local RoleDisplaySystem = require("RoleDisplaySystem/Shared")

RoleDisplaySystem.Client = {}
RoleDisplaySystem.Client.Commands = {}

function RoleDisplaySystem.Client.Commands.LoadRoles(args)
	if type(args) ~= "table" then
		args = {}
	end

	RoleDisplaySystem.Roles = args

	if RoleDisplaySystem.UI_Manager.instance and RoleDisplaySystem.UI_Manager.instance:isVisible() then
		RoleDisplaySystem.UI_Manager.instance:updateRoleList()
	end
end

function RoleDisplaySystem.Client.Commands.RoleResponse(args)
	if not args then
		return
	end

	if args.messageKey then
		local message = getText(args.messageKey, args.messageArgs and args.messageArgs.roleName or "")
	end

	if RoleDisplaySystem.UI_Manager.instance and RoleDisplaySystem.UI_Manager.instance:isVisible() then
		RoleDisplaySystem.UI_Manager.instance:updateRoleList()
	end
end

function RoleDisplaySystem.Client.OnServerCommand(module, command, args)
	if module ~= "RoleDisplaySystem" then
		return
	end

	if RoleDisplaySystem.Client.Commands[command] then
		RoleDisplaySystem.Client.Commands[command](args)
	end
end

Events.OnServerCommand.Add(RoleDisplaySystem.Client.OnServerCommand)

function RoleDisplaySystem.Client.AddRole(roleData)
	sendClientCommand("RoleDisplaySystem", "AddRole", {
		newRole = roleData,
	})
end

function RoleDisplaySystem.Client.RemoveRole(roleId)
	sendClientCommand("RoleDisplaySystem", "RemoveRole", {
		roleId = roleId,
	})
end

function RoleDisplaySystem.Client.UpdateRole(roleData)
	sendClientCommand("RoleDisplaySystem", "UpdateRole", {
		roleData = roleData,
	})
end

function RoleDisplaySystem.Client.AddPlayerToRole(roleId, username)
	sendClientCommand("RoleDisplaySystem", "ModifyRolePlayers", {
		roleId = roleId,
		action = "add",
		usernames = { username },
	})
end

function RoleDisplaySystem.Client.RemovePlayerFromRole(roleId, username)
	sendClientCommand("RoleDisplaySystem", "ModifyRolePlayers", {
		roleId = roleId,
		action = "remove",
		usernames = { username },
	})
end

function RoleDisplaySystem.Client.AddPlayersToRole(roleId, usernames)
	sendClientCommand("RoleDisplaySystem", "ModifyRolePlayers", {
		roleId = roleId,
		action = "add",
		usernames = usernames,
	})
end

local doCommand = false
local function sendCommand()
	if doCommand then
		RoleDisplaySystem.Roles = RoleDisplaySystem.Shared.RequestRoles()
		Events.OnTick.Remove(sendCommand)
	end
	doCommand = true
end
Events.OnTick.Add(sendCommand)

return RoleDisplaySystem.Client
