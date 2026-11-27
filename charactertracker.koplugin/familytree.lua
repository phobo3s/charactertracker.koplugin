--[[--
Family tree view for Character Tracker.

Built from the family relationships of the characters (father, mother, son,
daughter, brother, sister, spouse): parents above, children below, spouses
side by side with a double line. Other relationship types are not drawn; the
character card lists them.

The tree is drawn once into an off-screen buffer and shown through a window
that moves with swipes, so trees wider or taller than the screen work too.
Tapping a name calls on_tap(character).

Loaded by main.lua with dofile(); returns a function that takes the gettext
function and returns the widget class.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local Screen = Device.screen

-- rel = {target = B, type = t} on character A means "B is A's t".
local PARENT_TYPES = { father = true, mother = true }   -- B is a parent of A
local CHILD_TYPES = { son = true, daughter = true }     -- B is a child of A
local SIBLING_TYPES = { brother = true, sister = true }
local SPOUSE_TYPES = { spouse = true }

local function sortedKeys(set)
    local keys = {}
    for k in pairs(set) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

--- Builds the family graph. Returns nodes (key -> node) and the keys of the
--- nodes that have at least one family link, in character order.
local function buildGraph(characters)
    local nodes, order = {}, {}
    local function node(name)
        local key = name:lower()
        local n = nodes[key]
        if not n then
            n = { key = key, name = name, parents = {}, children = {}, spouses = {}, siblings = {} }
            nodes[key] = n
            table.insert(order, key)
        end
        return n
    end
    for _i, char in ipairs(characters) do
        node(char.name).char = char
    end
    local function link(child, parent)
        child.parents[parent.key] = true
        parent.children[child.key] = true
    end
    for _i, char in ipairs(characters) do
        local a = node(char.name)
        for _j, rel in ipairs(char.relationships or {}) do
            local t = rel.type
            if rel.target and rel.target ~= "" and rel.target:lower() ~= a.key
                    and (PARENT_TYPES[t] or CHILD_TYPES[t] or SIBLING_TYPES[t] or SPOUSE_TYPES[t]) then
                local b = node(rel.target)
                if PARENT_TYPES[t] then
                    link(a, b)
                elseif CHILD_TYPES[t] then
                    link(b, a)
                elseif SIBLING_TYPES[t] then
                    a.siblings[b.key] = true
                    b.siblings[a.key] = true
                else
                    a.spouses[b.key] = true
                    b.spouses[a.key] = true
                end
            end
        end
    end
    -- Siblings share their parents: "Jane is Elizabeth's sister" and "Mr. Bennet
    -- is Elizabeth's father" also put Jane under Mr. Bennet.
    local seen = {}
    for _i, key in ipairs(order) do
        if not seen[key] and next(nodes[key].siblings) then
            local group, queue = {}, { key }
            seen[key] = true
            while #queue > 0 do
                local k = table.remove(queue)
                table.insert(group, nodes[k])
                for s in pairs(nodes[k].siblings) do
                    if not seen[s] then seen[s] = true; table.insert(queue, s) end
                end
            end
            local parents = {}
            for _j, n in ipairs(group) do
                for p in pairs(n.parents) do parents[p] = true end
            end
            for _j, n in ipairs(group) do
                for p in pairs(parents) do link(n, nodes[p]) end
                n.sibling_group = key
            end
        end
    end
    local linked = {}
    for _i, key in ipairs(order) do
        local n = nodes[key]
        if next(n.parents) or next(n.children) or next(n.spouses) or next(n.siblings) then
            table.insert(linked, key)
        end
    end
    return nodes, linked
end

--- Splits the linked nodes into connected families and gives every node a
--- generation (row): parents one row above their children.
local function components(nodes, linked, first_key)
    local comps, done = {}, {}
    local starts = {}
    if first_key and nodes[first_key] then table.insert(starts, first_key) end
    for _i, k in ipairs(linked) do table.insert(starts, k) end
    for _i, start in ipairs(starts) do
        if not done[start] and nodes[start] then
            local n0 = nodes[start]
            if next(n0.parents) or next(n0.children) or next(n0.spouses) or next(n0.siblings) then
                local comp = { keys = {}, gen = {} }
                comp.gen[start] = 0
                done[start] = true
                local queue, qi = { start }, 1
                while qi <= #queue do
                    local k = queue[qi]; qi = qi + 1
                    table.insert(comp.keys, k)
                    local n, g = nodes[k], comp.gen[k]
                    local function visit(set, dg)
                        for _j, o in ipairs(sortedKeys(set)) do
                            if not done[o] then
                                done[o] = true
                                comp.gen[o] = g + dg
                                table.insert(queue, o)
                            end
                        end
                    end
                    visit(n.spouses, 0)
                    visit(n.siblings, 0)
                    visit(n.parents, -1)
                    visit(n.children, 1)
                end
                local min_g = 0
                for _j, k in ipairs(comp.keys) do min_g = math.min(min_g, comp.gen[k]) end
                comp.rows = {}
                for _j, k in ipairs(comp.keys) do
                    local g = comp.gen[k] - min_g + 1
                    comp.gen[k] = g
                    comp.rows[g] = comp.rows[g] or {}
                    table.insert(comp.rows[g], k)
                end
                table.insert(comps, comp)
            end
        end
    end
    return comps
end

--- Places the boxes of one family. Sets comp.x[key] (left edge) and
--- comp.width; rows are comp.rows.
local function layout(nodes, comp, m)
    local x = {}
    comp.x = x
    -- A unit is a person and their married-in spouses (spouses without
    -- parents in this tree), kept side by side.
    local function units(row, g)
        local list, used = {}, {}
        local function inRow(k) return comp.gen[k] == g end
        local function hasParents(k)
            for p in pairs(nodes[k].parents) do
                if comp.gen[p] == g - 1 then return true end
            end
            return false
        end
        local ordered = {}
        for _i, k in ipairs(row) do if hasParents(k) then table.insert(ordered, k) end end
        for _i, k in ipairs(row) do if not hasParents(k) then table.insert(ordered, k) end end
        for _i, k in ipairs(ordered) do
            if not used[k] then
                used[k] = true
                local unit = { k }
                for _j, s in ipairs(sortedKeys(nodes[k].spouses)) do
                    if not used[s] and inRow(s) and not hasParents(s) then
                        used[s] = true
                        table.insert(unit, s)
                    end
                end
                local parents = {}
                for p in pairs(nodes[k].parents) do
                    if comp.gen[p] == g - 1 then table.insert(parents, p) end
                end
                table.sort(parents)
                unit.parents = parents
                unit.family = #parents > 0 and table.concat(parents, "|")
                    or (nodes[k].sibling_group and "sib:" .. nodes[k].sibling_group) or ("solo:" .. k)
                table.insert(list, unit)
            end
        end
        -- keep the current left-to-right order where there is one
        for i, u in ipairs(list) do u.pos = x[u[1]] or i * 1e-3; u.index = i end
        table.sort(list, function(a, b)
            if a.pos ~= b.pos then return a.pos < b.pos end
            return a.index < b.index
        end)
        return list
    end
    local function unitWidth(u) return #u * m.box_w + (#u - 1) * m.spouse_gap end
    local function placeUnit(u, left)
        for i, k in ipairs(u) do x[k] = left + (i - 1) * (m.box_w + m.spouse_gap) end
        return left + unitWidth(u)
    end
    local function span(keys)
        local lo, hi
        for _i, k in ipairs(keys) do
            if x[k] then
                lo = math.min(lo or x[k], x[k])
                hi = math.max(hi or x[k] + m.box_w, x[k] + m.box_w)
            end
        end
        return lo, hi
    end

    -- Top-down: children grouped by their parents, centered under them.
    local function topDown()
        for g = 1, #comp.rows do
            local list = units(comp.rows[g], g)
            local families, by_family = {}, {}
            for _i, u in ipairs(list) do
                local f = by_family[u.family]
                if not f then
                    f = { units = {}, parents = u.parents }
                    by_family[u.family] = f
                    table.insert(families, f)
                end
                table.insert(f.units, u)
            end
            local last = -math.huge
            for i, f in ipairs(families) do
                local w = 0
                for j, u in ipairs(f.units) do w = w + unitWidth(u) + (j > 1 and m.unit_gap or 0) end
                local lo, hi = span(f.parents)
                if lo then
                    f.key = (lo + hi) / 2 - w / 2
                else
                    -- no parents drawn: where it was, or right after the previous family
                    f.key = x[f.units[1][1]] or (last == -math.huge and i * 1e-3 or last + 1e-3)
                end
                f.index = i
                last = f.key
            end
            table.sort(families, function(a, b)
                if a.key ~= b.key then return a.key < b.key end
                return a.index < b.index
            end)
            local cursor = -math.huge
            for _i, f in ipairs(families) do
                local left = math.max(f.key, cursor)
                for j, u in ipairs(f.units) do
                    if j > 1 then left = left + m.unit_gap end
                    left = placeUnit(u, left)
                end
                cursor = left + m.family_gap
            end
        end
    end
    -- Bottom-up: parents moved over their children where there is room.
    local function bottomUp()
        for g = #comp.rows - 1, 1, -1 do
            local list = units(comp.rows[g], g)
            local cursor = -math.huge
            for _i, u in ipairs(list) do
                local kids = {}
                for _j, k in ipairs(u) do
                    for c in pairs(nodes[k].children) do
                        if comp.gen[c] == g + 1 then table.insert(kids, c) end
                    end
                end
                local left = x[u[1]]
                local lo, hi = span(kids)
                if lo then left = (lo + hi) / 2 - unitWidth(u) / 2 end
                left = math.max(left, cursor)
                cursor = placeUnit(u, left) + m.unit_gap
            end
        end
    end
    topDown()
    bottomUp()
    topDown()
    local lo, hi = span(comp.keys)
    for _i, k in ipairs(comp.keys) do x[k] = math.floor(x[k] - lo + 0.5) end
    comp.width = hi - lo
end

-- ------------------------------------------------------------------------

return function(_)

local FamilyTree = InputContainer:extend{
    characters = nil,   -- list of characters
    focus = nil,        -- character to highlight; its family comes first
    on_tap = nil,       -- function(character)
    covers_fullscreen = true,
}

--- True when the characters have at least one family relationship.
function FamilyTree.hasFamily(characters)
    local _nodes, linked = buildGraph(characters)
    return #linked > 0
end

function FamilyTree:init()
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh }
    self.title_bar = TitleBar:new{
        width = sw,
        fullscreen = true,
        with_bottom_line = true,
        title = _("Family tree"),
        subtitle = _("Tap a name to open it · swipe to move"),
        close_callback = function() self:onClose() end,
        show_parent = self,
    }
    self[1] = self.title_bar
    self.view_y = self.title_bar:getHeight()
    self.view_w, self.view_h = sw, sh - self.view_y

    self.m = {
        box_w = Screen:scaleBySize(104),
        box_h = Screen:scaleBySize(52),
        spouse_gap = Screen:scaleBySize(18),
        unit_gap = Screen:scaleBySize(10),
        family_gap = Screen:scaleBySize(22),
        row_gap = Screen:scaleBySize(46),
        comp_gap = Screen:scaleBySize(70),  -- between separate families
        margin = Screen:scaleBySize(12),
    }
    self:buildCanvas()

    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Swipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end
end

function FamilyTree:buildCanvas()
    local m = self.m
    local nodes, linked = buildGraph(self.characters)
    local focus_key = self.focus and self.focus.name:lower()
    local comps = components(nodes, linked, focus_key)

    -- Lay out every family, then stack them vertically.
    local width, height = 0, m.margin
    for _i, comp in ipairs(comps) do
        layout(nodes, comp, m)
        comp.top = height
        height = height + #comp.rows * m.box_h + (#comp.rows - 1) * m.row_gap + m.comp_gap
        width = math.max(width, comp.width)
    end
    width = width + 2 * m.margin
    height = height - m.comp_gap + math.floor(m.row_gap / 2)
    -- Narrow trees are centered on the screen.
    local shift = math.max(0, math.floor((self.view_w - width) / 2))
    width = math.max(width, self.view_w)
    height = math.max(height, self.view_h)
    self.canvas_w, self.canvas_h = width, height

    local bb = Blitbuffer.new(width, height, Blitbuffer.TYPE_BB8)
    bb:fill(Blitbuffer.COLOR_WHITE)
    self.canvas = bb
    self.boxes = {}
    local black, gray = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_DARK_GRAY
    local line = math.max(1, Screen:scaleBySize(1.5))
    local function hline(x1, x2, y, color)
        if x2 < x1 then x1, x2 = x2, x1 end
        bb:paintRect(x1, y, x2 - x1 + line, line, color or black)
    end
    local function vline(x, y1, y2, color)
        if y2 < y1 then y1, y2 = y2, y1 end
        bb:paintRect(x, y1, line, y2 - y1 + line, color or black)
    end

    local function dashed(x1, x2, y, color)
        local dash, gap = Screen:scaleBySize(6), Screen:scaleBySize(4)
        local x = x1
        while x < x2 do
            bb:paintRect(x, y, math.min(dash, x2 - x + line), line, color or black)
            x = x + dash + gap
        end
    end

    local face = Font:getFace("cfont", 15)
    for _i, comp in ipairs(comps) do
        local ox = m.margin + shift
        local function bx(k) return ox + comp.x[k] end
        local function by(k) return comp.top + (comp.gen[k] - 1) * (m.box_h + m.row_gap) end
        local function cx(k) return bx(k) + math.floor(m.box_w / 2) end

        -- Lines first; boxes are painted over them.
        -- Spouses: a double line between the two boxes.
        for _j, k in ipairs(comp.keys) do
            for s in pairs(nodes[k].spouses) do
                if k < s and comp.gen[s] == comp.gen[k] then
                    local l, r = k, s
                    if comp.x[r] < comp.x[l] then l, r = r, l end
                    local y = by(k) + math.floor(m.box_h / 2)
                    hline(bx(l) + m.box_w, bx(r), y - 2 * line)
                    hline(bx(l) + m.box_w, bx(r), y + line)
                end
            end
        end
        -- Parents to children: down from the parents (the middle of the
        -- couple's line), along a bar, down to each child.
        local families, fam_order = {}, {}
        for _j, k in ipairs(comp.keys) do
            local ps = {}
            for p in pairs(nodes[k].parents) do
                if comp.gen[p] == comp.gen[k] - 1 then table.insert(ps, p) end
            end
            table.sort(ps)
            local id
            if #ps > 0 then
                id = table.concat(ps, "|")
            elseif nodes[k].sibling_group then
                id = "sib:" .. nodes[k].sibling_group
            end
            if id then
                if not families[id] then
                    families[id] = { parents = ps, kids = {} }
                    table.insert(fam_order, id)
                end
                table.insert(families[id].kids, k)
            end
        end
        local per_row = {}
        for _j, id in ipairs(fam_order) do
            local f = families[id]
            local g = comp.gen[f.kids[1]]
            if #f.parents == 0 then
                -- Siblings whose parents are not in the tree: a dashed bracket
                -- under their boxes, so it is not read as a parent's line.
                if #f.kids > 1 then
                    -- several brackets on one row: each at its own depth
                    local key = "sib" .. g
                    per_row[key] = (per_row[key] or 0) + 1
                    local y = by(f.kids[1]) + m.box_h + Screen:scaleBySize(8)
                        + ((per_row[key] - 1) % 3) * Screen:scaleBySize(7)
                    local lo, hi
                    for _l, c in ipairs(f.kids) do
                        lo = math.min(lo or cx(c), cx(c))
                        hi = math.max(hi or cx(c), cx(c))
                        vline(cx(c), by(c) + m.box_h, y, gray)
                    end
                    dashed(lo, hi, y, gray)
                end
            else
                per_row[g] = (per_row[g] or 0) + 1
                -- Bars of different families on one row get slightly different heights.
                local nudge = ((per_row[g] - 1) % 3 - 1) * Screen:scaleBySize(5)
                local bar_y = by(f.kids[1]) - math.floor(m.row_gap / 2) + nudge
                local lo, hi
                for _l, c in ipairs(f.kids) do
                    lo = math.min(lo or cx(c), cx(c))
                    hi = math.max(hi or cx(c), cx(c))
                    vline(cx(c), bar_y, by(c))
                end
                if #f.parents > 0 then
                    local px, py
                    local a, b = f.parents[1], f.parents[2]
                    if #f.parents == 2 and nodes[a].spouses[b] then
                        px = math.floor((cx(a) + cx(b)) / 2)
                        py = by(a) + math.floor(m.box_h / 2)
                    else
                        local sum = 0
                        for _l, p in ipairs(f.parents) do sum = sum + cx(p) end
                        px = math.floor(sum / #f.parents)
                        py = by(a) + m.box_h
                        if #f.parents > 1 then
                            local plo, phi = cx(f.parents[1]), cx(f.parents[1])
                            for _l, p in ipairs(f.parents) do
                                plo, phi = math.min(plo, cx(p)), math.max(phi, cx(p))
                                vline(cx(p), by(p) + m.box_h, py + math.floor(m.row_gap / 4))
                            end
                            py = py + math.floor(m.row_gap / 4)
                            hline(plo, phi, py)
                        end
                    end
                    vline(px, py, bar_y)
                    lo, hi = math.min(lo, px), math.max(hi, px)
                end
                if hi > lo then hline(lo, hi, bar_y) end
            end
        end

        -- Boxes
        for _j, k in ipairs(comp.keys) do
            local n = nodes[k]
            local x, y = bx(k), by(k)
            local is_focus = k == focus_key
            bb:paintRect(x, y, m.box_w, m.box_h, Blitbuffer.COLOR_WHITE)
            local border = is_focus and Screen:scaleBySize(3) or line
            bb:paintBorder(x, y, m.box_w, m.box_h, border, n.char and black or gray, Screen:scaleBySize(6))
            local pad = Screen:scaleBySize(5)
            local args = {
                text = n.char and n.char.name or n.name,
                face = face,
                bold = is_focus,
                width = m.box_w - 2 * pad,
                alignment = "center",
                fgcolor = n.char and black or gray,
            }
            local text = TextBoxWidget:new(args)
            local th = text:getSize().h
            if th > m.box_h - 2 * pad then
                -- too long for the box: cut with an ellipsis
                text:free()
                args.height = m.box_h - 2 * pad
                args.height_overflow_show_ellipsis = true
                text = TextBoxWidget:new(args)
                th = args.height
            end
            text:paintTo(bb, x + pad, y + math.floor((m.box_h - th) / 2))
            text:free()
            table.insert(self.boxes, { x = x, y = y, w = m.box_w, h = m.box_h, char = n.char })
        end

        -- A thin line between separate families
        if _i < #comps then
            local y = comp.top + #comp.rows * m.box_h + (#comp.rows - 1) * m.row_gap + math.floor(m.comp_gap / 2)
            hline(m.margin, width - m.margin, y, Blitbuffer.COLOR_LIGHT_GRAY)
        end
    end

    -- Start with the highlighted character in view.
    self.off_x, self.off_y = 0, 0
    for _i, b in ipairs(self.boxes) do
        if b.char and focus_key and b.char.name:lower() == focus_key then
            self.off_x = b.x + math.floor(b.w / 2) - math.floor(self.view_w / 2)
            self.off_y = b.y + math.floor(b.h / 2) - math.floor(self.view_h / 2)
        end
    end
    self:clampOffset()
end

function FamilyTree:clampOffset()
    self.off_x = math.max(0, math.min(self.off_x, self.canvas_w - self.view_w))
    self.off_y = math.max(0, math.min(self.off_y, self.canvas_h - self.view_h))
end

function FamilyTree:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    self.title_bar:paintTo(bb, x, y)
    bb:blitFrom(self.canvas, x, y + self.view_y, self.off_x, self.off_y, self.view_w, self.view_h)
end

function FamilyTree:onSwipe(_arg, ges)
    local dir = ges.direction
    local dx, dy = 0, 0
    local step_x, step_y = math.floor(self.view_w * 2 / 3), math.floor(self.view_h * 2 / 3)
    if dir == "west" then dx = step_x
    elseif dir == "east" then dx = -step_x
    elseif dir == "north" then dy = step_y
    elseif dir == "south" then dy = -step_y
    else return false end
    local ox, oy = self.off_x, self.off_y
    self.off_x, self.off_y = ox + dx, oy + dy
    self:clampOffset()
    if self.off_x ~= ox or self.off_y ~= oy then
        UIManager:setDirty(self, "ui")
    end
    return true
end

function FamilyTree:onTap(_arg, ges)
    local px = ges.pos.x - self.dimen.x + self.off_x
    local py = ges.pos.y - self.dimen.y - self.view_y + self.off_y
    if py < self.off_y then return false end
    for _i, b in ipairs(self.boxes) do
        if px >= b.x and px < b.x + b.w and py >= b.y and py < b.y + b.h then
            if b.char and self.on_tap then self.on_tap(b.char) end
            return true
        end
    end
    return true
end

function FamilyTree:onClose()
    UIManager:close(self, "ui")
    return true
end

function FamilyTree:onCloseWidget()
    if self.canvas then
        self.canvas:free()
        self.canvas = nil
    end
end

return FamilyTree
end
