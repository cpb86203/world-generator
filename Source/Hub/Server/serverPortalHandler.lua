--Server portal handling: create, close, and activate

--Services
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Events
local portalEvents = ReplicatedStorage:WaitForChild('portalEvents')
local callPortalRE = portalEvents:WaitForChild('callPortalRE')
local closePortalRE = portalEvents:WaitForChild('closePortalRE')
local activatePortalRE = portalEvents:WaitForChild('activatePortalRE')
local localTweenRE = ReplicatedStorage:WaitForChild('localTweenRE')

--Objects
local objects = ReplicatedStorage:WaitForChild('objects')
local portalModel = objects:WaitForChild('portalModel')
local pivotPartTemplate = objects:WaitForChild('pivotPart')
local portals = workspace:WaitForChild('portals')
local doorSFX = ReplicatedStorage:WaitForChild('sounds'):WaitForChild('doorSFX')

--Constants
local Y_OFFSET = -21 --Spawns the portal underground before tweening up
local MAX_32 = 2 ^ 32 - 1
local NUM_CAP = 2 ^ 31 - 1
local PLACE_ID = 98293391456708

local DOOR_PIVOT_OFFSET = 5.25
local DOOR_OPEN_ANGLE = -75
local REPLICATE_WAIT = 1
local TWEEN_SETTLE_WAIT = 1.1
local DOOR_OPEN_WAIT = 1
local DOOR_OPEN_SETTLE = 1.25
local CLOSE_DOOR_WAIT = 1
local ACTIVATE_TELEPORT_DELAY = 2
local ACTIVATE_CLEANUP_DELAY = 5
local DOOR_SFX_LIFETIME = 3

--HumanoidRootParts table for player detection within a portal
local HRPTable = {}

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		local HRP = char:WaitForChild('HumanoidRootPart')
		table.insert(HRPTable, HRP)
	end)

	plr.CharacterRemoving:Connect(function(char)
		local HRP = char:FindFirstChild('HumanoidRootPart')
		if HRP then
			local index = table.find(HRPTable, HRP)
			if index then
				table.remove(HRPTable, index)
			end
		end
	end)
end)

--Converts a string seed to a deterministic number
local function hashCode(str)
	if str == nil or str == '' then
		return math.random(1, NUM_CAP)
	end

	local val = 0
	local n = str:len()

	for i = 1, n do
		val = (val + str:byte(i) * (31 ^ (n - i))) % MAX_32
	end

	return val % NUM_CAP
end

--Plays door SFX
local function playDoorSFX(portal)
	local fakeDoor = portal:FindFirstChild('fakeDoor')
	if not fakeDoor then return end

	local doorSFXCLNE = doorSFX:Clone()
	doorSFXCLNE.Parent = fakeDoor
	doorSFXCLNE:Play()
	Debris:AddItem(doorSFXCLNE, DOOR_SFX_LIFETIME)
end

--Tweens the portal door shut for all clients
local function closePortalDoor(portal)
	local pivotPart = portal:FindFirstChild('pivotPart')
	if not pivotPart then return end

	playDoorSFX(portal)

	localTweenRE:FireAllClients(
		{ CFrame = CFrame.new(pivotPart.Position) * CFrame.Angles(0, 0, 0) },
		pivotPart,
		1,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	)
end

--Disables collision, tweens the portal underground, destroys it
local function closePortalAnim(portal: Model)
	for _, part in portal:GetDescendants() do
		if part:IsA('BasePart') then
			part.CanCollide = false
		end
	end

	local portalPrim = portal.PrimaryPart
	local door = portal:FindFirstChild('door')
	local fakeDoor = portal:FindFirstChild('fakeDoor')
	if not portalPrim then return end

	local portalCF = portalPrim.CFrame

	task.wait(CLOSE_DOOR_WAIT)

	if fakeDoor then fakeDoor.Transparency = 1 end
	if door then door.Transparency = 0 end

	portalCF += Vector3.new(0, Y_OFFSET, 0)
	localTweenRE:FireAllClients(
		{ CFrame = portalCF },
		portalPrim,
		1,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	)
	Debris:AddItem(portal, 1)
end

--Creates a portal, tweens it up, and opens the door
local function createPortal(plr, portalCF: CFrame, seed)
	local portal = portalModel:Clone()
	portal:PivotTo(portalCF + Vector3.new(0, Y_OFFSET, 0))
	portal.Name = plr.Name
	portal.Parent = portals

	local seedNum = tonumber(seed)
	if not seedNum or seed == '' then
		seedNum = hashCode(seed)
	end

	portal:SetAttribute('seed', seedNum)
	portal.textPart.SurfaceGui.TextLabel.Text = tostring(seedNum)

	task.wait(REPLICATE_WAIT)

	localTweenRE:FireAllClients(
		{ CFrame = portalCF },
		portal.PrimaryPart,
		1,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	)
	task.wait(TWEEN_SETTLE_WAIT)
	portal.PrimaryPart.CFrame = portalCF

	--Swap real door for a hinged fake door
	local portalDoor = portal.door
	local doorCF = portalDoor.CFrame

	local fakeDoor = portalDoor:Clone()
	fakeDoor.Name = 'fakeDoor'
	fakeDoor.CFrame = doorCF

	portalDoor.Transparency = 1
	portalDoor.CanCollide = false

	local pivotPart = pivotPartTemplate:Clone()
	pivotPart.Position = doorCF.Position + doorCF.RightVector * DOOR_PIVOT_OFFSET
	pivotPart.Parent = portal

	local openCF = pivotPart.CFrame * CFrame.Angles(0, math.rad(DOOR_OPEN_ANGLE), 0)

	local weld = Instance.new('WeldConstraint')
	weld.Part0 = pivotPart
	weld.Part1 = fakeDoor
	weld.Parent = pivotPart

	fakeDoor.Parent = portal

	task.wait(DOOR_OPEN_WAIT)
	playDoorSFX(portal)

	localTweenRE:FireAllClients(
		{ CFrame = openCF },
		pivotPart,
		1,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	)

	task.wait(DOOR_OPEN_SETTLE)
	pivotPart.CFrame = openCF
end

--Closes and removes the calling player's portal
local function closePortal(plr)
	local portal = portals:FindFirstChild(plr.Name)
	if not portal then return end

	closePortalDoor(portal)
	closePortalAnim(portal)
end

--Closes the door, teleports players inside the bounds, then removes the portal
local function activatePortal(plr)
	local portal = portals:FindFirstChild(plr.Name)
	if not portal then return end

	closePortalDoor(portal)

	local boundsPart = portal:FindFirstChild('boundsPart')
	if not boundsPart then return end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = HRPTable

	local partsInBounds = workspace:GetPartsInPart(boundsPart, overlapParams)

	if #partsInBounds > 0 then
		local plrTable = {}
		for _, HRP in partsInBounds do
			local character = HRP.Parent
			local targetPlr = Players:GetPlayerFromCharacter(character)
			if targetPlr then
				table.insert(plrTable, targetPlr)
			end
		end

		if #plrTable > 0 then
			local worldSeed = portal:GetAttribute('seed')

			local teleportOptions = Instance.new('TeleportOptions')
			teleportOptions.ShouldReserveServer = true
			teleportOptions:SetTeleportData({ Seed = worldSeed })

			task.wait(ACTIVATE_TELEPORT_DELAY)
			TeleportService:TeleportAsync(PLACE_ID, plrTable, teleportOptions)
		end
	end

	task.wait(ACTIVATE_CLEANUP_DELAY)
	closePortalAnim(portal)
end

--Listeners
callPortalRE.OnServerEvent:Connect(function(plr, portalCF, seed)
	createPortal(plr, portalCF, seed)
end)

closePortalRE.OnServerEvent:Connect(function(plr)
	closePortal(plr)
end)

activatePortalRE.OnServerEvent:Connect(function(plr)
	activatePortal(plr)
end)