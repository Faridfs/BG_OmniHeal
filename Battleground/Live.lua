local _, ns = ...
local Live = ns:NewModule("Live")
local Roster = ns.Roster
local Frames = ns.Frames

local GetTime = GetTime
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax

local TICK = 0.25
local RANGE_EVERY = 0.5
local SEEN_GRACE = 2
local ENEMY_DEAD_MARKER_TTL = 35
local MANA = 0

local plateKey = {}
local plates = {}
local plateTarget = setmetatable({}, { __index = function(t, unit)
  local v = unit .. "target"
  t[unit] = v
  return v
end })
local cached = {}
local targetKey
local ticker
local bothTeams = { Roster.allies, Roster.enemies }
local stats = { health = 0, power = 0, auras = 0, ticks = 0, since = 0 }

local HARM_SPELLS = {
  DEATHKNIGHT = 47541, DEMONHUNTER = 185123, DRUID = 8921, EVOKER = 361469, HUNTER = 185358,
  MAGE = 116, MONK = 117952, PALADIN = 20271, PRIEST = 585, ROGUE = 2094, SHAMAN = 188196,
  WARLOCK = 686, WARRIOR = 57755,
}
local RANGE_ITEM = 140786
local harmSpell
local function SpellInRange(spell, unit)
  if C_Spell and C_Spell.IsSpellInRange then
    return C_Spell.IsSpellInRange(spell, unit)
  end
  local name = GetSpellInfo and GetSpellInfo(spell)
  if not name or not IsSpellInRange then
    return nil
  end
  local r = IsSpellInRange(name, unit)
  if r == 1 then
    return true
  elseif r == 0 then
    return false
  end
end
local function ItemInRange(item, unit)
  local f = (C_Item and C_Item.IsItemInRange) or IsItemInRange
  return f(item, unit)
end

local function EnemyInRange(unit)
  if ns.Plain(UnitIsVisible(unit)) == false then
    return false
  end
  local hidden, sawHidden, sawNo
  for i = 1, 3 do
    local ok, v
    if i == 1 and harmSpell and SpellInRange then
      ok, v = pcall(SpellInRange, harmSpell, unit)
    elseif i == 2 and ItemInRange then
      ok, v = pcall(ItemInRange, RANGE_ITEM, unit)
    elseif i == 3 and not InCombatLockdown() and CheckInteractDistance then
      ok, v = pcall(CheckInteractDistance, unit, 4)
    end
    if ok then
      if ns.IsSecret(v) then
        if not sawHidden then
          hidden, sawHidden = v, true
        end
      elseif v == true then
        return true
      elseif v == false then
        sawNo = true
      end
    end
  end
  if sawHidden then
    return hidden
  end
  if sawNo then
    return false
  end
end

local function MatchByTraits(unit)
  local _, class = UnitClass(unit)
  class = ns.Plain(class)
  if not class then
    return nil
  end
  local race = ns.Plain(UnitRace(unit))
  local honor = UnitHonorLevel and ns.Plain(UnitHonorLevel(unit)) or nil
  local found
  for _, rec in ipairs(Roster.enemies) do
    if rec.class == class
      and (race == nil or rec.raceName == nil or rec.raceName == race)
      and (honor == nil or rec.honor == nil or rec.honor == honor) then
      if found then
        return nil
      end
      found = rec
    end
  end
  return found
end

local function EnemyFor(unit)
  local key = ns.UnitKey(unit)
  if key then
    local rec = Roster.byKey[key]
    return rec and rec.team == "enemy" and rec or nil
  end
  if ns.Plain(UnitIsPlayer(unit)) == false or not ns.IsHostile(unit) then
    return nil
  end
  stats.traitLookups = (stats.traitLookups or 0) + 1
  return MatchByTraits(unit)
end
Live.EnemyFor = EnemyFor

local function SetDead(rec, dead)
  if dead == (rec.dead == true) then
    return
  end
  rec.dead = dead
  rec.deadAt = dead and GetTime() or nil
  if dead then
    rec.carrier = nil
  end
  Frames:UpdateDynamic(rec)
  Frames:ShowHealth(rec)
