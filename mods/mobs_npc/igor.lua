
local S = mobs.intllib

-- Igor by TenPlus1

mobs.igor_drops = {
	"vessels:glass_bottle", "mobs:meat_raw", "default:sword_steel",
	"farming:bread", "bucket:bucket_water"
}

mobs:register_mob("mobs_npc:igor", {
	type = "npc",
	passive = false,
	damage = 5,
	attack_type = "dogfight",
	owner_loyal = true,
	pathfinding = true,
	reach = 2,
	attacks_monsters = true,
	hp_min = 20,
	hp_max = 30,
	armor = 100,
	collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
	visual = "mesh",
	mesh = "mobs_character.b3d",
	textures = {
		{"mobs_igor.png"}, -- skin by ruby32199
		{"mobs_igor2.png"},
		{"mobs_igor3.png"},
		{"mobs_igor4.png"},
		{"mobs_igor5.png"},
		{"mobs_igor6.png"},
		{"mobs_igor7.png"},
		{"mobs_igor8.png"},
	},
	makes_footstep_sound = true,
	sounds = {},
	walk_velocity = 1,
	run_velocity = 2,
	stepheight = 1.1,
	fear_height = 2,
	jump = true,
	drops = {
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 2},
		{name = "default:gold_lump", chance = 3, min = 1, max = 1},
	},
	water_damage = 1,
	lava_damage = 3,
	light_damage = 0,
	follow = {"mobs:meat_raw", "default:diamond"},
	view_range = 15,
	owner = "",
	order = "follow",
	-- model animation
	animation = {
		speed_normal = 30,
		speed_run = 30,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 200,
		punch_end = 219,
	},
	-- right clicking with raw meat will give Igor more health
	on_rightclick = function(self, clicker)

		-- feed to heal npc
		if mobs:feed_tame(self, clicker, 8, false, true) then return end
		if mobs:protect(self, clicker) then return end
		if mobs:capture_mob(self, clicker, nil, 5, 80, false, nil) then return end

		local item = clicker:get_wielded_item()
		local name = clicker:get_player_name()

		-- right clicking with gold lump drops random item from mobs.npc_drops
		if item:get_name() == "default:gold_lump" then

			if not mobs.is_creative(name) then
				item:take_item()
				clicker:set_wielded_item(item)
			end

			local pos = self.object:get_pos()

			pos.y = pos.y + 0.5

			local drops = self.igor_drops or mobs.igor_drops

			minetest.add_item(pos, {
				name = drops[math.random(1, #drops)]
			})

			minetest.chat_send_player(name, S("NPC dropped you an item for gold!"))

			return
		end

		-- if owner switch between follow and stand
		if self.owner and self.owner == name then

			if self.order == "follow" then
				self.order = "stand"
				minetest.chat_send_player(name, S("NPC stands still."))
			else
				self.order = "follow"
				minetest.chat_send_player(name, S("NPC will follow you."))
			end
		end
	end,
})
-- register spawn egg
mobs:register_egg("mobs_npc:igor", S("Igor"), "mobs_meat_raw.png", 1)

-- compatibility
mobs:alias_mob("mobs:igor", "mobs_npc:igor")
