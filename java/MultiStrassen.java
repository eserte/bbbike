// (c) 1998 Slaven Rezic

import java.lang.Class;
import java.lang.Error;
import java.util.Vector;
import java.util.Enumeration;
import java.io.FileNotFoundException;
//import Strassen;

/* XXX Note that with jdk 1.5 this throws the warning

   MultiStrassen.java:19: warning: [unchecked] unchecked call to addElement(E) as a member of the raw type java.util.Vector
           Data.addElement(e2.nextElement());

   The fix is to use generics (but this is probably not backward compatible).
   See http://forums.sun.com/thread.jspa?threadID=584311
*/

class MultiStrassen extends Strassen {
  public MultiStrassen (Vector obj) throws Error, FileNotFoundException {
    for(Enumeration e = obj.elements(); e.hasMoreElements(); ) {
      Object o = e.nextElement();
      if (!o.getClass().getName().equals("Strassen")) {
	throw new Error("Object is not from type Strassen");
      }
      for(Enumeration e2 = ((Strassen)o).Data.elements();
	  e2.hasMoreElements(); ) {
	Data.addElement(e2.nextElement());
      }
    }
  }
}

// Local variables:
// c-basic-offset: 2
// tab-width: 8
// End:
