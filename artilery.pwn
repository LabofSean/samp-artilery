/*
**
**
**
*/
#define FILTERSCRIPT

#include <a_samp>
#include <streamer>
#include <colandreas>
#tryinclude <foreach>

#if defined _FOREACH_LOCAL_VERSION
	#define ART_FOREACH				1
#endif

#if !defined ART_DELAY
	#define ART_DELAY				50
#endif

#if !defined ART_SPEED_MINI
	#define ART_SPEED_MINI				50
#endif

#if !defined ART_SPEED_LARG
	#define ART_SPEED_LARG				150		// temporarily not used
#endif

#if !defined ART_TICKS_TO_LARG
	#define ART_TICKS_TO_LARG			200		// temporarily not used
#endif

#if !defined ART_EXPLODE
	#define ART_EXPLODE				6
#endif

#if !defined ART_CORE
	#define ART_CORE				E_STREAMER_CUSTOM(500)
#endif

#if !defined ART_ID
	#define ART_ID					E_STREAMER_CUSTOM(501)
#endif

enum e_ART_DATA {
	Float: artX,
	Float: artY,
	Float: artZ,
	Float: artRadius,
	artTeam,
	artTarget,
	artArea
}

new artData[][e_ART_DATA] = {
	{	188.209503, 2081.165527, 26.092545, 400.0, 1, INVALID_PLAYER_ID, -1	},
	{	354.407928, 2028.423218, 26.139120, 400.0, 1, INVALID_PLAYER_ID, -1	},
	{	237.608398, 1696.536255, 26.099346, 400.0, 1, INVALID_PLAYER_ID, -1	},
	{	15.7157551, 1718.894897, 26.111212, 400.0, 1, INVALID_PLAYER_ID, -1	},
	{	-1394.779419, 493.404846, 21.681023, 500.0, 1, INVALID_PLAYER_ID, -1	},
	{	-1324.414063, 493.413239, 24.688835, 500.0, 1, INVALID_PLAYER_ID, -1	}
};

public OnFilterScriptInit()
{
	new arts;

	#if defined ART_STREAMRATE
		Streamer_SetTickRate(ART_STREAMRATE);
	#endif

	for(new i; i < sizeof(artData); i ++)
	{
		CreateDynamicObject(2995, artData[i][artX], artData[i][artY], artData[i][artZ], 0, 0, 0); // Test object

		artData[i][artTarget] = INVALID_PLAYER_ID;
		artData[i][artArea] = CreateDynamicSphere(artData[i][artX], artData[i][artY], artData[i][artZ], artData[i][artRadius]);

		Streamer_SetIntData(STREAMER_TYPE_AREA, artData[i][artArea], ART_CORE,	2);
		Streamer_SetIntData(STREAMER_TYPE_AREA,	artData[i][artArea], ART_ID,	i);

		arts ++;
	}

	SetTimer("ArtUpdate", ART_DELAY, true);

	printf("[ARTILERY] Loaded %d arts", arts);

	return 1;
}

public OnDynamicObjectMoved(objectid)
{
	if(Streamer_GetIntData(STREAMER_TYPE_OBJECT, objectid, ART_CORE) == 1)
	{
		new Float:x, Float:y, Float:z;

		GetDynamicObjectPos(objectid, x, y, z);
		CreateExplosion(x, y, z, ART_EXPLODE, 35);
		DestroyDynamicObject(objectid);

		return 1;
	}

	return 1;
}

public OnPlayerEnterDynamicArea(playerid, areaid)
{
	if(Streamer_GetIntData(STREAMER_TYPE_AREA, areaid, ART_CORE) == 2)
	{
		new
			artid = Streamer_GetIntData(STREAMER_TYPE_AREA, areaid, ART_ID),
			userid = artData[artid][artTarget];
		
		if(IsPlayerConnected(userid) && IsPlayerInRangeOfPoint(userid, artData[artid][artRadius], artData[artid][artX], artData[artid][artY], artData[artid][artZ]) && IsAPlane(userid))
			return 1;

		artData[artid][artTarget] = playerid;
	}

	return 1;
}

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
	if(Streamer_GetIntData(STREAMER_TYPE_AREA, areaid, ART_CORE) == 2)
	{
		new
			artid = Streamer_GetIntData(STREAMER_TYPE_AREA, areaid, ART_ID);

		if(artData[artid][artTarget] != playerid)
			return 1;

		artData[artid][artTarget] = INVALID_PLAYER_ID;

		#if defined ART_FOREACH
		foreach(new i : Player)
		{
			if(!IsPlayerInDynamicArea(i, artData[artid][artArea]))
				continue;
			
			Streamer_Update(i, STREAMER_TYPE_OBJECT);

			break;
		}
		#else
		for(new i; i < GetPlayerPoolSize(); i ++)
		{
			if(!IsPlayerConnected(i))
				continue;

			if(!IsPlayerInDynamicArea(i, artData[artid][artArea]))
				continue;

			Streamer_Update(i, STREAMER_TYPE_OBJECT);

			break;
		}
		#endif

		return 1;
	}

	return 1;
}

