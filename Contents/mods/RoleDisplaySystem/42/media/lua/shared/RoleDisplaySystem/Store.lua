local RoleDisplaySystem = require("RoleDisplaySystem/Shared")

RoleDisplaySystem.Store = RoleDisplaySystem.Store or {}

local Store = RoleDisplaySystem.Store
Store.MOD_DATA_KEY = "RoleManager_Roles"

local function normalizeRoles(roles)
	if type(roles) ~= "table" then
		return {}
	end
	return roles
end

function Store.LoadRoles()
	local roles = RoleDisplaySystem.Roles

	if ModData and ModData.getOrCreate then
		roles = ModData.getOrCreate(Store.MOD_DATA_KEY)
	end

	roles = normalizeRoles(roles)
	RoleDisplaySystem.Roles = roles
	return roles
end

function Store.SaveRoles(roles)
	roles = normalizeRoles(roles)
	RoleDisplaySystem.Roles = roles

	if ModData and ModData.add then
		ModData.add(Store.MOD_DATA_KEY, roles)
	end

	return roles
end

function Store.PushLocalRoles(roles)
	roles = Store.SaveRoles(roles)

	if RoleDisplaySystem.Client
		and RoleDisplaySystem.Client.Commands
		and RoleDisplaySystem.Client.Commands.LoadRoles
	then
		RoleDisplaySystem.Client.Commands.LoadRoles(roles)
	end
end

return Store
