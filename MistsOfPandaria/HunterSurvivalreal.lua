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
} )

-- Abilities
spec:RegisterAbilities( {
    -- Core MoP Survival Hunter Abilities
      -- Aimed Shot - Carefully aimed shot that does extra damage
    aimed_shot = {
        id = 19434,
        cast = 2.9,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 50,
        spendType = "focus",

        startsCombat = true,
        known = function() return true end,

        handler = function ()
            if talent.thrill_of_the_hunt.enabled then
                if math.random() < 0.2 then -- 20% chance proc
                    gain( 20, "focus" )
                    applyBuff( "thrill_of_the_hunt", 10 )
                end
            end
        end,
    },

    -- Arcane Shot - Quick shot that does arcane damage
    arcane_shot = {
        id = 3044,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",        spend = 25,
        spendType = "focus",

        startsCombat = true,
        known = function() return true end,

        handler = function ()
            -- Basic arcane shot, no special effects in MoP
        end,
    },

    -- Black Arrow - DoT that enables Lock and Load
    black_arrow = {
        id = 3674,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "shadow",        spend = 35,
        spendType = "focus",

        startsCombat = true,
        known = function() return true end,

        handler = function ()
            applyDebuff( "target", "black_arrow", 20 )
            -- Lock and Load proc chance handled by aura mechanics
        end,
    },

    -- Cobra Shot - Focus-efficient shot for Survival
    cobra_shot = {
        id = 77767,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",        spend = 20,
        spendType = "focus",

        startsCombat = true,
        known = function() return true end,

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
        spendType = "focus",

        startsCombat = true,

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
        spendType = "focus",

        startsCombat = true,

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
        spendType = "focus",

        startsCombat = true,

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
        school = "physical",

        startsCombat = true,

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
        school = "nature",

        startsCombat = false,

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
        school = "nature",

        startsCombat = false,

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
        school = "nature",

        startsCombat = false,

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
        school = "frost",

        startsCombat = false,

        handler = function ()
            -- Places freezing trap at location
        end,
    },

    explosive_trap = {
        id = 13813,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "fire",

        startsCombat = false,

        handler = function ()
            -- Places explosive trap at location
        end,
    },

    ice_trap = {
        id = 13809,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "frost",

        startsCombat = false,

        handler = function ()
            -- Places ice trap at location
        end,
    },

    snake_trap = {
        id = 34600,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",

        talent = "snake_trap",
        startsCombat = false,

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
        school = "physical",

        startsCombat = false,
        toggle = "defensives",

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
        school = "physical",

        toggle = "cooldowns",
        startsCombat = true,

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
        school = "physical",

        startsCombat = false,

        handler = function ()
            -- Leaps backwards
            setDistance( 15 )
        end,
    },

    feign_death = {
        id = 5384,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",

        startsCombat = false,

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
        school = "nature",

        talent = "binding_shot",
        startsCombat = false,

        handler = function ()
            applyDebuff( "target", "binding_shot" )
        end,
    },

    wyvern_sting = {
        id = 19386,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",

        talent = "wyvern_sting",
        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "wyvern_sting", 30 )
        end,
    },

    -- MoP Survival Signature
    raptor_bite = {
        name = "|T1376044:0|t |cff00ccff[MoP Survival Hunter]|r",
        cast = 0,
        cooldown = 0,
    }
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

    potion = "virmen_bite_potion",

    package = "Survival"
} )

local beastMastery = class.specs[ 253 ]

spec:RegisterSetting( "pet_healing", 0, {
    name = strformat( "%s Below Health %%", "Mend Pet" ),
    desc = strformat( "If set above zero, %s will be recommended when your pet falls below this health percentage. Set to 0 to disable the feature.", "Mend Pet" ),
    icon = 132179,
    iconCoords = { 0.1, 0.9, 0.1, 0.9 },
    type = "range",
    min = 0,
    max = 100,
    step = 1,
    width = "1.5"
} )

