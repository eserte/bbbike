// (c) 1998 Slaven Rezic

import java.lang.Class;
import java.lang.Error;
import java.util.Vector;
import java.util.Enumeration;
import java.io.FileNotFoundException;
//import Strassen;

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
// End:
