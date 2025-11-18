-- main.lua
love.window.setTitle("Assignment 2 prototype")
local Player = require("player")
local Level = require("level")
local Enemy = require("enemy")

local level, player, enemies

function love.load()
    math.randomseed(os.time())
    level = Level.new()
    player = Player.new(120,300)
    enemies = {}
    table.insert(enemies, require("enemy").new(500,220))
    table.insert(enemies, require("enemy").new(300,400))
end

function love.update(dt)
    -- input: key pressed events handled by love.keypressed, continuous handled here
    player:update(dt, level, enemies)
    for _, e in ipairs(enemies) do e:update(player, player, level) end
end

function love.draw()
    level:draw()
    for _, e in ipairs(enemies) do e:draw() end
    player:draw()
end

function love.keypressed(key)
    if key == "space" then player:jump() end
    if key == "lshift" or key == "rshift" then
        -- dash: combine with movement
        local dirx = 0
        if love.keyboard.isDown("a") or love.keyboard.isDown("left") then dirx = -1
        elseif love.keyboard.isDown("d") or love.keyboard.isDown("right") then dirx = 1 end
        player:dash(dirx, 0)
    end
    if key == "e" then player:shootBullet() end
    if key == "r" or key == "m" then player:shootMissile() end
    if key == "t" then
        local mx, my = love.mouse.getPosition()
        player:raycastTo(mx, my, level, enemies)
    end
end

function love.keyreleased(key)
    if key == "space" then player:shortHopRelease() end
end
