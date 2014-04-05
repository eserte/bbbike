# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1999-2004,2013,2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Win32Util;

=head1 NAME

Win32Util - a collection of Win32 related functions

=head1 SYNOPSIS

    use Win32Util;

=head1 DESCRIPTION

This is a collection of Win32 related functions. There are no strict
prerequirements for this module, however, full functionality can only
be achieved if some CPAN modules (Win32::Registry, Win32::API,
Win32::DDE, Win32::Shortcut ...) are available. By default, most of
these modules are already bundled with the popular ActivePerl package.

=cut

use strict;
use vars qw($DEBUG $browser_ole_obj $VERSION);

$VERSION = '1.40';
$DEBUG=0 unless defined $DEBUG;

# XXX Win-Registry-Funktionen mit Hilfe von Win32::API und
# der Hilfe von der Access-Webpage nachbilden...

# Laut Microsoft-Dokumentation soll für den Ort des Programm-Verzeichnisses
# die Funktion
#     SHGetSpecialFolderLocation(..., CSIDL_PROGRAMS, ...)
# verwendet werden.

use vars qw(%API_FUNC %API_DEF);

%API_DEF = ("SystemParametersInfo" => {Lib => "user32",
				       In  => ['N', 'N', 'P', 'N'],
				       Out => 'N'},
	    "GetSystemMetrics"     => {Lib => "user32",
				       In  => ['N'],
				       Out => 'N'},
	    "SHAddToRecentDocs"    => {Lib => "shell32",
				       In  => ['I', 'P'],
				       Out => 'I'},
	    "SHGetSpecialFolderLocation" => {Lib => "shell32",
					     In  => ['I', 'I', 'P'],
					     Out => 'I'},
	    "SHGetPathFromIDList"        => {Lib => "shell32",
					     In => ['P', 'P'],
					     Out => 'I'},
	    "GetLogicalDrives"     => {Lib => "kernel32",
				       In  => [],
				       Out => "I"},
	    "GetDriveType"         => {Lib => "kernel32",
				       In  => ["P"],
				       Out => "I"},
	    "GetVolumeInformation" => {Lib => "kernel32",
				       In  => ["P", "P", "I", "I", "I", "I", "P", "I"],
				       Out => "I"},
	    "GetSysColor"          => {Lib => "user32",
				       In  => ['N'],
				       Out => 'N'},
	    "GetUserName"          => {Lib => "advapi32",
				       In  => ['P', 'P'],
				       Out => 'I'},
	    "ShowWindow"           => {Lib => "user32",
				       In  => ['I', 'I'],
				       Out => "I"},
	    "DrawMenuBar"          => {Lib => "user32",
				       In  => ['N'],
				       Out => 'N'},
	    "GetMenuItemCount"     => {Lib => 'user32',
				       In  => ['N'],
				       Out => 'N'},
	    "GetMenuItemID"        => {Lib => 'user32',
				       In  => ['N','N'],
				       Out => 'N'},
	    "GetSystemMenu"        => {Lib => 'user32',
				       In  => ['N','N'],
				       Out => 'N'},
	    "RemoveMenu"           => {Lib => 'user32',
				       In  => ['N','N','N'],
				       Out => 'N'},
	    "SetWindowPos"         => {Lib => 'user32',
				       In  => [qw(N N N N N N N)],
				       Out => 'N'},
	   );

sub _get_api_function {
    my $name = shift;
    if (!exists $API_FUNC{$name}) {
	eval {
	    require Win32::API;
	    my $def = $API_DEF{$name};
	    if (!$def) {
		die "No API definition for $name";
	    }
	    $API_FUNC{$name} = new Win32::API ($def->{Lib}, $name,
					       $def->{In}, $def->{Out});
	};
	if ($@) {
	    warn $@;
	    $API_FUNC{$name} = undef;
	}
    }
    $API_FUNC{$name};
}

=head1 PROGRAM EXECUTION FUNCTIONS

=head2 start_any_viewer($file)

Based on extension of the given $file, start the appropriate viewer.

=cut

sub start_any_viewer {
    my $file = shift;
    require File::Basename;
    my($n,$p,$suffix) = File::Basename::fileparse($file, "\.[^.^]*");
    if ($suffix =~ /^html?$/) {
	return start_html_viewer($file);
    } elsif ($suffix eq 'ps') {
	return start_ps_viewer($file);
    } else {
	my $class = get_class_by_ext($suffix);
	if ($class) {
	    my $cmd = get_reg_cmd($class);
	    if (!$cmd) {
		warn "No command for class $class";
	    } else {
		return start_cmd($cmd, $file);
	    }
	} else {
	    warn "Can't start viewer for $file";
	}
    }
    0;
}

=head2 start_html_viewer($file)

Start a html viewer with the given file. This is mostly a WWW browser.

=cut

sub start_html_viewer {
    my $file = shift;
    if (!start_html_viewer_cmd($file)) {
        if (!start_html_viewer_dde($file)) {
            system("netscape $file &");
            if ($?) { return undef }
        }
    }
    1;
}

sub start_html_viewer_cmd {
    my $file = shift;
    my $html_viewer = get_html_viewer();
    if ($html_viewer =~ /netscape/i) {
	# Bei Netscape: HTML-Viewer funktioniert auf Dateien, nicht auf URLs!
	$file =~ s/^file://;
    }
    start_cmd($html_viewer, $file);
}

=head2 start_ps_viewer($file)

Start a postscript viewer with the given file.

=cut

sub start_ps_viewer {
    my $file = shift;
    if (!start_ps_viewer_cmd($file)) {
        system("gsview32 $file %");
        if ($?) { return undef }
    }
    1;
}

sub start_ps_viewer_cmd {
    my $file = shift;
    my $ps_viewer = get_ps_viewer();
    start_cmd($ps_viewer, $file);
}

sub ps_viewer_available {
    my $ps_viewer = get_ps_viewer();
    return 1 if defined $ps_viewer && $ps_viewer ne "";
    return 1 if is_in_path("gsview32");
    return 0;
}

=head2 start_ps_print($file)

Print a postscript file via a postscript viewer.

=cut

sub start_ps_print {
    my $file = shift;
    if (!start_ps_print_cmd($file)) {
        system("gsview32 /p $file %");
        if ($?) { return undef }
    }
    1;
}

sub start_ps_print_cmd {
    my $file = shift;
    my $ps_print = get_ps_print();
    start_cmd($ps_print, $file);
}

# XXX Maybe make a start_pdf_print with this information:
#
# --- CUT START ---
# Other options for the command line are:
# AcroRd32.exe /p filename - Executes the Reader and prints a file.
#    /n Launch a separate instance of the Acrobat application, even if one is
# currently open.
#    /s Open Acrobat, suppressing the splash screen.
#    /o Open Acrobat, suppressing the open file dialog.
#    /h Open Acrobat in hidden mode.
# AcroRd32.exe /t path printername drivername portname - Initiates
# Acrobat Reader, prints a file while suppressing the Acrobat print dialog
# box, then terminates Reader.

# The four parameters of the /t option evaluate to path, printername,
# drivername, and portname (all strings).
# printername - The name of your printer.
# drivername - Your printer driver's name. Whatever appears in the Driver Used
# box when you view your printer's properties.
# portname - The printer's port. portname cannot contain any "/" characters;
# if it does, output is routed to the default port for that printer.
# --- CUT END ---

sub start_txt_print {
    my $file = shift;
    my $txt_print = get_txt_print();
    start_cmd($txt_print, $file);
}

sub start_html_viewer_dde {
    my $file = shift;
    my ($app, $topic) = get_html_viewer_dde();
    start_dde($app, $topic, $file);
}

# XXX change to use IE or NS
# XXX Test it...
# Return a Win32::OLE object. With the XXX
sub show_browser_file {
    require Win32::OLE ;
    my $file = shift;
    if (!defined $browser_ole_obj) {
	$browser_ole_obj = Win32::OLE->new('InternetExplorer.Application');
    }
    if (defined $file && defined $browser_ole_obj) {
	$browser_ole_obj->Navigate($file);
    }
}

=head2 start_mail_composer($mailaddr)

Start a mail composer with $mailaddr as the recipient.

=cut

sub start_mail_composer {
    my $mailaddr = shift;
    if ($mailaddr !~ /^mailto:/) {
	$mailaddr = "mailto:$mailaddr";
    }
    my $mailto_cmd = get_mail_composer();
    start_cmd($mailto_cmd, $mailaddr);
}

sub get_html_viewer {
    my $class = get_class_by_ext(".htm") || "htmlfile";
    get_reg_cmd($class);
}
sub get_ps_viewer {
    my $class = get_class_by_ext(".ps") || "psfile";
    get_reg_cmd($class);
}
sub get_ps_print {
    my $class = get_class_by_ext(".ps") || "psfile";
    get_reg_cmd($class, "print");
}
sub get_txt_print {
    my $class = get_class_by_ext(".txt") || "txtfile";
    get_reg_cmd($class, "print");
}
sub get_mail_composer {
    my $cmd = get_reg_cmd("mailto");
    if ($cmd) {
	return $cmd;
    } else {
	eval <<'EOF';
	   use Win32::Registry;
	   my($key_ref, $key_ref2);
	   my $root = "SOFTWARE\\Clients\\Mail";
	   return unless $main::HKEY_LOCAL_MACHINE->Open($root, $key_ref);
	   my $key_ref2 = [];
	   return unless $key_ref->GetKeys($key_ref2);
	   my $clients = [@$key_ref2];
	   my $hashref;
	   if ($key_ref->GetValues($hashref)) {
	   	unshift @$clients, $hashref->{""}[2]; # default mailer
	   }
	   foreach my $client (@$clients) {
	       if ($main::HKEY_LOCAL_MACHINE->Open("$root\\$client\\Protocols\\mailto\\shell\\open\\command", $key_ref)) {
	       	   my $hashref;
	           if ($key_ref->GetValues($hashref)) {
		       $cmd = $hashref->{""}[2];
		       last;
	           }
	       }
	   }
EOF
	warn $@ if $@;
	return $cmd if defined $cmd;
	die "Can't send mail";
    }
}

sub get_html_viewer_dde {
    eval q{
        use Win32::Registry;
        my($app_ref, $topic_ref);
        return unless $main::HKEY_CLASSES_ROOT->Open('htmlfile\shell\open\ddeexec\Application', $app_ref);
        return unless $main::HKEY_CLASSES_ROOT->Open('htmlfile\shell\open\ddeexec\Topic', $topic_ref);
        my($app_hashref, $topic_hashref);
        return unless $app_ref->GetValues($app_hashref);
        return unless $topic_ref->GetValues($topic_hashref);
        ($app_hashref->{""}[2], $topic_hashref->{""}[2]);
    };
}

=head2 start_cmd($cmd, @args...)

Start an external program named $cmd. $cmd should be the full path to
the executable. @args are passed to the program. The program is
spawned, that is, executed in the background.

=cut

# XXX I got a report where for a print command the shell command
# was as follows:
#     %SystemRoot%\system32\Notepad.exe/p %1
# Note that there is no space between exe and /p!
# The user was unable to print, but the editor popped up.
# Was it only a typo by the user when reporting, or
# is it really this problem?
sub start_cmd {
    my($fullcmd, @args) = @_;

    my($appname, $base, $cmdline);
    eval q{
        use File::Basename;
        use Text::ParseWords;
	# ENV var substitution:
	my $env = normalize_env();
        $fullcmd =~ s/%([^%]+)%/$env->{uc($1)}/g;
        my(@words) = parse_line('\s+', 1, $fullcmd);
        $appname = shift @words; $appname =~ s/\"//g;
        my $argstr = join(" ", @words);
        $base = basename($appname); $base =~ s/\"//g;
        $cmdline = $base;
        my %arg_used;
        $argstr =~ s/(%(\d))/ $arg_used{$2-1}=1; defined($args[$2-1]) ? $args[$2-1] : "" /eg;
        $cmdline .= " $argstr";
        for my $i (0 .. $#args) {
            if (!$arg_used{$i}) {
                $cmdline .= " $args[$i]";
            }
        }
	if ($DEBUG) {
            warn "start_cmd: " . $cmdline . "\n(full path: $appname)\n";
	}
    };
    warn $@ if $@;

    my $r;
    eval q{
        use Win32::Process;
        my $proc;
        $r = Win32::Process::Create($proc, $appname, $cmdline,
				    0, NORMAL_PRIORITY_CLASS, ".");
    };
    if ($@) { # try Win32::Spawn (built-in)
        my $pid;
        $r = Win32::Spawn($appname, $cmdline, $pid);
    }
    $r;
}

=head2 normalize_env

Return a hash reference with all environment variable names changed
to uppercase.

=cut

sub normalize_env {
    my %env;
    while(my($k,$v) = each %ENV) {
	$env{uc($k)} = $v;
    }
    \%env;
}

=head2 start_dde($app, $topic, $arg)

Start a program via DDE. (What is $app and $topic?)

=cut

sub start_dde {
    my($app, $topic, $arg) = @_;
    my $r;
    eval q{
        use Win32::DDE::Client;
# XXX
$app="Netscape";# geht nur mit Netscape und nicht mit "Netscape 4.0" - warum?
        my $dde = new Win32::DDE::Client($app, $topic);
        warn "DDE Client with $app and $topic: $dde\n" if $DEBUG;
        if ($dde->Error) {
            warn "Unable to initiate DDE connection: " . $dde->Error . "\n";
            return;
        }
        $r = $dde->Request($arg);
        $dde->Disconnect;
    };
    $r;
}

