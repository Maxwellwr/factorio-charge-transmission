MOD = {}
MOD.name = "ChargeTransmission"
MOD.if_name = "charge-transmission"
MOD.interfaces = {}
MOD.commands = {}
MOD.config = require "control.config"

local Position = require "stdlib/area/position"
require "stdlib/event/event"

-- Enables Debug mode for new saves
if MOD.config.DEBUG then
  log(MOD.name .. " Debug mode enabled")
  require("stdlib/debug/quickstart")
end

local chargers, free_chargers, nodes, hashed_nodes, active_nodes, counters, constants

--############################################################################--
--                                   LOGIC                                    --
--############################################################################--

-- returns the node serving this cell, or nil
-- even if the node is enqueued to be added (in new_nodes)
local function get_node(cell)
  return cell and cell.valid and nodes[cell.owner.unit_number]
end

-- gets the closest cell to position
-- we don't just return LuaLogisticNetwork.find_cell_closest_to() because we give priority to cells being served by nodes
local function get_closest_cell(position, network)
  local closest_cell = network.find_cell_closest_to(position)

  -- short-circuit if there's no cell close to (how?) or if it is already a node (score)
  if get_node(closest_cell) then return closest_cell end

  -- so the closest cell is either a node or the one already in closest_cell
  -- let's find out!

  -- get cells that are close enough (include position) and are in a node
  local possible_nodes = table.filter(network.cells, function(cell)
    return cell.is_in_logistic_range(position) and get_node(cell)
  end)

  -- find the closest of these
  local min = math.huge

  for _, cell in pairs(possible_nodes) do
    -- the loop doesn't run if the table's empty
    local distance = Position.distance_squared(position, cell.owner.position)
    if distance < min then
      min = distance; closest_cell = cell
    end
  end

  return closest_cell
end

-- picks the right display variant between a charger and its target
-- 1-9 (1 being 0 rad and 9 2π rad)
local function update_display(charger)
  local vector = Position.subtract(charger.base.position, charger.target.owner.position)
  -- y axis is reversed -_-
  local orientation = (math.atan2(-vector.y, vector.x) / math.pi + 1) / 2
  charger.display.graphics_variation = math.floor(orientation * 8 + 0.5) % 8 + 2
end

local function enqueue_charger(charger)
  free_chargers[charger.id] = charger
  print("enqueued charger "..charger.id)
end

-- Removes a charger from a node, if it's there (complexity for debug purposes)
-- requeue: if true adds the charger to the free_charger list too
local function free_charger(charger, enqueue)
  local node = get_node(charger.target)
  if node then
    node.chargers[charger.id] = nil
    node.active = false
    print("removed charger "..charger.id.." from node "..node.id)
  end
  charger.target = nil
  if charger.display and charger.display.valid then
    charger.display.graphics_variation = 1
  end

  if enqueue then enqueue_charger(charger) end
end

-- adds a cell as a charger's target (and hence pairs it with any respective node)
local function target_cell(charger, cell)
  charger.target = cell

  -- make the display point at the cell's owner
  update_display(charger)

  local node = get_node(cell)
  if node then
    node.chargers[charger.id] = charger
    node.active = false
    print("added charger "..charger.id.." to node "..node.id)
  else
    -- new node
    node = {
      cell = cell,
      chargers = {},
      id = cell.owner.unit_number,
      active = false,
    }
    node.chargers[charger.id] = charger
    nodes[node.id] = node

    local hash = node.id%60
    if not hashed_nodes[hash] then hashed_nodes[hash] = {node}
    else table.insert(hashed_nodes[hash], node) end

    print("new node "..node.id.." with charger "..charger.id)
  end
end

-- return: true if a pair node was found
local function pair_charger(charger)
  -- ignore already those with targets
  if charger.target and charger.target.valid then return end

  local network = charger.base.surface.find_logistic_network_by_position(charger.base.position, charger.base.force)

  if not network then return false end

  local closest = get_closest_cell(charger.base.position, network)
  if not closest then return false end

  target_cell(charger, closest)
  return true
end

--############################################################################--
--                                   EVENTS                                   --
--############################################################################--

