local _, ns = ...
local T = ns.Theme

local Row = {}
ns.Row = Row

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ROUND_MASK = T.MEDIA .. "rounded-mask.png"
local RADIUS = 4
local MAX_BUBBLES = 6
local NEUTRAL_BAR = { 0.2, 0.65, 0.25 }
local VEHICLE_ICON = "|TInterface\\Icons\\INV_Misc_Wrench_01:0:0:0:0:64:64:6:58:6:58|t "
local VEHICLE_NAME = { 0.55, 0.68, 0.85 }
local VEHICLE_BAR = { 0.3, 0.38, 0.5 }
local MANA_COLOR = { 0, 0.44, 0.87 }

Row.ROUND_MASK = ROUND_MASK

Row.STYLES = { bars = "Bars", cards = "Cards", compact = "Compact", minimal = "Minimal" }
Row.STYLE_ORDER = { "bars", "cards", "compact", "minimal" }
Row.STYLE_DESC = "Bars: the row is the bar. Cards: themed row with a class-colored edge. Compact: small bars and smaller text. Minimal: outlined names over a thin line, no background."

Row.ROLE_MARKERS = { both = "Icon and tag", icon = "Icon", text = "Tag (HEAL / TANK)", off = "Off" }
Row.ROLE_MARKER_ORDER = { "both", "icon", "text", "off" }

local function ClassColor(class)
  local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or RAID_CLASS_COLORS[class])
  if c then return c.r, c.g, c.b end
  return 0.5, 0.5, 0.5
end
Row.ClassColor = ClassColor

local ROLE_ATLAS = {
  HEALER = { "UI-LFG-RoleIcon-Healer", "roleicon-tiny-healer" },
  TANK = { "UI-LFG-RoleIcon-Tank", "roleicon-tiny-tank" },
}
local ROLE_SHEET = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = { HEALER = { 20, 39, 1, 20 }, TANK = { 0, 19, 22, 41 } }
local ROLE_TAGS = { HEALER = "|cff3dff7aHEAL|r ", TANK = "|cff58a6ffTANK|r " }
local roleIconCache = {}

local function RoleIcon(role, size)
  local cacheKey = role .. size
  if roleIconCache[cacheKey] then return roleIconCache[cacheKey] end
  local markup
  for _, atlas in ipairs(ROLE_ATLAS[role]) do
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
      markup = CreateAtlasMarkup and CreateAtlasMarkup(atlas, size, size) or ("|A:" .. atlas .. ":" .. size .. ":" .. size .. "|a")
      break
    end
  end
  if not markup then
    local c = ROLE_COORDS[role]
    markup = string.format("|T%s:%d:%d:0:0:64:64:%d:%d:%d:%d|t", ROLE_SHEET, size, size, c[1], c[2], c[3], c[4])
  end
  markup = markup .. " "
  roleIconCache[cacheKey] = markup
  return markup
end

local function NewDot(parent, layer)
  local t = parent:CreateTexture(nil, layer); t:SetTexture(CIRCLE); t:Hide(); return t
end

function Row.RoundTexture(parent, texture)
  local mask = parent:CreateMaskTexture()
  mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(texture); texture:AddMaskTexture(mask)
  return mask
end

local function EnsureGlow(row)
  local glow = row.glow
  if glow then return glow end
  glow = CreateFrame("Frame", nil, row)
  glow:SetPoint("TOPLEFT", -3, 3); glow:SetPoint("BOTTOMRIGHT", 3, -3); glow:SetFrameLevel(row:GetFrameLevel() + 8)
  T.Round(glow, 6); glow:SetBackdropColor(1, 0.1, 0.1, 0.35); glow:SetBackdropBorderColor(1, 0.1, 0.1, 1)
  glow.rings = {}
  for i = 1, 2 do
    local ring = CreateFrame("Frame", nil, glow)
    glow.rings[i] = ring
    ring:SetPoint("TOPLEFT", i, -i); ring:SetPoint("BOTTOMRIGHT", -i, i)
    T.Round(ring, i == 1 and 6 or 4); ring:SetBackdropColor(0, 0, 0, 0); ring:SetBackdropBorderColor(1, 0.1, 0.1, 1)
  end
  glow:Hide()
  local anim = glow:CreateAnimationGroup()
  for i = 1, 3 do
    local on = anim:CreateAnimation("Alpha"); on:SetOrder(i * 2 - 1); on:SetFromAlpha(0); on:SetToAlpha(1); on:SetDuration(0.15)
    local off = anim:CreateAnimation("Alpha"); off:SetOrder(i * 2); off:SetFromAlpha(1); off:SetToAlpha(0); off:SetDuration(i == 3 and 0.6 or 0.25)
  end
  anim:SetScript("OnFinished", function() glow:Hide() end)
  glow.anim = anim; row.glow = glow
  if Row.ApplyLayers then Row.ApplyLayers(row) end
  return glow
