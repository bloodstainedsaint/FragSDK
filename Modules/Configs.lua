local Module = {}

local function ensureFolder(folder)
    local current = ""
    for part in folder:gmatch("[^/]+") do
        current = current == "" and part or current .. "/" .. part
        if not isfolder(current) then makefolder(current) end
    end
end

local function safeName(name)
    name = tostring(name or ""):gsub("[^%w_%-%s]", ""):gsub("%s+", "_")
    return name
end

local function notify(self, text)
    if self.Notify then self:Notify(text, 2) end
end

local function readIndex(folder)
    local path = folder .. "/index.json"
    if not isfile(path) then return {} end
    local ok, data = pcall(crypt.json.decode, readfile(path))
    return ok and type(data) == "table" and data or {}
end

local function writeIndex(folder, names)
    ensureFolder(folder)
    writefile(folder .. "/index.json", crypt.json.encode(names))
end

local function configPath(folder, name)
    return folder .. "/" .. safeName(name) .. ".json"
end

local function snapshot(self)
    local data = {}
    for key, value in pairs(self.Flags) do
        data[key] = value
    end
    return data
end

local function apply(self, data)
    for key, value in pairs(data) do
        self.Flags[key] = value
    end

    for _, window in ipairs(self.Windows) do
        for _, page in ipairs(window.pages) do
            for _, section in ipairs(page.sections) do
                for _, item in ipairs(section.items) do
                    if item.flag and data[item.flag] ~= nil then
                        local value = data[item.flag]
                        local callbackValue = value
                        if item.type == "toggle" or item.type == "slider" then
                            item.value = value
                        elseif item.type == "dropdown" then
                            item.selected = value
                        elseif item.type == "colorpicker" and type(value) == "table" then
                            local r = value.R <= 1 and value.R * 255 or value.R
                            local g = value.G <= 1 and value.G * 255 or value.G
                            local b = value.B <= 1 and value.B * 255 or value.B
                            item.color = Color3.fromRGB(r, g, b)
                            callbackValue = item.color
                        elseif item.type == "binder" and type(value) == "table" then
                            item.key = value.Key or item.key
                            item.mode = value.Mode or item.mode
                            item.active = value.Active == true
                        elseif item.type == "rangeslider" and type(value) == "table" then
                            item.lower = math.clamp(value.Min or item.lower, item.min, item.max)
                            item.upper = math.clamp(value.Max or item.upper, item.min, item.max)
                            if item.lower >= item.upper then item.upper = math.min(item.max, item.lower + item.step) end
                        elseif item.type == "textbox" then
                            item.text = tostring(value)
                            item.cursor = #item.text + 1
                        end
                        if item.callback then
                            if item.type == "rangeslider" then
                                item.callback(item.lower, item.upper)
                            else
                                item.callback(callbackValue)
                            end
                        end
                    end
                end
            end
        end
    end
end

function Module.AddConfigTab(self, window, props)
    props = props or {}
    local baseFolder = props.Folder or "FragSDK/Configs"
    local gameId = props.GameId
    if gameId == nil and props.PerGame ~= false then
        local ok, currentGameId = pcall(function() return game.GameId end)
        gameId = ok and currentGameId or 0
    end
    local folder = baseFolder
    if props.PerGame ~= false then folder = baseFolder .. "/" .. tostring(gameId or 0) end
    local page = window:Page({Name = props.Name or "Configs"})
    local left = page:Section({Name = "Configuration", Side = "Left"})
    local right = page:Section({Name = "Actions", Side = "Right"})

    local names = readIndex(folder)
    local defaultName = names[1] or "default"
    local nameBox = left:Textbox({Name = "Config Name", Default = defaultName})
    local selected = left:Dropdown({Name = "Selected Config", Options = #names > 0 and names or {"None"}, Default = defaultName})

    local function refresh()
        names = readIndex(folder)
        selected.options = #names > 0 and names or {"None"}
        if #names > 0 then selected.selected = names[1] end
    end

    local function save(name)
        name = safeName(name)
        if name == "" then notify(self, "Enter a config name") return end
        if not isfolder(folder) then makefolder(folder) end
        writefile(configPath(folder, name), crypt.json.encode(snapshot(self)))
        local exists = false
        for _, entry in ipairs(names) do if entry == name then exists = true break end end
        if not exists then table.insert(names, name); writeIndex(folder, names) end
        refresh()
        notify(self, "Saved config: " .. name)
    end

    local function load(name)
        name = safeName(name)
        local path = configPath(folder, name)
        if name == "" or not isfile(path) then notify(self, "Config not found") return end
        local ok, data = pcall(crypt.json.decode, readfile(path))
        if ok and type(data) == "table" then apply(self, data); notify(self, "Loaded config: " .. name)
        else notify(self, "Config is invalid") end
    end

    local function remove(name)
        name = safeName(name)
        local path = configPath(folder, name)
        if name == "" or not isfile(path) then notify(self, "Config not found") return end
        delfile(path)
        local nextNames = {}
        for _, entry in ipairs(names) do if entry ~= name then table.insert(nextNames, entry) end end
        names = nextNames
        writeIndex(folder, names)
        refresh()
        notify(self, "Deleted config: " .. name)
    end

    right:Button({Name = "Save Config", Callback = function() save(nameBox.text) end})
    right:Button({Name = "Load Selected", Callback = function() load(selected.selected) end})
    right:Button({Name = "Overwrite Selected", Callback = function() save(selected.selected) end})
    right:Button({Name = "Delete Selected", Callback = function() remove(selected.selected) end})
    right:Button({Name = "Refresh List", Callback = refresh})

    return page
end

return Module
