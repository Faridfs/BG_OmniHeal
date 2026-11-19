local _, ns = ...
local T = ns.Theme
local Window = {}
ns.SetupWindow = Window

local WIDTH, PAD, GAP = 460, 18, 6
local BODY_WIDTH = WIDTH - PAD * 2
local ROW_HEIGHT = 28
local stepKeys = { "setup_teams", "setup_layout", "setup_preview" }
local teamFields = { ally = "showAllies", enemy = "showEnemies" }

local function Place(widget, frame, x, y)
  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
end

local function Text(frame, font)
  local label = frame:CreateFontString(nil, "OVERLAY", font)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")
  label:SetWidth(BODY_WIDTH)
  label:SetWordWrap(true)
  return label
end

local function Choice(frame, onClick)
  local button = T.MakeButton(frame, "", BODY_WIDTH, ROW_HEIGHT)
  button.label:ClearAllPoints()
  button.label:SetPoint("LEFT", button, "LEFT", 30, 0)
  button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
  button.label:SetJustifyH("LEFT")
  button.mark = button:CreateTexture(nil, "OVERLAY")
  button.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  button.mark:SetSize(22, 22)
  button.mark:SetPoint("LEFT", button, "LEFT", 4, 0)
  button:SetScript("OnClick", onClick)
  return button
end

local function Build()
  local frame = CreateFrame("Frame", "OmniHealSetupWindow", UIParent, "BackdropTemplate")
  frame:Hide()
  frame:SetSize(WIDTH, 250)
  frame:SetPoint("TOP", UIParent, "TOP", 0, -12)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  T.Panel(frame, 6)

  frame.heading = Text(frame, "GameFontHighlight")
  frame.heading:SetWidth(BODY_WIDTH - 30)
  Place(frame.heading, frame, PAD, 14)
  local close = T.MakeButton(frame, "X", 20, 20)
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
  close:SetScript("OnClick", function() ns.Setup:Dismiss() end)

  local divider = T.Divider(frame)
  divider:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -38)
  divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -38)
  frame.progress = Text(frame, "GameFontHighlightSmall")
  frame.progress:SetTextColor(unpack(T.DIM))
  frame.title = Text(frame, "GameFontNormalLarge")
  frame.title:SetTextColor(unpack(T.TEXT))
  frame.hint = Text(frame, "GameFontHighlight")
  frame.hint:SetSpacing(2)

  frame.teams, frame.brackets = {}, {}
  for _, team in ipairs({ "ally", "enemy" }) do
    frame.teams[team] = Choice(frame, function()
      ns.Setup:SetTeam(team, not ns.Setup.draft[teamFields[team]])
    end)
  end
  for _, bracket in ipairs(ns.BRACKETS) do
    frame.brackets[bracket] = Choice(frame, function() ns.Setup:SetBracket(bracket) end)
  end
  frame.preview = T.MakeButton(frame, "", BODY_WIDTH, ROW_HEIGHT)
  frame.preview:SetScript("OnClick", function() ns.Setup:TogglePreview() end)
  frame.lock = Choice(frame, function() ns.Setup:SetLocked(not ns.Setup.draft.locked) end)

  frame.warning = Text(frame, "GameFontHighlightSmall")
  frame.warning:SetTextColor(1, 0.78, 0.35)
  frame.later = T.MakeButton(frame, "", 120, ROW_HEIGHT)
  frame.later:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
  frame.later:SetScript("OnClick", function() ns.Setup:Dismiss() end)
  frame.next = T.MakeButton(frame, "", 84, ROW_HEIGHT, true)
  frame.next:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
  frame.next:SetScript("OnClick", function()
    if ns.Setup.step == 3 then ns.Setup:Finish() else ns.Setup:Next() end
  end)
  frame.back = T.MakeButton(frame, "", 76, ROW_HEIGHT)
  frame.back:SetPoint("RIGHT", frame.next, "LEFT", -GAP, 0)
  frame.back:SetScript("OnClick", function() ns.Setup:Back() end)

  -- Escape closes special frames directly. Closing the guide from its controller
  -- takes a separate path so Finish or combat dismissal cannot call Dismiss again.
  tinsert(UISpecialFrames, frame:GetName())
  frame:SetScript("OnHide", function(self)
    if not self:IsShown() and not Window.closing and ns.Setup.active then ns.Setup:Dismiss() end
  end)
  frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
  frame:RegisterEvent("UI_SCALE_CHANGED")
  frame:SetScript("OnEvent", function(self) if self:IsShown() then Window:Refresh() end end)
  return frame
