# -*- perl -*-
# Spelling -- check for common spelling errors

# Copyright (C) 1998 Richard Braakman
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Spelling;
use strict;
use Tags;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(spelling_check spelling_check_picky);

# All spelling errors that have been observed "in the wild" in package
# descriptions are added here, on the grounds that if they occurred once they
# are more likely to occur again.

# Misspellings of "compatibility", "separate", and "similar" are particularly
# common.

# Be careful with corrections that involve punctuation, since the check is a
# bit rough with punctuation.  For example, I had to delete the correction of
# "builtin" to "built-in".

our %CORRECTIONS = qw(
                      accesnt accent
                      accelleration acceleration
                      accessable accessible
                      accomodate accommodate
                      acess access
                      acording according
                      additionaly additionally
                      adress address
                      adresses addresses
                      adviced advised
                      albumns albums
                      alegorical allegorical
                      algorith algorithm
                      allpication application
                      altough although
                      alows allows
                      amoung among
                      amout amount
                      analysator analyzer
                      ang and
                      appropiate appropriate
                      arraival arrival
                      artifical artificial
                      artillary artillery
                      attemps attempts
                      authentification authentication
                      automaticly automatically
                      automatize automate
                      automatized automated
                      automatizes automates
                      auxilliary auxiliary
                      availavility availability
                      availble available
                      avaliable available
                      availiable available
                      backgroud background
                      baloons balloons
                      becomming becoming
                      becuase because
                      calender calendar
                      cariage carriage
                      challanges challenges
                      changable changeable
                      charachters characters
                      charcter character
                      choosen chosen
                      colorfull colorful
                      comand command
                      commerical commercial
                      comminucation communication
                      commoditiy commodity
                      compability compatibility
                      compatability compatibility
                      compatable compatible
                      compatibiliy compatibility
                      compatibilty compatibility
                      compleatly completely
                      complient compliant
                      compres compress
                      containes contains
                      containts contains
                      contence contents
                      continous continuous
                      contraints constraints
                      convertor converter
                      convinient convenient
                      cryptocraphic cryptographic
                      deamon daemon
                      debain Debian
                      debians Debian\'s
                      decompres decompress
                      definate definite
                      definately definitely
                      dependancies dependencies
                      dependancy dependency
                      dependant dependent
                      developement development
                      developped developed
                      deveolpment development
                      devided divided
                      dictionnary dictionary
                      diplay display
                      disapeared disappeared
                      dissapears disappears
                      documentaion documentation
                      docuentation documentation
                      documantation documentation
                      dont don\'t
                      easilly easily
                      ecspecially especially
                      edditable editable
                      editting editing
                      eletronic electronic
                      enchanced enhanced
                      encorporating incorporating
                      enlightnment enlightenment
                      enterily entirely
                      enviroiment environment
                      environement environment
                      excellant excellent
                      exlcude exclude
                      exprimental experimental
                      extention extension
                      failuer failure
                      familar familiar
                      fatser faster
                      fetaures features
                      forse force
                      fortan fortran
                      framwork framework
                      fuction function
                      fuctions functions
                      functionnality functionality
                      functonality functionality
                      functionaly functionally
                      futhermore furthermore
                      generiously generously
                      grahical graphical
                      grahpical graphical
                      grapic graphic
                      guage gauge
                      halfs halves
                      heirarchically hierarchically
                      helpfull helpful
                      hierachy hierarchy
                      hierarchie hierarchy
                      howver however
                      implemantation implementation
                      incomming incoming
                      incompatabilities incompatibilities
                      indended intended
                      indendation indentation
                      independant independent
                      informatiom information
                      initalize initialize
                      inofficial unofficial
                      integreated integrated
                      integrety integrity
                      integrey integrity
                      intendet intended
                      interchangable interchangeable
                      intermittant intermittent
                      jave java
                      langage language
                      langauage language
                      langugage language
                      lauch launch
                      lesstiff lesstif
                      libaries libraries
                      libary library
                      licenceing licencing
                      loggin login
                      logile logfile
                      loggging logging
                      maintainance maintenance
                      maintainence maintenance
                      makeing making
                      managable manageable
                      manoeuvering maneuvering
                      mathimatic mathematic
                      mathimatics mathematics
                      mathimatical mathematical
                      ment meant
                      modulues modules
                      monochromo monochrome
                      multidimensionnal multidimensional
                      navagating navigating
                      nead need
                      neccesary necessary
                      neccessary necessary
                      necesary necessary
                      nescessary necessary
                      noticable noticeable
                      o\'caml OCaml
                      optionnal optional
                      orientatied orientated
                      orientied oriented
                      pacakge package
                      pachage package
                      packacge package
                      packege package
                      packge package
                      pakage package
                      particularily particularly
                      persistant persistent
                      plattform platform
                      ploting plotting
                      protable portable
                      posible possible
                      postgressql PostgreSQL
                      powerfull powerful
                      prefered preferred
                      prefferably preferably
                      prepaired prepared
                      princliple principle
                      priorty priority
                      proccesors processors
                      proces process
                      processsing processing
                      processessing processing
                      progams programs
                      programers programmers
                      programm program
                      programms programs
                      promps prompts
                      pronnounced pronounced
                      prononciation pronunciation
                      pronouce pronounce
                      protcol protocol
                      protocoll protocol
                      publically publicly
                      recieve receive
                      recieved received
                      redircet redirect
                      regulamentations regulations
                      remoote remote
                      repectively respectively
                      replacments replacements
                      requiere require
                      runnning running
                      safly safely
                      savable saveable
                      searchs searches
                      separatly separately
                      seperate separate
                      seperated separated
                      seperately separately
                      seperatly separately
                      serveral several
                      setts sets
                      similiar similar
                      simliar similar
                      speach speech
                      speling spelling
                      splitted split
                      standart standard
                      staically statically
                      staticly statically
                      succesful successful
                      succesfully successfully
                      suplied supplied
                      suport support
                      suppport support
                      supportin supporting
                      synchonized synchronized
                      syncronize synchronize
                      syncronizing synchronizing
                      syncronus synchronous
                      syste system
                      sythesis synthesis
                      taht that
                      throught through
                      useable usable
                      usefull useful
                      usera users
                      usetnet Usenet
                      utilites utilities
                      utillities utilities
                      utilties utilities
                      utiltity utility
                      utitlty utility
                      variantions variations
                      varient variant
                      verson version
                      vicefersa vice-versa
                      yur your
                      wheter whether
                      wierd weird
                      xwindows X
                     );

