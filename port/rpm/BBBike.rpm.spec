### DO NOT EDIT! CREATED AUTOMATICALLY BY ./mkrpm.pl! ###
%define __prefix        %{_prefix}
Name: BBBike
Version: 3.18
Release: 1
License: GPL-2.0
Group: Productivity/Scientific/Other
AutoReqProv: no
# XXX once we build the "ext" stuff the following should be removed
BuildArch: noarch
Requires: perl >= 5.005, perl(Tk) >= 800
Prefix: %{__prefix}
URL: http://bbbike.sourceforge.net
Packager: slaven@rezic.de
Source: http://heanet.dl.sourceforge.net/project/bbbike/BBBike/3.18/BBBike-3.18.tar.gz
Summary: A route-finder for cyclists in Berlin and Brandenburg


# Needed by RHEL5 (only)?
BuildRoot: %{_tmppath}/%{name}-root

%description
A route-finder for cyclists in Berlin and Brandenburg.
BBBike is now ported to more than 200 cities around the world - thanks to 
the OpenStreetMap project. For more information see the BBBike @ World 
homepage http://www.bbbike.org
------------------------------------------------------------------------
BBBike is an information system for cyclists in Berlin and 
Brandenburg (Germany). It has the following features:
* Displays a map with streets, railways, rivers, parks, altitude, and 
  other features 
* Finds and shows routes between two points
* Route-finder can be customized to match the cyclist's preferences: 
  fastest/nicest route, take wind directions and hills into account, etc.)
* Bike power calculator 
* Automatically fetches the current Berlin weather data
------------------------------------------------------------------------
Mit BBBike koennen Fahrrad-Routen in Berlin und Umgebung automatisch
oder manuell erstellt werden.
BBBike liefert unter anderem die Antwort auf folgende Fragen:
* Wie lang ist die Strecke von A nach B?
* Wie schnell komme ich von A nach B, wenn ich durchschnittlich 15
  km/h schnell fahre?
* Wie lange brauche ich von A nach B, wenn ich mit 100 Watt Leistung
  fahre, mit Beruecksichtigung des aktuellen Windes und von
  Steigungen auf der Strecke?
* Auf welchen Strassen fahre ich, wenn ich von A nach B kommen will?
* Wo habe ich Gegenwind- und Rueckenwindstrecken?
* Wo gibt es Steigungen und Gefaelle?
WWW: http://bbbike.sourceforge.net


%prep
%setup

%build
grep '/\.'      MANIFEST | awk '{print $1}' | xargs rm
grep '\.[cht]$' MANIFEST | awk '{print $1}' | xargs rm
rm cgi/bbbike.psgi
rm tkbikepwr

%install
mkdir -p $RPM_BUILD_ROOT%{_prefix}/lib/BBBike
cp -R . $RPM_BUILD_ROOT%{_prefix}/lib/BBBike

%post
rm -f %{_bindir}/bbbike
ln -s %{_prefix}/lib/BBBike/bbbike %{_bindir}/bbbike

%postun
rm -f %{_bindir}/bbbike

%files
%defattr(-,root,root)

%dir %{_prefix}/lib/BBBike
%{_prefix}/lib/BBBike/*

%changelog
* Sun Mar 17 2013 Slaven Rezic <slaven@rezic.de> - 3.18-1
- new version of BBBike
