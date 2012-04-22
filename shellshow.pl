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

#For debugging, change this to a valid pts and watch for warnings
#open my $pts, '>>', '/dev/pts/6';
#open STDERR, '>&', $pts;

my $VERSION = 0.1;

$| = 1;
my $rows = `tput lines`;
my $cols = `tput cols`;

setupterminal();

$SIG{INT} = \&restoreterminal;
$SIG{TERM} = \&restoreterminal;

if (@ARGV < 2 || $ARGV[0] eq "-h" || $ARGV[0] eq "--help") {
    showhelp();
}

# A simple timing array to use for the slides to give them
# a little acceleration.
my @timing = map { 0.1 / ($_ + 1) } (0 .. ($cols/2));

# Now make the other half of the timing array.
push @timing, reverse @timing[0..$#timing-1];

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
);
# Maybe have an r for random. Later of course we should allow a YAML config
# file or something to setup a saved show so you can just play that with
# predetermined wipes and waittimes, etc.

my $totalframes = scalar @frames;

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

restoreterminal();
exit 0;

sub forward {
    my $subref = shift;
    my $oldframe = $frameno;
    ++$frameno;
    $subref->($oldframe, $frameno);
}
sub backward {
    my $subref = shift;
    my $oldframe = $frameno;
    --$frameno;
    $subref->($oldframe, $frameno);
}

sub showhelp {
    print <<"EOF";
--------------------------------------------------------------------------------
shellshow: A program to show "slides" in an interesting way inside the terminal
Version: $VERSION
--------------------------------------------------------------------------------
Usage:
 shellshow <file1> <file2> [file3 [, file4, [ ... ]]]

Movement/Wipes:
   <space>, <enter> = Move forward a frame in slide motion.
   <b>, <backspace> = Move backward a frame in slide motion.
   <l>              = Move forward with slideline wipe. (slow)
   <k>              = Move backward with slideline wipe. (slow)
   <f>              = Move forward with fadeout/fadein wipe. (req. black bg)
   <d>              = Move backward with fadeout/fadein wipe. (req. black bg)
   <]>              = Move forward without transition
   <[>              = Move backward without transition

Description:
 Shellshow determines the size of your terminal window and reads in
 files given as args as frames, storing only the part of the file that 
 will fit inside the terminal window. You must at least give two filenames
 as arguments. You can use shell glob patterns/wildcards if you want.

Limitations:
 Right now this program can't handle files with ANSI escapes or multibyte
 characters like UTF-8 or binary characters.

 I'd recommend using a black background with white forground text for now.
 Eventually we'll have options for working with various background types, etc.

EOF
    exit(0);
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
    exit 0;
}

sub displayframe {
    my $oldframe = shift;
    my $newframe = shift;
    poscursor(1, 1);
    print join("\n", @{$frames[$newframe]});
    return 1;
}



sub slideright {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$newframe])) {
        my $left = $frames[$oldframe];
        my $right = $frames[$newframe];
        for my $x (1 .. $cols-1) {
            poscursor(1, 1);
            print join("\n", map {
                    substr $left->[$_].$right->[$_], $x, $cols;
                } (0 .. $rows-1));
            select(undef,undef, undef, $timing[$x]);
        }
    }
    return 1;
}
sub slideleft {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$oldframe])) {
        my $left = $frames[$newframe];
        my $right = $frames[$oldframe];
        for my $x (reverse 1 .. $cols-1) {
            poscursor(1, 1);
            print join("\n", map {
                    substr $left->[$_].$right->[$_], $x, $cols;
                } (0 .. $rows-1));
            select(undef,undef, undef, $timing[$x]);
        }
    }
    return 1;
}

# These are too slow.
sub slidelineright {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$newframe])) {
        my $left = $frames[$oldframe];
        my $right = $frames[$newframe];
        for my $y (0 .. $rows-1) {
            poscursor(1,$y + 1);
            my $leftline = $left->[$y];
            my $rightline = $right->[$y];
            for my $x (1 .. $cols) {
                print substr($leftline.$rightline, $x, $cols), "\r";
                select(undef,undef,undef, 0.001);
            }
            unless ($y + 1 == $rows) {
                print "\n";
            }
            #select(undef,undef, undef, $timing[$y]);
            select(undef,undef, undef, 0.0001);
        }
    }
    return 1;
}
sub slidelineleft {
    my $oldframe = shift;
    my $newframe = shift;

    if (defined($frames[$oldframe])) {
        my $left = $frames[$newframe];
        my $right = $frames[$oldframe];
        for my $y (0 .. $rows-1) {
            poscursor(1,$y + 1);
            my $leftline = $left->[$y];
            my $rightline = $right->[$y];
            for my $x (reverse 0 .. $cols) {
                print substr($leftline.$rightline, $x, $cols), "\r";
                select(undef,undef,undef, 0.001);
            }
            unless ($y + 1 == $rows) {
                print "\n";
            }
            #select(undef,undef, undef, $timing[$y]);
            select(undef,undef, undef, 0.0001);
        }
    }
    return 1;
}

sub fadeoutfadein {
    my $oldframe = shift;
    my $newframe = shift;
    my $wait = 0.01;

    if (defined($frames[$newframe])) {
        for my $color (@graydient) {
            poscursor(1,1);
            print "\033[38;5;${color}m";
            print join("\n", @{$frames[$oldframe]});
            select(undef,undef,undef, $wait);
        }
        for my $color (reverse @graydient) {
            poscursor(1,1);
            print "\033[38;5;${color}m";
            print join("\n", @{$frames[$newframe]});
            select(undef,undef,undef, $wait);
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

