-- Utils module for AO legacynet contracts
-- Provides find, map, filter, reduce utility functions

local utils = {}

--- Finds the first element in an array table that satisfies a predicate function.
-- @param fn The predicate function
-- @param t The array table to search
-- @return The first element that satisfies the predicate function
function utils.find(fn, t)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(t) == "table", "second argument should be a table")
  for _, v in pairs(t) do
    if fn(v) then
      return v
    end
  end
  return nil
end

--- Applies a function to each element of an array table, mapping it to a new value.
-- @param fn The function to apply to each element
-- @param t The table to map over
-- @return The mapped table
function utils.map(fn, t)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(t) == "table", "second argument should be an array")
  local result = {}
  for k, v in pairs(t) do
    result[k] = fn(v, k)
  end
  return result
end

--- Filters an array table based on a predicate function.
-- @param fn The predicate function
-- @param t The array to filter
-- @return The filtered table
function utils.filter(fn, t)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(t) == "table", "second argument should be an array")
  local result = {}
  for _, v in pairs(t) do
    if fn(v) then
      table.insert(result, v)
    end
  end
  return result
end

--- Reduces an array table to a single value.
-- @param fn The reducer function (result, value, key)
-- @param initial The initial value
-- @param t The array to reduce
-- @return The reduced value
function utils.reduce(fn, initial, t)
  assert(type(fn) == "function", "first argument should be a function")
  assert(type(t) == "table", "third argument should be a table")
  local result = initial
  for k, v in pairs(t) do
    if result == nil then
      result = v
    else
      result = fn(result, v, k)
    end
  end
  return result
end

return utils
