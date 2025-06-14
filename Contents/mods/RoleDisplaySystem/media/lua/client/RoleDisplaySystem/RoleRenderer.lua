local Reflection = require("Starlit/utils/Reflection")
local RoleDisplaySystem = require("RoleDisplaySystem/Shared")

local RoleRenderer = {}

local RENDER_CONFIG = {
	ENABLED = true,
	OFFSET_X = 0,
	OFFSET_Y = 0,
	SPACING = 3, -- space between roles and username
	SIMPLE_OFFSET = 0,
	MAX_RENDER_DISTANCE = 20,
	FADE_DISTANCE = 15,
}

local roleTextCache = {}
local cacheCleanupTimer = 0
local CACHE_CLEANUP_INTERVAL = 300

local function getOrCreateRoleText(playerOnlineID)
	if not roleTextCache[playerOnlineID] then
		local textObj = TextDrawObject.new(255, 255, 255, true, true, true, true, true, true)
		textObj:setDefaultFont(UIFont.Small)
		roleTextCache[playerOnlineID] = textObj
	end
	return roleTextCache[playerOnlineID]
end

local function calculateUsernameWidth(player)
	local width = 0
	if not player then
		return width
	end

	local username = player:getUsername()
	if not username or username == "" then
		return width
	end

	local displayName = username

	if player:getTagPrefix() and player:getTagPrefix() ~= "" then
		displayName = "[" .. player:getTagPrefix() .. "] " .. displayName
	end

	local playerAccessLevel = player:getAccessLevel()
	if playerAccessLevel and playerAccessLevel ~= "None" then
		displayName = "[" .. player:getAccessLevel() .. "] " .. displayName
	end

	if player.isSpeek and not player.isVoiceMute then
		displayName = "   " .. displayName
	elseif player.isVoiceMute then
		displayName = "   " .. displayName
	end

	width = getTextManager():MeasureStringX(UIFont.Small, displayName)

	return width
end

local function getPlayerUsernameHeight(player)
	if not player then
		return 0
	end
	return player:getUserNameHeight()
end

local function getAllVisiblePlayers()
	local players = {}

	if isClient() then
		local onlinePlayers = getOnlinePlayers()
		if onlinePlayers then
			for i = 0, onlinePlayers:size() - 1 do
				local player = onlinePlayers:get(i)
				if player then
					table.insert(players, player)
				end
			end
		end
	end
	for i = 0, getNumActivePlayers() - 1 do
		local player = getSpecificPlayer(i)
		if player then
			table.insert(players, player)
		end
	end

	return players
end

local function cleanupCache()
	local currentTime = getTimestampMs()
	if currentTime - cacheCleanupTimer > CACHE_CLEANUP_INTERVAL * 1000 then
		local activePlayers = {}

		local allPlayers = getAllVisiblePlayers()
		for i = 1, #allPlayers do
			local player = allPlayers[i]
			if player then
				activePlayers[player:getOnlineID()] = true
			end
		end

		for playerID, textObj in pairs(roleTextCache) do
			if not activePlayers[playerID] then
				roleTextCache[playerID] = nil
			end
		end

		cacheCleanupTimer = currentTime
	end
end

local function getPlayerScreenPosition(player)
	local playerIndex = 0
	local worldX = player:getX()
	local worldY = player:getY()
	local worldZ = player:getZ()

	local screenX = IsoUtils.XToScreen(worldX, worldY, worldZ, 0)
	local screenY = IsoUtils.YToScreen(worldX, worldY, worldZ, 0)

	screenX = screenX - IsoCamera.getOffX()
	screenY = screenY - IsoCamera.getOffY()

	screenY = screenY - (128 / (2 / Core.getTileScale()))

	local zoom = Core.getInstance():getZoom(playerIndex)
	screenX = screenX / zoom
	screenY = screenY / zoom

	return screenX, screenY
end

local function isMouseHoveringOverPlayer(player)
	if not player then
		return false
	end

	local clickObject = IsoObjectPicker.Instance:ContextPick(Mouse.getXA(), Mouse.getYA())
	if not clickObject then
		return false
	end
	local tile = Reflection.getUnexposedObjectField(clickObject, "tile")
	if not tile then
		return false
	end

	local tileX = tile:getSquare():getX()
	local tileY = tile:getSquare():getY()
	local tileZ = tile:getSquare():getZ()

	for x = tileX - 1, tileX + 1 do
		for y = tileY - 1, tileY + 1 do
			local square = IsoCell.getInstance():getGridSquare(x, y, tileZ)
			if square then
				local movingObjects = square:getMovingObjects()
				for i = 0, movingObjects:size() - 1 do
					local movingObject = movingObjects:get(i)
					if movingObject and movingObject == player then
						return true
					end
				end
			end
		end
	end

	return false