=head1 EXTENSION AND MIME FUNCTIONS

=head2 get_reg_cmd($filetype[, $opentype])

Get a command from registry for $filetype. The "open" type is
returned, except stated otherwise.

=cut

sub get_reg_cmd {
    my($filetype, $opentype) = @_;
    $opentype = 'open' if !defined $opentype;
    my $cmd;
    eval q{
        use Win32::Registry;
        my($reg_key, $key_ref, $hashref);
        $reg_key = join('\\\\', $filetype, 'shell', $opentype, 'command');
        return unless $main::HKEY_CLASSES_ROOT->Open($reg_key, $key_ref);
        return unless $key_ref->GetValues($hashref);
        $cmd = $hashref->{""}[2];
    };
    warn $@ if $@;
    $cmd;
}

=head2 get_class_by_ext($ext)

Return the class name for the given extension.

=cut

sub get_class_by_ext {
    my $ext = shift;
    my $class;
    eval q{
        use Win32::Registry;
        my($key_ref, $hashref);
        return unless $main::HKEY_CLASSES_ROOT->Open($ext, $key_ref);
        return unless $key_ref->GetValues($hashref);
        $class = $hashref->{""}[2];
    };
    warn $@ if $@;
    $class;
}

=head2 install_extension(%args)

Install a new extension (class) to the registry. The function may take
the following key-value parameters:

=over 4

=item -extension

Required. The extension to be installed. The extension should start
with a dot. This can also be an array reference to a number of
extensions.

=item -name

Required. The class name of the new extension. May be something like
Excel.Application.

=item -icon

The (full) path to a default icon file (format should be .ico).

=item -open

The default open command (used if the file is double-clicked in the
explorer).

=item -print

The default print command.

=item -desc

An optional description.

=item -mime

The mime type of the extension (something like text/plain).

=back

=cut

sub install_extension {
    my(%args) = @_;
    my $ext  = $args{-extension} or die "Missing -extension parameter";
    my @ext;
    push @ext, (ref $ext eq 'ARRAY' ? @$ext : $ext);
    foreach my $ext (@ext) {
        if ($ext !~ /^\./) {
	    warn "Extension $ext does not start with dot";
	}
    }
    my $name  = $args{-name} or die "Missing -name parameter";
    my $icon  = $args{-icon};
    my $open  = $args{"-open"};
    my $print = $args{"-print"};
    my $desc  = $args{"-desc"};
    my $mime  = $args{"-mime"};
    eval q{
	use Win32::Registry;
	foreach my $ext (@ext) {
	    my $ext_reg;
	    $main::HKEY_CLASSES_ROOT->Create($ext, $ext_reg);
	    $ext_reg->SetValue("", REG_SZ, $name);
	    if (defined $mime) {
		$ext_reg->SetValueEx("Content Type", 0, REG_SZ, $mime);
	    }
	}
	my $name_reg;
	$main::HKEY_CLASSES_ROOT->Create($name, $name_reg);
	if (defined $desc) {
	    $name_reg->SetValue("", REG_SZ, $desc);
	}
	if (defined $icon) {
	    my $icon_reg;
	    $name_reg->Create("DefaultIcon", $icon_reg);
	    $icon_reg->SetValue("", REG_SZ, $icon);
	}
	my $shell_reg;
	if (defined $open || defined $print) {
	    $name_reg->Create("shell", $shell_reg);
	}
	if (defined $open) {
	    my $open_reg;
	    $shell_reg->Create("open", $open_reg);
	    my $command_reg;
	    $open_reg->Create("command", $command_reg);
	    $command_reg->SetValue("", REG_SZ, $open);
	}
	if (defined $print) {
	    my $print_reg;
	    $shell_reg->Create("print", $print_reg);
	    my $command_reg;
	    $print_reg->Create("command", $command_reg);
	    $command_reg->SetValue("", REG_SZ, $print);
	}
    };
    warn $@ if ($@);
}

=head2 write_uninstall_information(%args)

=over 4

=item -appname => $appname

The application name. This is required.

=item -uninstallstring => $string

The command for the uninstall process (???). is required.

=item -regowner => $owner

Current owner of the registry entry (???). If not specified, the
current user is used.

=item -version => $version

Version number of application. This should consist of a major and
minor number. The full application name will be created of C<$appname>
and C<$version>.

=item -installdate => "YYYY-MM-DD"

The date of installation. If not specified, the current date is used.

=item -installlocation => $string

=item -installsource => $string

=item -modifypath => $string

=item -publisher => $string

=item -urlinfoabout => $string

=item -urlupdateinfo => $string

=back

=cut

sub write_uninstall_information {
    my(%args) = @_;

    my $appname         = delete $args{-appname} || die "-appname missing";
    my $uninstallstring = delete $args{-uninstallstring} || die "-uninstallstring missing";
    my $regowner        = delete $args{-regowner} || get_user_name(); # XXX full name?
    my $version         = delete $args{-version};
    my($versionmajor, $versionminor);
    if (defined $version && $version =~ /^(\d+)\.(\d+)$/) {
	($versionmajor, $versionminor) = ($1, $2);
    }
    my $appfullname = $appname;
    if (defined $version) {
	$appfullname .= " $version";
    }
    my $installdate     = delete $args{-installdate} || do {
	my(@l) = localtime;
	sprintf "%04d-%02d-%02d", $l[5]+1900, $l[4]+1, $l[3];
    };
    my $installlocation = delete $args{-installlocation};
    my $installsource   = delete $args{-installsource};
    my $modifypath      = delete $args{-modifypath};
    my $publisher       = delete $args{-publisher};
# XXX maybe s|/|//|g and s|//|///|g (see ext_uninst2.reg example)
    my $urlinfoabout    = delete $args{-urlinfoabout};
    my $urlupdateinfo   = delete $args{-urlupdateinfo};

    if (keys %args) {
	die "Unknown arguments: " . join(" ", keys %args);
    }

    eval <<'EOF';

    use Win32::TieRegistry;
    my $machKey = Win32::TieRegistry->new("LMachine")
	or die "Can't access HKEY_LOCAL_MACHINE key: $^E";
    my $appKey  = "Software/Microsoft/Windows/CurrentVersion/Uninstall/"
	          . $appfullname;
    delete $machKey->{$appKey};
    $machKey->{"$appKey/"} =
	{"/RegOwner" => $regowner,
	 (defined $version ? ("/DisplayVersion" => $version) : ()),
	 "/InstallDate" => $installdate,
	 (defined $installlocation ? ("/InstallLocation" => $installlocation) : ()),
	 (defined $installsource ? ("/InstallSource" => $installsource) : ()),
	 (defined $modifypath ? ("/ModifyPath" => $modifypath) : ()),
	 (defined $publisher ? ("/Publisher" => $publisher) : ()),
	 "/UninstallString" => $uninstallstring,
	 (defined $urlinfoabout ? ("/UrlInfoAbout" => $urlinfoabout) : ()),
	 (defined $urlupdateinfo ? ("/UrlUpdateInfo" => $urlupdateinfo) : ()),
	 (defined $versionmajor ? ("/VersionMajor" => [$versionmajor, "REG_DWORD"]) : ()),
	 (defined $versionminor ? ("/VersionMinor" => [$versionminor, "REG_DWORD"]) : ()),
	 "/DisplayName" => $appfullname,
	};

EOF
    warn $@ if $@;

}

