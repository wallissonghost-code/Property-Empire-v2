local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local GameConfig=require(ReplicatedStorage.Shared.GameConfig)

local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("MuseumRemotes")
local openEvent=remotes:WaitForChild("OpenMuseumUI")
local toastEvent=remotes:WaitForChild("MuseumToast")
local getState=remotes:WaitForChild("GetMuseumState")
local action=remotes:WaitForChild("MuseumAction")

local gui=Instance.new("ScreenGui") gui.Name="MuseumEmpireUI" gui.ResetOnSpawn=false gui.Parent=player:WaitForChild("PlayerGui")
local cash=Instance.new("TextLabel") cash.Size=UDim2.fromOffset(230,46) cash.Position=UDim2.fromOffset(16,16) cash.BackgroundColor3=Color3.fromRGB(18,21,27) cash.BackgroundTransparency=.12 cash.TextColor3=Color3.new(1,1,1) cash.Font=Enum.Font.GothamBold cash.TextSize=18 cash.Parent=gui
Instance.new("UICorner",cash).CornerRadius=UDim.new(0,10)

local toast=Instance.new("TextLabel") toast.AnchorPoint=Vector2.new(.5,0) toast.Position=UDim2.new(.5,0,0,18) toast.Size=UDim2.new(.8,0,0,48) toast.BackgroundColor3=Color3.fromRGB(26,32,39) toast.BackgroundTransparency=.08 toast.TextColor3=Color3.fromRGB(238,241,245) toast.Font=Enum.Font.GothamSemibold toast.TextSize=14 toast.TextWrapped=true toast.Visible=false toast.Parent=gui
Instance.new("UICorner",toast).CornerRadius=UDim.new(0,10)

local panel=Instance.new("Frame") panel.AnchorPoint=Vector2.new(.5,.5) panel.Position=UDim2.fromScale(.5,.52) panel.Size=UDim2.new(.92,0,.86,0) panel.BackgroundColor3=Color3.fromRGB(19,23,29) panel.Visible=false panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,14)
local limit=Instance.new("UISizeConstraint") limit.MinSize=Vector2.new(310,420) limit.MaxSize=Vector2.new(620,720) limit.Parent=panel
local title=Instance.new("TextLabel") title.Position=UDim2.fromOffset(18,12) title.Size=UDim2.new(1,-95,0,34) title.BackgroundTransparency=1 title.TextColor3=Color3.new(1,1,1) title.TextXAlignment=Enum.TextXAlignment.Left title.Font=Enum.Font.GothamBold title.TextSize=19 title.Parent=panel
local sub=Instance.new("TextLabel") sub.Position=UDim2.fromOffset(18,46) sub.Size=UDim2.new(1,-95,0,24) sub.BackgroundTransparency=1 sub.TextColor3=Color3.fromRGB(150,162,177) sub.TextXAlignment=Enum.TextXAlignment.Left sub.Font=Enum.Font.Gotham sub.TextSize=12 sub.Parent=panel
local close=Instance.new("TextButton") close.Size=UDim2.fromOffset(54,36) close.Position=UDim2.new(1,-70,0,16) close.Text="X" close.Font=Enum.Font.GothamBold close.TextSize=15 close.TextColor3=Color3.new(1,1,1) close.BackgroundColor3=Color3.fromRGB(81,47,51) close.Parent=panel Instance.new("UICorner",close).CornerRadius=UDim.new(0,8)
local list=Instance.new("ScrollingFrame") list.Position=UDim2.fromOffset(16,80) list.Size=UDim2.new(1,-32,1,-96) list.BackgroundColor3=Color3.fromRGB(25,30,37) list.BorderSizePixel=0 list.AutomaticCanvasSize=Enum.AutomaticSize.Y list.CanvasSize=UDim2.new() list.ScrollBarThickness=6 list.Parent=panel Instance.new("UICorner",list).CornerRadius=UDim.new(0,10)
local layout=Instance.new("UIListLayout") layout.Padding=UDim.new(0,7) layout.Parent=list
local padding=Instance.new("UIPadding") padding.PaddingLeft=UDim.new(0,10) padding.PaddingRight=UDim.new(0,10) padding.PaddingTop=UDim.new(0,10) padding.PaddingBottom=UDim.new(0,10) padding.Parent=list

