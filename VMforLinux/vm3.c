#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <inttypes.h>
#include <string.h>
#include <assert.h>
#include <setjmp.h>
#include <malloc.h>
#include <unistd.h>
#include <termios.h>
#include <math.h>
#include "mcode.h"

#define BDOS_MCD 0
#define PAGE0_CHECK 1
#define PAGE3_CHECK 1
#define FFF 1
#define FFF2 1
#define MIN_ALLOC_SIZE 8

enum continuation {
    TRANSFER_TO_NEW_PROCESS = 0x0a75,
    FETCH_ROUTINE = 0x041a,
    RESUME_PROCESS = 0x0d0e,
    RETURN_FROM_ERROR1 = 0x0bb5,
    RESUME_TRANSFER_ONCE_OVERLAY_LOADED = 0x0cb2,
    PROC_CALL_AFTER_OVERLAY_LOADED = 0x0a9b,
    FINISH_LEAVE_ONCE_OVERLAY_LOADED = 0x0ba8,
    RETURN_FROM_EXCEPTION = 0x0cd3,
    RETURN_FROM_HALT = 0x0d1b,
    RETURN_FROM_IOEXCEPTION = 0x0cfd
};

FILE *tracelog;
bool trace;
void error(int n, word hl, word bc);
bool mcode_interp(void);
void save_context(word coroutine_var, enum continuation retaddr);
void coroutine_transfer(word to_corout);
void system_call(void);
static int proc_num;
#define TRANSIENT 1
#define Z80 2

word overlay[512][64];  // memory for the overlay
word localstack[10000]; // just to detect empty stack in procedures
int nbframes=0;

int high_mem = 0xfefe; // 0xe406;    // end of transient memory
byte mem[65536+65536]; // additionnal space due to bug in EDIT2
byte *MEM(int addr)  {
#if PAGE0_CHECK
    if (addr>=0x000 && addr<0x0100) fprintf(tracelog,"PAGE0: Warning: access to byte at address %04x\n", addr);
#else
#if PAGE3_CHECK
    if (addr>=0x300 && addr<0x0400) fprintf(tracelog,"PAGE3: Warning: access to byte at address %04x\n", addr);
#endif
#endif
    return &mem[addr];
}
word *WMEM(int addr) {
#if PAGE0_CHECK
    if (addr>=0x000 && addr<0x0100) fprintf(tracelog,"PAGE0: Warning: access to word at address %04x\n", addr);
#else
#if PAGE3_CHECK
    if (addr>=0x300 && addr<0x0400) fprintf(tracelog,"PAGE3: Warning: access to word at address %04x\n", addr);
#endif
#endif
    return (word *)(&mem[addr]);
}
dword *DMEM(int addr) {
#if PAGE0_CHECK
    if (addr>=0x000 && addr<0x0100) fprintf(tracelog,"PAGE0: Warning: access to dword at address %04x\n", addr);
#endif
    return (dword *)(&mem[addr]);
}
qword *QMEM(int addr) {
#if PAGE0_CHECK
    if (addr>=0x000 && addr<0x0100) fprintf(tracelog,"PAGE0: Warning: access to qword at address %04x\n", addr);
#endif
    return (qword *)(&mem[addr]);
}

/* let's have GLOBAL address in a VM's register instead of in memory */
#undef GLOBAL_PTR
word GLOBAL_PTR;

/* same with STACK_LIMIT (= HEAP - 60) */
#undef STACK_LIMIT
word STACK_LIMIT;

/* move FREE_LIST variable */
#undef FREE_LIST
#define FREE_LIST 0x0104

#define BC OUTER_FRAME
word OUTER_FRAME, IP, IntFlag, HL, A, carry;
word LOCAL_PTR;
word STACK_PTR;
word bdos_global;
#define TOP (STACK[0])
#define IORESULT *WMEM(0x300)
#define HLRESULT *WMEM(0x302)
#define STD_EXCEPTIONS_MODULE *WMEM(0x320)

void   push(word w)   { STACK_PTR-=2; TOP = w; }
void  dpush(dword dw) { STACK_PTR-=4; *(dword *)STACK = dw; }
void  fpush(float f)  { STACK_PTR-=4; *(float *)STACK = f; }
void  qpush(double g) { STACK_PTR-=8; *(double *)STACK = g; }

word   pop(void)      { STACK_PTR+=2; return STACK[-1]; }
sword ipop(void)      { return pop(); }
#if FFF2
word  ppop(void)      { if (!TOP) error(7,0,0); return TOP & 0xff00 ? pop() : pop() + 0xff00; }
#else
word  ppop(void)      { if (!TOP) error(7,0,0); return pop(); }
#endif
dword dpop(void)      { STACK_PTR+=4; return *(dword *)(STACK-2); }
float fpop(void)      { STACK_PTR+=4; return *(float *)(STACK-2); }
qword qpop(void)      { STACK_PTR+=8; return *(double *)(STACK-4); }

byte  high(word w)    { return w >> 8; }
byte   low(word w)    { return w & 0xff; }
void  load(word w)    { push(w); }
#define  dload(lval)  { dpush(*(dword *)(&(lval))); }
#define  qload(lval)  { qpush(*(double *)(&(lval))); }
#define  store(lval)  { word w = pop(); (lval) =  w; }
#define dstore(lval)  { dop = dpop(); *(dword *)(&lval) = dop; }
#define qstore(lval)  { qop = qpop(); *(double *)(&lval) = qop; }

void  swap() { word tmp=pop(), up=TOP; TOP=tmp; push(up); }

void overflow(void)         { error(12,0,0); }
void stack_overflow(void)   {
    fprintf(tracelog,"Stack overflow !!\n");
    fflush(tracelog);
    error(6,0,0); 
}
bool z80(byte op);

void save_continuation(enum continuation continuation)
{
    push(continuation);
//    fprintf(tracelog, "Saving continuation at [%04X]: %04x\n",STACK_PTR,continuation);
}

void load_overlay(word module) // routine 0baf
{
//    old code:
//    fprintf(tracelog,"Need to load overlay module %04X (%.8s)\n", module, MEM(module) - 14);
//    push(A); // AF
//    save_continuation(RETURN_FROM_ERROR1);
//    error(1,module,OUTER_FRAME);

    word module_desc = module - 80;
    int record = WMEM(module)[1] / 32;
    int offset = WMEM(module)[1] % 32 * 2; // 64 words per record
    if (overlay[record][offset] == WMEM(module)[-2]) { // verify checksum
        if (TRACE_ALL) fprintf(tracelog,"Loading overlay module %.8s\n",MEM(module)-14);
        word length = overlay[record][offset+1];
        word destination = WMEM(module)[-3]; // load address
        if (TRACE_ALL) fprintf(tracelog,"Length: %d, Address: %04x\n",length,destination);
        // now search which module is currently loaded at this overlay address
        for (word mod1 = *(word *)(mem + 0x030C); mod1; mod1 = WMEM(mod1)[32])
            if (WMEM(mod1+80)[-3] == destination) {
                WMEM(mod1+80)[0] |= TRANSIENT; // mark the module absent
                if (TRACE_ALL) fprintf(tracelog,"Unload module %.8s\n",MEM(mod1+80-14));

            }
        // now load the module
        memcpy(MEM(destination), &overlay[record][offset+2], length);
        // check the version again
        if (WMEM(destination+length)[-1] != WMEM(module)[-2])
            fprintf(tracelog,"Error with final checksum\n");
        // mark the module loaded
        WMEM(module)[0] &= ~TRANSIENT;
    } else {
        fprintf(stderr, "System overlay load error\n");
        exit(1);
    }
}

void leave_check(int n)
{
    if ((n & 0x80) == 0) return; // was a call to an inner proc
    if (OUTER_FRAME == 0) return; // was an intra-module call

    GLOBAL_PTR = OUTER_FRAME;
    if (GLOBAL_PTR == 1) { // returned from the main module
        if (TRACE_ALL) fprintf(tracelog,"Returning from a module's INIT\n");
//        error(10,0,0); // now this isn't an error anymore
    } else {
        // otherwise it was an inter-module call
//      fprintf(tracelog,"GLOBAL_PTR := %04x\n",GLOBAL_PTR);
        assert( !(GLOBAL[0] & Z80) );
        if (GLOBAL[0] & TRANSIENT) { // need to reload caller module
//        fprintf(tracelog,"Error 1 after leave\n");
            save_continuation(FINISH_LEAVE_ONCE_OVERLAY_LOADED);
            load_overlay(GLOBAL_PTR);
        }
    }
}

word proc_addr(int n)
{
    word addr_location = GLOBAL[-1] - 2*n;
    if (TRACE_ALL) {
        fprintf(tracelog,"At IP=%04x (GLOBAL=%04x), ",IP,GLOBAL_PTR);
        fprintf(tracelog,"fetching %.8s's proc #%d\n",(char *)(GLOBAL-7),n);
        fprintf(tracelog,"\t[%04x]=%04x\n",addr_location,WMEM(addr_location)[0]);
        fflush(tracelog);
    }
    return WMEM(addr_location)[0] + addr_location + 1;
}

word ext_proc_addr(word module_base, int n)
{
    char *name = (char *)(WMEM(module_base)-7);
    word addr_location = WMEM(module_base)[-1] - 2*n;
    if (TRACE_ALL) {
        fprintf(tracelog,"At IP=%04x (GLOBAL=%04x), ",IP,GLOBAL_PTR);
        fprintf(tracelog,"fetching %.8s's proc #%d\n",name?name:"(null)",n);
    }
    return WMEM(addr_location)[0] + addr_location + 1;
}

#ifdef LEGACY
bool scanner_fetch(void)        // SCANNER.2
{
//    fprintf(tracelog,"Z80 procedure %.8s.%d\n","SCANNER",2);
    OUTER_FRAME = GLOBAL_PTR;
    int indx = *MEM(0x006c);
    if (indx == 128) {
        fprintf(tracelog,"Calling procedure %.8s.%d\n","SCANNER",34);
        push(GLOBAL_PTR);
        push(LOCAL_PTR);
        push(IP);
        int return_addr = *WMEM(0x0075)-2+0x5d;
        push(return_addr);
        proc_num = 34;
        IP = proc_addr(proc_num);
        while (IP != return_addr) mcode_interp();
            ;
        fprintf(tracelog,"Returned from procedure %.8s.%d\n","SCANNER",34);
        fprintf(tracelog,"\n\t LOCAL=%04X GLOBAL=%04X HEAP=%04X STACK=%04X",
              LOCAL_PTR, GLOBAL_PTR, STACK_LIMIT, STACK_PTR); //, IORESULT);
        fprintf(tracelog," TOP=%04X\n",TOP);
        fprintf(tracelog,"\nIP=%04X OP=%02X %02X %02X\n",IP,*MEM(IP),*MEM(IP+1),*MEM(IP+2));
        pop();
        LOCAL_PTR = pop();
        GLOBAL_PTR = pop();
        return false;
    }

    assert(*MEM(0x006c) != 128);
    byte c = *MEM(0x0080+indx);
    indx ++;
    *MEM(0x006c) = indx;
    if (c == 0x1A) c = 0xFF; // convert EOF into 0xFF
    GLOBAL[3] = c;
    *WMEM(0x006e) = *WMEM(0x006e) + 1;
    if ((GLOBAL[2] & 1) == 0) {
        fprintf(tracelog,"Return from procedure SCANNER.2\n");
        return true;
    }
    if (c >= ' ') {
       *MEM(0x0070) = *MEM(0x0070) + 1;
       if (*MEM(0x0072)) {
           fprintf(tracelog,"Return from procedure SCANNER.2\n");
           putchar(c); 
           return true; 
       }
    }
    push(GLOBAL_PTR);
    push(LOCAL_PTR);
    push(IP);
    int return_addr = *WMEM(0x0075)-2+0x5d;
    push(return_addr);
    proc_num = 33;
    fprintf(tracelog,"Calling procedure %.8s.%d\n","SCANNER",33);
    IP = proc_addr(proc_num);
    while (IP != return_addr) mcode_interp();
        ;
    fprintf(tracelog,"Return from procedure %.8s.%d\n","SCANNER",33);
    fprintf(tracelog,"\n\t LOCAL=%04X GLOBAL=%04X HEAP=%04X STACK=%04X",
            LOCAL_PTR, GLOBAL_PTR, STACK_LIMIT, STACK_PTR); //, IORESULT);
    fprintf(tracelog," TOP=%04X\n",TOP);
    fprintf(tracelog,"\nIP=%04X OP=%02X %02X %02X\n",IP,*MEM(IP),*MEM(IP+1),*MEM(IP+2));
    pop();
    LOCAL_PTR = pop();
    GLOBAL_PTR = pop();
    return false;
}

void scan_next_token(void)  // SCANNER.39
{
    // on entry: HL = adr of Z80 routine (after 87 nn)
    // DE = [031c] 
    // TOP = 0ad3 (Z80 return address in OPCODE 87)
    push(0);    // BC
    push(IP);   // DE
    push(LOCAL_PTR);    // IX
    push(0);    // HL
    LOCAL_PTR = STACK_PTR;
    push(0);    // HL


    GLOBAL[6] = 0;
    GLOBAL[9] = 7;

    push(0);  // just to have the same stack ptr
    while (GLOBAL[3] <= ' ') { // skip-whitechar loop 
//        fprintf(tracelog,"... in skip-whitechar loop\n");
        scanner_fetch();
        fprintf(tracelog,"SCANNER.2 returned char %c\n",GLOBAL[3]);
    }
    pop();

    byte char_read = GLOBAL[3];
    GLOBAL[25] = *WMEM(0x006e) - 1;     // file position ?
    GLOBAL[26] = *MEM(0x0070);
    word type_table = GLOBAL[24];
    byte char_type = char_read < 128 ? *MEM(type_table+char_read) : 0;
    GLOBAL[5] = char_type;

    if (char_type == 0x0a) { // identifier start
        word ident_buf  = GLOBAL[11];
        word ident_size = 0;
        while (char_type==0x0a || char_type==0x0b) {
            
            push(0); // AF
            push(0); // HL
            push(0); // DE
            push(0); // return addr
            if (ident_size++ < 127) *MEM(ident_buf++) = char_read;
 //           fprintf(tracelog,"...%c in identifier read loop\n",char_read);
            scanner_fetch();
            fprintf(tracelog,"SCANNER.2 returned char %c\n",GLOBAL[3]);
            pop(); pop(); pop(); pop();
            char_read = GLOBAL[3];
            char_type = *MEM(type_table+char_read);
        }
        *MEM(ident_buf) = 0; // end identifier
        LOCAL[3] = 1;
        fprintf(tracelog,"SCANNER.39 has read identifier [%s]\n",mem+GLOBAL[11]);
    } else fprintf(tracelog,"SCANNER.39 has returned\n");

    pop();
    pop();
    LOCAL_PTR = pop();
    pop();
}

void find_control_sequence()    // procedure EDITDISK.24
{
#define NB_CONTROLS 46
    static char *sequences[NB_CONTROLS] = {
        // cursor movements:
        "[[D", // "S", // left
        "H", // alternative
        "[[C", // "D", // right
        "A", // word left
        "F", // word right
        "E", // up
        "X", // down
        "W", // scroll down
        "Z", // scroll up
        "R", // page up
        "[[6~", //"C", // page down
        "QS",// left on line
        "QD",// right on line
        "QE",// top of page
        "QX",// bottom of page
        "QR",// top of file
        "QC",// end of file
        "QB",// beginning of block
        "QK",// end of block
        "QP",// last cursor position

        "V", // insert on/off
        "N", // insert line
        "Y", // delete line
        "QY",// delete to end of line
        "T", // delete right word
        "G", // delete char under cursor
        "_", // delete left char
        "_", // alternative

        // block commands
        "KB",// mark block begin
        "KK",// mark block end
        "KH",// Mark block end
        "KC",// copy block
        "KV",// move block
        "KY",// delete block
        "KR",// read block from disk
        "KW",// write block to disk
        
        // Misc. editing commands
        "KD",// end edit
        "KS",// save and re-edit
        "KQ",// abandon edit
        "KJ",// delete file
        "I", // tab
        "QI",// indent on/off
        "QF",// find
        "QA",// find and replace
        "L", // repeat last find
        "P"  // control character prefix
    };

    word table = pop(); // 0 : user sequences, 1 : system (wordstar) sequences
    word result_addr = pop();
    word length = pop();
    word string = pop();

    fprintf(tracelog,"Looking for string [%s] (len: %d) in table %d\n",mem+string,length,table);
    fflush(tracelog);
    if (table==0) // only look into system sequences
        for (int i=0; i<NB_CONTROLS; i++) {
            int seq_length = strlen(sequences[i]);
            if (seq_length < length) continue;
            int n;
            for (n=0; n<length; n++) {
                char c = *MEM(string+n);
                if (c < ' ') c += 0x40;
                // if (c >= 0x60) c -= 0x20;  // pb with ~ for example
                if (c != sequences[i][n]) break;
            }
            if (n == length) { // match found
                *WMEM(result_addr) = i+1;
                push(seq_length == length); // return 0 if substring, 1 if exact match
                fprintf(tracelog,"Control %ssequence found\n", seq_length==length ? "" : "sub-");
                fflush(tracelog);
                return;
            }
        }
    push(2); // not found
    fprintf(tracelog,"Control sequence not found\n");
    fflush(tracelog);
}

void find_keyword(word addr, int code) // procedure PASS1.36
{
#define NB_KEYWORDS 43
    typedef struct { char *name; int code; } key_assoc;
    static key_assoc table[NB_KEYWORDS] = {
     {"IF",34},{"DO",30},{"OF",41},{"OR",65},{"IN",51},{"TO",42},{"BY",29},
     {"END",13},{"VAR",20},{"NOT",66},{"DIV",61},{"AND",64},{"MOD",62},{"FOR",28},{"SET",50},
     {"THEN",35},{"ELSE",10},{"CASE",40},{"FROM",15},{"TYPE",19},{"WITH",38},{"EXIT",32},{"LOOP",31},
     {"BEGIN",23},{"ELSIF",11},{"WHILE",37},{"UNTIL",12},{"CONST",18},{"ARRAY",47},{"RAISE",39},
     {"REPEAT",36},{"RECORD",49},{"IMPORT",16},{"RETURN",33},{"MODULE",22},{"EXPORT",17},
     {"POINTER",48},{"FORWARD",67},
     {"PROCEDURE",21},{"QUALIFIED",26},{"EXCEPTION",14},
     {"DEFINITION",25},
     {"IMPLEMENTATION",24}
    };

//    fprintf(tracelog,"Z80 procedure PASS1.36\n");
fprintf(tracelog,"Looking for keyword [%s]\n",mem+addr);

    switch (code) {
    case 0: // case sensitive search of string
        if (strlen(mem+addr) < 15)
            for (int i=0; i<NB_KEYWORDS; i++)
                if (strcmp(mem+addr, table[i].name)==0) {
                    push(table[i].code);
                    return;
                }
        break;
    case 1: // case insensitive search of string
        if (strlen(mem+addr) < 15)
            for (int i=0; i<NB_KEYWORDS; i++)
                if (strcasecmp(mem+addr, table[i].name)==0) {
                    push(table[i].code);
                    return;
                }
        break;
    case 2: // search keyword by code
        for (int i=0; i<NB_KEYWORDS; i++)
            if (table[i].code == code) {
                strcpy(mem+addr, table[i].name);
                push(1);
                return;
            }
        break;
    }
    push(0);    // ie. not found
}

