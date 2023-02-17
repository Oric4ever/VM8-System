#include <stdio.h>
#include <string.h>

#define MAX_MODULES 32
#define NB_PROCS   128
extern unsigned int vclock;
unsigned int stats[256], ext_stats[256];

static FILE *file;
typedef struct { 
    short module_id;
    short proc_num;
    unsigned int previous_time;
    unsigned int vclock;
} time_stamp;

static time_stamp vclock_stack[100];
static int stack_index;

static unsigned int   calls    [MAX_MODULES][NB_PROCS];
static unsigned int   times    [MAX_MODULES][NB_PROCS];
static char           mod_names[MAX_MODULES][8];
static int next_id;

static int module_id(char *modname)
{
    for (int id=0; id<next_id; id++)
        if (strncmp(mod_names[id], modname, 8) == 0) return id;
    memcpy(mod_names[next_id], modname, 8);
    return next_id++;
}

static void reset_profiling(void)
{
    next_id = 0;
    for (int id=0; id<MAX_MODULES; id++)
        for (int n=0; n<NB_PROCS; n++)
            calls[id][n] = times[id][n] = 0;
    for (int opcode=0; opcode<256; opcode++)
        stats[opcode] = ext_stats[opcode] = 0;
}

static void show_profiling(void)
{
    if (file == NULL) file = fopen("profiler.log","a");
    fprintf(file, "==== Profiling module %.8s ====\n\n",mod_names[0]);
    for (int id=0; id<next_id; id++) {
        fprintf(file, "Module %.8s procs:\n", mod_names[id]);
        for (int n=0; n<NB_PROCS; n++) {
            if (times[id][n])
                fprintf(file,"#%d\t%8d calls\t%10d cycles\n",n,calls[id][n],times[id][n]);
        }
    }
    fprintf(file, "\n\n");
    fprintf(file, "Cycles spent in opcodes:\n");
    for (int opcode=0; opcode<256; opcode++)
        if (stats[opcode])
            fprintf(file,"#%02x:%10d cycles\n",opcode,stats[opcode]);
    for (int opcode=0; opcode<256; opcode++)
        if (ext_stats[opcode])
            fprintf(file,"Ext#%02x:%10d cycles\n",opcode,ext_stats[opcode]);
    fprintf(file, "\n\n");
}

void start_profile(char *modname, int proc_num)
{
    if (proc_num == 0) reset_profiling();

    int id = module_id(modname);
    calls[id][proc_num]++;

    unsigned int previous = times[id][proc_num];
    time_stamp stamp = { id, proc_num, previous, vclock };
    vclock_stack[stack_index++] = stamp;    
}

void end_profile()
{
    time_stamp start = vclock_stack[--stack_index];
    times[start.module_id][start.proc_num] = 
        start.previous_time + (vclock - start.vclock);

    if (start.proc_num == 0) show_profiling();
}

#define FETCH       5
#define FFETCH      6
#define GLOBAL      1
#define LOCAL       1
#define PROCS       7
#define POP         4
#define PPOP        7
#define PUSH        4
#define LOAD        6
#define LOCAL_LOAD  4
#define STORE       6
#define LOCAL_STORE 4
#define LOADBYTE    3
#define STOREBYTE   3
#define ADD         2
#define CMP         2
#define MUL        10
#define DIV       245
#define IMUL       20
#define IDIV      255
#define DADD        4
#define DMUL       47
#define DDIV      600
#define IMMB        3
#define IMMZ        4
#define IMMS        6
#define IMMW        6
#define IMM_nib     9
#define MODULE     12
#define MODULEm    16
#define LEAVE      35
#define JUMPPROC    8
#define CALL        PUSH + GLOBAL + PROCS + ADD + JUMPPROC
#define EXTCALL     PUSH + 7      + PROCS + ADD + JUMPPROC


