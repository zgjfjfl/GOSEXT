local Version = 1.02

require("GGPrediction")
require("ClassicAIO\\Utils")

local function IsUnderAllyTurret(unit)
	for _, turret in ipairs(_G.SDK.ObjectManager:GetAllyTurrets()) do
		local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
		if not turret.dead then 
			if turret.pos:DistanceTo(unit.pos) < range then
				return true
			end
		end
	end
	return false
end

local LastChatOpenTimer = 0

--------------------------------------

class "ClassicEzreal"

function ClassicEzreal:__init()
	print("Classic AIO - Ezreal Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 1050, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL, GGPrediction.COLLISION_MINION}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1050, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1.00, Radius = 160, Range = 25000, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.lastQ = 0
	self.lastW = 0
	self.EHelper = nil
	self.LastE = 0
	self.lastClearSpecial = 0
	self.lastQTarget = nil
	self.lastQExpire = 0
	self.lastAATarget = nil
	self.lastAAExpire = 0
	self.lastAAWillKill = false
end

function ClassicEzreal:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = true, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QSpecial", name = "Q Special Minions", toggle = true, value = true})
	--Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	--Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "EHelper", name = "EHelper"})
	Menu.EHelper:MenuElement({id = "Enable", name = "Enable EHelper", toggle = true, value = false})
	Menu.EHelper:MenuElement({id = "efake", name = "Key to use", value = false, key = string.byte("E")})
	Menu.EHelper:MenuElement({id = "elol", name = "key in game", value = false, key = string.byte("L")})
	
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoR"})
	Menu.Auto:MenuElement({id = "RCC", name = "Auto R CC", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RKill", name = "Auto R KillSteal", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RAOE", name = "Auto R AOE", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RCount", name = "Auto R| AOE Count >=", value = 3, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
end

function ClassicEzreal:OnPreAttack(args)
	local mode = GetMode()
	if mode == "LaneClear" then
		if self.lastQTarget and GetTickCount() < self.lastQExpire then
			if args.Target and args.Target.handle == self.lastQTarget then
				args.Process = false
				return
			end
		else
			self.lastQTarget = nil
		end
	end
	if args.Process and args.Target then
		self:TrackAATarget(args.Target)
	end
end

local LastEFake = 0
function ClassicEzreal:OnWndMsg(msg, wParam)
	if msg == KEY_DOWN and wParam == Menu.EHelper.efake:Key() then
		LastEFake = os.clock()
	end
end

function ClassicEzreal:OnEnemyHeroLoad(enemy)
	if enemy and specialMinionChampions[enemy.charName] then
		self.hasSpecialMinionEnemy = true
	end
end

function ClassicEzreal:TrackAATarget(unit)
	if not IsValid(unit) then return end
	if unit.type ~= Obj_AI_Hero and unit.type ~= Obj_AI_Minion then
		self.lastAAWillKill = false
		return
	end
	local attackSpeed = _G.SDK.Attack:GetProjectileSpeed()
	local flyTime = attackSpeed > 0 and unit.distance / attackSpeed or 0
	local timeToHit = _G.SDK.Attack:GetWindup() + flyTime
	local expireTime = (timeToHit + 0.15) * 1000
	self.lastAATarget = unit.handle
	self.lastAAExpire = GetTickCount() + expireTime
	self.lastAAWillKill = self:CanMyAAKill(unit, unit.type == Obj_AI_Hero)
end

function ClassicEzreal:Tick()
	if Game.IsChatOpen() then
		LastChatOpenTimer = GetTickCount()
	end
	if ShouldWait() then return end
	if IsCasting() then return end
	self:SemiR()
	self:AutoR()
	self:ELogic()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		if Menu.Clear.SpellFarm:Value() then
			self:FarmHarass()
			self:ClearSpecialMinions()
			self:LaneClear()
			self:JungleClear()
		else
			self:LastHit()
			self:FarmHarass()
		end
	elseif Mode == "LastHit" then
		self:LastHit()
	end
end

function ClassicEzreal:SemiR()
	if Menu.Combo.SemiR:Value() and IsReady(_R) then
		local target = GetTarget(3000)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastR(target)
		end
	end
end

function ClassicEzreal:Combo()
	local target = GetTarget(self.WSpell.Range)
	if IsValid(target) and target.pos:ToScreen().onScreen then
		if Menu.Combo.W:Value() and IsReady(_W) then
			self:CastW(target)
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			local inAARange = _G.SDK.Data:IsInAutoAttackRange(myHero, target)
        	local aaDamage = _G.SDK.Damage:GetAutoAttackDamage(myHero, target)	
        	local canKillWithAA = inAARange and _G.SDK.Orbwalker:CanAttack() and aaDamage >= target.health + target.shieldAD + target.hpRegen
			local aaWillKillTarget = self:WasMyRecentKillAATarget(target)
        	if not canKillWithAA and not aaWillKillTarget then
				self:CastQ(target)
			end
		end
	end
end

function ClassicEzreal:Harass()
	--if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			if Menu.Harass.Q:Value() and IsReady(_Q) then
				self:CastQ(target)
			end
			if Menu.Harass.W:Value() and IsReady(_W) then
				self:CastW(target)
			end
		end
	--end
end

function ClassicEzreal:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function ClassicEzreal:LaneClear()
	if not IsReady(_Q) or not Menu.Clear.SpellFarm:Value() or not Menu.Clear.LaneClear.Q:Value() then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	if #minions == 0 then return end
	table.sort(minions, function(a, b) return a.distance < b.distance end)
	local target = nil
	local isKillShot = false
	for i, m in ipairs(minions) do
		local isCannon = m.charName and m.charName:find("Siege")
		local shouldSkipAATarget = isCannon and self:WasMyRecentKillAATarget(m) or self:WasMyRecentAATarget(m)
		if IsValid(m) and m.pos2D.onScreen and m.team ~= 300 and not shouldSkipAATarget then
			local t = m.distance / self.QSpell.Speed + self.QSpell.Delay
			local hp = _G.SDK.HealthPrediction:GetPrediction(m, t)
			local QDmg = self:GetQDmg(m)
			if hp > 0 and hp <= QDmg then
				local _, _, coll = GGPrediction:GetCollision(myHero.pos, m.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius / 2, {GGPrediction.COLLISION_MINION}, m.networkID)
				if coll == 0 then
					target = m
					isKillShot = true
					break
				end
			end
			if not target and i == 1 and not isCannon and hp > QDmg and not IsUnderAllyTurret(m) then
				target = m
				isKillShot = false
				break
			end
		end
	end
	if IsValid(target) and IsReady(_Q) then
		if Control.CastSpell(HK_Q, target) then
			if isKillShot then
				local flyTime = (target.distance / self.QSpell.Speed + self.QSpell.Delay) * 1000
				self.lastQTarget = target.handle
				self.lastQExpire = GetTickCount() + flyTime + 100
			end
		end
	end
end

function ClassicEzreal:ClearSpecialMinions()
	if not IsReady(_Q) or not Menu.Clear.LaneClear.QSpecial:Value() then return end
	local plants = _G.SDK.ObjectManager:GetPlants(self.QSpell.Range)
	if #plants == 0 then return end
	table.sort(plants, function(a, b) return a.distance < b.distance end)
	for _, p in ipairs(plants) do
		if IsValid(p) then
			local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, p.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius/2, {GGPrediction.COLLISION_MINION}, p.networkID)
			if collisionCount == 0 and IsReady(_Q) then
				Control.CastSpell(HK_Q, p)
				return
			end
		end
	end
end

function ClassicEzreal:JungleClear()
	--if myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and 
	if Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetMonsters(800)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function ClassicEzreal:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen and not _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
				local timeToHit = minion.distance / self.QSpell.Speed + self.QSpell.Delay
				local Hp = _G.SDK.HealthPrediction:GetPrediction(minion, timeToHit)
				local QDmg = self:GetQDmg(minion)
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius/2, {GGPrediction.COLLISION_MINION}, minion.networkID)
				if Hp > 0 and QDmg >= Hp and collisionCount == 0 then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function ClassicEzreal:AutoR()
	if not IsReady(_R) or GetEnemyCount(800, myHero.pos) ~= 0 then return end
	for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(3000)) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.Auto.RCC:Value() and IsHardCC(enemy) then
				self:CastR(enemy)
				return
			end
			if Menu.Auto.RKill:Value() and not HaveBuff(enemy, "sionpassivezombie") then
				local Dmg = self:GetRDmg(enemy) + self:GetWDmg(enemy)
				if Dmg > enemy.health + enemy.shieldAD + enemy.hpRegen * 3 and myHero.pos:DistanceTo(enemy.pos) > self.QSpell.Range then
					if GetAllyCount(500, enemy.pos) == 0 and self.lastQ + 600 < GetTickCount() then
						self:CastR(enemy)
						return
					end
				end
			end
		end
	end		
	if Menu.Auto.RAOE:Value() then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		local aoeResults = RPrediction:GetAOEPrediction(myHero)
		local bestResult = nil
		for i = 1, #aoeResults do
			local result = aoeResults[i]
			if result.Count >= Menu.Auto.RCount:Value() then
				if not bestResult or result.Count > bestResult.Count then
					bestResult = result
				end
			end
		end
		if bestResult and Vector(bestResult.CastPosition):To2D().onScreen and myHero.pos:DistanceTo(bestResult.CastPosition) < 3000 then
			Control.CastSpell(HK_R, bestResult.CastPosition)
			return
		end
	end
