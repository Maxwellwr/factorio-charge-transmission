local Colours = require "libs/colour"

local icon = {{icon = "__base__/graphics/icons/beacon.png", tint = Colours.fromHex("#00bbee")}}

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
local entity_base = {
  type = "simple-entity",
  name = "charge-transmission-bot-charger-base",
  icons = icon,
  flags = {"not-on-map"},
  render_layer = "remnants",
  collision_mask = {},
  collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
  selection_box = {{-1, -1}, {1, 1}},
  drawing_box = {{-2, -2}, {2, 2}},
  selectable_in_game = false,
  pictures = base_rotations()
}

local entity = {
  type = "electric-energy-interface",
  name = "charge-transmission-bot-charger",
  icons = icon,
  flags = {"placeable-player", "player-creation"},
  minable = {mining_time = 1, result = "charge-transmission-bot-charger"},
  max_health = 200,
  corpse = "medium-remnants",
  dying_explosion = "medium-explosion",
  collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
  selection_box = {{-1, -1}, {1, 1}},
  drawing_box = {{-1, -1.5}, {1, 0.5}},
  enable_gui = true,
  allow_copy_paste = false,
  animation = {
    layers = {{
      filename = "__ChargeTransmission__/graphics/entities/bot-charger/base.png",
      width = 64,
      height = 64,
      line_length = 8,
      frame_count = 32,
      shift = util.by_pixel(0, 8),
      animation_speed = 0.5,
    },{
      filename = "__base__/graphics/entity/beacon/beacon-antenna.png",
      width = 54,
      height = 50,
      line_length = 8,
      frame_count = 32,
      -- shift = { -0.03125, -1.71875},
      shift = util.by_pixel(-1,-55+32+4),
      tint = Colours.fromHex("#00bbee"),
      animation_speed = 0.5
    },{
      filename = "__base__/graphics/entity/beacon/beacon-antenna-shadow.png",
      width = 63,
      height = 49,
      line_length = 8,
      frame_count = 32,
      -- shift = { 3.140625, 0.484375},
      shift = { -0.03125, -1.71875},
      animation_speed = 0.5,
      draw_as_shadow = true
    },}
  },
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
  vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
  working_sound =
    {
      sound =
      {
        filename = "__base__/sound/accumulator-working.ogg",
        volume = 0.4
      },
      idle_sound =
      {
        filename = "__base__/sound/accumulator-idle.ogg",
        volume = 0.2
      },
      max_sounds_per_type = 5
    }
}

local item = {
  type = "item",
  name = "charge-transmission-bot-charger",
  icons = icon,
  flags = {"goes-to-quickbar"},
  subgroup = "module",
  order = "a[beacon]",
  place_result = "charge-transmission-bot-charger",
  stack_size = 10
}

local recipe = {
  type = "recipe",
  name = "charge-transmission-bot-charger",
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
  result = "charge-transmission-bot-charger"
}

local technology = {
  type = "technology",
  name = "charge-transmission",
  icon = "__base__/graphics/technology/effect-transmission.png",
  effects =
  {
    {
      type = "unlock-recipe",
      recipe = "charge-transmission-bot-charger"
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

data:extend{entity_base, entity, item, recipe, technology}