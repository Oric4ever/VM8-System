MODULE WIDTH;
FROM Terminal IMPORT numCols;
BEGIN
  WRITELN('Current width is ',numCols);
  WRITE('Enter new width: '); READ(numCols);
END WIDTH.                                                                                                         