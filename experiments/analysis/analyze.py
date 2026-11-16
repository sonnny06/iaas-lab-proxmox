#!/usr/bin/env python3
"""analyze.py - tong hop va ve bieu do thi nghiem. Chay tu goc repo:
   python experiments/analysis/analyze.py"""
import os
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
EXP = os.path.abspath(os.path.join(HERE, ".."))
FIG = os.path.join(HERE, "figures")
TAB = os.path.join(HERE, "tables")
os.makedirs(FIG, exist_ok=True)
os.makedirs(TAB, exist_ok=True)


def load(rel):
    p = os.path.join(EXP, rel)
    if not os.path.exists(p):
        print("THIEU FILE:", rel)
        return None
    return pd.read_csv(p)


def save_table(df, name):
    df = df.round(2)
    df.to_csv(os.path.join(TAB, name + ".csv"), index=False)
    cols = list(df.columns)
    print("\n## " + name)
    print("| " + " | ".join(cols) + " |")
    print("|" + "---|" * len(cols))
    for _, r in df.iterrows():
        print("| " + " | ".join(str(r[c]) for c in cols) + " |")


def savefig(fig, name):
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, name), dpi=150)
    plt.close(fig)
    print("Da luu hinh:", name)


# ---------- Baseline ----------
base = load("00-baseline/results.csv")
base_cpu = base["cpu_bogo_ops_s"].mean() if base is not None else None

# ---------- 1) CPU overcommit ----------
cpu = load("01-cpu-overcommit/results.csv")
if cpu is not None:
    pr = (cpu.groupby(["cores_per_vm", "total_vcpu", "ratio", "run"])
             .agg(per_vcpu=("bogo_per_vcpu", "mean"),
                  total=("bogo_ops_s", "sum"),
                  steal=("steal_pct", "mean")).reset_index())
    t = (pr.groupby(["cores_per_vm", "total_vcpu", "ratio"])
           .agg(per_vcpu=("per_vcpu", "mean"), per_vcpu_sd=("per_vcpu", "std"),
                total=("total", "mean"), total_sd=("total", "std"),
                steal=("steal", "mean")).reset_index()
           .sort_values("ratio").reset_index(drop=True))
    ref = base_cpu if base_cpu else t["per_vcpu"].iloc[0]
    t["pct_of_ref"] = t["per_vcpu"] / ref * 100
    t["total_vs_first_pct"] = t["total"] / t["total"].iloc[0] * 100
    t["cv_pct"] = t["per_vcpu_sd"] / t["per_vcpu"] * 100
    save_table(t, "cpu_overcommit")
    if (t["cv_pct"] > 15).any():
        print("CANH BAO: CV > 15% o cau hinh CPU, can ghi chu hoac chay lai")

    labels = ["%.1f:1" % r for r in t["ratio"]]
    fig, ax = plt.subplots(1, 2, figsize=(10, 4))
    ax[0].bar(labels, t["pct_of_ref"], yerr=t["per_vcpu_sd"] / ref * 100, capsize=4)
    ax[0].set_xlabel("Tỷ lệ vCPU : pCPU")
    ax[0].set_ylabel("Hiệu năng mỗi vCPU (% so với baseline)" if base_cpu
                     else "Hiệu năng mỗi vCPU (% so với cấu hình đầu)")
    ax[0].set_title("Hiệu năng mỗi vCPU")
    ax[1].bar(labels, t["total_vs_first_pct"])
    ax[1].set_xlabel("Tỷ lệ vCPU : pCPU")
    ax[1].set_ylabel("Tổng công việc của cả nhóm VM (% so với cấu hình đầu)")
    ax[1].set_title("Tổng công việc làm được")
    savefig(fig, "fig1_cpu_overcommit.png")

# ---------- 2) RAM overcommit ----------
ram = load("02-ram-overcommit/results.csv")
if ram is not None:
    ram["cfg"] = ram["k"].astype(str) + "x " + ram["mode"]
    t = (ram.groupby("cfg", sort=False)
            .agg(total_alloc_MB=("total_alloc_MB", "mean"),
                 guest_mem_MB=("guest_mem_MB", "mean"),
                 bogo=("bogo_per_vm", "mean"), bogo_sd=("bogo_per_vm", "std"),
                 swapout_MiB=("swapout_MiB", "mean"),
                 ping_avg_ms=("ping_avg_ms", "mean"),
                 ping_max_ms=("ping_max_ms", "max"),
                 loss_pct=("loss_pct", "mean"),
                 oom_events=("oom_events", "sum"),
                 alive_min=("alive_vms", "min")).reset_index())
    t["pct_of_first"] = t["bogo"] / t["bogo"].iloc[0] * 100
    save_table(t, "ram_overcommit")

    fig, ax = plt.subplots(1, 3, figsize=(13, 4))
    ax[0].bar(t["cfg"], t["pct_of_first"], yerr=t["bogo_sd"] / t["bogo"].iloc[0] * 100, capsize=4)
    ax[0].set_title("Hiệu năng bộ nhớ mỗi VM (% so với cấu hình đầu)")
    ax[1].bar(t["cfg"], t["swapout_MiB"])
    ax[1].set_title("Dữ liệu host đẩy ra swap (MiB)")
    ax[2].bar(t["cfg"], t["ping_max_ms"])
    ax[2].set_title("Độ trễ ping lớn nhất (ms)")
    for a in ax:
        a.tick_params(axis="x", rotation=30)
    savefig(fig, "fig2_ram_overcommit.png")

# ---------- 3) Noisy neighbor ----------
nz = load("03-noisy-neighbor/results.csv")
if nz is not None:
    order = {"cpu": ["alone", "noisy", "cpulimit", "cpuunits"],
             "io": ["alone", "noisy", "limited"],
             "net": ["alone", "noisy", "limited"]}
    rows = []
    fig, axes = plt.subplots(2, 3, figsize=(13, 7))
    for j, (sc, states) in enumerate(order.items()):
        d = nz[nz["scenario"] == sc]
        if d.empty:
            continue
        g = (d.groupby("state")
               .agg(m=("victim_metric", "mean"), sd=("victim_metric", "std"),
                    p99_us=("victim_p99_us", "mean"),
                    ping_avg=("ping_avg_ms", "mean"),
                    ping_p99=("ping_p99_ms", "mean"))
               .reindex(states).dropna(subset=["m"]))
        if "alone" not in g.index:
            continue
        b = g.loc["alone", "m"]
        g["pct_of_alone"] = g["m"] / b * 100
        g["pct_sd"] = g["sd"] / b * 100
        g = g.reset_index()
        g.insert(0, "scenario", sc)
        rows.append(g)
        axes[0][j].bar(g["state"], g["pct_of_alone"], yerr=g["pct_sd"], capsize=4)
        axes[0][j].axhline(100, ls="--", lw=0.8)
        axes[0][j].set_title(sc + ": nạn nhân so với alone (%)")
        axes[1][j].bar(g["state"], g["ping_p99"])
        axes[1][j].set_title(sc + ": ping p99 (ms)")
    if rows:
        save_table(pd.concat(rows), "noisy_neighbor")
        savefig(fig, "fig3_noisy_neighbor.png")

print("\nXong. Bang trong", TAB, "- hinh trong", FIG)
