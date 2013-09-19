local CATEGORY_NAME = "Utility"

CreateConVar("ulx_warnkick_num", 3, FCVAR_ARCHIVE, "Number of warnings a player needs before they are kicked/banned.")
CreateConVar("ulx_warnkick_decayrate", 30, FCVAR_ARCHIVE, "Minutes a player needs to be connected before their warning count is decreased by 1.")
CreateConVar("ulx_warnkick_ban", 0, FCVAR_ARCHIVE, "If this is set to 1, the script will issue a temp ban instead of a kick.")
CreateConVar("ulx_warnkick_bantime", 30, FCVAR_ARCHIVE, "How long in minutes a player is banned if ulx_warkick_ban is set to 1.")

if !file.Exists( "ulx", "DATA" ) then
	file.CreateDir( "ulx" )
end

if !file.Exists( "ulx/Warnings", "DATA" ) then
	file.CreateDir( "ulx/Warnings" )
end

--[[
	ulx.warn( calling_ply, target_ply, reason )
	calling_ply	: PlayerObject	: Player who ran the command.
	target_ply	: PlayerObject	: Player who is being warned.
	reason		: String		: Reason player is being warned.
	
	This function is the ULX function that allows for a warning of a player.
]]
function ulx.warn( calling_ply, target_ply, reason )
	if reason and reason ~= "" then
		ulx.fancyLogAdmin( calling_ply, "#A warned #T (#s)", target_ply, reason )
	else
		reason = nil
		ulx.fancyLogAdmin( calling_ply, "#A warned #T", target_ply )
	end
	ulx.AddWarning( target_ply, calling_ply, reason )
end
local warn = ulx.command( CATEGORY_NAME, "ulx warn", ulx.warn, "!warn" )
warn:addParam{ type=ULib.cmds.PlayerArg }
warn:addParam{ type=ULib.cmds.StringArg, hint="reason", ULib.cmds.optional, ULib.cmds.takeRestOfLine }
warn:defaultAccess( ULib.ACCESS_ADMIN )
warn:help( "Warn a player." )

--[[
	ulx.AddWarning( target_ply, calling_ply, reason )
	target_ply	: PlayerObject	: Player who is being warned.
	calling_ply	: PlayerObject	: Admin or player who did the warning.
	reason		: String		: Reason player is being warned.
	
	This helper function is what adds the warning to the player's table and calls the save helper function.
	
]]
function ulx.AddWarning( target_ply, calling_ply, reason )

	if target_ply.warntable == nil then
		target_ply.warntable = {}
	end
	
	if target_ply.warntable["wcount"] == nil then
		target_ply.warntable["wcount"] = 0
	end
	
	if target_ply.warntable["warnings"] == nil then
		target_ply.warntable["warnings"] = {}
	end
	
	table.insert(target_ply.warntable["warnings"], {os.date(), calling_ply:Nick(), reason})
	
	target_ply.warntable["wcount"] = target_ply.warntable["wcount"] + 1
	ULib.tsayColor(target_ply, Color(0,0,0,255), "AWarn: " , Color(255,255,255,255), "You were warned by ", Color(0,0,0,255), "(", Color(0,255,0,255), calling_ply:Nick(), Color(0,0,0,255), ")", Color(255,255,255,255), " for: ", Color(255,0,0,255), reason)
	
	
	
	if target_ply.warntable["wcount"] >= GetConVarNumber( "ulx_warnkick_num" ) then
		if GetConVarNumber( "ulx_warnkick_ban" ) == 0 then
			target_ply.warntable["wcount"] = target_ply.warntable["wcount"] - 1
			ulx.WarningSave( target_ply )
			ULib.kick( target_ply, "Warning threshold exceeded" )
		else
			local btime = tostring( GetConVarNumber( "ulx_warnkick_bantime" ) )
			target_ply.warntable["wcount"] = target_ply.warntable["wcount"] - 1
			ulx.WarningSave( target_ply )
			ULib.kickban( target_ply, GetConVarNumber( "ulx_warnkick_bantime" ), "Warning threshold exceededm Banned for (" .. btime .. ") minutes.", calling_ply )
		end
	else
		ulx.WarningSave( target_ply )
	end
	

end

