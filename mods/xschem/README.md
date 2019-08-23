# xschem

A mod which saves and loads areas with metadata using schematics

## Limitations

The mod should support maps of any size in PUC Lua, but is limited by LuaJIT's memory. Tested to work well up to 700x50x700.

Meta data is only copied from whitelisted nodes. This includes all `q_command` nodes and `default:chest*` nodes.
This can be customised by modifying the whitelist in init.lua

When the map is loading, it'll all be dark initially. After it has loaded, the light will then be fixed. This takes about 5 seconds on
and SSD.

## Updating the saved map

1. If the size of the area has changed, update the co-ordinates following the comment "CHANGE AREA HERE" in `xschem/init.lua`
2. Enter the world as usual
3. Make any changes you wish to make
4. Type: `/xschemsave`
5. Find save.mts and save.meta in the world's folder, and copy to `schematics/` in the xschem folder, overriding the existing files.

## Creating a new world

There are no real requirements to making a new world, however, to avoid sharp cliffs it is recommended to set the mapgen to "flat" and the seed to 0.
