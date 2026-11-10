---
name: simulink-readable-modeling
description: Build or refactor readable Simulink models and portable controllers. Before any modeling work, confirm SLX only, SLX plus a companion dictionary, or AI selection between those two formats. For audit-only requests, prefer simulink-model-auditor.
---

# Simulink Readable Modeling

Make each diagram understandable at its own level, and make reusable control modules independent of their test harness. Apply this to the requested scope; retain the user's algorithm, tuned settings, interface contracts, and authorized changes.

## Select the modeling mode before editing

Every model built, changed, or repackaged with this skill uses one of these three choices. This includes control algorithms, engineering simulations, deployment controllers, layout changes, and teaching examples. Ask at the start unless the user already selected a mode or delegated the choice for this task. Inspect existing files if needed, and wait for the answer before editing or creating models.

1. **Only `.slx`.** Store parameters, types, and lookup tables in the model workspace with **Model File** as its data source. Deliver one model file.
2. **`.slx` + `.sldd` (SpeedLoop style).** Store shared parameters, types, and lookup tables in a same-named dictionary next to the model. Link it by filename. Deliver the pair.
3. **AI decides.** Select mode 1 or 2 based on the model's dependencies and purpose. Prefer a single SLX for self-contained models and a companion dictionary for shared typed calibrations, versioned parameter sets, or audit-gated embedded builds. Report the selected mode and reason.

The selected format governs the primary model files. Keep model-specific dependencies within those files. A separate build copy used for embedded C can have the dictionary and settings required by the deployment audit. Generated code, test results, and board adapters may be supplied separately when requested.

## Inspect before choosing a structure

1. Read the target model and any user-selected reference. Compare hierarchy, signal flow, port order, sample times, state/reset behavior, dictionaries, function packaging, and controller/harness boundaries. A screenshot alone does not establish module settings or portability.
2. Separate a layout-only change, a behavior-preserving refactor, and a new control design. For a refactor, retain an original copy and baseline data before changing structure. Explain any required behavior change separately.
3. Identify the main calculation path, shared measurements, diagnostic branches, feedback loops, and execution boundaries. Choose hierarchy around these responsibilities, rather than block-creation order.

## Use the installed model tools

With MathWorks tooling, use `model_overview`, `model_read`, `model_query_params`, and `model_resolve_params`. Before structural edits, follow the installed `building-simulink-models` library/policy check; for rearrangement, follow `arranging-simulink-layouts`. Use `model_edit` one scope at a time with an explicit layout mode. Resolve actual paths from returned block IDs instead of composing displayed block names.

After a partial edit, immediately inspect and check the scope. After completing a scope, re-read it and run `model_check`. Group existing blocks with the official subsystem-restructuring workflow so their wiring and identities are retained. If the necessary execution tools are unavailable, identify the unexecuted part rather than treating a plan or image as an edited model.

## Draw for the reader

Read [layout-and-refactoring.md](references/layout-and-refactoring.md) when arranging or regrouping a diagram.

- Keep the main signal path visible from left to right. Place parallel channels in matching rows, with matching port order and internal structure.
- At the system level show responsibilities; expose equations, PI state, or modulation logic at the next level. Use native inspectable blocks for ordinary transforms and control operations.
- Keep main-chain connections direct. Use meaningful **local** Goto/From labels for shared measurements, distant diagnostics, or feedback that would obscure that chain. Keep the input-source column separate from tags near consuming modules.
- Size subsystems for their port labels and give connected rows enough clearance. Separate reference, measurement, limit, and enable signals in a consistent order.
- Treat automatic layout as a first pass. Structural edits can move previously arranged blocks. Review again after adding routing blocks, and restore the intended rows and columns through the supported layout tool.
- Before delivery, review the saved model's exports at their final display size. If the model appears in a video, inspect the encoded overview and key close-ups at playback size. Follow the [visual acceptance checklist](references/layout-and-refactoring.md#visual-acceptance-before-delivery) even when the block-overlap check passes.

## Package and verify the selected format

