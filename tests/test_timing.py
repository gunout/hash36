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
