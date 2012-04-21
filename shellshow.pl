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


for my $file (@ARGV) {
    open(my $fh, $file);
    my $thisline;
    my $lineno = 0;
LINE: while (<$fh>) {
        chomp($_);
        if ($lineno > $rows - 1) {
            last LINE;
        }
	    $_ =~ s/\t/    /g; # Convert tabs into 4 spaces.
        my $thisline = substr($_, 0, $cols);
        if (length($_) > $cols) {
		    $thisline = substr($thisline, $cols-1,1, "+"); # This does the pico/nano like behavior of showing that a line is overlength.
        }
        my $diff = $cols - length($thisline);
        if ($diff) {
            $thisline .= " " x $diff;
        }
        $frames[$frame][$lineno] = $thisline;
        $lineno++;
    }
    if ($lineno <= $rows) {
        my $thisline = " " x $cols;
        for my $l ($lineno .. $rows) {
            $frames[$frame][$l] = $thisline;
        }
    }
    $frame++;
    close($fh);
}

my $totalframes = scalar @frames;

    print "\033[2J";
#foreach $frameno (keys @frames) {
my $frameno = 0;
my $BSD_STYLE;
while ($frameno < $totalframes && $frameno >= 0) {
    poscursor(1,1);
    displayframe(\@frames,$frameno,$cols,$rows);

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

    # Do the transition. Perl needs a case to store all the Pearls.
    my ($oldframe, $newframe);
    if ($read eq "\n" or $read eq " ") { # Return or space to move forward.
        $oldframe = $frameno;
        $newframe = $frameno+1;
        slideright(\@frames,$oldframe,$newframe, $cols, $rows, \@timing);
        $frameno = $newframe;
    } elsif ($read eq "\177" or $read eq "b") { # Backspace to go back.
        $oldframe = $frameno;
        $newframe = $frameno-1;
        slideleft(\@frames,$oldframe,$newframe, $cols, $rows, \@timing);
        $frameno = $newframe;
    } elsif ($read eq "l") { # l to move forward using line at a time wipe
        $oldframe = $frameno;
        $newframe = $frameno+1;
        slidelineright(\@frames,$oldframe,$newframe, $cols, $rows, \@timing);
        $frameno = $newframe;
    } elsif ($read eq "k") { # l to move forward using line at a time wipe
        $oldframe = $frameno;
        $newframe = $frameno-1;
        slidelineleft(\@frames,$oldframe,$newframe, $cols, $rows, \@timing);
        $frameno = $newframe;
    } elsif ($read eq "f") { # f to move forward using fade method.
        $oldframe = $frameno;
        $newframe = $frameno+1;
        fadeoutfadein(\@frames,$oldframe,$newframe, $cols, $rows, \@graydient, 0.01);
        $frameno = $newframe;
    } elsif ($read eq "d") { # f to move forward using fade method.
        $oldframe = $frameno;
        $newframe = $frameno-1;
        fadeoutfadein(\@frames,$oldframe,$newframe, $cols, $rows, \@graydient, 0.01);
        $frameno = $newframe;
    }
    # Maybe have an r for random. Later of course we should allow a YAML config
    # file or something to setup a saved show so you can just play that with
    # predetermined wipes and waittimes, etc.
}

restoreterminal();
exit 0;


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
    my $framesref = shift;
    my $frame = shift;
    my $cols = shift;
    my $rows = shift;

    my $line = "";
    poscursor(1, 1);
    for my $y (0 .. $rows-1) {
        $line = substr($$framesref[$frame][$y], 0, $cols);
        if ($y + 1 == $rows) {
            print "$line"; # Don't put a newline on the last line.
        } else {
            print "$line\n";
        }
    }
    return 1;
}



