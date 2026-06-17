local RoleDisplaySystem = require("RoleDisplaySystem/Shared")
require("RoleDisplaySystem/Client")
require("RoleDisplaySystem/RoleRenderer")
require("RoleDisplaySystem/MapIntegration")
local Theme = require("ElyonLib/UI/Theme/Theme")

local T = Theme.colors

local CONST = {
	LAYOUT = {
		WINDOW_SIZE = {
			MAIN_PANEL = {
				WIDTH  = 740,
				HEIGHT = 560,
			},
			ROLE_EDITOR_MODAL = {
				WIDTH  = 420,
				HEIGHT = 360,
			},
			DISPLAY_SETTINGS_MODAL = {
				WIDTH  = 360,
				HEIGHT = 260,
			},
			PLAYER_SELECTION_MODAL = {
				WIDTH  = 350,
				HEIGHT = 450,
			},
		},
		BUTTON = {
			WIDTH  = 110,
			HEIGHT = 25,
		},
		LABEL = {
			WIDTH = 80,
		},
		ENTRY = {
			WIDTH = 200,
		},
		PADDING        = 10,
		SPACING        = { SECTION = 10, ITEM = 5 },
		ELEMENT_HEIGHT = 25,
		ROLE_ROW_HEIGHT = 38,
		RADIO_SIZE     = 16,
	},
	FONT = {
		SMALL  = UIFont.Small,
		MEDIUM = UIFont.Medium,
		LARGE  = UIFont.Large,
	},
}

local function textMatchesFilter(text, filter)
	if not filter or filter == "" then
		return true
	end
	return tostring(text or ""):lower():find(filter, 1, true) ~= nil
end

local function entryFilterText(entry)
	if not entry then
		return ""
	end
	local text = entry.getInternalText and entry:getInternalText() or entry:getText()
	if not text then
		return ""
	end
	return text:trim():lower()
end

local function entryCurrentText(entry)
	if not entry then
		return ""
	end
	local text = entry.getInternalText and entry:getInternalText() or entry:getText()
	return text or ""
end

local function bracketPreview(style, name)
	local role = {
		name = name and name:trim() ~= "" and name:trim() or "Role",
		bracketStyle = style,
	}
	return RoleDisplaySystem.Shared.FormatRoleTag(role)
end

local function addBracketStyleOptions(combo, roleName)
	if not combo then
		return
	end

	combo:clear()
	combo:addOptionWithData(getText("IGUI_RM_BracketSquare", bracketPreview("square", roleName)), "square")
	combo:addOptionWithData(getText("IGUI_RM_BracketRound", bracketPreview("round", roleName)), "round")
	combo:addOptionWithData(getText("IGUI_RM_BracketCurly", bracketPreview("curly", roleName)), "curly")
	combo:addOptionWithData(getText("IGUI_RM_BracketAngle", bracketPreview("angle", roleName)), "angle")
	combo:addOptionWithData(getText("IGUI_RM_BracketColon", bracketPreview("colon", roleName)), "colon")
	combo:addOptionWithData(getText("IGUI_RM_BracketNone", bracketPreview("none", roleName)), "none")
end

local function selectComboData(combo, data)
	if not combo then
		return
	end

	for i = 1, combo:getOptionCount() do
		if combo:getOptionData(i) == data then
			combo.selected = i
			return
		end
	end

	combo.selected = combo:getOptionCount() > 0 and 1 or 0
end

local function getSelectedComboData(combo, fallback)
	if combo and combo.selected and combo.selected > 0 then
		return combo:getOptionData(combo.selected) or fallback
	end
	return fallback
end

RoleDisplaySystem.UI_Manager = ISCollapsableWindow:derive("RoleManager_UI")
RoleDisplaySystem.UI_Manager.instance = nil

function RoleDisplaySystem.UI_Manager:new(x, y, width, height, playerNum)
	playerNum = playerNum or 0

	local o = ISCollapsableWindow:new(
		x,
		y,
		width  or CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH,
		height or CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT
	)
	setmetatable(o, self)
	self.__index = self

	o.player          = getSpecificPlayer(playerNum) or getPlayer()
	o.borderColor     = Theme.copy(T.border)
	o.backgroundColor = Theme.copy(T.background)
	o.username        = o.player and o.player:getUsername() or ""
	o.selectedRole    = nil
	o.selectedPlayer  = nil
	o.minimumWidth    = CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH
	o.minimumHeight   = CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT

	o:setTitle(getText("IGUI_RM_Title"))
	o:setResizable(true)

	return o
end

function RoleDisplaySystem.UI_Manager:createChildren()
	ISCollapsableWindow.createChildren(self)

	local currentY      = self:titleBarHeight() + CONST.LAYOUT.PADDING
	local rh            = self:resizeWidgetHeight()
	local contentHeight = self.height - currentY - CONST.LAYOUT.PADDING - rh

	self.contentPanel = ISPanel:new(
		CONST.LAYOUT.PADDING, currentY,
		self.width - (CONST.LAYOUT.PADDING * 2), contentHeight
	)
	self.contentPanel:initialise()
	self.contentPanel.borderColor     = { r = 0, g = 0, b = 0, a = 0 }
	self.contentPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.contentPanel.anchorRight     = true
	self.contentPanel.anchorBottom    = true
	self:addChild(self.contentPanel)

	self:createMainLayout()
	self:updateRoleList()
	self:updateButtonStates()
end

function RoleDisplaySystem.UI_Manager:onResize()
	ISCollapsableWindow.onResize(self)

	if not self.contentPanel then return end

	local currentY = self.contentPanel:getY()
	local rh       = self:resizeWidgetHeight()

	self.contentPanel:setWidth(self.width - (CONST.LAYOUT.PADDING * 2))
	self.contentPanel:setHeight(self.height - currentY - CONST.LAYOUT.PADDING - rh)

	if self.leftPanel and self.rightPanel then
		local leftPanelWidth  = math.floor(self.contentPanel:getWidth() * 0.5)
		local rightPanelWidth = self.contentPanel:getWidth() - leftPanelWidth - CONST.LAYOUT.PADDING

		self.leftPanel:setWidth(leftPanelWidth)
		self.leftPanel:setHeight(self.contentPanel:getHeight())

		self.rightPanel:setX(leftPanelWidth + CONST.LAYOUT.PADDING)
		self.rightPanel:setWidth(rightPanelWidth)
		self.rightPanel:setHeight(self.contentPanel:getHeight())

		if self.roleList then
			local roleFilterY = self.rolesLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM
			if self.roleFilterEntry then
				self.roleFilterEntry:setY(roleFilterY)
				self.roleFilterEntry:setWidth(leftPanelWidth - CONST.LAYOUT.PADDING * 2)
			end

			local roleListY = self.roleFilterEntry and self.roleFilterEntry:getBottom() + CONST.LAYOUT.PADDING or self.rolesLabel:getBottom() + CONST.LAYOUT.PADDING
			local roleListHeight = math.floor((
				self.leftPanel:getHeight()
				- CONST.LAYOUT.PADDING * 6
				- CONST.LAYOUT.BUTTON.HEIGHT * 2
				- CONST.LAYOUT.ELEMENT_HEIGHT * 4
			) / 2)
			self.roleList:setY(roleListY)
			self.roleList:setWidth(leftPanelWidth - CONST.LAYOUT.PADDING * 2)
			self.roleList:setHeight(roleListHeight)

			local buttonY     = self.roleList:getBottom() + CONST.LAYOUT.PADDING
			local buttonWidth = (leftPanelWidth - CONST.LAYOUT.PADDING * 3) / 2

			if self.addRoleButton then
				self.addRoleButton:setY(buttonY)
				self.addRoleButton:setWidth(buttonWidth)
			end
			if self.removeRoleButton then
				self.removeRoleButton:setY(buttonY)
				self.removeRoleButton:setX(self.addRoleButton:getRight() + CONST.LAYOUT.PADDING)
				self.removeRoleButton:setWidth(buttonWidth)
			end
		end

		if self.playersInRoleLabel and self.playerList then
			local playerSectionY = self.removeRoleButton:getBottom() + CONST.LAYOUT.SPACING.SECTION
			self.playersInRoleLabel:setY(playerSectionY)

			local playerFilterY = self.playersInRoleLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM
			if self.playerFilterEntry then
				self.playerFilterEntry:setY(playerFilterY)
				self.playerFilterEntry:setWidth(leftPanelWidth - CONST.LAYOUT.PADDING * 2)
			end

			local playerListY      = self.playerFilterEntry and self.playerFilterEntry:getBottom() + CONST.LAYOUT.PADDING or self.playersInRoleLabel:getBottom() + CONST.LAYOUT.PADDING
			local playerListHeight = self.leftPanel:getHeight()
				- playerListY
				- CONST.LAYOUT.PADDING * 2
				- CONST.LAYOUT.BUTTON.HEIGHT

			self.playerList:setY(playerListY)
			self.playerList:setWidth(leftPanelWidth - CONST.LAYOUT.PADDING * 2)
			self.playerList:setHeight(playerListHeight)

			local buttonY     = self.playerList:getBottom() + CONST.LAYOUT.PADDING
			local buttonWidth = (leftPanelWidth - CONST.LAYOUT.PADDING * 3) / 2

			if self.addPlayerButton then
				self.addPlayerButton:setY(buttonY)
				self.addPlayerButton:setWidth(buttonWidth)
			end
			if self.removePlayerButton then
				self.removePlayerButton:setY(buttonY)
				self.removePlayerButton:setX(self.addPlayerButton:getRight() + CONST.LAYOUT.PADDING)
				self.removePlayerButton:setWidth(buttonWidth)
			end
		end

		if self.roleNameEntry then
			local fieldWidth = math.max(120, rightPanelWidth - CONST.LAYOUT.PADDING * 2)
			self.roleNameEntry:setWidth(fieldWidth)
			if self.bracketCombo then
				self.bracketCombo:setWidth(fieldWidth)
			end

			if self.settingsButton then
				local buttonWidth = math.floor((fieldWidth - CONST.LAYOUT.PADDING) / 2)
				local buttonY = self.rightPanel:getHeight() - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING
				self.saveRoleButton:setY(buttonY)
				self.saveRoleButton:setWidth(buttonWidth)
				self.settingsButton:setX(self.saveRoleButton:getRight() + CONST.LAYOUT.PADDING)
				self.settingsButton:setY(buttonY)
				self.settingsButton:setWidth(buttonWidth)
			end
			if self.previewPanel then
				self.previewPanel:setWidth(fieldWidth)
				local previewHeight = self.settingsButton
					and self.settingsButton:getY() - self.previewPanel:getY() - CONST.LAYOUT.PADDING
					or self.rightPanel:getHeight() - self.previewPanel:getY() - CONST.LAYOUT.PADDING
				self.previewPanel:setHeight(math.max(66, previewHeight))
			end
		end
	end