=head1 USER FUNCTIONS

=head2 get_user_name

Get current windows user.

=cut

sub get_user_name {
    my(%args) = @_;

    # first try the domain user
    if ($args{-full}) {
    	my $server = get_domain_server();
    	if (defined $server) {
	    my $userinfo = {};
	    Win32API::Net::UserGetInfo($server, Win32::LoginName(), 2, $userinfo);
	    if ($userinfo) {
	        return $userinfo->{fullName};
	    }
	}
    }

    my $GetUserName = _get_api_function("GetUserName");
    if (!$GetUserName) {
	return Win32::LoginName();
    }
    my $max = 256;
    my $maxb = pack("L", $max);
    my $login = "\0"x$max;
    my $b = $GetUserName->Call($login, $maxb);
    if ($b) {
	substr($login, 0, unpack("L", $maxb)-1);
    } else {
	undef;
    }
}

=head2 is_administrator

Guess if current user has admin rights.

=cut

sub is_administrator {
    my $user_name = get_user_name();
    if (defined $user_name) {
	return $user_name =~/^(administrator|admin)$/i ? 1 : 0;
    }
    undef;
}

=head2 get_user_folder($foldertype, $public)

Get the folder path for the current user, or, if $public is set to a
true value, for the whole system. If $foldertype is not given, the
"Personal" subfolder is returned.

=cut

sub get_user_folder {
    my($foldertype, $public) = @_;
    $foldertype = 'Personal' if !defined $foldertype;
    if ($public) {
	my $common_folders =
	    { map { $_ => 1 }
	      (qw/AppData Desktop Programs Startup/, 'Start Menu')
	    };
	if (exists $common_folders->{$foldertype}) {
	    $foldertype = "Common $foldertype";
	}
    }
    my $folder;
    eval q{
        use Win32::Registry;
        my $top_hkey = ($public
			? $main::HKEY_LOCAL_MACHINE
			: $main::HKEY_CURRENT_USER);
        my($reg_key, $key_ref, $hashref);
        $reg_key = join('\\\\', qw(SOFTWARE Microsoft Windows CurrentVersion
				   Explorer), 'Shell Folders');
        return unless $top_hkey->Open($reg_key, $key_ref);
        return unless $key_ref->GetValues($hashref);
        $folder = $hashref->{$foldertype}[2];
    };
    my $win32_registry_err = $@;
    if ($win32_registry_err) {
	if ($foldertype eq 'Personal' && !$public) {
	    # File::HomeDir is available in Strawberry Perl
	    if (eval { require File::HomeDir; 1 }) {
		$folder = File::HomeDir->my_home;
		if (!defined $folder) {
		    warn "WARN: can't get user folder neither using Win32::Registry ($win32_registry_err) nor with File::HomeDir";
		}
	    } else {
		warn "WARN: can't get user folder using Win32::Registry ($win32_registry_err) and File::HomeDir is not installed";
	    }
	} else {
	    # No fallback possible
	    warn $win32_registry_err;
	}
    }
    # XXX could also use Win32::GetFolderPath(CSIDL_APPDATA) ...
    $folder;
}

=head2 get_program_folder

Get the folder path for the program files (usually C:\Program Files).

=cut

sub get_program_folder {
    my $folder;
    eval q{
        use Win32::Registry;
        my $top_hkey = $main::HKEY_LOCAL_MACHINE;
        my($reg_key, $key_ref, $hashref);
        $reg_key = join('\\\\', qw(SOFTWARE Microsoft Windows CurrentVersion));
        return unless $top_hkey->Open($reg_key, $key_ref);
        return unless $key_ref->GetValues($hashref);
        $folder = $hashref->{"ProgramFilesDir"}[2];
    };
    warn $@ if $@;
    $folder;
}

sub get_special_folder {
    my($folder_type) = @_;

    my %sfid =
	(
	 ADMINTOOLS => 0x30, # only Windows 2000
	 ALTSTARTUP => 0x1D,
	 APPDATA => 0x1A,
	 BITBUCKET => 0xA,
	 COMMON_ADMINTOOLS => 0x2F, # only Windows 2000
	 COMMON_ALTSTARTUP => 0x1D, # only Windows 2000/NT
	 COMMON_APPDATA => 0x23, # only Windows 2000
	 COMMON_DESKTOPDIRECTORY => 0x19, # only Windows 2000/NT
	 COMMON_DOCUMENTS => 0x2E, # only Windows 2000/NT
	 COMMON_FAVORITES => 0x1F, # only Windows 2000/NT
	 COMMON_PROGRAMS => 0x17, # only Windows 2000/NT
	 COMMON_STARTMENU => 0x16, # only Windows 2000/NT
	 COMMON_STARTUP => 0x18, # only Windows 2000/NT
	 COMMON_TEMPLATES => 0x2D, # only Windows 2000/NT
	 CONTROLS => 0x3,
	 COOKIES => 0x21,
	 DESKTOP => 0x0,
	 DESKTOPDIRECTORY => 0x10,
	 DRIVES => 0x11,
	 FAVORITES => 0x6,
	 FONTS => 0x14,
	 HISTORY => 0x22,
	 INTERNET => 0x1,
	 INTERNET_CACHE => 0x20,
	 LOCAL_APPDATA => 0x1C, # only with MSIE 5.0
	 MYPICTURES => 0x27, # only with MSIE 5.0
	 NETHOOD => 0x13,
	 NETWORK => 0x12,
	 PERSONAL => 0x5,
	 PRINTERS => 0x4,
	 PRINTHOOD => 0x1B,
	 PROFILE => 0x28, # only with MSIE 5.0
	 PROGRAM_FILES => 0x26, # only with MSIE 5.0
	 PROGRAM_FILES_COMMON => 0x2B, # only Windows 2000/NT
	 PROGRAM_FILES_COMMONX86 => 0x2C, # only Windows 2000
	 PROGRAM_FILESX86 => 0x2A, # only Windows 2000
	 PROGRAMS => 0x2,
	 RECENT => 0x8,
	 SENDTO => 0x9,
	 STARTMENU => 0xB,
	 STARTUP => 0x7,
	 SYSTEM => 0x25, # only with MSIE 5.0
	 SYSTEMX86 => 0x29, # only Windows 2000
	 TEMPLATES => 0x15,
	 WINDOWS => 0x24, # only with MSIE 5.0
	);

    my $CSLID = $sfid{$folder_type};
    if (!defined $CSLID) {
	die "Folder type must be one of " . join(", ", keys %sfid) . "\n";
    }

    my $ret;
    eval q{
	my $SHGetSpecialFolderLocation = _get_api_function("SHGetSpecialFolderLocation") || die "Can't get API function for SHGetSpecialFolderLocation";
	my $SHGetPathFromIDList = _get_api_function("SHGetPathFromIDList") || die "Can't get API function for SHGetPathFromIDList";

	my $IDL = pack("VC", 0,0);
	my $lResult = $SHGetSpecialFolderLocation->Call(100, $CSLID, $IDL);
	if ($lResult == 0) {
	    my $sPath = " "x512;
	    my $cb;
	    (undef, $cb) = unpack("VC", $IDL);
	    my $cb_p = pack("C", $cb);
	    $SHGetPathFromIDList->Call($cb_p, $sPath);
	    $sPath =~ s/\0.*//;
	    $ret = $sPath;
	} else {
	    die "Error in SHGetSpecialFolderLocation";
	}
    };
    warn $@ if $@;
    $ret;
}

