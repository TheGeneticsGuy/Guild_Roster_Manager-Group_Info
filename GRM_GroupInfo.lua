-- Author: Arkaan
-- Addon Name: "Guild Roster Manager - Group Info"
-- Descripton: Niche use addon that maybe not all GRM users will need. Useful to know who you are grouped with in terms of former members.


-- Core GRM Globals
-- Adding to Modules table of Core Addon
GRM_G.Module.GroupInfo = false;
GRM_G.GroupInfo = {};               -- To keep info accessible globally if needed.

-- Saved Variable
GRM_GroupInfo_Save = {};

-- Local Globals
GRM_GI = {};                  -- Module function table
GRMGI_UI = {};                -- Module UI table

-- Version
GRM_GI.version = 1.44;
GRM_GI.UpgradeAnnounce = false;

-- Global Variables
GRM_GI.lock = false;
GRM_GI.optionsLoaded = false;

-- Compatibility frames
GRM_GI.UIAddonCompatibilityName = "";
GRM_GI.CustomButtonPosition = {};

-- Method:          GRM_GI.GetNumGroupMembersAndStatusDetails()
-- What it Does:    Returns the number of guildies you are currently grouped with
-- Purpose:         Useful to know when in a group
GRM_GI.GetNumGroupMembersAndStatusDetails = function()
    local resultCurrent , resultFormer , total , sameServer = 0 , 0 , 0 , 0;
    local members = {};
    local formerMembers = {};
    local serverMembers = {};

    local serverString = "-" .. GRM_G.realmName;

    for name , member in pairs ( GRM_G.GroupInfo ) do

        if member.isGuildie then
            resultCurrent = resultCurrent + 1;
            members[name] = member;

        elseif member.isFormerGuildie then
            resultFormer = resultFormer + 1;
            formerMembers[name] = member;
        else

            if string.find ( name , serverString , 1 , true ) ~= nil then
                member.connectedRealm = true;
                sameServer = sameServer + 1;
                serverMembers[name] = member;
                break;
            end

        end

        total = total + 1;
    end

    return total , sameServer , resultCurrent , resultFormer , members , formerMembers , serverMembers;
end

-- Method:          GRM_GI.GetNamesOfPlayersSameServer()
-- What it Does:    Gets the names of the players the same server in an array
-- Purpose:         Useful info
GRM_GI.GetNamesOfPlayersSameServer = function()
    local result = {};
    local serverString = "-" .. GRM_G.realmName;

    for name in pairs ( GRM_G.GroupInfo ) do
        if string.find ( name , serverString , 1 , true ) ~= nil then
            table.insert ( result , name );
        end
    end

    return result;
end

-- Method:          GRM_GI.GetNamesOfPlayersInGuild()
-- What it Does:    Gets the names of the players the same server in an array
-- Purpose:         Useful info
GRM_GI.GetNamesOfPlayersInGuild = function()
    local result = {};

    for name , player in pairs ( GRM_G.GroupInfo ) do
        if player.isGuildie then
            table.insert ( result , name );
        end
    end

    return result;
end

-- Method:          GRM_GI.GetUnitFullName()
-- What it Does:    Returns the players full name with server appended to it.
-- Purpose:         Necessary to compare against the saved DB
GRM_GI.GetUnitFullName = function ( groupName )
    local name , server = UnitName ( groupName );

    if name == nil then
        return nil;
    end

    if server ~= nil and server ~= "" then
        name = name .. "-" .. server;
    else
        name = name .. "-" .. GRM_G.realmName;
    end

    return name;
end

-- Method:          GRM_GI.GetAltNames( table )
-- What it Does:    Collects all altNames into a table and lists if they are a currentMember
-- Purpose:         Useful to grab so you can know if the player you are grouped with has alts still in the guild.
GRM_GI.GetAltNames = function ( listOfAlts )
    local alts = {};

    if not listOfAlts then
        return alts;
    end

    local guildData = GRM.GetGuild();

    for i = 1 , #listOfAlts do
        alts[ listOfAlts[i][1] ] = {};

        if guildData[ listOfAlts[i][1] ] ~= nil then
            alts[ listOfAlts[i][1] ].currentMember = true;
        else
            alts[ listOfAlts[i][1] ].currentMember = false;
        end

        alts[ listOfAlts[i][1] ].hexCode = GRM.GetClassColorRGB ( listOfAlts[i][2] , true );

    end

    return alts;
end

-- Method:          GRM_GI.IsPlayerFormerMemberByGUID ( guid )
-- What it Does:    Returns true if the player's guid matches and returns the player's info as needed.
-- Purpose:         To ascertain if the player namechanged but was formerly in the guild.
GRM_GI.IsPlayerFormerMemberByGUID = function ( guid )
    local playerInfo = {};
    local result = false;

    if guid ~= nil and guid ~= "" then

        local oldMemberData = GRM.GetFormerMembers();

        for _ , player in pairs ( oldMemberData ) do
            if type ( player ) == "table" then

                if player.GUID ~= "" and player.GUID == guid then
                    result = true;
                    playerInfo = { player.bannedInfo[1] , player.bannedInfo[2] , player.reasonBanned , player.name , player.altsAtTimeOfLeaving , player.isMain , GRM.FormatTimeStamp ( { player.joinDateHist[1][1] , player.joinDateHist[1][2] , player.joinDateHist[1][3] } ) , player.mainAtTimeOfLeaving }; -- [1] = isBanned = true/false ; [2] = dateBannedEpoch
                    break;
                end

            end
        end

    end

    return result , playerInfo;
end

-- Method:          GRM_GI.GetNumAltsStillInGuild ( table )
-- What it Does:    Returns the number of alts still in the guild
-- Purpose:         For quick flyover info that former member still has alts.
GRM_GI.GetNumAltsStillInGuild = function ( alts )
    local num = 0;

    for _ , altName in pairs ( alts ) do
        if altName.currentMember then
            num = num + 1;
        end
    end

    return num;
end

