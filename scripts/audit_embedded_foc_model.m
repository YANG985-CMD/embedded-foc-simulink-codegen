function report = audit_embedded_foc_model(model, varargin)
%AUDIT_EMBEDDED_FOC_MODEL Read-only audit of a Simulink FOC model.
%
% report = audit_embedded_foc_model("motor_control.slx")
% report = audit_embedded_foc_model("motor_control", ...
%     "ControllerPath", "motor_control/FOC_Model", "Compile", true)
%
% The function loads and optionally updates the model, but never saves it.
% It checks architecture and configuration signals that commonly affect
% embedded FOC code generation. Passing the audit is not a replacement for
% control simulation, ERT build, SIL/PIL, or target timing measurements.

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'model', @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'ControllerPath', '', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'Compile', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(parser, 'Verbose', true, ...
    @(x) islogical(x) && isscalar(x));
parse(parser, model, varargin{:});
opts = parser.Results;

[modelName, modelFile, modelDir] = resolveModel(char(model));
oldDir = pwd;
dirCleanup = onCleanup(@() cd(oldDir));
if ~isempty(modelDir)
    cd(modelDir);
end

wasLoaded = bdIsLoaded(modelName);
if ~wasLoaded
    load_system(modelFile);
end
modelCleanup = onCleanup(@() closeIfOpened(modelName, wasLoaded));

checks = struct('id', {}, 'status', {}, 'message', {}, 'evidence', {});
settings = readSettings(modelName);

checks(end+1) = makeCheck('solver.fixed_step', ...
    passFail(strcmpi(settings.SolverType, 'Fixed-step')), ...
    'Controller uses a fixed-step solver.', ...
    sprintf('SolverType=%s, Solver=%s', settings.SolverType, settings.Solver));

explicitStep = ~isempty(settings.FixedStep) && ...
    ~any(strcmpi(strtrim(settings.FixedStep), {'auto', '-1'}));
checks(end+1) = makeCheck('solver.explicit_base_step', ...
    passWarn(explicitStep), ...
    'Deployment base step should be an explicit PWM/ADC-derived period.', ...
    sprintf('FixedStep=%s', settings.FixedStep));

checks(end+1) = makeCheck('codegen.ert', ...
    passWarn(strcmpi(settings.SystemTargetFile, 'ert.tlc')), ...
    'ERT is preferred for a production embedded controller.', ...
    sprintf('SystemTargetFile=%s', settings.SystemTargetFile));

checks(end+1) = makeCheck('codegen.c99', ...
    passWarn(contains(lower(settings.TargetLangStandard), 'c99')), ...
    'Use the project C standard deliberately.', ...
    sprintf('TargetLangStandard=%s', settings.TargetLangStandard));

checks(end+1) = makeCheck('hardware.production_target', ...
    passWarn(any(contains(lower(settings.ProdHWDeviceType), {'arm', 'cortex'}))), ...
    'Production hardware must match the MCU integer and word assumptions.', ...
    sprintf('ProdHWDeviceType=%s', settings.ProdHWDeviceType));

checks(end+1) = makeCheck('codegen.report', ...
    passWarn(strcmpi(settings.GenerateReport, 'on')), ...
    'Generate a code report for interface and traceability review.', ...
    sprintf('GenerateReport=%s', settings.GenerateReport));

checks(end+1) = makeCheck('numeric.nonfinite', ...
    passWarn(strcmpi(settings.SupportNonFinite, 'off')), ...
    'Disable non-finite support for production unless NaN/Inf is required.', ...
    sprintf('SupportNonFinite=%s', settings.SupportNonFinite));

[dictionary, dictionaryCheck] = inspectDictionary(modelName);
checks(end+1) = dictionaryCheck;

controllerPath = char(opts.ControllerPath);
if isempty(controllerPath)
    controllerPath = findControllerBoundary(modelName);
end

if isempty(controllerPath)
    checks(end+1) = makeCheck('architecture.controller_boundary', 'WARN', ...
        'No FOC_Controller or FOC_Model subsystem was found.', ...
        'Provide ControllerPath when the project uses another name.');
    controller = emptyController();
