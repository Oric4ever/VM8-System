MODULE CLOCK;
FROM Time IMPORT SetTime, Time;
VAR i, hours, minutes, seconds: CARDINAL;
BEGIN
  WRITE("Enter hours, minutes, seconds: ");
  READ(hours, minutes, seconds);
  SetTime(hours, minutes, seconds);
  
  LOOP
    FOR i:= 0 TO 30000 DO END;
    Time(hours, minutes, seconds);
    WRITELN(hours:2, ':', minutes:2, ':', seconds:2);
  END;
END CLOCK.                