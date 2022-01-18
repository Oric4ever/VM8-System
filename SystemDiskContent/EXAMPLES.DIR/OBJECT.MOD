MODULE Object;

TYPE
    ClassPtr* = POINTER TO Class;
    Class*    = TAGGED RECORD
                  super* : ClassPtr;
                END;

    Instance* = TAGGED RECORD
                  class* : ClassPtr;
                END;

VAR class*: ClassPtr;

PROCEDURE Init*(VAR object: Instance; class: ClassPtr);
BEGIN
  object.class := class
END Init;

BEGIN
  NEW(class);
  class.super := class
END Object.