local mod = get_mod("New_Menu_Loadout_Manager")

--[[
	Author: famuel_nz

    Adds the functionality for saving and quickly changing between loadouts (items/talents/cosmetics) with the new menu style. 
--]]

--#########################--
--------- VARIABLES ---------
--#########################--

-- Local variables
local NUM_LOADOUT_BUTTONS = 10
local is_hero_character_info_hooked = false

-- Mod variables
mod.cloud_file = nil
mod.saved_loadouts = nil
mod.hero_view_data = nil
mod.scenegraph= nil
mod.widgets = nil
mod.is_loading = false
mod.equipment_queue = {}
mod.careerDecodes = {}

--#########################--
--------- FUNCTIONS ---------
--#########################--

-- Function which performs initial setup of career decodes and a cloud file for saving loadout data.
mod.on_all_mods_loaded = function()
    
    -- Create a local object to access the file in which saved loadouts are kept
    -- DATA is saved in C:\Program Files (x86)\Steam\userdata\%usernumber%\552500\remote
    local CloudFile = mod:dofile("scripts/mods/New_Menu_Loadout_Manager/cloud_file") 
    mod.cloud_file = CloudFile:new(mod, mod:get_name() .. ".data")
    mod.cloud_file:load(function(result)
		mod.saved_loadouts = result.data or {}
	end)

    -- Creates a function which returns a series of widgets (10 loadout buttons) and an initialised UI scenegraph
    mod.make_loadout_widgets = mod:dofile("scripts/mods/New_Menu_Loadout_Manager/make_loadout_widgets")

    -- Initialise decodes for hero career names
    mod.careerDecodes = {es_mercenary = "Mercenary", es_huntsman = "Huntsman", es_knight = "Foot Knight", es_questingknight = "Grail Knight",
                         dr_ranger = "Ranger Veteran", dr_ironbreaker = "Ironbreaker", dr_slayer = "Slayer", dr_engineer = "Outcast Engineer",
                         we_waywatcher = "Waystalker", we_maidenguard = "Handmaiden", we_shade = "Shade", we_thornsister = "Sister of the Thorn",
                         wh_captain = "Witch Hunter Captain", wh_bountyhunter = "Bounty Hunter", wh_zealot = "Zealot", wh_priest = "Warrior Priest",
                         bw_adept = "Battle Wizard", bw_scholar = "Pyromancer", bw_unchained = "Unchained", bw_necromancer = "Necromancer"}

end

-- Function to return the hero name, career name, and career index of the selected loadout.
mod.get_hero_details = function(self)
    local profile_index = FindProfileIndex(self.hero_view_data.hero_name)
    local profile = SPProfiles[profile_index]
	local career_index = self.hero_view_data.career_index
	local career_name = profile.careers[career_index].name
	return self.hero_view_data.hero_name, career_name, career_index
end

-- Function to return a loadout for a given loadout number and career name.
mod.get_loadout = function(self, loadout_number, career_name)
    return self.saved_loadouts[(career_name .. "/" .. tostring(loadout_number))]
end

-- Function to set a loadout in the saved_loadouts variable, and update the cloud file accordingly
mod.set_loadout = function(self, loadout_number, career_name, existingLoadout)
    self.saved_loadouts[(career_name .. "/" .. tostring(loadout_number))] = existingLoadout
    self.cloud_file:cancel()
    self.cloud_file:save(self.saved_loadouts)
end

-- Function to save the loadout (gear/talents/cosmetics) for a given loadout number and career name.
mod.save_loadout = function(self, loadout_number)

    -- Retrieve active career details
    local _, career_name = mod:get_hero_details()

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

    -- Retrieve the current talents from the backend manager
    local talents_loadout = {}
    local talents_backend = Managers.backend:get_interface("talents")
    talents_loadout = table.clone(talents_backend:get_talents(career_name))
    
    -- Retrieve the existing loadout from the cloud file. Create a loadout if it does not exist
    local existingLoadout = self:get_loadout(loadout_number, career_name)
    if not existingLoadout then
        existingLoadout = {}
    end

    -- Update the existing loadout
    existingLoadout.gear = gear_loadout
    existingLoadout.cosmetics = cosmetics_loadout
    existingLoadout.talents = talents_loadout    

    -- Save the updated loadout in the cloud file    
    self:set_loadout(loadout_number, career_name, existingLoadout)
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

        if not is_valid then 
            mod:echo("ERROR: Cannot equip item " .. item_data.display_name .. " in this slot type: " .. expected_slot_type) 
        end
    end

    return is_valid 
end

-- Function to check whether the next item in the equipment queue is valid in the specified slot, for the current career.
local function is_next_equip_valid(next_equip)	
    if not mod.hero_view_data then 
        return false 
    end

	local _, career_name = mod:get_hero_details()
	return is_equipment_valid(next_equip.item, career_name, next_equip.slot.name)
end

