local mod = get_mod("New_Menu_Loadout_Manager")

--[[
	Author: famuel_nz

    Adds the functionality for saving and quickly changing between gear/talent loadouts on the new menu style. 
--]]

--#########################--
----------- DATA ------------
--#########################--

-- Workaround for deletion (in patch 1.5) of a function required by SimpleUI.
UIResolutionScale = UIResolutionScale or UIResolutionScale_pow2

-- Local variables
local NUM_LOADOUT_BUTTONS = 10
local InventorySettings = InventorySettings
local SPProfiles = SPProfiles
local is_hero_character_info_hooked = false

-- Mod variables
mod.simple_ui = nil 
mod.button_theme = nil
mod.cloud_file = nil
mod.saved_loadouts = nil
mod.hero_view_data = nil
mod.loadouts_window = nil
mod.is_loading = false
mod.equipment_queue = {}
mod.careerDecodes = {}

--#########################--
--------- FUNCTIONS ---------
--#########################--

-- Function to perform initial setup.
mod.on_all_mods_loaded = function()
    
	mod.simple_ui = get_mod("SimpleUI")

    if mod.simple_ui then

        -- Create font
        mod.simple_ui.fonts:create("loadoutmgr_font", "hell_shark", 20)

		-- Create Style for buttons
		local button_theme = table.clone(mod.simple_ui.themes.default.default)		
        button_theme.font = "loadoutmgr_font"

        button_theme.color = Colors.get_color_table_with_alpha("black", 255)
        button_theme.color_hover = Colors.get_color_table_with_alpha("white", 0)
        button_theme.color_clicked = button_theme.color

        button_theme.color_text = Colors.get_color_table_with_alpha("font_button_normal", 255)
        button_theme.color_text_hover = Colors.get_color_table_with_alpha("white", 255)
        button_theme.color_text_clicked = Colors.get_color_table_with_alpha("font_default", 255)

        button_theme.shadow = {layers = 4, border = 0, color = Colors.get_color_table_with_alpha("white", 35)}
        mod.button_theme = button_theme

    else
        mod:echo("New Menu Loadout Manager Error: Missing Dependency: 'Simple UI'")
    end

    -- Initialise decodes for hero career names
    mod.careerDecodes = {es_mercenary = "Mercenary", es_huntsman = "Huntsman", es_knight = "Foot Knight", es_questingknight = "Grail Knight",
                         dr_ranger = "Ranger Veteran", dr_ironbreaker = "Ironbreaker", dr_slayer = "Slayer", dr_engineer = "Outcast Engineer",
                         we_waywatcher = "Waystalker", we_maidenguard = "Handmaiden", we_shade = "Shade", we_thornsister = "Sister of the Thorn",
                         wh_captain = "Witch Hunter Captain", wh_bountyhunter = "Bounty Hunter", wh_zealot = "Zealot", wh_priest = "Warrior Priest",
                         bw_adept = "Battle Wizard", bw_scholar = "Pyromancer", bw_unchained = "Unchained", bw_necromancer = "Necromancer"}

    -- Create a local object to access the file in which saved loadouts are kept
    local CloudFile = mod:dofile("scripts/mods/New_Menu_Loadout_Manager/cloud_file") 
    mod.cloud_file = CloudFile:new(mod, mod:get_name() .. ".data")
    mod.cloud_file:load(function(result)
		mod.saved_loadouts = result.data or {}
	end)
end

-- Function to return the hero name, career name, decoded career name and career index of the selected loadout.
mod.get_hero_details = function(self)
    local profile = SPProfiles[FindProfileIndex(self.hero_view_data.hero_name)]
	local career_index = self.hero_view_data.career_index
	local career_name = profile.careers[career_index].name
	return self.hero_view_data.hero_name, career_name, career_decode, career_index
end

-- Function to return the size and position of the Loadout buttons window.
-- TODO: Figure out how to align and scale this correctly, to bottom left by the friends icon. 
mod.get_gui_dimensions = function(self)	
    local scale = (UISettings.ui_scale or 100) / 100
    local gui_size = {math.floor(511 * scale), math.floor(694 * scale)}
	local gui_x_position = math.floor((UIResolutionWidthFragments() - gui_size[1]) / 4 + 30)
    local gui_y_position = math.floor((UIResolutionHeightFragments() - gui_size[2]) / 2 - 3) -- + 62 * scale)

    -- Return GUI size, Position, Height of Buttons
    return gui_size, {gui_x_position, gui_y_position}, math.floor(47 * scale)
end

-- Function to close any currently open windows.
mod.destroy_windows = function(self)
    if self.loadouts_window then
    	self.loadouts_window:destroy()
        self.loadouts_window = nil
    end
end

-- Function which checks for right-click mouse events within the loadout buttons window, and sends them to the appropriate widget.
local function dispatch_right_click(window)
	if stingray.Mouse.pressed(stingray.Mouse.button_id("right")) then
		local simple_ui = mod.simple_ui
		local position = simple_ui.mouse:cursor()
		for _, widget in pairs(window.widgets) do
			if simple_ui:point_in_bounds(position, widget:extended_bounds()) and widget.on_right_click then
				widget:on_right_click()
				break
			end
		end
	end
end

-- Function to create the window which shows a numbered button for each loadout.
mod.create_loadouts_window = function(self)

    if not self.loadouts_window and self.simple_ui then
        
		local gui_size, gui_position, loadout_buttons_height = self:get_gui_dimensions()
        local window_size = {gui_size[1], loadout_buttons_height}
        local window_position = {gui_position[1], gui_position[2]}
        local window_name = "loadouts"
        self.loadouts_window = self.simple_ui:create_window(window_name, window_position, window_size)

		local _, career_name = self:get_hero_details()

        -- On Left Click, equip the loadout
        local on_button_left_click = function(event) 
            local button_number = tonumber(event.params)
            mod:equip_loadout(button_number, career_name)      
        end

        -- On Right Click, save the current loadout to this button
        local on_save_click = function(event) 
            local button_number = tonumber(event.params)           
            mod:save_loadout(button_number, career_name)
        end

		-- Set up buttons
        local ui_scale = (UISettings.ui_scale or 100) / 100
        local button_size = {math.floor(33 * ui_scale), math.floor(33 * ui_scale)}
        local spacing = math.floor(10 * ui_scale)
        local margin = (window_size[1] - (NUM_LOADOUT_BUTTONS * button_size[1]) - ((NUM_LOADOUT_BUTTONS - 1) * spacing)) / 2
        local y_offset = (loadout_buttons_height - button_size[2]) / 2

		-- Add a button for each loadout. Clicking will open the details window
        for button_column = 1, NUM_LOADOUT_BUTTONS do
            local x_offset = margin + (button_column - 1) * (button_size[1] + spacing) 
            local name = (window_name .. "_" .. button_column)
            local newButton = self.loadouts_window:create_button(name, {x_offset, y_offset}, button_size, nil, "", button_column)

            newButton.theme = self.button_theme
            newButton.on_click = on_button_left_click
            newButton.on_right_click = on_save_click
			newButton.text = tostring(button_column)
			newButton.tooltip = sprintf("Loadout %d", button_column)
        end
       
        self.loadouts_window.on_hover_enter = function(window)
			window:focus()
		end
        
        self.loadouts_window.after_update = dispatch_right_click
        self.loadouts_window:init()

        local theme = self.loadouts_window.theme
		theme.color = {0, 0, 0, 0}
		theme.color_hover = theme.color
    end

end

-- Function to Reload the loadouts window, after closing any already open windows.
mod.reload_windows = function(self)
    self:destroy_windows()
    self:create_loadouts_window()
end

-- Function to return a loadout for a given loadout number and career name.
mod.get_loadout = function(self, loadout_number, career_name)
    return self.saved_loadouts[(career_name .. "/" .. tostring(loadout_number))]
end

