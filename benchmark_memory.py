#!/usr/bin/env python3
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ALGOS = ["bcrypt\n(cost=12)", "scrypt\n(N=2^14)",
         "scrypt\n(N=2^17)", "Argon2id/HASH-36\n(m=64 MiB)"]
MEM_KIB = [4, 16*1024, 128*1024, 64*1024]
MEM_MIB = [k/1024 for k in MEM_KIB]

fig, ax = plt.subplots(figsize=(10, 6))
colors = ["#ef4444", "#f59e0b", "#f97316", "#10b981"]
bars = ax.bar(ALGOS, MEM_MIB, color=colors, edgecolor="black", linewidth=1.2)
ax.set_yscale("log")
ax.set_ylabel("Mémoire par guess (MiB) — log")
ax.set_title("Memory-hardness : mémoire par tentative de hash",
             fontsize=13, fontweight="bold")
ax.grid(axis="y", alpha=0.3, which="both")
for bar, mib, kib in zip(bars, MEM_MIB, MEM_KIB):
    label = f"{mib:.0f} MiB" if mib >= 1 else f"{kib} KiB"
    ax.annotate(label, xy=(bar.get_x()+bar.get_width()/2, mib),
                xytext=(0, 6), textcoords="offset points",
                ha="center", fontsize=11, fontweight="bold")
ax.axhline(24*1024, color="#3b82f6", ls="--", lw=1.2, alpha=0.7)
ax.annotate("RTX 4090 : 24 GiB VRAM",
            xy=(3, 24*1024), xytext=(-0.4, 24*1024*0.55),
            fontsize=9, color="#1e40af",
            bbox=dict(boxstyle="round", fc="#dbeafe", ec="#3b82f6"))
fig.text(0.5, 0.02,
         "bcrypt (4 KiB) permet ~1 500x plus de guesses paralleles "
         "qu'Argon2id/HASH-36 (64 MiB).",
         ha="center", fontsize=10, style="italic",
         bbox=dict(boxstyle="round", fc="#fef3c7", ec="#f59e0b"))
plt.tight_layout(rect=[0, 0.05, 1, 1])
plt.savefig("hash36_memory.png", dpi=150, bbox_inches="tight")
print("OK hash36_memory.png")
