local function emergeblocks_callback(pos, action, num_calls_remaining, ctx)
	if ctx.total_blocks == 0 then
		ctx.total_blocks   = num_calls_remaining + 1
		ctx.current_blocks = 0
	end
	ctx.current_blocks = ctx.current_blocks + 1

	if ctx.current_blocks == ctx.total_blocks then
		ctx:callback()
	end
end

local function emerge_with_callbacks(pos1, pos2, callback)
	local context = {
		current_blocks = 0,
		total_blocks   = 0,
		start_time     = os.clock(),
		callback       = callback,
	}

	minetest.emerge_area(pos1, pos2, emergeblocks_callback, context)
end

return emerge_with_callbacks
