local mod = get_mod("New_Menu_Loadout_Manager")

--[[
	Author: famuel_nz

    Adds the functionality for saving and quickly changing between gear/talent loadouts on the new menu style. 
--]]

--#########################--
----------- DATA ------------
--#########################--

-- Local variables
local NUM_LOADOUT_BUTTONS = 10
local InventorySettings = InventorySettings
local SPProfiles = SPProfiles
local is_hero_preview_hooked = false

-- Mod variables
mod.simple_ui = nil 
mod.button_theme = nil
mod.cloud_file = nil
mod.loadouts_data = nil
mod.fatshark_view = nil
mod.loadouts_window = nil
mod.equipment_queue = {}
mod.is_loading = false

-- Workaround for deletion (in patch 1.5) of a function required by SimpleUI.
UIResolutionScale = UIResolutionScale or UIResolutionScale_pow2

--#########################--
--------- FUNCTIONS ---------
--#########################--

--[[ Function to perform initial setup. --]]
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

    -- Create a local object to access the file in which saved loadouts are kept
    local CloudFile = mod:dofile("scripts/mods/New_Menu_Loadout_Manager/cloud_file") 
    mod.cloud_file = CloudFile:new(mod, mod:get_name() .. ".data")
    mod.cloud_file:load(function(result) mod.loadouts_data = result.data or {} end)
	
    --mod.make_loadout_widgets = mod:dofile("scripts/mods/New_Menu_Loadout_Manager/make_loadout_widgets")
end

-- Function to return the hero name, career name, and career index of the selected loadout.
mod.get_hero_and_career = function(self)
    local fatshark_view = self.fatshark_view

    local profile = SPProfiles[FindProfileIndex(fatshark_view.hero_name)]
	local career_index = fatshark_view.career_index
	local career_name = profile.careers[career_index].name
	return fatshark_view.hero_name, career_name, career_index
end

-- Function to return the size and position of the Loadout buttons window.
-- TODO: Figure out how to align this correctly, to bottom left by the friends
mod.get_gui_dimensions = function(self)	
    local scale = (UISettings.ui_scale or 100) / 100
    local gui_size = {math.floor(511 * scale), math.floor(694 * scale)}
	local gui_x_position = math.floor((UIResolutionWidthFragments() - gui_size[1]) / 4 + 30)
    local gui_y_position = math.floor((UIResolutionHeightFragments() - gui_size[2]) / 2 - 3) -- + 62 * scale)

    -- Return GUI size, Position, Height of Buttons
    return gui_size, {gui_x_position, gui_y_position}, math.floor(47 * scale)
end

-- Function to check for Right-Click events within the Loadout Buttons window, and send them to the correct widget.
local function dispatch_right_click(window)
    if stingray.Mouse.pressed(stingray.Mouse.button_id("right")) then
        local position = mod.simple_ui.mouse:cursor()

    --     for _, widget in pairs(window.widgets) do
    --         if simple_ui:point_in_bounds(position, widget:extended_bounds()) and widget.on_right_click then
    --             widget:on_right_click()
    --             break
    --         end
    --     end

    end
end

-- Function to close any currently open windows.
mod.destroy_windows = function(self)
    if self.loadouts_window then
    	self.loadouts_window:destroy()
        self.loadouts_window = nil
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

		local _, career_name = self:get_hero_and_career()

        -- On Left Click, Equip the loadout. Button params is index number
        local on_button_click = function(button)            
            local loadout_number = NUM_LOADOUT_BUTTONS + button.params       
            if self:get_loadout(loadout_number, career_name) then mod:equip_loadout(loadout_number, career_name) end
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
            newButton.on_click = on_button_click
			newButton.text = tostring(button_column)
			newButton.tooltip = sprintf("Loadout %d", button_column)
        end

        self.loadouts_window.on_hover_enter = dispatch_right_click
        self.loadouts_window:init()
    end
