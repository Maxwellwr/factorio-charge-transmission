-- require "stdlib/event/event"
local Position = require "stdlib/area/position"
-- local Area = require "stdlib/area/area"
-- local Surface = require "stdlib/surface"
local Entity = require "stdlib/entity/entity"
require "stdlib/event/event"

MOD = {config = {quickstart = require "scripts/quickstart-config"}}
require "stdlib/debug/quickstart"

local nodes, counters, pchargers, new_nodes, is_charged, unpaired, bot_max
local function init_global(is_load)
  if not is_load then
    global.nodes = global.nodes or {}
    global.pchargers = global.pchargers or {}
    global.counters = global.counters or {
      nid = nil, pcid = nil, uid = nil,
      nodes = 0, pchargers = 0
    }
    global.new_nodes = global.new_nodes or {}
    global.is_charged = global.is_charged or {}
    global.unpaired = global.unpaired or {}
    global.bot_max = global.bot_max or {}
  end

  nodes = global.nodes
  pchargers = global.pchargers
  counters = global.counters
  new_nodes = global.new_nodes
  is_charged = global.is_charged
  unpaired = global.unpaired
  bot_max = global.bot_max
end

-- Automatically blacklists chargeless robots (Creative Mode, Nuclear/Fusion Bots, ...)
local function is_chargeable_bot(proto)
  -- Creative Mode; Nuclear Robots; Jamozed's Fusion Robots
  return (proto.energy_per_tick > 0 or proto.energy_per_move > 0) and proto.speed_multiplier_when_out_of_energy < 1
end

local function set_chargeable_bots()
  global.bot_max = {}
  bot_max = global.bot_max

  for _, proto in pairs(game.entity_prototypes) do
    if proto.type == "logistic-robot" then
      if is_chargeable_bot(proto) then
        bot_max[proto.name] = proto.max_energy
      end
    elseif proto.type == "construction-robot" then
      if is_chargeable_bot(proto) then
        bot_max[proto.name] = proto.max_energy
      end
    end
  end

  -- print(serpent.block(global.ChargeTransmission.bot_names))
end

script.on_init(function ()
  init_global()
  set_chargeable_bots()
end)

script.on_load(function ()
  init_global(true)
end)

script.on_configuration_changed(function(event)
  set_chargeable_bots()
  if event.mod_changes["ChargeTransmission"] then
    local ct = event.mod_changes["ChargeTransmission"]
    -- TODO: Symver-respecting upgrade chain
  end
end)


local function find_node(cell)
  if not(cell and cell.valid and cell.owner.valid) then return end
  if nodes[cell.owner.unit_number] then
    return nodes[cell.owner.unit_number]
  else
    for _, node in pairs(new_nodes) do
      if node.cell.valid and node.id == cell.owner.unit_number then
        return node
      end
    end
  end
end

local function get_closest_cell(charger)
  local neighbours = charger.logistic_cell.neighbours
  local index = nil
  local distance = math.huge
  local foundNode = false
  for i, neighbour in ipairs(neighbours) do
    if find_node(neighbour) then
      local new_distance = Position.distance_squared(charger.position, neighbour.owner.position)
      if not foundNode then
        -- print("first node, d²="..new_distance)
        distance = new_distance; index = i
        foundNode = true
      elseif new_distance < distance then
        -- print("node, d²="..new_distance)
        distance = new_distance; index = i
      end
    elseif not foundNode then
      local new_distance = Position.distance_squared(charger.position, neighbour.owner.position)
      if new_distance < distance then
        -- print("not node, d²="..new_distance)
        distance = new_distance; index = i
      end
    end
  end

  if index then
    return neighbours[index], index
  end
end

-- Finalizes building a charger, doing the following:
--  Creates the composite unit (radar)
--  Tries to find the closest logistic cell (roboport) and register it
--   Else, adds it as an unpaired charger
local function on_built_charger(entity)
  if entity.name:find("charge%-transmission_bots") then
    local transmitter = entity.surface.create_entity{
      name = "charge-transmission_bots-transmitter",
      position = entity.position,
      force = entity.force
    }
    transmitter.destructible = false
    Entity.set_data(transmitter, {main = entity})

    local warning = entity.surface.create_entity{
      name = "charge-transmission_bots-warning",
      position = entity.position,
    }
    warning.destructible = false
    warning.graphics_variation = 1

    local data = {transmitter = transmitter, warning = warning}
    -- data.cell, data.index = get_closest_cell(entity)
    Entity.set_data(entity, data)
    -- print("created unpaired charger "..entity.unit_number)
    unpaired[entity.unit_number] = entity
  elseif entity.name:find("charge%-transmission_players") then
    local transmitter = entity.surface.create_entity{
      name = "charge-transmission_players-transmitter",
      position = entity.position,
      force = entity.force
    }
    transmitter.destructible = false
    Entity.set_data(transmitter, {main = entity})

    local data = {transmitter = transmitter}
    Entity.set_data(entity, data)

    pchargers[entity.unit_number] = entity
    counters.pchargers = counters.pchargers + 1
  end
