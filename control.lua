-- require "stdlib/event/event"
local Position = require "stdlib/area/position"
local Area = require "stdlib/area/area"

local beacons
local bots = {"logistic-robot", "construction-robot"}

script.on_init(function ()
  global.ChargeTransmission = global.ChargeTransmission or {}
  global.ChargeTransmission.beacons = global.ChargeTransmission.beacons or {}

  beacons = global.ChargeTransmission.beacons
end)

script.on_load(function ()
  beacons = global.ChargeTransmission.beacons
end)

local function registerBeacon(beacon)
  if(beacon.name:find("roboport")) then
    table.insert(beacons, beacon)
    log("+"..#beacons)
  end
end

local function removeBeacon(beacon)
  if(beacon.name:find("roboport")) then
    local index = nil
    for k, v in pairs(beacons) do
      if v.unit_number == beacon.unit_number then
        index = k
        break
      end
    end
    if index then table.remove(beacons, index) end
    log("-"..#beacons)
  end
end

script.on_event(defines.events.on_built_entity, function(event)
  registerBeacon(event.created_entity)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
  registerBeacon(event.created_entity)
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
  removeBeacon(event.entity)
end)

script.on_event(defines.events.on_robot_mined_entity, function(event)
  removeBeacon(event.entity)
end)

script.on_event(defines.events.on_tick, function(event)
  for i=1+event.tick%30,#beacons,30 do
    local beacon = beacons[i]
    if beacon.active then
      local area = Position.expand_to_area(beacon.position, 55)
      for j=1,#bots do
        if beacon.energy <= 0 then break end
        local bot_type = bots[j]
        local found_bots = beacon.surface.find_entities_filtered{
          area = area,
          force = beacon.force,
          name = bot_type
        }
        for k=1,#found_bots do
          if beacon.energy <= 0 then break end
          local bot = found_bots[k]
          local energy = bot.prototype.max_energy - bot.energy
          bot.energy = bot.prototype.max_energy
          beacon.energy = beacon.energy - energy
        end
      end
    end
  end
end)