local RoleDisplaySystem = require("RoleDisplaySystem/Shared")
local RoleStore = require("RoleDisplaySystem/Store")

local previousClient = RoleDisplaySystem.Client
if previousClient then
	if previousClient.OnServerCommand then
		Events.OnServerCommand.Remove(previousClient.OnServerCommand)
	end
	if previousClient.requestInitialRoles then
		Events.OnTick.Remove(previousClient.requestInitialRoles)
	end
end

RoleDisplaySystem.Client = RoleDisplaySystem.Client or {}
RoleDisplaySystem.Client.Commands = {}

local MODULE = "RoleDisplaySystem"

local function sendRoleResponse(success, messageKey, extra)
	local response = extra or {}
	response.success = success == true
	response.messageKey = messageKey

	if RoleDisplaySystem.Client
		and RoleDisplaySystem.Client.Commands
		and RoleDisplaySystem.Client.Commands.RoleResponse
	then
		RoleDisplaySystem.Client.Commands.RoleResponse(response)
	end
end

local function normalizeArgs(args)
	if type(args) ~= "table" then
		return {}
	end
	return args
end

local function ensureRoleDefaults(role)
	role.id = role.id or RoleDisplaySystem.Shared.GenerateRoleId()
	role.players = role.players or {}
	role.priority = role.priority or 1
	role.bracketStyle = role.bracketStyle or "square"
	role.color = role.color or { r = 1, g = 1, b = 1, a = 1 }
	if role.showInMultiple == nil then
		role.showInMultiple = true
	end
	return role
end

local function playerIsInRole(role, username)
	if not role or not role.players or not username then
		return false
	end

	for _, playerName in ipairs(role.players) do
		if playerName == username then
			return true
		end
	end

	return false
end

local function executeLocalCommand(command, args)
	args = normalizeArgs(args)

	if command == "LoadRoles" then
		local roles = RoleStore.LoadRoles()
		RoleDisplaySystem.Client.Commands.LoadRoles(roles)
		return true
	end

	local roles = RoleStore.LoadRoles()

	if command == "AddRole" then
		local newRole = args.newRole
		if not newRole then
			sendRoleResponse(false, "IGUI_RM_InvalidRoleData")
			return false
		end

		local isValid, errorMessage = RoleDisplaySystem.Shared.ValidateRoleData(newRole)
		if not isValid then
			sendRoleResponse(false, "IGUI_RM_InvalidRoleData", {
				error = errorMessage,
			})
			return false
		end

		ensureRoleDefaults(newRole)
		roles[newRole.id] = newRole
		RoleStore.PushLocalRoles(roles)
		sendRoleResponse(true, "IGUI_RM_RoleCreated", {
			messageArgs = { roleName = newRole.name },
			roleId = newRole.id,
		})
		return true
	end

	if command == "RemoveRole" then
		local roleId = args.roleId
		local role = roles[roleId]
		if not role then
			sendRoleResponse(false, "IGUI_RM_RoleNotFound")
			return false
		end

		local roleName = role.name
		roles[roleId] = nil
		RoleStore.PushLocalRoles(roles)
		sendRoleResponse(true, "IGUI_RM_RoleDeleted", {
			messageArgs = { roleName = roleName },
		})
		return true
	end

	if command == "UpdateRole" then
		local roleData = args.roleData
		if not roleData or not roleData.id then
			sendRoleResponse(false, "IGUI_RM_InvalidRoleData")
			return false
		end

		local role = roles[roleData.id]
		if not role then
			sendRoleResponse(false, "IGUI_RM_RoleNotFound")
			return false
		end

		local isValid, errorMessage = RoleDisplaySystem.Shared.ValidateRoleData(roleData)
		if not isValid then
			sendRoleResponse(false, "IGUI_RM_InvalidRoleData", {
				error = errorMessage,
			})
			return false
		end

		role.name = roleData.name
		role.color = roleData.color or role.color
		role.bracketStyle = roleData.bracketStyle or role.bracketStyle
		role.priority = roleData.priority or role.priority
		role.showInMultiple = roleData.showInMultiple ~= false
		RoleStore.PushLocalRoles(roles)
		sendRoleResponse(true, "IGUI_RM_RoleUpdated", {
			messageArgs = { roleName = role.name },
		})
		return true
	end

	if command == "ModifyRolePlayers" then
		local roleId = args.roleId
		local role = roles[roleId]
		if not role then
			sendRoleResponse(false, "IGUI_RM_RoleNotFound")
			return false
		end

		role.players = role.players or {}
		local usernames = args.usernames or {}

		if args.action == "add" then
			local addedCount = 0
			for _, username in ipairs(usernames) do
				if not playerIsInRole(role, username) then
					table.insert(role.players, username)
					addedCount = addedCount + 1
				end
			end

			RoleStore.PushLocalRoles(roles)
			sendRoleResponse(true, "IGUI_RM_PlayersAdded", {
				messageArgs = { count = addedCount, roleName = role.name },
			})
			return true
		elseif args.action == "remove" then
			local removedCount = 0
			for _, username in ipairs(usernames) do
				for i = #role.players, 1, -1 do
					if role.players[i] == username then
						table.remove(role.players, i)
						removedCount = removedCount + 1
						break
					end
				end
			end

			RoleStore.PushLocalRoles(roles)
			sendRoleResponse(true, "IGUI_RM_PlayersRemoved", {
				messageArgs = { count = removedCount, roleName = role.name },
			})
			return true
		end

		sendRoleResponse(false, "IGUI_RM_InvalidRoleData", {
			error = "Invalid player modification action",
		})
		return false
	end

	return false
end

local function sendRoleCommand(command, args)
	args = args or {}

	if isClient() then
		local player = getPlayer()
		if not player then
			sendRoleResponse(false, "IGUI_RM_InvalidRoleData", {
				error = "Local player is not ready",
			})
			return false
		end

		sendClientCommand(player, MODULE, command, args)
		return true
	end

	return executeLocalCommand(command, args)
end

function RoleDisplaySystem.Client.Commands.LoadRoles(args)
	if type(args) ~= "table" then
		args = {}
	end

	RoleDisplaySystem.Roles = args
	if RoleDisplaySystem.ChatIntegration and RoleDisplaySystem.ChatIntegration.OnRolesUpdated then
		RoleDisplaySystem.ChatIntegration.OnRolesUpdated()
	end

	if RoleDisplaySystem.UI_Manager
		and RoleDisplaySystem.UI_Manager.instance
		and RoleDisplaySystem.UI_Manager.instance:isVisible()
	then
		RoleDisplaySystem.UI_Manager.instance:updateRoleList()
	end
end

function RoleDisplaySystem.Client.Commands.RoleResponse(args)
	if not args then
		return
	end

	if RoleDisplaySystem.UI_Manager
		and RoleDisplaySystem.UI_Manager.instance
		and RoleDisplaySystem.UI_Manager.instance:isVisible()
	then
		RoleDisplaySystem.UI_Manager.instance:updateRoleList()
	end
end

function RoleDisplaySystem.Client.OnServerCommand(module, command, args)
	if module ~= MODULE then
		return
	end

	if RoleDisplaySystem.Client.Commands[command] then
		RoleDisplaySystem.Client.Commands[command](args)
	end
end

Events.OnServerCommand.Add(RoleDisplaySystem.Client.OnServerCommand)

function RoleDisplaySystem.Client.AddRole(roleData)
	return sendRoleCommand("AddRole", {
		newRole = roleData,
	})
end

function RoleDisplaySystem.Client.RemoveRole(roleId)
	return sendRoleCommand("RemoveRole", {
		roleId = roleId,
	})
end

function RoleDisplaySystem.Client.UpdateRole(roleData)
	return sendRoleCommand("UpdateRole", {
		roleData = roleData,
	})
end

function RoleDisplaySystem.Client.AddPlayerToRole(roleId, username)
	return sendRoleCommand("ModifyRolePlayers", {
		roleId = roleId,
		action = "add",
		usernames = { username },
	})
end

function RoleDisplaySystem.Client.RemovePlayerFromRole(roleId, username)
	return sendRoleCommand("ModifyRolePlayers", {
		roleId = roleId,
		action = "remove",
		usernames = { username },
	})
end

function RoleDisplaySystem.Client.AddPlayersToRole(roleId, usernames)
	return sendRoleCommand("ModifyRolePlayers", {
		roleId = roleId,
		action = "add",
		usernames = usernames,
	})
end

function RoleDisplaySystem.Client.RequestRoles(toAll)
	return sendRoleCommand("LoadRoles", {
		toAll = toAll == true,
	})
end

local didRequestRoles = false
local function requestInitialRoles()
	if didRequestRoles then
		return
	end
	didRequestRoles = true
	RoleDisplaySystem.Client.RequestRoles(false)
	Events.OnTick.Remove(requestInitialRoles)
end
RoleDisplaySystem.Client.requestInitialRoles = requestInitialRoles
Events.OnTick.Add(requestInitialRoles)

return RoleDisplaySystem.Client
