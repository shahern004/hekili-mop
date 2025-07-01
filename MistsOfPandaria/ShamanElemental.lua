-- ShamanElemental.lua
-- January 2025 - MoP Structure based on Retail

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'SHAMAN' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state

local function getReferences()
    if not class then
        class, state = Hekili.Class, Hekili.State
    end
    return class, state
end

local strformat = string.format

local function InitializeSpec()
    if not Hekili or not Hekili.NewSpecialization then return end
    
    local spec = Hekili:NewSpecialization( 262 )

-- Resources
spec:RegisterResource( 0 ) -- Mana = 0 in MoP

-- Talents (MoP Elemental Shaman talents)
spec:RegisterTalents( {
    -- Tier 15
    astral_shift = { 15000, 108271, 1 },
    stone_bulwark_totem = { 15001, 108270, 1 },
    elemental_blast = { 15002, 117014, 1 },
    
    -- Tier 30
    frozen_power = { 30000, 63374, 1 },
    earthgrab_totem = { 30001, 51485, 1 },
    windwalk_totem = { 30002, 108273, 1 },
    
    -- Tier 45  
    call_of_the_elements = { 45000, 108285, 1 },
    totemic_restoration = { 45001, 108284, 1 },
    totemic_projection = { 45002, 108287, 1 },
    
    -- Tier 60
    lashing_lava = { 60000, 108291, 1 },
    conductivity = { 60001, 108282, 1 },
    unleashed_fury = { 60002, 117012, 1 },
    
    -- Tier 75
    unleash_life = { 75000, 73685, 1 },
    ancestral_swiftness = { 75001, 16188, 1 },
    echo_of_the_elements = { 75002, 108283, 1 },
    
    -- Tier 90
    elemental_mastery = { 90000, 16166, 1 },
    ancestral_guidance = { 90001, 108281, 1 },
    primal_elementalist = { 90002, 117013, 1 },
} )

