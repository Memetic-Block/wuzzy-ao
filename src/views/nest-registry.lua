function registry_info(state, req)
  local result = {
    owner = state.Owner,
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
  for i, code in ipairs(state.registration_codes) do
    total_registration_codes = total_registration_codes + 1
    result['registration_code_'..i] = code
  end
  result.total_registration_codes = total_registration_codes

  return result
end