void find_ident(word symbol_list, word identifier, bool case_insensitive)
// procedure SCANNER.22
{
//    fprintf(tracelog,"Z80 procedure SCANNER.22\n");
    word symbol = *WMEM(symbol_list);
    while (symbol) {
        word symbol_name = *WMEM(symbol+2);
        bool compare = case_insensitive ? strcasecmp(mem+identifier,mem+symbol_name)
                                        : strcmp(mem+identifier, mem+symbol_name);
        if (compare==0) break; // identifier found
        symbol = *WMEM(symbol); // next symbol in list
    }
    push(symbol); // return the symbol found (or null)
}
#endif

bool z80(byte op)
{ 
    char *module_name = ((char *)GLOBAL) - 14;
    word return_addr = pop();


    fprintf(tracelog,"Z80 procedure %.8s.%d at %04X\n",module_name,proc_num,IP);

    {
        fprintf(tracelog,"Z80 procedure %.8s.%d at %04X\n",module_name,proc_num,IP);
        fprintf(tracelog,"Not implemented!!\n");
        fflush(tracelog);
        FILE *fd = fopen("dump","w");
        fwrite(mem+IP,1024,1,fd);
        fclose(fd);
        exit(1);
    }

    IP = return_addr;
    if (op && OUTER_FRAME) {
        GLOBAL_PTR = OUTER_FRAME;
        fprintf(tracelog,"operand = %02x => GLOBAL PTR := %04x\n",op,GLOBAL_PTR);
    } else 
        fprintf(tracelog,"operand = 0, GLOBAL unchanged\n");

    OUTER_FRAME = GLOBAL_PTR;
    leave_check(0x80);
    return true;
}

void restore_frame(int size)
{
    STACK_PTR      = LOCAL_PTR;
    OUTER_FRAME    = pop();
    LOCAL_PTR      = pop();
    int current_IP = IP;
    IP             = pop();
//    if (IP==0x0ad3) fprintf(tracelog,"should return to Z80 routine!!!\n");
    STACK_PTR     += size;  // drop caller's arguments
}

void leave(int n)
{
    restore_frame(2*n & 0xff);
//    if (current_IP==0x5495)
//        fprintf(tracelog,"After LEAVE: IP=%04X LOCAL=%04X GLOBAL=%04X STACK=%04X\n",
//                IP,LOCAL_PTR,GLOBAL_PTR,STACK_PTR);
    leave_check(n);
}

void fct_leave(int n)
{
    int tmp = pop(); // get result
    restore_frame(2*n & 0xff);
    push(tmp);
    leave_check(n);
}

void dfct_leave(int n)
{
    int tmp = dpop(); // get result
    restore_frame(2*n & 0xff);
    dpush(tmp);
    leave_check(n);
}

void qfct_leave(int n)
{
    double tmp = qpop(); // get result
    restore_frame(2*n & 0xff);
    qpush(tmp);
    leave_check(n);
}

void longreal_opcode(void) {
    word op;
    double qtmp, qop;

    switch (FETCH) {
    case  0: qload(LOCAL[IFETCH]); break;
    case  1: qload(GLOBAL[FETCH]); break;
    case  2: qload(STACK_ADDRESSED[FETCH]); break;
    case  3: qload(EXTERN(FETCH)[FETCH]); break; 
    case  4: qstore(LOCAL[IFETCH]); break;
    case  5: qstore(GLOBAL[FETCH]); break;
    case  6: qstore(STACK_ADDRESSED[FETCH]); break;
    case  7: qstore(EXTERN(FETCH)[FETCH]); break;
    case  8: FETCH; // immediate byte not used
             op=pop(); qload(QARRAY_INDEXED(op)); break;
    case  9: FETCH; // immediate byte not used
             qtmp=qpop(); op=pop(); QARRAY_INDEXED(op)=qtmp; break;
    case 10: qfct_leave(FETCH); break;

    /* new opcodes added */

    case 11: dpush((int)qpop());              break; // qtod
    case 12: fpush((float)qpop());            break; // qtof
    case 13: qpush((double)dpop());           break; // dtoq
    case 14: qpush((double)fpop());           break; // ftoq
    case 15: qtmp=qpop(); qop=qpop();                // qcp
             push(qop>qtmp); push(qop<qtmp);  break;
    case 16: qtmp=qpop(); qpush(qpop()+qtmp); break; // qadd
    case 17: qtmp=qpop(); qpush(qpop()-qtmp); break; // qsub
    case 18: qtmp=qpop(); qpush(qpop()*qtmp); break; // qmul
    case 19: qtmp=qpop(); qpush(qpop()/qtmp); break; // qdiv
    case 20: break; // no opcode
    case 21: qpush(-qpop());                  break; // qneg
    case 22: qpush(fabs(qpop()));             break; // qabs
    }
}

void unimplemented(byte code) {
    fprintf(tracelog, "Unimplemented opcode %02x\n",code);
    exit(1);
}

void table_jump(word value)
{
    word low_bound = WFETCH; 
    value += 0x8000;    // for unsigned comparison
    word high_bound = WFETCH;
    if (value >= low_bound && value-low_bound <= high_bound) {
        word relative_addr = WFETCH; // relative return addr
        word abs_addr = relative_addr + IP - 1;
        word jump_addr = IP + 2*(value-low_bound);
        sword rel_jump = *WMEM(jump_addr);
        IP = rel_jump + jump_addr + 1;
        if (rel_jump < 0) push(abs_addr);
    } else {
        IP += (high_bound+2)*2;
    }
}

/* Each block in the free-blocks list has the following structure :
  Offset 0: 0x3ae3 marker
  Offset 2: next block address
  Offset 4: size
  ...
  Offset size-4: size (hence offset 4 if block size = 8
  Offset size-2: 0x3ae3 marker
*/
word allocate(int size) {

    if (size%2) size++;
    if (size<MIN_ALLOC_SIZE) size=MIN_ALLOC_SIZE;

    word block_ptr = FREE_LIST;
    word block;
    for ( ; ; block_ptr = block) {
        block     = *WMEM(block_ptr);
        if (block == 0) {   // end of blocks in free-blocks list
            if (STACK_LIMIT+size > STACK_PTR) error(5,0,0);
            block = STACK_LIMIT-60;    // STACK_LIMIT actually has a 60 bytes margin
            STACK_LIMIT += size;
            break;
        }
        word block_size = *WMEM(block+2);
        word extra = block_size - size;
        if (extra == 0) { // perfect size block
            *WMEM(block_ptr) = *WMEM(block); // replace previous link with next block addr
            break;
        } else if (extra >= MIN_ALLOC_SIZE) { 
            // we can split the block in two: left part already has link to next block
            word left_part = block;
            block += extra;
            *WMEM(block-2) = extra; // size is present at both end of a block
            *WMEM(left_part+2) = extra;
            break;
        }   // else block is too small
    }
    for (int i=0; i<size; i++) *MEM(block+i)=0;
//    fprintf(tracelog,"Allocated block at %04x\n",block);
    return block;
}

void allocate_without_tag(int size) {
    word block = allocate(size);
    word result_var = pop();
    *WMEM(result_var) = block;
}

void allocate_with_tag(int size) {
    word block = allocate(size+2);
    word tag = pop();
    *WMEM(block) = tag;
    word result_var = pop();
    *WMEM(result_var) = block+2;
}

bool remove_block_in_freelist(word block_to_remove)
{
    word ptr_block = FREE_LIST;
    word block = *WMEM(ptr_block);
    while (block) {
        if (block == block_to_remove) {
            *WMEM(ptr_block) = *WMEM(block); // remove block in freeblocks list
            return true;
        }
        ptr_block = block;
        block = *WMEM(ptr_block);
    }
    return false;
}

word find_ptr_to_block(word block_to_search)
{
    for (word ptr = FREE_LIST; *WMEM(ptr)!= 0; ptr = *WMEM(ptr))
        if (*WMEM(ptr) == block_to_search) return ptr;
    return 0;
}

void deallocate(word block, word size) {
    if (size%2) size++;
    if (size<MIN_ALLOC_SIZE) size=MIN_ALLOC_SIZE;

//    fprintf(tracelog,"Deallocate block at %04x\n",block);
    fflush(tracelog);
    if (block==0) error(7,0,0);

    word block1size = *WMEM(block-2);  // potential block just before
    word block_before = block - block1size; // calculate its potential address
    if (*WMEM(block_before+2) == block1size) { // check the size is the same
        word ptr1 = find_ptr_to_block(block_before);
        if (ptr1) { // the block just before is in the free list
            *WMEM(ptr1) = *WMEM(block_before);  // remove it from the free list
            size += block1size;
            block = block_before;
//fprintf(tracelog,"Merged two blocks of size %d and %d\n",size,block1size);
        }
    }

    word block_after = block + size;
    word ptr2 = find_ptr_to_block(block_after);
    if (ptr2) { // the block just after is in the free list
        *WMEM(ptr2) = *WMEM(block_after);  // remove it from the free list
        word block2size = *WMEM(block_after+2);
        size += block2size;
//fprintf(tracelog,"Merged two blocks of size %d and %d\n",size,block2size);
    }

    if (STACK_LIMIT == block + size + 60) { // enlarge heap if the block is just before
        STACK_LIMIT = block + 60;
    } else { // make this block first in the free list
        *WMEM(block+size-2) = size;
        *WMEM(block+2) = size;
        *WMEM(block) = *WMEM(FREE_LIST);
        *WMEM(FREE_LIST) = block;

//        fprintf(tracelog,"Free-blocks list:\n");
//        while (block) {
//            fprintf(tracelog,"\t-> block at %04x\n",block);
//            block = *WMEM(block+2);
//        }
    }
//    fprintf(tracelog,"Deallocate finished\n");
//    fflush(tracelog);
}

void deallocate_without_tag(word var_addr, word size) {
    word block = *WMEM(var_addr);
    *WMEM(var_addr) = 0;
    deallocate(block, size);
}

void deallocate_with_tag(word var_addr, word size) {
    word block = *WMEM(var_addr) - 2;
    *WMEM(var_addr) = 0;
    deallocate(block, size + 2);
}

