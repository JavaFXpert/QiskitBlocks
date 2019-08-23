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


dofile(minetest.get_modpath("circuit_blocks").."/circuit_node_types.lua");

-- our API object
circuit_blocks = {}

-- returns circuit_block object or nil
function circuit_blocks:get_circuit_block(pos)
	local node_name = minetest.get_node(pos).name
	if minetest.registered_nodes[node_name] then

        -- Retrieve metadata
        local meta = minetest.get_meta(pos)
        local node_type = meta:get_int("node_type")
        local radians = meta:get_float("radians")
        local ctrl_a = meta:get_int("ctrl_a")
        local ctrl_b = meta:get_int("ctrl_b")
        local swap = meta:get_int("swap")

        -- 1 if node is a gate, 0 of node is not a gate
        local node_is_gate = meta:get_int("is_gate")

        -- Retrieve circuit_specs metadata
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

        -- Retrieve wire extension related metadata (specific to circuit extension blocks)
        local wire_extension_block_pos_x = meta:get_int("wire_extension_block_pos_x")
        local wire_extension_block_pos_y = meta:get_int("wire_extension_block_pos_y")
        local wire_extension_block_pos_z = meta:get_int("wire_extension_block_pos_z")

        local node_wire_num = -1
        if circuit_is_on_grid == 1 then
            node_wire_num = circuit_num_wires - (pos.y - circuit_pos_y) + circuit_specs_wire_num_offset
        end

        local node_column_num = -1
        if circuit_is_on_grid == 1 then
            node_column_num = pos.x - circuit_pos_x + 1
        end

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

            get_node_type = function()
				return node_type
			end,

            -- Rotation in radians, float
            get_radians = function()
				return radians
			end,

            set_radians = function(radians_arg)
                radians = radians_arg
                meta:set_float("radians", radians_arg)
            end,

            -- Set control wire A, integer
            set_ctrl_a = function(ctrl_a_arg)
                ctrl_a = ctrl_a_arg
                meta:set_int("ctrl_a", ctrl_a_arg)

                return
			end,

            -- Get control wire A, integer
            get_ctrl_a = function()
				return ctrl_a
			end,

            -- Set control wire B, integer
            set_ctrl_b = function(ctrl_b_arg)
                ctrl_b = ctrl_b_arg
                meta:set_int("ctrl_b", ctrl_b_arg)

                return
			end,

            -- Control wire B, integer
            get_ctrl_b = function()
				return ctrl_b
			end,


            -- Set swap wire, integer
            set_swap = function(swap_arg)
                swap = swap_arg
                meta:set_int("swap", swap_arg)

                return
			end,

            -- Get swap wire, integer
            get_swap = function()
				return swap
			end,


            -- Indicates whether node is a gate, boolean
            is_gate = function()
				return node_is_gate == 1
			end,

            --
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

            -- Indicates whether node is on the circuit grid, boolean
            is_on_circuit_grid = function()
				return circuit_is_on_grid == 1
			end,

            -- Determine if a node is in the bounds of the circuit grid
            -- TODO: Perhaps deprecate is_on_circuit_grid()
            is_within_circuit_grid = function()
                local ret_within = false
                if circuit_dir_str == "+Z" then
                    if pos.x >= circuit_pos_x and
                            pos.x < (circuit_pos_x + circuit_num_columns) and
                            pos.y >= circuit_pos_y and
                            pos.y < (circuit_pos_y + circuit_num_wires) and
                            pos.z == circuit_pos_z then
                        ret_within = true
                    end
                elseif circuit_dir_str == "+X" then
                    if pos.z <= circuit_pos_z and
                            pos.z > (circuit_pos_z - circuit_num_columns) and
                            pos.y >= circuit_pos_y and
                            pos.y < (circuit_pos_y + circuit_num_wires) and
                            pos.x == circuit_pos_x then
                        ret_within = true
                    end
                elseif circuit_dir_str == "-X" then
                    if pos.z >= circuit_pos_z and
                            pos.z < (circuit_pos_z + circuit_num_columns) and
                            pos.y >= circuit_pos_y and
                            pos.y < (circuit_pos_y + circuit_num_wires) and
                            pos.x == circuit_pos_x then
                        ret_within = true
                    end
                elseif circuit_dir_str == "-Z" then
                    if pos.x <= circuit_pos_x and
                            pos.x > (circuit_pos_x - circuit_num_columns) and
                            pos.y >= circuit_pos_y and
                            pos.y < (circuit_pos_y + circuit_num_wires) and
                            pos.z == circuit_pos_z then
                        ret_within = true
                    end
                end

				return ret_within
			end,

            -- Circuit wire num that node is on, integer (1..num wires, -1 if not)
            get_node_wire_num = function()
				return node_wire_num
			end,

            -- Circuit column that node is on, integer (1..num columns, -1 if not)
            get_node_column_num = function()
				return node_column_num
			end,

            -- Direction that the back of the circuit is facing (X+, X-, Z+, Z-)
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

            -- Position of q_command block
            get_q_command_pos = function()
                local ret_pos = {}
                ret_pos.x = q_command_pos_x
                ret_pos.y = q_command_pos_y
                ret_pos.z = q_command_pos_z
				return ret_pos
			end,

            -- Position of wire extension block (specific to circuit extension blocks)
            get_wire_extension_block_pos = function()
                local ret_pos = {}
                ret_pos.x = wire_extension_block_pos_x
                ret_pos.y = wire_extension_block_pos_y
                ret_pos.z = wire_extension_block_pos_z
				return ret_pos
			end,

            -- Create string representation
            -- TODO: What is Lua way to implement a "to string" function?
            to_string = function()
                local ret_str = "pos: " .. dump(pos) .. "\n" ..
                        "node_name: " .. node_name .. "\n" ..
                        "node_type: " .. tostring(node_type) .. "\n" ..
                        "radians: " .. tostring(radians) .. "\n" ..
                        "ctrl_a: " .. tostring(ctrl_a) .. "\n" ..
                        "ctrl_b: " .. tostring(ctrl_b) .. "\n" ..
                        "swap: " .. tostring(swap) .. "\n" ..
                        "node_is_gate: " .. tostring(node_is_gate) .. "\n" ..
                        "circuit_specs_wire_num_offset: " .. tostring(circuit_specs_wire_num_offset) .. "\n" ..
                        "circuit_num_wires: " .. tostring(circuit_num_wires) .. "\n" ..
                        "circuit_num_columns: " .. tostring(circuit_num_columns) .. "\n" ..
                        "circuit_is_on_grid: " .. tostring(circuit_is_on_grid) .. "\n" ..
                        "circuit_dir_str: " .. circuit_dir_str .. "\n" ..
                        "circuit_pos_x: " .. tostring(circuit_pos_x) .. "\n" ..
                        "circuit_pos_y: " .. tostring(circuit_pos_y) .. "\n" ..
                        "circuit_pos_z: " .. tostring(circuit_pos_z) .. "\n" ..
                        "q_command_pos_x: " .. tostring(q_command_pos_x) .. "\n" ..
                        "q_command_pos_y: " .. tostring(q_command_pos_y) .. "\n" ..
                        "q_command_pos_z: " .. tostring(q_command_pos_z) .. "\n" ..
                        "wire_extension_block_pos_x: " .. tostring(wire_extension_block_pos_x) .. "\n" ..
                        "wire_extension_block_pos_x: " .. tostring(wire_extension_block_pos_x) .. "\n" ..
                        "wire_extension_block_pos_x: " .. tostring(wire_extension_block_pos_x) .. "\n"
                return ret_str
            end
		}
	else
		return nil
	end
end


function circuit_blocks:debug_node_info(pos, message)
    if not LOG_DEBUG then return end

    local block = circuit_blocks:get_circuit_block(pos)
    -- minetest.debug("to_string:\n" .. dump(block.to_string()))
    minetest.debug((message or "") .. "\ncircuit_block:\n" ..
        "get_node_pos() " .. dump(block.get_node_pos()) .. "\n" ..
        "get_node_name() " .. dump(block.get_node_name()) .. "\n" ..
        "get_node_type() " .. tostring(block.get_node_type()) .. "\n" ..
        "get_radians() " .. tostring(block.get_radians()) .. "\n" ..
        "get_ctrl_a() " .. tostring(block.get_ctrl_a()) .. "\n" ..
        "get_ctrl_b() " .. tostring(block.get_ctrl_b()) .. "\n" ..
        "get_swap() " .. tostring(block.get_swap()) .. "\n" ..
        "is_gate() " .. tostring(block.is_gate()) .. "\n" ..
        "circuit_specs_wire_num_offset() " .. tostring(block.get_circuit_specs_wire_num_offset()) .. "\n" ..
        "get_circuit_num_wires() " .. tostring(block.get_circuit_num_wires()) .. "\n" ..
        "get_circuit_num_columns() " .. tostring(block.get_circuit_num_columns()) .. "\n" ..
        "is_on_circuit_grid() " .. tostring(block.is_on_circuit_grid()) .. "\n" ..
        "is_within_circuit_grid() " .. tostring(block.is_within_circuit_grid()) .. "\n" ..
        "get_node_wire_num() " .. tostring(block.get_node_wire_num()) .. "\n" ..
        "get_node_column_num() " .. tostring(block.get_node_column_num()) .. "\n" ..
        "get_circuit_dir_str() " .. block.get_circuit_dir_str() .. "\n" ..
        "get_circuit_pos() " .. dump(block.get_circuit_pos()) .. "\n" ..
        "get_q_command_pos() " .. dump(block.get_q_command_pos()) .. "\n" ..
        "get_wire_extension_block_pos() " .. dump(block.get_wire_extension_block_pos()) .. "\n"
    )

