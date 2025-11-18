local level = require("level")
local Enemy = require("enemy")
local Player = require("player")

local enemies = {}
local debug = true
local player

local cam = {x = 0, y = 0}

function love.load()
    math.randomseed(os.time())
    level.init()

    -- spawn player in air so they must land/jump onto the start platform
    player = Player.new(40, 440)

    -- enemies: 1 before ascent, 1 on top platform, 1 after descent
    table.insert(enemies, Enemy.new(120, 480 - 16))   -- before ascent
    table.insert(enemies, Enemy.new(700, 260 - 16))   -- top platform
    table.insert(enemies, Enemy.new(1130, 480 - 16))  -- after descent
end

function love.update(dt)
    player:update(dt, level)

    local pstate = { x = player.x, y = player.y }
    for _, enemy in ipairs(enemies) do
        enemy:update(dt, pstate, level)
    end

    local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
    cam.x = player.x - winW * 0.5
    cam.y = player.y - winH * 0.5
    cam.x = math.max(0, math.min(cam.x, (level.width or winW) - winW))
    cam.y = math.max(0, math.min(cam.y, (level.height or winH) - winH))
end

function love.draw()
    love.graphics.clear(0.09, 0.11, 0.14)

    love.graphics.push()
    love.graphics.translate(-math.floor(cam.x), -math.floor(cam.y))

    level.draw()
    for _, e in ipairs(enemies) do e:draw() end
    player:draw()

    love.graphics.pop()

    if debug then
        love.graphics.setColor(1,1,1)
        love.graphics.print("Move: WASD/Arrows. Jump: Space. Dash: Shift + Left/Right", 10, 10)
    end
end

function love.keypressed(key)
    if key == "d" then debug = not debug end
end