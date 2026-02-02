-- Snake Game
-- A classic Snake game built with Love2D
-- Run directly: love game/
-- Supports hot-reload via getState() and reload() functions

-- Game module
local game = {}

-- Constants
local GRID_WIDTH = 20
local GRID_HEIGHT = 20
local MOVE_INTERVAL = 0.1
local SPEED_BOOST_INTERVAL = 0.05
local SPEED_BOOST_DURATION = 5.0
local SPEED_BOOST_SPAWN_MIN = 8.0
local SPEED_BOOST_SPAWN_MAX = 15.0
local HUD_HEIGHT = 40

local COLORS = {
    background = {0.1, 0.1, 0.15, 1},
    grid = {0.15, 0.15, 0.2, 1},
    food = {0.9, 0.3, 0.3, 1},
    speed_boost = {0.2, 0.7, 0.9, 1},
    speed_boost_active = {0.4, 0.9, 1.0, 1},
    text = {1, 1, 1, 1},
    menu_bg = {0, 0, 0, 0.7},
    menu_selected = {0.4, 0.8, 0.4, 1}
}

-- Game state
local state = nil

-- Helper function to deep copy a table
local function deepCopy(orig)
    if type(orig) ~= 'table' then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = deepCopy(v)
    end
    return copy
end

-- Helper functions
local function getScaleAndOffsets()
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    local availableWidth = windowWidth - 40
    local availableHeight = windowHeight - HUD_HEIGHT - 40
    local scaleX = availableWidth / GRID_WIDTH
    local scaleY = availableHeight / GRID_HEIGHT
    local scale = math.max(8, math.min(scaleX, scaleY))
    local gameWidth = GRID_WIDTH * scale
    local gameHeight = GRID_HEIGHT * scale
    local offsetX = (windowWidth - gameWidth) / 2
    local offsetY = (windowHeight - HUD_HEIGHT - gameHeight) / 2
    return scale, offsetX, offsetY
end

local function spawnFood()
    local valid = false
    while not valid do
        state.food = {
            x = love.math.random(1, GRID_WIDTH),
            y = love.math.random(1, GRID_HEIGHT)
        }
        valid = true
        for _, segment in ipairs(state.snake) do
            if segment.x == state.food.x and segment.y == state.food.y then
                valid = false
                break
            end
        end
        if valid and state.speedBoost then
            if state.food.x == state.speedBoost.x and state.food.y == state.speedBoost.y then
                valid = false
            end
        end
    end
end

local function spawnSpeedBoost()
    local valid = false
    while not valid do
        state.speedBoost = {
            x = love.math.random(1, GRID_WIDTH),
            y = love.math.random(1, GRID_HEIGHT)
        }
        valid = true
        for _, segment in ipairs(state.snake) do
            if segment.x == state.speedBoost.x and segment.y == state.speedBoost.y then
                valid = false
                break
            end
        end
        if valid and state.food then
            if state.speedBoost.x == state.food.x and state.speedBoost.y == state.food.y then
                valid = false
            end
        end
    end
end

local function initGame()
    state = {
        snake = {{x = 10, y = 10}, {x = 9, y = 10}, {x = 8, y = 10}},
        direction = {x = 1, y = 0},
        nextDirection = {x = 1, y = 0},
        food = {x = 15, y = 10},
        score = 0,
        highScore = 0,
        gameOver = false,
        moveTimer = 0,
        screen = "menu",
        menuSelection = 1,
        pauseSelection = 1,
        rainbowMode = false,
        rainbowTimer = 0,
        rainbowDuration = 1.5,
        rainbowOffset = 0,
        speedBoost = nil,
        speedBoostActive = false,
        speedBoostTimer = 0,
        speedBoostSpawnTimer = love.math.random() * (SPEED_BOOST_SPAWN_MAX - SPEED_BOOST_SPAWN_MIN) + SPEED_BOOST_SPAWN_MIN
    }
    spawnFood()
