import java.util.Vector;

public interface GeneralStrassen {
  void init();
  Strasse next();
  Vector to_koord(Vector in);
  int[] to_koord1(String in);
  int pos();
}
