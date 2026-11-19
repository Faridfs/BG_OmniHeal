local _, ns = ...
local L = ns.L
local Controls = ns.SettingsControls

local function Resort() ns.Roster:Resort() end

local function BracketSelect(order)
  return {
    type = "select", order = order,
    name = function() return L("opt_bracket") end,
    desc = function() return L("opt_bracket_desc") end,
    values = function() return ns.BRACKET_NAMES end,
    sorting = ns.BRACKETS,
    get = Controls.Get("editBracket"),
    set = function(_, value)
      ns.db.editBracket = value
      if ns.state == "test" then ns.Test:Rebuild() else Controls.RefreshFrames() end
    end,
  }
end

local SORT_ORDER = { "healer", "tank", "damage", "class", "name" }
local function SortValues()
  return { healer = L("sort_healer"), tank = L("sort_tank"), damage = L("sort_damage"), class = L("sort_class"), name = L("sort_name") }
end

local function TeamPage(team, order, nameKey)
  local other = team == "enemy" and "ally" or "enemy"
  local function TGet(key) return function() return ns.db[team][key] end end
  local function TSet(key, after) return function(_, value) ns.db[team][key] = value; (after or Controls.RefreshFrames)() end end
  local function LGet(key) return function() return ns:LayoutFor(team, ns.db.editBracket)[key] end end
  local function LSet(key) return function(_, value) ns:LayoutFor(team, ns.db.editBracket)[key] = value; Controls.RefreshFrames() end end
  local function TToggle(o, labelKey, key, descKey, extra)
    return Controls.With({ type = "toggle", order = o, name = function() return L(labelKey) end, desc = descKey and function() return L(descKey) end or nil, width = "full", get = TGet(key), set = TSet(key) }, extra)
  end
  local function LRange(o, labelKey, key, min, max, step, extra) return Controls.Range(o, labelKey, LGet(key), LSet(key), min, max, step, extra) end
  local function StyleIs(...)
    local styles = { ... }
    return function()
      for _, s in ipairs(styles) do if ns.db[team].style == s then return true end end
      return false
    end
  end

  local layoutArgs = {
    scale = LRange(1, "opt_scale", "scale", 0.5, 2, 0.05, { isPercent = true }),
    width = LRange(2, "opt_width", "width", ns.LIMITS.width[1], ns.LIMITS.width[2], 5),
    height = LRange(3, "opt_height", "height", ns.LIMITS.height[1], ns.LIMITS.height[2], 1),
    columns = LRange(4, "opt_columns", "columns", 1, 8, 1, { desc = function() return L("opt_columns_desc") end }),
    spacing = LRange(5, "opt_spacing", "spacing", 0, 10, 1),
    columnSpacing = LRange(6, "opt_column_spacing", "columnSpacing", 0, 30, 1, { disabled = function() return ns:LayoutFor(team, ns.db.editBracket).columns <= 1 end }),
    padX = LRange(7, "opt_padx", "padX", 0, 20, 1, { desc = function() return L("opt_padx_desc") end }),
    padY = LRange(8, "opt_pady", "padY", 0, 20, 1, { desc = function() return L("opt_pady_desc") end }),
    growUp = { type = "toggle", order = 9, name = function() return L("opt_growup") end, desc = function() return L("opt_growup_desc") end, width = "full", get = LGet("growUp"), set = LSet("growUp") },
  }

  for i, b in ipairs(ns.BRACKETS) do
    layoutArgs["copy" .. b] = {
      type = "execute",
      order = 10 + i,
      name = function() return L("opt_copy_from", ns.BRACKET_NAMES[b]) end,
      hidden = function() return ns.db.editBracket == b end,
      confirm = function() return L("opt_copy_from_confirm", L("page_" .. team), ns.BRACKET_NAMES[b]) end,
      func = function()
        local src, dst = ns:LayoutFor(team, b), ns:LayoutFor(team, ns.db.editBracket)
        for key, value in pairs(src) do dst[key] = value end
        Controls.RefreshFrames()
      end,
      width = "full",
      newline = true,
    }
  end

  local args = {
    show = Controls.FrameVisibility(team, 1),
    bracket = BracketSelect(2),
    layout = { type = "group", inline = true, order = 10, name = function() return L("layout_for", ns.BRACKET_NAMES[ns.db.editBracket] or "") end, args = layoutArgs },
    look = {
      type = "group", inline = true, order = 20, name = function() return L("grp_look") end,
      args = {
        style = { type = "select", order = 1, name = function() return L("opt_style") end, desc = function() return L("opt_style_desc") end, values = function() return ns.Row.STYLES end, sorting = ns.Row.STYLE_ORDER, get = TGet("style"), set = TSet("style") },
        barTexture = { type = "select", order = 2, name = function() return L("opt_bar_texture") end, values = function() return ns.Frames.BAR_TEXTURE_NAMES end, sorting = { "blizzard", "flat", "raid" }, get = TGet("barTexture"), set = TSet("barTexture"), disabled = StyleIs("minimal") },
        classColorBars = TToggle(3, "opt_class_color", "classColorBars", "opt_class_color_desc", nil, { disabled = StyleIs("minimal") }),
        panelAlpha = Controls.Range(4, "opt_panel_alpha", TGet("panelAlpha"), TSet("panelAlpha"), 0, 1, 0.05, { isPercent = true, desc = function() return L("opt_panel_alpha_desc") end }),
        bgAlpha = Controls.Range(5, "opt_bg_alpha", TGet("bgAlpha"), TSet("bgAlpha"), 0, 1, 0.05, { isPercent = true, desc = function() return L("opt_bg_alpha_desc") end, disabled = function() return not StyleIs("cards")() end }),
      },
    },
    text = {
      type = "group", inline = true, order = 30, name = function() return L("grp_name_icons") end,
      args = {
        roleMarker = { type = "select", order = 1, name = function() return L("opt_role_marker") end, desc = function() return L("opt_role_marker_desc") end, values = function() return ns.Row.ROLE_MARKERS end, sorting = ns.Row.ROLE_MARKER_ORDER, get = TGet("roleMarker"), set = TSet("roleMarker") },
        iconType = { type = "select", order = 2, name = function() return L("opt_icon_type") end, desc = function() return L("opt_icon_type_desc") end, values = function() return { spec = L("itype_spec"), class = L("itype_class"), none = L("itype_none") } end, sorting = { "spec", "class", "none" }, get = TGet("iconType"), set = TSet("iconType"), disabled = StyleIs("minimal") },
        showRealm = TToggle(3, "opt_show_realm", "showRealm", "opt_show_realm_desc"),
        fontSize = Controls.Range(4, "opt_font_size", TGet("fontSize"), TSet("fontSize"), 8, 18, 1),
        nameOffsetX = Controls.Range(5, "opt_name_x", TGet("nameOffsetX"), TSet("nameOffsetX"), -30, 30, 1, { desc = function() return L("opt_name_x_desc") end }),
        nameOffsetY = Controls.Range(6, "opt_name_y", TGet("nameOffsetY"), TSet("nameOffsetY"), -20, 20, 1, { desc = function() return L("opt_name_y_desc") end }),
      },
    },
    sorting = {
      type = "group", inline = true, order = 40, name = function() return L("grp_sorting") end,
      args = { sortBy = { type = "select", order = 1, name = function() return L("opt_sort_by") end, desc = function() return L("opt_sort_by_desc") end, values = SortValues, sorting = SORT_ORDER, get = TGet("sortBy"), set = TSet("sortBy", Resort) } },
    },
    copyHeader = { type = "header", order = 50, name = function() return L("grp_copy") end },
    copy = {
      type = "execute", order = 51, name = function() return L(team == "enemy" and "opt_copy_ally" or "opt_copy_enemy") end, desc = function() return L("opt_copy_desc") end,
      confirm = function() return L("opt_copy_confirm", other == "enemy" and L("opt_show_enemy") or L("opt_show_ally")) end,
      func = function()
        for key, value in pairs(ns.db[other]) do ns.db[team][key] = value end
        local src, dst = ns:LayoutFor(other, ns.db.editBracket), ns:LayoutFor(team, ns.db.editBracket)
        for key, value in pairs(src) do dst[key] = value end
        Resort()
      end,
    },
  }
  if team == "ally" then
    args.sorting.args.showSelf = Controls.Toggle(2, "opt_include_self", "showSelf", nil, Resort)
    args.mana = {
      type = "group", inline = true, order = 45, name = function() return L("grp_mana") end,
      args = {
        showHealerMana = TToggle(1, "opt_mana", "showHealerMana", "opt_mana_desc", { set = function(_, value) ns.db.ally.showHealerMana = value; ns.Frames:Refresh(); ns.Live:SyncAllies() end }),
        manaHeight = Controls.Range(2, "opt_mana_height", TGet("manaHeight"), TSet("manaHeight"), 2, 10, 1, { disabled = function() return not ns.db.ally.showHealerMana end }),
      },
    }
    args.clicks = { type = "description", order = 48, name = function() return L("ally_clicks_hint") end }
  end
  return { type = "group", order = order, name = function() return L(nameKey) end, args = args }
end

ns.options.args.enemy = TeamPage("enemy", 2, "page_enemy")
ns.options.args.ally = TeamPage("ally", 3, "page_ally")
