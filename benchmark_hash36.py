#!/usr/bin/env python3
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ALGOS = ["bcrypt\n(cost=12)", "scrypt\n(N=2^14)",
         "Argon2id\n(t=3,m=64M)", "HASH-36\n(Argon2id)"]
RTX_4090 = [184_000, 7_126, 4.9, 4.9]
RTX_5090 = [304_800, 7_760, 6.0, 6.0]
CPU_MS  = [20, 25, 18, 18]

fig, axes = plt.subplots(1, 2, figsize=(15, 6))
fig.suptitle("HASH-36 vs alternatives — Résistance GPU et coût CPU",
             fontsize=14, fontweight="bold")

ax = axes[0]
x = np.arange(len(ALGOS))
w = 0.38
b1 = ax.bar(x - w/2, RTX_4090, w, label="RTX 4090", color="#3b82f6")
b2 = ax.bar(x + w/2, RTX_5090, w, label="RTX 5090", color="#8b5cf6")
ax.set_yscale("log")
ax.set_ylabel("Débit (H/s) — log")
ax.set_title("Débit GPU attaquant (plus bas = mieux)")
ax.set_xticks(x)
ax.set_xticklabels(ALGOS)
ax.legend()
ax.grid(axis="y", alpha=0.3, which="both")
for bars in (b1, b2):
    for bar in bars:
        h = bar.get_height()
        ax.annotate(f"{h:,.0f}" if h >= 1 else f"{h:.1f}",
                    xy=(bar.get_x()+bar.get_width()/2, h),
                    xytext=(0, 3), textcoords="offset points",
                    ha="center", fontsize=8)

ax = axes[1]
colors = ["#f59e0b", "#ef4444", "#10b981", "#10b981"]
bars = ax.bar(ALGOS, CPU_MS, color=colors, edgecolor="black")
ax.set_ylabel("Temps vérification (ms)")
ax.set_title("Coût défenseur")
ax.grid(axis="y", alpha=0.3)
for bar, v in zip(bars, CPU_MS):
    ax.annotate(f"{v} ms", xy=(bar.get_x()+bar.get_width()/2, v),
                xytext=(0, 3), textcoords="offset points", ha="center")

factor = RTX_4090[0] / RTX_4090[2]
fig.text(0.5, 0.02,
         f"Facteur bcrypt → Argon2id/HASH-36 sur GPU : ~{factor:,.0f}×",
         ha="center", fontsize=11, style="italic",
         bbox=dict(boxstyle="round", fc="#fef3c7", ec="#f59e0b"))

plt.tight_layout(rect=[0, 0.05, 1, 0.95])
plt.savefig("hash36_benchmark.png", dpi=150, bbox_inches="tight")
print("OK hash36_benchmark.png")