-- Method:          GRM_GI.UpdateGroupInfo( bool )
-- What it Does:    Returns details on all the members of the current party or raid
-- Purpose:         Useful information for the player.
GRM_GI.UpdateGroupInfo = function( forcedFullRefresh )
    if not IsInGuild() then
        GRMGI_UI.GRM_GroupRulesButton:Hide();
        return;
    end

    local n = GetNumGroupMembers();
    local groupType = { ["false"] = "party" , ["true"] = "raid" };
    local group = groupType[tostring ( IsInRaid() )];
    local guildData = GRM.GetGuild();
    local formerMemberData = GRM.GetFormerMembers();
    local name , unit = "" , "";
    local tempListNames = {};

    if guildData and guildData[GRM_G.addonUser] ~= nil and guildData[GRM_G.addonUser].GUID ~= nil then

        for i = 1 , n do
            unit = group .. i;
            name = GRM_GI.GetUnitFullName ( unit );

            if name then
                tempListNames[name] = {};
                tempListNames[name].guid = UnitGUID( unit );
                tempListNames[name].class = select ( 2 , UnitClass ( unit ) );
                if name == GRM_G.addonUser then
                    tempListNames[name].unitID = "self";
                else
                    tempListNames[name].unitID = group .. i;
                end
            end

            if i == n and not tempListNames[GRM_G.addonUser] then
                tempListNames[GRM_G.addonUser] = {};
                tempListNames[GRM_G.addonUser].guid = guildData[GRM_G.addonUser].GUID;
                tempListNames[GRM_G.addonUser].class = guildData[GRM_G.addonUser].class;
                tempListNames[GRM_G.addonUser].unitID = "self";
            end
        end

        -- Now, we do cleanup of names of players no longer in group.
        for player in pairs ( GRM_G.GroupInfo ) do

        if tempListNames [ player ] == nil then
                GRM_G.GroupInfo [ player ] = nil;
        end

        end

        -- Now we add new names
        for player , unitInfo in pairs ( tempListNames ) do
            -- If the player has not been built the first time, now build it.
            if GRM_G.GroupInfo[ player ] == nil or ( GRM_G.GroupInfo[ player ] ~= nil and GRM_G.GroupInfo[ player ].unitID ~= unitInfo.unitID ) or forcedFullRefresh then
                GRM_G.GroupInfo[ player ] = {};

                -- Check if current guildie
                if guildData[ player ] ~= nil then
                    GRM_G.GroupInfo[ player ].isGuildie = true;
                    GRM_G.GroupInfo[ player ].isFormerGuildie = false;
                    GRM_G.GroupInfo[ player ].isBanned = { guildData[ player ].bannedInfo[1] , guildData[ player ].bannedInfo[2] , guildData[ player ].reasonBanned , "" };
                    GRM_G.GroupInfo[ player ].connectedRealm = true;

                -- Check if former guildie
                elseif formerMemberData[ player ] ~= nil then
                    GRM_G.GroupInfo[ player ].isGuildie = false;
                    GRM_G.GroupInfo[ player ].isFormerGuildie = true;
                    GRM_G.GroupInfo[ player ].dateLeft = GRM.FormatTimeStamp ( { formerMemberData[ player ].joinDateHist[1][1] , formerMemberData[ player ].joinDateHist[1][2] , formerMemberData[ player ].joinDateHist[1][3] } )
                    GRM_G.GroupInfo[ player ].isBanned = { formerMemberData[ player ].bannedInfo[1] , formerMemberData[ player ].bannedInfo[2] , formerMemberData[ player ].reasonBanned , "" };
                    GRM_G.GroupInfo[ player ].alts = GRM_GI.GetAltNames ( formerMemberData[ player ].altsAtTimeOfLeaving );
                    GRM_G.GroupInfo[ player ].isMain = formerMemberData[ player ].isMain;
                    GRM_G.GroupInfo[ player ].main = {};
                    GRM_G.GroupInfo[ player ].connectedRealm = true;

                    if not GRM_G.GroupInfo[ player ].isMain and #formerMemberData[ player ].altsAtTimeOfLeaving > 0 then
                        if #formerMemberData[ player ].mainAtTimeOfLeaving > 0 then
                            GRM_G.GroupInfo[ player ].main = { formerMemberData[ player ].mainAtTimeOfLeaving[1] };

                            if formerMemberData[ player ].mainAtTimeOfLeaving[3] ~= nil then
                                table.insert ( GRM_G.GroupInfo[ player ].main , GRM.GetClassColorRGB ( formerMemberData[ player ].mainAtTimeOfLeaving[3] , true ) );
                            else
                                -- Placeholder for old DB since never stored this info.
                                -- Just use generic class
                                table.insert ( GRM_G.GroupInfo[ player ].main , "|C"..(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)["WARRIOR"].colorStr );
                            end

                        end
                    end

                -- Check if
                else
                    local identified , playerInfo = GRM_GI.IsPlayerFormerMemberByGUID ( unitInfo.guid )

                    -- if Identified then the player name-Changed
                    if identified then
                        GRM_G.GroupInfo[ player ].isFormerGuildie = true;
                        GRM_G.GroupInfo[ player ].dateLeft = playerInfo[7];
                        GRM_G.GroupInfo[ player ].isBanned = { playerInfo[1] , playerInfo[2] , playerInfo[3] , playerInfo[4]};     -- isBanned, timeOfBanEpoch , reasonBanned, newName - Note, if not a nameChange then "playerInfo[4]" would be "" to check for empty string
                        GRM_G.GroupInfo[ player ].alts = GRM_GI.GetAltNames ( playerInfo[5] );
                        GRM_G.GroupInfo[ player ].isMain = playerInfo[6];
                        GRM_G.GroupInfo[ player ].main = {};
                        GRM_G.GroupInfo[ player ].connectedRealm = true;

                        if not GRM_G.GroupInfo[ player ].isMain and #GRM_G.GroupInfo[ player ].alts > 0 then
                            if #playerInfo[7] > 0 then
                                GRM_G.GroupInfo[ player ].main = { playerInfo[7][1] };

                                if playerInfo[7][3] ~= nil then
                                    table.insert ( GRM_G.GroupInfo[ player ].main , GRM.GetClassColorRGB ( playerInfo[7][3] , true ) );
                                else
                                    -- Placeholder for old DB since never stored this info.
                                    -- Just use generic class
                                    table.insert ( GRM_G.GroupInfo[ player ].main , "|C"..(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)["WARRIOR"].colorStr );
                                end

                            end
                        end

                    else
                        GRM_G.GroupInfo[ player ].isFormerGuildie = false;
                        GRM_G.GroupInfo[ player ].isBanned = { false };
                        GRM_G.GroupInfo[ player ].alts = {};
                        GRM_G.GroupInfo[ player ].connectedRealm = false;           -- This will be checked in other function if we know it is not a guildie, or a former guildie. Is it at least connected realm member?

                    end
                    GRM_G.GroupInfo[ player ].isGuildie = false;
                end

                GRM_G.GroupInfo[ player ].name = player;
                GRM_G.GroupInfo[ player ].class = unitInfo.class;
                GRM_G.GroupInfo[ player ].isReportedOn = false;
            end

            -- Rebuild these values every time anyway
            GRM_G.GroupInfo[ player ].unitID = unitInfo.unitID;
        end
    end
end


-- Method:          GRMGI_UI.LocalizeButtonFrame()
-- What it Does:    Reprocesses the font selection in case players change their settings
-- Purpose:         To allow settings changes on the fly.
GRMGI_UI.LocalizeButtonFrame = function ()
    if GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons ~= nil then
        for i = 1 , #GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons do

            if GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][2] then
                GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][2]:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );
            end
        end
    end

    if GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons ~= nil then
        for i = 1 , #GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons do

            if GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[i][2] then
                GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[i][2]:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );
            end

        end
    end

    GRM_GI.UpdateGroupInfo ( true );
    if GRMGI_UI.GRM_GroupButtonFrame:IsVisible() then
        GRM_GI.BuildGroupButtonFrame();
    end

end

-- Method:          GRM_GI.ReconfigureWidths ( int )
-- What it Does:    Reconfigures the width of the buttons and fontstrings
-- Purpose:         To allow dynamic reshaping of the mouseover Group Info window.
GRM_GI.ReconfigureWidths = function ( width )

    -- Redundancy
    if width < GRMGI_UI.GRM_GroupButtonFrame.TextFromServer:GetWidth() then
        width = GRMGI_UI.GRM_GroupButtonFrame.TextFromServer:GetWidth() + 5;
    end

    if GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons ~= nil then
        for i = 1 , #GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons do
            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1]:SetWidth ( width + 5 );
            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][2]:SetWidth ( width );       -- normalize all fontstrings to same width
        end
    end

    if GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons ~= nil then
        for i = 1 , #GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons do
            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[i][1]:SetWidth ( width + 5 );
            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[i][2]:SetWidth ( width );       -- normalize all fontstrings to same width
        end
    end
end

-- Method:          GRM_GI.SetValueButtonFrame ( string , table , int )
-- What it Does:    Sets the fontstring values by building the strings and also returns the width of the longest string.
-- Purpose:         To be able to dynamically build the Group Info frame as the group size changes and modifies.
GRM_GI.SetValueButtonFrame = function ( type , buttonDetails , sizeBiggest )
    local player = buttonDetails[1].player;
    local name , name2 = "" , "";
    local size = 0;

    if type == "guildies" then
        name = GRM.GetClassColorRGB ( player.class , true ) .. GRM.GetNameWithMainTags ( player.name , false , true , true , false ) .. "|r";
        if player.isBanned[1] then
            name = name .. " |CFFFF0000(" .. GRM.L ( "Banned" ) .. ")";
        end
        GRMGI_UI.GRM_GroupButtonFrame.GroupFrameFontStringTest:SetText ( name );
        buttonDetails[2]:SetText ( name );

    elseif type == "formerGuildies" then
        name = GRM.GetClassColorRGB ( player.class , true ) .. player.name .. "|r";

        local mainTag = GRM_G.MainTagHexCode .. GRM.GetMainTags ( false , GRM.S().mainTagIndex ) .. "|r";
        local altTag = GRM_G.MainTagHexCode .. GRM.GetAltTags ( false , GRM.S().mainTagIndex ) .. "|r"
        local numAltsStillInGuild = GRM_GI.GetNumAltsStillInGuild ( player.alts );

        if player.isMain then
            name = name .. mainTag;

        elseif #player.main > 0 then
            name2 = player.main[1]

            name = name .. altTag .. player.main[2] .. " " .. name2 .. "|r" .. mainTag;
        end

        if numAltsStillInGuild > 0 then
            if numAltsStillInGuild == 1 then
                name = name .. " - " .. GRM.L ( "1 Alt Still in Guild" );
            else
                name = name .. " - " .. GRM.L ( "{num} Alts Still in Guild" , nil , nil , numAltsStillInGuild );
            end
        end

        if player.isBanned[1] then
            name = name .. " |r - |CFFFF0000(" .. GRM.L ( "Banned" ) .. ")";
        end
        GRMGI_UI.GRM_GroupButtonFrame.GroupFrameFontStringTest:SetText ( name );
        buttonDetails[2]:SetText ( name );
        buttonDetails[3]:SetText ( player.dateLeft );

    elseif type == "serverMembers" then
        -- Keep full realm name
        name = GRM.GetClassColorRGB ( player.class , true ) .. player.name .. "|r";
        GRMGI_UI.GRM_GroupButtonFrame.GroupFrameFontStringTest:SetText ( name );
        buttonDetails[2]:SetText ( name );

    end

    size = GRMGI_UI.GRM_GroupButtonFrame.GroupFrameFontStringTest:GetWidth();
    size = size + 10;   -- for some leeway

    if sizeBiggest < size then
        if ( size - sizeBiggest ) < 10 then
            sizeBiggest = sizeBiggest + 10;
        else
            sizeBiggest = size;
        end
    end

    buttonDetails[1]:Show();

    return sizeBiggest;
end