end

function RoleDisplaySystem.UI_Manager:createMainLayout()
	local leftPanelWidth  = math.floor(self.contentPanel:getWidth() * 0.5)
	local rightPanelWidth = self.contentPanel:getWidth() - leftPanelWidth - CONST.LAYOUT.PADDING

	self.leftPanel = ISPanel:new(0, 0, leftPanelWidth, self.contentPanel:getHeight())
	self.leftPanel:initialise()
	Theme.applyPanelStyle(self.leftPanel)
	self.leftPanel.anchorRight  = false
	self.leftPanel.anchorBottom = true
	self.contentPanel:addChild(self.leftPanel)

	self.rightPanel = ISPanel:new(leftPanelWidth + CONST.LAYOUT.PADDING, 0, rightPanelWidth, self.contentPanel:getHeight())
	self.rightPanel:initialise()
	Theme.applyPanelStyle(self.rightPanel)
	self.rightPanel.anchorLeft   = false
	self.rightPanel.anchorRight  = true
	self.rightPanel.anchorBottom = true
	self.contentPanel:addChild(self.rightPanel)

	self:createRoleSection()
	self:createPlayerSection()
	self:createRoleOptionsSection()
end

function RoleDisplaySystem.UI_Manager:createRoleSection()
	self.rolesLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_Roles"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.MEDIUM, true
	)
	self.leftPanel:addChild(self.rolesLabel)

	local listY = self.rolesLabel:getBottom() + CONST.LAYOUT.PADDING
	self.roleFilterEntry = ISTextEntryBox:new(
		"",
		CONST.LAYOUT.PADDING,
		self.rolesLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM,
		self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 2,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.roleFilterEntry:initialise()
	self.roleFilterEntry:instantiate()
	self.roleFilterEntry:setPlaceholderText(getText("IGUI_RM_FilterRoles"))
	Theme.applyFieldStyle(self.roleFilterEntry)
	self.roleFilterEntry.onTextChange = function() self:updateRoleList() end
	self.leftPanel:addChild(self.roleFilterEntry)

	listY = self.roleFilterEntry:getBottom() + CONST.LAYOUT.PADDING
	local listHeight = math.floor((
		self.leftPanel:getHeight()
		- CONST.LAYOUT.PADDING * 6
		- CONST.LAYOUT.BUTTON.HEIGHT * 2
		- CONST.LAYOUT.ELEMENT_HEIGHT * 4
	) / 2)

	self.roleList = ISScrollingListBox:new(
		CONST.LAYOUT.PADDING, listY,
		self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 2, listHeight
	)
	self.roleList:initialise()
	self.roleList:instantiate()
	self.roleList.itemheight  = CONST.LAYOUT.ROLE_ROW_HEIGHT
	self.roleList.selected    = 0
	self.roleList.joypadParent = self
	self.roleList.font        = CONST.FONT.SMALL
	self.roleList.doDrawItem  = self.drawRoleListItem
	self.roleList.onMouseDown = self.onRoleListMouseDown
	self.roleList.target      = self
	self.roleList.anchorRight = true
	self.roleList.anchorBottom = false
	Theme.applyListStyle(self.roleList)
	self.roleList.drawBorder  = true
	self.roleList.borderColor = Theme.copy(T.borderDim)
	self.leftPanel:addChild(self.roleList)

	local buttonY     = self.roleList:getBottom() + CONST.LAYOUT.PADDING
	local buttonWidth = (self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 3) / 2

	self.addRoleButton = ISButton:new(
		CONST.LAYOUT.PADDING, buttonY,
		buttonWidth, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_AddRole"), self, self.onAddRole
	)
	self.addRoleButton:initialise()
	self.addRoleButton:instantiate()
	Theme.applyButtonStyle(self.addRoleButton)
	self.addRoleButton.anchorTop    = false
	self.addRoleButton.anchorBottom = false
	self.addRoleButton.anchorRight  = false
	self.leftPanel:addChild(self.addRoleButton)

	self.removeRoleButton = ISButton:new(
		self.addRoleButton:getRight() + CONST.LAYOUT.PADDING, buttonY,
		buttonWidth, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_RemoveRole"), self, self.onRemoveRole
	)
	self.removeRoleButton:initialise()
	self.removeRoleButton:instantiate()
	Theme.applyButtonStyle(self.removeRoleButton, "danger")
	self.removeRoleButton:setEnable(false)
	self.removeRoleButton.anchorLeft   = false
	self.removeRoleButton.anchorTop    = false
	self.removeRoleButton.anchorRight  = true
	self.removeRoleButton.anchorBottom = false
	self.leftPanel:addChild(self.removeRoleButton)
end

function RoleDisplaySystem.UI_Manager:createPlayerSection()
	local playerSectionY = self.removeRoleButton:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.playersInRoleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, playerSectionY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_PlayersInRole"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.MEDIUM, true
	)
	self.leftPanel:addChild(self.playersInRoleLabel)

	self.playerFilterEntry = ISTextEntryBox:new(
		"",
		CONST.LAYOUT.PADDING,
		self.playersInRoleLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM,
		self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 2,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.playerFilterEntry:initialise()
	self.playerFilterEntry:instantiate()
	self.playerFilterEntry:setPlaceholderText(getText("IGUI_RM_FilterPlayers"))
	Theme.applyFieldStyle(self.playerFilterEntry)
	self.playerFilterEntry.onTextChange = function() self:updatePlayerList() end
	self.leftPanel:addChild(self.playerFilterEntry)

	local playerListY      = self.playerFilterEntry:getBottom() + CONST.LAYOUT.PADDING
	local playerListHeight = self.leftPanel:getHeight()
		- playerListY
		- CONST.LAYOUT.PADDING * 2
		- CONST.LAYOUT.BUTTON.HEIGHT

	self.playerList = ISScrollingListBox:new(
		CONST.LAYOUT.PADDING, playerListY,
		self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 2, playerListHeight
	)
	self.playerList:initialise()
	self.playerList:instantiate()
	self.playerList.itemheight   = CONST.LAYOUT.ELEMENT_HEIGHT
	self.playerList.selected     = 0
	self.playerList.joypadParent = self
	self.playerList.font         = CONST.FONT.SMALL
	self.playerList.doDrawItem   = self.drawPlayerListItem
	self.playerList.onMouseDown  = self.onPlayerListMouseDown
	self.playerList.target       = self
	self.playerList.anchorRight  = true
	self.playerList.anchorBottom = true
	Theme.applyListStyle(self.playerList)
	self.playerList.drawBorder   = true
	self.playerList.borderColor  = Theme.copy(T.borderDim)
	self.leftPanel:addChild(self.playerList)

	local buttonY     = self.playerList:getBottom() + CONST.LAYOUT.PADDING
	local buttonWidth = (self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 3) / 2

	self.addPlayerButton = ISButton:new(
		CONST.LAYOUT.PADDING, buttonY,
		buttonWidth, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_AddPlayer"), self, self.onAddPlayer
	)
	self.addPlayerButton:initialise()
	self.addPlayerButton:instantiate()
	Theme.applyButtonStyle(self.addPlayerButton)
	self.addPlayerButton:setEnable(false)
	self.addPlayerButton.anchorLeft   = true
	self.addPlayerButton.anchorTop    = false
	self.addPlayerButton.anchorRight  = false
	self.addPlayerButton.anchorBottom = true
	self.leftPanel:addChild(self.addPlayerButton)

	self.removePlayerButton = ISButton:new(
		self.addPlayerButton:getRight() + CONST.LAYOUT.PADDING, buttonY,
		buttonWidth, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_RemovePlayer"), self, self.onRemovePlayer
	)
	self.removePlayerButton:initialise()
	self.removePlayerButton:instantiate()
	Theme.applyButtonStyle(self.removePlayerButton, "danger")
	self.removePlayerButton:setEnable(false)
	self.removePlayerButton.anchorLeft   = false
	self.removePlayerButton.anchorTop    = false
	self.removePlayerButton.anchorRight  = true
	self.removePlayerButton.anchorBottom = true
	self.leftPanel:addChild(self.removePlayerButton)
end

function RoleDisplaySystem.UI_Manager:createRoleOptionsSection()
	self.roleOptionsLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_RoleOptions"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.MEDIUM, true
	)
	self.rightPanel:addChild(self.roleOptionsLabel)

	local currentY = self.roleOptionsLabel:getBottom() + CONST.LAYOUT.SPACING.SECTION
	local fieldWidth = self.rightPanel:getWidth() - CONST.LAYOUT.PADDING * 2

	self.roleNameLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_RoleName") .. ":",
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self.rightPanel:addChild(self.roleNameLabel)

	self.roleNameEntry = ISTextEntryBox:new(
		"",
		CONST.LAYOUT.PADDING,
		currentY + CONST.LAYOUT.ELEMENT_HEIGHT + CONST.LAYOUT.SPACING.ITEM,
		fieldWidth,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.roleNameEntry:initialise()
	self.roleNameEntry:instantiate()
	Theme.applyFieldStyle(self.roleNameEntry)
	self.roleNameEntry.onTextChange = function() self:onRoleNameChanged() end
	self.rightPanel:addChild(self.roleNameEntry)

	currentY = self.roleNameEntry:getBottom() + CONST.LAYOUT.SPACING.SECTION

	local halfWidth = math.floor((fieldWidth - CONST.LAYOUT.PADDING) / 2)

	self.roleColorLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_RoleColor") .. ":",
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self.rightPanel:addChild(self.roleColorLabel)

	self.roleColorButton = ISButton:new(
		CONST.LAYOUT.PADDING,
		currentY + CONST.LAYOUT.ELEMENT_HEIGHT + CONST.LAYOUT.SPACING.ITEM,
		math.max(110, halfWidth - CONST.LAYOUT.ELEMENT_HEIGHT - CONST.LAYOUT.SPACING.ITEM),
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_ChooseColor"), self, self.onChooseColor
	)
	self.roleColorButton:initialise()
	self.roleColorButton:instantiate()
	Theme.applyButtonStyle(self.roleColorButton)
	self.rightPanel:addChild(self.roleColorButton)

	self.roleColorPreview = ISPanel:new(
		self.roleColorButton:getRight() + CONST.LAYOUT.SPACING.ITEM,
		currentY + CONST.LAYOUT.ELEMENT_HEIGHT + CONST.LAYOUT.SPACING.ITEM,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.roleColorPreview:initialise()
	self.roleColorPreview.borderColor     = Theme.copy(T.border)
	self.roleColorPreview.backgroundColor = { r = 1, g = 1, b = 1, a = 1 }
	self.rightPanel:addChild(self.roleColorPreview)

	self.currentRoleColor = { r = 1, g = 1, b = 1, a = 1 }

	self.priorityLabel = ISLabel:new(
		CONST.LAYOUT.PADDING + halfWidth + CONST.LAYOUT.PADDING,
		currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_Priority") .. ":",
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self.rightPanel:addChild(self.priorityLabel)

	self.priorityEntry = ISTextEntryBox:new(
		"1",
		self.priorityLabel:getX(),
		self.roleColorButton:getY(),
		halfWidth,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.priorityEntry:initialise()
	self.priorityEntry:instantiate()
	self.priorityEntry:setOnlyNumbers(true)
	Theme.applyFieldStyle(self.priorityEntry)
	self.priorityEntry.onTextChange = function() self:onRolePriorityChanged() end
	self.rightPanel:addChild(self.priorityEntry)

	currentY = self.roleColorButton:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.bracketStyleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_BracketStyle") .. ":",
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self.rightPanel:addChild(self.bracketStyleLabel)

	self.bracketCombo = ISComboBox:new(
		CONST.LAYOUT.PADDING,
		self.bracketStyleLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM,
		fieldWidth,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		self,
		self.onBracketStyleSelected
	)
	self.bracketCombo:initialise()
	self.bracketCombo:instantiate()
	Theme.applyComboStyle(self.bracketCombo)
	addBracketStyleOptions(self.bracketCombo, "Role")
	selectComboData(self.bracketCombo, "square")
	self.rightPanel:addChild(self.bracketCombo)

	currentY = self.bracketCombo:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.showInMultipleTickBox = ISTickBox:new(
		CONST.LAYOUT.PADDING,
		currentY,
		fieldWidth,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		nil,
		nil
	)
	self.showInMultipleTickBox:initialise()
	self.showInMultipleTickBox:instantiate()
	self.showInMultipleTickBox:addOption(getText("IGUI_RM_ShowRoleInMultiple"), "showInMultiple")
	self.showInMultipleTickBox:setSelected(1, true)
	Theme.applyTickBoxStyle(self.showInMultipleTickBox)
	self.rightPanel:addChild(self.showInMultipleTickBox)

	currentY = self.showInMultipleTickBox:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.previewLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_LivePreview"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.MEDIUM, true
	)
	self.rightPanel:addChild(self.previewLabel)

	self.previewPanel = ISPanel:new(
		CONST.LAYOUT.PADDING,
		self.previewLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM,
		fieldWidth,
		82
	)
	self.previewPanel:initialise()
	self.previewPanel.backgroundColor = Theme.copy(T.panelDark)
	self.previewPanel.borderColor = Theme.copy(T.borderDim)
	self.previewPanel.manager = self
	self.previewPanel.render = function(panel)
		if panel.manager and panel.manager.renderPreviewPanel then
			panel.manager:renderPreviewPanel(panel)
		end
	end
	self.rightPanel:addChild(self.previewPanel)

	local bottomButtonY = self.rightPanel:getHeight() - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING
	local buttonWidth = math.floor((fieldWidth - CONST.LAYOUT.PADDING) / 2)

	self.saveRoleButton = ISButton:new(
		CONST.LAYOUT.PADDING, bottomButtonY,
		buttonWidth, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_SaveRole"), self, self.onSaveRole
	)
	self.saveRoleButton:initialise()
	self.saveRoleButton:instantiate()
	Theme.applyButtonStyle(self.saveRoleButton, "success")
	self.saveRoleButton:setEnable(false)
	self.saveRoleButton.anchorTop = false
	self.saveRoleButton.anchorBottom = true
	self.rightPanel:addChild(self.saveRoleButton)

	self.settingsButton = ISButton:new(
		self.saveRoleButton:getRight() + CONST.LAYOUT.PADDING,
		bottomButtonY,
		buttonWidth, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_DisplaySettings"), self, self.onOpenDisplaySettings
	)
	self.settingsButton:initialise()
	self.settingsButton:instantiate()
	Theme.applyButtonStyle(self.settingsButton)
	self.settingsButton.anchorTop = false
	self.settingsButton.anchorBottom = true
	self.settingsButton.anchorRight = true
	self.rightPanel:addChild(self.settingsButton)

	self:hideRoleOptions(true)
end

function RoleDisplaySystem.UI_Manager:drawRoleListItem(y, item, alt)
	local role = item.item
	if not role then return y end

	local isSelected = self.selected == item.index
	if isSelected then
		self:drawRect(0, y, self:getWidth(), self.itemheight - 1, Theme.d(T.selected))
	elseif alt then
		self:drawRect(0, y, self:getWidth(), self.itemheight - 1, Theme.d(T.listAlt))
	end

	local roleColor   = RoleDisplaySystem.Shared.GetRoleColor(role)
	local swatchSize  = 14
	local swatchX     = CONST.LAYOUT.PADDING
	local swatchY     = y + 6
	self:drawRect(swatchX, swatchY, swatchSize, swatchSize, roleColor.a, roleColor.r, roleColor.g, roleColor.b)
	self:drawRectBorder(swatchX, swatchY, swatchSize, swatchSize, Theme.d(T.borderLight))

	local displayText = RoleDisplaySystem.Shared.FormatRoleTag(role)
	local textX       = swatchX + swatchSize + CONST.LAYOUT.SPACING.ITEM
	local textY       = y + 4

	self:drawText(
		displayText,
		textX, textY,
		roleColor.r, roleColor.g, roleColor.b, roleColor.a,
		self.font
	)

	local playerCount = role.players and #role.players or 0
	local priorityText = getText("IGUI_RM_PriorityShort", tostring(role.priority or 1))
	local countText   = getText("IGUI_RM_PlayerCountShort", tostring(playerCount))
	local metaText    = priorityText .. "   " .. countText
	local metaY       = y + 21
	self:drawText(
		metaText,
		textX, metaY,
		T.textMuted.r, T.textMuted.g, T.textMuted.b, 1,
		self.font
	)

	return y + self.itemheight
end

function RoleDisplaySystem.UI_Manager:drawPlayerListItem(y, item, alt)
	local username   = item.text
	local isSelected = self.selected == item.index

	if isSelected then
		self:drawRect(0, y, self:getWidth(), self.itemheight - 1, Theme.d(T.selected))
	elseif alt then
		self:drawRect(0, y, self:getWidth(), self.itemheight - 1, Theme.d(T.listAlt))
	end

	self:drawText(
		username,
		CONST.LAYOUT.PADDING,
		y + (self.itemheight - getTextManager():MeasureStringY(self.font, username)) / 2,
		T.text.r, T.text.g, T.text.b, T.text.a,
		self.font
	)

	return y + self.itemheight
end

function RoleDisplaySystem.UI_Manager:updateRoleList()
	self.roleList:clear()

	if not RoleDisplaySystem.Roles then return end

	local roles = {}
	local filter = entryFilterText(self.roleFilterEntry)
	for _, role in pairs(RoleDisplaySystem.Roles) do
		local tag = RoleDisplaySystem.Shared.FormatRoleTag(role)
		if textMatchesFilter(role.name, filter)
			or textMatchesFilter(tag, filter)
			or textMatchesFilter(role.id, filter)
		then
			roles[#roles + 1] = role
		end
	end
	table.sort(roles, function(a, b)
		local ap = tonumber(a.priority) or 1
		local bp = tonumber(b.priority) or 1
		if ap == bp then
			return tostring(a.name or ""):lower() < tostring(b.name or ""):lower()
		end
		return ap > bp
	end)

	for i = 1, #roles do
		local role = roles[i]
		self.roleList:addItem(role.name, role)
	end

	if self.selectedRole then
		local stillExists = false
		for i = 1, #self.roleList.items do
			if self.roleList.items[i].item.id == self.selectedRole.id then
				self.roleList.selected = i
				stillExists = true
				break
			end
		end
		if not stillExists then
			self.selectedRole = nil
		end
	end

	self:onRoleSelected()
end

function RoleDisplaySystem.UI_Manager:updatePlayerList()
	self.playerList:clear()
	self.playerList.selected = 0
	self.selectedPlayer = nil

	if not self.selectedRole or not self.selectedRole.players then return end

	local players = self.selectedRole.players
	local filter = entryFilterText(self.playerFilterEntry)
	for i = 1, #players do
		if textMatchesFilter(players[i], filter) then
			self.playerList:addItem(players[i], players[i])
		end
	end
end

function RoleDisplaySystem.UI_Manager:onRoleListMouseDown(x, y)
	if self.items and #self.items == 0 then return end

	local row = self:rowAt(x, y)
	if row > #self.items then row = #self.items end
	if row < 1           then row = 1           end

	local item = self.items[row].item
	getSoundManager():playUISound("UISelectListItem")
	self.selected = row
	if self.onmousedown then self.onmousedown(self.target, item) end

	local manager = self.target
	if manager and manager.onRoleSelected then
		manager:onRoleSelected()
	end
end

function RoleDisplaySystem.UI_Manager:onPlayerListMouseDown(x, y)
	ISScrollingListBox.onMouseDown(self, x, y)

	local manager = self.target
	if not manager then
		return
	end

	local selected = self.selected
	if selected > 0 and self.items[selected] then
		manager.selectedPlayer = self.items[selected].text
		if manager.removePlayerButton then
			manager.removePlayerButton:setEnable(true)
		end
	else
		manager.selectedPlayer = nil
		if manager.removePlayerButton then
			manager.removePlayerButton:setEnable(false)
		end
	end
end

function RoleDisplaySystem.UI_Manager:onRoleSelected()
	local selected = self.roleList.selected

	if selected <= 0 or not self.roleList.items[selected] then
		self.selectedRole   = nil
		self.selectedPlayer = nil
	else
		self.selectedRole   = self.roleList.items[selected].item
		self.selectedPlayer = nil
	end

	self:updatePlayerList()
	self:updateRoleOptions()
	self:updateButtonStates()
end

function RoleDisplaySystem.UI_Manager:updateRoleOptions()
	if not self.selectedRole then
		self:hideRoleOptions(true)
		return
	end

	self:hideRoleOptions(false)

	self.roleNameEntry:setText(self.selectedRole.name or "")
	self.priorityEntry:setText(tostring(self.selectedRole.priority or 1))

	if self.selectedRole.color then
		self.currentRoleColor = Theme.copy(self.selectedRole.color)
	else
		self.currentRoleColor = { r = 1, g = 1, b = 1, a = 1 }
	end

	self.roleColorPreview.backgroundColor = Theme.copy(self.currentRoleColor)

	local selectedStyle = self.selectedRole.bracketStyle or "square"
	self:updateBracketComboOptions(self.selectedRole.name or "Role")
	selectComboData(self.bracketCombo, selectedStyle)

	if self.showInMultipleTickBox then
		self.showInMultipleTickBox:setSelected(1, self.selectedRole.showInMultiple ~= false)
	end

	self:updateButtonStates()
end

function RoleDisplaySystem.UI_Manager:hideRoleOptions(hide)
	local elements = {
		self.roleNameLabel,    self.roleNameEntry,
		self.roleColorLabel,   self.roleColorButton,
		self.roleColorPreview, self.bracketStyleLabel,
		self.bracketCombo,     self.priorityLabel,
		self.priorityEntry,    self.saveRoleButton,
		self.showInMultipleTickBox,
		self.previewLabel,     self.previewPanel,
	}
	for i = 1, #elements do
		if elements[i] then elements[i]:setVisible(not hide) end
	end
end

function RoleDisplaySystem.UI_Manager:updateButtonStates()
	local hasRoleSelection   = self.selectedRole   ~= nil
	local hasPlayerSelection = self.selectedPlayer ~= nil

	self.removeRoleButton:setEnable(hasRoleSelection)
	self.addPlayerButton:setEnable(hasRoleSelection)
	self.removePlayerButton:setEnable(hasPlayerSelection)
	self.saveRoleButton:setEnable(hasRoleSelection and self.roleNameEntry and entryCurrentText(self.roleNameEntry):trim() ~= "")
end

function RoleDisplaySystem.UI_Manager:updateDisplaySettingsControls()
	local tickBox = self.displaySettingsTickBox
	if not tickBox then
		return
	end

	local rendererConfig = RoleDisplaySystem.RoleRenderer and RoleDisplaySystem.RoleRenderer.Config
	local mapConfig = RoleDisplaySystem.MapIntegration and RoleDisplaySystem.MapIntegration.Config

	tickBox:setSelected(1, not rendererConfig or rendererConfig.ENABLED ~= false)
	tickBox:setSelected(2, not mapConfig or mapConfig.ENABLED ~= false)
	tickBox:setSelected(3, RoleDisplaySystem.CHAT_CONFIG.ENABLED ~= false)
	tickBox:setSelected(4, RoleDisplaySystem.CHAT_CONFIG.SHOW_MULTIPLE_ROLES ~= false)
end

function RoleDisplaySystem.UI_Manager:onDisplaySettingChanged(index, selected, arg1, arg2, tickBox)
	tickBox = tickBox or self.displaySettingsTickBox
	local setting = tickBox and tickBox:getOptionData(index)
	if not setting then
		return
	end

	if setting == "aboveNames" then
		if RoleDisplaySystem.RoleRenderer and RoleDisplaySystem.RoleRenderer.Config then
			RoleDisplaySystem.RoleRenderer.Config.ENABLED = selected == true
		end
	elseif setting == "maps" then
		if RoleDisplaySystem.MapIntegration and RoleDisplaySystem.MapIntegration.Config then
			RoleDisplaySystem.MapIntegration.Config.ENABLED = selected == true
		end
	elseif setting == "chat" then
		RoleDisplaySystem.CHAT_CONFIG.ENABLED = selected == true
	elseif setting == "multiple" then
		RoleDisplaySystem.CHAT_CONFIG.SHOW_MULTIPLE_ROLES = selected == true
		if RoleDisplaySystem.MapIntegration and RoleDisplaySystem.MapIntegration.Config then
			RoleDisplaySystem.MapIntegration.Config.SHOW_MULTIPLE_ROLES = selected == true
		end
	end
end

RoleDisplaySystem.UI_Manager.DisplaySettingsModal = ISPanelJoypad:derive("RoleManager_DisplaySettingsModal")

function RoleDisplaySystem.UI_Manager.DisplaySettingsModal:new(parent, x, y, width, height)
	local o = ISPanelJoypad:new(
		x, y,
		width or CONST.LAYOUT.WINDOW_SIZE.DISPLAY_SETTINGS_MODAL.WIDTH,
		height or CONST.LAYOUT.WINDOW_SIZE.DISPLAY_SETTINGS_MODAL.HEIGHT
	)
	setmetatable(o, self)
	self.__index = self

	o.parent = parent
	o.backgroundColor = Theme.copy(T.background)
	o.borderColor = Theme.copy(T.border)
	o.background = true
	o.moveWithMouse = true

	return o
end

function RoleDisplaySystem.UI_Manager.DisplaySettingsModal:createChildren()
	self.titleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_DisplaySettings"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.MEDIUM, true
	)
	self:addChild(self.titleLabel)

	self.displaySettingsTickBox = ISTickBox:new(
		CONST.LAYOUT.PADDING,
		self.titleLabel:getBottom() + CONST.LAYOUT.PADDING,
		self.width - CONST.LAYOUT.PADDING * 2,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		self.parent,
		self.parent.onDisplaySettingChanged
	)
	self.displaySettingsTickBox:initialise()
	self.displaySettingsTickBox:instantiate()
	self.displaySettingsTickBox:addOption(getText("IGUI_RM_ShowAboveNames"), "aboveNames")
	self.displaySettingsTickBox:addOption(getText("IGUI_RM_ShowOnMaps"), "maps")
	self.displaySettingsTickBox:addOption(getText("IGUI_RM_ShowInChat"), "chat")
	self.displaySettingsTickBox:addOption(getText("IGUI_RM_ShowMultipleRoles"), "multiple")
	Theme.applyTickBoxStyle(self.displaySettingsTickBox)
	self:addChild(self.displaySettingsTickBox)

	local previousTickBox = self.parent.displaySettingsTickBox
	self.parent.displaySettingsTickBox = self.displaySettingsTickBox
	self.parent:updateDisplaySettingsControls()
	self.parent.displaySettingsTickBox = previousTickBox

	self.closeButton = ISButton:new(
		self.width - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING,
		self.height - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_Close"),
		self,
		self.onClose
	)
	self.closeButton:initialise()
	self.closeButton:instantiate()
	Theme.applyButtonStyle(self.closeButton)
	self:addChild(self.closeButton)
end

function RoleDisplaySystem.UI_Manager.DisplaySettingsModal:onClose()
	self:close()
end

function RoleDisplaySystem.UI_Manager.DisplaySettingsModal:close()
	if self.parent and self.parent.displaySettingsModal == self then
		self.parent.displaySettingsModal = nil
	end
	self:setVisible(false)
	self:removeFromUIManager()
end

function RoleDisplaySystem.UI_Manager:onOpenDisplaySettings()
	if self.displaySettingsModal and self.displaySettingsModal:isVisible() then
		self.displaySettingsModal:bringToTop()
		return
	end

	local modal = RoleDisplaySystem.UI_Manager.DisplaySettingsModal:new(
		self,
		(getCore():getScreenWidth() / 2) - (CONST.LAYOUT.WINDOW_SIZE.DISPLAY_SETTINGS_MODAL.WIDTH / 2),
		(getCore():getScreenHeight() / 2) - (CONST.LAYOUT.WINDOW_SIZE.DISPLAY_SETTINGS_MODAL.HEIGHT / 2),
		CONST.LAYOUT.WINDOW_SIZE.DISPLAY_SETTINGS_MODAL.WIDTH,
		CONST.LAYOUT.WINDOW_SIZE.DISPLAY_SETTINGS_MODAL.HEIGHT
	)
	modal:initialise()
	modal:addToUIManager()
	modal:bringToTop()
	self.displaySettingsModal = modal
end

function RoleDisplaySystem.UI_Manager:getEditorPreviewRole()
	local role = self.selectedRole or {}
	local name = role.name or "Role"

	if self.roleNameEntry and self.roleNameEntry:isVisible() then
		local entryName = entryCurrentText(self.roleNameEntry)
		if entryName and entryName:trim() ~= "" then
			name = entryName:trim()
		end
	end

	local bracketStyle = role.bracketStyle or "square"
	bracketStyle = getSelectedComboData(self.bracketCombo, bracketStyle)

	return {
		name = name,
		color = self.currentRoleColor or role.color or { r = 1, g = 1, b = 1, a = 1 },
		bracketStyle = bracketStyle,
		priority = tonumber(entryCurrentText(self.priorityEntry)) or role.priority or 1,
		showInMultiple = not self.showInMultipleTickBox or self.showInMultipleTickBox:isSelected(1),
		players = role.players or {},
	}
end

function RoleDisplaySystem.UI_Manager:renderPreviewPanel(panel)
	panel:drawRect(0, 0, panel:getWidth(), panel:getHeight(), Theme.d(T.panelDark))
	panel:drawRectBorder(0, 0, panel:getWidth(), panel:getHeight(), Theme.d(T.borderDim))

	local role = self:getEditorPreviewRole()
	local roleTag = RoleDisplaySystem.Shared.FormatRoleTag(role)
	local roleColor = RoleDisplaySystem.Shared.GetRoleColor(role)
	local username = self.username ~= "" and self.username or "Player"
	local x = CONST.LAYOUT.PADDING
	local y = CONST.LAYOUT.PADDING
	local rowHeight = getTextManager():getFontHeight(CONST.FONT.SMALL) + 6

	local rows = {
		{ label = getText("IGUI_RM_PreviewAbove"), value = roleTag .. " " .. username },
		{ label = getText("IGUI_RM_PreviewChat"), value = roleTag .. " " .. username .. ": ..." },
		{ label = getText("IGUI_RM_PreviewMap"), value = roleTag },
	}

	for i = 1, #rows do
		local label = rows[i].label .. ":"
		local labelWidth = getTextManager():MeasureStringX(CONST.FONT.SMALL, label) + 8
		panel:drawText(label, x, y, T.textMuted.r, T.textMuted.g, T.textMuted.b, 1, CONST.FONT.SMALL)
		panel:drawText(rows[i].value, x + labelWidth, y, roleColor.r, roleColor.g, roleColor.b, 1, CONST.FONT.SMALL)
		y = y + rowHeight
	end
end

RoleDisplaySystem.UI_Manager.RoleEditorModal = ISPanelJoypad:derive("RoleManager_RoleEditorModal")

function RoleDisplaySystem.UI_Manager.RoleEditorModal:new(parent, x, y, width, height)
	local o = ISPanelJoypad:new(
		x, y,
		width or CONST.LAYOUT.WINDOW_SIZE.ROLE_EDITOR_MODAL.WIDTH,
		height or CONST.LAYOUT.WINDOW_SIZE.ROLE_EDITOR_MODAL.HEIGHT
	)
	setmetatable(o, self)
	self.__index = self

	o.parent = parent
	o.player = parent.player
	o.currentRoleColor = { r = 1, g = 1, b = 1, a = 1 }
	o.backgroundColor = Theme.copy(T.background)
	o.borderColor = Theme.copy(T.border)
	o.background = true
	o.moveWithMouse = true
	o.currentBracketStyle = "square"

	return o
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:createChildren()
	self.titleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_NewRole"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.MEDIUM, true
	)
	self:addChild(self.titleLabel)

	local currentY = self.titleLabel:getBottom() + CONST.LAYOUT.PADDING

	self.nameLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_RoleName") .. ":",
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self:addChild(self.nameLabel)

	self.nameEntry = ISTextEntryBox:new(
		"",
		CONST.LAYOUT.PADDING,
		self.nameLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM,
		self.width - CONST.LAYOUT.PADDING * 2,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.nameEntry:initialise()
	self.nameEntry:instantiate()
	self.nameEntry:setPlaceholderText(getText("IGUI_RM_EnterRoleName"))
	Theme.applyFieldStyle(self.nameEntry)
	self.nameEntry.onTextChange = function() self:onRoleNameChanged() end
	self:addChild(self.nameEntry)

	currentY = self.nameEntry:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.colorLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_RoleColor") .. ":",
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self:addChild(self.colorLabel)

	self.colorButton = ISButton:new(
		CONST.LAYOUT.PADDING,
		self.colorLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM,
		120, CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_ChooseColor"), self, self.onChooseColor
	)
	self.colorButton:initialise()
	self.colorButton:instantiate()
	Theme.applyButtonStyle(self.colorButton)
	self:addChild(self.colorButton)

	self.colorPreview = ISPanel:new(
		self.colorButton:getRight() + CONST.LAYOUT.SPACING.ITEM,
		self.colorButton:getY(),
		CONST.LAYOUT.ELEMENT_HEIGHT,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.colorPreview:initialise()
	self.colorPreview.backgroundColor = Theme.copy(self.currentRoleColor)
	self.colorPreview.borderColor = Theme.copy(T.border)
	self:addChild(self.colorPreview)

	self.priorityLabel = ISLabel:new(
		self.colorPreview:getRight() + CONST.LAYOUT.PADDING,
		self.colorButton:getY(),
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_Priority") .. ":",
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self:addChild(self.priorityLabel)

	self.priorityEntry = ISTextEntryBox:new(
		"1",
		self.priorityLabel:getRight() + CONST.LAYOUT.SPACING.ITEM,
		self.colorButton:getY(),
		52,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.priorityEntry:initialise()
	self.priorityEntry:instantiate()
	self.priorityEntry:setOnlyNumbers(true)
	Theme.applyFieldStyle(self.priorityEntry)
	self:addChild(self.priorityEntry)

	currentY = self.colorButton:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.bracketStyleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_BracketStyle") .. ":",
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self:addChild(self.bracketStyleLabel)

	self.bracketCombo = ISComboBox:new(
		CONST.LAYOUT.PADDING,
		self.bracketStyleLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM,
		self.width - CONST.LAYOUT.PADDING * 2,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		self,
		self.onBracketStyleSelected
	)
	self.bracketCombo:initialise()
	self.bracketCombo:instantiate()
	Theme.applyComboStyle(self.bracketCombo)
	addBracketStyleOptions(self.bracketCombo, "Role")
	selectComboData(self.bracketCombo, "square")
	self:addChild(self.bracketCombo)

	currentY = self.bracketCombo:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.showInMultipleTickBox = ISTickBox:new(
		CONST.LAYOUT.PADDING,
		currentY,
		self.width - CONST.LAYOUT.PADDING * 2,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		nil,
		nil
	)
	self.showInMultipleTickBox:initialise()
	self.showInMultipleTickBox:instantiate()
	self.showInMultipleTickBox:addOption(getText("IGUI_RM_ShowRoleInMultiple"), "showInMultiple")
	self.showInMultipleTickBox:setSelected(1, true)
	Theme.applyTickBoxStyle(self.showInMultipleTickBox)
	self:addChild(self.showInMultipleTickBox)

	currentY = self.showInMultipleTickBox:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.addSelfTickBox = ISTickBox:new(
		CONST.LAYOUT.PADDING,
		currentY,
		self.width - CONST.LAYOUT.PADDING * 2,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		"",
		nil,
		nil
	)
	self.addSelfTickBox:initialise()
	self.addSelfTickBox:instantiate()
	self.addSelfTickBox:addOption(getText("IGUI_RM_AddMeToRole"), "addSelf")
	self.addSelfTickBox:setSelected(1, true)
	Theme.applyTickBoxStyle(self.addSelfTickBox)
	self:addChild(self.addSelfTickBox)

	local buttonY = self.height - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING
	self.cancelButton = ISButton:new(
		self.width - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING,
		buttonY,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_Cancel"),
		self,
		self.onCancel
	)
	self.cancelButton:initialise()
	self.cancelButton:instantiate()
	Theme.applyButtonStyle(self.cancelButton)
	self:addChild(self.cancelButton)

	self.createButton = ISButton:new(
		self.cancelButton:getX() - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING,
		buttonY,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_CreateRole"),
		self,
		self.onCreate
	)
	self.createButton:initialise()
	self.createButton:instantiate()
	Theme.applyButtonStyle(self.createButton, "success")
	self:addChild(self.createButton)
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:updateBracketComboOptions(roleName)
	if not self.bracketCombo then return end

	local selectedStyle = getSelectedComboData(self.bracketCombo, "square")
	addBracketStyleOptions(self.bracketCombo, roleName)
	selectComboData(self.bracketCombo, selectedStyle)
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:getPreviewRole()
	local name = entryCurrentText(self.nameEntry)
	if not name or name:trim() == "" then
		name = "Role"
	else
		name = name:trim()
	end

	return {
		name = name,
		color = self.currentRoleColor,
		bracketStyle = self.currentBracketStyle,
		priority = tonumber(entryCurrentText(self.priorityEntry)) or 1,
		showInMultiple = not self.showInMultipleTickBox or self.showInMultipleTickBox:isSelected(1),
		players = {},
	}
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:renderPreviewPanel(panel)
	panel:drawRect(0, 0, panel:getWidth(), panel:getHeight(), Theme.d(T.panelDark))
	panel:drawRectBorder(0, 0, panel:getWidth(), panel:getHeight(), Theme.d(T.borderDim))

	local role = self:getPreviewRole()
	local roleTag = RoleDisplaySystem.Shared.FormatRoleTag(role)
	local roleColor = RoleDisplaySystem.Shared.GetRoleColor(role)
	local username = self.parent and self.parent.username ~= "" and self.parent.username or "Player"
	local previewText = roleTag .. " " .. username
	local priorityText = getText("IGUI_RM_PriorityShort", tostring(role.priority or 1))

	panel:drawText(previewText, CONST.LAYOUT.PADDING, 10, roleColor.r, roleColor.g, roleColor.b, 1, CONST.FONT.SMALL)
	panel:drawText(priorityText, CONST.LAYOUT.PADDING, 32, T.textMuted.r, T.textMuted.g, T.textMuted.b, 1, CONST.FONT.SMALL)
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:onRoleNameChanged()
	self:updateBracketComboOptions(entryCurrentText(self.nameEntry))
	self.currentBracketStyle = getSelectedComboData(self.bracketCombo, "square")
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:onBracketStyleSelected(combo)
	self.currentBracketStyle = getSelectedComboData(combo, "square")
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:onChooseColor()
	local colorPicker = ISColorPicker:new(0, 0)
	colorPicker:initialise()
	colorPicker:instantiate()
	colorPicker:setInitialColor(Color.new(self.currentRoleColor.r, self.currentRoleColor.g, self.currentRoleColor.b, 1.0))
	colorPicker:setPickedFunc(self.onColorPicked, self)
	colorPicker:setX(getCore():getScreenWidth() / 2 - colorPicker:getWidth() / 2)
	colorPicker:setY(getCore():getScreenHeight() / 2 - colorPicker:getHeight() / 2)
	colorPicker:addToUIManager()
	colorPicker:bringToTop()
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:onColorPicked(color, mouseUp, target)
	if not color then
		return
	end

	target.currentRoleColor = {
		r = color.r or 1,
		g = color.g or 1,
		b = color.b or 1,
		a = 1,
	}
	target.colorPreview.backgroundColor = Theme.copy(target.currentRoleColor)
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:onCreate()
	local name = entryCurrentText(self.nameEntry)
	if not name or name:trim() == "" then
		return
	end

	local role = self:getPreviewRole()
	role.id = RoleDisplaySystem.Shared.GenerateRoleId()
	role.name = name:trim()
	role.players = {}

	if self.addSelfTickBox:isSelected(1) and self.player and self.player.getUsername then
		role.players[#role.players + 1] = self.player:getUsername()
	end

	if self.parent then
		self.parent.selectedRole = role
	end
	RoleDisplaySystem.Client.AddRole(role)
	self:close()
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:onCancel()
	self:close()
end

function RoleDisplaySystem.UI_Manager.RoleEditorModal:close()
	if self.parent and self.parent.roleEditorModal == self then
		self.parent.roleEditorModal = nil
	end
	self:setVisible(false)
	self:removeFromUIManager()
end

function RoleDisplaySystem.UI_Manager:onAddRole()
	if self.roleEditorModal and self.roleEditorModal:isVisible() then
		self.roleEditorModal:bringToTop()
		return
	end

	local modal = RoleDisplaySystem.UI_Manager.RoleEditorModal:new(
		self,
		(getCore():getScreenWidth() / 2) - (CONST.LAYOUT.WINDOW_SIZE.ROLE_EDITOR_MODAL.WIDTH / 2),
		(getCore():getScreenHeight() / 2) - (CONST.LAYOUT.WINDOW_SIZE.ROLE_EDITOR_MODAL.HEIGHT / 2),
		CONST.LAYOUT.WINDOW_SIZE.ROLE_EDITOR_MODAL.WIDTH,
		CONST.LAYOUT.WINDOW_SIZE.ROLE_EDITOR_MODAL.HEIGHT
	)
	modal:initialise()
	modal:addToUIManager()
	modal:bringToTop()
	self.roleEditorModal = modal
end

function RoleDisplaySystem.UI_Manager:onRemoveRole()
	if not self.selectedRole then return end

	local modal = ISModalDialog:new(
		0, 0, 350, 150,
		getText("IGUI_RM_ConfirmDeleteRole", self.selectedRole.name),
		true, self, self.onDeleteRoleConfirm
	)
	modal:initialise()
	modal:addToUIManager()
	modal:setX((getCore():getScreenWidth()  / 2) - (modal:getWidth()  / 2))
	modal:setY((getCore():getScreenHeight() / 2) - (modal:getHeight() / 2))
end

function RoleDisplaySystem.UI_Manager:onDeleteRoleConfirm(button)
	if button.internal ~= "YES" or not self.selectedRole then return end

	RoleDisplaySystem.Client.RemoveRole(self.selectedRole.id)
	self.selectedRole = nil
	self:updateRoleOptions()
end

function RoleDisplaySystem.UI_Manager:onAddPlayer()
	if not self.selectedRole then return end

	self.playerSelectionModal = RoleDisplaySystem.UI_Manager.PlayerSelectionModal:new(
		self,
		(getCore():getScreenWidth()  / 2) - (CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.WIDTH  / 2),
		(getCore():getScreenHeight() / 2) - (CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.HEIGHT / 2),
		CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.WIDTH,
		CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.HEIGHT
	)
	self.playerSelectionModal:initialise()
	self.playerSelectionModal:addToUIManager()
	self.playerSelectionModal:bringToTop()
end

function RoleDisplaySystem.UI_Manager:onRemovePlayer()
	if not self.selectedRole or not self.selectedPlayer then return end

	RoleDisplaySystem.Client.RemovePlayerFromRole(self.selectedRole.id, self.selectedPlayer)
	self.selectedPlayer = nil
	self.removePlayerButton:setEnable(false)
end

function RoleDisplaySystem.UI_Manager:onSaveRole()
	if not self.selectedRole then return end

	local roleName = entryCurrentText(self.roleNameEntry):trim()
	if roleName == "" then return end

	self.selectedRole.name     = roleName
	self.selectedRole.priority = tonumber(entryCurrentText(self.priorityEntry)) or 1
	self.selectedRole.color    = Theme.copy(self.currentRoleColor)

	self.selectedRole.bracketStyle = getSelectedComboData(self.bracketCombo, self.selectedRole.bracketStyle or "square")
	self.selectedRole.showInMultiple = not self.showInMultipleTickBox or self.showInMultipleTickBox:isSelected(1)

	RoleDisplaySystem.Client.UpdateRole(self.selectedRole)
end

function RoleDisplaySystem.UI_Manager:updateBracketComboOptions(roleName)
	if not self.bracketCombo then return end

	local selectedStyle = getSelectedComboData(self.bracketCombo, "square")
	addBracketStyleOptions(self.bracketCombo, roleName)
	selectComboData(self.bracketCombo, selectedStyle)
end

function RoleDisplaySystem.UI_Manager:onChooseColor()
	local colorPicker = ISColorPicker:new(0, 0)
	colorPicker:initialise()
	colorPicker:instantiate()

	local currentColor = Color.new(self.currentRoleColor.r, self.currentRoleColor.g, self.currentRoleColor.b, 1.0)
	colorPicker:setInitialColor(currentColor)
	colorPicker:setPickedFunc(self.onColorPicked, self)

	local sw = getCore():getScreenWidth()
	local sh = getCore():getScreenHeight()
	colorPicker:setX(sw / 2 - colorPicker:getWidth()  / 2)
	colorPicker:setY(sh / 2 - colorPicker:getHeight() / 2)
	colorPicker:addToUIManager()
	colorPicker:bringToTop()
end

function RoleDisplaySystem.UI_Manager:onColorPicked(color, mouseUp, target)
	if not color then return end

	target.currentRoleColor = {
		r = color.r or 1,
		g = color.g or 1,
		b = color.b or 1,
		a = 1,
	}
	target.roleColorPreview.backgroundColor = Theme.copy(target.currentRoleColor)

	if target.selectedRole then
		target.selectedRole.color = Theme.copy(target.currentRoleColor)
	end
	target:updateRoleList()
end

function RoleDisplaySystem.UI_Manager:onBracketStyleSelected(combo)
	if not self.selectedRole then return end
	self.selectedRole.bracketStyle = getSelectedComboData(combo, "square")
end

function RoleDisplaySystem.UI_Manager:onRoleNameChanged()
	self:updateBracketComboOptions(entryCurrentText(self.roleNameEntry))
	self:updateButtonStates()
end

function RoleDisplaySystem.UI_Manager:onRolePriorityChanged()
	self:updateButtonStates()
end

function RoleDisplaySystem.UI_Manager:close()
	if self.displaySettingsModal then
		self.displaySettingsModal:close()
		self.displaySettingsModal = nil
	end
	if self.roleEditorModal then
		self.roleEditorModal:close()
		self.roleEditorModal = nil
	end
	if self.playerSelectionModal then
		self.playerSelectionModal:close()
		self.playerSelectionModal = nil
	end

	ISCollapsableWindow.close(self)
	self:removeFromUIManager()
	RoleDisplaySystem.UI_Manager.instance = nil
end

function RoleDisplaySystem.UI_Manager.toggle(playerNum)
	playerNum = playerNum or 0

	if RoleDisplaySystem.UI_Manager.instance then
		RoleDisplaySystem.UI_Manager.instance:close()
		return
	end

	local x = (getCore():getScreenWidth()  / 2) - (CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH  / 2)
	local y = (getCore():getScreenHeight() / 2) - (CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT / 2)

	local panel = RoleDisplaySystem.UI_Manager:new(
		x, y,
		CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH,
		CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT,
		playerNum
	)
	panel:initialise()
	panel:addToUIManager()
	RoleDisplaySystem.UI_Manager.instance = panel
	RoleDisplaySystem.Client.RequestRoles(false)
end

RoleDisplaySystem.UI_Manager.PlayerSelectionModal = ISPanelJoypad:derive("RoleManager_PlayerSelectionModal")
RoleDisplaySystem.UI_Manager.PlayerSelectionModal.scoreboard = nil

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:new(parent, x, y, width, height)
	local o = ISPanelJoypad:new(
		x, y,
		width  or CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.WIDTH,
		height or CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.HEIGHT
	)
	setmetatable(o, self)
	self.__index = self

	o.parent           = parent
	o.player           = parent.player
	o.selectedUsernames = {}
	o.backgroundColor  = Theme.copy(T.background)
	o.borderColor      = Theme.copy(T.border)
	o.background       = true
	o.moveWithMouse    = true
	o.anchorLeft       = true
	o.anchorRight      = true
	o.anchorTop        = true
	o.anchorBottom     = true
	o.currentTab       = "online"
	o.contentStartY    = 0

	return o
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:initialise()
	ISPanelJoypad.initialise(self)
	if isClient() then scoreboardUpdate() end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createChildren()
	self.titleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_AddPlayers"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.MEDIUM, true
	)
	self:addChild(self.titleLabel)

	local currentY = self.titleLabel:getBottom() + CONST.LAYOUT.PADDING
	self:createTabs(currentY)
	self.contentStartY = self.onlineTab:getBottom() + CONST.LAYOUT.PADDING

	self:createTabContent()

	local buttonY = self.height - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING

	self.cancelButton = ISButton:new(
		self.width - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING, buttonY,
		CONST.LAYOUT.BUTTON.WIDTH, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_Cancel"), self, self.onCancel
	)
	self.cancelButton:initialise()
	self.cancelButton:instantiate()
	Theme.applyButtonStyle(self.cancelButton)
	self:addChild(self.cancelButton)

	self.addButton = ISButton:new(
		self.cancelButton:getX() - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING, buttonY,
		CONST.LAYOUT.BUTTON.WIDTH, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_Add"), self, self.onAdd
	)
	self.addButton:initialise()
	self.addButton:instantiate()
	Theme.applyButtonStyle(self.addButton, "primary")
	self.addButton:setEnable(false)
	self:addChild(self.addButton)
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createTabs(y)
	local tabWidth = 120

	self.onlineTab = ISButton:new(
		CONST.LAYOUT.PADDING, y,
		tabWidth, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_OnlinePlayers"), self, self.onTabSelected
	)
	self.onlineTab:initialise()
	self.onlineTab:instantiate()
	self.onlineTab.internal         = "online"
	self.onlineTab.borderColor      = Theme.copy(T.border)
	self.onlineTab.backgroundColor  = Theme.copy(T.primary)
	self.onlineTab.backgroundColorMouseOver = Theme.copy(T.primaryHover)
	self:addChild(self.onlineTab)

	self.manualTab = ISButton:new(
		self.onlineTab:getRight() + CONST.LAYOUT.PADDING, y,
		tabWidth, CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_ManualInput"), self, self.onTabSelected
	)
	self.manualTab:initialise()
	self.manualTab:instantiate()
	self.manualTab.internal         = "manual"
	self.manualTab.borderColor      = Theme.copy(T.border)
	self.manualTab.backgroundColor  = Theme.copy(T.buttonBg)
	self.manualTab.backgroundColorMouseOver = Theme.copy(T.buttonHover)
	self:addChild(self.manualTab)
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createTabContent()
	local toRemove = {
		self.descLabel, self.playerList, self.instructLabel,
		self.usernameEntry, self.previewLabel, self.previewList,
	}
	for i = 1, #toRemove do
		if toRemove[i] then self:removeChild(toRemove[i]) end
	end

	if self.currentTab == "online" then
		self:createOnlineContent()
	else
		self:createManualContent()
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createOnlineContent()
	self.descLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, self.contentStartY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_SelectPlayersDesc"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self:addChild(self.descLabel)

	local listY      = self.descLabel:getBottom() + CONST.LAYOUT.PADDING
	local listHeight = self.height - listY - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING * 3

	self.playerList = ISScrollingListBox:new(
		CONST.LAYOUT.PADDING, listY,
		self.width - CONST.LAYOUT.PADDING * 2, listHeight
	)
	self.playerList:initialise()
	self.playerList:instantiate()
	self.playerList.itemheight   = CONST.LAYOUT.ELEMENT_HEIGHT
	self.playerList.font         = CONST.FONT.SMALL
	self.playerList.doDrawItem   = self.drawPlayerListItem
	self.playerList.onMouseDown  = self.onPlayerListMouseDown
	self.playerList.target       = self
	Theme.applyListStyle(self.playerList)
	self.playerList.drawBorder   = true
	self:addChild(self.playerList)

	self:populatePlayerList()
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createManualContent()
	self.descLabel = ISLabel:new(
		CONST.LAYOUT.PADDING, self.contentStartY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_ManualInputDesc"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self:addChild(self.descLabel)

	self.instructLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.descLabel:getBottom() + CONST.LAYOUT.PADDING / 2,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_ManualInputInstruct"),
		T.textMuted.r, T.textMuted.g, T.textMuted.b, 1,
		CONST.FONT.SMALL, true
	)
	self:addChild(self.instructLabel)

	self.usernameEntry = ISTextEntryBox:new(
		"",
		CONST.LAYOUT.PADDING,
		self.instructLabel:getBottom() + CONST.LAYOUT.PADDING,
		self.width - CONST.LAYOUT.PADDING * 2,
		100
	)
	self.usernameEntry:initialise()
	self.usernameEntry:instantiate()
	Theme.applyFieldStyle(self.usernameEntry)
	self.usernameEntry:setMultipleLine(true)
	self.usernameEntry:setMaxLines(10)
	self.usernameEntry.onTextChange = function() self:updateAddButton() end
	self:addChild(self.usernameEntry)

	self.previewLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.usernameEntry:getBottom() + CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_PreviewUsernames"),
		T.text.r, T.text.g, T.text.b, T.text.a,
		CONST.FONT.SMALL, true
	)
	self:addChild(self.previewLabel)

	local previewListY      = self.previewLabel:getBottom() + CONST.LAYOUT.PADDING / 2
	local previewListHeight = self.height - previewListY - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING * 3

	self.previewList = ISScrollingListBox:new(
		CONST.LAYOUT.PADDING, previewListY,
		self.width - CONST.LAYOUT.PADDING * 2, previewListHeight
	)
	self.previewList:initialise()
	self.previewList:instantiate()
	self.previewList.itemheight = CONST.LAYOUT.ELEMENT_HEIGHT
	self.previewList.font       = CONST.FONT.SMALL
	Theme.applyListStyle(self.previewList)
	self.previewList.drawBorder = true
	self:addChild(self.previewList)
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:populatePlayerList()
	self.playerList:clear()

	local players = {}

	if not isClient() and not isServer() then
		local username    = self.player:getUsername()
		local displayName = self.player:getDisplayName()
		local alreadyInRole = false

		if self.parent.selectedRole and self.parent.selectedRole.players then
			local existing = self.parent.selectedRole.players
			for i = 1, #existing do
				if existing[i] == username then
					alreadyInRole = true
					break
				end
			end
		end

		if not alreadyInRole then
			players[#players + 1] = {
				username    = username,
				displayName = displayName,
				selected    = false,
			}
		end
	elseif isClient() then
		local scoreboard = RoleDisplaySystem.UI_Manager.PlayerSelectionModal.scoreboard
		if not scoreboard then return end

		for i = 0, scoreboard.usernames:size() - 1 do
			local username    = scoreboard.usernames:get(i)
			local displayName = scoreboard.displayNames:get(i)
			local alreadyInRole = false

			if self.parent.selectedRole and self.parent.selectedRole.players then
				local existing = self.parent.selectedRole.players
				for j = 1, #existing do
					if existing[j] == username then
						alreadyInRole = true
						break
					end
				end
			end

			if not alreadyInRole then
				players[#players + 1] = {
					username    = username,
					displayName = displayName,
					selected    = false,
				}
			end
		end
	end

	table.sort(players, function(a, b)
		return (a.displayName or a.username):lower() < (b.displayName or b.username):lower()
	end)

	for i = 1, #players do
		local playerData = players[i]
		local item = self.playerList:addItem(playerData.displayName or playerData.username, playerData)
		if playerData.username ~= playerData.displayName then
			item.tooltip = playerData.username
		end
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:drawPlayerListItem(y, item, alt)
	local playerData = item.item

	if alt then
		self:drawRect(0, y, self:getWidth(), self.itemheight - 1, Theme.d(T.listAlt))
	end

	local checkboxSize = 16
	local checkboxX    = 10
	local checkboxY    = y + (self.itemheight - checkboxSize) / 2

	self:drawRectBorder(checkboxX, checkboxY, checkboxSize, checkboxSize, Theme.d(T.border))

	if playerData.selected then
		self:drawRect(
			checkboxX + 3, checkboxY + 3,
			checkboxSize - 6, checkboxSize - 6,
			Theme.d(T.success)
		)
	end

	local displayText = playerData.displayName or playerData.username
	local textHeight  = getTextManager():MeasureStringY(self.font, displayText)
	self:drawText(
		displayText,
		checkboxX + checkboxSize + 10,
		y + (self.itemheight - textHeight) / 2,
		T.text.r, T.text.g, T.text.b, 1,
		self.font
	)

	return y + self.itemheight
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:onPlayerListMouseDown(x, y)
	local row = self:rowAt(x, y)

	if row > 0 and row <= #self.items then
		local item = self.items[row].item
		item.selected = not item.selected
		local modal = self.target or self.parent
		if modal then
			modal:updateSelectedUsernames()
			modal:updateAddButton()
		end
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:updateSelectedUsernames()
	self.selectedUsernames = {}

	if self.currentTab == "online" then
		if self.playerList then
			local items = self.playerList.items
			for i = 1, #items do
				local item = items[i].item
				if item.selected then
					self.selectedUsernames[#self.selectedUsernames + 1] = item.username
				end
			end
		end
	else
		if self.usernameEntry then
			local text = entryCurrentText(self.usernameEntry)
			self.selectedUsernames = self:parseUsernames(text)

			if self.previewList then
				self.previewList:clear()
				local names = self.selectedUsernames
				for i = 1, #names do
					self.previewList:addItem(names[i], names[i])
				end
			end
		end
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:parseUsernames(text)
	local usernames = {}

	if not text or text:trim() == "" then return usernames end

	local parts = text:split(";")

	for i = 1, #parts do
		local username = parts[i]:trim()
		if username ~= "" then
			local isDuplicate = false
			for j = 1, #usernames do
				if usernames[j] == username then
					isDuplicate = true
					break
				end
			end
			if not isDuplicate then
				usernames[#usernames + 1] = username
			end
		end
	end

	return usernames
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:updateAddButton()
	self:updateSelectedUsernames()
	self.addButton:setEnable(#self.selectedUsernames > 0)
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:onTabSelected(button)
	if button.internal == self.currentTab then return end

	self.currentTab = button.internal

	self.onlineTab.backgroundColor = Theme.copy(self.currentTab == "online" and T.primary or T.buttonBg)
	self.manualTab.backgroundColor = Theme.copy(self.currentTab == "manual" and T.primary or T.buttonBg)

	self.selectedUsernames = {}
	self:createTabContent()

	if self.currentTab == "online" and isClient() then
		scoreboardUpdate()
	end

	self:updateAddButton()
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:onAdd()
	if not self.parent.selectedRole or #self.selectedUsernames == 0 then return end

	RoleDisplaySystem.Client.AddPlayersToRole(self.parent.selectedRole.id, self.selectedUsernames)
	self:close()
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:onCancel()
	self:close()
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:close()
	if self.parent and self.parent.playerSelectionModal == self then
		self.parent.playerSelectionModal = nil
	end
	self:setVisible(false)
	self:removeFromUIManager()
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal.onScoreboardUpdate(usernames, displayNames, steamIDs)
	RoleDisplaySystem.UI_Manager.PlayerSelectionModal.scoreboard = {
		usernames    = usernames,
		displayNames = displayNames,
		steamIDs     = steamIDs,
	}

	local ui = RoleDisplaySystem.UI_Manager.instance
	if ui and ui.playerSelectionModal and ui.playerSelectionModal:isVisible() then
		ui.playerSelectionModal:populatePlayerList()
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal.OnMiniScoreboardUpdate()
	if ISMiniScoreboardUI.instance then
		scoreboardUpdate()
	end
end

Events.OnScoreboardUpdate.Add(RoleDisplaySystem.UI_Manager.PlayerSelectionModal.onScoreboardUpdate)
Events.OnMiniScoreboardUpdate.Add(RoleDisplaySystem.UI_Manager.PlayerSelectionModal.OnMiniScoreboardUpdate)

return RoleDisplaySystem.UI_Manager
