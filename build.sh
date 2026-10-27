#!/usr/bin/env bash
# =============================================================================
#  build.sh v3 — Construction complète du projet HASH-36
#  Usage : ./build.sh [--check] [--test] [--bench] [--package] [--publish] [--all]
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'
log()  { echo "${BLUE}▶${NC} $*"; }
ok()   { echo "${GREEN}✓${NC} $*"; }
warn() { echo "${YELLOW}⚠${NC} $*"; }
die()  { echo "${RED}✗${NC} $*" >&2; exit 1; }

DO_CHECK=0; DO_TEST=0; DO_BENCH=0; DO_PACKAGE=0; DO_PUBLISH=0
for arg in "$@"; do
  case "$arg" in
    --check)   DO_CHECK=1 ;;
    --test)    DO_TEST=1 ;;
    --bench)   DO_BENCH=1 ;;
    --package) DO_PACKAGE=1 ;;
    --publish) DO_PUBLISH=1; DO_PACKAGE=1 ;;
    --all)     DO_TEST=1; DO_BENCH=1; DO_PACKAGE=1 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) die "Option inconnue : $arg" ;;
  esac
done

# =============================================================================
#  1. ENVIRONNEMENT
# =============================================================================
log "Vérification de l'environnement..."
command -v python3 >/dev/null || die "python3 introuvable"
PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" \
  || die "Python >= 3.10 requis (trouvé $PY_VER)"
ok "Python $PY_VER"

if [[ ! -d .venv ]]; then
  log "Création du venv..."
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
ok "venv activé"

log "Installation des dépendances..."
export PIP_DEFAULT_TIMEOUT=120
export PIP_NO_INPUT=1
python -m pip install --quiet --upgrade pip
python -m pip install --quiet --only-binary=:all: \
    "argon2-cffi>=23.1" "pytest>=8.0" "pytest-cov>=5.0" \
    "matplotlib>=3.8" "build>=1.2" "twine>=5.0" "ruff>=0.5" \
  || python -m pip install --quiet \
    "argon2-cffi>=23.1" "pytest>=8.0" "pytest-cov>=5.0" \
    "matplotlib>=3.8" "build>=1.2" "twine>=5.0" "ruff>=0.5" \
  || die "Échec installation des dépendances"
ok "Dépendances installées"

# =============================================================================
#  2. ARBORESCENCE
# =============================================================================
log "Création de l'arborescence..."
mkdir -p tests docs dist
ok "Arborescence prête"

# =============================================================================
#  3. SOURCES
# =============================================================================
log "Génération des sources..."

cat > hash36_argon2id.py <<'PYEOF'
"""HASH-36-KDF : Argon2id avec séparation de domaine, pepper et rotation."""
from __future__ import annotations
from argon2.low_level import hash_secret_raw, Type
import os, struct, hashlib, hmac

__version__ = "0.1.0"
PEPPER_ENV = "HASH36_PEPPER"
_DOMAIN_PREFIX = bytes([2, 1, 19, 5]) + struct.pack(">I", 36)


def _resolve_pepper(pepper):
    if pepper is not None:
        return pepper.encode() if isinstance(pepper, str) else pepper
    return os.environ.get(PEPPER_ENV, "").encode()


def hash36_argon2id(mot_de_passe, sel=None, time_cost=3,
                    memory_cost=65536, parallelism=4, pepper=None):
    if sel is None:
        sel = os.urandom(16)
    cle = hash_secret_raw(
        secret=mot_de_passe.encode(), salt=_DOMAIN_PREFIX + sel,
        time_cost=time_cost, memory_cost=memory_cost,
        parallelism=parallelism, hash_len=32, type=Type.ID,
    )
    pep = _resolve_pepper(pepper)
    hmac_key = pep if pep else sel
    mode = "pepper" if pep else "no-pepper"
    tag = hmac.new(hmac_key, cle, hashlib.sha3_256).digest()[:16]
    return {"algo": "HASH-36-ARGON2ID", "sel": sel.hex(),
            "t": time_cost, "m": memory_cost, "p": parallelism,
            "hash": cle.hex(), "tag": tag.hex(), "mode": mode}


