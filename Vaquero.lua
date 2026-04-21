local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera
end)

Camera.CameraType = Enum.CameraType.Custom

-- Limpieza
local old = CoreGui:FindFirstChild("DEVTOOL")
if old then old:Destroy() end

-- ============================================================
-- FARM
-- ============================================================

local character = nil
local hrp = nil
local robRemote = nil
spawn(function()
	robRemote = RS:WaitForChild("GeneralEvents"):WaitForChild("Rob")
end)
local MAX_BAG = 40
local safes = {}
local autoRobEnabled = false

local function getCharacter()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	repeat wait() until char:FindFirstChild("HumanoidRootPart")
	return char, char:WaitForChild("HumanoidRootPart")
end
local function initializeCharacter() character, hrp = getCharacter() end
initializeCharacter()
LocalPlayer.CharacterAdded:Connect(function() wait(1) initializeCharacter() end)

for _, v in pairs(workspace:GetDescendants()) do
	if v.Name == "Safe" then table.insert(safes, v) end
end

local function getBagMoney()
	local states = LocalPlayer:FindFirstChild("States")
	if states then local bag = states:FindFirstChild("Bag") if bag then return bag.Value end end
	return 0
end

local function safeTeleport(safe)
	local part = safe:FindFirstChild("SafePart")
	if not part then return end
	local forward = part.CFrame.LookVector
	local pos = part.Position + (forward * 5) + Vector3.new(0, 3, 0)
	hrp.CFrame = CFrame.new(pos, part.Position)
end

local function getBestSafe()
	local best = nil local minDist = math.huge
	for _, safe in pairs(safes) do
		local part = safe:FindFirstChild("SafePart")
		if part then
			local dist = (hrp.Position - part.Position).Magnitude
			if dist < minDist then minDist = dist best = safe end
		end
	end
	return best
end

local function robSafe(safe)
	safeTeleport(safe) wait(0.6)
	local openEvent = safe:FindFirstChild("OpenSafe")
	if openEvent then openEvent:FireServer("Complete") wait(1) end
	robRemote:FireServer("Safe", safe)
	wait(2)
end

spawn(function()
	while true do
		wait(0.4)
		if autoRobEnabled then
			if not character or not hrp then initializeCharacter() end
			local currentBag = getBagMoney()
			if currentBag >= MAX_BAG then repeat wait(1) until getBagMoney() < MAX_BAG end
			local target = getBestSafe()
			if target then robSafe(target) end
		end
	end
end)

-- ============================================================
-- ESP + AIM + HITBOX
-- ============================================================

local espEnabled = true
local aimEnabled = true
local hitboxEnabled = false
local currentTarget = nil
local targetLockTime = 0
local MAX_DISTANCE = 800
local FOV_RADIUS = 200
local LOCK_DURATION = 0.3
local friendlyTargets = {}
local lastHealth = 100

local function isCowboy() return LocalPlayer.Team and LocalPlayer.Team.Name == "Cowboys" end
local function isOutlaw() return LocalPlayer.Team and LocalPlayer.Team.Name == "Outlaws" end
local function isCivilian() return LocalPlayer.Team and LocalPlayer.Team.Name == "Civilians" end
local function isEnemy(p)
	if not p.Team then return false end
	if isCowboy() then return p.Team.Name == "Outlaws" end
	if isOutlaw() then return p.Team.Name ~= "Outlaws" or friendlyTargets[p] end
	if isCivilian() then return p.Team.Name == "Outlaws" end
	return p.Team ~= LocalPlayer.Team
end

local teamColors = {
	Civilians = Color3.fromRGB(0,120,255),
	Cowboys   = Color3.fromRGB(255,220,0),
	Outlaws   = Color3.fromRGB(255,50,50)
}

local function applyHighlight(char, color)
	if not char then return end
	local e = char:FindFirstChild("ESP_HIGHLIGHT")
	if e then e:Destroy() end
	local h = Instance.new("Highlight")
	h.Name = "ESP_HIGHLIGHT"
	h.FillColor = color
	h.OutlineColor = Color3.new(1,1,1)
	h.FillTransparency = 0.3
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = char
	h.Parent = char
end

local function applyESP(player)
	local function onChar(char)
		if not espEnabled then return end
		if not player.Team then
			local t = 0
			repeat task.wait(0.1) t += 1 until player.Team or t > 30
		end
		if not player.Team then return end
		local color = teamColors[player.Team.Name]
		if color then applyHighlight(char, color) end
	end
	if player.Character then task.spawn(onChar, player.Character) end
	player.CharacterAdded:Connect(function(c) task.spawn(onChar, c) end)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		if player.Character then task.spawn(onChar, player.Character) end
	end)
