local BusinessEconomyConfig = {
	DataStoreName = "PropertyEmpireV2_BusinessEconomy_v1",
	DataVersion = 1,
	MaxInventoryPerItem = 9999,
	MinimumCashTransfer = 100,
	MaximumCashTransfer = 50000,
	FarmProductionCooldown = 20,
	PizzeriaServeCooldown = 10,
	CityPizzaPrice = 95,
	MaxCitySalePerAction = 5,
	MinSalePrice = 1,
	MaxSalePrice = 500,
	Items = {
		Flour = {
			DisplayName = "Farinha",
			DefaultFarmPrice = 18,
		},
		Cheese = {
			DisplayName = "Queijo",
			DefaultFarmPrice = 28,
		},
		Tomato = {
			DisplayName = "Tomate",
			DefaultFarmPrice = 15,
		},
		Pizza = {
			DisplayName = "Pizza",
		},
	},
	FarmItemOrder = {
		"Flour",
		"Cheese",
		"Tomato",
	},
	InventoryOrder = {
		"Flour",
		"Cheese",
		"Tomato",
		"Pizza",
	},
	FarmYield = {
		Flour = 5,
		Cheese = 3,
		Tomato = 4,
	},
	PizzeriaRecipe = {
		Inputs = {
			Flour = 2,
			Cheese = 1,
			Tomato = 1,
		},
		OutputItem = "Pizza",
		OutputQuantity = 1,
	},
}

return table.freeze(BusinessEconomyConfig)
