# Project Structure

```text
dsp/
├─ AGENTS.md
├─ README.md
├─ PROJECT_STRUCTURE.md
├─ 基于DSP与Vitis-Tutorials的机器人端无线控制设计任务书.md
├─ matlab/
│  └─ run_all_simulations.m
├─ models/
│  └─ robot_wireless_control_system.slx
├─ references/
│  └─ references_gbt7714.json
├─ scripts/
│  ├─ build_all.ps1
│  ├─ generate_report.py
│  ├─ plot_publication_figures.py
│  └─ validate_report.py
├─ src/
│  └─ dsp/
│     ├─ motor_control.c
│     ├─ rf_packet.c
│     ├─ isr_stub.asm
│     └─ README.md
└─ output/
   ├─ doc/
   ├─ figures/
   ├─ logs/
   └─ results/
```

`output/` 在本项目中不是临时目录，而是最终交付物和验证证据目录，因此需要纳入版本管理。