else
    controller = inspectController(controllerPath);
    checks(end+1) = makeCheck('architecture.controller_boundary', 'PASS', ...
        'A generated-controller boundary was identified.', controllerPath);
    checks(end+1) = makeCheck('architecture.atomic_boundary', ...
        passWarn(strcmpi(controller.atomic, 'on')), ...
        'Use an atomic or referenced boundary when a stable generated function is required.', ...
        sprintf('TreatAsAtomicUnit=%s', controller.atomic));

    [rateStatus, rateEvidence] = compareControllerRate( ...
        settings.FixedStep, controller.sampleTime);
    checks(end+1) = makeCheck('timing.controller_period', rateStatus, ...
        'Controller period must be inherited from or be an integer multiple of the base step.', ...
        rateEvidence);

    [desktopCount, desktopNames] = countDesktopBlocks(controllerPath);
    checks(end+1) = makeCheck('architecture.desktop_blocks', ...
        passFail(desktopCount == 0), ...
        'Keep scopes, workspace I/O, and desktop stimuli outside generated control.', ...
        joinEvidence(desktopNames));

    [plantCount, plantNames] = countPlantBlocks(controllerPath);
    checks(end+1) = makeCheck('architecture.plant_separation', ...
        passFail(plantCount == 0), ...
        'Keep inverter and motor plant blocks outside generated control.', ...
        joinEvidence(plantNames));
end

rateTransitions = inspectRateTransitions(modelName);
functionCalls = inspectFunctionCallGenerators(modelName);
pids = inspectPidBlocks(modelName);
features = inspectFeatures(modelName);

checks(end+1) = makeCheck('timing.rate_contract', ...
    passWarn(~isempty(rateTransitions) || ~isempty(functionCalls)), ...
    'Document deterministic crossings between current, estimator, and speed tasks.', ...
    sprintf('RateTransition=%d, FunctionCallGenerator=%d', ...
    numel(rateTransitions), numel(functionCalls)));

compile = struct('attempted', opts.Compile, 'succeeded', false, 'message', 'NOT RUN');
if opts.Compile
    try
        set_param(modelName, 'SimulationCommand', 'update');
        compile.succeeded = true;
        compile.message = 'Diagram update succeeded.';
        checks(end+1) = makeCheck('model.diagram_update', 'PASS', ...
            'Model diagram update succeeded.', 'No model was saved.');
    catch exception
        compile.message = exception.message;
        checks(end+1) = makeCheck('model.diagram_update', 'FAIL', ...
            'Model diagram update failed.', compactText(exception.message));
    end
end

statuses = {checks.status};
summary = struct( ...
    'pass', sum(strcmp(statuses, 'PASS')), ...
    'warn', sum(strcmp(statuses, 'WARN')), ...
    'fail', sum(strcmp(statuses, 'FAIL')));

report = struct( ...
    'tool', mfilename, ...
    'model', modelName, ...
    'file', modelFile, ...
    'controller', controller, ...
    'settings', settings, ...
    'dictionary', dictionary, ...
    'features', features, ...
    'rateTransitions', rateTransitions, ...
    'functionCallGenerators', functionCalls, ...
    'pidControllers', pids, ...
    'compile', compile, ...
    'checks', checks, ...
    'summary', summary);

if opts.Verbose
    printReport(report);
end
delete(modelCleanup);
delete(dirCleanup);
end

function [modelName, modelFile, modelDir] = resolveModel(modelArg)
if isfile(modelArg)
    [~, attributes] = fileattrib(modelArg);
    modelFile = attributes.Name;
    [modelDir, modelName] = fileparts(modelFile);
    return;
end

[~, candidateName, extension] = fileparts(modelArg);
if isempty(candidateName)
    candidateName = modelArg;
end
if bdIsLoaded(candidateName)
    modelName = candidateName;
    modelFile = get_param(modelName, 'FileName');
    modelDir = fileparts(modelFile);
    return;
