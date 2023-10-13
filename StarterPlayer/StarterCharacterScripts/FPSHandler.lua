-- // Services \\ --
Players = game:GetService('Players')
RunService = game:GetService('RunService')
GuiService = game:GetService('GuiService')
ReplicatedStorage = game:GetService('ReplicatedStorage')
UserInputService = game:GetService('UserInputService')


-- // Globals \\ --
local player: Player = Players.LocalPlayer
local character = script.Parent
local humanoid: Humanoid = character:WaitForChild('Humanoid')
local camera = workspace.CurrentCamera

local modules = ReplicatedStorage:WaitForChild('Modules')
local models = ReplicatedStorage:WaitForChild('Models')
local events = ReplicatedStorage:WaitForChild('Events')

local viewModels = models:WaitForChild('ViewModels')
local gunModels = models:WaitForChild('Guns')

local springModule = require(modules.SpringModule)
local FPSController = require(script:WaitForChild('FPSController'))


-- // Types \\ --
type ControllerEventBehavior = {
	requiresServerTranslation: boolean,
	continueAfterTranslation: boolean?
}

-- // Logic \\ --
local controller = FPSController.new(character, 'Default', { 'GLK' })


-- Mainly is going to handle client translations.
local switch = { }


controller.Event:Connect(function ( eventName: string, args: { any }, behaviors: ControllerEventBehavior? )
	if behaviors and behaviors.requiresServerTranslation then
		events.FPSControllerTranslator:FireServer(eventName, args)
		
		if behaviors.continueAfterTranslation == false then
			return
		end
	end
	
	
	local callback = switch[eventName]
	
	if callback then
		callback(unpack(args))
	end
end)


switch.ViewModelCreated = function ( activeGunName: string, guns: { string } )
	for i,v in guns do
		local tool = player.Backpack:FindFirstChild(v)
		if not tool then return end
		
		for si,sv in tool:GetDescendants() do
			if sv:IsA('MeshPart') or sv:IsA('Part') then
				sv.Transparency = 1
			end
		end
	end
end
