local Config = {
	MaxLevel = 5,
	DisplaySlots = { 4, 8, 12, 18, 24 },
	UpgradeCosts = { 0, 25000, 100000, 350000, 1000000 },
	LevelScore = { 10, 25, 50, 90, 150 },

	-- Estrelas são uma leitura simples do prestígio total do museu.
	StarThresholds = { 0, 40, 100, 220, 450 },

	BaseVisitorRevenue = 20,
	RevenuePerScore = 0.55,
	MaxRevenuePerVisitor = 7500,
	VisitorTickSeconds = 3.5,
	VisitorChanceBase = 0.18,
	VisitorChancePerScore = 0.0014,
	MaxVisitorChance = 0.92,
	MaxVisitorsPerMuseum = 8,
	VisitorStayMin = 4,
	VisitorStayMax = 10,
	VisitorWalkSpeed = 11,

	VisitorTypes = {
		{ Id = "Regular", Name = "Visitante", Weight = 55, RevenueMultiplier = 1.0 },
		{ Id = "Tourist", Name = "Turista", Weight = 23, RevenueMultiplier = 1.2 },
		{ Id = "Student", Name = "Estudante", Weight = 12, RevenueMultiplier = 0.8 },
		{ Id = "Collector", Name = "Colecionador", Weight = 7, RevenueMultiplier = 1.8, MinScore = 70 },
		{ Id = "VIP", Name = "VIP", Weight = 3, RevenueMultiplier = 3.0, MinScore = 180 },
	},
}

function Config.GetStars(score)
	score = math.max(0, tonumber(score) or 0)
	local stars = 1
	for index, threshold in ipairs(Config.StarThresholds) do
		if score >= threshold then
			stars = index
		end
	end
	return math.clamp(stars, 1, #Config.StarThresholds)
end

return table.freeze(Config)
