@echo off
rem Use this if BBBike is already installed on the system using the InnoSetup installer; which means that perl 5.6.1 is available
rem Prefer SiePerl, check for one of the both possible locations (pre-Vista,localized german and Vista)

IF EXIST c:\programme\bbbike\windows\5.6.1\bin\MSWin32-x86\perl GOTO Sieperlold
IF EXIST "c:\program files\bbbike\windows\5.6.1\bin\MSWin32-x86\perl" GOTO Sieperlnew
IF EXIST c:\perl\bin\perl GOTO Activeperl
IF EXIST c:\strawberry\perl\bin\perl GOTO Strawberry
echo "Cannot find any perl, fall through..."

Sieperlold:
c:\programme\bbbike\windows\5.6.1\bin\MSWin32-x86\perl -Ic:\programme\bbbike\windows\5.6.1\lib -Ic:\programme\bbbike\windows\site\5.6.1\lib bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

Sieperlnew:
"c:\program files\bbbike\windows\5.6.1\bin\MSWin32-x86\perl" "-Ic:\program files\bbbike\windows\5.6.1\lib" "-Ic:\program files\bbbike\windows\site\5.6.1\lib" bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

Activeperl:
C:\perl\bin\perl bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

Strawberry:
C:\strawberry\perl\bin\perl bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:End
