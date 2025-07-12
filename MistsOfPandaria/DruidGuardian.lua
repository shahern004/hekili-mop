if not Hekili or not Hekili.NewSpecialization then return end
-- DruidGuardian.lua
-- December 2024 - Rebuilt from retail structure for MoP compatibility

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'DRUID' then return end

local addon, ns = ...
local Hekili = _G[ addon ]

local class, state = Hekili.Class, Hekili.State
local strformat = string.format

local spec = Hekili:NewSpecialization( 104, true )

-- Register Resources
spec:RegisterResource( 1, { -- Rage = 1 in MoP
    -- No special rage mechanics in MoP like retail
} )
spec:RegisterResource( 3 ) -- Energy = 3 in MoP
spec:RegisterResource( 0 ) -- Mana = 0 in MoP

-- Spec configuration for MoP
spec.role = "TANK"
spec.primaryStat = "stamina"
spec.name = "Guardian"

-- No longer need custom spec detection - WeakAuras system handles this in Constants.lua

-- Talents (MoP system - different from retail)
spec:RegisterTalents( {
    -- Row 1 (15)
    feline_swiftness      = { 1, 1, 131768 },
    disorienting_roar     = { 1, 2, 99    },
    savage_defense        = { 1, 3, 62606 },

    -- Row 2 (30)
    thick_hide            = { 2, 1, 16931 },
    renewal               = { 2, 2, 108238 },
    cenarion_ward         = { 2, 3, 102351 },

    -- Row 3 (45)
    faerie_swarm          = { 3, 1, 102355 },
    mass_entanglement     = { 3, 2, 102359 },
    typhoon               = { 3, 3, 132469 },

    -- Row 4 (60)
    soul_of_the_forest    = { 4, 1, 158477 },
    incarnation           = { 4, 2, 102558 },
    force_of_nature       = { 4, 3, 106737 },

    -- Row 5 (75)
    mighty_bash           = { 5, 1, 5211   },
    mass_entanglement_2   = { 5, 2, 102359 },
    heart_of_the_wild     = { 5, 3, 108292 },

    -- Row 6 (90)
    dream_of_cenarius     = { 6, 1, 108373 },
    nature_swiftness      = { 6, 2, 132158 },
    disentanglement       = { 6, 3, 108280 }
} )

-- Gear Sets
spec:RegisterGear( "tier13", 78699, 78700, 78701, 78702, 78703, 78704, 78705, 78706, 78707, 78708 )
spec:RegisterGear( "tier14", 85304, 85305, 85306, 85307, 85308 )
spec:RegisterGear( "tier15", 95941, 95942, 95943, 95944, 95945 )
spec:RegisterGear( "tier16", 99344, 99345, 99346, 99347, 99348 )

-- T14 Set Bonuses
spec:RegisterSetBonuses( "tier14_2pc", 123456, 1, "Mangle has a 10% chance to apply 2 stacks of Lacerate." )
spec:RegisterSetBonuses( "tier14_4pc", 123457, 1, "Savage Defense also provides 20% dodge chance for 6 sec." )

-- T15 Set Bonuses  
spec:RegisterSetBonuses( "tier15_2pc", 123458, 1, "Your melee critical strikes reduce the cooldown of Enrage by 2 sec." )
spec:RegisterSetBonuses( "tier15_4pc", 123459, 1, "Frenzied Regeneration also reduces damage taken by 20%." )

-- T16 Set Bonuses
spec:RegisterSetBonuses( "tier16_2pc", 123460, 1, "Mangle critical strikes grant 1500 mastery for 8 sec." )
spec:RegisterSetBonuses( "tier16_4pc", 123461, 1, "Thrash periodic damage has a chance to reset the cooldown of Mangle." )