end
ns.SetDead = SetDead

local function SetVehicle(rec, unit)
  local enabled = ns.db[(rec.team or "enemy") .. "MarkVehicles"]
  if enabled == nil then enabled = ns.db.markVehicles end
  local inVehicle = enabled and ns.Plain(UnitInVehicle(unit)) or false
  if inVehicle == nil or inVehicle == (rec.inVehicle == true) then
    return
  end
  rec.inVehicle = inVehicle
  Frames:UpdateStatic(rec)
  Frames:UpdateDynamic(rec)
end
Live.SetVehicle = SetVehicle

local function ApplyHealth(rec, unit)
  rec.lastSeen = GetTime()
  rec.hpMax, rec.hp = UnitHealthMax(unit), UnitHealth(unit)
  rec.hasHealth = true
  if UnitHealthPercent and CurveConstants then
    rec.hpPct, rec.hasPct = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100), true
  end
  Frames:ShowHealth(rec)
  local dead = ns.Plain(UnitIsDeadOrGhost(unit))
  if dead ~= nil then
    SetDead(rec, dead)
  end
  if rec.team == "enemy" then
    SetVehicle(rec, unit)
  end
end

function Live.ApplyMana(rec)
  if rec.role ~= "HEALER" or not rec.unit or (Roster.slotsStale and ns.UnitKey(rec.unit) ~= rec.key) then
    return
  end
  rec.mpMax, rec.mp = UnitPowerMax(rec.unit, MANA), UnitPower(rec.unit, MANA)
  rec.hasMana = true
  Frames:ShowMana(rec)
end

local watchers = {}
local healthOwner = {}

local function OnWatched(self, event, unit)
  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    stats.health = stats.health + 1
    local rec = healthOwner[unit]
    if rec and (rec.team ~= "ally" or not Roster.slotsStale or ns.UnitKey(unit) == rec.key) then
      ApplyHealth(rec, unit)
    end
  elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
    local rec = Roster.allyByUnit[unit]
    if rec then
      SetVehicle(rec, unit)
    end
  elseif event == "UNIT_AURA" then
    stats.auras = stats.auras + 1
    local rec = Roster.allyByUnit[unit]
    if rec then
      ns.Auras:MarkDirty(rec)
    end
  else
    stats.power = stats.power + 1
    local rec = Roster.allyByUnit[unit]
    if rec then
      Live.ApplyMana(rec)
    end
  end
end

local function Watch(token, rec, mana, auras)
  local f = watchers[token]
  if not f then
    f = CreateFrame("Frame")
    f:SetScript("OnEvent", OnWatched)
    watchers[token] = f
  end
  healthOwner[token] = rec
  f:RegisterUnitEvent("UNIT_HEALTH", token)
  f:RegisterUnitEvent("UNIT_MAXHEALTH", token)
  if mana then
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", token)
    f:RegisterUnitEvent("UNIT_MAXPOWER", token)
  else
    f:UnregisterEvent("UNIT_POWER_UPDATE")
    f:UnregisterEvent("UNIT_MAXPOWER")
  end
  if auras then
    f:RegisterUnitEvent("UNIT_AURA", token)
  else
    f:UnregisterEvent("UNIT_AURA")
  end
  local allyVehicles = ns.db.allyMarkVehicles
  if allyVehicles == nil then allyVehicles = ns.db.markVehicles end
  if rec.team == "ally" and allyVehicles then
    f:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", token)
    f:RegisterUnitEvent("UNIT_EXITED_VEHICLE", token)
  else
    f:UnregisterEvent("UNIT_ENTERED_VEHICLE")
    f:UnregisterEvent("UNIT_EXITED_VEHICLE")
  end
end

local function Unwatch(token)
  healthOwner[token] = nil
  local f = watchers[token]
  if f then
    f:UnregisterAllEvents()
  end
end

