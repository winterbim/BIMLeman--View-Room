Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
Name "BIMLéman View Room (${BUILD_ID})"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\BIMLemanNative\${BUILD_ID}"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Icon "${STAGE}\brand.ico"
UninstallIcon "${STAGE}\brand.ico"
!define MUI_ICON "${STAGE}\brand.ico"
!define MUI_UNICON "${STAGE}\brand.ico"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${STAGE}\COPYING"
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "French"
Function .onInit
  SetShellVarContext current
  ; Installation in a fresh versioned directory only. No Veyon installation is overwritten.
  ${If} ${FileExists} "$INSTDIR\*.*"
    MessageBox MB_ICONSTOP "Le dossier candidat existe déjà. Désinstallez ce candidat avant de recommencer."
    SetErrorLevel 10
    Abort
  ${EndIf}
FunctionEnd
Section "Application native"
  SetOutPath "$INSTDIR"
  File /r /x uninstall-files.nsh "${STAGE}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BIMLemanNative-${BUILD_ID}" "DisplayName" "BIMLéman View Room (${BUILD_ID})"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BIMLemanNative-${BUILD_ID}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BIMLemanNative-${BUILD_ID}" "DisplayIcon" "$INSTDIR\veyon-master.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BIMLemanNative-${BUILD_ID}" "DisplayVersion" "${VERSION}"
  CreateDirectory "$SMPROGRAMS\BIMLéman View Room ${BUILD_ID}"
  CreateShortcut "$SMPROGRAMS\BIMLéman View Room ${BUILD_ID}\BIMLéman View Room.lnk" "$INSTDIR\veyon-master.exe" "" "$INSTDIR\brand.ico"
SectionEnd
Section "Uninstall"
  SetShellVarContext current
  ; Explicit generated file list: never recursively delete an arbitrary /D target.
  !include "${STAGE}\uninstall-files.nsh"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\BIMLéman View Room ${BUILD_ID}\BIMLéman View Room.lnk"
  RMDir "$SMPROGRAMS\BIMLéman View Room ${BUILD_ID}"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BIMLemanNative-${BUILD_ID}"
SectionEnd
