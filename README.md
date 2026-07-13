# Embedded FOC Simulink Codegen

面向 PMSM/BLDC 矢量控制与嵌入式 C 代码生成的 Codex Skill。它指导 Agent 从控制算法单元、闭环仿真、双闭环与启动逻辑，一直做到 ERT 代码生成、STM32/ARM 固件接口和验证交付。

> Skill 英文名已由 `speedloop-simulink-style` 更新为 `embedded-foc-simulink-codegen`。GitHub 仓库名暂时保留，原链接仍然有效。

## 这次增强了什么

- 不再只模仿单个 `speedloop.slx` 的外观，改为覆盖完整的 FOC 建模与部署流程。
- 增加 Clarke/Park、反 Park、SVPWM、电流环、速度环、启动状态机的分阶段构建与验证。
- 增加 Hall、Luenberger、SMO、EKF 等转子反馈方案的统一组件边界。
- 明确区分仿真对象与生成代码的控制器边界，防止把电机、逆变器、Scope 或测试激励生成进 MCU 代码。
- 把多速率模型和硬件时序关联起来：电流环对齐 PWM/ADC，速度环为电流环的整数倍。
- 增加 ERT、C99、ARM Cortex-M、数据字典、标定量、生成接口和固件调度契约。
- 增加只读 MATLAB 审计脚本，检查模型求解器、字典、控制器边界、Rate Transition、PI 和代码生成设置。
- 增加数学、环路、启动、故障、代码生成、SIL/PIL 与目标机时序的分层验证清单。

## 推荐架构

```text
Simulation Harness
├─ Command / Fault Stimulus
├─ Feedback Sampling and Type Conversion
├─ FOC_Controller or legacy FOC_Model
│  ├─ CommandAndModeManager
│  ├─ SpeedLoop                         slow task
│  ├─ CurrentLoop                       PWM/ADC fast task
│  │  ├─ Clarke
│  │  ├─ Park
│  │  ├─ DqCurrentController
│  │  ├─ InversePark
│  │  └─ SVPWM
│  ├─ StartupAndHandoff
│  ├─ RotorFeedback                     Hall/encoder/observer
│  └─ ProtectionAndLimits
├─ Inverter and PMSM Plant              simulation only
└─ Logging / Assertions / Scopes        simulation only
```

控制器输入输出应当具有稳定接口，并标明名称、单位、类型、量程、采样周期、初始化和无效数据处理。已有工程依赖 `FOC_Model`、`currloop`、`speedloop`、`tABC` 等接口时，Skill 会优先保持兼容，而不是为了好看强行改名。

## 采样周期原则

参考模型中常见两组配置：

- 教学双闭环：电流环 100 μs（10 kHz），速度环 1 ms（1 kHz）；
- 部分无感观测器模型：控制子系统 50 μs。

新版 Skill 不把这些数值当成所有项目的固定答案。实际应先确定 PWM 频率、ADC 采样时刻、计算预算和环路带宽，再令：

```text
Ts_speed = N × Ts_current, N 为正整数
```

跨速率信号必须说明保持、延迟、锁存或缓冲方式，并使用确定性的 Rate Transition、函数调用子系统或调度器映射。

## 安装

仓库名目前仍是 `speedloop-simulink-style`，但安装目录要使用新的 Skill 名：

```powershell
git clone https://github.com/YANG985-CMD/speedloop-simulink-style.git `
  "$HOME\.codex\skills\embedded-foc-simulink-codegen"
```

如果本机已经安装旧版，可改名并拉取更新：

```powershell
Rename-Item "$HOME\.codex\skills\speedloop-simulink-style" `
  "embedded-foc-simulink-codegen"
Set-Location "$HOME\.codex\skills\embedded-foc-simulink-codegen"
git pull
```

重新启动 Codex 会话后使用 `$embedded-foc-simulink-codegen`。

## 使用示例

```text
使用 $embedded-foc-simulink-codegen 创建一个用于 STM32G4 的 PMSM FOC 控制器，
电流环由 PWM/ADC 中断触发，速度环为 10 倍分频，并生成 ERT C99 代码。
```

```text
使用 $embedded-foc-simulink-codegen 审查当前 FOC_Model，检查电流环/速度环采样率、
PI 抗饱和、启动切换、数据字典、ERT 配置和生成代码接口。
```

```text
使用 $embedded-foc-simulink-codegen 为现有模型增加 Hall 与 SMO 可切换的 RotorFeedback，
保持原有 FOC_Model 端口和固件调用接口不变。
```

## 自动审计

在 MATLAB 中执行：

```matlab
addpath('scripts');
report = audit_embedded_foc_model('D:/project/motor_control.slx');
```

如果控制器不叫 `FOC_Controller` 或 `FOC_Model`：

```matlab
report = audit_embedded_foc_model('motor_control.slx', ...
    'ControllerPath', 'motor_control/MotorControl');
```

脚本只加载并更新模型，不保存文件。它输出 PASS/WARN/FAIL，并返回设置、端口、数据字典、PI、Rate Transition、函数调用发生器和功能识别结果。它不能替代闭环仿真、ERT 构建、SIL/PIL 或目标机最坏执行时间测试。

## 文件结构

```text
speedloop-simulink-style/
├─ SKILL.md
├─ README.md
├─ agents/
│  └─ openai.yaml
├─ scripts/
│  └─ audit_embedded_foc_model.m
└─ references/
   ├─ control-architecture.md
   ├─ embedded-codegen-contract.md
   ├─ reference-findings.md
   ├─ style-guide.md
   └─ verification-checklist.md
```

## 参考依据与原创说明

本次改良综合分析了用户本地的 STM32G4 Simulink FOC 开发手册 V13.1、本地 Clarke/Park、SVPWM、电流环、启动、速度环、Hall、Luenberger、SMO 与 EKF 模型族，以及旧版 Skill。仓库只保留重新组织和扩展后的通用工程方法、审计规则与原创文档，不上传参考 PDF、截图或原始模型文件。

具体设计依据与相对旧版的改良见 [`references/reference-findings.md`](references/reference-findings.md)。

## 依赖

- MATLAB 与 Simulink；
- 生成 ERT 代码通常需要 Embedded Coder；
- 电机/逆变器高保真对象可能需要 Simscape Electrical 或 Motor Control Blockset；
- SIL/PIL、模型测试和规范检查能力取决于已安装的 MathWorks 产品与目标支持包。
