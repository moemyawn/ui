--[[
	sippin. UI Library
	Roblox GUI Library with tabs, sections, and interactive components.

	USAGE:
		local Library = loadstring(game:HttpGet("..."))()

		local Window = Library:CreateWindow({
			Title = "sippin.",
			Theme = "red", -- "red","green","blue","purple","yellow","orange","pink"
			Key = Enum.KeyCode.Minus, -- toggle key
		})

		local Tab = Window:CreateTab("Combat", "rbxassetid://...")

		local Section = Tab:CreateSection("Aimbot")

		Section:AddToggle("Silent Aim", false, function(val)
			print("Silent Aim:", val)
		end)

		Section:AddSlider("FOV", 0, 360, 90, function(val)
			print("FOV:", val)
		end)

		Section:AddButton("Teleport", function()
			print("Teleport clicked")
		end)

		Section:AddKeybind("Noclip Key", Enum.KeyCode.N, "toggle", function(state)
			print("Noclip:", state)
		end)

		Section:AddDropdown("Team", {"Red","Blue","Green"}, "Red", function(val)
			print("Team:", val)
		end)

		Section:AddColorpicker("Chams Color", Color3.fromRGB(255,0,0), function(col)
			print("Color:", col)
		end)

		Section:AddTextbox("Player Name", "Enter name...", function(val)
			print("Name:", val)
		end)
]]

local Library = {}
Library.__index = Library

-- Services
local TweenService    = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local Players         = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────
-- Theme
-- ─────────────────────────────────────────────
local THEMES = {
	red    = Color3.fromHSV(0.95, 0.70, 0.85),
	green  = Color3.fromHSV(0.30, 0.65, 0.80),
	blue   = Color3.fromHSV(0.60, 0.65, 0.85),
	purple = Color3.fromHSV(0.75, 0.60, 0.85),
	yellow = Color3.fromHSV(0.14, 0.70, 0.90),
	orange = Color3.fromHSV(0.07, 0.75, 0.90),
	pink   = Color3.fromHSV(0.87, 0.55, 0.90),
}

local PALETTE = {
	bg          = Color3.fromRGB(14, 10, 16),
	bar         = Color3.fromRGB(22, 14, 20),
	panel       = Color3.fromRGB(20, 14, 22),
	sidebar     = Color3.fromRGB(17, 12, 19),
	element     = Color3.fromRGB(28, 18, 28),
	elementHov  = Color3.fromRGB(36, 24, 36),
	border      = Color3.fromRGB(40, 26, 38),
	text        = Color3.fromRGB(210, 195, 215),
	textDim     = Color3.fromRGB(100, 82, 105),
	textDisable = Color3.fromRGB(60, 48, 64),
	white       = Color3.new(1, 1, 1),
}

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────
local function tween(obj, info, goal)
	TweenService:Create(obj, info, goal):Play()
end

local FAST  = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
local MED   = TweenInfo.new(0.22, Enum.EasingStyle.Quad)

