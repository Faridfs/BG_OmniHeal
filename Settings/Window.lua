local _, ns = ...
local T = ns.Theme

local W, H, NAV_W, PAD = 768, 600, 158, 14
local SCROLL_GUTTER = 10
local CONTENT_W = W - PAD - NAV_W - PAD * 2 - (PAD + 8) - SCROLL_GUTTER
local GAP, ROW_GAP = 10, 14
local SECTION_GAP = 12
local UNIT = (CONTENT_W + GAP) / 3

local frame = CreateFrame("Frame", "OmniHealSettings", UIParent, "BackdropTemplate")
frame:SetSize(W, H)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()
tinsert(UISpecialFrames, "OmniHealSettings")
T.Panel(frame, 6)

local wordmark, versionText = T.Title(frame, 18, ns.version)
wordmark:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -11)

local close = T.MakeButton(frame, "X", 18, 18)
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
close:SetScript("OnClick", function() frame:Hide() end)

local info = T.MakeButton(frame, "", 18, 18)
info:SetPoint("RIGHT", close, "LEFT", -4, 0)
info.text = info:CreateFontString(nil, "OVERLAY")
pcall(info.text.SetFont, info.text, T.TITLE_FONT, 14, "")
info.text:SetPoint("CENTER", 0, 0)
info.text:SetText("i")
info.text:SetTextColor(unpack(T.TEXT))
info:HookScript("OnEnter", function(self)
  self.text:SetTextColor(unpack(T.ACCENT))
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:SetText(ns.L("page_info"), 1, 1, 1)
  GameTooltip:Show()
end)
info:HookScript("OnLeave", function(self)
  self.text:SetTextColor(unpack(T.TEXT))
  GameTooltip:Hide()
end)
info:SetScript("OnClick", function() ns.ToggleSettings("info") end)

local test = T.MakeButton(frame, "", 90, 22)
test:SetPoint("RIGHT", info, "LEFT", -4, 0)
test:SetScript("OnClick", function() ns.Test:Toggle() end)
test:HookScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:SetText(ns.L("grp_testing"), 1, 1, 1)
  GameTooltip:AddLine(ns.L("test_desc"), 0.8, 0.8, 0.8)
  GameTooltip:Show()
end)
test:HookScript("OnLeave", function() GameTooltip:Hide() end)

local searchBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
searchBox:SetHeight(24)
searchBox:SetAutoFocus(false)
searchBox:SetMaxLetters(100)
searchBox:SetFontObject("GameFontHighlight")
searchBox:SetJustifyH("LEFT")
searchBox:SetTextInsets(27, 27, 0, 0)
searchBox:SetPoint("LEFT", versionText or wordmark, "RIGHT", 18, 0)
searchBox:SetPoint("RIGHT", test, "LEFT", -12, 0)
T.Backdrop(searchBox, T.FIELD, T.FIELD_BORDER, 3)

local searchIcon = searchBox:CreateTexture(nil, "ARTWORK")
searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
searchIcon:SetSize(14, 14)
searchIcon:SetPoint("LEFT", searchBox, "LEFT", 7, 0)
searchIcon:SetVertexColor(0.7, 0.7, 0.7)

local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 27, 0)
searchPlaceholder:SetJustifyH("LEFT")

local searchClear = CreateFrame("Button", nil, searchBox)
searchClear:SetSize(18, 18)
searchClear:SetPoint("RIGHT", searchBox, "RIGHT", -4, 0)
searchClear.text = searchClear:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
searchClear.text:SetPoint("CENTER", 0, 0)
searchClear.text:SetText("X")
searchClear.text:SetTextColor(unpack(T.DIM))
searchClear:Hide()
searchClear:SetScript("OnClick", function()
  searchBox:SetText("")
  searchBox:SetFocus()
end)
searchClear:HookScript("OnEnter", function(self) self.text:SetTextColor(unpack(T.TEXT)) end)
searchClear:HookScript("OnLeave", function(self) self.text:SetTextColor(unpack(T.DIM)) end)

local topLine = T.Divider(frame)
topLine:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -38)
topLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -38)

local nav = CreateFrame("Frame", nil, frame)
nav:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -48)
nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
nav:SetWidth(NAV_W)
nav.buttons = {}
nav.headings = {}

local navLine = frame:CreateTexture(nil, "ARTWORK")
navLine:SetColorTexture(1, 1, 1, 0.07)
navLine:SetWidth(1)
navLine:SetPoint("TOPLEFT", nav, "TOPRIGHT", PAD, 0)
navLine:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", PAD, 0)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", nav, "TOPRIGHT", PAD * 2, 0)
scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD - 8, PAD)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(CONTENT_W, 10)
scroll:SetScrollChild(content)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
  local max = math.max(0, content:GetHeight() - self:GetHeight())
  self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
end)

-- СОЗДАЕМ ПОЛЗУНОК КАК ФРЕЙМ
local thumb = CreateFrame("Frame", nil, frame)
thumb:SetWidth(6)
thumb:SetFrameStrata("DIALOG")
thumb:EnableMouse(true)
thumb:RegisterForDrag("LeftButton")

local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
thumbTex:SetAllPoints()
thumbTex:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.5)
thumb:Hide()

local function UpdateThumb()
  local viewH, fullH = scroll:GetHeight(), content:GetHeight()
  if fullH <= viewH + 1 then thumb:Hide() return end
  
  local h = math.max(24, viewH * viewH / fullH)
  local y = (viewH - h) * (scroll:GetVerticalScroll() / (fullH - viewH))
  
  thumb:ClearAllPoints()
  thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 4, -y)
  thumb:SetHeight(h)
  thumb:Show()
  
  thumb.maxScroll = fullH - viewH
  thumb.viewH = viewH
  thumb.thumbH = h
end

scroll:SetScript("OnVerticalScroll", UpdateThumb)

-- Логика перетаскивания ползунка
thumb:SetScript("OnDragStart", function(self)
  self.dragging = true
  self.startY = select(2, GetCursorPosition())
  self.startScroll = scroll:GetVerticalScroll()
end)

thumb:SetScript("OnDragStop", function(self)
  self.dragging = false
end)

thumb:SetScript("OnUpdate", function(self)
  if self.dragging then
    local _, cy = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    local dy = (self.startY - cy) / scale
    
    local trackH = self.viewH - self.thumbH
    if trackH > 0 then
      local scrollDelta = (dy / trackH) * self.maxScroll
      local newScroll = math.min(self.maxScroll, math.max(0, self.startScroll + scrollDelta))
      scroll:SetVerticalScroll(newScroll)
    end
  end
end)

local INFO = {}
local function Eval(v, ...)
  if type(v) == "function" then return v(INFO, ...) end
  return v
end

local function Sorted(args)
  local list = {}
  for key, opt in pairs(args or {}) do
    if type(opt) == "table" and not Eval(opt.hidden) then
      list[#list + 1] = { key = key, opt = opt }
    end
  end
  table.sort(list, function(a, b)
    local oa, ob = a.opt.order or 100, b.opt.order or 100
    if oa == ob then return a.key < b.key end
    return oa < ob
  end)
  return list
end

local function WidthOf(opt, default)
  local w = opt.width
  if w == "full" then return 3 end
  if w == "double" then return 2 end
  if w == "half" then return 0.5 end
  if w == "normal" then return 1 end
  if type(w) == "number" then return w end
  return default
end

local function Tooltip(owner, title, desc)
  owner.tipTitle, owner.tipDesc = title, desc
  if owner.tipHooked then return end
  owner.tipHooked = true
  owner:HookScript("OnEnter", function(self)
    if self.OnEnterExtra then self:OnEnterExtra() end
    if not self.tipDesc or self.tipDesc == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self.tipTitle or "", 1, 1, 1)
    GameTooltip:AddLine(self.tipDesc, 0.8, 0.8, 0.8, true); GameTooltip:Show()
  end)
  owner:HookScript("OnLeave", function(self)
    if self.OnLeaveExtra then self:OnLeaveExtra() end
    if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
  end)
end

local Refresh

local pools, used = {}, {}
local function Acquire(kind, factory)
  pools[kind] = pools[kind] or {}
  local w = table.remove(pools[kind]) or factory()
  w.kind = kind; w:SetParent(content); w:Show(); used[#used + 1] = w
  return w
end
local function ReleaseAll()
  for _, w in ipairs(used) do w:Hide(); w:ClearAllPoints(); table.insert(pools[w.kind], w) end
  wipe(used)
end

local function Label(parent, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
  fs:SetJustifyH("LEFT")
  return fs
end

local function NewHeader()
  local f = CreateFrame("Frame", nil, content); f:SetHeight(20)
  f.fs = T.Section(f, "x"); f.fs:SetPoint("LEFT", f, "LEFT", 0, 0)
  return f
end

local function NewDesc()
  local f = CreateFrame("Frame", nil, content)
  f.fs = Label(f, "GameFontHighlight"); f.fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); f.fs:SetSpacing(2)
  return f
end

local function NewToggle()
  local b = CreateFrame("Button", nil, content); b:SetHeight(20)
  b.box = CreateFrame("Frame", nil, b, "BackdropTemplate"); b.box:SetSize(16, 16); b.box:SetPoint("LEFT", b, "LEFT", 0, 0)
  T.Backdrop(b.box, T.FIELD, T.FIELD_BORDER, 3)
  b.mark = b.box:CreateTexture(nil, "OVERLAY"); b.mark:SetPoint("CENTER")
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-icon-checkmark") then
    b.mark:SetAtlas("common-icon-checkmark"); b.mark:SetSize(12, 12)
  else
    b.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); b.mark:SetSize(20, 20)
  end
  b.mark:SetVertexColor(unpack(T.ON))
  b.label = Label(b, "GameFontHighlight"); b.label:SetPoint("LEFT", b.box, "RIGHT", 8, 0); b.label:SetPoint("RIGHT", b, "RIGHT", 0, 0)
  b.OnEnterExtra = function(self) if self:IsEnabled() then self.box:SetBackdropColor(unpack(T.HOVER)) end end
  b.OnLeaveExtra = function(self) self.box:SetBackdropColor(unpack(T.FIELD)) end
  return b
end

local function NewButton() return T.MakeButton(content, "", 100, 22) end

local function NewInput()
  local f = CreateFrame("Frame", nil, content)
  f.label = Label(f); f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); f.label:SetTextColor(unpack(T.DIM))
  f.box = CreateFrame("EditBox", nil, f, "BackdropTemplate"); f.box:SetHeight(22); T.Backdrop(f.box, T.FIELD, T.FIELD_BORDER, 3)
  f.box:SetFontObject("GameFontHighlight"); f.box:SetTextInsets(7, 7, 0, 0); f.box:SetAutoFocus(false)
  f.err = Label(f, "GameFontRedSmall"); f.err:SetPoint("TOPLEFT", f.box, "BOTTOMLEFT", 2, -2); f.err:SetPoint("RIGHT", f, "RIGHT", 0, 0); f.err:SetWordWrap(true)
  return f
