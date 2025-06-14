local Logger = require("RoleDisplaySystem/Logger")
local RoleDisplaySystem = require("RoleDisplaySystem/Shared")

local CONST = {
	LAYOUT = {
		WINDOW_SIZE = {
			MAIN_PANEL = {
				WIDTH = 600,
				HEIGHT = 500,
			},
			PLAYER_SELECTION_MODAL = {
				WIDTH = 350,
				HEIGHT = 450,
			},
		},
		BUTTON = {
			WIDTH = 110,
			HEIGHT = 25,
		},
		LABEL = {
			WIDTH = 80,
		},
		ENTRY = {
			WIDTH = 200,
		},
		PADDING = 10,
		SPACING = {
			SECTION = 10,
			ITEM = 5,
		},
		ELEMENT_HEIGHT = 25,
		RADIO_SIZE = 16,
	},
	FONT = {
		SMALL = UIFont.Small,
		MEDIUM = UIFont.Medium,
		LARGE = UIFont.Large,
	},
	COLORS = {
		BACKGROUND = {
			NORMAL = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
			FIELD = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 },
			PANEL = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 },
		},
		BORDER = {
			NORMAL = { r = 0.4, g = 0.4, b = 0.4, a = 1 },
			DARK = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
			LIGHT = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
		},
		BUTTON = {
			NORMAL = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
			HOVER = { r = 0.3, g = 0.3, b = 0.3, a = 0.8 },
			SELECTED = { r = 0.3, g = 0.5, b = 0.7, a = 0.8 },
			CLOSE = { r = 0.8, g = 0.2, b = 0.2, a = 0.8 },
			CLOSE_HOVER = { r = 0.9, g = 0.3, b = 0.3, a = 0.8 },
		},
		TEXT = {
			NORMAL = { r = 1, g = 1, b = 1, a = 1 },
			ERROR = { r = 1, g = 0.2, b = 0.2, a = 1 },
		},
		LIST = {
			ALT = { r = 0.15, g = 0.15, b = 0.15, a = 0.75 },
			SELECTED = { r = 0.3, g = 0.5, b = 0.7, a = 0.9 },
		},
		RADIO = {
			NORMAL = { r = 0.4, g = 0.4, b = 0.4, a = 1 },
			SELECTED = { r = 0.2, g = 0.8, b = 0.2, a = 1 },
		},
	},
}

local function copyColor(color)
	if not color then
		return { r = 1, g = 1, b = 1, a = 1 }
	end
	return {
		r = color.r or 1,
		g = color.g or 1,
		b = color.b or 1,
		a = color.a or 1,
	}
end

RoleDisplaySystem.UI_Manager = ISCollapsableWindow:derive("RoleManager_UI")
RoleDisplaySystem.UI_Manager.instance = nil

function RoleDisplaySystem.UI_Manager:new(x, y, width, height, playerNum)
	local o = ISCollapsableWindow:new(
		x,
		y,
		width or CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH,
		height or CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT
	)
	setmetatable(o, self)
	self.__index = self

	o.player = getSpecificPlayer(playerNum)
	o.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	o.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	o.username = o.player:getUsername()
	o.selectedRole = nil
	o.selectedPlayer = nil

	o.minimumWidth = CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH
	o.minimumHeight = CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT

	o:setTitle(getText("IGUI_RM_Title"))
	o:setResizable(true)

	return o
end

function RoleDisplaySystem.UI_Manager:createChildren()
	ISCollapsableWindow.createChildren(self)

	local currentY = self:titleBarHeight() + CONST.LAYOUT.PADDING
	local rh = self:resizeWidgetHeight()
	local contentHeight = self.height - currentY - CONST.LAYOUT.PADDING - rh

	self.contentPanel =
		ISPanel:new(CONST.LAYOUT.PADDING, currentY, self.width - (CONST.LAYOUT.PADDING * 2), contentHeight)
	self.contentPanel:initialise()
	self.contentPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	self.contentPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.contentPanel.anchorRight = true
	self.contentPanel.anchorBottom = true
	self:addChild(self.contentPanel)

	self:createMainLayout()
	self:updateRoleList()
	self:updateButtonStates()
end

function RoleDisplaySystem.UI_Manager:onResize()
	ISCollapsableWindow.onResize(self)

	if not self.contentPanel then
		return
	end

	local currentY = self.contentPanel:getY()
	local rh = self:resizeWidgetHeight()

	self.contentPanel:setWidth(self.width - (CONST.LAYOUT.PADDING * 2))
	self.contentPanel:setHeight(self.height - currentY - CONST.LAYOUT.PADDING - rh)

	if self.leftPanel and self.rightPanel then
		local leftPanelWidth = math.floor(self.contentPanel:getWidth() * 0.5)
		local rightPanelWidth = self.contentPanel:getWidth() - leftPanelWidth - CONST.LAYOUT.PADDING

		self.leftPanel:setWidth(leftPanelWidth)
		self.leftPanel:setHeight(self.contentPanel:getHeight())

		self.rightPanel:setX(leftPanelWidth + CONST.LAYOUT.PADDING)
		self.rightPanel:setWidth(rightPanelWidth)
		self.rightPanel:setHeight(self.contentPanel:getHeight())

		if self.roleList then
			local roleListHeight = math.floor(
				(
					self.leftPanel:getHeight()
					- CONST.LAYOUT.PADDING * 6
					- CONST.LAYOUT.BUTTON.HEIGHT * 2
					- CONST.LAYOUT.ELEMENT_HEIGHT * 2
				) / 2
			)
			self.roleList:setWidth(leftPanelWidth - CONST.LAYOUT.PADDING * 2)
			self.roleList:setHeight(roleListHeight)

			local buttonY = self.roleList:getBottom() + CONST.LAYOUT.PADDING
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

			local playerListY = self.playersInRoleLabel:getBottom() + CONST.LAYOUT.PADDING
			local playerListHeight = self.leftPanel:getHeight()
				- playerListY
				- CONST.LAYOUT.PADDING * 2
				- CONST.LAYOUT.BUTTON.HEIGHT

			self.playerList:setY(playerListY)
			self.playerList:setWidth(leftPanelWidth - CONST.LAYOUT.PADDING * 2)
			self.playerList:setHeight(playerListHeight)

			local buttonY = self.playerList:getBottom() + CONST.LAYOUT.PADDING
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
	end
