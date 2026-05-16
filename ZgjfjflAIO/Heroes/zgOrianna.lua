local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

local function GetAllyTurrets()
	return _G.SDK.ObjectManager:GetAllyTurrets()
end

local function IsUnderAllyTurret(unit)
	for i, turret in ipairs(GetAllyTurrets()) do
		local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
		if not turret.dead then 
			if turret.pos:DistanceTo(unit.pos) < range then
				return true
			end
		end
	end
	return false
end

local function IsUnderAllyTurret2(pos)
	for i, turret in ipairs(GetAllyTurrets()) do
		local range = (turret.boundingRadius + 750)
		if not turret.dead then 
			if turret.pos:DistanceTo(pos) < range then
				return true
			end
		end
	end
	return false
end

class "zgOrianna"

function zgOrianna:__init()		 
	print("Zgjfjfl AIO - Orianna Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:OnDraw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.05, Radius = 70, Range = 890, Speed = 1400, Collision = false}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 210, Range = 210, Speed = math.huge, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 1095, Speed = 1700, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.4, Radius = 325, Range = 360, Speed = math.huge, Collision = false}
	self.QRSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 400, Range = 825, Speed = 100, Collision = false}
	self.Ball = myHero
	self.BallPos = myHero.pos
	self.BallOnGround = false
	self.BallMoving = false
	self.Rsmart = false
	self.BestAlly = nil
	self.QMANA = 0
	self.WMANA = 0
	self.EMANA = 0
	self.RMANA = 0
end

