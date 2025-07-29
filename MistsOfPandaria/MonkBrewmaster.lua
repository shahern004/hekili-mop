-- MonkBrewmaster.lua July 2025
-- by Smufrik,
local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local Hekili = _G["Hekili"]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

-- Create frame for deferred loading and combat log events
local bmCombatLogFrame = CreateFrame("Frame")

-- Define Brewmaster specialization registration
local function RegisterBrewmasterSpec()
    -- Create the Brewmaster spec (268 is Brewmaster in MoP)
    local spec = Hekili:NewSpecialization(268, true)

    spec.name = "Brewmaster"
    spec.role = "TANK"
    spec.primaryStat = 2 -- Agility

    -- Ensure state is properly initialized
    if not state then
        state = Hekili.State
    end

    -- Force Chi initialization with fallback
    local function UpdateChi()
        local chi = UnitPower("player", 12) or 0
        local maxChi = UnitPowerMax("player", 12) or (state.talent.ascension.enabled and 5 or 4)
        if not state.chi then
            state.chi = {
                actual = chi,
                max = maxChi,
                regen = 0
            }
        else
            state.chi.actual = chi
            state.chi.max = maxChi
        end
    end

    UpdateChi() -- Initial Chi sync

    -- Register Chi resource (ID 12 in MoP)
    spec:RegisterResource(12, {}, {
        max = function() return state.talent.ascension.enabled and 5 or 4 end
    })

    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {
        -- No special energy regeneration mechanics for Brewmaster in MoP
    }, {
        base_regen = function()
            local base = 10 -- Base energy regen (10 energy per second)
            local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
            return base * haste_bonus
        end
    })

    -- Talents for MoP Brewmaster Monk
    spec:RegisterTalents({
        celerity = { 1, 1, 115173 },
        tigers_lust = { 1, 2, 116841 },
        momentum = { 1, 3, 115174 },
        chi_wave = { 2, 1, 115098 },
        zen_sphere = { 2, 2, 124081 },
        chi_burst = { 2, 3, 123986 },
        power_strikes = { 3, 1, 121817 },
        ascension = { 3, 2, 115396 },
        chi_brew = { 3, 3, 115399 },
        deadly_reach = { 4, 1, 115176 },
        charging_ox_wave = { 4, 2, 119392 },
        leg_sweep = { 4, 3, 119381 },
        healing_elixirs = { 5, 1, 122280 },
        dampen_harm = { 5, 2, 122278 },
        diffuse_magic = { 5, 3, 122783 },
        rushing_jade_wind = { 6, 1, 116847 },
        invoke_xuen = { 6, 2, 123904 },
        chi_torpedo = { 6, 3, 115008 }
    })

    -- Auras for Brewmaster Monk
    spec:RegisterAuras({
        shuffle = { id = 115307, duration = 6, max_stack = 1, emulated = true },
        elusive_brew = { id = 115308, duration = 30, max_stack = 15, emulated = true },
        fortifying_brew = { id = 115203, duration = 15, max_stack = 1, emulated = true },
        guard = { id = 115295, duration = 30, max_stack = 1, emulated = true },
        dampen_harm = { id = 122278, duration = 10, max_stack = 1, emulated = true },
        diffuse_magic = { id = 122783, duration = 6, max_stack = 1, emulated = true },
        breath_of_fire_dot = { id = 123725, duration = 8, tick_time = 2, max_stack = 1, emulated = true },
        heavy_stagger = { id = 124273, duration = 10, tick_time = 1, max_stack = 1, emulated = true },
        moderate_stagger = { id = 124274, duration = 10, tick_time = 1, max_stack = 1, emulated = true },
        light_stagger = { id = 124275, duration = 10, tick_time = 1, max_stack = 1, emulated = true },
        zen_sphere = { id = 124081, duration = 16, tick_time = 2, emulated = true },
        rushing_jade_wind = { id = 116847, duration = 6, emulated = true },
        tigers_lust = { id = 116841, duration = 6, emulated = true }
    })

    -- State Expressions
    spec:RegisterStateExpr("stagger_level", function()
        if state.buff.heavy_stagger and state.buff.heavy_stagger.up then return "heavy" end
        if state.buff.moderate_stagger and state.buff.moderate_stagger.up then return "moderate" end
        if state.buff.light_stagger and state.buff.light_stagger.up then return "light" end
        return "none"
    end)

    -- Abilities for Brewmaster Monk
    spec:RegisterAbilities({
        -- Core Abilities
        jab = {
            id = 100780,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                state.gain(1, "chi")
                if state.talent.power_strikes.enabled and math.random() <= 0.2 then
                    state.gain(1, "chi")
                end
                UpdateChi()
            end
        },
        keg_smash = {
            id = 121253,
            cast = 0,
            cooldown = 8,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                state.gain(2, "chi")
                state.applyDebuff("target", "breath_of_fire_dot", 8)
                UpdateChi()
            end
        },
        tiger_palm = {
            id = 100787,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 25,
            spendType = "energy",
            startsCombat = true,
            handler = function() end
        },
        blackout_kick = {
            id = 100784,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                state.spend(2, "chi")
                state.applyBuff("player", "shuffle", 6)
                UpdateChi()
            end
        },
        spinning_crane_kick = {
            id = 101546,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 1,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                state.spend(1, "chi")
                UpdateChi()
            end
        },
        expel_harm = {
            id = 115072,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                state.gain(1, "chi")
                UpdateChi()
            end
        },
        breath_of_fire = {
            id = 115181,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                state.spend(2, "chi")
                state.applyDebuff("target", "breath_of_fire_dot", 8)
                UpdateChi()
            end
        },

        -- Defensive & Utility Abilities
        purifying_brew = {
            id = 119582,
            cast = 0,
            cooldown = 1,
            gcd = "off",
            spend = 1,
            spendType = "chi",
            startsCombat = false,
            handler = function()
                state.spend(1, "chi")
                state.removeDebuff("player", "heavy_stagger")
                state.removeDebuff("player", "moderate_stagger")
                state.removeDebuff("player", "light_stagger")
                UpdateChi()
            end
        },
        guard = {
            id = 115295,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            spend = 2,
            spendType = "chi",
            startsCombat = false,
            handler = function()
                state.spend(2, "chi")
                state.applyBuff("player", "guard", 30)
                UpdateChi()
            end
        },
        fortifying_brew = {
            id = 115203,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            toggle = "defensives",
            startsCombat = false,
            handler = function()
                state.applyBuff("player", "fortifying_brew", 15)
            end
        },
        energizing_brew = {
            id = 115288,
            cast = 0,
            cooldown = 60,
            gcd = "off",
            startsCombat = false,
            handler = function() end
        },

        -- Talent Abilities
        tigers_lust = {
            id = 116841,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            talent = "tigers_lust",
            toggle = "movement",
            handler = function()
                state.applyBuff("player", "tigers_lust", 6)
            end
        },
        chi_wave = {
            id = 115098,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            talent = "chi_wave",
            spend = 2,
            spendType = "chi",
            handler = function()
                state.spend(2, "chi")
                UpdateChi()
            end
        },
        zen_sphere = {
            id = 124081,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            talent = "zen_sphere",
            spend = 2,
            spendType = "chi",
            handler = function()
                state.spend(2, "chi")
                state.applyBuff("player", "zen_sphere", 16)
                UpdateChi()
            end
        },
        chi_burst = {
            id = 123986,
            cast = 1,
            cooldown = 30,
            gcd = "spell",
            talent = "chi_burst",
            spend = 2,
            spendType = "chi",
            handler = function()
                state.spend(2, "chi")
                UpdateChi()
            end
        },
        chi_brew = {
            id = 115399,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "chi_brew",
            startsCombat = false,
            handler = function()
                state.gain(2, "chi")
                UpdateChi()
            end
        },
        charging_ox_wave = {
            id = 119392,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            talent = "charging_ox_wave",
            handler = function() end
        },
        leg_sweep = {
            id = 119381,
            cast = 0,
            cooldown = 45,
            gcd = "spell",
            talent = "leg_sweep",
            handler = function() end
        },
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "dampen_harm",
            toggle = "defensives",
            handler = function()
                state.applyBuff("player", "dampen_harm", 10)
            end
        },
        diffuse_magic = {
            id = 122783,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "diffuse_magic",
            toggle = "defensives",
            handler = function()
                state.applyBuff("player", "diffuse_magic", 6)
            end
        },
        rushing_jade_wind = {
            id = 116847,
            cast = 0,
            cooldown = 6,
            gcd = "spell",
            spend = 1,
            spendType = "chi",
            talent = "rushing_jade_wind",
            startsCombat = true,
            handler = function()
                state.spend(1, "chi")
                state.applyBuff("player", "rushing_jade_wind", 6)
                UpdateChi()
            end
        },
        invoke_xuen = {
            id = 123904,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            talent = "invoke_xuen",
            toggle = "cooldowns",
            handler = function() end
        },
        chi_torpedo = {
            id = 115008,
            cast = 0,
            cooldown = 0, -- Uses Roll charges
            gcd = "off",
            talent = "chi_torpedo",
            toggle = "movement",
            handler = function() end
        }
    })

    -- Register combat log event for Elusive Brew stacks and Chi updates
    bmCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    bmCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
        local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID, _, _, _, critical = select(2, ...)
        if subevent == "SPELL_DAMAGE" and sourceGUID == state.GUID and critical and (spellID == 100780 or spellID == 115072 or spellID == 121253) then
            state.addStack(115308, nil, 1) -- Elusive Brew stack
        elseif subevent == "UNIT_POWER_UPDATE" and sourceGUID == state.GUID and select(12, ...) == "CHI" then
            UpdateChi() -- Sync Chi on power update
        end
    end)

    -- Periodic Chi sync (every 1 second in combat)
    local lastChiUpdate = 0
    bmCombatLogFrame:SetScript("OnUpdate", function(self, elapsed)
        if InCombatLockdown() then
            lastChiUpdate = lastChiUpdate + elapsed
            if lastChiUpdate >= 1 then
                UpdateChi()
                lastChiUpdate = 0
            end
        end
    end)

    -- Options
    spec:RegisterOptions({
        enabled = true,
        aoe = 2,
        cycle = false,
        nameplates = true,
        nameplateRange = 8,
        damage = true,
        damageExpiration = 8,
        package = "Brewmaster"
    })

    spec:RegisterSetting("use_purifying_brew", true, {
        name = strformat("Use %s", Hekili:GetSpellLinkWithTexture(119582)), -- Purifying Brew
        desc = "If checked, Purifying Brew will be recommended based on stagger level.",
        type = "toggle",
        width = "full"
    })

    spec:RegisterSetting("proactive_shuffle", true, {
        name = "Proactive Shuffle",
        desc = "If checked, Blackout Kick will be recommended to maintain Shuffle proactively.",
        type = "toggle",
        width = "full"
    })

    -- Default APL Pack is intentionally left minimal.
    -- Import the APL text provided separately using the Hekili in-game interface.
    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:LIvAVTnoq0FmlGBl2wvhL4KUDJdqB6E0I2IGvz)0IktAjklwljkqszhxeWF77qQlQR42g0dyto89Mz4WzEW(N4FRVxiws8)S7C3fZVW9voUZp9C3l89KhYj(E54GT4nWhYWPW))wozFkwijC9whsy4qnecwbpa223BDbnr((m)1JH7IfGP5Kay1ZFLVxmnmKuAkre47DBmvOq6)HvOkIviwe89ajLLPqjuHe2oIXvO)MSLMqDa)GZIOja7)Ic9Psd0N5gCwiMtXVwHA9AWcw2w1hatFZnFuHwJfKqWEaBpAArcwZZ1CCKeiJTHgur2nyzqScTW5mN7uFWC(B4Kaw6AmyPhP0)(qPFkCYR37xx(YGy6Q1Gd8CA0sjoHKjDQxYHKHxNqcNblC5s4)CsX39c3XXjNvYHH8pHPGl)MQ0YnCkJtLhuOpcXVXG3rIizc6osDYtNv5W3IPBIjGrO8Qd50qNMKcon6anBtJllisj8DHtHGSQ72ZEQqI3SHWxLq2rsw(KycE3HNC)99xpLfs4q1WtMbwKiJDYjq5sM8YZN)SNztpKRL94V3jwmFMKTztcXjSocf2ieItZjzRIX8uReU1Qn58bUYraMgfPtbPyOQWgA71Nc8loc4BkW8qnOqnWvlDBUK)QU27AgljKTpRZjOz7yBjRURGKz5mwR24kvehmgkpIAt40KmcFd9B23wMLoC5PZRcHRz6AU)HjnpSWjqn7A4vRKcXp6PEXfrrjGbf5BjK8Y3(bqrjnaN0PWylzZkb8eo2EX1jqpcwHC1wAWwn7Rb4CeLG6WjPWJeXLUZAkHHof6tVJSQYOkV8wtOB7B9Yr7X7i9Yr6LSZrMRT2t9nOCtKht42NRDXENCMXZT2wFtn4IQGlK9VP0RnWnk7VX(JUz79XeOxHl0TdkQsnxmW1vQzttRbOBJaaUtINxiI1xWFfhswTNMfA5ad2RXrQYYvWFvBtemJu6LN05IKtWY4vSOvr0Ye2XbOt2wKtZY0UsahNrAQhM0pdPIFahTSsoMQq)LU(glz8oviK7YjjnTCM(9YxXRhyqh4FxrAoCz8sf6pPjjKUSmmjnmpm4fHXKZSnrs1nMZXjPTVxV6I5(E7a(aBANy77ThZ1zvr9O5QjTLVttPcbSPcjkYZH(2vtk3OHup3uYPzBjsHJcPqVxwEiZ8SuswOEQRmwp8egrWp0oocSlliPiuxvsOs41WRHue6fk0)9VcIgjsQ4lpxH2ht1JKBTgNDOLvfkJPb)U8eAavM0IBO(tAYjTK(7Mhfv0CBjek0jFrdAO9sUwmVhUJSIOkiL1MAYgMLYksxdpQblejmjmV99P6eMEb3EABGn99WfYygiW6wCat3y13ZSNrRgjcxKiHp(zJ2TQhC(VfoLbhqouNz0LAR408YnFqDd)iIg8909PHBAmiPBAjck0mOZde42ccuOLkuLybf6(7NYIgzdgu6osvHUuHoFUc9m4V(sOQTx6O19g5GlMBGCWm52SypLiAgoDsgMwLXd55pSdybMM8Zok5JPdzk6V440BdN2bwmPdeOBDDfCH52ECJGg9XoFIQulLkdkr7Q6zKyDezo2XtJuhTdCXXsC9f8yqYetxU08bDFAtNbR4R(qAgE1Kmu2D1KXpDE7H7PBsJXV1dJozKhJiQwwBKqP57K5t60JjIYecUMmZ0IPAPQZyidDt1SQwjvViEGGSjU3SfH1EVvwlQPD6MctQiRhmMVoM6S2yODddNhTnXaDB998UvzAlna3VfqTvdK30lz(ZleCeNFsnFMGORCQY4Xwsv3i9etynDJLFm0SYBDLkzyPFFOVJaRwK4pvK14lJin14q97l10COrmz)UaDfGoOd8WUvAAMU50OhYYXb1Qge63AAIK8io7a5Stm1qp9E6(rngE2d0GXTFdMHnHVsp2RfIwDW(6NxEn)ulpK2QM2(9gz999Ro9i(jNg5xB6rokRwYuJSrw9WP6Ow28h)))p]])
end

-- Deferred loading mechanism
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterBrewmasterSpec()
        bmCombatLogFrame:UnregisterEvent("ADDON_LOADED")
        return true
    end
    return false
end

-- Attempt immediate registration or wait for ADDON_LOADED
if not TryRegister() then
    bmCombatLogFrame:RegisterEvent("ADDON_LOADED")
    bmCombatLogFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