--[[
	ulx.DecayWarnings()
	
	This function runs on a timer and removes 1 active warning from a players warning count. The player needs to be playing on the server
	when this is called to have a warning removed.
]]
function ulx.DecayWarnings()
	print("Decay timer running")

	for _, pl in pairs ( player.GetAll() ) do
	
		if pl.warntable == nil then continue end
		if pl.warntable["wcount"] == nil then continue end
		if pl.warntable["wcount"] <= 0 then continue end
		
		pl.warntable["wcount"] = pl.warntable["wcount"] - 1
		ulx.WarningSave( pl )
		
		ULib.tsayColor(pl, Color(0,0,0,255), "AWarn: " , Color(255,255,255,255), "Your total warning count has been reduced by ", Color(255,0,0,255), "1")
	
	end
	
	timer.Create( "ULX_DecayTimer", GetConVarNumber( "ulx_warnkick_decayrate" ) * 60, 1, ulx.DecayWarnings )
end
timer.Create( "ULX_DecayTimer", 1, 1, ulx.DecayWarnings )

--[[
	ulx.WarningSave( pl )
	pl	: PlayerObject	: Player whos warnings are being saved
	
	This helper function saves the player's warnings to a text file for future use.
]]
function ulx.WarningSave( pl )

	local tbl = pl.warntable
	local SID = pl:SteamID64()
	
	toencode = util.TableToJSON(tbl)

	file.Write("ulx/Warnings/"..SID..".txt", toencode)

end

--[[
	ulx.WarningsLoad( pl )
	pl	: PlayerObject	: Player whos warnings are being loaded
	
	This helper function loads a player's saved warnings from their file to their player object.
]]
function ulx.WarningsLoad( pl )

	local SID = pl:SteamID64()
	if file.Exists( "ulx/Warnings/" .. SID .. ".txt", "DATA" ) then
		local todecode = file.Read( "ulx/Warnings/" .. SID .. ".txt", "DATA" )
		
		local tbl = util.JSONToTable( todecode )
		pl.warntable = tbl
	
	end

end
hook.Add( "PlayerAuthed", "WarningsLoad", ulx.WarningsLoad )

--[[
	ulx.seewarns( calling_ply, target_ply )
	calling_ply	: PlayerObject	: Admin or player who runs the command.
	target_ply	: PlayerObject	: Target player whos warnings are being displayed.
	
	This function allows an admin or whoever is granted access to see the history of warnings on a target player.
]]
function ulx.seewarns( calling_ply, target_ply )
	
	if not IsValid(calling_ply) then return end
	if not IsValid(target_ply) then return end
	
	if target_ply.warntable == nil then
		target_ply.warntable = {}
	end
	
	if target_ply.warntable["warnings"] == nil then
		ULib.console( calling_ply, "Showing warning history for player: " .. target_ply:Nick() )
		ULib.console( calling_ply, "this player does not currently have any warnings." )
	else
		ULib.console( calling_ply, "Showing warning history for player: " .. target_ply:Nick() )
		ULib.console( calling_ply, "Date                     Admin                              Reason" )
		ULib.console( calling_ply, "-------------------------------------------------------------------------------------------" )
		for k, v in pairs( target_ply.warntable[ "warnings" ] ) do
			local date = v[1]
			local admin = v[2]
			local reason = v[3]
			line = date .. string.rep(" ", 25 - date:len()) .. admin .. string.rep(" ", 35 - admin:len()) .. reason
			ULib.console( calling_ply, line )
		end
	end	
end
local seewarns = ulx.command( CATEGORY_NAME, "ulx seewarns", ulx.seewarns )
seewarns:addParam{ type=ULib.cmds.PlayerArg }
seewarns:defaultAccess( ULib.ACCESS_ADMIN )
seewarns:help( "Lists all warnings for a player to console." )

