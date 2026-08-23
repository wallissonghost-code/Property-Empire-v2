local Config = {}

Config.MaxStaffLevel = 5
Config.TickSeconds = 15
Config.EventDurationSeconds = 180

Config.Roles = {
	Reception = {Name="Recepção", BaseCost=2500, CostGrowth=1.8, RevenuePerTick=35, RatingPerLevel=2},
	Security = {Name="Segurança", BaseCost=4000, CostGrowth=1.9, SecurityPerLevel=16, RatingPerLevel=1},
	Cleaning = {Name="Limpeza", BaseCost=3200, CostGrowth=1.85, CleanlinessPerLevel=18, RatingPerLevel=2},
	Shop = {Name="Loja", BaseCost=6000, CostGrowth=2.0, RevenuePerTick=75, RatingPerLevel=1},
	Guide = {Name="Guias", BaseCost=5000, CostGrowth=1.95, RevenuePerTick=45, PrestigePerLevel=3, RatingPerLevel=2},
}

Config.Events = {
	FamilyDay = {Name="Dia da Família", Cost=12000, RevenueMultiplier=1.25, VisitorMultiplier=1.35, RatingBonus=4},
	NightMuseum = {Name="Noite no Museu", Cost=25000, RevenueMultiplier=1.55, VisitorMultiplier=1.20, RatingBonus=7},
	VIPGala = {Name="Gala VIP", Cost=60000, RevenueMultiplier=2.1, VisitorMultiplier=0.9, RatingBonus=12, MinPrestige=120},
}

function Config.NextStaffCost(roleId, currentLevel)
	local role = Config.Roles[roleId]
	if not role then return nil end
	return math.floor(role.BaseCost * (role.CostGrowth ^ math.max(0, currentLevel)))
end

return table.freeze(Config)
