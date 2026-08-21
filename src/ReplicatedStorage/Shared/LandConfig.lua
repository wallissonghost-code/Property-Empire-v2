local LandConfig = {
	DataStoreName = "PropertyEmpireV2_Lots_v1",
	ReservationSeconds = 45,
	StarterPrice = 15000,
	StarterDistrict = {
		Rows = 3,
		Columns = 4,
		LotSize = Vector3.new(72, 1, 72),
		Spacing = 14,
		GroundPadding = 52,
	},
}

return table.freeze(LandConfig)