void mark(word var_addr)
{
    word heap = STACK_LIMIT - 60;
    *WMEM(var_addr) = heap;
    STACK_LIMIT += 2;
    *WMEM(heap) = *WMEM(FREE_LIST); // save free list
    *WMEM(FREE_LIST) = 0;           // and continue with an empty list
}

void release(word var_addr)
{
    word ptr = *WMEM(var_addr);
    *WMEM(var_addr) = 0;
    if (ptr == 0) error(7,0,0);
    *WMEM(FREE_LIST) = *WMEM(ptr);
    STACK_LIMIT = ptr + 60;
}

void proc_call(int n, word outer_frame)
{
    OUTER_FRAME = outer_frame;
    push(IP);
    IP = proc_addr(n);
    proc_num = n;
}

void toplevel_proc_call(int n) {
    proc_call(n,0);
}

void show_module(word module_base)
{
    static word modules[100];
    static word nb_modules=0;
    for (int i=0; i<nb_modules; i++)
        if (modules[i]==module_base) return;
    modules[nb_modules++] = module_base;

    word proc0_addr = WMEM(module_base)[-1];
    printf("Module %04X: proc0 addr at %04X\n",module_base,proc0_addr);
    for (int i=0; i<8; i++)
        printf("\tModule %d: %04X\n",i,MODULE(i));
    for (int i=0; i<32; i++)
        printf("\tProc %d: %04X\n",i,proc_addr(i));
}

void finish_ext_proc_call(word module_base, int n)
{
    GLOBAL_PTR = module_base;
    if (TRACE_ALL) {
//        if (GLOBAL_PTR != OUTER_FRAME) show_module(GLOBAL_PTR);
        fprintf(tracelog, "calling proc #%d in module %.8s...\n",n,MEM(module_base)-14); 
    }
    assert( (*MEM(module_base) & Z80) == 0); // no Z80 code
    IP = proc_addr(n);
    proc_num = n;
}

void overlay_proc_call(word module_base, int procnum)
{
// Previous code :
//    fprintf(tracelog,"Loading overlay module\n");
//
//    pop();           // drop IP (it will be saved in the context instead)
//    push(procnum);   // push procedure number instead
//    save_continuation(PROC_CALL_AFTER_OVERLAY_LOADED);
    load_overlay(module_base);
    GLOBAL_PTR = module_base;
    IP = proc_addr(procnum);
    proc_num = procnum;
}

void ext_proc_call(word module_base, int procnum)
{
    push(IP);
    OUTER_FRAME = GLOBAL_PTR;  // calling module
    GLOBAL_PTR = module_base;  // changing module now to avoid loading overlay twice
    if ( *MEM(module_base) & TRANSIENT ) { // routine 0a95
        overlay_proc_call(module_base, procnum);
        return; // the rest will be done by the continuation
    } else finish_ext_proc_call(module_base,procnum);
}

void long_to_int()
{
    dword dw = dpop();
    if (-32768 <= dw && dw <= 32767) push(dw);
    else overflow();
}

void add_with_overflow()
{
    sword b = ipop(), a = ipop(), c = a+b;
    push(c);
    if ((a<0 && b<0 && c>=0) || (a>=0 && b>=0 && c<0)) overflow();
}

void sub_with_overflow()
{
    sword b = ipop(), a = ipop(), c = a-b;
    push(c);
    if ((a<0 && b>=0 && c>=0) || (a>=0 && b<0 && c<0)) overflow();
}

bool in_bitset(word a, word b)
{
    if (a >= 16) return false;
    return (b >> a ) & 1;
}

void copy_block()
{
    word size=pop(), src=pop(), dst=pop();
#if PAGE0_CHECK
    if (src<256 || dst <256) {
        fprintf(tracelog,"PAGE0: Copy %d bytes-block from %04x to %04x\n", size,src,dst); 
        for (int i=0; i<size; i++) 
            fprintf(tracelog, "%c",MEM(src)[i]);
        fprintf(tracelog,"\n");
    }
#endif
    while (size--) {
#if FFF2
        byte tmp = *MEM( src<256 ? src+0xff00 : src);
        *MEM( dst<256 ? dst+0xff00 : dst) = tmp;
        src++; dst++;
#else
        *MEM(dst++) = *MEM(src++);
#endif
    }
}

void copy_string()
{
    word src_size=pop(), dst_size=pop(), src=pop(), dst=pop();
    if (src==0 || dst==0) error(7,0,0);
#if PAGE0_CHECK
    if (src<256 || dst <256) {
        fprintf(tracelog,"PAGE0: Copy %d bytes-string from %04x to %04x\n", src_size,src,dst); 
        for (int i=0; i<src_size; i++) 
            fprintf(tracelog, "%c",MEM(src)[i]);
        fprintf(tracelog,"\n");
    }
#endif
#if FFF2
    if (src<256) src+=0xff00;
    if (dst<256) dst+=0xff00;
#endif
    while (src_size && *MEM(src)) {
        if (dst_size--) *MEM(dst++) = *MEM(src++);
        else error(15,0,0);
        src_size--;
    }
    while (dst_size--) *MEM(dst++)=0;
}

void string_compare(void)
{
    word str2_size=pop(), str1_size=pop(), str2=pop(), str1=pop();
//    for (int i=0x100; i<0x200; i++) {
//        fprintf(tracelog,"%02x ", *MEM(i));
//        if (i%16==15) fprintf(tracelog,"\n");
//    }
    while (true) {
        byte c1 = str1_size ? *MEM(str1++) : 0;
        byte c2 = str2_size ? *MEM(str2++) : 0;
//        fprintf(tracelog,"Compare byte %02x with %02x\n", c1, c2);
        if (c1 < c2) { push(0); push(1); break; }
        if (c1 > c2) {
//            str2 = (str2 & 0xff)|0x100; push(str2); push(str2-1); break; // mimic original bug
            push(1); push(0); break;
        }
        if (c1 == 0) { push(0); push(0); break; }
        str1_size--; str2_size--;
    }
}

void reserve(int n)
{
    word sizew = (n+1)/2;
    if (STACK_PTR - 2*sizew < STACK_LIMIT) stack_overflow();
    while (sizew--) push(0);
    push(STACK_PTR);
}

void string_reserve()
{
    word src=pop(), sizew = (pop()+1)/2;
#if PAGE0_CHECK
    if (src<256) fprintf(tracelog,"PAGE0: Reserve %d bytes-string on stack, copy from %04x\n", 2*sizew,src); 
#endif
    if (STACK_PTR - 2*sizew < STACK_LIMIT) stack_overflow();
    STACK_PTR -= 2*sizew;
#if FFF2
    if (src<256) src+=0xff00;
#endif
    for (int i=0; i<sizew; i++)
        STACK[i] = WMEM(src)[i];
    push(STACK_PTR);
}

void fill(void)
{
    byte val  = pop();
    word size = pop();
    word addr = pop();
#if PAGE0_CHECK
    if (addr<256) fprintf(tracelog,"PAGE0: Fill %d bytes-block at %04x\n", size,addr); 
#endif
#if FFF2
    if (addr<256) addr+=0xff00;
#endif
    for (int i=0; i<size; i++) *MEM(addr+i) = val;
}

void scan(void)
{
    byte val  = pop();
    word size = pop();
    word addr = pop();

    for (int i=0; i<size; i++)
        if (*MEM(addr+i) == val) { push(i); return; }
    push(-1);
}

void move_block(void)
{
    word size = pop();
    word dst  = pop();
    word src  = pop();
#if PAGE0_CHECK
    if (src<256 || dst <256) {
        fprintf(tracelog,"PAGE0: Move %d bytes-block from %04x to %04x\n", size,src,dst); 
        for (int i=0; i<size; i++) 
            fprintf(tracelog, "%c",MEM(src)[i]);
        fprintf(tracelog,"\n");
    }
#endif
#if FFF2
    if (src<256) src+=0xff00;
    if (dst<256) dst+=0xff00;
#endif
    if (dst > src) {
        while (size--) *MEM(dst+size) = *MEM(src+size);
    } else {
        for (int i=0; i<size; i++) *MEM(dst+i) = *MEM(src+i);
    }
}

void enter(int n)
{
    word size = 0xff - n;
    push(LOCAL_PTR);
    push(OUTER_FRAME);
    LOCAL_PTR = STACK_PTR;
    push(IP);   // routine's start address
    if (STACK_PTR - size < STACK_LIMIT) stack_overflow();
    STACK_PTR -= size;
    push(0);  // just for easier comparison
}

void save_context(word coroutine_var, enum continuation retaddr)
{
//    fprintf(tracelog,"Transfer from [%04X]=%04X ",coroutine_var, *WMEM(coroutine_var));

    save_continuation(retaddr);
//    fprintf(tracelog,"Saved context, continuation at [%04X] = %04X\n",STACK_PTR,retaddr);
    /* save context: 16 words */
    push(1); push(1); push(OUTER_FRAME);
    push(IP); push(1); push(1);
    push(LOCAL_PTR); push(1); push(1); push(1);
    push(*WMEM(FREE_LIST));
    push(STACK_LIMIT);
    push(0); // push(IntFlag);
    push(GLOBAL_PTR);
    push(1); 
    push(HL); // HL may contain GLOBAL_PTR
    *WMEM(coroutine_var) = STACK_PTR;
}

