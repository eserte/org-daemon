#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Encode qw(encode_utf8);
use File::Temp qw(tempdir);
use Test::More;
use Time::Local qw(timelocal);
BEGIN {
    if (!eval q{ use Time::Fake; 1 }) {
	plan skip_all => 'Time::Fake not available';
    }
}

plan 'no_plan';

sub create_org_file ($);

require "$FindBin::RealBin/../bin/org-daemon";
pass 'required org-daemon';

{ # empty file
    my $tmp = create_org_file <<'EOF';
* org file without dates
EOF
    is_deeply [App::orgdaemon::find_dates_in_org_file($tmp->filename)], [], 'empty file';
}

my $epoch = timelocal(0,0,0,1,1-1,2016);
Time::Fake->offset($epoch);

{ # date in far past
    my $tmp = create_org_file <<'EOF';
* TODO normal date :tag: <2013-12-31 Fr 23:59>
EOF
    is_deeply [App::orgdaemon::find_dates_in_org_file($tmp->filename)], [], 'date in far past';
}

{ # fake a currently displayed and due date (somewhat complicated)
    my $tmp = create_org_file <<'EOF';
* TODO normal date :tag: <2015-12-31 Fr 23:59>
EOF
    my $date_id = '* TODO normal date :tag: <2015-12-31 Fr 23:59>|2015-12-31 Fr '; # strange id formatting...
    no warnings 'redefine', 'once';
    local $App::orgdaemon::window_for_date{$date_id} = 'fake window id';
    local *Tk::Exists = sub { $_[0] eq 'fake window id' };
    my @dates = App::orgdaemon::find_dates_in_org_file($tmp->filename);
    is scalar(@dates), 1;
    is $dates[0]->id, $date_id;
    is $dates[0]->state, 'due', 'date in past, but current display in a window faked...';
}

{ # a normal date, neither due nor early warning
    my $tmp = create_org_file <<'EOF';
* TODO normal date :tag: <2016-01-02 Sa 0:00>
EOF
    my @dates = App::orgdaemon::find_dates_in_org_file($tmp->filename);
    is scalar(@dates), 1;
    is $dates[0]->{epoch}, $epoch + 86400;
    is $dates[0]->{text}, '* TODO normal date :tag: <2016-01-02 Sa 0:00>';
    is $dates[0]->id, '* TODO normal date :tag: <2016-01-02 Sa 0:00>|2016-01-02 Sa '; # strange id formatting...
    is $dates[0]->formatted_text, 'normal date :tag: <2016-01-02 Sa 0:00>';
    is $dates[0]->date_of_date, "2016-01-02";
    is $dates[0]->state, 'wait';
    is $dates[0]->{line}, 1;
}

{ # DONE items are ignored
    my $tmp = create_org_file <<'EOF';
* DONE normal date :tag: <2016-01-02 Sa 0:00>
EOF
    is_deeply [App::orgdaemon::find_dates_in_org_file($tmp->filename)], [], 'DONE dates are ignored';
}

{ # WONTFIX items are ignored
    my $tmp = create_org_file <<'EOF';
* WONTFIX normal date :tag: <2016-01-02 Sa 0:00>
EOF
    is_deeply [App::orgdaemon::find_dates_in_org_file($tmp->filename)], [], 'WONTFIX dates are ignored';
}

{ # test early warning --- default early warning is set to 30*60s
    my $tmp = create_org_file <<'EOF';
* TODO early warning <2016-01-01 Sa 0:15>
EOF
    my($date) = App::orgdaemon::find_dates_in_org_file($tmp->filename);
    is $date->state, 'early';
}

{ # early warning with individual date setting
    my $tmp = create_org_file <<'EOF';
** TODO Perl-Mongers-Treffen <2016-01-01 Sa 00:55 -60min>
EOF
    my($date) = App::orgdaemon::find_dates_in_org_file($tmp->filename);
    is $date->state, 'early', 'modified early warning';
}

{ # date with repeater and early warning
    my $tmp = create_org_file <<'EOF';
** TODO Perl-Mongers-Treffen <2016-01-01 Sa 00:55 +1m -60min>
EOF
    my($date) = App::orgdaemon::find_dates_in_org_file($tmp->filename);
    is $date->state, 'early', 'modified early warning, ignored repeater';
}

{ # date not in first line (and also: leap day, and English weekday name)
    my $tmp = create_org_file <<'EOF';
* TODO normal date :tag:
  Some text.
  Now comes the date: <2016-02-29 Mon 00:00>
  More text.
* WAITING another date :tagfoo:tagbar:
  <2016-03-01 Tue 23:59>
EOF
    my @dates = App::orgdaemon::find_dates_in_org_file($tmp->filename);
    is scalar(@dates), 2;
    is $dates[0]->date_of_date, '2016-02-29';
    is $dates[0]->formatted_text, 'normal date :tag:   Now comes the date: <2016-02-29 Mon 00:00>';
    is $dates[1]->date_of_date, '2016-03-01';
    is $dates[1]->formatted_text, 'another date :tagfoo:tagbar:   <2016-03-01 Tue 23:59>';
}

{ # multi line item
    my $tmp = create_org_file <<'EOF';
** TODO multi-line item <2016-01-02 Sa 0:00>
   Blubber bla
   * foo bar
   * another item
   : some code
#+BEGIN_EXAMPLE
literal example
#+END_EXAMPLE
** TODO 2nd item  <2016-01-03 So 0:00>
EOF
    my @dates = App::orgdaemon::find_dates_in_org_file($tmp->filename);
    like $dates[0]->formatted_text, qr{multi-line item};
    is   $dates[0]->date_of_date, '2016-01-02';
    like $dates[1]->formatted_text, qr{2nd item};
    is   $dates[1]->date_of_date, '2016-01-03';
}

{
    my $tmp = create_org_file encode_utf8(<<"EOF");
** TODO this contains utf-8: \x{20ac} <2016-01-02 Sa 0:00>
EOF
    my($date) = App::orgdaemon::find_dates_in_org_file($tmp->filename);
    like $date->formatted_text, qr{this contains utf-8: \x{20ac}};
}

{
    local $TODO = "does not work --- cannot switch encoding while reading from a scalar?";
    local $SIG{__WARN__} = sub {}; # cease warnings because of this problem
    my $tmp = create_org_file <<'EOF';
                      -*- coding: iso-8859-1 -*-
** TODO this contains latin1: ��� <2016-01-02 Sa 0:00>
EOF
    my($date) = App::orgdaemon::find_dates_in_org_file($tmp->filename);
    like $date->formatted_text, qr{this contains latin1: ���};
}

{ # slow emacs writes
    my $tmpdir = tempdir(CLEANUP => 1);
    my $tmpfile = "$tmpdir/test.org";
    if (fork == 0) {
	select undef,undef,undef,0.1;
	open my $ofh, '>', $tmpfile or die $!;
	print $ofh <<'EOF';
** TODO slow writing                <2016-01-02 Sa 0:00>
EOF
	close $ofh or die $!;
	exit 0;
    }
    my @warnings; local $SIG{__WARN__} = sub { push @warnings, @_ };
    my($date) = App::orgdaemon::find_dates_in_org_file($tmpfile);
    if (@warnings) {
	like $warnings[0], qr{NOTE: file '.*/test.org' probably vanished or is saved in this moment. Will retry again.};
    } else {
	diag 'No warnings seen. Slow fork?';
    }
    like $date->{text}, qr{slow writing};
}

{ # non-existent file (run rather last, as it's waiting for 1s)
    my $non_existent_file = '/tmp/non-existent-file/' . time . $$ . rand(1);
    {
	my @warnings; local $SIG{__WARN__} = sub { push @warnings, @_ };
	my @dates = App::orgdaemon::find_dates_in_org_file($non_existent_file);
	like $warnings[-1], qr{Can't open \Q$non_existent_file\E:};
	is_deeply \@dates, [];
    }
    # we have slightly different code paths the 2nd time
    {
	my @warnings; local $SIG{__WARN__} = sub { push @warnings, @_ };
	my @dates = App::orgdaemon::find_dates_in_org_file($non_existent_file);
	like $warnings[-1], qr{Can't open \Q$non_existent_file\E:};
	is_deeply \@dates, [];
    }    
}


sub create_org_file ($) {
    my $contents = shift;
    my $tmp = File::Temp->new(SUFFIX => '.org');
    $tmp->print($contents);
    $tmp->close;
    $tmp;
}

__END__