end


function circuit_blocks:place_nodes_between(gate_block, ctrl_block, new_node_type)
    --[[
    Place nodes vertically between given nodes
    TODO: Support all node types, but for now, only EMPTY and TRACE are supported
    --]]
    local low_wire_num = math.min(gate_block.get_node_wire_num(),
            ctrl_block.get_node_wire_num())
    local high_wire_num = math.max(gate_block.get_node_wire_num(),
            ctrl_block.get_node_wire_num())
    local new_node_name = "circuit_blocks:circuit_blocks_empty_wire"
    if new_node_type == CircuitNodeTypes.EMPTY then
        new_node_name = "circuit_blocks:circuit_blocks_empty_wire"
    elseif new_node_type == CircuitNodeTypes.TRACE then
        new_node_name = "circuit_blocks:circuit_blocks_trace"
    end

    local low_wire_num_pos = {x = gate_block.get_node_pos().x,
                              y = gate_block.get_circuit_pos().y +
                                      gate_block.get_circuit_num_wires() -
                                      low_wire_num,
                              z = gate_block.get_node_pos().z}

    if high_wire_num - low_wire_num >= 2 then
        -- TODO: Perhaps do deep copy instead?
        local cur_pos = {x = low_wire_num_pos.x, y = low_wire_num_pos.y, z = low_wire_num_pos.z}
        local cur_wire_num = 0

        for i = 1, high_wire_num - low_wire_num - 1 do
            cur_wire_num = low_wire_num + i
            if cur_wire_num ~= gate_block.get_ctrl_a() and cur_wire_num ~= gate_block.get_ctrl_b() then
                cur_pos.y = low_wire_num_pos.y - i
                minetest.swap_node(cur_pos, {name = new_node_name})

                minetest.get_meta(cur_pos):set_int("node_type", new_node_type)
            end
        end
    end
    return
end


function circuit_blocks:set_node_with_circuit_specs_meta(pos, node_name, player)
    -- Retrieve circuit_specs metadata
    local meta = minetest.get_meta(pos)

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


    local circuit_node_block = circuit_blocks:get_circuit_block(pos)
    local circuit_dir_str = circuit_node_block.get_circuit_dir_str()
    local param2_dir = 0
    if circuit_dir_str == "+X" then
        param2_dir = 1
    elseif circuit_dir_str == "-X" then
        param2_dir = 3
    elseif circuit_dir_str == "-Z" then
        param2_dir = 2
    end

    minetest.set_node(pos, {name = node_name,
                            param2 = param2_dir})

    --minetest.set_node(pos, {name = node_name,
    --                        param2 = minetest.dir_to_facedir(player:get_look_dir())})

    -- Put circuit_specs metadata on placed node
    meta = minetest.get_meta(pos)

    meta:set_int("circuit_specs_wire_num_offset", circuit_specs_wire_num_offset)
    meta:set_int("circuit_specs_num_wires", circuit_num_wires)
    meta:set_int("circuit_specs_num_columns", circuit_num_columns)
    meta:set_int("circuit_specs_is_on_grid", circuit_is_on_grid)
    meta:set_string("circuit_specs_dir_str", circuit_dir_str)
    meta:set_int("circuit_specs_pos_x", circuit_pos_x)
    meta:set_int("circuit_specs_pos_y", circuit_pos_y)
    meta:set_int("circuit_specs_pos_z", circuit_pos_z)
    meta:set_int("q_command_block_pos_x", q_command_pos_x)
    meta:set_int("q_command_block_pos_y", q_command_pos_y)
    meta:set_int("q_command_block_pos_z", q_command_pos_z)
end


function circuit_blocks:place_swap_qubit(gate_block, candidate_swap_wire_num, player)
    --[[
    Attempt to place a swap qubit on a wire.
    If successful, return the wire number. If not, return -1
    --]]
    local ret_placed_wire = -1
    local gate_wire_num = gate_block:get_node_wire_num()
    local circuit_num_wires = gate_block.get_circuit_num_wires()
    local gate_pos = gate_block:get_node_pos()

    if gate_block.get_node_type() == CircuitNodeTypes.SWAP and
            gate_wire_num >= 1 and
            gate_wire_num <= gate_block:get_circuit_num_wires() then
        local pos_y = circuit_num_wires - candidate_swap_wire_num + gate_block:get_circuit_pos().y
        local candidate_swap_pos = {x = gate_pos.x, y = pos_y, z = gate_pos.z}
        local candidate_block = circuit_blocks:get_circuit_block(candidate_swap_pos)

        -- Validate whether swap qubit may be placed
        if candidate_block:is_within_circuit_grid() and
                (candidate_block.get_node_type() == CircuitNodeTypes.EMPTY or
                        candidate_block.get_node_type() == CircuitNodeTypes.TRACE) then

            local new_swap_node_name = "circuit_blocks:circuit_blocks_swap_down_mate"
            if candidate_swap_wire_num > gate_block:get_node_wire_num() then
                new_swap_node_name = "circuit_blocks:circuit_blocks_swap_up_mate"
            end

            gate_block.set_swap(candidate_swap_wire_num)

            circuit_blocks:set_node_with_circuit_specs_meta(candidate_swap_pos,
                    new_swap_node_name, player)

            ret_placed_wire = candidate_swap_wire_num

            local new_gate_node_name = "circuit_blocks:circuit_blocks_swap"
            if gate_block.get_ctrl_a() ~= -1 then
                if gate_block.get_ctrl_a() > gate_block:get_node_wire_num() and
                        candidate_swap_wire_num > gate_block:get_node_wire_num() then
                    new_gate_node_name = "circuit_blocks:circuit_blocks_swap_down"
                elseif gate_block.get_ctrl_a() < gate_block:get_node_wire_num() and
                        candidate_swap_wire_num < gate_block:get_node_wire_num() then
                    new_gate_node_name = "circuit_blocks:circuit_blocks_swap_up"
                end
            else
                if candidate_swap_wire_num > gate_block:get_node_wire_num() then
                    new_gate_node_name = "circuit_blocks:circuit_blocks_swap_down"
                else
                    new_gate_node_name = "circuit_blocks:circuit_blocks_swap_up"
                end
            end

            minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})

            -- Place TRACE nodes between gate and swap node
            if gate_block.get_swap() ~= -1 then
                circuit_blocks:place_nodes_between(gate_block, candidate_block,
                    CircuitNodeTypes.TRACE)
            end
        end
    end

    return ret_placed_wire
end


function circuit_blocks:remove_swap_qubit(gate_block, swap_wire_num, player)
    --[[
    Remove a swap qubit from a wire.
    --]]
    local gate_wire_num = gate_block:get_node_wire_num()
    local circuit_num_wires = gate_block.get_circuit_num_wires()
    local gate_pos = gate_block:get_node_pos()

    if gate_block.get_node_type() == CircuitNodeTypes.SWAP and
            gate_wire_num >= 1 and
            gate_wire_num <= gate_block:get_circuit_num_wires() then
        local pos_y = circuit_num_wires - swap_wire_num + gate_block:get_circuit_pos().y
        local swap_pos = {x = gate_pos.x, y = pos_y, z = gate_pos.z}
        local swap_block = circuit_blocks:get_circuit_block(swap_pos)

        -- Validate whether swap qubit may be removed
        if swap_block:is_within_circuit_grid() then
            if math.abs(swap_wire_num - gate_block:get_node_wire_num()) > 0 then
                -- Remove nodes in-between gate and swap nodes
                circuit_blocks:place_nodes_between(gate_block, swap_block,
                        CircuitNodeTypes.EMPTY)
            end

            local new_swap_node_name = "circuit_blocks:circuit_blocks_empty_wire"

            gate_block.set_swap(-1)

            circuit_blocks:set_node_with_circuit_specs_meta(swap_pos,
                    new_swap_node_name, player)

            local new_gate_node_name = "circuit_blocks:circuit_blocks_swap"
            minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})
        end
    end
end


function circuit_blocks:place_ctrl_swap_qubit(gate_block, candidate_ctrl_wire_num, player)
    --[[
    Attempt to place a ctrl qubit on a wire for a swap gate.
    If successful, return the wire number. If not, return -1
    --]]
    local ret_placed_wire = -1
    local gate_wire_num = gate_block:get_node_wire_num()
    local circuit_num_wires = gate_block.get_circuit_num_wires()
    local gate_pos = gate_block:get_node_pos()

    if gate_block.get_node_type() == CircuitNodeTypes.SWAP and
            gate_block:get_swap() ~= -1 and
            gate_wire_num >= 1 and
            gate_wire_num <= gate_block:get_circuit_num_wires() then
        local pos_y = circuit_num_wires - candidate_ctrl_wire_num + gate_block:get_circuit_pos().y
        local candidate_ctrl_pos = {x = gate_pos.x, y = pos_y, z = gate_pos.z}
        local candidate_block = circuit_blocks:get_circuit_block(candidate_ctrl_pos)

        -- Validate whether ctrl qubit may be placed
        if candidate_block:is_within_circuit_grid() and
                (candidate_block.get_node_type() == CircuitNodeTypes.EMPTY or
                        candidate_block.get_node_type() == CircuitNodeTypes.TRACE) then

            local new_ctrl_node_name = "circuit_blocks:circuit_blocks_control"
            if candidate_ctrl_wire_num < gate_block:get_node_wire_num() and
                    candidate_ctrl_wire_num < gate_block:get_swap() then
                new_ctrl_node_name = "circuit_blocks:circuit_blocks_control_down"
            elseif candidate_ctrl_wire_num > gate_block:get_node_wire_num() and
                    candidate_ctrl_wire_num > gate_block:get_swap() then
                new_ctrl_node_name = "circuit_blocks:circuit_blocks_control_up"
            end

            gate_block.set_ctrl_a(candidate_ctrl_wire_num)

            circuit_blocks:set_node_with_circuit_specs_meta(candidate_ctrl_pos,
                    new_ctrl_node_name, player)

            ret_placed_wire = candidate_ctrl_wire_num

            -- Work out which blocks to use for swap node
            local new_gate_node_name = "circuit_blocks:circuit_blocks_swap"
            if candidate_ctrl_wire_num > gate_block:get_node_wire_num() and
                    gate_block:get_swap() > gate_block:get_node_wire_num() then
                new_gate_node_name = "circuit_blocks:circuit_blocks_swap_down"
            elseif candidate_ctrl_wire_num < gate_block:get_node_wire_num() and
                    gate_block:get_swap() < gate_block:get_node_wire_num() then
                new_gate_node_name = "circuit_blocks:circuit_blocks_swap_up"
            end
            minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})

            -- Place TRACE nodes between gate and ctrl_a node
            if gate_block.get_ctrl_a() ~= -1 then
                circuit_blocks:place_nodes_between(gate_block, candidate_block,
                    CircuitNodeTypes.TRACE)
            end
        end
    end

    return ret_placed_wire
end


function circuit_blocks:remove_ctrl_swap_qubit(gate_block, ctrl_wire_num, player)
    --[[
    Remove a control qubit from a wire for a swap gate.
    --]]
    local gate_wire_num = gate_block:get_node_wire_num()
    local circuit_num_wires = gate_block.get_circuit_num_wires()
    local gate_pos = gate_block:get_node_pos()

    if gate_block:get_swap() ~= -1 and
            gate_wire_num >= 1 and
            gate_wire_num <= gate_block:get_circuit_num_wires() then
        local pos_y = circuit_num_wires - ctrl_wire_num + gate_block:get_circuit_pos().y
        local ctrl_pos = {x = gate_pos.x, y = pos_y, z = gate_pos.z}
        local ctrl_block = circuit_blocks:get_circuit_block(ctrl_pos)

        -- Validate whether control qubit may be removed
        if ctrl_block:is_within_circuit_grid() then
            if math.abs(ctrl_wire_num - gate_block:get_node_wire_num()) > 0 then
                -- Remove nodes in-between gate and ctrl nodes
                circuit_blocks:place_nodes_between(gate_block, ctrl_block,
                        CircuitNodeTypes.EMPTY)
            end

            local new_ctrl_node_name = "circuit_blocks:circuit_blocks_trace"
            if (ctrl_wire_num > gate_block:get_node_wire_num() and
                    ctrl_wire_num > gate_block:get_swap()) or
                    (ctrl_wire_num < gate_block:get_node_wire_num() and
                    ctrl_wire_num < gate_block:get_swap()) then
                new_ctrl_node_name = "circuit_blocks:circuit_blocks_empty_wire"
            end
            gate_block.set_ctrl_a(-1)
            circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                    new_ctrl_node_name, player)

            local new_gate_node_name = "circuit_blocks:circuit_blocks_swap_up"
            if gate_block.get_swap() > gate_block:get_node_wire_num() then
                new_gate_node_name = "circuit_blocks:circuit_blocks_swap_down"
            end
            minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})
        end
    end
end


function circuit_blocks:place_ctrl_qubit(gate_block, candidate_ctrl_wire_num, player, b)
    --[[
    Attempt to place a control qubit on a wire.
    If successful, return the wire number. If not, return -1
    --]]
    local ret_placed_wire = -1
    local gate_wire_num = gate_block:get_node_wire_num()
    local circuit_num_wires = gate_block.get_circuit_num_wires()
    local gate_pos = gate_block:get_node_pos()

    if gate_wire_num >= 1 and
            gate_wire_num <= gate_block:get_circuit_num_wires() then
        local pos_y = circuit_num_wires - candidate_ctrl_wire_num + gate_block:get_circuit_pos().y
        local candidate_ctrl_pos = {x = gate_pos.x, y = pos_y, z = gate_pos.z}
        local candidate_block = circuit_blocks:get_circuit_block(candidate_ctrl_pos)

        -- Validate whether control qubit may be placed
        if candidate_block:is_within_circuit_grid() and
                (candidate_block.get_node_type() == CircuitNodeTypes.EMPTY or
                        candidate_block.get_node_type() == CircuitNodeTypes.TRACE) then

            local new_ctrl_node_name = "circuit_blocks:circuit_blocks_control_down"
            if candidate_ctrl_wire_num > gate_block:get_node_wire_num() then
                new_ctrl_node_name = "circuit_blocks:circuit_blocks_control_up"
            end

            if b then
                -- Handle Toffoli gate
                gate_block.set_ctrl_b(candidate_ctrl_wire_num)
                if (gate_block.get_ctrl_b() < gate_block.get_ctrl_a() and
                    gate_block.get_ctrl_b() > gate_block:get_node_wire_num()) or
                    (gate_block.get_ctrl_b() > gate_block.get_ctrl_a() and
                    gate_block.get_ctrl_b() < gate_block:get_node_wire_num()) then
                    new_ctrl_node_name = "circuit_blocks:circuit_blocks_control"
                end
            else
                gate_block.set_ctrl_a(candidate_ctrl_wire_num)
            end

            -- Put correct suffix on the control image name
            if b then
                new_ctrl_node_name = new_ctrl_node_name .. "_b"
            end

            circuit_blocks:set_node_with_circuit_specs_meta(candidate_ctrl_pos,
                    new_ctrl_node_name, player)

            ret_placed_wire = candidate_ctrl_wire_num

            if gate_block.get_node_type() == CircuitNodeTypes.X then
                local new_gate_node_name = "circuit_blocks:circuit_blocks_not_gate_up"
                if candidate_ctrl_wire_num > gate_block:get_node_wire_num() then
                    new_gate_node_name = "circuit_blocks:circuit_blocks_not_gate_down"
                end

                -- Handle Toffoli gate
                if gate_block.get_ctrl_a() ~= -1 and gate_block.get_ctrl_b() ~= -1 then
                    if (gate_block.get_ctrl_a() > gate_block:get_node_wire_num() and
                        gate_block.get_ctrl_b() < gate_block:get_node_wire_num()) or
                        (gate_block.get_ctrl_a() < gate_block:get_node_wire_num() and
                            gate_block.get_ctrl_b() > gate_block:get_node_wire_num()) then
                        new_gate_node_name = "circuit_blocks:circuit_blocks_not_gate"
                    end
                end
                minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})
            elseif gate_block.get_node_type() == CircuitNodeTypes.H then
                local new_gate_node_name = "circuit_blocks:circuit_blocks_h_gate_up"
                if candidate_ctrl_wire_num > gate_block:get_node_wire_num() then
                    new_gate_node_name = "circuit_blocks:circuit_blocks_h_gate_down"
                end
                minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})
            elseif gate_block.get_node_type() == CircuitNodeTypes.Y then
                local new_gate_node_name = "circuit_blocks:circuit_blocks_y_gate_up"
                if candidate_ctrl_wire_num > gate_block:get_node_wire_num() then
                    new_gate_node_name = "circuit_blocks:circuit_blocks_y_gate_down"
                end
                minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})
            elseif gate_block.get_node_type() == CircuitNodeTypes.Z then
                -- TODO: Replace node with appropriate Rz block
                if gate_block.get_node_name():sub(1, 36) ==
                        "circuit_blocks:circuit_blocks_z_gate" then
                    local new_gate_node_name = "circuit_blocks:circuit_blocks_z_gate_up"
                    if candidate_ctrl_wire_num > gate_block:get_node_wire_num() then
                        new_gate_node_name = "circuit_blocks:circuit_blocks_z_gate_down"
                    end
                    minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})
                end
            end

            -- Place TRACE nodes between gate and ctrl node
            if gate_block.get_ctrl_a() ~= -1 then
                circuit_blocks:place_nodes_between(gate_block, candidate_block,
                    CircuitNodeTypes.TRACE)
            end
        end
    end
    return ret_placed_wire
