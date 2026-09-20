#!/usr/bin/env python3
"""Print usage state for one Claude Code profile as JSON: {tier, usage, error, at} or {hidden: true}.

Profile 1 is ~/.claude, profile N is ~/.claude-profile-N (ccd).
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
POLL_SECONDS = 300

n = int(sys.argv[1])
force = len(sys.argv) > 2
home = os.path.expanduser("~")
creds_path = f"{home}/.claude/.credentials.json" if n == 1 else f"{home}/.claude-profile-{n}/.credentials.json"
cache_path = f"{os.environ.get('XDG_CACHE_HOME', home + '/.cache')}/claude-limits-{n}.json"


def done(state):
    if not state.get("hidden"):
        with open(cache_path, "w") as f:
            json.dump(state, f)
    print(json.dumps(state))
    sys.exit(0)


try:
    with open(cache_path) as f:
        prev = json.load(f)
except (OSError, ValueError):
    prev = {}
if not isinstance(prev, dict):
    prev = {}

try:
    with open(creds_path) as f:
        creds = json.load(f)["claudeAiOauth"]
    creds_mtime = os.path.getmtime(creds_path)
except (OSError, ValueError, KeyError, TypeError):
    creds = None
if not isinstance(creds, dict):
    done({"hidden": True})  # not logged in: hide the profile

# Claude Code rewrites .credentials.json when it renews the token: fetch right away.
checked = prev.get("checked", 0)
if not force and time.time() - checked < POLL_SECONDS and creds_mtime < checked:
    print(json.dumps(prev))
    sys.exit(0)

tier = (creds.get("rateLimitTier") or "").replace("default_claude_", "", 1).replace("_", " ")
state = {**prev, "tier": tier, "checked": int(time.time())}

# The token is refreshed only by Claude Code itself; an idle profile keeps its last numbers.
if not creds.get("accessToken") or (creds.get("expiresAt") or 0) < time.time() * 1000:
    done({**state, "error": f"token expired — run {'claude' if n == 1 else f'ccd {n}'} to refresh"})

req = urllib.request.Request(USAGE_URL, headers={
    "Authorization": f"Bearer {creds['accessToken']}",
    "anthropic-beta": "oauth-2025-04-20",
})
try:
    with urllib.request.urlopen(req, timeout=20) as r:
        usage = json.load(r)
except urllib.error.HTTPError as e:
    done({**state, "error": f"HTTP {e.code}"})
except (OSError, ValueError) as e:
    done({**state, "error": str(e)})

done({**state, "usage": usage, "error": None, "at": int(time.time())})
