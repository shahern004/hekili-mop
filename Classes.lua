-- Classes.lua
-- January 2025

local addon, ns = ...
local Hekili = _G[ addon ]

local class = Hekili.Class
local state = Hekili.State

local CommitKey = ns.commitKey
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local GetItemInfo = ns.CachedGetItemInfo
local GetResourceInfo, GetResourceKey = ns.GetResourceInfo, ns.GetResourceKey
local ResetDisabledGearAndSpells = ns.ResetDisabledGearAndSpells
local RegisterEvent = ns.RegisterEvent
local RegisterUnitEvent = ns.RegisterUnitEvent

local getSpecializationKey = ns.getSpecializationKey

local LSR = LibStub( "SpellRange-1.0" )

local insert, wipe = table.insert, table.wipe

local mt_resource = ns.metatables.mt_resource

-- MoP API compatibility - use old API calls instead of modern C_* namespaced ones
local GetActiveLossOfControlData, GetActiveLossOfControlDataCount
if C_LossOfControl then
    GetActiveLossOfControlData, GetActiveLossOfControlDataCount = C_LossOfControl.GetActiveLossOfControlData, C_LossOfControl.GetActiveLossOfControlDataCount
else
    -- MoP fallbacks
    GetActiveLossOfControlData = function() return {} end
    GetActiveLossOfControlDataCount = function() return 0 end
end

local GetItemCooldown = _G.GetItemCooldown or (C_Item and C_Item.GetItemCooldown) or function() return 0, 0 end
local GetSpellDescription = _G.GetSpellDescription or (C_Spell and C_Spell.GetSpellDescription) or function() return "" end  
local GetSpellTexture = _G.GetSpellTexture or (C_Spell and C_Spell.GetSpellTexture) or function() return "Interface\\Icons\\INV_Misc_QuestionMark" end
local GetSpecialization, GetSpecializationInfo = _G.GetSpecialization, _G.GetSpecializationInfo
local GetItemSpell = _G.GetItemSpell or (C_Item and C_Item.GetItemSpell) or function() return nil end
local GetItemCount = _G.GetItemCount or (C_Item and C_Item.GetItemCount) or function() return 0 end  
local IsUsableItem = _G.IsUsableItem or (C_Item and C_Item.IsUsableItem) or function() return false end
local GetSpellLink = _G.GetSpellLink or (C_Spell and C_Spell.GetSpellLink) or function() return nil end

-- Save the original GetSpellInfo before we override it
local OriginalGetSpellInfo = _G.GetSpellInfo

-- MoP compatibility wrapper for GetSpellInfo
local function GetSpellInfoCompatible(spellID)
    if not spellID then return nil end
    
    local name, rank, icon, castTime, minRange, maxRange, spellId = OriginalGetSpellInfo(spellID)
    if not name then return nil end
    
    -- Return a table structure like modern API for compatibility
    return {
        name = name,
        rank = rank, 
        iconID = icon,
        castTime = castTime,
        minRange = minRange,
        maxRange = maxRange,
        spellID = spellId or spellID
    }
end

-- Override GetSpellInfo to use our compatibility wrapper
local GetSpellInfo = GetSpellInfoCompatible

local UnitBuff, UnitDebuff = ns.UnitBuff, ns.UnitDebuff

local specTemplate = {
    enabled = true,

    aoe = 2,
    cycle = false,
    cycle_min = 6,
    gcdSync = true,

    nameplates = true,
    petbased = false,

    damage = true,
    damageExpiration = 8,
    damageDots = false,
    damageOnScreen = true,
    damageRange = 0,
    damagePets = false,

    -- Toggles
    custom1Name = "Custom 1",
    custom2Name = "Custom 2",
    noFeignedCooldown = false,

    abilities = {
        ['**'] = {
            disabled = false,
            toggle = "default",
            clash = 0,
            targetMin = 0,
            targetMax = 0,
            dotCap = 0,
            boss = false
        }
    },
    items = {
        ['**'] = {
            disabled = false,
            toggle = "default",
            clash = 0,
            targetMin = 0,
            targetMax = 0,
            boss = false,
            criteria = nil
        }
    },

    placeboBar = 3,

    ranges = {},
    settings = {},
    phases = {},
    cooldowns = {},
    utility = {},
    defensives = {},
    custom1 = {},
    custom2 = {},
}
ns.specTemplate = specTemplate -- for options.


local function Aura_DetectSharedAura( t, type )
    if not t then return end
    local finder = type == "debuff" and FindUnitDebuffByID or FindUnitBuffByID
    local aura = class.auras[ t.key ]

    local name, _, count, _, duration, expirationTime, caster = finder( aura.shared, aura.id )

    if name then
        t.count = count > 0 and count or 1

        if expirationTime > 0 then
            t.applied = expirationTime - duration
            t.expires = expirationTime
        else
            t.applied = state.query_time
            t.expires = state.query_time + t.duration
        end
        t.caster = caster
        return
    end

    t.count = 0
    t.applied = 0
    t.expires = 0
    t.caster = "nobody"
end


local protectedFunctions = {
    -- Channels.
    start = true,
    tick = true,
    finish = true,

    -- Casts
    handler = true, -- Cast finish.
    impact = true,  -- Projectile impact.
}


