-- BuildStand.server.lua
-- Procedurally constructs a recognizable Dutch Bros drive-thru location
-- with a properly spaced kitchen interior. Every station has THREE
-- visibility cues:
--   1. A floating BillboardGui label (name + instruction subtitle)
--   2. A distinct shape/color so stations read at a glance
--   3. A SurfaceGui on the front face (when the part has a flat front)
-- Every ProximityPrompt has ObjectText (station name) and ActionText
-- (specific verb like "Pull Shots" or "Add Vanilla").
--
-- Self-destructs at the end. Tags every interactive part so
-- StationInteraction.server.lua and HandoffWindow.server.lua wire up
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
-- Geometry — bigger than before so stations have 4-5 stud spacing
-- ============================================================
local BLD_W       = 60   -- interior X span
local BLD_D       = 40   -- interior Z span
local BLD_H       = 16   -- wall height
local FLOOR_Y     = 0
local FLOOR_TOP   = FLOOR_Y + 0.5
local WALL_THICK  = 1

-- Cleanup any prior build (and any default Roblox spawn)
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
    return prompt
end

-- ============================================================
-- Asphalt parking lot (large slab beneath everything)
-- ============================================================
mkPart({
    Name = "ParkingLot",
    Size = Vector3.new(160, 1, 120),
    CFrame = CFrame.new(0, FLOOR_Y - 0.5, 0),
    Color = ASPHALT,
    Material = Enum.Material.Asphalt,
})

mkPart({
    Name = "GrassStrip",
    Size = Vector3.new(8, 0.6, 120),
    CFrame = CFrame.new(-76, FLOOR_Y - 0.2, 0),
    Color = GRASS,
    Material = Enum.Material.Grass,
})
mkPart({
    Name = "Curb",
    Size = Vector3.new(0.6, 0.8, 120),
    CFrame = CFrame.new(-72, FLOOR_Y, 0),
    Color = CURB,
    Material = Enum.Material.Concrete,
})

mkPart({
    Name = "Sidewalk",
    Size = Vector3.new(BLD_W + 8, 0.4, 6),
    CFrame = CFrame.new(0, FLOOR_Y - 0.05, BLD_D/2 + 4),
    Color = SIDEWALK,
    Material = Enum.Material.Concrete,
})

-- Parking-lot stripes (front of building)
do
    local startX = -24
    local spacing = 8
    for i = 0, 5 do
        mkPart({
            Name = "ParkingLine_" .. i,
            Size = Vector3.new(0.3, 0.05, 12),
            CFrame = CFrame.new(startX + i * spacing, FLOOR_Y + 0.05, BLD_D/2 + 14),
            Color = WHITE,
            Material = Enum.Material.SmoothPlastic,
            CanCollide = false,
        })
    end
end

-- ============================================================
-- Drive-thru lane (along east side of building)
-- ============================================================
do
    mkPart({
        Name = "DriveThruLane",
        Size = Vector3.new(10, 0.06, 80),
        CFrame = CFrame.new(38, FLOOR_Y + 0.03, 0),
        Color = Color3.fromRGB(35, 35, 40),
        Material = Enum.Material.Asphalt,
        CanCollide = false,
    })
    for i = -5, 5 do
        mkPart({
            Name = "LaneDash_" .. i,
            Size = Vector3.new(0.3, 0.06, 3),
            CFrame = CFrame.new(38, FLOOR_Y + 0.07, i * 7),
            Color = DUTCH_YELLOW,
            Material = Enum.Material.SmoothPlastic,
            CanCollide = false,
        })
    end
    mkPart({
        Name = "LaneEdgeLeft",
        Size = Vector3.new(0.25, 0.06, 80),
        CFrame = CFrame.new(33.2, FLOOR_Y + 0.07, 0),
        Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false,
    })
    mkPart({
        Name = "LaneEdgeRight",
        Size = Vector3.new(0.25, 0.06, 80),
        CFrame = CFrame.new(42.8, FLOOR_Y + 0.07, 0),
        Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false,
    })
end

