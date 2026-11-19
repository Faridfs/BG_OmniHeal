local _, ns = ...
local Profiles = ns:NewModule("Profiles")

Profiles.ROLES = { "HEALER", "DAMAGER", "TANK" }
Profiles.ROLE_NAMES = { HEALER = "Healer", DAMAGER = "Damage", TANK = "Tank" }

local function DeepCopy(src)
  local out = {}
  for k, v in pairs(src) do
    out[k] = type(v) == "table" and DeepCopy(v) or v
  end
  return out
end

local PROFILE_PREFIX = "BGOH-PROFILE-1:"
local PROFILE_MAX_SIZE = 262144
local PROFILE_MAX_DEPTH = 32
local PROFILE_MAX_NODES = 20000

local function EncodeString(value)
  local escaped = value:gsub("[%c%%]", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
  return "S" .. #escaped .. ":" .. escaped
end

local function EncodeValue(value, depth, seen)
  if depth > PROFILE_MAX_DEPTH then error("Profile is nested too deeply.") end
  local valueType = type(value)
  if valueType == "string" then
    return EncodeString(value)
  elseif valueType == "boolean" then
    return value and "B1" or "B0"
  elseif valueType == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("Profile contains an invalid number.")
    end
    return "N" .. string.format("%.17g", value) .. ";"
  elseif valueType ~= "table" then
    error("Profile contains an unsupported value.")
  end

  if seen[value] then error("Profile contains a circular reference.") end
  seen[value] = true
  local keys = {}
  for key in pairs(value) do
    local keyType = type(key)
    if keyType ~= "string" and keyType ~= "number" and keyType ~= "boolean" then
      error("Profile contains an unsupported table key.")
    end
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    return tostring(a) < tostring(b)
  end)

  local parts = { "T", tostring(#keys), ":" }
  for _, key in ipairs(keys) do
    parts[#parts + 1] = EncodeValue(key, depth + 1, seen)
    parts[#parts + 1] = EncodeValue(value[key], depth + 1, seen)
  end
  seen[value] = nil
  return table.concat(parts)
end

local function ReadCount(source, position)
  local colon = source:find(":", position, true)
  if not colon or colon - position > 8 then error("Invalid profile data.") end
  local count = tonumber(source:sub(position, colon - 1))
  if not count or count < 0 or count % 1 ~= 0 then error("Invalid profile data.") end
  return count, colon + 1
end

local function DecodeString(value)
  local unescaped = value:gsub("%%[%x][%x]", "")
  if unescaped:find("%%") then error("Invalid escaped text in profile.") end
  local decoded = value:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  return decoded
end

local function DecodeValue(source, position, depth, state)
  if depth > PROFILE_MAX_DEPTH then error("Profile is nested too deeply.") end
  state.nodes = state.nodes + 1
  if state.nodes > PROFILE_MAX_NODES then error("Profile contains too much data.") end

  local tag = source:sub(position, position)
  if tag == "S" then
    local length, start = ReadCount(source, position + 1)
    if length > PROFILE_MAX_SIZE or start + length - 1 > #source then error("Invalid profile text length.") end
    local value = DecodeString(source:sub(start, start + length - 1))
    return value, start + length
  elseif tag == "N" then
    local ending = source:find(";", position + 1, true)
    if not ending or ending - position > 64 then error("Invalid number in profile.") end
    local value = tonumber(source:sub(position + 1, ending - 1))
    if not value or value ~= value or value == math.huge or value == -math.huge then
      error("Invalid number in profile.")
    end
    return value, ending + 1
  elseif tag == "B" then
    local flag = source:sub(position + 1, position + 1)
    if flag == "1" then return true, position + 2 end
    if flag == "0" then return false, position + 2 end
    error("Invalid boolean in profile.")
  elseif tag == "T" then
    local count, nextPosition = ReadCount(source, position + 1)
    if count > PROFILE_MAX_NODES then error("Profile contains too much data.") end
    local value = {}
    for _ = 1, count do
      local key
      key, nextPosition = DecodeValue(source, nextPosition, depth + 1, state)
      local keyType = type(key)
      if keyType ~= "string" and keyType ~= "number" and keyType ~= "boolean" then
        error("Invalid table key in profile.")
      end
      if value[key] ~= nil then error("Profile contains a duplicate table key.") end
      local item
      item, nextPosition = DecodeValue(source, nextPosition, depth + 1, state)
      value[key] = item
    end
    return value, nextPosition
  end
  error("Unrecognized profile data.")
end

local function ParseProfile(code)
  code = strtrim(code or "")
  if code:sub(1, 3) == "\239\187\191" then code = code:sub(4) end
  if #code > PROFILE_MAX_SIZE then error("Profile code is too large.") end
  if code:sub(1, #PROFILE_PREFIX) ~= PROFILE_PREFIX then error("This is not a BG OmniHeal profile code.") end
  local profile, position = DecodeValue(code, #PROFILE_PREFIX + 1, 0, { nodes = 0 })
  if position ~= #code + 1 then error("Unexpected data after the profile.") end
  if type(profile) ~= "table" then error("Profile data is incomplete.") end
  return profile
end

local function MergeKnownSettings(defaults, source)
  local result = {}
  for key, default in pairs(defaults) do
    local value = source and source[key]
    if type(default) == "table" then
      result[key] = MergeKnownSettings(default, type(value) == "table" and value or nil)
    elseif type(value) == type(default) then
      result[key] = value
    else
      result[key] = default
    end
  end
  return result
end

-- Imported legacy epic data is kept for sharing but never used to draw frames.
local function ImportEpicLayout(layout)
  if type(layout) ~= "table" then return nil end
  local result = {}
  for _, team in ipairs({ "ally", "enemy" }) do
    local source = layout[team]
    if type(source) == "table" then
      local fields = {}
      for key, sample in pairs(ns.defaults.brackets["10"][team]) do
        if type(source[key]) == type(sample) then fields[key] = source[key] end
      end
      if next(fields) then result[team] = fields end
    end
  end
  if next(result) then return result end
end

local function ImportPositions(positions)
  local result = {}
  local anchors = ns.Row.AURA_ANCHORS
  for bracket, teams in pairs(positions) do
    if (ns.defaults.brackets[bracket] or bracket == "40") and type(teams) == "table" then
      for _, team in ipairs({ "ally", "enemy" }) do
        local p = teams[team]
        if type(p) == "table" and anchors[p[1]] and anchors[p[2]]
            and type(p[3]) == "number" and type(p[4]) == "number" then
          result[bracket] = result[bracket] or {}
          result[bracket][team] = { p[1], p[2], p[3], p[4] }
        end
      end
    end
  end
  return result
end

function Profiles:List()
  local names = {}
  for name in pairs(ns.global.profiles) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

-- { name = name } for a settings dropdown
function Profiles:Values()
  local values = {}
  for name in pairs(ns.global.profiles) do
    values[name] = name
  end
  return values
end

function Profiles:Current()
  return ns.global.current
end

function Profiles:Export(name)
  local profile = ns.global.profiles[name or ns.global.current]
  if type(profile) ~= "table" then return nil, ns.L("prof_export_error") end
  local ok, encoded = pcall(EncodeValue, profile, 0, {})
  if not ok then return nil, ns.L("prof_export_error") end
  local code = PROFILE_PREFIX .. encoded
  if #code > PROFILE_MAX_SIZE then return nil, ns.L("prof_export_error") end
  return code
end

function Profiles:Import(name, code)
  name = strtrim(name or "")
  if name == "" or name:find("[%c]") then return false, ns.L("prof_import_name_required") end
  local characters = 0
  for i = 1, #name do
    local byte = name:byte(i)
    if byte < 128 or byte >= 192 then characters = characters + 1 end
  end
  if characters > 48 then return false, ns.L("prof_import_name_long") end
  if ns.global.profiles[name] then return false, ns.L("prof_import_name_exists", name) end

  local ok, imported = pcall(ParseProfile, code)
  if not ok then return false, ns.L("prof_import_invalid") end
  if tonumber(imported.schema) and tonumber(imported.schema) > tonumber(ns.defaults.schema or 0) then
    return false, ns.L("prof_import_newer")
  end

  local migratedOK, migrated = pcall(ns.MigrateProfile, ns, imported)
  if not migratedOK or type(migrated) ~= "table" then
    return false, ns.L("prof_import_settings_invalid")
  end
  local positions = ImportPositions(migrated.positions)
  local epic = ImportEpicLayout(migrated.brackets["40"])
  migrated = MergeKnownSettings(ns.defaults, migrated)
  migrated.positions = positions
  migrated.brackets["40"] = epic
  ns:MigrateProfile(migrated)
  ns.global.profiles[name] = migrated
  self:Use(name, "import")
  return true
end

-- Everything that reads settings redraws from the newly active profile
local function ApplyActive()
  if ns.Setup and ns.Setup.active then ns.Setup:Dismiss() end
  ns.Theme.Apply()
  ns.Frames:Refresh()
  ns.Hider:Update()
  ns.Live:SyncAllies()
  ns:UpdateState()
  if ns.RefreshSettings then
    ns.RefreshSettings()
  end
end

-- Swapping moves secure frames, so it waits for combat to end
function Profiles:Use(name, reason)
  local profile = ns.global.profiles[name]
  if not profile or name == ns.global.current then
    return
  end
  ns:AfterCombat("profile", function()
    ns.global.current = name
    ns.db = profile
    ApplyActive()
    ns.Print("Using profile " .. name .. (reason and (" (" .. reason .. ")") or "") .. ".")
  end)
end

-- New profiles start as a copy of the current one
function Profiles:Create(name, from)
  name = strtrim(name or "")
  if name == "" then
    return false, "Enter a profile name."
  end
  if ns.global.profiles[name] then
    return false, "A profile called " .. name .. " already exists."
  end
  local source = ns.global.profiles[from or ns.global.current]
  ns.global.profiles[name] = ns:MigrateProfile(DeepCopy(source))
  return true
end

function Profiles:Rename(newName)
  newName = strtrim(newName or "")
  local old = ns.global.current
  if newName == "" or newName == old then
    return true
  end
  if ns.global.profiles[newName] then
    return false, "A profile called " .. newName .. " already exists."
  end
  ns.global.profiles[newName] = ns.global.profiles[old]
  ns.global.profiles[old] = nil
  ns.global.current = newName
  for role, assigned in pairs(ns.global.roleProfiles) do
    if assigned == old then
      ns.global.roleProfiles[role] = newName
    end
  end
  return true
end

function Profiles:CopyInto(from)
  local source = ns.global.profiles[from]
  if not source or from == ns.global.current then
    return
  end
  ns:AfterCombat("profile", function()
    local copy = ns:MigrateProfile(DeepCopy(source))
    ns.global.profiles[ns.global.current] = copy
    ns.db = copy
    ApplyActive()
  end)
end

function Profiles:Reset()
  ns:AfterCombat("profile", function()
    local fresh = ns:MigrateProfile({})
    ns.global.profiles[ns.global.current] = fresh
    ns.db = fresh
    ApplyActive()
  end)
end

-- The current profile can't be deleted; roles pointing at a deleted one fall back to the current
function Profiles:Delete(name)
  if name == ns.global.current or not ns.global.profiles[name] then
    return
  end
  ns.global.profiles[name] = nil
  for role, assigned in pairs(ns.global.roleProfiles) do
    if assigned == name then
      ns.global.roleProfiles[role] = ns.global.current
    end
  end
end

-- One profile per role, copied from the current one, and switching turned on
function Profiles:CreateRoleSet()
  for _, role in ipairs(self.ROLES) do
    local name = self.ROLE_NAMES[role]
    if not ns.global.profiles[name] then
      self:Create(name)
    end
    ns.global.roleProfiles[role] = name
  end
  ns.global.roleSwitch = true
  self:CheckSpec()
end

local function PlayerRole()
  local SI = C_SpecializationInfo
  local getSpec = (SI and SI.GetSpecialization) or GetSpecialization
  local getRole = (SI and SI.GetSpecializationRole) or GetSpecializationRole
  local spec = getSpec and getSpec()
  return spec and getRole and getRole(spec) or nil
end

-- Called on login and whenever the player changes spec
function Profiles:CheckSpec()
  if not ns.global.roleSwitch then
    return
  end
  local role = PlayerRole()
  local name = role and ns.global.roleProfiles[role]
  if name and ns.global.profiles[name] then
    self:Use(name, self.ROLE_NAMES[role] .. " spec")
  end
end

ns:On("PLAYER_LOGIN", function()
  Profiles:CheckSpec()
end)

ns:On("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
  if unit == nil or unit == "player" then
    Profiles:CheckSpec()
  end
end)
