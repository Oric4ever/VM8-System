Oberon-07 compiler implementation notes


This Oberon-07 compiler is based on Project Oberon's compiler (www.projectoberon.com).
Mainly the code generator (in Project Oberon it targets a custom RISC design 
implemented in VHDL) has been replaced here by a new code generator targetting
a slightly extended version of Turbo Modula-2's virtual machine (that was itself
derived from Lilith's architecture, which in turn was inspired by Xerox' MESA
implementation).

These implementation notes aim to document diverging functionalities from Project
Oberon's compiler. They are grouped in the following paragraphs with no particular
order yet...

- Compiler options
- Basic types
- Keywords
- TAGGED and untagged records
- Variables, arrays and records
- Memory alignment
- Constants folding
- CASE statement
- Memory limitations
- Predefined procedures
- SYSTEM module
- Type compatibility
- Known bugs


Compiler options
================

Compiler options are currently only accessible through a special annotation format
inside comments. If the first "word" of the comment is a $ sign followed by an
option character and a + or a - character, then it is recognized as a compiler option.
Hence,

    $O- deactivates Integer Arithmetic Overflow check generation
    $O+   activates Integer Arithmetic Overflow check generation (default behavior)

    $T- deactivates Assertions and Bounds checks generation
    $T+   activates Assertions and Bounds checks generation (default behavior)

    $[+ deactivates Procedure names generation (default behavior)
    $[-   activates Procedure names generation 

Integer Arithmetic Overflow checks means that any arithmetic operation (even simple
incrementations/decrementations) in the compiled source is translated into a checked
arithmetic instruction. This means that any arithmetic overflow at run time will
be trapped. It is recommended to keep these checks (for debugging purposes for
example). Deactivating this option allows to have a slightly faster and smaller code.

Assertions and Bounds checks generation is also recommended. Every access to an array
with a non constant index will generate a runtime bound check, and assertions will
generate checks that are trapped at run time (and reveal the source line code of
the failed assertion, so programming with assertions is really recommended).
If this option is deactivated, index checks will not be generated (slightly faster 
and smaller code), and false assertions won't be trapped (still, the boolean expression
inside the ASSERT will be evaluated, as it might happen that this expression has some
side effect). E.g: ASSERT( Texts.OpenText(text, "foo.bar") )

Procedure names generation will in the future be useful for advanced debugging
features. For now it is deactivated, as this removes 5 bytes for each procedure.


Basic types
===========

The target virtual machine is a 16-bit architecture, so it was desired to keep usual
arithmetic operations to 16 bits. But as 32-bit operations might be often needed,
a LONGINT (32-bits) type has been added. In the future, a LONGREAL type might also
been added, since the REAL type is only simple precision here (IEEE754 simple precision).

So, the list of the basic types and their size is:

BOOLEAN 1 byte
CHAR    1 byte
INTEGER 2 bytes
LONGINT 2 bytes
REAL    4 bytes
BYTE    1 byte
SET     2 bytes

Please note there is no predefined STRING type despite the fact string literals exist.
The quote delimiter has been added as a valid delimiter for these string literals, so
"hello" and 'hello' are accepted.

Operations for the LONGINT are the same as INTEGER operations, however please note
there are no LONGINT literals nor constants. And an INTEGER can not be mixed with
a LONGINT in an arithmetic operations, so explicit conversions are mandatory.

E.g: to convert INTEGER to/from LONGINT :

    myLongVariable := LONG(42); (* see also LONG(1234H, 5678H) in standard procedures*)
    myIntVariable  := INT(myLongVariable)

Also, all pointer types are 16-bits (the virtual machine has a 64 KB memory).
Please note that PROCEDURE variables are 4 bytes (a module address plus a procedure
number), and for 1-byte types please also see Memory alignment below.


Keywords
========

A few additional keywords are defined:
- AND and NOT are defined as synonyms to the & and ~ operators,
- TAGGED is a keyword that might precedes RECORD (see following paragraph)


TAGGED and untagged records
===========================

The Oberon language (as defined by the Oberon-07 report) normally has only tagged
records. Manipulating a tag for each record is an additional burden for modules that
don't use type extension. This is why we have introduced the capability to handle
both tagged records and untagged records. A new keyword has thus been added to the
language: TAGGED. 
Hence,

        TYPE MyUntaggedRecord = RECORD ... END;

defines an untagged record type, whilst

        TYPE MyTaggedRecord   = TAGGED RECORD ... END;
             MyExtendedRecord = RECORD(MyTaggedRecord) ... END;

define two tagged record types (i.e. an extended record type will always be a tagged
record type).

Variables, arrays and records
==============================

Like in Turbo Modula-2, accessing variables is done thanks to offsets relative to
a base address: the module address for global variables, the stack frame address
for local variables (and parameters). Also, the opcodes of the virtual machine
favors small offsets for a more compact code. As a result, arrays and records are
not directly stored in these global locations or stack frame locations. Instead,
arrays and records are always accessed through a reference. Thus, an array or
record variable is actually a reference (an address) to the actual array/record
location. Global arrays/records are dynamically allocated in the heap when the 
module is loaded, whilst local arrays/records are dynamically allocated on the
stack when the procedure is entered.

Like in Modula-2, VARiable parameters are passed by reference, so these references
to arrays or records are just what is needed.
Unlike Turbo Modula-2, though, normal parameters (non VAR) of structured types
(arrays or records) don't need to be copied in Oberon because they have read-only
access in the procedures, so again these references to arrays or records are the
only things needed for the called procedures.

Memory alignment
================

There is no memory alignment as it is possible to access unaligned words.
However, the virtual machine architecture favors access to even offsets (of local
or global variables, or record field offsets). So, scalar variables (local/global
variables, formal parameters) are always stored at even offsets (displacements
between the base of local or global variables). This means that single CHAR, BOOLEAN,
or BYTE variables will actually use 2 bytes.

On the other hand, arrays of these 1-byte types won't use twice the needed space,
so an ARRAY 1000 OF BYTE will reserve 1000 bytes in memory.

For records, despite the privileged access to even-offset fields, it was found useful
for systems programming to have compacted records, so 1-byte fields will use 1 byte,
not two. This means that the generated code will be slightly less optimized if word
(or double word) sized fields have an odd offset (from the beginning of the record).
If this is a concern, better code will be obtained by pairing single byte fields,
or regrouping all single byte fields at the end.

E.g:
    RECORD
      a: BOOLEAN;
      b: INTEGER;
      c: REAL;
    END

will have the access to the b and c fields slightly less optimized, whilst

    RECORD
      b: INTEGER;
      c: REAL;
      a: BOOLEAN;
    END

will more optimized field accesses (in both cases, the size of the record is 7 bytes).


Constants folding
=================

Two options were possible for the implementation of the code generator:
- delaying code generation of constants, or
- systematically generating load instructions of constants, even if it means removing
these instructions afterwards for constants folding.
The first option was used, requiring a few modifications of the parser when non-symetric
operators are compiled (an instruction to load the constant first operand is generated).
As a result, constants folding is currently not complete: folding is not applied in
non-symetric operators. Also, removal of code due to constant boolean expressions in
IF/WHILE statements is not done yet. This should be enhanced in a future version.

There are a number of constants optimization though: constant operands in symetric
operators, but also optimized instructions when the second operand is constant (for
example, multiplications/divisions by a power of 2).


CASE statement
==============

The CASE statement isn't fully implemented in Project Oberon (only the CASE with a
record or pointer type is implemented). This compiler adds a jump-table implementation
of CASE for characters or small integers (in the range 0 to 255).
However, to simplify the parser, the expression following the CASE keyword is restricted
to a qualified identifier. The restriction might be removed in the future...

Also, the syntax has been a bit modified to take a vertical bar before the first 
constant :

E.g:    CASE k OF
        | 0: x := x + y
        | 1: x := x - y
        | 2: x := x * y
        | 3: x := x / y
        END


Memory limitations
==================

The compiler has been optimized to occupy the minimal space possible.
The buffer for code compilation is reset at the end of each compiled procedure, so the
buffer size (4 KB) limits the size of a single procedure to about a thousand lines.
Symbols internal to a procedure are also freed from the symbol table when that procedure
has completed compilation.
But still, memory can be a problem when dealing with many symbols: either internal to
the module under compilation, or because of symbols imported from other modules.
With the current system, there is about 22 KB of free memory for the symbols, knowing
that a single symbol takes 17 to 48 bytes depending on the identifier size.

Predefined procedures
=====================

The following "standard" procedures are defined, the list might change in future versions:

Function procedures:

ABS(x)      Absolute value of x (x of numeric type: INT, LONGINT, REAL)
ADDC(x,y)   Byte addition with carry           (see multi-precision arithmetic)
CARRY()     Returns the current value of Carry (see multi-precision arithmetic)   
DIVC(x,y)   Byte division with carry           (see multi-precision arithmetic)
ODD(x)      Returns TRUE if x is odd (x : INTEGER)
LEN(x)      Returns length of array x
LSW(x)      Returns an integer that represents the Least Significant Word of LONGINT x
MSW(x)      Returns an integer that represents the Most Significant Word of LONGINT x
MULC(x,y)   Byte multiplication with carry     (see multi-precision arithmetic)
SUBC(x,y)   Byte substraction with carry       (see multi-precision arithmetic)

