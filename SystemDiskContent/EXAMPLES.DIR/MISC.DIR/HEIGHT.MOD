MODULE HEIGHT;
FROM Terminal IMPORT numRows;
BEGIN
  WRITELN('Current height is ',numRows);
  WRITE('Enter new height: '); READ(numRows);
END HEIGHT.                                                                                                     