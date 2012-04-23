#!/usr/bin/perl

# shellshow: terminal slideshow program with a few basic wipes
# Probably the next version will be written in C, this was written in
# perl for quick prototyping and for my @climagic presentation at
# Indiana Linux Fest 2012.

# Copyright (C) 2012 Mark Krenz (Deltaray)

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# You may contact the author at <deltaray@slugbug.org>

use strict;
use warnings;
use autodie;
use Time::HiRes qw(sleep);
use Getopt::Long qw(:config auto_help);
use Pod::Usage;

#For debugging, change this to a valid pts and watch for warnings
#open my $pts, '>>', '/dev/pts/6';
#open STDERR, '>&', $pts;

my $VERSION = 0.2;
GetOptions() or pod2usage(2);
pod2usage(2) if @ARGV < 2;

$| = 1;
my $rows = `tput lines`;
my $cols = `tput cols`;

# A simple timing array to use for the slides to give them
# a little acceleration.
# Total = 2*S(0.1/(n+1), n=0..$cols/2), diverges. F(80)=4.97, F(160)=5.66
my @timing = map { 1 / ($_ + 1) } (0 .. ($cols/2));

# Now make the other half of the timing array.
push @timing, reverse @timing;

#Target transition time in seconds (slow terminals will be slower)
my $transition_time = 0.5; #seconds
my $timing_sum = 0;
for (@timing) { $timing_sum += $_ }
my $timing_scale = $transition_time / $timing_sum;

# Gray colors in the ansi color spectrum
my @graydient = reverse (232 .. 255);

my @frames = ();
my $frame = 0;


while (<>) {
    chomp;
    s/\t/    /g; # Convert tabs into 4 spaces.
    my $thisline = substr($_, 0, $cols);
    if (length > $cols) {
        substr($thisline, -1) = "+"; # This does the pico/nano like behavior of showing that a line is overlength.
    }
    my $diff = $cols - length($thisline);
    if ($diff) {
        $thisline .= " " x $diff;
    }
    $frames[$frame][$.-1] = $thisline;
}
continue {
    if ($. + 1 > $rows or eof ARGV) {
        if ($. < $rows) {
            my $thisline = " " x $cols;
            for my $l ($. .. $rows-1) {
                $frames[$frame][$l] = $thisline;
            }
        }
        $frame++;
        close ARGV; #reset $. and skip to next file
    }
}
push @frames, [(" " x $cols) x $rows];
$frames[-1][0] = sprintf '%*s', $cols, 'End of presentation. Click to exit.' . ' ' x ($cols / 2);

my %dispatch = (
    "\n" => sub { forward(\&slideright) },
    " " => sub { forward(\&slideright) },
    "\177" => sub { backward(\&slideleft) },
    b => sub { backward(\&slideleft) },
    l => sub { forward(\&slidelineright) },
    k => sub { backward(\&slidelineleft) },
    f => sub { forward(\&fadeoutfadein) },
    d => sub { backward(\&fadeoutfadein) },
    "]" => sub { forward(\&displayframe) },
    "[" => sub { backward(\&displayframe) },
    w => sub { forward(\&linebyline) },
    q => sub { backward(\&linebyline) },
    '.' => sub { forward(\&wipeleft) },
    ',' => sub { backward(\&wiperight) },
);
# Maybe have an r for random. Later of course we should allow a YAML config
# file or something to setup a saved show so you can just play that with
# predetermined wipes and waittimes, etc.

my $totalframes = scalar @frames;

$SIG{INT} = $SIG{TERM} = \&safe_exit;
$SIG{__DIE__} = sub {
    die @_ unless defined $^S;
    restoreterminal() unless $^S;
    die @_;
};
END { restoreterminal() }

setupterminal();

    print "\033[2J";
#foreach $frameno (keys @frames) {
my $frameno = 0;
my $BSD_STYLE;
displayframe(undef,$frameno);
while ($frameno < $totalframes && $frameno >= 0) {
    poscursor(1,1);

    # Seems crazy to have to run system commands twice just to read a char.
    # We'll make this more efficient in the future and/or switch to C.
    if ($BSD_STYLE) {
        system "stty cbreak </dev/tty >/dev/tty 2>&1";
    } else {
        system "stty", '-icanon', 'eol', "\001";
    }
    my $read = getc();
    if ($BSD_STYLE) {
        system "stty -cbreak </dev/tty >/dev/tty 2>&1";
    } else {
        system 'stty', 'icanon', 'eol', '^@'; # ASCII NUL
    }

    # Do the transition.
    if (exists $dispatch{$read}) {
        $dispatch{$read}->();
    }
}

safe_exit();

sub forward {
    my $subref = shift;
    my $oldframe = $frameno;
    ++$frameno;
    safe_exit() if $frameno >= $totalframes;
    $subref->($oldframe, $frameno);
}
sub backward {
    my $subref = shift;
    my $oldframe = $frameno;
    --$frameno;
    safe_exit() if $frameno < 0;
    $subref->($oldframe, $frameno);
}

sub setupterminal {
    # I could have used Curses, but decided not to go that route
    # for a bit more simplicity right now.
    system('tput', 'smcup'); # Must be called using system.
                             # Backticks won't work.
    # The codes for smcup were listed as [?1049h on some page as well. :-(
#    printf "\0337\033[?47h"; # Switch to alternate screen (smcup)
    printf "\033[?25l"; # Hide the cursor (civis)
    `stty -echo`; # Turn off input echo.
}

sub restoreterminal {
    system('tput', 'rmcup');
#    printf "\033[2J\033[?47l"; # Switch back to normal screen (rmcup)
    printf "\033[?25h"; # show the cursor again. (cnorm)
    `stty echo`; # Turn input echo back on.
}

sub safe_exit {
    restoreterminal();
    exit 0;
}

sub displayframe {
    my $oldframe = shift;
    my $newframe = shift;
    poscursor(1, 1);
    print join("\n", @{$frames[$newframe]}) if defined $frames[$newframe];
    return 1;
}



sub slideright {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$newframe])) {
        my @two_frames = map {
                $frames[$oldframe][$_] . $frames[$newframe][$_]
            } (0 .. $rows-1);
        for my $x (1 .. $cols) {
            poscursor(1, 1);
            print join("\n", map {
                    substr $_, $x, $cols;
                } @two_frames);
            sleep($timing_scale * $timing[$x]);
        }
    }
    return 1;
}
sub slideleft {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$oldframe])) {
        my @two_frames = map {
                $frames[$newframe][$_] . $frames[$oldframe][$_]
            } (0 .. $rows-1);
        for my $x (reverse 0 .. $cols-1) {
            poscursor(1, 1);
            print join("\n", map {
                    substr $_, $x, $cols;
                } @two_frames);
            sleep($timing_scale * $timing[$x]);
        }
    }
    return 1;
}

# These are too slow.
sub slidelineright {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$newframe])) {
        my @two_frames = map {
                $frames[$oldframe][$_] . $frames[$newframe][$_]
            } (0 .. $rows-1);
        for my $y (0 .. $rows-1) {
            poscursor(1,$y + 1);
            for my $x (1 .. $cols) {
                print substr($two_frames[$y], $x, $cols), "\r";
                sleep($transition_time / ($cols * $rows));
            }
            unless ($y + 1 == $rows) {
                print "\n";
            }
        }
    }
    return 1;
}
sub slidelineleft {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$oldframe])) {
        my @two_frames = map {
                $frames[$newframe][$_] . $frames[$oldframe][$_]
            } (0 .. $rows-1);
        for my $y (0 .. $rows-1) {
            poscursor(1,$y + 1);
            for my $x (reverse 0 .. $cols-1) {
                print substr($two_frames[$y], $x, $cols), "\r";
                sleep($transition_time / ($cols * $rows));
            }
            unless ($y + 1 == $rows) {
                print "\n";
            }
        }
    }
    return 1;
}

sub linebyline {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$newframe] and $newframe >= 0)) {
        poscursor(1,1);
        for my $y (0 .. $rows-1) {
            print $frames[$newframe][$y];
            unless ($y + 1 == $rows) {
                print "\n";
                sleep($transition_time / $rows);
            }
        }
    }
    return 1;
}

sub wiperight {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$newframe])) {
        my $newlines = $frames[$newframe];
        for my $x (1 .. $cols) {
            for my $y (1 .. $rows) {
                poscursor($x,$y);
                print substr($newlines->[$y-1], $x-1, 1);
            }
            sleep($transition_time / $cols);
        }
    }
    return 1;
}
sub wipeleft {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$newframe])) {
        my $newlines = $frames[$newframe];
        for my $x (reverse 1 .. $cols) {
            for my $y (1 .. $rows) {
                poscursor($x,$y);
                print substr($newlines->[$y-1], $x-1, 1);
            }
            sleep($transition_time / $cols);
        }
    }
    return 1;
}

sub fadeoutfadein {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$newframe])) {
        my $oldlines = join("\n", @{$frames[$oldframe]});
        my $newlines = join("\n", @{$frames[$newframe]});
        for my $color (@graydient) {
            poscursor(1,1);
            print "\033[38;5;${color}m";
            print $oldlines;
            sleep($transition_time / (2 * @graydient));
        }
        for my $color (reverse @graydient) {
            poscursor(1,1);
            print "\033[38;5;${color}m";
            print $newlines;
            sleep($transition_time / (2 * @graydient));
        }

    }
    return 1;
}


sub poscursor {
    my $x = shift;
    my $y = shift;
    print "\033[${y};${x}H";
    return 1;
}

__END__
=head1 NAME

shellshow - A program to show "slides" in an interesting way inside the terminal

=head1 SYNOPSIS

shellshow I<file1> I<file2> [ I<file3> [ I<file4> [ I<...> ]]]

=head2 Movement/Wipes:

=over

=item B<space>, B<enter>

Move forward a frame in slide motion.

=item B<b>, B<backspace>

Move backward a frame in slide motion.

=item B<l>

Move forward with slideline wipe. (slow)

=item B<k>

Move backward with slideline wipe. (slow)

=item B<f>

Move forward with fadeout/fadein wipe. (req. black bg)

=item B<d>

Move backward with fadeout/fadein wipe. (req. black bg)

=item B<]>

Move forward without transition

=item B<[>

Move backward without transition

=item B<w>

Move forward with horizontal wipe transition

=item B<q>

Move backward with horizontal wipe transition

=item B<.>

Move forward with vertical wipe transition

=item B<,>

Move backward with vertical wipe transition

=back

=head1 DESCRIPTION

Shellshow determines the size of your terminal window and reads in
files given as args as frames, storing only the part of the file that
will fit inside the terminal window. You must at least give two filenames
as arguments. You can use shell glob patterns/wildcards if you want.

=head1 LIMITATIONS
Right now this program can't handle files with ANSI escapes or multibyte
characters like UTF-8 or binary characters.

I'd recommend using a black background with white forground text for now.
Eventually we'll have options for working with various background types, etc.

