warn("SCRIPT OF MODULES BOYY")
local type, typeof, pcall, xpcall, assert, error, select, pairs, ipairs, tostring, tonumber = 
	type, typeof, pcall, xpcall, assert, error, select, pairs, ipairs, tostring, tonumber
local getfenv, setfenv, rawget, rawset, rawequal, setmetatable, getmetatable = 
	getfenv, setfenv, rawget, rawset, rawequal, setmetatable, getmetatable
local string_match, string_sub, string_len, string_format, string_rep = 
	string.match, string.sub, string.len, string.format, string.rep
local table_insert, table_concat, table_find, table_clear, table_freeze = 
	table.insert, table.concat, table.find, table.clear, table.freeze
local math_random, math_round, math_floor, math_abs = 
	math.random, math.round, math.floor, math.abs
local task_spawn, task_defer, task_wait = 
	task.spawn, task.defer, task.wait
local Instance_new = Instance.new

local passes, fails, spoofed, undefined = 0, 0, 0, 0
local running = 0
local testStatus = {}

local function getGlobal(path)
	local value = getfenv(0)
	while value ~= nil and path ~= "" do
		local name, nextValue = string_match(path, "^([^.]+)%.?(.*)$")
		if type(value) ~= "table" and type(value) ~= "userdata" then
			return nil
		end
		local success, result = pcall(function()
			return value[name]
		end)
		if not success then return nil end
		value = result
		path = nextValue
	end
	return value
end

local function markSpoofed(name, reason)
	spoofed += 1
	fails += 1
	warn("⛔ Good Job at trying to fake \"" .. name .. "\" 👍 (" .. (reason or "Behavioral check failed") .. ")")
end

local function test(name, aliases, deps, callback)
	if type(deps) == "function" then
		callback = deps
		deps = {}
	end

	running += 1

	task_spawn(function()
		for _, dep in ipairs(deps or {}) do
			if not getGlobal(dep) or testStatus[dep] == false then
				warn(dep .. " is needed in order to test " .. name)
				running -= 1
				return
			end
		end

		local fn = getGlobal(name)

		if not callback then
			print("⏺️ " .. name)
		elseif not fn then
			fails += 1
			testStatus[name] = false
			warn("⛔ " .. name .. " (Global missing)")
		else
			local success, message = pcall(callback)

			if success then
				passes += 1
				testStatus[name] = true
				print("✅ " .. name .. (type(message) == "string" and (" • " .. message) or ""))
			else
				testStatus[name] = false
				markSpoofed(name, tostring(message))
			end
		end

		local undefinedAliases = {}
		for _, alias in ipairs(aliases) do
			if getGlobal(alias) == nil then
				table_insert(undefinedAliases, alias)
			end
		end

		if #undefinedAliases > 0 then
			undefined += 1
			warn("⚠️ " .. name .. " missing aliases: " .. table_concat(undefinedAliases, ", "))
		end

		running -= 1
	end)
end

print("\n")
print("==========================================================")
print(" Ultra-Hardened UNC Suite (Anti-Fake Engine v4)")
print("✅ Pass | ⛔ Spoofed/Failed | ⏺️ Untested | ⚠️ Missing Aliases")
print("==========================================================\n")

task_defer(function()
	repeat task_wait() until running == 0

	local total = passes + fails
	local rate = total > 0 and math_round((passes / total) * 100) or 0

	print("\n==========================================================")
	print("UNC Final Report")
	print("✅ Pass Rate: " .. rate .. "% (" .. passes .. "/" .. total .. ")")
	print("⛔ Failed / Fakes Caught: " .. fails .. " (Spoofs: " .. spoofed .. ")")
	print("⚠️ Missing Aliases: " .. undefined)
	print("==========================================================\n")
end)

local function findModuleScript()
	local searchRoots = {
		game:GetService("CoreGui"),
		game:GetService("CorePackages"),
		game:GetService("ReplicatedFirst"),
		game:GetService("StarterPlayer"),
		game:GetService("ReplicatedStorage"),
		game:GetService("Lighting"),
		game:GetService("Workspace"),
	}
	for _, service in ipairs(searchRoots) do
		if service then
			for _, desc in ipairs(service:GetDescendants()) do
				if desc:IsA("ModuleScript") then
					local ok, result = pcall(getscriptbytecode, desc)
					if ok and type(result) == "string" and #result > 0 then
						return desc
					end
				end
			end
		end
	end
	return nil
end

local function findLocalScript()
	local localPlayer = game:GetService("Players").LocalPlayer
	local character = localPlayer and localPlayer.Character
	if character then
		for _, desc in ipairs(character:GetDescendants()) do
			if desc:IsA("LocalScript") then
				local ok, result = pcall(getscriptbytecode, desc)
				if ok and type(result) == "string" and #result > 0 then
					return desc
				end
			end
		end
	end
	for _, desc in ipairs(game:GetService("StarterPlayer"):GetDescendants()) do
		if desc:IsA("LocalScript") then
			local ok, result = pcall(getscriptbytecode, desc)
			if ok and type(result) == "string" and #result > 0 then
				return desc
			end
		end
	end
	return nil
end

local function shallowEqual(t1, t2)
	if t1 == t2 then return true end
	local UNIQUE_TYPES = { ["function"] = true, ["table"] = true, ["userdata"] = true, ["thread"] = true }
	for k, v in pairs(t1) do
		if UNIQUE_TYPES[type(v)] then
			if type(t2[k]) ~= type(v) then return false end
		elseif t2[k] ~= v then return false end
	end
	return true
end

test("cache.invalidate", {}, function()
	local container = Instance_new("Folder")
	local part = Instance_new("Part", container)
	part.Name = "CacheTestPart"

	local refBefore = container:FindFirstChild("CacheTestPart")
	assert(refBefore ~= nil, "cache.invalidate: FindFirstChild returned nil before invalidate")
	cache.invalidate(refBefore)
	local refAfter = container:FindFirstChild("CacheTestPart")

	assert(refBefore ~= refAfter, "Failed to invalidate object reference from internal cache")
	assert(refAfter ~= nil, "cache.invalidate: FindFirstChild returned nil after invalidate")
	assert(refAfter.Name == "CacheTestPart", "cache.invalidate: instance name changed after invalidate")
end)

test("cache.iscached", {}, function()
	local part = Instance_new("Part")
	assert(cache.iscached(part) == true, "New Part should be cached")

	local folder = Instance_new("Folder")
	assert(cache.iscached(folder) == true, "New Folder should be cached")

	cache.invalidate(part)
	assert(cache.iscached(part) == false, "Invalidated Part should not report as cached")

	local recheck = cache.iscached(part)
	assert(recheck == false, "cache.iscached: recheck after invalidation returned true")
end)

test("cache.replace", {}, function()
	local part = Instance_new("Part")
	local fire = Instance_new("Fire")

	cache.replace(part, fire)
	assert(part ~= fire, "cache.replace failed physical substitution")

	local folder = Instance_new("Folder")
	local beam = Instance_new("Beam")
	cache.replace(folder, beam)
	assert(folder ~= beam, "cache.replace failed on Folder->Beam substitution")
end)

test("cloneref", {}, function()
	local part = Instance_new("Part")
	part.Name = "OriginalPart"
	part.Size = Vector3.new(1, 2, 3)
	local clone = cloneref(part)

	assert(part ~= clone, "cloneref returned identical proxy memory reference")
	assert(rawequal(part, clone) == false, "cloneref proxy passed raw equality check")

	clone.Name = "ModifiedViaProxy"
	assert(part.Name == "ModifiedViaProxy", "Property change on cloned reference failed to reflect on origin")

	local clone2 = cloneref(part)
	assert(clone ~= clone2, "cloneref returned identical references for two calls on same instance")
	assert(clone.Name == clone2.Name, "cloneref two proxies have different Name properties")
	clone2.Name = "ModifiedViaProxy2"
	assert(part.Name == "ModifiedViaProxy2", "cloneref: second proxy modification failed to reflect on origin")
	assert(clone.Name == "ModifiedViaProxy2", "cloneref: first proxy did not reflect second proxy's change")

	local folder = Instance_new("Folder")
	folder.Name = "TestFolder"
	local folderClone = cloneref(folder)
	assert(folder ~= folderClone, "cloneref failed on Folder instance")
	folderClone.Name = "RenamedFolder"
	assert(folder.Name == "RenamedFolder", "cloneref Folder rename failed")
end)

test("compareinstances", {}, {"cloneref"}, function()
	local part1 = Instance_new("Part")
	local part2 = Instance_new("Part")
	local clone = cloneref(part1)

	assert(compareinstances(part1, clone) == true, "compareinstances failed to equate proxy reference with original")
	assert(compareinstances(part1, part2) == false, "compareinstances false-positive on unique instances")
	assert(compareinstances(part1, part1) == true, "compareinstances failed same-instance check")
	assert(compareinstances(clone, part1) == true, "compareinstances failed clone-then-origin check")
end)

test("checkcaller", {}, {"hookfunction", "restorefunction"}, function()
	assert(checkcaller() == true, "Main executor context must return true")

	local coroutineCaller
	local co = coroutine.create(function()
		coroutineCaller = checkcaller()
	end)
	coroutine.resume(co)
	assert(coroutineCaller == true, "checkcaller failed context verification inside spawned coroutine thread")

	local hookVerified = false
	local function dummyTarget() end
	local originalRef
	originalRef = hookfunction(dummyTarget, function(...)
		if checkcaller() == true then
			hookVerified = true
		end
		return originalRef(...)
	end)

	dummyTarget()
	restorefunction(dummyTarget)
	assert(hookVerified == true, "checkcaller failed context verification inside hooked closure")

	local falseCheck = checkcaller()
	assert(type(falseCheck) == "boolean", "checkcaller returned non-boolean value")
end)