end

function Row.Create(parent, name, team)
  local template = team == "ally" and "SecureUnitButtonTemplate" or "SecureActionButtonTemplate"
  local row = CreateFrame("Button", name, parent, template)
  row.team = team
  row:RegisterForClicks("AnyUp")
  if team ~= "ally" then row:SetAttribute("useOnKeyDown", false) end
  T.Round(row, RADIUS)
  row:SetBackdropColor(0, 0, 0, 0.6); row:SetBackdropBorderColor(1, 1, 1, 0)
  row:SetScript("PreClick", function(self, button)
    if self.rec and self.rec.team == "enemy" and not IsShiftKeyDown() then
      ns.Live:NoteClick(self.rec, button == "RightButton" and "focus" or "target")
    end
  end)

  local content = CreateFrame("Frame", nil, row); content:SetAllPoints(); content:SetFrameLevel(row:GetFrameLevel() + 2)
  row.content = content

  local premadeFrame = CreateFrame("Frame", nil, row)
  premadeFrame:SetAllPoints()
  premadeFrame:SetFrameLevel(row:GetFrameLevel() + 20)
  row.premadeFrame = premadeFrame
  
  row.premadeIcon = premadeFrame:CreateTexture(nil, "OVERLAY")
  row.premadeIcon:SetTexture("Interface\\Icons\\Ability_DualWield")
  row.premadeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.premadeIcon:SetBlendMode("ADD")
  Row.RoundTexture(premadeFrame, row.premadeIcon)
  row.premadeIcon:Hide()

  local identity = CreateFrame("Frame", nil, content); identity:SetAllPoints(); identity:SetFrameLevel(content:GetFrameLevel() + 1)
  row.identity = identity
  local stripe = identity:CreateTexture(nil, "ARTWORK"); stripe:SetColorTexture(1, 1, 1, 1); stripe:SetWidth(3); stripe:Hide()
  row.stripe = stripe

  row.icon = identity:CreateTexture(nil, "ARTWORK"); Row.RoundTexture(identity, row.icon)

  local hp = CreateFrame("StatusBar", nil, content); hp:SetMinMaxValues(0, 1); hp:SetValue(1)
  hp.bg = hp:CreateTexture(nil, "BACKGROUND"); hp.bg:SetAllPoints(); hp.bg:SetColorTexture(0, 0, 0, 0.45)
  row.health = hp

  local power = CreateFrame("StatusBar", nil, content); power:SetStatusBarTexture(WHITE); power:SetStatusBarColor(MANA_COLOR[1], MANA_COLOR[2], MANA_COLOR[3])
  power:SetMinMaxValues(0, 1); power:SetValue(1)
  power.bg = power:CreateTexture(nil, "BACKGROUND"); power.bg:SetAllPoints(); power.bg:SetColorTexture(0, 0, 0, 0.5); power:Hide()
  row.power = power

  local text = CreateFrame("Frame", nil, content); text:SetAllPoints(); text:SetFrameLevel(content:GetFrameLevel() + 3)
  row.text = text
  local function TextFrame()
    local frame = CreateFrame("Frame", nil, text); frame:SetAllPoints(); frame:SetFrameLevel(text:GetFrameLevel() + 1)
    return frame
  end
  row.counterFrame = TextFrame(); row.counter = row.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.statusFrame = TextFrame(); row.status = row.statusFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.hpTextFrame = TextFrame(); row.hpText = row.hpTextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.status:SetTextColor(1, 0.35, 0.35)
  row.carrierFrame = TextFrame(); row.carrier = row.carrierFrame:CreateTexture(nil, "OVERLAY"); row.carrier:SetSize(14, 14); row.carrier:Hide()
  row.nameFrame = TextFrame(); row.name = row.nameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)

  row.barArea = CreateFrame("Frame", nil, content)

  local auras = CreateFrame("Frame", nil, content); auras:SetFrameLevel(content:GetFrameLevel() + 8); auras:SetSize(1, 1); auras.icons = {}; row.auras = auras
  local dispels = CreateFrame("Frame", nil, content); dispels:SetFrameLevel(content:GetFrameLevel() + 9); dispels:SetSize(1, 1); dispels.icons = {}; row.dispels = dispels
  local externals = CreateFrame("Frame", nil, content); externals:SetFrameLevel(content:GetFrameLevel() + 7); externals:SetSize(1, 1); externals.icons = {}; row.externals = externals
  
  local allyCC = CreateFrame("Frame", nil, content); allyCC:SetFrameLevel(content:GetFrameLevel() + 10); allyCC:SetSize(1, 1); allyCC.icons = {}; row.allyCC = allyCC
  local enemyCC = CreateFrame("Frame", nil, content); enemyCC:SetFrameLevel(content:GetFrameLevel() + 10); enemyCC:SetSize(1, 1); enemyCC.icons = {}; row.enemyCC = enemyCC
  
  local defs = CreateFrame("Frame", nil, content); defs:SetFrameLevel(content:GetFrameLevel() + 10); defs:SetSize(1, 1); defs.icons = {}; row.defs = defs
  local trinket = CreateFrame("Frame", nil, content); trinket:SetFrameLevel(content:GetFrameLevel() + 10); trinket:SetSize(1, 1); trinket.icons = {}; row.trinket = trinket

  local bubbles = CreateFrame("Frame", nil, content); bubbles:SetFrameLevel(content:GetFrameLevel() + 5); bubbles:SetSize(1, 1); bubbles.marks, bubbles.shown = {}, {}; row.bubbles = bubbles
  local healerMarks = CreateFrame("Frame", nil, content); healerMarks:SetFrameLevel(content:GetFrameLevel() + 5); healerMarks:SetSize(1, 1); healerMarks.marks, healerMarks.shown = {}, {}; row.healerMarks = healerMarks

  return row
