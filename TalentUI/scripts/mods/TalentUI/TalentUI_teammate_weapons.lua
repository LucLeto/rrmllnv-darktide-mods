local mod = get_mod("TalentUI")

local pcall, tostring, type = pcall, tostring, type
local string_format = string.format

local MasterItems = require("scripts/backend/master_items")
local Ammo = require("scripts/utilities/ammo")

local TalentUISettings = mod:io_dofile("TalentUI/scripts/mods/TalentUI/TalentUI_settings")

-- Per player, per slot: { item_name, icon, ammo_current, ammo_max, ammo_text }; icon is re-resolved only when the equipped item changes
local teammate_weapons_data = {}

local player_previous_human_state_weapons = {}

local WEAPON_SLOTS = mod.WEAPON_SLOTS
local NUM_WEAPON_SLOTS = #WEAPON_SLOTS

local WEAPON_ICON_WIDGET_NAMES = {}
local WEAPON_TEXT_WIDGET_NAMES = {}

for i = 1, NUM_WEAPON_SLOTS do
	local weapon_slot = WEAPON_SLOTS[i]
	
	WEAPON_ICON_WIDGET_NAMES[i] = "talent_ui_weapon_" .. weapon_slot.id .. "_icon"
	WEAPON_TEXT_WIDGET_NAMES[i] = "talent_ui_weapon_" .. weapon_slot.id .. "_text"
end

-- Cached weapon settings; refreshed on load and from mod.on_setting_changed
local show_teammate_weapon_primary_icon
local show_teammate_weapon_secondary_icon
local teammate_weapon_show_ammo

local function refresh_teammate_weapon_settings()
	show_teammate_weapon_primary_icon = mod:get("show_teammate_weapon_primary_icon")
	show_teammate_weapon_secondary_icon = mod:get("show_teammate_weapon_secondary_icon")
	teammate_weapon_show_ammo = mod:get("teammate_weapon_show_ammo")
end

refresh_teammate_weapon_settings()

mod.refresh_teammate_weapon_settings = refresh_teammate_weapon_settings

-- Vanilla bot weapon items have no usable hud_icon; resolve icons through the equivalent player item.
local BOT_WEAPON_ICON_ITEMS = {
	["content/items/weapons/player/melee/bot_combatsword_linesman_p1"] = "content/items/weapons/player/melee/combatsword_p1_m1",
	["content/items/weapons/player/melee/bot_combatsword_linesman_p2"] = "content/items/weapons/player/melee/combatsword_p2_m1",
	["content/items/weapons/player/melee/bot_combataxe_linesman"] = "content/items/weapons/player/melee/combataxe_p1_m1",
	["content/items/weapons/player/ranged/bot_lasgun_killshot"] = "content/items/weapons/player/ranged/lasgun_p1_m1",
	["content/items/weapons/player/ranged/high_bot_lasgun_killshot"] = "content/items/weapons/player/ranged/lasgun_p1_m1",
	["content/items/weapons/player/ranged/bot_autogun_killshot"] = "content/items/weapons/player/ranged/autogun_p3_m1",
	["content/items/weapons/player/ranged/high_bot_autogun_killshot"] = "content/items/weapons/player/ranged/autogun_p3_m1",
	["content/items/weapons/player/ranged/bot_laspistol_killshot"] = "content/items/weapons/player/ranged/laspistol_p1_m1",
	["content/items/weapons/player/ranged/bot_zola_laspistol"] = "content/items/weapons/player/ranged/laspistol_p1_m1",
}

local function valid_icon(icon)
	return type(icon) == "string" and icon ~= ""
end

-- Returns the slot's icon plus the name of the item it was resolved from, or nil if the slot can't be resolved yet
local function get_player_weapon_by_slot(player, extensions, slot_name, item_name)
	if not extensions or not extensions.visual_loadout then
		return nil
	end
	
	local visual_loadout_extension = extensions.visual_loadout
	
	if not item_name or item_name == "not_equipped" then
		return nil
	end
	
	local success, item = pcall(visual_loadout_extension.item_from_slot, visual_loadout_extension, slot_name)
	
	if not success or not item then
		return nil
	end
	
	local resolved_item_name = item.name
	local icon = nil
	
	if resolved_item_name then
		local icon_item_name = BOT_WEAPON_ICON_ITEMS[resolved_item_name]
		if icon_item_name then
			local icon_item = MasterItems.get_item(icon_item_name)
			if icon_item and valid_icon(icon_item.hud_icon) then
				icon = icon_item.hud_icon
			end
		end
		
		if not icon then
			local master_item = MasterItems.get_item(resolved_item_name)
			if master_item and valid_icon(master_item.hud_icon) then
				icon = master_item.hud_icon
			end
		end
	end
	
	if not icon and valid_icon(item.hud_icon) then
		icon = item.hud_icon
	end
	
	if not icon then
		local success_template, weapon_template = pcall(visual_loadout_extension.weapon_template_from_slot, visual_loadout_extension, slot_name)
		
		if success_template and weapon_template then
			if valid_icon(weapon_template.hud_icon) then
				icon = weapon_template.hud_icon
			elseif valid_icon(weapon_template.hud_icon_small) then
				icon = weapon_template.hud_icon_small
			end
		end
	end
	
	if not icon then
		icon = "content/ui/materials/icons/weapons/hud/combat_blade_01"
	end
	
	return icon, resolved_item_name
end

local function set_team_weapon_widget_visible(widget, visible)
	local content = widget and widget.content

	if not content then
		return
	end

	widget.visible = true

	if content.visible ~= visible then
		content.visible = visible
		widget.dirty = true
	end
end

local function hide_all_weapon_widgets(self)
	local widgets_by_name = self._widgets_by_name

	for i = 1, NUM_WEAPON_SLOTS do
		local icon_widget = widgets_by_name[WEAPON_ICON_WIDGET_NAMES[i]]
		local text_widget = widgets_by_name[WEAPON_TEXT_WIDGET_NAMES[i]]

		set_team_weapon_widget_visible(icon_widget, false)
		set_team_weapon_widget_visible(text_widget, false)
	end
end

local function update_teammate_weapons(self, player, dt)
	local widgets_by_name = self._widgets_by_name
	
	if not widgets_by_name then
		return
	end
	
	-- if self._show_as_dead or self._dead or self._hogtied then
	-- 	hide_all_weapon_widgets(self)
	-- 	return
	-- end
	
	local player_peer_id = player:peer_id()
	if not player_peer_id then
		hide_all_weapon_widgets(self)
		return
	end
	
	local player_identifier = player:unique_id() or tostring(player_peer_id)

	local extensions = self:_player_extensions(player)

	if not extensions then
		hide_all_weapon_widgets(self)
		return
	end

	local is_human_controlled = player:is_human_controlled()
	local was_human_controlled = player_previous_human_state_weapons[player_identifier]

	if was_human_controlled and not is_human_controlled then
		mod.clear_teammate_weapons_data(player_identifier)
	end

	player_previous_human_state_weapons[player_identifier] = is_human_controlled

	local show_for_bots = TalentUISettings and TalentUISettings.show_abilities_for_bots ~= false
	if (not show_for_bots and not is_human_controlled) or self._show_as_dead or self._dead or self._hogtied then
		hide_all_weapon_widgets(self)
		return
	end
	
	local player_weapons_data = teammate_weapons_data[player_identifier]
	if not player_weapons_data then
		player_weapons_data = {}
		teammate_weapons_data[player_identifier] = player_weapons_data
	end
	
	local unit_data_extension = extensions.unit_data
	local inventory_component = unit_data_extension and unit_data_extension:read_component("inventory")
	
	local weapon_icon_width = TalentUISettings.teammate_weapon_icon_width
	local weapon_icon_height = TalentUISettings.teammate_weapon_icon_height
	
	for i = 1, NUM_WEAPON_SLOTS do
		-- if self._show_as_dead or self._dead or self._hogtied then
		-- 	hide_all_weapon_widgets(self)
		-- 	return
		-- end
		
		local weapon_slot = WEAPON_SLOTS[i]
		local icon_widget = widgets_by_name[WEAPON_ICON_WIDGET_NAMES[i]]
		
		if icon_widget then
			local slot_id = weapon_slot.id
			local slot_name = weapon_slot.slot
			local text_widget = widgets_by_name[WEAPON_TEXT_WIDGET_NAMES[i]]
			
			local weapon_data = player_weapons_data[slot_id]
			if not weapon_data then
				weapon_data = {}
				player_weapons_data[slot_id] = weapon_data
			end
			
			-- Cache the resolved item's own name, so an inventory/visual loadout mismatch is retried next frame
			local item_name = inventory_component and inventory_component[slot_name]
			if weapon_data.item_name ~= item_name then
				local icon, resolved_item_name = get_player_weapon_by_slot(player, extensions, slot_name, item_name)
				if icon then
					weapon_data.icon = icon
					weapon_data.item_name = resolved_item_name
				end
			end
			
			local has_weapon = weapon_data.icon ~= nil
			
			local show_weapon_icon = true
			if slot_id == "primary" then
				show_weapon_icon = show_teammate_weapon_primary_icon
			elseif slot_id == "secondary" then
				show_weapon_icon = show_teammate_weapon_secondary_icon
			end

			if has_weapon and show_weapon_icon then
				local icon = weapon_data.icon
				local icon_content = icon_widget.content
				local needs_icon_update = false
				
				local icon_style = icon_widget.style
				icon_style = icon_style and icon_style.icon
				
				if icon_style then
					local icon_size = icon_style.size
					if icon_size then
						if icon_size[1] ~= weapon_icon_width or icon_size[2] ~= weapon_icon_height then
							icon_size[1] = weapon_icon_width
							icon_size[2] = weapon_icon_height
							needs_icon_update = true
						end
					end
				end
				
				if icon and icon_content then
					if icon_content.icon ~= icon then
						icon_content.icon = icon
						needs_icon_update = true
					end
				end
				
				if icon_content.visible ~= true then
					set_team_weapon_widget_visible(icon_widget, true)
					needs_icon_update = true
				end
				
				if needs_icon_update then
					icon_widget.dirty = true
				end
				
				if text_widget then
					local needs_text_update = false
					local new_text = ""
					local new_visible = false
					
					if teammate_weapon_show_ammo then
						local slot_component = unit_data_extension and unit_data_extension:has_component(slot_name) and unit_data_extension:read_component(slot_name)
						
						if slot_component then
							local total_max_ammo = (Ammo.max_ammo_in_clips(slot_component) or 0) + (Ammo.max_ammo_in_reserve(slot_component) or 0)
							local total_current_ammo = (Ammo.current_ammo_in_clips(slot_component) or 0) + (Ammo.current_ammo_in_reserve(slot_component) or 0)
							
							if total_max_ammo == 0 then
								new_text = ""
								new_visible = false
							else
								if weapon_data.ammo_current ~= total_current_ammo or weapon_data.ammo_max ~= total_max_ammo then
									weapon_data.ammo_current = total_current_ammo
									weapon_data.ammo_max = total_max_ammo
									weapon_data.ammo_text = string_format("%d/%d", total_current_ammo, total_max_ammo)
								end
								
								new_text = weapon_data.ammo_text
								new_visible = true
							end
						else
							new_text = ""
							new_visible = false
						end
					else
						new_text = ""
						new_visible = false
					end
					
					local text_content = text_widget.content
					
					if text_content.text ~= new_text then
						text_content.text = new_text
						needs_text_update = true
					end
					
					if text_content.visible ~= new_visible then
						set_team_weapon_widget_visible(text_widget, new_visible)
						needs_text_update = true
					end
					
					if needs_text_update then
						text_widget.dirty = true
					end
				end
			else
				set_team_weapon_widget_visible(icon_widget, false)
				set_team_weapon_widget_visible(text_widget, false)
			end
		end
	end
end

mod.update_teammate_weapons = update_teammate_weapons

mod.clear_teammate_weapons_data = function(player_identifier)
	teammate_weapons_data[player_identifier] = nil
	player_previous_human_state_weapons[player_identifier] = nil
end

