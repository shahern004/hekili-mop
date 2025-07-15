-- HunterSurvival.lua
-- July 2025
-- by Smufrik

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'HUNTER' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local floor = math.floor
local strformat = string.format
local spec = Hekili:NewSpecialization( 255, false ) -- Survival spec ID for Hekili (255 = ranged in MoP Classic)

-- Ensure state is properly initialized
if not state then 
    state = Hekili.State 
end

-- Use MoP power type numbers instead of Enum
-- Focus = 2 in MoP Classic
spec:RegisterResource( 2 )

-- Talents
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    posthaste = { 1, 1, 109215 }, -- Disengage also frees you from movement impairing effects and increases speed.
    narrow_escape = { 1, 2, 109298 }, -- Disengage also activates a web trap.
    crouching_tiger_hidden_chimera = { 1, 3, 109300 }, -- Reduces the cooldown of Disengage and Deterrence.
    
    -- Tier 2 (Level 30) 
    silencing_shot = { 2, 1, 34490 }, -- Silences the target and interrupts spellcasting.
    binding_shot = { 2, 2, 109248 }, -- Stuns enemies if they move too far from the arrow.
    wyvern_sting = { 2, 3, 19386 }, -- Puts the target to sleep.
    
    -- Tier 3 (Level 45)
    spirit_bond = { 3, 1, 109212 }, -- You and your pet regenerate health while your pet is active.
    aspect_of_the_iron_hawk = { 3, 2, 109260 }, -- Increases ranged attack power and reduces damage taken.
    exhilaration = { 3, 3, 109304 }, -- Heals you and your pet.
    
    -- Tier 4 (Level 60)
    fervor = { 4, 1, 82726 }, -- Instantly restores Focus to you and your pet.
    dire_beast = { 4, 2, 120679 }, -- Summons a powerful wild beast to attack your target.
    thrill_of_the_hunt = { 4, 3, 109306 }, -- Focus spending shots have a chance to make your next Arcane/Multi-Shots free.
    
    -- Tier 5 (Level 75)
    a_murder_of_crows = { 5, 1, 131894 }, -- Summons crows to attack the target; cooldown resets if target dies.
    lynx_rush = { 5, 2, 120697 }, -- Your pet rapidly attacks multiple targets.
    blink_strikes = { 5, 3, 130392 }, -- Increases pet damage and allows pet to teleport to target.
    
    -- Tier 6 (Level 90)
    glaive_toss = { 6, 1, 117050 }, -- Hurls two glaives that damage enemies in their path.
    powershot = { 6, 2, 109259 }, -- Powerful shot that knocks back enemies.
    barrage = { 6, 3, 120360 }, -- Rapidly fires a spray of shots.
} )

-- Auras
spec:RegisterAuras( {
    -- Increases party and raid members' movement speed by 30%. If a group member is dazed, the effect is cancelled.
    aspect_of_the_pack = {
        id = 13159,
        duration = 3600,
        max_stack = 1
    },
    -- Movement speed increased by 30%.
    aspect_of_the_cheetah = {
        id = 5118,
        duration = 3600,
        max_stack = 1
    },
    -- Increases ranged attack power by 15% and reduces damage taken by 10%.
    aspect_of_the_hawk = {
        id = 13165,
        duration = 3600,
        max_stack = 1
    },
    aspect_of_the_iron_hawk = {
        id = 109260,
        duration = 3600,
        max_stack = 1,
        copy = { 13165, 109260 }  -- Link with regular Aspect of the Hawk
    },
    -- Deflecting all attacks. Damage taken reduced by 30%.
    deterrence = {
        id = 19263,
        duration = 5.0,
        max_stack = 1
    },
    -- Talent: Fires a magical projectile, tethering the enemy and any other enemies within 5 yards, stunning them for 5 sec if they move more than 5 yards.
    binding_shot = {
        id = 117526,
        duration = 5,
        max_stack = 1
    },
    -- Movement speed increased by 30% for 4 sec.
    posthaste = {
        id = 118922,
        duration = 4,
        max_stack = 1
    },
    camouflage = {
        id = 51755,
        duration = 60,
        max_stack = 1
    },
    -- Increased movement speed by 8%.
    pathfinding = {
        id = 107076,
        duration = 3600,
        max_stack = 1
    },
    -- Rooted.
    entrapment = {
        id = 135373,
        duration = 4.0,
        max_stack = 1
    },
    -- Suffering Fire damage every 1 sec.
    explosive_trap = {
        id = 13812,
        duration = 10.0,
        tick_time = 1.0,
        max_stack = 1
    },
    -- Feigning death.
    feign_death = {
        id = 5384,
        duration = 360,
        max_stack = 1
    },
    -- Talent: When activated, you and your pet immediately heal for 30% of your maximum health.
    exhilaration = {
        id = 109304,
        duration = 3,
        max_stack = 1
    },
    -- Talent: You and your pet regenerate 2% of total health every 5 sec.
    spirit_bond = {
        id = 109212,
        duration = 3600,
        tick_time = 5.0,
        max_stack = 1
    },
    -- Talent: Threat redirected from Hunter.
    misdirection = {
        id = 35079,
        duration = 8,
        max_stack = 1
    },
    -- Talent: Hurls a spray of shots, hitting all enemies in front of you.
    barrage = {
        id = 120360,
        duration = 3,
        tick_time = 0.2,
        max_stack = 1
    },
    -- Talent: Your next Multi-Shot or Arcane Shot will be free.
    thrill_of_the_hunt = {
        id = 34720,
        duration = 15,
        max_stack = 3
    },
    -- Talent: A swarm of crows assaults the target, dealing damage. If the target dies while under attack, the cooldown is reset.
    a_murder_of_crows = {
        id = 131894,
        duration = 15,
        tick_time = 1,
        max_stack = 1
    },
    -- Talent: Your pet rapidly attacks the target, dealing Physical damage.
    lynx_rush = {
        id = 120697,
        duration = 4,
        tick_time = 0.5,
        max_stack = 1
    },
    -- Talent: Instantly restores 50 Focus to you and 50 Focus to your pet.
    fervor = {
        id = 82726,
        duration = 10,
        max_stack = 1
    },
    -- Talent: A powerful wild beast attacks your target, dealing Physical damage.
    dire_beast = {
        id = 120679,
        duration = 15,
        tick_time = 2,
        max_stack = 1
    },
    -- Talent: Hurls two glaives in sequence at the target and nearby enemies, dealing Physical damage.
    glaive_toss = {
        id = 117050,
        duration = 3,
        max_stack = 1
    },
    -- Talent: Fires a powerful shot that deals Physical damage to the target and knocks back all targets within 5 yards.
    powershot = {
        id = 109259,
        duration = 2,
        max_stack = 1
    },

    -- Talent: Suffering Nature damage every 3 sec.
    serpent_sting = {
        id = 118253,   -- MoP Serpent Sting DOT debuff ID
        duration = 15,
        tick_time = 3,
        max_stack = 1,
        -- Add additional IDs for better compatibility
        copy = { 1978, 118253 }  -- Link the ability ID (1978) with debuff ID (118253)
    },
    -- Hunter's Mark - Reveals the target to you and increases all damage dealt to the target by 20%.
    hunters_mark = {
        id = 1130,
        duration = 300,
        max_stack = 1
    },
    -- Black Arrow - Ticks for Shadow damage and generates focus when it deals damage.
    black_arrow = {
        id = 3674,
        duration = 20,
        tick_time = 2,
        max_stack = 1
    },
    -- Talent: Silenced and unable to cast spells.
    silencing_shot = {
        id = 34490,
        duration = 3,
        max_stack = 1
    },
    -- Talent: Disengage also creates a web trap, snaring enemies for 8 sec.
    narrow_escape = {
        id = 136634,
        duration = 8,
        max_stack = 1
    },
    -- Talent: Reduces the cooldown of Disengage and Deterrence by 10%.
    crouching_tiger_hidden_chimera = {
        id = 128432,
        duration = 3600,
        max_stack = 1
    },
    -- Talent: Puts the target to sleep for 30 sec. Any damage caused will awaken the target. Only one target can be affected by Wyvern Sting at a time.
    wyvern_sting = {
        id = 19386,
        duration = 30,
        max_stack = 1
    },
    
    -- Lock and Load proc - Your traps have a chance to cause your next Explosive Shot to not consume focus and reset the cooldown.
    lock_and_load = {
        id = 56453,
        duration = 12,
        max_stack = 2,
        copy = { 56453 }  -- Ensure proper ID linking
    },
    
    -- Explosive Shot DoT
    explosive_shot = {
        id = 53301,
        duration = 2,
        tick_time = 0.5,
        max_stack = 1
    },
    
    -- Cobra Shot focus regeneration
    cobra_shot_regen = {
        id = 82726, -- Using Fervor spell ID as placeholder
        duration = 15,
        max_stack = 1,
        copy = { 82726 }  -- Ensure proper ID linking
    },

    -- Missing auras for APL compatibility
    rapid_fire = {
        id = 3045,
        duration = 15,
        max_stack = 1,
        copy = { 3045 }  -- Ensure proper ID linking
    },

    mend_pet = {
        id = 136,
        duration = 10,
        max_stack = 1
    },

    -- Master Marksman (shared Hunter mechanic)
    master_marksman = {
        id = 82925,
        duration = 15,
        max_stack = 5
    },

    -- PvP enlisted buff (placeholder)
    enlisted = {
        id = 1234567, -- Placeholder ID
        duration = 3600,
        max_stack = 1
    },
    
    -- Missing auras for other Hunter spec compatibility
    improved_steady_shot = {
        id = 53220,
        duration = 12,
        max_stack = 1
    },
    
    bestial_wrath = {
        id = 19574,
        duration = 18,
        max_stack = 1
    },
    
    frenzy = {
        id = 19621,
        duration = 8,
        max_stack = 5
    },
    
    beast_cleave = {
        id = 115939,
        duration = 4,
        max_stack = 1
    },
    
    careful_aim = {
        id = 34483,
        duration = 10,
        max_stack = 1
    },
    
    steady_focus = {
        id = 53220,
        duration = 15,
        max_stack = 1
    },
    
    -- Missing tier set bonuses
    tier14_4pc = {
        id = 123157,
        duration = 10,
        max_stack = 1
    },
    
    tier15_4pc = {
        id = 138369,
        duration = 10,
        max_stack = 1
    },
    
    tier16_4pc = {
        id = 144660,
        duration = 5,
        max_stack = 1
    }
} )

-- Missing debuffs for other Hunter spec compatibility
spec:RegisterAuras( {
    concussive_shot = {
        id = 5116,
        duration = 6,
        max_stack = 1
    },
    
    piercing_shots = {
        id = 63468,
        duration = 8,
        max_stack = 1
    }
} )

-- Pets
spec:RegisterPets({
    -- Basic pet
    main_pet = {
        id = function() 
            local petGUID = UnitGUID("pet")
            if petGUID then
                return tonumber( petGUID:match( "%-(%d+)%-[0-9A-F]+$" ) )
            end
            return nil
        end,
        duration = 3600
    },
    -- Dire Beast (Tier 4 talent)
    dire_beast = {
        id = 120679,
        duration = 15
    },
    -- A Murder of Crows (Tier 5 talent)
    murder_of_crows = {
        id = 131894,
        duration = 15
    }
} )

-- Mists of Pandaria
spec:RegisterGear( "tier14", 85830, 85831, 85832, 85833, 85834 ) -- Yaungol Slayer's Battlegear
spec:RegisterGear( "tier15", 95336, 95337, 95338, 95339, 95340 ) -- Faultline Battlegear
spec:RegisterGear( "tier16", 99402, 99403, 99404, 99405, 99406 ) -- Battlegear of the Unblinking Vigil

spec:RegisterAuras( {
    -- Tier 14 (2-piece) - Your Arcane Shot critical strikes have a 20% chance to reset the cooldown of your Aimed Shot.
    t14_2pc_crit_reset = {
        id = 123156,
        duration = 10,
        max_stack = 1
    },
    
    -- Tier 15 (2-piece) - Your Arcane Shot and Multi-Shot critical strikes have a 35% chance to make your next Aimed Shot or Explosive Shot cost no Focus.
    t15_2pc_focus_proc = {
        id = 138368,
        duration = 10,
        max_stack = 1
    },
    
    -- Tier 16 (2-piece) - When Kill Command or Explosive Shot deals damage, you have a 40% chance to gain 15% increased critical strike chance for 5 sec.
    t16_2pc_crit_bonus = {
        id = 144659,
        duration = 5,
        max_stack = 1
    }
} )


