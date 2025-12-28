local Module = {}

Module.Theme = {
    Background   = Color3.fromRGB(20, 20, 24),
    Header       = Color3.fromRGB(28, 28, 33), 
    SectionBg    = Color3.fromRGB(25, 25, 30),
    Border       = Color3.fromRGB(45, 45, 55),
    Accent       = Color3.fromRGB(98, 114, 255),
    Text         = Color3.fromRGB(235, 235, 240),
    TextDim      = Color3.fromRGB(110, 110, 120),
    Hover        = Color3.fromRGB(40, 40, 50),
    Link         = Color3.fromRGB(50, 200, 255),
    SnapLine     = Color3.fromRGB(98, 114, 255),
    Negative     = Color3.fromRGB(255, 85, 85),
    SwitchBg     = Color3.fromRGB(50, 50, 60),
    TooltipBg    = Color3.fromRGB(25, 25, 30),
    Divider      = Color3.fromRGB(60, 60, 70)
}

Module.Layer = { Base=1, Section=2, Item=3, Widget=10, Popup=50, Tooltip=200, Notif=300 }

return Module
