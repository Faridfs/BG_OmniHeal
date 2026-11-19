local _, ns = ...
local Roster = ns:NewModule("Roster")

Roster.enemies = {}
Roster.allies = {}
Roster.byKey = {} -- "Name-Realm" -> record, both teams
Roster.allyByUnit = {} -- "raid3" -> record
Roster.byShortName = {} -- "Bob" -> record, or false when more than one player has that name
Roster.specInfo = {} -- [classToken][localized spec name] = { icon, role }

local byKey, allyByUnit, specInfo = Roster.byKey, Roster.allyByUnit, Roster.specInfo
local enemyStamp, allyStamp = 0, 0
local lastOrder = { enemy = {}, ally = {} } -- record order last handed to the frames
local scoreTicker
local myRealm

-- name -> realm -> "Name-Realm", so hot paths don't rebuild the same strings
local keyCache = {}

function ns.FullName(name, realm)
  name = ns.Plain(name)
  realm = ns.Plain(realm)
  if not name then return nil end
  if not realm or realm == "" then
    if name:find("-", 1, true) then
      -- Realm suffixes in chat can include spaces. Character names cannot.
      return name:find(" ", 1, true) and (name:gsub(" ", "")) or name
    end
    myRealm = myRealm or GetNormalizedRealmName() or ""
    realm = myRealm
  elseif realm:find(" ", 1, true) then
    -- UnitName can give "Area 52"; the scoreboard and our keys use "Area52"
    realm = realm:gsub(" ", "")
  end
  local byRealm = keyCache[name]
  if not byRealm then
    byRealm = {}
    keyCache[name] = byRealm
  end
  local key = byRealm[realm]
  if not key then
    key = name .. "-" .. realm
    byRealm[realm] = key
  end
  return key
end

-- Chat and cast APIs may omit the realm even when the target is from another realm.
function Roster:ResolveName(name)
  if name:find("-", 1, true) then return byKey[ns.FullName(name)] end
  return self.byShortName[name] or nil
end

-- nil when the unit doesn't exist or its identity is secret. UnitName (not UnitFullName)
-- is what stays readable for enemy players in a match; "Unknown" means not loaded yet.
function ns.UnitKey(unit)
  local name, realm = UnitName(unit)
  if ns.IsSecret(name) or ns.IsSecret(realm) or not name or name == "" or name == UNKNOWNOBJECT then
    return nil
  end
  return ns.FullName(name, realm)
end

-- Hostile in a battleground means "not friendly"; UnitIsFriend stays readable when the
-- attackable / enemy checks don't
function ns.IsHostile(unit)
  local friend = ns.Plain(UnitIsFriend("player", unit))
  if friend ~= nil then
    return friend == false
  end
  return ns.Plain(UnitCanAttack("player", unit)) == true
end

function Roster:EnsureSpecInfo()
  if next(specInfo) then
    return
  end
  local SI = C_SpecializationInfo
  local getNum = (SI and SI.GetNumSpecializationsForClassID) or GetNumSpecializationsForClassID
  local getInfo = (SI and SI.GetSpecializationInfoForClassID) or GetSpecializationInfoForClassID
  if not getNum or not getInfo then
    return
  end
  for classID = 1, GetNumClasses() do
    local _, classToken = GetClassInfo(classID)
    if classToken then
      local t = {}
      specInfo[classToken] = t
      for i = 1, getNum(classID) or 0 do
        local _, name, _, icon, role = getInfo(classID, i)
        if name then
          t[name] = { icon = icon, role = role }
        end
      end
    end
  end
end

local RefreshRole

local function ApplySpec(rec, spec)
  local classSpecs = rec.class and specInfo[rec.class]
  local si = spec and classSpecs and classSpecs[spec]
  if si then
    if rec.specIcon ~= si.icon then
      rec.specIcon = si.icon
      rec.dirty = true
    end
    if rec.specRole ~= si.role then
      rec.specRole = si.role
      rec.dirty = true
    end
    RefreshRole(rec)
  end
end

local function NormalizeRole(role)
  role = ns.Plain(role)
  if role == "HEALER" or role == "TANK" or role == "DAMAGER" then return role end
  if role == "DAMAGE" then return "DAMAGER" end
  if type(role) == "number" then
    local lfgRole = Enum and Enum.LFGRole
    if lfgRole then
      if role == lfgRole.Tank then return "TANK" end
      if role == lfgRole.Healer then return "HEALER" end
      if role == lfgRole.Damage then return "DAMAGER" end
    else
      if role == 0 then return "TANK" end
      if role == 1 then return "HEALER" end
      if role == 2 then return "DAMAGER" end
    end
  end
