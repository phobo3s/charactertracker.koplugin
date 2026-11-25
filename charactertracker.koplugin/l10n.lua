--[[--
Plugin translations on top of KOReader's own catalogue.

Strings of this plugin are not in KOReader's translations, so they are kept
in standard gettext PO files next to this file: l10n/<lang>.po (e.g. tr.po,
pt_BR.po). Adding a language needs no code change: copy an existing PO file,
translate the msgstr lines and name it after the KOReader UI language.

Lookup order for a string: the plugin's PO for the UI language ("pt_BR",
then "pt"), then KOReader's catalogue (so common words such as "Cancel" are
translated even without a plugin PO), then the English source string.
Only plain msgid / msgstr entries are used; fuzzy entries are ignored.
--]]

local GetText = require("gettext")

local ESCAPES = { n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\" }

local function unescape(s)
    return (s:gsub("\\(.)", ESCAPES))
end

local function parsePO(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local translations = {}
    local entry = {}
    local pending_fuzzy = false
    local function flush()
        if entry.msgid and entry.msgid ~= "" and entry.msgstr and entry.msgstr ~= ""
                and not entry.fuzzy then
            translations[entry.msgid] = entry.msgstr
        end
        entry = {}
    end
    for line in f:lines() do
        line = line:gsub("\r$", "")
        -- msgid_plural / msgstr[n] / msgctxt do not match and are ignored
        local key, str = line:match('^(msg%a+)%s+"(.*)"%s*$')
        if key == "msgid" then
            flush()
            entry.fuzzy = pending_fuzzy
            pending_fuzzy = false
            entry.msgid = unescape(str)
            entry.current = "msgid"
        elseif key == "msgstr" then
            entry.msgstr = unescape(str)
            entry.current = "msgstr"
        elseif key then
            entry.current = nil
        else
            local cont = line:match('^%s*"(.*)"%s*$')
            if cont and entry.current then
                entry[entry.current] = entry[entry.current] .. unescape(cont)
            elseif line:match("^#,") and line:find("fuzzy", 1, true) then
                flush()
                pending_fuzzy = true
            end
        end
    end
    flush()
    f:close()
    return translations
end

local function loadTranslations()
    local lang = GetText.current_lang
    if type(lang) ~= "string" or lang == "" or lang == "C" then return {} end
    local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
    local candidates = { lang }
    local base = lang:match("^(%a+)[_%-]")
    if base then table.insert(candidates, base) end
    for _i, code in ipairs(candidates) do
        local translations = parsePO(dir .. "l10n/" .. code .. ".po")
        if translations then return translations end
    end
    return {}
end

local translations = loadTranslations()

return function(msgid)
    return translations[msgid] or GetText(msgid)
end
