local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("AuraSelect")
local gui=Instance.new("ScreenGui"); gui.Name="AuraMenu"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false; gui.Parent=player:WaitForChild("PlayerGui")
local open=Instance.new("TextButton"); open.Size=UDim2.fromOffset(58,58); open.Position=UDim2.new(0,18,.5,-29); open.Text="✦"; open.TextSize=27; open.Font=Enum.Font.GothamBold; open.BackgroundColor3=Color3.fromRGB(14,17,20); open.TextColor3=Color3.fromRGB(190,235,255); open.Parent=gui
Instance.new("UICorner",open).CornerRadius=UDim.new(1,0); local os=Instance.new("UIStroke",open); os.Color=Color3.fromRGB(80,130,160); os.Transparency=.25
local panel=Instance.new("Frame"); panel.Size=UDim2.fromOffset(310,380); panel.Position=UDim2.new(0,88,.5,-190); panel.BackgroundColor3=Color3.fromRGB(10,12,15); panel.Visible=false; panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,18); local stroke=Instance.new("UIStroke",panel); stroke.Color=Color3.fromRGB(62,75,90); stroke.Transparency=.35
local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Size=UDim2.new(1,-28,0,42); title.Position=UDim2.fromOffset(16,10); title.Text="COLEÇÃO DE AURAS"; title.Font=Enum.Font.GothamBold; title.TextSize=18; title.TextColor3=Color3.fromRGB(245,248,255); title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=panel
local sub=Instance.new("TextLabel"); sub.BackgroundTransparency=1; sub.Size=UDim2.new(1,-28,0,24); sub.Position=UDim2.fromOffset(16,43); sub.Text="Escolha um efeito para equipar"; sub.Font=Enum.Font.Gotham; sub.TextSize=11; sub.TextColor3=Color3.fromRGB(125,137,150); sub.TextXAlignment=Enum.TextXAlignment.Left; sub.Parent=panel
local list=Instance.new("Frame"); list.BackgroundTransparency=1; list.Position=UDim2.fromOffset(14,76); list.Size=UDim2.new(1,-28,1,-90); list.Parent=panel
local layout=Instance.new("UIListLayout",list); layout.Padding=UDim.new(0,8)
local choices={
 {"Lightning","TEMPESTADE ELÉTRICA","Raios orbitais e pulsos elétricos","⚡"},
 {"BlackHole","SINGULARIDADE","Buraco negro e disco de acreção","●"},
 {"FireRing","CÍRCULO INFERNAL","Chamas vivas girando aos seus pés","🔥"},
 {"Guardian","GUARDIÃO CELESTIAL","Asas de energia e halo luminoso","✦"},
 {"None","REMOVER AURA","Voltar ao visual padrão","×"}
}
for _,choice in choices do
 local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,51); b.BackgroundColor3=Color3.fromRGB(20,24,29); b.Text=""; b.AutoButtonColor=false; b.Parent=list; Instance.new("UICorner",b).CornerRadius=UDim.new(0,12)
 local icon=Instance.new("TextLabel"); icon.BackgroundTransparency=1; icon.Size=UDim2.fromOffset(42,51); icon.Text=choice[4]; icon.TextSize=20; icon.TextColor3=Color3.fromRGB(185,220,245); icon.Parent=b
 local name=Instance.new("TextLabel"); name.BackgroundTransparency=1; name.Position=UDim2.fromOffset(43,7); name.Size=UDim2.new(1,-50,0,18); name.Text=choice[2]; name.TextSize=12; name.Font=Enum.Font.GothamBold; name.TextColor3=Color3.fromRGB(242,245,250); name.TextXAlignment=Enum.TextXAlignment.Left; name.Parent=b
 local desc=Instance.new("TextLabel"); desc.BackgroundTransparency=1; desc.Position=UDim2.fromOffset(43,25); desc.Size=UDim2.new(1,-50,0,17); desc.Text=choice[3]; desc.TextSize=10; desc.Font=Enum.Font.Gotham; desc.TextColor3=Color3.fromRGB(125,137,150); desc.TextXAlignment=Enum.TextXAlignment.Left; desc.Parent=b
 b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=Color3.fromRGB(28,34,40)}):Play() end); b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=Color3.fromRGB(20,24,29)}):Play() end)
 b.Activated:Connect(function() remote:FireServer(choice[1]) end)
end
open.Activated:Connect(function() panel.Visible=not panel.Visible end)
