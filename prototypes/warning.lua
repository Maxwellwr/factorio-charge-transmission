local warning = {
  type = "simple-entity",
  name = "charge_transmission-warning",
  render_layer = "entity-info-icon",
  icon = "__ChargeTransmission__/graphics/overtaxed-icon.png",
  icon_size = 32,
  flags = {"not-on-map", "placeable-off-grid"},
  selectable_in_game = false,
  collision_mask = {},
  collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},

  animations = {{
    priority = "extra-high-no-scale",
    line_length = 2,
    frame_count = 2,
    width = 64,
    height = 64,
    filename = "__ChargeTransmission__/graphics/overtaxed.png",
    scale = 0.5,
    animation_speed = 1/30,
    flags = { "icon" },
  }}
}

local warning_signal = {
  type = "item",
  name = "charge_transmission-warning",
  icon = "__ChargeTransmission__/graphics/overtaxed-icon.png",
  icon_size = 64,
  flags = {"hidden"},
  stack_size = 1,
  -- hidden = true
}

data:extend{warning, warning_signal}