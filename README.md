# 基于 MATLAB/Simulink 的机器人端无线控制系统设计

本交付包按任务书改为 MATLAB/Simulink 开发，不使用 Vitis。实验结果来自本机 MATLAB R2025a 实际运行，并记录 MATLAB Agentic Toolkit、Simulink Agentic Toolkit 与 MATLAB MCP Server 初始化状态；不手写或伪造数据。

## 复现命令

在 PowerShell 中运行：

```powershell
.\scripts\build_all.ps1
```

等价分步命令：

```powershell
& 'D:\Program Files\MATLAB\R2025a\bin\matlab.exe' -batch "cd('D:\resource\湘潭大学\dsp'); addpath('matlab'); run_all_simulations"
& 'C:\Users\86155\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'scripts/plot_publication_figures.py'
& 'C:\Users\86155\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'scripts/generate_report.py'
& 'C:\Users\86155\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'scripts/generate_ppt_guide.py'
& 'C:\Users\86155\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'scripts/validate_report.py'
```

## 主要产物

- 最终报告：`output/doc/基于MATLAB的机器人端无线控制系统设计报告.docx`
- PPT制作说明书：`output/doc/PPT制作说明书.md`
- MATLAB 仿真入口：`matlab/run_all_simulations.m`
- Simulink 模型：`models/robot_wireless_control_system.slx`
- Agentic Toolkit 状态：`output/logs/agentic_toolkit_status.json`
- Simulink 架构审查：`output/results/model_architecture_review.json`
- DSP 示例源码：`src/dsp/`
- 真实仿真数据：`output/results/`
- 报告插图：`output/figures/`，其中结果图由 Python seaborn 根据真实 CSV/JSON 重绘
- 运行与校验日志：`output/logs/`

## 已验证结果

- MATLAB 版本：R2025a
- Agentic Toolkit：SATK 初始化通过，MCP Server 存在，Simulink 烟雾仿真通过
- 电机仿真：90% 上升时间 0.173 s，超调 9.55%，正向稳态误差 0.95 rpm，最终速度 -600.36 rpm
- 视频仿真：平均载荷 36.24 Mbps，即 4.53 MB/s，丢帧数 0
- 射频仿真：10 km 条件下最低控制信道 SNR 61.56 dB，最低视频信道 SNR 44.76 dB
- DOCX 校验：以 `output/logs/docx_validation.json` 为准，要求无乱码替换字符、引用连续、正文约 9500-10500 中文字符

## 说明

报告中的实验结果均为软件仿真结果，不声称为实物板卡测试、10 km 外场测试或真实硬件采样。封面身份信息未提供，保留为“待填写”。
