local _, ns = ...

local LEGACY_TEAM_KEYS = {
  "barTexture", "bgAlpha", "classColorBars", "fontSize", "healthText",
  "iconType", "manaHeight", "nameOffsetX", "nameOffsetY", "panelAlpha",
  "roleMarker", "showHealerMana", "showRealm", "sortBy", "style",
}

local CopyDefaults = ns.CopyDefaults

local function InheritBlitzSettings(brackets)
  if type(brackets) ~= "table" or type(brackets["10"]) ~= "table" then return end
  if type(brackets["8"]) ~= "table" then brackets["8"] = {} end
  CopyDefaults(brackets["10"], brackets["8"])
end

function ns:MigrateProfile(db)
  if type(db.brackets) ~= "table" then db.brackets = {} end
  if (db.schema or 0) < 9 then InheritBlitzSettings(db.brackets) end
  local function toBrackets(team, key, value)
    for _, b in ipairs(ns.BRACKETS) do
      db.brackets[b] = db.brackets[b] or {}
      db.brackets[b][team] = db.brackets[b][team] or {}
      if db.brackets[b][team][key] == nil then db.brackets[b][team][key] = value end
    end
  end
  for _, team in ipairs({ "enemy", "ally" }) do
    db[team] = db[team] or {}
    for _, key in ipairs(ns.LAYOUT_KEYS) do
      local value = db[team][key]
      if value == nil then value = db[key] end
      if value ~= nil then toBrackets(team, key, value) db[team][key] = nil end
    end
    for _, key in ipairs(LEGACY_TEAM_KEYS) do
      if db[key] ~= nil and db[team][key] == nil then
        db[team][key] = (key == "sortBy" and db[key] == "role") and "healer" or db[key]
      end
    end
  end
  for _, key in ipairs(ns.LAYOUT_KEYS) do db[key] = nil end
  for _, key in ipairs(LEGACY_TEAM_KEYS) do db[key] = nil end
  if (db.schema or 0) < 2 then
    for _, team in ipairs({ "enemy", "ally" }) do
      if db[team].roleMarker == "both" then db[team].roleMarker = "icon" end
    end
    db.schema = 2
  end
  if (db.schema or 0) < 4 then
    db.bigDispelSize, db.bigDispelMax, db.bigDispelTimers = nil, nil, nil
    db.bigDispelAnchor, db.bigDispelGrow = nil, nil
    db.bigDispelOffsetX, db.bigDispelOffsetY = nil, nil
    db.schema = 4
  end
  if (db.schema or 0) < 5 then
    -- Replace old shipped offsets while keeping values the user changed.
    if db.auraOffsetY == 10 then db.auraOffsetY = 0 end
    if db.dispelGrow == "left" then db.dispelGrow = "right" end
    if db.dispelOffsetX == -10 then db.dispelOffsetX = 0 end
    if db.dispelOffsetY == -10 then db.dispelOffsetY = 0 end
    if db.debuffOffsetX == -40 then db.debuffOffsetX = 0 end
    if db.allyCCOffsetX == 22 then db.allyCCOffsetX = 0 end
    if db.allyCCOffsetY == -8 then db.allyCCOffsetY = 0 end
    if db.enemyCCOffsetX == 3 then db.enemyCCOffsetX = 0 end
    db.schema = 5
  end
  if db.hideBlizzardRaid ~= nil or db.hideElvUIRaid ~= nil or db.hideEllesmereRaid ~= nil then
    db.hideOtherRaid = db.hideOtherRaid or db.hideBlizzardRaid or db.hideElvUIRaid or db.hideEllesmereRaid or false
    db.hideBlizzardRaid, db.hideElvUIRaid, db.hideEllesmereRaid = nil, nil, nil
  end
  if db.targetCounter ~= nil then
    db.targetIndicator = db.targetIndicator or (db.targetCounter and "bubbles" or "off")
    db.targetCounter = nil
  end
  db.hideInEpic, db.testAnimate, db.dispelHighlight = nil, nil, nil
  if db.markerShape then db.targetMarkShape = db.targetMarkShape or db.markerShape end
  db.markerShape, db.countSize = nil, nil
  if db.dispelFilter == "cc" then db.showAllyCC, db.showDispels = true, false end
  if db.debuffFilter == "cc" then db.showEnemyCC, db.myDebuffs = true, false end
  db.dispelFilter, db.debuffFilter = nil, nil

  -- Preserve the old master glow toggle when upgrading to per-category
  -- animation settings.
  if db.auraAnimationVersion == nil then
    if db.enableAuraGlow == false then
      db.auraAnimDebuffActive = "none"
      db.auraAnimCCActive = "none"
    end
    db.auraAnimationVersion = 1
  end
  if db.auraAnimationVersion < 4 then
    for _, category in ipairs({ "Buff", "Debuff", "CC" }) do
      local appearKey = "auraAnim" .. category .. "Appear"
      local activeKey = "auraAnim" .. category .. "Active"
      local colorKey = "auraAnim" .. category .. "ColorMode"
      local appear = db[appearKey]
      local active = db[activeKey]
      local colorMode = db[colorKey]

      if appear == "pop" then appear = "fade" end
      if appear ~= nil and appear ~= "none" and appear ~= "fade" and appear ~= "flash" then
        appear = "none"
      end
      if active == "soft" or active == "neon" then active = "borderPulse" end
      if active ~= nil and active ~= "none" and active ~= "border" and active ~= "borderPulse" and active ~= "borderOrbit" then
        active = "none"
      end
      if colorMode ~= nil and colorMode ~= "category" and colorMode ~= "dispel" and colorMode ~= "custom" then
        colorMode = nil
      end
      if category == "Buff" and colorMode == "dispel" then colorMode = "category" end

      db[appearKey], db[activeKey], db[colorKey] = appear, active, colorMode
    end
    db.auraAnimationVersion = 4
  end
  if db.auraAnimationVersion < 5 then
    for _, category in ipairs({ "Buff", "Debuff", "CC" }) do
      local prefix = "auraAnim" .. category
      local activeKey = prefix .. "Active"
      local effectsKey = prefix .. "Effects"
      local legacy = db[activeKey]
      if type(db[effectsKey]) ~= "table" and legacy ~= nil then
        db[effectsKey] = {
          border = legacy == "border",
          borderPulse = legacy == "borderPulse" or legacy == "soft" or legacy == "neon",
          borderOrbit = legacy == "borderOrbit",
        }
      end
      db[activeKey] = nil

    end
    db.auraAnimationVersion = 5
  end
  if db.auraAnimationVersion < 6 then
    for _, category in ipairs({ "Buff", "Debuff", "CC" }) do
      local prefix = "auraAnim" .. category
      local modeKey = prefix .. "ColorMode"
      if db[modeKey] == "custom" then
        db[modeKey] = category == "Buff" and "category" or "dispel"
      end
      db[prefix .. "R"], db[prefix .. "G"], db[prefix .. "B"] = nil, nil, nil
      db[prefix .. "CustomColorSet"] = nil
    end
    db.auraAnimationVersion = 6
  end
  if db.auraAnimationVersion < 7 then
    for _, category in ipairs({ "Buff", "Debuff", "CC" }) do
      local effectsKey = "auraAnim" .. category .. "Effects"
      local effects = db[effectsKey]
      if type(effects) ~= "table" then effects = {} end
      -- Replace the always-on game border with the explicit colored-border effect.
      if category == "Buff" then effects.border = effects.border == true
      else effects.border = true end
      effects.neon = effects.neon == true
      db[effectsKey] = effects
    end
    db.auraAnimationVersion = 7
  end
  if db.auraAnimationVersion < 8 then
    for _, category in ipairs({ "Buff", "Debuff", "CC" }) do
      local prefix = "auraAnim" .. category
      for _, effect in ipairs({ "Border", "Neon", "Pulse", "Orbit" }) do
        for _, field in ipairs({ "Speed", "Strength", "Size" }) do
          local key = prefix .. effect .. field
          if db[key] == nil then db[key] = db[prefix .. field] end
        end
      end
    end
    db.auraAnimationVersion = 8
  end
  if db.auraAnimationVersion < 9 then
    local buffColorModeKey = "auraAnimBuffColorMode"
    if db[buffColorModeKey] == nil or db[buffColorModeKey] == "category" then
      db[buffColorModeKey] = "school"
    end
    db.auraAnimationVersion = 9
  end
  if db.auraAnimationVersion < 10 then
    -- Buff icons remain visible, but aura animations are reserved for debuffs and CC.
    db.auraAnimBuffColorMode = "category"
    db.auraAnimationVersion = 10
  end
  if db.auraAnimationVersion < 11 then
    for _, category in ipairs({ "Debuff", "CC" }) do
      local prefix = "auraAnim" .. category .. "Orbit"
      if db[prefix .. "Length"] == nil then db[prefix .. "Length"] = 1 end
      if db[prefix .. "Count"] == nil then db[prefix .. "Count"] = 2 end
    end
    db.auraAnimationVersion = 11
  end
  db.enableAuraGlow = nil

  for _, team in ipairs({ "enemy", "ally" }) do
    if db[team].showIcon ~= nil then
      db[team].iconType = db[team].iconType or (db[team].showIcon and "spec" or "none")
      db[team].showIcon = nil
    end
  end
  if type(db.positions) == "table" and (type(db.positions.enemy) == "table" or type(db.positions.ally) == "table") then
    local old = db.positions
    db.positions = {}
    for _, b in ipairs(ns.BRACKETS) do
      db.positions[b] = {}
      CopyDefaults({ ally = old.ally, enemy = old.enemy }, db.positions[b])
    end
  end

  -- МИГРАЦИЯ ФЛАГОНОСЦЕВ: Переносим глобальные настройки в командные
  for _, team in ipairs({ "enemy", "ally" }) do
    if db[team].carrierAnchor == nil then
      db[team].carrierAnchor = db.carrierAnchor or "auto"
      db[team].carrierX = db.carrierX or 0
      db[team].carrierY = db.carrierY or 0
      db[team].carrierScale = db.carrierScale or 1
    end
  end
  db.carrierAnchor, db.carrierX, db.carrierY, db.carrierScale = nil, nil, nil, nil

  if (db.schema or 0) < 6 then
    local targetingFields = {
      { "TargetIndicator", "targetIndicator" },
      { "TargetMarkShape", "targetMarkShape" },
      { "TargetMarkAnchor", "targetMarkAnchor" },
      { "TargetMarkGrow", "targetMarkGrow" },
      { "TargetMarkX", "targetMarkX" },
      { "TargetMarkY", "targetMarkY" },
      { "TargetMarkScale", "targetMarkScale" },
      { "TargetMarkLayer", "targetMarkLayer" },
      { "CountAnchor", "countAnchor" },
      { "CountX", "countX" },
      { "CountY", "countY" },
      { "CountScale", "countScale" },
      { "CountLayer", "countLayer" },
    }
    for _, team in ipairs({ "ally", "enemy" }) do
      for _, field in ipairs(targetingFields) do
        local key = team .. field[1]
        if db[key] == nil then db[key] = db[field[2]] end
      end
    end
    db.schema = 6
  end

  if (db.schema or 0) < 7 then
    local sharedFields = {
      { "HpTextAnchor", "hpTextAnchor" }, { "HpTextX", "hpTextX" },
      { "HpTextY", "hpTextY" }, { "HpTextScale", "hpTextScale" },
      { "DeadTextAnchor", "deadTextAnchor" }, { "DeadTextX", "deadTextX" },
      { "DeadTextY", "deadTextY" }, { "DeadTextScale", "deadTextScale" },
      { "DeadTimer", "deadTimer" }, { "MarkVehicles", "markVehicles" },
      { "RangeFade", "rangeFade" }, { "RangeAlpha", "rangeAlpha" },
      { "Carriers", "carriers" }, { "StackSize", "stackSize" },
      { "HealthBarLayer", "healthBarLayer" }, { "NameLayer", "nameLayer" },
      { "HpTextLayer", "hpTextLayer" }, { "DeadTextLayer", "deadTextLayer" },
      { "CarrierIconLayer", "carrierIconLayer" }, { "VehicleBorderLayer", "vehicleBorderLayer" },
      { "UnitIconLayer", "unitIconLayer" }, { "TargetGlowLayer", "targetGlowLayer" },
    }
    for _, team in ipairs({ "ally", "enemy" }) do
      for _, field in ipairs(sharedFields) do
        local key = team .. field[1]
        if db[key] == nil then db[key] = db[field[2]] end
      end
      if team == "ally" then
        if db.allyManaBarLayer == nil then db.allyManaBarLayer = db.manaBarLayer end
        if db.allyHealerMarkLayer == nil then db.allyHealerMarkLayer = db.healerMarkLayer end
      end
    end
    db.schema = 7
  end

  if (db.schema or 0) < 8 then
    if db.dispelPrioritySize == nil then
      local baseSize = tonumber(db.dispelSize) or ns.defaults.dispelSize
      db.dispelPrioritySize = math.floor(baseSize * 1.4 + 0.5)
    end
    db.schema = 8
  end

  if (db.schema or 0) < 9 then
    InheritBlitzSettings(db.positions)
    db.schema = 9
  end
  if type(db.editBracket) == "number" then db.editBracket = tostring(db.editBracket) end
  if db.editBracket == "40" then db.editBracket = "15" end
  if not ns.defaults.brackets[db.editBracket] then db.editBracket = ns.defaults.editBracket end
  CopyDefaults(ns.defaults, db)
  return db
