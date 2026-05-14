--// SippinUI.lua (ModuleScript)
--// Drawing-based UI library with tabs, buttons, toggles, sliders, keybinds (Toggle/Hold), and themes.

local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local Library = {}
Library.__index = Library

Library.ThemeHues = {
	red = 0.95,
	green = 0.30,
	blue = 0.65,
	purple = 0.80,
	yellow = 0.15,
	orange = 0.075,
	pink = 0.87
}

Library.Windows = {}
Library.Flags = {}

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function v2lerp(a, b, t)
	return a:Lerp(b, t)
end

local function circularHueLerp(curr, targ, t)
	local diff = ((targ - curr + 0.5) % 1) - 0.5
	return (curr + diff * t) % 1
end

local function safeCallback(cb, ...)
	if typeof(cb) == "function" then
		local ok, err = pcall(cb, ...)
		if not ok then
			warn("[SippinUI] Callback error:", err)
		end
	end
end

local function pointInRect(p, pos, size)
	return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
end

local function createDrawing(class, props)
	local o = Drawing.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	return o
end

function Library:_registerWindow(win)
	table.insert(self.Windows, win)
end

function Library:_unregisterWindow(win)
	local idx = table.find(self.Windows, win)
	if idx then
		table.remove(self.Windows, idx)
	end
end

function Library:CreateWindow(opts)
	opts = opts or {}

	local viewport = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
	local size = opts.Size or Vector2.new(640, 400)
	local pos = opts.Position or Vector2.new((viewport.X - size.X) * 0.5, (viewport.Y - size.Y) * 0.5)

	local themeName = tostring(opts.Theme or "red")
	local hue = Library.ThemeHues[themeName] or (typeof(opts.Theme) == "number" and opts.Theme % 1) or Library.ThemeHues.red

	local self = setmetatable({
		TitlePrefix = tostring(opts.TitlePrefix or " sippin."),
		ThemeName = themeName,
		ThemeHue = hue,
		TargetHue = hue,

		Size = size,
		Position = pos,
		Visible = true,
		TargetVisible = 1,
		VisibleAlpha = 1,

		TabWidth = 190,
		TopBarHeight = 25,

		ToggleKey = opts.ToggleKey or Enum.KeyCode.Minus,

		DrawItems = {},
		Tabs = {},
		ActiveTab = nil,

		Dragging = false,
		DragOffset = Vector2.zero,
		DragTarget = pos,

		AwaitingBind = nil,

		Destroyed = false
	}, Window)

	self:_build()
	self:_connect()
	Library:_registerWindow(self)

	return self
end

function Window:_roleColor(role)
	local h = self.ThemeHue

	if role == "bg" then return Color3.fromHSV(h, 0.35, 0.11) end
	if role == "bar" then return Color3.fromHSV(h, 0.45, 0.20) end
	if role == "line" then return Color3.fromHSV(h, 0.55, 0.26) end
	if role == "panel" then return Color3.fromHSV(h, 0.30, 0.16) end
	if role == "tab" then return Color3.fromHSV(h, 0.35, 0.19) end
	if role == "tabActive" then return Color3.fromHSV(h, 0.58, 0.34) end
	if role == "control" then return Color3.fromHSV(h, 0.32, 0.22) end
	if role == "control2" then return Color3.fromHSV(h, 0.35, 0.25) end
	if role == "accent" then return Color3.fromHSV(h, 0.62, 0.95) end
	if role == "text" then return Color3.fromHSV(h, 0.10, 0.88) end
	if role == "mutedText" then return Color3.fromHSV(h, 0.16, 0.68) end

	return Color3.fromRGB(255, 255, 255)
end

function Window:_track(class, props, role, alpha, getPos, getVisible, getSize, getRole)
	local obj = createDrawing(class, props)
	local item = {
		obj = obj,
		role = role,
		alpha = alpha or (props.Transparency or 1),
		getPos = getPos,
		getVisible = getVisible,
		getSize = getSize,
		getRole = getRole
	}
	table.insert(self.DrawItems, item)
	return obj, item
end

function Window:_build()
	-- Base frame
	self._bg = self:_track("Square", {
		Position = self.Position,
		Size = self.Size,
		Filled = true,
		Transparency = 1,
		ZIndex = 1
	}, "bg", 1)

	self._bar = self:_track("Square", {
		Position = self.Position,
		Size = Vector2.new(self.Size.X, self.TopBarHeight),
		Filled = true,
		Transparency = 0.95,
		ZIndex = 2
	}, "bar", 0.95)

	self._line = self:_track("Square", {
		Position = self.Position + Vector2.new(0, self.TopBarHeight - 2),
		Size = Vector2.new(self.Size.X, 2),
		Filled = true,
		Transparency = 0.95,
		ZIndex = 3
	}, "line", 0.95)

	self._title = self:_track("Text", {
		Position = self.Position + Vector2.new(8, 4),
		Text = self.TitlePrefix .. self.ThemeName,
		Size = 16,
		Font = 3,
		Center = false,
		Outline = true,
		Transparency = 1,
		ZIndex = 4
	}, "text", 1)

	self._left = self:_track("Square", {
		Position = self.Position + Vector2.new(5, self.TopBarHeight + 8),
		Size = Vector2.new(self.TabWidth, self.Size.Y - self.TopBarHeight - 13),
		Filled = true,
		Transparency = 0.85,
		ZIndex = 2
	}, "panel", 0.85)

	self._right = self:_track("Square", {
		Position = self.Position + Vector2.new(self.TabWidth + 15, self.TopBarHeight + 8),
		Size = Vector2.new(self.Size.X - self.TabWidth - 20, self.Size.Y - self.TopBarHeight - 13),
		Filled = true,
		Transparency = 0.85,
		ZIndex = 2
	}, "panel", 0.85)
end

function Window:_connect()
	self._ib = UIS.InputBegan:Connect(function(input, gpe)
		if gpe or self.Destroyed then return end
		self:_onInputBegan(input)
	end)

	self._ie = UIS.InputEnded:Connect(function(input, gpe)
		if gpe or self.Destroyed then return end
		self:_onInputEnded(input)
	end)

	self._rs = RS.RenderStepped:Connect(function(dt)
		if self.Destroyed then return end
		self:_update(dt)
	end)
end

function Window:_windowBarRect()
	return self.Position, Vector2.new(self.Size.X, self.TopBarHeight)
end

function Window:_tabButtonRect(tab)
	return tab._btnPos or Vector2.zero, tab._btnSize or Vector2.zero
end

function Window:_layoutTabs()
	local y = self.TopBarHeight + 16
	for i, tab in ipairs(self.Tabs) do
		local pos = self.Position + Vector2.new(12, y + (i - 1) * 28)
		local size = Vector2.new(self.TabWidth - 14, 24)
		tab._btnPos = pos
		tab._btnSize = size
		if tab.ButtonBg then
			tab.ButtonBg.Position = pos
			tab.ButtonBg.Size = size
		end
		if tab.ButtonText then
			tab.ButtonText.Position = pos + Vector2.new(8, 3)
		end
	end
end

function Window:_layoutTabControls(tab)
	if not tab then return end

	local contentPos = self.Position + Vector2.new(self.TabWidth + 25, self.TopBarHeight + 18)
	local contentWidth = self.Size.X - self.TabWidth - 40
	local y = 0

	for _, c in ipairs(tab.Controls) do
		if c.SetLayout then
			c:SetLayout(contentPos + Vector2.new(0, y), contentWidth)
		end
		y += (c.Height or 24) + 8
	end
end

function Window:_layoutAll()
	self._bg.obj.Position = self.Position
	self._bg.obj.Size = self.Size

	self._bar.obj.Position = self.Position
	self._bar.obj.Size = Vector2.new(self.Size.X, self.TopBarHeight)

	self._line.obj.Position = self.Position + Vector2.new(0, self.TopBarHeight - 2)
	self._line.obj.Size = Vector2.new(self.Size.X, 2)

	self._title.obj.Position = self.Position + Vector2.new(8, 4)

	self._left.obj.Position = self.Position + Vector2.new(5, self.TopBarHeight + 8)
	self._left.obj.Size = Vector2.new(self.TabWidth, self.Size.Y - self.TopBarHeight - 13)

	self._right.obj.Position = self.Position + Vector2.new(self.TabWidth + 15, self.TopBarHeight + 8)
	self._right.obj.Size = Vector2.new(self.Size.X - self.TabWidth - 20, self.Size.Y - self.TopBarHeight - 13)

	self:_layoutTabs()
	self:_layoutTabControls(self.ActiveTab)
end

function Window:_setVisibleRaw(v)
	self.Visible = v
	self.TargetVisible = v and 1 or 0
end

function Window:SetVisible(v)
	self:_setVisibleRaw(v and true or false)
end

function Window:Toggle()
	self:_setVisibleRaw(not self.Visible)
end

function Window:SetTheme(theme)
	if typeof(theme) == "number" then
		self.TargetHue = theme % 1
		self.ThemeName = ("%.3f"):format(self.TargetHue)
	else
		local n = tostring(theme)
		self.TargetHue = Library.ThemeHues[n] or self.TargetHue
		self.ThemeName = n
	end
	self._title.obj.Text = self.TitlePrefix .. self.ThemeName
end

function Window:SetTab(tabOrName)
	local target = tabOrName
	if typeof(tabOrName) == "string" then
		for _, t in ipairs(self.Tabs) do
			if t.Name == tabOrName then
				target = t
				break
			end
		end
	end
	if not target or getmetatable(target) ~= Tab then return end

	self.ActiveTab = target
	self:_layoutAll()
end

function Window:CreateTab(name, icon)
	local tab = setmetatable({
		Window = self,
		Name = tostring(name or "Tab"),
		Icon = tostring(icon or ""),
		Controls = {},
		ButtonBg = nil,
		ButtonText = nil,
		_btnPos = Vector2.zero,
		_btnSize = Vector2.zero
	}, Tab)

	tab.ButtonBg = self:_track("Square", {
		Position = Vector2.zero,
		Size = Vector2.new(1, 1),
		Filled = true,
		Transparency = 0.9,
		ZIndex = 4
	}, "tab", 0.9, nil, function()
		return self.VisibleAlpha > 0.02
	end)

	tab.ButtonText = self:_track("Text", {
		Position = Vector2.zero,
		Text = (tab.Icon ~= "" and (tab.Icon .. "  ") or "") .. tab.Name,
		Size = 14,
		Font = 2,
		Center = false,
		Outline = true,
		Transparency = 1,
		ZIndex = 5
	}, "mutedText", 1, nil, function()
		return self.VisibleAlpha > 0.02
	end)

	table.insert(self.Tabs, tab)
	if not self.ActiveTab then
		self.ActiveTab = tab
	end
	self:_layoutAll()

	return tab
end

function Tab:_addControl(control)
	table.insert(self.Controls, control)
	self.Window:_layoutTabControls(self)
	return control
end

