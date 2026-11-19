local _, ns = ...
local L = ns.L
local Controls = ns.SettingsControls

local pendingCopy, pendingDelete
local function OtherProfiles() local values = {} for name in pairs(ns.global.profiles) do if name ~= ns.global.current then values[name] = name end end return values end
local function NoOthers() return next(OtherProfiles()) == nil end
local function RoleSelect(order, role, labelKey) return { type = "select", order = order, name = function() return L(labelKey) end, values = function() return ns.Profiles:Values() end, get = function() return ns.global.roleProfiles[role] or ns.global.current end, set = function(_, value) ns.global.roleProfiles[role] = value; ns.Profiles:CheckSpec() end, hidden = function() return not ns.global.roleSwitch end } end

local shareName, shareCode, shareStatus = "", "", ""

ns.options.args.profiles = {
  type = "group", order = 8, name = function() return L("page_profiles") end,
  args = {
    intro = { type = "description", order = 1, fontSize = "medium", name = function() return L("prof_intro") end },
    current = { type = "select", order = 2, name = function() return L("opt_current_profile") end, values = function() return ns.Profiles:Values() end, get = function() return ns.global.current end, set = function(_, value) ns.Profiles:Use(value) end },
    create = { type = "input", order = 3, name = function() return L("opt_new_profile") end, get = function() return "" end, set = function(_, value) local ok, err = ns.Profiles:Create(value); if ok then ns.Profiles:Use(strtrim(value)) end; return ok, err end },
    rename = { type = "input", order = 4, name = function() return L("opt_rename") end, get = function() return ns.global.current end, set = function(_, value) return ns.Profiles:Rename(value) end },
    manageHeader = { type = "header", order = 10, name = function() return L("prof_manage_header") end },
    copyFrom = { type = "select", order = 11, name = function() return L("opt_copy_from_profile") end, values = OtherProfiles, get = function() return pendingCopy end, set = function(_, value) pendingCopy = value end, hidden = NoOthers },
    copy = { type = "execute", order = 12, name = function() return L("opt_copy_btn") end, forceWhiteDisabledText = true, confirm = function() return L("opt_copy_profile_confirm", ns.global.current, tostring(pendingCopy)) end, disabled = function() return not (pendingCopy and ns.global.profiles[pendingCopy]) end, hidden = NoOthers, func = function() ns.Profiles:CopyInto(pendingCopy); pendingCopy = nil end },
    reset = { type = "execute", order = 13, name = function() return L("opt_reset_profile") end, confirm = function() return L("opt_reset_profile_confirm", ns.global.current) end, func = function() ns.Profiles:Reset() end },
    deleteWhich = { type = "select", order = 14, name = function() return L("opt_delete_profile") end, newline = true, values = OtherProfiles, get = function() return pendingDelete end, set = function(_, value) pendingDelete = value end, hidden = NoOthers },
    delete = { type = "execute", order = 15, name = function() return L("opt_delete_btn") end, forceWhiteDisabledText = true, confirm = function() return L("opt_delete_profile_confirm", tostring(pendingDelete)) end, disabled = function() return not (pendingDelete and ns.global.profiles[pendingDelete]) end, hidden = NoOthers, func = function() ns.Profiles:Delete(pendingDelete); pendingDelete = nil end },
    specHeader = { type = "header", order = 20, name = function() return L("prof_spec_header") end },
    specDesc = { type = "description", order = 21, name = function() return L("prof_spec_desc") end },
    roleSwitch = { type = "toggle", order = 22, width = "full", name = function() return L("opt_role_switch") end, get = function() return ns.global.roleSwitch end, set = function(_, value) ns.global.roleSwitch = value; ns.Profiles:CheckSpec() end },
    healer = RoleSelect(23, "HEALER", "role_healer"),
    damage = RoleSelect(24, "DAMAGER", "role_damage"),
    tank = RoleSelect(25, "TANK", "role_tank"),
    roleSet = { type = "execute", order = 26, name = function() return L("opt_role_set") end, newline = true, desc = function() return L("opt_role_set_desc") end, confirm = function() return L("opt_role_set_confirm") end, hidden = function() return ns.global.roleSwitch end, func = function() ns.Profiles:CreateRoleSet() end },
    shareHeader = { type = "header", order = 30, name = function() return L("prof_share_header") end },
    shareInfo = { type = "description", order = 31, fontSize = "medium", name = function() return L("prof_share_desc") end },
    export = { type = "execute", order = 32, width = "normal", name = function() return L("prof_export") end, func = function()
      local code, err = ns.Profiles:Export(ns.global.current)
      if not code then
        shareStatus = tostring(err or L("prof_export_error"))
        Controls.RefreshFrames()
        return
      end
      shareCode = code
      shareStatus = L("prof_export_ready")
      Controls.RefreshFrames()
    end },
    shareCode = { type = "input", order = 33, width = "full", name = function() return L("prof_code") end,
      get = function() return shareCode end,
      set = function(_, value) shareCode = value; return true end,
      onChange = function(_, value) shareCode = value end,
    },
    shareName = { type = "input", order = 34, width = "double", name = function() return L("prof_import_name") end,
      get = function() return shareName end,
      set = function(_, value) shareName = value; return true end,
      onChange = function(_, value) shareName = value end,
    },
    import = { type = "execute", order = 35, width = "normal", name = function() return L("prof_import") end, func = function()
      local ok, err = ns.Profiles:Import(shareName, shareCode)
      if not ok then
        shareStatus = tostring(err or L("prof_import_error"))
      else
        shareStatus = L("prof_import_done", strtrim(shareName))
        shareName, shareCode = "", ""
      end
      Controls.RefreshFrames()
    end },
    shareStatus = { type = "description", order = 36, fontSize = "medium", name = function() return shareStatus end, hidden = function() return shareStatus == "" end },
  },
}
