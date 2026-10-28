<!-- ============================================================ -->
<!--  HASH-36 — FUTURISTIC NEON ROSE README                       -->
<!--  Style : gunout / néon rose / SVG animés                     -->
<!--  Publié sur PyPI : v0.1.0                                    -->
<!-- ============================================================ -->

<div align="center">

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<p align="center">
  <a href="https://github.com/gunout/hash36">
    <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/banner_hash36.svg" alt="HASH-36 Banner" width="100%" />
  </a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<!-- BADGES PYPI (à jour) -->
<p align="center">
  <a href="https://pypi.org/project/hash36/">
    <img src="https://img.shields.io/pypi/v/hash36?style=for-the-badge&logo=pypi&logoColor=white&color=FF2D95" alt="PyPI version" />
  </a>
  <a href="https://pypi.org/project/hash36/">
    <img src="https://img.shields.io/pypi/dm/hash36?style=for-the-badge&logo=pypi&logoColor=white&color=FF69B4" alt="PyPI downloads" />
  </a>
  <a href="https://pypi.org/project/hash36/">
    <img src="https://img.shields.io/pypi/pyversions/hash36?style=for-the-badge&logo=python&logoColor=white&color=FFB6D9" alt="Python versions" />
  </a>
  <a href="https://pypi.org/project/hash36/">
    <img src="https://img.shields.io/pypi/l/hash36?style=for-the-badge&logo=opensourceinitiative&logoColor=white&color=FF2D95" alt="License" />
  </a>
</p>

<p align="center">
  <img src="https://readme-typing-svg.herokuapp.com?font=Orbitron&weight=700&size=22&pause=800&color=FF2D95&background=0D001A00&center=true&vCenter=true&random=true&width=800&lines=%E2%96%B6+Initializing+crypto+protocol...;%E2%96%B6+Argon2id+KDF+engine...;%E2%96%B6+Pepper+%2B+Domain+Separation...;%E2%96%B6+Rotation+automation...;%E2%96%B6+System+secure.+Welcome." alt="Typing SVG" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<p align="center">
  <a href="https://github.com/gunout/hash36">
    <img src="https://github-readme-stats.vercel.app/api/pin/?username=gunout&repo=hash36&theme=radical&hide_border=true&bg_color=0D001A&title_color=FF2D95&text_color=FFB6D9&icon_color=FF69B4" alt="HASH-36 Repo Card" />
  </a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

</div>

---

<h2 align="center">⚡ <code>whoami</code></h2>

<div align="center">

<samp>
  <span style="color:#FF2D95;">🔐 Argon2id</span> — RFC 9106, paramètres OWASP 2024<br>
  <span style="color:#FF69B4;">🏷️ Domain Separation</span> — préfixe BASE || A1Z26 (issu du mot « Hash »)<br>
  <span style="color:#FFB6D9;">🌶️ Pepper</span> — protège le tag HMAC contre un attaquant avec accès DB<br>
  <span style="color:#FF2D95;">🔄 Rotation</span> — check_needs_rehash + rehash + rehash-all<br>
  <span style="color:#FF69B4;">🖥️ CLI JSON</span> — 4 sous-commandes scriptables<br>
  <span style="color:#FFB6D9;">✅ Non-régression</span> — HASH-36 ≡ Argon2id bit-à-bit (8 tests)
</samp>

</div>

<div align="center">

> ⚠️ **Avertissement** : ne déployez pas HASH-36 en production sans audit de sécurité.
> Les constantes (`36`, `BASE`, couleur `#c4a47c`) sont **publiques** — elles servent à la séparation de domaine, pas à la sécurité.

</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">🛠️ <code>tech_stack</code></h2>

<div align="center">

