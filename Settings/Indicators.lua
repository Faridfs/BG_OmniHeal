local _, ns = ...
local L = ns.L
local Controls = ns.SettingsControls

local POSITION_ORDER = { "auto" }
for _, point in ipairs(ns.Row.AURA_ANCHOR_ORDER) do POSITION_ORDER[#POSITION_ORDER + 1] = point end
local SHAPE_ORDER = { "circle", "square", "cross" }

local function AddPlacement(args, key, order, labelKey, off, markers, withScale)
  local anchorKey, growKey = key .. "Anchor", key .. "Grow"
  local function Label(key2) return function() return labelKey and (L(labelKey) .. " " .. L(key2):lower()) or L(key2) end end
  local function IsDefault() return ns.db[anchorKey] == "auto" end
  off = off or function() return false end
  if markers then
    args[key .. "Shape"] = { type = "select", order = order, name = Label("lbl_shape"), values = function() return { circle = L("shape_circle"), square = L("shape_square"), cross = L("shape_cross") } end, sorting = SHAPE_ORDER, get = Controls.Get(key .. "Shape"), set = Controls.Set(key .. "Shape"), disabled = off }
  end
  args[anchorKey] = { type = "select", order = order + 0.1, name = Label("lbl_position"), desc = function() return L("pos_desc") end, values = function() local p = { auto = L("pos_auto") } for _, point in ipairs(ns.Row.AURA_ANCHOR_ORDER) do p[point] = ns.Row.AURA_ANCHORS[point] end return p end, sorting = POSITION_ORDER, get = Controls.Get(anchorKey), set = Controls.Set(anchorKey), disabled = off }
  if markers then
    args[growKey] = { type = "select", order = order + 0.2, name = Label("lbl_grow"), desc = function() return L("target_grow_desc") end, values = function() return { left = L("grow_left"), right = L("grow_right"), center = L("grow_center") } end, sorting = function() return (IsDefault() or ns.Row.AuraGrowsCentered(ns.db[anchorKey])) and { "center" } or { "left", "right" } end, get = function() return (IsDefault() or ns.Row.AuraGrowsCentered(ns.db[anchorKey])) and "center" or ns.db[growKey] end, set = function(_, value) if value ~= "center" then ns.db[growKey] = value; Controls.RefreshFrames() end end, disabled = function() return off() or IsDefault() or ns.Row.AuraGrowsCentered(ns.db[anchorKey]) end }
  end
  args[key .. "X"] = Controls.Range(order + 0.3, nil, Controls.Get(key .. "X"), Controls.Set(key .. "X"), -80, 80, 1, { disabled = off, name = Label("lbl_offset_x") })
  args[key .. "Y"] = Controls.Range(order + 0.4, nil, Controls.Get(key .. "Y"), Controls.Set(key .. "Y"), -40, 40, 1, { disabled = off, name = Label("lbl_offset_y") })
  if withScale ~= false then
    args[key .. "Scale"] = Controls.Range(order + 0.5, nil, Controls.Get(key .. "Scale"), Controls.Set(key .. "Scale"), 0.5, 3, 0.05, { isPercent = true, disabled = off, name = Label("lbl_size") })
  end
end

local function TargetingPage(order)
  local function IndicatorMode(team)
    local key = team .. "TargetIndicator"
    return {
      type = "select", order = 1, name = function() return L("opt_target_indicator") end,
      values = function() return { bubbles = L("ti_bubbles"), number = L("ti_number"), both = L("ti_both"), off = L("ti_off") } end,
      sorting = { "bubbles", "number", "both", "off" }, get = Controls.Get(key), set = Controls.Set(key),
    }
  end
  local function DotsOff(team)
    return function()
      local mode = ns.db[team .. "TargetIndicator"]
      return mode == "off" or mode == "number"
    end
  end
  local function NumberOff(team)
    return function()
      local mode = ns.db[team .. "TargetIndicator"]
      return mode ~= "number" and mode ~= "both"
    end
  end
  local allyTargets = {
    type = "group", inline = true, order = 1,
    name = function() return L("target_indicators_ally") end,
    args = { indicator = IndicatorMode("ally") },
  }
  AddPlacement(allyTargets.args, "allyTargetMark", 10, "label_dot", DotsOff("ally"), true)
  AddPlacement(allyTargets.args, "allyCount", 20, "label_number", NumberOff("ally"))

  local enemyTargets = {
    type = "group", inline = true, order = 2,
    name = function() return L("target_indicators_enemy") end,
    args = { indicator = IndicatorMode("enemy") },
  }
  AddPlacement(enemyTargets.args, "enemyTargetMark", 10, "label_dot", DotsOff("enemy"), true)
  AddPlacement(enemyTargets.args, "enemyCount", 20, "label_number", NumberOff("enemy"))

  local healers = {
    intro = { type = "description", order = 0, name = function() return L("healers_intro") end },
    healerTargets = Controls.Toggle(1, "opt_show", "healerTargets"),
  }
  AddPlacement(healers, "healerMark", 10, nil, function() return not ns.db.healerTargets end, true)

  return {
    type = "group", order = order, name = function() return L("page_targeting") end,
    commonArgs = {
      intro = { type = "description", order = 0, name = function() return L("targeting_intro") end },
      mine = { type = "group", inline = true, order = 10, name = function() return L("grp_my_target") end, args = { highlightTarget = Controls.Toggle(1, "opt_highlight", "highlightTarget", "opt_highlight_desc") } },
    },
    teamPages = {
      ally = {
        who = { type = "group", inline = true, order = 10, name = function() return L("grp_who") end, args = { ally = allyTargets } },
        healers = { type = "group", inline = true, order = 20, name = function() return L("grp_healers") end, args = healers },
      },
      enemy = {
        who = { type = "group", inline = true, order = 10, name = function() return L("grp_who") end, args = { enemy = enemyTargets } },
      },
    },
  }
end

local function HealthStatusPage(order)
  local function HealthText(o, team, labelKey)
    return { type = "select", order = o, name = function() return L(labelKey) end, values = function() return { none = L("hp_none"), percent = L("hp_percent"), value = L("hp_value") } end, sorting = { "none", "percent", "value" }, get = function() return ns.db[team].healthText end, set = function(_, value) ns.db[team].healthText = value; Controls.RefreshFrames() end }
  end
  local function VehicleChanged(team)
    for _, rec in pairs(ns.Roster.byKey) do
      if rec.team == team then rec.inVehicle = false end
    end
    ns.Frames:Refresh()
    if team == "ally" then ns.Live:SyncAllies() end
  end

  local function TeamStatus(team)
    local ally = team == "ally"
    local health = {
      intro = { type = "description", order = 0, name = function() return L("health_intro") end },
      healthText = HealthText(1, team, ally and "opt_ally_hp" or "opt_enemy_hp"),
    }
    AddPlacement(health, team .. "HpText", 10, nil, function() return ns.db[team].healthText == "none" end, nil, false)

    local dead = {
      intro = { type = "description", order = 0, name = function() return L("dead_intro") end },
      deadTimer = Controls.Toggle(1, "opt_dead_timer", team .. "DeadTimer", "opt_dead_timer_desc"),
    }
    AddPlacement(dead, team .. "DeadText", 10, nil, function() return not ns.db[team .. "DeadTimer"] end, nil, false)

    return {
      health = { type = "group", inline = true, order = 10, name = function() return L("grp_health") end, args = health },
      dead = { type = "group", inline = true, order = 20, name = function() return L("grp_dead") end, args = dead },
      vehicles = { type = "group", inline = true, order = 30, name = function() return L("grp_vehicles") end, args = {
        markVehicles = Controls.Toggle(1, "opt_mark_vehicles", team .. "MarkVehicles", "opt_mark_vehicles_desc", function() VehicleChanged(team) end),
      } },
      range = { type = "group", inline = true, order = 40, name = function() return L("grp_range") end, args = {
        rangeFade = Controls.Toggle(1, "opt_range_fade", team .. "RangeFade", "opt_range_fade_desc"),
        rangeAlpha = Controls.Range(2, "opt_range_alpha", Controls.Get(team .. "RangeAlpha"), Controls.Set(team .. "RangeAlpha"), 0.1, 1, 0.05, { isPercent = true, disabled = function() return not ns.db[team .. "RangeFade"] end }),
      } },
    }
  end

  return {
    type = "group", order = order, name = function() return L("page_status") end,
    teamPages = { ally = TeamStatus("ally"), enemy = TeamStatus("enemy") },
  }
end

local function TrackingPage(order)
  local function TeamCarrierArgs(team)
    local function TGet(key) return function() return ns.db[team][key] end end
    local function TSet(key) return function(_, value) ns.db[team][key] = value; Controls.RefreshFrames() end end
    return {
      intro = { type = "description", order = 0, name = function() return L("carriers_intro") end },
      carriers = Controls.Toggle(1, "opt_carriers", team .. "Carriers"),
      anchor = { type = "select", order = 2, name = function() return L("lbl_position") end, desc = function() return L("pos_desc") end, values = function() local p = { auto = L("pos_auto") } for _, point in ipairs(ns.Row.AURA_ANCHOR_ORDER) do p[point] = ns.Row.AURA_ANCHORS[point] end return p end, sorting = POSITION_ORDER, get = TGet("carrierAnchor"), set = TSet("carrierAnchor") },
      x = { type = "range", order = 3, name = function() return L("lbl_offset_x") end, min = -80, max = 80, step = 1, get = TGet("carrierX"), set = TSet("carrierX") },
      y = { type = "range", order = 4, name = function() return L("lbl_offset_y") end, min = -40, max = 40, step = 1, get = TGet("carrierY"), set = TSet("carrierY") },
      scale = { type = "range", order = 5, name = function() return L("lbl_size") end, min = 0.5, max = 3, step = 0.05, isPercent = true, get = TGet("carrierScale"), set = TSet("carrierScale") },
    }
  end

  local function CarrierPage(team)
    return {
      carriers = { type = "group", inline = true, order = 10, name = function() return L("grp_carriers") end, args = TeamCarrierArgs(team) },
    }
  end

  return {
    type = "group", order = order, name = function() return L("page_tracking") end,
    commonArgs = { intro = { type = "description", order = 1, fontSize = "medium", name = function() return L("tracking_intro") end } },
    teamPages = { ally = CarrierPage("ally"), enemy = CarrierPage("enemy") },
  }
end

local function ScannerPage(order)
  return {
    type = "group", order = order, name = function() return L("page_scanner") end,
    args = {
      intro = { type = "description", order = 1, fontSize = "medium", name = function() return L("scanner_intro") end },
      enabled = Controls.Toggle(2, "scanner_enabled", "premadeScannerEnabled", "scanner_enabled_desc", function() ns.Frames:Refresh() end),
      iconSize = Controls.Range(3, "scanner_size", Controls.Get("premadeIconSize"), Controls.Set("premadeIconSize", function() ns.Frames:Refresh() end), 10, 64, 1),
      offsetX = Controls.Range(4, "scanner_offset_x", Controls.Get("premadeOffsetX"), Controls.Set("premadeOffsetX", function() ns.Frames:Refresh() end), -50, 50, 1),
      offsetY = Controls.Range(5, "scanner_offset_y", Controls.Get("premadeOffsetY"), Controls.Set("premadeOffsetY", function() ns.Frames:Refresh() end), -50, 50, 1),
    },
  }
end

ns.options.args.targeting = TargetingPage(5)
ns.options.args.status = HealthStatusPage(6)
ns.options.args.scanner = ScannerPage(8.5)
ns.options.args.tracking = TrackingPage(8.6)
