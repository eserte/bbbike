// $Id: bbbike_result.js,v 1.1 2003/06/11 08:58:36 eserte Exp $
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