end

-- Function to Reload the loadouts window, after closing any already open windows.
mod.reload_windows = function(self)
    self:destroy_windows()
    self:create_loadouts_window()
end

-- Function to return the collection of loadouts for the current game mode.
-- "Deus" represents the Chaos Wastes game mode.
mod.get_loadouts = function(self)

	local data_root = self.loadouts_data

    -- If Chaos Wastes Mode - Return separate loadouts, or create them if none exist
    if Managers.mechanism:current_mechanism_name() == "deus" then
        local deus_loadouts = data_root.deus_loadouts

        if not deus_loadouts then
            deus_loadouts = {}
            data_root.deus_loadouts = deus_loadouts
        end

        return deus_loadouts
    end

    -- Otherwise, Adventure Mode - Return default loadouts
    return self.loadouts_data 
end

-- Function to return a loadout for a given loadout number and career name.
mod.get_loadout = function(self, loadout_number, career_name)
    return self:get_loadouts()[(career_name .. "/" .. tostring(loadout_number))]
end

-- Function to update the loadout for a given loadout number and career name.
mod.update_loadout = function(self, loadout_number, career_name, modifying_functor)

    local loadout = self:get_loadout(loadout_number, career_name)

    if not loadout then
        loadout = {}
        self:get_loadouts()[(career_name .. "/" .. tostring(loadout_number))] = loadout
    end

    modifying_functor(loadout)
    self.cloud_file:cancel()
    self.cloud_file:save(self.loadouts_data)
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

    -- Retrieve the current talents
    local talents_backend = Managers.backend:get_interface("talents")
    local talents_loadout = table.clone(talents_backend:get_talents(career_name))
    
    -- Update the loadout
    self:update_loadout(loadout_number, career_name, function(loadout)
        loadout.gear = gear_loadout
        loadout.cosmetics = cosmetics_loadout
        loadout.talents = talents_loadout
    end)

end

-- Function to determine whether the selected equipment is valid on a given career.
-- This check fixes exploits (quick switching careers / making loadouts in the modded realm and then swapping to offical)
local function is_equipment_valid(item, career_name, slot_name)

    local is_valid = false

    local item_data = item.data
    is_valid = table.contains(item_data.can_wield, career_name)
    if not is_valid then mod:echo("ERROR: Cannot equip item " .. item_data.display_name .. " on Career: " .. career_name) end
    
    local actual_slot_type = item_data.slot_type
    local expected_slot_type = InventorySettings.slots_by_name[slot_name].type
    is_valid = (actual_slot_type == expected_slot_type)
    if not is_valid then mod:echo("ERROR: Cannot equip item " .. item_data.display_name .. " in this slot type: " .. expected_slot_type) end

    return is_valid

    --TODO: Should this not apply to Warrior Priest as well?
    --if not is_valid and (career_name == "es_questingKnight" or career_name == "dr_slayer" ) and expected_slot_type == ItemType.RANGED then
    --    is_valid = (actual_slot_type == ItemType.MELEE)
    --end

end

-- Function to check whether the next item in the equipment queue is valid in the specified slot, for the current career.
local function is_next_equip_valid(next_equip)
	local fatshark_view = mod.fatshark_view
	if not fatshark_view then
		return false
	end

	local _, career_name = mod:get_hero_and_career()
	return is_equipment_valid(next_equip.item, career_name, next_equip.slot.name)
end

