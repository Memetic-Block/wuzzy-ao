local ACLUtils = {
  State = {
    Roles = {
      -- admin   = { 'address1' = true, 'address2' = true }
      -- [role1] = { 'address3' = true, 'address4' = true }
      -- [role2] = { 'address5' = true, 'address6' = true }
    }
  }
}

function ACLUtils.assertHasOneOfRole(address, roles)
  for _, role in pairs(roles) do
    
    if role == 'owner' and address == owner then
      return true
    elseif ACLUtils.State.Roles[role]
      and ACLUtils.State.Roles[role][address] ~= nil
    then
      return true
    end
  end
  assert(false, 'Permission Denied')
end

function ACLUtils.updateRoles(updateRolesDto, state)
  state = state or ACLUtils.State

  if updateRolesDto.Grant ~= nil then
    for address, roles in pairs(updateRolesDto.Grant) do
      assert(
        type(address) == 'string',
        'Address must be a string: ' .. tostring(address)
      )
      assert(type(roles) == 'table', 'Granted roles must be a list of strings')
      for _, role in pairs(roles) do
        assert(
          type(role) == 'string',
          'Role must be a string: ' .. tostring(role)
        )
        if state.Roles[role] == nil then
          state.Roles[role] = {}
        end
        state.Roles[role][address] = true
      end
    end
  end

  if updateRolesDto.Revoke ~= nil then
    for address, roles in pairs(updateRolesDto.Revoke) do
      assert(
        type(address) == 'string',
        'Address must be a string: ' .. tostring(address)
      )
      assert(type(roles) == 'table', 'Revoked roles must be a list of strings')
      for _, role in pairs(roles) do
        assert(
          type(role) == 'string',
          'Role must be a string: ' .. tostring(role)
        )
        if state.Roles[role] == nil then
          state.Roles[role] = {}
        end
        state.Roles[role][address] = nil
      end
    end
  end
end

return ACLUtils
