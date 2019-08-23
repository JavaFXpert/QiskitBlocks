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

-- Quantum control block that creates circuit, etc.

-- intllib support
local S
if (minetest.get_modpath("intllib")) then
	S = intllib.Getter()
else
  S = function ( s ) return s end
end

LOG_DEBUG = false

local qiskit_service_host = minetest.settings:get("qiskit_service_host") or
        "https://qiskit-blocks-service.herokuapp.com"

local qiskit_service_timeout = tonumber(minetest.settings:get("qiskit_service_timeout")) or 10

dofile(minetest.get_modpath("q_command").."/dkjson.lua");
dofile(minetest.get_modpath("q_command").."/url_code.lua");
dofile(minetest.get_modpath("q_command").."/complex_module.lua");
dofile(minetest.get_modpath("q_command").."/wire_extension.lua");


request_http_api = minetest.request_http_api()
if LOG_DEBUG then
    minetest.debug("request_http_api: " .. dump(request_http_api))
end

complex = create_complex()

BASIS_STATE_BLOCK_MAX_QUBITS = 4
CIRCUIT_MAX_WIRES = 8
CIRCUIT_MAX_COLUMNS = 64

-- Background music IDs
MUSIC_CHILL = 1
MUSIC_ACTIVE = 2
MUSIC_EXCITED = 3
MUSIC_CONGRATS = 4

-- our API object
q_command = {}

q_command.block_pos = {}
q_command.circuit_specs = {} -- dir_str, pos, num_wires, num_columns, is_on_grid
q_command.circuit_specs.pos = {} -- x, y, z


-- returns q_command object or nil
function q_command:get_q_command_block(pos)
	local node_name = minetest.get_node(pos).name
	if minetest.registered_nodes[node_name] then

        -- Retrieve metadata
        local meta = minetest.get_meta(pos)
        -- local node_type = meta:get_int("node_type")
        local circuit_dir_str = meta:get_string("circuit_specs_dir_str")
        local circuit_pos_x = meta:get_int("circuit_specs_pos_x")
        local circuit_pos_y = meta:get_int("circuit_specs_pos_y")
        local circuit_pos_z = meta:get_int("circuit_specs_pos_z")

        -- Flag that indicates whether to run qasm_simulator on next on_punch()
        -- 0 means don't run
        local qasm_simulator_flag = meta:get_int("qasm_simulator_flag")

        -- Variable that indicates whether to run state tomography, and if so,
        -- on which measurement basis currently
        -- 1: X, 2: Y, 3: Z, 0: Don't run state tomography
        local state_tomography_basis = meta:get_int("state_tomography_basis")

        -- JSON data returned from tomography measurements in x, y and z bases
        local qasm_data_json_for_1k_x_basis_meas = meta:get_string("qasm_data_json_for_1k_x_basis_meas")
        local qasm_data_json_for_1k_y_basis_meas = meta:get_string("qasm_data_json_for_1k_y_basis_meas")
        local qasm_data_json_for_1k_z_basis_meas = meta:get_string("qasm_data_json_for_1k_z_basis_meas")

        -- Indicator that Bloch sphere block is present in circuit
        local bloch_present_flag = meta:get_int("bloch_present_flag")

        -- Indicator that measurement sphere block is present in circuit
        local measure_present_flag = meta:get_int("measure_present_flag")

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

            -- Get qasm simulator flag, integer
            get_qasm_simulator_flag = function()
				qasm_simulator_flag = meta:get_int("qasm_simulator_flag")
                return qasm_simulator_flag
			end,

            -- Set qasm simulator flag, integer
            set_qasm_simulator_flag = function(zero_one)
                qasm_simulator_flag = zero_one
                meta:set_int("qasm_simulator_flag", zero_one)
			end,

            -- Get current state tomography basis, integer
            -- 1: X, 2: Y, 3: Z, 0: Don't run state tomography
            get_state_tomography_basis = function()
                state_tomography_basis = meta:get_int("state_tomography_basis")
				return state_tomography_basis
			end,

            -- Set current state tomography basis, integer
            -- 1: X, 2: Y, 3: Z, 0: Don't run state tomography
            set_state_tomography_basis = function(state_tomography_basis_num)
                state_tomography_basis = state_tomography_basis_num
                meta:set_int("state_tomography_basis", state_tomography_basis_num)
			end,


            -- Get JSON results of tomography x-basis measurements
            get_qasm_data_json_for_1k_x_basis_meas = function()
                qasm_data_json_for_1k_x_basis_meas = meta:get_string("qasm_data_json_for_1k_x_basis_meas")
                return qasm_data_json_for_1k_x_basis_meas
            end,

            -- Set JSON results of tomography x-basis measurements
            set_qasm_data_json_for_1k_x_basis_meas = function(qasm_data_json)
                qasm_data_json_for_1k_x_basis_meas = qasm_data_json
                meta:set_string("qasm_data_json_for_1k_x_basis_meas",
                        qasm_data_json)
            end,


            -- Get JSON results of tomography y-basis measurements
            get_qasm_data_json_for_1k_y_basis_meas = function()
                qasm_data_json_for_1k_y_basis_meas = meta:get_string("qasm_data_json_for_1k_y_basis_meas")
                return qasm_data_json_for_1k_y_basis_meas
            end,

            -- Set JSON results of tomography y-basis measurements
            set_qasm_data_json_for_1k_y_basis_meas = function(qasm_data_json)
                qasm_data_json_for_1k_y_basis_meas = qasm_data_json
                meta:set_string("qasm_data_json_for_1k_y_basis_meas",
                        qasm_data_json)
            end,


            -- Get JSON results of tomography z-basis measurements
            get_qasm_data_json_for_1k_z_basis_meas = function()
                qasm_data_json_for_1k_z_basis_meas = meta:get_string("qasm_data_json_for_1k_z_basis_meas")
                return qasm_data_json_for_1k_z_basis_meas
            end,

            -- Set JSON results of tomography z-basis measurements
            set_qasm_data_json_for_1k_z_basis_meas = function(qasm_data_json)
                qasm_data_json_for_1k_z_basis_meas = qasm_data_json
                meta:set_string("qasm_data_json_for_1k_z_basis_meas",
                        qasm_data_json)
            end,


            -- Get measure block present flag, integer
            get_measure_present_flag = function()
				measure_present_flag = meta:get_int("measure_present_flag")
                return measure_present_flag
			end,

            -- Set measure block present flag, integer
            set_measure_present_flag = function(zero_one)
                measure_present_flag = zero_one
                meta:set_int("measure_present_flag", zero_one)
			end,


            -- Get Bloch sphere block present flag, integer
            get_bloch_present_flag = function()
				bloch_present_flag = meta:get_int("bloch_present_flag")
                return bloch_present_flag
			end,

            -- Set Bloch sphere present flag, integer
            set_bloch_present_flag = function(zero_one)
                bloch_present_flag = zero_one
                meta:set_int("bloch_present_flag", zero_one)
			end,


            -- Determine if circuit grid exists
            --
            circuit_grid_exists = function()
                local ret_exists = false
                if circuit_pos_x ~= 0 or circuit_pos_y ~= 0 or circuit_pos_z ~= 0 then
                    -- TODO: Close the loophole where the origin of a circuit is on 0,0,0
                    --       (or make it an Easter egg)
                    ret_exists = true
                end
				return ret_exists
			end,


            -- Compute ratio (numerator / 1) of |0> measurements in a given basis (X:1, Y:2, Z:3)
            compute_meas_ket_0_ratio = function(meas_basis, wire_num)
                local q_block = q_command:get_q_command_block(pos)
                local qasm_data = nil
                if meas_basis == 1 then
                    qasm_data = meta:get_string("qasm_data_json_for_1k_x_basis_meas")
                elseif meas_basis == 2 then
                    qasm_data = meta:get_string("qasm_data_json_for_1k_y_basis_meas")
                elseif meas_basis == 3 then
                    qasm_data = meta:get_string("qasm_data_json_for_1k_z_basis_meas")
                end

                if qasm_data and qasm_data ~= "" and q_block:circuit_grid_exists() then
                    -- TODO: Finish this logic
                    local circuit_block = circuit_blocks:get_circuit_block(q_block:get_circuit_pos())
                    local num_wires = circuit_block.get_circuit_num_wires()
                    local bit_str_idx = num_wires + 1 - wire_num

                    local basis_state_bit_str = nil
                    local num_zeros = 0
                    local num_ones_and_zeros = 0


                    local obj, pos, err = json.decode (qasm_data, 1, nil)
                    if err then
                        minetest.debug ("Error in compute_meas_ket_0_ratio:", err)
                        return nil
                    else
                        local basis_freq = obj.result
                        if LOG_DEBUG then
                            minetest.debug("basis_freq:\n" .. dump(basis_freq))
                        end

                        for key, val in pairs(basis_freq) do
                            basis_state_bit_str = key:gsub("%s+", "")
                            local meas_bit = string.sub(basis_state_bit_str, bit_str_idx, bit_str_idx)
                            if meas_bit == "0" then
                                num_zeros = num_zeros + val
                            end
                            num_ones_and_zeros = num_ones_and_zeros + val
                            --minetest.debug("key: " .. basis_state_bit_str .. ", val: " .. val)
                        end
                        --minetest.debug("num_zeros: " .. num_zeros .. ", num_ones_and_zeros: " .. num_ones_and_zeros)
                    end

                    return num_zeros / num_ones_and_zeros

                else
                    return nil
                end
            end,

            compute_yz_pi_8_rots_by_meas_ratios = function(x_basis_ratio, y_basis_ratio, z_basis_ratio)
                local y_pi8rot = nil
                local z_pi8rot = nil
                local entangled = false

                if x_basis_ratio and y_basis_ratio and z_basis_ratio then
                    -- Origin of sphere is 0, 0, 0
                    local x_coord = x_basis_ratio - 0.5
                    local y_coord = y_basis_ratio - 0.5
                    local z_coord = z_basis_ratio - 0.5

                    if LOG_DEBUG then
                        minetest.debug("x_coord: " .. tostring(x_coord) ..
                               ", y_coord: " .. tostring(y_coord) ..
                               ", z_coord: " .. tostring(z_coord))
                    end

                    local radius = math.sqrt(x_coord^2 + y_coord^2 + z_coord^2)

                    -- Protect against divide by zero error and do polar calculations
                    if radius ~= 0 and x_coord ~= 0 then
                        local polar_rads = math.acos(z_coord / radius)
                        local azimuth_rads = math.atan(y_coord / x_coord)

                        polar_rads = (polar_rads + (2 * math.pi)) % (2 * math.pi)
                        if x_coord < 0.0 then
                            azimuth_rads = azimuth_rads + math.pi
                        end
                        azimuth_rads = (azimuth_rads + (2 * math.pi)) % (2 * math.pi)

                        y_pi8rot = math.floor(polar_rads * 8 / math.pi + .5)
                        z_pi8rot = math.floor(azimuth_rads * 8 / math.pi + .5) % 16
                    end

                    -- TODO: Find more reliable determination of entanglement
                    if radius < 0.47 then
                        entangled = true
                    end
                end
                return y_pi8rot, z_pi8rot, entangled
            end,


            -- Create string representation
            -- TODO: What is Lua way to implement a "to string" function?
            to_string = function()
                local ret_str = "pos: " .. dump(pos) .. "\n" ..
                        "node_name: " .. node_name .. "\n" ..
                        "circuit_dir_str: " .. circuit_dir_str .. "\n" ..
                        "circuit_pos_x: " .. tostring(circuit_pos_x) .. "\n" ..
                        "circuit_pos_y: " .. tostring(circuit_pos_y) .. "\n" ..
                        "circuit_pos_z: " .. tostring(circuit_pos_z) .. "\n" ..
                        "qasm_simulator_flag: " .. tostring(qasm_simulator_flag) .. "\n" ..
                        "state_tomography_basis: " .. tostring(state_tomography_basis) .. "\n" ..
                        "qasm_data_json_for_1k_x_basis_meas: " ..
                        tostring(qasm_data_json_for_1k_x_basis_meas) .. "\n" ..
                        "qasm_data_json_for_1k_y_basis_meas: " ..
                        tostring(qasm_data_json_for_1k_y_basis_meas) .. "\n" ..
                        "qasm_data_json_for_1k_z_basis_meas: " ..
                        tostring(qasm_data_json_for_1k_z_basis_meas) .. "\n"
                return ret_str
            end
		}
	else
		return nil
	end
end


function q_command:debug_node_info(pos, message)
    if not LOG_DEBUG then return end

    local block = q_command:get_q_command_block(pos)
    minetest.debug("to_string:\n" .. dump(block.to_string()))
    minetest.debug((message or "") .. "\ncircuit_block:\n" ..
        "get_node_pos() " .. dump(block.get_node_pos()) .. "\n" ..
        "get_node_name() " .. dump(block.get_node_name()) .. "\n" ..
        "circuit_grid_exists() " .. dump(block.circuit_grid_exists()) .. "\n" ..
        "get_circuit_dir_str() " .. block.get_circuit_dir_str() .. "\n" ..
        "get_circuit_pos() " .. dump(block.get_circuit_pos()) .. "\n")

end

--[[
    Computes player direction string +X, -X, +Z, or -Z
    TODO: Consider creating utils and moving this function there
--]]
function q_command:player_horiz_direction_string(player)
    local ret_dir = "+Z"
        local horiz_dir = player:get_look_horizontal()
    if horiz_dir > math.pi / 4 and horiz_dir <= 3*math.pi / 4 then
        ret_dir = "-X"
    elseif horiz_dir > 3*math.pi / 4 and horiz_dir <= 5*math.pi / 4 then
        ret_dir = "-Z"
    elseif horiz_dir > 5*math.pi / 4 and horiz_dir <= 7*math.pi / 4 then
        ret_dir = "+X"
    end

    return ret_dir
end


