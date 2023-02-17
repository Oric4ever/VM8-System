SOURCES=mcode.c bdos.c bios.c
SOURCES2=vm2.c bdos.c bios.c
SOURCES3=vm3.c bdos.c bios.c
SOURCES4=vm4.c bios.c profiler.c
SOURCES4a=vm4acc.c bios.c profiler.c
SOURCES5=vm5.c bios.c
CFLAGS=-g -O3

all: m2 m2_trace m2_disk m2_disk_trace vm2 vm2_trace vm3 vm3_trace vm4 vm4_trace vm5 vm5_trace vm4acc vm4acc_trace

vm5: $(SOURCES5)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=0 -DEMULATED_DISK=1 $^

vm5_trace: $(SOURCES5)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=1 -DEMULATED_DISK=1 $^

vm4acc: $(SOURCES4a)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=0 -DEMULATED_DISK=1 $^

vm4acc_trace: $(SOURCES4a)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=1 -DEMULATED_DISK=1 $^

vm4: $(SOURCES4)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=0 -DEMULATED_DISK=1 $^

vm4_trace: $(SOURCES4)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=1 -DEMULATED_DISK=1 $^

vm3: $(SOURCES3)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=0 -DEMULATED_DISK=1 $^

vm3_trace: $(SOURCES3)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=1 -DEMULATED_DISK=1 $^

vm2: $(SOURCES2)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=0 -DEMULATED_DISK=1 $^

vm2_trace: $(SOURCES2)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=1 -DEMULATED_DISK=1 $^

m2: $(SOURCES)
	gcc $(CFLAGS) -o $@ -DLEGACY -DTRACE_ALL=0 -DEMULATED_DISK=0 $^

m2_trace: $(SOURCES)
	gcc $(CFLAGS) -o $@ -DLEGACY -DTRACE_ALL=1 -DEMULATED_DISK=0 $^

m2_disk: $(SOURCES)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=0 -DEMULATED_DISK=1 $^

m2_disk_trace: $(SOURCES)
	gcc $(CFLAGS) -o $@          -DTRACE_ALL=1 -DEMULATED_DISK=1 $^

clean:
	rm -f m2 m2_trace m2_disk m2_disk_trace vm2
