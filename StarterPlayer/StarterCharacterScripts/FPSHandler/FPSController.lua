ReplicatedStorage = game:GetService('ReplicatedStorage')
UserInputService = game:GetService('UserInputService')
GUIService = game:GetService('GuiService')
RunService = game:GetService('RunService')
StarterPlayer = game:GetService('StarterPlayer')
TweenService = game:GetService('TweenService')

--  // Variables \\ --
local modules = ReplicatedStorage:WaitForChild('Modules')
local models = ReplicatedStorage:WaitForChild('Models')

local guns = models:WaitForChild('Guns')
local viewModels = models:WaitForChild('ViewModels')
local default: ViewModel = viewModels:WaitForChild('Default')

local SpringModule = require(modules.SpringModule)
local camera = workspace.CurrentCamera


-- // Internal Types \\ --

type Implementation = {
	__index: Implementation,
	new: ( character: Character, viewModelName: string, gunNames: { string } ) -> FPSController,    

	ProduceViewModel: ( self: FPSController, character: Character ) -> ViewModel,
	GetBobbing: ( self: FPSController, addition: number, speed: number, modifier: number ) -> number,
	HandleInput: ( self: FPSController, input: InputObject, processed: boolean ) -> nil,
	LoadAnimations: ( self: FPSController ) -> nil,
	Aim: ( self: FPSController, toggled: boolean ) -> nil,
	Lean: ( self: FPSController, leanDirection: string ) -> nil
}

type Prototype = {
	viewModel: ViewModel,
	mouseSway: any, movementSway: any, swayAmount: number,
	leanSpring: any,
	gunModels: { Model }, activeGun: Model,
	aiming: boolean, aimingCFrame: CFrame,
	humanoidRootPart: Part,
	humanoid: Humanoid, viewModelHumanoid: Humanoid,
	defaultWalkSpeed: number, adsWalkSpeed: number,
	debugArms: boolean,
	animations: { AnimationTrack }, animator: Animator,
	isLeaning: boolean, currentLeanDirection: ( 'Left' | 'Right' )?,
	currentLeanAngle: CFrameValue, leanTween: Tween?, leanDebounce: boolean,
	cameraOffsetTween: Tween?,
	Event: BindableEvent
}

-- // Exported Types \\ --
export type ViewModel = typeof( default )
export type Character = typeof( StarterPlayer:WaitForChild('StarterCharacter') )
export type FPSController = typeof( setmetatable( { } :: Prototype, { } :: Implementation ) )


-- // Custom Enumerations \\ --
enums = {
	LeanDirection = {
		Left = 'Left',
		Right = 'Right'
	}
}


-- // Non-Class Functions \\ --

--[[
    findPartWithName (local)
    
    @param list: { Instance }  The table you are searching in. 
    @param name: string  The name of the part you are searching for.
    @param partName: string  The name of the Instance you are searching for.
    @return Instance?
    
    Finds an Instance with a given name.
]]

local function findPartWithName ( list: { Instance }, partName: string ): Instance?
	for i,v in list do
		if v.Name == partName then
			return v
		end
	end

	return nil
end



-- // Main Logic \\ --

local FPSController: Implementation = { } :: Implementation
FPSController.__index = FPSController

--[[
    FPSController.new
    
    @param character: Character  The Player's Character.
    @param viewModelName: string  The name of the viewmodel to display.
    @param gunNames: { string }  The name of the guns to add to the ViewModel.
    @return FPSController
    
    Create a new FPS controller, initializing all values and connecting events.
]]

