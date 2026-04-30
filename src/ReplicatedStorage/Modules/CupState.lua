-- CupState.lua
-- Represents the in-progress contents of a cup. Server-authoritative.

local CupState = {}
CupState.__index = CupState

function CupState.new(size)
    local self = setmetatable({}, CupState)
    self.size = size or "Medium"
    self.base = nil
    self.syrups = {}
    self.toppings = {}
    self.hasLid = false
    self.hasSleeve = false
    self.extraShots = 0
    return self
end

function CupState:SetBase(baseName)
    if self.base then return false, "Cup already has a base" end
    self.base = baseName
    return true
end

function CupState:AddSyrup(syrupName)
    if #self.syrups >= 6 then return false, "Too many syrups" end
    table.insert(self.syrups, syrupName)
    return true
end

function CupState:AddTopping(toppingName)
    table.insert(self.toppings, toppingName)
    return true
end

function CupState:AddShot()
    self.extraShots = self.extraShots + 1
end

function CupState:ApplyLid()
    if not self.base then return false, "Need base first" end
    self.hasLid = true
    return true
end

function CupState:ApplySleeve()
    self.hasSleeve = true
    return true
end

function CupState:MatchesRecipe(recipe, requiredSize)
    if requiredSize and self.size ~= requiredSize then
        return false, 0, "Wrong size"
    end
    if self.base ~= recipe.base then
        return false, 0, "Wrong base"
    end

    local function tally(list)
        local t = {}
        for _, item in ipairs(list) do
            t[item] = (t[item] or 0) + 1
        end
        return t
    end

    local cupSyrups = tally(self.syrups)
    local recipeSyrups = tally(recipe.syrups)
    for syrup, count in pairs(recipeSyrups) do
        if cupSyrups[syrup] ~= count then
            return false, 0.5, "Syrup mismatch: " .. syrup
        end
    end
    for syrup, count in pairs(cupSyrups) do
        if recipeSyrups[syrup] ~= count then
            return false, 0.5, "Extra syrup: " .. syrup
        end
    end

    local cupToppings = tally(self.toppings)
    local recipeToppings = tally(recipe.toppings)
    for topping, count in pairs(recipeToppings) do
        if cupToppings[topping] ~= count then
            return false, 0.7, "Missing topping: " .. topping
        end
    end

    if not self.hasLid then
        return false, 0.9, "No lid"
    end

    return true, 1.0, "Perfect"
end

function CupState:Serialize()
    return {
        size = self.size,
        base = self.base,
        syrups = self.syrups,
        toppings = self.toppings,
        hasLid = self.hasLid,
        hasSleeve = self.hasSleeve,
        extraShots = self.extraShots,
    }
end

return CupState
