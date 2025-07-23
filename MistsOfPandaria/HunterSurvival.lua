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
        max_stack = 1
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
        dire_beast = {
            id = 120679,
        duration = 8,
        max_stack = 1
    },
        disengage = {
            id = 781,
            duration = 20,
            max_stack = 1
        },
       -- Restores Focus.
       fervor = {
        id = 82726,
        duration = 10,
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
        wyvern_sting = {
            id = 19386,
            duration = 30,
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
                spec:apply_aspect( "aspect_of_the_hawk" )
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
            texture = 236186,

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
            texture = 132294,

            handler = function ()
                applyBuff( "disengage" )
            end,
        },

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

        kill_command = {
            id = 34026,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            spend = 40,
            spendType = "focus",

            startsCombat = true,
            texture = 132176,

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
            texture = 132330,

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
            texture = 132208,

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
            
            spend = 25,
            spendType = "focus",

            startsCombat = true,
            texture = 236178,

            handler = function ()
                applyDebuff( "target", "explosive_shot" )
            end,
        },

        stampede = {
            id = 121818,
            cast = 0,
            cooldown = 300,
            gcd = "off",

            startsCombat = true,

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
            texture = 236174,

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
            texture = 136020,

            handler = function ()
                -- Dispel magic effect
            end,
        },

        hunters_mark = {
            id = 1130,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,
            texture = 132212,
            
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
            texture = 135130,

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
            texture = 236176,

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
            texture = 132179,

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
            texture = 132179,

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
            texture = 132179,

            usable = function() return not pet.alive, "no pet currently active" end,

            handler = function ()
                spec:summonPet( "hunter_pet" )
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

        call_pet_2 = {
            id = 83242,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = false,
            usable = function () return not pet.exists, "requires no active pet" end,
            handler = function ()
                summonPet( "ferocity" )
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
                summonPet( "cunning" )
            end,
        },

        dismiss_pet = {
            id = 2641,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,
            texture = 132179,
            
            usable = function() return pet.alive, "requires active pet" end,
            
            handler = function ()
                dismissPet()
            end,
        },

        misdirection = {
            id = 34477,
            cast = 0,
            cooldown = 30,
            gcd = "off",

            startsCombat = false,
            texture = 132312,

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
            texture = 132242,
            
            handler = function ()
                spec:apply_aspect( "aspect_of_the_cheetah" )
            end,
        },

        aspect_of_the_iron_hawk = {
            id = 109260,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = false,
            texture = 132242,

            handler = function ()
                spec:apply_aspect( "aspect_of_the_iron_hawk" )
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
            texture = 645217,

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
            texture = 236186,

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
            texture = 236176,

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
            texture = 236176,

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
            texture = 236176,

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
            texture = 236186,

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
        if is_training_dummy then
            return Hekili.Version:match( "^Dev" ) and settings.dummy_ttd or 300
        end
    
        return target.time_to_die
    end)

    spec:RegisterStateExpr( "focus_deficit", function()
        return (focus.max or 100) - (focus.current or 0)
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

    spec:RegisterPack( "Survival", 20250723, [[Hekili:fNvFVTTnA8plfhUahSonBN4KuG6c426BZ5sCcI82W9psIwIUMiYI(OOsAoeOp73dj1lu0uYoTPByOfUIpV87HpVZ5nWBHNBeIJ9MpS)Wr9pF4jodoBWPJENNl)PTyp3TOW7rFb(rcAd83UzShipGIfh8umffjeqknJfch65UmJeZNL4T0QuhocODloe(8i4NRjrryfT40qp3fRjP5bI)GYdk0BEaDf8Vd5eAsEqmjLdhVIYYd(n89KyIdaegDfjgu))a(ywchdhwcZ8GFop4A6T5b5xMFjqWT3n9t3C9hNSq(ZBNC3KfZUzE(LknK6SLHdPBwI4)04FbjWk3NUYNVg7hUgJ5O1VLSA8BwMTALJ1JDY2E0B2qfWi6On0hijF5qe(A0J33MKfNjfRLZimAsjbhIEQO)hJYcrXX(BXC)bs5l(fkM8a2o1RLoRu)niMep9sXCoCHL6i(Ipk5PNFMJyFbZDiP(lPPPhFKqopG9JOChD2h3)Ock5KnyFo1pIG)WGrfE9RNmBEEWD3Sq5Tbx)SBUB2I)tEWvZCxuq0aN8GprPXr0htGGSENa)LqASJRGFPjQ(N(IWX3kYlghwYNWoem9HXNui2HGy)mEfojvCreGsIYd(Doe6YFA)YnQIrLWobe2ePtbmkucKGSbNW3VCuoY0cPCQqk3mfUrOCKkZQ3j)eyTYRW0dWEruSWsbPcNwWMZMSyoXpDnLxB9Jav9XmwkG3BxJsHlGEpUgdkC6x3gtvxjUahQ8Eggf9uXDuyTRa9aIeJwgJpaKTuOmb2KbWX0qrGuKVOuLmSvIQZCSaGExbexO8RaYHAqmcLb(PgQfxYN0s3NMoh00)MehxzLGPJ)komJd6LHsev46nS))mpyngfZx3qvqbU4kTueFRiZzBi)9Jh2VqlxiULJrc4pHXOpcYCdIKWH)0qGlf04JeKitqJWsSR9zrU)kAywk4chzlNA8ff68DGoDXSTI4VaxrElOv02TXGdKa1SteMRkDTbgsv84NkyrhfnoqGJUYOh0xedZcrj1(pvGLe95bFyme8nQHMrsYRUqlmZrwnZZk1JQQWsgQsnqZMyZIcccmf8WsS(XF)oxr)MFBI70xR4FhzC(ljC0KXuoAZwCKmpUuxoLF0rHKDyIH2sI8xrynzR(ZTX4HekBYZRu0QPyFHHbMS3TVEI7Tt)0crhN5t(1PxpD(IAjuue(hCZ)20YRyRFPL(5P)RPZDN9hqi9K5Fg6PTy2vIwQvaPQ3LmkDnebZKnBe6xZ1pQVDwuKKYPjydooTfo2qsJGqWWsLWxdbJCNucptQyWnzNroui()ctUs(FqLhZO0iISlNi9RWY)0n3C1NV5pNB3lxL3E4Plfx5AFw6gIP0O4SuEd3RU41tH7TRiE(5I8LA5C8rTMQlnTfmsY9yXGc20xwkejWXBEBAmLpMRODWlG2HfQ5ouirmCoAPyoicUf9vKPYPmg0yOkD79NmYo9lHXbXS7BmZDJZf3e(RYyLM7KVOMdlylvqDEqugt2iBnMrjPB(LQ7o7cuXMAWJhimywmyovWQRkd30hQ0PCWRQrrLdETyYD)60fUAL3HbS(wkURyREqmTsuN3)OohxRPi(U7sVpdPav65YDa(r7qwlLH9CFacca6Qx90Z9relrSxHN7SnBPmy1myWmJTkDYV0ZfLXxtzWwUBYwXi375kpsSIBrvv4NZL7mJtefeI8(iCKumLKOxnvTylJSvrWU9g8CHtHLyiip33Kh0Er58GJYdStHEPzpoy2gW7vwdTyUv0aqGlS7viWpA76QXvYEwmRJDYQbI5Ea6MSGw1SGNOCM(QNXOkj22nwde2X6BDbbnDv1PrORt6sx23U7avtzekOKt7sj7B5Vd7ITTsj2USHewbQg1fQEL3t8WmcRftBaD5qFcWFwlj9nlSzyuV01m3p2aKCEliPAcBdq8I3aTr(J5K65bVh8Vd7lqYfTGeTb0nWsx7PAuPY6W(YIuAl4bdci(YUTGuhFHaLVRfu2OrMboFj72Ah3MTjBhNqrUrcCoOFB9vQ3xXaMh6sW6qSXjDHQZKGQZQ3TVCSw(xvFAvNHQha8WBLw80QgkVJN6TLx5D)9cRFe3Y2HfpLR8FQEo3)(6Xw0EDNEi)1OD9o870HPbeQE2xJQWYhg2wNGAU7LhSZJaNh88ZvrPfpeCEWXsZrLdUZZbNhaH393toxf405ufKwpEqhbP17AzezAB)qDJS9Nnr3d1yvUQt02NO7aXE2fJ4QC3ntkUnBz3qTAMfF3wuyjnLRfACPuUzjiKyrHSkYSenziQHg8m0wmKr1YIDgnaXo7DAPY47fTvQA5x1tRA1sDTw2oUUZx5cMguz2QS5Ebh8wOL)FHtFxZDgAOrmsf0uYwfERMQPJq7oNQ5v85mpObEApg)7kE9aYhTMR3z1V2NxYYCADwj8vBeiRJLzzI2VPreSoKILHuTk8HJAFmH6LM6mmT(vfncsB51j1rsdNeyQ97oyZG8t1CPApvz3rAMVizX9qTK0FcZdkst71j1RBA(EMQlvXIyFRz9D9SvFNPXAHeNRAAV3TlRUVQoAVdg9TnyElRl0PRrZE0JsmUE7m7xpfSFBM7bLb3rsM6)8())]] )
