-- require "stdlib/event/event"
local Position = require "stdlib/area/position"
-- local Area = require "stdlib/area/area"
-- local Surface = require "stdlib/surface"
local Entity = require "stdlib/entity/entity"
require "stdlib/event/event"

MOD = {config = {}}
MOD.config.quickstart = {
    mod_name = "ChargeTransmission",
    clear_items = true,
    power_armor = "power-armor-mk2",
    equipment = {
        "creative-mode_super-fusion-reactor-equipment",
        "personal-roboport-mk2-equipment",
        "belt-immunity-equipment"
    },
    starter_tracks = true,
    destroy_everything = true,
    disable_rso_starting = true,
    disable_rso_chunk = true,
    floor_tile = "lab-dark-1",
    floor_tile_alt = "lab-dark-2",
    ore_patches = true,
    make_train = true,
    area_box = {{-250, -250}, {250, 250}},
    chunk_bounds = true,
    center_map_tag = true,
    setup_power = true,
    stacks = {
        "construction-robot",
    },
    quickbar = {
        "picker-tape-measure",
        "creative-mode_item-source",
        "creative-mode_fluid-source",
        "creative-mode_energy-source",
        "creative-mode_super-substation",
        "creative-mode_magic-wand-modifier",
        "creative-mode_super-roboport",
        "charge-transmission_charger"
    }
}
require "stdlib/debug/quickstart"

local nodes, is_node, is_charged, unpaired, bot_max
local function init_global(is_load)
  if not is_load then
    global.nodes = global.nodes or {}
    global.is_node = global.is_node or {}
    global.is_charged = global.is_charged or {}
    global.unpaired = global.unpaired or {}
    global.bot_max = global.bot_max or {}
    global.logis_bot_max = global.logis_bot_max or {}
    global.constr_bot_max = global.constr_bot_max or {}
  end

  nodes = global.nodes
  is_node = global.is_node
  is_charged = global.is_charged
  unpaired = global.unpaired
  bot_max = global.bot_max
end