Type conversion functions:

CAP(x)      Converts character x to capital (uppercase)
CHR(x)      Converts x to character (x in range 0..255)
FLOOR(x)    Returns the integer that floors REAL x
FLT(x)      Converts INTEGER x to REAL
INT(x)      Converts LONGINT x TO INTEGER
LONG(x)     Converts INTEGER x TO LONGINT
LONG(msw,lsw) Assemble two integers (most significant, least significant) to make a LONGINT
ORD(x)      Return the ordinal number of x (x of type CHAR, BOOLEAN, SET)

Proper procedures:

ASSERT(x)   Asserts expression x is TRUE, traps x being FALSE
CLC         Clears carry                       (see multi-precision arithmetic)
DEC(x)      Decrements INTEGER x 
DEC(x, n)   Decrements INTEGER x by n                     (n must be a constant)
DISPOSE(x)  Frees the record pointed by x and let x:=NIL (see memory management)
EXCL(x, n)  Excludes n from SET x                         (n must be a constant)
INC(x)      Increments INTEGER x
INC(x, n)   Increments INTEGER x by n                     (n must be a constant)
INCL(x, n)  Includes n in SET x                           (n must be a constant)
NEW(x)      Allocates a record and let x points to it    (see memory management)


SYSTEM procedures
=================

The following procedures are defined in pseudo-module SYSTEM:

Function procedures:

ADR(x)      Returns the address of variable x
FREEMEM()   Returns the size of free memory (in bytes)
GET(x)      Returns the byte present at address x (x of type INTEGER)
SIZE(x)     Returns the size (in bytes) of variable x
SYS(x)      Executes system call #x and returns a return value
VAL(T,x)    Returns the value of x viewed as type T

Proper procedures:

ALLOCATE(x,n)   Allocates n bytes on heap              (see memory management)
COPY(src,dst,n) Copies n bytes from INTEGER address src to INTEGER address dst
FILL(dst,n,val) Fills n bytes at INTEGER address dst with byte value val
DEALLOCATE(x,n) De-allocates n bytes pointed by x      (see memory management)
MARK(x)         Stores state of heap in variable x     (see memory management)
PUT(x,val)      Stores byte value val at INTEGER address x (x of type INTEGER)
RELEASE(x)      Restores state of heap from x          (see memory management)

Memory management
=================

A garbage collector has not been implemented: it seemed that using explicit
memory management was better suited to the small memory size of the target (around
40 KB when the system is loaded).
Explicit memory management procedures have thus be defined, first there are the
classic NEW/DISPOSE procedures from Pascal and Modula-2.

When variable x is of type POINTER TO R (R can only be a record type in Oberon),
then NEW(x) allocates a new record of type R in the heap and its address is assigned
to variable x. Conversely, DISPOSE(x) then frees (deallocates) this record, and x
is reset to pointer value NIL.

For low-level system modules, it was found a bit restrictive to be only able to 
allocate records, so level procedures ALLOCATE and DEALLOCATE were added:
ALLOCATE(x, n) allocates n bytes on heap and the address of these bytes is stored
in variable x. Conversely, DEALLOCATE(x, n) frees these n bytes and x is reset to
value 0. Care must be taken that the address given to DEALLOCATE really is one that
was obtained with ALLOCATE, and that the number of bytes was the same as the one
specified in the corresponding ALLOCATE call.

Even if DISPOSE and DEALLOCATE take care to merge the freed memory blocks to contiguous
free memory blocks of the heap, using NEW/DISPOSE or ALLOCATE/DEALLOCATE not in a
stack (Last In First Out) manner might lead to fragmentation of the heap space.

This is why a second explicit management mechanism was added: MARK and RELEASE.
RELEASE(x) allows to return to the heap all the memory that was allocated since the
last MARK(x), as if all the small blocks allocated since the last MARK were DISPOSEd of
with a single RELEASE procedure call. However, the different variable pointers are
not reset so care must be taken to not use these pointers after the RELEASE call.