end

local function restartGame()
    local highScore = state.highScore
    initGame()
    state.highScore = highScore
    state.screen = "playing"
end

local function checkSelfCollision()
    local head = state.snake[1]
    for i = 2, #state.snake do
        if state.snake[i].x == head.x and state.snake[i].y == head.y then
            return true
        end
    end
    return false
end

local function moveSnake()
    state.direction = state.nextDirection
    local head = state.snake[1]
    local newHead = {
        x = head.x + state.direction.x,
        y = head.y + state.direction.y
    }

    -- Wrap around
    if newHead.x < 1 then newHead.x = GRID_WIDTH
    elseif newHead.x > GRID_WIDTH then newHead.x = 1 end
    if newHead.y < 1 then newHead.y = GRID_HEIGHT
    elseif newHead.y > GRID_HEIGHT then newHead.y = 1 end

    table.insert(state.snake, 1, newHead)

    -- Food collision
    if newHead.x == state.food.x and newHead.y == state.food.y then
        state.score = state.score + 10
        if state.score > state.highScore then state.highScore = state.score end
        state.rainbowMode = true
        state.rainbowTimer = state.rainbowDuration
        spawnFood()
    else
        table.remove(state.snake)
    end

    -- Speed boost collision
    if state.speedBoost and newHead.x == state.speedBoost.x and newHead.y == state.speedBoost.y then
        state.speedBoostActive = true
        state.speedBoostTimer = SPEED_BOOST_DURATION
        state.speedBoost = nil
        state.speedBoostSpawnTimer = love.math.random() * (SPEED_BOOST_SPAWN_MAX - SPEED_BOOST_SPAWN_MIN) + SPEED_BOOST_SPAWN_MIN
        state.score = state.score + 25
        if state.score > state.highScore then state.highScore = state.score end
    end

    if checkSelfCollision() then
        state.gameOver = true
        state.screen = "gameover"
    end
end

-- Draw functions
local function drawGrid()
    local scale, offsetX, offsetY = getScaleAndOffsets()
    love.graphics.setColor(COLORS.grid)
    for x = 0, GRID_WIDTH do
        love.graphics.line(offsetX + x * scale, offsetY, offsetX + x * scale, offsetY + GRID_HEIGHT * scale)
    end
    for y = 0, GRID_HEIGHT do
        love.graphics.line(offsetX, offsetY + y * scale, offsetX + GRID_WIDTH * scale, offsetY + y * scale)
    end
end

local function drawSnake()
    local scale, offsetX, offsetY = getScaleAndOffsets()
    for i, segment in ipairs(state.snake) do
        local r, g, b = 0, 0, 0

        if state.rainbowMode then
            local fadeProgress = state.rainbowTimer / state.rainbowDuration
            local fade = math.sin(fadeProgress * math.pi)
            if i == 1 then
                local greenR, greenG, greenB = 0.2, 1.0, 0.2
                local purpleR, purpleG, purpleB = 0.8, 0.4, 0.9
                r = greenR + (purpleR - greenR) * fade
                g = greenG + (purpleG - greenG) * fade
                b = greenB + (purpleB - greenB) * fade
            else
                local gradient = math.max(0.4, 1 - (i * 0.05))
                local greenR, greenG, greenB = 0.1 * gradient, 0.9 * gradient, 0.1 * gradient
                local purpleR, purpleG, purpleB = 0.6 * gradient, 0.2 * gradient, 0.8 * gradient
                r = greenR + (purpleR - greenR) * fade
                g = greenG + (purpleG - greenG) * fade
                b = greenB + (purpleB - greenB) * fade
            end
        else
            if i == 1 then
                r, g, b = 0.2, 1.0, 0.2
            else
                local gradient = math.max(0.4, 1 - (i * 0.05))
                r, g, b = 0.1 * gradient, 0.9 * gradient, 0.1 * gradient
            end
        end

        if state.speedBoostActive then
            local time = love.timer.getTime()
            local pulse = 0.5 + 0.5 * math.sin(time * 10 + i * 0.3)
            r = r * 0.5 + COLORS.speed_boost_active[1] * 0.5 * pulse
            g = g * 0.5 + COLORS.speed_boost_active[2] * 0.5 * pulse
            b = b * 0.5 + COLORS.speed_boost_active[3] * 0.5 * pulse
        end

        love.graphics.setColor(r, g, b, 1)
        local margin = math.max(1, math.floor(scale * 0.1))
        love.graphics.rectangle("fill",
            offsetX + (segment.x - 1) * scale + margin,
            offsetY + (segment.y - 1) * scale + margin,
            scale - margin * 2,
            scale - margin * 2
        )
    end
