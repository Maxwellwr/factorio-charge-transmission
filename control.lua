-- require "stdlib/event/event"
local Position = require "stdlib/area/position"
-- local Area = require "stdlib/area/area"
-- local Surface = require "stdlib/surface"
local Entity = require "stdlib/entity/entity"
require "stdlib/event/event"

local nodes, unpaired, indexes, bot_names
-- local bot_blacklist = {}
-- bot_blacklist["logistic-robot"] = false
-- bot_blacklist["construction-robot"] = false

local function globalToLocal(isInit)
  if isInit then
    global.ChargeTransmission = global.ChargeTransmission or {}
    global.ChargeTransmission.charger_nodes = global.ChargeTransmission.charger_nodes or {}
    global.ChargeTransmission.unpaired_chargers = global.ChargeTransmission.unpaired_chargers or {}
    global.ChargeTransmission.node_indexes = global.ChargeTransmission.node_indexes or {}
    global.ChargeTransmission.bot_names = global.ChargeTransmission.bot_names or {}
  end

  nodes = global.ChargeTransmission.charger_nodes
  unpaired = global.ChargeTransmission.unpaired_chargers
  indexes = global.ChargeTransmission.node_indexes
  bot_names = global.ChargeTransmission.bot_names
end

-- PLACEHOLDER for settings and chargeless bots detection
local function isValidBotProto(proto)
  return true or proto
end

local function registerBotNames()
  bot_names = {}

  for _, proto in pairs(game.entity_prototypes) do
    if proto.type == "logistic-robot" then
      if isValidBotProto(proto) then
        bot_names[proto.name] = proto.max_energy
      end
    elseif proto.type == "construction-robot" then
      if isValidBotProto(proto) then
        bot_names[proto.name] = proto.max_energy
      end
    end
  end

  log(serpent.block(global.ChargeTransmission.bot_types))
end

script.on_init(function ()
  globalToLocal(true)
  registerBotNames()
end)

script.on_load(function ()
  globalToLocal()
end)

script.on_configuration_changed(function ()
  registerBotNames()
end)


local function findNeighbourCells(charger)
  local neighbours = charger.logistic_cell.neighbours
  local index = nil
  local distance = math.huge
  for i=1,#neighbours do
    local new_distance = Position.distance_squared(charger.position, neighbours[i].owner.position)
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
  Entity.set_data(node, node_data)
  return node
end

-- Finalizes building a charger, doing the following:
--  Creates the composite unit (powerbox)
--  Tries to find the closest logistic cell (roboport) and register it
--   Else, adds it as an unpaired charger
local function onBuildCharger(entity)
  if(entity.name:find("charge%-transmission%-charger")) then
    entity.destructible = false
    local powerbox = entity.surface.create_entity{
      name = "charge-transmission-charger-powerbox",
      position = entity.position,
      force = entity.force
    }
    Entity.set_data(powerbox, {main = entity})
    local data = {powerbox = powerbox}
    data.index, data.cell = findNeighbourCells(entity)
    Entity.set_data(entity, data)
    if data.cell then
      registerCharger(entity, data.cell)
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
      local node_data = Entity.get_data(node)
      for key, c in pairs(node_data.chargers) do
        if c.unit_number == charger.unit_number then
          table.remove(node_data.chargers, key)
        end
      end
      Entity.set_data(node, node_data)
    end
  end
end

Event.register(defines.events.on_built_entity, function(event) onBuildCharger(event.created_entity) end)
Event.register(defines.events.on_robot_built_entity, function(event) onBuildCharger(event.created_entity) end)

Event.register(defines.events.on_player_mined_entity, function(event) onMinedCharger(event.entity) end)
Event.register(defines.events.on_robot_mined_entity, function(event) onMinedCharger(event.entity) end)

