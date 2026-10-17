--Generates  world settings (terrain, sky, water, weather)

local worldSettingsModule = {}

--Returns a random Color3
local function getRandomColor(rng)
	return Color3.fromRGB(
		rng:NextInteger(1, 255),
		rng:NextInteger(1, 255),
		rng:NextInteger(1, 255)
	)
end

--Picks a random terrain chunk size (rarity-based)
local function getTerrainSize(rng)
	local roll = rng:NextInteger(1, 10)
	if roll == 1 then
		if rng:NextInteger(1, 2) == 1 then
			return rng:NextInteger(150, 600)
		end
		return rng:NextInteger(75, 90)
	end
	return rng:NextInteger(90, 150)
end

--Selects a walking material (mostly defaults, rarely any material)
local function getTerrainMaterial(rng, materialsModule, terrainPart)
	local defaultMaterials = {'Grass', 'Snow', 'Sand', 'LeafyGrass'}
	local allMaterials = materialsModule.materials
	local material

	if rng:NextInteger(1, 8) == 1 then
		material = allMaterials[rng:NextInteger(1, #allMaterials)]
	else
		material = defaultMaterials[rng:NextInteger(1, #defaultMaterials)]
	end

	terrainPart:SetAttribute('walkingMaterial', material)
	return material
end

--Picks terrain color (usually default, rarely random)
local function getTerrainColor(rng, materialsModule, materialString)
	if rng:NextInteger(1, 12) == 1 then
		return getRandomColor(rng)
	end
	return materialsModule.materialColors[materialString]
end

--Sets day/night cycle speed and current time
local function setDayCycle(rng, dayCycleModule, Lighting)
	local randomMPS
	local roll = rng:NextInteger(1, 50)

	if roll == 1 then
		randomMPS = rng:NextInteger(300, 20000) / 10
	elseif roll == 2 then
		randomMPS = 0
	elseif roll <= 6 then
		randomMPS = rng:NextInteger(50, 300) / 10
	else
		randomMPS = rng:NextInteger(10, 50) / 10
	end

	Lighting.ClockTime = rng:NextInteger(1, 240) / 10
	dayCycleModule:setCycle(randomMPS)
end

--Rarely sets the terrain part shape to a ball
local function setTerrainShape(rng, terrainPart)
	if rng:NextInteger(1, 200) == 1 then
		terrainPart.Shape = Enum.PartType.Ball
	end
end

--Rarely applies dense atmosphere
local function setHaze(rng, Lighting)
	local atmosphere = Lighting:WaitForChild('Atmosphere')

	if rng:NextInteger(1, 10) == 1 then
		atmosphere.Color = getRandomColor(rng)
		atmosphere.Haze = 10

		if rng:NextInteger(1, 10) == 1 then
			atmosphere.Density = rng:NextInteger(500, 750) / 1000
		else
			atmosphere.Density = rng:NextInteger(325, 500) / 1000
		end
	end
end

--Randomizes moon/sun size, star count, and cloud settings
local function setSky(rng, Lighting)
	local sky = Lighting.Sky
	local clouds = workspace.Terrain.Clouds

	local moonRoll = rng:NextInteger(1, 15)
	if moonRoll == 1 then
		sky.MoonAngularSize = rng:NextInteger(15, 60)
	elseif moonRoll == 2 then
		sky.MoonAngularSize = rng:NextInteger(1, 8)
	else
		sky.MoonAngularSize = rng:NextInteger(8, 15)
	end

	local sunRoll = rng:NextInteger(1, 15)
	if sunRoll == 1 then
		sky.SunAngularSize = rng:NextInteger(15, 60)
	elseif sunRoll == 2 then
		sky.SunAngularSize = rng:NextInteger(1, 8)
	else
		sky.SunAngularSize = rng:NextInteger(8, 15)
	end

	local starRoll = rng:NextInteger(1, 15)
	if starRoll == 1 then
		sky.StarCount = rng:NextInteger(3500, 5000)
	elseif starRoll == 2 then
		sky.StarCount = rng:NextInteger(0, 2500)
	else
		sky.StarCount = rng:NextInteger(2500, 3500)
	end

	clouds.Enabled = true
	clouds.Density = rng:NextInteger(0, 100) / 100
	clouds.Cover = rng:NextInteger(0, 100) / 100

	if rng:NextInteger(1, 5) == 1 then
		clouds.Color = getRandomColor(rng)
	end
end

--Sets lighting brightness
local function setBrightness(rng, Lighting)
	local roll = rng:NextInteger(1, 12)

	if roll == 1 then
		Lighting.Brightness = rng:NextInteger(0, 20) / 10
	elseif roll == 2 then
		Lighting.Brightness = rng:NextInteger(40, 60) / 10
	else
		Lighting.Brightness = rng:NextInteger(20, 40) / 10
	end
end

--Decides if water exists and what height/color
local function setWater(rng, waterGridPart, Lighting, waterHeightOffset)
	local waterHeight

	if rng:NextInteger(1, 4) == 1 then
		if rng:NextInteger(1, 5) == 1 then
			waterHeight = rng:NextInteger(200, 300)
		else
			waterHeight = rng:NextInteger(100, 200)
		end

		if rng:NextInteger(1, 3) == 1 then
			local waterColor = getRandomColor(rng)
			waterGridPart.Color = waterColor
			Lighting.underwaterColorCorrection.TintColor = waterColor
		end

		workspace:SetAttribute('waterHeight', waterHeight - waterHeightOffset)
	else
		waterHeight = false
		workspace:SetAttribute('waterHeight', false)
	end

	return waterHeight
end

--Rarely returns a ceiling height (cave-like generation)
local function getCeilingHeight(rng)
	if rng:NextInteger(1, 25) == 1 then
		return rng:NextInteger(150, 300)
	end
	return nil
end

--Rarely enables rain, snow, or storm
local function setWeather(rng, weatherModule, Lighting)
	if rng:NextInteger(1, 4) ~= 1 then return end

	local atmosphere = Lighting.Atmosphere
	local clouds = workspace.Terrain.Clouds

	clouds.Enabled = true
	clouds.Cover = rng:NextInteger(80, 100) / 100

	local weatherString
	local emitterColor
	local lightningColor
	local stormStrength

	local weatherRoll = rng:NextInteger(1, 3)
	if weatherRoll == 1 then
		weatherString = 'rain'
		atmosphere.Density = 0.4
		atmosphere.Haze = 4
	elseif weatherRoll == 2 then
		weatherString = 'snow'
	else
		weatherString = 'storm'
		atmosphere.Density = 0.5
		atmosphere.Haze = 4

		if rng:NextInteger(1, 3) == 1 then
			lightningColor = getRandomColor(rng)
		end

		if rng:NextInteger(1, 5) == 1 then
			stormStrength = rng:NextInteger(5, 15)
		else
			stormStrength = rng:NextInteger(8, 12) / 10
		end
	end

	if rng:NextInteger(1, 3) == 1 then
		emitterColor = getRandomColor(rng)
	end

	weatherModule:setWeather(weatherString, emitterColor, lightningColor, stormStrength)
end

--Scales water and all of its bones proportionally (due to randomized chunk size)
local function resizeBonedMesh(scaleVector3, meshPart)
	for _, descendant in meshPart:GetDescendants() do
		if descendant:IsA('Bone') then
			local bone = descendant
			local parentCFrame
			if bone.Parent:IsA('Bone') then
				parentCFrame = bone.Parent.WorldCFrame
			else
				parentCFrame = bone.Parent.CFrame
			end

			local parentInPartCFrame = meshPart.CFrame:Inverse() * parentCFrame
			local parentInPartRotationCFrame = parentInPartCFrame - parentInPartCFrame.Position
			local pivotOffsetInPartSpace = parentInPartRotationCFrame * bone.Position
			local scaledPivotOffsetInPartSpace = pivotOffsetInPartSpace * scaleVector3
			local partToParentRotationCFrame = parentInPartRotationCFrame:Inverse()
			bone.Position = partToParentRotationCFrame * scaledPivotOffsetInPartSpace
		end
	end

	meshPart.Size *= scaleVector3
end

--Generates world settings
function worldSettingsModule.generate(rng, deps)
	local terrainPartSize = getTerrainSize(rng)
	local material = getTerrainMaterial(rng, deps.materialsModule, deps.terrainPart)

	deps.terrainPart.Material = Enum.Material[material]
	deps.terrainPart.Color = getTerrainColor(rng, deps.materialsModule, material)
	deps.terrainPart.Size = Vector3.new(terrainPartSize, deps.terrainPart.Size.Y, terrainPartSize)

	resizeBonedMesh(
		Vector3.new(terrainPartSize / 100, 1, terrainPartSize / 100),
		deps.waterGridPart
	)
	deps.waterGridPart.Texture.StudsPerTileU = terrainPartSize
	deps.waterGridPart.Texture.StudsPerTileV = terrainPartSize
	deps.waterGridPartModel.rayDetector.Size = Vector3.new(terrainPartSize, terrainPartSize, 20)

	setDayCycle(rng, deps.dayCycleModule, deps.Lighting)
	setTerrainShape(rng, deps.terrainPart)
	setHaze(rng, deps.Lighting)
	setSky(rng, deps.Lighting)
	setBrightness(rng, deps.Lighting)

	local waterHeight = setWater(rng, deps.waterGridPart, deps.Lighting, deps.waterHeightOffset)
	local ceilingHeight = getCeilingHeight(rng)

	return {
		terrainPartSize = terrainPartSize,
		material = material,
		waterHeight = waterHeight,
		ceilingHeight = ceilingHeight,
	}
end

--Applies weather after the initial fast-load finishes
function worldSettingsModule.applyWeather(rng, weatherModule, Lighting)
	setWeather(rng, weatherModule, Lighting)
end

return worldSettingsModule