function q_command:create_blank_circuit_grid()
    local circuit_num_wires = q_command.circuit_specs.num_wires
    local circuit_num_columns = q_command.circuit_specs.num_columns

    -- Must be 0 for the circuit grid. This variable is
    -- to be used by wire extension to indicate which wire
    -- is being extended
    local circuit_specs_wire_num_offset = 0

    for wire = 1, circuit_num_wires do
        for column = 1, circuit_num_columns do
            local node_pos = {}
            node_pos.y = q_command.circuit_specs.pos.y + circuit_num_wires - wire

            -- Assume dir_str is "+Z"
            local param2_dir = 0
            node_pos.x = q_command.circuit_specs.pos.x + column - 1
            node_pos.z = q_command.circuit_specs.pos.z

            if q_command.circuit_specs.dir_str == "+X" then
                param2_dir = 1
                node_pos.x = q_command.circuit_specs.pos.x
                node_pos.z = q_command.circuit_specs.pos.z - column + 1
            elseif q_command.circuit_specs.dir_str == "-X" then
                param2_dir = 3
                node_pos.x = q_command.circuit_specs.pos.x
                node_pos.z = q_command.circuit_specs.pos.z + column - 1
            elseif q_command.circuit_specs.dir_str == "-Z" then
                param2_dir = 2
                node_pos.x = q_command.circuit_specs.pos.x - column + 1
                node_pos.z = q_command.circuit_specs.pos.z
            end


            -- Put [0> blocks to the left of the circuit
            if column == 1 then
                local ket_pos = {x = node_pos.x - 1, y = node_pos.y, z = node_pos.z}

                if q_command.circuit_specs.dir_str == "+X" then
                    ket_pos = {x = node_pos.x, y = node_pos.y, z = node_pos.z + 1}
                elseif q_command.circuit_specs.dir_str == "-X" then
                    ket_pos = {x = node_pos.x, y = node_pos.y, z = node_pos.z - 1}
                elseif q_command.circuit_specs.dir_str == "-Z" then
                    ket_pos = {x = node_pos.x + 1, y = node_pos.y, z = node_pos.z}
                end

                minetest.set_node(ket_pos,
                        {name="circuit_blocks:_qubit_0", param2=param2_dir})
            end

            minetest.set_node(node_pos,
                    {name="circuit_blocks:circuit_blocks_empty_wire", param2=param2_dir})

            -- Update the metadata in these newly created nodes
            local meta = minetest.get_meta(node_pos)
            meta:set_int("circuit_specs_wire_num_offset", circuit_specs_wire_num_offset)
            meta:set_int("circuit_specs_num_wires", circuit_num_wires)
            meta:set_int("circuit_specs_num_columns", circuit_num_columns)
            meta:set_int("circuit_specs_is_on_grid", 1)
            meta:set_string("circuit_specs_dir_str", q_command.circuit_specs.dir_str)
            meta:set_int("circuit_specs_pos_x", q_command.circuit_specs.pos.x)
            meta:set_int("circuit_specs_pos_y", q_command.circuit_specs.pos.y)
            meta:set_int("circuit_specs_pos_z", q_command.circuit_specs.pos.z)
            meta:set_int("q_command_block_pos_x", q_command.block_pos.x)
            meta:set_int("q_command_block_pos_y", q_command.block_pos.y)
            meta:set_int("q_command_block_pos_z", q_command.block_pos.z)
        end
    end
end


function q_command:create_qasm_for_node(circuit_node_pos, wire_num,
                                        include_measurement_blocks, c_if_table, tomo_meas_basis)
    local qasm_str = ""
    local circuit_node_block = circuit_blocks:get_circuit_block(circuit_node_pos)
    local q_block = q_command:get_q_command_block(circuit_node_pos)

    if circuit_node_block then
        local node_type = circuit_node_block.get_node_type()

        if node_type == CircuitNodeTypes.EMPTY or
                node_type == CircuitNodeTypes.TRACE or
                node_type == CircuitNodeTypes.CTRL then
            -- Throw away a c_if if present
            c_if_table[wire_num] = ""
            -- Return immediately with zero length qasm_str
            return qasm_str
        else
            if c_if_table[wire_num] and c_if_table[wire_num] ~= "" then
                qasm_str = qasm_str .. c_if_table[wire_num] .. " "
                c_if_table[wire_num] = ""
            end
        end

        local ctrl_a = circuit_node_block.get_ctrl_a()
        local ctrl_b = circuit_node_block.get_ctrl_b()
        local swap = circuit_node_block.get_swap()

        local radians = circuit_node_block.get_radians()

        -- For convenience and brevity, create a zero-based, string, wire number
        --local wire_num_idx = tostring(wire_num - 1 +
        --        circuit_node_block.get_circuit_specs_wire_num_offset())
        --local ctrl_a_idx = tostring(ctrl_a - 1 +
        --        circuit_node_block.get_circuit_specs_wire_num_offset())
        --local ctrl_b_idx = tostring(ctrl_b - 1 +
        --        circuit_node_block.get_circuit_specs_wire_num_offset())

        -- TODO: Replace above with below?

        local wire_num_idx = tostring(wire_num - 1)
        local ctrl_a_idx = tostring(ctrl_a - 1)
        local ctrl_b_idx = tostring(ctrl_b - 1)
        local swap_idx = tostring(swap - 1)


        if node_type == CircuitNodeTypes.IDEN then
            -- Identity gate
            qasm_str = qasm_str .. 'id q[' .. wire_num_idx .. '];'

        elseif node_type == CircuitNodeTypes.X then
            local threshold = 0.0001
            if math.abs(radians - math.pi) <= threshold then
                if ctrl_a ~= -1 then
                    if ctrl_b ~= -1 then
                        -- Toffoli gate
                        qasm_str = qasm_str .. 'ccx q[' .. ctrl_a_idx .. '],'
                        qasm_str = qasm_str .. 'q[' .. ctrl_b_idx .. '],'
                        qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
                    else
                        -- Controlled X gate
                        qasm_str = qasm_str .. 'cx q[' .. ctrl_a_idx .. '],'
                        qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
                    end
                else
                    -- Pauli-X gate
                    qasm_str = qasm_str .. 'x q[' .. wire_num_idx .. '];'
                end
            else
                -- Rotation around X axis
                qasm_str = qasm_str .. 'rx(' .. tostring(radians) .. ') '
                qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
            end

        elseif node_type == CircuitNodeTypes.Y then
            local threshold = 0.0001
            if math.abs(radians - math.pi) <= threshold then
                if ctrl_a ~= -1 then
                    -- Controlled Y gate
                    qasm_str = qasm_str .. 'cy q[' .. ctrl_a_idx .. '],'
                    qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
                else
                    -- Pauli-Y gate
                    qasm_str = qasm_str .. 'y q[' .. wire_num_idx .. '];'
                end
            else
                -- Rotation around Y axis
                qasm_str = qasm_str .. 'ry(' .. tostring(radians) .. ') '
                qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
            end
        elseif node_type == CircuitNodeTypes.Z then
            local threshold = 0.0001
            if math.abs(radians - math.pi) <= threshold then
                if ctrl_a ~= -1 then
                    -- Controlled Z gate
                    qasm_str = qasm_str .. 'cz q[' .. ctrl_a_idx .. '],'
                    qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
                else
                    -- Pauli-Z gate
                    qasm_str = qasm_str .. 'z q[' .. wire_num_idx .. '];'
                end
            else
                if circuit_node_block.get_ctrl_a() ~= -1 then
                    -- Controlled rotation around the Z axis
                    qasm_str = qasm_str .. 'crz(' .. tostring(radians) .. ') '
                    qasm_str = qasm_str .. 'q[' .. ctrl_a_idx .. '],'
                    qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
                else
                    -- Rotation around Z axis
                    qasm_str = qasm_str .. 'rz(' .. tostring(radians) .. ') '
                    qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
                end
            end

        elseif node_type == CircuitNodeTypes.S then
            -- S gate
            qasm_str = qasm_str .. 's q[' .. wire_num_idx .. '];'
        elseif node_type == CircuitNodeTypes.SDG then
            -- S dagger gate
            qasm_str = qasm_str .. 'sdg q[' .. wire_num_idx .. '];'
        elseif node_type == CircuitNodeTypes.T then
            -- T gate
            qasm_str = qasm_str .. 't q[' .. wire_num_idx .. '];'
        elseif node_type == CircuitNodeTypes.TDG then
            -- T dagger gate
            qasm_str = qasm_str .. 'tdg q[' .. wire_num_idx .. '];'
        elseif node_type == CircuitNodeTypes.H then
            if ctrl_a ~= -1 then
                -- Controlled Hadamard
                qasm_str = qasm_str .. 'ch q[' .. ctrl_a_idx .. '],'
                qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
            else
                -- Hadamard gate
                qasm_str = qasm_str .. 'h q[' .. wire_num_idx .. '];'
            end
        elseif node_type == CircuitNodeTypes.BARRIER then
            -- barrier
            qasm_str = qasm_str .. 'barrier q[' .. wire_num_idx .. '];'
        elseif node_type == CircuitNodeTypes.MEASURE_Z then
            if include_measurement_blocks then
                -- Measurement block
                --qasm_str = qasm_str .. 'measure q[' .. wire_num_idx .. '] -> c[' .. wire_num_idx .. '];'
                qasm_str = qasm_str .. 'measure q[' .. wire_num_idx .. '] -> c' .. wire_num_idx .. '[0];'
            end
        elseif node_type == CircuitNodeTypes.QUBIT_BASIS then
            qasm_str = qasm_str .. 'reset q[' .. wire_num_idx .. '];'
            if circuit_node_block.get_node_name():sub(-2) == "_1" then
                qasm_str = qasm_str .. 'x q[' .. wire_num_idx .. '];'
            end
        elseif node_type == CircuitNodeTypes.CONNECTOR_M then
            -- Connector to wire extension, so traverse
            local wire_extension_block_pos = circuit_node_block.get_wire_extension_block_pos()

            if wire_extension_block_pos.x ~= 0 then
                local wire_extension_block = circuit_blocks:get_circuit_block(wire_extension_block_pos)
                local wire_extension_dir_str = wire_extension_block.get_circuit_dir_str()
                local wire_extension_circuit_pos = wire_extension_block.get_circuit_pos()

                if wire_extension_circuit_pos.x ~= 0 then
                    local wire_extension_circuit = circuit_blocks:get_circuit_block(wire_extension_circuit_pos)
                    local extension_wire_num = wire_extension_circuit.get_circuit_specs_wire_num_offset() + 1
                    local extension_num_columns = wire_extension_circuit.get_circuit_num_columns()
                    for column_num = 1, extension_num_columns do

                        -- Assume dir_str is "+Z"
                        local circ_node_pos = {x = wire_extension_circuit_pos.x + column_num - 1,
                                               y = wire_extension_circuit_pos.y,
                                               z = wire_extension_circuit_pos.z}

                        if wire_extension_dir_str == "+X" then
                            circ_node_pos = {x = wire_extension_circuit_pos.x,
                                                y = wire_extension_circuit_pos.y,
                                                z = wire_extension_circuit_pos.z - column_num + 1}
                        elseif wire_extension_dir_str == "-X" then
                            circ_node_pos = {x = wire_extension_circuit_pos.x,
                                                y = wire_extension_circuit_pos.y,
                                                z = wire_extension_circuit_pos.z + column_num - 1}
                        elseif wire_extension_dir_str == "-Z" then
                            circ_node_pos = {x = wire_extension_circuit_pos.x - column_num + 1,
                                                y = wire_extension_circuit_pos.y,
                                                z = wire_extension_circuit_pos.z}
                        end

                        qasm_str = qasm_str ..
                                 q_command:create_qasm_for_node(circ_node_pos,
                                         extension_wire_num, include_measurement_blocks,
                                         c_if_table, tomo_meas_basis)
                    end
                end
            end

        elseif node_type == CircuitNodeTypes.SWAP and swap ~= -1 then
            if ctrl_a ~= -1 then
                -- Controlled Swap
                qasm_str = qasm_str .. 'cswap q[' .. ctrl_a_idx .. '],'
                qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '],'
                qasm_str = qasm_str .. 'q[' .. swap_idx .. '];'
            else
                -- Swap gate
                qasm_str = qasm_str .. 'swap q[' .. wire_num_idx .. '],'
                qasm_str = qasm_str .. 'q[' .. swap_idx .. '];'
            end

        elseif node_type == CircuitNodeTypes.C_IF then
            local node_name = circuit_node_block.get_node_name()
            local register_idx_str = node_name:sub(35, 35)
            local eq_val_str = node_name:sub(39, 39)
            c_if_table[wire_num] = "if(c" .. register_idx_str .. "==" ..
                    eq_val_str .. ")"

        elseif node_type == CircuitNodeTypes.BLOCH_SPHERE then
            if include_measurement_blocks then
                if tomo_meas_basis == 1 then
                    -- Measure in the X basis (by first rotating -pi/2 radians on Y axis)
                    qasm_str = qasm_str .. 'ry(' .. tostring(-math.pi / 2) .. ') '
                    qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
                elseif tomo_meas_basis == 2 then
                    -- Measure in the Y basis (by first rotating pi/2 radians on X axis)
                    qasm_str = qasm_str .. 'rx(' .. tostring(math.pi / 2) .. ') '
                    qasm_str = qasm_str .. 'q[' .. wire_num_idx .. '];'
                elseif tomo_meas_basis == 3 then
                    -- Measure in the Z basis (no rotation necessary)
                end
                qasm_str = qasm_str .. 'measure q[' .. wire_num_idx .. '] -> c' .. wire_num_idx .. '[0];'
            end
        end

    else
        print("Unknown gate!")
    end

    if LOG_DEBUG then
        minetest.debug("End of create_qasm_for_node(), qasm_str:\n" .. qasm_str)
    end
    return qasm_str
end

function q_command:compute_circuit(circuit_block, include_measurement_blocks, tomo_meas_basis)
    local num_wires = circuit_block.get_circuit_num_wires()
    local num_columns = circuit_block.get_circuit_num_columns()
    local circuit_dir_str = circuit_block.get_circuit_dir_str()
    local circuit_pos_x = circuit_block.get_circuit_pos().x
    local circuit_pos_y = circuit_block.get_circuit_pos().y
    local circuit_pos_z = circuit_block.get_circuit_pos().z

    -- Holds conditional if statements for each wire
    local c_if_table = {}

    local qasm_str = 'OPENQASM 2.0;include "qelib1.inc";'

    qasm_str = qasm_str .. 'qreg q[' .. tostring(num_wires) .. '];'

    -- Create a classical register for each qubit
    for wire_num = 1, num_wires do
        qasm_str = qasm_str .. 'creg c' .. tostring(wire_num - 1) .. '[1];'
    end

    -- Add a column of identity gates to protect simulators from an empty circuit
    qasm_str = qasm_str .. 'id q;'


    for column_num = 1, num_columns do
        for wire_num = 1, num_wires do

            -- Assume dir_str is "+Z"
            local circuit_node_pos = {x = circuit_pos_x + column_num - 1,
                                      y = circuit_pos_y + num_wires - wire_num,
                                      z = circuit_pos_z}

            if circuit_dir_str == "+X" then
                circuit_node_pos = {x = circuit_pos_x,
                                    y = circuit_pos_y + num_wires - wire_num,
                                    z = circuit_pos_z - column_num + 1}
            elseif circuit_dir_str == "-X" then
                circuit_node_pos = {x = circuit_pos_x,
                                    y = circuit_pos_y + num_wires - wire_num,
                                    z = circuit_pos_z + column_num - 1}
            elseif circuit_dir_str == "-Z" then
                circuit_node_pos = {x = circuit_pos_x - column_num + 1,
                                      y = circuit_pos_y + num_wires - wire_num,
                                      z = circuit_pos_z}
            end



            qasm_str = qasm_str .. q_command:create_qasm_for_node(circuit_node_pos, wire_num,
                    include_measurement_blocks, c_if_table, tomo_meas_basis)
        end
    end

    if LOG_DEBUG then
        minetest.debug("qasm_str:\n" .. qasm_str)
    end

    return qasm_str
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
    if(formname == "create_circuit_grid") then
        if fields.num_wires_str and fields.num_columns_str then
            local num_wires = tonumber(fields.num_wires_str)
            local num_columns = tonumber(fields.num_columns_str)
            local start_z_offset = 0
            local start_x_offset = -1
            local start_y_offset = 1

            local horiz_dir_str = q_command:player_horiz_direction_string(player)

            if num_wires and num_wires >= 1 and num_wires <= CIRCUIT_MAX_WIRES and
                    num_columns and num_columns >= 1 and num_columns <= CIRCUIT_MAX_COLUMNS and
                    start_z_offset and start_z_offset >= 0 and
                    start_x_offset then
                -- Store direction string, position of left-most, bottom-most block, and dimensions of circuit
                q_command.circuit_specs.dir_str = horiz_dir_str

                q_command.circuit_specs.pos.y = q_command.block_pos.y + start_y_offset

                -- Assume dir_str is "+Z"
                q_command.circuit_specs.pos.x = q_command.block_pos.x - start_x_offset
                q_command.circuit_specs.pos.z = q_command.block_pos.z + start_z_offset

                if q_command.circuit_specs.dir_str == "+X" then
                    q_command.circuit_specs.pos.x = q_command.block_pos.x + start_z_offset
                    q_command.circuit_specs.pos.z = q_command.block_pos.z + start_x_offset
                elseif q_command.circuit_specs.dir_str == "-X" then
                    q_command.circuit_specs.pos.x = q_command.block_pos.x - start_z_offset
                    q_command.circuit_specs.pos.z = q_command.block_pos.z - start_x_offset
                elseif q_command.circuit_specs.dir_str == "-Z" then
                    q_command.circuit_specs.pos.x = q_command.block_pos.x + start_x_offset
                    q_command.circuit_specs.pos.z = q_command.block_pos.z - start_z_offset
                end

                q_command.circuit_specs.num_wires = num_wires
                q_command.circuit_specs.num_columns = num_columns

                -- Create circuit grid with empty blocks
                q_command:create_blank_circuit_grid()

                -- Put direction and location of circuit into the q_command block metadata
                local meta = minetest.get_meta(q_command.block_pos)
                meta:set_string("circuit_specs_dir_str", q_command.circuit_specs.dir_str)
                meta:set_int("circuit_specs_pos_x", q_command.circuit_specs.pos.x)
                meta:set_int("circuit_specs_pos_y", q_command.circuit_specs.pos.y)
                meta:set_int("circuit_specs_pos_z", q_command.circuit_specs.pos.z)

                -- TODO: Find a better way (that works)
                -- Punch the q_command block (ourself) to run simulator and update resultant displays
                minetest.punch_node(q_command.block_pos)

            else
                -- TODO: Show error message dialog?
                minetest.chat_send_player(player:get_player_name(),
                    "Circuit not created! Max wires is " .. CIRCUIT_MAX_WIRES ..
                            ", max columns is " .. CIRCUIT_MAX_COLUMNS)
            end
            return
        end
    end
end)

