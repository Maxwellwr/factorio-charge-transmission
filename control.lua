-- require "stdlib/event/event"
local Position = require "stdlib/area/position"
-- local Area = require "stdlib/area/area"
-- local Surface = require "stdlib/surface"
local Entity = require "stdlib/entity/entity"
require "stdlib/event/event"

local nodes, unpaired, indexes, bot_names, charging
-- local bot_blacklist = {}
-- bot_blacklist["logistic-robot"] = false
-- bot_blacklist["construction-robot"] = false

local function globalToLocal(isInit)
  if isInit then
    global.ChargeTransmission = global.ChargeTransmission or {}
    global.ChargeTransmission.charger_nodes = global.ChargeTransmission.charger_nodes or {}
    global.ChargeTransmission.unpaired_chargers = global.ChargeTransmission.unpaired_chargers or {}
    global.ChargeTransmission.node_indexes = global.ChargeTransmission.node_indexes or {}
    global.ChargeTransmission.bot_names = global.ChargeTransmission.bot_names or {construction = {}, logistic={}}
    global.ChargeTransmission.bots_charging = global.ChargeTransmission.bots_charging or {}
  end

  nodes = global.ChargeTransmission.charger_nodes
  unpaired = global.ChargeTransmission.unpaired_chargers
  indexes = global.ChargeTransmission.node_indexes
  bot_names = global.ChargeTransmission.bot_names
  charging = global.ChargeTransmission.bots_charging
end

-- PLACEHOLDER for settings and chargeless bots detection
local function isValidBotProto(proto)
  return true or proto
end

local function registerBotNames()
  charging = {}
  bot_names.logistic = {}
  bot_names.construction = {}

  for _, proto in pairs(game.entity_prototypes) do
    if proto.type == "logistic-robot" then
      if isValidBotProto(proto) then
        bot_names.logistic[proto.name] = proto.max_energy
      end
    elseif proto.type == "construction-robot" then
      if isValidBotProto(proto) then
        bot_names.construction[proto.name] = proto.max_energy
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
    log("["..node.unit_number.."]:new")
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
    local powerbox = entity.surface.create_entity{
      name = "charge-transmission-charger-powerbox",
      position = entity.position
    }
    local data = {powerbox = powerbox}
    data.index, data.cell = findNeighbourCells(entity)
    Entity.set_data(entity, data)
    if data.cell then
      registerCharger(entity, data.cell)
    else
      table.insert(unpaired, entity)
      log("unpair+")
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
  if(event.entity.name:find("charge%-transmission%-charger")) then
    log("yes")
  end
end)

-- TODO: player_on_select spawn player.set_gui_arrow{...}
-- TODO: on defines.events.on_selected_entity_changed ?

Event.register(defines.events.on_selected_entity_changed, function(event)
  local player = game.players[event.player_index]
  local current_entity = player.selected
  if current_entity and current_entity.name:match("charge%-transmission%-charger") then
    local data = Entity.get_data(current_entity)
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
          data.cell = nil
          Entity.set_data(charger, charger_data)
          table.insert(unpaired, charger)
          log("["..node.unit_number.."]:delete:"..#(data.chargers))
        end
        table.remove(nodes, n)
      end
    end
  end

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
        log("register:"..charger.unit_number)
      end
    else
      table.remove(unpaired, cid)
    end
  end

  -- area scanning
  for nid=1+event.tick%30,#nodes,30 do
    local node = nodes[nid]
    local data = Entity.get_data(node)
    if node.valid and #(data.chargers) > 0 then
      local target_bots = {}
      local energy = 0
      local cost = 0
      local bot_count = 0

      -- check total energy cost
      local constrobots, logibots =
        node.surface.find_entities_filtered {
          area = data.area,
          force = node.force,
          type = "construction-robot"
        },
        node.surface.find_entities_filtered {
          area = data.area,
          force = node.force,
          type = "logistic-robot"
        }
      for bid=1,#constrobots + #logibots do
        local bot, max_energy
        if bid <= #constrobots then
          bot = constrobots[bid]
          max_energy = bot_names.construction[bot.name]
        else
          bot = logibots[bid - #constrobots]
          max_energy = bot_names.logistic[bot.name]
        end

        if bot and max_energy then
          cost = cost + (max_energy - bot.energy) * 2
          bot_count = bot_count + 1

          local tid = (math.floor(bot_count/50) + (event.tick + 1))%30
          target_bots[tid] = target_bots[tid] or {}
          table.insert(target_bots[tid], bot)
        end
      end

      -- calculate total available energy
      for cid=#(data.chargers),1,-1 do
        if data.chargers[cid].valid then
          local powerbox = Entity.get_data(data.chargers[cid]).powerbox
          energy = energy + powerbox.energy
        else
          table.remove(data.chargers, cid)
        end
      end

      -- log("cost:"..bot_count..":"..cost)
      -- log("energy:"..#(data.chargers)..":"..energy)

      local fraction = 1
      -- overspending so the machine charges less per robot
      if cost > energy then fraction = energy / cost end

      -- set power cost on the powerboxes
      for cid=1, #(data.chargers) do
        local powerbox = Entity.get_data(data.chargers[cid]).powerbox
        powerbox.power_usage = (cost * fraction) / (30 * #(data.chargers))
      end

      -- insert the to-be-charged bots on charging
      for bid=1,30 do
        if target_bots[bid] then
          charging[bid] = charging[bid] or {}
          table.insert(charging[bid], {      
            bots = target_bots[bid],
            area = data.area,
            fraction = fraction
          })
          -- log("["..node.unit_number.."]:+"..#(target_bots[bid]).." bots:"..event.tick..":f"..fraction)
        end
      end
    end
  end

  -- bot recharging
  -- if charging[event.tick%30] then
  --   local charging_set = charging[event.tick%30]
  --   for i=1,#charging_set do
  --     local list = charging_set[i]
  --     for j=1, #(list.bots) do
  --       local bot = list.bots[j]
  --       if bot and bot.valid then
  --         bot.energy = bot.energy + (bot.prototype.max_energy - bot.energy) * list.fraction
  --       end
  --     end
  --   end

  --   charging[event.tick%30] = nil
  -- end
end)