GRM_GI.BuildGroupButtonFrame = function()
    local total , sameServer , currMembers , formerMembers , guildies , formerGuildies , serverMembers = GRM_GI.GetNumGroupMembersAndStatusDetails();
    local red = "|CFFFF0000";
    local height = 130;
    local width = 220;
    local minWidth = width - 10;
    local maxWidth = 0;
    local i , j , x = 0 , 0 , 0;

    local isAtLeastOne = function()
        if ( sameServer + currMembers + formerMembers ) > 0 then
            return true;
        else
            return false;
        end
    end

    GRMGI_UI.GRM_GroupButtonFrame.TextTotal:SetText ( GRM.L ( "Total in Group: {num}" , nil , nil , red .. total ) );

    -- Current Members
    GRMGI_UI.GRM_GroupButtonFrame.TextMembers:SetText ( GRM.L ( "Guildies: {num}" , nil , nil , red .. currMembers ) );

    for _ , player in pairs ( guildies ) do
        i = i + 1;

        -- Build the guildie frames.
        if not GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i] then
            local tempButton = CreateFrame ( "Button" , "GRM_GroupInfoButton" .. i , GRMGI_UI.GRM_GroupButtonFrame );

            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i] = { tempButton , tempButton:CreateFontString ( nil , "OVERLAY" , "GameFontWhiteTiny" ) };

            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1]:SetSize ( minWidth , 15 );
            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1]:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );

            if i == 1 then
                GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1]:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.TextMembers , "BOTTOMLEFT" , 0 , -1 );
            else
                GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1]:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i - 1][1] , "BOTTOMLEFT" );
            end

            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][2]:SetJustifyH ( "LEFT" );
            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][2]:SetPoint ( "LEFT" , GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1] , "LEFT" , 5 , 0 );
            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][2]:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );

            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1]:SetScript ( "OnEnter" , function ( self )
                GRM_GI.BuildMemberTooltip( self , i );
            end);

            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1]:SetScript ( "OnLeave" , function ()
                GRM_UI.RestoreTooltipScale();
                GameTooltip:Hide();
            end);

            GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1]:SetScript ( "OnClick" , function ( self , button )
                if button == "LeftButton" then
                    if IsShiftKeyDown() and IsControlKeyDown() then
                        GRM_UI.RestoreTooltipScale();
                        GameTooltip:Hide();
                        -- If Core GRM window is not open, let's open it!
                        if not GRM_UI.GRM_RosterChangeLogFrame:IsVisible() then
                            GRM_UI.GRM_RosterChangeLogFrame:Show();
                        end
                        GRM_UI.GRM_RosterChangeLogFrame.GRM_LogTab:Click();
                        GRM_UI.GRM_RosterChangeLogFrame.GRM_LogFrame.GRM_LogEditBox:SetText( GRM.SlimName ( self.player.name ) );

                    elseif IsControlKeyDown() then
                        GRM.OpenPlayerWindow( self.player.name );
                    end
                end
            end);

        end

        if i == 1 then
            height = height + 1;
        end
        height = height + GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1]:GetHeight();
        GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1].player = player;

        maxWidth = GRM_GI.SetValueButtonFrame ( "guildies" , GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i] , maxWidth );

    end

    -- Hide unused buttons...
    for k = i + 1 , #GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons do
        GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[k][1].player = nil;
        GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[k][1]:Hide();
    end

    if i > 0 then
        GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[i][1] , "BOTTOMLEFT" , 0 , -10 );
    else
        GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.TextMembers , "BOTTOMLEFT" , 0 , - 10 );
    end

    -- FORMER MEMBERS
    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers:SetText ( GRM.L ( "Former Guildies: {num}" , nil , nil , red .. formerMembers ) );

    for _ , player in pairs ( formerGuildies ) do
        j = j + 1;

        -- Build the guildie frames.
        if not GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j] then
            local tempButton = CreateFrame ( "Button" , "GRM_GroupInfoFormerMemberButton" .. j , GRMGI_UI.GRM_GroupButtonFrame );

            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j] = { tempButton , tempButton:CreateFontString ( nil , "OVERLAY" , "GameFontWhiteTiny" ) , tempButton:CreateFontString ( nil , "OVERLAY" , "GameFontWhiteTiny" ) };

            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1]:SetSize ( minWidth , 15 );
            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1]:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );

            if j == 1 then
                GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1]:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers , "BOTTOMLEFT" , 0 , -1 );
            else
                GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1]:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j - 1][1] , "BOTTOMLEFT" );
            end

            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][2]:SetJustifyH ( "LEFT" );
            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][2]:SetPoint ( "LEFT" , GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1] , "LEFT" , 5 , 0 );
            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][2]:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );
            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][3]:SetWidth ( 95 );
            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][3]:SetJustifyH ( "CENTER" );
            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][3]:SetPoint ( "LEFT" , GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1] , "RIGHT" );

            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1]:SetScript ( "OnEnter" , function ( self )
                GRM_GI.BuildFormerMemberTooltip( self , j );
            end);

            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1]:SetScript ( "OnLeave" , function ()
                GRM_UI.RestoreTooltipScale();
                GameTooltip:Hide();
            end);

            GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1]:SetScript ( "OnClick" , function ( self , button )
                if button == "LeftButton" then
                    if IsShiftKeyDown() and IsControlKeyDown() then
                        GRM_UI.RestoreTooltipScale();
                        GameTooltip:Hide();
                        -- If Core GRM window is not open, let's open it!
                        if not GRM_UI.GRM_RosterChangeLogFrame:IsVisible() then
                            GRM_UI.GRM_RosterChangeLogFrame:Show();
                        end
                        GRM_UI.GRM_RosterChangeLogFrame.GRM_LogTab:Click();
                        GRM_UI.GRM_RosterChangeLogFrame.GRM_LogFrame.GRM_LogEditBox:SetText( GRM.SlimName ( self.player.name ) );
                    end
                end
            end);
        end

        if j == 1 then
            height = height + 1;
        end
        height = height + GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1]:GetHeight();
        GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1].player = player;

        maxWidth = GRM_GI.SetValueButtonFrame ( "formerGuildies" , GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j] , maxWidth );
    end

    -- Hide unused buttons...
    for k = j + 1 , #GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons do
        GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[k][1].player = nil;
        GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[k][1]:Hide();
    end

    if j > 0 then
        GRMGI_UI.GRM_GroupButtonFrame.TextFromServer:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[j][1] , "BOTTOMLEFT" , 0 , -10 );
        GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft:Show();
        GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft:ClearAllPoints();
        GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft:SetPoint ( "BOTTOM" , GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[1][3] , "TOP" , 0 , 5 );
    else
        GRMGI_UI.GRM_GroupButtonFrame.TextFromServer:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers , "BOTTOMLEFT" , 0 , - 10 );
        GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft:Hide();
    end

    GRMGI_UI.GRM_GroupButtonFrame.TextFromServer:SetText ( GRM.L ( "Other {name} Members: {num}" , GetRealmName() , nil , red .. sameServer ) );

    for _ , player in pairs ( serverMembers ) do
        x = x + 1;

        -- Build the guildie frames.
        if not GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x] then
            local tempButton = CreateFrame ( "Button" , "GRM_GroupInfoFormerMemberButton" .. x , GRMGI_UI.GRM_GroupButtonFrame );

            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x] = { tempButton , tempButton:CreateFontString ( nil , "OVERLAY" , "GameFontWhiteTiny" ) , tempButton:CreateFontString ( nil , "OVERLAY" , "GameFontWhiteTiny" ) };

            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1]:SetSize ( minWidth , 15 );
            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1]:SetHighlightTexture ( "Interface\\Buttons\\UI-Panel-Button-Highlight" );

            if x == 1 then
                GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1]:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.TextFromServer , "BOTTOMLEFT" , 0 , -1 );
            else
                GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1]:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x - 1][1] , "BOTTOMLEFT" );
            end

            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][2]:SetJustifyH ( "LEFT" );
            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][2]:SetPoint ( "LEFT" , GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1] , "LEFT" , 5 , 0 );
            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][2]:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );
            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][3]:SetWidth ( 95 );
            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][3]:SetJustifyH ( "CENTER" );
            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][3]:SetPoint ( "LEFT" , GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1] , "RIGHT" );

            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1]:SetScript ( "OnEnter" , function ( self )
                GRM_GI.BuildServerMemberTooltip( self , x );
            end);

            GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1]:SetScript ( "OnLeave" , function ()
                GRM_UI.RestoreTooltipScale();
                GameTooltip:Hide();
            end);

        end

        if x == 1 then
            height = height + 1;
        end
        height = height + GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1]:GetHeight();
        GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x][1].player = player;

        maxWidth = GRM_GI.SetValueButtonFrame ( "serverMembers" , GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[x] , maxWidth );
    end

    -- Hide unused buttons...
    for k = x + 1 , #GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons do
        GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[k][1].player = nil;
        GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[k][1]:Hide();
    end

    if maxWidth > minWidth then
        width = maxWidth;
    else
        width = minWidth;
    end

    GRM_GI.ReconfigureWidths ( width );
    if isAtLeastOne() then
        if formerMembers > 0 then
            width = width + 120;        -- the Date Left fontstring adds and extra 95 width, plus extra for spacing
        end
    end
    GRMGI_UI.GRM_GroupButtonFrame:SetSize ( width + 25 , height );
    GRMGI_UI.GRM_GroupButtonFrame:Show();
end

GRM_GI.BuildMemberTooltip = function ( button , ind )
    local player = button.player;

    GRM_UI.SetTooltipScale()
    GameTooltip:SetOwner ( button , "ANCHOR_CURSOR" );
    GameTooltip:AddLine( GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons[ind][2]:GetText() );
    GameTooltip:AddLine ( " " );

    GameTooltip:AddLine ( GRM.L ( "{custom1} to open Player Window" , nil , nil , nil , "|CFFE6CC7F" .. GRM.L ( "Ctrl-Click" ) .. "|r" ) );
    GameTooltip:AddLine ( GRM.L ( "{custom1} to Search the Log for Player" , nil , nil , nil , "|CFFE6CC7F" .. GRM.L ( "Ctrl-Shift-Click" ) .. "|r" ) );

    GameTooltip:Show();
end

