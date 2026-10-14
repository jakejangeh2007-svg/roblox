--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Math.Cycle
--
-- Repeating timings, worked out from a clock time, so anything using the same clock
-- (like workspace:GetServerTimeNow()) stays in step without keeping any state.

local Cycle = {}

-- Something that goes back and forth between two ends: it waits `holdTime` seconds at
-- the first end, takes `moveTime` seconds to get to the second, waits there, comes back,
-- and so on, starting at the first end at `startDelay`. True while it's heading to (or
-- waiting at) the second end.
function Cycle.IsHeadingToSecondEnd(time: number, moveTime: number, holdTime: number, startDelay: number): boolean
	local period = 2 * (math.max(moveTime, 0) + math.max(holdTime, 0))
	if period <= 0 then
		return false
	end
	local phase = (time - startDelay) % period
	return phase >= holdTime and phase < 2 * holdTime + moveTime
end

-- Something that's on for `onTime` seconds, then off for `offTime`, and so on, starting
-- on at `startDelay`. True while it's on.
function Cycle.IsOn(time: number, onTime: number, offTime: number, startDelay: number): boolean
	local period = math.max(onTime, 0) + math.max(offTime, 0)
	if period <= 0 then
		return false
	end
	return (time - startDelay) % period < onTime
end

return Cycle
