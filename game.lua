-- game.lua - Main Snake Game Module
--
-- This file contains the core game logic for a classic Snake game built with Love2D.
-- It handles all aspects of gameplay including:
--   - Game state management (snake position, food, score, high score)
--   - Snake movement with wrap-around boundaries (no wall collisions)
--   - Food spawning and collision detection
--   - Multiple game screens: menu, playing, paused, and game over
--   - Input handling for snake direction (WASD/arrow keys) and menu navigation
--   - Rendering of the game grid, snake (with rainbow effect on eating), food, and HUD
--   - Hot-reload support with state preservation for development
--
-- The module exports functions: init(), update(dt), keypressed(), draw(),
-- getState(), and reload() for integration with the main Love2D callbacks.

local M = {}

-- Constants (can be modified and hot-reloaded)
local GRID_WIDTH = 20
local GRID_HEIGHT = 20
local MOVE_INTERVAL = 0.1
local HUD_HEIGHT = 40  -- Space reserved for HUD

-- Calculate scale and offsets to fit the game in the window
local function getScaleAndOffsets()
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()

    -- Reserve space for HUD and borders
    local availableWidth = windowWidth - 40  -- 20px border on each side
    local availableHeight = windowHeight - HUD_HEIGHT - 40  -- HUD space + 20px borders top/bottom

    -- Calculate scale to fit the grid while maintaining aspect ratio
    local scaleX = availableWidth / GRID_WIDTH
    local scaleY = availableHeight / GRID_HEIGHT
    local scale = math.min(scaleX, scaleY)

    -- Ensure minimum readable size
    scale = math.max(scale, 8)

    -- Calculate actual game dimensions
    local gameWidth = GRID_WIDTH * scale
    local gameHeight = GRID_HEIGHT * scale

    -- Center the game in the available space
    local offsetX = (windowWidth - gameWidth) / 2
    local offsetY = (windowHeight - HUD_HEIGHT - gameHeight) / 2

    return scale, offsetX, offsetY
end

local COLORS = {
    background = {0.1, 0.1, 0.15, 1},
    grid = {0.15, 0.15, 0.2, 1},
    snake_head = {0.3, 0.8, 0.3, 1},
    snake_body = {0.2, 0.6, 0.2, 1},
    food = {0.9, 0.3, 0.3, 1},
    text = {1, 1, 1, 1},
    menu_bg = {0, 0, 0, 0.7},
    menu_selected = {0.4, 0.8, 0.4, 1}
}

-- Game state
local state = nil

-- Initialize game state
function M.init()
    state = {
        snake = {{x = 10, y = 10}, {x = 9, y = 10}, {x = 8, y = 10}},
        direction = {x = 1, y = 0},
        nextDirection = {x = 1, y = 0},
        food = {x = 15, y = 10},
        score = 0,
        highScore = 0,
        gameOver = false,
        moveTimer = 0,
        screen = "menu",  -- menu, playing, paused, gameover
        menuSelection = 1,
        pauseSelection = 1,
        rainbowMode = false,
        rainbowTimer = 0,
        rainbowDuration = 1.5,  -- 1.5 seconds of rainbow after eating
        rainbowOffset = 0
    }
    M.spawnFood()
end

-- Get state for hot-reload
function M.getState()
    return state
end

-- Reload with saved state
function M.reload(savedState)
    if savedState then
        state = savedState
        -- Migration: ensure all fields exist
        state.screen = state.screen or "playing"
        state.menuSelection = state.menuSelection or 1
        state.pauseSelection = state.pauseSelection or 1
        state.moveTimer = state.moveTimer or 0
        state.nextDirection = state.nextDirection or state.direction
        state.rainbowMode = state.rainbowMode or false
        state.rainbowTimer = state.rainbowTimer or 0
        state.rainbowDuration = state.rainbowDuration or 1.5
        state.rainbowOffset = state.rainbowOffset or 0
    else
        M.init()
    end
