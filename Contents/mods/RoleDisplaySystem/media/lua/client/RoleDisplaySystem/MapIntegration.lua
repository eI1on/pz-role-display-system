local Reflection = require("Starlit/utils/Reflection")
local RoleDisplaySystem = require("RoleDisplaySystem/Shared")

RoleDisplaySystem.MapIntegration = {}

local MAP_CONFIG = {
	ENABLED = true,
	SHOW_MULTIPLE_ROLES = false,
}

local function getAllMapPlayers()
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

local function shouldShowPlayerOnMap(player)
	if not player then
		return false
	end

	if player:isDead() then
		return false
	end

	local localPlayer = getPlayer()
	if not localPlayer then
		return false
	end

	if player:isInvisible() then
		local localPlayerAccessLevel = localPlayer:getAccessLevel()
		local hasAdminPrivileges = localPlayerAccessLevel and localPlayerAccessLevel ~= "None"
		return hasAdminPrivileges or localPlayer:isCanSeeAll()
	end

	if isClient() and player ~= localPlayer then
		local visibility = getServerOptions():getBoolean("MapRemotePlayerVisibility")

		-- 1 = None, 2 = Faction/Safehouse, 3 = All
		if visibility == 1 then
			return false
		end
		if visibility == 3 then
			return true
		end

		return true
	end

	return true
end

local function shouldRenderRolesOnMap(player)
	if not MAP_CONFIG.ENABLED then
		return false
	end
	if not shouldShowPlayerOnMap(player) then
		return false
	end

	local localPlayer = getPlayer()
	if not localPlayer then
		return false
	end

	if player:isInvisible() then
		local localPlayerAccessLevel = localPlayer:getAccessLevel()
		local hasAdminPrivileges = localPlayerAccessLevel and localPlayerAccessLevel ~= "None"
		local hasDebugSeeAll = localPlayer:isCanSeeAll()

		if not hasAdminPrivileges and not hasDebugSeeAll then
			return false
		end
	end

	return true
end

local function renderPlayerRoles(self, player)
	if not shouldRenderRolesOnMap(player) then
		return
	end

	local username = player:getUsername()
	if not username or username == "" then
		return
	end

	local roles = RoleDisplaySystem.ChatIntegration.GetPlayerRoles(username)
	if not roles or #roles == 0 then
		return
	end

	local worldX = player:getX()
	local worldY = player:getY()

	if player:getVehicle() then
		worldX = player:getVehicle():getX()
		worldY = player:getVehicle():getY()
	end

	local api = self.javaObject:getAPI()

	local uiX = api:worldToUIX(worldX, worldY)
	local uiY = api:worldToUIY(worldX, worldY)

	uiX = math.floor(uiX)
	uiY = math.floor(uiY)

	local usernameWidth = getTextManager():MeasureStringX(UIFont.Small, username) + 16
	local lineHeight = getTextManager():MeasureStringY(UIFont.Small, username)
	local backgroundHeight = math.ceil(lineHeight * 1.25)

	local usernameBackgroundX = uiX - usernameWidth / 2.0
	local usernameBackgroundY = uiY + 4.0

	local rolesToShow = {}
	if MAP_CONFIG.SHOW_MULTIPLE_ROLES then
		rolesToShow = roles
	else
		if roles[1] then
			table.insert(rolesToShow, roles[1])
		end
	end

	local totalRoleWidth = 0
	local roleWidths = {}
	local roleSpacing = 2

	for i, role in ipairs(rolesToShow) do
		local roleTag = RoleDisplaySystem.Shared.FormatRoleTag(role)
		local roleWidth = getTextManager():MeasureStringX(UIFont.Small, roleTag)
		table.insert(roleWidths, roleWidth)
		totalRoleWidth = totalRoleWidth + roleWidth
		if i < #rolesToShow then
			totalRoleWidth = totalRoleWidth + roleSpacing
		end
	end

	if totalRoleWidth == 0 then
		return
	end

	local rolePadding = 10
	local totalBackgroundWidth = totalRoleWidth + rolePadding
	local roleHeight = backgroundHeight

	local roleBackgroundX = usernameBackgroundX - totalBackgroundWidth
	local roleBackgroundY = usernameBackgroundY

	self:setStencilRect(0, 0, self.width, self.height)
	self.javaObject:DrawTextureScaledColor(
		nil,
		roleBackgroundX,
		roleBackgroundY,
		totalBackgroundWidth,
		roleHeight,
		0.5,
		0.5,
		0.5,
		0.25
	)

	local currentX = roleBackgroundX + rolePadding / 2.0
	local roleTextY = roleBackgroundY + (roleHeight - lineHeight) / 2.0

	for i, role in ipairs(rolesToShow) do
		local roleTag = RoleDisplaySystem.Shared.FormatRoleTag(role)
		local roleColor = RoleDisplaySystem.Shared.GetRoleColor(role)
		local roleWidth = roleWidths[i]

		local r, g, b = 0.0, 0.0, 0.0
		if roleColor then
			r = roleColor.r
			g = roleColor.g
			b = roleColor.b
		end

		self.javaObject:DrawText(UIFont.Small, roleTag, currentX, roleTextY, r, g, b, 1.0)

		currentX = currentX + roleWidth + roleSpacing
	end

	self:clearStencilRect()
end

local function renderAllPlayerRoles(self)
	local api = self.javaObject:getAPI()
	local m_renderer = Reflection.getUnexposedObjectField(api, "m_renderer")
	local playersBool = Reflection.getUnexposedObjectField(m_renderer, "Players")

	if not playersBool:getValue() then
		return
	end

	local allPlayers = getAllMapPlayers()

	for _, player in ipairs(allPlayers) do
		if player then
			renderPlayerRoles(self, player)
		end
	end
end

local originalWorldMapPrerender = ISWorldMap.prerender
function ISWorldMap:prerender()
	originalWorldMapPrerender(self)
	renderAllPlayerRoles(self)
end

local originalMiniMapPrerender = ISMiniMapInner.prerender
function ISMiniMapInner:prerender()
	originalMiniMapPrerender(self)
	renderAllPlayerRoles(self)
end

function RoleDisplaySystem.MapIntegration.Initialize()
	if not MAP_CONFIG.ENABLED then
		return
	end

	local mapIntegration = SandboxVars.RoleDisplaySystem.MapIntegration
	if mapIntegration ~= nil and not mapIntegration then
		MAP_CONFIG.ENABLED = false
		return
	end

	local showMultiple = SandboxVars.RoleDisplaySystem.ShowMultipleRoles
	if showMultiple ~= nil then
		MAP_CONFIG.SHOW_MULTIPLE_ROLES = showMultiple
	end
end

Events.OnInitGlobalModData.Add(RoleDisplaySystem.MapIntegration.Initialize)

return RoleDisplaySystem.MapIntegration
