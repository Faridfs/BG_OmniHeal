local _, ns = ...
local PremadeScanner = ns:NewModule("PremadeScanner")

local guildCounts = {} -- [guildName] = { players = { [key] = true }, count = N }
local playerGuild = {} -- [key] = guildName
local visibleUnits = {}
local scanTicker
local SCAN_INTERVAL = 2

local function SetPremade(rec, value)
  if not rec or rec.team ~= "enemy" then return end
  value = value == true
  if rec.isPremade == value then return end
  rec.isPremade = value
  if rec.row then ns.Frames:UpdateDynamic(rec) end
end

function PremadeScanner:IsPremade(rec)
  if not rec or not rec.key then return false end
  local guild = playerGuild[rec.key]
  local data = guild and guildCounts[guild]
  return data ~= nil and data.count >= 3
end

local function UpdateRecord(rec)
  if rec and rec.team == "enemy" then
    SetPremade(rec, PremadeScanner:IsPremade(rec))
  end
end

local function UpdateGuild(guild)
  for _, rec in pairs(ns.Roster.byKey) do
    if rec.team == "enemy" and playerGuild[rec.key] == guild then
      UpdateRecord(rec)
    end
  end
end

local function UpdateKnownRecords()
  if ns.state ~= "bg" then return end
  for _, rec in pairs(ns.Roster.byKey) do
    UpdateRecord(rec)
  end
end

local function RemoveGuildMember(key, guild)
  local data = guildCounts[guild]
  if not data or not data.players[key] then return end

  data.players[key] = nil
  data.count = math.max(data.count - 1, 0)
  UpdateGuild(guild)
end

local function RememberGuildMember(key, guild)
  local previous = playerGuild[key]
  if previous ~= guild then
    if previous then
      playerGuild[key] = nil
      RemoveGuildMember(key, previous)
    end

    local data = guildCounts[guild]
    if not data then
      data = { players = {}, count = 0 }
      guildCounts[guild] = data
    end

    if not data.players[key] then
      data.players[key] = true
      data.count = data.count + 1
      if data.count == 3 then UpdateGuild(guild) end
    end
    playerGuild[key] = guild
  end

  UpdateRecord(ns.Roster.byKey[key])
end

local function ScanNameplate(unit)
  if ns.state ~= "bg" or not ns.db.premadeScannerEnabled then return end

  local ok, isPlayer = pcall(UnitIsPlayer, unit)
  if not ok or ns.Plain(isPlayer) ~= true then return end

  local hostileOK, hostile = pcall(ns.IsHostile, unit)
  if not hostileOK or hostile ~= true then return end

  local nameOK, name, realm = pcall(UnitName, unit)
  if not nameOK then return end
  name, realm = ns.Plain(name), ns.Plain(realm)
  if not name or name == "" then return end

  local key = ns.FullName(name, realm)
  if not key then return end

  local guildOK, guild = pcall(GetGuildInfo, unit)
  if not guildOK then return end
  guild = ns.Plain(guild)
  if type(guild) ~= "string" or guild == "" then return end

  RememberGuildMember(key, guild)
end

local function RefreshVisibleUnits()
  for i = 1, 40 do
    local unit = "nameplate" .. i
    local ok, exists = pcall(UnitExists, unit)
    if ok and ns.Plain(exists) == true then
      visibleUnits[unit] = true
    else
      visibleUnits[unit] = nil
    end
  end
end

local function ScanVisibleUnits()
  if ns.state ~= "bg" or not ns.db.premadeScannerEnabled then return end

  RefreshVisibleUnits()
  for unit in pairs(visibleUnits) do
    ScanNameplate(unit)
  end
  UpdateKnownRecords()
end

local function OnNameplateAdded(_, unit)
  if not unit then return end
  visibleUnits[unit] = true
  ScanNameplate(unit)
end

local function OnNameplateRemoved(_, unit)
  if unit then visibleUnits[unit] = nil end
end

function PremadeScanner:OnActivate(state)
  if state ~= "bg" then return end

  wipe(guildCounts)
  wipe(playerGuild)
  wipe(visibleUnits)
  for _, rec in pairs(ns.Roster.byKey) do
    SetPremade(rec, false)
  end

  ScanVisibleUnits()
  scanTicker = C_Timer.NewTicker(SCAN_INTERVAL, ScanVisibleUnits)
end

function PremadeScanner:OnDeactivate()
  if scanTicker then
    scanTicker:Cancel()
    scanTicker = nil
  end
  for _, rec in pairs(ns.Roster.byKey) do
    SetPremade(rec, false)
  end
  wipe(guildCounts)
  wipe(playerGuild)
  wipe(visibleUnits)
end

ns:OnActive("NAME_PLATE_UNIT_ADDED", OnNameplateAdded)
ns:OnActive("NAME_PLATE_UNIT_REMOVED", OnNameplateRemoved)
ns:OnActive("UPDATE_BATTLEFIELD_SCORE", UpdateKnownRecords)