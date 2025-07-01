-- HunterSurvival.lua
-- January 2025

if UnitClassBase( "player" ) ~= "HUNTER" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

local spec = Hekili:NewSpecialization( 255 )

-- MoP uses focus for hunters
spec:RegisterResource( Enum.PowerType.Focus )

-- Talents
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    improved_tracking = { 90001, 19883, 1 }, -- Improved Tracking
    hunter_vs_wild = { 90002, 109298, 1 }, -- Hunter vs. Wild  
    crouching_tiger_hidden_chimera = { 90003, 109300, 1 }, -- Crouching Tiger, Hidden Chimera
    
    -- Tier 2 (Level 30) 
    improved_serpent_sting = { 90004, 82834, 1 }, -- Improved Serpent Sting
    binding_shot = { 90005, 109248, 1 }, -- Binding Shot
    wyvern_sting = { 90006, 19386, 1 }, -- Wyvern Sting
    
    -- Tier 3 (Level 45)
    spirit_bond = { 90007, 109212, 1 }, -- Spirit Bond
    aspect_of_the_iron_hawk = { 90008, 109260, 1 }, -- Aspect of the Iron Hawk
    exhilaration = { 90009, 109304, 1 }, -- Exhilaration
    
    -- Tier 4 (Level 60)
    fervor = { 90010, 82726, 1 }, -- Fervor
    dire_beast = { 90011, 120679, 1 }, -- Dire Beast
    thrill_of_the_hunt = { 90012, 109306, 1 }, -- Thrill of the Hunt
    
    -- Tier 5 (Level 75)
    a_murder_of_crows = { 90013, 131894, 1 }, -- A Murder of Crows
    lynx_rush = { 90014, 120697, 1 }, -- Lynx Rush
    blink_strikes = { 90015, 130392, 1 }, -- Blink Strikes
    
    -- Tier 6 (Level 90)
    glaive_toss = { 90016, 117050, 1 }, -- Glaive Toss
    powershot = { 90017, 109259, 1 }, -- Powershot
    barrage = { 90018, 120360, 1 }, -- Barrage
} )

