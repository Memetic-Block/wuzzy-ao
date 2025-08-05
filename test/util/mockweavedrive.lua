-- module: "..common.weavedrive"

local function _loaded_mod__common_weavedrive()
--[[
  MOCK WeaveDrive Client
]]

local drive = {
	_version = "0.0.1"
}

local MOCK_WEAVEDRIVE_BLOCKS = {}
local MOCK_WEAVEDRIVE_TXS = {}
local MOCK_WEAVEDRIVE_DATA = {}

_MockWeaveDriveGetBlockCalls = {}
function drive.getBlock(height)
	_MockWeaveDriveGetBlockCalls[#_MockWeaveDriveGetBlockCalls + 1] = height
	local block = MOCK_WEAVEDRIVE_BLOCKS[height]
	if not block then
		return nil, "Block Header not found!"
	end

	return require("json").decode(block)
end

_MockWeaveDriveGetTxCalls = {}
function drive.getTx(txId)
	_MockWeaveDriveGetTxCalls[#_MockWeaveDriveGetTxCalls + 1] = txId
	local tx = MOCK_WEAVEDRIVE_TXS[txId]
	if not tx then
		return nil, "File not found!"
	end

	return require("json").decode(tx)
end

_MockWeaveDriveGetDataCalls = { }
function drive.getData(txId)
	_MockWeaveDriveGetDataCalls[#_MockWeaveDriveGetDataCalls + 1] = txId
	local data = MOCK_WEAVEDRIVE_DATA[txId]
	if not data then
		return nil, "File not found!"
	end

	return data
end

return drive

end

_G.package.loaded["..common.weavedrive"] = _loaded_mod__common_weavedrive()
