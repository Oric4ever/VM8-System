Caution! Only build a system if you know what you do !

Two systems are ready to be built here.

The first one integrates the editor and a part of the compiler in overlays, like the
original Turbo Modula-2 did.

It can be built with the following command:

LINK SHELLRS4 <LINKSYS4.TXT
Output file: SYSTEM4.SYS
Include all needed modules (Y/N) ? N
...
Use overlays (Y/N) ? Y
...

This generates both SYSTEM4.SYS and SYSTEM4.OVR files.
Then finalize the binary image with FINALIZE:

FINALIZE
Linked file (without .SYS extension): SYSTEM4
Name of Kernel module: SHELLRES   (actually not used anymore)

This system can be permanently installed into the reserved sectors of the disk (Caution!):

INSTALL
System filename (without BIN extension): SYSTEM4

The second system doesn't integrate the editor nor the compiler, leaving more space to
user applications.

It can be built with the following command:

LINK SHELLRS2
Output file: SYSTEM2.SYS
Include all needed modules (Y/N) ? Y

This generates only a SYSTEM2.SYS file as no overlays are used.
The finalize the binary image with FINALIZE:

FINALIZE
Linked file (without .SYS extension): SYSTEM2
Name of Kernel module: KERNEL3

This system can be permanently installed into the reserved sectors of the disk like the
first one, but before that it can also be tested in memory with

RUNSYS SYSTEM2.BIN


