# Project Agent Instructions

本项目是湘潭大学 DSP 课程设计交付包，主题为“基于 MATLAB/Simulink 的机器人端无线控制系统设计”。

## 固定要求

- 所有文本、脚本、JSON、CSV、Markdown 文件统一使用 UTF-8 编码。
- Word 文档正文中文字体使用宋体，英文和数字使用 Times New Roman。
- MATLAB 仿真结果必须来自真实运行，不得手写或伪造实验数据。
- 报告中的图、表、公式、参考文献必须保持交叉引用一致。
- 报告写作需要进行 humanize 风格润色，避免模板化、空泛化和 AI 腔。
- 不使用 Vitis；本项目采用 MATLAB/Simulink 设计开发。

## 项目结构

- `matlab/`：MATLAB 仿真入口与 Simulink 模型生成逻辑。
- `models/`：生成的 Simulink 分层系统模型。
- `scripts/`：构建、绘图、报告生成和校验脚本。
- `src/dsp/`：DSP C/ASM 示例源码。
- `references/`：GB/T 7714 参考文献清单。
- `output/results/`：真实仿真 CSV/JSON 数据。
- `output/figures/`：报告插图、Simulink 截图、seaborn 论文风格结果图。
- `output/doc/`：最终 DOCX 报告和 PPT 制作说明书。
- `output/logs/`：MATLAB 运行、报告生成、humanize 和校验日志。

## 构建命令

优先使用 PowerShell 运行：

```powershell
.\scripts\build_all.ps1
```

该命令会依次执行：

1. MATLAB 仿真和 Simulink 模型生成。
2. Python/seaborn 论文风格图表绘制。
3. DOCX 报告生成。
4. DOCX 和产物完整性校验。

## 质量门槛

- `output/doc/基于MATLAB的机器人端无线控制系统设计报告.docx` 必须生成成功。
- `models/robot_wireless_control_system.slx` 必须存在。
- `output/figures/` 必须包含电路图、流程图、Simulink 模型截图和结果图。
- `output/logs/docx_validation.json` 必须显示无乱码替换字符。
- 正文中文字符数应保持在约 9500-10500 字。
- 若某项仿真失败，报告必须记录失败原因，不得补假数据。

## Git 提交注意

- 提交前运行 `.\scripts\build_all.ps1`。
- 保留 `output/` 中的最终交付物和验证证据。
- 不提交本地虚拟环境、MATLAB 临时文件、Word 临时锁文件、系统缓存或个人密钥。
