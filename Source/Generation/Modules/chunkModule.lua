--Handles chunks (create, destroy)

local chunkModule = {}

local state = {
	initialized = false,
	fastLoad = true,
}

--Returns terrain height at coordinates
local function getTerrainHeight(x, z)
	local sampleX = x + state.originX
	local sampleZ = z + state.originZ

	local noise = math.noise(
		(sampleX / state.terrainScale) * state.terrainFrequency,
		(sampleZ / state.terrainScale) * state.terrainFrequency
	)
	return math.clamp(noise, -1, 1) * state.terrainAmplitude
end

--Small wait between chunk generation unless in fast-load (prevents freezing when loading lots of chunks)
local function chunkWait()
	if not state.fastLoad then
		task.wait()
	end
end

--Updates the grid center from the player's position
local function updateCenterPos()
	local pos = state.HRP.Position
	state.centerPosX = math.floor(pos.X / state.terrainPartSize)
	state.centerPosZ = math.floor(pos.Z / state.terrainPartSize)
end

--Returns whether a chunk exists at coordinates
local function doesChunkExist(x, z)
	for _, chunk in pairs(state.chunks) do
		local chunkPos = chunk:GetPivot().Position
		if chunkPos.X / state.terrainPartSize == x and chunkPos.Z / state.terrainPartSize == z then
			return true
		end
	end
	return false
end

--Returns whether a chunk is outside render distance
local function isChunkOutOfRange(chunk)
	local chunkPos = chunk:GetPivot().Position
	return math.abs(chunkPos.X / state.terrainPartSize - state.centerPosX) > state.renderDistance
		or math.abs(chunkPos.Z / state.terrainPartSize - state.centerPosZ) > state.renderDistance
end

--Create a terrain chunk (also water/ceiling/props if needed)
local function createChunk(x, z)
	local chunkClone = state.chunkModel:Clone()
	local chunkTerrain = chunkClone.terrain

	local chunkY = getTerrainHeight(x, z)
	chunkClone:PivotTo(CFrame.new(x * state.terrainPartSize, chunkY, z * state.terrainPartSize))
	chunkClone.Parent = state.chunkFolder
	state.currentChunks += 1

	if state.waterHeight and state.waterHeight > chunkY + state.halfTerrainHeight then
		local waterChunk = state.waterGridPartModel:Clone()
		waterChunk:PivotTo(
			CFrame.new(
				x * state.terrainPartSize,
				state.waterHeight - state.waterHeightOffset,
				z * state.terrainPartSize
			) * CFrame.Angles(math.rad(90), 0, 0)
		)
		waterChunk.Parent = state.waterChunkFolder.render
		chunkTerrain.Position += Vector3.new(0, -40, 0)
	else
		for _, propEntry in state.propData do
			local propCount = state.propModule.getPropCount(propEntry, x, z)
			state.propModule.createProps(
				propEntry, x, z, chunkClone, propCount,
				state.worldSeed, state.terrainPartSize
			)
		end
	end

	if state.ceilingHeight then
		local ceilingY
		if state.waterHeight then
			ceilingY = state.waterHeight + state.ceilingHeight
		else
			ceilingY = chunkY + state.terrainPart.Size.Y + state.ceilingHeight
		end

		local ceilingPart = chunkClone.terrain:Clone()
		ceilingPart.Position = Vector3.new(x * state.terrainPartSize, ceilingY, z * state.terrainPartSize)
		ceilingPart.Name = 'ceilingPart'
		ceilingPart.Parent = chunkClone
	end

	return chunkClone
end

--Spawns missing chunks within render distance
local function makeChunks()
	if state.currentChunks == state.baseChunks then return end

	for x = state.centerPosX - state.renderDistance, state.centerPosX + state.renderDistance do
		task.wait()
		for z = state.centerPosZ - state.renderDistance, state.centerPosZ + state.renderDistance do
			if not doesChunkExist(x, z) then
				table.insert(state.chunks, createChunk(x, z))
				chunkWait()
				if state.currentChunks >= state.baseChunks then
					return
				end
			end
		end
	end
end

--Destroys chunks outside render distance
local function destroyChunks()
	local n = #state.chunks

	for i = 1, n do
		local chunk = state.chunks[i]
		if chunk == nil then
			state.chunks[i] = nil
			state.currentChunks -= 1
			continue
		end

		if isChunkOutOfRange(chunk) then
			state.chunks[i] = nil
			chunk:Destroy()
			state.currentChunks -= 1
			chunkWait()
		end
	end

	local j = 0
	for i = 1, n do
		if state.chunks[i] ~= nil then
			j += 1
			state.chunks[j] = state.chunks[i]
		end
	end
	for i = j + 1, n do
		state.chunks[i] = nil
	end
end

--Initialize
function chunkModule.init(config)
	local settings = config.settings

	state.worldSeed = config.worldSeed
	state.terrainPartSize = settings.terrainPartSize
	state.waterHeight = settings.waterHeight
	state.ceilingHeight = settings.ceilingHeight
	state.propData = config.propData
	state.propModule = config.propModule

	state.chunkModel = config.chunkModel
	state.chunkFolder = config.chunkFolder
	state.waterGridPartModel = config.waterGridPartModel
	state.waterChunkFolder = config.waterChunkFolder
	state.terrainPart = config.terrainPart
	state.HRP = config.HRP
	state.waterHeightOffset = config.waterHeightOffset
	state.halfTerrainHeight = config.terrainPart.Size.Y / 2

	state.renderDistance = math.floor(2000 / settings.terrainPartSize)
	state.baseChunks = (state.renderDistance * 2 + 1) ^ 2
	state.chunks = {}
	state.currentChunks = 0
	state.fastLoad = true

	--Noise params
	local rng = config.rng
	--Give random translation of noise so the world "starts" in a different place on the noise map
	state.originX = rng:NextInteger(-100000, 100000)
	state.originZ = rng:NextInteger(-100000, 100000)

	state.terrainScale = rng:NextInteger(1, 5000)
	state.terrainFrequency = rng:NextInteger(1, 1000)
	state.terrainAmplitude = rng:NextInteger(1, 500)

	config.chunkFolder.ChildAdded:Connect(function(chunk)
		if not table.find(state.chunks, chunk) then
			table.insert(state.chunks, chunk)
			state.currentChunks += 1
		end
	end)

	state.initialized = true
end

function chunkModule.getBaseChunks()
	return state.baseChunks
end

function chunkModule.isFastLoad()
	return state.fastLoad
end

--On call: "recenter", destroy far chunks, create missing ones
function chunkModule.update()
	updateCenterPos()
	destroyChunks()
	makeChunks()
	state.fastLoad = false
end

return chunkModule