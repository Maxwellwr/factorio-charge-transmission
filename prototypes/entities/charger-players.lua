--[[
Player charger: Recharges players on logistic network it's inserted into
--]]

local Color = require "stdlib/color/color"
local Prototype = require "stdlib/prototype/prototype"

local icon = {{icon = "__base__/graphics/icons/beacon.png", tint = Color.from_hex("#00eebb")}}

local entity_transmitter = {
  type = "electric-energy-interface",
  name = "charge-transmission_players-transmitter",
  icons = table.deepcopy(icon),
  flags = {"player-creation", "not-on-map"},
  render_layer = "higher-object-above",
  collision_mask = {},
  collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
  selection_box = {{-0.5, -1}, {0.5, 0}},
  selection_priority = 200,
  selectable_in_game = true,
  animation = {
    filename = "__base__/graphics/entity/beacon/beacon-antenna.png",
    width = 54,
    height = 50,
    line_length = 8,
    frame_count = 32,
    shift = util.by_pixel(-1,-55+32+4),
    tint = Color.from_hex("#00eebb"),
    animation_speed = 0.5
  },
  enable_gui = false,
  allow_copy_paste = false,
  energy_source = {
    type = "electric",
    buffer_capacity = "200MJ",
    usage_priority = "secondary-input",
    input_flow_limit = "48MW",
    output_flow_limit = "0W",
    drain = "0W",
  },
  energy_production = "0W",
  energy_usage = "0W",
}

-- TODO: clean this even more, there's a few unecessary fields that aren't simplified
local entity_interface = {
  rotate = true,
  type = "roboport",
  name = "charge-transmission_players-interface",
  -- TODO: better icon for the interface?
  icons = table.deepcopy(icon),
  flags = {"placeable-player", "player-creation"},
  corpse = "medium-remnants",
  minable = {hardness = 0.2, mining_time = 0.5, result = "charge-transmission_players"},
  collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
  selection_box = {{-1, -1}, {1, 1}},
  drawing_box = {{-1, -1.5}, {1, 0.5}},
  dying_explosion = "medium-explosion",
  resistances = {{
    type = "fire",
    percent = 60
  },{
    type = "impact",
    percent = 30
  }},
  max_health = 200,
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    input_flow_limit = "8MW",
    buffer_capacity = "4MJ",
  },
  recharge_minimum = "612kJ",
  energy_usage = "612kW",
  -- per one charge slot
  charging_energy = "0kW",
  logistics_radius = 20,
  construction_radius = 20,
  charge_approach_distance = 0,
  robot_slots_count = 0,
  material_slots_count = 0,
  stationing_offset = {0, 0},
  charging_offsets = {},
  -- TODO: Better base graphics, yes.
  base = {
    filename = "__ChargeTransmission__/graphics/entities/charger/base.png",
    width = 64,
    height = 64,
    shift = util.by_pixel(0, 8),
  },
  base_patch = Prototype.empty_sprite(),
  base_animation = Prototype.empty_animation(),
  door_animation_up = Prototype.empty_animation(),
  door_animation_down = Prototype.empty_animation(),
  recharging_animation = Prototype.empty_animation(),

  recharging_light = {intensity = 0.4, size = 5, color = {r = 1.0, g = 1.0, b = 1.0}},
  request_to_open_door_timeout = 15,
  spawn_and_station_height = -0.1,

  draw_logistic_radius_visualization = true,
  draw_construction_radius_visualization = false,

  open_door_trigger_effect = {{
    type = "play-sound",
    sound = { filename = "__base__/sound/roboport-door.ogg", volume = 1.2 }
  }},
  close_door_trigger_effect = {{
    type = "play-sound",
    sound = { filename = "__base__/sound/roboport-door.ogg", volume = 0.75 }
  }},
  circuit_wire_connection_point = {
    shadow = {
      red = {1.17188, 1.98438},
      green = {1.04688, 2.04688}
    },
    wire = {
      red = {0.78125, 1.375},
      green = {0.78125, 1.53125}
    }
  },
  circuit_connector_sprites = get_circuit_connector_sprites({0.59375, 1.3125}, nil, 18),
  circuit_wire_max_distance = 0,
  default_available_logistic_output_signal = {type = "virtual", name = "signal-X"},
  default_total_logistic_output_signal = {type = "virtual", name = "signal-Y"},
  default_available_construction_output_signal = {type = "virtual", name = "signal-Z"},
  default_total_construction_output_signal = {type = "virtual", name = "signal-T"},

  vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
}

local item = {
  type = "item",
  name = "charge-transmission_players",
  localized_name = {"item-name.charge-transmission_players"},
  icons = table.deepcopy(icon),
  flags = {"goes-to-quickbar"},
  subgroup = "logistic-network",
  order = "c[signal]-a[roboport]",
  place_result = "charge-transmission_players-interface",
  stack_size = 20
}

local recipe = {
  type = "recipe",
  name = "charge-transmission_players",
  localized_name = {"item-name.charge-transmission_players"},
  enabled = false,
  energy_required = 15,
  ingredients =
  {
    {"beacon", 1},
    {"radar", 2},
    {"processing-unit", 10},
    {"battery", 20},
  },
  result = "charge-transmission_players"
}

data:extend{entity_transmitter, entity_interface, item, recipe}