// (c) 1998 Slaven Rezic

import java.lang.Integer;
import java.lang.StringBuffer;
import java.util.Enumeration;
import java.util.Hashtable;
import java.util.StringTokenizer;
import java.util.Vector;
import java.io.File;
import java.io.RandomAccessFile;
import java.io.EOFException;
import java.io.FileNotFoundException;
import java.io.InputStream;

class Strassen implements GeneralStrassen {
  public final Vector datadirs = new Vector();

  boolean verbose = false;

  Vector Data = new Vector();
  int Pos = 0;
  // Koord

  void initObject (File filename) throws FileNotFoundException {
    // Try first to read from jar
    if (verbose) System.err.println("Try first to read from jar...");
    InputStream is = Strassen.class.getClassLoader().getResourceAsStream("data/" + filename.getName());
    if (is != null) {
      boolean success = false;
      try {
	byte[] buf = new byte[1];
	StringBuffer sb = new StringBuffer();
	while (true) {
	  int len = is.read(buf);
	  if (len == -1) break;
	  if (buf[0] == 10) {
	    String s = sb.toString();
	    if (verbose) {
	      System.err.println(s);
	    }
	    if (!s.startsWith("#")) { // not a comment
	      Data.addElement(s);
	    }
	    sb = new StringBuffer();
	  } else {
	    sb.append((char)buf[0]);
	  }
	}
	success = true;
      } catch (Exception e) {
	System.err.println(e);
      }
      if (success) return;
    }

    // Fallback to filesystem
    if (verbose) System.err.println("Fallback to filesystem...");

    // XXX eigentlich static
    //datadirs.addElement(new File("/home/e/eserte/src/bbbike/data"));
    datadirs.addElement(new File("../data"));
    datadirs.addElement(new File("./data"));
    //datadirs.addElement(new File("/usr/local/BBBike/data"));

    Vector filenames = new Vector();

    for (Enumeration e = datadirs.elements() ; e.hasMoreElements() ;) {
      filenames.addElement(new File(e.nextElement().toString(),
				    filename.toString()));
    }

    RandomAccessFile B = null;
    for (Enumeration e = filenames.elements() ; e.hasMoreElements() ;) {
      File f = (File)e.nextElement();
      if (f.canRead()) {
	try {
	  B = new RandomAccessFile(f, "r");
	  while (true) {
	    String s = B.readLine();
	    if (s == null) break;
	    if (s.startsWith("#")) continue; // comments and directives
	    Data.addElement(s);
	  }
	} catch (EOFException ex) {
	  break;
	} catch (Exception ex) {
	  // try next one
	}
      }
    }

    if (B == null) {
      if (verbose) System.err.println("No file found.");
      throw new FileNotFoundException("Tried all datadirs");
    }
  }

  public Strassen (File filename) throws FileNotFoundException { // XXX $koord fehlt
    initObject(filename);
  }

  public Strassen (File filename, boolean aVerbose) throws FileNotFoundException {
    verbose = aVerbose;
    initObject(filename);
  }

  public Strasse get (int pos) {
    String line;
    Strasse result = new Strasse();
    try {
      //        if (pos > 20) { throw new Exception("TEST XXXXXXXXXXXXXXXXXXXXXXXXX"); }
      line = (String)Data.elementAt(pos);
    } catch (Exception e) {
      result.Name = null;
      result.Kreuzungen = new Vector();
      result.Category = null;
      return result;
    }
    StringTokenizer st = new StringTokenizer(line, "\t");
    String name = st.nextToken();
    String rest = st.nextToken();
    st = new StringTokenizer(rest, " ");
    String category = st.nextToken();
    Vector koord = new Vector();
    while(st.hasMoreTokens()) {
      koord.addElement(st.nextToken());
    }
    result.Name = name;
    result.Kreuzungen = koord; // XXX `X' wird nicht überlesen
    result.Category = category;
    return result;
  }

  public void init () {
    Pos = -1;
  }

  public Strasse first () {
    Pos = 0;
    return get(0);
  }

  public Strasse next () {
    return get(++Pos);
  }

  public Strasse next2 () { return new Strasse(); } // NYI

  public boolean at_end () {
    return Pos >= Data.size(); // XXX >= oder > ???
  }

  public int count () {
    return Data.size();
  }

  public int pos () {
    return Pos;
  }

