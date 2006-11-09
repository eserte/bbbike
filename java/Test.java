//import QSort;
import java.util.Vector;
import java.util.Enumeration;
//import Strassen;

class Test {

  public static void main(String argv[]) {
    /*    Properties prop = System.getProperties();
	  prop.list(System.err);
    */
    /*
    StringTokenizer st = new StringTokenizer(argv[0], ",");
    while (st.hasMoreElements()) {
      System.out.println(st.nextToken()); //.toString(),
    }
    */
    try {
      Strassen str = new Strassen();
      Vector crossings = str.all_crossings();
      for(Enumeration e = crossings.elements(); e.hasMoreElements(); ) {
	Vector crossing = (Vector)e.nextElement();
	System.out.print(crossing.elementAt(2));
	System.out.print(" ");
	System.out.print(crossing.elementAt(0));
	System.out.print("/");
	System.out.print(crossing.elementAt(1));
	System.out.println();
      }
      /*
      str.init();
      while(true) {
	Vector ret = str.next();
	Vector koords = (Vector)ret.elementAt(1);
	if (koords.isEmpty()) { break; }
	System.out.print(ret.elementAt(0));
	System.out.print(" ");
	System.out.print(ret.elementAt(2));
	System.out.print(" ");
	Vector koords2 = str.to_koord(koords);
	for (Enumeration e = koords2.elements() ; e.hasMoreElements() ;) {
	  Vector xy = (Vector)e.nextElement();
	  System.out.print("(");
	  System.out.print(xy.elementAt(0));
	  System.out.print(",");
	  System.out.print(xy.elementAt(1));
	  System.out.print(") ");
	}
	System.out.println();
      }
      */
    } catch (Exception e) {
      System.err.println("Exception!");
    }
    
  }

  /*
  public static void main(String argv[]) throws Exception {
        System.out.println(argv[0].substring(0, 2));
    String bla = new String("bla");
    String foo = new String("foo");
    bla.concat(foo);
    String xxx = foo.concat(bla);
    System.out.println(bla);
    System.out.println(foo);
    System.out.println(xxx);
    
    Vector s = new Vector();
    int i;
    for(i = 0; i < argv.length; i++) {
      Vector x = new Vector();
      x.addElement(new Integer(i));
      x.addElement(new Double(argv[i]));
      s.addElement(x);
    }
    Vector t = new Vector();
    t = (Vector)s.clone();

    QSort.sort(t, 1);

    for(i = 0; i < t.size(); i++) {
      System.out.print(((Vector)t.elementAt(i)).elementAt(1));
      System.out.print(" ");
      System.out.print(((Vector)t.elementAt(i)).elementAt(0));
      System.out.println();
    }

  }
*/
}

// Local variables:
// c-basic-offset: 2
// End:
