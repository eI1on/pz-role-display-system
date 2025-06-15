local Logger = require("RoleDisplaySystem/Logger")
local RoleDisplaySystem = require("RoleDisplaySystem/Shared")

RoleDisplaySystem.Server = {}
RoleDisplaySystem.Server.ServerCommands = {}

local DATA_DIR = "RoleDisplaySystem"
local ROLES_FILE = DATA_DIR .. "/roles.json"

--------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------

local function formatRoleInfo(role)
	local info = string.format(
		"[Name: %s] [ID: %s] [Priority: %s] [Style: %s]",
		role.name or "N/A",
		role.id or "N/A",
		role.priority or "1",
		role.bracketStyle or "square"
	)

	if role.players then
		info = info .. string.format(" [Players: %d]", #role.players)
	end

	return info
end

local function writeServerLog(logText)
	writeLog("admin", logText)
end

--------------------------------------------------
-- DATA MANAGEMENT
--------------------------------------------------

function RoleDisplaySystem.Server.SaveRoles(roles)
	RoleDisplaySystem.Roles = roles
end

function RoleDisplaySystem.Server.LoadRoles()
	RoleDisplaySystem.Roles = ModData.getOrCreate("RoleManager_Roles")
	return RoleDisplaySystem.Roles
end

--------------------------------------------------
-- PUSHING UPDATES TO CLIENTS
--------------------------------------------------

function RoleDisplaySystem.Server.PushRolesToAll(roles)
	if isServer() then
		sendServerCommand("RoleDisplaySystem", "LoadRoles", roles)
	else
		RoleDisplaySystem.Roles = roles
		RoleDisplaySystem.Client.Commands.LoadRoles(roles)
	end
end

function RoleDisplaySystem.Server.PushRolesToPlayer(player, roles)
	if isServer() then
		sendServerCommand(player, "RoleDisplaySystem", "LoadRoles", roles)
	else
		RoleDisplaySystem.Roles = roles
		RoleDisplaySystem.Client.Commands.LoadRoles(roles)
	end
end

--------------------------------------------------
-- SERVER COMMAND HANDLERS
--------------------------------------------------

function RoleDisplaySystem.Server.ServerCommands.LoadRoles(player, args)
	local roles = RoleDisplaySystem.Server.LoadRoles()
	if args and args.toAll then
		RoleDisplaySystem.Server.PushRolesToAll(roles)
	else
		RoleDisplaySystem.Server.PushRolesToPlayer(player, roles)
	end
end

function RoleDisplaySystem.Server.ServerCommands.AddRole(player, args)
	local roles = RoleDisplaySystem.Shared.RequestRoles()

	local newRole = args.newRole
	if not newRole then
		sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
			success = false,
			messageKey = "IGUI_RM_InvalidRoleData",
		})
		return
	end

	local isValid, errorMessage = RoleDisplaySystem.Shared.ValidateRoleData(newRole)
	if not isValid then
		sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
			success = false,
			messageKey = "IGUI_RM_InvalidRoleData",
			error = errorMessage,
		})
		return
	end

	if not newRole.id then
		newRole.id = RoleDisplaySystem.Shared.GenerateRoleId()
	end

	newRole.players = newRole.players or {}
	newRole.priority = newRole.priority or 1
	newRole.bracketStyle = newRole.bracketStyle or "square"
	newRole.color = newRole.color or { r = 1, g = 1, b = 1, a = 1 }

	roles[newRole.id] = newRole
	RoleDisplaySystem.Server.SaveRoles(roles)
	RoleDisplaySystem.Server.PushRolesToAll(roles)

	sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
		success = true,
		messageKey = "IGUI_RM_RoleCreated",
		messageArgs = { roleName = newRole.name },
		roleId = newRole.id,
	})

	local logText = string.format(
		"[Admin: %s] [SteamID: %s] [Role: %s] Added Role: %s",
		tostring(player:getUsername() or "Unknown"),
		tostring(player:getSteamID() or "0"),
		tostring(player:getAccessLevel() or "None"),
		tostring(formatRoleInfo(newRole))
	)
	writeServerLog(logText)
end

function RoleDisplaySystem.Server.ServerCommands.RemoveRole(player, args)
	local roles = RoleDisplaySystem.Shared.RequestRoles()

	local roleId = args.roleId
	local role = roles[roleId]

	if not role then
		sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
			success = false,
			messageKey = "IGUI_RM_RoleNotFound",
		})
		return
	end

	local roleName = role.name
	roles[roleId] = nil

	RoleDisplaySystem.Server.SaveRoles(roles)
	RoleDisplaySystem.Server.PushRolesToAll(roles)

	sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
		success = true,
		messageKey = "IGUI_RM_RoleDeleted",
		messageArgs = { roleName = roleName },
	})

	local logText = string.format(
		"[Admin: %s] [SteamID: %s] [Role: %s] Removed Role: %s",
		tostring(player:getUsername() or "Unknown"),
		tostring(player:getSteamID() or "0"),
		tostring(player:getAccessLevel() or "None"),
		tostring(formatRoleInfo(role))
	)
	writeServerLog(logText)