-- Finalizes building a charger, doing the following:
--  Creates the composite unit (radar)
--  Tries to find the closest logistic cell (roboport) and register it
--   Else, adds it as an unpaired charger
local function on_built_charger(event)
  local entity = event.created_entity

  if entity.name == "charge_transmission-charger" then
    local charger = {
      base = entity,
      id = entity.unit_number,
      c_debt = 0,
      l_debt = 0
    }
    chargers[charger.id] = charger

    charger.interface = entity.surface.create_entity {
      name = "charge_transmission-charger_interface",
      position = entity.position,
      force = entity.force
    }
    charger.interface.destructible = false

    charger.display = entity.surface.create_entity {
      name = "charge_transmission-charger_display",
      position = entity.position,
      force = entity.force
    }
    charger.display.destructible = false
    charger.display.graphics_variation = 1

    -- fixes any overlay issues (not needed any more but it doesn't hurt)
    entity.teleport(entity.position)

    if not pair_charger(charger) then enqueue_charger(charger) end
  end
end

local function on_mined_charger(event)
  local entity = event.entity

  if entity.name:find("charge_transmission%-charger") then
    if entity.name == "charge_transmission-charger" then
      local charger = chargers[entity.unit_number]
      if not charger then
        log "Attempted to remove already-dismantled charger"

        -- TODO: making sure the area is *really* clean
        return
      end

      free_charger(charger)

      -- remove composite partners
      for _, component in pairs({charger.interface, charger.display}) do
        if component and component.valid then
          component.destroy()
        end
      end

      chargers[charger.id] = nil
    else
      log "Abnormal destruction... what shall we do?"
      log(serpent.block(entity))
    end
  end
end

local function on_player_rotated_charger(event)
  local interface = event.entity
  if interface.name ~= "charge_transmission-charger_interface" then return end
  local player = game.players[event.player_index]

  -- print("rotated charger "..charger.unit_number)
  local charger_entity = interface.surface.find_entity("charge_transmission-charger", interface.position)
  local charger = (charger_entity and chargers[charger_entity.unit_number]) or nil

  -- require a charger with a valid target
  if not (charger_entity and charger and charger.target and charger.target.valid) then return end

  -- get all possible targets, under a node or not
  local cells = table.filter(charger.target.logistic_network.cells, function(cell)
    return cell.is_in_logistic_range(charger.base.position)
  end)

  -- quit if empty list
  if not next(cells) then return end

  -- get the next target
  if not charger.index or not cells[charger.index] then charger.index = next(cells)
  else charger.index = next(cells, charger.index) end
  -- avoid hitting the same current target (at least once)
  if charger.index and cells[charger.index].owner.unit_number == charger.target.owner.unit_number then
    charger.index = next(cells, charger.index)
  end
  -- rewind if there reached the end of the table (nil index)
  if not charger.index or not cells[charger.index] then charger.index = next(cells) end

  -- swap charger to the next "node"
  free_charger(charger)
  target_cell(charger, cells[charger.index])

  -- update arrow
  player.set_gui_arrow{type="entity", entity=charger.target.owner}
end

local function on_dolly_moved_entity(event)
  --[[
    player_index = player_index, --The index of the player who moved the entity
    moved_entity = entity, --The entity that was moved
    start_pos = position --The position that the entity was moved from
  --]]

  if event.moved_entity.name:find("charge_transmission%-charger") then
    if event.moved_entity.name ~= "charge_transmission-charger" then
      -- nuh huh, only the base can teleport, put that thing back where it came from, or so help me!
      event.moved_entity.teleport(event.start_pos)
    else
      -- move the rest of the composed entity
      local charger = chargers[event.moved_entity.unit_number]

      for _, component in pairs({charger.interface, charger.display}) do
        if component and component.valid then
          component.teleport(event.moved_entity.position)
        end
      end

      print("teleported charger "..charger.id)

      -- check if connected roboport is still within range
      if charger.target and not charger.target.is_in_logistic_range(event.moved_entity.position) then
        free_charger(charger, true)
        print("freed charger "..charger.id.." because out of reach")
      end
    end
  end
end

local function on_selected_entity_changed(event)
  local player = game.players[event.player_index]
  local current_entity = player.selected
  if current_entity and current_entity.name == "charge_transmission-charger_interface" then
    local charger_entity = current_entity.surface.find_entity("charge_transmission-charger", current_entity.position)
    local charger = (charger_entity and chargers[charger_entity.unit_number]) or nil

    if charger and charger.target and charger.target.valid then
      -- player.update_selected_entity(data.cell.owner.position)
      player.set_gui_arrow{type="entity", entity=charger.target.owner}
    end
  elseif event.last_entity and event.last_entity.name:match("charge_transmission%-charger") then
    player.clear_gui_arrow()
  end
end

--------------------------------------------------------------------------------
--                                  ON TICK                                   --
--------------------------------------------------------------------------------

local function get_charger_consumption(charger)
  -- returns the consumption bonus/penalty from the charger
  if not constants.use_modules then
    return 1.5
  else
    -- 300% max over 60 ticks (factor the 3 out)
    local consumption = (charger.base.effects and charger.base.effects.consumption and charger.base.effects.consumption.bonus or 0) * constants.distribution_effectivity
    return math.max(0.2, 1 + consumption) * 3
  end
end

-- TODO: Hey so, consumption is general... can't you globalize it? and maybe even disperse the cost in real time?
local function on_tick(event)
  --[[ Free Charger Reassignment (4c/s) ]]
  if event.tick%15 == 0 then
    if not free_chargers[counters.next_charger] then counters.next_charger = nil end
    local next_charger
    counters.next_charger, next_charger = next(free_chargers, counters.next_charger)

    if next_charger then
      if next_charger.base.valid then
        if pair_charger(next_charger) then
          free_chargers[next_charger.id] = nil
        end
      else free_chargers[next_charger.id] = nil end
    end
  end

  --[[ Robot Recharging (50?r/tick) ]]
  local total_robots = constants.robots_limit
  if not(counters.next_node and counters.next_node > 1 and counters.next_node <= #active_nodes) then
    counters.next_node = #active_nodes
  end
  for i = counters.next_node, 1, -1 do
    counters.next_node = i
    if total_robots <= 0 then goto end_bots end
    local node = nodes[active_nodes[i]]

    if node and node.active and node.cell.valid then
      local surface = node.cell.owner.surface
      local beam_position = node.cell.owner.position

      for _, bot in pairs(node.cell.to_charge_robots) do
        if node.cost >= node.energy then
          node.active = false
          active_nodes[i] = nil -- needed for when #[] == 1
          active_nodes[i], active_nodes[#active_nodes] = active_nodes[#active_nodes], nil
          break
        end

        local new_bot = surface.create_entity {
          name = bot.name,
          force = bot.force,
          position = bot.position,
        }
        -- new_bot.health = bot.health
        surface.create_entity {
          name = "charge_transmission-beam",
          position = beam_position,
          source_position = beam_position,
          target = new_bot,
          duration = 20,
        }
        node.cost = node.cost + new_bot.energy - bot.energy

        -- transfer inventory (based on stdlib's Inventory)
        -- bots only have 1-slot sized inventories, so...
        local stack = bot.get_inventory(defines.inventory.item_main)[1]
        if stack and stack.valid and stack.valid_for_read then
          new_bot.get_inventory(defines.inventory.item_main).insert({
            name = stack.name,
            count = stack.count,
            health = stack.health or 1,
            durability = stack.durability,
            ammo = stack.prototype.magazine_size and stack.ammo
          })
        end

        bot.destroy()
        total_robots = total_robots - 1
        if total_robots <= 0 then goto end_bots end
      end
    else
      if node then
        node.active = false
        print("deactivated node "..node.id)
      end
      active_nodes[i] = nil -- needed for when #[] == 1
      active_nodes[i], active_nodes[#active_nodes] = active_nodes[#active_nodes], nil
    end
  end
  ::end_bots::

  --[[ Node Updating (n%60/tick) ]]
  local tick_nodes = hashed_nodes[event.tick%60]
  if not tick_nodes then
    hashed_nodes[event.tick%60] = {}
    tick_nodes = hashed_nodes[event.tick%60]
  end

  for i = #tick_nodes, 1, -1 do
    local node = tick_nodes[i]
    -- housecleaning (remove invalid node)
    if not(node and node.cell.valid and next(node.chargers)) then
      if node then
        -- remove node, orphan chargers
        for _, charger in pairs(node.chargers) do free_charger(charger, true) end
        if node.warning and node.warning.valid then node.warning.destroy() end
        node.active = false
      end
      nodes[node.id] = nil
      table.remove(tick_nodes, i)
      print("removed node "..node.id)
    else
      local n_chargers = 0
      local energy = 0

      node.energy = node.energy or 0
      node.cost = node.cost or 0
      -- local consumption = 0

      for key, charger in pairs(node.chargers) do
        if charger.base.valid and charger.interface.valid then
          -- set cost
          charger.interface.power_usage = (charger.fraction and node.cost * (charger.fraction / node.energy) / 60) or 0
          n_chargers = n_chargers + 1

          -- reset charger
          -- consumption = consumption + get_charger_consumption(charger)
          charger.consumption = get_charger_consumption(charger)
          charger.fraction = charger.interface.energy
          energy = energy + charger.fraction / charger.consumption
        else
          node.chargers[key] = nil
          print("cleaned invalid charger "..key.." (== "..charger.id..") from node "..node.id)
        end
      end

      -- node.consumption = consumption / n_chargers

      -- add the warning if necessary
      if node.cost > node.energy or node.cost/(n_chargers*60) > constants.input_flow_limit then
        if not (node.warning and node.warning.valid) then
          node.warning = node.cell.owner.surface.create_entity {
            name = "charge_transmission-warning",
            position = node.cell.owner.position,
          }
        end
      elseif node.warning then
        if node.warning.valid then node.warning.destroy() end
        node.warning = nil
      end

      -- reset the node for the next second
      node.energy = energy
      node.cost = 0
      -- log(serpent.block(node))
      if not node.active then
        table.insert(active_nodes, node.id)
        print("activated node "..node.id)
        node.active = true
      end
    end
  end
end

--------------------------------------------------------------------------------
--                                EVENT HOOKS                                 --
--------------------------------------------------------------------------------

Event.register(defines.events.on_built_entity, on_built_charger)
  .register(defines.events.on_robot_built_entity, on_built_charger)

-- TODO: the function is kind of a misnomer now, isn't it
Event.register(defines.events.on_entity_died, on_mined_charger)
  .register(defines.events.on_pre_player_mined_item, on_mined_charger)
  .register(defines.events.on_robot_pre_mined, on_mined_charger)

-- TODO: these two should really be... moved upwards.
Event.register(defines.events.on_player_rotated_entity, on_player_rotated_charger)

Event.register(defines.events.on_selected_entity_changed, on_selected_entity_changed)

script.on_event(defines.events.on_tick, on_tick)

--############################################################################--
--                              INIT/LOAD/CONFIG                              --
--############################################################################--

local function init_global()
  global.nodes = {}
  global.active_nodes = {}
  global.hashed_nodes = {}
  global.chargers = {}

  global.free_chargers = {}
  global.counters = {
    -- next_charger = nil,
    -- next_node = nil
  }
  global.constants = {}

  global.changed = {}
end

local function update_constants()
  global.constants = global.constants or {}
  constants = global.constants

  constants.distribution_effectivity = game.entity_prototypes["charge_transmission-charger"].distribution_effectivity
  constants.input_flow_limit = game.entity_prototypes["charge_transmission-charger_interface"].electric_energy_source_prototype.input_flow_limit
  constants.use_modules = settings.startup["charge_transmission-use-modules"].value
  constants.robots_limit = settings.global["charge_transmission-robots-limit"].value
end

local function on_load()
  --[[ setup metatables ]]

  --[[ subscribe conditional event handlers ]]
  -- Subscribe to Picker's Dolly event
  if remote.interfaces["picker"] and remote.interfaces["picker"]["dolly_moved_entity_id"] then
    script.on_event(remote.call("picker", "dolly_moved_entity_id"), on_dolly_moved_entity)
  end

  --[[ init local variables ]]
  nodes = global.nodes
  active_nodes = global.active_nodes
  hashed_nodes = global.hashed_nodes
  chargers = global.chargers
  free_chargers = global.free_chargers
  counters = global.counters
  constants = global.constants
end

script.on_init(function ()
  init_global()

  -- Disable all past migrations
  for _, ver in pairs(MOD.migrations) do
    global.changed[ver] = true
  end

  on_load()
end)

script.on_load(on_load)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "charge_transmission-robots-limit" then
    -- update_constants()
    constants.robots_limit = settings.global["charge_transmission-robots-limit"].value
  end
end)

--------------------------------------------------------------------------------
--                                 MIGRATIONS                                 --
--------------------------------------------------------------------------------

MOD.migrations = {"0.3.2", "0.5.0"}

local Entity = require "stdlib/entity/entity"

local migration_scripts = {}
migration_scripts["0.3.2"] = function ()
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

  log("CT 0.3.2 migration applied")
  return true
end
migration_scripts["0.5.0"] = function()
  -- clear global from previous variables
  global.unpaired = nil
  global.bot_max = nil

  -- initiate new ones
  global.nodes = {}
  global.active_nodes = {}
  global.hashed_nodes = {}
  global.chargers = {}
  global.free_chargers = {}
  global.counters = {}
  global.constants = {}

  -- init local variables
  nodes = global.nodes
  active_nodes = global.active_nodes
  hashed_nodes = global.hashed_nodes
  chargers = global.chargers
  free_chargers = global.free_chargers
  counters = global.counters
  constants = global.constants

  -- reform chargers
  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered {
      name = "charge_transmission-charger"
    }
    for _, entity in pairs(entities) do
      on_built_charger({created_entity = entity})
    end
  end

  log("CT 0.5.0 migration applied")
  return true
end

script.on_configuration_changed(function(event)
  if event.mod_changes["ChargeTransmission"] then
    if not global.changed then global.changed = {} end
    for _, ver in pairs(MOD.migrations) do
      if not global.changed[ver] and migration_scripts[ver](event) then
        global.changed[ver] = true
      end
    end
  end

  update_constants()
end)

--############################################################################--
--                            INTERFACES/COMMANDS                             --
--############################################################################--

remote.add_interface(MOD.if_name, MOD.interfaces)
for name, command in pairs(MOD.commands) do
  commands.add_command(name, {"command-help."..name}, command)
end