-- Auras
spec:RegisterAuras( {
    -- Bear Form
    bear_form = {
        id = 5487,
        duration = 3600,
        max_stack = 1,
    },

    -- Defensive abilities
    barkskin = {
        id = 22812,
        duration = 12,
        max_stack = 1,
    },

    survival_instincts = {
        id = 61336,
        duration = 6,
        max_stack = 1,
    },

    frenzied_regeneration = {
        id = 22842,
        duration = 20,
        max_stack = 1,
    },

    savage_defense = {
        id = 62606,
        duration = 6,
        max_stack = 1,
    },

    -- Offensive abilities
    enrage = {
        id = 5229,
        duration = 10,
        max_stack = 1,
    },

    berserk = {
        id = 50334,
        duration = 15,
        max_stack = 1,
    },

    -- Debuffs
    lacerate = {
        id = 33745,
        duration = 15,
        max_stack = 3,
        tick_time = 3,
    },

    thrash_bear = {
        id = 77758,
        duration = 15,
        max_stack = 3,
        tick_time = 3,
    },

    faerie_fire = {
        id = 770,
        duration = 300,
        max_stack = 1,
    },

    demoralizing_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
    },

    -- Buffs from talents
    incarnation = {
        id = 102558,
        duration = 30,
        max_stack = 1,
    },

    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
    },

    nature_swiftness = {
        id = 132158,
        duration = 8,
        max_stack = 1,
    },

    cenarion_ward = {
        id = 102351,
        duration = 30,
        max_stack = 1,
    },

    -- Other forms
    cat_form = {
        id = 768,
        duration = 3600,
        max_stack = 1,
    },

    moonkin_form = {
        id = 24858,
        duration = 3600,
        max_stack = 1,
    },

    travel_form = {
        id = 783,
        duration = 3600,
        max_stack = 1,
    },

    aquatic_form = {
        id = 1066,
        duration = 3600,
        max_stack = 1,
    },

    -- Generic buffs
    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
    },

    -- Procs and special effects
    tooth_and_claw = {
        id = 135286,
        duration = 6,
        max_stack = 2,
    },

    -- Glyphs
    glyph_of_fae_silence = {
        id = 114302,
        duration = 5,
        max_stack = 1,
    },

    -- Raid buffs/debuffs
    weakened_armor = {
        id = 113746,
        duration = 30,
        max_stack = 3,
    },

    sunder_armor = {
        id = 58567,
        duration = 30,
        max_stack = 3,
    },
} )

-- State Functions
local function rage_spent_recently( amt )
    amt = amt or 1

    for i = 1, #state.recentRageSpent do
        if state.recentRageSpent[i] >= amt then return true end
    end

    return false
end

local function lacerate_up()
    return state.debuff.lacerate.up
end

local function thrash_up()
    return state.debuff.thrash_bear.up
end

