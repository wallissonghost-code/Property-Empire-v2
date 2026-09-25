local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("AuraSelect")
local gui=Instance.new("ScreenGui"); gui.Name="AuraMenu"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
local open=Instance.new("TextButton"); open.Size=UDim2.fromOffset(62,62); open.Position=UDim2.new(0,18,0.5,-31); open.Text="AURA"; open.TextSize=13; open.Font=Enum.Font.GothamBold; open.BackgroundColor3=Color3.fromRGB(18,22,24); open.TextColor3=Color3.fromRGB(70,255,170); open.Parent=gui
Instance.new("UICorner",open).CornerRadius=UDim.new(1,0)
local panel=Instance.new("Frame"); panel.Size=UDim2.fromOffset(280,330); panel.Position=UDim2.new(0,92,0.5,-165); panel.BackgroundColor3=Color3.fromRGB(12,15,17); panel.Visible=false; panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,18)
local stroke=Instance.new("UIStroke",panel); stroke.Color=Color3.fromRGB(55,70,67); stroke.Transparency=.35
local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Size=UDim2.new(1,-30,0,54); title.Position=UDim2.fromOffset(15,5); title.Text="AURAS"; title.Font=Enum.Font.GothamBold; title.TextSize=22; title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=panel
local list=Instance.new("Frame"); list.BackgroundTransparency=1; list.Position=UDim2.fromOffset(14,62); list.Size=UDim2.new(1,-28,1,-76); list.Parent=panel
local layout=Instance.new("UIListLayout",list); layout.Padding=UDim.new(0,8)
local choices={{"NeonStorm","NEON STORM"},{"Inferno","INFERNO"},{"Void","VOID"},{"Celestial","CELESTIAL"},{"None","REMOVER AURA"}}
for _,choice in choices do
 local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,44); b.BackgroundColor3=Color3.fromRGB(24,29,31); b.Text=choice[2]; b.TextColor3=Color3.fromRGB(235,240,240); b.TextSize=14; b.Font=Enum.Font.GothamSemibold; b.Parent=list; Instance.new("UICorner",b).CornerRadius=UDim.new(0,11)
 b.Activated:Connect(function() remote:FireServer(choice[1]) end)
end
open.Activated:Connect(function() panel.Visible=not panel.Visible end)
