# Brazilian Football Scores for Omarchy

English (US) · [Português (Brasil)](README.md)

Live scores, daily fixtures, and standings in the Omarchy bar: Série A, Série B,
Copa do Brasil, Libertadores, and Sudamericana. Follow your club for optional
notifications and goal celebrations in every competition it plays.
Portuguese name: **Futebol BR para Omarchy**. Formerly *Brazilian Série A Standings*.

![Open panel showing Série A standings and all 20 club crests](preview.png)

**Illustrative image:** a capture of the Brazilian Série A standings displayed
by the plugin on **October 20, 2026**. Standings may change after that date. The
selected club and highlights only demonstrate the interface and **do not
represent the plugin author's club preferences**.

## Requirements and installation

Omarchy 4.0+ with shell plugins, Quickshell/QtQuick, `curl` 8.4+,
`python3` 3.8+, and `notify-send` (`libnotify`). Internet required;
no account, API key, or token needed.

```sh
omarchy plugin add https://github.com/JohnRenatoDev/omarchy-tabela-brasileirao-serie-a.git --enable
```

The repository was renamed from `omarchy-football` to
`omarchy-tabela-brasileirao-serie-a`. The permanent ID remains
`russio.football`, preserving existing settings. The installer requests
consent before adding/enabling the plugin. There is no installer requiring elevated privileges or
automatic modification of other plugins. Run `omarchy restart shell` if necessary.

## Usage

Click the ball or score to open the popup; press `Q` or `Esc` to close it.
Left/right arrows switch tabs while the search field is not being edited.

| Tab | Contents |
| --- | --- |
| Jogos (Games) | Your club's match (from any competition) and the selected competition's daily fixtures. Another fixture selects its home team; clicking the followed fixture keeps your club. |
| Tabela (Standings) | Points, played, wins, draws, losses, and goal difference; one block per group in the South American cups. Click a club to follow it. |
| Ajustes (Settings) | Your club and the competitions it is tracked in; accent-insensitive search across every competition (Enter follows the first result, Esc clears); displayed competition; alerts and previews. |

### Competitions

| Competition | ESPN code | Standings |
| --- | --- | --- |
| Série A | `bra.1` | Single table, 20 clubs |
| Série B | `bra.2` | Single table, 20 clubs |
| Copa do Brasil | `bra.copa_do_brazil` | None (knockout) |
| Libertadores | `conmebol.libertadores` | Group stage (8 × 4) |
| Sudamericana | `conmebol.sudamericana` | Group stage (8 × 4) |

Your club is tracked in every catalog competition whose ESPN participant list
includes it, not only the displayed one. For example, with Série A on screen, a
goal by your club in the Libertadores still notifies; the notification and the
popup name the competition. Settings lists the club's competitions. Série C and
Série D are not in the catalog: ESPN publishes no 2026 data for them.

The bar shows local kickoff time before the match, score/clock during play,
`INT` at halftime, and `FIM` at full time. The result remains for about 30 minutes
after the end is first detected. Then a ball appears, or the slot hides if
`badgeWhenIdle` is false. The ball also appears without a selected team.

Celebrations last about 2.6 seconds; rival alerts last 1.9 seconds. Surfaces request
no keyboard focus and have an empty input region. Notifications, celebration, and
rival alerts are independent. Manual previews are explicit actions and work even
when the corresponding automatic effect is off.

## Configuration

Use the popup controls. Settings belong to the `russio.football` entry in
`~/.config/omarchy/shell.json`. This example is an entry, not a complete file:

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

| Key | Default | Effect |
| --- | --- | --- |
| `league` | `bra.1` | Displayed competition; pick it in Settings. Accepts the codes in the competitions table and, for compatibility, other ESPN codes such as `eng.1`. Invalid codes fall back to `bra.1`. |
| `team` / `teamName` | empty | Positive decimal ID of up to ten digits and followed club name. |
| `goalNotifications` | `true` | Goal, kickoff, and full-time notifications. |
| `goalCelebration` | `true` | Automatic celebration when your club scores. |
| `rivalAlert` | `true` | Automatic effect when the opponent scores. |
| `badgeWhenIdle` | `true` | Keep the ball accessible without a match. |

The interface is in Brazilian Portuguese. Zones follow the 2026 rules:

| Competition | Zones |
| --- | --- |
| Série A | 1st–4th Libertadores (blue), 5th Libertadores qualifying (light blue), 6th–11th Sudamericana (pink), 17th–20th relegation (theme alert color) |
| Série B | 1st–2nd promotion (blue), 3rd–6th promotion play-off (light blue), 17th–20th relegation |
| Libertadores | Per group: 1st–2nd round of 16 (blue), 3rd Sudamericana round-of-16 play-off (pink) |
| Sudamericana | Per group: 1st round of 16 (blue), 2nd round-of-16 play-off (light blue) |

Sources: CONMEBOL Libertadores 2026 and CONMEBOL Sudamericana 2026 club manuals
(June 2026 edition) and CBF rules as reported by the press. These are fixed
reference zones, not confirmation of qualification: extra berths, cup winners,
and rule changes may affect the actual qualifiers. In the cups the displayed rank
is ESPN's, which already applies head-to-head as the first tiebreaker. For other
ESPN leagues set by hand, tables with more than 12 clubs keep indicative
relegation markers for the bottom four.

The table uses aligned columns for rank, club, points (Pts), played (J), wins (V),
draws (E), losses (D), and goal difference (SG). Row separators improve scanning,
points are emphasized, and long club names are elided without overlapping the
statistics. The standings tab is wider to accommodate the data.

## Data, networking, and privacy

| Purpose | HTTPS destination |
| --- | --- |
| Fixtures | `site.api.espn.com/apis/site/v2/sports/soccer/<league>/scoreboard` |
| Standings | `site.api.espn.com/apis/v2/sports/soccer/<league>/standings` |
| Participants | `site.api.espn.com/apis/site/v2/sports/soccer/<league>/teams` |
| Crests | `a.espncdn.com/i/teamlogos/soccer/500/<id>.png` |

Crest URLs from JSON are ignored: the destination is derived from a validated ID.
Downloads allow HTTPS only, follow no redirects, and ignore `.curlrc`. No telemetry
or credentials are sent. ESPN/CDN receive normal requests, including your network
address; local proxy/DNS/TLS configuration remains the system's responsibility.
The external API may change, lag, or limit requests.

Scores: every 25 seconds while your club is playing, 90 seconds for scheduled or
recently finished matches, ten minutes when idle. Each cycle queries, one at a
time, the displayed competition plus the others your club plays (usually up to
three requests). Standings: every 30 minutes or when opening a stale popup; Copa
do Brasil has no standings and is not queried for them. Participants of the five
competitions: at startup and every 12 hours. JSON: up to 2 MiB and 100 processed matches/rows.
Network failures or invalid JSON retain the last valid data and display a warning.
API match clocks are limited to 32 characters; longer values are ignored.
Minute/stoppage-time formatting does not use a backtracking regular expression.

Crests: sequential downloads, up to 400 distinct IDs per instance/session, stored
in `~/.cache/omarchy/football/png-v1/<id>.png` using private temporary files and
atomic replacement. Before exposing a file to the UI or notifications, the helper
limits downloads to 2 MiB and dimensions to 2048 × 2048, validates chunk framing,
order, header values and CRCs, and rebuilds the PNG using only `IHDR`, `PLTE`,
`tRNS`, `IDAT` and `IEND`. All other ancillary chunks, including compressed text,
ICC profiles, EXIF and animation, are removed **without decompression**. Palette
and transparency are preserved; color profiles and animation are not retained.
The separate cache prevents reuse of old-version crests. Failures do not expose
the previous file: the abbreviation is shown, without retries in the same session.
Cache persists across sessions without automatic pruning. This mitigates metadata
expansion, but is not full pixel-stream validation or a guarantee against other
native decoder flaws; keep Qt/libpng updated. Multiple monitors may issue independent
requests/alerts; there is no cross-instance synchronization.

## IPC

```sh
omarchy-shell russio.football toggle
omarchy-shell russio.football open
omarchy-shell russio.football close
omarchy-shell russio.football refresh
omarchy-shell russio.football status
omarchy-shell russio.football openTab tabela
omarchy-shell russio.football celebrate
omarchy-shell russio.football rivalGoal
```

`openTab` accepts `jogos`, `tabela`, and `ajustes`. `status` reports the version,
counts, and latest refresh errors. The `celebrate` and `rivalGoal` previews require
a selected team. Omarchy/Quickshell manages IPC access.

## Updating and removal

```sh
omarchy plugin update russio.football
omarchy plugin remove russio.football
```

The manager unloads/removes the plugin. To delete cached crests too, run this
separately if desired:

```sh
rm -rf -- "$HOME/.cache/omarchy/football"
```

## Development and license

`Panel.qml`: UI/IPC; `Model.js`: parsing; `CrestCache.py`: downloads/storage.
Validate with `omarchy plugin validate .` and `git diff --check`.

### Rights to code, preview, and third-party content

The code is distributed under the [MIT license](LICENSE). The maintainer confirms
having the rights or permissions required to publish the code and preview
included in this repository and submit them to the marketplace.

Club crests, names, and trademarks, as well as ESPN data and content, belong to
their respective owners. The code's MIT license does not automatically apply
to these elements or authorize their redistribution or trademark use. Display
in the plugin or preview does not transfer rights or imply endorsement. Use
must respect the applicable permissions and terms of the respective owners.

This is an independent project with no affiliation, sponsorship, or endorsement
from ESPN, the clubs, or competition organizers. To report a rights concern or
request an asset review, open a
[repository issue](https://github.com/JohnRenatoDev/omarchy-tabela-brasileirao-serie-a/issues).
