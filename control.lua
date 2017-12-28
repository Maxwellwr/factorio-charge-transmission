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

local chargers, nodes, free_chargers, active_nodes, counters

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

-- Finalizes building a charger, doing the following:
--  Creates the composite unit (radar)
--  Tries to find the closest logistic cell (roboport) and register it
--   Else, adds it as an unpaired charger
local function on_built_charger(entity)
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

local function on_mined_charger(entity)
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

local function on_player_rotated_charger(interface, player)
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

--[[ ON_TICK ]]

local function get_charger_consumption(charger)
  -- returns the consumption bonus/penalty from the charger
  if not settings.startup["charge_transmission-use-modules"].value then
    return 1.5
  else
    -- 300% max over 60 ticks (factor the 3 out)
    local consumption = (charger.base.effects and charger.base.effects.consumption and charger.base.effects.consumption.value) or 0
    consumption = consumption * charger.base.prototype.distribution_effectivity
    -- log(serpent.block(charger.base.effects))
    -- log("consumption: "..consumption)
    return math.max(0.2, 1 + consumption) * 3
  end
end

-- TODO: Optimize this, make it squeaky clean
-- *  code check
-- *  add more .valid checks
local function on_tick(event)
  -- one free charger pairing
  if not free_chargers[counters.next_charger] then counters.next_charger = nil end
  local next_charger
  counters.next_charger, next_charger = next(free_chargers, counters.next_charger)

  if next_charger then
    if next_charger.base.valid then
      if pair_charger(next_charger) then
        free_chargers[next_charger.id] = nil
      end
    else
      free_chargers[next_charger.id] = nil
    end
  end

  --[[
    HEY, FUTURE ME. Here's the stitch.

    on_tick should have 4 parallel processes:
    = reassigning chargers
    - "recharging" robots
    - refreshing nodes (energy gain/loss)
      - includes removing invalid nodes

    compared to before, what happened is that i found a way to parallelize robot recharging from node refreshment. this is important because i want X (50 by default) bots recharged PER TICK. but energy gain/loss should be on a metric around 0.5s or 1s. so cycle 2 must be as tight as possible (like cycle 1 was on 0.4).

    how to do it? save how much energy you have left on the node. refresh that ammount on the, uh, refreshing cycle. when you add/remove a charger, invalidate that node (so no extra work gets done that turn, sorry!)

    because of the invalidation mechanic, new_nodes and new_chargers aren't needed anymore, as cycle 2 will never happen on invalidated (read: new or changed) nodes

    but we're not done on the optimization dance. we should probably index module effectivity, even if it's not strictly necessary anymore. we don't need to index max_energy as we're dealing directly with robots that wish to charge, so it's basically swapping one table for another. good thing at least module effect isn't force-based...

    also, need to index *everything* that is related to settings because reading from these takes time. same for prototype stuff, where it can be predicted ahead of time.

    finally, maybe re-reorganize this file once again? the cleanup you did on the folder layout may not have been the best!
  --]]

  -- before iterating nodes...
  if event.tick%60 == 0 then
    -- houseclean active_nodes (and nodes by extension)
    for id, node in pairs(nodes) do
      if node and node.cell.valid and not node.active then
        table.insert(active_nodes, node.id)
        print("activated node "..node.id)
        node.active = true
      elseif not(node and node.cell.valid and next(node.chargers)) then
        nodes[id] = nil
        print("removed node "..node.id)
      end
    end

    for i = #active_nodes, 1, -1 do
      local node = nodes[active_nodes[i]]
      if not(node and node.cell.valid and next(node.chargers)) then
        active_nodes[i] = nil -- needed for when #[] == 1
        active_nodes[i], active_nodes[#active_nodes] = active_nodes[#active_nodes], nil

        if node then
          -- remove node, orphan chargers
          for _, charger in pairs(node.chargers) do free_charger(charger, true) end
          nodes[node.id] = nil
          print("removed node "..node.id)
        end
      end
    end
  end

  for i = #active_nodes - event.tick % 20, 1, -1 * 20 do
    local node = nodes[active_nodes[i]]
    if node and node.cell.valid then
      -- print(event.tick..": processing node "..node.id)
      -- calculate total available energy
      local n_chargers = 0
      local energy = 0
      local cost = 0

      local surface = node.cell.owner.surface

      -- retrieve active/useful chargers and total energy buffer
      for key, charger in pairs(node.chargers) do
        if charger.base.valid then
          charger.interface.power_usage = 0
          -- TODO: energy_usage is a constant, refactor away
          if charger.base.energy >= charger.base.prototype.energy_usage then
            charger.consumption = get_charger_consumption(charger)
            energy = energy + charger.interface.energy / charger.consumption
            n_chargers = n_chargers + 1
          -- else
            -- Reset out of overtaxed (because it's the base that is dying, not the antenna)
            -- if charger.warning then
            --   if charger.warning.valid then charger.warning.destroy() end
            --   charger.warning = nil
            -- end
          end
        else
          node.chargers[key] = nil
          print("cleaned invalid charger "..key.." (== "..charger.id..") from node "..node.id)
        end
      end

      if n_chargers > 0 then
        for _, bot in pairs(node.cell.to_charge_robots) do
          if cost >= energy then break end

          local new_bot = surface.create_entity {
            name = bot.name,
            force = bot.force,
            position = bot.position,
          }
          new_bot.health = bot.health

          cost = cost + new_bot.energy - bot.energy

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

          surface.create_entity {
            name = "charge_transmission-beam",
            position = node.cell.owner.position,
            target = new_bot,
            source_position = node.cell.owner.position,
            duration = 20,
          }
          
        end
      end

      -- set power cost on the interfaces
      -- TODO: there's two constants down there, we should cache them!
      for _, charger in pairs(node.chargers) do
        if charger.base.energy >= charger.base.prototype.energy_usage then
          local fraction = (charger.interface.energy / charger.consumption) / energy
          local debt = cost * fraction / 20
          charger.interface.power_usage = debt * charger.consumption

          -- print(simplified.." ==? "..charger.interface.power_usage)

          if cost > energy or charger.interface.power_usage > charger.interface.electric_input_flow_limit then
            -- log(cost..">"..energy.." : "..debt..">"..charger.interface.electric_input_flow_limit)
            if not (node.warning and node.warning.valid) then
              node.warning = surface.create_entity {
                name = "charge_transmission-warning",
                position = node.cell.owner.position,
              }
            end
          else
            if node.warning then
              if node.warning.valid then node.warning.destroy() end
              node.warning = nil
            end
          end
        end
      end
    end
  end
end


Event.register(defines.events.on_built_entity, function(event) on_built_charger(event.created_entity) end)
  .register(defines.events.on_robot_built_entity, function(event) on_built_charger(event.created_entity) end)

-- TODO: the function is kind of a misnomer now, isn't it
Event.register(defines.events.on_entity_died, function(event) on_mined_charger(event.entity) end)
  .register(defines.events.on_pre_player_mined_item, function(event) on_mined_charger(event.entity) end)
  .register(defines.events.on_robot_pre_mined, function(event) on_mined_charger(event.entity) end)

-- TODO: these two should really be... moved upwards.
Event.register(defines.events.on_player_rotated_entity, function(event)
  if event.entity.name == "charge_transmission-charger_interface" then
    on_player_rotated_charger(event.entity, game.players[event.player_index])
  end
end)

Event.register(defines.events.on_selected_entity_changed, function(event)
  local player = game.players[event.player_index]
  local current_entity = player.selected
  if current_entity and current_entity.name == "charge_transmission-charger_interface" then
    local charger_entity = current_entity.surface.find_entity("charge_transmission-charger", current_entity.position)
    local charger = (charger_entity and chargers[charger_entity.unit_number]) or nil

    if charger and charger.target and charger.target.valid then
      -- player.update_selected_entity(data.cell.owner.position)
      player.set_gui_arrow{type="entity", entity=charger.target.owner}
    end
  elseif event.last_entity and event.last_entity.name == "charge_transmission-charger" then
    player.clear_gui_arrow()
  end
end)

script.on_event(defines.events.on_tick, on_tick)


--[[ MOD INIT/LOAD ]]

local migration_scripts = require("control.migrations")

local function init_global()
  global.nodes = global.nodes or {}
  global.chargers = global.chargers or {}
  global.new_nodes = global.new_nodes or {}
  global.active_nodes = global.active_nodes or {}
  global.free_chargers = global.free_chargers or {}
  global.counters = global.counters or {
    next_node = nil,
    next_charger = nil,
    nodes = 0
  }

  global.changed = global.changed or {}
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
  chargers = global.chargers
  active_nodes = global.active_nodes
  free_chargers = global.free_chargers
  counters = global.counters
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

script.on_configuration_changed(function(event)
  if event.mod_changes["ChargeTransmission"] then
    if not global.changed then global.changed = {} end
    for _, ver in pairs(MOD.migrations) do
      if not global.changed[ver] and migration_scripts[ver](event) then
        global.changed[ver] = true
      end
    end
  end
end)
