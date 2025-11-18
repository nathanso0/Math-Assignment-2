-- player.lua
local SAT = require("sat")
local Missile = require("missile")

local Player = {}
Player.__index = Player

function Player.new(x,y, spritesheet)
    local self = setmetatable({}, Player)
    self.x, self.y = x or 100, y or 300
    self.w, self.h = 24, 36
    -- physics
    self.vx, self.vy = 0, 0
    self.ax = 0
    self.gravity = 1200
    self.moveSpeed = 240
    self.maxSpeedX = 300
    self.friction = 10
    self.jumpImpulse = -420
    self.maxFall = 1000
    -- jump tuner (short hops if release)
    self.jumpHoldTime = 0.18
    self.jumpTimer = 0
    self.isGrounded = false
    -- dash
    self.canDash = true
    self.dashCooldown = 2.0
    self.dashTimer = 0
    self.isDashing = false
    self.dashDuration = 0.18
    self.dashTimeLeft = 0
    self.dashSpeed = 800
    self.facing = {x=1,y=0}
    -- bullets & missiles
    self.projectiles = {}
    self.missileTarget = nil -- {x,y, targetObject}
    -- debug
    self.showDebug = true
    return self
end

-- helper: player's collision polygon (rectangle) in world coords
function Player:getPoly(xOff, yOff)
    xOff = xOff or 0; yOff = yOff or 0
    local x, y = self.x + xOff, self.y + yOff
    return {
        {x = x - self.w/2, y = y - self.h/2},
        {x = x + self.w/2, y = y - self.h/2},
        {x = x + self.w/2, y = y + self.h/2},
        {x = x - self.w/2, y = y + self.h/2}
    }
end

function Player:update(dt, level, enemies)
    -- handle dash cooldown
    if not self.canDash then
        self.dashTimer = self.dashTimer + dt
        if self.dashTimer >= self.dashCooldown then
            self.canDash = true
            self.dashTimer = 0
        end
    end

    -- input
    local left = love.keyboard.isDown("a") or love.keyboard.isDown("left")
    local right = love.keyboard.isDown("d") or love.keyboard.isDown("right")

    -- movement acceleration
    local inputX = 0
    if left then inputX = inputX - 1 end
    if right then inputX = inputX + 1 end

    if self.isDashing then
        -- dash active: fixed velocity
        self.dashTimeLeft = self.dashTimeLeft - dt
        if self.dashTimeLeft <= 0 then self.isDashing = false end
    else
        -- normal physics
        self.ax = inputX * self.moveSpeed * 5
        -- apply friction (simple)
        if inputX == 0 then
            self.vx = self.vx * (1 - math.min(dt * self.friction, 1))
        else
            -- accelerate
            self.vx = self.vx + self.ax * dt
            if math.abs(self.vx) > self.maxSpeedX then
                self.vx = self.maxSpeedX * (self.vx < 0 and -1 or 1)
            end
            -- set facing horizontally when moving
            if inputX ~= 0 then self.facing.x = inputX; self.facing.y = 0 end
        end
    end

    -- gravity and clamp fall
    self.vy = self.vy + self.gravity * dt
    if self.vy > self.maxFall then self.vy = self.maxFall end

    -- apply velocities
    local nx, ny = self.x + (self.isDashing and self.dashVx or self.vx) * dt,
                   self.y + (self.isDashing and self.dashVy or self.vy) * dt

    -- basic collision resolution with level polygons
    -- naive: sample rectangle corners and push out if overlapping any polygon
    local candidatePoly = {
        {x = nx - self.w/2, y = ny - self.h/2},
        {x = nx + self.w/2, y = ny - self.h/2},
        {x = nx + self.w/2, y = ny + self.h/2},
        {x = nx - self.w/2, y = ny + self.h/2},
    }

    -- check collisions against level polygons
    local collided = false
    for _, poly in ipairs(level.polygons) do
        local collidedNow, mtv = SAT.polygonsCollide(candidatePoly, poly)
        if collidedNow then
            collided = true
            -- simple resolution: push candidate by axis * overlap
            nx = nx + mtv.axis.x * mtv.overlap
            ny = ny + mtv.axis.y * mtv.overlap
            -- if axis mostly vertical and we pushed up, treat as ground
            if mtv.axis.y < -0.7 then
                self.isGrounded = true
                self.vy = 0
            end
        end
    end
    if not collided then self.isGrounded = false end

    self.x, self.y = nx, ny

    -- update dash timer flags (continued)
    if self.isDashing then
        -- keep facing the dash direction
    else
        -- normal timers for jump hold
        if self.jumpTimer > 0 then self.jumpTimer = self.jumpTimer - dt end
    end

    -- update projectiles
    for i = #self.projectiles,1,-1 do
        local p = self.projectiles[i]
        p:update(dt, level, enemies)
        if p.dead then table.remove(self.projectiles, i) end
    end

    -- update missiles that may home onto moving targets (missiles handle their own homing)
