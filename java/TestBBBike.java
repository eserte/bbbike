/* $Id: TestBBBike.java,v 1.2 2004/03/04 23:21:28 eserte Exp $ */

import java.util.Enumeration;
import java.util.Hashtable;
import java.util.Vector;
import java.io.*;
//import Strassen;
//import StrassenNetz;

class TestBBBike {

  public static void main(String argv[]) throws Exception {
    String from, to;
    if (argv.length < 2) {
      System.err.println("Usage: from to");
      System.exit(2);
    }
    from = argv[0];
    to   = argv[1];

    Strassen str = new Strassen();
    StrassenNetz net = new StrassenNetz(str);
    net.make_net();
    net.search_Astar(from, to);
  }
}

