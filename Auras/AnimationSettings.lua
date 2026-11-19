local _, ns = ...
local Row = ns.Row
local Auras = ns.Auras

local ANIMATION_COLORS = {
  Debuff = { 0.2, 0.6, 1 },
  CC = { 1, 0.1, 0.1 },
}
local ANIMATION_CATEGORIES = { "Debuff", "CC" }
local animationButtons = setmetatable({}, { __mode = "k" })
local animationRefreshQueued = false
local lastAnimationSettingsKey

local function AnimationOptions(category)
  local prefix = "auraAnim" .. category
  local defaultColorMode = "dispel"
  local colorMode = ns.db[prefix .. "ColorMode"] or defaultColorMode
  if colorMode ~= "category" and colorMode ~= "dispel" then
    colorMode = defaultColorMode
  end
  local fallback = ANIMATION_COLORS[category] or ANIMATION_COLORS.Debuff
  local r, g, b = fallback[1], fallback[2], fallback[3]

  local appear = ns.db[prefix .. "Appear"] or "none"
  if appear == "pop" then appear = "fade" end
  if appear ~= "none" and appear ~= "fade" and appear ~= "flash" then appear = "none" end

  local savedEffects = ns.db[prefix .. "Effects"]
  if type(savedEffects) ~= "table" then savedEffects = {} end
  local active = {
    border = savedEffects.border == true,
    neon = savedEffects.neon == true,
    borderPulse = savedEffects.borderPulse == true,
    borderOrbit = savedEffects.borderOrbit == true,
  }

  local effectSettings = {}
  for effect, suffix in pairs({ border = "Border", neon = "Neon", borderPulse = "Pulse", borderOrbit = "Orbit" }) do
    effectSettings[effect] = {
      speed = ns.db[prefix .. suffix .. "Speed"] or 1,
      strength = ns.db[prefix .. suffix .. "Strength"] or 0.65,
      size = ns.db[prefix .. suffix .. "Size"] or 1.35,
      length = ns.db[prefix .. suffix .. "Length"] or 1,
      count = ns.db[prefix .. suffix .. "Count"] or 2,
    }
  end

  return {
    category = category,
    appear = appear,
    appearSpeed = ns.db[prefix .. "Speed"] or 1,
    active = active,
    effects = effectSettings,
    colorMode = colorMode,
    r = r, g = g, b = b,
  }
end

function Auras.ApplyButtonAnimation(btn, category, auraColor, spellID)
  if not btn then return end
  if not category then
    animationButtons[btn] = nil
    btn._rfaAnimationSpellID = nil
    Row.ClearAuraAnimation(btn)
    return
  end
  if auraColor ~= nil then btn._rfaAuraColor = auraColor end
  if spellID ~= nil then btn._rfaAnimationSpellID = spellID end
  auraColor = auraColor or btn._rfaAuraColor
  local settings = AnimationOptions(category)
  animationButtons[btn] = category
  ns.Safe("aura animation", Row.ApplyAuraAnimation, btn, settings, auraColor)
end

local function AnimationSettingsKey()
  local parts = {}
  for _, category in ipairs(ANIMATION_CATEGORIES) do
    local s = AnimationOptions(category)
    local values = {
      tostring(s.appear), tostring(s.active.border), tostring(s.active.neon), tostring(s.active.borderPulse),
      tostring(s.active.borderOrbit), tostring(s.colorMode), string.format("%.3f", s.appearSpeed),
      string.format("%.3f", s.r), string.format("%.3f", s.g), string.format("%.3f", s.b),
    }
    for _, effect in ipairs({ "border", "neon", "borderPulse", "borderOrbit" }) do
      local settings = s.effects[effect]
      values[#values + 1] = string.format("%.3f", settings.speed)
      values[#values + 1] = string.format("%.3f", settings.strength)
      values[#values + 1] = string.format("%.3f", settings.size)
      values[#values + 1] = string.format("%.3f", settings.length)
      values[#values + 1] = tostring(settings.count)
    end
    parts[#parts + 1] = table.concat(values, ":")
  end
  return table.concat(parts, "|")
end

function Auras:RefreshAnimationSettings()
  local key = AnimationSettingsKey()
  if key == lastAnimationSettingsKey then return end
  if InCombatLockdown() then
    ns:AfterCombat("aura-animation-settings", function() self:RefreshAnimationSettings() end)
    return
  end
  local complete = true
  for btn, category in pairs(animationButtons) do
    local accessible = not btn.CanBeAccessedInContext or btn:CanBeAccessedInContext()
    if accessible then
      Auras.ApplyButtonAnimation(btn, category, btn._rfaAuraColor)
      local isShown = btn:IsShown()
      if ns.IsSecret(isShown) then isShown = true end
      Row.SetAuraAnimationVisible(btn, isShown)
    else
      complete = false
    end
  end
  if complete then lastAnimationSettingsKey = key end
end

function Auras:RequestAnimationRefresh()
  if animationRefreshQueued then return end
  animationRefreshQueued = true
  C_Timer.After(0, function()
    animationRefreshQueued = false
    Auras:RefreshAnimationSettings()
  end)
end
