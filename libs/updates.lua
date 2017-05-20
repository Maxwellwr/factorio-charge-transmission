local Updates = {}

Updates.replaceIngredient = function (recipe, type, old, new)
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == type and ingredient.name == old then
      ingredient.name = new
    end
  end
  if recipe.results then
    for _, result in pairs(recipe.results) do
      if result.type == type and result.name == old then result.name = new end
    end
  elseif recipe.result and recipe.result == old and recipe.type == "item" then
    recipe.result = new
  end
end

return Updates