local _, ns = ...
local Row = ns.Row

local ROUND_GLOW_GRADIENT_PREFIX = ns.Theme.MEDIA .. "rounded-glow-gradient-"
local AURA_GLOW_MAX_SPREAD = 4.05
local AURA_GLOW_RATIO_MIN = 0.04
local AURA_GLOW_RATIO_STEP = 0.02
local AURA_GLOW_RATIO_MAX = 0.30
local HALO_ALPHA = 1.0
local ORBIT_DASH_THICKNESS = 2
local ORBIT_FLIPBOOK_COLUMNS = 12
local ORBIT_FLIPBOOK_ROWS = 8
local ORBIT_CYCLE_SECONDS = 1
local ORBIT_DASH_COUNT_MIN = 1
local ORBIT_DASH_COUNT_MAX = 4
local ORBIT_DASH_LENGTH_MIN = 0.5
local ORBIT_DASH_LENGTH_MAX = 1.5
local ORBIT_DASH_LENGTH_STEP = 0.25
local ACTIVE_EFFECT_FADE_SECONDS = 0.5

local function OrbitDashCount(state)
  local count = math.floor((ns.Plain(state.orbitCount) or 2) + 0.5)
  return math.max(ORBIT_DASH_COUNT_MIN, math.min(ORBIT_DASH_COUNT_MAX, count))
end

local function OrbitDashLengthCode(state)
  local length = ns.Plain(state.orbitLength) or 1
  length = math.max(ORBIT_DASH_LENGTH_MIN, math.min(ORBIT_DASH_LENGTH_MAX, length))
  local steps = math.floor((length - ORBIT_DASH_LENGTH_MIN) / ORBIT_DASH_LENGTH_STEP + 0.5)
  return math.floor(ORBIT_DASH_LENGTH_MIN * 100 + 0.5) + steps * math.floor(ORBIT_DASH_LENGTH_STEP * 100 + 0.5)
end

local function OrbitDashAtlasPath(orientation, count, lengthCode)
  return string.format("Interface\\AddOns\\BG_OmniHeal\\Media\\AuraOrbit%s_C%d_L%03d.png", orientation, count, lengthCode)
end

local function CreateGlowLayers(frame)
  local halo = frame:CreateTexture(nil, "OVERLAY")
  halo:SetTexture(ROUND_GLOW_GRADIENT_PREFIX .. "16.png")
  halo:SetBlendMode("ADD")
  halo:SetAlpha(HALO_ALPHA)
  local gradient = frame:CreateTexture(nil, "OVERLAY")
  gradient:SetTexture(ROUND_GLOW_GRADIENT_PREFIX .. "16.png")
  gradient:SetBlendMode("BLEND")
  return {
    { texture = halo, kind = "halo", spreadFactor = 1.35 },
    { texture = gradient, kind = "gradient", spreadFactor = 1 },
  }
end

local function EnsureAuraAnimationRegions(btn)
  if btn._rfaAuraAnimation then return btn._rfaAuraAnimation end

  local frame = CreateFrame("Frame", nil, btn)
  frame:SetAllPoints(btn)
  frame:SetFrameLevel(btn:GetFrameLevel() + 3)
  frame:SetAlpha(0)

  local neonFrame = CreateFrame("Frame", nil, frame)
  neonFrame:SetAllPoints(frame)
  neonFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
  neonFrame:SetAlpha(0)
  local pulseFrame = CreateFrame("Frame", nil, frame)
  pulseFrame:SetAllPoints(frame)
  pulseFrame:SetFrameLevel(frame:GetFrameLevel() + 2)
  pulseFrame:SetAlpha(0)
  local orbitFrame = CreateFrame("Frame", nil, frame)
  orbitFrame:SetAllPoints(frame)
  orbitFrame:SetFrameLevel(frame:GetFrameLevel() + 3)
  orbitFrame:SetAlpha(0)

  local neonLayers = CreateGlowLayers(neonFrame)
  local pulseLayers = CreateGlowLayers(pulseFrame)
  local state = {
    btn = btn,
    frame = frame,
    neonFrame = neonFrame,
    pulseFrame = pulseFrame,
    orbitFrame = orbitFrame,
    neonLayers = neonLayers,
    pulseLayers = pulseLayers,
    appearGroup = nil,
    activeGroup = nil,
    active = {},
    effects = {},
    visible = false,
    isAnimating = false,
    orbitSpeed = 1,
    orbitStrength = 0.65,
    orbitSize = 1.35,
    orbitDashes = nil,
    orbitAnimations = nil,
    borderTransition = nil,
    neonTransition = nil,
    key = nil,
    settings = nil,
  }
  btn._rfaAuraAnimation = state
  Row.UpdateAuraAnimationLayout(btn, 1.35, 1.35)
  return state
