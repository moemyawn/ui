local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local GS = game:GetService("GuiService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local global = (getglobal and getglobal()) or _G
local bliss_key = tostring(crypt.base64encode(tostring(game.PlaceId)))
local pb = global[bliss_key]
if type(pb) == "table" and pb.DestroyAll then
    pcall(function() pb:DestroyAll() end)
end

local bliss = {}
bliss._windows = {}
bliss._connections = {}
bliss._visible = true
bliss._toggleKey = Enum.KeyCode.Equals
bliss._notifs = {}
bliss._tooltipText = nil
bliss._tooltipTimer = 0
bliss._loadDone = false
bliss._loadTime = 0
bliss._themes = {}
bliss._activeTheme = nil
bliss._spacing = "default"
bliss._watermark = nil

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
    faded       = Color3.fromRGB(235, 135, 145),
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
    font       = 15,
    fontSm     = 13,
    fontXs     = 11,
    round      = 4,
    sliderH    = 4,
    toggleW    = 34,
    toggleH    = 16,
    colorBox   = 14,
}

local spacingPresets = {
    compact = { elemH = 24, elemGap = 3, pad = 5 },
    default = { elemH = 30, elemGap = 5, pad = 8 },
    wide    = { elemH = 38, elemGap = 8, pad = 12 },
}

local function applySpacing(preset)
    local p = spacingPresets[preset] or spacingPresets.default
    sz.elemH  = p.elemH
    sz.elemGap = p.elemGap
    sz.pad    = p.pad
end

local function setProp(obj, key, value)
    if value == nil then return end
    pcall(function() obj[key] = value end)
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

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function lc(a, b, t) return Color3.new(lerp(a.R,b.R,t), lerp(a.G,b.G,t), lerp(a.B,b.B,t)) end
local function hit(mx, my, x, y, w, h) return mx>=x and mx<=x+w and my>=y and my<=y+h end
local function snap(n, s) s = s or 1; return math.floor(n/s+0.5)*s end
local function easeOut(t) return 1 - (1-t)^3 end
local function easeInOut(t) return t < 0.5 and 4*t*t*t or 1 - (-2*t+2)^3/2 end

local mx, my, mDown, mClick, mScroll = 0, 0, false, false, 0
local insetY = 0
pcall(function()
    local _, inset = GS:GetGuiInset()
    insetY = inset.Y or 0
end)

local _tooltipDraw = nil
local function ensureTooltip()
    if _tooltipDraw then return end
    _tooltipDraw = {
        bg  = newRect({ Rounding = 3, ZIndex = 200 }),
        out = newRect({ Filled = false, Rounding = 3, ZIndex = 200 }),
        txt = newLabel({ Size = sz.fontXs, ZIndex = 201, Outline = true }),
    }
end

local function drawTooltip(text, tx, ty)
    ensureTooltip()
    local tw = #text * 5.2 + 12
    local th = 16
    local bx = clamp(tx, 2, 9999)
    local by = ty - th - 4
    _tooltipDraw.bg.Visible  = true
    _tooltipDraw.out.Visible = true
    _tooltipDraw.txt.Visible = true
    _tooltipDraw.bg.Position  = Vector2.new(bx, by)
    _tooltipDraw.bg.Size      = Vector2.new(tw, th)
    _tooltipDraw.bg.Color     = pal.bgDeep
    _tooltipDraw.out.Position = Vector2.new(bx, by)
    _tooltipDraw.out.Size     = Vector2.new(tw, th)
    _tooltipDraw.out.Color    = pal.accent
    _tooltipDraw.txt.Text     = text
    _tooltipDraw.txt.Position = Vector2.new(bx + 6, by + (th - sz.fontXs)/2 - 1)
    _tooltipDraw.txt.Color    = pal.text
end

local function hideTooltip()
    if not _tooltipDraw then return end
    _tooltipDraw.bg.Visible  = false
    _tooltipDraw.out.Visible = false
    _tooltipDraw.txt.Visible = false
end

local _loadScreen = nil
local function ensureLoadScreen()
    if _loadScreen then return end
    _loadScreen = {
        bg     = newRect({ ZIndex = 999, Color = pal.bgDeep }),
        panel  = newRect({ ZIndex = 1000, Rounding = 6 }),
        panOut = newRect({ ZIndex = 1000, Filled = false, Rounding = 6 }),
        bar    = newRect({ ZIndex = 1001, Rounding = 2 }),
        barBg  = newRect({ ZIndex = 1000, Rounding = 2 }),
        txt    = newLabel({ ZIndex = 1002, Size = sz.font }),
        sub    = newLabel({ ZIndex = 1002, Size = sz.fontXs, Color = pal.textDim }),
        dot1   = newDot({ ZIndex = 1002, Radius = 3, NumSides = 16 }),
        dot2   = newDot({ ZIndex = 1002, Radius = 3, NumSides = 16 }),
        dot3   = newDot({ ZIndex = 1002, Radius = 3, NumSides = 16 }),
        glowL1 = newRect({ ZIndex = 998, Rounding = 8, Filled = true }),
        glowL2 = newRect({ ZIndex = 997, Rounding = 12, Filled = true }),
        glowL3 = newRect({ ZIndex = 996, Rounding = 16, Filled = true }),
    }
end
local _loadT       = 0
local _loadDismiss = false
local _loadReady   = false
local _loadFading  = false
local _loadFadeT   = 0

local function updateLoadScreen(dt, cam)
    ensureLoadScreen()
    _loadT = _loadT + dt

    local minDuration = 2.25
    local fadeInDur   = 0.45
    local animDone    = _loadT >= minDuration

    local vp = cam.ViewportSize
    local cx, cy = vp.X/2, vp.Y/2
    local pw, ph = 260, 110

    local slideIn = easeOut(math.min(1, _loadT / 0.35))
    local fadeIn  = math.min(1, _loadT / fadeInDur)

    if fadeIn >= 1 and not _loadReady then
        _loadReady = true
    end

    if _loadFading then
        _loadFadeT = _loadFadeT + dt
        local t = math.min(1, _loadFadeT / 0.55)
        local inv = 1 - easeInOut(t)
        for _, d in pairs(_loadScreen) do
            pcall(function() d.Transparency = inv; d.Visible = inv > 0.01 end)
        end
        if t >= 1 then
            for _, d in pairs(_loadScreen) do d.Visible = false end
            bliss._loadDone = true
        end
        return
    end

    if animDone and _loadDismiss and not _loadFading then
        _loadFading = true
        _loadFadeT  = 0
        return
    end

    local panY = cy - ph/2 + (1 - slideIn) * 30

    _loadScreen.bg.Visible      = true
    _loadScreen.bg.Position     = Vector2.new(0, 0)
    _loadScreen.bg.Size         = Vector2.new(vp.X, vp.Y)
    _loadScreen.bg.Color        = pal.bgDeep
    _loadScreen.bg.Transparency = fadeIn

    local glowA = math.abs(math.sin(_loadT * 1.4)) * 0.08
    local glowC = pal.accent
    _loadScreen.glowL3.Visible = true; _loadScreen.glowL2.Visible = true; _loadScreen.glowL1.Visible = true
    local function setGlow(g, pad, alpha)
        g.Position     = Vector2.new(cx - pw/2 - pad, panY - pad)
        g.Size         = Vector2.new(pw + pad*2, ph + pad*2)
        g.Color        = glowC
        g.Transparency = alpha * slideIn
    end
    setGlow(_loadScreen.glowL3, 14, glowA * 0.3)
    setGlow(_loadScreen.glowL2, 8,  glowA * 0.55)
    setGlow(_loadScreen.glowL1, 3,  glowA * 0.8)

    _loadScreen.panel.Visible      = true
    _loadScreen.panel.Position     = Vector2.new(cx - pw/2, panY)
    _loadScreen.panel.Size         = Vector2.new(pw, ph)
    _loadScreen.panel.Color        = pal.panel
    _loadScreen.panel.Transparency = slideIn

    _loadScreen.panOut.Visible      = true
    _loadScreen.panOut.Position     = Vector2.new(cx - pw/2, panY)
    _loadScreen.panOut.Size         = Vector2.new(pw, ph)
    _loadScreen.panOut.Color        = pal.border
    _loadScreen.panOut.Transparency = slideIn

    _loadScreen.txt.Visible      = slideIn > 0.5
    _loadScreen.txt.Text         = "bliss"
    _loadScreen.txt.Center       = true
    _loadScreen.txt.Position     = Vector2.new(cx, panY + 18)
    _loadScreen.txt.Color        = pal.text
    _loadScreen.txt.Transparency = math.min(1, (slideIn - 0.5) * 2)

    _loadScreen.sub.Visible      = slideIn > 0.6
    _loadScreen.sub.Text         = "stay blissful!"
    _loadScreen.sub.Center       = true
    _loadScreen.sub.Position     = Vector2.new(cx, panY + 34)
    _loadScreen.sub.Color        = pal.textDim
    _loadScreen.sub.Transparency = math.min(1, (slideIn - 0.6) * 2.5)

    local barW = pw - 40
    local barX = cx - barW/2
    local barY = panY + 58
    local prog = easeInOut(math.min(1, _loadT / (minDuration * 0.9)))

    _loadScreen.barBg.Visible      = slideIn > 0.4
    _loadScreen.barBg.Position     = Vector2.new(barX, barY)
    _loadScreen.barBg.Size         = Vector2.new(barW, 4)
    _loadScreen.barBg.Color        = pal.borderDim
    _loadScreen.barBg.Rounding     = 2
    _loadScreen.barBg.Transparency = math.min(1, (slideIn - 0.4) * 1.7)

    _loadScreen.bar.Visible      = slideIn > 0.4
    _loadScreen.bar.Position     = Vector2.new(barX, barY)
    _loadScreen.bar.Size         = Vector2.new(math.max(4, barW * prog), 4)
    _loadScreen.bar.Color        = pal.accent
    _loadScreen.bar.Rounding     = 2
    _loadScreen.bar.Transparency = math.min(1, (slideIn - 0.4) * 1.7)

    local dotY = panY + 80
    local dOff = { -18, 0, 18 }
    local dots = { _loadScreen.dot1, _loadScreen.dot2, _loadScreen.dot3 }
    for i, dot in ipairs(dots) do
        dot.Visible      = slideIn > 0.5
        dot.Position     = Vector2.new(cx + dOff[i], dotY + math.sin(_loadT * 4 + (i-1)*1.2) * 2)
        dot.Color        = lc(pal.textDim, pal.accent, (math.sin(_loadT*3 + (i-1)*1.2) + 1)/2)
        dot.Transparency = math.min(1, (slideIn - 0.5) * 2)
    end
