# -*- perl -*-

#
# $Id: Inline.pm,v 1.9 2003/01/08 20:59:20 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package VectorUtil::Inline;

BEGIN {
    $VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);
}

use Inline 0.40; # because of API changes
use Config;
use Inline C => Config => CCFLAGS => "-O2";
use Inline Config => CLEAN_AFTER_BUILD => 0;   #XXX debugging, both needed
use Inline C => Config => CCFLAGS => "-g -O2"; #XXX debugging
use Inline (C => DATA =>
	    NAME => 'VectorUtil::Inline',
	    VERSION => $VERSION,
	   );

# XXX POINT should be a hidden perl/C object...
# return POINT buffer and number of points
sub array_to_POINT {
    my(@a) = @_;
    my $sizeof = sizeof_POINT();
    if ($sizeof != length(pack("ii",0,0))) {
	die "This architecture is not supported (yet)";
    }
    if (@a % 2 != 0) {
	die "Must be even number of points";
    }
    my $points = @a / 2;
    my $buf = "";
    for (@a) {
	$buf .= pack("i", $_);
    }
    ($buf, $points);
}

1;

__DATA__
__C__

typedef struct { int x; int y; } POINT;

#define MIN(x,y) (x < y ? x : y)
#define MAX(x,y) (x > y ? x : y)

#include <math.h>

double distance_point_line(double px, double py,
			   double s0x, double s0y,
			   double s1x, double s1y) {
    double sxd = s1x-s0x;
    double syd = s1y-s0y;
    double tf, nx, ny;
    if (sxd+syd==0) { /* line is really a point */
	return hypot(px-s0x, py-s0y);
    }
    tf = ((px-s0x)*(s1x-s0x) + (py-s0y)*(s1y-s0y)) /
	(sxd*sxd + syd*syd);
    /* nx/ny: nearest point on line */
    nx = s0x+tf*sxd;
    ny = s0y+tf*syd;
    if (((nx >= s0x && nx <= s1x) || (nx >= s1x && nx <= s0x))
	&&
	((ny >= s0y && ny <= s1y) || (ny >= s1y && ny <= s0y))
       ) {
	return hypot(s0x-px+tf*sxd, s0y-py+tf*syd);
    } else {
	/* nearest point is out of line ... check the endpoints of the line */
	double dist0 = hypot(s0x-px, s0y-py);
	double dist1 = hypot(s1x-px, s1y-py);
	if (dist0 < dist1) {
	    return dist0;
	} else {
	    return dist1;
	}
    }
}

int sizeof_POINT() {
  return sizeof(POINT);
}

/* http://www.exaflop.org/docs/naifgfx/naifpip.html */
/* cannot handle convex polygons */
int point_in_poly( char *poly_verts_c, int num_verts, char *test_point_c ) {
  int nx, ny, loop;
  int x, y;
  POINT *poly_verts = (POINT*)poly_verts_c;
  POINT *test_point = (POINT*)test_point_c;

  /* Clockwise order. */

  for ( loop = 0; loop < num_verts; loop++ ) {
    /*	generate a 2d normal ( no need to normalise ). */
    nx = poly_verts[ ( loop + 1 ) % num_verts ].y - poly_verts[ loop ].y;
    ny = poly_verts[ loop ].x - poly_verts[ ( loop + 1 ) % num_verts ].x;

    x = test_point->x - poly_verts[ loop ].x;
    y = test_point->y - poly_verts[ loop ].y;

    /*	Dot with edge normal to find side. */
    if ( ( x * nx ) + ( y * ny ) > 0 )
      return 0;
  }

  return 1;
}

/* http://astronomy.swin.edu.au/~pbourke/geometry/insidepoly/ */
int InsidePolygon(char *polygon_c,int N,char *p_c)
{
  int counter = 0;
  int i;
  double xinters;
  POINT p1,p2;
  POINT* polygon = (POINT*)polygon_c;
  POINT* p = (POINT*)p_c;

  p1 = polygon[0];
  for (i=1;i<=N;i++) {
    p2 = polygon[i % N];
    if (p->y > MIN(p1.y,p2.y)) {
      if (p->y <= MAX(p1.y,p2.y)) {
        if (p->x <= MAX(p1.x,p2.x)) {
          if (p1.y != p2.y) {
            xinters = (p->y-p1.y)*(p2.x-p1.x)/(p2.y-p1.y)+p1.x;
            if (p1.x == p2.x || p->x <= xinters)
              counter++;
          }
        }
      }
    }
    p1 = p2;
  }

  if (counter % 2 == 0)
    return 0;
  else
    return 1;
}

int pnpoly(char *polygon_c,int npol,char *p_c) {
  int i, j, c = 0;
  POINT* pg = (POINT*)polygon_c;
  POINT* p = (POINT*)p_c;
  int x = p->x;
  int y = p->y;
  for (i = 0, j = npol-1; i < npol; j = i++) {
    if ((((pg[i].y <= y) && (y < pg[j].y)) ||
	 ((pg[j].y <= y) && (y < pg[i].y))) &&
	(x < (pg[j].x - pg[i].x) * (y - pg[i].y) / (pg[j].y - pg[i].y) + pg[i].x))
      c = !c;
  }
  return c;
}

#define PI 3.141592653
#define TWOPI PI*2

/*
   Return the angle between two vectors on a plane
   The angle is from vector 1 to vector 2, positive anticlockwise
   The result is between -pi -> pi
*/
static double Angle2D(double x1, double y1, double x2, double y2)
{
   double dtheta,theta1,theta2;

   theta1 = atan2(y1,x1);
   theta2 = atan2(y2,x2);
   dtheta = theta2 - theta1;
   while (dtheta > PI)
      dtheta -= TWOPI;
   while (dtheta < -PI)
      dtheta += TWOPI;

   return(dtheta);
}

int InsidePolygon2(char *polygon_c,int n,char *p_c)
{
   int i;
   double angle=0;
   POINT p1,p2;
   POINT* polygon = (POINT*)polygon_c;
   POINT* p = (POINT*)p_c;

   for (i=0;i<n;i++) {
      p1.x = polygon[i].x - p->x;
      p1.y = polygon[i].y - p->y;
      p2.x = polygon[(i+1)%n].x - p->x;
      p2.y = polygon[(i+1)%n].y - p->y;
      angle += Angle2D(p1.x,p1.y,p2.x,p2.y);
   }

   if (abs(angle) < PI)
      return 0;
   else
      return 1;
}

