local _, ns = ...
local MinimapButton = ns:NewModule("MinimapButton")

local button
local function Saved() return ns.global.minimap end

local function Place()
  local angle = math.rad(Saved().angle or 225)
  local x, y = math.cos(angle), math.sin(angle)
  local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
  if shape == "SQUARE" then
    local m = math.max(math.abs(x), math.abs(y))
    x, y = x / m, y / m
  end
  local rx, ry = Minimap:GetWidth() / 2 + 5, Minimap:GetHeight() / 2 + 5
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x * rx, y * ry)
end

local function OnDragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  Saved().angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
  Place()
end

local function Create()
  button = CreateFrame("Button", "OmniHealMinimapButton", Minimap)
  button:SetSize(31, 31); button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(8)
  button:RegisterForClicks("AnyUp"); button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture(136477)

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(24, 24); background:SetTexture(136467); background:SetPoint("CENTER")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20); icon:SetPoint("CENTER"); icon:SetTexture(ns.Theme.MEDIA .. "icon.png")
  icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  local mask = button:CreateMaskTexture()
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(icon); icon:AddMaskTexture(mask)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetTexture(136430); border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then ns.Test:Toggle() else ns.ToggleSettings() end
  end)
  button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("BG OmniHeal", 1, 1, 1)
    GameTooltip:AddLine(ns.L("opt_minimap_desc"), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function MinimapButton:Update()
  if Saved().hide then if button then button:Hide() end return end
  if not button then Create() end
  Place(); button:Show()
end

function MinimapButton:OnInit() self:Update() end