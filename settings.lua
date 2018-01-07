data:extend {{
  type = "bool-setting",
  name = "charge_transmission-use-modules",
  setting_type = "runtime-global",
  default_value = true,
  order = "charge_transmission-a-a"
},{
  type = "bool-setting",
  name = "charge_transmission-have-beams",
  setting_type = "runtime-global",
  default_value = true,
  order = "charge_transmission-a-b"
},{
  type = "int-setting",
  name = "charge_transmission-robots-per-tick",
  setting_type = "runtime-global",
  default_value = 50,
  minimum_value = 0,
  order = "charge_transmission-b-a"
},{
  type = "int-setting",
  name = "charge_transmission-recharges-per-second",
  setting_type = "runtime-global",
  default_value = 6,
  allowed_values = {1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 60},
  order = "charge_transmission-b-b"
}}