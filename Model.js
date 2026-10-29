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

// ---- Competitions offered by the picker. `format` drives the Tabela tab:
//      "league" is one table, "groups" one table per group, "knockout" has
//      no table at all (ESPN serves an empty standings document for it).
var COMPETITIONS = [
  { code: "bra.1", name: "Série A", format: "league" },
  { code: "bra.2", name: "Série B", format: "league" },
  { code: "bra.copa_do_brazil", name: "Copa do Brasil", format: "knockout" },
  { code: "conmebol.libertadores", name: "Libertadores", format: "groups" },
  { code: "conmebol.sudamericana", name: "Sul-Americana", format: "groups" }
]

function competitions() {
  return COMPETITIONS
}

function competitionOf(code) {
  for (var i = 0; i < COMPETITIONS.length; i++)
    if (COMPETITIONS[i].code === code) return COMPETITIONS[i]
  return null
}

// Catalog codes, plus the bare ESPN codes ("eng.1") that shell.json
// accepted before the picker existed; anything else falls back to bra.1.
function leagueCode(value) {
  var code = String(value === undefined || value === null ? "" : value)
  if (competitionOf(code) || /^[a-z]{2,8}\.[1-9][0-9]?$/.test(code)) return code
  return "bra.1"
}

function leagueFormat(code) {
  var competition = competitionOf(code)
  return competition ? competition.format : "league"
}

// Zones follow the 2026 rules. CONMEBOL club manuals (June 2026):
// Libertadores 1st–2nd reach the round of 16 and 3rd drops into the
// Sudamericana round-of-16 play-off, where Sudamericana runners-up wait;
// Sudamericana group winners go straight through. CBF: Série B 1st–2nd
// promoted, 3rd–6th promotion play-off, bottom four relegated.
function standingsZone(rank, total, league) {
  if (!Number.isInteger(rank) || rank < 1 || rank > total) return ""
  if (league === "conmebol.libertadores")
    return rank <= 2 ? "advance" : (rank === 3 ? "sulAmericana" : "")
  if (league === "conmebol.sudamericana")
    return rank === 1 ? "advance" : (rank === 2 ? "playoff" : "")
  if (total > 12 && rank > total - 4) return "relegation"
  if (league === "bra.2") return rank <= 2 ? "advance" : (rank <= 6 ? "playoff" : "")
  if (league !== "bra.1") return ""
  if (rank <= 4) return "libertadores"
  if (rank === 5) return "preLibertadores"
  if (rank <= 11) return "sulAmericana"
  return ""
}

// Legend lines for the Tabela tab; empty when the competition has no
// zones of its own (the panel then shows the generic relegation note).
function zoneLegend(league) {
  if (league === "bra.1") return [
    { label: "1–4 Libertadores", zone: "libertadores" },
    { label: "5 Pré-Libertadores", zone: "preLibertadores" },
    { label: "6–11 Sul-Americana", zone: "sulAmericana" },
    { label: "Últimos 4: rebaixamento", zone: "relegation" }
  ]
  if (league === "bra.2") return [
    { label: "1–2 acesso", zone: "advance" },
    { label: "3–6 playoff de acesso", zone: "playoff" },
    { label: "Últimos 4: rebaixamento", zone: "relegation" }
  ]
  if (league === "conmebol.libertadores") return [
    { label: "1–2 oitavas de final", zone: "advance" },
    { label: "3º playoff da Sul-Americana", zone: "sulAmericana" }
  ]
  if (league === "conmebol.sudamericana") return [
    { label: "1º oitavas de final", zone: "advance" },
    { label: "2º playoff de oitavas", zone: "playoff" }
  ]
  return []
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
    clock: clockText(e.status && e.status.displayClock),
    date: String(e.date || "")
  }
}

// Each match carries the competition it came from, so a merged slate
// (followed club across cups) can still tell them apart.
function parseScoreboard(json, league) {
  if (!json || !Array.isArray(json.events)) throw new Error("Invalid scoreboard")
  var events = json.events
  var matches = []
  for (var i = 0; i < Math.min(events.length, 100); i++) {
    var match = parseEvent(events[i])
    if (!match) continue
    match.league = String(league || "")
    matches.push(match)
  }
  return matches
}

// ---- Roster (site /teams). Cups have no table, so the team picker and
//      the multi-competition follow both lean on this list.
function parseTeams(json) {
  var sports = json && json.sports
  var leagues = Array.isArray(sports) && sports[0] ? sports[0].leagues : null
  var teams = Array.isArray(leagues) && leagues[0] ? leagues[0].teams : null
  if (!Array.isArray(teams)) throw new Error("Invalid teams")
  var rows = []
  var seen = {}
  for (var i = 0; i < Math.min(teams.length, 300); i++) {
    var t = teams[i] && teams[i].team
    if (!t) continue
    var id = teamId(t.id)
    if (!id || seen[id]) continue
    seen[id] = true
    rows.push({
      id: id,
      abbr: String(t.abbreviation || ""),
      name: String(t.shortDisplayName || t.displayName || t.location || t.name || "").trim()
    })
  }
  rows.sort(function(a, b) { return a.name.localeCompare(b.name) })
  return rows
}

