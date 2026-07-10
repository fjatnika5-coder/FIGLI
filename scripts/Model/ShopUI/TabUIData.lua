local module = {}

module.Inventory = {

	Special = {
		Name = "Special Items",
		IconId = 3057073083,
		Order = 1
	},

	Items = {
		Name = "Normal Items",
		IconId = 15932726500,
		Order = 2
	},

	ExItems = {
		Name = "Exclusive Items",
		IconId = 10885027503,
		Order = 3
	},

	Auras = {
		Name = "Normal Auras",
		IconId = 9483381627,
		Order = 4
	},

	SpecialAuras = {
		Name = "Special Auras",
		IconId = 10885027503,
		Order = 5
	},

}

module.Shop = {

	Special = {
		Name = "Special Items",
		IconId = 3057073083,
		Order = 1,
		InventoryTabName = module.Inventory.Special
	},
	Items = {
		Name = "Cash Items",
		IconId = 15932726500,
		Order = 2,
		InventoryTabName = module.Inventory.Items
	},
	ExItems = {
		Name = "Exclusive Items",
		IconId = 10885027503,
		Order = 3,
		InventoryTabName = module.Inventory.ExItems
	},

	GemItems = {
		Name = "Gem Items",
		IconId = 6690991975,
		Order = 4,
		InventoryTabName = module.Inventory.Special
	},

    --[[ ❌ AURA SHOPS DIHAPUS/COMMENT
    Auras = {
        Name = "Normal Auras",
        IconId = 9483381627,
        Order = 5,
        InventoryTabName = module.Inventory.Auras,
        Disabled = false
    },
    GemAuras = {
        Name = "Gem Auras",
        IconId = 6690991975,
        Order = 6,
        InventoryTabName = module.Inventory.SpecialAuras,
        Disabled = false
    },
    SpecialAuras = {
        Name = "Special Auras",
        IconId = 10885027503,
        Order = 7,
        InventoryTabName = module.Inventory.SpecialAuras,
        Disabled = false
    },
    ]]

	Gamepasses = {
		Name = "Gamepasses",
		IconId = 13885942899,
		Order = 5  -- ✅ Order diubah jadi 5
	},

	GemsFrame = {
		Name = "Gems",
		IconId = 2654418499,
		NotVisible = true,
		Button = script.Parent.MainFrame:WaitForChild("TopBar"):WaitForChild("PlayerGems"):WaitForChild("buy")
	},

	CashFrame = {
		Name = "Cash",
		IconId = 14732298754,
		NotVisible = true,
		Button = script.Parent.MainFrame:WaitForChild("TopBar"):WaitForChild("PlayerCash"):WaitForChild("buy")
	},

}

return module