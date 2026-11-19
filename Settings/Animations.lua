local _, ns = ...
local L = ns.L
local Controls = ns.SettingsControls

local function RefreshAnimations()
  if ns.Auras then ns.Auras:RequestAnimationRefresh() end
end

local APPEAR_ANIMATION_ORDER = { "none", "fade", "flash" }

local function AuraAnimationGroup(category, order, nameKey)
  local prefix = "auraAnim" .. category
  local function ActiveEffects()
    local effects = ns.db[prefix .. "Effects"]
    if type(effects) ~= "table" then effects = {} end
    return effects
  end
  local function SetActiveEffect(_, key, value)
    local effects = ActiveEffects()
    effects[key] = value == true
    ns.db[prefix .. "Effects"] = effects
    RefreshAnimations()
  end
  local function ActiveToggle(key, labelKey, order)
    return {
      type = "toggle", order = order, width = "full",
      name = function() return L(labelKey) end,
      desc = function() return L("anim_active_effect_desc") end,
      get = function() return ActiveEffects()[key] == true end,
      set = function(_, value) SetActiveEffect(nil, key, value) end,
    }
  end
  local function EffectControls(effect, suffix, order, nameKey)
    local base = prefix .. suffix
    local controls = {
      speed = Controls.Range(1, "anim_speed", Controls.Get(base .. "Speed"), Controls.Set(base .. "Speed", RefreshAnimations), 0.35, 2.5, 0.05, {
        desc = function() return L("anim_speed_desc") end,
      }),
      strength = Controls.Range(2, "anim_strength", Controls.Get(base .. "Strength"), Controls.Set(base .. "Strength", RefreshAnimations), 0.1, 1, 0.05, {
        isPercent = true, desc = function() return L("anim_strength_desc") end,
      }),
      size = Controls.Range(3, "anim_size", Controls.Get(base .. "Size"), Controls.Set(base .. "Size", RefreshAnimations), 0.75, 2.25, 0.05, {
        desc = function() return L("anim_size_desc") end,
      }),
    }
    if effect == "borderOrbit" then
      controls.length = Controls.Range(4, "anim_dash_length", Controls.Get(base .. "Length"), Controls.Set(base .. "Length", RefreshAnimations), 0.5, 1.5, 0.25, {
        desc = function() return L("anim_dash_length_desc") end,
      })
      controls.count = Controls.Range(5, "anim_dash_count", Controls.Get(base .. "Count"), Controls.Set(base .. "Count", RefreshAnimations), 1, 4, 1, {
        desc = function() return L("anim_dash_count_desc") end,
      })
    end
    return {
      type = "group", order = order, inline = true,
      name = function() return L(nameKey) end,
      hidden = function() return not ActiveEffects()[effect] end,
      args = controls,
    }
  end
  local function ColorModeValues()
    local values = { category = L("anim_color_category") }
    values.dispel = L("anim_color_game")
    return values
  end

  local args = {
    appear = {
      type = "select", order = 1, name = function() return L("anim_on_apply") end,
      desc = function() return L("anim_on_apply_desc") end,
      values = function() return {
        none = L("anim_apply_none"), fade = L("anim_apply_fade"), flash = L("anim_apply_flash"),
      } end,
      sorting = APPEAR_ANIMATION_ORDER, get = Controls.Get(prefix .. "Appear"), set = Controls.Set(prefix .. "Appear", RefreshAnimations),
    },
    appearSpeed = Controls.Range(2, "anim_speed", Controls.Get(prefix .. "Speed"), Controls.Set(prefix .. "Speed", RefreshAnimations), 0.35, 2.5, 0.05, {
      desc = function() return L("anim_appear_speed_desc") end,
      hidden = function() return ns.db[prefix .. "Appear"] == "none" end,
    }),
    activeHeader = { type = "header", order = 3, name = function() return L("anim_active_effect") end },
    activeBorder = ActiveToggle("border", "anim_active_border", 4),
    borderSettings = EffectControls("border", "Border", 5, "anim_settings_border"),
    activeNeon = ActiveToggle("neon", "anim_active_neon", 6),
    neonSettings = EffectControls("neon", "Neon", 7, "anim_settings_neon"),
    activePulse = ActiveToggle("borderPulse", "anim_active_border_pulse", 8),
    pulseSettings = EffectControls("borderPulse", "Pulse", 9, "anim_settings_pulse"),
    activeOrbit = ActiveToggle("borderOrbit", "anim_active_border_orbit", 10),
    orbitSettings = EffectControls("borderOrbit", "Orbit", 11, "anim_settings_orbit"),
    colorMode = {
      type = "select", order = 12, name = function() return L("anim_color_mode") end,
      desc = function() return L("anim_color_mode_desc") end,
      values = ColorModeValues,
      sorting = function() return { "category", "dispel" } end,
      get = Controls.Get(prefix .. "ColorMode"), set = Controls.Set(prefix .. "ColorMode", RefreshAnimations),
    },
  }

  return {
    type = "group", inline = true, order = order, name = function() return L(nameKey) end,
    args = args,
  }
end

local function AnimationPage(order)
  local control = AuraAnimationGroup("CC", 1, "anim_group_cc")
  local debuffs = AuraAnimationGroup("Debuff", 2, "anim_group_debuffs")
  return {
    type = "group", order = order, name = function() return L("page_animation") end,
    commonArgs = {
      intro = { type = "description", order = 0, name = function() return L("anim_intro") end },
    },
    tabs = {
      control = { order = 1, name = function() return L("anim_group_cc") end, args = control.args },
      debuffs = { order = 2, name = function() return L("anim_group_debuffs") end, args = debuffs.args },
    },
  }
end

ns.options.args.animation = AnimationPage(8.8)
