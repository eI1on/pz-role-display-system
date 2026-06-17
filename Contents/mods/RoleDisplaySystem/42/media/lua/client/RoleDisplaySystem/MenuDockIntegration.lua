local MenuDock = require("ElyonLib/UI/MenuDock/MenuDock")
local RoleDisplaySystem = require("RoleDisplaySystem/Shared")
require("RoleDisplaySystem/RoleManager_UI")

MenuDock.registerButton({
	id = "role_display_system",
	title = getText("IGUI_RM_Title"),
	icon = "media/ui/ui_icon_role_display_system.png",
	minimumAccessLevel = "Admin",
	allowSinglePlayer = true,
	onClick = function(playerNum, entry)
		RoleDisplaySystem.UI_Manager.toggle(playerNum)
	end,
})
