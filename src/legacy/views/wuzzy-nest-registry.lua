-- 64J-FBSrijo_KuF4LAaKoHFgkJM6RSJZoyCBmUUSzPI

function registry_info(base, req)
  local state = base.WuzzyNestRegistry.State
  local result = {}

  local count = 1
  for id, nest in pairs(state.Nests) do
    result['nest_'..count..'_id'] = id
    result['nest_'..count..'_owner'] = nest.Owner
    count = count + 1
  end

  result['total_nests'] = count

  return result
end