GRM_GI.BuildFormerMemberTooltip = function ( button , ind )
    local player = button.player;

    GRM_UI.SetTooltipScale()
    GameTooltip:SetOwner ( button , "ANCHOR_CURSOR" );
    GameTooltip:AddLine( GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons[ind][2]:GetText() );

    -- if a NameChange
    if player.isBanned[4] ~= "" then
        GameTooltip:AddLine ( GRM.L ( "{name} has Name-Changed to {name2}" , GRM.GetClassColorRGB ( player.class , true ) .. GRM.FormatName ( player.isBanned[4] ) .. "|r" , GRM.GetClassColorRGB ( player.class , true ) .. GRM.FormatName ( player.name ) ) , 0.90 , 0.82 , 0.62 );
    end

    -- If a Ban
    if player.isBanned[1] then
        local reason = player.isBanned[3];
        if reason ~= "" then
            GameTooltip:AddLine ( "\n|CFFFF0000" .. GRM.L ( "Reason Banned:" ) .. "|r |CFFFFFFFF" .. reason , 1 , 1 , 1 , 1 , true );
        else
            GameTooltip:AddLine ( "\n|CFFFF0000" .. GRM.L ( "Reason Banned:" ) .. "|r |CFFFFFFFF" .. GRM.L ( "None Given" ) );
        end

        GameTooltip:AddLine ( GRM.L ( "Date Left" ) .. ": |CFFFFFFFF" .. player.dateLeft );

    end

    GameTooltip:AddLine ( " " );

    local numAltsStillInGuild = GRM_GI.GetNumAltsStillInGuild ( player.alts );

    if numAltsStillInGuild > 0 then
        local main = "";
        if #player.main > 0 then
            main = player.main[1];
        end

        if numAltsStillInGuild > 1 or main == "" then
            GameTooltip:AddLine ( GRM.L ( "Known Alts:" ) );
            local inGuild = ( "|cff7fff00 - " .. GRM.L ( "(Still in Guild)" ) );
            local msg;

            for name , alt in pairs ( player.alts ) do
                msg = "";
                if alt.currentMember then
                    msg = ( alt.hexCode .. GRM.FormatName ( name ) .. " " .. inGuild );
                else
                    msg = ( alt.hexCode .. GRM.FormatName ( name ) );
                end

                if name == main then
                    msg = msg .. "|r |cffff0000" .. GRM.L ( "(main)" );
                end

                GameTooltip:AddLine ( msg );

            end
        end

        GameTooltip:AddLine ( " " );
    end

    GameTooltip:AddLine ( GRM.L ( "{custom1} to Search the Log for Player" , nil , nil , nil , "|CFFE6CC7F" .. GRM.L ( "Ctrl-Shift-Click" ) .. "|r" ) );
    GameTooltip:Show();

end

GRM_GI.BuildServerMemberTooltip = function ( button , ind )
    local player = button.player;

    GRM_UI.SetTooltipScale()
    GameTooltip:SetOwner ( button , "ANCHOR_CURSOR" );
    GameTooltip:AddLine( GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons[ind][2]:GetText() );
    GameTooltip:Show();
end

-- Method:          GRM_GI.GroupCheckRepeatControl()
-- What it Does:    It rechecks the groupRosterStatus 3 times, jsut in case, due to variouus reasons, the server doesn't communicate back group status quick enough.
-- Purpose:         The button may not appear if it doesn't register group statuss instantly. This ensures the check.
GRM_GI.GroupCheckRepeatControl = function ( count )
    GRM_GI.GroupRosterUpdate();
    count = count + 1;

    if count < 4 then

        C_Timer.After ( 1 , function()
            GRM_GI.GroupCheckRepeatControl ( count );
        end);

    end
end

-- Method:          GRM_GI.EventListener()
-- What it Does:    Listens for the tracked events and initiates the given function
-- Purpose:         Event listening control
GRM_GI.EventListener = function()

    -- Sometimes there is a delay with the server, so we are going to trigger it 3 times to check
    if ( time() - GRM_G.StatusChecking.Timer ) >= 3.1 then

        C_Timer.After ( 1 , function()
            GRM_GI.GroupCheckRepeatControl ( 1 );
        end);

        GRMGI_UI.GroupInfoButtonInit();
        GRM_G.StatusChecking.Timer = time();
    end

end

-- Method:          GRM_GI.GroupRosterUpdate()
-- What it Does:    Calls the roster update or clears it
-- Purpose:         Live control of group info for use
GRM_GI.GroupRosterUpdate = function()
     if IsInGuild() and GRM_G.InGroup then
        C_Timer.After ( 1 , function()
            GRM_GI.UpdateGroupInfo ( false );

            -- Auto update the frame if it is visible
            if GRMGI_UI.GRM_GroupButtonFrame:IsVisible() then
                GRM_GI.BuildGroupButtonFrame();
            end
            GRM_GI.SetGroupInfoButtonPosition();

        end);
    else
        GRM_G.GroupInfo = {};
        if GRMGI_UI.GRM_GroupRulesButton:IsVisible() then
            GRMGI_UI.GRM_GroupRulesButton:Hide();
        end
    end
end

-- Method:          GRM_GI.RegisterModule()
-- What it Does:    Registers this addon
GRM_GI.RegisterModule = function()
    if GRM_G.Module ~= nil then
        GRM_G.Module.GroupInfo = true;
    end
end

-- Method:          GRM_GI.DelayCheck()
-- What it Does:    Retries the settings ever 5 seconds.
-- Purpose:         To ensure the core addon is loaded before it tries to do anything.
GRM_GI.DelayCheck = function()
    C_Timer.After ( 5 , GRM_GI.LoadGroupInfoModuleSettings );
end

-- Method:          GRM_GI.UpgradeAnnounceMessage()
-- What it Does:    Reports to player if addon module is outdated
-- Purpose:         Make sure versions line up.
GRM_GI.UpgradeAnnounceMessage = function()
    if GRM_G.Version then

        if GRM_G.GroupInfoV and GRM_G.GroupInfoV > GRM_GI.version then

            local GRMVersion = tonumber ( string.match ( GRM_G.Version , "R(.+)" ) );
            local message = "Group Info Module is Outdated."

            if GRMVersion > 1.96 then       -- Localization file didn't exist until 1.97 -- Needed to update to bring consistent.
                print ( GRM.L ( "GRM:" ) .. " " .. GRM.L ( message ) );
            else
                print ( "GRM: " .. message );
            end
        end
    end
end

-- Method:          GRM_GI.LoadGroupInfoModuleSettings()
-- What it Does:    Loads this module's settings, first by not loading until the core addon is loaded.
-- Purpose:         Control actions as needed. Only load as needed
--                  Note: This is kept in the global GRM_G table so it can be accessed from the core GRM to reload if a player leaves a guild and
--                  ultimately rejoins a guild. Thus it will disable, restart fresh, and re-enable the next time it groups up.
GRM_GI.LoadGroupInfoModuleSettings = function()
    -- Make sure not to load this addon until the game DB is built first.

    if GRM_G.OnFirstLoad or not IsInGuild() then
        GRM_GI.DelayCheck();
        return;
    else
        GRM_GI.RegisterModule();
        GRMGI_UI.LoadUI();

        if not GRM_GI.UpgradeAnnounce and GRM_G.Version then
            GRM_GI.UpgradeAnnounce = true;
            if GRM.S().syncCompatibilityMsg then
                GRM_GI.UpgradeAnnounceMessage();
            end
        end

        -- If a player reloads - need to reload this info as needed.
        if IsInGuild() and GRM_G.InGroup then
            GRM_GI.UpdateGroupInfo();
        end
    end
end

-- Method:          GRM_GI.GetCustomUIButtonName ( string , int , int )
-- What it Does:    Returns the proper button name based on custom UI formatting.
-- Purpose:         Modifier for increased compatibility with all addons and a universal formatting for single function use among all.
GRM_GI.GetCustomUIButtonName = function ( buttonName , j , special )
    local result = buttonName;

    if string.find ( result , "XX" ) ~= nil then

        if GRM_GI.UIAddonCompatibilityName ~= "Vuhdo" then
            local group = 0;

            if j < 6 then
                group = 1;
            elseif j < 11 then
                group = 2;
            elseif j < 16 then
                group = 3;
            elseif j < 21 then
                group = 4;
            elseif j < 26 then
                group = 5;
            elseif j < 31 then
                group = 6;
            elseif j < 36 then
                group = 7;
            elseif j < 41 then
                group = 8;
            end

            result = string.gsub ( string.gsub ( result , "XX" , group ) , "YY" , special );

        else
            result = string.gsub ( result , "XX" , j )
        end
    else
        result = result .. j;
    end;

    return result;
