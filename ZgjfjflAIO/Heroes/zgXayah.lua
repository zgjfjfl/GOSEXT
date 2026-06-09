local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgXayah"

function zgXayah:__init()		 
	print("Zgjfjfl AIO - Xayah Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 1075, Speed = 700, Collision = false}
	self.WSpell = { Delay = 0.25 }
	self.ESpell = { Delay = 0.25 }
	self.RSpell = { Delay = 1, Range = 1000 }
	self.Feathers = {}
end

function zgXayah:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Ecount", name = "Use E|If Can Hit X Feathers", value = 3, min = 3, max = 20, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Ecount", name = "Use E|If Can Hit X Feathers", value = 2, min = 2, max = 20, step = 1})
	
	Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
	Menu.AutoE:MenuElement({id = "ERoot", name = "Auto E Root(no combo)", toggle = true, value = true})
	Menu.AutoE:MenuElement({id = "EKill", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgXayah:OnTick()
	self.QSpell.Delay = math.max(math.floor((0.25 - 0.07*(myHero.attackSpeed-1))*1000)/1000, 0.1)
	self:FindFeathers()
	self:UpdateFeather()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:AutoE()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgXayah:OnPreAttack(args)
	local target = args.Target and args.Target.type == Obj_AI_Hero
	if target and IsReady(_W) then
		if GetMode() == "Combo" and Menu.Combo.W:Value() or GetMode() == "Harass" and Menu.Harass.W:Value() then 
			Control.CastSpell(HK_W)
		end
	end
end

function zgXayah:UpdateFeather()
	local currentTime = Game.Timer()
	for i = #self.Feathers, 1, -1 do
		if currentTime > self.Feathers[i].placetime then
			table.remove(self.Feathers, i)
		end
	end
	if #self.Feathers == 0 then
		return
	end
	for i = Game.MissileCount(), 1, -1 do
		local missile = Game.Missile(i)
		local mis = missile.missileData
		if mis and mis.owner == myHero.handle and mis.name:lower():find("xayahemissilesfx") then
			self.Feathers = {}
		end
	end
end

function zgXayah:CheckFeather(obj)
	for i = 1, #self.Feathers do
		if self.Feathers[i].ID == obj.networkID then
			return false
		end
	end
	return true
end

function zgXayah:FindFeathers()
	for i = 1, Game.ParticleCount() do
		local particle = Game.Particle(i)
		if particle then
			local parName = particle.name:lower()
			if parName:find("xayah") and parName:find("passive_dagger_mark") and self:CheckFeather(particle) then
				self.Feathers[#self.Feathers + 1] = {placetime = Game.Timer() + 6, ID = particle.networkID, pos = particle.pos}
			end
		end
	end		
end

function zgXayah:CountFeatherHits(target)
	local HitCount = 0
	if target then
		for i = 1, #self.Feathers do
			local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(target.pos, self.Feathers[i].pos, myHero.pos)
			local width = 80 + target.boundingRadius
			if isOnSegment and GGPrediction:IsInRange(target.pos, point, width) then
				HitCount = HitCount + 1
			end
		end
	end
	return HitCount
end
	
function zgXayah:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local enemies = GetEnemyHeroes()
		for i = 1, #enemies do
			local enemy = enemies[i]
			if IsValid(enemy) then
				local hitsCount = self:CountFeatherHits(enemy)
				if hitsCount >= Menu.Combo.Ecount:Value() then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
end

function zgXayah:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			self:CastGGPred(HK_Q, target)
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local enemies = GetEnemyHeroes()
		for i = 1, #enemies do
			local enemy = enemies[i]
			if IsValid(enemy) then
				local hitsCount = self:CountFeatherHits(enemy)
				if hitsCount >= Menu.Harass.Ecount:Value() then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
end

function zgXayah:AutoE()
	local enemies = GetEnemyHeroes()
	for i = 1, #enemies do
		local enemy = enemies[i]
		if IsValid(enemy) and IsReady(_E) then
			local hitsCount = self:CountFeatherHits(enemy)
			if Menu.AutoE.ERoot:Value() and GetMode() ~= "Combo" then
				if hitsCount >= 3 then
					Control.CastSpell(HK_E)
				end
			end
			if Menu.AutoE.EKill:Value() then
				local Dmg = self:GetEDmg(enemy, hitsCount)
				if Dmg > enemy.health + enemy.shieldAD then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
end

function zgXayah:GetEDmg(target, hitsCount)
	local level = myHero:GetSpellData(_E).level
	local hasIE = HasItem(myHero, 3031)
	local EDmg = (35 + level * 15 + 0.4 * myHero.bonusDamage) * hitsCount * (1 + myHero.critChance * (hasIE and 0.65 or 0.5))
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, EDmg)
end

function zgXayah:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	end
end

function zgXayah:Draw()
	if myHero.dead then return end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgXayah()