local HekiliSpecMixin = {
    RegisterResource = function( self, resourceID, regen, model, meta )
        local resource = GetResourceKey( resourceID )

        if not resource then
            Hekili:Error( "Unable to identify resource with PowerType " .. resourceID .. "." )
            return
        end

        local r = self.resources[ resource ] or {}

        r.resource = resource
        r.type = resourceID
        r.state = model or setmetatable( {
            resource = resource,
            type = resourceID,

            forecast = {},
            fcount = 0,
            times = {},
            values = {},

            actual = 0,
            max = 1,

            active_regen = 0.001,
            inactive_regen = 0.001,
            last_tick = 0,

            swingGen = false,

            add = function( amt, overcap )
                -- Bypasses forecast, useful in hooks.
                if overcap then r.state.amount = r.state.amount + amt
                else r.state.amount = max( 0, min( r.state.amount + amt, r.state.max ) ) end
            end,

            timeTo = function( x )
                return state:TimeToResource( r.state, x )
            end,
        }, mt_resource )
        r.state.regenModel = regen
        r.state.meta = meta or {}

        for _, func in pairs( r.state.meta ) do
            setfenv( func, state )
        end

        if r.state.regenModel then
            for _, v in pairs( r.state.regenModel ) do
                v.resource = v.resource or resource
                self.resourceAuras[ v.resource ] = self.resourceAuras[ v.resource ] or {}

                if v.aura then
                    self.resourceAuras[ v.resource ][ v.aura ] = true
                end

                if v.channel then
                    self.resourceAuras[ v.resource ].casting = true
                end

                if v.swing then
                    r.state.swingGen = true
                end
            end
        end

        self.primaryResource = self.primaryResource or resource
        self.resources[ resource ] = r

        CommitKey( resource )
    end,

    RegisterTalents = function( self, talents )
        for talent, id in pairs( talents ) do
            self.talents[ talent ] = id
            CommitKey( talent )

            local hero = id[ 4 ]

            if hero then
                self.talents[ hero ] = id
                CommitKey( hero )
                id[ 4 ] = nil
            end
        end
    end,

    RegisterPvpTalents = function( self, pvp )
        for talent, spell in pairs( pvp ) do
            self.pvptalents[ talent ] = spell
            CommitKey( talent )
        end
    end,

    RegisterGlyphs = function( self, glyphs )
        for spellID, glyphName in pairs( glyphs ) do
            if type( spellID ) == "number" and type( glyphName ) == "string" then
                self.glyphs[ glyphName ] = spellID
                self.glyphs[ spellID ] = glyphName
                CommitKey( glyphName )
            else
                Hekili:Error( "RegisterGlyphs: Invalid glyph format for spell %s -> %s in spec %d", tostring( spellID ), tostring( glyphName ), self.id )
            end
        end
    end,

    RegisterAura = function( self, aura, data )
        CommitKey( aura )

        local a = setmetatable( {
            funcs = {}
        }, {
            __index = function( t, k )
                if t.funcs[ k ] then return t.funcs[ k ]() end

                local setup = rawget( t, "onLoad" )
                if setup then
                    t.onLoad = nil
                    setup( t )

                    return t[ k ]
                end
            end
        } )

        a.key = aura

        if not data.id then
            self.pseudoAuras = self.pseudoAuras + 1
            data.id = ( -1000 * self.id ) - self.pseudoAuras
        end

        -- default values.
        data.duration  = data.duration or 30
        data.max_stack = data.max_stack or 1

        -- This is a shared buff that can come from anyone, give it a special generator.
        --[[ if data.shared then
            a.generate = Aura_DetectSharedAura
        end ]]

        for element, value in pairs( data ) do
            if type( value ) == "function" then
                setfenv( value, state )
                if element ~= "generate" then a.funcs[ element ] = value
                else a[ element ] = value end
            else
                a[ element ] = value
            end

            class.knownAuraAttributes[ element ] = true
        end

        if data.tick_time and not data.tick_fixed then
            if a.funcs.tick_time then
                local original = a.funcs.tick_time
                a.funcs.tick_time = setfenv( function( ... )
                    local val = original( ... )
                    return ( val or 3 ) * haste
                end, state )
                a.funcs.base_tick_time = original
            else
                local original = a.tick_time
                a.funcs.tick_time = setfenv( function( ... )
                    return ( original or 3 ) * haste
                end, state )
                a.base_tick_time = original
                a.tick_time = nil
            end
        end

        self.auras[ aura ] = a

        if a.id then
            if a.id > 0 then
                -- Hekili:ContinueOnSpellLoad( a.id, function( success )
                a.onLoad = function( a )
                    local d = GetSpellInfo( a.id )
                    a.name = d and d.name

                    if not a.name then
                        for k, v in pairs( class.auraList ) do
                            if v == a then class.auraList[ k ] = nil end
                        end

                        Hekili.InvalidSpellIDs = Hekili.InvalidSpellIDs or {}
                        Hekili.InvalidSpellIDs[ a.id ] = a.name or a.key

                        a.id = a.key
                        a.name = a.name or a.key

                        return
                    end

                    a.desc = GetSpellDescription( a.id )

                    local texture = a.texture or GetSpellTexture( a.id )

                    if self.id > 0 then
                        class.auraList[ a.key ] = "|T" .. texture .. ":0|t " .. a.name
                    end

                    self.auras[ a.name ] = a
                    if ns.getSpecializationID() == self.id then
                        -- Copy to class table as well.
                        class.auras[ a.name ] = a
                    end

                    if self.pendingItemSpells[ a.name ] then
                        local items = self.pendingItemSpells[ a.name ]

                        if type( items ) == "table" then
                            for i, item in ipairs( items ) do
                                local ability = self.abilities[ item ]
                                ability.itemSpellKey = a.key .. "_" .. ability.itemSpellID

                                self.abilities[ ability.itemSpellKey ] = a
                                class.abilities[ ability.itemSpellKey ] = a
                            end
                        else
                            local ability = self.abilities[ items ]
                            ability.itemSpellKey = a.key .. "_" .. ability.itemSpellID

                            self.abilities[ ability.itemSpellKey ] = a
                            class.abilities[ ability.itemSpellKey ] = a
                        end

                        self.pendingItemSpells[ a.name ] = nil
                        self.itemPended = nil
                    end
                end
            end
            self.auras[ a.id ] = a
        end

        if data.meta then
            for k, v in pairs( data.meta ) do
                if type( v ) == "function" then data.meta[ k ] = setfenv( v, state ) end
                class.knownAuraAttributes[ k ] = true
            end
        end

        if data.copy then
            if type( data.copy ) ~= "table" then
                self.auras[ data.copy ] = a
            else
                for _, key in ipairs( data.copy ) do
                    self.auras[ key ] = a
                end
            end
        end
    end,

    RegisterAuras = function( self, auras )
        for aura, data in pairs( auras ) do
            self:RegisterAura( aura, data )
        end
    end,

    RegisterPower = function( self, power, id, aura )
        self.powers[ power ] = id
        CommitKey( power )

        if aura and type( aura ) == "table" then
            self:RegisterAura( power, aura )
        end
    end,

    RegisterPowers = function( self, powers )
        for k, v in pairs( powers ) do
            self.powers[ k ] = v.id
            self.powers[ v.id ] = k

            for token, ids in pairs( v.triggers ) do
                if not self.auras[ token ] then
                    self:RegisterAura( token, {
                        id = v.id,
                        copy = ids
                    } )
                end
            end
        end
    end,

    RegisterStateExpr = function( self, key, func )
        setfenv( func, state )
        self.stateExprs[ key ] = func
        class.stateExprs[ key ] = func
        CommitKey( key )
    end,

    RegisterStateFunction = function( self, key, func )
        setfenv( func, state )
        self.stateFuncs[ key ] = func
        class.stateFuncs[ key ] = func
        CommitKey( key )
    end,

    RegisterStateTable = function( self, key, data )
        for _, f in pairs( data ) do
            if type( f ) == "function" then
                setfenv( f, state )
            end
        end

        local meta = getmetatable( data )

        if meta and meta.__index then
            setfenv( meta.__index, state )
        end

        self.stateTables[ key ] = data
        class.stateTables[ key ] = data
        CommitKey( key )
    end,

    -- Phases are for more durable variables that should be recalculated over the course of recommendations.
    -- The start/finish conditions are calculated on reset and that state is persistent between sets of recommendations.
    -- Within a set of recommendations, the phase conditions are recalculated when the clock advances and/or when ability handlers are fired.
    -- Notably, finish is only fired if we are currently in the phase.
    RegisterPhase = function( self, key, start, finish, ... )
        if start then start = setfenv( start, state ) end
        if finish then finish = setfenv( finish, state ) end

        self.phases[ key ] = {
            activate = start,
            deactivate = finish,
            virtual = {},
            real = {}
        }

        local phase = self.phases[ key ]
        local n = select( "#", ... )

        for i = 1, n do
            local hook = select( i, ... )

            if hook == "reset_precast" then
                self:RegisterHook( hook, function()
                    local d = display or "Primary"

                    if phase.real[ d ] == nil then
                        phase.real[ d ] = false
                    end

                    local original = phase.real[ d ]

                    if state.time == 0 and not InCombatLockdown() then
                        phase.real[ d ] = false
                        -- Hekili:Print( format( "[ %s ] Phase '%s' set to '%s' (%s) - out of combat.", self.name or "Unspecified", key, tostring( phase.real[ d ] ), hook ) )
                        -- if Hekili.ActiveDebug then Hekili:Debug( "[ %s ] Phase '%s' set to '%s' (%s) - out of combat.", self.name or "Unspecified", key, tostring( phase.virtual[ display or "Primary" ] ), hook ) end
                    end

                    if not phase.real[ d ] and phase.activate() then
                        phase.real[ d ] = true
                    end

                    if phase.real[ d ] and phase.deactivate() then
                        phase.real[ d ] = false
                    end

                    --[[ if phase.real[ d ] ~= original then
                        if d == "Primary" then Hekili:Print( format( "Phase change for %s [ %s ] (from %s to %s).", key, d, tostring( original ), tostring( phase.real[ d ] ) ) ) end
                    end ]]

                    phase.virtual[ d ] = phase.real[ d ]

                    if Hekili.ActiveDebug then Hekili:Debug( "[ %s ] Phase '%s' set to '%s' (%s).", self.name or "Unspecified", key, tostring( phase.virtual[ d ] ), hook ) end
                end )
            else
                self:RegisterHook( hook, function()
                    local d = display or "Primary"
                    local previous = phase.virtual[ d ]

                    if phase.virtual[ d ] ~= true and phase.activate() then
                        phase.virtual[ d ] = true
                    end

                    if phase.virtual[ d ] == true and phase.deactivate() then
                        phase.virtual[ d ] = false
                    end

                    if Hekili.ActiveDebug and phase.virtual[ d ] ~= previous then Hekili:Debug( "[ %s ] Phase '%s' set to '%s' (%s) - virtual.", self.name or "Unspecified", key, tostring( phase.virtual[ d ] ), hook ) end
                end )
            end
        end

        self:RegisterVariable( key, function()
            return self.phases[ key ].virtual[ display or "Primary" ]
        end )
    end,

    RegisterPhasedVariable = function( self, key, default, value, ... )
        value = setfenv( value, state )

        self.phases[ key ] = {
            update = value,
            virtual = {},
            real = {}
        }

        local phase = self.phases[ key ]
        local n = select( "#", ... )

        if type( default ) == "function" then
            phase.default = setfenv( default, state )
        else
            phase.default = setfenv( function() return default end, state )
        end

        for i = 1, n do
            local hook = select( i, ... )

            if hook == "reset_precast" then
                self:RegisterHook( hook, function()
                    local d = display or "Primary"

                    if phase.real[ d ] == nil or ( state.time == 0 and not InCombatLockdown() ) then
                        phase.real[ d ] = phase.default()
                    end

                    local original = phase.real[ d ] or "nil"

                    phase.real[ d ] = phase.update( phase.real[ d ], phase.default() )
                    phase.virtual[ d ] = phase.real[ d ]

                    if Hekili.ActiveDebug then
                        Hekili:Debug( "[ %s ] Phased variable '%s' set to '%s' (%s) - was '%s'.", self.name or "Unspecified", key, tostring( phase.virtual[ display or "Primary" ] ), hook, tostring( original ) )
                    end
                end )
            else
                self:RegisterHook( hook, function()
                    local d = display or "Primary"
                    local previous = phase.virtual[ d ]

                    phase.virtual[ d ] = phase.update( phase.virtual[ d ], phase.default() )

                    if Hekili.ActiveDebug and phase.virtual[ d ] ~= previous then Hekili:Debug( "[ %s ] Phased variable '%s' set to '%s' (%s) - virtual.", self.name or "Unspecified", key, tostring( phase.virtual[ display or "Primary" ] ), hook ) end
                end )
            end
        end

        self:RegisterVariable( key, function()
            return self.phases[ key ].virtual[ display or "Primary" ]
        end )
    end,

    RegisterGear = function( self, ... )
        local arg1 = select( 1, ... )
        if not arg1 then return end

        -- If the first arg is a table, it's registering multiple items/sets
        if type( arg1 ) == "table" then
            for set, data in pairs( arg1 ) do
                self:RegisterGear( set, data )
            end
            return
        end

        local arg2 = select( 2, ... )
        if not arg2 then return end

        -- If the first arg is a string, register it
        if type( arg1 ) == "string" then
            local gear = self.gear[ arg1 ] or {}
            local found = false

            -- If the second arg is a table, it's a tier set with auras
            if type( arg2 ) == "table" then
                if arg2.items then
                    for _, item in ipairs( arg2.items ) do
                        if not gear[ item ] then
                            table.insert( gear, item )
                            gear[ item ] = true
                            found = true
                        end
                    end
                end

                if arg2.auras then
                    -- Register auras (even if no items are found, can be useful for early patch testing).
                    self:RegisterAuras( arg2.auras )
                end
            end

            -- If the second arg is a number, this is a legacy registration with a single set/item
            if type( arg2 ) == "number" then
                local n = select( "#", ... )

                for i = 2, n do
                    local item = select( i, ... )

                    if not gear[ item ] then
                        table.insert( gear, item )
                        gear[ item ] = true
                        found = true
                    end
                end
            end

            if found then
                self.gear[ arg1 ] = gear
                CommitKey( arg1 )
            end

            return
        end

        -- Debug print if needed
        -- Hekili:Print( "|cFFFF0000[Hekili]|r Invalid input passed to RegisterGear." )
    end,


    -- Check for the set bonus based on hidden aura instead of counting the number of equipped items.
    -- This may be useful for tier set items that are crafted so their item ID doesn't match.
    -- The alternative is *probably* to treat sets based on bonusIDs.
    RegisterSetBonus = function( self, key, spellID )
        self.setBonuses[ key ] = spellID
        CommitKey( key )
    end,

    RegisterSetBonuses = function( self, ... )
        local n = select( "#", ... )

        for i = 1, n, 2 do
            self:RegisterSetBonus( select( i, ... ) )
        end
    end,

    RegisterPotion = function( self, potion, data )
        self.potions[ potion ] = data

        data.key = potion

        if data.items then
            if type( data.items ) == "table" then
                for _, key in ipairs( data.items ) do
                    self.potions[ key ] = data
                    CommitKey( key )
                end
            else
                self.potions[ data.items ] = data
                CommitKey( data.items )
            end
        end

        -- MoP compatibility: Use basic item info instead of Item callback system
        local name, link = GetItemInfo( data.item )
        if name then
            data.name = name
            data.link = link
            class.potionList[ potion ] = link
        end

        CommitKey( potion )
    end,

    RegisterPotions = function( self, potions )
        for k, v in pairs( potions ) do
            self:RegisterPotion( k, v )
        end
    end,

    RegisterRecheck = function( self, func )
        self.recheck = func
    end,

    RegisterHook = function( self, hook, func, noState )
        if not ( noState == true or hook == "COMBAT_LOG_EVENT_UNFILTERED" and noState == nil ) then
            func = setfenv( func, state )
        end
        self.hooks[ hook ] = self.hooks[ hook ] or {}
        insert( self.hooks[ hook ], func )
    end,

    RegisterAbility = function( self, ability, data )
        CommitKey( ability )

        local a = setmetatable( {
            funcs = {},
        }, {
            __index = function( t, k )
                local setup = rawget( t, "onLoad" )
                if setup then
                    t.onLoad = nil
                    setup( t )
                    return t[ k ]
                end

                if t.funcs[ k ] then return t.funcs[ k ]() end
                if k == "lastCast" then return state.history.casts[ t.key ] or t.realCast end
                if k == "lastUnit" then return state.history.units[ t.key ] or t.realUnit end
            end,
        } )

        a.key = ability
        a.from = self.id

        if not data.id then
            if data.item then
                class.specs[ 0 ].itemAbilities = class.specs[ 0 ].itemAbilities + 1
                data.id = -100 - class.specs[ 0 ].itemAbilities
            else
                self.pseudoAbilities = self.pseudoAbilities + 1
                data.id = -1000 * self.id - self.pseudoAbilities
            end
            a.id = data.id
        end

        if data.id and type( data.id ) == "function" then
            if not data.copy or type( data.copy ) == "table" and #data.copy == 0 then
                Hekili:Error( "RegisterAbility for %s (Specialization %d) will fail; ability has an ID function but needs to have 'copy' entries for the abilities table.", ability, self.id )
            end
        end


        local item = data.item
        if item and type( item ) == "function" then
            setfenv( item, state )
            item = item()
        end

        if data.meta then
            for k, v in pairs( data.meta ) do
                if type( v ) == "function" then data.meta[ k ] = setfenv( v, state ) end
            end
        end

        -- default values.
        if not data.cast     then data.cast     = 0             end
        if not data.cooldown then data.cooldown = 0             end
        if not data.recharge then data.recharge = data.cooldown end
        if not data.charges  then data.charges  = 1             end

        if data.hasteCD then
            if type( data.cooldown ) == "number" and data.cooldown > 0 then data.cooldown = Hekili:Loadstring( "return " .. data.cooldown .. " * haste" ) end
            if type( data.recharge ) == "number" and data.recharge > 0 then data.recharge = Hekili:Loadstring( "return " .. data.recharge .. " * haste" ) end
        end

        if not data.fixedCast and type( data.cast ) == "number" then
            data.cast = Hekili:Loadstring( "return " .. data.cast .. " * haste" )
        end

        if data.toggle == "interrupts" and data.gcd == "off" and data.readyTime == state.timeToInterrupt and data.interrupt == nil then
            data.interrupt = true
        end

        for key, value in pairs( data ) do
            if type( value ) == "function" then
                setfenv( value, state )

                if not protectedFunctions[ key ] then a.funcs[ key ] = value
                else a[ key ] = value end
                data[ key ] = nil
            else
                a[ key ] = value
            end
        end

        if ( a.velocity or a.flightTime ) and a.impact and a.isProjectile == nil then
            a.isProjectile = true
        end        a.realCast = 0

        if item then
            -- Simple item mapping like in Cataclysm
            class.itemMap[ item ] = ability

            -- Register the item if it doesn't already exist.
            class.specs[0]:RegisterGear( ability, item )
            if data.copy then
                if type( data.copy ) == "table" then
                    for _, iID in ipairs( data.copy ) do
                        if type( iID ) == "number" and iID < 0 then class.specs[0]:RegisterGear( ability, -iID ) end
                    end
                else
                    if type( data.copy ) == "number" and data.copy < 0 then class.specs[0]:RegisterGear( ability, -data.copy ) end
                end
            end
        end

        if data.items then
            for _, itemID in ipairs( data.items ) do
                class.itemMap[ itemID ] = ability
                class.specs[0]:RegisterGear( ability, itemID )
            end
        end

        if a.id and a.id > 0 then
            -- Hekili:ContinueOnSpellLoad( a.id, function( success )
            a.onLoad = function()
                local spellInfo = GetSpellInfo( a.id )

                if spellInfo == nil then
                    spellInfo = GetItemInfo( a.id )
                end
                if spellInfo then
                    a.name = spellInfo.name
                else
                    a.name = nil
                end

                if not a.name then
                    for k, v in pairs( class.abilityList ) do
                        if v == a then class.abilityList[ k ] = nil end
                    end
                    Hekili.InvalidSpellIDs = Hekili.InvalidSpellIDs or {}
                    table.insert( Hekili.InvalidSpellIDs, a.id )
                    Hekili:Error( "Name info not available for " .. a.id .. "." )
                    return
                end

                if not a.name then Hekili:Error( "Name info not available for " .. a.id .. "." ); return false end

                a.desc = GetSpellDescription( a.id ) -- was returning raw tooltip data.

                if a.suffix then
                    a.actualName = a.name
                    a.name = a.name .. " " .. a.suffix
                end

                local texture = a.texture or GetSpellTexture( a.id )

                self.abilities[ a.name ] = self.abilities[ a.name ] or a
                class.abilities[ a.name ] = class.abilities[ a.name ] or a

                if not a.unlisted then
                    class.abilityList[ ability ] = a.listName or ( "|T" .. texture .. ":0|t " .. a.name )
                    class.abilityByName[ a.name ] = class.abilities[ a.name ] or a
                end

                if a.rangeSpell and type( a.rangeSpell ) == "number" then
                    Hekili:ContinueOnSpellLoad( a.rangeSpell, function( success )
                        if success then
                            local info = GetSpellInfo( a.rangeSpell )
                            if info then
                                a.rangeSpell = info.name
                            else
                                a.rangeSpell = nil
                            end
                        else
                            a.rangeSpell = nil
                        end
                    end )
                end

                Hekili.OptionsReady = false
            end
        end

        self.abilities[ ability ] = a
        self.abilities[ a.id ] = a

        if not a.unlisted then class.abilityList[ ability ] = class.abilityList[ ability ] or a.listName or a.name end

        if data.copy then
            if type( data.copy ) == "string" or type( data.copy ) == "number" then
                self.abilities[ data.copy ] = a
            elseif type( data.copy ) == "table" then
                for _, key in ipairs( data.copy ) do
                    self.abilities[ key ] = a
                end
            end
        end

        if data.items then
            for _, itemID in ipairs( data.items ) do
                class.itemMap[ itemID ] = ability
            end
        end

        if a.dual_cast or a.funcs.dual_cast then
            self.can_dual_cast = true
            self.dual_cast[ a.key ] = true
        end

        if a.empowered or a.funcs.empowered then
            self.can_empower = true
        end

        if a.auras then
            self:RegisterAuras( a.auras )
        end
    end,    RegisterAbilities = function( self, abilities )
        for ability, data in pairs( abilities ) do
            self:RegisterAbility( ability, data )
        end
        
        -- If this is spec 0 (all), copy the new abilities to all other specs
        if self.id == 0 then
            for specID, spec in pairs( class.specs ) do
                if specID ~= 0 then
                    local copiedCount = 0
                    for ability, data in pairs( abilities ) do
                        if not spec.abilities[ability] then
                            spec.abilities[ability] = data
                            copiedCount = copiedCount + 1
                        end
                        -- Also ensure they're in the global abilities table
                        if not class.abilities[ability] then
                            class.abilities[ability] = data
                        end
                    end
                    if copiedCount > 0 then
                        print("DEBUG: RegisterAbilities copied", copiedCount, "new abilities from spec 0 to spec", specID)
                    end
                end
            end
        end
    end,

    RegisterPack = function( self, name, version, import )
        self.packs[ name ] = {
            version = tonumber( version ),
            import = import:gsub("([^|])|([^|])", "%1||%2")
        }
    end,

    RegisterPriority = function( self, name, version, notes, priority )
    end,

    RegisterRanges = function( self, ... )
        if type( ... ) == "table" then
            self.ranges = ...
            return
        end

        for i = 1, select( "#", ... ) do
            insert( self.ranges, ( select( i, ... ) ) )
        end
    end,

    RegisterRangeFilter = function( self, name, func )
        self.filterName = name
        self.filter = func
    end,

    RegisterOptions = function( self, options )
        self.options = options
    end,

    RegisterEvent = function( self, event, func )
        RegisterEvent( event, function( ... )
            if state.spec.id == self.id then func( ... ) end
        end )
    end,

    RegisterUnitEvent = function( self, event, unit1, unit2, func )
        RegisterUnitEvent( event, unit1, unit2, function( ... )
            if state.spec.id == self.id then func( ... ) end
        end )
    end,

    RegisterCombatLogEvent = function( self, func )
        self:RegisterHook( "COMBAT_LOG_EVENT_UNFILTERED", func )
    end,

    RegisterCycle = function( self, func )
        self.cycle = setfenv( func, state )
    end,

    RegisterPet = function( self, token, id, spell, duration, ... )
        CommitKey( token )

        -- Prepare the main model
        local model = {
            id = type( id ) == "function" and setfenv( id, state ) or id,
            token = token,
            spell = spell,
            duration = type( duration ) == "function" and setfenv( duration, state ) or duration
        }

        -- Register the main pet token
        self.pets[ token ] = model

        -- Register copies, but avoid overwriting unrelated registrations
        local n = select( "#", ... )
        if n and n > 0 then
            for i = 1, n do
                local alias = select( i, ... )

                if self.pets[ alias ] and self.pets[ alias ] ~= model then
                    if Hekili.ActiveDebug then
                        Hekili:Debug( "RegisterPet: Alias '%s' already assigned to a different pet. Skipping for token '%s'.", tostring( alias ), tostring( token ) )
                    end
                else
                    self.pets[ alias ] = model
                end
            end
        end
    end,


    RegisterPets = function( self, pets )
        for token, data in pairs( pets ) do
            -- Extract fields from the pet definition.
            local id = data.id
            local spell = data.spell
            local duration = data.duration
            local copy = data.copy

            -- Register the pet and handle the copy field if it exists.
            if copy then
                self:RegisterPet( token, id, spell, duration, type( copy ) == "string" and copy or unpack( copy ) )
            else
                self:RegisterPet( token, id, spell, duration )
            end
        end
    end,

    RegisterTotem = function( self, token, id, ... )
        -- Register the primary totem.
        self.totems[ token ] = id
        self.totems[ id ] = token

        -- Handle copies if provided.
        local n = select( "#", ... )
        if n and n > 0 then
            for i = 1, n do
                local copy = select( i, ... )
                self.totems[ copy ] = id
                self.totems[ id ] = copy
            end
        end

        -- Commit the primary token.
        CommitKey( token )
    end,

    RegisterTotems = function( self, totems )
        for token, data in pairs( totems ) do
            local id = data.id
            local copy = data.copy

            -- Register the primary totem.
            self.totems[ token ] = id
            self.totems[ id ] = token

            -- Register any copies (aliases).
            if copy then
                if type( copy ) == "string" then
                    self.totems[ copy ] = id
                    self.totems[ id ] = copy
                elseif type( copy ) == "table" then
                    for _, alias in ipairs( copy ) do
                        self.totems[ alias ] = id
                        self.totems[ id ] = alias
                    end
                end
            end

            CommitKey( token )
        end
    end,

    GetSetting = function( self, info )
        local setting = info[ #info ]
        return Hekili.DB.profile.specs[ self.id ].settings[ setting ]
    end,

    SetSetting = function( self, info, val )
        local setting = info[ #info ]
        Hekili.DB.profile.specs[ self.id ].settings[ setting ] = val
    end,

    -- option should be an AceOption table.
    RegisterSetting = function( self, key, value, option )
        CommitKey( key )

        table.insert( self.settings, {
            name = key,
            default = value,
            info = option
        } )

        option.order = 100 + #self.settings

        option.get = option.get or function( info )
            local setting = info[ #info ]
            local val = Hekili.DB.profile.specs[ self.id ].settings[ setting ]

            if val ~= nil then return val end
            return value
        end

        option.set = option.set or function( info, val )
            local setting = info[ #info ]
            Hekili.DB.profile.specs[ self.id ].settings[ setting ] = val
        end
    end,

    -- For faster variables.
    RegisterVariable = function( self, key, func )
        CommitKey( key )
        self.variables[ key ] = setfenv( func, state )
    end,
}


function Hekili:RestoreDefaults()
    local p = self.DB.profile
    local reverted = {}
    local changed = {}

    for k, v in pairs( class.packs ) do
        local existing = rawget( p.packs, k )

        if not existing or not existing.version or existing.version ~= v.version then
            local data = self.DeserializeActionPack( v.import )

            if data and type( data ) == "table" then
                p.packs[ k ] = data.payload
                data.payload.version = v.version
                data.payload.date = v.version
                data.payload.builtIn = true

                if not existing or not existing.version or existing.version < v.version then
                    insert( changed, k )
                else
                    insert( reverted, k )
                end

                local specID = data.payload.spec

                if specID then
                    local spec = rawget( p.specs, specID )
                    if spec then
                        if spec.package then
                            local currPack = p.packs[ spec.package ]
                            if not currPack or currPack.spec ~= specID then
                                spec.package = k
                            end
                        else
                            spec.package = k
                        end
                    end
                end
            end
        end
    end

    if #changed > 0 or #reverted > 0 then
        self:LoadScripts()
    end

    if #changed > 0 then
        local msg

        if #changed == 1 then
            msg = "The |cFFFFD100" .. changed[1] .. "|r priority was updated."
        elseif #changed == 2 then
            msg = "The |cFFFFD100" .. changed[1] .. "|r and |cFFFFD100" .. changed[2] .. "|r priorities were updated."
        else
            msg = "|cFFFFD100" .. changed[1] .. "|r"

            for i = 2, #changed - 1 do
                msg = msg .. ", |cFFFFD100" .. changed[i] .. "|r"
            end

            msg = "The " .. msg .. ", and |cFFFFD100" .. changed[ #changed ] .. "|r priorities were updated."
        end

        if msg then
            C_Timer.After( 5, function()
                if Hekili.DB.profile.notifications.enabled then Hekili:Notify( msg, 6 ) end
                Hekili:Print( msg )
            end )
        end
    end

    if #reverted > 0 then
        local msg

        if #reverted == 1 then
            msg = "The |cFFFFD100" .. reverted[1] .. "|r priority was reverted."
        elseif #reverted == 2 then
            msg = "The |cFFFFD100" .. reverted[1] .. "|r and |cFFFFD100" .. reverted[2] .. "|r priorities were reverted."
        else
            msg = "|cFFFFD100" .. reverted[1] .. "|r"

            for i = 2, #reverted - 1 do
                msg = msg .. ", |cFFFFD100" .. reverted[i] .. "|r"
            end

            msg = "The " .. msg .. ", and |cFFFFD100" .. reverted[ #reverted ] .. "|r priorities were reverted."
        end

        if msg then
            C_Timer.After( 6, function()
                if Hekili.DB.profile.notifications.enabled then Hekili:Notify( msg, 6 ) end
                Hekili:Print( msg )
            end )
        end
    end
end


function Hekili:RestoreDefault( name )
    local p = self.DB.profile

    local default = class.packs[ name ]

    if default then
        local data = self.DeserializeActionPack( default.import )

        if data and type( data ) == "table" then
            p.packs[ name ] = data.payload
            data.payload.version = default.version
            data.payload.date = default.version
            data.payload.builtIn = true
        end
    end
end


ns.restoreDefaults = function( category, purge )
end


ns.isDefault = function( name, category )
    if not name or not category then
        return false
    end

    for i, default in ipairs( class.defaults ) do
        if default.type == category and default.name == name then
            return true, i
        end
    end

    return false
end

function Hekili:NewSpecialization( specID, isRanged, icon )

    if not specID or specID < 0 then return end

    local id, name, _, texture, role, pClass

    if Hekili.IsRetail() and specID > 0 then id, name, _, texture, role, pClass = GetSpecializationInfoByID( specID )
    else
        id = specID
        texture = icon
    end

    if not id then
        Hekili:Error( "Unable to generate specialization DB for spec ID #" .. specID .. "." )
        return nil
    end

    if specID ~= 0 then
        class.initialized = true
    end

    local token = getSpecializationKey( id )

    local spec = class.specs[ id ] or {
        id = id,
        key = token,
        name = name,
        texture = texture,
        role = role,
        class = pClass,
        melee = not isRanged,

        resources = {},
        resourceAuras = {},
        primaryResource = nil,
        primaryStat = nil,

        talents = {},
        pvptalents = {},
        powers = {},
        glyphs = {},

        auras = {},
        pseudoAuras = 0,

        abilities = {},
        pseudoAbilities = 0,
        itemAbilities = 0,
        pendingItemSpells = {},

        pets = {},
        totems = {},

        potions = {},

        ranges = {},
        settings = {},

        stateExprs = {}, -- expressions are returned as values and take no args.
        stateFuncs = {}, -- functions can take arguments and can be used as helper functions in handlers.
        stateTables = {}, -- tables are... tables.

        gear = {},
        setBonuses = {},

        hooks = {},
        funcHooks = {},
        phases = {},
        interrupts = {},

        dual_cast = {},

        packs = {},
        options = {},

        variables = {}
    }

    class.num = class.num + 1

    for key, func in pairs( HekiliSpecMixin ) do
        spec[ key ] = func
    end    class.specs[ id ] = spec
    
    -- Copy shared abilities from spec 0 (all) to this spec (but not to spec 0 itself)
    if id ~= 0 and class.specs[0] then
        local copiedCount = 0
        for abilityKey, ability in pairs(class.specs[0].abilities) do
            if not spec.abilities[abilityKey] then
                spec.abilities[abilityKey] = ability
                copiedCount = copiedCount + 1
            end
        end
        -- Also ensure they're in the global abilities table
        for abilityKey, ability in pairs(class.specs[0].abilities) do
            if not class.abilities[abilityKey] then
                class.abilities[abilityKey] = ability
            end
        end
        if copiedCount > 0 then
            -- Shared abilities copied successfully
        end
    end
    
    return spec
end

function Hekili:GetSpecialization( specID )
    if not specID then return class.specs[ 0 ] end
    return class.specs[ specID ]
end


class.file = UnitClassBase( "player" )
local all = Hekili:NewSpecialization( 0, "All", "Interface\\Addons\\Hekili\\Textures\\LOGO-WHITE.blp" )

------------------------------
-- SHARED SPELLS/BUFFS/ETC. --
------------------------------

all:RegisterAuras( {

    -- Can be used in GCD calculation.
    shadowform = {
        id = 15473,
        duration = 3600,
        max_stack = 1,
    },

    voidform = {
        id = 194249,
        duration = 15,
        max_stack = 1,
    },

    adrenaline_rush = {
        id = 13750,
        duration = 20,
        max_stack = 1,
    },

    -- Bloodlusts
    ancient_hysteria = {
        id = 90355,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    heroism = {
        id = 32182,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    time_warp = {
        id = 80353,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    netherwinds = {
        id = 160452,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    primal_rage = {
        id = 90355,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    bloodlust = {
        alias = { "ancient_hysteria", "bloodlust_actual", "fury_of_the_aspects", "heroism", "netherwinds", "primal_rage", "time_warp" },
        aliasMode = "first",
        aliasType = "buff",
        duration = 3600,
    },

    bloodlust_actual = {
        id = 2825,
        duration = 40,
        shared = "player",
        max_stack = 1,
    },

    exhaustion = {
        id = 57723,
        duration = 600,
        shared = "player",
        max_stack = 1,
        copy = 390435
    },

    insanity = {
        id = 95809,
        duration = 600,
        shared = "player",
        max_stack = 1
    },

    temporal_displacement = {
        id = 80354,
        duration = 600,
        shared = "player",
        max_stack = 1
    },

    fury_of_the_aspects = {
        id = 90355, -- Ancient Hysteria (MoP bloodlust from Core Hound)
        duration = 40,
        max_stack = 1,
        shared = "player",
    },

    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
        shared = "player",
    },

    sated = {
        alias = { "exhaustion", "insanity", "sated_actual", "temporal_displacement" },
        aliasMode = "first",
        aliasType = "debuff",
        duration = 3600,
    },

    sated_actual = {
        id = 57724,
        duration = 600,
        shared = "player",
        max_stack = 1,
    },

    chaos_brand = {
        id = 1490,
        duration = 3600,
        type = "Magic",
        max_stack = 1,
        shared = "target"
    },
    power_infusion = {
        id = 10060,
        duration = 20,
        max_stack = 1,
        shared = "player",
        dot = "buff"
    },

    battle_shout = {
        id = 6673,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        dot = "buff"
    },

    -- SL Season 3
    old_war = {
        id = 188028,
        duration = 25,
    },

    deadly_grace = {
        id = 188027,
        duration = 25,
    },

    dextrous = {
        id = 146308,
        duration = 20,
    },

    vicious = {
        id = 148903,
        duration = 10,
    },

    -- WoD Legendaries
    archmages_incandescence_agi = {
        id = 177161,
        duration = 10,
    },

    archmages_incandescence_int = {
        id = 177159,
        duration = 10,
    },

    archmages_incandescence_str = {
        id = 177160,
        duration = 10,
    },

    archmages_greater_incandescence_agi = {
        id = 177172,
        duration = 10,
    },

    archmages_greater_incandescence_int = {
        id = 177176,
        duration = 10,
    },

    archmages_greater_incandescence_str = {
        id = 177175,
        duration = 10,
    },

    maalus = {
        id = 187620,
        duration = 15,
    },

    thorasus = {
        id = 187619,
        duration = 15,
    },

    str_agi_int = {
        duration = 3600,
    },

    stamina = {
        duration = 3600,
    },

    attack_power_multiplier = {
        duration = 3600,
    },

    haste = {
        duration = 3600,
    },

    spell_power_multiplier = {
        duration = 3600,
    },

    critical_strike = {
        duration = 3600,
    },

    mastery = {
        duration = 3600,
    },

    versatility = {
        duration = 3600,
    },



    casting = {
        name = "Casting",
        generate = function( t, auraType )
            local unit = auraType == "debuff" and "target" or "player"

            if unit == "player" or UnitCanAttack( "player", unit ) then
                local spell, _, _, startCast, endCast, _, _, notInterruptible, spellID = UnitCastingInfo( unit )

                if spell then
                    startCast = startCast / 1000
                    endCast = endCast / 1000

                    t.name = spell
                    t.count = 1
                    t.expires = endCast
                    t.applied = startCast
                    t.duration = endCast - startCast
                    t.v1 = spellID
                    t.v2 = notInterruptible and 1 or 0
                    t.v3 = 0
                    t.caster = unit

                    if unit ~= "target" then return end

                    if state.target.is_dummy then
                        -- Pretend that all casts by target dummies are interruptible.
                        if Hekili.ActiveDebug then Hekili:Debug( "Cast '%s' is fake-interruptible", spell ) end
                        t.v2 = 0

                    elseif Hekili.DB.profile.toggles.interrupts.filterCasts and class.spellFilters[ state.instance_id ] and class.interruptibleFilters and not class.interruptibleFilters[ spellID ] then
                        if Hekili.ActiveDebug then Hekili:Debug( "Cast '%s' not interruptible per user preference.", spell ) end
                        t.v2 = 1
                    end

                    return
                end

                spell, _, _, startCast, endCast, _, notInterruptible, spellID = UnitChannelInfo( unit )
                startCast = ( startCast or 0 ) / 1000
                endCast = ( endCast or 0 ) / 1000
                local duration = endCast - startCast

                -- Channels greater than 10 seconds are nonsense.  Probably.
                if spell and duration <= 10 then
                    t.name = spell
                    t.count = 1
                    t.expires = endCast
                    t.applied = startCast
                    t.duration = duration
                    t.v1 = spellID
                    t.v2 = notInterruptible and 1 or 0
                    t.v3 = 1 -- channeled.
                    t.caster = unit

                    if class.abilities[ spellID ] and class.abilities[ spellID ].dontChannel then
                        removeBuff( "casting" )
                        return
                    end

                    if unit ~= "target" then return end

                    if state.target.is_dummy then
                        -- Pretend that all casts by target dummies are interruptible.
                        if Hekili.ActiveDebug then Hekili:Debug( "Channel '%s' is fake-interruptible", spell ) end
                        t.v2 = 0

                    elseif Hekili.DB.profile.toggles.interrupts.filterCasts and class.spellFilters[ state.instance_id ] and class.interruptibleFilters and not class.interruptibleFilters[ spellID ] then
                        if Hekili.ActiveDebug then Hekili:Debug( "Channel '%s' not interruptible per user preference.", spell ) end
                        t.v2 = 1
                    end

                    return
                end
            end

            t.name = "Casting"
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.v1 = 0
            t.v2 = 0
            t.v3 = 0
            t.caster = unit
        end,
    },

    movement = {
        duration = 5,
        max_stack = 1,
        generate = function ()
            local m = buff.movement

            if moving then
                m.count = 1
                m.expires = query_time + 5
                m.applied = query_time
                m.caster = "player"
                return
            end

            m.count = 0
            m.expires = 0
            m.applied = 0
            m.caster = "nobody"
        end,
    },

    -- MoP compatible aura instead of retail repeat_performance
    gift_of_the_naaru = {
        id = 28880,
        duration = 15,
        max_stack = 1,
    },

    berserking = {
        id = 26297, -- Berserking (Troll, MoP ID)
        cast = 0,
        cooldown = 180,
        gcd = "off",
        toggle = "cooldowns",
        handler = function ()
            applyBuff( "berserking" )
        end,
    },

    blood_fury = {
        id = 20572,
        duration = 15,
    },

    shadowmeld = {
        id = 58984,
        duration = 3600,
    },

    -- MoP racial auras
    ancestral_call = {
        id = 33697, -- Blood Fury for casters
        duration = 15,
    },

    arcane_pulse = {
        id = 28880, -- Gift of the Naaru
        duration = 15,
    },

    hyper_organic_light_originator = {
        id = 58984, -- Shadowmeld
        duration = 3600,
    },

    fireblood = {
        id = 65116, -- Stoneform
        duration = 8,
    },

    stoneform = {
        id = 65116,
        duration = 8,
    },

    war_stomp = {
        id = 20549,
        duration = 2,
    },

    out_of_range = {
        generate = function ( oor )
            oor.rangeSpell = rawget( oor, "rangeSpell" ) or settings.spec.rangeChecker or class.specs[ state.spec.id ].ranges[ 1 ]

            if LSR.IsSpellInRange( class.abilities[ oor.rangeSpell ].name, "target" ) ~= 1 then
                oor.count = 1
                oor.applied = query_time
                oor.expires = query_time + 3600
                oor.caster = "player"
                oor.v1 = oor.rangeSpell
                return
            end

            oor.count = 0
            oor.applied = 0
            oor.expires = 0
            oor.caster = "nobody"
        end,
    },

    loss_of_control = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = "none", 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )

                    if event.lockoutSchool == 0 and event.startTime and event.startTime > 0 and event.timeRemaining and event.timeRemaining > 0 and event.timeRemaining > remains then
                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    disoriented = {  -- Disorients (e.g., Polymorph, Dragon’s Breath, Blind)
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = "none", 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )

                    if event.locType == "CONFUSE"
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    feared = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = "none", 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )

                    if ( event.locType == "FEAR" or event.locType == "FEAR_MECHANIC" or event.locType == "HORROR" )
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    incapacitated = {  -- Effects like Sap, Freezing Trap, Gouge
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = "none", 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )



                    if event.locType == "STUN"
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
        copy = "sapped"
    },

    rooted = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = "none", 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )

                    if event.locType == "ROOT" and event.startTime and event.startTime > 0 and event.timeRemaining and event.timeRemaining > 0 and event.timeRemaining > remains then
                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    snared = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = "none", 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )

                    if event.locType == "SNARE" and event.startTime and event.startTime > 0 and event.timeRemaining and event.timeRemaining > 0 and event.timeRemaining > remains then
                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
        copy = "slowed"
    },

    stunned = {  -- Shorter stuns (e.g., Kidney Shot, Cheap Shot, Bash)
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = "none", 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )

                    if event.locType == "STUN_MECHANIC"
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    dispellable_curse = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Curse" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_poison = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Poison" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_disease = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Disease" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_magic = {
        generate = function( t, auraType )
            if auraType == "buff" then
                local i = 1
                local name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )

                while( name ) do
                    if debuffType == "Magic" and canDispel then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )
                end

                if canDispel then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end

            else
                local i = 1
                local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

                while( name ) do
                    if debuffType == "Magic" then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
                end

                if name then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end

            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    stealable_magic = {
        generate = function( t )
            if UnitCanAttack( "player", "target" ) then
                local i = 1
                local name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )

                while( name ) do
                    if debuffType == "Magic" and canDispel then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )
                end

                if canDispel then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    reversible_magic = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Magic" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_enrage = {
        generate = function( t )
            if UnitCanAttack( "player", "target" ) then
                local i = 1
                local name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )

                while( name ) do
                    if debuffType == "" and canDispel then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )
                end

                if canDispel then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    all_absorbs = {
        duration = 15,
        max_stack = 1,
        -- TODO: Check if function works.
        generate = function( t, auraType )
            local unit = auraType == "debuff" and "target" or "player"
            local amount = UnitGetTotalAbsorbs( unit )

            if amount > 0 then
                -- t.name = ABSORB
                t.count = 1
                t.expires = now + 10
                t.applied = now - 5
                t.caster = unit
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
        copy = "unravel_absorb"
    },
    
    -- Food and drink auras for MoP Classic
    food = {
        id = 433,
        duration = 30,
        max_stack = 1,
    },
    
    drink = {
        id = 430,
        duration = 30,
        max_stack = 1,
    },
} )

do
    -- MoP Classic Potions - Simplified for compatibility
    local mop_potions = {
        {
            name = "virmen_bite",
            item = 76089,
            duration = 25
        },
        {
            name = "potion_of_mogu_power", 
            item = 76093,
            duration = 25
        },
        {
            name = "potion_of_the_jade_serpent",
            item = 76092,
            duration = 25
        },
        {
            name = "flask_of_spring_blossoms",
            item = 76083,
            duration = 3600
        },
        {
            name = "flask_of_the_warm_sun",
            item = 76084,
            duration = 3600
        },
        {
            name = "flask_of_falling_leaves",
            item = 76085,
            duration = 3600
        },
        {
            name = "flask_of_the_earth",
            item = 76086,
            duration = 3600
        },
        {
            name = "flask_of_winter_bite",
            item = 76087,
            duration = 3600
        }
    }

    -- Register generic potion aura
    all:RegisterAura( "potion", {
        duration = 30,
        max_stack = 1,
    } )

    local first_potion, first_potion_key
    local potion_items = {}

    all:RegisterHook( "reset_precast", function ()
        wipe( potion_items )
        for _, potion in ipairs( mop_potions ) do
            if GetItemCount( potion.item, false ) > 0 then
                potion_items[ potion.name ] = potion.item
                if not first_potion then
                    first_potion = potion.item
                    first_potion_key = potion.name
                end
            end
        end
    end )

    for _, potion in ipairs( mop_potions ) do
        local name, link, _, _, _, _, _, _, _, texture = GetItemInfo( potion.item )
        
        all:RegisterAbility( potion.name, {
            name = name or potion.name,
            listName = link or name or potion.name,
            cast = 0,
            cooldown = potion.duration < 100 and 60 or 0, -- Potions have 60s CD, flasks don't
            gcd = "off",

            startsCombat = false,
            toggle = "potions",

            item = potion.item,
            bagItem = true,
            texture = texture,

            usable = function ()
                return GetItemCount( potion.item ) > 0, "requires " .. (name or potion.name) .. " in bags"
            end,

            readyTime = function ()
                local start, duration = GetItemCooldown( potion.item )
                return max( 0, start + duration - query_time )
            end,

            handler = function ()
                applyBuff( potion.name, potion.duration )
            end,
        } )

        -- Register aura for the potion
        all:RegisterAura( potion.name, {
            duration = potion.duration,
            max_stack = 1,
        } )

        class.abilities[ potion.name ] = all.abilities[ potion.name ]
        class.potions[ potion.name ] = {
            name = name or potion.name,
            link = link or name or potion.name,
            item = potion.item
        }

        class.potionList[ potion.name ] = "|T" .. (texture or 136243) .. ":0|t |cff00ccff[" .. (name or potion.name) .. "]|r"
    end

    -- Generic potion ability
    all:RegisterAbility( "potion", {
        name = "Potion",
        listName = '|T136243:0|t |cff00ccff[Potion]|r',
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        toggle = "potions",

        item = function()
            return first_potion or 76089 -- Default to Virmen Bite
        end,
        bagItem = true,

        usable = function ()
            return first_potion ~= nil, "no valid potions found in inventory"
        end,

        handler = function ()
            if first_potion_key and all.abilities[ first_potion_key ] then
                all.abilities[ first_potion_key ].handler()
            else
                applyBuff( "potion", 25 )
            end
        end,

        copy = "potion_default"
    } )
end




local gotn_classes = {
    WARRIOR = 28880,
    MONK = 121093,
    DEATHKNIGHT = 59545,
    SHAMAN = 59547,
    HUNTER = 59543,
    PRIEST = 59544,
    MAGE = 59548,
    PALADIN = 59542,
    ROGUE = 370626
}

local baseClass = UnitClassBase( "player" ) or "WARRIOR"

all:RegisterAura( "gift_of_the_naaru", {
    id = gotn_classes[ baseClass ],
    duration = 5,
    max_stack = 1,
    copy = { 28800, 121093, 59545, 59547, 59543, 59544, 59548, 59542, 370626 }
} )

all:RegisterAbility( "gift_of_the_naaru", {
    id = gotn_classes[ baseClass ],
    cast = 0,
    cooldown = 180,
    gcd = "off",

    handler = function ()
        applyBuff( "gift_of_the_naaru" )
    end,
} )


all:RegisterAbilities( {
    global_cooldown = {
        id = 61304,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        unlisted = true,
        known = function () return true end,
    },
} )

-- MoP Classic/Classic compatible racial abilities only
-- Blood Fury spell IDs vary by class (whether you need AP/Int/both).
local bf_classes = {
    DEATHKNIGHT = 20572,
    HUNTER = 20572,
    MAGE = 33702,
    MONK = 33697,
    ROGUE = 20572,
    SHAMAN = 33697,
    WARLOCK = 33702,
    WARRIOR = 20572,
    PRIEST = 33702
}

all:RegisterAbilities( {
    blood_fury = {
        id = function () return bf_classes[ class.file ] or 20572 end,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "cooldowns",

        -- usable = function () return race.orc end,
        handler = function ()
            applyBuff( "blood_fury", 15 )
        end,

        copy = { 33702, 20572, 33697 },
    },

    arcane_torrent = {
        id = function ()
            -- Version-specific spell IDs for Arcane Torrent
            if Hekili.IsMoP() then
                if class.file == "MAGE"         then return 28730 end
                if class.file == "PALADIN"      then return 28730 end
                if class.file == "PRIEST"       then return 28730 end
                if class.file == "WARLOCK"      then return 28730 end
                if class.file == "MONK"         then return 129597 end
                if class.file == "WARRIOR"      then return 69179 end
                if class.file == "ROGUE"        then return 25046 end
                if class.file == "DEATHKNIGHT"  then return 50613 end
                if class.file == "HUNTER"       then return 80483 end
                return 28730
            elseif Hekili.IsRetail() then
                -- Retail spell IDs
                if class.file == "PALADIN"      then return 155145 end
                if class.file == "MONK"         then return 129597 end
                if class.file == "DEATHKNIGHT"  then return  50613 end
                if class.file == "WARRIOR"      then return  69179 end
                if class.file == "ROGUE"        then return  25046 end
                if class.file == "HUNTER"       then return  80483 end
                if class.file == "DEMONHUNTER"  then return 202719 end
                if class.file == "PRIEST"       then return 232633 end
                return 28730
            else
                -- Default/Classic spell IDs
                if class.file == "DEATHKNIGHT"  then return  50613 end
                if class.file == "ROGUE"        then return  25046 end
                return 28730
            end
        end,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        -- It does start combat if there are enemies in range, but we often use it precombat for resources.
        startsCombat = false,

        -- usable = function () return race.blood_elf end,
        toggle = "cooldowns",

        handler = function ()
            if Hekili.IsMoP() then
                if class.file == "MAGE"         then gain( 2, "mana" ) end
                if class.file == "PALADIN"      then gain( 2, "mana" ) end
                if class.file == "PRIEST"       then gain( 2, "mana" ) end
                if class.file == "WARLOCK"      then gain( 2, "mana" ) end
                if class.file == "MONK"         then gain( 1, "chi" ) end
                if class.file == "WARRIOR"      then gain( 15, "rage" ) end
                if class.file == "ROGUE"        then gain( 15, "energy" ) end
                if class.file == "DEATHKNIGHT"  then gain( 15, "runic_power" ) end
                if class.file == "HUNTER"       then gain( 15, "focus" ) end
            elseif Hekili.IsRetail() then
                if class.file == "DEATHKNIGHT"  then gain( 20, "runic_power" ) end
                if class.file == "HUNTER"       then gain( 15, "focus" ) end
                if class.file == "MONK"         then gain( 1, "chi" ) end
                if class.file == "PALADIN"      then gain( 1, "holy_power" ) end
                if class.file == "ROGUE"        then gain( 15, "energy" ) end
                if class.file == "WARRIOR"      then gain( 15, "rage" ) end
                if class.file == "DEMONHUNTER"  then gain( 15, "fury" ) end
                if class.file == "PRIEST"       then gain( 15, "insanity" ) end
            end
            removeBuff( "dispellable_magic" )
        end,

        copy = { 155145, 129597, 50613, 69179, 25046, 80483, 202719, 232633 }
    },

    will_to_survive = {
        id = 59752,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "defensives",
    },

    shadowmeld = {
        id = 58984,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        usable = function ()
            if not boss or solo then return false, "requires boss fight or group (to avoid resetting)" end
            if moving then return false, "can't shadowmeld while moving" end
            return true
        end,

        handler = function ()
            applyBuff( "shadowmeld" )
        end,
    },

    berserking = {
        id = 26297,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "cooldowns",

        -- usable = function () return race.troll end,
        handler = function ()
            applyBuff( "berserking", 10 )
        end,
    },

    stoneform = {
        id = 20594,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "defensives",

        buff = function()
            local aura, remains = "dispellable_poison", buff.dispellable_poison.remains

            for _, effect in pairs( { "dispellable_disease", "dispellable_curse", "dispellable_magic", "dispellable_bleed" } ) do
                local rem = buff[ effect ].remains
                if rem > remains then
                    aura = effect
                    remains = rem
                end
            end

            return aura
        end,

        handler = function ()
            removeBuff( "dispellable_poison" )
            removeBuff( "dispellable_disease" )
            removeBuff( "dispellable_curse" )
            removeBuff( "dispellable_magic" )
            removeBuff( "dispellable_bleed" )

            applyBuff( "stoneform" )
        end,

        auras = {
            stoneform = {
                id = 65116,
                duration = 8,
                max_stack = 1
            }
        }
    },
    -- INTERNAL HANDLERS
    call_action_list = {
        name = "|cff00ccff[Call Action List]|r",
        listName = '|T136243:0|t |cff00ccff[Call Action List]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        known = function() return true end,
        usable = function() return true end,
    },

    run_action_list = {
        name = "|cff00ccff[Run Action List]|r",
        listName = '|T136243:0|t |cff00ccff[Run Action List]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        known = function() return true end,
        usable = function() return true end,
    },    wait = {
        name = "|cff00ccff[Wait]|r",
        listName = '|T136243:0|t |cff00ccff[Wait]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        known = function() return true end,
        usable = function() return true end,
    },

    pool_resource = {
        name = "|cff00ccff[Pool Resource]|r",
        listName = "|T136243:0|t |cff00ccff[Pool Resource]|r",
        cast = 0,
        cooldown = 0,
        gcd = "off",
        known = function() return true end,
        usable = function() return true end,
    },    cancel_action = {
        name = "|cff00ccff[Cancel Action]|r",
        listName = "|T136243:0|t |cff00ccff[Cancel Action]|r",
        cast = 0,
        cooldown = 0,
        gcd = "off",
        known = function() return true end,

        usable = function ()
            local a = args.action_name
            local ability = class.abilities[ a ]
            if not a or not ability then return false, "no action identified" end
            if buff.casting.down or buff.casting.v3 ~= 1 then return false, "not channeling" end
            if buff.casting.v1 ~= ability.id then return false, "not channeling " .. a end
            return true
        end,
        timeToReady = function () return gcd.remains end,
    },

    variable = {
        name = "|cff00ccff[Variable]|r",
        listName = '|T136243:0|t |cff00ccff[Variable]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        known = function() return true end,
        usable = function() return true end,
    },

    healthstone = {
        name = "Healthstone",
        listName = "|T538745:0|t |cff00ccff[Healthstone]|r",
        cast = 0,
        cooldown = function () return time > 0 and 3600 or 60 end,
        gcd = "off",

        item = function() return talent.pact_of_gluttony.enabled and 224464 or 5512 end,
        items = { 224464, 5512 },
        bagItem = true,

        startsCombat = false,
        texture = function() return talent.pact_of_gluttony.enabled and 538744 or 538745 end,

        usable = function ()
            local item = talent.pact_of_gluttony.enabled and 224464 or 5512
            if GetItemCount( item ) == 0 then return false, "requires healthstone in bags"
            elseif not IsUsableItem( item ) then return false, "healthstone on CD"
            elseif health.current >= health.max then return false, "must be damaged" end
            return true
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( talent.pact_of_gluttony.enabled and 224464 or 5512 )
            return max( 0, start + duration - query_time )
        end,

        handler = function ()
            gain( 0.25 * health.max, "health" )
        end,
    },

    weyrnstone = {
        name = function () return ( GetItemInfo( 205146 ) ) or "Weyrnstone" end,
        listName = function ()
            local _, link, _, _, _, _, _, _, _, tex = GetItemInfo( 205146 )
            if link and tex then return "|T" .. tex .. ":0|t " .. link end
            return "|cff00ccff[Weyrnstone]|r"
        end,
        cast = 1.5,
        cooldown = 120,
        gcd = "spell",

        item = 205146,
        bagItem = true,

        startsCombat = false,
        texture = 5199618,

        usable = function ()
            if GetItemCount( 205146 ) == 0 then return false, "requires weyrnstone in bags" end
            if solo then return false, "must have an ally to teleport" end
            return true
        end,

        readyTime = function ()
            local start, duration = GetItemCooldown( 205146 )
            return max( 0, start + duration - query_time )
        end,

        handler = function ()
        end,

        copy = { "use_weyrnstone", "active_weyrnstone" }
    },

    cancel_buff = {
        name = "|cff00ccff[Cancel Buff]|r",
        listName = '|T136243:0|t |cff00ccff[Cancel Buff]|r',
        cast = 0,
        gcd = "off",

        startsCombat = false,

        buff = function () return args.buff_name or nil end,

        indicator = "cancel",
        texture = function ()
            if not args.buff_name then return 134400 end

            local a = class.auras[ args.buff_name ]
            -- if not a then return 134400 end
            if a.texture then return a.texture end

            a = a and a.id
            a = a and GetSpellTexture( a )

            return a or 134400
        end,

        usable = function () return args.buff_name ~= nil, "no buff name detected" end,
        timeToReady = function () return gcd.remains end,
        handler = function ()
            if not args.buff_name then return end

            local cancel = args.buff_name and buff[ args.buff_name ]
            cancel = cancel and rawget( cancel, "onCancel" )

            if cancel then
                cancel()
                return
            end

            removeBuff( args.buff_name )
        end,
    },

    null_cooldown = {
        name = "|cff00ccff[Null Cooldown]|r",
        listName = "|T136243:0|t |cff00ccff[Null Cooldown]|r",
        cast = 0,
        cooldown = 0.001,
        gcd = "off",

        startsCombat = false,

        unlisted = true
    },

    trinket1 = {
        name = "|cff00ccff[Trinket #1]|r",
        listName = "|T136243:0|t |cff00ccff[Trinket #1]|r",
        cast = 0,
        cooldown = 600,
        gcd = "off",

        usable = false,

        copy = "actual_trinket1",
    },

    trinket2 = {
        name = "|cff00ccff[Trinket #2]|r",
        listName = "|T136243:0|t |cff00ccff[Trinket #2]|r",
        cast = 0,
        cooldown = 600,
        gcd = "off",

        usable = false,

        copy = "actual_trinket2",
    },

    main_hand = {
        name = "|cff00ccff[" .. INVTYPE_WEAPONMAINHAND .. "]|r",
        listName = "|T136243:0|t |cff00ccff[" .. INVTYPE_WEAPONMAINHAND .. "]|r",
        cast = 0,
        cooldown = 600,
        gcd = "off",

        usable = false,

        copy = "actual_main_hand",
    }
} )


-- Use Items
do
    -- Should handle trinkets/items internally.
    -- 1.  Check APLs and don't try to recommend items that have their own APL entries.
    -- 2.  Respect item preferences registered in spec options.

    all:RegisterAbility( "use_items", {
        name = "Use Items",
        listName = "|T136243:0|t |cff00ccff[Use Items]|r",
        cast = 0,
        cooldown = 120,
        gcd = "off",
    } )

    all:RegisterAbility( "unusable_trinket", {
        name = "Unusable Trinket",
        listName = "|T136240:0|t |cff00ccff[Unusable Trinket]|r",
        cast = 0,
        cooldown = 180,
        gcd = "off",

        usable = false,
        unlisted = true
    } )

    all:RegisterAbility( "heart_essence", {
        name = function () return ( GetItemInfo( 158075 ) ) or "Heart Essence" end,
        listName = function ()
            local _, link, _, _, _, _, _, _, _, tex = GetItemInfo( 158075 )
            if link and tex then return "|T" .. tex .. ":0|t " .. link end
            return "|cff00ccff[Heart Essence]|r"
        end,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        item = 158075,
        essence = true,

        toggle = "essences",

        usable = function () return false, "your equipped major essence is supported elsewhere in the priority or is not an active ability" end
    } )
end


-- x.x - Heirloom Trinket(s)
all:RegisterAbility( "touch_of_the_void", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 128318,
    toggle = "cooldowns",
} )