end

function ns:LoadSavedVariables()
  local root = OmniHealDB or {}
  local firstInstall = next(root) == nil
  if not root.profiles then
    local old = root
    root = { profiles = { Default = old }, current = "Default" }
  end
  if firstInstall then root.frameSetupPending = true end
  root.minimap = root.minimap or { hide = false, angle = 225 }
  root.specs = root.specs or {}
  root.playerRoles = root.playerRoles or {}
  local cutoff = time() - 90 * 86400
  for key, e in pairs(root.specs) do
    if type(e) ~= "table" or (e.t or 0) < cutoff then root.specs[key] = nil end
  end
  for key, e in pairs(root.playerRoles) do
    if type(e) ~= "table" or (e.t or 0) < cutoff then root.playerRoles[key] = nil end
  end
  root.roleProfiles = root.roleProfiles or {}
  if root.roleSwitch == nil then root.roleSwitch = false end
  if not next(root.profiles) then root.profiles.Default = {} end
  for _, profile in pairs(root.profiles) do
    ns:MigrateProfile(profile)
    -- These switches were introduced as one-time upgrades for existing profiles.
    if not profile._enemyDefMigratedV1 then
      profile.showEnemyDef, profile._enemyDefMigratedV1 = true, true
    end
    if not profile._enemyCCMigratedV1 then
      profile.showEnemyCC, profile._enemyCCMigratedV1 = true, true
    end
  end
  if not root.profiles[root.current] then root.current = next(root.profiles) end
  OmniHealDB = root
  return root
end

