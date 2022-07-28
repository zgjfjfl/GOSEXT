
local Heroes ={"Ornn", "JarvanIV", "Poppy"}

require "GGPrediction"
require "2DGeometry"
require "MapPositionGOS"

local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local GameMinionCount     = Game.MinionCount
local GameMinion          = Game.Minion

local orbwalker         = _G.SDK.Orbwalker
local HealthPrediction         = _G.SDK.HealthPrediction


local function isSpellReady(spell)
    return  myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and Game.CanUseSpell(spell) == 0
end

local function getDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

local function getDistance(Pos1, Pos2)
    return math.sqrt(getDistanceSqr(Pos1, Pos2))
end

local function getEnemyHeroes()
    local EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy and not Hero.dead then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

local function getEnemyMinionsWithinDistanceOfLocation(location, distance)
    local EnemyMinions = {}
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and not minion.dead and minion.pos:DistanceTo(location) < distance then
            table.insert(EnemyMinions, minion)
        end
    end
    return EnemyMinions
end

local function getAOEMinion(maxRange, abilityRadius) 
    local bestCount = 0
    local bestPosition = nil
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        local count = 0
        if minion and not minion.dead and minion.isEnemy and myHero.pos:DistanceTo(minion.pos) < maxRange then 
            local count = #getEnemyMinionsWithinDistanceOfLocation(minion.pos, abilityRadius)
            if count > bestCount then
                bestCount = count
                bestPosition = minion.pos
            end
        end
    end
    return bestPosition, bestCount
end

local function castSpell(spellData, hotkey, target)
    local pred = GGPrediction:SpellPrediction(spellData)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_NORMAL) then
        if myHero.pos:DistanceTo(pred.CastPosition) <= spellData.Range + 15 then
            Control.CastSpell(hotkey, pred.CastPosition)	
        end
    end
end

local function castSpellHigh(spellData, hotkey, target)
    local pred = GGPrediction:SpellPrediction(spellData)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
        Control.CastSpell(hotkey, pred.CastPosition)	
    end
end


------------------------------------

class "Ornn"
        
function Ornn:__init()	     
    print("Zgjfjfl-Ornn Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 750, Speed = 1800, Collision = false}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 175, Range = 500, Speed = math.huge, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 180, Range = 800, Speed = 1600, Collision = false}

  end

function Ornn:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgOrnn", name = "Zgjfjfl Ornn"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EQ", name = "[E] to Q", toggle = true, value = true})
	self.Menu.Combo:MenuElement({id = "EWall", name = "[E] to Wall", toggle = true, value = true})
	self.Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min = 0, max = 300, value = 300})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})

end

function Ornn:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
   
end

function Ornn:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    if target then
	
	local qcastpos = myHero.pos + (target.pos - myHero.pos):Normalized() * self.qSpell.Range
        local ecastpos = myHero.pos + (target.pos - myHero.pos):Normalized() * self.eSpell.Range
        local objpos = target.pos:Extended(myHero.pos, -self.Menu.Combo.ED:Value())
        local lineE = LineSegment(target.pos, objpos)

        if not MapPosition:intersectsWall(lineE) then
            if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
	       if isSpellReady(_E) and self.Menu.Combo.EQ:Value() then
                    DelayAction(function()
                        Control.CastSpell(HK_E, qcastpos)
                    end, 1.4
                    )
	       end
            end
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
            castSpellHigh(self.wSpell, HK_W, target)
        end

        if MapPosition:inWall(ecastpos) and MapPosition:intersectsWall(lineE) and self.Menu.Combo.EWall:Value() and isSpellReady(_E) then
            Control.CastSpell(HK_E, ecastpos)
        end
    end
end	

function Ornn:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if self.Menu.Clear.W:Value() and isSpellReady(_W) then
            bestPosition, bestCount = getAOEMinion(self.wSpell.Range, self.wSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_W, bestPosition)
            end
        end
    end
end

function Ornn:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    if target then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end
        if self.Menu.Harass.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
            castSpellHigh(self.wSpell, HK_W, target)
        end
    end
end

function Ornn:Draw()
   if self.Menu.Draw.Q:Value() and isSpellReady(_Q)then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E)then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------
class "JarvanIV"
        
function JarvanIV:__init()	     
    print("Zgjfjfl-JarvanIV Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 90, Range = 785, Speed = math.huge, Collision = false}
    self.wSpell = { Range = 600 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 200, Range = 860, Speed = math.huge, Collision = false}
  end

function JarvanIV:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgJarvanIV", name = "Zgjfjfl JarvanIV"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "EQ", name = "[EQ]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})



end