# The format above doesn't allow spaces.
$CORRECTIONS{'alot'} = 'a lot';

# Picky corrections, applied before lowercasing the word.  These are only
# applied to things known to be entirely English text, such as package
# descriptions, and should not be applied to files that may contain
# configuration fragments or more informal files such as debian/copyright.
our %CORRECTIONS_CASE = qw(
                           D-BUS D-Bus
                           d-bus D-Bus
                           dbus D-Bus
                           debian Debian
                           english English
                           french French
                           EMacs Emacs
                           Gconf GConf
                           gconf GConf
                           german German
                           Gnome GNOME
                           gnome GNOME
                           Gnome-VFS GnomeVFS
                           Gnome-Vfs GnomeVFS
                           GnomeVfs GnomeVFS
                           gnome-vfs GnomeVFS
                           gnomevfs GnomeVFS
                           Gobject GObject
                           gobject GObject
                           Gstreamer GStreamer
                           gstreamer GStreamer
                           GTK GTK+
                           gtk+ GTK+
                           kde KDE
                           MYSQL MySQL
                           Mysql MySQL
                           mysql MySQL
                           linux Linux
                           OCAML OCaml
                           Ocaml OCaml
                           ocaml OCaml
                           OpenLdap OpenLDAP
                           Openldap OpenLDAP
                           openldap OpenLDAP
                           Postgresql PostgreSQL
                           postgresql PostgreSQL
                           python Python
                           russian Russian
                           SkoleLinux Skolelinux
                           skolelinux Skolelinux
                           SLang S-Lang
                           S-lang S-Lang
                           s-lang S-Lang
                           TCL Tcl
                           tcl Tcl
                           TEX TeX
                           TeTeX teTeX
                           Tetex teTeX
                           tetex teTeX
                           TK Tk
                           tk Tk
                           Xemacs XEmacs
                           XEMacs XEmacs
                           XFCE Xfce
                           XFce Xfce
                           xfce Xfce
                          );

# The format above doesn't allow spaces.
$CORRECTIONS_CASE{'Debian-Edu'} = 'Debian Edu';
$CORRECTIONS_CASE{'debian-edu'} = 'Debian Edu';
$CORRECTIONS_CASE{'TeXLive'} = 'TeX Live';
$CORRECTIONS_CASE{'TeX-Live'} = 'TeX Live';
$CORRECTIONS_CASE{'TeXlive'} = 'TeX Live';
$CORRECTIONS_CASE{'TeX-live'} = 'TeX Live';
$CORRECTIONS_CASE{'texlive'} = 'TeX Live';
$CORRECTIONS_CASE{'tex-live'} = 'TeX Live';

# -----------------------------------

sub _tag {
    my @args = grep { defined($_) } @_;
    tag(@args);
}

# Check spelling of $text and report the tag $tag if we find anything.
# $filename, if included, is given as the first argument to the tag.  If it's
# not defined, it will be omitted.
sub spelling_check {
    my ($tag, $text, $filename) = @_;

    for my $word (split(/\s+/, $text)) {
        $word = lc $word;

        # Try deleting the non-alphabetic parts from the word.  Treat
        # apostrophes specially: only delete them if they occur at the
        # beginning or end of the word.
        #
        # FIXME: Should do something that's aware of Unicode character
        # classes rather than only handling ISO 8859-15 characters.
        $word =~ s/(^\')|[^\w\xc0-\xd6\xd8-\xf6\xf8-\xff\'-]+|(\'\z)//g;
        if (exists $CORRECTIONS{$word}) {
            _tag($tag, $filename, $word, $CORRECTIONS{$word});
        }
    }

    # Special case for correcting a multi-word string.
    if ($text =~ m,Debian/GNU Linux,) {
        _tag($tag, $filename, "Debian/GNU Linux", "Debian GNU/Linux");
    }
}

# Check spelling of $text against pickier corrections, such as common
# capitalization mistakes.  This check is separate from spelling_check since
# it isn't appropriate for some files (such as changelog).  Takes $text to
# check spelling in and $tag to report if we find anything.  $filename, if
# included, is given as the first argument to the tag.  If it's not defined,
# it will be omitted.
sub spelling_check_picky {
    my ($tag, $text, $filename) = @_;

    for my $word (split(/\s+/, $text)) {
        $word =~ s/^\(|[).,?!:;]+$//g;
        if (exists $CORRECTIONS_CASE{$word}) {
            _tag($tag, $filename, $word, $CORRECTIONS_CASE{$word});
            next;
        }
    }
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround
