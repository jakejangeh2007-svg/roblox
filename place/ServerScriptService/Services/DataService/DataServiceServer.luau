--!strict
-- ModuleScript: ServerScriptService.Services.DataService.DataServiceServer
--
-- Loads and saves each player's data (see DataConfig.PlayerData) with DataStores.
-- Other services read and change a player's data through GetData. Changes are
-- saved every AUTOSAVE_INTERVAL, when the player leaves, and when the server shuts down.
--
-- Session lock: while a player is in this server, their saved record is marked as
-- in use. If they rejoin quickly and land in another server, that server waits for
-- this one to finish saving instead of loading old data and overwriting newer data.
--
-- If data can't load (for example in Studio without API access), the player plays
-- with default data and nothing is saved, so their real data is never overwritten.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataConfig = require(ReplicatedStorage.Shared.Modules.Game.DataConfig)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

type Session = {
	Data: DataConfig.PlayerData,
	Loaded: boolean, -- true once loading has finished, whether it worked or not
	CanSave: boolean, -- false when loading failed
}

type SessionLock = {
	JobId: string,
	Time: number,
}

type SavedRecord = {
	Data: DataConfig.PlayerData?,
	SessionLock: SessionLock?,
}

local DataServiceServer = {}

type DataServiceServerMembers = {
	Store: DataStore?, -- nil when DataStores aren't available
	Sessions: { [Player]: Session },
}

export type DataServiceServer = typeof(DataServiceServer) & DataServiceServerMembers

local function GetKey(player: Player): string
	return DataConfig.KEY_PREFIX .. player.UserId
end

local function IsLockedByAnotherServer(record: SavedRecord): boolean
	local lock = record.SessionLock
	return lock ~= nil and lock.JobId ~= game.JobId and os.time() - lock.Time < DataConfig.SESSION_LOCK_EXPIRY
end

-- Marks the saved record as in use by this server and returns it. Returns nil, and
-- changes nothing, while another server still holds it (unless `force` is true).
local function ClaimRecord(store: DataStore, key: string, force: boolean): SavedRecord?
	local claimedRecord: SavedRecord? = nil
	store:UpdateAsync(key, function(saved: SavedRecord?): SavedRecord?
		local record: SavedRecord = saved or {}
		if IsLockedByAnotherServer(record) and not force then
			claimedRecord = nil
			return nil
		end
		record.SessionLock = { JobId = game.JobId, Time = os.time() }
		claimedRecord = record
		return record
	end)
	return claimedRecord
end

function DataServiceServer.Init(self: DataServiceServer)
	self.Sessions = {}

	local success, result = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.DATASTORE_NAME)
	end)
	if success then
		self.Store = result
	else
		self.Store = nil
		warn(`DataStores aren't available, so progress won't be saved: {result}`)
	end

	Players.PlayerAdded:Connect(function(player)
		self:LoadAsync(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self.LoadAsync, self, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)
	game:BindToClose(function()
		self:SaveAllAsync(true)
	end)

	task.spawn(function()
		while true do
			task.wait(DataConfig.AUTOSAVE_INTERVAL)
			self:SaveAllAsync(false)
		end
	end)
end

function DataServiceServer.LoadAsync(self: DataServiceServer, player: Player)
	local session: Session = {
		Data = TableUtil.DeepCopy(DataConfig.DEFAULT_DATA),
		Loaded = false,
		CanSave = false,
	}
	self.Sessions[player] = session

	local store = self.Store
	if store then
		local key = GetKey(player)
		for attempt = 1, DataConfig.MAX_LOAD_ATTEMPTS do
			local isLastAttempt = attempt == DataConfig.MAX_LOAD_ATTEMPTS
			-- On the last attempt, take the lock anyway: the other server has had plenty of time.
			local success, result = pcall(ClaimRecord, store, key, isLastAttempt)
			if success and result then
				local data = result.Data or TableUtil.DeepCopy(DataConfig.DEFAULT_DATA)
				TableUtil.Reconcile(data, DataConfig.DEFAULT_DATA)
				session.Data = data
				session.CanSave = true
				break
			elseif not success then
				warn(`Couldn't load data for {player.Name} (attempt {attempt}): {result}`)
				if RunService:IsStudio() then
					warn(
						"To test saving in Studio: publish the place, then turn on Game Settings > Security > Enable Studio Access to API Services."
					)
					break
				end
			end
			if isLastAttempt or not player.Parent then
				break
			end
			task.wait(DataConfig.LOAD_RETRY_DELAY)
		end
		if not session.CanSave then
			warn(`{player.Name} is playing without saving because their data didn't load.`)
		end
	end

	session.Loaded = true
	if not player.Parent then
		-- They left while loading: give the lock back and forget them.
		self:SaveAsync(player, true)
		self.Sessions[player] = nil
	end
end

-- Saves `player`'s data. With `releaseLock`, also marks the record as free for other servers.
function DataServiceServer.SaveAsync(self: DataServiceServer, player: Player, releaseLock: boolean)
	local session = self.Sessions[player]
	local store = self.Store
	if not session or not session.CanSave or not store then
		return
	end
	local data = session.Data
	local success, problem = pcall(function()
		store:UpdateAsync(GetKey(player), function(saved: SavedRecord?): SavedRecord?
			local record: SavedRecord = saved or {}
			local lock = record.SessionLock
			if lock and lock.JobId ~= game.JobId then
				return nil -- another server has taken over this player; never overwrite its data
			end
			record.Data = data
			record.SessionLock = if releaseLock then nil else { JobId = game.JobId, Time = os.time() }
			return record
		end)
	end)
	if not success then
		warn(`Couldn't save data for {player.Name}: {problem}`)
	end
end

-- Saves every player at once and returns when all saves have finished.
function DataServiceServer.SaveAllAsync(self: DataServiceServer, releaseLocks: boolean)
	local pendingSaves = 0
	for player in self.Sessions do
		pendingSaves += 1
		task.spawn(function()
			self:SaveAsync(player, releaseLocks)
			pendingSaves -= 1
		end)
	end
	while pendingSaves > 0 do
		task.wait()
	end
end

function DataServiceServer.OnPlayerRemoving(self: DataServiceServer, player: Player)
	local session = self.Sessions[player]
	if not session or not session.Loaded then
		return -- LoadAsync cleans up once it finishes
	end
	self:SaveAsync(player, true)
	self.Sessions[player] = nil
end

-- The player's data, or nil if it hasn't finished loading. Changes to the returned
-- table are saved automatically.
function DataServiceServer.GetData(self: DataServiceServer, player: Player): DataConfig.PlayerData?
	local session = self.Sessions[player]
	return if session and session.Loaded then session.Data else nil
end

-- Like GetData, but waits up to WAIT_FOR_DATA_TIMEOUT seconds for the data to load.
function DataServiceServer.WaitForDataAsync(self: DataServiceServer, player: Player): DataConfig.PlayerData?
	local deadline = os.clock() + DataConfig.WAIT_FOR_DATA_TIMEOUT
	while player.Parent and os.clock() < deadline do
		local data = self:GetData(player)
		if data then
			return data
		end
		task.wait()
	end
	return self:GetData(player)
end

return DataServiceServer :: DataServiceServer
