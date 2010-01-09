/* $Id: BBBike.java,v 1.10 2008/12/31 16:49:12 eserte Exp $ */

import java.util.Enumeration;
import java.util.Hashtable;
import java.util.Vector;

import java.awt.*;
import java.awt.event.*;

import java.io.*;
//import MyCanvas;
//import Strassen;

class BBBike {

  Frame top;
  MyCanvas c;
  Hashtable str_draw = new Hashtable();
  int scale = 2;
  boolean verbose = false; // debugging
  StrassenNetz str_net;
  Kreuzungen crossings;
  String start_xy;
  String goal_xy;

  public BBBike() {
    init();
  }

  public BBBike(boolean verbose) {
    this.verbose = verbose;
    init();
  }

  private void init() {
/*
    GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment();
    GraphicsDevice gd = ge.getDefaultScreenDevice();
    GraphicsConfiguration gc = gd.getDefaultConfiguration();
    Rectangle bounds = gc.getBounds();
*/

    top = new Frame("BBBike $Revision: 1.10 $");
    top.setLayout(new BorderLayout());
    c = new MyCanvas(this);
    try {
      plotstr();
    } catch (FileNotFoundException e) {
      System.err.println("In plotstr: File not found, Exception caught: " + e);
    } catch (Exception e) {
      System.err.println("In plotstr: Exception caught: " + e);
    }

    top.add("Center", c);

    // Unter den Linden/Friedrichstr.:
    int berlin_mitte_x = 9349;
    int berlin_mitte_y = 12344;
    int[] berlin_mitte_txy = transpose(berlin_mitte_x, berlin_mitte_y);

    //berlin_mitte_txy[0] = 0;
    //berlin_mitte_txy[1] = 0;
System.err.println("x/y=" + berlin_mitte_txy[0] + "/" + berlin_mitte_txy[1]);

    MyScrollbar scrollH = new MyScrollbar(c,
					  Scrollbar.HORIZONTAL,
					  500, berlin_mitte_txy[0], -4000, 4000);
    MyScrollbar scrollV = new MyScrollbar(c,
					  Scrollbar.VERTICAL,
					  350, berlin_mitte_txy[1], -4000, 4000);

    top.add("East", scrollV);
    top.add("South", scrollH);

/*
    top.setSize(bounds.width, bounds.height);
*/
    top.setSize(200,250);
    top.show();

    top.addWindowListener(new WindowAdapter() {
        public void windowClosing(WindowEvent we) {
          System.exit(0);
        }
      });
  }

  public void plotstr() throws FileNotFoundException { // throws Exception { // File filename, String abk) {
    // XXXstatus_message("");

    /*    if (!str_draw.containsKey(abk))
	return;
	*/

    if (verbose) System.err.println("Trying to load strassen...");
    Strassen str = new Strassen(new File("strassen"), verbose);
    if (verbose) System.err.println("... OK");
    str.init();
    //int debugi = 0;
    if (verbose) System.err.println("Starting plotting streets...");
    while(true) {
      //if(debugi++>100)break;
      Strasse ret = str.next();
      Vector kreuzungen = ret.Kreuzungen;
      if (kreuzungen.isEmpty()) break;
      if (verbose) System.err.println(ret.Name);
      Vector transformed = new Vector();
      for(int i = 0; i < kreuzungen.size(); i++) {
        int[] koord = str.to_koord1((String)kreuzungen.elementAt(i));
        int[] res = transpose(koord[0], koord[1]);
	transformed.addElement(new Integer(res[0]));
	transformed.addElement(new Integer(res[1]));
      }
      CanvasProp prop = new CanvasProp();
      if (ret.Category.equals("H"))
	prop.put(CanvasProp.FILL, Color.yellow);
      else if (ret.Category.equals("HH"))
	prop.put(CanvasProp.FILL, new Color(238,238,0));
      else if (ret.Category.equals("NN"))
	prop.put(CanvasProp.FILL, Color.green);
      else if (ret.Category.equals("NH"))
	prop.put(CanvasProp.FILL, Color.white);
      else
	prop.put(CanvasProp.FILL, Color.white);
      prop.put(CanvasProp.WIDTH, new Integer(5));
      c.createLine(transformed, prop);
    }
    if (verbose) System.err.println();

    if (verbose) System.err.println("Making net...");
    str_net = new StrassenNetz(str);
    str_net.verbose = verbose;
    str_net.make_net();
    crossings = new Kreuzungen(str.all_crossings_hash());
    if (verbose) System.err.println("Finished plotstr");

  }

  public int[] transpose (int x, int y) {
    int[] res = new int[2];
    res[0] = (-200+x/25)*scale;
    res[1] = ( 600-y/25)*scale;
    return res;
  }

  public int[] anti_transpose (int x, int y) {
    int[] res = new int[2];
    res[0] = (x/scale+200)*25;
    res[1] = (600-y/scale)*25;
    return res;
  }

  public static void main(String argv[]) {
    boolean verbose = (argv.length > 0 && argv[0].equals("-v"));
    BBBike bbbike = new BBBike(verbose);
  }

  public void mouseClicked(int cx, int cy) throws Exception {
    int[] xy = anti_transpose(cx, cy);
    Vector res = crossings.nearest(xy[0], xy[1]);
    if (!res.isEmpty()) {
      if (start_xy == null) {
	start_xy = (String)res.elementAt(0);
      } else {
	goal_xy = (String)res.elementAt(0);
	Vector route = str_net.search_Astar(start_xy, goal_xy);
	drawRoute(route);
	start_xy = null;
      }
    }
  }

  public void drawRoute(Vector route) {
    Enumeration e_route = route.elements();
    if (!e_route.hasMoreElements())
      return;
    deleteOldRoute();
    String first = (String)e_route.nextElement();
    int comma_index = first.indexOf(',');
    int first_x = Integer.parseInt(first.substring(0, comma_index));
    int first_y =  Integer.parseInt(first.substring(comma_index+1));
    int[] cxy1 = transpose(first_x, first_y);
    for(; e_route.hasMoreElements(); ) {
      String next = (String)e_route.nextElement();
      comma_index = next.indexOf(',');
      int next_x = Integer.parseInt(next.substring(0, comma_index));
      int next_y = Integer.parseInt(next.substring(comma_index+1));
      int[] cxy2 = transpose(next_x, next_y);
      Vector lineCoords = new Vector(4);
      lineCoords.addElement(new Integer(cxy1[0]));
      lineCoords.addElement(new Integer(cxy1[1]));
      lineCoords.addElement(new Integer(cxy2[0]));
      lineCoords.addElement(new Integer(cxy2[1]));
      CanvasProp prop = new CanvasProp();
      prop.put(CanvasProp.FILL, Color.red);
      prop.put(CanvasProp.WIDTH, new Integer(7));
      prop.put(CanvasProp.TAG, "route");
      c.createLine(lineCoords, prop);

      cxy1 = cxy2;
    }
    c.repaint();
  }

  public void deleteOldRoute() {
    c.deleteByTag("route");
  }
}

class MyScrollbar extends Scrollbar {
  MyCanvas parent;

  public MyScrollbar(MyCanvas p,
		     int a, int b, int c, int d, int e) {
    super(a,b,c,d,e);
    parent = p;
    setUnitIncrement(30);
  }

  public boolean handleEvent(Event evt) {
    if (getOrientation() == HORIZONTAL)
      parent.hpos = getValue();
    else
      parent.vpos = getValue();
    parent.repaint();
    //    System.out.println(getValue());
    return true;
  }
}

// Local variables:
// c-basic-offset: 2
// tab-width: 8
// End:
