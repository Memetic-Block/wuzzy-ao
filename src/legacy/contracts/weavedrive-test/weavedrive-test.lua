local WeaveDriveTest = {}

function WeaveDriveTest.init()
  local json = require('json')
  local ACL = require('..common.acl')
  local WeaveDrive = require('..common.weavedrive')

  require('..common.handlers.acl')(ACL)
  require('..common.handlers.state')(WeaveDriveTest)

  Handlers.add(
    'WeaveDrive-Get-Block',
    Handlers.utils.hasMatchingTag('Action', 'WeaveDrive-Get-Block'),
    function (msg)
      ACL.assertHasOneOfRole(
        msg.From,
        { 'owner', 'admin', 'WeaveDrive-Get-Block' }
      )

      local blockHeight = msg.Tags['Block-Height']
      assert(
        blockHeight ~= nil,
        'Block-Height tag is required for WeaveDrive-Get-Block'
      )

      local status, errOrBlock, wdError = pcall(
        WeaveDrive.getBlock,
        blockHeight
      )

      if not status then
        ao.send({
          Target = msg.From,
          Action = 'WeaveDrive-Get-Block-Error',
          Tags = { ['Error-Type'] = 'pcall' },
          Data = errOrBlock
        })
        return
      end

      if wdError then
        ao.send({
          Target = msg.From,
          Action = 'WeaveDrive-Get-Block-Error',
          Tags = { ['Error-Type'] = 'WeaveDrive' },
          Data = wdError
        })
        return
      end

      ao.send({
        Target = msg.From,
        Action = 'WeaveDrive-Get-Block-Response',
        Tags = { ['Block-Height'] = blockHeight },
        Data = json.encode(errOrBlock)
      })
    end
  )

  Handlers.add(
    'WeaveDrive-Get-Tx',
    Handlers.utils.hasMatchingTag('Action', 'WeaveDrive-Get-Tx'),
    function (msg)
      ACL.assertHasOneOfRole(
        msg.From,
        { 'owner', 'admin', 'WeaveDrive-Get-Tx' }
      )

      local txId = msg.Tags['Tx-Id']
      assert(txId ~= nil, 'Tx-Id tag is required for WeaveDrive-Get-Tx')

      local status, errOrTx, wdError = pcall(WeaveDrive.getTransaction, txId)

      if not status then
        ao.send({
          Target = msg.From,
          Action = 'WeaveDrive-Get-Tx-Error',
          Tags = { ['Error-Type'] = 'pcall' },
          Data = errOrTx
        })
        return
      end

      if wdError then
        ao.send({
          Target = msg.From,
          Action = 'WeaveDrive-Get-Tx-Error',
          Tags = { ['Error-Type'] = 'WeaveDrive' },
          Data = wdError
        })
        return
      end

      ao.send({
        Target = msg.From,
        Action = 'WeaveDrive-Get-Tx-Response',
        Tags = { ['Tx-Id'] = txId },
        Data = json.encode(errOrTx)
      })
    end
  )

  Handlers.add(
    'WeaveDrive-Get-Data',
    Handlers.utils.hasMatchingTag('Action', 'WeaveDrive-Get-Data'),
    function (msg)
      ACL.assertHasOneOfRole(
        msg.From,
        { 'owner', 'admin', 'WeaveDrive-Get-Data' }
      )

      local txId = msg.Tags['Tx-Id']
      assert(txId ~= nil, 'Tx-Id tag is required for WeaveDrive-Get-Data')

      local status, errOrData, wdError = pcall(WeaveDrive.getData, txId)

      if not status then
        ao.send({
          Target = msg.From,
          Action = 'WeaveDrive-Get-Data-Error',
          Tags = { ['Error-Type'] = 'pcall' },
          Data = errOrData
        })
        return
      end

      if wdError then
        ao.send({
          Target = msg.From,
          Action = 'WeaveDrive-Get-Data-Error',
          Tags = { ['Error-Type'] = 'WeaveDrive' },
          Data = wdError
        })
        return
      end

      ao.send({
        Target = msg.From,
        Action = 'WeaveDrive-Get-Data-Response',
        Tags = { ['Tx-Id'] = txId },
        Data = json.encode(errOrData)
      })
    end
  )
end

WeaveDriveTest.init()

-- --- @class TransactionHeaders
-- --- @field tags { [number]: { name: string, value: string } }
-- --- @field id string The transaction id
-- --- @field owner string The owner pubkey of the transaction
-- --- @field ownerAddress string The owner address of the transaction
-- --- @field signature string The signature of the transaction
-- --- @field format number The format of the transaction
-- --- @field target string The target of the transaction
-- --- @field quantity string The quantity of the transaction
-- --- @field data_root string The data root of the transaction
-- --- @field last_tx string The last transaction id anchor
-- --- @field data_size string The data size of the transaction
-- --- @field reward string The reward of the transaction
-- local tx, getTxErr = WeaveDrive.getTx(transactionId)
-- if getTxErr then
--   return nil, 'Unable to fetch transaction headers: ' .. getTxErr
-- end