end


function circuit_blocks:remove_ctrl_qubit(gate_block, ctrl_wire_num, player, b)
    --[[
    Remove a control qubit from a wire.
    --]]
    local gate_wire_num = gate_block:get_node_wire_num()
    local circuit_num_wires = gate_block.get_circuit_num_wires()
    local gate_pos = gate_block:get_node_pos()

    if gate_wire_num >= 1 and
            gate_wire_num <= gate_block:get_circuit_num_wires() then
        local pos_y = circuit_num_wires - ctrl_wire_num + gate_block:get_circuit_pos().y
        local ctrl_pos = {x = gate_pos.x, y = pos_y, z = gate_pos.z}
        local ctrl_block = circuit_blocks:get_circuit_block(ctrl_pos)

        -- Validate whether control qubit may be removed
        if ctrl_block:is_within_circuit_grid() then
            if math.abs(ctrl_wire_num - gate_block:get_node_wire_num()) > 0 then
                -- Remove nodes in-between gate and ctrl nodes
                circuit_blocks:place_nodes_between(gate_block, ctrl_block,
                        CircuitNodeTypes.EMPTY)
            end

            local new_ctrl_node_name = "circuit_blocks:circuit_blocks_empty_wire"

            if b then
                if (gate_block.get_ctrl_a() > gate_block.get_node_wire_num() and
                        gate_block.get_ctrl_b() > gate_block.get_node_wire_num()) or
                        (gate_block.get_ctrl_a() < gate_block.get_node_wire_num() and
                                gate_block.get_ctrl_b() < gate_block.get_node_wire_num()) then
                    new_ctrl_node_name = "circuit_blocks:circuit_blocks_trace"
                end
                gate_block.set_ctrl_b(-1)
            else
                gate_block.set_ctrl_a(-1)
            end

            circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                    new_ctrl_node_name, player)

            if gate_block.get_node_type() == CircuitNodeTypes.X then
                local new_gate_node_name = "circuit_blocks:circuit_blocks_x_gate"
                if gate_block.get_ctrl_a() ~= -1 then
                    if gate_block.get_ctrl_b() ~= -1 then
                        if gate_block.get_ctrl_a() < gate_block:get_node_wire_num() and
                                gate_block.get_ctrl_b() < gate_block:get_node_wire_num() then
                            new_gate_node_name = "circuit_blocks:circuit_blocks_not_gate_up"
                        elseif gate_block.get_ctrl_a() > gate_block:get_node_wire_num() and
                                gate_block.get_ctrl_b() > gate_block:get_node_wire_num() then
                            new_gate_node_name = "circuit_blocks:circuit_blocks_not_gate_down"
                        end
                    else
                        if gate_block.get_ctrl_a() < gate_block:get_node_wire_num() then
                            new_gate_node_name = "circuit_blocks:circuit_blocks_not_gate_up"
                        else
                            new_gate_node_name = "circuit_blocks:circuit_blocks_not_gate_down"
                        end
                    end
                end
                minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})

            elseif gate_block.get_node_type() == CircuitNodeTypes.Y then
                local new_gate_node_name = "circuit_blocks:circuit_blocks_y_gate"
                minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})
            elseif gate_block.get_node_type() == CircuitNodeTypes.Z then
                -- TODO: Replace node with appropriate Rz block
                if gate_block.get_node_name():sub(1, 36) ==
                        "circuit_blocks:circuit_blocks_z_gate" then
                    local new_gate_node_name = "circuit_blocks:circuit_blocks_z_gate"
                    minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})
                end
            elseif gate_block.get_node_type() == CircuitNodeTypes.H then
                local new_gate_node_name = "circuit_blocks:circuit_blocks_h_gate"
                minetest.swap_node(gate_block.get_node_pos(), {name = new_gate_node_name})
            end
        end
    end
end


function circuit_blocks:rotate_gate(gate_block, by_radians)
    --[[
    Rotate a gate by a given number of radians
    --]]

    local node_name_beginning = nil
    local non_rotate_gate_name = nil
    if gate_block.get_ctrl_a() ~= -1 and
            gate_block.get_node_type() ~= CircuitNodeTypes.Z then
        return
    end
    if gate_block.get_node_type() == CircuitNodeTypes.X then
        node_name_beginning = "circuit_blocks:circuit_blocks_rx_gate_"
        non_rotate_gate_name = "circuit_blocks:circuit_blocks_x_gate"
    elseif gate_block.get_node_type() == CircuitNodeTypes.Y then
        node_name_beginning = "circuit_blocks:circuit_blocks_ry_gate_"
        non_rotate_gate_name = "circuit_blocks:circuit_blocks_y_gate"
    elseif gate_block.get_node_type() == CircuitNodeTypes.Z then
        node_name_beginning = "circuit_blocks:circuit_blocks_rz_gate_"
        non_rotate_gate_name = "circuit_blocks:circuit_blocks_z_gate"
    else
        -- Rotation is only supported on X, Y and Z gates
        return
    end


    local prev_radians = gate_block.get_radians()
    local new_radians = (gate_block.get_radians() + (math.pi * 2) + by_radians) % (math.pi * 2)

    gate_block.set_radians(new_radians)

    local new_node_name = nil

    local threshold = 0.0001
    --if math.abs(new_radians - 0) < threshold or
    --        math.abs(new_radians - math.pi * 2) < threshold then
    if math.abs(new_radians - math.pi) < threshold then
        new_node_name = non_rotate_gate_name
        gate_block.set_radians(math.pi)
    else
        local num_pi_16_radians = math.floor(new_radians * 16 / math.pi + 0.5)

        if num_pi_16_radians < 0 then
            num_pi_16_radians = 0
        elseif num_pi_16_radians >= 32 then
            num_pi_16_radians = 0
        end

        new_node_name = node_name_beginning .. tostring(num_pi_16_radians) .. "p16"
    end

    minetest.swap_node(gate_block.get_node_pos(), {name = new_node_name})
end


function circuit_blocks:delete_wire_extension(connector_block, player)
    circuit_blocks:set_node_with_circuit_specs_meta(connector_block:get_node_pos(),
            "circuit_blocks:circuit_blocks_empty_wire", player)

    -- Traverse from connector to wire extension
    local wire_extension_block_pos = connector_block.get_wire_extension_block_pos()

    if wire_extension_block_pos.x ~= 0 then
        local wire_extension_block = circuit_blocks:get_circuit_block(wire_extension_block_pos)
        minetest.remove_node(wire_extension_block_pos)

        local wire_extension_circuit_pos = wire_extension_block.get_circuit_pos()

        if wire_extension_circuit_pos.x ~= 0 then
            local wire_extension_circuit = circuit_blocks:get_circuit_block(wire_extension_circuit_pos)
            -- local extension_wire_num = wire_extension_circuit.get_circuit_specs_wire_num_offset() + 1
            local extension_num_columns = wire_extension_circuit.get_circuit_num_columns()
            local circuit_dir_str = wire_extension_circuit.get_circuit_dir_str()
            for column_num = 1, extension_num_columns do
                local circ_node_pos = {x = wire_extension_circuit_pos.x + column_num - 1,
                                       y = wire_extension_circuit_pos.y,
                                       z = wire_extension_circuit_pos.z}
                if circuit_dir_str == "+X" then
                    circ_node_pos = {x = wire_extension_circuit_pos.x,
                                     y = wire_extension_circuit_pos.y,
                                     z = wire_extension_circuit_pos.z - column_num + 1}
                elseif circuit_dir_str == "-X" then
                    circ_node_pos = {x = wire_extension_circuit_pos.x,
                                     y = wire_extension_circuit_pos.y,
                                     z = wire_extension_circuit_pos.z + column_num - 1}
                elseif circuit_dir_str == "-Z" then
                    circ_node_pos = {x = wire_extension_circuit_pos.x - column_num + 1,
                                     y = wire_extension_circuit_pos.y,
                                     z = wire_extension_circuit_pos.z}
                end

                minetest.remove_node(circ_node_pos)
            end
        end
    end
