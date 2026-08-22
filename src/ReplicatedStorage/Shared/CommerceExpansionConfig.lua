local CommerceExpansionConfig = {
	DataStoreName = "PropertyEmpireV2_CommerceExpansion_v1",
	MarketingDataStoreName = "PropertyEmpireV2_MarketingTargets_v1",
	DataVersion = 1,
	MaxInventoryPerItem = 9999,
	MinimumCashTransfer = 100,
	MaximumCashTransfer = 100000,

	LumberProductionCooldown = 15,
	LumberYield = 8,
	DefaultWoodPrice = 40,
	MinWoodPrice = 5,
	MaxWoodPrice = 500,
	WoodPriceStep = 5,

	FurnitureServeCooldown = 12,
	MaxFurnitureCitySalePerAction = 3,
	FurnitureCityPrices = {
		Chair = 180,
		Table = 420,
		Sofa = 700,
	},
	FurnitureRecipes = {
		Chair = { Wood = 2, Output = 1 },
		Table = { Wood = 4, Output = 1 },
		Sofa = { Wood = 6, Output = 1 },
	},
	FurnitureOrder = { "Chair", "Table", "Sofa" },
	Items = {
		Wood = { DisplayName = "Madeira" },
		Chair = { DisplayName = "Cadeira" },
		Table = { DisplayName = "Mesa" },
		Sofa = { DisplayName = "Sofá" },
	},

	DefaultCampaignPrice = 1200,
	MinCampaignPrice = 500,
	MaxCampaignPrice = 10000,
	CampaignPriceStep = 100,
	CampaignDurationSeconds = 300,
	CampaignDemandBoost = 0.25,
	CampaignReputationGain = 2,
	MaxMarketingReputation = 100,
}

return table.freeze(CommerceExpansionConfig)
