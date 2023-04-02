local uv, http, spawn, url = require("uv"), require("coro-http"), require("coro-spawn"), require("url")

local res_headers = {
   {"Content-Type", "text/markdown"}, -- Type of the response's payload (res_payload)
   {"Connection", "close"}, -- Whether to keep the connection alive, or close it
   code = 200,
   reason = "Success",
}
local err_headers = {
   code = 500,
   reason = "Internal Server Error",
}

local methods = {
	get = "get",
	set = "set",
	lst = "lst",
	list = "lst",
	del = "del",
	delete = "del"
}

local options = {
	machine = "machine",
	login = "login",
	password = "password"
}

local mainFile = args[1]:gsub("[^/\\]+$", "main.lua")

function main(res, body)
	if not res.path then return {code = 404}, "Not Found" end
	
	local path = url.parse(res.path, true)
	
	if (path.query or {}).pass ~= "ThugShakerCollection" then return {code = 401}, "Unauthorized" end
	path.query.pass = nil
	
	local pathParts = {path.pathname:match("^.-([^/]+).-(%a+)")}
	
	if pathParts[1]:lower() ~= "netrc" then return {code = 404}, "Not Found" end
	local method = methods[pathParts[2]:lower()]
	if not method then return {code = 404}, "Not Found" end
	
	local args = {mainFile, method}
	
	for i,v in pairs(path.query) do
		local option = options[i]
		if option then
			table.insert(args, "--" .. option)
			table.insert(args, v)
		end
	end
	
	local proc = spawn("luvit", {stdio = {true, true, true}, args = args})
	
	proc:waitExit()
	
	return {code = 200}, proc.stdout:read()
end

http.createServer("0.0.0.0", 22642, function(...)
	local returns = {pcall(main, ...)}
	
	if not (returns[1] and returns[2]) then
		return err_headers, returns[2] or err_headers.reason
	else
		table.remove(returns, 1)
		return unpack(returns)
	end
	
	return headers, table.concat(res_body)
end)
