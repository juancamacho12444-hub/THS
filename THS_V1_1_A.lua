--//====================================================
--// THS - Tactical Hitbox System V1.1-A
--// Sistema de Hitbox Táctica
--// LocalScript en StarterPlayer > StarterPlayerScripts
--// Proyecto 2/3 - Base inicial
--//====================================================

--[[
	IMPORTANTE:
	Este sistema está pensado para TUS PROPIOS juegos de Roblox Studio.
	Esta V1.1-A crea hitboxes auxiliares globales o por partes que siguen al objetivo,
	SIN modificar HumanoidRootPart ni partes reales del personaje.

	Ventajas:
	- No deforma rigs.
	- No rompe vehículos/asientos.
	- No cambia físicas del personaje.
	- Se limpia por completo al desactivar o cerrar.

	Para daño real en tu juego, más adelante haremos una versión server-side
	que valide disparos/impactos de forma segura.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local THS = {}

--//====================================================
--// CONFIG
--//====================================================

THS.Config = {
	SystemEnabled = false,
	MenuOpen = false,
	HitboxEnabled = false,

	-- Objetivos
	ShowPlayers = true,
	ShowNPCs = false,
	TeamCheck = false,

	-- Hitbox auxiliar
	HitboxMode = "Global", -- "Global" o "Partes"
	HitboxSize = 8,
	HitboxTransparency = 0.65,
	HitboxColor = Color3.fromRGB(0, 220, 255),

	-- Hitbox por partes
	UseHeadHitbox = true,
	UseTorsoHitbox = true,
	UseArmsHitbox = false,
	UseLegsHitbox = false,
	HeadHitboxSize = 5,
	TorsoHitboxSize = 7,
	ArmsHitboxSize = 4,
	LegsHitboxSize = 4,
	UseTeamColor = false,

	-- Rendimiento
	UpdateRate = 0.05,
	NPCCacheRate = 2,
	MaxTargets = 50,

	-- UI
	MenuKey = Enum.KeyCode.RightShift,
	ToggleKey = Enum.KeyCode.H,
}

THS.Runtime = {
	LastUpdate = 0,
	LastNPCCache = 0,
	Hitboxes = {},
	NPCs = {},
	Connections = {},
	DetectedTargets = 0,
	CurrentPage = "Inicio",
	IsShuttingDown = false,
	UnsavedChanges = false,
}

local Themes = {
	Default = {
		Background = Color3.fromRGB(12, 14, 18),
		Panel = Color3.fromRGB(20, 24, 31),
		PanelLight = Color3.fromRGB(30, 36, 46),
		Accent = Color3.fromRGB(0, 145, 255),
		AccentLight = Color3.fromRGB(0, 220, 255),
		Text = Color3.fromRGB(240, 245, 255),
		MutedText = Color3.fromRGB(165, 175, 190),
		Green = Color3.fromRGB(90, 255, 150),
		Red = Color3.fromRGB(255, 90, 90),
		DarkDot = Color3.fromRGB(8, 9, 12),
	}
}

local Theme = Themes.Default

--//====================================================
--// UTILIDADES
--//====================================================

local function create(className, props, parent)
	local obj = Instance.new(className)

	for prop, value in pairs(props or {}) do
		obj[prop] = value
	end

	obj.Parent = parent
	return obj
end

local function connect(signal, fn)
	local connection = signal:Connect(fn)
	table.insert(THS.Runtime.Connections, connection)
	return connection
end

local function clampNumber(value, minValue, maxValue)
	local number = tonumber(value)
	if not number then
		return minValue
	end
	return math.clamp(number, minValue, maxValue)
end

local function extractNumber(text, fallback)
	if typeof(text) == "number" then
		return text
	end

	local value = tostring(text or ""):match("[-+]?%d*%.?%d+")
	return tonumber(value) or fallback
end

local function getDeviceType()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Móvil"
	end

	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Consola"
	end

	return "PC"
end

local function getCharacterData(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end

	return {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Head = head or root,
		Name = model.Name,
		Type = "NPC",
		Player = nil,
		Team = nil,
	}
end

local function getTargetColor(target)
	if THS.Config.UseTeamColor and target.Player and target.Player.TeamColor then
		return target.Player.TeamColor.Color
	end

	return THS.Config.HitboxColor
end

local function findBodyPart(model, names)
	for _, name in ipairs(names) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function getBodyPartGroups(model)
	local groups = {
		Head = {},
		Torso = {},
		Arms = {},
		Legs = {},
	}

	local head = findBodyPart(model, { "Head" })
	if head then table.insert(groups.Head, head) end

	for _, name in ipairs({ "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(groups.Torso, part)
		end
	end

	for _, name in ipairs({
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"Left Arm", "Right Arm",
	}) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(groups.Arms, part)
		end
	end

	for _, name in ipairs({
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot",
		"Left Leg", "Right Leg",
	}) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(groups.Legs, part)
		end
	end

	return groups
end

local function getGroupSize(config, groupName)
	if groupName == "Head" then
		return config.HeadHitboxSize
	elseif groupName == "Torso" then
		return config.TorsoHitboxSize
	elseif groupName == "Arms" then
		return config.ArmsHitboxSize
	elseif groupName == "Legs" then
		return config.LegsHitboxSize
	end

	return config.HitboxSize
end

local function isGroupEnabled(config, groupName)
	if groupName == "Head" then
		return config.UseHeadHitbox
	elseif groupName == "Torso" then
		return config.UseTorsoHitbox
	elseif groupName == "Arms" then
		return config.UseArmsHitbox
	elseif groupName == "Legs" then
		return config.UseLegsHitbox
	end

	return false
end

--//====================================================
--// TARGET ENGINE INICIAL
--//====================================================

function THS:RefreshNPCCache()
	local now = os.clock()

	if now - self.Runtime.LastNPCCache < self.Config.NPCCacheRate then
		return
	end

	self.Runtime.LastNPCCache = now
	table.clear(self.Runtime.NPCs)

	for _, item in ipairs(workspace:GetDescendants()) do
		if item:IsA("Model") and not Players:GetPlayerFromCharacter(item) then
			local data = getCharacterData(item)
			if data then
				table.insert(self.Runtime.NPCs, data)
			end
		end
	end
end

function THS:GetTargets()
	local targets = {}

	if self.Config.ShowPlayers then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local data = getCharacterData(player.Character)

				if data then
					data.Type = "Player"
					data.Player = player
					data.Team = player.Team
					data.Name = player.Name

					if not self.Config.TeamCheck or player.Team ~= LocalPlayer.Team then
						table.insert(targets, data)
					end
				end
			end
		end
	end

	if self.Config.ShowNPCs then
		self:RefreshNPCCache()

		for _, data in ipairs(self.Runtime.NPCs) do
			if data.Model and data.Model.Parent and data.Humanoid and data.Humanoid.Health > 0 then
				table.insert(targets, data)
			end
		end
	end

	if #targets > self.Config.MaxTargets then
		local limited = {}
		for i = 1, self.Config.MaxTargets do
			limited[i] = targets[i]
		end
		targets = limited
	end

	self.Runtime.DetectedTargets = #targets
	return targets
end

--//====================================================
--// HITBOX ENGINE
--//====================================================

function THS:GetRuntimeFolder()
	if self.RuntimeFolder and self.RuntimeFolder.Parent then
		return self.RuntimeFolder
	end

	self.RuntimeFolder = create("Folder", {
		Name = "THS_Runtime"
	}, workspace)

	return self.RuntimeFolder
end

function THS:CreateHitbox(target)
	local folder = self:GetRuntimeFolder()

	local part = create("Part", {
		Name = "THS_Hitbox_" .. target.Model.Name,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Block,
		Size = Vector3.new(self.Config.HitboxSize, self.Config.HitboxSize, self.Config.HitboxSize),
		Transparency = self.Config.HitboxTransparency,
		Color = getTargetColor(target),
		CFrame = target.Root.CFrame,
	}, folder)

	local outline = create("SelectionBox", {
		Name = "THS_Hitbox_Outline",
		Adornee = part,
		Color3 = getTargetColor(target),
		LineThickness = 0.035,
		SurfaceTransparency = 1,
		Visible = true,
	}, part)

	self.Runtime.Hitboxes[target.Model] = {
		Part = part,
		Outline = outline,
		Target = target.Model,
		PartHitboxes = {},
	}
end

function THS:RemoveHitbox(model)
	local visual = self.Runtime.Hitboxes[model]

	if visual then
		if visual.Part then
			visual.Part:Destroy()
		end

		if visual.PartHitboxes then
			for _, partVisual in pairs(visual.PartHitboxes) do
				if partVisual.Part then
					partVisual.Part:Destroy()
				end
			end
		end

		self.Runtime.Hitboxes[model] = nil
	end
end

function THS:ClearHitboxes()
	for model in pairs(self.Runtime.Hitboxes) do
		self:RemoveHitbox(model)
	end
end

function THS:HideGlobalHitbox(visual)
	if visual.Part then
		visual.Part.Transparency = 1
		visual.Part.CanCollide = false
		visual.Part.CanTouch = false
		visual.Part.CanQuery = false
	end

	if visual.Outline then
		visual.Outline.Visible = false
	end
end

function THS:HidePartHitboxes(visual)
	if not visual.PartHitboxes then
		return
	end

	for _, partVisual in pairs(visual.PartHitboxes) do
		if partVisual.Part then
			partVisual.Part.Transparency = 1
			partVisual.Part.CanCollide = false
			partVisual.Part.CanTouch = false
			partVisual.Part.CanQuery = false
		end

		if partVisual.Outline then
			partVisual.Outline.Visible = false
		end
	end
end

function THS:GetOrCreatePartHitbox(visual, key, color)
	visual.PartHitboxes = visual.PartHitboxes or {}

	local partVisual = visual.PartHitboxes[key]
	if partVisual and partVisual.Part and partVisual.Part.Parent then
		return partVisual
	end

	local folder = self:GetRuntimeFolder()
	local part = create("Part", {
		Name = "THS_PartHitbox_" .. key,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Block,
		Transparency = self.Config.HitboxTransparency,
		Color = color,
		Size = Vector3.new(3, 3, 3),
	}, folder)

	local outline = create("SelectionBox", {
		Name = "THS_PartHitbox_Outline",
		Adornee = part,
		Color3 = color,
		LineThickness = 0.03,
		SurfaceTransparency = 1,
		Visible = true,
	}, part)

	partVisual = {
		Part = part,
		Outline = outline,
	}

	visual.PartHitboxes[key] = partVisual
	return partVisual
end

function THS:UpdateGlobalHitbox(target, visual, color)
	self:HidePartHitboxes(visual)

	local size = self.Config.HitboxSize
	visual.Part.CFrame = target.Root.CFrame
	visual.Part.Size = Vector3.new(size, size, size)
	visual.Part.Transparency = self.Config.HitboxTransparency
	visual.Part.Color = color
	visual.Part.CanCollide = false
	visual.Part.CanTouch = false
	visual.Part.CanQuery = false

	if visual.Outline then
		visual.Outline.Color3 = color
		visual.Outline.Visible = self.Config.HitboxTransparency >= 0.85
	end
end

function THS:UpdatePartHitboxes(target, visual, color)
	self:HideGlobalHitbox(visual)

	local active = {}
	local groups = getBodyPartGroups(target.Model)

	for groupName, parts in pairs(groups) do
		if isGroupEnabled(self.Config, groupName) then
			local boxSize = getGroupSize(self.Config, groupName)

			for index, bodyPart in ipairs(parts) do
				if bodyPart and bodyPart.Parent then
					local key = groupName .. "_" .. bodyPart.Name .. "_" .. tostring(index)
					active[key] = true

					local partVisual = self:GetOrCreatePartHitbox(visual, key, color)
					partVisual.Part.CFrame = bodyPart.CFrame
					partVisual.Part.Size = Vector3.new(boxSize, boxSize, boxSize)
					partVisual.Part.Transparency = self.Config.HitboxTransparency
					partVisual.Part.Color = color
					partVisual.Part.CanCollide = false
					partVisual.Part.CanTouch = false
					partVisual.Part.CanQuery = false

					if partVisual.Outline then
						partVisual.Outline.Color3 = color
						partVisual.Outline.Visible = self.Config.HitboxTransparency >= 0.85
					end
				end
			end
		end
	end

	for key, partVisual in pairs(visual.PartHitboxes) do
		if not active[key] then
			if partVisual.Part then
				partVisual.Part.Transparency = 1
			end

			if partVisual.Outline then
				partVisual.Outline.Visible = false
			end
		end
	end
end

function THS:UpdateHitbox(target)
	local visual = self.Runtime.Hitboxes[target.Model]

	if not visual then
		self:CreateHitbox(target)
		visual = self.Runtime.Hitboxes[target.Model]
	end

	if not visual or not visual.Part then
		return
	end

	local color = getTargetColor(target)

	if self.Config.HitboxMode == "Partes" then
		self:UpdatePartHitboxes(target, visual, color)
	else
		self:UpdateGlobalHitbox(target, visual, color)
	end
end

--//====================================================
--// UI ENGINE
--//====================================================

function THS:CreateToggle(parent, text, y, key, helpText)
	local row = create("Frame", {
		Name = text .. "_Row",
		Size = UDim2.fromOffset(520, 38),
		Position = UDim2.fromOffset(0, y),
		BackgroundTransparency = 1,
	}, parent)

	local button = create("TextButton", {
		Name = text,
		Size = UDim2.fromOffset(300, 34),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.PanelLight,
		Text = text,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		AutoButtonColor = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, button)

	local dot = create("Frame", {
		Name = "StateDot",
		Size = UDim2.fromOffset(13, 13),
		Position = UDim2.new(1, -24, 0.5, -6),
		BackgroundColor3 = self.Config[key] and Theme.Green or Theme.DarkDot,
	}, button)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)

	local help = create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(310, 2),
		BackgroundColor3 = Theme.PanelLight,
		Text = "ⓘ",
		TextColor3 = Theme.MutedText,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, help)

	connect(button.MouseButton1Click, function()
		self.Config[key] = not self.Config[key]

		if key == "SystemEnabled" and not self.Config.SystemEnabled then
			self.Config.HitboxEnabled = false
			self:ClearHitboxes()
		elseif key == "HitboxEnabled" and not self.Config.HitboxEnabled then
			self:ClearHitboxes()
		end

		self.Runtime.UnsavedChanges = true
		self:RefreshPage()
	end)

	connect(help.MouseButton1Click, function()
		self:SetPageInfo("ⓘ " .. text .. "\n\n" .. (helpText or "Sin descripción."))
	end)

	return row
end

function THS:CreateButton(parent, text, y, callback, helpText)
	local row = create("Frame", {
		Name = text .. "_Row",
		Size = UDim2.fromOffset(520, 38),
		Position = UDim2.fromOffset(0, y),
		BackgroundTransparency = 1,
	}, parent)

	local button = create("TextButton", {
		Name = text,
		Size = UDim2.fromOffset(300, 34),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.PanelLight,
		Text = text,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		AutoButtonColor = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, button)

	local help = create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(310, 2),
		BackgroundColor3 = Theme.PanelLight,
		Text = "ⓘ",
		TextColor3 = Theme.MutedText,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, help)

	connect(button.MouseButton1Click, function()
		callback()
		self.Runtime.UnsavedChanges = true
		self:RefreshPage()
	end)

	connect(help.MouseButton1Click, function()
		self:SetPageInfo("ⓘ " .. text .. "\n\n" .. (helpText or "Sin descripción."))
	end)

	return row
end

function THS:CreateNumberControl(parent, label, y, key, minValue, maxValue, step, helpText)
	local row = create("Frame", {
		Name = label .. "_Row",
		Size = UDim2.fromOffset(760, 48),
		Position = UDim2.fromOffset(0, y),
		BackgroundTransparency = 1,
	}, parent)

	create("TextLabel", {
		Size = UDim2.fromOffset(180, 24),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local minus = create("TextButton", {
		Size = UDim2.fromOffset(38, 28),
		Position = UDim2.fromOffset(185, 0),
		BackgroundColor3 = Theme.PanelLight,
		Text = "-",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		AutoButtonColor = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, minus)

	local plus = create("TextButton", {
		Size = UDim2.fromOffset(38, 28),
		Position = UDim2.fromOffset(228, 0),
		BackgroundColor3 = Theme.PanelLight,
		Text = "+",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		AutoButtonColor = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, plus)

	local box = create("TextBox", {
		Size = UDim2.fromOffset(90, 28),
		Position = UDim2.fromOffset(273, 0),
		BackgroundColor3 = Theme.PanelLight,
		Text = tostring(self.Config[key]),
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		ClearTextOnFocus = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, box)

	local sliderBack = create("Frame", {
		Size = UDim2.fromOffset(220, 8),
		Position = UDim2.fromOffset(375, 10),
		BackgroundColor3 = Theme.PanelLight,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, sliderBack)

	local sliderFill = create("Frame", {
		Size = UDim2.fromScale((self.Config[key] - minValue) / (maxValue - minValue), 1),
		BackgroundColor3 = Theme.Accent,
	}, sliderBack)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, sliderFill)

	local knob = create("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new((self.Config[key] - minValue) / (maxValue - minValue), -8, 0.5, -8),
		BackgroundColor3 = Theme.AccentLight,
	}, sliderBack)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

	local help = create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(610, -1),
		BackgroundColor3 = Theme.PanelLight,
		Text = "ⓘ",
		TextColor3 = Theme.MutedText,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, help)

	local function setValue(value)
		local newValue = math.clamp(value, minValue, maxValue)

		if step >= 1 then
			newValue = math.floor(newValue + 0.5)
		else
			newValue = math.floor((newValue / step) + 0.5) * step
			newValue = tonumber(string.format("%.3f", newValue))
		end

		self.Config[key] = newValue
		box.Text = tostring(newValue)

		local alpha = (newValue - minValue) / (maxValue - minValue)
		sliderFill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.new(alpha, -8, 0.5, -8)
		self.Runtime.UnsavedChanges = true
	end

	connect(minus.MouseButton1Click, function()
		setValue(self.Config[key] - step)
	end)

	connect(plus.MouseButton1Click, function()
		setValue(self.Config[key] + step)
	end)

	connect(box.FocusLost, function()
		local value = extractNumber(box.Text, self.Config[key])
		setValue(value)
	end)

	local dragging = false

	local function updateFromInput(input)
		local relativeX = input.Position.X - sliderBack.AbsolutePosition.X
		local alpha = math.clamp(relativeX / sliderBack.AbsoluteSize.X, 0, 1)
		local value = minValue + ((maxValue - minValue) * alpha)
		setValue(value)
	end

	connect(sliderBack.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromInput(input)
		end
	end)

	connect(knob.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)

	connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromInput(input)
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	connect(help.MouseButton1Click, function()
		self:SetPageInfo("ⓘ " .. label .. "\n\n" .. (helpText or "Sin descripción."))
	end)

	return row
end

function THS:SetPageInfo(text)
	if self.UI and self.UI.InfoText then
		self.UI.InfoText.Text = text
	end
end

function THS:ClearOptions()
	if not self.UI or not self.UI.OptionsFrame then
		return
	end

	for _, child in ipairs(self.UI.OptionsFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

function THS:RefreshPage()
	if not self.UI then
		return
	end

	self.UI.Title.Text = self.Runtime.CurrentPage
	self.UI.StatusDot.BackgroundColor3 = self.Config.SystemEnabled and Theme.Green or Theme.Red
	self.UI.StatusLabel.Text = self.Config.SystemEnabled and "Activo" or "Desactivado"

	self:ClearOptions()

	local page = self.Runtime.CurrentPage
	local options = self.UI.OptionsFrame

	if page == "Inicio" then
		self:SetPageInfo(
			"Panel principal del THS." ..
			"\n\nEstado: " .. (self.Config.SystemEnabled and "ACTIVO" or "DESACTIVADO") ..
			"\nDispositivo: " .. getDeviceType() ..
			"\nObjetivos detectados: " .. self.Runtime.DetectedTargets ..
			"\nHitbox: " .. (self.Config.HitboxEnabled and "ACTIVA" or "DESACTIVADA") ..
			"\n\nAtajos:" ..
			"\nRightShift = abrir/cerrar menú" ..
			"\nH = activar/desactivar THS"
		)

		self:CreateToggle(options, "Activar THS", 0, "SystemEnabled", "Activa o desactiva el sistema principal THS.")

	elseif page == "Hitbox" then
		self:SetPageInfo("Configura hitboxes auxiliares. Modo Global usa una caja general. Modo Partes permite cabeza, torso, brazos y piernas.")
		self:CreateToggle(options, "Hitbox auxiliar", 0, "HitboxEnabled", "Crea cajas auxiliares que siguen al objetivo.")

		self:CreateButton(options, "Modo: " .. self.Config.HitboxMode, 45, function()
			if self.Config.HitboxMode == "Global" then
				self.Config.HitboxMode = "Partes"
			else
				self.Config.HitboxMode = "Global"
			end
			self:ClearHitboxes()
		end, "Cambia entre una hitbox global o varias hitboxes por partes del cuerpo.")

		self:CreateNumberControl(options, "Transparencia", 100, "HitboxTransparency", 0, 1, 0.05, "0 = visible. 1 = invisible.")

		if self.Config.HitboxMode == "Global" then
			self:CreateNumberControl(options, "Tamaño global", 155, "HitboxSize", 1, 40, 1, "Tamaño de la caja auxiliar global.")
		else
			self:CreateToggle(options, "Cabeza", 155, "UseHeadHitbox", "Activa la hitbox auxiliar de cabeza.")
			if self.Config.UseHeadHitbox then
				self:CreateNumberControl(options, "Tamaño cabeza", 200, "HeadHitboxSize", 1, 25, 1, "Tamaño de la hitbox auxiliar de cabeza.")
			end

			self:CreateToggle(options, "Torso", 255, "UseTorsoHitbox", "Activa la hitbox auxiliar de torso.")
			if self.Config.UseTorsoHitbox then
				self:CreateNumberControl(options, "Tamaño torso", 300, "TorsoHitboxSize", 1, 30, 1, "Tamaño de la hitbox auxiliar de torso.")
			end

			self:CreateToggle(options, "Brazos", 355, "UseArmsHitbox", "Activa hitboxes auxiliares para brazos.")
			if self.Config.UseArmsHitbox then
				self:CreateNumberControl(options, "Tamaño brazos", 400, "ArmsHitboxSize", 1, 25, 1, "Tamaño de las hitboxes auxiliares de brazos.")
			end

			self:CreateToggle(options, "Piernas", 455, "UseLegsHitbox", "Activa hitboxes auxiliares para piernas.")
			if self.Config.UseLegsHitbox then
				self:CreateNumberControl(options, "Tamaño piernas", 500, "LegsHitboxSize", 1, 25, 1, "Tamaño de las hitboxes auxiliares de piernas.")
			end
		end

	elseif page == "Objetivos" then
		self:SetPageInfo("Elige qué tipos de objetivos reciben hitbox auxiliar.")
		self:CreateToggle(options, "Mostrar jugadores", 0, "ShowPlayers", "Incluye jugadores como objetivos.")
		self:CreateToggle(options, "Mostrar NPCs", 45, "ShowNPCs", "Incluye modelos con Humanoid y HumanoidRootPart.")
		self:CreateToggle(options, "Team Check", 90, "TeamCheck", "Si está activo, ignora jugadores de tu mismo equipo.")

	elseif page == "Colores" then
		self:SetPageInfo("Configura el color de las hitboxes auxiliares.")
		self:CreateToggle(options, "Color por equipo", 0, "UseTeamColor", "Usa el color del equipo del objetivo si es jugador.")

		self:CreateButton(options, "Color azul", 45, function()
			self.Config.HitboxColor = Color3.fromRGB(0, 220, 255)
			self.Config.UseTeamColor = false
		end, "Color manual azul/celeste.")

		self:CreateButton(options, "Color verde", 90, function()
			self.Config.HitboxColor = Color3.fromRGB(90, 255, 150)
			self.Config.UseTeamColor = false
		end, "Color manual verde.")

		self:CreateButton(options, "Color rojo", 135, function()
			self.Config.HitboxColor = Color3.fromRGB(255, 90, 90)
			self.Config.UseTeamColor = false
		end, "Color manual rojo.")

		self:CreateButton(options, "Color morado", 180, function()
			self.Config.HitboxColor = Color3.fromRGB(180, 120, 255)
			self.Config.UseTeamColor = false
		end, "Color manual morado.")

	elseif page == "Rendimiento" then
		self:SetPageInfo("Ajustes básicos para cuidar rendimiento.")
		self:CreateNumberControl(options, "Update Rate", 0, "UpdateRate", 0.01, 0.5, 0.01, "Tiempo entre actualizaciones. Menor = más fluido, mayor = más ligero.")
		self:CreateNumberControl(options, "Máx. objetivos", 55, "MaxTargets", 1, 100, 1, "Límite de objetivos procesados.")

		self:CreateButton(options, "Limpiar hitboxes", 110, function()
			self:ClearHitboxes()
		end, "Elimina todas las hitboxes auxiliares activas.")

	elseif page == "Ayuda" then
		self:SetPageInfo(
			"AYUDA THS" ..
			"\n\nEl THS crea hitboxes auxiliares visuales." ..
			"\nNo modifica el cuerpo real del personaje." ..
			"\nEsto evita problemas con vehículos/asientos." ..
			"\n\nRightShift = abrir/cerrar menú" ..
			"\nH = activar/desactivar THS" ..
			"\nArrastra la parte superior para mover el panel." ..
			"\nArrastra la bolita para mover el botón flotante."
		)

	elseif page == "Acerca de" then
		self:SetPageInfo(
			"THS - Tactical Hitbox System" ..
			"\n\nVersión: V1.1-A" ..
			"\nEstado: Hitbox por partes inicial" ..
			"\nProyecto 2/3" ..
			"\n\nObjetivo: sistema de hitbox auxiliar para tus propios juegos de Roblox Studio." ..
			"\n\nSiguiente paso: preparación server-side para daño validado."
		)
	end

	if options then
		if page == "Hitbox" and self.Config.HitboxMode == "Partes" then
			options.CanvasSize = UDim2.fromOffset(820, 620)
		else
			options.CanvasSize = UDim2.fromOffset(820, 420)
		end
	end
end

function THS:ShowCloseConfirm()
	if not self.UI or not self.UI.ConfirmFrame then
		return
	end

	local warning = "¿Cerrar THS completamente?\n\nSe desactivarán todas las funciones y se eliminarán la interfaz, la bolita y las hitboxes."
	if self.Runtime.UnsavedChanges then
		warning = warning .. "\n\nAdvertencia: tienes cambios sin guardar."
	end

	self.UI.ConfirmText.Text = warning
	self.UI.ConfirmFrame.Visible = true
end

function THS:HideCloseConfirm()
	if self.UI and self.UI.ConfirmFrame then
		self.UI.ConfirmFrame.Visible = false
	end
end

function THS:CreateUI()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local gui = create("ScreenGui", {
		Name = "THS_Interface",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
	}, playerGui)

	local main = create("Frame", {
		Name = "MainPanel",
		Size = UDim2.fromOffset(860, 570),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background,
		Visible = false,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, main)

	local topBar = create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
	}, main)

	local closeBtn = create("TextButton", {
		Name = "CloseButton",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -42, 0, 6),
		BackgroundColor3 = Theme.PanelLight,
		Text = "X",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
	}, topBar)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, closeBtn)
	connect(closeBtn.MouseButton1Click, function()
		self:ShowCloseConfirm()
	end)

	local sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 210, 1, 0),
		BackgroundColor3 = Theme.Panel,
	}, main)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, sidebar)

	create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 64),
		Position = UDim2.fromOffset(14, 10),
		BackgroundTransparency = 1,
		Text = "THS\nTactical Hitbox System",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sidebar)

	local statusDot = create("Frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromOffset(16, 84),
		BackgroundColor3 = Theme.Red,
	}, sidebar)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, statusDot)

	local statusLabel = create("TextLabel", {
		Size = UDim2.new(1, -35, 0, 20),
		Position = UDim2.fromOffset(34, 79),
		BackgroundTransparency = 1,
		Text = "Desactivado",
		TextColor3 = Theme.MutedText,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sidebar)

	local content = create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -230, 1, -20),
		Position = UDim2.fromOffset(220, 10),
		BackgroundColor3 = Theme.Panel,
	}, main)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, content)

	local title = create("TextLabel", {
		Size = UDim2.new(1, -60, 0, 42),
		Position = UDim2.fromOffset(15, 10),
		BackgroundTransparency = 1,
		Text = "Inicio",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)

	local infoText = create("TextLabel", {
		Size = UDim2.new(1, -30, 0, 105),
		Position = UDim2.fromOffset(15, 55),
		BackgroundTransparency = 1,
		TextColor3 = Theme.MutedText,
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "",
	}, content)

	local optionsFrame = create("ScrollingFrame", {
		Name = "OptionsFrame",
		Size = UDim2.new(1, -30, 1, -180),
		Position = UDim2.fromOffset(15, 165),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 7,
		CanvasSize = UDim2.fromOffset(780, 360),
		ScrollingDirection = Enum.ScrollingDirection.XY,
		AutomaticCanvasSize = Enum.AutomaticSize.None,
	}, content)

	local tabs = {
		"Inicio",
		"Hitbox",
		"Objetivos",
		"Colores",
		"Rendimiento",
		"Ayuda",
		"Acerca de",
	}

	for i, tab in ipairs(tabs) do
		local tabBtn = create("TextButton", {
			Size = UDim2.new(1, -20, 0, 32),
			Position = UDim2.fromOffset(10, 110 + ((i - 1) * 36)),
			BackgroundColor3 = Theme.PanelLight,
			Text = tab,
			TextColor3 = Theme.Text,
			Font = Enum.Font.GothamSemibold,
			TextSize = 13,
			AutoButtonColor = false,
		}, sidebar)
		create("UICorner", { CornerRadius = UDim.new(0, 8) }, tabBtn)

		connect(tabBtn.MouseButton1Click, function()
			self.Runtime.CurrentPage = tab
			self:RefreshPage()
		end)
	end

	local floating = create("TextButton", {
		Name = "THS_FloatingButton",
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.new(0, 25, 0.5, -29),
		BackgroundColor3 = Theme.Accent,
		Text = "THS",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		AutoButtonColor = false,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, floating)

	connect(floating.MouseButton1Click, function()
		self:ToggleMenu()
	end)

	-- Ventana de confirmación de cierre total
	local confirmFrame = create("Frame", {
		Name = "CloseConfirm",
		Size = UDim2.fromOffset(410, 210),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		ZIndex = 20,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 16) }, confirmFrame)

	local confirmText = create("TextLabel", {
		Size = UDim2.new(1, -30, 1, -80),
		Position = UDim2.fromOffset(15, 15),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 21,
	}, confirmFrame)

	local cancelBtn = create("TextButton", {
		Size = UDim2.fromOffset(150, 36),
		Position = UDim2.fromOffset(45, 160),
		BackgroundColor3 = Theme.PanelLight,
		Text = "Cancelar",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		ZIndex = 21,
		AutoButtonColor = false,
	}, confirmFrame)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, cancelBtn)

	local confirmBtn = create("TextButton", {
		Size = UDim2.fromOffset(150, 36),
		Position = UDim2.fromOffset(215, 160),
		BackgroundColor3 = Theme.Red,
		Text = "Cerrar todo",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		ZIndex = 21,
		AutoButtonColor = false,
	}, confirmFrame)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, confirmBtn)

	connect(cancelBtn.MouseButton1Click, function()
		self:HideCloseConfirm()
	end)

	connect(confirmBtn.MouseButton1Click, function()
		self:Shutdown()
	end)

	-- Movimiento de panel y bolita
	local draggingMain = false
	local mainStart
	local mainPos

	connect(topBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingMain = true
			mainStart = input.Position
			mainPos = main.Position
		end
	end)

	local draggingFloating = false
	local floatingStart
	local floatingPos

	connect(floating.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingFloating = true
			floatingStart = input.Position
			floatingPos = floating.Position
		end
	end)

	connect(UserInputService.InputChanged, function(input)
		if draggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - mainStart
			main.Position = UDim2.new(
				mainPos.X.Scale,
				mainPos.X.Offset + delta.X,
				mainPos.Y.Scale,
				mainPos.Y.Offset + delta.Y
			)
		end

		if draggingFloating and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - floatingStart
			floating.Position = UDim2.new(
				floatingPos.X.Scale,
				floatingPos.X.Offset + delta.X,
				floatingPos.Y.Scale,
				floatingPos.Y.Offset + delta.Y
			)
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingMain = false
			draggingFloating = false
		end
	end)

	self.UI = {
		Gui = gui,
		Main = main,
		Title = title,
		InfoText = infoText,
		OptionsFrame = optionsFrame,
		Floating = floating,
		StatusDot = statusDot,
		StatusLabel = statusLabel,
		ConfirmFrame = confirmFrame,
		ConfirmText = confirmText,
	}

	self:RefreshPage()
