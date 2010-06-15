The images are (will be) used in BBBikeGPS.pm. The file naming is
stupid: it depends on the localization of the device!

Upload instructions:

* Get the xImage program from Garmin. At the time of writing, it can
  be found here: http://www8.garmin.com/support/agree.jsp?id=545

* Install it (sorry, Windows only) and start it.

* Select "Get images from the GPS" and then the Image type for the
  waypoint symbols (this label is already localized).

* Select all images and download them. Now you should have files
  named like "Simbol tocke 001.bmp" (depending on the localization) on
  your hard disk.

* Rename the images in the bike2008 subdirectory to match the
  localized file names. I do this automatically like this:

    rsync -a bike2008/ /tmp/bike2008/
    cd /tmp/bike2008/
    rename 's/^/Simbol tocke /' *.bmp

* Put these files in place of the downloaded ones.

* Now start again xImage. This time use "Send images to the GPS".
  Again select the same image type, and select all images. Finish the
  upload.

----------------------------------------------------------------------
Current bike2008 bmps in order, as HCx matrix

---- ---- ---- ---- ---- ----
LSA  BU   RW1  RW0  KS   Q3
LSAF VF   VG   AS   BR   +BR
VS   NN   N    RW2  BT   ZS
ST   GF   WW   PW   FW   free

----------------------------------------------------------------------
Some thoughts for re-ordering the waypoint set

Penalties for entering
LSA   0 (may be red, but usually point is taken after stop)
BU    0 (may be closed, rarely, but usually point is taken after stop)
RW1   0
RW0   0
KS   +1 (because of street quality)
Q3   +2 (because of bad street quality)
LSAF  0 (rarely red)
VF    0
VG    0
AS    0
BR    0
+BR   0
VS    0
NN    0
N     0
RW2   0
BT    0
ZS    0
ST   -2 (slow driving)
GF   +2 (possibly fast driving)
WW   +1 (possibly street quality bad)
PW   +1 (possibly street quality bad)
FW   +1 (possibly street quality bad)

Subjective importance
LSA  +1 (for completeness in Berlin)
BU   +1 (for completeness)
RW1  +2
RW0  +2
KS   +3
Q3   +3
LSAF +1
VF    0
VG   -2 (never used so far)
AS   +2 (lower than KS/Q3 because it's standard)
BR   -1 (easily determined afterwards)
+BR  -1
VS   +2
NN   +2
N    +2
RW2  +2
BT   +2
ZS   -1 (for completeness in Berlin, not used in bbbike data)
ST   +2
GF   +2
WW   +3
PW   +3
FW   +3

Distance model for the matrix
* use the Manhatten distance
* use +1 for every direction change
* the right symbols in the first row may be accessed using the left key
  use the Manhatten distance for this path, but add +1

Possible pairs:
* RW1+RW2
* KS+Q3
* AS+BT (and maybe also BT+PW?)
* LSA+LSAF
* FW+WW

TODO:
* calculate Haeufigkeiten of existing Waypoint symbols