end

if isempty(extension)
    located = which([modelArg '.slx']);
    if isempty(located)
        located = which([modelArg '.mdl']);
    end
else
    located = which(modelArg);
end
if isempty(located)
    error('audit_embedded_foc_model:ModelNotFound', ...
        'Could not locate model "%s".', modelArg);
end
modelFile = located;
[modelDir, modelName] = fileparts(modelFile);
end

function closeIfOpened(modelName, wasLoaded)
if ~wasLoaded && bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end

function settings = readSettings(modelName)
names = {'SolverType', 'Solver', 'FixedStep', 'SystemTargetFile', ...
    'TargetLangStandard', 'ProdHWDeviceType', 'GenCodeOnly', ...
    'GenerateReport', 'SupportNonFinite', 'DefaultParameterBehavior', ...
    'DataDictionary'};
settings = struct();
for index = 1:numel(names)
    settings.(names{index}) = safeGetParam(modelName, names{index});
end
end

function [dictionary, check] = inspectDictionary(modelName)
dictionary = struct('name', safeGetParam(modelName, 'DataDictionary'), ...
    'resolvedPath', '', 'exactCase', false);
if isempty(dictionary.name)
    check = makeCheck('data.dictionary', 'WARN', ...
        'No model data dictionary is attached.', ...
        'Use a version-controlled definition for calibrations and interfaces.');
    return;
end

modelDir = fileparts(get_param(modelName, 'FileName'));
if java.io.File(dictionary.name).isAbsolute()
    candidate = dictionary.name;
else
    candidate = fullfile(modelDir, dictionary.name);
end
if ~isfile(candidate)
    check = makeCheck('data.dictionary', 'FAIL', ...
        'The attached data dictionary does not resolve.', dictionary.name);
    return;
end

dictionary.resolvedPath = candidate;
[folder, base, extension] = fileparts(dictionary.resolvedPath);
entries = dir(folder);
dictionary.exactCase = any(strcmp({entries.name}, [base extension]));
if dictionary.exactCase
    status = 'PASS';
    message = 'The model data dictionary resolves with exact filename case.';
else
    status = 'WARN';
    message = 'Dictionary filename case differs from the file on disk.';
end
check = makeCheck('data.dictionary', status, message, dictionary.resolvedPath);
end

function controllerPath = findControllerBoundary(modelName)
controllerPath = '';
subsystems = find_system(modelName, 'SearchDepth', 2, ...
    'FollowLinks', 'off', 'LookUnderMasks', 'none', 'BlockType', 'SubSystem');
preferred = {'FOC_Controller', 'FOC_Model'};
for p = 1:numel(preferred)
    for index = 1:numel(subsystems)
        if strcmpi(get_param(subsystems{index}, 'Name'), preferred{p})
            controllerPath = subsystems{index};
            return;
        end
    end
end
end

function controller = inspectController(controllerPath)
controller = struct( ...
    'path', controllerPath, ...
    'atomic', safeGetParam(controllerPath, 'TreatAsAtomicUnit'), ...
    'sampleTime', safeGetParam(controllerPath, 'SystemSampleTime'), ...
    'inputs', {orderedPorts(controllerPath, 'Inport')}, ...
    'outputs', {orderedPorts(controllerPath, 'Outport')});
end

function controller = emptyController()
controller = struct('path', '', 'atomic', '', 'sampleTime', '', ...
    'inputs', {{}}, 'outputs', {{}});
end

function [status, evidence] = compareControllerRate(baseStepText, controllerStepText)
evidence = sprintf('FixedStep=%s, ControllerSampleTime=%s', ...
    baseStepText, controllerStepText);
if any(strcmp(strtrim(controllerStepText), {'', '-1'}))
    status = 'PASS';
    evidence = [evidence ' (controller inherits its rate)'];
    return;
end
baseStep = str2double(baseStepText);
controllerStep = str2double(controllerStepText);
if ~isfinite(baseStep) || ~isfinite(controllerStep) || ...
        baseStep <= 0 || controllerStep <= 0
    status = 'WARN';
    return;
end
ratio = controllerStep / baseStep;
tolerance = 100 * eps(max(1, abs(ratio)));
if ratio >= 1 - tolerance && abs(ratio - round(ratio)) <= tolerance
    status = 'PASS';
else
    status = 'FAIL';
end
end

function names = orderedPorts(systemPath, blockType)
blocks = find_system(systemPath, 'SearchDepth', 1, 'BlockType', blockType);
if isempty(blocks)
    names = {};
    return;
end
ports = zeros(size(blocks));
for index = 1:numel(blocks)
    ports(index) = str2double(safeGetParam(blocks{index}, 'Port'));
end
[~, order] = sort(ports);
names = cellfun(@(x) get_param(x, 'Name'), blocks(order), 'UniformOutput', false);
end

function [count, names] = countDesktopBlocks(controllerPath)
types = {'Scope', 'ToWorkspace', 'FromWorkspace', 'SignalGenerator'};
names = {};
for index = 1:numel(types)
    blocks = find_system(controllerPath, 'SearchDepth', 8, ...
        'LookUnderMasks', 'none', 'FollowLinks', 'off', ...
        'BlockType', types{index});
    names = [names; blocks(:)]; %#ok<AGROW>
end
names = unique(names, 'stable');
count = numel(names);
end

function [count, names] = countPlantBlocks(controllerPath)
blocks = find_system(controllerPath, 'SearchDepth', 8, ...
    'LookUnderMasks', 'none', 'FollowLinks', 'off');
names = {};
pattern = '(surface.?mount|pmsm|permanent.?magnet|average.?value.?inverter|motor.?plant)';
for index = 1:numel(blocks)
    text = strjoin({safeGetParam(blocks{index}, 'Name'), ...
        safeGetParam(blocks{index}, 'MaskType'), ...
        safeGetParam(blocks{index}, 'ReferenceBlock')}, ' ');
    if ~isempty(regexpi(text, pattern, 'once'))
        names{end+1, 1} = blocks{index}; %#ok<AGROW>
    end
end
names = unique(names, 'stable');
count = numel(names);
end

function transitions = inspectRateTransitions(modelName)
blocks = find_system(modelName, 'SearchDepth', 8, 'LookUnderMasks', 'none', ...
    'FollowLinks', 'off', 'BlockType', 'RateTransition');
template = struct('path', '', 'outputSampleTime', '', ...
    'integrity', '', 'deterministic', '');
transitions = repmat(template, numel(blocks), 1);
for index = 1:numel(blocks)
    transitions(index) = struct( ...
        'path', blocks{index}, ...
        'outputSampleTime', safeGetParam(blocks{index}, 'OutPortSampleTime'), ...
        'integrity', safeGetParam(blocks{index}, 'Integrity'), ...
        'deterministic', safeGetParam(blocks{index}, 'Deterministic'));
end
end

function generators = inspectFunctionCallGenerators(modelName)
blocks = find_system(modelName, 'SearchDepth', 8, 'LookUnderMasks', 'none', ...
    'FollowLinks', 'off', 'MaskType', 'Function-Call Generator');
template = struct('path', '', 'sampleTime', '');
generators = repmat(template, numel(blocks), 1);
for index = 1:numel(blocks)
    sampleTime = firstAvailableParam(blocks{index}, ...
        {'sample_time', 'SampleTime', 'sampleTime'});
    generators(index) = struct( ...
        'path', blocks{index}, 'sampleTime', sampleTime);
end
end

function pids = inspectPidBlocks(modelName)
blocks = find_system(modelName, 'SearchDepth', 8, 'LookUnderMasks', 'none', ...
    'FollowLinks', 'off', 'MaskType', 'PID 1dof');
template = struct('path', '', 'controller', '', 'P', '', 'I', '', ...
    'integratorMethod', '', 'antiWindup', '', 'upperLimit', '', ...
    'lowerLimit', '', 'externalReset', '', 'sampleTime', '');
