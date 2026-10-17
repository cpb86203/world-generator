--Positions props inside chunks

local propModule = {}

--Returns a random Color3
local function getRandomColor(rng)
	return Color3.fromRGB(
		rng:NextInteger(1, 255),
		rng:NextInteger(1, 255),
		rng:NextInteger(1, 255)
	)
end

--Applies color to a prop (random or based on foliage)
local function setPropColor(rng, prop, materialString, materialsModule)
	if rng:NextInteger(1, 25) == 1 or prop:GetAttribute('anyColor') then
		local newColor = getRandomColor(rng)
		for _, desc in prop:GetDescendants() do
			if desc:IsA('MeshPart') or desc:IsA('Part') then
				desc.Color = newColor
			end
		end
	else
		for _, desc in prop:GetDescendants() do
			if desc:GetAttribute('foliage') then
				desc.Color = materialsModule.materialColors[materialString]
			end
		end
	end
end

--Rarely assigns a random material to a prop
local function setPropMaterial(rng, prop, materialsModule)
	if rng:NextInteger(1, 25) == 1 then
		local allMaterials = materialsModule.materials
		for _, desc in prop:GetDescendants() do
			if desc:IsA('MeshPart') or desc:IsA('Part') then
				desc.Material = allMaterials[rng:NextInteger(1, #allMaterials)]
			end
		end
	end
end

--Scales a prop model (rarity-based)
local function setPropModelScale(rng, prop)
	local roll = rng:NextInteger(1, 15)
	local modelScale

	if roll == 1 then
		modelScale = rng:NextInteger(5, 50) / 100
	elseif roll == 2 then
		modelScale = rng:NextInteger(175, 1000) / 100
	elseif roll <= 5 then
		modelScale = rng:NextInteger(50, 175) / 100
	else
		modelScale = rng:NextInteger(75, 150) / 100
	end

	prop:ScaleTo(modelScale)
end

--Builds a list of props, uses noise for placement
function propModule.getPropData(rng, materialString, propFolder, materialsModule)
	local propTable = {}

	if rng:NextInteger(1, 15) == 1 or not propFolder:FindFirstChild(materialString) then
		local propPool = {}
		for _, desc in propFolder:GetDescendants() do
			if desc:IsA('Model') then
				table.insert(propPool, desc)
			end
		end
		table.sort(propPool, function(a, b)
			return b.Name > a.Name
		end)

		local densityRoll = rng:NextInteger(1, 100)
		local randomPropNum
		if densityRoll <= 10 then
			randomPropNum = rng:NextInteger(7, 10)
		elseif densityRoll <= 20 then
			randomPropNum = rng:NextInteger(4, 6)
		else
			randomPropNum = rng:NextInteger(0, 3)
		end

		for _ = 1, randomPropNum do
			table.insert(propTable, propPool[rng:NextInteger(1, #propPool)])
		end
	else
		local materialPropFolder = propFolder[materialString]
		local propPool = {}
		for _, desc in materialPropFolder:GetDescendants() do
			if desc:IsA('Model') then
				table.insert(propPool, desc)
			end
		end
		table.sort(propPool, function(a, b)
			return b.Name > a.Name
		end)

		local randomPropNum = rng:NextInteger(0, 3)
		for _ = 1, randomPropNum do
			table.insert(propTable, propPool[rng:NextInteger(1, #propPool)])
		end
	end

	local propDataTable = {}
	for _, prop in propTable do
		local randomScale = rng:NextInteger(5, 30)
		local randomFrequency = rng:NextInteger(2, 10)
		local randomAmplitude = rng:NextInteger(2, 20)

		setPropColor(rng, prop, materialString, materialsModule)
		setPropMaterial(rng, prop, materialsModule)
		setPropModelScale(rng, prop)

		table.insert(propDataTable, {prop, randomScale, randomFrequency, randomAmplitude})
	end

	return propDataTable
end

--Returns how many of given prop should spawn at chunk coordinates
function propModule.getPropCount(propEntry, x, z)
	local randomScale = propEntry[2]
	local randomFrequency = propEntry[3]
	local randomAmplitude = propEntry[4]

	local noise = math.noise(
		(x / randomScale) * randomFrequency,
		(z / randomScale) * randomFrequency
	)
	noise = math.clamp(noise, -1, 1)

	local propCount = math.round(noise * randomAmplitude)
	return math.clamp(propCount, 0, 9999)
end

--Spawns props inside a chunk at raycasted ground positions
function propModule.createProps(propEntry, x, z, chunkClone, propCount, worldSeed, terrainPartSize)
	if propCount == 0 then return end

	local propModel = propEntry[1]
	local propModelScale = propModel:GetScale()

	local noise = math.noise((x / 100) * 5, (z / 100) * 5) ^ 2 * 1000
	local worldX = x * terrainPartSize
	local worldZ = z * terrainPartSize

	local localRng = Random.new(math.floor(noise + worldSeed))

	for _ = 1, propCount do
		local randomX = localRng:NextInteger(worldX - terrainPartSize / 2, worldX + terrainPartSize / 2)
		local randomZ = localRng:NextInteger(worldZ - terrainPartSize / 2, worldZ + terrainPartSize / 2)

		local heightLimit = (localRng:NextInteger(1, 8) == 1) and localRng:NextInteger(100, 1000) or 1000
		local heightMinimum = (localRng:NextInteger(1, 8) == 1) and localRng:NextInteger(50, 1000) or 1000

		local rayResult = workspace:Raycast(
			Vector3.new(randomX, heightLimit, randomZ),
			Vector3.new(0, -heightMinimum * 2, 0)
		)

		if rayResult and rayResult.Instance.Name == 'terrain' then
			local randomRot = localRng:NextInteger(0, 360)
			local randomScaleOffset = localRng:NextInteger(80, 120) / 100

			local propCLNE = propModel:Clone()
			propCLNE:ScaleTo(propModelScale * randomScaleOffset)
			propCLNE:PivotTo(CFrame.new(rayResult.Position) * CFrame.Angles(0, math.rad(randomRot), 0))
			propCLNE.Parent = chunkClone
		end
	end
end

return propModule