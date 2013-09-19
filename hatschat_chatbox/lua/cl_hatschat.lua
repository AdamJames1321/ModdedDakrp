--[[
/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
**************lua/cl_hatschat.lua**************
***************HatsChat Chat Box***************
/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
Yes, I'm really that imaginative when it comes to names.

HatsChat Chat Box by Nathan Healy is licensed under a Creative Commons Attribution 3.0 Unported License.
See http:--creativecommons.org/licenses/by/3.0 for more information

Created by my_hat_stinks
Current revision date 4 August 2012

Related files:
lua/autorun/sh_hatschat.lua
--]]

--[[ Version 4.1 ]]--   (I think :p)

if SERVER then 
	AddCSLuaFile("cl_hatschat.lua")
	return
end

surface.CreateFont ( "small", {
        size = 10,
        weight = 390,
        antialias = true,
        shadow = false,
        font = "coolvetica"})
surface.CreateFont ( "small", {
        size = 10,
        weight = 390,
        antialias = true,
        shadow = false,
        font = "coolvetica"})
--Although these variables are declared here, changes may require modifications further into the code
local maxhist = 3000 --Maximum history
local maxshow = 15 --Maximum messages to show
local time = 15 --Time to linger

surface.SetFont("ChatFont")
--Text Height
local _,__h = surface.GetTextSize("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrdtuvwxyz")
local tHeight = math.max(15, __h)

local showing = 1 --Newest message shown
local history = {} --All the messages
local Default = "" --The input text

local barscroll = 225 --Scrollbar Scroll
local barsize = 220 --Scrollbar Size

local maxlen = math.floor( ScrW()/3 ) --Maximum line length

--Highlighting variables became a little unorganised, I may fix this some time
--Selection Table
local sel = {Select = false, Start = 1, End = 1, Chosen = false,
	Char = {Start = 1, B = 1, End = 1} } --I'll admit, character-by-character highlighting was an afterthought. Turned out pretty well, though
local HStart = 0 --Which line did we start highlighting from?

local cur = {At = 0, Show = true, Time = CurTime(), Pos = 0} --Chat Cursor Table, Time and Show control blinking, At and Pos are positioning
local InputSel = {Select = false, Start = nil} --Input selection table, makes use of cursor position
local InputLen = 0 --Length of the input box

local TeamChat = false --Inputting to team chat?

--Uses a derma input box
local PasteFrame
local PasteBox

--Line icons, default on. Text "glow", default off
local ShowLineIcons, ShowLineGlow
timer.Simple(2, function() --Seems to error without a delay
	--Set false to disable, set true to force on, leave as is to default on, change the 1 to 0 to default off

ShowLineIcons = CreateClientConVar("HatsChat_LineIcons", (LocalPlayer():GetNWInt("LineIcons") or 1),true,true )
ShowLineGlow = CreateClientConVar("HatsChat_LineGlow", (LocalPlayer():GetNWInt("LineGlow") or 1),true,true )

	local function ChangeCallback( cvar, prev, new )
		LocalPlayer():SetPData( tostring(GetConVar(cvar)) , new)
	end
	cvars.AddChangeCallback( "HatsChat_LineIcons", ChangeCallback)
	cvars.AddChangeCallback( "HatsChat_LineGlow", ChangeCallback)
end)

local Enabled = CreateClientConVar("hatschat_enable", 1, true, true):GetInt() --For the toggle command
cvars.AddChangeCallback("hatschat_enable", function(cvar, oldvalue, newvalue)
	CloseChat()
	Enabled = newvalue
	LocalPlayer():ConCommand("HatsChat_Toggle")
end)

--Screen sizes
local x = 75
local y = ScrH()-200

local ChatColours = { --Simpler than the emoticons table
-- {"String to replace", Colour to use},
{"[Red]", Color(255,0,0)},
{"[Green]", Color(0,255,0)},
{"[Lime]", Color(127,255,0)},
{"[Blue]", Color(0,0,255)},
{"[Yellow]", Color(255,255,0)},
{"[Orange]", Color(255,106,0)},
{"[Pink]", Color(255,0,170)},
{"[White]", Color(255,255,255)},
{"[Black]", Color(0,0,0)}
}
for i=1,#ChatColours do ChatColours[i][1] = string.lower(ChatColours[i][1]) end --Lower case, it's simpler later

--[[
****Adding messages to chat
--]]
local emoticons = {}
local EmoticonsReady = false
--This just finds the emoticon table and formats it for this file. There shouldn't be a need to edit it
local function GetEmoticons() 
	--Entries to the emoticons table in this format:
	-- {"String to find", "String path (vmt file)" , Case Sensitive(Bool), width (Def 15)},
	if HatsChat_Emoticons then
		emoticons = table.Copy(HatsChat_Emoticons)
		EmoticonsReady = true
		chat.AddText(Color(100,250,150), "Chat emoticons set up!")
		timer.Destroy("HatsChat_FindEmoticons")
		
		for i = 1,#emoticons do
			if (not emoticons[i][5]) or (emoticons[i][5] == 15) then emoticons[i][5] = tHeight end --Scale anything that's default size
		end
	end
end
timer.Create("HatsChat_FindEmoticons", 0, 0, GetEmoticons)

--Find all the colours and emotes in a message
local function CheckEmote( args )
	--Colours
	for i = 1,#ChatColours do
		local col = ChatColours[i]
		local place, pend = 0,0
		while (place != nil) do
			for k,v in pairs(args) do
				if (type(v) == "string") then
					place, pend = string.find(string.lower(v), col[1],1,true)
					
					if place != nil then
						args[k] = string.sub(v,1,place-1)
						table.insert(args, k+1, col[2])
						table.insert(args, k+2, string.sub(v,pend+1,string.len(v)))
					end
				end
			end
		end
	end
	
	--Emotes
	if !EmoticonsReady then return args, false end
	local emoticon = false
	for i=1,#emoticons do
		local emote = emoticons[i]
		local pstart, pend = 0,0
		while (pstart != nil) do
			for k,v in pairs(args) do
				if (type(v) == "string") then
					if emote[3] then
						pstart, pend = string.find(v, emote[1],1,true)
					else
						local str = string.lower(v)
						pstart, pend = string.find(str, emote[1],1,true)
					end
					if pstart != nil then
						emoticon = true
						args[k] = string.sub(v,1,pstart-1)
						
						if emote[4] then
							table.insert(args, k+1, {"emote", Material(emote[2]..".png"), string.sub(v,pstart,pend), emote[5]})
						else 
							table.insert(args, k+1, {"emote", Material(emote[2]..".vmt"), string.sub(v,pstart,pend), emote[5]})
						end
						
						table.insert(args, k+2, string.sub(v,pend+1,string.len(v)))
					end
				end
			end
		end
	end
	return args, emoticon
