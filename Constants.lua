-- Constants.lua
-- June 2014

local addon, ns = ...
local Hekili = _G[ addon ]


-- Class Localization
ns.getLocalClass = function ( class )
    if not ns.player.sex then ns.player.sex = UnitSex( "player" ) end
    return ns.player.sex == 1 and LOCALIZED_CLASS_NAMES_MALE[ class ] or LOCALIZED_CLASS_NAMES_FEMALE[ class ]
end


local InverseDirection = {
    LEFT = "RIGHT",
    RIGHT = "LEFT",
    TOP = "BOTTOM",
    BOTTOM = "TOP"
}

ns.getInverseDirection = function ( dir )

    return InverseDirection[ dir ] or dir

end


local ClassIDs = {}

for i = 1, GetNumClasses() do
    local _, classTag = GetClassInfo( i )
    if classTag then ClassIDs[ classTag ] = i end
end

ns.getClassID = function( class )
    return ClassIDs[ class ] or -1
end


local ResourceInfo = {
    -- health       = Enum.PowerType.HealthCost,
    none            = Enum.PowerType.None,
    mana            = Enum.PowerType.Mana,
    rage            = Enum.PowerType.Rage,
    focus           = Enum.PowerType.Focus,
    energy          = Enum.PowerType.Energy,
    combo_points    = Enum.PowerType.ComboPoints,
    runes           = Enum.PowerType.Runes,
    runic_power     = Enum.PowerType.RunicPower,
    soul_shards     = Enum.PowerType.SoulShards,
    astral_power    = Enum.PowerType.LunarPower,
    holy_power      = Enum.PowerType.HolyPower,
    alternate       = Enum.PowerType.Alternate,
    maelstrom       = Enum.PowerType.Maelstrom,
    chi             = Enum.PowerType.Chi,
    insanity        = Enum.PowerType.Insanity,
    obsolete        = Enum.PowerType.Obsolete,
    obsolete2       = Enum.PowerType.Obsolete2,
    arcane_charges  = Enum.PowerType.ArcaneCharges,
    fury            = Enum.PowerType.Fury,
    pain            = Enum.PowerType.Pain,
    essence         = Enum.PowerType.Essence,
    blood_runes     = Enum.PowerType.RuneBlood,
    frost_runes     = Enum.PowerType.RuneFrost,
    unholy_runes    = Enum.PowerType.RuneUnholy,
}

local ResourceByID = {}

for k, powerType in pairs( ResourceInfo ) do
    ResourceByID[ powerType ] = k
end


function ns.GetResourceInfo()
    return ResourceInfo
end


function ns.GetResourceID( key )
    return ResourceInfo[ key ]
end


function ns.GetResourceKey( id )
    return ResourceByID[ id ]
end


local passive_regen = {
    mana = 1,
    focus = 1,
    energy = 1,
    essence = 1
}

function ns.ResourceRegenerates( key )
    -- Does this resource have a passive gain from waiting?
    if passive_regen[ key ] then return true end
    return false
end

-- Primary purpose of this table is to store information we know about a spec, but is not directly retrieveable via API calls in-game.
ns.Specializations = {
    [250] = {
        key = "blood",
        class = "DEATHKNIGHT",
        ranged = false
    },
    [251] = {
        key = "frost",
        class = "DEATHKNIGHT",
        ranged = false
    },
    [252] = {
        key = "unholy",
        class = "DEATHKNIGHT",
        ranged = false
    },
    [102] = {
        key = "balance",
        class = "DRUID",
        ranged = true
    },
    [103] = {
        key = "feral",
        class = "DRUID",
        ranged = false
    },
    [104] = {
        key = "guardian",
        class = "DRUID",
        ranged = false
    },
    [105] = {
        key = "restoration",
        class = "DRUID",
        ranged = true
    },
    [253] = {
        key = "beast_mastery",
        class = "HUNTER",
        ranged = true
    },
    [255] = {
        key = "survival",
        class = "HUNTER",
        ranged = true
    },
    [254] = {
        key = "marksmanship",
        class = "HUNTER",
        ranged = true
    },
    [62] = {
        key = "arcane",
        class = "MAGE",
        ranged = true
    },
    [63] = {
        key = "fire",
        class = "MAGE",
        ranged = true
    },
    [64] = {
        key = "frost",
        class = "MAGE",
        ranged = true
    },
    [268] = {
        key = "brewmaster",
        class = "MONK",
        ranged = false
    },
    [269] = {
        key = "windwalker",
        class = "MONK",
        ranged = false
    },
    [270] = {
        key = "mistweaver",
        class = "MONK",
        ranged = false
    },
    [65] = {
        key = "holy",
        class = "PALADIN",
        ranged = false
    },
    [66] = {
        key = "protection",
        class = "PALADIN",
        ranged = false
    },
    [70] = {
        key = "retribution",
        class = "PALADIN",
        ranged = false
    },
    [256] = {
        key = "discipline",
        class = "PRIEST",
        ranged = true
    },
    [257] = {
        key = "holy",
        class = "PRIEST",
        ranged = true
    },
    [258] = {
        key = "shadow",
        class = "PRIEST",
        ranged = true
    },
    [259] = {
        key = "assassination",
        class = "ROGUE",
        ranged = false
    },
    [260] = {
        key = "combat",
        class = "ROGUE",
        ranged = false
    },
    [261] = {
        key = "subtlety",
        class = "ROGUE",
        ranged = false
    },
    [262] = {
        key = "elemental",
        class = "SHAMAN",
        ranged = true
    },
    [263] = {
        key = "enhancement",
        class = "SHAMAN",
        ranged = false
    },
    [264] = {
        key = "restoration",
        class = "SHAMAN",
        ranged = true
    },
    [265] = {
        key = "affliction",
        class = "WARLOCK",
        ranged = true
    },
    [266] = {
        key = "demonology",
        class = "WARLOCK",
        ranged = true
    },
    [267] = {
        key = "destruction",
        class = "WARLOCK",
        ranged = true
    },
    [71] = {
        key = "arms",
        class = "WARRIOR",
        ranged = false
    },
    [72] = {
        key = "fury",
        class = "WARRIOR",
        ranged = false
    },
    [73] = {
        key = "protection",
        class = "WARRIOR",
        ranged = false
    },

}

ns.getSpecializationKey = function ( id )
    local spec = ns.Specializations[ id ]
    return spec and spec.key or "none"
end

ns.getSpecializationID = function ( index )
    -- MoP Classic version using spell-based detection for all classes
    -- This is much more reliable than spec index mapping
    local playerClass = select(2, UnitClass("player"))
    
    -- Get current active spec group (dual spec support)
    local activeSpecGroup = GetActiveSpecGroup and GetActiveSpecGroup() or 1
    local selectedSpec = index or (GetSpecialization and GetSpecialization(false, false, activeSpecGroup)) or 1
    
    print("DEBUG: Spell-based detection - Active Spec Group=" .. activeSpecGroup .. ", Selected Spec=" .. selectedSpec .. ", Class=" .. playerClass)
    
    -- Spell-based detection for all classes
    -- This checks signature spells that are unique to each specialization
    
    if playerClass == "HUNTER" then
        -- Hunter specializations based on signature spells
        if IsSpellKnown(53301) then -- Explosive Shot = Survival
            print("DEBUG: Detected Hunter Survival via Explosive Shot")
            return 255
        elseif IsSpellKnown(34026) then -- Kill Command = Beast Mastery
            print("DEBUG: Detected Hunter Beast Mastery via Kill Command")
            return 253
        elseif IsSpellKnown(19434) then -- Aimed Shot = Marksmanship (fallback)
            print("DEBUG: Detected Hunter Marksmanship via Aimed Shot")
            return 254
        end
        
    elseif playerClass == "DEATHKNIGHT" then
        -- Death Knight specializations
        if IsSpellKnown(45462) then -- Plague Strike (Blood)
            return 250
        elseif IsSpellKnown(49020) then -- Obliterate (Frost)
            return 251
        elseif IsSpellKnown(85948) then -- Festering Strike (Unholy)
            return 252
        end
        
    elseif playerClass == "DRUID" then
        -- Druid specializations
        if IsSpellKnown(78674) then -- Starsurge (Balance)
            return 102
        elseif IsSpellKnown(22568) then -- Ferocious Bite (Feral)
            return 103
        elseif IsSpellKnown(33745) then -- Lacerate (Guardian/Feral Tank)
            return 104
        elseif IsSpellKnown(18562) then -- Swiftmend (Restoration)
            return 105
        end
        
    elseif playerClass == "MAGE" then
        -- Mage specializations
        if IsSpellKnown(44425) then -- Arcane Orb (Arcane)
            return 62
        elseif IsSpellKnown(11366) then -- Pyroblast (Fire)
            return 63
        elseif IsSpellKnown(30455) then -- Ice Lance (Frost)
            return 64
        end
        
    elseif playerClass == "MONK" then
        -- Monk specializations
        if IsSpellKnown(115295) then -- Guard (Brewmaster)
            return 268
        elseif IsSpellKnown(101546) then -- Spinning Crane Kick (Windwalker)
            return 269
        elseif IsSpellKnown(115151) then -- Renewing Mist (Mistweaver)
            return 270
        end
        
    elseif playerClass == "PALADIN" then
        -- Paladin specializations
        if IsSpellKnown(20473) then -- Holy Shock (Holy)
            return 65
        elseif IsSpellKnown(31935) then -- Avenger's Shield (Protection)
            return 66
        elseif IsSpellKnown(85256) then -- Templar's Verdict (Retribution)
            return 70
        end
        
    elseif playerClass == "PRIEST" then
        -- Priest specializations
        if IsSpellKnown(47540) then -- Penance (Discipline)
            return 256
        elseif IsSpellKnown(88625) then -- Holy Word: Chastise (Holy)
            return 257
        elseif IsSpellKnown(8092) then -- Mind Blast (Shadow)
            return 258
        end
        
    elseif playerClass == "ROGUE" then
        -- Rogue specializations
        if IsSpellKnown(79140) then -- Vendetta (Assassination)
            return 259
        elseif IsSpellKnown(13750) then -- Adrenaline Rush (Combat)
            return 260
        elseif IsSpellKnown(36554) then -- Shadowstep (Subtlety)
            return 261
        end
        
    elseif playerClass == "SHAMAN" then
        -- Shaman specializations
        if IsSpellKnown(51505) then -- Lava Burst (Elemental)
            return 262
        elseif IsSpellKnown(17364) then -- Stormstrike (Enhancement)
            return 263
        elseif IsSpellKnown(61295) then -- Riptide (Restoration)
            return 264
        end
        
    elseif playerClass == "WARLOCK" then
        -- Warlock specializations
        if IsSpellKnown(30108) then -- Unstable Affliction (Affliction)
            return 265
        elseif IsSpellKnown(30146) then -- Summon Felguard (Demonology)
            return 266
        elseif IsSpellKnown(17962) then -- Conflagrate (Destruction)
            return 267
        end
        
    elseif playerClass == "WARRIOR" then
        -- Warrior specializations
        if IsSpellKnown(12294) then -- Mortal Strike (Arms)
            return 71
        elseif IsSpellKnown(23881) then -- Bloodthirst (Fury)
            return 72
        elseif IsSpellKnown(23922) then -- Shield Slam (Protection)
            return 73
        end
    end
    
    -- Fallback: Try basic spec index mapping if spell detection fails
    print("DEBUG: Spell detection failed for " .. playerClass .. ", using fallback")
    
    -- Basic fallback mapping for MoP Classic
    local fallbackMapping = {
        HUNTER = { [1] = 253, [2] = 254, [3] = 255 },       -- Beast Mastery, Marksmanship, Survival
        DEATHKNIGHT = { [1] = 250, [2] = 251, [3] = 252 },  -- Blood, Frost, Unholy
        DRUID = { [1] = 102, [2] = 103, [3] = 104, [4] = 105 }, -- Balance, Feral, Guardian, Restoration
        MAGE = { [1] = 62, [2] = 63, [3] = 64 },            -- Arcane, Fire, Frost
        MONK = { [1] = 268, [2] = 269, [3] = 270 },         -- Brewmaster, Windwalker, Mistweaver
        PALADIN = { [1] = 65, [2] = 66, [3] = 70 },         -- Holy, Protection, Retribution
        PRIEST = { [1] = 256, [2] = 257, [3] = 258 },       -- Discipline, Holy, Shadow
        ROGUE = { [1] = 259, [2] = 260, [3] = 261 },        -- Assassination, Combat, Subtlety
        SHAMAN = { [1] = 262, [2] = 263, [3] = 264 },       -- Elemental, Enhancement, Restoration
        WARLOCK = { [1] = 265, [2] = 266, [3] = 267 },      -- Affliction, Demonology, Destruction
        WARRIOR = { [1] = 71, [2] = 72, [3] = 73 }          -- Arms, Fury, Protection
    }
    
    if fallbackMapping[playerClass] and fallbackMapping[playerClass][selectedSpec] then
        print("DEBUG: Using fallback mapping for " .. playerClass .. " spec " .. selectedSpec)
        return fallbackMapping[playerClass][selectedSpec]
    end
    
    return 0  -- Complete fallback
end




ns.PvpDummies = {
    [67229] = true,   -- Training Dummy (Level 93 Elite - MoP)
    [46647] = true,   -- Training Dummy (Level 85 - Cataclysm)
    [31146] = true,   -- Raider's Training Dummy (Level 80)
    [32666] = true,   -- Training Dummy
    [32667] = true    -- Training Dummy
}

ns.TargetDummies = {
    [   4952 ] = "Theramore Combat Dummy",
    [   5652 ] = "Undercity Combat Dummy",
    [  25225 ] = "Practice Dummy",
    [  25297 ] = "Drill Dummy",
    [  31144 ] = "Training Dummy",
    [  31146 ] = "Raider's Training Dummy",
    [  32541 ] = "Initiate's Training Dummy",
    [  32543 ] = "Veteran's Training Dummy",
    [  32546 ] = "Ebon Knight's Training Dummy",
    [  32542 ] = "Disciple's Training Dummy",
    [  32545 ] = "Training Dummy",
    [  32666 ] = "Training Dummy",
    [  32667 ] = "Training Dummy",
    [  44171 ] = "Training Dummy",
    [  44548 ] = "Training Dummy",
    [  44389 ] = "Training Dummy",
    [  44614 ] = "Training Dummy",
    [  44703 ] = "Training Dummy",
    [  44794 ] = "Training Dummy",
    [  44820 ] = "Training Dummy",
    [  44848 ] = "Training Dummy",
    [  44937 ] = "Training Dummy",
    [  46647 ] = "Training Dummy",
    [  48304 ] = "Training Dummy",
    [  60197 ] = "Training Dummy",
    [  64446 ] = "Training Dummy",
    [  67127 ] = "Training Dummy",
    [  70245 ] = "Training Dummy",
}


ns.FrameStratas = {
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "FULLSCREEN",
    "FULLSCREEN_DIALOG",
    "TOOLTIP",

    BACKGROUND = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    DIALOG = 5,
    FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8
}