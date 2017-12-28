local beam = table.deepcopy(data.raw.beam["electric-beam"])
beam.name = "charge_transmission-beam"
beam.action = nil

data:extend{beam}