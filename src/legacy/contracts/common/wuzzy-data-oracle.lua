local WuzzyDataOracle = {}

function WuzzyDataOracle.getBlock(oracleAddress, height)
  assert(oracleAddress ~= nil, 'Data-Oracle-Address is not set!')
  assert(height ~= nil, 'Block height is required')

  ao.send({
    Target = oracleAddress,
    Action = 'Get-Block',
    ['Block-Height'] = height
  })
end

function WuzzyDataOracle.getTx(oracleAddress, txId)
  assert(oracleAddress ~= nil, 'Data-Oracle-Address is not set!')
  assert(txId ~= nil, 'Transaction ID is required')

  ao.send({
    Target = oracleAddress,
    Action = 'Get-Transaction',
    ['Transaction-Id'] = txId
  })
end

function WuzzyDataOracle.getData(oracleAddress, txId)
  assert(oracleAddress ~= nil, 'Data-Oracle-Address is not set!')
  assert(txId ~= nil, 'Transaction ID is required')

  ao.send({
    Target = oracleAddress,
    Action = 'Get-Data',
    ['Transaction-Id'] = txId,
    Raw = 'true'
  })
end

return WuzzyDataOracle
