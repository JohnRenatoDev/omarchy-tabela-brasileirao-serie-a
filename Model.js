// Model.js — pure helpers for parsing the ESPN public soccer API and
// formatting PT-BR match labels. No QML imports: everything the UI layer
// needs arrives as arguments, and nothing here touches the shell.

// ESPN status.type.state is "pre" | "in" | "post"; halftime shows up as
// state "in" with type name STATUS_HALFTIME, which deserves its own label.
function stateOf(status) {
  var type = (status && status.type) || {}
  var state = String(type.state || "pre")
  if (String(type.name || "") === "STATUS_HALFTIME") return "halftime"
  if (state === "in") return "live"
  if (state === "post") return "post"
  return "pre"
}

function teamOf(competitor) {
  var t = competitor && competitor.team ? competitor.team : {}
  var name = String(t.shortDisplayName || t.displayName || t.location || t.name || "Futebol")
  // Scoreboard events carry a string `logo`; standings carry a `logos`
  // array — accept both shapes.
  var logo = typeof t.logo === "string" && t.logo
    ? String(t.logo)
    : (t.logos && t.logos.length ? String(t.logos[0].href || "") : "")
  return {
    id: teamId(t.id),
    abbr: String(t.abbreviation || name.slice(0, 3).toUpperCase()),
    name: name,
    logo: logo,
    // ESPN colors arrive as bare hex ("7E0202") — QML wants the "#".
    color: /^[0-9a-fA-F]{6}$/.test(t.color || "") ? "#" + t.color : "",
    alternateColor: /^[0-9a-fA-F]{6}$/.test(t.alternateColor || "") ? "#" + t.alternateColor : "",
    score: scoreToNumber(competitor && competitor.score)
  }
}

function standingsZone(rank, total, league) {
  if (!Number.isInteger(rank) || rank < 1 || rank > total) return ""
  if (total > 12 && rank > total - 4) return "relegation"
  if (league !== "bra.1") return ""
  if (rank <= 4) return "libertadores"
  if (rank === 5) return "preLibertadores"
  if (rank <= 11) return "sulAmericana"
  return ""
}

function teamId(value) {
  var id = String(value === undefined || value === null ? "" : value)
  return /^[1-9][0-9]{0,9}$/.test(id) ? id : ""
}