-- MoP Classic does not have the complex PvP trinket system from retail
-- Basic trinket usage is handled by the general trinket system

-- BREWFEST
all:RegisterAbility( "brawlers_statue", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 117357,
    toggle = "defensives",

    handler = function ()
        applyBuff( "drunken_evasiveness" )
    end
} )

all:RegisterAura( "drunken_evasiveness", {
    id = 127967,
    duration = 20,
    max_stack = 1
} )


-- HALLOW'S END
all:RegisterAbility( "the_horsemans_sinister_slicer", {
    cast = 0,
    cooldown = 600,
    gcd = "off",

    item = 117356,
    toggle = "cooldowns",
} )


ns.addToggle = function( name, default, optionName, optionDesc )

    table.insert( class.toggles, {
        name = name,
        state = default,
        option = optionName,
        oDesc = optionDesc
    } )

    if Hekili.DB.profile[ 'Toggle State: ' .. name ] == nil then
        Hekili.DB.profile[ 'Toggle State: ' .. name ] = default
    end

end


ns.addSetting = function( name, default, options )

    table.insert( class.settings, {
        name = name,
        state = default,
        option = options
    } )

    if Hekili.DB.profile[ 'Class Option: ' .. name ] == nil then
        Hekili.DB.profile[ 'Class Option: ' ..name ] = default
    end

