# Layout and behavior-preserving refactoring

## Turn a reference into decisions

Inspect both the top level and representative internal scopes. Record which conventions help the reader: functional partitioning, forward path, parallel-channel ordering, shared-signal routing, port naming, reset/state placement, parameter expressions, task boundaries, and function packaging. Copy the convention; derive numerical values from the new design.

Do not require a local reference corpus to be present. If it is absent, use the model's actual interfaces and the principles below; ask for another reference only if that would resolve a material ambiguity.

## Place before routing

1. Place the major functions in computation order and align parallel channels.
2. Give modules enough width for both sides' labels, and enough height for port spacing.
3. Place source inputs in a separate column. Place shared-signal From blocks near consumers, with an unobstructed short approach to each port.
4. Route primary signals directly. Place diagnostic taps outside the main chain.
5. Route feedback visibly around the flow, or use a named local feedback tag where a return line would obscure the diagram.
6. Add supporting blocks, then inspect the settled result. A final position pass may be necessary after structural changes trigger the layout engine.

After moving blocks, reroute affected existing lines through the supported layout workflow or the native line-routing API. Inspect the exported paths again. Position changes alone can leave obsolete long line segments. If logging makes the overview hard to follow, group the test bench, algorithm, and results into distinct subsystems and use named vectors or buses for their diagnostic interfaces. Keep signal names, units, and element order explicit inside each group.

Use separate scope views when a diagram cannot remain readable on one screen. A child scope should explain one operation, not reproduce the entire parent in miniature. Subsystem previews are optional context, not the source of essential explanations.

For a new control design, function names and ports should be meaningful and code-generation-safe. For existing models, preserve public interface names and external mappings unless changing them is part of the task. Put additional explanations in descriptions or annotations rather than breaking firmware names for cosmetic reasons.

## Visual acceptance before delivery

1. Review the final saved overview and key subdiagrams at their intended display size. For localized work, review the affected views and export only those needed for delivery or to check the intended display size. For video, inspect the affected frames at playback size, including frames around transitions that move or crop the diagram.
2. Follow the main path and each visible feedback path from source to destination. Check for wires passing through unrelated blocks, avoidable backtracking, crossings that make connections ambiguous, and wires or overlays obscuring port names. Confirm that labels and endpoints remain legible in the final crop. A clean block-overlap report still requires this review.
3. If the view is crowded, give the main chain and diagnostic taps separate space. Use meaningful local tags for distant feedback and split the overview from detailed views if needed. Keep essential text legible. Export again after the fix and repeat the review on the deliverable.

## First-open walkthrough

Use the saved SLX in an ordinary Simulink window. Start at the default view for a new model or when the overall reading route changes. For localized edits, apply only the relevant steps to the affected view, including its incoming and outgoing connections. Use the visible labels and normal block dialogs as the reader would.

1. **Find the entry.** Identify the model's purpose, the default case, and the named block where that case is changed. For a standalone controller, identify the command and measurement ports and their units instead.
2. **Follow one representative signal.** Trace a real command or measurement from its source into the key subsystem and out again. Follow the return path when it is part of the operation. Inside the subsystem, locate the few blocks that carry out the main calculation and explain what physical quantity they turn into what output. Use names, units, and vector ordering where needed to follow the path. For example, trace a speed reference in rpm through the speed PI to a q-axis current reference in amperes, then find where measured speed returns.
3. **Read the result.** Locate the first Scope or Simulation Data Inspector signal to inspect. Use the same default run as the current delivery verification. Use labeled traces and units so the reader can tell a reference, a measurement, and an estimate apart when shown together. For a standalone controller, follow the output port and verify its meaning, unit, and element order instead.

Record the route or affected segment with actual block names in the validation notes. If a step depends on reading a setup script, inspecting hidden model metadata, or knowing an undocumented tag, clarify the diagram and recheck that step.

## Regroup existing blocks without losing behavior

Use the official grouping/expansion workflow to retain block identity and wiring. Inspect the new boundary rather than assuming its generated interface is satisfactory:

- Branches can create duplicate inputs carrying the same source.
- An internal shared signal can be routed out and back through a new input.
- Automatically generated `In1`/`Out1` names conceal physical meaning.
- New port numbering can disagree with the desired channel order.
- Removed inputs can leave an unused From block in the parent.

When consolidating duplicate ports, verify that they resolve to the **same signal source**, including local Goto/From. Equal-looking names or current numerical equality are insufficient. For an unnecessary out-and-back route, reconnect the real internal source before deleting the boundary input. Preserve any actual state, reset, scheduling, or library boundary.

When reordering ports, capture the parent connections, change the child port numbering, and reconnect by signal identity. Re-read both parent and child. Verify d/q order, phase order, vector elements, diagnostics, and firmware mappings.

Name a new local tag from its actual source port. Do not infer `Out1`'s meaning from an assumed output order. Keep a single source per visible local tag; maintain the same tag on all intended consumers.

## Evidence for a refactor

Record original and revised model versions plus the operating conditions. For unchanged arithmetic, compare the full saved time grids and traces before introducing a tolerance. Compare input/output order and delayed state as well as the final speed or other headline metric. If a discrepancy appears, inspect routing, port order, execution changes, and precision before considering algorithm tuning.

The numeric block bounds checked by the helper omit drawn labels, annotations, wire routes, and nested preview content. Check real scope exports as well as structural and dynamic results.