end

function ClassicEzreal:WasMyRecentAATarget(unit)
	return IsValid(unit) and self.lastAATarget == unit.handle and GetTickCount() <= self.lastAAExpire
end

function ClassicEzreal:WasMyRecentKillAATarget(unit)
	return self:WasMyRecentAATarget(unit) and self.lastAAWillKill
end

function ClassicEzreal:CanMyAAKill(unit, includeW)
	if not IsValid(unit) then return false end
	local aaDamage = _G.SDK.Damage:GetAutoAttackDamage(myHero, unit)
	local totalDamage = aaDamage
	if includeW then
		totalDamage = totalDamage + self:GetWDmg(unit)
	end
	return totalDamage >= unit.health + unit.shieldAD + unit.hpRegen
end

function ClassicEzreal:GetQDmg(unit)
	local qLevel = myHero:GetSpellData(_Q).level
	local dmg = (25 * qLevel + 15) + (1.1 * myHero.totalDamage)
	if qLevel > 0 then
		return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_PHYSICAL, dmg)
	else
		return 0
	end
end

function ClassicEzreal:GetWDmg(unit)
	local wLevel = myHero:GetSpellData(_W).level
	local dmg = (50 * wLevel + 30) + 0.6 * myHero.ap
	if wLevel > 0 then
		return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, dmg)
	else
		return 0
	end