end

-- HITBOX
local function applyHitbox(player)
	local function onChar(char)
		task.wait(0.5)
		if not hitboxEnabled then return end
		local hrpPart = char:FindFirstChild("HumanoidRootPart")
		if not hrpPart then return end
		local old = hrpPart:FindFirstChild("HITBOX_ESP")
		if old then old:Destroy() end
		local box = Instance.new("SelectionBox")
		box.Name = "HITBOX_ESP"
		box.Adornee = hrpPart
		box.Color3 = Color3.fromRGB(0, 255, 0)
		box.LineThickness = 0.04
		box.SurfaceTransparency = 0.7
		box.SurfaceColor3 = Color3.fromRGB(0, 255, 0)
		box.Parent = hrpPart
	end
	if player.Character then task.spawn(onChar, player.Character) end
	player.CharacterAdded:Connect(function(c) task.spawn(onChar, c) end)
end

local function enableHitboxESP()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then applyHitbox(p) end
	end
end

local function disableHitboxESP()
	for _, p in ipairs(Players:GetPlayers()) do
		if p and p.Character then
			local hrpPart = p.Character:FindFirstChild("HumanoidRootPart")
			if hrpPart then
				local box = hrpPart:FindFirstChild("HITBOX_ESP")
				if box then box:Destroy() end
			end
		end
	end
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then applyESP(p) end end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then applyESP(p) end end)

local function setupHealthDetection()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:WaitForChild("Humanoid")
	lastHealth = hum.Health
	hum.HealthChanged:Connect(function(hp)
		if hp < lastHealth and isOutlaw() then
			local att, shortest = nil, math.huge
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer and p.Character and p.Team == LocalPlayer.Team then
					local head = p.Character:FindFirstChild("Head")
					if head then
						local d = (head.Position - Camera.CFrame.Position).Magnitude
						if d < shortest then shortest = d att = p end
					end
				end
			end
			if att then
				friendlyTargets[att] = true
				if att.Character then applyHighlight(att.Character, Color3.fromRGB(0,0,0)) end
			end
		end
		lastHealth = hp
	end)
end

if LocalPlayer.Character then setupHealthDetection() end
LocalPlayer.CharacterAdded:Connect(function() wait(1) setupHealthDetection() end)

-- ============================================================
-- GUI (tu diseño exacto)
-- ============================================================

local function tween(inst, t, props, style, dir)
	TweenService:Create(inst, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props):Play()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "DEVTOOL"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = CoreGui

local Panel = Instance.new("Frame")
Panel.Name             = "Panel"
Panel.Size             = UDim2.new(0, 260, 0, 230)
Panel.AnchorPoint      = Vector2.new(0.5, 0.5)
Panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
Panel.BackgroundColor3 = Color3.fromRGB(16, 17, 24)
Panel.BorderSizePixel  = 0
Panel.Active           = true
Panel.Draggable        = true
Panel.Visible          = true
Panel.ClipsDescendants = true
Panel.Parent           = Gui
local panelCorner = Instance.new("UICorner", Panel) panelCorner.CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new("UIStroke", Panel)
panelStroke.Color = Color3.fromRGB(70, 80, 140) panelStroke.Thickness = 1 panelStroke.Transparency = 0.35
local panelGrad = Instance.new("UIGradient", Panel)
panelGrad.Rotation = 90
panelGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(26, 28, 42)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(14, 15, 22)),
}

local glow = Instance.new("ImageLabel", Panel)
glow.BackgroundTransparency = 1
glow.AnchorPoint     = Vector2.new(0.5, 0.5)
glow.Position        = UDim2.new(0.5, 0, 0.5, 0)
glow.Size            = UDim2.new(1, 40, 1, 40)
glow.ZIndex          = 0
glow.Image           = "rbxassetid://5028857084"
glow.ImageColor3     = Color3.fromRGB(80, 90, 200)
glow.ImageTransparency = 0.75
glow.ScaleType       = Enum.ScaleType.Slice
glow.SliceCenter     = Rect.new(24, 24, 276, 276)

