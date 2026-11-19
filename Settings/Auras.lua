local _, ns = ...
local L = ns.L
local Controls = ns.SettingsControls

local IS_RETAIL = WOW_PROJECT_ID ~= nil and WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

local function IconPlacement(prefix, off)
  local anchorKey, growKey = prefix .. "Anchor", prefix .. "Grow"
  return {
    type = "select", order = 6, name = function() return L("opt_position") end, desc = function() return L("opt_position_desc") end,
    values = function() return ns.Row.AURA_ANCHORS end, sorting = ns.Row.AURA_ANCHOR_ORDER, get = Controls.Get(anchorKey), set = Controls.Set(anchorKey), disabled = off,
  }, {
    type = "select", order = 7, name = function() return L("opt_grow_dir") end, desc = function() return L("opt_grow_dir_desc") end,
    values = function() return { left = L("grow_left"), right = L("grow_right"), center = L("grow_center") } end,
    sorting = function() return ns.Row.AuraGrowsCentered(ns.db[anchorKey]) and { "center" } or { "left", "right" } end,
    get = function() return ns.Row.AuraGrowsCentered(ns.db[anchorKey]) and "center" or ns.db[growKey] end,
    set = function(_, value) if value ~= "center" then ns.db[growKey] = value; ns.Frames:Refresh() end end,
    disabled = function() return off() or ns.Row.AuraGrowsCentered(ns.db[anchorKey]) end,
  }
end

local function ResyncAllies()
  ns.Frames:Refresh()
  ns.Live:SyncAllies()
end