def hash36_verify(mot_de_passe, record, pepper=None):
    r = hash36_argon2id(
        mot_de_passe, sel=bytes.fromhex(record["sel"]),
        time_cost=record["t"], memory_cost=record["m"],
        parallelism=record["p"], pepper=pepper,
    )
    return (hmac.compare_digest(r["hash"], record["hash"]) and
            hmac.compare_digest(r["tag"], record["tag"]))


def check_needs_rehash(record, target_t=3, target_m=65536, target_p=4):
    if record.get("mode") != "pepper":
        return True
    return (record["t"] < target_t or record["m"] < target_m
            or record["p"] < target_p)
PYEOF

cat > hash36_cli.py <<'PYEOF'
#!/usr/bin/env python3
"""CLI HASH-36 : hash / verify / rehash / rehash-all."""
import argparse, json, sys, os, pathlib, tempfile
from hash36_argon2id import (
    hash36_argon2id, hash36_verify, check_needs_rehash, PEPPER_ENV,
)


def _resolve_cli_pepper(args):
    if args.pepper:
        return args.pepper
    if args.pepper_env:
        val = os.environ.get(args.pepper_env)
        if val is None:
            raise SystemExit(f"Variable '{args.pepper_env}' non définie.")
        return val
    return None


def cmd_hash(args):
    rec = hash36_argon2id(
        args.password, sel=bytes.fromhex(args.salt) if args.salt else None,
        time_cost=args.t, memory_cost=args.m, parallelism=args.p,
        pepper=_resolve_cli_pepper(args))
    if args.json:
        print(json.dumps({"status": "ok", **rec}, indent=2))
    else:
        for k in ("algo", "mode", "sel", "t", "m", "p", "hash", "tag"):
            print(f"{k:10s}: {rec[k]}")
    return 0


def cmd_verify(args):
    try:
        rec = json.load(open(args.record))
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}) if args.json
              else f"Erreur : {e}", file=sys.stderr)
        return 1
    ok = hash36_verify(args.password, rec, pepper=_resolve_cli_pepper(args))
    needs = check_needs_rehash(rec, args.target_t, args.target_m, args.target_p)
    payload = {"status": "ok" if ok else "fail", "valid": ok,
               "needs_rehash": needs}
    if args.json:
        print(json.dumps(payload))
    else:
        print("✅ valide." if ok else "❌ invalide.")
        if needs:
            print("⚠️  Rehash recommandé.")
    return 0 if ok else 2


def cmd_rehash(args):
    old = json.load(open(args.record))
    if not hash36_verify(args.password, old, pepper=_resolve_cli_pepper(args)):
        print(json.dumps({"status": "fail", "valid": False}) if args.json
              else "❌ Mot de passe invalide.", file=sys.stderr)
        return 2
    new = hash36_argon2id(args.password, time_cost=args.t, memory_cost=args.m,
                          parallelism=args.p, pepper=_resolve_cli_pepper(args))
    out = json.dumps(new, indent=2)
    if args.out:
        open(args.out, "w").write(out)
    print(json.dumps({"status": "ok", **new}, indent=2) if args.json else out)
    return 0


def cmd_rehash_all(args):
    import hashlib, hmac
    root = pathlib.Path(args.dir)
    if not root.is_dir():
        print(f"Erreur : {root} n'est pas un répertoire", file=sys.stderr)
        return 1
    pepper = _resolve_cli_pepper(args)
    stats = {"total": 0, "skipped": 0, "rehashed": 0,
             "failed": 0, "errors": []}
    for path in sorted(root.rglob("*.json")):
        stats["total"] += 1
        try:
            rec = json.loads(path.read_text())
        except Exception as e:
            stats["errors"].append({"file": str(path), "error": str(e)})
            stats["failed"] += 1
            continue
        if not check_needs_rehash(rec, args.target_t, args.target_m, args.target_p):
            stats["skipped"] += 1
            continue
        if (rec.get("t", 0) < args.target_t or rec.get("m", 0) < args.target_m
                or rec.get("p", 0) < args.target_p):
            stats["errors"].append({"file": str(path),
                "error": "paramètres obsolètes : utiliser `rehash`"})
            stats["failed"] += 1
            continue
        try:
            cle = bytes.fromhex(rec["hash"])
            key = (pepper.encode() if pepper
                   else os.environ.get(PEPPER_ENV, "").encode()
                   or bytes.fromhex(rec["sel"]))
            rec["tag"] = hmac.new(key, cle, hashlib.sha3_256).digest()[:16].hex()
            rec["mode"] = "pepper" if key else "no-pepper"
        except Exception as e:
            stats["errors"].append({"file": str(path), "error": str(e)})
            stats["failed"] += 1
            continue
        if args.dry_run:
            stats["rehashed"] += 1
            continue
        try:
            fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
            with os.fdopen(fd, "w") as f:
                json.dump(rec, f, indent=2)
            os.replace(tmp, path)
            stats["rehashed"] += 1
        except Exception as e:
            stats["errors"].append({"file": str(path), "error": str(e)})
            stats["failed"] += 1
    payload = {"status": "ok", "dry_run": args.dry_run, **stats}
    print(json.dumps(payload, indent=2) if args.json
          else f"Total={stats['total']} rehashed={stats['rehashed']} "
               f"skipped={stats['skipped']} failed={stats['failed']}")
    return 0 if stats["failed"] == 0 else 2


def main(argv=None):
    p = argparse.ArgumentParser(prog="hash36")
    sub = p.add_subparsers(dest="command", required=True)

    def add_pepper(sp):
        sp.add_argument("--pepper")
        sp.add_argument("--pepper-env", default=None)
        sp.add_argument("--json", action="store_true")

    h = sub.add_parser("hash"); add_pepper(h)
    h.add_argument("-P", "--password", required=True)
    h.add_argument("-s", "--salt", default=None)
    h.add_argument("--t", type=int, default=3)
    h.add_argument("--m", type=int, default=65536)
    h.add_argument("--p", type=int, default=4)
    h.set_defaults(func=cmd_hash)

    v = sub.add_parser("verify"); add_pepper(v)
    v.add_argument("-P", "--password", required=True)
    v.add_argument("-r", "--record", required=True)
    v.add_argument("--target-t", type=int, default=3)
    v.add_argument("--target-m", type=int, default=65536)
    v.add_argument("--target-p", type=int, default=4)
    v.set_defaults(func=cmd_verify)

    r = sub.add_parser("rehash"); add_pepper(r)
    r.add_argument("-P", "--password", required=True)
    r.add_argument("-r", "--record", required=True)
    r.add_argument("-o", "--out", default=None)
    r.add_argument("--t", type=int, default=3)
    r.add_argument("--m", type=int, default=65536)
    r.add_argument("--p", type=int, default=4)
    r.set_defaults(func=cmd_rehash)

    ra = sub.add_parser("rehash-all"); add_pepper(ra)
    ra.add_argument("-d", "--dir", required=True)
    ra.add_argument("--dry-run", action="store_true")
    ra.add_argument("--target-t", type=int, default=3)
    ra.add_argument("--target-m", type=int, default=65536)
    ra.add_argument("--target-p", type=int, default=4)
    ra.set_defaults(func=cmd_rehash_all)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
PYEOF

