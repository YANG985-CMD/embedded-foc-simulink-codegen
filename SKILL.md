---
name: embedded-foc-simulink-codegen
description: Build, revise, audit, or prepare Simulink field-oriented-control models for embedded C code generation. Use for PMSM/BLDC FOC models involving Clarke/Park transforms, dq current and speed loops, SVPWM, startup state machines, Hall or sensorless rotor feedback, deterministic multi-rate execution, data dictionaries, ERT/Embedded Coder, STM32 or ARM Cortex-M deployment, and generated-code integration.
---

# Embedded FOC Simulink Codegen

Build an executable control design, not only a visually complete block diagram. Keep the simulation plant outside a clearly defined controller boundary and make that boundary suitable for deterministic embedded code generation.

## Workflow

1. Classify the request before editing:
   - algorithm unit: Clarke, Park, PI, SVPWM, observer, or state logic;
   - closed-loop simulation: controller plus inverter, motor, load, and tests;
   - deployment controller: controller-only model or atomic subsystem;
   - audit or migration: preserve behavior while finding code-generation risks.
2. Inspect the existing model, dictionary, callbacks, referenced models, solver, sample times, code mappings, and target configuration. Do not overwrite tuned gains, storage classes, or hardware timing without evidence.
3. Read the applicable reference:
   - architecture and construction order: `references/control-architecture.md`;
   - visual and block-level conventions: `references/style-guide.md`;
   - embedded interface and configuration: `references/embedded-codegen-contract.md`;
   - required verification: `references/verification-checklist.md`;
   - evidence and deliberate improvements over the reference corpus: `references/reference-findings.md`.
4. Build or revise in testable stages: transforms, modulation, current loop, startup/handoff, speed loop, then optional rotor estimator. Verify each stage before adding the next.
5. Establish one controller boundary such as `FOC_Controller` or preserve an existing `FOC_Model`. Put plant, sources, scopes, and desktop-only analysis outside it.
6. Define the execution contract from hardware timing. Align the fast current task with PWM/ADC sampling; make every slower task an integer multiple. Use explicit rate transitions or function-call partitions at crossings.
7. Update the diagram, run focused simulations, audit code-generation readiness, then generate code only after numerical and state-transition tests pass.

## Control Architecture Rules

- Use the signal chain `abc current -> Clarke -> Park -> dq PI -> inverse Park -> SVPWM` for the fast loop.
- Limit `iq_ref` in the speed loop and limit the dq voltage vector against the available DC-bus voltage. Prevent integrator windup whenever an actuator or reference saturates.
- Keep angle convention explicit: radians or per-unit, electrical or mechanical, direction, zero position, pole-pair conversion, and wrap range.
- Treat startup as control logic, not a hidden constant. Typical states are disabled, alignment, open-loop ramp, transition, and closed loop. Make reset and bumpless handoff behavior testable.
- Place Hall processing, Luenberger, SMO, EKF, or another estimator behind a rotor-feedback interface. Do not intertwine estimator internals with current-loop transforms.
- Prefer inspectable Simulink blocks for elementary transforms and PI control. Use MATLAB Function or Stateflow when it improves stateful algorithm clarity and remains supported by code generation.

## Embedded Code-Generation Rules

- Use fixed-step discrete execution. Set the base step explicitly for deployment; do not leave target timing dependent on automatic solver inference.
- Prefer ERT (`ert.tlc`), C99, and the actual ARM Cortex-M production hardware settings when Embedded Coder is available.
- Use `single` deliberately for controller arithmetic, but retain boolean, integer, fixed-point, or wider accumulator types where the hardware contract requires them.
- Store calibration parameters and interface data in a data dictionary or another version-controlled data definition. Export only symbols required by external firmware; internal signals should not become globals by default.
- Keep generated-code inputs and outputs stable and named by physical meaning. Document units, ranges, sample times, reset semantics, and ownership.
- Disable non-finite support for production when NaN/Inf behavior is not required, and verify all divide-by-zero and invalid-sensor paths explicitly.
- Generate a report and inspect the entry-point signature, parameter representation, execution order, memory, stack, and traceability before integrating with firmware.
- Never place the motor plant, scopes, Signal Builder, desktop file I/O, or test stimulus inside the generated controller boundary.

## Verification Gates

Do not claim completion from a successful diagram update alone. Apply the gates in `references/verification-checklist.md`:

1. transform identities, units, signs, and angle convention;
2. current-loop saturation, anti-windup, and step response;
3. startup states, fault/reset behavior, and closed-loop handoff;
4. speed-loop limits and multi-rate determinism;
5. nominal, reversal, load-step, bus-variation, and sensor-fault simulations;
6. controller-boundary update and code-generation audit;
7. ERT build plus SIL/PIL or target execution when tools and hardware are available.

Use the bundled read-only audit before handoff:

```matlab
addpath('scripts');
report = audit_embedded_foc_model('path/to/model.slx');
```

Treat audit output as engineering evidence, not as a substitute for simulation or target testing.

## Delivery

Report:

- model and controller boundary changed;
- control mode and rotor-feedback source;
- fast and slow task periods and their hardware trigger;
- interface, units, types, and saturation limits;
- simulations and code-generation checks actually run;
- unresolved assumptions, warnings, and target-integration work.

Do not redistribute the local reference manual or proprietary model files. Recreate only general engineering patterns and original documentation.
