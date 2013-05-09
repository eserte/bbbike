@echo off
rem Use this if BBBike is already installed on the system using the InnoSetup installer; which means that perl 5.6.1 is available
rem Prefer SiePerl, check for one of the both possible locations (pre-Vista,localized german and Vista)

IF EXIST "c:\program files\bbbike\perl\bin\perl.exe" GOTO BBBikeDistEN
IF EXIST c:\programme\bbbike\perl\bin\perl.exe GOTO BBBikeDistDE
IF EXIST c:\perl\bin\perl.exe GOTO Activeperl
IF EXIST c:\strawberry\perl\bin\perl.exe GOTO Strawberry
echo Cannot find any perl, fall through...
GOTO BBBikeDistEN

:BBBikeDistDE
c:\programme\bbbike\perl\bin\perl bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:BBBikeDistEN
"c:\program files\bbbike\perl\bin\perl" bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:Activeperl
C:\perl\bin\perl bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:Strawberry
C:\strawberry\perl\bin\perl bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:End