end

-- Method:          GRM_GI.SetGroupInfoButtonPosition()
-- What it Does:    Adjusts the position of the button depending on if the raid window is open or not
-- Purpose:         Flexible adjustment of the location of the GMR Group Info frame
GRM_GI.SetGroupInfoButtonPosition = function()
    if GRM.S() and GRM.S().GIModule then
        if GRM.S().GIModule.enabled and IsInGuild() and ( IsInRaid() or GRM_G.InGroup ) and GRM_GI.GetNumGroupMembersAndStatusDetails() > 1 then

            if not GRMGI_UI.GRM_GroupRulesButton:IsVisible() then
                GRMGI_UI.GRM_GroupRulesButton:Show();
            end

        else
            GRM_GI.lock = false;
            GRMGI_UI.GRM_GroupButtonFrame:Hide();
            GRMGI_UI.GRM_GroupRulesButton:Hide();
        end
    end
end

-- UI SETTINGS!!!

GRMGI_UI.GRM_GroupRulesButton = CreateFrame( "Button" , "GRM_GroupRulesButton" , UIParent , "UIPanelButtonTemplate" );
GRMGI_UI.GRM_GroupRulesButton:Hide();
GRMGI_UI.GRM_GroupRulesButton.Text = GRMGI_UI.GRM_GroupRulesButton:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" );

GRMGI_UI.GRM_GroupButtonFrame = CreateFrame ( "Frame" , "GRM_GroupButtonFrame" , GRMGI_UI.GRM_GroupRulesButton , "TranslucentFrameTemplate" );
GRMGI_UI.GRM_GroupButtonFrame.GRM_GroupButtonFrameCloseButton = CreateFrame( "Button" , "GRM_GroupButtonFrameCloseButton" , GRMGI_UI.GRM_GroupButtonFrame , "UIPanelCloseButton");
GRMGI_UI.GRM_GroupButtonFrame.memberNameButtons = {};
GRMGI_UI.GRM_GroupButtonFrame.formerMemberNameButtons = {};
GRMGI_UI.GRM_GroupButtonFrame.serverNameButtons = {};

GRMGI_UI.GRM_GroupButtonFrame.TextTitle = GRMGI_UI.GRM_GroupButtonFrame:CreateFontString ( nil , "OVERLAY" , "GameFontWhiteTiny" );
GRMGI_UI.GRM_GroupButtonFrame.TextTotal = GRMGI_UI.GRM_GroupButtonFrame:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" );
GRMGI_UI.GRM_GroupButtonFrame.TextMembers = GRMGI_UI.GRM_GroupButtonFrame:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" );
GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers = GRMGI_UI.GRM_GroupButtonFrame:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" );
GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft = GRMGI_UI.GRM_GroupButtonFrame:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" );
GRMGI_UI.GRM_GroupButtonFrame.TextFromServer = GRMGI_UI.GRM_GroupButtonFrame:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" );

GRMGI_UI.GRM_GroupButtonFrame.GroupFrameFontStringTest = GRMGI_UI.GRM_GroupButtonFrame:CreateFontString ( nil , "OVERLAY" , "GameFontWhiteTiny" );

-- Method:          GRMGI_UI.GroupInfoButtonUpdatePos()
-- What it Does:    Updates the position of the Group Info module to the default position, either for a bare GRM, or for one of the custom supported UIs.
-- Purpose:         Quality control of button placement.
GRMGI_UI.GroupInfoButtonUpdatePos = function()
    GRMGI_UI.GRM_GroupRulesButton:ClearAllPoints();
    GRMGI_UI.GRM_GroupRulesButton:SetPoint ( GRM_GI.CustomButtonPosition[1] , UIParent , GRM_GI.CustomButtonPosition[2] , GRM_GI.CustomButtonPosition[3] , GRM_GI.CustomButtonPosition[4] );
end

local updateAddonWithMultiplePositions = function()
    GRM_GroupInfo_Save[GRM_G.addonUser].raid = {};
    GRM_GroupInfo_Save[GRM_G.addonUser].party = {};

    if #GRM_GroupInfo_Save[GRM_G.addonUser] > 0 then
        for i = 1 , #GRM_GroupInfo_Save[GRM_G.addonUser] do
            GRM_GroupInfo_Save[GRM_G.addonUser].raid[i] = GRM_GroupInfo_Save[GRM_G.addonUser][i];
            GRM_GroupInfo_Save[GRM_G.addonUser].party[i] = GRM_GroupInfo_Save[GRM_G.addonUser][i];
            GRM_GroupInfo_Save[GRM_G.addonUser][i] = nil;
        end
    end
end

-- Method:          GRMGI_UI.GroupInfoButtonInit()
-- What it Does     Initializes the button position values for custom placement on UIParent
-- Purpose:         Customizable and movable button
GRMGI_UI.GroupInfoButtonInit = function()
    if not GRM_GroupInfo_Save[GRM_G.addonUser] then
        GRM_GroupInfo_Save[GRM_G.addonUser] = {};
        GRM_GroupInfo_Save[GRM_G.addonUser].party = { "CENTER" , "CENTER" , -200 , 0 };
        GRM_GroupInfo_Save[GRM_G.addonUser].raid = { "CENTER" , "CENTER" , -200 , 0 };
    end

    if not GRM_GroupInfo_Save[GRM_G.addonUser].raid then
        updateAddonWithMultiplePositions();
    end

    if IsInRaid() then
        GRM_GI.CustomButtonPosition = GRM_GroupInfo_Save[GRM_G.addonUser].raid;
    else
        GRM_GI.CustomButtonPosition = GRM_GroupInfo_Save[GRM_G.addonUser].party;
    end
    GRMGI_UI.GroupInfoButtonUpdatePos();

end

-- Method:          GRM_UI.ResetGroupInfoButtonToDefault()
-- What it Does:    Sets the button back to default positions based on compatible UI
-- Purpose:         Increased functionality and control of button placement.
GRMGI_UI.ResetGroupInfoButtonToDefault = function()
    GRM_GI.CustomButtonPosition = nil;
    GRM_GI.CustomButtonPosition = {};
    GRM_GroupInfo_Save[GRM_G.addonUser] = {};
    GRM_GroupInfo_Save[GRM_G.addonUser].party = { "CENTER" , "CENTER" , -200 , 0 };
    GRM_GroupInfo_Save[GRM_G.addonUser].raid = { "CENTER" , "CENTER" , -200 , 0 };
    GRMGI_UI.GroupInfoButtonInit();
end

-- Method:          GRMGI_UI.LoadUI()
-- What it Does:    Loads the module's UI frames
-- Purpose:         Compartmentalize the load for on-demand use and to avoid using if not guilded.
GRMGI_UI.LoadUI = function()
    GRMGI_UI.InitializeUIFrames();
    GRM_UI.InitializeLocalizations();
    GRMGI_UI.GroupInfoButtonInit();
    GRM_GI.SetGroupInfoButtonPosition();
end

-- Method:          GRMGI_UI.InitializeUIFrames()
-- What it Does:    Builds every Group info Module UI frame and their values, initializing them and pinning them to core GRM
-- Purpose:         Compartmentalize the load for on-demand use
GRMGI_UI.InitializeUIFrames = function()
    GRMGI_UI.GRM_GroupRulesButton:SetSize ( 90 , 25 );
    GRMGI_UI.GRM_GroupRulesButton:SetMovable ( false );
    GRMGI_UI.GRM_GroupRulesButton:RegisterForDrag ( "LeftButton" );
    GRMGI_UI.GRM_GroupRulesButton.Text:SetPoint ( "CENTER" , GRMGI_UI.GRM_GroupRulesButton );
    GRMGI_UI.GRM_GroupRulesButton.Timer = 0;

    GRMGI_UI.GRM_GroupRulesButton:SetScript ( "OnClick" , function ( _ , button )
        if button == "LeftButton" then
            if ( RaidFrame:IsVisible() and IsInRaid() ) or not IsControlKeyDown() then
                GRM_GI.lock = true;
                GRM_GI.UpdateGroupInfo ( true );
                GRM_GI.BuildGroupButtonFrame();
                GRMGI_UI.GRM_GroupButtonFrame.GRM_GroupButtonFrameCloseButton:Show();

                if GameTooltip:IsVisible() then
                    GRM_UI.RestoreTooltipScale();
                    GameTooltip:Hide();
                end
            end
        end
    end);

    GRMGI_UI.GRM_GroupButtonFrame:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupRulesButton , "TOPRIGHT" , 10 , 0 );
    GRMGI_UI.GRM_GroupButtonFrame:SetSize ( 250 , 175 );
    GRMGI_UI.GRM_GroupButtonFrame:Hide();

    GRMGI_UI.GRM_GroupButtonFrame.GRM_GroupButtonFrameCloseButton:SetPoint ( "TOPRIGHT" , GRMGI_UI.GRM_GroupButtonFrame , "TOPRIGHT" );
    GRMGI_UI.GRM_GroupButtonFrame.GRM_GroupButtonFrameCloseButton:Hide();
    GRMGI_UI.GRM_GroupButtonFrame.GRM_GroupButtonFrameCloseButton:SetScript ( "OnClick" , function ( self , button )
        if button == "LeftButton" then
            self:Hide();
            GRMGI_UI.GRM_GroupButtonFrame:Hide();
            GRM_GI.lock = false;
        end
    end);

    GRMGI_UI.GRM_GroupButtonFrame:SetScript ( "OnKeyDown" , function ( self , key )
        if not GRM_G.inCombat then
            self:SetPropagateKeyboardInput ( true );
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput ( false );
                self:Hide();
                GRMGI_UI.GRM_GroupButtonFrame.GRM_GroupButtonFrameCloseButton:Hide();
                GRM_GI.lock = false;
            end
        elseif key == "ESCAPE" then
            self:Hide();
            GRMGI_UI.GRM_GroupButtonFrame.GRM_GroupButtonFrameCloseButton:Hide();
            GRM_GI.lock = false;
        end
    end);

    GRMGI_UI.GRM_GroupButtonFrame.TextTitle:SetPoint ( "TOP" , GRMGI_UI.GRM_GroupButtonFrame , "TOP" , 0 , -15 );
    GRMGI_UI.GRM_GroupButtonFrame.TextTitle:SetTextColor ( 0 , 0.8 , 1 );
    GRMGI_UI.GRM_GroupButtonFrame.TextTotal:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame , "TOPLEFT" , 15 , -33 );
    GRMGI_UI.GRM_GroupButtonFrame.TextMembers:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.TextTotal , "BOTTOMLEFT" , 0 , - 10 );
    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers:SetWidth ( 200 );
    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers:SetWordWrap ( false );
    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers:SetJustifyH ( "LEFT" );
    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft:SetJustifyH ( "CENTER" );
    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft:SetWidth ( 100 );
    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft:SetWordWrap ( false );

    if GRM_G.BuildVersion >= 20000 then
        GRMGI_UI.GRM_GroupButtonFrame.TextFromServer:SetPoint ( "TOPLEFT" , GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers , "BOTTOMLEFT" , -5 , - 10 );
    else
        GRMGI_UI.GRM_GroupButtonFrame.TextFromServer:Hide();
    end

    GRMGI_UI.GRM_GroupRulesButton:SetScript ( "OnEnter" , function ( self )
        if not GRMGI_UI.GRM_GroupButtonFrame:IsVisible() then
            GRM_GI.BuildGroupButtonFrame ();

            if not GRM.S().GIModule.DisableGroupInfoTooltip then
                GRM_UI.SetTooltipScale()
                GameTooltip:SetOwner ( self , "ANCHOR_CURSOR" );
                GameTooltip:AddLine ( GRM.L ( "Click to Lock Info Window" ) );
                GameTooltip:AddLine ( " " );
                GameTooltip:AddLine ( GRM.L ( "{custom1} and drag to move this button anywhere." , nil , nil , nil , "|CFFE6CC7F" .. GRM.L ( "Ctrl-Left-Click" ) .. "|r" ) );
                GameTooltip:Show();
            end

        end
    end);

    GRMGI_UI.GRM_GroupRulesButton:SetScript ( "OnLeave" , function ()
        if not GRM_GI.lock then
            GRMGI_UI.GRM_GroupButtonFrame:Hide();

            if not GRM.S().GIModule.DisableGroupInfoTooltip then
                GRM_UI.RestoreTooltipScale();
                GameTooltip:Hide();
            end

        end
    end);

    -- Hide button if you leave a guild
    GRMGI_UI.GRM_GroupRulesButton:SetScript ( "OnUpdate" , function ( self , elapsed )
        GRMGI_UI.GRM_GroupRulesButton.Timer = GRMGI_UI.GRM_GroupRulesButton.Timer + elapsed;

        if GRMGI_UI.GRM_GroupRulesButton.Timer > 0.5 then

            if not IsInGuild() then
                self:Hide();
            end

        end

    end);

    GRMGI_UI.SetSavePosition = function( side1 , side2 , point1 , point2 )

        if not GRM_GroupInfo_Save[GRM_G.addonUser] then
            GRM_GroupInfo_Save[GRM_G.addonUser] = {};
        end

        if IsInRaid() then
            GRM_GroupInfo_Save[GRM_G.addonUser].raid = { side1 , side2 , point1 , point2 };
        elseif GRM_G.InGroup then
            GRM_GroupInfo_Save[GRM_G.addonUser].party = { side1 , side2 , point1 , point2 };
        end
    end

    GRMGI_UI.GRM_GroupRulesButton:SetScript ( "OnDragStart" , function ( self )
        if IsControlKeyDown() then
            -- Draggable anywhere.
            self:SetMovable ( true );
            self:StartMoving();

            GRM_UI.RestoreTooltipScale();
            GameTooltip:Hide();
        end
    end);

    GRMGI_UI.GRM_GroupRulesButton:SetScript ( "OnDragStop" , function ( self )
        self:StopMovingOrSizing();

        local side1, _ , side2 , point1 , point2 = GRMGI_UI.GRM_GroupRulesButton:GetPoint();
        GRM_GI.CustomButtonPosition = { side1 , side2 , point1 , point2 };
        GRMGI_UI.SetSavePosition ( side1 , side2 , point1 , point2 );
        self:SetMovable ( false );
    end)

    GRM_UI.GRM_MemberDetailMetaData.GRM_DayDropDownMenuSelected:SetScript ( "OnEnter" , function( self )
        if not GRM_UI.GRM_MemberDetailMetaData.GRM_DayDropDownMenu:IsVisible() then
            GRM_UI.SetTooltipScale()
            GameTooltip:SetOwner ( self , "ANCHOR_CURSOR" );
            GameTooltip:AddLine( GRM.L ( "|CFFE6CC7FClick|r to Change Day" ) );
            GameTooltip:Show();
        end
    end);

    GRM_UI.GRM_MemberDetailMetaData.GRM_DayDropDownMenuSelected:SetScript ( "OnLeave" , function()
        GRM_UI.RestoreTooltipScale();
        GameTooltip:Hide();
    end);

    GRMGI_UI.GRM_GroupRulesButton:HookScript ( "OnLeave" , GRMGI_UI.GRM_GroupRulesButton:GetScript ( "OnMouseUp"  ) );

    if not GRM.S().GIModule.enabled then
        GRMGI_UI.GRM_GroupRulesButton:Hide();
    end

