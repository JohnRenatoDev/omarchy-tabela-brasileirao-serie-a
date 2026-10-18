# Brasileirão for Omarchy

[![Omarchy 4.0+](https://img.shields.io/badge/Omarchy-4.0%2B-c6aa75?style=flat-square)](https://omarchy.org/manual/shell-plugins/)
[![MIT License](https://img.shields.io/badge/license-MIT-6aa6b2?style=flat-square)](LICENSE)

A live Brasileirão Série A tracker for the Omarchy bar. Follow your team, and
every matchday the bar shows both crests around the score as it changes in
real time — plus goal-arrival notifications, a full-screen celebration when
your team scores, and a full standings table one click away.

![Brasileirão bar widget showing two crests around a live score](preview.png)

## Highlights

- Adaptive bar chip: match countdown before kickoff, live score while the
  ball is rolling, final score for 30 minutes — out of the way otherwise
- Both team crests rendered on the bar, loaded from a local PNG cache
- Popup that opens on the exact game state: scoreboard card, minute, round
- Three-tab interface — **Jogos**, **Tabela**, **Ajustes** — kept
  minimal, modern, and clean
- Team picker with a search field across the full Série A roster
- Goal notifications over the desktop notification daemon, with the
  scorer's crest as the toast icon
- Full-screen goal celebration that appears fast and leaves fast, with
  confetti in the team's colors
- A quieter, deliberately bitter alert for when the other side scores —
  independently toggleable
- Data from ESPN's public soccer API: no key, no token, no rate-limit math
- Native Omarchy styling — follows the active theme, nothing bundled

## Install

Requires Omarchy 4.0 or newer with shell plugin support.

```sh
omarchy plugin add https://github.com/<you>/omarchy-football.git --enable
```

The shell normally picks the plugin up immediately. If the widget does not
appear, restart it once:

```sh
omarchy restart shell
```

## Use

While a match is on, the chip sits in the bar between your other widgets:

| State | What the bar shows |
| --- | --- |
| Match day, pre-game | `crest · kickoff time · crest`, from ~2h before kickoff |
| Live | pulsing dot, both crests, live score and match minute |
| Halftime / full time | the score with `INT` / `FIM` |
| After the final whistle | the score lingers ~30 min, then only the ball remains |
| No game today | a lone soccer ball, kept clickable |

| Action | Result |
| --- | --- |
| Left-click | Open or close the popup |
| `Q` while open | Close the popup |

### The popup

- **Jogos** — the followed team's match as a scoreboard card (score, minute,
  kickoff), plus every Brasileirão fixture of the day with mini crests. The
  followed team is highlighted; clicking any fixture switches the chip to
  that match.
- **Tabela** — the full classification table: position, crest, name, points,
  played, wins, draws, losses, and goal difference. Zone dots mark the
  Libertadores places and the relegation places; your team stays lit.
- **Ajustes** — the setup tab: a searchable team picker (type a name or a
  three-letter abbreviation to filter the roster), the "stop following"
  action, and the experience toggles — notifications, celebration, rival
  alert — plus a one-click preview of both overlay moods.

## Goal celebrations

When your team scores, a full-screen overlay takes the desktop for ~2.6
seconds: a white arrival flash, the club crest springing in at 148 px, a
pulsing **GOOOL!**, and falling confetti strips in the club's colors.

When the opponent scores instead, the overlay stays quiet: a brief
urgent-tinted vignette and the rival's crest dropping in tilted — sulk,
then gone in under two seconds.

Both surfaces are display-only layer-shell windows (`WlrLayer.Overlay`,
`WlrKeyboardFocus.None`, empty input region): the party never steals a
click or a keystroke from what you are doing.

## Configuration

The widget reads its settings from its own entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "russio.football",
  "league": "bra.1",
  "team": "2674",
  "teamName": "Santos",
  "goalNotifications": true,
  "goalCelebration": true,
  "rivalAlert": true,
  "badgeWhenIdle": true
}
```

| Key | Default | What it does |
| --- | --- | --- |
| `team` / `teamName` | — | The followed team (set by the picker, no manual edit needed) |
| `goalNotifications` | `true` | Goal / kickoff / full-time desktop alerts |
| `goalCelebration` | `true` | Full-screen celebration when your team scores |
| `rivalAlert` | `true` | Discreet alert when the opposition scores |
| `badgeWhenIdle` | `true` | Keep the team crest visible on no-game days |

Any ESPN league slug works for `league` — `bra.1` (Série A), `bra.2` (Série B),
`bra.3` (Série C), or anything else the API covers. The popup and the bar chip
follow whichever slug is set.

## Data

| Area | Source |
| --- | --- |
| Fixtures, live scores, match clock | `site.api.espn.com/apis/site/v2/sports/soccer/bra.1/scoreboard` |
| Classification table | `site.api.espn.com/apis/v2/sports/soccer/bra.1/standings` |
| Club crests | Fetched once per session from ESPN's CDN, cached as PNG |

Fetches adapt to the day: every 25 s with a live match, 90 s around a
scheduled one, 10 min on idle days. Network failures keep the last good
scoreboard on the bar — nothing blinks, nothing clears.

Crests are cached as PNGs under `~/.cache/omarchy/football/<team-id>.png`
and always rendered from disk, so the bar never loads remote art directly.

## IPC

Everything is scriptable through the widget's IPC route:

```sh
omarchy-shell russio.football toggle    # open/close the popup
omarchy-shell russio.football open      # open the popup
omarchy-shell russio.football close     # close it
omarchy-shell russio.football refresh   # force a data refresh now
omarchy-shell russio.football celebrate # preview the celebration overlay
omarchy-shell russio.football rivalGoal # preview the rival alert
```

## Notes

- ESPN's live feed lags broadcast by a few seconds; the scoreboard follows
  the feed, not the screen.
- Multi-monitor setups mount one widget per screen; each refreshes on its
  own cadence, and toasts/celebrations fire on whichever instance detects
  the goal first.
- ESPN team ids are stable numeric ids (`2674` = Santos), used as-is for
  both matching and the crest cache.

## Files

```
russio.football/
├── README.md
├── manifest.json     # plugin registration for the omarchy-shell host
├── Panel.qml         # bar chip + tabbed popup + celebration overlay
└── Model.js          # ESPN scoreboard/standings parsing and PT-BR labels
```