-- Function to save the loadout (gear/talents/cosmetics) for a given loadout number and career name.
mod.save_loadout = function(self, loadout_number, career_name)

    -- Retrieve the current gear
    local gear_loadout = {}
    for _, slot in ipairs(InventorySettings.slots_by_ui_slot_index) do
        local item_backend_id = BackendUtils.get_loadout_item_id(career_name, slot.name)
        if item_backend_id then gear_loadout[slot.name] = item_backend_id end
    end

    -- Retrieve the current cosmetics
    local cosmetics_loadout = {}
    for _, slot in ipairs(InventorySettings.slots_by_cosmetic_index) do
        local item_backend_id = BackendUtils.get_loadout_item_id(career_name, slot.name)
        if item_backend_id then cosmetics_loadout[slot.name] = item_backend_id end
    end

    -- Retrieve the current talents from the local variable (if in the Talents view) or the backend
    local talents_loadout = {}
    local talents_backend = Managers.backend:get_interface("talents")
    talents_loadout = table.clone(talents_backend:get_talents(career_name))
    
    -- Retrieve the current saved loadout from the cloud file. Create it if non-existant
    local existingLoadout = self:get_loadout(loadout_number, career_name)
    if not existingLoadout then
        existingLoadout = {}
    end

    -- Update the saved loadout
    existingLoadout.gear = gear_loadout
    existingLoadout.cosmetics = cosmetics_loadout
    existingLoadout.talents = talents_loadout    

    -- Save the updated loadout in the cloud file    
    self.saved_loadouts[(career_name .. "/" .. tostring(loadout_number))] = existingLoadout
    self.cloud_file:cancel()
    self.cloud_file:save(self.saved_loadouts)
    self:echo(sprintf("Loadout #%d saved for %s", loadout_number, mod.careerDecodes[career_name]))

end

-- Function to determine whether the selected equipment is valid on a given career.
-- This check fixes exploits (quick switching careers / making loadouts in the modded realm and then swapping to offical)
local function is_equipment_valid(item, career_name, slot_name)

    local item_data = item.data
    local is_valid = table.contains(item_data.can_wield, career_name)

    if not is_valid then
         mod:echo("ERROR: Cannot equip item " .. item_data.display_name .. " on Career: " .. career_name) 
    else     
        local actual_slot_type = item_data.slot_type
        local expected_slot_type = InventorySettings.slots_by_name[slot_name].type
        is_valid = (actual_slot_type == expected_slot_type)

        -- Special case: Grail Knight, Slayer and Warrior Priest can equip melee weapons in the ranged slot.
        if not is_valid and (career_name == "es_questingKnight" or career_name == "dr_slayer" or career_name == "wh_priest") and expected_slot_type == ItemType.RANGED then
            is_valid = (actual_slot_type == ItemType.MELEE)
        end

        if not is_valid then mod:echo("ERROR: Cannot equip item " .. item_data.display_name .. " in this slot type: " .. expected_slot_type) end
    end

    return is_valid 
end

-- Function to check whether the next item in the equipment queue is valid in the specified slot, for the current career.
local function is_next_equip_valid(next_equip)	
    if not mod.hero_view_data then return false end
	local _, career_name = mod:get_hero_details()
	return is_equipment_valid(next_equip.item, career_name, next_equip.slot.name)
end

