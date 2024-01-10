/*
*	[L4D2] Vomitjar Glow
*	Copyright (C) 2024 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.3"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Vomitjar Glow
*	Author	:	SilverShot
*	Descrp	:	Creates a dynamic light where Vomitjars explode.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=344724
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.3 (10-Jan-2024)
	- Changed the plugins on/off/mode cvars to use the "Left 4 DHooks" method instead of creating an entity.

1.2 (08-Jan-2024)
	- Fixed the plugins on/off/mode cvars having no affect. Thanks to "S.A.S" for reporting.

1.1 (04-Dec-2023)
	- Fixed the "l4d2_vomitjar_glow_time" cvar not working and glow time being stuck on 15 seconds. Thanks to "S.A.S" for reporting.

1.0 (03-Dec-2023)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define MAX_LIGHTS			8


ConVar g_hCvarAllow, g_hCvarColor, g_hCvarDist, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarTime;
int g_iEntities[MAX_LIGHTS], g_iTick[MAX_LIGHTS];
bool g_bCvarAllow, g_bFrameProcessing;
char g_sCvarCols[12];
float g_fFaderTick[MAX_LIGHTS], g_fFaderStart[MAX_LIGHTS], g_fFaderEnd[MAX_LIGHTS], g_fCvarDist, g_fCvarTime;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Vomitjar Glow",
	author = "SilverShot",
	description = "Creates a dynamic light where Vomitjars explode.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=344724"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hCvarAllow =			CreateConVar(	"l4d2_vomitjar_glow_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d2_vomitjar_glow_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d2_vomitjar_glow_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d2_vomitjar_glow_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarColor =			CreateConVar(	"l4d2_vomitjar_glow_color",			"255 0 100",	"The light color. Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", CVAR_FLAGS );
	g_hCvarDist =			CreateConVar(	"l4d2_vomitjar_glow_distance",		"250.0",		"How far does the dynamic light illuminate the area.", CVAR_FLAGS );
	g_hCvarTime =			CreateConVar(	"l4d2_vomitjar_glow_time",			"20.0",			"The light glow duration.", CVAR_FLAGS );
	CreateConVar(							"l4d2_vomitjar_glow_version",		PLUGIN_VERSION,	"Vomitjar Glow plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d2_vomitjar_glow");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarColor.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDist.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTime.AddChangeHook(ConVarChanged_Cvars);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fCvarDist = g_hCvarDist.FloatValue;
	g_hCvarColor.GetString(g_sCvarCols, sizeof(g_sCvarCols));
	g_fCvarTime = g_hCvarTime.FloatValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
	}
}

int g_iCurrentMode;
public void L4D_OnGameModeChange(int gamemode)
{
	g_iCurrentMode = gamemode;
}

bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_iCurrentMode == 0 )
			g_iCurrentMode = L4D_GetGameModeType();

		if( g_iCurrentMode == 0 )
			return false;

		switch( g_iCurrentMode ) // Left4DHooks values are flipped for these modes, sadly
		{
			case 2:		g_iCurrentMode = 4;
			case 4:		g_iCurrentMode = 2;
		}

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}



// ====================================================================================================
//					LIGHTS
// ====================================================================================================
public void L4D2_VomitJar_Detonate_Post(int target, int client)
{
	if( g_bCvarAllow && (target = EntRefToEntIndex(target)) != INVALID_ENT_REFERENCE )
	{
		// Find index
		int index = -1;

		for( int i = 0; i < MAX_LIGHTS; i++ )
		{
			if( IsValidEntRef(g_iEntities[i]) == false )
			{
				index = i;
				break;
			}
		}

		if( index == -1 )
			return;

		// Create light
		static char sTemp[40];

		int entity = CreateEntityByName("light_dynamic");
		if( entity == -1)
		{
			LogError("Failed to create 'light_dynamic'");
			return;
		}

		g_iEntities[index] = EntIndexToEntRef(entity);

		FormatEx(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols);
		DispatchKeyValue(entity, "_light", sTemp);
		DispatchKeyValue(entity, "brightness", "3");
		DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
		DispatchKeyValueFloat(entity, "distance", 5.0);
		DispatchKeyValue(entity, "style", "6");
		DispatchSpawn(entity);

		float vPos[3], vAng[3];
		GetEntPropVector(target, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(target, Prop_Data, "m_angRotation", vAng);
		vPos[2] += 40.0;
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");

		float flTickInterval = GetTickInterval();
		int iTickRate = RoundFloat(1 / flTickInterval);

		// Fade
		if( !g_bFrameProcessing )
		{
			g_bFrameProcessing = true;
			RequestFrame(OnFrameFade);
		}

		g_iTick[index] = 7;
		g_fFaderEnd[index] = GetGameTime() + g_fCvarTime - (flTickInterval * iTickRate);
		g_fFaderStart[index] = GetGameTime() + flTickInterval * iTickRate + 2.0;
		g_fFaderTick[index] = GetGameTime() - 1.0;

		/* Old method (causes rare crash with too many inputs)
		// Fade in
		for(int i = 1; i <= iTickRate; i++)
		{
			Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:%f:-1", (g_fCvarDist / iTickRate) * i, flTickInterval * i);
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "AddOutput");
		}
		AcceptEntityInput(entity, "FireUser1");

		// Fade out
		for(int i = iTickRate; i > 1; --i)
		{
			Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", (g_fCvarDist / iTickRate) * i, g_fCvarTime - flTickInterval * i);
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "AddOutput");
		}
		AcceptEntityInput(entity, "FireUser2");
		*/

		FormatEx(sTemp, sizeof(sTemp), "OnUser3 !self:Kill::%f:-1", g_fCvarTime + 1.0);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser3");
	}

	return;
}

void OnFrameFade()
{
	g_bFrameProcessing = false;

	float fDist;
	float fTime = GetGameTime();
	float flTickInterval = GetTickInterval();
	int iTickRate = RoundFloat(1 / flTickInterval);

	// Loop through valid ents
	for( int i = 0; i < MAX_LIGHTS; i++ )
	{
		if( IsValidEntRef(g_iEntities[i]) )
		{
			g_bFrameProcessing = true;

			// Ready for fade on this tick
			if( fTime > g_fFaderTick[i] )
			{
				// Fade in
				if( fTime < g_fFaderStart[i] )
				{
					fDist = (g_fCvarDist / iTickRate) * g_iTick[i];
					if( fDist < g_fCvarDist )
					{
						SetVariantFloat(fDist);
						AcceptEntityInput(g_iEntities[i], "Distance");
					}

					g_iTick[i]++;
					g_fFaderTick[i] = fTime + flTickInterval;
				}
				// Fade out
				else if( fTime > g_fFaderEnd[i] )
				{
					fDist = (g_fCvarDist / iTickRate) * (iTickRate - g_iTick[i]);
					if( fDist < g_fCvarDist )
					{
						SetVariantFloat(fDist);
						AcceptEntityInput(g_iEntities[i], "Distance");
					}

					g_iTick[i]++;
					g_fFaderTick[i] = fTime + flTickInterval;
				}
				else
				{
					g_iTick[i] = 0;
				}
			}
		}
	}

	if( g_bFrameProcessing )
	{
		RequestFrame(OnFrameFade);
	}
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}
