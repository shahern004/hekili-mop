-- HunterSurvival_Simple.lua
-- Minimal test version with just basic abilities

if UnitClassBase( "player" ) ~= "HUNTER" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local spec = Hekili:NewSpecialization( 255 )

-- Focus resource
spec:RegisterResource( Enum.PowerType.Focus )

-- Minimal abilities that should always work
spec:RegisterAbilities( {
    -- Auto Attack - this should always be available
    auto_attack = {
        id = 1,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = true,
        
        usable = function() return true end,
        known = function() return true end,
        
        handler = function()
            -- Auto attack
        end,
    },
    
    -- Hunter's Mark - basic utility
    hunters_mark = {
        id = 1130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        usable = function() return true end,
        known = function() return true end,
        
        handler = function()
            applyDebuff( "target", "hunters_mark", 300 )
        end,
    },
    
    -- Aspect of the Hawk - basic buff
    aspect_of_the_hawk = {
        id = 13165,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        usable = function() return true end,
        known = function() return true end,
        
        handler = function()
            applyBuff( "aspect_of_the_hawk" )
        end,
    },
} )

-- Force copy essential shared abilities
C_Timer.After(1, function()
    print("DEBUG: [Simple] Adding essential shared abilities...")
    
    -- Manually add the most basic shared abilities
    spec.abilities.call_action_list = {
        name = "|cff00ccff[Call Action List]|r",
        listName = '|T136243:0|t |cff00ccff[Call Action List]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        usable = function() return true end,
        known = function() return true end,
    }
    
    spec.abilities.wait = {
        name = "|cff00ccff[Wait]|r",
        listName = '|T136243:0|t |cff00ccff[Wait]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        usable = function() return true end,
        known = function() return true end,
    }
    
    print("DEBUG: [Simple] Added call_action_list and wait manually")
    print("DEBUG: [Simple] Testing ability availability:")
    
    for name, ability in pairs(spec.abilities) do
        local isUsable = ability.usable and ability.usable() or true
        local isKnown = ability.known and ability.known() or true
        print("DEBUG: [Simple]", name, "- usable:", isUsable, "known:", isKnown)
    end
end)

spec:RegisterPack( "SurvivalSimple", 20250618, [[Simple test pack for debugging MoP Survival Hunter.]] )
