--- Global Functions
-- @module global

local global = {}

--- Check if we are on dedicated server
global.is_dedicated_server = false

--- Get a random chance
-- @param chance A chance number
-- @return true if it has a chance, false otherwise
function global.rand_chance(chance)
end

--- Alert the user
-- In Dedicated Servers, the message will be printed to console instead.
-- @param msg The message to alert the user
function global.alert(msg)
end

--- Get the currently running game
-- @return A Game
function global.get_game()
end


return global
