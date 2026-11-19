local _, ns = ...
local Options = ns:NewModule("Options")
local T = ns.Theme

function Options:OnInit()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  local panel = CreateFrame("Frame")
  local title = T.Title(panel, 22, ns.version)
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  local open = T.MakeButton(panel, "", 200, 26)
  open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
  panel:SetScript("OnShow", function()
    text:SetText(ns.L("settings_open_hint"))
    open:SetText(ns.L("settings_open"))
    open:SetWidth(math.max(160, open.label:GetStringWidth() + 20))
  end)
  open:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    ns.ToggleSettings("general")
  end)
  local category = Settings.RegisterCanvasLayoutCategory(panel, "BG OmniHeal")
  Settings.RegisterAddOnCategory(category)
end

function Options:OnActivate() ns.RefreshSettings() end
Options.OnDeactivate = Options.OnActivate

function Options:Open() ns.ToggleSettings() end
function OmniHeal_OnAddonCompartmentClick() ns.ToggleSettings() end