-- ============================================================
-- 3 simple box cars (5 parts each: body + 4 wheels) per spec
-- ============================================================
local function buildSimpleCar(x, z, bodyColor)
    mkPart({
        Name = "CarBody",
        Size = Vector3.new(4, 2.4, 8),
        CFrame = CFrame.new(x, FLOOR_Y + 1.4, z),
        Color = bodyColor,
        Material = Enum.Material.SmoothPlastic,
    })
    for _, w in ipairs({
        {x - 1.7, FLOOR_Y + 0.6, z - 2.5},
        {x + 1.7, FLOOR_Y + 0.6, z - 2.5},
        {x - 1.7, FLOOR_Y + 0.6, z + 2.5},
        {x + 1.7, FLOOR_Y + 0.6, z + 2.5},
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
buildSimpleCar(38, 18,  Color3.fromRGB(60,  90,  200))
buildSimpleCar(38, 0,   Color3.fromRGB(220, 50,  50))
buildSimpleCar(38, -18, Color3.fromRGB(60,  160, 80))

-- ============================================================
-- Building floor (interior, distinct dark tile look)
-- ============================================================
mkPart({
    Name = "InteriorFloor",
    Size = Vector3.new(BLD_W, 1, BLD_D),
    CFrame = CFrame.new(0, FLOOR_Y, 0),
    Color = FLOOR_KITCHEN,
    Material = Enum.Material.SmoothPlastic,
})

-- ============================================================
-- Walls (corrugated metal blue-gray) with window cutouts
-- ============================================================
mkPart({
    Name = "BackWall",
    Size = Vector3.new(BLD_W, BLD_H, WALL_THICK),
    CFrame = CFrame.new(0, FLOOR_TOP + BLD_H/2, -BLD_D/2 + WALL_THICK/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})
mkPart({
    Name = "LeftWall",
    Size = Vector3.new(WALL_THICK, BLD_H, BLD_D),
    CFrame = CFrame.new(-BLD_W/2 + WALL_THICK/2, FLOOR_TOP + BLD_H/2, 0),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})

-- Front wall: walk-up window cutout at x ∈ [-22, -12], y ∈ [3, 8]
local FRONT_Z = BLD_D/2 - WALL_THICK/2
local WUW_X1, WUW_X2 = -22, -12
local WUW_Y1, WUW_Y2 = 3, 8
mkPart({
    Name = "FrontWallLeftSeg",
    Size = Vector3.new(WUW_X1 - (-BLD_W/2), BLD_H, WALL_THICK),
    CFrame = CFrame.new(((-BLD_W/2) + WUW_X1)/2, FLOOR_TOP + BLD_H/2, FRONT_Z),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})
mkPart({
    Name = "FrontWallRightSeg",
    Size = Vector3.new((BLD_W/2) - WUW_X2, BLD_H, WALL_THICK),
    CFrame = CFrame.new((WUW_X2 + (BLD_W/2))/2, FLOOR_TOP + BLD_H/2, FRONT_Z),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})
mkPart({
    Name = "FrontWallAboveWUW",
    Size = Vector3.new(WUW_X2 - WUW_X1, BLD_H - WUW_Y2, WALL_THICK),
    CFrame = CFrame.new((WUW_X1 + WUW_X2)/2, FLOOR_TOP + WUW_Y2 + (BLD_H - WUW_Y2)/2, FRONT_Z),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})
mkPart({
    Name = "FrontWallBelowWUW",
    Size = Vector3.new(WUW_X2 - WUW_X1, WUW_Y1, WALL_THICK),
    CFrame = CFrame.new((WUW_X1 + WUW_X2)/2, FLOOR_TOP + WUW_Y1/2, FRONT_Z),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})

-- Right wall: drive-thru window cutout at z ∈ [-3, 7], y ∈ [3, 8]
local RIGHT_X = BLD_W/2 - WALL_THICK/2
local DTW_Z1, DTW_Z2 = -3, 7
local DTW_Y1, DTW_Y2 = 3, 8
mkPart({
    Name = "RightWallBackSeg",
    Size = Vector3.new(WALL_THICK, BLD_H, DTW_Z1 - (-BLD_D/2)),
    CFrame = CFrame.new(RIGHT_X, FLOOR_TOP + BLD_H/2, ((-BLD_D/2) + DTW_Z1)/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})
mkPart({
    Name = "RightWallFrontSeg",
    Size = Vector3.new(WALL_THICK, BLD_H, (BLD_D/2) - DTW_Z2),
    CFrame = CFrame.new(RIGHT_X, FLOOR_TOP + BLD_H/2, (DTW_Z2 + (BLD_D/2))/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})
mkPart({
    Name = "RightWallAboveDTW",
    Size = Vector3.new(WALL_THICK, BLD_H - DTW_Y2, DTW_Z2 - DTW_Z1),
    CFrame = CFrame.new(RIGHT_X, FLOOR_TOP + DTW_Y2 + (BLD_H - DTW_Y2)/2, (DTW_Z1 + DTW_Z2)/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})
mkPart({
    Name = "RightWallBelowDTW",
    Size = Vector3.new(WALL_THICK, DTW_Y1, DTW_Z2 - DTW_Z1),
    CFrame = CFrame.new(RIGHT_X, FLOOR_TOP + DTW_Y1/2, (DTW_Z1 + DTW_Z2)/2),
    Color = METAL_BLUEGRAY, Material = Enum.Material.CorrugatedMetal,
})

-- ============================================================
-- Blue accent tower on front-left (architectural feature)
-- ============================================================
do
    mkPart({
        Name = "BlueAccentTowerFront",
        Size = Vector3.new(5, BLD_H + 5, 0.4),
        CFrame = CFrame.new(-BLD_W/2 + 2.5, FLOOR_TOP + (BLD_H + 5)/2, BLD_D/2 + 0.3),
        Color = DARK_BLUE, Material = Enum.Material.CorrugatedMetal,
    })
    mkPart({
        Name = "BlueAccentTowerSide",
        Size = Vector3.new(0.4, BLD_H + 5, 5),
        CFrame = CFrame.new(-BLD_W/2 - 0.3, FLOOR_TOP + (BLD_H + 5)/2, BLD_D/2 - 2),
        Color = DARK_BLUE, Material = Enum.Material.CorrugatedMetal,
    })
    mkPart({
        Name = "BlueAccentTowerCap",
        Size = Vector3.new(5.4, 0.4, 5.4),
        CFrame = CFrame.new(-BLD_W/2 + 2.3, FLOOR_TOP + BLD_H + 5, BLD_D/2 - 2),
        Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Slate,
    })
end

-- ============================================================
-- Roof + Dutch Bros blue fascia trim
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

-- ============================================================
-- Stone pillars
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

-- ============================================================
-- Front awning across walk-up entrance
-- ============================================================
do
    local awningY = FLOOR_TOP + BLD_H - 7
    mkPart({
        Name = "FrontAwning",
        Size = Vector3.new(BLD_W + 4, 0.6, 5),
        CFrame = CFrame.new(0, awningY, BLD_D/2 + 2),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
    pillar(-15, BLD_D/2 + 4, BLD_H - 7, "FrontAwningPillar_L")
    pillar( 18, BLD_D/2 + 4, BLD_H - 7, "FrontAwningPillar_R")
end

-- ============================================================
-- Drive-thru awning
-- ============================================================
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

-- ============================================================
-- String lights above the awning
-- ============================================================
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

-- ============================================================
-- Front sign + side sign + welcome band + EXIT ONLY
-- ============================================================
do
    local sign = mkPart({
        Name = "FrontDutchBrosSign",
        Size = Vector3.new(28, 5, 0.4),
        CFrame = CFrame.new(6, FLOOR_TOP + BLD_H - 3, BLD_D/2 + 0.5),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "DUTCH BROS Coffee", Enum.Font.GothamBlack, DUTCH_YELLOW, DUTCH_BLUE)
    addStripeBand("FrontSignStripe", CFrame.new(6, FLOOR_TOP + BLD_H - 6, BLD_D/2 + 0.6), 28, "X")

    local spotPart = mkPart({
        Name = "FrontSignSpotlight",
        Size = Vector3.new(0.4, 0.4, 0.4),
        CFrame = CFrame.new(6, FLOOR_TOP + BLD_H + 2, BLD_D/2 + 5),
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
        Size = Vector3.new(WUW_X2 - WUW_X1, 1, 0.2),
        CFrame = CFrame.new((WUW_X1 + WUW_X2)/2, FLOOR_TOP + WUW_Y2 + 0.6, BLD_D/2 + 0.6),
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

-- Walk-up window counter
mkPart({
    Name = "WalkUpCounter",
    Size = Vector3.new(WUW_X2 - WUW_X1, 0.4, 2),
    CFrame = CFrame.new((WUW_X1 + WUW_X2)/2, FLOOR_TOP + WUW_Y1 - 0.2, BLD_D/2 + 1),
    Color = CREAM, Material = Enum.Material.Marble,
})

-- ============================================================
-- Drive-thru hand-off counter (interior side, tagged HandoffWindow)
-- + a big floor arrow on the floor pointing at it
-- ============================================================
do
    local handoff = mkPart({
        Name = "DriveThruHandoff",
        Size = Vector3.new(2.5, 3, DTW_Z2 - DTW_Z1),
        CFrame = CFrame.new(BLD_W/2 - 1.5, FLOOR_TOP + 1.5, (DTW_Z1 + DTW_Z2)/2),
        Color = CREAM, Material = Enum.Material.Marble,
        Tags = {"HandoffWindow"},
    })
    addLabel(handoff, "Hand-Off Window", "Press E to deliver drink", DUTCH_ORANGE)
    addPrompt(handoff, "Drive-Thru Window", "Hand Off")
    -- Top SurfaceGui showing arrow + text (visible from above)
    addSurfaceText(handoff, Enum.NormalId.Top, "→ HAND OFF HERE →", Enum.Font.GothamBlack, WHITE, DUTCH_ORANGE)

    -- Big floor arrow on the floor pointing east at the handoff
    local arrow = mkPart({
        Name = "HandoffFloorArrow",
        Size = Vector3.new(8, 0.06, 2.5),
        CFrame = CFrame.new(BLD_W/2 - 8, FLOOR_TOP + 0.04, 2),
        Color = DUTCH_ORANGE, Material = Enum.Material.Neon,
        CanCollide = false,
    })
    addSurfaceText(arrow, Enum.NormalId.Top, "→ HAND OFF →", Enum.Font.GothamBlack, BLACK, DUTCH_ORANGE)
end

-- ============================================================
-- Back counter where the kitchen stations sit
-- ============================================================
local COUNTER_FRONT_Z = -BLD_D/2 + 5    -- front face of counter
local COUNTER_Z       = -BLD_D/2 + 4    -- counter center
local COUNTER_TOP_Y   = FLOOR_TOP + 3

mkPart({
    Name = "BackCounterBody",
    Size = Vector3.new(BLD_W - 6, 3, 3),
    CFrame = CFrame.new(0, FLOOR_TOP + 1.5, COUNTER_Z),
    Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.Wood,
})
mkPart({
    Name = "BackCounterTop",
    Size = Vector3.new(BLD_W - 5.5, 0.2, 3.4),
    CFrame = CFrame.new(0, COUNTER_TOP_Y, COUNTER_Z),
    Color = CREAM, Material = Enum.Material.Marble,
})

-- ============================================================
-- CUP TOWERS (FAR LEFT) — vertical cylinders, three heights
-- ============================================================
local function cupTower(x, sizeName, height, tag, frontTextSize)
    -- Roblox Cylinder long axis is local X; rotate 90deg around Z so it stands up.
    local cyl = mkPart({
        Name = "CupTower" .. sizeName,
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(height, 2.4, 2.4),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + height/2, COUNTER_Z) * CFrame.Angles(0, 0, math.rad(90)),
        Color = WHITE, Material = Enum.Material.Plastic,
        Tags = {tag},
    })
    addLabel(cyl, sizeName .. " Cups", "Press E to grab cup", DUTCH_BLUE)
    addPrompt(cyl, sizeName .. " Cup Tower", "Grab " .. sizeName .. " Cup")
    -- Cylinders don't have a usable flat front for SurfaceGui, so add a small
    -- flat sign block in front of the tower (faces +Z toward player).
    local sign = mkPart({
        Name = "CupTowerSign_" .. sizeName,
        Size = Vector3.new(2, 0.8, 0.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 0.5, COUNTER_FRONT_Z + 1.5),
        Color = DUTCH_BLUE, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, sizeName:upper() .. " CUPS", Enum.Font.GothamBlack, WHITE, DUTCH_BLUE)
    return cyl
end
cupTower(-26, "Small",  4, "CupTower_Small")
cupTower(-22, "Medium", 5, "CupTower_Medium")
cupTower(-18, "Large",  6, "CupTower_Large")

-- ============================================================
-- BASE MACHINES (LEFT-CENTER) — distinct shapes per machine
-- ============================================================
-- 1) Espresso machine: wide dark metallic box with a smaller box on top
do
    local base = mkPart({
        Name = "EspressoMachine",
        Size = Vector3.new(3, 2, 2.5),
        CFrame = CFrame.new(-13, COUNTER_TOP_Y + 1, COUNTER_Z),
        Color = Color3.fromRGB(50, 50, 58), Material = Enum.Material.Metal,
        Tags = {"EspressoMachine"},
    })
    mkPart({
        Name = "EspressoMachineTop",
        Size = Vector3.new(2, 1.3, 2),
        CFrame = CFrame.new(-13, COUNTER_TOP_Y + 2.65, COUNTER_Z),
        Color = Color3.fromRGB(35, 35, 40), Material = Enum.Material.Metal,
    })
    -- portafilter handle protruding from front
    mkPart({
        Name = "EspressoHandle",
        Size = Vector3.new(0.4, 0.4, 1.2),
        CFrame = CFrame.new(-13, COUNTER_TOP_Y + 1, COUNTER_Z + 1.8),
        Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood,
    })
    addLabel(base, "Espresso Machine", "Press E to pull shots", DUTCH_BLUE)
    addPrompt(base, "Espresso Machine", "Pull Shots")
    addSurfaceText(base, Enum.NormalId.Front, "ESPRESSO", Enum.Font.GothamBlack, DUTCH_YELLOW, Color3.fromRGB(50, 50, 58))
end
-- 2) Blue Rebel tap: tall thin neon-blue cylinder
do
    local tap = mkPart({
        Name = "RebelTap",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(4, 1.4, 1.4),
        CFrame = CFrame.new(-8, COUNTER_TOP_Y + 2, COUNTER_Z) * CFrame.Angles(0, 0, math.rad(90)),
        Color = Color3.fromRGB(0, 130, 220), Material = Enum.Material.Neon,
        Tags = {"RebelTap"},
    })
    -- spout
    mkPart({
        Name = "RebelTapSpout",
        Size = Vector3.new(0.3, 0.8, 1),
        CFrame = CFrame.new(-8, COUNTER_TOP_Y + 0.6, COUNTER_Z + 1.2),
        Color = Color3.fromRGB(180, 180, 200), Material = Enum.Material.Metal,
    })
    addLabel(tap, "Blue Rebel Tap", "Press E to fill", DUTCH_BLUE)
    addPrompt(tap, "Blue Rebel Tap", "Fill Cup")
    -- Front-text on a sign block
    local sign = mkPart({
        Name = "RebelTapSign",
        Size = Vector3.new(2.2, 0.6, 0.2),
        CFrame = CFrame.new(-8, COUNTER_TOP_Y + 0.2, COUNTER_FRONT_Z + 1.5),
        Color = Color3.fromRGB(0, 90, 220), Material = Enum.Material.Neon,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "BLUE REBEL", Enum.Font.GothamBlack, WHITE, Color3.fromRGB(0, 90, 220))
end
-- 3) Tea brewer: dark brown metal box with handle
do
    local brewer = mkPart({
        Name = "TeaBrewer",
        Size = Vector3.new(2.5, 3, 2.2),
        CFrame = CFrame.new(-3, COUNTER_TOP_Y + 1.5, COUNTER_Z),
        Color = Color3.fromRGB(120, 80, 45), Material = Enum.Material.Metal,
        Tags = {"TeaBrewer"},
    })
    mkPart({
        Name = "TeaBrewerSpout",
        Size = Vector3.new(0.4, 0.4, 1),
        CFrame = CFrame.new(-3, COUNTER_TOP_Y + 1, COUNTER_Z + 1.6),
        Color = Color3.fromRGB(60, 40, 25), Material = Enum.Material.Metal,
    })
    addLabel(brewer, "Tea Brewer", "Press E to brew", DUTCH_BLUE)
    addPrompt(brewer, "Tea Brewer", "Brew Tea")
    addSurfaceText(brewer, Enum.NormalId.Front, "TEA", Enum.Font.GothamBlack, CREAM, Color3.fromRGB(120, 80, 45))
end
-- 4) Lemonade dispenser: yellow translucent tank shape
do
    local tank = mkPart({
        Name = "LemonadeDispenser",
        Size = Vector3.new(2.2, 4, 2.2),
        CFrame = CFrame.new(2, COUNTER_TOP_Y + 2, COUNTER_Z),
        Color = Color3.fromRGB(255, 230, 80), Material = Enum.Material.Glass,
        Transparency = 0.15,
        Tags = {"LemonadeDispenser"},
    })
    mkPart({
        Name = "LemonadeTap",
        Size = Vector3.new(0.4, 0.6, 0.6),
        CFrame = CFrame.new(2, COUNTER_TOP_Y + 0.5, COUNTER_Z + 1.4),
        Color = Color3.fromRGB(180, 180, 200), Material = Enum.Material.Metal,
    })
    addLabel(tank, "Lemonade", "Press E to pour", DUTCH_BLUE)
    addPrompt(tank, "Lemonade Dispenser", "Pour Lemonade")
    -- Front sign because the tank is glass
    local sign = mkPart({
        Name = "LemonadeSign",
        Size = Vector3.new(2.2, 0.6, 0.2),
        CFrame = CFrame.new(2, COUNTER_TOP_Y + 0.2, COUNTER_FRONT_Z + 1.5),
        Color = Color3.fromRGB(220, 180, 30), Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "LEMONADE", Enum.Font.GothamBlack, BLACK, Color3.fromRGB(255, 230, 80))
end
-- 5) Milk steamer: chrome metal box
do
    local steamer = mkPart({
        Name = "MilkSteamer",
        Size = Vector3.new(2, 2.8, 2),
        CFrame = CFrame.new(7, COUNTER_TOP_Y + 1.4, COUNTER_Z),
        Color = WHITE, Material = Enum.Material.Metal,
        Tags = {"MilkSteamer"},
    })
    -- steam wand
    mkPart({
        Name = "MilkSteamerWand",
        Size = Vector3.new(0.2, 1.5, 0.2),
        CFrame = CFrame.new(7, COUNTER_TOP_Y + 2.5, COUNTER_Z + 1.1) * CFrame.Angles(math.rad(20), 0, 0),
        Color = Color3.fromRGB(200, 200, 220), Material = Enum.Material.Metal,
    })
    addLabel(steamer, "Milk Steamer", "Press E to steam", DUTCH_BLUE)
    addPrompt(steamer, "Milk Steamer", "Steam Milk")
    addSurfaceText(steamer, Enum.NormalId.Front, "MILK", Enum.Font.GothamBlack, DUTCH_BLUE, WHITE)
end

-- ============================================================
-- SYRUP WALL (CENTER) — 12 pumps, 2 rows of 6, wall-mounted
-- Each pump = colored cylinder body + small ball cap on top
-- ============================================================
do
    local SYRUPS = {
        {name = "Vanilla",         color = Color3.fromRGB(255, 240, 200)},
        {name = "Caramel",         color = Color3.fromRGB(190, 120, 50)},
        {name = "Chocolate",       color = Color3.fromRGB(80,  45,  20)},
        {name = "White Chocolate", color = Color3.fromRGB(245, 230, 200)},
        {name = "Hazelnut",        color = Color3.fromRGB(150, 100, 60)},
        {name = "Irish Cream",     color = Color3.fromRGB(220, 200, 160)},
        {name = "Macadamia Nut",   color = Color3.fromRGB(220, 190, 140)},
        {name = "Coconut",         color = Color3.fromRGB(255, 250, 240)},
        {name = "Strawberry",      color = Color3.fromRGB(220, 60,  90)},
        {name = "Peach",           color = Color3.fromRGB(255, 180, 130)},
        {name = "Blue Raspberry",  color = Color3.fromRGB(40,  120, 220)},
        {name = "Lime",            color = Color3.fromRGB(120, 220, 80)},
    }
    local rackX = 12
    local rackZ = -BLD_D/2 + 1.5
    local rackY = COUNTER_TOP_Y + 4.5
    local rackW = 14
    local rackH = 5.5
    -- Rack backboard
    mkPart({
        Name = "SyrupRackBoard",
        Size = Vector3.new(rackW, rackH, 0.4),
        CFrame = CFrame.new(rackX, rackY, rackZ),
        Color = Color3.fromRGB(50, 35, 20), Material = Enum.Material.Wood,
    })
    for r = 1, 2 do
        mkPart({
            Name = "SyrupShelf_" .. r,
            Size = Vector3.new(rackW, 0.3, 0.8),
            CFrame = CFrame.new(rackX, rackY - rackH/2 + (r - 0.5) * (rackH/2), rackZ + 0.6),
            Color = Color3.fromRGB(40, 28, 16), Material = Enum.Material.Wood,
        })
    end
    -- Header sign
    local headerAnchor = mkPart({
        Name = "SyrupRackHeader",
        Size = Vector3.new(0.2, 0.2, 0.2),
        CFrame = CFrame.new(rackX, rackY + rackH/2 + 1, rackZ),
        Transparency = 1, CanCollide = false,
    })
    addLabel(headerAnchor, "Syrup Wall", "Press E on a bottle to add", ACCENT_PINK)
    -- Big front sign panel under the rack
    local syrupSignBoard = mkPart({
        Name = "SyrupRackFrontSign",
        Size = Vector3.new(rackW, 1.2, 0.2),
        CFrame = CFrame.new(rackX, COUNTER_TOP_Y + 0.6, COUNTER_FRONT_Z + 1.5),
        Color = ACCENT_PINK, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(syrupSignBoard, Enum.NormalId.Front, "SYRUPS", Enum.Font.GothamBlack, WHITE, ACCENT_PINK)

    local cols = 6
    local spacing = rackW / cols
    for i, syrup in ipairs(SYRUPS) do
        local row = math.floor((i - 1) / cols) + 1
        local col = ((i - 1) % cols) + 1
        local bx = rackX - rackW/2 + (col - 0.5) * spacing
        local by = rackY - rackH/2 + (row - 0.5) * (rackH/2)
        local bz = rackZ + 0.95
        -- pump body: tall thin cylinder (vertical)
        local body = mkPart({
            Name = "SyrupBottle_" .. syrup.name:gsub("%s+", ""),
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(1.6, 0.7, 0.7),
            CFrame = CFrame.new(bx, by, bz) * CFrame.Angles(0, 0, math.rad(90)),
            Color = syrup.color, Material = Enum.Material.Glass,
            Tags = {"SyrupPump"},
            Attributes = {SyrupName = syrup.name},
        })
        addPrompt(body, syrup.name .. " Syrup", "Add " .. syrup.name)
        -- pump cap (small ball above the cylinder)
        mkPart({
            Name = "SyrupCap_" .. syrup.name:gsub("%s+", ""),
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(0.6, 0.6, 0.6),
            CFrame = CFrame.new(bx, by + 1, bz),
            Color = syrup.color:Lerp(BLACK, 0.4),
            Material = Enum.Material.SmoothPlastic,
        })
        -- small text label
        local bb = Instance.new("BillboardGui")
        bb.Adornee = body
        bb.Size = UDim2.new(0, 100, 0, 24)
        bb.StudsOffset = Vector3.new(0, 1.6, 0)
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.MaxDistance = 35
        bb.Parent = body
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundColor3 = BLACK
        lbl.BackgroundTransparency = 0.25
        lbl.Text = syrup.name
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextScaled = true
        lbl.TextColor3 = WHITE
        lbl.Parent = bb
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = lbl
    end
end

-- ============================================================
-- TOPPING STATIONS — small round (Ball) parts, color-coded
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
    addLabel(ball, name, "Press E to add", ACCENT_GREEN)
    addPrompt(ball, name, "Add " .. name)
    -- Front sign block (since spheres don't have flat faces)
    local sign = mkPart({
        Name = "ToppingSign_" .. tagAttr:gsub("%s+", ""),
        Size = Vector3.new(2.4, 0.7, 0.2),
        CFrame = CFrame.new(x, COUNTER_TOP_Y + 0.2, COUNTER_FRONT_Z + 1.5),
        Color = ACCENT_GREEN, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, name:upper(), Enum.Font.GothamBlack, WHITE, ACCENT_GREEN)
end
toppingSphere(15, "Whipped Cream",  WHITE,                              "Whipped Cream")
toppingSphere(18, "Boba",           Color3.fromRGB(50, 30, 25),         "Boba")
toppingSphere(21, "Soft Top",       Color3.fromRGB(245, 240, 230),      "Soft Top")
toppingSphere(24, "Caramel Drizzle",Color3.fromRGB(190, 120, 50),       "Caramel Drizzle")

-- ============================================================
-- LID STATION — stack of flat cylinders (looks like stacked lids)
-- ============================================================
do
    local lidStack
    for i = 1, 5 do
        local part = mkPart({
            Name = "LidDisc_" .. i,
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(0.18, 1.8, 1.8),
            CFrame = CFrame.new(28, COUNTER_TOP_Y + 0.18 + (i - 1) * 0.18, COUNTER_Z) * CFrame.Angles(0, 0, math.rad(90)),
            Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.SmoothPlastic,
        })
        if i == 1 then
            CollectionService:AddTag(part, "LidStation")
            lidStack = part
        end
    end
    addLabel(lidStack, "Lid Dispenser", "Press E to seal cup", ACCENT_GRAY)
    addPrompt(lidStack, "Lid Dispenser", "Seal Cup")
    local sign = mkPart({
        Name = "LidStationSign",
        Size = Vector3.new(2.2, 0.7, 0.2),
        CFrame = CFrame.new(28, COUNTER_TOP_Y + 0.2, COUNTER_FRONT_Z + 1.5),
        Color = ACCENT_GRAY, Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "LIDS", Enum.Font.GothamBlack, WHITE, ACCENT_GRAY)
end

-- ============================================================
-- SLEEVE STATION — side counter against right wall
-- ============================================================
do
    mkPart({
        Name = "SleeveCounter",
        Size = Vector3.new(2.5, 3, 2),
        CFrame = CFrame.new(BLD_W/2 - 2.5, FLOOR_TOP + 1.5, -12),
        Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.Wood,
    })
    local sleeve = mkPart({
        Name = "SleeveStation",
        Size = Vector3.new(1.5, 1.4, 1.5),
        CFrame = CFrame.new(BLD_W/2 - 2.5, FLOOR_TOP + 3.7, -12),
        Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Fabric,
        Tags = {"SleeveStation"},
    })
    addLabel(sleeve, "Sleeves", "Press E for cup sleeve", ACCENT_GRAY)
    addPrompt(sleeve, "Sleeves", "Add Sleeve")
    addSurfaceText(sleeve, Enum.NormalId.Front, "SLEEVES", Enum.Font.GothamBlack, CREAM, Color3.fromRGB(120, 80, 50))
end

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
    addLabel(trash, "Trash", "Press E to discard cup", ACCENT_RED)
    addPrompt(trash, "Trash", "Discard Cup")
    addSurfaceText(trash, Enum.NormalId.Front, "TRASH", Enum.Font.GothamBlack, WHITE, ACCENT_RED)
end

-- ============================================================
-- FLOOR ARROWS — chevrons in the player walking lane
-- showing the LEFT-TO-RIGHT workflow direction
-- ============================================================
do
    local arrowZ = -8     -- player walks in front of counter; arrows at z = -8
    local positions = {-22, -14, -6, 2, 10, 18, 25}
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

-- ============================================================
-- CHALKBOARD MENU on the back wall (above cup-towers area)
-- ============================================================
do
    local board = mkPart({
        Name = "ChalkboardMenu",
        Size = Vector3.new(10, 6, 0.4),
        CFrame = CFrame.new(-22, COUNTER_TOP_Y + 7, -BLD_D/2 + 1.5),
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

-- ============================================================
-- INTERIOR LIGHTING
-- ============================================================
do
    local positions = {
        Vector3.new(-18, FLOOR_TOP + BLD_H - 3, 0),
        Vector3.new(-6,  FLOOR_TOP + BLD_H - 3, 0),
        Vector3.new(6,   FLOOR_TOP + BLD_H - 3, 0),
        Vector3.new(18,  FLOOR_TOP + BLD_H - 3, 0),
        Vector3.new(-18, FLOOR_TOP + BLD_H - 3, -10),
        Vector3.new(0,   FLOOR_TOP + BLD_H - 3, -10),
        Vector3.new(18,  FLOOR_TOP + BLD_H - 3, -10),
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

-- ============================================================
-- SPAWN LOCATION (invisible, in front of cup-tower end)
-- Player faces +X so the workflow runs left-to-right ahead of them.
-- ============================================================
do
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "StandSpawn"
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Size = Vector3.new(4, 0.4, 4)
    spawn.CFrame = CFrame.new(-26, FLOOR_TOP + 0.2, -8) * CFrame.Angles(0, math.rad(-90), 0)
    spawn.Transparency = 1
    spawn.TopSurface = Enum.SurfaceType.Smooth
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Parent = stand
end

print("[BuildStand] Dutch Bros location constructed.")
script:Destroy()