function zgOrianna:LoadMenu()	
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	-- Draw Menu
	Menu:MenuElement({ id = "Draw", name = "Draw", type = MENU })
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({ id = "ballPos", name = "BallPos", value = true })
	Menu.Draw:MenuElement({ id = "qRange", name = "Q Range", value = false })
	Menu.Draw:MenuElement({ id = "wRange", name = "W Range", value = false })
	Menu.Draw:MenuElement({ id = "eRange", name = "E Range", value = false })
	Menu.Draw:MenuElement({ id = "rRange", name = "R Range", value = false })
	Menu.Draw:MenuElement({ id = "onlyRdy", name = "Draw Only Ready Spells", value = true })
	
	-- E Shield Config
	Menu:MenuElement({ id = "EConfig", name = "E Shield Config", type = MENU })
	Menu.EConfig:MenuElement({ id = "autoE", name = "Auto E", value = true })
	Menu.EConfig:MenuElement({ id = "hadrCC", name = "Auto E Hard CC", value = true })
	Menu.EConfig:MenuElement({ id = "poison", name = "Auto E Poison", value = true })
	Menu.EConfig:MenuElement({ id = "AGC", name = "AntiGapcloser E", value = true })
	
	-- Farm Menu
	Menu:MenuElement({ id = "Farm", name = "Farm", type = MENU })
	Menu.Farm:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4})
	Menu.Farm:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H")})
	Menu.Farm:MenuElement({ id = "farmQout", name = "Farm Q Out of AA Range", value = true })
	Menu.Farm:MenuElement({ id = "LCminions", name = "LaneClear minimum minions", value = 2, min = 0, max = 10, step = 1 })
	Menu.Farm:MenuElement({ id = "farmQ", name = "LaneClear Q", value = true })
	Menu.Farm:MenuElement({ id = "farmW", name = "LaneClear W", value = true })
	Menu.Farm:MenuElement({ id = "farmE", name = "LaneClear E", value = true })
	
	-- R Config
	Menu:MenuElement({ id = "RConfig", name = "R Config", type = MENU })
	Menu.RConfig:MenuElement({ id = "rCount", name = "Auto R X Enemies", value = 3, min = 0, max = 5, step = 1 })
	Menu.RConfig:MenuElement({ id = "smartR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu.RConfig:MenuElement({ id = "Rturrent", name = "Auto R Under Turret", value = true })
	Menu.RConfig:MenuElement({ id = "Rks", name = "R KS", value = false })
	Menu.RConfig:MenuElement({ id = "Rlifesaver", name = "Auto R Life Saver", value = true })
	
	-- Always R per Enemy
	Menu.RConfig:MenuElement({ id = "AlwaysR", name = "Always R", type = MENU })
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		Menu.RConfig.AlwaysR:MenuElement({ id = "Ralways" .. args.charName, name = args.charName, value = false })
	end)
		
	Menu:MenuElement({ id = "Flee", name = "Flee", type = MENU })
	Menu.Flee:MenuElement({id = "W", name = "Flee W", value = true})
	Menu.Flee:MenuElement({id = "E", name = "Flee mode E self", value = true})
end

function zgOrianna:OnTick()
	if ShouldWait() then
		return
	end
	self:UpdateBallPosition()
	if self.BallMoving then return end
	if IsCasting() then
		return
	end
	self:AntiGapcloser()
	self:AutoE()
	if IsReady(_R) then
		self:LogicR()
	end
	local hadrCC = Menu.EConfig.hadrCC:Value()
	local poison = Menu.EConfig.poison:Value()
	self:SetMana()
	self.BestAlly = myHero
	local allies = _G.SDK.ObjectManager:GetAllyHeroes(1500)
	for _, ally in ipairs(allies) do
		if IsValid(ally) then
			if IsReady(_E) and myHero.mana > self.RMANA + self.EMANA and ally.pos:DistanceTo(myHero.pos) < self.ESpell.Range then
				local countEnemy = GetEnemyCount(800, ally.pos)
				if ally.health < countEnemy * ally.levelData.lvl * 25 then
					self:CastE(ally)
				elseif IsHardCC(ally) and hadrCC and countEnemy > 0 then
					self:CastE(ally)
				elseif IsPoison(ally) and poison then
					self:CastE(ally)
				end
			end
			if IsReady(_W) and myHero.mana > self.RMANA + self.WMANA and GetDistance(self.BallPos, ally.pos) < 240 and ally.health < GetEnemyCount(600, ally.pos) * ally.levelData.lvl * 20 then
				Control.CastSpell(HK_W)
			end
			if (ally.health < self.BestAlly.health or GetEnemyCount(300, ally.pos) > 0) and ally.pos:DistanceTo(myHero.pos) < self.ESpell.Range and GetEnemyCount(700, ally.pos) > 0 then
				self.BestAlly = ally
			end
			if IsReady(_E) and myHero.mana > self.RMANA + self.EMANA and ally.pos:DistanceTo(myHero.pos) < self.ESpell.Range and GetEnemyCount(self.RSpell.Radius, ally.pos) >= Menu.RConfig.rCount:Value() and Menu.RConfig.rCount:Value() ~= 0 then
				self:CastE(ally)
			end
		end
	end
	if (Menu.RConfig.smartR:Value() or self.Rsmart) and IsReady(_R) then
		self.Rsmart = true
		local enemiesNearBall = self:CountEnemiesInRangeDelay(self.BallPos, self.RSpell.Radius, self.RSpell.Delay)
		if enemiesNearBall > 0 then
			Control.CastSpell(HK_R)
		else
			local target = GetTarget(self.QSpell.Range + 100)
			if IsValid(target) and IsReady(_Q) then
				Control.CastSpell(HK_Q, target:GetPrediction(self.QRSpell.Speed, self.QRSpell.Delay))
			else
				self.Rsmart = false
			end
		end
	else
		self.Rsmart = false
	end
	self:LogicQ()
	self:LogicFarm()
	if IsReady(_W) then
		self:LogicW()
	end
	if IsReady(_E) then
		self:LogicE(self.BestAlly)
	end
	if GetMode() == "Flee" then
		self:Flee()
	end
end

function zgOrianna:CastE(unit)
	if unit.isMe then
		Control.KeyDown(0x12)  -- Alt key
		Control.KeyDown(HK_E)
		Control.KeyUp(HK_E)
		Control.KeyUp(0x12)
	else
		Control.CastSpell(HK_E, unit)
	end
end

function zgOrianna:Flee()
	if HaveBuff(myHero, "orianaghostself") then
		if Menu.Flee.W:Value() and IsReady(_W) then
			Control.CastSpell(HK_W)
		end
	else
		if Menu.Flee.E:Value() and IsReady(_E) then
			self:CastE(myHero)
		end
	end
end

function zgOrianna:CountEnemiesInRangeDelay(pos, range, delay)
	local count = 0
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2000)
	for _, hero in ipairs(enemies) do
		if IsValid(hero) then
			local pred = hero:GetPrediction(math.huge, delay)
			if GetDistance(pos, pred) < range then
				count = count + 1
			end
		end
	end
	return count
end

function zgOrianna:SetMana()
	if myHero.health/myHero.maxHealth < 0.2 then
		self.QMANA = 0
		self.WMANA = 0
		self.EMANA = 0
		self.RMANA = 0
		return
	end

	self.QMANA = myHero:GetSpellData(_Q).mana
	self.WMANA = myHero:GetSpellData(_W).mana
	self.EMANA = myHero:GetSpellData(_E).mana
	self.RMANA = Game.CanUseSpell(_R) == 0 and myHero:GetSpellData(_R).mana or (self.QMANA - myHero.mpRegen * myHero:GetSpellData(_Q).cd)
end
local frameCounter = 0
function zgOrianna:UpdateBallPosition()
	frameCounter = frameCounter + 1
	if frameCounter < 3 then
		return
	end
	frameCounter = 0
	if self.BallOnGround then
		if self.Ball and self.Ball.name and string.find(self.Ball.name, "_Q_yomu_ring_green") then
			return
		end
		self.BallOnGround = false
	end
	if self:CheckBallOnHeroes() then
		return
	end
	if self:CheckBallInMissiles() then
		return
	end
	if self:CheckBallOnGround() then
		return
	end
end

function zgOrianna:CheckBallOnHeroes()
	if HaveBuff(myHero, "orianaghostself") then
		self.Ball = myHero
		self.BallPos = myHero.pos
		self.BallOnGround = false
		self.BallMoving = false
		return true
	end
	local allies = _G.SDK.ObjectManager:GetAllyHeroes(1300)
	for _, ally in ipairs(allies) do
		if IsValid(ally) and not ally.isMe and HaveBuff(ally, "orianaghost") then
			self.Ball = ally
			self.BallPos = ally.pos
			self.BallOnGround = false
			self.BallMoving = false
			return true
		end
	end
	return false
end

function zgOrianna:CheckBallInMissiles()
	local missileCount = Game.MissileCount()
	local searchRadius = 1300
	local mePos = myHero.pos
	local ballMissiles = {
		["OrianaIzuna"] = true,  -- Q missile
		["OrianaRedact"] = true  -- E missile
	}
	for i = missileCount, 1, -1 do
		local mis = Game.Missile(i)
		if mis and mis.pos and GetDistance(mePos, mis.pos) <= searchRadius then
			local name = mis.missileData and mis.missileData.name
			if name and ballMissiles[name] then
				self.Ball = mis
				self.BallPos = mis.pos
				self.BallOnGround = false
				self.BallMoving = true
				return true
			end
		end
	end
	return false
end

function zgOrianna:CheckBallOnGround()
	local particleCount = Game.ParticleCount()
	local searchRadius = 1300
	local mePos = myHero.pos
	for i = particleCount, 1, -1 do
		local par = Game.Particle(i)
		if par and par.pos and GetDistance(mePos, par.pos) < searchRadius then
			if par.name and string.find(par.name, "_Q_yomu_ring_green") then
				self.Ball = par
				self.BallPos = par.pos
				self.BallOnGround = true
				self.BallMoving = false
				return true
			end
		end
	end
	return false
end

function zgOrianna:AntiGapcloser()
	if Menu.EConfig.AGC:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(800)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and IsFacingMe(target) then
				self:CastE(myHero)
			end	
		end
	end
end

function zgOrianna:CastQ(target)
	local distance = GetDistance(self.BallPos, target.pos)
	if IsReady(_E) and myHero.mana > self.RMANA + self.QMANA + self.WMANA + self.EMANA and distance > myHero.pos:DistanceTo(target.pos) + 300 then
		self:CastE(myHero)
		return
	end
	local pred = GGPrediction:SpellPrediction(self.QSpell)
	pred:GetPrediction(target, self.BallPos)
	if pred:CanHit(3) then
		local castPos = Vector(myHero.pos):Extended(Vector(pred.CastPosition), 815)
		if target.distance > 815 then
			Control.CastSpell(HK_Q, castPos)
		else
			Control.CastSpell(HK_Q, pred.CastPosition)
		end
	end
end

