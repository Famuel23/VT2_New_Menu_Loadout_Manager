--[[
	Creates a set of Fatshark style widgets to display the 10 loadouts that can be selected.

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
	element = {
		passes = {
			{
				pass_type = "hotspot",
				content_id = "button_hotspot"
			},
			{
				pass_type = "rect",
				style_id = "rect"
			},
			{
				pass_type = "text",
				text_id = "text",
				style_id = "text"
			}--,
			-- {
			-- 	pass_type = "texture_frame",
			-- 	texture_id = "frame",
			-- 	style_id = "frame"
			-- }
		}
	}

	style = {
		rect = {
			color = Colors.get_color_table_with_alpha("black", 200),
			offset = {0, 0, 0}
		},
		text = {
			text_color = { 255, 255, 255, 255 },
			font_type = "hell_shark",
			font_size = 18,
			vertical_alignment = "center",
			horizontal_alignment = "center",
			offset = {0, 0, 1}
		}--,
		-- frame = {
		-- 	texture_size = UIFrameSettings.menu_frame_12.texture.texture_size,
		-- 	texture_sizes = UIFrameSettings.menu_frame_12.texture.texture_sizes,
		-- 	color = {255, 255, 255, 255},
		-- 	offset = {0, 0, 2}
		-- }
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
			text = tostring(i)--,
			--frame = UIFrameSettings.menu_frame_12.texture
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