-- Auras
spec:RegisterAuras( {
    -- Forms and Stances
    ghost_wolf = {
        id = 2645,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Weapon Imbues
    flametongue = {
        id = 318038,
        duration = 3600,
        max_stack = 1,
    },
    
    frostbrand = {
        id = 318039,
        duration = 3600,
        max_stack = 1,
    },
    
    windfury = {
        id = 319773,
        duration = 3600,
        max_stack = 1,
    },
    
    rockbiter = {
        id = 318037,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Shields
    lightning_shield = {
        id = 324,
        duration = 600,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(324)
            
            if name then
                t.name = name
                t.count = count or 3
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    earth_shield = {
        id = 974,
        duration = 600,
        max_stack = 9,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(974)
            
            if name then
                t.name = name
                t.count = count or 9
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    water_shield = {
        id = 52127,
        duration = 600,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(52127)
            
            if name then
                t.name = name
                t.count = count or 3
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    -- Buffs
    lava_surge = {
        id = 77756,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(77756)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    clearcasting = {
        id = 16246,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(16246)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    -- Talent Buffs
    elemental_mastery = {
        id = 16166,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(16166)
            
            if name and state.talent.elemental_mastery.enabled then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    ancestral_swiftness = {
        id = 16188,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(16188)
            
            if name and state.talent.ancestral_swiftness.enabled then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    echo_of_the_elements = {
        id = 108283,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(108283)
            
            if name and state.talent.echo_of_the_elements.enabled then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    
    -- Debuffs on Target
    flame_shock = {
        id = 8050,
        duration = 30,
        tick_time = 3,
        type = "Magic",
        max_stack = 1,
    },
    
    frost_shock = {
        id = 8056,
        duration = 8,
        type = "Magic",
        max_stack = 1,
    },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Basic Abilities
    lightning_bolt = {
        id = 403,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return state.buff.clearcasting.up and 0 or 0.06 end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136048,
        
        handler = function()
            removeBuff( "clearcasting" )
            if state.talent.rolling_thunder and state.buff.lightning_shield.up and state.buff.lightning_shield.stack >= 7 then
                addBuff( "lava_surge" )
            end
        end,
    },
    
    chain_lightning = {
        id = 421,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return state.buff.clearcasting.up and 0 or 0.12 end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136015,
        
        handler = function()
            removeBuff( "clearcasting" )
            if state.talent.rolling_thunder and state.buff.lightning_shield.up and state.buff.lightning_shield.stack >= 7 then
                addBuff( "lava_surge" )
            end
        end,
    },
    
    lava_burst = {
        id = 51505,
        cast = function() return state.buff.lava_surge.up and 0 or 2.0 end,
        cooldown = 8,
        gcd = "spell",
        
        spend = function() return state.buff.lava_surge.up and 0 or 0.10 end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 237582,
        
        handler = function()
            removeBuff( "lava_surge" )
            if state.debuff.flame_shock.up then
                -- Guaranteed crit on flame shocked targets
            end
        end,
    },
    
    earth_shock = {
        id = 8042,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136026,
        
        handler = function()
            -- Can proc Lava Surge
            if math.random() < 0.15 and state.buff.lightning_shield.up then
                addBuff( "lava_surge" )
            end
        end,
    },
    
    flame_shock = {
        id = 8050,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.17,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135813,
        
        handler = function()
            applyDebuff( "target", "flame_shock" )
        end,
    },
    
    frost_shock = {
        id = 8056,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.17,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135849,
        
        handler = function()
            applyDebuff( "target", "frost_shock" )
        end,
    },
    
    -- Shields
    lightning_shield = {
        id = 324,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        essential = true,
        
        nobuff = function() return state.buff.lightning_shield.up and "lightning_shield" or ( state.buff.earth_shield.up and "earth_shield" ) or ( state.buff.water_shield.up and "water_shield" ) end,
        
        handler = function()
            removeBuff( "earth_shield" )
            removeBuff( "water_shield" )
            applyBuff( "lightning_shield", nil, 3 )
        end,
        
        copy = { 324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472, 49280, 49281 }
    },
    
    earth_shield = {
        id = 974,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        essential = true,
        
        nobuff = function() return state.buff.earth_shield.up and "earth_shield" or ( state.buff.lightning_shield.up and "lightning_shield" ) or ( state.buff.water_shield.up and "water_shield" ) end,
        
        handler = function()
            removeBuff( "lightning_shield" )
            removeBuff( "water_shield" )
            applyBuff( "earth_shield", nil, 9 )
        end,
        
        copy = { 974, 32593, 32594, 49283, 49284 }
    },
    
    water_shield = {
        id = 52127,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        essential = true,
        
        nobuff = function() return state.buff.water_shield.up and "water_shield" or ( state.buff.lightning_shield.up and "lightning_shield" ) or ( state.buff.earth_shield.up and "earth_shield" ) end,
        
        handler = function()
            removeBuff( "lightning_shield" )
            removeBuff( "earth_shield" )
            applyBuff( "water_shield", nil, 3 )
        end,
        
        copy = { 52127, 52129, 52131, 52134, 52136, 52138 }
    },
    
    -- Weapon Imbues
    flametongue_weapon = {
        id = 8024,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "flametongue",
        
        handler = function()
            applyBuff( "flametongue" )
        end,
    },
    
    frostbrand_weapon = {
        id = 8033,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "frostbrand",
        
        handler = function()
            applyBuff( "frostbrand" )
        end,
    },
    
    windfury_weapon = {
        id = 8232,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "windfury",
        
        handler = function()
            applyBuff( "windfury" )
        end,
    },
    
    rockbiter_weapon = {
        id = 8017,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "rockbiter",
        
        handler = function()
            applyBuff( "rockbiter" )
        end,
    },
    
    -- Talent Abilities
    elemental_blast = {
        id = 117014,
        cast = 2.0,
        cooldown = 12,
        gcd = "spell",
        
        talent = "elemental_blast",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = true,
        texture = 651244,
        
        handler = function()
            -- Buffs a random stat
        end,
    },
    
    elemental_mastery = {
        id = 16166,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        talent = "elemental_mastery",
        
        handler = function()
            applyBuff( "elemental_mastery" )
        end,
    },
    
    ancestral_swiftness = {
        id = 16188,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        talent = "ancestral_swiftness",
        
        handler = function()
            applyBuff( "ancestral_swiftness" )
        end,
    },
    
    -- Utility
    purge = {
        id = 370,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136075,
        
        usable = function() return buff.dispellable_magic.up end,
        
        handler = function()
            removeBuff( "dispellable_magic" )
        end,
    },
    
    wind_shear = {
        id = 57994,
        cast = 0,
        cooldown = 12,
        gcd = "off",
        
        startsCombat = true,
        texture = 136018,
        
        toggle = "interrupts",
        interrupt = true,
        
        usable = function() return target.casting end,
        
        handler = function()
            interrupt()
        end,
    },
    
    ghost_wolf = {
        id = 2645,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136095,
        
        handler = function()
            applyBuff( "ghost_wolf" )
        end,
    },
} )

-- Priority List
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    cycle = false,
    
    nameplates = false,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "volcanic_potion",
    
    package = "Elemental",
} )

spec:RegisterPack( "Elemental", 20250108, [[Hekili:T3tAZTnor4FlCsKKvpbAb1fXssBACKOyN0fzSR9r1vvJ5sCnZGG)2VKf4vEvevHpNfDqjhhhV7rjjzgooSVF5L99oSN7V)1ND3N46)Ec33NX)M)M6)sC(5H3VF4VJp(6BZ(9J)(L9Op(6J)QJ)y4VpEjpWF8jpoF8Kx(aE8R)(jF(xyXJN4VFEVP)M6)C99AZ9LN4VN4r(VF(eo(1F8zH)AwqCJp(15(m)(y1YZpF(f3FET5U2Qf)T4qCrWPJGOsOl(5Vp)YJpIJNr4MFQX)(RNVx(VFpk)VFa9tpH)HFFd)xh)YJ)(VFa(VFC()yx6FqEI8Jd)rE(V)VE)V)8F(pE(ZJ)7bwxaVw(fpj)(VV4LgVE4zp5rxo5p9r8jOKZp(VpBE)MN)M9pqLKdE)V)6tFs9LMK3qUx4zxV)p(YJFa(XZ8JFEbp8apo(Rd8lp(0Jp5HrNzElpDr39b)JN4r4NX)5NJ)(3F)69Y)v3N9pOxoyUxgDx0F8B9V)KM(8N7)) ]])

