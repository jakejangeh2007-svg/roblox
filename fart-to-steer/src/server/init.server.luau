--!strict
-- Server entry point: find (or build) the course, then start every service.

local BoatService = require(script.BoatService)
local Course = require(script.Course)
local FartService = require(script.FartService)
local WaterService = require(script.WaterService)

local course = Course.get()
BoatService.start(course)
WaterService.start(course)
FartService.start()
