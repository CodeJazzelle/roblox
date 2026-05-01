-- DriveThruTraffic.server.lua
-- Drives the visual+functional drive-thru loop. Cars spawn off-screen,
-- pull up to the order window with a chat-bubble request, advance to the
-- pickup window where they hold a real OrderManager order, and drive off
-- once the player serves the matching drink (or after a 60s timeout).
--
-- Each car holds an orderID that came from OrderManager:SpawnOrder, so
-- the right-side OrderUI queue, the world, and the cars all reference
-- the SAME order. Phase 4 integration: this module is now the source of
-- order spawning — OrderManager's auto-spawn loop has been removed.
--
-- Lane geometry comes from the four DriveThruWaypoint parts placed by
-- BuildStand at z = +50 / +18 / +2 / -50. Edit those positions to
-- reshape the lane; this script reads them at runtime.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OrderManager = require(script.Parent:WaitForChild("OrderManager"))
local DrinkRecipes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DrinkRecipes"))
local SoundManager = require(script.Parent:WaitForChild("SoundManager"))

-- ============================================================
-- Tunables
-- ============================================================
local MAX_CARS_IN_LANE = 3
local MIN_SPAWN_INTERVAL = 10
local MAX_SPAWN_INTERVAL = 18
local PICKUP_TIMEOUT = 60       -- seconds before a waiting car gives up
local ORDER_DWELL = 4           -- seconds spent at the order window
local TWEEN_SPAWN_TO_ORDER  = 4
local TWEEN_ORDER_TO_PICKUP = 2
local TWEEN_PICKUP_TO_EXIT  = 4

local CAR_COLORS = {
    Color3.fromRGB(60, 90, 200),   Color3.fromRGB(220, 50, 50),
    Color3.fromRGB(60, 160, 80),   Color3.fromRGB(255, 200, 50),
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 30),
    Color3.fromRGB(255, 122, 0),   Color3.fromRGB(160, 100, 220),
}

-- ============================================================
-- Waypoints (lazy lookup; parts come from BuildStand)
-- ============================================================
local waypoints = {}
local function loadWaypoints()
    waypoints = {}
    for _, part in ipairs(CollectionService:GetTagged("DriveThruWaypoint")) do
        local kind = part:GetAttribute("WaypointType")
        if kind then waypoints[kind] = part end
    end
end
loadWaypoints()
CollectionService:GetInstanceAddedSignal("DriveThruWaypoint"):Connect(loadWaypoints)

local function waypointCFrame(kind)
    local p = waypoints[kind]
    if not p then return nil end
    -- Cars face -Z (driving north along the lane). Adjust Y by 1.5 so the
    -- car body sits above the marker (which is at y - 1.5 by design).
    return CFrame.new(p.Position.X, p.Position.Y + 1.5, p.Position.Z)
        * CFrame.Angles(0, math.rad(180), 0)
end

-- ============================================================
-- Car building
-- ============================================================
local function makeCar(color)
    local model = Instance.new("Model")
    model.Name = "DTCar"

    local body = Instance.new("Part")
    body.Name = "CarBody"
    body.Size = Vector3.new(4, 2.4, 8)
    body.Color = color
    body.Material = Enum.Material.SmoothPlastic
    body.TopSurface = Enum.SurfaceType.Smooth
    body.BottomSurface = Enum.SurfaceType.Smooth
    body.Anchored = true
    body.Parent = model
    model.PrimaryPart = body

    -- Cabin (slightly smaller, on top)
    local cabin = Instance.new("Part")
    cabin.Name = "CarCabin"
    cabin.Size = Vector3.new(3.6, 1.4, 4.5)
    cabin.Color = color:Lerp(Color3.new(0, 0, 0), 0.2)
    cabin.Material = Enum.Material.SmoothPlastic
    cabin.Anchored = true
    cabin.Parent = model
    cabin.CFrame = body.CFrame * CFrame.new(0, 1.7, -0.5)

    -- Windshield + rear window
    for _, info in ipairs({
        {name = "Windshield", offset = Vector3.new(0, 1.7, 1.6)},
        {name = "RearWindow", offset = Vector3.new(0, 1.7, -2.7)},
    }) do
        local w = Instance.new("Part")
        w.Name = info.name
        w.Size = Vector3.new(3.4, 1.2, 0.2)
        w.Color = Color3.fromRGB(120, 180, 220)
        w.Material = Enum.Material.Glass
        w.Transparency = 0.4
        w.Anchored = true
        w.Parent = model
        w.CFrame = body.CFrame * CFrame.new(info.offset)
    end

    -- Wheels (4)
    for _, off in ipairs({
        Vector3.new(-1.7, -1.2, -2.5), Vector3.new( 1.7, -1.2, -2.5),
        Vector3.new(-1.7, -1.2,  2.5), Vector3.new( 1.7, -1.2,  2.5),
    }) do
        local wheel = Instance.new("Part")
        wheel.Name = "Wheel"
        wheel.Shape = Enum.PartType.Cylinder
        wheel.Size = Vector3.new(1.2, 1.2, 1.2)
        wheel.Color = Color3.fromRGB(20, 20, 20)
        wheel.Material = Enum.Material.SmoothPlastic
        wheel.Anchored = true
        wheel.CanCollide = false
        wheel.Parent = model
        wheel.CFrame = body.CFrame * CFrame.new(off) * CFrame.Angles(0, 0, math.rad(90))
    end

    -- Headlights
    for _, side in ipairs({-1, 1}) do
        local hl = Instance.new("Part")
        hl.Name = "Headlight"
        hl.Size = Vector3.new(0.6, 0.4, 0.2)
        hl.Color = Color3.fromRGB(255, 240, 200)
        hl.Material = Enum.Material.Neon
        hl.Anchored = true
        hl.CanCollide = false
        hl.Parent = model
        hl.CFrame = body.CFrame * CFrame.new(side * 1.4, 0.4, 4)
        local pl = Instance.new("PointLight")
        pl.Color = Color3.fromRGB(255, 240, 200)
        pl.Brightness = 1.5
        pl.Range = 12
        pl.Parent = hl
    end
    -- Brake lights (red, dim until braking)
    for _, side in ipairs({-1, 1}) do
        local bl = Instance.new("Part")
        bl.Name = "BrakeLight"
        bl.Size = Vector3.new(0.6, 0.4, 0.2)
        bl.Color = Color3.fromRGB(120, 30, 30)
        bl.Material = Enum.Material.Neon
        bl.Anchored = true
        bl.CanCollide = false
        bl.Parent = model
        bl.CFrame = body.CFrame * CFrame.new(side * 1.4, 0.4, -4)
    end

    return model
end

-- Brighten brake-light parts to indicate stopping
local function setBrakeLights(model, on)
    for _, part in ipairs(model:GetChildren()) do
        if part.Name == "BrakeLight" then
            part.Color = on and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(120, 30, 30)
        end
    end
end

-- Tween the entire model along a path via CFrameValue + PivotTo
local function tweenCar(model, fromCFrame, toCFrame, duration)
    if not model.PrimaryPart then return end
    local cv = Instance.new("CFrameValue")
    cv.Value = fromCFrame
    local conn = cv:GetPropertyChangedSignal("Value"):Connect(function()
        if model.PrimaryPart then model:PivotTo(cv.Value) end
    end)
    local tween = TweenService:Create(cv, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Value = toCFrame})
    tween:Play()
    tween.Completed:Wait()
    conn:Disconnect()
    cv:Destroy()
end

-- Chat-bubble billboard above the car
local function chatBubble(model, text, duration)
    local body = model.PrimaryPart
    if not body then return end
    local bb = Instance.new("BillboardGui")
    bb.Adornee = body
    bb.Size = UDim2.new(0, 240, 0, 50)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 80
    bb.Parent = body

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BorderSizePixel = 0
    frame.Parent = bb
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, -6)
    label.Position = UDim2.fromOffset(5, 3)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(20, 20, 20)
    label.TextWrapped = true
    label.Parent = frame

    task.delay(duration or 4, function()
        if bb.Parent then bb:Destroy() end
    end)
end

-- ============================================================
-- Lane state — a queue of active cars (oldest first). Only the head of
-- the queue advances into Order/Pickup; followers stack at Spawn.
-- ============================================================
local activeCars = {}   -- ordered list, [1] = head of queue