local TitleBar = Instance.new("Frame", Panel)
TitleBar.Size             = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 32, 52)
TitleBar.BorderSizePixel  = 0
local titleCorner = Instance.new("UICorner", TitleBar) titleCorner.CornerRadius = UDim.new(0, 12)
local tbCap = Instance.new("Frame", TitleBar)
tbCap.Size = UDim2.new(1,0,0.5,0) tbCap.Position = UDim2.new(0,0,0.5,0)
tbCap.BackgroundColor3 = TitleBar.BackgroundColor3 tbCap.BorderSizePixel = 0 tbCap.BackgroundTransparency = 1
local titleGrad = Instance.new("UIGradient", TitleBar)
titleGrad.Rotation = 25
titleGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(64, 70, 170)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 44, 90)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(90, 55, 170)),
}
local Title = Instance.new("TextLabel", TitleBar)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1,-60,1,0) Title.Position = UDim2.new(0,12,0,0)
Title.Text = "✦  DEV TOOL" Title.TextColor3 = Color3.fromRGB(235,235,255)
Title.TextSize = 13 Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left

local pulse = Instance.new("Frame", TitleBar)
pulse.AnchorPoint = Vector2.new(1,0.5) pulse.Position = UDim2.new(1,-12,0.5,0)
pulse.Size = UDim2.new(0,8,0,8) pulse.BackgroundColor3 = Color3.fromRGB(110,230,160) pulse.BorderSizePixel = 0
local pulseCorner = Instance.new("UICorner", pulse) pulseCorner.CornerRadius = UDim.new(1,0)
task.spawn(function()
	while pulse.Parent do
		tween(pulse, 0.7, {BackgroundTransparency=0.6}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) task.wait(0.75)
		tween(pulse, 0.7, {BackgroundTransparency=0.0}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) task.wait(0.75)
	end
end)

local TabFrame = Instance.new("Frame", Panel)
TabFrame.Size = UDim2.new(0,70,1,-36) TabFrame.Position = UDim2.new(0,4,0,32)
TabFrame.BackgroundColor3 = Color3.fromRGB(22,23,34) TabFrame.BorderSizePixel = 0
local tabCorner = Instance.new("UICorner", TabFrame) tabCorner.CornerRadius = UDim.new(0,10)
local tabStroke = Instance.new("UIStroke", TabFrame) tabStroke.Color = Color3.fromRGB(45,48,75) tabStroke.Transparency = 0.3
local tabLayout = Instance.new("UIListLayout", TabFrame)
tabLayout.Padding = UDim.new(0,4) tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local tabPad = Instance.new("UIPadding", TabFrame) tabPad.PaddingTop = UDim.new(0,6)

local Content = Instance.new("Frame", Panel)
Content.Size = UDim2.new(1,-82,1,-38) Content.Position = UDim2.new(0,78,0,33)
Content.BackgroundTransparency = 1 Content.ClipsDescendants = true

local FOVFrame = Instance.new("Frame", Gui)
FOVFrame.Size = UDim2.new(0,FOV_RADIUS*2,0,FOV_RADIUS*2)
FOVFrame.AnchorPoint = Vector2.new(0.5,0.5) FOVFrame.Position = UDim2.new(0.5,0,0.5,0)
FOVFrame.BackgroundTransparency = 1 FOVFrame.Visible = true
local fsc = Instance.new("UIStroke", FOVFrame) fsc.Color = Color3.fromRGB(255,255,255) fsc.Thickness = 1 fsc.Transparency = 0.3
local fcc = Instance.new("UICorner", FOVFrame) fcc.CornerRadius = UDim.new(1,0)

local pages = {}
local tabBtns = {}
local currentPage

local function makePage()
	local p = Instance.new("Frame")
	p.Size = UDim2.new(1,0,1,0) p.Position = UDim2.new(0.05,0,0,0)
	p.BackgroundTransparency = 1 p.Visible = false p.Parent = Content
	local l = Instance.new("UIListLayout", p) l.Padding = UDim.new(0,5)
	return p
end

local function makeTab(name)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0,62,0,30) b.BackgroundColor3 = Color3.fromRGB(30,32,48)
	b.BackgroundTransparency = 1 b.BorderSizePixel = 0 b.AutoButtonColor = false
	b.Text = name b.TextColor3 = Color3.fromRGB(150,155,185)
	b.TextSize = 11 b.Font = Enum.Font.GothamBold b.Parent = TabFrame
	local c = Instance.new("UICorner", b) c.CornerRadius = UDim.new(0,7)
	b.MouseEnter:Connect(function()
		if currentPage ~= name then tween(b, 0.15, {BackgroundTransparency=0.3, TextColor3=Color3.fromRGB(210,215,240)}) end
	end)
	b.MouseLeave:Connect(function()
		if currentPage ~= name then tween(b, 0.2, {BackgroundTransparency=1, TextColor3=Color3.fromRGB(150,155,185)}) end
	end)
	return b
