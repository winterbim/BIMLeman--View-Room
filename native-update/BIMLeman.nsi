Unicode true
!include "MUI2.nsh"
Name "BIMLéman View Room"
OutFile "BIMLeman-View-Room-Update.exe"
InstallDir "$LOCALAPPDATA\Programs\BIMLemanViewRoom"
RequestExecutionLevel user
Icon "brand.ico"
UninstallIcon "brand.ico"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "French"
Section "Application"
  SetOutPath "$INSTDIR"
  File "publish\BIMLemanViewRoom.exe"
  File "brand.ico"
  CreateDirectory "$SMPROGRAMS\BIMLéman View Room"
  CreateShortcut "$SMPROGRAMS\BIMLéman View Room\BIMLéman View Room.lnk" "$INSTDIR\BIMLemanViewRoom.exe" "" "$INSTDIR\brand.ico"
  CreateShortcut "$DESKTOP\BIMLéman View Room.lnk" "$INSTDIR\BIMLemanViewRoom.exe" "" "$INSTDIR\brand.ico"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd
Section "Uninstall"
  Delete "$DESKTOP\BIMLéman View Room.lnk"
  Delete "$SMPROGRAMS\BIMLéman View Room\BIMLéman View Room.lnk"
  RMDir "$SMPROGRAMS\BIMLéman View Room"
  Delete "$INSTDIR\BIMLemanViewRoom.exe"
  Delete "$INSTDIR\brand.ico"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
SectionEnd