end


ns.addWhitespace = function( name, size )

    table.insert( class.settings, {
        name = name,
        option = {
            name = " ",
            type = "description",
            desc = " ",
            width = size
        }
    } )

end


ns.addHook = function( hook, func )
    insert( class.hooks[ hook ], func )
end


do
    local inProgress = {}
    local vars = {}

    local function load_args( ... )
        local count = select( "#", ... )
        if count == 0 then return end

        for i = 1, count do
            vars[ i ] = select( i, ... )
        end
    end    ns.callHook = function( event, ... )
        if not class or not class.hooks or not class.hooks[ event ] or inProgress[ event ] then return ... end
        wipe( vars )
        load_args( ... )

        inProgress[ event ] = true
        for i, hook in ipairs( class.hooks[ event ] ) do
            load_args( hook( unpack( vars ) ) )
        end
        inProgress[ event ] = nil

        return unpack( vars )
    end
end


ns.registerCustomVariable = function( var, default )
    state[ var ] = default
end




ns.setClass = function( name )
    -- deprecated.
    --class.file = name
end


function ns.setRange( value )
    class.range = value
end


local function storeAbilityElements( key, values )

    local ability = class.abilities[ key ]

    if not ability then
        ns.Error( "storeAbilityElements( " .. key .. " ) - no such ability in abilities table." )
        return
    end

    for k, v in pairs( values ) do
        ability.elem[ k ] = type( v ) == "function" and setfenv( v, state ) or v
    end

end
ns.storeAbilityElements = storeAbilityElements


local function modifyElement( t, k, elem, value )

    local entry = class[ t ][ k ]

    if not entry then
        ns.Error( "modifyElement() - no such key '" .. k .. "' in '" .. t .. "' table." )
        return
    end

    if type( value ) == "function" then
        entry.mods[ elem ] = setfenv( value, Hekili.State )
    else
        entry.elem[ elem ] = value
    end

end
ns.modifyElement = modifyElement



local function setUsableItemCooldown( cd )
    state.setCooldown( "usable_items", cd or 10 )
end


-- For Trinket Settings.
class.itemSettings = {}

local function addItemSettings( key, itemID, options )

    options = options or {}

    --[[ options.icon = {
        type = "description",
        name = function () return select( 2, GetItemInfo( itemID ) ) or format( "[%d]", itemID )  end,
        order = 1,
        image = function ()
            local tex = select( 10, GetItemInfo( itemID ) )
            if tex then
                return tex, 50, 50
            end
            return nil
        end,
        imageCoords = { 0.1, 0.9, 0.1, 0.9 },
        width = "full",
        fontSize = "large"
    } ]]

    options.disabled = {
        type = "toggle",
        name = function () return format( "Disable %s via |cff00ccff[Use Items]|r", select( 2, GetItemInfo( itemID ) ) or ( "[" .. itemID .. "]" ) ) end,
        desc = function( info )
            local output = "If disabled, the addon will not recommend this item via the |cff00ccff[Use Items]|r action.  " ..
                "You can still manually include the item in your action lists with your own tailored criteria."
            return output
        end,
        order = 25,
        width = "full"
    }

    options.minimum = {
        type = "range",
        name = "Minimum Targets",
        desc = "The addon will only recommend this trinket (via |cff00ccff[Use Items]|r) when there are at least this many targets available to hit.",
        order = 26,
        width = "full",
        min = 1,
        max = 10,
        step = 1
    }

    options.maximum = {
        type = "range",
        name = "Maximum Targets",
        desc = "The addon will only recommend this trinket (via |cff00ccff[Use Items]|r) when there are no more than this many targets detected.\n\n" ..
            "This setting is ignored if set to 0.",
        order = 27,
        width = "full",
        min = 0,
        max = 10,
        step = 1
    }

    class.itemSettings[ itemID ] = {
        key = key,
        name = function () return select( 2, GetItemInfo( itemID ) ) or ( "[" .. itemID .. "]" ) end,
        item = itemID,
        options = options,
    }

