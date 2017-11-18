#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use IPC::Run 'run';
use Test::More 'no_plan';

my $use_blib = 1;
my $org2ical = "$FindBin::RealBin/../blib/script/org2ical";
unless (-f $org2ical) {
    # blib version not available, use ../bin source version
    $org2ical = "$FindBin::RealBin/../bin/org2ical";
    $use_blib = 0;
}

# Special handling for systems without shebang handling
my @full_script = $^O eq 'MSWin32' || !$use_blib ? ($^X, $org2ical) : ($org2ical);

{
    my $res = run [@full_script, '--help'], '2>', \my $stderr;
    ok !$res, 'script run failed';
    like $stderr, qr{Unknown option: help};
    like $stderr, qr{\Qorg2ical [--debug] }, 'usage';
}

{
    my $res = run [@full_script, '--version'], '>', \my $stdout;
    ok $res, 'script run ok';
    if ($stdout =~ m{org2ical ([\d\.]+)}) {
	pass 'looks like a version';
    } else {
	fail "'$stdout' does not look like a version";
    }
}

__END__