void do_continuation(enum continuation continuation)
{
    int proc_num;
//    fprintf(tracelog,"Doing continuation [%04X] = %04X\n", STACK_PTR-2, continuation);
    word module_base;
    switch (continuation) {
        case RETURN_FROM_ERROR1: // return address after an error 1
                     pop(); // AF
                     do_continuation( pop() );
                     break;
        case RESUME_TRANSFER_ONCE_OVERLAY_LOADED:
                     BC = pop();
                     HL = pop();
                     A  = pop(); // AF
                     do_continuation( pop() );
                     break;
        case RETURN_FROM_EXCEPTION:
                     pop(); pop(); pop(); // drop 3 parameters
//                     fprintf(tracelog,"Return from error !!\n");
                     do_continuation( pop() );
                     break;
        case TRANSFER_TO_NEW_PROCESS:
                     // A on context contains the procedure number
                     proc_num = A;
                     if (GLOBAL[0] & TRANSIENT) overlay_proc_call(GLOBAL_PTR, proc_num);
                     else finish_ext_proc_call(GLOBAL_PTR, proc_num);
                     break;
        case FINISH_LEAVE_ONCE_OVERLAY_LOADED: break; // just a jump Next to do
        case RESUME_PROCESS: break; // just a jump Next to do
        case FETCH_ROUTINE: break; // this continuation installed in exception handler
//        case RETURN_FROM_HALT: push(IntFlag); IntFlag = 1; break;
        case PROC_CALL_AFTER_OVERLAY_LOADED:
                     // swap stack top (procedure number) and IP
                     proc_num = pop(); push(IP);
                     finish_ext_proc_call(HL, proc_num);
                     break;
        case RETURN_FROM_IOEXCEPTION: // TODO: end of IOTRANSFER
        default:
                     fprintf(tracelog,"Unknow continuation addr: %04X\n",continuation);
                     exit(1);
                     break;
    }
}

void coroutine_transfer(word to_corout) {
//    fprintf(tracelog,"to [%04X]=%04X\n",to_corout,*WMEM(to_corout));
    /* switch stack */
//    fprintf(tracelog, "Switching to coroutine stack\n");
    STACK_PTR  = *WMEM(to_corout);
    /* restore context */
    HL = pop(); // HL
    pop(); // HL'
    GLOBAL_PTR = pop(); // 0x312
    IntFlag    = pop(); // 0x314
    STACK_LIMIT   = pop(); // 0x316
    *WMEM(FREE_LIST) = pop();   // 0x318
    *WMEM(0x031a) = pop(); // 0x31a
    *WMEM(0x031c) = pop(); // 0x31c
    pop(); // IY
    LOCAL_PTR  = pop(); // IX
    pop(); // DE'
    pop(); // BC'
    IP = pop(); // DE
    BC = pop(); // BC
    pop(); // AF'

    push(HL); // HL
    push(BC); // BC
    if (GLOBAL[0] & TRANSIENT) { // we are resuming a module that has been swapped!
        save_continuation(RESUME_TRANSFER_ONCE_OVERLAY_LOADED); // push continuation
        load_overlay(GLOBAL_PTR);
        return; // continuation will do the rest
    }
    BC = pop();
    HL = pop();
    A = pop();  // AF
    do_continuation( pop() );
}

word upper_frame()
{
    if (LOCAL_PTR) {
        word outer_frame = LOCAL[0];
        word upper_frame = LOCAL[1];
        if (outer_frame == 1) return 0;
        if (outer_frame) GLOBAL_PTR = outer_frame;
        IP = LOCAL[2];
        LOCAL_PTR = upper_frame;
        return upper_frame;
    }
    return 0;
}

#define CONOUT 3
#define CR 0x0D
#define LF 0x0A

void write_char(char c) { bios(CONOUT, c); }
void writeln() { write_char(CR); write_char(LF); }

void write_string(char *msg)
{
    for (int i=0; msg[i]; i++) write_char(msg[i]);
}

void write_module_name(word module_addr)
{
    for (int i=0; i<8; i++) {
        char c = MEM(module_addr-78+32*2)[i];
        if (c == 0) c = ' ';
        write_char(c);
    }
}

word get_exception_module(int exception_num)
{
    if      (exception_num == 0) return STD_EXCEPTIONS_MODULE;
    else if (exception_num == 1) return GLOBAL_PTR;
    else return GLOBAL[-9-(exception_num-2)];
}

void raise_to_kernel() {
    word msg_size = pop();
    word msg_addr = pop();
    word exception_num = pop();
    bool propagate_exception = (exception_num != 10); // #10 : end of coroutine
    word exception_module;

    if (exception_num == 6) { // #6: out of memory
        propagate_exception = upper_frame(LOCAL_PTR);
        STACK_PTR = LOCAL_PTR - 3;
        exception_num = 5;
    }

    exception_module = get_exception_module(exception_num >> 8);
    exception_num    = exception_num & 0xFF;
    fprintf(tracelog, "Exception #%d, module %.8s\n", exception_num, MEM(exception_module-14));
    if (msg_size > 60) msg_size = 60;

    word save_local  = LOCAL_PTR;
    word save_global = GLOBAL_PTR;
    word save_ip     = IP;
    if (propagate_exception) {
        do {
            fprintf(tracelog, "Searching exception handler...\n");
            fprintf(tracelog, "LOCAL = %04x\n", LOCAL_PTR);
            fprintf(tracelog, "PROC START = %04x\n", LOCAL[-1]-2);
            fprintf(tracelog, "IP = %04x\n", IP);
            word proc_ptr = LOCAL[-1] - 2 - 2; // pointer to exception handler rel addr
            word except_handler = WMEM(proc_ptr)[0];
            if (except_handler && (except_handler & 0x8000) == 0) { // exception handlers are present
                word except_table = proc_ptr + 1 + except_handler;
                int nb_handlers = MEM(except_table)[0];
                word first_handler_ptr = except_table + nb_handlers*4 - 1;
                word handler_start = first_handler_ptr + WMEM(first_handler_ptr)[0] + 1;
                fprintf(tracelog, "%d exception handlers starting at %04x \n", nb_handlers, handler_start);
                if (IP <= handler_start) { // if IP > handler_start, we already are in one of these exception handlers
                    except_table++; // skip nb of exception handlers
                    for (int i=0; i<nb_handlers; i++, except_table+=4) {
                        fprintf(tracelog, "Handler #%d: exception #%d, module %.8s\n",
                                i, MEM(except_table)[0], MEM(get_exception_module(MEM(except_table)[1]))-14);
                        if (MEM(except_table)[0] == 0 // all-exceptions catch
                        || (MEM(except_table)[0] == exception_num &&
                            get_exception_module(MEM(except_table)[1]) == exception_module)) {
                            // we found a suitable exception handler
                            except_table += 2; // point to the relative addr of handler
                            IP = except_table + 1 + WMEM(except_table)[0];
                            STACK_PTR = LOCAL_PTR - 3;
                            return;
                        }
                    }
                }
            }
        } while (upper_frame());
        fprintf(tracelog, "Corresponding exception handler not found\n");
    }

    // either we couldn't propagate exception or couldn't find an exception handler
    GLOBAL_PTR = exception_module;
    word exception_name = proc_addr(exception_num);
    int exception_name_size = *MEM(exception_name);
    printf("\n\nException not caught: ");
    if (exception_module != STD_EXCEPTIONS_MODULE)
        printf("%.8s.", MEM(exception_module)-14, MEM(exception_name)+1);
    printf("%.*s", exception_name_size, MEM(exception_name+1));

    printf(" in module %.8s\n", MEM(save_global)-14);
    printf("Parameters: %d, %d, %d\n", TOP, BC, HL);
    if (msg_addr) printf("%*s\n", msg_size, MEM(msg_addr));
    printf("Aborting...\n");
    exit(1);
}

void assertion(word linenum, bool b) {
    if (!b) {
        printf("\nAssertion fails in module %.8s, line %d\n", ((char *)GLOBAL)-14, linenum);
        save_context(0x030a,RETURN_FROM_HALT); coroutine_transfer(0x0308);
    }
}

void typecheck(word linenum, word typetag1, word typetag2) {
    if (typetag1 != 0) {
        while (typetag1 != 0  &&  typetag1 != typetag2) {
            typetag1 = *WMEM(typetag1);
        }
        if (typetag1 == 0) {
            printf("\nType guard failure in module %.8s, line %d\n", ((char *)GLOBAL)-14, linenum);
            save_context(0x030a,RETURN_FROM_HALT); coroutine_transfer(0x0308);
        }
    }
}

void error(int n, word hl, word bc)
{
    if (n != 1) fprintf(tracelog, "ERROR %d !!!\n",n);
    push(n);
    push(0);
    push(0);
    HL = hl; BC = bc;
    raise_to_kernel();
}

void newprocess(void)
{
    word var_addr  = pop();
    word wrk_size  = pop();
    word wrk_addr  = pop();
    word module_ptr  = pop();
    word proc_number = pop();

    if (wrk_size < 70) error(5,0,0);
    word current_stack = STACK_PTR;
    STACK_PTR = wrk_addr + wrk_size;
    push(0); // this one will be left on stack
    /* save context: 17 words */
    push(TRANSFER_TO_NEW_PROCESS);  // return addr
    push(proc_number);  // word 15
    push(0);            // word 14
    push(1);            // word 13
    push(0);            // should be IP, but IP will be calculated later
    push(0);            // word 11
    push(0);            // word 10
    push(0);            // word  9
    push(0x041a);       // word  8
    push(0);            // word  7 
    push(0);            // word  6
    push(0);            // FREE_LIST
    push(wrk_addr + 60);// STACK_LIMIT
    push(0);            // interrupt flag
    push(module_ptr);   // GLOBAL_PTR
    push(0);            // word  1
    push(module_ptr);   // word  0
    *WMEM(var_addr) = STACK_PTR;
    STACK_PTR = current_stack;
}


/* Mimic Z80 context to remove all differences
void newprocess(void)
{
    word context[18] = {
        0,      // word 0: [0x030e] = HL
        0,      // word 1: [0x0310] = HL'
        0,      // word 2: [0x0312] = GLOBAL_PTR
        0,      // word 3: [0x0314] = Interrupt flag
        0,      // word 4: [0x0316] = stack limit
        0,      // word 5: [0x0318] = freeblocks list
        0,      // word 6: [0x031a] = save1
        0,      // word 7: [0x031c] = save2
        0x041a, // word 8: IY
        0,      // word 9: IX (frame pointer)
        0,      // word 10:DE'
        0,      // word 11:BC'
        0,      // word 12:DE (IP)
        1,      // word 13:BC 
        0,      // word 14:AF'
        0,      // word 15:AF
        0,      // return addr
        0       //
    };
    word var_addr  = pop();
    word wrk_size  = pop();
    word wrk_addr  = pop();
    word module_ptr  = pop();
    word proc_number = pop();
    
    if (wrk_size < 70) error(5,0,0);
    context[4] = wrk_addr + 60;
    word context_addr = wrk_addr + wrk_size - 36;
    *WMEM(var_addr) = context_addr;
    context[0] = context[2] = module_ptr;
    context[15] = unknown * 256;
    context[16] = 0x0a75; // TODO: fix me, we have to prepare the EXTERN PROC
    for (int i=0; i<18; i++) *WMEM(context_addr+2*i) = context[i];
}
*/

