-- Tests the restricted snippets Yata stores in frame attributes. A syntax
-- error in a snippet only shows up in game, so every snippet is compiled, and
-- the bar's updateindicators handler is run against mock frame handles.
-- From the repository root: lua5.1 Tests/snippet_test.lua
local helpers = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/helpers.lua")
local check = helpers.check

-- Every long-bracket string in these files is a snippet. Execute bodies can
-- define further snippets, so look inside each one too.
local function eachSnippet(source, visit)
	for _, body in source:gmatch("%[(=*)%[(.-)%]%1%]") do
		visit(body)
		eachSnippet(body, visit)
	end
end

for _, file in ipairs({ "TotemBar.lua", "TotemButton.lua", "Header.lua" }) do
	local count, errors = 0, {}
	eachSnippet(helpers.read(file), function(body)
		count = count + 1
		local compiled, err = loadstring(body, "=" .. file .. " snippet " .. count)
		if not compiled then
			table.insert(errors, err)
		end
	end)
	local summary = count == 1 and "its snippet compiles" or string.format("all %d snippets compile", count)
	local detail = #errors > 0 and (": " .. table.concat(errors, "; ")) or ""
	check(count > 0 and #errors == 0, file .. ": " .. summary .. detail)
end

-- The bar's _onattributechanged snippet, as the restricted environment runs it
local body = assert(helpers.read("TotemBar.lua"):match('SetAttribute%("_onattributechanged",%s*%[%[(.-)%]%]'),
	"bar snippet not found")
local snippet = assert(loadstring("local self, name, value = ...\n" .. body, "=bar snippet"))

-- Frame handle mock
local function Handle(attributes, children)
	local handle = { attributes = attributes or {}, children = children or {} }
	function handle:GetAttribute(key) return self.attributes[key] end
	function handle:SetAttribute(key, value) self.attributes[key] = value end
	function handle:GetChildren() return unpack(self.children) end
	return handle
end

local actions = {} -- action slot -> spell id
setfenv(snippet, {
	newtable = function(...) return { ... } end,
	ipairs = ipairs,
	GetActionInfo = function(action)
		if actions[action] then
			return "spell", actions[action], "spell"
		end
	end,
})

local totem = Handle({ actionid = 133, globalid = 3599 }) -- Fire slot, first page
local header = Handle({ istotemgroup = true }, { totem })
local bar = Handle({ setcallkey = "alt" }, { header })

-- No Call spell known, so nothing has set currentcallindex
local ok, err = pcall(snippet, bar, "updateindicators", true)
check(ok, "updateindicators runs with no Call spell known" .. (ok and "" or (": " .. tostring(err))))
if ok then
	check(totem.attributes.action == 133, "with no Call spell known it uses the first page")
	check(totem.attributes["alt-spell1"] == 3599, "the totem can be assigned to that page")
end

-- Third Call spell at the front of its column
bar.attributes.currentcallindex = 2
ok = pcall(snippet, bar, "updateindicators", true)
check(ok and totem.attributes.action == 141, "with the third Call spell it uses the third page")

-- The totem is already on the second page
bar.attributes.currentcallindex = 1
actions[137] = 3599
ok = pcall(snippet, bar, "updateindicators", true)
check(ok and totem.attributes["alt-spell1"] == nil, "a totem already on the page isn't offered for assignment")

helpers.finish()
