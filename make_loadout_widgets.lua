--[[
	Creates a set of widgets (representing the 10 loadout buttons) and their corresponding scenegraph information.

	Returns:
	 - An object containing an initialized UI scenegraph ("scenegraph"),
	 - A collection of widgets representing the loadout buttons ("widgets")
]]
return function()

	local scenegraph_definition = {
		root = {
			is_root = true,
			scale = "fit",
			size = {1920, 1080},
			position = {0, 0, 0},
		},
		loadout_1 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		},
		loadout_2 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		},
		loadout_3 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		},
		loadout_4 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		},
		loadout_5 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		},
		loadout_6 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		},
		loadout_7 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		},
		loadout_8 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		},
		loadout_9 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		},
		loadout_10 = {
			parent = "root",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = {60, 60},
			position = {160, 20, 0},
		}
	}

	-- Define the widget element passes and style used by each loadout button	
	local frame_settings = UIFrameSettings.menu_frame_12

	local element = {
		passes = {
			{
				pass_type = "hotspot",
				content_id = "button_hotspot",
				style_id = "button",
			},
			{
				pass_type = "rect",
				style_id = "button",
			},
			{
				pass_type = "text",
				text_id = "text",
				style_id = "text",
			},
			{
				pass_type = "texture_frame",
				style_id = "frame",
				texture_id = "frame",
			},
			{
				pass_type = "texture",
				style_id = "hover",
				texture_id = "hover",
				content_check_function = function (content)
					return content.button_hotspot.is_hover
				end,
			},
		}
	}

	local style = {
		button = {
			color = Colors.get_color_table_with_alpha("black", 200),
			offset = {0, 0, 0},
		},
		text = {
			text_color = {255, 255, 255, 255},
			font_type = "hell_shark",
			font_size = 18,
			vertical_alignment = "center",
			horizontal_alignment = "center",
			offset = {0, 0, 1},
		},
		frame = {
			texture_size = frame_settings.texture_size,
			texture_sizes = frame_settings.texture_sizes,
			color = {255, 255, 255, 255},
			offset = {0, 0, 2}
		},
		hover = {
			color = {255, 255, 255, 255},
			offset = {0, 0, 1},
		},
	}
	
	-- Create the ten loadout widgets used in the Hero View
	local widgets = {}
	local loadout_widgets = {}
	local x_offset = 0

	for i = 1, 10 do
		local widget_name = ("loadout_" .. tostring(i))
		local widget = {}

		widget.element = element

		widget.content = {
			button_hotspot = {},
			text = tostring(i),
			hover = "button_state_default_2",
			frame = frame_settings.texture,
		}

		widget.style = style
		widget.scenegraph_id = widget_name
		widget.offset = {x_offset, 0, 0}
		x_offset = x_offset + 70

		loadout_widgets[widget_name] = UIWidget.init(widget)
	end

	widgets.loadouts = loadout_widgets

	return {
		scenegraph = UISceneGraph.init_scenegraph(scenegraph_definition),
		widgets = widgets,
	}

end