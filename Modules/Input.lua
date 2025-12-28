local Module = {}

function Module.InitState()
    return {
        Enabled = true,
        EditMode = false,
        MousePos = vector.create(0, 0, 0),
        MouseDown = false, MouseHeld = false,
        RightMouseDown = false, RightMouseHeld = false,
        ToggleKey = "Delete", LastToggle = 0,
        ActiveTooltip = nil, ActivePopup = nil, 
        ScreenSize = vector.create(1920, 1080, 0),
        Watermark = { Visible = true, Text = "Severe UI", Extra = true, Pos = vector.create(60, 60, 0), Dragging = false, Offset = vector.create(0,0,0), Pinned = true },
        InputBusy = false,
        Snapping = { ActiveLines = {} },
        LastTick = 0, FrameCount = 0, CurrentFPS = 60,
        MenuAlpha = 1, DeltaTime = 0, LastRender = os.clock(),
    }
end

function Module.UpdateInput(self)
    local cur = os.clock()
    self.State.DeltaTime = cur - self.State.LastRender
    self.State.LastRender = cur

    local s, mPos = pcall(getmouseposition)
    if s and mPos then self.State.MousePos = mPos end
    if workspace.CurrentCamera then self.State.ScreenSize = workspace.CurrentCamera.ViewportSize end

    -- Left Mouse
    local lDown = isleftpressed()
    if lDown and not self.State.MouseDown then self.State.MouseDown = true
    elseif lDown and self.State.MouseDown then self.State.MouseHeld = true
    elseif not lDown then
        self.State.MouseDown = false; self.State.MouseHeld = false
        self.State.Watermark.Dragging = false
        for _, win in ipairs(self.Windows) do win.dragging = false end
        self.State.Snapping.ActiveLines = {} 
    end

    -- Right Mouse
    local rDown = isrightpressed()
    if rDown and not self.State.RightMouseDown then self.State.RightMouseDown = true
    elseif rDown and self.State.RightMouseDown then self.State.RightMouseHeld = true
    elseif not rDown then self.State.RightMouseDown = false; self.State.RightMouseHeld = false end

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
        self.State.Enabled = not self.State.Enabled; self.State.LastToggle = os.clock()
    end

    -- Global Alpha Animation
    local targetAlpha = self.State.Enabled and 1 or 0
    self.State.MenuAlpha = self.Lerp(self.State.MenuAlpha, targetAlpha, 10 * self.State.DeltaTime)
    if math.abs(self.State.MenuAlpha - targetAlpha) < 0.01 then self.State.MenuAlpha = targetAlpha end
    
    -- FPS Counter
    self.State.FrameCount = self.State.FrameCount + 1
    if (os.clock() - self.State.LastTick) >= 1 then
        self.State.CurrentFPS = self.State.FrameCount; self.State.FrameCount = 0; self.State.LastTick = os.clock()
    end
end

function Module.IsMouseOver(self, pos, size)
    local m = self.State.MousePos
    return m.x >= pos.x and m.x <= pos.x + size.x and m.y >= pos.y and m.y <= pos.y + size.y
end

-- Snapping System
function Module.GetSnapTargets(self, currentObj)
    local screen = self.State.ScreenSize
    local targetsX = { 0, screen.x / 2, screen.x } 
    local targetsY = { 0, screen.y / 2, screen.y } 
    
    local function Add(other)
        if other == currentObj then return end
        if not other.pos or not other.size then return end
        table.insert(targetsX, other.pos.x); table.insert(targetsX, other.pos.x + other.size.x)
        table.insert(targetsY, other.pos.y); table.insert(targetsY, other.pos.y + other.size.y)
    end
    
    for _, w in ipairs(self.Windows) do Add(w) end
    if self.State.Watermark.Visible then Add({pos=self.State.Watermark.Pos, size=vector.create(150, 22, 0)}) end
    return targetsX, targetsY
end

function Module.CalculateDragSnap(self, currentObj, rawPos)
    local snapPos = rawPos; local objSize = currentObj.size or vector.create(0,0,0)
    local targetsX, targetsY = self:GetSnapTargets(currentObj)
    local screen = self.State.ScreenSize; local threshold, lockDist = 15, 8
    self.State.Snapping.ActiveLines = {} 
    
    local anchorsX = { 0, objSize.x / 2, objSize.x }
    local anchorsY = { 0, objSize.y / 2, objSize.y }
    
    local function CheckAxis(val, anchors, targets, isX)
        local best = nil; local minD = threshold
        for _, off in ipairs(anchors) do
            local pt = val + off
            for _, t in ipairs(targets) do
                local diff = math.abs(pt - t)
                if diff < threshold then
                    local alpha = 1 - (diff / threshold)
                    local ls, le
                    if isX then ls=vector.create(t,0,self.Layer.Snap); le=vector.create(t,screen.y,0)
                    else ls=vector.create(0,t,self.Layer.Snap); le=vector.create(screen.x,t,0) end
                    table.insert(self.State.Snapping.ActiveLines, {A=ls, B=le, Alpha=alpha})
                    if diff < lockDist and diff < minD then minD = diff; best = t - off end
                end
            end
        end
        return best or val
    end
    
    return vector.create(CheckAxis(rawPos.x, anchorsX, targetsX, true), CheckAxis(rawPos.y, anchorsY, targetsY, false), 0)
end

return Module
