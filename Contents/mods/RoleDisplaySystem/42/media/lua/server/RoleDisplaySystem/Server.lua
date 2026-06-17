local Logger = require("RoleDisplaySystem/Logger")
local RoleDisplaySystem = require("RoleDisplaySystem/Shared")
local RoleStore = require("RoleDisplaySystem/Store")

local previousServer = RoleDisplaySystem.Server
if previousServer then
	if previousServer.init then
		Events.OnInitGlobalModData.Remove(previousServer.init)
	end
	if previousServer.onClientCommand then
		Events.OnClientCommand.Remove(previousServer.onClientCommand)
	end
end

RoleDisplaySystem.Server = RoleDisplaySystem.Server or {}
RoleDisplaySystem.Server.ServerCommands = {}

local MODULE = "RoleDisplaySystem"

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

local function getPlayerLogName(player)
	return player and tostring(player:getUsername() or "Unknown") or "Local"
end

local function getPlayerLogSteamID(player)
	return player and tostring(player:getSteamID() or "0") or "0"
end

local function getPlayerRole(player)
	if player and player.getRole then
		return player:getRole()
	end
	return nil
end

local function getRoleName(role)
	if role and role.getName then
		return tostring(role:getName() or "None")
	end
	return "None"
end

local function normalizeAccessName(accessLevel)
	accessLevel = tostring(accessLevel or "None"):lower()

	if accessLevel == "admin" then
		return "Admin"
	elseif accessLevel == "moderator" then
		return "Moderator"
	elseif accessLevel == "overseer" then
		return "Overseer"
	elseif accessLevel == "gm" then
		return "GM"
	elseif accessLevel == "observer" then
		return "Observer"
	end

	return "None"
end

local function getPlayerLogAccessLevel(player)
	if not player then
		return "Local"
	end

	local roleName = getRoleName(getPlayerRole(player))
	if normalizeAccessName(roleName) ~= "None" then
		return roleName
	end

	if player.getAccessLevel then
		return normalizeAccessName(player:getAccessLevel())
	end

	return "None"
end

local function playerCanManageRoles(player)
	if not isClient() and not isServer() then
		return true
	end

	if not player then
		return not isClient()
	end

	local role = getPlayerRole(player)
	local roleName = normalizeAccessName(getRoleName(role))
	if roleName == "Admin" or roleName == "Moderator" or roleName == "Overseer" then
		return true
	end

	if role and role.hasAdminPower and role:hasAdminPower() then
		return true
	end

	if player.getAccessLevel then
		local accessLevel = normalizeAccessName(player:getAccessLevel())
		return accessLevel == "Admin" or accessLevel == "Moderator" or accessLevel == "Overseer"
	end

	return false
end

local function sendRoleResponse(player, success, messageKey, extra)
	local response = extra or {}
	response.success = success == true
	response.messageKey = messageKey

	if isServer() and player then
		sendServerCommand(player, MODULE, "RoleResponse", response)
	elseif RoleDisplaySystem.Client and RoleDisplaySystem.Client.Commands then
		RoleDisplaySystem.Client.Commands.RoleResponse(response)
	end
end

local function normalizeArgs(args)
	if type(args) ~= "table" then
		return {}
	end
	return args
end

local function ensureAllowed(player)
	if playerCanManageRoles(player) then
		return true
	end

	sendRoleResponse(player, false, "IGUI_RM_InvalidRoleData", {
		error = "Player does not have permission to manage roles",
	})
	return false
end

--------------------------------------------------
-- DATA MANAGEMENT
--------------------------------------------------

function RoleDisplaySystem.Server.SaveRoles(roles)
	return RoleStore.SaveRoles(roles)
end

function RoleDisplaySystem.Server.LoadRoles()
	return RoleStore.LoadRoles()
end

--------------------------------------------------
-- PUSHING UPDATES TO CLIENTS
--------------------------------------------------

function RoleDisplaySystem.Server.PushRolesToAll(roles)
	if isServer() then
		sendServerCommand(MODULE, "LoadRoles", roles)
	else
		RoleDisplaySystem.Roles = roles
		if RoleDisplaySystem.Client and RoleDisplaySystem.Client.Commands then
			RoleDisplaySystem.Client.Commands.LoadRoles(roles)
		end
	end
end

function RoleDisplaySystem.Server.PushRolesToPlayer(player, roles)
	if isServer() then
		if player then
			sendServerCommand(player, MODULE, "LoadRoles", roles)
		end
	else
		RoleDisplaySystem.Roles = roles
		if RoleDisplaySystem.Client and RoleDisplaySystem.Client.Commands then
			RoleDisplaySystem.Client.Commands.LoadRoles(roles)
		end
	end
end

--------------------------------------------------
-- SERVER COMMAND HANDLERS
--------------------------------------------------

function RoleDisplaySystem.Server.ServerCommands.LoadRoles(player, args)
	args = normalizeArgs(args)
	local roles = RoleDisplaySystem.Server.LoadRoles()
	if args and args.toAll then
		RoleDisplaySystem.Server.PushRolesToAll(roles)
	else
		RoleDisplaySystem.Server.PushRolesToPlayer(player, roles)
	end
end

function RoleDisplaySystem.Server.ServerCommands.AddRole(player, args)
	args = normalizeArgs(args)
	if not ensureAllowed(player) then
		return
	end

	local roles = RoleDisplaySystem.Server.LoadRoles()

	local newRole = args.newRole
	if not newRole then
		sendRoleResponse(player, false, "IGUI_RM_InvalidRoleData")
		return
	end

	local isValid, errorMessage = RoleDisplaySystem.Shared.ValidateRoleData(newRole)
	if not isValid then
		sendRoleResponse(player, false, "IGUI_RM_InvalidRoleData", {
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
	if newRole.showInMultiple == nil then
		newRole.showInMultiple = true
	end

	roles[newRole.id] = newRole
	RoleDisplaySystem.Server.SaveRoles(roles)
	RoleDisplaySystem.Server.PushRolesToAll(roles)

	sendRoleResponse(player, true, "IGUI_RM_RoleCreated", {
		messageArgs = { roleName = newRole.name },
		roleId = newRole.id,
	})

	local logText = string.format(
		"[Admin: %s] [SteamID: %s] [Role: %s] Added Role: %s",
		getPlayerLogName(player),
		getPlayerLogSteamID(player),
		getPlayerLogAccessLevel(player),
		tostring(formatRoleInfo(newRole))
	)
	writeServerLog(logText)
end

function RoleDisplaySystem.Server.ServerCommands.RemoveRole(player, args)
	args = normalizeArgs(args)
	if not ensureAllowed(player) then
		return
	end

	local roles = RoleDisplaySystem.Server.LoadRoles()

	local roleId = args.roleId
	local role = roles[roleId]

	if not role then
		sendRoleResponse(player, false, "IGUI_RM_RoleNotFound")
		return
	end

	local roleName = role.name
	roles[roleId] = nil

	RoleDisplaySystem.Server.SaveRoles(roles)
	RoleDisplaySystem.Server.PushRolesToAll(roles)

	sendRoleResponse(player, true, "IGUI_RM_RoleDeleted", {
		messageArgs = { roleName = roleName },
	})

	local logText = string.format(
		"[Admin: %s] [SteamID: %s] [Role: %s] Removed Role: %s",
		getPlayerLogName(player),
		getPlayerLogSteamID(player),
		getPlayerLogAccessLevel(player),
		tostring(formatRoleInfo(role))
	)
	writeServerLog(logText)
end

function RoleDisplaySystem.Server.ServerCommands.UpdateRole(player, args)
	args = normalizeArgs(args)
	if not ensureAllowed(player) then
		return
	end

	local roles = RoleDisplaySystem.Server.LoadRoles()

	local roleData = args.roleData
	if not roleData or not roleData.id then
		sendRoleResponse(player, false, "IGUI_RM_InvalidRoleData")
		return
	end

	local role = roles[roleData.id]
	if not role then
		sendRoleResponse(player, false, "IGUI_RM_RoleNotFound")
		return
	end

	local isValid, errorMessage = RoleDisplaySystem.Shared.ValidateRoleData(roleData)
	if not isValid then
		sendRoleResponse(player, false, "IGUI_RM_InvalidRoleData", {
			error = errorMessage,
		})
		return
	end

	role.name = roleData.name
	role.color = roleData.color or role.color
	role.bracketStyle = roleData.bracketStyle or role.bracketStyle
	role.priority = roleData.priority or role.priority
	role.showInMultiple = roleData.showInMultiple ~= false

	RoleDisplaySystem.Server.SaveRoles(roles)
	RoleDisplaySystem.Server.PushRolesToAll(roles)

	sendRoleResponse(player, true, "IGUI_RM_RoleUpdated", {
		messageArgs = { roleName = role.name },
	})

	local logText = string.format(
		"[Admin: %s] [SteamID: %s] [Role: %s] Updated Role: %s",
		getPlayerLogName(player),
		getPlayerLogSteamID(player),
		getPlayerLogAccessLevel(player),
		tostring(formatRoleInfo(role))
	)
	writeServerLog(logText)
end

function RoleDisplaySystem.Server.ServerCommands.ModifyRolePlayers(player, args)
	args = normalizeArgs(args)
	if not ensureAllowed(player) then
		return
	end

	local roles = RoleDisplaySystem.Server.LoadRoles()

	local roleId = args.roleId
	local action = args.action
	local usernames = args.usernames or {}

	local role = roles[roleId]
	if not role then
		sendRoleResponse(player, false, "IGUI_RM_RoleNotFound")
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

		sendRoleResponse(player, true, "IGUI_RM_PlayersAdded", {
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

		sendRoleResponse(player, true, "IGUI_RM_PlayersRemoved", {
			messageArgs = { count = removedCount, roleName = role.name },
		})
	else
		sendRoleResponse(player, false, "IGUI_RM_InvalidRoleData", {
			error = "Invalid player modification action",
		})
		return
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
	if module ~= MODULE then
		return
	end

	if RoleDisplaySystem.Server.ServerCommands[command] then
		RoleDisplaySystem.Server.ServerCommands[command](player, args)
	end
end

Events.OnInitGlobalModData.Add(RoleDisplaySystem.Server.init)

Events.OnClientCommand.Add(RoleDisplaySystem.Server.onClientCommand)

return RoleDisplaySystem.Server
