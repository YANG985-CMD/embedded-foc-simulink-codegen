# STM32G4 Manual-Derived Capabilities

This reference captures capabilities present in the STM32G4 Simulink FOC V13.1 teaching material and accompanying model corpus. It is an execution guide, not a claim that every example is production-ready.

## Contents

- Corpus map
- Peripheral contract
- Observer interface and algorithm-specific rules
- Startup and Hall rules
- Calibration and tuning
- MCSDK migration
- Verification additions

## Corpus Map

The numbered folders are progressive milestones. Preserve existing model and generated-code names when migrating them unless an interface change is requested and tested.

| Folder | Capability | Expected artifacts |
| --- | --- | --- |
| `5.GPIO` to `12.CAN` | STM32G4 GPIO, UART/VOFA, ADC/DMA, OPAMP, TIM1, COMP/DAC, DAC output, CAN/FDCAN | CubeMX project, peripheral driver code, small test model where present |
| `13.Clark` | Clarke transform | `Clark.slx`, dictionary, ERT C component |
| `14.Park & AntiPark` | Park and inverse Park | Park model, dictionary, generated C |
| `15.SVPWM_VF` | SVPWM and open-loop V/F | modulation model and target project |
| `16.CurrLoop_IF` | dq current loop, I-F startup and state logic | `currloop`/FOC model and generated C |
| `17.SpeedLoop` | speed loop, Hall feedback, ADC/COMP/DAC/FDCAN integration | `speedloop.slx`, target template, telemetry hooks |
| `18.Lun_Model_Code` | Luenberger observer plus PLL | Simulink observer subsystem and target C |
| `19.SMO_Model_Code` | sliding-mode observer plus PLL and low-pass filtering | Simulink observer subsystem and target C |
| `20.EKF_Model_Code` | extended Kalman observer | state/covariance model and target C |
| `23.Nonlinear flux observer` | nonlinear flux observer plus PLL | observer model, `UART.slx`, and target C |
| `24.HALL sensor speedloop` | Hall interpolation, zero-speed closed loop and reversal | Hall feedback C module and speed-loop firmware |
| `25.VOFA+ GUI` | parameter tuning and telemetry | UART/VOFA parameter protocol and host configuration |

Folder names are clues only. Inspect the actual model, dictionary, generated report, and MCU project before deciding that a capability is enabled.

## Peripheral Contract

For STM32G4 deployment, document these functions and their evidence explicitly:

| Function | Required evidence |
| --- | --- |
| TIM1 complementary PWM | channel order, polarity, dead time, preload, update event, and safe disabled compare values |
| ADC current sampling | injected sequence, trigger source, sample point relative to PWM edges, conversion order, and DMA/interrupt ownership |
| OPAMP current front end | shunt topology, gain, bias/offset, saturation range, polarity, and ADC channel mapping |
| COMP/DAC protection | threshold units, DAC reference, comparator routing, timer break/disable path, latch, and recovery behavior |
| DC-bus ADC | divider scale, offset, plausibility range, and undervoltage/overvoltage behavior |
| Hall input | timer/GPIO mapping, six-sector table, direction, electrical zero, interpolation, and invalid states |
| UART/VOFA and CAN/FDCAN | frame format, rate, ownership, timeout, and proof that communication cannot block the fast task |
| DAC debug output | signal unit/range and a bounded debug-build option; DAC output must not become a control dependency |

The manual's ADC/OPAMP/TIM1/COMP/DAC chain is part of the control system. Do not model current feedback as an ideal scalar when assessing sampling delay, offset, saturation, or overcurrent behavior.

## Observer Interface

All observers must implement the common `RotorFeedback` contract:

```text
inputs: ia, ib, ic, applied voltage or duty, vdc, enable, reset
outputs: theta_e, omega, valid, confidence/status, diagnostics
```

Expose angle error against a reference sensor, speed error, validity/confidence, PLL error, and algorithm-specific diagnostics in the simulation harness even when they stay outside the generated boundary. Compare observers on the same plant, motor parameters, sample period, startup command, load step, and noise set.

### Luenberger

