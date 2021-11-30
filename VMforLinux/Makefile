SOURCES3=vm3.c bdos.c bios.c
CFLAGS=-g 

all: vm3

vm3: $(SOURCES3)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=0 -DEMULATED_DISK=1 $^

