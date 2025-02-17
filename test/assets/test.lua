script:import("flixel.text.FlxText")
script:import("flixel.tweens.FlxTween")
script:import("flixel.tweens.FlxEase")

local spr
local angleInc = 5

function create()
	print("hi! :D")
	print("woah, ", "multi param.")

	spr = FlxSprite:new()
	spr:loadGraphic("assets/yes.png")
	spr.scale:set(2, 2)
	spr:updateHitbox()
	spr:screenCenter()
	script.parent:add(spr)

	local txt = FlxText:new(0, 0, 0, "This text was made with Lua!\nAlong with the sprite in the background.", 24)
	txt.screenCenter()
	txt.y = txt.y - 50
	script.parent.add(txt)

	local function twnFinished() -- MAKE SURE EVERY FUNCTION AND VAR INSIDE FUNCTIONS ARE LOCAL. THIS IS TO WORKAROUND THE _G METATABLE.
		txt.angle = txt.angle + angleInc;

		if txt.angle >= 30 then
			angleInc = -5
		elseif txt.angle <= -30 then
			angleInc = 5
		end
		print("Random Num: "..tostring(giveRandomNum(1, 5)))
	end

	FlxTween:tween(txt, {y = txt.y + 100}, 0.5, {ease = FlxEase.quadOut, type = 4, onComplete = twnFinished})
end

function update(e)
	spr.angle = spr.angle + e * 100
end