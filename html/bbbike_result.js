// $Id: bbbike_result.js,v 1.2 2003/06/12 18:36:27 eserte Exp $
// (c) 2003 Slaven Rezic. All rights reserved.

function test_temp_blockings_set() {
  var frm = document.forms["Ausweichroute"];
  for (var elem = 0; elem < frm.elements["custom"].length; elem++) {
    if (frm.elements["custom"][elem].checked) {
      return true;
    }
  }
  alert("Bitte mindestens eine Auswahlbox auswählen");
  return false;
}

// Local variables:
// c-basic-offset: 2
// End:
