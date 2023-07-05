local Version = "1.16"
local LoadTime = 0
Callback.Add(
    "Load",
    function()
        if not FileExist(COMMON_PATH .. "GGPrediction.lua") then
            print("GGPrediction not found! Please download it before using this script.")
            return
        end
        if not FileExist(COMMON_PATH .. "DamageLib.lua") then
            print("DamageLib not found! Please download it before using this script.")
            return
        end
        if not FileExist(COMMON_PATH .. "MapPositionGOS.lua") then
            print("MapPositionGOS not found! Please download it before using this script.")
            return
        end
        if not FileExist(COMMON_PATH .. "2DGeometry.lua") then
            print("MapPositionGOS not found! Please download it before using this script.")
            return
        end
        require("GGPrediction")
        require("DamageLib")
        require("MapPositionGOS")
        require("2DGeometry")
        LoadTime = Game.Timer()
        Champion:Init()
    end
)

File = {}
do
    function File:WriteSpriteToFile(path, str)
        path = SPRITE_PATH .. path
        if FileExist(path) then
            return
        end
        local output = io.open(path, "wb")
        output:write(File:Base64Decode(str))
        output:close()
    end

    function File:Base64Decode(data)
        local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        data = string.gsub(data, "[^" .. b .. "=]", "")
        return (data:gsub(
            ".",
            function(x)
                if (x == "=") then
                    return ""
                end
                local r, f = "", (b:find(x) - 1)
                for i = 6, 1, -1 do
                    r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
                end
                return r
            end
        ):gsub(
            "%d%d%d?%d?%d?%d?%d?%d?",
            function(x)
                if (#x ~= 8) then
                    return ""
                end
                local c = 0
                for i = 1, 8 do
                    c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
                end
                return string.char(c)
            end
        ))
    end
end

-- Icons start
do
    File:WriteSpriteToFile(
        "MenuElement/Sussy.png",
        "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"
    )
end
-- Icons end

Menu = {}
do
    function Menu:Init()
        Menu.root =
            MenuElement(
            {
                name = "Sussy " .. myHero.charName,
                id = "Sussy " .. myHero.charName,
                type = _G.MENU,
                leftIcon = "/Sussy.png"
            }
        )
        Menu.q = Menu.root:MenuElement({name = "Q", id = "q", type = _G.MENU})
        Menu.w = Menu.root:MenuElement({name = "W", id = "w", type = _G.MENU})
        Menu.e = Menu.root:MenuElement({name = "E", id = "e", type = _G.MENU})
        Menu.r = Menu.root:MenuElement({name = "R", id = "r", type = _G.MENU})
        Menu.d = Menu.root:MenuElement({name = "Drawings", id = "d", type = _G.MENU})
        Menu.root:MenuElement({name = "", type = _G.SPACE, id = "VersionSpacer"})
        Menu.root:MenuElement({name = "Version  " .. Version, type = _G.SPACE, id = "VersionNumber"})
    end
end

Spells = {}
do
    Spells.InterruptableSpells = {
        ["CaitlynAceintheHole"] = true,
        ["Crowstorm"] = true,
        ["DrainChannel"] = true,
        ["GalioIdolOfDurand"] = true,
        ["ReapTheWhirlwind"] = true,
        ["KarthusFallenOne"] = true,
        ["KatarinaR"] = true,
        ["LucianR"] = true,
        ["AlZaharNetherGrasp"] = true,
        ["Meditate"] = true,
        ["MissFortuneBulletTime"] = true,
        ["AbsoluteZero"] = true,
        ["PantheonRJump"] = true,
        ["PantheonRFall"] = true,
        ["ShenStandUnited"] = true,
        ["Destiny"] = true,
        ["UrgotSwap2"] = true,
        ["VelkozR"] = true,
        ["InfiniteDuress"] = true,
        ["XerathLocusOfPower2"] = true
    }

    function Spells:IsReady(spell)
        return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and
            myHero:GetSpellData(spell).mana <= myHero.mana and
            Game.CanUseSpell(spell) == 0
    end

    function Spells:IsNotReady(spell)
        if not Spells:IsReady(spell) then
            return true
        end
        return false
    end

    function Spells:CreateLinePoly(pos)
        local startPos = myHero.pos
        local endPos = pos
        local width = 10
        local c1 = startPos + Vector(Vector(endPos) - startPos):Perpendicular():Normalized() * width
        local c2 = startPos + Vector(Vector(endPos) - startPos):Perpendicular2():Normalized() * width
        local c3 = endPos + Vector(Vector(startPos) - endPos):Perpendicular():Normalized() * width
        local c4 = endPos + Vector(Vector(startPos) - endPos):Perpendicular2():Normalized() * width
        local poly = Polygon(c1, c2, c3, c4)
        return poly
    end

    function Spells:LineCollidesTerrain(linePoly)
        for i, lineSegment in ipairs(linePoly:__getLineSegments()) do
            if MapPosition:intersectsWall(lineSegment) then
                return true
            end
        end
        return false
    end
end

Orb = {}
do
    function Orb:GetMode()
        if _G.SDK then
            return _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo" or
                _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass" or
                _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "Clear" or
                _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "Clear" or
                _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit" or
                _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee" or
                nil
        elseif _G.PremiumOrbwalker then
            return _G.PremiumOrbwalker:GetMode()
        end
        return nil
    end

    function Orb:IsCombo()
        if Orb:GetMode() == "Combo" then
            return true
        end
        return false
    end

    function Orb:IsHarass()
        if Orb:GetMode() == "Harass" then
            return true
        end
        return false
    end

    function Orb:IsClear()
        if Orb:GetMode() == "Clear" then
            return true
        end
        return false
    end

    function Orb:IsLastHit()
        if Orb:GetMode() == "LastHit" then
            return true
        end
        return false
    end

    function Orb:IsFlee()
        if Orb:GetMode() == "Flee" then
            return true
        end
        return false
    end

    function Orb:GetTarget(range)
        if _G.SDK then
            if myHero.ap > myHero.totalDamage then
                return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
            else
                return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
            end
        elseif _G.PremiumOrbwalker then
            return _G.PremiumOrbwalker:GetTarget(range)
        end
    end

    function Orb:IsEvading()
        if _G.JustEvade and _G.JustEvade:Evading() then
            return true
        end
        if _G.ExtLibEvade and _G.ExtLibEvade.Evading then
            return true
        end
        return false
    end
	
	function Orb:IsImmortal(target, isAttack)
		return _G.SDK.ObjectManager:IsHeroImmortal(target, isAttack)
	end

    function Orb:OnPostAttack(fn)
        if _G.SDK then
            return _G.SDK.Orbwalker:OnPostAttack(fn)
        elseif _G.PremiumOrbwalker then
            return _G.PremiumOrbwalker:OnPostAttack(fn)
        end
    end

    function Orb:OnPreAttack(fn)
        if _G.SDK then
            return _G.SDK.Orbwalker:OnPreAttack(fn)
        elseif _G.PremiumOrbwalker then
            return _G.PremiumOrbwalker:OnPreAttack(fn)
        end
    end
end

Champion = {}
do
    function Champion:IsValid(unit)
        if
            unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and
                unit.health > 0
         then
            return true
        end
        return false
    end

    function Champion:IsValidEnemy(unit)
        if unit and unit.team ~= myHero.team and Champion:IsValid(unit) then
            return true
        end
    end

    function Champion:IsValidAlly(unit)
        if unit and unit.team == myHero.team and Champion:IsValid(unit) then
            return true
        end
    end

    function Champion:IsRecalling(unit)
        if unit and unit.valid then
            local buffCount = unit.buffCount
            for i = 1, buffCount do
                local buff = unit:GetBuff(i)
                if buff.count > 0 and buff.name == "recall" and Game.Timer() < buff.expireTime then
                    return true
                end
            end
        end
        return false
    end

    function Champion:HealthPercent(unit)
        if unit then
            return 100 * unit.health / unit.maxHealth
        end
        return 0
    end

    function Champion:ManaPercent(unit)
        if unit then
            return 100 * unit.mana / unit.maxMana
        end
        return 0
    end

    function Champion:IsPlayerAtFountain()
        local blueFountain = Vector(500, 180, 500)
        local redFountain = Vector(14250, 170, 14250)
        local distance = 800
        local pos = myHero.pos
        return pos:DistanceTo(blueFountain) <= distance or pos:DistanceTo(redFountain) <= 800
    end

    function Champion:MyHeroNotReady()
        return myHero.dead or Game.IsChatOpen() or Orb:IsEvading() or myHero.isChanneling or
            Champion:IsRecalling(myHero) or
            Champion:IsPlayerAtFountain(myHero)
    end

    function Champion:GetEnemies()
        local enemies = {}
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.team ~= myHero.team then
                table.insert(enemies, hero)
            end
        end
        return enemies
    end

    function Champion:GetValidEnemies(pos, range)
        local enemies = {}
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and Champion:IsValidEnemy(hero) and pos:DistanceTo(hero.pos) <= range then
                table.insert(enemies, hero)
            end
        end
        return enemies
    end

    function Champion:GetAllies()
        local enemies = {}
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.team == myHero.team then
                table.insert(enemies, hero)
            end
        end
        return enemies
    end

    function Champion:GetValidAllies(pos, range)
        local enemies = {}
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and Champion:IsValidAlly(hero) and pos:DistanceTo(hero.pos) <= range then
                table.insert(enemies, hero)
            end
        end
        return enemies
    end

    function Champion:GetValidEnemiesCount(pos, range)
        local count = 0
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and Champion:IsValidEnemy(hero) and pos:DistanceTo(hero.pos) <= range then
                count = count + 1
            end
        end
        return count
    end

    function Champion:GetValidAlliesCount(pos, range)
        local count = 0
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and Champion:IsValidAlly(hero) then
                count = count + 1
            end
        end
        return count
    end

    function Champion:HasZileanBomb(unit)
        local name = "ZileanQEnemyBomb"
        for i = 0, unit.buffCount do
            local buff = unit:GetBuff(i)
            if buff and buff.count > 0 and buff.name == name then
                return true
            end
        end
        return false
    end

    function Champion:Init()
        -- Shaco START
        if myHero.charName == "Shaco" then
            Menu:Init()
            Menu.q:Remove()
            Menu.w:Remove()
            Menu.d:Remove()

            Menu.e_ks_enabled = Menu.e:MenuElement({id = "ekillsteal", name = "Killsteal", value = true})
            Menu.e_ks_backstab =
                Menu.e:MenuElement({id = "ekillstealbackstab", name = "Include Backstab", value = true})
            Menu.e_ks_collector =
                Menu.e:MenuElement({id = "ekillstealcollector", name = "Include Collector", value = true})

            Menu.r_clone_enabled = Menu.r:MenuElement({id = "clone", name = "Control Clone", value = true})
            Menu.r_clone_attack =
                Menu.r:MenuElement({id = "attack", name = "Control 'Clone' attack target", key = string.byte("T")})
            Menu.r_clone_follow =
                Menu.r:MenuElement({id = "follow", name = "Control 'Clone' follow self", key = string.byte("Z")})

            Callback.Add(
                "Tick",
                function()
                    if not Spells:IsReady(_E) or Champion:MyHeroNotReady() then
                        return
                    end

                    local basedmg = 45
                    local lvldmg = 25 * myHero:GetSpellData(_E).level
                    local statdmg = myHero.ap * 0.55 + myHero.bonusDamage * 0.7
                    local edmg = basedmg + lvldmg + statdmg
                    if edmg < 50 then
                        return
                    end
                    local behindDmg = 15 + (35 / 17 * (myHero.levelData.lvl - 1)) + myHero.ap * 0.1
                    if Menu.e_ks_enabled:Value() then
                      for i = 1, Game.HeroCount() do
                        local hero = Game.Hero(i)
                        if Champion:IsValidEnemy(hero) and myHero.pos:DistanceTo(hero.pos) <= 625 then
                            local health = hero.health + (2 * hero.hpRegen)
                            local extraDamage = 0
                            if Menu.e_ks_backstab:Value() and not _G.SDK.ObjectManager:IsFacing(hero, myHero) then
                                extraDamage = extraDamage + behindDmg
                            end
                            local dmg =
                                _G.SDK.Damage:CalculateDamage(myHero, hero, DAMAGE_TYPE_MAGICAL, edmg + extraDamage)
                            local hpPercent = health / hero.maxHealth
                            if hpPercent < 0.3 then
                                dmg = dmg * 1.5
                            end
                            if health > 1 then
                                if health < dmg then
                                    Control.CastSpell(HK_E, hero)
                                    return
                                end
                                if
                                    ((health - dmg) / hero.maxHealth) <= 0.05 and Menu.e_ks_collector:Value() and
                                        _G.SDK.ItemManager:HasItem(unit, 6676)
                                 then
                                    Control.CastSpell(HK_E, hero)
                                end
                            end
                        end
                      end
                    end
                    if Menu.r_clone_enabled:Value() and myHero:GetSpellData(_R).name == "HallucinateGuide" then
                        local target = Orb:GetTarget(2500)
                        if target then
                            if Menu.r_clone_attack:Value() then
                                Control.CastSpell(HK_R, target)
                            end
                        end
                        if Menu.r_clone_follow:Value() then
                            Control.CastSpell(HK_R, myHero)
                        end
                    end

                end
            )

            print("Sussy " .. myHero.charName .. " loaded.")
        end
        -- Shaco END

    end
end
