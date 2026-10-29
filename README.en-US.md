# Brazilian Football Scores for Omarchy

English (US) · [Português (Brasil)](README.md)

Live scores, daily fixtures, and standings in the Omarchy bar for Série A,
Série B, Copa do Brasil, Libertadores, and Sudamericana. If you follow a club,
you get optional notifications and goal celebrations in every competition it
plays. The Portuguese name is **Futebol BR para Omarchy**. The plugin was
previously called *Brazilian Série A Standings*.

![Open panel showing Série A standings and all 20 club crests](preview.png)

Illustrative image: the Série A standings shown by the plugin on October 20,
2026. The standings may have changed since then. The selected club and the
highlights only demonstrate the interface and do not represent the plugin
author's club preferences.

## Requirements and installation

Omarchy 4.0+ with shell plugins, Quickshell/QtQuick, `curl` 8.4+,
`python3` 3.8+, and `notify-send` (`libnotify`). The plugin needs internet
access but no account, API key, or token.

```sh
omarchy plugin add https://github.com/JohnRenatoDev/omarchy-tabela-brasileirao-serie-a.git --enable
```

The repository used to be called `omarchy-football`. The permanent ID is still
`russio.football`, so existing settings carry over. The installer asks for your
confirmation before adding and enabling the plugin. Nothing in the installation
requires elevated privileges or changes other plugins. If the widget does not
appear, run `omarchy restart shell`.

## Usage

Click the ball or the score to open the popup. `Q` or `Esc` closes it, and the
left/right arrows switch tabs when you are not typing in the search field.

| Tab | Contents |
| --- | --- |
| Jogos (Games) | Your club's match from any competition, plus the selected competition's fixtures for the day. Clicking another fixture follows its home team; clicking your club's fixture keeps your choice. |
| Tabela (Standings) | Points, played, wins, draws, losses, and goal difference. The South American cups show one block per group. Click a club to follow it. |
| Ajustes (Settings) | Your club, the displayed competition, alerts, and previews. |

In Settings, the followed club sits at the top with the competitions it is
tracked in and a "Deixar de seguir" (unfollow) button. Search ignores accents
and covers every competition, so you can follow a Libertadores club while
Série A is on screen. Enter follows the first result and `Esc` clears the
search. With no club followed, the list shows the displayed competition's
clubs. Once you pick one, the list stays folded until you type. It shows up to
24 clubs and tells you the total when there are more.

### Competitions

| Competition | ESPN code | Standings |
| --- | --- | --- |
| Série A | `bra.1` | Single table, 20 clubs |
| Série B | `bra.2` | Single table, 20 clubs |
| Copa do Brasil | `bra.copa_do_brazil` | None (knockout) |
| Libertadores | `conmebol.libertadores` | Group stage (8 × 4) |
| Sudamericana | `conmebol.sudamericana` | Group stage (8 × 4) |

The plugin tracks your club in every catalog competition whose ESPN participant
list includes it, not only the displayed one. With Série A on screen, for
example, a goal by your club in the Libertadores still triggers a notification,
and both the notification and the popup name the competition. Série C and
Série D are not in the catalog because ESPN publishes no 2026 data for them.

Before kickoff the bar shows the local start time. During play it shows the
score and clock, `INT` at halftime, and `FIM` at full time. The result stays for
about 30 minutes after the end is first detected. Then the ball comes back, or
the slot hides if `badgeWhenIdle` is false. The ball also shows when no club is
selected.

Celebrations last about 2.6 seconds and rival alerts 1.9 seconds. These
overlays take no keyboard focus and do not capture clicks. Notifications,
celebrations, and rival alerts are switched on and off separately. Previews run
only when you ask for them and work even when the matching automatic effect is
off.

## Configuration

Use the popup controls. Settings live in the `russio.football` entry of
`~/.config/omarchy/shell.json`. The example below is that entry only, not the
whole file:

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
| `league` | `bra.1` | Displayed competition, picked in Settings. Accepts the codes in the competitions table and, for compatibility, other ESPN codes such as `eng.1`. Invalid codes fall back to `bra.1`. |
| `team` / `teamName` | empty | ID of the followed club (positive number of up to ten digits) and its name. |
| `goalNotifications` | `true` | Goal, kickoff, and full-time notifications. |
| `goalCelebration` | `true` | Automatic celebration when your club scores. |
| `rivalAlert` | `true` | Automatic effect when the opponent scores. |
| `badgeWhenIdle` | `true` | Keeps the ball in the bar when there is no match. |

The interface is in Brazilian Portuguese. The colored zones follow the 2026
rules:

| Competition | Zones |
| --- | --- |
| Série A | 1st to 4th Libertadores (blue), 5th Libertadores qualifying (light blue), 6th to 11th Sudamericana (pink), 17th to 20th relegation (theme alert color) |
| Série B | 1st and 2nd promotion (blue), 3rd to 6th promotion play-off (light blue), 17th to 20th relegation |
| Libertadores | In each group: 1st and 2nd reach the round of 16 (blue), 3rd goes to the Sudamericana round-of-16 play-off (pink) |
| Sudamericana | In each group: 1st reaches the round of 16 (blue), 2nd plays the round-of-16 play-off (light blue) |