int cycles[256] = {
    0,
    0,
    FETCH + IMMB + GLOBAL + PROCS + ADD*2 + LOAD + ADD + PUSH,
    FETCH + LOCAL_LOAD + PUSH,
    FETCH + LOCAL_LOAD + PUSH,
    FETCH + LOCAL_LOAD + PUSH,
    FETCH + LOCAL_LOAD + PUSH,
    FETCH + LOCAL_LOAD + PUSH,
    FETCH +  LOCAL + IMMS + ADD*2 + LOCAL_LOAD*2 + PUSH*2,
    FETCH + GLOBAL + IMMZ + ADD*2 + LOAD*2 + PUSH*2,
    FETCH + PPOP   + IMMZ + ADD*2 + LOAD*2 + PUSH*2,
    FETCH + MODULEm+ IMMZ + ADD*2 + LOAD*2 + PUSH*2,
    FETCH + IMM_nib+MODULE+ ADD   + LOAD + PUSH,
    FETCH + POP + PPOP + ADD   + LOADBYTE + PUSH,
    FETCH + POP + PPOP + ADD*2 + LOAD     + PUSH,
    FETCH + POP + PPOP + ADD*3 + LOAD*2   + PUSH*2,

    0,  // not used
    0,  // not used
    0,  // not used
    FETCH + POP + LOCAL_STORE,
    FETCH + POP + LOCAL_STORE,
    FETCH + POP + LOCAL_STORE,
    FETCH + POP + LOCAL_STORE,
    FETCH + POP + LOCAL_STORE,
    FETCH + POP*2 +  LOCAL + IMMS + ADD*2 + LOCAL_STORE*2,
    FETCH + POP*2 + GLOBAL + IMMZ + ADD*2 + STORE*2,
    FETCH + POP*2 + PPOP   + IMMZ + ADD*2 + STORE*2,
    FETCH + POP*2 + MODULEm+ IMMZ + ADD*2 + STORE*2,
    FETCH +IMM_nib+ MODULE + IMMZ + ADD + POP + STORE,
    FETCH + POP*2 + PPOP + ADD   + STOREBYTE,
    FETCH + POP*2 + PPOP + ADD*2 + STORE,
    FETCH + POP*3 + PPOP + ADD*3 + STORE*2,

    FETCH + POP + PUSH*2,
    FETCH + POP*2 + PUSH*2,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH + LOCAL + ADD + LOCAL_LOAD + PUSH,
    FETCH +  LOCAL + IMMS + ADD*2 + LOCAL_LOAD + PUSH,
    FETCH + GLOBAL + IMMZ + ADD*2 + LOAD + PUSH,
    FETCH + PPOP   + IMMZ + ADD*2 + LOAD + PUSH,
    FETCH + MODULEm+ IMMZ + ADD*2 + LOAD + PUSH,

    FFETCH + POP*3 + 3, // + size * 10
    FFETCH + POP*4 + 6, // + src length* 15 + (dst size - src length)*7
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH + LOCAL + ADD + POP + LOCAL_STORE,
    FETCH +  LOCAL + IMMS + ADD*2 + POP + LOCAL_STORE,
    FETCH + GLOBAL + IMMZ + ADD*2 + POP + STORE,
    FETCH + POP + PPOP + IMMZ + ADD*2 + STORE,
    FETCH + MODULEm+ IMMZ + ADD*2 + POP + STORE,

    FFETCH, // + extended opcode cycles
    FETCH + PPOP + LOAD*2 + PUSH*2,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,
    FETCH + GLOBAL + LOAD + PUSH,

    0, // HALT
    FETCH + POP*2 + PPOP + STORE*2,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,
    FETCH + GLOBAL + POP + STORE,

    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,
    FETCH + PPOP + LOAD + PUSH,

    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,
    FETCH + POP + PPOP + STORE,

    FETCH +  LOCAL + IMMS + ADD*2 + PUSH,
    FETCH + GLOBAL + IMMZ + ADD*2 + PUSH,
    FETCH + PPOP   + IMMZ + ADD*2 + PUSH,
    FETCH + MODULEm+ IMMZ + ADD*2 + PUSH,
    FETCH + IMMB + LEAVE,
    FETCH + IMMB + LEAVE + POP + PUSH,
    FETCH + IMMB + LEAVE + POP*2 + PUSH*2,
    0, // unimplemented
    FETCH + 2 + LEAVE,
    FETCH + 2 + LEAVE,
    FETCH + 2 + LEAVE,
    FETCH + 2 + LEAVE,
    FETCH + IMMB + PUSH + ADD,
    FETCH + IMMB + PUSH,
    FETCH + IMMW + PUSH,
    FETCH + IMMW*2 + PUSH*2,

    FETCH + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,
    FETCH + 1 + PUSH,

    FETCH + POP*2 + CMP + 3 + PUSH,
    FETCH + POP*2 + CMP + 3 + PUSH,
    FETCH + 18, // a2 replaced
    FETCH + 18, // a3 replaced
    FETCH + 28, // a4 replaced
    FETCH + 28, // a5 replaced
    FETCH + POP*2 + ADD + PUSH,
    FETCH + POP*2 + ADD + PUSH,
    FETCH + POP*2 + MUL + PUSH,
    FETCH + POP*2 + DIV + PUSH,
    FETCH + POP*2 + DIV + PUSH,
    FETCH + POP   + 4   + PUSH,
    FETCH + POP   + ADD + PUSH,
    FETCH + POP   + ADD + PUSH,
    FETCH + IMMB  + POP + ADD + PUSH,
    FETCH + IMMB  + POP + ADD + PUSH,
    
    FETCH + IMMB + POP + PUSH, // + count * 5
    FETCH + IMMB + POP + PUSH, // + count * 5
    FETCH + POP*2 + CMP + 3 + PUSH,
    FETCH + POP*2 + CMP + 3 + PUSH,
    FETCH + POP*2 + CMP + 3 + PUSH,
    FETCH + POP*2 + CMP + 3 + PUSH,
    FETCH + POP   + ADD + PUSH,
    FETCH + POP   + ADD + PUSH,
    FETCH + POP*2 + IMUL + 6 + PUSH,
    FETCH + POP*2 + IDIV + PUSH,
    FETCH + POP*2 + 2 + PUSH,
    FETCH + POP*2 + 6 + PUSH,
    FETCH + POP   + 4 + PUSH, // average
    FETCH + POP   + 4 + PUSH*2,
    0, // TODO: LONG TO REAL
    0, // TODO: REAL TO LONG

    FETCH + POP*2 + ADD + 1 + PUSH,
    FETCH + POP*2 + ADD + 1 + PUSH,
    FETCH + POP*2 + MUL + PUSH,
    0, // unimplemented
    FFETCH + POP*4 + PUSH*2, // + 25 * nb of identical chars
    FFETCH + POP*4 + DADD + 2 + PUSH*2,
    FETCH + POP*4 + DADD + PUSH*2,
    FETCH + POP*4 + DADD + PUSH*2,
    FETCH + POP*4 + DMUL + PUSH*2,
    FETCH + POP*4 + DDIV + PUSH*2, // average approx.
    FETCH + POP*4 + DDIV + PUSH*2, // average approx.
    FETCH + POP   + 4 + PUSH,
    FETCH + POP*2 + 6 + PUSH*2, // average
    FETCH + IMMW*3 + POP + 25 + PUSH,
    FETCH + POP,
    FETCH + IMMW + 4 + PUSH,

    FETCH + POP*2 + ADD + 1 + PUSH,
    FETCH + POP*2 + ADD + 1 + PUSH,
    FETCH + POP + 6 + PUSH, // + 7 * size
    0, // unimplemented
    FETCH + IMMB + PUSH*3 + 17,
    0, // TODO: REAL compare
    0, // TODO: REAL add
    0, // TODO: REAL sub
    0, // TODO: REAL mul
    0, // TODO: REAL div
    FETCH + POP*3 + PUSH + 8,
    FETCH + POP*3 + PUSH + 8,
    FETCH + POP*2 + PUSH + 3,
    FETCH + POP   + PUSH + 2,
    FETCH + IMMB + POP + 6, // average
    FETCH + IMMB + POP + 7, // average

    FETCH + IMMW + 2,
    FETCH + IMMW + POP + 4, // average
    FETCH + IMMB + 2,
    FETCH + IMMB + POP + 4, // average
    FETCH + IMMB + 2,
    FETCH + IMMB + POP + 4, // average
    FETCH + POP*2 + ADD + PUSH,
    FETCH + POP*2 + 6, // + bit * 5
    FETCH + POP*2 + ADD + PUSH,
    FETCH + POP*2 + ADD + PUSH,
    FETCH + POP + 4 + PUSH, // + bit * 5
    FETCH + PPOP + POP + 3 + EXTCALL,
    FETCH + IMMB + CALL + 3,
    FETCH + IMMB + CALL + 4,
    FETCH + POP + IMMB + CALL + 3,
    FETCH + MODULEm + IMMB + 3 + EXTCALL,

    FETCH + IMM_nib + MODULE + EXTCALL,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2,
    FETCH + CALL + 2
};