- Keep the state definition and alpha-beta voltage/current conventions beside the model.
- Make observer gain, motor parameters, PLL gains, angle wrap, and reset values tunable and unit-documented.
- Check discrete poles/gain against the actual observer period, not only the top-model base step.
- Validate convergence from aligned and misaligned initial states, then compare estimated angle/speed with Hall or encoder feedback.

### Sliding-mode observer (SMO)

- Define the switching law and boundary layer explicitly; do not silently replace a sign function with an arbitrary saturation block.
- Record observer gain, boundary-layer width, low-pass cutoff, phase compensation, and PLL gains.
- Measure chattering and angle lag at low, nominal, and high speed. A clean speed trace alone does not prove angle accuracy.
- Gate closed-loop handoff on observer validity and angle/speed error, with timeout and fault behavior.

### Extended Kalman observer (EKF)

- Document the state vector, discrete motor model, Jacobian, covariance `P`, process noise `Q`, measurement noise `R`, and initial state.
- Check covariance symmetry and positive-semidefinite behavior after every update; bound or fault on non-finite values.
- Test innovation residuals, parameter mismatch, current noise, bus-voltage variation, and missed samples.
- Budget matrix operations at the observer rate and verify worst-case execution time on the target.

### Nonlinear flux observer

- Make the voltage model, stator-resistance compensation, flux-integration drift handling, nonlinear correction, and PLL explicit.
- Test ADC offset, dead-time/voltage error, low-speed observability, direction reversal, and restart from zero speed.
- Do not claim zero-speed sensorless operation without a separate initial-position or startup strategy.

## Startup and Hall Rules

Use explicit states such as `Disabled -> Align -> I-F/OpenLoop -> Observer/Hall Handoff -> ClosedLoop -> Fault`. For every transition record the angle source, speed source, current and voltage limits, timeout, validity guard, and PI-integrator action.

For Hall speed-loop models, verify the six valid sectors, reject `000`/`111` and illegal transitions, interpolate angle between edges only within a bounded timeout, and test zero-speed reverse. Hall feedback may close the loop at zero speed; sensorless observers generally need a separate alignment or I-F phase.

## Calibration and Tuning

Build a versioned parameter set containing:

- phase resistance, d/q inductance, pole pairs, and permanent-magnet flux;
- current shunt/gain/ADC scale and zero offsets for every phase;
- DC-bus divider scale and valid range;
- PWM period, dead time, ADC trigger/sample time, and electrical-angle convention;
- Hall sequence, direction, electrical zero, and interpolation period;
- PI limits, observer/PLL gains, EKF `P/Q/R`, and startup thresholds.

Use VOFA/UART or CAN/FDCAN only through a bounded background/telemetry path. Parameter writes must be range-checked, versioned, reset-safe, and unable to alter fast-loop state halfway through an update. Latch a complete calibration set at a defined synchronization point.

## MCSDK Migration

The corpus also contains ST MCSDK Hall projects. Treat MCSDK and Simulink-generated control as separate ownership models:

1. Identify who owns PWM, ADC/current feedback, Hall feedback, state machine, and fault handling.
2. Do not connect both control schedulers to the same timer interrupt.
3. When replacing MCSDK control with generated FOC, retain only the explicitly needed board/driver adapter and map units at one boundary.
4. Call generated-model initialization once and the fast step from the documented ADC/PWM event.
5. Compare Hall angle, current sign, duty polarity, dead time, and fault shutdown with a known-good MCSDK build before closing the loop.

## Verification Additions

- ADC sampling occurs inside a valid PWM window and current polarity matches the model.
- All current channels have offset, saturation, and plausibility checks.
- COMP/DAC protection disables PWM independently of the control task.
- Observer angle/speed is compared against a reference sensor and includes a validity timeout.
- Luenberger/SMO/EKF/flux observer uses the actual discrete period and has bounded state/reset behavior.
- Hall illegal-state and reverse transitions are handled.
- Generated `*_initialize` is called once and `*_step` is called from the expected ISR/task.
- VOFA/CAN telemetry cannot block or partially update fast-loop parameters.
- Target execution-time evidence includes observer worst-case cost.
