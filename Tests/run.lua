-- Runs every offline test, each in its own process.
-- From the repository root: lua5.1 Tests/run.lua [repo root]
assert(setfenv and loadstring, "the tests need Lua 5.1 or LuaJIT, the game's Lua version")

local dir = arg[0]:match("^(.*)[/\\]") or "."
local interpreter = arg[-1] or "lua5.1"
local rootArgument = arg[1] and string.format(' "%s"', arg[1]) or ""

local failed = 0
for _, test in ipairs({ "timer_test.lua", "snippet_test.lua", "locale_test.lua" }) do
	print("== " .. test)
	io.stdout:flush()
	-- Lua 5.1 returns the exit status; LuaJIT built with 5.2 compatibility returns true
	local status = os.execute(string.format('"%s" "%s/%s"%s', interpreter, dir, test, rootArgument))
	if status ~= 0 and status ~= true then
		failed = failed + 1
	end
end

print(failed == 0 and "All tests passed" or (failed .. " test file(s) failed"))
os.exit(failed == 0 and 0 or 1)
