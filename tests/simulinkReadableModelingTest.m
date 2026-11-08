classdef simulinkReadableModelingTest < matlab.unittest.TestCase
    % Utility tests use disposable models, never the user's open models.
    methods (TestClassSetup)
        function addScripts(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'skills', 'simulink-readable-modeling', 'scripts')));
        end
    end
    methods (Test)
        function overlapIsFoundWithinOneScope(testCase)
            f = fixture(testCase);
            add_block('built-in/Constant', [f.model '/Input'], 'Position', [30 30 110 80]);
            add_block('built-in/Gain', [f.model '/Gain'], 'Position', [80 40 160 90]);
            report = audit_readable_layout(f.model);
            testCase.verifyEqual(sum(strcmp({report.findings.code}, 'layout.block_overlap')), 1);
        end
        function touchingBoundsAreNotAnOverlap(testCase)
            f = fixture(testCase);
            add_block('built-in/Constant', [f.model '/Input'], 'Position', [30 30 110 80]);
            add_block('built-in/Gain', [f.model '/Gain'], 'Position', [110 30 190 80]);
            report = audit_readable_layout(f.model);
            testCase.verifyEqual(report.findingCount, 0);
        end
        function parentAndChildCoordinatesAreNotCompared(testCase)
            f = fixture(testCase);
            add_block('built-in/SubSystem', [f.model '/Control'], 'Position', [30 30 110 80]);
            add_block('built-in/Constant', [f.model '/Control/Input'], 'Position', [30 30 110 80]);
            report = audit_readable_layout(f.model);
            testCase.verifyEqual(numel(report.scopes), 2);
            testCase.verifyEqual(report.findingCount, 0);
        end
        function namesAndFontsAreReviewFindings(testCase)
            f = fixture(testCase);
            add_block('built-in/Inport', [f.model '/In1'], 'Position', [20 20 50 40], 'FontSize', '8');
            report = audit_readable_layout(f.model);
            testCase.verifyTrue(any(strcmp({report.findings.code}, 'ports.placeholder_name')));
            testCase.verifyTrue(any(strcmp({report.findings.code}, 'labels.small_font')));
        end
        function auditDoesNotCompileOrChangeSavedModel(testCase)
            f = fixture(testCase);
            add_block('built-in/Constant', [f.model '/Input'], 'Position', [30 30 110 80]);
            set_param(f.model, 'InitFcn', 'error(''Unexpected compile'')');
            save_system(f.model, f.file);
            before = bytes(f.file);
            report = audit_readable_layout(f.model);
            testCase.verifyFalse(report.modelChanged);
            testCase.verifyFalse(report.compiled);
            testCase.verifyEqual(get_param(f.model, 'Dirty'), 'off');
            testCase.verifyEqual(bytes(f.file), before);
        end
        function selectedScopeAndRecursiveOptionAreHonored(testCase)
            f = fixture(testCase);
            add_block('built-in/SubSystem', [f.model '/Control'], 'Position', [30 30 110 80]);
            add_block('built-in/Inport', [f.model '/Control/In1']);
            report = audit_readable_layout(f.model, 'Recursive', false);
            testCase.verifyEqual(numel(report.scopes), 1);
            testCase.verifyEqual(report.findingCount, 0);
            selected = audit_readable_layout(f.model, 'Scope', [f.model '/Control']);
            testCase.verifyEqual(selected.findingCount, 1);
            testCase.verifyError(@() audit_readable_layout(f.model, 'Scope', [f.model '/Absent']), ...
                'audit_readable_layout:InvalidScope');
        end
        function maskedInteriorsHaveExplicitCoverage(testCase)
            f = fixture(testCase);
            add_block('built-in/SubSystem', [f.model '/Masked'], 'Position', [30 30 110 80]);
            add_block('built-in/Inport', [f.model '/Masked/In1']);
            Simulink.Mask.create([f.model '/Masked']);
            report = audit_readable_layout(f.model);
            testCase.verifyEqual(numel(report.scopes), 1);
            testCase.verifyEqual(numel(report.skippedScopes), 1);
            testCase.verifyEqual(report.skippedScopes.reason, 'masked subsystem');
        end
        function reportRoundTripsThroughJson(testCase)
            f = fixture(testCase);
            target = fullfile(f.folder, 'reports', 'layout.json');
            report = audit_readable_layout(f.model, 'OutputFile', target);
            decoded = jsondecode(fileread(target));
            testCase.verifyEqual(decoded.schemaVersion, 1);
            testCase.verifyEqual(decoded.model, report.model);
            testCase.verifyFalse(decoded.compiled);
        end
        function unloadedModelIsNotOpened(testCase)
            f = fixture(testCase);
            save_system(f.model, f.file);
            close_system(f.model, 0);
            testCase.verifyError(@() audit_readable_layout(f.model), ...
                'audit_readable_layout:ModelNotLoaded');
            testCase.verifyFalse(bdIsLoaded(f.model));
        end
        function helperHasNoAnalyzerIssues(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            issues = checkcode(fullfile(root, 'skills', 'simulink-readable-modeling', ...
                'scripts', 'audit_readable_layout.m'), '-id');
            testCase.verifyEmpty(issues);
        end
    end
end

function f = fixture(testCase)
base = getenv('SIMULINK_SKILL_TEST_TMP');
if isempty(base)
    base = tempdir;
end
folder = tempname(base);
mkdir(folder);
[~, token] = fileparts(folder);
model = matlab.lang.makeValidName(['readable_' token]);
new_system(model);
f = struct('folder', folder, 'model', model, 'file', fullfile(folder, [model '.slx']));
testCase.addTeardown(@() removeFixture(f));
end
function removeFixture(f)
if bdIsLoaded(f.model)
    close_system(f.model, 0);
end
if isfolder(f.folder)
    rmdir(f.folder, 's');
end
end
function data = bytes(file)
fid = fopen(file, 'r');
cleanup = onCleanup(@() fclose(fid));
data = fread(fid, Inf, '*uint8');
end
