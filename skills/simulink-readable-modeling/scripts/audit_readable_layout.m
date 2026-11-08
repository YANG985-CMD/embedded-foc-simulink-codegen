function report = audit_readable_layout(model, varargin)
%AUDIT_READABLE_LAYOUT Read-only geometry/name review of a loaded model.
%   R = AUDIT_READABLE_LAYOUT(MODEL) inspects ordinary unlinked/unmasked
%   subsystem views recursively. It does not load, compile, edit or save.
%   Options: Scope, Recursive, OverlapTolerance, MinFontSize, OutputFile.

parser = inputParser;
textValue = @(x) ischar(x) || (isstring(x) && isscalar(x));
nonnegative = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0;
addRequired(parser, 'model', textValue);
addParameter(parser, 'Scope', '', textValue);
addParameter(parser, 'Recursive', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'OverlapTolerance', 2, nonnegative);
addParameter(parser, 'MinFontSize', 10, nonnegative);
addParameter(parser, 'OutputFile', '', textValue);
parse(parser, model, varargin{:});
options = parser.Results;
model = char(model);
if ~bdIsLoaded(model)
    error('audit_readable_layout:ModelNotLoaded', ...
        'Open the intended model first, then pass its loaded model name.');
end
scope = char(options.Scope);
if isempty(scope)
    scope = model;
end
try
    scope = getfullname(get_param(scope, 'Handle'));
    valid = strcmp(bdroot(scope), model) && ...
        (strcmp(scope, model) || strcmp(get_param(scope, 'BlockType'), 'SubSystem'));
catch
    valid = false;
end
if ~valid
    error('audit_readable_layout:InvalidScope', ...
        'Scope must be this loaded model or one of its subsystems.');
end
dirtyBefore = get_param(model, 'Dirty');
findingTemplate = struct('code', '', 'severity', 'WARN', 'scope', '', ...
    'blocks', {{}}, 'sids', {{}}, 'message', '');
findings = repmat(findingTemplate, 0, 1);
scopes = struct('path', {}, 'blockCount', {}, 'majorFunctions', {}, 'extent', {});
skipped = struct('path', {}, 'reason', {});
queue = {scope};
index = 1;
while index <= numel(queue)
    current = queue{index};
    index = index + 1;
    children = find_system(current, 'SearchDepth', 1, 'FollowLinks', 'off', ...
        'LookUnderMasks', 'none', 'Type', 'Block');
    children(strcmp(children, current)) = [];
    positions = zeros(numel(children), 4);
    types = cell(numel(children), 1);
    for k = 1:numel(children)
        block = children{k};
        positions(k, :) = get_param(block, 'Position');
        types{k} = get_param(block, 'BlockType');
        if ismember(types{k}, {'Inport', 'Outport'}) && ...
                ~isempty(regexp(get_param(block, 'Name'), '^(In|Out)\d+$', 'once'))
            findings(end+1, 1) = item(findingTemplate, 'ports.placeholder_name', ...
                current, {block}, 'Review this boundary name against its physical signal.'); %#ok<AGROW>
        end
        fontSize = get_param(block, 'FontSize');
        if ischar(fontSize) || isstring(fontSize)
            fontSize = str2double(fontSize);
        end
        if fontSize > 0 && fontSize < options.MinFontSize
            findings(end+1, 1) = item(findingTemplate, 'labels.small_font', ...
                current, {block}, 'Review the explicit font size at the intended viewing scale.'); %#ok<AGROW>
        end
        if options.Recursive && strcmp(types{k}, 'SubSystem')
            if ~isempty(get_param(block, 'ReferenceBlock'))
                skipped(end+1) = struct('path', block, 'reason', 'linked subsystem'); %#ok<AGROW>
            elseif strcmp(get_param(block, 'Mask'), 'on')
                skipped(end+1) = struct('path', block, 'reason', 'masked subsystem'); %#ok<AGROW>
            else
                queue{end+1} = block; %#ok<AGROW>
            end
        end
    end
    for left = 1:numel(children)
        for right = left+1:numel(children)
            overlap = min(positions(left, 3:4), positions(right, 3:4)) - ...
                max(positions(left, 1:2), positions(right, 1:2));
            if all(overlap > options.OverlapTolerance)
                message = sprintf('Block bounds overlap by %g x %g model units.', overlap);
                findings(end+1, 1) = item(findingTemplate, 'layout.block_overlap', ...
                    current, children([left, right]), message); %#ok<AGROW>
            end
        end
    end
    if isempty(positions)
        extent = [];
    else
        extent = [min(positions(:, 1:2), [], 1), max(positions(:, 3:4), [], 1)];
    end
    scopes(end+1) = struct('path', current, 'blockCount', numel(children), ...
        'majorFunctions', sum(ismember(types, {'SubSystem', 'ModelReference'})), ...
        'extent', extent); %#ok<AGROW>
end
report = struct('schemaVersion', 1, 'model', model, 'scope', scope, ...
    'recursive', options.Recursive, 'scopes', scopes, 'skippedScopes', skipped, ...
    'findings', findings, 'findingCount', numel(findings), ...
    'modelChanged', ~strcmp(dirtyBefore, get_param(model, 'Dirty')), ...
    'compiled', false, 'outputFile', char(options.OutputFile));
if ~isempty(report.outputFile)
    parent = fileparts(report.outputFile);
    if ~isempty(parent) && ~isfolder(parent)
        mkdir(parent);
    end
    fid = fopen(report.outputFile, 'w', 'n', 'UTF-8');
    if fid < 0
        error('audit_readable_layout:OutputFile', 'Cannot open the chosen report file.');
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', jsonencode(report, 'PrettyPrint', true));
end
end

function finding = item(template, code, scope, blocks, message)
finding = template;
finding.code = code;
finding.scope = scope;
finding.blocks = blocks;
finding.sids = cellfun(@Simulink.ID.getSID, blocks, 'UniformOutput', false);
finding.message = message;
end
