local Catalog = {}

Catalog.Items = {
	Quartz = { Name = "Cristal de Quartzo", Rarity = "Comum", Value = 120, Prestige = 1, Weight = 4000, Color = Color3.fromRGB(220,225,235), Material = Enum.Material.Glass },
	Ammonite = { Name = "Fóssil de Amonite", Rarity = "Incomum", Value = 900, Prestige = 4, Weight = 2200, Color = Color3.fromRGB(151,111,72), Material = Enum.Material.Sandstone },
	GoldNugget = { Name = "Pepita de Ouro", Rarity = "Incomum", Value = 2500, Prestige = 7, Weight = 1500, Color = Color3.fromRGB(255,190,55), Material = Enum.Material.Metal },
	Emerald = { Name = "Esmeralda", Rarity = "Raro", Value = 10000, Prestige = 18, Weight = 1000, Color = Color3.fromRGB(38,210,112), Material = Enum.Material.Glass },
	BlueDiamond = { Name = "Diamante Azul", Rarity = "Épico", Value = 75000, Prestige = 50, Weight = 600, Color = Color3.fromRGB(71,170,255), Material = Enum.Material.Glass },
	Meteorite = { Name = "Meteorito Antigo", Rarity = "Épico", Value = 180000, Prestige = 85, Weight = 350, Color = Color3.fromRGB(70,65,63), Material = Enum.Material.Slate },
	RoyalRelic = { Name = "Relíquia Real", Rarity = "Lendário", Value = 350000, Prestige = 120, Weight = 220, Color = Color3.fromRGB(231,178,48), Material = Enum.Material.Metal },
	BlackDiamond = { Name = "Diamante Negro", Rarity = "Mítico", Value = 1000000, Prestige = 250, Weight = 80, Color = Color3.fromRGB(19,20,26), Material = Enum.Material.Glass },
}

function Catalog.Get(id)
	return Catalog.Items[id]
end

function Catalog.Roll(rng)
	local total = 0
	for _, item in pairs(Catalog.Items) do total += item.Weight end
	local roll = rng:NextNumber(0, total)
	local cursor = 0
	for id, item in pairs(Catalog.Items) do
		cursor += item.Weight
		if roll <= cursor then return id, item end
	end
	return "Quartz", Catalog.Items.Quartz
end

return Catalog
