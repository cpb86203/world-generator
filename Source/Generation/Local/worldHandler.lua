--Handles the creation of the world (determine attributes, call chunk creation)

--Services
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

--Player
local player = Players.LocalPlayer

--World seed
local WORLD_SEED
if not RunService:IsStudio() then
	local teleportData = TeleportService:GetLocalPlayerTeleportData()
	if not teleportData or not teleportData.Seed then
		player:Kick()
		return
	end
	WORLD_SEED = teleportData.Seed
else
	WORLD_SEED = math.random(1, 1000000000)
end

local rng = Random.new(WORLD_SEED)
player:SetAttribute('seed', WORLD_SEED)

--Modules
local modules = ReplicatedStorage:WaitForChild('modules')
local materialsModule = require(modules:WaitForChild('materialsModule'))
local dayCycleModule = require(modules.dayCycleModule)
local plrLoadModule = require(modules.plrLoadModule)
local weatherModule = require(ReplicatedStorage.modules.weatherModule)
local waterChunkModule = require(player.PlayerScripts:WaitForChild('oceanScripts'):WaitForChild('waterChunkModule'))

local generationModule = modules.generation
local worldSettingsModule = require(generationModule.worldSettingsModule)
local propModule = require(generationModule.propModule)
local chunkModule = require(generationModule.chunkModule)

--Objects
local char = player.Character or player.CharacterAdded:Wait()
local HRP = char:WaitForChild('HumanoidRootPart')

local waterGridPartModel = ReplicatedStorage:WaitForChild('objects'):WaitForChild('waterGridPartModel')
local waterGridPart = waterGridPartModel.waterGridPart
local chunkModel = ReplicatedStorage:WaitForChild('objects'):WaitForChild('chunkModel')
local terrainPart = chunkModel.terrain
local waterChunkFolder = workspace:WaitForChild('waterChunks')
local chunkFolder = workspace:WaitForChild('chunks')
local propFolder = ReplicatedStorage:WaitForChild('props')

--Constants
local WATER_HEIGHT_OFFSET = 5

--World settings
local settings = worldSettingsModule.generate(rng, {
	materialsModule = materialsModule,
	dayCycleModule = dayCycleModule,
	weatherModule = weatherModule,
	terrainPart = terrainPart,
	waterGridPart = waterGridPart,
	waterGridPartModel = waterGridPartModel,
	Lighting = Lighting,
	waterHeightOffset = WATER_HEIGHT_OFFSET,
})

--Get prop data
local propData = propModule.getPropData(rng, settings.material, propFolder, materialsModule)

--Init chunks
chunkModule.init({
	rng = rng,
	worldSeed = WORLD_SEED,
	settings = settings,
	propData = propData,
	propModule = propModule,
	chunkModel = chunkModel,
	chunkFolder = chunkFolder,
	waterGridPartModel = waterGridPartModel,
	waterChunkFolder = waterChunkFolder,
	terrainPart = terrainPart,
	HRP = HRP,
	waterHeightOffset = WATER_HEIGHT_OFFSET,
})

--Main
local function main()
	plrLoadModule:startLoad(chunkModule.getBaseChunks())

	local weatherApplied = false

	while true do
		chunkModule.update()
		waterChunkModule:updateWaterChunks()

		--Apply weather once after initial update
		if not weatherApplied then
			worldSettingsModule.applyWeather(rng, weatherModule, Lighting)
			weatherApplied = true
		end

		task.wait(0.5)
	end
end

main()