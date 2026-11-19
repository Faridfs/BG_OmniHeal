local _, ns = ...
local L = ns.L
local Controls = ns.SettingsControls

local function FontsPage(order)
  local function TimerSize(key, labelKey, orderNum)
    return Controls.Range(orderNum, labelKey, Controls.Get("timerSize" .. key), function(_, v)
      ns.db["timerSize" .. key] = v
      ns.UpdateTimerFonts()
    end, 6, 30, 1)
  end
  local function TeamFonts(team)
    local ally = team == "ally"
    local headerKey = team .. "HeaderFontSize"
    local stackKey = team .. "StackSize"
    local fontArgs = {
      header = Controls.Range(1, ally and "opt_ally_header_size" or "opt_enemy_header_size", Controls.Get(headerKey), Controls.Set(headerKey, function() ns.Frames:Refresh() end), ally and 5 or 7, 30, 1),
    }
    local timerArgs = {
      desc = { type = "description", order = 0, name = function() return L("timers_desc") end },
      stackSize = Controls.Range(8, "timers_stacks", Controls.Get(stackKey), function(_, v) ns.db[stackKey] = v; ns.UpdateTimerFonts() end, 6, 30, 1),
    }
    if ally then
      timerArgs.timerSizeHeals = TimerSize("Heals", "grp_heals", 1)
      timerArgs.timerSizeExternals = TimerSize("Externals", "grp_externals", 2)
      timerArgs.timerSizeDispels = TimerSize("Dispels", "grp_dispels", 3)
      timerArgs.timerSizeAllyCC = TimerSize("AllyCC", "grp_ally_cc", 4)
    else
      timerArgs.timerSizeDefensives = TimerSize("Defensives", "grp_enemy_def", 1)
      timerArgs.timerSizeDebuffs = TimerSize("Debuffs", "grp_enemy_debuffs", 2)
      timerArgs.timerSizeEnemyCC = TimerSize("EnemyCC", "grp_enemy_cc", 3)
    end
    local textArgs = {
      hpTextScale = Controls.Range(1, "opt_hp_text_scale", Controls.Get(team .. "HpTextScale"), Controls.Set(team .. "HpTextScale"), 0.5, 2, 0.05, { isPercent = true }),
      deadTextScale = Controls.Range(2, "opt_dead_text_scale", Controls.Get(team .. "DeadTextScale"), Controls.Set(team .. "DeadTextScale"), 0.5, 2, 0.05, { isPercent = true }),
    }
    return {
      fontGroup = { type = "group", inline = true, order = 1, name = function() return L("grp_fonts") end, args = fontArgs },
      timersGroup = { type = "group", inline = true, order = 2, name = function() return L("timers_title") end, args = timerArgs },
      textGroup = { type = "group", inline = true, order = 3, name = function() return L("grp_text_sizes") end, args = textArgs },
    }
  end

  return {
    type = "group", order = order, name = function() return L("page_fonts") end,
    commonArgs = {
      fontGroup = {
        type = "group", inline = true, order = 1, name = function() return L("grp_fonts") end,
        args = {
          fontFace = {
            type = "select", order = 1, name = function() return L("opt_font_face") end,
            values = function() return ns.Theme.FONT_NAMES end,
            sorting = ns.Theme.FONT_ORDER,
            get = Controls.Get("fontFace"),
            set = Controls.Set("fontFace", function()
              ns.Frames:Refresh()
              ns.UpdateTimerFonts()
            end),
          },
        },
      },
    },
    teamPages = { ally = TeamFonts("ally"), enemy = TeamFonts("enemy") },
  }
end

local function LayersPage(order)
  local function Layer(orderNum, key, labelKey)
    return Controls.Range(orderNum, labelKey, Controls.Get(key), Controls.Set(key), 1, 10, 1, {
      desc = function() return L("opt_layer_desc") end,
    })
  end
  local ally = {
    allyAuras = { type = "group", inline = true, order = 10, name = function() return L("layers_ally_auras") end, args = {
      aura = Layer(1, "auraLayer", "layer_buffs_heals"),
      externals = Layer(2, "externalsLayer", "layer_externals"),
      dispels = Layer(3, "dispelLayer", "layer_dispels"),
      allyCC = Layer(4, "allyCCLayer", "layer_ally_cc"),
    } },
    bars = { type = "group", inline = true, order = 20, name = function() return L("layers_bars_icons") end, args = {
      health = Layer(1, "allyHealthBarLayer", "layer_health_bar"),
      mana = Layer(2, "allyManaBarLayer", "layer_mana_bar"),
      unitIcon = Layer(3, "allyUnitIconLayer", "layer_unit_icon"),
    } },
    text = { type = "group", inline = true, order = 30, name = function() return L("layers_text") end, args = {
      name = Layer(1, "allyNameLayer", "layer_name"),
      hpText = Layer(2, "allyHpTextLayer", "layer_health_text"),
      deadText = Layer(3, "allyDeadTextLayer", "layer_dead_text"),
      count = Layer(4, "allyCountLayer", "layer_count_ally"),
      carrier = Layer(5, "allyCarrierIconLayer", "layer_carrier"),
    } },
    markers = { type = "group", inline = true, order = 40, name = function() return L("layers_markers") end, args = {
      target = Layer(1, "allyTargetMarkLayer", "layer_target_marks_ally"),
      healer = Layer(2, "allyHealerMarkLayer", "layer_healer_marks"),
      vehicle = Layer(3, "allyVehicleBorderLayer", "layer_vehicle_border"),
      glow = Layer(4, "allyTargetGlowLayer", "layer_target_glow"),
    } },
  }
  local enemy = {
    enemyAuras = { type = "group", inline = true, order = 10, name = function() return L("layers_enemy_auras") end, args = {
      debuffs = Layer(1, "debuffLayer", "layer_enemy_debuffs"),
      defenses = Layer(2, "enemyDefLayer", "layer_enemy_defenses"),
      enemyCC = Layer(3, "enemyCCLayer", "layer_enemy_cc"),
    } },
    bars = { type = "group", inline = true, order = 20, name = function() return L("layers_bars_icons") end, args = {
      health = Layer(1, "enemyHealthBarLayer", "layer_health_bar"),
      unitIcon = Layer(2, "enemyUnitIconLayer", "layer_unit_icon"),
    } },
    text = { type = "group", inline = true, order = 30, name = function() return L("layers_text") end, args = {
      name = Layer(1, "enemyNameLayer", "layer_name"),
      hpText = Layer(2, "enemyHpTextLayer", "layer_health_text"),
      deadText = Layer(3, "enemyDeadTextLayer", "layer_dead_text"),
      count = Layer(4, "enemyCountLayer", "layer_count_enemy"),
      carrier = Layer(5, "enemyCarrierIconLayer", "layer_carrier"),
    } },
    markers = { type = "group", inline = true, order = 40, name = function() return L("layers_markers") end, args = {
      target = Layer(1, "enemyTargetMarkLayer", "layer_target_marks_enemy"),
      premade = Layer(2, "premadeLayer", "layer_premade"),
      vehicle = Layer(3, "enemyVehicleBorderLayer", "layer_vehicle_border"),
      glow = Layer(4, "enemyTargetGlowLayer", "layer_target_glow"),
    } },
  }
  return {
    type = "group", order = order, name = function() return L("page_layers") end,
    commonArgs = {
      intro = { type = "description", order = 0, name = function() return L("layers_intro") end },
    },
    teamPages = { ally = ally, enemy = enemy },
  }
end

ns.options.args.fonts = FontsPage(3.5)
ns.options.args.layers = LayersPage(8.7)
