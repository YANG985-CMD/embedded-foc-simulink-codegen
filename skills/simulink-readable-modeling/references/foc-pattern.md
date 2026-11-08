# Optional PMSM/BLDC FOC pattern

Use this pattern only for an applicable motor-control task. It is not a required hierarchy for other Simulink domains.

```text
Drive test harness
├─ Scenario and calibrated/sampled measurements
├─ FOC controller model
│  └─ FOC_Model
│     ├─ Control_State
│     ├─ speedloop
│     └─ currloop
│        ├─ Current_Transform: Clarke, SinCos, Park
│        ├─ Current_Allocation: reference limits, optional MTPA/FW maps
│        ├─ idq_Controller
│        │  ├─ Decoupling_Feedforward
│        │  ├─ D_Axis_PI
│        │  ├─ Q_Axis_PI
│        │  └─ Voltage_Vector_Limit
│        └─ Modulation: inverse transforms, common mode, duty
├─ PWM and inverter
└─ Motor, mechanical load and records
```

Keep d/q PI channels visually parallel. An example stable interface is reference, feedback, feedforward voltage, limited voltage, and run/reset state. A coupled voltage-vector limiter may need its limited voltage returned to both PI anti-windup paths. Preserve that contract when choosing between a PID block and an explicit native-block PI implementation.

For sampled currents, specify whether phase amplitudes or RMS values are used. Define the Clarke/Park scaling, phase sequence, electrical angle and pole-pair conversion. Keep the voltage/current constraints and map assumptions consistent with the motor and bus.

Possible controller inputs include three phase currents (A), bus voltage (V), run request, speed reference/feedback (mechanical rpm or a documented alternative), electrical angle (rad), and strategy selection. Possible outputs are normalized duty, run interlock, and bounded diagnostics. These are examples, not fixed counts or types for every board.

Separate position feedback/estimation and startup handling into identifiable functions. Retain the actual design's enable, alignment, ramp, handoff, fault and reset behavior rather than adding or deleting states for visual symmetry.

A synchronous 100 microsecond controller and a 2.5 microsecond switched plant were used in the original layout exercise. They are example conditions; choose new periods from PWM, acquisition and processor timing. Likewise, no example motor constants, gains, current limits, or timer counts are default settings for a new motor.
