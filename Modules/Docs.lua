local Module = {}

Module.DocWindows = {}

function Module.CreateDocWindow(self, props)
    local docWin = {
        name = props.Name or "Documentation",
        pos = props.Position or vector.create(300, 300, 0),
        size = vector.create(500, 350, 0),
        dragging = false,
        dragOffset = vector.create(0, 0, 0),
        pages = {},
        activePage = "",
        visible = props.Visible or false
    }

    function docWin:AddPage(id, title, contentCallback)
        self.pages[id] = {
            title = title,
            render = contentCallback
        }
        if self.activePage == "" then self.activePage = id end
    end

    function docWin:Navigate(id)
        if self.pages[id] then
            self.activePage = id
        end
    end

    function docWin:Draw(Lib)
        if not Lib.State.Enabled or not self.visible then return end

        local click = Lib.State.MouseDown and not Lib.State.MouseHeld
        if click and Lib:IsMouseOver(self.pos, self.size) then
            Lib.FocusedWindow = self
        end

        Lib:HandleDraggable(self, true, vector.create(self.size.x, 34, 0))

        local x, y, z = self.pos.x, self.pos.y, Lib.Layer.Base
        local winAlpha = Lib.State.MenuAlpha
        if winAlpha < 0.01 then return end

        Lib.Rect(vector.create(x, y, z), self.size, Lib.Theme.Border, winAlpha)
        Lib.Rect(vector.create(x + 1, y + 1, z), vector.create(self.size.x - 2, self.size.y - 2, 0), Lib.Theme.Background, winAlpha)

        Lib.Rect(vector.create(x + 1, y + 1, z), vector.create(self.size.x - 2, 34, 0), Lib.Theme.Header, winAlpha)
        Lib.Label(vector.create(x + 12, y + 10, z + 1), self.name, Lib.Theme.Text, false, winAlpha)
        Lib.Line(vector.create(x + 1, y + 34, z), vector.create(x + self.size.x - 1, y + 34, z), Lib.Theme.Border, winAlpha, 1)

        local sidebarW = 140
        Lib.Rect(vector.create(x + 1, y + 35, z), vector.create(sidebarW, self.size.y - 36, 0), Lib.Theme.SectionBg, winAlpha)
        Lib.Line(vector.create(x + sidebarW + 1, y + 35, z), vector.create(x + sidebarW + 1, y + self.size.y - 1, z), Lib.Theme.Border, winAlpha, 1)

        local sidebarY = y + 45
        for id, pg in pairs(self.pages) do
            local linkPos = vector.create(x + 10, sidebarY, 0)
            local isCurrent = (self.activePage == id)
            local hover = Lib:IsMouseOver(linkPos, vector.create(sidebarW - 20, 20, 0))

            if hover then
                Lib.Rect(linkPos, vector.create(sidebarW - 20, 20, 0), Lib.Theme.Hover, winAlpha)
                if click then self:Navigate(id) end
            end

            Lib.Label(vector.create(x + 15, sidebarY + 3, z + 1), pg.title, isCurrent and Lib.Theme.Accent or Lib.Theme.TextDim, false, winAlpha)
            sidebarY = sidebarY + 24
        end

        local active = self.pages[self.activePage]
        if active then
            local contentX = x + sidebarW + 20
            local contentY = y + 50
            local currentZ = z + 1

            local PageRenderer = {}
            PageRenderer.Y = contentY
            
            function PageRenderer:Header(txt)
                Lib.Label(vector.create(contentX, self.Y, currentZ), txt, Lib.Theme.Text, false, winAlpha)
                self.Y = self.Y + 22
            end

            function PageRenderer:Text(txt)
                local lines = Lib.WrapText(txt, 45) 
                for _, line in ipairs(lines) do
                    Lib.Label(vector.create(contentX, self.Y, currentZ), line, Lib.Theme.TextDim, false, winAlpha)
                    self.Y = self.Y + 18
                end
            end

            function PageRenderer:Space(h)
                self.Y = self.Y + (h or 12)
            end

            function PageRenderer:Link(text, targetId)
                local w = (7 * #text) + 10
                local linkPos = vector.create(contentX, self.Y, 0)
                local hover = Lib:IsMouseOver(linkPos, vector.create(w, 16, 0))

                if hover then
                    Lib.Rect(linkPos, vector.create(w, 16, 0), Lib.Theme.Hover, winAlpha)
                    if click then docWin:Navigate(targetId) end
                end

                Lib.Label(vector.create(contentX + 5, self.Y + 1, currentZ), text, Lib.Theme.Link, false, winAlpha)
                self.Y = self.Y + 20
            end

            active.render(PageRenderer)
        end
    end

    table.insert(self.Windows, docWin)
    return docWin
end

return Module