end

local menu = CreateFrame("Frame", "OmniHealSettingsMenu", frame, "BackdropTemplate")
menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetClampedToScreen(true); T.Backdrop(menu, T.BG, T.ACCENT, 4)
menu:Hide(); menu.items = {}
menu:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
menu:SetScript("OnHide", function(self) self.owner = nil; self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
menu:SetScript("OnEvent", function(self) if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end end)

local function OpenMenu(owner, choices, current, onPick)
  if menu:IsShown() and menu.owner == owner then menu:Hide(); return end
  menu.owner = owner; local width = owner:GetWidth()
  for i, choice in ipairs(choices) do
    local item = menu.items[i]
    if not item then
      item = CreateFrame("Button", nil, menu); item:SetHeight(20)
      item.hl = item:CreateTexture(nil, "HIGHLIGHT"); item.hl:SetAllPoints(); item.hl:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.2)
      item.text = Label(item, "GameFontHighlight"); item.text:SetPoint("LEFT", item, "LEFT", 8, 0); item.text:SetPoint("RIGHT", item, "RIGHT", -8, 0); item.text:SetWordWrap(false)
      menu.items[i] = item
    end
    item:ClearAllPoints(); item:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -(4 + (i - 1) * 20)); item:SetPoint("RIGHT", menu, "RIGHT", -1, 0)
    item.text:SetText(choice.label); width = math.max(width, item.text:GetStringWidth() + 18)
    if choice.value == current then item.text:SetTextColor(unpack(T.ACCENT)) else item.text:SetTextColor(unpack(T.TEXT)) end
    item:SetScript("OnClick", function() menu:Hide(); onPick(choice.value) end); item:Show()
  end
  for i = #choices + 1, #menu.items do menu.items[i]:Hide() end
  menu:SetSize(width, #choices * 20 + 8); menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2); menu:Show(); menu:Raise()
end

local function NewSelect()
  local f = CreateFrame("Frame", nil, content)
  f.label = Label(f); f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); f.label:SetTextColor(unpack(T.DIM))
  f.button = CreateFrame("Button", nil, f, "BackdropTemplate"); f.button:SetHeight(22); T.Backdrop(f.button, T.FIELD, T.FIELD_BORDER, 3)
  f.button.text = Label(f.button, "GameFontHighlight"); f.button.text:SetPoint("LEFT", f.button, "LEFT", 8, 0); f.button.text:SetPoint("RIGHT", f.button, "RIGHT", -22, 0); f.button.text:SetWordWrap(false)
  f.button.arrow = Label(f.button, "GameFontHighlightSmall"); f.button.arrow:SetPoint("RIGHT", f.button, "RIGHT", -8, 0); f.button.arrow:SetText("v"); f.button.arrow:SetTextColor(unpack(T.DIM))
  f.button.OnEnterExtra = function(self) if self:IsEnabled() then self:SetBackdropColor(unpack(T.HOVER)) end end
  f.button.OnLeaveExtra = function(self) self:SetBackdropColor(unpack(T.FIELD)) end
  return f
end

-- ПОЛЗУНОК
local RANGE_H = 24
local function NewRange()
  local f = CreateFrame("Frame", nil, content); f:SetHeight(RANGE_H)
  f.label = Label(f, "GameFontHighlight"); f.label:SetPoint("LEFT", f, "LEFT", 0, 0); f.label:SetWordWrap(false)
  
  f.value = CreateFrame("EditBox", nil, f, "BackdropTemplate"); f.value:SetSize(50, 20); f.value:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  T.Backdrop(f.value, T.FIELD, T.FIELD_BORDER, 3); f.value:SetFontObject("GameFontHighlightSmall"); f.value:SetJustifyH("CENTER"); f.value:SetAutoFocus(false)
  f.value:SetTextColor(1, 1, 1)
  
  f.btnPlus = CreateFrame("Button", nil, f, "BackdropTemplate"); f.btnPlus:SetSize(20, 20); f.btnPlus:SetPoint("RIGHT", f.value, "LEFT", -4, 0)
  T.Backdrop(f.btnPlus, T.FIELD, T.FIELD_BORDER, 3)
  f.btnPlus.text = f.btnPlus:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.btnPlus.text:SetPoint("CENTER"); f.btnPlus.text:SetText(">")
  
  f.btnMinus = CreateFrame("Button", nil, f, "BackdropTemplate"); f.btnMinus:SetSize(20, 20); f.btnMinus:SetPoint("RIGHT", f.btnPlus, "LEFT", -2, 0)
  T.Backdrop(f.btnMinus, T.FIELD, T.FIELD_BORDER, 3)
  f.btnMinus.text = f.btnMinus:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.btnMinus.text:SetPoint("CENTER"); f.btnMinus.text:SetText("<")

  f.slider = CreateFrame("Slider", nil, f, "BackdropTemplate"); f.slider:SetOrientation("HORIZONTAL"); f.slider:SetHeight(14); f.slider:SetPoint("RIGHT", f.btnMinus, "LEFT", -8, 0); f.slider:SetObeyStepOnDrag(true)
  f.slider.track = f.slider:CreateTexture(nil, "BACKGROUND"); f.slider.track:SetPoint("LEFT"); f.slider.track:SetPoint("RIGHT"); f.slider.track:SetHeight(4); f.slider.track:SetColorTexture(T.FIELD_BORDER[1], T.FIELD_BORDER[2], T.FIELD_BORDER[3], 1)
  f.slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8"); local th = f.slider:GetThumbTexture(); th:SetSize(10, 14); th:SetVertexColor(unpack(T.ACCENT))
  return f
end

local function Disabled(opt) return Eval(opt.disabled) and true or false end
local SETUP = {}

SETUP.header = function(opt, width)
  local f = Acquire("header", NewHeader); f:SetWidth(width); f.fs:SetText(string.upper(Eval(opt.name) or "")); return f, 22
end

SETUP.description = function(opt, width)
  local f = Acquire("description", NewDesc); f:SetWidth(width); f.fs:SetWidth(width)
  f.fs:SetFontObject(opt.fontSize == "medium" and "GameFontHighlight" or "GameFontHighlightSmall"); f.fs:SetTextColor(unpack(T.DIM))
  f.fs:SetText(strtrim(Eval(opt.name) or "")); local h = math.max(1, f.fs:GetStringHeight()); f:SetHeight(h); return f, h
end

SETUP.toggle = function(opt, width)
  local b = Acquire("toggle", NewToggle); b:SetWidth(width); local name = Eval(opt.name) or ""; b.label:SetText(name)
  local on = Eval(opt.get) and true or false; local off = Disabled(opt); b.mark:SetShown(on)
  T.AccentBorder(b.box, on, 0.8, T.ON); b.label:SetTextColor(unpack(off and T.DIM or T.TEXT)); b:SetAlpha(off and 0.5 or 1); b:SetEnabled(not off)
  Tooltip(b, name, Eval(opt.desc))
  b:SetScript("OnClick", function() opt.set(INFO, not on); Refresh() end)
  local h = math.max(20, b.label:GetStringHeight() + 4); b:SetHeight(h); return b, h
end

local confirm = CreateFrame("Frame", "OmniHealConfirm", frame, "BackdropTemplate")
confirm:SetSize(340, 120); confirm:SetPoint("CENTER", frame, "CENTER", 0, 20); confirm:SetFrameStrata("FULLSCREEN_DIALOG")
confirm:SetToplevel(true); confirm:EnableMouse(true); T.Panel(confirm, 6); confirm:Hide(); tinsert(UISpecialFrames, "OmniHealConfirm")
confirm.text = confirm:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); confirm.text:SetPoint("TOPLEFT", confirm, "TOPLEFT", 16, -18); confirm.text:SetPoint("TOPRIGHT", confirm, "TOPRIGHT", -16, -18); confirm.text:SetJustifyH("LEFT"); confirm.text:SetSpacing(2)
confirm.yes = T.MakeButton(confirm, ns.L("yes"), 96, 22, true); confirm.yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -4, 14)
confirm.no = T.MakeButton(confirm, ns.L("cancel"), 96, 22); confirm.no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 4, 14); confirm.no:SetScript("OnClick", function() confirm:Hide() end)

local function Confirm(text, onYes)
  confirm.text:SetText(text); confirm:SetHeight(math.max(110, confirm.text:GetStringHeight() + 70))
  confirm.yes:SetText(ns.L("yes")); confirm.no:SetText(ns.L("cancel"))
  confirm.yes:SetScript("OnClick", function() confirm:Hide(); onYes() end); confirm:Show(); confirm:Raise()
end

local fieldErrors, fieldDrafts = {}, {}

SETUP.input = function(opt, width)
  local f = Acquire("input", NewInput); f:SetWidth(width); f.key = opt.__key; f.box.field = f
  local name = Eval(opt.name) or ""; f.label:SetText(name); f.label:SetWidth(width); f.label:SetWordWrap(false); f.label:SetShown(name ~= "")
  f.box:ClearAllPoints(); f.box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, name ~= "" and -16 or 0); f.box:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  local errText = fieldErrors[f.key] or ""; f.err:SetText(errText)
  local off = Disabled(opt); f.box:EnableMouse(not off); f.box:SetEnabled(not off); f:SetAlpha(off and 0.5 or 1)
  f.box:SetText(fieldDrafts[f.key] or Eval(opt.get) or "")
  local function tryCommit(value)
    local ok, err = opt.set(INFO, value)
    if ok == false then fieldErrors[f.key] = err or "Invalid value."; fieldDrafts[f.key] = value; return false end
    fieldErrors[f.key], fieldDrafts[f.key] = nil, nil; return true
  end
  f.box:SetScript("OnEnterPressed", function(self) if tryCommit(self:GetText()) then self:ClearFocus() end; Refresh() end)
  f.box:SetScript("OnEscapePressed", function(self) fieldErrors[f.key], fieldDrafts[f.key] = nil, nil; self:SetText(Eval(opt.get) or ""); self:ClearFocus(); Refresh() end)
  f.box:SetScript("OnTextChanged", function(self, typed) if typed and opt.onChange then opt.onChange(INFO, self:GetText()) end end)
  f.box:SetScript("OnEditFocusGained", function(self) T.AccentBorder(self, true) end)
  f.box:SetScript("OnEditFocusLost", function(self) T.AccentBorder(self, false) end)
  Tooltip(f.box, name, Eval(opt.desc))
  local h = (name ~= "" and 16 or 0) + 22
  if errText ~= "" then h = h + f.err:GetStringHeight() + 4 end
  f:SetHeight(h); return f, h
