-- require "stdlib/event/event"
local Position = require "stdlib/area/position"
-- local Area = require "stdlib/area/area"
-- local Surface = require "stdlib/surface"
local Entity = require "stdlib/entity/entity"
require "stdlib/event/event"

local nodes, unpaired, is_node, is_done, bot_names
-- local bot_blacklist = {}
-- bot_blacklist["logistic-robot"] = false
-- bot_blacklist["construction-robot"] = false

local function globalToLocal(isInit)
  if isInit then
    global.ChargeTransmission = global.ChargeTransmission or {}

    global.ChargeTransmission.charger_nodes = global.ChargeTransmission.charger_nodes or {}
    global.ChargeTransmission.is_charger_node = global.ChargeTransmission.is_charger_node or {}
    global.ChargeTransmission.is_refilled_bot = global.ChargeTransmission.is_refilled_bot or {}
    global.ChargeTransmission.unpaired_chargers = global.ChargeTransmission.unpaired_chargers or {}
    global.ChargeTransmission.bot_names = global.ChargeTransmission.bot_names or {}
  end

  nodes = global.ChargeTransmission.charger_nodes
  is_node = global.ChargeTransmission.is_charger_node
  is_done = global.ChargeTransmission.is_refilled_bot
  unpaired = global.ChargeTransmission.unpaired_chargers
  bot_names = global.ChargeTransmission.bot_names
end