function zgOrianna:LogicQ()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) and IsReady(_Q) then
		local qDmg = self:GetQDmg(target)
		local wDmg = Game.CanUseSpell(_W) == 0 and self:GetWDmg(target) or 0
		if qDmg + wDmg > target.health then
			self:CastQ(target)
		elseif GetMode() == "Combo" and myHero.mana > self.RMANA + self.QMANA - 10 then
			self:CastQ(target)
		elseif (GetMode() == "LaneClear" and Menu.Farm.SpellHarass:Value() or GetMode() == "Harass") and myHero.mana > self.RMANA + self.QMANA + self.WMANA + self.EMANA then
			self:CastQ(target) 
		end
	end
end

function zgOrianna:LogicW()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2000)
	for _, hero in ipairs(enemies) do
		if IsValid(hero) and GetDistance(self.BallPos, hero.pos) < 250 then
			local wDmg = self:GetWDmg(hero)
			if hero.health < wDmg then
				Control.CastSpell(HK_W)
				return
			end
		end
	end

	if self:CountEnemiesInRangeDelay(self.BallPos, self.WSpell.Radius, 0) > 0 and myHero.mana > self.RMANA + self.WMANA then
		Control.CastSpell(HK_W)
		return
	end
end

function zgOrianna:LogicE(best)
	local target = GetTarget(1300)
	if GetMode() == "Combo" and IsValid(target) and not IsReady(_W) and myHero.mana > self.RMANA + self.EMANA then
		if self:CountEnemiesInRangeDelay(self.BallPos, 100, 0.1) > 0 then
			self:CastE(best)
		end
		local castArea = target.pos:Extended(best.pos, target.pos:DistanceTo(best.pos))
		if GetDistance(castArea, target.pos) < target.boundingRadius / 2 then
			self:CastE(best)
		end
	end
end

function zgOrianna:AutoE()
	if Menu.EConfig.autoE:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2500)
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.ESpell.Range)
		local turrets = _G.SDK.ObjectManager:GetEnemyTurrets(1500)
		for _, ally in ipairs(allies) do
			if IsValid(ally) then
				local canuse = false
				if IsPoison(ally) then
					canuse = true
				else
					for _, enemy in ipairs(enemies) do
						if IsValid(enemy) then
							local spell = enemy.activeSpell
							if enemy.valid then 
								if spell.target == ally.handle then
									canuse = true
									break
								else
									local endPos = spell.startPos:Extended(spell.placementPos, spell.range + spell.width)
									local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, endPos, enemy.pos)
									local width = ally.boundingRadius + (spell.width > 0 and spell.width or 0)
									if isOnSegment and GGPrediction:IsInRange(point, ally.pos, width) then
										canuse = true
										break
									end
								end
							end
						end
					end
					if not canuse then
						for _, turret in ipairs(turrets) do
							if turret and turret.targetID == ally.networkID then
								canuse = true
								break
							end
						end
					end
				end
				if canuse then
					self:CastE(ally)
					break
				end
			end
		end
	end
end

function zgOrianna:LogicR()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2000)
	for _, hero in ipairs(enemies) do
		if IsValid(hero) then
			local pred = hero:GetPrediction(math.huge, self.RSpell.Delay)
			if GetDistance(self.BallPos, pred) < self.RSpell.Radius and GetDistance(self.BallPos, hero.pos) < self.RSpell.Radius then
				if GetMode() == "Combo" and Menu.RConfig.AlwaysR["Ralways" .. hero.charName] and Menu.RConfig.AlwaysR["Ralways" .. hero.charName]:Value() then
					Control.CastSpell(HK_R)
				end

				if Menu.RConfig.Rks:Value() then
					local comboDmg = self:GetRDmg(hero)
					if hero.pos:DistanceTo(myHero.pos) < self.QSpell.Range then
						comboDmg = comboDmg + self:GetQDmg(hero)
					end
					if IsReady(_W) then
						comboDmg = comboDmg + self:GetWDmg(hero)
					end
					if _G.SDK.Data:IsInAutoAttackRange(myHero, hero) then
						comboDmg = comboDmg + _G.SDK.Damage:GetAutoAttackDamage(myHero, hero) * 2
					end
					if hero.health < comboDmg then
						Control.CastSpell(HK_R)
					end
				end

				if Menu.RConfig.Rturrent:Value() and IsUnderAllyTurret2(self.BallPos) and IsUnderAllyTurret(hero) then
					Control.CastSpell(HK_R)
				end

				if Menu.RConfig.Rlifesaver:Value() and myHero.health < GetEnemyCount(800, myHero.pos) * myHero.levelData.lvl * 20 and myHero.pos:DistanceTo(self.BallPos) > hero.pos:DistanceTo(myHero.pos) then
					Control.CastSpell(HK_R)
				end
			end
		end
	end

	local countEnemies = self:CountEnemiesInRangeDelay(self.BallPos, self.RSpell.Radius, self.RSpell.Delay)
	if countEnemies >= Menu.RConfig.rCount:Value() and GetEnemyCount(self.RSpell.Radius, self.BallPos) == countEnemies then
		Control.CastSpell(HK_R)
	end