end

-- ЦВЕТ (палитра через ColorPickerFrame)
SETUP.color = function(opt, width)
  local f = Acquire("color", function()
    local fr = CreateFrame("Frame", nil, content); fr:SetHeight(RANGE_H)
    fr.label = Label(fr, "GameFontHighlight"); fr.label:SetPoint("LEFT", fr, "LEFT", 0, 0); fr.label:SetWordWrap(false)
    fr.swatch = CreateFrame("Button", nil, fr, "BackdropTemplate"); fr.swatch:SetSize(60, 20); fr.swatch:SetPoint("RIGHT", fr, "RIGHT", 0, 0)
    T.Backdrop(fr.swatch, T.FIELD, T.FIELD_BORDER, 3)
    fr.swatch.text = Label(fr.swatch, "GameFontHighlightSmall"); fr.swatch.text:SetPoint("CENTER")
    return fr
  end)
  f:SetWidth(width)
  local name = Eval(opt.name) or ""; f.label:SetText(name); f.label:SetWidth(math.floor(width * 0.5))
  local r, g, b
  if type(opt.get) == "function" then
    r, g, b = opt.get(INFO)
  else
    r, g, b = unpack(opt.get)
  end
  r, g, b = r or 1, g or 1, b or 1
  f.swatch.text:SetText(string.format("#%02X%02X%02X",
    math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)))
  f.swatch:SetBackdropColor(r * 0.7, g * 0.7, b * 0.7, 1)
  local off = Disabled(opt); f:SetAlpha(off and 0.5 or 1); f.swatch:SetEnabled(not off)
  Tooltip(f.swatch, name, Eval(opt.desc))
  f.swatch:SetScript("OnClick", function()
    local cur = { r, g, b }
    local picker = ColorPickerFrame
    picker.hasOpacity, picker.opacity = false, 1
    picker.previousValues = { r = cur[1], g = cur[2], b = cur[3] }
    picker.func = function() opt.set(INFO, picker.r, picker.g, picker.b); Refresh() end
    picker.cancelFunc = function() opt.set(INFO, cur[1], cur[2], cur[3]); Refresh() end
    picker:SetColorRGB(cur[1], cur[2], cur[3])
    picker:Show()
  end)
  return f, RANGE_H
end

SETUP.execute = function(opt, width)
  local b = Acquire("execute", NewButton); b:SetSize(width, 22); local name = Eval(opt.name) or ""; b:SetText(name)
  b.forceWhiteDisabledText = opt.forceWhiteDisabledText == true
  local off = Disabled(opt); b:SetEnabled(not off); T.ApplyButtonColors(b); Tooltip(b, name, Eval(opt.desc))
  b:SetScript("OnClick", function()
    local function run() opt.func(INFO); Refresh() end
    local ask = Eval(opt.confirm)
    if ask then Confirm(type(ask) == "string" and ask or ("Are you sure?"), run) else run() end
  end)
  return b, 22
end

