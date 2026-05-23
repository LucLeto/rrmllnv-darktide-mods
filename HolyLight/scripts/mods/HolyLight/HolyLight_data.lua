local mod = get_mod("HolyLight")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "general_group",
				type = "group",
				text = mod:localize("general_group"),
				sub_widgets = {
					{
						setting_id = "enable_mod",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "effect_height",
						type = "numeric",
						default_value = 0.1,
						range = { 0.1, 2.0 },
						decimals_number = 2,
						interval = 0.05,
					},
					{
						setting_id = "modes_group",
						type = "group",
						text = mod:localize("modes_group"),
						sub_widgets = {
							{
								setting_id = "show_in_missions",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "show_in_havoc_missions",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "show_in_expeditions",
								type = "checkbox",
								default_value = true,
								sub_widgets = {
									{
										setting_id = "show_in_expedition_safe_zone",
										type = "checkbox",
										default_value = false,
									},
								},
							},
							{
								setting_id = "show_in_mortis_trials",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "show_in_psykhanium",
								type = "checkbox",
								default_value = false,
							},
						},
					},
				},
			},
			{
				setting_id = "targets_group",
				type = "group",
				text = mod:localize("targets_group"),
				sub_widgets = {
					{
						setting_id = "enable_stimms",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_ammo_pickups",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_grenade_pickups",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_ammo_crates",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_medical_crates",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_plasteel_pickups",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_diamantine_pickups",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_grimoires",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_scriptures",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "expedition_group",
				type = "group",
				text = mod:localize("expedition_group"),
				sub_widgets = {
					{
						setting_id = "enable_expedition_salvage",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_expedition_tech_remnants",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_expedition_reliquaries",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_expedition_strikes",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_expedition_mines",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_expedition_luggables",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "events_group",
				type = "group",
				text = mod:localize("events_group"),
				sub_widgets = {
					{
						setting_id = "enable_event_skulls",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		},
	},
}
