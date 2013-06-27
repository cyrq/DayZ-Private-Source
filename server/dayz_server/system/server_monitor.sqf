// DayZ Server Controlcenter Server Project

// Incude DayZCC specific funtions ---------------------------------------------------------------------------------------
#include "\@dayzcc\addons\dayz_server_config.hpp"

// Initialize funtions --------------------------------------------------------------------------------------------------

#include "\z\addons\dayz_server\compile\server_toggle_debug.hpp"
dayz_versionNo = 		getText(configFile >> "CfgMods" >> "DayZ" >> "version");
dayz_hiveVersionNo = 	getNumber(configFile >> "CfgMods" >> "DayZ" >> "hiveVersion");
dayz_serverVersionNo	= "5.9.2.3";
_script = getText(missionConfigFile >> "onPauseScript");

if ((count playableUnits == 0) and !isDedicated) then {
	isSinglePlayer = true;
};

waitUntil{initialized};

//All functions are now defind so let's start the server ---------------------------------------------------------------

diag_log format ["SERVER STARTING: VERSION: CC %1", dayz_serverVersionNo];
diag_log ("SERVER: WORLD: " + str(worldName));
diag_log ("SERVER: INSTANCE: " + str(dayz_instance));
diag_log ("HIVE: Starting ...");

// Set the time --------------------------------------------------------------------------------------------------------

	_key = "CHILD:307:";
	_result = _key call server_hiveReadWrite;
	_outcome = _result select 0;
	if(_outcome == "PASS") then {
		_date = _result select 1;
		if(isDedicated) then {
			setDate _date;
			dayzSetDate = _date;
			publicVariable "dayzSetDate";
		};
		diag_log ("HIVE: Local Time set to " + str(_date));
	};

// Fetch and spawn buildings ------------------------------------------------------------------------------------------

_key = format["CHILD:999:select b.class_name, ib.worldspace from instance_building ib join building b on ib.building_id = b.id where ib.instance_id = ?:[%1]:", dayZ_instance];
_data = "HiveEXT" callExtension _key;

diag_log("SERVER: Fetching buildings...");
_result = call compile format ["%1", _data];
_status = _result select 0;

_bldList = [];
_bldCount = 0;
if (_status == "CustomStreamStart") then {
	_val = _result select 1;
	for "_i" from 1 to _val do {
		_data = "HiveEXT" callExtension _key;
		_result = call compile format ["%1",_data];

		_pos = call compile (_result select 1);
		_dir = _pos select 0;
		_pos = _pos select 1;

		_building = createVehicle [_result select 0, _pos, [], 0, "CAN_COLLIDE"];
		_building setDir _dir;
		_bldCount = _bldCount + 1;
	};
	diag_log ("SERVER: Spawned " + str(_bldCount) + " buildings!");
};

// Hive Maintenance ---------------------------------------------------------------------------------------------------
waituntil{isNil "sm_done"};

#include "\z\addons\dayz_server\compile\fa_hiveMaintenance.hpp"