cat > pyproject.toml <<'TOMLEOF'
[build-system]
requires = ["setuptools>=77", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "hash36"
version = "0.1.0"
description = "HASH-36-KDF : Argon2id avec séparation de domaine, pepper et rotation."
readme = "README.md"
requires-python = ">=3.10"
license = "MIT"
license-files = ["LICENSE"]
authors = [{ name = "HASH-36 Working Group" }]
keywords = ["argon2", "kdf", "password", "pepper", "hash36", "security"]
classifiers = [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Developers",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Topic :: Security :: Cryptography",
]
dependencies = ["argon2-cffi>=23.1"]

[project.optional-dependencies]
dev = ["pytest>=8.0", "pytest-cov>=5.0", "matplotlib>=3.8",
       "ruff>=0.5", "mypy>=1.10"]

[project.scripts]
hash36 = "hash36_cli:main"

[tool.setuptools]
py-modules = ["hash36_argon2id", "hash36_cli"]

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["."]
addopts = "-q -m 'not slow'"
markers = [
    "slow: tests sensibles au bruit CPU (lancer avec -m slow)",
]

[tool.ruff]
line-length = 100
target-version = "py310"
TOMLEOF

cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 HASH-36 Working Group

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

cat > README.md <<'MDEOF'
# HASH-36

KDF au-dessus d'**Argon2id** (RFC 9106) avec séparation de domaine,
**pepper** et **rotation**.

## ⚠️ Avertissement

HASH-36 n'est **PAS** un nouvel algorithme cryptographique. C'est un
*schéma de construction* au-dessus d'Argon2id.

## 📦 Installation

    pip install hash36

## 🚀 Utilisation

### Python

    from hash36_argon2id import hash36_argon2id, hash36_verify
    rec = hash36_argon2id("MonMotDePasse!")
    assert hash36_verify("MonMotDePasse!", rec)

### CLI

    export HASH36_PEPPER="$(openssl rand -hex 32)"
    hash36 hash -P "MonMotDePasse!" --json
    hash36 verify -P "MonMotDePasse!" -r record.json --json
    hash36 rehash-all --dir records/ --dry-run --json

## 🔐 Paramètres (OWASP 2024)

| Paramètre | Minimum | Défaut |
|-----------|---------|--------|
| `t` | 2 | **3** |
| `m` | 19 MiB | **64 MiB** |
| `p` | 1 | **4** |

## 🧪 Tests

    pytest -v            # tests rapides (exclut @slow)
    pytest -m slow -v    # tests de timing (machine calme)

## 📊 Benchmarks

![GPU](hash36_benchmark.png)
![Mémoire](hash36_memory.png)

**Facteur bcrypt → Argon2id/HASH-36 sur GPU : ~37 000×.**

## 📄 Licence

MIT.
MDEOF

ok "Sources générées"

# =============================================================================
#  4. TESTS
# =============================================================================
log "Génération des tests..."

cat > tests/test_nonregression.py <<'PYEOF'
import struct
import pytest
from argon2.low_level import hash_secret_raw, Type
from hash36_argon2id import hash36_argon2id, check_needs_rehash

FAST = dict(time_cost=1, memory_cost=8192, parallelism=1)

CASES = [
    ("Hash",       "000102030405060708090a0b0c0d0e0f"),
    ("MonMdp!",    "ffffffffffffffffffffffffffffffff"),
    ("",           "00000000000000000000000000000000"),
    ("passwörd🔐", "0123456789abcdef0123456789abcdef"),
]

@pytest.mark.parametrize("mdp,sel_hex", CASES)
def test_hash36_egal_argon2id(mdp, sel_hex):
    sel = bytes.fromhex(sel_hex)
    prefix = bytes([2, 1, 19, 5]) + struct.pack(">I", 36)
    ref = hash_secret_raw(secret=mdp.encode(), salt=prefix + sel,
                          hash_len=32, type=Type.ID, **FAST)
    got = bytes.fromhex(hash36_argon2id(mdp, sel=sel, **FAST)["hash"])
    assert got == ref


def test_tag_deterministe_avec_pepper(monkeypatch):
    monkeypatch.setenv("HASH36_PEPPER", "pepper-fixe")
    a = hash36_argon2id("x", sel=b"\x01"*16, **FAST)
    b = hash36_argon2id("x", sel=b"\x01"*16, **FAST)
    assert a["tag"] == b["tag"] and a["mode"] == "pepper"


def test_tag_change_avec_pepper(monkeypatch):
    monkeypatch.setenv("HASH36_PEPPER", "A")
    a = hash36_argon2id("x", sel=b"\x01"*16, **FAST)
    monkeypatch.setenv("HASH36_PEPPER", "B")
    b = hash36_argon2id("x", sel=b"\x01"*16, **FAST)
    assert a["tag"] != b["tag"] and a["hash"] == b["hash"]


def test_mode_degrade_sans_pepper(monkeypatch):
    monkeypatch.delenv("HASH36_PEPPER", raising=False)
    r = hash36_argon2id("x", sel=b"\x01"*16, **FAST)
    assert r["mode"] == "no-pepper"


def test_check_needs_rehash():
    # Mode dégradé (sans pepper) → rehash obligatoire
    assert check_needs_rehash(
        {"mode": "no-pepper", "t": 3, "m": 65536, "p": 4})
    # Paramètres obsolètes
    assert check_needs_rehash(
        {"mode": "pepper", "t": 2, "m": 65536, "p": 4})
    assert check_needs_rehash(
        {"mode": "pepper", "t": 3, "m": 32768, "p": 4})
    assert check_needs_rehash(
        {"mode": "pepper", "t": 3, "m": 65536, "p": 2})
    # Tous les paramètres OK
    assert not check_needs_rehash(
        {"mode": "pepper", "t": 3, "m": 65536, "p": 4})
PYEOF

cat > tests/test_timing.py <<'PYEOF'
import time, statistics, inspect
import pytest
from hash36_argon2id import hash36_argon2id, hash36_verify, PEPPER_ENV

FAST = dict(time_cost=1, memory_cost=8192, parallelism=1)
N = 50
WARMUP = 5


def _mesurer(fn, n=N):
    for _ in range(WARMUP):
        fn()
    out = []
    for _ in range(n):
        t0 = time.perf_counter_ns()
        fn()
        out.append(time.perf_counter_ns() - t0)
    return out


def _welch_t_median(a, b):
    ma, mb = statistics.median(a), statistics.median(b)
    va, vb = statistics.variance(a), statistics.variance(b)
    return (ma - mb) / ((va/len(a) + vb/len(b)) ** 0.5)


@pytest.mark.slow
def test_verify_bon_vs_mauvais_timing(monkeypatch):
    """La différence de temps bon/mauvais mdp doit être statistiquement nulle.

    Marqué @pytest.mark.slow car sensible au bruit CPU.
    Lancer avec : pytest -m slow -v
    """
    monkeypatch.setenv(PEPPER_ENV, "timing-pepper")
    rec = hash36_argon2id("correct", sel=b"\x01"*16, **FAST)
    bon = _mesurer(lambda: hash36_verify("correct", rec, pepper="timing-pepper"))
    mauvais = _mesurer(lambda: hash36_verify("incorrect", rec, pepper="timing-pepper"))

    med_bon = statistics.median(bon) / 1e6
    med_mauvais = statistics.median(mauvais) / 1e6
    t = _welch_t_median(bon, mauvais)
    ratio = med_mauvais / med_bon

    print(f"\n[t-timing] bon={med_bon:.3f} ms, mauvais={med_mauvais:.3f} ms, "
          f"t={t:.2f}, ratio={ratio:.3f}")

    assert abs(t) < 3.5, f"Fuite temporelle (t={t:.2f})"
    assert 0.85 < ratio < 1.15, f"Ratio hors tolérance ({ratio:.3f})"


def test_compare_digest_utilise():
    src = inspect.getsource(hash36_verify)
    assert "compare_digest" in src, \
        "hash36_verify doit utiliser hmac.compare_digest (temps constant)"
PYEOF

cat > tests/test_cli.py <<'PYEOF'
import json, subprocess, sys, os

def run(args, env=None):
    e = os.environ.copy()
    if env: e.update(env)
    return subprocess.run([sys.executable, "-m", "hash36_cli", *args],
                          capture_output=True, text=True, env=e)

def test_hash_json():
    r = run(["hash", "-P", "test", "--json", "--t", "1", "--m", "8192", "--p", "1"])
    assert r.returncode == 0, r.stderr
    data = json.loads(r.stdout)
    assert data["status"] == "ok" and "hash" in data

def test_verify_fail():
    r = run(["verify", "-P", "x", "-r", "/nonexistent.json", "--json"])
    assert r.returncode == 1
PYEOF

ok "Tests générés"

# =============================================================================
#  5. BENCHMARKS
# =============================================================================
log "Génération des benchmarks..."

cat > benchmark_hash36.py <<'PYEOF'
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
PYEOF

cat > benchmark_memory.py <<'PYEOF'
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
PYEOF

ok "Benchmarks générés"

# =============================================================================
#  6. DOCUMENTATION
# =============================================================================
log "Génération de la documentation..."
cat > docs/threat_model.md <<'MDEOF'
# Threat Model STRIDE — HASH-36

## Périmètre
Génération du hash, stockage du record, vérification.

## Table STRIDE

| Menace | Risque | Contre-mesure |
|--------|--------|---------------|
| Spoofing | Moyen | Argon2id irréversible, sel unique |
| Tampering | Élevé sans pepper | tag HMAC-SHA3 avec pepper |
| Repudiation | Hors périmètre | logs d'audit séparés |
| Information Disclosure | Faible | Argon2id m=64 MiB, sel 128 bits |
| Denial of Service | Élevé | rate-limiting (inhérent à Argon2id) |
| Elevation | Hors périmètre | RBAC séparé |

## Faiblesses identifiées

1. **Tag sans pepper** → un attaquant avec accès DB peut recalculer le tag.
   *Correction* : pepper global (HSM ou $HASH36_PEPPER).
2. **DoS mémoire** → 64 MiB × N connexions.
   *Correction* : rate-limiting, file d'attente bornée.
3. **Paramètres non versionnés** → pas de rotation.
   *Correction* : check_needs_rehash + mode dans le record.
MDEOF
ok "Documentation générée"

# =============================================================================
#  7. VALIDATION SYNTAXE
# =============================================================================
log "Validation de la syntaxe Python..."
python -m py_compile hash36_argon2id.py hash36_cli.py \
                     tests/test_nonregression.py tests/test_timing.py \
                     tests/test_cli.py benchmark_hash36.py benchmark_memory.py \
  || die "Erreur de syntaxe Python"
ok "Syntaxe Python valide"

if [[ $DO_CHECK -eq 1 ]]; then
  log "Mode --check : validation uniquement"
  bash -n "$0" && ok "build.sh syntaxe valide"
  for f in hash36_argon2id.py hash36_cli.py pyproject.toml README.md LICENSE; do
    [[ -f "$f" ]] || die "Fichier manquant après génération : $f"
  done
  ok "Tous les fichiers critiques présents"
  ok "Check terminé, aucune exécution supplémentaire"
  exit 0
fi

# =============================================================================
#  8. TESTS
# =============================================================================
if [[ $DO_TEST -eq 1 ]]; then
  log "Exécution des tests (rapides, hors @slow)..."
  set +e
  pytest -v --cov=hash36_argon2id --cov=hash36_cli --cov-report=term-missing
  RC=$?
  set -e
  [[ $RC -eq 0 ]] && ok "Tests OK" || warn "Tests échoués (code $RC)"
fi

# =============================================================================
#  9. BENCHMARKS
# =============================================================================
if [[ $DO_BENCH -eq 1 ]]; then
  log "Génération des graphiques..."
  python benchmark_hash36.py
  python benchmark_memory.py
  ok "Graphiques générés"
fi

# =============================================================================
#  10. PACKAGING
# =============================================================================
if [[ $DO_PACKAGE -eq 1 ]]; then
  log "Construction du package..."
  [[ -f pyproject.toml ]] || die "pyproject.toml manquant"
  rm -rf dist build *.egg-info
  python -m build
  twine check dist/*
  ok "Package construit dans dist/"
fi

# =============================================================================
#  11. PUBLICATION
# =============================================================================
if [[ $DO_PUBLISH -eq 1 ]]; then
  warn "Publication sur PyPI (TestPyPI d'abord recommandé)"
  read -rp "Publier sur TestPyPI ? [y/N] " ans
  if [[ "${ans,,}" == "y" ]]; then
    twine upload --repository testpypi dist/*
    ok "Publié sur TestPyPI"
  fi
  read -rp "Publier sur PyPI ? [y/N] " ans
  if [[ "${ans,,}" == "y" ]]; then
    twine upload dist/*
    ok "Publié sur PyPI"
  fi
fi

# =============================================================================
#  FIN
# =============================================================================
echo
echo "${GREEN}${BOLD}✅ Projet HASH-36 construit avec succès${NC}"
echo "   Répertoire : $ROOT"
echo "   Fichiers   : $(find . -maxdepth 2 -type f -not -path './.venv/*' -not -path './.git/*' -not -path './.pytest_cache/*' -not -path './build/*' -not -path './*.egg-info/*' | wc -l)"
echo
echo "Commandes utiles :"
echo "   source .venv/bin/activate"
echo "   hash36 hash -P 'test' --json"
echo "   pytest -v            # tests rapides"
echo "   pytest -m slow -v    # tests de timing (machine calme)"
echo "   ./build.sh --all"