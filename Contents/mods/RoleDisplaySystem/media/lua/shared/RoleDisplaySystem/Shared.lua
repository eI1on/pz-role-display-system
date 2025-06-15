local Logger = require("RoleDisplaySystem/Logger")

local RoleDisplaySystem = {}
RoleDisplaySystem.VERSION = "1.0.0"
RoleDisplaySystem.Roles = {}
RoleDisplaySystem.Shared = {}

local DEBUG_MODE = true
function RoleDisplaySystem.Shared.debugLog(message, category)
	if not DEBUG_MODE then
		return
	end

	local player = getPlayer() and getPlayer():getUsername() or "Unknown"
	local prefix = string.format("[%s][%s]", category or "DEBUG", player)

	Logger:debug(prefix .. " " .. message)
end

RoleDisplaySystem.ACCESS_LEVEL = {
	None = 1,
	Observer = 2,
	GM = 3,
	Overseer = 4,
	Moderator = 5,
	Admin = 6,
}

RoleDisplaySystem.BRACKET_STYLES = {
	square = { open = "[", close = "]" },
	round = { open = "(", close = ")" },
	curly = { open = "{", close = "}" },
	angle = { open = "<", close = ">" },
	colon = { open = "", close = ":" },
	none = { open = "", close = "" },
}

function RoleDisplaySystem.Shared.RequestRoles()
	if isClient() then
		sendClientCommand("RoleDisplaySystem", "LoadRoles", { toAll = false })
		return RoleDisplaySystem.Roles
	else
		local roles = RoleDisplaySystem.Server.LoadRoles()
		return roles
	end
end

local rand = newrandom()
local chars = "0123456789aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ"

function RoleDisplaySystem.Shared.GenerateRoleId(prefix)
	prefix = prefix or "role_"
	local idStr = ""

	for _ = 1, 6 do
		local index = math.floor(rand:random(#chars)) + 1
		idStr = idStr .. chars:sub(index, index)
	end

	return prefix .. idStr
end

function RoleDisplaySystem.Shared.GetRoleById(roleId)
	return RoleDisplaySystem.Roles[roleId]
end

function RoleDisplaySystem.Shared.GetPlayerRoles(username)
	local playerRoles = {}

	if not RoleDisplaySystem.Roles then
		return playerRoles
	end

	for roleId, role in pairs(RoleDisplaySystem.Roles) do
		if role.players then
			for _, playerName in ipairs(role.players) do
				if playerName == username then
					table.insert(playerRoles, role)
					break
				end
			end
		end
	end

	table.sort(playerRoles, function(a, b)
		return (a.priority or 1) > (b.priority or 1)
	end)

	return playerRoles
end

function RoleDisplaySystem.Shared.GetHighestPriorityRole(username)
	local roles = RoleDisplaySystem.Shared.GetPlayerRoles(username)
	return roles[1]
end

function RoleDisplaySystem.Shared.FormatRoleTag(role)
	if not role then
		return ""
	end

	local style = RoleDisplaySystem.BRACKET_STYLES[role.bracketStyle] or RoleDisplaySystem.BRACKET_STYLES.square
	return style.open .. role.name .. style.close
end

function RoleDisplaySystem.Shared.FormatPlayerNameWithRole(username, showAllRoles)
	if showAllRoles then
		local roles = RoleDisplaySystem.Shared.GetPlayerRoles(username)
		local tags = {}

		for _, role in ipairs(roles) do
			table.insert(tags, RoleDisplaySystem.Shared.FormatRoleTag(role))
		end

		if #tags > 0 then
			return table.concat(tags, " ") .. " " .. username
		end
	else
		local role = RoleDisplaySystem.Shared.GetHighestPriorityRole(username)
		if role then
			return RoleDisplaySystem.Shared.FormatRoleTag(role) .. " " .. username
		end
	end

	return username
end

function RoleDisplaySystem.Shared.IsPlayerInRole(username, roleId)
	local role = RoleDisplaySystem.Roles[roleId]
	if not role or not role.players then
		return false
	end

	for _, playerName in ipairs(role.players) do
		if playerName == username then
			return true
		end
	end

	return false
end

function RoleDisplaySystem.Shared.GetRoleColor(role)
	if not role or not role.color then
		return { r = 1, g = 1, b = 1, a = 1 }
	end

	local color = role.color
	return {
		r = color.r or 1,
		g = color.g or 1,
		b = color.b or 1,
		a = color.a or 1,
	}
end

function RoleDisplaySystem.Shared.ValidateRoleData(roleData)
	if not roleData then
		return false, "Role data is missing"
	end

	if not roleData.name or roleData.name:trim() == "" then
		return false, "Role name is required"
	end

	if roleData.color then
		if type(roleData.color) ~= "table" then
			return false, "Invalid color format - must be a table"
		end

		local color = roleData.color
		if
			type(color.r) ~= "number"
			or color.r < 0
			or color.r > 1
			or type(color.g) ~= "number"
			or color.g < 0
			or color.g > 1
			or type(color.b) ~= "number"
			or color.b < 0
			or color.b > 1
		then
			return false, "Invalid color values - r, g, b must be numbers between 0 and 1"
		end
	end

	if roleData.bracketStyle and not RoleDisplaySystem.BRACKET_STYLES[roleData.bracketStyle] then
		return false, "Invalid bracket style"
	end

	if roleData.priority and (type(roleData.priority) ~= "number" or roleData.priority < 1) then
		return false, "Priority must be a positive number"
	end

	return true
end

return RoleDisplaySystem
