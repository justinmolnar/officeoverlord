-- sound_manager.lua
-- A centralized module for managing and playing sound effects and music.

local SoundManager = {
    sounds = {},
    music = {},
    currentMusic = nil
}

function SoundManager:init()
    -- List of sound effects to load.
    -- You must create a "sounds" folder and place audio files with these names inside.
    local soundFiles = {
        click = "assets/sounds/click.wav",
        hire = "assets/sounds/hire.wav",
        place = "assets/sounds/place.wav",
        win = "assets/sounds/work_complete.ogg",
        error = "assets/sounds/error.ogg"
    }

    -- List of music tracks to load.
    -- You must create a "music" folder and place audio files with these names inside.
    local musicFiles = {
        main = "assets/music/main_theme.ogg",
        battle = "assets/music/battle_theme.ogg"
    }

    -- Load sound effects
    for name, path in pairs(soundFiles) do
        local success, source = pcall(love.audio.newSource, path, "static")
        if success then
            self.sounds[name] = source
        else
            print("WARNING: Could not load sound effect: " .. path)
        end
    end

    -- Load music
    for name, path in pairs(musicFiles) do
        local success, source = pcall(love.audio.newSource, path, "stream")
        if success then
            source:setLooping(true)
            self.music[name] = source
        else
            print("WARNING: Could not load music track: " .. path)
        end
    end
end

function SoundManager:playEffect(name)
    if self.sounds[name] then
        self.sounds[name]:play()
    end
end

function SoundManager:playMusic(name)
    if self.currentMusic then
        self.currentMusic:stop()
    end
    if self.music[name] then
        self.currentMusic = self.music[name]
        self.currentMusic:play()
    end
end

function SoundManager:stopMusic()
    if self.currentMusic then
        self.currentMusic:stop()
        self.currentMusic = nil
    end
end

return SoundManager