-- Hook to help Hekili recognize Survival spec correctly
spec:RegisterHook( "check", function( display )
    -- Check if player is Hunter class
    local _, playerClassCheck = UnitClass("player")
    if playerClassCheck ~= "HUNTER" then 
        return false 
    end
    
    local currentSpec = GetSpecialization and GetSpecialization() or 0
    local specName = ""
    
    if currentSpec > 0 then
        local _, name = GetSpecializationInfo(currentSpec)
        specName = name or ""
    end
    
    -- Debug output
    -- print("SURVIVAL DETECTION: Spec=" .. currentSpec .. ", Name=" .. specName)
    -- print("HEKILI DEBUG: Display=" .. (display and display.displayName or "nil") .. ", Combat=" .. ((UnitAffectingCombat and UnitAffectingCombat("player")) or InCombatLockdown() and "true" or "false"))
    -- print("HEKILI DEBUG: Hekili.DB.profile.enabled=" .. tostring(Hekili.DB.profile.enabled))
    -- print("HEKILI DEBUG: GetSpecialization()=" .. tostring(GetSpecialization()))
    
    -- Force Survival detection for spec 3 OR if specName contains "Survival"
    if currentSpec == 3 or specName:find("Survival") or specName:find("survival") then
        -- print("SURVIVAL DETECTION: ACTIVATED - Using Survival spec")
        return true
    end
     -- Also try to detect by checking for Survival-specific spells
    local hasSurvivalSpell = IsSpellKnown(53301) -- Explosive Shot
    if hasSurvivalSpell then
        -- print("SURVIVAL DETECTION: ACTIVATED - Found Explosive Shot (forcing spec override)")
        -- Force Hekili to switch to our Survival spec
        if Hekili.State then
            Hekili.State.spec = spec
        end
        return true
    end

    -- print("HEKILI DEBUG: Survival detection FAILED")
    return false
end )

spec:RegisterHook( "runHandler", function( action, pool )
    if buff.camouflage.up and action ~= "camouflage" then removeBuff( "camouflage" ) end
    if buff.feign_death.up and action ~= "feign_death" then removeBuff( "feign_death" ) end
end )

local function IsActiveSpell( id )
    local slot = FindSpellBookSlotBySpellID( id )
    if not slot then return false end

    local _, _, spellID = GetSpellBookItemName( slot, "spell" )
    return id == spellID
end

-- Set up the state reference correctly with multiple fallbacks
local function ensureState()
    if not state then 
        state = Hekili.State 
    end
    if not state and Hekili and Hekili.State then
        state = Hekili.State
    end
    if state and state.IsActiveSpell == nil then
        state.IsActiveSpell = IsActiveSpell
    end
end

-- Call it immediately and also register as a hook for safety
ensureState()

-- Also ensure state is available in a hook for delayed initialization
-- Combined reset_precast hook to avoid conflicts
spec:RegisterHook( "reset_precast", function()
    -- Ensure state is properly initialized first
    ensureState()
    
    if debuff.explosive_trap.up then
        debuff.explosive_trap.expires = debuff.explosive_trap.applied + 10
    end

    if now - action.disengage.lastCast < 1.5 then
        setDistance( 15 )
    end

    -- Force sync Serpent Sting if there's a mismatch between game and Hekili state
    if UnitExists("target") then
        for i = 1, 40 do
            local name, _, _, _, _, expires, caster, _, _, spellID = UnitDebuff("target", i)
            if not name then break end
            if spellID == 118253 and caster == "player" then
                local gameRemains = expires > 0 and (expires - GetTime()) or 0
                if gameRemains > 0 and (not debuff.serpent_sting.up or debuff.serpent_sting.remains <= 0) then
                    -- if Hekili.ActiveDebug then
                    --     print("SYNC: Force applying serpent_sting debuff with " .. tostring(gameRemains) .. " seconds")
                    -- end
                    applyDebuff("target", "serpent_sting", gameRemains)
                end
                break
            end
        end
    end

    -- Auto-sync missing player buffs
    for i = 1, 40 do
        local name, _, _, _, _, expires, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end
        
        -- Sync missing buffs based on spell IDs from your list
        local gameRemains = expires > 0 and (expires - GetTime()) or 0
        if gameRemains > 0 then
            if spellID == 109260 and not buff.aspect_of_the_iron_hawk.up then
                applyBuff("aspect_of_the_iron_hawk", gameRemains)
                -- if Hekili.ActiveDebug then
                --     print("SYNC: Applied aspect_of_the_iron_hawk buff")
                -- end
            elseif spellID == 3045 and not buff.rapid_fire.up then
                applyBuff("rapid_fire", gameRemains)
                -- if Hekili.ActiveDebug then
                --     print("SYNC: Applied rapid_fire buff")
                -- end
            elseif spellID == 56453 and not buff.lock_and_load.up then
                applyBuff("lock_and_load", gameRemains, 2)  -- 2 stacks
                -- if Hekili.ActiveDebug then
                --     print("SYNC: Applied lock_and_load buff")
                -- end
            elseif spellID == 82726 and not buff.cobra_shot_regen.up then
                applyBuff("cobra_shot_regen", gameRemains)
                -- if Hekili.ActiveDebug then
                --     print("SYNC: Applied cobra_shot_regen buff")
                -- end
            end
        end
    end

    -- Debug talent detection
    -- if Hekili.ActiveDebug then
    --     print("TALENT DEBUG: aspect_of_the_iron_hawk.enabled = " .. tostring(talent.aspect_of_the_iron_hawk.enabled))
    --     print("TALENT DEBUG: posthaste.enabled = " .. tostring(talent.posthaste.enabled))
    --     print("TALENT DEBUG: fervor.enabled = " .. tostring(talent.fervor.enabled))
    --     print("TALENT DEBUG: glaive_toss.enabled = " .. tostring(talent.glaive_toss.enabled))
    --     print("TALENT DEBUG: powershot.enabled = " .. tostring(talent.powershot.enabled))
    --     print("TALENT DEBUG: barrage.enabled = " .. tostring(talent.barrage.enabled))
    --     
    --     -- Debug aspect buffs
    --     print("ASPECT DEBUG: aspect_of_the_hawk.up = " .. tostring(buff.aspect_of_the_hawk.up))
    --     print("ASPECT DEBUG: aspect_of_the_iron_hawk.up = " .. tostring(buff.aspect_of_the_iron_hawk.up))
    --     print("ASPECT DEBUG: aspect_of_the_cheetah.up = " .. tostring(buff.aspect_of_the_cheetah.up))
    --     print("ASPECT DEBUG: aspect_of_the_pack.up = " .. tostring(buff.aspect_of_the_pack.up))
    --     print("ASPECT DEBUG: has_aspect = " .. tostring(has_aspect))
    -- end
        
    -- MoP talent specific resets
    if talent.glaive_toss.enabled then
        class.abilities.multi_shot = class.abilities.glaive_toss
    elseif talent.powershot.enabled then
        class.abilities.multi_shot = class.abilities.powershot
    elseif talent.barrage.enabled then
        class.abilities.multi_shot = class.abilities.barrage
    end

    -- Trap-based Lock and Load procs (passive for Survival)
    if (action.explosive_trap.lastCast > now - 1) then
        applyBuff("lock_and_load", 12, 2)  -- 2 charges for 12 seconds
    end
    
    -- Tier 14 2pc - Arcane Shot crits have 20% chance to reset Aimed Shot cooldown
    if set_bonus.tier14_2pc > 0 and action.arcane_shot.lastCast > now - 5 and GetTime() % 1 < 0.2 then
        setCooldown("aimed_shot", 0)
    end
end )

-- Register trap handler for MoP
-- MoP Talent Detection Hook
spec:RegisterHook( "PLAYER_TALENT_UPDATE", function()
    if not GetTalentInfo then return end
    
    local specGroup = GetActiveSpecGroup and GetActiveSpecGroup() or 1
    
    -- Debug output for talent detection
    if Hekili.ActiveDebug then
        print("=== MOP TALENT DETECTION DEBUG ===")
        for tier = 1, 6 do
            for column = 1, 3 do
                local id, name, icon, selected = GetTalentInfo(tier, column, specGroup)
                if selected then
                    print("SELECTED TALENT: Tier " .. tier .. ", Column " .. column .. " - " .. (name or "Unknown") .. " (ID: " .. (id or "nil") .. ")")
                end
            end
        end
        print("=== END TALENT DEBUG ===")
    end
end )

-- Debug toggle function
SLASH_HEKILIDEBUG1 = "/hekilidebug"
SlashCmdList["HEKILIDEBUG"] = function(msg)
    if Hekili.ActiveDebug then
        Hekili.ActiveDebug = false
        print("Hekili Debug: DISABLED")
    else
        Hekili.ActiveDebug = true
        print("Hekili Debug: ENABLED")
    end
end

-- Debug command to check Serpent Sting state specifically
SLASH_HEKILISERPENT1 = "/hekiliserpent"
SlashCmdList["HEKILISERPENT"] = function(msg)
    print("=== SERPENT STING STATE CHECK ===")
    
    -- Check if we have a target
    if not UnitExists("target") then
        print("ERROR: No target selected")
        return
    end
    
    print("Target: " .. (UnitName("target") or "Unknown"))
    
    -- Check actual game debuffs
    print("--- GAME API SCAN ---")
    local found = false
    local gameExpires = 0
    local gameRemains = 0
    for i = 1, 40 do
        local name, icon, count, dispelType, duration, expires, caster, isStealable, nameplateShowPersonal, spellID = UnitDebuff("target", i)
        if not name then break end
        if spellID == 118253 or string.find(string.lower(name), "serpent") then
            print("Found: " .. name .. " (ID: " .. spellID .. ") Duration: " .. (duration or 0) .. " Expires: " .. (expires or 0) .. " Caster: " .. (caster or "unknown"))
            found = true
            gameExpires = expires or 0
            gameRemains = gameExpires > 0 and (gameExpires - GetTime()) or 0
            break
        end
    end
    if not found then
        print("No Serpent Sting debuff found via game API")
    end
    
    -- Check Hekili state
    print("--- HEKILI STATE ---")
    if Hekili and Hekili.State then
        local state = Hekili.State
        print("debuff.serpent_sting.up = " .. tostring(state.debuff.serpent_sting.up))
        print("debuff.serpent_sting.remains = " .. tostring(state.debuff.serpent_sting.remains))
        print("debuff.serpent_sting.expires = " .. tostring(state.debuff.serpent_sting.expires))
        print("active_dot.serpent_sting = " .. tostring(state.active_dot.serpent_sting))
    else
        print("Hekili.State not available")
    end
    
    -- Force sync if there's a mismatch
    if found and gameRemains > 0 and Hekili and Hekili.State then
        local state = Hekili.State
        if not state.debuff.serpent_sting.up or state.debuff.serpent_sting.remains <= 0 then
            print("--- FORCE SYNC ---")
            print("Mismatch detected! Game has debuff but Hekili doesn't. Forcing sync...")
            
            -- Manually apply the debuff to Hekili's state
            if state.applyDebuff then
                state.applyDebuff("target", "serpent_sting", gameRemains)
                print("Applied serpent_sting debuff to Hekili state with " .. gameRemains .. " seconds remaining")
            end
        end
    end
    
    print("=== END SERPENT STING CHECK ===")
end

-- Force sync command
SLASH_HEKILISYNC1 = "/hekilisync"
SlashCmdList["HEKILISYNC"] = function(msg)
    print("=== FORCE HEKILI SYNC ===")
    
    if not UnitExists("target") then
        print("ERROR: No target selected")
        return
    end
    
    if not (Hekili and Hekili.State) then
        print("ERROR: Hekili.State not available")
        return
    end
    
    local state = Hekili.State
    local synced = 0

    -- Add your sync logic here if needed

end

-- State Expressions for MoP Hunter
spec:RegisterStateExpr("pet_health_pct", function()
    if UnitExists("pet") then
        return (UnitHealth("pet") / UnitHealthMax("pet")) * 100
    end
    return 0
end)

spec:RegisterStateExpr("pet_exists", function()
    return UnitExists("pet")
end)

spec:RegisterStateExpr("buff_mend_pet_up", function()
    return FindUnitBuffByID(136, "pet")
end)

spec:RegisterStateExpr("in_combat", function()
    return UnitAffectingCombat and UnitAffectingCombat("player") or InCombatLockdown()
end)

spec:RegisterStateExpr("has_aspect", function()
    return buff.aspect_of_the_hawk.up or buff.aspect_of_the_iron_hawk.up or buff.aspect_of_the_cheetah.up or buff.aspect_of_the_pack.up
end)

-- Add missing state expressions for other Hunter specs compatibility
spec:RegisterStateExpr("focus_deficit", function()
    return focus.max - focus.current
end)

spec:RegisterStateExpr("focus_time_to_max", function()
    return focus.deficit / focus.regen
end)

spec:RegisterStateFunction( "apply_aspect", function( name )
    removeBuff( "aspect_of_the_hawk" )
    removeBuff( "aspect_of_the_iron_hawk" )
    removeBuff( "aspect_of_the_cheetah" )
    removeBuff( "aspect_of_the_pack" )
    
    if name then applyBuff( name ) end
end )

