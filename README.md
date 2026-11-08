# 使用过程中有任何缺点或者bug欢迎联系1829631824@qq.com


# Simulink FOC Skills

## 1. `embedded-foc-simulink-codegen`

FOC 执行 Skill。负责 PMSM/BLDC 的 Clarke/Park、dq 电流环、速度环、SVPWM、启动切换、转子反馈、多速率时序、嵌入式接口和受控代码生成。通用硬件路径进一步覆盖同步 PWM-电流采样链、模拟前端、独立硬件保护、Hall/编码器低速与反转、Luenberger/SMO/EKF/非线性磁链观测器、遥测标定，以及厂商 SDK 与生成代码的迁移边界。

## 2. `simulink-model-auditor`

通用审计 Skill。可以审计任意 Simulink 模型或子系统，不限于 FOC。检查求解器、采样率、结构连接、模型引用、库链接、数据字典、编译数据类型和代码生成配置；对 FOC 模型再增加 PI、Rate Transition、控制器边界和启动相关专项检查。

## 3. `simulink-readable-modeling`

[Simulink 清晰建模与模块移植](skills/simulink-readable-modeling/SKILL.md)。用于新建或重构人能顺着信号读懂的模型：按功能分层、主链从左到右、同类支路对齐、共用信号就近标注、端口说明单位与周期，并把可复用控制器与采样、日志、逆变器和电机试验台分开。

同时覆盖重排后的端口顺序核对、重复边界信号整理、参数字典管理，以及授权范围内的独立构建与同输入回放。它可独立用于通用 Simulink 布局和重构；FOC 设计时与另外两个 Skill 配合。附带只读 `audit_readable_layout` 工具，检查同层块边界重叠、占位端口名和小字体，实际布线与标签仍通过真实模型视图复查。

