local LandConfig = {
	DataStoreName = "PropertyEmpireV2_Lots_v1",
	ReservationSeconds = 45,
	StarterPrice = 15000,

	World = {
		Size = Vector3.new(1800, 2, 1600),
		GroundColor = Color3.fromRGB(92, 118, 82),
		GroundMaterial = Enum.Material.Grass,
		SpawnPosition = Vector3.new(0, 0.5, -280),
	},

	-- Área pública exclusiva: nenhum lote comprável é gerado dentro deste retângulo.
	CivicDistrict = {
		Name = "Civico",
		DisplayName = "DISTRITO CÍVICO",
		Center = Vector3.new(0, -0.75, -410),
		Size = Vector3.new(300, 1, 240),
		PlazaCenter = Vector3.new(0, -0.45, -392),
		PlazaSize = Vector3.new(232, 1, 154),
		CityHallPosition = Vector3.new(0, 0.5, -458),
		MarkerPosition = Vector3.new(0, 0, -292),
	},

	-- LOT-01 through LOT-12 deliberately keep their original positions.
	-- This preserves existing ownership and construction data while the city grows around them.
	Districts = {
		{
			Name = "Centro",
			DisplayName = "CENTRO",
			FirstLotIndex = 1,
			Rows = 3,
			Columns = 4,
			LotSize = Vector3.new(72, 1, 72),
			Spacing = 14,
			Origin = Vector3.new(0, 0, 0),
			MarkerOffset = Vector3.new(-165, 0, -155),
		},
		{
			Name = "Residencial",
			DisplayName = "BAIRRO RESIDENCIAL",
			FirstLotIndex = 13,
			Rows = 2,
			Columns = 3,
			LotSize = Vector3.new(72, 1, 72),
			Spacing = 18,
			Origin = Vector3.new(-470, 0, 0),
			MarkerOffset = Vector3.new(-135, 0, -115),
		},
		{
			Name = "Comercial",
			DisplayName = "DISTRITO COMERCIAL",
			FirstLotIndex = 19,
			Rows = 2,
			Columns = 3,
			LotSize = Vector3.new(72, 1, 72),
			Spacing = 18,
			Origin = Vector3.new(470, 0, -40),
			MarkerOffset = Vector3.new(-135, 0, -115),
		},
	},

	ReservedZones = {
		{
			Name = "Industrial",
			DisplayName = "ZONA INDUSTRIAL",
			Center = Vector3.new(0, -0.75, 500),
			Size = Vector3.new(560, 1, 300),
			Color = Color3.fromRGB(105, 106, 103),
			Material = Enum.Material.Concrete,
		},
		{
			Name = "Rural",
			DisplayName = "ZONA RURAL",
			Center = Vector3.new(-500, -0.75, -500),
			Size = Vector3.new(520, 1, 360),
			Color = Color3.fromRGB(104, 137, 79),
			Material = Enum.Material.Grass,
		},
		{
			Name = "Mineracao",
			DisplayName = "ÁREA DE MINERAÇÃO",
			Center = Vector3.new(500, -0.75, -500),
			Size = Vector3.new(380, 1, 360),
			Color = Color3.fromRGB(82, 84, 86),
			Material = Enum.Material.Slate,
		},
	},

	Roads = {
		{ Name = "BoulevardSul", Size = Vector3.new(1500, 1, 24), Position = Vector3.new(0, -0.55, 165) },
		{ Name = "BoulevardNorte", Size = Vector3.new(1500, 1, 24), Position = Vector3.new(0, -0.55, -165) },
		{ Name = "AvenidaOeste", Size = Vector3.new(24, 1, 1250), Position = Vector3.new(-190, -0.55, 110) },
		{ Name = "AvenidaLeste", Size = Vector3.new(24, 1, 1250), Position = Vector3.new(190, -0.55, 110) },
		{ Name = "LigacaoResidencial", Size = Vector3.new(290, 1, 18), Position = Vector3.new(-335, -0.5, 0) },
		{ Name = "LigacaoComercial", Size = Vector3.new(290, 1, 18), Position = Vector3.new(335, -0.5, -40) },
		{ Name = "LigacaoIndustrial", Size = Vector3.new(18, 1, 350), Position = Vector3.new(0, -0.5, 325) },
		{ Name = "AvenidaCivica", Size = Vector3.new(24, 1, 126), Position = Vector3.new(0, -0.5, -228) },
		{ Name = "FrenteCivica", Size = Vector3.new(330, 1, 24), Position = Vector3.new(0, -0.5, -290) },
		{ Name = "LigacaoRural", Size = Vector3.new(18, 1, 335), Position = Vector3.new(-500, -0.5, -330) },
		{ Name = "LigacaoMineracao", Size = Vector3.new(18, 1, 335), Position = Vector3.new(500, -0.5, -330) },
	},
}

return table.freeze(LandConfig)
