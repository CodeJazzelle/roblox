-- BuildStand.server.lua
-- Procedurally constructs a recognizable Dutch Bros drive-thru location:
-- corrugated-metal building, stone columns, drive-thru awning, signage,
-- parking lot with parked cars, sticker wall, full kitchen workflow.
--
-- Self-destructs at the end. Tags every interactive part so
-- StationInteraction.server.lua and HandoffWindow.server.lua can wire it up
-- via CollectionService:GetInstanceAddedSignal.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

-- ============================================================
-- Palette
-- ============================================================
local DUTCH_BLUE      = Color3.fromRGB(0,   90,  171)
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
-- Building geometry
-- ============================================================
local BLD_W       = 40
local BLD_D       = 30
local BLD_H       = 16
local FLOOR_Y     = 0
local FLOOR_TOP   = FLOOR_Y + 0.5
local WALL_THICK  = 1

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
    bb.Size = UDim2.new(0, 220, 0, 70)
    bb.StudsOffset = Vector3.new(0, 4.5, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 80
    bb.Parent = part

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = BLACK
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel = 0
    frame.Parent = bb
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 5)
    accent.BackgroundColor3 = accentColor or DUTCH_BLUE
    accent.BorderSizePixel = 0
    accent.Parent = frame
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(0, 12)
    accentCorner.Parent = accent

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -16, 0, 26)
    titleLbl.Position = UDim2.fromOffset(8, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 20
    titleLbl.TextColor3 = WHITE
    titleLbl.TextStrokeTransparency = 0.4
    titleLbl.TextStrokeColor3 = BLACK
    titleLbl.Parent = frame

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -16, 0, 22)
    subLbl.Position = UDim2.fromOffset(8, 38)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = subtitle
    subLbl.Font = Enum.Font.GothamSemibold
    subLbl.TextSize = 14
    subLbl.TextColor3 = DUTCH_YELLOW
    subLbl.Parent = frame
end

local RAINBOW_STRIPE = {
    Color3.fromRGB(220, 60, 60),    -- red
    Color3.fromRGB(255, 200, 50),   -- yellow
    Color3.fromRGB(255, 122, 0),    -- orange
    Color3.fromRGB(0,  90,  171),   -- blue
}

-- Drops 4 thin colored bars below `cframe` to make the Dutch Bros stripe band.
-- `width` controls horizontal extent; `axis` is "X" (front/back signs) or "Z" (side signs).
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

local function addSurfaceText(part, face, text, font, textColor, bgColor)
    local sg = Instance.new("SurfaceGui")
    sg.Face = face
    sg.LightInfluence = 0
    sg.PixelsPerStud = 50
    sg.Parent = part
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundColor3 = bgColor or BLACK
    lbl.Text = text
    lbl.Font = font or Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.TextColor3 = textColor or WHITE
    lbl.Parent = sg
    return lbl
end

-- ============================================================
-- Asphalt parking lot (large slab beneath everything)
-- ============================================================
mkPart({
    Name = "ParkingLot",
    Size = Vector3.new(140, 1, 100),
    CFrame = CFrame.new(0, FLOOR_Y - 0.5, 0),
    Color = ASPHALT,
    Material = Enum.Material.Asphalt,
})

-- Grass strip + curb on the west edge
mkPart({
    Name = "GrassStrip",
    Size = Vector3.new(8, 0.6, 100),
    CFrame = CFrame.new(-66, FLOOR_Y - 0.2, 0),
    Color = GRASS,
    Material = Enum.Material.Grass,
})
mkPart({
    Name = "Curb",
    Size = Vector3.new(0.6, 0.8, 100),
    CFrame = CFrame.new(-62, FLOOR_Y, 0),
    Color = CURB,
    Material = Enum.Material.Concrete,
})

-- Sidewalk strip in front of the building
mkPart({
    Name = "Sidewalk",
    Size = Vector3.new(BLD_W + 8, 0.4, 6),
    CFrame = CFrame.new(0, FLOOR_Y - 0.05, BLD_D/2 + 4),
    Color = SIDEWALK,
    Material = Enum.Material.Concrete,
})

