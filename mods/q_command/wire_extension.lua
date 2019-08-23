--[[
Copyright 2019 the original author or authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

-- Block that manages a wire extension, which is a the continuation of a circuit wire

-- our API object
wire_extension = {}

wire_extension.block_pos = {}
wire_extension.wire_specs = {} -- pos, num_columns, is_on_wire
wire_extension.wire_specs.pos = {} -- x, y, z

-- returns wire_extension object or nil
function wire_extension:get_wire_extension_block(pos)
	local node_name = minetest.get_node(pos).name
	if minetest.registered_nodes[node_name] then

        -- Retrieve metadata
        local meta = minetest.get_meta(pos)
        local node_type = meta:get_int("node_type")

        local circuit_specs_wire_num_offset = meta:get_int("circuit_specs_wire_num_offset")
        local circuit_num_wires = meta:get_int("circuit_specs_num_wires")
        local circuit_num_columns = meta:get_int("circuit_specs_num_columns")
        local circuit_is_on_grid = meta:get_int("circuit_specs_is_on_grid")
        local circuit_dir_str = meta:get_string("circuit_specs_dir_str")
        local circuit_pos_x = meta:get_int("circuit_specs_pos_x")
        local circuit_pos_y = meta:get_int("circuit_specs_pos_y")
        local circuit_pos_z = meta:get_int("circuit_specs_pos_z")
        local q_command_pos_x = meta:get_int("q_command_block_pos_x")
        local q_command_pos_y = meta:get_int("q_command_block_pos_y")
        local q_command_pos_z = meta:get_int("q_command_block_pos_z")

        --local wire_pos_x = meta:get_int("wire_specs_pos_x")
        --local wire_pos_y = meta:get_int("wire_specs_pos_y")
        --local wire_pos_z = meta:get_int("wire_specs_pos_z")

        local circuit_extension_pos_x = meta:get_int("circuit_extension_pos_x")
        local circuit_extension_pos_y = meta:get_int("circuit_extension_pos_y")
        local circuit_extension_pos_z = meta:get_int("circuit_extension_pos_z")

		return {
			pos = pos,

            -- Node position, table
            get_node_pos = function()
				return pos
			end,

            -- Node name, string
            get_node_name = function()
				return node_name
			end,

            -- Direction that the back of the circuit is facing (+X, -X, +Z, -Z)
            get_circuit_dir_str = function()
				return circuit_dir_str
			end,

            -- Position of lower-left node of the circuit grid
            get_circuit_pos = function()
                local ret_pos = {}
                ret_pos.x = circuit_pos_x
                ret_pos.y = circuit_pos_y
                ret_pos.z = circuit_pos_z
				return ret_pos
			end,

            -- Wire number offset, integer
            get_circuit_specs_wire_num_offset = function()
				return circuit_specs_wire_num_offset
			end,

            -- Number of circuit wires, integer
            get_circuit_num_wires = function()
				return circuit_num_wires
			end,

            -- Number of circuit columns, integer
            get_circuit_num_columns = function()
				return circuit_num_columns
			end,

            -- Position of q_command block
            get_q_command_pos = function()
                local ret_pos = {}
                ret_pos.x = q_command_pos_x
                ret_pos.y = q_command_pos_y
                ret_pos.z = q_command_pos_z
				return ret_pos
			end,

            -- Determine if wire extension exists
            wire_extension_exists = function()
                local ret_exists = false
                if circuit_pos_x ~= 0 and circuit_pos_z ~= 0 then
                    ret_exists = true
                end
				return ret_exists
			end,

            -- Position of extension point in circuit
            get_circuit_extension_pos = function()
                local ret_pos = {}
                ret_pos.x = circuit_extension_pos_x
                ret_pos.y = circuit_extension_pos_y
                ret_pos.z = circuit_extension_pos_z
				return ret_pos
			end,

            -- Create string representation
            -- TODO: What is Lua way to implement a "to string" function?
            to_string = function()
                local ret_str = "pos: " .. dump(pos) .. "\n" ..
                        "node_name: " .. node_name .. "\n" ..
                        "circuit_dir_str: " .. circuit_dir_str .. "\n" ..
                        "circuit_pos_x: " .. tostring(circuit_pos_x) .. "\n" ..
                        "circuit_pos_y: " .. tostring(circuit_pos_y) .. "\n" ..
                        "circuit_pos_z: " .. tostring(circuit_pos_z) .. "\n"
                return ret_str
            end
		}
	else
		return nil
	end
end


function wire_extension:debug_node_info(pos, message)
    local block = wire_extension:get_wire_extension_block(pos)
    minetest.debug("to_string:\n" .. dump(block.to_string()))
    minetest.debug((message or "") .. "\ncircuit_block:\n" ..
        "get_node_pos() " .. dump(block.get_node_pos()) .. "\n" ..
        "get_node_name() " .. dump(block.get_node_name()) .. "\n" ..
        "wire_extension_exists() " .. dump(block.wire_extension_exists()) .. "\n" ..
        --"get_wire_pos() " .. dump(block.get_wire_pos()) .. "\n" ..
        "circuit_specs_wire_num_offset() " .. tostring(block.get_circuit_specs_wire_num_offset()) .. "\n" ..
        "get_circuit_extension_pos() " .. dump(block.get_circuit_extension_pos()) .. "\n" ..
        "get_circuit_dir_str() " .. block.get_circuit_dir_str() .. "\n" ..
        "get_circuit_pos() " .. dump(block.get_circuit_pos()) .. "\n" ..
        "get_q_command_pos() " .. dump(block.get_q_command_pos()) .. "\n")

end


function wire_extension:create_blank_wire_extension()
    local extension_block = wire_extension:get_wire_extension_block(wire_extension.block_pos)
    -- local wire_num_wires = wire_extension.wire_specs.num_wires -- s/b 1
    -- local wire_num_columns = wire_extension.wire_specs.num_columns
    local wire_num_columns = extension_block.get_circuit_num_columns()

    -- TODO: [x] Eliminate outer loop, as there is just one wire
    -- for wire = 1, 1 do
    for column = 1, wire_num_columns do
        local node_pos = {}
        node_pos.y = extension_block.get_circuit_pos().y

        -- Assume dir_str is "+Z"
        local param2_dir = 0
        node_pos.x = extension_block.get_circuit_pos().x + column - 1
        node_pos.z = extension_block.get_circuit_pos().z

        if extension_block.get_circuit_dir_str() == "+X" then
            param2_dir = 1
            node_pos.x = extension_block.get_circuit_pos().x
            node_pos.z = extension_block.get_circuit_pos().z - column + 1
        elseif extension_block.get_circuit_dir_str() == "-X" then
            param2_dir = 3
            node_pos.x = extension_block.get_circuit_pos().x
            node_pos.z = extension_block.get_circuit_pos().z + column - 1
        elseif extension_block.get_circuit_dir_str() == "-Z" then
            param2_dir = 2
            node_pos.x = extension_block.get_circuit_pos().x - column + 1
            node_pos.z = extension_block.get_circuit_pos().z
        end

        minetest.set_node(node_pos,
                {name="circuit_blocks:circuit_blocks_empty_wire", param2=param2_dir})

        -- Update the metadata in these newly created nodes
        local meta = minetest.get_meta(node_pos)

        -- TODO: Calculate offset from the circuit_extension_pos
        meta:set_int("circuit_specs_wire_num_offset", extension_block.get_circuit_specs_wire_num_offset())

        meta:set_int("circuit_specs_num_wires", 1)
        meta:set_int("circuit_specs_num_columns", wire_num_columns)
        meta:set_int("circuit_specs_is_on_grid", 1)

        --[[
        meta:set_string("circuit_specs_dir_str", wire_extension.wire_specs.dir_str)
        meta:set_int("circuit_specs_pos_x", wire_extension.wire_specs.pos.x)
        meta:set_int("circuit_specs_pos_y", wire_extension.wire_specs.pos.y)
        meta:set_int("circuit_specs_pos_z", wire_extension.wire_specs.pos.z)
        --]]

        meta:set_string("circuit_specs_dir_str", extension_block.get_circuit_dir_str())
        meta:set_int("circuit_specs_pos_x", extension_block.get_circuit_pos().x)
        meta:set_int("circuit_specs_pos_y", extension_block.get_circuit_pos().y)
        meta:set_int("circuit_specs_pos_z", extension_block.get_circuit_pos().z)

        meta:set_int("wire_extension_block_pos_x", extension_block.get_node_pos().x)
        meta:set_int("wire_extension_block_pos_y", extension_block.get_node_pos().y)
        meta:set_int("wire_extension_block_pos_z", extension_block.get_node_pos().z)

        meta:set_int("q_command_block_pos_x", extension_block.get_q_command_pos().x)
        meta:set_int("q_command_block_pos_y", extension_block.get_q_command_pos().y)
        meta:set_int("q_command_block_pos_z", extension_block.get_q_command_pos().z)

    end
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
    if(formname == "create_wire_extension") then
        if fields.num_columns_str then
            local num_wires = 1
            local num_columns = tonumber(fields.num_columns_str)
            local start_z_offset = 0
            local start_x_offset = 1

            local horiz_dir_str = q_command:player_horiz_direction_string(player)

            if num_columns and num_columns > 0 then
                -- Store direction string, position of left-most, bottom-most block, and dimensions of circuit
                wire_extension.wire_specs.dir_str = horiz_dir_str

                wire_extension.wire_specs.pos.y = wire_extension.block_pos.y

                -- Assume dir_str is "+Z"
                wire_extension.wire_specs.pos.x = wire_extension.block_pos.x + start_x_offset
                wire_extension.wire_specs.pos.z = wire_extension.block_pos.z + start_z_offset

                if wire_extension.wire_specs.dir_str == "+X" then
                    wire_extension.wire_specs.pos.x = wire_extension.block_pos.x + start_z_offset
                    wire_extension.wire_specs.pos.z = wire_extension.block_pos.z - start_x_offset
                elseif wire_extension.wire_specs.dir_str == "-X" then
                    wire_extension.wire_specs.pos.x = wire_extension.block_pos.x - start_z_offset
                    wire_extension.wire_specs.pos.z = wire_extension.block_pos.z + start_x_offset
                elseif wire_extension.wire_specs.dir_str == "-Z" then
                    wire_extension.wire_specs.pos.x = wire_extension.block_pos.x - start_x_offset
                    wire_extension.wire_specs.pos.z = wire_extension.block_pos.z - start_z_offset
                end


                wire_extension.wire_specs.num_wires = num_wires
                wire_extension.wire_specs.num_columns = num_columns
                minetest.debug("wire_extension.wire_specs: " .. dump(wire_extension.wire_specs))

                -- Put direction and location of circuit into the wire_extension block metadata
                local meta = minetest.get_meta(wire_extension.block_pos)
                meta:set_string("circuit_specs_dir_str", wire_extension.wire_specs.dir_str)
                meta:set_int("circuit_specs_pos_x", wire_extension.wire_specs.pos.x)
                meta:set_int("circuit_specs_pos_y", wire_extension.wire_specs.pos.y)
                meta:set_int("circuit_specs_pos_z", wire_extension.wire_specs.pos.z)
                meta:set_int("circuit_specs_num_wires", wire_extension.wire_specs.num_wires)
                meta:set_int("circuit_specs_num_columns", wire_extension.wire_specs.num_columns)

                -- Create circuit grid with empty blocks
                wire_extension:create_blank_wire_extension()

                -- TODO: Find a better way (that works)
                -- Punch the wire_extension block (ourself) to run simulator and update resultant displays
                --minetest.punch_node(wire_extension.block_pos)

            else
                -- TODO: Show error message dialog?
                minetest.chat_send_player(player:get_player_name(),
                    "Wire extension not created! ")
            end
            return
        end
    end
end)

minetest.register_node("q_command:wire_extension_block", {
    description = "Wire extension block",
    tiles = {"circuit_blocks_wire_connector_f.png"},
    groups = {oddly_breakable_by_hand=2},
	paramtype2 = "facedir",

    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Wire extension block")
        wire_extension.block_pos = pos
    end,
	on_place = function(itemstack, placer, pointed_thing)
		-- Place the wire extension block
        -- TODO: Verify that this is working correctly
		local ret_itemstack, ret_success = minetest.item_place(itemstack,
                placer, pointed_thing)
        minetest.debug("In wire_extension_block on_place, ret_itemstack.get_count():\n" ..
        tostring(ret_itemstack:get_count()) .. "\nret_success: " .. tostring(ret_success))
        if ret_success then
            ret_itemstack:set_count(0)
        end
        return ret_itemstack
	end,
    after_place_node = function(pos, placer, itemstack)
        local itemstack_meta = itemstack:get_meta()
        local circuit_extension_pos = {x = itemstack_meta:get_int("circuit_extension_pos_x"),
                                       y = itemstack_meta:get_int("circuit_extension_pos_y"),
                                       z = itemstack_meta:get_int("circuit_extension_pos_z")}
        local wire_extension_block_meta = minetest.get_meta(pos)

        -- Put the position of the circuit extension node into this wire extension block
        wire_extension_block_meta:set_int("circuit_extension_pos_x",
                circuit_extension_pos.x)
        wire_extension_block_meta:set_int("circuit_extension_pos_y",
                circuit_extension_pos.y)
        wire_extension_block_meta:set_int("circuit_extension_pos_z",
                circuit_extension_pos.z)

        -- Put the location of this wire extension block into the circuit extension node
        local circuit_extension_block_meta = minetest.get_meta(circuit_extension_pos)
        circuit_extension_block_meta:set_int("wire_extension_block_pos_x", pos.x)
        circuit_extension_block_meta:set_int("wire_extension_block_pos_y", pos.y)
        circuit_extension_block_meta:set_int("wire_extension_block_pos_z", pos.z)

        -- Put the wire num offset into this wire extension block
        wire_extension_block_meta:set_int("circuit_specs_wire_num_offset",
                itemstack_meta:get_int("circuit_specs_wire_num_offset"))

        -- Put the position of the q_command block into this wire extension block
        wire_extension_block_meta:set_int("q_command_block_pos_x",
                itemstack_meta:get_int("q_command_block_pos_x"))
        wire_extension_block_meta:set_int("q_command_block_pos_y",
                itemstack_meta:get_int("q_command_block_pos_y"))
        wire_extension_block_meta:set_int("q_command_block_pos_z",
                itemstack_meta:get_int("q_command_block_pos_z"))

        minetest.debug("In after_place_node(), wire_extension_itemstack circuit_extension_pos: " ..
                dump(circuit_extension_pos))
        minetest.debug("wire_extension_block_meta:get_int('circuit_specs_wire_num_offset') " ..
                wire_extension_block_meta:get_int("circuit_specs_wire_num_offset"))

        local extension_block = wire_extension:get_wire_extension_block(pos)
        wire_extension:debug_node_info(pos, "In after_place_node(), wire_extension_block")

        -- TODO: Decide whether to return true or false
        return false
    end,
    on_rightclick = function(pos, node, clicker, itemstack)
        local player_name = clicker:get_player_name()
        local meta = minetest.get_meta(pos)
        local formspec = "size[5.0, 4.6]"..
                -- "field[1.0,0.5;1.5,1.5;num_wires_str;Wires:;3]" ..
                "field[3.0,0.5;1.5,1.5;num_columns_str;Columns:;4]" ..
				"button_exit[1.8,3.5;1.5,1.0;create;Create]"
        minetest.show_formspec(player_name, "create_wire_extension", formspec)
    end,
    on_punch = function(pos, node, player)
        -- If shift key is down, delete this block and the wire extension
        if player:get_player_control().sneak then
            local extension_block = wire_extension:get_wire_extension_block(pos)
            local circuit_extension_pos = extension_block:get_circuit_extension_pos()
            local circuit_extension_block = circuit_blocks:get_circuit_block(circuit_extension_pos)
            circuit_blocks:delete_wire_extension(circuit_extension_block, player)
        end
    end,
    can_dig = function(pos, player)
        return false
    end
})

