--[[
Main Functions:

* Frag:Init()
  Starts the UI rendering and input loops. Run this last.
  
* Frag:Notify(text, duration)
  Shows a visual notification card in the top right.
  - text: The message to show
  - duration: Display time in seconds (default is 3)
  
* Frag:CreateWindow(config)
  Creates the main UI window.
  - config: { Name = string, Position = vector, ToggleKey = string }
  
* window:Page(config)
  Adds a tab page to the window.
  - config: { Name = string }
  
* page:Section(config)
  Adds a column container to a page.
  - config: { Name = string, Side = "Left" or "Right" }

* Frag:CreateDocWindow(config)
  Creates a specialized documentation window with side navigation and custom rendering.
  - config: { Name = string, Position = vector }

* docWindow:AddPage(id, title, callback)
  Adds an article to the documentation window.
  - callback: function(ui)
    - ui:Header(text) -- Adds a bold header line
    - ui:Text(text)   -- Adds normal wrapped text
    - ui:Space(num)   -- Adds empty vertical spacing
    - ui:Link(text, targetId) -- Adds a clickable link to another page

Widgets (Add these to sections):

* section:Toggle(config)
  A simple on/off switch.
  - config: { Name = string, Default = bool, Flag = string, Callback = function(enabled) }
  
* section:Slider(config)
  A slider bar to adjust numbers.
  - config: { Name = string, Min = num, Max = num, Default = num, Flag = string, Callback = function(value) }
  
* section:Dropdown(config)
  A dropdown menu of options.
  - config: { Name = string, Options = table, Default = string, Multi = bool, Flag = string, Callback = function(choice) }
  
* section:Button(config)
  A clickable action button.
  - config: { Name = string, Callback = function() }
  
* section:ColorPicker(config)
  An interactive color selector.
  - config: { Name = string, Default = Color3, Flag = string, Callback = function(color) }
  
* section:Binder(config)
  A key binder element.
  - config: { Name = string, Default = string, Flag = string, Callback = function(key) }

State Options:
* Saved option values are stored at: Frag.Flags[FlagName]
* Frag.State.EditMode = bool -- Toggles the layout editor (dragging/snapping)
* Frag.State.Watermark.Visible = bool -- Shows/hides the watermark box
* Frag.State.Watermark.Text = string -- Sets watermark text
]]

local Frag = {}
Frag.__index = Frag

local Repo = "https://raw.githubusercontent.com/bloodstainedsaint/FragSDK/refs/heads/main/"
local Modules = {
    "Theme",
    "Utils",
    "Input",
    "Notifications",
    "Window",
    "Docs"
}

local function LoadModule(name)
    local url = Repo .. "Modules/" .. name .. ".lua"
    local success, content = pcall(function() return game:HttpGet(url) end)
    if not success then return warn("[FragSDK] Failed to fetch " .. name) end

    local cSuccess, bytecode = pcall(luau.compile, content, { optimizationLevel = 2 })
    if not cSuccess then return warn("[FragSDK] Compile failed for " .. name) end

    local lSuccess, func = pcall(luau.load, bytecode, { debugName = name, injectGlobals = true })
    if not lSuccess then return warn("[FragSDK] Load failed for " .. name) end

    local moduleData = func()
    for k, v in pairs(moduleData) do
        Frag[k] = v
    end
end

print("Loading Modules...")

for _, mod in ipairs(Modules) do
    LoadModule(mod)
end

if Frag.InitState then 
    Frag.State = Frag.InitState() 
end

print("FragSDK Loaded")
return Frag