end

-- Spawn food at random location
function M.spawnFood()
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
    end
end

-- Check collision with self
local function checkSelfCollision()
    local head = state.snake[1]
    for i = 2, #state.snake do
        if state.snake[i].x == head.x and state.snake[i].y == head.y then
            return true
        end
    end
    return false
end

-- Check wall collision
local function checkWallCollision()
    local head = state.snake[1]
    return head.x < 1 or head.x > GRID_WIDTH or head.y < 1 or head.y > GRID_HEIGHT
end

-- Move snake
local function moveSnake()
    -- Apply buffered direction
    state.direction = state.nextDirection

    -- Calculate new head position with wrap-around
    local head = state.snake[1]
    local newHead = {
        x = head.x + state.direction.x,
        y = head.y + state.direction.y
    }

    -- Wrap around boundaries
    if newHead.x < 1 then
        newHead.x = GRID_WIDTH
    elseif newHead.x > GRID_WIDTH then
        newHead.x = 1
    end

    if newHead.y < 1 then
        newHead.y = GRID_HEIGHT
    elseif newHead.y > GRID_HEIGHT then
        newHead.y = 1
    end

    -- Insert new head
    table.insert(state.snake, 1, newHead)

    -- Check food collision
    if newHead.x == state.food.x and newHead.y == state.food.y then
        state.score = state.score + 10
        if state.score > state.highScore then
            state.highScore = state.score
        end
        -- Activate purple mode
        state.rainbowMode = true
        state.rainbowTimer = state.rainbowDuration
        M.spawnFood()
    else
        -- Remove tail
        table.remove(state.snake)
    end

    -- Check self collision only (no wall collision since we wrap around)
    if checkSelfCollision() then
        state.gameOver = true
        state.screen = "gameover"
    end
end

-- Restart game
local function restartGame()
    local highScore = state.highScore
    M.init()
    state.highScore = highScore
    state.screen = "playing"
end

-- Update game logic
function M.update(dt)
    if state.screen ~= "playing" then
        return
    end

    -- Update rainbow mode timer
    if state.rainbowMode then
        state.rainbowTimer = state.rainbowTimer - dt
        state.rainbowOffset = state.rainbowOffset + dt * 2  -- Scroll speed
        if state.rainbowTimer <= 0 then
            state.rainbowMode = false
            state.rainbowTimer = 0
            state.rainbowOffset = 0
        end
    end

    state.moveTimer = state.moveTimer + dt
    if state.moveTimer >= MOVE_INTERVAL then
        state.moveTimer = state.moveTimer - MOVE_INTERVAL
        moveSnake()
    end
end

-- Handle key press
function M.keypressed(key, scancode, isrepeat)
    -- Ignore key repeats for menu navigation (prevents fast scrolling on handhelds)
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
        -- Direction changes
        if key == "up" or key == "w" then
            if state.direction.y ~= 1 then
                state.nextDirection = {x = 0, y = -1}
            end
        elseif key == "down" or key == "s" then
            if state.direction.y ~= -1 then
                state.nextDirection = {x = 0, y = 1}
            end
        elseif key == "left" or key == "a" then
            if state.direction.x ~= 1 then
                state.nextDirection = {x = -1, y = 0}
            end
        elseif key == "right" or key == "d" then
            if state.direction.x ~= -1 then
                state.nextDirection = {x = 1, y = 0}
            end
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
                M.init()
            end
        elseif key == "escape" then
            state.screen = "playing"
        end
    elseif state.screen == "gameover" then
        if key == "return" or key == "space" then
            restartGame()
        elseif key == "escape" then
            state.screen = "menu"
            M.init()
        end
    end
end

