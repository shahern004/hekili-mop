-- HunterBeastMastery.lua
-- January 2025

if UnitClassBase( "player" ) ~= "HUNTER" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local PTR = ns.PTR

local strformat = string.format

local GetSpellCount = C_Spell.GetSpellCastCount

local spec = Hekili:NewSpecialization( 253, true )

spec:RegisterResource( Enum.PowerType.Focus, {
    steady_shot = {
        resource = "focus",
        cast = function(x) return x > 0 and x or nil end,
        aura = function(x) return x > 0 and "casting" or nil end,
        
        last = function()
            return state.buff.casting.applied
        end,
        
        interval = function() return state.buff.casting.duration end,
        value = 14,
    },
    
    cobra_shot = {
        resource = "focus",
        cast = function(x) return x > 0 and x or nil end,
        aura = function(x) return x > 0 and "casting" or nil end,
        
        last = function()
            return state.buff.casting.applied
        end,
        
        interval = function() return state.buff.casting.duration end,
        value = 14,
    },
    
    dire_beast = {
        resource = "focus",
        aura = "dire_beast",
        
        last = function()
            local app = state.buff.dire_beast.applied
            local t = state.query_time
            
            return app + floor( ( t - app ) / 2 ) * 2
        end,
        
        interval = 2,
        value = 5,
    },
    
    fervor = {
        resource = "focus",
        aura = "fervor",
        
        last = function()
            return state.buff.fervor.applied
        end,
        
        interval = 0.1,
        value = 50,
    }
} )

-- Talents
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    posthaste = { 19340, 109215, 1 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 60% for 4 sec.
    narrow_escape = { 19339, 109298, 1 }, -- When Disengage is activated, you also activate a web trap which encases all targets within 8 yards in sticky webs, preventing movement for 8 sec. Damage caused may interrupt the effect.
    crouching_tiger_hidden_chimera = { 19341, 109215, 1 }, -- Reduces the cooldown of Disengage by 6 sec and Deterrence by 10 sec.

    -- Tier 2 (Level 30)
    silencing_shot = { 19386, 34490, 1 }, -- Interrupts spellcasting and prevents any spell in that school from being cast for 3 sec.
    wyvern_sting = { 19384, 19386, 1 }, -- A stinging shot that puts the target to sleep for 30 sec. Any damage will cancel the effect. When the target wakes up, they will be poisoned, taking Nature damage over 6 sec. Only one Sting per Hunter can be active on the target at a time.
    binding_shot = { 19387, 109248, 1 }, -- Fires a magical projectile, tethering the enemy and any other enemies within 5 yards, stunning them for 5 sec if they move more than 5 yards from the arrow.

    -- Tier 3 (Level 45)
    intimidation = { 19388, 19577, 1 }, -- Commands your pet to intimidate the target, causing a high amount of threat and stunning the target for 3 sec.
    spirit_bond = { 19389, 19579, 1 }, -- While your pet is active, you and your pet regen 2% of total health every 10 sec.
    iron_hawk = { 19390, 109260, 1 }, -- Reduces all damage taken by 10%.

    -- Tier 4 (Level 60)
    dire_beast = { 19347, 120679, 1 }, -- Summons a powerful wild beast that attacks the target for 15 sec.
    fervor = { 19348, 82726, 1 }, -- Instantly restores 50 Focus to you and your pet, and increases Focus regeneration by 50% for you and your pet for 10 sec.
    a_murder_of_crows = { 19349, 131894, 1 }, -- Summons a flock of crows to attack your target over 30 sec. If the target dies while the crows are attacking, their cooldown is reset.

    -- Tier 5 (Level 75)
    blink_strikes = { 19391, 130392, 1 }, -- Your pet's Basic Attacks deal 50% increased damage and can be used from 30 yards away. Their range is increased to 40 yards while Dash or Stampede is active.
    lynx_rush = { 19392, 120697, 1 }, -- Commands your pet to rush the target, performing 9 attacks in 4 sec for 800% normal damage. Each hit deals bleed damage to the target over 8 sec. Bleeds stack and persist on the target.
    thrill_of_the_hunt = { 19393, 109306, 1 }, -- You have a 30% chance when you hit with Multi-Shot or Arcane Shot to make your next Steady Shot or Cobra Shot cost no Focus and deal 150% additional damage.

    -- Tier 6 (Level 90)
    glaive_toss = { 19394, 117050, 1 }, -- Throws a pair of glaives at your target, dealing Physical damage and reducing movement speed by 30% for 3 sec. The glaives return to you, also dealing damage to any enemies in their path.
    powershot = { 19395, 109259, 1 }, -- A powerful aimed shot that deals weapon damage to the target and up to 5 targets in the line of fire. Knocks all targets back, reduces your maximum Focus by 20 for 10 sec and refunds some Focus for each target hit.
    barrage = { 19396, 120360, 1 }, -- Rapidly fires a spray of shots for 3 sec, dealing Physical damage to all enemies in front of you. Usable while moving.
} )



