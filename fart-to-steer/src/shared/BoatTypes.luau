--!strict
-- The round boats. Seats are spread evenly around the ring, and riders sit on
-- the tube facing the middle with their butts over the water.

export type BoatType = {
	name: string,
	seats: number,
	fillOrder: { number }, -- which seat each new rider gets, so riders spread out around the ring
	ringRadius: number, -- studs from the middle of the boat to the middle of the tube
	tubeRadius: number,
	pushScale: number, -- multiplies every push
	spinScale: number, -- multiplies every turn
	color: Color3,
}

local BoatTypes: { [string]: BoatType } = {
	SoloTube = {
		name = "Solo Tube",
		seats = 1,
		fillOrder = { 1 },
		ringRadius = 3,
		tubeRadius = 1.1,
		pushScale = 1.2,
		spinScale = 1.5,
		color = Color3.fromRGB(255, 170, 60),
	},
	DoubleDonut = {
		name = "Double Donut",
		seats = 2,
		fillOrder = { 1, 2 },
		ringRadius = 4.5,
		tubeRadius = 1.2,
		pushScale = 1.1,
		spinScale = 1.2,
		color = Color3.fromRGB(255, 120, 170),
	},
	PartyRing = {
		name = "Party Ring",
		seats = 4,
		fillOrder = { 1, 3, 2, 4 },
		ringRadius = 6,
		tubeRadius = 1.2,
		pushScale = 1,
		spinScale = 1,
		color = Color3.fromRGB(255, 80, 80),
	},
	MegaDonut = {
		name = "Mega Donut",
		seats = 8,
		fillOrder = { 1, 5, 3, 7, 2, 6, 4, 8 },
		ringRadius = 9,
		tubeRadius = 1.4,
		pushScale = 0.6,
		spinScale = 0.45,
		color = Color3.fromRGB(120, 110, 255),
	},
}

return BoatTypes
