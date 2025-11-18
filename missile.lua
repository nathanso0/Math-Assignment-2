-- missile.lua
local Missile = {}
Missile.__index = Missile

function Missile.new(x,y, dir, opts)
    local self = setmetatable({}, Missile)
    self.x, self.y = x, y
    self.dir = {x = dir.x, y = dir.y}
    local len = math.sqrt(self.dir.x*self.dir.x + self.dir.y*self.dir.y)
    if len == 0 then self.dir.x, self.dir.y = 1,0 end
    self.isHoming = opts.isHoming or false
    self.target = opts.target or nil -- {x,y, object}
    self.speed = opts.speed or 220
    self.acc = opts.acc or 600
    self.maxSpeed = opts.maxSpeed or 600
    self.w, self.h = 10, 6 -- rectangle base
    self.ttl = opts.ttl or 5
    self.dead = false
    return self
end

function Missile:update(dt, level, enemies)
    if self.isHoming and self.target then
        -- if target has moving object, update position to object's current center
        local tx, ty = self.target.x, self.target.y
        if self.target.object and self.target.object.x then
            tx, ty = self.target.object.x, self.target.object.y
        end
        local toTx, toTy = tx - self.x, ty - self.y
        local dist = math.sqrt(toTx*toTx + toTy*toTy)
        if dist > 1 then
            -- desired direction
            local ndx, ndy = toTx/dist, toTy/dist
            -- accelerate direction toward target (simple steering)
            self.dir.x = self.dir.x + ndx * dt * 4 -- steering factor
            self.dir.y = self.dir.y + ndy * dt * 4
            local len = math.sqrt(self.dir.x*self.dir.x + self.dir.y*self.dir.y)
            self.dir.x, self.dir.y = self.dir.x/len, self.dir.y/len
        end
    end

    -- accelerate speed
    self.speed = math.min(self.speed + self.acc * dt, self.maxSpeed)
    -- move
    self.x = self.x + self.dir.x * self.speed * dt
    self.y = self.y + self.dir.y * self.speed * dt

    -- handle TTL
    self.ttl = self.ttl - dt
    if self.ttl <= 0 then self.dead = true end

    -- TODO: collision with level/enemies -> explode (set dead)
    -- For assignment: detect collision against level polygons or enemy poly
    for _, poly in ipairs(level.polygons) do
        -- approximate missile as a point
        if require("sat").pointInPoly(self.x, self.y, poly) then
            self.dead = true
            return
        end
    end
    for _, e in ipairs(enemies) do
        if e.poly and require("sat").pointInPoly(self.x, self.y, e.poly) then
            self.dead = true
            e:onHit()
            return
        end
    end
end

function Missile:draw()
    -- draw rectangle base and triangle tip based on direction
    local angle = math.atan2(self.dir.y, self.dir.x)
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(angle)
    -- rectangle centered slightly back
    love.graphics.rectangle("fill", -self.w/2, -self.h/2, self.w, self.h)
    -- triangle tip in front
    love.graphics.polygon("fill", self.w/2, -self.h/2, self.w/2, self.h/2, self.w/2 + 8, 0)
    love.graphics.pop()
end

return Missile
