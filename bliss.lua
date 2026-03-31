local bliss = loadstring(game:HttpGet("YOUR_RAW_URL"))()

local win = bliss.new({
    Name = "bliss.lua",
    Size = Vector2.new(540, 380),
    Position = Vector2.new(100, 100),
})

local combat  = win:AddTab({ Name = "combat",  Icon = "◎" })
local visuals = win:AddTab({ Name = "visuals", Icon = "◉" })
local misc    = win:AddTab({ Name = "misc",    Icon = "◈" })
local config  = win:AddTab({ Name = "config",  Icon = "◇" })

combat:AddToggle({
    Name = "aimbot",
    Default = false,
    Flag = "aim_enabled",
    Callback = function(v)
        print("aimbot:", v)
    end
})

combat:AddSlider({
    Name = "fov",
    Min = 10,
    Max = 500,
    Default = 120,
    Increment = 5,
    Suffix = "px",
    Flag = "aim_fov",
    Callback = function(v)
        print("fov:", v)
    end
})

combat:AddDropdown({
    Name = "target",
    Options = {"closest", "lowest hp", "random"},
    Default = "closest",
    Flag = "aim_target",
    Callback = function(v)
        print("target mode:", v)
    end
})

combat:AddKeybind({
    Name = "aim key",
    Default = Enum.KeyCode.E,
    Flag = "aim_key",
    Callback = function()
        print("aim key pressed!")
    end
})

combat:AddSeparator()

combat:AddToggle({
    Name = "silent aim",
    Default = false,
    Flag = "silent",
    Callback = function(v) end
})

combat:AddSlider({
    Name = "prediction",
    Min = 0,
    Max = 1,
    Default = 0.15,
    Increment = 0.01,
    Flag = "prediction",
    Callback = function(v) end
})

visuals:AddToggle({
    Name = "esp",
    Default = false,
    Callback = function(v) end
})

visuals:AddColorPicker({
    Name = "esp color",
    Default = Color3.fromRGB(235, 135, 145),
    Callback = function(v)
        print("color:", v)
    end
})

visuals:AddToggle({
    Name = "tracers",
    Default = false,
    Callback = function(v) end
})

visuals:AddDropdown({
    Name = "tracer origin",
    Options = {"bottom", "center", "mouse"},
    Default = "bottom",
    Callback = function(v) end
})

visuals:AddSlider({
    Name = "transparency",
    Min = 0,
    Max = 100,
    Default = 30,
    Suffix = "%",
    Callback = function(v) end
})

misc:AddButton({
    Name = "rejoin server",
    Callback = function()
        print("rejoining...")
    end
})

misc:AddButton({
    Name = "copy server link",
    Callback = function()
        print("copied!")
    end
})

misc:AddTextbox({
    Name = "webhook url",
    Placeholder = "https://discord.com/api/...",
    Callback = function(v)
        print("webhook set:", v)
    end
})

misc:AddLabel({ Text = "stay blissful!" })

config:AddButton({
    Name = "save config",
    Callback = function()
        print("saved")
    end
})

config:AddButton({
    Name = "load config",
    Callback = function()
        print("loaded")
    end
})

config:AddSeparator()
config:AddLabel({ Text = "keybinds" })

config:AddKeybind({
    Name = "toggle menu",
    Default = Enum.KeyCode.RightShift,
    Callback = function() end
})
