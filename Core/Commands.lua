local _, ns = ...

local function ShowHelp()
  ns.Print("/oh  —  " .. ns.L("settings"))
  ns.Print("/oh setup  —  " .. ns.L("setup_reopen"))
  ns.Print("/oh preview  —  " .. ns.L("test_desc"))
  ns.Print("/oh lock, /oh unlock  —  " .. ns.L("opt_locked"))
  ns.Print("/oh reset  —  " .. ns.L("opt_reset"))
  ns.Print("/oh ally, /oh enemy, /oh auras, /oh profiles")
  ns.Print(ns.L("opt_probe") .. "  —  /oh env, /oh probe, /oh perf")
end

SLASH_OMNIHEAL1 = "/omniheal"
SLASH_OMNIHEAL2 = "/oh"
SlashCmdList.OMNIHEAL = function(message)
  local command = strlower(strtrim(message or ""))
  if command == "setup" then
    ns.Setup:Open()
  elseif command == "preview" or command == "test" then
    ns.Test:Toggle()
  elseif command == "lock" or command == "unlock" then
    local locked = command == "lock"
    if ns.Setup.active then ns.Setup:SetLocked(locked) else ns:SetLocked(locked) end
    ns.Print(locked and "Frames locked." or "Frames unlocked.")
  elseif command == "reset" then
    if ns.Setup.active then ns.Setup:Dismiss() end
    wipe(ns.db.positions)
    ns.Frames:Refresh()
    ns.Print("Positions reset.")
  elseif command == "probe" then
    ns.Probe()
  elseif command == "env" then
    ns.Environment()
  elseif command == "perf" or command:find("^perf ") then
    ns.Print(ns.Live:Stats())
  elseif command == "help" then
    ShowHelp()
  elseif ns.options.args[command] then
    ns.ToggleSettings(command)
  else
    ns.Options:Open()
  end
end