-- Abilities
spec:RegisterAbilities( {
    -- Auto Attack - basic melee/ranged auto attacks
    auto_attack = {
        id = 6603,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",

        startsCombat = true,
        texture = 135600,

        handler = function ()
            -- Enable auto attacks if not already active
        end,
    },

    -- Fires an arcane shot, dealing Arcane damage.
    arcane_shot = {
        id = 3044,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",

        spend = 20,
        spendType = "focus",
        
        copy = { 3044 },  -- Ensure proper ID linking

        startsCombat = true,

        handler = function ()
            -- Tier 14 2pc - 20% chance to reset Aimed Shot cooldown
            if set_bonus.tier14_2pc > 0 and GetTime() % 1 < 0.2 then -- Use time-based random
                setCooldown("aimed_shot", 0)
            end
            
            -- Tier 15 2pc - 35% chance to make next Aimed Shot or Explosive Shot cost no Focus
            if set_bonus.tier15_2pc > 0 and GetTime() % 1 < 0.35 then -- Use time-based random
                applyBuff("t15_2pc_focus_proc")
            end
            
            -- Handle Thrill of the Hunt talent
            if talent.thrill_of_the_hunt.enabled and GetTime() % 1 < 0.3 then -- Use time-based random
                applyBuff("thrill_of_the_hunt", 15, 1)
            end
        end,
    },
    
    -- Aim carefully for a critical shot dealing increased Physical damage.
    aimed_shot = {
        id = 19434,
        cast = 2.9, -- Modified for MoP
        cooldown = 10,
        gcd = "spell",

        spend = 50,
        spendType = 'focus',
        
        copy = { 19434 },  -- Ensure proper ID linking

        startsCombat = true,

        handler = function ()
            -- No special effects for Aimed Shot in MoP Survival
        end,
    },
    
    -- Increases ranged attack power by 15% and reduces damage taken by 10%.
    aspect_of_the_hawk = {
        id = 13165,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        copy = { 13165 },  -- Ensure proper ID linking
        
        startsCombat = false,
        
        usable = function () 
            return not talent.aspect_of_the_iron_hawk.enabled and not buff.aspect_of_the_hawk.up and not has_aspect
        end,

        handler = function ()
            apply_aspect("aspect_of_the_hawk")

        end,
    },
    
    -- Talent: Increases ranged attack power by 15% and reduces damage taken by 10%. Enhanced version of Aspect of the Hawk.
    aspect_of_the_iron_hawk = {
        id = 109260,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        talent = "aspect_of_the_iron_hawk",
        copy = { 109260, 13165 },  -- Link with regular Aspect of the Hawk
        startsCombat = false,
        
        usable = function () 
            return talent.aspect_of_the_iron_hawk.enabled and not buff.aspect_of_the_iron_hawk.up and not has_aspect
        end,

        handler = function ()
            apply_aspect("aspect_of_the_iron_hawk")
        end,
    },
    
    -- A stealthy aspect, allowing you to enter camouflage. While camouflaged, you are nearly invisible and generate no threat. Movement speed is reduced by 30%.
    camouflage = {
        id = 51753,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyBuff("camouflage")
        end,
    },
    
    -- A shot that deals Physical damage to the target and additional Nature damage over 15 sec.
    cobra_shot = {
        id = 77767,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        spend = 20,
        spendType = "focus",
        
        copy = { 77767 },  -- Ensure proper ID linking

        startsCombat = true,

        handler = function ()
            -- Cobra Shot extends Serpent Sting by 6 sec
            if debuff.serpent_sting.up then
                debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
            end
        end,
    },
    
    -- Disengage from combat, leaping backward.
    disengage = {
        id = 781,
        cast = 0,
        cooldown = function() return 20 - (talent.crouching_tiger_hidden_chimera.enabled and 2 or 0) end,
        gcd = "off",
        school = "physical",

        copy = { 781 },  -- Ensure proper ID linking
        startsCombat = false,

        handler = function ()
            if talent.posthaste.enabled then
                applyBuff("posthaste")
            end
            if talent.narrow_escape.enabled then
                applyDebuff("target", "narrow_escape")
            end
            setDistance(15)
        end,
    },
    
    -- Fire explosive ammunition at the target, dealing Fire damage to all enemies within 10 yards of the target.
    explosive_shot = {
        id = 53301,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "fire",

        spend = function() return buff.t15_2pc_focus_proc.up and 0 or 40 end,
        spendType = "focus",
        
        copy = { 53301 },  -- Ensure proper ID linking

        startsCombat = true,

        handler = function ()
            -- 3 ticks of damage over 2 seconds
            applyDebuff("target", "explosive_shot")
            removeBuff("t15_2pc_focus_proc")
            removeBuff("lock_and_load")
            
            -- Tier 16 2pc - 40% chance to gain 15% crit for 5 sec
            if set_bonus.tier16_2pc > 0 and GetTime() % 1 < 0.4 then
                applyBuff("t16_2pc_crit_bonus")
            end
        end,
    },
    
    -- Launch a fire trap to the target location that explodes when an enemy approaches, causing Fire damage over 10 sec to all enemies within 10 yards. Trap will exist for 30 sec. Only one trap can be active at a time.
    explosive_trap = {
        id = 13813,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "fire",

        copy = { 13813 },  -- Ensure proper ID linking
        startsCombat = false,

        handler = function ()
            trap_handler.trap_used("explosive")
        end,
    },
    
    -- Feign death, tricking enemies into not attacking you. Lasts for 3 min.
    feign_death = {
        id = 5384,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyBuff("feign_death")
        end,
    },
    
    -- Talent: Instantly restores 50 Focus to you and 50 Focus to your pet.
    fervor = {
        id = 82726,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "nature",

        talent = "fervor",
        copy = { 82726 },  -- Ensure proper ID linking
        startsCombat = false,

        handler = function ()
            gain(50, "focus")
            applyBuff("fervor")
        end,
    },
    
    -- Hurls two glaives in sequence at the target and nearby enemies, dealing Physical damage.
    glaive_toss = {
        id = 117050,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        school = "physical",

        talent = "glaive_toss",
        copy = { 117050 },  -- Ensure proper ID linking
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "glaive_toss")
        end,
    },
    
    -- Give the command to kill, causing your pet to savagely deal Physical damage to the enemy.
    kill_command = {
        id = 34026,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",

        spend = -15,
        spendType = "focus",
        
        copy = { 34026 },  -- Ensure proper ID linking

        startsCombat = true,

        usable = function () return pet.alive, "requires a living pet" end,
        handler = function ()
            -- In MoP, Kill Command is a primary focus generator
        end,
    },
    
    -- Talent: Your pet rapidly attacks the target, dealing Physical damage.
    lynx_rush = {
        id = 120697,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        school = "physical",

        talent = "lynx_rush",
        startsCombat = true,

        usable = function () return pet.alive, "requires a living pet" end,
        handler = function ()
            applyDebuff("target", "lynx_rush")
        end,
    },
    
    -- Talent: Misdirects all threat you cause to the targeted party or raid member, beginning with your next attack and lasting for 8 sec.
    misdirection = {
        id = 34477,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",

        talent = "misdirection",
        startsCombat = false,

        usable = function () return pet.alive or group, "requires a living pet or ally" end,
        handler = function ()
            applyBuff("misdirection")
        end,
    },
    
    -- Fires several missiles, hitting all enemies within 10 yards of the target for Physical damage.
    multi_shot = {
        id = 2643,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "focus",
        
        copy = { 2643 },  -- Ensure proper ID linking

        startsCombat = true,

        handler = function ()
            -- Tier 15 2pc - 35% chance to make next Aimed Shot or Explosive Shot cost no Focus
            if set_bonus.tier15_2pc > 0 and GetTime() % 1 < 0.35 then
                applyBuff("t15_2pc_focus_proc")
            end
            
            -- Handle Thrill of the Hunt talent
            if talent.thrill_of_the_hunt.enabled and GetTime() % 1 < 0.3 then
                applyBuff("thrill_of_the_hunt", 15, 1)
            end
        end,
    },
    
    -- Talent: Fires a powerful shot that deals Physical damage to the target and knocks back all targets within 5 yards.
    powershot = {
        id = 109259,
        cast = 2,
        cooldown = 45,
        gcd = "spell",
        school = "physical",

        talent = "powershot",
        copy = { 109259 },  -- Ensure proper ID linking
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "powershot")
        end,
    },
    
    -- A stinging shot that deals initial Nature damage and additional Nature damage over 15 sec.
    serpent_sting = {
        id = 1978,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        spend = 20,
        spendType = "focus",
        
        copy = { 1978, 118253 },  -- Link ability ID with debuff ID

        startsCombat = true,

        handler = function ()
            -- Debug: Serpent Sting application
            if Hekili.ActiveDebug then
                print("SERPENT STING DEBUG: Applying serpent_sting debuff")
                print("SERPENT STING DEBUG: Target = " .. (UnitName("target") or "nil"))
                print("SERPENT STING DEBUG: Before - debuff.serpent_sting.up = " .. tostring(debuff.serpent_sting.up))
                print("SERPENT STING DEBUG: Before - debuff.serpent_sting.remains = " .. tostring(debuff.serpent_sting.remains))
            end
            
            applyDebuff("target", "serpent_sting")
            
            -- Debug: After application
            if Hekili.ActiveDebug then
                print("SERPENT STING DEBUG: After - debuff.serpent_sting.up = " .. tostring(debuff.serpent_sting.up))
                print("SERPENT STING DEBUG: After - debuff.serpent_sting.remains = " .. tostring(debuff.serpent_sting.remains))
                print("SERPENT STING DEBUG: After - active_dot.serpent_sting = " .. tostring(active_dot.serpent_sting))
                
                -- Check actual target debuffs via game API
                if UnitExists("target") then
                    local found = false
                    for i = 1, 40 do
                        local name, _, _, _, _, _, caster, _, _, spellID = UnitDebuff("target", i)
                        if not name then break end
                        if spellID == 118253 then -- Serpent Sting debuff ID
                            print("SERPENT STING DEBUG: Found actual debuff on target - " .. name .. " (ID: " .. spellID .. ") from " .. (caster or "unknown"))
                            found = true
                            break
                        end
                    end
                    if not found then
                        print("SERPENT STING DEBUG: No actual serpent_sting debuff found on target via UnitDebuff")
                    end
                end
            end
        end,
    },
    
    -- Talent: Silences the target and interrupts spellcasting for 3 sec.
    silencing_shot = {
        id = 34490,
        cast = 0,
        cooldown = 20,
        gcd = "off",
        school = "nature",

        talent = "silencing_shot",
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "silencing_shot")
        end,
    },
    
    -- Begin launching traps to target location.
    trap_launcher = {
        id = 77769,
        cast = 0,
        cooldown = 1.5,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyBuff("trap_launcher")
        end,
    },
    
    -- Wing Clip not available or different ID in MoP - removed
    --[[
    -- Slows the target by 50% for 15 sec.
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
            applyDebuff("target", "wing_clip")
        end,
    },
    --]]
    
    -- Talent: Puts the target to sleep for 30 sec. Any damage caused will awaken the target. Only one target can be affected by Wyvern Sting at a time.
    wyvern_sting = {
        id = 19386,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",

        talent = "wyvern_sting",
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "wyvern_sting")
        end,
    },
    
    -- Talent: A swarm of crows assaults the target, dealing damage. If the target dies while under attack, the cooldown is reset.
    a_murder_of_crows = {
        id = 131894,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "nature",

        talent = "a_murder_of_crows",
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "a_murder_of_crows")
        end,
    },
    
    -- Talent: A powerful wild beast attacks your target, dealing Physical damage.
    dire_beast = {
        id = 120679,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",

        talent = "dire_beast",
        startsCombat = true,

        handler = function ()
            applyBuff("dire_beast")
        end,
    },
    
    -- Fire a magical arrow, dealing Arcane damage and causing all targets within 10 yards to take Nature damage every 3 sec for 15 sec.
    black_arrow = {
        id = 3674,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "shadow",

        spend = 35,
        spendType = "focus",
        
        copy = { 3674 },  -- Ensure proper ID linking

        startsCombat = true,

        handler = function ()
            applyDebuff("target", "black_arrow")
            
            -- Tier 16 2pc - 40% chance to gain 15% crit for 5 sec
            if set_bonus.tier16_2pc > 0 and GetTime() % 1 < 0.4 then
                applyBuff("t16_2pc_crit_bonus")
            end
        end,
    },
    
    -- Talent: Hurls a spray of shots, hitting all enemies in front of you.
    barrage = {
        id = 120360,
        cast = 3,
        channeled = true,
        cooldown = 30,
        gcd = "spell",
        school = "physical",

        talent = "barrage",
        copy = { 120360 },  -- Ensure proper ID linking
        startsCombat = true,

        start = function ()
            applyBuff("barrage")
        end,
        
        finish = function ()
            removeBuff("barrage")
        end,
    },
    
    -- Talent: You and your pet regenerate 2% of total health every 5 sec.
    spirit_bond = {
        id = 109212,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "nature",

        talent = "spirit_bond",
        startsCombat = false,

        handler = function ()
            applyBuff("spirit_bond")
        end,
    },
    
    -- Talent: When activated, you and your pet immediately heal for 30% of your maximum health.
    exhilaration = {
        id = 109304,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "nature",

        talent = "exhilaration",
        startsCombat = false,

        handler = function ()
            applyBuff("exhilaration")
            gain(0.3 * health.max, "health")
        end,
    },

    -- Abilities added to fix APL import errors
    -- call_pet = {
    --     id = 883, -- Call Pet 1
    --     copy = { 883, 83242, 83243, 83244, 83245, "call_pet_1", "call_pet_2", "call_pet_3", "call_pet_4", "call_pet_5", "summon_pet" },
    --     cast = 3,
    --     usable = function() return not pet.exists end,
    -- },

    stampede = {
        id = 121818,
        cooldown = 300,
        toggle = "cooldowns",
        copy = { 121818 },  -- Ensure proper ID linking
        usable = function() return UnitLevel("player") >= 87 end,
        known = function() return UnitLevel("player") >= 87 end,
    },

    blink_strike = {
        copy = "blink_strikes",
        talent = "blink_strikes",
    },

    tranquilizing_shot = {
        id = 19801,
        spend = 20,
        spendType = "focus",
        toggle = "dispels",
    },

    deterrence = {
        id = 19263,
        cast = 0,
        cooldown = function() return 90 - (talent.crouching_tiger_hidden_chimera.enabled and 9 or 0) end,
        gcd = "off",
        school = "physical",
        
        toggle = "defensives",
        startsCombat = false,
        
        handler = function()
            applyBuff("deterrence")
        end,
    },

    readiness = {
        id = 23989, -- Readiness - resets cooldowns
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        
        name = "Readiness", -- Add missing name
        toggle = "cooldowns",
        startsCombat = false,
        known = function() return UnitLevel("player") >= 23 end,
        
        handler = function()
            -- Readiness resets most hunter ability cooldowns
            setCooldown("explosive_shot", 0)
            setCooldown("disengage", 0)
            setCooldown("deterrence", 0)
            setCooldown("silencing_shot", 0)
            setCooldown("wyvern_sting", 0)
            setCooldown("explosive_trap", 0)
            setCooldown("black_arrow", 0)
        end,
    },

    -- Missing abilities for APL compatibility
    kill_shot = {
        id = 53351,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "focus",

        startsCombat = true,
        usable = function() return target.health.pct <= 20 end,

        handler = function ()
        end,
    },

    hunters_mark = {
        id = 1130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        handler = function ()
            applyDebuff("target", "hunters_mark")
        end,
    },

    rapid_fire = {
        id = 3045,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        school = "physical",

        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            applyBuff("rapid_fire", 15)
        end,
    },

    mend_pet = {
        id = 136,
        cast = 2,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        spend = 25,
        spendType = "focus",

        startsCombat = false,
        usable = function() return pet.exists and pet.health.pct < 100 end,

        handler = function ()
            applyBuff("mend_pet", 10)
        end,
    },

    aspect_of_the_cheetah = {
        id = 5118,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,
        usable = function() return not combat and not buff.aspect_of_the_cheetah.up and not has_aspect end,

        handler = function ()
            apply_aspect("aspect_of_the_cheetah")
        end,
    },


    call_pet = {
        id = 883,
        cast = 10,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,
        usable = function() return not pet.exists end,

        handler = function ()
            -- Pet summoning logic
        end,
    },
    
    -- Missing abilities for other Hunter spec compatibility
    steady_shot = {
        id = 56641,
        cast = 2.0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = -14,
        spendType = "focus",

        startsCombat = true,

        handler = function ()
            -- Generate focus and apply Steady Focus if needed
            if action.steady_shot.lastCast > now - 3 then
                applyBuff("steady_focus", 15)
            end
        end,
    },
    
    concussive_shot = {
        id = 5116,
        cast = 0,
        cooldown = 12,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "focus",

        startsCombat = true,

        handler = function ()
            applyDebuff("target", "concussive_shot")
        end,
    }
} )

