
shellshow
=========

shellshow is a slideshow program that provides interesting transitions between slides. Slides can simply be text files and no special formatting is necessary.

Demo
====

See it in action in this video:

http://www.youtube.com/watch?v=Fy7QK2vaSTU


Installation
============

Just put the shellshow script in your path somewhere.


Usage
=====

Create some slide files.  Each file counts as a slide.

Then start the show just by running:

  shellshow slides*

This will use slide files prefixed with slides. You should probably use
a prefix or suffix that will allow you to only select slide files.

You're not limited to "slide files" either, you could simply use this
kinda like a pager such as less, more or most.

Navigation
==========

  Once you're in the shellshow program, the following keys can be
  used to switch between the slides. These navigation keys may
  change in the future to allow for more wipes.

   <space>, <enter> = Move forward a frame in slide motion.
   <b>, <backspace> = Move backward a frame in slide motion.
   <l>              = Move forward with slideline wipe. (slow)
   <k>              = Move backward with slideline wipe. (slow)
   <f>              = Move forward with fadeout/fadein wipe. (req. black bg)
   <d>              = Move backward with fadeout/fadein wipe. (req. black bg)
 

Current issues
==============

In order to use the fading transition, you need to have a 256-color capable
terminal emulator. This also means that you'll have trouble using it inside a
terminal window managers like screen, tmux and dvtm.

It also cannot currently handle multibyte characters like UTF-8.

Hopefully these problems will be fixed in a future release.


Future Development
==================

I'll probably rewrite this in C and make it easier for other developers to
jump in and make transitions/wipes of their own. 

