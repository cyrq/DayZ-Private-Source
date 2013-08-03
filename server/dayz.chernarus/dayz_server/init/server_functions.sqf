//Include DayZCC specific settings
//#include "\@dayzcc\addons\dayz_server_config.hpp"

#include "\z\addons\dayz_server\compile\server_toggle_debug.hpp"

waituntil {!isnil "bis_fnc_init"};

BIS_MPF_remoteExecutionServer = {
	if ((_this select 1) select 2 == "JIPrequest") then {
		[nil,(_this select 1) select 0,"loc",rJIPEXEC,[any,any,"per","execVM","ca\Modules\Functions\init.sqf"]] call RE;
	};
};

BIS_Effects_Burn =			{};

// Player Login/Setup/Disconnect
server_playerLogin =		compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerLogin.sqf";
server_playerSetup =		compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerSetup.sqf";
server_onPlayerDisconnect = compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_onPlayerDisconnect.sqf";

// Player Sunchronization/Death
server_playerSync =			compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerSync.sqf";
server_playerDied =			compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerDied.sqf";

// Objects
server_updateObject =		compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_updateObject.sqf";
server_publishObj = 		compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_publishObject.sqf";
server_deleteObj =			compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_deleteObj.sqf";
server_updateNearbyObjects =	compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_updateNearbyObjects.sqf";

// Find Zed Owner
zombie_findOwner =			compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\zombie_findOwner.sqf";

// Crash Sites
server_spawnCrashSite =    compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_spawnCrashSite.sqf";

// Include BIS compositions
spawnComposition = 			compile preprocessFileLineNumbers "ca\modules\dyno\data\scripts\objectMapper.sqf";

// Infected Camps
fn_bases = compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\fn_bases.sqf";

// Care Packages/Wrecks
spawn_wreck = 				compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\spawn_wreck.sqf";
spawn_care = 				compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\spawn_care.sqf";

// Kill Msg's
server_playerHit = 			compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerHit.sqf";

onPlayerDisconnected 		"[_uid, _name] call server_onPlayerDisconnect;";


//Vehicles
vehicle_handleServerKilled = {
	private["_unit","_killer"];
	_unit = _this select 0;
	_killer = _this select 1;
		
	[_unit, "killed"] call server_updateObject;
	
	_unit removeAllMPEventHandlers "MPKilled";
	_unit removeAllEventHandlers "Killed";
	_unit removeAllEventHandlers "HandleDamage";
	_unit removeAllEventHandlers "GetIn";
	_unit removeAllEventHandlers "GetOut";
};

//Objects
check_publishobject = {
	private["_allowed","_allowedObjects","_object"];

	_object = _this select 0;
	_playername = _this select 1;
	_allowedObjects = ["TentStorage", "Hedgehog_DZ", "Sandbag1_DZ", "TrapBear", "Wire_cat1", "StashSmall", "StashMedium"];
	_allowed = false;

#ifdef OBJECT_DEBUG
	diag_log format ["DEBUG: Checking if Object: %1 is allowed published by %2", _object, _playername];
#endif

	if ((typeOf _object) in _allowedObjects) then {
#ifdef OBJECT_DEBUG
		diag_log format ["DEBUG: Object: %1 published by %2 is Safe",_object, _playername];
#endif
		_allowed = true;
	};

	_allowed
};

//Event Handlers
eh_localCleanup = {
	private ["_object"];
	_object = _this select 0;
	_object addEventHandler ["local", {
		if(_this select 1) then {
			private["_type","_unit"];
			_unit = _this select 0;
			_type = typeOf _unit;
			 _myGroupUnit = group _unit;
 			_unit removeAllMPEventHandlers "mpkilled";
 			_unit removeAllMPEventHandlers "mphit";
 			_unit removeAllMPEventHandlers "mprespawn";
 			_unit removeAllEventHandlers "FiredNear";
			_unit removeAllEventHandlers "HandleDamage";
			_unit removeAllEventHandlers "Killed";
			_unit removeAllEventHandlers "Fired";
			_unit removeAllEventHandlers "GetOut";
			_unit removeAllEventHandlers "GetIn";
			_unit removeAllEventHandlers "Local";
			clearVehicleInit _unit;
			deleteVehicle _unit;
			deleteGroup _myGroupUnit;
			_unit = nil;
			#ifdef SERVER_DEBUG
			diag_log ("CLEANUP: DELETED A " + str(_type) );
			#endif
		};
	}];
};

//HIVE
server_hiveWrite = {
	private["_data"];
	_data = "HiveExt" callExtension _this;
};

server_hiveReadWrite = {
	private["_key","_resultArray","_data"];
	_key = _this;
	_data = "HiveExt" callExtension _key;
	_resultArray = call compile format ["%1",_data];
	_resultArray
};


server_getDiff =	{
	private["_variable","_object","_vNew","_vOld","_result"];
	_variable = _this select 0;
	_object = 	_this select 1;
	_vNew = 	_object getVariable[_variable,0];
	_vOld = 	_object getVariable[(_variable + "_CHK"),_vNew];
	_result = 	0;
	if (_vNew < _vOld) then {
		_vNew = _vNew + _vOld;
		_object getVariable[(_variable + "_CHK"),_vNew];
	} else {
		_result = _vNew - _vOld;
		_object setVariable[(_variable + "_CHK"),_vNew];
	};
	_result
};

server_getDiff2 =	{
	private["_variable","_object","_vNew","_vOld","_result"];
	_variable = _this select 0;
	_object = 	_this select 1;
	_vNew = 	_object getVariable[_variable,0];
	_vOld = 	_object getVariable[(_variable + "_CHK"),_vNew];
	_result = _vNew - _vOld;
	_object setVariable[(_variable + "_CHK"),_vNew];
	_result
};

dayz_objectUID2 = {
	private["_position","_dir","_key"];
	_dir = _this select 0;
	_key = "";
	_position = _this select 1;
	{
		_x = _x * 10;
		if ( _x < 0 ) then { _x = _x * -10 };
		_key = _key + str(round(_x));
	} forEach _position;
	_key = _key + str(round(_dir));
	_key
};

dayz_recordLogin = {
	private ["_key"];
	_key = format["CHILD:103:%1:%2:%3:", _this select 0, _this select 1, _this select 2];
	_key call server_hiveWrite;
};

call compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\fa_hiveMaintenance.sqf";