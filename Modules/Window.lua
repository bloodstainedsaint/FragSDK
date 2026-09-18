local Module = {}
local Lib = Module
Module.Flags = {}

Module.Windows = {}
Module.Widgets = {} 

local WIN_W, COL_W = 560, 265
local DEFAULT_MAX_H = 700
local SLIDER_VALUE_W = 30
local RANGE_VALUE_W = 55
local SLIDER_ITEM_H = 40
local SLIDER_LONG_ITEM_H = 54
local SLIDER_GAP = 14
local SLIDER_MIN_W = 60

local function getSliderLayout(name, valueWidth)
    local availableWidth = COL_W - 20
    local labelWidth = #name * 7
    local sideBarWidth = availableWidth - labelWidth - (SLIDER_GAP * 2) - valueWidth

    if sideBarWidth >= SLIDER_MIN_W then
        return {
            topLabel = false,
            labelWidth = labelWidth,
            barWidth = sideBarWidth,
            valueWidth = valueWidth,
            height = SLIDER_ITEM_H,
        }
    end

    return {
        topLabel = true,
        labelWidth = availableWidth,
        barWidth = availableWidth - SLIDER_GAP - valueWidth,
        valueWidth = valueWidth,
        height = SLIDER_LONG_ITEM_H,
    }
end

local function textFromKey(key)
    if type(key) ~= "string" then return nil end
    if #key == 1 then return key:lower() end
    if key == "Space" then return " " end
    if key == "Backspace" then return "BACKSPACE" end
    if key == "Delete" then return "DELETE" end
    if key == "Enter" or key == "Return" then return "ENTER" end
    if key == "Escape" or key == "Esc" then return "ESCAPE" end
    if key == "Left" or key == "LeftArrow" then return "LEFT" end
    if key == "Right" or key == "RightArrow" then return "RIGHT" end
    if key == "Home" then return "HOME" end
    if key == "End" then return "END" end
    return nil
end

function Module.LabelWrapped(pos, text, color, maxWidth, center, alpha)
    local maxChars = math.max(1, math.floor(maxWidth / 7))
    local lines = {}
    local current = ""

    for word in text:gmatch("%S+") do
        if current ~= "" and #current + #word + 1 > maxChars then
            table.insert(lines, current)
            current = word
        elseif current == "" then
            current = word
        else
            current = current .. " " .. word
        end
    end

    if current ~= "" then table.insert(lines, current) end
    if #lines == 0 then lines = { text } end

    for i, line in ipairs(lines) do
        DrawingImmediate.Text(
            vector.create(pos.x, pos.y + ((i - 1) * 14), pos.z),
            13,
            color,
            alpha or 1,
            line,
            center or false,
            "Proggy"
        )
    end

    return #lines
end

function Module.FindWindowIndex(self, target)
    for i, w in ipairs(self.Windows) do
        if w == target then return i end
    end
    return nil
end

function Module.FindWidgetIndex(self, target)
    for i, w in ipairs(self.Widgets) do
        if w == target then return i end
    end
    return nil
end

function Module.IsWindowOccluded(self, win)
    local idx = self:FindWindowIndex(win)
    if not idx then return false end
    for i = idx + 1, #self.Windows do
        local other = self.Windows[i]
        local isVisible = (other.visible == nil or other.visible == true)
        if isVisible and self:IsMouseOver(other.pos, other.size) then
            return true
        end
    end
    return false
end

function Module.IsWidgetOccluded(self, widget)
    for _, w in ipairs(self.Windows) do
        local isVisible = (w.visible == nil or w.visible == true)
        if isVisible and self:IsMouseOver(w.pos, w.size) then
            return true
        end
    end
    local idx = self:FindWidgetIndex(widget)
    if not idx then return false end
    for i = idx + 1, #self.Widgets do
        local other = self.Widgets[i]
        if self:IsMouseOver(other.pos, other.size) then
            return true
        end
    end
    return false
end

function Module.IsOccluded(self, obj)
    if self:FindWindowIndex(obj) then
        return self:IsWindowOccluded(obj)
    else
        return self:IsWidgetOccluded(obj)
    end
end

function Module.BringToFront(self, target)
    local idx = self:FindWidgetIndex(target)
    if idx then
        table.remove(self.Widgets, idx)
        table.insert(self.Widgets, target)
    end
end

function Module.SendToBack(self, target)
    local idx = self:FindWidgetIndex(target)
    if idx then
        table.remove(self.Widgets, idx)
        table.insert(self.Widgets, 1, target)
    end
end

function Module.BringForward(self, target)
    local idx = self:FindWidgetIndex(target)
    if idx and idx < #self.Widgets then
        local other = self.Widgets[idx + 1]
        self.Widgets[idx + 1] = target
        self.Widgets[idx] = other
    end
end

function Module.SendBackward(self, target)
    local idx = self:FindWidgetIndex(target)
    if idx and idx > 1 then
        local other = self.Widgets[idx - 1]
        self.Widgets[idx - 1] = target
        self.Widgets[idx] = other
    end
end

function Module.HandleDraggable(self, obj, ignoreEditMode, dragSize)
    if not self.State.Enabled then
        obj.dragging = false
        obj.resizing = false
        return
    end

    if not self.State.EditMode and not ignoreEditMode then
        obj.dragging = false
        obj.resizing = false
        return
    end

    local click = self.State.MouseDown and not self.State.MouseHeld
    local hitSize = dragSize or obj.size
    
    if obj.resizable and self.State.EditMode and not self.State.InputBusy then
        local handleSize = 15
        local handlePos = vector.create(obj.pos.x + obj.size.x - handleSize, obj.pos.y + obj.size.y - handleSize, 0)
        if click and not self:IsOccluded(obj) and self:IsMouseOver(handlePos, vector.create(handleSize, handleSize, 0)) then
            obj.resizing = true
        end
    end

    if not self.State.InputBusy and not obj.resizing then
        local hovered = not self:IsOccluded(obj) and self:IsMouseOver(obj.pos, hitSize)
        if not obj.dragging and click and hovered then 
            obj.dragging = true
            obj.dragOffset = vector.create(self.State.MousePos.x - obj.pos.x, self.State.MousePos.y - obj.pos.y, 0) 
        end
    end
    
    if obj.resizing then
        if self.State.MouseDown then
            local rawSize = vector.create(self.State.MousePos.x - obj.pos.x, self.State.MousePos.y - obj.pos.y, 0)
            if self.CalculateResizeSnap then
                obj.size = self:CalculateResizeSnap(obj, rawSize)
            else
                obj.size = rawSize 
            end
            self.State.InputBusy = true
        else
            obj.resizing = false
        end
    elseif obj.dragging then
        if self.State.MouseDown then
            local rawPos = vector.create(self.State.MousePos.x - obj.dragOffset.x, self.State.MousePos.y - obj.dragOffset.y, 0)
            obj.pos = self:CalculateDragSnap(obj, rawPos)
            self.State.InputBusy = true
        else 
            obj.dragging = false 
        end
    end

    if obj.resizable and self.State.EditMode and self.State.Enabled then
        local p = obj.pos
        local s = obj.size
        local hs = 10 
        local c = obj.resizing and self.Theme.Accent or self.Theme.ResizeHandle
        local z = self.Layer.Widget + 5
        self.Triangle(
            vector.create(p.x + s.x, p.y + s.y, z), 
            vector.create(p.x + s.x - hs, p.y + s.y, z), 
            vector.create(p.x + s.x, p.y + s.y - hs, z), 
            c, 
            self.State.MenuAlpha
        )
    end
end

