MODULE Day09;
IMPORT Strings,Texts, Doubles;
FROM Strings IMPORT String;
FROM Convert IMPORT StrToCard;
EXCEPTION FileNotFound;
CONST N=1000;
VAR nums: ARRAY [0..N-1] OF LONGREAL;

PROCEDURE Valid(index: CARDINAL): BOOLEAN;
VAR number, n1, n2: LONGREAL;
    i,j: CARDINAL;
    str : ARRAY [0..7] OF CHAR;
BEGIN
  number := nums[index];
  FOR i := index-25 TO index-1 DO
    n1 := nums[i];
    IF n1+n1 # number THEN
      n2 := number - n1;
      FOR j := i+1 TO index-1 DO
        IF n2 = nums[j] THEN RETURN TRUE END;
      END;
    END;
  END;
  RETURN FALSE
END Valid;

PROCEDURE Sum(index1, index2: CARDINAL): LONGREAL;
VAR i: CARDINAL;
    sum: LONGREAL;
BEGIN
  sum := 0.0D0;
  FOR i := index1 TO index2 DO sum := sum + nums[i] END;
  RETURN sum
END Sum;

PROCEDURE SumMinMax(index1, index2: CARDINAL): LONGREAL;
VAR min, max: LONGREAL;
    i: CARDINAL;
BEGIN
  min := nums[index1];
  max := nums[index1];
  FOR i := index1+1 TO index2 DO
    IF nums[i] < min THEN min := nums[i] END;
    IF nums[i] > max THEN max := nums[i] END;
  END;
  RETURN min+max
END SumMinMax;

VAR
    input: Texts.TEXT;
    i, i2: CARDINAL;
    invalid, sum: LONGREAL;
    str: ARRAY [0..19] OF CHAR;
BEGIN
  IF NOT Texts.OpenText(input,"DAY09.TXT") THEN RAISE FileNotFound END;
  FOR i:=0 TO HIGH(nums) DO Doubles.ReadDouble(input, nums[i]) END;
  Texts.CloseText(input);

  i:=25; WHILE Valid(i) DO INC(i) END;
  invalid := nums[i];
  WRITE('Part 1: ', LONG(invalid));
  Doubles.WriteDouble(Texts.output, invalid, 15, 0);
  WRITELN;

  i := 0;
  REPEAT
    INC(i);
    i2 := i; REPEAT INC(i2); sum := Sum(i,i2) UNTIL sum >= invalid;
  UNTIL sum = invalid;
  sum := SumMinMax(i, i2);
  WRITE('Part 2: ', LONG(sum));
  Doubles.WriteDouble(Texts.output, sum, 15, 0);
  WRITELN;
END Day09.
