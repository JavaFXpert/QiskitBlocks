
local path = minetest.get_modpath("mobs_npc")

-- Intllib
local S
if minetest.get_modpath("intllib") then
	S = intllib.Getter()
else
	S = function(s, a, ...)
		if a == nil then
			return s
		end
		a = {a, ...}
		return s:gsub("(@?)@(%(?)(%d+)(%)?)",
			function(e, o, n, c)
				if e == ""then
					return a[tonumber(n)] .. (o == "" and c or "")
				else
					return "@" .. o .. n .. c
				end
			end)
	end
end
mobs.intllib = S

-- NPC
--dofile(path .. "/npc.lua") -- TenPlus1
--dofile(path .. "/trader.lua")
--dofile(path .. "/igor.lua")
dofile(path .. "/professor.lua")

dofile(path .. "/lucky_block.lua")

print (S("[MOD] Mobs Redo 'NPCs' loaded"))
