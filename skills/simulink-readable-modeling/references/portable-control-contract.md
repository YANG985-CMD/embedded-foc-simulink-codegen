# Portable controller contract

## Separate responsibilities

| Layer | Owns |
| --- | --- |
| Test harness | Stimuli, physical sampling models, plant, loads, desktop logging and comparison |
| Controller | Discrete control states, reference generation, transforms, limits, reset logic and normalized actuator commands |
| Parameter data | Motor/plant constants, gains, tables, units, limits, data representation and calibration ownership |
| Hardware adapter | Calibrated ADC acquisition, peripheral timing, angle capture, output conversion, interrupts and board shutdown |

Use ports or a documented typed bus for measured values and commands. Keep desktop data sources and sinks outside the generated boundary. If runtime diagnostics are part of the embedded product, provide an explicit bounded interface rather than hiding desktop logging inside the controller.

## Specify the interface

For every port or bus field, document:

- physical meaning, units and valid range;
- scalar/vector dimensions and element order;
- storage/compute type, sample time and freshness expectations;
- sign, rotation direction, electrical/mechanical angle meaning and wrap convention;
- initialization, disable/fault/reset behavior and output ownership.

For example, distinguish normalized three-phase duty from timer compare counts. Convert to counts using the actual timer period in the adapter, and retain a separate run/interlock signal when required. A reference's literal timer count is not a portable control constant.

## Match execution and numeric settings

Use the design's real fixed discrete periods. Derive slow tasks as intended multiples and specify crossings. A synchronous sampling hold within one schedule and a Rate Transition between independent tasks serve different roles; select the block according to the execution contract.

Choose atomic subsystems at meaningful execution boundaries. Select inline, nonreusable, reusable, or model-reference interfaces according to instance/state ownership and the target. Do not imply that atomic alone creates a reentrant function or that a reusable function alone resolves all data dependencies.

Use `single` where appropriate for embedded control, while preserving boolean/integer/fixed-point interfaces and wider arithmetic where needed. A double-precision plant may share physical parameters with a single-precision controller if conversion is explicit and verified. Keep initial conditions, integration method, reset semantics, actuator limits, and anti-windup paths inspectable.

Store tunable parameters and table breakpoints in the model's linked data dictionary. When the controller is intended to be copied on its own, expose its required configuration as mask parameters or explicit inputs, or document and provide its required dictionary entries. Verify the copied subsystem with that interface. Recompute dependent tables when the motor, bus, limits, or discretization changes.

## Prove the dependency boundary

For an authorized independent-build check:

1. Save the intended model/data changes. Copy only the declared controller and data dependencies to a fresh directory.
2. Close the original task models and release their specific dictionary connections. Do not close unrelated models or all dictionaries globally.
3. Open the copied files from the new directory with a fresh cache/code-output location. Check resolved dictionary, model-reference, library and callback dependencies. A successful build using a same-named dictionary still open from the original project does not establish independence.
4. Generate code through the applicable approved workflow. Preserve generated sources unchanged; place handwritten adapters separately.
5. Compile and replay the same sampled input trace when supported. Compare duty/actuator outputs, enable flags, references, feedback transforms, limits, and state progression using declared tolerances.

Keep the original model's target and optimization decisions unless the task calls for changing them. Standalone code generation, host compilation/replay, processor execution, and energized hardware tests are separate evidence stages.
