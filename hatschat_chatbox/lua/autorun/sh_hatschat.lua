--[[
/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
**********lua/autorun/sh_hatschat.lua**********
***************HatsChat Chat Box***************
/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
Yes, I'm really that imaginative when it comes to names.

HatsChat Chat Box by Nathan Healy is licensed under a Creative Commons Attribution 3.0 Unported License.
See http://creativecommons.org/licenses/by/3.0 for more information

Created by my_hat_stinks
Current revision date 4 August 2012

Related files:
lua/cl_hatschat.lua
--]]

if SERVER then
	AddCSLuaFile( "cl_hatschat.lua" )
	AddCSLuaFile( "sh_hatschat.lua" )
elseif CLIENT then
	include( "cl_hatschat.lua" )
end

/*Test strings, copy to chat
Emote Test: :)???:rolleyes::cool:>:(:(:P>:D:D:O;):bday::coin:<3:star::tux::gmod:
Colour Test: [red]Red[Green]Green[BLUE]Blue[YeLlOw]Yellow
*/

//Emoticons! Yay! Order written is priority (Eg, ">:(" is over ":(" so we don't get ">*sadface*")
HatsChat_Emoticons = { //Remember the {}, it's tables in the table!
// {"String to find", "String path (vmt/png file)" , Case Sensitive(Bool), png (Bool), width (Def 15, experimental)},
// {":)", "gui/silkicons/emoticon_smile", false, true, 15}, //Full example
{":)", "icon16/emoticon_smile"}, //Minimum example (Same as above)
{":tux:", "icon16/tux", false},
{"???", "gui/hatschat/emotes/confused", false},
{":rolleyes:", "gui/hatschat/emotes/rolleyes", false},
{":cool:", "gui/hatschat/emotes/cool", false},
{">:(", "gui/hatschat/emotes/mad", false},
{":(", "icon16/emoticon_unhappy", false},
{":p", "icon16/emoticon_tongue", false}, 
{">:D", "icon16/emoticon_evilgrin", false},
{":D", "icon16/emoticon_grin", false},
{":o", "icon16/emoticon_surprised", false},
{";)", "icon16/emoticon_wink", false},
{":bday:", "icon16/cake", false},
{":coin:", "icon16/coins", false},
{"<3", "icon16/heart", false},
{":star:", "icon16/star", false},
{":gmod:", "games/16/garrysmod", false}
}
//Note: The table in the client file is derived from this, but uses a different format.
//See the "GetEmoticons" function client-side to modify how the emoticons are implemented.
//Use this global table if you want to reference the emoticons from elsewhere

for i=1,#HatsChat_Emoticons do
	
	if HatsChat_Emoticons[i][4]==nil then //No png override, so check if it's png
		//If there's no png, assume it's vmt
		HatsChat_Emoticons[i][4] = file.Exists( "materials/"..HatsChat_Emoticons[i][2]..".png", "GAME" )
	end
	
	if SERVER then
		//Adding all files, for if the client doesn't have them
		if HatsChat_Emoticons[i][4] then
			resource.AddFile("materials/"..HatsChat_Emoticons[i][2]..".png") //Png is prioritised
		else
			resource.AddFile("materials/"..HatsChat_Emoticons[i][2]..".vmt") //Vmt is failsafe
		end
	else
		if !HatsChat_Emoticons[i][3] then HatsChat_Emoticons[i][1] = string.lower( HatsChat_Emoticons[i][1] ) end //Lower-case for any non-case sensitive (It's simpler later)
		//if !HatsChat_Emoticons[i][5] then HatsChat_Emoticons[i][5] = 15 end //Set width if it's blank
	end
end

//Line icons
HatsChat_LineIcons = { //Type is case sensitive!
// Type = {"Icon (png/vmt)", png (bool)},
SuperAdmin = {"icon16/shield_add", true}, //Full example
Admin = {"icon16/star"}, //Minimum example
Player = {"icon16/comment"},
Global = {"icon16/world"},  //Other messages, from the server
Console = {"icon16/world"}, //Chat messages from Console
Other = {"icon16/comments"}, //General Other messages
Join = {"icon16/group_add"}, //Player joined
Leave = {"icon16/group_delete"}, //Player left
Moderator = {"icon16/emoticon_smile"},
//The following icons aren't included in the client file, or may not work correctly,
//as they may differ between gamemodes and servers
Spectator = {"icon16/eye"},
Donator = {"icon16/coins"}
}


for k,v in pairs(HatsChat_LineIcons) do
	if v[2]==nil then //No png override, so check if it's png
		//If there's no png, assume it's vmt
		v[2] = file.Exists( "materials/"..v[1]..".png", "GAME" )
	end
	
	if SERVER then
		//Adding all files, for if the client doesn't have them
		if v[2] then
			resource.AddFile("materials/"..v[1]..".png") //Png is prioritised
		else
			resource.AddFile("materials/"..v[1]..".vmt") //Vmt is failsafe
		end
	else
		v[1] = Material( v[1] .. (v[2] and ".png" or ".vmt" ) )
	end
end

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