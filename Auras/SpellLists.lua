local _, ns = ...
local Auras = ns:NewModule("Auras")

-- Player-cast healing auras and shields.
Auras.TRACKED = {
  -- Priest
  [194384] = true, [17] = true, [139] = true, [41635] = true, [77489] = true, [10060] = true,
  [1253590] = true, [1253845] = true, [1253827] = true, [1253593] = true,
  [1300008] = true, [1300009] = true, -- Unfolding Vision shield variants

  -- Druid
  [774] = true, [155777] = true, [8936] = true, [33763] = true, [188550] = true, [48438] = true,
  [102351] = true, [102352] = true, [200389] = true, [207386] = true, [391891] = true,

  -- Shaman
  [61295] = true, [974] = true, [383648] = true, [382024] = true,

  -- Paladin
  [53563] = true, [156910] = true, [200025] = true, [287280] = true, [156322] = true, [223306] = true,
  [432496] = true, [432502] = true,
  [1244893] = true, [431381] = true, -- Beacon of the Savior, Dawnlight

  -- Monk
  [119611] = true, [124682] = true, [115175] = true,

  -- Evoker
  [364343] = true, [366155] = true, [367364] = true, [355941] = true, [376788] = true,
  [373267] = true, [363502] = true, [360827] = true,
}

-- Defensives shown when the ally defensive filter uses the custom list.
Auras.EXTERNALS = {
  [642] = true, [1022] = true, [6940] = true, [204018] = true, [498] = true,
  [116849] = true,
  [33206] = true, [47788] = true, [62618] = true, [47585] = true,
  [102342] = true, [22812] = true, [61336] = true, [102558] = true,
  [357170] = true,
  [51052] = true, [48707] = true, [48792] = true, [55233] = true,
  [196718] = true, [198582] = true, [187827] = true, [212800] = true, [205604] = true, [206649] = true,
  [97462] = true, [3411] = true, [23920] = true,
  [53480] = true, [186265] = true, [264735] = true,
  [98008] = true, [204336] = true, [108270] = true,
  [31224] = true, [5277] = true,
  [45438] = true, [198111] = true, [235313] = true,
}

-- Orb carrier buffs are already represented by the dedicated carrier marker.
-- Exclude them from Blizzard's broad defensive aura groups to avoid showing
-- the same orb twice on ally and enemy battleground frames.
Auras.ORB_CARRIER_AURAS = {
  [121164] = true, [121175] = true, [121176] = true, [121177] = true,
}

-- Personal defensives by the class of the player who has the aura.
Auras.CLASS_SELF_DEFS = {
  PALADIN     = { [642] = true, [498] = true, [184662] = true },
  MAGE        = { [45438] = true, [110959] = true },
  HUNTER      = { [186265] = true },
  ROGUE       = { [31224] = true, [5277] = true },
  DEATHKNIGHT = { [48707] = true, [48792] = true, [55233] = true, [49039] = true },
  WARRIOR     = { [23920] = true, [118038] = true, [871] = true },
  DEMONHUNTER = { [198589] = true, [187827] = true, [196718] = true },
  DRUID       = { [22812] = true, [61336] = true, [102558] = true },
  PRIEST      = { [47585] = true, [19236] = true },
  MONK        = { [122783] = true, [115176] = true, [122278] = true },
  SHAMAN      = { [108271] = true, [108270] = true },
  WARLOCK     = { [104773] = true, [108416] = true },
  EVOKER      = { [363916] = true, [370537] = true },
}