local function pickRandomDrinkName()
    local ids = DrinkRecipes.GetAllRecipeIDs()
    local pickedId = ids[math.random(1, #ids)]
    local recipe = DrinkRecipes.GetRecipe(pickedId)
    return recipe and recipe.displayName or "something good"
end

-- The order this car carries — the actual OrderManager order. Car waits
-- at Pickup until the order completes (or times out).
local completedOrders = {}  -- orderID -> player who served it
OrderManager.OrderCompleted.Event:Connect(function(orderID, player)
    completedOrders[orderID] = player
end)

local function runCarLifecycle(car, color)
    car.Parent = Workspace

    local spawnCF  = waypointCFrame("Spawn")
    local orderCF  = waypointCFrame("Order")
    local pickupCF = waypointCFrame("Pickup")
    local exitCF   = waypointCFrame("Exit")
    if not (spawnCF and orderCF and pickupCF and exitCF) then
        warn("[DriveThruTraffic] Missing waypoints — destroying car")
        car:Destroy()
        return
    end

    car:PivotTo(spawnCF)

    -- Drive in to the order window
    setBrakeLights(car, false)
    tweenCar(car, spawnCF, orderCF, TWEEN_SPAWN_TO_ORDER)
    setBrakeLights(car, true)

    -- "Ordering" — spawn a real OrderManager order and announce it
    local orderID = OrderManager:SpawnOrder()
    car:SetAttribute("OrderID", orderID or 0)
    if orderID then
        local order = OrderManager.ActiveOrders[orderID]
        local drinkName = (order and order.recipe and order.recipe.displayName) or pickRandomDrinkName()
        chatBubble(car, "I'd like a " .. drinkName .. "!", ORDER_DWELL)
    else
        chatBubble(car, "Hey! Can I get something?", ORDER_DWELL)
    end
    task.wait(ORDER_DWELL)

    -- Move up to the pickup window
    setBrakeLights(car, false)
    tweenCar(car, orderCF, pickupCF, TWEEN_ORDER_TO_PICKUP)
    setBrakeLights(car, true)

    -- Wait for our order to complete, or timeout
    local startedWait = tick()
    local served = false
    while tick() - startedWait < PICKUP_TIMEOUT do
        if orderID and completedOrders[orderID] then
            served = true
            completedOrders[orderID] = nil
            break
        end
        task.wait(0.5)
    end

    if served then
        chatBubble(car, "Thanks bro! 🙌", 3)
        SoundManager:PlayAt("CarHorn", car.PrimaryPart, 0.4)
        task.wait(0.6)
        SoundManager:PlayAt("CarHorn", car.PrimaryPart, 0.4)
    else
        chatBubble(car, "Forget it. 😤", 3)
        -- Fail the dangling order so the queue card disappears
        if orderID and OrderManager.ActiveOrders[orderID] then
            OrderManager:FailOrder(orderID, "Customer left")
        end
    end

    -- Drive away
    setBrakeLights(car, false)
    tweenCar(car, pickupCF, exitCF, TWEEN_PICKUP_TO_EXIT)
    car:Destroy()
end

local function spawnCar()
    if #activeCars >= MAX_CARS_IN_LANE then return end
    if not OrderManager.RoundActive then return end
    local color = CAR_COLORS[math.random(1, #CAR_COLORS)]
    local car = makeCar(color)
    table.insert(activeCars, car)
    task.spawn(function()
        runCarLifecycle(car, color)
        -- Remove from active list when done
        for i, c in ipairs(activeCars) do
            if c == car then
                table.remove(activeCars, i)
                break
            end
        end
    end)
end

-- ============================================================
-- Spawn loop — paced by random interval, gated by lane capacity and
-- whether a round is active.
-- ============================================================
task.spawn(function()
    -- Wait for waypoints to exist (BuildStand runs alongside)
    while not (waypoints.Spawn and waypoints.Order and waypoints.Pickup and waypoints.Exit) do
        task.wait(0.5)
        loadWaypoints()
    end

    while true do
        local interval = math.random(MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL)
        task.wait(interval)
        spawnCar()
    end
end)

print("[DriveThruTraffic] Active — cars will arrive when a round is running.")
