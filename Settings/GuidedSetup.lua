local _, ns = ...

local Setup = {}
ns.Setup = Setup
local offeredThisSession = false

local function Available()
  local _, instanceType = IsInInstance()
  return ns.db and not InCombatLockdown() and not ns.inBG and instanceType ~= "pvp"
end

local function NewDraft(profile)
  local positions = {}
  for _, bracket in ipairs(ns.BRACKETS) do
    -- Existing anchors are read through the profile. Dragging writes only to the draft.
    positions[bracket] = setmetatable({}, { __index = profile.positions[bracket] })
  end
  return {
    showAllies = profile.showAllies, showEnemies = profile.showEnemies,
    editBracket = profile.editBracket, locked = profile.locked, positions = positions,
  }
end

local function RestorePreview(wasPreview)
  ns:AfterCombat("setupPreview", function()
    if ns.inBG or select(2, IsInInstance()) == "pvp" then return end
    if wasPreview and ns.state == "test" then
      ns.Test:Rebuild()
    else
      ns.Test:SetEnabled(wasPreview)
    end
  end)
end

function Setup:Open()
  if not Available() then
    ns.Print(ns.L("setup_unavailable"))
    return
  end
  if not self.active then
    offeredThisSession = true
    self.active, self.step = true, 1
    self.profile = ns.db
    self.draft = NewDraft(ns.db)
    self.wasPreview = ns.testMode == true
  end
  if OmniHealSettings:IsShown() then OmniHealSettings:Hide() end
  ns.SetupWindow:Show()
end

function Setup:SetTeam(team, visible)
  if self.step ~= 1 then return end
  if team == "ally" then self.draft.showAllies = visible == true
  elseif team == "enemy" then self.draft.showEnemies = visible == true
  else return end
  if ns.state == "test" then ns.Frames:Refresh() end
  ns.SetupWindow:Refresh()
end

function Setup:SetBracket(bracket)
  if self.step ~= 2 or not ns.BRACKET_NAMES[bracket] then return end
  self.draft.editBracket = bracket
  if ns.state == "test" then ns.Test:Rebuild() end
  ns.SetupWindow:Refresh()
end

function Setup:Next()
  if not self.active or not Available() then return end
  if self.step == 1 and (self.draft.showAllies or self.draft.showEnemies) then
    self.step = 2
  elseif self.step == 2 then
    self.step = 3
  end
  ns.SetupWindow:Refresh()
end

function Setup:Back()
  if not self.active or self.step == 1 then return end
  local leavingPreview = self.step == 3
  self.step = self.step - 1
  if leavingPreview then RestorePreview(self.wasPreview) end
  ns.SetupWindow:Refresh()
end

function Setup:TogglePreview()
  if not self.active or not Available() then return end
  ns.Test:SetEnabled(not ns.testMode)
  ns.SetupWindow:Refresh()
end

function Setup:SetLocked(locked)
  if not self.active then return end
  self.draft.locked = locked == true
  ns.SetupWindow:Refresh()
end

local function Close(clearPending)
  if not Setup.active then return end
  local wasPreview = Setup.wasPreview
  Setup.active, Setup.step, Setup.profile, Setup.draft, Setup.wasPreview = nil, nil, nil, nil, nil
  if clearPending then ns.global.frameSetupPending = nil end
  ns.SetupWindow:Hide()
  RestorePreview(wasPreview)
  ns.RefreshSettings()
end

function Setup:Dismiss()
  Close(true)
end

function Setup:Finish()
  if self.step ~= 3 or not Available() or self.profile ~= ns.db then return end
  local draft = self.draft
  ns.db.showAllies, ns.db.showEnemies = draft.showAllies, draft.showEnemies
  ns.db.editBracket, ns.db.locked = draft.editBracket, draft.locked
  for bracket, moved in pairs(draft.positions) do
    if next(moved) then
      local saved = ns.db.positions[bracket] or {}
      for team, anchor in pairs(moved) do saved[team] = anchor end
      ns.db.positions[bracket] = saved
    end
  end
  Close(true)
end

local function CheckWorld()
  if not Available() then
    Close(false)
  elseif ns.global.frameSetupPending and not offeredThisSession then
    Setup:Open()
  end
end

ns:On("PLAYER_ENTERING_WORLD", CheckWorld)
ns:On("ZONE_CHANGED_NEW_AREA", CheckWorld)
ns:On("PLAYER_REGEN_ENABLED", CheckWorld)
ns:On("PLAYER_REGEN_DISABLED", function() Close(false) end)
