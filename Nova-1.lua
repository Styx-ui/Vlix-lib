--[[
	Nova UI Library v1.0.1
	Fixed:
	- Full mobile / touch support (drag, sliders, color picker, toggles, etc.)
	- Connection leaks (all UserInputService connections are now cleaned on Destroy)
	- Minimize properly hides content instead of leaving elements hanging
	- Ripple works on mobile
	- Keybind system no longer stacks global listeners
	- Safer input helpers (IsPrimary / IsMove)
	- Small robustness improvements
]]

local Nova = {
	Themes = {},
	Windows = {},
	Flags = {},
	Icons = {},
	ConfigFolder = "Nova_Configs",
	CurrentTheme = nil,
	Version = "1.0.1",
}

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse()

-- ─── Helpers ────────────────────────────────────────────────────────────────

local function IsPrimary(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function Tween(obj, t, props, style, dir)
	local info = TweenInfo.new(t, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end

local function Spring(obj, t, props)
	return Tween(obj, t, props, Enum.EasingStyle.Spring, Enum.EasingDirection.Out)
end

local function Back(obj, t, props)
	return Tween(obj, t, props, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function Round(r, p)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
	return c
end

local function Stroke(p, col, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = col or Color3.fromRGB(255,255,255)
	s.Thickness = thick or 1
	s.Transparency = trans or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function Pad(p, t, b, l, r)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop    = UDim.new(0, t or 0)
	pad.PaddingBottom = UDim.new(0, b or 0)
	pad.PaddingLeft   = UDim.new(0, l or 0)
	pad.PaddingRight  = UDim.new(0, r or 0)
	pad.Parent = p
	return pad
end

local function List(p, dir, pad, align, cross)
	local l = Instance.new("UIListLayout")
	l.FillDirection       = dir   or Enum.FillDirection.Vertical
	l.Padding             = UDim.new(0, pad or 0)
	l.SortOrder           = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	l.VerticalAlignment   = cross or Enum.VerticalAlignment.Top
	l.Parent = p
	return l
end

local function Grid(p, cellSize, cellPad)
	local g = Instance.new("UIGridLayout")
	g.CellSize     = cellSize or UDim2.fromOffset(100, 80)
	g.CellPaddingH = UDim2.fromOffset(cellPad or 6, 0)
	g.CellPaddingV = UDim2.fromOffset(0, cellPad or 6)
	g.SortOrder    = Enum.SortOrder.LayoutOrder
	g.Parent = p
	return g
end

local function New(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		obj[k] = v
	end
	if parent then obj.Parent = parent end
	return obj
end

local function Elevate(c, amt)
	amt = amt or 0.06
	local lum = 0.299*c.R + 0.587*c.G + 0.114*c.B
	if lum > 0.5 then
		return Color3.new(math.max(0,c.R-amt), math.max(0,c.G-amt), math.max(0,c.B-amt))
	end
	return Color3.new(math.min(1,c.R+amt), math.min(1,c.G+amt), math.min(1,c.B+amt))
end

local function Lerp(a, b, t) return a + (b - a) * t end

local function NormalizeImage(input)
	if not input then return "" end
	if type(input) == "number" then return "rbxassetid://"..tostring(input) end
	if type(input) ~= "string" or input == "" then return "" end
	if input:match("^rbxassetid://") or input:match("^rbxthumb://") or input:match("^rbxasset://") then return input end
	if input:match("^%d+$") then return "rbxassetid://"..input end
	if input:match("^https?://") then
		if writefile and isfile and getcustomasset and makefolder and isfolder then
			local safe = input:gsub("[^%w]","_")
			local folder = "Nova_Cache"
			local path = folder.."/"..safe..".png"
			local ok = pcall(function()
				if not isfolder(folder) then makefolder(folder) end
				if not isfile(path) then writefile(path, game:HttpGet(input)) end
			end)
			if ok then
				local aok, aid = pcall(function() return getcustomasset(path) end)
				if aok and aid then return aid end
			end
		end
		return ""
	end
	return input
end

local function ResolveIcon(key)
	if not key then return "", false end
	if type(key) == "number" then return "rbxassetid://"..tostring(key), true end
	if type(key) == "string" then
		if key:match("^rbxassetid://") or key:match("^%d+$") then return NormalizeImage(key), true end
		if key:match("^https?://") then return NormalizeImage(key), true end
		if Nova.Icons[key] then return NormalizeImage(Nova.Icons[key]), true end
	end
	return "", false
end

local function Img(parent, src, size, color, trans, z)
	local resolved, custom = ResolveIcon(src)
	if resolved == "" then return nil end
	local img = New("ImageLabel", {
		Size = size or UDim2.fromOffset(16,16),
		BackgroundTransparency = 1,
		Image = resolved,
		ImageColor3 = (custom and Color3.new(1,1,1)) or (color or Color3.new(1,1,1)),
		ImageTransparency = trans or 0,
		ZIndex = z or 5,
	}, parent)
	return img
end

local function Ripple(btn, accent)
	btn.ClipsDescendants = true
	btn.MouseButton1Click:Connect(function()
		local absPos = btn.AbsolutePosition
		local absSize = btn.AbsoluteSize
		-- Prefer last input position (works on mobile + PC)
		local mx, my = absSize.X/2, absSize.Y/2
		local ok, loc = pcall(function() return UserInputService:GetMouseLocation() end)
		if ok and loc then
			mx = loc.X - absPos.X
			my = loc.Y - absPos.Y
		elseif Mouse then
			mx = (Mouse.X or 0) - absPos.X
			my = (Mouse.Y or 0) - absPos.Y
		end
		local circle = New("Frame", {
			BackgroundColor3 = accent or Color3.new(1,1,1),
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5,0.5),
			ZIndex = (btn.ZIndex or 1) + 10,
			Size = UDim2.fromOffset(0,0),
			Position = UDim2.fromOffset(mx, my),
		}, btn)
		Round(200, circle)
		local target = math.max(absSize.X, absSize.Y) * 2
		Tween(circle, 0.5, {
			Size = UDim2.fromOffset(target, target),
			BackgroundTransparency = 1,
		})
		task.delay(0.5, function()
			if circle and circle.Parent then circle:Destroy() end
		end)
	end)
end

local function Glow(parent, color, radius, trans)
	local g = New("Frame", {
		Size = UDim2.new(1, radius*2, 1, radius*2),
		Position = UDim2.new(0, -radius, 0, -radius),
		BackgroundColor3 = color,
		BackgroundTransparency = trans or 0.82,
		ZIndex = (parent.ZIndex or 1) - 1,
		BorderSizePixel = 0,
	}, parent)
	Round(radius + 8, g)
	return g
end

local function PulseGlow(frame, color)
	local go = true
	task.spawn(function()
		while go and frame and frame.Parent do
			Tween(frame, 1.2, {BackgroundTransparency = 0.7}, Enum.EasingStyle.Sine)
			task.wait(1.2)
			if not (frame and frame.Parent) then break end
			Tween(frame, 1.2, {BackgroundTransparency = 0.88}, Enum.EasingStyle.Sine)
			task.wait(1.2)
		end
	end)
	return function() go = false end
end

local function MakeGradient(parent, c0, c1, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rot or 90
	g.Parent = parent
	return g
end

-- ─── Icons ──────────────────────────────────────────────────────────────────

local IconSources = {
	"https://raw.githubusercontent.com/danhub-67/Leehub-library/refs/heads/main/Icons.lua",
	"https://raw.githubusercontent.com/danhub-67/Leehub-library/refs/heads/main/Icons2.lua",
	"https://raw.githubusercontent.com/danhub-67/Leehub-library/refs/heads/main/Icons3.lua",
	"https://raw.githubusercontent.com/danhub-67/Leehub-library/refs/heads/main/Icons4.lua",
}

for _, url in ipairs(IconSources) do
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and res and res ~= "" then
		local lok, icons = pcall(function() return loadstring(res)() end)
		if lok and type(icons) == "table" then
			for k, v in pairs(icons) do
				Nova.Icons[k] = v
			end
		end
	end
end

-- ─── Themes ─────────────────────────────────────────────────────────────────

local function Theme(name, bg, elem, accent, outline, text, sub, toggle, slider, glow)
	return {
		Name       = name,
		Background = Color3.fromHex(bg),
		Element    = Color3.fromHex(elem),
		Accent     = Color3.fromHex(accent),
		Outline    = Color3.fromHex(outline),
		Text       = Color3.fromHex(text),
		SubText    = Color3.fromHex(sub),
		Toggle     = Color3.fromHex(toggle),
		Slider     = Color3.fromHex(slider),
		Glow       = Color3.fromHex(glow),
	}
end

Nova.Themes["Void"]    = Theme("Void",    "#04040A","#08081A","#00E5FF","#00B8D9","#E8F8FF","#5E9BAA","#00E5FF","#00B8D9","#00E5FF")
Nova.Themes["Ember"]   = Theme("Ember",   "#0A0602","#180C03","#FF6B1A","#CC5514","#FFF2EA","#9A6040","#FF6B1A","#CC5514","#FF6B1A")
Nova.Themes["Spectre"] = Theme("Spectre", "#080510","#100D1E","#B464FF","#8A3DD4","#F3EEFF","#7A60AA","#B464FF","#8A3DD4","#B464FF")
Nova.Themes["Mirage"]  = Theme("Mirage",  "#0A040A","#18041A","#FF2DC8","#CC00A0","#FFE8FD","#9A408E","#FF2DC8","#CC00A0","#FF2DC8")
Nova.Themes["Toxin"]   = Theme("Toxin",   "#030A04","#061408","#39FF14","#1ECC00","#EFFFEA","#60A040","#39FF14","#1ECC00","#39FF14")
Nova.Themes["Blaze"]   = Theme("Blaze",   "#0A0000","#1A0000","#FF1744","#CC0033","#FFE8EC","#AA4055","#FF1744","#CC0033","#FF1744")
Nova.Themes["Frost"]   = Theme("Frost",   "#020810","#041020","#40C8FF","#2090CC","#EAF5FF","#5080A0","#40C8FF","#2090CC","#40C8FF")
Nova.Themes["Gold"]    = Theme("Gold",    "#080600","#140E00","#FFD700","#CCAA00","#FFFDE8","#AA9040","#FFD700","#CCAA00","#FFD700")

Nova.ThemeOrder = {"Void","Ember","Spectre","Mirage","Toxin","Blaze","Frost","Gold"}

-- ─── Main GUI ───────────────────────────────────────────────────────────────

local MainGui = Instance.new("ScreenGui")
MainGui.Name = "NovaLibrary"
MainGui.ResetOnSpawn = false
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.DisplayOrder = 999
MainGui.IgnoreGuiInset = true
MainGui.Parent = (gethui and gethui()) or CoreGui

local NotifHolder = New("Frame", {
	Name = "Notifs",
	Size = UDim2.new(0, 280, 1, -20),
	Position = UDim2.new(1, -290, 0, 10),
	BackgroundTransparency = 1,
	ZIndex = 200,
}, MainGui)
List(NotifHolder, Enum.FillDirection.Vertical, 8, nil, Enum.VerticalAlignment.Bottom)

local WatermarkHolder = New("Frame", {
	Name = "Watermark",
	Size = UDim2.new(0, 0, 0, 28),
	AutomaticSize = Enum.AutomaticSize.X,
	Position = UDim2.new(0, 10, 0, 10),
	BackgroundColor3 = Color3.fromHex("#060610"),
	BackgroundTransparency = 0.1,
	ZIndex = 150,
	Visible = false,
}, MainGui)
Round(6, WatermarkHolder)
local WatermarkLabel = New("TextLabel", {
	Size = UDim2.new(1, -20, 1, 0),
	Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = Color3.new(1,1,1),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 151,
}, WatermarkHolder)
local WatermarkStroke = Stroke(WatermarkHolder, Color3.fromHex("#00E5FF"), 1, 0.3)
local WatermarkGlow = Glow(WatermarkHolder, Color3.fromHex("#00E5FF"), 6, 0.88)

function Nova:SetWatermark(config)
	config = config or {}
	local text = config.Text or config.Title or ""
	local T = Nova.CurrentTheme or Nova.Themes.Void
	WatermarkLabel.Text = text
	WatermarkLabel.TextColor3 = T.Text
	WatermarkStroke.Color = T.Accent
	WatermarkGlow.BackgroundColor3 = T.Glow
	WatermarkHolder.BackgroundColor3 = T.Background
	WatermarkHolder.Visible = true
end

function Nova:HideWatermark()
	WatermarkHolder.Visible = false
end

function Nova:GetThemes()
	return Nova.ThemeOrder
end

function Nova:GetFlags()
	return Nova.Flags
end

function Nova:GetFlag(name)
	return Nova.Flags[name]
end

function Nova:SetFlag(name, value)
	Nova.Flags[name] = value
end

function Nova:Toggle(name)
	if Nova.Flags[name] ~= nil then
		Nova.Flags[name] = not Nova.Flags[name]
	end
	return Nova.Flags[name]
end

function Nova:SaveConfig(name)
	name = tostring(name or "default")
	if not (writefile and HttpService) then return false end
	pcall(function()
		if makefolder and isfolder and not isfolder(Nova.ConfigFolder) then
			makefolder(Nova.ConfigFolder)
		end
	end)
	local payload = {}
	for k, v in pairs(Nova.Flags) do
		if typeof(v) == "Color3" then
			payload[k] = {__color=true, R=v.R, G=v.G, B=v.B}
		elseif typeof(v) == "EnumItem" then
			payload[k] = {__enum=true, EnumType=tostring(v.EnumType), Name=v.Name}
		else
			payload[k] = v
		end
	end
	local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
	if not ok then return false end
	local path = Nova.ConfigFolder.."/"..name..".json"
	return pcall(function() writefile(path, encoded) end) == true
end

function Nova:LoadConfig(name)
	name = tostring(name or "default")
	if not (readfile and isfile and HttpService) then return false end
	local path = Nova.ConfigFolder.."/"..name..".json"
	if not isfile(path) then return false end
	local ok, raw = pcall(function() return readfile(path) end)
	if not ok or not raw then return false end
	local dok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not dok or type(data) ~= "table" then return false end
	for k, v in pairs(data) do
		if type(v) == "table" and v.__color then
			Nova.Flags[k] = Color3.new(v.R, v.G, v.B)
		elseif type(v) == "table" and v.__enum then
			local root = Enum[v.EnumType]
			if root and root[v.Name] then
				Nova.Flags[k] = root[v.Name]
			else
				Nova.Flags[k] = v
			end
		else
			Nova.Flags[k] = v
		end
	end
	return true
end

function Nova:DeleteConfig(name)
	name = tostring(name or "default")
	if not (isfile and delfile) then return false end
	local path = Nova.ConfigFolder.."/"..name..".json"
	if not isfile(path) then return false end
	return pcall(function() delfile(path) end) == true
end

function Nova:ListConfigs()
	if not (isfolder and listfiles) then return {} end
	if not isfolder(Nova.ConfigFolder) then return {} end
	local files = listfiles(Nova.ConfigFolder)
	local configs = {}
	for _, f in ipairs(files) do
		local name = f:match("([^/\\]+)%.json$")
		if name then table.insert(configs, name) end
	end
	return configs
end

function Nova:Notify(config)
	config = config or {}
	local title    = config.Title   or "Nova"
	local content  = config.Content or config.Text or ""
	local duration = config.Duration or 4
	local ntype    = config.Type    or "Info"
	local T = Nova.CurrentTheme or Nova.Themes.Void

	local typeAccents = {
		Success = Color3.fromHex("#39FF14"),
		Error   = Color3.fromHex("#FF1744"),
		Warning = Color3.fromHex("#FFD700"),
		Info    = T.Accent,
	}
	local accent = typeAccents[ntype] or T.Accent

	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = T.Element,
		BackgroundTransparency = 0.1,
		ClipsDescendants = true,
		ZIndex = 201,
	}, NotifHolder)
	Round(10, frame)
	Stroke(frame, accent, 1, 0.35)

	local glowFrame = New("Frame", {
		Size = UDim2.new(1, 14, 1, 14),
		Position = UDim2.new(0,-7,0,-7),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.88,
		ZIndex = 200,
		BorderSizePixel = 0,
	}, frame)
	Round(14, glowFrame)

	local bar = New("Frame", {
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = accent,
		ZIndex = 203,
	}, frame)
	Round(2, bar)

	local barGlow = New("Frame", {
		Size = UDim2.new(1, 10, 1, 10),
		Position = UDim2.new(0,-5,0,-5),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.75,
		ZIndex = 202,
	}, bar)
	Round(6, barGlow)

	local titleLbl = New("TextLabel", {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = T.Text,
		Position = UDim2.new(0, 20, 0, 10),
		Size = UDim2.new(1, -30, 0, 17),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 203,
	}, frame)

	local contentLbl = New("TextLabel", {
		Text = content,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = T.SubText,
		Position = UDim2.new(0, 20, 0, 29),
		Size = UDim2.new(1, -30, 0, 30),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 203,
	}, frame)

	local progressTrack = New("Frame", {
		Size = UDim2.new(1, -20, 0, 2),
		Position = UDim2.new(0, 10, 1, -8),
		BackgroundColor3 = Elevate(T.Element),
		ZIndex = 204,
	}, frame)
	Round(2, progressTrack)

	local progressFill = New("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = accent,
		ZIndex = 205,
	}, progressTrack)
	Round(2, progressFill)

	Back(frame, 0.35, {Size = UDim2.new(1, 0, 0, 72)})

	task.spawn(function()
		local start = tick()
		while tick() - start < duration do
			local elapsed = tick() - start
			local remaining = 1 - (elapsed / duration)
			if progressFill and progressFill.Parent then
				progressFill.Size = UDim2.new(remaining, 0, 1, 0)
			end
			task.wait()
		end
		if frame and frame.Parent then
			local out = Tween(frame, 0.25, {
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
			})
			out.Completed:Connect(function()
				if frame and frame.Parent then frame:Destroy() end
			end)
		end
	end)
end

function Nova:Success(title, content, dur)
	return Nova:Notify({Title=title or "Success", Content=content or "", Type="Success", Duration=dur or 4})
end

function Nova:Error(title, content, dur)
	return Nova:Notify({Title=title or "Error", Content=content or "", Type="Error", Duration=dur or 4})
end

function Nova:Warn(title, content, dur)
	return Nova:Notify({Title=title or "Warning", Content=content or "", Type="Warning", Duration=dur or 4})
end

function Nova:Info(title, content, dur)
	return Nova:Notify({Title=title or "Info", Content=content or "", Type="Info", Duration=dur or 4})
end

function Nova:KeySystem(config)
	config = config or {}
	local title   = config.Title or "Key System"
	local link    = config.Link  or ""
	local keys    = config.Keys  or {}
	local onOk    = config.OnSuccess or function() end
	local T = Nova.CurrentTheme or Nova.Themes.Void

	local KeyGui = New("ScreenGui", {
		Name = "NovaKeySystem",
		ResetOnSpawn = false,
		DisplayOrder = 1000,
		IgnoreGuiInset = true,
	}, (gethui and gethui()) or CoreGui)

	local backdrop = New("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0,0,0),
		BackgroundTransparency = 0.45,
		ZIndex = 1,
	}, KeyGui)

	local frame = New("Frame", {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Element,
		BackgroundTransparency = 0.05,
		ClipsDescendants = true,
		ZIndex = 2,
	}, KeyGui)
	Round(14, frame)
	Stroke(frame, T.Accent, 1, 0.3)
	Glow(frame, T.Glow, 12, 0.84)

	local header = New("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.2,
		ZIndex = 3,
	}, frame)
	Round(14, header)
	New("Frame", {
		Size = UDim2.new(1,0,0,14),
		Position = UDim2.new(0,0,1,-14),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.2,
		ZIndex = 3,
	}, header)

	local titleLbl = New("TextLabel", {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = T.Text,
		Position = UDim2.new(0, 18, 0, 0),
		Size = UDim2.new(1, -36, 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, header)

	local accentBar = New("Frame", {
		Size = UDim2.new(1, -36, 0, 2),
		Position = UDim2.new(0, 18, 1, -1),
		BackgroundColor3 = T.Accent,
		ZIndex = 4,
	}, header)
	Round(2, accentBar)
	MakeGradient(accentBar, T.Accent, T.Background, 90)

	local inputBg = New("Frame", {
		Size = UDim2.new(1, -36, 0, 38),
		Position = UDim2.new(0, 18, 0, 62),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.2,
		ZIndex = 3,
	}, frame)
	Round(8, inputBg)
	local inputStroke = Stroke(inputBg, T.Outline, 1, 0.5)

	local box = New("TextBox", {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Enter your key...",
		PlaceholderColor3 = T.SubText,
		TextColor3 = T.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		ClearTextOnFocus = false,
		ZIndex = 4,
	}, inputBg)

	box.Focused:Connect(function()
		Tween(inputStroke, 0.2, {Color = T.Accent, Transparency = 0})
	end)
	box.FocusLost:Connect(function()
		Tween(inputStroke, 0.2, {Color = T.Outline, Transparency = 0.5})
	end)

	local getKeyBtn = New("TextButton", {
		Size = UDim2.new(0.5, -22, 0, 34),
		Position = UDim2.new(0, 18, 0, 112),
		BackgroundColor3 = Elevate(T.Element),
		BackgroundTransparency = 0.1,
		Text = "Get Key",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = T.SubText,
		ZIndex = 3,
	}, frame)
	Round(8, getKeyBtn)
	Stroke(getKeyBtn, T.Outline, 1, 0.6)
	Ripple(getKeyBtn, T.Accent)

	local verifyBtn = New("TextButton", {
		Size = UDim2.new(0.5, -22, 0, 34),
		Position = UDim2.new(0.5, 4, 0, 112),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 0,
		Text = "Verify",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = T.Background,
		ZIndex = 3,
	}, frame)
	Round(8, verifyBtn)
	Glow(verifyBtn, T.Glow, 6, 0.8)
	Ripple(verifyBtn, Color3.new(1,1,1))

	Back(frame, 0.4, {Size = UDim2.fromOffset(340, 160)})

	getKeyBtn.MouseButton1Click:Connect(function()
		if setclipboard then pcall(function() setclipboard(link) end) end
	end)

	verifyBtn.MouseButton1Click:Connect(function()
		local entered = box.Text
		local valid = false
		for _, k in ipairs(keys) do
			if k == entered then valid = true break end
		end
		if valid then
			local tw = Tween(frame, 0.2, {Size = UDim2.fromOffset(0,0), BackgroundTransparency = 1})
			Tween(backdrop, 0.2, {BackgroundTransparency = 1})
			tw.Completed:Connect(function()
				KeyGui:Destroy()
				onOk()
			end)
		else
			box.Text = ""
			box.PlaceholderText = "Invalid key. Try again."
			box.PlaceholderColor3 = Color3.fromHex("#FF1744")
			Tween(inputBg, 0.1, {BackgroundColor3 = Color3.fromHex("#1A0000")})
			task.delay(0.1, function()
				Tween(inputBg, 0.2, {BackgroundColor3 = T.Background})
			end)
			task.delay(2, function()
				box.PlaceholderText = "Enter your key..."
				box.PlaceholderColor3 = T.SubText
			end)
		end
	end)
end

-- ─── CreateWindow ───────────────────────────────────────────────────────────

function Nova:CreateWindow(config)
	config = config or {}
	local windowTitle  = config.Title   or "Nova"
	local windowSize   = config.Size    or Vector2.new(640, 440)
	local themeName    = config.Theme   or "Void"
	local toggleKey    = config.ToggleKey or Enum.KeyCode.RightShift
	local logoId       = config.Logo    or nil

	local T = Nova.Themes[themeName] or Nova.Themes["Void"]
	Nova.CurrentTheme = T

	if WatermarkStroke then WatermarkStroke.Color = T.Accent end
	if WatermarkGlow then WatermarkGlow.BackgroundColor3 = T.Glow end
	if WatermarkHolder then WatermarkHolder.BackgroundColor3 = T.Background end
	if WatermarkLabel then WatermarkLabel.TextColor3 = T.Text end

	local Registered = {}
	local TabButtons = {}
	local CurrentTab = nil
	local Visible = true
	local Connections = {} -- all UserInputService connections live here and are cleaned on Destroy

	local function Conn(signal, fn)
		local c = signal:Connect(fn)
		table.insert(Connections, c)
		return c
	end

	local function DisconnectAll()
		for _, c in ipairs(Connections) do
			pcall(function() c:Disconnect() end)
		end
		Connections = {}
	end

	local function ApplyAll()
		for _, entry in ipairs(Registered) do
			if entry.Type == "Frame" then
				if entry.Object then
					if entry.Prop == "BackgroundColor3" then
						entry.Object.BackgroundColor3 = T[entry.Key] or entry.Fallback or T.Element
					end
				end
			elseif entry.Type == "TextColor3" then
				entry.Object.TextColor3 = T[entry.Key] or entry.Fallback or T.Text
			elseif entry.Type == "Stroke" then
				entry.Object.Color = T[entry.Key] or entry.Fallback or T.Outline
			elseif entry.Type == "ImageColor3" then
				entry.Object.ImageColor3 = T[entry.Key] or entry.Fallback or T.Accent
			elseif entry.Type == "Accent" then
				entry.Object.BackgroundColor3 = T.Accent
			elseif entry.Type == "GlowBg" then
				entry.Object.BackgroundColor3 = T.Glow
			end
		end
	end

	local function Reg(t, obj, key, fallback)
		table.insert(Registered, {Type=t, Object=obj, Key=key, Fallback=fallback})
	end

	local screen = New("Frame", {
		Size = UDim2.new(1,0,1,0),
		BackgroundColor3 = Color3.new(0,0,0),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, MainGui)

	local mainFrame = New("Frame", {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0,
		ClipsDescendants = true, -- FIXED: was false, caused elements to hang out
		ZIndex = 11,
	}, screen)
	Round(14, mainFrame)
	Reg("Frame", mainFrame, "Background")

	local mainGlow = Glow(mainFrame, T.Glow, 20, 0.88)
	Reg("GlowBg", mainGlow, "Glow")

	local mainStroke = Stroke(mainFrame, T.Accent, 1, 0.4)
	Reg("Stroke", mainStroke, "Accent")

	local shadowFrame = New("Frame", {
		Size = UDim2.new(1, 40, 1, 40),
		Position = UDim2.new(0,-20,0,-20),
		BackgroundColor3 = Color3.new(0,0,0),
		BackgroundTransparency = 0.5,
		ZIndex = 10,
	}, mainFrame)
	Round(22, shadowFrame)

	local sidebar = New("Frame", {
		Size = UDim2.new(0, 54, 1, 0),
		BackgroundColor3 = T.Element,
		BackgroundTransparency = 0.05,
		ZIndex = 12,
	}, mainFrame)
	Round(14, sidebar)
	New("Frame", {
		Size = UDim2.new(0, 14, 1, 0),
		Position = UDim2.new(1,-14,0,0),
		BackgroundColor3 = T.Element,
		BackgroundTransparency = 0.05,
		ZIndex = 12,
	}, sidebar)
	Reg("Frame", sidebar, "Element")

	local sideAccentBar = New("Frame", {
		Size = UDim2.new(0, 2, 0.7, 0),
		Position = UDim2.new(1, -1, 0.15, 0),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 0.6,
		ZIndex = 13,
	}, sidebar)
	Round(2, sideAccentBar)
	Reg("Accent", sideAccentBar, "Accent")

	local logoArea = New("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 13,
	}, sidebar)

	if logoId then
		local logoImg = Img(logoArea, logoId, UDim2.fromOffset(28,28), T.Accent)
		if logoImg then
			logoImg.Position = UDim2.new(0.5, -14, 0.5, -14)
			logoImg.ZIndex = 14
		end
	else
		local logoTxt = New("TextLabel", {
			Size = UDim2.new(1,0,1,0),
			BackgroundTransparency = 1,
			Text = windowTitle:sub(1,1),
			Font = Enum.Font.GothamBold,
			TextSize = 20,
			TextColor3 = T.Accent,
			ZIndex = 14,
		}, logoArea)
		Reg("TextColor3", logoTxt, "Accent")
	end

	local logoLine = New("Frame", {
		Size = UDim2.new(0, 30, 0, 1),
		Position = UDim2.new(0.5, -15, 1, -1),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 0.7,
		ZIndex = 13,
	}, logoArea)
	Reg("Accent", logoLine, "Accent")

	local tabIconsContainer = New("Frame", {
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.new(0, 0, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 13,
		ClipsDescendants = true,
	}, sidebar)
	List(tabIconsContainer, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
	Pad(tabIconsContainer, 6, 6, 8, 8)

	local contentArea = New("Frame", {
		Size = UDim2.new(1, -54, 1, 0),
		Position = UDim2.new(0, 54, 0, 0),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0,
		ZIndex = 12,
		ClipsDescendants = true,
	}, mainFrame)
	Round(14, contentArea)
	New("Frame", {
		Size = UDim2.new(0, 14, 1, 0),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0,
		ZIndex = 12,
	}, contentArea)
	Reg("Frame", contentArea, "Background")

	local topBar = New("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = T.Element,
		BackgroundTransparency = 0.2,
		ZIndex = 13,
	}, contentArea)
	New("Frame", {
		Size = UDim2.new(1,0,0,14),
		Position = UDim2.new(0,0,1,-14),
		BackgroundColor3 = T.Element,
		BackgroundTransparency = 0.2,
		ZIndex = 13,
	}, topBar)
	Reg("Frame", topBar, "Element")

	local titleLbl = New("TextLabel", {
		Text = windowTitle,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = T.Text,
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 14,
	}, topBar)
	Reg("TextColor3", titleLbl, "Text")

	local titleAccent = New("Frame", {
		Size = UDim2.new(0, 0, 0, 2),
		Position = UDim2.new(0, 16, 1, -1),
		BackgroundColor3 = T.Accent,
		ZIndex = 14,
	}, topBar)
	Round(2, titleAccent)
	Reg("Accent", titleAccent, "Accent")

	local closeBtn = New("TextButton", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -38, 0.5, -14),
		BackgroundColor3 = Elevate(T.Element),
		BackgroundTransparency = 0.3,
		Text = "×",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = T.SubText,
		ZIndex = 14,
	}, topBar)
	Round(7, closeBtn)

	closeBtn.MouseEnter:Connect(function()
		Tween(closeBtn, 0.2, {BackgroundColor3 = Color3.fromHex("#FF1744"), TextColor3 = Color3.new(1,1,1)})
	end)
	closeBtn.MouseLeave:Connect(function()
		Tween(closeBtn, 0.2, {BackgroundColor3 = Elevate(T.Element), TextColor3 = T.SubText})
	end)
	closeBtn.MouseButton1Click:Connect(function()
		local tw = Tween(mainFrame, 0.3, {Size = UDim2.fromOffset(0,0), BackgroundTransparency = 1})
		tw.Completed:Connect(function()
			DisconnectAll()
			screen:Destroy()
		end)
	end)

	local minBtn = New("TextButton", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -72, 0.5, -14),
		BackgroundColor3 = Elevate(T.Element),
		BackgroundTransparency = 0.3,
		Text = "–",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = T.SubText,
		ZIndex = 14,
	}, topBar)
	Round(7, minBtn)

	local isMinimized = false

	minBtn.MouseEnter:Connect(function()
		Tween(minBtn, 0.2, {BackgroundColor3 = T.Accent, TextColor3 = T.Background})
	end)
	minBtn.MouseLeave:Connect(function()
		Tween(minBtn, 0.2, {BackgroundColor3 = Elevate(T.Element), TextColor3 = T.SubText})
	end)
	minBtn.MouseButton1Click:Connect(function()
		isMinimized = not isMinimized
		if isMinimized then
			-- hide everything except top bar
			sidebar.Visible = false
			for _, child in ipairs(contentArea:GetChildren()) do
				if child ~= topBar and not child:IsA("UICorner") then
					child.Visible = false
				end
			end
			Tween(mainFrame, 0.25, {Size = UDim2.fromOffset(windowSize.X, 48)})
		else
			sidebar.Visible = true
			for _, child in ipairs(contentArea:GetChildren()) do
				if child ~= topBar and not child:IsA("UICorner") then
					child.Visible = true
				end
			end
			Spring(mainFrame, 0.5, {Size = UDim2.fromOffset(windowSize.X, windowSize.Y)})
		end
	end)

	local scrollBar = New("Frame", {
		Size = UDim2.new(0, 2, 0, 0),
		Position = UDim2.new(0, 12, 0, 50),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 0.5,
		ZIndex = 14,
	}, contentArea)
	Round(2, scrollBar)

	local scrollConn
	local function UpdateScrollbar(scrollFrame)
		if scrollConn then scrollConn:Disconnect() end
		scrollConn = scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			local total = scrollFrame.AbsoluteCanvasSize.Y
			local vis   = scrollFrame.AbsoluteSize.Y
			if total <= vis then
				scrollBar.Visible = false
				return
			end
			scrollBar.Visible = true
			local ratio = vis / total
			local posRatio = scrollFrame.CanvasPosition.Y / (total - vis)
			local barH = math.max(30, (vis - 50) * ratio)
			scrollBar.Size = UDim2.new(0, 2, 0, barH)
			scrollBar.Position = UDim2.new(0, 12, 0, 50 + posRatio * (vis - 50 - barH))
		end)
	end

	-- ─── Drag (mobile + PC) ─────────────────────────────────────────────────
	local dragging = false
	local dragStart
	local startPos
	local dragInput

	topBar.InputBegan:Connect(function(inp)
		if IsPrimary(inp) then
			dragging = true
			dragStart = inp.Position
			startPos  = mainFrame.Position
			dragInput = inp
		end
	end)

	Conn(UserInputService.InputChanged, function(inp)
		if dragging and (inp == dragInput or IsMove(inp)) then
			local delta = inp.Position - dragStart
			mainFrame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	Conn(UserInputService.InputEnded, function(inp)
		if IsPrimary(inp) then
			dragging = false
			dragInput = nil
		end
	end)

	-- ─── Toggle key ─────────────────────────────────────────────────────────
	Conn(UserInputService.InputBegan, function(inp, gp)
		if not gp and inp.KeyCode == toggleKey then
			Visible = not Visible
			if Visible then
				mainFrame.Visible = true
				isMinimized = false
				sidebar.Visible = true
				for _, child in ipairs(contentArea:GetChildren()) do
					if child ~= topBar and not child:IsA("UICorner") then
						child.Visible = true
					end
				end
				Spring(mainFrame, 0.5, {Size = UDim2.fromOffset(windowSize.X, windowSize.Y)})
			else
				local tw = Tween(mainFrame, 0.25, {Size = UDim2.fromOffset(0,0)})
				tw.Completed:Connect(function() mainFrame.Visible = false end)
			end
		end
	end)

	mainFrame.Visible = true
	mainFrame.Size = UDim2.fromOffset(windowSize.X * 0.05, windowSize.Y * 0.05)
	task.defer(function()
		Spring(mainFrame, 0.6, {Size = UDim2.fromOffset(windowSize.X, windowSize.Y)})
	end)

	task.spawn(function()
		task.wait(0.1)
		local textWidth = TextService:GetTextSize(windowTitle, 15, Enum.Font.GothamBold, Vector2.new(9999, 20)).X
		Spring(titleAccent, 0.5, {Size = UDim2.new(0, textWidth, 0, 2)})
	end)

	local Window = {}

	function Window:ChangeTheme(name)
		local nt = Nova.Themes[name]
		if not nt then return end
		T = nt
		Nova.CurrentTheme = T
		ApplyAll()
	end

	function Window:SetTitle(text)
		titleLbl.Text = text
	end

	function Window:Toggle()
		Visible = not Visible
		if Visible then
			mainFrame.Visible = true
			Spring(mainFrame, 0.5, {Size = UDim2.fromOffset(windowSize.X, windowSize.Y)})
		else
			local tw = Tween(mainFrame, 0.25, {Size = UDim2.fromOffset(0,0)})
			tw.Completed:Connect(function() mainFrame.Visible = false end)
		end
	end

	function Window:Destroy()
		DisconnectAll()
		local tw = Tween(mainFrame, 0.3, {Size = UDim2.fromOffset(0,0), BackgroundTransparency = 1})
		tw.Completed:Connect(function() screen:Destroy() end)
	end

	function Window:CreateTab(tabConfig)
		tabConfig = tabConfig or {}
		local tabName = tabConfig.Name  or tabConfig.Title or "Tab"
		local tabIcon = tabConfig.Icon  or nil

		local tabBtn = New("TextButton", {
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = T.Background,
			BackgroundTransparency = 0.4,
			Text = "",
			ZIndex = 14,
			AutoButtonColor = false,
		}, tabIconsContainer)
		Round(10, tabBtn)
		local tabBtnStroke = Stroke(tabBtn, T.Outline, 1, 0.8)
		Reg("Stroke", tabBtnStroke, "Outline")

		local tabBtnGlow = New("Frame", {
			Size = UDim2.new(1, 14, 1, 14),
			Position = UDim2.new(0,-7,0,-7),
			BackgroundColor3 = T.Accent,
			BackgroundTransparency = 1,
			ZIndex = 13,
		}, tabBtn)
		Round(14, tabBtnGlow)

		local tabIndicator = New("Frame", {
			Size = UDim2.new(0, 3, 0, 0),
			Position = UDim2.new(0, -5, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = T.Accent,
			ZIndex = 15,
		}, tabBtn)
		Round(2, tabIndicator)

		if tabIcon then
			local ico = Img(tabBtn, tabIcon, UDim2.fromOffset(18,18), T.SubText, 0, 15)
			if ico then
				ico.Position = UDim2.new(0.5,-9,0.5,-9)
				ico.Name = "Icon"
			end
		else
			local initial = New("TextLabel", {
				Size = UDim2.new(1,0,1,0),
				BackgroundTransparency = 1,
				Text = tabName:sub(1,1):upper(),
				Font = Enum.Font.GothamBold,
				TextSize = 15,
				TextColor3 = T.SubText,
				ZIndex = 15,
				Name = "Icon",
			}, tabBtn)
			Reg("TextColor3", initial, "SubText")
		end

		local tooltip = New("TextLabel", {
			Size = UDim2.new(0, 0, 0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(1, 8, 0.5, -13),
			BackgroundColor3 = T.Element,
			BackgroundTransparency = 0.1,
			Text = " "..tabName.." ",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = T.Text,
			ZIndex = 20,
			Visible = false,
		}, tabBtn)
		Round(6, tooltip)
		Stroke(tooltip, T.Accent, 1, 0.5)
		Reg("TextColor3", tooltip, "Text")
		Reg("Frame", tooltip, "Element")

		tabBtn.MouseEnter:Connect(function()
			tooltip.Visible = true
		end)
		tabBtn.MouseLeave:Connect(function()
			tooltip.Visible = false
		end)

		local tabContent = New("ScrollingFrame", {
			Size = UDim2.new(1, -14, 1, -54),
			Position = UDim2.new(0, 0, 0, 50),
			BackgroundTransparency = 1,
			ScrollBarThickness = 0,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ZIndex = 13,
			Visible = false,
			ClipsDescendants = true,
		}, contentArea)
		Pad(tabContent, 10, 10, 14, 14)
		local contentList = List(tabContent, Enum.FillDirection.Vertical, 8)

		UpdateScrollbar(tabContent)

		local function ActivateTab()
			if CurrentTab then
				local prev = CurrentTab
				Tween(prev.Content, 0.15, {BackgroundTransparency = 1})
				prev.Content.Visible = false
				Tween(prev.Btn, 0.2, {BackgroundColor3 = T.Background, BackgroundTransparency = 0.4})
				Spring(prev.Indicator, 0.3, {Size = UDim2.new(0,3,0,0)})
				Tween(prev.BtnGlow, 0.2, {BackgroundTransparency = 1})
				Tween(prev.BtnStroke, 0.2, {Transparency = 0.8})
				local prevIcon = prev.Btn:FindFirstChild("Icon")
				if prevIcon then
					if prevIcon:IsA("TextLabel") then
						Tween(prevIcon, 0.2, {TextColor3 = T.SubText})
					elseif prevIcon:IsA("ImageLabel") then
						Tween(prevIcon, 0.2, {ImageColor3 = T.SubText})
					end
				end
			end
			tabContent.Visible = true
			Tween(tabBtn, 0.2, {BackgroundColor3 = T.Accent, BackgroundTransparency = 0.85})
			Spring(tabIndicator, 0.4, {Size = UDim2.new(0,3,0,22)})
			Tween(tabBtnGlow, 0.2, {BackgroundTransparency = 0.88})
			Tween(tabBtnStroke, 0.2, {Color = T.Accent, Transparency = 0.4})
			local iconEl = tabBtn:FindFirstChild("Icon")
			if iconEl then
				if iconEl:IsA("TextLabel") then
					Tween(iconEl, 0.2, {TextColor3 = T.Accent})
				elseif iconEl:IsA("ImageLabel") then
					Tween(iconEl, 0.2, {ImageColor3 = T.Accent})
				end
			end
			CurrentTab = {Btn=tabBtn, Content=tabContent, Indicator=tabIndicator, BtnGlow=tabBtnGlow, BtnStroke=tabBtnStroke}
			UpdateScrollbar(tabContent)
		end

		tabBtn.MouseButton1Click:Connect(ActivateTab)

		table.insert(TabButtons, {Btn=tabBtn, Content=tabContent, Indicator=tabIndicator, BtnGlow=tabBtnGlow, BtnStroke=tabBtnStroke})

		if #TabButtons == 1 then
			ActivateTab()
		end

		local Tab = {}
		local SectionReg = {}

		local function RegisterSectionEl(t, obj, key, fb)
			table.insert(SectionReg, {Type=t,Object=obj,Key=key,Fallback=fb})
			Reg(t,obj,key,fb)
		end

		function Tab:Select()
			ActivateTab()
		end

		function Tab:CreateSection(sConfig)
			sConfig = sConfig or {}
			local sName = (type(sConfig) == "string" and sConfig) or sConfig.Name or sConfig.Title or ""
			local hasName = sName ~= ""

			local sFrame = New("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = T.Element,
				BackgroundTransparency = 0.35,
				ZIndex = 14,
			}, tabContent)
			Round(10, sFrame)
			Stroke(sFrame, T.Outline, 1, 0.75)
			RegisterSectionEl("Frame", sFrame, "Element")

			local sInner = New("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ZIndex = 14,
			}, sFrame)
			Pad(sInner, hasName and 36 or 8, 8, 10, 10)
			List(sInner, Enum.FillDirection.Vertical, 6)

			if hasName then
				local sHeader = New("Frame", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundColor3 = T.Background,
					BackgroundTransparency = 0.3,
					ZIndex = 15,
				}, sFrame)
				Round(10, sHeader)
				New("Frame", {
					Size = UDim2.new(1, 0, 0, 14),
					Position = UDim2.new(0,0,1,-14),
					BackgroundColor3 = T.Background,
					BackgroundTransparency = 0.3,
					ZIndex = 15,
				}, sHeader)
				RegisterSectionEl("Frame", sHeader, "Background")

				local dot = New("Frame", {
					Size = UDim2.fromOffset(4,4),
					Position = UDim2.new(0,10,0.5,-2),
					BackgroundColor3 = T.Accent,
					ZIndex = 16,
				}, sHeader)
				Round(4, dot)
				RegisterSectionEl("Accent", dot, "Accent")

				New("TextLabel", {
					Text = sName:upper(),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextColor3 = T.SubText,
					Position = UDim2.new(0, 22, 0, 0),
					Size = UDim2.new(1,-32,1,0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 16,
					TextTransparency = 0.2,
				}, sHeader)
			end

			local Section = {}

			local function MakeRow(height, noHover)
				local row = New("Frame", {
					Size = UDim2.new(1, 0, 0, height),
					BackgroundColor3 = T.Element,
					BackgroundTransparency = 0.6,
					ZIndex = 15,
				}, sInner)
				Round(8, row)
				local rowStroke = Stroke(row, T.Outline, 1, 0.88)
				RegisterSectionEl("Stroke", rowStroke, "Outline")

				if not noHover then
					row.MouseEnter:Connect(function()
						Tween(row, 0.18, {BackgroundTransparency = 0.4})
						Tween(rowStroke, 0.18, {Transparency = 0.6})
					end)
					row.MouseLeave:Connect(function()
						Tween(row, 0.18, {BackgroundTransparency = 0.6})
						Tween(rowStroke, 0.18, {Transparency = 0.88})
					end)
				end
				return row, rowStroke
			end

			local function NameLabel(parent, text, icon, offsetX)
				local off = offsetX or 12
				if icon then
					local ico = Img(parent, icon, UDim2.fromOffset(14,14), T.SubText, 0, 16)
					if ico then
						ico.Position = UDim2.new(0, off, 0.5, -7)
						off = off + 20
					end
				end
				local lbl = New("TextLabel", {
					Text = text or "",
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = T.Text,
					Position = UDim2.new(0, off, 0, 0),
					Size = UDim2.new(0.55, -off, 1, 0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 16,
				}, parent)
				RegisterSectionEl("TextColor3", lbl, "Text")
				return lbl
			end

			function Section:CreateButton(bConfig)
				bConfig = bConfig or {}
				local name     = (type(bConfig)=="string" and bConfig) or bConfig.Name or bConfig.Title or "Button"
				local callback = bConfig.Callback or function() end
				local icon     = bConfig.Icon
				local desc     = bConfig.Description

				local row, rowStroke = MakeRow(desc and 52 or 38)
				local lbl = NameLabel(row, name, icon)
				if desc then
					lbl.Size = UDim2.new(0.6, -12, 0, 18)
					lbl.Position = UDim2.new(0, 12, 0, 6)
					New("TextLabel", {
						Text = desc,
						Font = Enum.Font.Gotham,
						TextSize = 11,
						TextColor3 = T.SubText,
						Position = UDim2.new(0, 12, 0, 26),
						Size = UDim2.new(0.7, -12, 0, 16),
						BackgroundTransparency = 1,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 16,
					}, row)
				end

				local btnEl = New("TextButton", {
					Size = UDim2.new(0, 70, 0, 26),
					Position = UDim2.new(1, -78, 0.5, -13),
					BackgroundColor3 = T.Accent,
					BackgroundTransparency = 0.05,
					Text = "Execute",
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					TextColor3 = T.Background,
					ZIndex = 16,
					AutoButtonColor = false,
				}, row)
				Round(7, btnEl)
				local btnGlow = Glow(btnEl, T.Glow, 5, 0.84)
				RegisterSectionEl("Accent", btnEl, "Accent")
				RegisterSectionEl("GlowBg", btnGlow, "Glow")
				Ripple(btnEl, T.Background)

				btnEl.MouseEnter:Connect(function()
					Spring(btnEl, 0.3, {Size = UDim2.new(0,76,0,28)})
					Tween(btnEl, 0.15, {BackgroundTransparency = 0})
				end)
				btnEl.MouseLeave:Connect(function()
					Spring(btnEl, 0.3, {Size = UDim2.new(0,70,0,26)})
					Tween(btnEl, 0.15, {BackgroundTransparency = 0.05})
				end)
				btnEl.MouseButton1Click:Connect(function()
					pcall(callback)
				end)

				row.InputBegan:Connect(function(inp)
					if IsPrimary(inp) then
						pcall(callback)
					end
				end)

				local obj = {}
				function obj:SetText(t) btnEl.Text = t end
				function obj:SetCallback(f) callback = f end
				return obj
			end

			function Section:CreateToggle(tConfig)
				tConfig = tConfig or {}
				local name     = tConfig.Name or tConfig.Title or "Toggle"
				local default  = tConfig.Default or tConfig.Value or false
				local flag     = tConfig.Flag
				local callback = tConfig.Callback or function() end
				local icon     = tConfig.Icon
				local desc     = tConfig.Description

				local state = default
				if flag then Nova.Flags[flag] = state end

				local row, _ = MakeRow(desc and 52 or 38)
				local lbl = NameLabel(row, name, icon)
				if desc then
					lbl.Size = UDim2.new(0.6, -12, 0, 18)
					lbl.Position = UDim2.new(0, 12, 0, 6)
					New("TextLabel", {
						Text = desc,
						Font = Enum.Font.Gotham,
						TextSize = 11,
						TextColor3 = T.SubText,
						Position = UDim2.new(0, 12, 0, 26),
						Size = UDim2.new(0.7, -12, 0, 16),
						BackgroundTransparency = 1,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 16,
					}, row)
				end

				local trackW, trackH = 42, 22
				local track = New("Frame", {
					Size = UDim2.fromOffset(trackW, trackH),
					Position = UDim2.new(1, -(trackW+10), 0.5, -trackH/2),
					BackgroundColor3 = Elevate(T.Element),
					ZIndex = 16,
				}, row)
				Round(trackH, track)
				local trackStroke = Stroke(track, T.Outline, 1, 0.6)
				RegisterSectionEl("Stroke", trackStroke, "Outline")

				local knob = New("Frame", {
					Size = UDim2.fromOffset(16, 16),
					Position = UDim2.new(0, 3, 0.5, -8),
					BackgroundColor3 = T.SubText,
					ZIndex = 17,
				}, track)
				Round(16, knob)

				local knobGlow = New("Frame", {
					Size = UDim2.new(1,10,1,10),
					Position = UDim2.new(0,-5,0,-5),
					BackgroundColor3 = T.Accent,
					BackgroundTransparency = 1,
					ZIndex = 16,
				}, knob)
				Round(14, knobGlow)

				local function SetState(val, skipCallback)
					state = val
					if flag then Nova.Flags[flag] = state end
					if state then
						Tween(track, 0.25, {BackgroundColor3 = T.Toggle})
						Tween(knob, 0.3, {Position = UDim2.new(0, trackW-19, 0.5, -8), BackgroundColor3 = Color3.new(1,1,1)})
						Tween(knobGlow, 0.25, {BackgroundTransparency = 0.8})
						Tween(trackStroke, 0.25, {Color = T.Accent, Transparency = 0.3})
					else
						Tween(track, 0.25, {BackgroundColor3 = Elevate(T.Element)})
						Tween(knob, 0.3, {Position = UDim2.new(0,3,0.5,-8), BackgroundColor3 = T.SubText})
						Tween(knobGlow, 0.25, {BackgroundTransparency = 1})
						Tween(trackStroke, 0.25, {Color = T.Outline, Transparency = 0.6})
					end
					if not skipCallback then pcall(callback, state) end
				end

				SetState(state, true)

				track.InputBegan:Connect(function(inp)
					if IsPrimary(inp) then
						SetState(not state)
					end
				end)
				row.InputBegan:Connect(function(inp)
					if IsPrimary(inp) then
						SetState(not state)
					end
				end)

				local obj = {}
				function obj:Set(v) SetState(v, false) end
				function obj:Get() return state end
				function obj:Toggle() SetState(not state) end
				return obj
			end

			function Section:CreateSlider(slConfig)
				slConfig = slConfig or {}
				local name     = slConfig.Name or slConfig.Title or "Slider"
				local min      = slConfig.Min or 0
				local max      = slConfig.Max or 100
				local default  = slConfig.Default or slConfig.Value or min
				local decimals = slConfig.Decimals or 0
				local suffix   = slConfig.Suffix or ""
				local flag     = slConfig.Flag
				local callback = slConfig.Callback or function() end
				local icon     = slConfig.Icon

				local value = math.clamp(default, min, max)
				if flag then Nova.Flags[flag] = value end

				local row, _ = MakeRow(52, true)

				local topRow = New("Frame", {
					Size = UDim2.new(1, -20, 0, 20),
					Position = UDim2.new(0, 10, 0, 7),
					BackgroundTransparency = 1,
					ZIndex = 16,
				}, row)

				local lbl = New("TextLabel", {
					Text = name,
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = T.Text,
					Size = UDim2.new(0.75, 0, 1, 0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 17,
				}, topRow)
				RegisterSectionEl("TextColor3", lbl, "Text")

				local function fmt(v)
					if decimals > 0 then
						return string.format("%."..decimals.."f", v)..suffix
					end
					return tostring(math.floor(v))..suffix
				end

				local valLbl = New("TextLabel", {
					Text = fmt(value),
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextColor3 = T.Accent,
					Size = UDim2.new(0.25, 0, 1, 0),
					Position = UDim2.new(0.75, 0, 0, 0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 17,
				}, topRow)
				RegisterSectionEl("TextColor3", valLbl, "Accent")

				local track = New("Frame", {
					Size = UDim2.new(1, -20, 0, 5),
					Position = UDim2.new(0, 10, 0, 34),
					BackgroundColor3 = Elevate(T.Element, 0.12),
					ZIndex = 16,
				}, row)
				Round(5, track)

				local fill = New("Frame", {
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundColor3 = T.Slider,
					ZIndex = 17,
				}, track)
				Round(5, fill)
				RegisterSectionEl("Accent", fill, "Slider")

				local fillGlow = New("Frame", {
					Size = UDim2.new(1, 0, 1, 8),
					Position = UDim2.new(0, 0, 0, -4),
					BackgroundColor3 = T.Glow,
					BackgroundTransparency = 0.78,
					ZIndex = 16,
				}, fill)
				Round(5, fillGlow)
				RegisterSectionEl("GlowBg", fillGlow, "Glow")

				local thumb = New("Frame", {
					Size = UDim2.fromOffset(14, 14),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					BackgroundColor3 = Color3.new(1,1,1),
					ZIndex = 18,
				}, track)
				Round(14, thumb)
				Stroke(thumb, T.Accent, 2, 0.1)
				local thumbGlow = Glow(thumb, T.Glow, 5, 0.82)
				RegisterSectionEl("GlowBg", thumbGlow, "Glow")

				local function Redraw(v)
					local t = math.clamp((v - min) / math.max(max - min, 1), 0, 1)
					fill.Size = UDim2.new(t, 0, 1, 0)
					thumb.Position = UDim2.new(t, 0, 0.5, 0)
					valLbl.Text = fmt(v)
				end
				Redraw(value)

				local sliding = false
				local slideInput

				track.InputBegan:Connect(function(inp)
					if IsPrimary(inp) then
						sliding = true
						slideInput = inp
						-- also update immediately on click
						local trackAbs = track.AbsolutePosition
						local trackSize = track.AbsoluteSize
						local rel = math.clamp((inp.Position.X - trackAbs.X) / math.max(trackSize.X, 1), 0, 1)
						local raw = min + (max - min) * rel
						local step = math.pow(10, decimals)
						value = math.floor(raw * step + 0.5) / step
						value = math.clamp(value, min, max)
						if flag then Nova.Flags[flag] = value end
						Redraw(value)
						pcall(callback, value)
					end
				end)

				Conn(UserInputService.InputEnded, function(inp)
					if IsPrimary(inp) then
						sliding = false
						slideInput = nil
					end
				end)

				Conn(UserInputService.InputChanged, function(inp)
					if sliding and (inp == slideInput or IsMove(inp)) then
						local trackAbs = track.AbsolutePosition
						local trackSize = track.AbsoluteSize
						local rel = math.clamp((inp.Position.X - trackAbs.X) / math.max(trackSize.X, 1), 0, 1)
						local raw = min + (max - min) * rel
						local step = math.pow(10, decimals)
						value = math.floor(raw * step + 0.5) / step
						value = math.clamp(value, min, max)
						if flag then Nova.Flags[flag] = value end
						Redraw(value)
						pcall(callback, value)
					end
				end)

				local obj = {}
				function obj:Set(v)
					value = math.clamp(v, min, max)
					if flag then Nova.Flags[flag] = value end
					Tween(fill, 0.2, {Size = UDim2.new(math.clamp((value-min)/(max-min),0,1),0,1,0)})
					valLbl.Text = fmt(value)
					pcall(callback, value)
				end
				function obj:Get() return value end
				return obj
			end

			function Section:CreateDropdown(dConfig)
				dConfig = dConfig or {}
				local name     = dConfig.Name or dConfig.Title or "Dropdown"
				local options  = dConfig.Options or dConfig.Items or {}
				local default  = dConfig.Default or dConfig.Value
				local multi    = dConfig.Multi or false
				local flag     = dConfig.Flag
				local callback = dConfig.Callback or function() end
				local icon     = dConfig.Icon

				local selected = multi and {} or (default or (options[1] or ""))
				if multi and default then selected = type(default)=="table" and default or {default} end
				if flag then Nova.Flags[flag] = selected end

				local row, _ = MakeRow(38, true)
				local lbl = NameLabel(row, name, icon)
				local open = false

				local function DisplayText()
					if multi then
						if #selected == 0 then return "Select..." end
						return table.concat(selected, ", ")
					end
					return (selected ~= "" and selected) or "Select..."
				end

				local selBtn = New("TextButton", {
					Size = UDim2.new(0, 130, 0, 26),
					Position = UDim2.new(1, -138, 0.5, -13),
					BackgroundColor3 = Elevate(T.Element),
					BackgroundTransparency = 0.2,
					Text = DisplayText(),
					Font = Enum.Font.GothamMedium,
					TextSize = 11,
					TextColor3 = T.Text,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 16,
					AutoButtonColor = false,
				}, row)
				Round(7, selBtn)
				Stroke(selBtn, T.Outline, 1, 0.6)
				RegisterSectionEl("TextColor3", selBtn, "Text")

				local arrow = New("TextLabel", {
					Size = UDim2.fromOffset(12, 12),
					Position = UDim2.new(1, -14, 0.5, -6),
					BackgroundTransparency = 1,
					Text = "▾",
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextColor3 = T.SubText,
					ZIndex = 17,
				}, selBtn)
				RegisterSectionEl("TextColor3", arrow, "SubText")

				local dropFrame = New("Frame", {
					Size = UDim2.new(0, 130, 0, 0),
					Position = UDim2.new(1, -138, 1, 6),
					BackgroundColor3 = T.Element,
					BackgroundTransparency = 0.05,
					ClipsDescendants = true,
					ZIndex = 30,
					Visible = false,
				}, row)
				Round(8, dropFrame)
				Stroke(dropFrame, T.Accent, 1, 0.4)
				Glow(dropFrame, T.Glow, 8, 0.86)
				RegisterSectionEl("Frame", dropFrame, "Element")

				local dropScroll = New("ScrollingFrame", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					ScrollBarThickness = 2,
					ScrollBarImageColor3 = T.Accent,
					CanvasSize = UDim2.new(0,0,0,0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ZIndex = 31,
				}, dropFrame)
				Pad(dropScroll, 4, 4, 4, 4)
				List(dropScroll, Enum.FillDirection.Vertical, 3)

				local function IsSelected(opt)
					if multi then
						for _, v in ipairs(selected) do
							if v == opt then return true end
						end
						return false
					end
					return selected == opt
				end

				local optBtns = {}

				local function RebuildOptions()
					for _, c in ipairs(dropScroll:GetChildren()) do
						if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
							c:Destroy()
						end
					end
					optBtns = {}
					for _, opt in ipairs(options) do
						local isSel = IsSelected(opt)
						local optBtn = New("TextButton", {
							Size = UDim2.new(1, 0, 0, 28),
							BackgroundColor3 = isSel and T.Accent or T.Element,
							BackgroundTransparency = isSel and 0.75 or 0.6,
							Text = "",
							ZIndex = 32,
							AutoButtonColor = false,
						}, dropScroll)
						Round(6, optBtn)

						if isSel then
							local selDot = New("Frame", {
								Size = UDim2.fromOffset(4,4),
								Position = UDim2.new(0,6,0.5,-2),
								BackgroundColor3 = T.Accent,
								ZIndex = 33,
							}, optBtn)
							Round(4, selDot)
						end

						New("TextLabel", {
							Text = tostring(opt),
							Font = Enum.Font.GothamMedium,
							TextSize = 12,
							TextColor3 = isSel and T.Accent or T.Text,
							Position = UDim2.new(0, isSel and 16 or 8, 0, 0),
							Size = UDim2.new(1, -16, 1, 0),
							BackgroundTransparency = 1,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 33,
						}, optBtn)

						optBtn.MouseEnter:Connect(function()
							if not IsSelected(opt) then
								Tween(optBtn, 0.15, {BackgroundTransparency = 0.4})
							end
						end)
						optBtn.MouseLeave:Connect(function()
							if not IsSelected(opt) then
								Tween(optBtn, 0.15, {BackgroundTransparency = 0.6})
							end
						end)
						optBtn.MouseButton1Click:Connect(function()
							if multi then
								local found = false
								for i, v in ipairs(selected) do
									if v == opt then
										table.remove(selected, i)
										found = true
										break
									end
								end
								if not found then table.insert(selected, opt) end
							else
								selected = opt
								open = false
								Tween(dropFrame, 0.2, {Size = UDim2.new(0,130,0,0)})
								task.delay(0.2, function() dropFrame.Visible = false end)
								Spring(arrow, 0.3, {Rotation = 0})
							end
							if flag then Nova.Flags[flag] = selected end
							selBtn.Text = DisplayText()
							RebuildOptions()
							pcall(callback, selected)
						end)
						table.insert(optBtns, optBtn)
					end
				end

				RebuildOptions()

				selBtn.MouseButton1Click:Connect(function()
					open = not open
					if open then
						dropFrame.Visible = true
						local itemH = math.min(#options, 5) * 31 + 8
						Spring(dropFrame, 0.35, {Size = UDim2.new(0,130,0,itemH)})
						Spring(arrow, 0.3, {Rotation = 180})
					else
						Spring(dropFrame, 0.25, {Size = UDim2.new(0,130,0,0)})
						Spring(arrow, 0.3, {Rotation = 0})
						task.delay(0.25, function() dropFrame.Visible = false end)
					end
				end)

				local obj = {}
				function obj:Set(v)
					selected = v
					if flag then Nova.Flags[flag] = selected end
					selBtn.Text = DisplayText()
					RebuildOptions()
				end
				function obj:Get() return selected end
				function obj:SetOptions(opts)
					options = opts
					RebuildOptions()
				end
				function obj:AddOption(opt)
					table.insert(options, opt)
					RebuildOptions()
				end
				function obj:RemoveOption(opt)
					for i, v in ipairs(options) do
						if v == opt then table.remove(options, i) break end
					end
					RebuildOptions()
				end
				return obj
			end

			function Section:CreateInput(iConfig)
				iConfig = iConfig or {}
				local name      = iConfig.Name or iConfig.Title or "Input"
				local placeholder = iConfig.Placeholder or "Type here..."
				local default   = iConfig.Default or iConfig.Value or ""
				local numeric   = iConfig.Numeric or false
				local flag      = iConfig.Flag
				local callback  = iConfig.Callback or function() end
				local onEnter   = iConfig.OnEnter or callback
				local icon      = iConfig.Icon

				local row, _ = MakeRow(38, true)
				NameLabel(row, name, icon)

				local inputBg = New("Frame", {
					Size = UDim2.new(0, 140, 0, 26),
					Position = UDim2.new(1, -148, 0.5, -13),
					BackgroundColor3 = Elevate(T.Element),
					BackgroundTransparency = 0.2,
					ZIndex = 16,
				}, row)
				Round(7, inputBg)
				local inputStroke = Stroke(inputBg, T.Outline, 1, 0.6)
				RegisterSectionEl("Stroke", inputStroke, "Outline")

				local box = New("TextBox", {
					Size = UDim2.new(1, -12, 1, 0),
					Position = UDim2.new(0, 6, 0, 0),
					BackgroundTransparency = 1,
					Text = default,
					PlaceholderText = placeholder,
					PlaceholderColor3 = T.SubText,
					TextColor3 = T.Text,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					ClearTextOnFocus = false,
					ZIndex = 17,
				}, inputBg)
				RegisterSectionEl("TextColor3", box, "Text")

				if flag then Nova.Flags[flag] = box.Text end

				box.Focused:Connect(function()
					Tween(inputStroke, 0.2, {Color = T.Accent, Transparency = 0})
					Tween(inputBg, 0.2, {BackgroundTransparency = 0.1})
				end)
				box.FocusLost:Connect(function(enter)
					Tween(inputStroke, 0.2, {Color = T.Outline, Transparency = 0.6})
					Tween(inputBg, 0.2, {BackgroundTransparency = 0.2})
					if numeric then
						local num = tonumber(box.Text)
						box.Text = num and tostring(num) or ""
					end
					if flag then Nova.Flags[flag] = box.Text end
					pcall(callback, box.Text)
					if enter then pcall(onEnter, box.Text) end
				end)
				box:GetPropertyChangedSignal("Text"):Connect(function()
					if flag then Nova.Flags[flag] = box.Text end
					pcall(callback, box.Text)
				end)

				local obj = {}
				function obj:Set(v) box.Text = tostring(v) end
				function obj:Get() return box.Text end
				function obj:Clear() box.Text = "" end
				return obj
			end

			function Section:CreateColorPicker(cpConfig)
				cpConfig = cpConfig or {}
				local name     = cpConfig.Name or cpConfig.Title or "Color"
				local default  = cpConfig.Default or cpConfig.Value or Color3.fromHex("#00E5FF")
				local flag     = cpConfig.Flag
				local callback = cpConfig.Callback or function() end

				local color = default
				if flag then Nova.Flags[flag] = color end

				local row, _ = MakeRow(38, true)
				NameLabel(row, name)

				local previewBtn = New("TextButton", {
					Size = UDim2.fromOffset(38, 26),
					Position = UDim2.new(1, -46, 0.5, -13),
					BackgroundColor3 = color,
					Text = "",
					ZIndex = 16,
					AutoButtonColor = false,
				}, row)
				Round(7, previewBtn)
				Stroke(previewBtn, T.Outline, 1, 0.5)
				local previewGlow = Glow(previewBtn, color, 5, 0.82)

				local pickerOpen = false
				local pickerFrame = New("Frame", {
					Size = UDim2.new(0, 200, 0, 0),
					Position = UDim2.new(1, -208, 1, 6),
					BackgroundColor3 = T.Element,
					BackgroundTransparency = 0.05,
					ClipsDescendants = true,
					ZIndex = 35,
					Visible = false,
				}, row)
				Round(10, pickerFrame)
				Stroke(pickerFrame, T.Accent, 1, 0.4)
				RegisterSectionEl("Frame", pickerFrame, "Element")

				local function hsv2rgb(h,s,v)
					return Color3.fromHSV(h,s,v)
				end

				local H, S, V = color:ToHSV()

				local function UpdateColor()
					color = hsv2rgb(H,S,V)
					previewBtn.BackgroundColor3 = color
					previewGlow.BackgroundColor3 = color
					if flag then Nova.Flags[flag] = color end
					pcall(callback, color)
				end

				local svPad = New("Frame", {
					Size = UDim2.new(1,-16,0,120),
					Position = UDim2.new(0,8,0,8),
					BackgroundColor3 = Color3.fromHSV(H,1,1),
					ZIndex = 36,
				}, pickerFrame)
				Round(6, svPad)

				local svGradH = Instance.new("UIGradient")
				svGradH.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(H,1,1))
				svGradH.Rotation = 0
				svGradH.Parent = svPad

				local svOverlay = New("Frame", {
					Size = UDim2.new(1,0,1,0),
					BackgroundColor3 = Color3.new(0,0,0),
					BackgroundTransparency = 0,
					ZIndex = 37,
				}, svPad)
				Round(6, svOverlay)
				local svGradV = Instance.new("UIGradient")
				svGradV.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(0,0,0))
				svGradV.Rotation = 90
				svGradV.Transparency = NumberSequence.new(1, 0)
				svGradV.Parent = svOverlay

				local svThumb = New("Frame", {
					Size = UDim2.fromOffset(10,10),
					AnchorPoint = Vector2.new(0.5,0.5),
					Position = UDim2.new(S, 0, 1-V, 0),
					BackgroundColor3 = Color3.new(1,1,1),
					ZIndex = 38,
				}, svPad)
				Round(10, svThumb)
				Stroke(svThumb, Color3.new(0,0,0), 1.5, 0)

				local hTrack = New("Frame", {
					Size = UDim2.new(1,-16,0,10),
					Position = UDim2.new(0,8,0,136),
					ZIndex = 36,
				}, pickerFrame)
				Round(5, hTrack)

				local hGrad = Instance.new("UIGradient")
				hGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0,   Color3.fromHSV(0,1,1)),
					ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6,1,1)),
					ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6,1,1)),
					ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6,1,1)),
					ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6,1,1)),
					ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6,1,1)),
					ColorSequenceKeypoint.new(1,   Color3.fromHSV(1,1,1)),
				})
				hGrad.Parent = hTrack

				local hThumb = New("Frame", {
					Size = UDim2.fromOffset(10,10),
					AnchorPoint = Vector2.new(0.5,0.5),
					Position = UDim2.new(H,0,0.5,0),
					BackgroundColor3 = Color3.new(1,1,1),
					ZIndex = 37,
				}, hTrack)
				Round(10, hThumb)
				Stroke(hThumb, Color3.new(0,0,0), 1.5, 0)

				local hexInput = New("TextBox", {
					Size = UDim2.new(1,-16,0,24),
					Position = UDim2.new(0,8,0,154),
					BackgroundColor3 = Elevate(T.Element),
					BackgroundTransparency = 0.3,
					Text = "#"..color:ToHex():upper(),
					Font = Enum.Font.GothamMedium,
					TextSize = 11,
					TextColor3 = T.Text,
					ClearTextOnFocus = false,
					ZIndex = 36,
				}, pickerFrame)
				Round(6, hexInput)
				Stroke(hexInput, T.Outline, 1, 0.6)

				local svDragging = false
				local hDragging  = false
				local svInput, hInput

				svPad.InputBegan:Connect(function(inp)
					if IsPrimary(inp) then
						svDragging = true
						svInput = inp
					end
				end)
				hTrack.InputBegan:Connect(function(inp)
					if IsPrimary(inp) then
						hDragging = true
						hInput = inp
					end
				end)

				Conn(UserInputService.InputEnded, function(inp)
					if IsPrimary(inp) then
						svDragging = false
						hDragging  = false
						svInput = nil
						hInput = nil
					end
				end)

				Conn(UserInputService.InputChanged, function(inp)
					if not IsMove(inp) and inp ~= svInput and inp ~= hInput then return end
					if svDragging then
						local abs = svPad.AbsolutePosition
						local sz  = svPad.AbsoluteSize
						S = math.clamp((inp.Position.X - abs.X) / math.max(sz.X,1), 0, 1)
						V = 1 - math.clamp((inp.Position.Y - abs.Y) / math.max(sz.Y,1), 0, 1)
						svThumb.Position = UDim2.new(S, 0, 1-V, 0)
						UpdateColor()
						hexInput.Text = "#"..color:ToHex():upper()
					end
					if hDragging then
						local abs = hTrack.AbsolutePosition
						local sz  = hTrack.AbsoluteSize
						H = math.clamp((inp.Position.X - abs.X) / math.max(sz.X,1), 0, 1)
						hThumb.Position = UDim2.new(H,0,0.5,0)
						svPad.BackgroundColor3 = Color3.fromHSV(H,1,1)
						svGradH.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(H,1,1))
						UpdateColor()
						hexInput.Text = "#"..color:ToHex():upper()
					end
				end)

				hexInput.FocusLost:Connect(function()
					local hex = hexInput.Text:gsub("#","")
					local ok, c3 = pcall(function() return Color3.fromHex(hex) end)
					if ok then
						color = c3
						H,S,V = c3:ToHSV()
						svThumb.Position = UDim2.new(S,0,1-V,0)
						hThumb.Position  = UDim2.new(H,0,0.5,0)
						svPad.BackgroundColor3 = Color3.fromHSV(H,1,1)
						svGradH.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(H,1,1))
						previewBtn.BackgroundColor3 = color
						previewGlow.BackgroundColor3 = color
						if flag then Nova.Flags[flag] = color end
						pcall(callback, color)
					end
					hexInput.Text = "#"..color:ToHex():upper()
				end)

				previewBtn.MouseButton1Click:Connect(function()
					pickerOpen = not pickerOpen
					if pickerOpen then
						pickerFrame.Visible = true
						Spring(pickerFrame, 0.35, {Size = UDim2.new(0,200,0,186)})
					else
						Spring(pickerFrame, 0.25, {Size = UDim2.new(0,200,0,0)})
						task.delay(0.25, function() pickerFrame.Visible = false end)
					end
				end)

				local obj = {}
				function obj:Set(c)
					color = c
					H,S,V = c:ToHSV()
					previewBtn.BackgroundColor3 = color
					previewGlow.BackgroundColor3 = color
					hexInput.Text = "#"..color:ToHex():upper()
					svThumb.Position = UDim2.new(S,0,1-V,0)
					hThumb.Position  = UDim2.new(H,0,0.5,0)
					svPad.BackgroundColor3 = Color3.fromHSV(H,1,1)
					if flag then Nova.Flags[flag] = color end
					pcall(callback, color)
				end
				function obj:Get() return color end
				return obj
			end

			function Section:CreateKeybind(kConfig)
				kConfig = kConfig or {}
				local name     = kConfig.Name or kConfig.Title or "Keybind"
				local default  = kConfig.Default or kConfig.Value or Enum.KeyCode.Unknown
				local flag     = kConfig.Flag
				local callback = kConfig.Callback or function() end
				local icon     = kConfig.Icon

				local current = default
				if flag then Nova.Flags[flag] = current end
				local listening = false

				local row, _ = MakeRow(38, true)
				NameLabel(row, name, icon)

				local keyBtn = New("TextButton", {
					Size = UDim2.new(0, 90, 0, 26),
					Position = UDim2.new(1, -98, 0.5, -13),
					BackgroundColor3 = Elevate(T.Element),
					BackgroundTransparency = 0.2,
					Text = current and current.Name or "None",
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					TextColor3 = T.Text,
					ZIndex = 16,
					AutoButtonColor = false,
				}, row)
				Round(7, keyBtn)
				local kbStroke = Stroke(keyBtn, T.Outline, 1, 0.6)
				RegisterSectionEl("TextColor3", keyBtn, "Text")

				keyBtn.MouseButton1Click:Connect(function()
					if listening then return end
					listening = true
					keyBtn.Text = "..."
					Tween(kbStroke, 0.2, {Color = T.Accent, Transparency = 0})
					Tween(keyBtn, 0.2, {BackgroundColor3 = T.Accent, BackgroundTransparency = 0.8})
					local conn
					conn = UserInputService.InputBegan:Connect(function(inp, gp)
						if gp then return end
						if inp.UserInputType == Enum.UserInputType.Keyboard then
							current = inp.KeyCode
							if flag then Nova.Flags[flag] = current end
							keyBtn.Text = current.Name
							listening = false
							Tween(kbStroke, 0.2, {Color = T.Outline, Transparency = 0.6})
							Tween(keyBtn, 0.2, {BackgroundColor3 = Elevate(T.Element), BackgroundTransparency = 0.2})
							conn:Disconnect()
							pcall(callback, current)
						end
					end)
					-- safety timeout
					task.delay(8, function()
						if listening then
							listening = false
							keyBtn.Text = current and current.Name or "None"
							Tween(kbStroke, 0.2, {Color = T.Outline, Transparency = 0.6})
							Tween(keyBtn, 0.2, {BackgroundColor3 = Elevate(T.Element), BackgroundTransparency = 0.2})
							if conn then pcall(function() conn:Disconnect() end) end
						end
					end)
				end)

				-- Shared keybind trigger (one connection per window, managed)
				Conn(UserInputService.InputBegan, function(inp, gp)
					if not gp and current and current ~= Enum.KeyCode.Unknown and inp.KeyCode == current then
						pcall(callback, current)
					end
				end)

				local obj = {}
				function obj:Set(k)
					current = k
					keyBtn.Text = k and k.Name or "None"
					if flag then Nova.Flags[flag] = k end
				end
				function obj:Get() return current end
				return obj
			end

			function Section:CreateProgressBar(pConfig)
				pConfig = pConfig or {}
				local name     = pConfig.Name or pConfig.Title or "Progress"
				local min      = pConfig.Min or 0
				local max      = pConfig.Max or 100
				local default  = pConfig.Default or pConfig.Value or min
				local suffix   = pConfig.Suffix or "%"
				local icon     = pConfig.Icon

				local value = math.clamp(default, min, max)
				local row, _ = MakeRow(52, true)

				local topRow = New("Frame", {
					Size = UDim2.new(1,-20,0,20),
					Position = UDim2.new(0,10,0,7),
					BackgroundTransparency = 1,
					ZIndex = 16,
				}, row)

				New("TextLabel", {
					Text = name,
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = T.Text,
					Size = UDim2.new(0.75,0,1,0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 17,
				}, topRow)

				local function fmt(v)
					local t = math.clamp((v-min)/(math.max(max-min,1)),0,1)
					return math.floor(t*100)..suffix
				end

				local valLbl = New("TextLabel", {
					Text = fmt(value),
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextColor3 = T.Accent,
					Size = UDim2.new(0.25,0,1,0),
					Position = UDim2.new(0.75,0,0,0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 17,
				}, topRow)
				RegisterSectionEl("TextColor3", valLbl, "Accent")

				local track = New("Frame", {
					Size = UDim2.new(1,-20,0,6),
					Position = UDim2.new(0,10,0,34),
					BackgroundColor3 = Elevate(T.Element, 0.12),
					ZIndex = 16,
				}, row)
				Round(6, track)

				local fill = New("Frame", {
					Size = UDim2.fromScale(0,1),
					BackgroundColor3 = T.Accent,
					ZIndex = 17,
				}, track)
				Round(6, fill)
				RegisterSectionEl("Accent", fill, "Accent")

				local fillGlow = New("Frame", {
					Size = UDim2.new(1,0,1,10),
					Position = UDim2.new(0,0,0,-5),
					BackgroundColor3 = T.Glow,
					BackgroundTransparency = 0.75,
					ZIndex = 16,
				}, fill)
				Round(6, fillGlow)
				RegisterSectionEl("GlowBg", fillGlow, "Glow")

				local function Redraw(v, animate)
					value = math.clamp(v, min, max)
					local t = math.clamp((value-min)/(math.max(max-min,1)),0,1)
					valLbl.Text = fmt(value)
					if animate ~= false then
						Tween(fill, 0.35, {Size = UDim2.fromScale(t,1)})
					else
						fill.Size = UDim2.fromScale(t,1)
					end
				end
				Redraw(value, false)

				local obj = {}
				function obj:Set(v, animate) Redraw(v, animate) end
				function obj:Get() return value end
				function obj:Increment(amt) Redraw(value + (amt or 1)) end
				return obj
			end

			function Section:CreateLabel(text, lConfig)
				lConfig = lConfig or {}
				if type(lConfig) == "string" then lConfig = {Text = lConfig} end
				text = (type(text) == "table" and (text.Text or text.Title)) or text or ""

				local row = New("Frame", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					ZIndex = 15,
				}, sInner)

				local lbl = New("TextLabel", {
					Text = text,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					TextColor3 = T.SubText,
					Position = UDim2.new(0, 8, 0, 0),
					Size = UDim2.new(1,-16,1,0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					ZIndex = 16,
				}, row)
				RegisterSectionEl("TextColor3", lbl, "SubText")

				local obj = {}
				function obj:Set(t) lbl.Text = t end
				function obj:Get() return lbl.Text end
				return obj
			end

			function Section:CreateParagraph(pConfig)
				pConfig = pConfig or {}
				local title = pConfig.Title or pConfig.Name or ""
				local text  = pConfig.Content or pConfig.Text or ""

				local row = New("Frame", {
					Size = UDim2.new(1,0,0,0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = T.Element,
					BackgroundTransparency = 0.55,
					ZIndex = 15,
				}, sInner)
				Round(8, row)
				Stroke(row, T.Outline, 1, 0.85)
				Pad(row, 8, 10, 12, 12)

				if title ~= "" then
					New("TextLabel", {
						Text = title,
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = T.Accent,
						Size = UDim2.new(1,0,0,18),
						BackgroundTransparency = 1,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 16,
					}, row)
					RegisterSectionEl("TextColor3", row:FindFirstChild("TextLabel"), "Accent")
				end

				local contentLbl = New("TextLabel", {
					Text = text,
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextColor3 = T.Text,
					Size = UDim2.new(1,0,0,0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Position = title ~= "" and UDim2.new(0,0,0,22) or UDim2.new(0,0,0,0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					ZIndex = 16,
				}, row)
				RegisterSectionEl("TextColor3", contentLbl, "Text")

				local obj = {}
				function obj:Set(t) contentLbl.Text = t end
				function obj:SetTitle(t)
					local tl = row:FindFirstChildOfClass("TextLabel")
					if tl then tl.Text = t end
				end
				function obj:Get() return contentLbl.Text end
				return obj
			end

			function Section:CreateDivider()
				local row = New("Frame", {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					ZIndex = 15,
				}, sInner)
				local line = New("Frame", {
					Size = UDim2.new(1, 0, 0, 1),
					Position = UDim2.new(0, 0, 0.5, 0),
					BackgroundColor3 = T.Outline,
					BackgroundTransparency = 0.55,
					ZIndex = 16,
				}, row)
				MakeGradient(line, T.Element, T.Accent, 0)
				RegisterSectionEl("Stroke", {Color=T.Outline}, "Outline")
				return row
			end

			function Section:CreateSearchBar(sbConfig)
				sbConfig = sbConfig or {}
				local placeholder = sbConfig.Placeholder or "Search..."
				local callback    = sbConfig.OnChange or sbConfig.Callback or function() end

				local row, _ = MakeRow(38, true)

				local searchIcon = New("TextLabel", {
					Size = UDim2.fromOffset(16,16),
					Position = UDim2.new(0,8,0.5,-8),
					BackgroundTransparency = 1,
					Text = "⌕",
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					TextColor3 = T.SubText,
					ZIndex = 16,
				}, row)

				local box = New("TextBox", {
					Size = UDim2.new(1, -52, 1, -10),
					Position = UDim2.new(0, 28, 0, 5),
					BackgroundTransparency = 1,
					Text = "",
					PlaceholderText = placeholder,
					PlaceholderColor3 = T.SubText,
					TextColor3 = T.Text,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					ClearTextOnFocus = false,
					ZIndex = 17,
				}, row)
				RegisterSectionEl("TextColor3", box, "Text")

				local clearBtn = New("TextButton", {
					Size = UDim2.fromOffset(18,18),
					Position = UDim2.new(1,-22,0.5,-9),
					BackgroundTransparency = 1,
					Text = "×",
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					TextColor3 = T.SubText,
					ZIndex = 17,
					Visible = false,
				}, row)

				box:GetPropertyChangedSignal("Text"):Connect(function()
					clearBtn.Visible = box.Text ~= ""
					pcall(callback, box.Text)
				end)
				clearBtn.MouseButton1Click:Connect(function()
					box.Text = ""
					pcall(callback, "")
				end)

				local obj = {}
				function obj:Set(t) box.Text = t end
				function obj:Get() return box.Text end
				function obj:Clear() box.Text = "" end
				return obj
			end

			function Section:CreateBadge(bdConfig)
				bdConfig = bdConfig or {}
				local text  = bdConfig.Text or bdConfig.Name or "NEW"
				local color = bdConfig.Color or T.Accent

				local row = New("Frame", {
					Size = UDim2.new(1,0,0,30),
					BackgroundTransparency = 1,
					ZIndex = 15,
				}, sInner)

				local badge = New("TextLabel", {
					Size = UDim2.new(0,0,0,20),
					AutomaticSize = Enum.AutomaticSize.X,
					Position = UDim2.new(0.5,0,0.5,-10),
					AnchorPoint = Vector2.new(0.5,0),
					BackgroundColor3 = color,
					BackgroundTransparency = 0.75,
					Text = " "..text.." ",
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					TextColor3 = color,
					ZIndex = 16,
				}, row)
				Round(10, badge)
				Stroke(badge, color, 1, 0.4)

				local obj = {}
				function obj:Set(t) badge.Text = " "..t.." " end
				function obj:SetColor(c)
					badge.BackgroundColor3 = c
					badge.TextColor3 = c
				end
				return obj
			end

			return Section
		end

		function Tab:CreateButton(...) return Tab:CreateSection(""):CreateButton(...) end
		function Tab:CreateToggle(...) return Tab:CreateSection(""):CreateToggle(...) end
		function Tab:CreateSlider(...) return Tab:CreateSection(""):CreateSlider(...) end
		function Tab:CreateDropdown(...) return Tab:CreateSection(""):CreateDropdown(...) end
		function Tab:CreateInput(...) return Tab:CreateSection(""):CreateInput(...) end
		function Tab:CreateColorPicker(...) return Tab:CreateSection(""):CreateColorPicker(...) end
		function Tab:CreateKeybind(...) return Tab:CreateSection(""):CreateKeybind(...) end
		function Tab:CreateProgressBar(...) return Tab:CreateSection(""):CreateProgressBar(...) end
		function Tab:CreateLabel(...) return Tab:CreateSection(""):CreateLabel(...) end
		function Tab:CreateParagraph(...) return Tab:CreateSection(""):CreateParagraph(...) end
		function Tab:CreateDivider(...) return Tab:CreateSection(""):CreateDivider(...) end
		function Tab:CreateSearchBar(...) return Tab:CreateSection(""):CreateSearchBar(...) end
		function Tab:CreateBadge(...) return Tab:CreateSection(""):CreateBadge(...) end

		return Tab
	end

	ApplyAll()
	table.insert(Nova.Windows, Window)
	return Window
end

return Nova
