local Module = {}

Module.NotifyQueue = {}

function Module.Notify(self, msg, duration) 
    table.insert(self.NotifyQueue, {
        id = os.clock()..math.random(), 
        text = msg, 
        duration = duration or 3, 
        start = os.clock(), 
        alpha = 0, 
        slide = -50
    }) 
end

function Module.RenderNotifications(self)
    local dt = self.State.DeltaTime
    local startY = 60
    
    for i = #self.NotifyQueue, 1, -1 do
        local n = self.NotifyQueue[i]
        local el = os.clock() - n.start
        local rem = n.duration - el
        
        n.slide = self.Lerp(n.slide, 0, dt * 10)
        n.alpha = self.Lerp(n.alpha, 1, dt * 10)
        
        if rem <= 0 then 
            n.alpha = self.Lerp(n.alpha, 0, dt * 15)
            if n.alpha < 0.05 then table.remove(self.NotifyQueue, i) end
        end
        
        if rem > 0 or n.alpha > 0.05 then
            local bw = (7 * #n.text) + 20
            local targetX = self.State.ScreenSize.x - bw - 20
            local px = targetX + n.slide
            
            self.Rect(vector.create(px, startY, 200), vector.create(bw, 28, 0), self.Theme.Border, n.alpha)
            self.Rect(vector.create(px + 1, startY + 1, 200), vector.create(bw - 2, 26, 0), self.Theme.Background, n.alpha)
            self.Label(vector.create(px + 10, startY + 6, 200), n.text, self.Theme.Text, false, n.alpha)
            
            local pct = math.clamp(rem / n.duration, 0, 1)
            self.Rect(vector.create(px + 1, startY + 25, 200), vector.create((bw - 2) * pct, 2, 0), self.Theme.Accent, n.alpha)
            
            startY = startY + 38
        end
    end
end

return Module