The SLX is the only file to open. For a runnable simulation, clicking **Run** must execute the default case and show its results in a Scope or Simulation Data Inspector. For a standalone component, verify that the model updates in isolation and check its documented interface.

- Keep the test case, controller, inverter, and plant as distinct internal subsystems. Bring separately referenced controller models or custom libraries needed by the default run into the same file as readable subsystems. Preserve rates, execution order, types, and initialization.
- Keep default stimuli inside the model using blocks or embedded scenario data. Use mask parameters or explicit inputs for configuration that must travel with a copied controller.
- Keep initialization and inputs independent of setup scripts, external data files, additional project models or dictionaries, preloaded workspace variables, and personal paths. Public learning downloads contain no `.m` files. Declare the MATLAB release and required MathWorks products.
- Verify the selected files in a clean MATLAB session and a fresh directory containing only those files. For SpeedLoop style, confirm the dictionary resolves from that directory. Open the SLX without setup, then run the applicable checks. When consolidating an existing model, replay the same inputs and compare against its baseline.

Use the auditor's `simulation` profile for the demo. For authorized embedded C, apply the `deployment` profile. Build the subsystem in place if it meets that contract, or use a separate deployment copy with the required dictionary and target settings. Keep generated C, raw results and board adapters separate from the demo entry files.

## Make the reusable boundary concrete

When reusable or generated control modules are in scope, read [portable-control-contract.md](references/portable-control-contract.md). State units, type, dimension, rate, direction, initialization/reset, parameter ownership, and adapter ownership at the boundary.

Keep stimuli, sampling-device models, motor/plant models, scopes, and desktop logging in the harness. Pass calibrated measurements and commands through ports. Keep timer-count conversion, peripheral access, and board-specific shutdown in the adapter. Store shared parameters and lookup tables according to the selected format.

An atomic subsystem expresses an execution boundary; a reusable function setting expresses code packaging. Choose these deliberately rather than marking every mathematical group atomic. Preserve justified boolean, integer, fixed-point, and accumulator types. Derive periods and limits from the actual target rather than copying the reference's example values.

For PMSM/BLDC FOC architecture, also read [foc-pattern.md](references/foc-pattern.md). The repository's `embedded-foc-simulink-codegen` handles FOC algorithm and hardware decisions; `simulink-model-auditor` provides the wider audit. This skill can be used independently for general layout/refactoring and does not replace either one's domain or build workflow.

## Verify the requested change

- For layout-only work, compare functional configuration/connections and update the model. Check the diagram at the views the reader will use.
- After regrouping, inspect duplicate boundary inputs, internal signals that unnecessarily exit and return, changed port numbers, tag source conflicts, and newly unused routing blocks. Compare primitive-block connections across hierarchy and local tags when feasible.
- For behavior-preserving refactors, replay the same inputs and compare time grids, internal signals, output ordering, and state/reset behavior. Prefer exact equality when arithmetic is unchanged; justify tolerances if execution or precision changed. Do not retune gains to hide a refactor discrepancy.
- When code generation is requested and authorized, use the applicable existing build/audit workflow. Test independence in a clean directory containing only declared model/data dependencies. Close the original model and same-named dictionary connections first, use fresh caches, and verify which files were resolved. Compile the unchanged generated C and compare it against simulation on the same input trace when the toolchain is available.
- Report separately what was observed in simulation, generated code, host replay, and target hardware. A layout request does not itself start code generation or hardware operation.

The optional read-only helper [audit_readable_layout.m](scripts/audit_readable_layout.m) detects same-scope block-bound overlaps, placeholder boundary names, and small explicit fonts in **already loaded** models. It neither loads nor compiles, edits, saves, or builds a model. Read [layout-audit.md](references/layout-audit.md) before using it; geometry checks supplement visual review and the official structural checks.

## Handoff

Identify the SLX to open and list its SLDD when the two-file format was chosen. Include relevant scope images and a concise change/validation record. For a reusable control module, include its interface/adapter contract and the independent-build evidence actually obtained. Keep temporary fixtures, caches, raw diagnostic dumps, personal paths, and unrelated source material out of the skill and public package.
