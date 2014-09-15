--[[
	CCMarker automatically marks targets for crowd control according to party make up and abilities
	Version: 1.4
	Author: sshen81
	License: MIT
--]]

-- Local objects 
local CCMarker = {};
local CCMarkerButton;
CCMarker_isMarking = false;
CCMarker_UseRepentance = false;
CCMarker_UseWyvern = false;
CCMarker_Callback = {};
CCMARKER_CREDITS = "CCMarker - by Helmet (Uther US). /ccmarker to display help";
CCMARKER_HELP = "/ccmarker mark - turns on/off marking\n/ccmarker targets - sends the party icon list over chat channel\n/ccmarker show - turns on/off the CCMarker button\n/ccmarker repentance on|off - enables Paladin's Repentance\n/ccmarker wyvern on|off - enables Hunter's Wyvern Sting";
CCMARKER_TOOLTIP_HELP = "Left click to toggle crowd control marking\nRight click (hold) and drag to move this button";


-- Constants
SPELL_BANISH = "Banish";
SPELL_BIND = "Bind";
SPELL_FEAR = "Fear";
SPELL_HEX = "Hex";
SPELL_HIBERNATE = "Hibernate";
SPELL_POLYMORPH = "Polymorph";
SPELL_REPENTANCE = "Repentance";
SPELL_SAP = "Sap";
SPELL_SHACKLE = "Shackle";
SPELL_TRAP = "Trap";
SPELL_WYVERN = "Wyvern Sting";

--[[
    Party unit table. Stores the party members and their values.
    Dynamically adds players to the partyMembers table
]]--
CCMarker_partyMembers = {}

--[[ 
    Creature Type table. This is a separate table because it contains a 
    prioritized list of CC spells associated with a creature type
]]--
CCMarker_ccTable = {
    ["Beast"]         = { SPELL_SAP, SPELL_HIBERNATE, SPELL_POLYMORPH, SPELL_HEX, SPELL_TRAP, SPELL_FEAR, SPELL_WYVERN },
    ["Demon"]         = { SPELL_SAP, SPELL_BANISH, SPELL_TRAP, SPELL_REPENTANCE, SPELL_FEAR, SPELL_WYVERN },
    ["Dragonkin"]     = { SPELL_SAP, SPELL_HIBERNATE, SPELL_TRAP, SPELL_REPENTANCE, SPELL_FEAR, SPELL_WYVERN },
    ["Elemental"]     = { SPELL_BANISH, SPELL_BIND, SPELL_TRAP, SPELL_FEAR, SPELL_WYVERN },
    ["Giant"]         = { SPELL_REPENTANCE, SPELL_TRAP, SPELL_FEAR, SPELL_WYVERN },
    ["Humanoid"]      = { SPELL_SAP, SPELL_POLYMORPH, SPELL_HEX, SPELL_TRAP, SPELL_REPENTANCE, SPELL_FEAR, SPELL_WYVERN },
    ["Undead"]        = { SPELL_SHACKLE, SPELL_TRAP, SPELL_REPENTANCE, SPELL_FEAR, SPELL_WYVERN },
};

-- Spell table for each class
CCMarker_spellTable = {
    ["Druid"]        = {SPELL_HIBERNATE},
    ["Hunter"]       = {SPELL_TRAP, SPELL_WYVERN},
    ["Mage"]         = {SPELL_POLYMORPH},
    ["Paladin"]      = {SPELL_REPENTANCE},
    ["Priest"]       = {SPELL_SHACKLE},
    ["Rogue"]        = {SPELL_SAP},
    ["Shaman"]       = {SPELL_HEX, SPELL_BIND},
    ["Warlock"]      = {SPELL_BANISH, SPELL_FEAR},
};

-- Target icons
CCMarker_targetIconsTable = {
    '{star}',
    '{circle}',
    '{diamond}',
    '{triangle}',
    '{moon}',
    '{square}',
    '{cross}'
};

-------------------------------------------------------------------
-- Events
-------------------------------------------------------------------
function CCMarker_OnLoad(self)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff33"..CCMARKER_CREDITS.."|r");

    self:RegisterEvent("PARTY_MEMBERS_CHANGED");
    self:RegisterEvent("PARTY_MEMBERS_ENABLE");
    self:RegisterEvent("PARTY_MEMBERS_DISABLE");
    self:RegisterEvent("PLAYER_TARGET_CHANGED");
    
    SlashCmdList["CCMARKER"] = function(msg)
        CCMarker_SlashHandler(msg);
    end
    
    SLASH_CCMARKER1 = "/ccmarker";

    CCMarker_CreateLayout();
    CCMarker_UpdateParty();
end

function CCMarker_OnEvent(self, event, arg1, arg2, arg3)
    if event == "PARTY_MEMBERS_CHANGED" or event == "PARTY_MEMBERS_ENABLE" or event == "PARTY_MEMBERS_DISABLE" then
        CCMarker_UpdateParty()
    elseif event == "PLAYER_TARGET_CHANGED" and CCMarker_isMarking then
        CCMarker_MarkTarget()
    end
end

function CCMarker_TooltipShow(self)
	GameTooltip_SetDefaultAnchor(GameTooltip, self);
    GameTooltip:SetText(CCMARKER_TOOLTIP_HELP);
    GameTooltip:Show();
end
-------------------------------------------------------------------
-- Marking Related Functions
-------------------------------------------------------------------
--[[
    Toggles Marking. When marking is turned off, we set all the party's spells
    as available for the next round of marking
]]--
function CCMarker_MarkToggle()
    if CCMarker_isMarking then
        CCMarker_isMarking = false;
        CCMarkerButton:SetBackdropColor(1,1,1);
        
        -- Clear out the party's assignment list
        for memberName,partyMemberData in pairs(CCMarker_partyMembers) do
            for spellName,spellData in pairs(partyMemberData["SPELLS"]) do
                spellData["ASSIGNED"] = false;
            end
        end
    else
        CCMarker_isMarking = true;
        CCMarkerButton:SetBackdropColor(0,1,0);
		CCMarker_MarkTarget();
    end
end

--[[
    The function that actually marks a target. It performs the following logical steps:
    
    1. Get the target's creature type.
    2. Loop through table comparing creature type with known applicable CC abilities 
    3. Loop through the party table to see if there is someone with that ability that is not already assigned for CC
]]--
function CCMarker_MarkTarget()
    if UnitExists("target") and UnitCanAttack("player", "target") then
        targetType = UnitCreatureType("target");
        for ccTableType,ccTableData in pairs(CCMarker_ccTable) do
            if ccTableType == targetType then
                --print("Targetted a CC-able: "..targetType);
                -- Use ipairs() as this table is ordered by priority
                for i,ccSpellName in ipairs(ccTableData) do
                    --print("Looking for someone who can "..ccSpellName)
                    for memberName,partyMemberData in pairs(CCMarker_partyMembers) do
                        -- Check that this party member has an available spell table key matching the spell we're looking for
                        for spellName,spellData in pairs(partyMemberData["SPELLS"]) do
                            if spellName == ccSpellName and not spellData["ASSIGNED"] then
                                --print("Found "..memberName.." who can "..spellName)
                                -- If there's a way to get the INDEX off of the KEY in a table, then this
                                -- loop can be removed.
                                for targetIconNumber,IconName in ipairs(CCMarker_targetIconsTable) do
                                    if IconName == spellData["ICON"] then
                                        -- Set the appropriate icon on the target
                                        SetRaidTarget("target",targetIconNumber)
                                        -- Mark this spell as assigned for CC so it does not attempt to assign again
                                        spellData["ASSIGNED"] = true
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------
-- Party Composition Related Functions
-------------------------------------------------------------------
--[[
    This function will generate the CCMarker_partyMembers table which contains a complete list of
    the party members and CC abilities. This is the table which will be looked up against
    to see what CC capabilities can be assigned when targetting.
    
    We try to assign icons at this point to avoid switching them as much as possible during
]]--
function CCMarker_UpdateParty()
    local toonClass, toonName, toonRealm;
    local partyIndex = 1;
	local partyString;
    local iconTable = {
    '{cross}',
    '{square}',
    '{moon}',
    '{triangle}',
    '{diamond}',
    '{circle}',
    '{star}'
    };

    -- Clear out the party units table
    table.wipe(CCMarker_partyMembers);
    
    -- Fill the party table
    for partyIndex = 1,GetNumPartyMembers() do
        partyString = "party"..partyIndex;
        
        -- Get this party member's name & class
        toonClass = UnitClass(partyString);
        toonName, toonRealm = UnitName(partyString);
		
		-- Don't add in Offline party members or classes which are not in the spell table
		if UnitIsConnected(partyString) and toonClass and toonName and CCMarker_spellTable[toonClass] then
			if not CCMarker_partyMembers[toonName] then
				CCMarker_partyMembers[toonName] = { ["CLASS"] = toonClass, ["SPELLS"] = {} };
			end

			-- Creates party unit's spell table based on a look up
			for i,spellName in ipairs(CCMarker_spellTable[toonClass]) do
				--[[ 
				Adds the name of the spell to the table, assigns it an icon and marks it as available to use.
				If in some corner case scneario we run out of icons, then this is dropped from the list. This
				would only happen if there were many party members with multiple CC abilities. In which case,
				there's plenty of CC to go around - no need to assign them all.
				]]--
				if #iconTable > 0 then
					if not CCMarker_partyMembers[toonName]["SPELLS"][spellName] then
						-- Paladins and Hunters require a special check
						if toonClass == "Paladin" then
							if CCMarker_UseRepentance then
								CCMarker_partyMembers[toonName]["SPELLS"][spellName] = {["ICON"] = iconTable[#iconTable], ["ASSIGNED"] = false};
								table.remove(iconTable);
							end
						elseif toonClass == "Hunter" and spellName == SPELL_WYVERN then
							if CCMarker_UseWyvern then
								CCMarker_partyMembers[toonName]["SPELLS"][spellName] = {["ICON"] = iconTable[#iconTable], ["ASSIGNED"] = false};
								table.remove(iconTable);
							end
						else
							CCMarker_partyMembers[toonName]["SPELLS"][spellName] = {["ICON"] = iconTable[#iconTable], ["ASSIGNED"] = false};
							table.remove(iconTable);
						end
					end
				end
			end
		end
    end
    
    -- Add the player
    toonClass = UnitClass("player");
    toonName, toonRealm = UnitName("player");
    
    if not CCMarker_partyMembers[toonName] then
        CCMarker_partyMembers[toonName] = { ["CLASS"] = toonClass, ["SPELLS"] = {} };
    end

    -- Creates party unit's spell table based on a look up
    for i,spellName in ipairs(CCMarker_spellTable[toonClass]) do
        --[[ 
        Adds the name of the spell to the table, assigns it an icon and marks it as available to use.
        If in some corner case scneario we run out of icons, then this is dropped from the list. This
        would only happen if there were many party members with multiple CC abilities. In which case,
        there's plenty of CC to go around - no need to assign them all.
        ]]--
        if #iconTable > 0 then
            if not CCMarker_partyMembers[toonName]["SPELLS"][spellName] then
				-- Paladins and Hunters require a special check
				if toonClass == "Paladin" then
					if CCMarker_UseRepentance then
						CCMarker_partyMembers[toonName]["SPELLS"][spellName] = {["ICON"] = iconTable[#iconTable], ["ASSIGNED"] = false};
						table.remove(iconTable);
					end
				elseif toonClass == "Hunter" and spellName == SPELL_WYVERN then
					if CCMarker_UseWyvern then
						CCMarker_partyMembers[toonName]["SPELLS"][spellName] = {["ICON"] = iconTable[#iconTable], ["ASSIGNED"] = false};
						table.remove(iconTable);
					end
				else
					CCMarker_partyMembers[toonName]["SPELLS"][spellName] = {["ICON"] = iconTable[#iconTable], ["ASSIGNED"] = false};
					table.remove(iconTable);
				end
            end
        end
    end
end

-------------------------------------------------------------------
-- UI Functions
-------------------------------------------------------------------
function CCMarker_SlashHandler(msg)

	local command, rest = msg:match("^(%S*)%s*(.-)$");

    if command == "mark" then
        CCMarker_MarkToggle();
    elseif command == "show" then
        if CCMarkerButton:IsShown() then
            CCMarkerButton:Hide();
        else
            CCMarkerButton:Show();
        end
    elseif command == "targets" then
        local channel;
        if GetNumPartyMembers() > 0 then
            channel = "PARTY";
        else
            channel = "SAY";
        end
        for memberName,partyMemberData in pairs(CCMarker_partyMembers) do
            for spellName,spellData in pairs(partyMemberData["SPELLS"]) do
                --if spellData["ASSIGNED"] then
                    SendChatMessage(memberName.."-"..spellName.."-"..spellData["ICON"], channel);
                --end
            end
        end
	elseif command == "repentance" then
		if rest == "on" then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffff33".."Repentance Enabled".."|r");
			CCMarker_UseRepentance = true;
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffff33".."Repentance Disabled".."|r");
			CCMarker_UseRepentance = false;
		end
		
		CCMarker_UpdateParty();
	elseif command == "wyvern" then
		if rest == "on" then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffff33".."Wyvern Sting Enabled".."|r");
			CCMarker_UseWyvern = true;
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffff33".."Wyvern Sting Disabled".."|r");
			CCMarker_UseWyvern = false;
		end
		
		CCMarker_UpdateParty();
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff33"..CCMARKER_HELP.."|r");
    end
end

function CCMarker_CreateLayout()

    CCMarkerHeader = _G["CCMarkerFrame"];

    CCMarkerButton = CreateFrame("Button", "CCButton", CCMarkerHeader, "SecureActionButtonTemplate, CCMarkerButtonTemplate");
    CCMarkerButton:SetScript("OnClick", function()
        CCMarker_MarkToggle();
    end)

    CCMarker_UpdateLayout();
end

function CCMarker_UpdateLayout()
    local point = "TOPLEFT";
    local pointOpposite = "BOTTOMLEFT";

    CCMarkerButton:SetPoint(point, CCMarkerHeader, "CENTER", ox, oy);

    CCMarkerButton:Show();
end

