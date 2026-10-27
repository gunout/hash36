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
