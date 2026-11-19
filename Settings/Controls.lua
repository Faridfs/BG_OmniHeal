local _, ns = ...
local L = ns.L
local Controls = {}
ns.SettingsControls = Controls

function Controls.RefreshFrames()
  ns.Frames:Refresh()
end

function Controls.Get(key)
  return function() return ns.db[key] end
end

function Controls.Set(key, onChange)
  onChange = onChange or Controls.RefreshFrames
  return function(_, value)
    ns.db[key] = value
    onChange()
  end
end

function Controls.With(option, overrides)
  if overrides then
    for key, value in pairs(overrides) do option[key] = value end
  end
  return option
end

function Controls.Toggle(order, nameKey, key, descKey, onChange, overrides)
  return Controls.With({
    type = "toggle",
    order = order,
    width = "full",
    name = function() return L(nameKey) end,
    desc = descKey and function() return L(descKey) end or nil,
    get = Controls.Get(key),
    set = Controls.Set(key, onChange),
  }, overrides)
end

function Controls.Range(order, nameKey, get, set, min, max, step, overrides)
  return Controls.With({
    type = "range",
    order = order,
    name = function() return L(nameKey) end,
    min = min, max = max, step = step,
    get = get, set = set,
  }, overrides)
end

-- General and the individual frame pages edit the same visibility flags.
function Controls.FrameVisibility(team, order, overrides)
  local isAlly = team == "ally"
  local label = isAlly and "opt_show_ally" or "opt_show_enemy"
  local key = isAlly and "showAllies" or "showEnemies"
  return Controls.Toggle(order, label, key, nil, nil, overrides)
end
