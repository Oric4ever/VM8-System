MODULE GRIDTEST;
FROM Terminal IMPORT ClearScreen, numRows, numCols;
FROM Boxes IMPORT VertLine, HorizLine, Box, REGULAR, BOLD;

VAR x,y: CARDINAL;
BEGIN
  numCols := 100;
  ClearScreen;
  FOR y:=0 TO numRows-2      DO HorizLine(0,y,numCols-2,REGULAR) END;
  FOR x:=0 TO numCols-2 BY 2 DO  VertLine(x,0,numRows-2,REGULAR) END;
  Box(10,5, 60,20,BOLD);
  Box(40,10,80,30,BOLD);
END GRIDTEST.                                                                                                             