# Brazilian Série A Standings for Omarchy

English (US) · [Português (Brasil)](README.md)

Live scores, daily fixtures, and Brazilian league standings in the Omarchy bar.
Follow your club for optional notifications and goal celebrations.
Portuguese name: **Tabela Brasileirão Série A para Omarchy**.

![Scoreboard preview in the bar](preview.png)

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
consent before adding/enabling the plugin. There is no `sudo` installer or
automatic modification of other plugins. Run `omarchy restart shell` if necessary.

## Usage

Click the ball or score to open the popup; press `Q` or `Esc` to close it.
Left/right arrows switch tabs while the search field is not being edited.

| Tab | Contents |
| --- | --- |
| Jogos (Games) | Your club's match and daily fixtures. Another fixture selects its home team; clicking the followed fixture keeps your club. |
| Tabela (Standings) | Points, played, wins, draws, losses, and goal difference. Click a club to follow it. |
| Ajustes (Settings) | Team search, stop following, notifications, celebration/rival controls, and previews. |

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
| `league` | `bra.1` | ESPN league, such as `bra.2`, `bra.3`, or `eng.1`. Invalid codes fall back to `bra.1`. |
| `team` / `teamName` | empty | Positive decimal ID of up to ten digits and followed club name. |
| `goalNotifications` | `true` | Goal, kickoff, and full-time notifications. |
| `goalCelebration` | `true` | Automatic celebration when your club scores. |
| `rivalAlert` | `true` | Automatic effect when the opponent scores. |
| `badgeWhenIdle` | `true` | Keep the ball accessible without a match. |

The interface is in Brazilian Portuguese. Zone markers indicate the top four and
bottom four in larger tables; they do not model every rule, extra berth, or other league.

## Data, networking, and privacy

| Purpose | HTTPS destination |
| --- | --- |
| Fixtures | `site.api.espn.com/apis/site/v2/sports/soccer/<league>/scoreboard` |
| Standings | `site.api.espn.com/apis/v2/sports/soccer/<league>/standings` |
| Crests | `a.espncdn.com/i/teamlogos/soccer/500/<id>.png` |

Crest URLs from JSON are ignored: the destination is derived from a validated ID.
Downloads allow HTTPS only, follow no redirects, and ignore `.curlrc`. No telemetry
or credentials are sent. ESPN/CDN receive normal requests, including your network
address; local proxy/DNS/TLS configuration remains the system's responsibility.
The external API may change, lag, or limit requests.

Scores: every 25 seconds while your club is playing, 90 seconds for scheduled or
recently finished matches, ten minutes when idle. Standings: every 30 minutes or
when opening a stale popup. JSON: up to 2 MiB and 100 processed matches/rows.
Network failures or invalid JSON retain the last valid data and display a warning.

Crests: sequential downloads, up to 200 distinct IDs per instance/session, stored
in `~/.cache/omarchy/football/<id>.png` using private temporary files and atomic
replacement. Limit: 2 MiB, PNG signature, and dimensions up to 2048 × 2048 checked;
this does not replace Qt decoder security. Missing canonical URLs/download errors
show the abbreviation, without retries in the same session. Cache persists across
sessions without automatic pruning. Multiple monitors may issue independent
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