-- Auras
spec:RegisterAuras( {
    -- Hunter Aspects
    aspect_of_the_hawk = {
        id = 13165,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_cheetah = {
        id = 5118,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_pack = {
        id = 13159,
        duration = 3600,
        max_stack = 1,
    },
    
    aspect_of_the_wild = {
        id = 20043,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Survival specific buffs/debuffs
    serpent_sting = {
        id = 1978,
        duration = 15,
        max_stack = 1,
        tick_time = 3,
    },
    
    hunters_mark = {
        id = 1130,
        duration = 300,
        max_stack = 1,
    },
    
    black_arrow = {
        id = 3674,
        duration = 20,
        max_stack = 1,
        tick_time = 2,
    },
    
    explosive_shot = {
        id = 53301,
        duration = 2,
        max_stack = 1,
    },
    
    lock_and_load = {
        id = 56453,
        duration = 20,
        max_stack = 1,
    },
    
    improved_steady_shot = {
        id = 53220,
        duration = 12,
        max_stack = 1,
    },
    
    -- Talent buffs
    thrill_of_the_hunt = {
        id = 109306,
        duration = 10,
        max_stack = 3,
    },
    
    -- Defensive abilities
    deterrence = {
        id = 19263,
        duration = 5,
        max_stack = 1,
    },
    
    feign_death = {
        id = 5384,
        duration = 6,
        max_stack = 1,
    },
    
    rapid_fire = {
        id = 3045,
        duration = 3,
        max_stack = 1,
        tick_time = 0.2,
    },
    
    -- Traps
    freezing_trap = {
        id = 3355,
        duration = 8,
        max_stack = 1,
    },
    
    ice_trap = {
        id = 13809,
        duration = 30,
        max_stack = 1,
    },
    
    explosive_trap = {
        id = 13813,
        duration = 20,
        max_stack = 1,
        tick_time = 2,
    },
    
    -- Bloodlust/Heroism effects
    bloodlust = {
        id = 2825,
        duration = 40,
        max_stack = 1,
    },
    
    heroism = {
        id = 32182,
        duration = 40,
        max_stack = 1,
    },
    
    time_warp = {
        id = 80353,
        duration = 40,
        max_stack = 1,
    },
    
    ancient_hysteria = {
        id = 90355,
        duration = 40,
        max_stack = 1,
    },
    
    -- Pet buffs
    mend_pet = {
        id = 136,
        duration = 10,
        max_stack = 1,
        unit = "pet",
    },
    
    -- Food/drink buffs
    drink = {
        id = 430,
        duration = 30,
        max_stack = 1,
    },
    
    food = {
        id = 433,
        duration = 30,
        max_stack = 1,
    },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Auto Attack - basic auto attacks
    auto_attack = {
        id = 1, -- Generic auto attack ID
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",
        
        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            -- Auto attack is automatic, no specific handler needed
        end,
    },
    
    -- Core MoP Survival Hunter Abilities
      -- Aimed Shot - Carefully aimed shot that does extra damage
    aimed_shot = {
        id = 19434,
        cast = 2.9,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 50,
        spendType = "focus",        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            if talent.thrill_of_the_hunt.enabled then
                if math.random() < 0.2 then -- 20% chance proc
                    gain( 20, "focus" )
                    applyBuff( "thrill_of_the_hunt", 10 )
                end
            end
        end,
    },    -- Arcane Shot - Quick shot that does arcane damage
    arcane_shot = {
        id = 3044,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",
        
        spend = 25,
        spendType = "focus",

        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            -- Basic arcane shot, no special effects in MoP
        end,
    },    -- Black Arrow - DoT that enables Lock and Load
    black_arrow = {
        id = 3674,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "shadow",
        
        spend = 35,
        spendType = "focus",

        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            applyDebuff( "target", "black_arrow", 20 )
            -- Lock and Load proc chance handled by aura mechanics
        end,
    },    -- Cobra Shot - Focus-efficient shot for Survival
    cobra_shot = {
        id = 77767,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        
        spend = 20,
        spendType = "focus",

        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            -- Basic cobra shot
        end,
    },

    -- Explosive Shot - Signature Survival ability
    explosive_shot = {
        id = 53301,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "fire",

        spend = 40,
        spendType = "focus",        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            applyDebuff( "target", "explosive_shot", 2 )
        end,
    },

    -- Multi-Shot - AoE ability
    multi_shot = {
        id = 2643,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "focus",        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            -- Hits multiple targets
        end,
    },

    -- Serpent Sting - DoT poison
    serpent_sting = {
        id = 1978,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        spend = 25,
        spendType = "focus",        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            applyDebuff( "target", "serpent_sting", 15 )
        end,
    },

    -- Steady Shot - Focus generator
    steady_shot = {
        id = 56641,
        cast = 2.0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            gain( 14, "focus" )
            if buff.improved_steady_shot.up then
                removeBuff( "improved_steady_shot" )
                gain( 15, "focus" ) -- Additional focus from improved steady shot
            else
                -- Start stacking buff for next shot
                applyBuff( "improved_steady_shot", 12 )
            end
        end,
    },

    -- Hunter's Mark - Tracking and damage increase
    hunters_mark = {
        id = 1130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            applyDebuff( "target", "hunters_mark", 300 )
        end,
    },

    -- Aspect abilities
    aspect_of_the_hawk = {
        id = 13165,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            removeBuff( "aspect_of_the_cheetah" )
            removeBuff( "aspect_of_the_pack" )
            removeBuff( "aspect_of_the_wild" )
            applyBuff( "aspect_of_the_hawk" )
        end,
    },

    aspect_of_the_cheetah = {
        id = 5118,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            removeBuff( "aspect_of_the_hawk" )
            removeBuff( "aspect_of_the_pack" )
            removeBuff( "aspect_of_the_wild" )
            applyBuff( "aspect_of_the_cheetah" )
        end,
    },

    -- Traps
    freezing_trap = {
        id = 1499,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "frost",        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            -- Places freezing trap at location
        end,
    },

    explosive_trap = {
        id = 13813,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "fire",        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            -- Places explosive trap at location
        end,
    },

    ice_trap = {
        id = 13809,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "frost",        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            -- Places ice trap at location
        end,
    },

    snake_trap = {
        id = 34600,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",        talent = "snake_trap",
        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            -- Places snake trap at location
        end,
    },

    -- Cooldowns
    deterrence = {
        id = 19263,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        school = "physical",        startsCombat = false,
        toggle = "defensives",
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            applyBuff( "deterrence", 5 )
        end,
    },

    rapid_fire = {
        id = 3045,
        cast = 3,
        channeled = true,
        cooldown = function() return talent.rapid_recuperation.enabled and 180 or 300 end,
        gcd = "spell",
        school = "physical",        toggle = "cooldowns",
        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        start = function ()
            applyBuff( "rapid_fire", 3 )
        end,

        tick = function ()
            -- Ticks every 0.2 seconds for high damage
        end,
    },

    -- Utility
    disengage = {
        id = 781,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            -- Leaps backwards
            setDistance( 15 )
        end,
    },

    -- Racial abilities
    arcane_torrent = {
        id = 28730, -- Blood Elf
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "arcane",
        
        startsCombat = false,
        known = function() return select(2, UnitRace("player")) == "BloodElf" end,
        usable = function() return true end,

        handler = function ()
            gain( 15, "focus" )
        end,
    },

    blood_fury = {
        id = 20572, -- Orc
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        known = function() return select(2, UnitRace("player")) == "Orc" end,
        usable = function() return true end,

        handler = function ()
            applyBuff( "blood_fury", 15 )
        end,
    },

    berserking = {
        id = 26297, -- Troll
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        known = function() return select(2, UnitRace("player")) == "Troll" end,
        usable = function() return true end,

        handler = function ()
            applyBuff( "berserking", 10 )
        end,
    },

    -- Utility abilities  
    feign_death = {
        id = 5384,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            applyBuff( "feign_death", 6 )
        end,
    },

    -- Talent Abilities
    binding_shot = {
        id = 109248,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",        talent = "binding_shot",
        startsCombat = false,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            applyDebuff( "target", "binding_shot" )
        end,
    },

    wyvern_sting = {
        id = 19386,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",        talent = "wyvern_sting",
        startsCombat = true,
        known = function() return true end,
        usable = function() return true end,

        handler = function ()
            applyDebuff( "target", "wyvern_sting", 30 )        end,
    },

    -- MoP Survival Signature
    raptor_bite = {
        name = "|T1376044:0|t |cff00ccff[MoP Survival Hunter]|r",
        cast = 0,
        cooldown = 0,
    },
    
    -- Call/run action list handlers for APL support
    call_action_list = {
        id = -1,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        usable = function( list ) return list ~= nil end,
        known = function() return true end,
        
        handler = function( list )
            if list and Hekili.PrimarySpec and Hekili.PrimarySpec.abilities[ list ] then
                Hekili.PrimarySpec.abilities[ list ].handler()
            end
        end,
    },
    
    run_action_list = {
        id = -2,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        usable = function( list ) return list ~= nil end,
        known = function() return true end,
        
        handler = function( list )
            if list and Hekili.PrimarySpec and Hekili.PrimarySpec.abilities[ list ] then
                Hekili.PrimarySpec.abilities[ list ].handler()
            end
        end,
    },
    
    -- Wait action for APL timing
    wait = {
        id = -3,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        usable = function() return true end,
        known = function() return true end,
        
        handler = function( sec )
            local wait_time = tonumber(sec) or 0.1
            -- This would normally advance the timeline
        end,
    },
    
    -- Pool focus action
    pool_focus = {
        id = -4,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        usable = function() return true end,
        known = function() return true end,
        
        handler = function()
            -- Wait for focus to regenerate
        end,
    },
} )

spec:RegisterRanges( "aimed_shot", "serpent_sting", "arcane_shot" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 8,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    potion = "virmen_bite",

    package = "Survival"
} )

local beastMastery = class.specs[ 253 ]

spec:RegisterSetting( "pet_healing", 0, {
    name = "Mend Pet Below Health %",
    desc = "If set above zero, Mend Pet will be recommended when your pet falls below this health percentage. Set to 0 to disable the feature.",
    icon = 132179,
    iconCoords = { 0.1, 0.9, 0.1, 0.9 },
    type = "range",
    min = 0,
    max = 100,
    step = 1,
    width = "1.5"
} )

spec:RegisterSetting( "use_hunter_mark", true, {
    name = "Use Hunter's Mark",
    desc = "If checked, Hunter's Mark will be recommended to mark targets for increased damage.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "mark_any", false, {
    name = "Hunter's Mark Any Target",
    desc = "If checked, Hunter's Mark may be recommended for any target rather than only bosses.",
    type = "toggle",
    width = "full"
} )

spec:RegisterPack( "Survival", 20250618, [[Hekili:fV1ctTnss4FluBDoqTzDmgmj7EbQYby315iah2zV7QTIThKgJ1HSKx9acx5s)2VUNxAgPrpmHQsQkj2sZ0VME(MU7P909Noz6yxscD6L971FqVJ6Fq3(73)Dh(2PJtEAnD641eN7j3bFiGSc(3XPrp49aXhFXt(HexKaXHProWlNo(2up)KrbtV1KQ7)UU7)Zh(UbhmDmjnzzyeqOvPlI8UF64LEUUu(mOXothpzPxC2C8VKS5cUNnpCb8DNeVWGS5(EXjWRxegLn)3P37571D6y2drHHeVM6W(4LmTJgqU1N6o9dth7e5LqJ8ithVdWHGzoHRULKKnVt2C4bRctdsOUSVUk8bVG7KV520fl6YP7SWfZswsN5SKstil7MUg4itUKCUWi4QvK3A(yo(4HJV(8tNKn)tdVC4VD(No)Yjtta7uLIQPC(SeLLKhVhyscSOrtMTIeaM0v0GK6TrWy7UKs8tw2DTdW93Nn)TduglAG7mCePRLpYuqX3r)kBrrjvYjvYM06)Kn)6ZnSDzZBAkA)PEd9o6cDjLkxlCi((mTGzrDPliP(wnLQfJ0KWzXldtSXFdlXq2YgyDZxIkZwMR(m(2rNWqF3WhdIrsFqLQwHLX(9yQNfDBb17UGzUussrh3FfFt28ZWxLnhKTO7ObopH89W6uPRjPXW(3OWecF3RtyGRh(rWg)tzZxcsMyVmQ8EeF4dEjPSrd(oXuatOx39ZLXhjEj6kN2EvGcGrYlEwcbeVe2J3SrSRXnYl4EM)Q6rlcdDvprS)h1Ob1Qr06wH4FzgUgzSsvyNhWKJQJjNrxqdI9EamDKaatknbG5sEQLmZvoBKpVTwpUWZbBrejWzjyTQJ85g8hiW)buRljKotTwziaWBqw)U6y9PsFxHkUI8FrVaYTOM6rJBPUASf4NRNHrAEITK8QHduF)EvUdBrOtkOiNaiu9hOr6qW2Y37)nG59RJUC4f4)DXfNFZ2I4HO(ruXg9Mou0YXl4HhAO8p)dGmna)oUzdwULbuWad(u41zZh0DqxaG6danzp86)5nVb(Rca5F)jWwm0LSw(GMmcA)jB(Fm8Mrd)WfNpgOXLNLn)0RU8SrtgD1LJ3sc9ja137N4ancpy2MjxAcveOI0dpBEI3kgyKCRt8wYSRV58tV6tFy4e2hVE4ndrrERiYwC4x(YyC6QvWUc(PD1CaZoOEZCnwYwxJbSUiLBd3i1fmc0zWrHUEW2WtYMVV2gf(0MXNh3RnFJDTETk0i4CMzo5ykDYT2DJiR9CNTWlIoJ8aXZhFyoVZF73YM0tV6Qlo7Q)1LMrNSl45co5qiFJWTWF(YrWdV4QFB0P7TvREav5WJND9y8muLAAEYzAGhg7syG)t1VExJvBxXM8CZs(HM(WbM(PX8W(2JnC5K7gNqwTM6cwBkXv7Kk5ZR3dQgbsXbnjkIUI4HVh8J6RTucS2lGghxkUKBBMzfw9NGXlqtSBJb1Yhb1t4dA)srn0k(zqJ(2ckO0jmq4BhmW07UarvqWroKaCdxuelmfdL7gcxzuN2cBGtJyyukffIVlKVB2wyenRDsb5wGc0O7X4lSetWwqh07B2I0ONA8O(H3Xcxca1c5qXsLBjnk0lE1BuEYYeBFWlccmlE2TG0OluMU8TWSZ5ydHlKq8H1KUlOrpeg1vmeg5LlZWo(d7zCORyWcXWAW74a(wWWMm8cgQ1Wpm6c4qr8qYD)0vWzYWNVz82IynXdpG)qe)h1wMx0(vdKlSjUik9TucyX1Tlw038rYOC1GDcktMTknYfoLbIkXjk8XydgKFew5XvCPxSfzgcfuL0vIkfHxywNbkRt28S5m9OAmsHECRpGxmlgGnUN2KnsFSmQxmzTsu3)PGVolknEzfwN83)CSkQzZeMI5zvsyUZNazXayyXXnPPAd1QL(it)WQbAfSED4JaUfe5UbJ3kLvrcghRgavUUsIIG8dBsrfdJhKeMOvTHhvdTv6Y6)kAgd3z2sV7wwMtFdikdVccj(MRMiIxD3d(reL5MF78jiCcp6EiZMRo9ZJfXfTvGm1hKtdornQ)6UuTl4LQO0kmzbvnGQEpOfc5h(O18jLvFsKOFTob7Ih8zucOb94r0zPiFy1H2RkNp6xxcHphjYG(57xC25)65xoE0FCUinSppbpX5)8cU4xqRoSYAEXhyCsyqdHOMSecVmPRQIhI09LbnRx8q00Yw(upzpnNbVy8OlhzCc1bjZsCY1JvylCa5ujjIe8xPqyo)piWgBLyyI(aGCqGricLDf5ophEufXVHgG7XJ5(tQQDuR7Klakcr0Tg2CbhTauhsTZbJVRt5m9orplpJjv)YxL8OamS(qMfrxerJx22Kon2nv3cpNugEu4kFVCsDVNVVTfH)b8CPT3d8yOFL6KMGLHIeG3RXU9793KBo3RENHD0uB)qN7NrcCNHxbdR2vpq13KU2perfSjrNlFPuSwh5fgXcwE3hxsbzmaF6faheL14cGh7vkbh74w36tqjlcc4rUAOhmI6LfeQpGVbGcWxjCsfbcFhnGgj2UXKMZcNuFIsVegPcAF28swTDraEASH9JB(4mAV6ZzAxLcIyih9woKHs0bOg0Hsw(milmH8lHMRW7(OsP)zr5gYEJbIGqwCtxTwwZcXJqqpGg(UX7vF2BAjUC0rYygRDTqoiv(9Mlj86iuAqAorfR0qLvB9u8f2uyDVlUANF9e7nvCi7JKOaaDjgVBsqO9wTomssNxjUUXxb7OPaABegBrC4kSU9PjHRiSBu0zjUBpUB2hVWdT87)lWjEbXPRrkHdGRbkYvOYQVsnX(TCIybxXzXe4fH(qqemOtsAebuBiSu45qcSUCuPeCyssHf)gpCiroUaUvlnWy0UUS8QjjKBjX0Fj7JSW5Sk)W7(OftN5vI8szbLxY4Rmg7PHbpq5Je5BxwQmAxIjW9KqTzZF0U7)19AHTxE1CFxS4sjUcJS4(jFPSUQ7YSv(K4GjjjWg28HFq9Mr(3y3dt(CoSY5ODHL5dFqLdhV7W8XD0ZquE7ZyoV7zmNF(zmN979CMu1l254PFx8SzxyR4Z4n1wfmI82TEX8XTcL2KZE(vL0gFDJ7747I1TkK6YVdTaIxOF7ovSCOkj6l1YrEv)B1YG42gAZIG62cQbPbRYleIZQ8P9N4vaCFaOIF5VJfjpjccsbsrJftu1yqpxcvniLzb(BdevEL4Bd4uE92BdSeVU3TcmIxO6wbbLxJxTHxZjofl6Q2SQ2pqViPAtO6tDuvXuB0vFOJwzK0gF1RRQYgQn6Awt5fP77dgsrZTeTMTal(IYyj(E((5kqqKfH4LcaXOgbTbdX8CVMqruP(3M4vmtXPnHSOLVtBICPkguTdKwIITbvW04uvmN8Qs(sTcQx1X2SaQvsV2ScQxqU2SiwU0BvAkiHVygbTn6nP)wrCQr)vvNUnAFzhaSzDxhfUWZh1F4lGbnMFxY85lSgSSTXkpkUXBqRNNnFucFsSW4WSzqULSe7JukKZ2t6vyXlWXp1fVTAQhamfjbI(ZpJnz4i4414V8ASqmEol1hnj4PCUkW4WDkEoEj(50vhYtYu4Ozfu2Fk6jayz6lz8YdL)O(AC(rwz)uAKGKjYHYSgShfKUcouM5z4hMa2ZrRKg83zcsJUithJbMn9Y(dgGD1fZIpD8pKnV6UPcxH(HAB7jyaYY08A8UWp28smEnqUu6XShCYXh1R6rdh7Op43FynJDf11lDLjTpSxh(elZe9BBtmjrfWO(qqvB2i(Mp4X4FYXR9jprJ4F7hpq9wZYsxIh2kLSGzLRgTObuE)rfjJLkGkiYoiv0lFLSI2fOGTALjib)gy1FpElSfMFLfpuNiLheJsmNLMBTTcC0OrqfCH3lUCIe3nhI5KJpO40D8PKhApfoUVqoRR)6kWcBDaMGn2BViI7tD2PCFqbptVHqkWfJwcrqER3ySTlkPFpuTykwfT73h54bXDvP8(Jh)MY5Q9AVfhVt1DYzhBVlVhoTZL8SBzux7UUSoCJ0BzZWE7bA)cJKUHdhDj45Dk)QJV(MrxDd7kcVy04jSbCUSl0ZmAsAjUzUSHMP8ArXKhTVlyx5MVxF(flGIWXNx9xbfQOh51jJw9QqXi)kLEF)EDY)fuiCd(M6DED2I1961XuNJ71DFKV8EMVt5(LFZgJELx8vrFYVzJ83iJq(OBP5YSIVcQurRU3m1uHzkxan6L9MNpGAH2c1guduScqmXz2Bs9M5sEVmkPOExO388ZhPunl9dicpLxUlu4rwcyqSbN57R8Z6SJybTJWHOTqdvXfj8tohAGGsFGkAhafdvR1al1Zgaz2UA7Ig0BZgZEAa2yTN(olBuulFHc7kpSxtZvp5bCYf7sGtoUFNDZXl3SrVVa2tO)B3D1BxqkNvctCk1cbYnVf(HuLJJBSjf1qXnmGKRGTnMMGOg8jHpN5ez7cw6O51z90JICvEPkfoVrJokVhRTEn7eKTSNPZfh1Objjpaad4cJd77OESTinStxzPkRHQ7woceaswlcK96ur)xxHQiR4zn8SM2T(K(k)1A6nA7Sww)ZxJj6CSSVPRwo2cQ0VoQWK3TRDNTZAZYTISKNTYbd6SnAqEny3wDpVESnQVTV)NTZk(04haP3z0iJ1D)QuZ5EjLANy2tl0wW2LaEje5iyw6vArMIyoJ7y2D02WR1jCEfL1iE5MoUuWy26x3kCukwvungvzpi3zNA6(4o2tIObnvVS2AIGT2hUjsPQHRgDk1OWkvqVfHBw01SUh1GtHwDT0eel93zt6JQe7AKPud)2SOB1QZltNUb3S3BlP712JS5HCfsBf1vcTzzCksO2BkBjbZZp3aDQ(jLxlXkMKF4JAhZFJHHs84X86YaFG)d(LSgRRNElJPAlWC2lJQgpgwVUoSOn2Y(B0kvn1SQPyUpMTYpvB(XBvVfAvivxDHwKIAr3DmVKe)GL2FRDnnOvMAEdfmdUYiyTnX4IW21IGw5SwT3mC3SuYobtFb6dWwAdAJj4524EwfbTR9b5)UYc8(2nBuYsLvsCpBoMhPYW950TDTyxK4m)JoQt9EmD2rfdRTwku71LAMqzLCm(fxlLm7ceKG3awJco9)p]] )

-- Simple action priority list for testing
spec:RegisterPack( "Survival", 20250124, [[Test priority list for Survival Hunter in MoP Classic.

This is a basic implementation for testing purposes.
actions=hunters_mark,if=!debuff.hunters_mark.up&target.time_to_die>15
actions+=/serpent_sting,if=!dot.serpent_sting.ticking&target.time_to_die>15
actions+=/explosive_shot,if=cooldown.explosive_shot.ready
actions+=/black_arrow,if=cooldown.black_arrow.ready&!debuff.black_arrow.up
actions+=/cobra_shot,if=focus>=25
actions+=/steady_shot]] )

-- State expressions to map modern SimC variables to MoP Classic equivalents
spec:RegisterStateExpr( "in_combat", function()
    return state.combat > 0
end )

spec:RegisterStateExpr( "spell_is_targeting", function()
    -- MoP doesn't have spell targeting, return false
    return false
end )

spec:RegisterStateExpr( "bloodlust", function()
    -- Return a table that behaves like a buff with .up property
    return {
        up = state.buff.bloodlust.up or state.buff.heroism.up or 
             state.buff.time_warp.up or state.buff.ancient_hysteria.up
    }
end )

spec:RegisterStateExpr( "threat", function()
    -- Return a table that behaves like threat API
    local threatSituation = 0
    if UnitThreatSituation then
        threatSituation = UnitThreatSituation("player", "target") or 0
    end
    return {
        situation = threatSituation
    }
end )

-- Additional state expressions for common modern variables
spec:RegisterStateExpr( "mend_pet", function()
    -- Check if mend pet is active on pet
    return state.pet.buff.mend_pet.up
end )

-- Map target.time_to_die to target.ttd for compatibility
spec:RegisterStateExpr( "time_to_die", function()
    return state.target.ttd
end )

-- Additional buff/debuff state expressions if needed
spec:RegisterStateExpr( "drink", function()
    return state.buff.drink.up or false
end )

spec:RegisterStateExpr( "food", function()
    return state.buff.food.up or false  
end )

-- Pet state expressions
spec:RegisterStateExpr( "pet", function()
    return {
        exists = state.pet.exists or false,
        alive = state.pet.alive or false,
        health_pct = state.pet.health_pct or 0,
        buff = state.pet.buff or {},
        debuff = state.pet.debuff or {},
    }
end )

-- Target state expressions  
spec:RegisterStateExpr( "target", function()
    return {
        exists = state.target.exists or false,
        health_pct = state.target.health_pct or 100,
        time_to_die = state.target.ttd or 0,
        ttd = state.target.ttd or 0,
        distance = state.target.distance or 0,
        level = state.target.level or 1,
        classification = state.target.classification or "normal",
        buff = state.target.buff or {},
        debuff = state.target.debuff or {},
    }
end )

-- Focus regen and management
spec:RegisterStateExpr( "focus_regen", function()
    return state.focus.regen or 4 -- Default focus regen in MoP
end )

spec:RegisterStateExpr( "time_to_max_focus", function()
    local current = state.focus.current or 0
    local max = state.focus.max or 100
    local regen = state.focus.regen or 4
    if current >= max then return 0 end
    return (max - current) / regen
end )

-- Cooldown expressions
spec:RegisterStateExpr( "cooldown", function()
    return state.cooldown or {}
end )

-- Action expressions  
spec:RegisterStateExpr( "action", function()
    return state.action or {}
end )

-- Spell expressions
spec:RegisterStateExpr( "spell", function()
    return state.spell or {}
end )

-- GCD expression
spec:RegisterStateExpr( "gcd", function()
    return state.gcd or { remains = 0, max = 1.5 }
end )

-- Combat state
spec:RegisterStateExpr( "combat", function()
    return state.combat > 0
end )

-- Buff/debuff helper functions
spec:RegisterStateFunction( "buff_up", function( buff_name )
    return state.buff[ buff_name ] and state.buff[ buff_name ].up or false
end )

spec:RegisterStateFunction( "debuff_up", function( debuff_name )
    return state.debuff[ debuff_name ] and state.debuff[ debuff_name ].up or false
end )

spec:RegisterStateFunction( "cooldown_ready", function( ability_name )
    return state.cooldown[ ability_name ] and state.cooldown[ ability_name ].ready or false
end )
