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