=head2 get_home_dir()

Get home directory (from domain server) or from some environment variables.

=cut

sub get_home_dir {
    my(%args) = @_;

    # first try the domain user
    my $server = get_domain_server();
    if (defined $server) {
    	my($userinfo) = {};
	Win32API::Net::UserGetInfo($server, Win32::LoginName(), 2, $userinfo);
	if ($userinfo) {
	    return $userinfo->{homeDir};
	}
    }

    if (exists $ENV{HOMEDRIVE} && exists $ENV{HOMEPATH}) {
	return "$ENV{HOMEDRIVE}$ENV{HOMEPATH}";
    }

    $ENV{USERPROFILE} || $ENV{HOMESHARE} || $ENV{HOME};
}


=head1 WWW AND NET FUNCTIONS

=head2 lwp_auto_proxy($lwp_user_agent)

Set the proxy for a LWP::UserAgent object (similar to the unix-centric
env_proxy method). Uses the Internet Explorer proxy setting.

=cut

sub lwp_auto_proxy {
    my $lwp_user_agent = shift;

    my $proxy_server;
    my $proxy_enable = 0;
    my $proxy_override;

    eval q{
        use Win32::Registry;
	my($reg_key, $key_ref, $hashref);
        $reg_key = join('\\\\', qw/Software Microsoft Windows CurrentVersion/,
			'Internet Settings');
	if ($main::HKEY_CURRENT_USER->Open($reg_key, $key_ref) &&
	    $key_ref->GetValues($hashref)) {
	    $proxy_enable   = $hashref->{"ProxyEnable"}[2];
	    $proxy_server   = $hashref->{"ProxyServer"}[2];
	    $proxy_override = $hashref->{"ProxyOverride"}[2];
	}
    };

    warn "Proxy settings from registry:
  enable=$proxy_enable server=$proxy_server override=$proxy_override\n"
	if $DEBUG;

    if ($proxy_enable) {
	# It seems that the following formats are possible:
	#    [http://]proxy[:port]
	# Fix this format to the one LWP uses...
	# multiple Proxies are separated by ";"
	foreach my $single_proxy (split /;/, $proxy_server) {
	    my $proxy_for;
	    if ($single_proxy =~ /^(ftp|http|https)=(.*)/) {
	        $proxy_for = [$1];
	        $single_proxy = $2;
	    } else {
	        $proxy_for = ['http', 'ftp'];
	    }
	    if ($single_proxy !~ m|^.*://|) {
	        $single_proxy = "http://$single_proxy/";
	    }
	    warn "Using <$single_proxy> as LWP proxy server setting for @$proxy_for\n"
	        if $DEBUG;
	    $lwp_user_agent->proxy($proxy_for, $single_proxy);
	}

	if (defined $proxy_override && $proxy_override eq '<local>') {
	    # XXX There is no way to say that hosts without domain portion
	    # should be no_proxied... So this is a poor excuse...
	    $lwp_user_agent->no_proxy("127.0.0.1", "localhost");
	}
    }
}

sub get_domain_server {
    if (eval { require Win32API::Net; 1 }) {
    	my($x1, $server, $x2, $userinfo);
	Win32API::Net::GetDCName($x1, $x2, $server);
	return $server;
    }
    undef;
}

=head1 MAIL FUNCTIONS

=head2 send_mail(%args)

Send an email through MAPI or other means. Some of the following
arguments are recognized:

=over 4

=item -sender

Required. The sender who is sending the mail.

=item -passwd

The MAPI password (?)

=item -recipient

The recipient of the mail.

=item -subject

The subject of the message.

=item -body

The body text of the message.

=back

This is from Win32 FAQ. Not tested, because MAPI is not installed on
my system.

=cut

sub send_mail {
    my(%args) = @_;
    send_mapi_mail(%args);
}

sub send_mapi_mail {
    my(%args) = @_;

    # Sender's Name and Password
    #
    my $sender = $args{-sender} or die "Sender is missing";
    my $passwd = $args{-password};

    # Create a new MAPI Session
    #
    require Win32::OLE;
    my $session;
    foreach my $mapiclass ("MAPI.Session",
			   #"MSMAPI.MAPISession"
			   ) {
	$session = Win32::OLE->new($mapiclass);
	last if ($session);
    }
    if (!$session) {
        die "Could not create a new MAPI Session: " . Win32::OLE->LastError();
    }

    # Attempt to log on.
    #
    my $err = $session->Logon($sender, $passwd);
    if ($err) {
        die "Logon failed: $!, " . Win32::OLE->LastError();
    }

    # Add a new message to the Outbox.
    #
    my $msg = $session->Outbox->Messages->Add();

    # Add the recipient.
    #
    my $rcpt = $msg->Recipients->Add();
    $rcpt->{Name} = $args{-recipient} or die "Recipient is missing";
    $rcpt->Resolve();

    # Create a subject and a body.
    #
    $msg->{Subject} = $args{-subject} or die "Empty Message";
    $msg->{Text} = $args{-body};

    # Send the message and log off.
    #
    $msg->Update();
    $msg->Send(0, 0, 0);
    $session->Logoff();

    1;
}

=head1 EXPLORER FUNCTIONS

=head2 create_shortcut(%args)

Create a shortcut (a desktop link). The following arguments are recognized:

=over 4

=item -path

Path to program (required).

=item -args

Additional arguments for the program.

=item -icon

Path to the .ico icon file.

=item -name

Title of the program (required).

=item -file

Specify where to save the .lnk file. If -file is not given, the file
will be stored on the current user desktop. The filename will consist
of the -name parameter and the .lnk extension.

=item -desc

Description for the file.

=item -wd

Working directory of this file.

=item -public

If true, create a shortcut visible for all users.

=item -autostart

Create shortlink in Autostart folder.

=back

=cut

sub create_shortcut {
    my(%args) = @_;
    my $path   = delete $args{-path} || die "Missing -path parameter";
    my $args   = delete $args{-args};
    my $icon   = delete $args{-icon};
    my $name   = delete $args{-name} || die "Missing -name parameter";
    my $file   = delete $args{-file};
    my $desc   = delete $args{-desc};
    my $wd     = delete $args{-wd};
    my $public = delete $args{-public} || 0;
    my $autostart = delete $args{-autostart} || 0;

    eval q{
        use Win32::Shortcut;

	if (!defined $file) {
	    my $dir;
	    $dir = get_user_folder(($autostart ? "Startup" : "Desktop"),
				   $public);
	    if (!defined $dir) {
		die "Can't get Desktop or Startup directory";
	    }
	    $file = join('\\\\', $dir, "$name.lnk");
	}

        my $scut = new Win32::Shortcut;
        $scut->{Path}		   = $path;
	$scut->{Arguments}	   = $args if defined $args;
	$scut->{IconLocation}      = $icon if defined $icon;
	$scut->{Description}	   = $desc if defined $desc;
	$scut->{WorkingDirectory}  = $wd   if defined $wd;
        foreach my $key (keys %args) {
            $scut->{$key} = $args{$key};
        }
        $scut->{File} = $file;
        die "Can't save $file" if !$scut->Save;
    };
    warn $@ if ($@);
}

=head2 create_internet_shortcut(%args)

Create an internet shortcut. The following arguments are recognized:

=over 4

=item -url

URL for the shortcur (required).

=item -icon

Path to the .ico icon file.

=item -name

Title of the program (required).

Specify where to save the .lnk file. If -file is not given, the file
will be stored on the current user desktop. The filename will consist
of the -url parameter and the .lnk extension.

=item -desc

Description for the file (not used yet).

=back

=cut

sub create_internet_shortcut {
    my(%args) = @_;
    my $url   = delete $args{-url} || die "Missing -url parameter";
    my $icon  = delete $args{-icon};
    my $name  = delete $args{-name} || die "Missing -name parameter";
    my $file  = delete $args{-file};
    my $desc  = delete $args{-desc};
    my $public = delete $args{-public} || 0;

    eval q{
        if (!defined $file) {
            my $desktop = get_user_folder("Desktop", $public);
            if (!defined $desktop) {
    	        die "Can't get Desktop directory";
	    }
	    $file = join('\\\\', $desktop, "$name.url");
	}

	my $crlf = "\015\012";
	open(URL, ">$file") or die "Can't save $file: $!";
	print URL "[InternetShortcut]$crlf";
	print URL "URL=$url$crlf";
	if (defined $icon) {
	    print URL "IconFile=$icon$crlf";
	    print URL "IconIndex=0$crlf";
	}
	close URL;
    };
    warn $@ if ($@);
}

=head2 add_recent_doc($doc)

Add the specified document to the list of recent documents.

=cut

sub add_recent_doc {
    my $doc = shift;
    warn "try $doc";
    eval q{
        my $addtorecentdocs = _get_api_function("SHAddToRecentDocs");
	die $@ if !$addtorecentdocs;
	my $SHARD_PATH = 2;
	$doc .= "\0"; # XXX notwendig???
        $addtorecentdocs->Call($SHARD_PATH, $doc);
	warn "yeah";
    };
    warn $@ if $@;
}

=head2 create_program_group(%args)

Create a program group. Following arguments are recognized:

=over 4

=item -parent

Required. The name of the new program group.

=item -files

Required. The files to be included into the new program group. The
argument may be either a file name or an array with a number of file
names. The file names can be either a string or a hash like {-path =>
'path', -name => 'name'}. In the latter case, this hash will be used
as an argument for create_shortcut.

=item -public

If true, create a program group in the public section, not in the user
section of the start menu.

=back

=cut

sub create_program_group {
    my(%args) = @_;
    my $parent = delete $args{-parent} or die "Missing -parent parameter";
    my $files  = delete $args{-files} or die "Missing -files parameter";
    my $public = delete $args{-public} || 0;
    my @files;
    push @files, (ref $files eq 'ARRAY' ? @$files : $files);
    eval q{
	use File::Path;
	use File::Basename;
	my $progdir = get_user_folder("Programs", $public);
	die "Can't get user folder." if !$progdir;
	my $topdir  = "$progdir/$parent";
	if (!-d $topdir) {
	    mkpath([$topdir], 0, 0755);
	}
	foreach my $file (@files) {
	    my %shortcut_args;
	    if (ref $file eq 'HASH') {
		%shortcut_args = %$file;
	    } else {
		%shortcut_args = (-path => $file,
				  -name => basename($file),
				 );
	    }
	    if (exists $shortcut_args{-url}) {
	        $shortcut_args{-file} = "$topdir/$shortcut_args{-name}.url";
	        create_internet_shortcut(%shortcut_args);
	    } else {
	        $shortcut_args{-file} = "$topdir/$shortcut_args{-name}.lnk";
	        create_shortcut(%shortcut_args);
	    }
	}
    };
    warn $@ if $@;
}

=head1 FILE SYSTEM FUNCTIONS

=head2 get_cdrom_drives

Return a list of CDROM drives on the system.

=cut

sub XXX_get_cdrom_drives {
    my @drives;
    eval q{
	my $DRIVE_CDROM = 5;
	my $MAX_DOS_DRIVES = 26;
        my $getlogicaldrives = _get_api_function("GetLogicalDrives");
        my $getdrivetype     = _get_api_function("GetDriveType");
	die $@ if !$getlogicaldrives || !$getdrivetype;
        my $drives = $getlogicaldrives->Call();
	my @drive_bits = split(//, unpack("b*", pack("L", $drives))); # XXX V statt L?
	for my $i (0 .. $MAX_DOS_DRIVES-1) {
	    if ($drive_bits[$i]) {
		my $drive_name = chr($i + ord('A')) . ":";
		my $drive_type = $getdrivetype->Call($drive_name);
		push @drives, $drive_name if ($drive_type == $DRIVE_CDROM);
	    }
	}
    };
    warn $@ if $@;
    @drives;
}

sub get_cdrom_drives {
    get_drives('cdrom');
}

=head2 get_drives([$drive_filter])

Return a list of drives on the system. The optional parameter
C<$drive_filter> should be a comma-separated string with the possible
values C<cdrom>, C<fixed> (for fixed drives like harddisks),
C<ramdisk>, C<remote> (for net drives), and C<removable> (for
removable drives like ZIP or floppy disk drives).

=cut

sub get_drives {
    my($filter) = @_;
    my @drives;
    eval q{
	my %drive_filter;
	if ($filter) {
	    my %drive_def = (cdrom => 5,
			     fixed => 3,
			     ramdisk => 6,
			     remote => 4,
			     removable => 2,
			    );
	    foreach my $drive (split /,/, $filter) {
		if ($drive_def{$drive}) {
		    $drive_filter{$drive_def{$drive}}++;
		} else {
		    die "Unknown drive: $drive, please use any of: " . join(", ", keys %drive_def);
		}
	    }
	}

	my $MAX_DOS_DRIVES = 26;
        my $getlogicaldrives = _get_api_function("GetLogicalDrives");
        my $getdrivetype     = _get_api_function("GetDriveType");
	die $@ if !$getlogicaldrives || !$getdrivetype;
        my $drives = $getlogicaldrives->Call();
	my @drive_bits = split(//, unpack("b*", pack("L", $drives))); # XXX V statt L?
	for my $i (0 .. $MAX_DOS_DRIVES-1) {
	    if ($drive_bits[$i]) {
		my $drive_name = chr($i + ord('A')) . ":";
		my $drive_type = $getdrivetype->Call($drive_name);
		push @drives, $drive_name if !$filter || exists $drive_filter{$drive_type};
	    }
	}
    };
    warn $@ if $@;
    @drives;
}

=head2 get_volume_name($path)

Return the volume name for the given I<$path>. If the API function
C<GetVolumeInformation> is not available, or if the drive does not
exist, then C<undef> is returned.

=cut

sub get_volume_name {
    my($path) = @_;

    my $get_volume_information = _get_api_function("GetVolumeInformation");
    if (!$get_volume_information) {
	warn "Can't get volume name, GetVolumeInformation not available";
	return undef;
    }

    my $buf = "\0"x256;
    my $ret = $get_volume_information->Call($path, $buf, length($buf), 0, 0, 0, 0, 0);
    if (!$ret) {
	warn "Can't get volume name for path '$path'";
	return undef;
    }
    $buf =~ s{\0.*}{};
    $buf;
}

=head2 path2unc($path)

Expand a normal absolute path to a UNC path.

=cut

sub path2unc {
    my $path = shift;
    if ($path =~ m|^([a-z]):[/\\](.*)|i) {
        "\\\\" . Win32::NodeName() . "\\" . $1 . "\\" . $2; 
    } else {
	$path;
    }
}

=head1 GUI FUNCTIONS

=head2 client_window_region($tk_window)

Return maximum region for a window (without borders, title bar,
taskbar area). Format is ($x, $y, $width, $height).

=cut

sub client_window_region {
    my $top = shift;

    my $SPI_GETWORKAREA = 48;
    my $SM_CYCAPTION = 4;
    #my $SM_CXBORDER = 5;
    #my $SM_CYBORDER = 6;
    #my $SM_CXEDGE = 45;
    #my $SM_CYEDGE = 46;
    my $SM_CXFRAME = 32;
    my $SM_CYFRAME = 33;


    my @extends;
    _get_api_function("SystemParametersInfo");
    _get_api_function("GetSystemMetrics");
    if (!$API_FUNC{SystemParametersInfo} ||
	!$API_FUNC{GetSystemMetrics}) {
	# guess region
	@extends = (0, 0, $top->screenwidth-24, $top->screenheight-40);
    } else {
	my $buf = "\0"x(4*4); # size of RECT structure
	my $r = $API_FUNC{SystemParametersInfo}->Call($SPI_GETWORKAREA, 0,
						      $buf, 0);
	# XXX $r überprüfen
	@extends = unpack("V4", $buf);
	$extends[2] -= ($extends[0] +
			$API_FUNC{GetSystemMetrics}->Call($SM_CXFRAME)*2);
	$extends[3] -= ($extends[1] +
			$API_FUNC{GetSystemMetrics}->Call($SM_CYFRAME)*2 +
			$API_FUNC{GetSystemMetrics}->Call($SM_CYCAPTION));
    }
    @extends;
}

=head2 screen_region($tk_window)

Return maximum screen size without taskbar area.

=cut

sub screen_region {
    my $top = shift;

    my $SPI_GETWORKAREA = 48;

    my @extends;
    _get_api_function("SystemParametersInfo");
    if (!$API_FUNC{SystemParametersInfo}) {
	# guess region
	@extends = (0, 0, $top->screenwidth, $top->screenheight-20);
    } else {
	my $buf = "\0"x(4*4); # size of RECT structure
	my $r = $API_FUNC{SystemParametersInfo}->Call($SPI_GETWORKAREA, 0,
						      $buf, 0);
	# XXX $r überprüfen
	@extends = unpack("V4", $buf);
    }
    @extends;
}

=head2 maximize($tk_window)

Maximize the window. If Win32::API is installed, then the taskbar will
not be obscured.

=cut

sub maximize {
    my $top = shift;

    my $showwindow = _get_api_function("ShowWindow");
    if (defined $showwindow) {
        my $SW_SHOWMAXIMIZED = 3;
	$showwindow->Call(hex($top->frame), $SW_SHOWMAXIMIZED);
    } else {
	my @extends = client_window_region($top);
	$top->geometry("$extends[2]x$extends[3]+$extends[0]+$extends[1]");
    }
}

=head2 get_sys_color($what)

Return ($r,$g,$b) values from 0 to 255 for the requested system color.
C<$what> is any of: scrollbar, background, activecaption,
inactivecaption, menu, window, windowframe, menutext, windowtext,
captiontext, activeborder, inactiveborder, appworkspace, highlight,
highlighttext, btnface, btnshadow, graytext, btntext,
inactivecaptiontext, btnhighlight, 3ddkshadow, 3dlight, infotext,
infobk.

=cut

sub get_sys_color {
    my $type = shift;
    my $name2number =
    {"scrollbar"	    => 0,
     "background"	    => 1,
     "activecaption"	    => 2,
     "inactivecaption"	    => 3,
     "menu"		    => 4,
     "window"		    => 5,
     "windowframe"	    => 6,
     "menutext"		    => 7,
     "windowtext"	    => 8,
     "captiontext"	    => 9,
     "activeborder"	    => 10,
     "inactiveborder"	    => 11,
     "appworkspace"	    => 12,
     "highlight"	    => 13,
     "highlighttext"	    => 14,
     "btnface"		    => 15,
     "btnshadow"	    => 16,
     "graytext"		    => 17,
     "btntext"		    => 18,
     "inactivecaptiontext"  => 19,
     "btnhighlight"	    => 20,
     "3ddkshadow"	    => 21,
     "3dlight"		    => 22,
     "infotext"		    => 23,
     "infobk"		    => 24,
    };
    my $number = $name2number->{$type};
    return unless defined $number;
    my $GetSysColor = _get_api_function("GetSysColor");
    return unless $GetSysColor;
    my $i = $GetSysColor->Call($number);
    my($r,$g,$b);
    $b = $i >> 16;
    $g = ($i >> 8) & 0xff;
    $r = $i & 0xff;
    ($r, $g, $b);
}

=head2 close_dosbox()

Closes the dosbox. Handy if starting a GUI program with the standard
perl.exe and not wperl.exe.

=cut

sub close_dosbox {
    require Win32::Console;
    Win32::Console::Free();
}

=head2 disable_dosbox_close_button()

As the function name says :-). Derived from a posting from Jack D.

Tested by Peter Arnhold.

=cut

sub disable_dosbox_close_button {
    require Win32::GUI;
    use constant MF_BYCOMMAND => 0;
    # Get DOS window handle..
    my $hWnd = Win32::GUI::GetPerlWindow();
    die "Can't get perl window" if !$hWnd;
    for (qw(GetSystemMenu GetMenuItemCount GetMenuItemID
	    RemoveMenu DrawMenuBar)) {       
	return if !defined _get_api_function($_);
    }
    # Get System menu associated with IE Window handle..
    my $hMenu = $API_FUNC{GetSystemMenu}->Call($hWnd, 0);
    if ($hMenu) {
	# Obtain the number of items in the menu
	my $menuItemCount = $API_FUNC{GetMenuItemCount}->Call($hMenu);

	# Remove the Close menu item  from the menu
	# The close item has an ID of 61536. Menu is zero-based so last
	# menu item is actually the Menu Item Count - 1.

	for (my $i = $menuItemCount-1; $i >= 0; $i--) {
	    my $ID = $API_FUNC{GetMenuItemID}->Call($hMenu, $i);
	    if ($ID == 61536) {
		$API_FUNC{RemoveMenu}->Call($hMenu, $ID, MF_BYCOMMAND);
		warn "Removing $ID ",Win32::FormatMessage(Win32::GetLastError());#XXX remove debug comment
	    }
	}

	# Force a redraw of the menu.
	# This will refresh the titlebar and disable the 'X' button
	$API_FUNC{DrawMenuBar}->Call($hWnd);
    }
}

=head2 keep_on_top($tk_window [, $flag])

Keep the window C<$tk_window> on top. If C<Win32::API> is not
available, attributes(-topmost) is used if Tk 804.027 is available,
otherwise a crude hack with a <Visibility> binding is used instead. If
the optional variable C<$flag> is false, "keep on top" is disabled.

=cut

# Idea by Jack
sub keep_on_top {
    my $mw = shift;
    my $flag = 1;
    if (@_) {
	$flag = shift;
    }

    my $HWND_NOTOPMOST = -2;
    my $HWND_TOPMOST = -1;
    my $SWP_NOMOVE = 2;
    my $SWP_NOSIZE = 1;

    my $set_window_pos = _get_api_function("SetWindowPos");
    if ($set_window_pos) {
	$mw->update;
	my $WinID = hex($mw->frame);
	my $callAPI = sub {
	    my($flag) = @_;
	    my($return) = $set_window_pos->Call($WinID,$flag,0,0,0,0,$SWP_NOSIZE|$SWP_NOMOVE);
	    warn "ERROR in api call" unless $return;
	};
	if ($flag) {
	    $callAPI->($HWND_TOPMOST);
	} else {
	    $callAPI->($HWND_NOTOPMOST);
	}
    } elsif ($Tk::VERSION >= 804.027) {
	$mw->attributes(-topmost => $flag); # XXX test this!
    } else {
	warn "No Win32::API available, visibility binding hack";
	my $stay_above_after;
	$mw->bind("<Visibility>" =>
		  sub {
		      if ($stay_above_after) {
			  $stay_above_after->cancel;
		      }
		      $stay_above_after = $mw->after
			  (1000, sub {
			       $mw->raise;
			       #Tk->break;
			       undef $stay_above_after;
			   });
		  }
		 );
    }
}

=head1 MISC FUNCTIONS

=head2 sort_cmp_hack($a,$b)

"use locale" does not work on Windows. This is a hack to be used in
sort for german umlauts.

=cut

sub sort_cmp_hack {
    my($s1, $s2) = @_;
    sort_cmp_hack_transform($s1) cmp sort_cmp_hack_transform($s2);
}

sub sort_cmp_hack_transform {
    my $s = shift;
    $s =~ tr/äöüßÄÖÜ/aousAOU/;
    $s;
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 81c0124cc2f424c6acc9713c27b9a484
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe" ||
		    -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8
BEGIN {
    if (eval { require File::Spec; defined &File::Spec::file_name_is_absolute }) {
	*file_name_is_absolute = \&File::Spec::file_name_is_absolute;
    } else {
	*file_name_is_absolute = sub {
	    my $file = shift;
	    my $r;
	    if ($^O eq 'MSWin32') {
		$r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	    } else {
		$r = ($file =~ m|^/|);
	    }
	    $r;
	};
    }
}
# REPO END

=head1 SEE ALSO

L<perlwin32|perlwin32>, L<Win32::API|Win32::API>,
L<Win32::OLE|Win32::OLE>, L<Win32::Registry|Win32::Registry>,
L<Win32::Process|Win32::Process>, L<Win32::DDE|Win32::DDE>,
L<Win32::Shortcut|Win32::Shortcut>, L<Tk|Tk>, L<LWP::UserAgent>.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (c) 1999, 2000, 2001, 2002 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

__END__

Subject: Re: Best way to locate Windows install dir?

I think that in practice env(windir) (note lowercase spelling) is
indeed the most portable method.  It exists and is well-known since
Win 3.x.

You could also code your own small extension to call the
GetWindowsDirectory() API. 

----------------------------------------------------------------

Aus perldoc Win32::Clipboard
Zitat:
bitmap (CF_DIB)

The clipboard contains an image, either a bitmap or a picture copied in the clipboard from a graphic application. The data you get is a binary buffer ready to be written to a bitmap (BMP format) file.

Example:

$image = Win32::Clipboard::GetBitmap();
open BITMAP, ">some.bmp";
binmode BITMAP;
print BITMAP $image;
close BITMAP;

Schreib es in eine temporäre Datei und ruf dann sowas wie
system "mspaint -p some.bmp"
auf.
Das Kommando druckt bei mir (unter WinXPpro) die Datei direkt auf den Standarddrucker.

http://board.perl-community.de/cgi-bin/ikonboard/ikonboard.cgi?act=ST;f=12;st=0;t=108;#idx3

HKEY_CURRENT_USER\Control Panel\International\sLanguage

DEU=Deutschland
ENG=Grossbritanien

(vielleicht fuer Msg.pm verwenden)

Alternative zur Ermittlung der Sprache (von Wolf Behrenhoff):
----------------------------------------------------------------------
use Win32::API;
my $GetLang = Win32::API->new(
        "kernel32", "DWORD GetUserDefaultLangID()"
    );
$l = $GetLang->Call();

my $lang;
if ($l == 0x407) {
  $lang = 'Deutsch';
} elsif ($l == 0x419) {
  $lang = 'Russisch';
} else {
  $lang = 'andere Sprache';
}
print $lang;
----------------------------------------------------------------------
