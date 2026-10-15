# Claude Limits: AI quota in your KDE Plasma panel

![screenshot](screenshot.png)

How much of your 5-hour window is left? How much of the week? When does it
reset? One pill per account in the panel, for
[Claude Code](https://claude.com/claude-code) (any number of accounts), Codex
and Antigravity.

## How it works

Each account has one small JSON file:

```
~/.cache/claude-limits/claude-1.json
~/.cache/claude-limits/claude-2.json
~/.cache/claude-limits/codex.json
~/.cache/claude-limits/agy.json
```

```json
{
  "five_hour": { "used_percentage": 12, "resets_at": 1792042200 },
  "seven_day": { "used_percentage": 46, "resets_at": 1792260000 },
  "tier": "max 5x",
  "error": null,
  "saved_at": 1792026690
}
```

The widget only reads that file, every 10 seconds. It makes no network calls
and holds no tokens.

A small service keeps the files fresh. Once a minute it looks at each one, and
if a file is missing or more than 5 minutes old, it asks the provider and
writes it again. After you log in again it fetches straight away.

Claude Code can write the file too. Its statusline gets your limits with each
reply, so an open session rewrites its file whenever a reply brings new
numbers. While that file is under 5 minutes old, the service makes no API call
for that account.

The file is the only thing the service and the widget share, so a script,
another bar or a notification can read it too.

## Install

Needs Plasma 6, `python3` and systemd.

```
git clone https://github.com/Nael-Nathanael/claude-limits-plasmoid
claude-limits-plasmoid/install.sh
```

`install.sh` installs the widget, copies the service to
`~/.local/bin/claude-limits-update` and starts `claude-limits.timer`. Run it
again to update.

Then right-click the panel → Add Widgets → Claude Limits. Add one widget per
account and pick the account under right-click → Configure.

## Reading a pill

```
 1% 12.30        ← 5-hour usage, resets 12:30
12% 01.00@Oct 18 ← weekly usage, resets Oct 18, 01:00
```

- Green under 50%, yellow from 50%, red from 80%.
- A grey `*` means the numbers are old: the last fetch failed or the service
  stopped. Hover for the reason.
- Click to fetch now.
- Not logged in: the widget hides itself.

## Accounts

| Widget setting | File | Login it reads |
|---|---|---|
| Claude Code, profile 1 | `claude-1.json` | `~/.claude` |
| Claude Code, profile N | `claude-N.json` | `~/.claude-profile-N` ([ccd](https://github.com/Nael-Nathanael/ccd)) |
| Codex | `codex.json` | `~/.codex/auth.json` |
| Antigravity | `agy.json` | the `gemini` / `antigravity` keyring entry |

The service finds these on its own. A new `ccd` profile gets a file on the next
minute.

## Live numbers from Claude Code (optional)

Add this to your statusline script (`statusLine` in
`~/.claude/settings.json`). It writes only when the numbers change, so an idle
session never makes old numbers look new.

```bash
input=$(cat)
profile=1
case "$CLAUDE_CONFIG_DIR" in *-profile-*) profile="${CLAUDE_CONFIG_DIR##*-profile-}" ;; esac
f="${XDG_CACHE_HOME:-$HOME/.cache}/claude-limits/claude-$profile.json"
mkdir -p "${f%/*}"
tmp=$(mktemp "$f.XXXXXX")
echo "$input" | jq -e --slurpfile old <(cat "$f" 2>/dev/null) '
  def win: if . then {used_percentage, resets_at} else null end;
  (($old[0] // {}) | del(.hidden)) as $o
  | .rate_limits | select(. != null)
  | {five_hour: (.five_hour | win), seven_day: (.seven_day | win)} as $n
  | select($n != {five_hour: $o.five_hour, seven_day: $o.seven_day})
  | $o + $n + {error: null, saved_at: (now | floor)}' > "$tmp" 2>/dev/null \
  && mv "$tmp" "$f" || rm -f "$tmp"
```

## Tokens

The service reads each tool's saved login and sends it only to that tool's own
usage endpoint. It never refreshes a Claude Code or Codex token. An account
left idle until its token expires keeps its last numbers, with a `*`, until you
use that tool again.

Antigravity tokens expire after an hour. To let the service renew its own copy
(never written back), put Antigravity's OAuth client in
`~/.config/claude-limits/agy-oauth.json`:

```json
{ "client_id": "…", "client_secret": "…" }
```

Without it, the agy pill asks you to run `agy` once the token runs out.

None of these usage endpoints is a documented API. Any of them can change or
go away.

## Uninstall

```
systemctl --user disable --now claude-limits.timer
rm ~/.config/systemd/user/claude-limits.{service,timer} ~/.local/bin/claude-limits-update
kpackagetool6 -t Plasma/Applet -r io.github.naelnathanael.claudelimits
rm -r ~/.cache/claude-limits
```

## License

MIT
