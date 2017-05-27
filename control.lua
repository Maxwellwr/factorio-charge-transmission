-- require "stdlib/event/event"
local Position = require "stdlib/area/position"
local Area = require "stdlib/area/area"
-- local Surface = require "stdlib/surface"
local Entity = require "stdlib/entity/entity"
require "stdlib/event/event"

local nodes, unpaired, indexes, bot_types, charging
-- local bot_blacklist = {}
-- bot_blacklist["logistic-robot"] = false
-- bot_blacklist["construction-robot"] = false



script.on_init(function ()
  global.ChargeTransmission = global.ChargeTransmission or {}
  global.ChargeTransmission.charger_nodes = global.ChargeTransmission.charger_nodes or {}
  global.ChargeTransmission.unpaired_chargers = global.ChargeTransmission.unpaired_chargers or {}
  global.ChargeTransmission.node_indexes = global.ChargeTransmission.node_indexes or {}
  global.ChargeTransmission.bot_types = global.ChargeTransmission.bot_types or {construction = {}, logistic={}}
  global.ChargeTransmission.bots_charging = global.ChargeTransmission.bots_charging or {}

  nodes = global.ChargeTransmission.charger_nodes
  unpaired = global.ChargeTransmission.unpaired_chargers
  indexes = global.ChargeTransmission.node_indexes
  bot_types = global.ChargeTransmission.bot_types
  charging = global.ChargeTransmission.bots_charging
end)

script.on_load(function ()
  nodes = global.ChargeTransmission.charger_nodes
  unpaired = global.ChargeTransmission.unpaired_chargers
  indexes = global.ChargeTransmission.node_indexes
  bot_types = global.ChargeTransmission.bot_types
  charging = global.ChargeTransmission.bots_charging
end)

-- PLACEHOLDER for settings and chargeless bots detection
local function isValidBotType(bot_type)
  return true
end

script.on_configuration_changed(function ()
  bot_types.logistic = {}
  bot_types.construction = {}

  for _, proto in pairs(game.entity_prototypes) do
    if proto.type == "logistic-robot" then
      if isValidBotType(proto) then
        bot_types.logistic[proto.name] = proto.max_energy
      end
    elseif proto.type == "construction-robot" then
      if isValidBotType(proto) then
        bot_types.construction[proto.name] = proto.max_energy
      end
    end
  end

  log(serpent.block(global.ChargeTransmission.bot_types))
end)



local function findNeighbourCells(charger)
  local neighbours = charger.logistic_cell.neighbours
  local index = nil
  local distance = math.huge
  for i=1,#neighbours do
    local new_distance = Position.distance_squared(charger.position, neighbours[i].owner.position)
    log(i..":distance:"..new_distance)
    if new_distance < distance then distance = new_distance; index = i end
  end
  if index then
    return index, neighbours[index]
  end
end

-- Registers a charger, placing it on its rightful node (or creating a new one)
local function registerCharger(charger, cell)
  local index = indexes[cell.owner.unit_number]
  if not index then
    -- new node
    local node = cell.owner
    local node_data = {chargers = {charger}}
    node_data.area = Position.expand_to_area(node.position, node.logistic_cell.construction_radius)
    Entity.set_data(node, node_data)
    -- register the node
    table.insert(nodes, node)
    indexes[node.unit_number] = #nodes
    return node
  end
  local node = nodes[index]
  local node_data = Entity.get_data(node)
  table.insert(node_data.chargers, charger)
  Entity.set_data(node_data)
  return node
end

-- Finalizes building a charger, doing the following:
--  Creates the composite unit (powerbox)
--  Tries to find the closest logistic cell (roboport) and register it
--   Else, adds it as an unpaired charger
local function onBuildCharger(entity)
  if(entity.name:find("charge%-transmission%-charger")) then
    local powerbox = entity.surface.create_entity{
      name = "charge-transmission-charger-powerbox",
      position = entity.position
    }
    local cell
    local data = {powerbox = powerbox}
    data.index, cell = findNeighbourCells(entity)
    Entity.set_data(entity, data)
    if cell then
      registerCharger(entity, cell)
    else
      table.insert(unpaired, entity)
    end
  end
end


local function onMinedCharger(charger)
  if(charger.name:find("charge%-transmission%-charger")) then
    -- remove composite partners
    local data = Entity.get_data(charger)
    data.powerbox.destroy()
    Entity.set_data(charger, nil)

    -- remove oneself from nodes
    for _, node in pairs(nodes) do
      local chargers = Entity.get_data(node)
      for key, c in pairs(chargers) do
        if c.unit_number == charger.unit_number then
          table.remove(chargers, key)
          -- return
        end
      end
    end
  end