end

local function mkGlowBorder(zBase)
    return {
        g1 = newRect({ Filled = false, Rounding = sz.round + 3, ZIndex = zBase - 1 }),
        g2 = newRect({ Filled = false, Rounding = sz.round + 6, ZIndex = zBase - 2 }),
        g3 = newRect({ Filled = false, Rounding = sz.round + 10, ZIndex = zBase - 3 }),
    }
end

local function drawGlowBorder(g, px, py, ww, wh, col, strength)
    local s = strength or 0.18
    local pads = {2, 5, 9}
    local alphas = {s, s*0.5, s*0.22}
    local gs = {g.g1, g.g2, g.g3}
    for i = 1, 3 do
        local pad = pads[i]
        gs[i].Visible   = true
        gs[i].Position  = Vector2.new(px - pad, py - pad)
        gs[i].Size      = Vector2.new(ww + pad*2, wh + pad*2)
        gs[i].Color     = col
        gs[i].Thickness = 1
        gs[i].Transparency = alphas[i]
    end
end

local function hideGlowBorder(g)
    g.g1.Visible = false; g.g2.Visible = false; g.g3.Visible = false
end

local function kill(d)
    if not d then return end
    pcall(function()
        if d.Remove then d:Remove()
        elseif d.Destroy then d:Destroy() end
    end)
end

local function mkNotif(opts)
    local n = {
        title   = opts.Title or "notification",
        msg     = opts.Message or "",
        kind    = opts.Type or "info",
        dur     = opts.Duration or 3.5,
        _t      = 0,
        _a      = 0,
        _dead   = false,
        _d      = {},
    }
    local z = 150
    n._d.bg     = newRect({ Rounding = 4, ZIndex = z })
    n._d.bgOut  = newRect({ Filled = false, Rounding = 4, ZIndex = z })
    n._d.accent = newRect({ Rounding = 2, ZIndex = z + 1 })
    n._d.title  = newLabel({ Size = sz.fontSm, ZIndex = z + 2 })
    n._d.msg    = newLabel({ Size = sz.fontXs, ZIndex = z + 2 })
    n._d.g1     = newRect({ Filled = false, Rounding = 6, ZIndex = z - 1 })
    n._d.g2     = newRect({ Filled = false, Rounding = 9, ZIndex = z - 2 })
    return n
end

local function updateNotifs(dt, cam)
    local vp = cam.ViewportSize
    local baseX = vp.X - 230
    local baseY = vp.Y - 20
    local alive = {}
    for _, n in ipairs(bliss._notifs) do
        n._t = n._t + dt
        local tgt = (n._t < n.dur) and 1 or 0
        n._a = lerp(n._a, tgt, n._t < n.dur and 0.14 or 0.1)
        if n._a < 0.01 and n._t >= n.dur then
            for _, d in pairs(n._d) do kill(d) end
            n._dead = true
        else
            alive[#alive+1] = n
        end
    end
    bliss._notifs = alive

    local offsetY = 0
    for i = #alive, 1, -1 do
        local n = alive[i]
        local nw, nh = 210, 46
        local nx = baseX + (1 - n._a) * 30
        local ny = baseY - offsetY - nh
        local col = n.kind == "good" and pal.good or (n.kind == "warn" and pal.warn or (n.kind == "bad" and pal.bad or pal.accent))

        for _, d in pairs(n._d) do d.Visible = true; d.Transparency = n._a end

        n._d.g2.Position = Vector2.new(nx - 7, ny - 7)
        n._d.g2.Size     = Vector2.new(nw + 14, nh + 14)
        n._d.g2.Color    = col; n._d.g2.Thickness = 1
        n._d.g2.Transparency = n._a * 0.1

        n._d.g1.Position = Vector2.new(nx - 3, ny - 3)
        n._d.g1.Size     = Vector2.new(nw + 6, nh + 6)
        n._d.g1.Color    = col; n._d.g1.Thickness = 1
        n._d.g1.Transparency = n._a * 0.25

        n._d.bg.Position    = Vector2.new(nx, ny)
        n._d.bg.Size        = Vector2.new(nw, nh)
        n._d.bg.Color       = pal.panel
        n._d.bg.Transparency = n._a

        n._d.bgOut.Position  = Vector2.new(nx, ny)
        n._d.bgOut.Size      = Vector2.new(nw, nh)
        n._d.bgOut.Color     = pal.border
        n._d.bgOut.Transparency = n._a

        n._d.accent.Position  = Vector2.new(nx, ny)
        n._d.accent.Size      = Vector2.new(3, nh)
        n._d.accent.Color     = col
        n._d.accent.Transparency = n._a

        n._d.title.Text      = n.title
        n._d.title.Position  = Vector2.new(nx + 10, ny + 7)
        n._d.title.Color     = pal.text
        n._d.title.Transparency = n._a

        n._d.msg.Text        = n.msg
        n._d.msg.Position    = Vector2.new(nx + 10, ny + 22)
        n._d.msg.Color       = pal.textSub
        n._d.msg.Transparency = n._a

        offsetY = offsetY + nh + 6
    end
end

local function mkWatermark(opts)
    opts = opts or {}
    local wm = {
        enabled = opts.Enabled ~= false,
        posH    = opts.PosX or "right",
        posV    = opts.PosY or "top",
        info    = opts.Info or "{fps} | {username}",
        color   = opts.Color or pal.accent,
        _d      = {},
        _pulse  = 0,
    }
    local z = 120
    wm._d.bg    = newRect({ Rounding = 4, ZIndex = z })
    wm._d.bgOut = newRect({ Filled = false, Rounding = 4, ZIndex = z })
    wm._d.txt   = newLabel({ Size = sz.fontXs, ZIndex = z + 1 })
    wm._d.g1    = newRect({ Filled = false, Rounding = 6, ZIndex = z - 1 })
    wm._d.g2    = newRect({ Filled = false, Rounding = 9, ZIndex = z - 2 })
    return wm
end

local function updateWatermark(wm, dt, cam)
    if not wm or not wm.enabled or not bliss._visible then
        if wm then for _, d in pairs(wm._d) do d.Visible = false end end
        return
    end
    wm._pulse = (wm._pulse + dt * 2.5) % (math.pi * 2)
    local vp = cam.ViewportSize
    local fps = math.floor(1 / (dt + 0.0001))
    local uname = "player"
    pcall(function() uname = Players.LocalPlayer.Name end)
    local txt = wm.info
    txt = txt:gsub("{fps}", tostring(fps))
    txt = txt:gsub("{username}", uname)
    local tw = #txt * 5.2 + 14
    local th = 18
    local px, py
    local margin = 10
    if wm.posH == "left" then px = margin
    elseif wm.posH == "middle" then px = vp.X/2 - tw/2
    else px = vp.X - tw - margin end
    if wm.posV == "bottom" then py = vp.Y - th - margin
    elseif wm.posV == "middle" then py = vp.Y/2 - th/2
    else py = margin end

    local glowA = (math.sin(wm._pulse) * 0.5 + 0.5) * 0.12
    wm._d.g2.Visible = true; wm._d.g1.Visible = true
    wm._d.g2.Position = Vector2.new(px - 7, py - 7); wm._d.g2.Size = Vector2.new(tw + 14, th + 14)
    wm._d.g2.Color = wm.color; wm._d.g2.Thickness = 1; wm._d.g2.Transparency = glowA * 0.4
    wm._d.g1.Position = Vector2.new(px - 3, py - 3); wm._d.g1.Size = Vector2.new(tw + 6, th + 6)
    wm._d.g1.Color = wm.color; wm._d.g1.Thickness = 1; wm._d.g1.Transparency = glowA * 0.7

    for _, d in pairs(wm._d) do d.Visible = true end
    wm._d.bg.Position  = Vector2.new(px, py); wm._d.bg.Size = Vector2.new(tw, th); wm._d.bg.Color = pal.panel
    wm._d.bgOut.Position = Vector2.new(px, py); wm._d.bgOut.Size = Vector2.new(tw, th); wm._d.bgOut.Color = pal.borderDim
    wm._d.txt.Text     = txt
    wm._d.txt.Position = Vector2.new(px + 7, py + (th - sz.fontXs)/2 - 1)
    wm._d.txt.Color    = wm.color
end

local function mkToggle(o, flags)
    local e = {
        type = "toggle", name = o.Name or "toggle",
        val = o.Default or false, cb = typeof(o.Callback) == "function" and o.Callback or function() end,
        flag = o.Flag, tooltip = o.Tooltip,
        h = sz.elemH, _a = 0, _flash = 0, _d = {},
    }
    e._d.label = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg    = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.fill  = newRect({ Rounding = 3, ZIndex = 29, Transparency = 0.35 })
    e._d.dot   = newDot({ Radius = 4, ZIndex = 31 })
    e._d.flash = newRect({ Rounding = 3, ZIndex = 32, Transparency = 0 })

    function e:set(v) self.val = v; self.cb(v); if self.flag and flags then flags[self.flag] = v end end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bw, bh = sz.toggleW, sz.toggleH
        local bx = px + w - bw - 6
        local by = py + (sz.elemH - bh) / 2
        local rowHit = hit(mx, my, px, py, w, sz.elemH)
        if rowHit and mClick then
            self.val = not self.val
            self.cb(self.val)
            if self.flag and flags then flags[self.flag] = self.val end
            self._flash = 1
        end
        self._flash = lerp(self._flash, 0, 0.18)
        local tgt = self.val and 1 or 0
        self._a = lerp(self._a, tgt, 0.16)
        self._d.label.Text     = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color    = rowHit and pal.text or pal.textSub
        self._d.bg.Position    = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh)
        self._d.bg.Color       = lc(pal.panel, pal.accentDim, self._a * 0.35)
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color    = lc(pal.borderDim, pal.accent, self._a)
        local fw = math.floor(bw * self._a)
        self._d.fill.Position  = Vector2.new(bx, by); self._d.fill.Size = Vector2.new(fw, bh)
        self._d.fill.Color     = pal.accent
        local dx = lerp(bx + 8, bx + bw - 8, self._a)
        self._d.dot.Position   = Vector2.new(dx, by + bh/2)
        self._d.dot.Color      = lc(pal.textDim, pal.text, self._a)
        self._d.flash.Position = Vector2.new(bx, by); self._d.flash.Size = Vector2.new(bw, bh)
        self._d.flash.Color    = pal.accent
        self._d.flash.Transparency = math.max(0, self._flash * 0.4)
        if rowHit and self.tooltip then
            bliss._tooltipText = self.tooltip
            bliss._tooltipMx   = mx; bliss._tooltipMy = my
        end
    end

    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local function mkSlider(o, flags)
    local e = {
        type = "slider", name = o.Name or "slider",
        val = o.Default or o.Min or 0, min = o.Min or 0, max = o.Max or 100,
        inc = o.Increment or 1, suf = o.Suffix or "",
        cb = typeof(o.Callback) == "function" and o.Callback or function() end,
        flag = o.Flag, tooltip = o.Tooltip,
        h = sz.elemH + 14, _drag = false, _a = 0, _flash = 0, _d = {},
    }
    e._d.label  = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.valTxt = newLabel({ Size = sz.fontSm, Color = pal.accent, ZIndex = 30 })
    e._d.track  = newRect({ Rounding = 2, ZIndex = 28 })
    e._d.fill   = newRect({ Rounding = 2, ZIndex = 29 })
    e._d.knob   = newDot({ Radius = 5, ZIndex = 31 })
    e._d.flash  = newRect({ Rounding = 2, ZIndex = 32 })

    function e:set(v) self.val = clamp(snap(v, self.inc), self.min, self.max); self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local tx, ty = px + 8, py + sz.elemH + 4
        local tw = w - 20
        local pct = (self.val - self.min) / (self.max - self.min)
        self._a = lerp(self._a, pct, 0.18)
        local trackHit = hit(mx, my, tx, ty - 6, tw, 16)
        if trackHit and mClick then self._drag = true; self._flash = 1 end
        if not mDown then self._drag = false end
        if self._drag then
            local raw = clamp((mx - tx)/tw, 0, 1)
            local nv = clamp(snap(self.min + raw*(self.max-self.min), self.inc), self.min, self.max)
            if nv ~= self.val then self.val = nv; self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end end
        end
        self._flash = lerp(self._flash, 0, 0.14)
        self._d.label.Text     = self.name
        self._d.label.Position = Vector2.new(px + 8, py + 4)
        self._d.label.Color    = (trackHit or self._drag) and pal.text or pal.textSub
        local vs = tostring(self.val) .. self.suf
        self._d.valTxt.Text     = vs
        self._d.valTxt.Position = Vector2.new(px + w - #vs * 5.5 - 6, py + 5)
        self._d.track.Position  = Vector2.new(tx, ty); self._d.track.Size = Vector2.new(tw, sz.sliderH); self._d.track.Color = pal.borderDim
        local fw = math.max(2, math.floor(tw * self._a))
        self._d.fill.Position   = Vector2.new(tx, ty); self._d.fill.Size = Vector2.new(fw, sz.sliderH); self._d.fill.Color = pal.accent
        local kx = tx + tw * self._a
        self._d.knob.Position   = Vector2.new(kx, ty + sz.sliderH/2)
        self._d.knob.Color      = self._drag and pal.accentLit or (trackHit and pal.text or pal.textSub)
        self._d.flash.Position  = Vector2.new(tx, ty); self._d.flash.Size = Vector2.new(fw, sz.sliderH)
        self._d.flash.Color     = pal.accentLit
        self._d.flash.Transparency = math.max(0, self._flash * 0.5)
        if trackHit and self.tooltip then
            bliss._tooltipText = self.tooltip; bliss._tooltipMx = mx; bliss._tooltipMy = my
        end
    end

    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local function mkButton(o)
    local e = {
        type = "button", name = o.Name or "button",
        cb = typeof(o.Callback) == "function" and o.Callback or function() end,
        tooltip = o.Tooltip,
        h = sz.elemH, _ha = 0, _flash = 0, _d = {},
    }
    e._d.bg    = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.bgOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.label = newLabel({ Size = sz.font, Center = true, ZIndex = 30 })
    e._d.flash = newRect({ Rounding = 3, ZIndex = 31 })
    e._d.glow  = newRect({ Filled = false, Rounding = 5, ZIndex = 27 })

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local bx, by = px + 4, py + 2
        local bw, bh = w - 8, sz.elemH - 4
        local hov = hit(mx, my, bx, by, bw, bh)
        self._ha = lerp(self._ha, hov and 1 or 0, 0.14)
        if hov and mClick then self.cb(); self._flash = 1 end
        self._flash = lerp(self._flash, 0, 0.15)
        self._d.bg.Position    = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh)
        self._d.bg.Color       = lc(pal.panel, pal.hover, self._ha)
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color    = lc(pal.borderDim, pal.accent, self._ha * 0.5)
        self._d.flash.Position = Vector2.new(bx, by); self._d.flash.Size = Vector2.new(bw, bh)
        self._d.flash.Color    = pal.accentLit
        self._d.flash.Transparency = math.max(0, self._flash * 0.35)
        self._d.glow.Position  = Vector2.new(bx - 3, by - 3); self._d.glow.Size = Vector2.new(bw + 6, bh + 6)
        self._d.glow.Color     = pal.accent; self._d.glow.Thickness = 1
        self._d.glow.Transparency = math.max(0, (1 - self._ha) * 1 + self._ha * 0.65)
        self._d.label.Text     = self.name
        self._d.label.Position = Vector2.new(bx + bw/2, by + (bh - sz.font)/2 - 1)
        self._d.label.Color    = lc(pal.textSub, pal.text, self._ha)
        if hov and self.tooltip then
            bliss._tooltipText = self.tooltip; bliss._tooltipMx = mx; bliss._tooltipMy = my
        end
    end

    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local function mkLabel(o)
    local e = { type = "label", text = o.Text or "", h = sz.elemH - 8, _d = {} }
    e._d.label = newLabel({ Size = o.Size or sz.fontSm, Color = o.Color or pal.textDim, ZIndex = 30, Font = o.Font or 2 })
    function e:set(t) self.text = t end
    function e:draw(px, py, w, vis)
        self._d.label.Visible  = vis
        if not vis then return end
        self._d.label.Text     = self.text
        self._d.label.Position = Vector2.new(px + 8, py + 2)
    end
    function e:destroy() kill(self._d.label) end
    return e