end

function Player:dash(dirx, diry)
    if not self.canDash then return end
    dirx = dirx or self.facing.x
    diry = diry or 0
    local len = math.sqrt(dirx*dirx + diry*diry)
    if len == 0 then dirx, diry = self.facing.x, 0; len = 1 end
    dirx, diry = dirx/len, diry/len
    self.isDashing = true
    self.dashTimeLeft = self.dashDuration
    self.dashVx = dirx * self.dashSpeed
    self.dashVy = diry * self.dashSpeed
    self.canDash = false
    self.dashTimer = 0
end

function Player:jump()
    if self.isGrounded then
        self.vy = self.jumpImpulse
        self.jumpTimer = self.jumpHoldTime
        self.isGrounded = false
    end
end

function Player:shortHopRelease()
    -- if jump button released early, reduce upward velocity
    if self.vy < 0 and self.jumpTimer > 0 then
        self.vy = self.vy * 0.5
        self.jumpTimer = 0
    end
end

function Player:shootBullet()
    -- bullet: straight line, weak
    local dir = {x = self.facing.x, y = self.facing.y}
    if dir.x == 0 and dir.y == 0 then dir.x = 1 end
    local b = Missile.new(self.x, self.y, dir, {isHoming=false, speed=500, ttl=2})
    table.insert(self.projectiles, b)
end

function Player:shootMissile()
    local dir = {x = self.facing.x, y = self.facing.y}
    if dir.x == 0 and dir.y == 0 then dir.x = 1 end
    local m = Missile.new(self.x, self.y, dir, {isHoming=true, target=self.missileTarget})
    table.insert(self.projectiles, m)
end

-- target via raycast: cast a ray into the level and find intersection with polygons/enemies
function Player:raycastTo(x,y, level, enemies)
    -- simple raycast against each polygon edge, return closest intersection
    local px, py = self.x, self.y
    local best = nil
    local function intersectSeg(px,py, rx,ry, x1,y1,x2,y2)
        -- ray p + t*(r), seg from x1,y1 to x2,y2 with u in [0,1]
        local rdx, rdy = rx - px, ry - py
        local sdx, sdy = x2 - x1, y2 - y1
        local denom = rdx * sdy - rdy * sdx
        if math.abs(denom) < 1e-8 then return nil end
        local t = ((x1 - px) * sdy - (y1 - py) * sdx) / denom
        local u = ((x1 - px) * rdy - (y1 - py) * rdx) / denom
        if t >= 0 and u >= 0 and u <= 1 then
            return px + t*rdx, py + t*rdy, t
        end
        return nil
    end

    for _, poly in ipairs(level.polygons) do
        for i=1,#poly do
            local a = poly[i]
            local b = poly[i % #poly + 1]
            local ix,iy,t = intersectSeg(px,py,x,y,a.x,a.y,b.x,b.y)
            if ix then
                if not best or t < best.t then best = {x=ix,y=iy,t=t, hitObject=poly} end
            end
        end
    end

    -- also test against enemies (using bounding box center)
    for _, e in ipairs(enemies) do
        -- if enemy bounding poly exists, raycast against its edges like above
        if e.poly then
            for i=1,#e.poly do
                local a = e.poly[i]; local b = e.poly[i%#e.poly+1]
                local ix,iy,t = intersectSeg(px,py,x,y,a.x,a.y,b.x,b.y)
                if ix and (not best or t < best.t) then best = {x=ix,y=iy,t=t, hitObject=e} end
            end
        end
    end

    if best then
        -- set missile target to the object (if it's an enemy, store reference so moving target moves)
        if best.hitObject and best.hitObject ~= level.polygons then
            self.missileTarget = {x = best.x, y = best.y, object = best.hitObject}
        else
            self.missileTarget = {x = best.x, y = best.y, object = nil}
        end
    end
    return best
end

function Player:draw()
    -- draw player sprite placeholder
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("fill", self.x - self.w/2, self.y - self.h/2, self.w, self.h)
    -- projectiles
    for _, p in ipairs(self.projectiles) do p:draw() end

    if self.showDebug then
        -- bounds
        love.graphics.setColor(1,0,0,0.6)
        local poly = self:getPoly()
        love.graphics.polygon("line", poly[1].x,poly[1].y, poly[2].x,poly[2].y, poly[3].x,poly[3].y, poly[4].x,poly[4].y)

        -- facing vector
        love.graphics.setColor(0,1,0)
        love.graphics.line(self.x, self.y, self.x + self.facing.x*40, self.y + self.facing.y*40)
        -- target
        if self.missileTarget then
            love.graphics.setColor(1,1,0)
            love.graphics.circle("line", self.missileTarget.x, self.missileTarget.y, 10)
            love.graphics.line(self.x, self.y, self.missileTarget.x, self.missileTarget.y)
        end
    end
end

return Player
