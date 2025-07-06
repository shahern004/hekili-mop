-- RogueSubtlety.lua
-- Mists of Pandaria (5.4.8)

if UnitClassBase( "player" ) ~= "ROGUE" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local insert, wipe = table.insert, table.wipe
local strformat = string.format
local GetSpellInfo = ns.GetUnpackedSpellInfo

local spec = Hekili:NewSpecialization( 261 )

spec:RegisterResource( Enum.PowerType.Energy, {
  shadow_techniques = {
    last = function () return state.query_time end,
    interval = function () return state.time_to_sht[5] end,
    value = 7,
    stop = function () return state.time_to_sht[5] == 0 or state.time_to_sht[5] == 3600 end,
  }
} )

spec:RegisterResource( Enum.PowerType.ComboPoints )

-- Talents
spec:RegisterTalents( {
  -- Tier 1
  nightstalker          = { 1181, 14062, 1 }, -- While Stealth or Vanish is active, your abilities deal 25% more damage.
  subterfuge            = { 1182, 108208, 1 }, -- Your abilities requiring Stealth can still be used for 3 sec after Stealth breaks.
  shadow_focus          = { 1183, 108209, 1 }, -- Abilities used while in Stealth cost 75% less energy.
  
  -- Tier 2
  deadly_throw          = { 1184, 26679, 1 }, -- Finishing move that throws a deadly blade at the target, dealing damage and reducing movement speed by 70% for 6 sec. 1 point: 12 damage 2 points: 24 damage 3 points: 36 damage 4 points: 48 damage 5 points: 60 damage
  nerve_strike          = { 1185, 108210, 1 }, -- Kidney Shot and Cheap Shot also reduce the damage dealt by the target by 50% for 6 sec after the effect ends.
  combat_readiness      = { 1186, 74001, 1 }, -- Reduces all damage taken by 50% for 10 sec. Each time you are struck while Combat Readiness is active, the damage reduction decreases by 10%.
  
  -- Tier 3
  cheat_death           = { 1187, 31230, 1 }, -- Fatal attacks instead bring you to 10% of your maximum health. For 3 sec afterward, you take 90% reduced damage. Cannot occur more than once per 90 sec.
  leeching_poison       = { 1188, 108211, 1 }, -- Your Deadly Poison also causes your Poison abilities to heal you for 10% of the damage they deal.
  elusiveness           = { 1189, 79008, 1 }, -- Feint also reduces all damage you take by 30% for 5 sec.
  
  -- Tier 4
  prep                  = { 1190, 14185, 1 }, -- When activated, the cooldown on your Vanish, Sprint, and Shadowstep abilities are reset.
  shadowstep            = { 1191, 36554, 1 }, -- Step through the shadows to appear behind your target and gain 70% increased movement speed for 2 sec. Cooldown reset by Preparation.
  burst_of_speed        = { 1192, 108212, 1 }, -- Increases your movement speed by 70% for 4 sec. Usable while stealthed. Removes all snare and root effects.
  
  -- Tier 5
  prey_on_the_weak      = { 1193, 51685, 1 }, -- Targets you disable with Cheap Shot, Kidney Shot, Sap, or Gouge take 10% additional damage for 6 sec.
  paralytic_poison      = { 1194, 108215, 1 }, -- Your Crippling Poison has a 4% chance to paralyze the target for 4 sec. Only one poison per weapon.
  dirty_tricks          = { 1195, 108216, 1 }, -- Cheap Shot, Gouge, and Blind no longer cost energy.
  
  -- Tier 6
  shuriken_toss         = { 1196, 114014, 1 }, -- Throws a shuriken at an enemy target, dealing 400% weapon damage (based on weapon damage) as Physical damage. Awards 1 combo point.
  versatility           = { 1197, 108214, 1 }, -- You can apply both Wound Poison and Deadly Poison to your weapons.
  anticipation          = { 1198, 114015, 1 }, -- You can build combo points beyond the normal 5. Combo points generated beyond 5 are stored (up to 5) and applied when your combo points reset to 0.
  
  -- Subtlety Specific Talents (1-45 talents)
  master_of_subtlety    = { 243, 31223, 3 }, -- Attacks made while stealthed and for 6 sec after breaking stealth do 10/20/30% additional damage.
  opportunity           = { 244, 1477, 3 }, -- Increases the damage dealt by your Backstab, Ambush, Garrote, and Eviscerate by 10/20/30%.
  initiative            = { 245, 13979, 2 }, -- Your Ambush, Garrote, and Cheap Shot abilities generate 1/2 additional combo point.
  
  -- 46-60 talents
  improved_ambush       = { 246, 14079, 2 }, -- Increases the critical strike chance of your Ambush ability by 25/50%.
  heightened_senses     = { 247, 30895, 1 }, -- Increases your Stealth detection and reduces the chance you are hit by spells and ranged attacks by 2%.
  premeditation         = { 248, 14183, 1 }, -- When you Ambush, you generate 2 additional combo points that can only be used on Eviscerate, Slice and Dice, or Rupture. These combo points cannot be used on other finishing moves. Lasts 20 sec.
  
  -- 61-75 talents
  hemorrhage           = { 249, 16511, 1 }, -- An instant strike that damages the target and causes the target to hemorrhage, dealing additional damage over time. Each strike of the Rogue's weapons has a chance to expose a flaw in their target's defenses, causing all attacks against the target to bypass 35% of that target's armor for 10 sec. Awards 1 combo point.
  honor_among_thieves  = { 250, 51701, 3 }, -- When anyone in your group critically hits with a spell or ability, you have a 33/66/100% chance to gain a combo point on your current target. This effect cannot occur more than once every 2 sec.
  waylay               = { 251, 51692, 2 }, -- Your Ambush and Backstab critical hits have a 50/100% chance to reduce the target's movement speed by 70% for 8 sec.
  
  -- 76-90 talents
  sanguinary_vein      = { 252, 79147, 2 }, -- Increases damage caused against targets with bleed effects by 8/16%.
  energetic_recovery   = { 253, 79152, 2 }, -- Your Slice and Dice ability also increases your Energy regeneration rate by 5/10%.
  find_weakness        = { 254, 91023, 2 }, -- Your Ambush, Garrote, and Cheap Shot abilities bypass 35/70% of your target's armor for 10 sec.
  
  -- 91+ talents
  slaughter_from_shadows = { 255, 51708, 3 }, -- Reduces the energy cost of your Ambush by 5/10/15, Backstab by 4/8/12, and Hemorrhage by 3/6/9.
  serrated_blades        = { 256, 14171, 2 }, -- Your attacks that apply your Deadly Poison also have a 10/20% chance to extend the duration of Rupture on the target by 2 sec.
  shadow_dance            = { 257, 51713, 1 }, -- Allows use of abilities that require Stealth for 8 sec, and increases damage by 20%. Does not break Stealth if already active.
} )