end

local ROW_LAYER_DEFAULTS = {
  allyHealthBarLayer = 1, enemyHealthBarLayer = 1, allyManaBarLayer = 1,
  allyUnitIconLayer = 1, enemyUnitIconLayer = 1,
  allyNameLayer = 3, enemyNameLayer = 3, allyHpTextLayer = 3, enemyHpTextLayer = 3,
  allyDeadTextLayer = 3, enemyDeadTextLayer = 3, allyCarrierIconLayer = 3, enemyCarrierIconLayer = 3,
  allyCountLayer = 3, enemyCountLayer = 3, allyTargetMarkLayer = 5, enemyTargetMarkLayer = 5,
  allyHealerMarkLayer = 5, premadeLayer = 5, allyVehicleBorderLayer = 4, enemyVehicleBorderLayer = 4,
  allyTargetGlowLayer = 4, enemyTargetGlowLayer = 4,
}

function Row.ApplyLayers(row)
  if not row or not row.content then return end
  local base = row.content:GetFrameLevel()
  local function Put(frame, key)
    local rank = tonumber(ns.db[key]) or ROW_LAYER_DEFAULTS[key]
    if frame and rank then pcall(frame.SetFrameLevel, frame, base + rank * 4) end
  end
  local team = row.team or "enemy"
  Put(row.health, team .. "HealthBarLayer")
  if team == "ally" then Put(row.power, "allyManaBarLayer") end
  Put(row.identity, team .. "UnitIconLayer")
  Put(row.nameFrame, team .. "NameLayer")
  Put(row.hpTextFrame, team .. "HpTextLayer")
  Put(row.statusFrame, team .. "DeadTextLayer")
  Put(row.counterFrame, team .. "CountLayer")
  Put(row.carrierFrame, team .. "CarrierIconLayer")
  Put(row.bubbles, team .. "TargetMarkLayer")
  if team == "ally" then Put(row.healerMarks, "allyHealerMarkLayer") end
  Put(row.premadeFrame, "premadeLayer")
  Put(row.glow, team .. "TargetGlowLayer")
  Put(row.vehicleRing, team .. "VehicleBorderLayer")
  if row.glow and row.glow.rings then
    for i, ring in ipairs(row.glow.rings) do pcall(ring.SetFrameLevel, ring, row.glow:GetFrameLevel() + i) end
  end
  if row.vehicleRing and row.vehicleRing.inner then
    pcall(row.vehicleRing.inner.SetFrameLevel, row.vehicleRing.inner, row.vehicleRing:GetFrameLevel() + 1)
  end