end

--Formatting, text wrapping, adding to history, and modifying values
--All methods of adding messages go through this function - Be careful with it!
local function AddMsg( ... ) 
	local args = { ... }
	local msgargs = {}
	local fullmsg = ""
	local NewArgs = {}
	
	local LineIcon, LineGlow
	
	--Text wrapping will probably be the only thing without an icon
	--Line icons default off
	if args[1] and type(args[1]) == "table" then
		if args[1][1] == "LineIcon" then
			LineIcon = tostring(args[1][2])
			
			table.remove( args, 1 )
		end
	end
	--LineGlow should be the second argument, if there's an icon
	--Otherwise, it should be the first
	if args[1] and type(args[1]) == "table" then
		if args[1][1] == "LineGlow" then
			LineGlow = args[1][2]
			
			table.remove( args, 1 )
		end
	end
	
	local args, emote = CheckEmote( args )
	
	local NeedNewLine = false
	
	local LineLength = 0
	
	--Text Wraping - This will be very messy
	--*******************
	local strnum = 0 --string num, for checking if it's the first string
	local elength = 0 --Make sure emote's lengths count!
	surface.SetFont("ChatFont")
	for k,v in ipairs(args) do --ipairs, we need order!
		if (type(v)=="string") then --We have a string! Let's test it!
			strnum = strnum+1
			if (surface.GetTextSize( fullmsg..v )+elength > maxlen) then --Is it too long?
				NeedNewLine = true --Mark us as needing a new line!
				
				--Gonna have to keep colour consistancy between lines
				--_______
				local ocol = Color(125,175,255) --Fallback
				for i=1,k do --k is where we are now, no point checking after it
					if ( ( type(args[i]) == "table") and (args[i].r and args[i].g and args[i].b)) then
						ocol=args[i] --It's a colour, set our current colour to it!
					end
				end
				
				NewArgs = { ocol } --New Arguments table
				
				
				--Split where neccessary for maximum sensible line-usage
				--_______
				local fullstr = ""
				local words = string.Explode(" ", v)
				local newstring = ""
				
				local ToNew = false --Insert string to the new table?
				
				for i = 1,#words do
					local word = words[i]
					if ToNew then --We've already got the first bit done, the rest goes to the new table
						newstring = newstring.." "..word
					else
						if (surface.GetTextSize( fullmsg..fullstr.." "..word )+elength > maxlen) then --Is it too long?
							ToNew = true
							if (i == 1) then --We're the only word! Some silly coder sent one big word!
								if (strnum == 1) then --We're also the first string!
									--Oh no! Character wrapping!
									---------
									local fullword = ""
									local newword = ""
									
									local foundword = false
									for num, char in ipairs( string.ToTable( word ) ) do --ipairs, we need order!
										if foundword then
											newword = newword..char
										else
										if (surface.GetTextSize( fullmsg..fullstr..fullword..char )+elength > maxlen) then --Is it too long (again)?
											foundword = true
											fullstr = fullstr..fullword --Should be same as fullword, but just in case
											newword = char
										else
											fullword = fullword..char
										end
										end
									end
									newstring = newword
									---------
								else --We're not the only string, so just word-wrap as a normal chatbox
									newstring = word
								end
							else --We're not the only word, so just word-wrap as a normal chatbox
								newstring = word
							end
						else --It's not too long!
							if (i == 1) then --No extra space, it's the first word
								fullstr = word
							else
								fullstr = fullstr.." "..word
							end
						end
					end
				end
				fullmsg = fullmsg..fullstr
				table.insert(msgargs, fullstr) --Put it in at the end
				table.insert(NewArgs, newstring)
				
				
				
				--Re-gather all arguments that appear after this one
				--_______
				for i= k,#args do
					if (i>k) then
						table.insert(NewArgs, args[i] )
					end
				end
				break --And we're done!
			else
				fullmsg = fullmsg..v
			end
		end
		
		if (type(v) == "table") and (v[1] == "emote") then --It's an emoticon!
			elength = elength+v[4] --Add our emote's length
			strnum = strnum+1 --Not a string, but still counts!
			
			if (surface.GetTextSize( fullmsg )+elength > maxlen) then --Are we too long?
				--Simplified version of the above
				NeedNewLine = true --Set New Line
				local ocol = Color(125,175,255) --Backup Colour
				for i=1,k do
					if ( ( type(args[i]) == "table") and (args[i].r and args[i].g and args[i].b)) then --Find a colour
						ocol=args[i]
					end
				end
				
				NewArgs = { ocol, v } --New arguments, the colour and emoticon
				
				for i= k,#args do --Find anything that appears after this
					if (i>k) then
						table.insert(NewArgs, args[i] )
					end
				end
				break --And we're done!
			end
		end
		
		table.insert(msgargs, v)
	end
	--We'll send the new line at the end of the function, if needed
	--*******************
	
	
	surface.SetFont("ChatFont")
	for _,v in pairs( msgargs ) do
		if (type(v) == "string") then
			LineLength = LineLength + surface.GetTextSize( v )
		elseif (type(v) == "table") and (v[1] == "emote") then
			LineLength = LineLength + v[4]
		end
	end
	
	--Table of line content, add it to the history table and it'll be dealt with later
	local info = {
		time = CurTime()+time,
		fullmsg = fullmsg,
		length = LineLength,
		icon = LineIcon,
		glow = LineGlow,
		args = msgargs
	}
	table.insert(history, 1, info)
	
	if ShowChat then
		--Re-adjust scrolling if we're not viewing the newest message
		if (showing>1) then
			showing = math.min(showing+1, (#history-maxshow)+1)
		end
	end
	
	if (#history > maxhist) then
		--Too much stuff, delete the oldest entry
		while (#history > maxhist) do
			table.remove(history)
		end
	end
	
	--Consistancy, don't want the selection changing
	if (sel.Chosen) then
		sel.Start = math.min(sel.Start+1, maxhist)
		sel.End = math.min(sel.End+1, maxhist)
		HStart = math.min(HStart+1, maxhist)
	end
	
	--After everything, so we've already got the current line inserted
	--But no other messages can jump in the middle (as may be possible, though unlikely, with a 1-tick timer)
	if NeedNewLine then
		AddMsg( unpack(NewArgs) )
	end
end

--[[
****Reading messages
--]]
--Regular chat messages
hook.Add("PlayerSay", "HatsChat_PlayerSay", function(ply, msg, t, dead)
	local tab = {}
	
	--Dead
	if dead then
		table.insert(tab, Color(255,25,25) )
		table.insert(tab, "*DEAD* ")
	end
	
	--Team
	if t then
		table.insert(tab, Color(10,100,10) )
		table.insert(tab, "(Team) " )
	end
	
	--Player
	if ply and ply:IsValid() and ply:IsPlayer() then
		table.insert(tab, team.GetColor( ply:Team() ) )
		table.insert(tab, ply:Nick() )
	else --Not player
		table.insert(tab, Color(175,175,200) )
		table.insert(tab, "Console" )
	end
	
	--Message:
	table.insert(tab, Color(200,200,200)  )
	table.insert(tab, ": " ..msg)
	
	if ply then
		if ply:IsSuperAdmin() then
			AddMsg( {"LineIcon", "SuperAdmin"}, {"LineGlow", Color(255,255,255)}, unpack( tab ) )
		elseif ply:IsAdmin() then
			AddMsg( {"LineIcon", "Admin"}, {"LineGlow", Color(0,0,0)}, unpack( tab ) )
		elseif TEAM_SPECTATOR and ply:Team() == TEAM_SPECTATOR then
			AddMsg( {"LineIcon", "Spectator"}, unpack( tab ) )
		else
			AddMsg( {"LineIcon", "Player"}, unpack( tab ) )
		end
	else
		AddMsg( {"LineIcon", "Global"}, unpack( tab ) )
	end
end)

--chat.AddText messages
local OAddText = chat.AddText
function chat.AddText( ... )
	local args = { ... }
	
	local LineIcon, LineGlow
	
	--Easy way to add custom Line Icons
	if args[1] then
		if type(args[1]) == "table" and type(args[1][1])=="string" and string.lower(args[1][1]) == "lineicon" then
			--Custom line icon
			LineIcon = tostring(args[1][2])
			
			table.remove( args, 1 )
		elseif type(args[1]) == "Player" and IsValid(args[1]) then
			--Player-related icon
			--I know ttt would use this pre-beta, so this will keep the icons working adequately
			if args[1]:IsSuperAdmin() then
				LineIcon = "SuperAdmin"
				LineGlow = Color(255,255,255)
			elseif args[1]:IsAdmin() then
				LineIcon = "Admin"
				LineGlow = Color(0,0,0)
			else
				LineIcon = "Player"
			end
		end
	end
	
	for k,v in pairs( args ) do
		if (type(v) != "string") and !((type(v) == "table") and (v.r and v.g and v.b)) then --Unusual entry
			if (type(v) == "Player") then --It's a player, use their name and team colour
				local ocol = Color(125,175,255)
				for i=1,k do
					if ( ( type(args[i]) == "table") and (args[i].r and args[i].g and args[i].b)) then
						ocol=args[i]
					end
				end
				--Each arg will push the old one up
				if IsValid(v) and v:IsPlayer() then
					local newargs = args
					table.remove(newargs, k)
					table.insert(newargs, k, team.GetColor( v:Team()) )
					table.insert(newargs, k+1, v:Nick() )
					table.insert(newargs, k+2, ocol )
					
					--timer.Simple(0, function() chat.AddText( unpack(newargs) ) end)
					--return
				else
					table.remove(args, k)
					
					table.insert(args, k, Color(125,175,255) )
					table.insert(args, k+1, "Console" )
					table.insert(args, k+2, ocol )
				end
			else --There's a mistake somewhere!
				ErrorNoHalt("[HatsChat Error] Invalid entry to chat.AddText! Type: "..type(v).." Attempting to fix...\n")
				table.remove(args, k)
				table.insert(args, k, tostring(v))
			end
		end
	end
	
	if LineIcon then
		if LineGlow then
			AddMsg( {"LineIcon", LineIcon}, {"LineGlow", LineGlow}, unpack(args) ) --Message to chat, custom line icon, custom glow
		else
			AddMsg( {"LineIcon", LineIcon}, unpack(args) ) --Message to chat, custom line icon
		end
	elseif LineGlow then
		AddMsg( {"LineIcon", "Other"}, {"LineGlow", LineGlow}, unpack(args) ) --Message to chat, custom glow
	else
		AddMsg( {"LineIcon", "Other"}, unpack(args) ) --Message to chat
	end
	OAddText( unpack(args) ) --Message to console
	return true
end

--"Other" messages
hook.Add("Default", "HatsChat_Default", function(plindex, plname, text, typ)
	if typ == "joinleave" then
		if type(text) == "string" then
			if string.find(text, "left the game") then
				AddMsg( {"LineIcon", "Leave"}, Color(125,255,175), text )
			else
				AddMsg( {"LineIcon", "Join"}, Color(125,255,175), text )
			end
		else
			AddMsg( Color(125,255,175), text )
		end
	else
		AddMsg( {"LineIcon", "Global"}, Color(125,175,255), text )
	end
end)

--[[
****The Chatbox
--]]
local BorderCol = Color(25, 25, 25, 255) --Chat input area decorations (Outline etc)
local BGCol = Color(25, 25, 25, 100) --Scrollbar Background
local FGCol = Color(25, 25, 25, 200) --Foreground (Scrollbar, text background)
local HCol = Color(50,150,255) --Highlight
local DefCol = Color(125,175,255) --Default / failsaife, for bad input

--The Display function
--Be Careful with this! Any errors here will hide the chatbox!
local function DrawChat()
	if Enabled then
		--Chat background (Needs to draw under chat, so draw before chat)
		if ShowChat then
			--If you want to have some background with a material, here's where to put it
			draw.RoundedBox(10, x-18, y-(15*tHeight), maxlen+21, 15*tHeight, FGCol)
		end
		
		surface.SetFont("ChatFont")
		--Chat lines
		for k, v in pairs(history) do
			if ( ShowChat or (v.time > CurTime()) ) then
				--maxshow+showing is (message to show)+1, so use < not <=
				if ((k < maxshow+showing) and (k >= showing)) then
					local pos = ((k-showing) + 1)
					
					if v.icon and ShowLineIcons and ShowLineIcons:GetBool() and HatsChat_LineIcons then
						local icon = HatsChat_LineIcons[ v.icon ]
						if icon then
							surface.SetMaterial( icon[1] ) --Set material
							surface.SetDrawColor(255,255,255,255) --Set 100% visible and colour
							
							surface.DrawTexturedRect( x-17, y-pos*tHeight, 15, 15) --Draw it to the screen
						end
					end
					local col = DefCol --Backup colour
					
					if v.glow and ShowLineGlow and ShowLineGlow:GetBool() then --Line "Glow"
						local GlowMod = math.Clamp( ( math.sin( CurTime()*2 )+1 )/2, 0, 1) --Sine wave at 0 to 1, used as a multiplier
						for i=1,#v.args do --Find the string
							local arg = v.args[i]
							if type(arg)=="string" then --This is the first string. This gets the glow
								for n=i,0,(-1) do
									if n<1 then --No previous colour arguments. Use default as the base colour
										local r = ((DefCol.r - v.glow.r)*GlowMod) + DefCol.r --Red
										local g = ((DefCol.g - v.glow.g)*GlowMod) + DefCol.g --Green
										local b = ((DefCol.b - v.glow.b)*GlowMod) + DefCol.b --Blue
										
										col = Color(r, g, b) --We're modifying the default colour
										break
									elseif type( v.args[n] ) == "table" and v.args[n].r and v.args[n].g then
										local OldCol = v.glow.old --This is the base colour. We separate it so it can be modified simply
										if not OldCol then --We've not copied the colour yet
											v.glow.old = table.Copy(v.args[n]) OldCol = v.glow.old
										end
										
										local r = ((OldCol.r - v.glow.r)*GlowMod) + v.glow.r --Red
										local g = ((OldCol.g - v.glow.g)*GlowMod) + v.glow.g --Green
										local b = ((OldCol.b - v.glow.b)*GlowMod) + v.glow.b --Blue
										
										v.args[n] = Color(r, g, b) --Replace the colour argument
										break --End loop
									end
								end
								
								break --End loop
							end
						end
					end
					
					local len = x
					
					if sel.Chosen and (k >= sel.Start and k <= sel.End) then --Highlight Selection
						local _,h = surface.GetTextSize( v.fullmsg )
							--Commented lines are for debugging. They will show where the highlight should start and end (Red start, green end)
							--Uncomment if you're having issues and need to see more clearly what's happening
						
						if k==sel.Start then --This line is the start of the selection
							if k==sel.End then --Single-line highlight
								draw.RoundedBox(0, sel.Char.Start[2], (y-pos*tHeight)+1, (sel.Char.End[2]-sel.Char.Start[2]), h, HCol)
								
								--draw.RoundedBox(0, sel.Char.Start[2]-1, (y-pos*tHeight)+1, 2, h, Color(255,0,0))
								--draw.RoundedBox(0, sel.Char.End[2]-1, (y-pos*tHeight)+1, 2, h, Color(0,255,0))
							else --Multi-line highlight
								draw.RoundedBox(0, x, (y-pos*tHeight)+1, (sel.Char.End[2]-x), h, HCol)
								
								--draw.RoundedBox(0, sel.Char.End[2]-1, (y-pos*tHeight)+1, 2, h, Color(0,255,0))
							end
						elseif k==sel.End then --This line is the end of the selection, multi-line highlight
							draw.RoundedBox(0, sel.Char.Start[2], (y-pos*tHeight)+1, ((v.length+x)-sel.Char.Start[2]), h, HCol)
							
							--draw.RoundedBox(0, sel.Char.Start[2]-1, (y-pos*tHeight)+1, 2, h, Color(255,0,0))
						else --This line is in the middle of the selection
							draw.RoundedBox(0, x, (y-pos*tHeight)+1, v.length, h, HCol)
						end
					end
					
					for k,text in pairs( v.args ) do --The actual display of the history here
						if (type(text) == "string") then --It's a string
							draw.SimpleText(text, "ChatFont", len, y-pos*tHeight, col) --Write it to the screen
							len = len + surface.GetTextSize(text, "ChatFont") --Recalculate length for the next segment
						elseif (type(text) == "table" and text[1]=="emote") then --It's an emote
							surface.SetMaterial( text[2] ) --Set material
							surface.SetDrawColor(255,255,255,255) --Set 100% visible and colour
							
							surface.DrawTexturedRect(len, y-pos*tHeight, text[4], tHeight) --Draw it to the screen
							len = len + text[4] --Recalculate the length
						else --Otherwise, must be a colour
							col = text --Set our colour for the next segment
						end
					end
				end
			end
		end
		
		--Stuff when chatbox is open
		if ShowChat then
			--Scrollbar Calculations
			if (#history > maxshow) then --There's more entries than can be displayed at once
				local max = (#history-maxshow)+1
				if (max > 10) then --Limits with the shape, can't make it too small or it looks bad
					barsize = 22
					local percent = (showing-1)/(max-1)
					
					--We're scaling the positioning, but not the size
					barscroll = ( 198*percent )+27
				else
					barsize = 220/max
					
					barscroll = ( (showing/max)*220 )+5
				end
			else
				--We don't have enough in the history to scroll. Make the scrollbar full
				barsize = 220
				barscroll = 225
			end
			
			--Scrollbar drawing
			draw.RoundedBox(10, x-55, y-225, 24, 220, BGCol)
			draw.RoundedBox(10, x-55, y-barscroll, 24, barsize, FGCol)
			
			
			surface.SetFont("Default")
			local InputVerf = string.gsub( Default, "&", "#" ) --& says length 0, # should be aprox the right size
			InputLen = math.max( surface.GetTextSize(InputVerf), (maxlen-2) )
			--Chat Input area Decorations (Outline etc)
			draw.RoundedBox(0, x-57, y+2, InputLen+60, 24, BorderCol)
			draw.RoundedBox(0, x-55, y+4, 50, 20, Color(255, 255, 255, 255))
			
			--Chat prompt text
			if TeamChat then
				draw.SimpleText( "Team: ", "Default", x-7, y+5, BorderCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT )
			else
				draw.SimpleText( "Chat: ", "Default", x-7, y+5, BorderCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT )
			end
			
			--Input area
			draw.RoundedBox(0, x-1, y+4, InputLen+2, 20, Color(255, 255, 255, 255))
			
			--Input highlight
			if InputSel.Select then
				if (InputSel.Start == cur.At) then InputSel.Select = false end
				
				local InputVerf = string.gsub( Default, "&", "#" )
				local Start, End
				if InputSel.Start < cur.At then
					Start,End = InputSel.Start, cur.At
				else
					Start,End = cur.At, InputSel.Start
				end
				surface.SetFont("Default")
				StrStart = surface.GetTextSize( string.sub(InputVerf, 0, Start) )
				Width = surface.GetTextSize( string.sub(InputVerf, (Start==0 and 0 or Start+1), End) )
				
				draw.RoundedBox(2, x+StrStart, y+6, Width, 18, HCol)
			end
			
			--Input Text (The important bit)
			draw.SimpleText( Default , "Default", x, y+5, BorderCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT )
			
			--Cursor
			if (cur.Show) then
				draw.RoundedBox(0, x+cur.Pos, y+5, 1, 17, BorderCol)
			end
			if (CurTime() > cur.Time) then cur.Show,cur.Time=!cur.Show,CurTime()+0.35 end --Blink cursor
		end
	end
end
hook.Add("HUDPaint", "HatsChat_DrawChat", DrawChat)

--Hide Default chatbox, it just gets in the way. We override the open/close commands later
hook.Add( "HUDShouldDraw", "HatsChat_HideChat", function ( x ) if ( x == "CHudChat" ) then return not Enabled end end )

--Close the input area
function CloseChat()
	--Close chat
	if !ShowChat then return true end
	ShowChat = false
	
	gui.EnableScreenClicker( false ) --Disable mouse
	
	showing = 1
	Default = ""
	
	--Clear selection
	sel.Select = false
	sel.Chosen = false
	
	--Empty the cursor
	cur.At = 0
	cur.Show = false
	cur.Str = ""
	cur.Time = CurTime()+900
	cur.Pos = 0
	
	hook.Call("FinishChat", GAMEMODE) --Allow other scripts to interact
end

--[[
****Dealing with the input box
--]]
--These concommand.Removes don't seem to work...
concommand.Remove("messagemode")
concommand.Remove("messagemode2")

--Open the chatbox
local function OpenChat(ply, bind, pressed)
	if (ply == LocalPlayer()) and Enabled then
		
		if ShowChat then --Chatbox is open
			if (bind == "cancelselect") then CloseChat() return true end --Close chat on Esc
			if (bind ~= "toggleconsole") then return true end --Don't do anything
			
		elseif (bind == "messagemode" or bind == "messagemode2") and pressed then --messagemode, they're opening chat
			timer.Simple(0.05, function() ShowChat = true end)--Mark chat as open
			
			TeamChat = (bind == "messagemode2") --Is it team? We'll use this later
			
			gui.EnableScreenClicker( true ) --Enable mouse
			
			Default = "" --Input area is empty
			
			--Reset the cursor
			cur.At = 0 --We're at charcter 0
			cur.Show = true --Showing the cursor (For blinking)
			cur.Time = CurTime()+0.5 --Time to blink
			cur.Pos = 0 --Actual position (Based on cur.At)
			
			hook.Call("StartChat", GAMEMODE) --Allow other scripts to interact
			
			return true
		end
	end
end
hook.Add("PlayerBindPress","HatsChat_BindPress",OpenChat) --Check binds

--Dealing with adding text to the input area. It should always go through this function
local BadInput = Sound("common/wpn_denyselect.wav")
local function AddText( str ) --To the input box
	if (!str) or (type(str) ~= "string") or (#str <=0) then return false end --Not valid, ignore it
	
	cur.Show = true --Cursor shows every update
	cur.Time = CurTime()+0.3
	
	local Start,End
	if InputSel.Select then --Something is selected. We're replacing it.
		local NumStart, NumEnd
		--Cehck our selection
		if InputSel.Start < cur.At then
			NumStart,NumEnd = InputSel.Start, cur.At
		else
			NumStart,NumEnd = cur.At, InputSel.Start
		end
		--Remove our selection
		Start,End = string.sub(Default,0,math.max(NumStart,0)),string.sub(Default,NumEnd+1,#Default+1)
		
		InputSel.Select = false --Update boolean
		
		cur.At = NumStart --Update cursor position
	else --Nothing is selected
		Start, End = string.sub(Default,1,cur.At),string.sub(Default,cur.At+1,-1)
	end
	
	if cur.At == #Default then End = "" end --Fix End if we're at the end
	
	if #(Start..str..End) <=126 then --We're within limits
		Default = Start..str..End --Insert new string
		
		cur.At = math.min(cur.At + #str, #Default) --Update cursor
	else --The string is too long!
	
		if #(Start..End) < 126 then --The string we already have isn't hitting the limit
			local tab = string.ToTable(str) --Go through character by character
			for i=1,#tab do
				local char = tab[i]
				if #(Start..char..End)<=126 then --It fits
					Start = Start..char --Add it
				else --It doesn't fit
					cur.At = #Start --Update cursor
					Default = Start..End --Add the end
					break --Finish
				end
			end
		end
		surface.PlaySound(BadInput) --Play error sound
	end
	
	surface.SetFont("Default")
	local InputVerf = string.gsub( Default, "&", "#" )
	cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) ) --Update cursor position
	
	hook.Call("DefaultChanged", GAMEMODE, tostring(Default) ) --Allow other scripts to interact
end

--Control keys
local KeyMap = {KEY_A,KEY_C,KEY_X,KEY_LEFT,KEY_RIGHT,KEY_DELETE,KEY_BACKSPACE}

local Pressed = {}
local HoldKey = {false,CurTime()}

--Input box controls. It's unlikely you'll want to edit this
local function KeyPress()
	if ShowChat and Enabled then
		if input.IsKeyDown(KEY_ENTER) then
		elseif input.IsKeyDown(KEY_ESCAPE) then
			CloseChat()
		elseif input.IsKeyDown(KEY_HOME) then
			if input.IsKeyDown(KEY_LSHIFT) then
				if not InputSel.Select then
					InputSel.Start = cur.At
					sel.Select = false
					sel.Chosen = false
				end
			end InputSel.Select = input.IsKeyDown(KEY_LSHIFT)
			
			cur.At = 0
			
			surface.SetFont("Default")
			local InputVerf = string.gsub( Default, "&", "#" )
			cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
		elseif input.IsKeyDown(KEY_END) then
			if input.IsKeyDown(KEY_LSHIFT) then
				if not InputSel.Select then
					InputSel.Start = cur.At
					sel.Select = false
					sel.Chosen = false
				end
			end InputSel.Select = input.IsKeyDown(KEY_LSHIFT)
			
			cur.At = #Default
			
			surface.SetFont("Default")
			local InputVerf = string.gsub( Default, "&", "#" )
			cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
		elseif (input.IsKeyDown(KEY_A) and input.IsKeyDown(KEY_LCONTROL)) and ((!Pressed[KEY_A]) or (HoldKey[1]==KEY_A and HoldKey[2]<CurTime())) then
			InputSel.Select = true
			InputSel.Start = 0
			cur.At = #Default
			
			sel.Select = false
			sel.Chosen = false
			
			surface.SetFont("Default")
			local InputVerf = string.gsub( Default, "&", "#" )
			cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
		elseif (input.IsKeyDown(KEY_C) and input.IsKeyDown(KEY_LCONTROL)) and ((!Pressed[KEY_C]) or (HoldKey[1]==KEY_C and HoldKey[2]<CurTime())) and InputSel.Select then
			if InputSel.Start < cur.At then
				SetClipboardText( string.sub( Default, InputSel.Start+1, cur.At ) )
			elseif InputSel.Start ~= cur.At then
				SetClipboardText( string.sub( Default, cur.At+1, InputSel.Start ) )
			else
				InputSel.Select = false
			end
		elseif (input.IsKeyDown(KEY_X) and input.IsKeyDown(KEY_LCONTROL)) and ((!Pressed[KEY_X]) or (HoldKey[1]==KEY_X and HoldKey[2]<CurTime())) and InputSel.Select then
			local NumStart, NumEnd
			if InputSel.Start < cur.At then
				NumStart,NumEnd = InputSel.Start, cur.At
				SetClipboardText( string.sub( Default, InputSel.Start+1, cur.At ) )
			elseif InputSel.Start ~= cur.At then
				NumStart,NumEnd = cur.At, InputSel.Start
				SetClipboardText( string.sub( Default, cur.At+1, InputSel.Start ) )
			else
				InputSel.Select = false
			end
			Start,End = string.sub(Default,0,math.max(NumStart,0)),string.sub(Default,NumEnd+1,#Default+1)
			
			Default = Start..End
			
			InputSel.Select = false
			cur.At = NumStart
			
			hook.Call("DefaultChanged", GAMEMODE, tostring(Default) ) --Allow other scripts to interact
		elseif input.IsKeyDown(KEY_LEFT) and ((!Pressed[KEY_LEFT]) or (HoldKey[1]==KEY_LEFT and HoldKey[2]<CurTime())) then
			cur.Time = CurTime()+0.3 cur.Show = true
			HoldKey = {KEY_LEFT,CurTime()+0.2}
			
			if input.IsKeyDown(KEY_LSHIFT) then
				if not InputSel.Select then
					InputSel.Start = cur.At
					sel.Select = false
					sel.Chosen = false
				end
			end InputSel.Select = input.IsKeyDown(KEY_LSHIFT)
			
			if input.IsKeyDown(KEY_LCONTROL) then
				local num = 0
				for i=(cur.At-1),0,-1 do
					if string.sub(Default,i,i) == " " then
						num=i
						break
					end
				end
				cur.At = num
				if cur.At==0 then cur.Pos = 0 else
					surface.SetFont("Default")
					local InputVerf = string.gsub( Default, "&", "#" )
					cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
				end
			else
				cur.At = math.max(0, cur.At-1)
				if cur.At==0 then cur.Pos = 0 else
					surface.SetFont("Default")
					local InputVerf = string.gsub( Default, "&", "#" )
					cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
				end
			end
		elseif input.IsKeyDown(KEY_RIGHT) and ((!Pressed[KEY_RIGHT]) or (HoldKey[1]==KEY_RIGHT and HoldKey[2]<CurTime())) then
			cur.Time = CurTime()+0.3 cur.Show = true
			HoldKey = {KEY_RIGHT,CurTime()+0.2}
			
			if input.IsKeyDown(KEY_LSHIFT) then
				if not InputSel.Select then
					InputSel.Start = cur.At
					
					sel.Select = false
					sel.Chosen = false
				end
			end InputSel.Select = input.IsKeyDown(KEY_LSHIFT)
			
			if input.IsKeyDown(KEY_LCONTROL) then
				local num = #Default
				for i= (cur.At+1),#Default do
					if string.sub(Default,i,i) == " " then
						num=i
						break
					end
				end
				cur.At = num
				if cur.At>#Default then cur.At = #Default end
				if cur.At==0 then cur.Pos = 0 else
					surface.SetFont("Default")
					local InputVerf = string.gsub( Default, "&", "#" )
					cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
				end
			else
				cur.At = math.min(#Default, cur.At+1)
				if cur.At==0 then cur.Pos = 0 else
					surface.SetFont("Default")
					local InputVerf = string.gsub( Default, "&", "#" )
					cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
				end
			end
		elseif input.IsKeyDown(KEY_BACKSPACE) and ((!Pressed[KEY_BACKSPACE]) or (HoldKey[1]==KEY_BACKSPACE and HoldKey[2]<CurTime())) then
			HoldKey = {KEY_BACKSPACE,CurTime()+0.2}
			if InputSel.Select then
				local Start, End
				if InputSel.Start < cur.At then
					Start,End = InputSel.Start, cur.At
				else
					Start,End = cur.At, InputSel.Start
				end
				StrStart,StrEnd = string.sub(Default,0,math.max(Start,0)),string.sub(Default,End+1,#Default+1)
				Default = StrStart..StrEnd
				
				InputSel.Select = false
				
				cur.At = math.min(cur.At,Start)
				if cur.At==0 then cur.Pos = 0 else
					surface.SetFont("Default")
					local InputVerf = string.gsub( Default, "&", "#" )
					cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
				end
				
			else
				local Start, End = string.sub(Default,0,math.max(cur.At-1,0)),string.sub(Default,cur.At+1,-1)
				Default = Start..End
				
				cur.At = math.max(0, cur.At-1)
				if cur.At==0 then cur.Pos = 0 else
					surface.SetFont("Default")
					local InputVerf = string.gsub( Default, "&", "#" )
					cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
				end
			end
			
			hook.Call("DefaultChanged", GAMEMODE, tostring(Default) ) --Allow other scripts to interact
		elseif input.IsKeyDown(KEY_DELETE) and ((!Pressed[KEY_DELETE]) or (HoldKey[1]==KEY_DELETE and HoldKey[2]<CurTime())) then
			HoldKey = {KEY_DELETE,CurTime()+0.2}
			if InputSel.Select then
				local Start, End
				if InputSel.Start < cur.At then
					Start,End = InputSel.Start, cur.At
				else
					Start,End = cur.At, InputSel.Start
				end
				StrStart,StrEnd = string.sub(Default,0,math.max(Start,0)),string.sub(Default,End+1,#Default+1)
				Default = StrStart..StrEnd
				
				InputSel.Select = false
				
				cur.At = math.min(cur.At,Start)
				if cur.At==0 then cur.Pos = 0 else
					surface.SetFont("Default")
					local InputVerf = string.gsub( Default, "&", "#" )
					cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
				end
			else
				if cur.At+2 >#Default then Default=string.sub(Default,1,cur.At) else
					local Start, End = string.sub(Default,1,cur.At),string.sub(Default,cur.At+2,-1)
					Default = Start..End
				end
				
				cur.At = math.min(cur.At,#Default)
				if cur.At==0 then cur.Pos = 0 else
					surface.SetFont("Default")
					local InputVerf = string.gsub( Default, "&", "#" )
					cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
				end
			end
			
			hook.Call("DefaultChanged", GAMEMODE, tostring(Default) ) --Allow other scripts to interact
		else
			if not PasteFrame then
				PasteFrame = vgui.Create("DFrame")
				PasteFrame:SetPos( ScrW()*2, ScrH()*2 ) PasteFrame:ShowCloseButton( false )
				PasteFrame:MakePopup()
				
				PasteBox = vgui.Create("DTextEntry",PasteFrame)
				PasteBox.OnTextChanged = function(self)
					local msg = PasteBox:GetValue()
					if (msg ~= "") then AddText( msg ) end
					PasteBox:SetText("")
					
					hook.Call("DefaultChanged", GAMEMODE, tostring(Default) ) --Allow other scripts to interact
				end
				PasteBox.OnLoseFocus = function(self) PasteBox:RequestFocus() end
				PasteBox.OnEnter = function(self)
					if not Enabled then CloseChat() return end
					
					if #Default > 0 then
						if TeamChat then
							RunConsoleCommand("say_team", Default)
						else
							RunConsoleCommand("say", Default)
						end
					end
					CloseChat()
				end
				
				PasteBox:RequestFocus()
			elseif not PasteBox.OnTextChanged then ErrorNoHalt("Chat input box disappeared!") PasteFrame:Close() PasteFrame = nil end
		end
	else
		if PasteFrame then PasteFrame:Close() PasteFrame = nil end
	end
	
	for _,v in pairs( KeyMap ) do
		Pressed[v] = input.IsKeyDown(v)
	end
end
hook.Add("Think","HatsChat_KeyPress",KeyPress)

--[[
****Misc Calculations
--]]
local function PlaceInLine( line, pos )
	surface.SetFont( "ChatFont" )
	if !line or !pos then return 0 end
	
	if type(line) ~= "table" then --We've been given something invalid
		ErrorNoHalt("Bad argument #1 to PlaceInLine (table expected, got "..type(line)..")\n") return 0
	elseif line.args then line = line.args end --We've been given the full line, not the line arguments
	
	if #line==0 then return 0 end
	surface.SetFont("ChatFont")
	
	pos=pos-x
	local size = 0
	local len = 0
	for i=1,#line do
		local part = line[i]
		
		if type(part)=="table" and part[1]=="emote" then
			if len+part[4] > pos then
				return size
			else
				size=size+1
				len = len+part[4]
			end
		elseif type(part)=="string" then
			local PartStr = string.gsub( part, "&", "#" ) --To stop odd lengths
			local w = 0
			for n=1,#part do
				w = surface.GetTextSize( string.sub( PartStr, 1, n), "ChatFont" )
				if (w+len)>pos then return (size+(n-1)) end
			end
			size = size+#part
			len = len+w
		end
	end
	
	return size --Full line
end

local function PosFromPlace( line, place )
	surface.SetFont("ChatFont")
	if place<=0 then return x end
	
	if type(line) ~= "table" then --We've been given something invalid
		ErrorNoHalt("Bad argument #1 to PosFromPlace (table expected, got "..type(line)..")\n") return 0
	elseif line.args then line = line.args end --We've been given the full line, not the line arguments
	
	if #line==0 then return x end
	
	local pos = x
	local point = 0
	for i=1,#line do
		local part = line[i]
		if type(part)=="string" then
			local PartStr = string.gsub( part, "&", "#" ) --To stop odd lengths
			for n=1,#part do
				local str = string.sub( PartStr, 1, n)
				point = point+1
				
				if point>=place then
					surface.SetFont("ChatFont")
					
					local w = surface.GetTextSize(str, "ChatFont")
					return (pos+w)
				end
			end
			
			surface.SetFont( "ChatFont" )
			local w = surface.GetTextSize(part, "ChatFont")
			pos=pos+w
			
		elseif type(part)=="table" and part[1]=="emote" then
			point = point+1
			pos = pos+part[4]
			if point>=place then
				return pos
			end
		end
	end
	
	return pos --Full line
end

local M1 = false
local drag = false --Are we dragging the scroll bar?
local InputHigh = false --Highlighting the input?
local function Think()
	if !ShowChat then return end
	if not Enabled then return end
	
	--Scrollbar and Highlights
	if input.IsMouseDown( MOUSE_LEFT ) then
		local mx = gui.MouseX()
		--ScrollBar
		if drag then
			local max = (#history-maxshow)+1
			local b = y- gui.MouseY()
			
			--Inverse of the equation to caluclate where the scrollbar should go
			showing = math.Clamp( --Make sure we don't go out of range
			( ((max-1)*(b-27)) /198) +1, --Calculate where we are
			1, max) --Min and Max
		else
			if (mx > (x-55)) and (mx < (x-31)) then
				local my = gui.MouseY()
				if (my > (y-225)) and (my < (y-5)) then
					drag = true
				end
			end
		end
		
		--Highlighting Input
		if InputHigh then
			local tab = string.ToTable( Default )
			local str = ""
			local size = 0
			cur.At = 0
			
			surface.SetFont("Default")
			for i=1,#tab do
				str = str..tab[i]
				local InputVerf = string.gsub( str, "&", "#" )
				
				size = surface.GetTextSize( string.gsub( str, "&", "#" ) )
				if (size+(x-1))<mx then
					cur.At = i
					cur.Pos = size
				else break end
			end
			
			surface.SetFont("Default")
			local InputVerf = string.gsub( Default, "&", "#" )
			cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
			
			InputHigh = true
			InputSel.Select = (cur.At ~= InputSel.Start)
		elseif !M1 then --Initial click
			if (mx > (x-1)) and (mx < (x+InputLen+1)) then
				local my = gui.MouseY()
				if (my > y+4) and (my < y+24) then
					local tab = string.ToTable( Default )
					local str = ""
					local size = 0
					cur.At = 0
					
					surface.SetFont("Default")
					for i=1,#tab do
						str = str..tab[i]
						
						size = surface.GetTextSize( string.gsub( str, "&", "#" ) )
						if ( (size+(x-1)) < mx ) then
							cur.At = i
						else break end
					end
					
					surface.SetFont("Default")
					local InputVerf = string.gsub( Default, "&", "#" )
					cur.Pos = surface.GetTextSize( string.sub(InputVerf, 1, cur.At) )
					
					InputHigh = true
					InputSel.Start = cur.At
				end
			end
		end
		
		--Highlight messages
		if sel.Select then --We've not released the mouse yet, no further checks!
			local my = gui.MouseY()
			--local HNum = showing+(math.ceil( (my-(y-1-(15*tHeight)))/tHeight ) *(-1) + tHeight) --Same as HStart below
			local HNum = math.floor( (y +tHeight -my-1 +tHeight*showing)/tHeight )-1--Same as HStart below
			
			if (HNum > HStart) then --We're selecting to something older
				sel.Start = HStart
				sel.End = HNum
				
				local line = history[HNum]
				local place = PlaceInLine( line , mx)
				sel.Char.Start = {place, PosFromPlace(line, place)}
				sel.Char.End = table.Copy( sel.Char.B )
			elseif (HNum < HStart) then --We're selecting to somewthing newer
				sel.Start = HNum
				sel.End = HStart
				
				local line = history[HNum]
				local place = PlaceInLine( line , mx)
				sel.Char.Start = table.Copy( sel.Char.B )
				sel.Char.End = {place, PosFromPlace(line, place)}
			elseif (HNum == HStart) then --We're on the start point
				sel.Start = HStart
				sel.End = HStart
				
				local line = history[HNum]
				local place = PlaceInLine( line , mx)
				if mx > sel.Char.B[2] then
					sel.Char.Start = table.Copy( sel.Char.B )
					sel.Char.End = {place, PosFromPlace(line, place)}
				else
					sel.Char.Start = {place, PosFromPlace(line, place)}
					sel.Char.End = table.Copy( sel.Char.B )
				end
			end
			
			InputSel.Select = false
		elseif !M1 then --Initial click!
			if (mx > x) and (mx < (x+maxlen)) then --Are we in the chatbox X co-ordinates?
				local my = gui.MouseY()
				if (my < (y)) and (my > (y-226)) then --Are we in the chatbox Y co-ordinates?
					sel.Select = true
					sel.Chosen = true
					InputSel.Select = false
					
					HStart = math.floor( (y +tHeight-my-1 +tHeight*showing)/tHeight )-1 --Should give 1 to tHeight when showing is default 1
					if (HStart > #history) then HStart = #history end
					
					sel.Start = HStart
					sel.End = HStart
					
					local line = history[HStart]
					local place = PlaceInLine(line, mx)
					sel.Char.B = {place, PosFromPlace(line, place)}
					sel.Char.Start = table.Copy( sel.Char.B )
					sel.Char.End = table.Copy( sel.Char.B )
					
				else
					sel.Chosen = false --Deselect
				end
			else
				local my = gui.MouseY()
				if !( (mx > (x-55)) and (mx < (x-31)) and (my > (y-225)) and (my < (y-5)) ) then --Touching scrollbar won't deselect
					sel.Chosen = false --Deselect
				end
			end
		end
		
		M1 = true --For next tick
	else
		if (#history > maxshow) then showing = math.Clamp( math.Round(showing), 1, (#history-maxshow)+1 ) end
		M1 = false
		drag = false
		sel.Select = false
		InputHigh = false
	end
	
	--Copy+Paste
	if (input.IsKeyDown(KEY_C)) then --Pressing C
		if (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)) then --Copy?
			if sel.Chosen then --Highlighted?
				local tab = {} --Table
				for i= sel.Start, sel.End do --Each line
					local line = ""
					if i==sel.Start and i==sel.End and (i>=1) and (i<=#history) then --Single line
						local pos = 0
						for _,text in pairs( history[i].args ) do
							if type(text)=="string" then --String
								for n=1,#text do --Character by character
									pos = pos+1
									if pos>sel.Char.Start[1] and pos<=sel.Char.End[1] then --Check length
										line = line..string.sub(text,n,n) --Insert Character
									end
								end
							elseif type(text)=="table" and text[1]=="emote" then
								pos=pos+1
								if pos > sel.Char.Start[1] and pos<=sel.Char.End[1] then --Check length
									line = line..text[3] --Insert text
								end
							end
						end
					elseif i==sel.End and (i>=1) and (i<=#history) then --FIRST line
						local pos = 0
						for _,text in pairs( history[i].args ) do
							if type(text)=="string" then --String
								for n=1,#text do --Character by character
									pos = pos+1
									if pos>sel.Char.Start[1] then --Check length
										line = line..string.sub(text,n,-1) --Insert text
										break --Done
									end
								end
							elseif type(text)=="table" and text[1]=="emote" then
								pos=pos+1
								if pos > sel.Char.Start[1] then --Check length
									line = line..text[3] --Insert text
								end
							end
						end
					elseif i==sel.Start and (i>=1) and (i<=#history) then --LAST line
						local pos = 0
						for _,text in pairs( history[i].args ) do
							if type(text)=="string" then --String
								for n=1,#text do --Character by character
									pos = pos+1
									if pos<=sel.Char.End[1] then --Check length
										line = line..string.sub(text,n,n) --Insert Character
									end
								end
							elseif type(text)=="table" and text[1]=="emote" then
								pos=pos+1
								if pos <= sel.Char.End[1] then --Check length
									line = line..text[3] --Insert text
								end
							end
						end
					elseif (i>=1) and (i<=#history) then --Normal lines
						for _,text in pairs( history[i].args ) do
							if (type(text) == "string") then --It's a string!
								line = line..text
							elseif (type(text) == "table" and text[1]=="emote") then --It's an emote!
								line = line..text[3]
							end
						end
						
					end
					
					table.insert(tab, 1, line) --Insert line!
				end
				
				
				local str = table.concat(tab,"\n") --Transform to string!
				SetClipboardText( str ) --To Clipboard!
			end
		end
	end
end
hook.Add("Think", "HatsChat_Think", Think)

--[[
****Misc functions
--]]
--Ever wanted to Msg in color? Now you can! :D
--Args as chat.AddText
function MsgColor( ... )
	if Enabled then
		OAddText( ... )
	else --Not enabled, ignore colours, use MsgN
		local str = ""
		local args = {...}
		
		for i=1,#args do
			if type(args[i]) == "string" then
				str = str .. tostring(args[i])
			elseif type(args[i]) == "Player" then
				str = str .. args[i]:Nick()
			end
		end
		
		MsgN( tostring(str) )
	end
end
MsgCol = MsgColor

concommand.Add("HatsChat_Test", function(ply, c, a)
	if ply~=LocalPlayer() then return end
	
	local loop = (tonumber(a[1]) or maxshow) or 15 --maxshow is 15 by default anyway, but this is just in case
	if #a>=1 then table.remove(a, 1) end
	
	timer.Create("DefaultTesting",0, loop, function()
		chat.AddText( Color(math.random()*255,math.random()*255,math.random()*255), --Random colour
			a[1] and table.concat(a," ") or --Passed arguments, or
			("[Testing Chatbox] "..HatsChat_Emoticons[math.Round(math.random(1,#HatsChat_Emoticons))][1])) --Default text with random emoticon
	end)
end)

concommand.Add("HatsChat_Toggle", function(ply,c,a)
	if ply~=LocalPlayer() then return end
	
	CloseChat()
	Enabled = not Enabled
end)
	

MsgCol(Color(100,250,150), "Successfully loaded HatsChat Chatbox!")

--[[
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
--]]