end

local function LayoutGlowLayers(btn, state, frame, layers, size)
  size = math.max(0.75, math.min(2.25, size or 1.35))
  local spread = AURA_GLOW_MAX_SPREAD * size
  local rawWidth = btn.GetWidth and btn:GetWidth() or 0
  local width = ns.Plain(rawWidth)
  if type(width) ~= "number" or width <= 0 then width = btn._auraSize or 24 end

  for _, layer in ipairs(layers) do
    local tex = layer.texture
    tex:ClearAllPoints()
    local layerSpread = spread * layer.spreadFactor
    local ratio = layerSpread / (width + 2 * layerSpread)
    local bucketIndex = math.ceil((ratio - AURA_GLOW_RATIO_MIN) / AURA_GLOW_RATIO_STEP - 0.00001)
    local bucket = AURA_GLOW_RATIO_MIN + bucketIndex * AURA_GLOW_RATIO_STEP
    bucket = math.max(AURA_GLOW_RATIO_MIN, math.min(AURA_GLOW_RATIO_MAX, bucket))
    if layer.ratio ~= bucket then
      tex:SetTexture(ROUND_GLOW_GRADIENT_PREFIX .. string.format("%02d.png", math.floor(bucket * 100 + 0.5)))
      layer.ratio = bucket
    end
    tex:SetPoint("TOPLEFT", frame, "TOPLEFT", -layerSpread, layerSpread)
    tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", layerSpread, -layerSpread)
  end
end

function Row.UpdateAuraAnimationLayout(btn, neonSize, pulseSize)
  local state = btn and btn._rfaAuraAnimation
  if not state then return end
  LayoutGlowLayers(btn, state, state.neonFrame, state.neonLayers, neonSize)
  LayoutGlowLayers(btn, state, state.pulseFrame, state.pulseLayers, pulseSize)
end

local function NeonColor(r, g, b)
  r, g, b = math.max(0, math.min(1, r)), math.max(0, math.min(1, g)), math.max(0, math.min(1, b))
  local high, low = math.max(r, g, b), math.min(r, g, b)
  local delta = high - low
  if high <= 0 then return r, g, b end

  local value = math.min(1, high * 1.12 + 0.03)
  if delta <= 0.0001 then return value, value, value end

  local hue
  if high == r then
    hue = ((g - b) / delta) % 6
  elseif high == g then
    hue = ((b - r) / delta) + 2
  else
    hue = ((r - g) / delta) + 4
  end
  hue = hue / 6

  local saturation = math.min(1, delta / high * 1.18 + 0.08)
  local sector = hue * 6
  local index = math.floor(sector)
  local fraction = sector - index
  local p = value * (1 - saturation)
  local q = value * (1 - fraction * saturation)
  local t = value * (1 - (1 - fraction) * saturation)
  local branch = index % 6
  if branch == 0 then return value, t, p end
  if branch == 1 then return q, value, p end
  if branch == 2 then return p, value, t end
  if branch == 3 then return p, q, value end
  if branch == 4 then return t, p, value end
  return value, p, q
end
Row.NeonColor = NeonColor

local function StopGroup(state, field)
  local g = state[field]
  if g then pcall(g.Stop, g); state[field] = nil end
end

local function ResetEffects(state)
  StopGroup(state, "appearGroup")
  StopGroup(state, "activeGroup")
  if state.orbitGroup then state.orbitGroup:Stop() end
  state.frame:SetScript("OnUpdate", nil)
  state.isAnimating = false
  state.borderTransition = nil
  state.neonTransition = nil
  state.frame:SetAlpha(0)
  state.neonFrame:SetAlpha(0)
  state.pulseFrame:SetAlpha(0)
  state.orbitFrame:SetAlpha(0)
end

function Row.ClearAuraAnimation(btn)
  if not btn then return end
  local state = btn._rfaAuraAnimation
  if state then
    ResetEffects(state)
    state.visible = false
    state.key = nil
    state.settings = nil
    state.active = { border = false, neon = false, borderPulse = false, borderOrbit = false }
    state.effects = {}
    state.borderColor = nil
    state.borderNative = false
    state.borderStrength = nil
  end
  Row.SetAuraDispelTypeBorder(btn, false)
  local ring = btn.ring or btn._ring
  if ring then
    ring:SetAlpha(0)
    ring:SetVertexColor(1, 1, 1, 0)
    ring:SetScale(1)
  end
  btn._pendingAppear = nil
end

local function AddDispelTypeTexture(btn, texture, showWhenHelpful)
  local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
  if not btn or not texture or not btn.AddDispelTypeTexture or not styles then return false end
  local ok = pcall(btn.AddDispelTypeTexture, btn, texture, {
    style = styles.PreserveAsset,
    showWhenHarmful = true,
    showWhenHelpful = showWhenHelpful == true,
    showWithoutDispelType = true,
  })
  return ok
end

function Row.SetAuraDispelTypeBorder(btn, enabled)
  local ring = btn and (btn.ring or btn._ring)
  if not btn or not ring then return false end

  if enabled then
    if btn._rfaNativeDispelRing then return true end
    local attached = AddDispelTypeTexture(btn, ring, true)
    if attached then btn._rfaNativeDispelRing = true end
    return attached
  end

  if btn._rfaNativeDispelRing then
    if btn.RemoveDispelTypeTexture then
      pcall(btn.RemoveDispelTypeTexture, btn, ring)
    end
    btn._rfaNativeDispelRing = nil
  end
  ring:SetAlpha(0)
  ring:SetVertexColor(1, 1, 1, 0)
  ring:SetScale(1)
  return true
end

function Row.SetupAnimationDispelType(btn, enabled)
  if not enabled then return end
  local state = btn and btn._rfaAuraAnimation
  if not state or state.dispelTypeSetup then return end
  local attached = false
  for _, layers in ipairs({ state.neonLayers, state.pulseLayers }) do
    for _, layer in ipairs(layers) do
      if AddDispelTypeTexture(btn, layer.texture, false) then attached = true end
    end
  end
  state.dispelTypeSetup = attached
end

local function EnsureOrbitDashes(state)
  if state.orbitDashes then return state.orbitDashes end
  local dashes = {}
  local count = OrbitDashCount(state)
  local lengthCode = OrbitDashLengthCode(state)
  local function CreateSide(name, asset, firstPoint, secondPoint, flip)
    local tex = state.orbitFrame:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(asset)
    tex:SetBlendMode("BLEND")
    tex:SetPoint(firstPoint, state.orbitFrame, firstPoint)
    tex:SetPoint(secondPoint, state.orbitFrame, secondPoint)
    if flip then tex:SetRotation(math.pi) end
    if state.color then tex:SetVertexColor(state.color[1], state.color[2], state.color[3], 1) end
    if state.dispelTypeSetup and state.settings and state.settings.colorMode == "dispel" then
      AddDispelTypeTexture(state.btn, tex, false)
    end
    dashes[name] = tex
    return tex
  end

  local horizontal = OrbitDashAtlasPath("Horizontal", count, lengthCode)
  local vertical = OrbitDashAtlasPath("Vertical", count, lengthCode)
  CreateSide("top", horizontal, "TOPLEFT", "TOPRIGHT", false)
  CreateSide("right", vertical, "TOPRIGHT", "BOTTOMRIGHT", false)
  CreateSide("bottom", horizontal, "BOTTOMLEFT", "BOTTOMRIGHT", true)
  CreateSide("left", vertical, "TOPLEFT", "BOTTOMLEFT", true)

  local group = state.orbitFrame:CreateAnimationGroup()
  group:SetLooping("REPEAT")
  local animations = {}
  for _, side in ipairs({ "top", "right", "bottom", "left" }) do
    local flipbook = group:CreateAnimation("Flipbook")
    flipbook:SetTarget(dashes[side])
    flipbook:SetFlipBookColumns(ORBIT_FLIPBOOK_COLUMNS)
    flipbook:SetFlipBookRows(ORBIT_FLIPBOOK_ROWS)
    flipbook:SetDuration(ORBIT_CYCLE_SECONDS)
    animations[#animations + 1] = flipbook
  end
  state.orbitGroup = group
  state.orbitAnimations = animations
  state.orbitDashes = dashes
  state.orbitAtlasKey = string.format("%d:%d", count, lengthCode)
  return dashes
end

local function UpdateOrbitDashes(state)
  local count = OrbitDashCount(state)
  local lengthCode = OrbitDashLengthCode(state)
  local atlasKey = string.format("%d:%d", count, lengthCode)
  if state.orbitAtlasKey ~= atlasKey then
    local dashes = state.orbitDashes
    dashes.top:SetTexture(OrbitDashAtlasPath("Horizontal", count, lengthCode))
    dashes.bottom:SetTexture(OrbitDashAtlasPath("Horizontal", count, lengthCode))
    dashes.left:SetTexture(OrbitDashAtlasPath("Vertical", count, lengthCode))
    dashes.right:SetTexture(OrbitDashAtlasPath("Vertical", count, lengthCode))
    state.orbitAtlasKey = atlasKey
  end
  local size = math.max(0.75, math.min(2.25, state.orbitSize or 1.35))
  local auraSize = ns.Plain(state.btn._auraSize) or 24
  local dashThickness = ORBIT_DASH_THICKNESS * (auraSize / 24) * math.sqrt(size)
  state.orbitDashes.top:SetHeight(dashThickness)
  state.orbitDashes.bottom:SetHeight(dashThickness)
  state.orbitDashes.left:SetWidth(dashThickness)
  state.orbitDashes.right:SetWidth(dashThickness)
  state.orbitDashThickness = dashThickness
end

local function StartOrbitAnimation(state)
  EnsureOrbitDashes(state)
  UpdateOrbitDashes(state)
  if not state.orbitGroup then return end
  state.orbitGroup:Stop()
  -- Keep the dashes moving at the same on-screen rate when their count changes.
  local duration = ORBIT_CYCLE_SECONDS * (2 / OrbitDashCount(state)) / math.max(0.35, state.orbitSpeed or 1)
  for _, animation in ipairs(state.orbitAnimations) do
    animation:SetDuration(duration)
  end
  state.orbitGroup:Play()
end

local function ResumeActiveEffect(state)
  if not state.visible then return end
  
  if state.appearGroup then
    local playing = state.appearGroup:IsPlaying()
    if playing == nil or ns.IsSecret(playing) then playing = true end
    if playing then return end
  end

  local active = state.active or {}
  local hasEffect = active.border or active.neon or active.borderPulse or active.borderOrbit
  if not hasEffect then
    state.frame:SetAlpha(0)
    state.neonFrame:SetAlpha(0)
    state.pulseFrame:SetAlpha(0)
    state.orbitFrame:SetAlpha(0)
    if state.orbitGroup then state.orbitGroup:Stop() end
    return
  end

  state.frame:SetAlpha(1)
  if active.border and not state.borderTransition then
    local ring = state.btn.ring or state.btn._ring
    if ring and state.borderNative then
      ring:SetAlpha(state.borderStrength or 1)
    elseif ring and state.borderColor then
      ring:SetVertexColor(state.borderColor[1], state.borderColor[2], state.borderColor[3], state.borderStrength)
    end
  end
  if active.neon then
    if not state.neonTransition then state.neonFrame:SetAlpha(state.effects.neon.strength) end
  else
    state.neonFrame:SetAlpha(0)
  end

  if active.borderPulse and state.activeGroup then
    if not state.isAnimating then
      state.isAnimating = true
      state.pulseFrame:SetAlpha(1)
      state.activeGroup:Play()
    end
  else
    state.pulseFrame:SetAlpha(active.borderPulse and state.effects.borderPulse.strength or 0)
  end

  if active.borderOrbit then
    state.orbitFrame:SetAlpha(state.effects.borderOrbit.strength)
    StartOrbitAnimation(state)
  else
    state.orbitFrame:SetAlpha(0)
    if state.orbitGroup then state.orbitGroup:Stop() end
  end
end

local function ApplyLayerColor(state, r, g, b)
  state.color = { r, g, b }
  for _, layers in ipairs({ state.neonLayers, state.pulseLayers }) do
    for _, layer in ipairs(layers) do layer.texture:SetVertexColor(r, g, b, 1) end
  end
  if state.orbitDashes then
    for _, tex in pairs(state.orbitDashes) do tex:SetVertexColor(r, g, b, 1) end
  end
end
Row.ApplyLayerColor = ApplyLayerColor

local function ApplyAuraBorder(btn, settings, auraColor, state, enabled, effectSettings)
  local ring = btn.ring or btn._ring
  if not ring then return end
  if not enabled then
    if btn._rfaNativeDispelRing then ring:SetAlpha(0)
    else ring:SetVertexColor(1, 1, 1, 0) end
    ring:SetScale(1)
    if state then state.borderColor, state.borderNative = nil, false end
    return
  end

  local useNativeColor = settings.colorMode == "dispel" and btn._rfaNativeDispelRing == true
  local r, g, b = settings.r or 1, settings.g or 1, settings.b or 1
  if not useNativeColor and settings.colorMode == "dispel" and auraColor
      and not (issecretvalue and (issecretvalue(auraColor[1]) or issecretvalue(auraColor[2]) or issecretvalue(auraColor[3]))) then
    r, g, b = auraColor[1], auraColor[2], auraColor[3]
  end
  if state then
    if useNativeColor then state.borderColor = nil
    else state.borderColor = { r, g, b } end
    state.borderNative = useNativeColor
    state.borderStrength = effectSettings.strength
  end
  if useNativeColor then ring:SetAlpha(effectSettings.strength)
  else
    ring:SetAlpha(1)
    ring:SetVertexColor(r, g, b, effectSettings.strength)
  end
  ring:SetScale(math.max(0.875, math.min(1.325, 0.65 + effectSettings.size * 0.3)))
end

local StartEntryTransitions

function Row.ApplyAuraAnimation(btn, settings, auraColor)
  if not btn or not settings then return end
  local appear = settings.appear or "none"
  local rawActive = settings.active
  local active = { border = false, neon = false, borderPulse = false, borderOrbit = false }
  if type(rawActive) == "table" then
    active.border = rawActive.border == true
    active.neon = rawActive.neon == true
    active.borderPulse = rawActive.borderPulse == true
    active.borderOrbit = rawActive.borderOrbit == true
  elseif rawActive == "border" then
    active.border = true
  elseif rawActive == "borderPulse" or rawActive == "soft" or rawActive == "neon" then
    active.borderPulse = true
  elseif rawActive == "borderOrbit" then
    active.borderOrbit = true
  end
  local hasActive = active.border or active.neon or active.borderPulse or active.borderOrbit
  local rawEffects = settings.effects or {}
  local effects = {}
  for _, name in ipairs({ "border", "neon", "borderPulse", "borderOrbit" }) do
    local raw = rawEffects[name] or {}
    effects[name] = {
      speed = math.max(0.35, math.min(2.5, raw.speed or settings.appearSpeed or 1)),
      strength = math.max(0.1, math.min(1, raw.strength or 0.65)),
      size = math.max(0.75, math.min(2.25, raw.size or 1.35)),
      length = math.max(ORBIT_DASH_LENGTH_MIN, math.min(ORBIT_DASH_LENGTH_MAX, raw.length or 1)),
      count = math.max(ORBIT_DASH_COUNT_MIN, math.min(ORBIT_DASH_COUNT_MAX, math.floor((raw.count or 2) + 0.5))),
    }
  end
  local appearSpeed = math.max(0.35, math.min(2.5, settings.appearSpeed or settings.speed or 1))
  local state = btn._rfaAuraAnimation
  if not state then
    if appear == "none" and not hasActive then return end
    state = EnsureAuraAnimationRegions(btn)
  end

  if settings.category == "Debuff" or settings.category == "CC" then
    Row.SetupAnimationDispelType(btn, settings.colorMode == "dispel")
  end

  Row.SetAuraDispelTypeBorder(btn, active.border and settings.colorMode == "dispel")
  ApplyAuraBorder(btn, settings, auraColor, state, active.border, effects.border)
  state.settings = settings

  local colorMode = settings.colorMode or "category"
  if colorMode == "category" then
    local r, g, b = NeonColor(settings.r or 1, settings.g or 1, settings.b or 1)
    ApplyLayerColor(state, r, g, b)
  elseif colorMode == "dispel" and state.dispelTypeSetup then
    -- AuraContainer applies the dispel color to these textures natively. This
    -- remains correct when the aura data is secret during battleground combat.
  elseif colorMode == "dispel" then
    if auraColor and not (issecretvalue and (issecretvalue(auraColor[1]) or issecretvalue(auraColor[2]) or issecretvalue(auraColor[3]))) then
      local r, g, b = NeonColor(auraColor[1], auraColor[2], auraColor[3])
      ApplyLayerColor(state, r, g, b)
    else
      local r, g, b = NeonColor(settings.r or 1, settings.g or 1, settings.b or 1)
      ApplyLayerColor(state, r, g, b)
    end
  end

  local key = table.concat({
    tostring(appear), tostring(active.border), tostring(active.neon), tostring(active.borderPulse), tostring(active.borderOrbit),
    tostring(settings.colorMode or "category"), string.format("%.3f", appearSpeed),
    string.format("%.3f", settings.r or 1), string.format("%.3f", settings.g or 1), string.format("%.3f", settings.b or 1),
    string.format("%.3f", effects.border.speed), string.format("%.3f", effects.border.strength), string.format("%.3f", effects.border.size),
    string.format("%.3f", effects.neon.speed), string.format("%.3f", effects.neon.strength), string.format("%.3f", effects.neon.size),
    string.format("%.3f", effects.borderPulse.speed), string.format("%.3f", effects.borderPulse.strength), string.format("%.3f", effects.borderPulse.size),
    string.format("%.3f", effects.borderOrbit.speed), string.format("%.3f", effects.borderOrbit.strength), string.format("%.3f", effects.borderOrbit.size),
    string.format("%.3f", effects.borderOrbit.length), tostring(effects.borderOrbit.count),
  }, ":")
  Row.UpdateAuraAnimationLayout(btn, effects.neon.size, effects.borderPulse.size)
  
  if state.key == key then 
    return 
  end

  ResetEffects(state)
  state.active = active
  state.effects = effects
  state.orbitSpeed = effects.borderOrbit.speed
  state.orbitSize = effects.borderOrbit.size
  state.orbitLength = effects.borderOrbit.length
  state.orbitCount = effects.borderOrbit.count
  if active.borderOrbit then
    EnsureOrbitDashes(state)
    UpdateOrbitDashes(state)
  end

  if appear == "fade" or appear == "flash" then
    local inDur, outDur
    if appear == "flash" then
      inDur, outDur = 0.08 / appearSpeed, 0.22 / appearSpeed
    else
      inDur, outDur = 0.18 / appearSpeed, 0.32 / appearSpeed
    end
    local group = state.frame:CreateAnimationGroup()
    local a1 = group:CreateAnimation("Alpha")
    a1:SetOrder(1); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(inDur)
    local a2 = group:CreateAnimation("Alpha")
    a2:SetOrder(2); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(outDur)
    group:SetScript("OnFinished", function()
      if state.appearGroup ~= group then return end
      state.frame:SetAlpha(0)
      ResumeActiveEffect(state)
    end)
    state.appearGroup = group
  end

  if active.borderPulse then
    state.activeGroup = state.pulseFrame:CreateAnimationGroup()
    state.activeGroup:SetLooping("BOUNCE")
    local strength = effects.borderPulse.strength
    local alpha = state.activeGroup:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.3 * strength); alpha:SetToAlpha(strength)
    alpha:SetDuration(0.9 / effects.borderPulse.speed)
    state.isAnimating = false
  end

  state.key = key
  
  local isShown = btn:IsShown()
  if ns.IsSecret(isShown) then isShown = true end
  if isShown then
    state.visible = true
    StartEntryTransitions(state)
    ResumeActiveEffect(state)
  else
    state.visible = false
  end
