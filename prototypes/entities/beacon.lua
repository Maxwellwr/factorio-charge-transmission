local Colours = require "libs/colour"

local entity = {
  type = "beacon",
  name = "charge-transmission-beacon",
  icon = "__base__/graphics/icons/beacon.png",
  flags = {"placeable-player", "player-creation"},
  minable = {mining_time = 1, result = "beacon"},
  max_health = 200,
  corpse = "big-remnants",
  dying_explosion = "medium-explosion",
  collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
  selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
  allowed_effects = {"consumption", "speed", "pollution"},
  base_picture =
  {
    filename = "__base__/graphics/entity/beacon/beacon-base.png",
    width = 116,
    height = 93,
    shift = { 0.34375, 0.046875}
  },
  animation =
  {
    filename = "__base__/graphics/entity/beacon/beacon-antenna.png",
    width = 54,
    height = 50,
    line_length = 8,
    frame_count = 32,
    shift = { -0.03125, -1.71875},
    tint = Colours.fromHex("#00ffff"),
    animation_speed = 0.5
  },
  animation_shadow =
  {
    filename = "__base__/graphics/entity/beacon/beacon-antenna-shadow.png",
    width = 63,
    height = 49,
    line_length = 8,
    frame_count = 32,
    shift = { 3.140625, 0.484375},
    animation_speed = 0.5
  },
  radius_visualisation_picture =
  {
    filename = "__base__/graphics/entity/beacon/beacon-radius-visualization.png",
    tint = Colours.fromHex("#00ffff"),
    width = 10,
    height = 10
  },
  supply_area_distance = 3,
  energy_source =
  {
    type = "electric",
    usage_priority = "secondary-input"
  },
  vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
  energy_usage = "480kW",
  distribution_effectivity = 0.5,
  module_specification =
  {
    module_slots = 2,
    module_info_icon_shift = {0, 0.5},
    module_info_multi_row_initial_height_modifier = -0.3
  }
}

local item = {
  type = "item",
  name = "charge-transmission-beacon",
  icons = {{icon = "__base__/graphics/icons/beacon.png", tint = Colours.fromHex("#00ffff")}},
  flags = {"goes-to-quickbar"},
  subgroup = "module",
  order = "a[beacon]",
  place_result = "charge-transmission-beacon",
  stack_size = 10
}

local recipe = {
  type = "recipe",
  name = "charge-transmission-beacon",
  enabled = false,
  energy_required = 15,
  ingredients =
  {
    {"beacon", 1},
    {"substation", 1},
    {"battery", 10},
    {"processing-unit", 20},
    {"copper-cable", 20}
  },
  result = "charge-transmission-beacon"
}

local technology = {
    type = "technology",
    name = "charge-transmission-beacon",
    icon = "__base__/graphics/technology/effect-transmission.png",
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "charge-transmission-beacon"
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

  data:extend{entity, item, recipe, technology}