end

function zgOrianna:LogicFarm()
	if GetMode() ~= "LaneClear" then return end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	if Menu.Farm.farmQout:Value() and IsReady(_Q) and myHero.mana > self.RMANA + self.QMANA + self.WMANA + self.EMANA then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 then
				local qDmg = self:GetQDmg(minion)
				if not _G.SDK.Data:IsInAutoAttackRange(myHero, minion) and minion.health < qDmg then
					Control.CastSpell(HK_Q, minion.pos)
				end
			end
		end
	end
	if Menu.Farm.SpellFarm:Value() --[[and myHero.mana/myHero.maxMana >= Menu.Farm.Mana:Value() / 100 ]]then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 then
				if Menu.Farm.farmQ:Value() and IsReady(_Q) and GetMinionCount(145, minion.pos) >= Menu.Farm.LCminions:Value() then
					Control.CastSpell(HK_Q, minion)
				end
			end
			if Menu.Farm.farmW:Value() and IsReady(_W) and GetDistance(self.BallPos, minion.pos) < self.WSpell.Radius and minion.health < self:GetWDmg(minion) then
				Control.CastSpell(HK_W)
			end
			if Menu.Farm.farmE:Value() and not IsReady(_W) and IsReady(_E) and GetDistance(self.BallPos, minion.pos) < self.ESpell.Radius then
				self:CastE(myHero)
			end
		end
	end
	if myHero.mana < self.RMANA + self.QMANA then return end
	local mobs = _G.SDK.ObjectManager:GetMonsters(800)
	if #mobs > 0 then
		local mob = mobs[1]
		if IsReady(_Q) then
			Control.CastSpell(HK_Q, mob.pos)
		end
		if IsReady(_W) and GetDistance(self.BallPos, mob.pos) < self.WSpell.Radius then
			Control.CastSpell(HK_W)
		elseif IsReady(_E) then
			self:CastE(self.BestAlly)
		end
		return
	end
end

function zgOrianna:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({60, 90, 120, 150, 180})[level] + 0.55 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function zgOrianna:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	local WDmg = ({70, 110, 150, 190, 230})[level] + 0.8 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
end

function zgOrianna:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({60, 90, 120, 150, 180})[level] + 0.3 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgOrianna:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	local RDmg = ({250, 400, 550})[level] + 0.95 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function zgOrianna:OnDraw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Farm.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Farm.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end
	if not self.BallPos then
		return
	elseif Menu.Draw.ballPos:Value() then
		Draw.Circle(self.BallPos, 50, 3, Draw.Color(255, 191, 0, 255))
	end

	if Menu.Draw.wRange:Value() then
		if Menu.Draw.onlyRdy:Value() and IsReady(_W) or not Menu.Draw.onlyRdy:Value() then
			Draw.Circle(self.BallPos, self.WSpell.Range, 1, Draw.Color(255, 255, 165, 0)) -- Orange
		end
	end

	if Menu.Draw.rRange:Value() then
		if Menu.Draw.onlyRdy:Value() and IsReady(_R) or not Menu.Draw.onlyRdy:Value() then
			Draw.Circle(self.BallPos, self.RSpell.Range, 1, Draw.Color(255, 128, 128, 128)) -- Gray
		end
	end

	if Menu.Draw.qRange:Value() then
		if Menu.Draw.onlyRdy:Value() and IsReady(_Q) or not Menu.Draw.onlyRdy:Value() then
			Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 0, 255, 255)) -- Cyan
		end
	end

	if Menu.Draw.eRange:Value() then
		if Menu.Draw.onlyRdy:Value() and IsReady(_E) or not Menu.Draw.onlyRdy:Value() then
			Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 255, 255, 0)) -- Yellow
		end
	end
end

zgOrianna()