end

local function mkSeparator(o)
    o = o or {}
    local e = { type = "sep", title = o.Title, h = o.Title and 20 or 10, _d = {} }
    e._d.line  = newLine({ Color = pal.borderDim, ZIndex = 28 })
    e._d.label = o.Title and newLabel({ Size = sz.fontXs, ZIndex = 30, Color = pal.textDim }) or nil
    function e:draw(px, py, w, vis)
        self._d.line.Visible = vis
        if not vis then
            if self._d.label then self._d.label.Visible = false end
            return
        end
        if self.title then
            local tw = #self.title * 5 + 8
            self._d.line.From = Vector2.new(px + 10 + tw + 4, py + 10)
            self._d.line.To   = Vector2.new(px + w - 10, py + 10)
            self._d.label.Visible  = true
            self._d.label.Text     = self.title
            self._d.label.Position = Vector2.new(px + 10, py + 4)
        else
            self._d.line.From = Vector2.new(px + 10, py + 5)
            self._d.line.To   = Vector2.new(px + w - 10, py + 5)
        end
    end
    function e:destroy() kill(self._d.line); if self._d.label then kill(self._d.label) end end
    return e
end

local function mkSectionHeader(o)
    local e = { type = "section", name = o.Name or "", h = 22, _d = {} }
    e._d.bg    = newRect({ ZIndex = 27, Rounding = 2 })
    e._d.label = newLabel({ Size = sz.fontXs, ZIndex = 30, Font = 2 })
    e._d.line  = newLine({ ZIndex = 28 })
    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        self._d.bg.Position    = Vector2.new(px + 4, py + 2)
        self._d.bg.Size        = Vector2.new(w - 8, 18)
        self._d.bg.Color       = pal.panelLit
        self._d.label.Text     = self.name:upper()
        self._d.label.Position = Vector2.new(px + 10, py + 5)
        self._d.label.Color    = pal.textDim
        self._d.line.From      = Vector2.new(px + 4, py + 20)
        self._d.line.To        = Vector2.new(px + w - 4, py + 20)
        self._d.line.Color     = pal.borderDim
    end
    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local function mkDropdown(o, flags)
    local e = {
        type = "dropdown", name = o.Name or "dropdown",
        opts = o.Options or {}, val = o.Default or (o.Options and o.Options[1] or ""),
        cb = typeof(o.Callback) == "function" and o.Callback or function() end,
        flag = o.Flag, tooltip = o.Tooltip,
        h = sz.elemH, _open = false, _openA = 0, _d = {}, _od = {}, _ob = {},
    }
    e._d.label  = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.valTxt = newLabel({ Size = sz.fontSm, ZIndex = 30 })
    e._d.box    = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.boxOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.arrow  = newTri({ ZIndex = 30 })
    e._d.panBg  = newRect({ Rounding = 3, ZIndex = 60 })
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
        for _, d in pairs(self._d) do d.Visible = vis end
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
        self._openA = lerp(self._openA, self._open and 1 or 0, 0.18)

        self._d.label.Text     = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color    = hov and pal.text or pal.textSub
        self._d.box.Position   = Vector2.new(bx, by); self._d.box.Size = Vector2.new(bw, bh)
        self._d.box.Color      = hov and pal.hover or pal.panel
        self._d.boxOut.Position = Vector2.new(bx, by); self._d.boxOut.Size = Vector2.new(bw, bh)
        self._d.boxOut.Color   = pal.borderDim
        self._d.valTxt.Text    = tostring(self.val)
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

        if self._openA > 0.01 then
            local oh = 22
            local ph = #self.opts * oh + 4
            local ph_anim = ph * self._openA
            local ppx, ppy = bx, by + bh + 2
            self._d.panBg.Visible  = true; self._d.panOut.Visible = true
            self._d.panBg.Position = Vector2.new(ppx, ppy); self._d.panBg.Size = Vector2.new(bw, ph_anim); self._d.panBg.Color = pal.bgDeep
            self._d.panOut.Position = Vector2.new(ppx, ppy); self._d.panOut.Size = Vector2.new(bw, ph_anim); self._d.panOut.Color = pal.border
            local outside = mClick and not hit(mx, my, ppx, ppy, bw, ph) and not hov
            for i, opt in ipairs(self.opts) do
                local ox = ppx + 2
                local oy = ppy + 2 + (i-1)*oh
                local ow, ooh = bw - 4, oh
                if oy + ooh <= ppy + ph_anim then
                    local oHov = hit(mx, my, ox, oy, ow, ooh)
                    self._ob[i].Visible  = true; self._ob[i].Position = Vector2.new(ox, oy); self._ob[i].Size = Vector2.new(ow, ooh)
                    self._ob[i].Color    = oHov and pal.hover or (opt == self.val and pal.panelLit or pal.bgDeep)
                    self._od[i].Visible  = true; self._od[i].Text = opt
                    self._od[i].Position = Vector2.new(ox + 6, oy + (ooh - sz.fontSm)/2 - 1)
                    self._od[i].Color    = opt == self.val and pal.accent or (oHov and pal.text or pal.textSub)
                    if oHov and mClick then
                        self.val = opt; self._open = false; self.cb(opt)
                        if self.flag and flags then flags[self.flag] = opt end
                    end
                else
                    self._ob[i].Visible = false; self._od[i].Visible = false
                end
            end
            if outside then self._open = false end
        else
            self._d.panBg.Visible = false; self._d.panOut.Visible = false
            for i = 1, #self._od do self._od[i].Visible = false; self._ob[i].Visible = false end
        end
        if hov and self.tooltip then
            bliss._tooltipText = self.tooltip; bliss._tooltipMx = mx; bliss._tooltipMy = my
        end
    end

    function e:destroy()
        for _, d in pairs(self._d) do kill(d) end
        for i = 1, #self._od do kill(self._od[i]); kill(self._ob[i]) end
    end
    return e
end