local currentOwner=nil
local focusedUid=nil
local busy=false
local function money(n) local s=tostring(math.floor(tonumber(n) or 0)) repeat local n2,k=s:gsub("^(-?%d+)(%d%d%d)","%1.%2") s=n2 until k==0 return "$"..s end
local function updateCash() cash.Text="💰 "..money(player:GetAttribute("Cash") or 0) end
player:GetAttributeChangedSignal("Cash"):Connect(updateCash) updateCash()
local function showToast(text) toast.Text=text toast.Visible=true task.delay(3,function() if toast.Text==text then toast.Visible=false end end) end
toastEvent.OnClientEvent:Connect(showToast)
local function clear() for _,c in ipairs(list:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end end
local function label(text,h,bold,color) local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-4,0,h or 30) l.BackgroundTransparency=1 l.Text=text l.TextWrapped=true l.TextXAlignment=Enum.TextXAlignment.Left l.TextColor3=color or Color3.fromRGB(228,232,238) l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham l.TextSize=bold and 14 or 13 l.Parent=list return l end
local function button(text,callback,color) local b=Instance.new("TextButton") b.Size=UDim2.new(1,-4,0,38) b.Text=text b.TextWrapped=true b.Font=Enum.Font.GothamSemibold b.TextSize=13 b.TextColor3=Color3.new(1,1,1) b.BackgroundColor3=color or Color3.fromRGB(48,74,98) b.Parent=list Instance.new("UICorner",b).CornerRadius=UDim.new(0,8) b.Activated:Connect(callback) return b end
local refresh
local function doAction(payload)
	if busy then return end busy=true local ok,res=pcall(function() return action:InvokeServer(payload) end) busy=false
	if not ok or type(res)~="table" then showToast("Falha de comunicação") return end showToast(res.Message or res.Error or "Concluído") refresh()
end
local function artifactBlock(a,isOwner,ownerId)
	label(string.format("[%s] %s",string.upper(a.Rarity),a.Name),30,true,a.Rarity=="Mítico" and Color3.fromRGB(191,151,255) or Color3.fromRGB(238,238,238))
	local sale=a.ForSale and ("À VENDA · "..money(a.Price)) or "BLOQUEADO"
	label(string.format("Valor estimado %s · prestígio %d · %s",money(a.BaseValue),a.Prestige,sale),34,false)
	if isOwner then
		if a.Location=="Inventory" then button("COLOCAR EM EXPOSIÇÃO",function() doAction({Action="Place",Uid=a.Uid}) end,Color3.fromRGB(55,101,79))
		else
			button("GUARDAR NO INVENTÁRIO",function() doAction({Action="Store",Uid=a.Uid}) end)
			button(a.ForSale and "BLOQUEAR VENDA" or "COLOCAR À VENDA",function() doAction({Action="ToggleSale",Uid=a.Uid}) end,a.ForSale and Color3.fromRGB(92,55,58) or Color3.fromRGB(67,96,69))
			if a.ForSale then
				button("PREÇO - "..money(GameConfig.PriceStep),function() doAction({Action="SetPrice",Uid=a.Uid,Price=math.max(1,a.Price-GameConfig.PriceStep)}) end)
				button("PREÇO + "..money(GameConfig.PriceStep),function() doAction({Action="SetPrice",Uid=a.Uid,Price=a.Price+GameConfig.PriceStep}) end)
			end
		end
	elseif a.ForSale then
		button("COMPRAR POR "..money(a.Price),function() doAction({Action="Buy",SellerUserId=ownerId,Uid=a.Uid}) end,Color3.fromRGB(54,105,75))
	end
end
refresh=function()
	if not currentOwner then return end
	local ok,state=pcall(function() return getState:InvokeServer(currentOwner) end)
	if not ok or type(state)~="table" or not state.Ok then showToast((type(state)=="table" and state.Error) or "Museu indisponível") return end
	clear() title.Text=string.upper(state.OwnerName.." · MUSEU") sub.Text=string.format("Nível %d · prestígio %d · vitrines %d",state.Level,state.Score,state.Capacity)
	if state.IsOwner then
		label("SEU MUSEU",30,true,Color3.fromRGB(115,214,181))
		label(string.format("Visitas: %d · receita de NPCs: %s · vendas: %d · compras: %d",state.Stats.Visits or 0,money(state.Stats.VisitorRevenue or 0),state.Stats.Sales or 0,state.Stats.Purchases or 0),48,false)
		if state.UpgradeCost then button("EXPANDIR MUSEU · "..money(state.UpgradeCost),function() doAction({Action="Upgrade"}) end,Color3.fromRGB(91,72,125)) end
		label("PEÇAS EXPOSTAS",30,true)
		local any=false for _,a in ipairs(state.Artifacts) do if a.Location=="Display" then any=true artifactBlock(a,true,state.OwnerUserId) end end if not any then label("Nenhuma peça em exposição ainda.",34,false) end
		label("INVENTÁRIO",30,true)
		local inv=false for _,a in ipairs(state.Artifacts) do if a.Location=="Inventory" then inv=true artifactBlock(a,true,state.OwnerUserId) end end if not inv then label("Vá até a mina para encontrar novas peças.",38,false) end
	else
		label("EXPOSIÇÃO",30,true,Color3.fromRGB(239,198,105))
		for _,a in ipairs(state.Artifacts) do artifactBlock(a,false,state.OwnerUserId) end
	end
end
openEvent.OnClientEvent:Connect(function(ownerId,uid) currentOwner=ownerId focusedUid=uid panel.Visible=true refresh() end)
close.Activated:Connect(function() panel.Visible=false currentOwner=nil focusedUid=nil end)
UserInputService.InputBegan:Connect(function(input,processed) if not processed and panel.Visible and input.KeyCode==Enum.KeyCode.Escape then panel.Visible=false currentOwner=nil end end)
showToast("Museum Empire: mine peças raras e construa o museu mais valioso da cidade")
print("[Museum Empire] Client ready")
