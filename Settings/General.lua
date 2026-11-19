local _, ns = ...
local L = ns.L
local Controls = ns.SettingsControls

ns.options.args.general = {
  type = "group", order = 1, name = function() return L("page_general") end,
  args = {
    language = { type = "select", order = 0, name = function() return L("language") end, desc = function() return L("language_desc") end, values = function() return ns.LANGUAGES end, sorting = ns.LANGUAGE_ORDER, get = function() return (ns.db and ns.db.language) or "auto" end, set = function(_, value) ns.db.language = value; ns.ApplyLanguage(); if ns.RefreshSettings then ns.RefreshSettings() end end },
    reload = { type = "execute", order = 0.1, name = function() return L("reload_ui") end, func = function() ReloadUI() end },
    frames = {
      type = "group", inline = true, order = -1, name = function() return L("grp_frames") end,
      args = {
        setup = { type = "execute", order = -3, name = function() return L("setup_reopen") end, func = function() ns.Setup:Open() end },
        showAllies = Controls.FrameVisibility("ally", -2, { searchHidden = true }),
        showEnemies = Controls.FrameVisibility("enemy", -1, { searchHidden = true }),
        locked = Controls.Toggle(1, "opt_locked", "locked", "opt_locked_desc", function() ns:SetLocked(ns.db.locked) end),
        minimap = { type = "toggle", order = 2, width = "full", name = function() return L("opt_minimap") end, desc = function() return L("opt_minimap_desc") end, get = function() return not ns.global.minimap.hide end, set = function(_, value) ns.global.minimap.hide = not value; ns.MinimapButton:Update() end },
        hideOtherRaid = Controls.Toggle(3, "opt_hide_raid", "hideOtherRaid", "opt_hide_raid_desc", function() ns.Hider:Update() end),
      },
    },
    testPreview = {
      type = "group", inline = true, order = 30, name = function() return L("grp_testing") end,
      args = {
        scenario = {
          type = "select", order = 1, name = function() return L("test_scenario") end,
          desc = function() return L("test_scenario_desc") end,
          values = function() return { balanced = L("test_scenario_balanced"), dense = L("test_scenario_dense") } end,
          sorting = { "balanced", "dense" }, get = Controls.Get("testScenario"),
          set = function(_, value)
            ns.db.testScenario = value
            if ns.state == "test" then ns.Test:Rebuild() end
          end,
        },
        placement = {
          type = "select", order = 2, name = function() return L("test_placement") end,
          desc = function() return L("test_placement_desc") end,
          values = function() return {
            current = L("test_placement_current"),
            corners = L("test_placement_corners"),
            sides = L("test_placement_sides"),
          } end,
          sorting = { "current", "corners", "sides" }, get = Controls.Get("testAnchorPreset"),
          set = function(_, value)
            ns.db.testAnchorPreset = value
            if ns.state == "test" then ns.Frames:Refresh() end
          end,
        },
      },
    },
    tools = {
      type = "group", inline = true, order = 40, name = function() return L("grp_tools") end,
      args = {
        reset = { type = "execute", order = 1, name = function() return L("opt_reset") end, confirm = function() return L("opt_reset_confirm") end, func = function() wipe(ns.db.positions); Controls.RefreshFrames() end },
        probe = { type = "execute", order = 2, name = function() return L("opt_probe") end, desc = function() return L("opt_probe_desc") end, func = function() ns.Probe() end },
      },
    },
  },
}

local function InfoPage(order)
  StaticPopupDialogs["OMNIHEAL_URL"] = {
    text = "Press Ctrl+C to copy, then paste it in your browser:",
    button1 = CLOSE, hasEditBox = true, editBoxWidth = 260,
    OnShow = function(self, url)
      local box = (self.GetEditBox and self:GetEditBox()) or self.EditBox or self.editBox
      if not box then return end
      box:SetText(url); box:HighlightText(); box:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  local function ShowURL(url) StaticPopup_Show("OMNIHEAL_URL", nil, nil, url) end
  local DISCORD_URL = "https://discord.gg/lavet"
  local DONATE_URL = "https://www.donationalerts.com/r/lavet"
  return {
    type = "group", order = order, name = function() return L("page_info") end,
    args = {
      intro = { type = "description", order = 1, fontSize = "medium", name = function() return L("info_desc") end },
      header = { type = "header", order = 2, name = function() return L("info_header") end },
      discord = { type = "execute", order = 3, name = function() return L("info_discord") end, desc = function() return L("info_discord_desc") end, func = function() ShowURL(DISCORD_URL) end },
      donate = { type = "execute", order = 4, name = function() return L("info_donate") end, desc = function() return L("info_donate_desc") end, func = function() ShowURL(DONATE_URL) end },
    },
  }
end

ns.options.args.info = InfoPage(9)