pids = repmat(template, numel(blocks), 1);
for index = 1:numel(blocks)
    pids(index) = struct( ...
        'path', blocks{index}, ...
        'controller', safeGetParam(blocks{index}, 'Controller'), ...
        'P', safeGetParam(blocks{index}, 'P'), ...
        'I', safeGetParam(blocks{index}, 'I'), ...
        'integratorMethod', safeGetParam(blocks{index}, 'IntegratorMethod'), ...
        'antiWindup', safeGetParam(blocks{index}, 'AntiWindupMode'), ...
        'upperLimit', safeGetParam(blocks{index}, 'UpperSaturationLimit'), ...
        'lowerLimit', safeGetParam(blocks{index}, 'LowerSaturationLimit'), ...
        'externalReset', safeGetParam(blocks{index}, 'ExternalReset'), ...
        'sampleTime', safeGetParam(blocks{index}, 'SampleTime'));
end
end

function features = inspectFeatures(modelName)
allBlocks = find_system(modelName, 'SearchDepth', 8, ...
    'LookUnderMasks', 'none', 'FollowLinks', 'off');
allNames = lower(strjoin(allBlocks, ' '));
features = struct( ...
    'hasClarke', contains(allNames, 'clark'), ...
    'hasPark', contains(allNames, 'park'), ...
    'hasSvpwm', contains(allNames, 'svpwm'), ...
    'hasCurrentLoop', any(contains(allNames, {'currloop', 'curr_loop', 'currentloop'})), ...
    'hasSpeedLoop', any(contains(allNames, {'speedloop', 'speed_loop'})), ...
    'hasStateflow', hasStateflow(modelName), ...
    'hasObserver', any(contains(allNames, {'observer', 'luenberger', 'smo', 'ekf', 'flux'})));
end

function value = hasStateflow(modelName)
value = false;
try
    charts = find_system(modelName, 'SearchDepth', 8, ...
        'LookUnderMasks', 'none', 'FollowLinks', 'off', 'SFBlockType', 'Chart');
    value = ~isempty(charts);
catch
    % Stateflow may be unavailable or the release may not support SFBlockType.
end
end

function value = firstAvailableParam(block, names)
value = '';
for index = 1:numel(names)
    value = safeGetParam(block, names{index});
    if ~isempty(value)
        return;
    end
end
end

function value = safeGetParam(object, parameter)
try
    value = get_param(object, parameter);
    if isnumeric(value) || islogical(value)
        value = mat2str(value);
    elseif isstring(value)
        value = char(value);
    elseif ~ischar(value)
        value = '';
    end
catch
    value = '';
end
end

function check = makeCheck(id, status, message, evidence)
check = struct('id', id, 'status', status, ...
    'message', message, 'evidence', evidence);
end

function status = passFail(condition)
if condition
    status = 'PASS';
else
    status = 'FAIL';
end
end

function status = passWarn(condition)
if condition
    status = 'PASS';
else
    status = 'WARN';
end
end

function evidence = joinEvidence(names)
if isempty(names)
    evidence = 'none found';
elseif numel(names) <= 5
    evidence = strjoin(names, '; ');
else
    evidence = sprintf('%s; ... (%d total)', strjoin(names(1:5), '; '), numel(names));
end
end

function text = compactText(text)
text = regexprep(text, '\s+', ' ');
if numel(text) > 500
    text = [text(1:497) '...'];
end
end

function printReport(report)
fprintf('\nEmbedded FOC Simulink Codegen Audit\n');
fprintf('Model: %s\n', report.model);
if ~isempty(report.controller.path)
    fprintf('Controller: %s\n', report.controller.path);
end
for index = 1:numel(report.checks)
    check = report.checks(index);
    fprintf('[%s] %s - %s\n', check.status, check.id, check.message);
    if ~isempty(check.evidence)
        fprintf('       %s\n', check.evidence);
    end
end
fprintf('Summary: %d PASS, %d WARN, %d FAIL\n\n', ...
    report.summary.pass, report.summary.warn, report.summary.fail);
end
