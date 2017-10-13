data:extend {{
    type = "bool-setting",
    name = "charge_transmission-use-modules",
    setting_type = "startup",
    default_value = true,
    order = "charge_transmission-a[modules]-a"
},{
    type = "bool-setting",
    name = "charge_transmission-add-effectivity-mk4",
    setting_type = "startup",
    default_value = true,
    order = "charge_transmission-a[modules]-b"
},{
    type = "bool-setting",
    name = "charge_transmission-add-other-mk4-modules",
    setting_type = "startup",
    default_value = false,
    order = "charge_transmission-a[modules]-c"
},}