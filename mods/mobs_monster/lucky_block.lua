
if minetest.get_modpath("lucky_block") then

	local web = {name = "mobs:cobweb"}
	local web_trap = {
		size = {x = 3, y = 3, z = 3},
		data = {
			web, web, web,
			web, web, web,
			web, web, web,

			web, web, web,
			web, web, web,
			web, web, web,

			web, web, web,
			web, web, web,
			web, web, web,
		},
	}

	lucky_block:add_schematics({
		{"webtrap", web_trap, {x = 1, y = 0, z = 1}},
	})

	lucky_block:add_blocks({
		{"sch", "webtrap", 1, true},
		{"spw", "mobs:dungeon_master", 1, nil, nil, 3, "Billy"},
		{"spw", "mobs:sand_monster", 3},
		{"spw", "mobs:stone_monster", 3, nil, nil, 3, "Bob"},
		{"spw", "mobs:dirt_monster", 3},
		{"spw", "mobs:tree_monster", 3},
		{"spw", "mobs:oerkki", 3},
		{"exp"},
		{"spw", "mobs:spider", 5},
		{"spw", "mobs:mese_monster", 2},
		{"spw", "mobs:lava_flan", 3},
		{"nod", "default:chest", 0, {
			{name = "mobs:lava_orb", max = 1}}},
	})

end