end

-- PvPScoreInfo.roleAssigned uses role flags. Numeric group roles use Enum.LFGRole.
local SCORE_ROLES = { [2] = "TANK", [4] = "HEALER", [8] = "DAMAGER" }

RefreshRole = function(rec)
  local role = rec.groupRole or rec.matchRole or rec.specRole or rec.scoreRole
  if rec.role ~= role then
    rec.role = role
    rec.dirty = true
  end
end

local function RememberScoreRole(key, info)
  local value = ns.Plain(info.roleAssigned)
  local role
  if type(value) == "number" then role = SCORE_ROLES[value]
  else role = NormalizeRole(value) end
  if not role then return nil end
  ns.global.playerRoles[key] = { role = role, t = time(), fromPvPFlags = true }
  return role
end

local function SavedScoreRole(key)
  local saved = ns.global.playerRoles[key]
  -- Earlier versions cached numeric scoreboard roles using the group-role encoding.
  return type(saved) == "table" and saved.fromPvPFlags and NormalizeRole(saved.role) or nil
end

-- The live scoreboard spec when it's readable (saving it for next time), else the saved one
local function SpecFor(key, info)
  local spec = ns.Plain(info.talentSpec)
  local saved = ns.global.specs
  local e = saved[key]
  if type(spec) == "string" and spec ~= "" then
    local now = time()
    if not e then
      saved[key] = { s = spec, t = now }
    elseif e.s ~= spec or now - e.t > 3600 then
      e.s, e.t = spec, now
    end
    return spec
  end
  return e and e.s
end

-- Sets a field and marks the row for a redraw only when the value really changed
local function SetField(rec, field, value)
  if rec[field] ~= value then
    rec[field] = value
    rec.dirty = true
  end
end

local function GetRecord(key, team, stamp)
  local rec = byKey[key]
  -- Changing sides (seen as an enemy, then joined our group): start clean, so no enemy
  -- nameplate, health or range state carries over
  if rec and rec.team ~= team then
    rec = nil
  end
  if not rec then
    rec = { key = key, lastSeen = 0, targeters = {}, dirty = true }
    byKey[key] = rec
  end
  rec.team = team
  rec.stamp = stamp
  return rec
end

-- Role order for each "sort by" choice
local ROLE_ORDERS = {
  healer = { HEALER = 1, TANK = 2, DAMAGER = 3 },
  tank = { TANK = 1, HEALER = 2, DAMAGER = 3 },
  damage = { DAMAGER = 1, HEALER = 2, TANK = 3 },
}

local function Compare(team, a, b)
  local by = ns.db[team].sortBy
  local order = ROLE_ORDERS[by]
  if order then
    local ra, rb = order[a.role] or 3, order[b.role] or 3
    if ra ~= rb then
      return ra < rb
    end
  end
  if by ~= "name" and a.class ~= b.class then
    return (a.class or "") < (b.class or "")
  end
  return a.key < b.key
end

local sorters = {
  enemy = function(a, b) return Compare("enemy", a, b) end,
  ally = function(a, b) return Compare("ally", a, b) end,
}

-- A change of unit token also requires rebinding, even if the sorted records are identical.
local function Publish(team, list, force)
  local prev = lastOrder[team]
  local same = not force and #prev == #list
  if same then
    for i = 1, #list do
      if prev[i] ~= list[i] then
        same = false
        break
      end
    end
  end
  if same then
    for i = 1, #list do
      local rec = list[i]
      if rec.dirty then
        rec.dirty = false
        ns.Frames:UpdateStatic(rec)
      end
    end
    return false
  end
  wipe(prev)
  for i = 1, #list do
    prev[i] = list[i]
    list[i].dirty = false
  end
  ns.Frames:SetRecords(team, list)
  return true
end

