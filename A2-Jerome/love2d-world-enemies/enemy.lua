-- Enemy with working projectiles and wall-probe turn-around
local Enemy = {}
Enemy.__index = Enemy

local WALK_SPEED = 60
local GRAVITY = 1200

-- small projectile type
local Projectile = {}
Projectile.__index = Projectile
function Projectile.new(x,y,dx,dy,speed,life)
    local p = setmetatable({}, Projectile)
    p.x = x; p.y = y
    p.dx = dx; p.dy = dy
    p.speed = speed or 380
    p.life = life or 3
    p.r = 4
    return p
end
function Projectile:update(dt, level)
    local sx, sy = self.x, self.y
    self.x = self.x + self.dx * self.speed * dt
    self.y = self.y + self.dy * self.speed * dt
    self.life = self.life - dt
    if level.raycast then
        local hit = level.raycast(sx, sy, self.x, self.y)
        if hit then self.life = 0 end
    end
end
function Projectile:draw()
    love.graphics.setColor(1,0.75,0.2)
    love.graphics.circle("fill", self.x, self.y, self.r)
    love.graphics.setColor(1,1,1)
end

function Enemy.new(x, y)
    local self = setmetatable({}, Enemy)
    self.x = x or 400
    self.y = y or 300
    self.w = 22; self.h = 32
    self.vx = 0; self.vy = 0
    self.facing = (math.random(1,2) == 1) and -1 or 1

    if math.random(1,2) == 1 then self.baseState = "idle" else self.baseState = "wander" end
    self.state = self.baseState
    self.stateTimer = 0

    self.viewRadius = 220
    self.viewHeight = 48

    self.triggered = false
    self.triggerBehavior = nil
    self.triggerTimer = 0

    self.t = math.random()*10
    self.shootFlash = 0
    self.shootCooldown = 0
    self.projectiles = {}
    return self
end

local function sign(n) if n < 0 then return -1 elseif n > 0 then return 1 else return 0 end end

function Enemy:isOnGround(level)
    local footY = self.y + self.h/2
    local groundY = level.getGroundBelow(self.x, footY - 1, 8)
    return groundY ~= nil and math.abs(groundY - footY) <= 8
end

function Enemy:frontHasGround(level, dir)
    dir = dir or self.facing
    local aheadX = self.x + (self.w/2 + 4) * dir
    local footY = self.y + self.h/2
    local groundY = level.getGroundBelow(aheadX, footY - 1, 12)
    return groundY ~= nil
end

function Enemy:canSeePlayer(player, level)
    local dx = player.x - self.x
    local dy = player.y - self.y
    if math.abs(dx) > self.viewRadius then return false end
    if math.abs(dy) > self.viewHeight/2 then return false end
    if self.facing == 1 and dx < -6 then return false end
    if self.facing == -1 and dx > 6 then return false end
    if level.raycast then
        local hit = level.raycast(self.x, self.y, player.x, player.y)
        if hit then
            local hitd2 = (hit.x - self.x)^2 + (hit.y - self.y)^2
            local pd2 = dx*dx + dy*dy
            if hitd2 < pd2 - 1 then return false end
        end
    end
    return true
end

local function in_firing_cone(self, tx, ty, maxAngleDeg)
    local dx = tx - self.x
    local dy = ty - self.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist == 0 then return true, 1 end
    local nx, ny = dx/dist, dy/dist
    local fx, fy = self.facing, 0
    local dot = nx*fx + ny*fy
    local cosThresh = math.cos(math.rad(maxAngleDeg or 35))
    return dot >= cosThresh, dot
end

function Enemy:spawnProjectile(tx, ty)
    local dx, dy = tx - self.x, ty - self.y
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then return end
    dx, dy = dx/len, dy/len
    local px = self.x + dx * (self.w/2 + 6)
    local py = self.y + dy * (self.h*0.25)
    table.insert(self.projectiles, Projectile.new(px, py, dx, dy, 380, 3.0))
    self.shootFlash = 0.12
    self.shootCooldown = 0.3
end

function Enemy:update(dt, player, level)
    self.t = self.t + dt
    self.stateTimer = self.stateTimer + dt
    self.triggerTimer = self.triggerTimer + dt
    self.shootFlash = math.max(0, self.shootFlash - dt)
    self.shootCooldown = math.max(0, self.shootCooldown - dt)

    -- update projectiles
    for i = #self.projectiles, 1, -1 do
        local p = self.projectiles[i]
        p:update(dt, level)
        if player and player.x and player.y then
            local dx = p.x - (player.x or 0)
            local dy = p.y - (player.y or 0)
            if dx*dx + dy*dy < (16*16) then
                p.life = 0
            end
        end
        if p.life <= 0 then table.remove(self.projectiles, i) end
    end

    -- gravity + ground snap
    self.vy = self.vy + GRAVITY * dt
    if self:isOnGround(level) then
        local footY = self.y + self.h/2
        local gy = level.getGroundBelow(self.x, footY - 1, 20)
        if gy then self.y = gy - self.h/2; self.vy = 0 end
    end

    -- detect player
    if not self.triggered and self:canSeePlayer(player, level) then
        self.triggered = true
        self.triggerBehavior = math.random(1,3)
        self.state = "triggered"
        self.stateTimer = 0
        self.triggerTimer = 0
    end

    -- behaviour
    if self.state == "idle" then
        self.vx = 0

    elseif self.state == "wander" then
        if self.vx == 0 then self.vx = self.facing * WALK_SPEED end
        if not self:frontHasGround(level, sign(self.vx)) then
            self.vx = -self.vx
            self.facing = sign(self.vx)
        end

    elseif self.state == "triggered" then
        local dx = player.x - self.x
        local dirToPlayer = sign(dx == 0 and 1 or dx)

        if self.triggerBehavior == 1 then
            self.vx = 0
            self.facing = dirToPlayer
            if self.triggerTimer > 0.8 and self.shootCooldown <= 0 then
                local leadTime = 0.18
                local tx, ty = player.x, player.y
                if player.vx and player.vy then
                    tx = tx + player.vx * leadTime
                    ty = ty + player.vy * leadTime
                end
                local ok = in_firing_cone(self, tx, ty, 35)
                if ok then self:spawnProjectile(tx, ty) end
                self.triggerTimer = 0
            end

        elseif self.triggerBehavior == 2 then
            self.facing = dirToPlayer
            if self:frontHasGround(level, self.facing) then
                self.vx = self.facing * WALK_SPEED
            else
                self.vx = 0
            end
            if self.triggerTimer > 0.9 and self.shootCooldown <= 0 then
                local leadTime = 0.14
                local tx, ty = player.x, player.y
                if player.vx and player.vy then
                    tx = tx + player.vx * leadTime
                    ty = ty + player.vy * leadTime
                end
                local ok = in_firing_cone(self, tx, ty, 30)
                if ok then self:spawnProjectile(tx, ty) end
                self.triggerTimer = 0
            end

        elseif self.triggerBehavior == 3 then
            self.facing = -dirToPlayer
            if self:frontHasGround(level, self.facing) then
                self.vx = self.facing * WALK_SPEED
            else
                self.vx = 0
            end
        end

        if not self:canSeePlayer(player, level) and self.stateTimer > 2.5 then
            self.triggered = false; self.triggerBehavior = nil
            self.state = self.baseState; self.stateTimer = 0
        end
    end

    -- BEFORE moving: probe ahead for walls and flip if necessary
    do
        local probeX = self.x + (self.w/2 + 3) * self.facing
        local probeFutureX = probeX + (self.vx or 0) * dt
        local hitWall = level.isSolidAt and level.isSolidAt(probeFutureX, self.y)
        if hitWall then
            self.facing = -self.facing
            self.vx = self.facing * (math.abs(self.vx) > 0 and math.abs(self.vx) or WALK_SPEED)
        end
    end

    -- integrate with safer snapping
    local prevY = self.y
    local prevFootY = prevY + self.h/2

    local attemptedX = self.x + (self.vx or 0) * dt
    local leftBlocked = level.isSolidAt and level.isSolidAt(attemptedX - self.w/2, self.y)
    local rightBlocked = level.isSolidAt and level.isSolidAt(attemptedX + self.w/2, self.y)

    if leftBlocked and not rightBlocked then
        self.vx = WALK_SPEED
        self.facing = 1
    elseif rightBlocked and not leftBlocked then
        self.vx = -WALK_SPEED
        self.facing = -1
    elseif leftBlocked and rightBlocked then
        self.vx = 0
    else
        self.x = attemptedX
    end

    self.y = self.y + (self.vy or 0) * dt

    for _, p in ipairs(level.platforms) do
        local px,py,pw,ph = p[1],p[2],p[3],p[4]
        local overlapX = (self.x >= px - self.w/2) and (self.x <= px + pw + self.w/2)
        local overlapY = (self.y + self.h/2 > py) and (self.y - self.h/2 < py + ph)
        if overlapX and overlapY then
            if prevFootY <= py + 1 then
                self.y = py - self.h/2
                self.vy = 0
            end
        end
    end
end

function Enemy:draw()
    love.graphics.push(); love.graphics.translate(self.x, self.y)
    local bob = math.sin(self.t * 3) * 2
    love.graphics.translate(0, bob)
    love.graphics.setColor(0.8, 0.3, 0.3)
    love.graphics.ellipse("fill", 0, 0, self.w*0.55, self.h*0.6)
    love.graphics.setColor(0.95,0.9,0.6)
    love.graphics.circle("fill", 0, -self.h*0.5, self.w*0.45)
    love.graphics.setColor(0,0,0)
    love.graphics.circle("fill", self.facing * 5, -self.h*0.5, 3)
    love.graphics.pop()

    for _, p in ipairs(self.projectiles) do p:draw() end

    if self.shootFlash > 0 then
        love.graphics.setColor(1,0.8,0.2,0.9)
        love.graphics.line(self.x, self.y - 6, self.x + self.facing * 28, self.y - 6)
    end

    local color = {0,0.6,0,0.12}
    if self.baseState == "wander" then color = {0,0.45,0.9,0.12} end
    if self.state == "triggered" then
        if self.triggerBehavior == 1 then color = {1,0.2,0.2,0.18}
        elseif self.triggerBehavior == 2 then color = {1,0.6,0.1,0.18}
        elseif self.triggerBehavior == 3 then color = {0.5,0.2,1,0.14} end
    end
    local vx = (self.facing == 1) and self.viewRadius or -self.viewRadius
    local rx = (self.facing == 1) and self.x or (self.x + vx)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", rx, self.y - self.viewHeight/2, math.abs(vx), self.viewHeight)
    love.graphics.setColor(1,1,1,0.6)
    love.graphics.rectangle("line", self.x - self.w/2, self.y - self.h/2, self.w, self.h)
    love.graphics.setColor(1,1,1)
end

return Enemy