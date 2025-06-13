-- conf.lua
-- This file is used by LÖVE to set up the game window and other global configurations.
-- It's automatically run before main.lua.

function love.conf(t)
    t.identity = "OfficeOverlord"         -- The name of the save directory
    t.version = "11.4"                   -- The LÖVE version this game was made for
    t.console = true                     -- Attach a console (useful for debugging)

    t.window.title = "Office Overlord - LÖVE 2D Edition" -- Set the window title
    t.window.width = 1280                -- Set the window width
    t.window.height = 720               -- Set the window height
    
    -- Add these three lines to enable resizing and set minimums
    t.window.resizable = true
    t.window.minwidth = 1024
    t.window.minheight = 640

    t.window.vsync = 1

    -- Explicitly enable modules you use:
    t.modules.audio = true
    t.modules.event = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true  -- <<< ENSURE THIS LINE IS PRESENT AND TRUE
    t.modules.window = true
    
    -- Disable unused modules if you're sure:
    t.modules.joystick = false 
    t.modules.physics = false 
    t.modules.touch = true -- Keep if you might support touch
    t.modules.video = false
    t.modules.thread = false
end