-- Tests that each locale file registers itself correctly with AceLocale, and
-- that a client in that locale sees its strings. Loads LibStub, AceLocale and
-- every locale file in TOC order, once per locale.
-- From the repository root: lua5.1 Tests/locale_test.lua
local helpers = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/helpers.lua")
local check = helpers.check

function UnitClass() return "Shaman", "SHAMAN" end
function geterrorhandler()
	return function(message) io.stderr:write(tostring(message), "\n") end
end

-- Locale files, in the order the TOC loads them
local locales = {}
for line in io.lines(helpers.root .. "/Yata.toc") do
	local locale = line:match("^Localization\\(%w+)%.lua")
	if locale then
		table.insert(locales, locale)
	end
end
check(#locales > 0, "the TOC lists locale files")

-- What a locale file registers, and the strings it assigns
local function readLocaleFile(locale)
	local registered = { strings = {} }
	local chunk = helpers.compile("Localization/" .. locale .. ".lua")
	setfenv(chunk, setmetatable({
		LibStub = function()
			return {
				NewLocale = function(_, app, code, isDefault)
					registered.app, registered.code, registered.isDefault = app, code, isDefault
					return registered.strings
				end,
			}
		end,
	}, { __index = _G }))
	chunk("Yata", {})
	return registered
end

-- The strings a player sees on a client in this locale
local function loadClient(locale)
	LibStub = nil -- start each client from fresh libraries
	function GetLocale() return locale end
	helpers.compile("Libs/LibStub/LibStub.lua")("Yata", {})
	helpers.compile("Libs/AceLocale-3.0/AceLocale-3.0.lua")("Yata", {})
	for _, file in ipairs(locales) do
		helpers.compile("Localization/" .. file .. ".lua")("Yata", {})
	end
	return LibStub("AceLocale-3.0"):GetLocale("Yata")
end

for _, locale in ipairs(locales) do
	local registered = readLocaleFile(locale)
	local registersAs = registered.code == locale and "" or string.format(" (got %s)", tostring(registered.code))
	check(registered.app == "Yata" and registered.code == locale,
		string.format("%s.lua registers as %s%s", locale, locale, registersAs))
	check((registered.isDefault == true) == (locale == "enUS"),
		string.format("%s.lua is %s", locale, locale == "enUS" and "the default locale" or "not a default locale"))

	local L = loadClient(locale)
	local total, shown = 0, 0
	for key, value in pairs(registered.strings) do
		total = total + 1
		if L[key] == (value == true and key or value) then
			shown = shown + 1
		end
	end
	check(total > 0 and shown == total,
		string.format("%s client shows all of its strings (%d of %d)", locale, shown, total))
end

helpers.finish()
