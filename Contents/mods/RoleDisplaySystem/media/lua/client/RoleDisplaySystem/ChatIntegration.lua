local RoleDisplaySystem = require("RoleDisplaySystem/Shared")

RoleDisplaySystem.ChatIntegration = {}

local CHAT_CONFIG = {
	ENABLED = true,
	SHOW_MULTIPLE_ROLES = false,
}

local playerRoleCache = {}
local cacheTimeout = 5000
local lastCacheUpdate = {}

---@param username string
---@return table|nil roles
function RoleDisplaySystem.ChatIntegration.GetPlayerRoles(username)
	if not username or username == "" then
		return nil
	end

	local currentTime = getTimestampMs()
	if playerRoleCache[username] and lastCacheUpdate[username] then
		if currentTime - lastCacheUpdate[username] < cacheTimeout then
			return playerRoleCache[username]
		end
	end

	local roles = RoleDisplaySystem.Shared.GetPlayerRoles(username)

	playerRoleCache[username] = roles
	lastCacheUpdate[username] = currentTime

	return roles
end

---@param username string
---@param forTextDraw? boolean
---@return table roleData
function RoleDisplaySystem.ChatIntegration.FormatPlayerRoles(username, forTextDraw)
	local roles = RoleDisplaySystem.ChatIntegration.GetPlayerRoles(username)

	if not roles or #roles == 0 then
		return {
			coloredRoles = {},
			hasRoles = false,
		}
	end

	local coloredRoles = {}

	if CHAT_CONFIG.SHOW_MULTIPLE_ROLES then
		for _, role in ipairs(roles) do
			local roleTag = RoleDisplaySystem.Shared.FormatRoleTag(role)
			local roleColor = RoleDisplaySystem.Shared.GetRoleColor(role)

			if roleColor then
				if forTextDraw then
					-- TextDrawObject format: [col=r,g,b]text[/]
					local r = math.floor(roleColor.r * 255)
					local g = math.floor(roleColor.g * 255)
					local b = math.floor(roleColor.b * 255)
					table.insert(coloredRoles, "[col=" .. r .. "," .. g .. "," .. b .. "]" .. roleTag .. "[/]")
				else
					-- chat format: <RGB:r,g,b>text
					local colorCode = roleColor.r .. "," .. roleColor.g .. "," .. roleColor.b
					table.insert(coloredRoles, "<RGB:" .. colorCode .. ">" .. roleTag)
				end
			else
				table.insert(coloredRoles, roleTag)
			end
		end
	else
		local topRole = roles[1]
		if topRole then
			local roleTag = RoleDisplaySystem.Shared.FormatRoleTag(topRole)
			local roleColor = RoleDisplaySystem.Shared.GetRoleColor(topRole)

			if roleColor then
				if forTextDraw then
					-- TextDrawObject format: [col=r,g,b]text[/]
					local r = math.floor(roleColor.r * 255)
					local g = math.floor(roleColor.g * 255)
					local b = math.floor(roleColor.b * 255)
					table.insert(coloredRoles, "[col=" .. r .. "," .. g .. "," .. b .. "]" .. roleTag .. "[/]")
				else
					-- chat format: <RGB:r,g,b>text
					local colorCode = roleColor.r .. "," .. roleColor.g .. "," .. roleColor.b
					table.insert(coloredRoles, "<RGB:" .. colorCode .. ">" .. roleTag)
				end
			else
				table.insert(coloredRoles, roleTag)
			end
		end
	end

	return {
		coloredRoles = coloredRoles,
		hasRoles = #coloredRoles > 0,
	}
end

---@param message ChatMessage
---@return string rolePrefix
function RoleDisplaySystem.ChatIntegration.GetRolePrefix(message)
	if not CHAT_CONFIG.ENABLED then
		return ""
	end

	local author = message:getAuthor()
	if not author or author == "" then
		return ""
	end

	local roleData = RoleDisplaySystem.ChatIntegration.FormatPlayerRoles(author, false)
	if not roleData.hasRoles then
		return ""
	end

	local originalColor = message:getTextColor()
	local originalRGB = "1,1,1"
	if originalColor then
		originalRGB = originalColor:getR() .. "," .. originalColor:getG() .. "," .. originalColor:getB()
	end

	local roleText = table.concat(roleData.coloredRoles, " ")

	return " " .. roleText .. " <RGB:" .. originalRGB .. "> "
end

---@param username string
---@return string formattedRoles
function RoleDisplaySystem.ChatIntegration.GetFormattedRolesForTextDraw(username)
	local roleData = RoleDisplaySystem.ChatIntegration.FormatPlayerRoles(username, true)
	if roleData.hasRoles then
		return table.concat(roleData.coloredRoles, " ")
	end
	return ""
end

---@param username? string
function RoleDisplaySystem.ChatIntegration.ClearPlayerCache(username)
	if username then
		playerRoleCache[username] = nil
		lastCacheUpdate[username] = nil
	else
		playerRoleCache = {}
		lastCacheUpdate = {}
	end
end

function RoleDisplaySystem.ChatIntegration.OnRolesUpdated()
	RoleDisplaySystem.ChatIntegration.ClearPlayerCache()
end

RoleDisplaySystem.ChatIntegration._metaMethodOverwrite = {}

RoleDisplaySystem.ChatIntegration._metaMethodOverwrite.getTextWithPrefix = function(original_fn)
	return function(self, ...)
		local originalReturn = original_fn(self, ...)
		local rolePrefix = RoleDisplaySystem.ChatIntegration.GetRolePrefix(self)
		return rolePrefix .. originalReturn
	end
end

function RoleDisplaySystem.ChatIntegration._metaMethodOverwrite.apply(class, methodName)
	if not __classmetatables then
		return false
	end
	local metatable = __classmetatables[class]
	if not metatable then
		return false
	end
	local metatable__index = metatable.__index
	if not metatable__index then
		return false
	end
	local originalMethod = metatable__index[methodName]
	if not originalMethod then
		return false
	end
	metatable__index[methodName] = RoleDisplaySystem.ChatIntegration._metaMethodOverwrite[methodName](originalMethod)
	return true
end

function RoleDisplaySystem.ChatIntegration.Initialize()
	if not CHAT_CONFIG.ENABLED then
		return
	end

	local chatIntegration = SandboxVars.RoleDisplaySystem.ChatIntegration
	if chatIntegration ~= nil and not chatIntegration then
		CHAT_CONFIG.ENABLED = false
		return
	end

	local showMultiple = SandboxVars.RoleDisplaySystem.ShowMultipleRoles
	if showMultiple ~= nil then
		CHAT_CONFIG.SHOW_MULTIPLE_ROLES = showMultiple
	end

	local success = false

	if zombie and zombie.chat and zombie.chat.ChatMessage then
		success = RoleDisplaySystem.ChatIntegration._metaMethodOverwrite.apply(
			zombie.chat.ChatMessage.class,
			"getTextWithPrefix"
		)
	end

	if success then
		Events.OnServerCommand.Add(function(module, command, args)
			if module == "RoleDisplaySystem" and command == "LoadRoles" then
				RoleDisplaySystem.ChatIntegration.OnRolesUpdated()
			end
		end)
	end
end

Events.OnInitGlobalModData.Add(RoleDisplaySystem.ChatIntegration.Initialize)

return RoleDisplaySystem.ChatIntegration
