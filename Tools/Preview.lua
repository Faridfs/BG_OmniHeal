local _, ns = ...
local Test = ns:NewModule("Test")
local Roster = ns.Roster
local IS_RETAIL = WOW_PROJECT_ID ~= nil and WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local UNSTABLE_AFFLICTION_SPELL_ID = 1219045

local HEALERS = { "PRIEST", "PALADIN", "DRUID", "SHAMAN", "MONK", "EVOKER" }
local TANKS = { "WARRIOR", "PALADIN", "DEATHKNIGHT", "DRUID", "MONK", "DEMONHUNTER" }
local DAMAGE = {
  "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
  "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
}

local ROLE_COUNTS = { ["8"] = { 2, 1 }, ["10"] = { 2, 1 }, ["15"] = { 3, 1 } }
local ALLY_FIRST_CLASSES = { "PRIEST", "PALADIN", "SHAMAN", "MAGE", "DEATHKNIGHT" }
local SELF_DEF_SAMPLE_BY_CLASS = {
  PALADIN = 642, MAGE = 45438, HUNTER = 186265, ROGUE = 31224,
  DEATHKNIGHT = 48792, WARRIOR = 23920, DEMONHUNTER = 187827,
  DRUID = 22812, PRIEST = 47585, MONK = 122783, SHAMAN = 108270,
  WARLOCK = 104773, EVOKER = 363916,
}
local ALLY_PERSONAL_DEFENSIVES = {
  PRIEST = { 47585, 19236 },
  SHAMAN = { 108270, 108271 },
  DEATHKNIGHT = { 48792, 48707 },
  PALADIN = { 642, 498 },
  MAGE = { 45438, 110959 },
}
local HEAL_SAMPLES = { 194384, 17, 774, 33763, 48438, 61295 }
local EXTERNAL_SAMPLES = { 6940, 1022, 204018, 33206, 116849, 102342 }
local ALLY_CC_SAMPLES = { { 118, "Magic" }, { 853, "Magic" }, { 408, "Physical" }, { 5782, "Magic" } }
local ENEMY_CC_SAMPLES = { { 408, "Physical" }, { 5782, "Magic" }, { 118, "Magic" }, { 853, "Magic" } }
local ALLY_DISPEL_SAMPLES = { { 118, "Magic" }, { 2818, "Poison" }, { 1714, "Curse" }, { 55095, "Disease" } }
-- Cycle through all dispel colors in test mode to verify the addon's border effects.
local ENEMY_DEBUFF_SAMPLES = {
  { 589, "Magic" }, { 1714, "Curse" }, { 2818, "Poison" }, { 55095, "Disease" },
}

local ticker

local function SpecFor(class, role)
  local specs = Roster.specInfo[class]
  if specs then
    for _, si in pairs(specs) do
      if si.role == role then
        return si
      end
    end
  end
end

