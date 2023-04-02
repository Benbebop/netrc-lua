table.remove(args, 1)

local mode = 0

if args[1]:lower() == "get" then
	mode = 0
elseif args[1]:lower() == "set" then
	mode = 1
elseif args[1]:lower() == "lst" then
	mode = 2
elseif args[1]:lower() == "del" then
	mode = 3
elseif args[1]:lower() == "help" then
	process.stdout:write([[Usage: netrc [GET/SET/DEL] [OPTIONS]
	
Options:
	-c clears the netrc file
	--machine [name] specifies a machine
	--login [name] sets the login to write
	--password [name] sets the password to write
	--account [name] sets the account password to write]])
	return
else
	process.stdout:write("invalid command: " .. args[1])
	return
end

table.remove(args, 1)

local options = {}

do -- PARSE OPTIONS --
	
	local command
	
	for i,v in ipairs(args) do
		if command then
			options[command] = v
			command = nil
		elseif v:sub(1,2) == "--" then
			command = v:sub(3,-1)
		elseif v:sub(1,1) == "-" then
			for tag in v:gmatch("[^%-]") do
				options[tag] = true
			end
		end
	end
	
end

local logins, default = {}

if not options.c then -- READ FILE CONTENT
	function parse(l)
		return l:match("machine%s*([^%s]+)"), {login = l:match("login%s*([^%s]+)"),
				password = l:match("password%s*([^%s]+)"),
				account = l:match("account%s*([^%s]+)"),
				macdef = l:match("macdef%s*([^%s]+)")}
	end

	for l in io.lines(".netrc") do
		local d = l:match("^%s*default")
		if d then
			_, default = parse(l)
		else
			local index, data = parse(l)
			logins[index] = data
		end
	end
end

local uv = require("uv")

local login
if options.machine then
	logins[options.machine] = logins[options.machine] or {}
	login = logins[options.machine]
else
	default = default or {}
	login = default
end

if mode > 0 then
	
	if mode == 1 then
		local charset = {n = 0} -- init charset
		for char in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"):gmatch(".") do table.insert(charset, char) charset.n = charset.n + 1 end
		
		login.login = options.login or login.login
		if options.password then
			login.password = options.password:gsub("%%auto(%b[])", function(args)
				local pass = {}
				for i=1,32 do
					math.randomseed(string.unpack("I4", uv.random(4)))
					pass[i] = charset[math.random(charset.n)]
				end
				return table.concat(pass)
			end)
		end
	elseif mode == 3 then
		logins[options.machine] = nil
	end

	local file = io.open(".netrc", "wb")

	for machine,login in pairs(logins) do
		local str = {"machine", machine}
		for i,v in pairs(login) do
			table.insert(str, i)
			table.insert(str, v)
		end
		file:write(table.concat(str, " "), "\n")
	end

	if default then
		local str = {"default"}
		for i,v in pairs(default) do
			table.insert(str, i)
			table.insert(str, v)
		end
		file:write(table.concat(str, " "))
	end
	
end

if mode < 2 then
	local str = {}
	for i,v in pairs(login) do
		table.insert(str, i)
		table.insert(str, ": ")
		table.insert(str, v)
		table.insert(str, "\n")
	end
	process.stdout:write(table.concat(str))
elseif mode == 2 then
	local str = {}
	for i,v in pairs(logins) do
		table.insert(str, i)
	end
	process.stdout:write(table.concat(str, "\n"))
end

os.exit()