The cup rules come from the CONMEBOL Libertadores 2026 and CONMEBOL
Sudamericana 2026 club manuals (June 2026 edition). The CBF rules come from
press reports of the regulations. The zones are a fixed reference, not a
confirmation of qualification: extra berths, cup winners, and rule changes can
change who qualifies. In the cups the displayed rank is ESPN's, which already
uses head-to-head as the first tiebreaker. For other ESPN leagues set by hand,
tables with more than 12 clubs mark the bottom four as indicative relegation.

The table has aligned columns for rank, club, points (Pts), played (J), wins
(V), draws (E), losses (D), and goal difference (SG). Separator lines divide
the rows, points are emphasized, and long club names are cut off before they
reach the statistics. The standings tab is wider than the others to fit
everything.

## Data, networking, and privacy

| Purpose | HTTPS destination |
| --- | --- |
| Fixtures | `site.api.espn.com/apis/site/v2/sports/soccer/<league>/scoreboard` |
| Standings | `site.api.espn.com/apis/v2/sports/soccer/<league>/standings` |
| Participants | `site.api.espn.com/apis/site/v2/sports/soccer/<league>/teams` |
| Crests | `a.espncdn.com/i/teamlogos/soccer/500/<id>.png` |

The plugin ignores crest URLs in the JSON and builds the address from a
validated ID. Downloads accept HTTPS only, follow no redirects, and ignore
`.curlrc`. There is no telemetry and no credentials are sent. ESPN and the CDN
receive ordinary requests, which include your network address. Local proxy,
DNS, and TLS settings are up to your system. The external API may change, lag,
or limit requests.

Scores refresh every 25 seconds while your club is playing, every 90 seconds
for scheduled or just-finished matches, and every ten minutes otherwise. Each
cycle queries, one at a time, the displayed competition and the others your
club plays (usually up to three requests). Standings refresh every 30 minutes,
or when you open the popup and they are stale. Copa do Brasil has no standings,
so the plugin does not request them. The participant lists for the five
competitions are fetched at startup and every 12 hours. The plugin accepts JSON
up to 2 MiB and processes up to 100 matches or rows. A network failure or
invalid JSON keeps the last valid data and shows a warning. Match clocks from
the API are capped at 32 characters, and longer values are ignored.
Minute and stoppage-time formatting does not use a backtracking regular
expression.

Crests are downloaded one at a time, up to 400 distinct IDs per instance and
session, and stored in `~/.cache/omarchy/football/png-v1/<id>.png` using
private temporary files and atomic replacement. Before handing a file to the UI
or to notifications, the helper caps the download at 2 MiB and the dimensions
at 2048 × 2048. It also validates the header, chunk framing, order, and CRCs,
and rebuilds the PNG using only `IHDR`, `PLTE`, `tRNS`, `IDAT`, and `IEND`. All
other ancillary chunks (compressed text, ICC profiles, EXIF, and animation) are
removed without decompression. Palette and transparency are kept; color
profiles and animation are not. The cache lives in a separate folder so crests
from the previous version are not reused. If a download fails, the previous
file is not used: the club's abbreviation shows instead, and the plugin does
not retry in the same session. The cache persists across sessions and is never
pruned automatically. This reduces the risk of metadata expansion, but it does
not validate the whole pixel stream or protect against other flaws in the
native decoder, so keep Qt and libpng updated. With several monitors, each
instance makes its own requests and alerts, with no synchronization between
them.

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

`openTab` accepts `jogos`, `tabela`, and `ajustes`. `status` reports the
version, the tracked competitions, counts, and the latest refresh errors. The
`celebrate` and `rivalGoal` previews require a selected club. Omarchy/Quickshell
controls IPC access.

## Updating and removal

```sh
omarchy plugin update russio.football
omarchy plugin remove russio.football
```

The manager unloads and removes the plugin. Cached crests stay on disk. To
delete them, run this separately:

```sh
rm -rf -- "$HOME/.cache/omarchy/football"
```

## Development and license

`Panel.qml` handles the UI and IPC, `Model.js` parses the data, and
`CrestCache.py` downloads and stores crests. Validate with
`omarchy plugin validate .` and `git diff --check`.

### Rights to code, preview, and third-party content

The code is distributed under the [MIT license](LICENSE). The maintainer
confirms having the rights or permissions required to publish the code and
preview included in this repository and to submit them to the marketplace.

Club crests, names, and trademarks, as well as ESPN data and content, belong to
their respective owners. The code's MIT license does not automatically apply to
these elements and does not authorize their redistribution or trademark use.
Showing them in the plugin or preview does not transfer rights or imply
endorsement. Any use of these elements must respect the permissions and terms
of their respective owners.

This is an independent project with no affiliation, sponsorship, or endorsement
from ESPN, the clubs, or the competition organizers. To report a rights concern
or request an asset review, open a
[repository issue](https://github.com/JohnRenatoDev/omarchy-tabela-brasileirao-serie-a/issues).
