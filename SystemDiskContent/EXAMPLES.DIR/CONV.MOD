MODULE CharConv;
VAR c: CHAR;
    i: INTEGER;
    o: CARDINAL;
BEGIN
  c := 200C;
  o := ORD(c);
  i := o;
  o := i;
  
  (* i := ORD(c) is not accepted, ORD(c) is a CARDINAL *)
  
  WRITELN("ORD(c) = ", ORD(c));
  
  c := CHR( ORD(c) - 1 ); (* conversions are mandatory *)
  
  c := CHR( ORD(c) DIV 2 ); (* what the hell would mean 'divide a char by 2' ?*)
  
  WRITELN("ORD(c) = ", ORD(c));
END CharConv.
  