end

function RoleDisplaySystem.UI_Manager:createMainLayout()
	local leftPanelWidth = math.floor(self.contentPanel:getWidth() * 0.5)
	local rightPanelWidth = self.contentPanel:getWidth() - leftPanelWidth - CONST.LAYOUT.PADDING

	self.leftPanel = ISPanel:new(0, 0, leftPanelWidth, self.contentPanel:getHeight())
	self.leftPanel:initialise()
	self.leftPanel.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.leftPanel.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	self.leftPanel.anchorRight = false
	self.leftPanel.anchorBottom = true
	self.contentPanel:addChild(self.leftPanel)

	self.rightPanel =
		ISPanel:new(leftPanelWidth + CONST.LAYOUT.PADDING, 0, rightPanelWidth, self.contentPanel:getHeight())
	self.rightPanel:initialise()
	self.rightPanel.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.rightPanel.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	self.rightPanel.anchorLeft = false
	self.rightPanel.anchorRight = true
	self.rightPanel.anchorBottom = true
	self.contentPanel:addChild(self.rightPanel)

	self:createRoleSection()
	self:createPlayerSection()
	self:createRoleOptionsSection()
end

function RoleDisplaySystem.UI_Manager:createRoleSection()
	self.rolesLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_Roles"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self.leftPanel:addChild(self.rolesLabel)

	local listY = self.rolesLabel:getBottom() + CONST.LAYOUT.PADDING
	local listHeight = math.floor(
		(
			self.leftPanel:getHeight()
			- CONST.LAYOUT.PADDING * 6
			- CONST.LAYOUT.BUTTON.HEIGHT * 2
			- CONST.LAYOUT.ELEMENT_HEIGHT * 2
		) / 2
	)

	self.roleList = ISScrollingListBox:new(
		CONST.LAYOUT.PADDING,
		listY,
		self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 2,
		listHeight
	)
	self.roleList:initialise()
	self.roleList:instantiate()
	self.roleList.itemheight = CONST.LAYOUT.ELEMENT_HEIGHT
	self.roleList.selected = 0
	self.roleList.joypadParent = self
	self.roleList.font = CONST.FONT.SMALL
	self.roleList.drawBorder = true
	self.roleList.borderColor = copyColor(CONST.COLORS.BORDER.DARK)
	self.roleList.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	self.roleList.doDrawItem = self.drawRoleListItem
	self.roleList.onMouseDown = self.onRoleListMouseDown
	self.roleList.target = self
	self.roleList.anchorRight = true
	self.roleList.anchorBottom = false
	self.leftPanel:addChild(self.roleList)

	local buttonY = self.roleList:getBottom() + CONST.LAYOUT.PADDING
	local buttonWidth = (self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 3) / 2

	self.addRoleButton = ISButton:new(
		CONST.LAYOUT.PADDING,
		buttonY,
		buttonWidth,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_AddRole"),
		self,
		self.onAddRole
	)
	self.addRoleButton:initialise()
	self.addRoleButton:instantiate()
	self.addRoleButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.addRoleButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.addRoleButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.addRoleButton.anchorTop = false
	self.addRoleButton.anchorBottom = false
	self.addRoleButton.anchorRight = false
	self.leftPanel:addChild(self.addRoleButton)

	self.removeRoleButton = ISButton:new(
		self.addRoleButton:getRight() + CONST.LAYOUT.PADDING,
		buttonY,
		buttonWidth,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_RemoveRole"),
		self,
		self.onRemoveRole
	)
	self.removeRoleButton:initialise()
	self.removeRoleButton:instantiate()
	self.removeRoleButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.removeRoleButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.CLOSE)
	self.removeRoleButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.CLOSE_HOVER)
	self.removeRoleButton:setEnable(false)
	self.removeRoleButton.anchorLeft = false
	self.removeRoleButton.anchorTop = false
	self.removeRoleButton.anchorRight = true
	self.removeRoleButton.anchorBottom = false
	self.leftPanel:addChild(self.removeRoleButton)
end

