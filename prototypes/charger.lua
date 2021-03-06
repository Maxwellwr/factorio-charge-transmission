--[[
Bot charger: Recharges bots on the closest roboport area coverage
--]]

-- local Colour = require "stdlib/color/color"
local Prototype = require "stdlib/prototype/prototype"

local icon = {{icon = "__base__/graphics/icons/beacon.png", tint = util.color "00bbee7f"}}

local entity_interface = {
  type = "electric-energy-interface",
  name = "charge_transmission-charger_interface",
  icon = "__ChargeTransmission__/graphics/entities/charger/transmitter-icon.png",
  icon_size = 32,
  flags = {"player-creation", "not-on-map"},
  collision_mask = {},
  collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
  selection_box = {
    util.by_pixel(9, 3), util.by_pixel(31, 25)
    -- {0.375, 0.375}, {0.875, 0.875}
  },
  selection_priority = 200,
  selectable_in_game = true,

  energy_source = {
    type = "electric",
    buffer_capacity = "25MJ",
    usage_priority = "secondary-input",
    input_flow_limit = "10MW",
    output_flow_limit = "0W",
    drain = "612kW",
  },
  energy_production = "0W",
  energy_usage = "0W",

  enable_gui = false,
  allow_copy_paste = false,

  picture = Prototype.empty_sprite()
}

local entity_display = {
  type = "simple-entity",
  name = "charge_transmission-charger_display",
  icon = "__ChargeTransmission__/graphics/entities/charger/transmitter-icon.png",
  icon_size = 32,
  flags = {"not-on-map"},
  selectable_in_game = false,
  collision_mask = {},
  collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
  selection_box = {{-0.8, -0.8}, {0.8, 0.8}},
  pictures = {Prototype.empty_sprite()}
}

for i=1,9 do
  table.insert(entity_display.pictures, {
    filename = "__ChargeTransmission__/graphics/entities/charger/base-interface.png",
    width = 14,
    height = 14,
    x = (i-1) * 14,
    shift = util.by_pixel(20, 14),
    hr_version = {
      filename = "__ChargeTransmission__/graphics/entities/charger/hr/base-interface.png",
      width = 28,
      height = 28,
      x = (i-1) * 28,
      scale = 0.5,
      shift = util.by_pixel(20, 14),
    }
  })
end

-- TODO: clean this even more, there's a few unnecessary fields that aren't simplified
local entity_base = {
  type = "beacon",
  name = "charge_transmission-charger",
  -- TODO: better icon for the interface?
  icons = table.deepcopy(icon),
  icon_size = 32,
  flags = {"placeable-player", "player-creation"},
  minable = {mining_time = 1, result = "charge_transmission-charger"},
  collision_box = {{-0.9, -0.4}, {0.9, 0.8}},
  selection_box = {{-1, -1}, {1, 1}},
  sticker_box = {{-0.3, -0.5}, {0.3, 0.1}},

  max_health = 200,
  corpse = "medium-remnants",
  dying_explosion = "medium-explosion",
  resistances = {{
    type = "fire",
    percent = 60
  },{
    type = "impact",
    percent = 30
  }},

  energy_source = {
    type = "electric",
    usage_priority = "primary-input",
    -- input_flow_limit = "4MW",
    -- buffer_capacity = "2MJ",
    render_no_power_icon = false
  },
  energy_usage = "0kW",

  allowed_effects = {"consumption"},
  supply_area_distance = 0,
  distribution_effectivity = 0.5,
  module_specification = {
    module_slots = 2,
    module_info_icon_shift = {-0.25, 0.25},
    -- module_info_multi_row_initial_height_modifier = 0.3
  },

  -- TODO: Better base graphics, yes.
  base_picture = {
    filename = "__ChargeTransmission__/graphics/entities/charger/base.png",
    width = 58,
    height = 65,
    shift = util.by_pixel(1, -8.5),
    hr_version = {
      filename = "__ChargeTransmission__/graphics/entities/charger/hr/base.png",
      width = 116,
      height = 130,
      shift = util.by_pixel(1, -8.5),
      scale = 0.5
    }
  },
  animation = {
    filename = "__ChargeTransmission__/graphics/entities/charger/base-animation.png",
    width = 24,
    height = 24,
    line_length = 6,
    frame_count = 6,
    shift = util.by_pixel(-12, -4),
    animation_speed = 0.05,
    hr_version = {
      filename = "__ChargeTransmission__/graphics/entities/charger/hr/base-animation.png",
      width = 48,
      height = 48,
      line_length = 6,
      frame_count = 6,
      shift = util.by_pixel(-12, -4),
      animation_speed = 0.05,
      scale = 0.5
    }
  },
  -- animation_shadow = table.deepcopy(data.raw.beacon.beacon.animation_shadow),
  radius_visualisation_picture = Prototype.empty_sprite(),

  vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
}

entity_base.animation_shadow = table.deepcopy(entity_base.animation)

local item = {
  type = "item",
  name = "charge_transmission-charger",
  icon = "__ChargeTransmission__/graphics/entities/charger/transmitter-icon.png",
  icon_size = 32,
  flags = {"goes-to-quickbar"},
  subgroup = "logistic-network",
  order = "c[signal]-a[roboport]",
  place_result = "charge_transmission-charger",
  stack_size = 20
}

local recipe = {
  type = "recipe",
  name = "charge_transmission-charger",
  enabled = false,
  energy_required = 15,
  ingredients =
  {
    {"beacon", 1},
    {"radar", 2},
    {"processing-unit", 10},
    {"battery", 20},
  },
  result = "charge_transmission-charger"
}

local technology = {
  type = "technology",
  name = "charge_transmission-charger",
  icon = "__ChargeTransmission__/graphics/entities/charger/technology.png",
  icon_size = 128,
  effects =
  {
    {
      type = "unlock-recipe",
      recipe = "charge_transmission-charger"
    }
  },
  prerequisites = {"effect-transmission", "robotics", "effectivity-module-3"},
  unit =
  {
    count = 250,
    ingredients =
    {
      {"science-pack-1", 1},
      {"science-pack-2", 1},
      {"science-pack-3", 1},
      {"high-tech-science-pack", 1},
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"production-science-pack", 1}
    },
    time = 30
  },
  order = "i-i"
}

data:extend{entity_interface, entity_display, entity_base, item, recipe, technology}
