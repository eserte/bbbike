// (c) 2004 Slaven Rezic

import java.util.*;
import java.lang.*;

class Kreuzungen {

    private Hashtable Hash;
    private Hashtable Grid;
    private int GridWidth = 1000;
    private int GridHeight = 1000;

    public Kreuzungen(Hashtable InHash) {
	Hash = InHash;
    }

    private void make_grid() throws Exception {
	Grid = new Hashtable();
	for (Enumeration k = Hash.keys(); k.hasMoreElements(); ) {
	    String key = (String)k.nextElement();
	    String grid = grid_xy(key);
	    Vector grid_k;
	    if (Grid.containsKey(grid)) {
		grid_k = (Vector)Grid.get(grid);
	    } else {
		grid_k = new Vector();
		Grid.put(grid, grid_k);
	    }
	    grid_k.addElement(key);
	}
    }

    private String grid_xy(String xy) throws Exception {
	int commaIndex = xy.indexOf(',');
	if (commaIndex < 1) {
	    throw new Exception("Invalid coordinate " + xy);
	}
	int x = Integer.parseInt(xy.substring(0, commaIndex));
	int y = Integer.parseInt(xy.substring(commaIndex+1));
	int[] gxy = grid(x, y);
	return String.valueOf(gxy[0]) + "," + String.valueOf(gxy[1]);
    }

    private int[] grid(int x, int y) {
	int gx = x/GridWidth;
	int gy = y/GridHeight;
	if (x < 0) gx--;
	if (y < 0) gy--;
	int[] ret = new int[2];
	ret[0] = gx;
	ret[1] = gy;
	return ret;
    }

    public Vector nearest(int x, int y) throws Exception {
	return nearest(x, y, 1);
    }

    public Vector nearest(int x, int y, int grids) throws Exception {
 	if (Grid == null)
 	    make_grid();
	String xy = String.valueOf(x) + "," + String.valueOf(y);
 	int[] gridxy = grid(x, y);
	Vector res = new Vector();
	Hashtable seen_combination = new Hashtable();
	for(int grids_i = 0; grids_i <= grids; grids_i++) {
	    Vector grid_sequence = new Vector();
	    grid_sequence.addElement(new Integer(0));
	    for (int i = 1; i <= grids_i; i++) {
		grid_sequence.addElement(new Integer(i));
		grid_sequence.addElement(new Integer(-i));
	    }
	    for(Enumeration e_xx = grid_sequence.elements(); e_xx.hasMoreElements(); ) {
		int xx =  ((Integer)(e_xx.nextElement())).intValue();
		for(Enumeration e_yy = grid_sequence.elements(); e_yy.hasMoreElements(); ) {
		    int yy = ((Integer)(e_yy.nextElement())).intValue();
		    String xxyy = String.valueOf(xx) + "," + String.valueOf(yy);
		    if (seen_combination.containsKey(xxyy))
			continue;
		    seen_combination.put(xxyy, new Boolean(true));
		    String s = String.valueOf(gridxy[0]+xx) + "," + String.valueOf(gridxy[1]+yy);
		    if (Grid.containsKey(s)) {
			Vector s_grid = (Vector)Grid.get(s);
			for(Enumeration e_grid = s_grid.elements(); e_grid.hasMoreElements(); ) {
			    res.addElement(e_grid.nextElement());
			}
		    }
		}
	    }
	    if (!res.isEmpty())
		break;
	}

	Vector res2 = new Vector();
	for (Enumeration e_res = res.elements(); e_res.hasMoreElements(); ) {
	    String this_xy = (String)e_res.nextElement();
	    Vector elem = new Vector();
	    elem.addElement(this_xy);
	    double dist = StrassenNetz.strecke_s(this_xy, xy);
	    elem.addElement(new Double(dist));
	    res2.addElement(elem);
	}
	QSort.sort(res2, 1);
	return (Vector)res2.elementAt(0);
    }

// sub nearest_loop {
//      my($self, $x, $y, %args) = @_;
//      my $max_grids = delete $args{MaxGrids} || 5;
//      return $self->nearest($x, $y, %args, Grids => $max_grids);
// }

// # wie nearest, nur wird hier "x,y" als ein Argument übergeben
// ### AutoLoad Sub
// sub nearest_coord {
//     my($self, $xy, %args) = @_;
//     my($x, $y) = split(/,/, $xy);
//     $self->nearest($x, $y, %args);
// }

// # wie nearest_loop, nur wird hier "x,y" als ein Argument übergeben
// ### AutoLoad Sub
// sub nearest_loop_coord {
//     my($self, $xy, %args) = @_;
//     my($x, $y) = split(/,/, $xy);
//     $self->nearest_loop($x, $y, %args);
// }

// # Zeichnet die Kreuzungen, z.B. zum Debuggen.
// ### AutoLoad Sub
// sub draw {
//     my($self, $canvas, $transpose_sub) = @_;
//     $canvas->delete("crossings");
//     while(my($crossing,$info) = each %{ $self->{Hash} }) {
// 	my($x,$y) = $transpose_sub->(split /,/, $crossing);
// 	$canvas->createLine($x, $y, $x, $y,
// 			    -tags => 'crossings',
// 			    -fill => 'DeepPink',
// 			    -capstyle => "round",
// 			    -width => 4,
// 			   );
//     }
// }

// 1;

}

// Local variables:
// c-basic-offset: 2
// tab-width: 8
// End:
