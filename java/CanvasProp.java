import java.util.Hashtable;

class CanvasProp extends Hashtable {
  public static final int FILL = 0;
  public static final int WIDTH = 1;

  public void put(int prop, Object value) {
    put(new Integer(prop), value);
  }

  public Object get(int prop) {
    return get(new Integer(prop));
  }
}
