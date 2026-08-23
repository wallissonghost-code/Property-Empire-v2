local Config = {}

Config.StaffRoles = {
	Reception = { Name = "Recepcionista", Color = Color3.fromRGB(62, 140, 210) },
	Security = { Name = "Segurança", Color = Color3.fromRGB(46, 52, 62) },
	Cleaning = { Name = "Limpeza", Color = Color3.fromRGB(76, 166, 133) },
	Shop = { Name = "Atendente da loja", Color = Color3.fromRGB(184, 120, 58) },
	Guide = { Name = "Guia", Color = Color3.fromRGB(128, 91, 180) },
}

Config.Missions = {
	{ Id = "visits_25", Name = "Primeiros fãs", Description = "Receba 25 visitantes", Stat = "Visits", Goal = 25, Reward = 2500 },
	{ Id = "revenue_10000", Name = "Museu lucrativo", Description = "Ganhe $10.000 com visitantes", Stat = "VisitorRevenue", Goal = 10000, Reward = 5000 },
	{ Id = "mine_10", Name = "Curador iniciante", Description = "Encontre 10 artefatos", Stat = "Mined", Goal = 10, Reward = 3500 },
	{ Id = "vip_5", Name = "Tapete vermelho", Description = "Receba 5 visitantes VIP", Stat = "VIPVisits", Goal = 5, Reward = 7000 },
	{ Id = "shop_5000", Name = "Loja movimentada", Description = "Fature $5.000 na loja", Stat = "ShopRevenue", Goal = 5000, Reward = 6000 },
}

Config.Achievements = {
	{ Id = "museum_level_2", Name = "Museu em expansão", Kind = "Level", Goal = 2 },
	{ Id = "museum_level_5", Name = "Império cultural", Kind = "Level", Goal = 5 },
	{ Id = "prestige_100", Name = "Nome respeitado", Kind = "Prestige", Goal = 100 },
	{ Id = "visits_250", Name = "Ponto turístico", Kind = "Visits", Goal = 250 },
	{ Id = "events_10", Name = "Mestre de eventos", Kind = "EventsHosted", Goal = 10 },
}

Config.IncidentTick = 24
Config.RobberyBaseChance = 0.08
Config.RobberyMaxChance = 0.28
Config.RobberyLossMin = 250
Config.RobberyLossMax = 2500
Config.ShopTick = 16
Config.RandomEventTick = 90
Config.RandomEvents = {
	{ Id = "SchoolTrip", Name = "Excursão escolar", Duration = 60, RevenueBoost = 1.15 },
	{ Id = "InfluencerVisit", Name = "Influenciador visitando", Duration = 75, RevenueBoost = 1.25 },
	{ Id = "RainyDay", Name = "Dia chuvoso", Duration = 60, RevenueBoost = 0.9 },
	{ Id = "CultureWeek", Name = "Semana cultural", Duration = 90, RevenueBoost = 1.35 },
}

return table.freeze(Config)
