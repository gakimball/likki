--- Check if a list-like table contains a value.
--- @param list any[]
--- @param value any
local hasvalue = function(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end

  return false
end

return {
  has = hasvalue,
}
