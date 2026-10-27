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
