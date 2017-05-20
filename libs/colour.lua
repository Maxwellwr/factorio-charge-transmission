local Colour = {}

--- Gets Factorio-friendly color object from hexadecimal string.
-- @param value Hexadecimal color string (#ffffff, not #fff)
-- @param alpha (optional) Alpha number [0, 1]
-- @return Table with rgba percent values
function Colour.fromHex(value, alpha)
  if value:find("#") then value = value:sub(2) end
  if not(#value == 6) then error("Invalid colour value: "..value); return end
  local number = tonumber(value, 16)
  return {
    r = bit32.extract(number, 16, 8) / 255,
    g = bit32.extract(number, 8, 8) / 255,
    b = bit32.extract(number, 0, 8) / 255,
    a = alpha
  }
end

return Colour