require "prototypes/entities/charger-bots"

local technology = {
  type = "technology",
  name = "charge-transmission_charger",
  icon = "__ChargeTransmission__/graphics/entities/charger/technology.png",
  icon_size = 128,
  effects =
  {
    {
      type = "unlock-recipe",
      recipe = "charge-transmission_bots"
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
      {"high-tech-science-pack", 1}
    },
    time = 30
  },
  order = "i-i"
}

data:extend{technology}