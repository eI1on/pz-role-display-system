local RoleDisplaySystem = require("RoleDisplaySystem/Shared")

local ISDebugMenu_setupButtons = ISDebugMenu.setupButtons
---@diagnostic disable-next-line: duplicate-set-field
function ISDebugMenu:setupButtons()
	self:addButtonInfo(getText("IGUI_RM_Title"), function()
		RoleDisplaySystem.UI_Manager.toggle(getPlayer():getPlayerNum())
	end, "MAIN")
	ISDebugMenu_setupButtons(self)
end

local ISAdminPanelUI_create = ISAdminPanelUI.create
---@diagnostic disable-next-line: duplicate-set-field
function ISAdminPanelUI:create()
	ISAdminPanelUI_create(self)
	local fontHeight = getTextManager():getFontHeight(UIFont.Small)
	local btnWid = 150
	local btnHgt = math.max(25, fontHeight + 3 * 2)
	local btnGapY = 5

	local lastButton = self.children[self.IDMax - 1]
	lastButton = lastButton.internal == "CANCEL" and self.children[self.IDMax - 2] or lastButton

	self.showRoleDisplaySystem = ISButton:new(
		lastButton.x,
		lastButton.y + btnHgt + btnGapY,
		btnWid,
		btnHgt,
		getText("IGUI_RM_Title"),
		self,
		function()
			RoleDisplaySystem.UI_Manager.toggle(getPlayer():getPlayerNum())
		end
	)
	self.showRoleDisplaySystem.internal = ""
	self.showRoleDisplaySystem:initialise()
	self.showRoleDisplaySystem:instantiate()
	self.showRoleDisplaySystem.borderColor = self.buttonBorderColor
	self:addChild(self.showRoleDisplaySystem)
end