-- Function to equip the loadout (gear/talents/cosmetics) associated to the given loadout number.
mod.equip_loadout = function(self, loadout_number, career_name, exclude_gear, exclude_talents, exclude_cosmetics)

    local loadout = self:get_loadout(loadout_number, career_name)
    local is_active_career = not self.profile_picker_info
    
    -- Check for valid loadout
    if not loadout then
        self:echo("Error: Loadout #" ..tostring(loadout_number).. " not found for Career: " ..career_name)
        return
    end

    -- Set Talents
    if (not exclude_talents) and loadout.talents then

        local unit = Managers.player:local_player().player_unit
        Managers.backend:get_interface("talents"):set_talents(career_name, talents_loadout)        

        if unit and Unit.alive(unit) and is_active_career then
            ScriptUnit.extension(unit, "talent_system"):talents_changed()
            ScriptUnit.extension(unit, "inventory_system"):apply_buffs_to_ammo()
        end
    end

    -- Set Gear and Cosmetics
    local gear_loadout = (not exclude_gear) and loadout.gear
    local cosmetics_loadout = (not exclude_cosmetics) and loadout.cosmetics
    
    if gear_loadout or cosmetics_loadout then
        local equipment_queue = self.equipment_queue
        local items_backend = Managers.backend:get_interface("items")

        for _, slot in pairs(InventorySettings.slots_by_slot_index) do

            -- Get item ID and item from the backend
            local item_backend_id = (gear_loadout and gear_loadout[slot.name]) or (cosmetics_loadout and cosmetics_loadout[slot.name])
            local item = item_backend_id and items_backend:get_item_from_id(item_backend_id)

            if item then
                local current_item_id = BackendUtils.get_loadout_item_id(career_name, slot.name)
                if not current_item_id or current_item_id ~= item_backend_id then

                    if is_active_career then
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

    if #self.equipment_queue > 0 then
        self.echo(sprintf("Equipping Loadout #%d for hero %s ...", loadout_number, career_name))
        self.completion_message = sprintf("Loadout #%d equipped for hero %s", loadout_number, career_name)
    else
        self:echo(sprintf("Loadout #%d equipped for hero %s", loadout_number, career_name))
    end
end

--#########################--
----------- HOOKS -----------
--#########################--

-- Hook on HeroWindowCharacterInfo.on_enter()
-- This hook shows the loadouts window whenever the "Equipment" or "Cosmetics" screens are shown.
local hook_HeroWindowCharacterInfo_on_enter = function(self)
	mod.fatshark_view = self
	if mod.loadouts_data then 
		mod:reload_windows() 
	end
end

-- Hook on HeroWindowCharacterInfo.on_exit()
-- This hook hides the loadouts window whenever the "Equipment" or "Cosmetics" screens are closed.
local hook_HeroWindowCharacterInfo_on_exit = function()
	mod:destroy_windows()
	mod.cloud_file:cancel()
	mod.fatshark_view = nil
end

-- Hook on HeroViewStateOverview._setup_menu_layout
-- This hook then adds our hooks to the HeroWindowCharacterInfo class
-- TODO: This state might not be right. Seems to work when initially opening hero view, then drops off when looking at talents or equipment again.
mod:hook(HeroViewStateOverview, "_setup_menu_layout", function(hooked_function, ...)
	local use_gamepad_layout = hooked_function(...)

	if use_gamepad_layout and not is_hero_preview_hooked then

		mod:hook_safe(HeroWindowCharacterInfo, "on_enter", hook_HeroWindowCharacterInfo_on_enter)
		mod:hook_safe(HeroWindowCharacterInfo, "on_exit", hook_HeroWindowCharacterInfo_on_exit)

		is_hero_preview_hooked = true
	end
    
    --HeroWindowLoadout._equip_item_presentation = function (self, item, slot)
    --mod:hook(HeroWindowCharacterInfo)
	
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

            busy = inventory_exten:resyncing_loadout() or attachment_exten.resync_id or self.ingame_ui._respawning

            if not busy and equipment_queue[1] then
                local next_equip = equipment_queue[1]
                table.remove(equipment_queue, 1)
                busy = true

                if is_next_equip_valid(next_equip) then
                    local slot = next_equip.slot
                    self:_set_loadout_item(next_equip.item, slot.name)
                    if slot.type == ItemType.SKIN then self:update_skin_sync() end
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