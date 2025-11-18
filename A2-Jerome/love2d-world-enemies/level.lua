local M = {}

M.width = 1400
M.height = 600

M.platforms = {}

function M.init()
    M.platforms = {
        {0,   520, 1400, 80},    -- ground

        
        -- TWO ascent platforms (player jumps: right then left to reach top)
        {500, 435, 120, 16},     -- ascent platform 1 (right)
        {375, 355, 120, 16},     -- ascent platform 2 (left)

        -- top long platform (enemy 2)
        {515, 275, 385, 16},

        -- TWO descent platforms
        {900, 355, 120, 16},     -- descent 1
        {775, 435, 120, 16},     -- descent 2

        {700, 300, 20, 250}, -- wall

    }
end

function M.draw()
    love.graphics.setColor(0.25, 0.25, 0.3)
    for _, p in ipairs(M.platforms) do
        love.graphics.rectangle("fill", p[1], p[2], p[3], p[4])
    end
    love.graphics.setColor(1,1,1)
end

function M.isSolidAt(x, y)
    for _, p in ipairs(M.platforms) do
        if x >= p[1] and x <= p[1] + p[3] and y >= p[2] and y <= p[2] + p[4] then
            return true
        end
    end
    return false
end

function M.getGroundBelow(x, yStart, maxDrop)
    local bestY = nil
    maxDrop = maxDrop or 240
    for _, p in ipairs(M.platforms) do
        if x >= p[1] and x <= p[1] + p[3] then
            local topY = p[2]
            if topY >= yStart and topY <= yStart + maxDrop then
                if not bestY or topY < bestY then bestY = topY end
            end
        end
    end
    return bestY
end

local function segInter(ax,ay,bx,by, cx,cy,dx,dy)
    local s1x, s1y = bx-ax, by-ay
    local s2x, s2y = dx-cx, dy-cy
    local denom = (-s2x * s1y + s1x * s2y)
    if math.abs(denom) < 1e-9 then return nil end
    local s = (-s1y * (ax-cx) + s1x * (ay-cy)) / denom
    local t = ( s2x * (ay-cy) - s2y * (ax-cx)) / denom
    if s >= 0 and s <= 1 and t >= 0 and t <= 1 then
        return ax + (t * s1x), ay + (t * s1y)
    end
    return nil
end

function M.raycast(x1,y1,x2,y2)
    local nearest = nil
    local bestd = math.huge
    for _, p in ipairs(M.platforms) do
        local x, y, w, h = p[1], p[2], p[3], p[4]
        local edges = {
            {x, y, x+w, y},
            {x+w, y, x+w, y+h},
            {x+w, y+h, x, y+h},
            {x, y+h, x, y},
        }
        for _, e in ipairs(edges) do
            local hx, hy = segInter(x1,y1,x2,y2, e[1],e[2], e[3],e[4])
            if hx then
                local d = (hx - x1)^2 + (hy - y1)^2
                if d < bestd then bestd = d; nearest = {x = hx, y = hy} end
            end
        end
    end
    return nearest
end

return M