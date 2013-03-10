@echo off
setlocal enabledelayedexpansion

echo ----------------------------------------------------
echo Starting up build ...
echo ----------------------------------------------------
echo.

if exist build (rmdir /s /q build)
if not exist build\@dayzcc\addons (mkdir build\@dayzcc\addons)
if not exist build\MPMissions (mkdir build\MPMissions)

echo.
echo ----------------------------------------------------
echo Building server addon ...
echo ----------------------------------------------------
echo.

util\cpbo.exe -y -p server\dayz_server build\@dayzcc\addons\dayz_server.pbo

echo.
echo ----------------------------------------------------
echo Building mission files ...
echo ----------------------------------------------------
echo.

echo Instance 1:
echo ^> Skipping ...
for /l %%i in (2,1,6) do (
echo Instance %%i:
for %%f in (chernarus fallujah lingor mbg_celle2 namalsk panthera2 takistan tavi thirsk utes zargabad oring isladuala) do (
echo ^> Building mission for "%%f"
mkdir temp > nul
xcopy mission\dayz.%%f temp /S /E /Q /C /R /Y > nul
cscript /nologo util\instance.vbs mission\dayz.%%f\init.sqf %%i > temp\init.sqf
util\cpbo.exe -y -p temp build\MPMissions\dayz_%%i.%%f.pbo > nul
rmdir /s /q temp > nul
)
)

for /l %%i in (1,1,6) do (
echo Instance %%i ^(rMod^):
for %%f in (chernarus fallujah lingor mbg_celle2 namalsk panthera2 takistan tavi thirsk utes zargabad oring isladuala) do (
echo ^> Building mission for "%%f"
mkdir temp > nul
xcopy mission\dayz.%%f temp /S /E /Q /C /R /Y > nul
cscript /nologo util\instance.vbs mission\dayz.%%f\init.sqf %%i > temp\init.sqf
cscript /nologo util\rmod.vbs mission\dayz.%%f\mission.sqm %%i > temp\mission.sqm
util\cpbo.exe -y -p temp build\MPMissions\rmod_%%i.%%f.pbo > nul
rmdir /s /q temp > nul
)
)

echo.
echo ----------------------------------------------------
echo Copying additional files ...
echo ----------------------------------------------------
echo.

xcopy mission build\MPMissions /S /E /Q /C /R /Y > nul
cscript /nologo util\rename.vbs > nul
copy server\dayz_server_config.hpp build\@dayzcc\addons\dayz_server_config.hpp > nul
copy server\HiveExt.dll build\@dayzcc\HiveExt.dll > nul
echo Done ...

echo.
echo ----------------------------------------------------
echo Finished! Press any key to exit ...
echo ----------------------------------------------------
pause>nul