function Module.CreateWindow(self, props)
    if props.ToggleKey and self.State then self.State.ToggleKey = props.ToggleKey end
    
    if self.Windows[1] then 
        self.Windows[1].name = props.Name or self.Windows[1].name
        return self.Windows[1] 
    end

    local window = { 
        name = props.Name or "UI", 
        pos = props.Position or vector.create(200,200,0), 
        size = vector.create(WIN_W, 30, 0), 
        dragging = false, 
        dragOffset = vector.create(0,0,0), 
        pages = {}, 
        activePage = 1, 
        pinned = false,
        tabAlpha = 1, 
        activePagePrev = 1,
        resizable = false,
        maxHeight = props.MaxHeight or DEFAULT_MAX_H,
        scroll = 0,
        scrollDragging = false
    }

    function window:Draw(Lib)
        if not Lib.State.Enabled then return end
        
        local dt = Lib.State.DeltaTime
        
        if self.activePage ~= self.activePagePrev then
            self.tabAlpha = 0 
            self.activePagePrev = self.activePage
        end
        self.tabAlpha = Lib.Lerp(self.tabAlpha, 1, dt * 10)

        local page = self.pages[self.activePage]
        local hasSubcategories = page and page.subcategories and #page.subcategories > 0 or false
        if hasSubcategories and not page.activeSubcategory then
            page.activeSubcategory = page.subcategories[1].name
        end

        local function sectionVisible(section)
            return not hasSubcategories
                or section.subcategory == nil
                or section.subcategory == page.activeSubcategory
        end

        local contentStart = hasSubcategories and 82 or 55
        local lY, rY = contentStart, contentStart
        
        if page then
            for _, s in ipairs(page.sections) do
                if not sectionVisible(s) then continue end
                local h = 28
                for _, it in ipairs(s.items) do
                    local add = 28 
                    if it.type == "slider" or it.type == "rangeslider" then
                        local valueWidth = it.type == "rangeslider" and RANGE_VALUE_W or SLIDER_VALUE_W
                        add = getSliderLayout(it.name, valueWidth).height
                    end
                    if it.type == "dropdown" and it.open then add = add + (#it.options * 22) + 6 end
                    if it.type == "colorpicker" and it.open then add = add + 75 end
                    h = h + add
                end
                if s.side == "Left" then s.ry = lY; lY=lY+h+12 else s.ry = rY; rY=rY+h+12 end
            end
        end
        local totalH = math.max(lY, rY)
        local contentHeight = totalH + 20
        local maxHeight = math.min(self.maxHeight or DEFAULT_MAX_H, math.max(260, Lib.State.ScreenSize.y - 40))
        local windowHeight = math.min(contentHeight, maxHeight)
        local maxScroll = math.max(0, contentHeight - windowHeight)
        self.scroll = math.clamp(self.scroll or 0, 0, maxScroll)
        self.size = vector.create(WIN_W, windowHeight, 0)

        Lib:HandleDraggable(self, true, vector.create(WIN_W, 34, 0))
        
        local x, y, z = self.pos.x, self.pos.y, Lib.Layer.Base
        if maxScroll > 0 and Lib.State.MouseWheel ~= 0
            and Lib:IsMouseOver(vector.create(x, y+34, 0), vector.create(WIN_W, windowHeight-34, 0)) then
            self.scroll = math.clamp(self.scroll - (Lib.State.MouseWheel * 45), 0, maxScroll)
            Lib.State.InputBusy = true
        end
        local click = Lib.State.MouseDown and not Lib.State.MouseHeld
        if Lib.State.InputBusy and not self.dragging then click = false end

        local occluded = Lib:IsWindowOccluded(self)
        if occluded then click = false end

        if click and Lib:IsMouseOver(self.pos, self.size) then
            Lib.FocusedWindow = self
        end

        local winAlpha = Lib.State.MenuAlpha
        if winAlpha < 0.01 then return end

        Lib.Rect(vector.create(x,y,z), self.size, Lib.Theme.Border, winAlpha)
        Lib.Rect(vector.create(x+1,y+1,z), vector.create(WIN_W-2, windowHeight-2,0), Lib.Theme.Background, winAlpha)
        Lib.Rect(vector.create(x+1,y+1,z), vector.create(WIN_W-2,34,0), Lib.Theme.Header, winAlpha)
        Lib.Label(vector.create(x+12,y+10,z+1), self.name, Lib.Theme.Text, false, winAlpha)
        Lib.Line(vector.create(x+1,y+34,z), vector.create(x+WIN_W-1,y+34,z), Lib.Theme.Border, winAlpha, 1)

        local tx = 130 
        for i, pg in ipairs(self.pages) do
            local w = (7*#pg.name)+20
            if click and not occluded and Lib:IsMouseOver(vector.create(x+tx,y+1,0), vector.create(w,34,0)) then self.activePage = i end
            
            local isActive = (self.activePage == i)
            Lib.Label(vector.create(x+tx+10,y+10,z+1), pg.name, isActive and Lib.Theme.Accent or Lib.Theme.TextDim, false, winAlpha)
            if isActive then 
                Lib.Rect(vector.create(x+tx,y+34-2,z+1), vector.create(w,2,0), Lib.Theme.Accent, winAlpha)
            end
            tx = tx + w
        end

        if hasSubcategories then
            Lib.Line(vector.create(x+1, y+58, z), vector.create(x+WIN_W-1, y+58, z), Lib.Theme.Border, winAlpha, 1)
            local stx = x + 12
            for _, sub in ipairs(page.subcategories) do
                local sw = (7 * #sub.name) + 20
                local subPos = vector.create(stx, y+36, 0)
                if click and not occluded and Lib:IsMouseOver(subPos, vector.create(sw, 22, 0)) then
                    page.activeSubcategory = sub.name
                    self.scroll = 0
                end

                local activeSub = page.activeSubcategory == sub.name
                Lib.Label(
                    vector.create(stx+10, y+41, z+1),
                    sub.name,
                    activeSub and Lib.Theme.Accent or Lib.Theme.TextDim,
                    false,
                    winAlpha
                )
                if activeSub then
                    Lib.Rect(vector.create(stx, y+56, z+1), vector.create(sw, 2, 0), Lib.Theme.Accent, winAlpha)
                end
                stx = stx + sw
            end
        end
        
        local contentAlpha = self.tabAlpha * winAlpha
        local contentTop = y + 55
        local contentBottom = y + windowHeight - 8

        if page then
            for _, sect in ipairs(page.sections) do
                if not sectionVisible(sect) then continue end
                local sx = (sect.side == "Left") and (x+12) or (x+12+COL_W+12); local sy = y+(sect.ry or contentStart)-self.scroll
                local sh = 28
                for _, it in ipairs(sect.items) do
                    local add = 28
                    if it.type == "slider" or it.type == "rangeslider" then
                        local valueWidth = it.type == "rangeslider" and RANGE_VALUE_W or SLIDER_VALUE_W
                        add = getSliderLayout(it.name, valueWidth).height
                    end
                    if it.type=="dropdown" and it.open then add=add+(#it.options*22)+6 end
                    if it.type=="colorpicker" and it.open then add=add+75 end
                    sh = sh + add
                end

                if sy + sh < contentTop or sy > contentBottom then
                    continue
                end

                local sectionDrawY = math.max(sy, contentTop)
                local visibleSectionHeight = math.min(sh - (sectionDrawY - sy), contentBottom - sectionDrawY)
                if visibleSectionHeight <= 0 then continue end

                Lib.Rect(vector.create(sx,sectionDrawY,z+1), vector.create(COL_W,visibleSectionHeight,0), Lib.Theme.Border, contentAlpha)
                Lib.Rect(vector.create(sx+1,sectionDrawY+1,z+1), vector.create(COL_W-2,math.max(0, visibleSectionHeight-2),0), Lib.Theme.SectionBg, contentAlpha)
                Lib.Rect(vector.create(sx+1,sectionDrawY+1,z+2), vector.create(COL_W-2, 22, 0), Lib.Theme.Header, contentAlpha)
                Lib.Label(vector.create(sx+8,sectionDrawY+5,z+3), sect.name, Lib.Theme.TextDim, false, contentAlpha)
                Lib.Line(vector.create(sx+1,sectionDrawY+23,z+2), vector.create(sx+COL_W-1,sectionDrawY+23,z+2), Lib.Theme.Border, contentAlpha, 1)

                local cy = sy + 30
                for _, item in ipairs(sect.items) do
                    if not item.anim then item.anim = { slide = 0, hover = 0 } end
                    local nmX, valX = sx+10, sx+COL_W-15
                    local iH = 28
                    local sliderLayout
                    if item.type == "slider" or item.type == "rangeslider" then
                        local valueWidth = item.type == "rangeslider" and RANGE_VALUE_W or SLIDER_VALUE_W
                        sliderLayout = getSliderLayout(item.name, valueWidth)
                        iH = sliderLayout.height
                    end
                    if item.type == "dropdown" and item.open then iH = iH + (#item.options * 22) + 6 end
                    if item.type == "colorpicker" and item.open then iH = iH + 75 end
                    local itemVisible = cy >= contentTop and cy + iH <= contentBottom
                    local itemPos = vector.create(sx+4, cy-2, 0)
                    local hover = itemVisible and not occluded and Lib:IsMouseOver(itemPos, vector.create(COL_W-8, 24, 0))
                    local iClick = hover and click
                    item.anim.hover = Lib.Lerp(item.anim.hover, hover and 1 or 0, dt * 10)

                    if itemVisible and item.type == "toggle" then
                        if iClick then 
                            item.value = not item.value; if item.callback then item.callback(item.value) end
                            if item.flag then Lib.Flags[item.flag] = item.value end 
                        end
                        local targetSlide = item.value and 1 or 0
                        item.anim.slide = Lib.Lerp(item.anim.slide, targetSlide, dt * 12)
                        local swW = 22; local swX = valX - swW
                        Lib.Label(vector.create(nmX, cy+4, z+3), item.name, item.value and Lib.Theme.Text or Lib.Theme.TextDim, false, contentAlpha)
                        local curCol = Lib.LerpColor(Lib.Theme.SwitchBg, Lib.Theme.Accent, item.anim.slide)
                        Lib.Circle(vector.create(swX, cy+10, z+3), 6, curCol, contentAlpha)
                        Lib.Circle(vector.create(swX+12, cy+10, z+3), 6, curCol, contentAlpha)
                        Lib.Rect(vector.create(swX, cy+4, z+3), vector.create(12, 12, 0), curCol, contentAlpha)
                        local knX = swX + (12 * item.anim.slide)
                        Lib.Circle(vector.create(knX, cy+10, z+4), 4, Lib.Theme.Text, contentAlpha)

                    elseif itemVisible and item.type == "slider" then
                        local valStr = tostring(item.value); local valW = 7 * #valStr
                        local barW = sliderLayout.barWidth
                        local barX = sx + 10
                        local valueStart = barX + barW + SLIDER_GAP
                        if not sliderLayout.topLabel then
                            barX = sx + 10 + sliderLayout.labelWidth + SLIDER_GAP
                            valueStart = barX + barW + SLIDER_GAP
                        end
                        local controlY = sliderLayout.topLabel and (cy + 18) or cy
                        local barY = controlY + 10
                        local sliderPos = vector.create(barX - 8, barY - 8, 0)
                        local sliderHover = not occluded and Lib:IsMouseOver(sliderPos, vector.create(barW + 16, 16, 0))
                        if sliderHover and isleftpressed() and not Lib.State.InputBusy then
                            local bx = barX
                            local pct = math.clamp((Lib.State.MousePos.x - bx) / barW, 0, 1)
                            local nv = math.floor(item.min + (item.max - item.min) * pct)
                            if nv ~= item.value then
                                item.value = nv; if item.callback then item.callback(nv) end; if item.flag then Lib.Flags[item.flag] = nv end
                            end
                            Lib.State.InputBusy = true
                        end
                        if sliderLayout.topLabel then
                            Lib.Label(vector.create(sx + (COL_W / 2), cy + 2, z+3), item.name, Lib.Theme.Text, true, contentAlpha)
                        else
                            Lib.Label(vector.create(nmX, cy + 4, z+3), item.name, Lib.Theme.Text, false, contentAlpha)
                        end
                        Lib.Label(vector.create(valueStart + ((SLIDER_VALUE_W - valW) / 2), controlY + 4, z+3), valStr, Lib.Theme.TextDim, false, contentAlpha)
                        Lib.Rect(vector.create(barX, barY, z+3), vector.create(barW, 2, 0), Lib.Theme.SwitchBg, contentAlpha)
                        local targetFill = ((item.value - item.min)/(item.max - item.min)) * barW
                        item.anim.slide = Lib.Lerp(item.anim.slide, targetFill, dt * 15)
                        Lib.Rect(vector.create(barX, barY, z+3), vector.create(item.anim.slide, 2, 0), Lib.Theme.Accent, contentAlpha)
                        Lib.Circle(vector.create(barX+item.anim.slide, barY+1, z+4), 4, Lib.Theme.Text, contentAlpha)

                    elseif itemVisible and item.type == "rangeslider" then
                        local barW = sliderLayout.barWidth
                        local barX = sx + 10
                        local valueStart = barX + barW + SLIDER_GAP
                        if not sliderLayout.topLabel then
                            barX = sx + 10 + sliderLayout.labelWidth + SLIDER_GAP
                            valueStart = barX + barW + SLIDER_GAP
                        end
                        local controlY = sliderLayout.topLabel and (cy + 18) or cy
                        local barY = controlY + 10
                        local range = math.max(item.max - item.min, item.step)
                        local minPct = math.clamp((item.lower - item.min) / range, 0, 1)
                        local maxPct = math.clamp((item.upper - item.min) / range, 0, 1)
                        local minX = barX + (minPct * barW)
                        local maxX = barX + (maxPct * barW)
                        local sliderPos = vector.create(sx + 4, cy - 2, 0)
                        local sliderHover = not occluded and Lib:IsMouseOver(sliderPos, vector.create(COL_W - 8, iH, 0))

                        local function snapValue(mouseX)
                            local pct = math.clamp((mouseX - barX) / barW, 0, 1)
                            local raw = item.min + (range * pct)
                            local snapped = item.min + (math.round((raw - item.min) / item.step) * item.step)
                            return math.clamp(snapped, item.min, item.max)
                        end

                        if click and sliderHover then
                            local mouseX = Lib.State.MousePos.x
                            item.dragging = math.abs(mouseX - minX) <= math.abs(mouseX - maxX) and "lower" or "upper"
                        end
                        if not isleftpressed() then item.dragging = nil end
                        if item.dragging == "lower" and isleftpressed() then
                            item.lower = math.min(snapValue(Lib.State.MousePos.x), item.upper - item.step)
                            item.lower = math.max(item.min, item.lower)
                            if item.callback then item.callback(item.lower, item.upper) end
                            if item.flag then Lib.Flags[item.flag] = {Min=item.lower, Max=item.upper} end
                            Lib.State.InputBusy = true
                        elseif item.dragging == "upper" and isleftpressed() then
                            item.upper = math.max(snapValue(Lib.State.MousePos.x), item.lower + item.step)
                            item.upper = math.min(item.max, item.upper)
                            if item.callback then item.callback(item.lower, item.upper) end
                            if item.flag then Lib.Flags[item.flag] = {Min=item.lower, Max=item.upper} end
                            Lib.State.InputBusy = true
                        end

                        if sliderLayout.topLabel then
                            Lib.Label(vector.create(sx + (COL_W / 2), cy + 2, z+3), item.name, Lib.Theme.Text, true, contentAlpha)
                        else
                            Lib.Label(vector.create(nmX, cy + 4, z+3), item.name, Lib.Theme.Text, false, contentAlpha)
                        end
                        Lib.Label(vector.create(valueStart, controlY+4, z+3), tostring(item.lower) .. "-" .. tostring(item.upper), Lib.Theme.TextDim, false, contentAlpha)
                        Lib.Rect(vector.create(barX, barY, z+3), vector.create(barW, 2, 0), Lib.Theme.SwitchBg, contentAlpha)
                        Lib.Rect(vector.create(minX, barY, z+3), vector.create(math.max(1, maxX-minX), 2, 0), Lib.Theme.Accent, contentAlpha)
                        Lib.Circle(vector.create(minX, barY+1, z+4), 4, Lib.Theme.Text, contentAlpha)
                        Lib.Circle(vector.create(maxX, barY+1, z+4), 4, Lib.Theme.Text, contentAlpha)

                    elseif itemVisible and item.type == "dropdown" then
                        if iClick then item.open = not item.open end
                        local dispText = item.selected
                        if item.multi then
                            local active = {}; for k,v in pairs(item.selected) do if v then table.insert(active, k) end end
                            if #active == 0 then dispText = "None" elseif #active <= 3 then dispText = table.concat(active, ", ") else dispText = #active .. " Selected" end
                        end
                        local labelLines = Lib.LabelWrapped(vector.create(nmX, cy+4, z+3), item.name, Lib.Theme.Text, valX - nmX - 30, false, contentAlpha)
                        if labelLines > 1 then iH = 46 end
                        Lib.Label(vector.create(valX-(7*#dispText)-15, cy+4, z+3), dispText, Lib.Theme.Accent, false, contentAlpha)
                        local triC = item.open and Lib.Theme.Accent or Lib.Theme.TextDim; local cx, cy_c = valX-5, cy+10
                        if item.open then Lib.Triangle(vector.create(cx, cy_c-3, z+3), vector.create(cx-4, cy_c+2, z+3), vector.create(cx+4, cy_c+2, z+3), triC, contentAlpha)
                        else Lib.Triangle(vector.create(cx, cy_c+3, z+3), vector.create(cx-4, cy_c-2, z+3), vector.create(cx+4, cy_c-2, z+3), triC, contentAlpha) end
                        if item.open then
                            local dy = cy + 28
                            Lib.Rect(vector.create(sx+10, dy-2, z+4), vector.create(COL_W-20, #item.options*22 + 4, 0), Lib.Theme.Header, contentAlpha)
                            Lib.Outline(vector.create(sx+10, dy-2, z+4), vector.create(COL_W-20, #item.options*22 + 4, 0), Lib.Theme.Border, contentAlpha)
                            for _, opt in ipairs(item.options) do
                                local oPos = vector.create(sx+12, dy, 0); local oSize = vector.create(COL_W-24, 20, 0)
                                if Lib:IsMouseOver(oPos, oSize) then
                                    Lib.Rect(oPos, oSize, Lib.Theme.Hover, contentAlpha)
                                    if click then
                                        if item.multi then item.selected[opt] = not item.selected[opt]; if item.callback then item.callback(item.selected) end; if item.flag then Lib.Flags[item.flag] = item.selected end
                                        else item.selected = opt; item.open = false; if item.callback then item.callback(opt) end; if item.flag then Lib.Flags[item.flag] = opt end end
                                    end
                                end
                                local isSel = false; if item.multi then isSel = item.selected[opt] else isSel = (item.selected == opt) end
                                Lib.Label(vector.create(sx+18, dy+3, z+5), opt, isSel and Lib.Theme.Accent or Lib.Theme.Text, false, contentAlpha)
                                dy = dy + 22
                            end
                            iH = iH + (#item.options * 22) + 6
                        end
                    elseif itemVisible and item.type == "button" then
                        if item.anim.hover > 0.01 then Lib.Rect(vector.create(sx+8, cy+2, z+2), vector.create(COL_W-16, 20, 0), Lib.Theme.Hover, item.anim.hover * contentAlpha) end
                        Lib.Outline(vector.create(sx+8, cy+2, z+2), vector.create(COL_W-16, 20, 0), Lib.Theme.Border, contentAlpha)
                        if iClick and item.callback then item.callback() end
                        local txtCol = Lib.LerpColor(Lib.Theme.Text, Lib.Theme.Accent, item.anim.hover)
                        Lib.Label(vector.create(nmX, cy+4, z+3), item.name, txtCol, false, contentAlpha)
                    elseif itemVisible and item.type == "colorpicker" then
                        if iClick then item.open = not item.open end
                        local labelLines = Lib.LabelWrapped(vector.create(nmX, cy + 4, z+3), item.name, Lib.Theme.Text, valX - nmX - 30, false, contentAlpha)
                        if labelLines > 1 then iH = 46 end
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
                            if nc ~= item.color then item.color = nc; if item.callback then item.callback(nc) end; if item.flag then Lib.Flags[item.flag] = {R=nc.R, G=nc.G, B=nc.B} end end
                            iH = iH + 75
                        end
                    elseif itemVisible and item.type == "textbox" then
                        local boxPos = vector.create(sx + 105, cy + 1, z + 3)
                        local boxSize = vector.create(COL_W - 120, 22, 0)
                        if click and Lib:IsMouseOver(boxPos, boxSize) then item.focused = true end
                        if click and not Lib:IsMouseOver(boxPos, boxSize) then item.focused = false end

                        item.cursor = item.cursor or (#item.text + 1)
                        if item.focused then
                            local pressed = getpressedkeys()
                            item.keyState = item.keyState or {}
                            local now = os.clock()
                            local function deletePrevious()
                                if item.cursor > 1 then
                                    item.text = string.sub(item.text, 1, item.cursor - 2) .. string.sub(item.text, item.cursor)
                                    item.cursor = item.cursor - 1
                                end
                            end
                            if pressed then
                                local current = {}
                                local shift = false
                                for _, key in ipairs(pressed) do
                                    if key == "LeftShift" or key == "RightShift" then shift = true end
                                end
                                for _, key in ipairs(pressed) do
                                    current[key] = true
                                    if not item.keyState[key] then
                                        local mapped = textFromKey(key)
                                        if mapped == "BACKSPACE" then
                                            deletePrevious()
                                            item.repeatKey = key
                                            item.repeatAt = now + 0.5
                                        elseif mapped == "DELETE" then
                                            item.text = string.sub(item.text, 1, item.cursor - 1) .. string.sub(item.text, item.cursor + 1)
                                        elseif mapped == "ENTER" then
                                            item.focused = false
                                        elseif mapped == "ESCAPE" then
                                            item.focused = false
                                        elseif mapped == "LEFT" then
                                            item.cursor = math.max(1, item.cursor - 1)
                                        elseif mapped == "RIGHT" then
                                            item.cursor = math.min(#item.text + 1, item.cursor + 1)
                                        elseif mapped == "HOME" then
                                            item.cursor = 1
                                        elseif mapped == "END" then
                                            item.cursor = #item.text + 1
                                        elseif mapped then
                                            local character = shift and mapped:upper() or mapped
                                            item.text = string.sub(item.text, 1, item.cursor - 1) .. character .. string.sub(item.text, item.cursor)
                                            item.cursor = item.cursor + #character
                                        end
                                    elseif key == item.repeatKey and key == "Backspace" and now >= (item.repeatAt or math.huge) then
                                        deletePrevious()
                                        item.repeatAt = now + 0.3
                                    end
                                end
                                item.keyState = current
                                if item.repeatKey and not current[item.repeatKey] then
                                    item.repeatKey = nil
                                    item.repeatAt = nil
                                end
                            else
                                item.keyState = {}
                            end
                            if item.callback then item.callback(item.text) end
                            if item.flag then Lib.Flags[item.flag] = item.text end
                        end

                        Lib.Label(vector.create(nmX, cy + 5, z + 4), item.name, Lib.Theme.Text, false, contentAlpha)
                        local boxBorder = item.focused and Lib.Theme.Accent or Lib.Theme.Border
                        Lib.Rect(boxPos, boxSize, boxBorder, contentAlpha)
                        Lib.Rect(vector.create(boxPos.x + 1, boxPos.y + 1, z + 3), vector.create(boxSize.x - 2, boxSize.y - 2, 0), Lib.Theme.Header, contentAlpha)
                        local maxChars = math.max(1, math.floor((boxSize.x - 14) / 7))
                        local startChar = math.max(1, math.min(item.cursor - maxChars, #item.text - maxChars + 1))
                        local visibleText = string.sub(item.text, startChar, startChar + maxChars - 1)
                        Lib.Label(vector.create(boxPos.x + 7, boxPos.y + 5, z + 4), visibleText, item.focused and Lib.Theme.Text or Lib.Theme.TextDim, false, contentAlpha)
                        if item.focused then
                            local caretIndex = math.max(0, item.cursor - startChar)
                            Lib.Rect(vector.create(boxPos.x + 7 + (caretIndex * 7), boxPos.y + 4, z + 4), vector.create(1, 14, 0), Lib.Theme.Accent, contentAlpha)
                        end
                    elseif itemVisible and item.type == "binder" then
                        if Lib.State.RightMouseDown and not Lib.State.RightMouseHeld and not Lib.State.ContextMenu.IsOpen and hover then
                            Lib.State.ContextMenu = {
                                IsOpen = true,
                                Pos = Lib.State.MousePos,
                                Target = item,
                                Type = "binderMode"
                            }
                        end
                        if iClick then item.listening = not item.listening end
                        if item.listening then
                            local keys = getpressedkeys()
                            if keys then
                                for _, k in ipairs(keys) do
                                    if k ~= "Unknown" and k ~= "LeftMouse" then
                                        item.key = k; item.listening = false
                                        if item.callback then item.callback(k) end; if item.flag then Lib.Flags[item.flag] = k end
                                    end
                                end
                            end
                        end
                        local txt = "[" .. (item.listening and "?" or item.key) .. "]"
                        txt = txt .. " " .. (item.mode or "Toggle")
                        local keyW = (7 * #txt)
                        local labelLines = Lib.LabelWrapped(vector.create(nmX, cy + 4, z+3), item.name, Lib.Theme.Text, valX - nmX - keyW - 10, false, contentAlpha)
                        if labelLines > 1 then iH = 46 end
                        Lib.Label(vector.create(valX - keyW, cy + 4, z+3), txt, item.listening and Lib.Theme.Accent or Lib.Theme.TextDim, false, contentAlpha)
                    end
                    cy = cy + iH
                end
            end
        end

        -- Cover content that was drawn outside the scroll viewport.
        Lib.Rect(
            vector.create(x + 1, y + 35, z + 100),
            vector.create(WIN_W - 2, math.max(0, contentTop - (y + 35)), 0),
            Lib.Theme.Background,
            winAlpha
        )
        Lib.Rect(
            vector.create(x + 1, contentBottom, z + 100),
            vector.create(WIN_W - 2, math.max(0, (y + windowHeight) - contentBottom - 1), 0),
            Lib.Theme.Background,
            winAlpha
        )

        if hasSubcategories then
            Lib.Line(vector.create(x+1, y+58, z+101), vector.create(x+WIN_W-1, y+58, z+101), Lib.Theme.Border, winAlpha, 1)
            local redrawX = x + 12
            for _, sub in ipairs(page.subcategories) do
                local subWidth = (7 * #sub.name) + 20
                local activeSub = page.activeSubcategory == sub.name
                Lib.Label(
                    vector.create(redrawX+10, y+41, z+102),
                    sub.name,
                    activeSub and Lib.Theme.Accent or Lib.Theme.TextDim,
                    false,
                    winAlpha
                )
                if activeSub then
                    Lib.Rect(vector.create(redrawX, y+56, z+102), vector.create(subWidth, 2, 0), Lib.Theme.Accent, winAlpha)
                end
                redrawX = redrawX + subWidth
            end
        end

        if maxScroll > 0 then
            local trackX = x + WIN_W - 8
            local trackY = y + 42
            local trackH = windowHeight - 50
            local thumbH = math.max(24, trackH * (windowHeight / contentHeight))
            local thumbTravel = trackH - thumbH
            local thumbY = trackY + (maxScroll > 0 and (self.scroll / maxScroll) * thumbTravel or 0)
            local thumbPos = vector.create(trackX, thumbY, z + 5)
            local thumbSize = vector.create(5, thumbH, 0)

            if click and Lib:IsMouseOver(thumbPos, thumbSize) then
                self.scrollDragging = true
                self.scrollDragOffset = Lib.State.MousePos.y - thumbY
            end

            if not Lib.State.MouseDown then self.scrollDragging = false end
            if self.scrollDragging and Lib.State.MouseDown then
                local nextY = Lib.State.MousePos.y - (self.scrollDragOffset or 0)
                local pct = math.clamp((nextY - trackY) / thumbTravel, 0, 1)
                self.scroll = pct * maxScroll
                Lib.State.InputBusy = true
            end

            Lib.Rect(vector.create(trackX, trackY, z + 4), vector.create(5, trackH, 0), Lib.Theme.SwitchBg, winAlpha)
            Lib.Rect(thumbPos, thumbSize, Lib.Theme.Accent, winAlpha)
        end
    end
    
    function window:Page(p)
        for _, pg in ipairs(self.pages) do if pg.name == p.Name then return pg end end
        local pg = {name=p.Name, sections={}, subcategories={}, activeSubcategory=nil}
        function pg:Subcategory(p)
            for _, sub in ipairs(self.subcategories) do
                if sub.name == p.Name then return sub end
            end
            local sub = {name=p.Name}
            table.insert(self.subcategories, sub)
            if not self.activeSubcategory then self.activeSubcategory = sub.name end
            return sub
        end
        function pg:Section(p)
            local sec = {name=p.Name, side=p.Side or "Left", subcategory=p.Subcategory, items={}}
            function sec:Toggle(p) table.insert(sec.items, {type="toggle", name=p.Name, value=p.Default or false, callback=p.Callback, flag=p.Flag}); if p.Flag then Lib.Flags[p.Flag] = p.Default or false end end
            function sec:Slider(p) table.insert(sec.items, {type="slider", name=p.Name, value=p.Default or p.Min, min=p.Min, max=p.Max, callback=p.Callback, flag=p.Flag}); if p.Flag then Lib.Flags[p.Flag] = p.Default or p.Min end end
            function sec:RangeSlider(p)
                local step = p.Step or 1
                local lower = p.DefaultMin or p.Min
                local upper = p.DefaultMax or p.Max
                local item = {type="rangeslider", name=p.Name, min=p.Min, max=p.Max, step=step, lower=lower, upper=upper, callback=p.Callback, flag=p.Flag}
                table.insert(sec.items, item)
                if p.Flag then Lib.Flags[p.Flag] = {Min=lower, Max=upper} end
                return item
            end
            function sec:Dropdown(p)
                local sel = p.Default
                if p.Multi and type(sel) ~= "table" then sel = {} end
                local item = {type="dropdown", name=p.Name, options=p.Options, selected=sel, open=false, multi=p.Multi, callback=p.Callback, flag=p.Flag}
                table.insert(sec.items, item)
                if p.Flag then Lib.Flags[p.Flag] = sel end
                return item
            end
            function sec:Button(p) local item = {type="button", name=p.Name, callback=p.Callback}; table.insert(sec.items, item); return item end
            function sec:ColorPicker(p) local c = p.Default or Color3.new(1,1,1); table.insert(sec.items, {type="colorpicker", name=p.Name, color=c, open=false, callback=p.Callback, flag=p.Flag}); if p.Flag then Lib.Flags[p.Flag] = {R=c.R, G=c.G, B=c.B} end end
            function sec:Textbox(p)
                local text = p.Default or ""
                local item = {type="textbox", name=p.Name, text=text, cursor=#text + 1, focused=false, keyState={}, callback=p.Callback, flag=p.Flag}
                table.insert(sec.items, item)
                if p.Flag then Lib.Flags[p.Flag] = item.text end
                return item
            end
            function sec:Binder(p)
                local mode = (p.Mode == "Hold" or p.Mode == "Tap") and p.Mode or "Toggle"
                local item = {
                    type="binder",
                    name=p.Name,
                    key=p.Default or "None",
                    mode=mode,
                    active=false,
                    wasPressed=false,
                    listening=false,
                    callback=p.Callback,
                    actionCallback=p.ActionCallback,
                    flag=p.Flag
                }
                table.insert(sec.items, item)
                if p.Flag then Lib.Flags[p.Flag] = {Key=item.key, Mode=item.mode, Active=false} end
            end
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
    local ren = game:GetService("RunService").Render
    
    ren:Connect(function()
        self.State.InputBusy = false
        
        self:UpdateInput()
        self:RenderNotifications()
        
        if self.FocusedWindow then
            local idx = self:FindWindowIndex(self.FocusedWindow)
            if idx then
                table.remove(self.Windows, idx)
                table.insert(self.Windows, self.FocusedWindow)
            end
            self.FocusedWindow = nil
        end

        if self.FocusedWidget then
            self:BringToFront(self.FocusedWidget)
            self.FocusedWidget = nil
        end

        if not self.State.ContextMenu then
            self.State.ContextMenu = { IsOpen = false, Pos = vector.create(0, 0, 0), Target = nil }
        end

        if self.State.RightMouseDown and not self.State.RightMouseHeld and not self.State.ContextMenu.IsOpen then
            if self.State.EditMode then
                for i = #self.Widgets, 1, -1 do
                    local w = self.Widgets[i]
                    if self:IsMouseOver(w.pos, w.size) then
                        self.State.ContextMenu = {
                            IsOpen = true,
                            Pos = self.State.MousePos,
                            Target = w
                        }
                        break 
                    end
                end
            end
        end

        for i = 1, #self.Widgets do
            local w = self.Widgets[i]
            w.z = self.Layer.Base + (i * 5)
            w:Draw(self)
        end

        for i = 1, #self.Windows do
            self.Windows[i]:Draw(self)
        end
        
        if self.State.ContextMenu.IsOpen then
            local menu = self.State.ContextMenu
            local isBinderMenu = menu.Type == "binderMode"
            local options = isBinderMenu and {"Toggle", "Hold", "Tap"} or {"Bring to Front", "Send to Back", "Bring Forward", "Send Backward"}
            local menuSize = vector.create(150, (#options * 22) + 10, 0)
            local z = self.Layer.Popup
            local click = self.State.MouseDown and not self.State.MouseHeld
            
            self.Rect(menu.Pos, menuSize, self.Theme.Border, 1)
            self.Rect(vector.create(menu.Pos.x + 1, menu.Pos.y + 1, 0), vector.create(menuSize.x-2, menuSize.y-2,0), self.Theme.Header, 1)
            
            local yOff = 5
            for _, opt in ipairs(options) do
                local optPos = vector.create(menu.Pos.x + 5, menu.Pos.y + yOff, 0)
                local hover = self:IsMouseOver(optPos, vector.create(menuSize.x - 10, 20, 0))
                
                if hover then
                    self.Rect(optPos, vector.create(menuSize.x - 10, 20, 0), self.Theme.Hover, 1)
                    if click then
                        if isBinderMenu then
                            menu.Target.mode = opt
                            menu.Target.active = false
                            menu.Target.wasPressed = false
                            if menu.Target.flag then
                                self.Flags[menu.Target.flag] = {
                                    Key = menu.Target.key,
                                    Mode = opt,
                                    Active = false
                                }
                            end
                        elseif opt == "Bring to Front" then self:BringToFront(menu.Target)
                        elseif opt == "Send to Back" then self:SendToBack(menu.Target)
                        elseif opt == "Bring Forward" then self:BringForward(menu.Target)
                        elseif opt == "Send Backward" then self:SendBackward(menu.Target) end
                        self.State.ContextMenu.IsOpen = false
                    end
                end
                
                self.Label(vector.create(optPos.x + 5, optPos.y + 3, z + 1), opt, self.Theme.Text, false, 1)
                yOff = yOff + 22
            end

            if click and not self:IsMouseOver(menu.Pos, menuSize) then
                self.State.ContextMenu.IsOpen = false
            end
        end

        for _, line in ipairs(self.State.Snapping.ActiveLines) do
            self.Line(line.A, line.B, self.Theme.SnapLine, line.Alpha, 2)
        end
        
        if self.State.EditMode and self.State.Enabled and self.State.MenuAlpha > 0.01 then
            local st = "LAYOUT EDITOR ENABLED"
            local sw = 7 * #st
            local sp = vector.create((self.State.ScreenSize.x/2)-(sw/2), 10, self.Layer.Notif)
            
            self.Rect(vector.create(sp.x-8, sp.y-4, 0), vector.create(sw+16, 22, 0), self.Theme.Background, 0.9 * self.State.MenuAlpha)
            self.Outline(vector.create(sp.x-8, sp.y-4, 0), vector.create(sw+16, 22, 0), self.Theme.EditModeText, 1 * self.State.MenuAlpha)
            self.Label(sp, st, self.Theme.EditModeText, false, 1 * self.State.MenuAlpha)
        end
        
        if self.State.Watermark.Visible and self.State.Enabled then
             local p, t = self.State.Watermark.Pos, self.State.Watermark.Text
             local w = (7*#t)+20
             local alpha = self.State.MenuAlpha
             
             if self.State.EditMode and self.State.MouseDown and not self.State.MouseHeld and self:IsMouseOver(p, vector.create(w, 24, 0)) then
                 self.State.Watermark.Dragging = true
                 self.State.Watermark.Offset = vector.create(self.State.MousePos.x - p.x, self.State.MousePos.y - p.y, 0)
             end
             
             if self.State.Watermark.Dragging then
                 if self.State.MouseDown then
                     local raw = vector.create(self.State.MousePos.x - self.State.Watermark.Offset.x, self.State.MousePos.y - self.State.Watermark.Offset.y, 0)
                     local dummy = { pos = raw, size = vector.create(w, 24, 0) }
                     if self.CalculateDragSnap then
                         self.State.Watermark.Pos = self:CalculateDragSnap(dummy, raw)
                     else
                         self.State.Watermark.Pos = raw
                     end
                 else
                     self.State.Watermark.Dragging = false
                 end
             end

             self.Rect(p, vector.create(w, 24, 0), self.Theme.Border, alpha)
             self.Rect(vector.create(p.x+1,p.y+1,1), vector.create(w-2, 22, 0), self.Theme.Background, alpha)
             self.Rect(p, vector.create(2,24,0), self.Theme.Accent, alpha)
             self.Label(vector.create(p.x+10,p.y+5,3), t, self.Theme.Text, false, alpha)
        end
    end)
end
return Module