end

StartEntryTransitions = function(state)
  local active, effects = state.active or {}, state.effects or {}
  state.borderTransition, state.neonTransition = nil, nil

  if active.border and (state.borderColor or state.borderNative) then
    local ring = state.btn.ring or state.btn._ring
    if ring then
      if state.borderNative then ring:SetAlpha(0)
      else ring:SetVertexColor(state.borderColor[1], state.borderColor[2], state.borderColor[3], 0) end
      state.borderTransition = {
        elapsed = 0,
        duration = ACTIVE_EFFECT_FADE_SECONDS / effects.border.speed,
        target = effects.border.strength,
      }
    end
  end
  if active.neon then
    state.neonFrame:SetAlpha(0)
    state.neonTransition = {
      elapsed = 0,
      duration = ACTIVE_EFFECT_FADE_SECONDS / effects.neon.speed,
      target = effects.neon.strength,
    }
  end

  if not state.borderTransition and not state.neonTransition then
    state.frame:SetScript("OnUpdate", nil)
    return
  end

  state.frame:SetScript("OnUpdate", function(_, elapsed)
    local running = false
    local transition = state.borderTransition
    if transition then
      transition.elapsed = math.min(transition.duration, transition.elapsed + elapsed)
      local progress = transition.duration > 0 and transition.elapsed / transition.duration or 1
      local ring = state.btn.ring or state.btn._ring
      if ring and (state.borderColor or state.borderNative) then
        if state.borderNative then ring:SetAlpha(transition.target * progress)
        else ring:SetVertexColor(state.borderColor[1], state.borderColor[2], state.borderColor[3], transition.target * progress) end
      end
      if progress >= 1 then state.borderTransition = nil else running = true end
    end

    transition = state.neonTransition
    if transition then
      transition.elapsed = math.min(transition.duration, transition.elapsed + elapsed)
      local progress = transition.duration > 0 and transition.elapsed / transition.duration or 1
      state.neonFrame:SetAlpha(transition.target * progress)
      if progress >= 1 then state.neonTransition = nil else running = true end
    end

    if not running then state.frame:SetScript("OnUpdate", nil) end
  end)