end

-- Method:          GRM_UI.InitializeLocalizations()
-- What it Does:    Reprocesses all of the fontstrings of this module for localization and font changes
-- Purpose:         Customization options for the user.
GRM_UI.InitializeLocalizations = function()

    GRMGI_UI.GRM_GroupRulesButton.Text:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 9 );
    GRMGI_UI.GRM_GroupRulesButton.Text:SetText ( GRM.L ( "GRM Info" ) );

    GRMGI_UI.GRM_GroupButtonFrame.TextTitle:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 14 , "THICKOUTLINE" );
    GRMGI_UI.GRM_GroupButtonFrame.TextTitle:SetText ( GRM.L ( "GRM Group Info" ) );

    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );
    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembersDateLeft:SetText ( GRM.L ( "Date Left" ) );

    GRMGI_UI.GRM_GroupButtonFrame.TextTotal:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );
    GRMGI_UI.GRM_GroupButtonFrame.TextMembers:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );
    GRMGI_UI.GRM_GroupButtonFrame.TextFormerMembers:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );

    GRMGI_UI.GRM_GroupButtonFrame.TextFromServer:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );

    GRMGI_UI.GRM_GroupButtonFrame.GroupFrameFontStringTest:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 11 );

    if GRM_GI.optionsLoaded then
        GRM_UI.LocalizeOptions();
    end

    GRMGI_UI.LocalizeButtonFrame();
end

-- Method:          GRM_UI.LoadGroupInfoOptions()
-- What it Does:    Loads the options for the core frame
-- Purpose:         To Build the info for the module.
GRM_UI.LoadGroupInfoOptions = function()
    if not GRM_GI.optionsLoaded then
        -- Options Module Header
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.Header = GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.Header:SetPoint ( "TOPLEFT" , GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame , 18 , - 12 );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.Header:SetTextColor ( 0.0 , 0.8 , 1.0 , 1.0 );

        -- Options Enable/Disable Checkbox
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButton = CreateFrame ( "CheckButton" , "GRM_EnableGIModuleCheckButton" , GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame , "InterfaceOptionsCheckButtonTemplate" );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButton:SetPoint ( "TOPLEFT" , GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.Header , "BOTTOMLEFT" , -4 , -4 );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButtonText = GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButton:CreateFontString ( nil , "OVERLAY" , "GameFontNormalSmall" );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButtonText:SetPoint ( "LEFT" , GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButton , "RIGHT" , 1 , 0 );

        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButton:SetScript ( "OnClick" , function( self , button )
            if button == "LeftButton" then
                if self:GetChecked() then
                    GRM.S().GIModule.enabled = true;
                    GRM_GI.GroupRosterUpdate();
                else
                    GRM.S().GIModule.enabled = false;
                    GRMGI_UI.GRM_GroupRulesButton:Hide();
                end
                GRM_UI.ConfigureGroupInfoRules();
            end
        end);

        -- Options Disable tooltip info
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton = CreateFrame ( "CheckButton" , "GRM_DisableGroupInfoTooltipCheckButton" , GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame , "InterfaceOptionsCheckButtonTemplate" );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipText = GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton:CreateFontString ( nil , "OVERLAY" , "GameFontNormalSmall" );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton:SetPoint ( "TOPLEFT" , GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButton , "BOTTOMLEFT" , 0 , -6 );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipText:SetPoint ( "LEFT" , GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton , "RIGHT" , 1 , 0 );

        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton:SetScript ( "OnClick" , function( self , button )
            if button == "LeftButton" then
                if self:GetChecked() then
                    GRM.S().GIModule.DisableGroupInfoTooltip = true;
                else
                    GRM.S().GIModule.DisableGroupInfoTooltip = false;
                end
                GRM_UI.ConfigureGroupInfoRules();
            end
        end);

        GRM_GI.optionsLoaded = true;
    end

    GRM_UI.ConfigureGroupInfoRules();
    GRM_UI.LocalizeOptions();
end

-- Method:          GRM_UI.ConfigureGroupInfoRules()
-- What it Does:    Reconfigures the buttons and text of this module to either be colored or greyed out
-- Purpose:         UX feature greyed out if not in use for obvious disabling and enabling visual cue.
GRM_UI.ConfigureGroupInfoRules = function()
    if GRM.S().GIModule.enabled then
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButton:SetChecked ( true );

        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipText:SetTextColor ( 1.0 , 0.82 , 0 , 1.0 );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton:Enable();
        if GRM.S().GIModule.DisableGroupInfoTooltip then
            GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton:SetChecked ( true );
        end

    else

        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipText:SetTextColor ( 0.5, 0.5 , 0.5 , 1.0 );
        GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton:Disable();
        if GRM.S().GIModule.DisableGroupInfoTooltip then
            GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton:SetChecked ( true );
        end

    end
end

-- Method:          GRM_UI.LocalizeOptions()
-- What it Does:    Reprocesses the string and their fonts
-- Purpose:         Compartmentalize the loading so they can be reprocessed on settings changes.
GRM_UI.LocalizeOptions = function()
    GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.Header:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 20 );
    GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.Header:SetText ( GRM.L ( "Group Info" ) );

    GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButtonText:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 12 );
    GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButtonText:SetText ( GRM.L ( "Enable Module" ) );
    GRM.NormalizeHitRects ( GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButton , GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_EnableGIModuleCheckButtonText );

    GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipText:SetFont ( GRM_G.FontChoice , GRM_G.FontModifier + 12 );
    GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipText:SetText ( GRM.L ( "Disable tooltip. Only show popout window." ) );
    GRM.NormalizeHitRects ( GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipCheckButton , GRM_UI.GRM_RosterChangeLogFrame.GRM_OptionsFrame.GRM_ModulesFrame.GRM_DisableGroupInfoTooltipText );

end

-- No need to delay for addon to load as the LoadGroupInfoModuleSettings will recursively loop until it is ready.
GRM_GI.LoadGroupInfoModuleSettings();
-- need to write logic if addon player leaves a guild, it is disabled, then for when they rejoin a guild
-- Check GUID to see if former namechange