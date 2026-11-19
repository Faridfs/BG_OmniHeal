local _, ns = ...
local Hider = ns:NewModule("Hider")

local PROVIDERS = {
  {
    name = "Blizzard",
    frames = function()
      return { _G.CompactRaidFrameContainer, _G.CompactPartyFrame, _G.CompactRaidFrameManager, _G.PartyFrame }
    end,
  },
  {
    name = "ElvUI",
    frames = function()
      return { _G.ElvUF_Raid1, _G.ElvUF_Raid2, _G.ElvUF_Raid3, _G.ElvUF_Raid, _G.ElvUF_Raid40, _G.ElvUF_Party, _G.ElvUF_Raidpet }
    end,
  },
  {
    name = "EllesmereUI",
    frames = function()
      local party = _G.ERFPartyHeader and _G.ERFPartyHeader:GetParent()
      return { _G.EllesmereUIRaidFrameContainer, party ~= UIParent and party or nil }
    end,
  },
}
Hider.PROVIDERS = PROVIDERS

local hiddenParent = CreateFrame("Frame", "OmniHealHiddenParent", UIParent)
hiddenParent:Hide()
local moved, watched = {}, {}
local refreshQueued = false

local function WantsHidden()
  return ns.state == "bg" and ns.db.hideOtherRaid
end

-- Another addon can borrow a frame and later restore it to the parent it saw
-- at the time. Reconcile after its SetParent finishes, outside combat.
local function OnParentChanged(frame)
  if refreshQueued or (not moved[frame] and not WantsHidden()) then return end
  refreshQueued = true
  C_Timer.After(0, function()
    refreshQueued = false
    Hider:Update()
  end)
end

local function HideFrame(frame, stock)
  if not frame or frame == hiddenParent or frame == UIParent or not frame.SetParent then return end
  if not watched[frame] then
    hooksecurefunc(frame, "SetParent", OnParentChanged)
    watched[frame] = true
  end

  local parent = frame:GetParent()
  if parent == hiddenParent then return end
  -- Stock top-level containers belong to UIParent. Leave containers parked
  -- under another addon's host there. CompactPartyFrame under PartyFrame is
  -- already hidden with its parent.
  if stock and parent ~= UIParent then return end
  if moved[frame] and parent ~= moved[frame] then return end

  moved[frame] = parent or UIParent
  frame:SetParent(hiddenParent)
end

local function RestoreAll()
  for frame, original in pairs(moved) do
    local parent = frame:GetParent()
    if parent == hiddenParent then
      frame:SetParent(original)
      moved[frame] = nil
    elseif parent == original then
      moved[frame] = nil
    end
    -- If it is still under a foreign host, retain its original parent in
    -- case that host later hands the frame back to OmniHealHiddenParent.
  end
end

local function Apply()
  if WantsHidden() then
    for _, provider in ipairs(PROVIDERS) do
      for _, frame in pairs(provider.frames()) do
        HideFrame(frame, provider.name == "Blizzard")
      end
    end
  else
    RestoreAll()
  end
end

function Hider:Update()
  ns:AfterCombat("hider", Apply)
end

function Hider:OnActivate(state)
  if state ~= "bg" then
    return
  end
  self:Update()
  C_Timer.After(3, function()
    if ns.state == "bg" then
      Hider:Update()
    end
  end)
end

function Hider:OnDeactivate()
  self:Update()
end