-- Auras
spec:RegisterAuras( {
    -- Talent: Under attack by a flock of crows.
    -- https://wowhead.com/beta/spell=131894
    a_murder_of_crows = {
        id = 131894,
        duration = 30,
        tick_time = 1,
        max_stack = 1
    },
    -- Movement speed increased by $w1%.
    -- https://wowhead.com/beta/spell=186257
    aspect_of_the_cheetah_sprint = {
        id = 186257,
        duration = 3,
        max_stack = 1
    },
    -- Movement speed increased by $w1%.
    -- https://wowhead.com/beta/spell=186258
    aspect_of_the_cheetah = {
        id = 186258,
        duration = 9,
        max_stack = 1
    },
    -- Deflecting all attacks.  Damage taken reduced by $w4%.
    -- https://wowhead.com/beta/spell=186265
    aspect_of_the_turtle = {
        id = 186265,
        duration = 8,
        max_stack = 1
    },
    -- Talent: Damage dealt increased by $w1%.
    -- https://wowhead.com/beta/spell=19574
    bestial_wrath = {
        id = 19574,
        duration = 10,
        type = "Ranged",
        max_stack = 1
    },
    -- Stunned.
    binding_shot_stun = {
        id = 117526,
        duration = 5,
        max_stack = 1,
    },
    -- Movement slowed by $s1%.
    concussive_shot = {
        id = 5116,
        duration = 6,
        mechanic = "snare",
        type = "Ranged",
        max_stack = 1
    },
    -- Talent: Haste increased by $s1%.
    dire_beast = {
        id = 120694,
        duration = 15,
        max_stack = 1
    },
    -- Feigning death.
    feign_death = {
        id = 5384,
        duration = 360,
        max_stack = 1
    },
    -- Restores Focus.
    fervor = {
        id = 82726,
        duration = 10,
        max_stack = 1
    },
    -- Incapacitated.
    freezing_trap = {
        id = 3355,
        duration = 8,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Increased movement speed by $s1%.
    posthaste = {
        id = 118922,
        duration = 4,
        max_stack = 1
    },
    -- Silenced.
    silencing_shot = {
        id = 34490,
        duration = 3,
        mechanic = "silence",
        max_stack = 1
    },
    -- Asleep.
    wyvern_sting = {
        id = 19386,
        duration = 30,
        mechanic = "sleep",
        max_stack = 1
    },
    -- Poisoned.
    wyvern_sting_dot = {
        id = 19386,
        duration = 6,
        tick_time = 2,
        max_stack = 1
    },
    -- Stunned.
    intimidation = {
        id = 19577,
        duration = 3,
        max_stack = 1
    },
    -- Health regeneration increased.
    spirit_bond = {
        id = 19579,
        duration = 3600,
        max_stack = 1
    },
    -- Damage taken reduced by $s1%.
    iron_hawk = {
        id = 109260,
        duration = 3600,
        max_stack = 1
    },
    -- Talent: Bleeding for $w1 damage every $t1 sec.
    lynx_rush = {
        id = 120697,
        duration = 8,
        tick_time = 1,
        max_stack = 9
    },
    -- Talent: Next Steady Shot or Cobra Shot costs no Focus and deals additional damage.
    thrill_of_the_hunt = {
        id = 109306,
        duration = 20,
        max_stack = 1
    },
    -- Talent: Movement speed reduced by $s1%.
    glaive_toss = {
        id = 117050,
        duration = 3,
        mechanic = "snare",
        max_stack = 1
    },
    -- Talent: Focus reduced by $s1.
    powershot = {
        id = 109259,
        duration = 10,
        max_stack = 1
    },
    -- Talent: Rapidly firing.
    barrage = {
        id = 120360,
        duration = 3,
        tick_time = 0.2,
        max_stack = 1
    },
    -- Movement speed reduced by $s1%.
    wing_clip = {
        id = 195645,
        duration = 15,
        max_stack = 1
    },
    -- Healing over time.
    mend_pet = {
        id = 136,
        duration = 10,
        type = "Magic",
        max_stack = 1,
        generate = function( t )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "pet", 136 )

            if name then
                t.name = name
                t.count = count
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    -- Threat redirected from Hunter.
    misdirection = {
        id = 35079,
        duration = 8,
        max_stack = 1
    },
    -- Feared.
    scare_beast = {
        id = 1513,
        duration = 20,
        mechanic = "flee",
        type = "Magic",
        max_stack = 1
    },
    -- Disoriented.
    scatter_shot = {
        id = 213691,
        duration = 4,
        type = "Ranged",
        max_stack = 1
    },
    -- Casting.
    casting = {
        duration = function () return haste end,
        max_stack = 1,
        generate = function ()
            if action.steady_shot.channeling or action.cobra_shot.channeling then
                return {
                    name = "Casting",
                    count = 1,
                    applied = action.steady_shot.channelStart or action.cobra_shot.channelStart,
                    expires = action.steady_shot.channelStart + action.steady_shot.castTime or action.cobra_shot.channelStart + action.cobra_shot.castTime,
                    caster = "player"
                }
            end
        end,
    },
    -- MoP specific auras
    improved_steady_shot = {
        id = 53220,
        duration = 15,
        max_stack = 1
    },
    serpent_sting = {
        id = 1978,
        duration = 15,
        tick_time = 3,
        type = "Ranged",
        max_stack = 1
    },
    frenzy = {
        id = 19615,
        duration = 8,
        max_stack = 5
    },
    beast_cleave = {
        id = 115939,
        duration = 4,
        max_stack = 1
    },
    hunters_mark = {
        id = 1130,
        duration = 300,
        type = "Ranged",
        max_stack = 1
    },
    aspect_of_the_iron_hawk = {
        id = 109260,
        duration = 3600,
        max_stack = 1
    },
    rapid_fire = {
        id = 3045,
        duration = 3,
        tick_time = 0.2,
        max_stack = 1
    },
    explosive_trap = {
        id = 13813,
        duration = 20,
        max_stack = 1
    },
    -- Tier set bonuses
    tier14_4pc = {
        id = 105919,
        duration = 3600,
        max_stack = 1
    },
    tier15_2pc = {
        id = 138267,
        duration = 3600,
        max_stack = 1
    },
    tier15_4pc = {
        id = 138268,
        duration = 3600,
        max_stack = 1
    },
    -- Additional missing auras
    deterrence = {
        id = 19263,
        duration = 5,
        max_stack = 1
    },
    aspect_of_the_hawk = {
        id = 13165,
        duration = 3600,
        max_stack = 1
    },
} )

-- Pets
spec:RegisterPets({
    dire_beast = {
        id = 100,
        spell = "dire_beast",
        duration = 15
    },
} )



--- Mists of Pandaria
spec:RegisterGear( "tier16", 99169, 99170, 99171, 99172, 99173 )
spec:RegisterGear( "tier15", 95307, 95308, 95309, 95310, 95311 )
spec:RegisterGear( "tier14", 84242, 84243, 84244, 84245, 84246 )


spec:RegisterHook( "spend", function( amt, resource )
    if amt < 0 and resource == "focus" and talent.fervor.enabled and buff.fervor.up then
        amt = amt * 1.5
    end

    return amt, resource
end )


-- Abilities
spec:RegisterAbilities( {
    -- Fire a shot that slows the target's movement speed by $s1% for $d.
    concussive_shot = {
        id = 5116,
        cast = 0,
        cooldown = 5,
        gcd = "spell",
        school = "physical",

        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "concussive_shot" )
        end,
    },

    -- Talent: Summons a powerful wild beast that attacks the target for $d.
    dire_beast = {
        id = 120679,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        school = "nature",

        talent = "dire_beast",
        startsCombat = true,

        handler = function ()
            applyBuff( "dire_beast" )
            summonPet( "dire_beast", 15 )
        end,
    },

    -- Talent: Instantly restores $s1 Focus to you and your pet.
    fervor = {
        id = 82726,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",

        spend = -50,
        spendType = "focus",

        talent = "fervor",
        startsCombat = false,

        handler = function ()
            applyBuff( "fervor" )
        end,
    },

    -- Talent: Summons a flock of crows to attack your target over $d. If the target dies while the crows are attacking, their cooldown is reset.
    a_murder_of_crows = {
        id = 131894,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",

        talent = "a_murder_of_crows",
        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "a_murder_of_crows" )
        end,
    },

    -- Talent: Commands your pet to rush the target, performing $s1 attacks in $d for $s2% normal damage.
    lynx_rush = {
        id = 120697,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        school = "physical",

        talent = "lynx_rush",
        startsCombat = true,

        usable = function() return pet.alive, "requires a living pet" end,

        handler = function ()
            applyDebuff( "target", "lynx_rush" )
        end,
    },

    -- Talent: Throws a pair of glaives at your target, dealing Physical damage and reducing movement speed by $s2% for $d.
    glaive_toss = {
        id = 117050,
        cast = 3,
        cooldown = 6,
        gcd = "spell",
        school = "physical",

        spend = 15,
        spendType = "focus",

        talent = "glaive_toss",
        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "glaive_toss" )
        end,
    },

    -- Talent: A powerful aimed shot that deals weapon damage. Knocks all targets back and reduces your maximum Focus by $s3 for $d.
    powershot = {
        id = 109259,
        cast = 2.5,
        cooldown = 45,
        gcd = "spell",
        school = "physical",

        spend = 45,
        spendType = "focus",

        talent = "powershot",
        startsCombat = true,

        handler = function ()
            applyDebuff( "player", "powershot" )
        end,
    },

    -- Talent: Rapidly fires a spray of shots for $d, dealing Physical damage to all enemies in front of you. Usable while moving.
    barrage = {
        id = 120360,
        cast = function () return 3 * haste end,
        channeled = true,
        cooldown = 20,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "focus",

        talent = "barrage",
        startsCombat = true,

        start = function ()
            applyBuff( "barrage" )
        end,
    },

    -- Talent: Commands your pet to intimidate the target, causing a high amount of threat and stunning the target for $d.
    intimidation = {
        id = 19577,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",

        talent = "intimidation",
        startsCombat = true,

        usable = function() return pet.alive, "requires a living pet" end,

        handler = function ()
            applyDebuff( "target", "intimidation" )
        end,
    },

    -- Talent: Interrupts spellcasting and prevents any spell in that school from being cast for $d.
    silencing_shot = {
        id = 34490,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        school = "physical",

        talent = "silencing_shot",
        startsCombat = true,

        toggle = "interrupts",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function ()
            applyDebuff( "target", "silencing_shot" )
            interrupt()
        end,
    },

    -- Talent: A stinging shot that puts the target to sleep for $d. Any damage will cancel the effect.
    wyvern_sting = {
        id = 19386,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",

        talent = "wyvern_sting",
        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "wyvern_sting" )
        end,
    },

    -- Talent: Fires a magical projectile, tethering the enemy and any other enemies within $s2 yards for $d.
    binding_shot = {
        id = 109248,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",

        talent = "binding_shot",
        startsCombat = false,

        handler = function ()
            applyDebuff( "target", "binding_shot_stun" )
        end,
    },

    -- Sends you and your pet into a rage, increasing all damage you both deal by $s1% for $d.
    bestial_wrath = {
        id = 19574,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",

        startsCombat = false,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "bestial_wrath" )
        end,
    },

    -- A quick shot causing Physical damage. Generates $s2 Focus.
    arcane_shot = {
        id = 3044,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",

        spend = function () return buff.thrill_of_the_hunt.up and 0 or 20 end,
        spendType = "focus",

        startsCombat = true,

        handler = function ()
            if buff.thrill_of_the_hunt.up then
                removeBuff( "thrill_of_the_hunt" )
            end
        end,
    },

    -- A steady shot that causes Physical damage. Generates $s2 Focus.
    steady_shot = {
        id = 56641,
        cast = 2,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function () return buff.thrill_of_the_hunt.up and 0 or -14 end,
        spendType = "focus",

        startsCombat = true,

        handler = function ()
            if buff.thrill_of_the_hunt.up then
                removeBuff( "thrill_of_the_hunt" )
            end
        end,
    },

    -- A quick shot that causes Physical damage. Generates $s2 Focus.
    cobra_shot = {
        id = 77767,
        cast = 2,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        spend = function () return buff.thrill_of_the_hunt.up and 0 or -14 end,
        spendType = "focus",

        startsCombat = true,

        handler = function ()
            if buff.thrill_of_the_hunt.up then
                removeBuff( "thrill_of_the_hunt" )
            end
        end,
    },

    -- Give the command to kill, causing your pet to perform a special attack.
    kill_command = {
        id = 34026,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "focus",

        startsCombat = true,

        usable = function() return pet.alive, "requires a living pet" end,

        handler = function ()
            -- Kill Command effects
        end,
    },

    -- Fires several missiles, hitting all nearby enemies within $A2 yards.
    multi_shot = {
        id = 2643,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 30,
        spendType = "focus",

        startsCombat = true,

        handler = function ()
            -- Multi-Shot effects
        end,
    },

    -- Apply Hunter's Mark to the target, increasing damage dealt to the target.
    hunters_mark = {
        id = 1130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        handler = function ()
            applyDebuff( "target", "hunters_mark" )
        end,
    },

    -- Leap backwards.
    disengage = {
        id = 781,
        cast = 0,
        cooldown = function () return talent.crouching_tiger_hidden_chimera.enabled and 14 or 20 end,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function ()
            if talent.posthaste.enabled then applyBuff( "posthaste" ) end
            if talent.narrow_escape.enabled then
                -- Apply web trap effect
            end
        end,
    },

    -- Feign death, tricking enemies into ignoring you.
    feign_death = {
        id = 5384,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyBuff( "feign_death" )
        end,
    },

    -- Hurls a frost trap that freezes the first enemy that approaches.
    freezing_trap = {
        id = 1499,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "frost",

        startsCombat = false,

        handler = function ()
            -- Freezing trap effects
        end,
    },

    -- Maims the target, reducing movement speed by $s1% for $d.
    wing_clip = {
        id = 2974,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 20,
        spendType = "focus",

        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "wing_clip" )
        end,
    },

    -- Channel to heal your pet.
    mend_pet = {
        id = 136,
        cast = 10,
        channeled = true,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        usable = function ()
            if not pet.alive then return false, "requires a living pet" end
            if settings.pet_healing > 0 and pet.health_pct > settings.pet_healing then return false, "pet health is above threshold" end
            return true
        end,

        start = function ()
            applyBuff( "mend_pet" )
        end,
    },

    -- Redirects all threat you cause to the targeted party member.
    misdirection = {
        id = 34477,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyBuff( "misdirection" )
        end,
    },

    -- Causes the target to run in fear.
    scare_beast = {
        id = 1513,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        spend = 25,
        spendType = "focus",

        startsCombat = false,

        usable = function() return target.is_beast, "requires a beast target" end,

        handler = function ()
            applyDebuff( "target", "scare_beast" )
        end,
    },

    -- A short-range shot that deals damage and incapacitates the target.
    scatter_shot = {
        id = 19503,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyDebuff( "target", "scatter_shot" )
        end,
    },

    -- Call your pet to your side.
    call_pet = {
        id = 883,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,

        usable = function () return not pet.exists, "requires no active pet" end,

        handler = function ()
            summonPet( "hunter_pet", 3600 )
        end,
    },

    -- Dismiss your pet.
    dismiss_pet = {
        id = 2641,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,

        usable = function () return pet.exists, "requires an active pet" end,

        handler = function ()
            dismissPet()
        end,
    },

    -- MoP specific abilities
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
            applyDebuff( "target", "serpent_sting" )
        end,
    },

    focus_fire = {
        id = 82692,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        usable = function () return pet.alive and buff.frenzy.stack >= 1, "requires pet with frenzy stacks" end,

        handler = function ()
            local stacks = buff.frenzy.stack
            removeBuff( "frenzy" )
            -- Focus Fire converts frenzy stacks to haste
        end,
    },

    deterrence = {
        id = 19263,
        cast = 0,
        cooldown = function () return talent.crouching_tiger_hidden_chimera.enabled and 170 or 180 end,
        gcd = "spell",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyBuff( "deterrence" )
        end,
    },

    aspect_of_the_hawk = {
        id = 13165,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        handler = function ()
            applyBuff( "aspect_of_the_hawk" )
        end,
    },

    aspect_of_the_iron_hawk = {
        id = 109260,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        handler = function ()
            applyBuff( "aspect_of_the_iron_hawk" )
        end,
    },

    call_pet_1 = {
        id = 883,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,

        usable = function () return not pet.exists, "requires no active pet" end,

        handler = function ()
            summonPet( "hunter_pet", 3600 )
        end,
    },

    masters_call = {
        id = 53271,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        usable = function () return pet.alive, "requires a living pet" end,

        handler = function ()
            -- Masters Call removes movement impairing effects
        end,
    },

    rapid_fire = {
        id = 3045,
        cast = 3,
        channeled = true,
        cooldown = 300,
        gcd = "spell",
        school = "physical",

        startsCombat = true,

        start = function ()
            applyBuff( "rapid_fire" )
        end,
    },

    kill_shot = {
        id = 53351,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "focus",

        startsCombat = true,

        usable = function () return target.health_pct <= 20, "requires target below 20% health" end,

        handler = function ()
            -- Kill Shot effects
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
            applyDebuff( "target", "explosive_trap" )
        end,
    },

    thrill_of_the_hunt_active = {
        id = 109306,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = false,

        usable = function () return buff.thrill_of_the_hunt.up, "requires thrill of the hunt buff" end,

        handler = function ()
            -- Active version of thrill of the hunt
        end,
    },

    -- Movement speed increased for a short duration.
    aspect_of_the_cheetah = {
        id = 186257, -- MoP: 5118 (old), Legion+: 186257/186258
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "nature",

        startsCombat = false,

        handler = function ()
            applyBuff( "aspect_of_the_cheetah" )
        end,
    },
} )

