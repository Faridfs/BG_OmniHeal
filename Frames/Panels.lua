local _, ns = ...
local Frames = ns:NewModule("Frames")
local Row = ns.Row

local WHITE = "Interface\\Buttons\\WHITE8X8"
local HEADER_HEIGHT = 14

Frames.BAR_TEXTURES = {
  blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
  flat = WHITE,
  raid = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}
Frames.BAR_TEXTURE_NAMES = { blizzard = "Blizzard", flat = "Flat", raid = "Raid frame" }

local OTHER_FACTION = { Alliance = "Horde", Horde = "Alliance" }

function ns:MyFaction()
  if ns.state == "bg" then
    local team = ns.Roster.team or ns.Plain(GetBattlefieldArenaFaction())
    if team == 0 then return "Horde"
    elseif team == 1 then return "Alliance" end
  end
  local faction = UnitFactionGroup("player")
  return (faction == "Horde" or faction == "Alliance") and faction or "Alliance"
end

function ns:TeamFaction(team)
  local mine = ns:MyFaction()
  return team == "ally" and mine or OTHER_FACTION[mine]
end

local CARRIER_SPELLS = {
  Alliance = 156621, Horde = 156618, Flag = 34976, Blue = 121164, Purple = 121175, Green = 121176, Orange = 121177,
}
local carrierIcons = {}
local function CarrierIcon(tag)
  local icon = carrierIcons[tag]
  if not icon then
    local id = CARRIER_SPELLS[tag]
    icon = id and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
    carrierIcons[tag] = icon
  end
  return icon
end
local CARRIER_COLORS = {
  Flag = { 1, 1, 1 }, Blue = { 0.25, 0.5, 1 }, Purple = { 0.7, 0.3, 1 }, Green = { 0.3, 1, 0.3 }, Orange = { 1, 0.6, 0.1 },
}
local DEAD_ICON = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:0|t"

local containers = {}

local function DefaultPoint(team)
  if team == "enemy" then return "LEFT", "CENTER", 300, 100 end
  return "RIGHT", "CENTER", -300, 100
end

local function RestorePosition(f)
  local saved = ns:FrameSettings().positions[ns:Bracket()]
  local p = saved and saved[f.team]
  local point, relPoint, x, y
  if p then
    point, relPoint, x, y = p[1], p[2], p[3], p[4]
  else
    point, relPoint, x, y = DefaultPoint(f.team)
  end
  f:ClearAllPoints()
  f:SetPoint(point, UIParent, relPoint, x, y)
end

local function SavePosition(f)
  local point, _, relPoint, x, y = f:GetPoint()
  local bracket = ns:Bracket()
  local positions = ns:FrameSettings().positions
  positions[bracket] = positions[bracket] or {}
  positions[bracket][f.team] = { point, relPoint, x, y }
end

local function CreateContainer(team)
  local f = CreateFrame("Frame", "OmniHeal_" .. team, UIParent)
  f.team = team; f.rows = {}; f.records = {}
  f:SetMovable(true); f:SetClampedToScreen(true); f:Hide()
  ns.Theme.Round(f, 6)

  local header = CreateFrame("Frame", nil, f)
  header:SetHeight(HEADER_HEIGHT); header:EnableMouse(true); header:RegisterForDrag("LeftButton")
  ns.Theme.Round(header, 4)
  header:SetBackdropColor(0, 0, 0, 0.5); header:SetBackdropBorderColor(0, 0, 0, 0)
  header:SetScript("OnDragStart", function()
    if not ns:FrameSettings().locked and not InCombatLockdown() then
      f.dragSettings = ns:FrameSettings()
      f.dragBracket = ns:Bracket()
      f:StartMoving()
    end
  end)
  header:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    if f.dragSettings == ns:FrameSettings() and f.dragBracket == ns:Bracket() then SavePosition(f) end
    f.dragSettings, f.dragBracket = nil, nil
  end)
  
  local fontSize = (team == "ally") and (ns.db.allyHeaderFontSize or 7) or (ns.db.enemyHeaderFontSize or 14)
  
  header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header.text:SetFont(ns.Theme.GetFont(), fontSize, "OUTLINE")
  header.text:SetPoint("LEFT", 4, 0)
  
  header.text:SetTextColor(1, 1, 1)
  header.text:SetShadowColor(0, 0, 0, 1)
  header.text:SetShadowOffset(1, -1)
  
  f.header = header
  containers[team] = f
  return f
end

function Frames.UpdateHeader(f)
  local faction = ns:TeamFaction(f.team)
  local header = f.header
  header:SetBackdropColor(0, 0, 0, math.min(0.6 * (ns.db[f.team].panelAlpha / 0.6), 0.9))
  
  local size = ns.db[f.team .. "HeaderFontSize"] or (f.team == "ally" and 7 or 14)
  header.text:SetFont(ns.Theme.GetFont(), size, "OUTLINE")
  
  header.text:SetFormattedText("%s  |cffffffff%d|r", faction, f.displayCount or 0)
end

function Frames:UpdateHeaders() for _, f in pairs(containers) do Frames.UpdateHeader(f) end end
function Frames:UpdateLocks() end

local function SetTargeting(row, rec)
  if row.team == "ally" then
    if not row.clickDefaults then
      row.clickDefaults = true; row:SetAttribute("type1", "target"); row:SetAttribute("type2", "focus")
    end
    row:SetAttribute("unit", rec.unit); row.boundUnit = rec.unit
    return
  end
  if rec.unit then
    row:SetAttribute("type1", "target"); row:SetAttribute("type2", "focus"); row:SetAttribute("unit", rec.unit)
  elseif rec.targetName then
    row:SetAttribute("unit", nil); row:SetAttribute("type1", "macro"); row:SetAttribute("macrotext1", "/targetexact " .. rec.targetName)
    row:SetAttribute("type2", "macro"); row:SetAttribute("macrotext2", "/targetexact " .. rec.targetName .. "\n/focus\n/targetlasttarget")
    row:SetAttribute("shift-type2", "macro"); row:SetAttribute("shift-macrotext2", "/stopmacro")
  else
    row:SetAttribute("unit", nil); row:SetAttribute("type1", nil); row:SetAttribute("type2", nil)
  end
end

local function RowFor(rec)
  local row = rec.row
  if row and row.rec == rec then return row end
end

function Frames:UpdateStatic(rec) local row = RowFor(rec) if row then Row.SetIdentity(row, rec, ns.db[rec.team]) end end

function Frames:UpdateDynamic(rec)
  local row = RowFor(rec)
  if not row then return end
  local db = ns.db

  if row.premadeIcon then
    if rec.isPremade and db.premadeScannerEnabled then
      row.premadeIcon:Show()
    else
      row.premadeIcon:Hide()
    end
  end

  Row.SetBarColor(row, rec, db[rec.team])
  if rec.dead then self:UpdateDeadTimer(rec, GetTime(), true)
  else row.status:SetText(""); rec.deadShown = nil end

  local carrierKey = (rec.team or "enemy") .. "Carriers"
  local carriersEnabled = db[carrierKey]
  if carriersEnabled == nil then carriersEnabled = db.carriers end
  local tag = carriersEnabled and rec.carrier
  if tag then
    local icon = CarrierIcon(tag)
    if icon then row.carrier:SetTexture(icon); row.carrier:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else local c = CARRIER_COLORS[tag] or CARRIER_COLORS.Flag; row.carrier:SetColorTexture(c[1], c[2], c[3]) end
    row.carrier:Show()
  else row.carrier:Hide() end

  if db.highlightTarget and rec.isTarget then row:SetBackdropBorderColor(1, 1, 1, 1)
  elseif ns.db.showDispelBorder ~= false and rec.dispelColor then local c = rec.dispelColor; row:SetBackdropBorderColor(c[1], c[2], c[3], 1)
  else Row.RestBorder(row) end
  local vehicleKey = (rec.team or "enemy") .. "MarkVehicles"
  local markVehicles = db[vehicleKey]
  if markVehicles == nil then markVehicles = db.markVehicles end
  Row.SetVehicleBorder(row, rec.inVehicle == true and markVehicles)
end

function Frames:UpdateHealers(rec)
  local row = RowFor(rec)
  if row then Row.SetHealerMarks(row, rec.healerClasses or {}, ns.db.healerTargets and rec.team == "ally") end
end

function Frames:UpdateTargeters(rec)
  local row = RowFor(rec)
  if not row then return end
  local mode = ns.db[(rec.team or "enemy") .. "TargetIndicator"] or ns.db.targetIndicator
  local list = rec.targeters
  Row.SetBubbles(row, list, mode == "bubbles" or mode == "both")
  local n = (mode == "number" or mode == "both") and #list or 0
  if n ~= row.countShown then
    row.countShown = n; row.counter:SetText(n > 0 and n or ""); row.counter:SetTextColor(1, 1, 1, 1)
  end
end

function Frames:UpdateDeadTimer(rec, now, force)
  local row = RowFor(rec)
  if not row or not rec.deadAt then return end
  local timerKey = (rec.team or "enemy") .. "DeadTimer"
  local timerEnabled = ns.db[timerKey]
  if timerEnabled == nil then timerEnabled = ns.db.deadTimer end
  if not timerEnabled then if force then row.status:SetText(DEAD_ICON) end return end
  local secs = math.floor(now - rec.deadAt)
  if force or secs ~= rec.deadShown then
    rec.deadShown = secs; row.status:SetFormattedText("%s%d", DEAD_ICON, secs)
  end
end

function Frames:SetNear(rec, near)
  rec.nearValue, rec.hasNear = near, true
  local row = RowFor(rec)
  if not row then return end
  local team = rec.team or "enemy"
  local fadeKey, alphaKey = team .. "RangeFade", team .. "RangeAlpha"
  local fade, rangeAlpha = ns.db[fadeKey], ns.db[alphaKey]
  if fade == nil then fade = ns.db.rangeFade end
  if rangeAlpha == nil then rangeAlpha = ns.db.rangeAlpha end
  local alpha = fade and rangeAlpha or 1
  if ns.IsSecret(near) then
    row.nearShown = nil
    if row.content.SetAlphaFromBoolean then row.content:SetAlphaFromBoolean(near, 1, alpha) end
    return
  end
  local a = near and 1 or alpha
  if a ~= row.nearShown then row.nearShown = a; row.content:SetAlpha(a) end
end

function Frames:Flash(rec) local row = RowFor(rec) if row then Row.Flash(row) end end

local function ShowHealthText(row, rec)
  local mode = ns.db[rec.team].healthText
  local text = row.hpText
  if (mode ~= "percent" and mode ~= "value") or not rec.hasHealth or rec.dead then text:SetText("") return end
  local hp, maxv = rec.hp, rec.hpMax
  local plain = not ns.IsSecret(hp) and not ns.IsSecret(maxv) and type(maxv) == "number" and maxv > 0
  if mode == "percent" then
    if rec.hasPct then text:SetFormattedText("%d%%", rec.hpPct)
    elseif plain then text:SetFormattedText("%d%%", hp / maxv * 100)
    else text:SetText("") end
  elseif AbbreviateNumbers then text:SetText(AbbreviateNumbers(hp))
  elseif plain then text:SetText(tostring(hp))
  else text:SetText("") end
end

function Frames:ShowHealth(rec)
  local row = RowFor(rec)
  if row then
    if rec.hasHealth then row.health:SetMinMaxValues(0, rec.hpMax); row.health:SetValue(rec.hp)
    else row.health:SetMinMaxValues(0, 1); row.health:SetValue(1) end
    ShowHealthText(row, rec)
  end
end

function Frames:ShowMana(rec)
  local row = RowFor(rec)
  if row and row.power:IsShown() then
    if rec.hasMana then row.power:SetMinMaxValues(0, rec.mpMax); row.power:SetValue(rec.mp)
    else row.power:SetMinMaxValues(0, 1); row.power:SetValue(1) end
  end
end

local function ManaHeight(rec, tdb)
  if rec.team == "ally" and tdb.showHealerMana and rec.role == "HEALER" then return tdb.manaHeight end
  return 0
end

function Frames:LayoutRow(f, row, rec, i, L, tdb, top, step, perCol, colStep, padX)
  row:SetSize(L.width, L.height); row:ClearAllPoints()
  local col, r = math.floor((i - 1) / perCol), (i - 1) % perCol
  local x, y = padX + col * colStep, top + r * step
  if L.growUp then row:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y)
  else row:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y) end
  SetTargeting(row, rec); self:PaintRow(row, rec); row:Show()
