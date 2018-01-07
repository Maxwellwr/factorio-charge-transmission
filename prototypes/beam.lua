local beam = table.deepcopy(data.raw.beam["electric-beam"])
beam.name = "charge_transmission-beam"
beam.action = nil

local weak_beam = table.deepcopy(data.raw.beam["electric-beam"])
weak_beam.name = "charge_transmission-weak-beam"
weak_beam.action = nil
-- log(serpent.block(weak_beam))
local add_weak_tint = function(t)
  t.tint = {r = 1, g = 0.5, b = 0.5}
  if t.hr_version then t.hr_version.tint = {r = 1, g = 0, b = 0} end
end
-- add_weak_tint(weak_beam.start)
-- add_weak_tint(weak_beam.head)
for _, variant in pairs(weak_beam.body) do add_weak_tint(variant) end
-- add_weak_tint(weak_beam.body)
-- add_weak_tint(weak_beam.tail)
-- add_weak_tint(weak_beam.ending)

data:extend{beam, weak_beam}