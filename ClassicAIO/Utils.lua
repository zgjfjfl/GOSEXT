local Version = 2.01

lastQ, lastW, lastE, lastR = 0, 0, 0, 0

local blockFlag = false -- Prevent recursive callback
function CheckChatBlock(menuElement, newValue) -- Block menu toggle when chat is open
    if Game.IsChatOpen() and not blockFlag then
        blockFlag = true
        if menuElement then
            menuElement:Value(not newValue)
        end
        blockFlag = false
        return true
    end
    return false
end

function IsReady(spell)
	local spellData = myHero:GetSpellData(spell)
	return spellData.currentCd == 0 and spellData.level > 0 and spellData.mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function IsValid(unit)
	return unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.health > 0 and not unit.dead
end

function GetDistanceSqr(Pos1, Pos2)
	local Pos2 = Pos2 or myHero.pos
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx^2 + dz^2
end

function GetDistance(Pos1, Pos2)
	return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function GetEnemyHeroes()
	local EnemyHeroes = {}
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isEnemy and not Hero.dead then
			table.insert(EnemyHeroes, Hero)
		end
	end
	return EnemyHeroes
end

function IsUnderTurret(unit)
	for _, turret in ipairs(_G.SDK.ObjectManager:GetEnemyTurrets()) do
		local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
		if not turret.dead then
			if turret.pos:DistanceTo(unit.pos) < range then
				return true
			end
		end
	end
	return false
end

function IsUnderTurret2(pos)
	for _, turret in ipairs(_G.SDK.ObjectManager:GetEnemyTurrets()) do
		local range = (turret.boundingRadius + 750)
		if not turret.dead then
			if turret.pos:DistanceTo(pos) < range then
				return true
			end
		end
	end
	return false
end

local HardCCTypes = {[5] = true, [8] = true, [9] = true, [12] = true, [23] = true, [25] = true, [29] = true, [30] = true, [35] = true}

local function GetBuffs(unit)
	return _G.SDK.BuffManager:GetBuffs(unit)
end

function HaveBuff(unit, buffName)
	buffName = buffName:lower()
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name and buff.name:lower() == buffName then
			return true
		end
	end
	return false
end

function HasBuffContainsName(unit, name)
	name = name:lower()
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name and buff.name:lower():find(name, 1, true) then
			return true
		end
	end
	return false
end

function HaveBuffContainsNameNums(unit, name)
	name = name:lower()
	local count = 0
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name and buff.name:lower():find(name, 1, true) then
			count = count + buff.count
		end
	end
	return count
end

function GetBuffData(unit, buffName)
	buffName = buffName:lower()
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name and buff.name:lower() == buffName then
			return true, buff
		end
	end
	return false, {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

function GetEnemyCount(range, unit)
	local count = 0
	local Range = range * range
	for _, hero in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
		if IsValid(hero) and GetDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

function GetMinionCount(range, unit)
	local count = 0
	local Range = range * range
	for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions()) do
		if IsValid(minion) and GetDistanceSqr(unit, minion.pos) < Range then
			count = count + 1
		end
	end
	return count
end

function GetAllyCount(range, unit)
	local count = 0
	local Range = range * range
	for _, hero in ipairs(_G.SDK.ObjectManager:GetAllyHeroes()) do
		if IsValid(hero) and GetDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

