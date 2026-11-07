"""Run: python3 -m unittest discover -s service"""
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import stat
import tempfile
import time
import unittest

SCRIPT = pathlib.Path(__file__).with_name("claude-limits-update")
loader = importlib.machinery.SourceFileLoader("claude_limits_update", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
updater = importlib.util.module_from_spec(spec)
loader.exec_module(updater)

USAGE = {"five_hour": {"utilization": 12.0, "resets_at": None}, "seven_day": None}


class Renewal(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = pathlib.Path(self.tmp.name)
        updater.HOME = str(self.home)
        updater.OUT = str(self.home / "out")
        (self.home / "out").mkdir()
        self.profile = self.home / ".claude-profile-4"
        self.profile.mkdir()
        self.creds = self.profile / ".credentials.json"
        self.sent = []
        updater.get = lambda url, headers, data=None: self.sent.append(headers["Authorization"]) or USAGE

    def login(self, token, expires_in):
        expires_at = int((time.time() + expires_in) * 1000)
        self.creds.write_text(json.dumps({"claudeAiOauth": {"accessToken": token, "expiresAt": expires_at}}))

    def fake_claude(self, body):
        path = self.home / ".local/bin/claude"
        path.parent.mkdir(parents=True)
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(path.stat().st_mode | stat.S_IEXEC)

    def run_update(self, force=True):
        updater.update("claude-4", lambda: updater.fetch_claude("4"), str(self.creds), force)
        return json.loads((self.home / "out/claude-4.json").read_text())

    def test_expired_login_is_renewed_then_fetched(self):
        self.login("old", -60)
        fresh = json.dumps({"claudeAiOauth": {"accessToken": "new", "expiresAt": int((time.time() + 3600) * 1000)}})
        self.fake_claude(f"""[ "$1 $2" = "auth status" ] && printf '%s' '{fresh}' > "$CLAUDE_CONFIG_DIR/.credentials.json\"""")
        state = self.run_update()
        self.assertEqual(self.sent, ["Bearer new"])
        self.assertIsNone(state["error"])
        self.assertEqual(state["five_hour"]["used_percentage"], 12.0)

    def test_failed_renewal_keeps_figures_and_sends_nothing(self):
        self.login("old", -60)
        self.fake_claude("exit 1")
        saved = {"five_hour": {"used_percentage": 40, "resets_at": None}, "saved_at": 5, "checked_at": 5}
        (self.home / "out/claude-4.json").write_text(json.dumps(saved))
        state = self.run_update()
        self.assertEqual(self.sent, [])
        self.assertIn("run ccd 4", state["error"])
        self.assertEqual(state["five_hour"]["used_percentage"], 40)
        self.assertEqual(state["saved_at"], 5)

    def test_check_waits_five_to_ten_minutes(self):
        self.login("live", 3600)
        os.utime(self.creds, (0, 0))
        for age, fetched in ((299, False), (601, True)):
            self.sent.clear()
            at = int(time.time()) - age
            (self.home / "out/claude-4.json").write_text(json.dumps({"saved_at": at, "checked_at": at}))
            self.run_update(force=False)
            self.assertEqual(bool(self.sent), fetched, age)


if __name__ == "__main__":
    unittest.main()