end

local function makeToggle(parent, text, state, cb)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1,-6,0,28) row.BackgroundColor3 = Color3.fromRGB(26,28,42) row.BorderSizePixel = 0
	local rc = Instance.new("UICorner", row) rc.CornerRadius = UDim.new(0,7)
	local rs = Instance.new("UIStroke", row) rs.Color = Color3.fromRGB(45,48,72) rs.Transparency = 0.4
	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(1,-48,1,0) lbl.Position = UDim2.new(0,8,0,0)
	lbl.BackgroundTransparency = 1 lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(220,222,240) lbl.TextSize = 11
	lbl.Font = Enum.Font.Gotham lbl.TextXAlignment = Enum.TextXAlignment.Left
	local pill = Instance.new("TextButton", row)
	pill.AutoButtonColor = false pill.Text = ""
	pill.Size = UDim2.new(0,32,0,16) pill.AnchorPoint = Vector2.new(1,0.5)
	pill.Position = UDim2.new(1,-8,0.5,0) pill.BorderSizePixel = 0
	pill.BackgroundColor3 = state and Color3.fromRGB(70,200,130) or Color3.fromRGB(55,58,82)
	local pc = Instance.new("UICorner", pill) pc.CornerRadius = UDim.new(1,0)
	local dot = Instance.new("Frame", pill)
	dot.Size = UDim2.new(0,12,0,12) dot.AnchorPoint = Vector2.new(0,0.5)
	dot.Position = state and UDim2.new(1,-14,0.5,0) or UDim2.new(0,2,0.5,0)
	dot.BackgroundColor3 = Color3.new(1,1,1) dot.BorderSizePixel = 0
	local dc = Instance.new("UICorner", dot) dc.CornerRadius = UDim.new(1,0)
	local on = state
	pill.MouseButton1Click:Connect(function()
		on = not on
		tween(pill, 0.18, {BackgroundColor3 = on and Color3.fromRGB(70,200,130) or Color3.fromRGB(55,58,82)})
		tween(dot, 0.22, {Position = on and UDim2.new(1,-14,0.5,0) or UDim2.new(0,2,0.5,0)}, Enum.EasingStyle.Back)
		if cb then cb(on) end
	end)
	row.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement then tween(row, 0.15, {BackgroundColor3=Color3.fromRGB(32,35,52)}) end
	end)
	row.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement then tween(row, 0.2, {BackgroundColor3=Color3.fromRGB(26,28,42)}) end
	end)
end

local function makeInfo(parent, text, val)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1,-6,0,28) row.BackgroundColor3 = Color3.fromRGB(26,28,42) row.BorderSizePixel = 0
	local rc = Instance.new("UICorner", row) rc.CornerRadius = UDim.new(0,7)
	local rs = Instance.new("UIStroke", row) rs.Color = Color3.fromRGB(45,48,72) rs.Transparency = 0.4
	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.6,-4,1,0) lbl.Position = UDim2.new(0,8,0,0)
	lbl.BackgroundTransparency = 1 lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(200,204,225) lbl.TextSize = 10
	lbl.Font = Enum.Font.Gotham lbl.TextXAlignment = Enum.TextXAlignment.Left
	local v = Instance.new("TextLabel", row)
	v.Size = UDim2.new(0.4,-8,1,0) v.Position = UDim2.new(0.6,0,0,0)
	v.BackgroundTransparency = 1 v.Text = val
	v.TextColor3 = Color3.fromRGB(120,190,255) v.TextSize = 11
	v.Font = Enum.Font.GothamBold v.TextXAlignment = Enum.TextXAlignment.Right
	return v
end

