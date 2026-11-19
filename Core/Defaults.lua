local _, ns = ...

ns.BRACKETS = { "8", "10", "15" }
ns.BRACKET_NAMES = { ["8"] = "Blitz (8)", ["10"] = "Rated BG (10)", ["15"] = "Random BG (up to 15)" }

local function CopyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(v, dst[k])
    elseif dst[k] == nil then dst[k] = v end
  end
end
ns.CopyDefaults = CopyDefaults

ns.LIMITS = { width = { 40, 600 }, height = { 10, 120 } }
ns.LAYOUT_KEYS = { "scale", "width", "height", "spacing", "columns", "columnSpacing", "padX", "padY", "growUp" }

ns.defaults = {
  -- General and preview
  schema = 9, language = "auto", theme = "auto", editBracket = "10",
  locked = false, showAllies = true, showEnemies = true, showSelf = true, hideOtherRaid = false,
  testScenario = "balanced", testAnchorPreset = "current",

  -- Healing auras on allies
  myAuras = true, auraFilter = "healing", auraFilterMode = "standard",
  auraMax = 3, auraSize = 12, auraSpacing = 2, auraLayer = 2, auraTimers = true,
  auraAnchor = "RIGHT", auraGrow = "left", auraOffsetX = 0, auraOffsetY = 0,

  -- Ally defensives and dispels
  showExternals = true, saveFilter = "custom",
  externalsMax = 3, externalsSize = 18, externalsSpacing = 2, externalsLayer = 1, externalsTimers = true,
  externalsAnchor = "TOPLEFT", externalsGrow = "right", externalsOffsetX = 0, externalsOffsetY = 0,
  showDispels = true, showDispelBorder = true, largePriorityDebuffs = false,
  dispelMax = 4, dispelSize = 14, dispelPrioritySize = 25, dispelSpacing = 2, dispelLayer = 3, dispelTimers = true,
  dispelAnchor = "CENTER", dispelGrow = "right", dispelOffsetX = 0, dispelOffsetY = 0,
  dispelTypeMagic = true, dispelTypeCurse = true, dispelTypeDisease = true, dispelTypePoison = true, dispelTypeOther = true,

  -- Crowd control
  showAllyCC = true, allyCCMax = 3, allyCCSize = 17, allyCCSpacing = 2, allyCCLayer = 4, allyCCTimers = true,
  allyCCAnchor = "LEFT", allyCCGrow = "right", allyCCOffsetX = 0, allyCCOffsetY = 0,
  showEnemyCC = true, enemyCCMax = 2, enemyCCSize = 22, enemyCCSpacing = 2, enemyCCLayer = 4, enemyCCTimers = true,
  enemyCCAnchor = "CENTER", enemyCCGrow = "right", enemyCCOffsetX = 0, enemyCCOffsetY = 0,

  -- Debuffs and defensives on enemies
  myDebuffs = false, debuffFilterMode = "custom", debuffMax = 4, debuffSize = 12, debuffSpacing = 2, debuffLayer = 2, debuffTimers = true,
  debuffAnchor = "RIGHT", debuffGrow = "left", debuffOffsetX = 0, debuffOffsetY = 0,
  showEnemyDef = true, enemyDefMax = 4, enemyDefSize = 18, enemyDefSpacing = 2, enemyDefLayer = 3, enemyDefTimers = true,
  enemyDefAnchor = "LEFT", enemyDefGrow = "right", enemyDefOffsetX = 0, enemyDefOffsetY = 0,

  -- Target and healer indicators
  highlightTarget = true, targetIndicator = "both", healerTargets = false,
  targetMarkShape = "square", targetMarkAnchor = "auto", targetMarkGrow = "right", targetMarkX = -9, targetMarkY = 27, targetMarkScale = 0.5,
  healerMarkShape = "cross", healerMarkAnchor = "auto", healerMarkGrow = "right", healerMarkX = 0, healerMarkY = 0, healerMarkScale = 1,
  countAnchor = "auto", countX = 4, countY = -9, countScale = 1.95,

  -- Player status and objectives
  rangeFade = true, rangeAlpha = 0.4, deadTimer = false, markVehicles = false, carriers = true,
  hpTextAnchor = "TOP", hpTextX = 7, hpTextY = -11, hpTextScale = 0.5,
  deadTextAnchor = "auto", deadTextX = 0, deadTextY = 0, deadTextScale = 1,
  carrierAnchor = "auto", carrierX = -4, carrierY = 0, carrierScale = 1,
  premadeScannerEnabled = true, premadeIconSize = 24, premadeOffsetX = 0, premadeOffsetY = 0,

  -- Text and draw order
  fontFace = "FRIZQT", allyHeaderFontSize = 7, enemyHeaderFontSize = 14, stackSize = 12,
  timerSizeHeals = 14, timerSizeExternals = 14, timerSizeDispels = 14, timerSizeAllyCC = 16,
  timerSizeDebuffs = 14, timerSizeEnemyCC = 16, timerSizeDefensives = 14,
  healthBarLayer = 1, manaBarLayer = 1, unitIconLayer = 1, nameLayer = 3, hpTextLayer = 3, deadTextLayer = 3,
  countLayer = 3, carrierIconLayer = 3, targetMarkLayer = 5, healerMarkLayer = 5, premadeLayer = 5, vehicleBorderLayer = 4, targetGlowLayer = 4,

  -- Additional fields retained for saved profile compatibility
  showAllyTracked = true, allyDebuffMax = 4, allyDebuffSize = 11, allyDebuffTimers = false,
  allyDebuffAnchor = "BOTTOMLEFT", allyDebuffGrow = "right", allyDebuffOffsetX = -1, allyDebuffOffsetY = 0,
  watchSpacing = 2, watchAnchor = "BOTTOMLEFT", watchGrow = "right", watchOffsetX = 0, watchOffsetY = 0,
  showTrinketTracker = true, trinketSize = 32, trinketAnchor = "CENTER", trinketGrow = "right", trinketOffsetX = 0, trinketOffsetY = 0, trinketTimers = true, timerSizeTrinket = 18,

  auraAnimationVersion = 11,
}