local function AurasPage(order)
  local function AurasOff() return not ns.db.myAuras end
  local function DispelsOff() return not ns.db.showDispels end
  local function DebuffsOff() return not ns.db.myDebuffs end
  local function ExternalsOff() return not ns.db.showExternals end

  local healAnchor, healGrow = IconPlacement("aura", AurasOff)
  local dispelAnchor, dispelGrow = IconPlacement("dispel", DispelsOff)
  local debuffAnchor, debuffGrow = IconPlacement("debuff", DebuffsOff)
  local externalAnchor, externalGrow = IconPlacement("externals", ExternalsOff)

  local function RefreshAuraSize(key, value)
    ns.db[key] = value
    ns.Frames:Refresh()
    for _, rec in pairs(ns.Roster.byKey) do
      if rec.row then ns.Auras:Update(rec) end
    end
  end

  local function Common(prefix, off, anchor, grow, maxIcons)
    local args = {
      [prefix .. "Max"] = Controls.Range(3, "opt_max_icons", Controls.Get(prefix .. "Max"), Controls.Set(prefix .. "Max"), 1, maxIcons, 1, { disabled = off }),
      [prefix .. "Size"] = Controls.Range(4, "opt_icon_size", Controls.Get(prefix .. "Size"), function(_, value)
        RefreshAuraSize(prefix .. "Size", value)
      end, 8, 50, 1, { disabled = off }),
      [prefix .. "Spacing"] = Controls.Range(4.5, "opt_icon_spacing", Controls.Get(prefix .. "Spacing"), Controls.Set(prefix .. "Spacing"), 0, 10, 1, {
        desc = function() return L("opt_icon_spacing_desc") end, disabled = off,
      }),
      [prefix .. "Timers"] = Controls.Toggle(5, "opt_countdown", prefix .. "Timers", "opt_countdown_desc", nil, { disabled = off }),
      [prefix .. "Anchor"] = anchor,
      [prefix .. "Grow"] = grow,
      [prefix .. "OffsetX"] = Controls.Range(8, "opt_offset_x", Controls.Get(prefix .. "OffsetX"), Controls.Set(prefix .. "OffsetX"), -40, 40, 1, { disabled = off }),
      [prefix .. "OffsetY"] = Controls.Range(9, "opt_offset_y", Controls.Get(prefix .. "OffsetY"), Controls.Set(prefix .. "OffsetY"), -40, 40, 1, { disabled = off }),
    }
    if IS_RETAIL and prefix == "dispel" then
      args.dispelPrioritySize = Controls.Range(4.25, "opt_priority_icon_size", Controls.Get("dispelPrioritySize"), function(_, value)
        RefreshAuraSize("dispelPrioritySize", value)
      end, 8, 80, 1, {
        desc = function() return L("opt_priority_icon_size_desc") end,
        disabled = function() return off() or not ns.db.largePriorityDebuffs end,
      })
    end
    return args
  end

  local heals = Common("aura", AurasOff, healAnchor, healGrow, 12)
  heals.intro = { type = "description", order = 0, name = function() return L("auras_heals_intro") end }
  heals.myAuras = Controls.Toggle(1, "opt_show", "myAuras", nil, ResyncAllies)
  heals.auraFilter = { type = "select", order = 2, name = function() return L("opt_aura_filter") end, desc = function() return L("opt_aura_filter_desc") end, values = function() return { healing = L("afilter_healing"), all = L("afilter_all") } end, sorting = { "healing", "all" }, get = Controls.Get("auraFilter"), set = Controls.Set("auraFilter"), disabled = AurasOff }

  local externals = Common("externals", ExternalsOff, externalAnchor, externalGrow, 12)
  externals.intro = { type = "description", order = 0, name = function() return L("auras_externals_intro") end }
  externals.showExternals = Controls.Toggle(1, "opt_show", "showExternals", nil, ResyncAllies)
  externals.saveFilter = {
    type = "select", order = 2, name = function() return L("opt_save_filter") end, desc = function() return L("opt_save_filter_desc") end,
    values = function() return { custom = L("save_custom"), blizzard = L("save_blizzard") } end,
    sorting = { "custom", "blizzard" },
    get = Controls.Get("saveFilter"),
    set = Controls.Set("saveFilter"),
  }

  local dispels = Common("dispel", DispelsOff, dispelAnchor, dispelGrow, 12)
  dispels.intro = { type = "description", order = 0, name = function() return L("auras_dispels_intro") end }
  dispels.showDispels = Controls.Toggle(1, "opt_show", "showDispels", nil, ResyncAllies)
  dispels.dispelFrameBorder = Controls.Toggle(1.05, "dispel_frame_border", "showDispelBorder", "dispel_frame_border_desc", ResyncAllies, { disabled = DispelsOff })
  dispels.typeHeader = { type = "header", order = 1.1, name = function() return L("dispel_types_header") end }
  dispels.typeMagic = Controls.Toggle(1.2, "dispel_type_magic", "dispelTypeMagic", nil, ResyncAllies, { width = "normal", disabled = DispelsOff })
  dispels.typePoison = Controls.Toggle(1.3, "dispel_type_poison", "dispelTypePoison", nil, ResyncAllies, { width = "normal", disabled = DispelsOff })
  dispels.typeCurse = Controls.Toggle(1.4, "dispel_type_curse", "dispelTypeCurse", nil, ResyncAllies, { width = "normal", disabled = DispelsOff })
  dispels.typeDisease = Controls.Toggle(1.5, "dispel_type_disease", "dispelTypeDisease", nil, ResyncAllies, { width = "normal", disabled = DispelsOff })
  dispels.typeOther = Controls.Toggle(1.6, "dispel_type_other", "dispelTypeOther", "dispel_type_other_desc", ResyncAllies, { width = "normal", disabled = DispelsOff })

  local function NoContainers() return not (AuraContainerSortMethod ~= nil or (C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer"))) end
  local function ContainerGroup(prefix, onKey, introKey)
    local function Off() return not ns.db[onKey] or NoContainers() end
    local anchor, grow = IconPlacement(prefix, Off)
    local args = Common(prefix, Off, anchor, grow, 12)
    args.intro = { type = "description", order = 0, name = function() return L(introKey) end }
    args[onKey] = Controls.Toggle(1, "opt_show", onKey, "msg_no_containers", nil, { disabled = NoContainers })
    return args
  end

  local allyCC = ContainerGroup("allyCC", "showAllyCC", "auras_ally_cc_intro")

  local debuffs = Common("debuff", DebuffsOff, debuffAnchor, debuffGrow, 12)
  debuffs.intro = { type = "description", order = 0, name = function() return L("auras_debuffs_intro") end }
  debuffs.myDebuffs = Controls.Toggle(1, "opt_show", "myDebuffs")

  local enemyCC = ContainerGroup("enemyCC", "showEnemyCC", "auras_enemy_cc_intro")
  local enemyDef = ContainerGroup("enemyDef", "showEnemyDef", "auras_enemy_def_intro")

  return {
    type = "group", order = order, name = function() return L("page_auras") end,
    commonArgs = IS_RETAIL and {
      largePriorityDebuffs = Controls.Toggle(1, "opt_priority_debuffs", "largePriorityDebuffs", "opt_priority_debuffs_desc"),
    } or nil,
    teamPages = {
      ally = {
        heals = { type = "group", inline = true, order = 10, name = function() return L("grp_heals") end, args = heals },
        externals = { type = "group", inline = true, order = 15, name = function() return L("grp_externals") end, args = externals },
        dispels = { type = "group", inline = true, order = 20, name = function() return L("grp_dispels") end, args = dispels },
        allyCC = { type = "group", inline = true, order = 25, name = function() return L("grp_ally_cc") end, args = allyCC },
      },
      enemy = {
        debuffs = { type = "group", inline = true, order = 10, name = function() return L("grp_enemy_debuffs") end, args = debuffs },
        enemyCC = { type = "group", inline = true, order = 20, name = function() return L("grp_enemy_cc") end, args = enemyCC },
        enemyDef = { type = "group", inline = true, order = 30, name = function() return L("grp_enemy_def") end, args = enemyDef },
      },
    },
  }
end

ns.options.args.auras = AurasPage(4)
