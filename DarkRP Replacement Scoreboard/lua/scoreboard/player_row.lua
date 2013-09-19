
surface.CreateFont( "ScoreboardPlayerName", {
	font 		= "coolvetica",
	size 		= 20,
	weight 		= 500,
} )

local texGradient = surface.GetTextureID("gui/center_gradient")

local PANEL = {}

--[[-------------------------------------------------------
Name: Paint
---------------------------------------------------------]]
function PANEL:Paint()
	if not IsValid(self.Player) then return end

	local color = team.GetColor(self.Player:Team())

	if self.Player:Team() == TEAM_CONNECTING then
		color = Color(200, 120, 50, 255)
	end

	draw.RoundedBox(4, 0, 0, self:GetWide(), 24, color)

	surface.SetTexture(texGradient)
	surface.SetDrawColor(255, 255, 255, 50)
	surface.DrawTexturedRect(0, 0, self:GetWide(), 24)

	return true
end

--[[-------------------------------------------------------
Name: UpdatePlayerData
---------------------------------------------------------]]
function PANEL:SetPlayer(ply)
	if not IsValid(ply) then return end
	self.Player = ply
	self:UpdatePlayerData()
end

--[[-------------------------------------------------------
Name: UpdatePlayerData
---------------------------------------------------------]]
function PANEL:UpdatePlayerData()
	if not IsValid(self.Player) then return end
	local Team = LocalPlayer():Team()
	self.lblName:SetText(self.Player:Name())
	self.lblName:SizeToContents()
	self.lblJob:SetText(self.Player.DarkRPVars and self.Player.DarkRPVars.job or team.GetName(self.Player:Team()) or "")
	self.lblJob:SizeToContents()
	self.lblPing:SetText(self.Player:Ping())
	self.lblWarranted:SetImage("icon16/exclamation.png")
	if self.Player.DarkRPVars and self.Player.DarkRPVars.wanted then
		self.lblWarranted:SetVisible(true)
	else
		self.lblWarranted:SetVisible(false)
	end
end

--[[-------------------------------------------------------
Name: PerformLayout
---------------------------------------------------------]]
function PANEL:Init()
	self.Size = 24

	self.lblName = vgui.Create("DLabel", self)
	self.lblJob = vgui.Create("DLabel", self)
	self.lblPing = vgui.Create("DLabel", self)
	self.lblWarranted = vgui.Create("DImage", self)
	self.lblWarranted:SetSize(16,16)

	-- If you don't do this it'll block your clicks
	self.lblName:SetMouseInputEnabled(false)
	self.lblJob:SetMouseInputEnabled(false)
	self.lblPing:SetMouseInputEnabled(false)
	self.lblWarranted:SetMouseInputEnabled(false)
end

--[[-------------------------------------------------------
Name: PerformLayout
---------------------------------------------------------]]
function PANEL:ApplySchemeSettings()
	self.lblName:SetFont("ScoreboardPlayerName")
	self.lblJob:SetFont("ScoreboardPlayerName")
	self.lblPing:SetFont("ScoreboardPlayerName")

	self.lblName:SetFGColor(color_white)
	self.lblJob:SetFGColor(color_white)
	self.lblPing:SetFGColor(color_white)
end

--[[-------------------------------------------------------
Name: PerformLayout
---------------------------------------------------------]]
function PANEL:DoClick()

end

--[[-------------------------------------------------------
Name: PerformLayout
---------------------------------------------------------]]
function PANEL:Think()
	if not self.PlayerUpdate or self.PlayerUpdate < CurTime() then
		self.PlayerUpdate = CurTime() + 0.5
		self:UpdatePlayerData()
	end
end

--[[-------------------------------------------------------
Name: PerformLayout
---------------------------------------------------------]]
function PANEL:PerformLayout()
	self:SetSize(self:GetWide(), self.Size)
	self.lblName:SizeToContents()
	self.lblName:SetPos(24, 2)

	local COLUMN_SIZE = 50

	self.lblPing:SetPos(self:GetWide() - COLUMN_SIZE * 1, 0)
	self.lblJob:SetPos(self:GetWide() - COLUMN_SIZE * 7, 1)
	self.lblWarranted:SetPos(self:GetWide() - COLUMN_SIZE * 8.8, 5)
end

--[[-------------------------------------------------------
Name: PerformLayout
---------------------------------------------------------]]
function PANEL:HigherOrLower(row)
	if not IsValid(row.Player) or not IsValid(self.Player) then return false end

	if self.Player:Team() == TEAM_CONNECTING then return false end
	if row.Player:Team() == TEAM_CONNECTING then return true end

	if team.GetName(self.Player:Team()) == team.GetName(row.Player:Team()) then
		return team.GetName(self.Player:Team()) < team.GetName(row.Player:Team())
	end

	return team.GetName(self.Player:Team()) < team.GetName(row.Player:Team())
end

vgui.Register("RPScorePlayerRow", PANEL, "Button")
