local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgTaliyah"
	
function zgTaliyah:__init()		 
	print("Zgjfjfl AIO - Taliyah Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1000, Speed = 3600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 225, Range = 900, Speed = math.huge, Collision = false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 200, Range = 950, Speed = 1700, Collision = false}
	self.isCastingW = false
    self.stage = 0
    self.stageTick = 0
    self.startPos = nil
    self.endPos = nil
    self.mPos = nil
end

function zgTaliyah:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Wpush", name = "[W] push range", value = 400, min = 100, max = 600, step = 50})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Erange", name = "[E] cast range", value = 900, min = 100, max = 950, step = 50})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "QMis", name = "[Q] Missile Path", toggle = true, value = false})
end

function zgTaliyah:Tick()
	self:UpdateCastW()
	if ShouldWait() then
		return
	end
	if IsCasting() or self.isCastingW then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgTaliyah:CastW(startPos, endPos)
    if self.isCastingW then return false end

    self.isCastingW = true
    self.stage = 1
    self.stageTick = GetTickCount()
    self.startPos = startPos
    self.endPos = endPos
    self.mPos = mousePos

    _G.SDK.Orbwalker:SetMovement(false)
    _G.SDK.Orbwalker:SetAttack(false)

    return true
end

function zgTaliyah:UpdateCastW()
    if not self.isCastingW then return end

    local now = GetTickCount()

    if now > self.stageTick then
        if self.stage == 1 then
            Control.SetCursorPos(self.startPos)
            Control.KeyDown(HK_W)

            self.stage = 2
            self.stageTick = now

        elseif self.stage == 2 then
            Control.SetCursorPos(self.endPos)
            Control.KeyUp(HK_W)

            self.stage = 3
            self.stageTick = now

        elseif self.stage == 3 then
            Control.SetCursorPos(self.mPos)

            self.stage = 4
            self.stageTick = now + 150

        elseif self.stage == 4 then
            _G.SDK.Orbwalker:SetMovement(true)
            _G.SDK.Orbwalker:SetAttack(true)

            self.isCastingW = false
        end
    end
end

function zgTaliyah:CastQ(target)
	local pred = GGPrediction:SpellPrediction(self.qSpell)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(3) then
		Control.CastSpell(HK_Q, pred.CastPosition)
	end
end

function zgTaliyah:Combo()
	local target = GetTarget(1000)
	if IsValid(target) then
		if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and Menu.Combo.Q:Value() and IsReady(_Q) then
			self:CastQ(target)
		end
		if myHero.pos:DistanceTo(target.pos) < Menu.Combo.Erange:Value() and Menu.Combo.E:Value() and IsReady(_E) and not IsReady(_W) then
			Control.CastSpell(HK_E, target)
		end
		if Menu.Combo.W:Value() and IsReady(_W) and lastW + 1100 < GetTickCount() then
			local wPred = GGPrediction:SpellPrediction(self.wSpell)
			wPred:GetPrediction(target, myHero)
			if wPred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				local predPos = wPred.CastPosition
				local d = myHero.pos:DistanceTo(predPos)
				if d < self.wSpell.Range then
					local endPos = predPos + (myHero.pos - predPos):Normalized() * 225
					if d <= Menu.Combo.Wpush:Value() then
						endPos = predPos + (predPos - myHero.pos):Normalized() * 225
					end
					if self:CastW(predPos, endPos) then
						lastW = GetTickCount()
						return
					end
				end
			end
		end
	end
end

function zgTaliyah:Harass()
	local target = GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastQ(target)
		end
	end
end

function zgTaliyah:DrawLine3D(x,y,z,a,b,c,width,col)
	local p1 = Vector(x,y,z):To2D()
	local p2 = Vector(a,b,c):To2D()
	Draw.Line(p1.x, p1.y, p2.x, p2.y, width, col)
end

function zgTaliyah:DrawRectangleOutline(x, y, z, x1, y1, z1, width, col)
	local startPos = Vector(x,y,z)
	local endPos = Vector(x1,y1,z1)
	local c1 = startPos+Vector(Vector(endPos)-startPos):Perpendicular():Normalized()*width
	local c2 = startPos+Vector(Vector(endPos)-startPos):Perpendicular2():Normalized()*width
	local c3 = endPos+Vector(Vector(startPos)-endPos):Perpendicular():Normalized()*width
	local c4 = endPos+Vector(Vector(startPos)-endPos):Perpendicular2():Normalized()*width
	self:DrawLine3D(c1.x,c1.y,c1.z,c2.x,c2.y,c2.z,2,col)
	self:DrawLine3D(c2.x,c2.y,c2.z,c3.x,c3.y,c3.z,2,col)
	self:DrawLine3D(c3.x,c3.y,c3.z,c4.x,c4.y,c4.z,2,col)
	self:DrawLine3D(c1.x,c1.y,c1.z,c4.x,c4.y,c4.z,2,col)
end

local lastQCastTime = 0
local checkDuration = 2.5
function zgTaliyah:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
	end

	if not Menu.Draw.QMis:Value() then return end
	if myHero.activeSpell.name == "TaliyahQ" then
		if lastQCastTime == 0 then
			lastQCastTime = Game.Timer()
		end
		
	end
	if Game.Timer() - lastQCastTime > checkDuration then
		lastQCastTime = 0
		return
	end
	local drawColor = Draw.Color(80, 0xFF, 0xFF, 0xFF)
	local missileCount = Game.MissileCount()
	local myHeroHandle = myHero.handle
	for i = 1, missileCount do
		local missile = Game.Missile(i)
		if missile and missile.missileData then
			local owner = missile.missileData.owner
			local name = missile.missileData.name
			if owner == myHeroHandle and (name == "TaliyahQMis" or name == "TaliyahQMisBig") then
				Draw.Circle(missile.pos, missile.missileData.width, drawColor)
				if missile.missileData.startPos and missile.missileData.endPos then
					self:DrawRectangleOutline(
						missile.missileData.startPos.x, missile.missileData.startPos.y, missile.missileData.startPos.z,
						missile.missileData.endPos.x, missile.missileData.endPos.y, missile.missileData.endPos.z,
						missile.missileData.width, drawColor
					)
				end
			end
		end
	end
end

zgTaliyah()