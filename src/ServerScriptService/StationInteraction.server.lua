-- StationInteraction.server.lua
-- Wires up all station ProximityPrompts to modify the cup the player is holding.
-- Listens to CollectionService:GetInstanceAddedSignal as well as initial GetTagged so
-- parts that are spawned later (e.g. by BuildStand at runtime) still get wired up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local CupState = require(ReplicatedStorage.Modules.CupState)
local SoundManager = require(script.Parent:WaitForChild("SoundManager"))

-- Mapping tag → sound key for station SFX. Driver of all "interaction"
-- audio so adding a new station means one entry here.
local STATION_SOUND = {
    CupTower_Small     = "cup_grab",
    CupTower_Medium    = "cup_grab",
    CupTower_Large     = "cup_grab",
    EspressoMachine    = "espresso_pull",
    RebelTap           = "liquid_pour",
    TeaBrewer          = "tea_pour",
    LemonadeDispenser  = "liquid_pour",
    MilkSteamer        = "milk_steam",
    SyrupPump          = "syrup_pump",
    ToppingStation     = "topping_add",
    LidStation         = "lid_click",
    SleeveStation      = "cup_grab",
    TrashCan           = "trash_drop",
}

local PlayerCups = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CupUpdatedEvent = Remotes:WaitForChild("CupUpdated")

local function getOrCreateCup(player, size)
    if not PlayerCups[player] then
        PlayerCups[player] = CupState.new(size or "Medium")
    end
    return PlayerCups[player]
end

local function syncCupToClient(player)
    local cup = PlayerCups[player]
    -- Always fire so the client can show/hide its cup HUD even when cleared.
    CupUpdatedEvent:FireClient(player, cup and cup:Serialize() or nil)
end

local function setupStation(stationPart, action)
    local prompt = stationPart:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.HoldDuration = 0.3
        prompt.MaxActivationDistance = 8
        prompt.Parent = stationPart
    end
    -- Console players see ButtonA glyph; ButtonA auto-triggers in range.
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonA

    prompt.Triggered:Connect(function(player)
        action(player, stationPart)
        syncCupToClient(player)
    end)
end

local function bindTag(tag, action)
    -- Wrap action with a sound trigger so every interaction plays the
    -- station's SFX without each binding having to remember to fire it.
    local soundKey = STATION_SOUND[tag]
    local wrapped = action
    if soundKey then
        wrapped = function(player, part)
            action(player, part)
            -- Per-player sound (FireClient) so each player only hears their
            -- own interactions, not everyone else's. 3D-positioned via the
            -- station's part so audio fades with distance.
            if part and part:IsA("BasePart") then
                SoundManager:PlayForPlayer(player, soundKey, part, 0.5)
            else
                SoundManager:PlayForPlayer(player, soundKey, nil, 0.5)
            end
        end
    end
    for _, part in ipairs(CollectionService:GetTagged(tag)) do
        setupStation(part, wrapped)
    end
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
        setupStation(part, wrapped)
    end)
end

bindTag("CupTower_Small",  function(player) PlayerCups[player] = CupState.new("Small")  end)
bindTag("CupTower_Medium", function(player) PlayerCups[player] = CupState.new("Medium") end)
bindTag("CupTower_Large",  function(player) PlayerCups[player] = CupState.new("Large")  end)

local baseStations = {
    EspressoMachine    = "Espresso",
    RebelTap           = "Blue Rebel",
    TeaBrewer          = "Tea",
    LemonadeDispenser  = "Lemonade",
    MilkSteamer        = "Milk",
}
for tag, baseName in pairs(baseStations) do
    bindTag(tag, function(player)
        local cup = getOrCreateCup(player)
        cup:SetBase(baseName)
    end)
end

bindTag("SyrupPump", function(player, part)
    local syrupName = part:GetAttribute("SyrupName")
    if not syrupName then return end
    local cup = getOrCreateCup(player)
    cup:AddSyrup(syrupName)
end)

bindTag("ToppingStation", function(player, part)
    local toppingName = part:GetAttribute("ToppingName")
    if not toppingName then return end
    local cup = getOrCreateCup(player)
    cup:AddTopping(toppingName)
end)

bindTag("LidStation", function(player)
    local cup = getOrCreateCup(player)
    cup:ApplyLid()
end)

bindTag("SleeveStation", function(player)
    local cup = getOrCreateCup(player)
    cup:ApplySleeve()
end)

bindTag("TrashCan", function(player)
    PlayerCups[player] = nil
end)

-- Drive-thru hand-off lives in HandoffWindow.server.lua (it talks to
-- OrderManager directly and uses _G.GetPlayerCup / _G.ClearPlayerCup).

_G.GetPlayerCup = function(player) return PlayerCups[player] end
_G.ClearPlayerCup = function(player)
    PlayerCups[player] = nil
    syncCupToClient(player)
end

Players.PlayerRemoving:Connect(function(player)
    PlayerCups[player] = nil
end)
