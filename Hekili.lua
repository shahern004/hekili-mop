-- Hekili.lua
-- July 2024

local addon, ns = ...

-- MoP API compatibility - Set up early for libraries
if not _G.GetSpecialization then
    _G.GetSpecialization = _G.GetActiveTalentGroup or function() return 1 end
end

if not _G.GetSpecializationInfo then
    _G.GetSpecializationInfo = function(specIndex)
        -- In MoP, there are typically 2-4 specs per class
        -- Return nil for invalid indices to prevent infinite loops
        if not specIndex or specIndex < 1 then
            return nil
        end
        
        local _, class = UnitClass("player")
        if not class then
            return nil
        end
        
        -- Return basic spec info based on index
        local specNames = {
            ["WARRIOR"] = { "Arms", "Fury", "Protection" },
            ["PALADIN"] = { "Holy", "Protection", "Retribution" },
            ["HUNTER"] = { "Beast Mastery", "Marksmanship", "Survival" },
            ["ROGUE"] = { "Assassination", "Combat", "Subtlety" },
            ["PRIEST"] = { "Discipline", "Holy", "Shadow" },
            ["DEATHKNIGHT"] = { "Blood", "Frost", "Unholy" },
            ["SHAMAN"] = { "Elemental", "Enhancement", "Restoration" },
            ["MAGE"] = { "Arcane", "Fire", "Frost" },
            ["WARLOCK"] = { "Affliction", "Demonology", "Destruction" },
            ["MONK"] = { "Brewmaster", "Mistweaver", "Windwalker" },
            ["DRUID"] = { "Balance", "Feral", "Guardian", "Restoration" }
        }
        
        local classSpecs = specNames[class]
        if not classSpecs or specIndex > #classSpecs then
            return nil
        end
        
        -- Return: specID, name, description, icon, role, class
        return specIndex, classSpecs[specIndex], classSpecs[specIndex], nil, nil, class
    end
end

if not _G.CanPlayerUseTalentSpecUI then
    _G.CanPlayerUseTalentSpecUI = function() return true end
end

Hekili = LibStub("AceAddon-3.0"):NewAddon( "Hekili", "AceConsole-3.0", "AceSerializer-3.0" )

-- MoP compatibility - simple version detection
Hekili.Version = "v5.4.0-1.0.0-MoP"
Hekili.Flavor = "MoP"

local format = string.format
local insert, concat = table.insert, table.concat

-- MoP API compatibility
local GetBuffDataByIndex = function(unit, index)
    local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
          nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
          nameplateShowAll, timeMod = UnitBuff(unit, index)
    if name then
        return {
            name = name,
            icon = icon,
            applications = count or 1,
            dispelType = debuffType,
            duration = duration or 0,
            expirationTime = expirationTime or 0,
            sourceUnit = source,
            isStealable = isStealable,
            nameplateShowPersonal = nameplateShowPersonal,
            spellId = spellId,
            canApplyAura = canApplyAura,
            isBossAura = isBossDebuff,
            isFromPlayerOrPlayerPet = castByPlayer,
            nameplateShowAll = nameplateShowAll,
            timeMod = timeMod
        }
    end
end

local GetDebuffDataByIndex = function(unit, index)
    local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
          nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
          nameplateShowAll, timeMod = UnitDebuff(unit, index)
    if name then
        return {
            name = name,
            icon = icon,
            applications = count or 1,
            dispelType = debuffType,
            duration = duration or 0,
            expirationTime = expirationTime or 0,
            sourceUnit = source,
            isStealable = isStealable,
            nameplateShowPersonal = nameplateShowPersonal,
            spellId = spellId,
            canApplyAura = canApplyAura,
            isBossAura = isBossDebuff,
            isFromPlayerOrPlayerPet = castByPlayer,
            nameplateShowAll = nameplateShowAll,
            timeMod = timeMod
        }
    end
end

