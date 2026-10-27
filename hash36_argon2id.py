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