SETUP.select = function(opt, width)
  local f = Acquire("select", NewSelect); f:SetWidth(width); local name = Eval(opt.name) or ""; f.label:SetText(name); f.label:SetWidth(width); f.label:SetWordWrap(false)
  f.button:ClearAllPoints(); f.button:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -16); f.button:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  local values = Eval(opt.values) or {}; local choices = {}; local sorting = Eval(opt.sorting)
  if sorting then
    for _, v in ipairs(sorting) do choices[#choices + 1] = { value = v, label = values[v] } end
  else
    for v, label in pairs(values) do choices[#choices + 1] = { value = v, label = label } end
    table.sort(choices, function(a, b) if type(a.value) == "number" and type(b.value) == "number" then return a.value < b.value end return tostring(a.label) < tostring(b.label) end)
  end
  local current = Eval(opt.get); f.button.text:SetText(values[current] or "")
  local off = Disabled(opt); f.button:SetEnabled(not off); f:SetAlpha(off and 0.5 or 1)
  Tooltip(f.button, name, Eval(opt.desc))
  f.button:SetScript("OnClick", function(self)
    OpenMenu(self, choices, current, function(v) opt.set(INFO, v); Refresh() end)
  end)
  f:SetHeight(38); return f, 38
end

SETUP.range = function(opt, width)
  local f = Acquire("range", NewRange); f:SetWidth(width); local name = Eval(opt.name) or ""; f.label:SetText(name)
  local labelW = math.floor(math.min(250, width * 0.46)); f.label:SetWidth(labelW)
  
  f.slider:ClearAllPoints(); f.slider:SetPoint("LEFT", f, "LEFT", labelW + 12, 0); f.slider:SetPoint("RIGHT", f.btnMinus, "LEFT", -8, 0)
  
  local min, max = opt.softMin or opt.min or 0, opt.softMax or opt.max or 1
  local step = opt.bigStep or opt.step or 0.01
  local s = f.slider
  
  s:SetScript("OnValueChanged", nil); s:SetMinMaxValues(min, max); s:SetValueStep(step)
  local value = Eval(opt.get) or min
  s:SetValue(math.max(min, math.min(max, value)))
  
  local function fmt(v) 
    if opt.isPercent then return string.format("%d%%", math.floor(v * 100 + 0.5)) end 
    if step >= 1 then return tostring(math.floor(v + 0.5)) end 
    return string.format("%.2f", v) 
  end
  
  f.value:SetText(fmt(value))
  local off = Disabled(opt); s:EnableMouse(not off); f.value:EnableMouse(not off); f:SetAlpha(off and 0.5 or 1)
  
  s:SetScript("OnValueChanged", function(_, v, userInput) 
    if not userInput then return end 
    v = math.floor(v / step + 0.5) * step
    f.value:SetText(fmt(v))
    opt.set(INFO, v) 
  end)
  s:SetScript("OnMouseUp", function() Refresh() end)
  
  f.btnPlus:SetScript("OnClick", function()
    if off then return end
    local curr = Eval(opt.get) or min
    local v = math.min(max, curr + (opt.isPercent and 0.01 or step))
    s:SetValue(v)
    f.value:SetText(fmt(v))
    opt.set(INFO, v)
  end)
  
  f.btnMinus:SetScript("OnClick", function()
    if off then return end
    local curr = Eval(opt.get) or min
    local v = math.max(min, curr - (opt.isPercent and 0.01 or step))
    s:SetValue(v)
    f.value:SetText(fmt(v))
    opt.set(INFO, v)
  end)
  
  f.value:SetScript("OnEnterPressed", function(self) 
    local v = tonumber((self:GetText():gsub("%%", ""))) 
    if v then 
      if opt.isPercent then v = v / 100 end 
      v = math.max(min, math.min(max, v))
      s:SetValue(v)
      self:SetText(fmt(v))
      opt.set(INFO, v) 
    end 
    self:ClearFocus()
    Refresh() 
  end)
  
  f.value:SetScript("OnEscapePressed", function(self) self:ClearFocus() Refresh() end)
  Tooltip(s, name, Eval(opt.desc)); f.label:SetTextColor(unpack(off and T.DIM or T.TEXT))
  return f, RANGE_H
end

local pageTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
pageTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
pageTitle:SetTextColor(unpack(T.TEXT))
local pageLine = content:CreateTexture(nil, "ARTWORK")
pageLine:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.35)
pageLine:SetHeight(1)
pageLine:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -30)
pageLine:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -30)

