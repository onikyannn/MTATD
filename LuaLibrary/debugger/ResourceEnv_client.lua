
ResourceEnv.stopEventName = "onClientResourceStop"
ResourceEnv.startEventName = "onClientResourceStart"

function ResourceEnv:_platformInit()
	local env = self._env
	self:_addCreateElementFunction( env, "playSFX", env.Sound )
	self:_addCreateElementFunction( env, "playSound", env.Sound )
	self:_addCreateElementFunction( env.Sound, "create", env.Sound )

	self:_addCreateElementFunction( env, "playSFX3D", env.Sound3D )
	self:_addCreateElementFunction( env, "playSound3D", env.Sound3D )
	self:_addCreateElementFunction( env.Sound3D, "create", env.Sound3D )

	self:initBindKeysFunctions()
end

function ResourceEnv:_destroyPlatform()
	self:cleanBindKeysFunctions()
end

function ResourceEnv:initBindKeysFunctions()
	self._keyBinds = {}
	local function getBindData( key, state, fun )
		for id, data in pairs( self._keyBinds ) do
			if data[1] == key and data[2] == state and data[3] == fun then
				return id, data
			end
		end
	end

	self._env.bindKey = function( key, state, func )
		if type( func ) ~= "function" then
			error( "Bad argument #3 in bindKey", 2 )
		end
		if getBindData( key, state, fun ) then
			error( "Key already bound", 2 )
		end
		local __fun = function( ... )
			local arg = { ... }
			CurrentEnv = self._env
			self._debugger:debugRun( function() func( self:_unpackFixed( arg ) ) end ) 
			CurrentEnv = _G
		end

		table.insert( self._keyBinds, { key, state, func, __fun } )

		bindKey( key, state, __fun )
	end

	self._env.unbindKey = function( key, state, fun )
		for id, data in pairs( self._keyBinds ) do
			if data[1] == key
				and (state == nil or data[2] == state)
				and (fun == nil or data[3] == fun)
			then
				unbindKey( data[1], data[2], data[4] )
				self._keyBinds[id] = nil
			end
		end
	end
end

function ResourceEnv:cleanBindKeysFunctions()
	for id, data in pairs( self._keyBinds ) do
		unbindKey( data[1], data[2], data[4] )
	end
end