end

local function drawFood()
    local scale, offsetX, offsetY = getScaleAndOffsets()
    love.graphics.setColor(COLORS.food)
    local centerX = offsetX + (state.food.x - 1) * scale + scale / 2
    local centerY = offsetY + (state.food.y - 1) * scale + scale / 2
    local radius = (scale - math.max(2, math.floor(scale * 0.2))) / 2
    love.graphics.circle("fill", centerX, centerY, radius)
end

local function drawSpeedBoost()
    if not state.speedBoost then return end
    local scale, offsetX, offsetY = getScaleAndOffsets()
    local centerX = offsetX + (state.speedBoost.x - 1) * scale + scale / 2
    local centerY = offsetY + (state.speedBoost.y - 1) * scale + scale / 2
    local radius = math.max(2, (scale - 4) / 2)
    local time = love.timer.getTime()
    local pulse = 0.8 + 0.2 * math.sin(time * 5)

    love.graphics.setColor(COLORS.speed_boost[1], COLORS.speed_boost[2], COLORS.speed_boost[3], 0.3 * pulse)
    love.graphics.circle("fill", centerX, centerY, radius * 1.4)
    love.graphics.setColor(COLORS.speed_boost[1] * pulse, COLORS.speed_boost[2] * pulse, COLORS.speed_boost[3] * pulse, 1)
    local size = radius * 0.9
    love.graphics.polygon("fill", centerX, centerY - size, centerX + size, centerY, centerX, centerY + size, centerX - size, centerY)
    love.graphics.setColor(1, 1, 1, 0.5 * pulse)
    local innerSize = size * 0.4
    love.graphics.polygon("fill", centerX, centerY - innerSize, centerX + innerSize, centerY, centerX, centerY + innerSize, centerX - innerSize, centerY)
end

