MOD.migrations = {"0.3.2"}

local Entity = require "stdlib/entity/entity"

local function oh_three_two()
  -- remove is_charged
  global.is_charged = nil

  -- make all chargers follow the new spec
  local function reset_charger(charger)
    local transmitter = Entity.get_data(charger).transmitter
    if transmitter then
    transmitter.electric_input_flow_limit = transmitter.prototype.electric_energy_source_prototype.input_flow_limit
    end
  end

  for _, charger in pairs(global.unpaired) do
    reset_charger(charger)
  end

  for _, node in pairs(global.nodes) do
    for _, charger in pairs(node.chargers) do
    reset_charger(charger)
    end
  end

  return true
end

local scripts = {}
scripts["0.3.2"] = oh_three_two

return scripts