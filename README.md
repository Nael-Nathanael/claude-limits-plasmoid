# Claude Limits: Claude Code usage in your KDE Plasma panel

![screenshot](screenshot.png)

How much of your [Claude Code](https://claude.com/claude-code) 5-hour window is
left? How much of the week? When does it reset? One line of text in the panel,
always there, so you stop finding out the hard way.

## TL;DR

1. `kpackagetool6 -t Plasma/Applet -i claude-limits-plasmoid/package`
2. Right-click the panel → Add Widgets → Claude Limits.
3. Read it like this:

```
4% 13.00 — 2% 01.00@Sept 27
│  │       │  └ weekly window resets Sept 27, 01:00
│  │       └ weekly usage
│  └ 5-hour window resets 13:00
└ 5-hour usage
```

- Green under 50%, yellow from 50%, red from 80%.
- When the week is too used up for the days left, it shows only when the week
  comes back.
- Grey `*` = last fetch failed, numbers are old. Hover for the reason.
- Click to refresh now.
- Not logged in = the widget asks the panel to hide it.

## Install

Needs Plasma 6 and `python3`.

```
git clone https://github.com/Nael-Nathanael/claude-limits-plasmoid
kpackagetool6 -t Plasma/Applet -i claude-limits-plasmoid/package
```

Then right-click the panel → Add Widgets → Claude Limits.

Update with `-u` instead of `-i`. Remove with
`kpackagetool6 -t Plasma/Applet -r io.github.naelnathanael.claudelimits`.

## Two ways to use it

**Plain Claude Code.** Add the widget. It reads `~/.claude`. Nothing to set.

**Several accounts with [ccd](https://github.com/Nael-Nathanael/ccd).** Add one
widget per profile. Right-click → Configure → set *Profile* to the `ccd` number.
Profile N reads `~/.claude-profile-N`.

## How it works

`contents/tools/usage.py` reads the OAuth token Claude Code keeps in
`.credentials.json` and asks `https://api.anthropic.com/api/oauth/usage`. The
token goes to that host only. Results are cached in `~/.cache/claude-limits-N.json`
and fetched again every 5 minutes, or right away when Claude Code renews the
token.

The widget never refreshes the token itself. A profile left idle until its token
expires keeps its last numbers until you run Claude Code again.

The usage endpoint is not a documented API. It can change or go away.

## License

MIT