end

function RoleDisplaySystem.Server.ServerCommands.UpdateRole(player, args)
	local roles = RoleDisplaySystem.Shared.RequestRoles()

	local roleData = args.roleData
	if not roleData or not roleData.id then
		sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
			success = false,
			messageKey = "IGUI_RM_InvalidRoleData",
		})
		return
	end

	local role = roles[roleData.id]
	if not role then
		sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
			success = false,
			messageKey = "IGUI_RM_RoleNotFound",
		})
		return
	end

	local isValid, errorMessage = RoleDisplaySystem.Shared.ValidateRoleData(roleData)
	if not isValid then
		sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
			success = false,
			messageKey = "IGUI_RM_InvalidRoleData",
			error = errorMessage,
		})
		return
	end

	role.name = roleData.name
	role.color = roleData.color or role.color
	role.bracketStyle = roleData.bracketStyle or role.bracketStyle
	role.priority = roleData.priority or role.priority

	RoleDisplaySystem.Server.SaveRoles(roles)
	RoleDisplaySystem.Server.PushRolesToAll(roles)

	sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
		success = true,
		messageKey = "IGUI_RM_RoleUpdated",
		messageArgs = { roleName = role.name },
	})

	local logText = string.format(
		"[Admin: %s] [SteamID: %s] [Role: %s] Updated Role: %s",
		tostring(player:getUsername() or "Unknown"),
		tostring(player:getSteamID() or "0"),
		tostring(player:getAccessLevel() or "None"),
		tostring(formatRoleInfo(role))
	)
	writeServerLog(logText)
end

function RoleDisplaySystem.Server.ServerCommands.ModifyRolePlayers(player, args)
	local roles = RoleDisplaySystem.Shared.RequestRoles()

	local roleId = args.roleId
	local action = args.action
	local usernames = args.usernames or {}

	local role = roles[roleId]
	if not role then
		sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
			success = false,
			messageKey = "IGUI_RM_RoleNotFound",
		})
		return
	end

	if not role.players then
		role.players = {}
	end

	if action == "add" then
		local addedCount = 0
		for _, targetUsername in ipairs(usernames) do
			local alreadyInRole = RoleDisplaySystem.Shared.IsPlayerInRole(targetUsername, roleId)
			if not alreadyInRole then
				table.insert(role.players, targetUsername)
				addedCount = addedCount + 1
			end
		end

		sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
			success = true,
			messageKey = "IGUI_RM_PlayersAdded",
			messageArgs = { count = addedCount, roleName = role.name },
		})
	elseif action == "remove" then
		local removedCount = 0
		for _, targetUsername in ipairs(usernames) do
			for i = #role.players, 1, -1 do
				if role.players[i] == targetUsername then
					table.remove(role.players, i)
					removedCount = removedCount + 1
					break
				end
			end
		end

		sendServerCommand(player, "RoleDisplaySystem", "RoleResponse", {
			success = true,
			messageKey = "IGUI_RM_PlayersRemoved",
			messageArgs = { count = removedCount, roleName = role.name },
		})
	end

	RoleDisplaySystem.Server.SaveRoles(roles)
	RoleDisplaySystem.Server.PushRolesToAll(roles)
end

--------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------

function RoleDisplaySystem.Server.GetPlayerByUsername(username)
	local players = getOnlinePlayers()
	if not players then
		return nil
	end
	for i = 0, players:size() - 1 do
		local player = players:get(i)
		if player and player:getUsername() == username then
			return player
		end
	end
	return nil
end

--------------------------------------------------
-- INITIALIZATION
--------------------------------------------------

function RoleDisplaySystem.Server.init()
	local roles = RoleDisplaySystem.Server.LoadRoles()
end

function RoleDisplaySystem.Server.onClientCommand(module, command, player, args)
	if module ~= "RoleDisplaySystem" then
		return
	end

	if RoleDisplaySystem.Server.ServerCommands[command] then
		RoleDisplaySystem.Server.ServerCommands[command](player, args)
	end
end

Events.OnInitGlobalModData.Remove(RoleDisplaySystem.Server.init)
Events.OnInitGlobalModData.Add(RoleDisplaySystem.Server.init)

Events.OnClientCommand.Remove(RoleDisplaySystem.Server.onClientCommand)
Events.OnClientCommand.Add(RoleDisplaySystem.Server.onClientCommand)

return RoleDisplaySystem.Server
