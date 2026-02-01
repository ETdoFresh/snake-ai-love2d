-- Snake Game Entry Point
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
