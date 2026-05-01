-- BuildStand.server.lua
-- Procedurally constructs the Dutch Bros stand: 90 studs wide × 40 deep ×
-- 16 tall, fully open front, single horizontal row of 12 syrup pumps along
-- the back wall, full left-to-right station workflow.
--
-- Coordinate convention:
--   * Floor TOP surface is at Y = 0 (the player walks on Y = 0).
--   * The floor PART is centered at Y = -0.5 with size 1, so it spans Y in
--     [-1, 0]. This is the convention every other Y value in this file
--     assumes.
--   * Walls run from Y = 0 (their bottom) to Y = BLD_H = 16 (their top).
--   * Roof bottom is at Y = 16, top at Y = 17.
--   * Counter top is at Y = 3 (waist height). Stations sit on top of it.
--
-- Self-destructs at the end. Tags every interactive part so
-- StationInteraction.server.lua and HandoffWindow.server.lua wire it up
-- via CollectionService:GetInstanceAddedSignal.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

-- ============================================================
-- Palette
-- ============================================================
local DUTCH_BLUE      = Color3.fromRGB(0,   90,  171)
local DARK_BLUE       = Color3.fromRGB(35,  70,  130)
local DUTCH_ORANGE    = Color3.fromRGB(255, 122,  0)
local DUTCH_YELLOW    = Color3.fromRGB(255, 200, 50)
local METAL_BLUEGRAY  = Color3.fromRGB(120, 135, 155)
local STONE_GRAY      = Color3.fromRGB(80,  80,  90)
local ASPHALT         = Color3.fromRGB(45,  45,  50)
local SIDEWALK        = Color3.fromRGB(180, 180, 180)
local GRASS           = Color3.fromRGB(80,  130, 60)
local CURB            = Color3.fromRGB(220, 220, 220)
local FLOOR_KITCHEN   = Color3.fromRGB(45,  50,  55)
local CHALK_GREEN     = Color3.fromRGB(25,  35,  25)
local WHITE           = Color3.new(1, 1, 1)
local BLACK           = Color3.fromRGB(20, 20, 20)
local CREAM           = Color3.fromRGB(255, 244, 222)
local ACCENT_PINK     = Color3.fromRGB(255, 100, 180)
local ACCENT_GREEN    = Color3.fromRGB(80,  180, 100)
local ACCENT_RED      = Color3.fromRGB(200, 60,  60)
local ACCENT_GRAY     = Color3.fromRGB(110, 110, 120)

-- ============================================================
-- Geometry
-- ============================================================
local BLD_W       = 90
local BLD_D       = 40
local BLD_H       = 16
local FLOOR_TOP   = 0          -- top surface of the floor (player walks here)
local FLOOR_PART_Y = -0.5      -- floor part's center Y (1-stud-thick floor)
local WALL_THICK  = 1
local COUNTER_TOP_Y = FLOOR_TOP + 3   -- counter top surface = 3
local COUNTER_Z       = -BLD_D/2 + 4  -- counter center
local COUNTER_FRONT_Z = -BLD_D/2 + 5  -- front face of counter

print(("[BuildStand] Starting build (BLD_W=%d, BLD_D=%d, BLD_H=%d)"):format(BLD_W, BLD_D, BLD_H))

-- ============================================================
-- Cleanup any prior build (and any default Roblox spawn)
-- ============================================================
do
    local existing = Workspace:FindFirstChild("DutchBrosStand")
    if existing then existing:Destroy() end
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("SpawnLocation") then child:Destroy() end
    end
end

local stand = Instance.new("Model")
stand.Name = "DutchBrosStand"
stand.Parent = Workspace

-- ============================================================
-- Helpers
-- ============================================================
local function mkPart(props)
    local p = Instance.new("Part")
    p.Anchored = props.Anchored ~= false
    p.CanCollide = props.CanCollide ~= false
    p.Material = props.Material or Enum.Material.SmoothPlastic
    p.Color = props.Color or WHITE
    p.Size = props.Size or Vector3.new(2, 2, 2)
    p.CFrame = props.CFrame or CFrame.new()
    p.Name = props.Name or "Part"
    p.Transparency = props.Transparency or 0
    if props.Shape then p.Shape = props.Shape end
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = props.Parent or stand
    if props.Tags then
        for _, t in ipairs(props.Tags) do
            CollectionService:AddTag(p, t)
        end
    end
    if props.Attributes then
        for k, v in pairs(props.Attributes) do
            p:SetAttribute(k, v)
        end
    end
    return p
end

local function addLabel(part, title, subtitle, accentColor)
    local bb = Instance.new("BillboardGui")
    bb.Name = "StationLabel"
    bb.Adornee = part
    bb.Size = UDim2.new(0, 240, 0, 76)
    bb.StudsOffset = Vector3.new(0, 4.5, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 100
    bb.Parent = part

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = BLACK
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = bb
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 6)
    accent.BackgroundColor3 = accentColor or DUTCH_BLUE
    accent.BorderSizePixel = 0
    accent.Parent = frame
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(0, 12)
    accentCorner.Parent = accent

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -16, 0, 28)
    titleLbl.Position = UDim2.fromOffset(8, 12)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 22
    titleLbl.TextColor3 = WHITE
    titleLbl.TextStrokeTransparency = 0.4
    titleLbl.TextStrokeColor3 = BLACK
    titleLbl.Parent = frame

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -16, 0, 22)
    subLbl.Position = UDim2.fromOffset(8, 42)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = subtitle
    subLbl.Font = Enum.Font.GothamSemibold
    subLbl.TextSize = 15
    subLbl.TextColor3 = DUTCH_YELLOW
    subLbl.Parent = frame
end

local RAINBOW_STRIPE = {
    Color3.fromRGB(220, 60, 60),
    Color3.fromRGB(255, 200, 50),
    Color3.fromRGB(255, 122, 0),
    Color3.fromRGB(0,  90,  171),
}
local function addStripeBand(name, cframe, width, axis)
    local stripeH = 0.35
    for i, c in ipairs(RAINBOW_STRIPE) do
        local size
        if axis == "Z" then
            size = Vector3.new(0.3, stripeH, width)
        else
            size = Vector3.new(width, stripeH, 0.3)
        end
        mkPart({
            Name = name .. "_" .. i,
            Size = size,
            CFrame = cframe * CFrame.new(0, -(i - 0.5) * stripeH, 0),
            Color = c,
            Material = Enum.Material.SmoothPlastic,
        })
    end
end