function FPSController.new ( character: Character, viewModelName: string, gunNames: { string } ): FPSController
	local self = setmetatable({ } :: Prototype, FPSController)

	self.gunModels = (function ()
		local tb = { }

		for i,v in gunNames do
			table.insert(tb, guns:WaitForChild(v):Clone())
		end

		return tb
	end)()

	UserInputService.MouseIconEnabled = false
	self.Event = script:WaitForChild('Event')
	
	self.activeGun = self.gunModels[1]

	self.humanoidRootPart = character:WaitForChild('HumanoidRootPart')
	self.humanoid = character:WaitForChild('Humanoid')

	self.defaultWalkSpeed, self.adsWalkSpeed = 12, 10
	self.humanoid.WalkSpeed = self.defaultWalkSpeed

	self.viewModel = self:ProduceViewModel(character, viewModelName, gunNames)

	self.mouseSway = SpringModule.new(Vector3.new())
	self.mouseSway.Speed, self.mouseSway.Damper  = 20, .5

	self.movementSway = SpringModule.new(Vector3.new())
	self.movementSway.Speed, self.movementSway.Damper = 20, .25

	self.aiming, self.aimingCFrame = false, CFrame.new()
	self.isLeaning, self.currentLeanDirection = false, nil
	self.currentLeanAngle = Instance.new('CFrameValue', script)

	self.debugArms = false

	
	RunService:BindToRenderStep('ViewModel', 301, function ( deltaTime: number )
		if self.debugArms then return end

		local mouseDelta = UserInputService:GetMouseDelta()
		self.mouseSway.Velocity += (Vector3.new(mouseDelta.X / 450, mouseDelta.Y / 450))

		self.swayAmount = Vector3.new(self:GetBobbing(10, 1, .7), self:GetBobbing(5, 1, .7), self:GetBobbing(5, 1, .7))
		self.movementSway.Velocity += ((self.swayAmount / 25) * deltaTime * 60 * self.humanoidRootPart.AssemblyLinearVelocity.Magnitude)

		if self.aiming then
			self.aimingCFrame = self.aimingCFrame:Lerp(self.activeGun.aimPart.CFrame:ToObjectSpace(self.viewModel.PrimaryPart.CFrame), .2)
		else
			self.aimingCFrame = self.aimingCFrame:Lerp(CFrame.new(), .04)
		end
		
		
		camera.CFrame *= CFrame.fromOrientation(self.currentLeanAngle.Value.X, self.currentLeanAngle.Value.Y, self.currentLeanAngle.Value.Z * .9)


		if not self.aiming then 
			self.viewModel:PivotTo(
				camera.CFrame * self.currentLeanAngle.Value
					* CFrame.Angles(self.movementSway.Position.X / 2, self.movementSway.Position.Y / 2, 0)
					* self.aimingCFrame
					* CFrame.Angles(0, -self.mouseSway.Position.X, self.mouseSway.Position.Y * 1.5)
					* CFrame.new(0, self.movementSway.Position.Y, self.movementSway.Position.X)
			)
		else
			self.viewModel:PivotTo(
				camera.CFrame * self.currentLeanAngle.Value
					* self.aimingCFrame
					* CFrame.Angles(0, -self.mouseSway.Position.X, self.mouseSway.Position.Y * 1.5)

			)
		end
	end)

	UserInputService.InputBegan:Connect(function ( input: InputObject, processed: boolean ) self:HandleInput(input, processed) end)
	UserInputService.InputEnded:Connect(function ( input: InputObject, processed: boolean ) self:HandleInput(input, processed) end)
end



--[[ 
    FPSController:GetBobbing
    
    @param addition: number  The addition to the time.
    @param speed: number  The speed at which to bob.
    @param modifier: number  The number at which to multiply the result at.
    @return number The product of the formula.
    
    Calculate movement bobbing using sine.
]]

function FPSController:GetBobbing ( addition: number, speed: number, modifier: number ): number
	return math.sin(time() * addition * speed) * modifier
end



--[[
    FPSController:ProduceViewModel
    
    @param character: Character  The player's character. 
    @param viewModelName: string  The name of the viewmodel to display.
    @param gunNames: { string }  The name of the guns to add to the ViewModel.
    @return ViewModel
    
    Create a new ViewModel, parenting it to the character and adding all necessary parts.
]]

