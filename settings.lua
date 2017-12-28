data:extend {{
  type = "bool-setting",
  name = "charge_transmission-use-modules",
  setting_type = "startup",
  default_value = true,
  order = "charge_transmission-a"
},{
  type = "int-setting",
  name = "charge_transmission-robots-limit",
  setting_type = "runtime-global",
  default_value = 50,
  minimum_value = 1,
  order = "charge_transmission-b"
}}

