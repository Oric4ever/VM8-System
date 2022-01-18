Caution! Only build a system if you know what you do !

Two systems are ready to be built here.

The first one integrates the editor and a part of the two compilers (M2 and OBN) in overlays,
like the original Turbo Modula-2 did.

It can be built with the following command:

LINK COMLINE2 SYSTEM.SYS <LINKSYS.TXT
Include all needed modules (Y/N) ? N
...
Use overlays (Y/N) ? Y
...

This generates both SYSTEM.SYS and SYSTEM.OVR files.
Then finalize the binary image (SYSTEM.BIN) with FINALIZE:

FINALIZE SYSTEM

This system can be permanently installed into the reserved sectors of the disk (Caution!):

INSTALL SYSTEM.BIN

The second system doesn't integrate the editor nor the compiler, leaving more space to
user applications. However, only the Oberon compiler will be fully usable, because the
Modula-2 compiler will lack space and thus be only able to compile small modules.

It can be built with the following command:

LINK COMLINE MINI.SYS
Include all needed modules (Y/N) ? Y

This generates only a MINI.SYS file as no overlays are used.
Then finalize the binary image with FINALIZE:

FINALIZE MINI

This system can be permanently installed into the reserved sectors of the disk like the
first one, but before that it can also be tested in memory with

RUNSYS MINI.BIN


