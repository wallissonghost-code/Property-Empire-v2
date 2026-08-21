local GameConfig = require(script.Parent.GameConfig)

local PlayerDataTemplate = {
	SchemaVersion = GameConfig.SchemaVersion,
	Cash = GameConfig.StartingCash,
	Bank = 0,
	OwnedLots = {},
	Businesses = {},
	Inventory = {},
	Vehicles = {},
	Settings = {
		MusicEnabled = true,
		SfxEnabled = true,
	},
	Meta = {
		CreatedAt = 0,
		LastSeenAt = 0,
	},
}

return table.freeze(PlayerDataTemplate)