end


--[[ local function addUsableItem( key, id )
    class.items = class.items or {}
    class.items[ key ] = id

    addGearSet( key, id )
    addItemSettings( key, id )
end
ns.addUsableItem = addUsableItem ]]


function Hekili:GetAbilityInfo( index )

    local ability = class.abilities[ index ]

    if not ability then return end

    -- Decide if more details are needed later.
    return ability.id, ability.name, ability.key, ability.item
end

class.interrupts = {}


local function addPet( key, permanent )
    state.pet[ key ] = rawget( state.pet, key ) or {}
    state.pet[ key ].name = key
    state.pet[ key ].expires = 0

    ns.commitKey( key )
end
ns.addPet = addPet


local function addStance( key, spellID )
    class.stances[ key ] = spellID
    ns.commitKey( key )
end
ns.addStance = addStance


local function setRole( key )

    for k,v in pairs( state.role ) do
        state.role[ k ] = nil
    end

    state.role[ key ] = true

end
ns.setRole = setRole


function Hekili:GetActiveSpecOption( opt )
    if not self.currentSpecOpts then return end
    return self.currentSpecOpts[ opt ]
end


function Hekili:GetActivePack()
    return self:GetActiveSpecOption( "package" )
end


Hekili.SpecChangeHistory = {}

