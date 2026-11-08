# Read-only layout helper

Open the intended model using the installed model tools first. The helper deliberately does not load a model, execute callbacks, compile it, rearrange it, save it, or generate code.

```matlab
addpath(fullfile(READABLE_SKILL_DIR, 'scripts'));
report = audit_readable_layout('motor_control', ...
    'Scope', 'motor_control/FOC_Controller', ...
    'Recursive', true);
```

Resolve actual scope paths from tool block IDs; the path above only illustrates the interface. Omit `Scope` to inspect the model root. `Recursive` defaults to true and follows unlinked ordinary subsystems. Linked and masked subsystem interiors are not recursively inspected. They can be checked explicitly by naming the loaded scope when appropriate. Model references remain external boundaries.

Options:

| Name | Default | Meaning |
| --- | --- | --- |
| `Scope` | Model root | Loaded model or subsystem to start at |
| `Recursive` | `true` | Also inspect unlinked, unmasked descendant subsystem views |
| `OverlapTolerance` | `2` | Report rectangles with more than this many model units of interior overlap in both dimensions |
| `MinFontSize` | `10` | Flag smaller explicit positive block-font sizes for review |
| `OutputFile` | Empty | Optional chosen JSON report file; no file is written by default |

Findings are review prompts, not an edit plan or a code-generation gate. Block bounds do not cover port-label extents, annotations, wire routing or readability at a particular zoom. Zero findings therefore still requires real diagram review and the official structural checks.

The report lists the scopes it actually checked, block counts/extents, skipped linked or masked scopes, and findings with paths and SIDs. `modelChanged` compares the loaded model's dirty flag before and after this read-only helper; it does not claim to detect unrelated concurrent edits or prove numerical equivalence.

Use the project's designated temporary directory for any report or fixture that is not a deliverable. The package contains no user-specific drive paths or private reference models.
