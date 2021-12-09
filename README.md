# VM8-System
System Disk for the VM-8 computer, and a Linux emulator

This is the second version of a system for the VM-8 Computer : now it has both the Turbo Modula-2 Reloaded compiler and an Oberon-07 compiler.
The Oberon-07 compiler is derived from Project Oberon (http://www.projectoberon.com/) : roughly, it replaces the custom-RISC code generator with a new code generator that targets the Turbo Modula-2 Reloaded VM.

Compared with Turbo Modula-2 Reloaded, there are a few extensions to the VM definition, and the Kernel has been reduced to almost nothing, so the exceptions handling mechanism using coroutines has been removed in the process, which means that exceptions that aren't caught will halt the VM. This is because I'm currently writing a small Oberon system that doesn't use coroutines (but still, using coroutines is possible in Modula-2 or Oberon user programs).

Beware that the convergence between Modula-2 and Oberon modules is not complete : the object format (.MCD files) is the same, so the system can load modules without worrying if there are Modula-2 or Oberon modules. But the symbol file formats are not the same: the Modula-2 compiler compiles definition modules into .SYM files, whilst the Oberon compiler generates .SMB files along with the .MCD code. So if you want to use a Modula-2 module from an Oberon module, you will need a .SMB file generated from a stub module, and if you want to use an Oberon module from a Modula-2 module, you will need to compile a Modula-2 definition module corresponding to the Oberon module. Not mentionning that the 16-bit version number is not calculated in the same way so it has to be patched afterwards... So for now, it is better to forget about this Modula-2/Oberon compatibility, except if you only use modules from the standard library (I've provided the symbol files for the two languages).

I haven't updated the firmware for the VM-8 computer yet, so if you want to try it you can use the ugly VM implementation for Linux.

TRY IT:

1. Download the virtual machine for Linux and compile it (make). It should work without modification on Linux, Android (in Termux), Windows (with Cygwin).

2. Download the zipped system disk and extract it (system.dsk) in the same directory as the virtual machine interpreters, it is an image of a FAT32 filesystem with my current small operating system pre-installed in it. You can check the contents of this image:

- file system.dsk reveals it has 128 reserved sectors (the system image is installed in the reserved sectors), apart from this it is a normal FAT32 filesystem.
- you can access the contents with the mtools on Linux, or mount this disk image (e.g sudo mount -o loop system.dsk /mnt). For convenience, this repository has shows all the files of this disk.

3. Start the virtual machine, telling it to boot on the disk image:
./vm3 system.dsk

4. Try some examples:
- dir
- type loadpath.txt  (this file contains the top level directory names that are looked up when you ask for a module to load (e.g dir and type are in SHELL.DIR)
- cd shell
- type cd.mod (this reveals that cd is a Modula-2 module)
- cd (without argument, it will prompt you for a directory name)
- ed cd.mod (this launches the editor, press F9 if you want to quit without saving, or F10 to save changes: try to change the message in the PromptFor call)
- m2 cd.mod (this compiles the module)
- cd (if you didn't introduce syntax errors, you now see your custom prompt message)
- root (this returns to the root of the filesystem)
- cd examples
- type hello.obn (yeap this one is an Oberon module)
- obn hello (this compiles the Oberon module)
- ...

or have a look at a small demonstration video: https://youtu.be/5Qu8TZNxHn0

STATUS:
This is not the publicly released version yet, it lacks documentation and I intend to deliver a new shell in the spirit of Midnight Commander.
It's not finished also because I might abandon Turbo Modula-2 Reloaded in favor of Oberon-07 in the future, so that will allow me to furthermore reduce the size of the system. The rationale behind the abandon of TM2R is that I don't have the sources (only the part that I have decompiled, and the result is not always readable). Also my code generator for Oberon is very good now, and I'm aiming for the simplest system possible...
However, I've fixed a few bugs discovered when playing Advent of Code 2021, so the big system.dsk image is not up-to-date with these last fixes, a new release will be commited when all the puzzles are done.
