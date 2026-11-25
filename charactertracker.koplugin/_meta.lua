local _ = (function()
    local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
    local ok, gettext = pcall(dofile, dir .. "l10n.lua")
    return ok and gettext or require("gettext")
end)()
return {
    name = "charactertracker",
    fullname = _("Character Tracker"),
    description = _([[Track characters, add notes, and link highlights to characters while reading. Never forget who's who in a book again.]]),
    version = "1.0.0",
}