-- Function to equip the loadout (gear/talents/cosmetics) associated to the given loadout number.
mod.equip_loadout = function(self, loadout_number, career_name)

    -- Check for valid loadout
    local loadout = self:get_loadout(loadout_number, career_name)
    if not loadout then
        self:echo("Error: Loadout #" ..tostring(loadout_number).. " not found for " .. mod.careerDecodes[career_name])
        return
    end

    
    -- Set Talents
    local unit = Managers.player:local_player().player_unit

    if loadout.talents then
        local talents_backend = Managers.backend:get_interface("talents")
        talents_backend:set_talents(career_name, loadout.talents)    
        
        if unit and Unit.alive(unit) then
		 	ScriptUnit.extension(unit, "talent_system"):talents_changed()
		 	ScriptUnit.extension(unit, "inventory_system"):apply_buffs_to_ammo()
        end
    end

    -- Set Gear and Cosmetics
    if loadout.gear or loadout.cosmetics then
        local equipment_queue = self.equipment_queue
        local items_backend = Managers.backend:get_interface("items")

        for _, slot in pairs(InventorySettings.slots_by_slot_index) do
            -- Get item ID and item from the backend
            local item_backend_id = (loadout.gear and loadout.gear[slot.name]) or (loadout.cosmetics and loadout.cosmetics[slot.name])
            local item = item_backend_id and items_backend:get_item_from_id(item_backend_id)

            if item then
                local current_item_id = BackendUtils.get_loadout_item_id(career_name, slot.name)
                if not current_item_id or current_item_id ~= item_backend_id then
                    if unit then
                        -- Add item to queue
                        equipment_queue[#equipment_queue + 1] = {slot = slot, item = item}
                    elseif is_equipment_valid(item, career_name, slot.name) then
                        -- Set item 
                        BackendUtils.set_loadout_item(item_backend_id, career_name, slot.name)
                    end
                end
            end

        end
    end

    -- Echo completion message or set it to be handled by post_update hooked function
    local completion_message = sprintf("Loadout #%d equipped for %s", loadout_number, mod.careerDecodes[career_name])

    if #self.equipment_queue > 0 then
        self.completion_message = completion_message
    else
        self:echo(completion_message)
    end
end

--#########################--
----------- HOOKS -----------
--#########################--

-- Hook on HeroViewStateOverview._start_transition_animation
-- This hook sets the hero_view_data from Fatshark's Hero View screens, and loads the mod UI components
local hook_HeroWindowHeroPowerConsole_on_enter = function(self)
	mod.hero_view_data = self
	if mod.saved_loadouts then 
		mod:reload_windows() 
	end
end

-- Hook on HeroViewStateOverview.on_exit
-- This hook destroys our mod windows, and resets the hero_view_data as the Fatshark screens are now closed
local hook_HeroWindowHeroPowerConsole_on_exit = function()
	mod:destroy_windows()
	mod.cloud_file:cancel()
	mod.hero_view_data = nil
end

-- Hook on HeroViewStateOverview._setup_menu_layout, which fires when opening the details for a given Hero
-- This hook then adds our safe hooks to the HeroWindowCharacterInfo on_enter and on_exit to draw/destroy our windows
-- Note: The below functions will only ever Hook one time by design using is_hero_character_info_hooked 
mod:hook(HeroViewStateOverview, "_setup_menu_layout", function(hooked_function, ...)
	local use_gamepad_layout = hooked_function(...)

	if use_gamepad_layout and not is_hero_character_info_hooked then
		mod:hook_safe(HeroWindowHeroPowerConsole, "on_enter", hook_HeroWindowHeroPowerConsole_on_enter)
		mod:hook_safe(HeroWindowHeroPowerConsole, "on_exit", hook_HeroWindowHeroPowerConsole_on_exit)
        is_hero_character_info_hooked = true
	end

    return use_gamepad_layout
end)

-- Hook on HeroViewStateOverview.post_update()
-- This hook performs the equipping of items when a loadout is selected, one at a time from the equipment queue.
mod:hook_safe(HeroViewStateOverview, "post_update", function(self, dt, t)

    local equipment_queue = mod.equipment_queue
    local busy = false

    if equipment_queue[1] or mod.completion_message then

        -- Block input while the queue is still being processed, to prevent the hero view being closed.
        if not mod.is_loading then
            mod.is_loading = true
            self:block_input()
        end

        -- Check whether ready to equip the next item
        local unit = Managers.player:local_player().player_unit
		if unit and Unit.alive(unit) then
			local inventory_extn = ScriptUnit.extension(unit, "inventory_system")
			local attachment_extn = ScriptUnit.extension(unit, "attachment_system")
			busy = inventory_extn:resyncing_loadout() or attachment_extn.resync_id or self.ingame_ui._respawning
			if not busy and equipment_queue[1] then
				-- We're good to go.
				local next_equip = equipment_queue[1]
				table.remove(equipment_queue, 1)
				busy = true

				if is_next_equip_valid(next_equip) then
					local slot = next_equip.slot
					self:_set_loadout_item(next_equip.item, slot.name)
					if slot.type == ItemType.SKIN then
						self:update_skin_sync()
					end
				end
			end
		end

    elseif mod.is_loading then
        -- Finished equipping items. Unblock the input
        mod.is_loading = false
        self:unblock_input()
    end

    -- Print completion message
    if mod.completion_message and not busy then
        mod:echo(mod.completion_message)
        mod.completion_message = nil
    end

end)