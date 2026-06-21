local RoleDisplaySystem = require("RoleDisplaySystem/Shared")
require("RoleDisplaySystem/ChatIntegration")

RoleDisplaySystem.RoleRenderer = RoleDisplaySystem.RoleRenderer or {}
local RoleRenderer = RoleDisplaySystem.RoleRenderer

local RENDER_CONFIG = {
	ENABLED = true,
	OFFSET_X = 0,
	OFFSET_Y = 0,
	SPACING = 3, -- space between roles and username
	SIMPLE_OFFSET = 0,
	MAX_RENDER_DISTANCE = 20,
	FADE_DISTANCE = 15,
}

RoleRenderer.Config = RENDER_CONFIG

local roleTextCache = {}
local cacheCleanupTimer = 0
local CACHE_CLEANUP_INTERVAL = 300

local function getNameDisplayOptions()
	local serverOptions = getServerOptions()
	return serverOptions:getBoolean("DisplayUserName"), serverOptions:getBoolean("ShowFirstAndLastName")
end

local function getOrCreateRoleText(playerOnlineID)
	if not roleTextCache[playerOnlineID] then
		local textObj = TextDrawObject.new(255, 255, 255, true, true, true, true, true, true)
		textObj:setDefaultFont(UIFont.Small)
		roleTextCache[playerOnlineID] = textObj
	end
	return roleTextCache[playerOnlineID]
end

local function calculateUsernameWidth(player)
	if not player then return 0 end

	local username = player:getUsername()
	if not username or username == "" then return 0 end

	local displayUsername, showFirstAndLastName = getNameDisplayOptions()

	local access = player:getAccessLevel()
	local hasAccess = access and access ~= "None"

	local tag = player.getTagPrefix and player:getTagPrefix() or nil
	local hasTag = tag and tag ~= ""

	local namePart = ""

	if showFirstAndLastName then
		namePart = player:getFullName() or ""
	end

	if displayUsername then
		if namePart ~= "" then
			namePart = string.format("%s (%s)", namePart, username)
		else
			namePart = username
		end
	elseif not showFirstAndLastName then
		-- B42 builds this value before CanSeeAll decides whether it is drawn.
		namePart = username
	end

	local prefixParts = {}

	if hasTag then
		prefixParts[#prefixParts + 1] = "[" .. tag .. "]"
	end

	if hasAccess and player.isShowAdminTag and player:isShowAdminTag() then
		prefixParts[#prefixParts + 1] = "[" .. access .. "]"
	end

	local displayName
	if #prefixParts > 0 then
		displayName = table.concat(prefixParts, " ") .. " " .. namePart
	else
		displayName = namePart
	end

	if player.isSpeek or player.isVoiceMute then
		displayName = "   " .. displayName
	end

	return getTextManager():MeasureStringX(UIFont.Small, displayName)
end

local function getPlayerUsernameHeight(player)
	if not player then
		return 0
	end
	if player.getUserNameHeight then
		return player:getUserNameHeight()
	end
	return getTextManager():MeasureStringY(UIFont.Small, player:getUsername() or "")
end

local function playerHasCapability(player, capability)
	if not player or not capability or not player.getRole then
		return false
	end

	local role = player:getRole()
	return role ~= nil and role.hasCapability ~= nil and role:hasCapability(capability)
end

local function canViewerSeeInvisiblePlayer(viewer, target)
	if not viewer or not target then
		return false
	end
	if viewer == target or not target:isInvisible() then
		return true
	end

	-- match IsoGameCharacter.updateUserName(): this capability controls whether
	-- an invisible remote player's overhead identity is shown to the viewer.
	return playerHasCapability(viewer, Capability.CanSeePlayersStats)
end

local function getAllVisiblePlayers()
	local players = {}
	local seen = {}

	if isClient() then
		local onlinePlayers = getOnlinePlayers()
		if onlinePlayers then
			for i = 0, onlinePlayers:size() - 1 do
				local player = onlinePlayers:get(i)
				if player then
					seen[player:getOnlineID()] = true
					table.insert(players, player)
				end
			end
		end
	end
	for i = 0, getNumActivePlayers() - 1 do
		local player = getSpecificPlayer(i)
		if player and not seen[player:getOnlineID()] then
			seen[player:getOnlineID()] = true
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

local function isMouseOverPlayerCharacter(player)
	if not player then
		return false
	end

	local pickedTarget = IsoObjectPicker.Instance:PickTarget(Mouse.getXA(), Mouse.getYA())
	if pickedTarget == player then
		return player:getTargetAlpha(player:getPlayerNum()) == 1.0
	end

	-- pickTarget does not use B42's FBO object picker. Match the character area
	-- used by the native overhead-name projection when that picker returns nil.
	local screenX, screenY = getPlayerScreenPosition(player)
	local zoom = Core.getInstance():getZoom(0)
	local tileScale = Core.getTileScale()
	local characterHeight = (128 / (2 / tileScale)) / zoom
	local characterHalfWidth = (24 * tileScale) / zoom
	local mouseX = Mouse.getXA()
	local mouseY = Mouse.getYA()

	return player:getTargetAlpha(player:getPlayerNum()) == 1.0
		and mouseX >= screenX - characterHalfWidth
		and mouseX <= screenX + characterHalfWidth
		and mouseY >= screenY
		and mouseY <= screenY + characterHeight
end

---@param player IsoPlayer
---@return boolean
local function shouldRenderForPlayer(player)
	if not player then
		return false
	end

	local localPlayer = getPlayer()
	if not localPlayer then
		return false
	end

	if player == localPlayer and not Core.getInstance():isShowYourUsername() then
		return false
	end

	if not canViewerSeeInvisiblePlayer(localPlayer, player) then
		return false
	end

	local hasDebugSeeAll = localPlayer.canSeeAll and localPlayer:canSeeAll()
	local displayUsername, showFirstAndLastName = getNameDisplayOptions()

	local currentSquare = player:getCurrentSquare()
	local hasLineOfSight = false
	if currentSquare then
		hasLineOfSight = currentSquare:getCanSee(localPlayer:getPlayerNum())
	end
	if not hasLineOfSight and not hasDebugSeeAll then
		return false
	end
	if getServerOptions():getBoolean("MouseOverToSeeDisplayName") and player ~= localPlayer and not hasDebugSeeAll then
		return isMouseOverPlayerCharacter(player)
	end

	if not displayUsername and not showFirstAndLastName and not hasDebugSeeAll then
		return false
	end

	return hasLineOfSight
end

---@param player1 IsoPlayer
---@param player2 IsoPlayer
---@return number
local function getPlayerDistance(player1, player2)
	local dx = player1:getX() - player2:getX()
	local dy = player1:getY() - player2:getY()
	return math.sqrt(dx * dx + dy * dy)
end

---@param distance number
---@return number
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

	local localPlayer = getPlayer()
	if not localPlayer then
		return
	end

	local displayUsername, showFirstAndLastName = getNameDisplayOptions()
	if not displayUsername and not showFirstAndLastName and not (localPlayer.canSeeAll and localPlayer:canSeeAll()) then
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

if RoleRenderer.onPostRender then
	Events.OnPostRender.Remove(RoleRenderer.onPostRender)
end
RoleRenderer.onPostRender = renderPlayerRoles
Events.OnPostRender.Add(RoleRenderer.onPostRender)

return RoleRenderer
