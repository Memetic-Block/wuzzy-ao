local WuzzyTxOracleTest = {
  State = {
    OracleId = nil
  }
}

WuzzyTxOracleTest.State.OracleId = WuzzyTxOracleTest.State.OracleId or
  ao.env.Process.Tags['Oracle-Id']

function WuzzyTxOracleTest.init()
  local ACL = require('..common.acl')

  require('..common.handlers.acl')(ACL)
  require('..common.handlers.state')(WuzzyTxOracleTest)

  Handlers.add(
    'Get-Block',
    Handlers.utils.hasMatchingTag('Action', 'Get-Block'),
    function (msg)
      ACL.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Get-Block' })
      assert(WuzzyTxOracleTest.State.OracleId ~= nil, 'Oracle-Id is not set!')

      local blockHeight = msg.Tags['Block-Height']
      assert(blockHeight ~= nil, 'Block-Height tag is required for Get-Block')

      ao.send({
        Target = WuzzyTxOracleTest.State.OracleId,
        Action = 'Get-Block',
        ['Block-Height'] = blockHeight
      })
    end
  )

  Handlers.add(
    'Get-Transaction',
    Handlers.utils.hasMatchingTag('Action', 'Get-Transaction'),
    function (msg)
      ACL.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Get-Transaction' })
      assert(WuzzyTxOracleTest.State.OracleId ~= nil, 'Oracle-Id is not set!')

      local txId = msg.Tags['Transaction-Id']
      assert(txId ~= nil, 'Transaction-Id tag is required for Get-Transaction')

      ao.send({
        Target = WuzzyTxOracleTest.State.OracleId,
        Action = 'Get-Transaction',
        ['Transaction-Id'] = txId
      })
    end
  )

  Handlers.add(
    'Get-Data',
    Handlers.utils.hasMatchingTag('Action', 'Get-Data'),
    function (msg)
      ACL.assertHasOneOfRole(msg.From, { 'owner', 'admin', 'Get-Data' })
      assert(WuzzyTxOracleTest.State.OracleId ~= nil, 'Oracle-Id is not set!')

      local txId = msg.Tags['Transaction-Id']
      assert(txId ~= nil, 'Transaction-Id tag is required for Get-Data')

      ao.send({
        Target = WuzzyTxOracleTest.State.OracleId,
        Action = 'Get-Data',
        ['Transaction-Id'] = txId
      })
    end
  )
end

WuzzyTxOracleTest.init()
