# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package TestUtil;

use strict;
use Exporter 'import';
use vars qw(@EXPORT);
@EXPORT = qw(get_root_dir get_full_script);

use Cwd 'realpath';
use File::Basename 'dirname';

sub get_root_dir () {
    dirname(dirname(realpath(__FILE__)));
}

sub get_full_script ($) {
    my($scriptname) = @_;

    my $use_blib = 1;
    my $full_script = get_root_dir() . "/blib/script/$scriptname";
    unless (-f $full_script) {
	# blib version not available, use ../bin source version
	$full_script = get_root_dir() . "/bin/$scriptname";
	$use_blib = 0;
    }

    # Special handling for systems without shebang handling
    my @full_script = $^O eq 'MSWin32' || !$use_blib ? ($^X, $full_script) : ($full_script);
    @full_script;
}

1;

__END__