local function makeInstance(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then inst.Parent = parent end
	return inst
end

local function roundFrame(parent, size, pos, radius, color, zindex)
	local f = makeInstance("Frame", {
		Size = size,
		Position = pos,
		BackgroundColor3 = color or PALETTE.element,
		BorderSizePixel = 0,
		ZIndex = zindex or 1,
	}, parent)
	local c = makeInstance("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, f)
	return f
end

local function label(parent, text, size, color, font, zindex)
	return makeInstance("TextLabel", {
		Text = text,
		TextSize = size or 13,
		TextColor3 = color or PALETTE.text,
		Font = font or Enum.Font.GothamMedium,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, size or 13),
		ZIndex = zindex or 2,
	}, parent)
end

-- ─────────────────────────────────────────────
-- Library:CreateWindow
-- ─────────────────────────────────────────────
function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local self = setmetatable({}, Library)
	self.Title    = cfg.Title or "sippin."
	self.Theme    = cfg.Theme or "red"
	self.ToggleKey = cfg.Key or Enum.KeyCode.Minus
	self.Visible  = true
	self._tabs    = {}
	self._activeTab = nil
	self._accentColor = THEMES[self.Theme] or THEMES.red
	self._animTarget  = self._accentColor

	-- ── ScreenGui ──
	local sg = makeInstance("ScreenGui", {
		Name = "sippinLib",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	}, PlayerGui)
	self._gui = sg

	-- ── Main Frame ──
	local main = makeInstance("Frame", {
		Name = "Main",
		Size = UDim2.new(0, 640, 0, 400),
		Position = UDim2.new(0.5, -320, 0.5, -200),
		BackgroundColor3 = PALETTE.bg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, sg)
	makeInstance("UICorner", { CornerRadius = UDim.new(0, 8) }, main)
	makeInstance("UIStroke", {
		Color = PALETTE.border,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, main)
	self._main = main

	-- ── Drop shadow ──
	local shadow = makeInstance("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.new(1, 40, 1, 40),
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.5,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		ZIndex = 0,
	}, main)

	-- ── Title bar ──
	local titleBar = makeInstance("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = PALETTE.bar,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, main)
	makeInstance("UICorner", { CornerRadius = UDim.new(0, 8) }, titleBar)
	-- flatten bottom corners
	makeInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 1, -8),
		BackgroundColor3 = PALETTE.bar,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, titleBar)

	-- accent line under title bar
	local accentLine = makeInstance("Frame", {
		Name = "AccentLine",
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = self._accentColor,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, titleBar)
	self._accentLine = accentLine

	-- Title text (prefix: "sippin.")
	local titleLabel = makeInstance("TextLabel", {
		Text = " " .. self.Title,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextColor3 = PALETTE.text,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, titleBar)
	self._titleLabel = titleLabel

	-- Suffix label: animated theme name in accent color
	local suffixLabel = makeInstance("TextLabel", {
		Text = self.Theme,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextColor3 = self._accentColor,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0), -- updated each frame
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, titleBar)
	self._suffixLabel = suffixLabel

	-- Typewriter animation state
	self._shownTheme = self.Theme
	self._animating  = false
	self._animId     = 0

	task.spawn(function()
		while titleLabel.Parent do
			local targetTheme = self.Theme
			if targetTheme ~= self._shownTheme and not self._animating then
				self._animating = true
				self._animId   += 1
				local thisAnim  = self._animId
				local oldTheme  = self._shownTheme
				self._shownTheme = targetTheme

				for i = #oldTheme, 0, -1 do
					if self._animId ~= thisAnim then break end
					suffixLabel.Text = oldTheme:sub(1, i)
					task.wait(0.03)
				end

				task.wait(0.04)

				for i = 1, #self._shownTheme do
					if self._animId ~= thisAnim then break end
					suffixLabel.Text = self._shownTheme:sub(1, i)
					task.wait(0.03)
				end

				self._animating = false
			end
			task.wait(0.05)
		end
	end)

	-- Close button
	local closeBtn = makeInstance("TextButton", {
		Text = "×",
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		TextColor3 = PALETTE.textDim,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 30, 1, 0),
		Position = UDim2.new(1, -32, 0, 0),
		ZIndex = 5,
	}, titleBar)
	closeBtn.MouseButton1Click:Connect(function()
		self:Toggle()
	end)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, FAST, { TextColor3 = self._accentColor })
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, FAST, { TextColor3 = PALETTE.textDim })
	end)

	-- ── Sidebar (tab list) ──
	local sidebar = makeInstance("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 130, 1, -32),
		Position = UDim2.new(0, 0, 0, 32),
		BackgroundColor3 = PALETTE.sidebar,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, main)

	local sideScroll = makeInstance("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -10),
		Position = UDim2.new(0, 0, 0, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = self._accentColor,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 3,
	}, sidebar)
	self._sideScroll = sideScroll
	self._sideScrollRef = sideScroll -- for accent updates

	makeInstance("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4),
	}, sideScroll)

	makeInstance("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, sideScroll)

	self._sidebar = sidebar
	self._tabButtons = {}

	-- ── Content area ──
	local content = makeInstance("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -130, 1, -32),
		Position = UDim2.new(0, 130, 0, 32),
		BackgroundColor3 = PALETTE.panel,
		BorderSizePixel = 0,
		ZIndex = 2,
		ClipsDescendants = true,
	}, main)
	self._content = content

	-- vertical divider
	makeInstance("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = PALETTE.border,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, content)

	-- ── Dragging ──
	local dragging, dragStart, frameStart = false, nil, nil
	titleBar.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = inp.Position
			frameStart = main.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = inp.Position - dragStart
			main.Position = UDim2.new(
				frameStart.X.Scale, frameStart.X.Offset + delta.X,
				frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
			)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	-- ── Toggle key ──
	UserInputService.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		if inp.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end)

	-- ── Accent color animation ──
	RunService.Heartbeat:Connect(function(dt)
		local target = THEMES[self.Theme] or THEMES.red
		local rT, gT, bT = target.R, target.G, target.B
		local rC, gC, bC = self._accentColor.R, self._accentColor.G, self._accentColor.B
		local speed = math.clamp(dt * 6, 0, 1)
		local newColor = Color3.new(
			rC + (rT - rC) * speed,
			gC + (gT - gC) * speed,
			bC + (bT - bC) * speed
		)
		self._accentColor = newColor
		accentLine.BackgroundColor3 = newColor
		sideScroll.ScrollBarImageColor3 = newColor
		-- update active tab indicator
		if self._activeTab then
			self._activeTab._indicator.BackgroundColor3 = newColor
		end
		-- keep suffix color in sync with accent
		self._suffixLabel.TextColor3 = newColor
		-- keep suffix positioned flush after prefix
		self._suffixLabel.Position = UDim2.new(
			0, titleLabel.AbsolutePosition.X - titleBar.AbsolutePosition.X + titleLabel.AbsoluteSize.X,
			0, 0
		)
	end)

	return self
