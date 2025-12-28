local Module = {}

Module.Notifications = {} -- Container for queue

function Module.Notify(self, msg, duration) 
    if not self.Notifications.Queue then self.Notifications.Queue = {} end
    table.insert(self.Notifications.Queue, {
        id = os.clock()..math.random(), 
        text = msg, 
        duration = duration or 3, 
        start = os.clock(), 
        alpha = 0, 
        slide = -50
    }) 
end

function Module.RenderNotifications(self)
    if not self.Notifications.Queue then return end
    
    local dt = self.State.DeltaTime
    local startY = 60
    
    -- Iterate backwards so we can safely remove items
    for i = #self.Notifications.Queue, 1, -1 do
        local n = self.Notifications.Queue[i]
        local el = os.clock() - n.start
        local rem = n.duration - el
        
        -- Slide Animation (Enter)
        n.slide = self.Lerp(n.slide, 0, dt * 10)
        
        -- Alpha Calculation
        if rem > 0 then
            -- Fading In
            n.alpha = self.Lerp(n.alpha, 1, dt * 10)
        else
            -- Fading Out (Expired)
            n.alpha = self.Lerp(n.alpha, 0, dt * 15)
            
            -- FIX: Kill it immediately if it's below 5% visibility
            if n.alpha < 0.05 then 
                table.remove(self.Notifications.Queue, i)
                continue -- Skip drawing this frame
            end
        end
        
        -- Only draw if visible
        if n.alpha > 0.05 then
            local bw = (7 * #n.text) + 20
            local targetX = self.State.ScreenSize.x - bw - 20
            local px = targetX + n.slide
            
            -- Border
            self.Rect(
                vector.create(px, startY, 200), 
                vector.create(bw, 28, 0), 
                self.Theme.Border, 
                n.alpha
            )
            
            -- Background
            self.Rect(
                vector.create(px + 1, startY + 1, 200), 
                vector.create(bw - 2, 26, 0), 
                self.Theme.Background, 
                n.alpha
            )
            
            -- Text
            self.Label(
                vector.create(px + 10, startY + 6, 200), 
                n.text, 
                self.Theme.Text, 
                false, 
                n.alpha
            )
            
            -- Time Bar
            local pct = math.clamp(rem / n.duration, 0, 1)
            if pct > 0 then
                self.Rect(
                    vector.create(px + 1, startY + 25, 200), 
                    vector.create((bw - 2) * pct, 2, 0), 
                    self.Theme.Accent, 
                    n.alpha
                )
            end
            
            startY = startY + 38
        end
    end
end

return Module
