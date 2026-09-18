local Module = {}

Module.Theme = {
    Background   = Color3.fromRGB(14, 16, 22),
    Header       = Color3.fromRGB(22, 26, 35),
    SectionBg    = Color3.fromRGB(18, 21, 29),
    Border       = Color3.fromRGB(43, 49, 64),
    Accent       = Color3.fromRGB(106, 139, 255),
    Text         = Color3.fromRGB(238, 241, 248),
    TextDim      = Color3.fromRGB(145, 153, 171),
    Hover        = Color3.fromRGB(31, 38, 52),
    Link         = Color3.fromRGB(92, 194, 255),
    SnapLine     = Color3.fromRGB(106, 139, 255),
    Negative     = Color3.fromRGB(255, 104, 120),
    SwitchBg     = Color3.fromRGB(57, 65, 82),
    ResizeHandle = Color3.fromRGB(255, 255, 255),
    EditModeText = Color3.fromRGB(255, 180, 50),
    InfoWinBg    = Color3.fromRGB(18, 21, 29),
    TooltipBg    = Color3.fromRGB(22, 26, 35),
    Divider      = Color3.fromRGB(52, 60, 78)
}

Module.Layer = { Base=1, Section=2, Item=3, Text=4, Widget=10, Popup=50, InfoWin=150, Tooltip=200, Snap=250, Notif=300 }

return Module