-- Parking-lot stripes (front of building)
do
    local startX = -18
    local spacing = 6
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
-- Drive-thru lane along the east (right) side
-- ============================================================
do
    -- Lane asphalt slab (slightly raised so it reads as a lane vs the lot)
    mkPart({
        Name = "DriveThruLane",
        Size = Vector3.new(10, 0.06, 70),
        CFrame = CFrame.new(28, FLOOR_Y + 0.03, 0),
        Color = Color3.fromRGB(35, 35, 40),
        Material = Enum.Material.Asphalt,
        CanCollide = false,
    })
    -- Yellow center dashes
    for i = -4, 4 do
        mkPart({
            Name = "LaneDash_" .. i,
            Size = Vector3.new(0.3, 0.06, 3),
            CFrame = CFrame.new(28, FLOOR_Y + 0.07, i * 7),
            Color = DUTCH_YELLOW,
            Material = Enum.Material.SmoothPlastic,
            CanCollide = false,
        })
    end
    -- White lane edges
    mkPart({
        Name = "LaneEdgeLeft",
        Size = Vector3.new(0.25, 0.06, 70),
        CFrame = CFrame.new(23.2, FLOOR_Y + 0.07, 0),
        Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false,
    })
    mkPart({
        Name = "LaneEdgeRight",
        Size = Vector3.new(0.25, 0.06, 70),
        CFrame = CFrame.new(32.8, FLOOR_Y + 0.07, 0),
        Color = WHITE, Material = Enum.Material.SmoothPlastic, CanCollide = false,
    })
end