forward ArtUpdate();
public ArtUpdate()
{
	for(new i; i < sizeof(artData); i ++)
		ArtShoot(i);
}

forward ArtShoot(artid);
public ArtShoot(artid)
{
	new userid = artData[artid][artTarget];

	if(!IsPlayerConnected(userid) || !IsPlayerInRangeOfPoint(userid, artData[artid][artRadius], artData[artid][artX], artData[artid][artY], artData[artid][artZ]) || !IsAPlane(userid))
		return 1;

	new
		Float:pX = artData[artid][artX],
		Float:pY = artData[artid][artY],
		Float:pZ = artData[artid][artZ],
		Float:atX, Float:atY, Float:atZ,
		Float:dist = GetPlayerDistanceFromPoint(userid, pX, pY, pZ);

	new offdist = GetPlayerPosFrontVehicleToArt(userid, dist, atX, atY, atZ);
	CA_RayCastLine(pX, pY, pZ, atX, atY, atZ, atX, atY, atZ);

	if(DistancePointToPoint(pX, pY, pZ, atX, atY, atZ) + 10 < dist)
		return 1;

	dist += offdist * (dist/50) + 8;

	new objectid = CreateDynamicObject(3065, pX, pY, pZ, 0, 0, 0, GetPlayerVirtualWorld(userid), -1);

	Streamer_SetIntData(STREAMER_TYPE_OBJECT, objectid, ART_CORE, 1);
	MoveDynamicObject(objectid, atX, atY, atZ, ART_SPEED_MINI, 0, 0, 0);

	#if defined ART_FOREACH
	foreach(new i : Player)
	{
		Streamer_Update(i, STREAMER_TYPE_OBJECT);
	}
	#else
	for(new i; i < GetPlayerPoolSize(); i ++)
	{
		if(!IsPlayerConnected(i))
			continue;

		Streamer_Update(i, STREAMER_TYPE_OBJECT);
	}
	#endif
	return 1;
}

stock GetPlayerPosFrontVehicleToArt(playerid, Float:dist, &Float:atX, &Float:atY, &Float:atZ)
{
	if(!IsAPlane(playerid))
		return 1;
	
	new
		Float:pX, Float:pY, Float:pZ,
		Float:vX, Float:vY, Float:vZ,
		vehicleid = GetPlayerVehicleID(playerid);
	
	dist = GetVehicleSpeed(vehicleid) - 4;

	GetVehiclePos(vehicleid, pX, pY, pZ);
	GetVehicleRotation(vehicleid, vX, vY, vZ);

	atX = floatround( pX + (dist * floatsin(-vZ, degrees)) ),
	atY = floatround( pY + (dist * floatcos(-vZ, degrees)) ),
	atZ = floatround( pZ + (dist * floatsin(vX, degrees)) );

	return floatround(dist);
}

//
stock DistancePointToPoint(Float: x, Float: y, Float: z, Float: fx, Float:fy, Float: fz)
	return floatround(floatsqroot(floatpower(fx - x, 2) + floatpower(fy - y, 2) + floatpower(fz - z, 2)));

stock GetVehicleSpeed(vehicleid)
{
    new	
		Float:pX,
		Float:pY,
		Float:pZ;
	
    GetVehicleVelocity(vehicleid, pX, pY, pZ);
    return floatround(floatsqroot(pX*pX+pY*pY+pZ*pZ)*100);
}

stock GetVehicleRotation(vehicleid, &Float:rX, &Float:rY, &Float:rZ)
{
	new 
		Float:qW,
		Float:qX,
		Float:qY,
		Float:qZ;
		
	GetVehicleRotationQuat(vehicleid, qW, qX, qY, qZ);
	rX = asin(2*qY*qZ-2*qX*qW);
	rY = -atan2(qX*qZ+qY*qW,0.5-qX*qX-qY*qY);
	rZ = -atan2(qX*qY+qZ*qW,0.5-qX*qX-qZ*qZ);
}

stock IsAPlane(playerid)
{
	switch(GetVehicleModel(GetPlayerVehicleID(playerid)))
	{
		case 460, 464, 476, 511, 512, 513, 519, 520, 553, 577, 592, 593: return 1;
	}

	return 0;
}