-- Abilities
spec:RegisterAbilities( {
    -- Bear Form
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        essential = true,

        handler = function ()
            shift( "bear_form" )
        end,
    },

    -- Basic attacks
    auto_attack = {
        id = 6603,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = true,
        texture = 132938,

        usable = function () return melee.range <= 5 end,
        handler = function ()
            cancelBuff( "prowl" )
        end,
    },

    mangle = {
        id = 33917,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = -5,
        spendType = "rage",

        startsCombat = true,
        texture = 132135,

        form = "bear_form",

        handler = function ()
            if talent.infected_wounds.enabled then
                applyDebuff( "target", "infected_wounds" )
            end
            
            removeBuff( "tooth_and_claw" )
            
            if set_bonus.tier16_4pc == 1 and active_dot.thrash_bear > 0 then
                if math.random() < 0.4 then
                    setCooldown( "mangle", 0 )
                end
            end
        end,
    },

    lacerate = {
        id = 33745,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        startsCombat = true,
        texture = 132131,

        form = "bear_form",

        handler = function ()
            applyDebuff( "target", "lacerate", 15, min( 3, debuff.lacerate.stack + 1 ) )
            
            if talent.tooth_and_claw.enabled then
                if math.random() < 0.4 then
                    applyBuff( "tooth_and_claw", 6, 2 )
                end
            end
        end,
    },

    thrash = {
        id = 77758,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = -5,
        spendType = "rage",

        startsCombat = true,
        texture = 451161,

        form = "bear_form",

        handler = function ()
            applyDebuff( "target", "thrash_bear", 15 )
            
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                for i = 1, applied do
                    if i == 1 then
                        applyDebuff( "target", "thrash_bear", 15 )
                    else
                        applyDebuff( "target" .. i, "thrash_bear", 15 )
                    end
                end
            end
        end,
    },

    maul = {
        id = 6807,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 30,
        spendType = "rage",

        startsCombat = true,
        texture = 132136,

        form = "bear_form",

        handler = function ()
            if buff.tooth_and_claw.up then
                local stacks = buff.tooth_and_claw.stack
                removeBuff( "tooth_and_claw" )
                applyDebuff( "target", "tooth_and_claw_debuff", 6 )
            end
        end,
    },

    swipe = {
        id = 779,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        startsCombat = true,
        texture = 134296,

        form = "bear_form",

        handler = function ()
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                -- Hit multiple enemies
            end
        end,
    },

    -- Defensive abilities
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        defensive = true,

        startsCombat = false,
        texture = 136097,

        handler = function ()
            applyBuff( "barkskin" )
        end,
    },

    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        defensive = true,

        startsCombat = false,
        texture = 236169,

        handler = function ()
            applyBuff( "survival_instincts" )
        end,
    },

    frenzied_regeneration = {
        id = 22842,
        cast = 0,
        cooldown = 90,
        gcd = "off",

        defensive = true,

        startsCombat = false,
        texture = 132091,

        handler = function ()
            applyBuff( "frenzied_regeneration" )
            health.actual = min( health.max, health.actual + ( health.max * 0.3 ) )
        end,
    },

    -- Rage generators
    enrage = {
        id = 5229,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        texture = 136224,

        form = "bear_form",

        handler = function ()
            applyBuff( "enrage" )
            gain( 20, "rage" )
        end,
    },

    berserk = {
        id = 50334,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        startsCombat = false,
        texture = 236149,

        talent = "berserk",

        handler = function ()
            applyBuff( "berserk" )
            setCooldown( "mangle", 0 )
        end,
    },

    -- Utility
    faerie_fire = {
        id = 770, -- Faerie Fire (unified in MoP)
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = true,
        texture = 136033,

        handler = function ()
            applyDebuff( "target", "faerie_fire" )
            applyDebuff( "target", "weakened_armor", 30, 3 )
        end,
    },

    demoralizing_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132117,

        handler = function ()
            applyDebuff( "target", "demoralizing_roar" )
            if active_enemies > 1 then
                active_dot.demoralizing_roar = active_enemies
            end
        end,
    },

    growl = {
        id = 6795,
        cast = 0,
        cooldown = 8,
        gcd = "spell",

        startsCombat = true,
        texture = 132270,

        handler = function ()
            -- Taunt effect
        end,
    },

    challenging_roar = {
        id = 5209, -- Challenging Roar (Guardian ability in MoP)
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        startsCombat = true,
        texture = 132117,

        handler = function ()
            -- AoE taunt
        end,
    },

    -- Incarnation
    incarnation = {
        id = 102558,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "incarnation",

        startsCombat = false,
        texture = 571586,

        handler = function ()
            applyBuff( "incarnation" )
            if not buff.bear_form.up then
                shift( "bear_form" )
            end
        end,
    },

    -- Nature's Swiftness (if talented)
    natures_swiftness = {
        id = 132158,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        talent = "nature_swiftness",

        startsCombat = false,
        texture = 136076,

        handler = function ()
            applyBuff( "nature_swiftness" )
        end,
    },

    -- Healing Touch (for Nature's Swiftness)
    healing_touch = {
        id = 5185,
        cast = function() return buff.nature_swiftness.up and 0 or 3 end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return buff.nature_swiftness.up and 0 or 0.15 end,
        spendType = "mana",

        startsCombat = false,
        texture = 136041,

        handler = function ()
            removeBuff( "nature_swiftness" )
            health.actual = min( health.max, health.actual + ( health.max * 0.4 ) )
        end,
    },

} )

-- State table and hooks
spec:RegisterStateExpr( "lacerate_up", function()
    return debuff.lacerate.up
end )

spec:RegisterStateExpr( "thrash_up", function()
    return debuff.thrash_bear.up
end )

spec:RegisterStateExpr( "rage_spent_recently", function()
    for i = 1, #recentRageSpent do
        if recentRageSpent[i] > 0 then return true end
    end
    return false
end )