end

local function shouldRenderForPlayer(player)
	if not player then
		return false
	end

	local localPlayer = getPlayer()
	if not localPlayer then
		return false
	end

	if not isClient() then
		return false
	end

	if player == localPlayer and not Core.getInstance():isShowYourUsername() then
		return false
	end

	local localPlayerAccessLevel = localPlayer:getAccessLevel()
	local hasAdminPrivileges = localPlayerAccessLevel and localPlayerAccessLevel ~= "None"
	local hasDebugSeeAll = localPlayer:isCanSeeAll()

	local currentSquare = player:getCurrentSquare()
	local hasLineOfSight = false
	if currentSquare then
		hasLineOfSight = currentSquare:getCanSee(localPlayer:getPlayerNum())
	end
	if not hasLineOfSight then
		return false
	end
	if player:isInvisible() then
		if not hasAdminPrivileges and not hasDebugSeeAll then
			return false
		end

		if
			not getServerOptions():getBoolean("DisplayUserName")
			and not getServerOptions():getBoolean("ShowFirstAndLastName")
			and not hasDebugSeeAll
		then
			return false
		end

		if
			getServerOptions():getBoolean("MouseOverToSeeDisplayName")
			and player ~= localPlayer
			and not hasDebugSeeAll
		then
			return isMouseHoveringOverPlayer(player)
		end

		return true
	end

	if not hasLineOfSight and not hasDebugSeeAll then
		return false
	end

	if getServerOptions():getBoolean("MouseOverToSeeDisplayName") and player ~= localPlayer and not hasDebugSeeAll then
		return isMouseHoveringOverPlayer(player)
	end

	if
		not getServerOptions():getBoolean("DisplayUserName")
		and not getServerOptions():getBoolean("ShowFirstAndLastName")
		and not hasDebugSeeAll
	then
		return false
	end

	return hasLineOfSight
end

local function getPlayerDistance(player1, player2)
	local dx = player1:getX() - player2:getX()
	local dy = player1:getY() - player2:getY()
	return math.sqrt(dx * dx + dy * dy)
end

local function getAlphaForDistance(distance)
	if distance <= RENDER_CONFIG.FADE_DISTANCE then
		return 1.0
	elseif distance >= RENDER_CONFIG.MAX_RENDER_DISTANCE then
		return 0.0
	else
		local fadeRange = RENDER_CONFIG.MAX_RENDER_DISTANCE - RENDER_CONFIG.FADE_DISTANCE
		local fadeAmount = (distance - RENDER_CONFIG.FADE_DISTANCE) / fadeRange
		return 1.0 - fadeAmount
	end
end

local function renderPlayerRoles()
	if not RENDER_CONFIG.ENABLED then
		return
	end
	if not isClient() then
		return
	end

	local localPlayer = getPlayer()
	if not localPlayer then
		return
	end

	cleanupCache()

	local allPlayers = getAllVisiblePlayers()

	for i = 1, #allPlayers do
		local player = allPlayers[i]
		if player and shouldRenderForPlayer(player) then
			local distance = getPlayerDistance(localPlayer, player)

			if distance <= RENDER_CONFIG.MAX_RENDER_DISTANCE then
				local alpha = getAlphaForDistance(distance)

				if alpha > 0.1 then
					local username = player:getUsername()
					if username and username ~= "" then
						local roleText = RoleDisplaySystem.ChatIntegration.GetFormattedRolesForTextDraw(username)

						if roleText and roleText ~= "" then
							local screenX, screenY = getPlayerScreenPosition(player)
							local textObj = getOrCreateRoleText(player:getOnlineID())

							if textObj:getOriginal() ~= roleText then
								textObj:ReadString(roleText)
							end

							local usernameWidth = calculateUsernameWidth(player)
							local finalX = screenX
								- ((usernameWidth + textObj:getWidth()) / 2)
								- RENDER_CONFIG.SPACING
								+ RENDER_CONFIG.OFFSET_X
							local finalY = screenY + RENDER_CONFIG.OFFSET_Y

							local usernameHeight = getPlayerUsernameHeight(player)
							if usernameHeight > 0 then
								finalY = finalY - usernameHeight
							end

							textObj:AddBatchedDraw(finalX, finalY, true, alpha)
						end
					end
				end
			end
		end
	end
end

Events.OnPostRender.Add(renderPlayerRoles)

return RoleRenderer