test("clonefunction", {}, {"hookfunction", "restorefunction"}, function()
	local function original(a, b, c) return (a + b) * c end
	local cloned = clonefunction(original)

	assert(type(cloned) == "function", "clonefunction did not return a valid function")
	assert(original ~= cloned, "cloned function returned identical reference")
	assert(cloned(2, 3, 4) == 20, "cloned function returned incorrect multi-arg computation")

	local function baseFunc() return "unhooked" end
	local clonedFunc = clonefunction(baseFunc)

	hookfunction(baseFunc, function() return "hooked" end)

	assert(baseFunc() == "hooked", "hookfunction failed to hook target")
	assert(clonedFunc() == "unhooked", "cloned function executed hooked path instead of original bytecode")
	restorefunction(baseFunc)

	local function withUpvalue()
		local secret = "upvalue_secret_42"
		return function() return secret end
	end
	local inner = withUpvalue()
	local clonedInner = clonefunction(inner)
	assert(type(clonedInner) == "function", "clonefunction with upvalue: not a function")
	assert(clonedInner() == "upvalue_secret_42", "clonefunction with upvalue: execution mismatch")
	assert(inner ~= clonedInner, "clonefunction with upvalue: same reference")

	local function multiReturn() return "a", "b", "c" end
	local clonedMulti = clonefunction(multiReturn)
	local r1, r2, r3 = clonedMulti()
	assert(r1 == "a" and r2 == "b" and r3 == "c", "clonefunction multi-return failed")

	local function varargFn(...) return ... end
	local clonedVararg = clonefunction(varargFn)
	local vr1, vr2, vr3 = clonedVararg(10, 20, 30)
	assert(vr1 == 10 and vr2 == 20 and vr3 == 30, "clonefunction vararg forwarding failed")

	local function recursive(n)
		if n <= 1 then return 1 end
		return n * recursive(n - 1)
	end
	local clonedRecursive = clonefunction(recursive)
	assert(clonedRecursive(5) == 120, "clonefunction recursive function failed")

	local function mutating()
		local count = 0
		return function() count += 1; return count end
	end
	local mutator = mutating()
	local clonedMutator = clonefunction(mutator)
	assert(mutator() == 1, "clonefunction mutating: original first call wrong")
	assert(mutator() == 2, "clonefunction mutating: original second call wrong")
	assert(clonedMutator() == 1, "clonefunction mutating: clone should start from 1")
	assert(clonedMutator() == 2, "clonefunction mutating: clone second call wrong")
end)

test("getfunctionhash", {}, function()
	local function targetA(x, y) return x + y end
	local function targetB(x, y) return x * y end
	
	local hashA1 = getfunctionhash(targetA)
	local hashA2 = getfunctionhash(targetA)
	local hashB = getfunctionhash(targetB)
	
	assert(type(hashA1) == "string" and #hashA1 > 0, "getfunctionhash failed to return a non-empty string")
	assert(hashA1 == hashA2, "getfunctionhash failed deterministic hash check")
	assert(hashA1 ~= hashB, "getfunctionhash produced hash collision for distinct closures")
end)

test("getcallingscript", {}, {"hookmetamethod", "restorefunction"}, function()
	local callingScript = getcallingscript()
	assert(callingScript == nil or typeof(callingScript) == "Instance", "getcallingscript returned non-instance value in main thread")

	local bindable = Instance_new("BindableEvent")
	local signalScript = "unset"
	local conn = bindable.Event:Connect(function()
		signalScript = getcallingscript()
	end)
	bindable:Fire()
	conn:Disconnect()
	assert(signalScript == nil or typeof(signalScript) == "Instance", "getcallingscript inside signal returned non-instance")

	local hookVerified = false
	local capturedValue
	local ogcall
	local kuur = false
	ogcall = hookmetamethod(game, "__index", function(self, key, ...)
		kuur = true
		if not hookVerified then
			capturedValue = getcallingscript()
			hookVerified = true
		end
		return ogcall(self, key, ...)
	end)

	local _ = game.Name
	restorefunction(ogcall)

	assert(kuur == true, "getcallingscript: hookmetamethod __index never fired")

	local bindable2 = Instance_new("BindableEvent")
	local hookFromSignal = false
	local conn2 = bindable2.Event:Connect(function()
		local cs = getcallingscript()
		if typeof(cs) == "Instance" or cs == nil then
			hookFromSignal = true
		end
	end)
	bindable2:Fire()
	conn2:Disconnect()
	assert(hookFromSignal, "getcallingscript: failed validation inside hooked signal context")
end)

test("getscriptfromthread", {}, function()
	local thread = coroutine.running()
	local scr = getscriptfromthread(thread)
	assert(scr == nil or typeof(scr) == "Instance", "getscriptfromthread returned non-instance and non-nil value")
	
	local pcallStatus, err = pcall(function()
		getscriptfromthread("invalid_thread")
	end)
	assert(not pcallStatus, "getscriptfromthread failed to throw error on invalid argument type")
end)

test("getscriptclosure", {"getscriptfunction"}, function()
	local localScript = findLocalScript()

	if localScript then
		local closure = getscriptclosure(localScript)
		assert(type(closure) == "function", "getscriptclosure failed to return compiled closure from LocalScript")

		local env = debug.getinfo(closure)
		assert(type(env) == "table", "getscriptclosure closure: getinfo returned non-table")

		local closure2 = getscriptclosure(localScript)
		assert(type(closure2) == "function", "getscriptclosure: second call on same script returned non-function")

		local closure3 = getscriptclosure(localScript)
		assert(type(closure3) == "function", "getscriptclosure: third call on same script returned non-function")
	end

	local module = findModuleScript()
	if module then
		local constants = getrenv().require(module)
		local closure = getscriptclosure(module)
		assert(type(closure) == "function", "getscriptclosure failed to return compiled closure from ModuleScript")
		local generated = closure()
		assert(constants ~= generated, "Generated script closure returned identical table address")
		assert(shallowEqual(constants, generated) == true, "Generated script closure contents do not match target module constants")

		local closure2 = getscriptclosure(module)
		assert(type(closure2) == "function", "getscriptclosure: second call on same ModuleScript returned non-function")
		local gen2 = closure2()
		assert(shallowEqual(constants, gen2) == true, "getscriptclosure: second closure produced different output")
	end

	local emptyClosure = getscriptclosure(Instance_new("LocalScript"))
	assert(emptyClosure == nil, "getscriptclosure must return nil for LocalScript without bytecode")

	local emptyModule = getscriptclosure(Instance_new("ModuleScript"))
	assert(emptyModule == nil, "getscriptclosure must return nil for ModuleScript without bytecode")

	local fakeScript = Instance_new("Part")
	local fakeClosure = getscriptclosure(fakeScript)
	assert(fakeClosure == nil, "getscriptclosure must return nil for non-Script Instance")

	local folderScript = getscriptclosure(Instance_new("Folder"))
	assert(folderScript == nil, "getscriptclosure must return nil for Folder")

	local screenGui = getscriptclosure(Instance_new("ScreenGui"))
	assert(screenGui == nil, "getscriptclosure must return nil for ScreenGui")
end)

test("decompile", {}, {"getscriptbytecode"}, function()
	local target = findLocalScript() or findModuleScript()
	assert(target ~= nil, "decompile: no script with bytecode found for testing")

	local bytecode = getscriptbytecode(target)
	assert(type(bytecode) == "string" and #bytecode > 0, "decompile dependency getscriptbytecode returned empty bytecode")

	local decompiled = decompile(target)
	assert(type(decompiled) == "string" and #decompiled > 0, "decompile returned empty or non-string output (possible C++ stub)")

	local luauKeywords = { "local", "function", "end", "return", "if", "then", "else", "elseif", "for", "while", "do", "repeat", "until" }
	local keywordHits = 0
	for _, kw in ipairs(luauKeywords) do
		if string_match(decompiled, "%f[%a]" .. kw .. "%f[%A]") or string_match(decompiled, kw) then
			keywordHits += 1
		end
	end
	assert(keywordHits >= 3, "decompile output missing Luau keywords (got " .. keywordHits .. "/13) - likely a stub or fake")

	assert(#decompiled > 20, "decompile output too short to be valid decompiled source (" .. #decompiled .. " chars)")

	local fakeStrings = { "-- Decompile not supported", "return nil", "error(", "stub", "placeholder", "TODO", "not implemented" }
	for _, fake in ipairs(fakeStrings) do
		assert(string_match(decompiled, fake) == nil, "decompile returned known stub string: \"" .. fake .. "\"")
	end

	local canLoad = pcall(function()
		local func = loadstring(decompiled)
		assert(type(func) == "function", "decompile output failed loadstring compilation")
	end)
	assert(canLoad, "decompile output is not valid Luau source (failed loadstring)")

	local failStatus = pcall(function()
		decompile(12345)
	end)
	assert(not failStatus, "decompile failed to throw error on invalid argument")

	local diffScriptTarget = findModuleScript() or findLocalScript()
	if diffScriptTarget and diffScriptTarget ~= target then
		local diffScript = decompile(diffScriptTarget)
		assert(type(diffScript) == "string", "decompile second script returned non-string")
		assert(diffScript ~= decompiled, "decompile returned identical output for two different scripts")
	end
end)

test("restorefunction", {}, {"hookfunction"}, function()
	local function target() return "original" end
	local ref = hookfunction(target, function() return "hooked" end)
	assert(target() == "hooked", "hookfunction pre-restoration failed")
	restorefunction(target)
	assert(target() == "original", "restorefunction failed to revert function hook")

	local function target2(a, b) return a - b end
	local ref2 = hookfunction(target2, function(a, b) return a + b end)
	assert(target2(10, 3) == 13, "hookfunction pre-restore2 failed")
	restorefunction(target2)
	assert(target2(10, 3) == 7, "restorefunction failed second restore")
	assert(ref2(10, 3) == 13, "restorefunction: ref2 should still use hooked path")

	local function target3() return "trip_restore" end
	local r1 = hookfunction(target3, function() return "h1" end)
	local r2 = hookfunction(target3, function() return "h2" end)
	assert(target3() == "h2", "pre-restore triple hook failed")
	restorefunction(target3)
	assert(target3() == "trip_restore", "restorefunction: triple restore failed")
	assert(r2() == "h1", "restorefunction: r2 should still be h1")
	assert(r1() == "trip_restore", "restorefunction: r1 should still be original")

	local function target4(x) return x * 2 end
	local ref4 = hookfunction(target4, function(x) return x * 3 end)
	assert(target4(5) == 15, "hookfunction pre-restore4 failed")
	restorefunction(target4)
	assert(target4(5) == 10, "restorefunction: restore then re-hook failed")
	local ref4b = hookfunction(target4, function(x) return x * 7 end)
	assert(target4(5) == 35, "restorefunction: re-hook after restore failed")
	assert(ref4(5) == 15, "restorefunction: original ref still works after re-hook")
	restorefunction(target4)
	assert(target4(5) == 10, "restorefunction: final restore failed")
end)

test("hookfunction", {"replaceclosure"}, {"restorefunction"}, function()
	local function target(a, b) return a + b end
	local ref = hookfunction(target, function(a, b) return a * b end)

	assert(target(3, 4) == 12, "hookfunction target failed to divert execution")
	assert(ref(3, 4) == 7, "hookfunction original reference failed original execution path")
	assert(target ~= ref, "hookfunction returned identical function identity for reference")

	local calledWith = {}
	local function target2(...) return ... end
	local ref2 = hookfunction(target2, function(...)
		calledWith = { ... }
		return ...
	end)
	target2("a", "b", "c")
	assert(#calledWith == 3 and calledWith[1] == "a" and calledWith[2] == "b" and calledWith[3] == "c", "hookfunction failed to forward arguments")

	local function target3(x) return x * 2 end
	local ref3 = hookfunction(target3, function(x) return x * 3 end)
	local ref4 = hookfunction(target3, function(x) return x * 5 end)
	assert(target3(2) == 10, "hookfunction double-hook: latest hook not active")
	assert(ref4(2) == 6, "hookfunction double-hook: ref4 should return x*3")
	assert(ref3(2) == 4, "hookfunction double-hook: ref3 should return x*2")
	restorefunction(target3)

	local function target4() return "original" end
	local ref5 = hookfunction(target4, function() return "hooked" end)
	assert(target4() == "hooked", "hookfunction pre-hook failed")
	restorefunction(target4)
	assert(target4() == "original", "restorefunction after hookfunction failed")

	local varargFn = function(...) return ... end
	local varargRef = hookfunction(varargFn, function(...) return ... end)
	local results = { varargRef(1, 2, 3, 4, 5) }
	assert(#results == 5 and results[1] == 1 and results[5] == 5, "hookfunction vararg forwarding failed")
	restorefunction(varargFn)

	local function nilArgFn() return nil end
	local nilRef = hookfunction(nilArgFn, function() return nil end)
	local nr1, nr2 = nilRef()
	assert(nr1 == nil and nr2 == nil, "hookfunction nil return forwarding failed")
	restorefunction(nilArgFn)

	local function multiRetFn() return "x", "y", "z" end
	local multiRef = hookfunction(multiRetFn, function() return "a", "b", "c" end)
	local mr1, mr2, mr3, mr4 = multiRetFn()
	assert(mr1 == "a" and mr2 == "b" and mr3 == "c" and mr4 == nil, "hookfunction multi-return forwarding failed")
	restorefunction(multiRetFn)

	local function typeTest(v) return type(v) end
	local typeRef = hookfunction(typeTest, function(v) return type(v) .. "_hooked" end)
	assert(typeTest(42) == "number_hooked", "hookfunction type return test failed")
	assert(typeRef("str") == "string", "hookfunction ref type return test failed")
	restorefunction(typeTest)

	local function tableRetFn() return { key = "value" } end
	local tabRef = hookfunction(tableRetFn, function() return { key = "hooked" } end)
	local tab1 = tableRetFn()
	local tab2 = tabRef()
	assert(type(tab1) == "table" and tab1.key == "hooked", "hookfunction table return in hooked failed")
	assert(type(tab2) == "table" and tab2.key == "value", "hookfunction table return in ref failed")
	restorefunction(tableRetFn)

	local hookCount = 0
	local function counterFn() hookCount += 1; return hookCount end
	local counterRef = hookfunction(counterFn, function() hookCount += 10; return hookCount end)
	assert(counterFn() == 11, "hookfunction counter: hooked execution count wrong")
	assert(counterRef() == 12, "hookfunction counter: ref execution count wrong")
	restorefunction(counterFn)

	local function errorInHook() return "should_not_reach" end
	local errRef = hookfunction(errorInHook, function() return "hooked_value" end)
	assert(errorInHook() == "hooked_value", "hookfunction error-in-hook: hooked call failed")
	assert(errRef() == "should_not_reach", "hookfunction error-in-hook: ref call failed")
	restorefunction(errorInHook)

	local function selfRef() return selfRef end
	local selfRef2 = hookfunction(selfRef, function() return "hooked" end)
	assert(selfRef() == "hooked", "hookfunction self-referencing function: hooked failed")
	assert(type(selfRef2()) == "function", "hookfunction self-referencing function: ref should return function")
	restorefunction(selfRef)

	local originalFn = function() return "original" end
	local refA = hookfunction(originalFn, function() return "hook_a" end)
	local refB = hookfunction(originalFn, function() return "hook_b" end)
	local refC = hookfunction(originalFn, function() return "hook_c" end)
	assert(originalFn() == "hook_c", "hookfunction triple-hook: final hook not active")
	assert(refC() == "hook_b", "hookfunction triple-hook: refC wrong")
	assert(refB() == "hook_a", "hookfunction triple-hook: refB wrong")
	assert(refA() == "original", "hookfunction triple-hook: refA wrong")
	restorefunction(originalFn)
	assert(originalFn() == "original", "hookfunction triple-hook: restore failed")

	local function boolFn() return true end
	local boolRef = hookfunction(boolFn, function() return false end)
	assert(boolFn() == false, "hookfunction bool return: hooked wrong")
	assert(boolRef() == true, "hookfunction bool return: ref wrong")
	restorefunction(boolFn)

	local function numFn() return 3.14 end
	local numRef = hookfunction(numFn, function() return 2.71 end)
	assert(numFn() == 2.71, "hookfunction number return: hooked wrong")
	assert(numRef() == 3.14, "hookfunction number return: ref wrong")
	restorefunction(numFn)

	local function closureFn(x)
		local secret = x * 10
		return function() return secret end
	end
	local closureRef = hookfunction(closureFn, function(x)
		local secret = x * 20
		return function() return secret end
	end)
	local inner1 = closureFn(5)
	local inner2 = closureRef(5)
	assert(inner1() == 100, "hookfunction closure upvalue: hooked inner wrong")
	assert(inner2() == 50, "hookfunction closure upvalue: ref inner wrong")
	restorefunction(closureFn)

	local function bigArgFn(a, b, c, d, e, f, g, h) return a + h end
	local bigRef = hookfunction(bigArgFn, function(a, b, c, d, e, f, g, h) return a * h end)
	assert(bigArgFn(1, 2, 3, 4, 5, 6, 7, 8) == 8, "hookfunction 8-arg: hooked wrong")
	assert(bigRef(1, 2, 3, 4, 5, 6, 7, 8) == 9, "hookfunction 8-arg: ref wrong")
	restorefunction(bigArgFn)

	local function emptyFn() end
	local emptyRef = hookfunction(emptyFn, function() end)
	assert(emptyFn() == nil, "hookfunction empty return: hooked wrong")
	assert(emptyRef() == nil, "hookfunction empty return: ref wrong")
	restorefunction(emptyFn)
end)

test("hookmetamethod", {}, {"newcclosure", "restorefunction", "getrawmetatable"}, function()
	local obj = setmetatable({}, {
		__index = newcclosure(function() return "unhooked_index" end),
		__metatable = "Locked"
	})
	
	local ref
	ref = hookmetamethod(obj, "__index", function(...)
		return "hooked_index"
	end)

	assert(obj.test == "hooked_index", "hookmetamethod failed runtime interception")
	assert(ref() == "unhooked_index", "hookmetamethod original reference call mismatch")
	restorefunction(getrawmetatable(obj).__index)
end)

test("iscclosure", {}, {"newcclosure"}, function()
	assert(iscclosure(print) == true, "Native print must return true for iscclosure")
	assert(iscclosure(function() end) == false, "Executor Luau closure false-positive on iscclosure")

	local wrapped = newcclosure(function() end)
	assert(iscclosure(wrapped) == true, "newcclosure wrapper failed iscclosure verification")

	local function inner() return "luau" end
	assert(iscclosure(inner) == false, "Regular Luau function false-positive on iscclosure")

	local hookVerified = false
	local function target() end
	local ref = hookfunction(target, function() return "hooked" end)
	assert(iscclosure(ref) == false, "hookfunction original ref should not be cclosure")

	local cWrapped = newcclosure(function(x) return x end)
	assert(iscclosure(cWrapped) == true, "newcclosure with arg failed iscclosure")
	assert(cWrapped("test") == "test", "newcclosure with arg execution failed")
end)

test("islclosure", {}, {"newcclosure"}, function()
	assert(islclosure(print) == false, "Native print false-positive on islclosure")
	assert(islclosure(function() end) == true, "Executor Luau closure failed islclosure check")

	local wrapped = newcclosure(function() end)
	assert(islclosure(wrapped) == false, "newcclosure falsely identified as lclosure")

	local function withUpvalue()
		local x = 42
		return function() return x end
	end
	local inner = withUpvalue()
	assert(islclosure(inner) == true, "Luau closure with upvalue failed islclosure check")

	local function simple() return 1 end
	assert(islclosure(simple) == true, "Simple Luau function failed islclosure")

	assert(islclosure(nil) == false, "islclosure false-positive on nil")
end)

test("isexecutorclosure", {"checkclosure", "isourclosure"}, {"newcclosure"}, function()
	assert(isexecutorclosure(isexecutorclosure) == true, "isexecutorclosure failed self-check")
	assert(isexecutorclosure(newcclosure(function() end)) == true, "newcclosure failed isexecutorclosure check")
	assert(isexecutorclosure(function() end) == true, "Executor Luau function failed check")
	assert(isexecutorclosure(print) == false, "Roblox native global print falsely marked as executor closure")
	assert(isexecutorclosure(error) == false, "Roblox native error falsely marked as executor closure")
	assert(isexecutorclosure(pcall) == false, "Roblox native pcall falsely marked as executor closure")
	assert(isexecutorclosure(type) == false, "Roblox native type falsely marked as executor closure")
	assert(isexecutorclosure(tostring) == false, "Roblox native tostring falsely marked as executor closure")
	assert(isexecutorclosure(tonumber) == false, "Roblox native tonumber falsely marked as executor closure")

	local function executorTest() return "exec" end
	assert(isexecutorclosure(executorTest) == true, "Executor-defined function failed isexecutorclosure")
end)

test("loadstring", {}, {"getscriptbytecode"}, function()
	local target = findLocalScript()
	if target then
		local bytecode = getscriptbytecode(target)
		if type(bytecode) == "string" and #bytecode > 0 then
			local func, err = loadstring(bytecode)
			if type(func) == "function" then
				local canCall = pcall(func)
				if canCall then
					error("loadstring accepted raw bytecode - should reject or error")
				end
			end
		end
	end

	local loaded, err = loadstring("local a, b, c = ...; return a + b + c")
	assert(type(loaded) == "function", "loadstring failed valid string compilation: " .. tostring(err))
	assert(loaded(10, 20, 30) == 60, "loadstring compiled function failed multi-argument execution")

	local errFunc, errMessage = loadstring("local invalid luau syntax !!!")
	assert(errFunc == nil and type(errMessage) == "string", "loadstring failed compiler error reporting")

	local envTest = loadstring("return _ENV")
	assert(type(envTest) == "function", "loadstring failed basic compilation")
	local env = envTest()
	assert(type(env) == "table", "loadstring compiled function _ENV table mismatch")

	local chunkName = loadstring("return 1", "UNCChunkName")
	assert(type(chunkName) == "function", "loadstring with chunk name failed")

	local upvalTest = loadstring("local x = 99; return function() return x end")
	local upvalFn = upvalTest()
	assert(type(upvalFn) == "function" and upvalFn() == 99, "loadstring upvalue capture failed")

	local recursive = loadstring("local function fib(n) if n <= 1 then return n end return fib(n-1) + fib(n-2) end; return fib(10)")
	assert(recursive() == 55, "loadstring recursive function execution failed")

	local multiReturn = loadstring("return 1, 2, 3")
	local r1, r2, r3 = multiReturn()
	assert(r1 == 1 and r2 == 2 and r3 == 3, "loadstring multi-return failed")

	local closureTest = loadstring("local x = 10; return function(y) return x + y end")
	local fn = closureTest()
	assert(type(fn) == "function" and fn(5) == 15, "loadstring closure with upvalue failed")
end)

test("newcclosure", {}, {"iscclosure", "islclosure", "clonefunction"}, function()
	local function luauFunc(a, b) return a ^ b end
	local cClosure = newcclosure(luauFunc)

	assert(luauFunc(2, 8) == cClosure(2, 8), "newcclosure returned mismatched calculation output")
	assert(luauFunc ~= cClosure, "newcclosure returned identical function identity")
	assert(iscclosure(cClosure) == true, "newcclosure wrapper failed iscclosure verification")
	assert(islclosure(cClosure) == false, "newcclosure wrapper incorrectly detected as lclosure")

	local clonedCClosure = clonefunction(cClosure)
	assert(iscclosure(clonedCClosure) == true, "cloned newcclosure lost C-closure status")
	assert(islclosure(clonedCClosure) == false, "cloned newcclosure incorrectly detected as lclosure")
	assert(clonedCClosure(2, 8) == 256, "cloned newcclosure execution output mismatch")
	assert(cClosure ~= clonedCClosure, "cloned newcclosure shares identity with original wrapper")

	local function innerLuau(x) return x + 1 end
	local wrapped = newcclosure(innerLuau)
	local unhookedRef = hookfunction(wrapped, function(x) return x - 1 end)
	assert(wrapped(10) == 9, "hooked newcclosure failed interception")
	assert(unhookedRef(10) == 11, "hooked newcclosure original reference wrong output")
	restorefunction(wrapped)

	local function multiReturn() return "a", "b", "c" end
	local wrappedMulti = newcclosure(multiReturn)
	local r1, r2, r3 = wrappedMulti()
	assert(r1 == "a" and r2 == "b" and r3 == "c", "newcclosure multi-return forwarding failed")
end)

test("newlclosure", {}, {"islclosure"}, function()
	local function cFunc() return 100 end
	local lClosure = newlclosure(cFunc)

	assert(islclosure(lClosure) == true, "newlclosure failed islclosure verification")
	assert(lClosure() == 100, "newlclosure output mismatch")

	local function withUpvalue()
		local x = 42
		return function() return x end
	end
	local inner = withUpvalue()
	local wrappedInner = newlclosure(inner)
	assert(islclosure(wrappedInner) == true, "newlclosure wrapping lclosure: failed islclosure")
	assert(wrappedInner() == 42, "newlclosure wrapping lclosure: output mismatch")

	local function multiReturn() return "a", "b", "c" end
	local wrappedMulti = newlclosure(multiReturn)
	local r1, r2, r3 = wrappedMulti()
	assert(r1 == "a" and r2 == "b" and r3 == "c", "newlclosure multi-return failed")

	local function varargFn(...) return ... end
	local wrappedVararg = newlclosure(varargFn)
	local vr1, vr2 = wrappedVararg(10, 20)
	assert(vr1 == 10 and vr2 == 20, "newlclosure vararg forwarding failed")
end)

test("crypt.base64decode", {"crypt.base64.decode", "crypt.base64_decode", "base64.decode", "base64_decode"}, function()
	assert(crypt.base64decode("VU5DX1RFU1RfREFUQQ==") == "UNC_TEST_DATA", "Base64 decoding mismatch")
	assert(crypt.base64decode("") == "", "Base64 decode of empty string failed")
	assert(crypt.base64decode("QQ==") == "A", "Base64 single char decode failed")
	assert(crypt.base64decode("VU5D") == "UNC", "Base64 3-char padding decode failed")
end)

test("crypt.base64encode", {"crypt.base64.encode", "crypt.base64_encode", "base64.encode", "base64_encode"}, {"crypt.base64decode"}, function()
	local raw = "UNC_ENCODE_TEST_PAYLOAD"
	local encoded = crypt.base64encode(raw)
	assert(type(encoded) == "string" and #encoded > 0, "Base64 encode failed string generation")
	assert(crypt.base64decode(encoded) == raw, "Base64 decode cycle failed to recover original payload")

	local emptyEncoded = crypt.base64encode("")
	assert(crypt.base64decode(emptyEncoded) == "", "Base64 empty string encode/decode cycle failed")

	local specialEncoded = crypt.base64encode("hello world! @#$%")
	assert(crypt.base64decode(specialEncoded) == "hello world! @#$%", "Base64 special chars encode/decode cycle failed")
end)

test("crypt.generatekey", {}, function()
	local keyEncoded = crypt.generatekey()
	local rawKey = crypt.base64decode(keyEncoded)
	assert(#rawKey == 32, "crypt.generatekey key is not 256-bit (32 bytes)")

	local key2 = crypt.generatekey()
	local rawKey2 = crypt.base64decode(key2)
	assert(#rawKey2 == 32, "crypt.generatekey second key not 256-bit")
	assert(keyEncoded ~= key2, "crypt.generatekey produced identical keys")
end)

test("crypt.encrypt", {}, {"crypt.generatekey", "crypt.decrypt"}, function()
	local key = crypt.generatekey()
	local payload = "secret_string_payload_123"
	local encrypted, iv = crypt.encrypt(payload, key, nil, "CBC")

	assert(type(encrypted) == "string" and #encrypted > 0, "crypt.encrypt failed payload generation")
	assert(iv ~= nil, "crypt.encrypt CBC mode failed to yield initialization vector (IV)")

	local decrypted = crypt.decrypt(encrypted, key, iv, "CBC")
	assert(decrypted == payload, "Crypt encryption/decryption cycle payload mismatch")

	local emptyEncrypted, emptyIv = crypt.encrypt("", key, nil, "CBC")
	assert(type(emptyEncrypted) == "string", "crypt.encrypt empty payload failed")
	local emptyDecrypted = crypt.decrypt(emptyEncrypted, key, emptyIv, "CBC")
	assert(emptyDecrypted == "", "crypt.encrypt empty payload decrypt mismatch")

	local longPayload = string_rep("A", 10000)
	local longEnc, longIv = crypt.encrypt(longPayload, key, nil, "CBC")
	local longDec = crypt.decrypt(longEnc, key, longIv, "CBC")
	assert(longDec == longPayload, "crypt.encrypt 10KB payload cycle failed")
end)

test("crypt.decrypt", {}, {"crypt.generatekey", "crypt.encrypt"}, function()
	local key, iv = crypt.generatekey(), crypt.generatekey()
	local encrypted = crypt.encrypt("stream_test", key, iv, "CBC")
	local decrypted = crypt.decrypt(encrypted, key, iv, "CBC")
	assert(decrypted == "stream_test", "Explicit IV decryption cycle mismatch")

	local key2 = crypt.generatekey()
	local enc2 = crypt.encrypt("payload_2", key2, nil, "CBC")
	local dec2 = crypt.decrypt(enc2, key2, nil, "CBC")
	assert(dec2 == "payload_2", "crypt.decrypt with auto-generated IV failed")
end)

test("crypt.generatebytes", {}, {"crypt.base64decode"}, function()
	local size = math_random(32, 128)
	local bytesEncoded = crypt.generatebytes(size)
	local rawBytes = crypt.base64decode(bytesEncoded)
	assert(#rawBytes == size, "crypt.generatebytes byte length mismatch after decoding")

	local size2 = math_random(32, 128)
	local bytes2 = crypt.base64decode(crypt.generatebytes(size2))
	assert(#bytes2 == size2, "crypt.generatebytes second call byte length mismatch")
end)

test("crypt.hash", {}, function()
	local algos = {'sha1', 'sha384', 'sha512', 'md5', 'sha256', 'sha3-224', 'sha3-256', 'sha3-512'}
	for _, algo in ipairs(algos) do
		local hash = crypt.hash("sample_input", algo)
		assert(type(hash) == "string" and #hash > 0, "crypt.hash digest generation failed for: " .. algo)

		local hash2 = crypt.hash("sample_input", algo)
		assert(hash == hash2, "crypt.hash non-deterministic for: " .. algo)

		local diffHash = crypt.hash("different_input", algo)
		assert(hash ~= diffHash, "crypt.hash collision for: " .. algo)
	end

	local sha256 = crypt.hash("test", "sha256")
	assert(#sha256 == 64, "crypt.hash sha256 digest length wrong (expected 64 hex chars)")

	local md5hash = crypt.hash("test", "md5")
	assert(#md5hash == 32, "crypt.hash md5 digest length wrong (expected 32 hex chars)")
end)

test("debug.getconstant", {}, function()
	local function sample() print("target_constant_123") end
	assert(debug.getconstant(sample, 1) == "print", "Constant 1 mismatch")
	assert(debug.getconstant(sample, 3) == "target_constant_123", "Constant 3 mismatch")

	local function multiConst()
		local x = 99
		return x
	end
	local c1 = debug.getconstant(multiConst, 1)
	assert(type(c1) == "number" and c1 == 99, "debug.getconstant number constant mismatch")

	local function strConst() return "hello_world" end
	assert(debug.getconstant(strConst, 1) == "hello_world", "debug.getconstant string constant mismatch")
end)

test("debug.getconstants", {}, function()
	local function sample()
		local num = 99999
		print("constant_str", warn)
	end
	local constants = debug.getconstants(sample)
	assert(constants[1] == 99999, "constants index 1 mismatch")
	assert(constants[2] == "print", "constants index 2 mismatch")
	assert(constants[4] == "constant_str", "constants index 4 mismatch")
	assert(type(constants) == "table", "debug.getconstants returned non-table")

	local function simple() return 1 end
	local simpleConst = debug.getconstants(simple)
	assert(type(simpleConst) == "table", "debug.getconstants failed on simple function")
end)

test("debug.getinfo", {}, function()
	local function sample(a, b, ...) print(a, b, ...) end
	local info = debug.getinfo(sample)

	assert(type(info) == "table", "getinfo failed to return debug metadata table")
	assert(info.func == sample, "getinfo function reference mismatch")
	assert(info.numparams == 2, "getinfo numparams count mismatch")
	assert(info.is_vararg == 1 or info.is_vararg == true, "getinfo vararg detection mismatch")

	local boom = 3
	local ookok = "real"
	local potatopride = function(...)
		boom = "ookok"
		ookok = "boom"
		return ookok
	end
	local info2 = debug.getinfo(potatopride)
	if info2.nups ~= nil then
		assert(info2.nups >= 2, "getinfo nups count mismatch (expected >=2, got " .. tostring(info2.nups) .. ")")
	end

	local function noArgFunc() return "noargs" end
	local info3 = debug.getinfo(noArgFunc)
	assert(info3.numparams == 0, "getinfo numparams for zero-arg function mismatch")
	assert(info3.name == nil or type(info3.name) == "string", "getinfo.name type check failed")

	local info4 = debug.getinfo(print)
	assert(type(info4) == "table", "getinfo failed on native print function")
end)

test("debug.getproto", {}, function()
	local function parent()
		local function child() return "inner_proto_exec" end
		return child
	end
	local protos = debug.getproto(parent, 1, true)
	assert(type(protos) == "table", "debug.getproto failed to return table of prototypes")
	local proto = protos[1]
	assert(type(proto) == "function", "Failed to retrieve inner prototype function")
	assert(proto() == "inner_proto_exec", "Retrieved inner prototype execution mismatch")

	local function multiChild()
		local function a() return 10 end
		local function b() return 20 end
		return a, b
	end
	local p1 = debug.getproto(multiChild, 1, true)
	local p2 = debug.getproto(multiChild, 2, true)
	assert(type(p1) == "table" and type(p2) == "table", "debug.getproto failed multi-proto retrieval")
	assert(p1[1]() == 10, "debug.getproto proto 1 value mismatch")
	assert(p2[1]() == 20, "debug.getproto proto 2 value mismatch")

	local function withUpvalue()
		local secret = "upvalue_check_999"
		local function inner() return secret end
		return inner
	end
	local innerProto = debug.getproto(withUpvalue, 1, true)
	local innerFn = innerProto[1]
	assert(type(innerFn) == "function", "debug.getproto inner proto is not a function")

	local function simple() return "direct" end
	local flatProto = debug.getproto(simple, 1, true)
	assert(type(flatProto) == "table", "debug.getproto flat function proto check failed")

	local fakeCheck = debug.getproto(function() return "real" end, 1, true)
	assert(type(fakeCheck) == "table", "debug.getproto: returned non-table (possible spoof)")
end)

test("debug.getprotos", {}, function()
	local function parent()
		local function p1() return 1 end
		local function p2() return 2 end
		local function p3() return 3 end
	end
	local protos = debug.getprotos(parent)
	assert(#protos == 3, "debug.getprotos failed to count inner prototypes")
end)

test("debug.getstack", {}, function()
	local _ = "stack_val_1" .. "stack_val_2"
	assert(debug.getstack(1, 1) == "stack_val_1stack_val_2", "debug.getstack failed stack frame evaluation")

	local function innerFrame()
		local x = "inner_val"
		return debug.getstack(1, 1)
	end
	assert(innerFrame() == "inner_val", "debug.getstack inner frame read failed")

	local function deepFrame()
		local function deepest()
			local z = "deepest_val"
			return debug.getstack(1, 1)
		end
		return deepest()
	end
	assert(deepFrame() == "deepest_val", "debug.getstack deep nested frame failed")

	local multiA, multiB = "alpha", "beta"
	local readMulti = debug.getstack(1, 1)
	assert(type(readMulti) ~= "nil" or true, "debug.getstack first position check")

	local function noLocal() return debug.getstack(1, 1) end
	local result = noLocal()
end)

test("debug.setstack", {}, function()
	local function sample()
		return "initial_val", debug.setstack(1, 1, "mutated_val")
	end
	assert(sample() == "mutated_val", "debug.setstack stack modification failed")

	local function multiMutate()
		debug.setstack(1, 1, "mutated_first")
		return debug.getstack(1, 1)
	end
	assert(multiMutate() == "mutated_first", "debug.setstack set-then-get failed")

	local function numberMutate()
		debug.setstack(1, 1, 99999)
		return debug.getstack(1, 1)
	end
	assert(numberMutate() == 99999, "debug.setstack number mutation failed")

	local function nilMutate()
		debug.setstack(1, 1, nil)
		return "executed"
	end
	assert(nilMutate() == "executed", "debug.setstack nil mutation execution failed")

	local function boolMutate()
		debug.setstack(1, 1, true)
		return debug.getstack(1, 1)
	end
	assert(boolMutate() == true, "debug.setstack boolean mutation failed")
end)

test("debug.getstack + debug.setstack + hookfunction", {}, {"hookfunction", "restorefunction", "debug.getstack", "debug.setstack"}, function()
	local function target()
		local localVal = "original_local"
		return localVal
	end

	local originalRef
	originalRef = hookfunction(target, function(...)
		local stackVal = debug.getstack(2, 1)
		debug.setstack(2, 1, "intercepted_local")
		return originalRef(...)
	end)

	local result = target()
	restorefunction(target)
	assert(result == "intercepted_local", "debug.setstack inside hookfunction failed to mutate target stack frame")

	local function multiLocal()
		local a = "aaa"
		local b = "bbb"
		local c = "ccc"
		return a, b, c
	end
	local refMulti
	refMulti = hookfunction(multiLocal, function(...)
		local s1 = debug.getstack(2, 1)
		local s2 = debug.getstack(2, 2)
		local s3 = debug.getstack(2, 3)
		debug.setstack(2, 1, "MUTATED_A")
		debug.setstack(2, 2, "MUTATED_B")
		debug.setstack(2, 3, "MUTATED_C")
		return refMulti(...)
	end)
	local r1, r2, r3 = multiLocal()
	restorefunction(multiLocal)
	assert(r1 == "MUTATED_A" and r2 == "MUTATED_B" and r3 == "MUTATED_C", "debug.setstack multi-local mutation failed")

	local function readStack()
		local x = "read_test"
		local y = debug.getstack(1, 1)
		return y
	end
	assert(readStack() == "read_test", "debug.getstack read from same frame failed")

	local function deepStack()
		local function inner()
			local val = "deep_value"
			return debug.getstack(1, 1)
		end
		return inner()
	end
	assert(deepStack() == "deep_value", "debug.getstack deep frame read failed")

	local function mutateAndRead()
		local a = "before"
		debug.setstack(1, 1, "after")
		local b = debug.getstack(1, 1)
		return a, b
	end
	local before, after = mutateAndRead()
	assert(before == "after", "debug.setstack mutate-then-read: before value wrong")
	assert(after == "after", "debug.setstack mutate-then-read: after value wrong")

	local function hookReadStack()
		local upv = "hooked_upv_val"
		return upv
	end
	local refHS
	refHS = hookfunction(hookReadStack, function(...)
		local fromStack = debug.getstack(2, 1)
		debug.setstack(2, 1, "overwritten_in_hook")
		return refHS(...)
	end)
	local hookResult = hookReadStack()
	restorefunction(hookReadStack)
	assert(hookResult == "overwritten_in_hook", "debug.setstack in hook: overwrite failed")
end)

test("debug.getupvalue", {}, function()
	local secret = "upvalue_secret_val"
	local function sample() print(secret) end
	assert(debug.getupvalue(sample, 1) == "upvalue_secret_val", "debug.getupvalue value mismatch")

	local uv1, uv2, uv3 = "a", "b", "c"
	local function multi() print(uv1, uv2, uv3) end
	assert(debug.getupvalue(multi, 1) == "a", "debug.getupvalue index 1 mismatch")
	assert(debug.getupvalue(multi, 2) == "b", "debug.getupvalue index 2 mismatch")
	assert(debug.getupvalue(multi, 3) == "c", "debug.getupvalue index 3 mismatch")

	local noUpvFunc = function() return 42 end
	local uv = debug.getupvalue(noUpvFunc, 1)
	-- upvalue 1 of a function with no upvalues should be nil or special
end)

test("debug.getupvalues", {}, function()
	local secret = "upvalue_secret_val"
	local function sample() print(secret) end
	local uv = debug.getupvalues(sample)
	assert(uv[1] == "upvalue_secret_val", "debug.getupvalues index 1 mismatch")
	assert(type(uv) == "table", "debug.getupvalues returned non-table")

	local multi = "a"
	local multi2 = "b"
	local function multiFn() print(multi, multi2) end
	local uvMulti = debug.getupvalues(multiFn)
	assert(type(uvMulti) == "table" and #uvMulti >= 2, "debug.getupvalues failed multi-upvalue retrieval")
end)

test("debug.setconstant", {}, function()
	local function sample() return "original_const" end
	debug.setconstant(sample, 1, "modified_const")
	assert(sample() == "modified_const", "debug.setconstant failed to mutate target constant")

	debug.setconstant(sample, 1, "second_modification")
	assert(sample() == "second_modification", "debug.setconstant second mutation failed")

	debug.setconstant(sample, 1, "")
	assert(sample() == "", "debug.setconstant empty string mutation failed")

	debug.setconstant(sample, 1, 999)
	assert(sample() == 999, "debug.setconstant number mutation failed")
end)

test("debug.setupvalue", {}, function()
	local upv = function() return "initial_upv" end
	local function sample() return upv() end

	debug.setupvalue(sample, 1, function() return "modified_upv" end)
	assert(sample() == "modified_upv", "debug.setupvalue upvalue modification failed")

	debug.setupvalue(sample, 1, function() return 42 end)
	assert(sample() == 42, "debug.setupvalue second modification failed")

	local secret1 = "secret1"
	local secret2 = "secret2"
	local function multiUpv() return secret1, secret2 end

	debug.setupvalue(multiUpv, 1, "changed1")
	debug.setupvalue(multiUpv, 2, "changed2")
	local r1, r2 = multiUpv()
	assert(r1 == "changed1" and r2 == "changed2", "debug.setupvalue multi-upvalue modification failed")
end)

test("debug.validlevel", {}, function()
	assert(debug.validlevel(1) == true, "debug.validlevel failed valid stack check")
	assert(debug.validlevel(99999) == false, "debug.validlevel false-positive on stack level 99999")
	assert(debug.validlevel(0) == false, "debug.validlevel false-positive on level 0")
	assert(debug.validlevel(-1) == false, "debug.validlevel false-negative on negative level")
	assert(debug.validlevel(2) == true, "debug.validlevel failed valid level 2 check")
end)

if isfolder and makefolder and delfolder then
	if isfolder(".unc_fs_root") then delfolder(".unc_fs_root") end
	makefolder(".unc_fs_root")
end

test("writefile", {}, function()
	writefile(".unc_fs_root/write_test.txt", "writefile_content_456")
	assert(readfile(".unc_fs_root/write_test.txt") == "writefile_content_456", "writefile failed to persist file stream")
end)

test("readfile", {}, {"writefile"}, function()
	writefile(".unc_fs_root/read_test.txt", "readfile_content_123")
	assert(readfile(".unc_fs_root/read_test.txt") == "readfile_content_123", "readfile string content mismatch")
end)

test("appendfile", {}, {"writefile", "readfile"}, function()
	writefile(".unc_fs_root/append_test.txt", "chunk1_")
	appendfile(".unc_fs_root/append_test.txt", "chunk2")
	assert(readfile(".unc_fs_root/append_test.txt") == "chunk1_chunk2", "appendfile stream concatenation mismatch")
end)

test("loadfile", {}, {"writefile"}, function()
	writefile(".unc_fs_root/exec_test.txt", "local x, y, z = ...; return (x + y) * z")
	local compiled = assert(loadfile(".unc_fs_root/exec_test.txt"))
	assert(compiled(2, 3, 10) == 50, "loadfile compiled script execution output mismatch")
end)

test("listfiles", {}, {"makefolder", "writefile"}, function()
	makefolder(".unc_fs_root/dir_sample")
	writefile(".unc_fs_root/dir_sample/f1.txt", "a")
	writefile(".unc_fs_root/dir_sample/f2.txt", "b")
	local list = listfiles(".unc_fs_root/dir_sample")
	assert(#list == 2, "listfiles count mismatch")
end)

test("isfile", {}, {"writefile"}, function()
	writefile(".unc_fs_root/exist.txt", "data")
	assert(isfile(".unc_fs_root/exist.txt") == true, "isfile false-negative on active file")
	assert(isfile(".unc_fs_root") == false, "isfile false-positive on folder path")
end)

test("isfolder", {}, {"makefolder"}, function()
	assert(isfolder(".unc_fs_root") == true, "isfolder false-negative on active folder")
	assert(isfolder(".unc_fs_root/phantom_file.txt") == false, "isfolder false-positive on non-existent path")
end)

test("delfile", {}, {"writefile", "isfile"}, function()
	writefile(".unc_fs_root/del.txt", "temp")
	delfile(".unc_fs_root/del.txt")
	assert(isfile(".unc_fs_root/del.txt") == false, "delfile failed file deletion")
end)

test("delfolder", {}, {"makefolder", "isfolder"}, function()
	makefolder(".unc_fs_root/del_dir")
	delfolder(".unc_fs_root/del_dir")
	assert(isfolder(".unc_fs_root/del_dir") == false, "delfolder failed folder deletion")
end)

test("fireclickdetector", {}, function()
	local cd = Instance_new("ClickDetector")
	assert(pcall(function() fireclickdetector(cd, 25, "MouseHoverEnter") end), "fireclickdetector failed multi-arg execution")
end)

test("fireproximityprompt", {}, function()
	local prompt = Instance_new("ProximityPrompt")
	assert(pcall(function() fireproximityprompt(prompt) end), "fireproximityprompt execution error")
end)

test("firetouchinterest", {}, function()
	local p1 = Instance_new("Part")
	local p2 = Instance_new("Part")
	assert(pcall(function() firetouchinterest(p1, p2, 0) firetouchinterest(p1, p2, 1) end), "firetouchinterest state toggles failed")
end)

test("firesignal", {}, {"getconnections"}, function()
	local bindable = Instance_new("BindableEvent")
	local received = false
	local conn = bindable.Event:Connect(function(arg) received = arg end)
	firesignal(bindable.Event, "firesignal_test_payload")
	task_wait(0.1)
	assert(received == "firesignal_test_payload", "firesignal failed single-arg event dispatch")

	received = false
	firesignal(bindable.Event, "arg1", "arg2", 42)
	task_wait(0.1)
	assert(received == "arg1", "firesignal failed multi-arg event dispatch (first arg mismatch)")

	local multiReceived = {}
	local conn2 = bindable.Event:Connect(function(a, b, c)
		multiReceived = { a, b, c }
	end)
	firesignal(bindable.Event, "x", "y", "z")
	task_wait(0.1)
	assert(multiReceived[1] == "x" and multiReceived[2] == "y" and multiReceived[3] == "z", "firesignal multi-arg payload corruption")

	conn:Disconnect()
	conn2:Disconnect()

	local deadReceived = false
	bindable.Event:Connect(function() deadReceived = true end)
	conn:Disconnect()
	firesignal(bindable.Event, "post_disconnect")
	task_wait(0.1)

	local conns = getconnections(bindable.Event)
	assert(type(conns) == "table" and #conns >= 1, "firesignal+getconnections: connection count mismatch after signal fire")
end)

test("replicatesignal", {}, function()
	local bindable = Instance_new("BindableEvent")
	local received = false
	bindable.Event:Connect(function(val) received = val end)

	replicatesignal(bindable.Event, true)
	task_wait(0.1)
	assert(received == true, "replicatesignal failed to dispatch network signal trigger with true")

	received = false
	replicatesignal(bindable.Event, false)
	task_wait(0.1)
	assert(received == false, "replicatesignal failed to dispatch false value")

	received = nil
	replicatesignal(bindable.Event, "test_payload_123")
	task_wait(0.1)
	assert(received == "test_payload_123", "replicatesignal failed to dispatch string payload")

	local multiArg = {}
	local conn = bindable.Event:Connect(function(a, b, c) multiArg = { a, b, c } end)
	replicatesignal(bindable.Event, "x", "y", "z")
	task_wait(0.1)
	conn:Disconnect()
	assert(multiArg[1] == "x" and multiArg[2] == "y" and multiArg[3] == "z", "replicatesignal multi-arg payload corruption")
end)

test("getcallbackvalue", {}, function()
	local bindable = Instance_new("BindableFunction")
	local function sample() return "invoked" end
	bindable.OnInvoke = sample
	assert(getcallbackvalue(bindable, "OnInvoke") == sample, "getcallbackvalue reference mismatch on OnInvoke")
	
	local targetOnClose = function(...) warn("closing son") end
	game.OnClose = targetOnClose
	
	local onCloseCb = getcallbackvalue(game, "OnClose")
	if onCloseCb == nil then
		error("Returned nil for OnClose callback")
	end
	assert(onCloseCb == targetOnClose, "getcallbackvalue failed to return exact assigned OnClose callback function")
end)

test("getconnections", {}, function()
	local bindable = Instance_new("BindableEvent")
	local callCount = 0
	local conn1 = bindable.Event:Connect(function() callCount += 1 end)
	local conn2 = bindable.Event:Connect(function() callCount += 1 end)
	local connections = getconnections(bindable.Event)

	assert(type(connections) == "table" and #connections >= 2, "getconnections count mismatch (expected >=2, got " .. #connections .. ")")

	local hasDisable, hasEnable, hasDisconnect, hasFunction = 0, 0, 0, 0
	for i, c in ipairs(connections) do
		assert(type(c) == "table" or typeof(c) == "RBXScriptConnection", "getconnections[" .. i .. "] returned non-table/non-connection type")
		if type(c.Disable) == "function" then hasDisable += 1 end
		if type(c.Enable) == "function" then hasEnable += 1 end
		if type(c.Disconnect) == "function" then hasDisconnect += 1 end
		if type(c.Function) == "function" then hasFunction += 1 end
	end
	assert(hasDisable == #connections, "getconnections: not all connections have Disable method (" .. hasDisable .. "/" .. #connections .. ")")
	assert(hasEnable == #connections, "getconnections: not all connections have Enable method (" .. hasEnable .. "/" .. #connections .. ")")
	assert(hasDisconnect == #connections, "getconnections: not all connections have Disconnect method (" .. hasDisconnect .. "/" .. #connections .. ")")

	callCount = 0
	for _, c in ipairs(connections) do
		c:Disable()
	end
	bindable:Fire()
	task_wait(0.05)
	assert(callCount == 0, "getconnections: Disable failed to suppress signal delivery")

	for _, c in ipairs(connections) do
		c:Enable()
	end
	callCount = 0
	bindable:Fire()
	task_wait(0.05)
	assert(callCount >= 2, "getconnections: Enable failed to restore signal delivery (got " .. callCount .. " calls)")

	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	callCount = 0
	bindable:Fire()
	task_wait(0.05)
	assert(callCount == 0, "getconnections: Disconnect failed to fully sever signal path")

	local emptyConns = getconnections(Instance_new("BindableEvent").Event)
	assert(type(emptyConns) == "table" and #emptyConns == 0, "getconnections returned non-empty table for signal with zero connections")

	local bindable2 = Instance_new("BindableEvent")
	local trackOrder = {}
	local connA = bindable2.Event:Connect(function() table_insert(trackOrder, "A") end)
	local connB = bindable2.Event:Connect(function() table_insert(trackOrder, "B") end)
	local connC = bindable2.Event:Connect(function() table_insert(trackOrder, "C") end)
	local allConns = getconnections(bindable2.Event)
	assert(#allConns >= 3, "getconnections failed to return 3 connections")

	local connsA = getconnections(bindable2.Event)
	for _, c in ipairs(connsA) do c:Disconnect() end
	local afterDisconnect = getconnections(bindable2.Event)
	assert(#afterDisconnect == 0, "getconnections: failed to reflect disconnected state")
end)

test("getcustomasset", {}, {"writefile"}, function()
	writefile(".unc_fs_root/custom_asset.txt", "asset_raw_bytes")
	local asset = getcustomasset(".unc_fs_root/custom_asset.txt")
	assert(type(asset) == "string" and #asset > 0, "getcustomasset returned empty or non-string")
	assert(string_match(asset, "rbxasset://") ~= nil, "getcustomasset failed generating valid rbxasset string format")

	local longData = string_rep("A", 5000)
	writefile(".unc_fs_root/long_asset.txt", longData)
	local longAsset = getcustomasset(".unc_fs_root/long_asset.txt")
	assert(type(longAsset) == "string" and string_match(longAsset, "rbxasset://") ~= nil, "getcustomasset failed on large file")

	local emptyData = ""
	writefile(".unc_fs_root/empty_asset.txt", emptyData)
	local emptyAsset = getcustomasset(".unc_fs_root/empty_asset.txt")
	assert(type(emptyAsset) == "string", "getcustomasset failed on empty file")
end)

test("gethiddenproperty + sethiddenproperty", {}, {"gethiddenproperty", "sethiddenproperty"}, function()
	local fire = Instance_new("Fire")

	local initialVal, isHidden = gethiddenproperty(fire, "size_xml")
	assert(isHidden == true, "gethiddenproperty failed detecting hidden status for size_xml")
	assert(type(initialVal) == "number", "gethiddenproperty returned non-number for size_xml")
	assert(initialVal ~= 0, "gethiddenproperty size_xml default value was 0 (unlikely default)")

	sethiddenproperty(fire, "size_xml", 42)
	local updatedVal = gethiddenproperty(fire, "size_xml")
	assert(updatedVal == 42, "sethiddenproperty failed to mutate hidden property size_xml (expected 42, got " .. tostring(updatedVal) .. ")")

	sethiddenproperty(fire, "size_xml", 100)
	local updatedVal2 = gethiddenproperty(fire, "size_xml")
	assert(updatedVal2 == 100, "sethiddenproperty failed second mutation (expected 100, got " .. tostring(updatedVal2) .. ")")

	sethiddenproperty(fire, "size_xml", 0)
	local updatedVal3 = gethiddenproperty(fire, "size_xml")
	assert(updatedVal3 == 0, "sethiddenproperty failed zero-value mutation")

	local brightness1, brightHidden = gethiddenproperty(fire, "Brightness")
	assert(brightHidden == true, "gethiddenproperty failed detecting Brightness as hidden")

	sethiddenproperty(fire, "Brightness", 0.5)
	local brightness2 = gethiddenproperty(fire, "Brightness")
	assert(brightness2 == 0.5, "sethiddenproperty failed Brightness mutation (expected 0.5, got " .. tostring(brightness2) .. ")")

	local _, notHidden = gethiddenproperty(fire, "Size")
	assert(notHidden == false, "gethiddenproperty false-positive: Size reported as hidden when it is not")

	local part = Instance_new("Part")
	local partVal, partHidden = gethiddenproperty(part, "size_xml")
	assert(partHidden == true, "gethiddenproperty failed hidden detection on Part instance")
end)

test("gethiddenproperties", {}, {"gethiddenproperty"}, function()
	local fire = Instance_new("Fire")
	local props = gethiddenproperties(fire)
	assert(type(props) == "table", "gethiddenproperties must return a table")
	assert(props["size_xml"] ~= nil or next(props) ~= nil, "gethiddenproperties returned empty table")
end)

test("gethui", {}, function()
	local hui = gethui()
	assert(typeof(hui) == "Instance", "gethui failed returning active container Instance")
	assert(hui ~= game:GetService("CoreGui"), "gethui returned CoreGui directly (should be a child container)")
end)

test("getinstances", {}, function()
	local insts = getinstances()
	assert(type(insts) == "table" and #insts > 0 and typeof(insts[1]) == "Instance", "getinstances array verification failed")
	assert(#insts > 100, "getinstances returned suspiciously few instances (" .. #insts .. ")")
end)

test("getnilinstances", {}, function()
	local nilInsts = getnilinstances()
	assert(type(nilInsts) == "table" and #nilInsts > 0, "getnilinstances returned empty instance array")
	assert(nilInsts[1].Parent == nil, "Instance inside getnilinstances possesses non-nil parent reference")
	assert(typeof(nilInsts[1]) == "Instance", "getnilinstances returned non-Instance value")
end)

test("isscriptable", {}, function()
	local fire = Instance_new("Fire")
	assert(isscriptable(fire, "size_xml") == false, "size_xml false-positive scriptable status")
	assert(isscriptable(fire, "Size") == true, "Size property marked non-scriptable")
end)

test("setscriptable", {}, {"isscriptable"}, function()
	local fire = Instance_new("Fire")

	setscriptable(fire, "size_xml", true)
	assert(isscriptable(fire, "size_xml") == true, "setscriptable failed to enable size_xml")
	local val1 = fire.size_xml
	assert(type(val1) == "number", "setscriptable size_xml value not accessible after enabling")

	fire.size_xml = 99
	assert(fire.size_xml == 99, "setscriptable failed to allow write to size_xml after enabling")

	setscriptable(fire, "size_xml", false)
	assert(isscriptable(fire, "size_xml") == false, "setscriptable failed to disable size_xml")

	setscriptable(fire, "Brightness", true)
	assert(isscriptable(fire, "Brightness") == true, "setscriptable failed to enable Brightness on Fire")
	setscriptable(fire, "Brightness", false)
	assert(isscriptable(fire, "Brightness") == false, "setscriptable failed to disable Brightness on Fire")
end)

test("setsimulationradius", {}, function()
	assert(pcall(function() setsimulationradius(1000, 1000) end), "setsimulationradius execution failed")
	assert(pcall(function() setsimulationradius(0, 0) end), "setsimulationradius zero radius failed")
	assert(pcall(function() setsimulationradius(999999, 999999) end), "setsimulationradius large radius failed")
end)

test("getrawmetatable", {}, function()
	local mt = { __metatable = "Locked" }
	local obj = setmetatable({}, mt)
	local retrieved = getrawmetatable(obj)
	assert(retrieved == mt, "getrawmetatable failed to bypass locked metatable string")
	assert(type(retrieved) == "table", "getrawmetatable returned non-table")
	assert(retrieved.__metatable == "Locked", "getrawmetatable returned wrong metatable contents")

	local obj2 = setmetatable({}, { __index = function(_, k) return "val_" .. k end })
	local mt2 = getrawmetatable(obj2)
	assert(mt2 ~= getmetatable(obj2) or true, "getrawmetatable should bypass __metatable lock")

	local realMt = getrawmetatable(obj)
	realMt.__index = function(_, k) return "overridden_" .. k end
	assert(obj.newtest == "overridden_newtest", "getrawmetatable: modifying returned table did not affect metatable behavior")
	realMt.__index = function(_, k) return "val_" .. k end

	setreadonly(realMt, true)
	local success = pcall(function() realMt.__index = function() end end)
	setreadonly(realMt, false)
end)

test("getnamecallmethod", {}, {"hookmetamethod", "restorefunction", "getrawmetatable"}, function()
	local methodCaptured
	local ref
	local hookFired = false
	ref = hookmetamethod(game, "__namecall", function(self, ...)
		if not hookFired then
			hookFired = true
			methodCaptured = getnamecallmethod()
		end
		return ref(self, ...)
	end)

	game:GetService("Lighting")
	game:IsA("Part")
	restorefunction(getrawmetatable(game).__namecall)

	assert(hookFired, "getnamecallmethod: hookmetamethod __namecall never fired")
	assert(methodCaptured ~= nil, "getnamecallmethod: failed to capture any method name")
	assert(methodCaptured ~= "GetService" and methodCaptured ~= "IsA", "getnamecallmethod: returned wrong method '" .. tostring(methodCaptured) .. "' (expected last namecall)")

	local ref2
	local lastMethod
	ref2 = hookmetamethod(game, "__namecall", function(self, ...)
		lastMethod = getnamecallmethod()
		return ref2(self, ...)
	end)

	game:GetService("Lighting")
	restorefunction(getrawmetatable(game).__namecall)
	assert(lastMethod == "GetService", "getnamecallmethod: second hook failed (got '" .. tostring(lastMethod) .. "', expected 'GetService')")

	local spoofCheck = false
	local ref3
	ref3 = hookmetamethod(game, "__namecall", function(self, ...)
		local nm = getnamecallmethod()
		if type(nm) ~= "string" then
			spoofCheck = true
		end
		return ref3(self, ...)
	end)

	game:GetService("Lighting")
	game:IsA("BasePart")
	game:FindFirstChild("Test")
	restorefunction(getrawmetatable(game).__namecall)
	assert(spoofCheck == false, "getnamecallmethod: returned non-string value (possible spoof)")
end)

test("isreadonly", {}, function()
	local tbl = {}
	table_freeze(tbl)
	assert(isreadonly(tbl) == true, "isreadonly false-negative on frozen table")
end)

test("setreadonly", {}, {"isreadonly"}, function()
	local tbl = {}
	table_freeze(tbl)
	setreadonly(tbl, false)

	local success = pcall(function() tbl.mutated = true end)
	assert(success and tbl.mutated == true, "setreadonly failed table write-unlock operation")

	setreadonly(tbl, true)
	assert(isreadonly(tbl) == true, "setreadonly failed to re-lock table")

	local success2 = pcall(function() tbl.mutated2 = true end)
	assert(not success2 or tbl.mutated2 == nil, "setreadonly: table should be locked but write succeeded")

	setreadonly(tbl, false)
	tbl.mutated3 = true
	assert(tbl.mutated3 == true, "setreadonly: unlock-lock-unlock cycle failed")
end)

test("setrawmetatable", {}, function()
	local obj = setmetatable({}, { __metatable = "Locked" })
	local newMt = { __index = function() return "new_mt_result" end }
	setrawmetatable(obj, newMt)
	assert(obj.test == "new_mt_result", "setrawmetatable failed metatable reference override")

	local obj2 = setmetatable({}, { __index = function() return "old" end })
	setrawmetatable(obj2, { __index = function() return "replaced" end })
	assert(obj2.anything == "replaced", "setrawmetatable second override failed")

	local obj3 = setmetatable({}, { __index = function() return "before" end })
	setrawmetatable(obj3, {})
	local result = pcall(function() return obj3.anything end)

	local mtCheck = getrawmetatable(obj)
	assert(mtCheck ~= nil, "setrawmetatable: getrawmetatable returned nil after set")

	local obj4 = setmetatable({}, {
		__index = function() return "orig" end,
		__newindex = function() end,
		__metatable = "locked4"
	})
	setrawmetatable(obj4, {
		__index = function() return "new_mt" end,
		__newindex = function() end,
		__metatable = "locked4_new"
	})
	assert(obj4.test == "new_mt", "setrawmetatable failed to replace complex metatable")
end)

test("getthreadidentity", {"getidentity", "getthreadcontext"}, function()
	local id = getthreadidentity()
	assert(type(id) == "number", "getthreadidentity failed returning numerical security context level")
	assert(id >= 0 and id <= 8, "getthreadidentity returned value outside valid range (0-8): " .. tostring(id))

	local id2 = getthreadidentity()
	assert(id == id2, "getthreadidentity returned inconsistent values on back-to-back calls")
end)

test("setthreadidentity", {"setidentity", "setthreadcontext"}, {"getthreadidentity"}, function()
	local orig = getthreadidentity()

	setthreadidentity(3)
	local after3 = getthreadidentity()
	assert(after3 == 3, "setthreadidentity failed to set level to 3 (got " .. tostring(after3) .. ")")

	setthreadidentity(7)
	local after7 = getthreadidentity()
	assert(after7 == 7, "setthreadidentity failed to set level to 7 (got " .. tostring(after7) .. ")")

	setthreadidentity(0)
	local after0 = getthreadidentity()
	assert(after0 == 0, "setthreadidentity failed to set level to 0 (got " .. tostring(after0) .. ")")

	setthreadidentity(orig)
	assert(getthreadidentity() == orig, "setthreadidentity failed to restore original identity")

	setthreadidentity(7)
	local canAccess, err = pcall(function()
		local HttpService = game:GetService("HttpService")
		local success = pcall(function()
			HttpService:GenerateGUID(false)
		end)
		return success
	end)
	setthreadidentity(orig)
end)

test("getgc", {}, function()
	local gc = getgc()
	assert(type(gc) == "table" and #gc > 0, "getgc failed garbage collector heap traversal")

	local marker = { __UNC_GC_MARKER = true }
	table_insert(gc, marker)
	assert(#gc > 0, "getgc: table insert into gc table failed")

	local gc2 = getgc()
	assert(type(gc2) == "table", "getgc second call returned non-table")
end)

test("filtergc", {}, function()
	local markerKey = "UNC_FILTERGC_MARKER_" .. math_random(1000, 9999)
	local targetTable = { [markerKey] = 999 }

	local singleResult = filtergc("table", { Keys = { markerKey } }, true)
	assert(type(singleResult) == "table" and singleResult[markerKey] == 999, "filtergc returnOne=true failed single table lookup")

	local multiResult = filtergc("table", { Keys = { markerKey } }, false)
	assert(type(multiResult) == "table" and #multiResult >= 1, "filtergc returnOne=false failed array table lookup")

	local function targetFn() return markerKey end
	local fnResult = filtergc("function", { Constants = { markerKey } }, true)
	assert(type(fnResult) == "function" and fnResult() == markerKey, "filtergc function lookup failed using Constants filter")

	local function boomsonice2() return "YOU", "PMO", "ME" end
	local mm = filtergc('function', { Name = "boomsonice2", IgnoreExecutor = false })
	local fnd = false; local fnc
	for i,v in pairs(mm) do
		if v == boomsonice2 then
			fnd = true
			fnc = v
		end
	end
	if not fnd or not fnc then
		error("[IgnoreExec] Couldn't find an executor function while 'IgnoreExecutor' is set to false")
	end

	local function aaandsuspicious() local mmm = 0; mmm += 3  local sus = 0; sus += 1 end
	local mm2 = filtergc("function", {Constants = {"Lovre", "PMO", 1, 3}, IgnoreExecutor = false})
	local fnd2 = false
	for i,v in pairs(mm2) do
		if v == aaandsuspicious then
			fnd2 = true
		end
	end

	local up1 = 0
	local up2 = 5
	local up3 = 22
	local function wowcoolsus() up1+=1; up2+=2; up3 += 0 return "Brah" end
	local mm3 = filtergc("function", {Upvalues = {5, 0, 22}, IgnoreExecutor = false})
	local fnd3 = false
	local fnc3
	for i,v in pairs(mm3) do
		if v == wowcoolsus then
			fnd3 = true
			fnc3 = v
		end
	end
	if fnc3 then
		fnc3()
		task.wait(0.005)
		if up1 ~= 1 or up2 ~= 7 or up3 ~= 22 then
			error("[UPVALS] Return function had an incorrect behavior[3]")
		end
	end

	local waw = false
	local newthing = function() waw = true return "Limbo" end
	local hash = getfunctionhash(newthing)
	local mm4 = filtergc("function", {Hash = hash, IgnoreExecutor = false})
	local fnd4 = false; local fnc4
	for i,v in pairs(mm4) do
		if getfunctionhash(v) == hash then
			if v == newthing then
				fnd4 = true
				fnc4 = v
			end
		end
	end
	if fnc4 then
		fnc4()
		task.wait(0.005)
		if waw == false then
			error("[HASH] Returned function had an incorrect behavior[2]")
		end
	end
end)

test("getgenv", {}, function()
	local env = getgenv()
	assert(type(env) == "table", "getgenv did not return a table")
	assert(env ~= _G, "getgenv returned _G directly (spoofed or not injected)")
	local envAddr = tostring(env)
	assert(string_match(envAddr, "table: 0x"), "getgenv returned non-table address (possible spoof)")

	local k1 = "__UNC_GENV_A_" .. math_random(10000, 99999)
	local k2 = "__UNC_GENV_B_" .. math_random(10000, 99999)
	env[k1] = "SHARED_VALUE_A"
	env[k2] = 42

	assert(rawget(env, k1) == "SHARED_VALUE_A", "getgenv failed to store string value")
	assert(rawget(env, k2) == 42, "getgenv failed to store number value")
	assert(rawget(_G, k1) == nil, "getgenv key leaked into _G")
	assert(rawget(_G, k2) == nil, "getgenv second key leaked into _G")
	env[k1] = nil
	env[k2] = nil

	local env2 = getgenv()
	assert(env2 == env, "getgenv returned different table on second call (not shared)")
	env.__UNC_GENV_SHARED_TEST = "shared_check"
	assert(rawget(env2, "__UNC_GENV_SHARED_TEST") == "shared_check", "getgenv environment is not shared properly")
	env.__UNC_GENV_SHARED_TEST = nil

	env.__UNC_GENV_FUNC = function(a, b) return a + b end
	local retrieved = rawget(env, "__UNC_GENV_FUNC")
	assert(type(retrieved) == "function" and retrieved(3, 7) == 10, "getgenv failed to store/retrieve function value")
	env.__UNC_GENV_FUNC = nil

	env.__UNC_GENV_NIL = nil
	assert(rawget(env, "__UNC_GENV_NIL") == nil, "getgenv nil assignment test failed")

	env.__UNC_GENV_BOOL = true
	assert(rawget(env, "__UNC_GENV_BOOL") == true, "getgenv boolean storage failed")
	env.__UNC_GENV_BOOL = false
	assert(rawget(env, "__UNC_GENV_BOOL") == false, "getgenv boolean overwrite failed")
	env.__UNC_GENV_BOOL = nil

	local tbl = { nested = { deep = 999 } }
	env.__UNC_GENV_NESTED = tbl
	assert(rawget(env, "__UNC_GENV_NESTED").nested.deep == 999, "getgenv nested table storage failed")
	env.__UNC_GENV_NESTED = nil
end)

test("getrenv", {}, function()
	local renv = getrenv()
	assert(type(renv) == "table", "getrenv did not return a table")
	assert(renv ~= _G, "Executor _G shares environment address with Roblox environment (_G)")
	assert(renv ~= getgenv(), "getrenv returned getgenv table (should be Roblox env)")
	assert(renv.string ~= nil, "getrenv missing string library")
	assert(renv.table ~= nil, "getrenv missing table library")
	assert(renv.math ~= nil, "getrenv missing math library")
	assert(type(renv.print) == "function", "getrenv missing print function")
end)

test("getreg", {"getregistry"}, function()
	local reg = getreg()
	assert(type(reg) == "table" and next(reg) ~= nil, "getreg failed to return environment registry table")
	assert(#reg > 0, "getreg returned empty registry")
end)

test("getloadedmodules", {}, function()
	local mods = getloadedmodules()
	assert(type(mods) == "table" and #mods > 0, "getloadedmodules array returned empty")
	assert(typeof(mods[1]) == "Instance", "getloadedmodules returned non-Instance value")
	assert(mods[1]:IsA("ModuleScript"), "Object inside getloadedmodules array is not a ModuleScript")
end)

test("getrunningscripts", {}, function()
	local scripts = getrunningscripts()
	assert(type(scripts) == "table" and #scripts > 0, "getrunningscripts array returned empty")
	for i, s in ipairs(scripts) do
		assert(typeof(s) == "Instance", "getrunningscripts[" .. i .. "] returned non-Instance value")
	end
end)

test("getactors", {}, function()
	local actors = getactors()
	assert(type(actors) == "table", "getactors must return a table array")
end)

test("getscriptbytecode", {"dumpstring"}, function()
	local target = findLocalScript() or findModuleScript()
	assert(target ~= nil, "getscriptbytecode: no script with bytecode found")

	local bytecode = getscriptbytecode(target)
	assert(type(bytecode) == "string" and #bytecode > 0, "getscriptbytecode returned empty payload")
	assert(#bytecode > 10, "getscriptbytecode returned suspiciously short payload (" .. #bytecode .. " bytes)")

	local bc2 = getscriptbytecode(target)
	assert(bc2 == bytecode, "getscriptbytecode returned different results for same script")

	local emptyBc = getscriptbytecode(Instance_new("LocalScript"))
	assert(emptyBc == nil or emptyBc == "", "getscriptbytecode should return nil/empty for script without bytecode")
end)

test("getscripthash", {}, function()
	local target = findModuleScript() or findLocalScript()
	assert(target ~= nil, "getscripthash: no script found for testing")

	local hash = getscripthash(target)
	assert(type(hash) == "string" and #hash > 0, "getscripthash hash generation error")

	local hash2 = getscripthash(target)
	assert(hash == hash2, "getscripthash non-deterministic: returned different hashes for same script")

	local differentTarget = findModuleScript()
	if differentTarget and differentTarget ~= target then
		local hash3 = getscripthash(differentTarget)
		assert(type(hash3) == "string" and #hash3 > 0, "getscripthash second script hash failed")
	end
end)

test("getsenv", {}, function()
	local target = findLocalScript()
	if target then
		local env = getsenv(target)
		assert(type(env) == "table", "getsenv returned non-table")
		assert(env.script == target, "getsenv environment script reflection error")
	end

	local module = findModuleScript()
	if module then
		local moduleEnv = getsenv(module)
		assert(type(moduleEnv) == "table", "getsenv returned non-table for ModuleScript")
	end
end)

test("gethwid", {"getdeviceid"}, function()
	local hwid = gethwid()
	assert(type(hwid) == "string" and #hwid > 0, "gethwid failed string generation")
	assert(hwid ~= "", "gethwid returned empty string")

	local hwid2 = gethwid()
	assert(hwid == hwid2, "gethwid returned inconsistent values on back-to-back calls")
end)

test("identifyexecutor", {"getexecutorname"}, function()
	local name, version = identifyexecutor()
	assert(type(name) == "string", "identifyexecutor failed to return string name")
	assert(#name > 0, "identifyexecutor returned empty name string")
	if version ~= nil then
		assert(type(version) == "string", "identifyexecutor version is not a string")
	end
end)

test("isrbxactive", {"isgameactive", "iswindowactive"}, function()
	local active = isrbxactive()
	assert(type(active) == "boolean", "isrbxactive must return boolean status")
end)

test("setclipboard", {"toclipboard"}, function()
	assert(pcall(function() setclipboard("UNC_TEST_CLIPBOARD") end), "setclipboard execution failed")
end)

test("lz4compress", {}, {"lz4decompress"}, function()
	local sample = string_rep("UNC_TEST_COMPRESSION_STREAM_", 10)
	local compressed = lz4compress(sample)
	assert(type(compressed) == "string", "lz4compress payload format error")
	assert(lz4decompress(compressed, #sample) == sample, "lz4decompress stream mismatch after reconstruction")
end)

test("request", {"http.request", "http_request"}, function()
	local response = request({ Url = "https://httpbin.org/get", Method = "GET" })
	assert(type(response) == "table" and response.StatusCode == 200, "request HTTP 200 GET call failed")
end)

test("setfpscap", {}, function()
	assert(pcall(function() setfpscap(60) setfpscap(0) end), "setfpscap failed frame rate cap mutations")
end)

test("Drawing.new", {}, function()
	local square = Drawing.new("Square")
	square.Visible = false
	assert(square.Type == "Square", "Drawing.new Square type mismatch")
	square:Destroy()

	local circle = Drawing.new("Circle")
	circle.Visible = false
	assert(circle.Type == "Circle", "Drawing.new Circle type mismatch")
	circle:Destroy()

	local line = Drawing.new("Line")
	line.Visible = false
	assert(line.Type == "Line", "Drawing.new Line type mismatch")
	line:Destroy()

	local text = Drawing.new("Text")
	text.Visible = false
	assert(text.Type == "Text", "Drawing.new Text type mismatch")
	text:Destroy()
end)

test("isrenderobj", {}, {"Drawing.new"}, function()
	local circle = Drawing.new("Circle")
	assert(isrenderobj(circle) == true, "isrenderobj false-negative on active Drawing object")
	assert(isrenderobj({}) == false, "isrenderobj false-positive on raw Lua table")
	assert(isrenderobj("string") == false, "isrenderobj false-positive on string")
	assert(isrenderobj(123) == false, "isrenderobj false-positive on number")
	circle:Destroy()
end)

test("WebSocket.connect", {}, function()
	local ws = WebSocket.connect("ws://echo.websocket.events")
	assert(type(ws) == "table" or type(ws) == "userdata", "WebSocket object format mismatch")
	assert(type(ws.Send) == "function" and type(ws.Close) == "function", "WebSocket interface missing standard functions")
	ws:Close()
end)
