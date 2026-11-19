local _, ns = ...
local Auras = ns.Auras
local Row = ns.Row

local IS_RETAIL = WOW_PROJECT_ID ~= nil and WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local PRIORITY_DEBUFF_SCALE = 1.4
local PRIORITY_DEBUFF_KINDS = {
  dispels = true, dispel = true,
  debuffs = true, debuff = true,
}

local function PriorityDebuffsEnabled(kind)
  return IS_RETAIL and PRIORITY_DEBUFF_KINDS[kind] == true and ns.db.largePriorityDebuffs == true
end

local function PriorityAuraSortMethod(kind)
  if PriorityDebuffsEnabled(kind) and AuraContainerSortMethod and AuraContainerSortMethod.UnitFrameDebuff ~= nil then
    return AuraContainerSortMethod.UnitFrameDebuff
  end
  return AuraContainerSortMethod and AuraContainerSortMethod.Default
end

local function IsLargeBlizzardAura(aura)
  if not aura then return false end
  if ns.Plain(aura.isBossAura) == true then return true end

  if AuraUtil and AuraUtil.IsRoleAura then
    local ok, isRoleAura = pcall(AuraUtil.IsRoleAura, aura)
    if ok and ns.Plain(isRoleAura) == true then return true end
  end
  return false
end

local function PriorityDebuffSize(kind, baseSize)
  if kind == "dispel" or kind == "dispels" then
    return tonumber(ns.db.dispelPrioritySize) or baseSize * PRIORITY_DEBUFF_SCALE
  end
  return baseSize * PRIORITY_DEBUFF_SCALE
end

local function AuraFrameSize(kind, baseSize, isLargePriority)
  if isLargePriority and PriorityDebuffsEnabled(kind) then
    return PriorityDebuffSize(kind, baseSize)
  end
  return baseSize
end

local function ApplyPriorityDebuffSize(btn, prefix)
  if not btn or not PriorityDebuffsEnabled(prefix) then return end
  local baseSize = tonumber(ns.db[prefix .. "Size"])
  if not baseSize then return end

  -- AuraContainer has already assigned this button to the large or normal
  -- group. Keep using that classification here instead of inspecting aura
  -- fields, which can be secret in combat.
  local large = btn._rfaLargePriority == true
  local size = AuraFrameSize(prefix, baseSize, large)
  local ok = pcall(btn.SetSize, btn, size, size)
  if not ok then return end

  btn._auraSize = size
  btn._rfaLargePriority = large
  local timerKind = prefix == "dispel" and "dispels" or "debuffs"
  btn.rfaKind = timerKind
  Row.ApplyTimerFont(btn, timerKind)
end

local HEAL_FILTER = "HELPFUL|PLAYER"
local DISPEL_FILTER = "HARMFUL|RAID" .. (IS_RETAIL and "|!CROWD_CONTROL" or "")
local PRIORITY_ALLY_DEBUFF_FILTER = "HARMFUL" .. (IS_RETAIL and "|!CROWD_CONTROL" or "")
local DISPEL_TYPE_SETTINGS = {
  Magic = "dispelTypeMagic",
  Curse = "dispelTypeCurse",
  Disease = "dispelTypeDisease",
  Poison = "dispelTypePoison",
}
local DISPEL_TYPE_ORDER = { "Magic", "Curse", "Disease", "Poison" }
local EXTERNAL_FILTER = "HELPFUL"
local MAX_SCAN = 40

local function DispelTypeEnabled(aura)
  local dispelType = ns.Plain(aura.dispelName)
  local setting = dispelType and DISPEL_TYPE_SETTINGS[dispelType]
  if setting then return ns.db[setting] ~= false end
  return ns.db.dispelTypeOther ~= false
end

local function DispelTypeFilterKey()
  local values = {}
  for _, dispelType in ipairs(DISPEL_TYPE_ORDER) do
    values[#values + 1] = ns.db[DISPEL_TYPE_SETTINGS[dispelType]] ~= false and "1" or "0"
  end
  values[#values + 1] = ns.db.dispelTypeOther ~= false and "1" or "0"
  return table.concat(values)
end

local function DispelCandidateFilters()
  local includeOther = ns.db.dispelTypeOther ~= false
  local allKnownEnabled = true
  for _, dispelType in ipairs(DISPEL_TYPE_ORDER) do
    if ns.db[DISPEL_TYPE_SETTINGS[dispelType]] == false then
      allKnownEnabled = false
      break
    end
  end
  if allKnownEnabled and includeOther then return {} end

  if includeOther then
    local excludeTypes = {}
    for _, dispelType in ipairs(DISPEL_TYPE_ORDER) do
      if ns.db[DISPEL_TYPE_SETTINGS[dispelType]] == false then
        excludeTypes[dispelType] = true
      end
    end
    return { excludeDispelTypes = excludeTypes }
  end

  local includeTypes = {}
  for _, dispelType in ipairs(DISPEL_TYPE_ORDER) do
    if ns.db[DISPEL_TYPE_SETTINGS[dispelType]] then
      includeTypes[dispelType] = true
    end
  end
  return { includeDispelTypes = includeTypes }
end

local function Wanted(aura)
  -- Caller already requested HELPFUL|PLAYER.
  if ns.db.auraFilter == "all" then return true end
  local id = ns.Plain(aura.spellId)
  return id ~= nil and Auras.TRACKED[id] == true
end

local function GameColor(globalName, fallback)
  local color = _G[globalName]
  if color then
    local r, g, b = ns.Plain(color.r), ns.Plain(color.g), ns.Plain(color.b)
    if r ~= nil and g ~= nil and b ~= nil then return { r, g, b } end
  end
  return fallback
end

local DISPEL_COLORS = {
  Magic = GameColor("DEBUFF_TYPE_MAGIC_COLOR", { 0.2, 0.6, 1 }),
  Curse = GameColor("DEBUFF_TYPE_CURSE_COLOR", { 0.6, 0, 1 }),
  Disease = GameColor("DEBUFF_TYPE_DISEASE_COLOR", { 0.6, 0.4, 0 }),
  Poison = GameColor("DEBUFF_TYPE_POISON_COLOR", { 0.45, 0.9, 0.15 }),
  Bleed = GameColor("DEBUFF_TYPE_BLEED_COLOR", { 0.8, 0, 0 }),
  Nature = { 0.2, 0.8, 0.2 },
  Physical = GameColor("DEBUFF_TYPE_BLEED_COLOR", { 0.8, 0, 0 }),
}
local DEFAULT_DISPEL = GameColor("DEBUFF_TYPE_NONE_COLOR", { 0.8, 0, 0 })
Auras.DISPEL_COLORS = DISPEL_COLORS

local function DispelColor(aura)
  local kind = ns.Plain(aura.dispelName)
  return kind and DISPEL_COLORS[kind] or nil
end

local function RingColor(aura, ringColor, prefix)
  if ringColor then return ringColor end
  if prefix == "dispel" or prefix == "debuff" or prefix == "allyCC" or prefix == "enemyCC" then
    local c = DispelColor(aura)
    if c then return c end
  end
  return nil
end

local ANIMATION_CATEGORY_BY_KIND = {
  dispels = "Debuff", debuffs = "Debuff",
  allyCC = "CC", enemyCC = "CC",
}
local ANIMATION_CATEGORY_BY_PREFIX = {
  dispel = "Debuff", debuff = "Debuff",
  allyCC = "CC", enemyCC = "CC",
}

function Auras:HookAnim(btn, prefix)
  if btn._animHooked then return end
  btn._animHooked = true
  prefix = prefix or "aura"

  local function onAura(self, aura)
    if not aura then
      ApplyPriorityDebuffSize(self, prefix)
      self:SetAlpha(1)
      self._shownSpellID = nil
      self._hasShownAura = nil
      self._rfaAuraColor = nil
      self._rfaAnimationSpellID = nil
      Auras.ApplyButtonAnimation(self, ANIMATION_CATEGORY_BY_PREFIX[prefix])
      return
    end

    local id = ns.Plain(aura.spellId)
    local key = id or ns.Plain(aura.icon) or "?"

    local auraColor = DispelColor(aura)
    ApplyPriorityDebuffSize(self, prefix)
    self._rfaAuraColor = auraColor
    self._rfaAnimationSpellID = id
    Auras.ApplyButtonAnimation(self, ANIMATION_CATEGORY_BY_PREFIX[prefix], auraColor, id)

    if self._shownSpellID == key and self._hasShownAura then
      Row.SetAuraAnimationVisible(self, true)
      return
    end
    self._shownSpellID = key
    self._hasShownAura = true

    self:SetAlpha(1)

    if prefix == "enemyDef" and id then
      local box = self:GetParent()
      local rec = box and box.rec
      if rec and rec.team == "enemy" and rec.class then
        local allowed = Auras.CLASS_SELF_DEFS[rec.class]
        if allowed and not allowed[id] then
          self:SetAlpha(0)
          self._shownSpellID = nil
          self._hasShownAura = nil
          Row.SetAuraAnimationVisible(self, false)
          return
        end
      end
    end

    Row.SetAuraAnimationVisible(self, true)
    Row.PlayAuraAssignedAnimation(self)

  end

  if btn.SetAuraData then hooksecurefunc(btn, "SetAuraData", onAura) end
  if btn.SetAuraInstanceID then
    hooksecurefunc(btn, "SetAuraInstanceID", function(self, id)
      if not id then onAura(self, nil); return end
      if not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then return end
      local unit = (self.GetUnit and self:GetUnit()) or self.unit or nil
      if not unit or unit == "none" then return end
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, id)
      if ok and aura then onAura(self, aura) end
    end)
  end
  if btn.ClearAura then
    hooksecurefunc(btn, "ClearAura", function(self)
      self:SetAlpha(1)
      self._shownSpellID = nil
      self._hasShownAura = nil
    end)
  end
end

local dirty = {}
local flushQueued = false

local function GetAura(unit, i, filter)
  local api = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if not api then return end
  local ok, aura = pcall(api, unit, i, filter)
  if ok then return ns.Plain(aura) end
end

local function SetCooldown(btn, unit, aura, timers)
  local cd = btn.cd
  cd:SetHideCountdownNumbers(not timers)
  local getDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration
  if unit and getDuration and cd.SetCooldownFromDurationObject then
    local ok, duration = pcall(getDuration, unit, aura.auraInstanceID)
    if ok and (ns.IsSecret(duration) or duration) then
      cd:SetCooldownFromDurationObject(duration)
      return
    end
  end
  local dur, expires = ns.Plain(aura.duration), ns.Plain(aura.expirationTime)
  if dur and expires and dur > 0 then
    cd:SetCooldown(expires - dur, dur)
  else
    cd:Clear()
  end
end

-- Blizzard's native containers select and display restricted auras in live matches.
local ENGINE_DISPEL_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE" .. (IS_RETAIL and "|!CROWD_CONTROL" or "")
local ENGINE_PRIORITY_ALLY_DEBUFF_FILTER = "HARMFUL" .. (IS_RETAIL and "|!CROWD_CONTROL" or "")
local engine, triedLoad
local boxState = setmetatable({}, { __mode = "k" })
local cooldowns = setmetatable({}, { __mode = "k" })

function Auras:UsesEngine()
  if not engine then
    if not triedLoad and C_AddOns and C_AddOns.LoadAddOn and not ns.IsAddOnLoaded("Blizzard_AuraContainer") then
      triedLoad = true
      pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    engine = AuraContainerSortMethod ~= nil and AnchorUtil ~= nil and AnchorUtil.FlowDirection ~= nil
  end
  return engine
end

local KINDS = {
  heals = { field = "healBox", filter = HEAL_FILTER, prefix = "aura", on = "myAuras", layer = 2 },
  dispels = { field = "dispelBox", filter = ENGINE_DISPEL_FILTER, priorityFilter = ENGINE_PRIORITY_ALLY_DEBUFF_FILTER, prefix = "dispel", on = "showDispels", layer = 3 },
  externals = { field = "externalBox", filter = EXTERNAL_FILTER, extra = "HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE", prefix = "externals", on = "showExternals", layer = 1 },
  debuffs = { field = "debuffBox", filter = "HARMFUL|PLAYER", prefix = "debuff", on = "myDebuffs", layer = 2 },
  allyCC = { field = "allyCCBox", filter = "HARMFUL|CROWD_CONTROL", prefix = "allyCC", on = "showAllyCC", layer = 4 },
  enemyDef = { field = "enemyDefBox", filter = "HELPFUL|BIG_DEFENSIVE", extra = "HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE", prefix = "enemyDef", on = "showEnemyDef", layer = 3 },
  enemyCC = { field = "enemyCCBox", filter = "HARMFUL|CROWD_CONTROL", prefix = "enemyCC", on = "showEnemyCC", layer = 4 },
}

local function Groups(kind)
  local k = KINDS[kind]
  if not k.groups then
    if IS_RETAIL and PRIORITY_DEBUFF_KINDS[kind] then
      k.groups = { { kind .. "Priority", k.priorityFilter or k.filter, true }, { kind, k.filter, false } }
    else
      k.groups = k.extra and { { kind, k.filter }, { kind .. "Ext", k.extra } } or { { kind, k.filter } }
    end
  end
  return k.groups
end

local TEST_ANCHOR_PRESETS = {
  corners = {
    auraAnchor = "BOTTOMLEFT", auraGrow = "right",
    externalsAnchor = "TOPLEFT", externalsGrow = "right",
    dispelAnchor = "BOTTOMRIGHT", dispelGrow = "left",
    allyCCAnchor = "TOPRIGHT", allyCCGrow = "left",
    debuffAnchor = "BOTTOMRIGHT", debuffGrow = "left",
    enemyDefAnchor = "TOPLEFT", enemyDefGrow = "right",
    enemyCCAnchor = "TOPRIGHT", enemyCCGrow = "left",
  },
  sides = {
    auraAnchor = "LEFT", auraGrow = "right",
    externalsAnchor = "TOPLEFT", externalsGrow = "right",
    dispelAnchor = "BOTTOMLEFT", dispelGrow = "right",
    allyCCAnchor = "RIGHT", allyCCGrow = "left",
    debuffAnchor = "RIGHT", debuffGrow = "left",
    enemyDefAnchor = "LEFT", enemyDefGrow = "right",
    enemyCCAnchor = "TOPRIGHT", enemyCCGrow = "left",
  },
}

local function Setting(kind, name)
  local key = KINDS[kind].prefix .. name
  if ns.state == "test" and (name == "Anchor" or name == "Grow") then
    local preset = TEST_ANCHOR_PRESETS[ns.db.testAnchorPreset]
    if preset and preset[key] then return preset[key] end
  end
  return ns.db[key]
end
local function LayerFrameLevel(row, kind)
  local layer = tonumber(Setting(kind, "Layer")) or KINDS[kind].layer
  return row.content:GetFrameLevel() + layer * 4
end

local initCount = { heals = 0, dispels = 0, externals = 0, debuffs = 0, allyCC = 0, enemyDef = 0, enemyCC = 0 }
local function Initialize(kind, btn, isLargePriority)
  btn.rfaKind = kind
  local size = AuraFrameSize(kind, Setting(kind, "Size"), isLargePriority)
  btn:SetSize(size, size)
  btn._auraSize = size
  btn._rfaLargePriority = isLargePriority == true
  pcall(btn.SetMouseClickEnabled, btn, false)
  pcall(btn.SetMouseMotionEnabled, btn, false)
  local icon, cd, ring, count = Row.DecorateAuraIcon(btn)
  if kind == "enemyDef" then
    cd:SetHideCountdownNumbers(true)
  else
    cd:SetHideCountdownNumbers(not Setting(kind, "Timers"))
  end
  if cd.SetUseAuraDisplayTime then cd:SetUseAuraDisplayTime(true) end
  btn:SetIcon(icon)
  btn:SetDurationCooldown(cd)
  btn:SetApplicationCount(count, {})
  btn._ring = ring
  cooldowns[btn] = cd
  initCount[kind] = initCount[kind] + 1
  Auras:HookAnim(btn, KINDS[kind] and KINDS[kind].prefix or kind)
  local cat = ANIMATION_CATEGORY_BY_KIND[kind]
  local ancestor = btn:GetParent()
  while ancestor and not ancestor._omniHealAuraRow do ancestor = ancestor:GetParent() end
  if ancestor then Row.SetAuraIconFrameLevel(btn, LayerFrameLevel(ancestor._omniHealAuraRow, kind) + 1) end
  Auras.ApplyButtonAnimation(btn, cat)
end
local function Initializer(kind, isLargePriority)
  return function(btn) ns.Safe("aura icon setup", Initialize, kind, btn, isLargePriority) end
end

-- The slot and the icon groups have independent frame assignments. Blizzard
-- owns aura selection, dispel colors and visibility, including during combat.
local function InitializeDispelBorder(button, content, style)
  button:SetPoint("TOPLEFT", content, "TOPLEFT", 1, -1)
  button:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -1, 1)
  button:SetMouseClickEnabled(false)
  button:SetMouseMotionEnabled(false)
  local function Edge(first, last, horizontal)
    local edge = button:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(1, 1, 1, 1)
    edge:SetPoint(first, button, first)
    edge:SetPoint(last, button, last)
    if horizontal then edge:SetHeight(2) else edge:SetWidth(2) end
    button:AddDispelTypeTexture(edge, { style = style, showAlways = true })
  end
  Edge("TOPLEFT", "TOPRIGHT", true)
  Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  Edge("TOPLEFT", "BOTTOMLEFT", false)
  Edge("TOPRIGHT", "BOTTOMRIGHT", false)
end

local function Box(row, kind)
  local k = KINDS[kind]
  local box = row[k.field]
  if box then return box end
  box = CreateFrame("AuraContainer", nil, row.content, "CustomAuraContainerTemplate")
  box._omniHealAuraRow = row
  box:SetFrameLevel(LayerFrameLevel(row, kind))
  box:SetSize(1, 1)
  box:SetEnabled(false)
  local size = Setting(kind, "Size")
  local spacing = Setting(kind, "Spacing") or 2
  local sortMethod = PriorityAuraSortMethod(kind)
  local sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal

  for _, g in ipairs(Groups(kind)) do
    local candidateFilters = {}
    if kind == "enemyDef" or (kind == "externals" and g[1] == "externalsExt") then
      candidateFilters.excludeSpellIDs = Auras.ORB_CARRIER_AURAS
    end
    local elementSize = AuraFrameSize(kind, size, g[3] == true)
    if PriorityDebuffsEnabled(kind) and g[3] ~= nil then
      candidateFilters.isBossOrRoleAura = g[3]
    end
    if kind == "dispels" and g[3] ~= true then
      for key, value in pairs(DispelCandidateFilters()) do candidateFilters[key] = value end
    end
    box:AddAuraGroup(g[1], g[2], {
      maxFrameCount = 0, sortMethod = sortMethod,
      sortDirection = sortDirection,
      candidateFilters = candidateFilters,
      initializeFrame = Initializer(kind, g[3] == true),
      layout = { elementWidth = elementSize, elementHeight = elementSize, elementSpacing = spacing },
    })
  end

  local dispelStyles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
  local hasDispelBorder = kind == "dispels" and dispelStyles ~= nil and dispelStyles.PreserveAsset ~= nil and box.AddAuraSlot ~= nil
  if hasDispelBorder then
    box:AddAuraSlot("rowBorder", ENGINE_DISPEL_FILTER, {
      sortMethod = sortMethod, sortDirection = sortDirection,
      candidateFilters = DispelCandidateFilters(),
      initializeFrame = function(button) InitializeDispelBorder(button, row.content, dispelStyles.PreserveAsset) end,
    })
  end

  boxState[box] = { hasDispelBorder = hasDispelBorder }
  row[k.field] = box
  return box
end

local buildQueue, building = {}, false
local function BuildStep()
  if InCombatLockdown() then ns:AfterCombat("aura-build", BuildStep) return end
  for _ = 1, 2 do
    local job = table.remove(buildQueue, 1)
    if not job then break end
    ns.Safe("aura container", Box, job.row, job.kind)
    local rec = job.row.rec
    if rec and ns.state == "bg" then ns.Safe("aura update", Auras.Update, Auras, rec) end
  end
  if buildQueue[1] then C_Timer.After(0, BuildStep) else building = false end
end
local function QueueBox(row, kind)
  for _, job in ipairs(buildQueue) do
    if job.row == row and job.kind == kind then return end
  end
  buildQueue[#buildQueue + 1] = { row = row, kind = kind }
  if not building then
    building = true
    C_Timer.After(0, BuildStep)
  end
end

local function Call(box, names, ...)
  for _, name in ipairs(names) do
    if box[name] then return box[name](box, ...) end
  end
end
local ANCHOR_SETTERS = { "SetFlowLayoutAnchorPoint", "SetAuraLayoutAnchorPoint" }
local GROWTH_SETTERS = { "SetFlowLayoutGrowthDirection", "SetAuraLayoutGrowthDirection" }

local function ApplyBox(row, rec, kind, unit)
  local on = ns.db[KINDS[kind].on]
  local max, size, timers = Setting(kind, "Max"), Setting(kind, "Size"), Setting(kind, "Timers")
  local priorityEnabled = PriorityDebuffsEnabled(kind)
  local prioritySize = priorityEnabled and PriorityDebuffSize(kind, size) or size
  local spacing = Setting(kind, "Spacing") or 2
  local sortMethod = PriorityAuraSortMethod(kind)
  local sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal
  local layer = tonumber(Setting(kind, "Layer")) or KINDS[kind].layer
  local layerLevel = LayerFrameLevel(row, kind)
  local anchor, grow = Setting(kind, "Anchor"), Setting(kind, "Grow")
  local ox, oy = Setting(kind, "OffsetX"), Setting(kind, "OffsetY")
  local box = row[KINDS[kind].field]
  if not box then
    if on then QueueBox(row, kind) end
    return
  end
  box.rec = rec
  local st = boxState[box]
  local refresh = false
  local point, at, x, y, toLeft = Row.AuraPoint(anchor, grow)

  local filter = nil
  if kind == "heals" then filter = ns.db.auraFilter
  end
  local dispelTypeFilter = kind == "dispels" and DispelTypeFilterKey() or nil

  local borderEnabled = st.hasDispelBorder and ns.db.showDispelBorder ~= false and on and max > 0
  local layout = table.concat({ point, at, x + (ox or 0), y + (oy or 0), tostring(toLeft), size, prioritySize, spacing, layer, on and max or 0, tostring(filter), tostring(dispelTypeFilter), tostring(borderEnabled), tostring(ns.db.saveFilter), tostring(sortMethod), tostring(priorityEnabled) }, ":")
  if st.layout ~= layout then
    if InCombatLockdown() then
      ns:AfterCombat("aura-layout", function() ns.Frames:Refresh() end)
    else
      box:SetFrameLevel(layerLevel)
      
      local groups, cap = Groups(kind), on and max or 0
      for i, g in ipairs(groups) do
        local share
        if kind == "externals" and ns.db.saveFilter ~= "blizzard" then
          share = i == 1 and cap or 0
        elseif g[3] ~= nil then
          if priorityEnabled then
            share = g[3] and math.min(cap, 1) or cap
          else
            share = g[3] and 0 or cap
          end
        else
          share = #groups > 1 and (i == 1 and math.ceil(cap / 2) or math.floor(cap / 2)) or cap
        end
        local elementSize = priorityEnabled and g[3] == true and prioritySize or size
        box:SetAuraGroupMaxFrameCount(g[1], share)
        local groupLayout = { elementWidth = elementSize, elementHeight = elementSize, elementSpacing = spacing }
        if g[3] ~= nil then
          groupLayout.layoutIndex = g[3] and 1 or 2
          groupLayout.groupSpacing = spacing
          groupLayout.groupLineSpacing = 0
        end
        box:SetAuraGroupLayout(g[1], groupLayout)
        if sortMethod ~= nil and sortDirection ~= nil and box.SetAuraGroupSortMethod then
          pcall(box.SetAuraGroupSortMethod, box, g[1], sortMethod, sortDirection)
        end
        for j = 1, box:GetAuraGroupFrameCount(g[1]) or 0 do
          local btn = box:GetAuraGroupFrame(g[1], j)
          if btn and (not btn.CanBeAccessedInContext or btn:CanBeAccessedInContext()) then
            btn:SetSize(elementSize, elementSize)
            btn._auraSize = elementSize
            btn._rfaLargePriority = priorityEnabled and g[3] == true
            Row.ApplyTimerFont(btn, kind)
            Row.SetAuraIconFrameLevel(btn, layerLevel + 1)
          end
        end
      end

      if kind == "externals" and st.saveFilter ~= ns.db.saveFilter then
        local smart = ns.db.saveFilter == "blizzard"
        box:SetAuraGroupFilterString(kind, smart and "HELPFUL|BIG_DEFENSIVE" or EXTERNAL_FILTER)
        box:SetAuraGroupCandidateFilters(kind, smart and { excludeSpellIDs = Auras.ORB_CARRIER_AURAS } or { includeSpellIDs = Auras.EXTERNALS })
        box:SetAuraGroupEnabled(kind .. "Ext", smart)
        st.saveFilter = ns.db.saveFilter
        refresh = true
      elseif filter and st.filter ~= filter then
        st.filter = filter
        if filter == "all" then box:SetAuraGroupCandidateFilters(kind, {})
        else box:SetAuraGroupCandidateFilters(kind, { includeSpellIDs = Auras.TRACKED }) end
        refresh = true
      end

      if st.hasDispelBorder then
        if st.dispelTypeFilter ~= dispelTypeFilter then
          box:SetAuraSlotCandidateFilters("rowBorder", DispelCandidateFilters())
        end
        box:SetAuraSlotEnabled("rowBorder", borderEnabled)
      end

      local hasPriorityGroups = false
      for _, g in ipairs(Groups(kind)) do
        if g[3] ~= nil then hasPriorityGroups = true; break end
      end
      if hasPriorityGroups and (st.priorityMode ~= priorityEnabled or (kind == "dispels" and st.dispelTypeFilter ~= dispelTypeFilter)) then
        for _, g in ipairs(Groups(kind)) do
          local candidateFilters = {}
          if kind == "dispels" and g[3] ~= true then
            for key, value in pairs(DispelCandidateFilters()) do candidateFilters[key] = value end
          end
          if priorityEnabled and g[3] ~= nil then candidateFilters.isBossOrRoleAura = g[3] end
          box:SetAuraGroupCandidateFilters(g[1], candidateFilters)
        end
        st.priorityMode = priorityEnabled
        st.dispelTypeFilter = dispelTypeFilter
        refresh = true
      end

      if st.sortMethod ~= sortMethod then
        st.sortMethod = sortMethod
        refresh = true
      end

      local FD = AnchorUtil.FlowDirection
      box:ClearAllPoints()
      box:SetPoint(point, row.barArea, at, x + (ox or 0), y + (oy or 0))
      local flowAnchor
      if priorityEnabled then
        flowAnchor = toLeft and "BOTTOMRIGHT" or "BOTTOMLEFT"
      else
        flowAnchor = toLeft and "RIGHT" or "LEFT"
      end
      Call(box, ANCHOR_SETTERS, flowAnchor)
      Call(box, GROWTH_SETTERS, toLeft and FD.Left or FD.Right, FD.Down)
      st.layout = layout
    end
  end
  if (st.timers ~= timers or st.size ~= size or st.prioritySize ~= prioritySize) and not InCombatLockdown() then
    local done = true
    for _, g in ipairs(Groups(kind)) do
      for i = 1, box:GetAuraGroupFrameCount(g[1]) or 0 do
        local btn = box:GetAuraGroupFrame(g[1], i)
        if btn and (not btn.CanBeAccessedInContext or btn:CanBeAccessedInContext()) then
          local isLargePriority = priorityEnabled and g[3] == true
          local frameSize = AuraFrameSize(kind, size, isLargePriority)
          btn:SetSize(frameSize, frameSize)
          btn._auraSize = frameSize
          btn._rfaLargePriority = isLargePriority
          local cd = cooldowns[btn]
          if cd then cd:SetHideCountdownNumbers(kind == "enemyDef" or not timers) end
          Row.ApplyTimerFont(btn, kind)
        else
          done = false
        end
      end
    end
    if done then st.timers, st.size, st.prioritySize = timers, size, prioritySize end
  end
  unit = on and unit or "none"
  if st.unit ~= unit then
    box:SetEnabled(false)
    box:SetUnit(unit)
    st.unit = unit
    refresh = true
  elseif st.rec ~= rec then
    refresh = true
  end
  st.rec = rec
  box:SetEnabled(unit ~= "none")
  if refresh and unit ~= "none" then box:UpdateAllAuras() end
end

local function HideBoxes(row)
  for _, k in pairs(KINDS) do
    local box = row[k.field]
    if box and boxState[box].unit ~= "none" then
      box:SetEnabled(false)
      box:SetUnit("none")
      boxState[box].unit = "none"
    end
  end
end

-- Preview data and clients without native containers use the row's own icons.
local function Show(group, n, aura, unit, timers, ringColor, prefix)
  local btn = Row.AuraIcon(group, n)
  prefix = prefix or "aura"
  local priorityLarge = PriorityDebuffsEnabled(prefix) and IsLargeBlizzardAura(aura)
  btn._rfaLayoutSize = priorityLarge and PriorityDebuffSize(prefix, ns.db[prefix .. "Size"] or 24) or nil
  local wasLarge = btn._rfaLargePriority == true
  btn._rfaLargePriority = priorityLarge == true
  local timerKind = prefix == "dispel" and "dispels" or prefix == "debuff" and "debuffs" or prefix
  btn.rfaKind = timerKind
  if wasLarge ~= btn._rfaLargePriority or btn._rfaTimerFontKind ~= timerKind then
    Row.ApplyTimerFont(btn, timerKind)
    btn._rfaTimerFontKind = timerKind
  end
  btn.icon:SetTexture(aura.icon)
  local stacks = ns.Plain(aura.applications)
  btn.count:SetText(stacks and stacks > 1 and stacks or "")

  local rc = RingColor(aura, ringColor, prefix)
  btn._rfaAuraColor = rc
  local previousSpellID = btn._currentSpellID
  local spellId = ns.Plain(aura.spellId)
  btn._shownSpellID = spellId

  SetCooldown(btn, unit, aura, timers)
  local category = ANIMATION_CATEGORY_BY_PREFIX[prefix]
  Auras.ApplyButtonAnimation(btn, category, rc, spellId)
  if category and spellId ~= nil and previousSpellID ~= spellId then
    btn._pendingAppear = true
  elseif not category then
    btn._pendingAppear = nil
  end
  btn._currentSpellID = spellId
end

local NO_SAMPLES = {}

local function ShowSamples(row, samples, prefix)
  local targetFrame
  if prefix == "enemyDef" then targetFrame = row.defs
  elseif prefix == "allyCC" then targetFrame = row.allyCC
  else targetFrame = row.enemyCC end
  
  if not samples and not targetFrame.ccShown then return end
  local db = ns.db
  local size = db[prefix .. "Size"]
  local n = 0

  for _, aura in ipairs(samples or NO_SAMPLES) do
    if n >= db[prefix .. "Max"] then break end
    n = n + 1
    Show(targetFrame, n, aura, nil, db[prefix .. "Timers"], DispelColor(aura), prefix)
  end
  Row.LayoutAuras(row, targetFrame, n, size, db[prefix .. "Anchor"], db[prefix .. "Grow"], db[prefix .. "OffsetX"], db[prefix .. "OffsetY"], db[prefix .. "Spacing"] or 2, db[prefix .. "Layer"])

  targetFrame.ccShown = n > 0 or nil
end

function Auras:UpdateEnemy(row, rec)
  local db = ns.db
  if ns.state == "bg" and not rec.testDebuffs and not rec.testDefs and not rec.testCC and self:UsesEngine() then
    Row.LayoutAuras(row, row.auras, 0, db.debuffSize, db.debuffAnchor, db.debuffGrow, 0, 0, db.debuffSpacing, db.debuffLayer)
    Row.LayoutAuras(row, row.defs, 0, db.enemyDefSize, db.enemyDefAnchor, db.enemyDefGrow, 0, 0, db.enemyDefSpacing, db.enemyDefLayer)
    Row.LayoutAuras(row, row.enemyCC, 0, db.enemyCCSize, db.enemyCCAnchor, db.enemyCCGrow, 0, 0, db.enemyCCSpacing, db.enemyCCLayer)
    ApplyBox(row, rec, "debuffs", rec.auraUnit or "none")
    ApplyBox(row, rec, "enemyDef", rec.auraUnit or "none")
    ApplyBox(row, rec, "enemyCC", rec.auraUnit or "none")
    return
  end
  HideBoxes(row)
  local n = 0
  if db.myDebuffs and rec.testDebuffs then
    for _, aura in ipairs(rec.testDebuffs) do
      if n >= db.debuffMax then break end
      n = n + 1
      Show(row.auras, n, aura, nil, db.debuffTimers, DispelColor(aura), "debuff")
    end
  end
  Row.LayoutAuras(row, row.auras, n, db.debuffSize, db.debuffAnchor, db.debuffGrow, db.debuffOffsetX, db.debuffOffsetY, db.debuffSpacing, db.debuffLayer)
  ShowSamples(row, db.showEnemyDef and rec.testDefs, "enemyDef")
  ShowSamples(row, db.showEnemyCC and rec.testCC, "enemyCC")
end

function Auras:Update(rec)
  self:RefreshAnimationSettings()
  local row = rec.row
  if not row or row.rec ~= rec then return end
  if rec.team == "enemy" then return self:UpdateEnemy(row, rec) end
  local db = ns.db
  if ns.state == "bg" and not rec.testAuras and not rec.testDispels and not rec.testCC and self:UsesEngine() then
    Row.LayoutAuras(row, row.auras, 0, db.auraSize, db.auraAnchor, db.auraGrow, 0, 0, db.auraSpacing, db.auraLayer)
    Row.LayoutAuras(row, row.externals, 0, db.externalsSize, db.externalsAnchor, db.externalsGrow, 0, 0, db.externalsSpacing, db.externalsLayer)
    Row.LayoutAuras(row, row.dispels, 0, db.dispelSize, db.dispelAnchor, db.dispelGrow, 0, 0, db.dispelSpacing, db.dispelLayer)
    Row.LayoutAuras(row, row.allyCC, 0, db.allyCCSize, db.allyCCAnchor, db.allyCCGrow, 0, 0, db.allyCCSpacing, db.allyCCLayer)
    ApplyBox(row, rec, "heals", rec.unit)
    ApplyBox(row, rec, "externals", rec.unit)
    ApplyBox(row, rec, "dispels", rec.unit)
    ApplyBox(row, rec, "allyCC", rec.unit)
    if rec.dispelColor then
      rec.dispelColor = nil
      ns.Frames:UpdateDynamic(rec)
    end
    return
  end
  HideBoxes(row)

  local e = 0
  if db.showExternals then
    local max = db.externalsMax
    if rec.testExternals then
      for _, aura in ipairs(rec.testExternals) do
        if e >= max then break end
        e = e + 1
        Show(row.externals, e, aura, nil, db.externalsTimers, nil, "externals")
      end
    elseif rec.unit then
      for i = 1, MAX_SCAN do
        local aura = GetAura(rec.unit, i, EXTERNAL_FILTER)
        if not aura or e >= max then break end
        local id = ns.Plain(aura.spellId)
        if id and Auras.EXTERNALS[id] then
          e = e + 1
          Show(row.externals, e, aura, rec.unit, db.externalsTimers, nil, "externals")
        end
      end
    end
  end
  Row.LayoutAuras(row, row.externals, e, db.externalsSize, db.externalsAnchor, db.externalsGrow, db.externalsOffsetX, db.externalsOffsetY, db.externalsSpacing, db.externalsLayer)

  local n = 0
  if db.myAuras then
    local max = db.auraMax
    if rec.testAuras then
      for _, aura in ipairs(rec.testAuras) do
        if n >= max then break end
        n = n + 1
        Show(row.auras, n, aura, nil, db.auraTimers, nil, "aura")
      end
    elseif rec.unit then
      for i = 1, MAX_SCAN do
        local aura = GetAura(rec.unit, i, HEAL_FILTER)
        if not aura or n >= max then break end
        if Wanted(aura) then
          n = n + 1
          Show(row.auras, n, aura, rec.unit, db.auraTimers, nil, "aura")
        end
      end
    end
  end
  Row.LayoutAuras(row, row.auras, n, db.auraSize, db.auraAnchor, db.auraGrow, db.auraOffsetX, db.auraOffsetY, db.auraSpacing, db.auraLayer)

  local d, rowColor = 0, nil
  if db.showDispels then
    local max = math.max(0, tonumber(db.dispelMax) or 0)
    local largeAura
    local normalAuras = {}
    local priorityEnabled = PriorityDebuffsEnabled("dispel")
    local function ConsiderDispel(aura)
      if not aura then return end
      if rec.testDispels and rec.testCC then
        local spellID = ns.Plain(aura.spellId)
        if spellID then
          for _, ccAura in ipairs(rec.testCC) do
            if spellID == ns.Plain(ccAura.spellId) then return end
          end
        end
      end
      if priorityEnabled and max > 0 and IsLargeBlizzardAura(aura) then
        if not largeAura then largeAura = aura end
      elseif DispelTypeEnabled(aura) and #normalAuras < max then
        normalAuras[#normalAuras + 1] = aura
      end
    end
    if rec.testDispels then
      for _, aura in ipairs(rec.testDispels) do
        ConsiderDispel(aura)
      end
    elseif rec.unit then
      if priorityEnabled and max > 0 then
        for i = 1, MAX_SCAN do
          local aura = GetAura(rec.unit, i, PRIORITY_ALLY_DEBUFF_FILTER)
          if not aura then break end
          ConsiderDispel(aura)
        end
      end
      for i = 1, MAX_SCAN do
        local aura = GetAura(rec.unit, i, DISPEL_FILTER)
        if not aura then break end
        ConsiderDispel(aura)
      end
    end
    local displayUnit = rec.unit
    if rec.testDispels then displayUnit = nil end
    local function ShowDispel(aura)
      d = d + 1
      local color = DispelColor(aura)
      rowColor = rowColor or color
      Show(row.dispels, d, aura, displayUnit, db.dispelTimers, color, "dispel")
    end
    if largeAura then ShowDispel(largeAura) end
    for _, aura in ipairs(normalAuras) do ShowDispel(aura) end
  end
  Row.LayoutAuras(row, row.dispels, d, db.dispelSize, db.dispelAnchor, db.dispelGrow, db.dispelOffsetX, db.dispelOffsetY, db.dispelSpacing, db.dispelLayer)

  ShowSamples(row, db.showAllyCC and rec.testCC, "allyCC")
  if rowColor ~= rec.dispelColor then
    rec.dispelColor = rowColor
    ns.Frames:UpdateDynamic(rec)
  end
end

local function Flush()
  flushQueued = false
  for rec in pairs(dirty) do
    dirty[rec] = nil
    Auras:Update(rec)
  end
end

function Auras:MarkDirty(rec)
  dirty[rec] = true
  if not flushQueued then
    flushQueued = true
    C_Timer.After(0, Flush)
  end
end

local function V(ok, v)
  if not ok then return "?" end
  if ns.IsSecret(v) then return "SECRET" end
  return tostring(v)
end

function Auras:ProbeLines()
  local lines = {}
  local list = OmniHeal_ally
  local row = list and list.rows and list.rows[1]
  lines[1] = string.format("aura containers %s, icons set up %d heals / %d dispels, %d waiting",
    self:UsesEngine() and "on" or "|cffff5555unavailable|r", initCount.heals, initCount.dispels, #buildQueue)
  if not row then
    lines[2] = "no ally rows yet"
    return lines
  end
  local rec = row.rec
  lines[2] = "first ally row: " .. tostring(rec and rec.name) .. " (" .. tostring(rec and rec.unit) .. ")"
  for _, kind in ipairs({ "heals", "dispels" }) do
    local box = row[kind == "heals" and "healBox" or "dispelBox"]
    if box then
      local st = boxState[box]
      lines[#lines + 1] = string.format("%s: unit %s, enabled %s, filter %s",
        kind, V(pcall(box.GetUnit, box)), V(pcall(box.IsEnabled, box)), tostring(st.filter))
    else
      lines[#lines + 1] = kind .. ": no container on this row"
    end
  end
  return lines
end

function Auras:OnDeactivate()
  wipe(dirty)
  wipe(buildQueue)
  for _, list in ipairs({ OmniHeal_ally, OmniHeal_enemy }) do
    for _, row in ipairs(list and list.rows or {}) do
      HideBoxes(row)
    end
  end
end