-- TODO: Refactor and test this code, as it's basically snippets from all around!
Event.register(defines.events.on_player_rotated_entity, function(event)
  if(event.entity.name:find("charge%-transmission%-charger%-powerbox")) then
    log("yes")
    local data = Entity.get_data(event.entity)
    local charger = data.main
    local data_charger = Entity.get_data(charger)
    -- unregister from old cell
    log("unregister")
    local nid = indexes[data_charger.cell.owner.unit_number]
    local node = nodes[nid]
    local data_node = Entity.get_data(node)
    for key, c in pairs(data_node.chargers) do
      if c.unit_number == charger.unit_number then
        table.remove(data_node.chargers, key)
      end
    end
    Entity.set_data(node, data_node)
    log("register")
    -- enter the new cell
    local neighbours = charger.logistic_cell.neighbours
    data_charger.index = (data_charger.index+1)%(#neighbours)
    log(serpent.block(neighbours))
    data_charger.cell = neighbours[data_charger.index]
    Entity.set_data(charger, data_charger)
    local index = indexes[data_charger.cell.owner.unit_number]
    if not index then
      log("new")
      -- new node
      node = data_charger.cell.owner
      data_node = {chargers = {charger}}
      data_node.area = Position.expand_to_area(node.position, node.logistic_cell.construction_radius)
      Entity.set_data(node, data_node)
      -- register the node
      table.insert(nodes, node)
      indexes[node.unit_number] = #nodes
      return node
    end
    node = nodes[index]
    data_node = Entity.get_data(node)
    table.insert(data_node.chargers, charger)
    Entity.set_data(node, data_node)
  end
end)

-- TODO: player_on_select spawn player.set_gui_arrow{...}
-- TODO: on defines.events.on_selected_entity_changed ?

Event.register(defines.events.on_selected_entity_changed, function(event)
  local player = game.players[event.player_index]
  local current_entity = player.selected
  if current_entity and current_entity.name:match("charge%-transmission%-charger") then
    local data = Entity.get_data(current_entity)
    if current_entity.name ~= "charge-transmission-charger" then
      data = Entity.get_data(data.main)
    end
    if data.cell then
      player.set_gui_arrow{type="entity", entity=data.cell.owner}
    end
  elseif event.last_entity and event.last_entity.name:match("charge%-transmission%-charger") then
    player.clear_gui_arrow()
  end
end)

-- TODO: Optimize this, make it squeaky clean
-- * change the architecture so roboports are the grouping element, not the charger so that grouped-together chargers "share the burden"
--   (also solves the issue of a charger having only so much input current)
-- * abstract the robot types to a setting which auto-updates to just save the name and max energy
-- ✓ add the 50 bots at a time system, or spread over timeframe
-- ✓ remove the math.maxes, they're slighly heavy and an if could work there
-- * code check
-- * add more .valid checks
script.on_event(defines.events.on_tick, function(event)
  -- charger re-pairing
  for cid=1+event.tick%150,#unpaired,150 do
    local charger = unpaired[cid]
    if charger and charger.valid then
      local data = Entity.get_data(charger)
      data.index, data.cell = findNeighbourCells(charger)
      Entity.set_data(charger, data)
      if data.cell then
        registerCharger(charger, data.cell)
        table.remove(unpaired, cid)
      end
    else
      table.remove(unpaired, cid)
    end
  end

  -- clear invalid nodes before iterating nodes
  if event.tick%30 == 0 then
    for nid=#nodes,1,-1 do
      local node = nodes[nid]
      local data = Entity.get_data(node)
      if not node.valid or #(data.chargers) <= 0 then
        -- node invalid: remove node, orphan chargers
        for cid=1, #(data.chargers) do
          local charger = data.chargers[cid]
          local charger_data = Entity.get_data(charger)
          charger_data.powerbox.power_usage = 0
          charger_data.index = nil
          charger_data.cell = nil
          Entity.set_data(charger, charger_data)
          table.insert(unpaired, charger)
        end
        table.remove(nodes, nid)
      end
    end
  end

  -- area scanning
  for nid=1+event.tick%30,#nodes,30 do
    local node = nodes[nid]
    local node_data = Entity.get_data(node)
    if node.valid and #(node_data.chargers) > 0 then
      local target_bots = {}
      local energy = 0
      local cost = 0

      -- check total energy cost
      local constrobots, logibots =
        node.surface.find_entities_filtered {
          area = node_data.area,
          force = node.force,
          type = "construction-robot"
        },
        node.surface.find_entities_filtered {
          area = node_data.area,
          force = node.force,
          type = "logistic-robot"
        }
      for bid=1,#constrobots + #logibots do
        local bot
        if bid <= #constrobots then bot = constrobots[bid]
        else bot = logibots[bid - #constrobots] end
        local max_energy = bot_names[bot.name]

        if bot and max_energy then
          cost = cost + (max_energy - bot.energy)
          table.insert(target_bots, {bot = bot, max = max_energy})
        end
      end

      -- calculate total available energy
      for cid=#(node_data.chargers),1,-1 do
        if node_data.chargers[cid].valid then
          local powerbox = Entity.get_data(node_data.chargers[cid]).powerbox
          energy = energy + powerbox.energy
        else
          table.remove(node_data.chargers, cid)
        end
      end

      local fraction = 1
      -- overspending so the machine charges less per robot
      if cost > energy then fraction = energy / cost end

      -- set power cost on the powerboxes
      for cid=1, #(node_data.chargers) do
        local powerbox = Entity.get_data(node_data.chargers[cid]).powerbox
        powerbox.power_usage = (cost * fraction) / (30 * #(node_data.chargers))
      end

      -- charge ALL bots
      for tid=1, #target_bots do
        local target = target_bots[tid]
        target.bot.energy = target.bot.energy + (target.max - target.bot.energy) * fraction
      end
    end
  end
end)