function IsHardCC(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if HardCCTypes[buff.type] then
			return true
		end
	end
	return false
end

function GetHardCCDuration(unit)
	local MaxDuration = 0
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if HardCCTypes[buff.type] then
			local BuffDuration = buff.duration
			if BuffDuration > MaxDuration then
				MaxDuration = BuffDuration
			end
		end
	end
	return MaxDuration
end

function IsInvulnerable(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.type == 18 then
			return true
		end
	end
	return false
end

function IsSlow(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.type == 11 then
			return true
		end
	end
	return false
end

function IsPoison(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.type == 13 or buff.type == 24 then
			return true
		end
	end
	return false
end

function Recalling(unit)
	local as = unit.activeSpell
	if as and as.valid and as.name:lower():find("recall") then
		return true
	end
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.name:lower():find("recall") then
			return true
		end
	end
	return false
end

function HasInvalidDashBuff(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		if buff.type == 30 or buff.type == 31 or buff.name == "ThreshQ" then
			return true
		end
	end
	return false
end

function GetMode()
	return _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "LaneClear"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "LaneClear"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit"
		or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee"
		or nil
end

function GetTarget(range)
	local dmgType = myHero.ap > myHero.totalDamage and _G.SDK.DAMAGE_TYPE_MAGICAL or _G.SDK.DAMAGE_TYPE_PHYSICAL
	return _G.SDK.TargetSelector:GetTarget(range, dmgType)
end

function IsFacingMe(unit)
	local V = Vector((unit.pos - myHero.pos))
	local D = Vector(unit.dir)
	local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
	if math.abs(Angle) < 90 then
		return true
	end
	return false
end

function CircleCircleIntersection(c1, c2, r1, r2)
	local D = GetDistance(c1,c2)
	if D > r1 + r2 or D <= math.abs(r1 - r2) then return nil end
	local A = (r1 * r1 - r2 * r2 + D * D) / (2 * D)
	local H = math.sqrt(r1 * r1 - A * A)
	local Direction = (c2 - c1):Normalized()
	local PA = c1 + A * Direction
	local S1 = PA + H * Direction:Perpendicular()
	local S2 = PA - H * Direction:Perpendicular()
	return S1, S2
end

function FindFirstWallCollision(startPos, endPos)
	local direction = (endPos - startPos):Normalized()
	local distance = startPos:DistanceTo(endPos)
	local step = 10
	for i = 0, distance, step do
		local checkPos = startPos + direction * i
		if Game.isWall(checkPos) then
			return checkPos
		end
	end
	return nil
end

function FindFirstWallCollisionInRectangle(startPos, endPos, width)
	local direction = (endPos - startPos):Normalized()
	local distance = startPos:DistanceTo(endPos)
	local perpDirection = direction:Perpendicular()
	for i = 0, distance, 10 do
		local centerPos = startPos + direction * i
		for j = -width/2, width/2, 10 do
			local checkPos = centerPos + perpDirection * j
			if Game.isWall(checkPos) then
				return checkPos
			end
		end
	end
	return nil
end

function IsCasting()
	if myHero.activeSpell.valid then
		if myHero.activeSpell.isCharging or
			(Game.Timer() >= myHero.activeSpell.startTime and Game.Timer() <= myHero.activeSpell.castEndTime)
		then
			return true
		end
	end
	return false
end

local slots = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}
function HasItem(unit, itemId)
	for i = 1, #slots do
		local slot = slots[i]
		local item = unit:GetItemData(slot)
		if item and item.itemID == itemId then
			return true
		end
	end
	return false
end

function ShouldWait()
	return myHero.dead or Game.IsChatOpen() or
			(_G.JustEvade and _G.JustEvade:Evading()) or
			Recalling(myHero) or
			Control.IsKeyDown(0x11) or
			Control.IsKeyDown(0x12)
end

function CastSpellAOE(spellSlot, spellData, minHitCount, source, mainTarget)
	local SpellPred = GGPrediction:SpellPrediction(spellData)
	local aoeResults = SpellPred:GetAOEPrediction(source)
	if #aoeResults == 0 then
		return false
	end
	if mainTarget then
		for i, result in ipairs(aoeResults) do
			if result.Unit.networkID == mainTarget.networkID and result.Count >= minHitCount then
				if Control.CastSpell(spellSlot, result.CastPosition) then
					return true
				end
			end
		end
	end
	table.sort(aoeResults, function(a, b) return a.Count > b.Count end)
	for i, result in ipairs(aoeResults) do
		if result.Count >= minHitCount then
			if Control.CastSpell(spellSlot, result.CastPosition) then
				return true
			end
		end
	end
	return false
end

-- =====================================================================================

-- =====================================================================================
-- SECTION 3: Classic Activator (simplified, with per-item submenus)
-- =====================================================================================

local ItemKeys = {HK_ITEM_1, HK_ITEM_2, HK_ITEM_3, HK_ITEM_4, HK_ITEM_5, HK_ITEM_6}

-- Buff type ids
local BUFF_STUN, BUFF_SILENCE, BUFF_TAUNT              = 5, 7, 8
local BUFF_SLOW, BUFF_SNARE                            = 11, 12
local BUFF_SPELL_IMMUNE, BUFF_PHYS_IMMUNE              = 16, 17
local BUFF_FEAR, BUFF_CHARM, BUFF_SUPPRESS, BUFF_BLIND = 22, 23, 25, 26
local BUFF_FLEE                                        = 29
local BUFF_DAMAGE, BUFF_POISON                         = 13, 24

-- Classic item ids
local ITEM_DFG          = 773128
local ITEM_GUNBLADE     = 773146
local ITEM_CUTLASS      = 773144
local ITEM_BOTRK        = 773153
local ITEM_RANDUIN      = 773143
local ITEM_HYDRA        = 773074
local ITEM_TIAMAT       = 773077
local ITEM_TRUE_ICE     = 773092
local ITEM_SOTD         = 773131
local ITEM_YOUMUUS      = 773142
local ITEM_SHURELYAS    = 773069
local ITEM_TWIN_SHADOWS = 773023
local ITEM_OHMWRECKER   = 773056
local ITEM_LOCKET       = 773190
local ITEM_ZHONYAS      = 773157
local ITEM_SERAPH       = 773040
local ITEM_MIKAELS      = 773222
local ITEM_HP_POTION    = 772003
local ITEM_MANA_POTION  = 772004
local ITEM_BISCUIT      = 772009
local ITEM_FLASK        = 772041

local TrackedItems = {
	[ITEM_LOCKET] = "Defensive", [ITEM_ZHONYAS] = "Defensive", [ITEM_SERAPH] = "Defensive",
	[ITEM_RANDUIN] = "Defensive",
	[ITEM_MIKAELS] = "Utility",
	[ITEM_DFG] = "Offensive", [ITEM_GUNBLADE] = "Offensive", [ITEM_CUTLASS] = "Offensive",
	[ITEM_BOTRK] = "Offensive", [ITEM_HYDRA] = "Offensive",
	[ITEM_TIAMAT] = "Offensive", [ITEM_TRUE_ICE] = "Offensive", [ITEM_SOTD] = "Offensive",
	[ITEM_YOUMUUS] = "Offensive", [ITEM_SHURELYAS] = "Offensive", [ITEM_TWIN_SHADOWS] = "Offensive",
	[ITEM_OHMWRECKER] = "Offensive",
	[ITEM_HP_POTION] = "Consumable", [ITEM_MANA_POTION] = "Consumable",
	[ITEM_BISCUIT] = "Consumable", [ITEM_FLASK] = "Consumable",
}

local RegenBuffNames = {"regenerationpotion", "itemminiregenpotion", "itemcrystalflask", "flaskofcrystalwater"}

local SUM_SMITE    = "SummonerSmite_Jade"
local SUM_IGNITE   = "SummonerDot_Jade"

local SmiteCamps = {
	["s3_dragon"]       = "Dragon",
	["s3_baron"]        = "Baron",
	["s3_lizardelder"]  = "Red",
	["s3_ancientgolem"] = "Blue",
}

local DDRAGON = "https://ddragon.leagueoflegends.com/cdn/16.15.1/img/"

local ActivatorMenuLoaded = false
local ActivatorMenu = nil
local MenuLoadAttempts = 0
local MENU_LOAD_MAX_ATTEMPTS = 300
local LastItemCast = 0
local LastSummonerCast = 0
local CastDelay = 250

local OwnedItems = {}
local OwnedCategories = {Defensive = false, Utility = false, Offensive = false, Consumable = false}
local HasAnyTrackedItem = false
local LastInventoryScan = 0
local InventoryScanInterval = 500

local SummonerSlot = {}
local SummonerHotkey = {}
local SummonersResolved = false

-- ---------------------------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------------------------

local function ItemIcon(itemId)
	return DDRAGON .. "item/" .. itemId .. ".png"
end

local function SummonerIcon(name)
	return DDRAGON .. "spell/" .. name .. ".png"
end

local function OwnSummonerIcon()
	for name in pairs(SummonerSlot) do
		return SummonerIcon(name)
	end
	return SummonerIcon(SUM_SMITE)
end

local function SpellIcon(spellName)
	return DDRAGON .. "spell/" .. spellName .. ".png"
end

local function ChampIcon(charName)
	return DDRAGON .. "champion/" .. charName .. ".png"
end

local function HealthPercent(unit)
	return unit.maxHealth > 0 and unit.health / unit.maxHealth * 100 or 100
end

local function ManaPercent(unit)
	return unit.maxMana > 0 and unit.mana / unit.maxMana * 100 or 100
end

local function IsInBase()
	local baseX, baseY, baseZ
	if myHero.team == 100 then
		baseX, baseY, baseZ = 1044, 125, 770
	else
		baseX, baseY, baseZ = 14952, 125, 14700
	end
	return GetDistance(myHero.pos, {x = baseX, y = baseY, z = baseZ}) <= 1200
end

local function ShieldValue(unit)
	return (unit.shieldAD or 0) + (unit.shieldAP or 0)
end

local function HeroLevel(unit)
	return (unit.levelData and unit.levelData.lvl) or 1
end

local function ForEachAlly(range, fn)
	if fn(myHero) then return true end
	for _, ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes(range)) do
		if IsValid(ally) then
			if fn(ally) then return true end
		end
	end
	return false
end

local function HasBuffType(unit, buffType)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		if buffs[i].type == buffType then return true end
	end
	return false
end

local UndyingBuffNames = {
	["jade_kayler"]                 = true,
	["jade_zilean_chronoshift"]     = true,
	["jade_tryndamereundyingrage"]  = true,
	["jade_jaxe"]                   = true,
	["zhonyasringshield"]           = true,
}

local function HasUndyingBuff(unit)
	local buffs = GetBuffs(unit)
	for i = 1, #buffs do
		if UndyingBuffNames[buffs[i].name:lower()] then return true end
	end
	return false
end

local function HasRegenBuff(unit)
	for i = 1, #RegenBuffNames do
		if HasBuffContainsName(unit, RegenBuffNames[i]) then return true end
	end
	return false
end

local function ValidTarget(unit)
	return IsValid(unit) and not unit.isImmortal and not IsInvulnerable(unit) and not HasUndyingBuff(unit)
end

-- ---------------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------------

local function RefreshItemCache(force)
	local now = GetTickCount()
	if not force and LastInventoryScan > 0 and now < LastInventoryScan + InventoryScanInterval then return end
	LastInventoryScan = now
	OwnedItems = {}
	OwnedCategories = {Defensive = false, Utility = false, Offensive = false, Consumable = false}
	HasAnyTrackedItem = false
	for i = 1, #slots do
		local slot = slots[i]
		local item = myHero:GetItemData(slot)
		local itemId = item and item.itemID or 0
		local category = TrackedItems[itemId]
		if category then
			OwnedItems[itemId] = {slot = slot, hotkey = ItemKeys[i], ammo = item.ammo}
			OwnedCategories[category] = true
			HasAnyTrackedItem = true
		end
	end
end

local function HasClassicItem(itemId)
	return OwnedItems[itemId] ~= nil
end

local function ItemReady(itemId)
	local cached = OwnedItems[itemId]
	if not cached then return nil end
	local item = myHero:GetItemData(cached.slot)
	if not item or item.itemID ~= itemId then
		RefreshItemCache(true)
		cached = OwnedItems[itemId]
		if not cached then return nil end
		item = myHero:GetItemData(cached.slot)
		if not item then return nil end
	end
	if item.ammo ~= nil and item.ammo == 0 and itemId == ITEM_FLASK then return nil end
	local spellData = myHero:GetSpellData(cached.slot)
	if spellData and spellData.currentCd == 0 then
		return cached.hotkey
	end
	return nil
end

local function CastItem(itemId, target)
	local hotkey = ItemReady(itemId)
	if not hotkey then return false end
	if target then
		Control.CastSpell(hotkey, target)
	else
		Control.CastSpell(hotkey)
	end
	LastItemCast = GetTickCount()
	return true
end

-- ---------------------------------------------------------------------------------
-- Summoner spells
-- ---------------------------------------------------------------------------------

local function ResolveSummoners()
	if SummonersResolved then return end
	local hotkeys = {[SUMMONER_1] = HK_SUMMONER_1, [SUMMONER_2] = HK_SUMMONER_2}
	for _, slot in ipairs({SUMMONER_1, SUMMONER_2}) do
		local data = myHero:GetSpellData(slot)
		if data and data.name and data.name ~= "" then
			SummonerSlot[data.name] = slot
			SummonerHotkey[data.name] = hotkeys[slot]
			SummonersResolved = true
		end
	end
end

local function HasSummoner(name)
	return SummonerSlot[name] ~= nil
end

local function SummonerReady(name)
	local slot = SummonerSlot[name]
	if not slot then return false end
	local data = myHero:GetSpellData(slot)
	return data and data.currentCd == 0 and Game.CanUseSpell(slot) == 0
end

local function CastSummoner(name, target)
	local hotkey = SummonerHotkey[name]
	if not hotkey then return false end
	if target then
		Control.CastSpell(hotkey, target)
	else
		Control.CastSpell(hotkey)
	end
	LastSummonerCast = GetTickCount()
	return true
end

local function SmiteDamage()
	return 460 + 30 * HeroLevel(myHero)
end

local function IgniteDamage()
	return 50 + 20 * HeroLevel(myHero)
end

-- ---------------------------------------------------------------------------------
-- Classic item active damage
-- ---------------------------------------------------------------------------------

local BOTRK_DAMAGE_TYPE = _G.SDK.DAMAGE_TYPE_MAGICAL

local function BotrkDamage(target)
	local raw = math.max(100, target.maxHealth * 0.15)
	return _G.SDK.Damage:CalculateDamage(myHero, target, BOTRK_DAMAGE_TYPE, raw)
end

local function DfgDamage(target)
	local raw = target.maxHealth * 0.15
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, raw)
end

local function GunbladeDamage(target)
	local raw = 150 + myHero.ap * 0.4
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, raw)
end

local function CutlassDamage(target)
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, 100)
end

local function LocketShield()
	return 50 + (180 / 17) * (HeroLevel(myHero) - 1)
end

local function SeraphShield()
	return 150 + myHero.mana * 0.2
end

-- ---------------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------------

local function LoadActivatorMenu()
	if ActivatorMenuLoaded then return true end
	ResolveSummoners()

	MenuLoadAttempts = MenuLoadAttempts + 1
	local allyNames = {}
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and not hero.isEnemy and not hero.isMe then
			table.insert(allyNames, hero.charName)
		end
	end

	ActivatorMenu = MenuElement({
		type = MENU,
		id = "Classic_AIO_Activator",
		name = "Classic AIO - Activator",
		leftIcon = ItemIcon(ITEM_ZHONYAS),
	})
	ActivatorMenu:MenuElement({id = "Enabled", name = "Enable Activator", value = true})

	-- Consumables
	ActivatorMenu:MenuElement({type = MENU, id = "Potions", name = "Consumables"})
	ActivatorMenu.Potions:MenuElement({id = "Enabled", name = "Auto use consumables", value = true})

	ActivatorMenu.Potions:MenuElement({type = MENU, id = "HealthPotion", name = "Health Potion", leftIcon = ItemIcon(ITEM_HP_POTION)})
	ActivatorMenu.Potions.HealthPotion:MenuElement({id = "Enabled", name = "Use Health Potion", value = true})
	ActivatorMenu.Potions.HealthPotion:MenuElement({id = "HP", name = "Self HP <= x%", value = 50, min = 0, max = 100, step = 5})

	ActivatorMenu.Potions:MenuElement({type = MENU, id = "ManaPotion", name = "Mana Potion", leftIcon = ItemIcon(ITEM_MANA_POTION)})
	ActivatorMenu.Potions.ManaPotion:MenuElement({id = "Enabled", name = "Use Mana Potion", value = true})
	ActivatorMenu.Potions.ManaPotion:MenuElement({id = "Mana", name = "Self Mana <= x%", value = 40, min = 0, max = 100, step = 5})

	ActivatorMenu.Potions:MenuElement({type = MENU, id = "Flask", name = "Crystalline Flask", leftIcon = ItemIcon(ITEM_FLASK)})
	ActivatorMenu.Potions.Flask:MenuElement({id = "Enabled", name = "Use Crystalline Flask", value = true})
	ActivatorMenu.Potions.Flask:MenuElement({id = "HP", name = "Self HP <= x%", value = 50, min = 0, max = 100, step = 5})
	ActivatorMenu.Potions.Flask:MenuElement({id = "Mana", name = "Self Mana <= x%", value = 40, min = 0, max = 100, step = 5})

	ActivatorMenu.Potions:MenuElement({type = MENU, id = "Biscuit", name = "Total Biscuit of Rejuvenation", leftIcon = ItemIcon(ITEM_BISCUIT)})
	ActivatorMenu.Potions.Biscuit:MenuElement({id = "Enabled", name = "Use Total Biscuit", value = true})
	ActivatorMenu.Potions.Biscuit:MenuElement({id = "HP", name = "Self HP <= x%", value = 50, min = 0, max = 100, step = 5})
	ActivatorMenu.Potions.Biscuit:MenuElement({id = "Mana", name = "Self Mana <= x%", value = 40, min = 0, max = 100, step = 5})

	-- Offensive
	ActivatorMenu:MenuElement({type = MENU, id = "Offensive", name = "Offensives"})
	ActivatorMenu.Offensive:MenuElement({id = "Enabled", name = "Enable Offensive Items", value = true})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Botrk", name = "Blade of the Ruined King", leftIcon = ItemIcon(ITEM_BOTRK)})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "Enabled", name = "Use Blade of the Ruined King", value = true})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "LifeSaver", name = "Use as LifeSaver", value = true})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Botrk:MenuElement({id = "Range", name = "Target Distance <=", value = 450, min = 100, max = 450, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Cutlass", name = "Bilgewater Cutlass", leftIcon = ItemIcon(ITEM_CUTLASS)})
	ActivatorMenu.Offensive.Cutlass:MenuElement({id = "Enabled", name = "Use Bilgewater Cutlass", value = true})
	ActivatorMenu.Offensive.Cutlass:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Cutlass:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Cutlass:MenuElement({id = "Range", name = "Target Distance <=", value = 450, min = 100, max = 450, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Gunblade", name = "Hextech Gunblade", leftIcon = ItemIcon(ITEM_GUNBLADE)})
	ActivatorMenu.Offensive.Gunblade:MenuElement({id = "Enabled", name = "Use Hextech Gunblade", value = true})
	ActivatorMenu.Offensive.Gunblade:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Gunblade:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Gunblade:MenuElement({id = "Range", name = "Target Distance <=", value = 700, min = 100, max = 700, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Dfg", name = "Deathfire Grasp", leftIcon = ItemIcon(ITEM_DFG)})
	ActivatorMenu.Offensive.Dfg:MenuElement({id = "Enabled", name = "Use Deathfire Grasp", value = true})
	ActivatorMenu.Offensive.Dfg:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Dfg:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Dfg:MenuElement({id = "Range", name = "Target Distance <=", value = 750, min = 100, max = 750, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Youmuus", name = "Youmuu''s Ghostblade", leftIcon = ItemIcon(ITEM_YOUMUUS)})
	ActivatorMenu.Offensive.Youmuus:MenuElement({id = "Enabled", name = "Use Youmuu''s Ghostblade", value = true})
	ActivatorMenu.Offensive.Youmuus:MenuElement({id = "KS", name = "Use as KillSteal", value = true})
	ActivatorMenu.Offensive.Youmuus:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Youmuus:MenuElement({id = "OnUlt", name = "Use on ultimate", value = false})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Sotd", name = "Sword of the Divine", leftIcon = ItemIcon(ITEM_SOTD)})
	ActivatorMenu.Offensive.Sotd:MenuElement({id = "Enabled", name = "Use Sword of the Divine", value = true})
	ActivatorMenu.Offensive.Sotd:MenuElement({id = "Combo", name = "Always in combo", value = true})
	ActivatorMenu.Offensive.Sotd:MenuElement({id = "RangeBuffer", name = "Attack Range Buffer", value = 100, min = 0, max = 300, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Hydra", name = "Ravenous Hydra / Tiamat", leftIcon = ItemIcon(ITEM_HYDRA)})
	ActivatorMenu.Offensive.Hydra:MenuElement({id = "Enabled", name = "Use Ravenous Hydra / Tiamat", value = true})
	ActivatorMenu.Offensive.Hydra:MenuElement({id = "Range", name = "Enemy Distance <=", value = 400, min = 100, max = 500, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "TrueIce", name = "Shard of True Ice", leftIcon = ItemIcon(ITEM_TRUE_ICE)})
	ActivatorMenu.Offensive.TrueIce:MenuElement({id = "Enabled", name = "Use Shard of True Ice", value = true})
	ActivatorMenu.Offensive.TrueIce:MenuElement({id = "Range", name = "Enemy Distance <=", value = 500, min = 100, max = 750, step = 25})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Shurelyas", name = "Shurelya''s Reverie", leftIcon = ItemIcon(ITEM_SHURELYAS)})
	ActivatorMenu.Offensive.Shurelyas:MenuElement({id = "Enabled", name = "Use Shurelya''s Reverie", value = true})
	ActivatorMenu.Offensive.Shurelyas:MenuElement({id = "MinRange", name = "Target Distance >=", value = 650, min = 0, max = 2500, step = 50})
	ActivatorMenu.Offensive.Shurelyas:MenuElement({id = "MaxRange", name = "Target Distance <=", value = 1800, min = 0, max = 2500, step = 50})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "TwinShadows", name = "Twin Shadows", leftIcon = ItemIcon(ITEM_TWIN_SHADOWS)})
	ActivatorMenu.Offensive.TwinShadows:MenuElement({id = "Enabled", name = "Use Twin Shadows", value = true})
	ActivatorMenu.Offensive.TwinShadows:MenuElement({id = "MinRange", name = "Target Distance >=", value = 700, min = 0, max = 2500, step = 50})
	ActivatorMenu.Offensive.TwinShadows:MenuElement({id = "MaxRange", name = "Target Distance <=", value = 2500, min = 0, max = 2500, step = 50})

	ActivatorMenu.Offensive:MenuElement({type = MENU, id = "Ohmwrecker", name = "Ohmwrecker", leftIcon = ItemIcon(ITEM_OHMWRECKER)})
	ActivatorMenu.Offensive.Ohmwrecker:MenuElement({id = "Enabled", name = "Use Ohmwrecker", value = true})
	ActivatorMenu.Offensive.Ohmwrecker:MenuElement({id = "Range", name = "Target Distance <=", value = 900, min = 100, max = 950, step = 50})

	-- Defensive
	ActivatorMenu:MenuElement({type = MENU, id = "Defensive", name = "Defensives"})
	ActivatorMenu.Defensive:MenuElement({id = "Enabled", name = "Enable Defensive Items", value = true})

	ActivatorMenu.Defensive:MenuElement({type = MENU, id = "Randuin", name = "Randuin''s Omen", leftIcon = ItemIcon(ITEM_RANDUIN)})
	ActivatorMenu.Defensive.Randuin:MenuElement({id = "Enabled", name = "Use Randuin''s Omen", value = true})
	ActivatorMenu.Defensive.Randuin:MenuElement({id = "Range", name = "Enemy Distance <=", value = 500, min = 100, max = 500, step = 25})

	ActivatorMenu.Defensive:MenuElement({type = MENU, id = "Zhonyas", name = "Zhonya''s Hourglass", leftIcon = ItemIcon(ITEM_ZHONYAS)})
	ActivatorMenu.Defensive.Zhonyas:MenuElement({id = "Enabled", name = "Use Zhonya''s Hourglass", value = true})
	ActivatorMenu.Defensive.Zhonyas:MenuElement({id = "HP", name = "Self HP <= x%", value = 30, min = 0, max = 100, step = 5})
	ActivatorMenu.Defensive.Zhonyas:MenuElement({id = "EnemyRange", name = "Enemy Detection Range", value = 800, min = 200, max = 1200, step = 50})

	ActivatorMenu.Defensive:MenuElement({type = MENU, id = "Seraph", name = "Seraph''s Embrace", leftIcon = ItemIcon(ITEM_SERAPH)})
	ActivatorMenu.Defensive.Seraph:MenuElement({id = "Enabled", name = "Use Seraph''s Embrace", value = true})
	ActivatorMenu.Defensive.Seraph:MenuElement({id = "HP", name = "Self HP <= x%", value = 50, min = 0, max = 100, step = 5})

	ActivatorMenu.Defensive:MenuElement({type = MENU, id = "Locket", name = "Locket of the Iron Solari", leftIcon = ItemIcon(ITEM_LOCKET)})
	ActivatorMenu.Defensive.Locket:MenuElement({id = "Enabled", name = "Use Locket of the Iron Solari", value = true})
	ActivatorMenu.Defensive.Locket:MenuElement({id = "HP", name = "Ally / Self HP <= x%", value = 50, min = 0, max = 100, step = 5})

	-- Cleansers
	ActivatorMenu:MenuElement({type = MENU, id = "Cleansers", name = "Cleansers"})
	ActivatorMenu.Cleansers:MenuElement({id = "Enabled", name = "Use Mikael''s Crucible", value = true})
	ActivatorMenu.Cleansers:MenuElement({id = "Delay", name = "Delay x ms", value = 0, min = 0, max = 1000, step = 50})
	ActivatorMenu.Cleansers:MenuElement({id = "HP", name = "Use only under % HP", value = 80, min = 0, max = 100, step = 5})
	ActivatorMenu.Cleansers:MenuElement({id = "MinDuration", name = "Minimum CC remaining (ms)", value = 250, min = 0, max = 2000, step = 50})
	ActivatorMenu.Cleansers:MenuElement({type = MENU, id = "BuffTypes", name = "Buff type"})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Stun", name = "Stun", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Snare", name = "Snare", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Charm", name = "Charm", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Fear", name = "Fear / Flee", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Silence", name = "Silence", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Suppression", name = "Suppression", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Taunt", name = "Taunt", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Blind", name = "Blind", value = true})
	ActivatorMenu.Cleansers.BuffTypes:MenuElement({id = "Slow", name = "Slow", value = false})
	ActivatorMenu.Cleansers:MenuElement({type = MENU, id = "Allies", name = "Mikael''s allies"})
	for _, charName in ipairs(allyNames) do
		ActivatorMenu.Cleansers.Allies:MenuElement({
			id = "Ally" .. charName,
			name = charName:gsub("^Jade_", ""),
			value = true,

		})
	end

	-- Summoners
	if HasSummoner(SUM_SMITE) or HasSummoner(SUM_IGNITE) then
		ActivatorMenu:MenuElement({type = MENU, id = "Summoners", name = "Summoners"})
		if HasSummoner(SUM_SMITE) then
			ActivatorMenu.Summoners:MenuElement({type = MENU, id = "Smite", name = "Smite", leftIcon = SummonerIcon(SUM_SMITE)})
			ActivatorMenu.Summoners.Smite:MenuElement({id = "Enabled", name = "Auto Smite objectives", toggle = true, value = false, key = string.byte("N"),
				callback = function(newValue) if CheckChatBlock(ActivatorMenu.Summoners.Smite.Enabled, newValue) then return end end})

			for _, camp in ipairs({"Dragon", "Baron", "Red", "Blue"}) do
				ActivatorMenu.Summoners.Smite:MenuElement({id = camp, name = camp, value = true})
			end
		end

		if HasSummoner(SUM_IGNITE) then
			ActivatorMenu.Summoners:MenuElement({type = MENU, id = "Ignite", name = "Ignite", leftIcon = SummonerIcon(SUM_IGNITE)})
			ActivatorMenu.Summoners.Ignite:MenuElement({id = "Enabled", name = "Use Ignite", value = true})
			ActivatorMenu.Summoners.Ignite:MenuElement({id = "Mode", name = "Trigger mode", value = 1, drop = {"KillSteal", "Enemy HP <= x%"}})
			ActivatorMenu.Summoners.Ignite:MenuElement({id = "HP", name = "Enemy HP <= x%", value = 20, min = 0, max = 100, step = 5})
			ActivatorMenu.Summoners.Ignite:MenuElement({id = "OnlyCombo", name = "Only in combo", value = true})
		end
	end
	ActivatorMenuLoaded = true
	return true
end

-- ---------------------------------------------------------------------------------
-- Cleansers (Mikael''s Crucible)
-- ---------------------------------------------------------------------------------

local function SelectedCleanseTypes()
	local menu = ActivatorMenu.Cleansers.BuffTypes
	local types = {}
	if menu.Stun:Value() then types[BUFF_STUN] = true end
	if menu.Snare:Value() then types[BUFF_SNARE] = true end
	if menu.Charm:Value() then types[BUFF_CHARM] = true end
	if menu.Fear:Value() then types[BUFF_FEAR] = true; types[BUFF_FLEE] = true end
	if menu.Silence:Value() then types[BUFF_SILENCE] = true end
	if menu.Suppression:Value() then types[BUFF_SUPPRESS] = true end
	if menu.Taunt:Value() then types[BUFF_TAUNT] = true end
	if menu.Blind:Value() then types[BUFF_BLIND] = true end
	if menu.Slow:Value() then types[BUFF_SLOW] = true end
	return types
end

local function Cleansers()
	if not ActivatorMenu.Cleansers.Enabled:Value() then return end
	if not HasClassicItem(ITEM_MIKAELS) or not ItemReady(ITEM_MIKAELS) then return end

	local hpLimit = ActivatorMenu.Cleansers.HP:Value()
	local minDuration = ActivatorMenu.Cleansers.MinDuration:Value() * 0.001
	local delay = ActivatorMenu.Cleansers.Delay:Value()
	local types = SelectedCleanseTypes()

	for _, ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes(800)) do
		local option = ActivatorMenu.Cleansers.Allies["Ally" .. ally.charName]
		if IsValid(ally) and option and option:Value() and HealthPercent(ally) < hpLimit then
			local buffs = GetBuffs(ally)
			for i = 1, #buffs do
				local buff = buffs[i]
				if types[buff.type] and (buff.duration or 0) >= minDuration then
					if delay > 0 then
						DelayAction(function() CastItem(ITEM_MIKAELS, ally) end, delay * 0.001)
						LastItemCast = GetTickCount()
					else
						CastItem(ITEM_MIKAELS, ally)
					end
					return
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------------
-- Survival - Seraph''s / Zhonya''s / Barrier for self, Locket / Heal for team
-- ---------------------------------------------------------------------------------

local function Survival()
	local defensiveOn = ActivatorMenu.Defensive.Enabled:Value()
	local enemies = GetEnemyCount(ActivatorMenu.Defensive.Zhonyas.EnemyRange:Value(), myHero.pos)
	local hpPercent = HealthPercent(myHero)

	if enemies > 0 then
		-- Seraph''s Embrace
		if defensiveOn and ActivatorMenu.Defensive.Seraph.Enabled:Value()
			and HasClassicItem(ITEM_SERAPH) and ItemReady(ITEM_SERAPH)
			and hpPercent <= ActivatorMenu.Defensive.Seraph.HP:Value() then
			if CastItem(ITEM_SERAPH) then return end
		end
		-- Zhonya''s Hourglass
		if defensiveOn and ActivatorMenu.Defensive.Zhonyas.Enabled:Value()
			and HasClassicItem(ITEM_ZHONYAS) and ItemReady(ITEM_ZHONYAS)
			and hpPercent <= ActivatorMenu.Defensive.Zhonyas.HP:Value() then
			if CastItem(ITEM_ZHONYAS) then return end
		end
	end

	-- Locket of the Iron Solari
	if defensiveOn and ActivatorMenu.Defensive.Locket.Enabled:Value()
		and HasClassicItem(ITEM_LOCKET) and ItemReady(ITEM_LOCKET) then
		local hpLimit = ActivatorMenu.Defensive.Locket.HP:Value()
		ForEachAlly(700, function(ally)
			if HealthPercent(ally) > hpLimit then return false end
			if GetDistance(ally.pos) > 700 then return false end
			return CastItem(ITEM_LOCKET)
		end)
	end
end

-- ---------------------------------------------------------------------------------
-- Potions
-- ---------------------------------------------------------------------------------

local function PotionManagement()
	if not OwnedCategories.Consumable then return end
	if not ActivatorMenu.Potions.Enabled:Value() then return end
	if HasRegenBuff(myHero) then return end
	if IsInBase() then return end

	local hp = HealthPercent(myHero)
	local mana = ManaPercent(myHero)

	-- Health Potion: low HP, any location (except base)
	if ActivatorMenu.Potions.HealthPotion.Enabled:Value()
		and hp <= ActivatorMenu.Potions.HealthPotion.HP:Value() then
		if CastItem(ITEM_HP_POTION) then return end
	end

	-- Mana Potion: low mana, any location (except base)
	if ActivatorMenu.Potions.ManaPotion.Enabled:Value()
		and mana <= ActivatorMenu.Potions.ManaPotion.Mana:Value() then
		if CastItem(ITEM_MANA_POTION) then return end
	end

	-- Crystalline Flask: low HP or low mana, any location (except base)
	if ActivatorMenu.Potions.Flask.Enabled:Value()
		and (hp <= ActivatorMenu.Potions.Flask.HP:Value() or mana <= ActivatorMenu.Potions.Flask.Mana:Value()) then
		if CastItem(ITEM_FLASK) then return end
	end

	-- Total Biscuit: low HP or low mana, any location (except base)
	if ActivatorMenu.Potions.Biscuit.Enabled:Value()
		and (hp <= ActivatorMenu.Potions.Biscuit.HP:Value() or mana <= ActivatorMenu.Potions.Biscuit.Mana:Value()) then
		if CastItem(ITEM_BISCUIT) then return end
	end
end

-- ---------------------------------------------------------------------------------
-- Offensive items
-- ---------------------------------------------------------------------------------

local function Offensive()
	if not OwnedCategories.Offensive or not ActivatorMenu.Offensive.Enabled:Value() then return end
	local menu = ActivatorMenu.Offensive
	local combo = GetMode() == "Combo"

	-- Blade of the Ruined King
	if HasClassicItem(ITEM_BOTRK) and menu.Botrk.Enabled:Value() and ItemReady(ITEM_BOTRK) then
		local range = menu.Botrk.Range:Value()
		local target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
		if IsValid(target) and target.distance <= range then
			if menu.Botrk.KS:Value() and ValidTarget(target)
				and BotrkDamage(target) > target.health then
				if CastItem(ITEM_BOTRK, target) then return end
			end
			if menu.Botrk.LifeSaver:Value()
				and myHero.health < myHero.maxHealth * 0.5 then
				if CastItem(ITEM_BOTRK, target) then return end
			end
			if menu.Botrk.Combo:Value() and combo then
				if CastItem(ITEM_BOTRK, target) then return end
			end
		end
	end

	-- Deathfire Grasp
	if HasClassicItem(ITEM_DFG) and menu.Dfg.Enabled:Value() and ItemReady(ITEM_DFG) then
		local range = menu.Dfg.Range:Value()
		local target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
		if IsValid(target) and target.distance <= range then
			if menu.Dfg.KS:Value() and ValidTarget(target)
				and DfgDamage(target) > target.health then
				if CastItem(ITEM_DFG, target) then return end
			end
			if menu.Dfg.Combo:Value() and combo then
				if CastItem(ITEM_DFG, target) then return end
			end
		end
	end

	-- Hextech Gunblade
	if HasClassicItem(ITEM_GUNBLADE) and menu.Gunblade.Enabled:Value() and ItemReady(ITEM_GUNBLADE) then
		local range = menu.Gunblade.Range:Value()
		local target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
		if IsValid(target) and target.distance <= range then
			if menu.Gunblade.KS:Value() and ValidTarget(target)
				and GunbladeDamage(target) > target.health then
				if CastItem(ITEM_GUNBLADE, target) then return end
			end
			if menu.Gunblade.Combo:Value() and combo then
				if CastItem(ITEM_GUNBLADE, target) then return end
			end
		end
	end

	-- Bilgewater Cutlass
	if HasClassicItem(ITEM_CUTLASS) and menu.Cutlass.Enabled:Value() and ItemReady(ITEM_CUTLASS) then
		local range = menu.Cutlass.Range:Value()
		local target = _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
		if IsValid(target) and target.distance <= range then
			if menu.Cutlass.KS:Value() and ValidTarget(target)
				and CutlassDamage(target) > target.health then
				if CastItem(ITEM_CUTLASS, target) then return end
			end
			if menu.Cutlass.Combo:Value() and combo then
				if CastItem(ITEM_CUTLASS, target) then return end
			end
		end
	end

	-- Shard of True Ice
	if HasClassicItem(ITEM_TRUE_ICE) and menu.TrueIce.Enabled:Value() and combo
		and GetEnemyCount(menu.TrueIce.Range:Value(), myHero.pos) > 0 then
		if CastItem(ITEM_TRUE_ICE, myHero) then return end
	end

	-- Youmuu''s Ghostblade
	if HasClassicItem(ITEM_YOUMUUS) and menu.Youmuus.Enabled:Value() and ItemReady(ITEM_YOUMUUS) then
		if menu.Youmuus.OnUlt:Value() and IsCasting() then
			if CastItem(ITEM_YOUMUUS) then return end
		end
		local target = _G.SDK.Orbwalker:GetTarget()
		if target and target.type == Obj_AI_Hero and IsValid(target) then
			if menu.Youmuus.KS:Value() and target.health < myHero.maxHealth then
				if CastItem(ITEM_YOUMUUS) then return end
			end
			if menu.Youmuus.Combo:Value() and combo then
				if CastItem(ITEM_YOUMUUS) then return end
			end
		end
	end

	-- Sword of the Divine
	if HasClassicItem(ITEM_SOTD) and menu.Sotd.Enabled:Value() and combo and ItemReady(ITEM_SOTD) then
		local target = _G.SDK.Orbwalker:GetTarget()
		if target and target.type == Obj_AI_Hero and IsValid(target) then
			local range = myHero.range + myHero.boundingRadius + target.boundingRadius + menu.Sotd.RangeBuffer:Value()
			if target.distance <= range then
				if CastItem(ITEM_SOTD) then return end
			end
		end
	end

	-- Ravenous Hydra / Tiamat
	if menu.Hydra.Enabled:Value() then
		local range = menu.Hydra.Range:Value()
		if GetEnemyCount(range, myHero.pos) > 0 or GetMinionCount(range, myHero.pos) > 1 then
			if HasClassicItem(ITEM_HYDRA) then
				if CastItem(ITEM_HYDRA) then return end
			elseif HasClassicItem(ITEM_TIAMAT) then
				if CastItem(ITEM_TIAMAT) then return end
			end
		end
	end

	-- Shurelya''s Reverie / Twin Shadows / Ohmwrecker
	if combo then
		local target = GetTarget(2500)
		if IsValid(target) then
			local distance = target.distance
			if HasClassicItem(ITEM_SHURELYAS) and menu.Shurelyas.Enabled:Value()
				and distance >= math.min(menu.Shurelyas.MinRange:Value(), menu.Shurelyas.MaxRange:Value())
				and distance <= math.max(menu.Shurelyas.MinRange:Value(), menu.Shurelyas.MaxRange:Value()) then
				if CastItem(ITEM_SHURELYAS) then return end
			end
			if HasClassicItem(ITEM_TWIN_SHADOWS) and menu.TwinShadows.Enabled:Value()
				and distance >= math.min(menu.TwinShadows.MinRange:Value(), menu.TwinShadows.MaxRange:Value())
				and distance <= math.max(menu.TwinShadows.MinRange:Value(), menu.TwinShadows.MaxRange:Value()) then
				if CastItem(ITEM_TWIN_SHADOWS) then return end
			end
			if HasClassicItem(ITEM_OHMWRECKER) and menu.Ohmwrecker.Enabled:Value()
				and distance <= menu.Ohmwrecker.Range:Value() and IsUnderTurret(myHero) then
				if CastItem(ITEM_OHMWRECKER) then return end
			end
		end
	end
end

-- ---------------------------------------------------------------------------------
-- Randuin''s Omen
-- ---------------------------------------------------------------------------------

local function Defensive()
	if not OwnedCategories.Defensive or not ActivatorMenu.Defensive.Enabled:Value() then return end
	if ActivatorMenu.Defensive.Randuin.Enabled:Value() and HasClassicItem(ITEM_RANDUIN)
		and GetEnemyCount(ActivatorMenu.Defensive.Randuin.Range:Value(), myHero.pos) > 0 then
		CastItem(ITEM_RANDUIN)
	end
end

-- ---------------------------------------------------------------------------------
-- Smite
-- ---------------------------------------------------------------------------------

local function Smite()
	if not HasSummoner(SUM_SMITE) or not ActivatorMenu.Summoners.Smite then return end
	if not ActivatorMenu.Summoners.Smite.Enabled:Value() then return end
	if not SummonerReady(SUM_SMITE) then return end

	local damage = SmiteDamage()
	for _, mob in ipairs(_G.SDK.ObjectManager:GetMonsters(760, true)) do
		local camp = SmiteCamps[mob.charName:lower()]
		if camp and ActivatorMenu.Summoners.Smite[camp]:Value() and mob.health <= damage then
			if mob.distance <= 760 + myHero.boundingRadius + mob.boundingRadius then
				CastSummoner(SUM_SMITE, mob)
				return
			end
		end
	end
end


-- ---------------------------------------------------------------------------------
-- Ignite
-- ---------------------------------------------------------------------------------

local function Ignite()
	if not HasSummoner(SUM_IGNITE) or not ActivatorMenu.Summoners.Ignite then return end
	if not ActivatorMenu.Summoners.Ignite.Enabled:Value() or not SummonerReady(SUM_IGNITE) then return end

	local combo = GetMode() == "Combo"
	if ActivatorMenu.Summoners.Ignite.OnlyCombo:Value() and not combo then return end

	local damage = IgniteDamage()
	local mode = ActivatorMenu.Summoners.Ignite.Mode:Value()
	local hpThreshold = ActivatorMenu.Summoners.Ignite.HP:Value()
	for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(600)) do
		if ValidTarget(enemy) then
			-- Mode 1: KillSteal
			if mode == 1 and enemy.health <= damage then
				if CastSummoner(SUM_IGNITE, enemy) then return end
			end
			-- Mode 2: Enemy HP <= x%
			if mode == 2 and HealthPercent(enemy) <= hpThreshold then
				if CastSummoner(SUM_IGNITE, enemy) then return end
			end
		end
	end
end

-- ---------------------------------------------------------------------------------
-- Tick
-- ---------------------------------------------------------------------------------

local function ActivatorTick()
	if not LoadActivatorMenu() then return end
	if not ActivatorMenu.Enabled:Value() then return end
	if myHero.dead or Game.IsChatOpen() then return end

	RefreshItemCache()

	Cleansers()
	Survival()
	Smite()
	Ignite()

	if ShouldWait() then return end
	if GetTickCount() < LastItemCast + CastDelay then return end
	if GetTickCount() < LastSummonerCast + CastDelay then return end

	if ActivatorMenu.Potions.Enabled:Value() then
		PotionManagement()
	end

	if not HasAnyTrackedItem then return end
	Offensive()
	Defensive()
end

Callback.Add("Tick", ActivatorTick)