function notificationText(value) {
  return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function scoreToNumber(value) {
  if (value && typeof value === "object") value = value.value
  var n = parseInt(value, 10)
  return isFinite(n) && n >= 0 ? n : 0
}

function parseEvent(e) {
  if (!e || !e.competitions || !e.competitions.length) return null
  var comp = e.competitions[0]
  var homeSide = null
  var awaySide = null
  var competitors = comp.competitors || []
  for (var i = 0; i < Math.min(competitors.length, 16); i++) {
    if (!competitors[i]) continue
    if (String(competitors[i].homeAway) === "home") homeSide = competitors[i]
    else if (String(competitors[i].homeAway) === "away") awaySide = competitors[i]
  }
  if (!homeSide || !awaySide) return null
  return {
    id: String(e.id || ""),
    home: teamOf(homeSide),
    away: teamOf(awaySide),
    state: stateOf(e.status),
    clock: String((e.status && e.status.displayClock) || ""),
    date: String(e.date || "")
  }
}

function parseScoreboard(json) {
  if (!json || !Array.isArray(json.events)) throw new Error("Invalid scoreboard")
  var events = json.events
  var matches = []
  for (var i = 0; i < Math.min(events.length, 100); i++) {
    var match = parseEvent(events[i])
    if (match) matches.push(match)
  }
  return matches
}

// The followed team may genuinely play twice on a scorecard (doubleheaders
// are rare, but Post-season chaos exists), so pick one well: nothing beats
// a match in progress, an upcoming one wins over a finished one, and the
// soonest kickoff breaks ties.
function pickFollowed(matches, teamId) {
  if (!teamId) return null
  var best = null
  var bestRank = -1
  for (var i = 0; i < matches.length; i++) {
    var match = matches[i]
    if (match.home.id !== teamId && match.away.id !== teamId) continue
    var rank = match.state === "live" || match.state === "halftime" ? 3
      : match.state === "pre" ? 2 : 1
    if (rank > bestRank
        || (rank === bestRank && best && match.date < best.date)) {
      bestRank = rank
      best = match
    }
  }
  return best
}

// ---- Table (standings). Stats arrive as a records array whose members are
//      keyed by name: "points", "gamesPlayed", "wins", "ties", "losses",
//      "pointDifferential". Values are numbers; display values are strings.
function statValue(stats, name) {
  if (!Array.isArray(stats)) return 0
  for (var i = 0; i < stats.length; i++) {
    if (!stats[i]) continue
    if (String(stats[i].name) === name) {
      var v = stats[i].value
      if (typeof v === "number") return v
      var parsed = parseFloat(stats[i].displayValue)
      return isFinite(parsed) ? parsed : 0
    }
  }
  return 0
}

function parseStandings(json) {
  if (!json || !Array.isArray(json.children)) throw new Error("Invalid standings")
  var children = json.children
  if (!children.length) return []
  var standings = children[0] && children[0].standings ? children[0].standings : {}
  var entries = standings.entries || []
  if (!Array.isArray(standings.entries)) throw new Error("Invalid standings entries")
  var rows = []
  for (var i = 0; i < Math.min(entries.length, 100); i++) {
    var e = entries[i]
    if (!e || !e.team) continue
    var t = e.team
    var logo = t.logos && t.logos.length ? String(t.logos[0].href || "") : ""
    rows.push({
      id: teamId(t.id),
      abbr: String(t.abbreviation || ""),
      name: String(t.shortDisplayName || t.displayName || t.location || t.name || ""),
      logo: logo,
      rank: Math.round(statValue(e.stats, "rank")) || i + 1,
      points: Math.round(statValue(e.stats, "points")),
      played: Math.round(statValue(e.stats, "gamesPlayed")),
      wins: Math.round(statValue(e.stats, "wins")),
      draws: Math.round(statValue(e.stats, "ties")),
      losses: Math.round(statValue(e.stats, "losses")),
      gd: Math.round(statValue(e.stats, "pointDifferential"))
    })
  }
  rows.sort(function(a, b) {
    if (a.rank !== b.rank) return a.rank - b.rank
    if (a.points !== b.points) return b.points - a.points
    return b.gd - a.gd
  })
  return rows
}

// ---- Bar chip labels.

// "45'+2'" keeps its addition clock; only trailing quotes get trimmed.
function clockLabel(match) {
  if (!match || !match.clock) return ""
  return match.clock.replace(/'+$/, '') + "'"
}

function stateLabel(match) {
  if (!match) return ""
  if (match.state === "halftime") return "INT"
  if (match.state === "live") return clockLabel(match)
  if (match.state === "post") return "FIM"
  return hhmm(match.date)
}

function hhmm(iso) {
  if (!iso) return ""
  var d = new Date(iso)
  if (isNaN(d.getTime())) return ""
  var h = d.getHours()
  var m = d.getMinutes()
  return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
}

// Long line for the panel hero: "19:30 · FLA × FLU", "2 × 1 · 45'",
// "2 × 1 · Final" in the shapes other sections already use.
function matchLine(match) {
  if (!match) return ""
  var head = match.home.abbr + " × " + match.away.abbr
  if (match.state === "pre") return hhmm(match.date) + " · " + head
  var s = match.home.score + " × " + match.away.score
  if (match.state === "post") return s + " · Final"
  if (match.state === "halftime") return s + " · Intervalo"
  return s + " · " + (clockLabel(match) || "Ao vivo")
}

// PT-BR league naming for headers and the hero line.
function leagueName(code) {
  var map = { "bra.1": "Série A", "bra.2": "Série B", "bra.3": "Série C" }
  return map[code] || String(code).toUpperCase()
}

// PT-BR days/rounds phrasing for section headers.
function roundLabel(matches) {
  if (!matches.length) return "Sem jogos hoje"
  var live = 0, upcoming = 0, done = 0
  for (var i = 0; i < matches.length; i++) {
    var st = matches[i].state
    if (st === "live" || st === "halftime") live++
    else if (st === "pre") upcoming++
    else done++
  }
  if (live) return live === 1 ? "1 jogo ao vivo" : live + " jogos ao vivo"
  if (upcoming) return "começa às " + hhmm(earliestKickoff(matches))
  return "rodada concluída"
}

function earliestKickoff(matches) {
  var best = ""
  for (var i = 0; i < matches.length; i++) {
    if (matches[i].state !== "pre") continue
    if (!best || matches[i].date < best) best = matches[i].date
  }
  return best
}
