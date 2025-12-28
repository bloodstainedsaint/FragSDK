local Module = {}

Module.Windows = {}
Module.Binders = {}
Module.Flags = {}

local WIN_W, COL_W = 560, 265 

function Module.HandleDraggable(self, obj, ignoreEditMode, dragSize)
    if not self.State.Enabled then
        obj.dragging = false; return
    end

    local click = self.State.MouseDown and not self.State.MouseHeld
    local hitSize = dragSize or obj.size
    local hovered = self:IsMouseOver(obj.pos, hitSize)

    if not self.State.InputBusy then
        if not obj.dragging and click and hovered then 
            obj.dragging = true
            obj.dragOffset = vector.create(self.State.MousePos.x - obj.pos.x, self.State.MousePos.y - obj.pos.y, 0) 
        end
    end
    
    if obj.dragging then
        if self.State.MouseDown then
            local rawPos = vector.create(self.State.MousePos.x - obj.dragOffset.x, self.State.MousePos.y - obj.dragOffset.y, 0)
            -- Call the snap function from Input module (mixed into self)
            obj.pos = self:CalculateDragSnap(obj, rawPos)
            self.State.InputBusy = true
        else 
            obj.dragging = false 
        end
    end
end

function Module.CreateWindow(self, props)
    -- This uses self.State, which relies on Main.lua initializing it first
    if props.ToggleKey and self.State then self.State.ToggleKey = props.ToggleKey end
    
    if self.Windows[1] then 
        self.Windows[1].name = props.Name or self.Windows[1].name
        return self.Windows[1] 
    end

    local window = { 
        name = props.Name or "UI", 
        pos = props.Position or vector.create(200,200,0), 
        size = vector.create(WIN_W, 30, 0), 
        dragging=false, dragOffset=vector.create(0,0,0), 
        pages={}, activePage=1, pinned=false,
        tabAlpha = 1, activePagePrev = 1
    }

    function window:Draw(Lib)
        -- VISIBILITY CHECK
        if not Lib.State.Enabled then return end
        
        local dt = Lib.State.DeltaTime
        
        -- Animation Logic
        if self.activePage ~= self.activePagePrev then
            self.tabAlpha = 0 
            self.activePagePrev = self.activePage
        end
        self.tabAlpha = Lib.Lerp(self.tabAlpha, 1, dt * 10)

        local page = self.pages[self.activePage]
        local lY, rY = 55, 55
        
        -- Height Calculation
        if page then
            for _, s in ipairs(page.sections) do
                local h = 28
                for _, it in ipairs(s.items) do
                    local add = 28 
                    if it.type == "dropdown" and it.open then add = add + (#it.options * 22) + 6 end
                    if it.type == "colorpicker" and it.open then add = add + 75 end
                    h = h + add
                end
                if s.side == "Left" then s.ry = lY; lY=lY+h+12 else s.ry = rY; rY=rY+h+12 end
            end
        end
        local totalH = math.max(lY, rY)
        self.size = vector.create(WIN_W, totalH + 20, 0)

        -- Window Dragging
        Lib:HandleDraggable(self, true, vector.create(WIN_W, 34, 0))
        
        local x, y, z = self.pos.x, self.pos.y, Lib.Layer.Base
        local click = Lib.State.MouseDown and not Lib.State.MouseHeld
        if Lib.State.InputBusy and not self.dragging then click = false end

        -- Draw Main Window
        -- Note: We pass alpha * MenuAlpha so the whole window fades
        local winAlpha = Lib.State.MenuAlpha
        if winAlpha < 0.01 then return end

        Lib.Rect(vector.create(x,y,z), self.size, Lib.Theme.Border, winAlpha)
        Lib.Rect(vector.create(x+1,y+1,z), vector.create(WIN_W-2, totalH+18,0), Lib.Theme.Background, winAlpha)
        Lib.Rect(vector.create(x+1,y+1,z), vector.create(WIN_W-2,34,0), Lib.Theme.Header, winAlpha)
        Lib.Label(vector.create(x+12,y+10,z+1), self.name, Lib.Theme.Text, false, winAlpha)
        Lib.Line(vector.create(x+1,y+34,z), vector.create(x+WIN_W-1,y+34,z), Lib.Theme.Border, winAlpha, 1)

        -- Draw Tabs
        local tx = 130 
        for i, pg in ipairs(self.pages) do
            local w = (7*#pg.name)+20
            if click and Lib:IsMouseOver(vector.create(x+tx,y+1,0), vector.create(w,34,0)) then self.activePage = i end
            
            local isActive = (self.activePage == i)
            Lib.Label(vector.create(x+tx+10,y+10,z+1), pg.name, isActive and Lib.Theme.Accent or Lib.Theme.TextDim, false, winAlpha)
            if isActive then 
                Lib.Rect(vector.create(x+tx,y+34-2,z+1), vector.create(w,2,0), Lib.Theme.Accent, winAlpha)
            end
            tx = tx + w
        end
        
        local contentAlpha = self.tabAlpha * winAlpha

        if page then
            for _, sect in ipairs(page.sections) do
                local sx = (sect.side == "Left") and (x+12) or (x+12+COL_W+12); local sy = y+sect.ry
                local sh = 28
                for _, it in ipairs(sect.items) do
                    local add = 28
                    if it.type=="dropdown" and it.open then add=add+(#it.options*22)+6 end
                    if it.type=="colorpicker" and it.open then add=add+75 end
                    sh = sh + add
                end
                
                -- Section Visuals
                Lib.Rect(vector.create(sx,sy,z+1), vector.create(COL_W,sh,0), Lib.Theme.Border, contentAlpha)
                Lib.Rect(vector.create(sx+1,sy+1,z+1), vector.create(COL_W-2,sh-2,0), Lib.Theme.SectionBg, contentAlpha)
                Lib.Rect(vector.create(sx+1,sy+1,z+2), vector.create(COL_W-2, 22, 0), Lib.Theme.Header, contentAlpha)
                Lib.Label(vector.create(sx+8,sy+5,z+3), sect.name, Lib.Theme.TextDim, false, contentAlpha)
                Lib.Line(vector.create(sx+1,sy+23,z+2), vector.create(sx+COL_W-1,sy+23,z+2), Lib.Theme.Border, contentAlpha, 1)

                local cy = sy + 30
                for _, item in ipairs(sect.items) do
                    -- Init Animation State for Items
                    if not item.anim then item.anim = { slide = 0, hover = 0 } end
                    
                    local nmX, valX = sx+10, sx+COL_W-15
                    local iH = 28
                    local itemPos = vector.create(sx+4, cy-2, 0)
                    local hover = Lib:IsMouseOver(itemPos, vector.create(COL_W-8, 24, 0))
                    local iClick = hover and click
                    
                    -- Update Hover Anim
                    item.anim.hover = Lib.Lerp(item.anim.hover, hover and 1 or 0, dt * 10)
                    
                    if item.type == "toggle" then
                        if iClick then 
                            item.value = not item.value
                            if item.callback then item.callback(item.value) end
                            if item.flag then Lib.Flags[item.flag] = item.value end 
                        end
                        
                        -- Anim
                        local targetSlide = item.value and 1 or 0
                        item.anim.slide = Lib.Lerp(item.anim.slide, targetSlide, dt * 12)
                        
                        Lib.Label(vector.create(nmX, cy+4, z+3), item.name, item.value and Lib.Theme.Text or Lib.Theme.TextDim, false, contentAlpha)
                        
                        local swW = 22
                        local swX = valX - swW
                        local curCol = Lib.LerpColor(Lib.Theme.SwitchBg, Lib.Theme.Accent, item.anim.slide)
                        
                        Lib.Circle(vector.create(swX, cy+10, z+3), 6, curCol, contentAlpha)
                        Lib.Circle(vector.create(swX+12, cy+10, z+3), 6, curCol, contentAlpha)
                        Lib.Rect(vector.create(swX, cy+4, z+3), vector.create(12, 12, 0), curCol, contentAlpha)
                        
                        local knX = swX + (12 * item.anim.slide)
                        Lib.Circle(vector.create(knX, cy+10, z+4), 4, Lib.Theme.Text, contentAlpha)

                    elseif item.type == "slider" then
                        if hover and isleftpressed() and not Lib.State.InputBusy then
                            local barW = 100
                            local bx = valX - barW - 15 -- Adjust logic from original
                            -- The original logic: valX is Right Side.
                            -- bx = valX - (TextWidth) - Padding - BarWidth
                            local valStr = tostring(item.value)
                            local vw = 7*#valStr
                            bx = valX - vw - 15 - 100
                            
                            local pct = math.clamp((Lib.State.MousePos.x - bx) / 100, 0, 1)
                            local nv = math.floor(item.min + (item.max - item.min) * pct)
                            if nv ~= item.value then 
                                item.value = nv
                                if item.callback then item.callback(nv) end
                                if item.flag then Lib.Flags[item.flag] = nv end 
                            end
                        end
                        
                        Lib.Label(vector.create(nmX, cy + 4, z+3), item.name, Lib.Theme.Text, false, contentAlpha)
                        
                        local valStr = tostring(item.value)
                        local valW = 7 * #valStr
                        Lib.Label(vector.create(valX - valW, cy + 4, z+3), valStr, Lib.Theme.TextDim, false, contentAlpha)
                        
                        local barW = 100
                        local barX = valX - valW - 15 - barW
                        local barY = cy + 10
                        
                        Lib.Rect(vector.create(barX, barY, z+3), vector.create(barW, 2, 0), Lib.Theme.SwitchBg, contentAlpha)
                        
                        local targetFill = ((item.value - item.min)/(item.max - item.min)) * barW
                        item.anim.slide = Lib.Lerp(item.anim.slide, targetFill, dt * 15)
                        
                        Lib.Rect(vector.create(barX, barY, z+3), vector.create(item.anim.slide, 2, 0), Lib.Theme.Accent, contentAlpha)
                        Lib.Circle(vector.create(barX+item.anim.slide, barY+1, z+4), 4, Lib.Theme.Text, contentAlpha)

                    elseif item.type == "dropdown" then
                        if iClick then item.open = not item.open end
                        
                        local dispText = item.selected
                        if item.multi then
                            local active = {}
                            for k,v in pairs(item.selected) do if v then table.insert(active, k) end end
                            if #active == 0 then dispText = "None" 
                            elseif #active <= 3 then dispText = table.concat(active, ", ") 
                            else dispText = #active .. " Selected" end
                        end
                        
                        Lib.Label(vector.create(nmX, cy+4, z+3), Lib.FitText(item.name, 120), Lib.Theme.Text, false, contentAlpha)
                        Lib.Label(vector.create(valX-(7*#dispText)-15, cy+4, z+3), dispText, Lib.Theme.Accent, false, contentAlpha)
                        
                        local triC = item.open and Lib.Theme.Accent or Lib.Theme.TextDim
                        local cx, cy_c = valX-5, cy+10
                        if item.open then
                            Lib.Triangle(vector.create(cx, cy_c-3, z+3), vector.create(cx-4, cy_c+2, z+3), vector.create(cx+4, cy_c+2, z+3), triC, contentAlpha)
                        else
                            Lib.Triangle(vector.create(cx, cy_c+3, z+3), vector.create(cx-4, cy_c-2, z+3), vector.create(cx+4, cy_c-2, z+3), triC, contentAlpha)
                        end
                        
                        if item.open then
                            local dy = cy + 28
                            Lib.Rect(vector.create(sx+10, dy-2, z+4), vector.create(COL_W-20, #item.options*22 + 4, 0), Lib.Theme.Header, contentAlpha)
                            Lib.Outline(vector.create(sx+10, dy-2, z+4), vector.create(COL_W-20, #item.options*22 + 4, 0), Lib.Theme.Border, contentAlpha)
                            for _, opt in ipairs(item.options) do
                                local oPos = vector.create(sx+12, dy, 0); local oSize = vector.create(COL_W-24, 20, 0)
                                if Lib:IsMouseOver(oPos, oSize) then
                                    Lib.Rect(oPos, oSize, Lib.Theme.Hover, contentAlpha)
                                    if click then
                                        if item.multi then 
                                            item.selected[opt] = not item.selected[opt]
                                            if item.callback then item.callback(item.selected) end
                                            if item.flag then Lib.Flags[item.flag] = item.selected end
                                        else 
                                            item.selected = opt; item.open = false
                                            if item.callback then item.callback(opt) end
                                            if item.flag then Lib.Flags[item.flag] = opt end 
                                        end
                                    end
                                end
                                local isSel = false; if item.multi then isSel = item.selected[opt] else isSel = (item.selected == opt) end
                                Lib.Label(vector.create(sx+18, dy+3, z+5), opt, isSel and Lib.Theme.Accent or Lib.Theme.Text, false, contentAlpha)
                                dy = dy + 22
                            end
                            iH = iH + (#item.options * 22) + 6
                        end
                    elseif item.type == "button" then
                        if item.anim.hover > 0.01 then
                            Lib.Rect(vector.create(sx+8, cy+2, z+2), vector.create(COL_W-16, 20, 0), Lib.Theme.Hover, item.anim.hover * contentAlpha)
                        end
                        Lib.Outline(vector.create(sx+8, cy+2, z+2), vector.create(COL_W-16, 20, 0), Lib.Theme.Border, contentAlpha)
                        if iClick and item.callback then item.callback() end
                        
                        local txtCol = Lib.LerpColor(Lib.Theme.Text, Lib.Theme.Accent, item.anim.hover)
                        Lib.Label(vector.create(nmX, cy+4, z+3), item.name, txtCol, false, contentAlpha)
                    
                    elseif item.type == "colorpicker" then
                        if iClick then item.open = not item.open end
                        Lib.Label(vector.create(nmX, cy + 4, z+3), item.name, Lib.Theme.Text, false, contentAlpha)
                        Lib.Rect(vector.create(valX - 20, cy + 6, z+3), vector.create(20, 10, 0), item.color, contentAlpha)
                        
                        if item.open then
                            local py = cy + 28
                            local function slider(c, v, m)
                                if Lib:IsMouseOver(vector.create(sx+15, py, 0), vector.create(COL_W-30, 15, 0)) and isleftpressed() then
                                    local p = math.clamp((Lib.State.MousePos.x - (sx+40)) / 150, 0, 1)
                                    v = math.floor(p * m)
                                end
                                Lib.Label(vector.create(sx+20, py, z+4), c, Lib.Theme.TextDim, false, contentAlpha)
                                Lib.Rect(vector.create(sx+40, py+6, z+4), vector.create(150, 2, 0), Lib.Theme.SwitchBg, contentAlpha)
                                Lib.Rect(vector.create(sx+40, py+6, z+4), vector.create((v/m)*150, 2, 0), Lib.Theme.Accent, contentAlpha)
                                Lib.Circle(vector.create(sx+40+(v/m)*150, py+7, z+5), 3, Lib.Theme.Text, contentAlpha)
                                py = py + 20
                                return v
                            end
                            local r = slider("R", math.floor(item.color.R*255), 255)
                            local g = slider("G", math.floor(item.color.G*255), 255)
                            local b = slider("B", math.floor(item.color.B*255), 255)
                            local nc = Color3.fromRGB(r,g,b)
                            if nc ~= item.color then 
                                item.color = nc
                                if item.callback then item.callback(nc) end
                                if item.flag then Lib.Flags[item.flag] = {R=nc.R, G=nc.G, B=nc.B} end 
                            end
                            iH = iH + 75
                        end
                    elseif item.type == "binder" then
                        if iClick then item.listening = not item.listening end
                        -- Simple binder logic: if listening, capture next key
                        if item.listening then
                            local keys = getpressedkeys()
                            if keys then
                                for _, k in ipairs(keys) do
                                    if k ~= "Unknown" and k ~= "LeftMouse" then
                                        item.key = k
                                        item.listening = false
                                        if item.callback then item.callback(k) end
                                        if item.flag then Lib.Flags[item.flag] = k end
                                    end
                                end
                            end
                        end

                        local txt = "[" .. (item.listening and "?" or item.key) .. "]"
                        local keyW = (7 * #txt)
                        Lib.Label(vector.create(nmX, cy + 4, z+3), Lib.FitText(item.name, 230 - keyW), Lib.Theme.Text, false, contentAlpha)
                        Lib.Label(vector.create(valX - keyW, cy + 4, z+3), txt, item.listening and Lib.Theme.Accent or Lib.Theme.TextDim, false, contentAlpha)
                    end
                    cy = cy + iH
                end
            end
        end
    end
    
    function window:Page(p)
        for _, pg in ipairs(self.pages) do if pg.name == p.Name then return pg end end
        local pg = {name=p.Name, sections={}}
        function pg:Section(p)
            local sec = {name=p.Name, side=p.Side or "Left", items={}}
            function sec:Toggle(p) table.insert(sec.items, {type="toggle", name=p.Name, value=p.Default or false, callback=p.Callback, flag=p.Flag}); if p.Flag then Lib.Flags[p.Flag] = p.Default or false end end
            function sec:Slider(p) table.insert(sec.items, {type="slider", name=p.Name, value=p.Default or p.Min, min=p.Min, max=p.Max, callback=p.Callback, flag=p.Flag}); if p.Flag then Lib.Flags[p.Flag] = p.Default or p.Min end end
            function sec:Dropdown(p) local sel = p.Default; if p.Multi and type(sel) ~= "table" then sel = {}; end table.insert(sec.items, {type="dropdown", name=p.Name, options=p.Options, selected=sel, open=false, multi=p.Multi, callback=p.Callback, flag=p.Flag}); if p.Flag then Lib.Flags[p.Flag] = sel end end
            function sec:Button(p) table.insert(sec.items, {type="button", name=p.Name, callback=p.Callback}) end
            function sec:ColorPicker(p) local c = p.Default or Color3.new(1,1,1); table.insert(sec.items, {type="colorpicker", name=p.Name, color=c, open=false, callback=p.Callback, flag=p.Flag}); if p.Flag then Lib.Flags[p.Flag] = {R=c.R, G=c.G, B=c.B} end end
            function sec:Binder(p) table.insert(sec.items, {type="binder", name=p.Name, key=p.Default or "None", listening=false, callback=p.Callback, flag=p.Flag}); if p.Flag then Lib.Flags[p.Flag] = p.Default or "None" end end
            table.insert(pg.sections, sec)
            return sec
        end
        table.insert(self.pages, pg)
        return pg
    end
    
    table.insert(self.Windows, window)
    return window
end

function Module.Init(self)
    -- DO NOT OVERWRITE self.State here (it comes from Main)
    local ren = game:GetService("RunService").Render
    
    ren:Connect(function()
        self.State.InputBusy = false
        
        self:UpdateInput()
        self:RenderNotifications()
        
        for _, w in ipairs(self.Windows) do
            w:Draw(self)
        end
        
        for _, line in ipairs(self.State.Snapping.ActiveLines) do
            self.Line(line.A, line.B, self.Theme.SnapLine, line.Alpha, 2)
        end
        
        -- Watermark Logic (Basic version for completeness)
        if self.State.Watermark.Visible and self.State.Enabled then
             local p, t = self.State.Watermark.Pos, self.State.Watermark.Text
             local w = (7*#t)+20
             self.Rect(p, vector.create(w, 24, 0), self.Theme.Border, self.State.MenuAlpha)
             self.Rect(vector.create(p.x+1,p.y+1,1), vector.create(w-2, 22, 0), self.Theme.Background, self.State.MenuAlpha)
             self.Rect(p, vector.create(2,24,0), self.Theme.Accent, self.State.MenuAlpha)
             self.Label(vector.create(p.x+10,p.y+5,3), t, self.Theme.Text, false, self.State.MenuAlpha)
        end
    end)
    
    print("[FragSDK] Initialized")
end

return Module
