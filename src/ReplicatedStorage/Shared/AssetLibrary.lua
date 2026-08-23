local AssetLibrary = {}

AssetLibrary.CreatorStore = {
	SmallMuseum = {
		Name = "Small Museum",
		AssetId = 5066948261,
		Category = "MuseumShell",
		Enabled = true,
	},
	DisplayCase = {
		Name = "Display Case",
		AssetId = 5360143567,
		Category = "Exhibit",
		Enabled = true,
	},
	Statue = {
		Name = "Statue",
		AssetId = 7937647616,
		Category = "Decoration",
		Enabled = true,
	},
	DinoSkull = {
		Name = "Dino Skull Display",
		AssetId = 14504227,
		Category = "Exhibit",
		Enabled = true,
	},
	HistoryGallery = {
		Name = "Museum Gallery History Exhibit Ancient",
		AssetId = 109449942844524,
		Category = "Gallery",
		Enabled = true,
	},
}

-- External GLB sources are kept as attribution/import metadata only.
-- Roblox cannot import arbitrary remote GLB files at runtime; these must be
-- downloaded, reviewed, optimized and imported through Studio before use.
AssetLibrary.ExternalGLB = {
	NationalGalleryLowPoly = {
		Name = "National Gallery of Art Low Poly Game Ready",
		License = "CC BY",
		Source = "https://sketchfab.com/3d-models/national-gallery-of-art-low-poly-game-ready-3303b852a0ea4557ad4d73eb78101cc6",
		Status = "ManualImportRequired",
	},
	MuseumShowcase = {
		Name = "Museum Showcase",
		License = "CC BY",
		Source = "https://sketchfab.com/3d-models/museum-showcase-348a94fabe6f42d5b4404eb19b71b35d",
		Status = "ManualImportRequired",
	},
	SmallMuseumDisplayCase = {
		Name = "Small Museum Display Case",
		License = "CC BY",
		Source = "https://sketchfab.com/3d-models/small-museum-display-case-bcc6c9850ce8455897196555418c6fa7",
		Status = "ManualImportRequired",
	},
	LowPolyFurnitureBundle = {
		Name = "Low Poly Furnitures Full Bundle",
		License = "CC BY",
		Source = "https://sketchfab.com/3d-models/low-poly-furnitures-full-bundle-05d29572fef94794803365bdbfd7afa9",
		Status = "ManualImportRequired",
	},
}

return table.freeze(AssetLibrary)
