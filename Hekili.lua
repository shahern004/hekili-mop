-- Hekili.lua
-- July 2024

local addon, ns = ...

-- Initialize MoP compatibility tables
ns.TargetDummies = ns.TargetDummies or {}

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

        -- Map spec indices to actual MoP spec IDs based on class and abilities
        local specID = 0
        local specName = "Unknown"

        if class == "HUNTER" then
            if IsPlayerSpell(19574) then specID = 253; specName = "Beast Mastery"  -- Bestial Wrath
            elseif IsPlayerSpell(19506) then specID = 254; specName = "Marksmanship"  -- Improved Tracking
            elseif IsPlayerSpell(53301) then specID = 255; specName = "Survival"  -- Explosive Shot
            else
                -- Fallback detection based on other abilities
                if IsPlayerSpell(34026) then specID = 253; specName = "Beast Mastery"  -- Kill Command
                elseif IsPlayerSpell(82928) then specID = 254; specName = "Marksmanship"  -- Aimed Shot
                elseif IsPlayerSpell(3674) then specID = 255; specName = "Survival"  -- Black Arrow
                else specID = 255; specName = "Survival" end -- Default to Survival
            end
        elseif class == "WARRIOR" then
            -- Add warrior detection as needed
            specID = 71; specName = "Arms"
        elseif class == "PALADIN" then
            -- Add paladin detection as needed
            specID = 70; specName = "Retribution"
        else
            specID = 1; specName = "Unknown"
        end

        -- Return: specID, name, description, icon, role, class
        return specID, specName, specName, nil, nil, class
    end
end

if not _G.CanPlayerUseTalentSpecUI then
    _G.CanPlayerUseTalentSpecUI = function() return true end
end

Hekili = LibStub("AceAddon-3.0"):NewAddon( "Hekili", "AceConsole-3.0", "AceSerializer-3.0", "AceTimer-3.0" )

-- MoP compatibility - simple version detection
Hekili.Version = "v5.5.0-1.0.0-MoP"
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

-- MoP AuraUtil compatibility - avoid conflicts with ElvUI
if _G.ElvUI then
    -- ElvUI detected - don't create global AuraUtil to avoid conflicts
    print("DEBUG: ElvUI detected - skipping global AuraUtil creation to prevent conflicts")

    -- Create internal AuraUtil for Hekili's own use only
    if not ns.AuraUtil then
        ns.AuraUtil = {}
        ns.AuraUtil.ForEachAura = function(unit, filter, maxCount, func)
            -- Internal Hekili-only aura processing
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
                    timeMod = timeMod or 1
                }

                func(aura)
                i = i + 1

                if maxCount and i > maxCount then break end
            end
        end
        print("DEBUG: Created internal ns.AuraUtil for Hekili (ElvUI compatibility mode)")
    end
else
    -- No ElvUI detected - safe to create global AuraUtil
    if not AuraUtil then
        AuraUtil = {}
        print("DEBUG: Created global AuraUtil (no ElvUI detected)")
    end

    if not AuraUtil.ForEachAura then
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
                    timeMod = timeMod or 1
                }

                func(aura)
                i = i + 1

                if maxCount and i > maxCount then break end
            end
        end
        print("DEBUG: Created global AuraUtil.ForEachAura (no ElvUI detected)")
    else
        print("DEBUG: AuraUtil.ForEachAura already exists")
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
	resourceAuras = {},    talents = {},
    pvptalents = {},
    glyphs = {},
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
    local class = Hekili.Class

	for k, v in pairs( debug ) do
		if not dispName or dispName == k then
			for i = #v.log, v.index, -1 do
				v.log[ i ] = nil
			end

            -- Store aura data using simple UnitBuff/UnitDebuff calls
            local auraString = "\nplayer_buffs:"
            local now = GetTime()

            for i = 1, 40 do
                local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitBuff( "player", i )

                if not name then break end

                local aura = class.auras[ spellId ]
                local key = aura and aura.key
                if key and state.auras and state.auras.player and state.auras.player.buff and not state.auras.player.buff[ key ] then
                    key = key .. " [MISSING]"
                end

                auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId or 0, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
            end

            auraString = auraString .. "\n\nplayer_debuffs:"

            for i = 1, 40 do
                local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitDebuff( "player", i )

                if not name then break end

                local aura = class.auras[ spellId ]
                local key = aura and aura.key
                if key and state.auras and state.auras.player and state.auras.player.debuff and not state.auras.player.debuff[ key ] then
                    key = key .. " [MISSING]"
                end

                auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId or 0, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
            end


            if not UnitExists( "target" ) then
                auraString = auraString .. "\n\ntarget_auras:  target does not exist"
            else
                auraString = auraString .. "\n\ntarget_buffs:"

                for i = 1, 40 do
                    local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitBuff( "target", i )

                    if not name then break end

                    local aura = class.auras[ spellId ]
                    local key = aura and aura.key
                    if key and state.auras and state.auras.target and state.auras.target.buff and not state.auras.target.buff[ key ] then
                        key = key .. " [MISSING]"
                    end

                    auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId or 0, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
                end

                auraString = auraString .. "\n\ntarget_debuffs:"

                for i = 1, 40 do
                    local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitDebuff( "target", i, "PLAYER" )

                    if not name then break end

                    local aura = class.auras[ spellId ]
                    local key = aura and aura.key
                    if key and state.auras and state.auras.target and state.auras.target.debuff and not state.auras.target.debuff[ key ] then
                        key = key .. " [MISSING]"
                    end

                    auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId or 0, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
                end
            end

            auraString = auraString .. "\n\n"

            insert( v.log, 1, auraString )
            if Hekili.TargetDebug and Hekili.TargetDebug:len() > 0 then
                insert( v.log, 1, "targets:\n" .. Hekili.TargetDebug )
            end
            insert( v.log, 1, self:GenerateProfile() )

            local custom = ""
            local packName = state.system and state.system.packName or "Unknown"
            local pack = self.DB and self.DB.profile and self.DB.profile.packs and self.DB.profile.packs[packName]

            if pack and not pack.builtIn then
                custom = format( " |cFFFFA700(Custom: %s[%d])|r", state.spec and state.spec.name or "Unknown", state.spec and state.spec.id or 0 )
            end

            local overview = format( "%s%s; %s|r", packName, custom, dispName or "Unknown" )
            local displayPool = Hekili.DisplayPool and Hekili.DisplayPool[dispName]
            local recs = displayPool and displayPool.Recommendations or {}

            for i, rec in ipairs( recs ) do
                if not rec.actionName then
                    if i == 1 then
                        overview = format( "%s - |cFF666666N/A|r", overview )
                    end
                    break
                end
                if not class.abilities[ rec.actionName ] then
                    if i == 1 then
                        overview = format( "%s - |cFF666666N/A|r", overview )
                    end
                    break
                end
                local abilityName = class.abilities[ rec.actionName ].name or rec.actionName or "Unknown"
                overview = format( "%s%s%s|cFFFFD100(%0.2f)|r", overview, ( i == 1 and " - " or ", " ), abilityName, rec.time or 0 )
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

    if snapped then
        if Hekili.DB.profile.screenshot then Screenshot() end
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

    -- MoP Classic: Force spec detection on enable with delay to ensure LibClassicSpecs is loaded
    C_Timer.After(2, function()
        -- Check if LibClassicSpecs is available now
        if LibClassicSpecs then
            print("DEBUG: LibClassicSpecs loaded, attempting spec detection...")
        else
            print("DEBUG: LibClassicSpecs still not loaded, using fallback detection...")
        end
        self:ForceSpecDetection()
    end)

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
local callHook = callHook
if not callHook then
    function callHook(hookName, ...)
        -- This is a placeholder, the actual function is in Classes.lua
        -- print("Placeholder callHook:", hookName)
    end
end

-- Fallback for GetSpecialization / GetSpecializationInfo / CanPlayerUseTalentSpecUI

