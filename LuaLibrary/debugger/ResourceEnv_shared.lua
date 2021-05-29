local copy
copy = function(t)
	if type(t) == "table" then
		local o = {}
		for k, v in pairs(t) do
			o[k] = copy(v)
		end
		return o
	else
		return t
	end
end

CurrentEnv = _G

ResourceEnv = Class()

function ResourceEnv:constructor(resource, debugger)
	self._debugger = debugger
	self._resource = resource
	self._resourceName = resource:getName()
	local resourceRoot = resource:getRootElement()
	self._resourceRoot = resourceRoot
	local eventHandlers = {}
	self._eventHandlers = eventHandlers
	local timers = {}
	self._timers = timers
	local files = {}
	self._files = files
	local commands = {}
	self._commands = commands
	local xml = {}
	self._xml = xml

	local env = copy(DefaultEnv)
	env._G = env
	env.resource = resource
	env.resourceRoot = resourceRoot
	env.debug.debugger = debugger

	for _, className in pairs( UsedMetateble ) do
		env[className] = setmetatable( env[className], getmetatable( _G[className] ) )
	end

	env.loadstring = function( content, blockName )
		local resource = self._resource
		local resourceName, filePath = filePath:match( ":(.-)/(.+)" )
		if resourceName then
			resource = Resource.getFromName( resourceName ) or resource
		end
		return loadstring( content, self._debugger:genDebugLink( self._resource, filePath or blockName ) )
	end


	local dynElementRoot = resource:getDynamicElementRoot()
	local function addCreateElementFunction( owner, functionName )
		local _fun = owner[functionName]
		owner[functionName] = function( ... )
			local result = _fun( ... )
			if result then
				result:setParent( dynElementRoot )
				return result
			else
				error("Can not create object", 2)
			end
		end
	end

	addCreateElementFunction( env, "createBlip" )
	addCreateElementFunction( env.Blip, "create" )
	addCreateElementFunction( env, "createBlipAttachedTo" )
	addCreateElementFunction( env.Blip, "createAttachedTo" )

	addCreateElementFunction( env, "createColCircle" )
	addCreateElementFunction( env, "createColCuboid" )
	addCreateElementFunction( env, "createColPolygon" )
	addCreateElementFunction( env, "createColRectangle" )
	addCreateElementFunction( env, "createColSphere" )
	addCreateElementFunction( env, "createColTube" )

	addCreateElementFunction( env.ColShape, "Circle" )
	addCreateElementFunction( env.ColShape, "Cuboid" )
	addCreateElementFunction( env.ColShape, "Polygon" )
	addCreateElementFunction( env.ColShape, "Rectangle" )
	addCreateElementFunction( env.ColShape, "Sphere" )
	addCreateElementFunction( env.ColShape, "Tube" )

	addCreateElementFunction( env, "createElement" )
	addCreateElementFunction( env.Element, "create" )
	addCreateElementFunction( env, "cloneElement" )
	addCreateElementFunction( env.Element, "clone" )

	addCreateElementFunction( env, "createMarker" )
	addCreateElementFunction( env.Marker, "create" )

	addCreateElementFunction( env, "createObject" )
	addCreateElementFunction( env.Object, "create" )

	addCreateElementFunction( env, "createPed" )
	addCreateElementFunction( env.Ped, "create" )

	addCreateElementFunction( env, "createPickup" )
	addCreateElementFunction( env.Pickup, "create" )

	addCreateElementFunction( env, "createRadarArea" )
	addCreateElementFunction( env.RadarArea, "create" )

	addCreateElementFunction( env, "createVehicle" )
	addCreateElementFunction( env.Vehicle, "create" )

	addCreateElementFunction( env, "createWater" )
	addCreateElementFunction( env.Water, "create" )

	if triggerClientEvent then
		addCreateElementFunction( env, "dbConnect" )
		addCreateElementFunction( env.Connection, "create" )

		addCreateElementFunction( env, "createTeam" )
		addCreateElementFunction( env.Team, "create" )
	else

	end

	local backup = {}
	local function tempValues( values )
		for _, key in pairs( values ) do
			backup[key] = env[key]
			env[key] = _G[key]
		end
	end

	local function restoreBackup()
		for key in pairs( backup ) do
			env[key] = backup[key]
		end
	end

	-- Commands

	env.addCommandHandler = function(cmd, __commandFunction, ... )
		commands[cmd] = true
		addCommandHandler( cmd, function( ... )
			CurrentEnv = env
			local arg = { ... }
			self._debugger:debugRun( function() __timerFunction( unpack( arg ) ) end ) 
			CurrentEnv = _G
		end, ... )
	end

	-- Events

	self._destroyElementHandler = function()
		eventHandlers[source] = nil
	end 

	addEventHandler( triggerClientEvent and "onElementDestroy" or "onClientElementDestroy", root, self._destroyElementHandler )

	env.addEventHandler = function( eventName, element, __eventFunction, ... )
		if type( __eventFunction ) == 'function' then
			local elementHandlers = eventHandlers[element]
			if not elementHandlers then
				elementHandlers = {}
				eventHandlers[element] = elementHandlers
			end
			local events = elementHandlers[eventName]
			if not events then
				events = {}
				elementHandlers[eventName] = events
			end

			local fun
			fun = events[ __eventFunction ] or function( ... )
				tempValues{
					"source",
					"this",
					"resourceRoot",
					"sourceResource",
					"sourceResourceRoot",
					"eventName",
				}
				local arg = { ... }

				if not self.resource:getState() == 'running' then
					removeEventHandler( eventName, this, fun )
					return
				end

				CurrentEnv = env
				self._debugger:debugRun( function() __eventFunction( unpack( arg ) ) end ) 
				CurrentEnv = _G
				restoreBackup()
			end;

			local resul = addEventHandler( eventName, element, fun, ... )
			if resul then
				events[ __eventFunction ] = fun
			end
			return resul
		else
			outputDebugString( 'Expected function at argument 3 got ' .. type( _f ), 2 )
			return false
		end
	end;

	env.removeEventHandler = function( eventName, element, _f )
		local elementHandlers = eventHandlers[element]
		if not elementHandlers then
			elementHandlers = {}
			eventHandlers[element] = elementHandlers
		end
		local events = elementHandlers[eventName]
		if not events then
			events = {}
			elementHandlers[eventName] = events
		end

		if _f ~= nil then
			return removeEventHandler( eventName, element, events[ _f ] )
		else
			outputDebugString( 'Expected function at argument 3 got ' .. type( _f ) )
			return false
		end
	end;

	-- Timers

	env.Timer = setmetatable( env.Timer, getmetatable( Timer ) )

	env.Timer.create = function( __timerFunction, time, count, ... )
		if type( __timerFunction ) == 'function' then
			local arg = { ... }
			local timer

			timer = Timer( function()
				tempValues{
					"sourceTimer",
				}
				CurrentEnv = env
				self._debugger:debugRun( function() __timerFunction( unpack( arg ) ) end ) 
				CurrentEnv = _G
				restoreBackup()

				if not timer:isValid() or select( 2, timer:getDetails() ) == 1 then
					timers[timer] = nil
				end
			end, time, count )

			timers[timer] = __timerFunction
			return timer
		end
	end;

	env.Timer.destroy = function( timer )
		timers[timer] = nil
		timer:destroy()
	end;

	local function hook()
		--debug.sethook(function(...) debugger:_hookFunction(...) end, "crl")
		--debug.sethook(function(...) iprint( ... ) end, "crl")
	end

	setfenv(hook, env)
	hook()
	-- End

	self._env = env