function RoleDisplaySystem.UI_Manager:createPlayerSection()
	local playerSectionY = self.removeRoleButton:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.playersInRoleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		playerSectionY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_PlayersInRole"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self.leftPanel:addChild(self.playersInRoleLabel)

	local playerListY = self.playersInRoleLabel:getBottom() + CONST.LAYOUT.PADDING
	local playerListHeight = self.leftPanel:getHeight()
		- playerListY
		- CONST.LAYOUT.PADDING * 2
		- CONST.LAYOUT.BUTTON.HEIGHT

	self.playerList = ISScrollingListBox:new(
		CONST.LAYOUT.PADDING,
		playerListY,
		self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 2,
		playerListHeight
	)
	self.playerList:initialise()
	self.playerList:instantiate()
	self.playerList.itemheight = CONST.LAYOUT.ELEMENT_HEIGHT
	self.playerList.selected = 0
	self.playerList.joypadParent = self
	self.playerList.font = CONST.FONT.SMALL
	self.playerList.drawBorder = true
	self.playerList.borderColor = copyColor(CONST.COLORS.BORDER.DARK)
	self.playerList.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	self.playerList.doDrawItem = self.drawPlayerListItem
	self.playerList.onMouseDown = self.onPlayerListMouseDown
	self.playerList.target = self
	self.playerList.anchorRight = true
	self.playerList.anchorBottom = true
	self.leftPanel:addChild(self.playerList)

	local buttonY = self.playerList:getBottom() + CONST.LAYOUT.PADDING
	local buttonWidth = (self.leftPanel:getWidth() - CONST.LAYOUT.PADDING * 3) / 2

	self.addPlayerButton = ISButton:new(
		CONST.LAYOUT.PADDING,
		buttonY,
		buttonWidth,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_AddPlayer"),
		self,
		self.onAddPlayer
	)
	self.addPlayerButton:initialise()
	self.addPlayerButton:instantiate()
	self.addPlayerButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.addPlayerButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.addPlayerButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.addPlayerButton:setEnable(false)
	self.addPlayerButton.anchorLeft = true
	self.addPlayerButton.anchorTop = false
	self.addPlayerButton.anchorRight = false
	self.addPlayerButton.anchorBottom = true
	self.leftPanel:addChild(self.addPlayerButton)

	self.removePlayerButton = ISButton:new(
		self.addPlayerButton:getRight() + CONST.LAYOUT.PADDING,
		buttonY,
		buttonWidth,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_RemovePlayer"),
		self,
		self.onRemovePlayer
	)
	self.removePlayerButton:initialise()
	self.removePlayerButton:instantiate()
	self.removePlayerButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.removePlayerButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.CLOSE)
	self.removePlayerButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.CLOSE_HOVER)
	self.removePlayerButton:setEnable(false)
	self.removePlayerButton.anchorLeft = false
	self.removePlayerButton.anchorTop = false
	self.removePlayerButton.anchorRight = true
	self.removePlayerButton.anchorBottom = true
	self.leftPanel:addChild(self.removePlayerButton)
end