function FPSController:ProduceViewModel ( character: Character, viewModelname: string, gunNames: { string } ): ViewModel
	-- Set Player.Character.Archivable to true because it cannot be cloned if it is not Archiveable.
	character.Archivable = true
	local newCharacter = character:Clone()


	local newViewModel = Instance.new('Model')


	local primary = default:WaitForChild('Primary'):Clone()
	primary.Parent = newViewModel
	primary.CFrame = default:WaitForChild('Primary').CFrame
	newViewModel.PrimaryPart = primary


	-- Define all the ViewModel parts.
	local parts = {
		newCharacter:WaitForChild('LeftUpperArm'),
		newCharacter:WaitForChild('LeftLowerArm'),
		newCharacter:WaitForChild('LeftHand'),
		newCharacter:WaitForChild('RightUpperArm'),
		newCharacter:WaitForChild('RightLowerArm'),
		newCharacter:WaitForChild('RightHand'),
		primary
	}


	default:WaitForChild('Humanoid'):Clone().Parent = newViewModel


	-- Clone over the shirt if it exists.
	local shirt: Shirt? = newCharacter:FindFirstChildOfClass('Shirt')
	if shirt then
		shirt:Clone().Parent = newViewModel
	end


    --[[ 
        Move parts that should be in the view model from the character clone to the view model 
        Destroys Motor6Ds in that part then sets properties it should have based on the default model's parts' properties.
    ]]

	for i,v in parts do
		v.Parent = newViewModel
		v.Size = default:FindFirstChild(v.Name).Size

		for si,sv in v:GetChildren() do
			if sv:IsA('Motor6D') then
				sv:Destroy()
			end
		end

		v.CFrame = default:FindFirstChild(v.Name).CFrame
	end




	-- Loops through default preset Motor6Ds and clones them then sets them to what they should be within the new view model.
	for i,v in default:GetDescendants() do
		if not v:IsA('Motor6D') then
			continue
		end

		local motor6d: Motor6D = v:Clone()

		motor6d.Parent = findPartWithName(parts, motor6d.Part0.Name)
		motor6d.Part0 = motor6d.Parent
		motor6d.Part1 = findPartWithName(newViewModel:GetChildren(), motor6d.Name)
	end

	-- Configures the Motor6Ds within the primary part.
	primary:WaitForChild('LeftUpperArm').Part1 = newViewModel:WaitForChild('LeftUpperArm')
	primary:WaitForChild('RightUpperArm').Part1 = newViewModel:WaitForChild('RightUpperArm')
	newCharacter:Destroy()


	-- Loops through GunModels and welds them to the primary part using Motor6Ds.
	for i,v in self.gunModels do
		v.Parent = newViewModel

		local joint = Instance.new('Motor6D', v.Handle)

		joint.Part0 = newViewModel.PrimaryPart
		joint.Part1 = v.Handle
		joint.C1 = CFrame.new(0, .2, .2)
	end


	self.viewModel = newViewModel
	self.viewModel.Parent = camera

	self.viewModelHumanoid = self.viewModel:WaitForChild('Humanoid')
	self.animator = self.viewModelHumanoid:WaitForChild('Animator')


	self:LoadAnimations()
	self.animations.idle:Play()
	
	self.Event:Fire('ViewModelCreated', { 
		self.activeGun.Name, 
		
		(function ( )
			local collection = { }
			
			for i,v in self.gunModels do
				table.insert(collection, v.Name)
			end
			
			return collection
		end)()
	})
	
	
	return newViewModel
end



--[[
    FPSController:LoadAnimations
    
    @return nil
    
    Loads all animations related to the gun.
]]

function FPSController:LoadAnimations ( ): nil
	self.animations = { 
		idle = self.animator:LoadAnimation(self.activeGun.Handle.Animations.Idle)
	}
end



--[[
    FPSController:HandleInput
    
    @param input: InputObject  The input object provided by the UserInputService event.
    @param processed: boolean  If the input was processed by Roblox for whatever reason. Eg: Being an interaction with Roblox CoreGUI.
    @return nil
    
    Handles a UserInputService event.
]]

function FPSController:HandleInput ( input: InputObject, processed: boolean ): nil
	if (not ( input.UserInputState == Enum.UserInputState.Begin or input.UserInputState == Enum.UserInputState.End )) or processed then
		return
	end


	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		self:Aim(input.UserInputState == Enum.UserInputState.Begin)
	elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.F then
		self.debugArms = not self.debugArms
	elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Q then
		if input.UserInputState == Enum.UserInputState.End then return end

		self:Lean(enums.LeanDirection.Left)
	elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.E then
		if input.UserInputState == Enum.UserInputState.End then return end

		self:Lean(enums.LeanDirection.Right)
	end
