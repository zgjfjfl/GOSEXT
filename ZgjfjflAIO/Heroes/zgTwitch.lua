local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgTwitch"

function zgTwitch:__init()
	print("Zgjfjfl AIO - Twitch Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 275, Range = 950, Speed = 1750, Collision = false}
	self.EBuffs = {}
end

function zgTwitch:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = false})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = 'Estacks', name = 'Use E|X Stacks', value = 6, min = 1, max = 6, step = 1})
	Menu.Combo:MenuElement({id = 'Eenemies', name = 'Use E|X Enemies', value = 1, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Rrange", name = 'Use R|X Distance', value = 750, min = 300, max = 1500, step = 50})
	Menu.Combo:MenuElement({id = "Renemies", name = 'Use R|X Enemies', value = 3, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Harass:MenuElement({id = 'Estacks', name = 'Use E|X Stacks', value = 6, min = 1, max = 6, step = 1})
	Menu.Harass:MenuElement({id = 'Eenemies', name = 'Use E|X Enemies', value = 1, min = 1, max = 5, step = 1})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = 'qrecall', name = 'Invisible Recall Key', key = string.byte('M')})
	Menu.Misc:MenuElement({id = 'stopq', name = 'Stop using W when has Q', value = true})
	Menu.Misc:MenuElement({id = 'stopr', name = 'Stop using W when has R', value = false})
	Menu.Misc:MenuElement({id = "EKill", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = 'qtimer', name = 'Q Timer', value = true})
	Menu.Draw:MenuElement({id = 'qinvisible', name = 'Q Invisible Range', value = true})
	Menu.Draw:MenuElement({id = 'qnotification', name = 'Q Notification Range', value = true})
end

function zgTwitch:EBuffManager()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2000)
	for _, hero in ipairs(enemies) do
		local id = hero.networkID
		if self.EBuffs[id] == nil then
			self.EBuffs[id] = { count = 0, duration = 0 }
		end
		local ebuff, ebuffData = GetBuffData(hero, "twitchdeadlyvenom")
		if ebuff and ebuffData.count > 0 and ebuffData.duration > 0 then
			if self.EBuffs[id].count < 6 and ebuffData.duration > self.EBuffs[id].duration then
				self.EBuffs[id].count = self.EBuffs[id].count + 1
			end
			self.EBuffs[id].duration = ebuffData.duration
		else
			self.EBuffs[id].count = 0
			self.EBuffs[id].duration = 0
		end
	end
end

function zgTwitch:OnTick()
	if ShouldWait() then
		return
	end

	self:EBuffManager()
	self:QRecall()

	if IsCasting() then return end

	self:EKS()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgTwitch:QRecall()
	if Menu.Misc.qrecall:Value() and IsReady(_Q) then
		Control.KeyDown(HK_Q)
		Control.KeyUp(HK_Q)
		Control.KeyDown(string.byte("B"))
		Control.KeyUp(string.byte("B"))
	end
end

function zgTwitch:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local xenemies = 0
		for _, hero in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1200)) do
			if IsValid(hero) and self.EBuffs[hero.networkID] then
				local ecount = self.EBuffs[hero.networkID].count
				if ecount > 0 and ecount >= Menu.Combo.Estacks:Value() then
					xenemies = xenemies + 1
				end
			end
		end
		if xenemies >= Menu.Combo.Eenemies:Value() then
			Control.CastSpell(HK_E)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Combo.Rrange:Value())
		if #enemies >= Menu.Combo.Renemies:Value() then
			Control.CastSpell(HK_R)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget()
		if target ~= nil then
			Control.CastSpell(HK_Q)
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		if Menu.Misc.stopq:Value() and HaveBuff(myHero, "TwitchHideInShadows") then
			return
		end
		if Menu.Misc.stopr:Value() and Game.Timer() < _G.SDK.Spell.RkTimer + 5.45 then
			return
		end
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(950)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			self:CastW(target)
		end
	end
end

function zgTwitch:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local xenemies = 0
		for _, hero in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1200)) do
			if IsValid(hero) and self.EBuffs[hero.networkID] then
				local ecount = self.EBuffs[hero.networkID].count
				if ecount > 0 and ecount >= Menu.Harass.Estacks:Value() then
					xenemies = xenemies + 1
				end
			end
		end
		if xenemies >= Menu.Harass.Eenemies:Value() then
			Control.CastSpell(HK_E)
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget()
		if target ~= nil and target.type == Obj_AI_Hero then
			Control.CastSpell(HK_Q)
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		if Menu.Misc.stopq:Value() and HaveBuff(myHero, "TwitchHideInShadows") then
			return
		end
		if Menu.Misc.stopr:Value() and Game.Timer() < _G.SDK.Spell.RkTimer + 5.45 then
			return
		end
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(950)
		if IsValid(target) and target.type == Obj_AI_Hero and target.pos:ToScreen().onScreen then 
			self:CastW(target)
		end
	end
end

function zgTwitch:EKS()
	if not (Menu.Misc.EKill:Value() and IsReady(_E)) then
		return
	end
	for _, hero in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1200)) do
		if IsValid(hero) and self.EBuffs[hero.networkID] then
			local ecount = self.EBuffs[hero.networkID].count
			if ecount > 0 then
				local elvl = myHero:GetSpellData(_E).level
				local basedmg = 10 + (elvl * 10)
				local perstack = (10 + (5 * elvl)) * ecount
				local bonusAD = myHero.bonusDamage * 0.35 * ecount
				local rawPhys = basedmg + perstack + bonusAD
				local rawMagic = myHero.ap * 0.35 * ecount
				local physDamage = _G.SDK.Damage:CalculateDamage(myHero, hero, _G.SDK.DAMAGE_TYPE_PHYSICAL, rawPhys)
				local magicDamage = _G.SDK.Damage:CalculateDamage(myHero, hero, _G.SDK.DAMAGE_TYPE_MAGICAL, rawMagic)
				local totalDamage = physDamage + magicDamage
				if totalDamage >= hero.health + (1.5 * hero.hpRegen) then
					Control.CastSpell(HK_E)
					break
				end
			end
		end
	end
end

function zgTwitch:CastW(unit)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(unit, myHero)
	if WPrediction:CanHit(3) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function zgTwitch:DrawTextOnHero(hero, text, color)
	local pos2D = hero.pos:To2D()
	local posX = pos2D.x - 50
	local posY = pos2D.y
	Draw.Text(text, 50, posX + 50, posY - 15, color)
end

function zgTwitch:Draw()
	if myHero.dead then return end

	if Menu.Draw.qtimer:Value() then
		local preInvisibleDuration = 1.35 - (Game.Timer() - _G.SDK.Spell.QkTimer)
		if preInvisibleDuration > 0 then
			self:DrawTextOnHero(myHero, tostring(math.floor(preInvisibleDuration * 1000)), Draw.Color(200, 65, 255, 100))
			return
		end
		local buff, buffData = GetBuffData(myHero, "TwitchHideInShadows")
		if buff then
			self:DrawTextOnHero(myHero, tostring(math.floor(buffData.duration * 1000)), Draw.Color(200, 65, 255, 100))
		end
	end

	if HaveBuff(myHero, "TwitchHideInShadows") then
		if Menu.Draw.qinvisible:Value() then
			Draw.Circle(myHero.pos, 500, 1, Draw.Color(200, 255, 0, 0))
		end
		if Menu.Draw.qnotification:Value() then
			Draw.Circle(myHero.pos, 800, 1, Draw.Color(200, 188, 77, 26))
		end
	end
end

zgTwitch()