if (isServer and isNil "sm_done") then {
	private["_i","_hiveResponse","_key","_objectArray","_objectCount"];
	
	for "_i" from 1 to 5 do {
		diag_log "HIVE: trying to get objects";
		_key = format["CHILD:302:%1:", dayZ_instance];
		_hiveResponse = _key call server_hiveReadWrite;  
		if ((((isnil "_hiveResponse") || {(typeName _hiveResponse != "ARRAY")}) || {((typeName (_hiveResponse select 1)) != "SCALAR")}) || {(_hiveResponse select 1 > 2000)}) then {
			diag_log ("HIVE: connection problem... HiveExt response:"+str(_hiveResponse));
			_hiveResponse = ["",0];
		} 
		else {
			diag_log ("HIVE: found "+str(_hiveResponse select 1)+" objects" );
			_i = 99;
		};
	};
	
	_objectArray = [];
	if ((_hiveResponse select 0) == "ObjectStreamStart") then {
		_objectCount = _hiveResponse select 1;
		diag_log ("HIVE: Commence Object Streaming...");
		for "_i" from 1 to _objectCount do { 
			_hiveResponse = _key call server_hiveReadWrite;
			_objectArray set [_i - 1, _hiveResponse];
		};
		diag_log ("HIVE: got " + str(count _objectArray) + " objects");
#ifdef EMPTY_TENTS_CHECK
		[_objectArray, EMPTY_TENTS_GLOBAL_LIMIT, EMPTY_TENTS_USER_LIMIT] call fa_removeExtraTents;
#endif
		[_objectArray] call fa_checkVehicles;
	};

	{
		private["_action","_ObjectID","_class","_CharacterID","_worldspace","_inventory", "_hitpoints","_fuel","_damage","_entity","_dir","_point","_res",  "_rawData","_class","_worldspace","_uid", "_selection", "_dam", "_booleans", "_point", "_wantExplosiveParts"];

		_action = _x select 0;
		_ObjectID = _x select 1;
		_class =	if ((typeName (_x select 2)) == "STRING") then { _x select 2 } else { "Old_bike_TK_CIV_EP1" };
		_CharacterID = _x select 3;			
		_worldspace = if ((typeName (_x select 4)) == "ARRAY") then { _x select 4 } else { [] };
		_inventory=	if ((typeName (_x select 5)) == "ARRAY") then { _x select 5 } else { [] };
		_hitpoints=	if ((typeName (_x select 6)) == "ARRAY") then { _x select 6 } else { [] };
		_fuel =	if ((typeName (_x select 7)) == "SCALAR") then { _x select 7 } else { 0 };
		_damage = if ((typeName (_x select 8)) == "SCALAR") then { _x select 8 } else { 0.9 };  
		_entity = nil;
	
		_dir = floor(random(360));
		_point = getMarkerpos "respawn_west";	
		if (count _worldspace >= 1 && {(typeName (_worldspace select 0)) == "SCALAR"}) then { 
			_dir = _worldspace select 0;
		};
		if (count _worldspace == 2 && {(typeName (_worldspace select 1)) == "ARRAY"}) then { 
			_i = _worldspace select 1;
			if (count _i == 3 &&
				{(typeName (_i select 0)) == "SCALAR"} && 
				{(typeName (_i select 1)) == "SCALAR"} &&
				{(typeName (_i select 2)) == "SCALAR"}) then {
				_point = _i;	
			};
		};
 	   
		if ((_class isKindOf "AllVehicles") && ((_CharacterID == "0") OR (_CharacterID == "1")) && (_damage < 1)) then {
			_point set [2, 0];
#ifdef VEH_MAINTENANCE_ROTTEN_AT_STARTUP
			if ((random(VEH_MAINTENANCE_ROTTEN_AT_STARTUP) < 1) AND {(_action == "OBJ")}) then {
				 _damage = VEH_MAINTENANCE_ROTTEN_LOGIC; _action = "DAMAGED"; 
			};
#endif
#ifdef VEH_MAINTENANCE_ADD_MISSING		

			// ask to create a new vehicle if damage is too high
			if (_damage > 0.85 AND (_action != "CREATED")) then { _action = "SPAWNED"; };  
#endif
			// check for no collision with world. Find a suitable place (depending of defined parameters)
			_worldspace = [_class, _dir, _point, _action] call fa_smartlocation;
			if (count _worldspace < 2) then {  // safe position NOT found
				_action = "FAILED"; // don't worry, maybe we will find a nice spot next time :)
			}
			else { // found a spot for respawn
				if ((([_worldspace select 1, _point] call BIS_fnc_distance2D) > 1) 
					AND (_action == "OBJ")) then { _action = "MOVED"; };
				_dir = _worldspace select 0;
				_point = _worldspace select 1;
				_entity = createVehicle [_class, _point, [], 0, 
					if ((_class isKindOf "Air") OR {(_action != "OBJ")}) then {"NONE"} else {"CAN_COLLIDE"}
				]; 
				_entity setVariable ["ObjectID", _ObjectID, true]; // this variable must be set very early
				_entity setVariable ["CharacterID", _CharacterID, true];	
				_entity setVariable ["lastUpdate",time]; // prevent immediate hive write when vehicle parts are set up
				// setPos will be done again just after setDir, see below....
#ifdef VEH_MAINTENANCE_ADD_MISSING		
				if (_damage > 0.85) then { 
					_fuel = VEH_MAINTENANCE_SPAWN_FUEL_LOGIC;
					_hitpoints = [];
					_damage = _hitpoints call fa_setDamagedParts;
		
					_inventory = [];
				};
#endif
				_entity setDamage _damage;
				{
					_wantExplosiveParts = _x;
					{
						_selection = _x select 0;
						_dam = _x select 1;
						if (_selection in dayZ_explosiveParts) then {
							if (_wantExplosiveParts) then {
								if (_dam > 0.8) then { _dam = 0.8; };
								[_entity, _selection, _dam] call fnc_veh_handleDam;
							};
						}
						else {
							if (!_wantExplosiveParts) then {
								[_entity, _selection, _dam] call fnc_veh_handleDam;
							};
						};
					} forEach _hitpoints;
				} forEach [false, true];
				_entity setvelocity [0,0,1];
				_entity setFuel _fuel;
				_entity call fnc_veh_ResetEH;
			};
#ifdef OBJECT_DEBUG
			diag_log (format["VEHICLE %1 %2 at %3, original damage=%4, effective damage=%6, fuel=%5",
				 _action, _entity call fa_veh2str, (getPosASL _entity) call fa_coor2str, _damage, _fuel, damage _entity]);
#endif
		}
		else {
			if (!(_class in SafeObjects )) then {  
				_damage = 1; 
			};
			if (_damage < 1) then {
				_booleans=[];
				_worldspace = [_class, _point, _booleans] call fn_niceSpot;
				if (_booleans select 3) then {
					if ((_class != "TentStorage") OR {(_inventory call fa_tentEmpty)}) then {
						_action = "FAILED";
						_damage = 5;
#ifdef OBJECT_DEBUG
						diag_log(format["Won't spawn object #%1(%4) in/close to a building, _point:%3, inventory: %5 booleans:%2",_ObjectID, _booleans, _point, _class, _inventory]);
#endif
					};
				};
			};
			if (_damage < 1) then {
#ifdef OBJECTS_FIX_OUTOFMAP
				_worldspace = [_dir, _point] call fa_staywithus;
				_dir =  _worldspace select 0;
				_point =  _worldspace select 1;
#endif
				_entity = createVehicle [_class, _point, [], 0, 
					if (_class=="TentStorage") then {"NONE"} else {"CAN_COLLIDE"}
				];	
				_entity setVariable ["ObjectUID", _ObjectID, true];
				_entity setVariable ["CharacterID", _CharacterID, true];	
				_entity setVariable ["lastUpdate",time];
				_entity setDamage _damage;
	
				if (_class == "TentStorage") then { 
					_entity addMPEventHandler ["MPKilled",{_this call vehicle_handleServerKilled;}]; 
				};
			}
			else {
#ifdef OBJECT_DEBUG
				diag_log (format["IGNORED %1 oid#%2 cid:%3 ",
					_class, _ObjectID, _CharacterID ]);
#endif
			};
		};		
		if (_damage < 1 AND !(isNil ("_entity"))) then {
			_entity setdir _dir;
			_entity setPos _point;
			[_entity, _inventory] call fa_populateCargo;
			
			dayz_serverObjectMonitor set [count dayz_serverObjectMonitor, _entity];
			if (_action == "CREATED") then {
				_key = format["CHILD:308:%1:%2:%3:%4:%5:%6:%7:%8:%9:", dayZ_instance, 
					_class, _damage , 1, 
					[_dir, _point], 
					[getWeaponCargo _entity, getMagazineCargo _entity ,getBackpackCargo _entity], 
					_hitpoints, _fuel, _ObjectID
				];
				_rawData = "HiveEXT" callExtension _key;
			};
			if (_action == "SPAWNED" || _action == "DAMAGED") then {
			};
			if (_action == "SPAWNED") then {
				_key = format["CHILD:309:%1:%2:", _ObjectID, 
					[getWeaponCargo _entity, getMagazineCargo _entity, getBackpackCargo _entity]];
				_rawData = "HiveEXT" callExtension _key;
			};
			if (_action == "MOVED" || _action == "SPAWNED") then {
				[_entity, "position"] call server_updateObject;
			};
		};
		sleep 0.01;
	} forEach _objectArray;

// Finish initialization ----------------------------------------------------------------------------------------------

	createCenter civilian;
	if (isDedicated) then {
		endLoadingScreen;
	};	
	
	if (isDedicated) then {
		_id = [] execFSM "\z\addons\dayz_server\system\server_cleanup.fsm";
	};

	allowConnection = true;

// Heli Crashes --------------------------------------------------------------------------------------------------------

	// [_guaranteedLoot, _randomizedLoot, spawnOnStart, _frequency, _variance, _spawnChance, _spawnMarker, _spawnRadius, _spawnFire, _fadeFire]
	[3, 4, 3, (40 * 60), (15 * 60), 0.75, 'center', 4000, true, false] spawn server_spawnCrashSite;

// Spawn Camps --------------------------------------------------------------------------------------------------------

	// quantity, marker, radius, min distance between 2 camps
	Server_InfectedCamps = [3, "center", 4500, 2000] call fn_bases;
	dayzInfectedCamps = Server_InfectedCamps;
	publicVariable "dayzInfectedCamps";
	
// Care packages ------------------------------------------------------------------------------------------------------

if (SpawnCare) then {
	for "_x" from 1 to SpawnCareCount do {
		_id = [] spawn spawn_care;
	};
};
	
// Wrecks (Not Heli Crashes!) -----------------------------------------------------------------------------------------

if (SpawnWrecks) then {
	for "_x" from 1 to SpawnWrecksCount do {
		_id = [] spawn spawn_wreck;
	};
};

// Anti Wallhack ------------------------------------------------------------------------------------------------------

	call compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\fa_antiwallhack.sqf";
	
	sm_done = true;
	publicVariable "sm_done";
};