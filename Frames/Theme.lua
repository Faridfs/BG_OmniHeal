local ADDON, ns = ...

-- Строгая черно-белая тема (Monochrome)
local T = {}
ns.Theme = T

-- ЦВЕТА (Черный, Серый, Белый)
T.BG = { 0.05, 0.05, 0.05, 0.95 }           -- Глубокий черный фон окна
T.BORDER = { 0.2, 0.2, 0.2, 1 }             -- Темно-серая рамка окна
T.FIELD = { 0.1, 0.1, 0.1, 1 }              -- Темно-серые поля ввода и неактивные кнопки
T.FIELD_BORDER = { 0.3, 0.3, 0.3, 1 }       -- Серая рамка полей
T.HOVER = { 0.18, 0.18, 0.18, 1 }           -- Светло-серый при наведении
T.ACCENT = { 1, 1, 1 }                      -- ЧИСТО БЕЛЫЙ (ползунки, выделение)
T.ON = { 1, 1, 1 }                          -- ЧИСТО БЕЛЫЙ (галочки чекбоксов)
T.DIM = { 0.6, 0.6, 0.6 }                   -- Серый текст (описания)
T.TEXT = { 1, 1, 1 }                        -- Белый текст

T.FONTS = {
  FRIZQT = "Fonts\\FRIZQT___CYR.TTF",
  ARIAL = "Fonts\\ARIALN.TTF",
  MORPHEUS = "Fonts\\MORPHEUS_CYR.TTF",
  SKURRI = "Fonts\\SKURRI_CYR.TTF",
}
T.FONT_NAMES = {
  FRIZQT = "Friz Quadrata (по умолчанию)",
  ARIAL = "Arial Narrow",
  MORPHEUS = "Morpheus",
  SKURRI = "Skurri",
}
T.FONT_ORDER = { "FRIZQT", "ARIAL", "MORPHEUS", "SKURRI" }

function T.GetFont()
  return T.FONTS[ns.db and ns.db.fontFace or "FRIZQT"] or T.FONTS.FRIZQT
end

-- ИСПОЛЬЗУЕМ ШРИФТ С ПОДДЕРЖКОЙ КИРИЛЛИЦЫ
T.TITLE_FONT = "Fonts\\FRIZQT___CYR.TTF"

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
T.MEDIA = MEDIA

function T.Hex(c)
  return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local PU = PixelUtil
local function Pt(region, point, a, b, c, d)
  local rel, relPoint, x, y
  if type(a) == "table" then
    rel, relPoint, x, y = a, b, c or 0, d or 0
  else
    rel, relPoint, x, y = region:GetParent(), point, a or 0, b or 0
  end
  if PU then
    PU.SetPoint(region, point, rel, relPoint, x, y)
  else
    region:SetPoint(point, rel, relPoint, x, y)
  end
end
local function Sz(region, w, h)
  if PU then PU.SetSize(region, w, h) else region:SetSize(w, h) end
end
local function Ht(region, h)
  if PU then PU.SetHeight(region, h) else region:SetHeight(h) end
end
local function Wd(region, w)
  if PU then PU.SetWidth(region, w) else region:SetWidth(w) end
end

