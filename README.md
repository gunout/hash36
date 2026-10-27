<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=6,11,20&height=180&section=header&text=HASH-36&fontSize=70&fontAlignY=35&animation=twinkling&fontColor=ffffff" />

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=24&duration=3000&pause=500&color=10B981&center=true&vCenter=true&width=600&lines=Argon2id+KDF+avec+pepper;Rotation+automatique;GPG+Signed+Commits" alt="Typing SVG" />

[![PyPI](https://img.shields.io/badge/PyPI-à%20venir-lightgrey?style=for-the-badge&logo=pypi&logoColor=white)](https://pypi.org/project/hash36/)
[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Argon2id](https://img.shields.io/badge/Argon2id-RFC%209106-10b981?style=for-the-badge&logo=shield&logoColor=white)](https://www.rfc-editor.org/rfc/rfc9106)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge&logo=opensourceinitiative&logoColor=white)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-11%20passed-success?style=for-the-badge&logo=pytest&logoColor=white)](#-tests)
[![GPG Signed](https://img.shields.io/badge/Commits-GPG%20Signed-2496ED?style=for-the-badge&logo=gnuprivacyguard&logoColor=white)](https://github.com/gunout/hash36/commits/main)

<img src="hash36_benchmark.png" alt="Benchmark GPU" width="800">

</div>

---

## ⚡whoami

**HASH-36** est un **schéma de construction** au-dessus d'**Argon2id** (RFC 9106).
Il n'invente **pas** de cryptographie : il ajoute une **séparation de domaine**, un **pepper** global et une **rotation** automatique des paramètres.

- 🔐 **Argon2id** (RFC 9106) — paramètres OWASP 2024 par défaut (`t=3, m=64 MiB, p=4`)
- 🏷️ **Domain separation** — préfixe `BASE || A1Z26` issu du mot « Hash » (A1Z26=36, BASE=2.1.19.5)
- 🌶️ **Pepper** global — protège le `tag` HMAC contre un attaquant avec accès DB
- 🔄 **Rotation** — `check_needs_rehash` + `rehash` + `rehash-all` (migration sans mot de passe)
- 🖥️ **CLI JSON** — 4 sous-commandes scriptables avec codes de sortie
- ✅ **Non-régression** — HASH-36 ≡ Argon2id bit-à-bit (8 tests)

> ⚠️ **Avertissement** : ne déployez pas HASH-36 en production sans audit de sécurité.
> Les constantes (`36`, `BASE`, couleur `#c4a47c`) sont **publiques** — elles servent à la séparation de domaine, pas à la sécurité.

---

## 🛠️tech_stack

<div align="center">

![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![Argon2](https://img.shields.io/badge/Argon2-10b981?style=flat-square&logo=shield&logoColor=white)
![pytest](https://img.shields.io/badge/pytest-0A9EDC?style=flat-square&logo=pytest&logoColor=white)
![matplotlib](https://img.shields.io/badge/matplotlib-11557c?style=flat-square&logo=python&logoColor=white)
![setuptools](https://img.shields.io/badge/setuptools-EF7B26?style=flat-square&logo=python&logoColor=white)
![GPG](https://img.shields.io/badge/GPG-2496ED?style=flat-square&logo=gnuprivacyguard&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white)

</div>

---

## 🚀quick_start

**Installation** : `pip install hash36`

**CLI** :

    export HASH36_PEPPER="$(openssl rand -hex 32)"
    hash36 hash -P "MonMotDePasse!" --json
    hash36 verify -P "MonMotDePasse!" -r record.json --json
    hash36 rehash -P "MonMotDePasse!" -r record.json -o record.new.json
    hash36 rehash-all --dir records/ --dry-run --json

**Python** :

    from hash36_argon2id import hash36_argon2id, hash36_verify

    rec = hash36_argon2id("MonMotDePasse!")          # pepper depuis $HASH36_PEPPER
    assert hash36_verify("MonMotDePasse!", rec)

---

## 🔐paramètres_owasp

| Paramètre | Minimum | Défaut HASH-36 |
|-----------|---------|----------------|
| `t` (time cost) | 2 | **3** |
| `m` (memory cost) | 19 MiB | **64 MiB** |
| `p` (parallelism) | 1 | **4** |
| Sel | 16 octets | **16 octets** |
| Pepper | 32 octets | **variable d'env** |

---

## 📊benchmark

<div align="center">

<img src="hash36_benchmark.png" alt="Débit GPU + Coût CPU" width="800">

**Facteur bcrypt → Argon2id/HASH-36 sur GPU : ~37 000×**

<img src="hash36_memory.png" alt="Memory-hardness" width="600">

</div>

| Algorithme | Débit RTX 4090 | Mémoire/guess |
|------------|----------------|---------------|
| bcrypt (cost=12) | **184 000 H/s** | 4 KiB |
| scrypt (N=2¹⁴) | 7 126 H/s | 16 MiB |
| **Argon2id / HASH-36** | **~5 H/s** | **64 MiB** |

---

## 🧪tests

**Tests rapides (11 tests)** : `pytest -v`

**Tests de timing (machine calme)** : `pytest -m slow -v -s`

**Couverture** : `pytest --cov=hash36_argon2id --cov-report=term-missing`

| Test | Ce qu'il valide |
|------|-----------------|
| `test_hash36_egal_argon2id` | HASH-36 ≡ Argon2id (bit-à-bit) |
| `test_tag_change_avec_pepper` | Le pepper protège le tag |
| `test_mode_degrade_sans_pepper` | Détection du mode dégradé |
| `test_check_needs_rehash` | Rotation correcte |
| `test_verify_bon_vs_mauvais_timing` | Timing constant (`@slow`) |
| `test_compare_digest_utilise` | `hmac.compare_digest` statique |
| `test_hash_json` / `test_verify_fail` | CLI subprocess |

---

## 🛡️threat_model

| Menace STRIDE | Risque | Contre-mesure |
|---------------|--------|---------------|
| **S**poofing | 🟡 Moyen | Argon2id irréversible, sel unique |
| **T**ampering | 🟠 sans pepper | tag HMAC-SHA3 **avec pepper** |
| **R**epudiation | ⚪ Hors périmètre | logs d'audit séparés |
| **I**nformation Disclosure | 🟢 Faible | Argon2id `m=64 MiB`, sel 128 bits |
| **D**enial of Service | 🟠 Élevé | rate-limiting (inhérent à Argon2id) |
| **E**levation | ⚪ Hors périmètre | RBAC séparé |

Voir [`docs/threat_model.md`](docs/threat_model.md) pour l'analyse complète.

---

## 🏗️architecture

- `hash36_argon2id.py` — cœur (Argon2id + pepper + rotation)
- `hash36_cli.py` — CLI (hash / verify / rehash / rehash-all)
- `pyproject.toml` — packaging PyPI (SPDX, setuptools>=77)
- `build.sh` — construction complète (tests + bench + package)
- `deploy.sh` — déploiement GitHub avec signature GPG
- `rebuild.sh` — rebuild + test dans venv vierge
- `tests/` — 3 fichiers de tests (non-régression, timing, CLI)
- `docs/threat_model.md` — STRIDE complet
- `hash36_benchmark.png` — graphique GPU + CPU
- `hash36_memory.png` — graphique memory-hardness

---

## 📈github_stats

<div align="center">

![GitHub stars](https://img.shields.io/github/stars/gunout/hash36?style=social)
![GitHub forks](https://img.shields.io/github/forks/gunout/hash36?style=social)
![GitHub watchers](https://img.shields.io/github/watchers/gunout/hash36?style=social)
![GitHub last commit](https://img.shields.io/github/last-commit/gunout/hash36?style=flat-square)
![GitHub commit activity](https://img.shields.io/github/commit-activity/m/gunout/hash36?style=flat-square)
![GitHub repo size](https://img.shields.io/github/repo-size/gunout/hash36?style=flat-square)

</div>

---

## 📚références

- [RFC 9106 — Argon2](https://www.rfc-editor.org/rfc/rfc9106)
- [RFC 7914 — scrypt](https://www.rfc-editor.org/rfc/rfc7914)
- [NIST SP 800-132](https://csrc.nist.gov/publications/detail/sp/800-132/final)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [PEP 639 — SPDX license expression](https://peps.python.org/pep-0639/)

---

## 📄licence

MIT — voir [`LICENSE`](LICENSE).

<div align="center">

**Construit avec 🔐 par [@gunout](https://github.com/gunout)**

[![GitHub followers](https://img.shields.io/github/followers/gunout?style=social)](https://github.com/gunout)

</div>
