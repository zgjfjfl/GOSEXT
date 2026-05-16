local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgSenna"

function zgSenna:__init()
	print("Zgjfjfl AIO - Senna Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 50, Range = 1300, Speed = math.huge, Collision = false}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1250, Speed = 1200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1, Radius = 160, Range = 25000, Speed = 20000, Collision = false}
end

function zgSenna:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)",value = true})
	Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
	Menu.combo:MenuElement({id = "Qexternal", name = "use Q External", value = true})
	Menu.combo:MenuElement({id = "Q", name = "use Q", value = true})
	Menu.combo:MenuElement({id = "W", name = "use W", value = true})
	Menu.combo:MenuElement({id = "WRange", name = "use W|Range", value = 1100, min = 1,max = 1250,step = 50})

	Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
	Menu.harass:MenuElement({id = "Qexternal", name = "use Q External", value = true})
	Menu.harass:MenuElement({id = "Q", name = "use Q", value = true})
	Menu.harass:MenuElement({id = "W", name = "use W", value = false})
	Menu.harass:MenuElement({id = "WRange", name = "use W|Range", value = 1100, min = 1,max = 1250,step = 50})

	Menu:MenuElement({type = MENU, id = "ks", name = "KS"})
	Menu.ks:MenuElement({id = "Qexternal", name = "Q External KS", value = true})
	Menu.ks:MenuElement({id = "R", name = "R KS", value = true})
	Menu.ks:MenuElement({id = "MinRange",name = "Min R Range",value = 1300, min = 1,max = 2000,step = 50})
	Menu.ks:MenuElement({id = "MaxRange",name = "Max R Range",value = 5000, min = 1,max = 20000,step = 50})

	Menu:MenuElement({type = MENU, id = "heal", name = "Auto Heal"})
	Menu.heal:MenuElement({id = "Q", name = "Q Auto Heal Ally", value = true})
	Menu.heal:MenuElement({id = "HP",name = "If Ally HP < X %",value = 20,min = 1,max = 101,step = 10})

	Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawing"})
	Menu.Drawing:MenuElement({id = "Q",name = "Draw [Q] Range",value = false})
	Menu.Drawing:MenuElement({id = "W",name = "Draw [W] Range",value = false})
end

function zgSenna:Draw()
	if myHero.dead then return end

	if Menu.Drawing.Q:Value() then
		Draw.Circle(myHero.pos, self.QSpell.Range, Draw.Color(255, 0xE1,0xA0,0x00))
	end

	if Menu.Drawing.W:Value() then
		Draw.Circle(myHero.pos, self.WSpell.Range, Draw.Color(255, 0xE1,0xA0,0x00))
	end
end

function zgSenna:OnPreAttack(args)
	if Menu.SupportMode:Value() and GetMode() == "Harass" then
		if args.Target.type ~= Obj_AI_Hero and args.Target.charName ~= "SennaSoul" then
			args.Process = false
		end
	end
end

function zgSenna:OnTick()
	Q1Range = myHero.range + myHero.boundingRadius * 2
	self:SetQDelay()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end

	if GetMode() == "Combo" then
		self:Combo()
	end

	if GetMode() == "Harass" then
		self:Harass()
	end

	self:KS()
	self:AutoHeal()
end

function zgSenna:SetQDelay()
	if myHero.activeSpell.valid and myHero.activeSpell.name == "SennaQCast" then
		self.QSpell.Delay = myHero.activeSpell.windup
	end
end

function zgSenna:Combo()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) then
		if target.distance <= Q1Range then
			if Menu.combo.Q:Value() then
				self:CastQ(target)
			end
		else
			if Menu.combo.Qexternal:Value() then
				self:CastQExternal(target)
			end
		end
	end

	if Menu.combo.W:Value() then
		local target = GetTarget(Menu.combo.WRange:Value())
		if IsValid(target) then
			self:CastW(target)
		end
	end
end

function zgSenna:Harass()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) then
		if target.distance <= Q1Range then
			if Menu.harass.Q:Value() then
				self:CastQ(target)
			end
		else
			if Menu.harass.Qexternal:Value() then
				self:CastQExternal(target)
			end
		end
	end

	if Menu.harass.W:Value() then
		local target = GetTarget(Menu.harass.WRange:Value())
		if IsValid(target) then
			self:CastW(target)
		end
	end