end

-- ─────────────────────────────────────────────
-- Window:Toggle
-- ─────────────────────────────────────────────
function Library:Toggle()
	self.Visible = not self.Visible
	tween(self._main, MED, {
		Size = self.Visible
			and UDim2.new(0, 640, 0, 400)
			or  UDim2.new(0, 640, 0, 0),
	})
end

-- ─────────────────────────────────────────────
-- Window:SetTheme
-- ─────────────────────────────────────────────
function Library:SetTheme(theme)
	if THEMES[theme] then
		self.Theme = theme
	end
end

-- ─────────────────────────────────────────────
-- Window:CreateTab
-- ─────────────────────────────────────────────
function Library:CreateTab(name, icon)
	-- Tab page (scrollable)
	local page = makeInstance("ScrollingFrame", {
		Name = name,
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.new(0, 4, 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = PALETTE.border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 3,
	}, self._content)

	makeInstance("UIPadding", {
		PaddingLeft  = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop   = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}, page)

	makeInstance("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, page)

	-- Sidebar button
	local btn = makeInstance("TextButton", {
		Name = name .. "Btn",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = PALETTE.element,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 4,
		AutoButtonColor = false,
	}, self._sideScroll)
	makeInstance("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)

	-- Active indicator bar
	local indicator = makeInstance("Frame", {
		Name = "Indicator",
		Size = UDim2.new(0, 3, 0.6, 0),
		Position = UDim2.new(0, 0, 0.2, 0),
		BackgroundColor3 = self._accentColor,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	}, btn)
	makeInstance("UICorner", { CornerRadius = UDim.new(0, 2) }, indicator)

	-- Icon (if provided)
	local xOff = 10
	if icon and icon ~= "" then
		makeInstance("ImageLabel", {
			Image = icon,
			Size = UDim2.new(0, 16, 0, 16),
			Position = UDim2.new(0, xOff, 0.5, -8),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, btn)
		xOff = xOff + 22
	end

	local btnLabel = makeInstance("TextLabel", {
		Text = name,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextColor3 = PALETTE.textDim,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(xOff + 6), 1, 0),
		Position = UDim2.new(0, xOff, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	}, btn)

	local tab = {
		_page      = page,
		_btn       = btn,
		_indicator = indicator,
		_label     = btnLabel,
		_library   = self,
		_sections  = {},
	}

	btn.MouseEnter:Connect(function()
		if self._activeTab ~= tab then
			tween(btn, FAST, { BackgroundColor3 = PALETTE.elementHov })
		end
	end)
	btn.MouseLeave:Connect(function()
		if self._activeTab ~= tab then
			tween(btn, FAST, { BackgroundColor3 = PALETTE.element })
		end
	end)

	btn.MouseButton1Click:Connect(function()
		self:_selectTab(tab)
	end)

	table.insert(self._tabs, tab)

	if #self._tabs == 1 then
		self:_selectTab(tab)
	end

	return setmetatable(tab, { __index = tabMethods })
end

function Library:_selectTab(tab)
	-- deselect old
	if self._activeTab then
		local old = self._activeTab
		old._indicator.Visible = false
		tween(old._label, FAST, { TextColor3 = PALETTE.textDim })
		tween(old._btn, FAST, { BackgroundColor3 = PALETTE.element })
		old._page.Visible = false
	end

	self._activeTab = tab

	tab._page.Visible = true
	tab._indicator.Visible = true
	tab._indicator.BackgroundColor3 = self._accentColor
	tween(tab._label, FAST, { TextColor3 = PALETTE.text })
	tween(tab._btn, FAST, { BackgroundColor3 = PALETTE.elementHov })
end

-- ─────────────────────────────────────────────
-- Tab Methods (sections, elements)
-- ─────────────────────────────────────────────
tabMethods = {}
tabMethods.__index = tabMethods

function tabMethods:CreateSection(name)
	local lib = self._library

	-- Section container
	local section = makeInstance("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PALETTE.element,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, self._page)
	makeInstance("UICorner", { CornerRadius = UDim.new(0, 6) }, section)
	makeInstance("UIStroke", {
		Color = PALETTE.border,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, section)

	local pad = makeInstance("UIPadding", {
		PaddingLeft   = UDim.new(0, 10),
		PaddingRight  = UDim.new(0, 10),
		PaddingTop    = UDim.new(0, 28),
		PaddingBottom = UDim.new(0, 10),
	}, section)

	local list = makeInstance("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, section)

	-- Section header
	local hdr = makeInstance("TextLabel", {
		Text = name,
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		TextColor3 = lib._accentColor,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 10, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, section)

	local hdrLine = makeInstance("Frame", {
		Size = UDim2.new(1, -20, 0, 1),
		Position = UDim2.new(0, 10, 0, 22),
		BackgroundColor3 = PALETTE.border,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, section)

	-- Update header color with accent
	RunService.Heartbeat:Connect(function()
		hdr.TextColor3 = lib._accentColor
	end)

	local sectionObj = {
		_frame   = section,
		_library = lib,
		_order   = 0,
	}

	function sectionObj:_nextOrder()
		self._order += 1
		return self._order
	end

	-- ── AddToggle ──────────────────────────────────────
	function sectionObj:AddToggle(name, default, callback)
		local val = default or false
		local row = makeInstance("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			ZIndex = 4,
			LayoutOrder = self:_nextOrder(),
		}, section)

		local lbl = label(row, name, 12, PALETTE.text, Enum.Font.GothamMedium, 4)
		lbl.Size = UDim2.new(1, -44, 1, 0)
		lbl.Position = UDim2.new(0, 0, 0, 0)
		lbl.TextYAlignment = Enum.TextYAlignment.Center

		local track = makeInstance("Frame", {
			Size = UDim2.new(0, 36, 0, 18),
			Position = UDim2.new(1, -36, 0.5, -9),
			BackgroundColor3 = PALETTE.bg,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, row)
		makeInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

		local knob = makeInstance("Frame", {
			Size = UDim2.new(0, 12, 0, 12),
			Position = UDim2.new(0, 3, 0.5, -6),
			BackgroundColor3 = PALETTE.textDim,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, track)
		makeInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

		local function update(animate)
			local accentC = lib._accentColor
			if val then
				if animate then
					tween(track, FAST, { BackgroundColor3 = accentC })
					tween(knob, FAST, {
						Position = UDim2.new(0, 21, 0.5, -6),
						BackgroundColor3 = PALETTE.white,
					})
				else
					track.BackgroundColor3 = accentC
					knob.Position = UDim2.new(0, 21, 0.5, -6)
					knob.BackgroundColor3 = PALETTE.white
				end
			else
				if animate then
					tween(track, FAST, { BackgroundColor3 = PALETTE.bg })
					tween(knob, FAST, {
						Position = UDim2.new(0, 3, 0.5, -6),
						BackgroundColor3 = PALETTE.textDim,
					})
				else
					track.BackgroundColor3 = PALETTE.bg
					knob.Position = UDim2.new(0, 3, 0.5, -6)
					knob.BackgroundColor3 = PALETTE.textDim
				end
			end
		end
		update(false)

		local btn = makeInstance("TextButton", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 7,
		}, row)
		btn.MouseButton1Click:Connect(function()
			val = not val
			update(true)
			if callback then callback(val) end
		end)

		local toggle = { Value = val }
		function toggle:Set(v)
			val = v
			update(true)
		end
		return toggle
	end

	-- ── AddSlider ──────────────────────────────────────
	function sectionObj:AddSlider(name, min, max, default, callback)
		min = min or 0
		max = max or 100
		local val = math.clamp(default or min, min, max)

		local row = makeInstance("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundTransparency = 1,
			ZIndex = 4,
			LayoutOrder = self:_nextOrder(),
		}, section)

		-- Label row
		local lbl = label(row, name, 12, PALETTE.text, Enum.Font.GothamMedium, 4)
		lbl.Size = UDim2.new(1, -40, 0, 14)
		lbl.TextYAlignment = Enum.TextYAlignment.Center

		local valLbl = makeInstance("TextLabel", {
			Text = tostring(val),
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextColor3 = PALETTE.textDim,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 38, 0, 14),
			Position = UDim2.new(1, -38, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 4,
		}, row)

		-- Track
		local track = makeInstance("Frame", {
			Size = UDim2.new(1, 0, 0, 6),
			Position = UDim2.new(0, 0, 0, 22),
			BackgroundColor3 = PALETTE.bg,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, row)
		makeInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

		local fill = makeInstance("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = lib._accentColor,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, track)
		makeInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

		local thumb = makeInstance("Frame", {
			Size = UDim2.new(0, 12, 0, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			BackgroundColor3 = PALETTE.white,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, track)
		makeInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, thumb)
		makeInstance("UIStroke", { Color = PALETTE.border, Thickness = 1 }, thumb)

		local function updateVisual()
			local pct = (val - min) / (max - min)
			fill.Size = UDim2.new(pct, 0, 1, 0)
			fill.BackgroundColor3 = lib._accentColor
			thumb.Position = UDim2.new(pct, 0, 0.5, 0)
			valLbl.Text = tostring(math.round(val))
		end
		updateVisual()

		local sliding = false
		local function calcVal(inputX)
			local abs = track.AbsolutePosition.X
			local w   = track.AbsoluteSize.X
			local pct = math.clamp((inputX - abs) / w, 0, 1)
			val = min + (max - min) * pct
			val = math.round(val)
			updateVisual()
			if callback then callback(val) end
		end

		track.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				sliding = true
				calcVal(inp.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(inp)
			if sliding and inp.UserInputType == Enum.UserInputType.MouseMovement then
				calcVal(inp.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				sliding = false
			end
		end)

		local slider = { Value = val }
		function slider:Set(v)
			val = math.clamp(v, min, max)
			updateVisual()
		end
		return slider
	end

	-- ── AddButton ──────────────────────────────────────
	function sectionObj:AddButton(name, callback)
		local btn = makeInstance("TextButton", {
			Name = name,
			Text = name,
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			TextColor3 = PALETTE.text,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = PALETTE.bg,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			ZIndex = 4,
			LayoutOrder = self:_nextOrder(),
		}, section)
		makeInstance("UICorner", { CornerRadius = UDim.new(0, 5) }, btn)
		makeInstance("UIStroke", { Color = PALETTE.border, Thickness = 1 }, btn)

		btn.MouseEnter:Connect(function()
			tween(btn, FAST, { BackgroundColor3 = lib._accentColor, TextColor3 = PALETTE.white })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, FAST, { BackgroundColor3 = PALETTE.bg, TextColor3 = PALETTE.text })
		end)
		btn.MouseButton1Click:Connect(function()
			-- flash
			tween(btn, TweenInfo.new(0.06), { BackgroundColor3 = PALETTE.white })
			task.delay(0.08, function()
				tween(btn, FAST, { BackgroundColor3 = PALETTE.bg })
			end)
			if callback then callback() end
		end)
	end

	-- ── AddKeybind ──────────────────────────────────────
	-- mode: "toggle" or "hold"
	function sectionObj:AddKeybind(name, default, mode, callback)
		mode = mode or "toggle"
		local key = default or Enum.KeyCode.Unknown
		local active = false
		local listening = false

		local row = makeInstance("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			ZIndex = 4,
			LayoutOrder = self:_nextOrder(),
		}, section)

		local lbl = label(row, name, 12, PALETTE.text, Enum.Font.GothamMedium, 4)
		lbl.Size = UDim2.new(1, -80, 1, 0)
		lbl.TextYAlignment = Enum.TextYAlignment.Center

		local keyBtn = makeInstance("TextButton", {
			Text = key.Name,
			TextSize = 10,
			Font = Enum.Font.GothamMedium,
			TextColor3 = PALETTE.text,
			Size = UDim2.new(0, 74, 0, 20),
			Position = UDim2.new(1, -74, 0.5, -10),
			BackgroundColor3 = PALETTE.bg,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			ZIndex = 5,
		}, row)
		makeInstance("UICorner", { CornerRadius = UDim.new(0, 4) }, keyBtn)
		makeInstance("UIStroke", { Color = PALETTE.border, Thickness = 1 }, keyBtn)

		local statusDot = makeInstance("Frame", {
			Size = UDim2.new(0, 6, 0, 6),
			Position = UDim2.new(0, -10, 0.5, -3),
			BackgroundColor3 = PALETTE.textDisable,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, keyBtn)
		makeInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, statusDot)

		local function setActive(v)
			active = v
			tween(statusDot, FAST, {
				BackgroundColor3 = v and lib._accentColor or PALETTE.textDisable
			})
			if callback then callback(active) end
		end

		keyBtn.MouseButton1Click:Connect(function()
			listening = true
			keyBtn.Text = "..."
			tween(keyBtn, FAST, { BackgroundColor3 = lib._accentColor })
		end)

		UserInputService.InputBegan:Connect(function(inp, gpe)
			if listening then
				if inp.UserInputType == Enum.UserInputType.Keyboard then
					key = inp.KeyCode
					keyBtn.Text = key.Name
					listening = false
					tween(keyBtn, FAST, { BackgroundColor3 = PALETTE.bg })
				end
				return
			end
			if gpe then return end
			if inp.KeyCode == key then
				if mode == "toggle" then
					setActive(not active)
				elseif mode == "hold" then
					setActive(true)
				end
			end
		end)

		UserInputService.InputEnded:Connect(function(inp)
			if mode == "hold" and inp.KeyCode == key then
				setActive(false)
			end
		end)

		local keybind = { Key = key, Active = active }
		function keybind:Set(k)
			key = k
			keyBtn.Text = k.Name
		end
		return keybind
	end

	-- ── AddDropdown ──────────────────────────────────────
	function sectionObj:AddDropdown(name, options, default, callback)
		local val = default or options[1]
		local open = false

		local wrapper = makeInstance("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			ZIndex = 4,
			LayoutOrder = self:_nextOrder(),
			ClipsDescendants = false,
		}, section)

		local lbl = label(wrapper, name, 12, PALETTE.text, Enum.Font.GothamMedium, 4)
		lbl.Size = UDim2.new(1, -140, 1, 0)
		lbl.TextYAlignment = Enum.TextYAlignment.Center

		local dropBtn = makeInstance("TextButton", {
			Text = val,
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextColor3 = PALETTE.text,
			Size = UDim2.new(0, 130, 0, 22),
			Position = UDim2.new(1, -130, 0.5, -11),
			BackgroundColor3 = PALETTE.bg,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			ClipsDescendants = false,
		}, wrapper)
		makeInstance("UICorner", { CornerRadius = UDim.new(0, 4) }, dropBtn)
		makeInstance("UIStroke", { Color = PALETTE.border, Thickness = 1 }, dropBtn)
		makeInstance("UIPadding", { PaddingLeft = UDim.new(0, 6) }, dropBtn)

		local arrow = makeInstance("TextLabel", {
			Text = "▾",
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			TextColor3 = PALETTE.textDim,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 16, 1, 0),
			Position = UDim2.new(1, -16, 0, 0),
			ZIndex = 6,
		}, dropBtn)

		-- Option list
		local optFrame = makeInstance("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(0, 0, 1, 4),
			BackgroundColor3 = PALETTE.element,
			BorderSizePixel = 0,
			ZIndex = 20,
			Visible = false,
			ClipsDescendants = true,
		}, dropBtn)
		makeInstance("UICorner", { CornerRadius = UDim.new(0, 4) }, optFrame)
		makeInstance("UIStroke", { Color = PALETTE.border, Thickness = 1 }, optFrame)
		makeInstance("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, optFrame)

		for _, opt in ipairs(options) do
			local optBtn = makeInstance("TextButton", {
				Text = opt,
				TextSize = 11,
				Font = Enum.Font.Gotham,
				TextColor3 = opt == val and PALETTE.text or PALETTE.textDim,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = PALETTE.element,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 21,
			}, optFrame)
			makeInstance("UIPadding", { PaddingLeft = UDim.new(0, 8) }, optBtn)

			optBtn.MouseEnter:Connect(function()
				tween(optBtn, FAST, { BackgroundColor3 = PALETTE.elementHov })
			end)
			optBtn.MouseLeave:Connect(function()
				tween(optBtn, FAST, { BackgroundColor3 = PALETTE.element })
			end)
			optBtn.MouseButton1Click:Connect(function()
				val = opt
				dropBtn.Text = opt
				-- re-pad text because TextButton loses padding
				open = false
				tween(optFrame, FAST, { Size = UDim2.new(1, 0, 0, 0) })
				task.delay(0.12, function() optFrame.Visible = false end)
				tween(arrow, FAST, { Rotation = 0 })
				if callback then callback(val) end
			end)
		end

		local totalH = #options * 24

		dropBtn.MouseButton1Click:Connect(function()
			open = not open
			if open then
				optFrame.Visible = true
				optFrame.Size = UDim2.new(1, 0, 0, 0)
				tween(optFrame, MED, { Size = UDim2.new(1, 0, 0, totalH) })
				tween(arrow, FAST, { Rotation = 180 })
			else
				tween(optFrame, MED, { Size = UDim2.new(1, 0, 0, 0) })
				tween(arrow, FAST, { Rotation = 0 })
				task.delay(0.22, function() optFrame.Visible = false end)
			end
		end)

		local dropdown = { Value = val }
		function dropdown:Set(v)
			val = v
			dropBtn.Text = v
		end
		return dropdown
	end

	-- ── AddTextbox ──────────────────────────────────────
	function sectionObj:AddTextbox(name, placeholder, callback)
		local row = makeInstance("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			ZIndex = 4,
			LayoutOrder = self:_nextOrder(),
		}, section)

		local lbl = label(row, name, 12, PALETTE.text, Enum.Font.GothamMedium, 4)
		lbl.Size = UDim2.new(1, -145, 1, 0)
		lbl.TextYAlignment = Enum.TextYAlignment.Center

		local box = makeInstance("TextBox", {
			PlaceholderText = placeholder or "",
			PlaceholderColor3 = PALETTE.textDim,
			Text = "",
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextColor3 = PALETTE.text,
			Size = UDim2.new(0, 130, 0, 22),
			Position = UDim2.new(1, -130, 0.5, -11),
			BackgroundColor3 = PALETTE.bg,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			ZIndex = 5,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		makeInstance("UICorner", { CornerRadius = UDim.new(0, 4) }, box)
		local stroke = makeInstance("UIStroke", { Color = PALETTE.border, Thickness = 1 }, box)
		makeInstance("UIPadding", { PaddingLeft = UDim.new(0, 6) }, box)

		box.Focused:Connect(function()
			tween(stroke, FAST, { Color = lib._accentColor })
		end)
		box.FocusLost:Connect(function(enter)
			tween(stroke, FAST, { Color = PALETTE.border })
			if callback then callback(box.Text) end
		end)

		local textbox = { Value = "" }
		function textbox:Set(v)
			box.Text = v
		end
		return textbox
	end

	-- ── AddColorpicker ──────────────────────────────────────
	-- Simple RGB sliders
	function sectionObj:AddColorpicker(name, default, callback)
		default = default or Color3.new(1, 0, 0)
		local r, g, b = default.R * 255, default.G * 255, default.B * 255

		local expanded = false

		local wrapper = makeInstance("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 28),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = 4,
			LayoutOrder = self:_nextOrder(),
		}, section)
		makeInstance("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}, wrapper)

		local headerRow = makeInstance("Frame", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			ZIndex = 4,
			LayoutOrder = 0,
		}, wrapper)

		local lbl = label(headerRow, name, 12, PALETTE.text, Enum.Font.GothamMedium, 4)
		lbl.Size = UDim2.new(1, -50, 1, 0)
		lbl.TextYAlignment = Enum.TextYAlignment.Center

		local preview = makeInstance("TextButton", {
			Text = "",
			Size = UDim2.new(0, 40, 0, 20),
			Position = UDim2.new(1, -40, 0.5, -10),
			BackgroundColor3 = default,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			ZIndex = 5,
		}, headerRow)
		makeInstance("UICorner", { CornerRadius = UDim.new(0, 4) }, preview)
		makeInstance("UIStroke", { Color = PALETTE.border, Thickness = 1 }, preview)

		-- Expanded sliders container
		local sliderFrame = makeInstance("Frame", {
			Name = "Sliders",
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			ZIndex = 4,
			LayoutOrder = 1,
			ClipsDescendants = true,
		}, wrapper)
		makeInstance("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}, sliderFrame)

		local function updateColor()
			local c = Color3.fromRGB(r, g, b)
			preview.BackgroundColor3 = c
			if callback then callback(c) end
		end

		local function makeColorSlider(label_, channel, startVal)
			local slRow = makeInstance("Frame", {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, sliderFrame)

			local lbl2 = makeInstance("TextLabel", {
				Text = label_,
				TextSize = 10,
				Font = Enum.Font.Gotham,
				TextColor3 = PALETTE.textDim,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 10, 1, 0),
				ZIndex = 4,
			}, slRow)

			local track = makeInstance("Frame", {
				Size = UDim2.new(1, -18, 0, 5),
				Position = UDim2.new(0, 14, 0.5, -2),
				BackgroundColor3 = PALETTE.bg,
				BorderSizePixel = 0,
				ZIndex = 4,
			}, slRow)
			makeInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

			local fill = makeInstance("Frame", {
				Size = UDim2.new(startVal / 255, 0, 1, 0),
				BackgroundColor3 = lib._accentColor,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, track)
			makeInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

			local thumb = makeInstance("Frame", {
				Size = UDim2.new(0, 9, 0, 9),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(startVal / 255, 0, 0.5, 0),
				BackgroundColor3 = PALETTE.white,
				BorderSizePixel = 0,
				ZIndex = 6,
			}, track)
			makeInstance("UICorner", { CornerRadius = UDim.new(1, 0) }, thumb)

			local sliding = false
			track.InputBegan:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 then
					sliding = true
					local pct = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
					if channel == "r" then r = math.round(pct * 255)
					elseif channel == "g" then g = math.round(pct * 255)
					elseif channel == "b" then b = math.round(pct * 255) end
					fill.Size = UDim2.new(pct, 0, 1, 0)
					thumb.Position = UDim2.new(pct, 0, 0.5, 0)
					updateColor()
				end
			end)
			UserInputService.InputChanged:Connect(function(inp)
				if sliding and inp.UserInputType == Enum.UserInputType.MouseMovement then
					local pct = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
					if channel == "r" then r = math.round(pct * 255)
					elseif channel == "g" then g = math.round(pct * 255)
					elseif channel == "b" then b = math.round(pct * 255) end
					fill.Size = UDim2.new(pct, 0, 1, 0)
					thumb.Position = UDim2.new(pct, 0, 0.5, 0)
					updateColor()
				end
			end)
			UserInputService.InputEnded:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 then
					sliding = false
				end
			end)
		end

		makeColorSlider("R", "r", r)
		makeColorSlider("G", "g", g)
		makeColorSlider("B", "b", b)

		preview.MouseButton1Click:Connect(function()
			expanded = not expanded
			tween(sliderFrame, MED, {
				Size = expanded
					and UDim2.new(1, 0, 0, 3 * 16 + 8)
					or  UDim2.new(1, 0, 0, 0)
			})
		end)

		local cp = { Value = default }
		function cp:Set(c)
			r, g, b = c.R * 255, c.G * 255, c.B * 255
			updateColor()
		end
		return cp
	end

	-- ── AddLabel ──────────────────────────────────────
	function sectionObj:AddLabel(text)
		local lbl = makeInstance("TextLabel", {
			Text = text,
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextColor3 = PALETTE.textDim,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ZIndex = 4,
			LayoutOrder = self:_nextOrder(),
		}, section)
		return lbl
	end

	-- ── AddSeparator ──────────────────────────────────────
	function sectionObj:AddSeparator()
		local sep = makeInstance("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = PALETTE.border,
			BorderSizePixel = 0,
			ZIndex = 4,
			LayoutOrder = self:_nextOrder(),
		}, section)
		return sep
	end

	return sectionObj
end

return Library
