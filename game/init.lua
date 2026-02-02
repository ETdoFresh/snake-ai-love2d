-- game/init.lua - Game Module Re-export
--
-- This file re-exports the game module for the parent hot-reload system.
-- IMPORTANT: This file must NOT define any love.* callbacks (load, update, draw, keypressed).
-- The parent snake-ai/main.lua handles all Love2D callbacks and provides:
--   - Hot-reload support
--   - AI console (backtick key)
--   - File watching
--   - Error handling
--
-- The parent loader calls the module's methods directly:
--   - init() - Initialize game state
--   - update(dt) - Game loop
--   - draw() - Render game
--   - keypressed(key, scancode, isrepeat) - Handle input
--   - getState() - Return state for hot-reload preservation
--   - reload(savedState) - Restore state after hot-reload

return require("game.game")
