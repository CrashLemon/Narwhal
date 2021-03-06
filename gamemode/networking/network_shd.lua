/*---------------------------------------------------------

	Developer's Notes:
	
	This file has our shared networking tables and entity methods.
	
	Note: This may need some cleaning up.

---------------------------------------------------------*/

// Declare frequently used globals as locals to enhance performance
local string = string
local table = table
local math = math
local umsg = umsg
local type = type
local error = error
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tobool = tobool
local FindMetaTable = FindMetaTable
local ValidEntity = ValidEntity
local ErrorNoHalt = ErrorNoHalt
local Entity = Entity
local NullEntity = NullEntity
local SERVER = SERVER
local CLIENT = CLIENT

NARWHAL.__NetworkData = {}
NARWHAL.__NetworkTypeID = {}
NARWHAL.__NetworkTypeID2 = {}
NARWHAL.__NetworkCache = {} -- Set up the shared Network Cache table
NARWHAL.__NetworkCache.Booleans = {} -- Stores NWBools
NARWHAL.__NetworkCache.Strings = {} -- Stores NWStrings
NARWHAL.__NetworkCache.Integers = {} -- Stores NWInts
NARWHAL.__NetworkCache.Floats = {} -- Stores NWFloats
NARWHAL.__NetworkCache.Entities = {} -- Stores NWEntities
NARWHAL.__NetworkCache.Colors = {} -- Stores NWColors
NARWHAL.__NetworkCache.Vectors = {} -- Stores NWVectors
NARWHAL.__NetworkCache.Angles = {} -- Stores NWAngles
NARWHAL.__NetworkCache.Effects = {} -- Stores NWEffects
NARWHAL.__NetworkCache.Tables = {} -- Stores NWTables
NARWHAL.__NetworkCache.Vars = {} -- Stores NWVars

// This is a function for getting the network configurations.
function GM:GetNetworkData()
	return NARWHAL.__NetworkData
end

