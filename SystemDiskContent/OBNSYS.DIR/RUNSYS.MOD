IMPLEMENTATION MODULE RunSys;
FROM SYSTEM  IMPORT ADR;
FROM ComLine IMPORT RedirectInput, PromptFor;
FROM Loader  IMPORT Call;
FROM Files   IMPORT FILE, Open, ReadBytes, Close;

VAR sysname: ARRAY [0..19] OF CHAR;
    f : FILE;
    size: CARDINAL;
BEGIN
  RedirectInput; PromptFor('System to load: ', sysname);
  IF Open(f, sysname) THEN
    size := ReadBytes(f, ADR(SystemImage), 512);
    size := ReadBytes(f, ADR(SystemImage), SIZE(SystemImage));
    Close(f);
    IF size = SIZE(SystemImage) THEN
      WRITELN('Warning: Not enough memory to load ',sysname)
    END;
    Call("BootSys")
  ELSE
    WRITELN(sysname, ' not found')
  END;
END RunSys.
                                                                                            