![Python](https://img.shields.io/badge/Python-3.10%2B-FF2D95?style=for-the-badge&logo=python&logoColor=white)
![Argon2](https://img.shields.io/badge/Argon2id-RFC%209106-FF69B4?style=for-the-badge&logo=shield&logoColor=white)
![pytest](https://img.shields.io/badge/pytest-11%20passed-FFB6D9?style=for-the-badge&logo=pytest&logoColor=white)
![matplotlib](https://img.shields.io/badge/matplotlib-FF2D95?style=for-the-badge&logo=python&logoColor=white)
![setuptools](https://img.shields.io/badge/setuptools-FF69B4?style=for-the-badge&logo=python&logoColor=white)
![GPG](https://img.shields.io/badge/GPG-Signed-FFB6D9?style=for-the-badge&logo=gnuprivacyguard&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-FF2D95?style=for-the-badge&logo=opensourceinitiative&logoColor=white)

</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">🚀 <code>quick_start</code></h2>

<div align="center">

**Installation** : `pip install hash36`

</div>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">📊 <code>benchmark</code></h2>

<div align="center">

<img src="https://raw.githubusercontent.com/gunout/hash36/main/hash36_benchmark.png" alt="Débit GPU + Coût CPU" width="800">

**Facteur bcrypt → Argon2id/HASH-36 sur GPU : ~37 000×**

<img src="https://raw.githubusercontent.com/gunout/hash36/main/hash36_memory.png" alt="Memory-hardness" width="600">

</div>

| Algorithme | Débit RTX 4090 | Mémoire/guess |
|------------|----------------|---------------|
| bcrypt (cost=12) | **184 000 H/s** | 4 KiB |
| scrypt (N=2¹⁴) | 7 126 H/s | 16 MiB |
| **Argon2id / HASH-36** | **~5 H/s** | **64 MiB** |

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">🔐 <code>paramètres_owasp</code></h2>

<div align="center">

| Paramètre | Minimum | Défaut HASH-36 |
|-----------|---------|----------------|
| `t` (time cost) | 2 | **3** |
| `m` (memory cost) | 19 MiB | **64 MiB** |
| `p` (parallelism) | 1 | **4** |
| Sel | 16 octets | **16 octets** |
| Pepper | 32 octets | **variable d'env** |

</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">🧪 <code>tests</code></h2>

<div align="center">

| Test | Ce qu'il valide |
|------|-----------------|
| `test_hash36_egal_argon2id` | HASH-36 ≡ Argon2id (bit-à-bit) |
| `test_tag_change_avec_pepper` | Le pepper protège le tag |
| `test_mode_degrade_sans_pepper` | Détection du mode dégradé |
| `test_check_needs_rehash` | Rotation correcte |
| `test_verify_bon_vs_mauvais_timing` | Timing constant (`@slow`) |
| `test_compare_digest_utilise` | `hmac.compare_digest` statique |
| `test_hash_json` / `test_verify_fail` | CLI subprocess |

</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">🛡️ <code>threat_model</code></h2>

<div align="center">

| Menace STRIDE | Risque | Contre-mesure |
|---------------|--------|---------------|
| **S**poofing | 🟡 Moyen | Argon2id irréversible, sel unique |
| **T**ampering | 🟠 sans pepper | tag HMAC-SHA3 **avec pepper** |
| **R**epudiation | ⚪ Hors périmètre | logs d'audit séparés |
| **I**nformation Disclosure | 🟢 Faible | Argon2id `m=64 MiB`, sel 128 bits |
| **D**enial of Service | 🟠 Élevé | rate-limiting (inhérent à Argon2id) |
| **E**levation | ⚪ Hors périmètre | RBAC séparé |

</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">🏗️ <code>architecture</code></h2>

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

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">📈 <code>github_stats</code></h2>

<div align="center">

![GitHub stars](https://img.shields.io/github/stars/gunout/hash36?style=social)
![GitHub forks](https://img.shields.io/github/forks/gunout/hash36?style=social)
![GitHub watchers](https://img.shields.io/github/watchers/gunout/hash36?style=social)
![GitHub last commit](https://img.shields.io/github/last-commit/gunout/hash36?style=flat-square&color=FF2D95)
![GitHub commit activity](https://img.shields.io/github/commit-activity/m/gunout/hash36?style=flat-square&color=FF69B4)
![GitHub repo size](https://img.shields.io/github/repo-size/gunout/hash36?style=flat-square&color=FFB6D9)

</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">📚 <code>références</code></h2>

- [RFC 9106 — Argon2](https://www.rfc-editor.org/rfc/rfc9106)
- [RFC 7914 — scrypt](https://www.rfc-editor.org/rfc/rfc7914)
- [NIST SP 800-132](https://csrc.nist.gov/publications/detail/sp/800-132/final)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [PEP 639 — SPDX license expression](https://peps.python.org/pep-0639/)

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<h2 align="center">📄 <code>licence</code></h2>

<div align="center">

MIT — voir [`LICENSE`](LICENSE).

</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/divider_hash36.svg" alt="Divider" />
</p>

<div align="center">

**Construit avec 🔐 par [@gunout](https://github.com/gunout)**

[![GitHub followers](https://img.shields.io/github/followers/gunout?style=social)](https://github.com/gunout)

</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/gunout/hash36/main/assets/images/footer_hash36.svg" alt="Footer" width="100%" />
</p>