end

local function PlaceBars(row, left, top, right, bottom, manaH)
  local hp, power = row.health, row.power
  hp:ClearAllPoints(); power:ClearAllPoints()
  if manaH > 0 then
    power:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", left, bottom); power:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -right, bottom)
    power:SetHeight(manaH); power:Show(); bottom = bottom + manaH + 1
  else power:Hide() end
  hp:SetPoint("TOPLEFT", row, "TOPLEFT", left, -top); hp:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -right, bottom)
end

local function PlaceThin(row, left, right, bottom, barH, manaH)
  local hp, power = row.health, row.power
  hp:ClearAllPoints(); power:ClearAllPoints()
  if manaH > 0 then
    power:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", left, bottom); power:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -right, bottom)
    power:SetHeight(manaH); power:Show(); bottom = bottom + manaH + 1
  else power:Hide() end
  hp:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", left, bottom); hp:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -right, bottom); hp:SetHeight(barH)
  return bottom + barH
end

local TEXT_ELEMENTS = {
  { "counter", "count", -3 }, { "hpText", "hpText", -2 }, { "status", "deadText", -2 }, { "carrier", "carrier", -2 },
}

local function PlaceText(row, left, right, y, nameX, nameY, tdb)
  local db = ns.db
  local prev, carry = nil, 0
  for _, e in ipairs(TEXT_ELEMENTS) do
    local el, key, gap = row[e[1]], e[2], e[3]
    local anchor, ox, oy
    
    if key == "carrier" then
      anchor = tdb.carrierAnchor or "auto"
      ox, oy = tdb.carrierX or 0, tdb.carrierY or 0
    else
      local team = row.team or "enemy"
      local settingKey = key
      if key == "count" then settingKey = team .. "Count"
      elseif key == "hpText" then settingKey = team .. "HpText"
      elseif key == "deadText" then settingKey = team .. "DeadText" end
      anchor = db[settingKey .. "Anchor"] or db[key .. "Anchor"] or "auto"
      ox, oy = db[settingKey .. "X"] or db[key .. "X"] or 0,
        db[settingKey .. "Y"] or db[key .. "Y"] or 0
    end
    
    el:ClearAllPoints()
    if anchor ~= "auto" then el:SetPoint(anchor, row.barArea, anchor, ox, oy); carry = carry + gap
    elseif prev then el:SetPoint("RIGHT", prev, "LEFT", gap + carry + ox, oy); prev, carry = el, 0
    else el:SetPoint("RIGHT", row, "RIGHT", -right + gap + carry + ox, y + oy); prev, carry = el, 0 end
  end
  row.name:ClearAllPoints()
  row.name:SetPoint("LEFT", row, "LEFT", left + 3 + (nameX or 0), y + (nameY or 0))
  if prev then row.name:SetPoint("RIGHT", prev, "LEFT", -2 + carry, nameY or 0)
  else row.name:SetPoint("RIGHT", row, "RIGHT", -right - 3, y + (nameY or 0)) end
end

local function SetBarArea(row, left, top, right, bottom)
  local area = row.barArea
  area:ClearAllPoints(); area:SetPoint("TOPLEFT", row, "TOPLEFT", left, -top); area:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -right, bottom)
end

local function PlaceIcon(row, x, y, size)
  row.icon:ClearAllPoints(); row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", x, -y); row.icon:SetSize(size, size); row.icon:Show()
end

local function PlaceMarkGroup(row, group, key, baseSize, autoPoint, autoY)
  local db = ns.db
  local size = math.max(3, math.floor(baseSize * (db[key .. "Scale"] or 1) + 0.5))
  group.size = size; group.shape = db[key .. "Shape"]
  local anchor = db[key .. "Anchor"] or "auto"
  local ox, oy = db[key .. "X"] or 0, db[key .. "Y"] or 0
  group:ClearAllPoints()
  if anchor == "auto" then group:SetPoint(autoPoint, row, autoPoint, ox, autoY + oy)
  else
    local point, at, x, y = Row.AuraPoint(anchor, db[key .. "Grow"])
    group:SetPoint(point, row.barArea, at, x + ox, y + oy)
  end
  group:SetHeight(size)
end

function Row.Apply(row, tdb, h, manaH)
  local style = Row.STYLES[tdb.style] and tdb.style or "bars"
  row.style = style
  local font, size, flags = T.GetFont(), tdb.fontSize, ""
  row.stripe:Hide(); row.icon:Hide(); row.restBorder = nil
  row:SetBackdropColor(0, 0, 0, 0)
  local texture = ns.Frames.BAR_TEXTURES[tdb.barTexture] or ns.Frames.BAR_TEXTURES.blizzard
  local inset = 2

  if style == "bars" or style == "compact" or style == "cards" then
    local left = inset
    if style == "cards" then
      inset, left = 3, 7
      row:SetBackdropColor(T.FIELD[1], T.FIELD[2], T.FIELD[3], tdb.bgAlpha)
      row.restBorder = T.FIELD_BORDER
      row.stripe:ClearAllPoints(); row.stripe:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3); row.stripe:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 3); row.stripe:Show()
    end
    if style == "compact" then size = math.max(size - 1, 6) end
    if tdb.iconType ~= "none" then
      local iconSize = h - inset * 2
      PlaceIcon(row, left, inset, iconSize)
      left = left + iconSize + 2
    end
    PlaceBars(row, left, inset, inset, inset, manaH)
    SetBarArea(row, left, inset, inset, inset)
    PlaceText(row, left, inset, manaH > 0 and (manaH + 1) / 2 or 0, tdb.nameOffsetX, tdb.nameOffsetY, tdb)
  else
    flags = "OUTLINE"
    local barTop = PlaceThin(row, 2, 2, 1, 2, manaH > 0 and 2 or 0)
    SetBarArea(row, 2, 1, 2, 1)
    PlaceText(row, 0, 1, barTop / 2, tdb.nameOffsetX, tdb.nameOffsetY, tdb)
    texture = WHITE
  end

  row.health:SetStatusBarTexture(texture)
  row.name:SetFont(font, size, flags)
  local db = ns.db
  local countScale = db[(row.team or "enemy") .. "CountScale"] or db.countScale or 1
  row.counter:SetFont(font, math.max(6, math.floor((size + 2) * countScale + 0.5)), "OUTLINE")
  local team = row.team or "enemy"
  row.hpText:SetFont(font, math.max(6, math.floor(math.max(size - 1, 6) * (db[team .. "HpTextScale"] or db.hpTextScale or 1) + 0.5)), flags)
  row.status:SetFont(font, math.max(6, math.floor(math.max(size - 1, 6) * (db[team .. "DeadTextScale"] or db.deadTextScale or 1) + 0.5)), flags)
  
  local carrier = math.max(6, math.floor(14 * (tdb.carrierScale or 1) + 0.5))
  row.carrier:SetSize(carrier, carrier)
  
  row.fontSize = size; row.inset = inset; row.rowHeight = h

  local dot = math.max(5, math.min(12, math.floor(h / 3)))
  PlaceMarkGroup(row, row.bubbles, (row.team or "enemy") .. "TargetMark", dot, "BOTTOM", 1)
  PlaceMarkGroup(row, row.healerMarks, "healerMark", dot + 2, "TOP", -1)

  if row.premadeIcon then
    row.premadeIcon:SetSize(db.premadeIconSize, db.premadeIconSize)
    row.premadeIcon:ClearAllPoints()
    row.premadeIcon:SetPoint("CENTER", row, "CENTER", db.premadeOffsetX, db.premadeOffsetY)
  end
  Row.ApplyLayers(row)
end

function Row.RestBorder(row)
  local c = row.restBorder
  if c then row:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
  else row:SetBackdropBorderColor(1, 1, 1, 0) end
end

function Row.SetIdentity(row, rec, tdb)
  local name = (tdb.showRealm and rec.fullName) or rec.name or rec.key
  local marker = tdb.roleMarker
  local role = rec.role
  if (role == "HEALER" or role == "TANK") and marker ~= "off" then
    local prefix = ""
    if marker == "both" or marker == "icon" then prefix = RoleIcon(role, row.fontSize + 3) end
    if marker == "both" or marker == "text" then prefix = prefix .. ROLE_TAGS[role] end
    name = prefix .. name
  end
  if rec.inVehicle then name = VEHICLE_ICON .. name end
  row.name:SetText(name)

  local style = row.style
  if rec.inVehicle then row.name:SetTextColor(VEHICLE_NAME[1], VEHICLE_NAME[2], VEHICLE_NAME[3])
  elseif style == "minimal" or not tdb.classColorBars then row.name:SetTextColor(ClassColor(rec.class))
  else row.name:SetTextColor(1, 1, 1) end
  row.stripe:SetVertexColor(ClassColor(rec.class))

  if row.icon:IsShown() then
    if rec.specIcon and tdb.iconType ~= "class" then row.icon:SetTexture(rec.specIcon); row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif rec.class then row.icon:SetAtlas("classicon-" .. rec.class:lower())
    else row.icon:SetColorTexture(0.2, 0.2, 0.2) end
  end
end

function Row.SetBarColor(row, rec, tdb)
  if rec.dead then row.health:SetStatusBarColor(0.3, 0.3, 0.3)
  elseif rec.inVehicle then row.health:SetStatusBarColor(VEHICLE_BAR[1], VEHICLE_BAR[2], VEHICLE_BAR[3])
  elseif row.style == "minimal" or tdb.classColorBars then
    local r, g, b = ClassColor(rec.class)
    row.health:SetStatusBarColor(r * 0.75, g * 0.75, b * 0.75, 1)
  else row.health:SetStatusBarColor(NEUTRAL_BAR[1], NEUTRAL_BAR[2], NEUTRAL_BAR[3]) end
end

local function NewMark(group, shape)
  if shape ~= "cross" then
    local ring = NewDot(group, "ARTWORK"); ring:SetVertexColor(0, 0, 0, 0.9)
    return { shape = shape, ring = ring, dot = NewDot(group, "OVERLAY") }
  end
  local function Bar(layer) local t = group:CreateTexture(nil, layer); t:SetColorTexture(1, 1, 1, 1); t:Hide(); return t end
  return { shape = "cross", outlineH = Bar("ARTWORK"), outlineV = Bar("ARTWORK"), h = Bar("OVERLAY"), v = Bar("OVERLAY") }
end