spec:RegisterSetting( "use_hunter_mark", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    desc = strformat( "If checked, %s will be recommended to mark targets for increased damage.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "mark_any", false, {
    name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterPack( "Survival", 20250618, [[MoP Survival Hunter - Basic rotation priority focused on Explosive Shot, Black Arrow, and Serpent Sting maintenance with Lock and Load procs. Prioritizes focus efficiency and DoT uptime. Uses Aimed Shot during Lock and Load procs and as a focus dump. Includes proper aspect management and utility abilities.]] )

-- Create a comprehensive debug function to test ability availability
local function debugAbilities()
    print("=== ABILITY DEBUG REPORT ===")
    print("Spec ID:", spec.id)
    print("Player Level:", UnitLevel("player"))
    print("Player Class:", UnitClassBase("player"))
    print("Current Spec:", GetSpecialization and GetSpecialization() or "Unknown")
    
    print("\n--- REGISTERED ABILITIES ---")
    local abilityCount = 0
    for abilityName, abilityData in pairs(spec.abilities) do
        abilityCount = abilityCount + 1
        
        -- Test various conditions
        local known = abilityData.known and abilityData.known() or "No known function"
        local usable = abilityData.usable and abilityData.usable() or "No usable function"
        local spellKnown = IsSpellKnown and IsSpellKnown(abilityData.id) or "Unknown"
        local spellUsable = IsUsableSpell and IsUsableSpell(abilityData.id) or "Unknown"
        
        print(string.format("Ability: %s (ID: %s)", abilityName, tostring(abilityData.id)))
        print(string.format("  known(): %s", tostring(known)))
        print(string.format("  usable(): %s", tostring(usable)))
        print(string.format("  IsSpellKnown(): %s", tostring(spellKnown)))
        print(string.format("  IsUsableSpell(): %s", tostring(spellUsable)))
        print("")
    end
    
    print("Total abilities registered:", abilityCount)
    print("=== END DEBUG REPORT ===")
end

-- Schedule debug after everything loads
C_Timer.After(5, debugAbilities)

-- Also create a slash command for manual debugging
SLASH_HEKILIDEBUG1 = "/hekilidebug"
SlashCmdList["HEKILIDEBUG"] = debugAbilities

-- Debug: Print when spec is fully loaded and copy shared abilities
print("DEBUG: Survival Hunter spec fully registered")

-- Use a timer to ensure shared abilities are copied after all specs are loaded
C_Timer.After(3, function()
    print("DEBUG: [Delayed] Manual shared abilities copying...")
    
    -- List of essential shared abilities we need
    local essentialAbilities = {
        "call_action_list",
        "run_action_list", 
        "wait",
        "global_cooldown",
        "auto_attack"
    }
    
    local copiedCount = 0
    
    -- Try to get them from class.abilities first
    for _, abilityName in ipairs(essentialAbilities) do
        if class.abilities and class.abilities[abilityName] then
            if not spec.abilities[abilityName] then
                spec.abilities[abilityName] = class.abilities[abilityName]
                copiedCount = copiedCount + 1
                print("DEBUG: [Manual] Copied from class.abilities:", abilityName)
            else
                print("DEBUG: [Manual] Already exists:", abilityName)
            end
        else
            print("DEBUG: [Manual] Not found in class.abilities:", abilityName)
        end
    end
    
    -- If that didn't work, try class.specs[0]
    if copiedCount == 0 and class.specs and class.specs[0] and class.specs[0].abilities then
        print("DEBUG: [Manual] Trying class.specs[0].abilities...")
        for _, abilityName in ipairs(essentialAbilities) do
            if class.specs[0].abilities[abilityName] then
                if not spec.abilities[abilityName] then
                    spec.abilities[abilityName] = class.specs[0].abilities[abilityName]
                    copiedCount = copiedCount + 1
                    print("DEBUG: [Manual] Copied from spec[0]:", abilityName)
                end
            end
        end
    end
    
    -- If still nothing, create minimal versions manually
    if copiedCount == 0 then
        print("DEBUG: [Manual] Creating minimal shared abilities manually...")
        
        spec.abilities.call_action_list = {
            name = "|cff00ccff[Call Action List]|r",
            listName = '|T136243:0|t |cff00ccff[Call Action List]|r',
            cast = 0,
            cooldown = 0,
            gcd = "off",
            essential = true,
        }
        
        spec.abilities.run_action_list = {
            name = "|cff00ccff[Run Action List]|r", 
            listName = '|T136243:0|t |cff00ccff[Run Action List]|r',
            cast = 0,
            cooldown = 0,
            gcd = "off",
            essential = true,
        }
        
        spec.abilities.wait = {
            name = "|cff00ccff[Wait]|r",
            listName = '|T136243:0|t |cff00ccff[Wait]|r',
            cast = 0,
            cooldown = 0,
            gcd = "off",
            essential = true,
        }
        
        copiedCount = 3
        print("DEBUG: [Manual] Created 3 essential abilities manually")
    end
    
    print("DEBUG: [Manual] Total abilities added:", copiedCount)
    
    -- Final verification
    local verified = {}
    for _, abilityName in ipairs(essentialAbilities) do
        if spec.abilities[abilityName] then
            verified[abilityName] = true
            print("DEBUG: [Final] ✓", abilityName, "is now available")
        else
            print("DEBUG: [Final] ✗", abilityName, "is still missing")
        end
    end
    
    print("DEBUG: [Final] Shared abilities setup complete!")
    
    -- Add known() function to all abilities that lack it
    local patchedCount = 0
    for abilityName, abilityData in pairs(spec.abilities) do
        if not abilityData.known then
            abilityData.known = function() return true end
            patchedCount = patchedCount + 1
        end
    end
    print("DEBUG: [Patch] Added known() function to", patchedCount, "abilities")
end)
