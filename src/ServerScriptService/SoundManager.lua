-- SoundManager.lua (ModuleScript)
-- Centralized server-side sound dispatcher. Other server modules call
-- SoundManager:PlayAt(soundKey, partOrPosition, volume) — a PlaySound
-- RemoteEvent fanout to every client, which creates the actual Sound
-- instance locally. Sounds parented to a Part inherit 3D audio falloff.
--
-- Asset IDs are user-provided; some may be invalid or unloadable. The
-- client-side SoundPlayer wraps Sound creation in pcall and prints a
-- warning if anything fails — the game does not crash on a bad asset.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundManager = {}

-- Sound library — keys are stable names used by callers; values are the
-- asset IDs to actually play. Edit values here to swap individual sounds
-- without touching call sites.
SoundManager.Sounds = {
    -- Stations
    CupGrab         = "rbxassetid://9116402097",
    EspressoPull    = "rbxassetid://3742023110",
    SyrupPump       = "rbxassetid://9119305266",
    MilkSteam       = "rbxassetid://9120476375",
    LidClick        = "rbxassetid://3744373440",
    Trash           = "rbxassetid://9112861971",

    -- Gameplay
    OrderComplete   = "rbxassetid://3120909354",
    WrongDrink      = "rbxassetid://3744371091",
    -- 9117990702 returned 403 in testing; swapped for a known-public whistle.
    RoundStart      = "rbxassetid://138081500",
    RoundEnd        = "rbxassetid://3744371091",
    ComboIncrease   = "rbxassetid://3120909354",
    ComboBreak      = "rbxassetid://9117997078",
    TipEarned       = "rbxassetid://3120909355",

    -- UI
    ButtonClick     = "rbxassetid://6042583773",
    MenuOpen        = "rbxassetid://4612375233",
    PurchaseSuccess = "rbxassetid://3120909354",

    -- Ambient / music
    BackgroundMusic = "rbxassetid://1837935739",
    OutdoorAmbience = "rbxassetid://9120476375",

    -- Drive-thru
    CarHorn         = "rbxassetid://9114046921",
    CarArrive       = "rbxassetid://3120909354",
}

local PlaySoundEvent  -- assigned lazily so the module doesn't yield on require

local function getRemote()
    if PlaySoundEvent then return PlaySoundEvent end
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    PlaySoundEvent = remotes:WaitForChild("PlaySound")
    return PlaySoundEvent
end

-- Play a sound. `targetOrNil` can be:
--   * a BasePart (sound is parented to that part for 3D audio)
--   * nil (sound plays as 2D, parented to SoundService client-side)
function SoundManager:PlayAt(soundKey, targetOrNil, volume)
    local soundId = self.Sounds[soundKey]
    if not soundId then
        warn("[SoundManager] Unknown sound key: " .. tostring(soundKey))
        return
    end
    getRemote():FireAllClients(soundId, targetOrNil, volume or 0.5)
end

-- Same as PlayAt but only fires to a single player. Use for
-- player-personal sounds (purchase confirmations, error tones, etc.).
function SoundManager:PlayForPlayer(player, soundKey, volume)
    local soundId = self.Sounds[soundKey]
    if not soundId then
        warn("[SoundManager] Unknown sound key: " .. tostring(soundKey))
        return
    end
    getRemote():FireClient(player, soundId, nil, volume or 0.5)
end

return SoundManager
