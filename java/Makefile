#
# $Id: Makefile,v 1.5 1999/09/07 08:22:54 eserte Exp $
#

JAVAROOT?=/usr/lib/java

DEBUG=	-g

JAVAC=$(JAVAROOT)/bin/javac -deprecation $(DEBUG)
JAVA=$(JAVAROOT)/bin/java

all:	Strasse.class \
	Strassen.class MultiStrassen.class GeneralStrassen.class \
	StrassenNetz.class QSort.class BBBike.class MyCanvas.class \
	TestBBBike.class

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

test:	all
	$(JAVA) BBBike -v

clean:
	rm *.class