end

--//====================================================
--// CORE
--//====================================================

function THS:ToggleMenu(force)
	if not self.UI or not self.UI.Main then
		return
	end

	if force ~= nil then
		self.Config.MenuOpen = force
	else
		self.Config.MenuOpen = not self.Config.MenuOpen
	end

	self.UI.Main.Visible = self.Config.MenuOpen

	if self.Config.MenuOpen then
		self.UI.Main.Size = UDim2.fromOffset(810, 540)
		TweenService:Create(self.UI.Main, TweenInfo.new(0.18), {
			Size = UDim2.fromOffset(860, 570)
		}):Play()
	end
end

function THS:ToggleSystem()
	self.Config.SystemEnabled = not self.Config.SystemEnabled

	if not self.Config.SystemEnabled then
		self.Config.HitboxEnabled = false
		self:ClearHitboxes()
	end

	self.Runtime.UnsavedChanges = true
	self:RefreshPage()
end

function THS:Update()
	if self.Runtime.IsShuttingDown then
		return
	end

	if not self.Config.SystemEnabled or not self.Config.HitboxEnabled then
		self:ClearHitboxes()
		return
	end

	local now = os.clock()
	if now - self.Runtime.LastUpdate < self.Config.UpdateRate then
		return
	end
	self.Runtime.LastUpdate = now

	local active = {}
	local targets = self:GetTargets()

	for _, target in ipairs(targets) do
		if target.Root and target.Root.Parent then
			active[target.Model] = true
			self:UpdateHitbox(target)
		end
	end

	for model in pairs(self.Runtime.Hitboxes) do
		if not active[model] then
			self:RemoveHitbox(model)
		end
	end

	if self.UI and self.Runtime.CurrentPage == "Inicio" then
		self:RefreshPage()
	end
end

function THS:Shutdown()
	if self.Runtime.IsShuttingDown then
		return
	end

	self.Runtime.IsShuttingDown = true
	self.Config.SystemEnabled = false
	self.Config.HitboxEnabled = false
	self:ClearHitboxes()

	for _, connection in ipairs(self.Runtime.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.Runtime.Connections)

	if self.RuntimeFolder then
		self.RuntimeFolder:Destroy()
		self.RuntimeFolder = nil
	end

	if self.UI and self.UI.Gui then
		self.UI.Gui:Destroy()
	end

	self.UI = nil
	print("[THS] Sistema cerrado completamente.")
end

function THS:Init()
	self:CreateUI()

	connect(UserInputService.InputBegan, function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == self.Config.MenuKey then
			self:ToggleMenu()
		elseif input.KeyCode == self.Config.ToggleKey then
			self:ToggleSystem()
		end
	end)

	connect(RunService.RenderStepped, function()
		self:Update()
	end)

	print("[THS] Tactical Hitbox System V1.1-A iniciado.")
end

THS:Init()
