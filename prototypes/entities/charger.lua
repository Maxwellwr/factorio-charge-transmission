--[[
Bot charger: Recharges bots on the closest roboport's area coverage
--]]

local Color = require "stdlib/color/color"
local Prototype = require "libs/prototype"

local icon = {{icon = "__base__/graphics/icons/beacon.png", tint = Color.from_hex("#00bbee")}}

local entity_transmitter = {
  type = "electric-energy-interface",
  name = "charge-transmission-charger-transmitter",
  icon = "__ChargeTransmission__/graphics/entities/charger/transmitter-icon.png",
  flags = {"player-creation"},
  render_layer = "remnants",
  collision_mask = {},
  collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
  selection_box = {{-0.5, -1}, {0.5, 0}},
  drawing_box = {{0, 0}, {0, 0}},
  selection_priority = 200,
  selectable_in_game = true,
  picture = Prototype.empty_sprite(),
  enable_gui = false,
  allow_copy_paste = false,
  energy_source = {
    type = "electric",
    buffer_capacity = "50MJ",
    usage_priority = "secondary-input",
    input_flow_limit = "10MW",
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
  name = "charge-transmission-charger-interface",
  -- TODO: better icon?
  icons = icon,
  flags = {"not-on-map", "placeable-player", "player-creation"},
  corpse = "medium-remnants",
  minable = {hardness = 0.2, mining_time = 0.5, result = "charge-transmission-charger"},
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
    input_flow_limit = "5MW",
    buffer_capacity = "100MJ",
    drain = "200kW",
  },
  recharge_minimum = "0J",
  energy_usage = "0W",
  -- per one charge slot
  charging_energy = "0W",
  logistics_radius = 0,
  construction_radius = 0,
  charge_approach_distance = 0,
  robot_slots_count = 0,
  material_slots_count = 0,
  stationing_offset = {0, 0},
  charging_offsets = {},
  base = {
    filename = "__ChargeTransmission__/graphics/entities/charger/base.png",
    width = 64,
    height = 64,
    shift = util.by_pixel(0, 8),
  },
  base_patch = Prototype.empty_sprite(),
  base_animation = {
    filename = "__base__/graphics/entity/beacon/beacon-antenna.png",
    width = 54,
    height = 50,
    line_length = 8,
    frame_count = 32,
    -- shift = { -0.03125, -1.71875},
    shift = util.by_pixel(-1,-55+32+4),
    tint = Color.from_hex("#00bbee"),
    animation_speed = 0.5
  },
  door_animation_up = Prototype.empty_animation(),
  door_animation_down = Prototype.empty_animation(),
  recharging_animation = Prototype.empty_animation(),

  recharging_light = {intensity = 0.4, size = 5, color = {r = 1.0, g = 1.0, b = 1.0}},
  request_to_open_door_timeout = 15,
  spawn_and_station_height = -0.1,

  draw_logistic_radius_visualization = false,
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
  -- TODO: Use beacon-like sounds
  working_sound = {
    sound = { filename = "__base__/sound/roboport-working.ogg", volume = 0.6 },
    max_sounds_per_type = 3,
    audible_distance_modifier = 0.5,
    probability = 1 / (5 * 60) -- average pause between the sound is 5 seconds
  },
}

local item = {
  type = "item",
  name = "charge-transmission-charger",
  localized_name = {"item-name.charge-transmission-charger"},
  icon = "__ChargeTransmission__/graphics/entities/charger/transmitter-icon.png",
  flags = {"goes-to-quickbar"},
  subgroup = "logistic-network",
  order = "c[signal]-a[roboport]",
  place_result = "charge-transmission-charger-interface",
  stack_size = 20
}

local recipe = {
  type = "recipe",
  name = "charge-transmission-charger",
  localized_name = {"item-name.charge-transmission-charger"},
  enabled = false,
  energy_required = 15,
  ingredients =
  {
    {"beacon", 1},
    {"radar", 1},
    {"battery", 20},
    {"processing-unit", 20},
    {"copper-cable", 20}
  },
  result = "charge-transmission-charger"
}

local technology = {
  type = "technology",
  name = "charge-transmission-charger",
  icon = "__ChargeTransmission__/graphics/entities/charger/technology.png",
  icon_size = 128,
  effects =
  {
    {
      type = "unlock-recipe",
      recipe = "charge-transmission-charger"
    }
  },
  prerequisites = {"effect-transmission", "robotics", "effectivity-module-2"},
  unit =
  {
    count = 250,
    ingredients =
    {
      {"science-pack-1", 1},
      {"science-pack-2", 1},
      {"science-pack-3", 2},
      {"high-tech-science-pack", 2}
    },
    time = 30
  },
  order = "i-i"
}

data:extend{entity_transmitter, entity_interface, item, recipe, technology}