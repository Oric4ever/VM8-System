MODULE Dithering;
FROM Terminal IMPORT WriteString, WriteChar, WriteLn;
FROM XTerm IMPORT Color, Foreground, Background;

TYPE Ratio = [0..4];

PROCEDURE Dither(color1, color2: Color; dither: Ratio);
BEGIN
  Foreground(color1); Background(color2);
  CASE dither OF
  | 0 : WriteChar(' ')
  | 1 : WriteString("░")
  | 2 : WriteString("▒")
  | 3 : WriteString("▓")
  | 4 : WriteString("█")
  END;
END Dither;

VAR i,j: Color;
    k: Ratio;
BEGIN
  FOR i:=BLACK TO WHITE DO
    FOR j:=BLACK TO WHITE DO
      FOR k:=0 TO 4 DO
        Dither(i,j,k)
      END;
    END;
    WriteLn;
  END;
END Dithering.   