--- A Mod Loader
-- @module fc

local fc = {}

--- Get path from mod id
-- @param id The Mod ID
-- @return The Mod Directory or empty string if it does not exist
function fc.get_mod_path(id)
end

--- Get Mod's Asset
-- @param asset The asset name in the form '<id>/<asset>'
-- @return The Resource or nil if it does not exist
function fc.get_mod_asset(asset)
end

--- Add hook to the function
-- If the hook already has a function or if the function does not exist, it will throw a error
-- @param hook The Hook Name used from the game
-- @param func A Function Name (that isn't local)
function fc.add_hook(hook, func)
end

--- Call a hook
-- This is not needed as the game already calls the hooks.
-- @param hook The Hook Name to call
-- @param args The Arguments used for calling
function fc.call_hook(hook, args)
end

--- Add a custom gamemode to the list
-- This cannot be used to add custom gamemodes based on existing ones.
-- @param name A Name for the custom gamemode
-- @param asset A Mod Asset to use as a icon (must be a valid image!)
function fc.add_custom_gamemode(name, asset)
end

--- Send a custom RPC
-- This is mainly useful for making other players be in sync.
-- @param data The data to send to all players, this can be any table.
function fc.send_custom_rpc(data)
end

return fc
