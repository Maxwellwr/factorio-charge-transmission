--[[
Bot charger: Recharges bots on the closest roboport's area coverage
--]]

local Color = require "stdlib/color/color"
local Prototype = require "libs/prototype"

local icon = {{icon = "__base__/graphics/icons/beacon.png", tint = Color.from_hex("#00bbee")}}

local function base_rotations()
  local pictures = {}
  for i=0,23 do
    pictures[i+1] = {
      filename = "__ChargeTransmission__/graphics/entities/bot-charger/connection.png",
      width = 128,
      height = 128,
      x=i%6 * 128,
      y=math.floor(i/6) * 128,
      shift = util.by_pixel(0, 8)
    }
  end
  table.insert(pictures, {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
  })
  return pictures
end

-- TODO: Rename to connection/cable
local entity_powerbox = {
  type = "electric-energy-interface",
  name = "charge-transmission-charger-powerbox",
  icons = icon,
  flags = {"not-on-map"},
  render_layer = "remnants",
  collision_mask = {},
  collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
  selection_box = {{-1, -1}, {1, 0}},
  drawing_box = {{-2, -2}, {2, 2}},
  selectable_in_game = false,
  picture = Prototype.empty_sprite(),
  enable_gui = true,
  allow_copy_paste = false,
  energy_source = {
    type = "electric",
    buffer_capacity = "50MJ",
    usage_priority = "secondary-input",
    input_flow_limit = "20MW",
    output_flow_limit = "0W",
    drain = "200kW",
  },
  energy_production = "0W",
  energy_usage = "0W",
}

local entity = {
  type = "roboport",
  name = "charge-transmission-charger",
  icons = icon,
  flags = {"placeable-player", "player-creation"},
  minable = {mining_time = 1, result = "charge-transmission-charger"},
  max_health = 200,
  corpse = "medium-remnants",
  dying_explosion = "medium-explosion",
  collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
  selection_box = {{-1, 0}, {1, 1}},
  drawing_box = {{-1, -1.5}, {1, 0.5}},
  enable_gui = true,
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    input_flow_limit = "1MW",
    buffer_capacity = "1MJ"
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

  draw_logistic_radius_visualization = true,
  draw_construction_radius_visualization = true,

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
  circuit_wire_max_distance = 9,
  default_available_logistic_output_signal = {type = "virtual", name = "signal-X"},
  default_total_logistic_output_signal = {type = "virtual", name = "signal-Y"},
  default_available_construction_output_signal = {type = "virtual", name = "signal-Z"},
  default_total_construction_output_signal = {type = "virtual", name = "signal-T"},

  vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
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
  icons = icon,
  flags = {"goes-to-quickbar"},
  subgroup = "module",
  order = "a[beacon]",
  place_result = "charge-transmission-charger",
  stack_size = 10
}

local recipe = {
  type = "recipe",
  name = "charge-transmission-charger",
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
  name = "charge-transmission",
  icon = "__base__/graphics/technology/effect-transmission.png",
  effects =
  {
    {
      type = "unlock-recipe",
      recipe = "charge-transmission-charger"
    }
  },
  prerequisites = {"effect-transmission", "robotics"},
  unit =
  {
    count = 125,
    ingredients =
    {
      {"science-pack-1", 1},
      {"science-pack-2", 1},
      {"science-pack-3", 1},
      {"high-tech-science-pack", 2}
    },
    time = 30
  },
  order = "i-i"
}

data:extend{entity_powerbox, entity, item, recipe, technology}