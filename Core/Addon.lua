local ADDON, ns = ...

local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
ns.version = GetMetadata(ADDON, "Version")

function ns.ScoreInfo(i)
  if C_PvP and C_PvP.GetScoreInfo then return C_PvP.GetScoreInfo(i) end
  if not GetBattlefieldScore then return nil end
  local name, _, _, _, _, faction, _, race, _, classToken = GetBattlefieldScore(i)
  if not name then return nil end
  return { name = name, faction = faction, raceName = race, classToken = classToken }
end
ns.modules = {}

local issecretvalue = issecretvalue
function ns.IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) == true end
function ns.Plain(v) if issecretvalue and issecretvalue(v) then return nil end return v end
function ns.Print(...) print("|cff33ccffOmniHeal:|r", ...) end

local reported = {}
local stack
local function KeepStack(err) stack = debugstack and debugstack(2) or "" return err end
function ns.Safe(label, fn, ...)
  local ok, err
  local n = select("#", ...)
  if n == 0 then ok, err = xpcall(fn, KeepStack)
  else
    local args = { ... }
    ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, KeepStack)
  end
  if not ok then
    err = label .. ": " .. tostring(err)
    ns.lastError = err
    if not reported[err] then
      reported[err] = true
      ns.Print("|cffff5555Update error|r: " .. err)
      local handler = geterrorhandler and geterrorhandler()
      if handler then pcall(handler, err .. "\n" .. (stack or "")) end
    end
  end
end

function ns.Throttled(interval, fn)
  local last, queued = -interval, false
  local function run() queued = false last = GetTime() fn() end
  return function()
    if queued then return end
    local wait = last + interval - GetTime()
    if wait <= 0 then run() else queued = true C_Timer.After(wait, run) end
  end
end

function ns:NewModule(name)
  local m = { name = name }
  self[name] = m
  self.modules[#self.modules + 1] = m
  return m
end

local eventFrame = CreateFrame("Frame")
local always, whileActive = {}, {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = always[event]
  if list then for i = 1, #list do ns.Safe(event, list[i], event, ...) end end
  if ns.state then
    list = whileActive[event]
    if list then for i = 1, #list do ns.Safe(event, list[i], event, ...) end end
  end
end)

function ns:On(event, fn)
  local list = always[event]
  if not list then list = {} always[event] = list eventFrame:RegisterEvent(event) end
  list[#list + 1] = fn
end

function ns:OnActive(event, fn)
  local list = whileActive[event]
  if not list then list = {} whileActive[event] = list end
  list[#list + 1] = fn
  if ns.state then eventFrame:RegisterEvent(event) end
end

local function SetActiveEvents(on)
  for event in pairs(whileActive) do
    if on then eventFrame:RegisterEvent(event)
    elseif not always[event] then eventFrame:UnregisterEvent(event) end
  end
end

local pending = {}
function ns:AfterCombat(key, fn)
  if InCombatLockdown() then pending[key] = fn
  else pending[key] = nil ns.Safe(key, fn) end
end

ns:On("PLAYER_REGEN_ENABLED", function()
  local queued = pending
  pending = {}
  for key, fn in pairs(queued) do ns.Safe(key, fn) end
end)

function ns:UpdateState()
  if not ns.db then return end
  local _, instanceType = IsInInstance()
  local wasInBG, oldBracket = ns.inBG, ns.liveBracket
  ns.inBG = instanceType == "pvp"
  ns.liveBracket, ns.inactiveReason = nil, nil
  if ns.inBG then
    ns.testMode = false
    ns.liveBracket, ns.inactiveReason = ns.GetBattlegroundLayout()
  end
  local state = (ns.liveBracket and "bg") or (ns.testMode and "test") or nil
  if state == ns.state then
    if state == "bg" and oldBracket ~= ns.liveBracket then ns.Frames:Refresh() end
    if wasInBG ~= ns.inBG then ns.RefreshSettings() end
    return
  end
  local old = ns.state
  ns.state = state
  if old then
    for _, m in ipairs(ns.modules) do
      if m.OnDeactivate then ns.Safe((m.name or "module") .. " stop", m.OnDeactivate, m) end
    end
  end
  SetActiveEvents(state ~= nil)
  if state then
    for _, m in ipairs(ns.modules) do
      if m.OnActivate then ns.Safe((m.name or "module") .. " start", m.OnActivate, m, state) end
    end
  end
end

-- Only the sample frames read the guide's uncommitted choices.
function ns:FrameSettings()
  if self.state == "test" and self.Setup and self.Setup.active then
    return self.Setup.draft
  end
  return self.db
end

function ns:Bracket()
  if ns.state == "bg" then return ns.liveBracket end
  return self:FrameSettings().editBracket
end

function ns:LayoutFor(team, bracket) return ns.db.brackets[bracket or ns:Bracket()][team] end
function ns:SetLocked(locked) ns.db.locked = locked ns.Frames:UpdateLocks() end

ns:On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  ns.global = ns:LoadSavedVariables()
  ns.db = ns.global.profiles[ns.global.current]
  for _, m in ipairs(ns.modules) do if m.OnInit then m:OnInit() end end
end)

ns:On("PLAYER_ENTERING_WORLD", function() ns:UpdateState() end)
ns:On("ZONE_CHANGED_NEW_AREA", function() ns:UpdateState() end)
