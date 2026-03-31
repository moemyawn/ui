--[[
    bliss.lua
    drawing-based ui lib for UNC/sUNC runtimes

    usage:
        local bliss = loadstring(game:HttpGet("to be changed cause i haven't made the repo yet"))()
        local win = bliss.new({ Name = "bliss.lua" })
        local tab = win:AddTab({ Name = "main" })
        tab:AddToggle({ Name = "on", Callback = function(v) end })

    "stay blissful!"
--]]

local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local bliss = {}
bliss._windows = {}
bliss._connections = {}
bliss._visible = true
bliss._toggleKey = Enum.KeyCode.RightShift

-- salmon-pink, soft and warm
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

-- drawing constructors
-- nothing fancy, just wrappers that return the object

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

-- math stuff

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function lc(a, b, t) return Color3.new(lerp(a.R,b.R,t), lerp(a.G,b.G,t), lerp(a.B,b.B,t)) end
local function hit(mx, my, x, y, w, h) return mx>=x and mx<=x+w and my>=y and my<=y+h end
local function snap(n, s) s = s or 1; return math.floor(n/s+0.5)*s end

-- mouse state, polled every frame

local mx, my, mDown, mClick, mScroll = 0, 0, false, false, 0

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
        mClick = true
    end
    if io.KeyCode == bliss._toggleKey and not gp then
        bliss._visible = not bliss._visible
    end
end))

table.insert(bliss._connections, UIS.InputEnded:Connect(function(io)
    if io.UserInputType == Enum.UserInputType.MouseButton1 then
        mDown = false
    end
end))

-- remove helper, safely kills a drawing
local function kill(d)
    if not d then return end
    pcall(function()
        if d.Remove then
            d:Remove()
        elseif d.Destroy then
            d:Destroy()
        end
    end)
end

-- each window/tab/element tracks its own drawings in a flat list
-- so cleanup is just iterate and :Remove()

-- ══════════════════════════════════════
--  elements
-- ══════════════════════════════════════

local function mkToggle(o, flags)
    local e = {
        type = "toggle", name = o.Name or "toggle",
        val = o.Default or false, cb = o.Callback or function()end,
        flag = o.Flag, h = sz.elemH, _a = 0, _d = {},
    }
    -- drawings created here, AFTER window chrome exists
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.fill = newRect({ Rounding = 3, ZIndex = 29, Transparency = 0.35 })
    e._d.dot = newDot({ Radius = 4, ZIndex = 31 })

    function e:set(v) self.val = v; self.cb(v); if self.flag and flags then flags[self.flag] = v end end

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bw, bh = sz.toggleW, sz.toggleH
        local bx = px + w - bw - 6
        local by = py + (sz.elemH - bh) / 2
        local rowHit = hit(mx, my, px, py, w, sz.elemH)
        if rowHit and mClick then self.val = not self.val; self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end end
        local tgt = self.val and 1 or 0
        self._a = lerp(self._a, tgt, 0.16)
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font) / 2 - 1)
        self._d.label.Color = rowHit and pal.text or pal.textSub
        self._d.bg.Position = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh)
        self._d.bg.Color = lc(pal.panel, pal.accentDim, self._a * 0.35)
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color = lc(pal.borderDim, pal.accent, self._a)
        local fw = math.floor(bw * self._a)
        self._d.fill.Position = Vector2.new(bx, by); self._d.fill.Size = Vector2.new(fw, bh)
        self._d.fill.Color = pal.accent
        local dx = lerp(bx + 8, bx + bw - 8, self._a)
        self._d.dot.Position = Vector2.new(dx, by + bh / 2)
        self._d.dot.Color = lc(pal.textDim, pal.text, self._a)
    end

    function e:destroy() for _,d in pairs(self._d) do kill(d) end end
    return e
end

