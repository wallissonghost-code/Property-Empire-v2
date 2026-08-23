local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("MuseumExpansionRemotes")
local getState=remotes:WaitForChild("GetExpansionState")
local action=remotes:WaitForChild("ExpansionAction")

local gui=Instance.new("ScreenGui") gui.Name="MuseumExpansionUI" gui.ResetOnSpawn=false gui.Parent=player:WaitForChild("PlayerGui")
local open=Instance.new("TextButton") open.Size=UDim2.fromOffset(170,48) open.Position=UDim2.new(0,200,1,-68) open.BackgroundColor3=Color3.fromRGB(77,66,126) open.TextColor3=Color3.new(1,1,1) open.Text="🎯 MISSÕES" open.Font=Enum.Font.GothamBold open.TextSize=14 open.Parent=gui Instance.new("UICorner",open).CornerRadius=UDim.new(0,11)
local panel=Instance.new("Frame") panel.AnchorPoint=Vector2.new(.5,.5) panel.Position=UDim2.fromScale(.5,.52) panel.Size=UDim2.new(.9,0,.82,0) panel.BackgroundColor3=Color3.fromRGB(20,24,31) panel.Visible=false panel.Parent=gui Instance.new("UICorner",panel).CornerRadius=UDim.new(0,16)
local limit=Instance.new("UISizeConstraint") limit.MinSize=Vector2.new(310,420) limit.MaxSize=Vector2.new(650,720) limit.Parent=panel
local title=Instance.new("TextLabel") title.Position=UDim2.fromOffset(18,12) title.Size=UDim2.new(1,-90,0,36) title.BackgroundTransparency=1 title.Text="MISSÕES & CONQUISTAS" title.TextColor3=Color3.new(1,1,1) title.TextXAlignment=Enum.TextXAlignment.Left title.Font=Enum.Font.GothamBold title.TextSize=20 title.Parent=panel
local close=Instance.new("TextButton") close.Position=UDim2.new(1,-62,0,14) close.Size=UDim2.fromOffset(44,34) close.Text="X" close.Font=Enum.Font.GothamBold close.TextColor3=Color3.new(1,1,1) close.BackgroundColor3=Color3.fromRGB(92,52,58) close.Parent=panel Instance.new("UICorner",close).CornerRadius=UDim.new(0,9)
local list=Instance.new("ScrollingFrame") list.Position=UDim2.fromOffset(16,58) list.Size=UDim2.new(1,-32,1,-74) list.BackgroundColor3=Color3.fromRGB(27,32,40) list.BorderSizePixel=0 list.AutomaticCanvasSize=Enum.AutomaticSize.Y list.CanvasSize=UDim2.new() list.ScrollBarThickness=6 list.Parent=panel Instance.new("UICorner",list).CornerRadius=UDim.new(0,12)
local layout=Instance.new("UIListLayout") layout.Padding=UDim.new(0,8) layout.Parent=list
local pad=Instance.new("UIPadding") pad.PaddingLeft=UDim.new(0,10) pad.PaddingRight=UDim.new(0,10) pad.PaddingTop=UDim.new(0,10) pad.PaddingBottom=UDim.new(0,10) pad.Parent=list

local function clear() for _,c in ipairs(list:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end end
local function section(text)
	local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-4,0,30) l.BackgroundTransparency=1 l.Text=text l.TextColor3=Color3.fromRGB(242,201,103) l.TextXAlignment=Enum.TextXAlignment.Left l.Font=Enum.Font.GothamBold l.TextSize=15 l.Parent=list
end
local function refresh()
	local ok,state=pcall(function() return getState:InvokeServer() end)
	if not ok or type(state)~="table" or not state.Ok then return end
	clear() section("MISSÕES")
	for _,m in ipairs(state.Missions or {}) do
		local card=Instance.new("Frame") card.Size=UDim2.new(1,-4,0,84) card.BackgroundColor3=Color3.fromRGB(35,42,52) card.Parent=list Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
		local name=Instance.new("TextLabel") name.Position=UDim2.fromOffset(12,8) name.Size=UDim2.new(1,-130,0,22) name.BackgroundTransparency=1 name.Text=m.Name name.TextColor3=Color3.new(1,1,1) name.TextXAlignment=Enum.TextXAlignment.Left name.Font=Enum.Font.GothamBold name.TextSize=13 name.Parent=card
		local desc=Instance.new("TextLabel") desc.Position=UDim2.fromOffset(12,31) desc.Size=UDim2.new(1,-130,0,38) desc.BackgroundTransparency=1 desc.Text=string.format("%s  •  %d/%d  •  $%d",m.Description,math.min(m.Value,m.Goal),m.Goal,m.Reward) desc.TextWrapped=true desc.TextColor3=Color3.fromRGB(171,183,198) desc.TextXAlignment=Enum.TextXAlignment.Left desc.Font=Enum.Font.Gotham desc.TextSize=11 desc.Parent=card
		local b=Instance.new("TextButton") b.AnchorPoint=Vector2.new(1,.5) b.Position=UDim2.new(1,-10,.5,0) b.Size=UDim2.fromOffset(108,44) b.Text=m.Claimed and "COLETADO" or ((m.Value>=m.Goal) and "COLETAR" or "EM PROGRESSO") b.TextColor3=Color3.new(1,1,1) b.Font=Enum.Font.GothamBold b.TextSize=11 b.BackgroundColor3=m.Claimed and Color3.fromRGB(66,70,78) or ((m.Value>=m.Goal) and Color3.fromRGB(55,111,78) or Color3.fromRGB(57,72,91)) b.Parent=card Instance.new("UICorner",b).CornerRadius=UDim.new(0,9)
		if not m.Claimed and m.Value>=m.Goal then b.Activated:Connect(function() action:InvokeServer({Action="ClaimMission",Id=m.Id}) refresh() end) end
	end
	section("CONQUISTAS")
	for _,a in ipairs(state.Achievements or {}) do
		local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-4,0,42) l.BackgroundColor3=Color3.fromRGB(34,39,48) l.Text=(a.Unlocked and "🏆 " or "🔒 ")..a.Name l.TextColor3=a.Unlocked and Color3.fromRGB(246,210,111) or Color3.fromRGB(153,160,170) l.Font=Enum.Font.GothamSemibold l.TextSize=12 l.Parent=list Instance.new("UICorner",l).CornerRadius=UDim.new(0,9)
	end
end
open.Activated:Connect(function() panel.Visible=true refresh() end)
close.Activated:Connect(function() panel.Visible=false end)
print("[Museum Empire] Expansion UI ready")