function Hekili:SpecializationChanged()
    local currentSpec, currentID, currentName
    
    -- SpecializationChanged event handler for non-retail versions
    
    -- Use MoP-compatible spec detection
    if Hekili.IsRetail() then
        currentSpec = GetSpecialization()
        currentID = GetSpecializationInfo( currentSpec )
        print("DEBUG: Using Retail spec detection - currentSpec:", currentSpec, "currentID:", currentID)
    else
        -- MoP Classic: Use our custom spec detection logic
        currentSpec = GetSpecialization and GetSpecialization() or 1
        currentID = ns.getSpecializationID(currentSpec)
        currentName = ns.getSpecializationKey(currentID)
        print("DEBUG: Using MoP spec detection - currentSpec:", currentSpec, "currentID:", currentID, "currentName:", currentName)
    end

    if currentID == nil then
        self.PendingSpecializationChange = true
        return
    end

    self.PendingSpecializationChange = false
    self:ForceUpdate( "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" )

    insert( self.SpecChangeHistory, {
        spec = currentID,
        time = GetTime(),
        bt = debugstack()
    } )

    for k, _ in pairs( state.spec ) do
        state.spec[ k ] = nil
    end

    for key in pairs( GetResourceInfo() ) do
        state[ key ] = nil
        class[ key ] = nil
    end

    class.primaryResource = nil

    wipe( state.buff )
    wipe( state.debuff )

    wipe( class.auras )
    wipe( class.abilities )
    wipe( class.hooks )
    wipe( class.talents )
    wipe( class.pvptalents )
    wipe( class.powers )
    wipe( class.gear )
    wipe( class.setBonuses )
    wipe( class.packs )
    wipe( class.resources )
    wipe( class.resourceAuras )

    wipe( class.pets )

    local specs = {}    -- If the player does not have a specialization, use their first spec instead.
    if Hekili.IsRetail() and currentSpec == 5 then
        currentSpec = 1
        currentID = GetSpecializationInfo( 1 )
    end

    if Hekili.IsRetail() then
        for i = 1, 4 do
            local id, name, _, _, role, primaryStat = GetSpecializationInfo( i )

            if not id then break end

            if i == currentSpec then
                insert( specs, 1, id )

                state.spec.id = id
                state.spec.name = name
                state.spec.key = getSpecializationKey( id )

                for k in pairs( state.role ) do
                    state.role[ k ] = false
                end

                if role == "DAMAGER" then
                    state.role.attack = true
                elseif role == "TANK" then
                    state.role.tank = true
                else
                    state.role.healer = true
                end

                if primaryStat == 1 then
                    state.spec.primaryStat = "strength"
                elseif primaryStat == 2 then
                    state.spec.primaryStat = "agility"
                else
                    state.spec.primaryStat = "intellect"
                end

                state.spec[ state.spec.key ] = true
            else
                insert( specs, id )
            end
        end
    else
        -- MoP Classic: Use the detected spec directly
        insert( specs, 1, currentID )
        
        state.spec.id = currentID
        state.spec.name = currentName or "feral"
        state.spec.key = getSpecializationKey( currentID )

        -- Set role based on spec for MoP Druid specs
        for k in pairs( state.role ) do
            state.role[ k ] = false
        end
        
        if currentID == 103 then -- Feral
            state.role.attack = true
            state.spec.primaryStat = "agility"
        elseif currentID == 104 then -- Guardian
            state.role.tank = true
            state.spec.primaryStat = "agility"
        elseif currentID == 102 then -- Balance
            state.role.attack = true
            state.spec.primaryStat = "intellect"
        elseif currentID == 105 then -- Restoration
            state.role.healer = true
            state.spec.primaryStat = "intellect"
        else
            state.role.attack = true -- Default fallback
        end
        
        state.spec[ state.spec.key ] = true
    end

    insert( specs, 0 )


    for key in pairs( GetResourceInfo() ) do
        state[ key ] = nil
        class[ key ] = nil
    end
    if rawget( state, "rune" ) then state.rune = nil; class.rune = nil; end

    for k in pairs( class.resourceAuras ) do
        class.resourceAuras[ k ] = nil
    end

    class.primaryResource = nil

    for k in pairs( class.stateTables ) do
        rawset( state, k, nil )
        class.stateTables[ k ] = nil
    end

    for k in pairs( class.stateFuncs ) do
        rawset( state, k, nil )
        class.stateFuncs[ k ] = nil
    end

    for k in pairs( class.stateExprs ) do
        class.stateExprs[ k ] = nil
    end

    self.currentSpec = nil
    self.currentSpecOpts = nil

    for i, specID in ipairs( specs ) do
        local spec = class.specs[ specID ]        if spec then
            if specID == currentID then
                self.currentSpec = spec
                self.currentSpecOpts = rawget( self.DB.profile.specs, specID )
                
                -- Create default spec profile if it doesn't exist
                if not self.currentSpecOpts then
                    self.DB.profile.specs[ specID ] = self.DB.profile.specs[ specID ] or {}
                    self.currentSpecOpts = self.DB.profile.specs[ specID ]
                end
                
                state.settings.spec = self.currentSpecOpts

                state.spec.can_dual_cast = spec.can_dual_cast
                state.spec.dual_cast = spec.dual_cast

                for res, model in pairs( spec.resources ) do
                    class.resources[ res ] = model
                    state[ res ] = model.state
                end
                if rawget( state, "runes" ) then state.rune = nil; class.rune = nil; end

                for k,v in pairs( spec.resourceAuras ) do
                    class.resourceAuras[ k ] = v
                end

                class.primaryResource = spec.primaryResource

                for talent, id in pairs( spec.talents ) do
                    class.talents[ talent ] = id
                end

                for talent, id in pairs( spec.pvptalents ) do
                    class.pvptalents[ talent ] = id
                end

                class.variables = spec.variables

                class.potionList.default = "|T967533:0|t |cFFFFD100Default|r"
            end

            if specID == currentID or specID == 0 then
                for event, hooks in pairs( spec.hooks ) do
                    for _, hook in ipairs( hooks ) do
                        class.hooks[ event ] = class.hooks[ event ] or {}
                        insert( class.hooks[ event ], hook )
                    end
                end
            end

            for res, model in pairs( spec.resources ) do
                if not class.resources[ res ] then
                    class.resources[ res ] = model
                    state[ res ] = model.state
                end
            end

            if rawget( state, "runes" ) then state.rune = nil; class.rune = nil; end

            for k, v in pairs( spec.auras ) do
                if not class.auras[ k ] then class.auras[ k ] = v end
            end

            for k, v in pairs( spec.powers ) do
                if not class.powers[ k ] then class.powers[ k ] = v end
            end

            for k, v in pairs( spec.abilities ) do
                if not class.abilities[ k ] then class.abilities[ k ] = v end
            end

            for k, v in pairs( spec.gear ) do
                if not class.gear[ k ] then class.gear[ k ] = v end
            end

            for k, v in pairs( spec.setBonuses ) do
                if not class.setBonuses[ k ] then class.setBonuses[ k ] = v end
            end

            for k, v in pairs( spec.pets ) do
                if not class.pets[ k ] then class.pets[ k ] = v end
            end

            for k, v in pairs( spec.totems ) do
                if not class.totems[ k ] then class.totems[ k ] = v end
            end

            for k, v in pairs( spec.packs ) do
                if not class.packs[ k ] then class.packs[ k ] = v end
            end

            for name, func in pairs( spec.stateExprs ) do
                if not class.stateExprs[ name ] then
                    if rawget( state, name ) then state[ name ] = nil end
                    class.stateExprs[ name ] = func
                end
            end

            for name, func in pairs( spec.stateFuncs ) do
                if not class.stateFuncs[ name ] then
                    if rawget( state, name ) then
                        Hekili:Error( "Cannot RegisterStateFunc for an existing expression ( " .. spec.name .. " - " .. name .. " )." )
                    else
                        class.stateFuncs[ name ] = func
                        rawset( state, name, func )
                        -- Hekili:Error( "Not real error, registered " .. name .. " for " .. spec.name .. " (RSF)." )
                    end
                end
            end

            for name, t in pairs( spec.stateTables ) do
                if not class.stateTables[ name ] then
                    if rawget( state, name ) then
                        Hekili:Error( "Cannot RegisterStateTable for an existing expression ( " .. spec.name .. " - " .. name .. " )." )
                    else
                        class.stateTables[ name ] = t
                        rawset( state, name, t )
                        -- Hekili:Error( "Not real error, registered " .. name .. " for " .. spec.name .. " (RST)." )
                    end
                end
            end

            if spec.id > 0 then
                local s = rawget( Hekili.DB.profile.specs, spec.id )

                if s then
                    for k, v in pairs( spec.settings ) do
                        if s.settings[ v.name ] == nil then s.settings[ v.name ] = v.default end
                    end
                end
            end
        end
    end

    for k in pairs( class.abilityList ) do
        local ability = class.abilities[ k ]

        if ability and ability.id > 0 then
            if not ability.texture or not ability.name then
                local data = GetSpellInfo( ability.id )

                if data and data.name and data.iconID then
                    ability.name = ability.name or data.name
                    class.abilityList[ k ] = "|T" .. data.iconID .. ":0|t " .. ability.name
                end
            else
                class.abilityList[ k ] = "|T" .. ability.texture .. ":0|t " .. ability.name
            end
        end
    end

    state.GUID = UnitGUID( "player" )
    state.player.unit = UnitGUID( "player" )

    ns.callHook( "specializationChanged" )

    ns.updateTalents()
    ResetDisabledGearAndSpells()

    state.swings.mh_speed, state.swings.oh_speed = UnitAttackSpeed( "player" )

    HekiliEngine.activeThread = nil
    self:UpdateDisplayVisibility()
    self:UpdateDamageDetectionForCLEU()
end


do
    RegisterEvent( "PLAYER_ENTERING_WORLD", function( event, login, reload )
        if login or reload then
            local currentSpec = GetSpecialization()
            local currentID = GetSpecializationInfo( currentSpec )

            if currentID ~= state.spec.id then
                Hekili:SpecializationChanged()
            end
        end
    end )

    local SpellDisableEvents = {
        CHALLENGE_MODE_START = 1,
        CHALLENGE_MODE_RESET = 1,
        CHALLENGE_MODE_COMPLETED = 1,
        PLAYER_ALIVE = 1,
        ZONE_CHANGED_NEW_AREA = 1,
        QUEST_SESSION_CREATED = 1,
        QUEST_SESSION_DESTROYED = 1,
        QUEST_SESSION_ENABLED_STATE_CHANGED = 1,
        QUEST_SESSION_JOINED = 1,
        QUEST_SESSION_LEFT = 1
    }

    local function CheckSpellsAndGear()
        -- WipeCovenantCache() -- Not available in MoP Classic
        ResetDisabledGearAndSpells()
        ns.updateGear()
    end

    for k in pairs( SpellDisableEvents ) do
        RegisterEvent( k, function( event )
            C_Timer.After( 1, CheckSpellsAndGear )
        end )
    end
end


class.trinkets = {
    [0] = { -- for when nothing is equipped.
    },
}


setmetatable( class.trinkets, {
    __index = function( t, k )
    return t[0]
end
} )

-- Register universal state expressions that all specializations can use
-- These are fundamental state values that should be available across all specs
setfenv( function() 
    -- Universal combat state
    class.stateExprs.in_combat = function()
        return state.combat and state.combat > 0 or false
    end
    
    -- Universal movement state  
    class.stateExprs.moving = function()
        return state.buff and state.buff.moving and state.buff.moving.up or false
    end
    
    -- Universal mounted state
    class.stateExprs.mounted = function()
        return state.buff and state.buff.mounted and state.buff.mounted.up or false
    end
    
    -- Universal bloodlust/heroism state (multiple buff IDs)
    class.stateExprs.bloodlust = function()
        return {
            up = (state.buff and state.buff.bloodlust and state.buff.bloodlust.up) or
                 (state.buff and state.buff.heroism and state.buff.heroism.up) or
                 (state.buff and state.buff.time_warp and state.buff.time_warp.up) or
                 (state.buff and state.buff.ancient_hysteria and state.buff.ancient_hysteria.up) or
                 false,
            down = not ((state.buff and state.buff.bloodlust and state.buff.bloodlust.up) or
                       (state.buff and state.buff.heroism and state.buff.heroism.up) or
                       (state.buff and state.buff.time_warp and state.buff.time_warp.up) or
                       (state.buff and state.buff.ancient_hysteria and state.buff.ancient_hysteria.up)),
            remains = math.max(
                (state.buff and state.buff.bloodlust and state.buff.bloodlust.remains) or 0,
                (state.buff and state.buff.heroism and state.buff.heroism.remains) or 0,
                (state.buff and state.buff.time_warp and state.buff.time_warp.remains) or 0,
                (state.buff and state.buff.ancient_hysteria and state.buff.ancient_hysteria.remains) or 0
            )
        }
    end
    
    -- Universal threat state
    class.stateExprs.threat = function()
        return {
            situation = state.tanking and 3 or (state.aggro and 2 or 1),
            raw = state.tanking and 100 or (state.aggro and 75 or 0),
            scaled = state.tanking and 100 or (state.aggro and 75 or 0),
            current = state.tanking and 100 or (state.aggro and 75 or 0)
        }
    end
    
    -- Universal spell targeting state  
    class.stateExprs.spell_is_targeting = function()
        return state.channeling and state.channeling.spell_id and state.channeling.spell_id > 0 or false
    end
    
    -- Universal focus state (for focus-using classes)
    class.stateExprs.focus = function() 
        return {
            current = state.focus and state.focus.current or 0,
            max = state.focus and state.focus.max or 100,
            pct = state.focus and state.focus.current and state.focus.max and (state.focus.current / state.focus.max * 100) or 0,
            deficit = state.focus and state.focus.current and state.focus.max and (state.focus.max - state.focus.current) or 100,
            regen = state.focus and state.focus.regen or 0,
            time_to_max = state.focus and state.focus.current and state.focus.max and state.focus.regen and 
                         state.focus.regen > 0 and ((state.focus.max - state.focus.current) / state.focus.regen) or 0,
            exists = state.focus ~= nil
        }
    end
end, state )()