--[[
	ulx.RemoveWarning( calling_ply, target_ply, warning_count )
	calling_ply		: PlayerObject	: Admin or player who runs the command.
	target_ply		: PlayerObject	: Target player whos warnings are being displayed.
	warning_count	: Integer		: Amount of active warnings to remove from the player.
	
	This function will allow an admin to remove active warnings from a target player.
]]
function ulx.RemoveWarning( calling_ply, target_ply, warning_count )
	
	if not IsValid(calling_ply) then return end
	if not IsValid(target_ply) then return end
	
	if target_ply.warntable == nil then
		target_ply.warntable = {}
	end
	
	if target_ply.warntable["wcount"] == nil then
		ULib.console( calling_ply, "Player " .. target_ply:Nick() .. " does not currently have any active warnings.")
		return
	end
	
	if target_ply.warntable["wcount"] == 0 then
		ULib.console( calling_ply, "Player " .. target_ply:Nick() .. " does not currently have any active warnings.")
		return
	end
		
	local total_warnings = target_ply.warntable["wcount"]
	local to_remove = warning_count
	
	if to_remove > total_warnings then
		to_remove = total_warnings
	end
	
	target_ply.warntable["wcount"] = total_warnings - to_remove
	ulx.fancyLogAdmin( calling_ply, "#A removed active warnings from #T.", target_ply )
	ULib.console( calling_ply, "You removed (" .. to_remove .. ") warnings from " .. target_ply:Nick() .. ". Player current has (" .. target_ply.warntable["wcount"] .. ") active warnings remaining.")

end
local removewarn = ulx.command( CATEGORY_NAME, "ulx removewarning", ulx.RemoveWarning )
removewarn:addParam{ type=ULib.cmds.PlayerArg }
removewarn:addParam{ type=ULib.cmds.NumArg, hint="active warnings to remove" }
removewarn:defaultAccess( ULib.ACCESS_ADMIN )
removewarn:help( "Removes active warnings from a player." )

--[[
	ulx.RemoveWarningHistory( calling_ply, target_ply )
	calling_ply		: PlayerObject	: Admin or player who runs the command.
	target_ply		: PlayerObject	: Target player whos warnings are being removed.
	
	This function removes all warning history from a player.
]]
function ulx.RemoveWarningHistory( calling_ply, target_ply )
	if not IsValid(calling_ply) then return end
	if not IsValid(target_ply) then return end
	
	local SID = target_ply:SteamID64()
	
	if file.Exists( "ulx/Warnings/"..SID..".txt", "DATA" ) then
		file.Delete( "ulx/Warnings/"..SID..".txt" )
		target_ply.warntable = nil
		ULib.console( calling_ply, "You removed all warning records for player: " .. target_ply:Nick() .. "." )
		ulx.fancyLogAdmin( calling_ply, "#A removed all warning records for player #T.", target_ply )
	else
		ULib.console( calling_ply, "Unable to find any warning records for player: " .. target_ply:Nick() .. "." )
	end
		

end
local deletewarnings = ulx.command( CATEGORY_NAME, "ulx deletewarnings", ulx.RemoveWarningHistory )
deletewarnings:addParam{ type=ULib.cmds.PlayerArg }
deletewarnings:defaultAccess( ULib.ACCESS_SUPERADMIN )
deletewarnings:help( "Deletes all warning records from a target player." )

--[[
	ulx.ListAllWarnings( calling_ply )
	calling_ply		: PlayerObject	: Admin or player who runs the command.
	
	Shows a list of all players on the server and how many total warnings and active warnings they have.
]]
function ulx.ListAllWarnings( calling_ply )

	ULib.console( calling_ply, "Showing total warnings for all players:" )
	ULib.console( calling_ply, "Player Name                          Total Warnings         Active Warnings" )
	ULib.console( calling_ply, string.rep( "-", 75 ) )
	
	for _, pl in pairs( player.GetAll() ) do
		if pl.warntable == nil then continue end
		if pl.warntable[ "wcount" ] == nil then continue end
		local totalwarns = tostring( table.Count( pl.warntable[ "warnings" ] ) )
		local activewarns = tostring( pl.warntable[ "wcount" ] )
		ULib.console( calling_ply, pl:Nick() .. string.rep(" ", 37 - pl:Nick():len()) .. totalwarns .. string.rep(" ", 23 - totalwarns:len()) .. activewarns )
	end
	
end
local listwarnings = ulx.command( CATEGORY_NAME, "ulx listwarnings", ulx.ListAllWarnings )
listwarnings:defaultAccess( ULib.ACCESS_ADMIN )
listwarnings:help( "Returns a list of all connected players and their warning counts." )