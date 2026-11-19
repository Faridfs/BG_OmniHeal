local _, ns = ...
local Row = ns.Row

local ROUND_RING = ns.Theme.MEDIA .. "rounded-ring.png"

function Row.AuraIcon(a, i)
  local btn = a.icons[i]
  if btn then return btn end
  btn = CreateFrame("Frame", nil, a)
  btn.icon, btn.cd, btn.ring, btn.count = Row.DecorateAuraIcon(btn)
  btn:Hide(); a.icons[i] = btn
  return btn
end

function Row.ApplyTimerFont(btn, kind)
  if not btn then return end
  local scale = btn._rfaLargePriority and 1.4 or 1
  local size = 14
  if kind == "heals" then size = ns.db.timerSizeHeals or 14
  elseif kind == "externals" then size = ns.db.timerSizeExternals or 14
  elseif kind == "dispels" then size = ns.db.timerSizeDispels or 14
  elseif kind == "allyCC" then size = ns.db.timerSizeAllyCC or 16
  elseif kind == "debuffs" then size = ns.db.timerSizeDebuffs or 14
  elseif kind == "enemyCC" then size = ns.db.timerSizeEnemyCC or 16
  elseif kind == "enemyDef" then size = ns.db.timerSizeDefensives or 14
  end
  local cd = btn.cd
  if cd then
    for _, region in ipairs({cd:GetRegions()}) do
      if region:IsObjectType("FontString") then
        region:SetFont(ns.Theme.GetFont(), size * scale, "OUTLINE")
      end
    end
  end
  if btn.count then
    local team = (kind == "heals" or kind == "externals" or kind == "dispels" or kind == "allyCC") and "ally" or "enemy"
    btn.count:SetFont(ns.Theme.GetFont(), (ns.db[team .. "StackSize"] or ns.db.stackSize or 12) * scale, "OUTLINE")
  end
end

