local mq = require 'mq'
local imgui = require 'ImGui'
local boxhud = require 'boxhud'

local open, show = true, true

local function embeddedboxhud(boxhudWindow)
    if not open then return end
    open, show = imgui.Begin('embeddedboxhud', open)
    if show then
        boxhud:Render(boxhudWindow)
    end
    imgui.End()
end

boxhud:Init(nil, true)
local boxhudWindow = boxhud:GetDefaultWindow()
mq.imgui.init('embeddedboxhud', function() embeddedboxhud(boxhudWindow) end)

while open do
    boxhud:Process(boxhudWindow)
    mq.delay(100)
end