function Live:SyncAllies()
  if ns.state ~= "bg" then
    return
  end
  local wantMana = ns.db.ally.showHealerMana
  local wantAuras = (ns.db.myAuras or ns.db.showDispels) and not ns.Auras:UsesEngine()
  for token in pairs(watchers) do
    if token:find("^raid") or token:find("^party") or token == "player" then
      if not Roster.allyByUnit[token] then
        Unwatch(token)
      end
    end
  end
  for unit, rec in pairs(Roster.allyByUnit) do
    Watch(unit, rec, wantMana and rec.role == "HEALER", wantAuras)
    SetVehicle(rec, unit)
    ApplyHealth(rec, unit)
    Live.ApplyMana(rec)
  end
end

local function WatchTargets()
  targetKey = ns.UnitKey("target")
  for _, token in ipairs({ "target", "focus" }) do
    local rec = EnemyFor(token)
    cached[token] = rec
    healthOwner[token] = rec
  end
  local f = watchers.targets
  if not f then
    f = CreateFrame("Frame")
    f:SetScript("OnEvent", OnWatched)
    watchers.targets = f
  end
  f:RegisterUnitEvent("UNIT_HEALTH", "target", "focus")
  f:RegisterUnitEvent("UNIT_MAXHEALTH", "target", "focus")
end

local clicked = {}
local CLICK_WINDOW = 1

function Live:NoteClick(rec, token)
  local c = clicked[token] or {}
  c.rec, c.at = rec, GetTime()
  clicked[token] = c
end

local function ClickedEnemy(token)
  local c = clicked[token]
  if not c or not c.rec or GetTime() - c.at > CLICK_WINDOW then
    return nil
  end
  if ns.Plain(UnitIsPlayer(token)) == false or not ns.IsHostile(token) then
    return nil
  end
  local _, class = UnitClass(token)
  class = ns.Plain(class)
  if class and c.rec.class and class ~= c.rec.class then
    return nil
  end
  return c.rec
end

local function OnTargetChanged(token)
  if token == "target" then
    targetKey = ns.UnitKey("target")
  end
  local rec = EnemyFor(token) or ClickedEnemy(token)
  if rec and token == "target" and not targetKey then
    targetKey = rec.key
  end
  cached[token] = rec
  healthOwner[token] = rec
  if rec then
    ApplyHealth(rec, token)
  end
end

ns:OnActive("PLAYER_TARGET_CHANGED", function()
  if ns.state == "bg" then
    OnTargetChanged("target")
  end
end)

ns:OnActive("PLAYER_FOCUS_CHANGED", function()
  if ns.state == "bg" then
    OnTargetChanged("focus")
  end
end)

ns:OnActive("UPDATE_MOUSEOVER_UNIT", function()
  if ns.state ~= "bg" then
    return
  end
  local rec = EnemyFor("mouseover")
  if rec then
    ApplyHealth(rec, "mouseover")
  end
end)

ns:OnActive("NAME_PLATE_UNIT_ADDED", function(_, unit)
  if ns.state ~= "bg" then
    return
  end
  local isPlayer = ns.Plain(UnitIsPlayer(unit))
  if isPlayer == false then
    return
  end
  local rec = EnemyFor(unit)
  if rec or ns.IsHostile(unit) then
    plates[unit] = true
  end
  if rec then
    plateKey[unit] = rec.key
    rec.token = unit
    Watch(unit, rec, false)
    ApplyHealth(rec, unit)
  end
end)

ns:OnActive("NAME_PLATE_UNIT_REMOVED", function(_, unit)
  plates[unit] = nil
  local key = plateKey[unit]
  if key then
    plateKey[unit] = nil
    Unwatch(unit)
    local rec = Roster.byKey[key]
    if rec and rec.token == unit then
      rec.token = nil
    end
  end
end)