-- PvP Talents
spec:RegisterPvpTalents( {
  smoke_bomb           = 1209, -- (359053) Creates a cloud of thick smoke in an 8 yard radius around the Rogue for 5 sec. Enemies are unable to target into or out of the smoke cloud.
} )

-- Auras
spec:RegisterAuras( {
  -- Abilities
  blind = {
    id = 2094,
    duration = 60,
    max_stack = 1
  },
  combat_readiness = {
    id = 74001,
    duration = 10,
    max_stack = 5
  },
  evasion = {
    id = 5277,
    duration = 10,
    max_stack = 1
  },
  feint = {
    id = 1966,
    duration = 5,
    max_stack = 1
  },
  kidney_shot = {
    id = 408,
    duration = function() return 5 + ( effective_combo_points > 0 and min( 6, effective_combo_points ) - 1 or 0 ) end,
    max_stack = 1
  },
  preparation = {
    id = 14185,
    duration = 3600,
    max_stack = 1
  },
  premeditation = {
    id = 14183,
    duration = 20,
    max_stack = 1
  },
  sap = {
    id = 6770,
    duration = 60,
    max_stack = 1
  },
  shadow_dance = {
    id = 51713,
    duration = 8,
    max_stack = 1
  },
  shadowstep = {
    id = 36563,
    duration = 2,
    max_stack = 1
  },
  slice_and_dice = {
    id = 5171,
    duration = function() return 12 + ( 6 * min( 5, effective_combo_points ) ) end,
    max_stack = 1
  },
  sprint = {
    id = 2983,
    duration = 8,
    max_stack = 1
  },
  stealth = {
    id = 1784,
    duration = 3600,
    max_stack = 1
  },
  vanish = {
    id = 11327,
    duration = 10,
    max_stack = 1
  },
  
  -- Bleeds/Poisons
  garrote = {
    id = 703,
    duration = 18,
    max_stack = 1
  },
  rupture = {
    id = 1943,
    duration = function() return 8 + ( 4 * min( 5, effective_combo_points ) ) end,
    max_stack = 1
  },
  deadly_poison = {
    id = 2818,
    duration = 12,
    max_stack = 5
  },
  crippling_poison = {
    id = 3409,
    duration = 12,
    max_stack = 1
  },
  mind_numbing_poison = {
    id = 5760,
    duration = 10,
    max_stack = 1
  },
  
  -- Talents
  master_of_subtlety = {
    id = 31665,
    duration = 6,
    max_stack = 1
  },
  find_weakness = {
    id = 91021,
    duration = 10,
    max_stack = 1
  },
  honor_among_thieves = {
    id = 51701,
    duration = 2,
    max_stack = 1
  },
  subterfuge = {
    id = 115192,
    duration = 3,
    max_stack = 1
  },
  anticipation = {
    id = 115189,
    duration = 3600,
    max_stack = 5
  },
} )

local true_stealth_change, emu_stealth_change = 0, 0
local last_mh, last_oh, last_shadow_techniques, swings_since_sht, sht = 0, 0, 0, 0, {} -- Shadow Techniques

spec:RegisterEvent( "UPDATE_STEALTH", function ()
  true_stealth_change = GetTime()
end )

spec:RegisterStateExpr( "cp_max_spend", function ()
  return 5
end )

spec:RegisterStateExpr( "effective_combo_points", function ()
  local c = combo_points.current or 0
  return c
end )

-- Abilities
spec:RegisterAbilities( {
  -- Stab the target, causing 632 Physical damage. Damage increased by 20% when you are behind your target. Awards 1 combo point.
  backstab = {
    id = 53,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 60 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) * ( talent.slaughter_from_shadows.enabled and (1 - 0.04 * talent.slaughter_from_shadows.rank) or 1 ) end,
    spendType = "energy",

    startsCombat = true,

    handler = function ()
      gain( 1, "combo_points" )
    end
  },

  -- Finishing move that disembowels the target, causing damage per combo point. 1 point : 273 damage 2 points: 546 damage 3 points: 818 damage 4 points: 1,091 damage 5 points: 1,363 damage
  eviscerate = {
    id = 2098,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 35 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    usable = function () return combo_points.current > 0, "requires combo points" end,

    handler = function ()
      if buff.slice_and_dice.up then
        buff.slice_and_dice.expires = buff.slice_and_dice.expires + effective_combo_points * 3
      end
      
      spend( combo_points.current, "combo_points" )
    end
  },

  -- An instant strike that damages the target and causes the target to hemorrhage, dealing additional damage over time. Awards 1 combo point.
  hemorrhage = {
    id = 16511,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 35 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) * ( talent.slaughter_from_shadows.enabled and (1 - 0.03 * talent.slaughter_from_shadows.rank) or 1 ) end,
    spendType = "energy",

    talent = "hemorrhage",
    startsCombat = true,

    handler = function ()
      gain( 1, "combo_points" )
      applyDebuff( "target", "hemorrhage", 24 )
    end
  },

  -- Finishing move that tears open the target, dealing damage over time. Lasts longer per combo point. 1 point : 8 sec 2 points: 12 sec 3 points: 16 sec 4 points: 20 sec 5 points: 24 sec
  rupture = {
    id = 1943,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 25 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    usable = function () return combo_points.current > 0, "requires combo points" end,

    handler = function ()
      applyDebuff( "target", "rupture", 8 + (4 * effective_combo_points) )
      spend( combo_points.current, "combo_points" )
    end
  },

  -- Finishing move that cuts your target, dealing instant damage and increasing your attack speed by 40%. Lasts longer per combo point. 1 point : 12 sec 2 points: 18 sec 3 points: 24 sec 4 points: 30 sec 5 points: 36 sec
  slice_and_dice = {
    id = 5171,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 25 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    startsCombat = false,
    usable = function () return combo_points.current > 0, "requires combo points" end,

    handler = function ()
      applyBuff( "slice_and_dice", 12 + (6 * effective_combo_points) )
      spend( combo_points.current, "combo_points" )
    end
  },

  -- Ambush the target, causing 275% weapon damage plus 348. Must be stealthed. Awards 2 combo points.
  ambush = {
    id = 8676,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 60 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) * ( talent.slaughter_from_shadows.enabled and (1 - 0.05 * talent.slaughter_from_shadows.rank) or 1 ) end,
    spendType = "energy",

    startsCombat = true,
    usable = function () return stealthed.all, "requires stealth" end,

    handler = function ()
      gain( 2 + ( talent.initiative.enabled and talent.initiative.rank or 0 ), "combo_points" )
      
      if talent.find_weakness.enabled then
        applyDebuff( "target", "find_weakness" )
      end
      
      if talent.premeditation.enabled then
        applyBuff( "premeditation", 20 )
      end
    end
  },

  -- Talent: Allows use of abilities that require Stealth for 8 sec, and increases damage by 20%. Does not break Stealth if already active.
  shadow_dance = {
    id = 51713,
    cast = 0,
    cooldown = 60,
    gcd = "off",

    talent = "shadow_dance",
    startsCombat = false,

    toggle = "cooldowns",

    handler = function ()
      applyBuff( "shadow_dance" )
    end
  },

  -- Talent: Step through the shadows to appear behind your target and gain 70% increased movement speed for 2 sec.
  shadowstep = {
    id = 36554,
    cast = 0,
    cooldown = 24,
    gcd = "off",
    school = "physical",

    talent = "shadowstep",
    startsCombat = false,

    handler = function ()
      applyBuff( "shadowstep" )
      if buff.preparation.up then removeBuff( "preparation" ) end
    end
  },

  -- Throws a shuriken at an enemy target, dealing 400% weapon damage (based on weapon damage) as Physical damage. Awards 1 combo point.
  shuriken_toss = {
    id = 114014,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 40 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    talent = "shuriken_toss",
    startsCombat = true,

    handler = function ()
      gain( 1, "combo_points" )
    end
  },

  -- Stuns the target for 4 sec. Awards 2 combo points.
  cheap_shot = {
    id = 1833,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function ()
      if talent.dirty_tricks.enabled then return 0 end
      return 40 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 )
    end,
    spendType = "energy",

    startsCombat = true,
    nodebuff = "cheap_shot",

    usable = function ()
      if boss then return false, "cheap_shot assumed unusable in boss fights" end
      return stealthed.all, "not stealthed"
    end,

    handler = function ()
      applyDebuff( "target", "cheap_shot", 4 )
      gain( 2 + ( talent.initiative.enabled and talent.initiative.rank or 0 ), "combo_points" )
      
      if talent.find_weakness.enabled then
        applyDebuff( "target", "find_weakness" )
      end
    end
  },

  -- Finishing move that strikes the target, causing damage. If used during Shadow Dance, Cheap Shot is also performed on the target for no energy or combo points. 1 point : 12 damage 2 points: 24 damage 3 points: 36 damage 4 points: 48 damage 5 points: 60 damage
  deadly_throw = {
    id = 26679,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    school = "physical",

    spend = function () return 25 * ( ( talent.shadow_focus.enabled and ( buff.stealth.up ) ) and 0.25 or 1 ) end,
    spendType = "energy",

    talent = "deadly_throw",
    startsCombat = true,
    usable = function () return combo_points.current > 0, "requires combo points" end,

    handler = function ()
      spend( combo_points.current, "combo_points" )
      
      if buff.shadow_dance.up then
        applyDebuff( "target", "cheap_shot", 4 )
      end
    end
  },

  -- When activated, the cooldown on your Vanish, Sprint, and Shadowstep abilities are reset.
  preparation = {
    id = 14185,
    cast = 0,
    cooldown = 300,
    gcd = "off",
    school = "physical",

    talent = "prep",
    startsCombat = false,

    toggle = "cooldowns",

    handler = function ()
      applyBuff( "preparation" )
      setCooldown( "vanish", 0 )
      setCooldown( "sprint", 0 )
      if talent.shadowstep.enabled then setCooldown( "shadowstep", 0 ) end
    end
  }
} )

