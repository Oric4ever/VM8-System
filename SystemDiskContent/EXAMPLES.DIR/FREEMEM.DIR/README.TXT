Compare available memory in the following situations:

MemSize0.mcd: normal dynamic loading of the module by the resident Modula-2 System
    (consisting in low-level modules (DISK, FAT32, FATDIR, FileDesc), user-level modules (Terminal,
    Convert, Files, Texts), kernel modules (Excepts, InitMod, Kernel3), resident part of shell
    (ShellRes, EditPos, ComLine, Loader))

    => 51193 bytes free

MemSize1.bin: build a system with only the necessary modules (no kernel, no shell).
    # link memsize1
    Output File: memsize1.sys
    Include all needed modules (Y/N)? Y
    ...
    # finalize
    Linked file (without .SYS extension): memsize1
    Name of Kernel module: memsize1
    ...
    # runsys memsize1.bin

    => 55834 bytes free

MemSize2.bin: building a system with only the Terminal module.
    # link memsize2
    Output File: memsize2.sys
    Include all needed modules (Y/N)? Y
    ...
    # finalize
    Linked file (without .SYS extension): memsize2
    Name of Kernel module: memsize2
    ...
    # runsys memsize2.bin

    => 63645 bytes free

MemSize3.bin: building a system with no library module, only BIOS calls
    # link memsize3
    Output File: memsize2.sys
    Include all needed modules (Y/N)? Y
    ...
    # finalize
    Linked file (without .SYS extension): memsize3
    Name of Kernel module: memsize3
    ...
    # runsys memsize3.bin

    => 64184 bytes free
    
    (the firmware still uses a 512-bytes buffer at 0100H, so the memsize3 "system" is
    loaded at 0300H, and memory at 0FF00H is used to redirect page 0.
    So 1 KB is wasted)