-- Priority List
spec:RegisterPackage( "Guardian", 20241201.1, [[Hekili:TEvZZTnss(BrvkPss2SILnHPdllNLfEMGUcKYSSSSQOOcOOOGHHJC6p3HF5J5NZhKqPbQb9H9O8O2kP(T4T2lKr(0Q(yU57FWYgV9Ro3CFWyVp8FWYgV(IK63g7eo0C)TcNlpe9)SkOsI3ZnHPdLlwAo1QaHLaHJaH5FwHHJG3TJdtT4cJPjO2MfO2(fOwO9E9fO(TfOMMBFKdltaWwaSjOPBKKJG5FwHH7gZBF3NsJ5FKfEm(V4TFEI(E)dglXexYpqwSkdlFxuKfVYXMfKB(0E9HXISG8BQU9FXaRnfWNJB)g8V9oYVGWa8p3NsXNfqMhbEF3NLWDu0k5YNfeggBT(Vd7)Mg8d36Fk)Cy0R(xpMJEOdGzh9THLyDCaOWWNJBF0n3mCCaNJl8zn(Bz4TXzN4cKgUhMfKBLJ(MJzGONMLPG3MZOu1DmF1FKNTGSmebcVn3dZH)FFiE9TIuBFZK55(1Jm(d5M9O4TtHJ4YJF5o2ZsJmhbLJBE5YXB)lR8VJ5qH)9THCy55cNCIl8dxL8ZV7lgvdQWU(9qP)PFO0U(UVX54VBe(JU8iiF9W8cKF0uWYh(y8EQHKpfEllBOW(JRW(h5)OTJJ)dJJLyXBP5XvKNJUayOWaKrMGOOGzZqfwOWrKQ5iyOWHWaOWLtOTdcqQgKJ3CGdlgOq(sNlZC3(6p)EqXZhfnlUXHHeOsO6PHJNgCKaOY4OJQH7gaLOkO6FHs8yO55xUGnw5YJVuixCKLapJrMCOE1WJaBpbmGq)dJJLy0OVoaWqLHBE5kCXJNp(yoK0eiKKbFCqKI8CW()c)yoKaGp0MZ2uXhtZXnl8B9pIhElp0)Jh6)OHBXeVpB5o5AXnl5(VJzqpYXBSpOPMkE7)cKJJGVpUWNDOpG5M(J7CWnlLJFzqSSJ7(FFCoSDC5YXcJJLlVhVJ7s8)6M0(B(p4nfXO0UOhZ0OLBBLtNlQtY0Q5yL0TUVn5FQTXP5YtZclD)J)qhz5(bVGZsNJfIrPBR9VXdwWKDC58f3Hp8HpXrUL)K(1lXNpHWE)YXRoQI8R4B8K0Ely3l(t)W8Kul(TDmqZelKO7CfKl85f(WHlOdJF)rX)n(xDdqO(QJ7)gFdZYm5YJq)dZ8KZ)Z8P8U4C8BWpbJltNJI)6h0lL2yb3WJFNc8fE)QJcK4p8)2Fc5x4tWa)c(ZlN)h8L9gSKZ8XQTqfVtNJfE)QJcK4p8)2FcZxq8j2YJ7(WGNP7s)3Wgxo)e8f(rNx)Daf9kpb)I)6)tJelLNJ7Ctq(MJpA8elXNYLJZBLXpZfCl3)lp8CKV4T4Zq4pWLHnJxo)e8v4V5pbp3s8T4u8ZlN)eLlps)dJ2GJ(o2HlUhFV4LhB(zI)8YJ7rQcKF0n4J)9R5LZWyFKNrJZ5ZOF1nqKhxvNJNg)z5Y7WJf(3VeZRlLtIl8CKx41SB)tJeF3ZnHPdLlwAo1QaHLarNJcphxTp4TJ)8o8BwPJ(FdKqTbE)q8tOK8f8V(bpMT9o8)eMeeFdE4Uq4pUq4TBQaFXVE5Y7Gx2FeG)4AFcoNqEeFkTZQJ4Bp8JpGCtlpTw(M(gTjDJlDfUo25YU8hy8x0Fc3D3Nf(qqzJ)81rrNZJNWgWZz8)7hbRlNJAaZHFjd2GcDWJvjpSsWJj42AcJnNJLVhNCbKV1kNJrJBg)tqCPQBOEUvmfOA)HyXvqtPBOl3YTW(ElP8CZJFqJ)6wYJa6vJ)6gLKNJ48AaFEL)yCfV(E4WJNV0V4FFuKJJGHFpExKOm9h0S9hbQWFONJJ4TJ(FD(XdU)RvNZxo2aBo3OPJhE4W8dNW5JX4zEUJRoZJX8JrFEo8yGClLWrSRo)z5Uo2X)4Q3UkpLLV8(qYhMl)hhEm3SJqsLdNG6yOh)aWJdDYwGPFgFlf))F9KxtYJJdDYwGPFcZJdDcHOsKhLJ)hhEc6Ox5Xp4tq)0VJfOElkVJfgvdZi8B2Lhl8WJFfSIlJXhM)8CoMFX8XrVFKbVExH)d]] )