void extend_opcode(void) {
    word op, op2;
    sword iop, iop2;
    dword dop, dop2;
    int res;
    
    switch (FETCH) {
    case  0: STACK_PTR+=2; break; // drop
    case  1: push(IntFlag); IntFlag=1; break; // Push Int flag and disable Int
    case  2: IntFlag=pop(); break; // Pop Int flag
    case  3: dpush( -dpop() ); break;
    case  4: op2=pop(); op=pop(); push( (1<<(op2+1))-(1<<op) ); break;
    case  5: allocate_without_tag(pop()); break;
    case  6: op=pop(); deallocate_without_tag(pop(),op); break;
    case  7: mark(pop()); break;
    case  8: release(pop()); break;
    case  9: push(STACK_PTR-STACK_LIMIT-1); break; // FreeMem()
    case 10: op=pop(); save_context(pop(),RESUME_PROCESS); coroutine_transfer(op); break;
    case 11: // IOTRANSFER
    case 12: newprocess(); break;
    case 13: op2=pop(); op=pop(); IORESULT=bios(op,op2); break;
    case 14: move_block(); break;
    case 15: fill(); break;
    case 16: // INP
    case 17: // OUT
    case 18: string_reserve(); break;
// new opcodes
    case 19: scan(); break;
    case 20: assertion(WFETCH, pop()); break;
    case 21: op  = pop()+pop()+carry; push(op & 0xFF); carry = op >> 8; break; // ADDC
    case 22: op2 = pop(); op = pop()-op2-carry; push(op & 0xFF); carry = op >> 15; break; // SUBC
    case 23: op  = pop()*pop()+carry; push(op & 0xFF); carry = op >> 8; break; // MULC
    case 24: op2 = pop(); op = pop() + (carry << 8); push(op/op2); carry = op%op2; break;  // DIVC
    case 25: push(carry); break; // CARRY
    case 26: carry = 0; break; // CLC
    case 27: op = pop(); typecheck(WFETCH, pop(), op); break; // TYPCHK
    case 28: op2 = pop(); op = pop(); push(bios(op,op2)); break; // SYS
    case 29: iop2=ipop(); iop=ipop(); push(iop>=0 ? iop%iop2 : (iop%iop2 + iop2) % iop2); break; // signed Modulo
    case 30: op2=FETCH; dop=(dword)ipop(); push((sword)(dop >> op2)); break; // ASR
    case 31: allocate_with_tag(pop()); break;
    case 32: op=pop(); deallocate_with_tag(pop(), op); break;
    case 33: op = pop(); push(op==0 ? 0 : WMEM(op)[-1]); break; // get tag
    case 34: op = pop(); push( op >= 'a' && op <= 'z' ? op - 32 : op); break; // CAP

    default:
        unimplemented(*MEM(--IP));
    }
}

