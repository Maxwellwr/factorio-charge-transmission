data:extend {{
  type = "bool-setting",
  name = "charge_transmission-use-modules",
  setting_type = "runtime-global",
  default_value = true,
  order = "charge_transmission-a"
},{
  type = "bool-setting",
  name = "charge_transmission-have-beams",
  setting_type = "runtime-global",
  default_value = true,
  order = "charge_transmission-a"
},{
  type = "int-setting",
  name = "charge_transmission-robots-limit",
  setting_type = "runtime-global",
  default_value = 25,
  minimum_value = 1,
  order = "charge_transmission-b"
},{
  type = "int-setting",
  name = "charge_transmission-nodes-interval",
  setting_type = "runtime-global",
  default_value = 4,
  minimum_value = 1,
  maximum_value = 60,
  order = "charge_transmission-b"
}}