function Tab:AddLabel(text)
	local w = self.Window
	local control = {
		Type = "Label",
		Height = 18
	}

	control.Bg = w:_track("Square", {
		Position = Vector2.zero,
		Size = Vector2.new(10, 18),
		Filled = true,
		Transparency = 0,
		Visible = false
	}, "control", 0, nil, function()
		return false
	end)

	control.Text = w:_track("Text", {
		Position = Vector2.zero,
		Text = tostring(text or "Label"),
		Size = 14,
		Font = 2,
		Center = false,
		Outline = true,
		Transparency = 1,
		ZIndex = 6
	}, "text", 1, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	function control:SetLayout(pos, width)
		self.Text.obj.Position = pos + Vector2.new(0, 0)
	end

	return self:_addControl(control)
end

function Tab:AddButton(name, callback)
	local w = self.Window
	local control = {
		Type = "Button",
		Height = 24,
		Callback = callback
	}

	control.Bg = w:_track("Square", {
		Position = Vector2.zero,
		Size = Vector2.new(10, 24),
		Filled = true,
		Transparency = 0.9,
		ZIndex = 5
	}, "control", 0.9, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.Text = w:_track("Text", {
		Position = Vector2.zero,
		Text = tostring(name or "Button"),
		Size = 14,
		Font = 2,
		Center = false,
		Outline = true,
		Transparency = 1,
		ZIndex = 6
	}, "text", 1, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.Pos = Vector2.zero
	control.Size = Vector2.new(10, 24)

	function control:SetLayout(pos, width)
		self.Pos = pos
		self.Size = Vector2.new(width, 24)
		self.Bg.obj.Position = pos
		self.Bg.obj.Size = self.Size
		self.Text.obj.Position = pos + Vector2.new(8, 3)
	end

	function control:MouseDown(m)
		if pointInRect(m, self.Pos, self.Size) then
			safeCallback(self.Callback)
			return true
		end
		return false
	end

	return self:_addControl(control)
end

function Tab:AddToggle(name, default, callback, flag)
	local w = self.Window
	local value = default and true or false

	local control = {
		Type = "Toggle",
		Height = 24,
		Value = value,
		Callback = callback,
		Flag = flag
	}

	control.Bg = w:_track("Square", {
		Position = Vector2.zero,
		Size = Vector2.new(10, 24),
		Filled = true,
		Transparency = 0.9,
		ZIndex = 5
	}, "control", 0.9, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.Indicator = w:_track("Square", {
		Position = Vector2.zero,
		Size = Vector2.new(16, 16),
		Filled = true,
		Transparency = 1,
		ZIndex = 6
	}, "tab", 1, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end, nil, function()
		return control.Value and "accent" or "tab"
	end)

	control.Text = w:_track("Text", {
		Position = Vector2.zero,
		Text = tostring(name or "Toggle"),
		Size = 14,
		Font = 2,
		Center = false,
		Outline = true,
		Transparency = 1,
		ZIndex = 6
	}, "text", 1, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.Pos = Vector2.zero
	control.Size = Vector2.new(10, 24)

	function control:Set(v, noCallback)
		self.Value = v and true or false
		if self.Flag then
			Library.Flags[self.Flag] = self.Value
		end
		if not noCallback then
			safeCallback(self.Callback, self.Value)
		end
	end

	function control:SetLayout(pos, width)
		self.Pos = pos
		self.Size = Vector2.new(width, 24)
		self.Bg.obj.Position = pos
		self.Bg.obj.Size = self.Size
		self.Indicator.obj.Position = pos + Vector2.new(width - 22, 4)
		self.Text.obj.Position = pos + Vector2.new(8, 3)
	end

	function control:MouseDown(m)
		if pointInRect(m, self.Pos, self.Size) then
			self:Set(not self.Value)
			return true
		end
		return false
	end

	if flag then Library.Flags[flag] = value end
	return self:_addControl(control)
end

function Tab:AddSlider(name, min, max, default, step, callback, flag)
	local w = self.Window
	min = tonumber(min) or 0
	max = tonumber(max) or 100
	step = tonumber(step) or 1

	local function snap(v)
		v = math.clamp(v, min, max)
		local s = math.floor(((v - min) / step) + 0.5) * step + min
		return math.clamp(s, min, max)
	end

	local control = {
		Type = "Slider",
		Height = 38,
		Min = min,
		Max = max,
		Step = step,
		Value = snap(default or min),
		Callback = callback,
		Flag = flag,
		Sliding = false
	}

	control.Label = w:_track("Text", {
		Position = Vector2.zero,
		Text = tostring(name or "Slider"),
		Size = 14,
		Font = 2,
		Center = false,
		Outline = true,
		Transparency = 1,
		ZIndex = 6
	}, "text", 1, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.ValueText = w:_track("Text", {
		Position = Vector2.zero,
		Text = tostring(control.Value),
		Size = 14,
		Font = 2,
		Center = false,
		Outline = true,
		Transparency = 1,
		ZIndex = 6
	}, "mutedText", 1, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.Track = w:_track("Square", {
		Position = Vector2.zero,
		Size = Vector2.new(10, 12),
		Filled = true,
		Transparency = 0.9,
		ZIndex = 5
	}, "control", 0.9, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.Fill = w:_track("Square", {
		Position = Vector2.zero,
		Size = Vector2.new(10, 12),
		Filled = true,
		Transparency = 1,
		ZIndex = 6
	}, "accent", 1, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.Pos = Vector2.zero
	control.Size = Vector2.new(10, 12)

	function control:_ratio()
		return (self.Value - self.Min) / (self.Max - self.Min)
	end

	function control:_updateVisual()
		local r = self:_ratio()
		self.Fill.obj.Position = self.Pos
		self.Fill.obj.Size = Vector2.new(math.max(0, self.Size.X * r), self.Size.Y)
		self.ValueText.obj.Text = tostring(self.Value)
		self.ValueText.obj.Position = Vector2.new(self.Pos.X + self.Size.X - self.ValueText.obj.TextBounds.X, self.Pos.Y - 18)
	end

	function control:Set(v, noCallback)
		self.Value = snap(v)
		if self.Flag then
			Library.Flags[self.Flag] = self.Value
		end
		self:_updateVisual()
		if not noCallback then
			safeCallback(self.Callback, self.Value)
		end
	end

	function control:SetLayout(pos, width)
		self.Label.obj.Position = pos
		self.Pos = pos + Vector2.new(0, 18)
		self.Size = Vector2.new(width, 12)

		self.Track.obj.Position = self.Pos
		self.Track.obj.Size = self.Size
		self:_updateVisual()
	end

	function control:_setFromMouse(mx, noCallback)
		local r = math.clamp((mx - self.Pos.X) / self.Size.X, 0, 1)
		self:Set(self.Min + (self.Max - self.Min) * r, noCallback)
	end

	function control:MouseDown(m)
		if pointInRect(m, self.Pos, self.Size) then
			self.Sliding = true
			self:_setFromMouse(m.X)
			return true
		end
		return false
	end

	function control:MouseUp()
		self.Sliding = false
	end

	function control:MouseMove(m)
		if self.Sliding then
			self:_setFromMouse(m.X)
		end
	end

	if flag then Library.Flags[flag] = control.Value end
	return self:_addControl(control)
end

function Tab:AddKeybind(name, defaultKey, mode, callback, flag)
	local w = self.Window
	local bindMode = tostring(mode or "Toggle")
	if bindMode ~= "Toggle" and bindMode ~= "Hold" then
		bindMode = "Toggle"
	end

	local control = {
		Type = "Keybind",
		Height = 24,
		Name = tostring(name or "Keybind"),
		Key = defaultKey or Enum.KeyCode.E,
		Mode = bindMode,
		State = false,
		Callback = callback,
		Flag = flag,
		Waiting = false
	}

	control.Bg = w:_track("Square", {
		Position = Vector2.zero,
		Size = Vector2.new(10, 24),
		Filled = true,
		Transparency = 0.9,
		ZIndex = 5
	}, "control", 0.9, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.Text = w:_track("Text", {
		Position = Vector2.zero,
		Text = "",
		Size = 14,
		Font = 2,
		Center = false,
		Outline = true,
		Transparency = 1,
		ZIndex = 6
	}, "text", 1, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.ModeText = w:_track("Text", {
		Position = Vector2.zero,
		Text = "",
		Size = 14,
		Font = 2,
		Center = false,
		Outline = true,
		Transparency = 1,
		ZIndex = 6
	}, "mutedText", 1, nil, function()
		return w.ActiveTab == self and w.VisibleAlpha > 0.02
	end)

	control.Pos = Vector2.zero
	control.Size = Vector2.new(10, 24)

	function control:_refresh()
		local keyName = self.Waiting and "..." or self.Key.Name
		self.Text.obj.Text = self.Name .. " [" .. keyName .. "]"
		self.ModeText.obj.Text = self.Mode .. (self.State and " ON" or " OFF")
	end

	function control:SetLayout(pos, width)
		self.Pos = pos
		self.Size = Vector2.new(width, 24)
		self.Bg.obj.Position = pos
		self.Bg.obj.Size = self.Size
		self.Text.obj.Position = pos + Vector2.new(8, 3)
		self.ModeText.obj.Position = pos + Vector2.new(width - 90, 3)
		self:_refresh()
	end

	function control:SetMode(m)
		if m == "Toggle" or m == "Hold" then
			self.Mode = m
			self:_refresh()
		end
	end

	function control:SetKey(key)
		if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
			self.Key = key
			self:_refresh()
		end
	end

	function control:Set(state, noCallback)
		self.State = state and true or false
		if self.Flag then
			Library.Flags[self.Flag] = self.State
		end
		self:_refresh()
		if not noCallback then
			safeCallback(self.Callback, self.State, self.Key, self.Mode)
		end
	end

	function control:MouseDown(m)
		if pointInRect(m, self.Pos, self.Size) then
			self.Waiting = true
			w.AwaitingBind = self
			self:_refresh()
			return true
		end
		return false
	end

	control:_refresh()
	if flag then Library.Flags[flag] = control.State end
	return self:_addControl(control)
end

function Window:_onInputBegan(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == self.ToggleKey then
			self:Toggle()
			return
		end

		if self.AwaitingBind then
			if input.KeyCode ~= Enum.KeyCode.Unknown then
				self.AwaitingBind:SetKey(input.KeyCode)
			end
			self.AwaitingBind.Waiting = false
			self.AwaitingBind:_refresh()
			self.AwaitingBind = nil
			return
		end

		for _, tab in ipairs(self.Tabs) do
			for _, c in ipairs(tab.Controls) do
				if c.Type == "Keybind" and c.Key == input.KeyCode then
					if c.Mode == "Toggle" then
						c:Set(not c.State)
					else
						c:Set(true)
					end
				end
			end
		end
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local m = UIS:GetMouseLocation()

	-- Drag
	local barPos, barSize = self:_windowBarRect()
	if pointInRect(m, barPos, barSize) then
		self.Dragging = true
		self.DragOffset = m - self.Position
		self.DragTarget = self.Position
	end

	-- Tabs
	for _, tab in ipairs(self.Tabs) do
		local p, s = self:_tabButtonRect(tab)
		if pointInRect(m, p, s) then
			self:SetTab(tab)
			return
		end
	end

	-- Active tab controls
	if self.ActiveTab then
		for _, c in ipairs(self.ActiveTab.Controls) do
			if c.MouseDown and c:MouseDown(m) then
				return
			end
		end
	end
end

function Window:_onInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		self.Dragging = false
		if self.ActiveTab then
			for _, c in ipairs(self.ActiveTab.Controls) do
				if c.MouseUp then
					c:MouseUp()
				end
			end
		end
	end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		for _, tab in ipairs(self.Tabs) do
			for _, c in ipairs(tab.Controls) do
				if c.Type == "Keybind" and c.Mode == "Hold" and c.Key == input.KeyCode then
					c:Set(false)
				end
			end
		end
	end
end

function Window:_update(dt)
	self.VisibleAlpha = lerp(self.VisibleAlpha, self.TargetVisible, math.clamp(dt * 12, 0, 1))
	self.ThemeHue = circularHueLerp(self.ThemeHue, self.TargetHue, math.clamp(dt * 10, 0, 1))
	self._title.obj.Text = self.TitlePrefix .. self.ThemeName

	if self.Dragging then
		local m = UIS:GetMouseLocation()
		self.DragTarget = m - self.DragOffset
	end
	self.Position = v2lerp(self.Position, self.DragTarget, math.clamp(dt * 20, 0, 1))

	self:_layoutAll()

	local mouse = UIS:GetMouseLocation()
	if self.ActiveTab then
		for _, c in ipairs(self.ActiveTab.Controls) do
			if c.MouseMove then
				c:MouseMove(mouse)
			end
		end
	end

	for _, tab in ipairs(self.Tabs) do
		local active = (tab == self.ActiveTab)
		if tab.ButtonBg then
			tab.ButtonBg.obj.Color = self:_roleColor(active and "tabActive" or "tab")
		end
		if tab.ButtonText then
			tab.ButtonText.obj.Color = self:_roleColor(active and "text" or "mutedText")
		end
	end

	for _, item in ipairs(self.DrawItems) do
		local o = item.obj
		local role = item.getRole and item.getRole() or item.role
		local vis = item.getVisible and item.getVisible() or true
		local alpha = (item.alpha or 1) * self.VisibleAlpha

		if role then
			o.Color = self:_roleColor(role)
		end

		o.Visible = vis and self.VisibleAlpha > 0.02
		o.Transparency = alpha
	end
end

function Window:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true

	if self._ib then self._ib:Disconnect() end
	if self._ie then self._ie:Disconnect() end
	if self._rs then self._rs:Disconnect() end

	for _, item in ipairs(self.DrawItems) do
		pcall(function()
			item.obj:Remove()
		end)
	end

	self.DrawItems = {}
	self.Tabs = {}
	self.ActiveTab = nil

	Library:_unregisterWindow(self)
end

return Library
