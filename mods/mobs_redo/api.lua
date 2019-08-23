
-- Intllib and CMI support check
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP .. "/intllib.lua")
local use_cmi = minetest.global_exists("cmi")

mobs = {
	mod = "redo",
	version = "20190630",
	intllib = S,
	invis = minetest.global_exists("invisibility") and invisibility or {},
}

-- creative check
local creative_cache = minetest.settings:get_bool("creative_mode")
function mobs.is_creative(name)
	return creative_cache or minetest.check_player_privs(name, {creative = true})
end


-- localize math functions
local pi = math.pi
local square = math.sqrt
local sin = math.sin
local cos = math.cos
local abs = math.abs
local min = math.min
local max = math.max
local atann = math.atan
local random = math.random
local floor = math.floor
local atan = function(x)
	if not x or x ~= x then
		--error("atan bassed NaN")
		return 0
	else
		return atann(x)
	end
end


-- Load settings
local damage_enabled = minetest.settings:get_bool("enable_damage")
local mobs_spawn = minetest.settings:get_bool("mobs_spawn") ~= false
local peaceful_only = minetest.settings:get_bool("only_peaceful_mobs")
local disable_blood = minetest.settings:get_bool("mobs_disable_blood")
local mobs_drop_items = minetest.settings:get_bool("mobs_drop_items") ~= false
local mobs_griefing = minetest.settings:get_bool("mobs_griefing") ~= false
local creative = minetest.settings:get_bool("creative_mode")
local spawn_protected = minetest.settings:get_bool("mobs_spawn_protected") ~= false
local remove_far = minetest.settings:get_bool("remove_far_mobs") ~= false
local difficulty = tonumber(minetest.settings:get("mob_difficulty")) or 1.0
local show_health = minetest.settings:get_bool("mob_show_health") ~= false
local max_per_block = tonumber(minetest.settings:get("max_objects_per_block") or 99)
local mob_chance_multiplier = tonumber(minetest.settings:get("mob_chance_multiplier") or 1)

-- Peaceful mode message so players will know there are no monsters
if peaceful_only then
	minetest.register_on_joinplayer(function(player)
		minetest.chat_send_player(player:get_player_name(),
			S("** Peaceful Mode Active - No Monsters Will Spawn"))
	end)
end

-- calculate aoc range for mob count
local aoc_range = tonumber(minetest.settings:get("active_block_range")) * 16

-- pathfinding settings
local enable_pathfinding = true
local stuck_timeout = 3 -- how long before mob gets stuck in place and starts searching
local stuck_path_timeout = 10 -- how long will mob follow path before giving up

-- default nodes
local node_fire = "fire:basic_flame"
local node_permanent_flame = "fire:permanent_flame"
local node_ice = "default:ice"
local node_snowblock = "default:snowblock"
local node_snow = "default:snow"
mobs.fallback_node = minetest.registered_aliases["mapgen_dirt"] or "default:dirt"

local mob_class = {
	stepheight = 1.1, -- was 0.6
	fly_in = "air",
	owner = "",
	order = "",
	jump_height = 4, -- was 6
	lifetimer = 180, -- 3 minutes
	physical = true,
	collisionbox = {-0.25, -0.25, -0.25, 0.25, 0.25, 0.25},
	visual_size = {x = 1, y = 1},
	makes_footstep_sound = false,
	view_range = 5,
	walk_velocity = 1,
	run_velocity = 2,
	light_damage = 0,
	light_damage_min = 14,
	light_damage_max = 15,
	water_damage = 0,
	lava_damage = 0,
	suffocation = 2,
	fall_damage = 1,
	fall_speed = -10, -- must be lower than -2 (default: -10)
	drops = {},
	armor = 100,
	sounds = {},
	jump = true,
	knock_back = true,
	walk_chance = 50,
	stand_chance = 30,
	attack_chance = 5,
	passive = false,
	blood_amount = 5,
	blood_texture = "mobs_blood.png",
	shoot_offset = 0,
	floats = 1, -- floats in water by default
	replace_offset = 0,
	timer = 0,
	env_damage_timer = 0, -- only used when state = "attack"
	tamed = false,
	pause_timer = 0,
	horny = false,
	hornytimer = 0,
	child = false,
	gotten = false,
	health = 0,
	reach = 3,
	htimer = 0,
	docile_by_day = false,
	time_of_day = 0.5,
	fear_height = 0,
	runaway_timer = 0,
	immune_to = {},
	explosion_timer = 3,
	allow_fuse_reset = true,
	stop_to_explode = true,
	dogshoot_count = 0,
	dogshoot_count_max = 5,
	dogshoot_count2_max = 5,
	group_attack = false,
	attack_monsters = false,
	attack_animals = false,
	attack_players = true,
	attack_npcs = true,
	facing_fence = false,
	_cmi_is_mob = true,
}
local mob_class_meta = {__index = mob_class}

-- play sound
function mob_class:mob_sound(sound)

	if sound then
		minetest.sound_play(sound, {
			object = self.object,
			gain = 1.0,
			max_hear_distance = self.sounds.distance
		})
	end
end


-- attack player/mob
function mob_class:do_attack(player)

	if self.state == "attack" then
		return
	end

	self.attack = player
	self.state = "attack"

	if random(0, 100) < 90 then
		self:mob_sound(self.sounds.war_cry)
	end
end


-- calculate distance
local get_distance = function(a, b)

	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z

	return square(x * x + y * y + z * z)
end


-- collision function based on jordan4ibanez' open_ai mod
function mob_class:collision()

	local pos = self.object:get_pos()
	local vel = self.object:get_velocity()
	local x, z = 0, 0
	local width = -self.collisionbox[1] + self.collisionbox[4] + 0.5

	for _,object in ipairs(minetest.get_objects_inside_radius(pos, width)) do

		if object:is_player()
		or (object:get_luaentity()
		and object:get_luaentity()._cmi_is_mob == true
		and object ~= self.object) then

			local pos2 = object:get_pos()
			local vec  = {x = pos.x - pos2.x, z = pos.z - pos2.z}

			x = x + vec.x
			z = z + vec.z
		end
	end

	return({x, z})
end


-- move mob in facing direction
function mob_class:set_velocity(v)

	local c_x, c_y = 0, 0

	-- can mob be pushed, if so calculate direction
	if self.pushable then
		c_x, c_y = unpack(self:collision())
	end

	-- halt mob if it has been ordered to stay
	if self.order == "stand" then
		self.object:set_velocity({x = 0, y = 0, z = 0})
		return
	end

	local yaw = (self.object:get_yaw() or 0) + self.rotate

	self.object:set_velocity({
		x = (sin(yaw) * -v) + c_x,
		y = self.object:get_velocity().y,
		z = (cos(yaw) * v) + c_y,
	})
end

-- global version of above function
function mobs:set_velocity(entity, v)
	mob_class.set_velocity(entity, v)
end


-- calculate mob velocity
function mob_class:get_velocity()

	local v = self.object:get_velocity()

	return (v.x * v.x + v.z * v.z) ^ 0.5
end


-- set and return valid yaw
function mob_class:set_yaw(yaw, delay)

	if not yaw or yaw ~= yaw then
		yaw = 0
	end

	delay = delay or 0

	if delay == 0 then
		self.object:set_yaw(yaw)
		return yaw
	end

	self.target_yaw = yaw
	self.delay = delay

	return self.target_yaw
end

-- global function to set mob yaw
function mobs:yaw(entity, yaw, delay)
	mob_class.set_yaw(entity, yaw, delay)
end


-- set defined animation
function mob_class:set_animation(anim, force)

	if not self.animation
	or not anim then return end

	self.animation.current = self.animation.current or ""

	-- only set different animation for attacks when using same set
	if force ~= true and anim ~= "punch" and anim ~= "shoot"
	and string.find(self.animation.current, anim) then
		return
	end

	-- check for more than one animation
	local num = 0

	for n = 1, 4 do

		if self.animation[anim .. n .. "_start"]
		and self.animation[anim .. n .. "_end"] then
			num = n
		end
	end

	-- choose random animation from set
	if num > 0 then
		num = random(0, num)
		anim = anim .. (num ~= 0 and num or "")
	end

	if anim == self.animation.current
	or not self.animation[anim .. "_start"]
	or not self.animation[anim .. "_end"] then
		return
	end

	self.animation.current = anim

	self.object:set_animation({
		x = self.animation[anim .. "_start"],
		y = self.animation[anim .. "_end"]},
		self.animation[anim .. "_speed"] or self.animation.speed_normal or 15,
		0, self.animation[anim .. "_loop"] ~= false)
end

-- above function exported for mount.lua
function mobs:set_animation(entity, anim)
	mob_class.set_animation(entity, anim)
end


-- check line of sight (BrunoMine)
local line_of_sight = function(self, pos1, pos2, stepsize)

	stepsize = stepsize or 1

	local s, pos = minetest.line_of_sight(pos1, pos2, stepsize)

	-- normal walking and flying mobs can see you through air
	if s == true then
		return true
	end

	-- New pos1 to be analyzed
	local npos1 = {x = pos1.x, y = pos1.y, z = pos1.z}

	local r, pos = minetest.line_of_sight(npos1, pos2, stepsize)

	-- Checks the return
	if r == true then return true end

	-- Nodename found
	local nn = minetest.get_node(pos).name

	-- Target Distance (td) to travel
	local td = get_distance(pos1, pos2)

	-- Actual Distance (ad) traveled
	local ad = 0

	-- It continues to advance in the line of sight in search of a real
	-- obstruction which counts as 'normal' nodebox.
	while minetest.registered_nodes[nn]
	and (minetest.registered_nodes[nn].walkable == false) do
--	or minetest.registered_nodes[nn].drawtype == "nodebox") do

		-- Check if you can still move forward
		if td < ad + stepsize then
			return true -- Reached the target
		end

		-- Moves the analyzed pos
		local d = get_distance(pos1, pos2)

		npos1.x = ((pos2.x - pos1.x) / d * stepsize) + pos1.x
		npos1.y = ((pos2.y - pos1.y) / d * stepsize) + pos1.y
		npos1.z = ((pos2.z - pos1.z) / d * stepsize) + pos1.z

		-- NaN checks
		if d == 0
		or npos1.x ~= npos1.x
		or npos1.y ~= npos1.y
		or npos1.z ~= npos1.z then
			return false
		end

		ad = ad + stepsize

		-- scan again
		r, pos = minetest.line_of_sight(npos1, pos2, stepsize)

		if r == true then return true end

		-- New Nodename found
		nn = minetest.get_node(pos).name

	end

	return false
end


-- check line of sight (by BrunoMine, tweaked by Astrobe)
local new_line_of_sight = function(self, pos1, pos2, stepsize)

	if not pos1 or not pos2 then return end

	stepsize = stepsize or 1

	local stepv = vector.multiply(vector.direction(pos1, pos2), stepsize)

	local s, pos = minetest.line_of_sight(pos1, pos2, stepsize)

	-- normal walking and flying mobs can see you through air
	if s == true then return true end

	-- New pos1 to be analyzed
	local npos1 = {x = pos1.x, y = pos1.y, z = pos1.z}

	local r, pos = minetest.line_of_sight(npos1, pos2, stepsize)

	-- Checks the return
	if r == true then return true end

	-- Nodename found
	local nn = minetest.get_node(pos).name

	-- It continues to advance in the line of sight in search of a real
	-- obstruction which counts as 'normal' nodebox.
	while minetest.registered_nodes[nn]
	and (minetest.registered_nodes[nn].walkable == false) do
--	or minetest.registered_nodes[nn].drawtype == "nodebox") do

		npos1 = vector.add(npos1, stepv)

		if get_distance(npos1, pos2) < stepsize then return true end

		-- scan again
		r, pos = minetest.line_of_sight(npos1, pos2, stepsize)

		if r == true then return true end

		-- New Nodename found
		nn = minetest.get_node(pos).name
	end

	return false
end

-- check line of sight using raycasting (thanks Astrobe)
local ray_line_of_sight = function(self, pos1, pos2)

	local ray = minetest.raycast(pos1, pos2, true, false)
	local thing = ray:next()

	while thing do

		if thing.type == "object"
		and thing.ref ~= self.object
		and not thing.ref:is_player() then return false end

		if thing.type == "node" then

			local name = minetest.get_node(thing.under).name

			if minetest.registered_items[name]
			and minetest.registered_items[name].walkable then return false end
		end

		thing = ray:next()
	end

	return true
end

-- detect if using minetest 5.0 by searching for permafrost node
local is_50 = nil -- minetest.registered_nodes["default:permafrost"]