sub slideright {
    my $framesref = shift;
    my $oldframe = shift;
    my $newframe = shift;
    my $cols = shift;
    my $rows = shift;
    my $timingref = shift;

    if (defined($$framesref[$newframe])) {
        my $leftline = "";
        my $rightline = "";
        for my $x (1 .. $cols-1) {
            poscursor(1, 1);
            for my $y (0 .. $rows-1) {
                $leftline = substr($$framesref[$oldframe][$y], $x);
                $rightline = substr($$framesref[$newframe][$y], 0, $x);
                if ($y + 1 == $rows) {
                    print "$leftline$rightline"; # Don't put a newline on the last line.
                } else {
                    print "$leftline$rightline\n";
                }
            }
            select(undef,undef, undef, $$timingref[$x]);
        }
    }
    return 1;
}
sub slideleft {
    my $framesref = shift;
    my $oldframe = shift;
    my $newframe = shift;
    my $cols = shift;
    my $rows = shift;
    my $timingref = shift;

    if (defined($$framesref[$oldframe])) {
        my $leftline = "";
        my $rightline = "";
        for my $x (reverse 1 .. $cols-1) {
            poscursor(1, 1);
            for my $y (0 .. $rows-1) {
                $leftline = substr($$framesref[$newframe][$y], $x);
                $rightline = substr($$framesref[$oldframe][$y], 0, $x);
                if ($y + 1 == $rows) {
                    print "$leftline$rightline"; # Don't put a newline on the last line.
                } else {
                    print "$leftline$rightline\n";
                }
            }
            select(undef,undef, undef, $$timingref[$x]);
        }
    }
    return 1;
}

# These are too slow.
sub slidelineright {
    my $framesref = shift;
    my $oldframe = shift;
    my $newframe = shift;
    my $cols = shift;
    my $rows = shift;
    my $timingref = shift;

    if (defined($$framesref[$newframe])) {
        my $leftline = "";
        my $rightline = "";
        for my $y (0 .. $rows-1) {
            for my $x (1 .. $cols) {
                poscursor(1,$y + 1);
                $leftline = substr($$framesref[$oldframe][$y], $x);
                $rightline = substr($$framesref[$newframe][$y], 0, $x);
                print "$leftline$rightline"; # Don't put a newline on the last line.
                select(undef,undef,undef, 0.001);
            }
            unless ($y + 1 == $rows) {
                print "\n";
            }
            #select(undef,undef, undef, $$timingref[$y]);
            select(undef,undef, undef, 0.0001);
        }
    }
    return 1;
}
sub slidelineleft {
    my $framesref = shift;
    my $oldframe = shift;
    my $newframe = shift;
    my $cols = shift;
    my $rows = shift;
    my $timingref = shift;

    if (defined($$framesref[$oldframe])) {
        my $leftline = "";
        my $rightline = "";
        for my $y (0 .. $rows-1) {
            for my $x (reverse 0 .. $cols) {
                poscursor(1,$y + 1);
                $leftline = substr($$framesref[$newframe][$y], $x);
                $rightline = substr($$framesref[$oldframe][$y], 0, $x);
                print "$leftline$rightline"; # Don't put a newline on the last line.
                select(undef,undef,undef, 0.001);
            }
            unless ($y + 1 == $rows) {
                print "\n";
            }
            #select(undef,undef, undef, $$timingref[$y]);
            select(undef,undef, undef, 0.0001);
        }
    }
    return 1;
}

sub fadeoutfadein {
    my $framesref = shift;
    my $oldframe = shift;
    my $newframe = shift;
    my $cols = shift;
    my $rows = shift;
    my $graydientref = shift;
    my $wait = shift || 0.03;

    if (defined($$framesref[$newframe])) {
        for my $color (@$graydientref) {
            poscursor(1,1);

            for my $y (0 .. $rows-1) {
                print "\033[38;5;${color}m" . $$framesref[$oldframe][$y];
                unless ($y + 1 == $rows) { 
                    print "\n";
                }
            }
            select(undef,undef,undef, $wait);
        }
        for my $color (reverse @$graydientref) {
            poscursor(1,1);

            for my $y (0 .. $rows-1) {
                print "\033[38;5;${color}m" . $$framesref[$newframe][$y];
                unless ($y + 1 == $rows) { 
                    print "\n";
                }
            }
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