end

function Frames:PaintRow(row, rec)
  local tdb = ns.db[rec.team]
  Row.Apply(row, tdb, ns:LayoutFor(rec.team).height, ManaHeight(rec, tdb))
  row.countShown = nil; Row.ClearMarks(row); Row.StopFlash(row); row.nearShown = nil
  if rec.hasNear then self:SetNear(rec, rec.nearValue)
  else row.content:SetAlpha(1); row.nearShown = 1 end
  self:UpdateStatic(rec); self:UpdateDynamic(rec); self:UpdateTargeters(rec); self:UpdateHealers(rec); self:ShowHealth(rec); self:ShowMana(rec)
  if ns.state == "bg" and row.power:IsShown() then ns.Live.ApplyMana(rec) end
  ns.Auras:Update(rec)
end

function Frames:RebindAllies()
  for _, row in ipairs(containers.ally.rows) do
    if row:IsShown() and row.boundUnit then
      local rec = ns.Roster.allyByUnit[row.boundUnit]
      local old = row.rec
      if rec ~= old then
        if old and old.row == row then old.row = nil end
        row.rec = rec
        if rec then rec.row = row; self:PaintRow(row, rec)
        else row.content:SetAlpha(0) end
      end
    end
  end
end

function Frames:Layout(team)
  local f = containers[team]
  local tdb = ns.db[team]
  local L = ns:LayoutFor(team)
  local shown = ns:FrameSettings()[team == "enemy" and "showEnemies" or "showAllies"]
  local enabled = ns.state ~= nil and shown
  local list = f.records
  local n = enabled and math.min(#list, tonumber(ns:Bracket())) or 0
  f.displayCount = n
  local step = L.height + L.spacing

  local cols = math.max(1, math.min(L.columns, n))
  local perCol = math.max(1, math.ceil(n / cols))
  local colStep = L.width + L.columnSpacing
  local padX, padY = L.padX, L.padY

  f:SetScale(L.scale)
  f:SetWidth(padX * 2 + cols * L.width + (cols - 1) * L.columnSpacing)
  local T = ns.Theme
  f:SetBackdropColor(T.BG[1], T.BG[2], T.BG[3], tdb.panelAlpha)
  f:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], tdb.panelAlpha > 0 and 0.8 or 0)
  local header = f.header
  header:ClearAllPoints()
  if L.growUp then header:SetPoint("BOTTOMLEFT", padX, padY); header:SetPoint("BOTTOMRIGHT", -padX, padY)
  else header:SetPoint("TOPLEFT", padX, -padY); header:SetPoint("TOPRIGHT", -padX, -padY) end
  local top = padY + HEADER_HEIGHT + 2
  for i = 1, n do
    local row = f.rows[i]
    if not row then
      row = Row.Create(f, f:GetName() .. "Row" .. i, team)
      row.team = team
      if team == "ally" then ClickCastFrames = ClickCastFrames or {}; ClickCastFrames[row] = true end
      f.rows[i] = row
    end
    local rec = list[i]
    row.rec = rec; rec.row = row
    ns.Safe("row " .. i, self.LayoutRow, self, f, row, rec, i, L, tdb, top, step, perCol, colStep, padX)
  end
  for i = n + 1, #f.rows do
    local row = f.rows[i]
    Row.StopFlash(row); row:Hide(); row.rec = nil
  end

  f:SetHeight(top + perCol * step - L.spacing + padY)
  RestorePosition(f); f:SetShown(enabled); Frames.UpdateHeader(f)
  if team == "ally" and ns.state == "bg" then ns.Live:SyncAllies() end
  if ns.state == "test" then ns.Test:Paint() end
end

function Frames:SetRecords(team, list)
  containers[team].records = list
  ns:AfterCombat("layout_" .. team, function() self:Layout(team) end)
end

function Frames:Refresh()
  ns:AfterCombat("layout_enemy", function() self:Layout("enemy") end)
  ns:AfterCombat("layout_ally", function() self:Layout("ally") end)
end

function Frames:OnInit() CreateContainer("enemy"); CreateContainer("ally") end
function Frames:OnActivate() self:Refresh() end
function Frames:OnDeactivate() self:Refresh() end
