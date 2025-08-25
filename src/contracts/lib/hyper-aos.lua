--[[
    ██╗  ██╗██╗   ██╗██████╗ ███████╗██████╗      █████╗  ██████╗ ███████╗
    ██║  ██║╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗    ██╔══██╗██╔═══██╗██╔════╝
    ███████║ ╚████╔╝ ██████╔╝█████╗  ██████╔╝    ███████║██║   ██║███████╗
    ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══╝  ██╔══██╗    ██╔══██║██║   ██║╚════██║
    ██║  ██║   ██║   ██║     ███████╗██║  ██║    ██║  ██║╚██████╔╝███████║
    ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚══════╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
    
    Hyper-AOS v0.1.1
    Built: 2025-08-10 22:05:16
--]]

do
  local module = function()
--- The Utils module provides a collection of utility functions for functional programming in Lua. It includes functions for array manipulation such as concatenation, mapping, reduction, filtering, and finding elements, as well as a property equality checker.
-- @module utils

--- The utils table
-- @table utils
-- @field _version The version number of the utils module
-- @field matchesPattern The matchesPattern function
-- @field matchesSpec The matchesSpec function
-- @field curry The curry function
-- @field concat The concat function
-- @field reduce The reduce function
-- @field map The map function
-- @field filter The filter function
-- @field find The find function
-- @field propEq The propEq function
-- @field reverse The reverse function
-- @field compose The compose function
-- @field prop The prop function
-- @field includes The includes function
-- @field keys The keys function
-- @field values The values function
local utils = { _version = "0.0.5" }

--- Given a pattern, a value, and a message, returns whether there is a pattern match.
-- @usage utils.matchesPattern(pattern, value, msg)
-- @param pattern The pattern to match
-- @param value The value to check for in the pattern
-- @param msg The message to check for the pattern
-- @treturn {boolean} Whether there is a pattern match
function utils.matchesPattern(pattern, value, msg)
  -- If the key is not in the message, then it does not match
  if (not pattern) then
    return false
  end
  -- if the patternMatchSpec is a wildcard, then it always matches
  if pattern == '_' then
    return true
  end
  -- if the patternMatchSpec is a function, then it is executed on the tag value
  if type(pattern) == "function" then
    if pattern(value, msg) then
      return true
    else
      return false
    end
  end
  -- if the patternMatchSpec is a string, check it for special symbols (less `-` alone)
  -- and exact string match mode
  if (type(pattern) == 'string') then
    if string.match(pattern, "[%^%$%(%)%%%.%[%]%*%+%?]") then
      if string.match(value, pattern) then
        return true
      end
    else
      if value == pattern then
        return true
      end
    end
  end

  -- if the pattern is a table, recursively check if any of its sub-patterns match
  if type(pattern) == 'table' then
    for _, subPattern in pairs(pattern) do
      if utils.matchesPattern(subPattern, value, msg) then
        return true
      end
    end
  end

  return false
end

--- Given a message and a spec, returns whether there is a spec match.
-- @usage utils.matchesSpec(msg, spec)
-- @param msg The message to check for the spec
-- @param spec The spec to check for in the message
-- @treturn {boolean} Whether there is a spec match
function utils.matchesSpec(msg, spec)
  if type(spec) == 'function' then
    return spec(msg)
  -- If the spec is a table, step through every key/value pair in the pattern and check if the msg matches
  -- Supported pattern types:
  --   - Exact string match
  --   - Lua gmatch string
  --   - '_' (wildcard: Message has tag, but can be any value)
  --   - Function execution on the tag, optionally using the msg as the second argument
  --   - Table of patterns, where ANY of the sub-patterns matching the tag will result in a match
  end
  if type(spec) == 'table' then
    for key, pattern in pairs(spec) do
      -- The key can either be in the top level of the 'msg' object  
      -- or in the body table of the msg
      local msgValue = msg[key] or (msg.body and msg.body[key])
      if not msgValue then
        return false
      end
      local matchesMsgValue = utils.matchesPattern(pattern, msgValue, msg)
      if not matchesMsgValue then
        return false
      end

    end
    return true
  end

  if type(spec) == 'string' and msg.action and msg.action == spec then
    return true
  end
  if type(spec) == 'string' and msg.body and msg.body.action and msg.body.action == spec then
    return true
  end
  return false
end

--- Given a table, returns whether it is an array.
-- An 'array' is defined as a table with integer keys starting from 1 and
-- having no gaps between the keys.
-- @lfunction isArray
-- @param table The table to check
-- @treturn {boolean} Whether the table is an array
local function isArray(table)
  if type(table) == "table" then
      local maxIndex = 0
      for k, v in pairs(table) do
          if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
              return false -- If there's a non-integer key, it's not an array
          end
          maxIndex = math.max(maxIndex, k)
      end
      -- If the highest numeric index is equal to the number of elements, it's an array
      return maxIndex == #table
  end
  return false
end

--- Curries a function.
-- @tparam {function} fn The function to curry
-- @tparam {number} arity The arity of the function
-- @treturn {function} The curried function
utils.curry = function (fn, arity)
  assert(type(fn) == "function", "function is required as first argument")
  -- LUERL compatibility: if debug.getinfo is not available, arity must be provided
  if not arity then
    if debug and debug.getinfo then
      local info = debug.getinfo(fn, "u")
      arity = info and info.nparams or 2  -- Default to 2 if we can't determine
    else
      arity = 2  -- Default to 2 for LUERL compatibility
    end
  end
  if arity < 2 then return fn end

  return function (...)
    local args = {...}

    if #args >= arity then
      return fn(table.unpack(args))
    else
      return utils.curry(function (...)
        return fn(table.unpack(args),  ...)
      end, arity - #args)
    end
  end
end

--- Concat two Array Tables
-- @function concat
-- @usage utils.concat(a)(b)
-- @usage utils.concat({1, 2})({3, 4}) --> {1, 2, 3, 4}
-- @tparam {table<Array>} a The first array
-- @tparam {table<Array>} b The second array
-- @treturn {table<Array>} The concatenated array
utils.concat = utils.curry(function (a, b)
  assert(type(a) == "table", "first argument should be a table that is an array")
  assert(type(b) == "table", "second argument should be a table that is an array")
  assert(isArray(a), "first argument should be a table")
  assert(isArray(b), "second argument should be a table")

  local result = {}
  for i = 1, #a do
      result[#result + 1] = a[i]
  end
  for i = 1, #b do
      result[#result + 1] = b[i]
  end
  return result
end, 2)

--- Applies a function to each element of a table, reducing it to a single value.
-- @function utils.reduce
-- @usage utils.reduce(fn)(initial)(t)
-- @usage utils.reduce(function(acc, x) return acc + x end)(0)({1, 2, 3}) --> 6
-- @tparam {function} fn The function to apply
-- @param initial The initial value
-- @tparam {table<Array>} t The table to reduce
-- @return The reduced value
utils.reduce = utils.curry(function (fn, initial, t)
  assert(type(fn) == "function", "first argument should be a function that accepts (result, value, key)")
  assert(type(t) == "table" and isArray(t), "third argument should be a table that is an array")
  local result = initial
  for k, v in pairs(t) do
    if result == nil then
      result = v
    else
      result = fn(result, v, k)
    end
  end
  return result
end, 3)

--- Applies a function to each element of an array table, mapping it to a new value.
-- @function utils.map
-- @usage utils.map(fn)(t)
-- @usage utils.map(function(x) return x * 2 end)({1, 2, 3}) --> {2, 4, 6}
-- @tparam {function} fn The function to apply to each element
-- @tparam {table<Array>} data The table to map over
-- @treturn {table<Array>} The mapped table
utils.map = utils.curry(function (fn, data)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(data) == "table" and isArray(data), "second argument should be an Array")

  local function map (result, v, k)
    result[k] = fn(v, k)
    return result
  end

  return utils.reduce(map, {}, data)
end, 2)

--- Filters an array table based on a predicate function.
-- @function utils.filter
-- @usage utils.filter(fn)(t)
-- @usage utils.filter(function(x) return x > 1 end)({1, 2, 3}) --> {2,3}
-- @tparam {function} fn The predicate function to determine if an element should be included.
-- @tparam {table<Array>} data The array to filter
-- @treturn {table<Array>} The filtered table
utils.filter = utils.curry(function (fn, data)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(data) == "table" and isArray(data), "second argument should be an Array")

  local function filter (result, v, _k)
    if fn(v) then
      table.insert(result, v)
    end
    return result
  end

  return utils.reduce(filter,{}, data)
end, 2)

--- Finds the first element in an array table that satisfies a predicate function.
-- @function utils.find
-- @usage utils.find(fn)(t)
-- @usage utils.find(function(x) return x > 1 end)({1, 2, 3}) --> 2
-- @tparam {function} fn The predicate function to determine if an element should be included.
-- @tparam {table<Array>} t The array table to search
-- @treturn The first element that satisfies the predicate function
utils.find = utils.curry(function (fn, t)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(t) == "table", "second argument should be a table that is an array")
  for _, v in pairs(t) do
    if fn(v) then
      return v
    end
  end
end, 2)

--- Checks if a property of an object is equal to a value.
-- @function utils.propEq
-- @usage utils.propEq(propName)(value)(object)
-- @usage utils.propEq("name")("Lua")({name = "Lua"}) --> true
-- @tparam {string} propName The property name to check
-- @tparam {string} value The value to check against
-- @tparam {table} object The object to check
-- @treturn {boolean} Whether the property is equal to the value
utils.propEq = utils.curry(function (propName, value, object)
  assert(type(propName) == "string", "first argument should be a string")
  assert(type(value) == "string", "second argument should be a string")
  assert(type(object) == "table", "third argument should be a table<object>")
  
  return object[propName] == value
end, 3)

--- Reverses an array table.
-- @function utils.reverse
-- @usage utils.reverse(data)
-- @usage utils.reverse({1, 2, 3}) --> {3, 2, 1}
-- @tparam {table<Array>} data The array table to reverse
-- @treturn {table<Array>} The reversed array table
utils.reverse = function (data)
  assert(type(data) == "table", "argument needs to be a table that is an array")
  return utils.reduce(
    function (result, v, i)
      result[#data - i + 1] = v
      return result
    end,
    {},
    data
  )
end

--- Composes a series of functions into a single function.
-- @function utils.compose
-- @usage utils.compose(fn1)(fn2)(fn3)(v)
-- @usage utils.compose(function(x) return x + 1 end)(function(x) return x * 2 end)(3) --> 7
-- @tparam {function} ... The functions to compose
-- @treturn {function} The composed function
utils.compose = utils.curry(function (...)
  local mutations = utils.reverse({...})

  return function (v)
    local result = v
    for _, fn in pairs(mutations) do
      assert(type(fn) == "function", "each argument needs to be a function")
      result = fn(result)
    end
    return result
  end
end, 2)

--- Returns the value of a property of an object.
-- @function utils.prop
-- @usage utils.prop(propName)(object)
-- @usage utils.prop("name")({name = "Lua"}) --> "Lua"
-- @tparam {string} propName The property name to get
-- @tparam {table} object The object to get the property from
-- @treturn The value of the property
utils.prop = utils.curry(function (propName, object) 
  return object[propName]
end, 2)

--- Checks if an array table includes a value.
-- @function utils.includes
-- @usage utils.includes(val)(t)
-- @usage utils.includes(2)({1, 2, 3}) --> true
-- @param val The value to check for
-- @tparam {table<Array>} t The array table to check
-- @treturn {boolean} Whether the value is in the array table
utils.includes = utils.curry(function (val, t)
  assert(type(t) == "table", "argument needs to be a table")
  assert(isArray(t), "argument should be a table that is an array")
  return utils.find(function (v) return v == val end, t) ~= nil
end, 2)

--- Returns the keys of a table.
-- @usage utils.keys(t)
-- @usage utils.keys({name = "Lua", age = 25}) --> {"name", "age"}
-- @tparam {table} t The table to get the keys from
-- @treturn {table<Array>} The keys of the table
utils.keys = function (t)
  assert(type(t) == "table", "argument needs to be a table")
  local keys = {}
  for key in pairs(t) do
    table.insert(keys, key)
  end
  return keys
end

--- Returns the values of a table.
-- @usage utils.values(t)
-- @usage utils.values({name = "Lua", age = 25}) --> {"Lua", 25}
-- @tparam {table} t The table to get the values from
-- @treturn {table<Array>} The values of the table
utils.values = function (t)
  assert(type(t) == "table", "argument needs to be a table")
  local values = {}
  for _, value in pairs(t) do
    table.insert(values, value)
  end
  return values
end

--- Convert a message's tags to a table of key-value pairs
-- @function Tab
-- @tparam {table} msg The message containing tags
-- @treturn {table} A table with tag names as keys and their values
function utils.Tab(msg)
  local inputs = {}
  for _, o in ipairs(msg.Tags) do
    if not inputs[o.name] then
      inputs[o.name] = o.value
    end
  end
  return inputs
end


return utils

  end
  _G.package.loaded['.utils'] = module()
end

-- next file

do
  local module = function()
--- The Handler Utils module is a lightweight Lua utility library designed to provide common functionalities for handling and processing messages within the AOS computer system. It offers a set of functions to check message attributes and send replies, simplifying the development of more complex scripts and modules. This document will guide you through the module's functionalities, installation, and usage. Returns the _utils table.
-- @module handlers-utils

--- The _utils table
-- @table _utils
-- @field _version The version number of the _utils module
-- @field hasMatchingTag The hasMatchingTag function
-- @field hasMatchingTagOf The hasMatchingTagOf function
-- @field hasMatchingData The hasMatchingData function
-- @field reply The reply function
-- @field continue The continue function
local _utils = { _version = "0.0.2" }

local _ = require('.utils')

--- Checks if a given message has a tag that matches the specified name and value.
-- @function hasMatchingTag
-- @tparam {string} name The tag name to check
-- @tparam {string} value The value to match for in the tag
-- @treturn {function} A function that takes a message and returns whether there is a tag match (-1 if matches, 0 otherwise)
function _utils.hasMatchingTag(name, value)
  assert(type(name) == 'string' and type(value) == 'string', 'invalid arguments: (name : string, value : string)')

  return function (msg)
    return msg.Tags[name] == value
  end
end

--- Checks if a given message has a tag that matches the specified name and one of the specified values.
-- @function hasMatchingTagOf
-- @tparam {string} name The tag name to check
-- @tparam {string[]} values The list of values of which one should match
-- @treturn {function} A function that takes a message and returns whether there is a tag match (-1 if matches, 0 otherwise)
function _utils.hasMatchingTagOf(name, values)
  assert(type(name) == 'string' and type(values) == 'table', 'invalid arguments: (name : string, values : string[])')
  return function (msg)
    for _, value in ipairs(values) do
      local patternResult = Handlers.utils.hasMatchingTag(name, value)(msg)

      if patternResult ~= 0 and patternResult ~= false and patternResult ~= "skip" then
        return patternResult
      end
    end

    return 0
  end
end

--- Checks if a given message has data that matches the specified value.
-- @function hasMatchingData
-- @tparam {string} value The value to match against the message data
-- @treturn {function} A function that takes a message and returns whether the data matches the value (-1 if matches, 0 otherwise)
function _utils.hasMatchingData(value)
  assert(type(value) == 'string', 'invalid arguments: (value : string)')
  return function (msg)
    return msg.Data == value
  end
end

--- Given an input, returns a function that takes a message and replies to it.
-- @function reply
-- @tparam {table | string} input The content to send back. If a string, it sends it as data. If a table, it assumes a structure with `Tags`.
-- @treturn {function} A function that takes a message and replies to it
function _utils.reply(input) 
  assert(type(input) == 'table' or type(input) == 'string', 'invalid arguments: (input : table or string)')
  return function (msg)
    if type(input) == 'string' then
      msg.reply({ Data = input })
      return
    end
    msg.reply(input)
  end
end

--- Inverts the provided pattern's result if it matches, so that it continues execution with the next matching handler.
-- @function continue
-- @tparam {table | function} pattern The pattern to check for in the message
-- @treturn {function} Function that executes the pattern matching function and returns `1` (continue), so that the execution of handlers continues.
function _utils.continue(pattern)
  return function (msg)
    local match = _.matchesSpec(msg, pattern)

    if not match or match == 0 or match == "skip" then
      return match
    end
    return 1
  end
end

return _utils

  end
  _G.package.loaded['.handlers-utils'] = module()
end

-- next file

do
  local module = function()
--- The Handlers library provides a flexible way to manage and execute a series of handlers based on patterns. Each handler consists of a pattern function, a handle function, and a name. This library is suitable for scenarios where different actions need to be taken based on varying input criteria. Returns the handlers table.
-- @module handlers

--- The handlers table
-- @table handlers
-- @field _version The version number of the handlers module
-- @field list The list of handlers
-- @field onceNonce The nonce for the once handlers
-- @field utils The handlers-utils module
-- @field generateResolver The generateResolver function
-- @field receive The receive function
-- @field once The once function
-- @field add The add function
-- @field append The append function
-- @field prepend The prepend function
-- @field remove The remove function
-- @field evaluate The evaluate function
local handlers = { _version = "0.0.5" }
local utils = require('.utils')

handlers.utils = require('.handlers-utils')
-- if update we need to keep defined handlers
if Handlers then
  handlers.list = Handlers.list or {}
else
  handlers.list = {}
end
handlers.onceNonce = 0

--- Given an array, a property name, and a value, returns the index of the object in the array that has the property with the value.
-- @lfunction findIndexByProp
-- @tparam {table[]} array The array to search through
-- @tparam {string} prop The property name to check
-- @tparam {any} value The value to check for in the property
-- @treturn {number | nil} The index of the object in the array that has the property with the value, or nil if no such object is found
local function findIndexByProp(array, prop, value)
  for index, object in ipairs(array) do
    if object[prop] == value then
      return index
    end
  end
  return nil
end

--- Given a name, a pattern, and a handle, asserts that the arguments are valid.
-- @lfunction assertAddArgs
-- @tparam {string} name The name of the handler
-- @tparam {table | function | string} pattern The pattern to check for in the message
-- @tparam {function} handle The function to call if the pattern matches
-- @tparam {number | string | nil} maxRuns The maximum number of times the handler should run, or nil if there is no limit
local function assertAddArgs(name, pattern, handle, maxRuns)
  assert(
    type(name) == 'string' and
    (type(pattern) == 'function' or type(pattern) == 'table' or type(pattern) == 'string'),
    'Invalid arguments given. Expected: \n' ..
    '\tname : string, ' ..
    '\tpattern : action : string | MsgMatch : table,\n' ..
    '\t\tfunction(msg: Message) : {-1 = break, 0 = skip, 1 = continue},\n' ..
    '\thandle(msg : Message) : void) | Resolver,\n' ..
    '\tMaxRuns? : number | "inf" | nil')
end

--- Given a resolver specification, returns a resolver function.
-- @function generateResolver
-- @tparam {table | function} resolveSpec The resolver specification
-- @treturn {function} A resolver function
function handlers.generateResolver(resolveSpec)
  return function(msg)
    -- If the resolver is a single function, call it.
    -- Else, find the first matching pattern (by its matchSpec), and exec.
    if type(resolveSpec) == "function" then
      return resolveSpec(msg)
    else
        for matchSpec, func in pairs(resolveSpec) do
            if utils.matchesSpec(msg, matchSpec) then
                return func(msg)
            end
        end
    end
  end
end

--- Given a pattern, returns the next message that matches the pattern.
-- This function uses Lua's coroutines under-the-hood to add a handler, pause,
-- and then resume the current coroutine. This allows us to effectively block
-- processing of one message until another is received that matches the pattern.
-- @function receive
-- @tparam {table | function} pattern The pattern to check for in the message
function handlers.receive(pattern)
  return 'not implemented'
end

--- Given a name, a pattern, and a handle, adds a handler to the list.
-- If name is not provided, "_once_" prefix plus onceNonce will be used as the name.
-- Adds handler with maxRuns of 1 such that it will only be called once then removed from the list.
-- @function once
-- @tparam {string} name The name of the handler
-- @tparam {table | function | string} pattern The pattern to check for in the message
-- @tparam {function} handle The function to call if the pattern matches
function handlers.once(...)
  local name, pattern, handle
  if select("#", ...) == 3 then
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
  else
    name = "_once_" .. tostring(handlers.onceNonce)
    handlers.onceNonce = handlers.onceNonce + 1
    pattern = select(1, ...)
    handle = select(2, ...)
  end
  handlers.prepend(name, pattern, handle, 1)
end

--- Given a name, a pattern, and a handle, adds a handler to the list.
-- @function add
-- @tparam {string} name The name of the handler
-- @tparam {table | function | string} pattern The pattern to check for in the message
-- @tparam {function} handle The function to call if the pattern matches
-- @tparam {number | string | nil} maxRuns The maximum number of times the handler should run, or nil if there is no limit
function handlers.add(...)
  local name, pattern, handle, maxRuns
  local args = select("#", ...)
  if args == 2 then
    name = select(1, ...)
    pattern = select(1, ...)
    handle = select(2, ...)
    maxRuns = nil
  elseif args == 3 then
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = nil
  else
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = select(4, ...)
  end
  assertAddArgs(name, pattern, handle, maxRuns)

  handle = handlers.generateResolver(handle)

  -- update existing handler by name
  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    -- found update
    handlers.list[idx].pattern = pattern
    handlers.list[idx].handle = handle
    handlers.list[idx].maxRuns = maxRuns
  else
    -- not found then add    
    table.insert(handlers.list, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })

  end
  return #handlers.list
end

--- Appends a new handler to the end of the handlers list.
-- @function append
-- @tparam {string} name The name of the handler
-- @tparam {table | function | string} pattern The pattern to check for in the message
-- @tparam {function} handle The function to call if the pattern matches
-- @tparam {number | string | nil} maxRuns The maximum number of times the handler should run, or nil if there is no limit
function handlers.append(...)
  local name, pattern, handle, maxRuns
  local args = select("#", ...)
  if args == 2 then
    name = select(1, ...)
    pattern = select(1, ...)
    handle = select(2, ...)
    maxRuns = nil
  elseif args == 3 then
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = nil
  else
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = select(4, ...)
  end
  assertAddArgs(name, pattern, handle, maxRuns)

  handle = handlers.generateResolver(handle)
  -- update existing handler by name
  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    -- found update
    handlers.list[idx].pattern = pattern
    handlers.list[idx].handle = handle
    handlers.list[idx].maxRuns = maxRuns
  else
    table.insert(handlers.list, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
  end
end

--- Prepends a new handler to the beginning of the handlers list.
-- @function prepend
-- @tparam {string} name The name of the handler
-- @tparam {table | function | string} pattern The pattern to check for in the message
-- @tparam {function} handle The function to call if the pattern matches
-- @tparam {number | string | nil} maxRuns The maximum number of times the handler should run, or nil if there is no limit
function handlers.prepend(...)
  local name, pattern, handle, maxRuns
  local args = select("#", ...)
  if args == 2 then
    name = select(1, ...)
    pattern = select(1, ...)
    handle = select(2, ...)
    maxRuns = nil
  elseif args == 3 then
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = nil
  else 
    name = select(1, ...)
    pattern = select(2, ...)
    handle = select(3, ...)
    maxRuns = select(4, ...)
  end
  assertAddArgs(name, pattern, handle, maxRuns)

  handle = handlers.generateResolver(handle)

  -- update existing handler by name
  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    -- found update
    handlers.list[idx].pattern = pattern
    handlers.list[idx].handle = handle
    handlers.list[idx].maxRuns = maxRuns
  else  
    table.insert(handlers.list, 1, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
  end
end

--- Returns an object that allows adding a new handler before a specified handler.
-- @function before
-- @tparam {string} handleName The name of the handler before which the new handler will be added
-- @treturn {table} An object with an `add` method to insert the new handler
function handlers.before(handleName)
  assert(type(handleName) == 'string', 'Handler name MUST be a string')

  local idx = findIndexByProp(handlers.list, "name", handleName)
  return {
    add = function (name, pattern, handle, maxRuns) 
      assertAddArgs(name, pattern, handle, maxRuns)
      handle = handlers.generateResolver(handle)
      if idx then
        table.insert(handlers.list, idx, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
      end
    end
  }
end

--- Returns an object that allows adding a new handler after a specified handler.
-- @function after
-- @tparam {string} handleName The name of the handler after which the new handler will be added
-- @treturn {table} An object with an `add` method to insert the new handler
function handlers.after(handleName)
  assert(type(handleName) == 'string', 'Handler name MUST be a string')
  local idx = findIndexByProp(handlers.list, "name", handleName)
  return {
    add = function (name, pattern, handle, maxRuns)
      assertAddArgs(name, pattern, handle, maxRuns)
      handle = handlers.generateResolver(handle)
      if idx then
        table.insert(handlers.list, idx + 1, { pattern = pattern, handle = handle, name = name, maxRuns = maxRuns })
      end
    end
  }

end

--- Removes a handler from the handlers list by name.
-- @function remove
-- @tparam {string} name The name of the handler to be removed
function handlers.remove(name)
  assert(type(name) == 'string', 'name MUST be string')
  if #handlers.list == 1 and handlers.list[1].name == name then
    handlers.list = {}
  end

  local idx = findIndexByProp(handlers.list, "name", name)
  if idx ~= nil and idx > 0 then
    table.remove(handlers.list, idx)
  end
end

--- Evaluates each handler against a given message and environment. Handlers are called in the order they appear in the handlers list.
-- Return 0 to not call handler, -1 to break after handler is called, 1 to continue
-- @function evaluate
-- @tparam {table} msg The message to be processed by the handlers.
-- @tparam {table} env The environment in which the handlers are executed.
-- @treturn The response from the handler(s). Returns a default message if no handler matches.
function handlers.evaluate(msg, env)
  local handled = false
  assert(type(msg) == 'table', 'msg is not valid')
  assert(type(env) == 'table', 'env is not valid')
  for _, o in ipairs(handlers.list) do
    if o.name ~= "_default" then
      local match = utils.matchesSpec(msg, o.pattern)
      if not (type(match) == 'number' or type(match) == 'string' or type(match) == 'boolean') then
        error("Pattern result is not valid, it MUST be string, number, or boolean")
      end
      -- handle boolean returns
      if type(match) == "boolean" and match == true then
        match = -1
      elseif type(match) == "boolean" and match == false then
        match = 0
      end

      -- handle string returns
      if type(match) == "string" then
        if match == "continue" then
          match = 1
        elseif match == "break" then
          match = -1
        else
          match = 0
        end
      end

      if match ~= 0 then
        if match < 0 then
          handled = true
        end
        -- each handle function can accept, the msg, env
        local status, err = pcall(o.handle, msg, env)
        if not status then
          error(err)
        end
        -- remove handler if maxRuns is reached. maxRuns can be either a number or "inf"
        if o.maxRuns ~= nil and o.maxRuns ~= "inf" then
          o.maxRuns = o.maxRuns - 1
          if o.maxRuns == 0 then
            handlers.remove(o.name)
          end
        end
      end
      if match < 0 then
        return handled
      end
    end
  end
  -- do default
  if not handled then
    -- add to inbox
    table.insert(Inbox, msg)
    return true, _G.meta.printNewMessage(msg)
  end
end

return handlers

  end
  _G.package.loaded['.handlers'] = module()
end

-- next file

do
  local module = function()
--[[
bint_luerl - Optimized version for LUERL environment
Leverages LUERL's native large integer support for efficient arbitrary-precision arithmetic

This is a simplified API-compatible version of bint that directly uses LUERL's
native large integer capabilities instead of the array-based implementation.
]]

local memo = {}

--- Create a new bint module
-- For LUERL, we can use native integers of any size
local function newmodule(bits, wordbits)
  bits = bits or 256
  
  -- Memoize modules
  local memoindex = bits * 64 + (wordbits or 0)
  if memo[memoindex] then
    return memo[memoindex]
  end
  
  -- Create bint module
  local bint = {}
  bint.__index = bint
  
  -- Store bits for compatibility
  bint.bits = bits
  
  -- In LUERL, we store the value directly as a large integer
  -- wrapped in a table for metatable support
  
  --- Create a new bint with 0 value
  function bint.zero()
    return setmetatable({value = 0}, bint)
  end
  
  --- Create a new bint with 1 value
  function bint.one()
    return setmetatable({value = 1}, bint)
  end
  
  --- Create a bint from an unsigned integer
  function bint.fromuinteger(x)
    x = tonumber(x)
    if x then
      return setmetatable({value = math.floor(x)}, bint)
    end
  end
  
  --- Create a bint from a signed integer
  function bint.frominteger(x)
    x = tonumber(x)
    if x then
      return setmetatable({value = math.floor(x)}, bint)
    end
  end
  
  --- Create a bint from a string in base
  function bint.frombase(s, base)
    if type(s) ~= 'string' then
      return nil
    end
    base = base or 10
    if not (base >= 2 and base <= 36) then
      return nil
    end
    
    -- Use native tonumber for conversion
    local value = tonumber(s, base)
    if value then
      return setmetatable({value = math.floor(value)}, bint)
    end
    
    -- For very large numbers, parse manually
    local sign, int = s:lower():match('^([+-]?)(%w+)$')
    if not int then
      return nil
    end
    
    local result = 0
    local power = 1
    for i = #int, 1, -1 do
      local digit = tonumber(int:sub(i, i), base)
      if not digit then
        return nil
      end
      result = result + digit * power
      power = power * base
    end
    
    if sign == '-' then
      result = -result
    end
    
    return setmetatable({value = result}, bint)
  end
  
  --- Create a bint from a string
  function bint.fromstring(s)
    if type(s) ~= 'string' then
      return nil
    end
    
    if s:find('^[+-]?[0-9]+$') then
      return bint.frombase(s, 10)
    elseif s:find('^[+-]?0[xX][0-9a-fA-F]+$') then
      return bint.frombase(s:gsub('0[xX]', '', 1), 16)
    elseif s:find('^[+-]?0[bB][01]+$') then
      return bint.frombase(s:gsub('0[bB]', '', 1), 2)
    end
  end
  
  --- Create a new bint from a value
  function bint.new(x)
    if getmetatable(x) == bint then
      return setmetatable({value = x.value}, bint)
    end
    
    local ty = type(x)
    if ty == 'number' then
      return bint.frominteger(x)
    elseif ty == 'string' then
      return bint.fromstring(x)
    end
    
    assert(false, 'value cannot be represented by a bint')
  end
  
  --- Convert to bint if possible
  function bint.tobint(x, clone)
    if getmetatable(x) == bint then
      if clone then
        return setmetatable({value = x.value}, bint)
      end
      return x
    end
    
    local ty = type(x)
    if ty == 'number' then
      return bint.frominteger(x)
    elseif ty == 'string' then
      return bint.fromstring(x)
    end
  end
  
  --- Parse to bint or number
  function bint.parse(x, clone)
    local b = bint.tobint(x, clone)
    if b then
      return b
    end
    return tonumber(x)
  end
  
  --- Convert to unsigned integer
  function bint.touinteger(x)
    if getmetatable(x) == bint then
      return x.value
    end
    return math.floor(tonumber(x) or 0)
  end
  
  --- Convert to signed integer
  function bint.tointeger(x)
    if getmetatable(x) == bint then
      return x.value
    end
    return math.floor(tonumber(x) or 0)
  end
  
  --- Convert to number
  function bint.tonumber(x)
    if getmetatable(x) == bint then
      return x.value
    end
    return tonumber(x)
  end
  
  --- Convert to string in base
  function bint.tobase(x, base, unsigned)
    x = bint.tobint(x)
    if not x then
      return nil
    end
    
    base = base or 10
    if not (base >= 2 and base <= 36) then
      return nil
    end
    
    if unsigned == nil then
      unsigned = base ~= 10
    end
    
    local value = x.value
    if not unsigned and value < 0 then
      return '-' .. bint.tobase(setmetatable({value = -value}, bint), base, true)
    end
    
    if value == 0 then
      return '0'
    end
    
    local digits = '0123456789abcdefghijklmnopqrstuvwxyz'
    local result = {}
    
    while value > 0 do
      local remainder = value % base
      table.insert(result, 1, digits:sub(remainder + 1, remainder + 1))
      value = math.floor(value / base)
    end
    
    return table.concat(result)
  end
  
  --- Check if zero
  function bint.iszero(x)
    if getmetatable(x) == bint then
      return x.value == 0
    end
    return x == 0
  end
  
  --- Check if one
  function bint.isone(x)
    if getmetatable(x) == bint then
      return x.value == 1
    end
    return x == 1
  end
  
  --- Check if minus one
  function bint.isminusone(x)
    if getmetatable(x) == bint then
      return x.value == -1
    end
    return x == -1
  end
  
  --- Check if bint
  function bint.isbint(x)
    return getmetatable(x) == bint
  end
  
  --- Check if integral
  function bint.isintegral(x)
    return getmetatable(x) == bint or (type(x) == 'number' and x == math.floor(x))
  end
  
  --- Check if numeric
  function bint.isnumeric(x)
    return getmetatable(x) == bint or type(x) == 'number'
  end
  
  --- Get type
  function bint.type(x)
    if getmetatable(x) == bint then
      return 'bint'
    elseif type(x) == 'number' then
      if x == math.floor(x) then
        return 'integer'
      else
        return 'float'
      end
    end
  end
  
  --- Check if negative
  function bint.isneg(x)
    if getmetatable(x) == bint then
      return x.value < 0
    end
    return x < 0
  end
  
  --- Check if positive
  function bint.ispos(x)
    if getmetatable(x) == bint then
      return x.value > 0
    end
    return x > 0
  end
  
  --- Check if even
  function bint.iseven(x)
    if getmetatable(x) == bint then
      return x.value % 2 == 0
    end
    return math.floor(x) % 2 == 0
  end
  
  --- Check if odd
  function bint.isodd(x)
    if getmetatable(x) == bint then
      return x.value % 2 ~= 0
    end
    return math.floor(x) % 2 ~= 0
  end
  
  --- Absolute value
  function bint.abs(x)
    local bx = bint.tobint(x)
    if bx then
      return setmetatable({value = math.abs(bx.value)}, bint)
    end
    return math.abs(x)
  end
  
  --- Increment
  function bint.inc(x)
    local bx = bint.tobint(x, true)
    if bx then
      bx.value = bx.value + 1
      return bx
    end
    return x + 1
  end
  
  --- Decrement
  function bint.dec(x)
    local bx = bint.tobint(x, true)
    if bx then
      bx.value = bx.value - 1
      return bx
    end
    return x - 1
  end
  
  --- Addition
  function bint.__add(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return setmetatable({value = bx.value + by.value}, bint)
    end
    return (tonumber(x) or 0) + (tonumber(y) or 0)
  end
  
  --- Subtraction
  function bint.__sub(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return setmetatable({value = bx.value - by.value}, bint)
    end
    return (tonumber(x) or 0) - (tonumber(y) or 0)
  end
  
  --- Multiplication
  function bint.__mul(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return setmetatable({value = bx.value * by.value}, bint)
    end
    return (tonumber(x) or 0) * (tonumber(y) or 0)
  end
  
  --- Integer division
  function bint.__idiv(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      assert(by.value ~= 0, 'attempt to divide by zero')
      -- LUERL handles large integer division correctly
      return setmetatable({value = bx.value // by.value}, bint)
    end
    return math.floor((tonumber(x) or 0) / (tonumber(y) or 1))
  end
  
  --- Float division
  function bint.__div(x, y)
    local nx = getmetatable(x) == bint and x.value or tonumber(x) or 0
    local ny = getmetatable(y) == bint and y.value or tonumber(y) or 1
    return nx / ny
  end
  
  --- Modulo
  function bint.__mod(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      assert(by.value ~= 0, 'attempt to divide by zero')
      return setmetatable({value = bx.value % by.value}, bint)
    end
    return (tonumber(x) or 0) % (tonumber(y) or 1)
  end
  
  --- Power
  function bint.__pow(x, y)
    local nx = getmetatable(x) == bint and x.value or tonumber(x) or 0
    local ny = getmetatable(y) == bint and y.value or tonumber(y) or 0
    return nx ^ ny
  end
  
  --- Integer power
  function bint.ipow(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      -- Use exponentiation by squaring for efficiency
      local result = setmetatable({value = 1}, bint)
      local base = setmetatable({value = bx.value}, bint)
      local exp = by.value
      
      if exp < 0 then
        return setmetatable({value = 0}, bint)
      end
      
      if exp == 0 then
        return setmetatable({value = 1}, bint)
      end
      
      while exp > 0 do
        if exp % 2 == 1 then
          result = result * base
        end
        base = base * base
        exp = exp // 2
      end
      
      return result
    end
    
    return math.floor((tonumber(x) or 0) ^ (tonumber(y) or 0))
  end
  
  --- Unary minus
  function bint.__unm(x)
    if getmetatable(x) == bint then
      return setmetatable({value = -x.value}, bint)
    end
    return -(tonumber(x) or 0)
  end
  
  --- Bitwise AND
  function bint.__band(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      -- LUERL should support bitwise operations on large integers
      return setmetatable({value = bx.value & by.value}, bint)
    end
    return 0
  end
  
  --- Bitwise OR
  function bint.__bor(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return setmetatable({value = bx.value | by.value}, bint)
    end
    return 0
  end
  
  --- Bitwise XOR
  function bint.__bxor(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return setmetatable({value = bx.value ~ by.value}, bint)
    end
    return 0
  end
  
  --- Bitwise NOT
  function bint.__bnot(x)
    if getmetatable(x) == bint then
      return setmetatable({value = ~x.value}, bint)
    end
    return ~(tonumber(x) or 0)
  end
  
  --- Left shift
  function bint.__shl(x, y)
    local bx = bint.tobint(x)
    local shiftn = tonumber(y) or 0
    if bx then
      return setmetatable({value = bx.value << shiftn}, bint)
    end
    return (tonumber(x) or 0) << shiftn
  end
  
  --- Right shift
  function bint.__shr(x, y)
    local bx = bint.tobint(x)
    local shiftn = tonumber(y) or 0
    if bx then
      return setmetatable({value = bx.value >> shiftn}, bint)
    end
    return (tonumber(x) or 0) >> shiftn
  end
  
  --- Equality
  function bint.__eq(x, y)
    -- Both must be bints for metamethod to be called
    return x.value == y.value
  end
  
  --- General equality check
  function bint.eq(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return bx.value == by.value
    end
    return x == y
  end
  
  --- Less than
  function bint.__lt(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return bx.value < by.value
    end
    return (tonumber(x) or 0) < (tonumber(y) or 0)
  end
  
  --- Less than or equal
  function bint.__le(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return bx.value <= by.value
    end
    return (tonumber(x) or 0) <= (tonumber(y) or 0)
  end
  
  --- To string
  function bint:__tostring()
    return tostring(self.value)
  end
  
  --- Division and modulo operations
  function bint.idivmod(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      assert(by.value ~= 0, 'attempt to divide by zero')
      local q = bx.value // by.value
      local r = bx.value % by.value
      return setmetatable({value = q}, bint), setmetatable({value = r}, bint)
    end
    local nx, ny = tonumber(x) or 0, tonumber(y) or 1
    return math.floor(nx / ny), nx % ny
  end
  
  --- Max/min functions
  function bint.max(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return setmetatable({value = math.max(bx.value, by.value)}, bint)
    end
    return math.max(tonumber(x) or 0, tonumber(y) or 0)
  end
  
  function bint.min(x, y)
    local bx, by = bint.tobint(x), bint.tobint(y)
    if bx and by then
      return setmetatable({value = math.min(bx.value, by.value)}, bint)
    end
    return math.min(tonumber(x) or 0, tonumber(y) or 0)
  end
  
  -- In-place operations for API compatibility
  function bint:_add(y)
    local by = bint.tobint(y)
    if by then
      self.value = self.value + by.value
    end
    return self
  end
  
  function bint:_sub(y)
    local by = bint.tobint(y)
    if by then
      self.value = self.value - by.value
    end
    return self
  end
  
  function bint:_unm()
    self.value = -self.value
    return self
  end
  
  function bint:_abs()
    self.value = math.abs(self.value)
    return self
  end
  
  function bint:_inc()
    self.value = self.value + 1
    return self
  end
  
  function bint:_dec()
    self.value = self.value - 1
    return self
  end
  
  -- Allow calling bint as constructor
  setmetatable(bint, {
    __call = function(_, x)
      return bint.new(x)
    end
  })
  
  memo[memoindex] = bint
  return bint
end

return newmodule
  end
  -- Load bint_luerl as .bint module (returns the constructor function)
  _G.package.loaded['.bint'] = module()
end

-- next file

do
  local module = function()
local json = { _version = "0.2.0" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t"
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do escape_char_map_inv[v] = k end

local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end

local function encode_nil(val) return "null" end

local function encode_table(val, stack)
  local res = {}
  stack = stack or {}
  
  -- Circular reference?
  if stack[val] then error("circular reference") end
  
  stack[val] = true
  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then error("invalid table: sparse array") end
    -- Encode
    for i = 1, #val do res[i] = encode(val[i], stack) end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"
  else
    -- Treat as an object
    local i = 1
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      if type(v) ~= "function" then
        res[i] = encode(k, stack) .. ":" .. encode(v, stack)
        i = i + 1
      end
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end

local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end

local type_func_map = {
  [ "nil" ]     = encode_nil,
  [ "table" ]   = encode_table,
  [ "string" ]  = encode_string,
  [ "number" ]  = encode_number,
  [ "boolean" ] = tostring
}

encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then return f(val, stack) end
  error("unexpected type '" .. t .. "'")
end

function json.encode(val) return (encode(val)) end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do res[select(i, ...)] = true end
  return res
end

local space_chars = create_set(" ", "\t", "\r", "\n")
local delim_chars = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals = create_set("true", "false", "null")

local literal_map = { [ "true" ] = true, [ "false" ] = false, [ "null" ] = nil }

local function next_char(str, idx, set, negate)
  for i = idx, #str do if set[str:sub(i, i)] ~= negate then return i end end
  return #str + 1
end

local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error(string.format("%s at line %d col %d", msg, line_count, col_count))
end

local function codepoint_to_utf8(n)
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128,
                       n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error(string.format("invalid unicode codepoint '%x'", n))
end

local function parse_unicode_escape(s)
  local n1 = tonumber(s:sub(1, 4), 16)
  local n2 = tonumber(s:sub(7, 10), 16)
  if n2 then
    return
    codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end

local function parse_string(str, i)
  local res = {}
  local j = i + 1
  local k = j
  
  while j <= #str do
    local x = str:byte(j)
    
    if x < 32 then
      decode_error(str, j, "control character in string")
    elseif x == 92 then -- `\`: Escape
      res[#res + 1] = str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1) or
                    str:match("^%x%x%x%x", j + 1) or
                    decode_error(str, j - 1,
                                 "invalid unicode escape in string")
        res[#res + 1] = parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1,
                       "invalid escape char '" .. c .. "' in string")
        end
        res[#res + 1] = escape_char_map_inv[c]
      end
      k = j + 1
    elseif x == 34 then -- `"`: End of string
      res[#res + 1] = str:sub(k, j - 1)
      return table.concat(res), j + 1
    end
    
    j = j + 1
  end
  
  decode_error(str, i, "expected closing quote for string")
end

local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then decode_error(str, i, "invalid number '" .. s .. "'") end
  return n, x
end

local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end

local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while true do
    local x
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end

local function parse_object(str, i)
  local res = {}
  i = i + 1
  while true do
    local key, val
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    val, i = parse(str, i)
    res[key] = val
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end

local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object
}

parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then return f(str, idx) end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end

function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then decode_error(str, idx, "trailing garbage") end
  return res
end

return json
  end
  -- Load json module without the dot prefix
  _G.package.loaded['json'] = module()
end

-- next file

do
-- set version for hyper-aos
_G.package.loaded['.process'] = { _version = "dev" }
-- load handlers to global state if exists
if _G.package.loaded['.handlers'] then
  _G.Handlers = require('.handlers')
end

-- Initialize global state variables directly in _G
-- These will be persisted across compute calls
_G.Inbox = _G.Inbox or {}
_G.MAX_INBOX_SIZE = 10000
_G._OUTPUT = ""

-- Private functions table
-- This table is kept in _G for test compatibility but excluded from state extraction
-- We keep meta separate as it contains private functions and initialization state
---@diagnostic disable-next-line
_G.meta = _G.meta or { initialized = false }
function _G.meta.init(msg)
  -- Initialize owner from first Process message
  if not _G.meta.initialized and msg.type and string.lower(msg.type) == "process" and msg.commitments then
    -- Find first non-hmac commitment and set its committer as owner
    for key, commitment in pairs(msg.commitments) do
      if commitment.type and string.lower(commitment.type) ~= "hmac-sha256" and commitment.committer then
        -- Store process id and owner directly in _G
        _G.id = key
        _G.owner = commitment.committer
        _G.meta.initialized = true
        
        -- Initialize authorities array in _G
        _G.authorities = _G.authorities or {}
        
        -- Parse authorities from comma-separated string
        if msg.authority then
          -- Split comma-separated authorities string manually
          local authorities_str = msg.authority
          local start_pos = 1
          while true do
            local comma_pos = string.find(authorities_str, ",", start_pos)
            local authority
            if comma_pos then
              authority = string.sub(authorities_str, start_pos, comma_pos - 1)
            else
              authority = string.sub(authorities_str, start_pos)
            end
            
            -- Trim whitespace
            authority = string.match(authority, "^%s*(.-)%s*$") or authority
            
            -- Check if it's 43 characters (valid Arweave address)
            if #authority == 43 then
              table.insert(_G.authorities, authority)
            end
            
            if not comma_pos then
              break
            end
            start_pos = comma_pos + 1
          end
        end
        
        break
      end
    end
  end
  
  -- Initialize colors table with terminal escape codes in _G and meta
  if not _G.colors then
    _G.colors = {
      -- Reset
      reset = "\27[0m",
      
      -- Regular colors
      black = "\27[30m",
      red = "\27[31m",
      green = "\27[32m",
      yellow = "\27[33m",
      blue = "\27[34m",
      magenta = "\27[35m",
      cyan = "\27[36m",
      white = "\27[37m",
      gray = "\27[90m",  -- Same as bright_black
      
      -- Bright colors
      bright_black = "\27[90m",
      bright_red = "\27[91m",
      bright_green = "\27[92m",
      bright_yellow = "\27[93m",
      bright_blue = "\27[94m",
      bright_magenta = "\27[95m",
      bright_cyan = "\27[96m",
      bright_white = "\27[97m",
      
      -- Background colors
      bg_black = "\27[40m",
      bg_red = "\27[41m",
      bg_green = "\27[42m",
      bg_yellow = "\27[43m",
      bg_blue = "\27[44m",
      bg_magenta = "\27[45m",
      bg_cyan = "\27[46m",
      bg_white = "\27[47m",
      
      -- Text styles
      bold = "\27[1m",
      dim = "\27[2m",
      italic = "\27[3m",
      underline = "\27[4m",
      blink = "\27[5m",
      reverse = "\27[7m",
      hidden = "\27[8m",
      strikethrough = "\27[9m"
    }
    -- Also store in meta for backward compatibility with tests
    _G.meta.colors = _G.colors
  end
  
  -- Also store authorities in meta for backward compatibility
  _G.meta.authorities = _G.authorities or {}

end

-- Private function to check if a message is trusted
-- A message is trusted if it has from-process equal to from and the committer is in authorities
function _G.meta.is_trusted(msg)
  -- Check if message has both from and from-process fields
  if not msg.from or not msg["from-process"] then
    return false
  end
  
  -- Check if from equals from-process
  if msg.from ~= msg["from-process"] then
    return false
  end
  
  -- Check if any commitment's committer is in the authorities list
  if msg.commitments and _G.authorities then
    for _, commitment in pairs(msg.commitments) do
      if commitment.committer then
        -- Check if this committer is in the authorities list
        for _, authority in ipairs(_G.authorities) do
          if commitment.committer == authority then
            return true
          end
        end
      end
    end
  end
  
  return false
end

-- Private function to ensure message has a 'from' field and check trust
-- Sets msg.from based on from-process or first non-HMAC signed commitment
-- Also sets msg.trusted based on authorities verification
function _G.meta.ensure_message(msg)
  -- If message already has 'from', leave it as is
  if msg.from then
    -- Still need to check trust even if from exists
    msg.trusted = _G.meta.is_trusted(msg)
    return msg
  end
  -- First check if there's a from-process field
  if msg["from-process"] then
    msg.from = msg["from-process"]
    -- Check trust after setting from
    msg.trusted = _G.meta.is_trusted(msg)
    return msg
  end
  -- Otherwise, find the first non-HMAC signed commitment's committer
  if msg.commitments then
    for key, commitment in pairs(msg.commitments) do
      if commitment.type and commitment.committer then
        -- Skip HMAC commitments
        if string.lower(commitment.type) ~= "hmac-sha256" then
          msg.from = commitment.committer
        end
      end
    end
  end
  -- If no from-process and no non-HMAC commitments, from remains nil
  -- Check trust after all from logic
  msg.trusted = _G.meta.is_trusted(msg)
  return msg
end

-- Private function to check if message has valid owner commitment
-- Validates that the message's from matches the global owner
function _G.meta.is_owner(msg)
  -- Ensure message has 'from' field
  _G.meta.ensure_message(msg)
  
  -- Check if msg.from matches the owner stored in _G
  if msg.from and _G.owner and msg.from == _G.owner then
    return true
  end
  
  return false
end

-- Private function to format and return new message notification
-- Formats the from address as first 3 + ... + last 3 chars in green
-- Shows first 20 chars of message content in blue
function _G.meta.printNewMessage(msg)
  -- Format the from address: first 3 chars + ... + last 3 chars
  local from_display = ""
  if msg.from then
    if #msg.from > 6 then
      from_display = string.sub(msg.from, 1, 3) .. "..." .. string.sub(msg.from, -3)
    else
      from_display = msg.from
    end
  else
    from_display = "unknown"
  end
  
  -- Get the message content (first 20 characters)
  local content = msg.data or msg.body or ""
  if #content > 20 then
    content = string.sub(content, 1, 20)
  end
  
  -- Format and return the message with colors
  return "New Message From " .. 
         _G.colors.green .. from_display .. _G.colors.reset .. 
         ": Data = " .. 
         _G.colors.blue .. content .. _G.colors.reset
end

-- override print function with colorized table support
---@diagnostic disable-next-line
function print(...)
  local args = {...}
  local output = {}
  
  for i, v in ipairs(args) do
    if type(v) == "table" then
      table.insert(output, stringify(v))
    else
      table.insert(output, tostring(v))
    end
  end
  
  _OUTPUT = _OUTPUT .. table.concat(output, "\t") .. "\n"
end

-- utility function to remove last CR
---@diagnostic disable-next-line
function removeCR(str)
    if str:sub(-1) == "\r" or str:sub(-1) == "\n" then
        return str:sub(1, -2)
    end
    return str
end

-- stringify utilities for colorized table printing
---@diagnostic disable-next-line
function isSimpleArray(tbl)
  local arrayIndex = 1
  for k, v in pairs(tbl) do
    if k ~= arrayIndex or (type(v) ~= "number" and type(v) ~= "string") then
      return false
    end
    arrayIndex = arrayIndex + 1
  end
  return true
end

---@diagnostic disable-next-line
function stringify(tbl, indent, visited)
  -- Handle non-table types
  if type(tbl) ~= "table" then
    if type(tbl) == "string" then
      return _G.colors.green .. '"' .. tbl .. '"' .. _G.colors.reset
    else
      return _G.colors.blue .. tostring(tbl) .. _G.colors.reset
    end
  end
  
  indent = indent or 0
  local toIndent = string.rep(" ", indent)
  local toIndentChild = string.rep(" ", indent + 2)

  local result = {}
  local isArray = true
  local arrayIndex = 1

  -- Handle simple arrays
  if isSimpleArray(tbl) then
    for _, v in ipairs(tbl) do
      if type(v) == "string" then
        v = _G.colors.green .. '"' .. v .. '"' .. _G.colors.reset
      else
        v = _G.colors.blue .. tostring(v) .. _G.colors.reset
      end
      table.insert(result, v)
    end
    return "{ " .. table.concat(result, ", ") .. " }"
  end

  -- Handle complex tables
  for k, v in pairs(tbl) do
    if isArray then
      if k == arrayIndex then
        arrayIndex = arrayIndex + 1
        if type(v) == "table" then
          v = stringify(v, indent + 2, visited)
        elseif type(v) == "string" then
          v = _G.colors.green .. '"' .. v .. '"' .. _G.colors.reset
        else
          v = _G.colors.blue .. tostring(v) .. _G.colors.reset
        end
        table.insert(result, toIndentChild .. v)
      else
        isArray = false
        result = {}
      end
    end
    if not isArray then
      if type(v) == "table" then
        visited = visited or {}
        if visited[v] then
            v = _G.colors.dim .. "<circular reference>" .. _G.colors.reset
        else
          visited[v] = true
          v = stringify(v, indent + 2, visited)
        end
      elseif type(v) == "string" then
        v = _G.colors.green .. '"' .. v .. '"' .. _G.colors.reset
      else
        v = _G.colors.blue .. tostring(v) .. _G.colors.reset
      end
      -- Format key with color
      local keyStr = tostring(k)
      if type(k) == "string" then
        keyStr = _G.colors.red .. keyStr .. _G.colors.reset
      else
        keyStr = _G.colors.yellow .. "[" .. keyStr .. "]" .. _G.colors.reset
      end
      table.insert(result, toIndentChild .. keyStr .. " = " .. v)
    end
  end

  local prefix = isArray and "{\n" or "{\n"
  local suffix = isArray and "\n" .. toIndent .. "}" or "\n" .. toIndent .. "}"
  local separator = isArray and ",\n" or ",\n"
  return prefix .. table.concat(result, separator) .. suffix
end

-- prompt function for console with colors
---@diagnostic disable-next-line
function prompt()
  -- Use colors if available, otherwise fallback to plain text
  if _G.colors and _G.colors.cyan then
    local c = _G.colors
    return c.cyan .. c.bold .. "hyper" .. c.reset .. 
           c.white .. "~" .. c.reset .. 
           c.bright_green .. "aos" .. c.reset .. 
           c.white .. "@" .. c.reset .. 
           c.yellow .. require('.process')._version .. c.reset .. 
           c.white .. "[" .. c.reset .. 
           c.bright_magenta .. #Inbox .. c.reset .. 
           c.white .. "]" .. c.reset .. 
           c.bright_blue .. "> " .. c.reset
  else
    return "hyper~aos@" .. require('.process')._version .. "[" .. #Inbox .. "]> "
  end
end

-- send function for dispatching messages to other processes
---@diagnostic disable-next-line
function send(msg)
  -- Initialize results table if needed
  _G.results = _G.results or {}
  _G.results.outbox = _G.results.outbox or {}
  table.insert(_G.results.outbox, msg)
end

-- eval function, this function allows you update your process
---@diagnostic disable-next-line
function eval(msg)
  -- Security check: validate commitments
  if not _G.meta.is_owner(msg) then
    print("Unauthorized: eval requires owner signed message")
    return "ok"
  end
  -- Original eval logic
  local expr = msg.body or msg.data or ""
  local func, err = load("return " .. expr, 'aos', 't', _G)
  local output = ""
  local e = nil
  if err then
    func, err = load(expr, 'aos', 't', _G)
  end
  if func then
    output, e = func()
  else
    return err
  end

  if e then
    return e
  end

  return output
end

-- List of Lua built-in keys to exclude when serializing state
-- This ensures we only return user data, not system functions/tables
local SYSTEM_KEYS = {
  -- Lua built-in functions
  "assert", "collectgarbage", "dofile", "error", "getmetatable", "ipairs",
  "load", "loadfile", "loadstring", "next", "pairs", "pcall", "print",
  "rawequal", "rawget", "rawlen", "rawset", "require", "select",
  "setmetatable", "tonumber", "tostring", "type", "xpcall", "_VERSION",
  
  -- Lua built-in libraries
  "coroutine", "debug", "io", "math", "os", "package", "string", "table", "utf8",
  
  -- AOS specific functions that shouldn't be serialized
  "compute", "eval", "send", "prompt", "removeCR", "isSimpleArray", "stringify", "Handlers",
  
  -- Private/temporary variables
  "_OUTPUT", "MAX_INBOX_SIZE", "SYSTEM_KEYS", "meta",
  
  -- These will be handled specially or excluded
  "State", "_G"
  
  -- NOTE: We explicitly DO NOT exclude: id, owner, authorities, colors, Inbox
  -- These are process state that should be persisted
}

--- Recursively copy a table, handling circular references
-- @param tbl table The table to copy
-- @param visited table Table tracking visited tables for circular reference detection
-- @return table The copied table
local function copy_table_recursive(tbl, visited)
  local copy = {}
  for k, v in pairs(tbl) do
    local value_type = type(v)
    if value_type == "table" then
      -- Check for circular reference
      if visited[v] then
        copy[k] = "<circular reference>"
      else
        -- Mark this table as visited
        visited[v] = true
        -- Recursively copy the table
        copy[k] = copy_table_recursive(v, visited)
        -- Unmark after processing
        visited[v] = nil
      end
    elseif value_type ~= "function" then
      -- Copy non-function values
      copy[k] = v
    end
    -- Skip functions entirely
  end
  return copy
end

--- Extract user state from _G, filtering out system keys and functions
-- Handles circular references properly to avoid infinite loops
-- @param visited table Optional table to track visited tables for circular reference detection
-- @return table The filtered state containing only user data
local function extract_state_from_global(visited)
  visited = visited or {}
  local state = {}
  
  -- Create a lookup table for system keys for O(1) access
  local system_keys_set = {}
  for _, key in ipairs(SYSTEM_KEYS) do
    system_keys_set[key] = true
  end
  
  -- Iterate through all keys in _G
  for key, value in pairs(_G) do
    -- Skip system keys and functions
    if not system_keys_set[key] and type(value) ~= "function" then
      local value_type = type(value)
      if value_type == "table" then
        -- Check for circular reference
        if visited[value] then
          state[key] = "<circular reference>"
        else
          -- Mark this table as visited
          visited[value] = true
          -- Recursively copy the table
          state[key] = copy_table_recursive(value, visited)
          -- Unmark after processing (allows same table in different paths)
          visited[value] = nil
        end
      else
        -- For non-table values, just copy them
        state[key] = value
      end
    end
  end
  
  return state
end

--- Main entry point for message processing
-- Processes messages and manages state directly in _G
-- @param state table The incoming state (merged into _G on first call)
-- @param assignment table The message assignment to process
-- @return string Status ("ok")
-- @return table The filtered state extracted from _G
function compute(state, assignment)
  -- Clear output buffer
  _G._OUTPUT = ""
  
  -- On first message or when state is provided, merge it into _G
  -- This allows the process to restore previous state
  if state and next(state) then
    -- Create a lookup table for system keys for O(1) access
    local system_keys_set = {}
    for _, key in ipairs(SYSTEM_KEYS) do
      system_keys_set[key] = true
    end
    
    for key, value in pairs(state) do
      -- Don't overwrite system keys or functions
      if type(_G[key]) ~= "function" and not system_keys_set[key] then
        _G[key] = value
      end
    end
  end
  
  -- Initialize results structure in _G
  _G.results = _G.results or {}
  _G.results.outbox = {}
  _G.results.output = { data = "", prompt = prompt() }
  _G.results.info = "hyper-aos"
  
  -- Extract message from assignment
  local msg = assignment.body or {}
  
  -- Ensure message has 'from' field
  msg = _G.meta.ensure_message(msg)
  
  -- Initialize process state from first Process message
  if not _G.meta.initialized then
    _G.meta.init(msg)
  end
  
  -- Extract and normalize action
  local action = msg.action or ""
  action = string.lower(action)

  local status, result = false, ""

  -- Handle actions by calling global functions
  --if action ~= "compute" and type(_G[action]) == "function" then
  if action == "eval" then
    status, result = pcall(_G[action], msg)
  elseif action ~= "" then
    status, result = pcall(Handlers.evaluate, msg, {})
  else
    -- If not handled, add to inbox
    result = _G.meta.printNewMessage(msg)
    
    table.insert(_G.Inbox, msg)
    -- Implement FIFO rotation when inbox exceeds limit
    if #_G.Inbox > _G.MAX_INBOX_SIZE then
      table.remove(_G.Inbox, 1)
    end
  end

  -- Set execution status
  _G.results.status = "ok"
  if not status and result ~= "" then
    _G.results.status = "error"
  end

  -- Format output based on result type
  if type(result) == "table" then
    _G.results.output.data = result
  else
    print(tostring(result))
    _G.results.output.data = removeCR(_G._OUTPUT)
  end

  -- Set print flag for non-eval actions
  if action ~= "eval" then
    _G.results.output.print = true
  end
  
  -- Extract state from _G, filtering out system keys and functions
  -- This creates a clean state object containing only user data
  local filtered_state = extract_state_from_global()
  
  -- Include the results in the filtered state for the response
  filtered_state.results = _G.results
  
  -- For backward compatibility with tests, include meta table
  -- This provides access to colors and authorities for testing
  filtered_state.meta = {
    initialized = _G.meta.initialized,
    owner = _G.owner or "",
    id = _G.id or "",
    authorities = _G.meta.authorities or _G.authorities or {},
    colors = _G.meta.colors or _G.colors or {}
  }
  
  -- Return status and filtered state
  -- The state will be persisted and passed back in the next compute call
  return "ok", filtered_state
end




end