bool mcode_interp(void)
{
  word op, tmp;
  sword iop, itmp;
  dword dop, dtmp;
  float fop, ftmp;

  static bool enter_proc = false;

  if (TRACE_ALL) {
    if (enter_proc) localstack[++nbframes]=STACK_PTR;
//    fprintf(tracelog,"\n\tLOCAL=%04X GLOBAL=%04X STACK=%04X",
//         LOCAL_PTR, GLOBAL_PTR, STACK_PTR);
//    fprintf(tracelog,"\n\tLOCAL=%04X GLOBAL=%04X HEAP=%04X LIMIT=%04X STACK=%04X",
//         LOCAL_PTR, GLOBAL_PTR, STACK_LIMIT-60, STACK_LIMIT, STACK_PTR);
//    fprintf(tracelog," [FF6D]=%04x",*WMEM(0xFF6D));
//    if (STACK_PTR==localstack[nbframes]) fprintf(tracelog,"  EMPTY\n");
//    else
        fprintf(tracelog," TOP=%04X \n",TOP);
    fprintf(tracelog,"\nIP=%04X OP=%02X %02X %02X \n", IP, *MEM(IP), *MEM(IP+1), *MEM(IP+2));
    fflush(tracelog);
  }
  enter_proc = *MEM(IP)==0xD4 || (*MEM(IP)==0x40 && *MEM(IP+1)==0x0A);

  switch (FETCH) {
  case 0x00: error(16,0,0); break;
  case 0x01: raise_to_kernel(); break;
  case 0x02: push( proc_addr(FETCH) ); break;
  case 0x03: load( LOCAL[3]); break;
  case 0x04: load( LOCAL[4]); break;
  case 0x05: load( LOCAL[5]); break;
  case 0x06: load( LOCAL[6]); break;
  case 0x07: load( LOCAL[7]); break;
  case 0x08: dload(LOCAL[IFETCH]); break;
  case 0x09: dload(GLOBAL[FETCH]); break;
  case 0x0a: dload(STACK_ADDRESSED[FETCH]); break;
  case 0x0b: dload(EXTERN(FETCH)[FETCH]); break; 
  case 0x0c: op=FETCH; load( EXTERN(op/16)[op%16] ); break;
  case 0x0d: op=pop(); load(BARRAY_INDEXED(op)); break;
  case 0x0e: op=pop(); load(WARRAY_INDEXED(op)); break; 
  case 0x0f: op=pop();dload(DARRAY_INDEXED(op)); break;

  case 0x10: load( LOCAL[0]); break;
  case 0x11: op=FETCH; tmp=LOCAL_PTR; while(op--) tmp=WMEM(tmp)[0]; push(tmp); break;
  case 0x12: longreal_opcode(); break;
  case 0x13: store( LOCAL[3]); break;
  case 0x14: store( LOCAL[4]); break;
  case 0x15: store( LOCAL[5]); break;
  case 0x16: store( LOCAL[6]); break;
  case 0x17: store( LOCAL[7]); break;
  case 0x18: dstore(LOCAL[IFETCH]); break;
  case 0x19: dstore(GLOBAL[FETCH]); break;
  case 0x1a: dstore(STACK_ADDRESSED[FETCH]); break;
  case 0x1b: dstore(EXTERN(FETCH)[FETCH]); break;
  case 0x1c: op=FETCH; store( EXTERN(op/16)[op%16] ); break;
  case 0x1d: store(tmp); op=pop();  BARRAY_INDEXED(op)=tmp; break;
  case 0x1e: store(tmp); op=pop();  WARRAY_INDEXED(op)=tmp; break;
  case 0x1f: dtmp=dpop(); op=pop(); DARRAY_INDEXED(op)=dtmp; break;

  case 0x20: load(TOP); break;
  case 0x21: swap(); break;
  case 0x22: load( LOCAL[ -2]); break;
  case 0x23: load( LOCAL[ -3]); break;
  case 0x24: load( LOCAL[ -4]); break;
  case 0x25: load( LOCAL[ -5]); break;
  case 0x26: load( LOCAL[ -6]); break;
  case 0x27: load( LOCAL[ -7]); break;
  case 0x28: load( LOCAL[ -8]); break;
  case 0x29: load( LOCAL[ -9]); break;
  case 0x2a: load( LOCAL[-10]); break;
  case 0x2b: load( LOCAL[-11]); break;
  case 0x2c: load( LOCAL[IFETCH]); break;
  case 0x2d: load(GLOBAL[FETCH]); break;
  case 0x2e: load(STACK_ADDRESSED[FETCH]); break; 
  case 0x2f: load(EXTERN(FETCH)[FETCH]); break;

  case 0x30: copy_block(); break;
  case 0x31: copy_string(); break;
  case 0x32: store( LOCAL[ -2]); break;
  case 0x33: store( LOCAL[ -3]); break;
  case 0x34: store( LOCAL[ -4]); break;
  case 0x35: store( LOCAL[ -5]); break;
  case 0x36: store( LOCAL[ -6]); break;
  case 0x37: store( LOCAL[ -7]); break;
  case 0x38: store( LOCAL[ -8]); break;
  case 0x39: store( LOCAL[ -9]); break;
  case 0x3a: store( LOCAL[-10]); break;
  case 0x3b: store( LOCAL[-11]); break;
  case 0x3c: store( LOCAL[IFETCH]); break;
  case 0x3d: store(GLOBAL[FETCH]); break;
  case 0x3e: store(STACK_ADDRESSED[FETCH]); break;
  case 0x3f: store(EXTERN(FETCH)[FETCH]); break;

  case 0x40: extend_opcode(); break;
  case 0x41: dpush(DSTACK_ADDRESSED[0]); break;
  case 0x42: load(GLOBAL[ 2]); break;
  case 0x43: load(GLOBAL[ 3]); break;
  case 0x44: load(GLOBAL[ 4]); break;
  case 0x45: load(GLOBAL[ 5]); break;
  case 0x46: load(GLOBAL[ 6]); break;
  case 0x47: load(GLOBAL[ 7]); break;
  case 0x48: load(GLOBAL[ 8]); break;
  case 0x49: load(GLOBAL[ 9]); break;
  case 0x4a: load(GLOBAL[10]); break;
  case 0x4b: load(GLOBAL[11]); break;
  case 0x4c: load(GLOBAL[12]); break;
  case 0x4d: load(GLOBAL[13]); break;
  case 0x4e: load(GLOBAL[14]); break;
  case 0x4f: load(GLOBAL[15]); break;

  case 0x50: /* temporarily replaced
                save_context(0x030a,RETURN_FROM_HALT); coroutine_transfer(0x0308); break;
             */
             fprintf(tracelog, "HALT in module %04X (%.8s)\n", GLOBAL_PTR, MEM(GLOBAL_PTR) - 14);
             leave(0x80); nbframes--;
              //  exit(1);
             break;
  case 0x51: dstore(STACK_ADDRESSED[0]); break;
  case 0x52: store(GLOBAL[ 2]); break;
  case 0x53: store(GLOBAL[ 3]); break;
  case 0x54: store(GLOBAL[ 4]); break;
  case 0x55: store(GLOBAL[ 5]); break;
  case 0x56: store(GLOBAL[ 6]); break;
  case 0x57: store(GLOBAL[ 7]); break;
  case 0x58: store(GLOBAL[ 8]); break;
  case 0x59: store(GLOBAL[ 9]); break;
  case 0x5a: store(GLOBAL[10]); break;
  case 0x5b: store(GLOBAL[11]); break;
  case 0x5c: store(GLOBAL[12]); break;
  case 0x5d: store(GLOBAL[13]); break;
  case 0x5e: store(GLOBAL[14]); break;
  case 0x5f: store(GLOBAL[15]); break;

  case 0x60: load(STACK_ADDRESSED[ 0]); break;
  case 0x61: load(STACK_ADDRESSED[ 1]); break;
  case 0x62: load(STACK_ADDRESSED[ 2]); break;
  case 0x63: load(STACK_ADDRESSED[ 3]); break;
  case 0x64: load(STACK_ADDRESSED[ 4]); break;
  case 0x65: load(STACK_ADDRESSED[ 5]); break;
  case 0x66: load(STACK_ADDRESSED[ 6]); break;
  case 0x67: load(STACK_ADDRESSED[ 7]); break;
  case 0x68: load(STACK_ADDRESSED[ 8]); break;
  case 0x69: load(STACK_ADDRESSED[ 9]); break;
  case 0x6a: load(STACK_ADDRESSED[10]); break;
  case 0x6b: load(STACK_ADDRESSED[11]); break;
  case 0x6c: load(STACK_ADDRESSED[12]); break;
  case 0x6d: load(STACK_ADDRESSED[13]); break;
  case 0x6e: load(STACK_ADDRESSED[14]); break;
  case 0x6f: load(STACK_ADDRESSED[15]); break;

  case 0x70: store(STACK_ADDRESSED[ 0]); break;
  case 0x71: store(STACK_ADDRESSED[ 1]); break;
  case 0x72: store(STACK_ADDRESSED[ 2]); break;
  case 0x73: store(STACK_ADDRESSED[ 3]); break;
  case 0x74: store(STACK_ADDRESSED[ 4]); break;
  case 0x75: store(STACK_ADDRESSED[ 5]); break;
  case 0x76: store(STACK_ADDRESSED[ 6]); break;
  case 0x77: store(STACK_ADDRESSED[ 7]); break;
  case 0x78: store(STACK_ADDRESSED[ 8]); break;
  case 0x79: store(STACK_ADDRESSED[ 9]); break;
  case 0x7a: store(STACK_ADDRESSED[10]); break;
  case 0x7b: store(STACK_ADDRESSED[11]); break;
  case 0x7c: store(STACK_ADDRESSED[12]); break;
  case 0x7d: store(STACK_ADDRESSED[13]); break;
  case 0x7e: store(STACK_ADDRESSED[14]); break;
  case 0x7f: store(STACK_ADDRESSED[15]); break;

  case 0x80: push(LOCAL_PTR +IFETCH*2); break;
  case 0x81: push(GLOBAL_PTR+ FETCH*2); break;
  case 0x82: push(pop()+FETCH*2); break;
  case 0x83: tmp=GLOBAL[-9-FETCH]; push(tmp+FETCH*2); break;
  case 0x84: leave(FETCH); nbframes--; break;
  case 0x85: fct_leave(FETCH); nbframes--; break;
  case 0x86: dfct_leave(FETCH); nbframes--; break;
  case 0x87: z80(FETCH); break; // Z80 code
  case 0x88: leave(0x80); nbframes--; break;
  case 0x89: leave(0x81); nbframes--; break;
  case 0x8a: leave(0x82); nbframes--; break;
  case 0x8b: leave(0x83); nbframes--; break;
  case 0x8c: tmp=FETCH; push(IP); IP += tmp; break;
  case 0x8d: push(FETCH); break;
  case 0x8e: push(WFETCH); break;
  case 0x8f: dtmp=*((dword *)MEM(IP)); IP+=4; dpush(dtmp); break;

  case 0x90: push( 0); break;
  case 0x91: push( 1); break;
  case 0x92: push( 2); break;
  case 0x93: push( 3); break;
  case 0x94: push( 4); break;
  case 0x95: push( 5); break;
  case 0x96: push( 6); break;
  case 0x97: push( 7); break;
  case 0x98: push( 8); break;
  case 0x99: push( 9); break;
  case 0x9a: push(10); break;
  case 0x9b: push(11); break;
  case 0x9c: push(12); break;
  case 0x9d: push(13); break;
  case 0x9e: push(14); break;
  case 0x9f: push(15); break;

  case 0xa0: op=pop(); push( pop() == op ); break;
  case 0xa1: op=pop(); push( pop() != op ); break;
  case 0xa2: op=pop(); push( pop() <  op ); break;
  case 0xa3: op=pop(); push( pop() >  op ); break;
  case 0xa4: op=pop(); push( pop() <= op ); break;
  case 0xa5: op=pop(); push( pop() >= op ); break;
  case 0xa6: op=pop(); push( pop() +  op ); break;
  case 0xa7: op=pop(); push( pop() -  op ); break;
  case 0xa8: op=pop(); push( pop() *  op ); break;
  case 0xa9: op=pop(); push( pop() /  op ); break; // unsigned division
  case 0xaa: itmp=ipop(); iop=ipop(); push(iop>=0 ? iop%itmp : (iop%itmp + itmp) % itmp); break; // unsigned Modulus
  case 0xab:           push( pop() == 0  ); break;
  case 0xac:           push( pop() +  1  ); break;
  case 0xad:           push( pop() -  1  ); break;
  case 0xae:           push( pop() + FETCH);break;
  case 0xaf:           push( pop() - FETCH);break;

  case 0xb0:             push( pop() << FETCH ); break;
  case 0xb1:             push( pop() >> FETCH ); break;
  case 0xb2: iop=ipop(); push( ipop() <  iop  ); break;
  case 0xb3: iop=ipop(); push( ipop() >  iop  ); break;
  case 0xb4: iop=ipop(); push( ipop() <= iop  ); break;
  case 0xb5: iop=ipop(); push( ipop() >= iop  ); break;
  case 0xb6:             push( !pop()         ); break;
  case 0xb7:             push(  pop() ^ -1    ); break;
  case 0xb8: iop=ipop(); push( ipop() *  iop  ); break;
  case 0xb9: itmp=ipop(); iop=ipop(); push(iop/itmp - (iop < 0 && iop%itmp!=0)); break;
  case 0xba: swap(); if (pop()) overflow(); break;
  case 0xbb: long_to_int(); break;
  case 0xbc:             push( abs(ipop())  ); break;   
  case 0xbd: iop=ipop(); dpush(iop); break;
  case 0xbe: fpush( (float)dpop() ); break;
  case 0xbf: dpush( (dword)fpop() ); break;

  case 0xc0: op=pop(); push(tmp=op+pop()); if (tmp<op) overflow(); break;
  case 0xc1: op=pop(); tmp=pop(); push(tmp-op); if (TOP>tmp) overflow(); break;
  case 0xc2: dop=(dword)ipop(); dtmp=(dword)ipop(); dtmp*=dop;
             if (dtmp<-32768 || dtmp>32767) overflow(); else push((word)dtmp); break;
  case 0xc3: system_call(); break;
  case 0xc4: string_compare(); break;
  case 0xc5: dop=dpop(); dtmp=dpop(); push(dtmp>dop); push(dtmp<dop); break;
  case 0xc6: dtmp=dpop(); dpush( dpop() + dtmp); break;
  case 0xc7: dtmp=dpop(); dpush( dpop() - dtmp); break;
  case 0xc8: dtmp=dpop(); dpush( dpop() * dtmp); break;
  case 0xc9: dtmp=dpop(); dop=dpop(); dpush(dop/dtmp - (dop<0 && dop%dtmp!=0)); break;
  case 0xca: dtmp=dpop(); dop=dpop(); dpush(dop>=0 ? dop%dtmp : (dop%dtmp + dtmp) % dtmp); break; // Modulus
  case 0xcb: push( pop() != 0 ); break;
  case 0xcc: dtmp=dpop(); dpush( abs(dtmp) ); break;
  case 0xcd: table_jump(pop()); break;
  case 0xce: IP = pop(); break;
  case 0xcf: tmp=FETCH; push(IP + tmp + (FETCH<<8)); break;

  case 0xd0: add_with_overflow(); break;
  case 0xd1: sub_with_overflow(); break;
  case 0xd2: reserve(pop()); break;
  case 0xd3: string_reserve(); break;
  case 0xd4: enter(FETCH); break;
  case 0xd5: fop=fpop(); ftmp=fpop(); push(ftmp>fop); push(ftmp<fop); break;
  case 0xd6: fop=fpop(); fpush( fpop() + fop); break;
  case 0xd7: fop=fpop(); fpush( fpop() - fop); break;
  case 0xd8: fop=fpop(); fpush( fpop() * fop); break;
  case 0xd9: fop=fpop(); fpush( fpop() / fop); break;
  case 0xda: op=pop(); tmp=pop();
             if (TOP<op || TOP>op+tmp) error(2,op+tmp,op); 
             break;
  case 0xdb: iop=ipop(); tmp=pop();
             if (ITOP<iop || ITOP>iop+tmp) error(3,iop+tmp,iop); 
             break;
  case 0xdc: op=pop(); if (TOP>op) error(2,op,0); break;
  case 0xdd: if (ITOP<0) error(4,0,0); break;
  case 0xde: tmp=FETCH; if (!(pop()&1)) { push(0); IP += tmp; } break;
  case 0xdf: tmp=FETCH; if (  pop()&1 ) { push(1); IP += tmp; } break;

  case 0xe0: tmp=FETCH; op=FETCH; IP += (op<<8)+tmp-1; break;
  case 0xe1: tmp=FETCH; op=FETCH; if (!(pop()&1)) IP+=(op<<8)+tmp-1; break;
  case 0xe2: tmp=FETCH; IP += tmp; break;
  case 0xe3: tmp=FETCH; if (!(pop()&1)) IP+=tmp; break;
  case 0xe4: tmp=FETCH; IP -= tmp; break;
  case 0xe5: tmp=FETCH; if (!(pop()&1)) IP-=tmp; break;
  case 0xe6: op=pop(); push( op | pop() ); break;
  case 0xe7: op=pop(); push( in_bitset(pop(), op) ); break;
  case 0xe8: op=pop(); push( op & pop() ); break;
  case 0xe9: op=pop(); push( op ^ pop() ); break;
  case 0xea: op=pop(); push( 1 << op ); break;
  case 0xeb: op=pop(); ext_proc_call(op, pop()); break;
  case 0xec: // fprintf(tracelog,"Call inner proc!\n");
             proc_call(FETCH,LOCAL_PTR); break;
  case 0xed: toplevel_proc_call(FETCH); break;
  case 0xee: //fprintf(tracelog,"Call outter proc!\n");
             proc_call(FETCH,pop()); break;
  case 0xef: tmp = FETCH; ext_proc_call(MODULE(tmp), FETCH); break;

  case 0xf0: tmp = FETCH; ext_proc_call(MODULE(tmp/16),tmp%16); break;
  case 0xf1: toplevel_proc_call( 1); break;
  case 0xf2: toplevel_proc_call( 2); break;
  case 0xf3: toplevel_proc_call( 3); break;
  case 0xf4: toplevel_proc_call( 4); break;
  case 0xf5: toplevel_proc_call( 5); break;
  case 0xf6: toplevel_proc_call( 6); break;
  case 0xf7: toplevel_proc_call( 7); break;
  case 0xf8: toplevel_proc_call( 8); break;
  case 0xf9: toplevel_proc_call( 9); break;
  case 0xfa: toplevel_proc_call(10); break;
  case 0xfb: toplevel_proc_call(11); break;
  case 0xfc: toplevel_proc_call(12); break;
  case 0xfd: toplevel_proc_call(13); break;
  case 0xfe: toplevel_proc_call(14); break;
  case 0xff: toplevel_proc_call(15); break;
  }
  return true;
}

