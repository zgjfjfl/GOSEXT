local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgNeeko"

function zgNeeko:__init()
	print("Zgjfjfl AIO - Neeko Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 900, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1000, Speed = 1300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgNeeko:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = false})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "[E] Range Set", value = 1000, min = 500, max = 1000, step = 50})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] on 'CC'", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "Q", name = "Auto [Q] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "E", name = "Auto [E] Kills", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
end

function zgNeeko:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if Menu.SupportMode:Value() and mode == "Harass" then
		if target.type ~= Obj_AI_Hero then
			args.Process = false
			return
		end
	end
end

function zgNeeko:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	end
	self:AutoQ()
	self:AutoE()
end

function zgNeeko:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(Menu.Combo.Erange:Value())
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_E) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgNeeko:Harass()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgNeeko:AutoQ()
	if IsReady(_Q) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.Q:Value() and IsHardCC(target) then
					self:CastGGPred(HK_Q, target)
				end
				if Menu.Kill.Q:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetQDmg(target) then
					self:CastGGPred(HK_Q, target)
				end
			end
		end
	end
end

function zgNeeko:AutoE()
	if IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Combo.Erange:Value())
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.E:Value() and IsHardCC(target) then
					self:CastGGPred(HK_E, target)
				end
				if Menu.Kill.E:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetEDmg(target) then
					self:CastGGPred(HK_E, target)
				end
			end
		end
	end	
end

function zgNeeko:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	end
end

function zgNeeko:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({80, 125, 170, 215, 260})[level] + 0.5 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function zgNeeko:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({70, 105, 140, 175, 210})[level] + 0.65 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgNeeko:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

zgNeeko()