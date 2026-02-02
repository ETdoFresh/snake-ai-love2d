-- Snake Game Entry Point
-- This file handles all Love2D callbacks and loads the game module.
-- The game module (game/init.lua) re-exports game/game.lua which contains:
--   - init() - Initialize game state
--   - update(dt) - Game loop
--   - draw() - Render game
--   - keypressed(key, scancode, isrepeat) - Handle input
--   - getState() - Return state for hot-reload preservation
--   - reload(savedState) - Restore state after hot-reload
local game = require("game")

function love.load()
    game.init()
end

function love.update(dt)
    game.update(dt)
end

function love.draw()
    game.draw()
end

function love.keypressed(key, scancode, isrepeat)
    game.keypressed(key, scancode, isrepeat)
end