local function drawHUD()
    local scale = getScaleAndOffsets()
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    love.graphics.setColor(COLORS.text)
    local hudY = windowHeight - HUD_HEIGHT + 10
    local padding = 20

    love.graphics.print("Score: " .. state.score, padding, hudY)
    love.graphics.print("Length: " .. #state.snake, (windowWidth - love.graphics.getFont():getWidth("Length: " .. #state.snake)) / 2, hudY)
    love.graphics.print("High Score: " .. state.highScore, windowWidth - love.graphics.getFont():getWidth("High Score: " .. state.highScore) - padding, hudY)

    if state.speedBoostActive then
        local time = love.timer.getTime()
        local pulse = 0.7 + 0.3 * math.sin(time * 8)
        love.graphics.setColor(COLORS.speed_boost_active[1] * pulse, COLORS.speed_boost_active[2] * pulse, COLORS.speed_boost_active[3] * pulse, 1)
        local boostText = string.format("SPEED BOOST! %.1fs", state.speedBoostTimer)
        love.graphics.print(boostText, (windowWidth - love.graphics.getFont():getWidth(boostText)) / 2, 10)
    end
end

local function drawMenu()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(COLORS.menu_bg)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local defaultFont = love.graphics.getFont()
    local font = love.graphics.newFont(48)
    love.graphics.setFont(font)

    local title = "SNAKE GAME"
    local titleY = h/3
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.printf(title, 3, titleY + 3, w, "center")
    love.graphics.setColor(0.2, 0.9, 0.3, 1)
    love.graphics.printf(title, 0, titleY, w, "center")
    love.graphics.printf(title, 1, titleY, w, "center")
    love.graphics.printf(title, 0, titleY + 1, w, "center")
    love.graphics.printf(title, 1, titleY + 1, w, "center")
    love.graphics.setFont(defaultFont)

    local options = {"Start Game", "Quit"}
    for i, opt in ipairs(options) do
        if i == state.menuSelection then
            love.graphics.setColor(COLORS.menu_selected)
            opt = "> " .. opt .. " <"
        else
            love.graphics.setColor(COLORS.text)
        end
        love.graphics.printf(opt, 0, h/2 + (i-1) * 30, w, "center")
    end

    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.printf("Press ` for AI Console", 0, h - 50, w, "center")
end

local function drawPaused()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    drawGrid()
    drawFood()
    drawSnake()

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local defaultFont = love.graphics.getFont()
    local font = love.graphics.newFont(48)
    love.graphics.setFont(font)

    local titleText = "GAME PAUSED"
    local titleY = h/4
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.printf(titleText, 3, titleY + 3, w, "center")
    love.graphics.setColor(1, 0.2, 0.2, 1)
    love.graphics.printf(titleText, 0, titleY, w, "center")
    love.graphics.printf(titleText, 1, titleY, w, "center")
    love.graphics.printf(titleText, 0, titleY + 1, w, "center")
    love.graphics.printf(titleText, 1, titleY + 1, w, "center")
    love.graphics.setFont(defaultFont)

    love.graphics.setColor(COLORS.text)
    local statsY = h/3 + 20
    love.graphics.printf("Current Score: " .. state.score, 0, statsY, w, "center")
    love.graphics.printf("High Score: " .. state.highScore, 0, statsY + 25, w, "center")
    love.graphics.printf("Snake Length: " .. #state.snake, 0, statsY + 50, w, "center")

    local options = {"Resume", "Restart", "Main Menu"}
    local menuStartY = h/2 + 40
    for i, opt in ipairs(options) do
        if i == state.pauseSelection then
            love.graphics.setColor(COLORS.menu_selected)
            opt = "> " .. opt .. " <"
        else
            love.graphics.setColor(COLORS.text)
        end
        love.graphics.printf(opt, 0, menuStartY + (i-1) * 35, w, "center")
    end

    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf("WASD/Arrow Keys: Move Snake", 0, h - 55, w, "center")
end

local function drawGameOver()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(COLORS.menu_bg)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local defaultFont = love.graphics.getFont()
    local font = love.graphics.newFont(72)
    love.graphics.setFont(font)

    local titleText = "GAME OVER"
    local titleY = h/3
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(titleText, 4, titleY + 4, w, "center")
    love.graphics.setColor(COLORS.food)
    for dx = 0, 2 do
        for dy = 0, 2 do
            love.graphics.printf(titleText, dx, titleY + dy, w, "center")
        end
    end
    love.graphics.setFont(defaultFont)

    love.graphics.setColor(COLORS.text)
    love.graphics.printf("Score: " .. state.score, 0, h/2, w, "center")
    love.graphics.printf("High Score: " .. state.highScore, 0, h/2 + 30, w, "center")
    love.graphics.printf("Press ENTER to restart", 0, h/2 + 80, w, "center")
    love.graphics.printf("Press ESC for menu", 0, h/2 + 110, w, "center")
end

-- Module functions (for hot-reload support)

-- Initialize the game (called by love.load or after reload without saved state)
function game.init()
    love.keyboard.setKeyRepeat(true)
    initGame()
end

-- Update game logic
function game.update(dt)
    if state.screen ~= "playing" then return end

    if state.rainbowMode then
        state.rainbowTimer = state.rainbowTimer - dt
        state.rainbowOffset = state.rainbowOffset + dt * 2
        if state.rainbowTimer <= 0 then
            state.rainbowMode = false
            state.rainbowTimer = 0
            state.rainbowOffset = 0
        end
    end

    if state.speedBoostActive then
        state.speedBoostTimer = state.speedBoostTimer - dt
        if state.speedBoostTimer <= 0 then
            state.speedBoostActive = false
            state.speedBoostTimer = 0
        end
    end

    if not state.speedBoost and not state.speedBoostActive then
        state.speedBoostSpawnTimer = state.speedBoostSpawnTimer - dt
        if state.speedBoostSpawnTimer <= 0 then
            spawnSpeedBoost()
        end
    end

    local currentInterval = state.speedBoostActive and SPEED_BOOST_INTERVAL or MOVE_INTERVAL
    state.moveTimer = state.moveTimer + dt
    if state.moveTimer >= currentInterval then
        state.moveTimer = state.moveTimer - currentInterval
        moveSnake()
    end
end

-- Draw the game
function game.draw()
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    if state.screen == "menu" then
        drawMenu()
    else
        drawGrid()
        drawFood()
        drawSpeedBoost()
        drawSnake()
        drawHUD()

        if state.screen == "paused" then
            drawPaused()
        elseif state.screen == "gameover" then
            drawGameOver()
        end
    end
end

-- Handle key presses
function game.keypressed(key, scancode, isrepeat)
    if isrepeat and (state.screen == "menu" or state.screen == "paused" or state.screen == "gameover") then
        return
    end

    if state.screen == "menu" then
        if key == "up" then
            state.menuSelection = state.menuSelection - 1
            if state.menuSelection < 1 then state.menuSelection = 2 end
        elseif key == "down" then
            state.menuSelection = state.menuSelection + 1
            if state.menuSelection > 2 then state.menuSelection = 1 end
        elseif key == "return" or key == "space" then
            if state.menuSelection == 1 then
                state.screen = "playing"
            else
                love.event.quit()
            end
        end
    elseif state.screen == "playing" then
        if key == "up" or key == "w" then
            if state.direction.y ~= 1 then state.nextDirection = {x = 0, y = -1} end
        elseif key == "down" or key == "s" then
            if state.direction.y ~= -1 then state.nextDirection = {x = 0, y = 1} end
        elseif key == "left" or key == "a" then
            if state.direction.x ~= 1 then state.nextDirection = {x = -1, y = 0} end
        elseif key == "right" or key == "d" then
            if state.direction.x ~= -1 then state.nextDirection = {x = 1, y = 0} end
        elseif key == "escape" then
            state.screen = "paused"
            state.pauseSelection = 1
        end
    elseif state.screen == "paused" then
        if key == "up" then
            state.pauseSelection = state.pauseSelection - 1
            if state.pauseSelection < 1 then state.pauseSelection = 3 end
        elseif key == "down" then
            state.pauseSelection = state.pauseSelection + 1
            if state.pauseSelection > 3 then state.pauseSelection = 1 end
        elseif key == "return" or key == "space" then
            if state.pauseSelection == 1 then
                state.screen = "playing"
            elseif state.pauseSelection == 2 then
                restartGame()
            else
                state.screen = "menu"
                initGame()
            end
        elseif key == "escape" then
            state.screen = "playing"
        end
    elseif state.screen == "gameover" then
        if key == "return" or key == "space" then
            restartGame()
        elseif key == "escape" then
            state.screen = "menu"
            initGame()
        end
    end
end

-- Get a copy of the current game state for hot-reload preservation
function game.getState()
    if not state then
        return nil
    end
    return deepCopy(state)
end

-- Reload the game with a saved state (for hot-reload)
function game.reload(savedState)
    love.keyboard.setKeyRepeat(true)
    if savedState then
        state = deepCopy(savedState)
    else
        initGame()
    end
end

-- Love2D callbacks (delegate to module functions)
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

return game
