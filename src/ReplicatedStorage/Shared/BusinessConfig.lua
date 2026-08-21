local BusinessConfig = {
	DataStoreName = "PropertyEmpireV2_Businesses_v1",
	DataVersion = 1,
	LicenseFee = 1000,
	ReservationSeconds = 45,
	MinimumBuildPieces = 4,
	MinimumFloorPieces = 1,
	MinimumWallPieces = 2,
	InitialReputation = 10,
	TypeOrder = {
		"Farm",
		"Pizzeria",
		"LumberCompany",
		"FurnitureFactory",
		"MiningCompany",
		"Museum",
		"MarketingAgency",
	},
	Types = {
		Farm = {
			DisplayName = "Fazenda",
			Category = "Produção",
			Description = "Produz ingredientes e matérias-primas para outras empresas.",
		},
		Pizzeria = {
			DisplayName = "Pizzaria",
			Category = "Alimentação",
			Description = "Compra ingredientes e transforma estoque em pizzas para venda.",
		},
		LumberCompany = {
			DisplayName = "Madeireira",
			Category = "Produção",
			Description = "Fornece madeira para móveis e futuras cadeias de construção.",
		},
		FurnitureFactory = {
			DisplayName = "Fábrica de Móveis",
			Category = "Indústria",
			Description = "Compra madeira e produz móveis negociáveis.",
		},
		MiningCompany = {
			DisplayName = "Mineradora",
			Category = "Extração",
			Description = "Extrai recursos e pode encontrar itens raros.",
		},
		Museum = {
			DisplayName = "Museu",
			Category = "Cultura",
			Description = "Coleciona e exibe itens raros para gerar prestígio.",
		},
		MarketingAgency = {
			DisplayName = "Agência de Marketing",
			Category = "Serviços",
			Description = "Vende campanhas que ajudam outras empresas a ganhar demanda e reputação.",
		},
	},
}

return table.freeze(BusinessConfig)