Also it is not advised at all to mix DISPOSE (or DEALLOCATE) and RELEASE calls.

ALLOCATE and DEALLOCATE are classic procedures of the Modula-2 STORAGE module.
MARK and RELEASE were defined as an extension in Turbo Modula-2. 



Multi-precision arithmetic
==========================

Having a standard INTEGER type of 16 bits might seem very limited nowadays.
A few predefined procedures (and opcodes in the virtual machine) have been added to make
multi-precision libraries more efficient, especially for small platforms like the main
target which is an 8-bit platform.
So the following functions do 8-bit calculations only, but taking into account a 8-bit
carry register, so that it is easy to propagate the carry in multi-byte calculations.

ADDC(x,y) => returns (x+y+carry) MOD 256, carry is set to (x+y+carry) DIV 256
SUBC(x,y) => returns (x-y-carry) MOD 256, carry is set to (x-y-carry) DIV 256
MULC(x,y) => returns (x*y+carry) MOD 256, carry is set to (x*y+carry) DIV 256
DIVC(x,y) => returns (carry*256+x) DIV y, carry is set to (carry*256+x) MOD y

Current value of carry can be obtained with the function procedure CARRY(), or
cleared with procedure CLC.

Please note that there's no LSB or MSB standard procedures (respectively Least
Significant Byte and Most Significant Byte) since the behavior of MOD and DIV for
negative dividends has been changed in the virtual machine and now provides what
is expected from MOD 256 and DIV 256.

A multi-precision arithmetic library is provided in module BigNum.


Type compatibility
==================

The Oberon-07 report states that the type of VARiable parameters "must be identical
to the corresponding actual parameter's type, except in the case of a record, where
it must be a base type of the corresponding actual parameter's type".
This exception in the strict equality of VARiable parameters types has been extended
to POINTER types: the pointer type of a formal parameter passed by VARiable can be a
base type of the corresponding actual parameter's type.


Known bugs
==========

1. Arrays (or Records) of procedures with parameters

When a procedure address is not stored in simple variable but instead inside an array
or a record, and when this indirectly called procedure requires parameters, then the
the sequence of generated opcodes is not in correct order. 
The problem is that parameters are pushed on stack before the indirect call opcode
is executed and thus the call will not use the correct procedure address.
This also means that the bug doesn't show up for procedures that don't have parameters.
Fixing the bug is not straightforward as it would require some opcodes reordering.
A simple workaround is to temporarily copy the procedure address in a simple procedure
variable.

E.g:

TYPE Function = PROCEDURE(a: INTEGER):INTEGER;
VAR i: INTEGER;
    function1: Function;
    functions: ARRAY 10 OF Function;
PROCEDURE Square(a: INTEGER):INTEGER;
BEGIN RETURN a*a
END Square;

BEGIN
  FOR i:=0 TO 9 DO functions[i] := Square END;
  i := ...;
  i := functions[i](i);  (* CAUTION this line generates bad code *)
  function1 := functions[i];  (* using a simple variable works *)
  i := function1(i);     (* so this is a workaround... *)
  

2. Tag CASE switch in recursive procedures

When using a type tag CASE on a parameter of a recursive procedure, there will be a
type compatibility error issued by the compiler when calling the recursive procedure
from inside the CASE statement. This is because the type of the CASE variable is
temporarily switched to the selected type, which works fine in most cases, but here
the variable is the formal parameter of the recursive procedure so this formal parameter
changes type as well although it shouldn't. I will try adding a variable with the same
name instead, in order not to change the formal parameter's type...
For now, a simple workaround is to use a temporary variable...

E.g:

TYPE RootType = TAGGED RECORD END;
     PtrType  = POINTER TO RootType;
     SubType1 = RECORD(RootType) a: INTEGER END;
     SubType2 = RECORD(RootType) left,right: PtrType END;
 
PROCEDURE Recursive(p: PtrType);
BEGIN
  CASE p OF
  | SubType1: Out.Int(p.a, 5)
  | SubType2: Recursive(p.left);  (* CAUTION formal parameter p is now of type SubType2 *)
              Recursive(p.right)  (* CAUTION same here *)
  END
END Recursive;

workaround:

PROCEDURE Recursive(ptr: PtrType);
VAR p: PtrType;
BEGIN
  p := ptr;
  CASE p OF
  | SubType1: Out.Int(p.a, 5)
  | SubType2: Recursive(p.left);  (* formal parameter ptr is of type PtrType *)
              Recursive(p.right)  (* same here *)
  END
END Recursive;