local function mkKeybind(o, flags)
    local e = {
        type = "keybind", name = o.Name or "keybind",
        val = typeof(o.Default) == "EnumItem" and o.Default or nil,
        cb = typeof(o.Callback) == "function" and o.Callback or function() end,
        flag = o.Flag, tooltip = o.Tooltip,
        h = sz.elemH, _listen = false, _d = {},
    }
    e._d.label  = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg     = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.bgOut  = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.keyTxt = newLabel({ Size = sz.fontXs, Center = true, ZIndex = 30 })

    local kconn

    function e:set(k)
        self.val = k
        if self.flag and flags then flags[self.flag] = k end
    end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then return end
        local kn = self._listen and "..." or (self.val and self.val.Name or "None")
        local kw = math.max(42, #kn * 6 + 16)
        local kh = sz.elemH - 10
        local kx = px + w - kw - 6
        local ky = py + 5
        local hov = hit(mx, my, kx, ky, kw, kh)
        if hov and mClick and not self._listen then
            self._listen = true
            if kconn then kconn:Disconnect(); kconn = nil end
            kconn = UIS.InputBegan:Connect(function(io, gp)
                if gp then return end
                if io.UserInputType == Enum.UserInputType.Keyboard then
                    local key = (io.KeyCode == Enum.KeyCode.Escape) and nil or io.KeyCode
                    self:set(key)
                    self._listen = false
                    if kconn then kconn:Disconnect(); kconn = nil end
                end
            end)
        end
        self._d.label.Text     = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color    = pal.textSub
        self._d.bg.Position    = Vector2.new(kx, ky); self._d.bg.Size = Vector2.new(kw, kh)
        self._d.bg.Color       = self._listen and pal.press or (hov and pal.hover or pal.panel)
        self._d.bgOut.Position = Vector2.new(kx, ky); self._d.bgOut.Size = Vector2.new(kw, kh)
        self._d.bgOut.Color    = self._listen and pal.accent or pal.borderDim
        self._d.keyTxt.Text    = kn
        self._d.keyTxt.Position = Vector2.new(kx + kw/2, ky + (kh - sz.fontXs)/2 - 1)
        self._d.keyTxt.Color   = self._listen and pal.accent or pal.textDim
        if hov and self.tooltip then
            bliss._tooltipText = self.tooltip; bliss._tooltipMx = mx; bliss._tooltipMy = my
        end
    end

    table.insert(bliss._connections, UIS.InputBegan:Connect(function(io, gp)
        if gp or e._listen then return end
        if io.UserInputType == Enum.UserInputType.Keyboard and e.val and io.KeyCode == e.val then
            e.cb()
        end
    end))

    function e:destroy()
        for _, d in pairs(self._d) do kill(d) end
        if kconn then kconn:Disconnect(); kconn = nil end
    end
    return e
end

local function mkTextbox(o, flags)
    local e = {
        type = "textbox", name = o.Name or "textbox",
        val = o.Default or "", ph = o.Placeholder or "type here",
        cb = typeof(o.Callback) == "function" and o.Callback or function() end,
        flag = o.Flag, tooltip = o.Tooltip,
        h = sz.elemH + 6, _focus = false, _blink = 0, _focusA = 0, _d = {},
    }
    e._d.label  = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.bg     = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.bgOut  = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.glow   = newRect({ Filled = false, Rounding = 5, ZIndex = 27 })
    e._d.txt    = newLabel({ Size = sz.fontSm, ZIndex = 30 })
    e._d.cur    = newLine({ Color = pal.accent, ZIndex = 31 })

    local cconn
    function e:set(v) self.val = v; self.cb(v); if self.flag and flags then flags[self.flag] = v end end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
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
        self._focusA = lerp(self._focusA, self._focus and 1 or 0, 0.15)
        self._d.label.Text     = self.name
        self._d.label.Position = Vector2.new(px + 8, py + 2)
        self._d.bg.Position    = Vector2.new(bx, by); self._d.bg.Size = Vector2.new(bw, bh); self._d.bg.Color = pal.bgDeep
        self._d.bgOut.Position = Vector2.new(bx, by); self._d.bgOut.Size = Vector2.new(bw, bh)
        self._d.bgOut.Color    = lc(hov and pal.borderLit or pal.borderDim, pal.accent, self._focusA)
        self._d.glow.Position  = Vector2.new(bx - 3, by - 3); self._d.glow.Size = Vector2.new(bw + 6, bh + 6)
        self._d.glow.Color     = pal.accent; self._d.glow.Thickness = 1
        self._d.glow.Transparency = math.max(0, 1 - self._focusA * 0.65)
        local dt = #self.val > 0 and self.val or self.ph
        self._d.txt.Text       = dt; self._d.txt.Position = Vector2.new(bx + 6, by + (bh - sz.fontSm)/2 - 1)
        self._d.txt.Color      = #self.val > 0 and pal.text or pal.textDim
        if self._focus then
            self._blink = (self._blink + 1) % 60
            self._d.cur.Visible = self._blink < 35
            local cx = bx + 6 + #self.val * 5.8
            self._d.cur.From   = Vector2.new(cx, by + 3); self._d.cur.To = Vector2.new(cx, by + bh - 3)
        else
            self._d.cur.Visible = false
        end
        if hov and self.tooltip then
            bliss._tooltipText = self.tooltip; bliss._tooltipMx = mx; bliss._tooltipMy = my
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
        val = o.Default or Color3.new(1,1,1),
        cb = typeof(o.Callback) == "function" and o.Callback or function() end,
        flag = o.Flag, tooltip = o.Tooltip,
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

    e._d.label   = newLabel({ Size = sz.font, ZIndex = 30 })
    e._d.prev    = newRect({ Rounding = 3, ZIndex = 28 })
    e._d.prevOut = newRect({ Filled = false, Rounding = 3, ZIndex = 28 })
    e._d.panBg   = newRect({ Rounding = 4, ZIndex = 60 })
    e._d.panOut  = newRect({ Filled = false, Rounding = 4, ZIndex = 60 })
    e._d.svBox   = newRect({ Rounding = 2, ZIndex = 61 })
    e._d.svDot   = newDot({ Filled = false, Radius = 4, Thickness = 2, ZIndex = 63 })
    e._d.hBar    = newRect({ Rounding = 2, ZIndex = 61 })
    e._d.hCur    = newRect({ Rounding = 2, ZIndex = 62 })

    function e:set(c) self.val = c; self.cb(c); if self.flag and flags then flags[self.flag] = c end end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = vis end
        if not vis then
            self._d.panBg.Visible = false; self._d.panOut.Visible = false
            self._d.svBox.Visible = false; self._d.svDot.Visible = false
            self._d.hBar.Visible  = false; self._d.hCur.Visible = false
            return
        end
        local cs = sz.colorBox
        local cx = px + w - cs - 10
        local cy = py + (sz.elemH - cs)/2
        local hov = hit(mx, my, cx, cy, cs, cs)
        if hov and mClick then self._open = not self._open end

        self._d.label.Text     = self.name
        self._d.label.Position = Vector2.new(px + 8, py + (sz.elemH - sz.font)/2 - 1)
        self._d.label.Color    = pal.textSub
        self._d.prev.Position  = Vector2.new(cx, cy); self._d.prev.Size = Vector2.new(cs, cs); self._d.prev.Color = self.val
        self._d.prevOut.Position = Vector2.new(cx, cy); self._d.prevOut.Size = Vector2.new(cs, cs); self._d.prevOut.Color = pal.borderDim

        local show = self._open
        self._d.panBg.Visible = show; self._d.panOut.Visible = show
        self._d.svBox.Visible = show; self._d.svDot.Visible = show
        self._d.hBar.Visible  = show; self._d.hCur.Visible = show

        if show then
            local pw, ph = 160, 120
            local ppx = cx + cs - pw
            local ppy = cy + cs + 4
            self._d.panBg.Position = Vector2.new(ppx, ppy); self._d.panBg.Size = Vector2.new(pw, ph); self._d.panBg.Color = pal.bgDeep
            self._d.panOut.Position = Vector2.new(ppx, ppy); self._d.panOut.Size = Vector2.new(pw, ph); self._d.panOut.Color = pal.border
            local sx, sy = ppx + 6, ppy + 6
            local sw, sh = pw - 26, ph - 12
            self._d.svBox.Position = Vector2.new(sx, sy); self._d.svBox.Size = Vector2.new(sw, sh)
            self._d.svBox.Color    = Color3.fromHSV(self._hue, 1, 1)
            if hit(mx, my, sx, sy, sw, sh) and mClick then self._dSV = true end
            if not mDown then self._dSV = false end
            if self._dSV then
                self._sat = clamp((mx - sx)/sw, 0, 1)
                self._bri = 1 - clamp((my - sy)/sh, 0, 1)
                self.val = Color3.fromHSV(self._hue, self._sat, self._bri)
                self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end
            end
            self._d.svDot.Position = Vector2.new(sx + self._sat*sw, sy + (1-self._bri)*sh)
            self._d.svDot.Color    = pal.text
            local hx, hy = ppx + pw - 16, ppy + 6
            local hh = ph - 12
            self._d.hBar.Position = Vector2.new(hx, hy); self._d.hBar.Size = Vector2.new(8, hh)
            self._d.hBar.Color    = Color3.fromHSV(self._hue, 1, 1)
            if hit(mx, my, hx, hy, 8, hh) and mClick then self._dH = true end
            if not mDown then self._dH = false end
            if self._dH then
                self._hue = clamp((my - hy)/hh, 0, 0.999)
                self.val = Color3.fromHSV(self._hue, self._sat, self._bri)
                self.cb(self.val); if self.flag and flags then flags[self.flag] = self.val end
            end
            self._d.hCur.Position = Vector2.new(hx - 1, hy + self._hue*hh - 2)
            self._d.hCur.Size     = Vector2.new(10, 4); self._d.hCur.Color = pal.text
            if mClick and not hit(mx, my, ppx, ppy, pw, ph) and not hov and not self._dSV and not self._dH then
                self._open = false
            end
        end
        if hov and self.tooltip then
            bliss._tooltipText = self.tooltip; bliss._tooltipMx = mx; bliss._tooltipMy = my
        end
    end

    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local function mkConfigUI(win)
    local e = {
        type = "config", name = "config", h = sz.elemH, _open = false, _openA = 0,
        _nameVal = "", _d = {}, _od = {}, _ob = {},
    }
    local z = 80
    e._d.btn    = newRect({ Rounding = 3, ZIndex = z })
    e._d.btnOut = newRect({ Filled = false, Rounding = 3, ZIndex = z })
    e._d.btnTxt = newLabel({ Size = sz.fontXs, Center = true, ZIndex = z + 1 })
    e._d.panel  = newRect({ Rounding = 4, ZIndex = z + 10 })
    e._d.panOut = newRect({ Filled = false, Rounding = 4, ZIndex = z + 10 })
    e._d.title  = newLabel({ Size = sz.fontSm, ZIndex = z + 11 })
    e._d.saveBtn  = newRect({ Rounding = 3, ZIndex = z + 11 })
    e._d.saveBtnO = newRect({ Filled = false, Rounding = 3, ZIndex = z + 11 })
    e._d.saveTxt  = newLabel({ Size = sz.fontXs, Center = true, ZIndex = z + 12 })
    e._d.loadBtn  = newRect({ Rounding = 3, ZIndex = z + 11 })
    e._d.loadBtnO = newRect({ Filled = false, Rounding = 3, ZIndex = z + 11 })
    e._d.loadTxt  = newLabel({ Size = sz.fontXs, Center = true, ZIndex = z + 12 })
    e._d.inp    = newRect({ Rounding = 3, ZIndex = z + 11 })
    e._d.inpOut = newRect({ Filled = false, Rounding = 3, ZIndex = z + 11 })
    e._d.inpTxt = newLabel({ Size = sz.fontXs, ZIndex = z + 12 })

    local function getConfigs()
        local t = {}
        if not syn or not syn.protected_call then return t end
        pcall(function()
            for _, f in ipairs(listfiles("bliss_configs")) do
                local name = f:match("([^/\\]+)%.json$")
                if name then t[#t+1] = name end
            end
        end)
        return t
    end

    local function saveConfig(name)
        if not name or #name == 0 then return end
        pcall(function()
            if not isfolder("bliss_configs") then makefolder("bliss_configs") end
            local data = {}
            for k, v in pairs(win._flags) do
                if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
                    data[k] = v
                end
            end
            writefile("bliss_configs/" .. name .. ".json", game:GetService("HttpService"):JSONEncode(data))
        end)
    end

    local function loadConfig(name)
        if not name or #name == 0 then return end
        pcall(function()
            local raw = readfile("bliss_configs/" .. name .. ".json")
            local data = game:GetService("HttpService"):JSONDecode(raw)
            for k, v in pairs(data) do
                win._flags[k] = v
                for _, tab in ipairs(win._tabs) do
                    for _, el in ipairs(tab._elems) do
                        if el.flag == k and el.set then
                            pcall(function() el:set(v) end)
                        end
                    end
                end
            end
        end)
    end

    function e:draw(px, py, w, vis)
        for _, d in pairs(self._d) do d.Visible = false end
        if not vis then return end
        local bx, by = px + 4, py + 2
        local bw, bh = w - 8, sz.elemH - 4
        local hov = hit(mx, my, bx, by, bw, bh)
        if hov and mClick then self._open = not self._open end
        self._openA = lerp(self._openA, self._open and 1 or 0, 0.16)

        self._d.btn.Visible    = true
        self._d.btnOut.Visible = true
        self._d.btnTxt.Visible = true
        self._d.btn.Position   = Vector2.new(bx, by); self._d.btn.Size = Vector2.new(bw, bh)
        self._d.btn.Color      = hov and pal.hover or pal.panel
        self._d.btnOut.Position = Vector2.new(bx, by); self._d.btnOut.Size = Vector2.new(bw, bh)
        self._d.btnOut.Color   = pal.borderDim
        self._d.btnTxt.Text    = "config manager"
        self._d.btnTxt.Position = Vector2.new(bx + bw/2, by + (bh - sz.fontXs)/2 - 1)
        self._d.btnTxt.Color   = pal.textSub

        if self._openA > 0.01 then
            local pw, ph = w - 8, 80
            local ppx, ppy = px + 4, py + sz.elemH + 2
            for _, d in pairs(self._d) do d.Visible = true end
            self._d.panel.Position  = Vector2.new(ppx, ppy); self._d.panel.Size = Vector2.new(pw, ph); self._d.panel.Color = pal.bgDeep
            self._d.panOut.Position = Vector2.new(ppx, ppy); self._d.panOut.Size = Vector2.new(pw, ph); self._d.panOut.Color = pal.border
            self._d.title.Text      = "save / load config"
            self._d.title.Position  = Vector2.new(ppx + 8, ppy + 6); self._d.title.Color = pal.textDim

            local inpX, inpY = ppx + 6, ppy + 22
            local inpW, inpH = pw - 12, 16
            self._d.inp.Position    = Vector2.new(inpX, inpY); self._d.inp.Size = Vector2.new(inpW, inpH); self._d.inp.Color = pal.panel
            self._d.inpOut.Position = Vector2.new(inpX, inpY); self._d.inpOut.Size = Vector2.new(inpW, inpH); self._d.inpOut.Color = pal.borderDim
            self._d.inpTxt.Text     = #self._nameVal > 0 and self._nameVal or "config name..."
            self._d.inpTxt.Position = Vector2.new(inpX + 4, inpY + (inpH - sz.fontXs)/2 - 1)
            self._d.inpTxt.Color    = #self._nameVal > 0 and pal.text or pal.textDim

            local sbW = (pw - 18) / 2
            local sbY = ppy + 46
            self._d.saveBtn.Position  = Vector2.new(ppx + 6, sbY); self._d.saveBtn.Size = Vector2.new(sbW, 18)
            self._d.saveBtn.Color     = pal.panel
            self._d.saveBtnO.Position = Vector2.new(ppx + 6, sbY); self._d.saveBtnO.Size = Vector2.new(sbW, 18)
            self._d.saveBtnO.Color    = pal.borderDim
            self._d.saveTxt.Text      = "save"
            self._d.saveTxt.Position  = Vector2.new(ppx + 6 + sbW/2, sbY + 4); self._d.saveTxt.Color = pal.textSub

            self._d.loadBtn.Position  = Vector2.new(ppx + 6 + sbW + 6, sbY); self._d.loadBtn.Size = Vector2.new(sbW, 18)
            self._d.loadBtn.Color     = pal.panel
            self._d.loadBtnO.Position = Vector2.new(ppx + 6 + sbW + 6, sbY); self._d.loadBtnO.Size = Vector2.new(sbW, 18)
            self._d.loadBtnO.Color    = pal.borderDim
            self._d.loadTxt.Text      = "load"
            self._d.loadTxt.Position  = Vector2.new(ppx + 6 + sbW + 6 + sbW/2, sbY + 4); self._d.loadTxt.Color = pal.textSub

            if hit(mx, my, ppx + 6, sbY, sbW, 18) and mClick then saveConfig(self._nameVal) end
            if hit(mx, my, ppx + 6 + sbW + 6, sbY, sbW, 18) and mClick then loadConfig(self._nameVal) end

            if mClick and not hit(mx, my, ppx, ppy, pw, ph) and not hov then self._open = false end
        end
    end

    function e:destroy() for _, d in pairs(self._d) do kill(d) end end
    return e
end

local Tab = {}
Tab.__index = Tab

function Tab:AddToggle(o)      local e = mkToggle(o, self._win._flags);          self._elems[#self._elems+1] = e; return e end
function Tab:AddSlider(o)      local e = mkSlider(o, self._win._flags);          self._elems[#self._elems+1] = e; return e end
function Tab:AddButton(o)      local e = mkButton(o);                            self._elems[#self._elems+1] = e; return e end
function Tab:AddDropdown(o)    local e = mkDropdown(o, self._win._flags);        self._elems[#self._elems+1] = e; return e end
function Tab:AddKeybind(o)     local e = mkKeybind(o, self._win._flags);         self._elems[#self._elems+1] = e; return e end
function Tab:AddTextbox(o)     local e = mkTextbox(o, self._win._flags);         self._elems[#self._elems+1] = e; return e end
function Tab:AddColorPicker(o) local e = mkColorPicker(o, self._win._flags);     self._elems[#self._elems+1] = e; return e end
function Tab:AddLabel(o)       local e = mkLabel(o);                             self._elems[#self._elems+1] = e; return e end
function Tab:AddSeparator(o)   local e = mkSeparator(o);                         self._elems[#self._elems+1] = e; return e end
function Tab:AddSection(o)     local e = mkSectionHeader(o);                     self._elems[#self._elems+1] = e; return e end
function Tab:AddConfig()       local e = mkConfigUI(self._win);                  self._elems[#self._elems+1] = e; return e end

local Window = {}
Window.__index = Window

function Window:AddTab(o)
    o = o or {}
    local tab = setmetatable({
        name = o.Name or "tab",
        icon = o.Icon or "·",
        iconImg = o.IconImage,
        _elems = {}, _scroll = 0, _scrollV = 0, _win = self,
    }, Tab)
    local td = {
        bg    = newRect({ Rounding = 3, ZIndex = 8 }),
        icon  = newLabel({ Size = sz.fontSm, Center = true, ZIndex = 9 }),
        label = newLabel({ Size = sz.fontSm, ZIndex = 9 }),
        bar   = newRect({ Rounding = 2, ZIndex = 9, Color = pal.accent }),
        barA  = 0,
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

local function renderWin(w, dt)
    local show = w._vis and bliss._visible
    local p = w._pos
    local ww, wh = w._sz.X, w._sz.Y

    w._visA = lerp(w._visA or (show and 1 or 0), show and 1 or 0, 0.15)
    if w._visA < 0.01 and not show then
        local d = w._draw
        for _, obj in pairs(d) do obj.Visible = false end
        for _, td in ipairs(w._tabDraw) do for _, obj in pairs(td) do if type(obj) ~= "number" then obj.Visible = false end end end
        for _, tab in ipairs(w._tabs) do for _, el in ipairs(tab._elems) do el:draw(0,0,0,false) end end
        for _, g in pairs(w._glow) do hideGlowBorder(g) end
        return
    end

    if hit(mx, my, p.X, p.Y, ww, sz.titleH) and mClick and not w._drag then
        w._drag = true; w._dOff = Vector2.new(mx - p.X, my - p.Y)
    end
    if not mDown then w._drag = false end
    if w._drag then
        w._pos = Vector2.new(mx - w._dOff.X, my - w._dOff.Y)
        p = w._pos
    end

    local alpha = w._visA
    local d = w._draw

    d.bg.Visible    = true; d.bg.Position = p; d.bg.Size = Vector2.new(ww, wh); d.bg.Color = pal.bg; d.bg.Transparency = alpha
    d.bgOut.Visible = true; d.bgOut.Position = p; d.bgOut.Size = Vector2.new(ww, wh); d.bgOut.Color = pal.border; d.bgOut.Transparency = alpha
    d.title.Visible = true; d.title.Position = p; d.title.Size = Vector2.new(ww, sz.titleH); d.title.Color = pal.panel; d.title.Transparency = alpha
    d.titleDiv.Visible = true; d.titleDiv.From = Vector2.new(p.X, p.Y + sz.titleH); d.titleDiv.To = Vector2.new(p.X + ww, p.Y + sz.titleH); d.titleDiv.Transparency = alpha
    d.dot.Visible   = true; d.dot.Position = Vector2.new(p.X + 13, p.Y + sz.titleH/2); d.dot.Transparency = alpha
    d.name.Visible  = true; d.name.Position = Vector2.new(p.X + 24, p.Y + (sz.titleH - sz.font)/2 - 1); d.name.Text = w._name; d.name.Transparency = alpha
    d.slogan.Visible = true; d.slogan.Position = Vector2.new(p.X + ww - 72, p.Y + (sz.titleH - sz.fontXs)/2); d.slogan.Transparency = alpha
    d.side.Visible  = true; d.side.Position = Vector2.new(p.X, p.Y + sz.titleH); d.side.Size = Vector2.new(sz.tabW, wh - sz.titleH); d.side.Color = pal.bgDeep; d.side.Transparency = alpha
    d.sideDiv.Visible = true; d.sideDiv.From = Vector2.new(p.X + sz.tabW, p.Y + sz.titleH); d.sideDiv.To = Vector2.new(p.X + sz.tabW, p.Y + wh); d.sideDiv.Transparency = alpha

    w._glowPulse = (w._glowPulse or 0) + dt * 1.8
    local glowStr = 0.14 + math.abs(math.sin(w._glowPulse)) * 0.07
    drawGlowBorder(w._glow.outer, p.X, p.Y, ww, wh, pal.accent, glowStr * alpha)

    local sideY = p.Y + sz.titleH
    for i, td in ipairs(w._tabDraw) do
        local act = (i == w._active)
        td.barA = lerp(td.barA, act and 1 or 0, 0.14)
        local ty = sideY + 8 + (i-1)*30
        local tx = p.X + 6
        local tw = sz.tabW - 12
        local th = 26
        local hov = hit(mx, my, tx, ty, tw, th)
        if hov and mClick then w._active = i end
        for k, obj in pairs(td) do
            if type(obj) ~= "number" then obj.Visible = alpha > 0.05 end
        end
        td.bg.Position = Vector2.new(tx, ty); td.bg.Size = Vector2.new(tw, th)
        td.bg.Color    = lc(lc(pal.bgDeep, pal.hover, hov and 0.6 or 0), pal.panelLit, td.barA)
        td.bg.Transparency = alpha
        td.icon.Position = Vector2.new(tx + 11, ty + (th - sz.fontSm)/2 - 1)
        td.icon.Color    = lc(pal.textDim, pal.accent, td.barA)
        td.icon.Text     = w._tabs[i].icon
        td.icon.Transparency = alpha
        td.label.Position = Vector2.new(tx + 24, ty + (th - sz.fontSm)/2 - 1)
        td.label.Color    = lc(pal.textDim, pal.text, td.barA + (hov and 0.4 or 0))
        td.label.Text     = w._tabs[i].name
        td.label.Transparency = alpha
        td.bar.Position   = Vector2.new(tx + 1, ty + 5 + (1 - td.barA) * 8)
        td.bar.Size       = Vector2.new(2, 16 * td.barA)
        td.bar.Visible    = alpha > 0.05 and td.barA > 0.05
        td.bar.Transparency = alpha
    end

    local cx = p.X + sz.tabW + 1
    local cy = p.Y + sz.titleH + 1
    local cw = ww - sz.tabW - 2
    local ch = wh - sz.titleH - 2

    d.contentDiv.Visible = true; d.contentDiv.From = Vector2.new(cx, cy); d.contentDiv.To = Vector2.new(cx + cw, cy); d.contentDiv.Transparency = alpha * 0.5

    local at = w._tabs[w._active]
    if at then
        if hit(mx, my, cx, cy, cw, ch) and mScroll ~= 0 then
            at._scrollV = at._scrollV - mScroll * 26
        end
        at._scrollV = at._scrollV * 0.82
        at._scroll  = at._scroll + at._scrollV
        local totalH = 0
        for _, el in ipairs(at._elems) do totalH = totalH + el.h + sz.elemGap end
        at._scroll = clamp(at._scroll, 0, math.max(0, totalH - ch + 14))

        local ey = cy + sz.pad - at._scroll
        for _, el in ipairs(at._elems) do
            local eVis = alpha > 0.05 and (ey + el.h > cy) and (ey < cy + ch)
            el:draw(cx + 4, ey, cw - 12, eVis and true or false)
            ey = ey + el.h + sz.elemGap
        end

        if totalH > ch then
            local ratio = at._scroll / (totalH - ch + 14)
            local bh = math.max(20, (ch/totalH)*ch)
            local by = cy + ratio * (ch - bh)
            d.scroll.Visible = alpha > 0.05
            d.scroll.Position = Vector2.new(cx + cw - 4, by); d.scroll.Size = Vector2.new(2, bh)
            d.scroll.Transparency = alpha
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

function bliss.new(opts)
    opts = opts or {}
    local ww = opts.Size and opts.Size.X or 520
    local wh = opts.Size and opts.Size.Y or 380
    local cam = workspace.CurrentCamera

    if opts.AccentColor then
        pal.accent    = opts.AccentColor
        pal.accentDim = Color3.new(opts.AccentColor.R*0.75, opts.AccentColor.G*0.75, opts.AccentColor.B*0.75)
        pal.accentLit = Color3.new(math.min(1,opts.AccentColor.R*1.2), math.min(1,opts.AccentColor.G*1.2), math.min(1,opts.AccentColor.B*1.2))
    end

    local d = {
        bg         = newRect({ Rounding = sz.round, ZIndex = 1 }),
        bgOut      = newRect({ Filled = false, Rounding = sz.round, ZIndex = 1 }),
        title      = newRect({ ZIndex = 2 }),
        titleDiv   = newLine({ Color = pal.borderDim, ZIndex = 3 }),
        dot        = newDot({ Color = pal.accent, Radius = 3, NumSides = 16, ZIndex = 4 }),
        name       = newLabel({ Color = pal.text, Size = sz.font, ZIndex = 4 }),
        slogan     = newLabel({ Text = "stay blissful!", Color = pal.textDim, Size = sz.fontXs, Font = 3, ZIndex = 4 }),
        side       = newRect({ ZIndex = 2 }),
        sideDiv    = newLine({ Color = pal.borderDim, ZIndex = 3 }),
        contentDiv = newLine({ Color = pal.borderDim, ZIndex = 3, Transparency = 0.5 }),
        scroll     = newRect({ Color = pal.borderDim, Rounding = 2, ZIndex = 25 }),
    }

    local win = setmetatable({
        _name     = opts.Name or "bliss.lua",
        _sz       = Vector2.new(ww, wh),
        _pos      = opts.Position or Vector2.new((cam.ViewportSize.X - ww)/2, (cam.ViewportSize.Y - wh)/2),
        _vis      = true, _tabs = {}, _active = 1,
        _flags    = {}, _drag = false, _dOff = Vector2.new(0, 0),
        _draw     = d, _tabDraw = {},
        _visA     = 0,
        _glowPulse = 0,
        _glow     = { outer = mkGlowBorder(1) },
    }, Window)

    bliss._windows[win._name] = win

    ensureLoadScreen()
    _loadT      = 0
    _loadDismiss = false
    _loadReady  = false
    _loadFading = false
    _loadFadeT  = 0

    if opts.Watermark then
        local wm = opts.Watermark
        bliss._watermark = mkWatermark({
            Enabled  = wm.Enabled,
            PosX     = wm.PosX,
            PosY     = wm.PosY,
            Info     = wm.Info,
            Color    = wm.Color or pal.accent,
        })
    end

    _loadDismiss = false
    return win
end

function bliss:Notify(opts)
    opts = opts or {}
    local n = mkNotif(opts)
    table.insert(self._notifs, n)
    return n
end

function bliss:AddWatermark(opts)
    self._watermark = mkWatermark(opts or {})
end

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

function bliss:SaveTheme(name)
    self._themes[name] = {}
    for k, v in pairs(pal) do self._themes[name][k] = v end
end

function bliss:LoadTheme(name)
    if not self._themes[name] then return end
    for k, v in pairs(self._themes[name]) do pal[k] = v end
end

function bliss:SetSpacing(preset)
    applySpacing(preset)
    bliss._spacing = preset
end

function bliss:SetToggleKey(k) self._toggleKey = k end

function bliss:FinishLoading()
    if _loadReady then
        _loadDismiss = true
    else
        task.spawn(function()
            while not _loadReady do task.wait() end
            _loadDismiss = true
        end)
    end
end

function bliss:Destroy(name)
    local w = self._windows[name]
    if not w then return end
    for _, tab in ipairs(w._tabs) do
        for _, el in ipairs(tab._elems) do if el.destroy then el:destroy() end end
    end
    for _, d in pairs(w._draw) do kill(d) end
    for _, td in ipairs(w._tabDraw) do for k, d in pairs(td) do if type(d) ~= "number" then kill(d) end end end
    for _, g in pairs(w._glow) do
        kill(g.g1); kill(g.g2); kill(g.g3)
    end
    self._windows[name] = nil
end

function bliss:DestroyAll()
    for name in pairs(self._windows) do self:Destroy(name) end
    for _, c in ipairs(self._connections) do pcall(c.Disconnect, c) end
    self._connections = {}
    for _, d in pairs(_tooltipDraw or {}) do kill(d) end
    if _loadScreen then for _, d in pairs(_loadScreen) do kill(d) end end
    if self._watermark then for _, d in pairs(self._watermark._d) do kill(d) end end
end

table.insert(bliss._connections, UIS.InputChanged:Connect(function(io)
    if io.UserInputType == Enum.UserInputType.MouseMovement then
        mx, my = io.Position.X, io.Position.Y - insetY
    elseif io.UserInputType == Enum.UserInputType.MouseWheel then
        mScroll = io.Position.Z
    end
end))

table.insert(bliss._connections, UIS.InputBegan:Connect(function(io, gp)
    if io.UserInputType == Enum.UserInputType.MouseButton1 then
        mDown = true; mClick = true
    end
    if not gp and io.KeyCode == bliss._toggleKey then
        bliss._visible = not bliss._visible
    end
end))

table.insert(bliss._connections, UIS.InputEnded:Connect(function(io)
    if io.UserInputType == Enum.UserInputType.MouseButton1 then mDown = false end
end))

local _lastT = tick()
table.insert(bliss._connections, RS.RenderStepped:Connect(function()
    local now = tick()
    local dt  = math.min(now - _lastT, 0.1)
    _lastT    = now

    local ml = UIS:GetMouseLocation()
    mx, my = ml.X, ml.Y - insetY

    local cam = workspace.CurrentCamera

    if not bliss._loadDone then
        updateLoadScreen(dt, cam)
        mClick  = false
        mScroll = 0
        return
    end

    bliss._tooltipText = nil
    for _, w in pairs(bliss._windows) do
        renderWin(w, dt)
    end

    if bliss._tooltipText then
        drawTooltip(bliss._tooltipText, bliss._tooltipMx or mx, bliss._tooltipMy or my)
    else
        hideTooltip()
    end

    updateNotifs(dt, cam)
    updateWatermark(bliss._watermark, dt, cam)

    mClick  = false
    mScroll = 0
end))

task.spawn(function()
    task.wait(2.25)
    while not _loadReady do task.wait() end
    _loadDismiss = true
end)

global[bliss_key] = bliss
return bliss