-- Single Target
spec:RegisterPack( "Elemental ST", 20250108, [[Hekili:T3tAZTnor4FlCsKKvpbAb1fXssBACKOyN0fzSR9r1vvJ5sCnZGG)2VKf4vEvevHpNfDqjhhhV7rjjzgooSVF5L99oSN7V)1ND3N46)Ec33NX)M)M6)sC(5H3VF4VJp(6BZ(9J)(L9Op(6J)QJ)y4VpEjpWF8jpoF8Kx(aE8R)(jF(xyXJN4VFEVP)M6)C99AZ9LN4VN4r(VF(eo(1F8zH)AwqCJp(15(m)(y1YZpF(f3FET5U2Qf)T4qCrWPJGOsOl(5Vp)YJpIJNr4MFQX)(RNVx(VFpk)VFa9tpH)HFFd)xh)YJ)(VFa(VFC()yx6FqEI8Jd)rE(V)VE)V)8F(pE(ZJ)7bwxaVw(fpj)(VV4LgVE4zp5rxo5p9r8jOKZp(VpBE)MN)M9pqLKdE)V)6tFs9LMK3qUx4zxV)p(YJFa(XZ8JFEbp8apo(Rd8lp(0Jp5HrNzElpDr39b)JN4r4NX)5NJ)(3F)69Y)v3N9pOxoyUxgDx0F8B9V)KM(8N7)) ]])

-- AOE
spec:RegisterPack( "Elemental AOE", 20250108, [[Hekili:T3tAZTnor4FlCsKKvpbAb1fXssBACKOyN0fzSR9r1vvJ5sCnZGG)2VKf4vEvevHpNfDqjhhhV7rjjzgooSVF5L99oSN7V)1ND3N46)Ec33NX)M)M6)sC(5H3VF4VJp(6BZ(9J)(L9Op(6J)QJ)y4VpEjpWF8jpoF8Kx(aE8R)(jF(xyXJN4VFEVP)M6)C99AZ9LN4VN4r(VF(eo(1F8zH)AwqCJp(15(m)(y1YZpF(f3FET5U2Qf)T4qCrWPJGOsOl(5Vp)YJpIJNr4MFQX)(RNVx(VFpk)VFa9tpH)HFFd)xh)YJ)(VFa(VFC()yx6FqEI8Jd)rE(V)VE)V)8F(pE(ZJ)7bwxaVw(fpj)(VV4LgVE4zp5rxo5p9r8jOKZp(VpBE)MN)M9pqLKdE)V)6tFs9LMK3qUx4zxV)p(YJFa(XZ8JFEbp8apo(Rd8lp(0Jp5HrNzElpDr39b)JN4r4NX)5NJ)(3F)69Y)v3N9pOxoyUxgDx0F8B9V)KM(8N7)) ]])

end

-- Lazy initialization
if Hekili and Hekili.NewSpecialization then
    InitializeSpec()
else
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" then
            InitializeSpec()
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
