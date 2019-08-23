
local emerge_with_callbacks = dofile(minetest.get_modpath("xschem") .. "/emerge.lua")

function xschem.save(pname, filepath, from, to)
	local function notice(msg)
		if pname then
			minetest.chat_send_player(pname, "-!- " .. msg)
		end
	end

	notice("[Step 1/3] Emerging area")

	emerge_with_callbacks(from, to, function()
		notice("[Step 2/3] Saving area as schematic")
		minetest.create_schematic(from, to, nil, filepath .. ".mts", nil)


		notice("[Step 3/3] Saving meta data")
		do
			local meta = {}
			xschem.fetch_metadata(meta, from, to)

			local file = io.open(filepath .. ".meta", "w")
			file:write(minetest.write_json(meta))
			file:close()
		end

		notice("Done!")
	end)
end

local WHITELIST = {}
function xschem.whitelist(name)
	WHITELIST[minetest.get_content_id(name)] = true
end

function xschem.fetch_metadata(metalist, pos1, pos2)
	-- Read data into LVM
	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(pos1, pos2)
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	local data = vm:get_data()

	-- Scan for whitelisted nodes
	for z = pos1.z, pos2.z do
		for y = pos1.y, pos2.y do
			for x = pos1.x, pos2.x do
				local vi = a:index(x, y, z)
				if WHITELIST[data[vi]] then
					local pos = { x = x, y = y, z = z }
					local meta = minetest.get_meta(pos)
					if meta then
						meta = meta:to_table()
						meta.pos = pos

						if meta.inventory then
							for listname, list in pairs(meta.inventory) do
								for i=1, #list do
									list[i] = list[i]:to_string()
								end
							end
						end

						if next(meta.fields) or (meta.inventory and next(meta.inventory)) then
							metalist[#metalist + 1] = meta
						end
					end
				end
			end
		end
	end
end

function xschem.place_metadata(metalist, pos1, pos2)
	for i=1, #metalist do
		local point = metalist[i].pos
		if point.x >= pos1.x and point.x <= pos2.x and
				point.y >= pos1.y and point.y <= pos2.y and
				point.z >= pos1.z and point.z <= pos2.z then
			local meta = minetest.get_meta(point)
			meta:from_table(metalist[i])
		end
	end
end

function xschem.load_area(from, to, cb)
	minetest.after(0, function()
		local before = minetest.get_us_time()
		emerge_with_callbacks(from, to, function()
			local after_generation = minetest.get_us_time()
			minetest.fix_light(from, to)
			local after_lighting = minetest.get_us_time()

			local duration_gen = (after_generation - before) * 0.000001
			local duration_lighting = (after_lighting - after_generation) * 0.000001

			cb(duration_gen, duration_lighting)
		end)
	end)
end
