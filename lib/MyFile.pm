# -*- perl -*-

#
# $Id: $
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

package MyFile;

$VERSION = "0.01";

sub openlist {
    local(*FH, @fnames) = @_;
    local($file);
    while ($file = shift(@fnames)) {
	open(FH, $file) && return $file;
	local($gzfile) = "$file.gz";
	if (-r $gzfile) {
	    open(FH, "zcat $gzfile |") && return $gzfile;
	}
    }
    undef;
}

sub openlist2 {
    local(*FH, @dnames, $fname) = @_;
    local($dir, $file);
    while ($dir = shift(@dnames)) {
	$file = "$dir/$fname";
	open(FH, $file) && return $file;
    }
    undef;
}

1;
