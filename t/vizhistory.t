#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2026 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";

use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Test::More;

if (!eval { require YAML::XS; 1 }) {
    plan skip_all => 'YAML::XS not available';
}

plan tests => 21;

# Setup mock archive directory
my $tempdir = tempdir(CLEANUP => 1);
my $archive_dir = "$tempdir/archive";
make_path($archive_dir) or die "Cannot create mock archive dir: $!";
make_path("$archive_dir/2024") or die "Cannot create mock 2024 dir: $!";
make_path("$archive_dir/2013") or die "Cannot create mock 2013 dir: $!";

# Write mock YAML files
write_file_content("$archive_dir/2024/newvmz-20241231.yaml", <<'EOF');
id2rec:
  viz2021:13,52:
    id: viz2021:13,52
    text: "first version"
    viz2025_id: LMS:123/45
  other_id:
    id: other_id
    text: "only in oldest"
EOF

write_file_content("$archive_dir/newvmz-20250102.yaml", <<'EOF');
id2rec:
  viz2021:13,52:
    id: viz2021:13,52
    text: "second version"
    viz2025_id: LMS:123/45
EOF

write_file_content("$archive_dir/newvmz-20250103.yaml", <<'EOF');
id2rec:
  viz2021:13,52:
    id: viz2021:13,52
    text: "third version"
    viz2025_id: LMS:123/45
  new_id:
    id: new_id
    text: "only in newest"
EOF

# Same content as 20250103 to test skipping empty diffs
write_file_content("$archive_dir/newvmz-20250104.yaml", <<'EOF');
id2rec:
  viz2021:13,52:
    id: viz2021:13,52
    text: "third version"
    viz2025_id: LMS:123/45
  new_id:
    id: new_id
    text: "only in newest"
EOF

# Buggy older files to test stopping on buggy dates
write_file_content("$archive_dir/2013/newvmz-20130122.yaml", <<'EOF');
id2rec:
  buggy_id:
    id: buggy_id
    text: "buggy 20130122"
EOF

write_file_content("$archive_dir/2013/newvmz-20130121.yaml", <<'EOF');
id2rec:
  buggy_id:
    id: buggy_id
    text: "buggy 20130121"
EOF

my $vizhistory_cmd = "$^X -I$FindBin::RealBin/.. -I$FindBin::RealBin/../lib $FindBin::RealBin/../miscsrc/vizhistory";

# Case: Direct key lookup of new_id (only in newest, stop immediately on next)
{
    my $cmd = "$vizhistory_cmd --dir $archive_dir --no-pager new_id";
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    is($exit_code, 0, "Exit code is 0 for new_id lookup");
    like($output, qr/ID: new_id/, "Output contains correct ID header");
    like($output, qr/File: newvmz-20250103\.yaml/, "Output contains filename with changes");
    like($output, qr/\+text: only in newest/, "Output contains diff of text");

    # 20250104 has identical content for new_id as 20250103. The transition has an empty diff,
    # so it should be skipped and 20250104 should not be shown.
    unlike($output, qr/File: newvmz-20250104\.yaml/, "Output skips identical version (empty diff) for 20250104");
}

# Case: viz2025_id lookup of LMS:123/45 (present in all versions, with empty diff between 20250103 and 20250104)
{
    my $cmd = "$vizhistory_cmd --dir $archive_dir --no-pager LMS:123/45";
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    is($exit_code, 0, "Exit code is 0 for viz2025_id lookup");
    like($output, qr/File: newvmz-20250103\.yaml/, "Output contains newest file header");
    like($output, qr/File: newvmz-20250102\.yaml/, "Output contains middle file header");
    like($output, qr/File: 2024\/newvmz-20241231\.yaml/, "Output contains oldest file header in subdirectory");

    # Transition between 20250103 and 20250104 is identical, so 20250104 should not be shown.
    unlike($output, qr/File: newvmz-20250104\.yaml/, "Output skips identical version (empty diff) of LMS:123/45 for 20250104");
}

# Case: Direct key lookup of other_id (without --all, should stop at newest and exit with error)
{
    my $cmd = "$vizhistory_cmd --dir $archive_dir --no-pager other_id";
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    is($exit_code, 1, "Exit code is 1 when ID is not found under default behavior");
    like($output, qr/Error: ID 'other_id' was never found in the archive\./, "Output has correct error message");
}

# Case: Direct key lookup of other_id with --all (should skip newest, find it in oldest, exit 0)
{
    my $cmd = "$vizhistory_cmd --dir $archive_dir --no-pager --all other_id";
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    is($exit_code, 0, "Exit code is 0 with --all option for other_id");
    like($output, qr/File: 2024\/newvmz-20241231\.yaml/, "Output contains oldest file header with --all option");
    like($output, qr/\+text: only in oldest/, "Output contains correct diff for oldest file");
}

# Case: Non-existent ID lookup with --all
{
    my $cmd = "$vizhistory_cmd --dir $archive_dir --no-pager --all non_existent_id";
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    is($exit_code, 1, "Exit code is 1 when non-existent ID lookup is run with --all");
}

# Case: Verify stop_on_buggy_date behaviour (by default, stops on <= 20130122)
{
    my $cmd = "$vizhistory_cmd --dir $archive_dir --no-pager --all buggy_id";
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    is($exit_code, 1, "Exit code is 1 because buggy dates <= 20130122 are stopped/skipped by default");
    like($output, qr/Error: ID 'buggy_id' was never found/, "Output shows never found error");
}

# Case: Verify override with --process-buggy (processes buggy dates <= 20130122)
{
    my $cmd = "$vizhistory_cmd --dir $archive_dir --no-pager --all --process-buggy buggy_id";
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    is($exit_code, 0, "Exit code is 0 with --process-buggy");
    like($output, qr/File: 2013\/newvmz-20130122\.yaml/, "Output contains 20130122");
    like($output, qr/File: 2013\/newvmz-20130121\.yaml/, "Output contains 20130121");
}

sub write_file_content {
    my ($file, $content) = @_;
    open my $fh, '>', $file or die "Cannot write to $file: $!";
    print $fh $content;
    close $fh;
}
