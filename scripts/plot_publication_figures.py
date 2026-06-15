#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Create publication-style figures from real simulation CSV outputs.

This script uses seaborn/matplotlib and overwrites the report figures generated
by MATLAB with higher quality multi-panel plots. It never synthesizes data.
"""

from __future__ import annotations

import json
from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RESULTS_DIR = PROJECT_ROOT / "output" / "results"
FIGURES_DIR = PROJECT_ROOT / "output" / "figures"
LOGS_DIR = PROJECT_ROOT / "output" / "logs"


def configure_style() -> None:
    sns.set_theme(context="paper", style="whitegrid", font="DejaVu Sans")
    mpl.rcParams.update(
        {
            "figure.dpi": 180,
            "savefig.dpi": 400,
            "axes.linewidth": 0.8,
            "axes.labelsize": 9,
            "axes.titlesize": 9,
            "xtick.labelsize": 8,
            "ytick.labelsize": 8,
            "legend.fontsize": 8,
            "legend.frameon": False,
            "grid.linewidth": 0.35,
            "lines.linewidth": 1.35,
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
        }
    )


def save(fig: plt.Figure, name: str) -> None:
    out = FIGURES_DIR / name
    fig.savefig(out, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def plot_motor() -> None:
    df = pd.read_csv(RESULTS_DIR / "motor_response.csv")
    summary = json.loads((RESULTS_DIR / "motor_summary.json").read_text(encoding="utf-8"))
    colors = sns.color_palette("colorblind", 6)
    fig, axes = plt.subplots(3, 1, figsize=(7.2, 6.0), sharex=True)

    sns.lineplot(data=df, x="time_s", y="target_speed_rpm", ax=axes[0], color="0.25", linestyle="--", label="Reference")
    sns.lineplot(data=df, x="time_s", y="speed_rpm", ax=axes[0], color=colors[0], label="Motor speed")
    axes[0].axvline(summary["reverse_time_s"], color="0.45", linestyle=":", linewidth=0.9)
    axes[0].set_ylabel("Speed (rpm)")
    axes[0].set_xlabel("")
    axes[0].set_title(
        f"Closed-loop speed response: $t_{{90}}$={summary['rise_time_90_s']:.3f}s, overshoot={summary['overshoot_percent']:.2f}%"
    )

    sns.lineplot(data=df, x="time_s", y="current_a", ax=axes[1], color=colors[3])
    axes[1].axhline(summary["max_current_a"], color="0.45", linestyle=":", linewidth=0.8)
    axes[1].axhline(-summary["max_current_a"], color="0.45", linestyle=":", linewidth=0.8)
    axes[1].set_ylabel("Current (A)")
    axes[1].set_xlabel("")

    sns.lineplot(data=df, x="time_s", y="pwm_duty", ax=axes[2], color=colors[2])
    axes[2].set_ylabel("PWM duty")
    axes[2].set_xlabel("Time (s)")
    axes[2].set_ylim(-0.05, 1.05)

    for ax in axes:
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
    save(fig, "motor_response.png")


def plot_video() -> None:
    df = pd.read_csv(RESULTS_DIR / "video_buffer.csv")
    summary = json.loads((RESULTS_DIR / "video_summary.json").read_text(encoding="utf-8"))
    colors = sns.color_palette("colorblind", 6)
    fig, axes = plt.subplots(3, 1, figsize=(7.2, 6.0), sharex=True)

    sns.lineplot(data=df, x="time_s", y="video_payload_mbps", ax=axes[0], color=colors[0], label="Video payload")
    sns.lineplot(data=df, x="time_s", y="rf_capacity_mbps", ax=axes[0], color=colors[3], label="RF capacity")
    axes[0].set_ylabel("Rate (Mbps)")
    axes[0].set_xlabel("")
    axes[0].set_title(
        f"Video traffic under VHF capacity variation: mean payload={summary['mean_payload_MBps']:.2f} MB/s"
    )

    sns.lineplot(data=df, x="time_s", y="buffer_mb", ax=axes[1], color=colors[2])
    axes[1].axhline(32, color="0.45", linestyle=":", linewidth=0.8)
    axes[1].set_ylabel("Buffer (MB)")
    axes[1].set_xlabel("")

    sns.lineplot(data=df, x="time_s", y="latency_ms", ax=axes[2], color=colors[4])
    axes[2].set_ylabel("Latency (ms)")
    axes[2].set_xlabel("Time (s)")

    for ax in axes:
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
    save(fig, "video_buffer.png")


def plot_rf() -> None:
    budget = pd.read_csv(RESULTS_DIR / "rf_link_budget.csv")
    ber = pd.read_csv(RESULTS_DIR / "rf_ber_curve.csv")
    summary = json.loads((RESULTS_DIR / "rf_summary.json").read_text(encoding="utf-8"))
    colors = sns.color_palette("colorblind", 6)
    fig, axes = plt.subplots(1, 2, figsize=(7.4, 3.3))

    budget_melt = budget.melt(
        id_vars=["frequency_mhz"],
        value_vars=["control_snr_db", "video_snr_db"],
        var_name="Channel",
        value_name="SNR_dB",
    )
    budget_melt["Channel"] = budget_melt["Channel"].map(
        {"control_snr_db": "Control", "video_snr_db": "Video"}
    )
    sns.lineplot(
        data=budget_melt,
        x="frequency_mhz",
        y="SNR_dB",
        hue="Channel",
        marker="o",
        ax=axes[0],
        palette=[colors[0], colors[3]],
    )
    axes[0].set_xlabel("Frequency (MHz)")
    axes[0].set_ylabel("SNR (dB)")
    axes[0].set_title(f"10 km VHF link margin; min video SNR={summary['min_video_snr_db']:.2f} dB")

    sns.lineplot(data=ber, x="ebn0_db", y="ber_simulated", ax=axes[1], color=colors[0], marker="o", label="Simulated")
    sns.lineplot(data=ber, x="ebn0_db", y="ber_theory", ax=axes[1], color="0.20", linestyle="--", label="Theory")
    axes[1].set_yscale("log")
    axes[1].set_xlabel("$E_b/N_0$ (dB)")
    axes[1].set_ylabel("BER")
    axes[1].set_title("BPSK reliability check")
    axes[1].set_ylim(1e-7, 1)

    for ax in axes:
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
    save(fig, "rf_link_ber.png")


def plot_summary() -> None:
    motor = json.loads((RESULTS_DIR / "motor_summary.json").read_text(encoding="utf-8"))
    video = json.loads((RESULTS_DIR / "video_summary.json").read_text(encoding="utf-8"))
    rf = json.loads((RESULTS_DIR / "rf_summary.json").read_text(encoding="utf-8"))
    data = pd.DataFrame(
        [
            {"Metric": "Motor rise time", "Value": motor["rise_time_90_s"], "Unit": "s"},
            {"Metric": "Motor overshoot", "Value": motor["overshoot_percent"], "Unit": "%"},
            {"Metric": "Video payload", "Value": video["mean_payload_MBps"], "Unit": "MB/s"},
            {"Metric": "Max buffer", "Value": video["max_buffer_mb"], "Unit": "MB"},
            {"Metric": "Min control SNR", "Value": rf["min_control_snr_db"], "Unit": "dB"},
            {"Metric": "Min video SNR", "Value": rf["min_video_snr_db"], "Unit": "dB"},
        ]
    )
    fig, ax = plt.subplots(figsize=(7.2, 3.8))
    sns.barplot(data=data, y="Metric", x="Value", hue="Unit", dodge=False, ax=ax, palette="colorblind")
    ax.set_xlabel("Value")
    ax.set_ylabel("")
    ax.set_title("System-level performance summary from reproducible simulation outputs")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    for container in ax.containers:
        ax.bar_label(container, fmt="%.2f", padding=3, fontsize=8)
    save(fig, "system_performance_summary.png")


def main() -> None:
    configure_style()
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    plot_motor()
    plot_video()
    plot_rf()
    plot_summary()
    (LOGS_DIR / "publication_figures.log").write_text(
        "Generated seaborn publication-style figures from CSV/JSON simulation outputs.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
