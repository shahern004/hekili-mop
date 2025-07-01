-- Test.lua - Minimal test file for MoP compatibility

print("Hekili Test: Loading...")

-- Test basic addon creation without LibStub first
local addonName = "HekiliTest"
local addon = {}

addon.name = addonName
addon.version = "test-1.0"

-- Register for basic events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            print("Hekili Test: ADDON_LOADED event received")
        end
    elseif event == "PLAYER_LOGIN" then
        print("Hekili Test: PLAYER_LOGIN event received")
        print("Hekili Test: WoW Version: " .. (GetBuildInfo() or "unknown"))
        print("Hekili Test: Successfully loaded in MoP!")
    end
end)

print("Hekili Test: Frame registered, waiting for events...")
