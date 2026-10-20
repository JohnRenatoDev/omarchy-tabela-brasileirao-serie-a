import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Brasileirão bar widget: crest·score·crest chip on the bar while the
// followed team has a game, goal/kickoff/final notifications over
// notify-send, a full-screen goal celebration, and a tabbed popup —
// Jogos (today's slate), Tabela (Serie A standings), Ajustes (team
// picker with search, toggles).
//
// Data comes from ESPN's public scoreboard/standings endpoints (no key),
// fetched by curl like the weather widget. Crests are cached as PNGs under
// ~/.cache/omarchy/football/ and always rendered from disk — the bar never
// loads remote art directly.

Panel {
  id: root
  moduleName: "russio.football"
  ipcTarget: "russio.football"
  // The panel owns the IPC target outright so refresh()/celebrate() join
  // the standard open/close route — same shape the bluetooth panel uses.
  manageIpc: false
  visible: true

  // ---- Shell-sourced look, the trio every panel resolves.
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color mutedColor: Qt.darker(foreground, 1.4)
  readonly property color accentColor: Color.accent
  readonly property color urgentColor: bar ? bar.urgent : Color.urgent
  readonly property var zoneColors: ({ libertadores: "#4b83d1", preLibertadores: "#68c5f5", sulAmericana: "#c55383", relegation: root.urgentColor })
  // Panel (unlike BarWidget) doesn't define vertical — mirror it from the
  // host bar so the chip can stack on side-mounted bars.
  readonly property bool vertical: bar ? bar.vertical : false

  // ---- Settings (inline shell.json entry of russio.football).
  readonly property string league: /^[a-z]{2,8}\.[1-9][0-9]?$/.test(String(setting("league", "bra.1")))
    ? String(setting("league", "bra.1")) : "bra.1"
  readonly property string teamId: Model.teamId(settingString("team", ""))
  readonly property string teamName: {
    var v = setting("teamName", "")
    return v === undefined || v === null ? "" : String(v)
  }
  readonly property bool teamFollowed: teamId !== ""
  readonly property bool goalNotifications: boolSetting("goalNotifications", true)
  readonly property bool goalCelebration: boolSetting("goalCelebration", true)
  readonly property bool rivalAlert: boolSetting("rivalAlert", true)
  readonly property bool badgeWhenIdle: boolSetting("badgeWhenIdle", true)

  function settingString(name, fallback) {
    var v = setting(name, fallback)
    if (v === undefined || v === null) return fallback
    return String(v)
  }

  function boolSetting(name, fallback) {
    var v = setting(name, fallback)
    if (v === undefined || v === null) return fallback
    return v === true || v === 1 || v === "true"
  }

  // ---- Popup state.
  property string activeTab: "jogos"
  property string searchText: ""
  property bool searchFocused: false

  // ---- Goal celebration overlay state. One overlay, two moods: "own" is
  //      the full party, "rival" a discreet angry vignette.
  property bool celebrating: false
  property string celebrationKind: "own"
  property string celebrationTeamId: ""
  property string celebrationTeamAbbr: ""
  property string celebrationTeamName: ""
  property string celebrationScoreLine: ""
  property real celebrationSeed: 0

  // ---- Match data.
  property var todayMatches: []          // parsed events for today
  property var match: null               // the followed team's match
  property var standings: []             // parsed Serie A table rows
  property bool scoreboardError: false
  property bool standingsError: false
  property var lastScoreState: null      // previous poll's {id, hs, as, state}
  property date postShownAt: new Date(0) // when the final score first showed
  property date lastStandingsAt: new Date(0)
  property date nowTick: new Date()      // minute tick driving hide timers

  // ---- Crest cache. teamId -> "file://…" URI; the whole map is reassigned
  //      after each landing so Image bindings re-evaluate.
  property var crestUris: ({})
  property var crestQueue: []
  property var crestHrefQueued: ({})
  property string fetchingCrestId: ""
  property string fetchingCrestTarget: ""
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/omarchy/football"

  // Polling cadence — live ticks fast, idle days coast.
  readonly property int pollLiveMs: 25000
  readonly property int pollActiveMs: 90000
  readonly property int pollIdleMs: 600000
  readonly property int standingsRefreshMs: 1800000
  readonly property int postTailMs: 30 * 60 * 1000
  readonly property string followedMatchId: match ? match.id : ""

  readonly property int scoreboardIntervalMs: {
    var m = root.match
    if (m && (m.state === "live" || m.state === "halftime")) return root.pollLiveMs
    if (m && ((m.state === "pre")
              || (m.state === "post"
                  && (nowTick.getTime() - postShownAt.getTime()) < root.postTailMs)))
      return root.pollActiveMs
    return root.pollIdleMs
  }

  // What the bar slot renders. "setup" invites the first pick, "idle" is a
  // lone crest on no-game days, "hidden" frees the slot entirely.
  readonly property string chipMode: {
    if (!root.teamFollowed) return "setup"
    var m = root.match
    if (m) {
      if (m.state === "pre") return "upcoming"
      if (m.state === "post")
        return (nowTick.getTime() - postShownAt.getTime()) < root.postTailMs
          ? "final" : (badgeWhenIdle ? "idle" : "hidden")
      return "live"
    }
    return badgeWhenIdle ? "idle" : "hidden"
  }

  // ============================== FETCH ==============================

  function refreshScoreboard() {
    if (scoreboardProc.running) return
    scoreboardProc.command = ["curl", "--disable", "-fsS", "--proto", "=https",
      "--max-filesize", "2097152", "--connect-timeout", "5", "--max-time", "12", "--",
      "https://site.api.espn.com/apis/site/v2/sports/soccer/" + root.league + "/scoreboard"]
    scoreboardProc.running = true
  }

  Timer {
    id: scoreboardTimer
    interval: root.scoreboardIntervalMs
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: root.refreshScoreboard()
  }

  // Interval shifts come from state transitions — restart so the new
  // cadence governs the next tick rather than finishing the old cycle.
  onScoreboardIntervalMsChanged: scoreboardTimer.restart()

  function refreshStandings() {
    if (standingsProc.running) return
    standingsProc.command = ["curl", "--disable", "-fsS", "--proto", "=https",
      "--max-filesize", "2097152", "--connect-timeout", "5", "--max-time", "12", "--",
      "https://site.api.espn.com/apis/v2/sports/soccer/" + root.league + "/standings"]
    standingsProc.running = true
  }

  Timer {
    id: standingsTimer
    interval: root.standingsRefreshMs
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: root.refreshStandings()
  }

  function open() {
    controller.show()
    activeTab = "jogos"
    if (standingsProc.running) return
    // Table is stale past half a refresh cycle (or never fetched) — the
    // open is exactly when the user will look at it.
    if (!root.standings.length
        || (new Date().getTime() - lastStandingsAt.getTime()) > root.standingsRefreshMs / 2)
      root.refreshStandings()
  }

  function close() { controller.hide() }

  Component.onCompleted: {
    root.refreshScoreboard()
    root.refreshStandings()
  }

  Process {
    id: scoreboardProc
    stdout: StdioCollector {
      id: scoreboardOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0) root.applyScoreboard(scoreboardOutput.text)
      else root.scoreboardError = true
    }
  }

  Process {
    id: standingsProc
    stdout: StdioCollector {
      id: standingsOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0) root.applyStandings(standingsOutput.text)
      else root.standingsError = true
    }
  }

  // Minute sweep so chip states that depend on the clock (post-tail
  // expiry, an upcoming kickoff arriving between polls) flip without a
  // data event of their own.
  Timer {
    id: chipTicker
    interval: 60000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: root.nowTick = new Date()
  }

  function applyScoreboard(raw) {
    var events = []
    try { events = Model.parseScoreboard(JSON.parse(raw)) } catch (e) {
      root.scoreboardError = true
      return
    }
    root.scoreboardError = false
    for (var i = 0; i < events.length; i++) {
      root.queueCrest(events[i].home.id)
      root.queueCrest(events[i].away.id)
    }
    root.todayMatches = events
    root.match = Model.pickFollowed(events, root.teamId)
    root.handleNotifications(root.match)
  }

  function applyStandings(raw) {
    var rows = []
    try { rows = Model.parseStandings(JSON.parse(raw)) } catch (e) {
      root.standingsError = true
      return
    }
    root.standingsError = false
    for (var i = 0; i < rows.length; i++) root.queueCrest(rows[i].id)
    root.standings = rows
    if (rows.length) root.lastStandingsAt = new Date()
  }

  // ========================= NOTIFICATIONS ===========================

  function handleNotifications(current) {
    var prev = root.lastScoreState
    root.lastScoreState = current
      ? { id: current.id, hs: current.home.score, as: current.away.score, state: current.state }
      : null

    if (current && current.state === "post" && (!prev || prev.id !== current.id || prev.state !== "post")) {
      root.postShownAt = new Date()
      root.nowTick = new Date()
    }
    if (!current || !prev || prev.id !== current.id) return

    // The final-score tail on the bar starts its countdown at the live→post
    // flip regardless of notification settings.
    if ((prev.state === "live" || prev.state === "halftime") && current.state === "post") {
      root.postShownAt = new Date()
      root.nowTick = new Date()
      if (root.goalNotifications) root.notify("🏁 Fim de jogo", Model.matchLine(current), root.teamId)
    }

    if (root.goalNotifications && prev.state === "pre" && (current.state === "live" || current.state === "halftime"))
      root.notify("⚽ Começa o jogo!", Model.matchLine(current), root.teamId)

    var scorers = []
    if (current.home.score > prev.hs) scorers.push(current.home)
    if (current.away.score > prev.as) scorers.push(current.away)
    scorers.sort(function(first, second) {
      return (first.id === root.teamId ? 1 : 0) - (second.id === root.teamId ? 1 : 0)
    })
    for (var index = 0; index < scorers.length; index++) root.onGoal(current, scorers[index])
  }

  function notifyGoalOf(matchNow, team) {
    var scorerIsHome = team.id === matchNow.home.id
    var summary = "⚽ GOOOL — " + team.name + "!"
    var body = matchNow.home.abbr + " " + matchNow.home.score + " × "
      + matchNow.away.score + " " + matchNow.away.abbr
    var clock = Model.clockLabel(matchNow)
    if (clock) body += " · " + clock
    root.notify(summary, body, scorerIsHome ? matchNow.home.id : matchNow.away.id)
  }

  // notify-send lands in the shell's own notification daemon — the same
  // channel omarchy reminders ride. The cached crest PNG, once present,
  // becomes the toast icon.
  function notify(summary, body, iconTeamId) {
    var args = ["notify-send", "-a", "Brasileirão", "-t", "8000"]
    var uri = root.crestUris[iconTeamId]
    if (uri) args.push("-i", uri.replace("file://", ""))
    args.push("--", summary, Model.notificationText(body))
    Quickshell.execDetached(args)
  }

  // ---- Full-screen goal overlay. The Loader tears the content down at
  //      hide, so each goal replays from scratch with fresh confetti seeds.
  //      "own" is the fast full party; "rival" the discreet angry vignette.
  function celebrate(team, matchNow, kind) {
    root.celebrationKind = kind === "rival" ? "rival" : "own"
    root.celebrationTeamId = team.id
    root.celebrationTeamAbbr = team.abbr
    root.celebrationTeamName = team.name
    root.celebrationScoreLine = matchNow.home.abbr + " " + matchNow.home.score + " × "
      + matchNow.away.score + " " + matchNow.away.abbr
    var clock = Model.clockLabel(matchNow)
    if (clock) root.celebrationScoreLine += " · " + clock
    root.celebrationSeed = Math.random()
    // Happens and disappears — own ~2.6s, rival ~1.9s.
    celebrationHideTimer.interval = root.celebrationKind === "rival" ? 1900 : 2600
    root.celebrating = true
    celebrationHideTimer.restart()
  }

  // A goal landed: toast per notifications, overlay per mood.
  function onGoal(matchNow, team) {
    var own = team.id === root.teamId
    if (root.goalNotifications) root.notifyGoalOf(matchNow, team)
    if (own) {
      if (root.goalCelebration) root.celebrate(team, matchNow, "own")
    } else if (root.rivalAlert) {
      root.celebrate(team, matchNow, "rival")
    }
  }

  // Manual trigger for the IPC route — same show, no goal required.
  function testCelebrate(kind) {
    if (!root.teamFollowed) return
    var m = root.match
    var wantRival = kind === "rival"
    var team = null
    if (m) {
      // "own" celebrates the followed side; "rival" its opponent.
      team = (m.home.id === root.teamId) === !wantRival ? m.home : m.away
    } else {
      var abbr = root.teamName.slice(0, 3).toUpperCase()
      team = wantRival
        ? { id: "99999", abbr: "RVA", name: "Rival FC", logo: "", color: "", alternateColor: "", score: 0 }
        : { id: root.teamId, abbr: abbr, name: root.teamName, logo: "", color: "", alternateColor: "", score: 0 }
      m = { home: { abbr: wantRival ? abbr : "RVA", score: wantRival ? 0 : 1 },
            away: { abbr: wantRival ? abbr : "RVA", score: 0 },
            state: "live", clock: "90'" }
      if (wantRival) m = { home: { abbr: abbr, score: 0 }, away: { abbr: "RVA", score: 1 },
                           state: "live", clock: "90'" }
    }
    root.celebrate(team, m, wantRival ? "rival" : "own")
  }

  Timer {
    id: celebrationHideTimer
    interval: 2600
    onTriggered: root.celebrating = false
  }

  // ========================== CREST CACHE ============================

  function queueCrest(teamId) {
    teamId = Model.teamId(teamId)
    if (!teamId) return
    if (root.crestUris[teamId] !== undefined) return
    if (root.crestHrefQueued[teamId]) return
    if (Object.keys(root.crestHrefQueued).length >= 200) return
    root.crestHrefQueued[teamId] = true
    root.crestQueue.push({ id: teamId })
    root.pumpCrests()
  }

  // One curl at a time; each lands as teamId.png. Failure is permanent for
  // this session (no retry storm out of 25s live polls) — the crest keeps
  // rendering as its abbreviation instead.
  function pumpCrests() {
    if (crestProc.running || root.crestQueue.length === 0) return
    var job = root.crestQueue.shift()
    root.fetchingCrestId = job.id
    root.fetchingCrestTarget = root.cacheDir + "/" + job.id + ".png"
    crestProc.command = ["python3", decodeURIComponent(Qt.resolvedUrl("CrestCache.py").toString().replace(/^file:\/\//, "")),
      root.cacheDir, job.id]
    crestProc.running = true
  }

  Process {
    id: crestProc
    onExited: function(exitCode) {
      if (exitCode === 0 && root.fetchingCrestId) {
        var next = Object.assign({}, root.crestUris)
        next[root.fetchingCrestId] = "file://" + root.fetchingCrestTarget
        root.crestUris = next
      }
      Qt.callLater(root.pumpCrests)
    }
  }

  // ========================= FOLLOW A TEAM ===========================

  // Single persistence path: clone the current shell.json entry, let the
  // caller mutate the clone, then apply locally and write back through the
  // bar host — the clock widget's format-cycling pattern.
  function writeSettings(apply) {
    var entry = { id: root.moduleName }
    if (root.settings) {
      for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    }
    apply(entry)
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function selectTeam(id, name) {
    if (!Model.teamId(id)) return
    root.writeSettings(function(e) {
      e.team = String(id)
      e.teamName = String(name)
    })
    root.resetFollowedState()
    root.refreshScoreboard()
  }

  function clearTeam() {
    root.writeSettings(function(e) {
      delete e.team
      delete e.teamName
    })
    root.resetFollowedState()
    root.refreshScoreboard()
  }

  function setSetting(name, value) {
    root.writeSettings(function(e) { e[name] = value })
  }

  function resetFollowedState() {
    root.match = null
    root.lastScoreState = null
    root.postShownAt = new Date(0)
    root.nowTick = new Date()
  }

  // ============================ BAR CHIP =============================

  function chipTooltip() {
    if (!root.teamFollowed) return "Brasileirão · clique para escolher seu time"
    var m = root.match
    if (!m) return "Brasileirão " + Model.leagueName(root.league) + " · seguindo " + (root.teamName || "seu time")
    return Model.matchLine(m) + " · " + (m.home.name + " × " + m.away.name)
  }

  function chipCenterText(matchNow) {
    // stateLabel covers every state: pre → "HH:MM", live → "45'",
    // halftime → "INT", post → "FIM".
    return matchNow ? Model.stateLabel(matchNow) : ""
  }

  // The slot closes cleanly when hidden — no stray padding from an
  // invisible button.
  implicitWidth: root.chipMode === "hidden" ? 0 : button.implicitWidth
  implicitHeight: root.chipMode === "hidden" ? 0 : button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: root.chipMode !== "hidden"
    tooltipText: root.chipTooltip()
    // Custom content replaces the text label — the slot closes around the
    // chip row/column plus the button's own margins.
    fixedWidth: root.vertical
      ? -1
      : Math.max(12, hChip.implicitWidth + button.scaledHorizontalMargin * 2)
    fixedHeight: root.vertical
      ? Math.max(12, vChip.implicitHeight + button.scaledVerticalPadding * 2)
      : -1
    horizontalMargin: 8.5
    verticalPadding: 6

    onPressed: function(b) { root.toggle() }

    // ---- Horizontal: live dot · crest · score · clock · score · crest
    Row {
      id: hChip
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: Style.space(5)

      Rectangle {
        width: 5
        height: 5
        radius: 2.5
        anchors.verticalCenter: parent.verticalCenter
        visible: root.chipMode === "live"
        color: root.accentColor
        SequentialAnimation on opacity {
          running: root.chipMode === "live"
          loops: Animation.Infinite
          NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.OutQuad }
          NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InQuad }
        }
      }

      Crest {
        size: 14
        teamId: root.match ? root.match.home.id : root.teamId
        abbr: root.match ? root.match.home.abbr
          : root.teamName.slice(0, 3).toUpperCase()
        visible: root.chipMode === "upcoming" || root.chipMode === "live" || root.chipMode === "final"
      }

      Text {
        textFormat: Text.PlainText
        text: root.match ? String(root.match.home.score) : ""
        visible: root.chipMode === "live" || root.chipMode === "final"
        color: root.match && root.match.home.id === root.teamId
          ? root.accentColor : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: root.match && root.match.home.id === root.teamId
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.chipCenterText(root.match)
        visible: root.match !== null
        color: root.chipMode === "live" ? root.accentColor : root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: root.chipMode === "live"
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.match ? String(root.match.away.score) : ""
        visible: root.chipMode === "live" || root.chipMode === "final"
        color: root.match && root.match.away.id === root.teamId
          ? root.accentColor : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: root.match && root.match.away.id === root.teamId
        anchors.verticalCenter: parent.verticalCenter
      }

      Crest {
        size: 14
        teamId: root.match ? root.match.away.id : root.teamId
        abbr: root.match ? root.match.away.abbr
          : root.teamName.slice(0, 3).toUpperCase()
        visible: root.chipMode === "upcoming" || root.chipMode === "live" || root.chipMode === "final"
      }

      Text {
        textFormat: Text.PlainText
        // Ball on the bar whenever there's no live game to show: setup
        // invites the first pick, idle days keep the widget reachable.
        text: "⚽"
        visible: root.chipMode === "setup" || root.chipMode === "idle"
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.chipMode === "idle" ? 0.55 : 0.9
      }
    }

    // ---- Vertical: crests on one line, score/clock beneath.
    Column {
      id: vChip
      visible: root.vertical
      anchors.centerIn: parent
      spacing: 0

      Row {
        spacing: Style.space(4)
        anchors.horizontalCenter: parent.horizontalCenter

        // First crest: the home side when a game is on; idle shows only the
        // ball, not the crest.
        Crest {
          size: 12
          teamId: hHomeCrestVisible() && root.match ? root.match.home.id : root.teamId
          abbr: hHomeCrestVisible() && root.match
            ? root.match.home.abbr : root.teamName.slice(0, 3).toUpperCase()
          visible: hHomeCrestVisible()
        }

        Crest {
          size: 12
          teamId: root.match ? root.match.away.id : root.teamId
          abbr: root.match ? root.match.away.abbr : ""
          visible: hHomeCrestVisible()
        }

        Text {
          textFormat: Text.PlainText
          text: "⚽"
          visible: root.chipMode === "setup" || root.chipMode === "idle"
          font.pixelSize: Style.font.caption
          font.family: root.fontFamily
          opacity: root.chipMode === "idle" ? 0.55 : 0.9
        }
      }

      Text {
        textFormat: Text.PlainText
        text: {
          var m = root.match
          if (!m) return ""
          if (root.chipMode === "upcoming") return Model.stateLabel(m)
          if (root.chipMode === "final") return m.home.score + "–" + m.away.score
          if (root.chipMode === "live")
            return m.home.score + "–" + m.away.score + " " + Model.stateLabel(m)
          return ""
        }
        visible: root.chipMode === "upcoming" || root.chipMode === "live" || root.chipMode === "final"
        color: root.chipMode === "live" ? root.accentColor : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.horizontalCenter: parent.horizontalCenter
      }
    }
  }

  // Matches the horizontal chip's visibility rule without reaching across
  // inline component trees.
  function hHomeCrestVisible() {
    return root.chipMode === "upcoming" || root.chipMode === "live" || root.chipMode === "final"
  }

  // ==================== GOAL CELEBRATION OVERLAY =====================

  // Full-screen, click-through, input-free layer — the OSD's window recipe.
  // Lives on the shell's default screen like the OSD does.
  PanelWindow {
    id: celebrationPanel
    visible: root.celebrating
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "russio-football-goal"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Visual-only surface: empty input region so the party never eats a click.
    mask: Region {}

    Loader {
      id: celebrationLoader
      anchors.fill: parent
      active: root.celebrating
      sourceComponent: root.celebrationKind === "rival" ? rivalComponent : celebrationComponent
    }
  }

  // Celebration colors mirrored from the scorer's ESPN palette; accent keeps
  // them usable when the API omits color fields.
  readonly property color celebrationColor: {
    var raw = ""
    if (root.match) {
      raw = root.celebrationTeamId === root.match.home.id ? root.match.home.color
        : (root.celebrationTeamId === root.match.away.id ? root.match.away.color : "")
    }
    return raw ? raw : root.accentColor
  }
  readonly property color celebrationAlternateColor: {
    var raw = ""
    if (root.match) {
      raw = root.celebrationTeamId === root.match.home.id ? root.match.home.alternateColor
        : (root.celebrationTeamId === root.match.away.id ? root.match.away.alternateColor : "")
    }
    return raw ? raw : root.foreground
  }

  Component {
    id: celebrationComponent

    Item {
      id: celebration
      anchors.fill: parent

      // Deterministic hash of (seed, index) — fresh every goal, stable per
      // replay so a piece's x/size/rotation agree across its bindings.
      function pieceSeed(index) {
        var n = Math.sin((root.celebrationSeed * 1000 + index) * 12.9898) * 43758.5453
        return n - Math.floor(n)
      }

      function pieceColor(index) {
        var palette = [root.celebrationColor, root.celebrationAlternateColor,
                       "#ffffff", root.accentColor, root.celebrationColor]
        return palette[index % palette.length]
      }

      // Expanding rings from center — the shockwave of the roar.
      Repeater {
        model: 2

        Rectangle {
          id: ring
          required property int index
          anchors.centerIn: parent
          width: 220
          height: 220
          radius: 110
          color: "transparent"
          border.width: 3
          border.color: root.celebrationColor
          transformOrigin: Item.Center
          SequentialAnimation {
            running: root.celebrating
            loops: 1
            PauseAnimation { duration: ring.index * 240 }
            ParallelAnimation {
              NumberAnimation { target: ring; property: "scale"; from: 0.3; to: 4.5; duration: 1000; easing.type: Easing.OutQuad }
              NumberAnimation { target: ring; property: "opacity"; from: 0.55; to: 0.0; duration: 1000 }
            }
          }
        }
      }

      // Double white flash on arrival — the crowd-roar cue.
      Rectangle {
        id: flash
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
        SequentialAnimation on opacity {
          running: root.celebrating
          loops: 1
          NumberAnimation { to: 0.30; duration: 80; easing.type: Easing.OutQuad }
          NumberAnimation { to: 0.0; duration: 440; easing.type: Easing.InQuad }
        }
      }

      // Confetti: falling strips in the team's colors, two staggered waves.
      // Bounded animations only — no infinite loops tied to the overlay.
      Repeater {
        model: 36

        Rectangle {
          id: piece
          required property int index
          readonly property real seed: celebration.pieceSeed(index)
          readonly property real delay: index < 24 ? 0 : 600
          readonly property real fallMs: 1000 + seed * 1100
          width: 6 + seed * 5
          height: 10 + (1 - seed) * 10
          radius: 2
          color: celebration.pieceColor(index)
          x: seed * (celebration.width - 24) + 12
          y: -40
          rotation: seed * 360
          opacity: 0

          SequentialAnimation {
            running: root.celebrating
            loops: 1
            PauseAnimation { duration: piece.delay }
            ParallelAnimation {
              NumberAnimation { target: piece; property: "opacity"; to: 0.95; duration: 120 }
              NumberAnimation {
                target: piece; property: "y"
                from: -40; to: celebration.height + 80
                duration: piece.fallMs; easing.type: Easing.InQuad
              }
              NumberAnimation {
                target: piece; property: "rotation"
                to: piece.rotation + 540 + piece.seed * 500
                duration: piece.fallMs
              }
            }
          }
        }
      }

      // Radial burst — shards explode outward from behind the GOOOL! block
      // in every direction, spin hard and fade as they fly.
      Repeater {
        model: 20

        Item {
          id: burstHolder
          required property int index
          readonly property real seed: celebration.pieceSeed(index + 200)
          readonly property real angle: (index / 28.0) * Math.PI * 2 + (seed - 0.5) * 0.9
          readonly property real dist: 130 + seed * 260
          readonly property real flyMs: 1200 + seed * 800
          anchors.centerIn: parent
          width: 1
          height: 1

          Rectangle {
            id: shard
            width: 5 + burstHolder.seed * 5
            height: 8 + burstHolder.seed * 7
            radius: 2
            x: -width / 2
            y: -height / 2
            color: celebration.pieceColor(burstHolder.index + 3)
            rotation: burstHolder.seed * 360

            ParallelAnimation {
              running: root.celebrating
              NumberAnimation {
                target: shard; property: "x"
                from: -shard.width / 2
                to: burstHolder.dist * Math.cos(burstHolder.angle) - shard.width / 2
                duration: burstHolder.flyMs; easing.type: Easing.OutCubic
              }
              NumberAnimation {
                target: shard; property: "y"
                from: -shard.height / 2
                to: burstHolder.dist * Math.sin(burstHolder.angle) - shard.height / 2
                duration: burstHolder.flyMs; easing.type: Easing.OutQuad
              }
              NumberAnimation {
                target: shard; property: "rotation"
                to: shard.rotation + 720
                duration: burstHolder.flyMs
              }
              SequentialAnimation {
                NumberAnimation { target: shard; property: "opacity"; to: 1.0; duration: burstHolder.flyMs * 0.45 }
                NumberAnimation { target: shard; property: "opacity"; to: 0.0; duration: burstHolder.flyMs * 0.55 }
              }
            }
          }
        }
      }

      // Center block: crest springs in with GOOOL!, the whole block
      // breathes, then fades as the party ends.
      Column {
        id: block
        anchors.centerIn: parent
        spacing: Style.space(16)
        transformOrigin: Item.Center

        Crest {
          size: 148
          teamId: root.celebrationTeamId
          abbr: root.celebrationTeamAbbr
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
          id: goalText
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "GOOOL!"
          color: root.accentColor
          font.family: root.fontFamily
          font.pixelSize: Math.max(72, Math.round(celebration.height / 8))
          font.bold: true
          style: Text.Outline
          styleColor: root.foreground
          transformOrigin: Item.Center

          SequentialAnimation on scale {
            running: root.celebrating
            loops: 3
            NumberAnimation { to: 1.10; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1.0; duration: 300; easing.type: Easing.InQuad }
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.celebrationTeamName + "  ·  " + root.celebrationScoreLine
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
      }

      SequentialAnimation {
        running: root.celebrating
        loops: 1

        // Spring in from nothing.
        ParallelAnimation {
          NumberAnimation { target: block; property: "scale"; from: 0.15; to: 1.0; duration: 320; easing.type: Easing.OutBack }
          NumberAnimation { target: block; property: "opacity"; from: 0.0; to: 1.0; duration: 140 }
        }

        // Double bounce settle — the crest punches the air twice.
        SequentialAnimation {
          NumberAnimation { target: block; property: "scale"; to: 1.06; duration: 110; easing.type: Easing.OutQuad }
          NumberAnimation { target: block; property: "scale"; to: 0.99; duration: 110; easing.type: Easing.OutQuad }
          NumberAnimation { target: block; property: "scale"; to: 1.03; duration: 100; easing.type: Easing.OutQuad }
          NumberAnimation { target: block; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
        }

        // Hold while the confetti falls, then bow out.
        PauseAnimation { duration: 1500 }
        NumberAnimation { target: block; property: "opacity"; to: 0.0; duration: 380; easing.type: Easing.InQuad }
      }
    }
  }

  // ---- Rival goal: discreet and bitter. A brief urgent-colored vignette
  //      pulse, the scorer's crest drops in tilted and fades — under two
  //      seconds, no confetti, no flash.
  Component {
    id: rivalComponent

    Item {
      id: rival
      anchors.fill: parent

      // Vignette pulse — the room goes cold for a beat.
      Rectangle {
        anchors.fill: parent
        color: root.urgentColor
        opacity: 0
        SequentialAnimation on opacity {
          running: root.celebrating
          loops: 1
          NumberAnimation { to: 0.13; duration: 140; easing.type: Easing.OutQuad }
          NumberAnimation { to: 0.0; duration: 1100; easing.type: Easing.InQuad }
        }
      }

      Column {
        id: rivalBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.16)
        spacing: Style.space(6)

        Crest {
          size: 44
          teamId: root.celebrationTeamId
          abbr: root.celebrationTeamAbbr
          anchors.horizontalCenter: parent.horizontalCenter
          rotation: -8
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "Argh… gol do " + root.celebrationTeamName
          color: root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.celebrationScoreLine
          color: root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      SequentialAnimation {
        running: root.celebrating
        loops: 1

        // Drop in, sulk, fade out — quick and quiet.
        ParallelAnimation {
          NumberAnimation { target: rivalBlock; property: "opacity"; from: 0.0; to: 1.0; duration: 220 }
          NumberAnimation { target: rivalBlock; property: "anchors.bottomMargin"; from: Math.round(rival.height * 0.16) + 18; to: Math.round(rival.height * 0.16); duration: 340; easing.type: Easing.OutBack }
        }
        PauseAnimation { duration: 1100 }
        NumberAnimation { target: rivalBlock; property: "opacity"; to: 0.0; duration: 320; easing.type: Easing.InQuad }
      }
    }
  }

  // ============================== IPC ===============================

  IpcHandler {
    target: "russio.football"

    function status(): string {
      return JSON.stringify({ version: "1.0.2", league: root.league, team: root.teamId,
        matches: root.todayMatches.length, standings: root.standings.length,
        cachedCrests: Object.keys(root.crestUris).length, queuedCrests: root.crestQueue.length,
        scoreboardError: root.scoreboardError, standingsError: root.standingsError,
        opened: root.opened, activeTab: root.activeTab, celebrating: root.celebrating })
    }

    function open() { root.open() }
    function openTab(name: string): void {
      if (["jogos", "tabela", "ajustes"].indexOf(name) < 0) return
      root.open()
      root.activeTab = name
    }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function refresh(): void {
      root.refreshScoreboard()
      root.refreshStandings()
    }
    function celebrate(): void { root.testCelebrate("own") }
    function rivalGoal(): void { root.testCelebrate("rival") }
  }

  // ============================== POPUP ==============================

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(popupColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.searchFocused
      onCloseRequested: root.close()
      onTextKey: function(text) { if (text.toLowerCase() === "q") root.close() }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          var tabs = ["jogos", "tabela", "ajustes"]
          root.activeTab = tabs[(tabs.indexOf(root.activeTab) + dx + tabs.length) % tabs.length]
        }
        if (dy > 0) popupScroll.contentY = Math.max(0, Math.min(
          popupScroll.contentHeight - popupScroll.height,
          popupScroll.contentY + Style.space(24)))
        else if (dy < 0) popupScroll.contentY = Math.max(0,
          popupScroll.contentY - Style.space(24))
      }
      onActivateRequested: {}

      Flickable {
        id: popupScroll
        anchors.fill: parent
        contentWidth: popupColumn.width
        contentHeight: popupColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: popupColumn
          width: popupScroll.width
          spacing: Style.space(12)

          // ---------- Compact hero: followed team + state word ----------
          Row {
            width: parent.width
            spacing: Style.space(10)

            Crest {
              id: heroCrest
              size: 30
              teamId: root.teamId
              abbr: root.teamName.slice(0, 3).toUpperCase()
              opacity: root.teamFollowed ? 1.0 : 0.5
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              width: parent.width - heroCrest.width - parent.spacing
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1

              Text {
                textFormat: Text.PlainText
                text: root.teamFollowed
                  ? (root.teamName || "Seu time")
                  : "Brasileirão · " + Model.leagueName(root.league)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: root.heroStateLine()
                color: root.hasLiveMatch() ? root.accentColor : root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.hasLiveMatch()
                font.letterSpacing: root.hasLiveMatch() ? 1.2 : 0
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }

          // ---------- Tab bar ----------
          Row {
            width: parent.width
            spacing: 0

            Repeater {
              model: [
                { id: "jogos", label: "JOGOS" },
                { id: "tabela", label: "TABELA" },
                { id: "ajustes", label: "AJUSTES" }
              ]

              Item {
                id: tabItem
                required property var modelData
                readonly property bool active: root.activeTab === modelData.id
                width: tabLabel.implicitWidth + Style.space(28)
                height: 30

                Text {
                  id: tabLabel
                  anchors.centerIn: parent
                  text: modelData.label
                  color: tabItem.active ? root.accentColor : root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: tabItem.active
                  font.letterSpacing: 1.4
                  textFormat: Text.PlainText
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activeTab = modelData.id
                }

                Rectangle {
                  anchors.horizontalCenter: tabLabel.horizontalCenter
                  anchors.bottom: parent.bottom
                  width: tabLabel.implicitWidth
                  height: 2
                  radius: 1
                  color: root.accentColor
                  visible: tabItem.active
                }
              }
            }
          }

          Loader {
            width: parent.width
            sourceComponent: root.activeTab === "tabela"
              ? tabelaComponent
              : (root.activeTab === "ajustes" ? ajustesComponent : jogosComponent)
          }
        }
      }
    }
  }

  // ---- Hero status: short word, the score lives in the jogos card.
  function heroStateLine() {
    if (root.scoreboardError) return "Falha na atualização · dados anteriores"
    if (!root.teamFollowed) return "Escolha o seu time nos ajustes"
    var m = root.match
    if (!m) return "Sem jogo hoje"
    if (m.state === "pre") return "HOJE · " + Model.hhmm(m.date)
    if (m.state === "halftime") return "INTERVALO"
    if (m.state === "live") return "AO VIVO"
    if (m.state === "post") return "FIM DE JOGO"
    return ""
  }

  function hasLiveMatch() {
    var m = root.match
    return !!m && (m.state === "live" || m.state === "halftime")
  }

  function roundCenterText(row) {
    if (row.state === "live") return Model.clockLabel(row) || "AO VIVO"
    if (row.state === "halftime") return "INT"
    if (row.state === "post") return row.home.score + "–" + row.away.score
    return Model.hhmm(row.date)
  }

  function rowCenterColor(row) {
    if (row.state === "live" || row.state === "halftime") return root.accentColor
    if (row.state === "post") return root.mutedColor
    return root.foreground
  }

  // ---- Team search across the standings roster.
  function filteredStandings() {
    var q = root.searchText.trim().toLowerCase()
    if (!q) return root.standings
    var out = []
    for (var i = 0; i < root.standings.length; i++) {
      var row = root.standings[i]
      var name = String(row.name || "").toLowerCase()
      var abbr = String(row.abbr || "").toLowerCase()
      if (name.indexOf(q) >= 0 || abbr.indexOf(q) >= 0) out.push(row)
    }
    return out
  }

  // ============================== TABS ===============================

  // ---- JOGOS: followed-match scoreboard card + today's round.
  Component {
    id: jogosComponent

    Column {
      id: jogosColumn
      width: parent.width
      spacing: Style.space(10)

      // Scoreboard card — only when the followed team actually plays today.
      Rectangle {
        visible: root.match !== null
        width: parent.width
        implicitHeight: 74
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : 10
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)

        Row {
          anchors.centerIn: parent
          spacing: Style.space(14)

          Column {
            spacing: Style.space(4)
            Crest {
              size: 28
              teamId: root.match ? root.match.home.id : ""
              abbr: root.match ? root.match.home.abbr : ""
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              textFormat: Text.PlainText
              text: root.match ? root.match.home.abbr : ""
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }

          Column {
            spacing: 1
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: root.match
                ? (root.match.state === "pre"
                   ? Model.hhmm(root.match.date)
                   : root.match.home.score + " × " + root.match.away.score)
                : ""
              color: root.match && root.match.state !== "pre" ? root.accentColor : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: {
                var m = root.match
                if (!m) return ""
                if (m.state === "pre") return "Hoje"
                if (m.state === "halftime") return "Intervalo"
                if (m.state === "post") return "Final"
                return Model.clockLabel(m) || "Ao vivo"
              }
              color: root.match && (root.match.state === "live" || root.match.state === "halftime")
                ? root.accentColor : root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.match && (root.match.state === "live" || root.match.state === "halftime")
            }
          }

          Column {
            spacing: Style.space(4)
            Crest {
              size: 28
              teamId: root.match ? root.match.away.id : ""
              abbr: root.match ? root.match.away.abbr : ""
              anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
              textFormat: Text.PlainText
              text: root.match ? root.match.away.abbr : ""
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }
      }

      PanelSectionHeader {
        text: root.todayMatches.length
          ? "Rodada de hoje · " + Model.roundLabel(root.todayMatches)
          : "Rodada de hoje"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Column {
        width: parent.width
        spacing: Style.space(2)

        Repeater {
          model: root.todayMatches

          Item {
            id: roundRow
            required property var modelData
            readonly property bool followed: String(modelData.id) === root.followedMatchId
            width: parent.width
            height: 24

            Rectangle {
              anchors.fill: parent
              radius: 5
              color: roundRow.followed
                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                : (roundMouse.containsMouse
                   ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
                   : "transparent")
            }

            MouseArea {
              id: roundMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              // Clicking a row jumps the picker to that matchup's team —
              // cheap and obvious from the highlight.
              onClicked: {
                if (String(modelData.home.id) !== root.teamId && String(modelData.away.id) !== root.teamId)
                  root.selectTeam(modelData.home.id, modelData.home.name)
              }
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(8)

              Crest {
                size: 14
                teamId: modelData.home.id
                abbr: modelData.home.abbr
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.home.abbr
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: roundRow.followed
                width: 30
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: root.roundCenterText(modelData)
                color: root.rowCenterColor(modelData)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: modelData.state === "live" || modelData.state === "halftime"
                horizontalAlignment: Text.AlignHCenter
                width: 54
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.away.abbr
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: roundRow.followed
                width: 30
                anchors.verticalCenter: parent.verticalCenter
              }

              Crest {
                size: 14
                teamId: modelData.away.id
                abbr: modelData.away.abbr
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.home.name + " × " + modelData.away.name
                  + (modelData.state === "post" ? "  ·" : "")
                color: roundRow.followed ? root.accentColor : root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }

      Text {
        visible: !root.todayMatches.length
        textFormat: Text.PlainText
        text: scoreboardProc.running
          ? "Buscando os jogos de hoje..." : "Sem jogos do Brasileirão hoje."
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ---- TABELA: standings with G4/Z4 zone dots and the followed row lit.
  Component {
    id: tabelaComponent

    Column {
      id: tabelaColumn
      width: parent.width
      spacing: Style.space(2)

      PanelSectionHeader {
        text: "Classificação · " + Model.leagueName(root.league)
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Grid {
        width: parent.width
        columns: 2
        rowSpacing: Style.space(4)
        visible: root.league === "bra.1"

        Repeater {
          model: [
            { label: "1–4 Libertadores", zone: "libertadores" },
            { label: "5 Pré-Libertadores", zone: "preLibertadores" },
            { label: "6–11 Sul-Americana", zone: "sulAmericana" },
            { label: "Últimos 4: rebaixamento", zone: "relegation" }
          ]

          Row {
            required property var modelData
            width: tabelaColumn.width / 2
            spacing: Style.space(4)
            Rectangle { width: 6; height: 6; radius: 3; color: root.zoneColors[parent.modelData.zone]; anchors.verticalCenter: parent.verticalCenter }
            Text {
              textFormat: Text.PlainText
              text: parent.modelData.label
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Item {
        width: parent.width
        height: 16

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Row {
            visible: root.league !== "bra.1"
            spacing: Style.space(4)
            Rectangle { width: 6; height: 6; radius: 3; color: root.urgentColor; anchors.verticalCenter: parent.verticalCenter }
            Text {
              textFormat: Text.PlainText
              text: "Rebaixamento"
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          text: "Pts  J  V  E  D  SG"
          color: root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(1)

        Repeater {
          model: root.standings

          Item {
            id: tableRow
            required property var modelData
            required property int index
            readonly property bool followed: String(modelData.id) === root.teamId
            readonly property string zone: Model.standingsZone(modelData.rank, root.standings.length, root.league)
            width: parent.width
            height: 22

            Rectangle {
              anchors.fill: parent
              radius: 4
              color: tableRow.followed
                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                : (tableMouse.containsMouse
                   ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
                   : "transparent")
            }

            MouseArea {
              id: tableMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectTeam(modelData.id, modelData.name)
            }

            Rectangle {
              width: 5
              height: 5
              radius: 2.5
              anchors.left: parent.left
              anchors.leftMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              color: root.zoneColors[tableRow.zone] || "transparent"
            }

            Text {
              textFormat: Text.PlainText
              text: String(tableRow.index + 1)
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              width: 14
              horizontalAlignment: Text.AlignRight
              anchors.left: parent.left
              anchors.leftMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
            }

            Crest {
              size: 13
              teamId: modelData.id
              abbr: modelData.abbr
              anchors.left: parent.left
              anchors.leftMargin: Style.space(34)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              textFormat: Text.PlainText
              text: modelData.name
              color: tableRow.followed ? root.accentColor : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: tableRow.followed
              elide: Text.ElideRight
              anchors.left: parent.left
              anchors.leftMargin: Style.space(54)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              textFormat: Text.PlainText
              text: modelData.points + "  " + modelData.played + "  "
                + modelData.wins + "  " + modelData.draws + "  "
                + modelData.losses + "  "
                + (modelData.gd > 0 ? "+" + modelData.gd : modelData.gd)
              color: tableRow.followed ? root.accentColor : root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      Text {
        visible: !root.standings.length
        textFormat: Text.PlainText
        text: standingsProc.running ? "Carregando a tabela..." : "A tabela chega com a próxima atualização."
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ---- AJUSTES: team picker with search + experience toggles.
  Component {
    id: ajustesComponent

    Column {
      id: ajustesColumn
      width: parent.width
      spacing: Style.space(10)

      PanelSectionHeader {
        text: "Seu time"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      // Current selection line, or a nudge when nobody is followed.
      Item {
        width: parent.width
        height: root.teamFollowed ? 24 : 0
        visible: root.teamFollowed

        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(7)

          Crest {
            size: 16
            teamId: root.teamId
            abbr: root.teamName.slice(0, 3).toUpperCase()
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            textFormat: Text.PlainText
            text: "Seguindo " + (root.teamName || "seu time")
            color: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Text {
          textFormat: Text.PlainText
          text: "✕"
          color: root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter

          MouseArea {
            id: clearTeamMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearTeam()
          }

          opacity: clearTeamMouse.containsMouse ? 1.0 : 0.8
        }
      }

      // Search field — filters the roster by name or abbreviation.
      Rectangle {
        width: parent.width
        height: 30
        radius: 15
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
        border.color: searchInput.activeFocus
          ? root.accentColor
          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
        border.width: 1

        Text {
          id: searchPlaceholder
          visible: searchInput.text === "" && !searchInput.activeFocus
          anchors.left: parent.left
          anchors.leftMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: "Buscar time..."
          color: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }

        TextInput {
          id: searchInput
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          verticalAlignment: TextInput.AlignVCenter
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          clip: true
          onTextChanged: root.searchText = text
          onActiveFocusChanged: root.searchFocused = activeFocus
          Keys.onEscapePressed: root.close()
          Component.onDestruction: root.searchFocused = false
        }
      }

      Flow {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: root.filteredStandings()

          Rectangle {
            id: pickerChip
            required property var modelData
            readonly property bool following: String(modelData.id) === root.teamId
            width: pickerRow.implicitWidth + Style.space(14)
            height: 25
            radius: 12.5
            color: pickerMouse.containsMouse
              ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
              : "transparent"
            border.color: pickerChip.following
              ? root.accentColor
              : (pickerMouse.containsMouse ? Qt.darker(root.foreground, 1.3) : "transparent")
            border.width: pickerChip.following ? 1.4 : 1

            MouseArea {
              id: pickerMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.selectTeam(modelData.id, modelData.name)
                root.searchText = ""
                searchInput.text = ""
              }
            }

            Row {
              id: pickerRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Crest {
                size: 13
                teamId: modelData.id
                abbr: modelData.abbr
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.name
                color: pickerChip.following ? root.accentColor : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: pickerChip.following
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }

      Text {
        visible: !root.filteredStandings().length
        textFormat: Text.PlainText
        text: root.standings.length
          ? "Nenhum time para \"" + root.searchText + "\""
          : (standingsProc.running ? "Carregando os times..." : "Times chegam com a próxima atualização.")
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      PanelSectionHeader {
        text: "Experiência"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      ToggleRow {
        label: "Notificações de gol e de jogo"
        checked: root.goalNotifications
        onToggled2: root.setSetting("goalNotifications", !root.goalNotifications)
      }

      ToggleRow {
        label: "Comemoração de gol na tela"
        checked: root.goalCelebration
        onToggled2: root.setSetting("goalCelebration", !root.goalCelebration)
      }

      ToggleRow {
        label: "Aviso discreto de gol rival"
        checked: root.rivalAlert
        onToggled2: root.setSetting("rivalAlert", !root.rivalAlert)
      }

      Row {
        spacing: Style.space(18)

        Text {
          textFormat: Text.PlainText
          text: "▶  Testar comemoração"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true

          MouseArea {
            id: testCelebrateMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
              root.testCelebrate("own")
            }
          }

          opacity: testCelebrateMouse.containsMouse ? 1.0 : 0.85
        }

        Text {
          textFormat: Text.PlainText
          text: "▶  Testar aviso rival"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true

          MouseArea {
            id: testRivalMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
              root.testCelebrate("rival")
            }
          }

          opacity: testRivalMouse.containsMouse ? 1.0 : 0.85
        }
      }

      Text {
        textFormat: Text.PlainText
        text: root.scoreboardError || root.standingsError
          ? "ESPN indisponível · mantendo os últimos dados válidos"
          : "Dados: API pública da ESPN · atualização automática"
        color: Qt.darker(root.foreground, 1.6)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ---- Bare toggle with a label; the whole row is the click target.
  component ToggleRow: Item {
    id: toggleRow
    property string label: ""
    property bool checked: false
    signal toggled2()

    implicitWidth: parent ? parent.width : 100
    implicitHeight: 26

    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(10)

      ToggleSwitch {
        checked: toggleRow.checked
        interactive: false // the row owns the click
        foreground: root.foreground
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: toggleRow.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: toggleMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: toggleRow.toggled2()
    }
  }

  // ---- Crest with an abbr fallback while the PNG lands. Remote covers are
  //      never requested — the local cache, once warm, is the only source.
  component Crest: Item {
    id: crest
    property string teamId: ""
    property string abbr: ""
    property real size: 14

    width: size
    height: size

    Image {
      id: crestImg
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
      asynchronous: true
      sourceSize.width: 120
      sourceSize.height: 120
      source: root.crestUris[crest.teamId] || ""
    }

    Text {
      anchors.fill: parent
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText
      text: crest.abbr
      visible: crestImg.source === ""
        || (crestImg.status !== Image.Ready && crestImg.status !== Image.Loading)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Math.max(8, Math.round(crest.size * 0.58))
      font.bold: true
    }
  }
}
