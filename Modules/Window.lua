local Module = {}

Module.Windows = {}

function Module.CreateWindow(self, props)
    local window = { 
        name = props.Name or "UI", 
        pos = props.Position or vector.create(200,200,0), 
        size = vector.create(560, 30, 0), 
        activePage = 1,
        pages = {}
    }

    if props.ToggleKey then self.State.ToggleKey = props.ToggleKey end

    function window:Draw(Lib)
        -- Only draw if visible
        local alpha = Lib.State.MenuAlpha
        if alpha < 0.01 then return end
        
        -- (Insert your big draw logic here, referencing Lib.Theme, Lib.Rect, etc.)
        -- For brevity, simply drawing the header as a test:
        local x, y = self.pos.x, self.pos.y
        Lib.Rect(self.pos, self.size, Lib.Theme.Background, alpha)
        Lib.Outline(self.pos, self.size, Lib.Theme.Border, alpha)
        Lib.Label(vector.create(x+10, y+5, 0), self.name, Lib.Theme.Text, false, alpha)
    end
    
    function window:Page(name)
        -- Page Logic here...
        return {} -- return dummy for now
    end

    table.insert(self.Windows, window)
    return window
end

function Module.Init(self)
    -- Initialize State
    self.State = self.InitState() -- From Input module
    
    game:GetService("RunService").Render:Connect(function()
        self:UpdateInput()
        self:RenderNotifications()
        
        for _, w in ipairs(self.Windows) do
            w:Draw(self) -- Pass the Library (self) to the window so it can access utils
        end
    end)
    
    print("[FragSDK] Initialized")
end

return Module
