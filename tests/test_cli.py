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