function ns.UpdateTimerFonts()
  if not OmniHeal_ally or not OmniHeal_enemy then return end
  for _, list in ipairs({OmniHeal_ally, OmniHeal_enemy}) do
    for _, row in ipairs(list.rows) do
      local groups = {
        { box = row.healBox, kind = "heals" },
        { box = row.externalBox, kind = "externals" },
        { box = row.dispelBox, kind = "dispels" },
        { box = row.debuffBox, kind = "debuffs" },
        { box = row.enemyCCBox, kind = "enemyCC" },
        { box = row.allyCCBox, kind = "allyCC" },
        { box = row.enemyDefBox, kind = "enemyDef" },
      }
      for _, g in ipairs(groups) do
        if g.box then
          if g.box.GetAuraGroupFrameCount then
            local groupKeys = { g.kind }
            if g.kind == "dispels" or g.kind == "debuffs" then
              groupKeys[#groupKeys + 1] = g.kind .. "Priority"
            end
            for _, groupKey in ipairs(groupKeys) do
              local count = g.box:GetAuraGroupFrameCount(groupKey) or 0
              for i = 1, count do
                local btn = g.box:GetAuraGroupFrame(groupKey, i)
                if btn and (not btn.CanBeAccessedInContext or btn:CanBeAccessedInContext()) then
                  Row.ApplyTimerFont(btn, g.kind)
                end
              end
            end
          end
          if g.box.icons then
            for _, btn in ipairs(g.box.icons) do
              Row.ApplyTimerFont(btn, g.kind)
            end
          end
        end
      end

      local legacyGroups = {
        { box = row.auras, kind = "heals" },
        { box = row.externals, kind = "externals" },
        { box = row.dispels, kind = "dispels" },
        { box = row.allyCC, kind = "allyCC" },
        { box = row.enemyCC, kind = "enemyCC" },
        { box = row.defs, kind = "enemyDef" },
      }
      for _, g in ipairs(legacyGroups) do
        if g.box and g.box.icons then
          for _, btn in ipairs(g.box.icons) do
            Row.ApplyTimerFont(btn, g.kind)
          end
        end
      end
    end
  end
end

function Row.DecorateAuraIcon(btn)
  if btn.Background then btn.Background:SetAlpha(0) end
  if btn.IconBackground then btn.IconBackground:SetAlpha(0) end
  if btn.Bg then btn.Bg:SetAlpha(0) end
  if btn.bg then btn.bg:SetAlpha(0) end

  local regions = { btn:GetRegions() }
  for i = 1, #regions do
    local region = regions[i]
    if region and region.IsObjectType and region:IsObjectType("Texture") and region.GetDrawLayer then
      local layer = region:GetDrawLayer()
      if layer == "BACKGROUND" or layer == "BORDER" then
        region:SetAlpha(0)
      end
    end
  end

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(btn)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  Row.RoundTexture(btn, icon)

  local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
  cd:SetAllPoints(btn)
  cd:SetScale(0.6)
  cd:SetSwipeTexture(Row.ROUND_MASK)
  cd:SetSwipeColor(0, 0, 0, 0.65)
  cd:SetDrawEdge(false)
  cd:SetDrawBling(false)
  cd:SetReverse(true)

  local over = CreateFrame("Frame", nil, btn)
  over:SetAllPoints()
  over:SetFrameLevel(cd:GetFrameLevel() + 1)
  btn._omniHealAuraOverlay = over
  local ring = over:CreateTexture(nil, "OVERLAY")
  ring:SetPoint("TOPLEFT", 0, 0)
  ring:SetPoint("BOTTOMRIGHT", 0, 0)
  ring:SetTexture(ROUND_RING)
  ring:SetVertexColor(0, 0, 0, 0)

  local count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  count:SetPoint("BOTTOMRIGHT", 2, -1)

  btn.cd = cd
  btn.count = count

  Row.ApplyTimerFont(btn, btn.rfaKind)

  return icon, cd, ring, count
end

function Row.SetAuraIconFrameLevel(btn, level)
  if not btn or not level then return end
  pcall(btn.SetFrameLevel, btn, level)
  -- Reserve three levels inside each aura layer for the cooldown, custom border, and animation.
  if btn.cd then pcall(btn.cd.SetFrameLevel, btn.cd, level + 1) end
  if btn._omniHealAuraOverlay then
    pcall(btn._omniHealAuraOverlay.SetFrameLevel, btn._omniHealAuraOverlay, level + 2)
  end
  local animation = btn._rfaAuraAnimation
  if animation and animation.frame then
    pcall(animation.frame.SetFrameLevel, animation.frame, level + 3)
  end
end

Row.AURA_ANCHORS = {
  TOPLEFT = "Top left", TOP = "Top", TOPRIGHT = "Top right", LEFT = "Middle left", CENTER = "Middle", RIGHT = "Middle right",
  BOTTOMLEFT = "Bottom left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom right",
}
Row.AURA_ANCHOR_ORDER = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local CENTERED = { TOP = true, CENTER = true, BOTTOM = true }

function Row.AuraGrowsCentered(anchor) return CENTERED[anchor] == true end

function Row.AuraPoint(anchor, grow)
  anchor = Row.AURA_ANCHORS[anchor] and anchor or "RIGHT"
  local centered = CENTERED[anchor]
  local toLeft = not centered and grow == "left"
  local inset = 1
  local x = anchor:find("LEFT") and inset or (anchor:find("RIGHT") and -inset or 0)
  local y = anchor:find("TOP") and -inset or (anchor:find("BOTTOM") and inset or 0)
  local point = anchor
  if toLeft and anchor:find("LEFT") then point = anchor:gsub("LEFT", "RIGHT")
  elseif not centered and not toLeft and anchor:find("RIGHT") then point = anchor:gsub("RIGHT", "LEFT") end
  return point, anchor, x, y, toLeft
end

function Row.LayoutAuras(row, a, n, size, anchor, grow, offsetX, offsetY, spacing, layer)
  if not a then return end
  local point, x, y, toLeft
  point, anchor, x, y, toLeft = Row.AuraPoint(anchor, grow)
  local gap = spacing or 2
  local groupLevel = row.content:GetFrameLevel() + (tonumber(layer) or 2) * 4
  local cursor, width, height = 0, 0, 0
  a:SetFrameLevel(groupLevel)
  for i = 1, #a.icons do
    local btn = a.icons[i]
    Row.SetAuraIconFrameLevel(btn, groupLevel + 1)
    if i <= n then
      local iconSize = tonumber(btn._rfaLayoutSize) or size
      btn:SetSize(iconSize, iconSize)
      btn._auraSize = iconSize
      if i > 1 then cursor = cursor + gap end
      cursor = cursor + iconSize
      width, height = cursor, math.max(height, iconSize)
    else
      btn:Hide()
      btn._rfaLayoutSize = nil
      Row.SetAuraAnimationVisible(btn, false)
      btn._shownSpellID, btn._currentSpellID, btn._pendingAppear, btn._hasShownAura = nil, nil, nil, nil
    end
  end
  a:SetSize(n > 0 and width or 1, n > 0 and height or size)
  a:ClearAllPoints()
  a:SetPoint(point, row.barArea, anchor, x + (offsetX or 0), y + (offsetY or 0))
  cursor = 0
  for i = 1, n do
    local btn = a.icons[i]
    local iconSize = tonumber(btn._rfaLayoutSize) or size
    btn:ClearAllPoints()
    if i > 1 then cursor = cursor + gap end
    if toLeft then
      btn:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -cursor, 0)
    else
      btn:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", cursor, 0)
    end
    cursor = cursor + iconSize
    local animation = btn._rfaAuraAnimation
    Row.UpdateAuraAnimationLayout(btn,
      animation and animation.effects.neon and animation.effects.neon.size or 1.35,
      animation and animation.effects.borderPulse and animation.effects.borderPulse.size or 1.35)
    btn:Show()
    Row.SetAuraAnimationVisible(btn, true)
    if btn._pendingAppear then
      btn._pendingAppear = nil
      Row.PlayAuraAssignedAnimation(btn)
    end
  end
end