end

Event.register(defines.events.on_built_entity, function(event) onBuildCharger(event.created_entity) end)
Event.register(defines.events.on_robot_built_entity, function(event) onBuildCharger(event.created_entity) end)

Event.register(defines.events.on_player_mined_entity, function(event) onMinedCharger(event.entity) end)
Event.register(defines.events.on_robot_mined_entity, function(event) onMinedCharger(event.entity) end)

-- TODO: Swap roboports when you "rotate" the bot charger
Event.register(defines.events.on_player_rotated_entity, function(event)
  if(event.entity.name:find("charge%-transmission%-bot%-charger")) then
    log("yes")
  end
end)

-- TODO: player_on_select spawn player.set_gui_arrow{...}
-- TODO: on defines.events.on_selected_entity_changed ?

-- TODO: Optimize this, make it squeaky clean
-- * change the architecture so roboports are the grouping element, not the charger so that grouped-together chargers "share the burden"
--   (also solves the issue of a charger having only so much input current)
-- * abstract the robot types to a setting which auto-updates to just save the name and max energy
-- * add the 50 bots at a time system, or spread over timeframe
-- ✓ remove the math.maxes, they're slighly heavy and an if could work there
-- * code check
-- * add more .valid checks
script.on_event(defines.events.on_tick, function(event)
  -- area scanning (twice per second)
  -- iterating backwards because, if a node is removed, it won't skip nodes, i think?
  -- * write tests for this pls
  for node_id=#nodes-event.tick%30,1,-30 do
    local node = nodes[node_id]
    local data = Entity.get_data(node)
    if node.valid and #(data.chargers) > 0 then
      local bots = {}
      local energy = 0
      local cost = 0
      local bot_count = 0
      -- check total energy cost
      local constrobots = node.surface.find_entities_filtered {
        area = data.area,
        force = node.force,
        type = "construction-robot"
      }
      for bot=1,#constrobots do
        local bot_type = constrobots[bot].name
        if bot_types[bot_type] then
          cost = cost + (bot_types[bot_type] - constrobots[bot].energy) * 2
          -- makes the bot recharging loop start the tick after this one
          -- limited to 50n bots per tick, over 30 ticks
          local i = (bot_count/50 + node_id)%30+1
          bots[i] = bots[i] or {}
          table.insert(bots[i], constrobots[bot])
          bot_count = bot_count + 1
        end
      end

      local logibots = node.surface.find_entities_filtered {
        area = data.area,
        force = node.force,
        type = "logistic-robot"
      }
      for bot=1,#logibots do
        local bot_type = logibots[bot].name
        if bot_types[bot_type] then
          cost = cost + (bot_types[bot_type] - logibots[bot].energy) * 2
          local i = (bot_count/50 + node_id)%30+1
          bots[i] = bots[i] or {}
          table.insert(bots[i], logibots[bot])
          bot_count = bot_count + 1
        end
      end

      for charger=1, #(data.chargers) do
        local powerbox = Entity.get_data(data.chargers[charger]).powerbox
        energy = energy + powerbox.energy
      end

      log("cost:"..bot_count..":"..cost)
      log("energy:"..#(data.chargers)..":"..energy)

      local fraction = 1
      if cost > energy then
        -- overspending so the machine charges less per robot
        fraction = energy / cost
      end

      for charger=1, #(data.chargers) do
        local powerbox = Entity.get_data(data.chargers[charger]).powerbox
        powerbox.power_usage = (cost * fraction) / (30 * #(data.chargers))
      end

      for i=1,30 do
        charging[i] = charging[i] or {}
        table.insert(charging[i], {
          bots = bots[i],
          area = bots.area,
          fraction = bots.fraction
        })
      end
    else
      -- node invalid: remove node, orphan chargers
      for e=1, #(data.chargers) do
        local charger = data.chargers[e]
        local charger_data = Entity.get_data(charger)
        charger_data.powerbox.power_usage = 0
        charger_data.index = nil
        -- data.cells = nil
        Entity.set_data(charger, charger_data)
        table.insert(unpaired, charger)
      end
      table.remove(nodes, node_id)
    end
  end

  -- bot recharging
  if charging[event.tick%30] then
    local charging_set = charging[event.tick%30]
    for i=1,#charging_set do
      local list = charging_set[i]
      for j=1, #(list.bots) do
        local bot = list.bots[j]
        -- check if the robot is still inside the area
        -- (no cheating energy am i right)
        if Area.inside(list.area, bot.position) then
          bot.energy = bot.energy + (bot.prototype.max_energy - bot.energy) * list.fraction
        end
      end
    end

    charging[event.tick%30] = nil
  end

  -- TODO: charger re-pairing
end)