function JarvanIV:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
   
end

function JarvanIV:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    if target then

        local pred = GGPrediction:SpellPrediction(self.eSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -50)
            if self.Menu.Combo.E:Value() and isSpellReady(_E) then
                Control.CastSpell(HK_E, castPos)
	            if isSpellReady(_Q) then
                    DelayAction(function()
                        Control.CastSpell(HK_Q, castPos)
                    end, 0.1
                    )
				end
			end
        end	
		        
		if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and not isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
            Control.CastSpell(HK_W)
        end
		
    end
end	

function JarvanIV:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_Q, bestPosition)
            end
        end
    end
end

function JarvanIV:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    if target then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end

    end
end

function JarvanIV:Flee()
    if self.Menu.Flee.EQ:Value() and isSpellReady(_Q) and isSpellReady(_E) then
        local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.qSpell.Range
            Control.CastSpell(HK_E, pos)
            DelayAction(function()
                Control.CastSpell(HK_Q, pos)
            end, 0.1
            )
    end
end

function JarvanIV:Draw()
   if self.Menu.Draw.Q:Value() and isSpellReady(_Q)then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E)then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------

class "Poppy"
        
function Poppy:__init()	     
    print("Zgjfjfl-Poppy Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 430, Speed = math.huge, Collision = false}
    self.eSpell = { Range = 475 }
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 450, Speed = 2500, Collision = false}
    self.r2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 1200, Speed = 2500, Collision = false}
  end

function Poppy:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgPoppy", name = "Zgjfjfl Poppy"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min =0, max = 400, value = 400})
        self.Menu.Combo:MenuElement({id = "RF", name = "[R] Fast", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RFHP", name = "[R] Fastcast on target HP %", value = 30, min=0, max = 100 })
        self.Menu.Combo:MenuElement({id = "RM", name = "[R] Slowcast Semi-Manual Key", key = string.byte("T")})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "W", name = "W Setting "})
        self.Menu.W:MenuElement({type = MENU, id = "WB", name = "Auto W If Enemy dash on ME"})
            DelayAction(function()
                for i, Hero in pairs(getEnemyHeroes()) do
                    self.Menu.W.WB:MenuElement({id = Hero.charName, name =Hero.charName, value = false})		
                end		
            end,0.2)
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Poppy:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if isSpellReady(_W) then
        self:AutoW()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end

end

function Poppy:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    if target then
	
        local endPos = target.pos:Extended(myHero.pos, -self.Menu.Combo.ED:Value())				
        if MapPosition:inWall(endPos) and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
            Control.CastSpell(HK_E, target)
        end
				        
        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end
		
        if self.Menu.Combo.RF:Value() and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and target.health/target.maxHealth <= self.Menu.Combo.RFHP:Value()/100 then
                Control.KeyDown(HK_R)
                if Control.IsKeyDown(HK_R) then
                    Control.SetCursorPos(target)
                    DelayAction(function() Control.SetCursorPos(mousePos) end, 0.1)
                    DelayAction(function() Control.KeyUp(HK_R) end, 0.1)

                end
        end
    end
end	

function Poppy:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_Q, bestPosition)
            end
        end
    end
end

function Poppy:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    if target then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end

    end
end

function Poppy:AutoW()

    local target = _G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    if target then
    local blockobj = self.Menu.W.WB[target.charName] and self.Menu.W.WB[target.charName]:Value()
        if blockobj and target.pathing.isDashing then
        local vct = Vector(target.pathing.endPos.x, target.pathing.endPos.y, target.pathing.endPos.z)
            if vct:DistanceTo(myHero.pos) < 400 then
                Control.CastSpell(HK_W)
            end
        end
    end
end

function Poppy:RSemiManual()
    local target = _G.SDK.TargetSelector:GetTarget(self.r2Spell.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    if target then
        if isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < self.r2Spell.Range then
                Control.KeyDown(HK_R)
                if Control.IsKeyDown(HK_R) then
                    Control.SetCursorPos(target)
                    DelayAction(function() Control.SetCursorPos(mousePos) end, 1)
                    DelayAction(function() Control.KeyUp(HK_R) end, 1)
                end
        end
    end
end


function Poppy:Draw()
   if self.Menu.Draw.Q:Value() and isSpellReady(_Q)then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E)then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R)then
            Draw.Circle(myHero.pos, self.r2Spell.Range, Draw.Color(192, 255, 255, 255))
    end

end


------------------------------

function onLoadEvent()
    if table.contains(Heroes, myHero.charName) then
		_G[myHero.charName]()
    end
end


Callback.Add('Load', onLoadEvent)
