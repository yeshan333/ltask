local boot = require "ltask.bootstrap"
local ltask = require "ltask"

local SERVICE_ROOT <const> = 1
local MESSSAGE_SYSTEM <const> = 0

local config = {}

local function init_config()
	local config_file = assert(arg[1])
	assert(loadfile(config_file, "t", config))()
end

local function searchpath(name)
	return assert(package.searchpath(name, config.service_path))
end

local function new_service(label, id)
	local sid = boot.new_service(label, "@" .. searchpath "service", id)
	assert(sid == id)
	return sid
end

local function bootstrap()
	new_service("root", SERVICE_ROOT)
	boot.init_root(SERVICE_ROOT)
	-- send init message to root service
	local init_msg, sz = ltask.pack("init", {
		path = config.lua_path,
		cpath = config.lua_cpath,
		filename = searchpath "root",
		args = {config}
	})
	-- self bootstrap
	boot.post_message {
		from = SERVICE_ROOT,
		to = SERVICE_ROOT,
		session = 0,	-- 0 for root init
		type = MESSSAGE_SYSTEM,
		message = init_msg,
		size = sz,
	}
end

local function exclusive_thread(label, id)
	local sid = new_service(label, id)
	boot.new_thread(sid)
end

function print(...)
	boot.pushlog(ltask.pack(...))
end

init_config()
boot.init(config)
boot.init_timer()

for i, t in ipairs(config.exclusive) do
	local label = type(t) == "table" and t[1] or t
	local id = i + 1
	exclusive_thread(label, id)
end

bootstrap()	-- launch root

print "ltask Start"
boot.run()
