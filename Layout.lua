-- Dock geometry and order rules. No game API here, so tests can load it as is.
local _, ns = ...

local floor, max = math.floor, math.max

-- Unit step along the line for each direction.
local DIR = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

function ns.Horizontal(dir)
    return dir == "LEFT" or dir == "RIGHT"
end

-- Centers of n icons, as offsets from the handle's center, plus the box around icons and handle.
-- cfg: dir, perRow (0 = one line), size, gap, handle (the handle's length along the line),
-- wrap (1: extra rows go up / columns go right; -1: down / left).
function ns.Slots(n, cfg)
    local d = DIR[cfg.dir] or DIR.LEFT
    local size, gap = cfg.size, cfg.gap
    local step = size + gap
    local per = (cfg.perRow and cfg.perRow > 0) and cfg.perRow or max(n, 1)
    local first = cfg.handle / 2 + gap + size / 2
    local wrap = cfg.wrap or 1

    -- The handle: `handle` long along the line, `size` across it.
    local hx, hy
    if d[1] ~= 0 then hx, hy = cfg.handle / 2, size / 2 else hx, hy = size / 2, cfg.handle / 2 end
    local box = { left = -hx, right = hx, bottom = -hy, top = hy }

    local slots = {}
    for i = 1, n do
        local col, row = (i - 1) % per, floor((i - 1) / per)
        local along, across = first + col * step, row * step * wrap
        local x, y
        if d[1] ~= 0 then x, y = along * d[1], across else x, y = across, along * d[2] end
        slots[i] = { x = x, y = y }
        local h = size / 2
        if x - h < box.left then box.left = x - h end
        if x + h > box.right then box.right = x + h end
        if y - h < box.bottom then box.bottom = y - h end
        if y + h > box.top then box.top = y + h end
    end
    return slots, box
end

-- Index of the slot nearest (x, y), or nil when there are none.
function ns.Nearest(slots, x, y)
    local best, bestD
    for i, s in ipairs(slots) do
        local dx, dy = s.x - x, s.y - y
        local dd = dx * dx + dy * dy
        if not bestD or dd < bestD then best, bestD = i, dd end
    end
    return best
end

local function IndexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
end
ns.IndexOf = IndexOf

-- Adds key at the end of order if it isn't there yet.
function ns.MergeOrder(order, key)
    if not IndexOf(order, key) then order[#order + 1] = key end
end

-- Moves key to where the shown icon in slot t is. `shown` = keys of the icons on screen, in order.
-- Icons that aren't shown (hidden by their addon, not loaded) keep their places among the rest.
function ns.Reorder(order, shown, key, t)
    local target = shown[t]
    if not target or target == key then return false end
    local from = IndexOf(shown, key)
    local i = IndexOf(order, key)
    if not i then return false end
    table.remove(order, i)
    local j = IndexOf(order, target)
    if not j then
        table.insert(order, i, key)
        return false
    end
    -- Dragged forward: lands after the target; dragged back: before it.
    if from and from < t then j = j + 1 end
    table.insert(order, j, key)
    return true
end

-- Moves key one place up (delta -1) or down (+1) in order.
function ns.Move(order, key, delta)
    local i = IndexOf(order, key)
    local j = i and i + delta
    if not j or j < 1 or j > #order then return false end
    order[i], order[j] = order[j], order[i]
    return true
end

-- Our addons mark "something waits for you" with a gold border (1, 0.82, 0).
function ns.IsGold(r, g, b)
    return type(r) == "number" and type(g) == "number" and type(b) == "number"
        and r > 0.8 and g > 0.55 and g < 0.95 and b < 0.35
end
