local GameConfig = {
	UniverseId = 10715548183,
	PlaceId = 138523274489009,
	DataStoreName = "PropertyEmpireV2_PlayerData_v1",
	SchemaVersion = 1,
	StartingCash = 25000,
	AutoSaveInterval = 60,

	-- Temporary owner/tester mode. This grants effectively unlimited personal
	-- cash during a play session without persisting the inflated balance.
	TestUnlimitedCashEnabled = true,
	TestUnlimitedCash = 999999999,
	TestUnlimitedCashCreatorAccess = true,
	TestUnlimitedCashUsernames = {
		"Ghostzinhuuu21",
	},
}

return table.freeze(GameConfig)