local function PlaceMark(m, group, x, size, top, r, g, b)
  local corner = top and "TOPLEFT" or "BOTTOMLEFT"
  if m.shape ~= "cross" then
    local tex = m.shape == "square" and WHITE or CIRCLE
    m.ring:SetTexture(tex); m.dot:SetTexture(tex)
    m.ring:ClearAllPoints(); m.ring:SetPoint(corner, group, corner, x - 1, top and 1 or -1); m.ring:SetSize(size + 2, size + 2)
    m.dot:ClearAllPoints(); m.dot:SetPoint(corner, group, corner, x, 0); m.dot:SetSize(size, size); m.dot:SetVertexColor(r, g, b)
    m.ring:Show(); m.dot:Show()
    return
  end
  local bar = math.max(3, math.floor(size * 0.45 + 0.5))
  local cx, cy = x + size / 2, top and -size / 2 or size / 2
  for _, part in ipairs({ { m.outlineH, size + 2, bar + 2 }, { m.outlineV, bar + 2, size + 2 }, { m.h, size, bar }, { m.v, bar, size } }) do
    local t = part[1]
    t:ClearAllPoints(); t:SetPoint("CENTER", group, corner, cx, cy); t:SetSize(part[2], part[3]); t:Show()
  end
  m.outlineH:SetVertexColor(0, 0, 0, 0.9); m.outlineV:SetVertexColor(0, 0, 0, 0.9); m.h:SetVertexColor(r, g, b); m.v:SetVertexColor(r, g, b)
end

local function HideMark(m) for _, t in pairs(m) do if type(t) == "table" then t:Hide() end end end

local function SetMarks(group, classes, show, top)
  local shape = group.shape or "circle"
  local gap = shape == "cross" and 2 or 1
  local count = show and #classes or 0
  local same = count == #group.shown
  if same then
    for i = 1, count do if group.shown[i] ~= classes[i] then same = false; break end end
  end
  if same then return end
  wipe(group.shown)
  local shown = math.min(count, MAX_BUBBLES)
  local size = group.size or 6
  group:SetWidth(math.max(shown * size + math.max(shown - 1, 0) * gap, 1))
  for i = 1, math.max(shown, #group.marks) do
    local m = group.marks[i]
    if i <= shown then
      if not m or m.shape ~= shape then
        if m then HideMark(m) end
        m = NewMark(group, shape); group.marks[i] = m
      end
      PlaceMark(m, group, (i - 1) * (size + gap), size, top, ClassColor(classes[i]))
    elseif m then HideMark(m) end
  end
  for i = 1, count do group.shown[i] = classes[i] end
  if count > shown or group.more then
    if not group.more then
      group.more = group:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); group.more:SetPoint("LEFT", group, "RIGHT", 2, 0)
    end
    group.more:SetText(count > shown and ("+" .. (count - shown)) or "")
  end
end

function Row.ClearMarks(row)
  for _, group in ipairs({ row.bubbles, row.healerMarks }) do
    for _, m in ipairs(group.marks) do HideMark(m) end
    wipe(group.shown)
    if group.more then group.more:SetText("") end
  end
end

function Row.SetBubbles(row, classes, show) SetMarks(row.bubbles, classes, show, false) end
function Row.SetHealerMarks(row, classes, show) SetMarks(row.healerMarks, classes, show, true) end

function Row.SetVehicleBorder(row, on)
  local ring = row.vehicleRing
  if not on then if ring then ring:Hide(); Row.ApplyLayers(row) end return end
  if not ring then
    ring = CreateFrame("Frame", nil, row)
    ring:SetPoint("TOPLEFT", 1, -1); ring:SetPoint("BOTTOMRIGHT", -1, 1); ring:SetFrameLevel(row:GetFrameLevel() + 7)
    T.Round(ring, RADIUS); ring:SetBackdropColor(0, 0, 0, 0); ring:SetBackdropBorderColor(VEHICLE_NAME[1], VEHICLE_NAME[2], VEHICLE_NAME[3], 1)
    local inner = CreateFrame("Frame", nil, ring)
    inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1); T.Round(inner, 3)
    inner:SetBackdropColor(0, 0, 0, 0); inner:SetBackdropBorderColor(VEHICLE_NAME[1], VEHICLE_NAME[2], VEHICLE_NAME[3], 1)
    ring.inner = inner
    row.vehicleRing = ring
  end
  ring:Show()
  Row.ApplyLayers(row)
end

function Row.Flash(row)
  local glow = EnsureGlow(row)
  glow.anim:Stop(); glow:Show(); glow.anim:Play()
end

function Row.StopFlash(row)
  if row.glow then row.glow.anim:Stop(); row.glow:Hide() end
end
