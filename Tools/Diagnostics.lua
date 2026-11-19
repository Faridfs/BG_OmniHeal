local _, ns = ...

local function S(v)
  if ns.IsSecret(v) then return "|cffff5555SECRET|r" end
  return v == nil and "|cff888888nil|r" or "|cff55ff55ok|r"
end

local function ProbeUnit(unit)
  local exists = UnitExists(unit)
  if not ns.IsSecret(exists) and not exists then
    ns.Print(unit .. ": none")
    return
  end
  local _, class = UnitClass(unit)
  ns.Print(
    unit .. ":",
    "name " .. S(UnitName(unit)),
    "full name " .. S(UnitFullName(unit)),
    "guid " .. S(UnitGUID(unit)),
    "class " .. S(class),
    "hp " .. S(UnitHealth(unit)),
    "max " .. S(UnitHealthMax(unit)),
    "dead " .. S(UnitIsDeadOrGhost(unit))
  )
end

function ns.Environment()
  local version, build, date, interface = GetBuildInfo()
  ns.Print(string.format("client %s build %s (%s), interface %s, project %s",
    tostring(version), tostring(build), tostring(date), tostring(interface), tostring(WOW_PROJECT_ID)))
  local checks = {
    { "hidden values (issecretvalue)", issecretvalue },
    { "aura containers", AuraContainerSortMethod ~= nil or (C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer")) or nil },
    { "C_UnitAuras.GetAuraDataByIndex", C_UnitAuras and C_UnitAuras.GetAuraDataByIndex },
    { "UnitAura", UnitAura },
    { "C_PvP.GetScoreInfo", C_PvP and C_PvP.GetScoreInfo },
    { "GetBattlefieldScore", GetBattlefieldScore },
    { "specs (GetSpecializationInfoForClassID)", (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID) or GetSpecializationInfoForClassID },
    { "UnitGroupRolesAssigned", UnitGroupRolesAssigned },
    { "C_Spell.IsSpellInRange", C_Spell and C_Spell.IsSpellInRange },
    { "IsSpellInRange", IsSpellInRange },
    { "C_Item.IsItemInRange", C_Item and C_Item.IsItemInRange },
    { "C_Spell.GetSpellTexture", C_Spell and C_Spell.GetSpellTexture },
    { "UnitHonorLevel", UnitHonorLevel },
    { "C_ClassColor", C_ClassColor },
    { "Settings panel", Settings and Settings.RegisterCanvasLayoutCategory },
    { "cast targets (UnitSpellTargetName)", UnitSpellTargetName },
    { "combat log", CombatLogGetCurrentEventInfo },
  }
  local have, missing = {}, {}
  for _, c in ipairs(checks) do
    if c[2] then
      have[#have + 1] = c[1]
    else
      missing[#missing + 1] = c[1]
    end
  end
  ns.Print("|cff55ff55has:|r " .. table.concat(have, ", "))
  ns.Print("|cffff5555missing:|r " .. (missing[1] and table.concat(missing, ", ") or "nothing"))
end

local function Section(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    ns.Print(name .. ": |cffff5555error|r " .. tostring(err))
  end
end

function ns.Probe()
  local layout = ns.inactiveReason or ns.BRACKET_NAMES[ns:Bracket()] or ns:Bracket()
  ns.Print("Probe (in a battleground: " .. tostring(ns.inBG) .. ", layout: " .. layout .. ", version " .. tostring(ns.version) .. ")")
  Section("aura containers", function()
    for _, line in ipairs(ns.Auras:ProbeLines()) do
      ns.Print(line)
    end
  end)
  Section("target", function()
    ProbeUnit("target")
    local _, race = UnitRace("target")
    ns.Print("target race " .. S(race) .. ", honor " .. S(UnitHonorLevel and UnitHonorLevel("target")) .. ", hostile " .. S(UnitCanAttack("player", "target")))
    local matched = ns.Live.EnemyFor and ns.Live.EnemyFor("target")
    ns.Print("target matched to scoreboard: " .. (matched and matched.key or "no"))
  end)
  Section("nameplates", function()
    ProbeUnit("nameplate1")
    ProbeUnit("nameplate1target")
  end)
  if IsInRaid() then
    Section("raid1", function()
      ProbeUnit("raid1")
      ProbeUnit("raid1target")
      ns.Print("raid1 range " .. S(UnitInRange("raid1")) .. ", mana " .. S(UnitPower("raid1", 0)))
      ns.Print("nameplate1target is raid1: " .. S(UnitIsUnit("nameplate1target", "raid1")))
      ns.Print("nameplate1 hostile: can attack " .. S(UnitCanAttack("player", "nameplate1")) .. ", is enemy " .. S(UnitIsEnemy("player", "nameplate1")))
    end)
  end
  Section("scoreboard", function()
    local info = GetNumBattlefieldScores() > 0 and ns.ScoreInfo(1)
    if info then
      ns.Print("scoreboard:", "name " .. S(info.name), "faction " .. S(info.faction), "class " .. S(info.classToken), "spec " .. S(info.talentSpec))
    else
      ns.Print("scoreboard: no data")
    end
    ns.Print("rows " .. GetNumBattlefieldScores() .. ", arena faction " .. S(GetBattlefieldArenaFaction())
      .. ", our team " .. tostring(ns.Roster.myTeam) .. ", enemies listed " .. #ns.Roster.enemies)
  end)
  Section("other", function()
    if ns.lastBGMessageSecret ~= nil then
      ns.Print("bg announcements " .. (ns.lastBGMessageSecret and "|cffff5555SECRET|r" or "|cff55ff55ok|r"))
    else
      ns.Print("bg announcements: none seen yet")
    end
    ns.Print(string.format("tracking %d enemies, %d allies", #ns.Roster.enemies, #ns.Roster.allies))
    if ns.lastError then
      ns.Print("last update error: " .. ns.lastError)
    end
  end)
end
