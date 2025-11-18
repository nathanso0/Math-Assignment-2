-- missile.lua
local SAT = require("sat")

local Missile = {}
Missile.__index = Missile

function Missile.new(x, y, dir, opts)
    local self = setmetatable({}, Missile)
    self.x, self.y = x, y
    self.dir = {x = dir.x, y = dir.y}

    -- normalize
    local len = math.sqrt(self.dir.x^2 + self.dir.y^2)
    if len == 0 then
        self.dir.x, self.dir.y = 1, 0
    else
        self.dir.x, self.dir.y = self.dir.x / len, self.dir.y / len
    end

    self.isHoming = opts.isHoming or false
    self.target = opts.target or nil -- {x, y, object}
    self.speed = opts.speed or 220
    self.acc = opts.acc or 600
    self.maxSpeed = opts.maxSpeed or 600

    self.w, self.h = 10, 6
    self.ttl = opts.ttl or 5
    self.dead = false
    return self
end

function Missile:update(dt, level, enemies)
    -- HOMING STEERING
    if self.isHoming and self.target then
        local tx, ty = self.target.x, self.target.y
        if self.target.object and self.target.object.x then
            tx, ty = self.target.object.x, self.target.object.y
        end
        local dx, dy = tx - self.x, ty - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 1 then
            -- steering factor
            local ndx, ndy = dx/dist, dy/dist
            self.dir.x = self.dir.x + ndx * dt * 4
            self.dir.y = self.dir.y + ndy * dt * 4
            local len = math.sqrt(self.dir.x^2 + self.dir.y^2)
            self.dir.x, self.dir.y = self.dir.x / len, self.dir.y / len
        end
    end

    -- SPEED AND MOVEMENT
    self.speed = math.min(self.speed + self.acc * dt, self.maxSpeed)
    self.x = self.x + self.dir.x * self.speed * dt
    self.y = self.y + self.dir.y * self.speed * dt

    -- TTL
    self.ttl = self.ttl - dt
    if self.ttl <= 0 then self.dead = true end

    -- COLLISION
    for _, poly in ipairs(level.polygons) do
        if SAT.pointInPoly(self.x, self.y, poly) then
            self.dead = true
            return
        end
    end

    for _, e in ipairs(enemies) do
        if e.poly and SAT.pointInPoly(self.x, self.y, e.poly) then
            self.dead = true
            if e.onHit then e:onHit() end
            return
        end
    end
end

function Missile:draw()
    local angle = math.atan2(self.dir.y, self.dir.x)
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(angle)
    -- rectangle
    love.graphics.rectangle("fill", -self.w/2, -self.h/2, self.w, self.h)
    -- triangle tip
    love.graphics.polygon("fill", self.w/2, -self.h/2, self.w/2, self.h/2, self.w/2 + 8, 0)
    love.graphics.pop()
end

return Missile
