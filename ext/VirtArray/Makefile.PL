use ExtUtils::MakeMaker;
use Config;
use Cwd;

# für die BBBike-Installation
my $thisdir = getcwd();
chdir("../..");
my $root = getcwd();
chdir($thisdir);

WriteMakefile
  (
   'NAME'	=> 'VirtArray',
   'VERSION_FROM' => 'VirtArray.pm', # finds $VERSION
   'LIBS'	=> [''],   # e.g., '-lm' 
   'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
   'INC'	=> '',     # e.g., '-I/usr/include/other' 
  );

# für die BBBike-Installation
sub MY::install {
    if ($] >= 5.006) {
	"install:	all
	@\$(MOD_INSTALL) \\
		\$(INST_LIB) $root/lib \\
		\$(INST_ARCHLIB) $root/lib/$Config{'version'}/$Config{'archname'} \\

";
    } else {
	"install:	all
	@\$(MOD_INSTALL) \\
		\$(INST_LIB) $root/lib \\
		\$(INST_ARCHLIB) $root/lib/$Config{'archname'} \\

";
    }
}
