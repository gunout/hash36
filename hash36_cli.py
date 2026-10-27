#!/usr/bin/env python3
"""CLI HASH-36 : hash / verify / rehash / rehash-all."""
import argparse, json, sys, os, pathlib, tempfile
from hash36_argon2id import (
    hash36_argon2id, hash36_verify, check_needs_rehash, PEPPER_ENV,
)


def _resolve_cli_pepper(args):
    """--pepper > --pepper-env > $HASH36_PEPPER (via hash36_argon2id)."""
    if args.pepper:
        return args.pepper
    if args.pepper_env:
        val = os.environ.get(args.pepper_env)
        if val is None:
            raise SystemExit(f"Variable '{args.pepper_env}' non définie.")
        return val
    return None


def _write_json(path: str, data: dict) -> None:
    """Écrit un JSON avec newline final (bonne pratique Unix)."""
    with open(path, "w") as f:
        f.write(json.dumps(data, indent=2) + "\n")


# =============================================================================
#  hash
# =============================================================================
def cmd_hash(args):
    """hash36 hash -P <mdp> [--json] [--pepper ...] [--t N --m N --p N]"""
    rec = hash36_argon2id(
        args.password,
        sel=bytes.fromhex(args.salt) if args.salt else None,
        time_cost=args.t,
        memory_cost=args.m,
        parallelism=args.p,
        pepper=_resolve_cli_pepper(args),
    )
    if args.json:
        # Record pur, sans "status" (permet `hash36 hash ... > record.json`)
        print(json.dumps(rec, indent=2))
    else:
        for k in ("algo", "mode", "sel", "t", "m", "p", "hash", "tag"):
            print(f"{k:10s}: {rec[k]}")
    return 0


# =============================================================================
#  verify
# =============================================================================
def cmd_verify(args):
    """hash36 verify -P <mdp> -r <record.json> [--json]"""
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


# =============================================================================
#  rehash
# =============================================================================
def cmd_rehash(args):
    """hash36 rehash -P <mdp> -r <in.json> [-o <out.json>] [--json]"""
    try:
        old = json.load(open(args.record))
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}) if args.json
              else f"Erreur : {e}", file=sys.stderr)
        return 1

    if not hash36_verify(args.password, old, pepper=_resolve_cli_pepper(args)):
        print(json.dumps({"status": "fail", "valid": False}) if args.json
              else "❌ Mot de passe invalide, rehash refusé.", file=sys.stderr)
        return 2

    new = hash36_argon2id(
        args.password,
        time_cost=args.t, memory_cost=args.m, parallelism=args.p,
        pepper=_resolve_cli_pepper(args),
    )

    out = json.dumps(new, indent=2) + "\n"
    if args.out:
        with open(args.out, "w") as f:
            f.write(out)
    print(json.dumps({"status": "ok", **new}, indent=2) if args.json else out)
    return 0


# =============================================================================
#  rehash-all
# =============================================================================
def cmd_rehash_all(args):
    """hash36 rehash-all --dir <répertoire> [--dry-run] [--json]"""
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
            stats["errors"].append({"file": str(path), "error": f"json: {e}"})
            stats["failed"] += 1
            continue

        # Déjà optimal ?
        if not check_needs_rehash(rec, args.target_t, args.target_m, args.target_p):
            stats["skipped"] += 1
            continue

        # Paramètres obsolètes : nécessite le mot de passe → on ne peut pas migrer
        if (rec.get("t", 0) < args.target_t
                or rec.get("m", 0) < args.target_m
                or rec.get("p", 0) < args.target_p):
            stats["errors"].append({
                "file": str(path),
                "error": "paramètres obsolètes : rehash nécessite le mot de passe (utiliser `rehash`)",
            })
            stats["failed"] += 1
            continue

        # Seul le pepper a changé → recalcul du tag, sans Argon2id
        try:
            cle = bytes.fromhex(rec["hash"])
            key = (pepper.encode() if pepper
                   else os.environ.get(PEPPER_ENV, "").encode()
                   or bytes.fromhex(rec["sel"]))
            rec["tag"] = hmac.new(key, cle, hashlib.sha3_256).digest()[:16].hex()
            rec["mode"] = "pepper" if key else "no-pepper"
        except Exception as e:
            stats["errors"].append({"file": str(path), "error": f"tag: {e}"})
            stats["failed"] += 1
            continue

        if args.dry_run:
            stats["rehashed"] += 1
            continue

        # Écriture atomique (tempfile + os.replace)
        try:
            fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
            with os.fdopen(fd, "w") as f:
                json.dump(rec, f, indent=2)
                f.write("\n")   # ← newline final
            os.replace(tmp, path)
            stats["rehashed"] += 1
        except Exception as e:
            stats["errors"].append({"file": str(path), "error": f"write: {e}"})
            stats["failed"] += 1

    payload = {"status": "ok", "dry_run": args.dry_run, **stats}
    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(f"Total     : {stats['total']}")
        print(f"Rehachés  : {stats['rehashed']}")
        print(f"Ignorés   : {stats['skipped']}")
        print(f"Échecs    : {stats['failed']}")
        if stats["errors"]:
            print("\nErreurs :")
            for e in stats["errors"]:
                print(f"  - {e['file']}: {e['error']}")
    return 0 if stats["failed"] == 0 else 2


# =============================================================================
#  main
# =============================================================================
def main(argv=None):
    p = argparse.ArgumentParser(
        prog="hash36",
        description="HASH-36-KDF : Argon2id avec séparation de domaine, pepper et rotation.",
    )
    sub = p.add_subparsers(dest="command", required=True)

    def add_pepper_opts(sp):
        sp.add_argument("--pepper", default=None,
                        help="Pepper en clair (⚠️ visible dans ps)")
        sp.add_argument("--pepper-env", default=None,
                        help="Nom d'une variable d'env contenant le pepper")
        sp.add_argument("--json", action="store_true",
                        help="Sortie JSON")

    # --- hash ---
    h = sub.add_parser("hash", help="Générer un hash HASH-36")
    add_pepper_opts(h)
    h.add_argument("-P", "--password", required=True, help="Mot de passe")
    h.add_argument("-s", "--salt", default=None, help="Sel en hex (32 car.)")
    h.add_argument("--t", type=int, default=3, help="Time cost (défaut: 3)")
    h.add_argument("--m", type=int, default=65536, help="Memory cost en KiB (défaut: 65536)")
    h.add_argument("--p", type=int, default=4, help="Parallélisme (défaut: 4)")
    h.set_defaults(func=cmd_hash)

    # --- verify ---
    v = sub.add_parser("verify", help="Vérifier un mot de passe")
    add_pepper_opts(v)
    v.add_argument("-P", "--password", required=True, help="Mot de passe à tester")
    v.add_argument("-r", "--record", required=True, help="Fichier JSON du record")
    v.add_argument("--target-t", type=int, default=3)
    v.add_argument("--target-m", type=int, default=65536)
    v.add_argument("--target-p", type=int, default=4)
    v.set_defaults(func=cmd_verify)

    # --- rehash ---
    r = sub.add_parser("rehash", help="Re-hacher un record (nécessite le mot de passe)")
    add_pepper_opts(r)
    r.add_argument("-P", "--password", required=True, help="Mot de passe")
    r.add_argument("-r", "--record", required=True, help="Record d'entrée")
    r.add_argument("-o", "--out", default=None, help="Record de sortie (défaut: stdout)")
    r.add_argument("--t", type=int, default=3)
    r.add_argument("--m", type=int, default=65536)
    r.add_argument("--p", type=int, default=4)
    r.set_defaults(func=cmd_rehash)

    # --- rehash-all ---
    ra = sub.add_parser("rehash-all",
                        help="Migrer tous les records d'un répertoire (sans mot de passe)")
    add_pepper_opts(ra)
    ra.add_argument("-d", "--dir", required=True, help="Répertoire racine")
    ra.add_argument("--dry-run", action="store_true", help="Simulation sans écriture")
    ra.add_argument("--target-t", type=int, default=3)
    ra.add_argument("--target-m", type=int, default=65536)
    ra.add_argument("--target-p", type=int, default=4)
    ra.set_defaults(func=cmd_rehash_all)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())