spec:RegisterOptions( {
  enabled = true,

  aoe = 3,
  cycle = false,

  nameplates = true,
  nameplateRange = 10,
  rangeFilter = false,

  canFunnel = true,
  funnel = false,

  damage = true,
  damageExpiration = 6,

  potion = "draenic_agility",

  package = "Subtlety",
} )

spec:RegisterPack( "Subtlety", 20250406, [[Hekili:TZv3Unom4FPB4dQDKQ(ovYLlr9QKCe4rnCvzUCBkQu8zJV3xRy3o2oKf1TojBwKC0AuXCTY)NUo8dZFcvz9Pih73(zAA94b7nzJn69Gzxi9Xh3FjGFAT)gU1Y0oF7n8XW)IbcEJEw8nC5PtEJd57w4G8CkUhF99I3Mx4u(BVN6LNMwbJ)fmolp3rj)YMZYj97X67mRZO8L7o(Z88Yy)xhxEhgpN(Cl4uGOWEZlxpJVCgDjwEgCXgqG92UqV4ooFJRmGR0MpFOTU)NsZm21z94Pco2f8UdcCrlUYXZhf76QKKYZtmUvxP6nrZwB1YEMTYFGtgYYYfGQK66yIwKEK8A51dT9Ys4HsPNKDPpGZyWEJpbMwLyBU3(yPG2Ev0NVl3aAUTJCUTPZ(UGxKG5W9)DdkGOMk4u4HZ)2bGEF6OFQ04g(NdzR9jgBf)M6vZ6JoswmQUPOmk1cMnjPeUjG7s9NKOMC)mjj9KuY1)Gu(OZ9FbWQIJf(gblB(sgpXmLW0vkwW03EsKbxlEYGhVdw98rTm)gKP(LLuEBjB(0gVs)4acUd)xbxvKfTm3LsGdUkygkxqyeQa0GqhZx9)uJHrwb(gMJyWVyXJBiIdTIVOl4FeN2YZAJJyGQ30ZKBu8MYHmcI3N(WGTfNcgTl2jy2Y28YUX65CjmMBZYlPiMmYlPdZS3WKSlYE)1Nck3SL0rqLkYc87gFIdPi1o0JKE9LsyWENzOBzILEXzMnBglZZR4G30Lh4r)YjMgwJEPz4cNbS7kMqZZZIKYoXqwFJspjRnzQ8h9kRHsv68iUPsQGiokI09Wj6vePRBzZsYm2)cKprgqoqaUEVkLyvPJuDLBXb8J5OXCVZSGZyWGbcMTrg9Qai4vDrE(CcK)P4uj3wFd27Ij5bfUG9HuqZdQ6vr1sbCfaFHLu4rL8d90yJxeNVHKSbUdPPNuoZEPsV9i3YyQFHFgCsB6h9wqwUZ7bCbeBJ4EXP9eDUvdvCFimVCYAZCFZVP1(iMpYtb1UfhcQVW16y1sJJN)bOBTwTJCc4Y4bYVhOGPeIjDUfFk(x)X0Gw3lFqvbw9Q0DWl7z5kNjSCszh2MwY9E1nUZIWZU(ByEFGK1qN4vwJVGX7Z5Tz9b28mPQFUTlm(3UD)qOsGgPZW2LrLAO1S9UPFqDgPo7qVvzixAHqcDd2sSvEuQaHBvJZTr6dCkr(lQpbq)SkOBHFQpZqkNWl0(h9MsDg0KCcYKjX7EqVVA9UFAvqZ9GXIBnP9(Q5J6kkFZkBbxHzXZgF(xFMbgIHyHMM(IfnW9oVtq5UEA0iOGcuaXNyYvXUQ2TpZOcuLJxJF6GQQFHEMklHhESRvmtGsQNMIxwgbQlGXSsjE)9zQWYErbmJpqK9sQOzDnxC5bLe0Lv5MxQK7sOEiEXI6lvb3bFw7fYSyI)yiPdFjHPIlFzIc8YMSXaFb01jrFzC4(hq10yNK21yiWdL0c7wK)7YW9I9(PjnF6WVrAZ2HdgYiKSA1kXIXOlIVAl2XuUonjlPB67yqp1gXA53DWBRCJAzDsUG7cwI87dDH(HdUXaAJ9wNbI8Vir4X6QfYgYVuQsGcjEXbgw)BO9Fh9fQGvS3JqEptLFwkwjwk(XpRvPFwSAX0NRFy(VCixF9PuDZZ89V5vbRK6I83GfDXkbV35Io0qfDGMZsCg83k07X3i1T1E2LLnVNn)FbKfYyMJj8uRZs6X7r3W9lzSa)y1WgmxrPMTmFZMVz)mGCEHxvwjG(hERUxTnR2lxiKlZgb29sBwQu1x53d8Vy7OQfr(dqupD6Wvx8GVyYcmIJ(pTtqKvnR91a3HoEZj)1LFaQyqpb5nz5ZZ4VtQI9gCUY9ztTY1s9fEUkRx8X1xVljZgpG4hL0VZMEKFLSk(t3I0VlnZVLt)2nKhE4U2kn09C35EpGlfP1HNVvlnm1)KORMmRcDVb5dQRVlGOblCXt9x3z1mWVS2uynKMdW1FJKr0Fo8OXWUKIFZlk90kvjLwVlkffN)XjPo2V0uAJnmDyf8kB3DpVh2Kju09Zs2GU1sBLuOIQFvT11klkjOVkd2H8N9Og5WtlpbFFxZ)2Xf3eMLaLPAuF7O2XVEJ9m0FU4Vo4Cf6pQi4xmOWQdLh24MFoxoW6S)5TFvxWVpR2lKGlZ33uSR1bCLFzvL)UVFQL)WL5MdRxlsGH)6q9D)XaH)hCEWap8v3QWrGHdaY)Wbm4z9)]] )
