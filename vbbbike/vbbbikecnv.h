// -*- C++ -*-
//	vbbbikecnv.h:	Header for vbbbikeCanvasPane class
//=======================================================================

#ifndef vbbbikeCNV_H
#define vbbbikeCNV_H

#include <v/vcanvas.h>

class CanvasLineItem
{
  friend class vbbbikeCanvasPane;
  friend class CanvasLineItemList;

  int x1,y1,x2,y2;

  CanvasLineItem() { }
  CanvasLineItem(int xx1, int yy1, int xx2, int yy2) {
    x1 = xx1;
    y1 = yy1;
    x2 = xx2;
    y2 = yy2;
  }
  void set(int xx1, int yy1, int xx2, int yy2) {
    x1 = xx1;
    y1 = yy1;
    x2 = xx2;
    y2 = yy2;
  }

};

class CanvasLineItemList
{
public:
  CanvasLineItem **list;
  int count;
};

//----------------------------------------------------------------------

class CanvasAreaItem
{
  friend class vbbbikeCanvasPane;
  friend class CanvasAreaItemList;

  vPoint *points;
  int no;
  int minx, maxx, miny, maxy;

private:
  int currCount;

protected:
  CanvasAreaItem() {
    no = 0;
    points = NULL;
  }
  ~CanvasAreaItem() {
    if (points) delete points;
  }

  void elements(int count) {
    points    = new vPoint[count];
    currCount = 0;
    no = count;
  }
  void add(int xx1, int yy1) {
    points[currCount].x = xx1;
    points[currCount].y = yy1;
    if (currCount == 0) {
      minx = maxx = xx1;
      miny = maxy = yy1;
    } else {
      if (minx > xx1) minx = xx1;
      if (maxx < xx1) maxx = xx1;
      if (miny > yy1) miny = yy1;
      if (maxy < yy1) maxy = yy1;
    }
    currCount++;
  }

};

class CanvasAreaItemList
{
public:
  CanvasAreaItem **list;
  int count;
};

//----------------------------------------------------------------------

class vbbbikeCanvasPane : public vCanvasPane
{
public:		//---------------------------------------- public
  vbbbikeCanvasPane();
  virtual ~vbbbikeCanvasPane();

  // Scrolling
  virtual void HPage(int shown, int top);
  virtual void VPage(int shown, int top);
  
  virtual void HScroll(int step);
  virtual void VScroll(int step);

  // Events
  virtual void MouseDown(int x, int y, int button);
  virtual void MouseUp(int x, int y, int button);
  virtual void MouseMove(int x, int y, int button);

  virtual void Redraw(int x, int y, int width, int height);
  virtual void doRedraw(int x, int y, int width, int height);
  virtual void Resize(int newW, int newH);

protected:	//--------------------------------------- protected

private:		//--------------------------------------- private
  enum { // sort by display order
    Xitem,

    BUitem,
    Witem,
    Fitem,
    INitem,
    HBitem,

    UAitem,
    UBitem,

    SAitem,
    SBitem,
    SCitem,

    NNitem,
    Nitem,
    NHitem,
    Hitem,
    HHitem,
    BABitem,

    MAXitem = 15, // set this to last item

    areaMask = 0x1000,
    catMask  = 0x0fff
  };

  CanvasLineItemList LineItemList[MAXitem+1];
  CanvasAreaItemList AreaItemList[MAXitem+1];

  void convertData();
  inline int getCategory(char* catStr);
  void adjust(int& X, int& Y);
  void getDelta(int& dx, int& dy);
  void drawRoute();

  int dx;
  int dy;
  double zoom;

  enum {
    minx = -1270, /* -10849 in Hafas-Koordinaten */
    maxx =  2400, /*  34867 in Hafas-Koordinaten */
    miny = -1210, /*  30083 in Hafas-Koordinaten */
    maxy =  1778 /*  -7234 in Hafas-Koordinaten */
  };

  enum {
    x0 = -minx,
    y0 = -miny,
    xm = (maxx-minx)/100,
    ym = (maxy-miny)/100
  };

  vColor grey;

  vPen whitePen;
  vPen blackPen;
  vPen greenPen;
  vPen yellowPen;
  vPen darkYellowPen;
  vPen bluePen;
  vPen green3Pen;
  vPen green4Pen;
  vPen blue4Pen;
  vPen lightBluePen;
  vPen parkGreenPen;
  vPen buPen;
  vPen harbourPen;
  vPen industrialPen;

  vBrush blueBrush, lightBlueBrush, whiteBrush, parkGreenBrush, buBrush;
  vBrush harbourBrush, industrialBrush;

};
#endif
