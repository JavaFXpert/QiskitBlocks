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


--[[
TODO:
[X] Allow bloch sphere block to be placed on second to rightmost column
[] Use state tomography or purity to update bloch-sphere blocks
- https://github.com/Qiskit/qiskit-tutorials/blob/master/qiskit/ignis/state_tomography.ipynb
[] Fix problem of control qubit erased when it can't be placed becuase of running into
    another gate. Probably need to add code to on_punch and on_right_click.
[] Investigate punch_operable for rotate and control tools
[] Implement appropriate gate images for CRZ gate
[] Ability for measurement block to actuate (e.g. turn on a light or open door)
    [] Investigate use of http://mesecons.net/items.html for in-world activation and sensing
    [] Ability for measured output wire to feed into input of same circuit
[] Fix problem of deleting a control qubit by left-clicking with a circuit block.
[] Tighten up circuit connector blocks and wire extension appearance and behavior
    [] Modify texture configuration on circuit connector blocks (M & F) so that they appear
	correct on the back side as well
    [] Make circuit extension M block item fall where it can easily be picked up
    [] Label M & F connectors with autogenerated labels in order of being placed
    [] Protect against orphaning wire extensions
    [] Set wire_extension itemstack count to 0 when deleting wire extension related elements
    [] Don't allow extenders to be placed on extensions.
    [] Prevent digging a wire connection block if wire extension exists
[] Implement reset
[] Implement classical registers and conditionals supported by OpenQASM
[] Implement games like Tiq Taq Toe (the following, or MTod's versions)
- https://quantumfrontiers.com/2019/07/15/tiqtaqtoe/
[] Prevent ket blocks from being deleted easily
    [] Right-clicking input ket flips to opposite state
[] Make rest of tools and blocks reach farther in non-creative mode
[] Create Alice and Bob mobs that coach the player in some small way
[] Create basement under the quantum circuits in the garden that show matrices/vectors/geometric interpretation of 2D vector spaces
[] SPECIAL-right-click make X/Y/Z gates automatically rotate clockwise
[] Check for pos x and z being nil instead of ~= 0 so that things don't break on pos x==0 or z==0
[] Prevent right-clicking on wire_extension_block after wire_extension exists
[] Don't allow creating circuit if already exists
[] Create an area where a mob does a quantum random walk
[] Display wire local state
[] Clicking basis state ellipse block shows a state vector display?
[] Create game environment with rooms that are significant in quantum computing history
[] Make arrow blocks (connector, extenders, etc.) point correct direction on all sides
[] Can liquid blocks have tooltip that shows probability and other info (e.g. amp & phase)?
[] Find better way of programmatically distinguishing (than leading underscore) between
    blocks that may reside on the circuit grid and those that may not
[] Filter inventory panel (e.g. hide rotation blocks)
[] Use JWootton terrain generation mod
[] Make |0> |1> labels on measure block on left & right
[] Remove circuit_gate group code
[] Understand and standardize on when to use colon, or dot, as function separator
[] Find alternative to hardcoding node name strings everywhere
[] Remove hearts from creative mode
[] Update music and sounds
[] Create blocks (e.g. classical optimizer) to demonstrate variational algorithms
[] Should this warning be addressed?
	2019-06-29 08:11:11: WARNING[Main]: Irrlicht: PNG warning: iCCP: CRC error
--]]

LOG_DEBUG = false

dofile(minetest.get_modpath("circuit_blocks").."/circuit_blocks.lua");
dofile(minetest.get_modpath("circuit_blocks").."/circuit_node_types.lua");

minetest.register_node("circuit_blocks:_qubit_0", {
    description = "Qubit 0 block",
    tiles = {"circuit_blocks_qubit_0.png"},
    groups = {oddly_breakable_by_hand=2},
	paramtype2 = "facedir"
})

minetest.register_node("circuit_blocks:_qubit_1", {
    description = "Qubit 1 block",
    tiles = {"circuit_blocks_qubit_1.png"},
    groups = {oddly_breakable_by_hand=2},
	paramtype2 = "facedir"
})

minetest.register_node("circuit_blocks:_alice_cat_0", {
    description = "Alice cat grumpy block",
    tiles = {"circuit_blocks_alice_cat_0.png"},
    groups = {oddly_breakable_by_hand=2},
	paramtype2 = "facedir"
})

minetest.register_node("circuit_blocks:_alice_cat_1", {
    description = "Alice cat happy block",
    tiles = {"circuit_blocks_alice_cat_1.png"},
    groups = {oddly_breakable_by_hand=2},
	paramtype2 = "facedir"
})

minetest.register_node("circuit_blocks:_bob_cat_0", {
    description = "Bob cat grumpy block",
    tiles = {"circuit_blocks_bob_cat_0.png"},
    groups = {oddly_breakable_by_hand=2},
	paramtype2 = "facedir"
})

minetest.register_node("circuit_blocks:_bob_cat_1", {
    description = "Bob cat happy block",
    tiles = {"circuit_blocks_bob_cat_1.png"},
    groups = {oddly_breakable_by_hand=2},
	paramtype2 = "facedir"
})

minetest.register_tool("circuit_blocks:control_tool", {
	description = "Control tool",
	inventory_image = "circuit_blocks_control_tool.png",
	wield_image = "circuit_blocks_control_tool.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	range = 16,
	tool_capabilities = {},
})

minetest.register_tool("circuit_blocks:rotate_tool", {
	description = "Rotate tool",
	inventory_image = "circuit_blocks_rotate_tool.png",
	wield_image = "circuit_blocks_rotate_tool.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	range = 16,
	tool_capabilities = {},
})

minetest.register_tool("circuit_blocks:swap_tool", {
	description = "Swap tool",
	inventory_image = "circuit_blocks_swap_tool.png",
	wield_image = "circuit_blocks_swap_tool.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	range = 16,
	tool_capabilities = {},
})

circuit_blocks:register_circuit_block(CircuitNodeTypes.EMPTY, false, false, 0, false)
circuit_blocks:register_circuit_block(CircuitNodeTypes.X, false, false, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.X, true, true, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.X, true, false, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.X, false, true, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.H, false, false, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.H, true, false, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.H, false, true, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.Y, false, false, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.Y, true, false, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.Y, false, true, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.Z, false, false, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.Z, true, false, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.Z, false, true, 0, true)
circuit_blocks:register_circuit_block(CircuitNodeTypes.SWAP, false, false, 0, true, "", "")
circuit_blocks:register_circuit_block(CircuitNodeTypes.SWAP, true, false, 0, true, "", "")
circuit_blocks:register_circuit_block(CircuitNodeTypes.SWAP, false, true, 0, true, "", "")
circuit_blocks:register_circuit_block(CircuitNodeTypes.SWAP, false, false, 0, true, "", "_mate")
circuit_blocks:register_circuit_block(CircuitNodeTypes.SWAP, true, false, 0, true, "", "_mate")
circuit_blocks:register_circuit_block(CircuitNodeTypes.SWAP, false, true, 0, true, "", "_mate")
circuit_blocks:register_circuit_block(CircuitNodeTypes.S, false, false, 0, false)
circuit_blocks:register_circuit_block(CircuitNodeTypes.SDG, false, false, 0, false)
circuit_blocks:register_circuit_block(CircuitNodeTypes.T, false, false, 0, false)
circuit_blocks:register_circuit_block(CircuitNodeTypes.TDG, false, false, 0, false)
circuit_blocks:register_circuit_block(CircuitNodeTypes.CTRL, true, true, 0, false, "", "")
circuit_blocks:register_circuit_block(CircuitNodeTypes.CTRL, true, false, 0, false, "", "")
circuit_blocks:register_circuit_block(CircuitNodeTypes.CTRL, false, true, 0, false, "", "")
circuit_blocks:register_circuit_block(CircuitNodeTypes.CTRL, true, true, 0, false, "", "_b")
circuit_blocks:register_circuit_block(CircuitNodeTypes.CTRL, true, false, 0, false, "", "_b")
circuit_blocks:register_circuit_block(CircuitNodeTypes.CTRL, false, true, 0, false, "", "_b")
circuit_blocks:register_circuit_block(CircuitNodeTypes.TRACE, false, false, 0, false)
circuit_blocks:register_circuit_block(CircuitNodeTypes.BARRIER, false, false, 0, false)
circuit_blocks:register_circuit_block(CircuitNodeTypes.MEASURE_Z, false, false, 0, false,"", "z")
circuit_blocks:register_circuit_block(CircuitNodeTypes.MEASURE_Z, false, false, 0, false,"","0")
circuit_blocks:register_circuit_block(CircuitNodeTypes.MEASURE_Z, false, false, 0, false, "","1")
circuit_blocks:register_circuit_block(CircuitNodeTypes.MEASURE_Z, false, false, 0, false, "","alice_cat")
circuit_blocks:register_circuit_block(CircuitNodeTypes.MEASURE_Z, false, false, 0, false, "","bob_cat")
circuit_blocks:register_circuit_block(CircuitNodeTypes.MEASURE_Z, false, false, 0, false, "","alice_cat_0")
circuit_blocks:register_circuit_block(CircuitNodeTypes.MEASURE_Z, false, false, 0, false, "","alice_cat_1")
circuit_blocks:register_circuit_block(CircuitNodeTypes.MEASURE_Z, false, false, 0, false, "","bob_cat_0")
circuit_blocks:register_circuit_block(CircuitNodeTypes.MEASURE_Z, false, false, 0, false, "","bob_cat_1")
circuit_blocks:register_circuit_block(CircuitNodeTypes.CONNECTOR_M, false, false, 0, false, "q_command:wire_extension_block")
-- circuit_blocks:register_circuit_block(CircuitNodeTypes.CONNECTOR_F, false, false, 0, false)

local ROTATION_RESOLUTION = 32
for idx = 0, ROTATION_RESOLUTION do
    circuit_blocks:register_circuit_block(CircuitNodeTypes.X, false, false, idx, true)
    circuit_blocks:register_circuit_block(CircuitNodeTypes.Y, false, false, idx, true)
    circuit_blocks:register_circuit_block(CircuitNodeTypes.Z, false, false, idx, true)
end

for y_rot = 0, 8 do
    for z_rot = 0, 15 do
        circuit_blocks:register_circuit_block(CircuitNodeTypes.BLOCH_SPHERE, false, false, 0, false, "", "", y_rot, z_rot)
    end
end

-- Create a blank Block sphere
circuit_blocks:register_circuit_block(CircuitNodeTypes.BLOCH_SPHERE, false, false, 0, false, "", "", nil, nil)
