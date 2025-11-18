local SAT = require("sat")
local Missile = require("missile")

local Player = {}
Player.__index = Player

function Player.new(x, y)
    local self = setmetatable({}, Player)

    self.x, self.y = x, y
    self.w, self.h = 24, 36

    -- Physics
    self.vx, self.vy = 0, 0
    self.moveSpeed = 240
    self.maxSpeedX = 320
    self.gravity = 1200
    self.jumpImpulse = -450
    self.maxFall = 900
    self.friction = 8

    -- Jump tuning
    self.jumpTimer = 0
    self.jumpHoldTime = 0.15
    self.isGrounded = false

    -- Dash
    self.canDash = true
    self.dashCooldown = 2
    self.dashTimer = 0
    self.isDashing = false
    self.dashDuration = 0.15
    self.dashTimeLeft = 0
    self.dashSpeed = 800

    -- Facing direction
    self.facing = {x = 1, y = 0}

    -- Projectiles
    self.projectiles = {}
    self.missileTarget = nil

    self.showDebug = true

    return self
end

function Player:getPoly(offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    return {
        {x = self.x - self.w/2 + offsetX, y = self.y - self.h/2 + offsetY},
        {x = self.x + self.w/2 + offsetX, y = self.y - self.h/2 + offsetY},
        {x = self.x + self.w/2 + offsetX, y = self.y + self.h/2 + offsetY},
        {x = self.x - self.w/2 + offsetX, y = self.y + self.h/2 + offsetY}
    }
end

function Player:update(dt, level, enemies)
    --========================================
    -- DASH COOLDOWN
    --========================================
    if not self.canDash then
        self.dashTimer = self.dashTimer + dt
        if self.dashTimer >= self.dashCooldown then
            self.canDash = true
            self.dashTimer = 0
        end
    end

    --========================================
    -- INPUT
    --========================================
    local left  = love.keyboard.isDown("a", "left")
    local right = love.keyboard.isDown("d", "right")

    local moveX = 0
    if left  then moveX = moveX - 1 end
    if right then moveX = moveX + 1 end

    --========================================
    -- DASHING MOVEMENT OVERRIDES
    --========================================
    if self.isDashing then
        self.dashTimeLeft = self.dashTimeLeft - dt
        if self.dashTimeLeft <= 0 then
            self.isDashing = false
        end
    else
        -- Normal physics
        if moveX ~= 0 then
            self.vx = self.vx + moveX * self.moveSpeed * dt * 5
            if math.abs(self.vx) > self.maxSpeedX then
                self.vx = self.maxSpeedX * (self.vx < 0 and -1 or 1)
            end
            self.facing.x = moveX
        else
            -- friction
            self.vx = self.vx * (1 - math.min(dt * self.friction, 1))
        end
    end

    --========================================
    -- GRAVITY
    --========================================
    if not self.isDashing then
        self.vy = self.vy + self.gravity * dt
        if self.vy > self.maxFall then self.vy = self.maxFall end
    end

    --========================================
    -- APPLY VELOCITY
    --========================================
    local vx = self.isDashing and self.dashVx or self.vx
    local vy = self.isDashing and self.dashVy or self.vy

    local newX = self.x + vx * dt
    local newY = self.y + vy * dt

    local poly = self:getPoly(newX - self.x, newY - self.y)

    -- RESET grounded
    self.isGrounded = false

    --========================================
    -- SAT COLLISIONS (LEVEL)
    --========================================
    for _, obj in ipairs(level.polygons) do
        local hit, mtv = SAT.polygonsCollide(poly, obj)
        if hit then
            -- Move by MTV
            newX = newX + mtv.axis.x * mtv.overlap
            newY = newY + mtv.axis.y * mtv.overlap

            -- Ground check
            if mtv.axis.y < -0.6 then
                self.isGrounded = true
                self.vy = 0
            end

            -- Rebuild polygon at new pos
            poly = self:getPoly(newX - self.x, newY - self.y)
        end
    end

    -- Apply final pos
    self.x, self.y = newX, newY

    --========================================
    -- PROJECTILES UPDATE
    --========================================
    for i = #self.projectiles, 1, -1 do
        local p = self.projectiles[i]
        p:update(dt, level, enemies)
        if p.dead then table.remove(self.projectiles, i) end
    end
end

function Player:dash(dx, dy)
    if not self.canDash then return end

    local mag = math.sqrt(dx*dx + dy*dy)
    if mag == 0 then dx = self.facing.x; dy = 0; mag = 1 end

    dx, dy = dx / mag, dy / mag

    self.isDashing = true
    self.dashTimeLeft = self.dashDuration
    self.dashVx = dx * self.dashSpeed
    self.dashVy = dy * self.dashSpeed

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
    if self.jumpTimer > 0 and self.vy < 0 then
        self.vy = self.vy * 0.35
        self.jumpTimer = 0
    end
end

function Player:shootBullet()
    local dir = {x=self.facing.x, y=0}
    local p = Missile.new(self.x, self.y, dir, {
        isHoming=false,
        speed=500,
        ttl=1.5
    })
    table.insert(self.projectiles, p)
end

function Player:shootMissile()
    local dir = {x=self.facing.x, y=0}
    local p = Missile.new(self.x, self.y, dir, {
        isHoming=true,
        target=self.missileTarget
    })
    table.insert(self.projectiles, p)
end

function Player:raycastTo(mx, my, level, enemies)
    local ox, oy = self.x, self.y

    local best = nil

    local function seg(px,py, rx,ry, x1,y1, x2,y2)
        local rdx, rdy = rx - px, ry - py
        local sdx, sdy = x2 - x1, y2 - y1

        local denom = rdx * sdy - rdy * sdx
        if math.abs(denom) < 1e-8 then return nil end

        local t = ((x1 - px) * sdy - (y1 - py) * sdx) / denom
        local u = ((x1 - px) * rdy - (y1 - py) * rdx) / denom

        if t >= 0 and u >= 0 and u <= 1 then
            return px + t*rdx, py + t*rdy, t
        end
    end

    -- Level polygons
    for _, poly in ipairs(level.polygons) do
        for i=1,#poly do
            local a, b = poly[i], poly[i % #poly + 1]
            local ix, iy, t = seg(ox, oy, mx, my, a.x, a.y, b.x, b.y)
            if ix and (not best or t < best.t) then
                best = {x=ix, y=iy, t=t, hit=poly}
            end
        end
    end

    -- Enemy polygons
    for _, e in ipairs(enemies) do
        if e.poly then
            for i=1,#e.poly do
                local a, b = e.poly[i], e.poly[i % #e.poly + 1]
                local ix, iy, t = seg(ox, oy, mx, my, a.x, a.y, b.x, b.y)
                if ix and (not best or t < best.t) then
                    best = {x=ix, y=iy, t=t, hit=e}
                end
            end
        end
    end

    if best then
        self.missileTarget = {
            x = best.x,
            y = best.y,
            object = best.hit
        }
    end
end

function Player:draw()
    -- Body
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("fill",
        self.x - self.w/2,
        self.y - self.h/2,
        self.w, self.h)

    -- Projectiles
    for _, p in ipairs(self.projectiles) do p:draw() end

    -- Debug
    if self.showDebug then
        -- bounds
        local P = self:getPoly()
        love.graphics.setColor(1,0,0,0.6)
        love.graphics.polygon("line",
            P[1].x,P[1].y,
            P[2].x,P[2].y,
            P[3].x,P[3].y,
            P[4].x,P[4].y)

        -- facing
        love.graphics.setColor(0,1,0)
        love.graphics.line(self.x, self.y, self.x + self.facing.x*40, self.y)

        -- target
        if self.missileTarget then
            love.graphics.setColor(1,1,0)
            love.graphics.circle("line",
                self.missileTarget.x,
                self.missileTarget.y,
                10)
        end
    end
end

return Player
