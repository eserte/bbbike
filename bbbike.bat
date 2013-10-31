@echo off
rem Use this batch script if BBBike is already installed on the system
rem using the InnoSetup installer; which means that a suitable perl with
rem required modules, especially Tk, already exists
rem If BBBike is not installed, then fallback to either Strawberry Perl
rem in its standard install location (Tk may be compiled with strawberry)
rem or ActivePerl (least preferred, as Tk is not anymore available for
rem ActivePerl)

IF EXIST "%ProgramFiles%\bbbike\perl\bin\perl.exe" GOTO BBBikeDistAny
IF EXIST "c:\program files\bbbike\perl\bin\perl.exe" GOTO BBBikeDistEN
IF EXIST c:\programme\bbbike\perl\bin\perl.exe GOTO BBBikeDistDE
IF EXIST c:\strawberry\perl\bin\perl.exe GOTO Strawberry
IF EXIST c:\perl\bin\perl.exe GOTO Activeperl
echo Cannot find any perl, fall through...
GOTO BBBikeDistEN

:BBBikeDistAny
"%ProgramFiles%\bbbike\perl\bin\perl" bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:BBBikeDistDE
c:\programme\bbbike\perl\bin\perl bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:BBBikeDistEN
"c:\program files\bbbike\perl\bin\perl" bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:Strawberry
C:\strawberry\perl\bin\perl bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:Activeperl
C:\perl\bin\perl bbbike %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO End

:End