local function mkSlider(o, flags)
    local e = {
        type = "slider", name = o.Name or "slider",
        val = o.Default or o.Min or 0, min = o.Min or 0, max = o.Max or 100,
        inc = o.Increment or 1, suf = o.Suffix or "",
        cb = o.Callback or function()end, flag = o.Flag,
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
        local pct = (self.val - self.min) / (self.max - self.min)
        self._a = lerp(self._a, pct, 0.18)
        local trackHit = hit(mx, my, tx, ty - 6, tw, 16)
        if trackHit and mClick then self._drag = true end
        if not mDown then self._drag = false end
        if self._drag then
            local raw = clamp((mx - tx) / tw, 0, 1)
            local nv = clamp(snap(self.min + raw * (self.max - self.min), self.inc), self.min, self.max)
            if nv ~= self.val then self.val = nv; self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end end
        end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + 4)
        self._d.label.Color = (trackHit or self._drag) and pal.text or pal.textSub
        local vs = tostring(self.val) .. self.suf
        self._d.valTxt.Text = vs
        self._d.valTxt.Position = Vector2.new(px + w - #vs * 5.5 - 6, py + 5)
        self._d.track.Position = Vector2.new(tx, ty); self._d.track.Size = Vector2.new(tw, sz.sliderH); self._d.track.Color = pal.borderDim
        local fw = math.max(2, math.floor(tw * self._a))
        self._d.fill.Position = Vector2.new(tx, ty); self._d.fill.Size = Vector2.new(fw, sz.sliderH); self._d.fill.Color = pal.accent
        local kx = tx + tw * self._a
        self._d.knob.Position = Vector2.new(kx, ty + sz.sliderH / 2)
        self._d.knob.Color = self._drag and pal.accentLit or (trackHit and pal.text or pal.textSub)
    end

    function e:destroy() for _,d in pairs(self._d) do kill(d) end end
    return e
end

local function mkButton(o)
    local e = {
        type = "button", name = o.Name or "button",
        cb = o.Callback or function()end, h = sz.elemH, _ha = 0, _d = {},
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
        self._ha = lerp(self._ha, hov and 1 or 0, 0.14)
        if hov and mClick then self.cb() end
        self._d.bg.Position = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh)
        self._d.bg.Color = lc(pal.panel, pal.hover, self._ha)
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color = lc(pal.borderDim, pal.accent, self._ha * 0.5)
        self._d.label.Position = Vector2.new(bx + bw/2, by + (bh - sz.font)/2 - 1)
        self._d.label.Color = lc(pal.textSub, pal.text, self._ha)
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
        self._d.label.Text = self.text
        self._d.label.Position = Vector2.new(px + 8, py + 2)
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
    end
    function e:destroy() kill(self._d.line) end
    return e
end

local function mkDropdown(o, flags)
    local e = {
        type = "dropdown", name = o.Name or "dropdown",
        opts = o.Options or {}, val = o.Default or (o.Options and o.Options[1] or ""),
        cb = o.Callback or function()end, flag = o.Flag,
        h = sz.elemH, _open = false, _d = {}, _od = {}, _ob = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.valTxt = newLabel({ Size = sz.fontSm, ZIndex = 30 })
    e._d.box = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.boxOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.arrow = newTri({ ZIndex = 30 })
    e._d.panBg = newRect({ Rounding = 3, ZIndex = 60 })
    e._d.panOut = newRect({ Filled = false, Rounding = 3, ZIndex = 60 })

    local function buildOpts(self)
        for i = 1, #self._od do kill(self._od[i]); kill(self._ob[i]) end
        self._od, self._ob = {}, {}
        for i = 1, #self.opts do
            self._od[i] = newLabel({ Size = sz.fontSm, ZIndex = 62 })
            self._ob[i] = newRect({ Rounding = 2, ZIndex = 61 })
        end
    end
    buildOpts(e)

    function e:set(v) self.val = v; self.cb(v); if self.flag and flags then flags[self.flag] = v end end
    function e:refresh(newOpts) self.opts = newOpts; buildOpts(self) end

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then
            for i = 1, #self._od do self._od[i].Visible = false; self._ob[i].Visible = false end
            return
        end
        local bw = math.min(140, w * 0.45)
        local bh = sz.elemH - 6
        local bx = px + w - bw - 6
        local by = py + 3
        local hov = hit(mx, my, bx, by, bw, bh)
        if hov and mClick then self._open = not self._open end

        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color = hov and pal.text or pal.textSub
        self._d.box.Position = Vector2.new(bx, by); self._d.box.Size = Vector2.new(bw, bh)
        self._d.box.Color = hov and pal.hover or pal.panel
        self._d.boxOut.Position = Vector2.new(bx, by); self._d.boxOut.Size = Vector2.new(bw, bh)
        self._d.boxOut.Color = pal.borderDim
        self._d.valTxt.Text = tostring(self.val)
        self._d.valTxt.Position = Vector2.new(bx + 6, by + (bh - sz.fontSm)/2 - 1)

        local ax = bx + bw - 12
        local ay = by + bh/2
        local s = 4
        if self._open then
            self._d.arrow.PointA = Vector2.new(ax-s, ay+2); self._d.arrow.PointB = Vector2.new(ax+s, ay+2); self._d.arrow.PointC = Vector2.new(ax, ay-2)
        else
            self._d.arrow.PointA = Vector2.new(ax-s, ay-2); self._d.arrow.PointB = Vector2.new(ax+s, ay-2); self._d.arrow.PointC = Vector2.new(ax, ay+2)
        end
        self._d.arrow.Color = pal.textDim

        if self._open then
            local oh = 22
            local ph = #self.opts * oh + 4
            local ppx, ppy = bx, by + bh + 2
            self._d.panBg.Visible = true; self._d.panOut.Visible = true
            self._d.panBg.Position = Vector2.new(ppx, ppy); self._d.panBg.Size = Vector2.new(bw, ph); self._d.panBg.Color = pal.bgDeep
            self._d.panOut.Position = Vector2.new(ppx, ppy); self._d.panOut.Size = Vector2.new(bw, ph); self._d.panOut.Color = pal.border
            local outside = mClick and not hit(mx, my, ppx, ppy, bw, ph) and not hov
            for i, opt in ipairs(self.opts) do
                local ox = ppx + 2
                local oy = ppy + 2 + (i-1)*oh
                local ow, ooh = bw - 4, oh
                local oHov = hit(mx, my, ox, oy, ow, ooh)
                self._ob[i].Visible = true; self._ob[i].Position = Vector2.new(ox, oy); self._ob[i].Size = Vector2.new(ow, ooh)
                self._ob[i].Color = oHov and pal.hover or (opt == self.val and pal.panelLit or pal.bgDeep)
                self._od[i].Visible = true; self._od[i].Text = opt
                self._od[i].Position = Vector2.new(ox + 6, oy + (ooh - sz.fontSm)/2 - 1)
                self._od[i].Color = opt == self.val and pal.accent or (oHov and pal.text or pal.textSub)
                if oHov and mClick then
                    self.val = opt; self._open = false; self.cb(opt)
                    if self.flag and flags then flags[self.flag] = opt end
                end
            end
            if outside then self._open = false end
        else
            self._d.panBg.Visible = false; self._d.panOut.Visible = false
            for i = 1, #self._od do self._od[i].Visible = false; self._ob[i].Visible = false end
        end
    end

    function e:destroy()
        for _,d in pairs(self._d) do kill(d) end
        for i = 1, #self._od do kill(self._od[i]); kill(self._ob[i]) end
    end
    return e
end

local function mkKeybind(o, flags)
    local e = {
        type = "keybind", name = o.Name or "keybind",
        val = o.Default or Enum.KeyCode.Unknown,
        cb = o.Callback or function()end, flag = o.Flag,
        h = sz.elemH, _listen = false, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.keyTxt = newLabel({ Size = sz.fontXs, Center = true, ZIndex = 30 })

    local kconn
    function e:set(k) self.val = k; if self.flag and flags then flags[self.flag] = k end end

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local kn = self._listen and "..." or (self.val and self.val.Name or "None")
        local kw = math.max(42, #kn * 6 + 16)
        local kh = sz.elemH - 10
        local kx = px + w - kw - 6
        local ky = py + 5
        local hov = hit(mx, my, kx, ky, kw, kh)
        if hov and mClick and not self._listen then
            self._listen = true
            if kconn then kconn:Disconnect() end
            kconn = UIS.InputBegan:Connect(function(io, gp)
                if gp then return end
                if io.UserInputType == Enum.UserInputType.Keyboard then
                    self.val = io.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or io.KeyCode
                    self._listen = false
                    if self.flag and flags then flags[self.flag] = self.val end
                    if kconn then kconn:Disconnect(); kconn = nil end
                end
            end)
        end
        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color = pal.textSub
        self._d.bg.Position = Vector2.new(kx, ky); self._d.bg.Size = Vector2.new(kw, kh)
        self._d.bg.Color = self._listen and pal.press or (hov and pal.hover or pal.panel)
        self._d.bgOut.Position = Vector2.new(kx, ky); self._d.bgOut.Size = Vector2.new(kw, kh)
        self._d.bgOut.Color = self._listen and pal.accent or pal.borderDim
        self._d.keyTxt.Text = kn
        self._d.keyTxt.Position = Vector2.new(kx + kw/2, ky + (kh - sz.fontXs)/2 - 1)
        self._d.keyTxt.Color = self._listen and pal.accent or pal.textDim
    end

    -- fire callback on press
    table.insert(bliss._connections, UIS.InputBegan:Connect(function(io, gp)
        if gp or e._listen then return end
        if io.KeyCode == e.val then e.cb() end
    end))

    function e:destroy()
        for _,d in pairs(self._d) do kill(d) end
        if kconn then kconn:Disconnect() end
    end
    return e
end

local function mkTextbox(o, flags)
    local e = {
        type = "textbox", name = o.Name or "textbox",
        val = o.Default or "", ph = o.Placeholder or "type here...",
        cb = o.Callback or function()end, flag = o.Flag,
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
        if mClick then
            local was = self._focus
            self._focus = hov
            if self._focus and not was then
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
        self._d.bg.Position = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh); self._d.bg.Color = pal.bgDeep
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color = self._focus and pal.accent or (hov and pal.borderLit or pal.borderDim)
        local dt = #self.val > 0 and self.val or self.ph
        self._d.txt.Text = dt; self._d.txt.Position = Vector2.new(bx + 6, by + (bh - sz.fontSm)/2 - 1)
        self._d.txt.Color = #self.val > 0 and pal.text or pal.textDim
        if self._focus then
            self._blink = (self._blink + 1) % 60
            self._d.cur.Visible = self._blink < 35
            local cx = bx + 6 + #self.val * 5.8
            self._d.cur.From = Vector2.new(cx, by + 3); self._d.cur.To = Vector2.new(cx, by + bh - 3)
        else
            self._d.cur.Visible = false
        end
    end

    -- char input
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
        for _,d in pairs(self._d) do kill(d) end
        if cconn then cconn:Disconnect() end
    end
    return e
end

local function mkColorPicker(o, flags)
    local e = {
        type = "color", name = o.Name or "color",
        val = o.Default or Color3.new(1,1,1),
        cb = o.Callback or function()end, flag = o.Flag,
        h = sz.elemH, _open = false, _dSV = false, _dH = false,
        _hue = 0, _sat = 1, _bri = 1, _d = {},
    }
    -- init hsv from default
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
    e._d.hBar = newRect({ Rounding = 2, ZIndex = 61 })
    e._d.hCur = newRect({ Rounding = 2, ZIndex = 62 })

    function e:set(c) self.val = c; self.cb(c); if self.flag and flags then flags[self.flag] = c end end

    function e:draw(px, py, w, vis)
        for _,d in pairs(self._d) do d.Visible = vis end
        if not vis then
            self._d.panBg.Visible = false; self._d.panOut.Visible = false
            self._d.svBox.Visible = false; self._d.svDot.Visible = false
            self._d.hBar.Visible = false; self._d.hCur.Visible = false
            return
        end
        local cs = sz.colorBox
        local cx = px + w - cs - 10
        local cy = py + (sz.elemH - cs)/2
        local hov = hit(mx, my, cx, cy, cs, cs)
        if hov and mClick then self._open = not self._open end

        self._d.label.Text = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color = pal.textSub
        self._d.prev.Position = Vector2.new(cx, cy); self._d.prev.Size = Vector2.new(cs, cs); self._d.prev.Color = self.val
        self._d.prevOut.Position = Vector2.new(cx, cy); self._d.prevOut.Size = Vector2.new(cs, cs); self._d.prevOut.Color = pal.borderDim

        local show = self._open
        self._d.panBg.Visible = show; self._d.panOut.Visible = show
        self._d.svBox.Visible = show; self._d.svDot.Visible = show
        self._d.hBar.Visible = show; self._d.hCur.Visible = show

        if show then
            local pw, ph = 160, 120
            local ppx = cx + cs - pw
            local ppy = cy + cs + 4
            self._d.panBg.Position = Vector2.new(ppx, ppy); self._d.panBg.Size = Vector2.new(pw, ph); self._d.panBg.Color = pal.bgDeep
            self._d.panOut.Position = Vector2.new(ppx, ppy); self._d.panOut.Size = Vector2.new(pw, ph); self._d.panOut.Color = pal.border

            local sx, sy = ppx + 6, ppy + 6
            local sw, sh = pw - 26, ph - 12
            self._d.svBox.Position = Vector2.new(sx, sy); self._d.svBox.Size = Vector2.new(sw, sh)
            self._d.svBox.Color = Color3.fromHSV(self._hue, 1, 1)

            if hit(mx, my, sx, sy, sw, sh) and mClick then self._dSV = true end
            if not mDown then self._dSV = false end
            if self._dSV then
                self._sat = clamp((mx - sx)/sw, 0, 1)
                self._bri = 1 - clamp((my - sy)/sh, 0, 1)
                self.val = Color3.fromHSV(self._hue, self._sat, self._bri)
                self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end
            end
            self._d.svDot.Position = Vector2.new(sx + self._sat*sw, sy + (1-self._bri)*sh)
            self._d.svDot.Color = pal.text

            local hx, hy = ppx + pw - 16, ppy + 6
            local hh = ph - 12
            self._d.hBar.Position = Vector2.new(hx, hy); self._d.hBar.Size = Vector2.new(8, hh)
            self._d.hBar.Color = Color3.fromHSV(self._hue, 1, 1)

            if hit(mx, my, hx, hy, 8, hh) and mClick then self._dH = true end
            if not mDown then self._dH = false end
            if self._dH then
                self._hue = clamp((my - hy)/hh, 0, 0.999)
                self.val = Color3.fromHSV(self._hue, self._sat, self._bri)
                self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end
            end
            self._d.hCur.Position = Vector2.new(hx - 1, hy + self._hue*hh - 2)
            self._d.hCur.Size = Vector2.new(10, 4); self._d.hCur.Color = pal.text

            if mClick and not hit(mx, my, ppx, ppy, pw, ph) and not hov and not self._dSV and not self._dH then
                self._open = false
            end
        end
    end

    function e:destroy() for _,d in pairs(self._d) do kill(d) end end
    return e
end

-- ══════════════════════════════════════
--  Tab
-- ══════════════════════════════════════

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

-- ══════════════════════════════════════
--  Window
-- ══════════════════════════════════════

local Window = {}
Window.__index = Window

function Window:AddTab(o)
    o = o or {}
    local tab = setmetatable({
        name = o.Name or "tab", icon = o.Icon or "·",
        _elems = {}, _scroll = 0, _win = self,
    }, Tab)

    -- tab button drawings, created AFTER window chrome
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

-- ══════════════════════════════════════
--  render
-- ══════════════════════════════════════

local function renderWin(w)
    local show = w._vis and bliss._visible
    local p = w._pos
    local ww, wh = w._sz.X, w._sz.Y

    -- drag
    if hit(mx, my, p.X, p.Y, ww, sz.titleH) and mClick and not w._drag then
        w._drag = true; w._dOff = Vector2.new(mx - p.X, my - p.Y)
    end
    if not mDown then w._drag = false end
    if w._drag then
        w._pos = Vector2.new(mx - w._dOff.X, my - w._dOff.Y)
        p = w._pos
    end

    -- window chrome
    local d = w._draw
    for _, obj in pairs(d) do obj.Visible = show end
    if not show then
        for _, td in ipairs(w._tabDraw) do for _, obj in pairs(td) do obj.Visible = false end end
        for _, tab in ipairs(w._tabs) do for _, el in ipairs(tab._elems) do el:draw(0, 0, 0, false) end end
        return
    end

    d.bg.Position = p; d.bg.Size = Vector2.new(ww, wh); d.bg.Color = pal.bg
    d.bgOut.Position = p; d.bgOut.Size = Vector2.new(ww, wh); d.bgOut.Color = pal.border
    d.title.Position = p; d.title.Size = Vector2.new(ww, sz.titleH); d.title.Color = pal.panel
    d.titleDiv.From = Vector2.new(p.X, p.Y + sz.titleH); d.titleDiv.To = Vector2.new(p.X + ww, p.Y + sz.titleH)
    d.dot.Position = Vector2.new(p.X + 13, p.Y + sz.titleH/2)
    d.name.Position = Vector2.new(p.X + 24, p.Y + (sz.titleH - sz.font)/2 - 1); d.name.Text = w._name
    d.slogan.Position = Vector2.new(p.X + ww - 72, p.Y + (sz.titleH - sz.fontXs)/2)
    d.side.Position = Vector2.new(p.X, p.Y + sz.titleH); d.side.Size = Vector2.new(sz.tabW, wh - sz.titleH); d.side.Color = pal.bgDeep
    d.sideDiv.From = Vector2.new(p.X + sz.tabW, p.Y + sz.titleH); d.sideDiv.To = Vector2.new(p.X + sz.tabW, p.Y + wh)

    -- tabs
    local sideY = p.Y + sz.titleH
    for i, td in ipairs(w._tabDraw) do
        local act = (i == w._active)
        local ty = sideY + 8 + (i-1)*30
        local tx = p.X + 6
        local tw = sz.tabW - 12
        local th = 26
        local hov = hit(mx, my, tx, ty, tw, th)
        if hov and mClick then w._active = i end
        for _, obj in pairs(td) do obj.Visible = show end
        td.bg.Position = Vector2.new(tx, ty); td.bg.Size = Vector2.new(tw, th)
        td.bg.Color = act and pal.panelLit or (hov and pal.hover or pal.bgDeep)
        td.icon.Position = Vector2.new(tx + 11, ty + (th - sz.fontSm)/2 - 1)
        td.icon.Color = act and pal.accent or pal.textDim
        td.icon.Text = w._tabs[i].icon
        td.label.Position = Vector2.new(tx + 24, ty + (th - sz.fontSm)/2 - 1)
        td.label.Color = act and pal.text or (hov and pal.textSub or pal.textDim)
        td.label.Text = w._tabs[i].name
        td.bar.Position = Vector2.new(tx + 1, ty + 5); td.bar.Size = Vector2.new(2, 16)
        td.bar.Visible = show and act
    end

    -- content
    local cx = p.X + sz.tabW + 1
    local cy = p.Y + sz.titleH + 1
    local cw = ww - sz.tabW - 2
    local ch = wh - sz.titleH - 2

    d.contentDiv.From = Vector2.new(cx, cy); d.contentDiv.To = Vector2.new(cx + cw, cy)

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

        -- scrollbar
        if totalH > ch then
            local ratio = at._scroll / (totalH - ch + 14)
            local bh = math.max(20, (ch/totalH)*ch)
            local by = cy + ratio * (ch - bh)
            d.scroll.Visible = true
            d.scroll.Position = Vector2.new(cx + cw - 4, by); d.scroll.Size = Vector2.new(2, bh)
        else
            d.scroll.Visible = false
        end
    end

    -- hide inactive tabs
    for i, tab in ipairs(w._tabs) do
        if i ~= w._active then
            for _, el in ipairs(tab._elems) do el:draw(0, 0, 0, false) end
        end
    end
end

-- ══════════════════════════════════════
--  bliss.new — builds window chrome FIRST
-- ══════════════════════════════════════

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

    -- window chrome created HERE, before any elements
    -- so elements (created in AddToggle etc) are always on top by creation order
    local d = {
        bg       = newRect({ Rounding = sz.round, ZIndex = 1 }),
        bgOut    = newRect({ Filled = false, Rounding = sz.round, ZIndex = 1 }),
        title    = newRect({ ZIndex = 2 }),
        titleDiv = newLine({ Color = pal.borderDim, ZIndex = 3 }),
        dot      = newDot({ Color = pal.accent, Radius = 3, NumSides = 16, ZIndex = 4 }),
        name     = newLabel({ Color = pal.text, Size = sz.font, ZIndex = 4 }),
        slogan   = newLabel({ Text = "stay blissful!", Color = pal.textDim, Size = sz.fontXs, Font = 3, ZIndex = 4 }),
        side     = newRect({ ZIndex = 2 }),
        sideDiv  = newLine({ Color = pal.borderDim, ZIndex = 3 }),
        contentDiv = newLine({ Color = pal.borderDim, ZIndex = 3, Transparency = 0.5 }),
        scroll   = newRect({ Color = pal.borderDim, Rounding = 2, ZIndex = 25 }),
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

-- ══════════════════════════════════════
--  public api
-- ══════════════════════════════════════

function bliss:UIProperties(name, visible)
    local w = self._windows[name]
    if w then w._vis = visible end
end

function bliss:GetFlag(name, flag)
    local w = self._windows[name]
    return w and w._flags and w._flags[flag]
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
    for _, c in ipairs(self._connections) do pcall(c.Disconnect, c) end
    self._connections = {}
end

-- render loop

table.insert(bliss._connections, RS.RenderStepped:Connect(function()
    for _, w in pairs(bliss._windows) do
        renderWin(w)
    end
    mClick = false
    mScroll = 0
end))

-- stay blissful!
return bliss
