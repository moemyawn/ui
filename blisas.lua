--[[
    bliss.lua
    drawing-based ui lib for UNC/sUNC runtimes
    "stay blissful!"
--]]

-- == global cleanup ==

local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local GS = game:GetService("GuiService")
local HS = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local GENV = (getgenv and getgenv()) or _G
local BLISS_KEY = "__bliss_runtime__"
local prev = GENV[BLISS_KEY]
if type(prev) == "table" and prev.DestroyAll then
    pcall(function() prev:DestroyAll() end)
end

local bliss = {}
bliss._windows = {}
bliss._connections = {}
bliss._allDrawings = {}
bliss._visible = true
bliss._toggleKey = Enum.KeyCode.Equals
bliss._notifications = {}
bliss._tooltipData = nil
bliss.membrane = false

-- == palette ==

local pal = {
    bg           = Color3.fromRGB(15, 14, 18),
    bgDeep       = Color3.fromRGB(10, 9, 13),
    panel        = Color3.fromRGB(21, 20, 25),
    panelLit     = Color3.fromRGB(28, 27, 33),
    panelDeep    = Color3.fromRGB(17, 16, 20),
    hover        = Color3.fromRGB(35, 33, 42),
    press        = Color3.fromRGB(44, 41, 52),
    border       = Color3.fromRGB(42, 40, 50),
    borderDim    = Color3.fromRGB(30, 29, 36),
    borderLit    = Color3.fromRGB(58, 55, 68),
    text         = Color3.fromRGB(218, 215, 225),
    textSub      = Color3.fromRGB(138, 133, 152),
    textDim      = Color3.fromRGB(78, 74, 90),
    textOff      = Color3.fromRGB(55, 52, 65),
    accent       = Color3.fromRGB(238, 128, 142),
    accentDim    = Color3.fromRGB(188, 95, 108),
    accentLit    = Color3.fromRGB(255, 162, 172),
    accentSoft   = Color3.fromRGB(238, 128, 142),
    accentGlow   = Color3.fromRGB(255, 180, 190),
    shadow       = Color3.fromRGB(5, 4, 8),
    good         = Color3.fromRGB(108, 198, 138),
    warn         = Color3.fromRGB(215, 185, 88),
    bad          = Color3.fromRGB(215, 88, 88),
    black        = Color3.fromRGB(0, 0, 0),
    white        = Color3.fromRGB(255, 255, 255),
}

-- == sizing ==

local sz = {
    titleH      = 34,
    tabW        = 120,
    elemH       = 32,
    elemGap     = 5,
    pad         = 10,
    font        = 13,
    fontSm      = 11,
    fontXs      = 10,
    round       = 6,
    roundSm     = 4,
    roundXs     = 3,
    sliderH     = 5,
    toggleW     = 36,
    toggleH     = 18,
    colorBox    = 16,
    shadowOff   = 6,
    shadowAlpha = 0.55,
    notifW      = 240,
    notifH      = 58,
    tooltipPad  = 6,
}

-- == drawing constructors ==

