// (c) 1999 Slaven Rezic

import java.lang.Double;
import java.lang.Math;
import java.util.Enumeration;
import java.util.Hashtable;
import java.util.StringTokenizer;
import java.util.Vector;
import java.io.File;
import java.io.FileNotFoundException;
//import GeneralStrassen;
//import Strassen;
//import QSort;

class StrassenNetz {
  GeneralStrassen strassen;
  Hashtable Net;
  Hashtable Net2Name;
  Hashtable KoordXY;
  Vector Additional;
  Vector AdditionalNet;

  public StrassenNetz (GeneralStrassen s) {
    strassen = s;
    Additional = new Vector();
    AdditionalNet = new Vector();
  }

  public void make_net () {
    Net = new Hashtable();
    Net2Name = new Hashtable();
    KoordXY = new Hashtable();
    strassen.init();
    while(true) {
      Strasse ret = strassen.next();
      Vector kreuzungen = ret.Kreuzungen;
      if (kreuzungen.isEmpty()) break;
      Vector kreuz_coord = strassen.to_koord(kreuzungen);

      int i;
      for(i = 0; i < kreuzungen.size()-1; i++) {
	int entf = (int)(strecke((Vector)kreuz_coord.elementAt(i),
				 (Vector)kreuz_coord.elementAt(i+1)));
	
	String kreuzungen_i0 = (String)kreuzungen.elementAt(i);
	String kreuzungen_i1 = (String)kreuzungen.elementAt(i+1);

	if (!Net.containsKey(kreuzungen_i0))
	  Net.put(kreuzungen_i0, new Hashtable());
	if (!Net.containsKey(kreuzungen_i1))
	  Net.put(kreuzungen_i1, new Hashtable());

	((Hashtable)Net.get(kreuzungen_i0)).put(kreuzungen_i1,
						new Integer(entf));
	((Hashtable)Net.get(kreuzungen_i1)).put(kreuzungen_i0,
						new Integer(entf));

	if (!KoordXY.containsKey(kreuzungen_i0))
	  KoordXY.put(kreuzungen_i0, kreuz_coord.elementAt(i));

	if (!Net2Name.containsKey(kreuzungen_i0))
	  Net2Name.put(kreuzungen_i0, new Hashtable());
	((Hashtable)Net2Name.get(kreuzungen_i0)).put
	  (kreuzungen_i1, new Integer(strassen.pos()));
      }
      
      // letztes i
      if (!KoordXY.containsKey(kreuzungen.elementAt(i)))
	KoordXY.put(kreuzungen.elementAt(i), kreuz_coord.elementAt(i));
      
    }
  }

  public void make_sperre (File sperre_file) throws FileNotFoundException {
    Strassen sperre_obj = new Strassen(sperre_file);
    Strasse ret = sperre_obj.first();
    while(true) {
      Vector kreuzungen = ret.Kreuzungen;
      if (kreuzungen.isEmpty()) break;
      String category = ret.Category;
      if (kreuzungen.size() == 1) {
	Hashtable hash0 = (Hashtable)Net.get(kreuzungen.elementAt(0));
	for(Enumeration e = hash0.keys(); e.hasMoreElements(); ) {
	  Object key = e.nextElement();
	  hash0.remove(key);
	  ((Hashtable)Net.get(key)).remove(kreuzungen.elementAt(0));
	  KoordXY.remove(kreuzungen.elementAt(0));
	}
      } else {
	int i;
	for(i = 0; i < kreuzungen.size()-1; i++) {
	  ((Hashtable)Net.get(kreuzungen.elementAt(i)))
	    .remove(kreuzungen.elementAt(i+1));
	  if (category.substring(0, 1).equals("2"))
	    ((Hashtable)Net.get(kreuzungen.elementAt(i+1)))
	      .remove(kreuzungen.elementAt(i));
	}
      }
      ret = sperre_obj.next();
    }
  }

  public void reset() {
    del_add_net();
  }

  public Vector search_Astar(String from, String to) throws Exception {
    Hashtable OPEN_CLOSED = new Hashtable();
    OPEN_CLOSED.put(from, new Integer(1));
    Hashtable NODES = new Hashtable();
    {
      Vector initvec = new Vector(3);
      initvec.addElement(null);
      initvec.addElement(new Integer(0));
      initvec.addElement(new Integer(0));
      NODES.put(from, initvec);
    }

    System.err.println("Start Search...");

    while(true) {
      if (OPEN_CLOSED.size() == 0) { // XXX stimmt nicht
	System.out.println("Nothing found!");
	return new Vector();
      }

      int min_node_f = 999999999;
      String min_node = "";

      for (Enumeration k = OPEN_CLOSED.keys(); k.hasMoreElements() ;) {
	String key = (String)k.nextElement();
	if (((Integer)(OPEN_CLOSED.get(key))).intValue() == 1) {
	  if (((Integer)((Vector)(NODES.get(key))).elementAt(2)).intValue()
	      < min_node_f) {
	    min_node = key;
	    min_node_f = 
	      ((Integer)((Vector)NODES.get(key)).elementAt(2)).intValue();
	  }
	}
      }
      OPEN_CLOSED.put(min_node, new Integer(2)); // closed

      if (min_node.equals(to)) {
	System.err.println("Path found");
	int len = 0;
	while(true) {
	  if (((Vector)(NODES.get(min_node))).elementAt(0) != null) {
	    String prev_node =
	      (String)(((Vector)(NODES.get(min_node))).elementAt(0));
	    int etappe = (int)strecke_s(min_node, prev_node);
	    len += etappe;
	    System.err.println("* " + min_node + " => " + prev_node + " (" + etappe + ")");
	    min_node = prev_node;
	  } else {
	    break;
	  }
	}
	System.err.println("Length: " + len + "m");
	System.exit(2); // XXX ausgabe
      }

      for (Enumeration k = ((Hashtable)(Net.get(min_node))).keys();
	   k.hasMoreElements() ;) {
	String successor = (String)k.nextElement();

/* XXX Check auf NULL fehlt
	if ((((Vector)(NODES.get(min_node))).elementAt(0)).equals(successor))
	  continue;
	  */

	int g = ((Integer)((Vector)(NODES.get(min_node))).elementAt(1)).intValue() +
	  ((Integer)((Hashtable)(Net.get(min_node))).get(successor)).intValue();
	int f = g + (int)strecke_s(successor, to);
	
	if (!OPEN_CLOSED.containsKey(successor)) {
	  Vector succVec = new Vector(3);
	  succVec.addElement(min_node);
	  succVec.addElement(new Integer(g));
	  succVec.addElement(new Integer(f));
	  NODES.put(successor, succVec);
	  OPEN_CLOSED.put(successor, new Integer(1));
	} else {
	  if (f < ((Integer)((Vector)NODES.get(successor)).
		   elementAt(2)).intValue()) {
	    Vector succVec = new Vector(3);
	    succVec.addElement(min_node);
	    succVec.addElement(new Integer(g));
	    succVec.addElement(new Integer(f));
	    NODES.put(successor, succVec);
	    if (((Integer)(OPEN_CLOSED.get(successor))).intValue() == 2) {
	      OPEN_CLOSED.put(successor, new Integer(1));
	    }
	  }
	}
      }
    }

    //return new Vector();
  }

  public Vector search(String from, String to) throws Exception {
    if (!reachable(from) || !reachable(to))
      return new Vector();

    Vector all_paths = new Vector();
    Vector one_path_desc = new Vector();
    Vector one_path = new Vector();
    one_path.addElement(from);
    one_path_desc.addElement(one_path);
    one_path_desc.addElement(new Double(0));
    all_paths.addElement(one_path_desc);

    Vector found_paths = new Vector();
    Vector suspended_paths = new Vector();
    Hashtable visited = new Hashtable();
    visited.put(from, new Double(0));
    while(true) {
      while(!all_paths.isEmpty()) {
	Vector new_all_paths = new Vector();
	for(Enumeration e = all_paths.elements(); e.hasMoreElements(); ) {
	  Vector path_def = (Vector)e.nextElement();
	  Vector path = (Vector)path_def.elementAt(0);
	  double curr_len = ((Double)path_def.elementAt(1)).doubleValue();
	  String last_node = (String)path.elementAt(path.size()-1);
	  for(Enumeration e2 = ((Hashtable)Net.get(last_node)).keys();
	      e2.hasMoreElements(); ) {
	    Object next_node = e2.nextElement();
	    double len = ((Double)((Hashtable)Net.get(last_node))
			  .get(next_node)).doubleValue();
	    double next_node_len = len + curr_len;
	    if (visited.containsKey(next_node) &&
		next_node_len 
		>= ((Double)visited.get(next_node)).doubleValue())
	      continue;
	    visited.put(next_node, new Double(next_node_len));
	    if (next_node.equals(to)) {
	      Vector koords = new Vector();
	      for(Enumeration e3 = path.elements(); e3.hasMoreElements(); )
		koords.addElement(e3.nextElement());
	      koords.addElement(to);
	      System.err.print("Found path, len: ");
	      System.err.println(next_node_len);
	      Vector new_path_desc = new Vector();
	      new_path_desc.addElement(strassen.to_koord(koords));
	      new_path_desc.addElement(new Double(next_node_len));
	      found_paths.addElement(new_path_desc);
	      continue;
	    }
	    double virt_len = next_node_len +
	      strecke((Vector)KoordXY.get(next_node),
		      (Vector)KoordXY.get(to));
	    if (visited.containsKey(to) &&
		((Double)visited.get(to)).doubleValue() < virt_len)
	      continue;
	    Vector new_path_desc = new Vector();
	    Vector new_path = new Vector();
	    new_path = (Vector)path.clone();
	    new_path.addElement(next_node);
	    new_path_desc.addElement(new_path);
	    new_path_desc.addElement(new Double(next_node_len));
	    new_path_desc.addElement(new Double(virt_len));
	  }
	}
	all_paths = (Vector)new_all_paths.clone();
	for(Enumeration e = suspended_paths.elements(); e.hasMoreElements();)
	  all_paths.addElement(e.nextElement());
	QSort.sort(all_paths, 2);
	suspended_paths.removeAllElements();
	while (all_paths.size() > 5) {
	  suspended_paths.addElement(all_paths.elementAt(5));
	  all_paths.removeElementAt(5);
	}
      }
      if (!suspended_paths.isEmpty()) {
	all_paths.removeAllElements();
	for(int i = 0; i < 5; i++) {
	  all_paths.addElement(suspended_paths.elementAt(0));
	  suspended_paths.removeElementAt(0);
	}
	QSort.sort(all_paths, 2);
      } else {
	break;
      }
    }

    if (found_paths.isEmpty()) {
      System.err.println("Nothing found!");
      return new Vector();
    } else {
      QSort.sort(found_paths, 1);
      return (Vector)((Vector)found_paths.elementAt(0)).elementAt(0);
    }
  }

  public Vector search_via (String from, String to, Vector via)
  throws Exception {
    Vector route = new Vector();
    route.addElement(from);
    for(Enumeration e = via.elements(); e.hasMoreElements(); )
      route.addElement(e.nextElement());
    route.addElement(to);
    Vector path = new Vector();
    int i;
    for(i = 0; i < route.size()-1; i++) {
      Vector search_res = search((String)route.elementAt(i),
				 (String)route.elementAt(i+1));
      for(Enumeration e = search_res.elements(); e.hasMoreElements(); )
	path.addElement(e.nextElement());
    }
    return path;
  }

  // route_to_name NYI

  public void add_net(Vector points) {
    if (points.size() != 3)
      throw new Error("add_net: Es müssen genau drei Punkte in points sein");
    String startx = (String)((Vector)points.elementAt(0)).elementAt(0);
    String starty = (String)((Vector)points.elementAt(0)).elementAt(1);
    String starts = "(" + startx + "," + starty + ")";
    for(Enumeration e = points.elements(); e.hasMoreElements(); ) {
      Vector point = (Vector)e.nextElement();
      String x = (String)point.elementAt(0);
      String y = (String)point.elementAt(1);
      String s = "(" + x + "," + y + ")";
      if (!KoordXY.containsKey(s)) {
	Vector xy = new Vector();
	xy.addElement(x);
	xy.addElement(y);
	KoordXY.put(s, xy);
	Additional.addElement(s);
      }
      if (s.equals(starts)) continue;
      int entf = (int)(strecke((Vector)points.elementAt(0), point));
      if (!Net.containsKey(starts))
	Net.put(starts, new Hashtable());
      if (!((Hashtable)Net.get(starts)).containsKey(s)) {
	((Hashtable)Net.get(starts)).put(s, new Integer(entf));
	Vector starts_s = new Vector();
	starts_s.addElement(starts);
	starts_s.addElement(s);
	AdditionalNet.addElement(starts_s);
      }
      if (!Net.containsKey(s))
	Net.put(s, new Hashtable());
      if (!((Hashtable)Net.get(s)).containsKey(starts)) {
	((Hashtable)Net.get(s)).put(starts, new Integer(entf));
	Vector starts_s = new Vector();
	starts_s.addElement(s);
	starts_s.addElement(starts);
	AdditionalNet.addElement(starts_s);
      }
    }	
  }

  public void del_add_net() {
    for(Enumeration e = Additional.elements(); e.hasMoreElements(); ) {
      String a = (String)e.nextElement();
      KoordXY.remove(a);
    }
    for(Enumeration e = AdditionalNet.elements(); e.hasMoreElements(); ) {
      Vector b = (Vector)e.nextElement();
      if (Net.containsKey(b.elementAt(0)))
	((Hashtable)Net.get(b.elementAt(0))).remove(b.elementAt(1));
    }
    Additional.removeAllElements();
    AdditionalNet.removeAllElements();
  }

  public boolean reachable (String index) {
    if (!Net.containsKey(index)) {
      System.err.print(index);
      System.err.println(" is not reachable.");
      return false;
    }
    return true;
  }

  public static double strecke(Vector o1, Vector o2) {
    return Math.sqrt(sqr(  ((Integer)o1.elementAt(0)).intValue()
			 - ((Integer)o2.elementAt(0)).intValue()) +
		     sqr(  ((Integer)o1.elementAt(1)).intValue()
			 - ((Integer)o2.elementAt(1)).intValue()));
  }

  public static double strecke_s(String p1, String p2) {
    StringTokenizer st1 = new StringTokenizer(p1, ",");
    StringTokenizer st2 = new StringTokenizer(p2, ",");
    int p1x, p1y, p2x, p2y;
    p1x = Integer.parseInt(st1.nextToken());
    p1y = Integer.parseInt(st1.nextToken());
    p2x = Integer.parseInt(st2.nextToken());
    p2y = Integer.parseInt(st2.nextToken());
    return Math.sqrt(sqr(p1x-p2x) + sqr(p1y-p2y));
  }

  public static double sqr(double x) { return x * x; }
}