-- MoP Classic spec detection function
function Hekili:GetMoPSpecialization()
    local _, class = UnitClass("player")
    if not class then
        return nil, nil
    end

    -- Try LibClassicSpecs first if available
    if LibClassicSpecs and LibClassicSpecs.GetSpecialization and LibClassicSpecs.GetSpecializationInfo then
        local currentSpec = LibClassicSpecs.GetSpecialization()
        if currentSpec and currentSpec > 0 then
            local specID, specName, description, icon, role, className = LibClassicSpecs.GetSpecializationInfo(currentSpec)
            if specID and specID > 0 and specName then
                print("DEBUG: LibClassicSpecs detection - specID:", specID, "specName:", specName, "role:", role)
                return specID, specName
            end
        end
    end

    -- Fallback to manual detection if LibClassicSpecs fails
    local specID = 0
    local specName = "Unknown"
      if class == "HUNTER" then
        if IsPlayerSpell(19574) then specID = 253; specName = "Beast Mastery"  -- Bestial Wrath
        elseif IsPlayerSpell(19506) then specID = 254; specName = "Marksmanship"  -- Improved Tracking
        elseif IsPlayerSpell(53301) then specID = 255; specName = "Survival"  -- Explosive Shot
        else
            -- Fallback detection based on other abilities
            if IsPlayerSpell(34026) then specID = 253; specName = "Beast Mastery"  -- Kill Command
            elseif IsPlayerSpell(82928) then specID = 254; specName = "Marksmanship"  -- Aimed Shot
            elseif IsPlayerSpell(3674) then specID = 255; specName = "Survival"  -- Black Arrow
            else specID = 255; specName = "Survival" end -- Default to Survival
        end
    elseif class == "DRUID" then
        -- Druid spec detection for MoP Classic - Prioritize specific specs first

        -- Check for Restoration-specific spells FIRST (highest priority for healers)
        if IsPlayerSpell(18562) then -- Swiftmend - Restoration specific
            specID = 105; specName = "Restoration"
        elseif IsPlayerSpell(33763) then -- Lifebloom - Restoration specific
            specID = 105; specName = "Restoration"

        -- Check for Feral-specific spells (higher priority than shared spells)
        elseif IsPlayerSpell(52610) then -- Savage Roar - Feral specific
            specID = 103; specName = "Feral"
        elseif IsPlayerSpell(22568) then -- Ferocious Bite - Feral specific
            specID = 103; specName = "Feral"
        elseif IsPlayerSpell(33876) then -- Mangle (Cat) - Feral specific
            specID = 103; specName = "Feral"
        elseif IsPlayerSpell(5221) then -- Shred - Core Feral ability
            specID = 103; specName = "Feral"
        elseif IsPlayerSpell(1822) then -- Rake - Core Feral ability
            specID = 103; specName = "Feral"

        -- Check for Guardian-specific spells
        elseif IsPlayerSpell(33878) then -- Mangle (Bear) - Guardian specific
            specID = 104; specName = "Guardian"
        elseif IsPlayerSpell(6807) then -- Maul - Guardian specific
            specID = 104; specName = "Guardian"

        -- Check for Balance-specific spells (lower priority since some are shared)
        elseif IsPlayerSpell(78674) then -- Starsurge - Balance specific
            specID = 102; specName = "Balance"
        elseif IsPlayerSpell(8921) then -- Moonfire - Available to all but assume Balance
            specID = 102; specName = "Balance"

        else
            -- If no specific spells found, try to detect based on current form or basic abilities

            -- Check if player is in Cat Form or has Cat Form ability
            if GetShapeshiftForm and (GetShapeshiftForm() == 1 or IsPlayerSpell(768)) then -- Cat Form
                specID = 103; specName = "Feral"
            elseif GetShapeshiftForm and (GetShapeshiftForm() == 2 or IsPlayerSpell(5487)) then -- Bear Form
                specID = 104; specName = "Guardian"
            -- Check for basic healing spells that suggest Restoration
            elseif IsPlayerSpell(5185) then -- Healing Touch - Available to Restoration
                specID = 105; specName = "Restoration"
            elseif IsPlayerSpell(774) then -- Rejuvenation - Available to Restoration
                specID = 105; specName = "Restoration"
            -- Check for Balance spells
            elseif IsPlayerSpell(5176) then -- Wrath - Balance spell
                specID = 102; specName = "Balance"
            else
                -- Last resort: check talent group or default to Feral
                local activeGroup = GetActiveTalentGroup and GetActiveTalentGroup() or 1
                specID = 103; specName = "Feral" -- Default to Feral for Druids
            end
        end
    elseif class == "ROGUE" then
        -- Rogue spec detection for MoP Classic - Check for spec-specific abilities first
        if IsPlayerSpell(13750) then -- Adrenaline Rush - Combat specific
            specID = 260; specName = "Combat"
        elseif IsPlayerSpell(51690) then -- Killing Spree - Combat specific
            specID = 260; specName = "Combat"
        elseif IsPlayerSpell(13877) then -- Blade Flurry - Combat specific
            specID = 260; specName = "Combat"
        elseif IsPlayerSpell(84617) then -- Revealing Strike - Combat specific
            specID = 260; specName = "Combat"
        elseif IsPlayerSpell(79140) then -- Vendetta - Assassination specific
            specID = 259; specName = "Assassination"
        elseif IsPlayerSpell(14177) then -- Cold Blood - Assassination specific
            specID = 259; specName = "Assassination"
        elseif IsPlayerSpell(51713) then -- Shadow Dance - Subtlety specific
            specID = 261; specName = "Subtlety"
        elseif IsPlayerSpell(36554) then -- Shadowstep - Subtlety specific
            specID = 261; specName = "Subtlety"
        else
            -- Fallback: check for basic abilities that are more common in certain specs
            if IsPlayerSpell(2098) then -- Eviscerate - Available to all but more common in Combat
                specID = 260; specName = "Combat"
            elseif IsPlayerSpell(1943) then -- Rupture - Available to all but more common in Assassination
                specID = 259; specName = "Assassination"
            else
                specID = 260; specName = "Combat" -- Default to Combat for Rogues
            end
        end
    elseif class == "WARRIOR" then
        -- Add warrior detection as needed
        specID = 71; specName = "Arms"
    elseif class == "PALADIN" then
        -- Add paladin detection as needed
        specID = 70; specName = "Retribution"
    else
        specID = 1; specName = "Unknown"
    end

    -- Safety check: Ensure we never return 0 or invalid spec IDs for known classes
    if class == "DRUID" and (specID == 0 or specID == 1) then
        specID = 103; specName = "Feral"
    elseif class == "ROGUE" and (specID == 0 or specID == 1) then
        specID = 260; specName = "Combat"
    end

    return specID, specName
end

-- Manual function to force spec detection and update
function Hekili:ForceSpecDetection()
    local specID, specName = self:GetMoPSpecialization()

    if specID and specID > 0 then
        -- Manually set state.spec values
        if not self.State then
            self.State = { spec = {}, role = {} }
        end
        if not self.State.spec then
            self.State.spec = {}
        end

        self.State.spec.id = specID
        self.State.spec.name = specName

        -- Try to get spec key using the getSpecializationKey function from Constants.lua
        if ns.getSpecializationKey then
            self.State.spec.key = ns.getSpecializationKey(specID)
        else
            -- Fallback spec key generation
            self.State.spec.key = specName and specName:lower():gsub("%s+", "_") or "unknown"
        end

        -- Try to get role from LibClassicSpecs if available
        if LibClassicSpecs and LibClassicSpecs.GetSpecializationRole then
            local currentSpec = LibClassicSpecs.GetSpecialization and LibClassicSpecs.GetSpecialization()
            if currentSpec and currentSpec > 0 then
                local role = LibClassicSpecs.GetSpecializationRole(currentSpec)
                if role then
                    self.State.role = role
                end
            end
        end

        print("DEBUG: state.spec.id:", self.State.spec.id)
        print("DEBUG: state.spec.name:", self.State.spec.name)
        print("DEBUG: state.spec.key:", self.State.spec.key)
        print("DEBUG: state.role:", self.State.role)

        -- Force a spec change event
        if self.SpecializationChanged then
            self:SpecializationChanged()
        end

        return true
    else
        print("DEBUG: ForceSpecDetection failed - invalid spec ID")
        return false
    end
end