-- Automatically blacklists chargeless robots (Creative Mode, Nuclear/Fusion Bots, ...)
local function isValidBotProto(proto)
  -- Creative Mode; Nuclear Robots; Jamozed's Fusion Robots
  if proto.energy_per_tick == 0 and proto.energy_per_move == 0 then return false end
  -- (use case without known mods that haven't already matched previously)
  if proto.speed_multiplier_when_out_of_energy >= 1 then return false end

  return true
end

local function registerBotNames()
  global.ChargeTransmission.bot_names = {}
  bot_names = global.ChargeTransmission.bot_names

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

  log(serpent.block(global.ChargeTransmission.bot_names))
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


-- TODO: Prioritize node-bearing cells
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

local function findNodeFromCell(cell)
  for _, node in pairs(nodes) do
    if node.cell.valid and node.cell.owner.unit_number == cell.owner.unit_number then
      return node
    end
  end
end

-- Registers a charger, placing it on its rightful node (or creating a new one)
-- Warning: does not update the charger entity's data to point at the cell
local function registerCharger(charger, cell)
  local node = findNodeFromCell(cell)
  if not node then
    -- new node
    node = {cell = cell, chargers = {}, id = cell.owner.unit_number}
    node.area = Position.expand_to_area(node.cell.owner.position, node.cell.construction_radius)
    -- register the node
    table.insert(nodes, node)
    is_node[node.id] = true
    -- log("new node "..node.id.." for cell "..cell.owner.unit_number)
  end

  table.insert(node.chargers, charger)
  -- log("added charger "..charger.unit_number.." to node "..node.id)
  return node
end

-- Finalizes building a charger, doing the following:
--  Creates the composite unit (radar)
--  Tries to find the closest logistic cell (roboport) and register it
--   Else, adds it as an unpaired charger
local function onBuiltCharger(entity)
  if(entity.name:find("charge%-transmission%-charger")) then
    local transmitter = entity.surface.create_entity{
      name = "charge-transmission-charger-transmitter",
      position = entity.position,
      force = entity.force
    }
    transmitter.destructible = false
    Entity.set_data(transmitter, {main = entity})

    local data = {transmitter = transmitter}
    data.index, data.cell = findNeighbourCells(entity)
    Entity.set_data(entity, data)

    if data.cell then
      -- log("created reserved charger "..entity.unit_number.." for node "..data.cell.owner.unit_number)
      registerCharger(entity, data.cell)
    else
      -- log("created unpaired charger "..entity.unit_number)
      table.insert(unpaired, entity)
    end
  end
end

-- Removes a charger from, either the node (cell) it has saved, or from all if the node is invalid
local function removeChargerFromNodes(charger, charger_data)
  charger_data = charger_data or Entity.get_data(charger)
  local owner_cell = charger_data and charger_data.cell

  if owner_cell and owner_cell.valid then
    -- known node, remove only from that one
    for _, n in pairs(nodes) do
      if n.cell.valid and n.cell.owner.unit_number == owner_cell.owner.unit_number then
        for cid, c in pairs(n.chargers) do
          if c.unit_number == charger.unit_number then
            table.remove(n.chargers, cid)
            -- log("removed charger "..charger.unit_number.." from node "..n.cell.owner.unit_number)
          end
        end

        charger_data.node = nil
        Entity.set_data(charger, charger_data)
        return
      end
    end
  else
    -- unknown node, remove from all valid nodes
    if charger_data then charger_data.node = nil; Entity.set_data(charger, charger_data) end

    for _, n in pairs(nodes) do
      for cid, c in pairs (n.chargers) do
        if c.unit_number == charger.unit_number then
          table.remove(n.chargers, cid)
          -- log("removed charger "..charger.unit_number.." from node "..n.cell.owner.unit_number)
        end
      end
    end
  end
end

local function onMinedCharger(charger)
  if(charger.name:find("charge%-transmission%-charger")) then
    -- remove composite partners
    local data = Entity.get_data(charger)
    data.transmitter.destroy()
    Entity.set_data(charger, nil)

    -- remove oneself from nodes
    removeChargerFromNodes(charger)
  end
end

local function onRotatedCharger(charger, player)
  -- log("rotated charger "..charger.unit_number)
  local charger_data = Entity.get_data(charger)

  -- swap charger to the next "node"
  removeChargerFromNodes(charger)

  local neighbours = charger.logistic_cell.neighbours
  local new_index = (charger_data.index)%(#neighbours) + 1
  -- log("#: "..charger_data.index.."->"..new_index)
  -- log("id: "..neighbours[charger_data.index].owner.unit_number.."->"..neighbours[new_index].owner.unit_number)
  charger_data.index = new_index
  charger_data.cell = neighbours[new_index]
  Entity.set_data(charger, charger_data)
  registerCharger(charger, neighbours[new_index])

  -- update arrow
  charger_data = Entity.get_data(charger)
  player.set_gui_arrow{type="entity", entity=charger_data.cell.owner}
end

Event.register(defines.events.on_built_entity, function(event) onBuiltCharger(event.created_entity) end)
Event.register(defines.events.on_robot_built_entity, function(event) onBuiltCharger(event.created_entity) end)

Event.register(defines.events.on_player_mined_entity, function(event) onMinedCharger(event.entity) end)
Event.register(defines.events.on_robot_mined_entity, function(event) onMinedCharger(event.entity) end)

Event.register(defines.events.on_player_rotated_entity, function(event)
  if(event.entity.name:find("charge%-transmission%-charger%-transmitter")) then
    local data = Entity.get_data(event.entity)
    local charger = data.main
    local player = game.players[event.player_index]

    onRotatedCharger(charger, player)
  end
end)

Event.register(defines.events.on_selected_entity_changed, function(event)
  local player = game.players[event.player_index]
  local current_entity = player.selected
  if current_entity and current_entity.name:match("charge%-transmission%-charger%-transmitter") then
    local data = Entity.get_data(current_entity)
    data = Entity.get_data(data.main)

    if data.cell and data.cell.valid then
      player.set_gui_arrow{type="entity", entity=data.cell.owner}
    end
  elseif event.last_entity and event.last_entity.name:match("charge%-transmission%-charger") then
    player.clear_gui_arrow()
  end
end)


-- TODO: Optimize this, make it squeaky clean
-- ✓  change the architecture so roboports are the grouping element, not the charger so that grouped-together chargers "share the burden"
--    (also solves the issue of a charger having only so much input current)
-- ✓  abstract the robot types to a setting which auto-updates to just save the name and max energy
-- *  code check
-- ✓? add more .valid checks
script.on_event(defines.events.on_tick, function(event)
  -- charger re-pairing every 5 seconds
  for cid=1+event.tick%300,#unpaired,300 do
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

  -- before iterating nodes...
  if event.tick%60 == 0 then
    -- clear registered bots
    global.ChargeTransmission.is_refilled_bot = {}
    is_done = global.ChargeTransmission.is_refilled_bot

    -- clear invalid nodes
    for nid=#nodes,1,-1 do
      local node = nodes[nid]
      if not node.cell.valid or #(node.chargers) <= 0 then
        -- node is invalid: remove node, orphan chargers
        is_node[node.id] = nil

        for cid=1, #(node.chargers) do
          local charger = node.chargers[cid]
          if charger and charger.valid then
            local charger_data = Entity.get_data(charger)
            charger_data.transmitter.power_usage = 0
            charger_data.index = nil
            charger_data.cell = nil
            Entity.set_data(charger, charger_data)
            -- log("unpaired charger "..charger.unit_number.." from node "..node.id)
            table.insert(unpaired, charger)
          end
        end
        table.remove(nodes, nid)
        -- log("removed node "..node.id)
      end
    end
  end

  -- area scanning
  for nid=1+event.tick%60,#nodes,60 do
    local node = nodes[nid]

    -- calculate total available energy
    local energy = 0
    for cid=#(node.chargers),1,-1 do
      -- reverse iteration to allow for removals
      if node.chargers[cid].valid then
        local transmitter = Entity.get_data(node.chargers[cid]).transmitter
        energy = energy + transmitter.energy
      else
        table.remove(node.chargers, cid)
      end
    end

    -- check total energy cost
    local cost = 0
    -- local bots = 0
    local constrobots, logibots =
      node.cell.owner.surface.find_entities_filtered {
        area = node.area,
        force = node.cell.owner.force,
        type = "construction-robot"
      },
      node.cell.owner.surface.find_entities_filtered {
        area = node.area,
        force = node.cell.owner.force,
        type = "logistic-robot"
      }
    local debt = 0

    if #constrobots + #logibots > 0 then
      for bid=1,#constrobots + #logibots do
        local bot
        if bid <= #constrobots then bot = constrobots[bid]
        else bot = logibots[bid - #constrobots] end
        local max_energy = bot_names[bot.name]

        if bot and max_energy and not(is_done[bot.unit_number]) then
          cost = cost + (max_energy - bot.energy) * 1.25
          if cost < energy then
            bot.energy = max_energy
            is_done[bot.unit_number] = true
            -- bots = bots + 1
          else break end
        end
      end

      debt = cost
      -- overspending so the machine only charged so many robots
      if cost >= energy then debt = energy end
      -- split the energetic debt between the chargers and time
      debt = debt / (60 * #(node.chargers))
      -- log("#"..node.id..":debt "..debt..":cost "..cost..":energy "..energy..":bots "..bots)
    end

    -- set power cost on the transmitteres
    for cid=1, #(node.chargers) do
      local transmitter = Entity.get_data(node.chargers[cid]).transmitter
      transmitter.power_usage = debt
    end
  end
end)