/* $Id: BBBike.java,v 1.4 1999/02/20 16:36:04 eserte Exp $ */

import java.util.Enumeration;
import java.util.Hashtable;
import java.util.Vector;
import java.awt.Color;
import java.awt.Component;
import java.awt.Event;
import java.awt.Frame;
import java.awt.Graphics;
import java.awt.BorderLayout;
import java.awt.Panel;
import java.awt.Scrollbar;
import java.io.*;
import MyCanvas;
import Strassen;

class BBBike {

  Frame top;
  MyCanvas c;
  Hashtable str_draw = new Hashtable();
  int scale = 2;
  boolean verbose = false; // debugging

  public BBBike() {
    init();
  }

  public BBBike(boolean verbose) {
    this.verbose = verbose;
    init();
  }

  private void init() {
    top = new Frame("BBBike $Revision: 1.4 $");
    top.setLayout(new BorderLayout());
    c = new MyCanvas();
    try {
      plotstr();
    } catch (FileNotFoundException e) {
      System.err.println("File not found, Exception caught: " + e);
    } catch (Exception e) {
      System.err.println("Exception caught: " + e);
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

    top.resize(1000, 700);
    top.show();
  }

  public void plotstr() throws FileNotFoundException { // throws Exception { // File filename, String abk) {
    // XXXstatus_message("");

    /*    if (!str_draw.containsKey(abk))
	return;
	*/

    Strassen str = new Strassen();
    str.init();
    //int debugi = 0;
    while(true) {
      //if (debugi++>100) break;
      Strasse ret = str.next();
      Vector kreuzungen = ret.Kreuzungen;
      if (kreuzungen.isEmpty()) break;
      if (verbose)
	System.err.println(ret.Name);
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
      else
	prop.put(CanvasProp.FILL, Color.white);
      prop.put(CanvasProp.WIDTH, new Integer(5));
      c.createLine(transformed, prop);
    }
    if (verbose)
      System.err.println();
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
}

class MyScrollbar extends Scrollbar {
  MyCanvas parent;

  public MyScrollbar(MyCanvas p,
		     int a, int b, int c, int d, int e) {
    super(a,b,c,d,e);
    parent = p;
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
