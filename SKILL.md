---
name: speedloop-simulink-style
description: Build, revise, or review Simulink FOC speed-loop motor-control models using the reference SpeedLoop_Model/speedloop.slx style. Use when the user asks to create or modify BLDC/PMSM FOC, speed-loop, current-loop, Clarke/Park/AntiPark/SVPWM, inverter, PMSM plant, or STM32/ERT-oriented Simulink models in the documented SpeedLoop style.
---

# SpeedLoop Simulink Style

## Core Workflow

Use this skill when the user wants a Simulink motor-control model to look and behave like the local `speedloop.slx` reference model.

1. Inspect the target model or destination folder first. Preserve existing data dictionaries, generated-code settings, and naming conventions.
2. Read `references/style-guide.md` before creating or changing model structure.
3. Prefer visible Simulink blocks and subsystems over MATLAB Function blocks unless the user explicitly asks for algorithmic code.
4. Use fixed-step, code-generation-friendly settings and a data dictionary for signals/parameters.
5. Build in layers: top-level test harness, atomic `FOC_Model`, internal `speedloop`, internal `currloop`, and focused transform/control subsystems.
6. Verify by updating the diagram and running a short simulation when the plant/test harness exists.

## Model Shape

Mirror the reference partitioning:

- Top level: stimulus/feedback conversion, `Rate Transition` blocks, `FOC_Model`, inverter, PMSM plant, scopes, and Goto/From probes.
- `FOC_Model`: atomic subsystem with current inputs, DC bus, enable, speed reference, speed feedback, electrical angle, and one `tABC` output.
- `speedloop`: speed PI with external reset from current-loop state logic, output `iqRef`.
- `currloop`: state/enable logic, Clarke/Park, `idq_Controller`, AntiPark, SVPWM, and reset output.
- Use separate small subsystems named by motor-control function: `Clark`, `Park`, `AntiPark`, `SVPWM`, `idq_Controller`.

## Implementation Preferences

- Use library blocks such as `Sum`, `Gain`, `Product`, `Trigonometry`, `PID Controller`, `Switch Case`, `If Action Subsystem`, `Merge`, `Data Type Conversion`, `Rate Transition`, `Goto`, and `From`.
- Use Simulink `PID Controller` blocks for speed/current PI loops. Configure PI, Forward Euler, clamping anti-windup, and explicit saturation limits.
- Keep code-generation-critical subsystems atomic where the reference does: `FOC_Model`, `currloop`, `SVPWM`, and state/action subsystems.
- Use `single`-typed `Simulink.Signal` and `Simulink.Parameter` entries in a `.sldd` when creating reusable control signals or tunable constants.
- Avoid decorative abstractions. The reference style favors readable engineering block diagrams and generated-code compatibility.

## Validation

After edits:

- Run `set_param(model,'SimulationCommand','update')`.
- Confirm no unexpected MATLAB Function blocks were introduced for block-style requests.
- Confirm the model uses a data dictionary and fixed-step settings.
- Run a short simulation if source/plant blocks are present.
- If using code generation settings, confirm `SystemTargetFile` remains `ert.tlc`.

## References

- Read `references/style-guide.md` for concrete block hierarchy, port order, parameter names, and style rules extracted from the source model.