local function track(d)
    bliss._allDrawings[#bliss._allDrawings + 1] = d
    return d
end

local function setProp(obj, key, val)
    if val == nil then return end
    pcall(function() obj[key] = val end)
end

local function newRect(p)
    local d = Drawing.new("Square")
    setProp(d, "Visible", p.Visible or false)
    setProp(d, "Filled", (p.Filled == nil) and true or p.Filled)
    setProp(d, "Color", p.Color or pal.bg)
    setProp(d, "Position", p.Position or Vector2.new(0, 0))
    setProp(d, "Size", p.Size or Vector2.new(10, 10))
    setProp(d, "Thickness", p.Thickness or 1)
    setProp(d, "Transparency", (p.Transparency ~= nil) and p.Transparency or 0)
    setProp(d, "Rounding", p.Rounding or 0)
    setProp(d, "ZIndex", p.ZIndex or 1)
    return track(d)
end

local function newLabel(p)
    local d = Drawing.new("Text")
    setProp(d, "Visible", p.Visible or false)
    setProp(d, "Text", p.Text or "")
    setProp(d, "Size", p.Size or sz.font)
    setProp(d, "Color", p.Color or pal.text)
    setProp(d, "Position", p.Position or Vector2.new(0, 0))
    setProp(d, "Center", p.Center or false)
    setProp(d, "Outline", true)
    setProp(d, "OutlineColor", pal.black)
    setProp(d, "Font", p.Font or 2)
    setProp(d, "Transparency", (p.Transparency ~= nil) and p.Transparency or 0)
    setProp(d, "ZIndex", p.ZIndex or 2)
    return track(d)
end

local function newLine(p)
    local d = Drawing.new("Line")
    setProp(d, "Visible", p.Visible or false)
    setProp(d, "From", p.From or Vector2.new(0, 0))
    setProp(d, "To", p.To or Vector2.new(0, 0))
    setProp(d, "Color", p.Color or pal.border)
    setProp(d, "Thickness", p.Thickness or 1)
    setProp(d, "Transparency", (p.Transparency ~= nil) and p.Transparency or 0)
    setProp(d, "ZIndex", p.ZIndex or 1)
    return track(d)
end

local function newDot(p)
    local d = Drawing.new("Circle")
    setProp(d, "Visible", p.Visible or false)
    setProp(d, "Filled", (p.Filled == nil) and true or p.Filled)
    setProp(d, "Color", p.Color or pal.accent)
    setProp(d, "Position", p.Position or Vector2.new(0, 0))
    setProp(d, "Radius", p.Radius or 5)
    setProp(d, "NumSides", p.NumSides or 24)
    setProp(d, "Thickness", p.Thickness or 1)
    setProp(d, "Transparency", (p.Transparency ~= nil) and p.Transparency or 0)
    setProp(d, "ZIndex", p.ZIndex or 2)
    return track(d)
end

local function newTri(p)
    local d = Drawing.new("Triangle")
    setProp(d, "Visible", p.Visible or false)
    setProp(d, "Filled", (p.Filled == nil) and true or p.Filled)
    setProp(d, "Color", p.Color or pal.text)
    setProp(d, "PointA", p.A or Vector2.new(0, 0))
    setProp(d, "PointB", p.B or Vector2.new(0, 0))
    setProp(d, "PointC", p.C or Vector2.new(0, 0))
    setProp(d, "Thickness", p.Thickness or 1)
    setProp(d, "Transparency", (p.Transparency ~= nil) and p.Transparency or 0)
    setProp(d, "ZIndex", p.ZIndex or 2)
    return track(d)
end

local function kill(d)
    if not d then return end
    pcall(function()
        if d.Remove then d:Remove()
        elseif d.Destroy then d:Destroy() end
    end)
end

-- == math and easing ==

local clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local snap = function(n, s) s = s or 1; return math.floor(n / s + 0.5) * s end
local hit = function(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

local function lerp(a, b, t)
    return a + (b - a) * clamp(t, 0, 1)
end

local function lc(a, b, t)
    t = clamp(t, 0, 1)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

local function easeOutQuart(t)
    return 1 - math.pow(1 - t, 4)
end

local function easeOutElastic(t)
    if t == 0 or t == 1 then return t end
    local p = 0.4
    return math.pow(2, -10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
end

local function bounce(current, target, speed, overshoot)
    overshoot = overshoot or 0.08
    local diff = target - current
    if math.abs(diff) < 0.001 then return target end
    local raw = current + diff * clamp(speed, 0, 1)
    if overshoot > 0 and math.abs(diff) > 0.01 then
        raw = raw + diff * overshoot * math.sin(os.clock() * 12)
    end
    return raw
end

local function smoothDamp(current, target, vel, smoothTime, dt)
    smoothTime = math.max(0.0001, smoothTime)
    local omega = 2 / smoothTime
    local x = omega * dt
    local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    local change = current - target
    local temp = (vel + omega * change) * dt
    vel = (vel - omega * temp) * exp
    local result = target + (change + temp) * exp
    return result, vel
end

-- == text measurement ==

local _measureCache = {}
local _measureLabel = nil

local function measureText(text, fontSize, font)
    font = font or 2
    local key = text .. ":" .. fontSize .. ":" .. font
    if _measureCache[key] then return _measureCache[key] end
    if not _measureLabel then
        _measureLabel = Drawing.new("Text")
        _measureLabel.Visible = false
        _measureLabel.Size = 13
        _measureLabel.Font = 2
    end
    _measureLabel.Text = text
    _measureLabel.Size = fontSize
    _measureLabel.Font = font
    local bounds = Vector2.new(0, 0)
    pcall(function()
        bounds = _measureLabel.TextBounds
    end)
    if bounds.X == 0 then
        bounds = Vector2.new(#text * fontSize * 0.55, fontSize)
    end
    _measureCache[key] = bounds
    return bounds
end

-- == input state ==

local mx, my, mDown, mClick, mRClick, mScroll = 0, 0, false, false, false, 0
local mClickConsumed = false
local mRClickConsumed = false
local prevMDown = false
local insetY = 0
pcall(function()
    local _, inset = GS:GetGuiInset()
    insetY = inset.Y or 0
end)

table.insert(bliss._connections, UIS.InputChanged:Connect(function(io)
    if io.UserInputType == Enum.UserInputType.MouseMovement then
        mx, my = io.Position.X, io.Position.Y
    elseif io.UserInputType == Enum.UserInputType.MouseWheel then
        mScroll = io.Position.Z
    end
end))

table.insert(bliss._connections, UIS.InputBegan:Connect(function(io, gp)
    if io.UserInputType == Enum.UserInputType.MouseButton1 then
        mDown = true
        if not prevMDown then mClick = true end
    elseif io.UserInputType == Enum.UserInputType.MouseButton2 then
        mRClick = true
    end
    if io.KeyCode == bliss._toggleKey then
        bliss._visible = not bliss._visible
    end
end))

table.insert(bliss._connections, UIS.InputEnded:Connect(function(io)
    if io.UserInputType == Enum.UserInputType.MouseButton1 then
        mDown = false
    end
end))

-- == membrane (gc management) ==

local _membraneLastGC = 0
local _membraneBaseline = 0
local _membraneSamples = {}

local function membraneUpdate()
    if not bliss.membrane then return end
    local now = os.clock()
    if now - _membraneLastGC < 2 then return end

    local mem = collectgarbage("count")
    _membraneSamples[#_membraneSamples + 1] = mem
    if #_membraneSamples > 30 then table.remove(_membraneSamples, 1) end

    if _membraneBaseline == 0 and #_membraneSamples >= 5 then
        local sum = 0
        for _, v in ipairs(_membraneSamples) do sum = sum + v end
        _membraneBaseline = sum / #_membraneSamples
    end

    if _membraneBaseline > 0 then
        local threshold = _membraneBaseline * 1.5
        if mem > threshold then
            collectgarbage("collect")
            _membraneLastGC = now
        elseif now - _membraneLastGC > 30 then
            collectgarbage("step", 100)
            _membraneLastGC = now
        end
    end
end

-- == notification system ==

local _notifDrawings = {}

local function updateNotifications(dt)
    local screenW = workspace.CurrentCamera.ViewportSize.X
    local baseY = workspace.CurrentCamera.ViewportSize.Y - 16
    local i = #bliss._notifications
    while i >= 1 do
        local n = bliss._notifications[i]
        n._life = n._life + dt
        if n._life > n.duration then
            n._fadeOut = (n._fadeOut or 0) + dt * 4
            if n._fadeOut >= 1 then
                for _, d in pairs(n._d) do kill(d) end
                table.remove(bliss._notifications, i)
                i = i - 1
                goto continue
            end
        end
        local fadeIn = clamp(n._life * 5, 0, 1)
        local fadeOut = 1 - (n._fadeOut or 0)
        local alpha = fadeIn * fadeOut
        local ny = baseY - (sz.notifH + 6) * (#bliss._notifications - i + 1)
        local nx = screenW - sz.notifW - 16
        n._posY = lerp(n._posY or (ny + 20), ny, 0.15)
        local accentCol = n.color or pal.accent
        n._d.bg.Visible = bliss._visible
        n._d.bg.Position = Vector2.new(nx, n._posY)
        n._d.bg.Size = Vector2.new(sz.notifW, sz.notifH)
        n._d.bg.Color = pal.panel
        n._d.bg.Transparency = (1 - alpha) * 0.5
        n._d.bg.Rounding = sz.roundSm
        n._d.bgOut.Visible = bliss._visible
        n._d.bgOut.Position = Vector2.new(nx, n._posY)
        n._d.bgOut.Size = Vector2.new(sz.notifW, sz.notifH)
        n._d.bgOut.Color = lc(pal.borderDim, accentCol, 0.3)
        n._d.bgOut.Rounding = sz.roundSm
        n._d.bar.Visible = bliss._visible
        n._d.bar.Position = Vector2.new(nx + 4, n._posY + 4)
        n._d.bar.Size = Vector2.new(3, sz.notifH - 8)
        n._d.bar.Color = accentCol
        n._d.bar.Rounding = 2
        n._d.title.Visible = bliss._visible
        n._d.title.Position = Vector2.new(nx + 14, n._posY + 8)
        n._d.title.Text = n.title
        n._d.title.Color = pal.text
        n._d.title.Transparency = 1 - alpha
        n._d.msg.Visible = bliss._visible
        n._d.msg.Position = Vector2.new(nx + 14, n._posY + 26)
        n._d.msg.Text = n.message
        n._d.msg.Color = pal.textSub
        n._d.msg.Transparency = 1 - alpha
        local progW = sz.notifW - 8
        local progPct = clamp(n._life / n.duration, 0, 1)
        n._d.prog.Visible = bliss._visible
        n._d.prog.Position = Vector2.new(nx + 4, n._posY + sz.notifH - 5)
        n._d.prog.Size = Vector2.new(progW * (1 - progPct), 2)
        n._d.prog.Color = accentCol
        n._d.prog.Rounding = 1
        ::continue::
        i = i - 1
    end
end

function bliss:Notify(opts)
    opts = opts or {}
    local colorMap = { success = pal.good, warning = pal.warn, error = pal.bad, info = pal.accent }
    local n = {
        title = opts.Title or "bliss.lua",
        message = opts.Message or "",
        duration = opts.Duration or 3,
        color = colorMap[opts.Type or "info"] or pal.accent,
        _life = 0, _fadeOut = 0, _posY = workspace.CurrentCamera.ViewportSize.Y,
        _d = {
            bg = newRect({ Rounding = sz.roundSm, ZIndex = 200 }),
            bgOut = newRect({ Filled = false, Rounding = sz.roundSm, ZIndex = 200 }),
            bar = newRect({ Rounding = 2, ZIndex = 201 }),
            title = newLabel({ Size = sz.font, ZIndex = 202 }),
            msg = newLabel({ Size = sz.fontSm, ZIndex = 202 }),
            prog = newRect({ Rounding = 1, ZIndex = 201 }),
        },
    }
    self._notifications[#self._notifications + 1] = n
end

-- == tooltip system ==

local _tooltip = {
    text = "", show = false, alpha = 0,
    _d = {
        bg = newRect({ Rounding = sz.roundXs, ZIndex = 210, Color = pal.panelDeep }),
        bgOut = newRect({ Filled = false, Rounding = sz.roundXs, ZIndex = 210, Color = pal.borderDim }),
        label = newLabel({ Size = sz.fontSm, ZIndex = 211, Color = pal.textSub }),
    },
    _hoverTime = 0,
    _target = "",
}

local function updateTooltip()
    if _tooltip._target ~= "" then
        _tooltip._hoverTime = _tooltip._hoverTime + (1/60)
    else
        _tooltip._hoverTime = 0
    end
    _tooltip.show = _tooltip._hoverTime > 0.45 and _tooltip._target ~= ""
    _tooltip.alpha = lerp(_tooltip.alpha, _tooltip.show and 1 or 0, 0.18)
    local vis = _tooltip.alpha > 0.02 and bliss._visible
    for _, d in pairs(_tooltip._d) do d.Visible = vis end
    if not vis then return end
    local bounds = measureText(_tooltip._target, sz.fontSm)
    local pw = bounds.X + sz.tooltipPad * 2
    local ph = bounds.Y + sz.tooltipPad * 2
    local tx = mx + 14
    local ty = my + 14
    local scrW = workspace.CurrentCamera.ViewportSize.X
    if tx + pw > scrW - 8 then tx = mx - pw - 4 end
    _tooltip._d.bg.Position = Vector2.new(tx, ty)
    _tooltip._d.bg.Size = Vector2.new(pw, ph)
    _tooltip._d.bg.Transparency = 1 - _tooltip.alpha
    _tooltip._d.bgOut.Position = Vector2.new(tx, ty)
    _tooltip._d.bgOut.Size = Vector2.new(pw, ph)
    _tooltip._d.bgOut.Transparency = 1 - _tooltip.alpha
    _tooltip._d.label.Position = Vector2.new(tx + sz.tooltipPad, ty + sz.tooltipPad - 2)
    _tooltip._d.label.Text = _tooltip._target
    _tooltip._d.label.Transparency = 1 - _tooltip.alpha
end

local function setTooltip(text)
    if text and text ~= "" then
        if _tooltip._target ~= text then
            _tooltip._hoverTime = 0
        end
        _tooltip._target = text
    else
        _tooltip._target = ""
    end
end

-- == config system ==

local Config = {}

local function b64enc(data)
    local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    return ((data:gsub(".", function(x)
        local r, byte = "", x:byte()
        for i = 8, 1, -1 do r = r .. (byte % 2^i - byte % 2^(i-1) > 0 and "1" or "0") end
        return r
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
        if #x < 6 then return "" end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i,i) == "1" and 2^(6-i) or 0) end
        return b:sub(c+1, c+1)
    end) .. ({"", "==", "="})[#data % 3 + 1])
end

local function b64dec(data)
    local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    data = data:gsub("[^" .. b .. "=]", "")
    return (data:gsub(".", function(x)
        if x == "=" then return "" end
        local r, f = "", (b:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and "1" or "0") end
        return r
    end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
        if #x ~= 8 then return "" end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == "1" and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function serializeColor3(c)
    return { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) }
end

local function deserializeColor3(t)
    return Color3.fromRGB(t[1], t[2], t[3])
end

function Config.Gather(win)
    local data = {}
    for _, tab in ipairs(win._tabs) do
        for _, el in ipairs(tab._elems) do
            if el.flag then
                local v = el.val
                if typeof(v) == "Color3" then
                    data[el.flag] = { _type = "Color3", _val = serializeColor3(v) }
                elseif typeof(v) == "EnumItem" then
                    data[el.flag] = { _type = "EnumItem", _val = tostring(v) }
                elseif type(v) == "table" then
                    data[el.flag] = { _type = "table", _val = v }
                else
                    data[el.flag] = v
                end
            end
        end
    end
    return data
end

function Config.Apply(win, data)
    for _, tab in ipairs(win._tabs) do
        for _, el in ipairs(tab._elems) do
            if el.flag and data[el.flag] ~= nil then
                local v = data[el.flag]
                if type(v) == "table" and v._type then
                    if v._type == "Color3" then
                        v = deserializeColor3(v._val)
                    elseif v._type == "EnumItem" then
                        pcall(function()
                            local parts = tostring(v._val):split(".")
                            v = Enum[parts[2]][parts[3]]
                        end)
                    elseif v._type == "table" then
                        v = v._val
                    end
                end
                if el.set then
                    el:set(v)
                else
                    el.val = v
                end
            end
        end
    end
end

function Config.Save(win, name)
    local data = Config.Gather(win)
    local json = HS:JSONEncode(data)
    local encoded = b64enc(json)
    local path = "bliss/" .. (name or win._name) .. ".cfg"
    if makefolder then pcall(makefolder, "bliss") end
    if writefile then
        writefile(path, encoded)
        return true
    end
    return false
end

function Config.Load(win, name)
    local path = "bliss/" .. (name or win._name) .. ".cfg"
    if not readfile then return false end
    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return false end
    local json = b64dec(raw)
    local ok2, data = pcall(HS.JSONDecode, HS, json)
    if not ok2 or type(data) ~= "table" then return false end
    Config.Apply(win, data)
    return true
end

function Config.Export(win)
    local data = Config.Gather(win)
    local json = HS:JSONEncode(data)
    return b64enc(json)
end

function Config.Import(win, str)
    local json = b64dec(str)
    local ok, data = pcall(HS.JSONDecode, HS, json)
    if not ok or type(data) ~= "table" then return false end
    Config.Apply(win, data)
    return true
end

function Config.List()
    local files = {}
    if listfiles then
        pcall(function()
            for _, f in ipairs(listfiles("bliss")) do
                if f:match("%.cfg$") then
                    files[#files + 1] = f:match("([^/\\]+)%.cfg$")
                end
            end
        end)
    end
    return files
end

function Config.Delete(name)
    if delfile then
        pcall(delfile, "bliss/" .. name .. ".cfg")
        return true
    end
    return false
end

bliss.Config = Config

-- == elements ==

local function mkToggle(o, flags)
    local e = {
        type = "toggle", name = o.Name or "toggle",
        val = o.Default or false, cb = o.Callback or function() end,
        flag = o.Flag, h = sz.elemH, tip = o.Tooltip,
        _a = 0, _ha = 0, _clickScale = 0, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg = newRect({ Rounding = sz.roundSm + 5, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = sz.roundSm + 5, ZIndex = 28 })
    e._d.fill = newRect({ Rounding = sz.roundSm + 5, ZIndex = 29 })
    e._d.dot = newDot({ Radius = 5, ZIndex = 31, NumSides = 20 })

    function e:set(v) self.val = v; self.cb(v); if self.flag and flags then flags[self.flag] = v end end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bw, bh = sz.toggleW, sz.toggleH
        local bx = px + w - bw - 6
        local by = py + (sz.elemH - bh) / 2
        local rowHit = hit(mx, my, px, py, w, sz.elemH)
        if self.tip and rowHit then setTooltip(self.tip) end
        if rowHit and mClick and not mClickConsumed then
            self.val = not self.val
            self.cb(self.val)
            if self.flag and flags then flags[self.flag] = self.val end
            self._clickScale = 0.3
            mClickConsumed = true
        end
        self._ha = lerp(self._ha, rowHit and 1 or 0, 0.12)
        local tgt = self.val and 1 or 0
        self._a = bounce(self._a, tgt, 0.14, 0.06)
        self._clickScale = lerp(self._clickScale, 0, 0.15)
        self._d.label.Text = self.name
        local labelBounds = measureText(self.name, sz.font)
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - labelBounds.Y) / 2)
        self._d.label.Color = lc(pal.textSub, pal.text, self._ha)
        local scale = 1 - self._clickScale * 0.08
        local sw = math.floor(bw * scale)
        local sh = math.floor(bh * scale)
        local sx = bx + (bw - sw) / 2
        local sy = by + (bh - sh) / 2
        self._d.bg.Position = Vector2.new(sx, sy)
        self._d.bg.Size = Vector2.new(sw, sh)
        self._d.bg.Color = lc(pal.panelDeep, pal.accentDim, self._a * 0.4)
        self._d.bgOut.Position = Vector2.new(sx, sy)
        self._d.bgOut.Size = Vector2.new(sw, sh)
        self._d.bgOut.Color = lc(pal.borderDim, pal.accent, self._a * 0.7)
        local fw = math.floor(sw * self._a)
        self._d.fill.Position = Vector2.new(sx, sy)
        self._d.fill.Size = Vector2.new(fw, sh)
        self._d.fill.Color = lc(pal.accentDim, pal.accent, self._a)
        self._d.fill.Transparency = 0.3
        local dotX = lerp(sx + 9, sx + sw - 9, self._a)
        self._d.dot.Position = Vector2.new(dotX, sy + sh / 2)
        self._d.dot.Color = lc(pal.textDim, pal.white, self._a)
        self._d.dot.Radius = 5 + self._clickScale * 2
    end

    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local function mkSlider(o, flags)
    local e = {
        type = "slider", name = o.Name or "slider",
        val = o.Default or o.Min or 0, min = o.Min or 0, max = o.Max or 100,
        inc = o.Increment or 1, suf = o.Suffix or "",
        cb = o.Callback or function() end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH + 16, _drag = false, _a = 0, _ha = 0, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.valTxt = newLabel({ Size = sz.fontSm, Color = pal.accent, ZIndex = 30 })
    e._d.trackBg = newRect({ Rounding = 3, ZIndex = 27, Color = pal.panelDeep })
    e._d.track = newRect({ Rounding = 3, ZIndex = 28, Color = pal.borderDim })
    e._d.fill = newRect({ Rounding = 3, ZIndex = 29 })
    e._d.knob = newDot({ Radius = 6, ZIndex = 31, Color = pal.white })
    e._d.knobGlow = newDot({ Radius = 10, ZIndex = 30, Transparency = 0.8 })

    function e:set(v) self.val = clamp(snap(v, self.inc), self.min, self.max); self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local tx, ty = px + 8, py + sz.elemH + 6
        local tw = w - 20
        local pct = (self.val - self.min) / math.max(self.max - self.min, 0.001)
        self._a = bounce(self._a, pct, 0.16, 0.04)
        local trackHit = hit(mx, my, tx, ty - 8, tw, 20)
        self._ha = lerp(self._ha, (trackHit or self._drag) and 1 or 0, 0.12)
        if self.tip and trackHit then setTooltip(self.tip) end
        if trackHit and mClick and not mClickConsumed then self._drag = true; mClickConsumed = true end
        if not mDown then self._drag = false end
        if self._drag then
            local raw = clamp((mx - tx) / tw, 0, 1)
            local nv = clamp(snap(self.min + raw * (self.max - self.min), self.inc), self.min, self.max)
            if nv ~= self.val then self.val = nv; self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end end
        end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + 4)
        self._d.label.Color = lc(pal.textSub, pal.text, self._ha)
        local vs = tostring(self.val) .. self.suf
        local vBounds = measureText(vs, sz.fontSm)
        self._d.valTxt.Text = vs
        self._d.valTxt.Position = Vector2.new(px + w - vBounds.X - 6, py + 5)
        self._d.trackBg.Position = Vector2.new(tx - 2, ty - 3)
        self._d.trackBg.Size = Vector2.new(tw + 4, sz.sliderH + 6)
        self._d.track.Position = Vector2.new(tx, ty)
        self._d.track.Size = Vector2.new(tw, sz.sliderH)
        local fw = math.max(3, math.floor(tw * self._a))
        self._d.fill.Position = Vector2.new(tx, ty)
        self._d.fill.Size = Vector2.new(fw, sz.sliderH)
        self._d.fill.Color = lc(pal.accentDim, pal.accent, self._ha)
        local kx = tx + tw * self._a
        self._d.knob.Position = Vector2.new(kx, ty + sz.sliderH / 2)
        self._d.knob.Color = lc(pal.textSub, pal.white, self._ha)
        self._d.knob.Radius = lerp(5, 7, self._ha)
        self._d.knobGlow.Position = Vector2.new(kx, ty + sz.sliderH / 2)
        self._d.knobGlow.Color = pal.accent
        self._d.knobGlow.Transparency = lerp(1, 0.7, self._ha)
        self._d.knobGlow.Radius = lerp(0, 12, self._ha)
    end

    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local function mkButton(o)
    local e = {
        type = "button", name = o.Name or "button",
        cb = o.Callback or function() end, h = sz.elemH, tip = o.Tooltip,
        _ha = 0, _clickA = 0, _d = {},
    }
    e._d.bg = newRect({ Rounding = sz.roundSm, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = sz.roundSm, ZIndex = 28 })
    e._d.label = newLabel({ Size = sz.font, Center = true, ZIndex = 30 })

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bx, by = px + 4, py + 2
        local bw, bh = w - 8, sz.elemH - 4
        local hov = hit(mx, my, bx, by, bw, bh)
        if self.tip and hov then setTooltip(self.tip) end
        self._ha = lerp(self._ha, hov and 1 or 0, 0.12)
        self._clickA = lerp(self._clickA, 0, 0.12)
        if hov and mClick and not mClickConsumed then
            self.cb()
            self._clickA = 1
            mClickConsumed = true
        end
        local scale = 1 - self._clickA * 0.03
        local sw = math.floor(bw * scale)
        local sh = math.floor(bh * scale)
        local sx = bx + (bw - sw) / 2
        local sy = by + (bh - sh) / 2
        self._d.bg.Position = Vector2.new(sx, sy)
        self._d.bg.Size = Vector2.new(sw, sh)
        self._d.bg.Color = lc(pal.panel, pal.hover, self._ha)
        self._d.bgOut.Position = Vector2.new(sx, sy)
        self._d.bgOut.Size = Vector2.new(sw, sh)
        self._d.bgOut.Color = lc(pal.borderDim, pal.accent, self._ha * 0.5)
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(sx + sw / 2, sy + (sh - sz.font) / 2 - 1)
        self._d.label.Color = lc(pal.textSub, pal.text, self._ha)
    end

    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local function mkLabel(o)
    local e = { type = "label", text = o.Text or "", h = sz.elemH - 8, _d = {} }
    e._d.label = newLabel({ Size = sz.fontSm, Color = pal.textDim, ZIndex = 30 })
    function e:set(t) self.text = t end
    function e:draw(px, py, w, vis)
        self._d.label.Visible = vis
        if not vis then return end
        self._d.label.Text = self.text
        self._d.label.Position = Vector2.new(px + 8, py + 3)
    end
    function e:destroy() kill(self._d.label) end
    return e
end

local function mkSeparator()
    local e = { type = "sep", h = 12, _d = {} }
    e._d.line = newLine({ Color = pal.borderDim, ZIndex = 28 })
    function e:draw(px, py, w, vis)
        self._d.line.Visible = vis
        if not vis then return end
        self._d.line.From = Vector2.new(px + 10, py + 6)
        self._d.line.To = Vector2.new(px + w - 10, py + 6)
    end
    function e:destroy() kill(self._d.line) end
    return e
end

local function mkSectionHeader(o)
    local e = { type = "header", text = o.Text or "section", h = 26, _d = {} }
    e._d.label = newLabel({ Size = sz.font, Color = pal.accent, ZIndex = 30 })
    e._d.lineL = newLine({ Color = pal.borderDim, ZIndex = 28 })
    e._d.lineR = newLine({ Color = pal.borderDim, ZIndex = 28 })
    function e:set(t) self.text = t end
    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bounds = measureText(self.text, sz.font)
        local textX = px + 12
        self._d.label.Text = self.text
        self._d.label.Position = Vector2.new(textX, py + 6)
        local lineY = py + 13
        self._d.lineL.Visible = false
        self._d.lineR.From = Vector2.new(textX + bounds.X + 8, lineY)
        self._d.lineR.To = Vector2.new(px + w - 10, lineY)
    end
    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local function mkDropdown(o, flags)
    local multi = o.Multi or false
    local e = {
        type = "dropdown", name = o.Name or "dropdown", multi = multi,
        opts = o.Options or {},
        val = multi and (o.Default or {}) or (o.Default or (o.Options and o.Options[1] or "")),
        cb = o.Callback or function() end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH, _open = false, _ha = 0, _d = {}, _od = {}, _ob = {}, _oc = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.valTxt = newLabel({ Size = sz.fontSm, ZIndex = 30 })
    e._d.box = newRect({ Rounding = sz.roundSm, ZIndex = 28 })
    e._d.boxOut = newRect({ Filled = false, Rounding = sz.roundSm, ZIndex = 28 })
    e._d.arrow = newTri({ ZIndex = 30 })
    e._d.panBg = newRect({ Rounding = sz.roundSm, ZIndex = 60 })
    e._d.panOut = newRect({ Filled = false, Rounding = sz.roundSm, ZIndex = 60 })

    local function buildOpts(self)
        for i = 1, #self._od do kill(self._od[i]); kill(self._ob[i]); if self._oc[i] then kill(self._oc[i]) end end
        self._od, self._ob, self._oc = {}, {}, {}
        for i = 1, #self.opts do
            self._od[i] = newLabel({ Size = sz.fontSm, ZIndex = 62 })
            self._ob[i] = newRect({ Rounding = sz.roundXs, ZIndex = 61 })
            if multi then
                self._oc[i] = newRect({ Rounding = 2, ZIndex = 63 })
            end
        end
    end
    buildOpts(e)

    local function displayVal(self)
        if self.multi then
            if #self.val == 0 then return "none" end
            if #self.val == 1 then return self.val[1] end
            return self.val[1] .. " +" .. (#self.val - 1)
        end
        return tostring(self.val)
    end

    local function hasVal(self, opt)
        if not self.multi then return self.val == opt end
        for _, v in ipairs(self.val) do if v == opt then return true end end
        return false
    end

    local function toggleVal(self, opt)
        if not self.multi then
            self.val = opt
        else
            local idx
            for i, v in ipairs(self.val) do if v == opt then idx = i; break end end
            if idx then table.remove(self.val, idx) else self.val[#self.val + 1] = opt end
        end
        self.cb(self.val)
        if self.flag and flags then flags[self.flag] = self.val end
    end

    function e:set(v) self.val = v; self.cb(v); if self.flag and flags then flags[self.flag] = v end end
    function e:refresh(newOpts) self.opts = newOpts; buildOpts(self) end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then
            for i = 1, #self._od do self._od[i].Visible = false; self._ob[i].Visible = false; if self._oc[i] then self._oc[i].Visible = false end end
            return
        end
        local bw = math.min(150, w * 0.46)
        local bh = sz.elemH - 6
        local bx = px + w - bw - 6
        local by = py + 3
        local hov = hit(mx, my, bx, by, bw, bh)
        if self.tip and hit(mx, my, px, py, w, sz.elemH) then setTooltip(self.tip) end
        self._ha = lerp(self._ha, hov and 1 or 0, 0.12)
        if hov and mClick and not mClickConsumed then self._open = not self._open; mClickConsumed = true end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font) / 2 - 1)
        self._d.label.Color = lc(pal.textSub, pal.text, self._ha)
        self._d.box.Position = Vector2.new(bx, by); self._d.box.Size = Vector2.new(bw, bh)
        self._d.box.Color = lc(pal.panel, pal.hover, self._ha)
        self._d.boxOut.Position = Vector2.new(bx, by); self._d.boxOut.Size = Vector2.new(bw, bh)
        self._d.boxOut.Color = lc(pal.borderDim, pal.borderLit, self._ha * 0.5)
        self._d.valTxt.Text = displayVal(self)
        self._d.valTxt.Position = Vector2.new(bx + 8, by + (bh - sz.fontSm) / 2 - 1)
        self._d.valTxt.Color = pal.text
        local ax = bx + bw - 14
        local ay = by + bh / 2
        local s = 4
        if self._open then
            self._d.arrow.PointA = Vector2.new(ax-s, ay+2); self._d.arrow.PointB = Vector2.new(ax+s, ay+2); self._d.arrow.PointC = Vector2.new(ax, ay-3)
        else
            self._d.arrow.PointA = Vector2.new(ax-s, ay-2); self._d.arrow.PointB = Vector2.new(ax+s, ay-2); self._d.arrow.PointC = Vector2.new(ax, ay+3)
        end
        self._d.arrow.Color = pal.textDim
        if self._open and #self.opts > 0 then
            local oh = 24
            local ph = #self.opts * oh + 6
            local ppx, ppy = bx, by + bh + 3
            self._d.panBg.Visible = true; self._d.panOut.Visible = true
            self._d.panBg.Position = Vector2.new(ppx, ppy); self._d.panBg.Size = Vector2.new(bw, ph); self._d.panBg.Color = pal.bgDeep
            self._d.panOut.Position = Vector2.new(ppx, ppy); self._d.panOut.Size = Vector2.new(bw, ph); self._d.panOut.Color = pal.border
            local outside = mClick and not mClickConsumed and not hit(mx, my, ppx, ppy, bw, ph) and not hov
            for i, opt in ipairs(self.opts) do
                local ox = ppx + 3
                local oy = ppy + 3 + (i - 1) * oh
                local ow, ooh = bw - 6, oh
                local oHov = hit(mx, my, ox, oy, ow, ooh)
                local sel = hasVal(self, opt)
                self._ob[i].Visible = true; self._ob[i].Position = Vector2.new(ox, oy); self._ob[i].Size = Vector2.new(ow, ooh)
                self._ob[i].Color = oHov and pal.hover or (sel and pal.panelLit or pal.bgDeep)
                self._ob[i].Rounding = sz.roundXs
                self._od[i].Visible = true; self._od[i].Text = opt
                local textOff = multi and 22 or 8
                self._od[i].Position = Vector2.new(ox + textOff, oy + (ooh - sz.fontSm) / 2 - 1)
                self._od[i].Color = sel and pal.accent or (oHov and pal.text or pal.textSub)
                if multi and self._oc[i] then
                    self._oc[i].Visible = true
                    self._oc[i].Position = Vector2.new(ox + 6, oy + (ooh - 10) / 2)
                    self._oc[i].Size = Vector2.new(10, 10)
                    self._oc[i].Color = sel and pal.accent or pal.borderDim
                    self._oc[i].Rounding = 2
                end
                if oHov and mClick and not mClickConsumed then
                    toggleVal(self, opt)
                    if not multi then self._open = false end
                    mClickConsumed = true
                end
            end
            if outside then self._open = false end
        else
            self._d.panBg.Visible = false; self._d.panOut.Visible = false
            for i = 1, #self._od do
                self._od[i].Visible = false; self._ob[i].Visible = false
                if self._oc[i] then self._oc[i].Visible = false end
            end
        end
    end

    function e:destroy()
        for _, d in pairs(self._d) do kill(d) end
        for i = 1, #self._od do kill(self._od[i]); kill(self._ob[i]); if self._oc[i] then kill(self._oc[i]) end end
    end
    return e
end

local function mkKeybind(o, flags)
    local e = {
        type = "keybind", name = o.Name or "keybind",
        val = o.Default or Enum.KeyCode.Unknown,
        mode = o.Mode or "toggle",
        cb = o.Callback or function() end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH, _listen = false, _ctxOpen = false, _active = false, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg = newRect({ Rounding = sz.roundSm, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = sz.roundSm, ZIndex = 28 })
    e._d.keyTxt = newLabel({ Size = sz.fontXs, Center = true, ZIndex = 30 })
    e._d.modeTxt = newLabel({ Size = sz.fontXs, ZIndex = 30, Color = pal.textDim })
    e._d.ctxBg = newRect({ Rounding = sz.roundSm, ZIndex = 100 })
    e._d.ctxOut = newRect({ Filled = false, Rounding = sz.roundSm, ZIndex = 100 })
    local modes = { "toggle", "hold", "always on", "always off" }
    e._ctxItems = {}
    for i = 1, #modes do
        e._ctxItems[i] = {
            bg = newRect({ Rounding = sz.roundXs, ZIndex = 101 }),
            label = newLabel({ Size = sz.fontSm, ZIndex = 102 }),
        }
    end

    local kconn
    function e:set(k)
        if type(k) == "table" then
            self.val = k.Key or self.val
            self.mode = k.Mode or self.mode
        else
            self.val = k
        end
        if self.flag and flags then flags[self.flag] = { Key = self.val, Mode = self.mode, Active = self._active } end
    end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        for _, ci in pairs(self._ctxItems) do ci.bg.Visible = false; ci.label.Visible = false end
        if not vis then self._d.ctxBg.Visible = false; self._d.ctxOut.Visible = false; return end
        local kn = self._listen and "..." or (self.val and self.val.Name or "None")
        local knBounds = measureText(kn, sz.fontXs)
        local kw = math.max(42, knBounds.X + 16)
        local kh = sz.elemH - 10
        local kx = px + w - kw - 6
        local ky = py + 5
        local hov = hit(mx, my, kx, ky, kw, kh)
        if self.tip and hit(mx, my, px, py, w, sz.elemH) then setTooltip(self.tip) end
        if hov and mClick and not mClickConsumed and not self._listen then
            self._listen = true
            mClickConsumed = true
            if kconn then kconn:Disconnect() end
            kconn = UIS.InputBegan:Connect(function(io, gp)
                if gp then return end
                if io.UserInputType == Enum.UserInputType.Keyboard then
                    self.val = io.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or io.KeyCode
                    self._listen = false
                    if self.flag and flags then flags[self.flag] = { Key = self.val, Mode = self.mode, Active = self._active } end
                    if kconn then kconn:Disconnect(); kconn = nil end
                end
            end)
        end
        if hov and mRClick and not mRClickConsumed then
            self._ctxOpen = not self._ctxOpen
            mRClickConsumed = true
        end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font) / 2 - 1)
        self._d.label.Color = pal.textSub
        self._d.bg.Position = Vector2.new(kx, ky); self._d.bg.Size = Vector2.new(kw, kh)
        self._d.bg.Color = self._listen and pal.press or (hov and pal.hover or pal.panel)
        self._d.bgOut.Position = Vector2.new(kx, ky); self._d.bgOut.Size = Vector2.new(kw, kh)
        self._d.bgOut.Color = self._listen and pal.accent or (self._active and pal.accentDim or pal.borderDim)
        self._d.keyTxt.Text = kn
        self._d.keyTxt.Position = Vector2.new(kx + kw / 2, ky + (kh - sz.fontXs) / 2 - 1)
        self._d.keyTxt.Color = self._listen and pal.accent or (self._active and pal.accentLit or pal.textDim)
        local modeBounds = measureText("[" .. self.mode .. "]", sz.fontXs)
        self._d.modeTxt.Text = "[" .. self.mode .. "]"
        self._d.modeTxt.Position = Vector2.new(kx - modeBounds.X - 6, py + (sz.elemH - sz.fontXs) / 2)
        self._d.modeTxt.Color = pal.textDim
        if self._ctxOpen then
            local ctxW = 100
            local ctxH = #modes * 22 + 4
            local ctxX = kx
            local ctxY = ky + kh + 3
            self._d.ctxBg.Visible = true; self._d.ctxOut.Visible = true
            self._d.ctxBg.Position = Vector2.new(ctxX, ctxY); self._d.ctxBg.Size = Vector2.new(ctxW, ctxH); self._d.ctxBg.Color = pal.bgDeep
            self._d.ctxOut.Position = Vector2.new(ctxX, ctxY); self._d.ctxOut.Size = Vector2.new(ctxW, ctxH); self._d.ctxOut.Color = pal.border
            local ctxOutside = mClick and not mClickConsumed and not hit(mx, my, ctxX, ctxY, ctxW, ctxH) and not hov
            for i, m in ipairs(modes) do
                local iy = ctxY + 2 + (i - 1) * 22
                local iHov = hit(mx, my, ctxX + 2, iy, ctxW - 4, 22)
                local sel = self.mode == m
                self._ctxItems[i].bg.Visible = true
                self._ctxItems[i].bg.Position = Vector2.new(ctxX + 2, iy)
                self._ctxItems[i].bg.Size = Vector2.new(ctxW - 4, 22)
                self._ctxItems[i].bg.Color = iHov and pal.hover or (sel and pal.panelLit or pal.bgDeep)
                self._ctxItems[i].bg.Rounding = sz.roundXs
                self._ctxItems[i].label.Visible = true
                self._ctxItems[i].label.Text = m
                self._ctxItems[i].label.Position = Vector2.new(ctxX + 10, iy + 4)
                self._ctxItems[i].label.Color = sel and pal.accent or (iHov and pal.text or pal.textSub)
                if iHov and mClick and not mClickConsumed then
                    self.mode = m
                    self._ctxOpen = false
                    mClickConsumed = true
                    if self.flag and flags then flags[self.flag] = { Key = self.val, Mode = self.mode, Active = self._active } end
                end
            end
            if ctxOutside then self._ctxOpen = false end
        else
            self._d.ctxBg.Visible = false; self._d.ctxOut.Visible = false
        end
    end

    table.insert(bliss._connections, UIS.InputBegan:Connect(function(io, gp)
        if gp or e._listen then return end
        if io.KeyCode == e.val then
            if e.mode == "toggle" then
                e._active = not e._active
                e.cb(e._active)
            elseif e.mode == "hold" then
                e._active = true
                e.cb(true)
            elseif e.mode == "always on" then
                e._active = true
            end
            if e.flag and flags then flags[e.flag] = { Key = e.val, Mode = e.mode, Active = e._active } end
        end
    end))

    table.insert(bliss._connections, UIS.InputEnded:Connect(function(io)
        if io.KeyCode == e.val and e.mode == "hold" then
            e._active = false
            e.cb(false)
            if e.flag and flags then flags[e.flag] = { Key = e.val, Mode = e.mode, Active = e._active } end
        end
    end))

    function e:destroy()
        for _, d in pairs(self._d) do kill(d) end
        for _, ci in pairs(self._ctxItems) do kill(ci.bg); kill(ci.label) end
        if kconn then kconn:Disconnect() end
    end
    return e
end

local function mkTextbox(o, flags)
    local e = {
        type = "textbox", name = o.Name or "textbox",
        val = o.Default or "", ph = o.Placeholder or "type here...",
        cb = o.Callback or function() end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH + 6, _focus = false, _blink = 0, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg = newRect({ Rounding = sz.roundSm, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = sz.roundSm, ZIndex = 28 })
    e._d.txt = newLabel({ Size = sz.fontSm, ZIndex = 30 })
    e._d.cur = newLine({ Color = pal.accent, ZIndex = 31, Thickness = 1 })

    local cconn
    function e:set(v) self.val = v; self.cb(v); if self.flag and flags then flags[self.flag] = v end end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bw = w - 14
        local bh = 22
        local bx = px + 7
        local by = py + sz.elemH - bh + 3
        local hov = hit(mx, my, bx, by, bw, bh)
        if self.tip and hov then setTooltip(self.tip) end
        if mClick and not mClickConsumed then
            local was = self._focus
            self._focus = hov
            if self._focus and not was then
                mClickConsumed = true
                if cconn then cconn:Disconnect() end
                cconn = UIS.InputBegan:Connect(function(io)
                    if not self._focus then return end
                    if io.KeyCode == Enum.KeyCode.Backspace then
                        if #self.val > 0 then self.val = self.val:sub(1, -2) end
                    elseif io.KeyCode == Enum.KeyCode.Return then
                        self._focus = false; self.cb(self.val)
                        if self.flag and flags then flags[self.flag] = self.val end
                        if cconn then cconn:Disconnect(); cconn = nil end
                    elseif io.KeyCode == Enum.KeyCode.Escape then
                        self._focus = false
                        if cconn then cconn:Disconnect(); cconn = nil end
                    end
                end)
            elseif was and not self._focus then
                self.cb(self.val)
                if self.flag and flags then flags[self.flag] = self.val end
                if cconn then cconn:Disconnect(); cconn = nil end
            end
        end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + 2)
        self._d.label.Color = pal.textSub
        self._d.bg.Position = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh); self._d.bg.Color = pal.panelDeep
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color = self._focus and pal.accent or (hov and pal.borderLit or pal.borderDim)
        local dt = #self.val > 0 and self.val or self.ph
        self._d.txt.Text = dt
        self._d.txt.Position = Vector2.new(bx + 7, by + (bh - sz.fontSm) / 2 - 1)
        self._d.txt.Color = #self.val > 0 and pal.text or pal.textDim
        if self._focus then
            self._blink = (self._blink + 1) % 60
            self._d.cur.Visible = self._blink < 35
            local textBounds = measureText(self.val, sz.fontSm)
            local cx = bx + 7 + textBounds.X + 1
            self._d.cur.From = Vector2.new(cx, by + 4)
            self._d.cur.To = Vector2.new(cx, by + bh - 4)
        else
            self._d.cur.Visible = false
        end
    end

    table.insert(bliss._connections, UIS.InputBegan:Connect(function(io, gp)
        if not e._focus or gp then return end
        local shift = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
        local n = io.KeyCode.Name
        if io.KeyCode == Enum.KeyCode.Space then e.val = e.val .. " "
        elseif n and #n == 1 and n:match("%a") then e.val = e.val .. (shift and n:upper() or n:lower())
        elseif n and #n == 1 and n:match("%d") then
            local sm = {["1"]="!",["2"]="@",["3"]="#",["4"]="$",["5"]="%",["6"]="^",["7"]="&",["8"]="*",["9"]="(",["0"]=")"}
            e.val = e.val .. (shift and (sm[n] or n) or n)
        elseif io.KeyCode == Enum.KeyCode.Period then e.val = e.val .. (shift and ">" or ".")
        elseif io.KeyCode == Enum.KeyCode.Comma then e.val = e.val .. (shift and "<" or ",")
        elseif io.KeyCode == Enum.KeyCode.Minus then e.val = e.val .. (shift and "_" or "-")
        elseif io.KeyCode == Enum.KeyCode.Equals then e.val = e.val .. (shift and "+" or "=")
        elseif io.KeyCode == Enum.KeyCode.Slash then e.val = e.val .. (shift and "?" or "/")
        elseif io.KeyCode == Enum.KeyCode.Semicolon then e.val = e.val .. (shift and ":" or ";")
        elseif io.KeyCode == Enum.KeyCode.Quote then e.val = e.val .. (shift and '"' or "'")
        elseif io.KeyCode == Enum.KeyCode.LeftBracket then e.val = e.val .. (shift and "{" or "[")
        elseif io.KeyCode == Enum.KeyCode.RightBracket then e.val = e.val .. (shift and "}" or "]")
        elseif io.KeyCode == Enum.KeyCode.BackSlash then e.val = e.val .. (shift and "|" or "\\")
        elseif io.KeyCode == Enum.KeyCode.Backquote then e.val = e.val .. (shift and "~" or "`")
        end
    end))

    function e:destroy()
        for _, d in pairs(self._d) do kill(d) end
        if cconn then cconn:Disconnect() end
    end
    return e
end

local function mkColorPicker(o, flags)
    local e = {
        type = "color", name = o.Name or "color",
        val = o.Default or Color3.new(1, 1, 1),
        cb = o.Callback or function() end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH, _open = false, _dSV = false, _dH = false,
        _hue = 0, _sat = 1, _bri = 1, _d = {},
    }
    do
        local r, g, b = e.val.R, e.val.G, e.val.B
        local hi, lo = math.max(r, g, b), math.min(r, g, b)
        local d = hi - lo
        e._bri = hi; e._sat = hi == 0 and 0 or d / hi
        if d == 0 then e._hue = 0
        elseif hi == r then e._hue = ((g - b) / d) % 6
        elseif hi == g then e._hue = (b - r) / d + 2
        else e._hue = (r - g) / d + 4 end
        e._hue = e._hue / 6
    end

    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.prev = newRect({ Rounding = sz.roundSm, ZIndex = 28 })
    e._d.prevOut = newRect({ Filled = false, Rounding = sz.roundSm, ZIndex = 28 })
    e._d.panBg = newRect({ Rounding = sz.roundSm, ZIndex = 60 })
    e._d.panOut = newRect({ Filled = false, Rounding = sz.roundSm, ZIndex = 60 })
    e._d.svBox = newRect({ Rounding = sz.roundXs, ZIndex = 61 })
    e._d.svWhiteGrad = newRect({ Rounding = sz.roundXs, ZIndex = 62 })
    e._d.svBlackGrad = newRect({ Rounding = sz.roundXs, ZIndex = 63 })
    e._d.svDot = newDot({ Filled = false, Radius = 5, Thickness = 2, ZIndex = 65 })
    e._d.svDotInner = newDot({ Radius = 3, ZIndex = 66 })
    e._d.hBar = newRect({ Rounding = sz.roundXs, ZIndex = 61 })
    e._d.hCur = newRect({ Rounding = 2, ZIndex = 64 })
    e._d.hexTxt = newLabel({ Size = sz.fontXs, ZIndex = 62, Color = pal.textDim })

    function e:set(c)
        self.val = c; self.cb(c)
        local r, g, b = c.R, c.G, c.B
        local hi, lo = math.max(r, g, b), math.min(r, g, b)
        local d = hi - lo
        self._bri = hi; self._sat = hi == 0 and 0 or d / hi
        if d == 0 then self._hue = 0
        elseif hi == r then self._hue = ((g - b) / d) % 6
        elseif hi == g then self._hue = (b - r) / d + 2
        else self._hue = (r - g) / d + 4 end
        self._hue = self._hue / 6
        if self.flag and flags then flags[self.flag] = c end
    end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local cs = sz.colorBox
        local cx = px + w - cs - 10
        local cy = py + (sz.elemH - cs) / 2
        local hov = hit(mx, my, cx, cy, cs, cs)
        if self.tip and hov then setTooltip(self.tip) end
        if hov and mClick and not mClickConsumed then self._open = not self._open; mClickConsumed = true end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font) / 2 - 1)
        self._d.label.Color = pal.textSub
        self._d.prev.Position = Vector2.new(cx, cy); self._d.prev.Size = Vector2.new(cs, cs); self._d.prev.Color = self.val
        self._d.prevOut.Position = Vector2.new(cx, cy); self._d.prevOut.Size = Vector2.new(cs, cs)
        self._d.prevOut.Color = lc(pal.borderDim, pal.borderLit, hov and 1 or 0)
        local show = self._open
        for _, key in pairs({"panBg","panOut","svBox","svWhiteGrad","svBlackGrad","svDot","svDotInner","hBar","hCur","hexTxt"}) do
            self._d[key].Visible = show
        end
        if show then
            local pw, ph = 180, 140
            local ppx = cx + cs - pw
            local ppy = cy + cs + 5
            self._d.panBg.Position = Vector2.new(ppx, ppy); self._d.panBg.Size = Vector2.new(pw, ph); self._d.panBg.Color = pal.bgDeep
            self._d.panOut.Position = Vector2.new(ppx, ppy); self._d.panOut.Size = Vector2.new(pw, ph); self._d.panOut.Color = pal.border
            local sx, sy = ppx + 8, ppy + 8
            local sw, sh = pw - 30, ph - 30
            self._d.svBox.Position = Vector2.new(sx, sy); self._d.svBox.Size = Vector2.new(sw, sh)
            self._d.svBox.Color = Color3.fromHSV(self._hue, 1, 1)
            self._d.svWhiteGrad.Position = Vector2.new(sx, sy); self._d.svWhiteGrad.Size = Vector2.new(sw, sh)
            self._d.svWhiteGrad.Color = pal.white; self._d.svWhiteGrad.Transparency = 0.5
            self._d.svBlackGrad.Position = Vector2.new(sx, sy + sh * 0.5); self._d.svBlackGrad.Size = Vector2.new(sw, sh * 0.5)
            self._d.svBlackGrad.Color = pal.black; self._d.svBlackGrad.Transparency = 0.3
            if hit(mx, my, sx, sy, sw, sh) and mClick and not mClickConsumed then self._dSV = true; mClickConsumed = true end
            if not mDown then self._dSV = false end
            if self._dSV then
                self._sat = clamp((mx - sx) / sw, 0, 1)
                self._bri = 1 - clamp((my - sy) / sh, 0, 1)
                self.val = Color3.fromHSV(self._hue, self._sat, self._bri)
                self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end
            end
            self._d.svDot.Position = Vector2.new(sx + self._sat * sw, sy + (1 - self._bri) * sh)
            self._d.svDot.Color = pal.white
            self._d.svDotInner.Position = Vector2.new(sx + self._sat * sw, sy + (1 - self._bri) * sh)
            self._d.svDotInner.Color = self.val
            local hx, hy = ppx + pw - 18, ppy + 8
            local hh = ph - 30
            self._d.hBar.Position = Vector2.new(hx, hy); self._d.hBar.Size = Vector2.new(8, hh)
            self._d.hBar.Color = Color3.fromHSV(self._hue, 1, 1)
            if hit(mx, my, hx - 2, hy, 12, hh) and mClick and not mClickConsumed then self._dH = true; mClickConsumed = true end
            if not mDown then self._dH = false end
            if self._dH then
                self._hue = clamp((my - hy) / hh, 0, 0.999)
                self.val = Color3.fromHSV(self._hue, self._sat, self._bri)
                self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end
            end
            self._d.hCur.Position = Vector2.new(hx - 2, hy + self._hue * hh - 3)
            self._d.hCur.Size = Vector2.new(12, 6); self._d.hCur.Color = pal.white
            local hex = string.format("#%02X%02X%02X", math.floor(self.val.R*255), math.floor(self.val.G*255), math.floor(self.val.B*255))
            self._d.hexTxt.Text = hex
            self._d.hexTxt.Position = Vector2.new(ppx + 8, ppy + ph - 18)
            if mClick and not mClickConsumed and not hit(mx, my, ppx, ppy, pw, ph) and not hov and not self._dSV and not self._dH then
                self._open = false
            end
        end
    end

    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

-- == Tab ==

local Tab = {}
Tab.__index = Tab

function Tab:AddToggle(o) local e = mkToggle(o, self._win._flags); self._elems[#self._elems + 1] = e; return e end
function Tab:AddSlider(o) local e = mkSlider(o, self._win._flags); self._elems[#self._elems + 1] = e; return e end
function Tab:AddButton(o) local e = mkButton(o); self._elems[#self._elems + 1] = e; return e end
function Tab:AddDropdown(o) local e = mkDropdown(o, self._win._flags); self._elems[#self._elems + 1] = e; return e end
function Tab:AddKeybind(o) local e = mkKeybind(o, self._win._flags); self._elems[#self._elems + 1] = e; return e end
function Tab:AddTextbox(o) local e = mkTextbox(o, self._win._flags); self._elems[#self._elems + 1] = e; return e end
function Tab:AddColorPicker(o) local e = mkColorPicker(o, self._win._flags); self._elems[#self._elems + 1] = e; return e end
function Tab:AddLabel(o) local e = mkLabel(o); self._elems[#self._elems + 1] = e; return e end
function Tab:AddSeparator() local e = mkSeparator(); self._elems[#self._elems + 1] = e; return e end
function Tab:AddSection(o) local e = mkSectionHeader(o); self._elems[#self._elems + 1] = e; return e end

-- == Window ==

local Window = {}
Window.__index = Window

function Window:AddTab(o)
    o = o or {}
    local tab = setmetatable({
        name = o.Name or "tab", icon = o.Icon or "·",
        _elems = {}, _scroll = 0, _scrollVel = 0, _win = self,
    }, Tab)
    local td = {
        bg = newRect({ Rounding = sz.roundSm, ZIndex = 8 }),
        icon = newLabel({ Size = sz.fontSm, Center = true, ZIndex = 9 }),
        label = newLabel({ Size = sz.fontSm, ZIndex = 9 }),
        bar = newRect({ Rounding = 2, ZIndex = 9, Color = pal.accent }),
        _ha = 0,
    }
    self._tabDraw[#self._tabDraw + 1] = td
    self._tabs[#self._tabs + 1] = tab
    if #self._tabs == 1 then self._active = 1 end
    return tab
end

function Window:SetVisible(v) self._vis = v end

function Window:SetTab(x)
    if type(x) == "number" then self._active = clamp(x, 1, #self._tabs)
    else for i, t in ipairs(self._tabs) do if t.name == x then self._active = i; break end end end
end

-- == render ==

local function renderWin(w, dt)
    local targetVis = w._vis and bliss._visible
    w._openAnim = lerp(w._openAnim or 0, targetVis and 1 or 0, 0.12)
    local show = w._openAnim > 0.01
    if not show then
        for _, obj in pairs(w._draw) do obj.Visible = false end
        for _, td in ipairs(w._tabDraw) do for _, obj in pairs(td) do if type(obj) ~= "number" then obj.Visible = false end end end
        for _, tab in ipairs(w._tabs) do for _, el in ipairs(tab._elems) do el:draw(0, 0, 0, false) end end
        return
    end

    local alpha = w._openAnim
    local p = w._pos
    local ww, wh = w._sz.X, w._sz.Y

    if hit(mx, my, p.X, p.Y, ww, sz.titleH) and mClick and not mClickConsumed and not w._drag then
        w._drag = true
        w._dOff = Vector2.new(mx - p.X, my - p.Y)
        mClickConsumed = true
    end
    if not mDown then w._drag = false end
    if w._drag then
        local targetX = mx - w._dOff.X
        local targetY = my - w._dOff.Y
        w._pos = Vector2.new(
            lerp(p.X, targetX, 0.35),
            lerp(p.Y, targetY, 0.35)
        )
        p = w._pos
    end

    local d = w._draw

    d.shadow.Visible = show
    d.shadow.Position = Vector2.new(p.X + sz.shadowOff, p.Y + sz.shadowOff)
    d.shadow.Size = Vector2.new(ww, wh)
    d.shadow.Color = pal.shadow
    d.shadow.Transparency = sz.shadowAlpha * alpha

    d.bg.Visible = show
    d.bg.Position = p; d.bg.Size = Vector2.new(ww, wh); d.bg.Color = pal.bg
    d.bg.Transparency = 1 - alpha

    d.bgOut.Visible = show
    d.bgOut.Position = p; d.bgOut.Size = Vector2.new(ww, wh); d.bgOut.Color = lc(pal.border, pal.borderLit, 0.1)
    d.bgOut.Transparency = 1 - alpha

    d.title.Visible = show
    d.title.Position = p; d.title.Size = Vector2.new(ww, sz.titleH); d.title.Color = pal.panel
    d.title.Transparency = 1 - alpha

    d.titleInner.Visible = show
    d.titleInner.Position = Vector2.new(p.X + 1, p.Y + 1)
    d.titleInner.Size = Vector2.new(ww - 2, sz.titleH - 1)
    d.titleInner.Color = pal.panelLit
    d.titleInner.Transparency = 0.85

    d.titleDiv.Visible = show
    d.titleDiv.From = Vector2.new(p.X, p.Y + sz.titleH)
    d.titleDiv.To = Vector2.new(p.X + ww, p.Y + sz.titleH)
    d.titleDiv.Color = pal.borderDim
    d.titleDiv.Transparency = 1 - alpha

    d.dot.Visible = show
    d.dot.Position = Vector2.new(p.X + 14, p.Y + sz.titleH / 2)
    d.dot.Transparency = 1 - alpha

    d.dotGlow.Visible = show
    d.dotGlow.Position = Vector2.new(p.X + 14, p.Y + sz.titleH / 2)
    d.dotGlow.Color = pal.accent
    d.dotGlow.Transparency = 0.8
    d.dotGlow.Radius = 6 + math.sin(os.clock() * 2) * 1.5

    d.name.Visible = show
    d.name.Position = Vector2.new(p.X + 26, p.Y + (sz.titleH - sz.font) / 2 - 1)
    d.name.Text = w._name
    d.name.Transparency = 1 - alpha

    d.slogan.Visible = show
    d.slogan.Position = Vector2.new(p.X + ww - 80, p.Y + (sz.titleH - sz.fontXs) / 2)
    d.slogan.Transparency = 1 - alpha

    d.side.Visible = show
    d.side.Position = Vector2.new(p.X, p.Y + sz.titleH)
    d.side.Size = Vector2.new(sz.tabW, wh - sz.titleH)
    d.side.Color = pal.bgDeep
    d.side.Transparency = 1 - alpha

    d.sideDiv.Visible = show
    d.sideDiv.From = Vector2.new(p.X + sz.tabW, p.Y + sz.titleH)
    d.sideDiv.To = Vector2.new(p.X + sz.tabW, p.Y + wh)
    d.sideDiv.Color = pal.borderDim
    d.sideDiv.Transparency = 1 - alpha

    local sideY = p.Y + sz.titleH
    for i, td in ipairs(w._tabDraw) do
        local act = (i == w._active)
        local ty = sideY + 8 + (i - 1) * 32
        local tx = p.X + 7
        local tw = sz.tabW - 14
        local th = 28
        local hov = hit(mx, my, tx, ty, tw, th)
        td._ha = lerp(td._ha or 0, (hov or act) and 1 or 0, 0.12)
        if hov and mClick and not mClickConsumed then w._active = i; mClickConsumed = true end
        for k, obj in pairs(td) do if type(obj) ~= "number" then obj.Visible = show end end
        td.bg.Position = Vector2.new(tx, ty); td.bg.Size = Vector2.new(tw, th)
        td.bg.Color = act and pal.panelLit or lc(pal.bgDeep, pal.hover, td._ha)
        td.bg.Transparency = 1 - alpha
        td.icon.Position = Vector2.new(tx + 12, ty + (th - sz.fontSm) / 2 - 1)
        td.icon.Color = act and pal.accent or lc(pal.textDim, pal.textSub, td._ha)
        td.icon.Text = w._tabs[i].icon
        td.icon.Transparency = 1 - alpha
        td.label.Position = Vector2.new(tx + 26, ty + (th - sz.fontSm) / 2 - 1)
        td.label.Color = act and pal.text or lc(pal.textDim, pal.textSub, td._ha)
        td.label.Text = w._tabs[i].name
        td.label.Transparency = 1 - alpha
        td.bar.Position = Vector2.new(tx + 1, ty + 6)
        td.bar.Size = Vector2.new(2, 16)
        td.bar.Visible = show and act
        td.bar.Transparency = 1 - alpha
    end

    local cx = p.X + sz.tabW + 1
    local cy = p.Y + sz.titleH + 1
    local cw = ww - sz.tabW - 2
    local ch = wh - sz.titleH - 2

    d.contentDiv.Visible = show
    d.contentDiv.From = Vector2.new(cx, cy)
    d.contentDiv.To = Vector2.new(cx + cw, cy)
    d.contentDiv.Transparency = 0.6

    local at = w._tabs[w._active]
    if at then
        if hit(mx, my, cx, cy, cw, ch) and mScroll ~= 0 then
            at._scrollVel = at._scrollVel - mScroll * 40
        end
        at._scroll = at._scroll + at._scrollVel * dt * 4
        at._scrollVel = at._scrollVel * 0.88

        local totalH = 0
        for _, el in ipairs(at._elems) do totalH = totalH + el.h + sz.elemGap end
        at._scroll = clamp(at._scroll, 0, math.max(0, totalH - ch + 16))

        local ey = cy + sz.pad - at._scroll
        for _, el in ipairs(at._elems) do
            local eVis = show and (ey + el.h > cy) and (ey < cy + ch)
            el:draw(cx + 5, ey, cw - 14, eVis)
            ey = ey + el.h + sz.elemGap
        end

        if totalH > ch then
            local ratio = at._scroll / math.max(totalH - ch + 16, 1)
            local bh = math.max(24, (ch / totalH) * ch)
            local barTargetY = cy + ratio * (ch - bh)
            w._scrollBarY = lerp(w._scrollBarY or barTargetY, barTargetY, 0.18)
            d.scroll.Visible = show
            d.scroll.Position = Vector2.new(cx + cw - 5, w._scrollBarY)
            d.scroll.Size = Vector2.new(3, bh)
            d.scroll.Color = lc(pal.borderDim, pal.accent, 0.2)
            d.scroll.Transparency = 1 - alpha
            d.scroll.Rounding = 2
        else
            d.scroll.Visible = false
        end
    end

    for i, tab in ipairs(w._tabs) do
        if i ~= w._active then
            for _, el in ipairs(tab._elems) do el:draw(0, 0, 0, false) end
        end
    end
end

-- == bliss.new ==

function bliss.new(opts)
    opts = opts or {}
    local ww = opts.Size and opts.Size.X or 540
    local wh = opts.Size and opts.Size.Y or 400
    local cam = workspace.CurrentCamera

    if opts.AccentColor then
        pal.accent = opts.AccentColor
        pal.accentDim = Color3.new(opts.AccentColor.R * 0.72, opts.AccentColor.G * 0.72, opts.AccentColor.B * 0.72)
        pal.accentLit = Color3.new(math.min(1, opts.AccentColor.R * 1.22), math.min(1, opts.AccentColor.G * 1.22), math.min(1, opts.AccentColor.B * 1.22))
        pal.accentGlow = Color3.new(math.min(1, opts.AccentColor.R * 1.35), math.min(1, opts.AccentColor.G * 1.35), math.min(1, opts.AccentColor.B * 1.35))
    end

    local d = {
        shadow     = newRect({ Rounding = sz.round + 2, ZIndex = 0, Color = pal.shadow, Transparency = sz.shadowAlpha }),
        bg         = newRect({ Rounding = sz.round, ZIndex = 1 }),
        bgOut      = newRect({ Filled = false, Rounding = sz.round, ZIndex = 1 }),
        title      = newRect({ Rounding = 0, ZIndex = 2 }),
        titleInner = newRect({ Rounding = 0, ZIndex = 2, Transparency = 0.85 }),
        titleDiv   = newLine({ Color = pal.borderDim, ZIndex = 3 }),
        dot        = newDot({ Color = pal.accent, Radius = 4, NumSides = 20, ZIndex = 4 }),
        dotGlow    = newDot({ Color = pal.accent, Radius = 8, NumSides = 20, ZIndex = 3, Transparency = 0.8 }),
        name       = newLabel({ Color = pal.text, Size = sz.font, ZIndex = 4 }),
        slogan     = newLabel({ Text = "stay blissful!", Color = pal.textDim, Size = sz.fontXs, Font = 3, ZIndex = 4 }),
        side       = newRect({ ZIndex = 2 }),
        sideDiv    = newLine({ Color = pal.borderDim, ZIndex = 3 }),
        contentDiv = newLine({ Color = pal.borderDim, ZIndex = 3, Transparency = 0.5 }),
        scroll     = newRect({ Color = pal.borderDim, Rounding = 2, ZIndex = 25 }),
    }

    local win = setmetatable({
        _name = opts.Name or "bliss.lua",
        _sz = Vector2.new(ww, wh),
        _pos = opts.Position or Vector2.new((cam.ViewportSize.X - ww) / 2, (cam.ViewportSize.Y - wh) / 2),
        _vis = true, _tabs = {}, _active = 1,
        _flags = {}, _drag = false, _dOff = Vector2.new(0, 0),
        _draw = d, _tabDraw = {}, _openAnim = 0, _scrollBarY = 0,
    }, Window)

    bliss._windows[win._name] = win
    return win
end

-- == public api ==

function bliss:UIProperties(name, visible)
    local w = self._windows[name]
    if w then w._vis = visible end
end

function bliss:GetFlag(name, flag)
    local w = self._windows[name]
    return w and w._flags and w._flags[flag]
end

function bliss:SetFlag(name, flag, val)
    local w = self._windows[name]
    if not w then return end
    w._flags[flag] = val
    for _, tab in ipairs(w._tabs) do
        for _, el in ipairs(tab._elems) do
            if el.flag == flag and el.set then el:set(val) end
        end
    end
end

function bliss:SetTheme(t)
    for k, v in pairs(t or {}) do
        local map = {
            Accent = "accent", Background = "bg", Surface = "panel",
            Text = "text", TextSecondary = "textSub", Border = "border",
        }
        pal[map[k] or k] = v
    end
end

function bliss:SetToggleKey(k) self._toggleKey = k end

function bliss:Destroy(name)
    local w = self._windows[name]
    if not w then return end
    for _, tab in ipairs(w._tabs) do
        for _, el in ipairs(tab._elems) do if el.destroy then el:destroy() end end
    end
    for _, d in pairs(w._draw) do kill(d) end
    for _, td in ipairs(w._tabDraw) do
        for k, d in pairs(td) do if type(d) ~= "number" then kill(d) end end
    end
    self._windows[name] = nil
end

function bliss:DestroyAll()
    for name in pairs(self._windows) do self:Destroy(name) end
    for _, n in ipairs(self._notifications) do
        for _, d in pairs(n._d) do kill(d) end
    end
    self._notifications = {}
    for _, d in pairs(_tooltip._d) do kill(d) end
    for _, d in ipairs(self._allDrawings) do kill(d) end
    self._allDrawings = {}
    if _measureLabel then kill(_measureLabel); _measureLabel = nil end
    for _, c in ipairs(self._connections) do pcall(c.Disconnect, c) end
    self._connections = {}
end

-- == render loop ==

local _lastTime = os.clock()

table.insert(bliss._connections, RS.RenderStepped:Connect(function()
    local now = os.clock()
    local dt = math.min(now - _lastTime, 0.05)
    _lastTime = now

    local ml = UIS:GetMouseLocation()
    mx, my = ml.X, ml.Y - insetY

    mClickConsumed = false
    mRClickConsumed = false

    for _, w in pairs(bliss._windows) do
        renderWin(w, dt)
    end

    updateTooltip()
    updateNotifications(dt)
    membraneUpdate()

    setTooltip("")
    mClick = false
    mRClick = false
    mScroll = 0
    prevMDown = mDown
end))

GENV[BLISS_KEY] = bliss

-- stay blissful!
return bliss
