local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MuseumOperationsRemotes")
local getState = remotes:WaitForChild("GetOperationsState")
local action = remotes:WaitForChild("OperationsAction")

local gui = Instance.new("ScreenGui")
gui.Name = "MuseumOperationsUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local open = Instance.new("TextButton")
open.AnchorPoint = Vector2.new(0,1)
open.Position = UDim2.new(0,16,1,-128)
open.Size = UDim2.fromOffset(170,48)
open.BackgroundColor3 = Color3.fromRGB(47,72,92)
open.TextColor3 = Color3.new(1,1,1)
open.Font = Enum.Font.GothamBold
open.TextSize = 14
open.Text = "⚙  GESTÃO"
open.Parent = gui
Instance.new("UICorner",open).CornerRadius=UDim.new(0,11)

local panel=Instance.new("Frame")
panel.AnchorPoint=Vector2.new(.5,.5)
panel.Position=UDim2.fromScale(.5,.52)
panel.Size=UDim2.new(.9,0,.82,0)
panel.BackgroundColor3=Color3.fromRGB(20,24,31)
panel.Visible=false
panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,16)
local limit=Instance.new("UISizeConstraint") limit.MinSize=Vector2.new(310,420) limit.MaxSize=Vector2.new(620,720) limit.Parent=panel

local title=Instance.new("TextLabel") title.Position=UDim2.fromOffset(18,12) title.Size=UDim2.new(1,-90,0,32) title.BackgroundTransparency=1 title.Text="GESTÃO DO MUSEU" title.TextColor3=Color3.new(1,1,1) title.TextXAlignment=Enum.TextXAlignment.Left title.Font=Enum.Font.GothamBold title.TextSize=18 title.Parent=panel
local close=Instance.new("TextButton") close.Position=UDim2.new(1,-60,0,12) close.Size=UDim2.fromOffset(42,32) close.Text="X" close.Font=Enum.Font.GothamBold close.TextColor3=Color3.new(1,1,1) close.BackgroundColor3=Color3.fromRGB(91,54,57) close.Parent=panel Instance.new("UICorner",close).CornerRadius=UDim.new(0,8)
local status=Instance.new("TextLabel") status.Position=UDim2.fromOffset(18,48) status.Size=UDim2.new(1,-36,0,44) status.BackgroundTransparency=1 status.TextColor3=Color3.fromRGB(170,185,202) status.TextWrapped=true status.Font=Enum.Font.GothamMedium status.TextSize=12 status.Parent=panel

local list=Instance.new("ScrollingFrame") list.Position=UDim2.fromOffset(16,98) list.Size=UDim2.new(1,-32,1,-114) list.BackgroundColor3=Color3.fromRGB(26,31,39) list.BorderSizePixel=0 list.AutomaticCanvasSize=Enum.AutomaticSize.Y list.CanvasSize=UDim2.new() list.ScrollBarThickness=5 list.Parent=panel Instance.new("UICorner",list).CornerRadius=UDim.new(0,12)
local layout=Instance.new("UIListLayout") layout.Padding=UDim.new(0,8) layout.Parent=list
local pad=Instance.new("UIPadding") pad.PaddingLeft=UDim.new(0,10) pad.PaddingRight=UDim.new(0,10) pad.PaddingTop=UDim.new(0,10) pad.PaddingBottom=UDim.new(0,10) pad.Parent=list

local function money(n)
	local s=tostring(math.floor(tonumber(n) or 0)) repeat local n2,k=s:gsub("^(-?%d+)(%d%d%d)","%1.%2") s=n2 until k==0 return "$"..s
end
local function clear() for _,c in ipairs(list:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end end
local function label(text,h,bold,color) local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-4,0,h or 30) l.BackgroundTransparency=1 l.Text=text l.TextWrapped=true l.TextXAlignment=Enum.TextXAlignment.Left l.TextColor3=color or Color3.fromRGB(230,234,240) l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham l.TextSize=bold and 14 or 12 l.Parent=list return l end
local function button(text,callback,color) local b=Instance.new("TextButton") b.Size=UDim2.new(1,-4,0,42) b.Text=text b.TextWrapped=true b.Font=Enum.Font.GothamSemibold b.TextSize=12 b.TextColor3=Color3.new(1,1,1) b.BackgroundColor3=color or Color3.fromRGB(49,73,96) b.Parent=list Instance.new("UICorner",b).CornerRadius=UDim.new(0,9) b.Activated:Connect(callback) return b end

local refreshing=false
local refresh
local function doAction(payload)
	if refreshing then return end refreshing=true
	local ok,res=pcall(function() return action:InvokeServer(payload) end)
	refreshing=false
	if ok and type(res)=="table" then status.Text=res.Message or res.Error or "Concluído" end
	refresh()
end

refresh=function()
	local ok,state=pcall(function() return getState:InvokeServer() end)
	if not ok or type(state)~="table" or not state.Ok then status.Text="Gestão indisponível" return end
	clear()
	status.Text=string.format("Caixa %s  •  Avaliação %d/100  •  Limpeza %d  •  Segurança %d",money(state.Cash),state.Rating,state.Cleanliness,state.Security)
	label("FUNCIONÁRIOS",30,true,Color3.fromRGB(115,214,181))
	local order={"Reception","Security","Cleaning","Shop","Guide"}
	for _,id in ipairs(order) do
		local r=state.Staff[id]
		if r then
			label(string.format("%s · nível %d/%d",r.Name,r.Level,r.MaxLevel),28,true)
			if r.NextCost then button("CONTRATAR / EVOLUIR · "..money(r.NextCost),function() doAction({Action="Hire",Role=id}) end) else label("Equipe no nível máximo",24,false,Color3.fromRGB(241,194,92)) end
		end
	end
	label("EVENTOS",34,true,Color3.fromRGB(241,194,92))
	if state.ActiveEvent then
		local left=math.max(0,(state.EventEndsAt or 0)-os.time())
		local e=state.Events[state.ActiveEvent]
		label((e and e.Name or state.ActiveEvent).." ATIVO · "..left.."s",34,true,Color3.fromRGB(117,204,255))
	else
		local events={"FamilyDay","NightMuseum","VIPGala"}
		for _,id in ipairs(events) do local e=state.Events[id] if e then button(e.Name.." · "..money(e.Cost),function() doAction({Action="StartEvent",EventId=id}) end,Color3.fromRGB(85,67,112)) end end
	end
end

open.Activated:Connect(function() panel.Visible=not panel.Visible if panel.Visible then refresh() end end)
close.Activated:Connect(function() panel.Visible=false end)
