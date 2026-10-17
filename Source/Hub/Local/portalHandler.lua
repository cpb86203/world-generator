--Handles the portal GUI: calling, closing, and activating portals

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Player
local plr = Players.LocalPlayer

--GUI
local portalGUI = plr.PlayerGui:WaitForChild('portalGUI')
local frame = portalGUI:WaitForChild('Frame')
local textBox = frame:WaitForChild('textFrame'):WaitForChild('textBox')
local callButton = frame:WaitForChild('callButton')
local closeButton = frame:WaitForChild('closeButton')
local activateButton = frame:WaitForChild('activateButton')

--Events
local portalEvents = ReplicatedStorage:WaitForChild('portalEvents')
local callPortalRE = portalEvents:WaitForChild('callPortalRE')
local closePortalRE = portalEvents:WaitForChild('closePortalRE')
local activatePortalRE = portalEvents:WaitForChild('activatePortalRE')

--Objects
local portalsFolder = workspace:WaitForChild('portals')
local portalBoundsPart = ReplicatedStorage:WaitForChild('objects'):WaitForChild('portalBoundsPart')

--Constants
local DEFAULT_TEXT_COLOR = Color3.fromRGB(183, 255, 183)
local ERROR_TEXT_COLOR = Color3.fromRGB(255, 136, 120)
local ACTIVE_COLOR = Color3.fromRGB(151, 255, 128)
local INACTIVE_COLOR = Color3.fromRGB(255, 144, 144)

local PORTAL_SPAWN_DISTANCE = 15
local PORTAL_BOUNDS_Y_OFFSET = 10
local CALL_CLOSE_DEBOUNCE = 4.5
local ACTIVATE_DEBOUNCE = 10
local FLASH_COUNT = 3
local FLASH_INTERVAL = 0.1

--State
local callPortalDebounce = false
local closePortalDebounce = false
local activatePortalDebounce = false

local portalBoundsParams = OverlapParams.new()
portalBoundsParams.FilterType = Enum.RaycastFilterType.Include

--Stops all portal actions during debounce
local function setAllDebounces(locked)
	callPortalDebounce = locked
	closePortalDebounce = locked
	activatePortalDebounce = locked
end

--Flashes call button to show invalid portal position
local function flashButtonRoutine()
	for _ = 1, FLASH_COUNT do
		callButton.TextColor3 = ERROR_TEXT_COLOR
		task.wait(FLASH_INTERVAL)
		callButton.TextColor3 = DEFAULT_TEXT_COLOR
		task.wait(FLASH_INTERVAL)
	end
end

--Returns portal parts in a location (really just checking for potential overlap)
local function getPortalsInBounds(portalCF)
	local boundsCF = portalCF + Vector3.new(0, PORTAL_BOUNDS_Y_OFFSET, 0)

	local portalBoundsPartCLNE = portalBoundsPart:Clone()
	portalBoundsPartCLNE.CFrame = boundsCF * CFrame.Angles(0, 0, math.rad(90))
	portalBoundsPartCLNE.Parent = workspace.temp

	portalBoundsParams.FilterDescendantsInstances = portalsFolder:GetChildren()
	local partsTable = workspace:GetPartsInPart(portalBoundsPartCLNE, portalBoundsParams)

	portalBoundsPartCLNE:Destroy()
	return partsTable
end

--Requests a new portal in front of the player, or flashes the button if the space is occupied
local function callPortal()
	local char = plr.Character
	if not char then return end

	local HRP = char:FindFirstChild('HumanoidRootPart')
	if not HRP then return end
	if callPortalDebounce then return end

	setAllDebounces(true)
	activateButton.BackgroundColor3 = INACTIVE_COLOR
	closePortalRE:FireServer()

	local HRPCf = HRP.CFrame
	local lookVector = HRPCf.LookVector
	local newPos = Vector3.new(HRPCf.X, 0, HRPCf.Z) + lookVector * PORTAL_SPAWN_DISTANCE
	local portalCF = CFrame.new(newPos, newPos - lookVector)

	if #getPortalsInBounds(portalCF) ~= 0 then
		task.spawn(flashButtonRoutine)
		task.wait(CALL_CLOSE_DEBOUNCE)
		setAllDebounces(false)
		return
	end

	callPortalRE:FireServer(portalCF, textBox.Text)

	task.wait(CALL_CLOSE_DEBOUNCE)
	setAllDebounces(false)
	activateButton.BackgroundColor3 = ACTIVE_COLOR
end

--Requests server to close the portal
local function closePortal()
	if closePortalDebounce then return end

	setAllDebounces(true)
	activateButton.BackgroundColor3 = INACTIVE_COLOR
	closePortalRE:FireServer()

	task.wait(CALL_CLOSE_DEBOUNCE)
	setAllDebounces(false)
end

--Requests server to activate the portal
local function activatePortal()
	if activatePortalDebounce then return end

	setAllDebounces(true)
	activatePortalRE:FireServer()
	activateButton.BackgroundColor3 = INACTIVE_COLOR

	task.wait(ACTIVATE_DEBOUNCE)
	setAllDebounces(false)
end

--Listeners
callButton.Activated:Connect(callPortal)
closeButton.Activated:Connect(closePortal)
activateButton.Activated:Connect(activatePortal)