-- MoP doesn't have UnpackAuraData, so we create a compatibility function
local UnpackAuraData = function(auraData)
    if type(auraData) == "table" then
        return auraData.name, auraData.icon, auraData.applications, auraData.dispelType,
               auraData.duration, auraData.expirationTime, auraData.sourceUnit, auraData.isStealable,
               auraData.nameplateShowPersonal, auraData.spellId, auraData.canApplyAura,
               auraData.isBossAura, auraData.isFromPlayerOrPlayerPet, auraData.nameplateShowAll,
               auraData.timeMod
    end
end

-- MoP AuraUtil compatibility
if not AuraUtil then
    AuraUtil = {}
    AuraUtil.ForEachAura = function(unit, filter, maxCount, func)
        local i = 1
        while true do
            local name, icon, count, dispelType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod
            
            if filter == "HELPFUL" then
                name, icon, count, dispelType, duration, expirationTime, source, isStealable, 
                nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                nameplateShowAll, timeMod = UnitBuff(unit, i)
            else
                name, icon, count, dispelType, duration, expirationTime, source, isStealable, 
                nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                nameplateShowAll, timeMod = UnitDebuff(unit, i)
            end
            
            if not name then break end
            
            local aura = {
                name = name,
                icon = icon,
                applications = count or 1,
                dispelType = dispelType,
                duration = duration or 0,
                expirationTime = expirationTime or 0,
                sourceUnit = source,
                isStealable = isStealable,
                nameplateShowPersonal = nameplateShowPersonal,
                spellId = spellId,
                canApplyAura = canApplyAura,
                isBossAura = isBossDebuff,
                isFromPlayerOrPlayerPet = castByPlayer,
                nameplateShowAll = nameplateShowAll,
                timeMod = timeMod
            }
            
            func(aura)
            i = i + 1
            
            if maxCount and i > maxCount then break end
        end
    end
end

local buildStr, _, _, buildNum = GetBuildInfo()

-- MoP compatibility: Set proper build number for MoP
if not buildNum or buildNum < 50000 then
    buildNum = 18414 -- MoP 5.4.8 build number
    buildStr = "5.4.8"
end

Hekili.CurrentBuild = buildNum

if Hekili.Version == ( "@" .. "project-version" .. "@" ) then
    Hekili.Version = format( "Dev-%s (%s)", buildStr, date( "%Y%m%d" ) )
    Hekili.IsDev = true
end

Hekili.AllowSimCImports = true

Hekili.IsRetail = function()
    return false
end

Hekili.IsWrath = function()
    return false
end

Hekili.IsClassic = function()
    return true
end

Hekili.IsMoP = function()
    return true
end

Hekili.IsDragonflight = function()
    return false
end

Hekili.BuiltFor = 50400
Hekili.GameBuild = buildStr

ns.PTR = false
Hekili.IsPTR = ns.PTR

ns.Patrons = "|cFFFFD100Current Status|r\n\n"
    .. "All existing specializations are currently supported, though healer priorities are experimental and focused on rotational DPS only.\n\n"
    .. "If you find odd recommendations or other issues, please follow the |cFFFFD100Report Issue|r link below and submit all the necessary information to have your issue investigated.\n\n"
    .. "Please |cffff0000do not|r submit tickets for routine priority updates (i.e., from SimulationCraft). They are routinely updated."

do
    local cpuProfileDB = {}

    function Hekili:ProfileCPU( name, func )
        cpuProfileDB[ name ] = func
    end

	ns.cpuProfile = cpuProfileDB

	local frameProfileDB = {}

	function Hekili:ProfileFrame( name, f )
		frameProfileDB[ name ] = f
	end

	ns.frameProfile = frameProfileDB
end


ns.lib = {
    Format = {}
}


-- 04072017:  Let's go ahead and cache aura information to reduce overhead.
ns.auras = {
    target = {
        buff = {},
        debuff = {}
    },
    player = {
        buff = {},
        debuff = {}
    }
}

Hekili.Class = {
    specs = {},
    num = 0,

    file = "NONE",
    initialized = false,

	resources = {},
	resourceAuras = {},
    talents = {},
    pvptalents = {},
	auras = {},
	auraList = {},
    powers = {},
	gear = {},
    setBonuses = {},

	knownAuraAttributes = {},

    stateExprs = {},
    stateFuncs = {},
    stateTables = {},

	abilities = {},
	abilityByName = {},
    abilityList = {},
    itemList = {},
    itemMap = {},
    itemPack = {
        lists = {
            items = {}
        }
    },

    packs = {},

    pets = {},
    totems = {},

    potions = {},
    potionList = {},

	hooks = {},
    range = 8,
	settings = {},
    stances = {},
	toggles = {},
	variables = {},
}
local class = Hekili.Class

Hekili.Scripts = {
    DB = {},
    Channels = {},
    PackInfo = {},
}

Hekili.State = {}

ns.hotkeys = {}
ns.keys = {}
ns.queue = {}
ns.targets = {}
ns.TTD = {}

ns.UI = {
    Displays = {},
    Buttons = {}
}

ns.debug = {}
ns.snapshots = {}


function Hekili:Query( ... )
	local output = ns

	for i = 1, select( '#', ... ) do
		output = output[ select( i, ... ) ]
    end

    return output
end


function Hekili:Run( ... )
	local n = select( "#", ... )
	local fn = select( n, ... )

	local func = ns

	for i = 1, fn - 1 do
		func = func[ select( i, ... ) ]
    end

    return func( select( fn, ... ) )
end


local debug = ns.debug
local active_debug
local current_display

local lastIndent = 0

function Hekili:SetupDebug( display )
    if not self.ActiveDebug then return end
    if not display then return end

    current_display = display

    debug[ current_display ] = debug[ current_display ] or {
        log = {},
        index = 1
    }
    active_debug = debug[ current_display ]
	active_debug.index = 1

	lastIndent = 0

	local pack = self.State.system.packName

    if not pack then return end

	self:Debug( "New Recommendations for [ %s ] requested at %s ( %.2f ); using %s( %s ) priority.", display, date( "%H:%M:%S"), GetTime(), self.DB.profile.packs[ pack ].builtIn and "built-in " or "", pack )
end


function Hekili:Debug( ... )
    if not self.ActiveDebug then return end
	if not active_debug then return end

	local indent, text = ...
	local start

	if type( indent ) ~= "number" then
		indent = lastIndent
		text = ...
		start = 2
	else
		lastIndent = indent
		start = 3
	end

	local prepend = format( indent > 0 and ( "%" .. ( indent * 4 ) .. "s" ) or "%s", "" )
	text = text:gsub("\n", "\n" .. prepend )
    text = format( "%" .. ( indent > 0 and ( 4 * indent ) or "" ) .. "s", "" ) .. text

    if select( start, ... ) ~= nil then
	    active_debug.log[ active_debug.index ] = format( text, select( start, ... ) )
    else
        active_debug.log[ active_debug.index ] = text
    end
    active_debug.index = active_debug.index + 1
end


local snapshots = ns.snapshots
local hasScreenshotted = false

