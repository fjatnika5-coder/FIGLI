local Blueprints = {

	Piggyback = {
		Mode = "Multi",
		CFrame = CFrame.new(0, 0, 0),
		CarrierAnimID_R15 = 105608341209946,
		CarrierAnimID_R6 = 89433515567014,
		TargetAnimID_R15 = 72299042225473,
		TargetAnimID_R6 = 113527264523093,
	},

	Bridal = {
		Mode = "Solo",
		CFrame = CFrame.new(1.2, 0.6, -1),
		CarrierAnimID_R15 = 128922197333871,
		CarrierAnimID_R6 = 128922197333871,
		TargetAnimID_R15 = 77425673302164,
		TargetAnimID_R6 = 77425673302164,
	},

	ShoulderCarry = {
		Mode = "Solo",
		CFrame = CFrame.new(0, 2.5, 1.13),
		CarrierAnimID_R15 = 120546255639792,
		CarrierAnimID_R6 = 120546255639792,
		TargetAnimID_R15 = 87147610179619,
		TargetAnimID_R6 = 87147610179619,
	},

	Nyekek = {
		Mode = "Solo",
		CFrame = CFrame.new(0, 0.9, -2.1) * CFrame.fromEulerAnglesXYZ(-25, math.rad(180), 0),
		CarrierAnimID_R15 = 87786023116101,
		CarrierAnimID_R6 = 87786023116101,
		TargetAnimID_R15 = 106263444148212,
		TargetAnimID_R6 = 106263444148212,
	},

	Hug = {
		Mode = "Solo",
		CFrame = CFrame.new(0, 0.6, -1.2) * CFrame.fromEulerAnglesXYZ(-25, math.rad(180), 0),
		CarrierAnimID_R15 = 78730969078103,
		CarrierAnimID_R6 = 78730969078103,
		TargetAnimID_R15 = 83788925406021,
		TargetAnimID_R6 = 83788925406021,
	},

	Menyeret = {
		Mode = "Solo",
		CFrame = CFrame.new(-2.35, -2, 4.5) * CFrame.fromEulerAnglesXYZ(math.rad(-25), math.rad(180), 0),
		CarrierAnimID_R15 = 107968013984330,
		CarrierAnimID_R6 = 107968013984330,
		TargetAnimID_R15 = 119027758804163,
		TargetAnimID_R6 = 119027758804163,
	},

	Fireman = {
		Mode = "Solo",
		CFrame = CFrame.new(-2, -1.1, -1) * CFrame.new(0.9, 0.6, 1.04) * CFrame.Angles(math.rad(0), 0, math.rad(0)),
		CarrierAnimID_R15 = 91806854395225,
		CarrierAnimID_R6 = 91806854395225,
		TargetAnimID_R15 = 115526607213501,
		TargetAnimID_R6 = 115526607213501,
	},

}

return Blueprints