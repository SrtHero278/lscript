script:import("flixel.text.FlxText")

local spr

function create()
    spr = FlxSprite:new()
    spr:loadGraphic("assets/yes.png")
    spr.scale:set(2, 2)
    spr:updateHitbox()
    spr:screenCenter()
    script.parent:add(spr)

    local txt = FlxText:new(0, 0, 0, "This text was made with Lua!\nAlong with the sprite in the background.", 24)
    txt:screenCenter()
    script.parent:add(txt)
end

function update(e)
    spr.angle = spr.angle + e * 100
end