local function showPage(name)
	local target = pages[name]
	if not target then return end
	for n,b in pairs(tabBtns) do
		if n==name then tween(b, 0.2, {BackgroundTransparency=0, BackgroundColor3=Color3.fromRGB(55,60,150), TextColor3=Color3.fromRGB(255,255,255)})
		else tween(b, 0.2, {BackgroundTransparency=1, TextColor3=Color3.fromRGB(150,155,185)}) end
	end
	if currentPage and pages[currentPage] and currentPage ~= name then
		local o = pages[currentPage]
		tween(o, 0.15, {Position=UDim2.new(-0.05,0,0,0)})
		task.delay(0.15, function() o.Visible = false end)
	end
	target.Position = UDim2.new(0.08,0,0,0)
	target.Visible = true
	for _, c in ipairs(target:GetChildren()) do
		if c:IsA("Frame") then c.BackgroundTransparency=1 tween(c, 0.25, {BackgroundTransparency=0}) end
	end
	tween(target, 0.25, {Position=UDim2.new(0,0,0,0)}, Enum.EasingStyle.Quint)
	currentPage = name
end

-- PÁGINAS
local combatPage = makePage()
makeToggle(combatPage, "Aim Assist", aimEnabled, function(val)
	aimEnabled = val currentTarget = nil FOVFrame.Visible = val
end)
makeToggle(combatPage, "ESP", espEnabled, function(val)
	espEnabled = val
	if not val then
		for _,p in ipairs(Players:GetPlayers()) do
			if p.Character then local h=p.Character:FindFirstChild("ESP_HIGHLIGHT") if h then h:Destroy() end end
		end
	else
		for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then applyESP(p) end end
	end
end)
makeToggle(combatPage, "Hitbox ESP 🟩", false, function(val)
	hitboxEnabled = val
	if val then enableHitboxESP()
	else disableHitboxESP() end
end)

local teamsPage = makePage()
local cowV = makeInfo(teamsPage, "🤠 Cowboys", "0")
local outV = makeInfo(teamsPage, "🔴 Outlaws", "0")
local civV = makeInfo(teamsPage, "🔵 Civilians", "0")
local myV  = makeInfo(teamsPage, "👤 Mi equipo", "—")

local farmPage = makePage()
makeToggle(farmPage, "Auto-Rob", false, function(val) autoRobEnabled = val end)
local bagV = makeInfo(farmPage, "💰 Bolsa", "0")

tabBtns["Combat"] = makeTab("Combat")
tabBtns["Teams"]  = makeTab("Teams")
tabBtns["Farm"]   = makeTab("Farm")
pages["Combat"]   = combatPage
pages["Teams"]    = teamsPage
pages["Farm"]     = farmPage

tabBtns["Combat"].MouseButton1Click:Connect(function() showPage("Combat") end)
tabBtns["Teams"] .MouseButton1Click:Connect(function() showPage("Teams")  end)
tabBtns["Farm"]  .MouseButton1Click:Connect(function() showPage("Farm")   end)

task.defer(function() showPage("Combat") end)

RunService.Heartbeat:Connect(function()
	local cow,out,civ=0,0,0
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Team then
			if p.Team.Name=="Cowboys" then cow+=1
			elseif p.Team.Name=="Outlaws" then out+=1
			elseif p.Team.Name=="Civilians" then civ+=1
			end
		end
	end
	cowV.Text=tostring(cow) outV.Text=tostring(out) civV.Text=tostring(civ)
	myV.Text=LocalPlayer.Team and LocalPlayer.Team.Name or "—"
	bagV.Text=tostring(getBagMoney())
end)

-- ANIMACIÓN PANEL
local panelScale = Instance.new("UIScale", Panel) panelScale.Scale = 1
local panelOpen = true local animating = false

local function openPanel()
	if animating or panelOpen then return end
	animating = true panelOpen = true Panel.Visible = true
	tween(panelScale, 0.2, {Scale=1}, Enum.EasingStyle.Quad)
	tween(Panel, 0.18, {BackgroundTransparency=0})
	tween(panelStroke, 0.18, {Transparency=0.35})
	tween(glow, 0.22, {ImageTransparency=0.75})
	task.delay(0.2, function() animating = false end)
end

local function closePanel()
	if animating or not panelOpen then return end
	animating = true panelOpen = false
	tween(panelScale, 0.16, {Scale=0.9}, Enum.EasingStyle.Quad)
	tween(Panel, 0.14, {BackgroundTransparency=1})
	tween(panelStroke, 0.14, {Transparency=1})
	tween(glow, 0.14, {ImageTransparency=1})
	task.delay(0.16, function() Panel.Visible = false animating = false end)
end

