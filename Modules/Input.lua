local Module = {}

function Module.InitState()
    return {
        Enabled = true,
        MousePos = vector.create(0, 0, 0),
        MouseDown = false,
        ToggleKey = "Delete",
        LastToggle = 0,
        ScreenSize = vector.create(1920, 1080, 0),
        DeltaTime = 0,
        LastRender = os.clock(),
        MenuAlpha = 1
    }
end

function Module.UpdateInput(self)
    local cur = os.clock()
    self.State.DeltaTime = cur - self.State.LastRender
    self.State.LastRender = cur

    local s, mPos = pcall(getmouseposition)
    if s and mPos then self.State.MousePos = mPos end
    if workspace.CurrentCamera then self.State.ScreenSize = workspace.CurrentCamera.ViewportSize end

    local lDown = isleftpressed()
    if lDown and not self.State.MouseDown then self.State.MouseDown = true
    elseif not lDown then self.State.MouseDown = false end

    -- Toggle Logic
    local keys = getpressedkeys()
    local isTogglePressed = false
    local KeyMap = { [46] = "Delete", [45] = "Insert" }
    
    if keys then 
        for _, k in ipairs(keys) do 
            if k == self.State.ToggleKey or KeyMap[k] == self.State.ToggleKey then isTogglePressed = true break end 
        end 
    end

    if isTogglePressed and (os.clock() - self.State.LastToggle > 0.3) then
        self.State.Enabled = not self.State.Enabled
        self.State.LastToggle = os.clock()
    end

    -- Menu Alpha
    local target = self.State.Enabled and 1 or 0
    self.State.MenuAlpha = self.Lerp(self.State.MenuAlpha, target, 10 * self.State.DeltaTime)
    if math.abs(self.State.MenuAlpha - target) < 0.01 then self.State.MenuAlpha = target end
end

function Module.IsMouseOver(self, pos, size)
    local m = self.State.MousePos
    return m.x >= pos.x and m.x <= pos.x + size.x and m.y >= pos.y and m.y <= pos.y + size.y
end

return Module
