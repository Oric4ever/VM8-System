IMPLEMENTATION MODULE Mosaic;
FROM Terminal IMPORT GotoXY, WriteChar, WriteString, WriteLn, numRows, numCols;
FROM SYSTEM IMPORT BYTE;
FROM STORAGE IMPORT ALLOCATE;

CONST ESC = 033C;
TYPE Bitmap = POINTER TO ARRAY [0..7FFFH] OF BYTE;

PROCEDURE NewBitmap(VAR bitmap: Bitmap);
BEGIN
  ALLOCATE(bitmap, numRows * numCols)
END NewBitmap;

PROCEDURE Foreground(color: Color);
BEGIN
  WriteChar(ESC); WriteChar('[');
  IF color >= 8
  THEN WriteChar('9'); WriteChar( CHR(ORD('0') + color - 8) )
  ELSE WriteChar('3'); WriteChar( CHR(ORD('0') + color) )
  END;
  WriteChar('m')
END Foreground;

PROCEDURE Background(color: Color);
BEGIN
  WriteChar(ESC); WriteChar('[');
  IF color >= 8
  THEN WriteString("10"); WriteChar( CHR(ORD('0') + color - 8) )
  ELSE WriteChar  ('4');  WriteChar( CHR(ORD('0') + color) )
  END;
  WriteChar('m')
END Background;

PROCEDURE Plot(bitmap: Bitmap; x,y: CARDINAL; color: Color);
VAR lowerDot: BOOLEAN;
    colors, index, upper, lower : CARDINAL;
BEGIN
  lowerDot := ODD(y); y := y DIV 2; GotoXY(x,y);
  upper := 0; lower := 0;
  IF bitmap <> NIL THEN
    index  := y * numCols + x;
    colors := ORD(bitmap^[index]);
    upper  := colors DIV 16;
    lower  := colors MOD 16;
  END;
  IF lowerDot THEN lower := color ELSE upper := color END;
  IF bitmap <> NIL THEN bitmap^[index] := upper * 16 + lower END;
  Foreground(upper);
  Background(lower);
  WriteString("▀");
END Plot;

END Mosaic.                                                           