# Verification Checklist

Record PASS, FAIL, NOT RUN, or NOT APPLICABLE with evidence. Do not convert an unrun check into a pass.

## Model Integrity

- [ ] All linked models, libraries, dictionaries, callbacks, and initialization scripts resolve from a clean checkout.
- [ ] Model update/compile succeeds without unresolved data, algebraic-loop, sample-time, or data-type errors.
- [ ] Dictionary filename capitalization matches the file on disk.
- [ ] Controller boundary is identifiable; plant and test sources remain outside it.
- [ ] Units, angle convention, phase order, and speed convention are documented.

## Mathematical Units

- [ ] Clarke transform matches the chosen amplitude/power scaling.
- [ ] Park followed by inverse Park reconstructs the alpha-beta vector within tolerance.
- [ ] Electrical angle uses the correct pole-pair conversion and wraps correctly.
- [ ] SVPWM covers every sector and boundary; duty remains in the documented range.
- [ ] Positive speed/current/torque signs agree across plant, sensor, and controller.

## Current Loop

- [ ] Current sampling is aligned with PWM and mapped to the fast task.
- [ ] d/q PI gains, discrete method, sample time, and limits are recorded.
- [ ] Current reference and voltage-vector limits match motor/inverter constraints.
- [ ] Anti-windup works during current and voltage saturation.
- [ ] Enable, disable, fault, and reset leave no stale duty or integrator state.
- [ ] Current steps are stable under bus and load variation.

## Startup, Rotor Feedback, and Speed Loop

- [ ] Alignment/open-loop/transition/closed-loop states have explicit guards and timeouts where applicable.
- [ ] Handoff is bumpless enough for current and torque limits.
- [ ] Rotor angle/speed validity is checked before closed loop.
- [ ] Hall direction and zero-speed behavior, or sensorless convergence range, is tested.
- [ ] Speed task period is an integer multiple of the current task period.
- [ ] Speed PI output is limited to safe `iq_ref`; reset/tracking behavior is verified.
- [ ] Observer diagnostics include angle/speed error against a reference, validity timeout, reset behavior, and low-speed convergence limits.
- [ ] SMO filtering/phase compensation and chattering, Luenberger discrete gain/poles, EKF `P/Q/R`/innovation/numeric health, or flux-observer drift/offset handling are verified as applicable.
- [ ] Hall `000`/`111`, illegal transitions, timeout, interpolation, direction reversal, and zero-speed behavior are tested as applicable.

## Hardware Integration

- [ ] A `ControlPlatformProfile` records the MCU/DSP, control clock, PWM/current-acquisition trigger, base period, peripheral ownership, data units, and generated-code call sites.
- [ ] PWM channel order, polarity, dead time, update/latch behavior, minimum pulse, and safe disabled command are recorded.
- [ ] Current acquisition trigger and sample position are synchronized to PWM and avoid invalid sampling windows.
- [ ] Current-front-end topology, gain, polarity, zero offset, saturation, and converter-channel mapping are calibrated.
- [ ] Comparator, gate-driver fault, or other independent overcurrent threshold and PWM-trip/gate-disable path are fault-injected.
- [ ] DC-bus scaling and undervoltage/overvoltage behavior are verified.
- [ ] Telemetry/calibration transport cannot block the fast loop or partially update a calibration set.
- [ ] Vendor SDK and generated controller have exactly one owner for PWM, sampling, position feedback, state machine, and fault handling.

## Scenario Tests

- [ ] Enable from rest and disable while running.
- [ ] Low, nominal, and high speed commands.
- [ ] Positive/negative reversal when supported.
- [ ] Load-torque step and release.
- [ ] DC-bus minimum/nominal/maximum and invalid reading.
- [ ] Current/angle/speed sensor fault or loss of validity.
- [ ] Overcurrent/fault response and recovery.
- [ ] Boundary numeric cases: zero, limits, wrap, and saturation.

## Code Generation

- [ ] Fixed-step base period is explicit and matches the firmware scheduler.
- [ ] No subsystem declares a period faster than the model base step; every periodic rate is an integer multiple.
- [ ] Rate transitions or function-call partitions are deterministic.
- [ ] ERT/C99 and actual production hardware configuration are selected when available.
- [ ] Non-finite, dynamic memory, continuous state, and unsupported block use are deliberate.
- [ ] Model Advisor or project code-generation checks have been reviewed.
- [ ] Code build succeeds and the report contains the expected entry points and data.
- [ ] Generated code is reproducible and contains no hand edits.
- [ ] Generated `*_initialize` is called exactly once before enable and `*_step` is called from the documented PWM/current-acquisition ISR or scheduler path.
- [ ] SIL/PIL or golden-vector comparison passes when available.
- [ ] Target worst-case execution time, stack, and memory meet budget.

## Evidence to Deliver

- test harness/model name and revision;
- parameter set and data dictionary revision;
- plots or logged assertions for the scenarios run;
- code-generation report/build log;
- generic audit from the companion `simulink-model-auditor` Skill plus its
  `audit_embedded_foc_model.m` FOC specialization;
- unresolved warnings, assumptions, and hardware tests still required.