-- BOLITA
local Dot = Instance.new("TextButton", Gui)
Dot.Size = UDim2.new(0,38,0,38) Dot.Position = UDim2.new(0,14,0.5,-19)
Dot.BackgroundColor3 = Color3.fromRGB(65,70,190) Dot.BorderSizePixel = 0
Dot.Text = "✦" Dot.TextColor3 = Color3.fromRGB(255,255,255)
Dot.TextSize = 18 Dot.Font = Enum.Font.GothamBold
Dot.AutoButtonColor = false Dot.ZIndex = 20 Dot.Active = true
local dc = Instance.new("UICorner", Dot) dc.CornerRadius = UDim.new(1,0)
local ds = Instance.new("UIStroke", Dot) ds.Thickness = 1.5 ds.Color = Color3.fromRGB(150,160,255) ds.Transparency = 0.2
local dotGrad = Instance.new("UIGradient", Dot)
dotGrad.Rotation = 60
dotGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(90,100,230)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150,70,210)),
}
local halo = Instance.new("ImageLabel", Dot)
halo.BackgroundTransparency = 1 halo.AnchorPoint = Vector2.new(0.5,0.5)
halo.Position = UDim2.new(0.5,0,0.5,0) halo.Size = UDim2.new(1,20,1,20)
halo.ZIndex = 19 halo.Image = "rbxassetid://5028857084"
halo.ImageColor3 = Color3.fromRGB(120,130,255) halo.ImageTransparency = 0.6
halo.ScaleType = Enum.ScaleType.Slice halo.SliceCenter = Rect.new(24,24,276,276)
task.spawn(function()
	while Dot.Parent do
		tween(halo, 1.0, {ImageTransparency=0.85, Size=UDim2.new(1,30,1,30)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) task.wait(1.05)
		tween(halo, 1.0, {ImageTransparency=0.55, Size=UDim2.new(1,18,1,18)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) task.wait(1.05)
	end
end)
local dotScale = Instance.new("UIScale", Dot) dotScale.Scale = 1
Dot.MouseEnter:Connect(function() tween(dotScale, 0.15, {Scale=1.08}) end)
Dot.MouseLeave:Connect(function() tween(dotScale, 0.15, {Scale=1.00}) end)

local dragging,dragStart,startPos,touchStart=false,nil,nil,0
local moved = 0
Dot.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
		dragging=true dragStart=i.Position startPos=Dot.Position touchStart=tick() moved=0
		tween(dotScale, 0.1, {Scale=0.92})
	end
end)
Dot.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then
		local d=i.Position-dragStart moved=math.max(moved, d.Magnitude)
		Dot.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end)
Dot.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
		tween(dotScale, 0.15, {Scale=1})
		if tick()-touchStart<0.25 and moved<10 then
			if Panel.Visible then closePanel() tween(Dot, 0.2, {BackgroundColor3=Color3.fromRGB(190,60,70)})
			else openPanel() tween(Dot, 0.2, {BackgroundColor3=Color3.fromRGB(65,70,190)}) end
		end
		dragging=false
	end
end)

-- AIM
local function isFirstPerson()
	return (Camera.Focus.Position-Camera.CFrame.Position).Magnitude<1
end

local function getClosestTarget()
	local closest,shortest=nil,math.huge
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=LocalPlayer and p.Character and p.Team and isEnemy(p) then
			local hum=p.Character:FindFirstChild("Humanoid")
			local part=p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health>0 and part then
				local wd=(part.Position-Camera.CFrame.Position).Magnitude
				if wd<MAX_DISTANCE then
					local pos=Camera:WorldToViewportPoint(part.Position)
					local center=Camera.ViewportSize/2
					local dist=(Vector2.new(pos.X,pos.Y)-center).Magnitude
					if dist<shortest and dist<FOV_RADIUS then shortest=dist closest=part end
				end
			end
		end
	end
	return closest
end

RunService.RenderStepped:Connect(function()
	if not aimEnabled then FOVFrame.Visible=false return end
	if not Camera then return end
	if not isFirstPerson() then FOVFrame.Visible=false currentTarget=nil return end
	FOVFrame.Visible=true
	if currentTarget then
		local hum=currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid")
		if not currentTarget.Parent or not hum or hum.Health<=0 then currentTarget=nil targetLockTime=0 end
	end
	if not currentTarget or (tick()-targetLockTime)>LOCK_DURATION then
		local nt=getClosestTarget()
		if nt and nt~=currentTarget then currentTarget=nt targetLockTime=tick() end
	end
	if currentTarget then
		Camera.CFrame=CFrame.new(Camera.CFrame.Position,currentTarget.Position)
	end
end)
