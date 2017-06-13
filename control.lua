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

local nodes, new_nodes, is_charged, unpaired, bot_max
local function init_global(is_load)
  if not is_load then
    global.nid = nil
    global.done_nodes = 0
    global.total_nodes = 0
    global.nodes = global.nodes or {}
    global.new_nodes = global.new_nodes or {}
    global.is_charged = global.is_charged or {}
    global.uid = nil
    global.unpaired = global.unpaired or {}
    global.bot_max = global.bot_max or {}
  end

  nodes = global.nodes
  new_nodes = global.new_nodes
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


local function find_node(cell)
  if nodes[cell.owner.unit_number] then
    return nodes[cell.owner.unit_number]
  else
    for _, node in pairs(new_nodes) do
      if node.cell.valid and node.cell.owner.unit_number == cell.owner.unit_number then
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

-- Registers a charger, placing it on its rightful node (or creating a new one)
-- Warning: does not update the charger entity's data to point at the cell
local function pair_charger(charger, cell)
  local node = find_node(cell)
  if not node then
    -- new node
    node = {cell = cell, chargers = {}, id = cell.owner.unit_number}
    node.area = Position.expand_to_area(node.cell.owner.position, node.cell.construction_radius)
    -- register the node
    table.insert(new_nodes, node)
    log("new node "..node.id.." for cell "..cell.owner.unit_number)
  end

  node.chargers[charger.unit_number] = charger
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
    -- local warning = entity.surface.create_entity{
    --   name = "charge-transmission_charger-warning",
    --   position = entity.position,
    -- }
    -- warning.destructible = false
    -- warning.graphics_variation = 1

    local data = {transmitter = transmitter}
    data.cell, data.index = get_closest_cell(entity)
    Entity.set_data(entity, data)

    if data.cell then
      log("created reserved charger "..entity.unit_number.." for node "..data.cell.owner.unit_number)
      pair_charger(entity, data.cell)
    else
      log("created unpaired charger "..entity.unit_number)
      unpaired[entity.unit_number] = entity
    end
  end
end

-- Removes a charger from, either the node (cell) it has saved, or from all if the node is invalid
local function unpair_charger(charger)
  local data = Entity.get_data(charger) or {}
  local node = find_node(data.cell)
  if data then data.cell = nil end

  if node then
    -- known node, remove only from that one
    node.chargers[charger.unit_number] = nil
    log("unpaired charger "..charger.unit_number.." from node "..node.id)
    return
  else
    -- unknown node, remove from all valid nodes
    for _, n in pairs(nodes) do
      n.chargers[charger.unit_number] = nil
      log("unpaired charger "..charger.unit_number.." from node "..n.id)
    end

    for _, n in pairs(new_nodes) do
      n.chargers[charger.unit_number] = nil
      log("unpaired charger "..charger.unit_number.." from node "..n.id)
    end
  end
end

local function on_mined_charger(charger)
  if(charger.name:find("charge%-transmission_charger")) then
    -- remove composite partners
    local data = Entity.get_data(charger)
    if data.transmitter and data.transmitter.valid then data.transmitter.destroy() end
    if data.warning and data.warning.valid then data.warning.destroy() end

    -- erase data
    Entity.set_data(charger, nil)

    -- remove oneself from nodes
    unpair_charger(charger)
  end
end

local function on_player_rotated_charger(charger, player)
  log("rotated charger "..charger.unit_number)
  local data = Entity.get_data(charger)

  -- swap charger to the next "node"
  unpair_charger(charger)

  local neighbours = charger.logistic_cell.neighbours
  if next(neighbours) then
    local new_index = (data.index)%(#neighbours) + 1
    log("#: "..data.index.."->"..new_index)
    log("id: "..neighbours[data.index].owner.unit_number.."->"..neighbours[new_index].owner.unit_number)
    data.index = new_index
    data.cell = neighbours[new_index]
    -- Entity.set_data(charger, data)
    pair_charger(charger, neighbours[new_index])

    -- update arrow
    player.set_gui_arrow{type="entity", entity=neighbours[new_index].owner}
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

  -- charger re-pairing
  local unpaired_charger
  global.uid, unpaired_charger = next(unpaired, global.uid)
  if unpaired_charger then
    if unpaired_charger and unpaired_charger.valid then
      local data = Entity.get_data(unpaired_charger)
      data.cell, data.index = get_closest_cell(unpaired_charger)
      -- Entity.set_data(unpaired_charger, data)
      if data.cell then
        pair_charger(unpaired_charger, data.cell)
        unpaired[unpaired_charger.unit_number] = nil
      end
    else
      unpaired[global.uid] = nil
    end
  end

  -- before iterating nodes...
  if event.tick%60 == 0 then
    -- clear registered bots
    global.is_charged = {}
    is_charged = global.is_charged

    -- register new nodes
    for nid, node in pairs(new_nodes) do
      if nodes[nid] then
        -- if the node is already there, move the chargers into it
        for cid, charger in pairs(node.chargers) do
          nodes[nid].chargers[cid] = charger
          log("joined node "..node.id)
        end
      else
        nodes[nid] = node
        global.total_nodes = global.total_nodes + 1
        log("added node "..node.id)
      end
      new_nodes[nid] = nil
    end

    -- clear invalid nodes
    for key, node in pairs(nodes) do
      if not node.cell.valid or #(node.chargers) <= 0 then
        log(node.id.."!"..#(node.chargers))
        -- node is invalid: remove node, orphan chargers
        -- TODO: fix unpaired so either iteration works here
        for _, charger in pairs(node.chargers) do
          if charger and charger.valid then
            local data = Entity.get_data(charger)
            data.transmitter.power_usage = 0
            data.index = nil
            data.cell = nil
            -- Entity.set_data(charger, data)
            log("unpaired charger "..charger.unit_number.." from node "..node.id)
            unpaired[charger.unit_number] = charger
          end
        end
        nodes[key] = nil
        global.total_nodes = global.total_nodes - 1
        log("removed node "..node.id)
      end
    end
  end

  -- area scanning
  -- TODO: add +1 so it always does the non-tick one
  local max
  if global.done_nodes > global.total_nodes%5 then max = math.ceil(global.total_nodes/5)
  else max = math.floor(global.total_nodes/5) end
  local iter = 0

  while iter < max do
    local node
    global.nid, node = next(nodes, global.nid)
    log(node.id..":"..iter.." of "..max.." in "..global.total_nodes)
    -- TODO: move stuff of tick 0 over here and make it call next again

    if node and node.cell.valid then
      -- calculate total available energy
      local energy = 0
      for key, charger in pairs(node.chargers) do
        if charger.valid then
          local transmitter = Entity.get_data(charger).transmitter
          transmitter.power_usage = 0
          -- TODO: energy_usage is a constant, refactor away
          if charger.energy >= charger.prototype.energy_usage then
            energy = energy + transmitter.energy
          else
            -- Reset out of overtaxed (because it's the interface that is dying, not the antenna)
            Entity.get_data(charger).warning.graphics_variation = 1
          end
        else
          node.chargers[key] = nil
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
        log("#"..node.id..":debt "..debt..":cost "..cost..":energy "..energy..":bots "..bots)
      end

      -- set power cost on the transmitteres
      -- TODO: there's two constants down there, we should cache them!
      local overtaxed = cost > energy
      for _, charger in pairs(node.chargers) do
        if charger.energy >= charger.prototype.energy_usage then
          local data = Entity.get_data(charger)
          data.transmitter.power_usage = debt

          -- state machine:
          --   1: neutral, don't display
          --   2: active, don't display
          --   3: active, display (toggled below)
          -- 1->2, 2/3->1
          if overtaxed or debt > charger.prototype.input_flow_limit then
            if data.warning.graphics_variation == 1 then
              data.warning.graphics_variation = 2
            end
          else
            data.warning.graphics_variation = 1
          end
        end
      end
    end

    iter = iter + 1
  end
  global.done_nodes = global.done_nodes + iter

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