end

function zgSenna:KS()
	if Menu.ks.Qexternal:Value() and IsReady(_Q) then
		for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1300)) do
			if IsValid(enemy) then
				if enemy.distance > Q1Range and (enemy.health + enemy.shieldAD) < self:GetQDamage(enemy) then
					self:CastQExternal(enemy)
				end
			end
		end
	end

	if Menu.ks.R:Value() and IsReady(_R) then
		local enemies = GetEnemyHeroes()
		for i = 1, #enemies do
			local enemy = enemies[i]
			if IsValid(enemy) and (enemy.health + enemy.shieldAD) < self:GetRDamage(enemy) then
				if GetDistanceSqr(myHero.pos,enemy.pos) <  Menu.ks.MaxRange:Value() * Menu.ks.MaxRange:Value()
					and GetDistanceSqr(myHero.pos,enemy.pos) >  Menu.ks.MinRange:Value() * Menu.ks.MinRange:Value()
					and GetAllyCount(600, enemy.pos) == 0
				then
					local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
					RPrediction:GetPrediction(enemy, myHero)
					if RPrediction:CanHit(3) then
						Control.CastSpell(HK_R, RPrediction.CastPosition)
					end
				end
			end
		end
	end
end

function zgSenna:AutoHeal()
	if Menu.heal.Q:Value() and IsReady(_Q) then
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(Q1Range)
		for i = 1, #allies do 
			local ally = allies[i]
			local percetHealth = ally.health / ally.maxHealth*100
			if not ally.isMe and percetHealth < Menu.heal.HP:Value() then
				Control.CastSpell(HK_Q, ally)
			end
		end
	end
end

function zgSenna:GetQDamage(target)
	local baseDmg = ({30, 60, 90, 120, 150})[myHero:GetSpellData(_Q).level]
	local bonusDmg = myHero.bonusDamage * 0.4
	local passiveDmg = myHero.totalDamage * 0.2

	local value = baseDmg + bonusDmg + passiveDmg

	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, value)

end

function zgSenna:GetRDamage(target)
	local baseDmg = ({250, 400, 550})[myHero:GetSpellData(_R).level]
	local bonusDmg = myHero.bonusDamage * 1.15
	local bonusAP = myHero.ap * 0.7

	local value = baseDmg + bonusDmg + bonusAP

	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, value)
end

function zgSenna:CastQExternal(target)
	if IsReady(_Q) then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			local range = myHero.pos:DistanceTo(QPrediction.UnitPosition)
			local targetPos = myHero.pos:Extended(QPrediction.UnitPosition, range)

			local allies = _G.SDK.ObjectManager:GetAllyHeroes(Q1Range)
			local minions = _G.SDK.ObjectManager:GetMinions(Q1Range)
			local turrets = _G.SDK.ObjectManager:GetTurrets(Q1Range)
			local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Q1Range)

			local objectTable = self:tableMerge(allies, minions, turrets, enemies)

			for i = 1, #objectTable do
				local object = objectTable[i]
				local objectPos = myHero.pos:Extended(object.pos, range)
				if GetDistanceSqr(targetPos, objectPos) < (65/2 + target.boundingRadius) ^ 2 then
					Control.CastSpell(HK_Q, object)
				end
			end
		end
	end
end

function zgSenna:tableMerge(t1, t2, t3 ,t4)
	local newTable = {}

	for i = 1, #t1 do
		local v = t1[i]
		table.insert(newTable,v)
	end
	for i = 1, #t2 do
		local v = t2[i]
		table.insert(newTable,v)
	end

	if t3 then
		for i = 1, #t3 do
			local v = t3[i]
			table.insert(newTable,v)
		end
	end

	if t4 then
		for i = 1, #t4 do
			local v = t4[i]
			table.insert(newTable,v)
		end
	end
	
	return newTable
end

function zgSenna:CastQ(target)
	if IsReady(_Q) then
		Control.CastSpell(HK_Q, target)
	end
end

function zgSenna:CastW(target)
	if IsReady(_W) then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(target, myHero)
		if WPrediction:CanHit(3) then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
		end
	end
end

zgSenna()