end

local function ShowChoice(button, frame, y, text, selected)
  button:SetText(text)
  button.isCurrent = selected
  button.mark:SetShown(selected)
  T.ApplyButtonColors(button)
  Place(button, frame, PAD, y)
  button:Show()
  return y + ROW_HEIGHT + GAP
end

local function FitFooter(button, text, minWidth)
  button:SetText(text)
  button:SetWidth(math.max(minWidth, button.label:GetStringWidth() + 20))
end

function Window:Refresh()
  local frame, setup = self.frame, ns.Setup
  if not frame or not frame:IsShown() or not setup.active then return end
  local step = setup.step
  local key = stepKeys[step]
  frame.heading:SetText("BG OmniHeal  ·  " .. ns.L("setup_title"))
  frame.progress:SetText(string.format(ns.L("setup_step"), step, #stepKeys))
  Place(frame.progress, frame, PAD, 50)
  local y = 50 + frame.progress:GetStringHeight() + GAP
  frame.title:SetText(ns.L(key))
  Place(frame.title, frame, PAD, y)
  y = y + frame.title:GetStringHeight() + GAP
  frame.hint:SetText(ns.L(key .. "_hint"))
  Place(frame.hint, frame, PAD, y)
  y = y + frame.hint:GetStringHeight() + 14

  for _, button in pairs(frame.teams) do button:Hide() end
  for _, button in pairs(frame.brackets) do button:Hide() end
  frame.preview:Hide()
  frame.lock:Hide()
  frame.warning:Hide()
  local draft = setup.draft
  local canAdvance = step ~= 1 or draft.showAllies or draft.showEnemies
  if step == 1 then
    for _, team in ipairs({ "ally", "enemy" }) do
      y = ShowChoice(frame.teams[team], frame, y, ns.L("page_" .. team), draft[teamFields[team]])
    end
    if not canAdvance then
      frame.warning:SetText(ns.L("setup_choose_team"))
      Place(frame.warning, frame, PAD, y)
      frame.warning:Show()
      y = y + frame.warning:GetStringHeight() + GAP
    end
  elseif step == 2 then
    for _, bracket in ipairs(ns.BRACKETS) do
      y = ShowChoice(frame.brackets[bracket], frame, y, ns.BRACKET_NAMES[bracket], draft.editBracket == bracket)
    end
  else
    frame.preview:SetText(ns.L(ns.testMode and "preview_end" or "preview_start"))
    Place(frame.preview, frame, PAD, y)
    frame.preview:Show()
    y = ShowChoice(frame.lock, frame, y + ROW_HEIGHT + GAP, ns.L("opt_locked"), draft.locked)
  end

  FitFooter(frame.later, ns.L("setup_later"), 100)
  FitFooter(frame.back, ns.L("setup_back"), 70)
  FitFooter(frame.next, ns.L(step == 3 and "setup_finish" or "setup_next"), 80)
  frame.back:SetShown(step > 1)
  frame.next:SetEnabled(not not canAdvance)

  local height = y + 12 + ROW_HEIGHT + PAD
  frame:SetHeight(height)
  local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
  if screenW > 24 and screenH > 24 then
    frame:SetScale(math.min(1, (screenW - 24) / WIDTH, (screenH - 24) / height))
  end
end

function Window:Show()
  if not self.frame then self.frame = Build() end
  self.frame:Show()
  self:Refresh()
  self.frame:Raise()
end

function Window:Hide()
  if not self.frame or not self.frame:IsShown() then return end
  self.closing = true
  self.frame:Hide()
  self.closing = nil
end
