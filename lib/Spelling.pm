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
                      abandonning abandoning
                      abigious ambiguous
                      abitrate arbitrate
                      abov above
                      absolut absolute
                      accelleration acceleration
                      accesing accessing
                      accesnt accent
                      accessable accessible
                      accessable accessible
                      accidentaly accidentally
                      accidentually accidentally
                      accomodate accommodate
                      accomodate accommodate
                      accomodates accommodates
                      accout account
                      acess access
                      acording according
                      acumulating accumulating
                      addional additional
                      additionaly additionally
                      adress address
                      adresses addresses
                      adviced advised
                      afecting affecting
                      albumns albums
                      alegorical allegorical
                      algorith algorithm
                      algorithmical algorithmically
                      allpication application
                      alows allows
                      als also
                      altough although
                      ambigious ambiguous
                      amoung among
                      amout amount
                      analysator analyzer
                      ang and
                      annoucement announcement
                      appearence appearance
                      appropiate appropriate
                      appropriatly appropriately
                      aquired acquired
                      aquired acquired
                      architechture architecture
                      arguement argument
                      arguements arguments
                      aritmetic arithmetic
                      arne't aren't
                      arraival arrival
                      artifical artificial
                      artillary artillery
                      assigment assignment
                      assigments assignments
                      assistent assistant
                      asuming assuming
                      atomatically automatically
                      attemps attempts
                      attruibutes attributes
                      authentification authentication
                      automaticly automatically
                      automatize automate
                      automatized automated
                      automatizes automates
                      auxilliary auxiliary
                      avaiable available
                      availabled available
                      availablity availability
                      availale available
                      availavility availability
                      availble available
                      availble available
                      availiable available
                      avaliable available
                      avaliable available
                      backgroud background
                      baloons balloons
                      batery battery
                      becomming becoming
                      becuase because
                      begining beginning
                      calender calendar
                      cancelation cancellation
                      cancelation cancellation
                      capabilites capabilities
                      capatibilities capabilities
                      cariage carriage
                      challanges challenges
                      changable changeable
                      charachters characters
                      charcter character
                      chnages changes
                      choosen chosen
                      colorfull colorful
                      comand command
                      comit commit
                      commerical commercial
                      comminucation communication
                      commiting committing
                      committ commit
                      commoditiy commodity
                      compability compatibility
                      compatability compatibility
                      compatable compatible
                      compatibiliy compatibility
                      compatibilty compatibility
                      compleatly completely
                      complient compliant
                      compres compress
                      compresion compression
                      connectinos connections
                      consistancy consistency
                      containes contains
                      containts contains
                      contence contents
                      continous continuous
                      continueing continuing
                      contraints constraints
                      convertor converter
                      convinient convenient
                      corected corrected
                      cryptocraphic cryptographic
                      deamon daemon
                      debain Debian
                      debians Debian's
                      decompres decompress
                      definate definite
                      definately definitely
                      delemiter delimiter
                      dependancies dependencies
                      dependancy dependency
                      dependant dependent
                      detabase database
                      developement development
                      developement development
                      developped developed
                      deveolpment development
                      devided divided
                      dictionnary dictionary
                      diplay display
                      disapeared disappeared
                      dispertion dispersion
                      dissapears disappears
                      docuentation documentation
                      documantation documentation
                      documentaion documentation
                      dont don't
                      easilly easily
                      ecspecially especially
                      edditable editable
                      editting editing
                      eletronic electronic
                      enchanced enhanced
                      encorporating incorporating
                      endianess endianness
                      enhaced enhanced
                      enlightnment enlightenment
                      enterily entirely
                      enviroiment environment
                      enviroment environment
                      environement environment
                      excecutable executable
                      exceded exceeded
                      excellant excellent
                      exlcude exclude
                      explicitely explicitly
                      expresion expression
                      exprimental experimental
                      extention extension
                      failuer failure
                      familar familiar
                      fatser faster
                      fetaures features
                      forse force
                      fortan fortran
                      forwardig forwarding
                      framwork framework
                      fuction function
                      fuctions functions
                      functionaly functionally
                      functionnality functionality
                      functonality functionality
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
                      incompatable incompatible
                      inconsistant inconsistent
                      indendation indentation
                      indended intended
                      independant independent
                      informatiom information
                      infromation information
                      initalize initialize
                      initators initiators
                      initializiation initialization
                      inofficial unofficial
                      integreated integrated
                      integrety integrity
                      integrey integrity
                      intendet intended
                      interchangable interchangeable
                      intermittant intermittent
                      interupted interrupted
                      jave java
                      langage language
                      langauage language
                      langugage language
                      lauch launch
                      lenght length
                      lesstiff lesstif
                      libaries libraries
                      libary library
                      libraris libraries
                      licenceing licencing
                      loggging logging
                      loggin login
                      logile logfile
                      machinary machinery
                      maintainance maintenance
                      maintainence maintenance
                      makeing making
                      managable manageable
                      manoeuvering maneuvering
                      mathimatical mathematical
                      mathimatic mathematic
                      mathimatics mathematics
                      ment meant
                      messsages messages
                      microprocesspr microprocessor
                      milliseonds milliseconds
                      miscelleneous miscellaneous
                      misformed malformed
                      mispelled misspelled
                      mmnemonic mnemonic
                      modulues modules
                      monochorome monochrome
                      monochromo monochrome
                      monocrome monochrome
                      mroe more
                      multidimensionnal multidimensional
                      navagating navigating
                      nead need
                      neccesary necessary
                      neccessary necessary
                      neccessary necessary
                      necesary necessary
                      negotation negotiation
                      nescessary necessary
                      nessessary necessary
                      noticable noticeable
                      notications notifications
                      o'caml OCaml
                      omitt omit
                      ommitted omitted
                      optionnal optional
                      optmizations optimizations
                      orientatied orientated
                      orientied oriented
                      overaall overall
                      pacakge package
                      pachage package
                      packacge package
                      packege package
                      packge package
                      pakage package
                      paramameters parameters
                      parameterize parametrize
                      paramter parameter
                      paramters parameters
                      particularily particularly
                      pased passed
                      peprocessor preprocessor
                      perfoming performing
                      permissons permissions
                      persistant persistent
                      plattform platform
                      ploting plotting
                      posible possible
                      postgressql PostgreSQL
                      powerfull powerful
                      preceeded preceded
                      preceeding preceding
                      precission precision
                      prefered preferred
                      prefferably preferably
                      prepaired prepared
                      primative primitive
                      princliple principle
                      priorty priority
                      proccesors processors
                      proces process
                      processessing processing
                      processpr processor
                      processsing processing
                      progams programs
                      programers programmers
                      programm program
                      programms programs
                      promps prompts
                      pronnounced pronounced
                      prononciation pronunciation
                      pronouce pronounce
                      pronunce pronounce
                      propery property
                      prosess process
                      protable portable
                      protcol protocol
                      protecion protection
                      protocoll protocol
                      psychadelic psychedelic
                      quering querying
                      recieved received
                      recieved received
                      recieve receive
                      recieve receive
                      reciever receiver
                      recognizeable recognizable
                      recommanded recommended
                      redircet redirect
                      redirectrion redirection
                      reenabled re-enabled
                      reenable re-enable
                      reencode re-encode
                      refence reference
                      registerd registered
                      registraration registration
                      regulamentations regulations
                      remoote remote
                      removeable removable
                      repectively respectively
                      replacments replacements
                      requiere require
                      requred required
                      resizeable resizable
                      ressize resize
                      ressource resource
                      retransmited retransmitted
                      runnning running
                      safly safely
                      savable saveable
                      searchs searches
                      secund second
                      separatly separately
                      sepcify specify
                      seperated separated
                      seperated separated
                      seperately separately
                      seperate separate
                      seperate separate
                      seperatly separately
                      seperator separator
                      sequencial sequential
                      serveral several
                      setts sets
                      similiar similar
                      simliar similar
                      speach speech
                      speciefied specified
                      specifed specified
                      specificaton specification
                      specifing specifying
                      speficied specified
                      speling spelling
                      splitted split
                      staically statically
                      standart standard
                      staticly statically
                      subdirectoires subdirectories
                      succesfully successfully
                      succesful successful
                      superceded superseded
                      superflous superfluous
                      superseeded superseded
                      suplied supplied
                      suport support
                      suppored supported
                      supportin supporting
                      suppoted supported
                      suppported supported
                      suppport support
                      suspicously suspiciously
                      synax syntax
                      synchonized synchronized
                      syncronize synchronize
                      syncronize synchronize
                      syncronizing synchronizing
                      syncronus synchronous
                      syste system
                      sythesis synthesis
                      taht that
                      throught through
                      transfering transferring
                      trasmission transmission
                      treshold threshold
                      trigerring triggering
                      unexecpted unexpected
                      unfortunatelly unfortunately
                      unknonw unknown
                      unuseful useless
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
                      verbse verbose
                      verisons versions
                      verison version
                      verson version
                      vicefersa vice-versa
                      wheter whether
                      wierd weird
                      xwindows X
                      yur your
                     );

# The format above doesn't allow spaces.
$CORRECTIONS{'alot'} = 'a lot';

# Picky corrections, applied before lowercasing the word.  These are only
# applied to things known to be entirely English text, such as package
# descriptions, and should not be applied to files that may contain
# configuration fragments or more informal files such as debian/copyright.
our %CORRECTIONS_CASE = qw(
                           apache Apache
                           api API
                           Api API
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
                           gnu GNU
                           Gnu GNU
                           Gobject GObject
                           gobject GObject
                           Gstreamer GStreamer
                           gstreamer GStreamer
                           GTK GTK+
                           gtk+ GTK+
                           Http HTTP
                           kde KDE
                           meta-package metapackage
                           MYSQL MySQL
                           Mysql MySQL
                           mysql MySQL
                           linux Linux
                           Latex LaTeX
                           latex LaTeX
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
                           spanish Spanish
                           subversion Subversion
                           TCL Tcl
                           tcl Tcl
                           TEX TeX
                           Tex TeX
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
    return unless $text;

    $text = lc $text;
    $text =~ s/[.,;:?!()[\]]//g;

    for my $word (split(/\s+/, $text)) {
        if (exists $CORRECTIONS{$word}) {
            _tag($tag, $filename, $word, $CORRECTIONS{$word});
        }
    }

    # Special case for correcting a multi-word string.
    if ($text =~ m,debian/gnu\s+linux,) {
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

    # Check this first in case it's contained in square brackets and
    # removed below.
    if ($text =~ m,meta\s+package,) {
        _tag($tag, $filename, "meta package", "metapackage");
    }

    # Exclude text enclosed in square brackets as it could be a package list
    # or similar which may legitimately contain lower-cased versions of
    # the words.
    $text =~ s/\[.+?\]//sg;
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
