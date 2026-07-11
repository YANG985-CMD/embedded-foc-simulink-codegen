# SpeedLoop Simulink Style Guide

Source analyzed: the reference `SpeedLoop_Model/speedloop.slx` model. The original model is not distributed with this skill.

## Baseline Model Settings

- Data dictionary: `speedloop.sldd`.
- Solver type: fixed-step.
- Solver: `FixedStepAuto`.
- Fixed step: `1e-4`.
- Stop time in reference harness: `10.0`.
- System target file: `ert.tlc`.
- Hardware board: `None`.

Prefer these settings for new models unless the user provides different embedded target constraints.

## Reference Top-Level Layout

The reference top level is a simulation harness wrapped around an embedded-control subsystem:

- Input stimulus and feedback acquisition on the left.
- `Data Type Conversion` and `Rate Transition` blocks before controller inputs.
- `FOC_Model` as the central control subsystem.
- Output conversion/limiting subsystem into an `Average-Value Inverter`.
- `Surface Mount PMSM` plant on the right.
- `Bus Selector`, scopes, and `Goto` tags for measurement signals.

Use `Rate Transition` blocks with integrity and deterministic transfer enabled for all external controller inputs crossing into `FOC_Model`.

## FOC_Model Interface

Make `FOC_Model` an atomic subsystem.

Input ports, in this order:

1. `ia`
2. `ib`
3. `ic`
4. `v_bus`
5. `Motor_OnOff`
6. `SpeedRef`
7. `SpeedFd`
8. `theta`

Output ports:

1. `tABC`

Internal children:

- `currloop`: atomic subsystem.
- `speedloop`: speed PI subsystem.
- `Function-Call Generator` when a function-call execution pattern is required.
- `Unit Delay` and `Goto/From` for reset/state feedback.

## currloop Interface

Make `currloop` atomic.

Input ports, in this order:

1. `ia`
2. `ib`
3. `ic`
4. `v_bus`
5. `Motor_OnOff`
6. `iq_ref`
7. `theta`

Output ports:

1. `tABC`
2. `SpeedReset`

Typical children:

- `Chart` or equivalent state/enable logic, atomic.
- `Clark`
- `Park`
- `idq_Controller`
- `AntiPark`
- `SVPWM`, atomic.
- `Switch Case`, four `If Action Subsystem` blocks, `Merge`, and reset outputs for motor state handling.
- `SinCos` trigonometry blocks feeding Park and AntiPark.
- `Goto/From` tags for shared signals such as state, theta, or current feedback.

## speedloop Interface

Input ports:

1. `SpeedRef`
2. `SpeedFd`
3. `SpeedReset`

Output ports:

1. `iqRef`

Use a Simulink `PID Controller` block rather than hand-written PI code:

- Controller: `PI`
- P: `spd_kp`
- I: `spd_ki`
- Integrator method: `Forward Euler`
- Anti-windup: `clamping`
- Saturation: upper `3`, lower `-3`
- External reset: `rising`

## idq_Controller Interface

Input ports:

1. `id_fdbk`
2. `iq_fdbk`
3. `iq_ref`

Output ports:

1. `ud_ref`
2. `uq_ref`

Use two Simulink `PID Controller` blocks:

- d-axis PID: `PID Controller1`
  - Controller: `PI`
  - P: `curr_d_kp`
  - I: `curr_d_ki`
  - Anti-windup: `clamping`
  - Integrator: `Forward Euler`
  - Saturation: `24*0.9/sqrt(3)` to `-24*0.9/sqrt(3)`
- q-axis PID: `PID Controller2`
  - Controller: `PI`
  - P: `curr_q_kp`
  - I: `curr_q_ki`
  - Anti-windup: `clamping`
  - Integrator: `Forward Euler`
  - Saturation: `24*0.9/sqrt(3)` to `-24*0.9/sqrt(3)`

Use `Sum` blocks for reference-minus-feedback errors. Keep `Constant` blocks for fixed d-axis reference and auxiliary limits when matching the reference visually.

## Data Dictionary Style

Create or reuse a `.sldd` beside the model.

Reference `Design Data` entries include:

- Signals: `ia`, `ib`, `ic`, `ialpha`, `ibeta`, `id`, `iq`, `ThetaOpen`, `Sig`
- Parameters: `L`, `Rs`, `Udc`, `CurrKi`, `CurrKp`, `Pn`, `flux`, `spd_ki`, `spd_kp`

Signal style:

- Use `Simulink.Signal`.
- Data type: `single` for current, dq, and motor-control signals.
- Sample time: `-1` unless explicitly constrained.

Parameter style:

- Use `Simulink.Parameter`.
- Data type: `single`.
- Use descriptive motor-control names. Preserve the existing mixed naming if editing the reference model: `spd_kp`, `spd_ki`, `CurrKp`, `CurrKi`, `Rs`, `L`, `Pn`, `flux`, `Udc`.
- Storage class is often `Custom` for motor parameters and speed gains, and `Auto` for some controller constants. Preserve existing storage classes when editing.

## Naming and Visual Style

- Use subsystem names that match motor-control concepts, not generic algorithm names.
- Keep reference-style names when modifying the model: `FOC_Model`, `currloop`, `speedloop`, `Clark`, `Park`, `AntiPark`, `SVPWM`, `idq_Controller`.
- Preserve reference capitalization: `SpeedRef`, `SpeedFd`, `Motor_OnOff`, `SpeedReset`, `iqRef`, `tABC`.
- It is acceptable that some inherited reference blocks use default names such as `Constant1`, `Gain6`, or `Sum7`; do not rename existing blocks merely for tidiness.
- Use Goto/From tags and Bus Selector probes at the top level for plant feedback and scopes.
- Keep controller input preparation on the left, plant on the right, and scopes/probes at the far right.

## Block Choices

Prefer these block types:

- `SubSystem`, `Inport`, `Outport`
- `PID Controller`
- `Sum`, `Gain`, `Product`, `Trigonometry`, `Math`
- `Switch`, `Switch Case`, `If Action Subsystem`, `Merge`
- `Saturation`/`Saturate`, `Dead Zone`, `MinMax`
- `Data Type Conversion`, `Signal Specification`
- `Rate Transition`, `Unit Delay`, `Discrete-Time Integrator`
- `Goto`, `From`, `Bus Selector`, `Bus Creator`
- `Scope`, `Terminator`, `Ground`

Avoid MATLAB Function blocks for this style unless the user explicitly asks for function-based logic.

## Review Checklist

- `FOC_Model` exists and is atomic.
- `currloop` exists and is atomic.
- `speedloop` has external reset behavior for PI state reset.
- Current-loop PI blocks use clamping anti-windup and voltage saturation limits.
- Speed-loop PI limits `iqRef`.
- Inputs crossing into the control model use `Rate Transition`.
- Controller-facing signals are converted or specified as `single` where appropriate.
- The model is fixed-step and uses ERT-compatible settings.
