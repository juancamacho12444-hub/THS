--//====================================================
--// THS - Tactical Hitbox System V1.4-F
--// Sistema de Hitbox Táctica
--// LocalScript en StarterPlayer > StarterPlayerScripts
--// Proyecto 2/3 - Hitbox real para daño predeterminado
--//====================================================

--[[
	IMPORTANTE:
	Este sistema está pensado para TUS PROPIOS juegos de Roblox Studio.
	Esta V1.4-F usa hitbox real global o por partes, Color Engine y Debug Engine,
	MODIFICANDO temporalmente HumanoidRootPart/partes reales del personaje cuando activas la hitbox.

	Ventajas:
	- Hace que las armas que usan raycast/partes reales puedan pegar a la hitbox.
	- Puede afectar vehículos/asientos mientras esté activo.
	- Restaura las partes al apagar/cerrar.
	- No crea botón extra de disparo ni pestaña de daño.

	No agrega botón extra de disparo ni pestaña de daño.
	El daño lo hace el arma predeterminada de tu juego al pegarle a la parte agrandada.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

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

	-- Hitbox real
	HitboxMode = "Global", -- "Global" modifica HumanoidRootPart; "Partes" modifica partes reales
	HitboxSize = 8,
	HitboxTransparency = 0.65,
	HitboxColor = Color3.fromRGB(0, 220, 255),

	-- Color Engine inicial
	ColorMode = "Manual", -- "Manual", "Team", "Type", "Health", "SVT"
	AllyColor = Color3.fromRGB(90, 255, 150),
	EnemyColor = Color3.fromRGB(255, 90, 90),
	NPCColor = Color3.fromRGB(0, 220, 255),
	DummyColor = Color3.fromRGB(180, 180, 180),
	BossColor = Color3.fromRGB(255, 170, 0),
	ObjectiveColor = Color3.fromRGB(180, 120, 255),
	HighHealthColor = Color3.fromRGB(90, 255, 150),
	MidHealthColor = Color3.fromRGB(255, 220, 80),
	LowHealthColor = Color3.fromRGB(255, 90, 90),

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
	DebugKey = Enum.KeyCode.F8,
	ShowDebugPanel = true,
}

THS.Runtime = {
	LastUpdate = 0,
	LastNPCCache = 0,
	Hitboxes = {},
	OriginalParts = {},
	NPCs = {},
	Connections = {},
	DetectedTargets = 0,
	CurrentPage = "Inicio",
	IsShuttingDown = false,
	UnsavedChanges = false,
	LastDebugUpdate = 0,
	LastFPSUpdate = 0,
	FrameCounter = 0,
	CurrentFPS = 0,
	LastFrameTimeMs = 0,
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

local ColorPalette = {
	{ Name = "Celeste", Value = Color3.fromRGB(0, 220, 255) },
	{ Name = "Azul", Value = Color3.fromRGB(0, 145, 255) },
	{ Name = "Verde", Value = Color3.fromRGB(90, 255, 150) },
	{ Name = "Rojo", Value = Color3.fromRGB(255, 90, 90) },
	{ Name = "Morado", Value = Color3.fromRGB(180, 120, 255) },
	{ Name = "Naranja", Value = Color3.fromRGB(255, 170, 0) },
	{ Name = "Blanco", Value = Color3.fromRGB(245, 245, 245) },
}

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

local function getPaletteNextColor(currentColor)
	local bestIndex = 1
	local bestDistance = math.huge

	for index, entry in ipairs(ColorPalette) do
		local c = entry.Value
		local distance = math.abs(c.R - currentColor.R) + math.abs(c.G - currentColor.G) + math.abs(c.B - currentColor.B)
		if distance < bestDistance then
			bestDistance = distance
			bestIndex = index
		end
	end

	local nextIndex = bestIndex + 1
	if nextIndex > #ColorPalette then
		nextIndex = 1
	end

	return ColorPalette[nextIndex].Value
end

local function getColorName(color)
	local bestName = "Personalizado"
	local bestDistance = math.huge

	for _, entry in ipairs(ColorPalette) do
		local c = entry.Value
		local distance = math.abs(c.R - color.R) + math.abs(c.G - color.G) + math.abs(c.B - color.B)
		if distance < bestDistance then
			bestDistance = distance
			bestName = entry.Name
		end
	end

	return bestName
end

local function getTargetType(model, player)
	local explicitType = model:GetAttribute("THS_TargetType") or model:GetAttribute("SVT_TargetType")
	if explicitType then
		return tostring(explicitType)
	end

	if CollectionService:HasTag(model, "THS_Boss") or CollectionService:HasTag(model, "Boss") then
		return "Boss"
	end

	if CollectionService:HasTag(model, "THS_Objective") or CollectionService:HasTag(model, "Objective") then
		return "Objective"
	end

	if CollectionService:HasTag(model, "THS_Dummy") or CollectionService:HasTag(model, "Dummy") then
		return "Dummy"
	end

	local name = string.lower(model.Name)
	if string.find(name, "boss") then
		return "Boss"
	end

	if string.find(name, "objective") or string.find(name, "objetivo") then
		return "Objective"
	end

	if string.find(name, "dummy") or string.find(name, "dummie") then
		return "Dummy"
	end

	if player then
		if LocalPlayer.Team and player.Team == LocalPlayer.Team then
			return "Ally"
		end
		return "Enemy"
	end

	return "NPC"
end

local function getHealthColor(target)
	local humanoid = target.Humanoid
	if not humanoid or humanoid.MaxHealth <= 0 then
		return THS.Config.HitboxColor
	end

	local ratio = humanoid.Health / humanoid.MaxHealth
	if ratio >= 0.65 then
		return THS.Config.HighHealthColor
	elseif ratio >= 0.3 then
		return THS.Config.MidHealthColor
	else
		return THS.Config.LowHealthColor
	end
end

local function getTypeColor(target)
	local targetType = target.TargetType or "NPC"

	if targetType == "Ally" then
		return THS.Config.AllyColor
	elseif targetType == "Enemy" then
		return THS.Config.EnemyColor
	elseif targetType == "Dummy" then
		return THS.Config.DummyColor
	elseif targetType == "Boss" then
		return THS.Config.BossColor
	elseif targetType == "Objective" then
		return THS.Config.ObjectiveColor
	end

	return THS.Config.NPCColor
end

local function getTargetColor(target)
	if THS.Config.UseTeamColor and target.Player and target.Player.TeamColor then
		return target.Player.TeamColor.Color
	end

	if THS.Config.ColorMode == "Team" and target.Player and target.Player.TeamColor then
		return target.Player.TeamColor.Color
	end

	if THS.Config.ColorMode == "Type" then
		return getTypeColor(target)
	end

	if THS.Config.ColorMode == "Health" then
		return getHealthColor(target)
	end

	if THS.Config.ColorMode == "SVT" then
		local svtColor = target.Model:GetAttribute("SVT_TargetColor") or target.Model:GetAttribute("SVT_Color")
		if typeof(svtColor) == "Color3" then
			return svtColor
		end

		local playerSVTColor = LocalPlayer:GetAttribute("SVT_CurrentColor")
		if typeof(playerSVTColor) == "Color3" then
			return playerSVTColor
		end

		return getTypeColor(target)
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
					data.TargetType = getTargetType(player.Character, player)

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
				data.TargetType = getTargetType(data.Model, nil)
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
--// HITBOX ENGINE REAL
--//====================================================

--[[
	V1.4-F:
	Esta versión NO usa cajas auxiliares para el daño.
	Modifica temporalmente HumanoidRootPart o partes reales del personaje.

	Objetivo:
	- Que las armas del juego que disparan con raycast/hit part puedan detectar el hitbox.
	- Que no exista botón extra de daño.
	- Que no exista pestaña de daño.
	- Que el daño sea el predeterminado del arma/juego.

	Nota:
	Si un arma valida todo 100% desde servidor, un LocalScript no puede forzar ese daño.
	Para esa clase de armas, después hacemos la versión correcta con servidor.
]]

function THS:SaveOriginalPart(part)
	if not part or not part:IsA("BasePart") then
		return
	end

	if self.Runtime.OriginalParts[part] then
		return
	end

	self.Runtime.OriginalParts[part] = {
		Size = part.Size,
		Transparency = part.Transparency,
		Color = part.Color,
		Material = part.Material,
		CanCollide = part.CanCollide,
		CanTouch = part.CanTouch,
		CanQuery = part.CanQuery,
		Massless = part.Massless,
		Name = part.Name,
	}
end

function THS:RestorePart(part)
	local original = self.Runtime.OriginalParts[part]
	if not original then
		return
	end

	if part and part.Parent then
		pcall(function()
			part.Size = original.Size
			part.Transparency = original.Transparency
			part.Color = original.Color
			part.Material = original.Material
			part.CanCollide = original.CanCollide
			part.CanTouch = original.CanTouch
			part.CanQuery = original.CanQuery
			part.Massless = original.Massless
		end)

		local outline = part:FindFirstChild("THS_RealHitbox_Outline")
		if outline then
			outline:Destroy()
		end
	end

	self.Runtime.OriginalParts[part] = nil
end

function THS:CreateOrUpdateOutline(part, color)
	local outline = part:FindFirstChild("THS_RealHitbox_Outline")

	if not outline then
		outline = create("SelectionBox", {
			Name = "THS_RealHitbox_Outline",
			Adornee = part,
			Color3 = color,
			LineThickness = 0.035,
			SurfaceTransparency = 1,
			Visible = true,
		}, part)
	else
		outline.Adornee = part
		outline.Color3 = color
		outline.Visible = true
	end

	return outline
end

function THS:GetRuntimeFolder()
	-- Se conserva por compatibilidad interna, pero V1.4-F no crea partes auxiliares.
	return workspace
end

function THS:CreateHitbox(target)
	self.Runtime.Hitboxes[target.Model] = {
		Target = target.Model,
		ActiveParts = {},
		TargetName = target.Model.Name,
	}
end

function THS:ApplyRealHitbox(part, size, color)
	if not part or not part:IsA("BasePart") then
		return false
	end

	self:SaveOriginalPart(part)

	pcall(function()
		part.Size = Vector3.new(size, size, size)
		part.Transparency = self.Config.HitboxTransparency
		part.Color = color
		part.Material = Enum.Material.Neon
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = true
		part.Massless = true
	end)

	self:CreateOrUpdateOutline(part, color)
	return true
end

function THS:RemoveHitbox(model)
	local visual = self.Runtime.Hitboxes[model]

	if visual and visual.ActiveParts then
		for part in pairs(visual.ActiveParts) do
			self:RestorePart(part)
		end
	end

	self.Runtime.Hitboxes[model] = nil
end

function THS:ClearHitboxes()
	for model in pairs(self.Runtime.Hitboxes) do
		self:RemoveHitbox(model)
	end

	-- Seguridad extra por si alguna parte quedó guardada fuera de la tabla del modelo.
	for part in pairs(self.Runtime.OriginalParts) do
		self:RestorePart(part)
	end
end

function THS:UpdateGlobalHitbox(target, visual, color)
	local active = {}
	local size = self.Config.HitboxSize

	if target.Root and target.Root.Parent then
		if self:ApplyRealHitbox(target.Root, size, color) then
			active[target.Root] = true
		end
	end

	for part in pairs(visual.ActiveParts) do
		if not active[part] then
			self:RestorePart(part)
		end
	end

	visual.ActiveParts = active
end

function THS:UpdatePartHitboxes(target, visual, color)
	local active = {}
	local groups = getBodyPartGroups(target.Model)

	for groupName, parts in pairs(groups) do
		if isGroupEnabled(self.Config, groupName) then
			local boxSize = getGroupSize(self.Config, groupName)

			for _, bodyPart in ipairs(parts) do
				if bodyPart and bodyPart.Parent and bodyPart:IsA("BasePart") then
					if self:ApplyRealHitbox(bodyPart, boxSize, color) then
						active[bodyPart] = true
					end
				end
			end
		end
	end

	for part in pairs(visual.ActiveParts) do
		if not active[part] then
			self:RestorePart(part)
		end
	end

	visual.ActiveParts = active
end

function THS:UpdateHitbox(target)
	local visual = self.Runtime.Hitboxes[target.Model]

	if not visual then
		self:CreateHitbox(target)
		visual = self.Runtime.Hitboxes[target.Model]
	end

	if not visual then
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
--// DEBUG ENGINE INICIAL
--//====================================================

function THS:GetActiveHitboxStats()
	local targetCount = 0
	local boxCount = 0

	for _, visual in pairs(self.Runtime.Hitboxes) do
		targetCount += 1

		if visual.ActiveParts then
			for part in pairs(visual.ActiveParts) do
				if part and part.Parent then
					boxCount += 1
				end
			end
		end
	end

	return targetCount, boxCount
end

function THS:RefreshDebugPanel(force)
	if not self.UI or not self.UI.DebugFrame or not self.UI.DebugText then
		return
	end

	self.UI.DebugFrame.Visible = self.Config.ShowDebugPanel
	if not self.Config.ShowDebugPanel then
		return
	end

	local now = os.clock()
	if not force and now - self.Runtime.LastDebugUpdate < 0.25 then
		return
	end
	self.Runtime.LastDebugUpdate = now

	local targetVisuals, boxCount = self:GetActiveHitboxStats()
	self.UI.DebugText.Text =
		"THS DEBUG" ..
		"\nFPS: " .. tostring(math.floor(self.Runtime.CurrentFPS + 0.5)) ..
		"\nFrame: " .. string.format("%.2f ms", self.Runtime.LastFrameTimeMs) ..
		"\nTargets: " .. tostring(self.Runtime.DetectedTargets) ..
		"\nVisuales: " .. tostring(targetVisuals) ..
		"\nHitboxes: " .. tostring(boxCount) ..
		"\nModo: " .. tostring(self.Config.HitboxMode) ..
		"\nColor: " .. tostring(self.Config.ColorMode) ..
		"\nUpdate: " .. tostring(self.Config.UpdateRate)
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
		elseif key == "ShowDebugPanel" then
			self:UpdateDebugVisibility()
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

function THS:CycleColorMode()
	local modes = { "Manual", "Team", "Type", "Health", "SVT" }
	local currentIndex = table.find(modes, self.Config.ColorMode) or 1
	local nextIndex = currentIndex + 1
	if nextIndex > #modes then
		nextIndex = 1
	end

	self.Config.ColorMode = modes[nextIndex]
	self.Config.UseTeamColor = self.Config.ColorMode == "Team"
end

function THS:CycleConfigColor(key)
	self.Config[key] = getPaletteNextColor(self.Config[key])
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
		self:SetPageInfo("Configura la hitbox real. Modo Global agranda HumanoidRootPart. Modo Partes agranda partes reales del cuerpo.")
		self:CreateToggle(options, "Hitbox real", 0, "HitboxEnabled", "Agranda temporalmente la parte real para que el arma del juego pueda detectar el impacto.")

		self:CreateButton(options, "Modo: " .. self.Config.HitboxMode, 45, function()
			if self.Config.HitboxMode == "Global" then
				self.Config.HitboxMode = "Partes"
			else
				self.Config.HitboxMode = "Global"
			end
			self:ClearHitboxes()
		end, "Cambia entre agrandar HumanoidRootPart o agrandar partes reales del cuerpo.")

		self:CreateNumberControl(options, "Transparencia", 100, "HitboxTransparency", 0, 1, 0.05, "0 = visible. 1 = invisible.")

		if self.Config.HitboxMode == "Global" then
			self:CreateNumberControl(options, "Tamaño global", 155, "HitboxSize", 1, 40, 1, "Tamaño del HumanoidRootPart agrandado.")
		else
			self:CreateToggle(options, "Cabeza", 155, "UseHeadHitbox", "Activa hitbox real de cabeza.")
			if self.Config.UseHeadHitbox then
				self:CreateNumberControl(options, "Tamaño cabeza", 200, "HeadHitboxSize", 1, 25, 1, "Tamaño real aplicado a la cabeza.")
			end

			self:CreateToggle(options, "Torso", 255, "UseTorsoHitbox", "Activa hitbox real de torso.")
			if self.Config.UseTorsoHitbox then
				self:CreateNumberControl(options, "Tamaño torso", 300, "TorsoHitboxSize", 1, 30, 1, "Tamaño real aplicado al torso.")
			end

			self:CreateToggle(options, "Brazos", 355, "UseArmsHitbox", "Activa hitboxes reales para brazos.")
			if self.Config.UseArmsHitbox then
				self:CreateNumberControl(options, "Tamaño brazos", 400, "ArmsHitboxSize", 1, 25, 1, "Tamaño real aplicado a los brazos.")
			end

			self:CreateToggle(options, "Piernas", 455, "UseLegsHitbox", "Activa hitboxes reales para piernas.")
			if self.Config.UseLegsHitbox then
				self:CreateNumberControl(options, "Tamaño piernas", 500, "LegsHitboxSize", 1, 25, 1, "Tamaño real aplicado a las piernas.")
			end
		end

	elseif page == "Objetivos" then
		self:SetPageInfo("Elige qué tipos de objetivos reciben hitbox real.")
		self:CreateToggle(options, "Mostrar jugadores", 0, "ShowPlayers", "Incluye jugadores como objetivos.")
		self:CreateToggle(options, "Mostrar NPCs", 45, "ShowNPCs", "Incluye modelos con Humanoid y HumanoidRootPart.")
		self:CreateToggle(options, "Team Check", 90, "TeamCheck", "Si está activo, ignora jugadores de tu mismo equipo.")

	elseif page == "Colores" then
		self:SetPageInfo(
			"Color Engine inicial." ..
			"\n\nModo actual: " .. self.Config.ColorMode ..
			"\nManual: " .. getColorName(self.Config.HitboxColor) ..
			"\nAliado: " .. getColorName(self.Config.AllyColor) ..
			" | Enemigo: " .. getColorName(self.Config.EnemyColor) ..
			"\nNPC: " .. getColorName(self.Config.NPCColor) ..
			"\nBoss: " .. getColorName(self.Config.BossColor) .. " | Objetivo: " .. getColorName(self.Config.ObjectiveColor)
		)

		self:CreateButton(options, "Modo color: " .. self.Config.ColorMode, 0, function()
			self:CycleColorMode()
		end, "Cambia el modo de color: Manual, Team, Type, Health o SVT.")

		self:CreateButton(options, "Manual: " .. getColorName(self.Config.HitboxColor), 45, function()
			self:CycleConfigColor("HitboxColor")
			self.Config.ColorMode = "Manual"
			self.Config.UseTeamColor = false
		end, "Cicla el color manual global de las hitboxes.")

		self:CreateButton(options, "Aliado: " .. getColorName(self.Config.AllyColor), 90, function()
			self:CycleConfigColor("AllyColor")
			self.Config.ColorMode = "Type"
		end, "Color usado para objetivos aliados en modo Type.")

		self:CreateButton(options, "Enemigo: " .. getColorName(self.Config.EnemyColor), 135, function()
			self:CycleConfigColor("EnemyColor")
			self.Config.ColorMode = "Type"
		end, "Color usado para objetivos enemigos en modo Type.")

		self:CreateButton(options, "NPC: " .. getColorName(self.Config.NPCColor), 180, function()
			self:CycleConfigColor("NPCColor")
			self.Config.ColorMode = "Type"
		end, "Color usado para NPCs en modo Type.")

		self:CreateButton(options, "Dummy: " .. getColorName(self.Config.DummyColor), 225, function()
			self:CycleConfigColor("DummyColor")
			self.Config.ColorMode = "Type"
		end, "Color usado para Dummies en modo Type.")

		self:CreateButton(options, "Boss: " .. getColorName(self.Config.BossColor), 270, function()
			self:CycleConfigColor("BossColor")
			self.Config.ColorMode = "Type"
		end, "Color usado para Bosses en modo Type.")

		self:CreateButton(options, "Objetivo: " .. getColorName(self.Config.ObjectiveColor), 315, function()
			self:CycleConfigColor("ObjectiveColor")
			self.Config.ColorMode = "Type"
		end, "Color usado para objetivos especiales en modo Type.")

	elseif page == "Rendimiento" then
		self:SetPageInfo("Ajustes básicos para cuidar rendimiento.")
		self:CreateNumberControl(options, "Update Rate", 0, "UpdateRate", 0.01, 0.5, 0.01, "Tiempo entre actualizaciones. Menor = más fluido, mayor = más ligero.")
		self:CreateNumberControl(options, "Máx. objetivos", 55, "MaxTargets", 1, 100, 1, "Límite de objetivos procesados.")

		self:CreateButton(options, "Limpiar hitboxes", 110, function()
			self:ClearHitboxes()
		end, "Restaura todas las partes modificadas y limpia las hitboxes reales activas.")

	elseif page == "Debug" then
		local targetVisuals, boxCount = self:GetActiveHitboxStats()
		self:SetPageInfo(
			"Debug Engine inicial. Hitbox real activa cuando THS + Hitbox real están encendidos." ..
			"\n\nFPS: " .. tostring(math.floor(self.Runtime.CurrentFPS + 0.5)) ..
			"\nObjetivos detectados: " .. tostring(self.Runtime.DetectedTargets) ..
			"\nVisuales activos: " .. tostring(targetVisuals) ..
			"\nHitboxes activas: " .. tostring(boxCount) ..
			"\n\nF8 = mostrar/ocultar panel Debug."
		)

		self:CreateToggle(options, "Panel Debug", 0, "ShowDebugPanel", "Muestra un recuadro pequeño con FPS, objetivos y hitboxes activas.")
		self:CreateButton(options, "Mostrar/Ocultar Debug", 45, function()
			self:ToggleDebugPanel()
		end, "Alterna el panel Debug sin cerrar la interfaz principal.")
		self:CreateButton(options, "Actualizar Debug", 90, function()
			self:RefreshDebugPanel(true)
		end, "Actualiza manualmente las estadísticas del panel Debug.")

	elseif page == "Ayuda" then
		self:SetPageInfo(
			"AYUDA THS" ..
			"\n\nEl THS V1.4-F agranda partes reales del personaje." ..
			"\nNo agrega botón extra ni pestaña de daño." ..
			"\nEl daño lo hace el arma predeterminada del juego si detecta esas partes." ..
			"\n\nRightShift = abrir/cerrar menú" ..
			"\nH = activar/desactivar THS" ..
			"\nArrastra la parte superior para mover el panel." ..
			"\nArrastra la bolita para mover el botón flotante."
		)

	elseif page == "Acerca de" then
		self:SetPageInfo(
			"THS - Tactical Hitbox System" ..
			"\n\nVersión: V1.4-F" ..
			"\nEstado: Hitbox real para daño predeterminado" ..
			"\nProyecto 2/3" ..
			"\n\nObjetivo: hitbox real para que tus armas puedan impactar con su daño predeterminado." ..
			"\n\nSiguiente paso: versión server-side cuando quieras hacerlo más estable."
		)
	end

	if options then
		if page == "Hitbox" and self.Config.HitboxMode == "Partes" then
			options.CanvasSize = UDim2.fromOffset(860, 620)
		elseif page == "Colores" then
			options.CanvasSize = UDim2.fromOffset(860, 460)
		else
			options.CanvasSize = UDim2.fromOffset(860, 420)
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
		"Debug",
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

	-- Panel Debug pequeño y movible
	local debugFrame = create("Frame", {
		Name = "THS_DebugPanel",
		Size = UDim2.fromOffset(230, 165),
		Position = UDim2.new(1, -250, 0, 20),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.08,
		Visible = self.Config.ShowDebugPanel,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, debugFrame)

	local debugTitle = create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 6),
		BackgroundTransparency = 1,
		Text = "THS DEBUG",
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, debugFrame)

	local debugText = create("TextLabel", {
		Size = UDim2.new(1, -20, 1, -38),
		Position = UDim2.fromOffset(10, 32),
		BackgroundTransparency = 1,
		Text = "Inicializando debug...",
		TextColor3 = Theme.MutedText,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, debugFrame)

	local draggingDebug = false
	local debugStart
	local debugPos

	connect(debugFrame.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingDebug = true
			debugStart = input.Position
			debugPos = debugFrame.Position
		end
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

		if draggingDebug and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - debugStart
			debugFrame.Position = UDim2.new(
				debugPos.X.Scale,
				debugPos.X.Offset + delta.X,
				debugPos.Y.Scale,
				debugPos.Y.Offset + delta.Y
			)
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingMain = false
			draggingFloating = false
			draggingDebug = false
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
		DebugFrame = debugFrame,
		DebugText = debugText,
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

function THS:Update(deltaTime)
	if self.Runtime.IsShuttingDown then
		return
	end

	local now = os.clock()
	self.Runtime.FrameCounter += 1
	self.Runtime.LastFrameTimeMs = (deltaTime or 0) * 1000

	if now - self.Runtime.LastFPSUpdate >= 1 then
		local elapsed = now - self.Runtime.LastFPSUpdate
		if elapsed > 0 then
			self.Runtime.CurrentFPS = self.Runtime.FrameCounter / elapsed
		end
		self.Runtime.FrameCounter = 0
		self.Runtime.LastFPSUpdate = now
	end

	self:RefreshDebugPanel(false)

	if not self.Config.SystemEnabled or not self.Config.HitboxEnabled then
		self:ClearHitboxes()
		return
	end

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
	self.Runtime.LastFPSUpdate = os.clock()
	self:CreateUI()

	connect(UserInputService.InputBegan, function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == self.Config.MenuKey then
			self:ToggleMenu()
		elseif input.KeyCode == self.Config.ToggleKey then
			self:ToggleSystem()
		elseif input.KeyCode == self.Config.DebugKey then
			self:ToggleDebugPanel()
		end
	end)

	connect(RunService.RenderStepped, function(deltaTime)
		self:Update(deltaTime)
	end)

	print("[THS] Tactical Hitbox System V1.4-F Real Hitbox iniciado.")
end

THS:Init()