// Catalog competitions whose roster lists the club. ESPN shares team IDs
// across leagues, so membership is a plain ID lookup.
function teamLeagues(rosters, followedId) {
  var out = []
  if (!followedId || !rosters) return out
  for (var i = 0; i < COMPETITIONS.length; i++) {
    var roster = rosters[COMPETITIONS[i].code]
    if (!Array.isArray(roster)) continue
    for (var j = 0; j < roster.length; j++) {
      if (roster[j].id === followedId) {
        out.push(COMPETITIONS[i].code)
        break
      }
    }
  }
  return out
}

// Competitions to poll: the one on screen plus every one the club plays.
function followedLeagues(selected, rosters, followedId) {
  var out = [selected]
  var own = teamLeagues(rosters, followedId)
  for (var i = 0; i < own.length; i++) if (own[i] !== selected) out.push(own[i])
  return out
}

// Case- and accent-folded text, so "gremio" finds Grêmio.
function searchKey(value) {
  var s = String(value || "").toLowerCase()
  if (typeof s.normalize === "function") s = s.normalize("NFD").replace(/[̀-ͯ]/g, "")
  return s.trim()
}

// Team picker rows. An empty query browses the selected competition (its
// roster, or the table while the roster is pending); a typed query searches
// every catalog roster, so any club can be followed from any competition.
// Selected-competition matches come first; `total` counts before the cap.
function pickerTeams(rosters, selected, fallback, query, limit) {
  var q = searchKey(query)
  var teams = []
  var seen = {}
  var total = 0
  function add(list) {
    if (!Array.isArray(list)) return
    for (var i = 0; i < list.length; i++) {
      var row = list[i]
      var id = row && teamId(row.id)
      if (!id || seen[id]) continue
      if (q && searchKey(row.name).indexOf(q) < 0 && searchKey(row.abbr).indexOf(q) < 0) continue
      seen[id] = true
      total++
      if (teams.length < limit) teams.push({ id: id, abbr: String(row.abbr || ""), name: String(row.name || "") })
    }
  }
  var own = rosters && rosters[selected]
  add(Array.isArray(own) && own.length ? own : fallback)
  if (q) for (var c = 0; c < COMPETITIONS.length; c++) add(rosters && rosters[COMPETITIONS[c].code])
  return { teams: teams, total: total }
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

// Group-stage cups arrive as one child per group ("Group A"…); leagues as
// a single child. Rows stay flat, tagged with their group, its size (zones
// count within the group) and whether they open it (the panel's subheader).
// Rank is ESPN's own: CONMEBOL breaks ties head-to-head before goal
// difference, so points/GD only order rows that share a rank.
function parseStandings(json) {
  if (!json || !Array.isArray(json.children)) throw new Error("Invalid standings")
  var children = json.children
  var grouped = children.length > 1
  var rows = []
  for (var g = 0; g < Math.min(children.length, 16); g++) {
    var standings = children[g] && children[g].standings ? children[g].standings : {}
    var entries = standings.entries || []
    if (!Array.isArray(standings.entries)) throw new Error("Invalid standings entries")
    var group = grouped ? groupLabel(children[g].name, g) : ""
    var block = []
    for (var i = 0; i < Math.min(entries.length, 100); i++) {
      var e = entries[i]
      if (!e || !e.team) continue
      var t = e.team
      var logo = t.logos && t.logos.length ? String(t.logos[0].href || "") : ""
      block.push({
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
        gd: Math.round(statValue(e.stats, "pointDifferential")),
        group: group
      })
    }
    block.sort(function(a, b) {
      if (a.rank !== b.rank) return a.rank - b.rank
      if (a.points !== b.points) return b.points - a.points
      return b.gd - a.gd
    })
    for (var k = 0; k < block.length; k++) {
      block[k].groupSize = block.length
      block[k].groupStart = grouped && k === 0
      rows.push(block[k])
    }
  }
  return rows
}

function groupLabel(name, index) {
  var m = /^Group ([A-Z])$/.exec(String(name || ""))
  return "Grupo " + (m ? m[1] : String.fromCharCode(65 + index))
}

// ---- Bar chip labels.

// "45'+2'" keeps its addition clock; only trailing quotes get trimmed.
function clockText(value) {
  if (typeof value !== "string" && typeof value !== "number") return ""
  var text = String(value || "")
  return text.length <= 32 ? text : ""
}

function clockLabel(match) {
  var clock = clockText(match && match.clock)
  if (!clock) return ""
  var end = clock.length
  while (end > 0 && clock.charAt(end - 1) === "'") end--
  return clock.slice(0, end) + "'"
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
  var competition = competitionOf(code)
  if (competition) return competition.name
  return code === "bra.3" ? "Série C" : String(code).toUpperCase()
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