-- Drops records missing from the latest scan and rebuilds the sorted list
local function Commit(team, stamp, list, needsLayout)
  wipe(list)
  for key, rec in pairs(byKey) do
    if rec.team == team then
      if rec.stamp == stamp then
        list[#list + 1] = rec
      else
        byKey[key] = nil
      end
    end
  end
  table.sort(list, sorters[team])
  -- Short names for lookups that only get a bare name (who a cast is aimed at)
  local short = Roster.byShortName
  wipe(short)
  for _, rec in pairs(byKey) do
    local name = rec.name
    if name then
      short[name] = short[name] == nil and rec or false
    end
  end
  return Publish(team, list, needsLayout)
end

-- Our team number for this match (0 Horde, 1 Alliance), read from the scoreboard rows of
-- people in our group. GetBattlefieldArenaFaction can be hidden or wrong (cross-faction,
-- mercenary), so it's only a fallback until two group members agree.
local rows, rowNames, rowFactions = {}, {}, {}
local function FindMyTeam(count)
  local votes = { [0] = 0, [1] = 0 }
  local me = ns.UnitKey("player")
  for i = 1, count do
    local key, faction = rowNames[i], rowFactions[i]
    if key and votes[faction] then
      local rec = byKey[key]
      if key == me or (rec and rec.team == "ally" and rec.unit) then
        votes[faction] = votes[faction] + 1
      end
    end
  end
  if votes[0] ~= votes[1] then
    local team = votes[0] > votes[1] and 0 or 1
    if votes[team] >= 2 and votes[1 - team] == 0 then
      Roster.myTeam = team
    end
    return team
  end
  return ns.Plain(GetBattlefieldArenaFaction())
end

function Roster:ScanEnemies()
  if ns.state ~= "bg" then
    return
  end
  local count = GetNumBattlefieldScores()
  if count == 0 then
    return
  end
  for i = 1, count do
    local info = ns.ScoreInfo(i)
    local name = info and ns.Plain(info.name)
    rows[i] = info or false
    rowNames[i] = name and ns.FullName(name)
    rowFactions[i] = info and ns.Plain(info.faction)
  end
  local myTeam = self.myTeam or FindMyTeam(count)
  if myTeam ~= 0 and myTeam ~= 1 then
    return
  end
  self.team = myTeam -- what the headers show, locked or not
  enemyStamp = enemyStamp + 1
  local alliesChanged, allyRolesChanged, enemiesSeen = false, false, 0
  for i = 1, count do
    local info = rows[i]
    local name = info and ns.Plain(info.name)
    local faction = rowFactions[i]
    if name and faction then
      local key = ns.FullName(name)
      local matchRole = RememberScoreRole(key, info)
      local scoreRole = matchRole or SavedScoreRole(key)
      local known = byKey[key]
      -- Someone in our group is never an enemy, whatever a wrong team guess says
      if faction ~= myTeam and not (known and known.team == "ally" and known.unit) then
        enemiesSeen = enemiesSeen + 1
        local rec = GetRecord(key, "enemy", enemyStamp)
        if rec.targetName ~= name then
          rec.targetName = name
          rec.fullName = name
          rec.name = Ambiguate(name, "short")
          rec.dirty = true
        end
        SetField(rec, "class", ns.Plain(info.classToken))
        -- Kept for matching units whose names the game hides during a match
        rec.raceName = ns.Plain(info.raceName)
        rec.honor = ns.Plain(info.honorLevel)
        if matchRole then SetField(rec, "matchRole", matchRole) end
        if scoreRole then SetField(rec, "scoreRole", scoreRole); RefreshRole(rec) end
        ApplySpec(rec, SpecFor(key, info))
      else
        -- The scoreboard is the easiest place to learn ally specs (saved even for
        -- teammates outside our group, for when we next meet them)
        local spec = SpecFor(key, info)
        local rec = byKey[key]
        if rec and rec.team == "ally" then
          local oldRole = rec.role
          if matchRole then SetField(rec, "matchRole", matchRole) end
          if scoreRole then SetField(rec, "scoreRole", scoreRole) end
          RefreshRole(rec)
          ApplySpec(rec, spec)
          alliesChanged = alliesChanged or rec.dirty
          allyRolesChanged = allyRolesChanged or oldRole ~= rec.role
        end
      end
    end
  end
  -- With the scoreboard filtered to your own faction no enemies come back; keep the list
  if enemiesSeen > 0 then
    Commit("enemy", enemyStamp, self.enemies)
  end
  ns.Frames:UpdateHeaders()
  if alliesChanged then
    -- A new role can change the ally sort order
    table.sort(self.allies, sorters.ally)
    Publish("ally", self.allies, allyRolesChanged)
    if allyRolesChanged and InCombatLockdown() then ns.Live:SyncAllies() end
  end
end

function Roster:ScanAllies()
  if ns.state ~= "bg" then
    return
  end
  allyStamp = allyStamp + 1
  wipe(allyByUnit)
  local needsLayout = false
  local n = GetNumGroupMembers()
  local raid = IsInRaid()
  for i = 1, math.max(n, 1) do
    local unit = raid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
    local name, realm = UnitName(unit)
    local key
    if not ns.IsSecret(name) and not ns.IsSecret(realm) and name and name ~= "" and name ~= UNKNOWNOBJECT then
      key = ns.FullName(name, realm)
    end
    local isPlayer = ns.Plain(UnitIsUnit(unit, "player")) == true
    if key and (ns.db.showSelf or not isPlayer) then
      local rec = GetRecord(key, "ally", allyStamp)
      local oldRole = rec.role
      if rec.unit ~= unit then
        needsLayout = true
        rec.unit = unit
        rec.targetUnit = unit .. "target"
      end
      rec.isPlayer = isPlayer
      SetField(rec, "name", name)
      SetField(rec, "fullName", (realm and realm ~= "" and not isPlayer) and rec.key or name)
      local _, class = UnitClass(unit)
      SetField(rec, "class", ns.Plain(class))
      local role = UnitGroupRolesAssigned and NormalizeRole(UnitGroupRolesAssigned(unit))
      SetField(rec, "groupRole", role)
      local scoreRole = SavedScoreRole(rec.key)
      if scoreRole then SetField(rec, "scoreRole", scoreRole) end
      RefreshRole(rec)
      if rec.role ~= oldRole then needsLayout = true end
      allyByUnit[unit] = rec
    end
  end
  local changed = Commit("ally", allyStamp, self.allies, needsLayout)
  self.slotsStale = false
  -- Outside combat the layout synchronizes unit events. In combat, update the
  -- existing rows and watchers now, while the secure layout waits for combat to end.
  if changed and InCombatLockdown() then
    ns.Frames:RebindAllies()
    ns.Live:SyncAllies()
  end
end

-- Re-applies sort order and the include-myself option after a settings change
function Roster:Resort()
  if ns.state == "bg" then
    self:ScanAllies()
  end
  for team, list in pairs({ enemy = self.enemies, ally = self.allies }) do
    table.sort(list, sorters[team])
    Publish(team, list, true)
  end
end

function Roster:Reset()
  wipe(byKey)
  wipe(allyByUnit)
  wipe(Roster.byShortName)
  wipe(self.enemies)
  wipe(self.allies)
  wipe(lastOrder.enemy)
  wipe(lastOrder.ally)
  wipe(keyCache)
  wipe(rows)
  wipe(rowNames)
  wipe(rowFactions)
  self.myTeam, self.team = nil, nil
  myRealm = nil
  ns.Frames:SetRecords("enemy", self.enemies)
  ns.Frames:SetRecords("ally", self.allies)
end

-- Scoreboard events can fire in bursts while the scoreboard is open.
local scanEnemies = ns.Throttled(1, function() ns.Safe("enemy scan", Roster.ScanEnemies, Roster) end)

function Roster:OnActivate(state)
  self:EnsureSpecInfo()
  if state ~= "bg" then
    return
  end
  myRealm = GetNormalizedRealmName()
  self:ScanAllies()
  RequestBattlefieldScoreData()
  -- Scoreboard data only refreshes on request
  -- 12.1 timers refuse the game's own functions as callbacks; wrap it
  scoreTicker = C_Timer.NewTicker(5, function()
    RequestBattlefieldScoreData()
  end)
end

function Roster:OnDeactivate()
  if scoreTicker then
    scoreTicker:Cancel()
    scoreTicker = nil
  end
  self:Reset()
end

-- A loading screen can be a new match without leaving battleground state; work the team out again
ns:On("PLAYER_ENTERING_WORLD", function()
  Roster.myTeam, Roster.team = nil, nil
end)

ns:OnActive("UPDATE_BATTLEFIELD_SCORE", scanEnemies)
-- Specs are readable again once the match ends; ask for the scoreboard so they get saved
ns:OnActive("PVP_MATCH_COMPLETE", function()
  RequestBattlefieldScoreData()
end)
ns:OnActive("GROUP_ROSTER_UPDATE", function()
  -- Reconcile each roster event immediately. A secure button already targets the new
  -- occupant of its raid slot, so delaying its label can send a heal to the wrong player.
  if ns.state == "bg" then
    Roster.slotsStale = true
    Roster:ScanAllies()
  end
end)
