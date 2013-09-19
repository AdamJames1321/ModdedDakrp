--[[
	ULX Custom Chat Colors
	Really messy, but fuck it.
	Author: Adult
]]--

-- colors[ steamid ] = color
local colors = {}
local fname = "ulx_chatcolor.txt"

-- Only called on the server.
local function saveColors()
	local kv = util.TableToKeyValues( colors )
	file.Write( fname, kv )
end

-- Sends the clients the color table.
local function resendColors()
	net.Start( "ulx_chatcolor" )
		net.WriteTable( colors )
	net.Broadcast()
end

-- I personally think it's better to keep the colors saved to the server.
if SERVER then
	-- Make sure you make the file
	if not file.Exists( fname, "DATA" ) then
		print( "Creating " .. fname .. "...")
		saveColors()
	end

	local f = file.Read( fname, "DATA" )
	colors = util.KeyValuesToTable( f )

	-- Need this for later.
	util.AddNetworkString( "ulx_chatcolor" )
end


-- Client only stuff.
if CLIENT then
	-- Based on GM:OnPlayerChat
	local function OnPlayerChat( ply, text, teamonly, isdead )
		local tab = {}

		-- Are you dead?
		if isdead then
			table.insert( tab, Color( 255, 30, 40 ) )
			table.insert( tab, "*DEAD*")
		end

		-- Team chat
		if teamonly then
			table.insert( tab, Color( 30, 160, 40 ) )
			table.insert( tab, "( TEAM )" )
		end

		-- Name with color
		if IsValid( ply ) then
			table.insert( tab, team.GetColor( ply:Team() ) )
			table.insert( tab, ply:Name() )
		else 
			table.insert( tab, "Console")
		end

		-- The colon after the name
		table.insert( tab, Color( 255, 255, 255 ) )
		table.insert( tab, ": " )

		-- Custom chat color (finally!)
		local col = colors[ ply:SteamID() ]

		if col ~= nil then
			table.insert( tab, col )
		end
		
		-- Almost forgot to add the text!
		table.insert( tab, text )
		
		-- Finally add it.
		chat.AddText( unpack( tab ) )

		return true 
	end

	hook.Add( "OnPlayerChat", "ShowTeams", OnPlayerChat )

	-- Get the colors pls.
	net.Receive( "ulx_chatcolor", function()
		colors = net.ReadTable()
	end)
end 

-- -------------------------------
-- Finally, ulx stuff.

-- ulx chatcolor <r> <g> <b>
-- Sets the caller's color.
function ulx.chatcolor( caller, r, g, b )
	local r = math.Clamp( r, 0, 255 )
	local g = math.Clamp( g, 0, 255 )
	local b = math.Clamp( b, 0, 255 )

	colors[ caller:SteamID() ] = Color( r, g, b )

	ulx.fancyLogAdmin( caller, false, "#A set their chat color to [#i,#i,#i].", r, g, b )

	-- Send it to the client
	if SERVER then 
		resendColors()
		saveColors()
	end
end

local chatcolor = ulx.command( "Chat", "ulx chatcolor", ulx.chatcolor, "!chatcolor" )
chatcolor:addParam{ type=ULib.cmds.NumArg, hint="Red value", ULib.cmds.optional }
chatcolor:addParam{ type=ULib.cmds.NumArg, hint="Green value", ULib.cmds.optional }
chatcolor:addParam{ type=ULib.cmds.NumArg, hint="Blue value", ULib.cmds.optional }
chatcolor:defaultAccess( ULib.ACCESS_ALL )
chatcolor:help( "Sets your custom chat color." )

-- ulx removecolor <ply>
-- Removes target's color.
function ulx.removecolor( caller, target )
	local sid = target:SteamID()
	colors[sid] = nil 

	ulx.fancyLogAdmin( caller, false, "#A removed #T's chat color.", target )

	if SERVER then 
		resendColors()
		saveColors()
	end
end

local removecolor = ulx.command( "Chat", "ulx removecolor", ulx.removecolor, "!removecolor" )
removecolor:addParam{ type=ULib.cmds.PlayerArg, hint="Target", ULib.cmds.optional, default="^" }
removecolor:defaultAccess( ULib.ACCESS_ADMIN )
removecolor:help( "Removes target's custom color." )


-- ulx setcolor <ply> <r> <g> <b>
-- Sets target's color
function ulx.setcolor( caller, target, r, g, b )
	local r = math.Clamp( r, 0, 255 )
	local g = math.Clamp( g, 0, 255 )
	local b = math.Clamp( b, 0, 255 )

	colors[ target:SteamID() ] = Color( r, g, b )

	ulx.fancyLogAdmin( caller, false, "#A set #T's chat color to [#i,#i,#i].", target, r, g, b )

	-- Send it to the client
	if SERVER then 
		resendColors()
		saveColors()
	end
end

local setcolor = ulx.command( "Chat", "ulx setcolor", ulx.setcolor, "!setcolor" )
setcolor:addParam{ type=ULib.cmds.PlayerArg, hint="Target" }
setcolor:addParam{ type=ULib.cmds.NumArg, hint="Red value", ULib.cmds.optional }
setcolor:addParam{ type=ULib.cmds.NumArg, hint="Green value", ULib.cmds.optional }
setcolor:addParam{ type=ULib.cmds.NumArg, hint="Blue value", ULib.cmds.optional }
setcolor:defaultAccess( ULib.ACCESS_ADMIN )
setcolor:help( "Sets target's custom chat color." )

