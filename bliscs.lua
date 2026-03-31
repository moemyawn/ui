--[[
    bliss.lua
    drawing-based ui lib for UNC/sUNC runtimes

    usage:
        local bliss = loadstring(game:HttpGet("url"))()
        local win = bliss.new({ Name = "bliss.lua" })
        local tab = win:AddTab({ Name = "main" })
        tab:AddToggle({ Name = "on", Callback = function(v) end })

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
bliss._visible = true
bliss._toggleKey = Enum.KeyCode.Equals
bliss._notifications = {}
bliss.membrane = false

-- == palette ==

local pal = {
    bg          = Color3.fromRGB(18, 17, 20),
    bgDeep      = Color3.fromRGB(13, 12, 15),
    panel       = Color3.fromRGB(23, 22, 27),
    panelLit    = Color3.fromRGB(30, 29, 35),
    hover       = Color3.fromRGB(38, 36, 44),
    press       = Color3.fromRGB(46, 43, 52),
    border      = Color3.fromRGB(46, 44, 54),
    borderDim   = Color3.fromRGB(34, 33, 40),
    borderLit   = Color3.fromRGB(62, 59, 72),
    text        = Color3.fromRGB(215, 212, 222),
    textSub     = Color3.fromRGB(135, 130, 148),
    textDim     = Color3.fromRGB(82, 78, 95),
    accent      = Color3.fromRGB(235, 135, 145),
    accentDim   = Color3.fromRGB(185, 100, 112),
    accentLit   = Color3.fromRGB(255, 165, 175),
    accentSoft  = Color3.fromRGB(235, 135, 145),
    good        = Color3.fromRGB(105, 195, 135),
    warn        = Color3.fromRGB(210, 180, 85),
    bad         = Color3.fromRGB(210, 85, 85),
    black       = Color3.fromRGB(0, 0, 0),
}

-- == sizing ==

local sz = {
    titleH     = 32,
    tabW       = 115,
    elemH      = 30,
    elemGap    = 5,
    pad        = 8,
    font       = 13,
    fontSm     = 11,
    fontXs     = 10,
    round      = 4,
    sliderH    = 4,
    toggleW    = 34,
    toggleH    = 16,
    colorBox   = 14,
}

-- == drawing constructors (unchanged from working version) ==

local function setProp(obj, key, value)
    if value == nil then return end
    pcall(function()
        obj[key] = value
    end)
end

local function applyCommon(d, p, defaults)
    setProp(d, "Visible", p.Visible or false)
    setProp(d, "Transparency", (p.Transparency ~= nil) and p.Transparency or 1)
    setProp(d, "ZIndex", p.ZIndex or defaults.ZIndex)
end

local function newRect(p)
    local d = Drawing.new("Square")
    applyCommon(d, p, { ZIndex = 1 })
    setProp(d, "Filled", (p.Filled == nil) and true or p.Filled)
    setProp(d, "Color", p.Color or pal.bg)
    setProp(d, "Position", p.Position or Vector2.new(0, 0))
    setProp(d, "Size", p.Size or Vector2.new(10, 10))
    setProp(d, "Thickness", p.Thickness or 1)
    setProp(d, "Rounding", p.Rounding or 0)
    return d
end

local function newLabel(p)
    local d = Drawing.new("Text")
    applyCommon(d, p, { ZIndex = 2 })
    setProp(d, "Text", p.Text or "")
    setProp(d, "Size", p.Size or sz.font)
    setProp(d, "Color", p.Color or pal.text)
    setProp(d, "Position", p.Position or Vector2.new(0, 0))
    setProp(d, "Center", p.Center or false)
    setProp(d, "Outline", true)
    setProp(d, "OutlineColor", pal.black)
    setProp(d, "Font", p.Font or 2)
    return d
end

local function newLine(p)
    local d = Drawing.new("Line")
    applyCommon(d, p, { ZIndex = 1 })
    setProp(d, "From", p.From or Vector2.new(0, 0))
    setProp(d, "To", p.To or Vector2.new(0, 0))
    setProp(d, "Color", p.Color or pal.border)
    setProp(d, "Thickness", p.Thickness or 1)
    return d
end

local function newDot(p)
    local d = Drawing.new("Circle")
    applyCommon(d, p, { ZIndex = 2 })
    setProp(d, "Filled", (p.Filled == nil) and true or p.Filled)
    setProp(d, "Color", p.Color or pal.accent)
    setProp(d, "Position", p.Position or Vector2.new(0, 0))
    setProp(d, "Radius", p.Radius or 5)
    setProp(d, "NumSides", p.NumSides or 20)
    setProp(d, "Thickness", p.Thickness or 1)
    return d
end

local function newTri(p)
    local d = Drawing.new("Triangle")
    applyCommon(d, p, { ZIndex = 2 })
    setProp(d, "Filled", (p.Filled == nil) and true or p.Filled)
    setProp(d, "Color", p.Color or pal.text)
    setProp(d, "PointA", p.A or Vector2.new(0, 0))
    setProp(d, "PointB", p.B or Vector2.new(0, 0))
    setProp(d, "PointC", p.C or Vector2.new(0, 0))
    setProp(d, "Thickness", p.Thickness or 1)
    return d
end

-- == math ==

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function lc(a, b, t) return Color3.new(lerp(a.R,b.R,t), lerp(a.G,b.G,t), lerp(a.B,b.B,t)) end
local function hit(px, py, x, y, w, h) return px>=x and px<=x+w and py>=y and py<=y+h end
local function snap(n, s) s = s or 1; return math.floor(n/s+0.5)*s end

local function bounce(cur, tgt, spd)
    local diff = tgt - cur
    if math.abs(diff) < 0.002 then return tgt end
    return cur + diff * clamp(spd, 0, 1) + diff * 0.04 * math.sin(os.clock() * 14)
end

local function kill(d)
    if not d then return end
    pcall(function()
        if d.Remove then d:Remove()
        elseif d.Destroy then d:Destroy() end
    end)
end

-- == text measurement ==

local _mCache = {}
local _mLabel = nil

local function measureText(text, fontSize, font)
    font = font or 2
    local key = text .. ":" .. fontSize .. ":" .. font
    if _mCache[key] then return _mCache[key] end
    if not _mLabel then
        _mLabel = Drawing.new("Text")
        _mLabel.Visible = false
        _mLabel.Size = 13
        _mLabel.Font = 2
    end
    _mLabel.Text = text
    _mLabel.Size = fontSize
    _mLabel.Font = font
    local bounds = Vector2.new(#text * fontSize * 0.55, fontSize)
    pcall(function() bounds = _mLabel.TextBounds end)
    _mCache[key] = bounds
    return bounds
end

-- == input state ==

local mx, my, mDown, mClick, mRClick, mScroll = 0, 0, false, false, false, 0
local mClickUsed = false
local mRClickUsed = false
local insetY = 0
pcall(function()
    local _, inset = GS:GetGuiInset()
    insetY = inset.Y or 0
end)

table.insert(bliss._connections, UIS.InputChanged:Connect(function(io)
    if io.UserInputType == Enum.UserInputType.MouseMovement then
        mx, my = io.Position.X, io.Position.Y - insetY
    elseif io.UserInputType == Enum.UserInputType.MouseWheel then
        mScroll = io.Position.Z
    end
end))

table.insert(bliss._connections, UIS.InputBegan:Connect(function(io, gp)
    if io.UserInputType == Enum.UserInputType.MouseButton1 then
        mDown = true
        mClick = true
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

-- == membrane ==

local _memLast = 0
local _memBase = 0
local _memSamples = {}

local function membraneUpdate()
    if not bliss.membrane then return end
    local now = os.clock()
    if now - _memLast < 2 then return end
    local mem = collectgarbage("count")
    _memSamples[#_memSamples + 1] = mem
    if #_memSamples > 30 then table.remove(_memSamples, 1) end
    if _memBase == 0 and #_memSamples >= 5 then
        local sum = 0
        for _, v in ipairs(_memSamples) do sum = sum + v end
        _memBase = sum / #_memSamples
    end
    if _memBase > 0 and mem > _memBase * 1.5 then
        collectgarbage("collect")
        _memLast = now
    elseif _memBase > 0 and now - _memLast > 30 then
        collectgarbage("step", 100)
        _memLast = now
    end
end

-- == tooltip ==

local _tip = { target = "", timer = 0, alpha = 0 }
_tip._d = {
    bg = newRect({ Rounding = 3, ZIndex = 210, Color = pal.panel }),
    bgOut = newRect({ Filled = false, Rounding = 3, ZIndex = 210, Color = pal.borderDim }),
    label = newLabel({ Size = sz.fontSm, ZIndex = 211, Color = pal.textSub }),
}

local function setTooltip(t)
    if t and t ~= "" then
        if _tip.target ~= t then _tip.timer = 0 end
        _tip.target = t
    else
        _tip.target = ""
    end
end

local function updateTooltip()
    if _tip.target ~= "" then
        _tip.timer = _tip.timer + (1/60)
    else
        _tip.timer = 0
    end
    local show = _tip.timer > 0.4 and _tip.target ~= "" and bliss._visible
    _tip.alpha = lerp(_tip.alpha, show and 1 or 0, 0.16)
    local vis = _tip.alpha > 0.05
    _tip._d.bg.Visible = vis
    _tip._d.bgOut.Visible = vis
    _tip._d.label.Visible = vis
    if not vis then return end
    local bounds = measureText(_tip.target, sz.fontSm)
    local pw = bounds.X + 12
    local ph = bounds.Y + 8
    local tx = mx + 14
    local ty = my + 14
    _tip._d.bg.Position = Vector2.new(tx, ty)
    _tip._d.bg.Size = Vector2.new(pw, ph)
    _tip._d.bg.Transparency = 1 - _tip.alpha
    _tip._d.bgOut.Position = Vector2.new(tx, ty)
    _tip._d.bgOut.Size = Vector2.new(pw, ph)
    _tip._d.bgOut.Transparency = 1 - _tip.alpha
    _tip._d.label.Position = Vector2.new(tx + 6, ty + 2)
    _tip._d.label.Text = _tip.target
    _tip._d.label.Transparency = 1 - _tip.alpha
end

-- == notifications ==

local function updateNotifications(dt)
    local screenW = workspace.CurrentCamera.ViewportSize.X
    local baseY = workspace.CurrentCamera.ViewportSize.Y - 16
    local i = #bliss._notifications
    while i >= 1 do
        local n = bliss._notifications[i]
        n._life = n._life + dt
        local dead = false
        if n._life > n.duration then
            n._fade = (n._fade or 0) + dt * 4
            if n._fade >= 1 then
                for _, d in pairs(n._d) do kill(d) end
                table.remove(bliss._notifications, i)
                dead = true
            end
        end
        if not dead then
            local fi = clamp(n._life * 5, 0, 1)
            local fo = 1 - (n._fade or 0)
            local a = fi * fo
            local nw = 240
            local nh = 56
            local ny = baseY - (nh + 6) * (#bliss._notifications - i + 1)
            local nx = screenW - nw - 16
            n._py = lerp(n._py or (ny + 20), ny, 0.15)
            local ac = n.color or pal.accent
            n._d.bg.Visible = bliss._visible; n._d.bg.Position = Vector2.new(nx, n._py)
            n._d.bg.Size = Vector2.new(nw, nh); n._d.bg.Color = pal.panel
            n._d.bg.Transparency = 1 - a; n._d.bg.Rounding = 4
            n._d.bgOut.Visible = bliss._visible; n._d.bgOut.Position = Vector2.new(nx, n._py)
            n._d.bgOut.Size = Vector2.new(nw, nh); n._d.bgOut.Color = lc(pal.borderDim, ac, 0.3)
            n._d.bgOut.Rounding = 4; n._d.bgOut.Transparency = 1 - a
            n._d.bar.Visible = bliss._visible; n._d.bar.Position = Vector2.new(nx + 4, n._py + 4)
            n._d.bar.Size = Vector2.new(3, nh - 8); n._d.bar.Color = ac; n._d.bar.Rounding = 2
            n._d.bar.Transparency = 1 - a
            n._d.title.Visible = bliss._visible; n._d.title.Position = Vector2.new(nx + 14, n._py + 8)
            n._d.title.Text = n.title; n._d.title.Color = pal.text; n._d.title.Transparency = 1 - a
            n._d.msg.Visible = bliss._visible; n._d.msg.Position = Vector2.new(nx + 14, n._py + 26)
            n._d.msg.Text = n.message; n._d.msg.Color = pal.textSub; n._d.msg.Transparency = 1 - a
            local pW = nw - 8
            local pPct = clamp(n._life / n.duration, 0, 1)
            n._d.prog.Visible = bliss._visible; n._d.prog.Position = Vector2.new(nx + 4, n._py + nh - 5)
            n._d.prog.Size = Vector2.new(pW * (1 - pPct), 2); n._d.prog.Color = ac; n._d.prog.Rounding = 1
            n._d.prog.Transparency = 1 - a
        end
        i = i - 1
    end
end

function bliss:Notify(opts)
    opts = opts or {}
    local cm = { success = pal.good, warning = pal.warn, error = pal.bad, info = pal.accent }
    local n = {
        title = opts.Title or "bliss.lua", message = opts.Message or "",
        duration = opts.Duration or 3, color = cm[opts.Type or "info"] or pal.accent,
        _life = 0, _fade = 0, _py = workspace.CurrentCamera.ViewportSize.Y,
        _d = {
            bg = newRect({ Rounding = 4, ZIndex = 200 }),
            bgOut = newRect({ Filled = false, Rounding = 4, ZIndex = 200 }),
            bar = newRect({ Rounding = 2, ZIndex = 201 }),
            title = newLabel({ Size = sz.font, ZIndex = 202 }),
            msg = newLabel({ Size = sz.fontSm, ZIndex = 202 }),
            prog = newRect({ Rounding = 1, ZIndex = 201 }),
        },
    }
    self._notifications[#self._notifications + 1] = n
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

local function serColor(c) return {math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)} end
local function desColor(t) return Color3.fromRGB(t[1], t[2], t[3]) end

function Config.Gather(win)
    local data = {}
    for _, tab in ipairs(win._tabs) do
        for _, el in ipairs(tab._elems) do
            if el.flag then
                local v = el.val
                if typeof(v) == "Color3" then data[el.flag] = { _t = "c3", _v = serColor(v) }
                elseif typeof(v) == "EnumItem" then data[el.flag] = { _t = "ei", _v = tostring(v) }
                elseif type(v) == "table" then data[el.flag] = { _t = "tb", _v = v }
                else data[el.flag] = v end
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
                if type(v) == "table" and v._t then
                    if v._t == "c3" then v = desColor(v._v)
                    elseif v._t == "ei" then pcall(function() local p = tostring(v._v):split("."); v = Enum[p[2]][p[3]] end)
                    elseif v._t == "tb" then v = v._v end
                end
                if el.set then el:set(v) else el.val = v end
            end
        end
    end
end

function Config.Save(win, name)
    local data = Config.Gather(win)
    local json = HS:JSONEncode(data)
    local enc = b64enc(json)
    local path = "bliss/" .. (name or win._name) .. ".cfg"
    if makefolder then pcall(makefolder, "bliss") end
    if writefile then writefile(path, enc); return true end
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
    return b64enc(HS:JSONEncode(Config.Gather(win)))
end

function Config.Import(win, str)
    local json = b64dec(str)
    local ok, data = pcall(HS.JSONDecode, HS, json)
    if not ok or type(data) ~= "table" then return false end
    Config.Apply(win, data)
    return true
end

function Config.List()
    local f = {}
    if listfiles then pcall(function() for _, v in ipairs(listfiles("bliss")) do if v:match("%.cfg$") then f[#f+1] = v:match("([^/\\]+)%.cfg$") end end end) end
    return f
end

function Config.Delete(name)
    if delfile then pcall(delfile, "bliss/" .. name .. ".cfg"); return true end
    return false
end

bliss.Config = Config

-- == elements ==

local function mkToggle(o, flags)
    local e = {
        type = "toggle", name = o.Name or "toggle",
        val = o.Default or false, cb = o.Callback or function()end,
        flag = o.Flag, h = sz.elemH, tip = o.Tooltip, _a = 0, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg = newRect({ Rounding = 8, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = 8, ZIndex = 28 })
    e._d.fill = newRect({ Rounding = 8, ZIndex = 29 })
    e._d.dot = newDot({ Radius = 4, ZIndex = 31 })

    function e:set(v) self.val = v; self.cb(v); if self.flag and flags then flags[self.flag] = v end end

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bw, bh = sz.toggleW, sz.toggleH
        local bx = px + w - bw - 6
        local by = py + (sz.elemH - bh) / 2
        local rowHit = hit(mx, my, px, py, w, sz.elemH)
        if self.tip and rowHit then setTooltip(self.tip) end
        if rowHit and mClick and not mClickUsed then
            self.val = not self.val; self.cb(self.val)
            if self.flag and flags then flags[self.flag] = self.val end
            mClickUsed = true
        end
        local tgt = self.val and 1 or 0
        self._a = bounce(self._a, tgt, 0.15)
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font) / 2 - 1)
        self._d.label.Color = rowHit and pal.text or pal.textSub
        self._d.label.Transparency = 0
        self._d.bg.Position = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh)
        self._d.bg.Color = lc(pal.panel, pal.accentDim, self._a * 0.35)
        self._d.bg.Transparency = 0
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color = lc(pal.borderDim, pal.accent, self._a)
        self._d.bgOut.Transparency = 0
        local fw = math.floor(bw * self._a)
        self._d.fill.Position = Vector2.new(bx, by); self._d.fill.Size = Vector2.new(fw, bh)
        self._d.fill.Color = pal.accent; self._d.fill.Transparency = 0.35
        local dx = lerp(bx + 8, bx + bw - 8, self._a)
        self._d.dot.Position = Vector2.new(dx, by + bh / 2)
        self._d.dot.Color = lc(pal.textDim, pal.text, self._a)
        self._d.dot.Transparency = 0
    end

    function e:destroy() for _,d in pairs(self._d) do kill(d) end end
    return e
end

local function mkSlider(o, flags)
    local e = {
        type = "slider", name = o.Name or "slider",
        val = o.Default or o.Min or 0, min = o.Min or 0, max = o.Max or 100,
        inc = o.Increment or 1, suf = o.Suffix or "",
        cb = o.Callback or function()end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH + 14, _drag = false, _a = 0, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.valTxt = newLabel({ Size = sz.fontSm, Color = pal.accent, ZIndex = 30 })
    e._d.track = newRect({ Rounding = 2, ZIndex = 28 })
    e._d.fill = newRect({ Rounding = 2, ZIndex = 29 })
    e._d.knob = newDot({ Radius = 5, ZIndex = 31 })

    function e:set(v) self.val = clamp(snap(v, self.inc), self.min, self.max); self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end end

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local tx, ty = px + 8, py + sz.elemH + 4
        local tw = w - 20
        local pct = (self.val - self.min) / math.max(self.max - self.min, 0.001)
        self._a = bounce(self._a, pct, 0.16)
        local trackHit = hit(mx, my, tx, ty - 6, tw, 16)
        if self.tip and trackHit then setTooltip(self.tip) end
        if trackHit and mClick and not mClickUsed then self._drag = true; mClickUsed = true end
        if not mDown then self._drag = false end
        if self._drag then
            local raw = clamp((mx - tx) / tw, 0, 1)
            local nv = clamp(snap(self.min + raw * (self.max - self.min), self.inc), self.min, self.max)
            if nv ~= self.val then self.val = nv; self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end end
        end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + 4)
        self._d.label.Color = (trackHit or self._drag) and pal.text or pal.textSub
        self._d.label.Transparency = 0
        local vs = tostring(self.val) .. self.suf
        local vb = measureText(vs, sz.fontSm)
        self._d.valTxt.Text = vs
        self._d.valTxt.Position = Vector2.new(px + w - vb.X - 6, py + 5)
        self._d.valTxt.Transparency = 0
        self._d.track.Position = Vector2.new(tx, ty); self._d.track.Size = Vector2.new(tw, sz.sliderH)
        self._d.track.Color = pal.borderDim; self._d.track.Transparency = 0
        local fw = math.max(2, math.floor(tw * self._a))
        self._d.fill.Position = Vector2.new(tx, ty); self._d.fill.Size = Vector2.new(fw, sz.sliderH)
        self._d.fill.Color = pal.accent; self._d.fill.Transparency = 0
        local kx = tx + tw * self._a
        self._d.knob.Position = Vector2.new(kx, ty + sz.sliderH / 2)
        self._d.knob.Color = self._drag and pal.accentLit or (trackHit and pal.text or pal.textSub)
        self._d.knob.Transparency = 0
    end

    function e:destroy() for _,d in pairs(self._d) do kill(d) end end
    return e
end

local function mkButton(o)
    local e = {
        type = "button", name = o.Name or "button",
        cb = o.Callback or function()end, h = sz.elemH, tip = o.Tooltip, _ha = 0, _d = {},
    }
    e._d.bg = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.label = newLabel({ Size = sz.font, Center = true, ZIndex = 30 })

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bx, by = px + 4, py + 2
        local bw, bh = w - 8, sz.elemH - 4
        local hov = hit(mx, my, bx, by, bw, bh)
        if self.tip and hov then setTooltip(self.tip) end
        self._ha = lerp(self._ha, hov and 1 or 0, 0.14)
        if hov and mClick and not mClickUsed then self.cb(); mClickUsed = true end
        self._d.bg.Position = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh)
        self._d.bg.Color = lc(pal.panel, pal.hover, self._ha); self._d.bg.Transparency = 0
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color = lc(pal.borderDim, pal.accent, self._ha * 0.5); self._d.bgOut.Transparency = 0
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(bx + bw/2, by + (bh - sz.font)/2 - 1)
        self._d.label.Color = lc(pal.textSub, pal.text, self._ha); self._d.label.Transparency = 0
    end

    function e:destroy() for _,d in pairs(self._d) do kill(d) end end
    return e
end

local function mkLabel(o)
    local e = { type = "label", text = o.Text or "", h = sz.elemH - 8, _d = {} }
    e._d.label = newLabel({ Size = sz.fontSm, Color = pal.textDim, ZIndex = 30 })
    function e:set(t) self.text = t end
    function e:draw(px, py, w, vis)
        self._d.label.Visible = vis
        if not vis then return end
        self._d.label.Text = self.text; self._d.label.Position = Vector2.new(px + 8, py + 2)
        self._d.label.Transparency = 0
    end
    function e:destroy() kill(self._d.label) end
    return e
end

local function mkSeparator()
    local e = { type = "sep", h = 10, _d = {} }
    e._d.line = newLine({ Color = pal.borderDim, ZIndex = 28 })
    function e:draw(px, py, w, vis)
        self._d.line.Visible = vis
        if not vis then return end
        self._d.line.From = Vector2.new(px + 10, py + 5)
        self._d.line.To = Vector2.new(px + w - 10, py + 5)
        self._d.line.Transparency = 0
    end
    function e:destroy() kill(self._d.line) end
    return e
end

local function mkSection(o)
    local e = { type = "header", text = o.Text or "section", h = 24, _d = {} }
    e._d.label = newLabel({ Size = sz.font, Color = pal.accent, ZIndex = 30 })
    e._d.line = newLine({ Color = pal.borderDim, ZIndex = 28 })
    function e:set(t) self.text = t end
    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bounds = measureText(self.text, sz.font)
        self._d.label.Text = self.text; self._d.label.Position = Vector2.new(px + 10, py + 5)
        self._d.label.Transparency = 0
        self._d.line.From = Vector2.new(px + bounds.X + 18, py + 12)
        self._d.line.To = Vector2.new(px + w - 8, py + 12)
        self._d.line.Transparency = 0
    end
    function e:destroy() for _,d in pairs(self._d) do kill(d) end end
    return e
end

local function mkDropdown(o, flags)
    local multi = o.Multi or false
    local e = {
        type = "dropdown", name = o.Name or "dropdown", multi = multi,
        opts = o.Options or {},
        val = multi and (o.Default or {}) or (o.Default or (o.Options and o.Options[1] or "")),
        cb = o.Callback or function()end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH, _open = false, _d = {}, _od = {}, _ob = {}, _oc = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.valTxt = newLabel({ Size = sz.fontSm, ZIndex = 30 })
    e._d.box = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.boxOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.arrow = newTri({ ZIndex = 30 })
    e._d.panBg = newRect({ Rounding = 3, ZIndex = 60 })
    e._d.panOut = newRect({ Filled = false, Rounding = 3, ZIndex = 60 })

    local function buildOpts(self)
        for i = 1, #self._od do kill(self._od[i]); kill(self._ob[i]); if self._oc[i] then kill(self._oc[i]) end end
        self._od, self._ob, self._oc = {}, {}, {}
        for i = 1, #self.opts do
            self._od[i] = newLabel({ Size = sz.fontSm, ZIndex = 62 })
            self._ob[i] = newRect({ Rounding = 2, ZIndex = 61 })
            if multi then self._oc[i] = newRect({ Rounding = 2, ZIndex = 63 }) end
        end
    end
    buildOpts(e)

    local function dispVal(self)
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
        if not self.multi then self.val = opt
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
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then
            for i = 1, #self._od do self._od[i].Visible = false; self._ob[i].Visible = false; if self._oc[i] then self._oc[i].Visible = false end end
            return
        end
        local bw = math.min(140, w * 0.45)
        local bh = sz.elemH - 6
        local bx = px + w - bw - 6
        local by = py + 3
        local hov = hit(mx, my, bx, by, bw, bh)
        if self.tip and hit(mx, my, px, py, w, sz.elemH) then setTooltip(self.tip) end
        if hov and mClick and not mClickUsed then self._open = not self._open; mClickUsed = true end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color = hov and pal.text or pal.textSub; self._d.label.Transparency = 0
        self._d.box.Position = Vector2.new(bx, by); self._d.box.Size = Vector2.new(bw, bh)
        self._d.box.Color = hov and pal.hover or pal.panel; self._d.box.Transparency = 0
        self._d.boxOut.Position = Vector2.new(bx, by); self._d.boxOut.Size = Vector2.new(bw, bh)
        self._d.boxOut.Color = pal.borderDim; self._d.boxOut.Transparency = 0
        self._d.valTxt.Text = dispVal(self)
        self._d.valTxt.Position = Vector2.new(bx + 6, by + (bh - sz.fontSm)/2 - 1); self._d.valTxt.Transparency = 0
        local ax = bx + bw - 12
        local ay = by + bh/2
        local s = 4
        if self._open then
            self._d.arrow.PointA = Vector2.new(ax-s, ay+2); self._d.arrow.PointB = Vector2.new(ax+s, ay+2); self._d.arrow.PointC = Vector2.new(ax, ay-2)
        else
            self._d.arrow.PointA = Vector2.new(ax-s, ay-2); self._d.arrow.PointB = Vector2.new(ax+s, ay-2); self._d.arrow.PointC = Vector2.new(ax, ay+2)
        end
        self._d.arrow.Color = pal.textDim; self._d.arrow.Transparency = 0
        if self._open and #self.opts > 0 then
            local oh = 22
            local ph = #self.opts * oh + 4
            local ppx, ppy = bx, by + bh + 2
            self._d.panBg.Visible = true; self._d.panOut.Visible = true
            self._d.panBg.Position = Vector2.new(ppx, ppy); self._d.panBg.Size = Vector2.new(bw, ph)
            self._d.panBg.Color = pal.bgDeep; self._d.panBg.Transparency = 0
            self._d.panOut.Position = Vector2.new(ppx, ppy); self._d.panOut.Size = Vector2.new(bw, ph)
            self._d.panOut.Color = pal.border; self._d.panOut.Transparency = 0
            local outside = mClick and not mClickUsed and not hit(mx, my, ppx, ppy, bw, ph) and not hov
            for i, opt in ipairs(self.opts) do
                local ox, oy = ppx + 2, ppy + 2 + (i-1)*oh
                local ow, ooh = bw - 4, oh
                local oHov = hit(mx, my, ox, oy, ow, ooh)
                local sel = hasVal(self, opt)
                self._ob[i].Visible = true; self._ob[i].Position = Vector2.new(ox, oy); self._ob[i].Size = Vector2.new(ow, ooh)
                self._ob[i].Color = oHov and pal.hover or (sel and pal.panelLit or pal.bgDeep); self._ob[i].Transparency = 0
                local tOff = multi and 20 or 6
                self._od[i].Visible = true; self._od[i].Text = opt
                self._od[i].Position = Vector2.new(ox + tOff, oy + (ooh - sz.fontSm)/2 - 1)
                self._od[i].Color = sel and pal.accent or (oHov and pal.text or pal.textSub); self._od[i].Transparency = 0
                if multi and self._oc[i] then
                    self._oc[i].Visible = true; self._oc[i].Position = Vector2.new(ox + 4, oy + (ooh - 10)/2)
                    self._oc[i].Size = Vector2.new(10, 10); self._oc[i].Color = sel and pal.accent or pal.borderDim
                    self._oc[i].Transparency = 0
                end
                if oHov and mClick and not mClickUsed then
                    toggleVal(self, opt)
                    if not multi then self._open = false end
                    mClickUsed = true
                end
            end
            if outside then self._open = false end
        else
            self._d.panBg.Visible = false; self._d.panOut.Visible = false
            for i = 1, #self._od do self._od[i].Visible = false; self._ob[i].Visible = false; if self._oc[i] then self._oc[i].Visible = false end end
        end
    end

    function e:destroy()
        for _,d in pairs(self._d) do kill(d) end
        for i = 1, #self._od do kill(self._od[i]); kill(self._ob[i]); if self._oc[i] then kill(self._oc[i]) end end
    end
    return e
end

local function mkKeybind(o, flags)
    local e = {
        type = "keybind", name = o.Name or "keybind",
        val = o.Default or Enum.KeyCode.Unknown,
        mode = o.Mode or "toggle",
        cb = o.Callback or function()end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH, _listen = false, _ctxOpen = false, _active = false, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.keyTxt = newLabel({ Size = sz.fontXs, Center = true, ZIndex = 30 })
    e._d.modeTxt = newLabel({ Size = sz.fontXs, ZIndex = 30, Color = pal.textDim })
    e._d.ctxBg = newRect({ Rounding = 3, ZIndex = 100 })
    e._d.ctxOut = newRect({ Filled = false, Rounding = 3, ZIndex = 100 })
    local modes = {"toggle", "hold", "always on", "always off"}
    e._ctxItems = {}
    for i = 1, #modes do
        e._ctxItems[i] = { bg = newRect({ Rounding = 2, ZIndex = 101 }), label = newLabel({ Size = sz.fontSm, ZIndex = 102 }) }
    end

    local kconn

    function e:set(k)
        if type(k) == "table" then self.val = k.Key or self.val; self.mode = k.Mode or self.mode
        else self.val = k end
        if self.flag and flags then flags[self.flag] = { Key = self.val, Mode = self.mode, Active = self._active } end
    end

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        for _, ci in pairs(self._ctxItems) do ci.bg.Visible = false; ci.label.Visible = false end
        self._d.ctxBg.Visible = false; self._d.ctxOut.Visible = false
        if not vis then return end
        local kn = self._listen and "..." or (self.val and self.val.Name or "None")
        local kb = measureText(kn, sz.fontXs)
        local kw = math.max(42, kb.X + 16)
        local kh = sz.elemH - 10
        local kx = px + w - kw - 6
        local ky = py + 5
        local hov = hit(mx, my, kx, ky, kw, kh)
        if self.tip and hit(mx, my, px, py, w, sz.elemH) then setTooltip(self.tip) end
        if hov and mClick and not mClickUsed and not self._listen then
            self._listen = true; mClickUsed = true
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
        if hov and mRClick and not mRClickUsed then self._ctxOpen = not self._ctxOpen; mRClickUsed = true end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color = pal.textSub; self._d.label.Transparency = 0
        self._d.bg.Position = Vector2.new(kx, ky); self._d.bg.Size = Vector2.new(kw, kh)
        self._d.bg.Color = self._listen and pal.press or (hov and pal.hover or pal.panel); self._d.bg.Transparency = 0
        self._d.bgOut.Position = Vector2.new(kx, ky); self._d.bgOut.Size = Vector2.new(kw, kh)
        self._d.bgOut.Color = self._listen and pal.accent or (self._active and pal.accentDim or pal.borderDim); self._d.bgOut.Transparency = 0
        self._d.keyTxt.Text = kn
        self._d.keyTxt.Position = Vector2.new(kx + kw/2, ky + (kh - sz.fontXs)/2 - 1)
        self._d.keyTxt.Color = self._listen and pal.accent or (self._active and pal.accentLit or pal.textDim); self._d.keyTxt.Transparency = 0
        local mb = measureText("[" .. self.mode .. "]", sz.fontXs)
        self._d.modeTxt.Text = "[" .. self.mode .. "]"
        self._d.modeTxt.Position = Vector2.new(kx - mb.X - 6, py + (sz.elemH - sz.fontXs)/2)
        self._d.modeTxt.Transparency = 0
        if self._ctxOpen then
            local cW, cH = 100, #modes * 22 + 4
            local cX, cY = kx, ky + kh + 3
            self._d.ctxBg.Visible = true; self._d.ctxOut.Visible = true
            self._d.ctxBg.Position = Vector2.new(cX, cY); self._d.ctxBg.Size = Vector2.new(cW, cH)
            self._d.ctxBg.Color = pal.bgDeep; self._d.ctxBg.Transparency = 0
            self._d.ctxOut.Position = Vector2.new(cX, cY); self._d.ctxOut.Size = Vector2.new(cW, cH)
            self._d.ctxOut.Color = pal.border; self._d.ctxOut.Transparency = 0
            local ctxOut = mClick and not mClickUsed and not hit(mx, my, cX, cY, cW, cH) and not hov
            for i, m in ipairs(modes) do
                local iy = cY + 2 + (i-1)*22
                local iHov = hit(mx, my, cX+2, iy, cW-4, 22)
                local sel = self.mode == m
                self._ctxItems[i].bg.Visible = true; self._ctxItems[i].bg.Position = Vector2.new(cX+2, iy)
                self._ctxItems[i].bg.Size = Vector2.new(cW-4, 22)
                self._ctxItems[i].bg.Color = iHov and pal.hover or (sel and pal.panelLit or pal.bgDeep)
                self._ctxItems[i].bg.Transparency = 0
                self._ctxItems[i].label.Visible = true; self._ctxItems[i].label.Text = m
                self._ctxItems[i].label.Position = Vector2.new(cX+10, iy+4)
                self._ctxItems[i].label.Color = sel and pal.accent or (iHov and pal.text or pal.textSub)
                self._ctxItems[i].label.Transparency = 0
                if iHov and mClick and not mClickUsed then
                    self.mode = m; self._ctxOpen = false; mClickUsed = true
                    if self.flag and flags then flags[self.flag] = { Key = self.val, Mode = self.mode, Active = self._active } end
                end
            end
            if ctxOut then self._ctxOpen = false end
        end
    end

    table.insert(bliss._connections, UIS.InputBegan:Connect(function(io, gp)
        if gp or e._listen then return end
        if io.KeyCode == e.val then
            if e.mode == "toggle" then e._active = not e._active; e.cb(e._active)
            elseif e.mode == "hold" then e._active = true; e.cb(true)
            elseif e.mode == "always on" then e._active = true end
            if e.flag and flags then flags[e.flag] = { Key = e.val, Mode = e.mode, Active = e._active } end
        end
    end))

    table.insert(bliss._connections, UIS.InputEnded:Connect(function(io)
        if io.KeyCode == e.val and e.mode == "hold" then
            e._active = false; e.cb(false)
            if e.flag and flags then flags[e.flag] = { Key = e.val, Mode = e.mode, Active = e._active } end
        end
    end))

    function e:destroy()
        for _,d in pairs(self._d) do kill(d) end
        for _, ci in pairs(self._ctxItems) do kill(ci.bg); kill(ci.label) end
        if kconn then kconn:Disconnect() end
    end
    return e
end

local function mkTextbox(o, flags)
    local e = {
        type = "textbox", name = o.Name or "textbox",
        val = o.Default or "", ph = o.Placeholder or "type here...",
        cb = o.Callback or function()end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH + 6, _focus = false, _blink = 0, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.txt = newLabel({ Size = sz.fontSm, ZIndex = 30 })
    e._d.cur = newLine({ Color = pal.accent, ZIndex = 31 })

    local cconn
    function e:set(v) self.val = v; self.cb(v); if self.flag and flags then flags[self.flag] = v end end

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bw = w - 14
        local bh = 20
        local bx = px + 7
        local by = py + sz.elemH - bh + 3
        local hov = hit(mx, my, bx, by, bw, bh)
        if self.tip and hov then setTooltip(self.tip) end
        if mClick and not mClickUsed then
            local was = self._focus
            self._focus = hov
            if self._focus and not was then
                mClickUsed = true
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
        self._d.label.Text = self.name; self._d.label.Position = Vector2.new(px + 8, py + 2)
        self._d.label.Transparency = 0
        self._d.bg.Position = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh)
        self._d.bg.Color = pal.bgDeep; self._d.bg.Transparency = 0
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color = self._focus and pal.accent or (hov and pal.borderLit or pal.borderDim)
        self._d.bgOut.Transparency = 0
        local dt = #self.val > 0 and self.val or self.ph
        self._d.txt.Text = dt; self._d.txt.Position = Vector2.new(bx + 6, by + (bh - sz.fontSm)/2 - 1)
        self._d.txt.Color = #self.val > 0 and pal.text or pal.textDim; self._d.txt.Transparency = 0
        if self._focus then
            self._blink = (self._blink + 1) % 60
            self._d.cur.Visible = self._blink < 35
            local tb = measureText(self.val, sz.fontSm)
            local cx = bx + 6 + tb.X + 1
            self._d.cur.From = Vector2.new(cx, by + 3); self._d.cur.To = Vector2.new(cx, by + bh - 3)
            self._d.cur.Transparency = 0
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

    function e:destroy() for _,d in pairs(self._d) do kill(d) end; if cconn then cconn:Disconnect() end end
    return e
end

local function mkColorPicker(o, flags)
    local e = {
        type = "color", name = o.Name or "color",
        val = o.Default or Color3.new(1,1,1),
        cb = o.Callback or function()end, flag = o.Flag, tip = o.Tooltip,
        h = sz.elemH, _open = false, _dSV = false, _dH = false,
        _hue = 0, _sat = 1, _bri = 1, _d = {},
    }
    do
        local r,g,b = e.val.R, e.val.G, e.val.B
        local hi,lo = math.max(r,g,b), math.min(r,g,b)
        local d = hi - lo
        e._bri = hi; e._sat = hi==0 and 0 or d/hi
        if d == 0 then e._hue = 0
        elseif hi == r then e._hue = ((g-b)/d)%6
        elseif hi == g then e._hue = (b-r)/d+2
        else e._hue = (r-g)/d+4 end
        e._hue = e._hue / 6
    end

    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.prev = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.prevOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.panBg = newRect({ Rounding = 4, ZIndex = 60 })
    e._d.panOut = newRect({ Filled = false, Rounding = 4, ZIndex = 60 })
    e._d.svBox = newRect({ Rounding = 2, ZIndex = 61 })
    e._d.svDot = newDot({ Filled = false, Radius = 4, Thickness = 2, ZIndex = 63 })
    e._d.svDotIn = newDot({ Radius = 2, ZIndex = 64 })
    e._d.hBar = newRect({ Rounding = 2, ZIndex = 61 })
    e._d.hCur = newRect({ Rounding = 2, ZIndex = 62 })
    e._d.hexTxt = newLabel({ Size = sz.fontXs, ZIndex = 62, Color = pal.textDim })

    function e:set(c)
        self.val = c; self.cb(c)
        local r,g,b = c.R, c.G, c.B
        local hi,lo = math.max(r,g,b), math.min(r,g,b)
        local d = hi - lo
        self._bri = hi; self._sat = hi==0 and 0 or d/hi
        if d == 0 then self._hue = 0
        elseif hi == r then self._hue = ((g-b)/d)%6
        elseif hi == g then self._hue = (b-r)/d+2
        else self._hue = (r-g)/d+4 end
        self._hue = self._hue / 6
        if self.flag and flags then flags[self.flag] = c end
    end

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local cs = sz.colorBox
        local cx = px + w - cs - 10
        local cy = py + (sz.elemH - cs)/2
        local hov = hit(mx, my, cx, cy, cs, cs)
        if self.tip and hov then setTooltip(self.tip) end
        if hov and mClick and not mClickUsed then self._open = not self._open; mClickUsed = true end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color = pal.textSub; self._d.label.Transparency = 0
        self._d.prev.Position = Vector2.new(cx, cy); self._d.prev.Size = Vector2.new(cs, cs)
        self._d.prev.Color = self.val; self._d.prev.Transparency = 0
        self._d.prevOut.Position = Vector2.new(cx, cy); self._d.prevOut.Size = Vector2.new(cs, cs)
        self._d.prevOut.Color = pal.borderDim; self._d.prevOut.Transparency = 0
        local show = self._open
        for _, k in pairs({"panBg","panOut","svBox","svDot","svDotIn","hBar","hCur","hexTxt"}) do
            self._d[k].Visible = show
        end
        if show then
            local pw, ph = 170, 130
            local ppx = cx + cs - pw
            local ppy = cy + cs + 4
            self._d.panBg.Position = Vector2.new(ppx, ppy); self._d.panBg.Size = Vector2.new(pw, ph)
            self._d.panBg.Color = pal.bgDeep; self._d.panBg.Transparency = 0
            self._d.panOut.Position = Vector2.new(ppx, ppy); self._d.panOut.Size = Vector2.new(pw, ph)
            self._d.panOut.Color = pal.border; self._d.panOut.Transparency = 0
            local sx, sy = ppx + 6, ppy + 6
            local sw, sh = pw - 26, ph - 26
            self._d.svBox.Position = Vector2.new(sx, sy); self._d.svBox.Size = Vector2.new(sw, sh)
            self._d.svBox.Color = Color3.fromHSV(self._hue, 1, 1); self._d.svBox.Transparency = 0
            if hit(mx, my, sx, sy, sw, sh) and mClick and not mClickUsed then self._dSV = true; mClickUsed = true end
            if not mDown then self._dSV = false end
            if self._dSV then
                self._sat = clamp((mx - sx)/sw, 0, 1)
                self._bri = 1 - clamp((my - sy)/sh, 0, 1)
                self.val = Color3.fromHSV(self._hue, self._sat, self._bri)
                self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end
            end
            self._d.svDot.Position = Vector2.new(sx + self._sat*sw, sy + (1-self._bri)*sh)
            self._d.svDot.Color = pal.text; self._d.svDot.Transparency = 0
            self._d.svDotIn.Position = Vector2.new(sx + self._sat*sw, sy + (1-self._bri)*sh)
            self._d.svDotIn.Color = self.val; self._d.svDotIn.Transparency = 0
            local hx, hy = ppx + pw - 16, ppy + 6
            local hh = ph - 26
            self._d.hBar.Position = Vector2.new(hx, hy); self._d.hBar.Size = Vector2.new(8, hh)
            self._d.hBar.Color = Color3.fromHSV(self._hue, 1, 1); self._d.hBar.Transparency = 0
            if hit(mx, my, hx-2, hy, 12, hh) and mClick and not mClickUsed then self._dH = true; mClickUsed = true end
            if not mDown then self._dH = false end
            if self._dH then
                self._hue = clamp((my - hy)/hh, 0, 0.999)
                self.val = Color3.fromHSV(self._hue, self._sat, self._bri)
                self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end
            end
            self._d.hCur.Position = Vector2.new(hx - 2, hy + self._hue*hh - 3)
            self._d.hCur.Size = Vector2.new(12, 6); self._d.hCur.Color = pal.text; self._d.hCur.Transparency = 0
            local hex = string.format("#%02X%02X%02X", math.floor(self.val.R*255), math.floor(self.val.G*255), math.floor(self.val.B*255))
            self._d.hexTxt.Text = hex; self._d.hexTxt.Position = Vector2.new(ppx + 6, ppy + ph - 16)
            self._d.hexTxt.Transparency = 0
            if mClick and not mClickUsed and not hit(mx, my, ppx, ppy, pw, ph) and not hov and not self._dSV and not self._dH then
                self._open = false
            end
        end
    end

    function e:destroy() for _,d in pairs(self._d) do kill(d) end end
    return e
end

-- == Tab ==

local Tab = {}
Tab.__index = Tab

function Tab:AddToggle(o) local e = mkToggle(o, self._win._flags); self._elems[#self._elems+1] = e; return e end
function Tab:AddSlider(o) local e = mkSlider(o, self._win._flags); self._elems[#self._elems+1] = e; return e end
function Tab:AddButton(o) local e = mkButton(o); self._elems[#self._elems+1] = e; return e end
function Tab:AddDropdown(o) local e = mkDropdown(o, self._win._flags); self._elems[#self._elems+1] = e; return e end
function Tab:AddKeybind(o) local e = mkKeybind(o, self._win._flags); self._elems[#self._elems+1] = e; return e end
function Tab:AddTextbox(o) local e = mkTextbox(o, self._win._flags); self._elems[#self._elems+1] = e; return e end
function Tab:AddColorPicker(o) local e = mkColorPicker(o, self._win._flags); self._elems[#self._elems+1] = e; return e end
function Tab:AddLabel(o) local e = mkLabel(o); self._elems[#self._elems+1] = e; return e end
function Tab:AddSeparator() local e = mkSeparator(); self._elems[#self._elems+1] = e; return e end
function Tab:AddSection(o) local e = mkSection(o); self._elems[#self._elems+1] = e; return e end

-- == Window ==

local Window = {}
Window.__index = Window

function Window:AddTab(o)
    o = o or {}
    local tab = setmetatable({
        name = o.Name or "tab", icon = o.Icon or "·",
        _elems = {}, _scroll = 0, _win = self,
    }, Tab)
    local td = {
        bg = newRect({ Rounding = 3, ZIndex = 8 }),
        icon = newLabel({ Size = sz.fontSm, Center = true, ZIndex = 9 }),
        label = newLabel({ Size = sz.fontSm, ZIndex = 9 }),
        bar = newRect({ Rounding = 2, ZIndex = 9, Color = pal.accent }),
    }
    self._tabDraw[#self._tabDraw+1] = td
    self._tabs[#self._tabs+1] = tab
    if #self._tabs == 1 then self._active = 1 end
    return tab
end

function Window:SetVisible(v) self._vis = v end
function Window:SetTab(x)
    if type(x) == "number" then self._active = clamp(x, 1, #self._tabs)
    else for i, t in ipairs(self._tabs) do if t.name == x then self._active = i; break end end end
end

-- == render ==

local function renderWin(w)
    local show = w._vis and bliss._visible
    local p = w._pos
    local ww, wh = w._sz.X, w._sz.Y

    if hit(mx, my, p.X, p.Y, ww, sz.titleH) and mClick and not mClickUsed and not w._drag then
        w._drag = true; w._dOff = Vector2.new(mx - p.X, my - p.Y); mClickUsed = true
    end
    if not mDown then w._drag = false end
    if w._drag then
        w._pos = Vector2.new(mx - w._dOff.X, my - w._dOff.Y)
        p = w._pos
    end

    local d = w._draw
    for _, obj in pairs(d) do obj.Visible = show end
    if not show then
        for _, td in ipairs(w._tabDraw) do for _, obj in pairs(td) do obj.Visible = false end end
        for _, tab in ipairs(w._tabs) do for _, el in ipairs(tab._elems) do el:draw(0, 0, 0, false) end end
        return
    end

    d.shadow.Position = Vector2.new(p.X + 5, p.Y + 5); d.shadow.Size = Vector2.new(ww, wh)
    d.shadow.Color = pal.black; d.shadow.Transparency = 0.5; d.shadow.Rounding = sz.round + 2
    d.bg.Position = p; d.bg.Size = Vector2.new(ww, wh); d.bg.Color = pal.bg; d.bg.Transparency = 0
    d.bgOut.Position = p; d.bgOut.Size = Vector2.new(ww, wh); d.bgOut.Color = pal.border; d.bgOut.Transparency = 0
    d.title.Position = p; d.title.Size = Vector2.new(ww, sz.titleH); d.title.Color = pal.panel; d.title.Transparency = 0
    d.titleDiv.From = Vector2.new(p.X, p.Y + sz.titleH); d.titleDiv.To = Vector2.new(p.X + ww, p.Y + sz.titleH); d.titleDiv.Transparency = 0
    d.dot.Position = Vector2.new(p.X + 13, p.Y + sz.titleH/2); d.dot.Transparency = 0
    d.name.Position = Vector2.new(p.X + 24, p.Y + (sz.titleH - sz.font)/2 - 1); d.name.Text = w._name; d.name.Transparency = 0
    d.slogan.Position = Vector2.new(p.X + ww - 72, p.Y + (sz.titleH - sz.fontXs)/2); d.slogan.Transparency = 0
    d.side.Position = Vector2.new(p.X, p.Y + sz.titleH); d.side.Size = Vector2.new(sz.tabW, wh - sz.titleH)
    d.side.Color = pal.bgDeep; d.side.Transparency = 0
    d.sideDiv.From = Vector2.new(p.X + sz.tabW, p.Y + sz.titleH); d.sideDiv.To = Vector2.new(p.X + sz.tabW, p.Y + wh)
    d.sideDiv.Transparency = 0

    local sideY = p.Y + sz.titleH
    for i, td in ipairs(w._tabDraw) do
        local act = (i == w._active)
        local ty = sideY + 8 + (i-1)*30
        local tx = p.X + 6
        local tw = sz.tabW - 12
        local th = 26
        local hov = hit(mx, my, tx, ty, tw, th)
        if hov and mClick and not mClickUsed then w._active = i; mClickUsed = true end
        for _, obj in pairs(td) do obj.Visible = show end
        td.bg.Position = Vector2.new(tx, ty); td.bg.Size = Vector2.new(tw, th)
        td.bg.Color = act and pal.panelLit or (hov and pal.hover or pal.bgDeep); td.bg.Transparency = 0
        td.icon.Position = Vector2.new(tx + 11, ty + (th - sz.fontSm)/2 - 1)
        td.icon.Color = act and pal.accent or pal.textDim; td.icon.Text = w._tabs[i].icon; td.icon.Transparency = 0
        td.label.Position = Vector2.new(tx + 24, ty + (th - sz.fontSm)/2 - 1)
        td.label.Color = act and pal.text or (hov and pal.textSub or pal.textDim)
        td.label.Text = w._tabs[i].name; td.label.Transparency = 0
        td.bar.Position = Vector2.new(tx + 1, ty + 5); td.bar.Size = Vector2.new(2, 16)
        td.bar.Visible = show and act; td.bar.Transparency = 0
    end

    local cx = p.X + sz.tabW + 1
    local cy = p.Y + sz.titleH + 1
    local cw = ww - sz.tabW - 2
    local ch = wh - sz.titleH - 2

    d.contentDiv.From = Vector2.new(cx, cy); d.contentDiv.To = Vector2.new(cx + cw, cy); d.contentDiv.Transparency = 0.5

    local at = w._tabs[w._active]
    if at then
        if hit(mx, my, cx, cy, cw, ch) and mScroll ~= 0 then
            at._scroll = at._scroll - mScroll * 26
        end
        local totalH = 0
        for _, el in ipairs(at._elems) do totalH = totalH + el.h + sz.elemGap end
        at._scroll = clamp(at._scroll, 0, math.max(0, totalH - ch + 14))

        local ey = cy + sz.pad - at._scroll
        for _, el in ipairs(at._elems) do
            local eVis = show and (ey + el.h > cy) and (ey < cy + ch)
            el:draw(cx + 4, ey, cw - 12, eVis)
            ey = ey + el.h + sz.elemGap
        end

        if totalH > ch then
            local ratio = at._scroll / (totalH - ch + 14)
            local bh = math.max(20, (ch/totalH)*ch)
            local by = cy + ratio * (ch - bh)
            d.scroll.Visible = true; d.scroll.Position = Vector2.new(cx + cw - 4, by)
            d.scroll.Size = Vector2.new(2, bh); d.scroll.Transparency = 0
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
    local ww = opts.Size and opts.Size.X or 520
    local wh = opts.Size and opts.Size.Y or 380
    local cam = workspace.CurrentCamera

    if opts.AccentColor then
        pal.accent = opts.AccentColor
        pal.accentDim = Color3.new(opts.AccentColor.R*0.75, opts.AccentColor.G*0.75, opts.AccentColor.B*0.75)
        pal.accentLit = Color3.new(math.min(1,opts.AccentColor.R*1.2), math.min(1,opts.AccentColor.G*1.2), math.min(1,opts.AccentColor.B*1.2))
    end

    local d = {
        shadow     = newRect({ Rounding = sz.round + 2, ZIndex = 0 }),
        bg         = newRect({ Rounding = sz.round, ZIndex = 1 }),
        bgOut      = newRect({ Filled = false, Rounding = sz.round, ZIndex = 1 }),
        title      = newRect({ ZIndex = 2 }),
        titleDiv   = newLine({ Color = pal.borderDim, ZIndex = 3 }),
        dot        = newDot({ Color = pal.accent, Radius = 3, NumSides = 16, ZIndex = 4 }),
        name       = newLabel({ Color = pal.text, Size = sz.font, ZIndex = 4 }),
        slogan     = newLabel({ Text = "stay blissful!", Color = pal.textDim, Size = sz.fontXs, Font = 3, ZIndex = 4 }),
        side       = newRect({ ZIndex = 2 }),
        sideDiv    = newLine({ Color = pal.borderDim, ZIndex = 3 }),
        contentDiv = newLine({ Color = pal.borderDim, ZIndex = 3 }),
        scroll     = newRect({ Color = pal.borderDim, Rounding = 2, ZIndex = 25 }),
    }

    local win = setmetatable({
        _name = opts.Name or "bliss.lua",
        _sz = Vector2.new(ww, wh),
        _pos = opts.Position or Vector2.new((cam.ViewportSize.X - ww)/2, (cam.ViewportSize.Y - wh)/2),
        _vis = true, _tabs = {}, _active = 1,
        _flags = {}, _drag = false, _dOff = Vector2.new(0, 0),
        _draw = d, _tabDraw = {},
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
        local map = { Accent="accent", Background="bg", Surface="panel", Text="text", TextSecondary="textSub", Border="border" }
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
    for _, td in ipairs(w._tabDraw) do for _, d in pairs(td) do kill(d) end end
    self._windows[name] = nil
end

function bliss:DestroyAll()
    for name in pairs(self._windows) do self:Destroy(name) end
    for _, n in ipairs(self._notifications) do for _, d in pairs(n._d) do kill(d) end end
    self._notifications = {}
    for _, d in pairs(_tip._d) do kill(d) end
    if _mLabel then kill(_mLabel); _mLabel = nil end
    for _, c in ipairs(self._connections) do pcall(c.Disconnect, c) end
    self._connections = {}
end

-- == render loop ==

table.insert(bliss._connections, RS.RenderStepped:Connect(function()
    local ml = UIS:GetMouseLocation()
    mx, my = ml.X, ml.Y - insetY

    mClickUsed = false
    mRClickUsed = false

    for _, w in pairs(bliss._windows) do
        renderWin(w)
    end

    updateTooltip()
    updateNotifications(1/60)
    membraneUpdate()

    setTooltip("")
    mClick = false
    mRClick = false
    mScroll = 0
end))

GENV[BLISS_KEY] = bliss

-- stay blissful!
return bliss