local function AllyTargetedBy(plate)
  local token = plateTarget[plate]
  local key = ns.UnitKey(token)
  if key then
    local rec = Roster.byKey[key]
    return rec and rec.team == "ally" and rec or nil
  end
  local index = ns.Plain(UnitInRaid(token))
  if index then
    local rec = Roster.allyByUnit["raid" .. index]
    if rec and ns.Plain(UnitIsUnit(token, rec.unit)) then
      return rec
    end
  end
  for _, rec in ipairs(Roster.allies) do
    if ns.Plain(UnitIsUnit(token, rec.unit)) then
      return rec
    end
  end
end

local function PlateClass(plate)
  local key = plateKey[plate]
  local rec = key and Roster.byKey[key]
  if rec and rec.class then
    return rec.class
  end
  local _, class = UnitClass(plate)
  return ns.Plain(class)
end

local function CastTarget(unit)
  local name = UnitSpellTargetName and ns.Plain(UnitSpellTargetName(unit))
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return Roster:ResolveName(name)
end

local function CountHealer(healer, other)
  if other and other ~= healer and other.team == "ally" and not other.healerSeenBy[healer] then
    other.healerSeenBy[healer] = true
    other.healerClasses[#other.healerClasses + 1] = healer.class or "UNKNOWN"
  end
end

function Live:Tick()
  stats.ticks = stats.ticks + 1
  local now = GetTime()
  local db = ns.db
  local trackAllyTargets = (db.allyTargetIndicator or db.targetIndicator) ~= "off"
  local trackEnemyTargets = (db.enemyTargetIndicator or db.targetIndicator) ~= "off"
  local tracking = trackAllyTargets or trackEnemyTargets
  local allyFade, enemyFade = db.allyRangeFade, db.enemyRangeFade
  if allyFade == nil then allyFade = db.rangeFade end
  if enemyFade == nil then enemyFade = db.rangeFade end
  local iAmDead = ns.Plain(UnitIsDeadOrGhost("player")) == true
  local targetRec = cached.target
  if tracking then
    for _, rec in pairs(Roster.byKey) do
      if rec.targeters[1] then
        wipe(rec.targeters)
      end
    end
  end

  local healerTargets = db.healerTargets
  if healerTargets then
    for _, rec in ipairs(Roster.allies) do
      if rec.healerSeenBy then
        wipe(rec.healerSeenBy)
      else
        rec.healerSeenBy = {}
      end
      if rec.healerClasses then
        wipe(rec.healerClasses)
      else
        rec.healerClasses = {}
      end
    end
    for _, rec in ipairs(Roster.allies) do
      if rec.role == "HEALER" and rec.unit then
        local key = ns.UnitKey(rec.targetUnit)
        CountHealer(rec, key and Roster.byKey[key])
        CountHealer(rec, CastTarget(rec.unit))
      end
    end
  end

  for _, rec in ipairs(Roster.allies) do
    local unit = rec.unit
    if healerTargets then
      if rec.healerClasses[2] then
        table.sort(rec.healerClasses)
      end
      Frames:UpdateHealers(rec)
    end
    local dead = ns.Plain(UnitIsDeadOrGhost(unit))
    if dead ~= nil then
      SetDead(rec, dead)
    end
    if rec.dead then
      Frames:UpdateDeadTimer(rec, now)
    end

    if not allyFade or rec.isPlayer then
      Frames:SetNear(rec, true)
    elseif iAmDead then
      Frames:SetNear(rec, false)
    else
      local inRange, checked = UnitInRange(unit)
      if not ns.IsSecret(inRange) and (inRange == nil or ns.Plain(checked) == false) then
        inRange = true
      end
      Frames:SetNear(rec, inRange)
    end

    local enemy = EnemyFor(rec.targetUnit)
    if enemy then
      if trackEnemyTargets then
        enemy.targeters[#enemy.targeters + 1] = rec.class or "PRIEST"
      end
      if not enemy.token and enemy ~= targetRec then
        ApplyHealth(enemy, rec.targetUnit)
      end
      enemy.rangeUnit = enemy.rangeUnit or rec.targetUnit
    end
  end

  if trackAllyTargets then
    for plate in pairs(plates) do
      local class = PlateClass(plate)
      if class then
        local ally = AllyTargetedBy(plate)
        if ally then
          ally.targeters[#ally.targeters + 1] = class
        end
      end
    end
    for _, rec in ipairs(Roster.allies) do
      if rec.targeters[2] then
        table.sort(rec.targeters)
      end
      Frames:UpdateTargeters(rec)
    end
  end

  for _, rec in ipairs(Roster.enemies) do
    if rec.dead then
      if rec.deadAt and now - rec.deadAt >= ENEMY_DEAD_MARKER_TTL then
        SetDead(rec, false)
      else
        Frames:UpdateDeadTimer(rec, now)
      end
    end
    -- Источник аур врага: только цель, фокус или враждебный неймплейт.
    -- Без rangeUnit, чтобы контейнер не привязался к чужому юниту.
    local unit = (rec == targetRec and "target") or (rec == cached.focus and "focus") or (rec.token and ns.IsHostile(rec.token) and rec.token) or nil
    if unit ~= rec.auraUnit then
      rec.auraUnit = unit
      -- Обновляем ауры при смене юнита, если любая из активных систем
      -- (свои дебаффы, сейвы на врагах, CC на врагах) включена.
      if db.myDebuffs or db.showEnemyDef or db.showEnemyCC then
        ns.Auras:Update(rec)
      end
    end
    if not enemyFade then
      Frames:SetNear(rec, true)
    elseif iAmDead or rec.dead then
      Frames:SetNear(rec, false)
    else
      if unit then
        if unit ~= rec.rangeFrom or now - (rec.rangeAt or 0) >= RANGE_EVERY then
          local near = EnemyInRange(unit)
          if not ns.IsSecret(near) and near == nil then
            local prev = rec.inRange
            if ns.IsSecret(prev) or prev ~= nil then
              near = prev
            else
              near = false
            end
          end
          rec.inRange, rec.rangeFrom, rec.rangeAt = near, unit, now
        end
      elseif now - rec.lastSeen >= SEEN_GRACE or now - (rec.rangeAt or 0) >= SEEN_GRACE then
        rec.inRange, rec.rangeFrom = false, nil
      end
      Frames:SetNear(rec, rec.inRange)
    end
    rec.rangeUnit = nil
    if trackEnemyTargets then
      if rec.targeters[2] then
        table.sort(rec.targeters)
      end
      Frames:UpdateTargeters(rec)
    end
  end

  for _, list in ipairs(bothTeams) do
    for _, rec in ipairs(list) do
      local isTarget = rec.key == targetKey
      if isTarget ~= (rec.isTarget == true) then
        rec.isTarget = isTarget
        Frames:UpdateDynamic(rec)
      end
    end
  end
end

function Live.SafeTick()
  ns.Safe("tick", Live.Tick, Live)
end

function Live:Stats()
  local secs = math.max(GetTime() - stats.since, 1)
  local watched = 0
  for _ in pairs(healthOwner) do
    watched = watched + 1
  end
  local line = string.format("events/s: health %.1f, mana %.1f, auras %.1f; updates/s %.1f; watching %d units", stats.health / secs, stats.power / secs, stats.auras / secs, stats.ticks / secs, watched)
  if ns.lastError then
    line = line .. " |cffff5555last update error:|r " .. ns.lastError
  end
  return line
end

function Live:OnActivate(state)
  if state ~= "bg" then
    return
  end
  stats.health, stats.power, stats.auras, stats.ticks, stats.since = 0, 0, 0, 0, GetTime()
  local _, myClass = UnitClass("player")
  harmSpell = HARM_SPELLS[myClass]
  WatchTargets()
  self:SyncAllies()
  ticker = C_Timer.NewTicker(TICK, Live.SafeTick)
end

function Live:OnDeactivate()
  if ticker then
    ticker:Cancel()
    ticker = nil
  end
  for token in pairs(watchers) do
    Unwatch(token)
  end
  wipe(plateKey)
  wipe(plates)
  wipe(cached)
  targetKey = nil
end
