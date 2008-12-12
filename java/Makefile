#
# $Id: Makefile,v 1.10 2006/11/09 22:00:46 eserte Exp $
#

#JAVAROOT?=/usr/lib/java

#DEBUG=	-g
#DEBUG= -Xlint:deprecation -Xlint:unchecked

#JAVAC=$(JAVAROOT)/bin/javac $(DEBUG)
#JAVA=$(JAVAROOT)/bin/java

JAVAC=javac $(DEBUG)
JAVA=java

all:	Strasse.class \
	Strassen.class MultiStrassen.class GeneralStrassen.class \
	StrassenNetz.class QSort.class BBBike.class MyCanvas.class \
	TestBBBike.class Kreuzungen.class

Strasse.class:	Strasse.java
	$(JAVAC) Strasse.java

Strassen.class: Strassen.java
	$(JAVAC) Strassen.java

MultiStrassen.class: MultiStrassen.java
	$(JAVAC) MultiStrassen.java

GeneralStrassen.class: GeneralStrassen.java
	$(JAVAC) GeneralStrassen.java

StrassenNetz.class: StrassenNetz.java
	$(JAVAC) StrassenNetz.java

QSort.class: QSort.java
	$(JAVAC) QSort.java

BBBike.class: BBBike.java
	$(JAVAC) BBBike.java

TestBBBike.class: TestBBBike.java
	$(JAVAC) TestBBBike.java

MyCanvas.class: MyCanvas.java
	$(JAVAC) MyCanvas.java

CanvasProp.class: CanvasProp.java
	$(JAVAC) CanvasProp.java

Kreuzungen.class: Kreuzungen.java
	$(JAVAC) Kreuzungen.java

test:	all
	$(JAVA) BBBike -v

clean:
	rm *.class

bbbike.jar:	all
	jar cfm bbbike.jar Manifest.txt *.class -C .. data/strassen 
