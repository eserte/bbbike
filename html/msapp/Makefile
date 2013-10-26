BBBIKE_IMAGES=../../images

all: browserconfig-files

browserconfig-files: browserconfig_cgilayout.xml browserconfig_bbbikelayout.xml

browserconfig_cgilayout.xml: browserconfig.tpl.xml
	tpage --define images_dir=/BBBike/html/msapp browserconfig.tpl.xml > browserconfig_cgilayout.xml~
	chmod 644 browserconfig_cgilayout.xml~
	mv browserconfig_cgilayout.xml~ browserconfig_cgilayout.xml

browserconfig_bbbikelayout.xml: browserconfig.tpl.xml
	tpage --define images_dir=/bbbike/html/msapp browserconfig.tpl.xml > browserconfig_bbbikelayout.xml~
	chmod 644 browserconfig_bbbikelayout.xml~
	mv browserconfig_bbbikelayout.xml~ browserconfig_bbbikelayout.xml

image-files: srtbike_logo_128x128.png srtbike_logo_270x270.png

srtbike_logo_128x128.png: ${BBBIKE_IMAGES}/srtbike_logo.svg
	convert -bordercolor none -background none -border 40x40 -density 256 -geometry 128x128 images/srtbike_logo.svg html/images/srtbike_logo_128x128.png

srtbike_logo_270x270.png: ${BBBIKE_IMAGES}/srtbike_logo.svg
	convert -bordercolor none -background none -border 80x80 -density 540 -geometry 270x245 -extent 270x270 -gravity north images/srtbike_logo.svg html/images/srtbike_logo_270x270.png