-- Function to equip the loadout (gear/talents/cosmetics) associated to the given loadout number.
mod.equip_loadout = function(self, loadout_number)

    -- Retrieve active career details
    local _, career_name = mod:get_hero_details()
        
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
                    -- Add item to queue for equipping asynchronously in hook: HeroViewStateOverview.post_update()
                    if is_equipment_valid(item, career_name, slot.name) then
                        equipment_queue[#equipment_queue + 1] = {slot = slot, item = item}
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

-- Function which determines if a loadout button is currently being hovered.
local is_loadout_hovered = function (self)
    for i = 1, NUM_LOADOUT_BUTTONS do        
		local widget = mod.widgets.loadouts["loadout_" ..i]

		if widget then
            local hotspot = widget.content["button_hotspot"]
            
            if hotspot.on_hover_enter and not hotspot.disabled then
                return i
            end
        end
    end
end

-- Function which determines if a loadout button is currently being pressed.
-- Returns the loadout button index and left/right, depending on input type.
local is_loadout_pressed = function (self)
	for i = 1, NUM_LOADOUT_BUTTONS do        
		local widget = mod.widgets.loadouts["loadout_" ..i]

		if widget then
            local hotspot = widget.content["button_hotspot"]
            
            if not hotspot.disabled then
                if hotspot.on_pressed and not hotspot.is_selected then
                    return i, "left"
                elseif hotspot.on_right_click then
                    return i, "right"
                end
            end
		end

	end
end

--#########################--
----------- HOOKS -----------
--#########################--

-- Hook on HeroWindowHeroPowerConsole.on_enter
-- This hook sets the hero_view_data from Fatshark's Hero View screens, and populates the loadout button widgets/scenegraph.
local hook_HeroWindowPanelConsole_on_enter = function(self)
	mod.hero_view_data = self

    local widget_populator = mod.make_loadout_widgets()
    mod.scenegraph = widget_populator.scenegraph
    mod.widgets = widget_populator.widgets
end

-- Hook on HeroWindowHeroPowerConsole.on_exit
-- This hook resets the hero_view_data and loadout widgets as the Fatshark Hero View screens are now closed.
local hook_HeroWindowPanelConsole_on_exit = function()
	mod.hero_view_data = nil
    mod.scenegraph = nil
    mod.widgets = nil
	mod.cloud_file:cancel()
end

-- Hook on HeroWindowHeroPowerConsole.draw
-- This hook draws the collection of widgets populated from the make_loadout_widgets file, set in the above on_enter hook
local hook_HeroWindowPanelConsole_draw = function(self, dt)

    -- TODO: We need to refresh talents when they are updated
    -- TODO: We need to keep track of current talents selected on the screen when saving talents
    
    --window._talent_interface:set_talents(window._career_name, window._selected_talents)
    --window:_initialize_talents()

    for index, window in ipairs(self.parent._active_windows) do

        if window.NAME == "HeroWindowTalentsConsole" or window.NAME == "HeroWindowLoadoutConsole" or window.NAME == "HeroWindowCosmeticsLoadoutConsole" then
            if mod.widgets and mod.scenegraph then
                UIRenderer.begin_pass(self.ui_renderer, mod.scenegraph, self.parent:window_input_service(), dt, nil, self.render_settings)
        
                for _, widget_group in pairs(mod.widgets) do
                    for _, widget in pairs(widget_group) do
                        UIRenderer.draw_widget(self.ui_renderer, widget)
                    end
                end
        
                UIRenderer.end_pass(self.ui_renderer)
            end
        end
    end
    
end

-- Hook on HeroViewStateOverview._handle_input
-- This hook will handle input events for equipping or saving a loadout to a given button.
mod:hook_safe(HeroViewStateOverview, "_handle_input", function (self, dt, t)

    if mod.widgets then
        -- Handle loadout button hovers
        local loadout_button_hover = is_loadout_hovered()
        if loadout_button_hover then 
            self:play_sound("play_gui_equipment_button_hover")
        end

        -- Handle loadout button presses
        local loadout_button_press, input = is_loadout_pressed()
        if loadout_button_press and input == "left" then
            mod:equip_loadout(loadout_button_press)
        elseif loadout_button_press and input == "right" then 
            mod:save_loadout(loadout_button_press)
        end        
    end

end)

-- Hook on HeroViewStateOverview._setup_menu_layout, which fires when opening the details for a Hero
-- This hook then adds our safe hooks to the HeroWindowHeroPowerConsole on_enter and on_exit to draw/destroy our windows
-- Note: is_hero_character_info_hooked variable used to prevent issues re-hooking the draw function.
mod:hook(HeroViewStateOverview, "_setup_menu_layout", function(hooked_function, ...)
	local use_gamepad_layout = hooked_function(...)

	if use_gamepad_layout and not is_hero_character_info_hooked then
		mod:hook_safe(HeroWindowPanelConsole, "on_enter", hook_HeroWindowPanelConsole_on_enter)
		mod:hook_safe(HeroWindowPanelConsole, "on_exit", hook_HeroWindowPanelConsole_on_exit)
        mod:hook_safe(HeroWindowPanelConsole, "draw", hook_HeroWindowPanelConsole_draw)
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

            -- Equip valid items from the queue.
			if not busy and equipment_queue[1] then
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