function q_command:parse_json_statevector(sv_data)
    local statevector = {}
    local obj, pos, err = json.decode (sv_data, 1, nil)
    if err then
        minetest.debug ("Error in parse_json_statevector:", err)
    else
        local temp_statevector = obj.__ndarray__
        for i = 1,#temp_statevector do
            statevector[i] = complex.new(temp_statevector[i].__complex__[1],
                    temp_statevector[i].__complex__[2])
        end
    end
    return statevector
end

function q_command:register_q_command_block(suffix_correct_solution,
                                            suffix_incorrect_solution,
                                            correct_solution_statevector,
                                            block_represents_correct_solution)
    if not suffix_correct_solution or not suffix_incorrect_solution then
        suffix_incorrect_solution = "default"
        suffix_correct_solution = "default_success"
    end

    if not block_represents_correct_solution then
        block_represents_correct_solution = false
    end

    local texture_correct_solution = "q_command_block_" .. suffix_correct_solution .. ".png"
    local texture_incorrect_solution = "q_command_block_" .. suffix_incorrect_solution .. ".png"

    local q_block_node_name = "q_command:q_block_" .. suffix_incorrect_solution
    local other_q_block_node_name = "q_command:q_block_" .. suffix_correct_solution
    local block_desc = "Q command block " .. suffix_incorrect_solution
    local block_texture = "q_command_block_" .. suffix_incorrect_solution .. ".png"
    if block_represents_correct_solution then
        q_block_node_name = "q_command:q_block_" .. suffix_correct_solution
        other_q_block_node_name = "q_command:q_block_" .. suffix_incorrect_solution
        block_desc = "Q command block " .. suffix_correct_solution
        block_texture = "q_command_block_" .. suffix_correct_solution .. ".png"
    end

    minetest.register_node(q_block_node_name, {
        description = block_desc,
        tiles = {block_texture},
        groups = {oddly_breakable_by_hand=2},
        paramtype2 = "facedir",
        on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            meta:set_string("infotext", "Quantum circuit command block")
            q_command.block_pos = pos

            --minetest.debug("mpd.playing:" .. tostring(mpd.playing))
            if mpd.playing and mpd.playing ~= MUSIC_ACTIVE then
                mpd.play_song(MUSIC_ACTIVE)
            end

        end,
        on_rightclick = function(pos, node, clicker, itemstack)
            local q_block = q_command:get_q_command_block(pos)
            if not q_block:circuit_grid_exists() then
                local player_name = clicker:get_player_name()
                local meta = minetest.get_meta(pos)
                local formspec = "size[5.0, 4.6]"..
                        "field[1.0,0.5;1.8,1.5;num_wires_str;Wires (max " .. CIRCUIT_MAX_WIRES .. ");2]" ..
                        "field[3.0,0.5;1.8,1.5;num_columns_str;Cols (max " .. CIRCUIT_MAX_COLUMNS .. ");4]" ..
                        --"field[1.0,2.0;1.5,1.5;start_z_offset_str;Forward offset:;0]" ..
                        --"field[3.0,2.0;1.5,1.5;start_x_offset_str;Left offset:;-1]" ..
                        "button_exit[1.8,3.5;1.5,1.0;create;Create]"
                minetest.show_formspec(player_name, "create_circuit_grid", formspec)
            else
                if mpd.playing then
                    minetest.chat_send_player(clicker:get_player_name(),
                            "Pausing music")
                    mpd.stop_song()
                else
                    minetest.chat_send_player(clicker:get_player_name(),
                            "Starting music")
                    mpd.play_song(MUSIC_CHILL)
                end
            end
        end,
        on_punch = function(pos, node, player)
            local q_block = q_command:get_q_command_block(pos)
            if q_block:circuit_grid_exists() then

                local circuit_block = circuit_blocks:get_circuit_block(q_block.get_circuit_pos())
                local num_wires = circuit_block.get_circuit_num_wires()
                local num_columns = circuit_block.get_circuit_num_columns()
                local circuit_dir_str = circuit_block.get_circuit_dir_str()
                local circuit_pos_x = circuit_block.get_circuit_pos().x
                local circuit_pos_y = circuit_block.get_circuit_pos().y
                local circuit_pos_z = circuit_block.get_circuit_pos().z

                if player:get_player_control().sneak then
                    -- Delete entire circuit and wire extensions

                    for column_num = 1, num_columns do
                        for wire_num = 1, num_wires do

                            -- Assume dir_str is "+Z"
                            local node_pos = {x = circuit_pos_x + column_num - 1,
                                              y = circuit_pos_y + num_wires - wire_num,
                                              z = circuit_pos_z}

                            if circuit_dir_str == "+X" then
                                node_pos = {x = circuit_pos_x,
                                            y = circuit_pos_y + num_wires - wire_num,
                                            z = circuit_pos_z - column_num + 1}
                            elseif circuit_dir_str == "-X" then
                                node_pos = {x = circuit_pos_x,
                                            y = circuit_pos_y + num_wires - wire_num,
                                            z = circuit_pos_z + column_num - 1}
                            elseif circuit_dir_str == "-Z" then
                                node_pos = {x = circuit_pos_x - column_num + 1,
                                            y = circuit_pos_y + num_wires - wire_num,
                                            z = circuit_pos_z}
                            end

                            -- Delete ket blocks to the left of the circuit
                            if column_num == 1 then
                                local ket_pos = {x = node_pos.x - 1, y = node_pos.y, z = node_pos.z}

                                if circuit_dir_str == "+X" then
                                    ket_pos = {x = node_pos.x, y = node_pos.y, z = node_pos.z + 1}
                                elseif circuit_dir_str == "-X" then
                                    ket_pos = {x = node_pos.x, y = node_pos.y, z = node_pos.z - 1}
                                elseif circuit_dir_str == "-Z" then
                                    ket_pos = {x = node_pos.x + 1, y = node_pos.y, z = node_pos.z}
                                end

                                minetest.remove_node(ket_pos)
                            end

                            -- Delete histogram and basis state blocks at the bottom of the circuit
                            if wire_num == num_wires then
                                local hist_pos = {x = node_pos.x, y = node_pos.y - 1, z = node_pos.z}

                                minetest.remove_node(hist_pos)

                                -- Remove basis state block
                                local basis_state_node_pos = {x = hist_pos.x,
                                                              y = hist_pos.y - 1,
                                                              z = hist_pos.z - 1}

                                if circuit_dir_str == "+X" then
                                    basis_state_node_pos = {x = hist_pos.x - 1,
                                                            y = hist_pos.y - 1,
                                                            z = hist_pos.z}
                                elseif circuit_dir_str == "-X" then
                                    basis_state_node_pos = {x = hist_pos.x + 1,
                                                            y = hist_pos.y - 1,
                                                            z = hist_pos.z}
                                elseif circuit_dir_str == "-Z" then
                                    basis_state_node_pos = {x = hist_pos.x,
                                                            y = hist_pos.y - 1,
                                                            z = hist_pos.z + 1}
                                end

                                if num_wires <= BASIS_STATE_BLOCK_MAX_QUBITS then
                                    minetest.remove_node(basis_state_node_pos)
                                end

                            end

                            local cur_block = circuit_blocks:get_circuit_block(node_pos)
                            if cur_block.get_node_type() == CircuitNodeTypes.CONNECTOR_M then
                                circuit_blocks:delete_wire_extension(cur_block, player)
                            end
                            minetest.remove_node(node_pos)
                        end
                    end

                    -- Remove the q_block
                    minetest.remove_node(pos)

                else

                    local circuit_grid_pos = q_block.get_circuit_pos()
                    local circuit_block = circuit_blocks:get_circuit_block(circuit_grid_pos)

                    local qasm_str = q_command:compute_circuit(circuit_block, false)
                    local qasm_with_measurement_str = q_command:compute_circuit(circuit_block, true)
                    local qasm_with_tomo_x_str = q_command:compute_circuit(circuit_block, true, 1)
                    local qasm_with_tomo_y_str = q_command:compute_circuit(circuit_block, true, 2)
                    local qasm_with_tomo_z_str = q_command:compute_circuit(circuit_block, true, 3)

                    local http_request_statevector = {
                        url = qiskit_service_host .. "/api/run/statevector?backend=statevector_simulator&qasm=" ..
                                url_code.urlencode(qasm_str),
                        timeout = qiskit_service_timeout
                    }

                    local http_request_qasm = {
                        url = qiskit_service_host .. "/api/run/qasm?backend=qasm_simulator&qasm=" ..
                                url_code.urlencode(qasm_with_measurement_str) .. "&num_shots=1",
                        timeout = qiskit_service_timeout
                    }

                    local http_request_qasm_tomo_x = {
                        url = qiskit_service_host .. "/api/run/qasm?backend=qasm_simulator&qasm=" ..
                                url_code.urlencode(qasm_with_tomo_x_str) .. "&num_shots=1000",
                        timeout = qiskit_service_timeout
                    }

                    local http_request_qasm_tomo_y = {
                        url = qiskit_service_host .. "/api/run/qasm?backend=qasm_simulator&qasm=" ..
                                url_code.urlencode(qasm_with_tomo_y_str) .. "&num_shots=1000",
                        timeout = qiskit_service_timeout
                    }

                    local http_request_qasm_tomo_z = {
                        url = qiskit_service_host .. "/api/run/qasm?backend=qasm_simulator&qasm=" ..
                                url_code.urlencode(qasm_with_tomo_z_str) .. "&num_shots=1000",
                        timeout = qiskit_service_timeout
                    }

                    --[[
                    bit_idx is one-based
                    --]]
                    local function bit_is_set(num, num_bits, bit_idx)
                        num_bits = num_bits or math.max(1, select(2, math.frexp(num)))
                        local bits_table = {} -- will contain the bits
                        for b = 1, num_bits do
                            bits_table[b] = math.fmod(num, 2)
                            num = math.floor((num - bits_table[b]) / 2)
                        end
                        return bits_table[bit_idx] == 1
                    end


                    local function update_measure_block(circuit_node_pos, num_wires, wire_num, basis_state_bit_str, reset)
                        local circuit_node_block = circuit_blocks:get_circuit_block(circuit_node_pos)

                        if circuit_node_block then
                            local node_type = circuit_node_block.get_node_type()
                            if node_type == CircuitNodeTypes.MEASURE_Z then
                                q_block.set_measure_present_flag(1)
                                local new_node_name = nil
                                if reset then
                                    new_node_name = "circuit_blocks:circuit_blocks_measure_z"

                                    -- Use cat measure textures if measure block is cat-related
                                    if circuit_node_block.get_node_name():sub(1, 47) ==
                                            "circuit_blocks:circuit_blocks_measure_alice_cat" then
                                        new_node_name = "circuit_blocks:circuit_blocks_measure_alice_cat"
                                    elseif circuit_node_block.get_node_name():sub(1, 45) ==
                                            "circuit_blocks:circuit_blocks_measure_bob_cat" then
                                        new_node_name = "circuit_blocks:circuit_blocks_measure_bob_cat"
                                    end
                                else
                                    local bit_str_idx = num_wires + 1 - wire_num
                                    local meas_bit = string.sub(basis_state_bit_str, bit_str_idx, bit_str_idx)
                                    new_node_name = "circuit_blocks:circuit_blocks_measure_" .. meas_bit

                                    -- Use cat measure textures if measure block is cat-related
                                    if circuit_node_block.get_node_name():sub(1, 47) ==
                                            "circuit_blocks:circuit_blocks_measure_alice_cat" then
                                        new_node_name = "circuit_blocks:circuit_blocks_measure_alice_cat_" .. meas_bit
                                    elseif circuit_node_block.get_node_name():sub(1, 45) ==
                                            "circuit_blocks:circuit_blocks_measure_bob_cat" then
                                        new_node_name = "circuit_blocks:circuit_blocks_measure_bob_cat_" .. meas_bit
                                    end
                                end

                                local circuit_dir_str = circuit_node_block.get_circuit_dir_str()
                                local param2_dir = 0
                                if circuit_dir_str == "+X" then
                                    param2_dir = 1
                                elseif circuit_dir_str == "-X" then
                                    param2_dir = 3
                                elseif circuit_dir_str == "-Z" then
                                    param2_dir = 2
                                end
                                minetest.swap_node(circuit_node_pos, {name = new_node_name, param2 = param2_dir})

                            elseif node_type == CircuitNodeTypes.CONNECTOR_M then
                                -- Connector to wire extension, so traverse
                                local wire_extension_block_pos = circuit_node_block.get_wire_extension_block_pos()


                                if LOG_DEBUG then
                                    q_command:debug_node_info(wire_extension_block_pos,
                                            "Processing CONNECTOR_M, wire_extension_block")
                                end

                                if wire_extension_block_pos.x ~= 0 then
                                    local wire_extension_block = circuit_blocks:get_circuit_block(wire_extension_block_pos)
                                    local wire_extension_dir_str = wire_extension_block.get_circuit_dir_str()
                                    local wire_extension_circuit_pos = wire_extension_block.get_circuit_pos()

                                    if LOG_DEBUG then
                                        q_command:debug_node_info(wire_extension_circuit_pos,
                                                "Processing CONNECTOR_M, wire_extension_circuit")
                                    end

                                    if wire_extension_circuit_pos.x ~= 0 then
                                        local wire_extension_circuit = circuit_blocks:get_circuit_block(wire_extension_circuit_pos)
                                        local extension_wire_num = wire_extension_circuit.get_circuit_specs_wire_num_offset() + 1
                                        local extension_num_columns = wire_extension_circuit.get_circuit_num_columns()
                                        for column_num = 1, extension_num_columns do

                                            -- Assume dir_str is "+Z"
                                            local circ_node_pos = {x = wire_extension_circuit_pos.x + column_num - 1,
                                                                   y = wire_extension_circuit_pos.y,
                                                                   z = wire_extension_circuit_pos.z}

                                            if wire_extension_dir_str == "+X" then
                                                circ_node_pos = {x = wire_extension_circuit_pos.x,
                                                                 y = wire_extension_circuit_pos.y,
                                                                 z = wire_extension_circuit_pos.z - column_num + 1}
                                            elseif wire_extension_dir_str == "-X" then
                                                circ_node_pos = {x = wire_extension_circuit_pos.x,
                                                                 y = wire_extension_circuit_pos.y,
                                                                 z = wire_extension_circuit_pos.z + column_num - 1}
                                            elseif wire_extension_dir_str == "-Z" then
                                                circ_node_pos = {x = wire_extension_circuit_pos.x - column_num + 1,
                                                                 y = wire_extension_circuit_pos.y,
                                                                 z = wire_extension_circuit_pos.z}
                                            end

                                            if LOG_DEBUG then
                                                q_command:debug_node_info(circ_node_pos,
                                                        "Processing CONNECTOR_M, circ_node_pos")
                                            end

                                            update_measure_block(circ_node_pos, num_wires, wire_num, basis_state_bit_str, reset)
                                        end
                                    end
                                end
                            end
                        end
                    end


                    local function update_bloch_sphere_block(circuit_node_pos, num_wires, wire_num, reset)
                        local circuit_node_block = circuit_blocks:get_circuit_block(circuit_node_pos)

                        if circuit_node_block then
                            local node_type = circuit_node_block.get_node_type()
                            local new_node_name = "circuit_blocks:circuit_blocks_qubit_bloch_blank"

                            if node_type == CircuitNodeTypes.BLOCH_SPHERE then
                                q_block.set_bloch_present_flag(1)
                                local circuit_dir_str = circuit_node_block.get_circuit_dir_str()
                                local param2_dir = 0
                                if circuit_dir_str == "+X" then
                                    param2_dir = 1
                                elseif circuit_dir_str == "-X" then
                                    param2_dir = 3
                                elseif circuit_dir_str == "-Z" then
                                    param2_dir = 2
                                end

                                if reset then
                                    new_node_name = "circuit_blocks:circuit_blocks_qubit_bloch_blank"
                                    minetest.swap_node(circuit_node_pos, {name = new_node_name, param2 = param2_dir})
                                else
                                    local y_pi8rot = 0
                                    local z_pi8rot = 0
                                    local entangled = false

                                    local x_json = q_block.get_qasm_data_json_for_1k_x_basis_meas(1)
                                    local y_json = q_block.get_qasm_data_json_for_1k_x_basis_meas(2)
                                    local z_json = q_block.get_qasm_data_json_for_1k_x_basis_meas(3)

                                    if x_json and x_json ~= "" and
                                            y_json and y_json ~= "" and
                                            z_json and z_json ~= "" then
                                        y_pi8rot, z_pi8rot, entangled = q_block.compute_yz_pi_8_rots_by_meas_ratios(
                                                q_block.compute_meas_ket_0_ratio(1, wire_num),
                                                q_block.compute_meas_ket_0_ratio(2, wire_num),
                                                q_block.compute_meas_ket_0_ratio(3, wire_num))

                                        if entangled and y_pi8rot and z_pi8rot then
                                            new_node_name = "circuit_blocks:circuit_blocks_qubit_bloch_entangled"
                                            minetest.swap_node(circuit_node_pos, {name = new_node_name, param2 = param2_dir})
                                        elseif y_pi8rot and z_pi8rot then
                                            new_node_name = "circuit_blocks:circuit_blocks_qubit_bloch_y" ..
                                                    y_pi8rot .. "p8_z" .. z_pi8rot .. "p8"
                                            minetest.swap_node(circuit_node_pos, {name = new_node_name, param2 = param2_dir})
                                        else
                                            -- Not all tomo measurements are available
                                            --minetest.debug("y_pi8rot: " .. tostring(y_pi8rot) ..
                                            --        ", z_pi8rot: " .. tostring(z_pi8rot) ..
                                            --        ", entangled: " .. tostring(entangled))
                                        end


                                    else
                                        --minetest.debug("x_json:[" .. x_json .. "]" ..
                                        --        ", y_json:[" .. y_json .. "]" ..
                                        --        ", z_json:[" .. z_json .. "]")
                                    end
                                end



                            elseif node_type == CircuitNodeTypes.CONNECTOR_M then
                                -- Connector to wire extension, so traverse
                                local wire_extension_block_pos = circuit_node_block.get_wire_extension_block_pos()

                                if wire_extension_block_pos.x ~= 0 then
                                    local wire_extension_block = circuit_blocks:get_circuit_block(wire_extension_block_pos)
                                    local wire_extension_dir_str = wire_extension_block.get_circuit_dir_str()
                                    local wire_extension_circuit_pos = wire_extension_block.get_circuit_pos()

                                    q_command:debug_node_info(wire_extension_circuit_pos,
                                            "In update_bloch_sphere_block(), processing CONNECTOR_M, wire_extension_circuit")

                                    if wire_extension_circuit_pos.x ~= 0 then
                                        local wire_extension_circuit = circuit_blocks:get_circuit_block(wire_extension_circuit_pos)
                                        local extension_wire_num = wire_extension_circuit.get_circuit_specs_wire_num_offset() + 1
                                        local extension_num_columns = wire_extension_circuit.get_circuit_num_columns()
                                        for column_num = 1, extension_num_columns do

                                            -- Assume dir_str is "+Z"
                                            local circ_node_pos = {x = wire_extension_circuit_pos.x + column_num - 1,
                                                                   y = wire_extension_circuit_pos.y,
                                                                   z = wire_extension_circuit_pos.z}

                                            if wire_extension_dir_str == "+X" then
                                                circ_node_pos = {x = wire_extension_circuit_pos.x,
                                                                 y = wire_extension_circuit_pos.y,
                                                                 z = wire_extension_circuit_pos.z - column_num + 1}
                                            elseif wire_extension_dir_str == "-X" then
                                                circ_node_pos = {x = wire_extension_circuit_pos.x,
                                                                 y = wire_extension_circuit_pos.y,
                                                                 z = wire_extension_circuit_pos.z + column_num - 1}
                                            elseif wire_extension_dir_str == "-Z" then
                                                circ_node_pos = {x = wire_extension_circuit_pos.x - column_num + 1,
                                                                 y = wire_extension_circuit_pos.y,
                                                                 z = wire_extension_circuit_pos.z}
                                            end

                                            q_command:debug_node_info(circ_node_pos,
                                                    "In update_bloch_sphere_block(), Processing CONNECTOR_M, circ_node_pos")

                                            update_bloch_sphere_block(circ_node_pos, num_wires, wire_num, reset)
                                        end
                                    end
                                end
                            end
                        end
                    end


                    local function process_backend_statevector_result(http_request_response)
                        if LOG_DEBUG then
                            minetest.debug("http_request_response (statevector):\n" .. dump(http_request_response))
                        end
                        if http_request_response.succeeded and
                                http_request_response.completed and
                                not http_request_response.timeout then

                            local sv_data = http_request_response.data

                            local statevector = q_command:parse_json_statevector(sv_data)

                            -- minetest.debug("statevector:\n" .. dump(statevector))

                            -- minetest.debug("correct_solution_statevector:\n" .. dump(correct_solution_statevector))

                            local is_correct_solution = true
                            if statevector and correct_solution_statevector and
                                    #statevector == #correct_solution_statevector then
                                for sv_idx = 1, #statevector do
                                    if not complex.nearly_equals(statevector[sv_idx],
                                            correct_solution_statevector[sv_idx]) then
                                        is_correct_solution = false
                                        break
                                    end
                                end

                            else
                                is_correct_solution = false
                                --minetest.debug("mpd.playing:" .. tostring(mpd.playing))
                            end

                            if is_correct_solution then
                                if mpd.playing then
                                    if mpd.playing == MUSIC_CONGRATS then
                                        mpd.queue_next_song(MUSIC_CONGRATS)
                                    else
                                        mpd.play_song(MUSIC_CONGRATS)
                                    end
                                end
                                mpd.queue_next_song(MUSIC_ACTIVE)
                            else
                                if mpd.playing then
                                    if mpd.playing == MUSIC_CHILL then
                                        mpd.play_song(MUSIC_ACTIVE)
                                    elseif mpd.playing == MUSIC_ACTIVE then
                                        mpd.queue_next_song(MUSIC_ACTIVE)
                                    elseif mpd.playing == MUSIC_EXCITED then
                                        mpd.queue_next_song(MUSIC_ACTIVE)
                                    elseif mpd.playing == MUSIC_CONGRATS then
                                        mpd.queue_next_song(MUSIC_ACTIVE)
                                    end
                                end
                            end

                            if LOG_DEBUG then
                                minetest.debug("is_correct_solution: " .. tostring(is_correct_solution))
                            end
                            if (is_correct_solution and not block_represents_correct_solution) or
                                    (not is_correct_solution and block_represents_correct_solution) then
                                minetest.swap_node(q_block.get_node_pos(), {name = other_q_block_node_name})
                            else
                            end

                            -- Update the histogram
                            local hist_node_pos = nil
                            local basis_state_node_pos = nil
                            local under_hist_node_pos = nil

                            -- TODO: Put this constant somewhere
                            local BLOCK_WATER_LEVELS = 63

                            -- Place a platform under the circuit
                            for col_num = 1, math.min(#statevector, num_columns) + 3 do
                                for row_num = 1, 4 do
                                    -- Assume dir_str is "+Z"
                                    local platform_node_pos = {x = circuit_grid_pos.x + col_num - 3,
                                                               y = circuit_grid_pos.y - 2,
                                                               z = circuit_grid_pos.z + 2 - row_num}
                                    if circuit_block.get_circuit_dir_str() == "+X" then
                                        platform_node_pos = {x = circuit_grid_pos.x + 2 - row_num,
                                                             y = circuit_grid_pos.y - 2,
                                                             z = circuit_grid_pos.z - col_num + 3}
                                    elseif circuit_block.get_circuit_dir_str() == "-X" then
                                        platform_node_pos = {x = circuit_grid_pos.x - 2 + row_num,
                                                             y = circuit_grid_pos.y - 2,
                                                             z = circuit_grid_pos.z + col_num - 3}
                                    elseif circuit_block.get_circuit_dir_str() == "-Z" then
                                        platform_node_pos = {x = circuit_grid_pos.x - col_num + 3,
                                                             y = circuit_grid_pos.y - 2,
                                                             z = circuit_grid_pos.z - 2 + row_num}
                                    end

                                    minetest.set_node(platform_node_pos,
                                            {name="default:desert_stone_block"})
                                end
                            end

                            for col_num = 1, math.min(#statevector, num_columns) do

                                -- Assume dir_str is "+Z"
                                hist_node_pos = {x = circuit_grid_pos.x + col_num - 1,
                                                 y = circuit_grid_pos.y - 1,
                                                 z = circuit_grid_pos.z}

                                if circuit_block.get_circuit_dir_str() == "+X" then
                                    hist_node_pos = {x = circuit_grid_pos.x,
                                                     y = circuit_grid_pos.y - 1,
                                                     z = circuit_grid_pos.z - col_num + 1}
                                elseif circuit_block.get_circuit_dir_str() == "-X" then
                                    hist_node_pos = {x = circuit_grid_pos.x,
                                                     y = circuit_grid_pos.y - 1,
                                                     z = circuit_grid_pos.z + col_num - 1}
                                elseif circuit_block.get_circuit_dir_str() == "-Z" then
                                    hist_node_pos = {x = circuit_grid_pos.x - col_num + 1,
                                                     y = circuit_grid_pos.y - 1,
                                                     z = circuit_grid_pos.z}
                                end

                                local amp = statevector[col_num]
                                local phase_rad = (complex.polar_radians(amp) + math.pi * 2) % (math.pi * 2)

                                local p16_radians = 0
                                local threshold = 0.0001
                                if math.abs(phase_rad - 0) > threshold and
                                        math.abs(phase_rad - math.pi * 2) > threshold then
                                    p16_radians = math.floor(phase_rad * 16 / math.pi + 0.5)
                                    if LOG_DEBUG then
                                        minetest.debug("phase_rad: " .. tostring(phase_rad) .. ", p16_radians: " .. tostring(p16_radians))
                                    end
                                    if p16_radians < 1 then
                                        p16_radians = 1
                                    elseif p16_radians > 32 then
                                        p16_radians = 32
                                    end
                                end

                                local probability = (complex.abs(statevector[col_num]))^2
                                local scaled_prob = math.floor(probability * BLOCK_WATER_LEVELS)

                                local hist_node_name = "q_command:statevector_glass_no_arrow"
                                if scaled_prob > 0 then
                                    hist_node_name = "q_command:statevector_glass_" .. tostring(p16_radians) .. "p16"
                                end
                                minetest.set_node(hist_node_pos,
                                        {name=hist_node_name, param2 = scaled_prob})

                                -- Place basis state block
                                -- Assume dir_str is "+Z"
                                local param2_dir = 0
                                basis_state_node_pos = {x = hist_node_pos.x,
                                                        y = hist_node_pos.y - 1,
                                                        z = hist_node_pos.z - 1}
                                under_hist_node_pos = {x = hist_node_pos.x,
                                                       y = hist_node_pos.y - 1,
                                                       z = hist_node_pos.z}

                                if circuit_block.get_circuit_dir_str() == "+X" then
                                    param2_dir = 1
                                    basis_state_node_pos = {x = hist_node_pos.x - 1,
                                                            y = hist_node_pos.y - 1,
                                                            z = hist_node_pos.z}
                                    under_hist_node_pos = {x = hist_node_pos.x,
                                                           y = hist_node_pos.y - 1,
                                                           z = hist_node_pos.z}
                                elseif circuit_block.get_circuit_dir_str() == "-X" then
                                    param2_dir = 3
                                    basis_state_node_pos = {x = hist_node_pos.x + 1,
                                                            y = hist_node_pos.y - 1,
                                                            z = hist_node_pos.z}
                                    under_hist_node_pos = {x = hist_node_pos.x,
                                                           y = hist_node_pos.y - 1,
                                                           z = hist_node_pos.z}
                                elseif circuit_block.get_circuit_dir_str() == "-Z" then
                                    param2_dir = 2
                                    basis_state_node_pos = {x = hist_node_pos.x,
                                                            y = hist_node_pos.y - 1,
                                                            z = hist_node_pos.z + 1}
                                    under_hist_node_pos = {x = hist_node_pos.x,
                                                           y = hist_node_pos.y - 1,
                                                           z = hist_node_pos.z}
                                end

                                if num_wires <= BASIS_STATE_BLOCK_MAX_QUBITS then
                                    local node_name = "q_command:q_command_state_" .. num_wires .. "qb_" .. tostring(col_num - 1)
                                    minetest.set_node(basis_state_node_pos,
                                            {name=node_name, param2=param2_dir})
                                    minetest.set_node(under_hist_node_pos,
                                            {name="default:desert_stone_block", param2=param2_dir})

                                    -- Place ellipsis block if there are more
                                    -- basis states than displayed
                                    if num_columns < #statevector and col_num == num_columns then
                                        minetest.set_node(basis_state_node_pos,
                                                {name="q_command:q_command_state_ellipsis", param2=param2_dir})
                                    end
                                end

                            end

                            -- Reset measure blocks and Bloch sphere blocks in the circuit
                            local num_wires = circuit_block.get_circuit_num_wires()
                            local num_columns = circuit_block.get_circuit_num_columns()
                            local circuit_dir_str = circuit_block.get_circuit_dir_str()
                            local circuit_pos_x = circuit_block.get_circuit_pos().x
                            local circuit_pos_y = circuit_block.get_circuit_pos().y
                            local circuit_pos_z = circuit_block.get_circuit_pos().z

                            q_block.set_measure_present_flag(0)
                            q_block.set_bloch_present_flag(0)

                            for column_num = 1, num_columns do
                                for wire_num = 1, num_wires do

                                    -- Assume dir_str is "+Z"
                                    local circuit_node_pos = {x = circuit_pos_x + column_num - 1,
                                                              y = circuit_pos_y + num_wires - wire_num,
                                                              z = circuit_pos_z}

                                    if circuit_dir_str == "+X" then
                                        circuit_node_pos = {x = circuit_pos_x,
                                                            y = circuit_pos_y + num_wires - wire_num,
                                                            z = circuit_pos_z - column_num + 1}
                                    elseif circuit_dir_str == "-X" then
                                        circuit_node_pos = {x = circuit_pos_x,
                                                            y = circuit_pos_y + num_wires - wire_num,
                                                            z = circuit_pos_z + column_num - 1}
                                    elseif circuit_dir_str == "-Z" then
                                        circuit_node_pos = {x = circuit_pos_x - column_num + 1,
                                                            y = circuit_pos_y + num_wires - wire_num,
                                                            z = circuit_pos_z}
                                    end

                                    update_measure_block(circuit_node_pos, num_wires, wire_num, nil, true)
                                    update_bloch_sphere_block(circuit_node_pos, num_wires, wire_num, true)
                                end

                            end

                            -- If Bloch sphere blocks are present, measure the circuit and do state tomography
                            if q_block.get_bloch_present_flag() == 1 then
                                -- Nil the tomo measurement data
                                q_block.set_qasm_data_json_for_1k_x_basis_meas(nil)
                                q_block.set_qasm_data_json_for_1k_y_basis_meas(nil)
                                q_block.set_qasm_data_json_for_1k_z_basis_meas(nil)

                                -- Indicate that the qasm_simulator should be run, with state tomography,
                                -- beginning with the X measurement basis (1 is X)
                                -- TODO: Make constants for these?

                                q_block.set_qasm_simulator_flag(1)
                                q_block.set_state_tomography_basis(1)
                                minetest.punch_node(q_block.get_node_pos())

                                q_block.set_qasm_simulator_flag(1)
                                q_block.set_state_tomography_basis(2)
                                minetest.punch_node(q_block.get_node_pos())

                                q_block.set_qasm_simulator_flag(1)
                                q_block.set_state_tomography_basis(3)
                                minetest.punch_node(q_block.get_node_pos())

                                -- Also indicate that the qasm_simulator should be run, without state tomography?
                                --circuit_blocks:set_node_with_circuit_specs_meta(pos,
                                --        orig_node_name, player)
                                q_block.set_qasm_simulator_flag(1)
                                q_block.set_state_tomography_basis(0)
                                minetest.punch_node(q_block.get_node_pos())
                            end


                        else
                            minetest.debug("Call to statevector_simulator Didn't succeed")
                        end
                    end




                    local function common_process_backend_qasm_result(http_request_response, state_tomo_basis)
                        if LOG_DEBUG then
                            minetest.debug("http_request_response (qasm):\n" .. dump(http_request_response))
                        end
                        if http_request_response.succeeded and
                                http_request_response.completed and
                                not http_request_response.timeout then

                            local qasm_data = http_request_response.data

                            if LOG_DEBUG then
                                minetest.debug ("qasm_data:", qasm_data)
                            end

                            local basis_state_bit_str = nil

                            local obj, pos, err = json.decode (qasm_data, 1, nil)
                            if err then
                                minetest.debug ("Error:", err)
                            else
                                local basis_freq = obj.result
                                if LOG_DEBUG then
                                    minetest.debug("basis_freq:\n" .. dump(basis_freq))
                                end

                                if state_tomo_basis == 1 then
                                    q_block.set_qasm_data_json_for_1k_x_basis_meas(qasm_data)
                                elseif state_tomo_basis == 2 then
                                    q_block.set_qasm_data_json_for_1k_y_basis_meas(qasm_data)
                                elseif state_tomo_basis == 3 then
                                    q_block.set_qasm_data_json_for_1k_z_basis_meas(qasm_data)
                                end

                                for key, val in pairs(basis_freq) do
                                    basis_state_bit_str = key:gsub("%s+", "")
                                end
                            end

                            if LOG_DEBUG then
                            minetest.debug("state_tomo_basis: " .. state_tomo_basis ..
                                    ", basis_state_bit_str: " .. basis_state_bit_str)
                            end

                            if basis_state_bit_str then

                                if mpd.playing then
                                    if mpd.playing == MUSIC_CHILL then
                                        mpd.play_song(MUSIC_EXCITED)
                                        mpd.queue_next_song(MUSIC_ACTIVE)
                                    elseif mpd.playing == MUSIC_ACTIVE then
                                        mpd.play_song(MUSIC_EXCITED)
                                        mpd.queue_next_song(MUSIC_ACTIVE)
                                    elseif mpd.playing == MUSIC_EXCITED then
                                        mpd.queue_next_song(MUSIC_EXCITED)
                                    elseif mpd.playing == MUSIC_CONGRATS then
                                        mpd.queue_next_song(MUSIC_ACTIVE)
                                    end
                                end

                                -- Update measure blocks in the circuit
                                local num_wires = circuit_block.get_circuit_num_wires()
                                local num_columns = circuit_block.get_circuit_num_columns()
                                local circuit_dir_str = circuit_block.get_circuit_dir_str()
                                local circuit_pos_x = circuit_block.get_circuit_pos().x
                                local circuit_pos_y = circuit_block.get_circuit_pos().y
                                local circuit_pos_z = circuit_block.get_circuit_pos().z

                                for column_num = 1, num_columns do
                                    for wire_num = 1, num_wires do

                                        -- Assume dir_str is "+Z"
                                        local circuit_node_pos = {x = circuit_pos_x + column_num - 1,
                                                                  y = circuit_pos_y + num_wires - wire_num,
                                                                  z = circuit_pos_z}

                                        if circuit_dir_str == "+X" then
                                            circuit_node_pos = {x = circuit_pos_x,
                                                                y = circuit_pos_y + num_wires - wire_num,
                                                                z = circuit_pos_z - column_num + 1}
                                        elseif circuit_dir_str == "-X" then
                                            circuit_node_pos = {x = circuit_pos_x,
                                                                y = circuit_pos_y + num_wires - wire_num,
                                                                z = circuit_pos_z + column_num - 1}
                                        elseif circuit_dir_str == "-Z" then
                                            circuit_node_pos = {x = circuit_pos_x - column_num + 1,
                                                                y = circuit_pos_y + num_wires - wire_num,
                                                                z = circuit_pos_z}
                                        end


                                        --if state_tomo_basis == 0 then
                                        --    update_measure_block(circuit_node_pos, num_wires, wire_num, basis_state_bit_str)
                                        --else
                                        --    update_bloch_sphere_block(circuit_node_pos, num_wires, wire_num)
                                        --end

                                        if state_tomo_basis == 0 then
                                            update_measure_block(circuit_node_pos, num_wires, wire_num, basis_state_bit_str)
                                        end
                                        update_bloch_sphere_block(circuit_node_pos, num_wires, wire_num)
                                    end

                                end
                            end

                        else
                            minetest.debug("Call to qasm_simulator Didn't succeed")
                        end
                    end

                    local function process_backend_qasm_result_no_tomo(http_request_response)
                        common_process_backend_qasm_result(http_request_response, 0)
                    end

                    local function process_backend_qasm_result_tomo_x_meas_basis(http_request_response)
                        common_process_backend_qasm_result(http_request_response, 1)
                    end

                    local function process_backend_qasm_result_tomo_y_meas_basis(http_request_response)
                        common_process_backend_qasm_result(http_request_response, 2)
                    end

                    local function process_backend_qasm_result_tomo_z_meas_basis(http_request_response)
                        common_process_backend_qasm_result(http_request_response, 3)
                    end

                    if q_block.get_qasm_simulator_flag() ~= 0 then

                        if q_block.get_state_tomography_basis() == 0 then
                            -- Run qasm_simulator without state tomography
                            request_http_api.fetch(http_request_qasm, process_backend_qasm_result_no_tomo)
                        elseif q_block.get_state_tomography_basis() == 1 then
                            -- Measure in X basis for state tomography
                            request_http_api.fetch(http_request_qasm_tomo_x, process_backend_qasm_result_tomo_x_meas_basis)
                        elseif q_block.get_state_tomography_basis() == 2 then
                            -- Measure in Y basis for state tomography
                            request_http_api.fetch(http_request_qasm_tomo_y, process_backend_qasm_result_tomo_y_meas_basis)
                        elseif q_block.get_state_tomography_basis() == 3 then
                            -- Measure in Z basis for state tomography
                            request_http_api.fetch(http_request_qasm_tomo_z, process_backend_qasm_result_tomo_z_meas_basis)
                        end

                        q_block.set_qasm_simulator_flag(0)
                        q_block.set_state_tomography_basis(0)
                    else
                        -- Only run statevector_simulator
                        request_http_api.fetch(http_request_statevector, process_backend_statevector_result)
                    end
                end

            else
                if player:get_player_control().sneak then
                    -- Circuit doesn't exist, so just remove the q_block
                    minetest.remove_node(pos)
                else
                    minetest.chat_send_player(player:get_player_name(),
                            "Must create a circuit first")
                end
            end
        end,
        can_dig = function(pos, player)
            return false
        end
    })
end


minetest.register_node("q_command:q_command_state_ellipsis", {
    description = "Some basis states not displayed",
    tiles = {"q_command_state_ellipsis.png"},
    groups = {oddly_breakable_by_hand=2},
    paramtype2 = "facedir"
})

function q_command:register_basis_state_block(num_qubits, basis_state_num)
    local texture_name = "q_command_state_" .. num_qubits .. "qb_" ..
            tostring(basis_state_num)
    minetest.register_node("q_command:" .. texture_name, {
        description = "Basis state " .. tostring(basis_state_num) .. " block",
        tiles = {texture_name .. ".png"},
        paramtype2 = "facedir",
        groups = {oddly_breakable_by_hand=2}
    })
end


minetest.register_node("q_command:statevector_glass_no_arrow", {
    description = "Statevector Glass with no arrow",
    drawtype = "glasslike_framed",
    tiles = {"q_command_glass.png", "q_command_transparent_blank.png^q_command_glass_detail.png"},
    special_tiles = {"q_command_water.png"},
    paramtype = "light",
    paramtype2 = "glasslikeliquidlevel",
    --sunlight_propagates = true,
    --is_ground_content = false,
    groups = {cracky = 3},
    --sounds = default.node_sound_glass_defaults(),
})


function q_command:register_statevector_liquid_block(pi16rotation)
    local texture_name = "q_command_rotation_" .. pi16rotation .. "p16"
    minetest.register_node("q_command:statevector_glass_" .. pi16rotation .. "p16", {
        description = "Statevector Glass " .. pi16rotation .. "p16",
        drawtype = "glasslike_framed",
        tiles = {"q_command_glass.png", texture_name .. ".png^q_command_glass_detail.png"},
        special_tiles = {"q_command_water.png"},
        paramtype = "light",
        paramtype2 = "glasslikeliquidlevel",
        --sunlight_propagates = true,
        --is_ground_content = false,
        groups = {cracky = 3},
        --sounds = default.node_sound_glass_defaults(),
    })
end

function q_command:convert_newlines(str)
	if(type(str)~="string") then
		return "ERROR: No string found!"
	end

	local function convert(s)
		return s:gsub("\n", function(slash, what)
			return ","
		end)
	end

	return convert(str)
end


--- Help buttons ---
function q_command:register_help_button(suffix, caption, fulltext)
	--q_command.captions[itemstringpart] = caption
	minetest.register_node("q_command:q_command_button_wall_help_" .. suffix, {
		description = suffix .. " help button",
		drawtype = "nodebox",
		tiles = {"q_command_button_wall_help.png"},
		inventory_image = "q_command_button_wield_help.png",
		wield_image = "q_command_button_wield_help.png",
		paramtype = "light",
		paramtype2 = "wallmounted",
		sunlight_propagates = true,
		is_ground_content = false,
		walkable = false,
		node_box = {
			type = "wallmounted",
			wall_top    = {-0.4375, 0.4375, -0.3125, 0.4375, 0.5, 0.3125},
			wall_bottom = {-0.4375, -0.5, -0.3125, 0.4375, -0.4375, 0.3125},
			wall_side   = {-0.5, -0.3125, -0.4375, -0.4375, 0.3125, 0.4375},
		},
		groups = {cracky = 2, attached_node = 1},
		legacy_wallmounted = true,
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			local formspec = ""..
			"size[12,6]"..
			"label[-0.15,-0.4;"..minetest.formspec_escape(S(caption)).."]"..
			"tablecolumns[text]"..
			"tableoptions[background=#000000;highlight=#000000;border=false]"..
			"table[0,0.25;12,5.2;infosign_text;"..
			q_command:convert_newlines(minetest.formspec_escape(S(fulltext)))..
			"]"..
			"button_exit[4.5,5.5;3,1;close;"..minetest.formspec_escape(S("Close")).."]"
			meta:set_string("formspec", formspec)
			meta:set_string("infotext", string.format(S("%s (Right-click for hints)"), S(caption)))
			meta:set_string("id", itemstringpart)
			meta:set_string("caption", caption)
		end,
		on_receive_fields = function(pos, formname, fields, sender)
			--print("Sign at "..minetest.pos_to_string(pos).." got "..dump(fields))
			local player_name = sender:get_player_name()
			if minetest.is_protected(pos, player_name) then
				minetest.record_protection_violation(pos, player_name)
				return
			end
			local text = fields.text
			if not text then
				return
			end
			if string.len(text) > 512 then
				minetest.chat_send_player(player_name, "Text too long")
				return
			end
			minetest.log("action", (player_name or "") .. " wrote \"" ..
				text .. "\" to sign at " .. minetest.pos_to_string(pos))
			local meta = minetest.get_meta(pos)
			meta:set_string("text", text)
			meta:set_string("infotext", '"' .. text .. '"')
		end,
	})
end

q_command.texts = {}

q_command.texts.quantum_circuit_world =
[[
Welcome to the world of quantum computing circuits! The block-world
environment you are currently in is created with the Minetest.net
open-source library. A list of controls for getting around and doing
things in Minetest are available by pausing the game (e.g. with the Esc
key on some platforms). The quantum gates and circuits with which you
will interact are powered by <https://qiskit.org/> quantum simulators.

There are an increasing number of areas that you may explore in this
environment. First, it would be helpful to read the signs in this room
(by right-clicking them), as they describe the behavior of various
quantum computing related blocks that you will encounter. By the way,
there is no need to take the blocks and tools from this room, as they
will be available in chests along the way. Please leave them in this
room, and come back anytime you have questions about what they do or how
to use them.

The first place outside this room that you may want to visit is the
quantum cats sandbox. In that area, some basic quantum computing
circuits and gates are demonstrated with grumpy and happy cats instead
of the usual qubits. To get there, follow the light blocks just outside
the front doors into the woods.

If you would rather skip the cats, then a good place to begin your
journey would be in the quantum circuit garden on the other side of the
large wall outside the front doors. Wherever you choose to begin, please
be sure to right-click the Help buttons (labeled with a question mark)
as you encounter them.

Wherever you go, remember that the sun may eventually set for a while.
To skip a night-cycle, just right-click a nearby bed and you will
immediately wake up the next morning. You may also grab a yellow lamp
from a chest to shed some light at night.
]]
q_command:register_help_button("quantum_circuit_world", "Quantum circuit world", q_command.texts.quantum_circuit_world)


q_command.texts.x_rx_gates =
[[
The X and Rx gates rotate a qubit state around the X axis of a Bloch
sphere (refer to the Bloch spheres on the wall). While wielding one of
these gates, right-click to place it on a quantum circuit. The X gate is
often referred to the NOT gate because it flips the |0> state to |1> and
vice-versa.

Once placed, left-click or right-click the Rotate Tool (the rounded tool
spinning on the floor) to rotate its state in increments of π/16 radians
(11.25 degrees), or -π/16 radians, respectively. When first placed, an
Rx gate has a rotation of 0 radians around the X axis. An X gate when
first placed has a rotation of π radians (180 degrees) around the X axis.

To convert an X gate into a controlled-X gate (and vice-versa),
left-click or right-click the block while wielding the Control Tool (the
wand-shaped tool spinning on the floor). Left-clicking moves the control
qubit up one wire, and right-clicking moves the control qubit down one
wire. The controlled-X gate is also known as the controlled-NOT, or CNOT
gate. It acts on a pair of qubits, with one acting as control and the
other as target. It performs an X operation on the target whenever the
control is in state |1>. If the control qubit is in a superposition,
this gate creates entanglement.

To convert a controlled-X gate into a Toffoli gate (and vice-versa),
hold the Special key down while wielding the Control Tool and
left-clicking or right-clicking. Left-clicking moves the second control
qubit up one wire, and right-clicking moves the second control qubit
down one wire. There is a blue dot on the second control qubit to help
you distinguish it from the first control qubit. The Special key
mentioned earlier may be known, and set, by pausing the game and choosing
the Change Keys button.

To remove an X gate, or any other gate from a circuit, left-click it
while wielding a block (or empty-handed if you are close enough).
]]
q_command:register_help_button("x_rx_gates", "X and Rx gates", q_command.texts.x_rx_gates)


q_command.texts.y_ry_gates =
[[
The Y and Ry gates rotate a qubit state around the Y axis of a Bloch
sphere (refer to a Bloch sphere on the wall). While wielding one of
these gates, right-click to place it on a quantum circuit.

Once placed, left-click or right-click the Rotate Tool (the rounded tool
spinning on the floor) to rotate its state in increments of π/16 radians
(11.25 degrees), or -π/16 radians, respectively. When first placed, an
Rx gate has a rotation of 0 radians around the Y axis. A Y gate when
first placed has a rotation of π radians (180 degrees) around the Y axis.

To convert a Y gate into a controlled-Y gate (and vice-versa),
left-click or right-click the block while wielding the Control Tool (the
wand-shaped tool spinning on the floor). Left-clicking moves the control
qubit up one wire, and right-clicking moves the control qubit down one
wire. The controlled-Y gate acts on a pair of qubits, with one acting as
control and the other as target. It performs a Y operation on the target
whenever the control is in state |1>.

To remove a Y gate, or any other gate from a circuit, left-click it
while wielding a block (or empty-handed if you are close enough).
]]
q_command:register_help_button("y_ry_gates", "Y and Ry gates", q_command.texts.y_ry_gates)


q_command.texts.z_rz_gates =
[[The Z and Rz gates rotate a qubit state around the Z axis of a Bloch
sphere, shifting its phase (refer to a Bloch sphere on the wall). While
wielding one of these gates, right-click to place it on a quantum circuit.

Once placed, left-click or right-click the Rotate Tool (the rounded tool
spinning on the floor) to rotate its state in increments of π/16 radians
(11.25 degrees), or -π/16 radians, respectively. When first placed, an
Rz gate has a rotation of 0 radians around the Z axis. A Z gate when
first placed has a rotation of π radians (180 degrees) around the Z axis.

To convert a Z gate into a controlled-Z gate (and vice-versa),
left-click or right-click the block while wielding the Control Tool (the
wand-shaped tool spinning on the floor). Left-clicking moves the control
qubit up one wire, and right-clicking moves the control qubit down one
wire. The controlled-Z gate acts on a pair of qubits, with one acting as
control and the other as target. It performs a Z operation on the target
whenever the control is in state |1>. A Z gate may be rotated even if it
has a control qubit, in which case it is known as a controlled-Rz gate.

To remove a Z gate, or any other gate from a circuit, left-click it
while wielding a block (or empty-handed if you are close enough).
]]
q_command:register_help_button("z_rz_gates", "Z and Rz gates", q_command.texts.z_rz_gates)


q_command.texts.h_gate_desc =
[[
The H (for Hadamard) gate rotates a qubit state around the diagonal X+Z
axis of a Bloch sphere (refer to a Bloch spheres on the wall). For
example, it rotates the state from |0> (see top-left Bloch sphere on the
wall) to |+> (see top-right Bloch sphere on the wall) and vice-versa.
Another common example is that it rotates the state from |1> (see
bottom-left Bloch sphere on the wall) to |-> (see bottom-right Bloch
sphere on the wall) and vice-versa. The H gate is used in many quantum
algorithms to create superpositions. As a Clifford gate, the Hadamard
gate is useful for moving information between the X and Z bases.

While wielding an H gate, right-click to place it on a quantum circuit.

To convert an H gate into a controlled-H gate (and vice-versa),
left-click or right-click the block while wielding the Control Tool (the
wand-shaped tool spinning on the floor). Left-clicking moves the control
qubit up one wire, and right-clicking moves the control qubit down one
wire. The controlled-H gate acts on a pair of qubits, with one acting as
control and the other as target. It performs an H operation on the
target whenever the control is in state |1>.

To remove an H gate, or any other gate from a circuit, left-click it
while wielding a block (or empty-handed if you are close enough).
]]
q_command:register_help_button("h_gate_desc", "Hadamard gate", q_command.texts.h_gate_desc)


q_command.texts.swap_gate_desc =
[[
The Swap gate swaps the states of the qubits on two wires with each
other. While wielding a Swap gate block, right-click to place it on one
of the desired wires. Then while wielding the Swap Tool (the saw-like
tool spinning on the floor), left-click or right-click the block to
navigate to the other desired wire. Left-clicking moves the other swap
qubit up one wire, and right-clicking moves it down one wire. Note that
this other swap qubit has a slightly different appearance (less pixels)
so that it may be distinguished from the originally placed Swap gate
block.

To convert a Swap gate into a controlled-Swap gate (and vice-versa),
left-click or right-click the original block placed while wielding the
Control Tool (the wand-shaped tool spinning on the floor). Left-clicking
moves the control qubit up one wire, and right-clicking moves the
control qubit down one wire. The controlled-Swap gate acts on the qubits
in a Swap gate by performing a Swap operation on the qubits whenever the
control qubit is in state |1>.

To remove a Swap gate, or any other gate from a circuit, left-click it
while wielding a block (or empty-handed if you are close enough).
]]
q_command:register_help_button("swap_gate_desc", "Swap gate", q_command.texts.swap_gate_desc)


q_command.texts.s_sdg_gates_desc =
[[
The S, and Sdg, gates rotate a qubit state around the Z axis of a Bloch
sphere, shifting its phase (refer to a Bloch sphere on the wall). The S
gate performs a rotation of π/2 radians, which is a quarter of the way
counterclockwise around the Bloch sphere. The Sdg (pronounced S dagger)
gate performs a rotation of -π/2 radians, which is a quarter of the way
clockwise around the Bloch sphere.

As Clifford gates, both are useful for moving information between the x
and y bases. While wielding one of these gates, right-click to place it
on a quantum circuit.

To remove an S gate, or any other gate from a circuit, left-click it
while wielding a block (or empty-handed if you are close enough).
]]
q_command:register_help_button("s_sdg_gates_desc", "S and Sdg gates", q_command.texts.s_sdg_gates_desc)


q_command.texts.t_tdg_gates_desc =
[[
The T, and Tdg, gates rotate a qubit state around the Z axis of a Bloch
sphere, shifting its phase (refer to a Bloch sphere on the wall). The T
gate performs a rotation of π/4 radians, which is an eighth of the way
counterclockwise around the Bloch sphere . The Tdg (pronounced T dagger)
gate performs a rotation of -π/4 radians, which is an eighth of the way
clockwise around the Bloch sphere.

Fault-tolerant quantum computers will compile all quantum programs down
to just these gates, as well as the Clifford gates. While wielding one
of these gates, right-click to place it on a quantum circuit.

To remove a T gate, or any other gate from a circuit, left-click it
while wielding a block (or empty-handed if you are close enough).
]]
q_command:register_help_button("t_tdg_gates_desc", "T and Tdg gates", q_command.texts.t_tdg_gates_desc)


q_command.texts.measurement_z_desc =
[[
The Measurement block performs a measurement on a qubit in the Z basis,
which is also called the computational, or standard, basis. Referring to
a Bloch sphere on the wall, note that this basis may be represented by a
plane cutting through its equator. After measurement, the state of a
qubit will either be |0> (represented by the top left Bloch sphere) or
|1> (represented by the bottom left Bloch sphere).

While wielding a measurement block, right-click to place it on a quantum
circuit.

To make a measurement in the Z basis, right click the Measurement block.
Measurement in other bases may be accomplished by rotating the qubit
state with appropriate gates prior to performing a measurement with this
block. Measurement is not a reversible operation.

The Measurement block may be turned into a Bloch sphere that displays an
estimation of the qubit state before measurement. To accomplish this,
right-click the Measurement block while holding down the Special key.
This will insert state tomography measurements into the circuit,
calculating and displaying the estimated state. The Special key may be
known, and set, by pausing the game and choosing the Change Keys button.

Note: Whenever a Bloch sphere is on a circuit, the QASM simulator will
automatically be run whenever the any changes to the circuit occur.

To remove a Measurement block, or any other block from a circuit,
left-click it while wielding a block (or empty-handed if you are close
enough).
]]
q_command:register_help_button("measurement_z_desc", "Measurement in Z basis", q_command.texts.measurement_z_desc)


q_command.texts.bloch_sphere_block_desc =
[[
A Bloch sphere, like these on the wall, represent the quantum state of a
qubit. Anywhere on the surface of the sphere is a valid quantum state.
For example, the top-left Bloch sphere represents state |0> and the
bottom-left Bloch sphere represents state |1>. Note that these Bloch
spheres are rotated slightly clockwise and tilted toward you. The green
markers represent states on the visible side of a Bloch sphere, and the
blue markers represent states on its hidden side.

To make measurements for state tomography, right-click the Bloch sphere
block while holding down the Special key. The Special key may be known,
and set, by pausing the game and choosing the Change Keys button. To
make a measurement in the Z basis and display the measured basis state,
right-click the Bloch sphere block without holding down other keys.

Note that the Bloch sphere block is only available by right-clicking a
Measurement block while holding down the Special key. Whenever a Bloch
sphere is on a circuit, the QASM simulator will automatically be run
whenever the any changes to the circuit occur.

To remove a Bloch sphere block, or any other block from a circuit,
left-click it while wielding a block (or empty-handed if you are close
enough).
]]
q_command:register_help_button("bloch_sphere_block_desc", "The Bloch sphere", q_command.texts.bloch_sphere_block_desc)


q_command.texts.reset_op_desc =
[[
The Reset operation returns a qubit to state |0> (represented by the top
left Bloch sphere on the wall), irrespective of its state before the
operation was applied. It is not a reversible operation.

While wielding a Reset block, right-click to place it on a quantum
circuit.

To remove a Reset block, or any other block from a circuit, left-click
it while wielding a block (or empty-handed if you are close enough).
]]
q_command:register_help_button("reset_op_desc", "Reset or |0> operation", q_command.texts.reset_op_desc)


q_command.texts.barrier_op_desc =
[[To make your quantum program more efficient, the compiler will try to
combine gates. The Barrier is an instruction to the compiler to prevent
these combinations being made.

While wielding a Barrier block, right-click to place it on a quantum
circuit.

To remove a Barrier block, or any other block from a circuit, left-click
it while wielding a block (or empty-handed if you are close enough).
]]
q_command:register_help_button("barrier_op_desc", "Barrier operation", q_command.texts.barrier_op_desc)


q_command.texts.if_op_block_desc =
[[
The If operation allows quantum gates to be conditionally applied,
depending on the state of a classical register. While wielding an If
operation block, right-click while pointing immediately to the left of
the desired gate to be conditionally applied. Then right-click the If
block until the wire containing the desired measurement block, and
classical conditional value (0 or 1), are displayed on the block.

Note that OpenQASM and Qiskit support multiple-bit classical registers,
but this application currently supports only single-bit classical
registers. These classical register are created implicitly, one per
quantum register (which are implicitly created as single-qubit) in the
circuit.

To remove an If operation block, or any other block from a circuit,
left-click it while wielding a block (or empty-handed if you are close
enough).
]]
q_command:register_help_button("if_op_block_desc", "If operation", q_command.texts.if_op_block_desc)


q_command.texts.wire_extender_block_desc =
[[
Although not representative of a Qiskit operation, the Wire Extender
block enables a circuit wire to be extended to another location. Here is
the procedure for doing that:

1) While wielding a Wire Extension block and pointing at the rightmost
block on the desired wire, right-click to place it.

2) Left-click the Wire Extension block, which will cause a Wire
Continuation block to drop (the cube-shaped item spinning on the floor).
Note: The direction in which it drops is influenced by the where you are
when you left-click.

3) Left-click the Wire Continuation block to put it in your inventory.
Move this block to your hotbar if it is not already there.

4) While wielding this Wire Continuation block, right-click to place it
in the position and orientation that you would like the wire
continuation to be.

5) Right-click the Wire Continuation block, specifying how many blocks
wide the wire continuation should be.

To remove a wire continuation and its associated Wire Extension block
from a circuit, while pressing the shift key, left-click the Wire
Continuation block.
]]
q_command:register_help_button("wire_extender_block_desc", "Wire Extender block", q_command.texts.wire_extender_block_desc)


q_command.texts.q_block_desc =
[[
The Q block enables you to create a quantum circuit that may be executed
by Qiskit simulators. Here is the procedure for creating a quantum circuit:

1) While wielding a Q block, point at the position in the world that you
would like the circuit to be placed and right-click.

2) Right-click the Q block, specifying in the dialog the number of wires
and columns that you would like the circuit to have, and click the Create
button.

3) Place blocks on the circuit and interact with it, referring to the
instructions near each of the blocks in this room.

When a quantum circuit is created, a foundation made of blocks is also
created. This foundation includes some liquid blocks that help you
visualize the probabilities and phases for each basis state in the state
vector.

Left-clicking a Q block causes the Qiskit statevector simulator to be
run, which is not normally necessary as it is run whenever the circuit
is modified. The most common reason for left-clicking a Q block is to
restore the Measurement blocks to their original appearance, rather than
showing the state of their last measurement.

Right-clicking on a Q block when a circuit has already been created
stops and starts the music. You may also right-click this non-functional
Q block to stop or start the music.