local function addSurfaceText(part, face, text, font, textColor, bgColor, bgTransparency)
    local sg = Instance.new("SurfaceGui")
    sg.Face = face
    sg.LightInfluence = 0
    sg.PixelsPerStud = 50
    sg.Parent = part
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundColor3 = bgColor or BLACK
    lbl.BackgroundTransparency = bgTransparency or 0
    lbl.Text = text
    lbl.Font = font or Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.TextColor3 = textColor or WHITE
    lbl.Parent = sg
    return lbl
end

-- Reuses the prompt that StationInteraction's bindTag has already attached
-- (its Triggered handler is already bound — we just want to set the text).
-- Creates one if absent (covers parts that aren't tagged, e.g. HandoffWindow).
-- Sets GamepadKeyCode = ButtonA so console players see the correct glyph
-- and the prompt auto-triggers on ButtonA when in range.
local function addPrompt(part, objectText, actionText, distance)
    local prompt = part:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.HoldDuration = 0.3
        prompt.RequiresLineOfSight = false
        prompt.Parent = part
    end
    prompt.MaxActivationDistance = distance or 8
    prompt.ObjectText = objectText
    prompt.ActionText = actionText
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonA
    return prompt
end

-- ============================================================
-- Asphalt parking lot + grass + sidewalk + parking stripes
-- ============================================================
mkPart({
    Name = "ParkingLot",
    Size = Vector3.new(180, 1, 140),
    CFrame = CFrame.new(0, FLOOR_PART_Y, 0),
    Color = ASPHALT,
    Material = Enum.Material.Asphalt,
})
mkPart({
    Name = "GrassStrip",
    Size = Vector3.new(8, 0.6, 140),
    CFrame = CFrame.new(-92, FLOOR_TOP - 0.2, 0),
    Color = GRASS,
    Material = Enum.Material.Grass,
})
mkPart({
    Name = "Curb",
    Size = Vector3.new(0.6, 0.8, 140),
    CFrame = CFrame.new(-88, FLOOR_TOP, 0),
    Color = CURB,
    Material = Enum.Material.Concrete,
})
mkPart({
    Name = "Sidewalk",
    Size = Vector3.new(BLD_W + 10, 0.4, 6),
    CFrame = CFrame.new(0, FLOOR_TOP - 0.05, BLD_D/2 + 4),
    Color = SIDEWALK,
    Material = Enum.Material.Concrete,
})
do
    local startX = -36
    local spacing = 9
    for i = 0, 6 do
        mkPart({
            Name = "ParkingLine_" .. i,
            Size = Vector3.new(0.3, 0.05, 12),
            CFrame = CFrame.new(startX + i * spacing, FLOOR_TOP + 0.05, BLD_D/2 + 14),
            Color = WHITE,
            Material = Enum.Material.SmoothPlastic,
            CanCollide = false,
        })
    end
end
print("[BuildStand] Parking lot + grass + sidewalk built")

-- ============================================================
-- Drive-thru lane along east side
-- ============================================================
do
    local laneX = BLD_W/2 + 8   -- 8 studs east of right wall (53)
    mkPart({
        Name = "DriveThruLane",
        Size = Vector3.new(10, 0.06, 90),
        CFrame = CFrame.new(laneX, FLOOR_TOP + 0.03, 0),
        Color = Color3.fromRGB(35, 35, 40),
        Material = Enum.Material.Asphalt,
        CanCollide = false,
    })
    for i = -6, 6 do
        mkPart({
            Name = "LaneDash_" .. i,
            Size = Vector3.new(0.3, 0.06, 3),
            CFrame = CFrame.new(laneX, FLOOR_TOP + 0.07, i * 7),
            Color = DUTCH_YELLOW,
            Material = Enum.Material.SmoothPlastic,
            CanCollide = false,
        })
    end
    mkPart({
        Name = "LaneEdgeLeft",
        Size = Vector3.new(0.25, 0.06, 90),
        CFrame = CFrame.new(laneX - 4.8, FLOOR_TOP + 0.07, 0),
        Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false,
    })
    mkPart({
        Name = "LaneEdgeRight",
        Size = Vector3.new(0.25, 0.06, 90),
        CFrame = CFrame.new(laneX + 4.8, FLOOR_TOP + 0.07, 0),
        Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false,
    })
end
print("[BuildStand] Drive-thru lane built")

-- ============================================================
-- 3 simple box cars (5 parts each: body + 4 wheels)
-- ============================================================
local function buildSimpleCar(x, z, bodyColor)
    mkPart({
        Name = "CarBody",
        Size = Vector3.new(4, 2.4, 8),
        CFrame = CFrame.new(x, FLOOR_TOP + 1.4, z),
        Color = bodyColor,
        Material = Enum.Material.SmoothPlastic,
    })
    for _, w in ipairs({
        {x - 1.7, FLOOR_TOP + 0.6, z - 2.5},
        {x + 1.7, FLOOR_TOP + 0.6, z - 2.5},
        {x - 1.7, FLOOR_TOP + 0.6, z + 2.5},
        {x + 1.7, FLOOR_TOP + 0.6, z + 2.5},
    }) do
        mkPart({
            Name = "CarWheel",
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(1.2, 1.2, 1.2),
            CFrame = CFrame.new(w[1], w[2], w[3]) * CFrame.Angles(0, 0, math.rad(90)),
            Color = BLACK,
            Material = Enum.Material.SmoothPlastic,
        })
    end
end
-- Drive-thru waypoint markers (invisible parts tagged for DriveThruTraffic).
-- Cars drive south-to-north along x = BLD_W/2 + 8 = +53.
do
    local LANE_X = BLD_W/2 + 8
    local LANE_Y = FLOOR_TOP + 1.4   -- car body center height
    local function waypoint(name, z, kind)
        local p = mkPart({
            Name = name,
            Size = Vector3.new(2, 0.2, 2),
            CFrame = CFrame.new(LANE_X, LANE_Y - 1.5, z),
            Color = DUTCH_ORANGE, Material = Enum.Material.Neon,
            CanCollide = false, Transparency = 1,
            Tags = {"DriveThruWaypoint"},
            Attributes = {WaypointType = kind, LaneX = LANE_X, LaneY = LANE_Y},
        })
        return p
    end
    waypoint("DTSpawn",  50, "Spawn")
    waypoint("DTOrder",  18, "Order")
    waypoint("DTPickup",  2, "Pickup")
    waypoint("DTExit",  -50, "Exit")
end
print("[BuildStand] Drive-thru waypoints placed (Spawn / Order / Pickup / Exit)")

-- ============================================================
-- Building floor (top surface at Y=0)
-- ============================================================
mkPart({
    Name = "InteriorFloor",
    Size = Vector3.new(BLD_W, 1, BLD_D),
    CFrame = CFrame.new(0, FLOOR_PART_Y, 0),
    Color = FLOOR_KITCHEN,
    Material = Enum.Material.SmoothPlastic,
})
print("[BuildStand] Floor built")

-- ============================================================
-- Walls — back, left, right (with drive-thru cutout). FRONT IS OPEN.
-- ============================================================
mkPart({
    Name = "BackWall",
    Size = Vector3.new(BLD_W, BLD_H, WALL_THICK),
    CFrame = CFrame.new(0, FLOOR_TOP + BLD_H/2, -BLD_D/2 + WALL_THICK/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.DiamondPlate,
})
mkPart({
    Name = "LeftWall",
    Size = Vector3.new(WALL_THICK, BLD_H, BLD_D),
    CFrame = CFrame.new(-BLD_W/2 + WALL_THICK/2, FLOOR_TOP + BLD_H/2, 0),
    Color = METAL_BLUEGRAY, Material = Enum.Material.DiamondPlate,
})

-- Right wall: drive-thru window cutout at z ∈ [-3, 7], y ∈ [3, 8]
local RIGHT_X = BLD_W/2 - WALL_THICK/2
local DTW_Z1, DTW_Z2 = -3, 7
local DTW_Y1, DTW_Y2 = 3, 8
mkPart({
    Name = "RightWallBackSeg",
    Size = Vector3.new(WALL_THICK, BLD_H, DTW_Z1 - (-BLD_D/2)),
    CFrame = CFrame.new(RIGHT_X, FLOOR_TOP + BLD_H/2, ((-BLD_D/2) + DTW_Z1)/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.DiamondPlate,
})
mkPart({
    Name = "RightWallFrontSeg",
    Size = Vector3.new(WALL_THICK, BLD_H, (BLD_D/2) - DTW_Z2),
    CFrame = CFrame.new(RIGHT_X, FLOOR_TOP + BLD_H/2, (DTW_Z2 + (BLD_D/2))/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.DiamondPlate,
})
mkPart({
    Name = "RightWallAboveDTW",
    Size = Vector3.new(WALL_THICK, BLD_H - DTW_Y2, DTW_Z2 - DTW_Z1),
    CFrame = CFrame.new(RIGHT_X, FLOOR_TOP + DTW_Y2 + (BLD_H - DTW_Y2)/2, (DTW_Z1 + DTW_Z2)/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.DiamondPlate,
})
mkPart({
    Name = "RightWallBelowDTW",
    Size = Vector3.new(WALL_THICK, DTW_Y1, DTW_Z2 - DTW_Z1),
    CFrame = CFrame.new(RIGHT_X, FLOOR_TOP + DTW_Y1/2, (DTW_Z1 + DTW_Z2)/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.DiamondPlate,
})
print("[BuildStand] Walls built (back, left, right; FRONT OPEN)")

-- ============================================================
-- Blue accent tower on front-left
-- ============================================================
do
    mkPart({
        Name = "BlueAccentTowerFront",
        Size = Vector3.new(5, BLD_H + 5, 0.4),
        CFrame = CFrame.new(-BLD_W/2 + 2.5, FLOOR_TOP + (BLD_H + 5)/2, BLD_D/2 + 0.3),
        Color = DARK_BLUE, Material = Enum.Material.DiamondPlate,
    })
    mkPart({
        Name = "BlueAccentTowerSide",
        Size = Vector3.new(0.4, BLD_H + 5, 5),
        CFrame = CFrame.new(-BLD_W/2 - 0.3, FLOOR_TOP + (BLD_H + 5)/2, BLD_D/2 - 2),
        Color = DARK_BLUE, Material = Enum.Material.DiamondPlate,
    })
    mkPart({
        Name = "BlueAccentTowerCap",
        Size = Vector3.new(5.4, 0.4, 5.4),
        CFrame = CFrame.new(-BLD_W/2 + 2.3, FLOOR_TOP + BLD_H + 5, BLD_D/2 - 2),
        Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Slate,
    })
end

-- ============================================================
-- Roof + fascia
-- ============================================================
mkPart({
    Name = "Roof",
    Size = Vector3.new(BLD_W + 2, 1, BLD_D + 2),
    CFrame = CFrame.new(0, FLOOR_TOP + BLD_H + 0.5, 0),
    Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Slate,
})
for _, fascia in ipairs({
    {n = "FasciaFront", size = Vector3.new(BLD_W + 2, 0.8, 0.4), pos = Vector3.new(0, FLOOR_TOP + BLD_H + 0.6, BLD_D/2 + 1)},
    {n = "FasciaBack",  size = Vector3.new(BLD_W + 2, 0.8, 0.4), pos = Vector3.new(0, FLOOR_TOP + BLD_H + 0.6, -BLD_D/2 - 1)},
    {n = "FasciaLeft",  size = Vector3.new(0.4, 0.8, BLD_D + 2), pos = Vector3.new(-BLD_W/2 - 1, FLOOR_TOP + BLD_H + 0.6, 0)},
    {n = "FasciaRight", size = Vector3.new(0.4, 0.8, BLD_D + 2), pos = Vector3.new(BLD_W/2 + 1, FLOOR_TOP + BLD_H + 0.6, 0)},
}) do
    mkPart({
        Name = fascia.n, Size = fascia.size,
        CFrame = CFrame.new(fascia.pos),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
end
-- Thin top fascia beam at the very top of the front face — gives the
-- DUTCH BROS sign and rainbow stripe something to attach to without
-- closing off the front view.
mkPart({
    Name = "FrontTopFascia",
    Size = Vector3.new(BLD_W, 1, 0.4),
    CFrame = CFrame.new(0, FLOOR_TOP + BLD_H - 0.5, BLD_D/2 + 0.5),
    Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
})
print("[BuildStand] Roof + fascia built")

-- ============================================================
-- Stone pillars + awnings + string lights
-- ============================================================
local function pillar(x, z, height, name)
    mkPart({
        Name = name or "StonePillar",
        Size = Vector3.new(2.5, height, 2.5),
        CFrame = CFrame.new(x, FLOOR_TOP + height/2, z),
        Color = STONE_GRAY, Material = Enum.Material.Slate,
    })
end
pillar(-BLD_W/2 - 1, BLD_D/2 + 1, BLD_H + 1, "FrontLeftPillar")
pillar( BLD_W/2 + 1, BLD_D/2 + 1, BLD_H + 1, "FrontRightPillar")
pillar( BLD_W/2 + 8,  9, BLD_H - 4, "AwningPillarFront")
pillar( BLD_W/2 + 8, -3, BLD_H - 4, "AwningPillarBack")

-- Front awning across the entrance
do
    local awningY = FLOOR_TOP + BLD_H - 7
    mkPart({
        Name = "FrontAwning",
        Size = Vector3.new(BLD_W + 4, 0.6, 5),
        CFrame = CFrame.new(0, awningY, BLD_D/2 + 2),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
    pillar(-22, BLD_D/2 + 4, BLD_H - 7, "FrontAwningPillar_L")
    pillar( 22, BLD_D/2 + 4, BLD_H - 7, "FrontAwningPillar_R")
end

-- Drive-thru awning
do
    local awningY = FLOOR_TOP + BLD_H - 4
    mkPart({
        Name = "DriveThruAwning",
        Size = Vector3.new(10, 0.6, 14),
        CFrame = CFrame.new(BLD_W/2 + 4, awningY, 3),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
    for i = 1, 6 do
        mkPart({
            Name = "AwningStripe_" .. i,
            Size = Vector3.new(10, 0.05, 2),
            CFrame = CFrame.new(BLD_W/2 + 4, awningY - 0.4, 3 - 7 + (i - 0.5) * (14/6)),
            Color = (i % 2 == 0) and DUTCH_ORANGE or WHITE,
            Material = Enum.Material.SmoothPlastic, CanCollide = false,
        })
    end
end

-- String lights above the awning
do
    local lightY = FLOOR_TOP + BLD_H - 3
    for i = 1, 8 do
        local lp = mkPart({
            Name = "StringLight_" .. i,
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(0.6, 0.6, 0.6),
            CFrame = CFrame.new(BLD_W/2 + 1 + i, lightY, 10),
            Color = DUTCH_YELLOW, Material = Enum.Material.Neon, CanCollide = false,
        })
        local pl = Instance.new("PointLight")
        pl.Color = DUTCH_YELLOW; pl.Brightness = 1.5; pl.Range = 8
        pl.Parent = lp
    end
    mkPart({
        Name = "StringLightWire",
        Size = Vector3.new(9, 0.05, 0.05),
        CFrame = CFrame.new(BLD_W/2 + 5, lightY + 0.4, 10),
        Color = BLACK, Material = Enum.Material.SmoothPlastic, CanCollide = false,
    })
end
print("[BuildStand] Pillars + awnings + string lights built")

-- ============================================================
-- Front sign + side sign + welcome banner + EXIT ONLY
-- ============================================================
do
    local sign = mkPart({
        Name = "FrontDutchBrosSign",
        Size = Vector3.new(28, 5, 0.4),
        CFrame = CFrame.new(8, FLOOR_TOP + BLD_H - 3, BLD_D/2 + 0.5),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "DUTCH BROS Coffee", Enum.Font.GothamBlack, DUTCH_YELLOW, DUTCH_BLUE)
    addStripeBand("FrontSignStripe", CFrame.new(8, FLOOR_TOP + BLD_H - 6, BLD_D/2 + 0.6), 28, "X")
    local spotPart = mkPart({
        Name = "FrontSignSpotlight",
        Size = Vector3.new(0.4, 0.4, 0.4),
        CFrame = CFrame.new(8, FLOOR_TOP + BLD_H + 2, BLD_D/2 + 5),
        Transparency = 1, CanCollide = false,
    })
    local spot = Instance.new("SpotLight")
    spot.Color = WHITE; spot.Brightness = 5; spot.Range = 24
    spot.Angle = 90; spot.Face = Enum.NormalId.Bottom
    spot.Parent = spotPart
end
do
    local sign = mkPart({
        Name = "SideDutchBrosSign",
        Size = Vector3.new(0.4, 4, 18),
        CFrame = CFrame.new(BLD_W/2 + 0.5, FLOOR_TOP + BLD_H - 3, -3),
        Color = WHITE, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Right, "DUTCH BROS Coffee", Enum.Font.GothamBlack, DUTCH_BLUE, WHITE)
    addStripeBand("SideSignStripe", CFrame.new(BLD_W/2 + 0.6, FLOOR_TOP + BLD_H - 5.5, -3), 18, "Z")
end
do
    local welcomeBand = mkPart({
        Name = "WalkUpWelcome",
        Size = Vector3.new(12, 1.4, 0.2),
        CFrame = CFrame.new(-22, FLOOR_TOP + BLD_H - 8, BLD_D/2 + 0.6),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(welcomeBand, Enum.NormalId.Front, "WELCOME BACK BESTIE", Enum.Font.GothamBlack, DUTCH_YELLOW, DUTCH_BLUE)
end
do
    mkPart({
        Name = "ExitOnlyPost",
        Size = Vector3.new(0.4, 6, 0.4),
        CFrame = CFrame.new(BLD_W/2 + 4, FLOOR_TOP + 3, -BLD_D/2 - 4),
        Color = STONE_GRAY, Material = Enum.Material.Metal,
    })
    local sign = mkPart({
        Name = "ExitOnlySign",
        Size = Vector3.new(4, 2, 0.2),
        CFrame = CFrame.new(BLD_W/2 + 4, FLOOR_TOP + 5, -BLD_D/2 - 4),
        Color = ACCENT_RED, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "EXIT ONLY", Enum.Font.GothamBlack, WHITE, ACCENT_RED)
    addSurfaceText(sign, Enum.NormalId.Back,  "EXIT ONLY", Enum.Font.GothamBlack, WHITE, ACCENT_RED)
end
print("[BuildStand] Signs + stripes + welcome banner + exit sign built")

-- ============================================================
-- Drive-thru hand-off counter (interior side, tagged HandoffWindow)
-- ============================================================
do
    local handoff = mkPart({
        Name = "DriveThruHandoff",
        Size = Vector3.new(2.5, 3, DTW_Z2 - DTW_Z1),
        CFrame = CFrame.new(BLD_W/2 - 1.5, FLOOR_TOP + 1.5, (DTW_Z1 + DTW_Z2)/2),
        Color = CREAM, Material = Enum.Material.Marble,
        Tags = {"HandoffWindow"},
    })
    addLabel(handoff, "HAND-OFF WINDOW", "Press E to serve order", DUTCH_ORANGE)
    addPrompt(handoff, "Drive-Thru Window", "Hand Off")
    addSurfaceText(handoff, Enum.NormalId.Top, "→ HAND OFF HERE →", Enum.Font.GothamBlack, WHITE, DUTCH_ORANGE)
    -- big floor arrow pointing to the handoff
    local arrow = mkPart({
        Name = "HandoffFloorArrow",
        Size = Vector3.new(8, 0.06, 2.5),
        CFrame = CFrame.new(BLD_W/2 - 8, FLOOR_TOP + 0.04, 2),
        Color = DUTCH_ORANGE, Material = Enum.Material.Neon,
        CanCollide = false,
    })
    addSurfaceText(arrow, Enum.NormalId.Top, "→ HAND OFF →", Enum.Font.GothamBlack, BLACK, DUTCH_ORANGE)
end
print("[BuildStand] Hand-off counter built")

-- ============================================================
-- Back counter — split for the syrup-wall section. Cups + bases on
-- the left counter, toppings + lid on the right counter, syrup wall
-- against the bare back wall in the middle.
-- ============================================================
local LEFT_COUNTER_X1, LEFT_COUNTER_X2 = -43, -18    -- hosts cups + bases
local RIGHT_COUNTER_X1, RIGHT_COUNTER_X2 = 18, 31    -- hosts toppings + lid
local function backCounterSegment(name, x1, x2)
    local w = x2 - x1
    local cx = (x1 + x2)/2
    mkPart({
        Name = name .. "Body",
        Size = Vector3.new(w, 3, 3),
        CFrame = CFrame.new(cx, FLOOR_TOP + 1.5, COUNTER_Z),
        Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.Wood,
    })
    mkPart({
        Name = name .. "Top",
        Size = Vector3.new(w + 0.2, 0.2, 3.4),
        CFrame = CFrame.new(cx, COUNTER_TOP_Y, COUNTER_Z),
        Color = CREAM, Material = Enum.Material.Marble,
    })
end
backCounterSegment("LeftBackCounter",  LEFT_COUNTER_X1,  LEFT_COUNTER_X2)
backCounterSegment("RightBackCounter", RIGHT_COUNTER_X1, RIGHT_COUNTER_X2)
print("[BuildStand] Back counter built (split: left + right, syrup gap in middle)")

-- ============================================================
-- CUP TOWERS (3 cylinders, X = -41 / -38 / -35)
-- ============================================================
local function cupTower(x, sizeName, height, tag)
    local cyl = mkPart({
        Name = "CupTower" .. sizeName,
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(height, 2.4, 2.4),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + height/2, COUNTER_Z) * CFrame.Angles(0, 0, math.rad(90)),
        Color = WHITE, Material = Enum.Material.Plastic,
        Tags = {tag},
    })
    addLabel(cyl, "CUPS - " .. sizeName:upper(), "Press E to grab cup", DUTCH_BLUE)
    addPrompt(cyl, sizeName .. " Cup Tower", "Grab " .. sizeName .. " Cup")
    local sign = mkPart({
        Name = "CupTowerSign_" .. sizeName,
        Size = Vector3.new(2, 0.8, 0.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 0.5, COUNTER_FRONT_Z + 1.5),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, sizeName:upper() .. " CUPS", Enum.Font.GothamBlack, WHITE, DUTCH_BLUE)
    return cyl
end
cupTower(-41, "Small",  4, "CupTower_Small")
cupTower(-38, "Medium", 5, "CupTower_Medium")
cupTower(-35, "Large",  6, "CupTower_Large")
print("[BuildStand] Cup towers built (3)")

-- ============================================================
-- BASE MACHINES (5, 3-stud spacing): Espresso/Rebel/Tea/Lemonade/Milk
-- X = -31 / -28 / -25 / -22 / -19
-- ============================================================
do
    local x = -31
    local base = mkPart({
        Name = "EspressoMachine",
        Size = Vector3.new(3, 2, 2.5),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 1, COUNTER_Z),
        Color = Color3.fromRGB(50, 50, 58), Material = Enum.Material.Metal,
        Tags = {"EspressoMachine"},
    })
    mkPart({
        Name = "EspressoMachineTop",
        Size = Vector3.new(2, 1.3, 2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 2.65, COUNTER_Z),
        Color = Color3.fromRGB(35, 35, 40), Material = Enum.Material.Metal,
    })
    mkPart({
        Name = "EspressoHandle",
        Size = Vector3.new(0.4, 0.4, 1.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 1, COUNTER_Z + 1.8),
        Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood,
    })
    addLabel(base, "ESPRESSO MACHINE", "Press E to pull shots", DUTCH_BLUE)
    addPrompt(base, "Espresso Machine", "Pull Shots")
    addSurfaceText(base, Enum.NormalId.Front, "ESPRESSO", Enum.Font.GothamBlack, DUTCH_YELLOW, Color3.fromRGB(50, 50, 58))
end
do
    local x = -28
    local tap = mkPart({
        Name = "RebelTap",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(4, 1.4, 1.4),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 2, COUNTER_Z) * CFrame.Angles(0, 0, math.rad(90)),
        Color = Color3.fromRGB(0, 130, 220), Material = Enum.Material.Neon,
        Tags = {"RebelTap"},
    })
    mkPart({
        Name = "RebelTapSpout",
        Size = Vector3.new(0.3, 0.8, 1),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 0.6, COUNTER_Z + 1.2),
        Color = Color3.fromRGB(180, 180, 200), Material = Enum.Material.Metal,
    })
    addLabel(tap, "BLUE REBEL TAP", "Press E to fill cup", DUTCH_BLUE)
    addPrompt(tap, "Blue Rebel Tap", "Fill Cup")
    local sign = mkPart({
        Name = "RebelTapSign",
        Size = Vector3.new(2.2, 0.6, 0.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 0.2, COUNTER_FRONT_Z + 1.5),
        Color = Color3.fromRGB(0, 90, 220), Material = Enum.Material.Neon,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "BLUE REBEL", Enum.Font.GothamBlack, WHITE, Color3.fromRGB(0, 90, 220))
end
do
    local x = -25
    local brewer = mkPart({
        Name = "TeaBrewer",
        Size = Vector3.new(2.5, 3, 2.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 1.5, COUNTER_Z),
        Color = Color3.fromRGB(120, 80, 45), Material = Enum.Material.Metal,
        Tags = {"TeaBrewer"},
    })
    mkPart({
        Name = "TeaBrewerSpout",
        Size = Vector3.new(0.4, 0.4, 1),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 1, COUNTER_Z + 1.6),
        Color = Color3.fromRGB(60, 40, 25), Material = Enum.Material.Metal,
    })
    addLabel(brewer, "TEA BREWER", "Press E to brew tea", DUTCH_BLUE)
    addPrompt(brewer, "Tea Brewer", "Brew Tea")
    addSurfaceText(brewer, Enum.NormalId.Front, "TEA", Enum.Font.GothamBlack, CREAM, Color3.fromRGB(120, 80, 45))
end
do
    local x = -22
    local tank = mkPart({
        Name = "LemonadeDispenser",
        Size = Vector3.new(2.2, 4, 2.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 2, COUNTER_Z),
        Color = Color3.fromRGB(255, 230, 80), Material = Enum.Material.Glass,
        Transparency = 0.15,
        Tags = {"LemonadeDispenser"},
    })
    mkPart({
        Name = "LemonadeTap",
        Size = Vector3.new(0.4, 0.6, 0.6),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 0.5, COUNTER_Z + 1.4),
        Color = Color3.fromRGB(180, 180, 200), Material = Enum.Material.Metal,
    })
    addLabel(tank, "LEMONADE DISPENSER", "Press E to pour", DUTCH_BLUE)
    addPrompt(tank, "Lemonade Dispenser", "Pour Lemonade")
    local sign = mkPart({
        Name = "LemonadeSign",
        Size = Vector3.new(2.2, 0.6, 0.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 0.2, COUNTER_FRONT_Z + 1.5),
        Color = Color3.fromRGB(220, 180, 30), Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "LEMONADE", Enum.Font.GothamBlack, BLACK, Color3.fromRGB(255, 230, 80))
end
do
    local x = -19
    local steamer = mkPart({
        Name = "MilkSteamer",
        Size = Vector3.new(2, 2.8, 2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 1.4, COUNTER_Z),
        Color = WHITE, Material = Enum.Material.Metal,
        Tags = {"MilkSteamer"},
    })
    mkPart({
        Name = "MilkSteamerWand",
        Size = Vector3.new(0.2, 1.5, 0.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 2.5, COUNTER_Z + 1.1) * CFrame.Angles(math.rad(20), 0, 0),
        Color = Color3.fromRGB(200, 200, 220), Material = Enum.Material.Metal,
    })
    addLabel(steamer, "MILK STEAMER", "Press E to steam milk", DUTCH_BLUE)
    addPrompt(steamer, "Milk Steamer", "Steam Milk")
    addSurfaceText(steamer, Enum.NormalId.Front, "MILK", Enum.Font.GothamBlack, DUTCH_BLUE, WHITE)
end
print("[BuildStand] Base machines built (5)")

-- ============================================================
-- SYRUP WALL — 12 pumps in a SINGLE horizontal row along the BACK WALL.
-- All pumps share Z = -19 (flush against back wall) and Y = 3.8 (waist
-- height: cylinder center, bottom at counter-top height Y=3). X spaced
-- exactly 3 studs apart, centered around X=0.
-- ============================================================
do
    -- Order matches user spec exactly
    local SYRUPS = {
        {name = "Vanilla",         color = Color3.fromRGB(255, 240, 200)},
        {name = "Caramel",         color = Color3.fromRGB(190, 120, 50)},
        {name = "Chocolate",       color = Color3.fromRGB(80,  45,  20)},
        {name = "White Chocolate", color = Color3.fromRGB(245, 230, 200)},
        {name = "Hazelnut",        color = Color3.fromRGB(150, 100, 60)},
        {name = "Irish Cream",     color = Color3.fromRGB(220, 200, 160)},
        {name = "Peach",           color = Color3.fromRGB(255, 180, 130)},
        {name = "Strawberry",      color = Color3.fromRGB(220, 60,  90)},
        {name = "Coconut",         color = Color3.fromRGB(255, 250, 240)},
        {name = "Raspberry",       color = Color3.fromRGB(180, 30,  80)},
        {name = "Salted Caramel",  color = Color3.fromRGB(180, 110, 60)},
        {name = "Lavender",        color = Color3.fromRGB(190, 160, 220)},
    }
    local PUMP_SPACING = 3
    local PUMP_Y       = 3.8                -- cylinder center; bottom = 3 (waist)
    local PUMP_Z       = -BLD_D/2 + 1       -- z = -19; just inside the back wall surface (-19.5)
    local startX       = -((#SYRUPS - 1) * PUMP_SPACING) / 2  -- -16.5
    local SHELF_W      = (#SYRUPS - 1) * PUMP_SPACING + 4     -- 37 wide

    -- Dutch Bros blue backing panel mounted on the back wall
    mkPart({
        Name = "SyrupBackboard",
        Size = Vector3.new(SHELF_W, 5, 0.4),
        CFrame = CFrame.new(0, FLOOR_TOP + 4, -BLD_D/2 + 0.8),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
    -- Wood shelf the pumps stand on (flush under their bottoms at Y=3)
    mkPart({
        Name = "SyrupShelf",
        Size = Vector3.new(SHELF_W, 0.4, 1.4),
        CFrame = CFrame.new(0, FLOOR_TOP + 2.8, PUMP_Z),
        Color = Color3.fromRGB(40, 28, 16), Material = Enum.Material.Wood,
    })
    -- "SYRUPS" header sign on backboard
    local headerSign = mkPart({
        Name = "SyrupRackHeaderSign",
        Size = Vector3.new(SHELF_W - 4, 1.2, 0.2),
        CFrame = CFrame.new(0, FLOOR_TOP + 7, -BLD_D/2 + 0.6),
        Color = ACCENT_PINK, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(headerSign, Enum.NormalId.Front, "SYRUPS", Enum.Font.GothamBlack, WHITE, ACCENT_PINK)

    -- 12 pumps in a single horizontal row
    for i, syrup in ipairs(SYRUPS) do
        local bx = startX + (i - 1) * PUMP_SPACING
        local body = mkPart({
            Name = "SyrupBottle_" .. syrup.name:gsub("%s+", ""),
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(1.6, 0.7, 0.7),
            CFrame = CFrame.new(bx, PUMP_Y, PUMP_Z) * CFrame.Angles(0, 0, math.rad(90)),
            Color = syrup.color, Material = Enum.Material.Glass,
            Tags = {"SyrupPump"},
            Attributes = {SyrupName = syrup.name},
        })
        addPrompt(body, syrup.name:upper() .. " SYRUP", "Add " .. syrup.name)
        mkPart({
            Name = "SyrupCap_" .. syrup.name:gsub("%s+", ""),
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(0.6, 0.6, 0.6),
            CFrame = CFrame.new(bx, PUMP_Y + 1, PUMP_Z),
            Color = syrup.color:Lerp(BLACK, 0.4),
            Material = Enum.Material.SmoothPlastic,
        })
        -- Two-line label, 2 studs above each pump
        local bb = Instance.new("BillboardGui")
        bb.Adornee = body
        bb.Size = UDim2.new(0, 180, 0, 56)
        bb.StudsOffset = Vector3.new(0, 2, 0)
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.MaxDistance = 60
        bb.Parent = body
        local frame = Instance.new("Frame")
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundColor3 = BLACK
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        frame.Parent = bb
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(1, 0, 0, 4)
        accent.BackgroundColor3 = ACCENT_PINK
        accent.BorderSizePixel = 0
        accent.Parent = frame
        local accentCorner = Instance.new("UICorner")
        accentCorner.CornerRadius = UDim.new(0, 8)
        accentCorner.Parent = accent
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -8, 0, 20)
        title.Position = UDim2.fromOffset(4, 8)
        title.BackgroundTransparency = 1
        title.Text = syrup.name:upper() .. " SYRUP"
        title.Font = Enum.Font.GothamBlack
        title.TextSize = 16
        title.TextColor3 = WHITE
        title.Parent = frame
        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -8, 0, 18)
        sub.Position = UDim2.fromOffset(4, 32)
        sub.BackgroundTransparency = 1
        sub.Text = "Press E to add to cup"
        sub.Font = Enum.Font.GothamSemibold
        sub.TextSize = 12
        sub.TextColor3 = DUTCH_YELLOW
        sub.Parent = frame
    end
end
print("[BuildStand] Syrup wall built (12 pumps, single row, X=-16.5..+16.5, Y=3.8, Z=-19)")

-- ============================================================
-- TOPPING STATIONS (3 spheres on right counter, X = +20 / +23 / +26)
-- ============================================================
local function toppingSphere(x, name, color, tagAttr)
    local ball = mkPart({
        Name = "Topping_" .. tagAttr:gsub("%s+", ""),
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(1.4, 1.4, 1.4),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 0.7, COUNTER_Z),
        Color = color, Material = Enum.Material.SmoothPlastic,
        Tags = {"ToppingStation"}, Attributes = {ToppingName = tagAttr},
    })
    addLabel(ball, name:upper(), "Press E to add topping", ACCENT_GREEN)
    addPrompt(ball, name, "Add " .. name)
    local sign = mkPart({
        Name = "ToppingSign_" .. tagAttr:gsub("%s+", ""),
        Size = Vector3.new(2.4, 0.7, 0.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 0.2, COUNTER_FRONT_Z + 1.5),
        Color = ACCENT_GREEN, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, name:upper(), Enum.Font.GothamBlack, WHITE, ACCENT_GREEN)
end
toppingSphere(20, "Whipped Cream", WHITE,                          "Whipped Cream")
toppingSphere(23, "Boba",          Color3.fromRGB(50, 30, 25),     "Boba")
toppingSphere(26, "Soft Top",      Color3.fromRGB(245, 240, 230),  "Soft Top")
print("[BuildStand] Topping stations built (3)")

-- ============================================================
-- LID STATION (X = +29)
-- ============================================================
do
    local lidStack
    for i = 1, 5 do
        local part = mkPart({
            Name = "LidDisc_" .. i,
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(0.18, 1.8, 1.8),
            CFrame = CFrame.new(29, COUNTER_TOP_Y + 0.18 + (i - 1) * 0.18, COUNTER_Z) * CFrame.Angles(0, 0, math.rad(90)),
            Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.SmoothPlastic,
        })
        if i == 1 then
            CollectionService:AddTag(part, "LidStation")
            lidStack = part
        end
    end
    addLabel(lidStack, "LID STATION", "Press E to seal cup", ACCENT_GRAY)
    addPrompt(lidStack, "Lid Dispenser", "Seal Cup")
    local sign = mkPart({
        Name = "LidStationSign",
        Size = Vector3.new(2.2, 0.7, 0.2),
        CFrame = CFrame.new(29, COUNTER_TOP_Y + 0.2, COUNTER_FRONT_Z + 1.5),
        Color = ACCENT_GRAY, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "LIDS", Enum.Font.GothamBlack, WHITE, ACCENT_GRAY)
end
print("[BuildStand] Lid station built")

-- ============================================================
-- SLEEVE STATION (right wall side counter)
-- ============================================================
do
    mkPart({
        Name = "SleeveCounter",
        Size = Vector3.new(2.5, 3, 2),
        CFrame = CFrame.new(BLD_W/2 - 2.5, FLOOR_TOP + 1.5, -14),
        Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.Wood,
    })
    local sleeve = mkPart({
        Name = "SleeveStation",
        Size = Vector3.new(1.5, 1.4, 1.5),
        CFrame = CFrame.new(BLD_W/2 - 2.5, FLOOR_TOP + 3.7, -14),
        Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Fabric,
        Tags = {"SleeveStation"},
    })
    addLabel(sleeve, "SLEEVES", "Press E to add sleeve", ACCENT_GRAY)
    addPrompt(sleeve, "Sleeves", "Add Sleeve")
    addSurfaceText(sleeve, Enum.NormalId.Front, "SLEEVES", Enum.Font.GothamBlack, CREAM, Color3.fromRGB(120, 80, 50))
end
print("[BuildStand] Sleeve station built")

-- ============================================================
-- TRASH CAN
-- ============================================================
do
    local trash = mkPart({
        Name = "TrashCan",
        Size = Vector3.new(2, 3, 2),
        CFrame = CFrame.new(-BLD_W/2 + 4, FLOOR_TOP + 1.5, BLD_D/2 - 5),
        Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal,
        Tags = {"TrashCan"},
    })
    addLabel(trash, "TRASH", "Press E to discard cup", ACCENT_RED)
    addPrompt(trash, "Trash", "Discard Cup")
    addSurfaceText(trash, Enum.NormalId.Front, "TRASH", Enum.Font.GothamBlack, WHITE, ACCENT_RED)
end
print("[BuildStand] Trash can built")

-- ============================================================
-- FLOOR ARROWS — chevrons in the player walking lane (z = -10),
-- showing the LEFT-TO-RIGHT workflow direction.
-- ============================================================
do
    local arrowZ = -10
    local positions = {-37, -27, -17, 0, 17, 27, 35}
    for i, x in ipairs(positions) do
        local arrow = mkPart({
            Name = "FlowArrow_" .. i,
            Size = Vector3.new(3.5, 0.06, 1.6),
            CFrame = CFrame.new(x, FLOOR_TOP + 0.04, arrowZ),
            Color = DUTCH_ORANGE, Material = Enum.Material.Neon,
            CanCollide = false,
        })
        addSurfaceText(arrow, Enum.NormalId.Top, "→", Enum.Font.GothamBlack, BLACK, DUTCH_ORANGE)
    end
end
print("[BuildStand] Floor arrows built")

-- ============================================================
-- CHALKBOARD MENU on the back wall above the cup-tower area
-- ============================================================
do
    local board = mkPart({
        Name = "ChalkboardMenu",
        Size = Vector3.new(10, 6, 0.4),
        CFrame = CFrame.new(-37, COUNTER_TOP_Y + 7, -BLD_D/2 + 0.8),
        Color = CHALK_GREEN, Material = Enum.Material.Slate,
    })
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.LightInfluence = 0
    sg.PixelsPerStud = 50
    sg.Parent = board
    local pad = Instance.new("Frame")
    pad.Size = UDim2.fromScale(1, 1)
    pad.BackgroundTransparency = 1
    pad.Parent = sg
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.18, 0)
    title.BackgroundTransparency = 1
    title.Text = "~ TODAY'S MENU ~"
    title.Font = Enum.Font.Antique
    title.TextScaled = true
    title.TextColor3 = DUTCH_ORANGE
    title.Parent = pad
    local list = Instance.new("Frame")
    list.Size = UDim2.new(1, -20, 0.78, 0)
    list.Position = UDim2.new(0, 10, 0.2, 0)
    list.BackgroundTransparency = 1
    list.Parent = pad
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = list
    local items = {
        {"Caramelizer",  "$5"},
        {"Annihilator",  "$5"},
        {"Golden Eagle", "$5"},
        {"White Mocha",  "$5"},
        {"OG Gummybear", "$5"},
        {"Shark Attack", "$5"},
        {"Lemonberry",   "$4"},
        {"Peach Tea",    "$4"},
    }
    for i, item in ipairs(items) do
        local row = Instance.new("TextLabel")
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundTransparency = 1
        row.Text = ("%s %s %s"):format(item[1], string.rep(".", math.max(2, 26 - #item[1])), item[2])
        row.Font = Enum.Font.Antique
        row.TextSize = 28
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.TextColor3 = CREAM
        row.LayoutOrder = i
        row.Parent = list
    end
end
print("[BuildStand] Chalkboard menu built")

-- ============================================================
-- STICKER WALL on left interior wall
-- ============================================================
do
    local leftWall = stand:FindFirstChild("LeftWall")
    if leftWall then
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Right
        sg.LightInfluence = 0
        sg.PixelsPerStud = 30
        sg.Parent = leftWall
        local STICKER_TEXTS = {
            "LOVE ABOUNDS", "BRO!", "STAY CAFFEINATED", "REBEL 4 LIFE",
            "BUZZ", "BESTIE", "DUTCH MAFIA", "KICKIN' IT",
            "MUCHAS GRACIAS", "GOLDEN HOUR", "WHIP IT", "SUNSHINE",
            "WIRED", "PEACE OUT", "☕", "❤", "⚡", "✨", "★", "♨",
        }
        local STICKER_COLORS = {
            DUTCH_ORANGE, DUTCH_YELLOW, ACCENT_PINK, DUTCH_BLUE,
            ACCENT_GREEN, Color3.fromRGB(220, 80, 200),
            Color3.fromRGB(100, 220, 220), Color3.fromRGB(255, 100, 100),
        }
        local rng = Random.new(7777)
        for _ = 1, 22 do
            local sticker = Instance.new("TextLabel")
            local sw = rng:NextNumber(0.08, 0.20)
            local sh = rng:NextNumber(0.05, 0.13)
            local sx = rng:NextNumber(sw/2 + 0.02, 1 - sw/2 - 0.02)
            local sy = rng:NextNumber(sh/2 + 0.02, 1 - sh/2 - 0.02)
            sticker.Size = UDim2.new(sw, 0, sh, 0)
            sticker.Position = UDim2.new(sx - sw/2, 0, sy - sh/2, 0)
            sticker.BackgroundColor3 = STICKER_COLORS[rng:NextInteger(1, #STICKER_COLORS)]
            sticker.Text = STICKER_TEXTS[rng:NextInteger(1, #STICKER_TEXTS)]
            sticker.Font = Enum.Font.GothamBlack
            sticker.TextScaled = true
            sticker.TextColor3 = (rng:NextNumber() < 0.5) and WHITE or BLACK
            sticker.Rotation = rng:NextInteger(-30, 30)
            sticker.Parent = sg
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 8)
            c.Parent = sticker
            local stroke = Instance.new("UIStroke")
            stroke.Color = WHITE; stroke.Thickness = 2
            stroke.Parent = sticker
        end
    end
end
print("[BuildStand] Sticker wall built")

-- ============================================================
-- INTERIOR LIGHTING
-- ============================================================
do
    local lightY = FLOOR_TOP + BLD_H - 3
    local positions = {
        Vector3.new(-30, lightY, 0),
        Vector3.new(-15, lightY, 0),
        Vector3.new(  0, lightY, 0),
        Vector3.new( 15, lightY, 0),
        Vector3.new( 30, lightY, 0),
        Vector3.new(-15, lightY, -10),
        Vector3.new( 15, lightY, -10),
    }
    for i, pos in ipairs(positions) do
        local lp = mkPart({
            Name = "InteriorLight_" .. i,
            Size = Vector3.new(0.8, 0.3, 0.8),
            CFrame = CFrame.new(pos),
            Color = Color3.fromRGB(220, 240, 255),
            Material = Enum.Material.Neon, CanCollide = false,
        })
        local pl = Instance.new("PointLight")
        pl.Color = Color3.fromRGB(180, 210, 255)
        pl.Brightness = 2; pl.Range = 18
        pl.Parent = lp
    end
end
print("[BuildStand] Interior lights built")

-- ============================================================
-- SPAWN LOCATION (invisible, on the floor at the cup-tower end)
-- Floor top is Y=0. Spawn part is 1 stud tall, center Y=0.5, top Y=1.
-- Player HRP lands ~3 studs above spawn top → HRP at Y≈4 inside the
-- building, well below the roof at Y=16.
-- ============================================================
do
    local SPAWN_X, SPAWN_Y, SPAWN_Z = -40, 0.5, 0
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "StandSpawn"
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Size = Vector3.new(6, 1, 6)
    -- LookAt makes the spawn's LookVector point toward the workflow (+X),
    -- so the player faces east toward the bases / syrup wall on spawn.
    spawn.CFrame = CFrame.lookAt(Vector3.new(SPAWN_X, SPAWN_Y, SPAWN_Z), Vector3.new(0, SPAWN_Y, SPAWN_Z))
    spawn.Transparency = 1
    spawn.TopSurface = Enum.SurfaceType.Smooth
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Parent = stand
    print(("[BuildStand] Spawn placed at X=%d, Y=%.1f, Z=%d"):format(SPAWN_X, SPAWN_Y, SPAWN_Z))
end

print("[BuildStand] Build complete. Self-destructing.")
script:Destroy()
