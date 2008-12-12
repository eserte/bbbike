import java.util.Enumeration;
import java.util.Vector;
import java.awt.Color;
import java.awt.Component;
import java.awt.Graphics;
import java.awt.Canvas;
import java.awt.event.*;

class CanvasLine {
  Vector tags = new Vector();
  Vector coords = new Vector();
  CanvasProp prop = new CanvasProp();
  MyCanvas parent;

  public CanvasLine(MyCanvas p) {
    parent = p;
  }

  public Vector gettags() {
    return tags;
  }

  public boolean hastag(String tag) {
    for(Enumeration e = tags.elements(); e.hasMoreElements();) {
      if (((String)e.nextElement()).equals(tag))
	return true;
    }
    return false;
  }

  public Vector coords() {
    return coords;
  }

  public void addcoord(int x, int y) {
    tags.addElement(new Integer(x));
    tags.addElement(new Integer(y));
  }

  public void addtag(String tag) {
    tags.addElement(tag);
  }

  public void draw(Graphics g) {
    //System.err.println("hpos=" + parent.hpos + "/vpos="+parent.vpos);
    for(Enumeration e = prop.keys(); e.hasMoreElements(); ) {
      int key = ((Integer)e.nextElement()).intValue();
      switch(key) {
      case CanvasProp.FILL:
	g.setColor((Color)prop.get(key));
	break;
      case CanvasProp.WIDTH:
	// NYI
	break;
      case CanvasProp.TAG:
	// nothing to do here
	break;
      default:
	throw new Error("Unknown property key " + key);
      }
    }

    for(int i = 0; i < coords.size() - 3; i+=2) {
      //System.err.println(((Integer)coords.elementAt(i  )).intValue() + (500-parent.hpos) + " " + (((Integer)coords.elementAt(i+1)).intValue() + (350-parent.vpos)));
      g.drawLine
	(((Integer)coords.elementAt(i  )).intValue() + (500-parent.hpos),
	 ((Integer)coords.elementAt(i+1)).intValue() + (350-parent.vpos),
	 ((Integer)coords.elementAt(i+2)).intValue() + (500-parent.hpos),
	 ((Integer)coords.elementAt(i+3)).intValue() + (350-parent.vpos));
    }
  }
}

class MyCanvas extends Canvas
               implements MouseListener,
                          KeyListener {
  Vector lines = new Vector();
  Vector text  = new Vector();
  int hpos = 500; // XXX
  int vpos = 350; // XXX
  BBBike app;

  public MyCanvas() {
    init();
  }

  public MyCanvas(BBBike app_arg) {
    app = app_arg;
    init();
  }

  private void init() {
    setBackground(Color.lightGray);
    addMouseListener(this);
  }

  public void createLine(Vector coords) {
    createLine(coords, new CanvasProp());
  }

  public void createLine(Vector coords, CanvasProp prop) {
    CanvasLine l = new CanvasLine(this);
    l.coords = coords;
    l.prop = prop;
    lines.addElement(l);
  }

  public void deleteByTag(String tag) {
    for(int index = lines.size()-1; index >= 0; index--) {
      CanvasLine l = (CanvasLine)lines.get(index);
      String thisTag = (String)l.prop.get(CanvasProp.TAG);
      if (thisTag != null && thisTag.equals(tag)) {
	lines.removeElementAt(index);
      }
    }
  }

  public void paint(Graphics g) {
    g.setColor(getForeground());
    g.setPaintMode();
    for(Enumeration e = lines.elements(); e.hasMoreElements(); ) {
      CanvasLine l = (CanvasLine)e.nextElement();
      l.draw(g);
    }
  }

  public void mouseClicked(MouseEvent event) {
    try {
      int eX = event.getX();
      int eY = event.getY();
      int tX = eX - (500-hpos);
      int tY = eY - (350-vpos);
      System.err.println("pressed x="+eX+"/y="+eY +
			 " translated to x="+tX+"/y="+tY);
      app.mouseClicked(tX, tY);
    } catch (Exception e) {
      System.err.println("Caught " + e.toString());
    }
  }
  public void mousePressed(MouseEvent event) { }
  public void mouseReleased(MouseEvent event) { }
  public void mouseEntered(MouseEvent event) { }
  public void mouseExited(MouseEvent event) { }

  public void keyPressed(KeyEvent e) {
    int code = e.getKeyCode();
    int newHpos = hpos, newVpos = vpos;

    if (e.getKeyChar() == 'q')
      System.exit(0);
    if (code == KeyEvent.VK_UP)
      newVpos -= 10;
    else if (code == KeyEvent.VK_DOWN)
      newVpos += 10;
    else if (code == KeyEvent.VK_LEFT)
      newHpos -= 10;
    else if (code == KeyEvent.VK_LEFT)
      newHpos += 10;
    else {
      System.err.println("Unknown key code: " + code);
      return;
    }
    if (newHpos < -4000 || newHpos > 4000 ||
	newVpos < -4000 || newVpos > 4000) return;
    hpos = newHpos;
    vpos = newVpos;
    repaint();
  }
  public void keyTyped(KeyEvent e) { }
  public void keyReleased(KeyEvent e) { }

}

// Local variables:
// c-basic-offset: 2
// tab-width: 8
// End:
