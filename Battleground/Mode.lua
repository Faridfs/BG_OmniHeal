local _, ns = ...

local function MatchFlag(read)
  return read and ns.Plain(read()) == true
end

local function MapCapacity(mapID)
  if not mapID or mapID == 0 or not GetNumBattlegroundTypes or not (C_PvP and C_PvP.GetBattlegroundInfo) then return end
  local count = ns.Plain(GetNumBattlegroundTypes())
  if type(count) ~= "number" then return end
  for index = 1, count do
    local entry = ns.Plain(C_PvP.GetBattlegroundInfo(index))
    if entry and ns.Plain(entry.mapID) == mapID then
      local capacity = ns.Plain(entry.maxPlayers)
      if type(capacity) == "number" and capacity > 0 then return capacity end
    end
  end
end

-- The same map can host Blitz, a rated match, or a random battleground.
-- Only unranked matches use capacity to decide whether frames should run.
function ns.GetBattlegroundLayout()
  local pvp = C_PvP
  if pvp and (MatchFlag(pvp.IsSoloRBG) or MatchFlag(pvp.IsRatedSoloRBG) or MatchFlag(pvp.IsBrawlSoloRBG)) then
    return "8"
  end
  if MatchFlag(pvp and pvp.IsRatedBattleground or IsRatedBattleground) then return "10" end

  local _, _, _, _, instanceCapacity, _, _, mapID = GetInstanceInfo()
  local capacity = MapCapacity(ns.Plain(mapID)) or ns.Plain(instanceCapacity)
  if type(capacity) ~= "number" or capacity <= 0 then return nil, "waiting for battleground size" end
  if capacity > 15 then return nil, "epic or large battleground" end
  return "15"
end

local function MatchUpdated()
  if ns.inBG then ns:UpdateState() end
end

ns:On("UPDATE_BATTLEFIELD_STATUS", MatchUpdated)
if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("PVP_MATCH_STATE_CHANGED") then
  ns:On("PVP_MATCH_STATE_CHANGED", MatchUpdated)
end
