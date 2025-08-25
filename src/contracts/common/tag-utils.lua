local TagUtils = {}

---@param tags table Tags to search through
---@param name string Tag name to find the value for
---@return string|nil The value of the tag or nil if not found
function TagUtils.findEncoded(tags, name)
  local base64 = require('.base64')

  for _, tag in ipairs(tags) do
    for _, pad in ipairs({ '', '==', '=' }) do
      local nameSuccess, nameResult = pcall(base64.decode, tag.name..pad)
      if nameSuccess and nameResult == name and type(tag.value) == 'string' then
        for _, pad2 in ipairs({ '', '==', '=' }) do
          local valueSuccess, valueResult = pcall(
            base64.decode,
            tag.value..pad2
          )
          if valueSuccess and valueResult then
            return valueResult
          end
        end
        break
      end
    end
  end

  return nil
end

---@param tags table Tags to search through
---@param name string Tag name to find the value for
---@return string|nil The value of the tag or nil if not found
function TagUtils.find(tags, name)
  for _, tag in ipairs(tags) do
    if tag.name == name then
      return tag.value
    end
  end

  return nil
end

return TagUtils