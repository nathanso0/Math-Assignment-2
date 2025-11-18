-- sat.lua
local SAT = {}

-- project polygon on axis (axis normalized)
local function project(poly, axis)
    local min, max
    for i=1,#poly do
        local p = poly[i]
        local proj = p.x * axis.x + p.y * axis.y
        if not min or proj < min then min = proj end
        if not max or proj > max then max = proj end
    end
    return min, max
end

local function overlap(aMin,aMax,bMin,bMax)
    return math.min(aMax,bMax) - math.max(aMin,bMin)
end

-- Get axes (normals) for polygon edges
local function getAxes(poly)
    local axes = {}
    for i=1,#poly do
        local p1 = poly[i]
        local p2 = poly[i % #poly + 1]
        local edge = { x = p2.x - p1.x, y = p2.y - p1.y }
        -- normal (perp)
        local axis = { x = -edge.y, y = edge.x }
        local len = math.sqrt(axis.x*axis.x + axis.y*axis.y)
        if len > 0 then axis.x, axis.y = axis.x/len, axis.y/len end
        table.insert(axes, axis)
    end
    return axes
end

-- polygon vs polygon SAT test
function SAT.polygonsCollide(polyA, polyB)
    local minOverlap = math.huge
    local smallestAxis = {x=0,y=0}

    local axesA = getAxes(polyA)
    local axesB = getAxes(polyB)

    for _, axis in ipairs(axesA) do
        local aMin,aMax = project(polyA, axis)
        local bMin,bMax = project(polyB, axis)
        local o = overlap(aMin,aMax,bMin,bMax)
        if o <= 0 then return false, nil end
        if o < minOverlap then minOverlap = o; smallestAxis = axis end
    end
    for _, axis in ipairs(axesB) do
        local aMin,aMax = project(polyA, axis)
        local bMin,bMax = project(polyB, axis)
        local o = overlap(aMin,aMax,bMin,bMax)
        if o <= 0 then return false, nil end
        if o < minOverlap then minOverlap = o; smallestAxis = axis end
    end
    return true, {axis=smallestAxis, overlap=minOverlap}
end

-- point-in-poly (ray crossing)
function SAT.pointInPoly(px, py, poly)
    local inside = false
    local j = #poly
    for i=1,#poly do
        local xi, yi = poly[i].x, poly[i].y
        local xj, yj = poly[j].x, poly[j].y
        local intersect = ((yi > py) ~= (yj > py)) and
            (px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi)
        if intersect then inside = not inside end
        j = i
    end
    return inside
end

return SAT
