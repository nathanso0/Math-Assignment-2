-- main.lua
love.window.setTitle("Assignment 2 Prototype")

local Player = require("player")
local Level  = require("level")
local Enemy  = require("enemy")

local level, player, enemies

function love.load()
    math.randomseed(os.time())

    level = Level.new()
    player = Player.new(120, 300)

    enemies = {
        Enemy.new(500, 220),
        Enemy.new(300, 400)
    }
end

function love.update(dt)
    player:update(dt, level, enemies)

    for _, e in ipairs(enemies) do
        e:update(dt, player, level)
    end
end

function love.draw()
    level:draw()

    for _, e in ipairs(enemies) do
        e:draw()
    end

    player:draw()
end

function love.keypressed(key)
    if key == "space" then player:jump() end

    -- Celeste dash: Shift + direction
    if key == "lshift" or key == "rshift" then
        local dirx = 0
        if love.keyboard.isDown("a", "left") then dirx = -1 end
        if love.keyboard.isDown("d", "right") then dirx = 1 end
        player:dash(dirx, 0)
    end

    if key == "e" then player:shootBullet() end
    if key == "r" or key == "m" then player:shootMissile() end

    -- Raycast Target ability
    if key == "t" then
        local mx, my = love.mouse.getPosition()
        player:raycastTo(mx, my, level, enemies)
    end
end

function love.keyreleased(key)
    if key == "space" then player:shortHopRelease() end
end
