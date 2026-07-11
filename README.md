# SpeedLoop Simulink Style

面向 BLDC/PMSM 矢量控制的 Simulink Agent Skill，用于按照统一、可读、适合代码生成的 SpeedLoop 风格创建、修改和审查 FOC 速度环模型。

该技能把一个参考 `speedloop.slx` 工程的模型层级、端口顺序、模块选择、数据字典、求解器和 ERT 代码生成约束提炼成可复用规范。仓库不包含原始 `.slx` 模型。

## 核心功能

- **构建FOC模型**：支持速度环、电流环、Clarke/Park/AntiPark、SVPWM、逆变器和PMSM对象。
- **统一模型架构**：按照测试平台 → `FOC_Model` → `speedloop`/`currloop` → 变换与控制子系统分层。
- **块图优先**：优先使用可见Simulink模块，避免无必要的MATLAB Function黑盒。
- **嵌入式友好**：采用定步长、原子子系统、`single` 数据类型、数据字典和 `ert.tlc` 配置。
- **控制器规范**：速度和dq电流控制使用Simulink PID Controller、Forward Euler和clamping抗积分饱和。
- **模型审查**：检查端口、Rate Transition、复位逻辑、PI限幅、数据字典和代码生成设置。
- **验证流程**：更新模型图并在测试平台存在时执行短时仿真。

## 推荐模型层级

```text
Top-level Test Harness
├─ Stimulus / Feedback Conversion
├─ Rate Transition
├─ FOC_Model (Atomic)
│  ├─ speedloop
│  │  └─ Speed PI → iqRef
│  └─ currloop (Atomic)
│     ├─ State / Enable Logic
│     ├─ Clark
│     ├─ Park
│     ├─ idq_Controller
│     ├─ AntiPark
│     └─ SVPWM (Atomic)
├─ Average-Value Inverter
├─ Surface Mount PMSM
└─ Scopes / Goto / From Probes
```

## 关键建模约定

| 项目 | 默认规范 |
| --- | --- |
| 求解器 | Fixed-step / `FixedStepAuto` |
| 基准步长 | `1e-4` |
| 代码生成目标 | `ert.tlc` |
| 主要信号类型 | `single` |
| 参数管理 | 模型旁的 `.sldd` 数据字典 |
| PI积分方法 | Forward Euler |
| 抗积分饱和 | clamping |
| 控制层接口 | Rate Transition保证确定性传输 |

## 典型接口

`FOC_Model` 输入顺序：

```text
ia, ib, ic, v_bus, Motor_OnOff, SpeedRef, SpeedFd, theta
```

输出：

```text
tABC
```

`currloop` 输入顺序：

```text
ia, ib, ic, v_bus, Motor_OnOff, iq_ref, theta
```

输出：

```text
tABC, SpeedReset
```

## 安装

将仓库克隆到Codex技能目录：

```powershell
git clone https://github.com/YANG985-CMD/speedloop-simulink-style.git `
  "$HOME\.codex\skills\speedloop-simulink-style"
```

重新启动Codex会话后，即可在Simulink电机控制任务中使用该技能。

## 使用示例

```text
使用 $speedloop-simulink-style 创建一个PMSM FOC速度环模型，包含速度PI、电流PI、Clarke/Park、AntiPark和SVPWM。
```

```text
使用 $speedloop-simulink-style 检查当前模型是否符合定步长、数据字典和ERT代码生成要求。
```

```text
按照SpeedLoop风格重构当前FOC_Model，保留现有参数和代码生成配置。
```

## 文件结构

```text
speedloop-simulink-style/
├─ SKILL.md
├─ README.md
├─ agents/
│  └─ openai.yaml
└─ references/
   └─ style-guide.md
```

更具体的端口顺序、PI参数名、子系统原子性和审查清单见 [`references/style-guide.md`](references/style-guide.md)。

## 依赖说明

- 创建和仿真模型需要MATLAB与Simulink。
- 使用PMSM/逆变器对象时可能需要Simscape Electrical或相应电机控制产品。
- 生成ERT代码通常需要Embedded Coder。