三个 Skill 与以下 MathWorks 官方项目配合使用：
- [Simulink Agentic Toolkit](https://github.com/simulink/simulink-agentic-toolkit)
- [MATLAB Agentic Toolkit](https://github.com/matlab/matlab-agentic-toolkit)
- [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server)
- codex自动配置指令：https://github.com/YANG985-CMD/embedded-foc-simulink-codegen 帮我配置一下这个项目，以及这个项目README里面链接下的matlab官方mcp和skill也要配置一下。
## 模型展示

### FOC 闭环仿真系统

控制器与逆变器、PMSM 电机对象分离，形成完整的闭环仿真平台。

[![FOC 闭环仿真系统](skills/embedded-foc-simulink-codegen/assets/speedloop-system-overview.png)](skills/embedded-foc-simulink-codegen/assets/speedloop-system-overview.png)

### FOC 控制器架构

速度环生成 q 轴电流参考，快速电流环完成坐标变换、电流调节和 PWM 调制。

[![FOC 控制器架构](skills/embedded-foc-simulink-codegen/assets/foc-controller-architecture.png)](skills/embedded-foc-simulink-codegen/assets/foc-controller-architecture.png)

### dq 电流环与 SVPWM

快速控制链包含 Clarke、Park、dq 电流 PI、反 Park、SVPWM、启动和闭环切换逻辑。

[![dq 电流环与 SVPWM](skills/embedded-foc-simulink-codegen/assets/foc-current-loop.png)](skills/embedded-foc-simulink-codegen/assets/foc-current-loop.png)

## 通用硬件与观测器能力

Skill 先建立平台无关的 `ControlPlatformProfile`，再将目标 MCU/DSP 的 PWM、同步电流采集、模拟前端、硬件 Trip、位置反馈、通信和调度映射到统一适配边界。STM32G4 的 TIM1/ADC/OPAMP/COMP-DAC/FDCAN/MCSDK 只是其中一个具体映射。规则会检查：

- PWM 与电流采集时序、模拟前端增益与偏置、独立过流关断；
- I-F 启动、观测器切换、Hall/编码器非法状态、插值和零速反转；
- Luenberger、SMO、EKF、非线性磁链观测器各自的参数、数值稳定性和验证指标；
- 生成模型初始化与快速步函数的真实固件调用位置；
- UART、CAN、USB 或其他遥测标定数据的限幅、原子更新和快速环隔离；
- 厂商电机控制 SDK 与 Simulink 生成控制器的外设和调度所有权。

详细执行规则位于 [`hardware-integration-and-observers.md`](skills/embedded-foc-simulink-codegen/references/hardware-integration-and-observers.md)。

## 为什么是强强联合

这个仓库不是重复实现通用 Simulink 工具，而是在 MathWorks 官方 Simulink Skills 和 MATLAB MCP 之上增加 FOC 专业能力与工程门禁。

| MathWorks 官方 Skill/MCP | 本仓库的 Skill | 联合后的效果 |
| --- | --- | --- |
| `model_overview`、`model_read`、`model_query_params` | FOC 架构、角度约定、启动切换和多速率规则 | 先理解真实模型，再作专业判断，减少凭名称猜测 |
| `model_edit`、`model_check` | 控制器/电机边界和可生成代码约束 | 形成“读取 → 修改 → 复查 → 结构检查”的闭环 |
| 官方布局与子系统重构工具 | 清晰分层、对齐支路、物理端口名和模块依赖契约 | 人能阅读和维护，控制模块可独立迁移 |
| `SimulationInput`、`model_test` | 启动、反转、负载阶跃、故障和抗饱和场景 | 将 FOC 要求转成可重复的仿真与行为测试 |
| 项目、数据字典和模型引用管理 | 标定参数、固件接口与所有权规则 | 模型、数据和生成代码接口保持一致 |
| Model Advisor 与 MATLAB 静态分析 | 通用审计 + FOC 专项审计 | 同时获得官方检查证据和领域风险报告 |
| MATLAB/Simulink/Embedded Coder 执行能力 | deployment profile、硬件安全清单和显式授权 | 审计有 FAIL 或未明确授权时拒绝调用 `slbuild` |

官方工具负责操作和检查模型；`embedded-foc-simulink-codegen` 负责 FOC 领域设计；`simulink-readable-modeling` 负责图形组织、重构和可移植模块边界；`simulink-model-auditor` 负责核对后续验证或部署的条件。



## 安装

先克隆仓库，再把需要的 Skill 目录复制到 Codex 的 skills 目录：

```powershell
git clone https://github.com/YANG985-CMD/embedded-foc-simulink-codegen.git .\simulink-skills
Copy-Item .\simulink-skills\skills\embedded-foc-simulink-codegen `
  "$HOME\.codex\skills\embedded-foc-simulink-codegen" -Recurse
Copy-Item .\simulink-skills\skills\simulink-model-auditor `
  "$HOME\.codex\skills\simulink-model-auditor" -Recurse
Copy-Item .\simulink-skills\skills\simulink-readable-modeling `
  "$HOME\.codex\skills\simulink-readable-modeling" -Recurse
```

也可以单独安装清晰建模 Skill。要使用 FOC 代码生成门禁，需要同时安装 `embedded-foc-simulink-codegen` 和 `simulink-model-auditor`。

## 使用示例

新建或整理模型：

```text
使用 $simulink-readable-modeling 参考已有工程重构这个模型。
让主控制链、d/q 支路、端口和采样周期便于人阅读，把控制器与试验台分开；
保留原有参数和算法，并对比重构前后的相同工况数据。
```

审计任意模型：

```text
使用 $simulink-model-auditor 审计这个 Simulink 模型。先调用官方
model_overview、model_read、model_check，再运行 simulation profile 的本地审计。
不要修改模型，也不要生成代码。
```

执行 FOC 修改：

```text
使用 $embedded-foc-simulink-codegen 为目标 MCU/DSP 创建一个 PMSM FOC 控制器。
严格使用官方 Simulink MCP 修改模型；完成后调用 $simulink-model-auditor 做通用审计和 FOC 专项审计。
```

## 本地审计脚本

```matlab
addpath('skills/simulink-model-auditor/scripts');

% 任意 Simulink 模型
generic = audit_simulink_model('any_model.slx', ...
    'Profile', 'simulation', ...
    'OutputFile', 'artifacts/simulink-audit.json');

% FOC 专项审计
foc = audit_embedded_foc_model('motor_control.slx', ...
    'ControllerPath', 'motor_control/FOC_Controller', ...
    'Profile', 'deployment', ...
    'OutputFile', 'artifacts/foc-audit.json');
```

审计脚本只读模型，不会保存修改。`READY` 只表示脚本检查通过，不等于功能正确、标准合规或硬件安全；仍需官方 `model_test`、Model Advisor、SIL/PIL、目标机时序和硬件保护验证。

清晰建模的只读布局检查（模型已打开）：

```matlab
addpath('skills/simulink-readable-modeling/scripts');
layout = audit_readable_layout('motor_control', 'Recursive', true);
```

该工具不加载、编译、修改或保存模型。报告列出实际覆盖的视图；块边界检查不包含标签范围和线的路由，需结合实际图形检查。详见 [布局检查说明](skills/simulink-readable-modeling/references/layout-audit.md)。

## 代码生成门禁

```matlab
addpath('skills/simulink-model-auditor/scripts');
addpath('skills/embedded-foc-simulink-codegen/scripts');
build = run_embedded_foc_codegen('motor_control.slx', ...
    'ControllerPath', 'motor_control/FOC_Controller', ...
    'ConfirmBuild', true);
```

没有明确的 `ConfirmBuild=true`，或通用/FOC deployment audit 存在 FAIL，脚本不会调用 `slbuild`。

## 验证

```matlab
results = runtests('tests');
assertSuccess(results);
```

GitHub Actions 使用 MathWorks 官方 `setup-matlab@v3` 和 `run-tests@v3`，以 R2024b 作为稳定测试基线；CI 不执行真实 Embedded Coder 构建。

本地测试可通过环境变量 `SIMULINK_SKILL_TEST_TMP` 指定临时夹具目录；未设置时使用 MATLAB 默认临时目录。

## 目录

```text
skills/embedded-foc-simulink-codegen/  FOC 执行 Skill
skills/simulink-model-auditor/        通用 + FOC 审计 Skill
skills/simulink-readable-modeling/    清晰建模、布局重构与模块移植 Skill
tests/                               三个 Skill 的 MATLAB utility tests
.github/workflows/matlab-tests.yml    GitHub Actions
```