To remove a Q block and its circuit, while pressing the shift key
left-click the Q block.
]]
q_command:register_help_button("q_block_desc", "Q block", q_command.texts.q_block_desc)


q_command.texts.quantum_cats_sandbox =
[[
There are so many ones and zeros in quantum computing that some folks
find it easier to initially relate to states with real world concepts
(e.g. cats) rather than jumping straight to qubits. In the Quantum Cats
Sandbox, each of the circuits start out with cats (Alice Cat and Bob
Cat) in their grumpy state. The gates in the circuits evolve their
quantum states, resulting in various probabilities of the cats being
being grumpy or happy when observed (measured). These probabilities are
expressed by the liquid levels in the glass blocks below each circuit.
The binary digits 0 and 1 in front of the liquid blocks represent grumpy
and happy states, respectively, with the rightmost digit representing
the topmost cat.

Take a look at the circuits, beginning with the one-wire circuits on the
opposite wall, and right-click their Help buttons to learn more about
them. Feel free to remove (by left-clicking) and add (by right-clicking)
gates on a circuit to see the effects on the probabilities as well as
measurements. To measure a circuit, right-click on a block that has the
appearance of a measuring device. You will find a couple of gates and
some other items in the chest, which you may open and close by
right-clicking. To move an item from the chest into your inventory, drag
it from the upper to the lower section of the chest dialog box. The
items that appear in the top row of the inventory will appear in the
hotbar ready to be wielded.

There are a some tools in the chest with which you may add control
qubits to a gate, as well as to rotate a gate. To use these tools,
position the cursor on an appropriate gate and left-click or right-click.
]]
q_command:register_help_button("quantum_cats_sandbox", "Quantum cats sandbox", q_command.texts.quantum_cats_sandbox)

q_command.texts.making_cats_happy =
[[
This circuit, consisting of only one wire (cat), leverages the Pauli-X
gate, also known as the NOT, or bit-flip, gate. Its effect on a grumpy
cat is to make it happy, and vice-versa. Notice how the outcome
probabilities and measurement results change as this gate is removed and
added.
]]
q_command:register_help_button("making_cats_happy", "Making a cat happy", q_command.texts.making_cats_happy)

q_command.texts.superpositional_cat =
[[
This circuit leverages the Hadamard gate to put a cat into an equal
superposition of grumpy and happy. Notice how the outcome probabilities
and measurement results change as this gate is removed and added.
]]
q_command:register_help_button("superpositional_cat", "Superposition of grumpy and happy cat", q_command.texts.superpositional_cat)

q_command.texts.entangling_cats =
[[
This two-wire circuit demonstrates the property known as quantum
entanglement. Notice that each of the wires in the circuit are continued
by blocks separated from the main circuit. This illustrates the idea
that two entangled quantum particles may be separated by a great
distance and continue to be entangled. Measuring one of the particles
(cats) results in the measured state of the other particle to be
determined. Try it out by right-clicking one of the measurement blocks.
Also notice that the probabilities indicate that states 00 (grumpy-grumpy)
and 11 (happy-happy) are equally likely.

The CNOT gate (the two-wire gate that has the appearance of cross-hairs
and a vertical line with a dot), is partially responsible for the
entanglement. The cross-hairs symbol has the functionality of a NOT gate
used in another circuit in this cat sandbox. The difference is that it
is conditional on the state of the other wire, performing the NOT
operation whenever the other wire is in the happy cat state.
]]
q_command:register_help_button("entangling_cats", "Entangling cats", q_command.texts.entangling_cats)

q_command.texts.quantum_circuit_garden =
[[
Welcome to the quantum circuit garden, which contains various
circuit-based puzzles to solve. For more information on the challenge
for a given circuit, right-click its Help button. To solve a puzzle, add
the appropriate gates to its circuit. You can find the necessary gates
in the chest below this sign, which you may open and close by
right-clicking. To move an item from the chest into your inventory, drag
it from the upper to the lower section of the chest dialog box. The
items that appear in the top row of the inventory will appear in the
hotbar ready to be wielded. To add a gate to a circuit, choose the gate
block from the hotbar, position the cursor on the circuit, and
right-click. Left-clicking a gate while wielding a block (or empty
handed if you are close enough) removes it from the circuit. When you
solve a given circuit puzzle, the black Q block will turn gold.

There are a couple of tools in the chest with which you may add control
qubits to a gate, as well as to rotate a gate. To use these tools,
position the cursor on an appropriate gate and left-click or right-click.

Notice that each circuit has a set of glass blocks with liquid levels
that express the measurement probability of each basis state. The
rightmost digit of each basis state represents the topmost wire. To
measure a circuit, right-click on a block that has the appearance of a
measuring device.
]]
q_command:register_help_button("quantum_circuit_garden", "Quantum circuit garden", q_command.texts.quantum_circuit_garden)

q_command:register_q_command_block("default")

q_command.texts.x_gate =
[[
This circuit, consisting of only one wire, leverages the X gate, also
known as the Pauli-X, NOT, or bit-flip, gate. Its effect on the |0>
state is to make it |1>, and vice-versa. To work through this puzzle,
take the following steps:

1) Notice that the blue liquid indicates there is a 100% probability
that the result will be |0> when the circuit is measured. Go ahead and
right-click the measurement block several times to verify that |0> is
always the result.

2) Get an X block out of the chest.

3) While wielding the X block, position the cursor on the empty place
on the circuit wire, and right-click.

4) Notice that the blue liquid now indicates there is a 100% probability
that the result will be |1> when the circuit is measured. Go ahead and
right-click the measurement block several times to verify that |1> is
always the result.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("x_gate", "Quantum NOT gate", q_command.texts.x_gate)
local solution_statevector_x_gate =
{
	{
		r = 0,
		i = 0
	},
	{
		r = 1,
		i = 0
	}
}
q_command:register_q_command_block( "x_gate_success", "x_gate",
        solution_statevector_x_gate, true)
q_command:register_q_command_block( "x_gate_success", "x_gate",
        solution_statevector_x_gate, false)


q_command.texts.h_gate =
[[
This circuit, consisting of only one wire, leverages the H gate, also
known as the the Hadamard gate. Its effect on the |0> state is to put it
into an equal superposition of |0> and |1>. Therefore, when the qubit is
measured, there is a 50% probability that the result will be |0>, and a
50% probability that the result will be |1>. To work through this
puzzle, take the following steps:

1) Notice that the blue liquid indicates there is a 100% probability
that the result will be |0> when the circuit is measured. Go ahead and
right-click the measurement block several times to verify that |0> is
always the result.

2) Get an H block out of the chest.

3) While wielding the H block, position the cursor on the empty place
on the circuit wire, and right-click.

4) Notice that the blue liquid now indicates there is a 50% probability
that the result will be |0> when the circuit is measured, and a 50%
probability that the result will be |1> when the circuit is measured. Go
ahead and right-click the measurement block several times to verify that
the results are fairly evenly distributed between |0> and |1>.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("h_gate", "Hadamard gate", q_command.texts.h_gate)
local solution_statevector_h_gate =
{
	{
		r = 0.707,
		i = 0
	},
	{
		r = 0.707,
		i = 0
	}
}
q_command:register_q_command_block( "h_gate_success", "h_gate",
        solution_statevector_h_gate, true)
q_command:register_q_command_block( "h_gate_success", "h_gate",
        solution_statevector_h_gate, false)


q_command.texts.cnot_gate_puzzle =
[[
The CNOT gate, also referred to as the controlled-NOT or controlled-X
gate, is one of the two-qubit gates in quantum computing. To create a
CNOT gate, first place an X gate on the circuit. Then, to convert an X
gate into a CNOT gate (and vice-versa), left-click or right-click the
block while wielding the Control Tool (the wand-shaped tool).
Left-clicking moves the control qubit up one wire, and right-clicking
moves the control qubit down one wire. The CNOT gate acts on a pair of
qubits, with one acting as control and the other as target. It performs
an X operation on the target whenever the control is in state |1>.

To work through this puzzle, take the following steps:

1) Place a CNOT gate in the second column, with the target qubit on the
bottom and the control qubit on the top.

2) Notice that the blue liquid indicates there is a 100% probability
that the result will be |00> when the circuit is measured. The leftmost
0 corresponds to the bottom wire, and the rightmost 0 corresponds to the
top wire. Go ahead and right-click one of the measurement blocks a few
times to verify that |00> is always the result.

3) Place an X gate on the top wire of the first column, noticing that
there is now a 100% probability that the result will be |11> when
measured. Note that the bottom qubit flips to |1> because of the CNOT
gate. Go ahead and right-click one of the measurement blocks a few times
to verify that |11> is always the result.

4) Add an X gate to the circuit on the bottom wire of the first column,
noticing that there is now a 100% probability that the result will be
|01> when measured. Go ahead and right-click one of the measurement
blocks to verify that |01> is always the result.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("cnot_gate_puzzle", "CNOT gate puzzle", q_command.texts.cnot_gate_puzzle)
local solution_statevector_cnot_gate_puzzle =
{
	{
		r = 0,
		i = 0
	},
	{
		r = 1,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	}
}
q_command:register_q_command_block( "cnot_gate_puzzle_success", "cnot_gate_puzzle",
        solution_statevector_cnot_gate_puzzle, true)
q_command:register_q_command_block( "cnot_gate_puzzle_success", "cnot_gate_puzzle",
        solution_statevector_cnot_gate_puzzle, false)