-- Slash command for debugging spec detection
SLASH_HEKILISPEC1 = "/hekilispec"
SlashCmdList["HEKILISPEC"] = function(msg)
    print("=== Hekili Spec Detection Debug ===")

    -- Show current state before any detection
    print("\n--- Current State (Before Detection) ---")
    if Hekili and Hekili.State and Hekili.State.spec then
        print("Current state.spec.id:", Hekili.State.spec.id)
        print("Current state.spec.name:", Hekili.State.spec.name)
        print("Current state.spec.key:", Hekili.State.spec.key)
    else
        print("No current state available")
    end

    -- Check PendingSpecializationChange
    if Hekili then
        print("PendingSpecializationChange:", Hekili.PendingSpecializationChange)
    end

    -- Show LibClassicSpecs detection
    print("\n--- LibClassicSpecs Status ---")
    local LCS = LibStub("LibClassicSpecs-1.0", true)
    if LCS then
        print("LibClassicSpecs loaded: YES")
        local specName, specID, roleToken, primaryStat = LCS:GetCurrentSpec()
        print("LCS GetCurrentSpec():")
        print("  specName:", specName)
        print("  specID:", specID)
        print("  roleToken:", roleToken)
        print("  primaryStat:", primaryStat)
    else
        print("LibClassicSpecs loaded: NO")
    end

    -- Show Blizzard API values
    print("\n--- Blizzard API Values ---")
    local spec = GetSpecialization and GetSpecialization()
    print("GetSpecialization():", spec)

    if spec then
        local id, name, desc, icon, bg, role, class = GetSpecializationInfo(spec)
        print("GetSpecializationInfo(" .. spec .. "):")
        print("  id:", id)
        print("  name:", name)
        print("  role:", role)
        print("  class:", class)
    end

    -- Show our fallback detection
    print("\n--- Fallback Detection ---")
    if ns and ns.getSpecializationID then
        local fallbackID = ns.getSpecializationID(spec)
        print("ns.getSpecializationID(" .. (spec or "nil") .. "):", fallbackID)
    end

    -- Test specific spells for Druid
    if UnitClass("player") == "Druid" then
        print("\n--- Druid Spell Detection ---")
        print("  IsPlayerSpell(18562) [Swiftmend - Resto]:", IsPlayerSpell(18562))
        print("  IsPlayerSpell(33763) [Lifebloom - Resto]:", IsPlayerSpell(33763))
        print("  IsPlayerSpell(5185) [Healing Touch - Resto]:", IsPlayerSpell(5185))
        print("  IsPlayerSpell(774) [Rejuvenation - Resto]:", IsPlayerSpell(774))
        print("  IsPlayerSpell(1822) [Rake - Feral]:", IsPlayerSpell(1822))
        print("  IsPlayerSpell(5221) [Shred - Feral]:", IsPlayerSpell(5221))
        print("  IsPlayerSpell(78674) [Starsurge - Balance]:", IsPlayerSpell(78674))
        print("  IsPlayerSpell(8921) [Moonfire - Balance]:", IsPlayerSpell(8921))
        print("  IsPlayerSpell(33878) [Mangle Bear - Guardian]:", IsPlayerSpell(33878))
        print("  IsPlayerSpell(6807) [Maul - Guardian]:", IsPlayerSpell(6807))

        -- Check current form
        if GetShapeshiftForm then
            print("  GetShapeshiftForm():", GetShapeshiftForm())
        end
    end

    print("\n--- Force Spec Detection ---")
    if Hekili and Hekili.ForceSpecDetection then
        local success = Hekili:ForceSpecDetection()
        if success then
            print("Spec detection successful!")
        else
            print("Spec detection failed!")
        end
    else
        print("Hekili not loaded or ForceSpecDetection not available")
    end

    print("\n--- Final State (After Detection) ---")
    if Hekili and Hekili.State and Hekili.State.spec then
        print("Final state.spec.id:", Hekili.State.spec.id)
        print("Final state.spec.name:", Hekili.State.spec.name)
        print("Final state.spec.key:", Hekili.State.spec.key)
        if Hekili.State.role then
            print("Final state.role.attack:", Hekili.State.role.attack)
            print("Final state.role.tank:", Hekili.State.role.tank)
            print("Final state.role.heal:", Hekili.State.role.heal)
        end
        print("Final state.spec.primaryStat:", Hekili.State.spec.primaryStat)
    else
        print("No final state available")
    end

    -- Trigger a specialization change to see if that affects things
    print("\n--- Triggering SpecializationChanged ---")
    if Hekili and Hekili.SpecializationChanged then
        local beforeID = Hekili.State and Hekili.State.spec and Hekili.State.spec.id
        print("Before SpecializationChanged - state.spec.id:", beforeID)

        Hekili:SpecializationChanged()
        print("SpecializationChanged called")

        -- Show state after SpecializationChanged
        local afterID = Hekili.State and Hekili.State.spec and Hekili.State.spec.id
        print("After SpecializationChanged - state.spec.id:", afterID)

        if beforeID and afterID and beforeID ~= afterID then
            print("WARNING: state.spec.id changed from", beforeID, "to", afterID)
        end
    end

    print("=== End Debug ===")
end