unsigned ext_cycles[] = {
    FFETCH + POP,
    0, // unimplemented
    0, // unimplemented
    FFETCH + POP*2 + 7 + PUSH*2,
    FFETCH + POP*2 + PUSH + 13, // + (bit1 + bit2) * 5 
    FFETCH + 19 + 47, // + 10 * size
    0, // TODO: min for Deallocate
    FFETCH + 43,
    FFETCH + 43,
    FFETCH + 4 + PUSH,
    0, // unimplemented
    0, // unimplemented
    0, // unimplemented
    0, // unimplemented
    FFETCH + POP*3 + 7, // + 10 * size
    FFETCH + POP*3 + 3, // + 7 * size
    FFETCH + POP + 5 + PUSH,
    FFETCH + POP*2 + 5,
    0, // unimplemented
    FFETCH + POP*3 + 8 + PUSH, // + 9 * nb of bytes not matching
    FFETCH + POP + 4,
    0, // TODO: ADDC
    0, // TODO: SUBC
    0, // TODO: MULC
    0, // TODO: DIVC
    0, // TODO: CARRY
    0, // TODO: CLC
    FFETCH + POP*2 + 8, // min value
    0, // TODO: cycles per system call
    FFETCH + POP*2 + IDIV + PUSH,
    FFETCH + IMMB + POP + PUSH, // + count * 5
    FFETCH + 34 + 47, // + 10 * size
    0, // TODO: min for Deallocate
    FFETCH + 17,
    FFETCH + 9,
    FFETCH + POP*2 + PUSH,   // + count * 5
    FFETCH + POP*3 + PUSH*2, // + count * 7
    FFETCH + POP*2 + PUSH,   // + count * 5
    FFETCH + POP*3 + PUSH*2  // + count * 7
};
    
