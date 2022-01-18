MACROS=mcode.h
SOURCES3=vm3.c bios.c
CFLAGS=-g -O3

all: vm3

vm3: $(SOURCES3) $(MACROS)
	gcc $(CFLAGS) -o $@ -DTRACE_ALL=0 -DEMULATED_DISK=1 $(SOURCES3)

