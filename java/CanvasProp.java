import java.util.Hashtable;

class CanvasProp extends Hashtable {
  public static final int FILL = 0;
  public static final int WIDTH = 1;
  public static final int TAG = 2;

  public void put(int prop, Object value) {
    put(new Integer(prop), value);
  }

  public Object get(int prop) {
    Object ret = null;
    try {
      ret = get(new Integer(prop));
    } catch (Exception e) {
    }
    return ret;
  }
}

// Local variables:
// c-basic-offset: 2
// tab-width: 8
// End:
