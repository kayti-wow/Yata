-- Shared helpers for the offline tests. Each test runs in its own process, so
-- the WoW API mocks one test defines can't leak into another.
assert(setfenv and loadstring, "the tests need Lua 5.1 or LuaJIT, the game's Lua version")

local helpers = {}

-- The repository root: the test's first argument, or the folder above Tests/
helpers.root = arg[1] or ((arg[0]:match("^(.*)[/\\]") or ".") .. "/..")

-- Reads a file from the repository, dropping a UTF-8 byte order mark as the
-- game does
function helpers.read(file)
	local f = assert(io.open(helpers.root .. "/" .. file, "rb"))
	local source = f:read("*a")
	f:close()
	return (source:gsub("^\239\187\191", ""))
end

-- Compiles a file from the repository
function helpers.compile(file)
	return assert(loadstring(helpers.read(file), "@" .. file))
end

local failures = 0

function helpers.check(ok, message)
	print((ok and "ok   " or "FAIL ") .. message)
	if not ok then
		failures = failures + 1
	end
end

-- Prints the result and exits with a status the runner can read
function helpers.finish()
	print(failures == 0 and "all passed" or (failures .. " failed"))
	os.exit(failures == 0 and 0 or 1)
end

return helpers