function mob_class:line_of_sight(pos1, pos2, stepsize)

	if is_50 then -- only use if minetest 5.0 is detected
		return ray_line_of_sight(self, pos1, pos2)
	end

	return line_of_sight(self, pos1, pos2, stepsize)
end

-- global function
function mobs:line_of_sight(entity, pos1, pos2, stepsize)
	return entity:line_of_sight(pos1, pos2, stepsize)
end


function mob_class:attempt_flight_correction()

	if self:flight_check() then return true end

	-- We are not flying in what we are supposed to.
	-- See if we can find intended flight medium and return to it
	local pos = self.object:get_pos()
	local searchnodes = self.fly_in

	if type(searchnodes) == "string" then
		searchnodes = {self.fly_in}
	end

	local flyable_nodes = minetest.find_nodes_in_area(
		{x = pos.x - 1, y = pos.y - 1, z = pos.z - 1},
		{x = pos.x + 1, y = pos.y + 1, z = pos.z + 1},
		searchnodes)

	if #flyable_nodes < 1 then
		return false
	end

	local escape_target = flyable_nodes[math.random(1, #flyable_nodes)]
	local escape_direction = vector.direction(pos, escape_target)

	self.object:set_velocity(
		vector.multiply(escape_direction, self.run_velocity))

	return true
end


-- are we flying in what we are suppose to? (taikedz)
function mob_class:flight_check()

	local def = minetest.registered_nodes[self.standing_in]

	if not def then return false end -- nil check

	if type(self.fly_in) == "string"
	and self.standing_in == self.fly_in then

		return true

	elseif type(self.fly_in) == "table" then

		for _,fly_in in pairs(self.fly_in) do

			if self.standing_in == fly_in then

				return true
			end
		end
	end

	-- stops mobs getting stuck inside stairs and plantlike nodes
	if def.drawtype ~= "airlike"
	and def.drawtype ~= "liquid"
	and def.drawtype ~= "flowingliquid" then
		return true
	end

	return false
end


-- if self.stay_near set then check periodically for nodes and turn to face/move
function mob_class:do_stay_near()

	if not self.stay_near then return false end

	local pos = self.object:get_pos()
	local searchnodes = self.stay_near[1]
	local chance = self.stay_near[2] or 10

	if random(1, chance) > 1 then
		return false
	end

	if type(searchnodes) == "string" then
		searchnodes = {self.stay_near[1]}
	end

	local r = self.view_range
	local nearby_nodes = minetest.find_nodes_in_area(
		{x = pos.x - r, y = pos.y - 1, z = pos.z - r},
		{x = pos.x + r, y = pos.y + 1, z = pos.z + r},
		searchnodes)

	if #nearby_nodes < 1 then
		return false
	end

	local target = nearby_nodes[math.random(1, #nearby_nodes)]
	local direction = vector.direction(pos, target)

	local vec = {
		x = target.x - pos.x,
		z = target.z - pos.z
	}

	yaw = (atan(vec.z / vec.x) + pi / 2) - self.rotate

	if target.x > pos.x then
		yaw = yaw + pi
	end

	yaw = self:set_yaw(yaw, 4)

	self:set_animation("walk")

	self:set_velocity(self.walk_velocity)

	return true
end


-- custom particle effects
local effect = function(pos, amount, texture, min_size, max_size, radius, gravity, glow)

	radius = radius or 2
	min_size = min_size or 0.5
	max_size = max_size or 1
	gravity = gravity or -10
	glow = glow or 0

	minetest.add_particlespawner({
		amount = amount,
		time = 0.25,
		minpos = pos,
		maxpos = pos,
		minvel = {x = -radius, y = -radius, z = -radius},
		maxvel = {x = radius, y = radius, z = radius},
		minacc = {x = 0, y = gravity, z = 0},
		maxacc = {x = 0, y = gravity, z = 0},
		minexptime = 0.1,
		maxexptime = 1,
		minsize = min_size,
		maxsize = max_size,
		texture = texture,
		glow = glow,
	})
end


-- update nametag colour
function mob_class:update_tag()

	local col = "#00FF00"
	local qua = self.hp_max / 4

	if self.health <= floor(qua * 3) then
		col = "#FFFF00"
	end

	if self.health <= floor(qua * 2) then
		col = "#FF6600"
	end

	if self.health <= floor(qua) then
		col = "#FF0000"
	end

	self.object:set_properties({
		nametag = self.nametag,
		nametag_color = col
	})
end


-- drop items
function mob_class:item_drop()

	-- check for nil or no drops
	if not self.drops or #self.drops == 0 then
		return
	end

	-- no drops if disabled by setting
	if not mobs_drop_items then return end

	-- no drops for child mobs
	if self.child then return end

	-- was mob killed by player?
	local death_by_player = self.cause_of_death and self.cause_of_death.puncher
		and self.cause_of_death.puncher:is_player() or nil

	local obj, item, num
	local pos = self.object:get_pos()

	for n = 1, #self.drops do

		if random(1, self.drops[n].chance) == 1 then

			num = random(self.drops[n].min or 0, self.drops[n].max or 1)
			item = self.drops[n].name

			-- cook items on a hot death
			if self.cause_of_death.hot then

				local output = minetest.get_craft_result({
					method = "cooking", width = 1, items = {item}})

				if output and output.item and not output.item:is_empty() then
					item = output.item:get_name()
				end
			end

			-- only drop rare items (drops.min=0) if killed by player
			if death_by_player then
				obj = minetest.add_item(pos, ItemStack(item .. " " .. num))

			elseif self.drops[n].min ~= 0 then
				obj = minetest.add_item(pos, ItemStack(item .. " " .. num))
			end

			if obj and obj:get_luaentity() then

				obj:set_velocity({
					x = random(-10, 10) / 9,
					y = 6,
					z = random(-10, 10) / 9,
				})

			elseif obj then
				obj:remove() -- item does not exist
			end
		end
	end

	self.drops = {}
end


-- check if mob is dead or only hurt
function mob_class:check_for_death(cmi_cause)

	-- has health actually changed?
	if self.health == self.old_health and self.health > 0 then
		return
	end

	self.old_health = self.health

	-- still got some health? play hurt sound
	if self.health > 0 then

		self:mob_sound(self.sounds.damage)

		-- make sure health isn't higher than max
		if self.health > self.hp_max then
			self.health = self.hp_max
		end

		-- backup nametag so we can show health stats
		if not self.nametag2 then
			self.nametag2 = self.nametag or ""
		end

		if show_health
		and (cmi_cause and cmi_cause.type == "punch") then

			self.htimer = 2
			self.nametag = "♥ " .. self.health .. " / " .. self.hp_max

			self:update_tag()
		end

		return false
	end

	self.cause_of_death = cmi_cause

	-- drop items
	self:item_drop()

	self:mob_sound(self.sounds.death)

	local pos = self.object:get_pos()

	-- execute custom death function
	if self.on_die then

		self:on_die(pos)

		if use_cmi then
			cmi.notify_die(self.object, cmi_cause)
		end

		self.object:remove()

		return true
	end

	-- default death function and die animation (if defined)
	if self.animation
	and self.animation.die_start
	and self.animation.die_end then

		local frames = self.animation.die_end - self.animation.die_start
		local speed = self.animation.die_speed or 15
		local length = max(frames / speed, 0)

		self.attack = nil
		self.v_start = false
		self.timer = 0
		self.blinktimer = 0
		self.passive = true
		self.state = "die"
		self:set_velocity(0)
		self:set_animation("die")

		minetest.after(length, function(self)

			if use_cmi and self.object:get_luaentity() then
				cmi.notify_die(self.object, cmi_cause)
			end

			self.object:remove()
		end, self)
	else

		if use_cmi then
			cmi.notify_die(self.object, cmi_cause)
		end

		self.object:remove()
	end

	effect(pos, 20, "tnt_smoke.png")

	return true
end


-- is mob facing a cliff
function mob_class:is_at_cliff()

	if self.fear_height == 0 then -- 0 for no falling protection!
		return false
	end

	local yaw = self.object:get_yaw()
	local dir_x = -sin(yaw) * (self.collisionbox[4] + 0.5)
	local dir_z = cos(yaw) * (self.collisionbox[4] + 0.5)
	local pos = self.object:get_pos()
	local ypos = pos.y + self.collisionbox[2] -- just above floor

	if minetest.line_of_sight(
		{x = pos.x + dir_x, y = ypos, z = pos.z + dir_z},
		{x = pos.x + dir_x, y = ypos - self.fear_height, z = pos.z + dir_z}
	, 1) then

		return true
	end

	return false
end


-- get node but use fallback for nil or unknown
local node_ok = function(pos, fallback)

	fallback = fallback or mobs.fallback_node

	local node = minetest.get_node_or_nil(pos)

	if node and minetest.registered_nodes[node.name] then
		return node
	end

	return minetest.registered_nodes[fallback]
end


-- environmental damage (water, lava, fire, light etc.)
function mob_class:do_env_damage()

	-- feed/tame text timer (so mob 'full' messages dont spam chat)
	if self.htimer > 0 then
		self.htimer = self.htimer - 1
	end

	-- reset nametag after showing health stats
	if self.htimer < 1 and self.nametag2 then

		self.nametag = self.nametag2
		self.nametag2 = nil

		self:update_tag()
	end

	local pos = self.object:get_pos()

	self.time_of_day = minetest.get_timeofday()

	-- remove mob if standing inside ignore node
	if self.standing_in == "ignore" then
		self.object:remove()
		return
	end

	-- is mob light sensative, or scared of the dark :P
	if self.light_damage ~= 0 then

		local light = minetest.get_node_light(pos) or 0

		if light >= self.light_damage_min
		and light <= self.light_damage_max then

			self.health = self.health - self.light_damage

			effect(pos, 5, "tnt_smoke.png")

			if self:check_for_death({type = "light"}) then return end
		end
	end

	local nodef = minetest.registered_nodes[self.standing_in]

	pos.y = pos.y + 1 -- for particle effect position

	-- water
	if self.water_damage
	and nodef.groups.water then

		if self.water_damage ~= 0 then

			self.health = self.health - self.water_damage

			effect(pos, 5, "bubble.png", nil, nil, 1, nil)

			if self:check_for_death({type = "environment",
					pos = pos, node = self.standing_in}) then return end
		end

	-- lava or fire or ignition source
	elseif self.lava_damage
	and nodef.groups.igniter then
--	and (nodef.groups.lava
--	or self.standing_in == node_fire
--	or self.standing_in == node_permanent_flame) then

		if self.lava_damage ~= 0 then

			self.health = self.health - self.lava_damage

			effect(pos, 5, "fire_basic_flame.png", nil, nil, 1, nil)

			if self:check_for_death({type = "environment",
					pos = pos, node = self.standing_in, hot = true}) then return end
		end

	-- damage_per_second node check
	elseif nodef.damage_per_second ~= 0 then

		self.health = self.health - nodef.damage_per_second

		effect(pos, 5, "tnt_smoke.png")

		if self:check_for_death({type = "environment",
				pos = pos, node = self.standing_in}) then return end
	end
--[[
	--- suffocation inside solid node
	if self.suffocation ~= 0
	and nodef.walkable == true
	and nodef.groups.disable_suffocation ~= 1
	and nodef.drawtype == "normal" then

		self.health = self.health - self.suffocation

		if self:check_for_death({type = "environment",
				pos = pos, node = self.standing_in}) then return end
	end
]]
	self:check_for_death({type = "unknown"})
end


-- jump if facing a solid node (not fences or gates)
function mob_class:do_jump()

	if not self.jump
	or self.jump_height == 0
	or self.fly
	or self.child
	or self.order == "stand" then
		return false
	end

	self.facing_fence = false

	-- something stopping us while moving?
	if self.state ~= "stand"
	and self:get_velocity() > 0.5
	and self.object:get_velocity().y ~= 0 then
		return false
	end

	local pos = self.object:get_pos()
	local yaw = self.object:get_yaw()

	-- what is mob standing on?
	pos.y = pos.y + self.collisionbox[2] - 0.2

	local nod = node_ok(pos)

--print ("standing on:", nod.name, pos.y)

	if minetest.registered_nodes[nod.name].walkable == false then
		return false
	end

	-- where is front
	local dir_x = -sin(yaw) * (self.collisionbox[4] + 0.5)
	local dir_z = cos(yaw) * (self.collisionbox[4] + 0.5)

	-- what is in front of mob?
	local nod = node_ok({
		x = pos.x + dir_x,
		y = pos.y + 0.5,
		z = pos.z + dir_z
	})

	-- thin blocks that do not need to be jumped
	if nod.name == node_snow then
		return false
	end

--print ("in front:", nod.name, pos.y + 0.5)

	if self.walk_chance == 0
	or minetest.registered_items[nod.name].walkable then

		if not nod.name:find("fence")
		and not nod.name:find("gate") then

			local v = self.object:get_velocity()

			v.y = self.jump_height

			self:set_animation("jump") -- only when defined

			self.object:set_velocity(v)

			-- when in air move forward
			minetest.after(0.3, function(self, v)

				if self.object:get_luaentity() then

					self.object:set_acceleration({
						x = v.x * 2,--1.5,
						y = 0,
						z = v.z * 2,--1.5
					})
				end
			end, self, v)

			if self:get_velocity() > 0 then
				self:mob_sound(self.sounds.jump)
			end
		else
			self.facing_fence = true
		end

		-- if we jumped against a block/wall 4 times then turn
		if self.object:get_velocity().x ~= 0
		or self.object:get_velocity().z ~= 0 then

			self.jump_count = (self.jump_count or 0) + 1
--print ("----", self.jump_count)
			if self.jump_count == 4 then

				local yaw = self.object:get_yaw() or 0

				yaw = self:set_yaw(yaw + 1.35, 8)
--print ("---- turn")
				self.jump_count = 0
			end
		end

		return true
	end

	return false
end


-- blast damage to entities nearby (modified from TNT mod)
local entity_physics = function(pos, radius)

	radius = radius * 2

	local objs = minetest.get_objects_inside_radius(pos, radius)
	local obj_pos, dist

	for n = 1, #objs do

		obj_pos = objs[n]:get_pos()

		dist = get_distance(pos, obj_pos)

		if dist < 1 then dist = 1 end

		local damage = floor((4 / dist) * radius)
		local ent = objs[n]:get_luaentity()

		-- punches work on entities AND players
		objs[n]:punch(objs[n], 1.0, {
			full_punch_interval = 1.0,
			damage_groups = {fleshy = damage},
		}, pos)
	end
end


-- should mob follow what I'm holding ?
function mob_class:follow_holding(clicker)

	if mobs.invis[clicker:get_player_name()] then
		return false
	end

	local item = clicker:get_wielded_item()
	local t = type(self.follow)

	-- single item
	if t == "string"
	and item:get_name() == self.follow then
		return true

	-- multiple items
	elseif t == "table" then

		for no = 1, #self.follow do

			if self.follow[no] == item:get_name() then
				return true
			end
		end
	end

	return false
end


-- find two animals of same type and breed if nearby and horny
function mob_class:breed()

	-- child takes 240 seconds before growing into adult
	if self.child == true then

		self.hornytimer = self.hornytimer + 1

		if self.hornytimer > 240 then

			self.child = false
			self.hornytimer = 0

			self.object:set_properties({
				textures = self.base_texture,
				mesh = self.base_mesh,
				visual_size = self.base_size,
				collisionbox = self.base_colbox,
				selectionbox = self.base_selbox,
			})

			-- custom function when child grows up
			if self.on_grown then
				self.on_grown(self)
			else
				-- jump when fully grown so as not to fall into ground
				self.object:set_velocity({
					x = 0,
					y = self.jump_height,
					z = 0
				})
			end
		end

		return
	end

	-- horny animal can mate for 40 seconds,
	-- afterwards horny animal cannot mate again for 200 seconds
	if self.horny == true
	and self.hornytimer < 240 then

		self.hornytimer = self.hornytimer + 1

		if self.hornytimer >= 240 then
			self.hornytimer = 0
			self.horny = false
		end
	end

	-- find another same animal who is also horny and mate if nearby
	if self.horny == true
	and self.hornytimer <= 40 then

		local pos = self.object:get_pos()

		effect({x = pos.x, y = pos.y + 1, z = pos.z}, 8, "heart.png", 3, 4, 1, 0.1)

		local objs = minetest.get_objects_inside_radius(pos, 3)
		local num = 0
		local ent = nil

		for n = 1, #objs do

			ent = objs[n]:get_luaentity()

			-- check for same animal with different colour
			local canmate = false

			if ent then

				if ent.name == self.name then
					canmate = true
				else
					local entname = string.split(ent.name,":")
					local selfname = string.split(self.name,":")

					if entname[1] == selfname[1] then
						entname = string.split(entname[2],"_")
						selfname = string.split(selfname[2],"_")

						if entname[1] == selfname[1] then
							canmate = true
						end
					end
				end
			end

			if ent
			and canmate == true
			and ent.horny == true
			and ent.hornytimer <= 40 then
				num = num + 1
			end

			-- found your mate? then have a baby
			if num > 1 then

				self.hornytimer = 41
				ent.hornytimer = 41

				-- spawn baby
				minetest.after(5, function(self, ent)

					if not self.object:get_luaentity() then
						return
					end

					-- custom breed function
					if self.on_breed then

						-- when false skip going any further
						if self:on_breed(ent) == false then
								return
						end
					else
						effect(pos, 15, "tnt_smoke.png", 1, 2, 2, 15, 5)
					end

					local mob = minetest.add_entity(pos, self.name)
					local ent2 = mob:get_luaentity()
					local textures = self.base_texture

					-- using specific child texture (if found)
					if self.child_texture then
						textures = self.child_texture[1]
					end

					-- and resize to half height
					mob:set_properties({
						textures = textures,
						visual_size = {
							x = self.base_size.x * .5,
							y = self.base_size.y * .5,
						},
						collisionbox = {
							self.base_colbox[1] * .5,
							self.base_colbox[2] * .5,
							self.base_colbox[3] * .5,
							self.base_colbox[4] * .5,
							self.base_colbox[5] * .5,
							self.base_colbox[6] * .5,
						},
						selectionbox = {
							self.base_selbox[1] * .5,
							self.base_selbox[2] * .5,
							self.base_selbox[3] * .5,
							self.base_selbox[4] * .5,
							self.base_selbox[5] * .5,
							self.base_selbox[6] * .5,
						},
					})
					-- tamed and owned by parents' owner
					ent2.child = true
					ent2.tamed = true
					ent2.owner = self.owner
				end, self, ent)

				num = 0

				break
			end
		end
	end
end


-- find and replace what mob is looking for (grass, wheat etc.)
function mob_class:replace(pos)

	if not mobs_griefing
	or not self.replace_rate
	or not self.replace_what
	or self.child == true
	or self.object:get_velocity().y ~= 0
	or random(1, self.replace_rate) > 1 then
		return
	end

	local what, with, y_offset

	if type(self.replace_what[1]) == "table" then

		local num = random(#self.replace_what)

		what = self.replace_what[num][1] or ""
		with = self.replace_what[num][2] or ""
		y_offset = self.replace_what[num][3] or 0
	else
		what = self.replace_what
		with = self.replace_with or ""
		y_offset = self.replace_offset or 0
	end

	pos.y = pos.y + y_offset

	if #minetest.find_nodes_in_area(pos, pos, what) > 0 then

-- print ("replace node = ".. minetest.get_node(pos).name, pos.y)

		local oldnode = {name = what}
		local newnode = {name = with}
		local on_replace_return

		if self.on_replace then
			on_replace_return = self:on_replace(pos, oldnode, newnode)
		end

		if on_replace_return ~= false then
			minetest.set_node(pos, {name = with})
		end
	end
end


-- check if daytime and also if mob is docile during daylight hours
function mob_class:day_docile()

	if self.docile_by_day == false then

		return false

	elseif self.docile_by_day == true
	and self.time_of_day > 0.2
	and self.time_of_day < 0.8 then

		return true
	end
end


local los_switcher = false
local height_switcher = false

-- path finding and smart mob routine by rnd, line_of_sight and other edits by Elkien3
function mob_class:smart_mobs(s, p, dist, dtime)

	local s1 = self.path.lastpos

	local target_pos = self.attack:get_pos()

	-- is it becoming stuck?
	if abs(s1.x - s.x) + abs(s1.z - s.z) < .5 then
		self.path.stuck_timer = self.path.stuck_timer + dtime
	else
		self.path.stuck_timer = 0
	end

	self.path.lastpos = {x = s.x, y = s.y, z = s.z}

	local use_pathfind = false
	local has_lineofsight = minetest.line_of_sight(
		{x = s.x, y = (s.y) + .5, z = s.z},
		{x = target_pos.x, y = (target_pos.y) + 1.5, z = target_pos.z}, .2)

	-- im stuck, search for path
	if not has_lineofsight then

		if los_switcher == true then
			use_pathfind = true
			los_switcher = false
		end -- cannot see target!
	else
		if los_switcher == false then

			los_switcher = true
			use_pathfind = false

			minetest.after(1, function(self)

				if self.object:get_luaentity() then

					if has_lineofsight then
						self.path.following = false
					end
				end
			end, self)
		end -- can see target!
	end

	if (self.path.stuck_timer > stuck_timeout and not self.path.following) then

		use_pathfind = true
		self.path.stuck_timer = 0

		minetest.after(1, function(self)

			if self.object:get_luaentity() then

				if has_lineofsight then
					self.path.following = false
				end
			end
		end, self)
	end

	if (self.path.stuck_timer > stuck_path_timeout and self.path.following) then

		use_pathfind = true
		self.path.stuck_timer = 0

		minetest.after(1, function(self)

			if self.object:get_luaentity() then

				if has_lineofsight then
					self.path.following = false
				end
			end
		end, self)
	end

	if abs(vector.subtract(s,target_pos).y) > self.stepheight then

		if height_switcher then
			use_pathfind = true
			height_switcher = false
		end
	else
		if not height_switcher then
			use_pathfind = false
			height_switcher = true
		end
	end

	if use_pathfind then
		-- lets try find a path, first take care of positions
		-- since pathfinder is very sensitive
		local sheight = self.collisionbox[5] - self.collisionbox[2]

		-- round position to center of node to avoid stuck in walls
		-- also adjust height for player models!
		s.x = floor(s.x + 0.5)
--		s.y = floor(s.y + 0.5) - sheight
		s.z = floor(s.z + 0.5)

		local ssight, sground = minetest.line_of_sight(s, {
			x = s.x, y = s.y - 4, z = s.z}, 1)

		-- determine node above ground
		if not ssight then
			s.y = sground.y + 1
		end

		local p1 = self.attack:get_pos()

		p1.x = floor(p1.x + 0.5)
		p1.y = floor(p1.y + 0.5)
		p1.z = floor(p1.z + 0.5)

		local dropheight = 6
		if self.fear_height ~= 0 then dropheight = self.fear_height end

		self.path.way = minetest.find_path(s, p1, 16, self.stepheight, dropheight, "Dijkstra")

--[[
		-- show path using particles
		if self.path.way and #self.path.way > 0 then
			print ("-- path length:" .. tonumber(#self.path.way))
			for _,pos in pairs(self.path.way) do
				minetest.add_particle({
				pos = pos,
				velocity = {x=0, y=0, z=0},
				acceleration = {x=0, y=0, z=0},
				expirationtime = 1,
				size = 4,
				collisiondetection = false,
				vertical = false,
				texture = "heart.png",
				})
			end
		end
]]

		self.state = ""
		self:do_attack(self.attack)

		-- no path found, try something else
		if not self.path.way then

			self.path.following = false

			 -- lets make way by digging/building if not accessible
			if self.pathfinding == 2 and mobs_griefing then

				-- is player higher than mob?
				if s.y < p1.y then

					-- build upwards
					if not minetest.is_protected(s, "") then

						local ndef1 = minetest.registered_nodes[self.standing_in]

						if ndef1 and (ndef1.buildable_to or ndef1.groups.liquid) then

								minetest.set_node(s, {name = mobs.fallback_node})
						end
					end

					local sheight = math.ceil(self.collisionbox[5]) + 1

					-- assume mob is 2 blocks high so it digs above its head
					s.y = s.y + sheight

					-- remove one block above to make room to jump
					if not minetest.is_protected(s, "") then

						local node1 = node_ok(s, "air").name
						local ndef1 = minetest.registered_nodes[node1]

						if node1 ~= "air"
						and node1 ~= "ignore"
						and ndef1
						and not ndef1.groups.level
						and not ndef1.groups.unbreakable
						and not ndef1.groups.liquid then

							minetest.set_node(s, {name = "air"})
							minetest.add_item(s, ItemStack(node1))

						end
					end

					s.y = s.y - sheight
					self.object:set_pos({x = s.x, y = s.y + 2, z = s.z})

				else -- dig 2 blocks to make door toward player direction

					local yaw1 = self.object:get_yaw() + pi / 2
					local p1 = {
						x = s.x + cos(yaw1),
						y = s.y,
						z = s.z + sin(yaw1)
					}

					if not minetest.is_protected(p1, "") then

						local node1 = node_ok(p1, "air").name
						local ndef1 = minetest.registered_nodes[node1]

						if node1 ~= "air"
							and node1 ~= "ignore"
							and ndef1
							and not ndef1.groups.level
							and not ndef1.groups.unbreakable
							and not ndef1.groups.liquid then

							minetest.add_item(p1, ItemStack(node1))
							minetest.set_node(p1, {name = "air"})
						end

						p1.y = p1.y + 1
						node1 = node_ok(p1, "air").name
						ndef1 = minetest.registered_nodes[node1]

						if node1 ~= "air"
						and node1 ~= "ignore"
						and ndef1
						and not ndef1.groups.level
						and not ndef1.groups.unbreakable
						and not ndef1.groups.liquid then

							minetest.add_item(p1, ItemStack(node1))
							minetest.set_node(p1, {name = "air"})
						end

					end
				end
			end

			-- will try again in 2 second
			self.path.stuck_timer = stuck_timeout - 2

			-- frustration! cant find the damn path :(
			--self:mob_sound(self.sounds.random)
		else
			-- yay i found path
			self:mob_sound(self.sounds.war_cry)
			self:set_velocity(self.walk_velocity)

			-- follow path now that it has it
			self.path.following = true
		end
	end
end


-- specific attacks
local specific_attack = function(list, what)

	-- no list so attack default (player, animals etc.)
	if list == nil then
		return true
	end

	-- found entity on list to attack?
	for no = 1, #list do

		if list[no] == what then
			return true
		end
	end

	return false
end


-- general attack function for all mobs ==========
function mob_class:general_attack()

	-- return if already attacking, passive or docile during day
	if self.passive
	or self.state == "attack"
	or self:day_docile() then
		return
	end

	local s = self.object:get_pos()
	local objs = minetest.get_objects_inside_radius(s, self.view_range)

	-- remove entities we aren't interested in
	for n = 1, #objs do

		local ent = objs[n]:get_luaentity()

		-- are we a player?
		if objs[n]:is_player() then

			-- if player invisible or mob not setup to attack then remove from list
			if self.attack_players == false
			or (self.owner and self.type ~= "monster")
			or mobs.invis[objs[n]:get_player_name()]
			or not specific_attack(self.specific_attack, "player") then
				objs[n] = nil
--print("- pla", n)
			end

		-- or are we a mob?
		elseif ent and ent._cmi_is_mob then

			-- remove mobs not to attack
			if self.name == ent.name
			or (not self.attack_animals and ent.type == "animal")
			or (not self.attack_monsters and ent.type == "monster")
			or (not self.attack_npcs and ent.type == "npc")
			or not specific_attack(self.specific_attack, ent.name) then
				objs[n] = nil
--print("- mob", n, self.name, ent.name)
			end

		-- remove all other entities
		else
--print(" -obj", n)
			objs[n] = nil
		end
	end

	local p, sp, dist, min_player
	local min_dist = self.view_range + 1

	-- go through remaining entities and select closest
	for _,player in pairs(objs) do

		p = player:get_pos()
		sp = s

		dist = get_distance(p, s)

		-- aim higher to make looking up hills more realistic
		p.y = p.y + 1
		sp.y = sp.y + 1

		-- choose closest player to attack that isnt self
		if dist ~= 0
		and dist < min_dist
		and self:line_of_sight(sp, p, 2) == true then
			min_dist = dist
			min_player = player
		end
	end

	-- attack closest player or mob
	if min_player and random(1, 100) > self.attack_chance then
		self:do_attack(min_player)
	end
end


-- specific runaway
local specific_runaway = function(list, what)

	-- no list so do not run
	if list == nil then
		return false
	end

	-- found entity on list to attack?
	for no = 1, #list do

		if list[no] == what then
			return true
		end
	end

	return false
end


-- find someone to runaway from
function mob_class:do_runaway_from()

	if not self.runaway_from then
		return
	end

	local s = self.object:get_pos()
	local p, sp, dist, pname
	local player, obj, min_player, name
	local min_dist = self.view_range + 1
	local objs = minetest.get_objects_inside_radius(s, self.view_range)

	for n = 1, #objs do

		if objs[n]:is_player() then

			pname = objs[n]:get_player_name()

			if mobs.invis[pname]
			or self.owner == pname then

				name = ""
			else
				player = objs[n]
				name = "player"
			end
		else
			obj = objs[n]:get_luaentity()

			if obj then
				player = obj.object
				name = obj.name or ""
			end
		end

		-- find specific mob to runaway from
		if name ~= "" and name ~= self.name
		and specific_runaway(self.runaway_from, name) then

			p = player:get_pos()
			sp = s

			-- aim higher to make looking up hills more realistic
			p.y = p.y + 1
			sp.y = sp.y + 1

			dist = get_distance(p, s)

			-- choose closest player/mob to runaway from
			if dist < min_dist
			and self:line_of_sight(sp, p, 2) == true then
				min_dist = dist
				min_player = player
			end
		end
	end

	if min_player then

		local lp = player:get_pos()
		local vec = {
			x = lp.x - s.x,
			y = lp.y - s.y,
			z = lp.z - s.z
		}

		local yaw = (atan(vec.z / vec.x) + 3 * pi / 2) - self.rotate

		if lp.x > s.x then
			yaw = yaw + pi
		end

		yaw = self:set_yaw(yaw, 4)
		self.state = "runaway"
		self.runaway_timer = 3
		self.following = nil
	end
end


-- follow player if owner or holding item, if fish outta water then flop
function mob_class:follow_flop()

	-- find player to follow
	if (self.follow ~= ""
	or self.order == "follow")
	and not self.following
	and self.state ~= "attack"
	and self.state ~= "runaway" then

		local s = self.object:get_pos()
		local players = minetest.get_connected_players()

		for n = 1, #players do

			if get_distance(players[n]:get_pos(), s) < self.view_range
			and not mobs.invis[ players[n]:get_player_name() ] then

				self.following = players[n]

				break
			end
		end
	end

	if self.type == "npc"
	and self.order == "follow"
	and self.state ~= "attack"
	and self.owner ~= "" then

		-- npc stop following player if not owner
		if self.following
		and self.owner
		and self.owner ~= self.following:get_player_name() then
			self.following = nil
		end
	else
		-- stop following player if not holding specific item
		if self.following
		and self.following:is_player()
		and self:follow_holding(self.following) == false then
			self.following = nil
		end

	end

	-- follow that thing
	if self.following then

		local s = self.object:get_pos()
		local p

		if self.following:is_player() then

			p = self.following:get_pos()

		elseif self.following.object then

			p = self.following.object:get_pos()
		end

		if p then

			local dist = get_distance(p, s)

			-- dont follow if out of range
			if dist > self.view_range then
				self.following = nil
			else
				local vec = {
					x = p.x - s.x,
					z = p.z - s.z
				}

				local yaw = (atan(vec.z / vec.x) + pi / 2) - self.rotate

				if p.x > s.x then yaw = yaw + pi end

				yaw = self:set_yaw(yaw, 6)

				-- anyone but standing npc's can move along
				if dist > self.reach
				and self.order ~= "stand" then

					self:set_velocity(self.walk_velocity)

					if self.walk_chance ~= 0 then
						self:set_animation("walk")
					end
				else
					self:set_velocity(0)
					self:set_animation("stand")
				end

				return
			end
		end
	end

	-- swimmers flop when out of their element, and swim again when back in
	if self.fly then

		local s = self.object:get_pos()

		if not self:attempt_flight_correction() then

			self.state = "flop"
			self.object:set_velocity({x = 0, y = -5, z = 0})

			self:set_animation("stand")

			return
		elseif self.state == "flop" then
			self.state = "stand"
		end
	end
end


-- dogshoot attack switch and counter function
function mob_class:dogswitch(dtime)

	-- switch mode not activated
	if not self.dogshoot_switch
	or not dtime then
		return 0
	end

	self.dogshoot_count = self.dogshoot_count + dtime

	if (self.dogshoot_switch == 1
	and self.dogshoot_count > self.dogshoot_count_max)
	or (self.dogshoot_switch == 2
	and self.dogshoot_count > self.dogshoot_count2_max) then

		self.dogshoot_count = 0

		if self.dogshoot_switch == 1 then
			self.dogshoot_switch = 2
		else
			self.dogshoot_switch = 1
		end
	end

	return self.dogshoot_switch
end


-- execute current state (stand, walk, run, attacks)
function mob_class:do_states(dtime)

	local yaw = self.object:get_yaw() or 0

	if self.state == "stand" then

		if random(1, 4) == 1 then

			local lp = nil
			local s = self.object:get_pos()
			local objs = minetest.get_objects_inside_radius(s, 3)

			for n = 1, #objs do

				if objs[n]:is_player() then
					lp = objs[n]:get_pos()
					break
				end
			end

			-- look at any players nearby, otherwise turn randomly
			if lp then

				local vec = {
					x = lp.x - s.x,
					z = lp.z - s.z
				}

				yaw = (atan(vec.z / vec.x) + pi / 2) - self.rotate

				if lp.x > s.x then yaw = yaw + pi end
			else
				yaw = yaw + random(-0.5, 0.5)
			end

			yaw = self:set_yaw(yaw, 8)
		end

		self:set_velocity(0)
		self:set_animation("stand")

		-- mobs ordered to stand stay standing
		if self.order ~= "stand"
		and self.walk_chance ~= 0
		and self.facing_fence ~= true
		and random(1, 100) <= self.walk_chance
		and self:is_at_cliff() == false then

			self:set_velocity(self.walk_velocity)
			self.state = "walk"
			self:set_animation("walk")
		end

	elseif self.state == "walk" then

		local s = self.object:get_pos()
		local lp = nil

		-- is there something I need to avoid?
		if self.water_damage > 0
		and self.lava_damage > 0 then

			lp = minetest.find_node_near(s, 1, {"group:water", "group:lava"})

		elseif self.water_damage > 0 then

			lp = minetest.find_node_near(s, 1, {"group:water"})

		elseif self.lava_damage > 0 then

			lp = minetest.find_node_near(s, 1, {"group:lava"})
		end

		if lp then

			-- if mob in water or lava then look for land
			if (self.lava_damage
				and minetest.registered_nodes[self.standing_in].groups.lava)
			or (self.water_damage
				and minetest.registered_nodes[self.standing_in].groups.water) then

				lp = minetest.find_node_near(s, 5, {"group:soil", "group:stone",
					"group:sand", node_ice, node_snowblock})

				-- did we find land?
				if lp then

					local vec = {
						x = lp.x - s.x,
						z = lp.z - s.z
					}

					yaw = (atan(vec.z / vec.x) + pi / 2) - self.rotate

					if lp.x > s.x then yaw = yaw + pi end

					-- look towards land and jump/move in that direction
					yaw = self:set_yaw(yaw, 6)
					self:do_jump()
					self:set_velocity(self.walk_velocity)
				else
					yaw = yaw + random(-0.5, 0.5)
				end

			else

				local vec = {
					x = lp.x - s.x,
					z = lp.z - s.z
				}

				yaw = (atan(vec.z / vec.x) + pi / 2) - self.rotate

				if lp.x > s.x then yaw = yaw + pi end
			end

			yaw = self:set_yaw(yaw, 8)

		-- otherwise randomly turn
		elseif random(1, 100) <= 30 then

			yaw = yaw + random(-0.5, 0.5)

			yaw = self:set_yaw(yaw, 8)
		end

		-- stand for great fall in front
		local temp_is_cliff = self:is_at_cliff()

		if self.facing_fence == true
		or temp_is_cliff
		or random(1, 100) <= self.stand_chance then

			self:set_velocity(0)
			self.state = "stand"
			self:set_animation("stand", true)
		else
			self:set_velocity(self.walk_velocity)

			if self:flight_check()
			and self.animation
			and self.animation.fly_start
			and self.animation.fly_end then
				self:set_animation("fly")
			else
				self:set_animation("walk")
			end
		end

	-- runaway when punched
	elseif self.state == "runaway" then

		self.runaway_timer = self.runaway_timer + 1

		-- stop after 5 seconds or when at cliff
		if self.runaway_timer > 5
		or self:is_at_cliff()
		or self.order == "stand" then
			self.runaway_timer = 0
			self:set_velocity(0)
			self.state = "stand"
			self:set_animation("stand")
		else
			self:set_velocity(self.run_velocity)
			self:set_animation("walk")
		end

	-- attack routines (explode, dogfight, shoot, dogshoot)
	elseif self.state == "attack" then

		-- calculate distance from mob and enemy
		local s = self.object:get_pos()
		local p = self.attack:get_pos() or s
		local dist = get_distance(p, s)

		-- stop attacking if player invisible or out of range
		if dist > self.view_range
		or not self.attack
		or not self.attack:get_pos()
		or self.attack:get_hp() <= 0
		or (self.attack:is_player() and mobs.invis[ self.attack:get_player_name() ]) then

--			print(" ** stop attacking **", dist, self.view_range)
			self.state = "stand"
			self:set_velocity(0)
			self:set_animation("stand")
			self.attack = nil
			self.v_start = false
			self.timer = 0
			self.blinktimer = 0
			self.path.way = nil

			return
		end

		if self.attack_type == "explode" then

			local vec = {
				x = p.x - s.x,
				z = p.z - s.z
			}

			yaw = (atan(vec.z / vec.x) + pi / 2) - self.rotate

			if p.x > s.x then yaw = yaw + pi end

			yaw = self:set_yaw(yaw)

			local node_break_radius = self.explosion_radius or 1
			local entity_damage_radius = self.explosion_damage_radius
					or (node_break_radius * 2)

			-- start timer when in reach and line of sight
			if not self.v_start
			and dist <= self.reach
			and self:line_of_sight(s, p, 2) then

				self.v_start = true
				self.timer = 0
				self.blinktimer = 0
				self:mob_sound(self.sounds.fuse)
--				print ("=== explosion timer started", self.explosion_timer)

			-- stop timer if out of reach or direct line of sight
			elseif self.allow_fuse_reset
			and self.v_start
			and (dist > self.reach
					or not self:line_of_sight(s, p, 2)) then
				self.v_start = false
				self.timer = 0
				self.blinktimer = 0
				self.blinkstatus = false
				self.object:settexturemod("")
			end

			-- walk right up to player unless the timer is active
			if self.v_start and (self.stop_to_explode or dist < 1.5) then
				self:set_velocity(0)
			else
				self:set_velocity(self.run_velocity)
			end

			if self.animation and self.animation.run_start then
				self:set_animation("run")
			else
				self:set_animation("walk")
			end

			if self.v_start then

				self.timer = self.timer + dtime
				self.blinktimer = (self.blinktimer or 0) + dtime

				if self.blinktimer > 0.2 then

					self.blinktimer = 0

					if self.blinkstatus then
						self.object:settexturemod("")
					else
						self.object:settexturemod("^[brighten")
					end

					self.blinkstatus = not self.blinkstatus
				end

--				print ("=== explosion timer", self.timer)

				if self.timer > self.explosion_timer then

					local pos = self.object:get_pos()

					-- dont damage anything if area protected or next to water
					if minetest.find_node_near(pos, 1, {"group:water"})
					or minetest.is_protected(pos, "") then

						node_break_radius = 1
					end

					self.object:remove()

					if minetest.get_modpath("tnt") and tnt and tnt.boom
					and not minetest.is_protected(pos, "") then

						tnt.boom(pos, {
							radius = node_break_radius,
							damage_radius = entity_damage_radius,
							sound = self.sounds.explode,
						})
					else

						minetest.sound_play(self.sounds.explode, {
							pos = pos,
							gain = 1.0,
							max_hear_distance = self.sounds.distance or 32
						})

						entity_physics(pos, entity_damage_radius)
						effect(pos, 32, "tnt_smoke.png", nil, nil, node_break_radius, 1, 0)
					end

					return
				end
			end

		elseif self.attack_type == "dogfight"
		or (self.attack_type == "dogshoot" and self:dogswitch(dtime) == 2)
		or (self.attack_type == "dogshoot" and dist <= self.reach and self:dogswitch() == 0) then

			if self.fly
			and dist > self.reach then

				local p1 = s
				local me_y = floor(p1.y)
				local p2 = p
				local p_y = floor(p2.y + 1)
				local v = self.object:get_velocity()

				if self:flight_check() then

					if me_y < p_y then

						self.object:set_velocity({
							x = v.x,
							y = 1 * self.walk_velocity,
							z = v.z
						})

					elseif me_y > p_y then

						self.object:set_velocity({
							x = v.x,
							y = -1 * self.walk_velocity,
							z = v.z
						})
					end
				else
					if me_y < p_y then

						self.object:set_velocity({
							x = v.x,
							y = 0.01,
							z = v.z
						})

					elseif me_y > p_y then

						self.object:set_velocity({
							x = v.x,
							y = -0.01,
							z = v.z
						})
					end
				end

			end

			-- rnd: new movement direction
			if self.path.following
			and self.path.way
			and self.attack_type ~= "dogshoot" then

				-- no paths longer than 50
				if #self.path.way > 50
				or dist < self.reach then
					self.path.following = false
					return
				end

				local p1 = self.path.way[1]

				if not p1 then
					self.path.following = false
					return
				end

				if abs(p1.x-s.x) + abs(p1.z - s.z) < 0.6 then
					-- reached waypoint, remove it from queue
					table.remove(self.path.way, 1)
				end

				-- set new temporary target
				p = {x = p1.x, y = p1.y, z = p1.z}
			end

			local vec = {
				x = p.x - s.x,
				z = p.z - s.z
			}

			yaw = (atan(vec.z / vec.x) + pi / 2) - self.rotate

			if p.x > s.x then yaw = yaw + pi end

			yaw = self:set_yaw(yaw)

			-- move towards enemy if beyond mob reach
			if dist > self.reach then

				-- path finding by rnd
				if self.pathfinding -- only if mob has pathfinding enabled
				and enable_pathfinding then

					self:smart_mobs(s, p, dist, dtime)
				end

				if self:is_at_cliff() then

					self:set_velocity(0)
					self:set_animation("stand")
				else

					if self.path.stuck then
						self:set_velocity(self.walk_velocity)
					else
						self:set_velocity(self.run_velocity)
					end

					if self.animation and self.animation.run_start then
						self:set_animation("run")
					else
						self:set_animation("walk")
					end
				end

			else -- rnd: if inside reach range

				self.path.stuck = false
				self.path.stuck_timer = 0
				self.path.following = false -- not stuck anymore

				self:set_velocity(0)

				if not self.custom_attack then

					if self.timer > 1 then

						self.timer = 0

--						if self.double_melee_attack
--						and random(1, 2) == 1 then
--							self:set_animation("punch2")
--						else
							self:set_animation("punch")
--						end

						local p2 = p
						local s2 = s

						p2.y = p2.y + .5
						s2.y = s2.y + .5

						if self:line_of_sight(p2, s2) == true then

							-- play attack sound
							self:mob_sound(self.sounds.attack)

							-- punch player (or what player is attached to)
							local attached = self.attack:get_attach()
							if attached then
								self.attack = attached
							end
							self.attack:punch(self.object, 1.0, {
								full_punch_interval = 1.0,
								damage_groups = {fleshy = self.damage}
							}, nil)
						end
					end
				else	-- call custom attack every second
					if self.custom_attack
					and self.timer > 1 then

						self.timer = 0

						self:custom_attack(p)
					end
				end
			end

		elseif self.attack_type == "shoot"
		or (self.attack_type == "dogshoot" and self:dogswitch(dtime) == 1)
		or (self.attack_type == "dogshoot" and dist > self.reach and self:dogswitch() == 0) then

			p.y = p.y - .5
			s.y = s.y + .5

			local dist = get_distance(p, s)
			local vec = {
				x = p.x - s.x,
				y = p.y - s.y,
				z = p.z - s.z
			}

			yaw = (atan(vec.z / vec.x) + pi / 2) - self.rotate

			if p.x > s.x then yaw = yaw + pi end

			yaw = self:set_yaw(yaw)

			self:set_velocity(0)

			if self.shoot_interval
			and self.timer > self.shoot_interval
			and random(1, 100) <= 60 then

				self.timer = 0
				self:set_animation("shoot")

				-- play shoot attack sound
				self:mob_sound(self.sounds.shoot_attack)

				local p = self.object:get_pos()

				p.y = p.y + (self.collisionbox[2] + self.collisionbox[5]) / 2

				if minetest.registered_entities[self.arrow] then

					local obj = minetest.add_entity(p, self.arrow)
					local ent = obj:get_luaentity()
					local amount = (vec.x * vec.x + vec.y * vec.y + vec.z * vec.z) ^ 0.5
					local v = ent.velocity or 1 -- or set to default

					ent.switch = 1
					ent.owner_id = tostring(self.object) -- add unique owner id to arrow

					 -- offset makes shoot aim accurate
					vec.y = vec.y + self.shoot_offset
					vec.x = vec.x * (v / amount)
					vec.y = vec.y * (v / amount)
					vec.z = vec.z * (v / amount)

					obj:set_velocity(vec)
				end
			end
		end
	end
end


-- falling and fall damage
function mob_class:falling(pos)

	if self.fly or self.disable_falling then
		return
	end

	-- floating in water (or falling)
	local v = self.object:get_velocity()

	if v.y > 0 then

		-- apply gravity when moving up
		self.object:set_acceleration({
			x = 0,
			y = -10,
			z = 0
		})

	elseif v.y <= 0 and v.y > self.fall_speed then

		-- fall downwards at set speed
		self.object:set_acceleration({
			x = 0,
			y = self.fall_speed,
			z = 0
		})
	else
		-- stop accelerating once max fall speed hit
		self.object:set_acceleration({x = 0, y = 0, z = 0})
	end

	-- in water then float up
	if self.standing_in
	and minetest.registered_nodes[self.standing_in].groups.water then

		if self.floats == 1 then

			self.object:set_acceleration({
				x = 0,
				y = -self.fall_speed / (max(1, v.y) ^ 8), -- 8 was 2
				z = 0
			})
		end
	else

		-- fall damage onto solid ground
		if self.fall_damage == 1
		and self.object:get_velocity().y == 0 then

			local d = (self.old_y or 0) - self.object:get_pos().y

			if d > 5 then

				self.health = self.health - floor(d - 5)

				effect(pos, 5, "tnt_smoke.png", 1, 2, 2, nil)

				if self:check_for_death({type = "fall"}) then
					return
				end
			end

			self.old_y = self.object:get_pos().y
		end
	end
end


-- is Took Ranks mod active?
local tr = minetest.get_modpath("toolranks")

-- deal damage and effects when mob punched
function mob_class:on_punch(hitter, tflp, tool_capabilities, dir)

	-- mob health check
	if self.health <= 0 then
		return
	end

	-- custom punch function
	if self.do_punch
	and self:do_punch(hitter, tflp, tool_capabilities, dir) == false then
		return
	end

	-- error checking when mod profiling is enabled
	if not tool_capabilities then
		minetest.log("warning", "[mobs] Mod profiling enabled, damage not enabled")
		return
	end

	-- is mob protected?
	if self.protected and hitter:is_player()
	and minetest.is_protected(self.object:get_pos(), hitter:get_player_name()) then
		minetest.chat_send_player(hitter:get_player_name(), S("Mob has been protected!"))
		return
	end

	local weapon = hitter:get_wielded_item()
	local weapon_def = weapon:get_definition() or {}
	local punch_interval = 1.4

	-- calculate mob damage
	local damage = 0
	local armor = self.object:get_armor_groups() or {}
	local tmp

	-- quick error check incase it ends up 0 (serialize.h check test)
	if tflp == 0 then
		tflp = 0.2
	end

	if use_cmi then
		damage = cmi.calculate_damage(self.object, hitter, tflp, tool_capabilities, dir)
	else

		for group,_ in pairs( (tool_capabilities.damage_groups or {}) ) do

			tmp = tflp / (tool_capabilities.full_punch_interval or 1.4)

			if tmp < 0 then
				tmp = 0.0
			elseif tmp > 1 then
				tmp = 1.0
			end

			damage = damage + (tool_capabilities.damage_groups[group] or 0)
				* tmp * ((armor[group] or 0) / 100.0)
		end
	end

	-- check for tool immunity or special damage
	for n = 1, #self.immune_to do

		if self.immune_to[n][1] == weapon_def.name then

			damage = self.immune_to[n][2] or 0
			break

		-- if "all" then no tool does damage unless it's specified in list
		elseif self.immune_to[n][1] == "all" then
			damage = self.immune_to[n][2] or 0
		end
	end

	-- healing
	if damage <= -1 then
		self.health = self.health - floor(damage)
		return
	end

--	print ("Mob Damage is", damage)

	if use_cmi
	and cmi.notify_punch(self.object, hitter, tflp, tool_capabilities, dir, damage) then
		return
	end

	-- add weapon wear
	punch_interval = tool_capabilities.full_punch_interval or 1.4

	-- toolrank support
	local wear = floor((punch_interval / 75) * 9000)

	if mobs.is_creative(hitter:get_player_name()) then

		if tr then
			wear = 1
		else
			wear = 0
		end
	end

	if tr then
		if weapon_def.original_description then
			toolranks.new_afteruse(weapon, hitter, nil, {wear = wear})
		end
	else
		weapon:add_wear(wear)
	end

	hitter:set_wielded_item(weapon)

	-- only play hit sound and show blood effects if damage is 1 or over
	if damage >= 1 then

		-- weapon sounds
		if weapon_def.sounds then

			local s = random(0, #weapon_def.sounds)

			minetest.sound_play(weapon_def.sounds[s], {
				object = self.object,
				max_hear_distance = 8
			})
		else
			minetest.sound_play("default_punch", {
				object = self.object,
				max_hear_distance = 5
			})
		end

		-- blood_particles
		if not disable_blood and self.blood_amount > 0 then

			local pos = self.object:get_pos()

			pos.y = pos.y + (-self.collisionbox[2] + self.collisionbox[5]) * .5

			-- do we have a single blood texture or multiple?
			if type(self.blood_texture) == "table" then

				local blood = self.blood_texture[random(1, #self.blood_texture)]

				effect(pos, self.blood_amount, blood, nil, nil, 1, nil)
			else
				effect(pos, self.blood_amount, self.blood_texture, nil, nil, 1, nil)
			end
		end

		-- do damage
		self.health = self.health - floor(damage)

		-- exit here if dead, check for tools with fire damage
		local hot = tool_capabilities and tool_capabilities.damage_groups
				and tool_capabilities.damage_groups.fire

		if self:check_for_death({type = "punch",
				puncher = hitter, hot = hot}) then
			return
		end

		--[[ add healthy afterglow when hit (can cause hit lag with larger textures)
		minetest.after(0.1, function()

			if not self.object:get_luaentity() then return end

			self.object:settexturemod("^[colorize:#c9900070")

			core.after(0.3, function()
				self.object:settexturemod("")
			end)
		end) ]]

	end -- END if damage

	-- knock back effect (only on full punch)
	if self.knock_back
	and tflp >= punch_interval then

		local v = self.object:get_velocity()
		local kb = damage or 1
		local up = 2

		-- if already in air then dont go up anymore when hit
		if v.y > 0
		or self.fly then
			up = 0
		end

		-- direction error check
		dir = dir or {x = 0, y = 0, z = 0}

		-- use tool knockback value or default
		kb = tool_capabilities.damage_groups["knockback"] or kb -- (kb * 1.5)

		self.object:set_velocity({
			x = dir.x * kb,
			y = up,
			z = dir.z * kb
		})

		self.pause_timer = 0.25
	end

	-- if skittish then run away
	if self.runaway == true
	and self.order ~= "stand" then

		local lp = hitter:get_pos()
		local s = self.object:get_pos()
		local vec = {
			x = lp.x - s.x,
			y = lp.y - s.y,
			z = lp.z - s.z
		}

		local yaw = (atan(vec.z / vec.x) + 3 * pi / 2) - self.rotate

		if lp.x > s.x then
			yaw = yaw + pi
		end

		yaw = self:set_yaw(yaw, 6)
		self.state = "runaway"
		self.runaway_timer = 0
		self.following = nil
	end

	local name = hitter:get_player_name() or ""

	-- attack puncher and call other mobs for help
	if self.passive == false
	and self.state ~= "flop"
	and self.child == false
	and self.attack_players == true
	and hitter:get_player_name() ~= self.owner
	and not mobs.invis[ name ] then

		-- attack whoever punched mob
		self.state = ""
		self:do_attack(hitter)

		-- alert others to the attack
		local objs = minetest.get_objects_inside_radius(hitter:get_pos(), self.view_range)
		local obj = nil

		for n = 1, #objs do

			obj = objs[n]:get_luaentity()

			if obj and obj._cmi_is_mob then

				-- only alert members of same mob
				if obj.group_attack == true
				and obj.state ~= "attack"
				and obj.owner ~= name
				and obj.name == self.name then
					obj:do_attack(hitter)
				end

				-- have owned mobs attack player threat
				if obj.owner == name and obj.owner_loyal then
					obj:do_attack(self.object)
				end
			end
		end
	end
end


-- get entity staticdata
function mob_class:get_staticdata()

	-- remove mob when out of range unless tamed
	if remove_far
	and self.remove_ok
	and self.type ~= "npc"
	and self.state ~= "attack"
	and not self.tamed
	and self.lifetimer < 20000 then

		--print ("REMOVED " .. self.name)

		self.object:remove()

		return ""-- nil
	end

	self.remove_ok = true
	self.attack = nil
	self.following = nil
	self.state = "stand"

	-- used to rotate older mobs
	if self.drawtype
	and self.drawtype == "side" then
		self.rotate = math.rad(90)
	end

	if use_cmi then
		self.serialized_cmi_components = cmi.serialize_components(self._cmi_components)
	end

	local tmp = {}

	for _,stat in pairs(self) do

		local t = type(stat)

		if  t ~= "function"
		and t ~= "nil"
		and t ~= "userdata"
		and _ ~= "_cmi_components" then
			tmp[_] = self[_]
		end
	end

	--print('===== '..self.name..'\n'.. dump(tmp)..'\n=====\n')
	return minetest.serialize(tmp)
end


-- activate mob and reload settings
function mob_class:mob_activate(staticdata, def, dtime)

	-- remove monsters in peaceful mode
	if self.type == "monster"
	and peaceful_only then

		self.object:remove()

		return
	end

	-- load entity variables
	local tmp = minetest.deserialize(staticdata)

	if tmp then
		for _,stat in pairs(tmp) do
			self[_] = stat
		end
	end

	-- force current model into mob
	self.mesh = def.mesh
	self.base_mesh = def.mesh
	self.collisionbox = def.collisionbox
	self.selectionbox = def.selectionbox

	-- select random texture, set model and size
	if not self.base_texture then

		-- compatiblity with old simple mobs textures
		if def.textures and type(def.textures[1]) == "string" then
			def.textures = {def.textures}
		end

		self.base_texture = def.textures and def.textures[random(1, #def.textures)]
		self.base_mesh = def.mesh
		self.base_size = self.visual_size
		self.base_colbox = self.collisionbox
		self.base_selbox = self.selectionbox
	end

	-- for current mobs that dont have this set
	if not self.base_selbox then
		self.base_selbox = self.selectionbox or self.base_colbox
	end

	-- set texture, model and size
	local textures = self.base_texture
	local mesh = self.base_mesh
	local vis_size = self.base_size
	local colbox = self.base_colbox
	local selbox = self.base_selbox

	-- specific texture if gotten
	if self.gotten == true
	and def.gotten_texture then
		textures = def.gotten_texture
	end

	-- specific mesh if gotten
	if self.gotten == true
	and def.gotten_mesh then
		mesh = def.gotten_mesh
	end

	-- set child objects to half size
	if self.child == true then

		vis_size = {
			x = self.base_size.x * .5,
			y = self.base_size.y * .5,
		}

		if def.child_texture then
			textures = def.child_texture[1]
		end

		colbox = {
			self.base_colbox[1] * .5,
			self.base_colbox[2] * .5,
			self.base_colbox[3] * .5,
			self.base_colbox[4] * .5,
			self.base_colbox[5] * .5,
			self.base_colbox[6] * .5
		}
		selbox = {
			self.base_selbox[1] * .5,
			self.base_selbox[2] * .5,
			self.base_selbox[3] * .5,
			self.base_selbox[4] * .5,
			self.base_selbox[5] * .5,
			self.base_selbox[6] * .5
		}
	end

	if self.health == 0 then
		self.health = random(self.hp_min, self.hp_max)
	end

	-- pathfinding init
	self.path = {}
	self.path.way = {} -- path to follow, table of positions
	self.path.lastpos = {x = 0, y = 0, z = 0}
	self.path.stuck = false
	self.path.following = false -- currently following path?
	self.path.stuck_timer = 0 -- if stuck for too long search for path

	-- mob defaults
	self.object:set_armor_groups({immortal = 1, fleshy = self.armor})
	self.old_y = self.object:get_pos().y
	self.old_health = self.health
	self.sounds.distance = self.sounds.distance or 10
	self.textures = textures
	self.mesh = mesh
	self.collisionbox = colbox
	self.selectionbox = selbox
	self.visual_size = vis_size
	self.standing_in = "air"

	-- check existing nametag
	if not self.nametag then
		self.nametag = def.nametag
	end

	-- set anything changed above
	self.object:set_properties(self)
	self:set_yaw((random(0, 360) - 180) / 180 * pi, 6)
	self:update_tag()
	self:set_animation("stand")

	-- run on_spawn function if found
	if self.on_spawn and not self.on_spawn_run then
		if self.on_spawn(self) then
			self.on_spawn_run = true --  if true, set flag to run once only
		end
	end

	-- run after_activate
	if def.after_activate then
		def.after_activate(self, staticdata, def, dtime)
	end

	if use_cmi then
		self._cmi_components = cmi.activate_components(self.serialized_cmi_components)
		cmi.notify_activate(self.object, dtime)
	end
end


-- handle mob lifetimer and expiration
function mob_class:mob_expire(pos, dtime)

	-- when lifetimer expires remove mob (except npc and tamed)
	if self.type ~= "npc"
	and not self.tamed
	and self.state ~= "attack"
	and remove_far ~= true
	and self.lifetimer < 20000 then

		self.lifetimer = self.lifetimer - dtime

		if self.lifetimer <= 0 then

			-- only despawn away from player
			local objs = minetest.get_objects_inside_radius(pos, 15)

			for n = 1, #objs do

				if objs[n]:is_player() then

					self.lifetimer = 20

					return
				end
			end

--			minetest.log("action",
--				S("lifetimer expired, removed @1", self.name))

			effect(pos, 15, "tnt_smoke.png", 2, 4, 2, 0)

			self.object:remove()

			return
		end
	end
end


-- main mob function
function mob_class:on_step(dtime)

	if use_cmi then
		cmi.notify_step(self.object, dtime)
	end

	local pos = self.object:get_pos()
	local yaw = 0

	-- get node at foot level every quarter second
	self.node_timer = (self.node_timer or 0) + dtime

	if self.node_timer > 0.25 then

		self.node_timer = 0

		local y_level = self.collisionbox[2]

		if self.child then
			y_level = self.collisionbox[2] * 0.5
		end

		-- what is mob standing in?
		self.standing_in = node_ok({
			x = pos.x, y = pos.y + y_level + 0.25, z = pos.z}, "air").name
--		print ("standing in " .. self.standing_in)

		-- check for mob expiration (0.25 instead of dtime since were in a timer)
		self:mob_expire(pos, 0.25)
	end

	-- check if falling, flying, floating
	self:falling(pos)

	-- smooth rotation by ThomasMonroe314

	if self.delay and self.delay > 0 then

		local yaw = self.object:get_yaw()

		if self.delay == 1 then
			yaw = self.target_yaw
		else
			local dif = abs(yaw - self.target_yaw)

			if yaw > self.target_yaw then

				if dif > pi then
					dif = 2 * pi - dif -- need to add
					yaw = yaw + dif / self.delay
				else
					yaw = yaw - dif / self.delay -- need to subtract
				end

			elseif yaw < self.target_yaw then

				if dif > pi then
					dif = 2 * pi - dif
					yaw = yaw - dif / self.delay -- need to subtract
				else
					yaw = yaw + dif / self.delay -- need to add
				end
			end

			if yaw > (pi * 2) then yaw = yaw - (pi * 2) end
			if yaw < 0 then yaw = yaw + (pi * 2) end
		end

		self.delay = self.delay - 1
		self.object:set_yaw(yaw)
	end

	-- end rotation

	-- knockback timer
	if self.pause_timer > 0 then

		self.pause_timer = self.pause_timer - dtime

		return
	end

	-- run custom function (defined in mob lua file)
	if self.do_custom then

		-- when false skip going any further
		if self:do_custom(dtime) == false then
			return
		end
	end

	-- attack timer
	self.timer = self.timer + dtime

	if self.state ~= "attack" then

		if self.timer < 1 then
			return
		end

		self.timer = 0
	end

	-- never go over 100
	if self.timer > 100 then
		self.timer = 1
	end

	-- mob plays random sound at times
	if random(1, 100) == 1 then
		self:mob_sound(self.sounds.random)
	end

	-- environmental damage timer (every 1 second)
	self.env_damage_timer = self.env_damage_timer + dtime

	if (self.state == "attack" and self.env_damage_timer > 1)
	or self.state ~= "attack" then

		self.env_damage_timer = 0

		-- check for environmental damage (water, fire, lava etc.)
		self:do_env_damage()

		-- node replace check (cow eats grass etc.)
		self:replace(pos)
	end

	self:general_attack()

	self:breed()

	self:follow_flop()

	self:do_states(dtime)

	self:do_jump()

	self:do_runaway_from(self)

	self:do_stay_near()
end


-- default function when mobs are blown up with TNT
function mob_class:on_blast(damage)

	--print ("----- Damage", damage)

	self.object:punch(self.object, 1.0, {
		full_punch_interval = 1.0,
		damage_groups = {fleshy = damage},
	}, nil)

	return false, true, {}
end


mobs.spawning_mobs = {}

-- register mob entity
function mobs:register_mob(name, def)

	mobs.spawning_mobs[name] = true

minetest.register_entity(name, setmetatable({

	stepheight = def.stepheight,
	name = name,
	type = def.type,
	attack_type = def.attack_type,
	fly = def.fly,
	fly_in = def.fly_in,
	owner = def.owner,
	order = def.order,
	on_die = def.on_die,
	do_custom = def.do_custom,
	jump_height = def.jump_height,
	drawtype = def.drawtype, -- DEPRECATED, use rotate instead
	rotate = math.rad(def.rotate or 0), --  0=front, 90=side, 180=back, 270=side2
	lifetimer = def.lifetimer,
	hp_min = max(1, (def.hp_min or 5) * difficulty),
	hp_max = max(1, (def.hp_max or 10) * difficulty),
	collisionbox = def.collisionbox,
	selectionbox = def.selectionbox or def.collisionbox,
	visual = def.visual,
	visual_size = def.visual_size,
	mesh = def.mesh,
	makes_footstep_sound = def.makes_footstep_sound,
	view_range = def.view_range,
	walk_velocity = def.walk_velocity,
	run_velocity = def.run_velocity,
	damage = max(0, (def.damage or 0) * difficulty),
	light_damage = def.light_damage,
	light_damage_min = def.light_damage_min,
	light_damage_max = def.light_damage_max,
	water_damage = def.water_damage,
	lava_damage = def.lava_damage,
	suffocation = def.suffocation,
	fall_damage = def.fall_damage,
	fall_speed = def.fall_speed,
	drops = def.drops,
	armor = def.armor,
	on_rightclick = def.on_rightclick,
	arrow = def.arrow,
	shoot_interval = def.shoot_interval,
	sounds = def.sounds,
	animation = def.animation,
	follow = def.follow,
	jump = def.jump,
	walk_chance = def.walk_chance,
	stand_chance = def.stand_chance,
	attack_chance = def.attack_chance,
	passive = def.passive,
	knock_back = def.knock_back,
	blood_amount = def.blood_amount,
	blood_texture = def.blood_texture,
	shoot_offset = def.shoot_offset,
	floats = def.floats,
	replace_rate = def.replace_rate,
	replace_what = def.replace_what,
	replace_with = def.replace_with,
	replace_offset = def.replace_offset,
	on_replace = def.on_replace,
	reach = def.reach,
	texture_list = def.textures,
	child_texture = def.child_texture,
	docile_by_day = def.docile_by_day,
	fear_height = def.fear_height,
	runaway = def.runaway,
	pathfinding = def.pathfinding,
	immune_to = def.immune_to,
	explosion_radius = def.explosion_radius,
	explosion_damage_radius = def.explosion_damage_radius,
	explosion_timer = def.explosion_timer,
	allow_fuse_reset = def.allow_fuse_reset,
	stop_to_explode = def.stop_to_explode,
	custom_attack = def.custom_attack,
	double_melee_attack = def.double_melee_attack,
	dogshoot_switch = def.dogshoot_switch,
	dogshoot_count_max = def.dogshoot_count_max,
	dogshoot_count2_max = def.dogshoot_count2_max or def.dogshoot_count_max,
	group_attack = def.group_attack,
	attack_monsters = def.attacks_monsters or def.attack_monsters,
	attack_animals = def.attack_animals,
	attack_players = def.attack_players,
	attack_npcs = def.attack_npcs,
	specific_attack = def.specific_attack,
	runaway_from = def.runaway_from,
	owner_loyal = def.owner_loyal,
	pushable = def.pushable,
	stay_near = def.stay_near,

	on_spawn = def.on_spawn,

	on_blast = def.on_blast, -- class redifinition

	do_punch = def.do_punch,

	on_breed = def.on_breed,

	on_grown = def.on_grown,

	on_activate = function(self, staticdata, dtime)
		return self:mob_activate(staticdata, def, dtime)
	end,

}, mob_class_meta))

end -- END mobs:register_mob function


-- count how many mobs of one type are inside an area
-- will also return true for second value if player is inside area
local count_mobs = function(pos, type)

	local total = 0
	local objs = minetest.get_objects_inside_radius(pos, aoc_range * 2)
	local ent
	local players

	for n = 1, #objs do

		if not objs[n]:is_player() then

			ent = objs[n]:get_luaentity()

			-- count mob type and add to total also
			if ent and ent.name and ent.name == type then
				total = total + 1
			end
		else
			players = true
		end
	end

	return total, players
end


-- global functions

function mobs:spawn_abm_check(pos, node, name)
	-- global function to add additional spawn checks
	-- return true to stop spawning mob
end


function mobs:spawn_specific(name, nodes, neighbors, min_light, max_light,
	interval, chance, aoc, min_height, max_height, day_toggle, on_spawn)

	-- Do mobs spawn at all?
	if not mobs_spawn then
		return
	end

	-- chance/spawn number override in minetest.conf for registered mob
	local numbers = minetest.settings:get(name)

	if numbers then
		numbers = numbers:split(",")
		chance = tonumber(numbers[1]) or chance
		aoc = tonumber(numbers[2]) or aoc

		if chance == 0 then
			minetest.log("warning", string.format("[mobs] %s has spawning disabled", name))
			return
		end

		minetest.log("action",
			string.format("[mobs] Chance setting for %s changed to %s (total: %s)",
				name, chance, aoc))

	end

	minetest.register_abm({

		label = name .. " spawning",
		nodenames = nodes,
		neighbors = neighbors,
		interval = interval,
		chance = max(1, (chance * mob_chance_multiplier)),
		catch_up = false,

		action = function(pos, node, active_object_count, active_object_count_wider)

			-- is mob actually registered?
			if not mobs.spawning_mobs[name]
			or not minetest.registered_entities[name] then
--print ("--- mob doesn't exist", name)
				return
			end

			-- additional custom checks for spawning mob
			if mobs:spawn_abm_check(pos, node, name) == true then
				return
			end

			-- do not spawn if too many entities in area
			if active_object_count_wider >= max_per_block then
--print("--- too many entities in area", active_object_count_wider)
				return
			end

			-- get total number of this mob in area
			local num_mob, is_pla = count_mobs(pos, name)

			if not is_pla then
--print ("--- no players within active area, will not spawn " .. name)
				return
			end

			if num_mob >= aoc then
--print ("--- too many " .. name .. " in area", num_mob .. "/" .. aoc)
				return
			end

			-- if toggle set to nil then ignore day/night check
			if day_toggle ~= nil then

				local tod = (minetest.get_timeofday() or 0) * 24000

				if tod > 4500 and tod < 19500 then
					-- daylight, but mob wants night
					if day_toggle == false then
--print ("--- mob needs night", name)
						return
					end
				else
					-- night time but mob wants day
					if day_toggle == true then
--print ("--- mob needs day", name)
						return
					end
				end
			end

			-- spawn above node
			pos.y = pos.y + 1

			-- are we spawning within height limits?
			if pos.y > max_height
			or pos.y < min_height then
--print ("--- height limits not met", name, pos.y)
				return
			end

			-- are light levels ok?
			local light = minetest.get_node_light(pos)
			if not light
			or light > max_light
			or light < min_light then
--print ("--- light limits not met", name, light)
				return
			end

			-- only spawn away from player
			local objs = minetest.get_objects_inside_radius(pos, 8)

			for n = 1, #objs do

				if objs[n]:is_player() then
--print ("--- player too close", name)
					return
				end
			end

			-- do we have enough height clearance to spawn mob?
			local ent = minetest.registered_entities[name]
			local height = max(1, math.ceil(
				(ent.collisionbox[5] or 0.25) -
				(ent.collisionbox[2] or -0.25) - 1))

			for n = 0, height do

				local pos2 = {x = pos.x, y = pos.y + n, z = pos.z}

				if minetest.registered_nodes[node_ok(pos2).name].walkable == true then
--print ("--- inside block", name, node_ok(pos2).name)
					return
				end
			end

			-- mobs cannot spawn in protected areas when enabled
			if not spawn_protected
			and minetest.is_protected(pos, "") then
--print ("--- inside protected area", name)
				return
			end

			-- spawn mob half block higher than ground
			pos.y = pos.y + 0.5

			local mob = minetest.add_entity(pos, name)
--[[
			print ("[mobs] Spawned " .. name .. " at "
			.. minetest.pos_to_string(pos) .. " on "
			.. node.name .. " near " .. neighbors[1])
]]
			if on_spawn then

				local ent = mob:get_luaentity()

				on_spawn(ent, pos)
			end
		end
	})
end


-- compatibility with older mob registration
function mobs:register_spawn(name, nodes, max_light, min_light, chance,
		active_object_count, max_height, day_toggle)

	mobs:spawn_specific(name, nodes, {"air"}, min_light, max_light, 30,
		chance, active_object_count, -31000, max_height, day_toggle)
end


-- MarkBu's spawn function
function mobs:spawn(def)

	mobs:spawn_specific(
		def.name,
		def.nodes or {"group:soil", "group:stone"},
		def.neighbors or {"air"},
		def.min_light or 0,
		def.max_light or 15,
		def.interval or 30,
		def.chance or 5000,
		def.active_object_count or 1,
		def.min_height or -31000,
		def.max_height or 31000,
		def.day_toggle,
		def.on_spawn
	)
end


-- register arrow for shoot attack
function mobs:register_arrow(name, def)

	if not name or not def then return end -- errorcheck

	minetest.register_entity(name, {

		physical = false,
		visual = def.visual,
		visual_size = def.visual_size,
		textures = def.textures,
		velocity = def.velocity,
		hit_player = def.hit_player,
		hit_node = def.hit_node,
		hit_mob = def.hit_mob,
		drop = def.drop or false, -- drops arrow as registered item when true
		collisionbox = def.collisionbox or {0, 0, 0, 0, 0, 0},
		timer = 0,
		switch = 0,
		owner_id = def.owner_id,
		rotate = def.rotate,
		automatic_face_movement_dir = def.rotate
			and (def.rotate - (pi / 180)) or false,

		on_activate = def.on_activate,

		on_punch = def.on_punch or function(self, hitter, tflp, tool_capabilities, dir)
		end,

		on_step = def.on_step or function(self, dtime)

			self.timer = self.timer + 1

			local pos = self.object:get_pos()

			if self.switch == 0
			or self.timer > 150 then

				self.object:remove() ; -- print ("removed arrow")

				return
			end

			-- does arrow have a tail (fireball)
			if def.tail
			and def.tail == 1
			and def.tail_texture then

				minetest.add_particle({
					pos = pos,
					velocity = {x = 0, y = 0, z = 0},
					acceleration = {x = 0, y = 0, z = 0},
					expirationtime = def.expire or 0.25,
					collisiondetection = false,
					texture = def.tail_texture,
					size = def.tail_size or 5,
					glow = def.glow or 0,
				})
			end

			if self.hit_node then

				local node = node_ok(pos).name

				if minetest.registered_nodes[node].walkable then

					self:hit_node(pos, node)

					if self.drop == true then

						pos.y = pos.y + 1

						self.lastpos = (self.lastpos or pos)

						minetest.add_item(self.lastpos, self.object:get_luaentity().name)
					end

					self.object:remove() ; -- print ("hit node")

					return
				end
			end

			if self.hit_player or self.hit_mob then

				for _,player in pairs(minetest.get_objects_inside_radius(pos, 1.0)) do

					if self.hit_player
					and player:is_player() then

						self:hit_player(player)
						self.object:remove() ; -- print ("hit player")
						return
					end

					local entity = player:get_luaentity()

					if entity
					and self.hit_mob
					and entity._cmi_is_mob == true
					and tostring(player) ~= self.owner_id
					and entity.name ~= self.object:get_luaentity().name then

						self:hit_mob(player)

						self.object:remove() ;  --print ("hit mob")

						return
					end
				end
			end

			self.lastpos = pos
		end
	})
end


-- compatibility function
function mobs:explosion(pos, radius)

	local self = {sounds = {explode = "tnt_explode"}}

	mobs:boom(self, pos, radius)
end


-- no damage to nodes explosion
function mobs:safe_boom(self, pos, radius)

	minetest.sound_play(self.sounds and self.sounds.explode or "tnt_explode", {
		pos = pos,
		gain = 1.0,
		max_hear_distance = self.sounds and self.sounds.distance or 32
	})

	entity_physics(pos, radius)

	effect(pos, 32, "tnt_smoke.png", radius * 3, radius * 5, radius, 1, 0)
end


-- make explosion with protection and tnt mod check
function mobs:boom(self, pos, radius)

	if mobs_griefing
	and minetest.get_modpath("tnt") and tnt and tnt.boom
	and not minetest.is_protected(pos, "") then

		tnt.boom(pos, {
			radius = radius,
			damage_radius = radius,
			sound = self.sounds and self.sounds.explode,
			explode_center = true,
		})
	else
		mobs:safe_boom(self, pos, radius)
	end
end


-- Register spawn eggs

-- Note: This also introduces the “spawn_egg” group:
-- * spawn_egg=1: Spawn egg (generic mob, no metadata)
-- * spawn_egg=2: Spawn egg (captured/tamed mob, metadata)
function mobs:register_egg(mob, desc, background, addegg, no_creative)

	local grp = {spawn_egg = 1}

	-- do NOT add this egg to creative inventory (e.g. dungeon master)
	if creative and no_creative == true then
		grp.not_in_creative_inventory = 1
	end

	local invimg = background

	if addegg == 1 then
		invimg = "mobs_chicken_egg.png^(" .. invimg ..
			"^[mask:mobs_chicken_egg_overlay.png)"
	end

	-- register new spawn egg containing mob information
	minetest.register_craftitem(mob .. "_set", {

		description = S("@1 (Tamed)", desc),
		inventory_image = invimg,
		groups = {spawn_egg = 2, not_in_creative_inventory = 1},
		stack_max = 1,

		on_place = function(itemstack, placer, pointed_thing)

			local pos = pointed_thing.above

			-- am I clicking on something with existing on_rightclick function?
			local under = minetest.get_node(pointed_thing.under)
			local def = minetest.registered_nodes[under.name]
			if def and def.on_rightclick then
				return def.on_rightclick(pointed_thing.under, under, placer, itemstack)
			end

			if pos
			and not minetest.is_protected(pos, placer:get_player_name()) then

				if not minetest.registered_entities[mob] then
					return
				end

				pos.y = pos.y + 1

				local data = itemstack:get_metadata()
				local mob = minetest.add_entity(pos, mob, data)
				local ent = mob:get_luaentity()

				-- set owner if not a monster
				if ent.type ~= "monster" then
					ent.owner = placer:get_player_name()
					ent.tamed = true
				end

				-- since mob is unique we remove egg once spawned
				itemstack:take_item()
			end

			return itemstack
		end,
	})


	-- register old stackable mob egg
	minetest.register_craftitem(mob, {

		description = desc,
		inventory_image = invimg,
		groups = grp,

		on_place = function(itemstack, placer, pointed_thing)

			local pos = pointed_thing.above

			-- am I clicking on something with existing on_rightclick function?
			local under = minetest.get_node(pointed_thing.under)
			local def = minetest.registered_nodes[under.name]
			if def and def.on_rightclick then
				return def.on_rightclick(pointed_thing.under, under, placer, itemstack)
			end

			if pos
			and not minetest.is_protected(pos, placer:get_player_name()) then

				if not minetest.registered_entities[mob] then
					return
				end

				pos.y = pos.y + 1

				local mob = minetest.add_entity(pos, mob)
				local ent = mob:get_luaentity()

				-- don't set owner if monster or sneak pressed
				if ent.type ~= "monster"
				and not placer:get_player_control().sneak then
					ent.owner = placer:get_player_name()
					ent.tamed = true
				end

				-- if not in creative then take item
				if not mobs.is_creative(placer:get_player_name()) then
					itemstack:take_item()
				end
			end

			return itemstack
		end,
	})

end


-- force capture a mob if space available in inventory, or drop as spawn egg
function mobs:force_capture(self, clicker)

	-- add special mob egg with all mob information
	local new_stack = ItemStack(self.name .. "_set")

	local tmp = {}

	for _,stat in pairs(self) do
		local t = type(stat)
		if  t ~= "function"
		and t ~= "nil"
		and t ~= "userdata" then
			tmp[_] = self[_]
		end
	end

	local data_str = minetest.serialize(tmp)

	new_stack:set_metadata(data_str)

	local inv = clicker:get_inventory()

	if inv:room_for_item("main", new_stack) then
		inv:add_item("main", new_stack)
	else
		minetest.add_item(clicker:get_pos(), new_stack)
	end

	self.object:remove()

	self:mob_sound("default_place_node_hard")
end


-- capture critter (thanks to blert2112 for idea)
function mobs:capture_mob(self, clicker, chance_hand, chance_net, chance_lasso,
		force_take, replacewith)

	if self.child
	or not clicker:is_player()
	or not clicker:get_inventory() then
		return false
	end

	-- get name of clicked mob
	local mobname = self.name

	-- if not nil change what will be added to inventory
	if replacewith then
		mobname = replacewith
	end

	local name = clicker:get_player_name()
	local tool = clicker:get_wielded_item()

	-- are we using hand, net or lasso to pick up mob?
	if tool:get_name() ~= ""
	and tool:get_name() ~= "mobs:net"
	and tool:get_name() ~= "mobs:lasso" then
		return false
	end

	-- is mob tamed?
	if self.tamed == false
	and force_take == false then

		minetest.chat_send_player(name, S("Not tamed!"))

		return false
	end

	-- cannot pick up if not owner
	if self.owner ~= name
	and force_take == false then

		minetest.chat_send_player(name, S("@1 is owner!", self.owner))

		return false
	end

	if clicker:get_inventory():room_for_item("main", mobname) then

		-- was mob clicked with hand, net, or lasso?
		local chance = 0

		if tool:get_name() == "" then
			chance = chance_hand

		elseif tool:get_name() == "mobs:net" then

			chance = chance_net

			tool:add_wear(4000) -- 17 uses

			clicker:set_wielded_item(tool)

		elseif tool:get_name() == "mobs:lasso" then

			chance = chance_lasso

			tool:add_wear(650) -- 100 uses

			clicker:set_wielded_item(tool)

		end

		-- calculate chance.. add to inventory if successful?
		if chance and chance > 0 and random(1, 100) <= chance then

			-- default mob egg
			local new_stack = ItemStack(mobname)

			-- add special mob egg with all mob information
			-- unless 'replacewith' contains new item to use
			if not replacewith then

				new_stack = ItemStack(mobname .. "_set")

				local tmp = {}

				for _,stat in pairs(self) do
					local t = type(stat)
					if  t ~= "function"
					and t ~= "nil"
					and t ~= "userdata" then
						tmp[_] = self[_]
					end
				end

				local data_str = minetest.serialize(tmp)

				new_stack:set_metadata(data_str)
			end

			local inv = clicker:get_inventory()

			if inv:room_for_item("main", new_stack) then
				inv:add_item("main", new_stack)
			else
				minetest.add_item(clicker:get_pos(), new_stack)
			end

			self.object:remove()

			self:mob_sound("default_place_node_hard")

			return new_stack

		-- when chance above fails or set to 0, miss!
		elseif chance and chance ~= 0 then
			minetest.chat_send_player(name, S("Missed!"))

			self:mob_sound("mobs_swing")
			return false

		-- when chance set to nil always return a miss (used for npc walk/follow)
		elseif not chance then
			return false
		end
	end

	return true
end


-- protect tamed mob with rune item
function mobs:protect(self, clicker)

	local name = clicker:get_player_name()
	local tool = clicker:get_wielded_item()

	if tool:get_name() ~= "mobs:protector" then
		return false
	end

	if self.tamed == false then
		minetest.chat_send_player(name, S("Not tamed!"))
		return true -- false
	end

	if self.protected == true then
		minetest.chat_send_player(name, S("Already protected!"))
		return true -- false
	end

	if not mobs.is_creative(clicker:get_player_name()) then
		tool:take_item() -- take 1 protection rune
		clicker:set_wielded_item(tool)
	end

	self.protected = true

	local pos = self.object:get_pos()
	pos.y = pos.y + self.collisionbox[2] + 0.5

	effect(self.object:get_pos(), 25, "mobs_protect_particle.png", 0.5, 4, 2, 15)

	self:mob_sound("mobs_spell")

	return true
end


local mob_obj = {}
local mob_sta = {}

-- feeding, taming and breeding (thanks blert2112)
function mobs:feed_tame(self, clicker, feed_count, breed, tame)

	-- can eat/tame with item in hand
	if self.follow
	and self:follow_holding(clicker) then

		-- if not in creative then take item
		if not mobs.is_creative(clicker:get_player_name()) then

			local item = clicker:get_wielded_item()

			item:take_item()

			clicker:set_wielded_item(item)
		end

		-- increase health
		self.health = self.health + 4

		if self.health >= self.hp_max then

			self.health = self.hp_max

			if self.htimer < 1 then

				minetest.chat_send_player(clicker:get_player_name(),
					S("@1 at full health (@2)",
					self.name:split(":")[2], tostring(self.health)))

				self.htimer = 5
			end
		end

		self.object:set_hp(self.health)

		self:update_tag()

		-- make children grow quicker
		if self.child == true then

			self.hornytimer = self.hornytimer + 20

			return true
		end

		-- feed and tame
		self.food = (self.food or 0) + 1

		if self.food >= feed_count then

			self.food = 0

			if breed and self.hornytimer == 0 then
				self.horny = true
			end

			if tame then

				if self.tamed == false then
					minetest.chat_send_player(clicker:get_player_name(),
						S("@1 has been tamed!",
						self.name:split(":")[2]))
				end

				self.tamed = true

				if not self.owner or self.owner == "" then
					self.owner = clicker:get_player_name()
				end
			end

			-- make sound when fed so many times
			self:mob_sound(self.sounds.random)
		end

		return true
	end

	local item = clicker:get_wielded_item()

	-- if mob has been tamed you can name it with a nametag
	if item:get_name() == "mobs:nametag"
	and clicker:get_player_name() == self.owner then

		local name = clicker:get_player_name()

		-- store mob and nametag stack in external variables
		mob_obj[name] = self
		mob_sta[name] = item

		local tag = self.nametag or ""

		minetest.show_formspec(name, "mobs_nametag", "size[8,4]"
			.. default.gui_bg
			.. default.gui_bg_img
			.. "field[0.5,1;7.5,0;name;"
			.. minetest.formspec_escape(S("Enter name:")) .. ";" .. tag .. "]"
			.. "button_exit[2.5,3.5;3,1;mob_rename;"
			.. minetest.formspec_escape(S("Rename")) .. "]")
	end

	return false
end


-- inspired by blockmen's nametag mod
minetest.register_on_player_receive_fields(function(player, formname, fields)

	-- right-clicked with nametag and name entered?
	if formname == "mobs_nametag"
	and fields.name
	and fields.name ~= "" then

		local name = player:get_player_name()

		if not mob_obj[name]
		or not mob_obj[name].object then
			return
		end

		-- make sure nametag is being used to name mob
		local item = player:get_wielded_item()

		if item:get_name() ~= "mobs:nametag" then
			return
		end

		-- limit name entered to 64 characters long
		if string.len(fields.name) > 64 then
			fields.name = string.sub(fields.name, 1, 64)
		end

		-- update nametag
		mob_obj[name].nametag = fields.name

		mob_obj[name]:update_tag()

		-- if not in creative then take item
		if not mobs.is_creative(name) then

			mob_sta[name]:take_item()

			player:set_wielded_item(mob_sta[name])
		end

		-- reset external variables
		mob_obj[name] = nil
		mob_sta[name] = nil
	end
end)


-- compatibility function for old entities to new modpack entities
function mobs:alias_mob(old_name, new_name)

	-- spawn egg
	minetest.register_alias(old_name, new_name)

	-- entity
	minetest.register_entity(":" .. old_name, {

		physical = false,

		on_activate = function(self)

			if minetest.registered_entities[new_name] then
				minetest.add_entity(self.object:get_pos(), new_name)
			end

			self.object:remove()
		end
	})
end