end


function circuit_blocks:register_circuit_block(circuit_node_type,
                                               connector_up,
                                               connector_down,
                                               pi16rotation,
                                               is_gate,
                                               drop_name,
                                               suffix,
                                               y_pi8rot,
                                               z_pi8rot)
    local texture_name = ""
    if circuit_node_type == CircuitNodeTypes.EMPTY then
        texture_name = "circuit_blocks_empty_wire"
    elseif circuit_node_type == CircuitNodeTypes.X then
        texture_name = "circuit_blocks_x_gate"
        --if pi16rotation ~= 0 then
        if pi16rotation ~= 16 then
            texture_name = "circuit_blocks_rx_gate_" .. pi16rotation .. "p16"
        elseif connector_up and not connector_down then
            texture_name = "circuit_blocks_not_gate_up"
        elseif connector_down and not connector_up then
            texture_name = "circuit_blocks_not_gate_down"
        elseif connector_up and connector_up then
            texture_name = "circuit_blocks_not_gate"
        end
    elseif circuit_node_type == CircuitNodeTypes.Y then
        texture_name = "circuit_blocks_y_gate"
        --if pi16rotation ~= 0 then
        if pi16rotation ~= 16 then
            texture_name = "circuit_blocks_ry_gate_" .. pi16rotation .. "p16"
        elseif connector_up and not connector_down then
            texture_name = "circuit_blocks_y_gate_up"
        elseif connector_down and not connector_up then
            texture_name = "circuit_blocks_y_gate_down"
        end
    elseif circuit_node_type == CircuitNodeTypes.Z then
        texture_name = "circuit_blocks_z_gate"
        --if pi16rotation ~= 0 then
        if pi16rotation ~= 16 then
            texture_name = "circuit_blocks_rz_gate_" .. pi16rotation .. "p16"
        elseif connector_up and not connector_down then
            texture_name = "circuit_blocks_z_gate_up"
        elseif connector_down and not connector_up then
            texture_name = "circuit_blocks_z_gate_down"
        end
    elseif circuit_node_type == CircuitNodeTypes.H then
        texture_name = "circuit_blocks_h_gate"
        if connector_up and not connector_down then
            texture_name = "circuit_blocks_h_gate_up"
        elseif connector_down and not connector_up then
            texture_name = "circuit_blocks_h_gate_down"
        end
    elseif circuit_node_type == CircuitNodeTypes.SWAP then
        texture_name = "circuit_blocks_swap" .. suffix
        if connector_up and not connector_down then
            texture_name = "circuit_blocks_swap_up" .. suffix
        elseif connector_down and not connector_up then
            texture_name = "circuit_blocks_swap_down" .. suffix
        end
    elseif circuit_node_type == CircuitNodeTypes.CTRL then
        texture_name = "circuit_blocks_control" .. suffix
        if connector_up and not connector_down then
            texture_name = "circuit_blocks_control_up" .. suffix
        elseif connector_down and not connector_up then
            texture_name = "circuit_blocks_control_down" .. suffix
        end
    elseif circuit_node_type == CircuitNodeTypes.S then
        texture_name = "circuit_blocks_s_gate"
    elseif circuit_node_type == CircuitNodeTypes.SDG then
        texture_name = "circuit_blocks_sdg_gate"
    elseif circuit_node_type == CircuitNodeTypes.T then
        texture_name = "circuit_blocks_t_gate"
    elseif circuit_node_type == CircuitNodeTypes.TDG then
        texture_name = "circuit_blocks_tdg_gate"
    elseif circuit_node_type == CircuitNodeTypes.TRACE then
        texture_name = "circuit_blocks_trace"
    elseif circuit_node_type == CircuitNodeTypes.BARRIER then
        texture_name = "circuit_blocks_barrier"
    elseif circuit_node_type == CircuitNodeTypes.MEASURE_Z then
        texture_name = "circuit_blocks_measure_" .. suffix
    elseif circuit_node_type == CircuitNodeTypes.CONNECTOR_M then
        texture_name = "circuit_blocks_wire_connector_m"
    elseif circuit_node_type == CircuitNodeTypes.CONNECTOR_F then
        texture_name = "circuit_blocks_wire_connector_f"
    elseif circuit_node_type == CircuitNodeTypes.BLOCH_SPHERE then
        if y_pi8rot and z_pi8rot then
            texture_name = "circuit_blocks_qubit_bloch_y" .. y_pi8rot .. "p8_z" .. z_pi8rot .. "p8"
        else
            texture_name = "circuit_blocks_qubit_bloch_" .. suffix
        end
    elseif circuit_node_type == CircuitNodeTypes.C_IF then
        texture_name = "circuit_blocks_if_" .. suffix
    elseif circuit_node_type == CircuitNodeTypes.QUBIT_BASIS then
        texture_name = "circuit_blocks_gate_" .. suffix
    end

    -- TODO: Work out way to pass in a meaningful description
    minetest.register_node("circuit_blocks:"..texture_name, {
        description = texture_name,
        tiles = {texture_name..".png"},
        groups = {circuit_gate=1, oddly_breakable_by_hand=2},
        paramtype2 = "facedir",
        range = 16,

        -- TODO: Find best way to implement dropping an item
        -- drop = drop_name,

        on_drop = function(itemstack, dropper, pos)
            -- minetest.debug("in on_drop, itemstack: " .. dump(itemstack))
        end,

        on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            meta:set_int("node_type", circuit_node_type)
            meta:set_float("radians", 0.0)
            meta:set_int("ctrl_a", -1)
            meta:set_int("ctrl_b", -1)
            meta:set_int("swap", -1)
            meta:set_int("is_gate", (is_gate and 1 or 0))
        end,

        on_timer = function(pos, elapsed)
            local block = circuit_blocks:get_circuit_block(pos)
            circuit_blocks:rotate_gate(block, math.pi / 16.0)

            -- Punch the q_command block to run simulator and update resultant displays
            local q_command_pos = block.get_q_command_pos()
            minetest.punch_node(q_command_pos)

            return true
        end,

        on_punch = function(pos, node, player)
            -- TODO: Enable digging other types of blocks (e.g. measure_z)
            local block = circuit_blocks:get_circuit_block(pos)

            local placed_wire = -1
            local wielded_item = player:get_wielded_item()
            local node_type = block:get_node_type()

            if block.is_within_circuit_grid() then

                -- Stop node timer if running
                local node_timer = minetest.get_node_timer(pos)
                node_timer:stop()

                if node_type == CircuitNodeTypes.X or
                        node_type == CircuitNodeTypes.Y or
                        node_type == CircuitNodeTypes.Z or
                        node_type == CircuitNodeTypes.H then

                    if wielded_item:get_name() == "circuit_blocks:control_tool" then
                        local threshold = 0.0001
                        -- TODO: Revisit this radians logic, and factor into a function
                        if not player:get_player_control().aux1 and block.get_ctrl_a() == -1 and
                                (node_type == CircuitNodeTypes.Z or
                                math.abs(block.get_radians() - math.pi) < threshold) then
                            placed_wire = circuit_blocks:place_ctrl_qubit(block,
                                    block:get_node_wire_num() - 1, player, false)

                        elseif player:get_player_control().aux1 and block.get_ctrl_a() ~= -1 and
                                block.get_ctrl_b() == -1 and
                                node_type == CircuitNodeTypes.X then
                            -- User adding control qubit b
                            placed_wire = circuit_blocks:place_ctrl_qubit(block,
                                    block:get_node_wire_num() - 1, player, true)

                        elseif player:get_player_control().aux1 and block.get_ctrl_a() ~= -1 and
                                block.get_ctrl_b() == block:get_node_wire_num() + 1 then
                            -- User removing control qubit b
                            circuit_blocks:remove_ctrl_qubit(block,
                                    block.get_ctrl_b(), player, true)

                        elseif not player:get_player_control().aux1 and
                                block.get_ctrl_a() == block:get_node_wire_num() + 1 then
                            if block.get_ctrl_b() == -1 then
                                -- User removing control qubit a
                                circuit_blocks:remove_ctrl_qubit(block,
                                        block.get_ctrl_a(), player, false)
                            end

                        elseif not player:get_player_control().aux1 and block.get_ctrl_a() ~= -1 then
                            -- User moving control qubit a UP
                            --minetest.debug("User moving control qubit a UP, block.get_ctrl_a(): " ..
                            --        tostring(block.get_ctrl_a()) .. ", block.get_node_wire_num(): " ..
                            --        tostring(block.get_node_wire_num()))
                            local pos_y = block.get_circuit_num_wires() - block.get_ctrl_a() + block:get_circuit_pos().y
                            local ctrl_pos = {x = pos.x, y = pos_y, z = pos.z}
                            if block.get_ctrl_a() - 1 >= 1 and
                                    block.get_ctrl_a() - 1 ~= block.get_ctrl_b() then
                                if block.get_ctrl_a() > block.get_node_wire_num() then
                                    -- Replace with empty block if control is moving toward the gate
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                            "circuit_blocks:circuit_blocks_empty_wire", player)
                                end
                                placed_wire = circuit_blocks:place_ctrl_qubit(block,
                                        block.get_ctrl_a() - 1, player, false)
                            else
                                if LOG_DEBUG then
                                    minetest.debug("Tried to place ctrl a on unavailable wire: " ..
                                            block.get_ctrl_a() - 1)
                                end
                            end

                        elseif player:get_player_control().aux1 and block.get_ctrl_b() ~= -1 then
                            -- User moving control qubit b
                            local pos_y = block.get_circuit_num_wires() - block.get_ctrl_b() + block:get_circuit_pos().y
                            local ctrl_pos = {x = pos.x, y = pos_y, z = pos.z}
                            if block.get_ctrl_b() - 1 >= 1 and
                                    block.get_ctrl_b() - 1 ~= block.get_ctrl_a() then
                                if block.get_ctrl_b() < block.get_ctrl_a() and
                                        block.get_node_wire_num() <  block.get_ctrl_b() then
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                        "circuit_blocks:circuit_blocks_trace", player)
                                else
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                        "circuit_blocks:circuit_blocks_empty_wire", player)
                                end
                                placed_wire = circuit_blocks:place_ctrl_qubit(block,
                                        block.get_ctrl_b() - 1, player, true)
                            else
                                if LOG_DEBUG then
                                    minetest.debug("Tried to place ctrl b on unavailable wire: " ..
                                            block.get_ctrl_b() - 1)
                                end
                            end
                        end

                    elseif wielded_item:get_name() == "circuit_blocks:rotate_tool" and
                            (node_type == CircuitNodeTypes.X or
                                    node_type == CircuitNodeTypes.Y or
                                    node_type == CircuitNodeTypes.Z) then
                        if player:get_player_control().aux1 then
                            local node_timer = minetest.get_node_timer(pos)
                            if node_timer:is_started() then
                                node_timer:stop()
                            else
                                node_timer:start(2.0)
                            end
                        else
                            circuit_blocks:rotate_gate(block, math.pi / 16.0)
                        end
                    else
                        if block.get_ctrl_a() ~= -1 then
                            circuit_blocks:remove_ctrl_qubit(block, block.get_ctrl_a(), player)
                            if block.get_ctrl_b() ~= -1 then
                                circuit_blocks:remove_ctrl_qubit(block, block.get_ctrl_b(), player)
                            end
                        end

                        -- Necessary to replace punched node
                        circuit_blocks:set_node_with_circuit_specs_meta(pos,
                                "circuit_blocks:circuit_blocks_empty_wire", player)
                    end

                elseif node_type == CircuitNodeTypes.SWAP then
                    if block:get_node_name():sub(-5) == "_mate" then
                        minetest.chat_send_player(player:get_player_name(),
                                "Please operate on the originally placed Swap gate")
                    elseif wielded_item:get_name() == "circuit_blocks:swap_tool" then
                        if block.get_swap() == -1 then
                            if block:get_node_name():sub(-5) ~= "_mate" then
                                -- Attempt to place a swap qubit
                                placed_wire = circuit_blocks:place_swap_qubit(block,
                                        block:get_node_wire_num() - 1, player)
                            end
                        elseif block.get_swap() == block:get_node_wire_num() + 1 then
                            if block:get_ctrl_a() == -1 then
                                -- User removing swap qubit
                                circuit_blocks:remove_swap_qubit(block,
                                        block.get_swap(), player)
                            end
                        else
                            -- User moving swap qubit UP
                            local pos_y = block.get_circuit_num_wires() - block.get_swap() + block:get_circuit_pos().y
                            local swap_pos = {x = pos.x, y = pos_y, z = pos.z}
                            if block.get_swap() - 1 >= 1 then
                                if block.get_swap() > block.get_node_wire_num() then
                                    -- Replace with empty block if swap mate is moving toward the gate
                                    circuit_blocks:set_node_with_circuit_specs_meta(swap_pos,
                                            "circuit_blocks:circuit_blocks_empty_wire", player)
                                end
                                placed_wire = circuit_blocks:place_swap_qubit(block,
                                        block.get_swap() - 1, player)
                            else
                                if LOG_DEBUG then
                                    minetest.debug("Tried to place swap on unavailable wire: " ..
                                            block.get_swap() - 1)
                                end
                            end
                        end
                    elseif wielded_item:get_name() == "circuit_blocks:control_tool" then
                        if block.get_ctrl_a() == -1 then
                            -- Attempt to place a ctrl qubit
                            placed_wire = circuit_blocks:place_ctrl_swap_qubit(block,
                                    block:get_node_wire_num() - 1, player)
                        elseif block.get_ctrl_a() == block:get_node_wire_num() + 1 then
                            -- User removing control qubit
                            circuit_blocks:remove_ctrl_swap_qubit(block,
                                    block.get_ctrl_a(), player)
                        elseif block.get_ctrl_a() ~= -1 then
                            -- User moving control qubit a
                            local pos_y = block.get_circuit_num_wires() - block.get_ctrl_a() + block:get_circuit_pos().y
                            local ctrl_pos = {x = pos.x, y = pos_y, z = pos.z}
                            if block.get_ctrl_a() - 1 >= 1 and
                                    block.get_ctrl_a() - 1 ~= block.get_swap() then
                                if block:get_ctrl_a() - 1 < block:get_swap() and
                                        block:get_ctrl_a() - 1 > block:get_node_wire_num() then
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                            "circuit_blocks:circuit_blocks_trace", player)
                                else
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                            "circuit_blocks:circuit_blocks_empty_wire", player)
                                end
                                placed_wire = circuit_blocks:place_ctrl_swap_qubit(block,
                                        block.get_ctrl_a() - 1, player)
                            else
                                if LOG_DEBUG then
                                    minetest.debug("Tried to place ctrl_a on unavailable wire: " ..
                                            block.get_ctrl_a() - 1)
                                end
                            end
                        end
                    else
                        if block.get_swap() ~= -1 then
                            circuit_blocks:remove_swap_qubit(block, block.get_swap(), player)
                        end
                        if block.get_ctrl_a() ~= -1 then
                            circuit_blocks:remove_swap_qubit(block, block.get_ctrl_a(), player)
                        end

                        -- Necessary to replace punched node
                        circuit_blocks:set_node_with_circuit_specs_meta(pos,
                                "circuit_blocks:circuit_blocks_empty_wire", player)
                    end

                elseif node_type == CircuitNodeTypes.CONNECTOR_M then
                    -- If shift key is down, delete this block and the wire extension
                    if player:get_player_control().sneak then
                        circuit_blocks:delete_wire_extension(block, player)
                    else
                        local wire_extension_itemstack = ItemStack("q_command:wire_extension_block")
                        local meta = wire_extension_itemstack:get_meta()
                        meta:set_int("circuit_extension_pos_x", pos.x)
                        meta:set_int("circuit_extension_pos_y", pos.y)
                        meta:set_int("circuit_extension_pos_z", pos.z)

                        meta:set_int("q_command_block_pos_x", block.get_q_command_pos().x)
                        meta:set_int("q_command_block_pos_y", block.get_q_command_pos().y)
                        meta:set_int("q_command_block_pos_z", block.get_q_command_pos().z)

                        meta:set_int("circuit_specs_wire_num_offset", block.get_node_wire_num() - 1)

                        local drop_pos = {x = pos.x, y = pos.y, z = pos.z - 1}
                        minetest.item_drop(wire_extension_itemstack, player, drop_pos)

                    end
                elseif node_type == CircuitNodeTypes.CTRL then
                    minetest.chat_send_player(player:get_player_name(),
                            "Use the Control Tool on the originally placed gate to move or remove a control qubit")
                elseif node_type == CircuitNodeTypes.TRACE then
                    minetest.chat_send_player(player:get_player_name(),
                            "Please operate on the originally placed gate")
                elseif wielded_item:get_name() == "circuit_blocks:control_tool" then
                    minetest.chat_send_player(player:get_player_name(),
                            "Control tool may only be used on X, Y, Z and H gates")
                elseif wielded_item:get_name() == "circuit_blocks:rotate_tool" then
                    minetest.chat_send_player(player:get_player_name(),
                            "Rotate tool may only be used on X, Y and Z gates")
                else
                    -- Necessary to replace punched node
                    circuit_blocks:set_node_with_circuit_specs_meta(pos,
                            "circuit_blocks:circuit_blocks_empty_wire", player)
                end

                -- Punch the q_command block to run simulator and update resultant displays
                local q_command_pos = block.get_q_command_pos()
                minetest.punch_node(q_command_pos)

            end

            return
        end,
        can_dig = function(pos, player)
            local meta = minetest.get_meta(pos)
            local node_type = meta:get_int("node_type")
            local radians = meta:get_float("radians")
            local ctrl_a = meta:get_int("ctrl_a")
            local ctrl_b = meta:get_int("ctrl_b")
            local swap = meta:get_int("swap")
            local is_gate = meta:get_int("is_gate")
            local is_on_grid = meta:get_int("circuit_specs_is_on_grid")

            return is_on_grid == 0
        end,
        on_rightclick = function(pos, node, player, itemstack)
            local block = circuit_blocks:get_circuit_block(pos)
            local circuit_dir_str = block.get_circuit_dir_str()

            local placed_wire = -1
            local wielded_item = player:get_wielded_item()
            local node_type = block:get_node_type()

            if block.is_within_circuit_grid() then

                -- Stop node timer if running
                local node_timer = minetest.get_node_timer(pos)
                node_timer:stop()

                if node_type == CircuitNodeTypes.X or
                        node_type == CircuitNodeTypes.Y or
                        node_type == CircuitNodeTypes.Z or
                        node_type == CircuitNodeTypes.H then

                    if wielded_item:get_name() == "circuit_blocks:control_tool" then
                        local threshold = 0.0001
                        if not player:get_player_control().aux1 and block.get_ctrl_a() == -1 and
                                (node_type == CircuitNodeTypes.Z or
                                math.abs(block.get_radians() - math.pi) < threshold) then
                            placed_wire = circuit_blocks:place_ctrl_qubit(block,
                                    block:get_node_wire_num() + 1, player, false)

                        elseif player:get_player_control().aux1 and block.get_ctrl_a() ~= -1 and
                                block.get_ctrl_b() == -1 and
                                node_type == CircuitNodeTypes.X then
                            -- User adding control qubit b
                            placed_wire = circuit_blocks:place_ctrl_qubit(block,
                                    block:get_node_wire_num() + 1, player, true)

                        elseif player:get_player_control().aux1 and block.get_ctrl_a() ~= -1 and
                                block.get_ctrl_b() == block:get_node_wire_num() - 1 then
                            -- User removing control qubit b
                            circuit_blocks:remove_ctrl_qubit(block,
                                    block.get_ctrl_b(), player, true)

                        elseif not player:get_player_control().aux1 and
                                block.get_ctrl_a() == block:get_node_wire_num() - 1 then
                            if block.get_ctrl_b() == -1 then
                                -- User removing control qubit a
                                circuit_blocks:remove_ctrl_qubit(block,
                                        block.get_ctrl_a(), player, false)
                            end

                        elseif not player:get_player_control().aux1 and block.get_ctrl_a() ~= -1 then
                            -- User moving control qubit "a" DOWN
                            local pos_y = block.get_circuit_num_wires() - block.get_ctrl_a() + block:get_circuit_pos().y
                            local ctrl_pos = {x = pos.x, y = pos_y, z = pos.z}
                            if block.get_ctrl_a() + 1 <= block.get_circuit_num_wires() and
                                    block.get_ctrl_a() + 1 ~= block.get_ctrl_b() then
                                if block.get_ctrl_a() < block.get_node_wire_num() then
                                    -- Replace with empty block if control is moving toward the gate
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                            "circuit_blocks:circuit_blocks_empty_wire", player)
                                end
                                placed_wire = circuit_blocks:place_ctrl_qubit(block,
                                        block.get_ctrl_a() + 1, player, false)
                            else
                                if LOG_DEBUG then
                                    minetest.debug("Tried to place ctrl a on unavailable wire: " ..
                                            block.get_ctrl_a() + 1)
                                end
                            end

                        elseif player:get_player_control().aux1 and block.get_ctrl_b() ~= -1 then
                            -- User moving control qubit b
                            local pos_y = block.get_circuit_num_wires() - block.get_ctrl_b() + block:get_circuit_pos().y
                            local ctrl_pos = {x = pos.x, y = pos_y, z = pos.z}
                            if block.get_ctrl_b() + 1 <= block.get_circuit_num_wires() and
                                    block.get_ctrl_b() + 1 ~= block.get_ctrl_a() then
                                if block.get_ctrl_b() > block.get_ctrl_a() and
                                        block.get_node_wire_num() >  block.get_ctrl_b() then
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                        "circuit_blocks:circuit_blocks_trace", player)
                                else
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                        "circuit_blocks:circuit_blocks_empty_wire", player)
                                end
                                placed_wire = circuit_blocks:place_ctrl_qubit(block,
                                        block.get_ctrl_b() + 1, player, true)
                            else
                                if LOG_DEBUG then
                                    minetest.debug("Tried to place ctrl b on unavailable wire: " ..
                                            block.get_ctrl_b() + 1)
                                end
                            end
                        end

                    elseif wielded_item:get_name() == "circuit_blocks:rotate_tool" then
                        circuit_blocks:rotate_gate(block, -math.pi / 16.0)
                    end

                elseif node_type == CircuitNodeTypes.SWAP then
                    if block:get_node_name():sub(-5) == "_mate" then
                        minetest.chat_send_player(player:get_player_name(),
                                "Please operate on the originally placed Swap gate")
                    elseif wielded_item:get_name() == "circuit_blocks:swap_tool" then
                        if block.get_swap() == -1 then
                            if block:get_node_name():sub(-5) ~= "_mate" then
                                -- Attempt to place a swap qubit
                                placed_wire = circuit_blocks:place_swap_qubit(block,
                                        block:get_node_wire_num() + 1, player)
                            end
                        elseif block.get_swap() == block:get_node_wire_num() - 1 then
                            if block:get_ctrl_a() == -1 then
                                -- User removing swap qubit
                                circuit_blocks:remove_swap_qubit(block,
                                        block.get_swap(), player)
                            end
                        else
                            -- User moving swap qubit DOWN
                            local pos_y = block.get_circuit_num_wires() - block.get_swap() + block:get_circuit_pos().y
                            local swap_pos = {x = pos.x, y = pos_y, z = pos.z}
                            if block.get_swap() + 1 <= block.get_circuit_num_wires() then
                                if block.get_swap() < block.get_node_wire_num() then
                                    -- Replace with empty block if swap mate is moving toward the gate
                                    circuit_blocks:set_node_with_circuit_specs_meta(swap_pos,
                                            "circuit_blocks:circuit_blocks_empty_wire", player)
                                end
                                placed_wire = circuit_blocks:place_swap_qubit(block,
                                        block.get_swap() + 1, player)
                            else
                                if LOG_DEBUG then
                                    minetest.debug("Tried to place swap on unavailable wire: " ..
                                            block.get_swap() + 1)
                                end
                            end
                        end
                    elseif wielded_item:get_name() == "circuit_blocks:control_tool" then
                        if block.get_ctrl_a() == -1 then
                            -- Attempt to place a ctrl qubit
                            placed_wire = circuit_blocks:place_ctrl_swap_qubit(block,
                                    block:get_node_wire_num() + 1, player)
                        elseif block.get_ctrl_a() == block:get_node_wire_num() - 1 then
                            -- User removing control qubit
                            circuit_blocks:remove_ctrl_swap_qubit(block,
                                    block.get_ctrl_a(), player)
                        elseif block.get_ctrl_a() ~= -1 then
                            -- User moving control qubit a
                            local pos_y = block.get_circuit_num_wires() - block.get_ctrl_a() + block:get_circuit_pos().y
                            local ctrl_pos = {x = pos.x, y = pos_y, z = pos.z}
                            if block.get_ctrl_a() + 1 <= block.get_circuit_num_wires() and
                                    block.get_ctrl_a() + 1 ~= block.get_swap() then
                                if block:get_ctrl_a() + 1 > block:get_swap() and
                                        block:get_ctrl_a() + 1 < block:get_node_wire_num() then
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                            "circuit_blocks:circuit_blocks_trace", player)
                                else
                                    circuit_blocks:set_node_with_circuit_specs_meta(ctrl_pos,
                                            "circuit_blocks:circuit_blocks_empty_wire", player)
                                end
                                placed_wire = circuit_blocks:place_ctrl_swap_qubit(block,
                                        block.get_ctrl_a() + 1, player)
                            else
                                if LOG_DEBUG then
                                    minetest.debug("Tried to place ctrl_a on unavailable wire: " ..
                                            block.get_ctrl_a() + 1)
                                end
                            end
                        end
                    end

                elseif node_type == CircuitNodeTypes.C_IF then
                    local node_name = block.get_node_name()
                    local register_idx = tonumber(node_name:sub(35, 35))
                    local eq_val = tonumber(node_name:sub(39, 39))

                    -- Toggle the equals value between 0 and 1, incrementing the register index as appropriate
                    eq_val = (eq_val + 1) % 2
                    if eq_val == 0 then
                        register_idx = (register_idx + 1) %
                                (math.min(MAX_C_IF_WIRES, block.get_circuit_num_wires()))
                    end

                    local new_node_name = "circuit_blocks:circuit_blocks_if_c" ..
                            tostring(register_idx) .. "_eq" .. tostring(eq_val)
                    minetest.swap_node(block.get_node_pos(), {name = new_node_name})

                elseif node_type == CircuitNodeTypes.EMPTY then
                    -- TODO: Perhaps use naming convention that indicates this is a gate
                    -- TODO: Make referencing wielded item consistent in this function
                    if wielded_item:get_name() == "circuit_blocks:circuit_blocks_wire_connector_m" then
                        -- Only allow placement on rightmost column
                        -- Assume dir_str is "+Z"
                        local is_rightmost_column = block.get_circuit_pos().x +
                                block.get_circuit_num_columns() - 1 == block.get_node_pos().x
                        if circuit_dir_str == "+X" then
                            is_rightmost_column = block.get_circuit_pos().z -
                                    block.get_circuit_num_columns() + 1 == block.get_node_pos().z
                        elseif circuit_dir_str == "-X" then
                            is_rightmost_column = block.get_circuit_pos().z +
                                    block.get_circuit_num_columns() - 1 == block.get_node_pos().z
                        elseif circuit_dir_str == "-Z" then
                            is_rightmost_column = block.get_circuit_pos().x -
                                    block.get_circuit_num_columns() + 1 == block.get_node_pos().x
                        end

                        if is_rightmost_column then
                            circuit_blocks:set_node_with_circuit_specs_meta(pos,
                                    wielded_item:get_name(), player)
                        else
                            minetest.chat_send_player(player:get_player_name(),
                                    "Wire connector may only be placed on rightmost column")
                        end
                    elseif wielded_item:get_name() == "circuit_blocks:circuit_blocks_qubit_bloch_blank" then
                        -- TODO: Try using node_type == ... instead
                        -- Only allow placement on penultimate and rightmost and column
                        -- Assume dir_str is "+Z"
                        local is_rightmost_columns = block.get_circuit_pos().x +
                                block.get_circuit_num_columns() - 2 <= block.get_node_pos().x
                        if circuit_dir_str == "+X" then
                            is_rightmost_columns = block.get_circuit_pos().z -
                                    block.get_circuit_num_columns() + 2 == block.get_node_pos().z
                        elseif circuit_dir_str == "-X" then
                            is_rightmost_columns = block.get_circuit_pos().z +
                                    block.get_circuit_num_columns() - 2 == block.get_node_pos().z
                        elseif circuit_dir_str == "-Z" then
                            is_rightmost_columns = block.get_circuit_pos().x -
                                    block.get_circuit_num_columns() + 2 == block.get_node_pos().x
                        end

                        if is_rightmost_columns then
                            circuit_blocks:set_node_with_circuit_specs_meta(pos,
                                    wielded_item:get_name(), player)
                        else
                            minetest.chat_send_player(player:get_player_name(),
                                    "Bloch sphere display may only be placed on the two rightmost columns")
                        end
                    elseif wielded_item:get_name() == "circuit_blocks:control_tool" then
                        minetest.chat_send_player(player:get_player_name(),
                                "Control tool may only be used on X, Y, Z, H and SWAP gates")
                    elseif wielded_item:get_name() == "circuit_blocks:rotate_tool" then
                        minetest.chat_send_player(player:get_player_name(),
                                "Rotate tool may only be used on X, Y and Z gates")
                    elseif wielded_item:get_name() == "circuit_blocks:swap_tool" then
                        minetest.chat_send_player(player:get_player_name(),
                                "Swap tool may only be used on SWAP gates")
                    elseif wielded_item:get_name():sub(1, 14) == "circuit_blocks" and
                        wielded_item:get_name():sub(1, 16) ~= "circuit_blocks:_" then
                        circuit_blocks:set_node_with_circuit_specs_meta(pos,
                                wielded_item:get_name(), player)

                        -- Set radians to pi if X, Y or Z gate placed
                        if wielded_item:get_name():sub(1, 36) == "circuit_blocks:circuit_blocks_x_gate" or
                                wielded_item:get_name():sub(1, 36) == "circuit_blocks:circuit_blocks_y_gate" or
                                wielded_item:get_name():sub(1, 36) == "circuit_blocks:circuit_blocks_z_gate" then
                            block.set_radians(math.pi)
                        end
                    end
                end

                circuit_blocks:debug_node_info(pos,
                        "Right-clicked node info")
            end

            if block.is_within_circuit_grid() then
                local q_command_pos = block.get_q_command_pos()

                if block.get_node_type() == CircuitNodeTypes.MEASURE_Z or
                        block.get_node_type() == CircuitNodeTypes.BLOCH_SPHERE then
                    local new_node_name = nil

                    -- TODO: Remove
                    minetest.punch_node(q_command_pos)

                    if not player:get_player_control().aux1 then
                        -- TODO: Put back
                        --[
                        -- Use cat measure textures if measure block is cat-related
                        new_node_name = "circuit_blocks:circuit_blocks_measure_z"
                        if block.get_node_name():sub(1, 47) ==
                                "circuit_blocks:circuit_blocks_measure_alice_cat" then
                            new_node_name = "circuit_blocks:circuit_blocks_measure_alice_cat"
                        elseif block.get_node_name():sub(1, 45) ==
                                "circuit_blocks:circuit_blocks_measure_bob_cat" then
                            new_node_name = "circuit_blocks:circuit_blocks_measure_bob_cat"
                        end
                        circuit_blocks:set_node_with_circuit_specs_meta(pos,
                                new_node_name, player)
                        --]]

                        -- Also indicate that the qasm_simulator should be run, without state tomography
                        --q_command:get_q_command_block(q_command_pos).set_qasm_simulator_flag(1)
                        --q_command:get_q_command_block(q_command_pos).set_state_tomography_basis(0)
                        --minetest.punch_node(q_command_pos)
                    else
                        q_command:get_q_command_block(q_command_pos).set_bloch_present_flag(1)
                        new_node_name = "circuit_blocks:circuit_blocks_qubit_bloch_blank"
                        circuit_blocks:set_node_with_circuit_specs_meta(pos,
                                new_node_name, player)
                    end

                    --minetest.debug("User requested measurement, measurement block present: " ..
                    --q_command:get_q_command_block(q_command_pos).get_measure_present_flag() ..
                    --", Bloch sphere block present: " ..
                    --q_command:get_q_command_block(q_command_pos).get_bloch_present_flag())

                    if q_command:get_q_command_block(q_command_pos).get_bloch_present_flag() == 1 then
                        -- Nil the tomo measurement data
                        q_command:get_q_command_block(q_command_pos).set_qasm_data_json_for_1k_x_basis_meas(nil)
                        q_command:get_q_command_block(q_command_pos).set_qasm_data_json_for_1k_y_basis_meas(nil)
                        q_command:get_q_command_block(q_command_pos).set_qasm_data_json_for_1k_z_basis_meas(nil)

                        -- Indicate that the qasm_simulator should be run, with state tomography,
                        -- beginning with the X measurement basis (1 is X)
                        -- TODO: Make constants for these?

                        q_command:get_q_command_block(q_command_pos).set_qasm_simulator_flag(1)
                        q_command:get_q_command_block(q_command_pos).set_state_tomography_basis(1)
                        minetest.punch_node(q_command_pos)

                        q_command:get_q_command_block(q_command_pos).set_qasm_simulator_flag(1)
                        q_command:get_q_command_block(q_command_pos).set_state_tomography_basis(2)
                        minetest.punch_node(q_command_pos)

                        q_command:get_q_command_block(q_command_pos).set_qasm_simulator_flag(1)
                        q_command:get_q_command_block(q_command_pos).set_state_tomography_basis(3)
                        minetest.punch_node(q_command_pos)
                    end

                    -- Also indicate that the qasm_simulator should be run, without state tomography?
                    --circuit_blocks:set_node_with_circuit_specs_meta(pos,
                    --        orig_node_name, player)
                    q_command:get_q_command_block(q_command_pos).set_qasm_simulator_flag(1)
                    q_command:get_q_command_block(q_command_pos).set_state_tomography_basis(0)
                    minetest.punch_node(q_command_pos)
                else
                    -- Punch the q_command block to run simulator and update resultant displays
                    minetest.punch_node(q_command_pos)
                end
            end

            return
        end
    })
end