function Hekili:SaveDebugSnapshot( dispName )
    local snapped = false
    local formatKey = ns.formatKey
    local state = Hekili.State

	for k, v in pairs( debug ) do
		if not dispName or dispName == k then
			for i = #v.log, v.index, -1 do
				v.log[ i ] = nil
			end

            -- Store previous spell data.
            local prevString = "\nprevious_spells:"

            -- Skip over the actions in the "prev" table that were added to computed the next recommended ability in the queue.
            local i, j = ( #state.predictions + 1 ), 1
            local spell = state.prev[i].spell or "no_action"

            if spell == "no_action" then
                prevString = prevString .. "  no history available"
            else
                local numHistory = #state.prev.history
                while i <= numHistory and spell ~= "no_action" do
                    prevString = format( "%s\n   %d - %s", prevString, j, spell )
                    i, j = i + 1, j + 1
                    spell = state.prev[i].spell or "no_action"
                end
            end
            prevString = prevString .. "\n\n"

            insert( v.log, 1, prevString )

            -- Store aura data.
            local auraString = "\n### Auras ###\n"

            local now = GetTime()
            local playerBuffs = {}
            local pbOrder = {}

            local longestKey, longestName = 0, 0

            AuraUtil.ForEachAura( "player", "HELPFUL", nil, function( aura )
                if aura.isFromPlayerOrPlayerPet then
                    local model = class.auras[ aura.spellId ]
                    local key = model and model.key or formatKey( aura.name )

                    local offset = 0
                    local newKey = key

                    while( playerBuffs[ newKey ] ) do
                        offset = offset + 1
                        newKey = format( "%s_%d", key, offset )
                    end

                    if newKey ~= key then key = newKey end

                    pbOrder[ #pbOrder + 1 ] = key
                    longestKey = max( longestKey, key:len() )
                    longestName = max( longestName, aura.name:len() )

                    playerBuffs[ key ] = {}
                    local elem = playerBuffs[ key ]

                    elem.spellId = aura.spellId
                    elem.key = key
                    elem.name = aura.name

                    elem.count = aura.applications > 0 and aura.applications or 1
                    elem.remains = aura.expirationTime > 0 and ( aura.expirationTime - now ) or 3600

                    local scraped = state.auras.player.buff[ model and model.key or key ]
                    if scraped and scraped.applied > 0 then
                        elem.sCount = scraped.count > 0 and scraped.count or 1
                        elem.sRemains = scraped.expires > 0 and ( scraped.expires - now ) or 3600
                    end
                end
            end, true )

            for token, caught in pairs( state.auras.player.buff ) do
                if not playerBuffs[ token ] and caught.expires > 0 then
                    playerBuffs[ token ] = {
                        spellId = caught.id,
                        key = caught.key,
                        name = "",

                        count = 0,
                        remains = 0,

                        sCount = caught.count > 0 and caught.count or 1,
                        sRemains = caught.expires > 0 and ( caught.expires - now ) or 3600
                    }

                    pbOrder[ #pbOrder + 1 ] = token
                    longestKey = max( longestKey, token:len() )
                end
            end

            sort( pbOrder )


            local playerDebuffs = {}
            local pdOrder = {}

            AuraUtil.ForEachAura( "player", "HARMFUL", nil, function( aura )
                local model = class.auras[ aura.spellId ]
                local key = model and model.key or formatKey( aura.name )

                local offset = 0
                local newKey = key

                while( playerDebuffs[ newKey ] ) do
                    offset = offset + 1
                    newKey = format( "%s_%d", key, offset )
                end
                if newKey ~= key then key = newKey end

                pdOrder[ #pdOrder + 1 ] = key
                longestKey = max( longestKey, key:len() )
                longestName = max( longestName, aura.name:len() )

                playerDebuffs[ key ] = {}
                local elem = playerDebuffs[ key ]

                elem.spellId = aura.spellId
                elem.key = key
                elem.name = aura.name

                elem.count = aura.applications > 0 and aura.applications or 1
                elem.remains = aura.expirationTime > 0 and ( aura.expirationTime - now ) or 3600

                local scraped = state.auras.player.debuff[ model and model.key or key ]
                if scraped and scraped.applied > 0 then
                    elem.sCount = scraped.count > 0 and scraped.count or 1
                    elem.sRemains = scraped.expires > 0 and ( scraped.expires - now ) or 3600
                end
            end, true )

            for token, caught in pairs( state.auras.player.debuff ) do
                if not playerDebuffs[ token ] and caught.expires > 0 then
                    playerDebuffs[ token ] = {
                        spellId = caught.id,
                        key = caught.key,
                        name = "",

                        count = 0,
                        remains = 0,

                        sCount = caught.count > 0 and caught.count or 1,
                        sRemains = caught.expires > 0 and ( caught.expires - now ) or 3600
                    }

                    pdOrder[ #pdOrder + 1 ] = token
                    longestKey = max( longestKey, token:len() )
                end
            end

            sort( pdOrder )


            local targetBuffs = {}
            local tbOrder = {}

            AuraUtil.ForEachAura( "target", "HELPFUL", nil, function( aura )
                local model = class.auras[ aura.spellId ]
                local key = model and model.key or formatKey( aura.name )

                local offset = 0
                local newKey = key

                while( targetBuffs[ newKey ] ) do
                    offset = offset + 1
                    newKey = format( "%s_%d", key, offset )
                end
                if newKey ~= key then key = newKey end

                tbOrder[ #tbOrder + 1 ] = key
                longestKey = max( longestKey, key:len() )
                longestName = max( longestName, aura.name:len() )

                targetBuffs[ key ] = {}
                local elem = targetBuffs[ key ]

                elem.spellId = aura.spellId
                elem.key = key
                elem.name = aura.name

                elem.count = aura.applications > 0 and aura.applications or 1
                elem.remains = aura.expirationTime > 0 and ( aura.expirationTime - now ) or 3600

                local scraped = state.auras.target.buff[ model and model.key or key ]
                if scraped and scraped.applied > 0 then
                    elem.sCount = scraped.count > 0 and scraped.count or 1
                    elem.sRemains = scraped.expires > 0 and ( scraped.expires - now ) or 3600
                end
            end, true )

            for token, caught in pairs( state.auras.target.buff ) do
                if not targetBuffs[ token ] and caught.expires > 0 then
                    targetBuffs[ token ] = {
                        spellId = caught.id,
                        key = caught.key,
                        name = "",

                        count = 0,
                        remains = 0,

                        sCount = caught.count > 0 and caught.count or 1,
                        sRemains = caught.expires > 0 and ( caught.expires - now ) or 3600
                    }

                    tbOrder[ #tbOrder + 1 ] = token
                    longestKey = max( longestKey, token:len() )
                end
            end

            sort( tbOrder )


            local targetDebuffs = {}
            local tdOrder = {}

            AuraUtil.ForEachAura( "target", "HARMFUL", nil, function( aura )
                if aura.isFromPlayerOrPlayerPet then
                    local model = class.auras[ aura.spellId ]
                    local key = model and model.key or formatKey( aura.name )

                    local offset = 0
                    local newKey = key

                    while( targetDebuffs[ newKey ] ) do
                        offset = offset + 1
                        newKey = format( "%s_%d", key, offset )
                    end
                    if newKey ~= key then key = newKey end

                    tdOrder[ #tdOrder + 1 ] = key
                    longestKey = max( longestKey, key:len() )
                    longestName = max( longestName, aura.name:len() )

                    targetDebuffs[ key ] = {}
                    local elem = targetDebuffs[ key ]

                    elem.spellId = aura.spellId
                    elem.key = key
                    elem.name = aura.name

                    elem.count = aura.applications > 0 and aura.applications or 1
                    elem.remains = aura.expirationTime > 0 and ( aura.expirationTime - now ) or 3600

                    local scraped = state.auras.target.debuff[ model and model.key or key ]
                    if scraped and scraped.applied > 0 then
                        elem.sCount = scraped.count > 0 and scraped.count or 1
                        elem.sRemains = scraped.expires > 0 and ( scraped.expires - now ) or 3600
                    end
                end
            end, true )

            for token, caught in pairs( state.auras.target.debuff ) do
                if not targetDebuffs[ token ] and caught.expires > 0 then
                    targetDebuffs[ token ] = {
                        spellId = caught.id,
                        key = caught.key,
                        name = "",

                        count = 0,
                        remains = 0,

                        sCount = caught.count > 0 and caught.count or 1,
                        sRemains = caught.expires > 0 and ( caught.expires - now ) or 3600
                    }

                    tdOrder[ #tdOrder + 1 ] = token
                    longestKey = max( longestKey, token:len() )
                end
            end

            sort( tdOrder )

            local header = "     n  | ID      | Token" .. string.rep( " ", longestKey - 4 ) .. " | Name" .. string.rep( " ", longestName - 4 ) .. " | A. Count | A. Remains | S. Count | S. Remains\n"
                .. "    --- | ------- | " .. string.rep( "-", longestKey + 1 ) .. " | " .. string.rep( "-", longestName ) .. " | -------- | ---------- | -------- | ----------"


            if #pbOrder > 0 then
                auraString = auraString .. "\nplayer_buffs:\n" .. header

                for i, token in ipairs( pbOrder ) do
                    local aura = playerBuffs[ token ]

                    auraString = format( "%s\n     %-2d | %7d | %s%-" .. longestKey .. "s | %-" .. longestName .. "s | %8d | %10.2f | %8d | %10.2f",
                        auraString, i, class.auras[ token ] and class.auras[ token ].id or -1, ( class.auras[ token ] and " " or "*" ), token, aura.name, aura.count, aura.remains, aura.sCount or -1, aura.sRemains or - 1 )
                end

            else
                auraString = auraString .. "\nplayer_buffs: none"
            end

            if #pdOrder > 0 then
                auraString = auraString .. "\n\nplayer_debuffs:\n" .. header

                for i, token in ipairs( pdOrder ) do
                    local aura = playerDebuffs[ token ]

                    auraString = format( "%s\n     %-2d | %7d | %s%-" .. longestKey .. "s | %-" .. longestName .. "s | %8d | %10.2f | %8d | %10.2f",
                        auraString, i, class.auras[ token ] and class.auras[ token ].id or -1, ( class.auras[ token ] and " " or "*" ), token, aura.name, aura.count, aura.remains, aura.sCount or -1, aura.sRemains or - 1 )
                end
            else
                auraString = auraString .. "\n\nplayer_debuffs: none"
            end

            if #tbOrder > 0 then
                auraString = auraString .. "\n\ntarget_buffs:\n" .. header

                for i, token in ipairs( tbOrder ) do
                    local aura = targetBuffs[ token ]
                    local model = class.auras[ token ]

                    auraString = format( "%s\n     %-2d | %7d | %s%-" .. longestKey .. "s | %-" .. longestName .. "s | %8d | %10.2f | %8d | %10.2f",
                        auraString, i, model and model.id or -1, model and " " or "*", token, aura.name, aura.count, aura.remains, aura.sCount or -1, aura.sRemains or - 1 )
                end

            else
                auraString = auraString .. "\n\ntarget_buffs: none"
            end

            if #tdOrder > 0 then
                auraString = auraString .. "\n\ntarget_debuffs:\n" .. header

                for i, token in ipairs( tdOrder ) do
                    local aura = targetDebuffs[ token ]

                    auraString = format( "%s\n     %-2d | %7d | %s%-" .. longestKey .. "s | %-" .. longestName .. "s | %8d | %10.2f | %8d | %10.2f",
                        auraString, i, class.auras[ token ] and class.auras[ token ].id or -1, ( class.auras[ token ] and " " or "*" ), token, aura.name, aura.count, aura.remains, aura.sCount or -1, aura.sRemains or - 1 )
                end

            else
                auraString = auraString .. "\n\ntarget_debuffs: none"
            end


            insert( v.log, 1, auraString )
            insert( v.log, 1, "\n### Targets ###\n\ndetected_targets:  " .. ( Hekili.TargetDebug or "no data" ) )
            insert( v.log, 1, self:GenerateProfile() )


            local performance
            local pInfo = HekiliEngine.threadUpdates

            -- TODO: Include # of active displays, number of icons displayed.

            if pInfo then
                performance = string.format( "\n\nPerformance\n"
                    .. "|| Updates || Updates / sec || Avg. Work || Avg. Time || Avg. Frames || Peak Work || Peak Time || Peak Frames || FPS || Work Cap ||\n"
                    .. "|| %7d || %13.2f || %9.2f || %9.2f || %11.2f || %9.2f || %9.2f || %11.2f || %3d || %8.2f ||",
                    pInfo.updates, pInfo.updatesPerSec, pInfo.meanWorkTime, pInfo.meanClockTime, pInfo.meanFrames, pInfo.peakWorkTime, pInfo.peakClockTime, pInfo.peakFrames, GetFramerate() or 0, Hekili.maxFrameTime or 0 )
            end

            if performance then insert( v.log, performance ) end

            local custom = ""

            local pack = self.DB.profile.packs[ state.system.packName ]
            if not pack.builtIn then
                custom = format( " |cFFFFA700(*%s[%d])|r", state.spec.name, state.spec.id )
            end

            local overview = format( "%s%s; %s|r", state.system.packName, custom, dispName or state.display )
            local recs = Hekili.DisplayPool[ dispName or state.display ].Recommendations

            for i, rec in ipairs( recs ) do
                if not rec.actionName then
                    if i == 1 then
                        overview = format( "%s - |cFF666666N/A|r", overview )
                    end
                    break
                end
                overview = format( "%s%s%s|cFFFFD100(%0.2f)|r", overview, ( i == 1 and " - " or ", " ), rec.actionName, rec.time )
            end

            insert( v.log, 1, overview )

            local snap = {
                header = "|cFFFFD100[" .. date( "%H:%M:%S" ) .. "]|r " .. overview,
                log = concat( v.log, "\n" ),
                data = ns.tableCopy( v.log ),
                recs = {}
            }

            insert( snapshots, snap )
            snapped = true
		end
    end

    -- Limit screenshot to once per login.
    if snapped then
        if Hekili.DB.profile.screenshot and ( not hasScreenshotted or Hekili.ManualSnapshot ) then
            Screenshot()
            hasScreenshotted = true
        end
        return true
    end

    return false
end

Hekili.Snapshots = ns.snapshots



ns.Tooltip = CreateFrame( "GameTooltip", "HekiliTooltip", UIParent, "GameTooltipTemplate" )
Hekili:ProfileFrame( "HekiliTooltip", ns.Tooltip )

ns.db = nil -- Placeholder for AceDB

-- Initialize Hekili.DB as early as possible with a placeholder
-- This will be replaced when OnInitialize runs
Hekili.DB = { profile = { enabled = false, displays = {}, toggles = { mode = { value = "automatic" }, cooldowns = { value = true }, interrupts = { value = true }, defensives = { value = true }, potions = { value = true } }, specs = {}, notifications = { enabled = false } } }

function Hekili:OnInitialize()
    -- Initialization code
    ns.db = LibStub("AceDB-3.0"):New("HekiliDB", ns.Defaults, true)
    self.db = ns.db
    self.DB = ns.db  -- Make sure Hekili.DB is properly set
    Hekili.DB = ns.db  -- Also set the global reference

    -- Register slash commands, etc.
    self:RegisterChatCommand("hekili", "ChatCommand")

    -- Initialize other modules that depend on DB being ready
    if ns.Options and ns.Options.Initialize then
        ns.Options:Initialize()
    end

    if ns.UI and ns.UI.Initialize then  -- Ensure UI is initialized after DB
        ns.UI:Initialize()
    end

    self.initialized = true
    self:Print("Hekili Initialized for MoP!")
end

function Hekili:OnEnable()
    -- Enabling code
    if not self.initialized then self:OnInitialize() end

    if ns.Events and ns.Events.Register then
        ns.Events:Register()
    end
    
    -- Start UI updates if not paused
    if ns.UI and ns.UI.StartUpdates then
        ns.UI:StartUpdates()
    end

    self:Print("Hekili Enabled!")
end

function Hekili:OnDisable()
    -- Disabling code
    if ns.Events and ns.Events.Unregister then
        ns.Events:Unregister()
    end

    if ns.UI and ns.UI.StopUpdates then
        ns.UI:StopUpdates()
    end    self:Print("Hekili Disabled!")
end

-- Store class information but don't overwrite the Class table
Hekili.ClassName = select( 2, UnitClass( "player" ) )
Hekili.ClassIndex = select( 3, UnitClass( "player" ) )

-- Placeholder for callHook
if not callHook then
    function callHook(hookName, ...)
        -- This is a placeholder, the actual function is in Classes.lua
        -- print("Placeholder callHook:", hookName)
    end
end

-- Fallback for GetSpecialization / GetSpecializationInfo / CanPlayerUseTalentSpecUI
