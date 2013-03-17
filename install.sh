#!/bin/sh

# Use this shell script to start install.pl
# from Konqueror.

mydirname=`dirname $0`
cd $mydirname
perl ./install.pl
