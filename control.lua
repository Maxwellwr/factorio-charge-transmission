MOD = {}
MOD.name = "ChargeTransmission"
MOD.if_name = "charge-transmission"
MOD.interfaces = {}
MOD.commands = {}
MOD.config = require("config")

local Position = require "stdlib/area/position"
-- local Area = require "stdlib/area/area"
-- local Surface = require "stdlib/surface"
-- local Entity = require "stdlib/entity/entity"
require "stdlib/event/event"
-- require "stdlib/table"

-- Enables Debug mode for new saves
if MOD.config.DEBUG then
  log(MOD.name .. " Debug mode enabled")
  require("stdlib/debug/quickstart")
end

local chargers, nodes, new_chargers, new_nodes, counters, bot_max

-- returns the node serving this cell
-- even if the node is enqueued to be added (in new_nodes)
local function get_node(cell)
  if not(cell and cell.valid) then return end
  return nodes[cell.owner.unit_number] or new_nodes[cell.owner.unit_number]
end

-- gets the closest cell to position
-- we don't just return LuaLogisticNetwork.find_cell_closest_to() because we give priority to cells being served by nodes
local function get_closest_cell(position, network)
  local closest_cell = network.find_cell_closest_to(position)

  -- short-circuit if there's no cell close to (how?) or if it is already a node (score)
  if not closest_cell or get_node(closest_cell) then return closest_cell end

  -- so the closest cell is either a node or the one already in closest_cells
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

-- adds a cell as a charger's target (and hence pairs it with any respective node)
local function target_cell(charger, cell)
  charger.target = cell
  charger.target_id = cell.owner.unit_number

  -- make the display point at the cell's owner
  update_display(charger)

  local node = get_node(cell)
  if node then
    node.chargers[charger.id] = charger

  else
    -- new node
    new_nodes[charger.target_id] = {
      cell = cell,
      chargers = {charger},
      id = cell.owner.unit_number
    }

    print("new node "..new_nodes[charger.target_id].id.." with charger "..charger.id)
  end
end

local function enqueue_charger(charger)
  new_chargers[charger.id] = charger
  print("enqueued charger "..charger.id)
end

-- Removes a charger from a node, if it's there (complexity for debug purposes)
-- requeue: if true adds the charger to the unpaired list
local function unpair_charger(charger, requeue)
  local node = get_node(charger.target)
  if node then
    node.chargers[charger.id] = nil
    print("removed charger "..charger.id.." from node "..node.id)
    charger.target = nil
  end
  if charger.display and charger.display.valid then charger.display.graphics_variation = 1 end

  if requeue then enqueue_charger(charger) end
end


