timer.Simple(0, function()
        FAdmin.GlobalSetting.FAdmin = false
        if CLIENT then
                usermessage.Hook("FAdmin_GlobalSetting", function() end)
        end
end)