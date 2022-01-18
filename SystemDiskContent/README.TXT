Quick command guide

This system aims to be a minimalist (single-user, single-task) disk operating
system written in Modula-2 and Oberon, that can be easily extended by the
end-user: any compiled module may become a new operating system command.

Commands available on this disk image:

- simple modules that provide a familiar disk operating system command line
interface (in the SHELL:

    dir                     lists the contents of the working directory.
                            Please note that filenames are grouped by basename,
                            so you will often see a line such as
                                MODULE   DEF SYM MOD MCD BAK
                            which means there are five files with the same basename
                            but a different extension.

    dir filespec            wildcards (?,*) are accepted in the filename specification

    cd subdirectory         changes the current working directory (one at a time),
                            you don't have to provide the .DIR extension in the
                            directory name

    cd ..                   goes up one directory

    root                    returns to the root directory

    copy file1 file2        copies file1 into file2

    copyto file1 subdir     copies file1 into subdir

    delete file             deletes ONE file (no wildcards yet, safer)

    rename file1 file2      renames file1 into file2

    type file               types file onto the terminal

    lines file              counts lines in file

    size file               shows size of file


- e filename                starts the text editor (default extension for filename is OBN).
                            Editor commands: please see EDITKEYS.TXT in directory EDITOR,
                            or better EDITKEYS.OLD to be sure you don't accidently modify
                            EDITKEYS.TXT.
                            Lifesavers: F9 to quit without saving, F10 saves and exits with
                            a .BAK file that retains the old version of the file.

- m2 filename               Turbo Modula-2 Reloaded compiler. See information about Turbo
                            Modula-2 Reloaded in the MODULA2 directory.

- obn filename              Oberon compiler. See information about the Oberon compiler in
                            OBERON directory.


Please note the LOADPATH.TXT file in root directory. This is the list of directories that
the dynamic Loader will use when searching a module (.MCD) or a symbolic file (.SYM for
Modula-2, .SMB for Oberon), if the file is not found in the current directory.

Please note also that modifying system modules (editor, compilers, system libraries) is reserved
for advanced users: it is often a very bad idea to modify an existing DEFINITION module, and care
must be taken when replacing vital modules with modified ones... (plus the fact that many
system modules have been "cached" in the current system image).