-- Each category owns its effect selections and tuning.
for _, category in ipairs({ "Debuff", "CC" }) do
  local prefix = "auraAnim" .. category
  ns.defaults[prefix .. "Appear"] = "none"
  ns.defaults[prefix .. "ColorMode"] = "dispel"
  ns.defaults[prefix .. "Effects"] = { border = true, neon = false, borderPulse = false, borderOrbit = false }
  ns.defaults[prefix .. "Speed"] = 1
  ns.defaults[prefix .. "Strength"] = 0.65
  ns.defaults[prefix .. "Size"] = 1.35
  for _, effect in ipairs({ "Border", "Neon", "Pulse", "Orbit" }) do
    for _, field in ipairs({ "Speed", "Strength", "Size" }) do
      ns.defaults[prefix .. effect .. field] = ns.defaults[prefix .. field]
    end
  end
  ns.defaults[prefix .. "OrbitLength"] = 1
  ns.defaults[prefix .. "OrbitCount"] = 2
end

ns.defaults.ally = {
  nameOffsetY = 2,
  fontSize = 8,
  showRealm = false,
  roleMarker = "icon",
  barTexture = "flat",
  iconType = "none",
  panelAlpha = 0,
  classColorBars = true,
  bgAlpha = 0.6,
  style = "compact",
  nameOffsetX = -3,
  showHealerMana = false,
  sortBy = "healer",
  manaHeight = 4,
  healthText = "value",
  carrierAnchor = "auto", carrierX = -4, carrierY = 0, carrierScale = 1,
}

ns.defaults.enemy = {
  nameOffsetY = 0,
  fontSize = 11,
  showRealm = false,
  roleMarker = "icon",
  barTexture = "flat",
  iconType = "none",
  panelAlpha = 0.6,
  classColorBars = true,
  bgAlpha = 0.6,
  style = "compact",
  nameOffsetX = 0,
  showHealerMana = true,
  sortBy = "healer",
  manaHeight = 4,
  healthText = "value",
  carrierAnchor = "auto", carrierX = 0, carrierY = 0, carrierScale = 1,
}

ns.defaults.brackets = {
  ["10"] = {
    ally = { scale = 2, width = 82, height = 38, columns = 5, growUp = true, spacing = 0, columnSpacing = 0, padX = 0, padY = 0 },
    enemy = { scale = 1, width = 155, height = 35, columns = 1, growUp = false, spacing = 0, columnSpacing = 0, padX = 0, padY = 0 },
  },
  ["15"] = {
    ally = { scale = 2, width = 79, height = 35, columns = 5, growUp = true, spacing = 0, columnSpacing = 0, padX = 0, padY = 0 },
    enemy = { scale = 1.5, width = 125, height = 24, columns = 1, growUp = false, spacing = 0, columnSpacing = 4, padX = 0, padY = 0 },
  },
}

ns.defaults.positions = {
    ["10"] = {
        ally = { "CENTER", "CENTER", -61.13034820556641, -73.43440246582031 },
        enemy = { "RIGHT", "RIGHT", -280.5077514648438, 54.61073684692383 },
    },
    ["15"] = {
        ally = { "CENTER", "CENTER", -54.39821624755859, -94.66677856445312 },
        enemy = { "TOPLEFT", "BOTTOMLEFT", 975.333251953125, 552 },
    },
}

-- Blitz starts with the former shared layout and can be edited independently.
ns.defaults.brackets["8"] = {}
ns.defaults.positions["8"] = {}
CopyDefaults(ns.defaults.brackets["10"], ns.defaults.brackets["8"])
CopyDefaults(ns.defaults.positions["10"], ns.defaults.positions["8"])

-- Keep the shipped defaults consistent while each team stores its own indicators.
for _, team in ipairs({ "ally", "enemy" }) do
    ns.defaults[team .. "TargetIndicator"] = ns.defaults.targetIndicator
    for _, suffix in ipairs({ "Shape", "Anchor", "Grow", "X", "Y", "Scale" }) do
        ns.defaults[team .. "TargetMark" .. suffix] = ns.defaults["targetMark" .. suffix]
    end
    ns.defaults[team .. "TargetMarkLayer"] = ns.defaults.targetMarkLayer
    for _, suffix in ipairs({ "Anchor", "X", "Y", "Scale" }) do
        ns.defaults[team .. "Count" .. suffix] = ns.defaults["count" .. suffix]
    end
    ns.defaults[team .. "CountLayer"] = ns.defaults.countLayer

    for _, field in ipairs({
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
    }) do
        ns.defaults[team .. field[1]] = ns.defaults[field[2]]
    end
    if team == "ally" then
        ns.defaults.allyManaBarLayer = ns.defaults.manaBarLayer
        ns.defaults.allyHealerMarkLayer = ns.defaults.healerMarkLayer
    end
end
