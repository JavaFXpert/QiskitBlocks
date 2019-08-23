
if minetest.get_modpath("lucky_block") then

	lucky_block:add_blocks({
		{"spw", "mobs:npc", 1, true, true},
		{"spw", "mobs:igor", 1, true, true, 5, "Igor"},
		{"spw", "mobs:trader", 1, false, false},
		{"lig", "fire:permanent_flame"},
	})

end