-- Automatically blacklists chargeless robots (Creative Mode, Nuclear/Fusion Bots, ...)
local function is_chargeable_bot(proto)
  -- Creative Mode; Nuclear Robots; Jamozed's Fusion Robots
  if proto.energy_per_tick == 0 and proto.energy_per_move == 0 then return false end
  -- (use case without known mods that haven't already matched previously)
  if proto.speed_multiplier_when_out_of_energy >= 1 then return false end

  return true
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

  -- log(serpent.block(global.ChargeTransmission.bot_names))
end

script.on_init(function ()
  init_global()
  set_chargeable_bots()
end)

-- local nodes
script.on_load(function ()
  -- nodes = global.nodes
  init_global(true)
end)

script.on_configuration_changed(function ()
  set_chargeable_bots()
end)


-- TODO: Prioritize node-bearing cells
local function get_closest_cell(charger)
  local neighbours = charger.logistic_cell.neighbours
  local index = nil
  local distance = math.huge
  local foundNode = false
  for i, neighbour in ipairs(neighbours) do
    if is_node[neighbour.owner.unit_number] then
      foundNode = true
      local new_distance = Position.distance_squared(charger.position, neighbour.owner.position)
      if new_distance < distance then distance = new_distance; index = i end
    elseif not foundNode then
      local new_distance = Position.distance_squared(charger.position, neighbour.owner.position)
      if new_distance < distance then distance = new_distance; index = i end
    end
  end

  if index then
    return neighbours[index], index
  end
end

local function find_node(cell)
  for _, node in pairs(nodes) do
    if node.cell.valid and node.cell.owner.unit_number == cell.owner.unit_number then
      return node
    end
  end
end

-- Registers a charger, placing it on its rightful node (or creating a new one)
-- Warning: does not update the charger entity's data to point at the cell
local function pair_charger(charger, cell)
  local node = find_node(cell)
  if not node then
    -- new node
    node = {cell = cell, chargers = {}, id = cell.owner.unit_number}
    node.area = Position.expand_to_area(node.cell.owner.position, node.cell.construction_radius)
    -- register the node
    table.insert(nodes, node)
    is_node[node.id] = true
    log("new node "..node.id.." for cell "..cell.owner.unit_number)
  end

  table.insert(node.chargers, charger)
  log("added charger "..charger.unit_number.." to node "..node.id)
  return node
end

-- Finalizes building a charger, doing the following:
--  Creates the composite unit (radar)
--  Tries to find the closest logistic cell (roboport) and register it
--   Else, adds it as an unpaired charger
local function on_built_charger(entity)
  if(entity.name:find("charge%-transmission_charger")) then
    local transmitter = entity.surface.create_entity{
      name = "charge-transmission_charger-transmitter",
      position = entity.position,
      force = entity.force
    }
    transmitter.destructible = false
    Entity.set_data(transmitter, {main = entity})
    local warning = entity.surface.create_entity{
      name = "charge-transmission_charger-warning",
      position = entity.position,
    }
    warning.destructible = false
    warning.graphics_variation = 1

    local data = {
      transmitter = transmitter,
      warning = warning,
      composite = {transmitter, warning}
    }
    data.cell, data.index = get_closest_cell(entity)
    Entity.set_data(entity, data)

    if data.cell then
      log("created reserved charger "..entity.unit_number.." for node "..data.cell.owner.unit_number)
      pair_charger(entity, data.cell)
    else
      log("created unpaired charger "..entity.unit_number)
      table.insert(unpaired, entity)
    end
  end
end

-- Removes a charger from, either the node (cell) it has saved, or from all if the node is invalid
local function unpair_charger(charger, charger_data)
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

local function on_mined_charger(charger)
  if(charger.name:find("charge%-transmission_charger")) then
    -- remove composite partners
    local data = Entity.get_data(charger)
    for _, slave in pairs(data.composite) do
      if slave.valid then slave.destroy() end
    end
    -- data.transmitter.destroy()
    Entity.set_data(charger, nil)

    -- remove oneself from nodes
    unpair_charger(charger)
  end
end

local function on_player_rotated_charger(charger, player)
  -- log("rotated charger "..charger.unit_number)
  local charger_data = Entity.get_data(charger)

  -- swap charger to the next "node"
  unpair_charger(charger)

  local neighbours = charger.logistic_cell.neighbours
  if next(neighbours) then
    local new_index = (charger_data.index)%(#neighbours) + 1
    -- log("#: "..charger_data.index.."->"..new_index)
    -- log("id: "..neighbours[charger_data.index].owner.unit_number.."->"..neighbours[new_index].owner.unit_number)
    charger_data.index = new_index
    charger_data.cell = neighbours[new_index]
    -- Entity.set_data(charger, charger_data)
    pair_charger(charger, neighbours[new_index])

    -- update arrow
    charger_data = Entity.get_data(charger)
    player.set_gui_arrow{type="entity", entity=charger_data.cell.owner}
  end
end

Event.register(defines.events.on_built_entity, function(event) on_built_charger(event.created_entity) end)
Event.register(defines.events.on_robot_built_entity, function(event) on_built_charger(event.created_entity) end)

Event.register(defines.events.on_player_mined_entity, function(event) on_mined_charger(event.entity) end)
Event.register(defines.events.on_robot_mined_entity, function(event) on_mined_charger(event.entity) end)

Event.register(defines.events.on_player_rotated_entity, function(event)
  if(event.entity.name:find("charge%-transmission_charger%-transmitter")) then
    local data = Entity.get_data(event.entity)
    local charger = data.main
    local player = game.players[event.player_index]

    on_player_rotated_charger(charger, player)
  end
end)

Event.register(defines.events.on_selected_entity_changed, function(event)
  local player = game.players[event.player_index]
  local current_entity = player.selected
  if current_entity and current_entity.name:match("charge%-transmission_charger%-transmitter") then
    local data = Entity.get_data(current_entity)
    data = Entity.get_data(data.main)

    if data.cell and data.cell.valid then
      player.set_gui_arrow{type="entity", entity=data.cell.owner}
    end
  elseif event.last_entity and event.last_entity.name:match("charge%-transmission_charger") then
    player.clear_gui_arrow()
  end
end)


-- TODO: Optimize this, make it squeaky clean
-- ✓  change the architecture so roboports are the grouping element, not the charger so that grouped-together chargers "share the burden"
--    (also solves the issue of a charger having only so much input current)
-- ✓  abstract the robot types to a setting which auto-updates to just save the name and max energy
-- *  code check
-- *  move stuff to pairs()
-- ✓? add more .valid checks
script.on_event(defines.events.on_tick, function(event)

  -- charger re-pairing every 5 seconds
  for cid=1+event.tick%300,#unpaired,300 do
    local charger = unpaired[cid]
    if charger and charger.valid then
      local data = Entity.get_data(charger)
      data.cell, data.index = get_closest_cell(charger)
      Entity.set_data(charger, data)
      if data.cell then
        pair_charger(charger, data.cell)
        table.remove(unpaired, cid)
      end
    else
      table.remove(unpaired, cid)
    end
  end

  -- before iterating nodes...
  if event.tick%60 == 0 then
    -- clear registered bots
    global.is_charged = {}
    is_charged = global.is_charged

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
        transmitter.power_usage = 0
        -- TODO: energy_usage is a constant, refactor away
        if node.chargers[cid].energy >= node.chargers[cid].prototype.energy_usage then
          energy = energy + transmitter.energy
        else
          -- Reset out of overtaxed (because it's the interface that is dying, not the antenna)
          Entity.get_data(node.chargers[cid]).warning.graphics_variation = 1
        end
      else
        table.remove(node.chargers, cid)
      end
    end

    -- check total energy cost
    local cost = 0
    local debt = 0
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

    if #constrobots + #logibots > 0 then
      for bid=1,#constrobots + #logibots do
        local bot
        if bid <= #constrobots then bot = constrobots[bid]
        else bot = logibots[bid - #constrobots] end
        local max_energy = bot_max[bot.name]

        if bot and max_energy and not(is_charged[bot.unit_number]) then
          cost = cost + (max_energy - bot.energy) * 1.5
          if cost < energy then
            bot.energy = max_energy
            is_charged[bot.unit_number] = true
            -- bots = bots + 1
          else break end
        end
      end

      -- split the energetic debt between the chargers and time
      debt = cost / (60 * #(node.chargers))
      -- log("#"..node.id..":debt "..debt..":cost "..cost..":energy "..energy..":bots "..bots)
    end

    -- set power cost on the transmitteres
    -- TODO: there's two constants down there, we should cache them!
    local overtaxed = cost > energy or debt > game.entity_prototypes["charge-transmission_charger-transmitter"].electric_energy_source_prototype.input_flow_limit
    for _, charger in pairs(node.chargers) do
      if charger.energy >= charger.prototype.energy_usage then
        local data = Entity.get_data(charger)
        data.transmitter.power_usage = debt

        -- state machine:
        --   1: neutral, don't display
        --   2: active, don't display
        --   3: active, display (toggled below)
        -- 1->2, 2/3->1
        if overtaxed then
          if data.warning.graphics_variation == 1 then
            data.warning.graphics_variation = 2
          end
        else
          data.warning.graphics_variation = 1
        end
      end
    end
  end

  -- displays the blinking custom warning for overtaxing
  if event.tick%30 == 0 then
    for _, node in pairs(nodes) do
      for _, charger in pairs(node.chargers) do
        local warning = Entity.get_data(charger).warning

        if warning.graphics_variation ~= 1 then
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