end

function Row.PlayAuraAssignedAnimation(btn)
  local state = btn and btn._rfaAuraAnimation
  if not state then return end
  StartEntryTransitions(state)
  if state.activeGroup then
    state.activeGroup:Stop()
    state.isAnimating = false
  end
  if state.orbitGroup then state.orbitGroup:Stop() end
  state.neonFrame:SetAlpha(0)
  state.pulseFrame:SetAlpha(0)
  state.orbitFrame:SetAlpha(0)
  state.frame:SetAlpha(0)
  if state.appearGroup then
    state.appearGroup:Stop()
    state.appearGroup:Play()
  else
    ResumeActiveEffect(state)
  end
end

function Row.SetAuraAnimationVisible(btn, shown)
  local state = btn and btn._rfaAuraAnimation
  if not state then return end
  if ns.IsSecret(shown) then shown = true end
  local newVisible = shown and true or false
  if state.visible == newVisible then return end
  state.visible = newVisible
  if shown then
    StartEntryTransitions(state)
    ResumeActiveEffect(state)
  else
    if state.activeGroup then 
      state.activeGroup:Stop() 
      state.isAnimating = false
    end
    if state.appearGroup then state.appearGroup:Stop() end
    if state.orbitGroup then state.orbitGroup:Stop() end
    state.frame:SetScript("OnUpdate", nil)
    state.borderTransition, state.neonTransition = nil, nil
    state.pulseFrame:SetAlpha(0)
    state.orbitFrame:SetAlpha(0)
    state.frame:SetAlpha(0)
  end
end
