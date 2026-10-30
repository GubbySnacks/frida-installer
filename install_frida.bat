@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  Frida Full Installer
::  PC toolkit + matching frida-server pushed to Quest (ARM64)
:: ============================================================

echo.
echo ========================================
echo   FRIDA INSTALLER (PC + QUEST SERVER)
echo ========================================
echo.

:: --- Step 1: Check for Python ---
echo [*] Checking for Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Python not found on PATH.
    echo [!] Install Python 3.8+ from https://www.python.org/downloads/
    echo [!] IMPORTANT: check "Add Python to PATH" during install, then re-run this script.
    pause
    exit /b 1
)

for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PYVER=%%v
echo [+] Found Python !PYVER!
echo.

:: --- Step 2: Upgrade pip ---
echo [*] Upgrading pip...
python -m pip install --upgrade pip
echo.

:: --- Step 3: Install Frida core + tools ---
echo [*] Installing Frida core and CLI tools...
echo     (frida, frida-tools)
python -m pip install --upgrade frida frida-tools
if %errorlevel% neq 0 (
    echo [!] Frida install failed. Check your internet connection and pip output above.
    pause
    exit /b 1
)
echo.

:: --- Step 4: Optional extras ---
echo [*] Installing optional helpers...
echo     (objection - runtime mobile exploration toolkit built on Frida)
python -m pip install --upgrade objection
echo.

:: --- Step 5: Verify PC install ---
echo [*] Verifying PC installation...
echo.
echo --- frida version ---
frida --version
echo.
echo --- frida CLI tools available ---
where frida
where frida-ps
where frida-trace
where frida-ls-devices
where frida-kill
echo.

:: ============================================================
::  Step 6: Fetch matching frida-server for Quest (ARM64)
:: ============================================================
echo ========================================
echo   FETCHING FRIDA-SERVER FOR QUEST
echo ========================================
echo.

:: Read the installed frida client version so the server matches exactly
set FRIDA_VER=
for /f %%v in ('frida --version 2^>nul') do set FRIDA_VER=%%v

if "!FRIDA_VER!"=="" (
    echo [!] Could not read frida version. Skipping server fetch.
    pause
    exit /b 1
)
echo [+] Installed frida client version: !FRIDA_VER!
echo [*] Will fetch matching server: frida-server-!FRIDA_VER!-android-arm64
echo.

:: Write a small Python helper to download + decompress the .xz
:: (Python is guaranteed present; avoids needing curl/7zip/tar for .xz)
set DLHELPER=%TEMP%\_frida_dl.py
> "!DLHELPER!" echo import sys, urllib.request, lzma
>> "!DLHELPER!" echo version = sys.argv[1]
>> "!DLHELPER!" echo url = "https://github.com/frida/frida/releases/download/%%s/frida-server-%%s-android-arm64.xz" %% (version, version)
>> "!DLHELPER!" echo print("[*] Downloading " + url)
>> "!DLHELPER!" echo req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
>> "!DLHELPER!" echo data = urllib.request.urlopen(req).read()
>> "!DLHELPER!" echo print("[*] Decompressing (" + str(len(data)) + " bytes compressed)...")
>> "!DLHELPER!" echo out = lzma.decompress(data)
>> "!DLHELPER!" echo open("frida-server", "wb").write(out)
>> "!DLHELPER!" echo print("[+] Wrote frida-server (" + str(len(out)) + " bytes)")

echo [*] Downloading matching frida-server...
python "!DLHELPER!" !FRIDA_VER!
if %errorlevel% neq 0 (
    echo [!] Download/decompress failed.
    echo [!] Check that release exists at:
    echo [!]   https://github.com/frida/frida/releases/tag/!FRIDA_VER!
    del "!DLHELPER!" >nul 2>&1
    pause
    exit /b 1
)
del "!DLHELPER!" >nul 2>&1
echo.

:: ============================================================
::  Step 7: Push frida-server to the Quest over ADB
:: ============================================================
echo ========================================
echo   PUSHING TO QUEST OVER ADB
echo ========================================
echo.

:: Check for adb
where adb >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] adb not found on PATH.
    echo [!] Install Android platform-tools and add to PATH:
    echo [!]   https://developer.android.com/tools/releases/platform-tools
    echo [!] The frida-server binary was still downloaded to this folder.
    echo [!] Once adb is set up, push it manually with:
    echo [!]   adb push frida-server /data/local/tmp/frida-server
    echo [!]   adb shell chmod 755 /data/local/tmp/frida-server
    pause
    exit /b 1
)

echo [*] Starting adb and checking for device...
adb start-server
adb devices
echo.
echo [!] Make sure your Quest is connected, awake, and USB debugging is allowed.
echo [!] (Check the headset for the "Allow USB debugging?" prompt.)
pause
echo.

echo [*] Pushing frida-server to /data/local/tmp/ ...
adb push frida-server /data/local/tmp/frida-server
if %errorlevel% neq 0 (
    echo [!] Push failed. Is the Quest connected and authorized? Re-run after fixing.
    pause
    exit /b 1
)

echo [*] Setting executable permission...
adb shell chmod 755 /data/local/tmp/frida-server
echo.

echo ========================================
echo   DONE
echo ========================================
echo.
echo PC tools installed and frida-server deployed to the Quest.
echo.
echo To start the server on the Quest (needs root):
echo   adb shell "su -c /data/local/tmp/frida-server ^&"
echo.
echo Then from your PC, confirm the connection:
echo   frida-ps -U
echo.
echo If the Quest is not rooted, running frida-server usually requires
echo root (su). Without it, use a repackaged/gadget approach instead.
echo.
pause