local function Render(args, y)
  local row, rowW, rowH = {}, 0, 0
  local function flush()
    if #row == 0 then return end
    local x = 0
    for _, item in ipairs(row) do item.w:SetPoint("TOPLEFT", content, "TOPLEFT", x, -(y + rowH - item.h)); x = x + item.width + GAP end
    y = y + rowH + ROW_GAP; wipe(row); rowW, rowH = 0, 0
  end
  for _, entry in ipairs(Sorted(args)) do
    local opt = entry.opt
    opt.__key = entry.key
    if opt.type == "group" and opt.inline then
      flush()
      if y > 10 then y = y + SECTION_GAP end
      local header = SETUP.header({ name = opt.name }, CONTENT_W)
      header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
      y = Render(opt.args, y + 22 + 8)
    elseif SETUP[opt.type] then
      local full = opt.type == "header" or opt.type == "description" or opt.type == "range"
      local units = WidthOf(opt, full and 3 or 1); local width = math.floor(units * UNIT - GAP)
      if opt.newline or units >= 3 or (rowW + width) > CONTENT_W + 1 then flush() end
      if opt.type == "header" and y > 10 then y = y + SECTION_GAP end
      local w, h = SETUP[opt.type](opt, width)
      row[#row + 1] = { w = w, h = h, width = width }
      rowW = rowW + width + GAP; rowH = math.max(rowH, h)
      if units >= 3 then flush() end
    end
  end
  flush(); return y
end

local MAX_SEARCH_RESULTS = 40
local function SearchLower(value)
  value = tostring(value or "")
  if strlower then return strlower(value) end
  return string.lower(value)
end

local function SearchWordsMatch(words, path, name, description)
  local text = SearchLower(table.concat(path, " ") .. " " .. name .. " " .. tostring(description or ""))
  for _, word in ipairs(words) do
    if not string.find(text, word, 1, true) then return false end
  end
  return #words > 0
end

local function Extend(list, value)
  local copy = {}
  for i, item in ipairs(list) do copy[i] = item end
  if value and value ~= "" then copy[#copy + 1] = value end
  return copy
end

local function CollectSearchMatches(args, path, keyPath, words, results)
  local total = 0
  for _, entry in ipairs(Sorted(args)) do
    local opt = entry.opt
    local name = tostring(Eval(opt.name) or "")
    local nextPath = path
    local nextKeys = Extend(keyPath, entry.key)
    if opt.type == "group" then
      nextPath = Extend(path, name)
      total = total + CollectSearchMatches(opt.args, nextPath, nextKeys, words, results)
    elseif not opt.searchHidden and SETUP[opt.type] and opt.type ~= "description" and opt.type ~= "header" then
      local description = Eval(opt.desc)
      if SearchWordsMatch(words, path, name, description) then
        total = total + 1
        if #results < MAX_SEARCH_RESULTS then
          local copy = {}
          for key, value in pairs(opt) do copy[key] = value end
          results[#results + 1] = {
            key = table.concat(nextKeys, "\31"),
            option = copy,
            path = table.concat(path, " / "),
          }
        end
      end
    end
  end
  return total
end

local function FindSearchResults(query)
  local words, results, total = {}, {}, 0
  local foldedQuery = SearchLower(strtrim(query or ""))
  for word in foldedQuery:gmatch("%S+") do
    words[#words + 1] = word
  end
  if #words == 0 then return results, total end

  for _, pageEntry in ipairs(Sorted(ns.options.args)) do
    local page = pageEntry.opt
    local pageName = tostring(Eval(page.name) or "")
    local pagePath, pageKeys = { pageName }, { pageEntry.key }
    if page.commonArgs then
      total = total + CollectSearchMatches(page.commonArgs, Extend(pagePath, ns.L("search_common")), Extend(pageKeys, "common"), words, results)
    end
    if page.teamPages then
      for _, team in ipairs({ "ally", "enemy" }) do
        local teamPath = Extend(pagePath, ns.L(team == "ally" and "page_ally" or "page_enemy"))
        total = total + CollectSearchMatches(page.teamPages[team], teamPath, Extend(pageKeys, team), words, results)
      end
    elseif page.tabs then
      for _, tabEntry in ipairs(Sorted(page.tabs)) do
        local tab = tabEntry.opt
        local tabName = tostring(Eval(tab.name) or tabEntry.key)
        total = total + CollectSearchMatches(tab.args, Extend(pagePath, tabName), Extend(pageKeys, tabEntry.key), words, results)
      end
    elseif page.args then
      total = total + CollectSearchMatches(page.args, pagePath, pageKeys, words, results)
    end
  end
  return results, total
end

local function RenderSearchResults(query, y)
  local results, total = FindSearchResults(query)
  pageTitle:SetText(ns.L("search_results", total))
  if total == 0 then
    local message, height = SETUP.description({
      name = function() return ns.L("search_no_results") end,
      fontSize = "medium",
    }, CONTENT_W)
    message:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    return y + height + ROW_GAP
  end

  for _, result in ipairs(results) do
    local heading, height = SETUP.header({ name = function() return result.path end }, CONTENT_W)
    heading:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    y = y + height + 4
    y = Render({ [result.key] = result.option }, y)
    y = y + SECTION_GAP
  end

  if total > #results then
    local message, height = SETUP.description({
      name = function() return ns.L("search_more", #results, total) end,
      fontSize = "medium",
    }, CONTENT_W)
    message:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    y = y + height + ROW_GAP
  end
  return y
end

local current = "general"
local activePageTabs, pageTabButtons = {}, {}
local searchQuery = ""
local function PageTabClick(page, tab)
  return function()
    activePageTabs[page] = tab
    scroll:SetVerticalScroll(0)
    Refresh()
  end
end

local function Select(key)
  current = key; wipe(fieldErrors); wipe(fieldDrafts)
  if searchQuery ~= "" then
    searchQuery = ""
    searchBox:SetText("")
  end
  searchBox:ClearFocus()
  for pageKey, button in pairs(nav.buttons) do
    button.isCurrent = pageKey == key
    T.ApplyButtonColors(button)
  end
  scroll:SetVerticalScroll(0); Refresh()
end

local function NewPageButton(key)
  local button = T.MakeButton(nav, "", NAV_W, 24)
  button.key = key
  button.label:ClearAllPoints()
  button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
  button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
  button.label:SetJustifyH("LEFT")
  button.label:SetWordWrap(false)
  button:SetScript("OnClick", function(self) Select(self.key) end)
  button:HookScript("OnEnter", function(self)
    if self.label:IsTruncated() then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self:GetText())
      GameTooltip:Show()
    end
  end)
  button:HookScript("OnLeave", function(self)
    if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
  end)
  return button
end

local function BuildNavigation()
  local y = 0
  for i, section in ipairs(ns.options.navigation) do
    local heading = nav.headings[i]
    if not heading then
      heading = nav:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      heading:SetTextColor(unpack(T.DIM))
      nav.headings[i] = heading
    end
    heading:SetText(ns.L(section.label))
    heading:ClearAllPoints()
    heading:SetPoint("TOPLEFT", nav, "TOPLEFT", 3, -y)
    y = y + 19
    for _, key in ipairs(section.pages) do
      local option = ns.options.args[key]
      local button = nav.buttons[key] or NewPageButton(key)
      nav.buttons[key] = button
      button:SetText(Eval(option.name))
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -y)
      y = y + 27
    end
    y = y + 8
  end
  nav.language = ns.db.language or "auto"
end

local drawing, drawAgain = false, false

local function DrawTeamTabs(pageKey, pages, y)
  local buttons = pageTabButtons[pageKey]
  if not buttons then
    buttons = {}
    pageTabButtons[pageKey] = buttons
  end
  local tabWidth = math.floor((CONTENT_W - GAP) / 2)
  for i, team in ipairs({ "ally", "enemy" }) do
    local button = buttons[team]
    if not button then
      button = T.MakeButton(content, "", tabWidth, 24)
      buttons[team] = button
    end
    button:SetText(ns.L(team == "ally" and "page_ally" or "page_enemy"))
    button:SetSize(tabWidth, 24)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", content, "TOPLEFT", (i - 1) * (tabWidth + GAP), -y)
    button.isCurrent = (activePageTabs[pageKey] or "ally") == team
    button:SetScript("OnClick", PageTabClick(pageKey, team))
    button:Show()
    T.ApplyButtonColors(button)
  end
  return y + 34
end

local function DrawTabs(pageKey, tabs, y)
  local buttons = pageTabButtons[pageKey]
  if not buttons then
    buttons = {}
    pageTabButtons[pageKey] = buttons
  end
  local entries = Sorted(tabs)
  local active = activePageTabs[pageKey]
  local activeExists = false
  for _, entry in ipairs(entries) do
    if entry.key == active then activeExists = true; break end
  end
  if not activeExists and entries[1] then
    active = entries[1].key
    activePageTabs[pageKey] = active
  end

  local tabWidth = math.floor((CONTENT_W - GAP) / 2)
  for i, entry in ipairs(entries) do
    local button = buttons[entry.key]
    if not button then
      button = T.MakeButton(content, "", tabWidth, 24)
      buttons[entry.key] = button
    end
    button:SetText(tostring(Eval(entry.opt.name) or entry.key))
    button:SetSize(tabWidth, 24)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", content, "TOPLEFT", (i - 1) * (tabWidth + GAP), -y)
    button.isCurrent = active == entry.key
    button:SetScript("OnClick", PageTabClick(pageKey, entry.key))
    button:Show()
    T.ApplyButtonColors(button)
  end
  return y + 34
end

local function Draw()
  if nav.language ~= (ns.db.language or "auto") then BuildNavigation() end
  test:SetText(ns.L(ns.state == "test" and "preview_end" or "preview_start"))
  test:SetWidth(math.max(90, test.label:GetStringWidth() + 16))
  test:SetEnabled(not ns.inBG)
  if not frame:IsShown() or not current then return end
  local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  local keepKey, keepText
  if focus and focus.field and focus.field:IsShown() then keepKey, keepText = focus.field.key, focus:GetText() end
  menu:Hide(); ReleaseAll()
  for _, buttons in pairs(pageTabButtons) do
    for _, button in pairs(buttons) do button:Hide() end
  end
  local group = ns.options.args[current]
  searchPlaceholder:SetText(ns.L("search_settings"))
  searchPlaceholder:SetShown(searchBox:GetText() == "")
  searchClear:SetShown(searchBox:GetText() ~= "")
  local y = 40
  local query = strtrim(searchQuery or "")
  if query ~= "" then
    y = RenderSearchResults(query, y)
  else
    pageTitle:SetText(group and Eval(group.name) or "")
    if group and group.teamPages then
      y = DrawTeamTabs(current, group.teamPages, y)
    elseif group and group.tabs then
      y = DrawTabs(current, group.tabs, y)
    end
    if group and group.commonArgs then
      y = Render(group.commonArgs, y)
      y = y + SECTION_GAP
    end
    if group and group.teamPages then
      local team = activePageTabs[current] or "ally"
      y = Render(group.teamPages[team], y)
    elseif group and group.tabs then
      local active = activePageTabs[current]
      if not group.tabs[active] then
        local entries = Sorted(group.tabs)
        active = entries[1] and entries[1].key
      end
      local tab = active and group.tabs[active]
      y = Render(tab and tab.args, y)
    else
      y = Render(group and group.args, y)
    end
  end
  if keepKey then
    for _, w in ipairs(used) do
      if w.box and w.key == keepKey then w.box:SetText(keepText or ""); w.box:SetFocus(); break end
    end
  end
  content:SetHeight(math.max(y, 10))
  local max = math.max(0, content:GetHeight() - scroll:GetHeight())
  if scroll:GetVerticalScroll() > max then scroll:SetVerticalScroll(max) end
  UpdateThumb()
end

function Refresh()
  if drawing then drawAgain = true; return end
  drawing = true
  repeat drawAgain = false; Draw() until not drawAgain
  drawing = false
end

searchBox:SetScript("OnTextChanged", function(self)
  local value = self:GetText() or ""
  searchPlaceholder:SetShown(value == "")
  searchClear:SetShown(value ~= "")
  if value == searchQuery then return end
  searchQuery = value
  scroll:SetVerticalScroll(0)
  Refresh()
end)
searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
searchBox:SetScript("OnEscapePressed", function(self)
  self:SetText("")
  self:ClearFocus()
end)
searchBox:SetScript("OnEditFocusGained", function(self) T.AccentBorder(self, true) end)
searchBox:SetScript("OnEditFocusLost", function(self) T.AccentBorder(self, false) end)

local function FitWindow()
  local width, height = UIParent:GetWidth(), UIParent:GetHeight()
  if width > PAD * 2 and height > PAD * 2 then
    frame:SetScale(math.min(1, (width - PAD * 2) / W, (height - PAD * 2) / H))
  end
end

frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:RegisterEvent("UI_SCALE_CHANGED")
frame:SetScript("OnEvent", function() if frame:IsShown() then FitWindow() end end)
frame:SetScript("OnShow", function()
  FitWindow()
  BuildNavigation()
  Select(current)
end)
frame:SetScript("OnHide", function() menu:Hide(); confirm:Hide() end)

local refreshQueued = false
function ns.RefreshSettings()
  if refreshQueued or not frame:IsShown() then return end
  refreshQueued = true
  C_Timer.After(0, function()
    refreshQueued = false
    if frame:IsShown() then Refresh() end
  end)
end

function ns.ToggleSettings(page)
  if ns.Setup.active then ns.Setup:Dismiss() end
  if frame:IsShown() and not page then frame:Hide(); return end
  if page then current = page end
  frame:Show(); frame:Raise()
  if page then Select(page) end
  ns.RefreshSettings()
end