q_command.texts.hxx_gates =
[[
This circuit leverages Hadamard and X gates to create a quantum state in
which the measurement results |001> and |101> are equally likely, and no
other measurement results are possible. This quantum state could be
expressed as |001> + |101>

To solve this circuit puzzle, place an H gate and an X gate on the
appropriate wires.

Hint: Use what you already have learned about the behaviors of H and X
gates on single-wire circuits.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("hxx_gates", "Hadamard and X gates", q_command.texts.hxx_gates)
local solution_statevector_hxx_gates =
{
	{
		r = 0,
		i = 0
	},
	{
		r = 0.707,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0.707,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	}
}
q_command:register_q_command_block( "hxx_gates_success", "hxx_gates",
        solution_statevector_hxx_gates, true)
q_command:register_q_command_block( "hxx_gates_success", "hxx_gates",
        solution_statevector_hxx_gates, false)


q_command.texts.bell_phi_plus =
[[
The four simplest examples of quantum entanglement are the Bell states.
The most well-known Bell state, symbolized by Φ+ (phi plus), may be
realized with a Hadamard gate and a CNOT gate. The CNOT gate is a
two-wire gate that has the appearance of cross-hairs and a vertical line
with a dot. The cross-hairs symbol has the functionality of the X gate,
with the difference being that it is conditional on the state of the
other wire, performing the NOT operation whenever the other wire is |1>.

Measuring one of the qubits results in the measured state of the other
qubit to be determined. A correct Φ+ Bell state solution will have
probabilities indicating that measurement results |00> and |11> are
equally likely, as well has having identical phases. The notation for a
phase on these block-world circuits is an arrow that points in a
direction signifying its counterclockwise rotation, from 0 radians
pointing rightward.

One way to realize this state is to place a Hadamard gate on the top
wire, and an X gate on the second wire in a column to the right of the
Hadamard gate. Then select the control tool from the hotbar (after
having retrieved it from the chest). While positioning the cursor on the
X gate in the circuit, left-click until the control qubit is on the same
wire as the Hadamard gate.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("bell_phi_plus", "Bell State: Φ+", q_command.texts.bell_phi_plus)
local solution_statevector_bell_phi_plus =
{
	{
		r = 0.707,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0.707,
		i = 0
	}
}
q_command:register_q_command_block( "bell_phi_plus_success", "bell_phi_plus",
        solution_statevector_bell_phi_plus, true)
q_command:register_q_command_block( "bell_phi_plus_success", "bell_phi_plus",
        solution_statevector_bell_phi_plus, false)


q_command.texts.bell_phi_minus =
[[
The four simplest examples of quantum entanglement are the Bell states.
One of these Bell states, symbolized by Φ- (phi minus), may be realized
by placing an X gate on the top wire, and adding the Φ+ Bell state
circuit (as instructed in another puzzle) to the right of the X gate.

Measuring one of the qubits results in the measured state of the other
qubit to be determined. A correct Φ- Bell state solution will have
probabilities indicating that measurement results |00> and |11> are
equally likely, as well has having opposite phases. The notation for a
phase on these block-world circuits is an arrow that points in a
direction signifying its counterclockwise rotation, from 0 radians
pointing rightward. As an example, a leftward pointing arrow signifies a
phase of π radians.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("bell_phi_minus", "Bell State: Φ-", q_command.texts.bell_phi_minus)
local solution_statevector_bell_phi_minus =
{
	{
		r = 0.707,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = -0.707,
		i = 0
	}
}
q_command:register_q_command_block( "bell_phi_minus_success", "bell_phi_minus",
        solution_statevector_bell_phi_minus, true)
q_command:register_q_command_block( "bell_phi_minus_success", "bell_phi_minus",
        solution_statevector_bell_phi_minus, false)


q_command.texts.bell_psi_plus =
[[
The four simplest examples of quantum entanglement are the Bell states.
One of these Bell states, symbolized by Ψ+ (psi plus), may be realized
by placing an X gate on the second wire, and adding the Φ+ Bell state
circuit (as instructed in another puzzle) to the right of the X gate,

Measuring one of the qubits results in the measured state of the other
qubit to be determined. A correct Ψ+ Bell state solution will have
probabilities indicating that measurement results |01> and |10> are
equally likely, as well has having identical phases. The notation for a
phase on these block-world circuits is an arrow that points in a
direction signifying its counterclockwise rotation, from 0 radians
pointing rightward. The Ψ+ Bell state is known as one of the singlet
states, where measuring one of the qubits determines that the other
qubit will be measured as the opposite state.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("bell_psi_plus", "Bell State: Ψ+", q_command.texts.bell_psi_plus)
local solution_statevector_bell_psi_plus =
{
	{
		r = 0,
		i = 0
	},
	{
		r = 0.707,
		i = 0
	},
	{
		r = 0.707,
		i = 0
	},
	{
		r = 0,
		i = 0
	}
}
q_command:register_q_command_block( "bell_psi_plus_success", "bell_psi_plus",
        solution_statevector_bell_psi_plus, true)
q_command:register_q_command_block( "bell_psi_plus_success", "bell_psi_plus",
        solution_statevector_bell_psi_plus, false)


q_command.texts.bell_psi_minus =
[[
The four simplest examples of quantum entanglement are the Bell states.
One of these Bell states, symbolized by Ψ- (psi minus), may be realized
by placing X gates on the top and second wires, and adding the Φ+ Bell
state circuit (as instructed in another puzzle) to the right of the X
gates.

Measuring one of the qubits results in the measured state of the other
qubit to be determined. A correct Ψ- Bell state solution will have
probabilities indicating that measurement results |01> and |10> are
equally likely, as well has having opposite phases. The notation for a
phase on these block-world circuits is an arrow that points in a
direction signifying its counterclockwise rotation, from 0 radians
pointing rightward. As an example, a leftward pointing arrow signifies a
phase of π radians. The Ψ- Bell state is known as one of the singlet
states, where measuring one of the qubits determines that the other
qubit will be measured as the opposite state.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("bell_psi_minus", "Bell State: Ψ-", q_command.texts.bell_psi_minus)
local solution_statevector_bell_psi_minus =
{
	{
		r = 0,
		i = 0
	},
	{
		r = -0.707,
		i = 0
	},
	{
		r = 0.707,
		i = 0
	},
	{
		r = 0,
		i = 0
	}
}
q_command:register_q_command_block( "bell_psi_minus_success", "bell_psi_minus",
        solution_statevector_bell_psi_minus, true)
q_command:register_q_command_block( "bell_psi_minus_success", "bell_psi_minus",
        solution_statevector_bell_psi_minus, false)


q_command.texts.ghz_state =
[[
GHZ (Greenberger–Horne–Zeilinger) states are entangled states involving
three or more qubits, where the basis states involved contain all zeros
or all ones. For example, the entangled state in this three-wire circuit
puzzle has equal probabilities of being measured as |000> and |111>.
Please refer to the Bell state circuit puzzles for more information on
entanglement.

One way to realize this state is to place a Hadamard gate on the top
wire, and an X gate on the second wire in a column to the right of the
Hadamard gate. Then select the control tool from the hotbar (after
having retrieved it from the chest). While positioning the cursor on the
X gate in the circuit, convert it to a CNOT gate by left-clicking, until
the control qubit is on the same wire as the Hadamard gate. Repeat this
process to place another CNOT gate whose X gate is on the third wire and
control qubit is on the top wire.

Note that measuring the circuit (by right-clicking the measurement
blocks) results in either |000> or |111> each time.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("ghz_state", "GHZ states", q_command.texts.ghz_state)
local solution_statevector_ghz_state =
{
	{
		r = 0.707,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 0.707,
		i = 0
	}
}
q_command:register_q_command_block( "ghz_state_success", "ghz_state",
        solution_statevector_ghz_state, true)
q_command:register_q_command_block( "ghz_state_success", "ghz_state",
        solution_statevector_ghz_state, false)


q_command.texts.equal_super_2wire =
[[
This circuit leverages two Hadamard gates to create an equal
superposition of |00>, |01>, |10>, and |11>. To solve this circuit
puzzle, place an H block on each wire. Notice how the outcome
probabilities and measurement results change as these gates are removed
and added. This pattern of placing an H gate on each wire of a circuit
is commonly used to create a superposition consisting of 2^numQubits
states.

If the Q block turned gold, congratulations on solving the puzzle!
]]
q_command:register_help_button("equal_super_2wire", "Equal superposition with two qubits", q_command.texts.equal_super_2wire)
local solution_statevector_equal_super_2wire =
{
	{
		r = 0.5,
		i = 0
	},
	{
		r = 0.5,
		i = 0
	},
	{
		r = 0.5,
		i = 0
	},
	{
		r = 0.5,
		i = 0
	}
}
q_command:register_q_command_block( "equal_super_2wire_success", "equal_super_2wire",
        solution_statevector_equal_super_2wire, true)
q_command:register_q_command_block( "equal_super_2wire_success", "equal_super_2wire",
        solution_statevector_equal_super_2wire, false)


q_command.texts.rotate_yz_gates_puzzle =
[[
The Rx and X gates rotate a qubit state around the X axis of a Bloch
sphere. The Ry and Y gates rotate a qubit state around the Y axis. The
Rz and Z gates rotate a qubit state around the Z axis. To work through
this puzzle, take the following steps:

1) Place an Ry gate on first column of the top wire.

2) Turn the Measurement block on the top wire into a Bloch sphere that
displays an estimation of the qubit state before measurement. To
accomplish this, right-click the Measurement block while holding down
the Special key. This will insert state tomography measurements into the
circuit, calculating and displaying the estimated state. The Special key
may be known, and set, by pausing the game and choosing the Change Keys
button.

3) The Bloch sphere should have a green square at its top, reflecting
that the state of the qubit is |0>. While wielding the Rotate Tool (the
rounded tool), left-click the Ry gate 8 times, pausing a couple of
seconds each time. Each click performs a rotation of π/16 radians (11.25
degrees). Notice that the state represented on the Bloch sphere changes,
moving along a curved vertical line and ending up on its equator. The
state that should be reflected on the Bloch sphere is commonly referred
to as the plus, or |+> state.

4) Place a Z gate on the second column of the top wire. Notice that the
state represented on the Bloch sphere changes again, rotating π radians
(180 degrees) around the Z axis. Its color changes to blue, indicating
that it is located on the back side of the sphere. This state is
commonly referred to as the minus, or |-> state.

5) Turn the Measurement block on the bottom wire into a Bloch sphere.
Then place an X gate on the first column of the bottom wire. Note that
the state of that qubit rotates π radians (180 degrees) around the X
axis from the top to the bottom of the Bloch sphere.

6) Place a Hadamard gate on the second column of the bottom wire. Note
that the state reflected on the Bloch sphere is the same as the qubit on
the top wire. This demonstrates that there are many combinations
(actually an infinite number) of gate operations that can arrive at the
same state.
]]
q_command:register_help_button("rotate_yz_gates_puzzle", "Rotate X/Y/Z gates puzzle", q_command.texts.rotate_yz_gates_puzzle)
local solution_statevector_rotate_yz_gates_puzzle =
{
	{
		r = 0.5,
		i = 0
	},
	{
		r = -0.5,
		i = 0
	},
	{
		r = -0.5,
		i = 0
	},
	{
		r = 0.5,
		i = 0
	}
}
q_command:register_q_command_block( "rotate_yz_gates_puzzle_success", "rotate_yz_gates_puzzle",
        solution_statevector_rotate_yz_gates_puzzle, true)
q_command:register_q_command_block( "rotate_yz_gates_puzzle_success", "rotate_yz_gates_puzzle",
        solution_statevector_rotate_yz_gates_puzzle, false)


q_command.texts.swap_gate_puzzle =
[[
The Swap gate swaps the states of the qubits on two wires with each
other. To work through this puzzle, take the following steps:

1) Place an X gate on the top wire of the first column.

2) Notice that the blue liquid indicates there is a 100% probability
that the result will be |01> when the circuit is measured. The leftmost
digit corresponds to the bottom wire, and the rightmost digit
corresponds to the top wire. Go ahead and right-click one of the
measurement blocks to verify that |01> is always the result.

3) While wielding a Swap gate block, right-click to place it in the
second column of either wire. Then while wielding the Swap Tool (the
saw-like tool), left-click or right-click the block to navigate to the
other wire. Left-clicking moves the other swap qubit up one wire, and
right-clicking moves it down one wire. Note that this other swap qubit
has a slightly different appearance (less pixels) so that it may be
distinguished from the originally placed Swap gate block.

4) Notice that the blue liquid indicates there is now a 100% probability
that the result will be |10> when the circuit is measured. This
demonstrates that the qubits have switched wires with each other because
of the Swap gate. Go ahead and right-click one of the measurement blocks
to verify that |10> is always the result.
]]
q_command:register_help_button("swap_gate_puzzle", "Swap gate puzzle", q_command.texts.swap_gate_puzzle)
local solution_statevector_swap_gate_puzzle =
{
	{
		r = 0,
		i = 0
	},
	{
		r = 0,
		i = 0
	},
	{
		r = 1,
		i = 0
	},
	{
		r = 0,
		i = 0
	}
}
q_command:register_q_command_block( "swap_gate_puzzle_success", "swap_gate_puzzle",
        solution_statevector_swap_gate_puzzle, true)
q_command:register_q_command_block( "swap_gate_puzzle_success", "swap_gate_puzzle",
        solution_statevector_swap_gate_puzzle, false)


q_command.texts.notsingleplayer =
[[
You are now playing QiskitBlocks in multiplayer mode, but QiskitBlocks
is optimized for the singleplayer mode.

Unless you are sure no other players will join, please exit now and
start QiskitBlocks in singleplayer mode.
]]

q_command.texts.creative =
[[
The Creative Mode is turned on, but QiskitBlocks is designed to be
played with the Creative Mode checkbox deselected.

You can leave now by clicking the Leave QiskitBlocks button, or later by
pressing [Esc].
]]

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if(fields.leave) then
        minetest.kick_player(player:get_player_name(), S("You have voluntarily exited QiskitBlocks"))
        return
    end
end)

minetest.register_on_joinplayer(function(player)
	local formspec = nil
	if(minetest.is_singleplayer() == false) then
		formspec = "size[12,6]"..
		"label[-0.15,-0.4;"..minetest.formspec_escape(S("Warning: You're not playing in singleplayer mode")).."]"..
		"tablecolumns[text]"..
		"tableoptions[background=#000000;highlight=#000000;border=false]"..
		"table[0,0.25;12,5.2;creative_text;"..
        q_command:convert_newlines(minetest.formspec_escape(S(q_command.texts.notsingleplayer)))..
		"]"..
		"button_exit[2.5,5.5;3,1;close;"..minetest.formspec_escape(S("Continue anyway")).."]"..
		"button_exit[6.5,5.5;3,1;leave;"..minetest.formspec_escape(S("Leave QiskitBlocks")).."]"
	elseif(minetest.settings:get_bool("creative_mode")) then
		formspec = "size[12,6]"..
		"label[-0.15,-0.4;"..(minetest.formspec_escape(S("Warning: Creative mode is active"))).."]"..
		"tablecolumns[text]"..
		"tableoptions[background=#000000;highlight=#000000;border=false]"..
		"table[0,0.25;12,5.2;creative_text;"..
        q_command:convert_newlines(minetest.formspec_escape(S(q_command.texts.creative)))..
		"]"..
		"button_exit[2.5,5.5;3,1;close;"..minetest.formspec_escape(S("Continue anyway")).."]"..
		"button_exit[6.5,5.5;3,1;leave;"..minetest.formspec_escape(S("Leave QiskitBlocks")).."]"
	end
	if(formspec~=nil) then
		minetest.show_formspec(player:get_player_name(), "intro", formspec)
	end
end)


-- TODO: Remove this code after removing blocks in-world
local function register_sign(desc, def)
	minetest.register_node("q_command:level_progression", {
		description = desc,
		drawtype = "nodebox",
		tiles = {"q_command_level_progression.png"},
		inventory_image = "q_command_level_progression.png",
		wield_image = "q_command_level_progression.png",
		paramtype = "light",
		paramtype2 = "wallmounted",
		sunlight_propagates = true,
		is_ground_content = false,
		walkable = false,
		node_box = {
			type = "wallmounted",
			wall_top    = {-0.4375, 0.4375, -0.3125, 0.4375, 0.5, 0.3125},
			wall_bottom = {-0.4375, -0.5, -0.3125, 0.4375, -0.4375, 0.3125},
			wall_side   = {-0.5, -0.3125, -0.4375, -0.4375, 0.3125, 0.4375},
		},
		groups = def.groups,
		legacy_wallmounted = true,
		sounds = def.sounds,

		on_construct = function(pos)
			--local n = minetest.get_node(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("formspec", "field[text;;${text}]")
		end,
		on_receive_fields = function(pos, formname, fields, sender)
			--print("Sign at "..minetest.pos_to_string(pos).." got "..dump(fields))
			local player_name = sender:get_player_name()
			if minetest.is_protected(pos, player_name) then
				minetest.record_protection_violation(pos, player_name)
				return
			end
			local text = fields.text
			if not text then
				return
			end
			if string.len(text) > 512 then
				minetest.chat_send_player(player_name, "Text too long")
				return
			end
			minetest.log("action", (player_name or "") .. " wrote \"" ..
				text .. "\" to sign at " .. minetest.pos_to_string(pos))
			local meta = minetest.get_meta(pos)
			meta:set_string("text", text)
			meta:set_string("infotext", '"' .. text .. '"')
		end,
	})
end

-- TODO: Remove this code after removing blocks in-world
register_sign("Level sign", "Wooden", {
	--sounds = default.node_sound_wood_defaults(),
	groups = {choppy = 2, attached_node = 1, flammable = 2, oddly_breakable_by_hand = 3}
})

minetest.register_node("q_command:block_no_function", {
    description = "Non-functional Q command block",
    tiles = {"q_command_block_no_function.png"},
    groups = {oddly_breakable_by_hand=2},
	paramtype2 = "facedir",
    on_rightclick = function(pos, node, clicker, itemstack)
        if mpd.playing then
            minetest.chat_send_player(clicker:get_player_name(),
                    "Pausing music")
            mpd.stop_song()
        else
            minetest.chat_send_player(clicker:get_player_name(),
                    "Starting music")
            mpd.play_song(MUSIC_CHILL)
        end
    end
})


for num_qubits = 1, BASIS_STATE_BLOCK_MAX_QUBITS do
    for basis_state_num = 0, 2^num_qubits - 1 do
        q_command:register_basis_state_block(num_qubits, basis_state_num)
    end
end

local ROTATION_RESOLUTION = 32
for idx = 0, ROTATION_RESOLUTION do
    q_command:register_statevector_liquid_block(idx)
end






