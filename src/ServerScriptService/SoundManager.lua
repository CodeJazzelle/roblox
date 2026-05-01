-- SoundManager.lua (ModuleScript)
-- Centralized server-side sound dispatcher. Other server modules call
-- SoundManager:PlayForPlayer(player, soundKey, partOrNil, volume) to play
-- a per-player sound (preferred for station feedback) or
-- SoundManager:PlayAt(soundKey, partOrNil, volume) to broadcast to every
-- client (used for round-wide events like the start whistle).
--
-- Asset IDs are user-provided; some may be invalid or unloadable. The
-- client-side SoundPlayer wraps both Sound construction and :Play() in
-- pcall and prints a warning if anything fails — the game does not crash
-- on a bad asset.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundManager = {}

-- Sound library — keys are stable snake_case names used by callers; values
-- are the asset IDs to actually play. Edit values here to swap individual
-- sounds without touching call sites. The fallback ID rbxassetid://6042583773
-- (UI confirm) is used by SoundPlayer when an asset fails to load, so any
-- sound at least makes a click noise rather than silence.
SoundManager.Sounds = {
    -- Stations
    cup_grab           = "rbxassetid://9116402097",
    espresso_pull      = "rbxassetid://3742023110",
    liquid_pour        = "rbxassetid://9120476375",
    tea_pour           = "rbxassetid://9120476375",
    milk_steam         = "rbxassetid://9120476375",
    syrup_pump         = "rbxassetid://9119305266",
    topping_add        = "rbxassetid://9119305266",
    lid_click          = "rbxassetid://3744373440",
    trash_drop         = "rbxassetid://9112861971",

    -- Hand-off
    cash_register_ding = "rbxassetid://3120909354",
    wrong_drink_buzz   = "rbxassetid://3744371091",
    tip_earned         = "rbxassetid://3120909355",

    -- Round / gameplay
    round_start        = "rbxassetid://138081500",   -- whistle (9117990702 was 403)
    round_end          = "rbxassetid://3744371091",
    combo_increase     = "rbxassetid://3120909354",
    combo_break        = "rbxassetid://9117997078",

    -- UI
    button_click       = "rbxassetid://6042583773",
    menu_open          = "rbxassetid://4612375233",
    purchase_success   = "rbxassetid://3120909354",

    -- Ambient / drive-thru
    background_music   = "rbxassetid://1837935739",
    outdoor_ambience   = "rbxassetid://9120476375",
    car_horn           = "rbxassetid://9114046921",
    car_arrive         = "rbxassetid://3120909354",
}

local PlaySoundEvent  -- assigned lazily so the module doesn't yield on require

local function getRemote()
    if PlaySoundEvent then return PlaySoundEvent end
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    PlaySoundEvent = remotes:WaitForChild("PlaySound")
    return PlaySoundEvent
end

-- Play a sound to ALL players. Use for round-wide events.
-- `targetOrNil` can be a BasePart (3D audio) or nil (2D, parented to
-- SoundService client-side).
function SoundManager:PlayAt(soundKey, targetOrNil, volume)
    local soundId = self.Sounds[soundKey]
    if not soundId then
        warn("[SoundManager] Unknown sound key: " .. tostring(soundKey))
        return
    end
    getRemote():FireAllClients(soundId, targetOrNil, volume or 0.5)
end

-- Play a sound to a single player only — used for station feedback so each
-- player only hears their own interactions. Logs to Output every time it
-- fires so we can verify sounds are being triggered even if a specific
-- asset fails to load on the client.
function SoundManager:PlayForPlayer(player, soundKey, targetOrNil, volume)
    if not player then return end
    local soundId = self.Sounds[soundKey]
    if not soundId then
        warn("[SoundManager] Unknown sound key: " .. tostring(soundKey))
        return
    end
    getRemote():FireClient(player, soundId, targetOrNil, volume or 0.5)
    print(("[SoundPlayer] Played %s for %s"):format(soundKey, player.Name))
end

return SoundManager