end

function ResourceEnv:destructor()
	self._resourceRoot:destroy()

	for cmd in pairs( self._commands ) do
		removeCommandHandler( cmd )
	end

	for element, events in pairs( self._eventHandlers ) do
		if isElement( element ) then
			for eventName, functs in pairs( events ) do
				for original, hooked in pairs( functs ) do
					removeEventHandler( eventName, element, hooked )
				end
			end
		end
	end

	removeEventHandler( triggerClientEvent and "onElementDestroy" or "onClientElementDestroy", root, self._destroyElementHandler )

	for timer in pairs( self._timers ) do
		if isTimer( timer ) then
			timer:destroy()
		end
	end
end

function ResourceEnv:loadFile( filePath )
	local fullPath = (":%s/%s"):format(self._resourceName, filePath )
	local file = File.open( fullPath )
	local content = file:read( file:getSize() )
	file:close()

	local f, errorMsg = loadstring( content, self._debugger:genDebugLink( self._resource, filePath ) )
	if f then
		setfenv( f, self._env )
		CurrentEnv = self._env
		self._debugger:debugRun( f )
		CurrentEnv = _G
	else
		errorMsg = self._debugger:fixPathInString( errorMsg )
		local file, line = errorMsg:match( "^(.+):(%d+):.+" )
		self._debugger:outputDebugString("Syntax error:" .. errorMsg, 1, file, tonumber( line ) )
	end
end

function ResourceEnv:getEnvTable()
	return self._env
end
