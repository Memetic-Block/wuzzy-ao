function registry_info(state, req)
  local result = {
    owner = state.nest_registry_owner,
    registration_code_required = state.registration_code_required
  }

  local roles = ''
  for role, addresses in pairs(state.acl.roles) do
    roles = roles .. role .. (roles == '' and '' or ',')
    for address, _ in pairs(addresses) do
      result['acl_'..role..'_'..address] = true
    end
  end
  result.roles = roles

  local total_nests = 0
  for i, nest in ipairs(state.nests) do
    total_nests = total_nests + 1
    result['nest_'..i..'_id'] = nest.id
    result['nest_'..i..'_owner'] = nest.owner
    result['nest_'..i..'_acl'] = nest.acl
  end
  result.total_nests = total_nests

  local total_registration_codes = 0
  for code, _ in pairs(state.registration_codes) do
    if code ~= 'commitments' then
      total_registration_codes = total_registration_codes + 1
      result['registration_code_'..total_registration_codes] = code
    end
  end
  result.total_registration_codes = total_registration_codes

  return result
end

function nests_by_address(state, req)
  local address = req.address
  local result = {}
  for _i, nest in ipairs(state.nests) do
    if nest.owner == address then
      table.insert(result, nest)
    else
      for _role, addresses in pairs(nest.acl.roles) do
        if addresses[address] then
          table.insert(result, nest)
          break
        end
      end
    end
  end
  return result
end
