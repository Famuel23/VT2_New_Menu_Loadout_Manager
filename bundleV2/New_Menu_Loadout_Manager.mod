return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`New_Menu_Loadout_Manager` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("New_Menu_Loadout_Manager", {
			mod_script       = "scripts/mods/New_Menu_Loadout_Manager/New_Menu_Loadout_Manager",
			mod_data         = "scripts/mods/New_Menu_Loadout_Manager/New_Menu_Loadout_Manager_data",
			mod_localization = "scripts/mods/New_Menu_Loadout_Manager/New_Menu_Loadout_Manager_localization",
		})
	end,
	packages = {
		"resource_packages/New_Menu_Loadout_Manager/New_Menu_Loadout_Manager",
	},
}