-- ============================================================
-- Parked cars in the drive-thru lane (4 of them, queued)
-- ============================================================
local function buildCar(x, z, bodyColor)
    mkPart({
        Name = "CarBody",
        Size = Vector3.new(4, 2, 8),
        CFrame = CFrame.new(x, FLOOR_Y + 1.4, z),
        Color = bodyColor,
        Material = Enum.Material.SmoothPlastic,
    })
    mkPart({
        Name = "CarCabin",
        Size = Vector3.new(3.6, 1.4, 4.5),
        CFrame = CFrame.new(x, FLOOR_Y + 3.1, z - 0.5),
        Color = bodyColor,
        Material = Enum.Material.SmoothPlastic,
    })
    mkPart({
        Name = "CarWindshield",
        Size = Vector3.new(3.4, 1.2, 0.2),
        CFrame = CFrame.new(x, FLOOR_Y + 3.1, z + 1.6),
        Color = Color3.fromRGB(120, 180, 220),
        Material = Enum.Material.Glass,
        Transparency = 0.4,
    })
    mkPart({
        Name = "CarRearWindow",
        Size = Vector3.new(3.4, 1.2, 0.2),
        CFrame = CFrame.new(x, FLOOR_Y + 3.1, z - 2.7),
        Color = Color3.fromRGB(120, 180, 220),
        Material = Enum.Material.Glass,
        Transparency = 0.4,
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
    for _, side in ipairs({-1, 1}) do
        mkPart({
            Name = "CarTailLight",
            Size = Vector3.new(0.6, 0.4, 0.2),
            CFrame = CFrame.new(x + side * 1.5, FLOOR_Y + 1.5, z - 3.95),
            Color = Color3.fromRGB(220, 30, 30),
            Material = Enum.Material.Neon,
        })
    end
end

buildCar(28,  20, Color3.fromRGB(60,  90,  200))   -- blue
buildCar(28,   6, Color3.fromRGB(220, 50,  50))    -- red
buildCar(28,  -8, Color3.fromRGB(60,  160, 80))    -- green
buildCar(28, -22, WHITE)                            -- white

-- ============================================================
-- Building floor (interior)
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
-- Back wall (full)
mkPart({
    Name = "BackWall",
    Size = Vector3.new(BLD_W, BLD_H, WALL_THICK),
    CFrame = CFrame.new(0, FLOOR_TOP + BLD_H/2, -BLD_D/2 + WALL_THICK/2),
    Color = METAL_BLUEGRAY,
    Material = Enum.Material.CorrugatedMetal,
})
-- Left wall (full)
mkPart({
    Name = "LeftWall",
    Size = Vector3.new(WALL_THICK, BLD_H, BLD_D),
    CFrame = CFrame.new(-BLD_W/2 + WALL_THICK/2, FLOOR_TOP + BLD_H/2, 0),
    Color = METAL_BLUEGRAY,
    Material = Enum.Material.CorrugatedMetal,
})

-- Front wall: walk-up window cutout at x ∈ [-14, -6], y ∈ [3, 8]
local FRONT_Z = BLD_D/2 - WALL_THICK/2
local WUW_X1, WUW_X2 = -14, -6
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

-- Right wall: drive-thru window cutout at z ∈ [-2, 8], y ∈ [3, 8]
local RIGHT_X = BLD_W/2 - WALL_THICK/2
local DTW_Z1, DTW_Z2 = -2, 8
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
-- Blue accent tower on the front-left (architectural feature from the
-- reference image — taller than the main roof, wraps around the corner)
-- ============================================================
local DARK_BLUE = Color3.fromRGB(35, 70, 130)
do
    -- Front face of the tower (covers leftmost ~5 studs of front wall, rises above roof)
    mkPart({
        Name = "BlueAccentTowerFront",
        Size = Vector3.new(5, BLD_H + 5, 0.4),
        CFrame = CFrame.new(-BLD_W/2 + 2.5, FLOOR_TOP + (BLD_H + 5)/2, BLD_D/2 + 0.3),
        Color = DARK_BLUE,
        Material = Enum.Material.CorrugatedMetal,
    })
    -- Left face of the tower (wraps around the corner so it reads as a 3D column)
    mkPart({
        Name = "BlueAccentTowerSide",
        Size = Vector3.new(0.4, BLD_H + 5, 5),
        CFrame = CFrame.new(-BLD_W/2 - 0.3, FLOOR_TOP + (BLD_H + 5)/2, BLD_D/2 - 2),
        Color = DARK_BLUE,
        Material = Enum.Material.CorrugatedMetal,
    })
    -- Top cap so the tower has a finished look at its peak
    mkPart({
        Name = "BlueAccentTowerCap",
        Size = Vector3.new(5.4, 0.4, 5.4),
        CFrame = CFrame.new(-BLD_W/2 + 2.3, FLOOR_TOP + BLD_H + 5, BLD_D/2 - 2),
        Color = Color3.fromRGB(60, 60, 70),
        Material = Enum.Material.Slate,
    })
end

-- ============================================================
-- Roof + Dutch Bros blue fascia trim
-- ============================================================
mkPart({
    Name = "Roof",
    Size = Vector3.new(BLD_W + 2, 1, BLD_D + 2),
    CFrame = CFrame.new(0, FLOOR_TOP + BLD_H + 0.5, 0),
    Color = Color3.fromRGB(50, 50, 60),
    Material = Enum.Material.Slate,
})
for _, fascia in ipairs({
    {n = "FasciaFront", size = Vector3.new(BLD_W + 2, 0.8, 0.4), pos = Vector3.new(0, FLOOR_TOP + BLD_H + 0.6, BLD_D/2 + 1)},
    {n = "FasciaBack",  size = Vector3.new(BLD_W + 2, 0.8, 0.4), pos = Vector3.new(0, FLOOR_TOP + BLD_H + 0.6, -BLD_D/2 - 1)},
    {n = "FasciaLeft",  size = Vector3.new(0.4, 0.8, BLD_D + 2), pos = Vector3.new(-BLD_W/2 - 1, FLOOR_TOP + BLD_H + 0.6, 0)},
    {n = "FasciaRight", size = Vector3.new(0.4, 0.8, BLD_D + 2), pos = Vector3.new(BLD_W/2 + 1, FLOOR_TOP + BLD_H + 0.6, 0)},
}) do
    mkPart({
        Name = fascia.n,
        Size = fascia.size,
        CFrame = CFrame.new(fascia.pos),
        Color = DUTCH_BLUE,
        Material = Enum.Material.SmoothPlastic,
    })
end

-- ============================================================
-- Stone pillars: front corners + drive-thru awning supports
-- ============================================================
local function pillar(x, z, height, name)
    mkPart({
        Name = name or "StonePillar",
        Size = Vector3.new(2.5, height, 2.5),
        CFrame = CFrame.new(x, FLOOR_TOP + height/2, z),
        Color = STONE_GRAY,
        Material = Enum.Material.Slate,
    })
end
pillar(-BLD_W/2 - 1, BLD_D/2 + 1, BLD_H + 1, "FrontLeftPillar")
pillar( BLD_W/2 + 1, BLD_D/2 + 1, BLD_H + 1, "FrontRightPillar")
pillar( BLD_W/2 + 8,  8, BLD_H - 4, "AwningPillarFront")
pillar( BLD_W/2 + 8, -2, BLD_H - 4, "AwningPillarBack")

-- ============================================================
-- Front awning across the walk-up entrance (matches reference image)
-- Sits below the rainbow stripe band so it reads as the underside trim.
-- ============================================================
do
    local awningY = FLOOR_TOP + BLD_H - 7
    mkPart({
        Name = "FrontAwning",
        Size = Vector3.new(BLD_W + 4, 0.6, 5),
        CFrame = CFrame.new(0, awningY, BLD_D/2 + 2),
        Color = DUTCH_BLUE,
        Material = Enum.Material.SmoothPlastic,
    })
    -- Two extra stone pillars holding up the front awning (matches the image)
    pillar(-10, BLD_D/2 + 4, BLD_H - 7, "FrontAwningPillar_L")
    pillar( 14, BLD_D/2 + 4, BLD_H - 7, "FrontAwningPillar_R")
end

-- ============================================================
-- Drive-thru awning (extends out from right side)
-- ============================================================
do
    local awningY = FLOOR_TOP + BLD_H - 4
    mkPart({
        Name = "DriveThruAwning",
        Size = Vector3.new(10, 0.6, 14),
        CFrame = CFrame.new(BLD_W/2 + 4, awningY, 3),
        Color = DUTCH_BLUE,
        Material = Enum.Material.SmoothPlastic,
    })
    -- Underside stripes (alternating orange/white) for that classic awning look
    for i = 1, 6 do
        mkPart({
            Name = "AwningStripe_" .. i,
            Size = Vector3.new(10, 0.05, 2),
            CFrame = CFrame.new(BLD_W/2 + 4, awningY - 0.4, 3 - 7 + (i - 0.5) * (14/6)),
            Color = (i % 2 == 0) and DUTCH_ORANGE or WHITE,
            Material = Enum.Material.SmoothPlastic,
            CanCollide = false,
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
            Color = DUTCH_YELLOW,
            Material = Enum.Material.Neon,
            CanCollide = false,
        })
        local pl = Instance.new("PointLight")
        pl.Color = DUTCH_YELLOW
        pl.Brightness = 1.5
        pl.Range = 8
        pl.Parent = lp
    end
    mkPart({
        Name = "StringLightWire",
        Size = Vector3.new(9, 0.05, 0.05),
        CFrame = CFrame.new(BLD_W/2 + 5, lightY + 0.4, 10),
        Color = BLACK,
        Material = Enum.Material.SmoothPlastic,
        CanCollide = false,
    })
end

-- ============================================================
-- Front DUTCH BROS sign (positioned on the gray section to the right of the
-- blue accent tower, with the rainbow stripe band underneath)
-- ============================================================
do
    local sign = mkPart({
        Name = "FrontDutchBrosSign",
        Size = Vector3.new(22, 4.5, 0.4),
        CFrame = CFrame.new(4, FLOOR_TOP + BLD_H - 3, BLD_D/2 + 0.5),
        Color = DUTCH_BLUE,
        Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "DUTCH BROS Coffee", Enum.Font.GothamBlack, DUTCH_YELLOW, DUTCH_BLUE)
    addStripeBand("FrontSignStripe", CFrame.new(4, FLOOR_TOP + BLD_H - 5.6, BLD_D/2 + 0.6), 22, "X")
    -- Spotlight illuminating the sign
    local spotPart = mkPart({
        Name = "FrontSignSpotlight",
        Size = Vector3.new(0.4, 0.4, 0.4),
        CFrame = CFrame.new(0, FLOOR_TOP + BLD_H + 2, BLD_D/2 + 5),
        Transparency = 1, CanCollide = false,
    })
    local spot = Instance.new("SpotLight")
    spot.Color = WHITE
    spot.Brightness = 5
    spot.Range = 24
    spot.Angle = 90
    spot.Face = Enum.NormalId.Bottom
    spot.Parent = spotPart
end

-- Side "DUTCH BROS Coffee" sign visible from drive-thru
do
    local sign = mkPart({
        Name = "SideDutchBrosSign",
        Size = Vector3.new(0.4, 4, 16),
        CFrame = CFrame.new(BLD_W/2 + 0.5, FLOOR_TOP + BLD_H - 3, -3),
        Color = WHITE,
        Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Right, "DUTCH BROS Coffee", Enum.Font.GothamBlack, DUTCH_BLUE, WHITE)
    addStripeBand("SideSignStripe", CFrame.new(BLD_W/2 + 0.6, FLOOR_TOP + BLD_H - 5.5, -3), 16, "Z")
    local spotPart = mkPart({
        Name = "SideSignSpotlight",
        Size = Vector3.new(0.4, 0.4, 0.4),
        CFrame = CFrame.new(BLD_W/2 + 5, FLOOR_TOP + BLD_H + 2, -3),
        Transparency = 1, CanCollide = false,
    })
    local spot = Instance.new("SpotLight")
    spot.Color = WHITE
    spot.Brightness = 4
    spot.Range = 18
    spot.Angle = 90
    spot.Face = Enum.NormalId.Bottom
    spot.Parent = spotPart
end

-- WELCOME BACK BESTIE band above the walk-up window
do
    local welcomeBand = mkPart({
        Name = "WalkUpWelcome",
        Size = Vector3.new(WUW_X2 - WUW_X1, 1, 0.2),
        CFrame = CFrame.new((WUW_X1 + WUW_X2)/2, FLOOR_TOP + WUW_Y2 + 0.6, BLD_D/2 + 0.6),
        Color = DUTCH_BLUE,
        Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(welcomeBand, Enum.NormalId.Front, "WELCOME BACK BESTIE", Enum.Font.GothamBlack, DUTCH_YELLOW, DUTCH_BLUE)
end

-- EXIT ONLY sign post at the south end of the drive-thru lane
do
    mkPart({
        Name = "ExitOnlyPost",
        Size = Vector3.new(0.4, 6, 0.4),
        CFrame = CFrame.new(BLD_W/2 + 4, FLOOR_TOP + 3, -BLD_D/2 - 4),
        Color = STONE_GRAY,
        Material = Enum.Material.Metal,
    })
    local sign = mkPart({
        Name = "ExitOnlySign",
        Size = Vector3.new(4, 2, 0.2),
        CFrame = CFrame.new(BLD_W/2 + 4, FLOOR_TOP + 5, -BLD_D/2 - 4),
        Color = ACCENT_RED,
        Material = Enum.Material.SmoothPlastic,
    })
    addSurfaceText(sign, Enum.NormalId.Front, "EXIT ONLY", Enum.Font.GothamBlack, WHITE, ACCENT_RED)
    addSurfaceText(sign, Enum.NormalId.Back,  "EXIT ONLY", Enum.Font.GothamBlack, WHITE, ACCENT_RED)
end

-- Walk-up window counter (sticks out front-left)
mkPart({
    Name = "WalkUpCounter",
    Size = Vector3.new(WUW_X2 - WUW_X1, 0.4, 2),
    CFrame = CFrame.new((WUW_X1 + WUW_X2)/2, FLOOR_TOP + WUW_Y1 - 0.2, BLD_D/2 + 1),
    Color = CREAM,
    Material = Enum.Material.Marble,
})

-- ============================================================
-- Drive-thru hand-off counter (interior side, tagged HandoffWindow)
-- This is what the player triggers to submit a drink.
-- ============================================================
do
    local handoff = mkPart({
        Name = "DriveThruHandoff",
        Size = Vector3.new(2.5, 3, DTW_Z2 - DTW_Z1),
        CFrame = CFrame.new(BLD_W/2 - 1.5, FLOOR_TOP + 1.5, (DTW_Z1 + DTW_Z2)/2),
        Color = CREAM,
        Material = Enum.Material.Marble,
        Tags = {"HandoffWindow"},
    })
    addLabel(handoff, "Hand-Off Window", "Press E to deliver drink", DUTCH_ORANGE)
end

-- ============================================================
-- Back counter where the kitchen stations sit
-- ============================================================
local COUNTER_Z = -BLD_D/2 + 4
local COUNTER_TOP_Y = FLOOR_TOP + 3

mkPart({
    Name = "BackCounterBody",
    Size = Vector3.new(BLD_W - 4, 3, 3),
    CFrame = CFrame.new(0, FLOOR_TOP + 1.5, COUNTER_Z),
    Color = Color3.fromRGB(70, 50, 35),
    Material = Enum.Material.Wood,
})
mkPart({
    Name = "BackCounterTop",
    Size = Vector3.new(BLD_W - 3.5, 0.2, 3.4),
    CFrame = CFrame.new(0, COUNTER_TOP_Y, COUNTER_Z),
    Color = CREAM,
    Material = Enum.Material.Marble,
})

local function counterStation(opts)
    local size = opts.size or Vector3.new(2.5, 3, 2.5)
    local part = mkPart({
        Name = opts.name,
        Size = size,
        CFrame = CFrame.new(opts.x, COUNTER_TOP_Y + size.Y/2, opts.z or COUNTER_Z),
        Color = opts.color or DUTCH_BLUE,
        Material = opts.material or Enum.Material.Metal,
        Tags = opts.tags,
        Attributes = opts.attributes,
    })
    addLabel(part, opts.title, opts.subtitle, opts.labelColor or DUTCH_BLUE)
    return part
end

-- ============================================================
-- Cup towers (FAR LEFT)
-- ============================================================
counterStation({
    name = "CupTowerSmall",  x = -17,
    size = Vector3.new(2,   4, 2),    color = WHITE, material = Enum.Material.Plastic,
    tags = {"CupTower_Small"},
    title = "Small Cups",  subtitle = "Press E to grab cup",
    labelColor = DUTCH_BLUE,
})
counterStation({
    name = "CupTowerMedium", x = -14,
    size = Vector3.new(2.4, 5, 2.4),  color = WHITE, material = Enum.Material.Plastic,
    tags = {"CupTower_Medium"},
    title = "Medium Cups", subtitle = "Press E to grab cup",
    labelColor = DUTCH_BLUE,
})
counterStation({
    name = "CupTowerLarge",  x = -11,
    size = Vector3.new(2.8, 6, 2.8),  color = WHITE, material = Enum.Material.Plastic,
    tags = {"CupTower_Large"},
    title = "Large Cups",  subtitle = "Press E to grab cup",
    labelColor = DUTCH_BLUE,
})

-- ============================================================
-- Base machines (LEFT-CENTER)
-- ============================================================
counterStation({
    name = "EspressoMachine",   x = -7,
    size = Vector3.new(3, 3.5, 2.5),
    color = Color3.fromRGB(60, 60, 70), material = Enum.Material.Metal,
    tags = {"EspressoMachine"},
    title = "Espresso Machine", subtitle = "Press E to pull shots",
    labelColor = DUTCH_BLUE,
})
counterStation({
    name = "RebelTap",          x = -3.5,
    size = Vector3.new(2, 4, 2),
    color = Color3.fromRGB(0, 130, 220), material = Enum.Material.Neon,
    tags = {"RebelTap"},
    title = "Blue Rebel Tap",   subtitle = "Press E to fill",
    labelColor = DUTCH_BLUE,
})
counterStation({
    name = "TeaBrewer",         x = -0.5,
    size = Vector3.new(2.5, 3, 2.5),
    color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Metal,
    tags = {"TeaBrewer"},
    title = "Tea Brewer",       subtitle = "Press E to brew",
    labelColor = DUTCH_BLUE,
})
counterStation({
    name = "LemonadeDispenser", x = 2.5,
    size = Vector3.new(2.5, 4, 2.5),
    color = Color3.fromRGB(255, 230, 80), material = Enum.Material.SmoothPlastic,
    tags = {"LemonadeDispenser"},
    title = "Lemonade",         subtitle = "Press E to pour",
    labelColor = DUTCH_BLUE,
})
counterStation({
    name = "MilkSteamer",       x = 5.5,
    size = Vector3.new(2, 3.5, 2),
    color = WHITE, material = Enum.Material.Metal,
    tags = {"MilkSteamer"},
    title = "Milk Steamer",     subtitle = "Press E to steam",
    labelColor = DUTCH_BLUE,
})

-- ============================================================
-- Syrup wall (CENTER) — wall-mounted rack with 12 pumps in 2 rows of 6
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
    local rackX = 9
    local rackZ = -BLD_D/2 + 1.5
    local rackY = COUNTER_TOP_Y + 4
    local rackW = 12
    local rackH = 5
    mkPart({
        Name = "SyrupRackBoard",
        Size = Vector3.new(rackW, rackH, 0.4),
        CFrame = CFrame.new(rackX, rackY, rackZ),
        Color = Color3.fromRGB(50, 35, 20),
        Material = Enum.Material.Wood,
    })
    for r = 1, 2 do
        mkPart({
            Name = "SyrupShelf_" .. r,
            Size = Vector3.new(rackW, 0.3, 0.8),
            CFrame = CFrame.new(rackX, rackY - rackH/2 + (r - 0.5) * (rackH/2), rackZ + 0.6),
            Color = Color3.fromRGB(40, 28, 16),
            Material = Enum.Material.Wood,
        })
    end
    -- Header label
    local headerAnchor = mkPart({
        Name = "SyrupRackHeader",
        Size = Vector3.new(0.2, 0.2, 0.2),
        CFrame = CFrame.new(rackX, rackY + rackH/2 + 1, rackZ),
        Transparency = 1, CanCollide = false,
    })
    addLabel(headerAnchor, "Syrup Wall", "Press E on a bottle to add", ACCENT_PINK)

    local cols = 6
    local spacing = rackW / cols
    for i, syrup in ipairs(SYRUPS) do
        local row = math.floor((i - 1) / cols) + 1
        local col = ((i - 1) % cols) + 1
        local bx = rackX - rackW/2 + (col - 0.5) * spacing
        local by = rackY - rackH/2 + (row - 0.5) * (rackH/2)
        local bz = rackZ + 0.9
        local bottle = mkPart({
            Name = "SyrupBottle_" .. syrup.name:gsub("%s+", ""),
            Size = Vector3.new(0.8, 1.6, 0.8),
            CFrame = CFrame.new(bx, by, bz),
            Color = syrup.color,
            Material = Enum.Material.Glass,
            Tags = {"SyrupPump"},
            Attributes = {SyrupName = syrup.name},
        })
        local bb = Instance.new("BillboardGui")
        bb.Adornee = bottle
        bb.Size = UDim2.new(0, 90, 0, 22)
        bb.StudsOffset = Vector3.new(0, 1.4, 0)
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.MaxDistance = 30
        bb.Parent = bottle
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundColor3 = BLACK
        lbl.BackgroundTransparency = 0.3
        lbl.Text = syrup.name
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextScaled = true
        lbl.TextColor3 = WHITE
        lbl.Parent = bb
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = lbl
    end
end

-- ============================================================
-- Topping stations (RIGHT-CENTER) + drizzle station
-- ============================================================
counterStation({
    name = "ToppingWhippedCream", x = 8,
    size = Vector3.new(1.8, 2.4, 1.8),
    color = WHITE, material = Enum.Material.SmoothPlastic,
    tags = {"ToppingStation"}, attributes = {ToppingName = "Whipped Cream"},
    title = "Whipped Cream", subtitle = "Press E to add",
    labelColor = ACCENT_GREEN,
})
counterStation({
    name = "ToppingBoba",         x = 10.5,
    size = Vector3.new(1.8, 2.4, 1.8),
    color = Color3.fromRGB(50, 30, 25), material = Enum.Material.SmoothPlastic,
    tags = {"ToppingStation"}, attributes = {ToppingName = "Boba"},
    title = "Boba",          subtitle = "Press E to add",
    labelColor = ACCENT_GREEN,
})
counterStation({
    name = "ToppingSoftTop",      x = 13,
    size = Vector3.new(1.8, 2.4, 1.8),
    color = Color3.fromRGB(245, 240, 230), material = Enum.Material.SmoothPlastic,
    tags = {"ToppingStation"}, attributes = {ToppingName = "Soft Top"},
    title = "Soft Top",      subtitle = "Press E to add",
    labelColor = ACCENT_GREEN,
})
counterStation({
    name = "DrizzleStation",      x = 15.5,
    size = Vector3.new(1.8, 2.4, 1.8),
    color = Color3.fromRGB(190, 120, 50), material = Enum.Material.SmoothPlastic,
    tags = {"ToppingStation"}, attributes = {ToppingName = "Caramel Drizzle"},
    title = "Drizzle",       subtitle = "Press E to add",
    labelColor = ACCENT_GREEN,
})

-- ============================================================
-- Lid + sleeve stations (FAR RIGHT)
-- ============================================================
counterStation({
    name = "LidStation", x = 18,
    size = Vector3.new(1.5, 1.6, 1.5),
    color = Color3.fromRGB(40, 40, 50), material = Enum.Material.SmoothPlastic,
    tags = {"LidStation"},
    title = "Lid Dispenser", subtitle = "Press E to seal cup",
    labelColor = ACCENT_GRAY,
})
do
    -- Sleeve station sits on a side counter against the right wall
    mkPart({
        Name = "SleeveCounter",
        Size = Vector3.new(2.5, 3, 2),
        CFrame = CFrame.new(BLD_W/2 - 2.5, FLOOR_TOP + 1.5, -10),
        Color = Color3.fromRGB(70, 50, 35),
        Material = Enum.Material.Wood,
    })
    local sleeve = mkPart({
        Name = "SleeveStation",
        Size = Vector3.new(1.5, 1.4, 1.5),
        CFrame = CFrame.new(BLD_W/2 - 2.5, FLOOR_TOP + 3.7, -10),
        Color = Color3.fromRGB(120, 80, 50),
        Material = Enum.Material.Fabric,
        Tags = {"SleeveStation"},
    })
    addLabel(sleeve, "Sleeves", "Press E for cup sleeve", ACCENT_GRAY)
end

-- ============================================================
-- Trash can
-- ============================================================
do
    local trash = mkPart({
        Name = "TrashCan",
        Size = Vector3.new(2, 3, 2),
        CFrame = CFrame.new(-BLD_W/2 + 3, FLOOR_TOP + 1.5, BLD_D/2 - 4),
        Color = Color3.fromRGB(50, 50, 55),
        Material = Enum.Material.Metal,
        Tags = {"TrashCan"},
    })
    addLabel(trash, "Trash", "Press E to discard cup", ACCENT_RED)
end

-- ============================================================
-- Chalkboard menu on the back interior wall (above the cup-towers area)
-- ============================================================
do
    local board = mkPart({
        Name = "ChalkboardMenu",
        Size = Vector3.new(10, 6, 0.4),
        CFrame = CFrame.new(-13, COUNTER_TOP_Y + 6, -BLD_D/2 + 1.5),
        Color = CHALK_GREEN,
        Material = Enum.Material.Slate,
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
-- Sticker wall on left interior wall (22 random stickers)
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
        for i = 1, 22 do
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
            stroke.Color = WHITE
            stroke.Thickness = 2
            stroke.Parent = sticker
        end
    end
end

-- ============================================================
-- Interior PointLights (blue-tinted)
-- ============================================================
do
    local LIGHT_POSITIONS = {
        Vector3.new(-12, FLOOR_TOP + BLD_H - 3, 0),
        Vector3.new(0,   FLOOR_TOP + BLD_H - 3, 0),
        Vector3.new(12,  FLOOR_TOP + BLD_H - 3, 0),
        Vector3.new(-12, FLOOR_TOP + BLD_H - 3, -8),
        Vector3.new(12,  FLOOR_TOP + BLD_H - 3, -8),
    }
    for i, pos in ipairs(LIGHT_POSITIONS) do
        local lp = mkPart({
            Name = "InteriorLight_" .. i,
            Size = Vector3.new(0.8, 0.3, 0.8),
            CFrame = CFrame.new(pos),
            Color = Color3.fromRGB(220, 240, 255),
            Material = Enum.Material.Neon,
            CanCollide = false,
        })
        local pl = Instance.new("PointLight")
        pl.Color = Color3.fromRGB(180, 210, 255)
        pl.Brightness = 2
        pl.Range = 16
        pl.Parent = lp
    end
end

-- ============================================================
-- Spawn location (invisible, at the cup-tower end)
-- Player spawns facing +X so the workflow runs left-to-right ahead of them.
-- ============================================================
do
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "StandSpawn"
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Size = Vector3.new(4, 0.4, 4)
    -- CFrame.Angles(0, -90deg, 0) rotates the SpawnLocation so its LookVector
    -- (originally -Z) points in +X — i.e. the player faces the workflow.
    spawn.CFrame = CFrame.new(-15, FLOOR_TOP + 0.2, 6) * CFrame.Angles(0, math.rad(-90), 0)
    spawn.Transparency = 1
    spawn.TopSurface = Enum.SurfaceType.Smooth
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Parent = stand
end

print("[BuildStand] Dutch Bros location constructed.")
script:Destroy()