function RoleDisplaySystem.UI_Manager:createRoleOptionsSection()
	self.roleOptionsLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_RoleOptions"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self.rightPanel:addChild(self.roleOptionsLabel)

	local currentY = self.roleOptionsLabel:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.roleNameLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_RoleName") .. ":",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.rightPanel:addChild(self.roleNameLabel)

	self.roleNameEntry = ISTextEntryBox:new(
		"",
		CONST.LAYOUT.PADDING,
		currentY + CONST.LAYOUT.ELEMENT_HEIGHT + CONST.LAYOUT.SPACING.ITEM,
		CONST.LAYOUT.ENTRY.WIDTH,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.roleNameEntry:initialise()
	self.roleNameEntry:instantiate()
	self.roleNameEntry.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.roleNameEntry.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
	self.roleNameEntry.onTextChange = function()
		self:onRoleNameChanged()
	end
	self.rightPanel:addChild(self.roleNameEntry)

	currentY = self.roleNameEntry:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.roleColorLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_RoleColor") .. ":",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.rightPanel:addChild(self.roleColorLabel)

	self.roleColorButton = ISButton:new(
		CONST.LAYOUT.PADDING,
		currentY + CONST.LAYOUT.ELEMENT_HEIGHT + CONST.LAYOUT.SPACING.ITEM,
		100,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_ChooseColor"),
		self,
		self.onChooseColor
	)
	self.roleColorButton:initialise()
	self.roleColorButton:instantiate()
	self.roleColorButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.roleColorButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.roleColorButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.rightPanel:addChild(self.roleColorButton)

	self.roleColorPreview = ISPanel:new(
		self.roleColorButton:getRight() + CONST.LAYOUT.SPACING.ITEM,
		currentY + CONST.LAYOUT.ELEMENT_HEIGHT + CONST.LAYOUT.SPACING.ITEM,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.roleColorPreview:initialise()
	self.roleColorPreview.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.roleColorPreview.backgroundColor = copyColor({ r = 1, g = 1, b = 1, a = 1 })
	self.rightPanel:addChild(self.roleColorPreview)

	self.currentRoleColor = { r = 1, g = 1, b = 1, a = 1 }

	currentY = self.roleColorButton:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.bracketStyleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_BracketStyle") .. ":",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.rightPanel:addChild(self.bracketStyleLabel)

	currentY = self.bracketStyleLabel:getBottom() + CONST.LAYOUT.SPACING.ITEM

	self.bracketRadios = ISRadioButtons:new(
		CONST.LAYOUT.PADDING,
		currentY,
		self.rightPanel:getWidth() - CONST.LAYOUT.PADDING * 2,
		150,
		self,
		self.onBracketStyleSelected
	)
	self.bracketRadios:initialise()
	self.bracketRadios:instantiate()

	self:updateBracketRadioOptions("Role")

	self.bracketRadios:setSelected(1)
	self.rightPanel:addChild(self.bracketRadios)

	currentY = self.bracketRadios:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.priorityLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		currentY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_Priority") .. ":",
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self.rightPanel:addChild(self.priorityLabel)

	self.priorityEntry = ISTextEntryBox:new(
		"1",
		CONST.LAYOUT.PADDING,
		currentY + CONST.LAYOUT.ELEMENT_HEIGHT + CONST.LAYOUT.SPACING.ITEM,
		60,
		CONST.LAYOUT.ELEMENT_HEIGHT
	)
	self.priorityEntry:initialise()
	self.priorityEntry:instantiate()
	self.priorityEntry.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.priorityEntry.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
	self.priorityEntry.onTextChange = function()
		self:onRolePriorityChanged()
	end
	self.rightPanel:addChild(self.priorityEntry)

	currentY = self.priorityEntry:getBottom() + CONST.LAYOUT.SPACING.SECTION

	self.saveRoleButton = ISButton:new(
		CONST.LAYOUT.PADDING,
		currentY,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_SaveRole"),
		self,
		self.onSaveRole
	)
	self.saveRoleButton:initialise()
	self.saveRoleButton:instantiate()
	self.saveRoleButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.saveRoleButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.saveRoleButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.saveRoleButton:setEnable(false)
	self.rightPanel:addChild(self.saveRoleButton)

	self:hideRoleOptions(true)
end

function RoleDisplaySystem.UI_Manager:drawRoleListItem(y, item, alt)
	local role = item.item
	if not role then
		return y
	end

	local isSelected = self.selected == item.index
	local bgColor = isSelected and copyColor(CONST.COLORS.LIST.SELECTED)
		or (alt and copyColor(CONST.COLORS.LIST.ALT) or self.backgroundColor)

	self:drawRect(0, y, self:getWidth(), self.itemheight - 1, bgColor.a, bgColor.r, bgColor.g, bgColor.b)

	local displayText = RoleDisplaySystem.Shared.FormatRoleTag(role)
	local roleColor = RoleDisplaySystem.Shared.GetRoleColor(role)

	local textHeight = getTextManager():MeasureStringY(self.font, displayText)
	self:drawText(
		displayText,
		CONST.LAYOUT.PADDING,
		y + self.itemheight / 2 - textHeight / 2,
		roleColor.r,
		roleColor.g,
		roleColor.b,
		roleColor.a,
		self.font
	)

	local playerCount = role.players and #role.players or 0
	local countText = "(" .. playerCount .. ")"
	local textWidth = getTextManager():MeasureStringX(self.font, countText)
	self:drawText(
		countText,
		self:getWidth() - textWidth - CONST.LAYOUT.PADDING,
		y + self.itemheight / 2 - textHeight / 2,
		0.7,
		0.7,
		0.7,
		1,
		self.font
	)

	return y + self.itemheight
end

function RoleDisplaySystem.UI_Manager:drawPlayerListItem(y, item, alt)
	local username = item.text

	local isSelected = self.selected == item.index
	local bgColor = isSelected and copyColor(CONST.COLORS.LIST.SELECTED)
		or (alt and copyColor(CONST.COLORS.LIST.ALT) or self.backgroundColor)

	self:drawRect(0, y, self:getWidth(), self.itemheight - 1, bgColor.a, bgColor.r, bgColor.g, bgColor.b)

	self:drawText(
		username,
		CONST.LAYOUT.PADDING,
		y + (self.itemheight - getTextManager():MeasureStringY(self.font, username)) / 2,
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		self.font
	)

	return y + self.itemheight
end

function RoleDisplaySystem.UI_Manager:updateRoleList()
	self.roleList:clear()

	if not RoleDisplaySystem.Roles then
		return
	end

	for roleId, role in pairs(RoleDisplaySystem.Roles) do
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

	if not self.selectedRole or not self.selectedRole.players then
		return
	end

	for _, username in ipairs(self.selectedRole.players) do
		self.playerList:addItem(username, username)
	end
end

function RoleDisplaySystem.UI_Manager:onRoleListMouseDown(x, y)
	if self.items and #self.items == 0 then
		return
	end
	local row = self:rowAt(x, y)

	if row > #self.items then
		row = #self.items
	end
	if row < 1 then
		row = 1
	end

	local item = self.items[row].item

	getSoundManager():playUISound("UISelectListItem")
	self.selected = row
	if self.onmousedown then
		self.onmousedown(self.target, item)
	end

	self.parent.parent.parent:onRoleSelected()
end

function RoleDisplaySystem.UI_Manager:onPlayerListMouseDown(x, y)
	ISScrollingListBox.onMouseDown(self, x, y)

	local selected = self.selected
	if selected > 0 and self.items[selected] then
		self.parent.parent.parent.selectedPlayer = self.items[selected].text
		if self.parent.parent.parent.removePlayerButton then
			self.parent.parent.parent.removePlayerButton:setEnable(true)
		end
	else
		self.parent.parent.parent.selectedPlayer = nil
		if self.parent.parent.parent.removePlayerButton then
			self.parent.parent.parent.removePlayerButton:setEnable(false)
		end
	end
end

function RoleDisplaySystem.UI_Manager:onRoleSelected()
	local selected = self.roleList.selected

	if selected <= 0 or not self.roleList.items[selected] then
		self.selectedRole = nil
		self.selectedPlayer = nil
	else
		self.selectedRole = self.roleList.items[selected].item
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
		self.currentRoleColor = copyColor(self.selectedRole.color)
	else
		self.currentRoleColor = { r = 1, g = 1, b = 1, a = 1 }
	end

	self.roleColorPreview.backgroundColor = copyColor(self.currentRoleColor)

	local selectedStyle = self.selectedRole.bracketStyle or "square"
	local bracketStyleMap = {
		square = 1,
		round = 2,
		curly = 3,
		angle = 4,
		colon = 5,
		none = 6,
	}

	self:updateBracketRadioOptions(self.selectedRole.name or "Role")

	local selectedIndex = bracketStyleMap[selectedStyle] or 1
	self.bracketRadios:setSelected(selectedIndex)
end

function RoleDisplaySystem.UI_Manager:hideRoleOptions(hide)
	local elements = {
		self.roleNameLabel,
		self.roleNameEntry,
		self.roleColorLabel,
		self.roleColorButton,
		self.roleColorPreview,
		self.bracketStyleLabel,
		self.bracketRadios,
		self.priorityLabel,
		self.priorityEntry,
		self.saveRoleButton,
	}

	for i = 1, #elements do
		if elements[i] then
			elements[i]:setVisible(not hide)
		end
	end
end

function RoleDisplaySystem.UI_Manager:updateButtonStates()
	local hasRoleSelection = self.selectedRole ~= nil
	local hasPlayerSelection = self.selectedPlayer ~= nil

	self.removeRoleButton:setEnable(hasRoleSelection)
	self.addPlayerButton:setEnable(hasRoleSelection)
	self.removePlayerButton:setEnable(hasPlayerSelection)
	self.saveRoleButton:setEnable(hasRoleSelection)
end

function RoleDisplaySystem.UI_Manager:onAddRole()
	local modal =
		ISTextBox:new(0, 0, 280, 180, getText("IGUI_RM_EnterRoleName"), "", nil, self.onCreateRoleConfirm, nil, self)
	modal:initialise()
	modal:addToUIManager()
	modal:setX((getCore():getScreenWidth() / 2) - (modal:getWidth() / 2))
	modal:setY((getCore():getScreenHeight() / 2) - (modal:getHeight() / 2))
end

function RoleDisplaySystem.UI_Manager:onCreateRoleConfirm(button)
	local name = button.parent.entry:getText() and button.parent.entry:getText() ~= "" and button.parent.entry:getText()
	if button.internal ~= "OK" or not name or name:trim() == "" then
		return
	end

	local newRole = {
		id = RoleDisplaySystem.Shared.GenerateRoleId(),
		name = name:trim(),
		color = { r = 1, g = 1, b = 1, a = 1 },
		bracketStyle = "square",
		priority = 1,
		players = {},
	}

	RoleDisplaySystem.Client.AddRole(newRole)
end

function RoleDisplaySystem.UI_Manager:onRemoveRole()
	if not self.selectedRole then
		return
	end

	local modal = ISModalDialog:new(
		0,
		0,
		350,
		150,
		getText("IGUI_RM_ConfirmDeleteRole", self.selectedRole.name),
		true,
		self,
		self.onDeleteRoleConfirm
	)
	modal:initialise()
	modal:addToUIManager()
	modal:setX((getCore():getScreenWidth() / 2) - (modal:getWidth() / 2))
	modal:setY((getCore():getScreenHeight() / 2) - (modal:getHeight() / 2))
end

function RoleDisplaySystem.UI_Manager:onDeleteRoleConfirm(button)
	if button.internal ~= "YES" or not self.selectedRole then
		return
	end

	RoleDisplaySystem.Client.RemoveRole(self.selectedRole.id)
	self.selectedRole = nil
	self:updateRoleOptions()
end

function RoleDisplaySystem.UI_Manager:onAddPlayer()
	if not self.selectedRole then
		return
	end

	self.playerSelectionModal = RoleDisplaySystem.UI_Manager.PlayerSelectionModal:new(
		self,
		(getCore():getScreenWidth() / 2) - (CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.WIDTH / 2),
		(getCore():getScreenHeight() / 2) - (CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.HEIGHT / 2),
		CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.WIDTH,
		CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.HEIGHT
	)
	self.playerSelectionModal:initialise()
	self.playerSelectionModal:addToUIManager()
	self.playerSelectionModal:bringToTop()
end

function RoleDisplaySystem.UI_Manager:onRemovePlayer()
	if not self.selectedRole or not self.selectedPlayer then
		return
	end

	RoleDisplaySystem.Client.RemovePlayerFromRole(self.selectedRole.id, self.selectedPlayer)
	self.selectedPlayer = nil
	self.removePlayerButton:setEnable(false)
end

function RoleDisplaySystem.UI_Manager:onSaveRole()
	if not self.selectedRole then
		return
	end

	local roleName = self.roleNameEntry:getText():trim()
	if roleName == "" then
		return
	end

	self.selectedRole.name = roleName
	self.selectedRole.priority = tonumber(self.priorityEntry:getText()) or 1

	local selectedIndex = self.bracketRadios.selected
	if selectedIndex > 0 then
		self.selectedRole.bracketStyle = self.bracketRadios:getOptionData(selectedIndex)
	end

	RoleDisplaySystem.Client.UpdateRole(self.selectedRole)
end

function RoleDisplaySystem.UI_Manager:updateBracketRadioOptions(roleName)
	if not self.bracketRadios then
		return
	end

	self.bracketRadios:clear()

	local name = roleName or "Role"
	self.bracketRadios:addOption("[" .. name .. "]", "square")
	self.bracketRadios:addOption("(" .. name .. ")", "round")
	self.bracketRadios:addOption("{" .. name .. "}", "curly")
	self.bracketRadios:addOption("<" .. name .. ">", "angle")
	self.bracketRadios:addOption(name .. ":", "colon")
	self.bracketRadios:addOption(name, "none")
end

function RoleDisplaySystem.UI_Manager:onChooseColor()
	local colorPicker = ISColorPicker:new(0, 0)
	colorPicker:initialise()
	colorPicker:instantiate()

	local currentColor = Color.new(self.currentRoleColor.r, self.currentRoleColor.g, self.currentRoleColor.b, 1.0)
	colorPicker:setInitialColor(currentColor)

	colorPicker:setPickedFunc(self.onColorPicked, self)

	local screenWidth = getCore():getScreenWidth()
	local screenHeight = getCore():getScreenHeight()
	colorPicker:setX(screenWidth / 2 - colorPicker:getWidth() / 2)
	colorPicker:setY(screenHeight / 2 - colorPicker:getHeight() / 2)

	colorPicker:addToUIManager()
	colorPicker:bringToTop()
end

function RoleDisplaySystem.UI_Manager:onColorPicked(color, mouseUp, target)
	if not color then
		return
	end

	target.currentRoleColor = {
		r = color.r or 1,
		g = color.g or 1,
		b = color.b or 1,
		a = 1,
	}
	target.roleColorPreview.backgroundColor = copyColor(target.currentRoleColor)

	if target.selectedRole then
		target.selectedRole.color = copyColor(target.currentRoleColor)
	end
end

function RoleDisplaySystem.UI_Manager:onBracketStyleSelected(radioButtons, selectedIndex)
	if not self.selectedRole then
		return
	end

	local selectedOption = radioButtons:getOptionData(selectedIndex)
	self.selectedRole.bracketStyle = selectedOption
end

function RoleDisplaySystem.UI_Manager:onRoleNameChanged() end

function RoleDisplaySystem.UI_Manager:onRolePriorityChanged() end

function RoleDisplaySystem.UI_Manager:close()
	if self.playerSelectionModal then
		self.playerSelectionModal:close()
		self.playerSelectionModal = nil
	end

	ISCollapsableWindow.close(self)
	self:removeFromUIManager()
	RoleDisplaySystem.UI_Manager.instance = nil
end

function RoleDisplaySystem.UI_Manager.toggle(playerNum)
	local player = getSpecificPlayer(playerNum)
	if not RoleDisplaySystem.Shared.HasPermission(player) then
		return
	end

	if RoleDisplaySystem.UI_Manager.instance then
		RoleDisplaySystem.UI_Manager.instance:close()
		return
	end

	local x = (getCore():getScreenWidth() / 2) - (CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH / 2)
	local y = (getCore():getScreenHeight() / 2) - (CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT / 2)

	local panel = RoleDisplaySystem.UI_Manager:new(
		x,
		y,
		CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.WIDTH,
		CONST.LAYOUT.WINDOW_SIZE.MAIN_PANEL.HEIGHT,
		playerNum
	)
	panel:initialise()
	panel:addToUIManager()
	RoleDisplaySystem.UI_Manager.instance = panel
end

RoleDisplaySystem.UI_Manager.PlayerSelectionModal = ISPanelJoypad:derive("RoleManager_PlayerSelectionModal")

RoleDisplaySystem.UI_Manager.PlayerSelectionModal.scoreboard = nil

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:new(parent, x, y, width, height)
	local o = ISPanelJoypad:new(
		x,
		y,
		width or CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.WIDTH,
		height or CONST.LAYOUT.WINDOW_SIZE.PLAYER_SELECTION_MODAL.HEIGHT
	)
	setmetatable(o, self)
	self.__index = self

	o.parent = parent
	o.player = parent.player
	o.selectedUsernames = {}
	o.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	o.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	o.moveWithMouse = true
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true

	o.currentTab = "online" -- "online" or "manual"
	o.contentStartY = 0

	return o
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:initialise()
	ISPanelJoypad.initialise(self)
	if isClient() then
		scoreboardUpdate()
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createChildren()
	self.titleLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_AddPlayers"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.MEDIUM,
		true
	)
	self:addChild(self.titleLabel)

	local currentY = self.titleLabel:getBottom() + CONST.LAYOUT.PADDING

	self:createTabs(currentY)
	self.contentStartY = self.onlineTab:getBottom() + CONST.LAYOUT.PADDING

	self:createTabContent()

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
	self.cancelButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.cancelButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.cancelButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self:addChild(self.cancelButton)

	self.addButton = ISButton:new(
		self.cancelButton:getX() - CONST.LAYOUT.BUTTON.WIDTH - CONST.LAYOUT.PADDING,
		buttonY,
		CONST.LAYOUT.BUTTON.WIDTH,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_Add"),
		self,
		self.onAdd
	)
	self.addButton:initialise()
	self.addButton:instantiate()
	self.addButton.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.addButton.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.addButton.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self.addButton:setEnable(false)
	self:addChild(self.addButton)
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createTabs(y)
	local tabWidth = 120

	self.onlineTab = ISButton:new(
		CONST.LAYOUT.PADDING,
		y,
		tabWidth,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_OnlinePlayers"),
		self,
		self.onTabSelected
	)
	self.onlineTab:initialise()
	self.onlineTab:instantiate()
	self.onlineTab.internal = "online"
	self.onlineTab.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.onlineTab.backgroundColor = copyColor(CONST.COLORS.BUTTON.SELECTED)
	self.onlineTab.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self:addChild(self.onlineTab)

	self.manualTab = ISButton:new(
		self.onlineTab:getRight() + CONST.LAYOUT.PADDING,
		y,
		tabWidth,
		CONST.LAYOUT.BUTTON.HEIGHT,
		getText("IGUI_RM_ManualInput"),
		self,
		self.onTabSelected
	)
	self.manualTab:initialise()
	self.manualTab:instantiate()
	self.manualTab.internal = "manual"
	self.manualTab.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.manualTab.backgroundColor = copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.manualTab.backgroundColorMouseOver = copyColor(CONST.COLORS.BUTTON.HOVER)
	self:addChild(self.manualTab)
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createTabContent()
	if self.descLabel then
		self:removeChild(self.descLabel)
	end
	if self.playerList then
		self:removeChild(self.playerList)
	end
	if self.instructLabel then
		self:removeChild(self.instructLabel)
	end
	if self.usernameEntry then
		self:removeChild(self.usernameEntry)
	end
	if self.previewLabel then
		self:removeChild(self.previewLabel)
	end
	if self.previewList then
		self:removeChild(self.previewList)
	end

	if self.currentTab == "online" then
		self:createOnlineContent()
	else
		self:createManualContent()
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createOnlineContent()
	self.descLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.contentStartY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_SelectPlayersDesc"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.descLabel)

	local listY = self.descLabel:getBottom() + CONST.LAYOUT.PADDING
	local listHeight = self.height - listY - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING * 3

	self.playerList =
		ISScrollingListBox:new(CONST.LAYOUT.PADDING, listY, self.width - CONST.LAYOUT.PADDING * 2, listHeight)
	self.playerList:initialise()
	self.playerList:instantiate()
	self.playerList.itemheight = CONST.LAYOUT.ELEMENT_HEIGHT
	self.playerList.font = CONST.FONT.SMALL
	self.playerList.drawBorder = true
	self.playerList.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.playerList.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	self.playerList.doDrawItem = self.drawPlayerListItem
	self.playerList.onMouseDown = self.onPlayerListMouseDown
	self.playerList.target = self
	self:addChild(self.playerList)

	self:populatePlayerList()
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:createManualContent()
	self.descLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.contentStartY,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_ManualInputDesc"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.descLabel)

	self.instructLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.descLabel:getBottom() + CONST.LAYOUT.PADDING / 2,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_ManualInputInstruct"),
		0.7,
		0.7,
		0.7,
		1,
		CONST.FONT.SMALL,
		true
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
	self.usernameEntry.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.usernameEntry.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.FIELD)
	self.usernameEntry:setMultipleLine(true)
	self.usernameEntry:setMaxLines(10)
	self.usernameEntry.onTextChange = function()
		self:updateAddButton()
	end
	self:addChild(self.usernameEntry)

	self.previewLabel = ISLabel:new(
		CONST.LAYOUT.PADDING,
		self.usernameEntry:getBottom() + CONST.LAYOUT.PADDING,
		CONST.LAYOUT.ELEMENT_HEIGHT,
		getText("IGUI_RM_PreviewUsernames"),
		CONST.COLORS.TEXT.NORMAL.r,
		CONST.COLORS.TEXT.NORMAL.g,
		CONST.COLORS.TEXT.NORMAL.b,
		CONST.COLORS.TEXT.NORMAL.a,
		CONST.FONT.SMALL,
		true
	)
	self:addChild(self.previewLabel)

	local previewListY = self.previewLabel:getBottom() + CONST.LAYOUT.PADDING / 2
	local previewListHeight = self.height - previewListY - CONST.LAYOUT.BUTTON.HEIGHT - CONST.LAYOUT.PADDING * 3

	self.previewList = ISScrollingListBox:new(
		CONST.LAYOUT.PADDING,
		previewListY,
		self.width - CONST.LAYOUT.PADDING * 2,
		previewListHeight
	)
	self.previewList:initialise()
	self.previewList:instantiate()
	self.previewList.itemheight = CONST.LAYOUT.ELEMENT_HEIGHT
	self.previewList.font = CONST.FONT.SMALL
	self.previewList.drawBorder = true
	self.previewList.borderColor = copyColor(CONST.COLORS.BORDER.NORMAL)
	self.previewList.backgroundColor = copyColor(CONST.COLORS.BACKGROUND.NORMAL)
	self:addChild(self.previewList)
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:populatePlayerList()
	self.playerList:clear()

	local players = {}

	if not isClient() and not isServer() then
		local username = self.player:getUsername()
		local displayName = self.player:getDisplayName()

		local alreadyInRole = false
		if self.parent.selectedRole and self.parent.selectedRole.players then
			for _, existingName in ipairs(self.parent.selectedRole.players) do
				if existingName == username then
					alreadyInRole = true
					break
				end
			end
		end

		if not alreadyInRole then
			table.insert(players, {
				username = username,
				displayName = displayName,
				selected = false,
			})
		end
	elseif isClient() then
		local scoreboard = RoleDisplaySystem.UI_Manager.PlayerSelectionModal.scoreboard
		if not scoreboard then
			return
		end

		for i = 0, scoreboard.usernames:size() - 1 do
			local username = scoreboard.usernames:get(i)
			local displayName = scoreboard.displayNames:get(i)

			local alreadyInRole = false
			if self.parent.selectedRole and self.parent.selectedRole.players then
				for _, existingName in ipairs(self.parent.selectedRole.players) do
					if existingName == username then
						alreadyInRole = true
						break
					end
				end
			end

			if not alreadyInRole then
				table.insert(players, {
					username = username,
					displayName = displayName,
					selected = false,
				})
			end
		end
	end

	table.sort(players, function(a, b)
		return (a.displayName or a.username):lower() < (b.displayName or b.username):lower()
	end)

	for _, playerData in ipairs(players) do
		local item = self.playerList:addItem(playerData.displayName or playerData.username, playerData)
		if playerData.username ~= playerData.displayName then
			item.tooltip = playerData.username
		end
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:drawPlayerListItem(y, item, alt)
	local playerData = item.item

	if alt then
		self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.15, 0.15, 0.15)
	end

	local checkboxSize = 16
	local checkboxX = 10
	local checkboxY = y + (self.itemheight - checkboxSize) / 2

	self:drawRectBorder(checkboxX, checkboxY, checkboxSize, checkboxSize, 1, 0.4, 0.4, 0.4)

	if playerData.selected then
		self:drawRect(checkboxX + 3, checkboxY + 3, checkboxSize - 6, checkboxSize - 6, 1, 0.2, 0.8, 0.2)
	end

	local displayText = playerData.displayName or playerData.username
	local textHeight = getTextManager():MeasureStringY(self.font, displayText)
	self:drawText(
		displayText,
		checkboxX + checkboxSize + 10,
		y + (self.itemheight - textHeight) / 2,
		1,
		1,
		1,
		1,
		self.font
	)

	return y + self.itemheight
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:onPlayerListMouseDown(x, y)
	local row = self:rowAt(x, y)

	if row > 0 and row <= #self.items then
		local item = self.items[row].item
		item.selected = not item.selected

		self.parent:updateSelectedUsernames()
		self.parent:updateAddButton()
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:updateSelectedUsernames()
	self.selectedUsernames = {}

	if self.currentTab == "online" then
		if self.playerList then
			for i = 1, #self.playerList.items do
				local item = self.playerList.items[i].item
				if item.selected then
					table.insert(self.selectedUsernames, item.username)
				end
			end
		end
	else
		if self.usernameEntry then
			local text = self.usernameEntry:getText()
			self.selectedUsernames = self:parseUsernames(text)

			if self.previewList then
				self.previewList:clear()
				for i = 1, #self.selectedUsernames do
					self.previewList:addItem(self.selectedUsernames[i], self.selectedUsernames[i])
				end
			end
		end
	end
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:parseUsernames(text)
	local usernames = {}

	if not text or text:trim() == "" then
		return usernames
	end

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
				table.insert(usernames, username)
			end
		end
	end

	return usernames
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:updateAddButton()
	self:updateSelectedUsernames()

	local hasSelection = #self.selectedUsernames > 0
	self.addButton:setEnable(hasSelection)
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:onTabSelected(button)
	if button.internal == self.currentTab then
		return
	end

	self.currentTab = button.internal

	self.onlineTab.backgroundColor = self.currentTab == "online" and copyColor(CONST.COLORS.BUTTON.SELECTED)
		or copyColor(CONST.COLORS.BUTTON.NORMAL)
	self.manualTab.backgroundColor = self.currentTab == "manual" and copyColor(CONST.COLORS.BUTTON.SELECTED)
		or copyColor(CONST.COLORS.BUTTON.NORMAL)

	self.selectedUsernames = {}

	self:createTabContent()

	if self.currentTab == "online" and isClient() then
		scoreboardUpdate()
	end

	self:updateAddButton()
end

function RoleDisplaySystem.UI_Manager.PlayerSelectionModal:onAdd()
	if not self.parent.selectedRole or #self.selectedUsernames == 0 then
		return
	end

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
		usernames = usernames,
		displayNames = displayNames,
		steamIDs = steamIDs,
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
