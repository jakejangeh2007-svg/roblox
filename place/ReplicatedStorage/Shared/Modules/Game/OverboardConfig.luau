--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.OverboardConfig
--
-- Riders who get knocked off their boat (OverboardService). Anything solid that hits a
-- rider hard enough knocks them off (spikes and other hazards pop the boat instead).
-- They go flying, lie limp in the water for a moment, then come round and have to swim
-- back by farting, and grab back on along their own stretch of the edge.

local OverboardConfig = {
	-- Getting knocked off
	KNOCK_OFF_SPEED = 7, -- studs/s something has to hit a rider at (compared to how they're moving) to knock them off
	HIT_BOX_SIZE = Vector3.new(2.5, 5, 2), -- the space round a rider that counts as them being hit...
	HIT_BOX_OFFSET = CFrame.new(0, -0.5, 0), -- ...from their HumanoidRootPart
	THROW_BOUNCE = 0.4, -- they fly off what hit them with its speed, plus this much of it again
	THROW_UP_SPEED = 45, -- studs/s they're thrown upward (about as high as a jump)
	THROW_OUT_SPEED = 8, -- studs/s they're thrown away from their boat
	MAX_THROW_SPEED = 45, -- studs/s they're never thrown faster than, across the water
	THROW_SPIN = 8, -- rad/s they tumble at as they fly
	REBOARD_GRACE_TIME = 1.5, -- seconds after grabbing back on before they can be knocked off again

	-- Knocked out: limp as a ragdoll for this long
	KNOCKOUT_TIME = 3,
	LIMB_SWING = 75, -- degrees an arm, leg or hand can swing from how it was when they were hit...
	SPINE_SWING = 30, -- ...and their neck and waist
	JOINT_TWIST = 30, -- degrees any joint can twist either way

	-- Floating. The water holds them up like a soft spring, like it holds up boats.
	FLOAT_HEIGHT = -0.4, -- how far above the surface a swimmer's HumanoidRootPart floats
	LIMP_FLOAT_HEIGHT = -0.2, -- how far above the surface each part of a knocked-out body floats
	FLOAT_STIFFNESS = 40, -- studs/s² of push back up for every stud they're pushed under
	MAX_FLOAT_DEPTH = 3, -- pushing them deeper than this doesn't push them back up any harder
	FLOAT_DAMPING = 8, -- how quickly bobbing dies down, per second
	SPLASH_DAMPING = 0.2, -- extra damping that grows with up/down speed, so landing in the water stops them quickly
	AIRBORNE_HEIGHT = 1, -- studs above the surface they're out of the water; the water's hold fades in below that
	LIMP_DRAG = 2.5, -- per second: how quickly a knocked-out body slows down in the water (sprawled out, it stops quickly)
	LIMP_SPIN_DAMPING = 3, -- how quickly a knocked-out body stops tumbling in the water, per second
	TURBULENCE_SCALE = 1, -- how hard rapids shove swimmers, compared to how hard they shove boats

	-- Swimming. Farting pushes a swimmer the way they face; A and D turn them.
	FART_PUSH_SCALE = 0.5, -- a fart pushes a swimmer at this fraction of FartConfig's push strengths
	GLIDE_DRAG = 0.8, -- per second: how quickly a swimmer slows down when they stop farting
	TOP_SPEED = 14, -- studs/s a swimmer farting at full strength levels off at (slower than a boat)
	TURN_SPEED = math.rad(160), -- how fast a swimmer turns (radians per second)
	TURN_RESPONSE_TIME = 0.12, -- turning speeds up and slows down most of the way in this many seconds
	FACING_RESPONSIVENESS = 20, -- how quickly their body turns to face where they're heading (higher = snappier)

	-- Grabbing back on: swim to within this many studs of anywhere along your own stretch
	-- of your boat's edge and you grab straight back on there.
	GRAB_DISTANCE = 3,
	SWIM_TIME_LIMIT = 30, -- seconds a swimmer has to get back aboard before they're sent back to their checkpoint
	FALL_DISTANCE = 30, -- a swimmer this far below the last water they were in has fallen off the river

	-- Swimming pose (on every player's screen)
	SWIM_LEAN = math.rad(50), -- leaning forward this far from upright
	PADDLE_REACH = math.rad(110), -- arms reach forward this far from hanging down...
	PADDLE_ANGLE = math.rad(35), -- ...and paddle this far either side of that, one arm after the other...
	PADDLE_SPEED = 9, -- ...this fast (radians of the paddle cycle per second)
	ELBOW_BEND = math.rad(30),
	KICK_ANGLE = math.rad(25), -- legs kick this far either way...
	KICK_SPEED = 12, -- ...this fast (radians of the kick cycle per second)
	KNEE_BEND = math.rad(20),
	STICK_DEADZONE = 0.5, -- how far a controller's left stick has to be pushed left or right to turn
}

return OverboardConfig
