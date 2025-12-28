local Module = {}

-- Math Helpers
function Module.Lerp(a, b, t) return a + (b - a) * t end
function Module.LerpColor(c1, c2, t)
    return Color3.new(Module.Lerp(c1.R, c2.R, t), Module.Lerp(c1.G, c2.G, t), Module.Lerp(c1.B, c2.B, t))
end

function Module.FitText(text, maxWidth)
    local charWidth = 7 
    if (#text * charWidth) > maxWidth then return string.sub(text, 1, math.floor(maxWidth / charWidth) - 2) .. ".." end
    return text
end

-- Drawing Wrappers (Direct access to global DrawingImmediate)
function Module.Rect(pos, size, color, alpha) DrawingImmediate.FilledRectangle(pos, size, color, alpha or 1) end
function Module.Outline(pos, size, color, alpha) DrawingImmediate.Rectangle(pos, size, color, alpha or 1, 1) end
function Module.Label(pos, text, color, center, alpha) DrawingImmediate.Text(pos, 13, color, alpha or 1, text, center or false, "Proggy") end
function Module.Line(a, b, color, alpha, thickness) DrawingImmediate.Line(a, b, color, alpha or 1, 1, thickness or 1) end
function Module.Circle(pos, radius, color, alpha) DrawingImmediate.FilledCircle(pos, radius, color, alpha or 1) end
function Module.Triangle(a, b, c, color, alpha) DrawingImmediate.FilledTriangle(a, b, c, color, alpha or 1) end

return Module