// This can be used to add custom datatypes. This could be useful on a per-gamemode basis. It would allow developers to design their own ways of sending data.
// Every time we send data, it follows a general pattern: Check to see if the data is valid within the context of the variable, Encode it somehow, Send that encoded data via usermessages, and then Retrieving that data on the client.
function GM:AddValidNetworkType( sType, sRef, sStore, funcCheck, funcSend, funcRead )
	local tData = {}
	tData["Ref"] = sRef
	tData["Storage"] = sStore
	if SERVER then
		tData["Func_Check"] = funcCheck
		tData["Func_Send"] = funcSend
	elseif CLIENT then
		tData["Func_Read"] = funcRead
	end
	NARWHAL.__NetworkData[sType] = tData
	NARWHAL.__NetworkTypeID[#NARWHAL.__NetworkTypeID + 1] = sType
	NARWHAL.__NetworkTypeID2[sType] = #NARWHAL.__NetworkTypeID
	if !NARWHAL.__NetworkCache[sStore] then
		NARWHAL.__NetworkCache[sStore] = {}
	end
end

// Here's our internal configuration loading. Devs can load their own in the other function.
local function LoadInternalNetworkConfigurations()
	
	// BOOLEANS
	GAMEMODE:AddValidNetworkType( "boolean", "Bool", "Booleans",
		function( var ) return tobool( var ) end,
		function( var ) umsg.Bool( var ) end,
		function( um ) return um:ReadBool() end
	)

	// STRINGS
	GAMEMODE:AddValidNetworkType( "string", "String", "Strings",
		function( var )
			local vType = type( var )
			if vType != "string" and vType != "number" then
				error( "Bad argument #2 (String expected, got "..vType..")\n", 2 )
			end
			return tostring( var )
		end,
		function( var ) umsg.String( var ) end,
		function( um ) return um:ReadString() end
	)

	// INTEGERS
	GAMEMODE:AddValidNetworkType( "integer", "Int", "Integers",
		function( var )
			if !tonumber( var ) then
				error( "Bad argument #2 (Number expected, got "..type( var )..")\n", 2 )
			end
			return tonumber( math.floor( var ) )
		end,
		function( var )
			if ( var >= -32768 and var <= 32767 ) then
				umsg.Bool( true )
				umsg.Short( var )
			elseif ( var >= -2147483648 and var <= 2147483647 ) then
				umsg.Bool( false )
				umsg.Long( var )
			else
				ErrorNoHalt( "Attempted to send a number that exceeds usermessage Long limits!\n" )
			end
		end,
		function( um )
			local short = um:ReadBool()
			if short then
				return um:ReadShort()
			else
				return um:ReadLong()
			end
		end
	)

	// FLOATS
	GAMEMODE:AddValidNetworkType( "float", "Float", "Floats",
		function( var )
			if !tonumber( var ) then
				error( "Bad argument #2 (Number expected, got "..type( var )..")\n", 2 )
			end
			return tonumber( var )
		end,
		function( var ) umsg.Float( var ) end,
		function( um ) return um:ReadFloat() end
	)

	// ENTITIES	
	GAMEMODE:AddValidNetworkType( "entity", "Entity", "Entities",
		function( var )
			local vType = type( var )
			if vType != "Entity" and vType != "Player" then
				error( "Bad argument #2 (Player or Entity expected, got "..vType..")\n", 2 )
			end
			return var
		end,
		function( var )
			local vType = type( var )
			if vType == "Entity" then
				umsg.Char(0)
				umsg.Short(var:EntIndex())
			elseif vType == "Player" then
				umsg.Char(1)
				umsg.Short(var:UserID()-32770)
			end
		end,
		function( um )
			local entType = um:ReadChar()
			local entID = 0

			if entType == 0 then
				return Entity( um:ReadShort() )
			elseif entType == 1 then
				local id = um:ReadShort() + 32770
				for _, ply in pairs( player.GetAll() ) do
					if ValidEntity( ply ) then
						if ply:UserID() == id then
							return ply
						end
					end
				end
			else
				error("Fatal error receiving entity(invalid type)")
			end
			return NullEntity()
		end
	)

	// COLORS
	GAMEMODE:AddValidNetworkType( "color", "Color", "Colors",
		function( var )
			if type( var ) != "table" then
				error( "Bad argument #2 (Color table expected, got "..type( var )..")\n", 2 )
			end
			if type( var.r + var.g + var.b ) != "number" then
				error( "Bad argument #2 (Table '"..tostring( var ).."' is not a valid Color)\n", 2 )
			end
			var.r = math.Clamp( var.r, 0, 255 )
			var.g = math.Clamp( var.g, 0, 255 )
			var.b = math.Clamp( var.b, 0, 255 )
			var.a = var.a or 255
			var.a = math.Clamp( var.a, 0, 255 )
			return var
		end,
		function( var )
			umsg.Char( color.r - 128 )
			umsg.Char( color.g - 128 )
			umsg.Char( color.b - 128 )
			umsg.Char( color.a - 128 )
		end,
		function( um )
			return { r = um:ReadChar() + 128, g = um:ReadChar() + 128, b = um:ReadChar() + 128, a = um:ReadChar() + 128 }
		end
	)

	// VECTORS
	GAMEMODE:AddValidNetworkType( "vector", "Vector", "Vectors",
		function( var )
			if type( var ) != "vector" then
				error( "Bad argument #2 (Vector expected, got "..type( var )..")\n", 2 )
			end
			return var
		end,
		function( var ) umsg.Vector( var ) end,
		function( um ) return um:ReadVector() end
	)

	// ANGLES
	GAMEMODE:AddValidNetworkType( "angle", "Angle", "Angles",
		function( var )
			if type( var ) != "angle" then
				error( "Bad argument #2 (Angle expected, got "..type( var )..")\n", 2 )
			end
			return var
		end,
		function( var ) umsg.Angle( var ) end,
		function( um ) return um:ReadAngle() end
	)

	// TABLES
	GAMEMODE:AddValidNetworkType( "table", "Table", "Tables",
		function( var )
			if type( var ) != "table" then
				error( "Bad argument #2 (Table expected, got "..type( var )..")\n", 2 )
			end
			return glon.encode( var )
		end,
		function( var ) umsg.String( var ) end,
		function( um ) return glon.decode( um:ReadString() ) end
	)

	// EFFECTS
	GAMEMODE:AddValidNetworkType( "ceffectdata", "Effect", "Effects",
		function( var )
			if type( var ) != "CEffectData" then
				error( "Bad argument #2 (CEffectData expected, got "..type( var )..")\n", 2 )
			end
			return glon.encode( var )
		end,
		function( var ) umsg.String( var ) end,
		function( um ) return glon.decode( um:ReadString() ) end
	)
	
	if GAMEMODE.LoadNetworkConfigurations then
		GAMEMODE:LoadNetworkConfigurations() -- Call the one for developers.
	end
	
	local ENTITY = FindMetaTable( "Entity" ) -- Here is the entity metatable. This lets us add methods to all entities.
	if !ENTITY then return end
	
	// A handy function for getting network ID's. This is no longer networkable
	local NextID = 0
	ENTITY.GetNetworkID = function( self )
		if self:IsPlayer() then
			return "ply"..self:UserID()
		elseif self.NetworkID then
			return "ent"..self.NetworkID
		else
			NextID = NextID + 1
			return "ent"..NextID
		end
	end
	
	// Now we loop through our network data and generate our player/entity methods for networking.
	for k, v in pairs( NARWHAL.__NetworkData ) do
		ENTITY["SendNetworked"..v.Ref] = function( self, Name, Var, Filter )
			local entType = type( self )
			if !SERVER then Filter = nil end
			if !self or !ValidEntity( self ) or ( entType:lower() != "entity" and entType:lower() != "player" ) then
				error( "Entity.SendNetworked"..v.Ref.." Failed: Entity or Player expected, got "..entType.."\n", 2 )
			elseif !Name then
				error( entType..".SendNetworked"..v.Ref.." Failed: Bad argument #1 (String or Number expected, got "..type( Name )..")\n", 2 )
			elseif Name:find('[\\/:%*%?"<>|]') or Name:find(" ") then
				error( entType..".SendNetworked"..v.Ref.." Failed: Bad argument #1 (Variable Names may only contain alphanumeric characters and underscores!)\n", 2 )
			elseif !Var then
				error( entType..".SendNetworked"..v.Ref.." Failed: Bad argument #2 (Attempted to use nil variable!)\n", 2 )
			elseif Filter and type( Filter ) != "player" and type( Filter ) != "table" then
				error( entType..".FetchNetworked"..v.Ref.." Failed: Bad argument #3 (Player or Table of Players expected, got "..type( Filter )..")\n", 2 )
			elseif Filter and type( Filter ) == "table" then
				for k, v in pairs( Filter ) do
					if !ValidEntity( v ) or type( v ) != "player" then
						table.remove( Filter, k )
						ErrorNoHalt( entType..".FetchNetworked"..v.Ref..": Problem with argument #3 (Filter Table contains invalid member "..tostring( v )..")\n" )
					end
				end
				if !IsTableOfEntitiesValid( Filter ) then
					error( entType..".FetchNetworked"..v.Ref.." Failed: Bad argument #3 (Filter Table does not contain any valid players!)\n", 2 )
				end
			end
			GAMEMODE:SendNetworkedVariable( self, Name, Var, k, Filter )
		end
		ENTITY["FetchNetworked"..v.Ref] = function( self, Name, Var, Filter )
			local entType = type( self )
			if !SERVER then Filter = nil end
			if !self or !ValidEntity( self ) or ( entType:lower() != "entity" and entType:lower() != "player" ) then
				error( "Entity.FetchNetworked"..v.Ref.." Failed: Entity or Player expected, got "..entType.."\n", 2 )
			elseif !Name then
				error( entType..".FetchNetworked"..v.Ref.." Failed: Bad argument #1 (String or Number expected, got "..type( Name )..")\n", 2 )
			elseif Name:find('[\\/:%*%?"<>|]') or Name:find(" ") then
				error( entType..".FetchNetworked"..v.Ref.." Failed: Bad argument #1 (Variable Names may only contain alphanumeric characters and underscores!)\n", 2 )
			elseif Filter and type( Filter ) != "player" and type( Filter ) != "table" then
				error( entType..".FetchNetworked"..v.Ref.." Failed: Bad argument #3 (Player or Table of Players expected, got "..type( Filter )..")\n", 2 )
			elseif Filter and type( Filter ) == "table" then
				for k, v in pairs( Filter ) do
					if !ValidEntity( v ) or type( v ) != "player" then
						table.remove( Filter, k )
						ErrorNoHalt( entType..".FetchNetworked"..v.Ref..": Problem with argument #3 (Filter Table contains invalid member "..tostring( v )..")\n" )
					end
				end
				if !IsTableOfEntitiesValid( Filter ) then
					error( entType..".FetchNetworked"..v.Ref.." Failed: Bad argument #3 (Filter Table does not contain any valid players!)\n", 2 )
				end
			end
			return GAMEMODE:FetchNetworkedVariable( self, Name, Var, k, Filter )
		end
		ENTITY["SendNW"..v.Ref] = ENTITY["SendNetworked"..v.Ref]
		ENTITY["FetchNW"..v.Ref] = ENTITY["FetchNetworked"..v.Ref]
	end
	
end
hook.Add( "Initialize", "NARWHAL_LoadNetworkConfigurations", LoadInternalNetworkConfigurations )


