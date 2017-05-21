-- require "stdlib/event/event"
local Position = require "stdlib/area/position"
local Area = require "stdlib/area/area"
local Surface = require "stdlib/surface"
local Entity = require "stdlib/entity/entity"
require "stdlib/event/event"

local chargers
local bot_types = {"logistic-robot", "construction-robot"}

script.on_init(function ()
  global.ChargeTransmission = global.ChargeTransmission or {}
  global.ChargeTransmission.bot_chargers = global.ChargeTransmission.bot_chargers or {}

  chargers = global.ChargeTransmission.bot_chargers
end)

script.on_load(function ()
  chargers = global.ChargeTransmission.bot_chargers
end)


local function findRoboport(savedata)
  local mask = Entity.to_collision_area(savedata.charger)
  for k,v in pairs({{0,-1},{1,0},{0,1},{-1,0}}) do
    local roboports = Surface.find_all_entities{type="roboport", area = Area.offset(mask, v)}
    if #roboports > 0 then
      savedata.roboport = roboports[1]
      savedata.area = Position.expand_to_area(savedata.roboport.position,
        savedata.roboport.logistic_cell.construction_radius)
      savedata.base.graphics_variation = k
      return
    end
  end
  savedata.base.graphics_variation = 5
end

local function registerBotCharger(charger)
  if(charger.name:find("charge%-transmission%-bot%-charger")) then
    local base = charger.surface.create_entity{
      name = "charge-transmission-bot-charger-base",
      position = charger.position
    }
    local savedata = {charger = charger, base = base}
    table.insert(chargers, savedata)
    findRoboport(savedata)
    log("+"..#chargers)
  end
end

local function removeBotCharger(charger)
  if(charger.name:find("charge%-transmission%-bot%-charger")) then
    for key, savedata in pairs(chargers) do
      if savedata.charger.unit_number == charger.unit_number then
        savedata.base.destroy()
        table.remove(chargers, key)
        log("-"..#chargers)
        return
      end
    end
  end
end

Event.register(defines.events.on_built_entity, function(event) registerBotCharger(event.created_entity) end)
Event.register(defines.events.on_robot_built_entity, function(event) registerBotCharger(event.created_entity) end)

Event.register(defines.events.on_player_mined_entity, function(event) removeBotCharger(event.entity) end)
Event.register(defines.events.on_robot_mined_entity, function(event) removeBotCharger(event.entity) end)

script.on_event(defines.events.on_tick, function(event)
  for id=1+event.tick%30,#chargers,30 do
    local data = chargers[id]
    if data.roboport and data.roboport.valid and data.charger.valid then
      -- data.charger.power_usage = 0
      local bots = {}
      local cost = 0
      -- check total energy cost
      for type=1,#bot_types do
        local bot_type = game.entity_prototypes[bot_types[type]]
        bots[type] = data.charger.surface.find_entities_filtered {
          area = data.area,
          force = data.charger.force,
          name = bot_type.name
        }
        cost = cost + (bot_type.max_energy / 4) * #(bots[type])
      end
      if cost * 30 > data.charger.energy then
        -- overspending so the machine charges less per robot
        local fraction = data.charger.energy / (cost * 30)
        log((fraction*100).."% energy usage on "..id)
        for type=1,#bot_types do
          local refill = game.entity_prototypes[bot_types[type]].max_energy * fraction
          for j=1,#(bots[type]) do
            bots[type][j].energy = math.max(refill, bots[type][j].energy)
          end
        end
        data.charger.power_usage = cost * fraction
      else
        -- recharge all bots fully
        for type=1,#bot_types do
          local refill = game.entity_prototypes[bot_types[type]].max_energy
          for j=1,#(bots[type]) do
            bots[type][j].energy = refill
          end
        end
        data.charger.power_usage = cost
      end
    elseif data.charger.valid and event.tick % 120 then
      data.roboport = nil
      data.area = nil
      findRoboport(data)
    end
  end
end)