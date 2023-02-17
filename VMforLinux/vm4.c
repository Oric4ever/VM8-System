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

/* Version avec pile 1 Ko pour les contextes de procedures...
 * Avec 0x500-0x120 = 1024 - 32 octets, ok pour compilateur Oberon
 *
 * mais compilateur Modula2 déborde à cause de la procédure récursive SymTab.proc31
 */
#define LOCAL_STACK_LIMIT 0x120

/* Maintenant que les variables en page 0 ont été supprimées,
 * essai sans déplacement de la page0 en page255 */
#define PAGE0_CHECK 1
#define MOVE_PAGE0_TO_PAGE255 0

#define LEGACY 0

#define MIN_ALLOC_SIZE 4

FILE *tracelog;
bool trace;
void error(int n, word param1, word param2);
bool mcode_interp(void);
void legacy_system_call(void);
static int proc_num;
unsigned int vclock;

int high_mem = 0xfefe; // 0xe406;    // end of transient memory
byte mem[65536+65536]; // additionnal space due to bug in EDIT2
byte *MEM(int addr)  {
#if PAGE0_CHECK
    if (addr>=0x000 && addr<0x0100) fprintf(tracelog,"PAGE0: Warning: access to byte at address %04x\n", addr);
#endif
    return &mem[addr];
}
word *WMEM(int addr) {
#if PAGE0_CHECK
    if (addr>=0x000 && addr<0x0100) fprintf(tracelog,"PAGE0: Warning: access to word at address %04x\n", addr);
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

/* trying with STACK_LIMIT (= HEAP - 60) too */
#undef STACK_LIMIT
word STACK_LIMIT;

#define OUTER_FRAME REG2
word IP, IntFlag, REG1, REG2, A, carry;
word LOCAL_PTR, RESERVE_STACK_PTR;
word STACK_PTR;
word STD_EXCEPTIONS_MODULE;

char *error_msgs[] = {
    "Illegal instruction",
    "Bad overlay",
    "Bounds",
    "Integer range",
    "Negative",
    "Out of memory",
    "Out of memory",
    "Pointer",
    "Division by zero",
    "Function returns no result",
    "End of coroutine",
    "Real overflow",
    "Overflow",
    "Case select",
    "Bad heap",
    "String too long",
    "Illegal instruction",
    "Stack overflow"
};

#define TOP (STACK[0])
#define BIOS_RESULT *WMEM(0x300)
#define BIOS_RESULT2 *WMEM(0x302)
#define RESERVE_LIMIT STACK_LIMIT
#undef FREE_LIST
#define FREE_LIST 0x0118

#define TRANSIENT 1
#define NATIVE 2

void   push(word w)   { STACK_PTR-=2; TOP = w; }
void  dpush(dword dw) { STACK_PTR-=4; *(dword  *)STACK = dw; }
void  fpush(float f)  { STACK_PTR-=4; *(float  *)STACK = f; }
void  qpush(double g) { STACK_PTR-=8; *(double *)STACK = g; }

word   pop(void)      { STACK_PTR+=2; return STACK[-1]; }
sword ipop(void)      { return pop(); }
#if MOVE_PAGE0_TO_PAGE255
word  ppop(void)      { if (!TOP) error(POINTER_ERROR,0,0); return TOP & 0xff00 ? pop() : pop() + 0xff00; }
#else
word  ppop(void)      { if (!TOP) error(POINTER_ERROR,0,0); return pop(); }
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

void overflow(void)         { error(OVERFLOW_ERROR,0,0); }
void stack_overflow(void)   {
    fprintf(tracelog,"Stack overflow !!\n");
    fflush(tracelog);
    error(STACKOVERFLOW_ERROR,0,0); 
}
bool native(byte op);

void leave_check(int n)
{
    extern void end_profile(void);
    end_profile();
    if ((n & 0x80) == 0) return; // was a call to an inner proc
    if (OUTER_FRAME == 0) return; // was an intra-module call

    GLOBAL_PTR = OUTER_FRAME;
    if (GLOBAL_PTR == 1) { // returned from the main module
        if (TRACE_ALL) fprintf(tracelog,"Returning from a module's INIT\n");
//        error(ENDOFCOROUT_ERROR,0,0); // now this isn't an error anymore
    } else {
        // otherwise it was an inter-module call
//      fprintf(tracelog,"GLOBAL_PTR := %04x\n",GLOBAL_PTR);
        assert( !(GLOBAL[0] & NATIVE) );
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

int search_proc(word addr)
{
    if (addr > proc_addr(0)) return 0;
    int proc_num;
    for (proc_num = 1; proc_addr(proc_num) < addr; proc_num++)
        ;
    return proc_num-1;
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

bool native(byte op)
{ 
    char *module_name = ((char *)GLOBAL) - 14;
    word return_addr = pop();


    fprintf(tracelog,"NATIVE procedure %.8s.%d at %04X\n",module_name,proc_num,IP);

    {
        fprintf(tracelog,"NATIVE procedure %.8s.%d at %04X\n",module_name,proc_num,IP);
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
    STACK_PTR         = LOCAL_PTR-2;
    RESERVE_STACK_PTR = pop();
    OUTER_FRAME       = pop();
    LOCAL_PTR         = pop();
    IP                = pop();
    STACK_PTR        += size;  // drop caller's arguments
}

void leave(int n)
{
    restore_frame(2*n & 0xff);
    leave_check(n);
}

void module_halt(void)
{
    bool module_init_found = false;
    do {
        word proc_table_ptr = GLOBAL[-1];
        word module_init = WMEM(proc_table_ptr)[0] + proc_table_ptr + 1;
        word this_proc_start = LOCAL[-1]-2;
        module_init_found = this_proc_start == module_init;
        leave(0x80);
   } while (!module_init_found);
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
  Offset 0: next block address
  Offset 2: size
  ...
  Offset size-2: size (hence offset 2 if block size = 4)
*/
word allocate(int size) {
    if (size%2) size++;
    if (size<MIN_ALLOC_SIZE) size=MIN_ALLOC_SIZE;

//    fprintf(tracelog,"Heap = %04x, Stack = %04x, allocating %5d-bytes...", RESERVE_LIMIT, RESERVE_STACK_PTR, size);

    word block_ptr = FREE_LIST;
    word block;
    for ( ; ; block_ptr = block) {
        block     = *WMEM(block_ptr);
        if (block == 0) {   // end of blocks in free-blocks list
            if (RESERVE_LIMIT+size > RESERVE_STACK_PTR) error(OUTOFMEM_ERROR,0,0);
            block = RESERVE_LIMIT-60;    // RESERVE_LIMIT actually has a 60 bytes margin
            RESERVE_LIMIT += size;
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
//    fprintf(tracelog, " at %04x\n", block);
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

//    fprintf(tracelog,"Deallocating %5d-bytes block at %04x =>\n",size,block);
    fflush(tracelog);
    if (block==0) error(POINTER_ERROR,0,0);

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

    if (RESERVE_LIMIT == block + size + 60) { // enlarge heap if the block is just before
        RESERVE_LIMIT = block + 60;
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
//    fprintf(tracelog,"Heap = %04x, Stack = %04x.\n", RESERVE_LIMIT, RESERVE_STACK_PTR);
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
    word heap = RESERVE_LIMIT - 60;
    *WMEM(var_addr) = heap;
    RESERVE_LIMIT += 2;
//fprintf(tracelog, "Mark    heap at %04x, save free list at %04x, stack = %04x\n", heap, *WMEM(FREE_LIST), RESERVE_STACK_PTR);
    *WMEM(heap) = *WMEM(FREE_LIST); // save free list
    *WMEM(FREE_LIST) = 0;           // and continue with an empty list
}

void release(word var_addr)
{
    word ptr = *WMEM(var_addr);
    *WMEM(var_addr) = 0;
    if (ptr == 0) error(POINTER_ERROR,0,0);
    *WMEM(FREE_LIST) = *WMEM(ptr);
    RESERVE_LIMIT = ptr + 60;
//fprintf(tracelog, "Release heap at %04x, back free list at %04x, stack = %04x\n", ptr, *WMEM(FREE_LIST), RESERVE_STACK_PTR);
}

void proc_call(int n, word outer_frame)
{
    extern void start_profile(char *, int);
    start_profile(MEM(GLOBAL_PTR)-14, n);
    OUTER_FRAME = outer_frame;
    push(IP);
    push(LOCAL_PTR);
    push(outer_frame);
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

void ext_proc_call(word module_base, int n)
{
    extern void start_profile(char *, int);
    start_profile(MEM(module_base)-14, n);
    push(IP);
    push(LOCAL_PTR);
    push(GLOBAL_PTR); // outer frame is toplevel
    GLOBAL_PTR = module_base;  // changing module now to avoid loading overlay twice
//    if ( *MEM(module_base) & TRANSIENT ) load_overlay(module_base);

    GLOBAL_PTR = module_base;
    if (TRACE_ALL) {
        fprintf(tracelog, "calling proc #%d in module %.8s...\n",n,MEM(module_base)-14); 
    }
    if (strcmp(MEM(module_base)-14,"OBN")==0) trace=1;
    assert( (*MEM(module_base) & NATIVE) == 0); // no NATIVE code
    IP = proc_addr(n);
    proc_num = n;
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
#if MOVE_PAGE0_TO_PAGE255
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
    if (src==0 || dst==0) error(POINTER_ERROR,0,0);
#if PAGE0_CHECK
    if (src<256 || dst <256) {
        fprintf(tracelog,"PAGE0: Copy %d bytes-string from %04x to %04x\n", src_size,src,dst); 
        for (int i=0; i<src_size; i++) 
            fprintf(tracelog, "%c",MEM(src)[i]);
        fprintf(tracelog,"\n");
    }
#endif
#if MOVE_PAGE0_TO_PAGE255
    if (src<256) src+=0xff00;
    if (dst<256) dst+=0xff00;
#endif
    while (src_size && *MEM(src)) {
        if (dst_size--) *MEM(dst++) = *MEM(src++);
        else error(STRINGTOOLONG_ERROR,0,0);
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

void reserve(int size)
{
    if (RESERVE_STACK_PTR - size < RESERVE_LIMIT) stack_overflow();
    RESERVE_STACK_PTR -= size;
    bzero(MEM(RESERVE_STACK_PTR), size);
    push(RESERVE_STACK_PTR);
}

void string_reserve()
{
    word src=pop(), size = pop();
#if PAGE0_CHECK
    if (src<256) fprintf(tracelog,"PAGE0: Reserve %d bytes-string on stack, copy from %04x\n", size, src); 
#endif
    if (RESERVE_STACK_PTR - size < RESERVE_LIMIT) stack_overflow();
    RESERVE_STACK_PTR -= size;
#if MOVE_PAGE0_TO_PAGE255
    if (src<256) src+=0xff00;
#endif
    memcpy(MEM(RESERVE_STACK_PTR), MEM(src), size);
    push(RESERVE_STACK_PTR);
}

void fill(void)
{
    byte val  = pop();
    word size = pop();
    word addr = pop();
#if PAGE0_CHECK
    if (addr<256) fprintf(tracelog,"PAGE0: Fill %d bytes-block at %04x\n", size,addr); 
#endif
#if MOVE_PAGE0_TO_PAGE255
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
    push(size);
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
#if MOVE_PAGE0_TO_PAGE255
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
    LOCAL_PTR = STACK_PTR;
    push(RESERVE_STACK_PTR);
    if (STACK_PTR - size < LOCAL_STACK_LIMIT) stack_overflow();
    STACK_PTR -= size;
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

word get_exception_module(int exception_module_num)
{
    if      (exception_module_num == 0) return STD_EXCEPTIONS_MODULE;
    else if (exception_module_num == 1) return GLOBAL_PTR;
    else return GLOBAL[-9-(exception_module_num-2)];
}

void stack_trace() {
    do {
        int proc_num = search_proc(IP);
        int offset   = IP - proc_addr(proc_num);
        printf("Module %8.8s, proc #%d  +%d\n", MEM(GLOBAL_PTR)-14, proc_num, offset);
        fprintf(tracelog, "Module %8.8s, proc #%d  +%d\n", MEM(GLOBAL_PTR)-14, proc_num, offset);
    } while (upper_frame());
}

void raise_to_kernel() {
    word msg_size = pop();
    word msg_addr = pop();
    word exception_num = pop();
    bool propagate_exception = (exception_num != ENDOFCOROUT_ERROR); // end of coroutine

    if (exception_num == 6) { // #6: out of memory
        propagate_exception = upper_frame(LOCAL_PTR);
        STACK_PTR = LOCAL_PTR - 3;
        exception_num = OUTOFMEM_ERROR;
    }

    word exception_module = get_exception_module(exception_num >> 8);
    exception_num    = exception_num & 0xFF;
    int name_length  = MEM(ext_proc_addr(exception_module, exception_num))[0];
    char *exc_name   = MEM(ext_proc_addr(exception_module, exception_num)+1);
    printf("EXCEPTION %.8s.%.*s\n", MEM(exception_module-14), name_length, exc_name);
    fprintf(tracelog, "%.8s.%.*s\n", MEM(exception_module-14), name_length, exc_name);

    if (msg_size > 60) msg_size = 60;

    word save_local  = LOCAL_PTR;
    word save_global = GLOBAL_PTR;
    word save_ip     = IP;
/*
    if (propagate_exception) {
        do {
            fprintf(tracelog, "Searching exception handler...\n");
            fprintf(tracelog, "LOCAL = %04x\n", LOCAL_PTR);
            fprintf(tracelog, "PROC START = %04x\n", LOCAL[-1]-2);
            fprintf(tracelog, "IP = %04x\n", IP);
    fprintf(tracelog,"\n\tGLOBAL=%04X", GLOBAL_PTR);
    fprintf(tracelog,    " LOCAL=%04X",  LOCAL_PTR);
    fprintf(tracelog,     " HEAP=%04X", RESERVE_LIMIT-60);
    fprintf(tracelog,    " LIMIT=%04X", RESERVE_LIMIT);
    fprintf(tracelog,    " RESERVE=%04X", RESERVE_STACK_PTR);
    fprintf(tracelog,    " STACK=%04X", STACK_PTR);
    fprintf(tracelog," TOP=%04X \n",TOP);
            word proc_ptr = LOCAL[-1] - 2 - 2; // pointer to exception handler rel addr
            word except_handler = WMEM(proc_ptr)[0];
            if (except_handler && (except_handler & 0x8000) == 0) { // exception handlers are present
                fprintf(tracelog, "%04x offset found\n", except_handler);
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
*/
    GLOBAL_PTR = exception_module;
    word exception_name = proc_addr(exception_num);
    int exception_name_size = *MEM(exception_name);
    printf("\n\nException not caught: ");
/*
    if (exception_module != STD_EXCEPTIONS_MODULE)
        printf("%.8s.", MEM(exception_module)-14, MEM(exception_name)+1);
    printf("%.*s", exception_name_size, MEM(exception_name+1));
*/
    printf("%s error at\n", error_msgs[exception_num]);
    fprintf(tracelog, "%s error at\n", error_msgs[exception_num]);
    LOCAL_PTR  = save_local;
    GLOBAL_PTR = save_global;
    IP         = save_ip;
    stack_trace();
    printf("Aborting...\n");
    exit(1);
}

void assertion(word linenum, bool b) {
    if (!b) {
        printf("\nAssertion fails in module %.8s, line %d\n", ((char *)GLOBAL)-14, linenum);
//        save_context(0x030a,RETURN_FROM_HALT); coroutine_transfer(0x0308);
    }
}

void typecheck(word linenum, word typetag1, word typetag2) {
    if (typetag1 != 0) {
        while (typetag1 != 0  &&  typetag1 != typetag2) {
            typetag1 = *WMEM(typetag1);
        }
        if (typetag1 == 0) {
            printf("\nType guard failure in module %.8s, line %d\n", ((char *)GLOBAL)-14, linenum);
//            save_context(0x030a,RETURN_FROM_HALT); coroutine_transfer(0x0308);
        }
    }
}

void error(int n, word param1, word param2)
{
    if (n != 1) fprintf(tracelog, "ERROR %d !!!\n",n);
    push(n);
    push(0);
    push(0);
    REG1 = param1; REG2 = param2;
    raise_to_kernel();
}

void newprocess(void)
{
    fprintf(tracelog,"NEWPROCESS implementation removed !\n");
}

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
    case  9: push(RESERVE_STACK_PTR-RESERVE_LIMIT-1); break; // FreeMem()
    case 10: op=pop();
             fprintf(tracelog, "TRANSFER implementation removed !\n");
//           save_context(pop(),RESUME_PROCESS); coroutine_transfer(op); break;
    case 11: // IOTRANSFER
    case 12: newprocess(); break;
    case 13: op2=pop(); op=pop(); BIOS_RESULT=bios(op,op2); break;
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
    case 35: op = pop();  push( ipop() >> op ); break;
    case 36: op = pop(); dpush( dpop() >> op ); break;
    case 37: op = pop();  push( ipop() << op ); break;
    case 38: op = pop(); dpush( dpop() << op ); break;
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

  if (TRACE_ALL) {
    fprintf(tracelog,"\n\tGLOBAL=%04X", GLOBAL_PTR);
    fprintf(tracelog,    " LOCAL=%04X",  LOCAL_PTR);
    fprintf(tracelog,     " HEAP=%04X", RESERVE_LIMIT-60);
    fprintf(tracelog,    " FREELIST=%04X", *WMEM(FREE_LIST));
    fprintf(tracelog,    " RESERVE=%04X", RESERVE_STACK_PTR);
    fprintf(tracelog,    " STACK=%04X", STACK_PTR);
//    fprintf(tracelog," [FEEE]=%04x",*WMEM(0xFEEE));
    fprintf(tracelog," TOP=%04X \n",TOP);
    fprintf(tracelog,"\nIP=%04X OP=%02X %02X %02X \n", IP, *MEM(IP), *MEM(IP+1), *MEM(IP+2));
    fflush(tracelog);
  }

  vclock++;

  switch (FETCH) {
  case 0x00: error(ILLEGAL_INSTRUCTION,0,0); break;
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

  case 0x50: /* original coroutine implementation replaced
                save_context(0x030a,RETURN_FROM_HALT); coroutine_transfer(0x0308); break;
             */
             fprintf(tracelog, "HALT in module %04X (%.8s)\n", GLOBAL_PTR, MEM(GLOBAL_PTR) - 14);
             module_halt();
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
  case 0x84: leave(FETCH); break;
  case 0x85: fct_leave(FETCH); break;
  case 0x86: dfct_leave(FETCH); break;
  case 0x87: native(FETCH); break; // NATIVE code
  case 0x88: leave(0x80); break;
  case 0x89: leave(0x81); break;
  case 0x8a: leave(0x82); break;
  case 0x8b: leave(0x83); break;
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
  case 0xa9: op=pop(); 
             if (op) push( pop() /  op ); 
             else error(DIVBYZERO_ERROR,0,0); 
             break; // unsigned division
  case 0xaa: itmp=ipop(); iop=ipop(); 
             if (itmp) push(iop>=0 ? iop%itmp : (iop%itmp + itmp) % itmp);
             else error(DIVBYZERO_ERROR,0,0);
             break; // unsigned Modulus
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
  case 0xb9: itmp=ipop(); iop=ipop(); 
             if (itmp) push(iop/itmp - (iop < 0 && iop%itmp!=0));
             else error(DIVBYZERO_ERROR,0,0);
             break;
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
  case 0xc3: legacy_system_call(); break;
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
             if (TOP<op || TOP>op+tmp) error(BOUNDS_ERROR,op+tmp,op); 
             break;
  case 0xdb: iop=ipop(); tmp=pop();
             if (ITOP<iop || ITOP>iop+tmp) error(IBOUNDS_ERROR,iop+tmp,iop); 
             break;
  case 0xdc: op=pop(); if (TOP>op) error(BOUNDS_ERROR,op,0); break;
  case 0xdd: if (ITOP<0) error(NEGATIVE_ERROR,0,0); break;
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
    if (LEGACY) *WMEM(0xFF0C) = 0x041A; // let the Legacy Kernel know the VM fetch routine address
    STACK_LIMIT = *(word *)(mem + 0x0316);
    STACK_PTR  = 0x0500;
    RESERVE_STACK_PTR = high_mem;
    word module = *WMEM(0x030C); // first module to init
    STD_EXCEPTIONS_MODULE = *WMEM(0x120);
    fprintf(tracelog,"Reset: heap=%04x, reserve=%04x\n", STACK_LIMIT-60, high_mem);
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

    char *sysfilename = argc < 2 ?  "image.dsk" : argv[1];
    fd = fopen(sysfilename,"r");
    if (fd == NULL) { printf("Cannot open %s\n", sysfilename); exit(1); }
    fseek(fd, 512*8, SEEK_SET);   // skip first 8 sectors
    fread(mem+0x0100,512,120,fd); // read the next 120 sectors (60 KB) for the system
    fclose(fd);

    set_conio_terminal_mode();
    tracelog = fopen("trace.txt","w");
    init_bios(sysfilename);
    warm_boot();
}

void legacy_system_call(void) {
    fprintf(tracelog, "Legacy system call at IP = %04x", IP-1);
    if (LEGACY) ext_proc_call(*WMEM(0xFF10), *WMEM(0xFF12));
}
