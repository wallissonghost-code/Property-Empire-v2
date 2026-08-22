local Config = {
	MaxLevel = 5,
	DisplaySlots = { 4, 8, 12, 18, 24 },
	UpgradeCosts = { 0, 25000, 100000, 350000, 1000000 },
	LevelScore = { 10, 25, 50, 90, 150 },
	BaseVisitorRevenue = 20,
	RevenuePerScore = 0.55,
	MaxRevenuePerVisitor = 7500,
	VisitorTickSeconds = 4,
	VisitorChanceBase = 0.16,
	VisitorChancePerScore = 0.0012,
	MaxVisitorChance = 0.9,
}
return table.freeze(Config)