end

function ClassicEzreal:GetRDmg(unit)
	local rLevel = myHero:GetSpellData(_R).level
	local dmg = (150 * rLevel + 200) + 1.0 * myHero.ap
	if rLevel > 0 then
		return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, dmg)
	else
		return 0
	end
end

function ClassicEzreal:CastQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		if Control.CastSpell(HK_Q, QPrediction.CastPosition) then
			self.lastQ = GetTickCount()
			return true
		end
	end
	return false
end

function ClassicEzreal:CastW(unit)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(unit, myHero)
	if WPrediction:CanHit(3) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function ClassicEzreal:CastR(unit)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(unit, myHero)
	if RPrediction:CanHit(3) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function ClassicEzreal:ELogic()
	if not Menu.EHelper.Enable:Value() then return end
	local timer = GetTickCount()
	if self.EHelper ~= nil then
		if _G.SDK.Cursor.Step == 0 then
			_G.SDK.Cursor:Add(self.EHelper, myHero.pos:Extended(Vector(mousePos), 600))
			self.EHelper = nil
		end
		return
	end
	if
		not (
			os.clock() < LastEFake + 0.5
			and Game.CanUseSpell(_E) == 0
			and not Control.IsKeyDown(HK_LUS)
			and not myHero.dead
			and not Game.IsChatOpen()
			and Game.IsOnTop()
		)
	then
		return
	end
	if self.LastE and timer < self.LastE + 1000 then
		return
	end
	if timer < LastChatOpenTimer + 1000 then
		return
	end
	if timer < LevelUpKeyTimer + 1000 then
		return
	end
	self.LastE = timer
	if _G.SDK.Cursor.Step == 0 then
		_G.SDK.Cursor:Add(Menu.EHelper.elol:Key(), myHero.pos:Extended(Vector(mousePos), 600))
		return
	end
	self.EHelper = Menu.EHelper.elol:Key()
end

function ClassicEzreal:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end

ClassicEzreal()