#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: Makefile.PL,v 1.3 2003/01/08 20:11:36 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

use ExtUtils::MakeMaker;

WriteMakefile
  (
   'NAME'	   => 'ESRI',
   'VERSION'       => '0.01',
   'EXE_FILES'     => ['esri2bbd.pl'],
   'PREREQ_PM'     => {Class::Accessor => undef,
		      },

   'PM' => {'Shapefile.pm'       => '$(INST_LIB)/ESRI/Shapefile.pm',
	    'Shapefile/Main.pm'  => '$(INST_LIB)/ESRI/Shapefile/Main.pm',
	    'Shapefile/Index.pm' => '$(INST_LIB)/ESRI/Shapefile/Index.pm',
	    'Shapefile/DBase.pm' => '$(INST_LIB)/ESRI/Shapefile/DBase.pm',
	   },

   'dist' => {'POSTOP'=>'-$(CHMOD) 644 $(DISTVNAME).tar$(SUFFIX)'},

   'ABSTRACT_FROM' => '',
   'AUTHOR'        => 'Slaven Rezic (slaven@rezic.de)',
  );

__END__
