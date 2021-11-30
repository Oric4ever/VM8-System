IMPLEMENTATION MODULE FileDesc;
 IMPORT FATDIR;
 FROM NEWFAT32 IMPORT ReadFragment, Fragment;
 FROM SYSTEM   IMPORT ADR;

 PROCEDURE ReadBuffer(f: File);
 BEGIN
   ReadFragment(f^.currCluster, Fragment(f^.currentSect), ADR(f^.buffer));
   f^.ptr := ADR(f^.buffer);
 END ReadBuffer;

 PROCEDURE InitFile(f: File);
 BEGIN
   f^.marker      := FILEMARKER;
   f^.bufferEnd   := ADR(f^.buffer) + 512;
   f^.pos         := LONG(0);
   f^.bufferDirty := FALSE;
   f^.currCluster := FATDIR.StartCluster(f^.entry);
   f^.currentSect := LONG(0);
   ReadBuffer(f)
 END InitFile;

 PROCEDURE FindFile(f: File): BOOLEAN;
 BEGIN
   FATDIR.InitFind(f^.entry.desc.nameAndType.fullName);
   IF FATDIR.FindNextMatch(f^.entry) THEN
     InitFile(f);
     RETURN TRUE
   END;
   RETURN FALSE END FindFile;

END FileDesc.