end

-- Removes a charger from a node, if it's there (complexity for debug purposes)
local function remove_bot_charger(charger, node)
  if node.chargers[charger.unit_number] then
    node.chargers[charger.unit_number] = nil
    -- print("removed charger "..charger.unit_number.." from node "..node.id)
  end
end

-- Unpairs a charger (removes it from its linked node, or all if that node's invalid)
local function unpair_bot_charger(charger)
  local data = Entity.get_data(charger) or {}
  local node = find_node(data.cell)
  if data and data.cell then data.cell = nil end

  if node then
    -- known node, remove only from that one
    remove_bot_charger(charger, node)
    return
  else
    -- unknown node, remove from all valid nodes
    for _, n in pairs(nodes) do
      remove_bot_charger(charger, n)
    end
    -- and from all reserved new nodes
    for _, n in pairs(new_nodes) do
      remove_bot_charger(charger, n)
    end
  end
  -- print("unpaired charger "..charger.unit_number)
end

local function on_mined_charger(charger)
  if charger.name:find("charge%-transmission_bots") then
    -- remove composite partners
    local data = Entity.get_data(charger)
    if data.transmitter and data.transmitter.valid then data.transmitter.destroy() end
    if data.warning and data.warning.valid then data.warning.destroy() end

    -- erase data
    Entity.set_data(charger, nil)

    -- remove oneself from nodes
    unpair_bot_charger(charger)
  elseif charger.name:find("charge%-transmission_players") then
    local data = Entity.get_data(charger)
    if data.transmitter and data.transmitter.valid then data.transmitter.destroy() end
  end
end

-- Registers a charger, placing it on its rightful node (or creating a new one)
-- Warning: does not update the charger entity's data to point at the cell
local function pair_bot_charger(charger, cell)
  local node = find_node(cell)
  if not node then
    -- new node
    node = {cell = cell, chargers = {}, id = cell.owner.unit_number}

    node.area = Position.expand_to_area(node.cell.owner.position, math.max(node.cell.construction_radius, node.cell.logistic_radius))
    -- register the node
    table.insert(new_nodes, node)
    -- print("new node "..node.id.." for cell "..cell.owner.unit_number)
  end

  node.chargers[charger.unit_number] = charger
  -- print("added charger "..charger.unit_number.." to node "..node.id)
  return node
end

local function on_player_rotated_bot_charger(charger, player)
  -- print("rotated charger "..charger.unit_number)
  local data = Entity.get_data(charger)

  -- swap charger to the next "node"
  unpair_bot_charger(charger)

  local neighbours = charger.logistic_cell.neighbours
  if next(neighbours) then
    local new_index = (data.index)%(#neighbours) + 1
    -- print("#: "..data.index.."->"..new_index)
    -- print("id: "..neighbours[data.index].owner.unit_number.."->"..neighbours[new_index].owner.unit_number)
    data.index = new_index
    data.cell = neighbours[new_index]
    -- Entity.set_data(charger, data)
    pair_bot_charger(charger, neighbours[new_index])

    -- update arrow
    player.set_gui_arrow{type="entity", entity=neighbours[new_index].owner}
  end
end

Event.register(defines.events.on_built_entity, function(event) on_built_charger(event.created_entity) end)
Event.register(defines.events.on_robot_built_entity, function(event) on_built_charger(event.created_entity) end)

-- TODO: the function is kind of a misnamer now, isn't it
Event.register(defines.events.on_entity_died, function(event) on_mined_charger(event.entity) end)
Event.register(defines.events.on_player_mined_entity, function(event) on_mined_charger(event.entity) end)
Event.register(defines.events.on_robot_mined_entity, function(event) on_mined_charger(event.entity) end)

Event.register(defines.events.on_player_rotated_entity, function(event)
  if(event.entity.name:find("charge%-transmission_bots%-transmitter")) then
    local data = Entity.get_data(event.entity)
    local charger = data.main
    local player = game.players[event.player_index]

    on_player_rotated_bot_charger(charger, player)
  end
end)

Event.register(defines.events.on_selected_entity_changed, function(event)
  local player = game.players[event.player_index]
  local current_entity = player.selected
  if current_entity and current_entity.name:match("charge%-transmission_bots%-transmitter") then
    local data = Entity.get_data(current_entity)
    data = Entity.get_data(data.main)

    if data.cell and data.cell.valid then
      player.set_gui_arrow{type="entity", entity=data.cell.owner}
    end
  elseif event.last_entity and event.last_entity.name:match("charge%-transmission_bots") then
    player.clear_gui_arrow()
  end
end)

-- TODO: Optimize this, make it squeaky clean
-- *  code check
-- *  add more .valid checks
script.on_event(defines.events.on_tick, function(event)

  -- charger re-pairing
  local next_charger
  counters.uid, next_charger = next(unpaired, counters.uid)
  -- print("on_tick:unpair:"..(counters.uid or "nil")..":"..((next_charger and next_charger.valid and next_charger.unit_number) or "nil"))
  if next_charger then
    if next_charger.valid then
      local data = Entity.get_data(next_charger)
      data.cell, data.index = get_closest_cell(next_charger)
      -- Entity.set_data(unpaired_charger, data)
      if data.cell then
        pair_bot_charger(next_charger, data.cell)
        unpaired[next_charger.unit_number] = nil
      end
    else
      unpaired[counters.uid] = nil
    end
  end

  -- before iterating nodes...
  if event.tick%60 == 0 then
    -- clear registered bots
    global.is_charged = {}
    is_charged = global.is_charged

    -- register new nodes
    for _, node in pairs(new_nodes) do
      if nodes[node.id] then
        -- if the node is already there, move the chargers into it
        for cid, charger in pairs(node.chargers) do
          nodes[node.id].chargers[cid] = charger
          -- print("joined charger "..cid.." into node "..node.id)
        end
      else
        nodes[node.id] = node
        counters.nodes = counters.nodes + 1
        -- print("added node "..node.id)
        -- print(#nodes)
      end
    end

    -- clean new nodes list
    global.new_nodes = {}
    new_nodes = global.new_nodes

    -- clear invalid nodes
    for key, node in pairs(nodes) do
      if not (node.cell.valid and next(node.chargers)) then
        -- node is invalid: remove node, orphan chargers
        for _, charger in pairs(node.chargers) do
          if charger and charger.valid then
            local data = Entity.get_data(charger)
            data.transmitter.power_usage = 0
            data.index = nil
            data.cell = nil
            -- Entity.set_data(charger, data)
            -- print("unpaired charger "..charger.unit_number.." from node "..node.id)
            unpaired[charger.unit_number] = charger
          end
        end
        nodes[key] = nil
        -- counters.nodes = counters.nodes - 1
        -- print("removed node "..node.id)
        -- print(table_size(nodes))
      end
    end
    counters.nodes = table_size(nodes)

    -- clear invalid player chargers
    for key, charger in pairs(pchargers) do
      if not charger.valid then
        pchargers[key] = nil
      end
    end
    counters.pchargers = table_size(pchargers)

    -- seed the next iter
    counters.nid = next(nodes)
    counters.pcid = next(pchargers)
  end

  -- area scanning
  -- TODO: add +1 so it always does the non-tick one
  local iter = 0
  local count = counters.nodes
  local max
  -- log(counters.done_nodes)
  -- print((5-counters.nodes%5)%5)
  if event.tick%60 == 59 then max = math.huge -- Damage control, does ALL remaining nodes in the end until you nil
  elseif event.tick%60 >= (60-count%60)%60 then max = math.ceil(count/60) -- separates the nodes over 60 seconds
  else max = math.floor(count/60) end
  -- max = math.ceil(counters.nodes/5)
  -- print(counters.nid)

  while counters.nid and iter < max do
    local node = nodes[counters.nid]
    iter = iter + 1
    -- print(event.tick..": processing node "..node.id.." | "..iter.." of "..max.." in "..#nodes)

    if node and node.cell.valid then
      -- calculate total available energy
      local n_chargers = 0
      local energy = 0
      local cost = 0
      local debt = 0

      -- retrieve active/useful chargers and total energy buffer
      for key, charger in pairs(node.chargers) do
        if charger.valid then
          local transmitter = Entity.get_data(charger).transmitter
          transmitter.power_usage = 0
          -- TODO: energy_usage is a constant, refactor away
          if charger.energy >= charger.prototype.energy_usage then
            energy = energy + transmitter.energy
            n_chargers = n_chargers + 1
          else
            -- Reset out of overtaxed (because it's the interface that is dying, not the antenna)
            Entity.get_data(charger).warning.graphics_variation = 1
          end
        else
          node.chargers[key] = nil
          -- print("cleaned invalid charger "..key.." from node "..node.id)
        end
      end

      if n_chargers > 0 then
        -- check total energy cost
        -- local bots = 0
        local constrobots, logibots
        constrobots = node.cell.owner.surface.find_entities_filtered {
          area = node.area,
          force = node.cell.owner.force,
          type = "construction-robot"
        }
        logibots = node.cell.owner.surface.find_entities_filtered {
          area = node.area,
          force = node.cell.owner.force,
          type = "logistic-robot"
        }

        if #constrobots + #logibots > 0 then
          local modifier = 1 + node.cell.owner.force.worker_robots_battery_modifier
          for bid=1,#constrobots + #logibots do
            local bot
            if bid <= #constrobots then bot = constrobots[bid]
            else bot = logibots[bid - #constrobots] end
            local max_energy = bot_max[bot.name] * modifier

            if bot and max_energy and bot.energy < max_energy then
              cost = cost + (max_energy - bot.energy) * 1.5
              if cost < energy then
                bot.energy = max_energy
                is_charged[bot.unit_number] = true
                -- bots = bots + 1
              else break end
            end
          end

          -- split the energetic debt between the chargers and time
          debt = cost / (60 * n_chargers)
        end
        -- print("debt: "..debt..", cost: "..cost..", energy: "..energy..", bots: "..bots)
      end


      -- set power cost on the transmitteres
      -- TODO: there's two constants down there, we should cache them!
      for _, charger in pairs(node.chargers) do
        if charger.energy >= charger.prototype.energy_usage then
          local data = Entity.get_data(charger)
          data.transmitter.power_usage = debt

          -- state machine:
          --   1: neutral, don't display
          --   2: active, don't display
          --   3: active, display (toggled below)
          -- 1->2, 2/3->1
          if cost > energy or debt > charger.electric_input_flow_limit then
            if data.warning.graphics_variation == 1 then
              data.warning.graphics_variation = 2
            end
          else
            data.warning.graphics_variation = 1
          end
        end
      end
    end

    counters.nid = next(nodes, counters.nid)
    -- print("next node: "..serpent.block(counters.nid))
  end

  -- player scanning
  -- same logic as above
  iter = 0
  count = counters.pchargers
  if event.tick%60 == 59 then max = math.huge
  elseif event.tick%60 >= (60-count%60)%60 then max = math.ceil(count/60)
  else max = math.floor(count/60) end

  while counters.pcid and iter < max do
    local charger = pchargers[counters.pcid]
    iter = iter + 1

    if charger and charger.valid then
      local network = charger.logistic_network
      local transmitter = Entity.get_data(charger).transmitter
      if network and transmitter and transmitter.valid then
        local cost = 0
        local energy = transmitter.energy

        -- fetch all requesters on network, which include... players!
        for _, player in pairs(network.requesters) do
          local armors = player.get_inventory(defines.inventory.player_armor) or {}
          for aid=1,#armors do
            local armor = armors[aid]
            local grid = armor.grid
            if grid then
              for k, equipment in pairs(grid.equipment) do
                -- precalculate need so to be able to add partial energy recharges
                local need = equipment.max_energy - equipment.energy
                if cost + need < energy then
                  equipment.energy = equipment.max_energy
                  cost = cost + need
                else
                  equipment.energy = equipment.energy + (energy - cost)
                  cost = energy
                  -- leave the whole for-loop block
                  goto finished
                end
              end
            end
          end
        end
        ::finished::
        transmitter.power_usage = cost / 60

      end
    end

    counters.pcid = next(pchargers, counters.pcid)
  end

  -- displays the blinking custom warning for overtaxing
  if event.tick%30 == 0 then
    for _, n in pairs(nodes) do
      for _, charger in pairs(n.chargers) do
        local warning = Entity.get_data(charger).warning

        if warning and warning.graphics_variation ~= 1 then
          if event.tick%60 == 0 then
            warning.graphics_variation = 2
          else
            warning.graphics_variation = 3
          end
        end
      end
    end
  end
end)