-- Draw functions
local function drawGrid()
    local scale, offsetX, offsetY = getScaleAndOffsets()
    love.graphics.setColor(COLORS.grid)

    -- Draw vertical lines
    for x = 0, GRID_WIDTH do
        love.graphics.line(
            offsetX + x * scale,
            offsetY,
            offsetX + x * scale,
            offsetY + GRID_HEIGHT * scale
        )
    end

    -- Draw horizontal lines
    for y = 0, GRID_HEIGHT do
        love.graphics.line(
            offsetX,
            offsetY + y * scale,
            offsetX + GRID_WIDTH * scale,
            offsetY + y * scale
        )
    end
end

local function drawSnake()
    local scale, offsetX, offsetY = getScaleAndOffsets()
    for i, segment in ipairs(state.snake) do
        if state.rainbowMode then
            -- Fade from green to purple and back when eating food
            local fadeProgress = state.rainbowTimer / state.rainbowDuration
            -- Create a smooth fade: 0 -> 1 -> 0 over the duration
            local fade = math.sin(fadeProgress * math.pi)

            if i == 1 then
                -- Head: fade from bright green to bright purple
                local greenR, greenG, greenB = 0.4, 0.9, 0.4
                local purpleR, purpleG, purpleB = 0.8, 0.4, 0.9
                local r = greenR + (purpleR - greenR) * fade
                local g = greenG + (purpleG - greenG) * fade
                local b = greenB + (purpleB - greenB) * fade
                love.graphics.setColor(r, g, b, 1)
            else
                -- Body: fade from green gradient to purple gradient
                local gradient = 1 - (i * 0.05)
                gradient = math.max(gradient, 0.4)

                local greenR, greenG, greenB = 0.2 * gradient, 0.8 * gradient, 0.2 * gradient
                local purpleR, purpleG, purpleB = 0.6 * gradient, 0.2 * gradient, 0.8 * gradient
                local r = greenR + (purpleR - greenR) * fade
                local g = greenG + (purpleG - greenG) * fade
                local b = greenB + (purpleB - greenB) * fade
                love.graphics.setColor(r, g, b, 1)
            end
        else
            -- Normal green color scheme
            if i == 1 then
                -- Bright green for head
                love.graphics.setColor(0.4, 0.9, 0.4, 1)
            else
                -- Darker green for body, with slight gradient
                local gradient = 1 - (i * 0.05)  -- Slightly darker for each segment
                gradient = math.max(gradient, 0.4)  -- Don't go too dark
                love.graphics.setColor(0.2 * gradient, 0.8 * gradient, 0.2 * gradient, 1)
            end
        end

        -- Calculate segment margin based on scale to maintain visual appearance
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
    local radius = math.max(2, (scale - 4) / 2)

    -- Draw a circle
    love.graphics.circle("fill", centerX, centerY, radius)
end

local function drawHUD()
    local scale, offsetX, offsetY = getScaleAndOffsets()
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()

    love.graphics.setColor(COLORS.text)

    -- Position HUD at bottom of screen
    local hudY = windowHeight - HUD_HEIGHT + 10

    -- Center score information
    local scoreText = "Score: " .. state.score
    local highScoreText = "High Score: " .. state.highScore
    local snakeLength = "Length: " .. #state.snake

    -- Calculate text positioning to center and spread across window
    local padding = 20
    local scoreX = padding
    local centerX = (windowWidth - love.graphics.getFont():getWidth(snakeLength)) / 2
    local highScoreX = windowWidth - love.graphics.getFont():getWidth(highScoreText) - padding

    love.graphics.print(scoreText, scoreX, hudY)
    love.graphics.print(snakeLength, centerX, hudY)
    love.graphics.print(highScoreText, highScoreX, hudY)

    -- Show scale info in debug mode (comment out for release)
    love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
    love.graphics.print("Scale: " .. string.format("%.1fx", scale), padding, 10)
end

local function drawMenu()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    love.graphics.setColor(COLORS.menu_bg)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(COLORS.text)
    local title = "SNAKE GAME"
    love.graphics.printf(title, 0, h/3, w, "center")

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

    -- Draw faded game background
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    drawGrid()
    drawFood()
    drawSnake()

    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Title with drop shadow
    local defaultFont = love.graphics.getFont()  -- Store current font
    local font = love.graphics.newFont(48)  -- Back to original size
    love.graphics.setFont(font)

    local titleText = "GAME PAUSED"
    local titleY = h/4

    -- Draw drop shadow (offset by 3 pixels)
    love.graphics.setColor(0, 0, 0, 0.8)  -- Black shadow
    love.graphics.printf(titleText, 3, titleY + 3, w, "center")

    -- Draw bold effect by rendering text multiple times with slight offsets
    love.graphics.setColor(1, 0.2, 0.2, 1)  -- Bright red
    love.graphics.printf(titleText, 0, titleY, w, "center")
    love.graphics.printf(titleText, 1, titleY, w, "center")
    love.graphics.printf(titleText, 0, titleY + 1, w, "center")
    love.graphics.printf(titleText, 1, titleY + 1, w, "center")

    -- Reset to default font
    love.graphics.setFont(defaultFont)

    -- Game statistics
    love.graphics.setColor(COLORS.text)
    local snakeLength = #state.snake
    local statsY = h/3 + 20
    love.graphics.printf("Current Score: " .. state.score, 0, statsY, w, "center")
    love.graphics.printf("High Score: " .. state.highScore, 0, statsY + 25, w, "center")
    love.graphics.printf("Snake Length: " .. snakeLength, 0, statsY + 50, w, "center")

    -- Menu options
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

    -- Controls instructions
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf("↑↓ Navigate  •  ENTER Select  •  ESC Resume", 0, h - 80, w, "center")
    love.graphics.printf("WASD/Arrow Keys: Move Snake", 0, h - 55, w, "center")
end

local function drawGameOver()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    love.graphics.setColor(COLORS.menu_bg)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Extra bold "GAME OVER" text
    local defaultFont = love.graphics.getFont()  -- Store current font
    local font = love.graphics.newFont(72)  -- Even larger font size for extra bold appearance
    love.graphics.setFont(font)

    local titleText = "GAME OVER"
    local titleY = h/3

    -- Draw drop shadow (offset by 4 pixels for stronger effect)
    love.graphics.setColor(0, 0, 0, 0.9)  -- Darker shadow
    love.graphics.printf(titleText, 4, titleY + 4, w, "center")

    -- Draw extra bold effect by rendering text multiple times with more offsets
    love.graphics.setColor(COLORS.food)  -- Red color
    love.graphics.printf(titleText, 0, titleY, w, "center")
    love.graphics.printf(titleText, 1, titleY, w, "center")
    love.graphics.printf(titleText, 2, titleY, w, "center")
    love.graphics.printf(titleText, 0, titleY + 1, w, "center")
    love.graphics.printf(titleText, 1, titleY + 1, w, "center")
    love.graphics.printf(titleText, 2, titleY + 1, w, "center")
    love.graphics.printf(titleText, 0, titleY + 2, w, "center")
    love.graphics.printf(titleText, 1, titleY + 2, w, "center")
    love.graphics.printf(titleText, 2, titleY + 2, w, "center")

    -- Reset to default font
    love.graphics.setFont(defaultFont)

    love.graphics.setColor(COLORS.text)
    love.graphics.printf("Score: " .. state.score, 0, h/2, w, "center")
    love.graphics.printf("High Score: " .. state.highScore, 0, h/2 + 30, w, "center")
    love.graphics.printf("Press ENTER to restart", 0, h/2 + 80, w, "center")
    love.graphics.printf("Press ESC for menu", 0, h/2 + 110, w, "center")
end

-- Main draw function
function M.draw()
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    if state.screen == "menu" then
        drawMenu()
    else
        drawGrid()
        drawFood()
        drawSnake()
        drawHUD()

        if state.screen == "paused" then
            drawPaused()
        elseif state.screen == "gameover" then
            drawGameOver()
        end
    end
end

return M