spec:RegisterRanges( "arcane_shot", "kill_command", "wing_clip" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = false,
    nameplateRange = 40,
    rangeFilter = false,

    damage = true,
    damageExpiration = 3,

    potion = "tempered_potion",
    package = "Beast Mastery",
} )

spec:RegisterSetting( "pet_healing", 0, {
    name = strformat( "%s Below Health %%", Hekili:GetSpellLinkWithTexture( spec.abilities.mend_pet.id ) ),
    desc = strformat( "If set above zero, %s may be recommended when your pet falls below this health percentage. Setting to |cFFFFd1000|r disables this feature.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.mend_pet.id ) ),
    icon = 132179,
    iconCoords = { 0.1, 0.9, 0.1, 0.9 },
    type = "range",
    min = 0,
    max = 100,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "avoid_bw_overlap", false, {
    name = strformat( "Avoid %s Overlap", Hekili:GetSpellLinkWithTexture( spec.abilities.bestial_wrath.id ) ),
    desc = strformat( "If checked, %s will not be recommended if the buff is already active.", Hekili:GetSpellLinkWithTexture( spec.abilities.bestial_wrath.id ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "mark_any", false, {
    name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "check_pet_range", false, {
    name = strformat( "Check Pet Range for %s", Hekili:GetSpellLinkWithTexture( spec.abilities.kill_command.id ) ),
    desc = function ()
        return strformat( "If checked, %s will only be recommended if your pet is in range of your target.\n\n" ..
                          "Requires |c" .. ( state.settings.petbased and "FF00FF00" or "FFFF0000" ) .. "Pet-Based Target Detection|r",
                          Hekili:GetSpellLinkWithTexture( spec.abilities.kill_command.id ) )
    end,
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "thrill_of_the_hunt_priority", true, {
    name = strformat( "Prioritize %s Usage", Hekili:GetSpellLinkWithTexture( spec.talents.thrill_of_the_hunt.id ) ),
    desc = strformat( "If checked, %s or %s will be prioritized when %s is active to use the Focus-free proc.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.steady_shot.id ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.cobra_shot.id ),
        Hekili:GetSpellLinkWithTexture( spec.talents.thrill_of_the_hunt.id ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "focus_dump_threshold", 80, {
    name = "Focus Dump Threshold",
    desc = strformat( "Focus level at which to prioritize spending abilities like %s and %s to avoid Focus capping.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.arcane_shot.id ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.multi_shot.id ) ),
    type = "range",
    min = 50,
    max = 120,
    step = 5,
    width = 1.5
} )

spec:RegisterPack( "Beast Mastery", 20250707, [[Hekili:vZXAVXTXXFlcb9SuS9vEpLJRobK0KGAHeHaCoFQih5kY90XkEKxj5jzfiWF7D2hK7dU7ssz1A3VyyrUCMzN3ZSZEBMS5JBwhHkXBUEQ30fEN7D(yppVfEl3SU8Xd4nRpGcVdDl8Fsr7H)9hWOIYQGFf(xC(JKx)ysgkIaMISJ5HWs2S(MJXjLFiDZnAWE54PZM)DtMTzn6y5US8nRxV)428472SExCueM9f4IWnRjFXB9o)TElFpGTSdBwNexuwqWZ24KeCo8)UMs94u0nj4On)WM1H5XavfJG1KfESOk4Ivvbl8QcgvfCsvWnh3UDC8(d5z3JJ8Hnak6r)IDzLJpcWhfwgNLcBdXZzetE8b2B(LShElhWmAOk4qECgG0yCXMsyB2f9CjqpZy0teMsof48d40sGAItVDCoEpkoLSqyDcskm7MCeJIaSmRpyzodlNY31L7Ybk2pBRF5oS)UJPK9CvWtpvfuIYVfxoUmEp2VmZpkgZ4BtaiCMGgq5HOuCnruseY5fLULcha4IsIVhtPfjQBHNaW3GH9okX)HCu5ono(pqWbWL3HkayKbpDF8FIOVZj7UeLam1Xi)9hZJW5K9DyE2dfJ5RMspugJc2v0dA9XU59CuM8y6N8ZpwStbvQmIoqCdiiiCEpzUDaZ7is)WS97rPreWUWkyPaABoo9pFCCrjy8Z1A7dwOsy)TX5ycow6gh6GrxhzUNnLVRp)zazJ2BYeVIrg10Fl6yIrnCMRWOCeono0hDBCsC5JAQU)kyixfaS8BqLn(jESkO4rWbZ(EqZUSnxkXBoK1T9WjsQGs7yeOuap3FIgT)t7XaEtdFK(zvbGwdecypW3CBdOQss(RDyus5o)dHauUOLVy7AsaUIiKMjtafYN9h(KGdABIFlpEpkh2c)4VTUkipReXnVGL6ZKGHzzjrzpKwyYKWoAKGGqJ3xLjPR83lOfMbWPHsPAH4pHdpcHqhGFwUsJcRh0zM6zXDGMSNHWgNUNYahiXWjzpqaZFPkGb7Z6YjSf6yaw6U836c6wS21X8mp72)qq9C)BYspwGlCZ(lati6cht(MjZ9NFiu4Uu8mdeWclBDvzYhJj5AuqKcGaJ4njlCiHd1iWf(tBrG0NvtGg8vOhaXUGPfYAZnwiZnEooMXPfeQZPujofixaw(rO9GHP)cwAvmfMX7rFQk4BRc8gpxGPim8TqOpswSkcGFSgL9pJpD0pZc6xkf(ehFBQFeMKh0a9Zc53HrmFSEJFh3nq6Da(L8PgxeboQcfoxyEVKCC1Do1(1XIO7GlRtmqkFB5yt2ZL(NzFGa3drF2aLqZyD8I(LA98HNATRSOv3)YEZA)buF)3J5UyO(W8lEiUmCNjMFnCiFjoNiQYHALcFmmb250pUG8rAEl4oSzGf27CVgWhHUxpnAPTiNTjJRXKOJYbvuYe5sQd0Us8WLRylqDcZjoJv5JtX7bZno3vs5sgIg4koLN6WUvoUqbU(mogLjizgbjfgl5oIKavFnHQ5fqKuCutwE8NMNLvsFQeUOLzx4tYAqp9gIi(yjn1tUawndKoRokoLOher1duQwHlvcruoRlb1cbPkdn3S(t0RhILKSX8sPC49q96DZBprKTTukMOIdGhVAlWWDyCjsRoptRqpzEofWz0C2ExCzkllcsVdbruyQytwutDCHEywk45GeAPDNi0ExVYhsGoI1Y7KITfxGtVL0jhNvvwZRnt3dow9biEdt6Aq2XAWuberfctEtswrr2(cno))G6n69vbQnEQk43pqATeimU6yc8NElFdj5VPaDwf8B543wRlaPJqSZy5nPvmJqh4iOuxZJ1fPCYeJ83tsvppoe7NMLfLG7OLaM1bJZHu)3HE4ohAHKx7wov3HdlGU(BSa)MfUXzVa6SSX6cDmhNsatN1SBpgHnF9a4ENg4SusE933uKCPTA2gqbwwArYcUZmwnLAf3kN(HKvPuhtmMF0pdVrU7bNUhbX0jbSaXytAhBPRkj72yit7T5z7RcIjjD2rbA9AxXckEQLk27OfItvAHOA7H6B6TNQvWedLuQHKoRpnunLuotvaiqhW9H0qDk7euPA)iDAe(5rOgifAfS2jfIhRSok7XyIngZErvH77Z(jzfnu0)6yrjXYOJ6CCLENjAzAFsTRVzLZ9cEdkphu3vsIXeUxOx(TCTkCG0l3U3MGiaVecz1jsNQJ0jskBsaYTRytqEUwUe4pDacIsHxo6GI)t1xXuLu72ux5wzvotuYpTRIUOYxE5zwYLCPIVcTK7vuv)7ze3D1uE)ljVL5QdxAkkjoSKfuC)7qsFBqxT(VD1X6mmazACeZvx7EmnvsFtSWHRUPhjqRcjjMKY7u0bMOWYukLQRZlWEX32ETCumPmH67zj0HTE)SO1ZtPf4FPpWOVRleEaQ9mNwRHLDd)akjL)r7XctYDByePRvYPuXHdbRt86cTsgoTWRFeEBCyCzvR2bl(kkwS7HIJLT487ZYnTZyhfSuYi0vsH6Zl4w3o8w6YD3eBTE(6j96aEx61dVyNqqVv2pzfnzljTa5Cvx44qGVEItpt2Ikzns5mhXRUEIDNvp)omz5qi0Kh2Dmz8a3dps6HCPV0lp37Z4S2VEIDFuk9DSoDak3yqZ5abj29u5cEAz(EH0M1vsdNzJoO5LuFQCoZj5zupIs6Ejqj8(BpMRFWTF)XYS3gsB2qgekjxyJ0r6fFMeuXJPOdfGuN2pKE2AH2b(FMvQPANRMMqNPd7EolEEu0sntcttJHDxcdi46ZJ80yykHGT7VWDSWtTeoujZkDI8mBbl7mXMNrSsQ959qyFYJzt11SjF3M1pGYtPkTR)iPTeGVIS8sc4aRNxXMvQxbzSJ)3hbseqvrgjTcsx32ZAIx4ou6T4IXvx9rwFnssYEGD0fhZrajb5Aap)ybzXKbRG2(dg9vfqocDcdQSEDPzuSFmvz1rrKfhHkr3GkWVV6QQG3sj2wo24VsXVf8SRmS7OJbvF3C)sCk8QfVVk43tloEGahYcQ3hVs0YIx9LGvWAgXa28YNrEF5b)pFxPVript6G6LEa7GXvEaBfM278jZ4)B22gLFYhazF3jmL4PwvIvq8xe9y56p5psUZ0dGb1mRbdJ5mXkZrmIbeoJrCQFQ8dd1ZSIARhg9xezuF4(1hg1W4a2z(gpQVVA39QhS8lfpq(iLFvp0AeN2Jvfw(Ksomk0U)JEGXMJvCy40(US9XVj4nZ75x1COAVQhr6v3KSvF(xXUuTSvhG6CtvudtM5ioJAbt9rzwuxZxeMOa9oD9RD0KdJFz3Yxn5YU4UFTKkQzvjPtU4LI90YgRlLPME03hxfQAECAX(Yv7)1xejGHKOuPQQoRFsrFVV(jqzdmzl7oz)kGlAKLzGnexqhRxOwzcdb(J9XffusKVX4SNBXPqr8HasbNE3Hlb2qqvWhkzFenSiz25jBKYDK5FbFpDCzeNSBCAyYXispxXXK(BvtP)ZFNmU3FOeVV4pEdSv3fhUtE1O0hfyLZei7osNkseWvMNuJ0)wvaq7C08rgia1))OInwoIhnvcZpaMxs7ioilRxkLBqFu6X93GzQkjzLGq(d7R1eiDPrwmsuAidLeLpVz93ufyB(IU6BCoIrxrxqpNZOQRy0qX4M8wE9Q)62euXDVHmCrR0gbklRpllIVCtJIK5pQDEnVjE7QtO9sY(yj1hy1SEca730izgSImHOKMO5CgxTADCMwHIXffK26cTXpNnPqVHmprR0gNiUu39n7PbQUHfHWm2rVNEQDlhVy1spoYTF1CKrCN8uyn1xXgYkAwWi1lTZfl8gDI5gpwBby6s20Iuy)j9cVW4gnjd29snMtu3FMsocCQ1rR9fkdnpcaT4qcEgYltaulN1xiOkIZkSUvozGrNoaSmzXzMrtREWlB6B7iageQx6zb1n9xxcLTAU)iHA8qqQ19ROF6syTDV7hDQsx7VC1CVNEYi(TGhw71LWHAN5hrb)fRwu7d4Lz2af0IrlmAeN6NR6JGU3KhCTlxTyK75E8Y39IIUzdtapThBwfqPsam5lSjRLRkdb0zJSoXHg5u)xLuAHWlwnLR1yFQPK1kLCAoKyPp90PUMhIlwnF8IrTLnxU8m7ixEGQ04cwe(CMZsZmNoWePUfMnO20zbSqp7FB3(E5u10f2bIyqOiaHSkXSriRTRnYvnUzApUvGwVJnS0ag0ecY48vnY2RQneTJdPbHsY1MHPPQMbnXbdAO()TKZInW3mltsGV1CsvtNZ8g1mBuxS62Wi7WTVrqAfaXoihqWcBGqmEleWyXIEKB75LMSMN4aPAQCnMQwnMpXk76PNCm1sxUWHEVA14Yo0AnLsJAzf(5YqnYWQvQCjYnZ6MdSoLrn6YvN7zjaONdEIuBBAG(feOZ8LzBUF6l8CbeE4SlOeUTqlNrACal9DRJOUGAqz4U9NQV8(j)0bZuTNamnDaZNPCjRvTrvVfqxmQXYqhy93HABk1GlwgqBBrO)XZhz1gPUGyJ3oobMQpgVxR3db(jWrTdz1tpYuRje3ApJWu7AYjfdV(oSr24n7I234oJqT5(YzaExS6DwOez9OwxLokzyTzeuwPXlAUaxnhhnHaBojzcYAFB3VuCvZ)wVXZndePRCUjOmtdklndf5BwUAMAK)h7UPFH343nIFN0RBEGRRWQatQNd6k5dWu2CT(o1(0t63NwBGcOC5BTQKrLPRg7i1RfRj35lCGjBTKzeVrskL2z7AXlGV(qcSYKBC5Ri)LZQtnq2ZIoyAPe3coq0KXw0IRJap3j8TogcDKjAtGjoRAixZDbbPmXlRK7M4BuUa5RMiPB16kXBs4pZZcwETEDugqKTGFwsAWrGhDu3vPfMRSOMh35p8isiwAwWwPLYIPFHu4Lwi)RJYOMQBnd2x3UOqt)0Mib56FwtgzOTYAqwvV30VIjkWLtXUDNB)3VmbzqhGWvoQ53atH(nV(52rUokoQg4VW1Cvdw7L13taO2Ni6hP3DOEcjtLbR)vMsqV(7vvzm)5UvqC(tkOKBu67m6JNuQxFtvNbgZ(4P1160T(mdaYEPj29K7Ogf2rCmGFbQeKeFCmDQG1rRDeGqBBz87mPyiGGkh2maS5ZVrEq(XrahU56PlMrh96n)N]] )