# Hardware Integration and Rotor Observers

Apply this reference to any MCU, DSP, FPGA-assisted controller, inverter board, vendor motor-control SDK, or generated-code target. Map platform-specific names into stable control roles before changing the model or firmware.

## Contents

- Platform profile
- Hardware-adapter contract
- Timing and protection
- Position feedback and observers
- Startup and handoff
- Calibration and telemetry
- Vendor-SDK migration
- STM32G4 teaching-corpus mapping
- Verification evidence

## Platform Profile

Create a `ControlPlatformProfile` before deployment work. Record `unknown` instead of guessing.

| Field | Required content |
| --- | --- |
| target | MCU/DSP/SoC family, core, numeric assumptions, toolchain, vendor SDK |
| control clock | clock source, frequency, timer clock, interrupt priorities |
| PWM role | peripheral, channels, polarity, center/edge alignment, frequency, dead time, latch/update event |
| current acquisition | sensor topology, converter/peripheral, trigger, channel order, sample window, ISR/DMA owner |
| analog front end | shunt or sensor gain, bias, bandwidth, saturation, polarity, internal/external amplifier |
| hardware trip | comparator/gate-driver fault source, threshold, PWM trip/break route, latch and reset |
| other feedback | DC bus, phase voltage, temperature, Hall, encoder, resolver, index/zero |
| telemetry | UART, CAN, USB, SPI, Ethernet, or other transport, rate and task owner |
| scheduler | fast/slow/background entry points, periods, triggers, priorities, deadlines |
| generated API | initialize, fast step, slow step, reset, calibration exchange, output ownership |

Do not require a specific peripheral name. An advanced timer, ePWM, FlexPWM, MCPWM, FPGA PWM, or another deterministic unit may own the PWM role. ADC injected groups, start-of-conversion sequencers, queued converters, simultaneous ADCs, or external converters may own current acquisition.

## Hardware-Adapter Contract

Keep platform registers and vendor HAL calls outside the generated controller. Use one thin adapter with physical-unit and validity contracts:

```text
Hardware input adapter
  raw current/voltage/position samples
  -> offset, scale, polarity, plausibility, timestamp
  -> FocFeedback in A, V, rad, rad/s and validity/status

Generated controller
  FocCommand + FocFeedback + Calibration
  -> normalized duty or voltage request + state/fault diagnostics

Hardware output adapter
  controller output
  -> bus-aware clamp, timer/count conversion, latch/update
  -> PWM peripheral or gate disable
```

Document every adapter signal's unit, type, range, sample age, reset value, and owner. Keep the emergency trip independent of this software path.

## Timing and Protection

- Derive the fast period from the actual PWM and current-acquisition event.
- Place current samples inside valid conduction windows and account for switching transients, blanking, amplifier settling, converter acquisition time, and conversion latency.
- Record whether the control step uses the sample from the current, previous, or reconstructed PWM cycle.
- Verify complementary polarity, dead time, minimum pulse, bootstrap constraints, update/latch behavior, and safe disabled command.
- Route overcurrent or gate-driver fault directly to a PWM trip/break or gate-disable mechanism when hardware supports it.
- Record trip threshold in physical units and raw hardware units. Fault-inject the route without relying on the control task.
- Model measurement delay, offset, saturation, invalid windows, and bus-voltage error when they materially affect stability or observer accuracy.

Support one-, two-, or three-shunt, inline, isolated, Hall-effect, sigma-delta, or other current sensing. State the reconstruction and observability limits instead of assuming three ideal phase currents.

## Position Feedback and Observers

Hide every feedback source behind a common interface:

```text
inputs: sampled currents, applied voltage or duty, vdc, sensor edges/data, enable, reset
outputs: theta_e, omega_e or omega_m, valid, confidence/status, diagnostics
```

Keep reference-only angle/speed error, PLL error, confidence, EKF innovation, and SMO chattering indicators in the simulation/test harness. Compare feedback methods using the same plant, parameters, sample period, command, load, noise, and voltage-error model.

### Hall, encoder, and resolver

- Define electrical/mechanical units, direction, pole-pair conversion, zero offset, wrap, timeout, and invalid transitions.
- For Hall, verify all valid sectors, reject illegal states/transitions, bound interpolation time, and test zero-speed reversal.
- For encoder/resolver, verify count/resolution scaling, index or alignment behavior, overflow, signal loss, and low-speed differentiation/filter delay.

### Luenberger

- Define states and alpha-beta voltage/current conventions.
- Record observer gain, motor parameters, discrete period, PLL gains, wrap, and reset values.
- Check discrete poles/gain at the actual observer rate and test convergence from angle/state mismatch.

### Sliding-mode observer (SMO)

- Define switching law, boundary layer, observer gain, low-pass cutoff, phase compensation, and PLL gains.
- Measure chattering and angle lag across speed. Do not accept a clean speed trace as proof of angle accuracy.
- Gate handoff on validity and bounded angle/speed error, with timeout and fault behavior.

### Extended Kalman observer (EKF)

- Document state vector, discrete model, Jacobian, covariance `P`, process noise `Q`, measurement noise `R`, and initial state.
- Check covariance symmetry/numeric health, bound non-finite values, and test innovation under parameter mismatch, noise, voltage variation, and missed samples.
- Verify worst-case matrix-operation time on the target.

### Nonlinear flux observer

- Define voltage model, stator-resistance compensation, integration-drift handling, nonlinear correction, PLL, and reset.
- Test current offset, inverter voltage/dead-time error, low-speed observability, reversal, and restart.
- Do not claim zero-speed sensorless operation without an initial-position or startup method.

## Startup and Handoff

Use explicit states such as:

```text
Disabled -> Align -> I-F/OpenLoop -> Feedback Handoff -> ClosedLoop -> Fault
```

Record angle/speed source, limits, timeout, validity guard, and integrator action for each transition. Permit a valid Hall/encoder/resolver path to close at zero speed after direction/offset verification. Require a separate initial-position, alignment, or open-loop strategy for observers that are not observable at standstill.

## Calibration and Telemetry

Version and range-check motor parameters, sensor scales/offsets, bus scaling, PWM/dead-time values, position alignment, PI limits, observer/PLL gains, EKF `P/Q/R`, and startup thresholds.

Run telemetry and calibration exchange outside the fast task. Use any suitable transport, but prevent blocking I/O and partial parameter updates. Stage a complete calibration set, validate it, then latch it atomically at a documented synchronization point. Preserve last-known-good values after invalid writes or communication loss.

## Vendor-SDK Migration

Treat a vendor motor-control SDK and a Simulink-generated controller as separate ownership models:

1. Assign one owner for PWM, current acquisition, position feedback, state machine, and faults.
2. Do not connect two control schedulers to the same hardware event.
3. Retain only the required board/driver adapter when replacing an SDK controller.
4. Map raw units to the generated interface at one boundary.
5. Call generated initialization once before enable and call each step from its documented event.
6. Compare current sign, angle, duty polarity, dead time, sampling instant, and fault shutdown with a known-good baseline before closing the loop.

Apply this ownership rule to MCSDK or any other vendor/custom framework; do not encode SDK-specific APIs in the controller model.

## STM32G4 Teaching-Corpus Mapping

Use this as one concrete mapping, not as the generic architecture:

| Teaching folder | Generic role |
| --- | --- |
| `5.GPIO` to `12.CAN` | board I/O, telemetry, acquisition, PWM, analog front end, protection |
| `13.Clark`, `14.Park & AntiPark`, `15.SVPWM_VF` | transform and modulation algorithm units |
| `16.CurrLoop_IF`, `17.SpeedLoop` | current/speed control, startup, hardware adapter |
| `18.Lun_Model_Code`, `19.SMO_Model_Code`, `20.EKF_Model_Code` | rotor observer variants |
| `23.Nonlinear flux observer` | nonlinear flux-feedback variant |
| `24.HALL sensor speedloop` | Hall interpolation, zero-speed and reversal baseline |
| `25.VOFA+ GUI` | one telemetry/calibration implementation |

Map TIM1 to the PWM role, ADC/OPAMP to current acquisition/front end, COMP/DAC to hardware trip, UART/FDCAN to telemetry, and MCSDK to the vendor-SDK role. Preserve the existing model interface unless migration is explicitly requested and tested.

## Verification Evidence

- completed `ControlPlatformProfile` with no safety-critical unknowns;
- PWM/current-acquisition timing diagram or scope capture;
- current/voltage/position calibration and polarity results;
- independent overcurrent or driver-fault trip injection;
- feedback angle/speed comparison and validity timeout results;
- startup, handoff, stop, reversal, sensor loss, load step, and bus-variation tests;
- generated initialize/step call sites and scheduler ownership;
- telemetry atomic-update and fast-loop isolation evidence;
- target WCET, stack, memory, and unresolved platform assumptions.
