    -- HunterSurvival.lua
    -- july 2025 by smufrik

-- Early return if not a Hunter
if select(2, UnitClass('player')) ~= 'HUNTER' then return end

    local addon, ns = ...
local Hekili = _G[ "Hekili" ]
    
-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end
    
local class = Hekili.Class
local state = Hekili.State

local strformat = string.format
    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local spec = Hekili:NewSpecialization( 255, true )

    -- Use MoP power type numbers instead of Enum
    -- Focus = 2 in MoP Classic
    spec:RegisterResource( 2, {
        steady_shot = {
            resource = "focus",
            cast = function(x) return x > 0 and x or nil end,
            aura = function(x) return x > 0 and "casting" or nil end,

            last = function()
                return state.buff.casting.applied
            end,

            interval = function() return state.buff.casting.duration end,
            value = 9,
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
        },
    } )

    -- Talents
    spec:RegisterTalents( {
        -- Tier 1 (Level 15)
        posthaste = { 1, 1, 109215 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 60% for 4 sec.
        narrow_escape = { 1, 2, 109298 }, -- When Disengage is activated, you also activate a web trap which encases all targets within 8 yards in sticky webs, preventing movement for 8 sec. Damage caused may interrupt the effect.
        crouching_tiger_hidden_chimera = { 1, 3, 109215 }, -- Reduces the cooldown of Disengage by 6 sec and Deterrence by 10 sec.

        -- Tier 2 (Level 30)
        binding_shot = { 2, 1, 109248 }, -- Your next Arcane Shot, Chimera Shot, or Multi-Shot also deals 50% of its damage to all other enemies within 8 yards of the target, and reduces the movement speed of those enemies by 50% for 4 sec.
        wyvern_sting = { 2, 2, 19386 }, -- A stinging shot that puts the target to sleep for 30 sec. Any damage will cancel the effect. When the target wakes up, the Sting causes 0 Nature damage over 6 sec. Only one Sting per Hunter can be active on the target at a time.
        intimidation = { 2, 3, 19577 }, -- Command your pet to intimidate the target, causing a high amount of threat and reducing the target's movement speed by 50% for 3 sec.

        -- Tier 3 (Level 45)
        exhilaration = { 3, 1, 109260 }, -- Instantly heals you for 30% of your total health.
        aspect_of_the_iron_hawk = { 3, 2, 109260 }, -- Reduces all damage taken by 15%.
        spirit_bond = { 3, 3, 109212 }, -- While your pet is active, you and your pet will regenerate 2% of total health every 2 sec, and your pet will grow to 130% of normal size.

        -- Tier 4 (Level 60)
        fervor = { 4, 1, 82726 }, -- Instantly resets the cooldown on your Kill Command and causes you and your pet to generate 50 Focus over 3 sec.
        dire_beast = { 4, 2, 120679 }, -- Summons a powerful wild beast that attacks your target and roars, increasing your Focus regeneration by 50% for 8 sec.
        thrill_of_the_hunt = { 4, 3, 109306 }, -- Your successful Auto Shots have a 15% chance to make your next Arcane Shot, Chimera Shot, or Aimed Shot cost no Focus.

        -- Tier 5 (Level 75)
        a_murder_of_crows = { 5, 1, 131894 }, -- Sends a murder of crows to attack the target, dealing 0 Physical damage over 15 sec. If the target dies while under attack, A Murder of Crows' cooldown is reset.
        blink_strikes = { 5, 2, 109304 }, -- Your pet's Basic Attacks deal 50% additional damage, and your pet can now use Blink Strike, teleporting to the target and dealing 0 Physical damage.
        lynx_rush = { 5, 3, 120697 }, -- Your pet charges your target, dealing 0 Physical damage and causing the target to bleed for 0 Physical damage over 8 sec.

        -- Tier 6 (Level 90)
        glaive_toss = { 6, 1, 117050 }, -- Throws a glaive at the target, dealing 0 Physical damage to the target and 0 Physical damage to all enemies in a line between you and the target. The glaive returns to you, damaging enemies in its path again.
        powershot = { 6, 2, 109259 }, -- A powerful shot that deals 0 Physical damage and reduces the target's movement speed by 50% for 6 sec.
        barrage = { 6, 3, 120360 }, -- Rapidly fires a spray of shots for 3 sec, dealing 0 Physical damage to all enemies in front of you.
        
        -- Additional talents
        piercing_shots = { 7, 1, 82924 }, -- Your critical strikes have a chance to apply Piercing Shots, dealing damage over time.
        lock_and_load = { 7, 2, 56453 }, -- Your critical strikes have a chance to reset the cooldown on Aimed Shot.
        careful_aim = { 7, 3, 82926 }, -- After killing a target, your next 2 shots deal increased damage.
    } )

    -- Auras
spec:RegisterAuras( {
        aspect_of_the_hawk = {
            id = 13165,
            duration = 3600,
        max_stack = 1
    },
        aspect_of_the_iron_hawk = {
            id = 109260,
            duration = 3600,
            max_stack = 1,
            generate = function( t )
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "player", 109260 )
                
                if name then
                    t.name = name
                    t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 3600
                    t.caster = "player"
                    return
                end
                
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
            end,
        },
        casting = {
            id = 116951,
            generate = function( t )
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "player", 116951 )
                
                if name then
                    t.name = name
                    t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 2.5
                    t.caster = "player"
                    return
                end
                
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
            end,
        },
        cobra_shot = {
            id = 19386,
        duration = 6,
        max_stack = 1
    },

        disengage = {
            id = 781,
            duration = 20,
            max_stack = 1
        },

        focus_fire = {
            id = 82692,
            duration = 20,
            max_stack = 1
        },
        kill_command = {
            id = 34026,
            duration = 5,
        max_stack = 1
    },
        multi_shot = {
            id = 2643,
            duration = 4,
        max_stack = 1
    },
        rapid_fire = {
            id = 3045,
        duration = 15,
        max_stack = 1
    },
        steady_focus = {
        id = 109259,
        duration = 10,
        max_stack = 1
    },

        thrill_of_the_hunt = {
            id = 109306,
            duration = 8,
            max_stack = 1
        },

        hunters_mark = {
            id = 1130,
            duration = 300,
        type = "Ranged",
        max_stack = 1
    },

        black_arrow_debuff = {
            id = 3674,
            duration = 15,
            max_stack = 1,
            type = "Magic"
        },

    serpent_sting = {
        id = 118253,    
        duration = 15,
        tick_time = 3,
        type = "Ranged",
        max_stack = 1
    },

        concussive_shot = {
            id = 5116,
            duration = 6,
            max_stack = 1
        },

        deterrence = {
            id = 19263,
            duration = 5,
            max_stack = 1
        },

        mend_pet = {
            id = 136,
            duration = 10,
            max_stack = 1,
            generate = function( t )
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "pet", 136 )
                
                if name then
                    t.name = name
                    t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 10
                    t.caster = "pet"
                    return
                end
                
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
            end,
        },

        misdirection = {
            id = 34477,
            duration = 8,
            max_stack = 1
        },

        aspect_of_the_cheetah = {
            id = 5118,
            duration = 3600,
            max_stack = 1
        },

        a_murder_of_crows = {
            id = 131894,
            duration = 30,
            max_stack = 1
        },

        lynx_rush = {
            id = 120697,
            duration = 4,
            max_stack = 1
        },

        barrage = {
            id = 120360,
            duration = 3,
            max_stack = 1
        },

        black_arrow = {
            id = 3674,
            duration = 15,
            max_stack = 1,
        },

        lock_and_load = {
            id = 56453,
            duration = 8,
            max_stack = 1
        },

        piercing_shots = {
            id = 82924,
            duration = 8,
            max_stack = 1
        },

        careful_aim = {
            id = 82926,
            duration = 20,
            max_stack = 2
        },

        blink_strikes = {
            id = 109304,
            duration = 0,
            max_stack = 1
        },

        -- Tier 2 Talent Auras (Active abilities only)
        binding_shot = {
            id = 109248,
            duration = 4,
            max_stack = 1
        },

        wyvern_sting = {
            id = 19386,
            duration = 30,
            max_stack = 1
        },

        intimidation = {
            id = 19577,
            duration = 3,
            max_stack = 1
        },

        wyvern_sting = {
            id = 19386,
            duration = 30,
            max_stack = 1
        },

        -- Tier 3 Talent Auras (Active abilities only)
        exhilaration = {
            id = 109260,
            duration = 0,
            max_stack = 1
        },

        -- Tier 4 Talent Auras (Active abilities only)
        fervor = {
            id = 82726,
            duration = 3,
            max_stack = 1
        },



        silencing_shot = {
            id = 34490,
            duration = 3,
            max_stack = 1
        },

        explosive_shot = {
            id = 53301,
        duration = 4,
            max_stack = 1,
        },

        stampede = {
            id = 121818,
            duration = 12,
            max_stack = 1,
            
        },

        explosive_trap = {
            id = 13813,
            duration = 20,
            max_stack = 1
        },

        
    } )

    spec:RegisterStateFunction( "apply_aspect", function( name )
        removeBuff( "aspect_of_the_hawk" )
        removeBuff( "aspect_of_the_iron_hawk" )
        removeBuff( "aspect_of_the_cheetah" )
        removeBuff( "aspect_of_the_pack" )

        if name then applyBuff( name ) end
    end )

    -- Lock and Load state tracking
    spec:RegisterStateExpr( "lock_and_load_shots", function()
        if buff.lock_and_load.up then
            return 3
        end
        return 0
    end )

    -- Abilities
    spec:RegisterAbilities( {
        arcane_shot = {
            id = 3044,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 30,
            spendType = "focus",
            
            startsCombat = true,
            
            handler = function ()
                -- No special handling needed for MoP
            end,
        },
        
        aspect_of_the_hawk = {
            id = 13165,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = false,
            texture = 136076,
            
            handler = function ()
                apply_aspect( "aspect_of_the_hawk" )
            end,
        },
        
        black_arrow = {
            id = 3674,
            cast = 0,
            cooldown = 30,
            gcd = "spell",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "black_arrow" )
            end,
        },

        cobra_shot = {
            id = 77767,
            cast = function() return 2 / haste end,
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
                
                -- Apply Cobra Shot debuff
                applyDebuff( "target", "cobra_shot" )
            end,
        },

        dire_beast = {
            id = 120679,
            cast = 0,
            cooldown = 45,
            gcd = "spell",

            startsCombat = true,

            handler = function ()
                applyBuff( "dire_beast" )
            end,
        },

        disengage = {
            id = 781,
            cast = 0,
            cooldown = 20,
            gcd = "off",

            startsCombat = false,

            handler = function ()
                applyBuff( "disengage" )
            end,
        },



        kill_command = {
            id = 34026,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            spend = 40,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                applyBuff( "kill_command" )
            end,
        },

        multi_shot = {
            id = 2643,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            spend = 40,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                applyBuff( "multi_shot" )
            end,
        },

        rapid_fire = {
            id = 3045,
            cast = 0,
            cooldown = 300,
            gcd = "off",

            startsCombat = false,
            toggle = "cooldowns",

            handler = function ()
                applyBuff( "rapid_fire" )
            end,
        },

        steady_shot = {
            id = 56641,
            cast = function() return 2 / haste end,
            cooldown = 0,
            gcd = "spell",
            school = "physical",

            spend = function () return buff.thrill_of_the_hunt.up and 0 or -14 end,
            spendType = "focus",

            startsCombat = true,
            texture = 132213,

            handler = function ()
                if buff.thrill_of_the_hunt.up then
                    removeBuff( "thrill_of_the_hunt" )
                end
            end,
        },

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

        wyvern_sting = {
            id = 19386,
            cast = 0,
            cooldown = 60,
            gcd = "spell",

            startsCombat = true,
            texture = 136189,

            handler = function ()
                applyDebuff( "target", "wyvern_sting" )
            end,
        },

        explosive_shot = {
            id = 53301,
            cast = 0,
            cooldown = 6,
            gcd = "spell",
            
            spend = function() return buff.lock_and_load.up and 0 or 25 end,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "explosive_shot" )
                
                -- If this was a Lock and Load shot, reduce the count
                if buff.lock_and_load.up then
                    -- This will be handled by the state expression
                end
            end,
        },

        stampede = {
            id = 121818,
            cast = 0,
            cooldown = 300,
            gcd = "off",

            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyBuff( "stampede" )
            end,
        },

        exhilaration = {
            id = 109304,
            cast = 0,
            cooldown = 120,
            gcd = "off",

            startsCombat = false,

            handler = function ()
                -- Self-heal ability
            end,
        },

        tranquilizing_shot = {
            id = 19801,
            cast = 0,
            cooldown = 8,
            gcd = "spell",

            startsCombat = true,

            handler = function ()
                -- Dispel magic effect
            end,
        },

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
                -- interrupt() handled by the system
            end,
        },

        hunters_mark = {
            id = 1130,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,
            
            handler = function ()
                applyDebuff( "target", "hunters_mark", 300 )
            end,
        },

        aimed_shot = {
            id = 19434,
            cast = 2.4,
            cooldown = 10,
            gcd = "spell",
            
            spend = 50,
            spendType = "focus",
            
            startsCombat = true,

            handler = function ()
                -- Basic Aimed Shot handling
            end,
        },

        chimera_shot = {
            id = 53209,
            cast = 0,
            cooldown = 9,
            gcd = "spell",

            spend = 35,
            spendType = "focus",

            startsCombat = true,
            texture = 132215,

            handler = function ()
                -- Refresh Serpent Sting if present
                if debuff.serpent_sting.up then
                    debuff.serpent_sting.expires = debuff.serpent_sting.expires + 9
                    if debuff.serpent_sting.expires > query_time + 18 then
                        debuff.serpent_sting.expires = query_time + 18
                    end
                end
            end,
        },

        auto_shot = {
            id = 75,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            
            startsCombat = true,
            texture = 132215,
            
            handler = function ()
                -- Auto Shot is automatic
            end,
        },

        kill_shot = {
            id = 53351,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 35,
            spendType = "focus",
            
            startsCombat = true,
            texture = 236174,

            handler = function ()
                -- Kill Shot for targets below 20% health
            end,
        },

        concussive_shot = {
            id = 5116,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            spend = 15,
            spendType = "focus",

            startsCombat = true,
            texture = 132296,
            
            handler = function ()
                applyDebuff( "target", "concussive_shot", 6 )
            end,
        },

        deterrence = {
            id = 19263,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            
            startsCombat = false,
            texture = 132369,

            handler = function ()
                applyBuff( "deterrence" )
            end,
        },

        feign_death = {
            id = 5384,
            cast = 0,
            cooldown = 0,
            gcd = "off",

            startsCombat = false,
            texture = 132293,

            handler = function ()
                -- Feign Death drops combat
            end,
        },

        mend_pet = {
            id = 136,
            cast = 3,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = false,

            handler = function ()
                applyBuff( "mend_pet" )
            end,
        },
        revive_pet = {
            id = 982,
            cast = 6,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = false,

            handler = function ()
                -- Revive Pet ability
            end,
        },

        call_pet = {
            id = 883,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,

            usable = function() return not pet.alive, "no pet currently active" end,

            handler = function ()
                -- spec:summonPet( "hunter_pet" ) handled by the system
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
                -- summonPet( "hunter_pet", 3600 ) handled by the system
            end,
        },

        call_pet_2 = {
            id = 83242,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = false,
            usable = function () return not pet.exists, "requires no active pet" end,
            handler = function ()
                -- summonPet( "ferocity" ) handled by the system
            end,
        },

        call_pet_3 = {
            id = 83243,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = false,
            usable = function () return not pet.exists, "requires no active pet" end,
            handler = function ()
                -- summonPet( "cunning" ) handled by the system
            end,
        },

        dismiss_pet = {
            id = 2641,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,
            
            usable = function() return pet.alive, "requires active pet" end,
            
            handler = function ()
                -- dismissPet() handled by the system
            end,
        },

        misdirection = {
            id = 34477,
            cast = 0,
            cooldown = 30,
            gcd = "off",

            startsCombat = false,

            handler = function ()
                applyBuff( "misdirection", 8 )
            end,
        },

        aspect_of_the_cheetah = {
            id = 5118,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            
            startsCombat = false,
            
            handler = function ()
                apply_aspect( "aspect_of_the_cheetah" )
            end,
        },

        aspect_of_the_iron_hawk = {
            id = 109260,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = false,

            handler = function ()
                apply_aspect( "aspect_of_the_iron_hawk" )
            end,
        },

        a_murder_of_crows = {
            id = 131894,
            cast = 0,
            cooldown = 60,
            gcd = "spell",

            spend = 30,
            spendType = "focus",

            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "target", "a_murder_of_crows" )
            end,
        },

        lynx_rush = {
            id = 120697,
            cast = 0,
            cooldown = 90,
            gcd = "spell",

            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "target", "lynx_rush" )
            end,
        },

        glaive_toss = {
            id = 117050,
            cast = 0,
            cooldown = 15,
            gcd = "spell",

            spend = 15,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                -- Glaive Toss deals damage to target and enemies in line
            end,
        },

        powershot = {
            id = 109259,
            cast = 3,
            cooldown = 45,
            gcd = "spell",
            
            spend = 15,
            spendType = "focus",
            
            startsCombat = true,

            handler = function ()
                -- Power Shot deals damage and knocks back enemies
            end,
        },

        barrage = {
            id = 120360,
            cast = 3,
            channeled = true,
            cooldown = 20,
            gcd = "spell",

            spend = 40,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                applyBuff( "barrage" )
            end,
        },

        blink_strike = {
            id = 130392,
            cast = 0,
            cooldown = 20,
            gcd = "spell",

            startsCombat = true,

            handler = function ()
                -- Pet ability, no special handling needed
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

        -- Additional talent abilities
        piercing_shots = {
            id = 82924,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            
            startsCombat = false,

            handler = function ()
                -- Passive talent, no active handling needed
            end,
        },

        careful_aim = {
            id = 82926,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            
            startsCombat = false,

            handler = function ()
                -- Passive talent, no active handling needed
            end,
        },

        -- Pet abilities that can be talented
        blink_strikes = {
            id = 109304,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            
            startsCombat = false,

            handler = function ()
                -- Passive talent, no active handling needed
            end,
        },

        -- Tier 2 Talents (Active abilities only)
        binding_shot = {
            id = 109248,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = true,

            handler = function ()
                -- Passive talent, no active handling needed
            end,
        },

        wyvern_sting = {
            id = 19386,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "wyvern_sting" )
            end,
        },

        intimidation = {
            id = 19577,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = true,

            handler = function ()
                -- Pet ability, no special handling needed
            end,
        },

        wyvern_sting = {
            id = 19386,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "wyvern_sting" )
            end,
        },

        -- Tier 3 Talents (Active abilities only)
        exhilaration = {
            id = 109260,
            cast = 0,
            cooldown = 120,
            gcd = "off",
            
            startsCombat = false,
            toggle = "defensives",

            handler = function ()
                -- Self-heal ability
            end,
        },

        -- Tier 4 Talents (Active abilities only)
        fervor = {
            id = 82726,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            
            startsCombat = false,
            toggle = "cooldowns",

            handler = function ()
                applyBuff( "fervor" )
            end,
        },

        dire_beast = {
            id = 120679,
            cast = 0,
            cooldown = 45,
            gcd = "spell",
            
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyBuff( "dire_beast" )
            end,
        },
    } )

    -- Pet Registration
    spec:RegisterPet( "tenacity", 1, "call_pet_1" )
    spec:RegisterPet( "ferocity", 2, "call_pet_2" )
    spec:RegisterPet( "cunning", 3, "call_pet_3" )

    -- Gear Registration
    spec:RegisterGear( "tier16", 99169, 99170, 99171, 99172, 99173 )
    spec:RegisterGear( "tier15", 95307, 95308, 95309, 95310, 95311 )
    spec:RegisterGear( "tier14", 84242, 84243, 84244, 84245, 84246 )

    -- State Expressions
    spec:RegisterStateExpr( "focus_time_to_max", function()
        local regen_rate = 6 * haste
        if buff.aspect_of_the_iron_hawk.up then regen_rate = regen_rate * 1.3 end
        if buff.rapid_fire.up then regen_rate = regen_rate * 1.5 end
        
        return math.max( 0, ( (state.focus.max or 100) - (state.focus.current or 0) ) / regen_rate )
    end )
    spec:RegisterStateExpr("ttd", function()
        if state.is_training_dummy then
            return Hekili.Version:match( "^Dev" ) and settings.dummy_ttd or 300
        end
    
        return state.target.time_to_die
    end)

    spec:RegisterStateExpr( "focus_deficit", function()
        return (state.focus.max or 100) - (state.focus.current or 0)
    end )

    spec:RegisterStateExpr( "pet_alive", function()
        return pet.alive
    end )

    spec:RegisterStateExpr( "bloodlust", function()
        return buff.bloodlust
    end )

    -- Options
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
        package = "Survival",
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

    spec:RegisterSetting( "mark_any", false, {
        name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        type = "toggle",
        width = "full"
    } )

    spec:RegisterPack( "Survival", 20250723, [[Hekili:fNvBVTnos4FlfhUGeSD16yhNKfOoaUT(219sTdI8EhUVijAj6yIil6JIkzZHa9B)gsQxOOPKDtDVdlsrI4WzEMHZ7R35El8CJqCS3S(96pS3v9h4C(19717cpx(lBXEUBrHpIEa(Le0g4FDZyprEcflo4LykksWGuAgleo0ZDzgjMpnXBPnUceUfhcFB4qp31KOiSIqCAON7I1K08aXpO8GcHMhqxb)DiNqtYdIjPC44vuwEWVJFKetCauWORiXGS)lWhZs4y4WsmMh8Z5bFLEx(xY)cC8D3p5tZ)6hhVq(R3n((XlMoFw(xu8p1zldhs3SeX)Pr)csGuUpDLpFn2pCngZrRFpz1O3TmB1khRh7KT9K3THkar0jBOprsE4qy(A0Zp2gNfNjzRLZimAsjbhICQO)hJWcrXX(BXC)ZL8x8BOyYty7uVw(uL6VbXK450umNdgSuhXx8rjV86RCe7bm3HK6VKMME2jc(8e2pIYD0V(OENuqjNSb7ZP(re8nNpS4v)RJNolp4(5luV2Wt)053pDX)kp42PUlki6CN8G)ojg8yCxt5GBi4UH)tCygh8bzOeHR4P979xZdwJrX81NjDTwm)on(vQNG2b(MX(PaNeQwb4ux0zBi)dJ63RqU9b5(jknoI(Cc4AF6a4FeAb7mD2jnTQ)0xee8ErO4OWY7jfcCPBgnOGTda2(z8kCsQ4biaLeLh8hCiGH)Y(5Bu1fvm7cGzJLodGXeLaHLBWj89ZhLduAbxgk4Y8jWlbLJuXZNo4NaTvADspa9frXcnf4kCAX1C2KfZjstDT2FjiQpMXsb8E3AuQ4P751yqGt(ZTXuLjP4zgm3mmk6LcBuy9tb6jejgTmgFaiBPqycSjdCIPHch4iFr2rz4Ievx5ybaNElqCHWVfihY8XiuM4Ds4GfIekbs4xoas8XWWff6AtZfUKRvUCwXXjn(GK20BkDeV2k6qqkAatpt4RPzCbenqBinjIiWXEa0kAyw6nJUOuC)Q4jkgj42ygJ(miRnisch(PbNwkOXhjirMvjclvnTpluScUpyOTebJUUmgVhiuxmBRW7nWvKTrOIB3gdgBcuNjrOZQKmnarQ6o(PIROdJghiasx5HoxKJzmleLuBFvULs4NhCZiikzydjJKKBAfhAvpVSuoQCklzOkXafiJf1f)zHowjp7VDHIBkLyb)(4FCVROI5Vp2DYXksYrgX8976AYUuoAZwCKmprjcCk)OJcF7CjgAljYFfH18A1FUTlEiz5nVZrYH2KTFJokMxFNh9XU3n5tlefpNn(3M81jZwuFPI86)G7JPnPCe7IrQPFEYFBYm3P)dW3E8SpdLjxm9w9Q5ovLdLURRbxzMS(Lq(AV2d7z)kkss50eSXnUOLBSHKgbEDHLcHVg8)4oPeEMuW3mQV9lYHgv(3q)3K)dKoY0XmIilCkIdl08pnF(TFE()CM9x5Qa4dpcPWKR9z5ZqmLgfNLYB88QZE9O2t3LfV(ArisnFo7KwJULQ2cgj5rSO3dBYllf8e44nVpnMYhXv0E(3aT9leZ9OqIykd0srRveClYRi4KtzmOArv85hgm0o9lHoBXShBm(qJZfwc)vzSs1D8dQw7c2sfuNheLXKv3wJzus6MFPY2zNHQRP6L5jcdAVdA5g06Q8XnFdvYu2lxvx1YE5wm((FBYcxT88qpBhVS8kMv3XNwMUR6DsN9f2KfF3f03N6P1UZba(H7qwD(yp3NaVb4O6jP9CFgXseZk55oDZwkJl6r7kJ5KDY)INlkdACJbdTVjBfJ8ONR8iXe7fPxHFDMCfa4erMHiVpchjztjj6PvvJQZiBveSBrcpx4uyWmcYZ9D5bTNDop4K8a7uONJ2JdQTb8oYsOf1TIgacCHEVcbpDDzUQ6gWWkTN5ppgJEQBu2PpK8Gpanw2VNnBzdG2(SO1kP58pnKmqRQl2bkhnF1gJQY0iqWGUqqhJT2fe0Kvv5qHSUOlzzFQ2dumLrpGqg2Lq23qVhMHTTmB2m2q(dbQUSluDKNp(WucRz8BaDzZOcWFvlrynZZAOuh3XR3lYLPxSuVcEtYdKXAx)w0IV7XW1bU2CLxiH0V2cK0M(WapDnNUrQyRtYintA4aA5r8LDlRQo(AbkpVxlWSr1zdG(nnCVDKBw8VDKcjThkrARLoRhhZeNh4waA5DCyh2V8GlLGQZK8VHTdOfFx3wISQy1cDp82ikwvUbQADX9TSZ(93fq9k5lBeOyX8Y)uTC())1DrrJf7un8)nsxV3MDks2acvlX3ihVCn)2Q(vF7tHuPMR0pp41xRCElwRFEWzs1rfAUZY9ZdaV(E7juScC63u5Iw38rhUO1JBA4xABezDLS9LfP)c1yA2Qt0gPQBhXtTZgHPC3HZkSMTmESwU0IVBZlSKMYjJnmkLdxdmjwKFRImlEtgSQVXD6BZhYijAXyZgGyNrVTKW8dI6nvDdvvSRA6ADPw22rDjXYzSnOYSSEZjIo4bXl)FNQ(42700rdFKkOP4TY9w1ZuhU2D2TXrC1UhHgMApc47YB(aIwTMjOZCJTpLLL5b7mp5rRZjRDZzzuG3uFfw7SXmMrFRf6XmC95Y60xTE7QgEQTSLwDTPXBbOr7XNYG8l0E50wzB3ouMBMvzl7xZj9v5EqouABPvp5P5EDvgvXSEV1q)UwF3p0yznNURu11374TvwZQJ2BVtVTw6BzsJoF4AoKvBg)otbOhh2Rn19Ydlst9FE)3]] )
