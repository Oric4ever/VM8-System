MODULE READFILE;
FROM Files IMPORT FILE;
IMPORT Files;
FROM SYSTEM IMPORT ADR, TSIZE;
FROM STORAGE IMPORT FREEMEM;

TYPE Header = RECORD
                fileSize, moduleStart, dependencies, nbDependencies,
                reserved4, reserved5, reserved6, reserved7: CARDINAL;
              END;
VAR header : Header;
    f : FILE;
    read : CARDINAL;
    buf : ARRAY [0..10000] OF CHAR;
BEGIN
  WRITELN("Free mem = ", FREEMEM());
  IF Files.Open(f, "RUSHHOUR.MCD") THEN
    WRITELN("Free mem = ", FREEMEM());
    read := Files.ReadBytes(f, ADR(header), TSIZE(Header));
    WRITELN("Module size is ", header.fileSize);
    read := Files.ReadBytes(f, ADR(buf), header.fileSize);
    WRITELN("Read ", read, " bytes");
    Files.Close(f);
    WRITELN("Free mem = ", FREEMEM());
  END;
END READFILE.                                                                            