  public Vector to_koord (Vector in) { 
    Vector out = new Vector();
    for (Enumeration e = in.elements() ; e.hasMoreElements() ;) {
      String s = (String)e.nextElement();
      //System.err.println(s.substring(0, s.length()));
      StringTokenizer st = new StringTokenizer(s.substring(0, s.length()),
					       ",");
      Vector koord = new Vector();
      koord.addElement(new Integer(st.nextToken()));
      koord.addElement(new Integer(st.nextToken()));
      out.addElement(koord);
    }
    return out;
  }

  public int[] to_koord1 (String s) { // XXX siehe to_koord
    int[] koord = new int[2];
    StringTokenizer st = new StringTokenizer(s.substring(0, s.length()),
					     ",");
    koord[0] = Integer.parseInt(st.nextToken());
    koord[1] = Integer.parseInt(st.nextToken());
    return koord;
  }

  public Hashtable all_crossings_hash() {
    if (verbose) System.err.println("Creating hash for all crossings...");
    Hashtable crossings = new Hashtable();
    init();
    while(true) {
      Strasse ret = next();
      String name = ret.Name;
      Vector kreuzungen = ret.Kreuzungen;
      if (kreuzungen.isEmpty()) break;
      Vector kreuz_coord = to_koord(kreuzungen);
      for (Enumeration e = kreuz_coord.elements() ; e.hasMoreElements() ;) {
	Vector i = (Vector)e.nextElement();
	String xy = i.elementAt(0) + "," + i.elementAt(1); // XXX ???
	if (!crossings.containsKey(xy)) {
	  crossings.put(xy, new Integer(1));
	} else {
	  crossings.put(xy,
			new Integer(((Integer)crossings.get(xy)).intValue()
				    + 1));
	}
      }
    }
    return crossings;
  }

  public Vector all_crossings () {
    if (verbose) System.err.println("Creating all crossings...");
    Hashtable crossings = new Hashtable();
    Hashtable crossing_name = new Hashtable();
    init();
    while(true) {
      Strasse ret = next();
      String name = ret.Name;
      Vector kreuzungen = ret.Kreuzungen;
      if (kreuzungen.isEmpty()) break;
      Vector kreuz_coord = to_koord(kreuzungen);
      for (Enumeration e = kreuz_coord.elements() ; e.hasMoreElements() ;) {
	Vector i = (Vector)e.nextElement();
	String xy = i.elementAt(0) + "," + i.elementAt(1); // XXX ???
	if (!crossings.containsKey(xy)) {
	  crossings.put(xy, new Integer(1));
	} else {
	  crossings.put(xy,
			new Integer(((Integer)crossings.get(xy)).intValue()
				    + 1));
	}
	boolean brk = false;
	if (crossing_name.containsKey(xy)) {
	  for (Enumeration e2 = ((Vector)crossing_name.get(xy)).elements();
	       e2.hasMoreElements() ;) {
	    String test = (String)e2.nextElement();
	    if (test.equals(name)) {
	      brk = true;
	      break;
	    }
	  }
	} else {
	  crossing_name.put(xy, new Vector());
	}
	if (!brk) {
	  Vector old = (Vector)crossing_name.get(xy);
	  old.addElement(name);
	  crossing_name.put(xy, old);
	}
      }
    }

    Vector crossingsVec = new Vector();
    for (Enumeration e = crossings.keys(); e.hasMoreElements(); ) {
      String k = (String)e.nextElement();
      int v = ((Integer)crossings.get(k)).intValue();
      if (v > 1) {
	StringTokenizer st = new StringTokenizer(k, ",");
	int x = Integer.parseInt(st.nextToken());
	int y = Integer.parseInt(st.nextToken());
	Vector elem = new Vector();
	elem.addElement(new Integer(x));
	elem.addElement(new Integer(y));
	String kreuzung_name = new String("");
	for (Enumeration e2 = ((Vector)crossing_name.get(k)).elements();
	     e2.hasMoreElements(); ) {
	  String nextName = (String)e2.nextElement();
	  kreuzung_name = kreuzung_name.concat(nextName);
	  if (e2.hasMoreElements()) {
	    kreuzung_name = kreuzung_name.concat("/");
	  }
	}
	elem.addElement(kreuzung_name);
	crossingsVec.addElement(elem);
      }
    }
    return crossingsVec;

  }

}

// Local variables:
// c-basic-offset: 2
// End:
