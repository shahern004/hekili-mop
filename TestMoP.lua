-- Test script to verify Hekili loads correctly in MoP
print("Testing Hekili addon load...")

-- Check if required API functions exist
if GetBuildInfo then
    local version, build, date, tocversion = GetBuildInfo()
    print("WoW Version:", version, "Build:", build, "TOC:", tocversion)
else
    print("ERROR: GetBuildInfo not found")
end

-- Check for MoP-specific APIs
if GetSpecialization then
    print("GetSpecialization: Available")
else
    print("GetSpecialization: NOT AVAILABLE")
end

if GetSpellInfo then
    print("GetSpellInfo: Available")
else
    print("GetSpellInfo: NOT AVAILABLE")
end

if UnitAura then
    print("UnitAura: Available")
else
    print("UnitAura: NOT AVAILABLE")
end

-- Check for retail APIs that should NOT exist in MoP
if C_Timer then
    print("WARNING: C_Timer found (should be compatibility layer)")
else
    print("C_Timer: Not found (expected in MoP)")
end

if C_UnitAuras then
    print("ERROR: C_UnitAuras found (should not exist in MoP)")
else
    print("C_UnitAuras: Not found (correct for MoP)")
end

if C_Spell then
    print("ERROR: C_Spell found (should not exist in MoP)")
else
    print("C_Spell: Not found (correct for MoP)")
end

print("Test completed.")