spec:RegisterRanges( "silencing_shot", "arcane_shot" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 2,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    potion = "virmen_bite_potion", -- MoP-era agility potion

    package = "Survival"
} )

local beastMastery = class.specs[ 253 ]


spec:RegisterSetting( "mark_any", false, {
    name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( 1130 ) ), -- Hunter's Mark spell ID for MoP
    desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( 1130 ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "auto_trap", false, {
    name = strformat( "Auto Recommend Traps" ),
    desc = strformat( "If checked, appropriate traps will be recommended during combat. Explosive Trap for AoE and Black Arrow for single target." ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "lock_and_load_toggle", "cooldowns", {
    name = strformat( "Lock and Load: Special Toggle" ),
    desc = strformat( "When you have Lock and Load procs available, Explosive Shot will only be recommended if the selected toggle is active." ),
    type = "select",
    width = 2,
    values = function ()
        local toggles = {
            none       = "Do Not Override",
            default    = "Default",
            cooldowns  = "Cooldowns",
            essences   = "Minor CDs",
            defensives = "Defensives",
            interrupts = "Interrupts",
            potions    = "Potions",
            custom1    = spec.custom1Name or "Custom 1",
            custom2    = spec.custom2Name or "Custom 2",
        }
        return toggles
    end
} )

spec:RegisterPack( "Survival", 20250406, [[Hekili:TQ1EVTnos8plbhUCPODDDCQt7c0ea3gVTPxEue5BxC)JKOLOJ5fzrFuso1hc0N9B4drrrrj7KwSy3lMpMz48E(PZ)y)z(EXOCS)nJgoA8W3pC8GHdho(yFV8TRX(ERrrpGUh(Ju0k4)En97LHEfSnKnOe(UBtOOyorYOfSi4e(EZlij5xM6p3fLpE0VdNDnocwE8yFVLK4yS8S4SiFVzljzLH8)fvgQyEziDb87OCcnTmmHKLdBVGYkd)k(bsczaiim6cscW()gSyrAoMvlMLH)wzOqWl)w53Gd8NtU7YjF6QPELHtU5IYWpF7nxC5SlV9gp(b2Gye08e8B4V4ZwqJkYcwsUF5BasvOw48ZE)q3NmH(O5b)4jJDFUv4ysXQM08KXhkVuxeFdMT1HS8Ho4reJKtIqjneOrTom3AqqjbfPKC1rZrS7X5dWjKC8tpP(vcEdo58ZwNG2IzYF96t07MtwHdYPbXe85hpwVCCXQvBBXrmBnonpilNKEFadVGHZQEtX45flwmOXrgWWRqK0SpEQnLMNaUibigJ(OfDoqriJtmOyT99tO8ntJd4UXbCxSnyfbe3UX(oUF(sgjjjGUiiFjoyj455GiTpKGscFXRlsYj)Muzb(4PXGpjDAzymohlD4T4iIIdYi5fi(MkUawqG(sIKnyfNKbzlP5GlL91JsWOn7pfoBKso)mLMetFeI)adnyskdROBMnlyO1K4GfegoaTbrse7iztKIkdQpdyBrXBp8aHMYy5I1WAjuACsrMH(As8guAeoMNaaCNldxHsHueRaFLwpvuAqeklpa)J1j0SAJIwk0BiERkjrfu9UwXGWzksIdap61bIdPix1PgyfK(0t6D60nH)QeVRVF30pF71FAYmXF(9j3nHNqQ8BYSEzdwZWr0vZr5V(S3I4rS5vulAjgNJw(gYIZKkrNBl0NRO8uJXhUIUHBc3dIVe94dDrz(EsZuFC1nxGSsjbRbxEN7UuKbhssIycUFugoNNha8mHvG4XT68lKSG50SSxDOuFged2rZRF2WdDMGsP2L1k(hGF01WH5EteyHuUlwz4rKvRPSCe4Ajl3eJwb(AVsl0)Qfvhs6hQ87fQ3MU71sHqDk)zaV(OkvH4ozkk8hyY9q47fyu(YYqGeaVsJ2AsMf8JeeZpb)TSeJsYxoyDu(hhnSYpfvKbQggnhjlhhrtJjcciQZUeUIsBPQRa)rvYMmtM9ick3KHJoB4GJ5Ct4ffZiPCNQNEs8Zfq8FDS)f4f4uE4Qkrzrou8pF7UveX6lQuM8mSZzGvEPzCq3kskMlH6W5g5GTsqMPeUvO)dxjGMZLrcoB3CjstHkkYm1078(1NuNvzI33N(ziLY1tUzYxME90BMvhWP8oEjH8v2JP)X0B8U8pNQ6J6Fn7YRUC2)UMfA9oWe8pwcLcyYIonDUgp09vKhjlNMITUX764gRizXqXJOkMa5DbN5bAB1566zZaR))fAuL8)efZ8G8)k3wieNebUhWRp7T4ugeUL5MB5M0qucrWtvJpernvU)I2C85BV9QlU9VUPPbH3fG0z5IV7XdO0osndJ49NblsttQD5hOpnip1vpB4T6QESBcKLJwTghlU(rTliRcknRk)Qd1ftRUSSmAhsiSfjfNLX5G7Mben6DETzcYhGZ7qx4Khq(PaOT1vVjlb6FjxsGJFgNTI33HK8QoeomUGjCx0YbKbLktH7Mbig0fcpzoJbPS5V66XcCD(5aLWShAuDUX(CDFWIc22Qi87L5adxtL5JReXLygLKT6TARLBckVMmbYgcdkSavPavIoJSJEWMn5kUJB4KpXJ3VeMJsSkHp017GgerjWBTdfYcmBdLjJt4hBGCHbqnxWTmwnae09LQTc12M9rysoE0EWCm0LNbjRxSISvcUqehxlIH8zcDA3cwvWIXmEIViy0HmdY3ApTWxnZr7t0L8ppbC5GHCyKhWgSWC563GlcKSn9hbSISLg3wVwlbRENAJPqNC6omB3NG4TSKtZm1egR2VuUM(i4yRtqkUSET(V6Cy0nifSPYrUILTDYTqzO7UDMSV5WJo51Ch17(Y0zEVYOOhvwlYSV)gjlDnqO913PiDO1ib8PbSjYERr3hIvpWwJht9foS3reBsSgJEl6eW5m5qN)D0z9Uu2gty13ZqDSXTowef6DRRxBc9rJ6T31WPqT8vGnw1L2vGvUmCALiw1iWrF9YV81PEqoU1mcLjsW(4sCQefQngJamOQRRxIBLqA8KAv4pYfjUrRxNqIuDxlesfWgM5Qm46pT5sif)ty(0Qxpbym(h4OICE)NOuocChnA4FNxuH3cM7x)d8jCTAcYOLTZ0Jq8joImqalhsgvDD1S8WajyM5l)c6mN8YauNgQzhWbDOgCnf7BzSRnXhjTXP8vTCs2xl(b9AYRJLBdorhUdAJ)Je(CBFM77RKCxsuZyJU8e0IHtK461rzIOJMgDmRSECGrKdnZOB4i0upAOBTNQ5OwblTaAXLaDQEkPAfsNot7HQQDAKd3HT8G(XrQEBtiivnhlNi)YBMCf))5QRMENweBjzhyjAvW667TbkGcxrHW(7gEQV3Jiwkh(bFVlfGxWTdV3c88bLFZ3t8xCG7vZbc)5nIVgGQSJ)NGTe3Q6iMdbkHRNrwlpq75m994IjgeCFVdKtt5Ews)C4FaQTabj)7timHkXI9ViuCSKqvOIjx4njfEiVZiBVVYWZld)ai43mYsABQwAbAt9ZXEgEPfjq(zwQSjadoPd1HbwnwCTdGEmFV15Lld)yz4OHCo9U(Ek)C4(47LHJ89go446hah)htzQb(pLHp9KYRrHbexch3Ne2b6q7PgxpxpNpN2RrTb4r9r(63MBKJAAYPcw)((y9UWyApFR62R5m8d9ZqtiO2tYRpoq9FVdV36mC2oVM5eTcr7kpOidIg)49prMcKANjtC(5d77lhUhFjNE)ik9(Ln64ZdS7KSg4WZZKbhs9nae)u(DaCLgBx0Tciqfr7LZ9whPkdxdpR14CtPXrUPFYu3hpUJ6kcxP64JECLQbTYoMXfiFpBe(CM9WfsE9B9oszBAGJNrY1gO7e(kHoRde9QF6vR7Q8unR7bEpHnyKHUScwqxM6QdvHKNL6UxecbznHNIrFxhfrSO)iR7mYvbbTdDd49SKSNh(HMQovcaOY8jJ1ffQ4zneHwXiFOXP0afADk7mYnRTT3Ojw9)HqmXmSv1CtVRArtsBUSC8WoBUHJ6NTLUfSJTWC0ucCIVOWbVs9EgC1HnsHPrBuiD2H(TODBGgRFc17jOLDiQ2dYgQq7hTdilDijDIjz1ZRhKjfYx3XX9ajPP7w9Uc61Dc7UaP0ssnHQSMp6vfmPRqzdu0CQopTphghqWjyMDoGwxSfGMMU8QTeuYUhV266MWjAOMLBiltX7ySNcunhk1oqVh0sDw6X1eW9x6Pd0A5wzhau66n2tXLEaGENmW07O3wlCb8kN6DHLkuwdsPCsnNQ3YvHhx9WyJuZ(2etJ75QIvRIlNlY(1P7IJrrCsIXd765ApyrN61e6J(UgmOcya1Cz96Qx)TLTNk093O2V7HHhpSF)ARJBQdn(G1UCFR70W(7g3QNMNZhNUzCH9hFwQg1ZK9sty0ck9FfOO)tLPXTRFtP(zGT(VK4XEm6A4XTeXNfW7om1nChpRlSCQRtRHI0soEEOY70Y5a9DZ(Tejhh3xl496b(cXT3VdmeC(fzAu7One99nkqNiAS)a6BkQ95)1p6972f1oXUUx0A84TBx4fb6VtNKwG73N8EQRcj7uJVxFsG(liv1m6UDxoWyGzxFhGwhQ1xdWxvQdvKVKp0ZFrsWGLfTggRuSJ))p]] )
