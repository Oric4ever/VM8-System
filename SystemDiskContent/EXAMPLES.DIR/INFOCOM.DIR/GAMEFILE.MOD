IMPLEMENTATION MODULE GameFile;
FROM STORAGE IMPORT ALLOCATE;
IMPORT Files;

CONST BLOCKSIZE = 512;
VAR gameFile: Files.FILE;

PROCEDURE OpenFile  (gameName: ARRAY OF CHAR): BOOLEAN;
BEGIN
  RETURN Files.Open(gameFile, gameName)
END OpenFile;

PROCEDURE ReadZWORD(): CARDINAL;
VAR w1, w2 :  RECORD
                word : CARDINAL;
                bytes: ARRAY [0..1] OF BYTE;
              END;
BEGIN
  Files.ReadWord(gameFile, w1.word);
  w2.bytes[0] := w1.bytes[1];
  w2.bytes[1] := w1.bytes[0];
  RETURN w2.word
END ReadZWORD;

PROCEDURE ReadHeader(VAR header: Header);
VAR w: WORD;
BEGIN
  WITH header DO
    Files.ReadRec(gameFile, versionAndFlags);
    release          := ReadZWORD();
    residentBytes    := ReadZWORD();
    gameOffset       := ReadZWORD();
    vocabOffset      := ReadZWORD();
    objectOffset     := ReadZWORD();
    variableOffset   := ReadZWORD();
    saveBytes        := ReadZWORD();
    flags2           := ReadZWORD();
    Files.ReadRec(gameFile, serialNum);
    commonWordOffset := ReadZWORD();
    verifyLength     := ReadZWORD();
    verifyChecksum   := ReadZWORD();
    Files.ReadRec(gameFile, padding1);
    fkeyOffset       := ReadZWORD();
    Files.ReadRec(gameFile, padding2);
    alphabetOffset   := ReadZWORD();
    Files.ReadRec(gameFile, padding3);
  END;
END ReadHeader;

PROCEDURE LoadPages(block, numBlocks: CARDINAL; addr: ADDRESS);
VAR bytesRead: CARDINAL;
BEGIN
  Files.SetPos(gameFile, LONG(block) * LONG(BLOCKSIZE));
  bytesRead := Files.ReadBytes(gameFile, addr, numBlocks * BLOCKSIZE);
END LoadPages;

PROCEDURE GetByte(VAR page, offset: CARDINAL): CARDINAL;
VAR ptr  : POINTER TO ARRAY [0..0] OF BYTE;
    byte : BYTE;
BEGIN
  IF page < residentBlocks THEN
    ptr  := basePtr + page * BLOCKSIZE + offset;
    byte := ptr^[0];
  ELSE
    Files.SetPos(gameFile, LONG(page) * LONG(BLOCKSIZE) + LONG(offset));
    Files.ReadByte(gameFile, byte);
  END;
  INC(offset); IF offset = BLOCKSIZE THEN offset := 0; INC(page) END;
  RETURN ORD(byte)
END GetByte;

PROCEDURE GetWord(VAR page, offset: CARDINAL): CARDINAL;
BEGIN
  RETURN GetByte(page,offset) * 256 + GetByte(page,offset)
END GetWord;

PROCEDURE CloseFile;
BEGIN
  Files.Close(gameFile)
END CloseFile;

PROCEDURE Save;
BEGIN
  (* TODO: implement *)
END Save;

PROCEDURE Restore;
BEGIN
  (* TODO: implement *)
END Restore;

PROCEDURE Check(VAR header, info: Header): BOOLEAN;
BEGIN
  IF  (ORD(info.versionAndFlags[0]) = ORD(header.versionAndFlags[0]))
  AND (info.release            = header.release)
  AND (info.residentBytes      = header.residentBytes)
  AND (info.gameOffset         = header.gameOffset)
  AND (info.vocabOffset        = header.vocabOffset)
  AND (info.objectOffset       = header.objectOffset)
  AND (info.variableOffset     = header.variableOffset)
  AND (info.saveBytes          = header.saveBytes)
  AND (info.commonWordOffset   = header.commonWordOffset)
  AND (info.fkeyOffset         = header.fkeyOffset)
  AND (info.alphabetOffset     = header.alphabetOffset)
  THEN
    header.versionAndFlags[1] := info.versionAndFlags[1];
    header.verifyLength       := info.verifyLength;
    header.verifyChecksum     := info.verifyChecksum;
    RETURN TRUE
  END;
  RETURN FALSE
END Check;

PROCEDURE Init;
BEGIN
  ReadHeader(gameHeader);
  residentBlocks := (gameHeader.residentBytes + BLOCKSIZE - 1) DIV BLOCKSIZE;
  ALLOCATE(basePtr, residentBlocks * BLOCKSIZE);
  LoadPages(0,residentBlocks, basePtr);
  globalPtr     := basePtr + gameHeader.variableOffset;
  commonWordPtr := basePtr + gameHeader.commonWordOffset;
  defaultProps  := basePtr + gameHeader.objectOffset;

  (* TODO: complete initialization *)
END Init;

END GameFile.