-- return: true if a pair node was found
local function pair_charger(charger)
  -- ignore already those with targets
  if charger.target then return end

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
  if entity.name == "charge_transmission-charger-base" then
    local charger = {
      base = entity,
      id = entity.unit_number
    }
    chargers[charger.id] = charger

    charger.interface = entity.surface.create_entity {
      name = "charge_transmission-charger-interface",
      position = entity.position,
      force = entity.force
    }
    charger.interface.destructible = false

    charger.display = entity.surface.create_entity {
      name = "charge_transmission-charger-display",
      position = entity.position,
      force = entity.force
    }
    charger.display.destructible = false
    charger.display.graphics_variation = 1 -- none

    charger.warning = entity.surface.create_entity {
      name = "charge_transmission-charger-warning",
      position = entity.position,
    }
    charger.warning.destructible = false
    charger.warning.graphics_variation = 1

    -- fixes any overlay issues (not needed any more but it doesn't hurt)
    entity.teleport(entity.position)

    if not pair_charger(charger) then enqueue_charger(charger) end
  end
end

local function on_mined_charger(entity)
  if entity.name:find("charge_transmission%-charger") then
    if entity.name == "charge_transmission-charger-base" then
      local charger = chargers[entity.unit_number]
      if not charger then
        log "Attempted to remove already-dismantled charger"

        -- TODO: making sure the area is *really* clean
        return
      end

      unpair_charger(charger)

      -- remove composite partners
      for _, component in pairs({charger.interface, charger.display, charger.warning}) do
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
  local charger_entity = interface.surface.find_entity("charge_transmission-charger-base", interface.position)
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
  unpair_charger(charger)
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
    if event.moved_entity.name ~= "charge_transmission-charger-base" then
      -- nuh huh, only the base can teleport, put that thing back where it came from, or so help me!
      event.moved_entity.teleport(event.start_pos)
    else
      -- move the rest of the composed entity
      local charger = chargers[event.moved_entity.unit_number]

      for _, component in pairs({charger.interface, charger.display, charger.warning}) do
        if component and component.valid then
          component.teleport(event.moved_entity.position)
        end
      end

      print("teleported charger "..charger.id)

      -- check if connected roboport is still within range
      if charger.target and not charger.target.is_in_logistic_range(event.moved_entity.position) then
        unpair_charger(charger, true)
        print("unpaired charger "..charger.id.." because out of reach")
      end
    end
  end
end


Event.register(defines.events.on_built_entity, function(event) on_built_charger(event.created_entity) end)
  .register(defines.events.on_robot_built_entity, function(event) on_built_charger(event.created_entity) end)

-- TODO: the function is kind of a misnomer now, isn't it
Event.register(defines.events.on_entity_died, function(event) on_mined_charger(event.entity) end)
  .register(defines.events.on_preplayer_mined_item, function(event) on_mined_charger(event.entity) end)
  .register(defines.events.on_robot_pre_mined, function(event) on_mined_charger(event.entity) end)

Event.register(defines.events.on_player_rotated_entity, function(event)
  if event.entity.name == "charge_transmission-charger-interface" then
    on_player_rotated_charger(event.entity, game.players[event.player_index])
  end
end)

Event.register(defines.events.on_selected_entity_changed, function(event)
  local player = game.players[event.player_index]
  local current_entity = player.selected
  if current_entity and current_entity.name == "charge_transmission-charger-interface" then
    local charger_entity = current_entity.surface.find_entity("charge_transmission-charger-base", current_entity.position)
    local charger = (charger_entity and chargers[charger_entity.unit_number]) or nil

    if charger and charger.target and charger.target.valid then
      -- player.update_selected_entity(data.cell.owner.position)
      player.set_gui_arrow{type="entity", entity=charger.target.owner}
    end
  elseif event.last_entity and event.last_entity.name:match("charge_transmission%-charger") then
    player.clear_gui_arrow()
  end
end)

--[[ ON_TICK ]]

local function get_charger_consumption(charger)
  -- returns the consumption bonus/penalty from the charger
  if not settings.startup["charge_transmission-use-modules"].value then
    return 1.5
  end

  -- split the energetic debt along time
  -- add module effect
  local consumption = 1
  local effectivity = charger.base.prototype.distribution_effectivity
  local modules = charger.base.get_module_inventory()
  for i=1,#modules do
    if modules[i] and modules[i].valid_for_read and modules[i].prototype.module_effects.consumption then
      consumption = consumption + modules[i].prototype.module_effects.consumption.bonus * effectivity
    end
  end
  -- print("loss: "..consumption)

  -- 300% max over 60 ticks (factor the 3 out)
  return math.max(0.2, consumption) * 3
  -- charger.antenna.power_usage = cost * math.max(0.2, consumption) / 20
  -- print("cost: "..antenna.power_usage)
end

-- TODO: Optimize this, make it squeaky clean
-- *  code check
-- *  add more .valid checks
script.on_event(defines.events.on_tick, function(event)
  -- charger re-pairing
  if not new_chargers[counters.next_charger] then counters.next_charger = nil end
  local next_charger
  counters.next_charger, next_charger = next(new_chargers, counters.next_charger)

  if next_charger then
    if next_charger.base.valid then
      if pair_charger(next_charger) then
        new_chargers[next_charger.id] = nil
      end
    else
      new_chargers[next_charger.id] = nil
    end
  end

  -- before iterating nodes...
  if event.tick%60 == 0 then
    -- register new nodes
    for key, node in pairs(new_nodes) do
      if nodes[key] then
        -- if the node is already there, move the chargers into it
        table.merge(nodes[key].chargers, node.chargers)
        for cid, _ in pairs(node.chargers) do
          print("joined charger "..cid.." into node "..node.id)
        end
      else
        nodes[key] = node
        print("activated node "..node.id)
      end
      new_nodes[key] = nil
    end

    -- -- clean new nodes list
    -- global.new_nodes = {}
    -- new_nodes = global.new_nodes

    -- seed the next iter
    counters.node_count = table_size(nodes)
    counters.next_node = next(nodes)
  end

  -- area scanning
  -- TODO: add +1 so it always does the non-tick one
  local iter = 0
  local count = counters.node_count
  local max
  -- log(counters.done_nodes)
  -- print((5-counters.nodes%5)%5)
  if event.tick%60 == 59 then max = math.huge -- Damage control, does ALL remaining nodes in the end until you nil
  elseif event.tick%60 < count%60 then max = math.ceil(count/60) -- separates the nodes over 60 seconds
  else max = math.floor(count/60) end
  -- max = math.ceil(counters.nodes/5)
  -- print(counters.nid)

  while counters.next_node and iter < max do
    local node = nodes[counters.next_node]
    iter = iter + 1
    -- print(event.tick..": processing node "..node.id.." | "..iter.." of "..max.." in "..counters.nodes.." (== "..table_size(nodes)..")")

    if node and node.cell.valid and next(node.chargers) then
      -- calculate total available energy
      local n_chargers = 0
      local energy = 0
      local cost = 0

      -- retrieve active/useful chargers and total energy buffer
      for key, charger in pairs(node.chargers) do
        if charger.base.valid then
          charger.interface.power_usage = 0
          -- TODO: energy_usage is a constant, refactor away
          if charger.base.energy >= charger.base.prototype.energy_usage then
            charger.consumption = get_charger_consumption(charger)
            energy = energy + charger.interface.energy * 30 / charger.consumption
            n_chargers = n_chargers + 1
          else
            -- Reset out of overtaxed (because it's the base that is dying, not the antenna)
            charger.warning.graphics_variation = 1
          end
        else
          node.chargers[key] = nil
          print("cleaned invalid charger "..key.." (== "..charger.id..") from node "..node.id)
        end
      end

      if n_chargers > 0 then
        -- check total energy cost
        -- local bots = 0
        local constrobots, logibots
        local area = Position.expand_to_area(node.cell.owner.position, math.max(node.cell.logistic_radius, node.cell.construction_radius))
        constrobots = node.cell.owner.surface.find_entities_filtered {
          area = area,
          force = node.cell.owner.force,
          type = "construction-robot"
        }
        logibots = node.cell.owner.surface.find_entities_filtered {
          area = area,
          force = node.cell.owner.force,
          type = "logistic-robot"
        }

        if #constrobots + #logibots > 0 then
          local limits = {}
          local modifier = 1 + node.cell.owner.force.worker_robots_battery_modifier
          for key, max_energy in pairs(bot_max) do
            limits[key] = max_energy * modifier
          end

          for id = 1, #constrobots do
            local bot = constrobots[id]
            local max_energy = limits[bot.name]

            if bot and bot.valid and bot.energy < max_energy then
              cost = cost + max_energy - bot.energy
              bot.energy = max_energy
              if cost >= energy then break end
            end
          end

          for id = 1, #logibots do
            local bot = logibots[id]
            local max_energy = limits[bot.name]

            if bot and bot.valid and bot.energy < max_energy then
              cost = cost + max_energy - bot.energy
              bot.energy = max_energy
              if cost >= energy then break end
            end
          end

          -- split the energetic debt between the chargers and time
          -- debt = cost / (60 * n_chargers)
        end
        -- print("debt: "..debt..", cost: "..cost..", energy: "..energy..", bots: "..bots)
      end

      -- set power cost on the interfaces
      -- TODO: there's two constants down there, we should cache them!
      for _, charger in pairs(node.chargers) do
        if charger.base.energy >= charger.base.prototype.energy_usage then
          local fraction = (charger.interface.energy * 30 / charger.consumption) / energy
          local debt = cost * fraction / 60
          charger.interface.power_usage = debt * charger.consumption

          -- local simplified = (cost * charger.interface.energy) / (2 * energy)
          -- print(simplified.." ==? "..charger.interface.power_usage)

          -- state machine:
          --   1: neutral, don't display
          --   2: active, don't display
          --   3: active, display (toggled below)
          -- 1->2, 2/3->1
          if cost > energy or charger.interface.power_usage > charger.interface.electric_input_flow_limit then
            -- log(cost..">"..energy.." : "..debt..">"..charger.interface.electric_input_flow_limit)
            if charger.warning.graphics_variation == 1 then
              charger.warning.graphics_variation = 2
            end
          else
            charger.warning.graphics_variation = 1
          end
        end
      end

    elseif node then
      -- node is invalid (either cell is dead or no chargers)
      -- remove node, orphan chargers
      for _, charger in pairs(node.chargers) do unpair_charger(charger, true) end
      nodes[node.id] = nil
      -- counters.nodes = counters.nodes - 1
      print("removed node "..node.id)
    end

    counters.next_node = next(nodes, counters.next_node)
    -- print("next node: "..serpent.block(counters.nid))
  end

  -- displays the blinking custom warning for overtaxing
  if event.tick%30 == 0 then
    for _, n in pairs(nodes) do
      for _, charger in pairs(n.chargers) do
        local warning = charger.warning
        if warning and warning.valid and warning.graphics_variation ~= 1 then
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


--[[ MOD INIT/LOAD ]]

local migration_scripts = require("scripts.migrations")

-- Automatically blacklists chargeless robots (Creative Mode, Nuclear/Fusion Bots, ...)
local function is_chargeable_bot(prototype)
  -- Creative Mode; Nuclear Robots; Jamozed's Fusion Robots
  return (prototype.energy_per_tick > 0 or prototype.energy_per_move > 0) and prototype.speed_multiplier_when_out_of_energy < 1
end

local function get_bots_info()
  local max_energy = {}

  for _, prototype in pairs(game.entity_prototypes) do
    if prototype.type == "logistic-robot" or prototype.type == "construction-robot" then
      max_energy[prototype.name] = (is_chargeable_bot(prototype) and prototype.max_energy) or 0

      -- if is_chargeable_bot(prototype) then
      --   max_energies[prototype.name] = prototype.max_energy
      -- end
    end
  end

  log(serpent.block(max_energy))

  return max_energy
end

local function init_global()
  global.nodes = global.nodes or {}
  global.chargers = global.chargers or {}
  global.new_nodes = global.new_nodes or {}
  global.new_chargers = global.new_chargers or {}
  global.counters = global.counters or {
    next_node = nil,
    next_charger = nil,
    nodes = 0
  }
  global.bot_max = get_bots_info()

  -- global.next_node = global.next_node or nil
  -- global.next_charger = global.next_charger or nil
  -- global.node_count = global.node_count or 0

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
  new_nodes = global.new_nodes
  new_chargers = global.new_chargers
  counters = global.counters
  bot_max = global.bot_max
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
  global.bot_max = get_bots_info()
  bot_max = global.bot_max

  if event.mod_changes["ChargeTransmission"] then
    if not global.changed then global.changed = {} end
    for _, ver in pairs(MOD.migrations) do
      if not global.changed[ver] and migration_scripts[ver](event) then
        global.changed[ver] = true
      end
    end
  end
end)
