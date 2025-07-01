-- HunterSurvival.lua
-- Updated June 10, 2025 - MoP Classic Compatible Structure
-- Mists of Pandaria module for Hunter: Survival spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'HUNTER' then return end

local addon, ns = ...
local Hekili = _G[ addon ]

if not Hekili then return end

local class, state
local spec

-- Wait for proper class initialization
local function getReferences()
    if not class and Hekili and Hekili.Class then
        class = Hekili.Class
        state = Hekili.State
    end
    if not spec and class and class.specs and Hekili.NewSpecialization then
        spec = Hekili:NewSpecialization( 255 ) -- Survival spec ID for MoP
    end
    return class, state, spec
end

-- Only proceed if we're in MoP Classic
if not Hekili or not Hekili.CurrentBuild or Hekili.CurrentBuild < 50400 then return end

-- Initialize spec when ready
local function initializeSpec()
    local class, state, spec = getReferences()
    if not spec then return false end

    -- MoP API compatibility imports
    local IsUsableItem = ns.IsUsableItem or IsUsableItem
    local GetItemIcon = ns.GetItemIcon or GetItemIcon
    local FindUnitBuffByID = ns.FindUnitBuffByID
    local FindUnitDebuffByID = ns.FindUnitDebuffByID

    -- Resources
    spec:RegisterResource( 2, { -- Focus = 2 in MoP
        -- Steady Shot focus regeneration
        steady_shot = {
            resource = "focus",
            aura = "steady_shot",
            last = function ()
                local app = state.buff.steady_shot.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1.5 ) * 1.5
            end,
            interval = 1.5,
            value = function()
                return state.buff.steady_shot.up and 14 or 0
            end,
        },

        -- Rapid Recuperation focus regeneration
        rapid_recuperation = {
            aura = "rapid_recuperation",
            last = function ()
                local app = state.buff.rapid_recuperation.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 3 ) * 3
            end,
            interval = 3,
            value = function()
                return state.health.pct < 50 and 8 or 0
            end,
        },
        
        -- Thrill of the Hunt focus cost reduction
        thrill_of_the_hunt = {
            aura = "thrill_of_the_hunt",
            last = function ()
                local app = state.buff.thrill_of_the_hunt.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1 ) * 1
            end,
            interval = 1,
            value = function()
                return state.buff.thrill_of_the_hunt.up and 20 or 0
            end,
        },
    }, {
        -- Base focus regeneration
        base_regen = function ()
            local base = 6 -- Base focus regen per second
            local haste_bonus = base * state.haste -- Haste scaling
            local aspect_bonus = 0
            
            -- Aspect bonuses
            if state.buff.aspect_of_the_fox.up then
                aspect_bonus = aspect_bonus + base * 0.30
            end
            
            return haste_bonus + aspect_bonus
        end,
        
        -- Fervor talent focus restoration
        fervor = function ()
            return state.talent.fervor.enabled and state.cooldown.fervor.ready and 50 or 0
        end,
    } )

    -- Talents (MoP Talent Trees)
    spec:RegisterTalents( {
        -- Tier 1 (Level 15) - Movement
        posthaste              = { 1, 1, 109248 },
        narrow_escape          = { 1, 2, 109259 },
        crouching_tiger        = { 1, 3, 120679 },
        
        -- Tier 2 (Level 30) - Crowd Control
        silencing_shot         = { 2, 1, 34490  },
        wyvern_sting           = { 2, 2, 19386  },
        binding_shot           = { 2, 3, 109248 },
        
        -- Tier 3 (Level 45) - Survivability
        exhilaration           = { 3, 1, 109304 },
        aspect_of_the_iron_hawk = { 3, 2, 109260 },
        spirit_bond            = { 3, 3, 117902 },
        
        -- Tier 4 (Level 60) - Pet Abilities
        murder_of_crows        = { 4, 1, 131894 },
        blink_strikes          = { 4, 2, 130392 },
        lynx_rush              = { 4, 3, 120697 },
        
        -- Tier 5 (Level 75) - Focus Management
        fervor                 = { 5, 1, 82726  },
        dire_beast             = { 5, 2, 120679 },
        thrill_of_the_hunt     = { 5, 3, 34497  },
        
        -- Tier 6 (Level 90) - Area Damage
        glaive_toss            = { 6, 1, 109215 },
        powershot              = { 6, 2, 117049 },
        barrage                = { 6, 3, 121818 }
    } )

    -- Auras
    spec:RegisterAuras( {
        -- Aspects
        aspect_of_the_hawk = {
            id = 13165,
            duration = 3600,
            max_stack = 1,
        },
        
        aspect_of_the_fox = {
            id = 13159,
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

        -- Hunter's Mark
        hunters_mark = {
            id = 1130,
            duration = 300,
            max_stack = 1,
        },

        -- Serpent Sting
        serpent_sting = {
            id = 1978,
            duration = 15,
            tick_time = 3,
            max_stack = 1,
        },

        -- Steady Shot buff
        steady_shot = {
            id = 53817,
            duration = 8,
            max_stack = 1,
        },

        -- Lock and Load
        lock_and_load = {
            id = 53813,
            duration = 12,
            max_stack = 2,
        },

        -- Master's Call
        masters_call = {
            id = 62305,
            duration = 4,
            max_stack = 1,
        },

        -- Rapid Fire
        rapid_fire = {
            id = 3045,
            duration = 15,
            max_stack = 1,
        },

        -- Rapid Recuperation
        rapid_recuperation = {
            id = 53817,
            duration = 3600,
            max_stack = 1,
        },

        -- Thrill of the Hunt
        thrill_of_the_hunt = {
            id = 34497,
            duration = 8,
            max_stack = 3,
        },

        -- Black Arrow
        black_arrow = {
            id = 3674,
            duration = 20,
            tick_time = 2,
            max_stack = 1,
        },

        -- Explosive Shot
        explosive_shot = {
            id = 53301,
            duration = 2,
            tick_time = 1,
            max_stack = 1,
        },

        -- Wyvern Sting
        wyvern_sting = {
            id = 19386,
            duration = 30,
            max_stack = 1,
        },

        -- Improved Tracking
        improved_tracking = {
            id = 19506,
            duration = 3600,
            max_stack = 1,
        },

        -- Expose Weakness
        expose_weakness = {
            id = 34500,
            duration = 7,
            max_stack = 1,
        },

        -- Tier Set Bonuses
        tier14_2pc_sv = {
            id = 105919,
            duration = 3600,
            max_stack = 1,
        },

        tier14_4pc_sv = {
            id = 105925,
            duration = 6,
            max_stack = 1,
        },
    } )

    -- Abilities
    spec:RegisterAbilities( {
        -- Core Abilities
        steady_shot = {
            id = 56641,
            cast = 2.0,
            cooldown = 0,
            gcd = "spell",
            
            spend = function() return state.buff.thrill_of_the_hunt.up and -20 or 0 end,
            spendType = "focus",
            
            startsCombat = true,
            texture = 132213,
            
            handler = function ()
                applyBuff( "steady_shot" )
                if state.talent.thrill_of_the_hunt.enabled and math.random() <= 0.30 then
                    applyBuff( "thrill_of_the_hunt" )
                end
                
                -- Lock and Load proc chance
                if state.talent.lock_and_load.enabled and math.random() <= 0.05 then
                    applyBuff( "lock_and_load", 12, 2 )
                end
            end,
        },

        auto_shot = {
            id = 75,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            
            startsCombat = true,
            texture = 135489,
            
            handler = function ()
                -- Auto shot logic
            end,
        },

        arcane_shot = {
            id = 3044,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = function() 
                local cost = 25
                if state.buff.thrill_of_the_hunt.up then
                    cost = cost - 20
                end
                return cost
            end,
            spendType = "focus",
            
            startsCombat = true,
            texture = 132218,
            
            handler = function ()
                if state.talent.thrill_of_the_hunt.enabled and math.random() <= 0.30 then
                    applyBuff( "thrill_of_the_hunt" )
                end
            end,
        },

        multi_shot = {
            id = 2643,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = function() 
                local cost = 35
                if state.buff.thrill_of_the_hunt.up then
                    cost = cost - 20
                end
                return cost
            end,
            spendType = "focus",
            
            startsCombat = true,
            texture = 132330,
            
            handler = function ()
                if state.talent.thrill_of_the_hunt.enabled and math.random() <= 0.30 then
                    applyBuff( "thrill_of_the_hunt" )
                end
            end,
        },

        -- Signature Survival Abilities
        explosive_shot = {
            id = 53301,
            cast = 0,
            charges = function() return state.buff.lock_and_load.up and 3 or 1 end,
            cooldown = 6,
            recharge = 6,
            gcd = "spell",
            
            spend = function() 
                return state.buff.lock_and_load.up and 0 or 40
            end,
            spendType = "focus",
            
            startsCombat = true,
            texture = 236178,
            
            handler = function ()
                applyDebuff( "target", "explosive_shot", 2 )
                if state.buff.lock_and_load.up then
                    removeBuff( "lock_and_load" )
                end
            end,
        },

        black_arrow = {
            id = 3674,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            
            spend = 35,
            spendType = "focus",
            
            startsCombat = true,
            texture = 136181,
            
            handler = function ()
                applyDebuff( "target", "black_arrow", 20 )
                
                -- Lock and Load proc chance
                if state.talent.lock_and_load.enabled and math.random() <= 0.15 then
                    applyBuff( "lock_and_load", 12, 2 )
                end
            end,
        },

        serpent_sting = {
            id = 1978,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 15,
            spendType = "focus",
            
            startsCombat = true,
            texture = 132204,
            
            handler = function ()
                applyDebuff( "target", "serpent_sting", 15 )
            end,
        },

        -- Utility Abilities
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

        disengage = {
            id = 781,
            cast = 0,
            cooldown = function() 
                return state.talent.crouching_tiger.enabled and 19 or 25
            end,
            gcd = "off",
            
            startsCombat = false,
            texture = 132294,
            
            handler = function ()
                -- Movement ability
            end,
        },

        -- Traps
        explosive_trap = {
            id = 13813,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            
            startsCombat = true,
            texture = 135826,
            
            handler = function ()
                -- Trap logic
            end,
        },

        freezing_trap = {
            id = 1499,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            
            startsCombat = false,
            texture = 135834,
            
            handler = function ()
                -- CC trap logic
            end,
        },

        -- Cooldowns
        rapid_fire = {
            id = 3045,
            cast = 0,
            cooldown = 300,
            gcd = "off",
            
            toggle = "cooldowns",
            
            startsCombat = false,
            texture = 132208,
            
            handler = function ()
                applyBuff( "rapid_fire", 15 )
            end,
        },

        bestial_wrath = {
            id = 19574,
            cast = 0,
            cooldown = 120,
            gcd = "off",
            
            toggle = "cooldowns",
            
            startsCombat = false,
            texture = 132127,
            
            handler = function ()
                -- Pet ability
            end,
        },

        -- Aspects
        aspect_of_the_hawk = {
            id = 13165,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = false,
            texture = 136076,
            essential = true,
            
            nobuff = "aspect_of_the_hawk",
            
            handler = function ()
                removeBuff( "aspect_of_the_fox" )
                removeBuff( "aspect_of_the_cheetah" )
                removeBuff( "aspect_of_the_pack" )
                applyBuff( "aspect_of_the_hawk" )
            end,
        },

        aspect_of_the_fox = {
            id = 13159,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = false,
            texture = 136076,
            
            nobuff = "aspect_of_the_fox",
            
            handler = function ()
                removeBuff( "aspect_of_the_hawk" )
                removeBuff( "aspect_of_the_cheetah" )
                removeBuff( "aspect_of_the_pack" )
                applyBuff( "aspect_of_the_fox" )
            end,
        },

        -- Talent Abilities
        wyvern_sting = {
            id = 19386,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            
            talent = "wyvern_sting",
            
            spend = 25,
            spendType = "focus",
            
            startsCombat = true,
            texture = 135125,
            
            handler = function ()
                applyDebuff( "target", "wyvern_sting", 30 )
            end,
        },

        silencing_shot = {
            id = 34490,
            cast = 0,
            cooldown = 20,
            gcd = "off",
            
            talent = "silencing_shot",
            
            startsCombat = true,
            texture = 132323,
            
            toggle = "interrupts",
            interrupt = true,
            
            handler = function ()
                interrupt()
            end,
        },

        fervor = {
            id = 82726,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            
            talent = "fervor",
            
            startsCombat = false,
            texture = 236183,
            
            handler = function ()
                gain( 50, "focus" )
            end,
        },
    } )

    -- Pet Abilities
    spec:RegisterAbilities( {
        -- Basic Pet Commands
        pet_attack = {
            id = 2649,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            
            startsCombat = true,
            texture = 132140,
            
            usable = function() return pet.exists end,
            
            handler = function ()
                -- Pet attack logic
            end,
        },

        pet_follow = {
            id = 2641,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            
            startsCombat = false,
            texture = 132142,
            
            usable = function() return pet.exists end,
            
            handler = function ()
                -- Pet follow logic
            end,
        },

        pet_stay = {
            id = 3442,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            
            startsCombat = false,
            texture = 132144,
            
            usable = function() return pet.exists end,
            
            handler = function ()
                -- Pet stay logic
            end,
        },

        -- Pet Special Abilities
        growl = {
            id = 2649,
            cast = 0,
            cooldown = 5,
            gcd = "off",
            
            startsCombat = true,
            texture = 132141,
            
            usable = function() return pet.exists end,
            
            handler = function ()
                -- Pet taunt
            end,
        },

        intimidation = {
            id = 19577,
            cast = 0,
            cooldown = 60,
            gcd = "off",
            
            startsCombat = true,
            texture = 132111,
            
            usable = function() return pet.exists end,
            
            handler = function ()
                -- Pet stun
            end,
        },
    } )

    return true
end

-- Try to initialize immediately, or wait for class to be ready
if not initializeSpec() then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(self, event, ...)
        if initializeSpec() then
            frame:UnregisterAllEvents()
        end
    end)
end