struct termios orig_termios;

void reset_terminal_mode(void) {
    fclose(tracelog);
    tcsetattr(0, TCSANOW, &orig_termios); 
}

void set_conio_terminal_mode(void)
{
  struct termios termios;

  tcgetattr (0, &orig_termios);
  tcgetattr (0, &termios);
//  cfmakeraw(&termios);
  termios.c_iflag &= ~(INLCR | IGNCR | ICRNL | IXON);
//  termios.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
//  termios.c_oflag &= ~OPOST;
  termios.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG ); // | IEXTEN);
//  termios.c_cflag &= ~(CSIZE | PARENB);
//  termios.c_cflag |= CS8;
  tcsetattr (0, TCSANOW, &termios);
  atexit(reset_terminal_mode);
}


struct {
    short file_size; // not counting header
    short module_start; // actually 80 bytes before module_start
    short dependencies; // => gives addr of module dependencies
    short nb_dependencies;
    short reserved[4];
} header;

void warm_boot(void)
{
    *WMEM(0xFF0C) = 0x041A; // let the Kernel know the VM fetch routine address
    STACK_LIMIT = *(word *)(mem + 0x0316);
    STACK_PTR  = high_mem;
    word module = *(word *)(mem + 0x030C); // first module to init
    while (module != 0) {
        GLOBAL_PTR = module + 80;
        if (GLOBAL[0] & 4) { // INIT flag
            IP = proc_addr(0);  // so that proc_call pushes KERNEL's INIT addr
            proc_call(0,1);     // so that the saved context is 1, this ends the run
            while (GLOBAL_PTR != 1) mcode_interp();
        }
        module = WMEM(module)[32]; // module's link to next module
    }
    fprintf(tracelog,"Last module terminated !\n");
}

int main(int argc, char *argv[])
{
    FILE *fd;

//#if BDOS_MCD
//    /* read BDOS.MCD                           */
//    fd = fopen("BDOS.MCD","r");
//    if (fd == NULL) { printf("Cannot open BDOS.MCD\n"); exit(1); }
//    fread(&header, 1, sizeof(header), fd);
//    high_mem -= header.file_size;
//    fread(mem+high_mem,header.file_size,1,fd);
//    fclose(fd);
//
//    bdos_global = high_mem + header.module_start + 80;
//    /* adjust the procedure table address */
//    *WMEM(bdos_global-2) += high_mem;
//    /* set the dependency to Convert and TERMINAL module */
//    /*   *WMEM(bdos_global - 18) = 0x35FD;  */
//    /*   *WMEM(bdos_global - 20) = 0x5D18;  */
//#endif

#if EMULATED_DISK
    char *sysfilename = argc < 2 ?  "image.dsk" : argv[1];
    fd = fopen(sysfilename,"r");
    if (fd == NULL) { printf("Cannot open %s\n", sysfilename); exit(1); }
    fseek(fd, 512*8, SEEK_SET);   // skip first 8 sectors
    fread(mem+0x0100,512,120,fd); // read the next 120 sectors (60 KB) for the system
    fseek(fd, 512*64, SEEK_SET);  // also reposition on the last 32 KB of the reserved sectors
    fread(overlay,128,256,fd);    // and read it as a 32 KB overlay file
    fseek(fd, 512*56, SEEK_SET);  // ... extend the overlay with an extra 4KB...
    fread(&overlay[256],128,32,fd);
    fclose(fd);
#else
    char *sysfilename = argc < 2 ?  "M2.SYS" : argv[1];
    fd = fopen(sysfilename,"r");
    if (fd == NULL) { printf("Cannot open %s\n", sysfilename); exit(1); }
    fread(mem+0x0100,0xff00,1,fd); // read all file
    fclose(fd);
    fd = fopen("M2.OVR","r");
    if (fd == NULL) { printf("Cannot open M2.OVR\n"); exit(1); }
    fread(overlay,128,256,fd);   // and 256 records for the overlay
    fclose(fd);
#endif
    //assert( strncmp(mem+GLOBAL_PTR-14, "KERNEL", 6)==0 );

    set_conio_terminal_mode();
    tracelog = fopen("trace.txt","w");
#if EMULATED_DISK
    init_bios(sysfilename);
#endif

    /* some memory initialization just to remove differences with the Z80 version */
    // *WMEM(0xe3f0) = 0x041a; *WMEM(0xe3e6) = 0xe3f6;
    // *WMEM(0x0001) = 0xf203;
    // *WMEM(0xD012) = 0xdaa1;
    // *WMEM(0xe24a) = 0x47f1; *WMEM(0xe33c) = 0;
    // *WMEM(0xe322) = 0x33a8; *WMEM(0x618d) = 0xe4e3;
    // *WMEM(0x0074) = 0x2020; *WMEM(0x0076) = 0x2020;
    // *WMEM(0x5F30) = 0x5D6A;
    // *MEM(0xf910)=0xdf;


//#if BDOS_MCD
//    /* More space is required in the stack to execute the BDOS calls */
//    /* => change the pointer to the kernel process area */
//    word Z80CODE = 0x041a;
//    GLOBAL[18] = Z80CODE;
//    /* and declare the area size [0x041a - 0x055c] in two locations */
//    *WMEM(0x1ee9) = *WMEM(0x1eff) = 0x055c - 0x041a;
//#endif

    warm_boot();
}

void system_call(void) {
//#if BDOS_MCD
//    word param = pop();
//    word fct = pop();
//    push(fct); push(param);
//    fprintf(tracelog,"BDOS function %d\n",fct);
//    fflush(tracelog);
//    ext_proc_call(bdos_global, 1);
//#endif
    extern char *filename(int);
    static int dmaoff;
/*
    fprintf(tracelog,"BDOS function ");
    int param = TOP;
    switch(STACK[1]) {
        case 15: fprintf(tracelog,"OPEN %s\n",filename(param)); break;
        case 16: fprintf(tracelog,"CLOSE %s\n",filename(param)); break;
        case 19: fprintf(tracelog,"DELETE %s\n",filename(param)); break;
        case 22: fprintf(tracelog,"MAKE %s\n",filename(param)); break;
        case 23: fprintf(tracelog,"RENAME %s\n",filename(param)); break;
        case 26: dmaoff=param; fprintf(tracelog,"DMAOFFSET %04X\n",dmaoff); break;
        case 33: fprintf(tracelog,"READRAND %s, record %d\n",
                                   filename(param), *MEM(param+34)*256 + *MEM(param+33));
                 fprintf(tracelog,"\t skippedClusters = %d\n", *MEM(param+15)*256 + *MEM(param+14));
                 break;
        case 34: fprintf(tracelog,"WRITERAND %s, record %d",
                                   filename(param), *MEM(param+34)*256 + *MEM(param+33));
                 for (int i=0; i<128; i++) {
                     if (i%32==0) fprintf(tracelog,"\n");
                     fprintf(tracelog,"%02x ",*MEM(dmaoff+i));
                 }
                 fprintf(tracelog,"\n");
                 break;
        case 35: fprintf(tracelog,"FSIZE %s\n",filename(param)); break;
        default:
            fprintf(tracelog,"%d, param %d\n",STACK[1],param);
    }
*/
#  if EMULATED_DISK
    ext_proc_call(*WMEM(0xFF10), *WMEM(0xFF12));
#  else 
    word op=pop(); IORESULT=bdos(pop(),op);
#  endif
}
