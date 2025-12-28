-- [ FragSDK | Main Loader ]
local Frag = {}
Frag.__index = Frag

-- Github Configuration
local Repo = "https://raw.githubusercontent.com/bloodstainedsaint/FragSDK/refs/heads/main/"
local Modules = {
    "Theme",
    "Utils",
    "Input",
    "Notifications",
    "Window"
}

-- Loader Function
local function LoadModule(name)
    local url = Repo .. "Modules/" .. name .. ".lua"
    local success, content = pcall(function() return game:HttpGet(url) end)
    if not success then return warn("[FragSDK] Failed to fetch " .. name) end

    -- Use Severe's Luau Compiler for performance
    local cSuccess, bytecode = pcall(luau.compile, content, { optimizationLevel = 2 })
    if not cSuccess then return warn("[FragSDK] Compile failed for " .. name) end

    local lSuccess, func = pcall(luau.load, bytecode, { debugName = name, injectGlobals = true })
    if not lSuccess then return warn("[FragSDK] Load failed for " .. name) end

    -- Run the module and merge it into Frag
    local moduleData = func()
    for k, v in pairs(moduleData) do
        Frag[k] = v
    end
end

print("[FragSDK] Loading Modules...")

-- Load all modules in order
for _, mod in ipairs(Modules) do
    LoadModule(mod)
end

-- CRITICAL FIX: Initialize State here so it exists before CreateWindow is called
if Frag.InitState then 
    Frag.State = Frag.InitState() 
end

print("[FragSDK] Loaded Successfully")
return Frag
