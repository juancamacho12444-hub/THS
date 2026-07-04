--//====================================================
--// THS - Tactical Hitbox System V2.0 Demo Completa
--// Sistema de Hitbox Táctica
--// LocalScript en StarterPlayer > StarterPlayerScripts
--// Proyecto 2/3 - Demo completa final
--//====================================================

--[[
	IMPORTANTE:
	Este sistema está pensado para TUS PROPIOS juegos de Roblox Studio.
	Esta V2.0 Demo Completa cierra la versión funcional estable la hitbox real global o por partes, Color Engine y Debug Engine,
	MODIFICANDO temporalmente HumanoidRootPart/partes reales del personaje cuando activas la hitbox.

	Ventajas:
	- Hace que las armas que usan raycast/partes reales puedan pegar a la hitbox.
	- Puede afectar vehículos/asientos mientras esté activo.
	- Restaura las partes al apagar/cerrar.
	- No crea botón extra de disparo ni pestaña de daño.

	No agrega botón extra de disparo ni pestaña de daño.
	El daño lo hace el arma predeterminada de tu juego al pegarle a la parte agrandada.
	Incluye Save Engine portable por código de exportación/importación.
	Incluye Optimization Engine con presets de rendimiento, distancia máxima y limpieza automática.
	Incluye Compatibility/Polish Engine con ajustes rápidos para PC, móvil, NPCs, visible/invisible y restauración.
	Versión final de demo: lista para copiar, pegar y probar como LocalScript.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

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
	HitboxCanTouch = true, -- Ayuda a armas/proyectiles que usan eventos Touched.
	RestoreOnDeath = true,

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
	UseDistanceLimit = true,
	TargetMaxDistance = 600,
	AutoCleanStale = true,
	AutoCleanInterval = 3,

	-- UI
	MenuKey = Enum.KeyCode.RightShift,
	ToggleKey = Enum.KeyCode.H,
	DebugKey = Enum.KeyCode.F8,
	ShowDebugPanel = true,
}

THS.Runtime = {
	LastUpdate = 0,
	LastNPCCache = 0,
	LastAutoClean = 0,
	Hitboxes = {},
	OriginalParts = {},
	TargetConnections = {},
	NPCs = {},
	Connections = {},
	DetectedTargets = 0,
	CurrentPage = "Inicio",
	CurrentProfileName = "Manual",
	PerformanceMode = "Balanceado",
	CompatibilityMode = "Normal",
	FinalStatus = "Demo completa lista",
	SavedProfiles = {},
	LastExportCode = "",
	LastImportCode = "",
	LastSaveStatus = "Sin acciones todavía.",
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

local ProfileKeys = {
	"HitboxMode",
	"HitboxSize",
	"HitboxTransparency",
	"HitboxColor",
	"HitboxCanTouch",
	"ShowPlayers",
	"ShowNPCs",
	"TeamCheck",
	"ColorMode",
	"UseHeadHitbox",
	"UseTorsoHitbox",
	"UseArmsHitbox",
	"UseLegsHitbox",
	"HeadHitboxSize",
	"TorsoHitboxSize",
	"ArmsHitboxSize",
	"LegsHitboxSize",
	"UpdateRate",
	"MaxTargets",
	"UseDistanceLimit",
	"TargetMaxDistance",
	"AutoCleanStale",
	"AutoCleanInterval",
}

local BuiltInProfiles = {
	["Recomendado"] = {
		HitboxMode = "Global",
		HitboxSize = 8,
		HitboxTransparency = 0.65,
		HitboxCanTouch = true,
		ShowPlayers = true,
		ShowNPCs = false,
		TeamCheck = false,
		ColorMode = "Manual",
		UpdateRate = 0.05,
		MaxTargets = 50,
		UseDistanceLimit = true,
		TargetMaxDistance = 600,
		AutoCleanStale = true,
		AutoCleanInterval = 3,
	},

	["Grande"] = {
		HitboxMode = "Global",
		HitboxSize = 13,
		HitboxTransparency = 0.75,
		HitboxCanTouch = true,
		ShowPlayers = true,
		ShowNPCs = false,
		TeamCheck = false,
		ColorMode = "Manual",
		UpdateRate = 0.05,
		MaxTargets = 50,
		UseDistanceLimit = true,
		TargetMaxDistance = 600,
		AutoCleanStale = true,
		AutoCleanInterval = 3,
	},

	["Movil"] = {
		HitboxMode = "Global",
		HitboxSize = 16,
		HitboxTransparency = 0.8,
		HitboxCanTouch = true,
		ShowPlayers = true,
		ShowNPCs = false,
		TeamCheck = false,
		ColorMode = "Manual",
		UpdateRate = 0.04,
		MaxTargets = 60,
		UseDistanceLimit = true,
		TargetMaxDistance = 450,
		AutoCleanStale = true,
		AutoCleanInterval = 2.5,
	},

	["NPCs"] = {
		HitboxMode = "Global",
		HitboxSize = 10,
		HitboxTransparency = 0.65,
		HitboxCanTouch = true,
		ShowPlayers = false,
		ShowNPCs = true,
		TeamCheck = false,
		ColorMode = "Type",
		UpdateRate = 0.06,
		MaxTargets = 70,
		UseDistanceLimit = true,
		TargetMaxDistance = 700,
		AutoCleanStale = true,
		AutoCleanInterval = 3,
	},

	["Cabeza"] = {
		HitboxMode = "Partes",
		HitboxTransparency = 0.65,
		HitboxCanTouch = true,
		ShowPlayers = true,
		ShowNPCs = false,
		TeamCheck = false,
		ColorMode = "Manual",
		UseHeadHitbox = true,
		UseTorsoHitbox = false,
		UseArmsHitbox = false,
		UseLegsHitbox = false,
		HeadHitboxSize = 8,
		TorsoHitboxSize = 7,
		ArmsHitboxSize = 4,
		LegsHitboxSize = 4,
		UpdateRate = 0.05,
		MaxTargets = 50,
		UseDistanceLimit = true,
		TargetMaxDistance = 500,
		AutoCleanStale = true,
		AutoCleanInterval = 3,
	},

	["Torso"] = {
		HitboxMode = "Partes",
		HitboxTransparency = 0.65,
		HitboxCanTouch = true,
		ShowPlayers = true,
		ShowNPCs = false,
		TeamCheck = false,
		ColorMode = "Manual",
		UseHeadHitbox = false,
		UseTorsoHitbox = true,
		UseArmsHitbox = false,
		UseLegsHitbox = false,
		HeadHitboxSize = 5,
		TorsoHitboxSize = 10,
		ArmsHitboxSize = 4,
		LegsHitboxSize = 4,
		UpdateRate = 0.05,
		MaxTargets = 50,
		UseDistanceLimit = true,
		TargetMaxDistance = 500,
		AutoCleanStale = true,
		AutoCleanInterval = 3,
	},
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

function THS:GetLocalRoot()
	if LocalPlayer.Character then
		return LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	end

	return nil
end

function THS:IsTargetInsideDistance(target, localRoot)
	if not self.Config.UseDistanceLimit then
		return true
	end

	if not target or not target.Root or not localRoot then
		return true
	end

	local distance = (target.Root.Position - localRoot.Position).Magnitude
	target.Distance = distance

	return distance <= self.Config.TargetMaxDistance
end

function THS:AddTargetIfAllowed(targets, data, localRoot)
	if not data then
		return
	end

	if not self:IsTargetInsideDistance(data, localRoot) then
		return
	end

	table.insert(targets, data)
end

function THS:GetTargets()
	local targets = {}
	local localRoot = self:GetLocalRoot()

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
						self:AddTargetIfAllowed(targets, data, localRoot)
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
				self:AddTargetIfAllowed(targets, data, localRoot)
			end
		end
	end

	table.sort(targets, function(a, b)
		return (a.Distance or 0) < (b.Distance or 0)
	end)

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
	V2.0:
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
		CastShadow = part.CastShadow,
		CustomPhysicalProperties = part.CustomPhysicalProperties,
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
			part.CastShadow = original.CastShadow
			part.CustomPhysicalProperties = original.CustomPhysicalProperties
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
	-- Se conserva por compatibilidad interna, pero V2.0 no crea partes auxiliares.
	return workspace
end

function THS:DisconnectTargetConnections(model)
	local list = self.Runtime.TargetConnections[model]
	if not list then
		return
	end

	for _, connection in ipairs(list) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	self.Runtime.TargetConnections[model] = nil
end

function THS:BindTargetSafety(target)
	if not target or not target.Model or self.Runtime.TargetConnections[target.Model] then
		return
	end

	local connections = {}
	self.Runtime.TargetConnections[target.Model] = connections

	if target.Humanoid then
		table.insert(connections, target.Humanoid.Died:Connect(function()
			if self.Config.RestoreOnDeath then
				self:RemoveHitbox(target.Model)
			end
		end))
	end

	table.insert(connections, target.Model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:RemoveHitbox(target.Model)
		end
	end))
end

function THS:CreateHitbox(target)
	self:BindTargetSafety(target)
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

	if LocalPlayer.Character and part:IsDescendantOf(LocalPlayer.Character) then
		return false
	end

	self:SaveOriginalPart(part)

	pcall(function()
		part.Size = Vector3.new(size, size, size)
		part.Transparency = self.Config.HitboxTransparency
		part.Color = color
		part.Material = Enum.Material.Neon
		part.CanCollide = false
		part.CanTouch = self.Config.HitboxCanTouch
		part.CanQuery = true
		part.Massless = true
		part.CastShadow = false
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
	self:DisconnectTargetConnections(model)
end

function THS:ClearHitboxes()
	for model in pairs(self.Runtime.Hitboxes) do
		self:RemoveHitbox(model)
	end

	-- Seguridad extra por si alguna parte quedó guardada fuera de la tabla del modelo.
	for part in pairs(self.Runtime.OriginalParts) do
		self:RestorePart(part)
	end

	for model in pairs(self.Runtime.TargetConnections) do
		self:DisconnectTargetConnections(model)
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
--// OPTIMIZATION ENGINE
--//====================================================

function THS:SetPerformancePreset(mode)
	local presets = {
		Calidad = {
			UpdateRate = 0.03,
			NPCCacheRate = 1,
			MaxTargets = 100,
			UseDistanceLimit = false,
			TargetMaxDistance = 1000,
			AutoCleanInterval = 3,
		},

		Balanceado = {
			UpdateRate = 0.05,
			NPCCacheRate = 2,
			MaxTargets = 50,
			UseDistanceLimit = true,
			TargetMaxDistance = 600,
			AutoCleanInterval = 3,
		},

		Movil = {
			UpdateRate = 0.08,
			NPCCacheRate = 3,
			MaxTargets = 35,
			UseDistanceLimit = true,
			TargetMaxDistance = 450,
			AutoCleanInterval = 2.5,
		},

		Ligero = {
			UpdateRate = 0.15,
			NPCCacheRate = 4,
			MaxTargets = 20,
			UseDistanceLimit = true,
			TargetMaxDistance = 300,
			AutoCleanInterval = 2,
		},
	}

	local data = presets[mode]
	if not data then
		return
	end

	for key, value in pairs(data) do
		self.Config[key] = value
	end

	self.Config.AutoCleanStale = true
	self.Runtime.PerformanceMode = mode
	self.Runtime.CurrentProfileName = "Manual"
	self.Runtime.UnsavedChanges = true
	self:ClearHitboxes()
	self:RefreshDebugPanel(true)
end

function THS:AutoCleanStaleHitboxes()
	local removed = 0

	for model, visual in pairs(self.Runtime.Hitboxes) do
		local shouldRemove = false

		if not model or not model.Parent then
			shouldRemove = true
		else
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")

			if not humanoid or humanoid.Health <= 0 or not root then
				shouldRemove = true
			end
		end

		if shouldRemove then
			self:RemoveHitbox(model)
			removed += 1
		end
	end

	if removed > 0 then
		self:RefreshDebugPanel(true)
	end
end



--//====================================================
--// COMPATIBILITY / POLISH ENGINE
--//====================================================

function THS:SetCompatibilityPreset(mode)
	self:ClearHitboxes()

	if mode == "PC" then
		self.Config.HitboxMode = "Global"
		self.Config.HitboxSize = 8
		self.Config.HitboxTransparency = 0.65
		self.Config.HitboxCanTouch = true
		self.Config.ShowPlayers = true
		self.Config.ShowNPCs = false
		self.Config.TeamCheck = false
		self.Config.UseDistanceLimit = true
		self.Config.TargetMaxDistance = 600
		self.Config.UpdateRate = 0.05
		self.Runtime.CompatibilityMode = "PC"

	elseif mode == "Movil" then
		self.Config.HitboxMode = "Global"
		self.Config.HitboxSize = 14
		self.Config.HitboxTransparency = 0.75
		self.Config.HitboxCanTouch = true
		self.Config.ShowPlayers = true
		self.Config.ShowNPCs = false
		self.Config.TeamCheck = false
		self.Config.UseDistanceLimit = true
		self.Config.TargetMaxDistance = 450
		self.Config.UpdateRate = 0.08
		self.Runtime.CompatibilityMode = "Móvil"

	elseif mode == "NPCs" then
		self.Config.HitboxMode = "Global"
		self.Config.HitboxSize = 10
		self.Config.HitboxTransparency = 0.65
		self.Config.HitboxCanTouch = true
		self.Config.ShowPlayers = false
		self.Config.ShowNPCs = true
		self.Config.TeamCheck = false
		self.Config.UseDistanceLimit = true
		self.Config.TargetMaxDistance = 700
		self.Config.UpdateRate = 0.06
		self.Runtime.CompatibilityMode = "NPCs"

	elseif mode == "Visible" then
		self.Config.HitboxTransparency = 0.35
		self.Config.ColorMode = "Manual"
		self.Config.HitboxColor = Color3.fromRGB(0, 220, 255)
		self.Runtime.CompatibilityMode = "Visible"

	elseif mode == "Invisible" then
		self.Config.HitboxTransparency = 1
		self.Config.HitboxCanTouch = true
		self.Runtime.CompatibilityMode = "Invisible"

	elseif mode == "PartesBasico" then
		self.Config.HitboxMode = "Partes"
		self.Config.UseHeadHitbox = true
		self.Config.UseTorsoHitbox = true
		self.Config.UseArmsHitbox = false
		self.Config.UseLegsHitbox = false
		self.Config.HeadHitboxSize = 6
		self.Config.TorsoHitboxSize = 9
		self.Config.HitboxTransparency = 0.65
		self.Config.HitboxCanTouch = true
		self.Runtime.CompatibilityMode = "Partes básico"
	end

	self.Runtime.CurrentProfileName = "Manual"
	self.Runtime.UnsavedChanges = true
	self:RefreshDebugPanel(true)
end

function THS:EmergencyRestoreAndReactivate()
	local wasSystemEnabled = self.Config.SystemEnabled
	local wasHitboxEnabled = self.Config.HitboxEnabled

	self:ClearHitboxes()

	self.Config.SystemEnabled = wasSystemEnabled
	self.Config.HitboxEnabled = wasHitboxEnabled
	self.Runtime.LastUpdate = 0
	self.Runtime.CompatibilityMode = "Restaurado"
	self:RefreshDebugPanel(true)
end



--//====================================================
--// FINAL DEMO ENGINE
--//====================================================

function THS:ApplyFinalRecommendedSetup()
	self:ClearHitboxes()
	self.Config.SystemEnabled = true
	self.Config.HitboxEnabled = true
	self.Config.HitboxMode = "Global"
	self.Config.HitboxSize = 8
	self.Config.HitboxTransparency = 0.65
	self.Config.HitboxCanTouch = true
	self.Config.ShowPlayers = true
	self.Config.ShowNPCs = false
	self.Config.TeamCheck = false
	self.Config.ColorMode = "Manual"
	self.Config.UseDistanceLimit = true
	self.Config.TargetMaxDistance = 600
	self.Config.UpdateRate = 0.05
	self.Config.MaxTargets = 50
	self.Runtime.CurrentProfileName = "Final recomendado"
	self.Runtime.PerformanceMode = "Balanceado"
	self.Runtime.CompatibilityMode = "Final recomendado"
	self.Runtime.FinalStatus = "Setup final aplicado"
	self.Runtime.UnsavedChanges = true
	self:RefreshDebugPanel(true)
end

function THS:ApplyFinalMobileSetup()
	self:ClearHitboxes()
	self.Config.SystemEnabled = true
	self.Config.HitboxEnabled = true
	self.Config.HitboxMode = "Global"
	self.Config.HitboxSize = 14
	self.Config.HitboxTransparency = 0.75
	self.Config.HitboxCanTouch = true
	self.Config.ShowPlayers = true
	self.Config.ShowNPCs = false
	self.Config.TeamCheck = false
	self.Config.ColorMode = "Manual"
	self.Config.UseDistanceLimit = true
	self.Config.TargetMaxDistance = 450
	self.Config.UpdateRate = 0.08
	self.Config.MaxTargets = 35
	self.Runtime.CurrentProfileName = "Final móvil"
	self.Runtime.PerformanceMode = "Móvil"
	self.Runtime.CompatibilityMode = "Final móvil"
	self.Runtime.FinalStatus = "Setup móvil aplicado"
	self.Runtime.UnsavedChanges = true
	self:RefreshDebugPanel(true)
end

function THS:ApplyFinalNPCSetup()
	self:ClearHitboxes()
	self.Config.SystemEnabled = true
	self.Config.HitboxEnabled = true
	self.Config.HitboxMode = "Global"
	self.Config.HitboxSize = 10
	self.Config.HitboxTransparency = 0.65
	self.Config.HitboxCanTouch = true
	self.Config.ShowPlayers = false
	self.Config.ShowNPCs = true
	self.Config.TeamCheck = false
	self.Config.ColorMode = "Type"
	self.Config.UseDistanceLimit = true
	self.Config.TargetMaxDistance = 700
	self.Config.UpdateRate = 0.06
	self.Config.MaxTargets = 70
	self.Runtime.CurrentProfileName = "Final NPCs"
	self.Runtime.PerformanceMode = "Balanceado"
	self.Runtime.CompatibilityMode = "Final NPCs"
	self.Runtime.FinalStatus = "Setup NPCs aplicado"
	self.Runtime.UnsavedChanges = true
	self:RefreshDebugPanel(true)
end

function THS:FinalEmergencyClean()
	self:ClearHitboxes()
	self.Runtime.FinalStatus = "Limpieza final ejecutada"
	self:RefreshDebugPanel(true)
end


--//====================================================
--// PROFILE ENGINE INICIAL
--//====================================================

function THS:CopyProfileFromConfig()
	local profile = {}

	for _, key in ipairs(ProfileKeys) do
		profile[key] = self.Config[key]
	end

	return profile
end

function THS:ApplyProfileData(profileName, data)
	if not data then
		return
	end

	self:ClearHitboxes()

	for key, value in pairs(data) do
		if self.Config[key] ~= nil then
			self.Config[key] = value
		end
	end

	self.Runtime.CurrentProfileName = profileName or "Manual"
	self.Runtime.UnsavedChanges = true
	self:RefreshDebugPanel(true)
end

function THS:ApplyBuiltInProfile(profileName)
	local data = BuiltInProfiles[profileName]
	if not data then
		return
	end

	self:ApplyProfileData(profileName, data)
end

function THS:SaveProfileSlot(slotName)
	self.Runtime.SavedProfiles[slotName] = self:CopyProfileFromConfig()
	self.Runtime.CurrentProfileName = slotName .. " guardado"
	self.Runtime.UnsavedChanges = false
end

function THS:LoadProfileSlot(slotName)
	local data = self.Runtime.SavedProfiles[slotName]
	if not data then
		self:SetPageInfo("El " .. slotName .. " todavía está vacío.\n\nPrimero configura el THS y presiona Guardar " .. slotName .. ".")
		return
	end

	self:ApplyProfileData(slotName, data)
end

function THS:GetProfileSlotStatus(slotName)
	return self.Runtime.SavedProfiles[slotName] and "guardado" or "vacío"
end

function THS:MarkManualProfile()
	self.Runtime.CurrentProfileName = "Manual"
end



--//====================================================
--// SAVE ENGINE PORTABLE
--//====================================================

function THS:EncodePortableValue(value)
	if typeof(value) == "Color3" then
		return {
			__type = "Color3",
			r = math.floor(value.R * 255 + 0.5),
			g = math.floor(value.G * 255 + 0.5),
			b = math.floor(value.B * 255 + 0.5),
		}
	end

	return value
end

function THS:DecodePortableValue(value)
	if type(value) == "table" and value.__type == "Color3" then
		return Color3.fromRGB(
			clampNumber(value.r, 0, 255),
			clampNumber(value.g, 0, 255),
			clampNumber(value.b, 0, 255)
		)
	end

	return value
end

function THS:CreatePortableSaveCode()
	local profile = self:CopyProfileFromConfig()
	local encodedProfile = {}

	for key, value in pairs(profile) do
		encodedProfile[key] = self:EncodePortableValue(value)
	end

	local package = {
		System = "THS",
		Version = "1.6-A",
		Mode = "PortableConfig",
		ProfileName = tostring(self.Runtime.CurrentProfileName or "Manual"),
		Config = encodedProfile,
	}

	local ok, result = pcall(function()
		return HttpService:JSONEncode(package)
	end)

	if ok then
		self.Runtime.LastExportCode = result
		self.Runtime.LastSaveStatus = "Código generado correctamente."
		return result
	end

	self.Runtime.LastSaveStatus = "Error al generar código: " .. tostring(result)
	return ""
end

function THS:ImportPortableSaveCode(code)
	local rawCode = tostring(code or "")
	self.Runtime.LastImportCode = rawCode

	if rawCode == "" then
		self.Runtime.LastSaveStatus = "Pega un código antes de importar."
		return false
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(rawCode)
	end)

	if not ok or type(decoded) ~= "table" then
		self.Runtime.LastSaveStatus = "Código inválido o incompleto."
		return false
	end

	if decoded.System ~= "THS" or type(decoded.Config) ~= "table" then
		self.Runtime.LastSaveStatus = "Ese código no parece ser un perfil THS."
		return false
	end

	local importedConfig = {}

	for key, value in pairs(decoded.Config) do
		if self.Config[key] ~= nil then
			importedConfig[key] = self:DecodePortableValue(value)
		end
	end

	self:ApplyProfileData("Importado", importedConfig)
	self.Runtime.LastSaveStatus = "Perfil importado correctamente."
	return true
end

function THS:CreateTextBox(parent, label, y, defaultText, height, onFocusLost, helpText)
	height = height or 80

	local row = create("Frame", {
		Name = label .. "_TextBoxRow",
		Size = UDim2.fromOffset(760, height + 35),
		Position = UDim2.fromOffset(0, y),
		BackgroundTransparency = 1,
	}, parent)

	create("TextLabel", {
		Size = UDim2.fromOffset(520, 24),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local box = create("TextBox", {
		Size = UDim2.fromOffset(650, height),
		Position = UDim2.fromOffset(0, 28),
		BackgroundColor3 = Theme.PanelLight,
		Text = tostring(defaultText or ""),
		PlaceholderText = "Pega o copia aquí...",
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.MutedText,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ClearTextOnFocus = false,
		MultiLine = true,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, box)

	local help = create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(660, 28),
		BackgroundColor3 = Theme.PanelLight,
		Text = "ⓘ",
		TextColor3 = Theme.MutedText,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, help)

	connect(box.FocusLost, function()
		if onFocusLost then
			onFocusLost(box.Text)
		end
	end)

	connect(help.MouseButton1Click, function()
		self:SetPageInfo("ⓘ " .. label .. "\n\n" .. (helpText or "Sin descripción."))
	end)

	return box
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
		"\nPerfil: " .. tostring(self.Runtime.CurrentProfileName) ..
		"\nRendimiento: " .. tostring(self.Runtime.PerformanceMode) ..
		"\nCompatibilidad: " .. tostring(self.Runtime.CompatibilityMode) ..
		"\nFinal: " .. tostring(self.Runtime.FinalStatus) ..
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
		self:MarkManualProfile()
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
			"\nPerfil: " .. tostring(self.Runtime.CurrentProfileName) ..
			"\nCompatibilidad: " .. tostring(self.Runtime.CompatibilityMode) ..
			"\n\nAtajos:" ..
			"\nRightShift = abrir/cerrar menú" ..
			"\nH = activar/desactivar THS"
		)

		self:CreateToggle(options, "Activar THS", 0, "SystemEnabled", "Activa o desactiva el sistema principal THS.")

	elseif page == "Hitbox" then
		self:SetPageInfo("Configura la hitbox real estable. Al activar Hitbox real, el daño queda en manos del arma predeterminada del juego. No hay botón extra ni pestaña de daño.")
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

		self:CreateToggle(options, "CanTouch armas", 145, "HitboxCanTouch", "Déjalo activo si tus armas/proyectiles usan eventos Touched.")

		if self.Config.HitboxMode == "Global" then
			self:CreateNumberControl(options, "Tamaño global", 200, "HitboxSize", 1, 40, 1, "Tamaño del HumanoidRootPart agrandado.")
		else
			self:CreateToggle(options, "Cabeza", 200, "UseHeadHitbox", "Activa hitbox real de cabeza.")
			if self.Config.UseHeadHitbox then
				self:CreateNumberControl(options, "Tamaño cabeza", 245, "HeadHitboxSize", 1, 25, 1, "Tamaño real aplicado a la cabeza.")
			end

			self:CreateToggle(options, "Torso", 300, "UseTorsoHitbox", "Activa hitbox real de torso.")
			if self.Config.UseTorsoHitbox then
				self:CreateNumberControl(options, "Tamaño torso", 345, "TorsoHitboxSize", 1, 30, 1, "Tamaño real aplicado al torso.")
			end

			self:CreateToggle(options, "Brazos", 400, "UseArmsHitbox", "Activa hitboxes reales para brazos.")
			if self.Config.UseArmsHitbox then
				self:CreateNumberControl(options, "Tamaño brazos", 445, "ArmsHitboxSize", 1, 25, 1, "Tamaño real aplicado a los brazos.")
			end

			self:CreateToggle(options, "Piernas", 500, "UseLegsHitbox", "Activa hitboxes reales para piernas.")
			if self.Config.UseLegsHitbox then
				self:CreateNumberControl(options, "Tamaño piernas", 545, "LegsHitboxSize", 1, 25, 1, "Tamaño real aplicado a las piernas.")
			end
		end

	elseif page == "Objetivos" then
		self:SetPageInfo("Elige qué tipos de objetivos reciben hitbox real.")
		self:CreateToggle(options, "Mostrar jugadores", 0, "ShowPlayers", "Incluye jugadores como objetivos.")
		self:CreateToggle(options, "Mostrar NPCs", 45, "ShowNPCs", "Incluye modelos con Humanoid y HumanoidRootPart.")
		self:CreateToggle(options, "Team Check", 90, "TeamCheck", "Si está activo, ignora jugadores de tu mismo equipo.")

	elseif page == "Perfiles" then
		self:SetPageInfo(
			"Profile Engine inicial." ..
			"\n\nPerfil actual: " .. tostring(self.Runtime.CurrentProfileName) ..
			"\nSlot 1: " .. self:GetProfileSlotStatus("Slot 1") ..
			" | Slot 2: " .. self:GetProfileSlotStatus("Slot 2") ..
			" | Slot 3: " .. self:GetProfileSlotStatus("Slot 3") ..
			"\n\nLos slots se guardan durante esta sesión del juego. Más adelante hacemos Save Engine persistente."
		)

		self:CreateButton(options, "Preset Recomendado", 0, function()
			self:ApplyBuiltInProfile("Recomendado")
		end, "Perfil equilibrado para pruebas generales.")

		self:CreateButton(options, "Preset Grande", 45, function()
			self:ApplyBuiltInProfile("Grande")
		end, "Aumenta la hitbox global sin tocar configuración de daño.")

		self:CreateButton(options, "Preset Móvil", 90, function()
			self:ApplyBuiltInProfile("Movil")
		end, "Hitbox global más grande para pruebas en teléfono.")

		self:CreateButton(options, "Preset NPCs", 135, function()
			self:ApplyBuiltInProfile("NPCs")
		end, "Prioriza NPCs y dummies/modelos con Humanoid.")

		self:CreateButton(options, "Preset Cabeza", 180, function()
			self:ApplyBuiltInProfile("Cabeza")
		end, "Modo por partes enfocado solo en cabeza.")

		self:CreateButton(options, "Preset Torso", 225, function()
			self:ApplyBuiltInProfile("Torso")
		end, "Modo por partes enfocado solo en torso.")

		self:CreateButton(options, "Guardar Slot 1", 285, function()
			self:SaveProfileSlot("Slot 1")
		end, "Guarda la configuración actual en Slot 1.")

		self:CreateButton(options, "Cargar Slot 1", 330, function()
			self:LoadProfileSlot("Slot 1")
		end, "Carga la configuración guardada en Slot 1.")

		self:CreateButton(options, "Guardar Slot 2", 375, function()
			self:SaveProfileSlot("Slot 2")
		end, "Guarda la configuración actual en Slot 2.")

		self:CreateButton(options, "Cargar Slot 2", 420, function()
			self:LoadProfileSlot("Slot 2")
		end, "Carga la configuración guardada en Slot 2.")

		self:CreateButton(options, "Guardar Slot 3", 465, function()
			self:SaveProfileSlot("Slot 3")
		end, "Guarda la configuración actual en Slot 3.")

		self:CreateButton(options, "Cargar Slot 3", 510, function()
			self:LoadProfileSlot("Slot 3")
		end, "Carga la configuración guardada en Slot 3.")

	elseif page == "Guardar" then
		self:SetPageInfo(
			"Save Engine portable." ..
			"\n\nSirve para guardar y mover tu configuración manualmente." ..
			"\nEstado: " .. tostring(self.Runtime.LastSaveStatus) ..
			"\n\nNo usa DataStore todavía. Copias el código generado y después lo puedes importar."
		)

		local exportBox = self:CreateTextBox(
			options,
			"Código exportado",
			0,
			self.Runtime.LastExportCode,
			115,
			function(value)
				self.Runtime.LastExportCode = value
			end,
			"Presiona Generar código actual y copia este texto. Ese código guarda tu configuración actual."
		)

		self:CreateButton(options, "Generar código actual", 155, function()
			self.Runtime.LastExportCode = self:CreatePortableSaveCode()
			exportBox.Text = self.Runtime.LastExportCode
		end, "Genera un código con la configuración actual de THS.")

		self:CreateButton(options, "Exportar preset móvil", 200, function()
			self:ApplyBuiltInProfile("Movil")
			self.Runtime.LastExportCode = self:CreatePortableSaveCode()
			exportBox.Text = self.Runtime.LastExportCode
		end, "Aplica el preset móvil y genera su código.")

		local importBox = self:CreateTextBox(
			options,
			"Código para importar",
			260,
			self.Runtime.LastImportCode,
			115,
			function(value)
				self.Runtime.LastImportCode = value
			end,
			"Pega aquí un código THS exportado y luego presiona Importar código."
		)

		self:CreateButton(options, "Importar código pegado", 415, function()
			self:ImportPortableSaveCode(importBox.Text)
		end, "Carga la configuración del código pegado.")

		self:CreateButton(options, "Limpiar códigos", 460, function()
			self.Runtime.LastExportCode = ""
			self.Runtime.LastImportCode = ""
			self.Runtime.LastSaveStatus = "Códigos limpiados."
		end, "Limpia los cuadros de exportación/importación.")


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

	elseif page == "Compatibilidad" then
		self:SetPageInfo(
			"Compatibility/Polish Engine." ..
			"\n\nModo actual: " .. tostring(self.Runtime.CompatibilityMode) ..
			"\nEstos botones son ajustes rápidos para no tocar muchas opciones manualmente." ..
			"\n\nRecomendación: si estás en teléfono, usa Setup móvil. Si pruebas NPCs, usa Setup NPCs."
		)

		self:CreateButton(options, "Setup PC", 0, function()
			self:SetCompatibilityPreset("PC")
		end, "Configuración equilibrada para PC con mouse/clic izquierdo.")

		self:CreateButton(options, "Setup móvil", 45, function()
			self:SetCompatibilityPreset("Movil")
		end, "Hitbox más grande y rendimiento más ligero para teléfono.")

		self:CreateButton(options, "Setup NPCs", 90, function()
			self:SetCompatibilityPreset("NPCs")
		end, "Activa NPCs y dummies, desactiva jugadores.")

		self:CreateButton(options, "Setup partes básico", 135, function()
			self:SetCompatibilityPreset("PartesBasico")
		end, "Modo por partes simple: cabeza y torso activos.")

		self:CreateButton(options, "Modo visible", 195, function()
			self:SetCompatibilityPreset("Visible")
		end, "Hace la hitbox más visible para debug y pruebas.")

		self:CreateButton(options, "Modo invisible", 240, function()
			self:SetCompatibilityPreset("Invisible")
		end, "Hace la hitbox invisible, pero mantiene CanTouch activo.")

		self:CreateButton(options, "Restaurar y reactivar", 300, function()
			self:EmergencyRestoreAndReactivate()
		end, "Restaura partes modificadas y mantiene el estado activo/inactivo actual.")

		self:CreateToggle(options, "CanTouch armas", 360, "HitboxCanTouch", "Déjalo activo si tus armas/proyectiles usan eventos Touched.")
		self:CreateToggle(options, "Team Check", 405, "TeamCheck", "Evita aplicar hitbox a jugadores de tu mismo equipo.")
		self:CreateToggle(options, "Mostrar NPCs", 450, "ShowNPCs", "Activa NPCs/dummies/modelos con Humanoid.")

	elseif page == "Rendimiento" then
		self:SetPageInfo(
			"Optimization Engine." ..
			"\n\nModo actual: " .. tostring(self.Runtime.PerformanceMode) ..
			"\nUpdate Rate: " .. tostring(self.Config.UpdateRate) ..
			"\nMáx. objetivos: " .. tostring(self.Config.MaxTargets) ..
			"\nDistancia límite: " .. (self.Config.UseDistanceLimit and tostring(self.Config.TargetMaxDistance) or "Desactivada") ..
			"\nAuto limpieza: " .. (self.Config.AutoCleanStale and "ACTIVA" or "DESACTIVADA")
		)

		self:CreateButton(options, "Preset Calidad", 0, function()
			self:SetPerformancePreset("Calidad")
		end, "Más fluido y más objetivos. Úsalo si tu juego va bien de FPS.")

		self:CreateButton(options, "Preset Balanceado", 45, function()
			self:SetPerformancePreset("Balanceado")
		end, "Configuración recomendada para la mayoría de pruebas.")

		self:CreateButton(options, "Preset Móvil", 90, function()
			self:SetPerformancePreset("Movil")
		end, "Más ligero para teléfono, con distancia limitada.")

		self:CreateButton(options, "Preset Ligero", 135, function()
			self:SetPerformancePreset("Ligero")
		end, "Modo de bajo consumo: menos objetivos y actualizaciones más separadas.")

		self:CreateNumberControl(options, "Update Rate", 195, "UpdateRate", 0.01, 0.5, 0.01, "Tiempo entre actualizaciones. Menor = más fluido, mayor = más ligero.")
		self:CreateNumberControl(options, "Máx. objetivos", 250, "MaxTargets", 1, 120, 1, "Límite de objetivos procesados.")
		self:CreateToggle(options, "Límite distancia", 305, "UseDistanceLimit", "Procesa solo objetivos dentro de la distancia máxima.")
		self:CreateNumberControl(options, "Distancia máx.", 350, "TargetMaxDistance", 50, 2000, 50, "Distancia máxima para procesar objetivos.")
		self:CreateToggle(options, "Auto limpieza", 405, "AutoCleanStale", "Limpia hitboxes muertas, eliminadas o inválidas automáticamente.")
		self:CreateNumberControl(options, "Intervalo limpieza", 450, "AutoCleanInterval", 1, 10, 0.5, "Cada cuántos segundos hace una limpieza automática.")

		self:CreateButton(options, "Limpiar hitboxes", 510, function()
			self:ClearHitboxes()
		end, "Restaura todas las partes modificadas y limpia las hitboxes reales activas.")

	elseif page == "Debug" then
		local targetVisuals, boxCount = self:GetActiveHitboxStats()
		self:SetPageInfo(
			"Debug Engine inicial. Hitbox real estable activa cuando THS + Hitbox real están encendidos." ..
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

	elseif page == "Final" then
		self:SetPageInfo(
			"THS V2.0 Demo Completa." ..
			"\n\nEstado: " .. tostring(self.Runtime.FinalStatus) ..
			"\n\nEsta versión conserva el método que ya funcionó:" ..
			"\nHitbox real + arma normal del juego = daño predeterminado." ..
			"\n\nChecklist final:" ..
			"\n1. Activar THS." ..
			"\n2. Activar Hitbox real." ..
			"\n3. Usar Modo Global." ..
			"\n4. Dejar CanTouch armas activo." ..
			"\n5. Disparar con el arma normal del juego."
		)

		self:CreateButton(options, "Aplicar setup final", 0, function()
			self:ApplyFinalRecommendedSetup()
		end, "Activa THS y deja configuración balanceada lista para probar.")

		self:CreateButton(options, "Aplicar setup móvil", 45, function()
			self:ApplyFinalMobileSetup()
		end, "Activa THS con tamaño mayor y rendimiento más ligero para teléfono.")

		self:CreateButton(options, "Aplicar setup NPCs", 90, function()
			self:ApplyFinalNPCSetup()
		end, "Activa THS para NPCs/dummies/modelos con Humanoid.")

		self:CreateButton(options, "Modo invisible final", 150, function()
			self.Config.HitboxTransparency = 1
			self.Config.HitboxCanTouch = true
			self.Runtime.FinalStatus = "Modo invisible final aplicado"
		end, "Deja la hitbox invisible pero funcional para armas.")

		self:CreateButton(options, "Modo visible debug", 195, function()
			self.Config.HitboxTransparency = 0.35
			self.Config.HitboxColor = Color3.fromRGB(0, 220, 255)
			self.Runtime.FinalStatus = "Modo visible debug aplicado"
		end, "Deja la hitbox visible para revisar tamaño y posición.")

		self:CreateButton(options, "Limpieza final", 255, function()
			self:FinalEmergencyClean()
		end, "Restaura todas las partes modificadas por THS.")

		self:CreateButton(options, "Generar código final", 300, function()
			self.Runtime.LastExportCode = self:CreatePortableSaveCode()
			self.Runtime.FinalStatus = "Código final generado en pestaña Guardar"
		end, "Genera código portable de la configuración actual para la pestaña Guardar.")

	elseif page == "Ayuda" then
		self:SetPageInfo(
			"AYUDA THS" ..
			"\n\nEl THS V2.0 agranda partes reales del personaje." ..
			"\nNo agrega botón extra ni pestaña de daño." ..
			"\nEl daño lo hace el arma predeterminada del juego si detecta esas partes.
Ahora incluye perfiles, Save Engine portable, Optimization Engine, Compatibility Engine y pestaña Final." ..
			"\n\nRightShift = abrir/cerrar menú" ..
			"\nH = activar/desactivar THS" ..
			"\nArrastra la parte superior para mover el panel." ..
			"\nArrastra la bolita para mover el botón flotante."
		)

	elseif page == "Acerca de" then
		self:SetPageInfo(
			"THS - Tactical Hitbox System" ..
			"\n\nVersión: V2.0" ..
			"\nEstado: Hitbox real estable para daño predeterminado" ..
			"\nProyecto 2/3" ..
			"\n\nObjetivo: hitbox real para que tus armas puedan impactar con su daño predeterminado." ..
			"\n\nProyecto 2/3 cerrado como demo completa. Siguiente paso posible: versión Library modular."
		)
	end

	if options then
		if page == "Hitbox" and self.Config.HitboxMode == "Partes" then
			options.CanvasSize = UDim2.fromOffset(860, 620)
		elseif page == "Perfiles" then
			options.CanvasSize = UDim2.fromOffset(860, 650)
		elseif page == "Guardar" then
			options.CanvasSize = UDim2.fromOffset(860, 620)
		elseif page == "Compatibilidad" then
			options.CanvasSize = UDim2.fromOffset(860, 560)
		elseif page == "Rendimiento" then
			options.CanvasSize = UDim2.fromOffset(860, 620)
		elseif page == "Final" then
			options.CanvasSize = UDim2.fromOffset(860, 460)
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
		"Perfiles",
		"Guardar",
		"Colores",
		"Compatibilidad",
		"Rendimiento",
		"Debug",
		"Final",
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

	if self.Config.AutoCleanStale and now - self.Runtime.LastAutoClean >= self.Config.AutoCleanInterval then
		self.Runtime.LastAutoClean = now
		self:AutoCleanStaleHitboxes()
	end

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

	print("[THS] Tactical Hitbox System V2.0 Demo Completa iniciado.")
end

THS:Init()