local function Rounded(frame, r)
  if frame.SetBackdrop then frame:SetBackdrop(nil) end
  local fills, lines = {}, {}
  local function solid(layer, sub)
    local t = frame:CreateTexture(nil, layer, nil, sub)
    t:SetColorTexture(1, 1, 1, 1)
    return t
  end
  local function corner(layer, sub, file, point, flipX, flipY)
    local t = frame:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(MEDIA .. file .. r .. ".png")
    Sz(t, r, r)
    Pt(t, point)
    t:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1, flipY and 1 or 0, flipY and 0 or 1)
    return t
  end
  local c = solid("BACKGROUND", -8); Pt(c, "TOPLEFT", r, -r); Pt(c, "BOTTOMRIGHT", -r, r); fills[#fills + 1] = c
  local top = solid("BACKGROUND", -8); Pt(top, "TOPLEFT", r, 0); Pt(top, "BOTTOMRIGHT", frame, "TOPRIGHT", -r, -r); fills[#fills + 1] = top
  local bot = solid("BACKGROUND", -8); Pt(bot, "TOPLEFT", frame, "BOTTOMLEFT", r, r); Pt(bot, "BOTTOMRIGHT", -r, 0); fills[#fills + 1] = bot
  local lef = solid("BACKGROUND", -8); Pt(lef, "TOPLEFT", 0, -r); Pt(lef, "BOTTOMRIGHT", frame, "BOTTOMLEFT", r, r); fills[#fills + 1] = lef
  local rig = solid("BACKGROUND", -8); Pt(rig, "TOPLEFT", frame, "TOPRIGHT", -r, -r); Pt(rig, "BOTTOMRIGHT", 0, r); fills[#fills + 1] = rig
  fills[#fills + 1] = corner("BACKGROUND", -8, "corner-fill-", "TOPLEFT", false, false)
  fills[#fills + 1] = corner("BACKGROUND", -8, "corner-fill-", "TOPRIGHT", true, false)
  fills[#fills + 1] = corner("BACKGROUND", -8, "corner-fill-", "BOTTOMLEFT", false, true)
  fills[#fills + 1] = corner("BACKGROUND", -8, "corner-fill-", "BOTTOMRIGHT", true, true)
  local lt = solid("BORDER", 0); Ht(lt, 1); Pt(lt, "TOPLEFT", r, 0); Pt(lt, "TOPRIGHT", -r, 0); lines[#lines + 1] = lt
  local lb = solid("BORDER", 0); Ht(lb, 1); Pt(lb, "BOTTOMLEFT", r, 0); Pt(lb, "BOTTOMRIGHT", -r, 0); lines[#lines + 1] = lb
  local ll = solid("BORDER", 0); Wd(ll, 1); Pt(ll, "TOPLEFT", 0, -r); Pt(ll, "BOTTOMLEFT", 0, r); lines[#lines + 1] = ll
  local lr = solid("BORDER", 0); Wd(lr, 1); Pt(lr, "TOPRIGHT", 0, -r); Pt(lr, "BOTTOMRIGHT", 0, r); lines[#lines + 1] = lr
  lines[#lines + 1] = corner("BORDER", 0, "corner-line-", "TOPLEFT", false, false)
  lines[#lines + 1] = corner("BORDER", 0, "corner-line-", "TOPRIGHT", true, false)
  lines[#lines + 1] = corner("BORDER", 0, "corner-line-", "BOTTOMLEFT", false, true)
  lines[#lines + 1] = corner("BORDER", 0, "corner-line-", "BOTTOMRIGHT", true, true)

  frame.SetBackdropColor = function(_, cr, cg, cb, ca)
    for _, t in ipairs(fills) do t:SetVertexColor(cr, cg, cb, ca or 1) end
  end
  frame.SetBackdropBorderColor = function(_, cr, cg, cb, ca)
    for _, t in ipairs(lines) do t:SetVertexColor(cr, cg, cb, ca or 1) end
  end
end

T.Round = Rounded

local skinned = {}
function T.Backdrop(frame, fill, border, radius)
  Rounded(frame, radius or 4)
  frame.bbFill, frame.bbBorder = fill or T.BG, border or T.BORDER
  frame:SetBackdropColor(unpack(frame.bbFill))
  frame:SetBackdropBorderColor(unpack(frame.bbBorder))
  skinned[#skinned + 1] = frame
end

function T.Panel(frame, radius)
  T.Backdrop(frame, T.BG, T.BORDER, radius or 6)
  local glow = frame:CreateTexture(nil, "BORDER", nil, 1)
  glow:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.18)
  Pt(glow, "TOPLEFT", 6, -1)
  Pt(glow, "TOPRIGHT", -6, -1)
  Ht(glow, 1)
  frame.bbGlow = glow
end

function T.Title(parent, size, version)
  local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  pcall(title.SetFont, title, T.TITLE_FONT, size or 17, "")
  title:SetText(T.Hex(T.TEXT) .. "BG |r" .. T.Hex(T.ACCENT) .. "OmniHeal|r")
  local ver
  if version then
    ver = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 6, -2)
    ver:SetText(version)
  end
  return title, ver
end

function T.Divider(parent)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 0.07)
  Ht(line, 1)
  return line
end

function T.Section(parent, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetText(string.upper(text))
  fs:SetTextColor(unpack(T.DIM))
  local line = T.Divider(parent)
  Pt(line, "LEFT", fs, "RIGHT", 8, 0)
  Pt(line, "RIGHT", parent, "RIGHT", 0, 0)
  fs.line = line
  return fs
end

function T.AccentBorder(frame, on, alpha, color)
  color = color or T.ACCENT
  if on then
    frame:SetBackdropBorderColor(color[1], color[2], color[3], alpha or 0.8)
  else
    frame:SetBackdropBorderColor(unpack(T.FIELD_BORDER))
  end
end

function T.ApplyButtonColors(btn, hover)
  if not btn.bbFill then return end
  
  if btn.isCurrent then
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    T.AccentBorder(btn, true, 1, { 1, 1, 1 })
  else
    btn:SetBackdropColor(unpack(hover and T.HOVER or T.FIELD))
    T.AccentBorder(btn, btn.bbAccent)
  end
  
  local label = btn.label or btn:GetFontString()
  if label and btn.isCurrent then
    label:SetTextColor(1, 1, 1)
  elseif label and btn.bbFontsSet then
    local active = (not btn.IsEnabled) or btn:IsEnabled()
    local textColor = (not active and btn.forceWhiteDisabledText) and T.BUTTON_TEXT or (active and T.BUTTON_TEXT or T.BUTTON_TEXT_OFF)
    label:SetTextColor(unpack(textColor))
  end
end

T.BUTTON_TEXT = { 1, 1, 1, 1 }
T.BUTTON_TEXT_OFF = { 0.45, 0.47, 0.56, 1 }
local fontOn = CreateFont("OmniHealButtonFont")
fontOn:CopyFontObject(GameFontHighlightSmall)
fontOn:SetTextColor(unpack(T.BUTTON_TEXT))
local fontOff = CreateFont("OmniHealButtonFontDisabled")
fontOff:CopyFontObject(GameFontHighlightSmall)
fontOff:SetTextColor(unpack(T.BUTTON_TEXT_OFF))

function T.SkinButton(btn, accent)
  local text = btn:GetText()
  T.Backdrop(btn, T.FIELD, T.FIELD_BORDER, 3)
  btn.bbAccent = accent
  if not btn.label then
    btn.label = btn:CreateFontString(nil, "OVERLAY", accent and "GameFontNormalSmall" or "GameFontHighlightSmall")
    btn.label:SetPoint("CENTER", 0, 0)
    btn:SetFontString(btn.label)
  end
  btn:SetNormalFontObject(fontOn)
  btn:SetHighlightFontObject(fontOn)
  btn:SetDisabledFontObject(fontOff)
  btn.bbFontsSet = true
  btn:SetText(text or "")
  btn:SetPushedTextOffset(0, -1)
  btn.isCurrent = btn.isCurrent or false
  local function hook(ev, fn)
    if btn:GetScript(ev) then btn:HookScript(ev, fn) else btn:SetScript(ev, fn) end
  end
  hook("OnEnter", function(self) T.ApplyButtonColors(self, self:IsEnabled()) end)
  hook("OnLeave", function(self) T.ApplyButtonColors(self) end)
  hook("OnEnable", function(self) T.ApplyButtonColors(self) end)
  hook("OnDisable", function(self) T.ApplyButtonColors(self) end)
  T.ApplyButtonColors(btn)
end

function T.MakeButton(parent, text, w, h, accent)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  Sz(b, w, h)
  b:SetText(text)
  T.SkinButton(b, accent)
  return b
end

function T.Apply()
end