end



--[[
    FPSController:Aim
    
    @param toggled: boolean  Whether to aim down sight or not.
    @return nil
    
    Toggles ADS.
]]

function FPSController:Aim ( toggled: boolean ): nil
	self.aiming = toggled

	if self.aiming then
		self.humanoid.WalkSpeed = self.adsWalkSpeed

		-- Add something that prevents walk bobbing.
	else
		self.humanoid.WalkSpeed = self.defaultWalkSpeed
	end
end



--[[
    FPSController:Lean
    
    @param leanDirection: string  Which direction to lean in.
    @return nil
    
    Leans in a given direction.
]]

function FPSController:Lean ( leanDirection: string ): nil
	if self.leanDebounce then 
		if self.leanTween then
			self.leanTween:Cancel()
		end
		
		if self.cameraOffsetTween then
			self.cameraOffsetTween:Cancel()
		end
	end
	
	self.leanDebounce = true
	
	
	if leanDirection == enums.LeanDirection.Left and self.currentLeanDirection == leanDirection then
		self.currentLeanDirection = nil
		
		self.leanTween = TweenService:Create(
			self.currentLeanAngle,
			TweenInfo.new(.3),
			{
				Value = CFrame.fromOrientation(0, 0, 0)
			}
		)

		self.leanTween:Play()

		self.leanTween.Completed:Once(function()
			self.leanTween:Destroy()

			self.leanDebounce = false
			self.leanTween = nil
		end)
		
		self.cameraOffsetTween = TweenService:Create(
			self.humanoid,
			TweenInfo.new(.3),
			{
				CameraOffset = Vector3.new()
			}
		)
		
		self.cameraOffsetTween.Completed:Once(function()
			self.cameraOffsetTween:Destroy()
			self.cameraOffsetTween = nil
		end)
		
		self.cameraOffsetTween:Play()
		
	elseif leanDirection == enums.LeanDirection.Right and self.currentLeanDirection == leanDirection then
		self.currentLeanDirection = nil
		
		self.leanTween = TweenService:Create(
			self.currentLeanAngle,
			TweenInfo.new(.3),
			{
				Value = CFrame.fromOrientation(0, 0, 0)
			}
		)

		self.leanTween.Completed:Once(function()
			self.leanTween:Destroy()

			self.leanDebounce = false
			self.leanTween = nil
		end)
		
		self.leanTween:Play()
		
		
		self.cameraOffsetTween = TweenService:Create(
			self.humanoid,
			TweenInfo.new(.3),
			{
				CameraOffset = Vector3.new()
			}
		)

		self.cameraOffsetTween.Completed:Once(function()
			self.cameraOffsetTween:Destroy()
			self.cameraOffsetTween = nil
		end)

		self.cameraOffsetTween:Play()
	else
		self.currentLeanDirection = leanDirection
		
		local endAngle: CFrame = (function()
			local a = CFrame.new(0, 0, 0)
			
			if self.currentLeanDirection == enums.LeanDirection.Left then
				a = CFrame.fromOrientation(0, 0, math.rad(18))
			elseif self.currentLeanDirection == enums.LeanDirection.Right then
				a = CFrame.fromOrientation(0, 0, math.rad(-18))
			end
			
			return a
		end)()
		
		self.leanTween = TweenService:Create(
			self.currentLeanAngle,
			TweenInfo.new(.45),
			{
				Value = endAngle
			}
		)
		
		
		self.leanTween:Play()
		
		self.leanTween.Completed:Once(function()
			self.leanTween:Destroy()
			
			self.leanDebounce = false
			self.leanTween = nil
		end)
		
		
		self.cameraOffsetTween = TweenService:Create(
			self.humanoid,
			TweenInfo.new(.45),
			{
				CameraOffset = if self.currentLeanDirection == enums.LeanDirection.Left then Vector3.new(-1.5) else Vector3.new(1.5)
			}
		)

		self.cameraOffsetTween.Completed:Once(function()
			self.cameraOffsetTween:Destroy()
			self.cameraOffsetTween = nil
		end)

		self.cameraOffsetTween:Play()
	end
end



return FPSController