local function Build(team, list)
  wipe(list)
  local bracket = ns:Bracket()
  local size = tonumber(bracket)
  local healers, tanks = ROLE_COUNTS[bracket][1], ROLE_COUNTS[bracket][2]
  local allyRoles
  if team == "ally" then
    allyRoles = { "HEALER", "HEALER", "DAMAGER", "DAMAGER", "TANK" }
    local remaining = { HEALER = healers, TANK = tanks, DAMAGER = size - healers - tanks }
    for _, role in ipairs(allyRoles) do remaining[role] = remaining[role] - 1 end
    local remainingRoles = {}
    for _, role in ipairs({ "HEALER", "TANK", "DAMAGER" }) do
      for _ = 1, math.max(0, remaining[role]) do remainingRoles[#remainingRoles + 1] = role end
    end
    for i = 6, size do allyRoles[i] = remainingRoles[i - 5] end
  end
  for i = 1, size do
    local role, pool
    if team == "ally" then
      role = allyRoles[i]
      pool = role == "HEALER" and HEALERS or role == "TANK" and TANKS or DAMAGE
    elseif i <= healers then
      role, pool = "HEALER", HEALERS
    elseif i <= healers + tanks then
      role, pool = "TANK", TANKS
    else
      role, pool = "DAMAGER", DAMAGE
    end
    
    local classOffset = team == "enemy" and 0 or 2
    local class = team == "ally" and ALLY_FIRST_CLASSES[i] or nil
    if not class then class = pool[(i * 3 + classOffset) % #pool + 1] end

    local si = SpecFor(class, role)
    local name = (team == "enemy" and "Enemy" or "Ally") .. i
    local rec = {
      key = name .. "-Test",
      name = name,
      fullName = name .. "-Test",
      team = team,
      class = class,
      specIcon = si and si.icon,
      role = role,
      lastSeen = 0,
      targeters = {},
      dead = false,
      hpMax = 100,
      hp = 100 - (i * 13) % 55,
      hasHealth = true,
      mpMax = 100,
      mp = 90 - (i * 17) % 60,
      hasMana = true,
    }
    Roster.byKey[rec.key] = rec
    list[i] = rec
  end
end

local function Decorate()
  local e, a = Roster.enemies, Roster.allies
  
  e[1].isPremade = true
  e[2].isPremade = true
  e[3].isPremade = true

  e[1].carrier = "Alliance"
  a[2].carrier = "Horde"
  e[3].isTarget = true

  local targeterClasses = {
    "DEATHKNIGHT", "HUNTER", "MAGE", "ROGUE", "WARRIOR", "PALADIN",
    "SHAMAN", "PRIEST", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
  }
  local function Targeters(count, offset)
    local classes = {}
    for j = 1, count do
      classes[j] = targeterClasses[(offset + j - 2) % #targeterClasses + 1]
    end
    return classes
  end

  for i, rec in ipairs(a) do
    if i == 1 or i % 3 == 0 then
      local count = 2 + (math.floor((i - 1) / 3) % 4)
      rec.targeters = Targeters(count, i)
    end
  end
  local enemyTargetSamples = {
    { 1, 3 },
    { math.ceil(#e / 2), 4 },
    { #e, 5 },
  }
  for _, sample in ipairs(enemyTargetSamples) do
    local rec = e[sample[1]]
    if rec then rec.targeters = Targeters(sample[2], sample[1] * 2) end
  end
  a[2].healerClasses = { "DRUID", "PRIEST" }
  if a[5] then a[5].healerClasses = { "SHAMAN" } end
  
  local now = GetTime()
  local function sample(spellID, duration, left, stacks, dispelName)
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID) or 134400
    return {
      spellId = spellID,
      icon = icon,
      duration = duration,
      expirationTime = now + left,
      applications = stacks,
      dispelName = dispelName,
    }
  end

  local function unstableAfflictionSample()
    local icon
    if C_Spell and C_Spell.GetSpellTexture then
      icon = C_Spell.GetSpellTexture(UNSTABLE_AFFLICTION_SPELL_ID) or C_Spell.GetSpellTexture(316099)
    end
    local aura = sample(UNSTABLE_AFFLICTION_SPELL_ID, 16, 11, nil, "Magic")
    aura.icon = icon or aura.icon or 136197
    -- Test-only marker so the new enlarged-priority-aura display can be previewed reliably.
    aura.isBossAura = true
    return aura
  end

  local allyVehicles = ns.db.allyMarkVehicles
  if allyVehicles == nil then allyVehicles = ns.db.markVehicles end
  local enemyVehicles = ns.db.enemyMarkVehicles
  if enemyVehicles == nil then enemyVehicles = ns.db.markVehicles end
  if a[7] then a[7].inVehicle = allyVehicles end
  if e[9] then e[9].inVehicle = enemyVehicles end
  
  -- Тестовые эффекты диспела, контроля и аур.
  local function debuff(spellID, kind, duration, left)
    local d = sample(spellID, duration, left, nil, kind)
    return d
  end
  local dense = ns.db.testScenario == "dense"

  -- Первые пять союзников получают личные сейвы класса, остальные — внешние.
  for i, rec in ipairs(a) do
    local buffCount = 1 + ((i - 1) % 3)
    rec.testAuras = {}
    for j = 1, buffCount do
      local buffID = HEAL_SAMPLES[(i + j - 2) % #HEAL_SAMPLES + 1]
      rec.testAuras[j] = sample(buffID, 18 - (j - 1) * 2, 10 + (i + j) % 7, j > 1 and i % 3 == 0 and 2 or nil)
    end

    local personalDefensives = i <= #ALLY_FIRST_CLASSES and ALLY_PERSONAL_DEFENSIVES[rec.class]
    if personalDefensives then
      rec.testExternals = { sample(personalDefensives[1], 10, 5 + i % 4) }
      if dense then rec.testExternals[2] = sample(personalDefensives[2], 12, 7 + i % 3) end
    else
      local externalID = EXTERNAL_SAMPLES[(i - 6) % #EXTERNAL_SAMPLES + 1]
      rec.testExternals = { sample(externalID, 10 + i % 4, 5 + i % 4) }
      if dense then
        local extraExternal = EXTERNAL_SAMPLES[(i - 5) % #EXTERNAL_SAMPLES + 1]
        rec.testExternals[2] = sample(extraExternal, 12, 7 + i % 3)
      end
    end

    if dense or i % 2 == 0 then
      local cc = ALLY_CC_SAMPLES[(i - 1) % #ALLY_CC_SAMPLES + 1]
      rec.testCC = { sample(cc[1], 8, 4 + i % 3, nil, cc[2]) }
      if dense then
        local extraCC = ALLY_CC_SAMPLES[i % #ALLY_CC_SAMPLES + 1]
        rec.testCC[2] = sample(extraCC[1], 12, 7, nil, extraCC[2])
      end
    end

    if (IS_RETAIL and i == 1) or dense or i % 3 == 1 then
      local dispel = ALLY_DISPEL_SAMPLES[(i - 1) % #ALLY_DISPEL_SAMPLES + 1]
      rec.testDispels = { debuff(dispel[1], dispel[2], 12, 7) }
      if dense then
        local extraDispel = ALLY_DISPEL_SAMPLES[i % #ALLY_DISPEL_SAMPLES + 1]
        rec.testDispels[2] = debuff(extraDispel[1], extraDispel[2], 10, 5)
      end
      if IS_RETAIL and i == 1 then
        rec.testDispels = {
          unstableAfflictionSample(),
          debuff(589, "Magic", 18, 10),
          debuff(1714, "Curse", 14, 8),
          debuff(2818, "Poison", 12, 6),
        }
      end
    end
  end

  -- На каждом враге есть личный сейв его класса и дебафф для просмотра.
  for i, rec in ipairs(e) do
    local spellID = SELF_DEF_SAMPLE_BY_CLASS[rec.class]
    if spellID then rec.testDefs = { sample(spellID, 10, 5 + i % 4) } end

    local debuff = ENEMY_DEBUFF_SAMPLES[(i - 1) % #ENEMY_DEBUFF_SAMPLES + 1]
    rec.testDebuffs = { sample(debuff[1], 18, 8 + i % 6, nil, debuff[2]) }
    if dense then
      local extraDebuff = ENEMY_DEBUFF_SAMPLES[i % #ENEMY_DEBUFF_SAMPLES + 1]
      rec.testDebuffs[2] = sample(extraDebuff[1], 14, 6 + i % 5, nil, extraDebuff[2])
    end

    if dense or i % 2 == 0 then
      local cc = ENEMY_CC_SAMPLES[(i - 1) % #ENEMY_CC_SAMPLES + 1]
      rec.testCC = { sample(cc[1], 8, 4 + i % 3, nil, cc[2]) }
      if dense then
        local extraCC = ENEMY_CC_SAMPLES[i % #ENEMY_CC_SAMPLES + 1]
        rec.testCC[2] = sample(extraCC[1], 12, 7, nil, extraCC[2])
      end
    end
  end
end

function Test:Paint()
  for _, list in ipairs({ Roster.enemies, Roster.allies }) do
    for i, rec in ipairs(list) do
      ns.Frames:SetNear(rec, i % 4 ~= 0)
    end
  end
end

local function Animate()
  local now = GetTime()
  for _, list in ipairs({ Roster.enemies, Roster.allies }) do
    for _, rec in ipairs(list) do
      if rec.dead then
        ns.Frames:UpdateDeadTimer(rec, now)
      end
    end
  end
end

function Test:SetEnabled(enabled)
  if ns.inBG or (ns.testMode == true) == enabled then return end
  ns.testMode = enabled
  ns:UpdateState()
end

function Test:Toggle()
  if ns.Setup and ns.Setup.active then
    ns.Setup:TogglePreview()
    return
  end
  if ns.inBG then
    ns.Print("Test mode isn't available inside a battleground.")
    return
  end
  self:SetEnabled(not ns.testMode)
  ns.Print(ns.testMode and "Test mode on." or "Test mode off.")
end

function Test:Rebuild()
  if ns.state ~= "test" then return end
  wipe(Roster.byKey)
  Build("enemy", Roster.enemies)
  Build("ally", Roster.allies)
  Decorate()
  
  ns.Frames:SetRecords("enemy", Roster.enemies)
  ns.Frames:SetRecords("ally", Roster.allies)
end

function Test:OnActivate(state)
  if state ~= "test" then return end
  self:Rebuild()
  
  C_Timer.After(0, function()
    if ns.state == "test" then
      ns.Frames:Refresh()
      for _, rec in pairs(Roster.byKey) do
        if rec.row then ns.Auras:Update(rec) end
      end
    end
  end)
  
  ticker = C_Timer.NewTicker(1, Animate)
end

function Test:OnDeactivate()
  if ticker then
    ticker:Cancel()
    ticker = nil
  end
end
