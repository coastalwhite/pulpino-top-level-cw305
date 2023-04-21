#ifndef __PULPINO_EXT_COMM__
#define __PULPINO_EXT_COMM__

#include <stdint.h>
#include <stdbool.h>

uint8_t read();
void write(uint8_t byte);

uint32_t read_word();
void write_word(uint32_t word);

void led(bool is_on);
void program();
#define read_registers() \
    asm volatile(                  \
        "sw      sp,-120(sp)\n\t"  \
        "addi    sp,sp,-124\n\t"   \
        "sw      x1,0(sp)\n\t"     \
        "sw      x3,8(sp)\n\t"     \
        "sw      x4,12(sp)\n\t"    \
        "sw      x5,16(sp)\n\t"    \
        "sw      x6,20(sp)\n\t"    \
        "sw      x7,24(sp)\n\t"    \
        "sw      x8,28(sp)\n\t"    \
        "sw      x9,32(sp)\n\t"    \
        "sw      x10,36(sp)\n\t"   \
        "sw      x11,40(sp)\n\t"   \
        "sw      x12,44(sp)\n\t"   \
        "sw      x13,48(sp)\n\t"   \
        "sw      x14,52(sp)\n\t"   \
        "sw      x15,56(sp)\n\t"   \
        "sw      x16,60(sp)\n\t"   \
        "sw      x17,64(sp)\n\t"   \
        "sw      x18,68(sp)\n\t"   \
        "sw      x19,72(sp)\n\t"   \
        "sw      x20,76(sp)\n\t"   \
        "sw      x21,80(sp)\n\t"   \
        "sw      x22,84(sp)\n\t"   \
        "sw      x23,88(sp)\n\t"   \
        "sw      x24,92(sp)\n\t"   \
        "sw      x25,96(sp)\n\t"   \
        "sw      x26,100(sp)\n\t"  \
        "sw      x27,104(sp)\n\t"  \
        "sw      x28,108(sp)\n\t"  \
        "sw      x29,112(sp)\n\t"  \
        "sw      x30,116(sp)\n\t"  \
        "sw      x31,120(sp)\n\t"  \
                                   \
        "lw      a0,0(sp)\n\t"     \
        "call    write_word\n\t"   \
        "lw      a0,4(sp)\n\t"     \
        "call    write_word\n\t"   \
        "lw      a0,8(sp)\n\t"     \
        "call    write_word\n\t"   \
        "lw      a0,12(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,16(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,20(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,24(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,28(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,32(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,36(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,40(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,44(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,48(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,52(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,56(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,60(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,64(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,68(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,72(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,76(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,80(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,84(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,88(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,92(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,96(sp)\n\t"    \
        "call    write_word\n\t"   \
        "lw      a0,100(sp)\n\t"   \
        "call    write_word\n\t"   \
        "lw      a0,104(sp)\n\t"   \
        "call    write_word\n\t"   \
        "lw      a0,108(sp)\n\t"   \
        "call    write_word\n\t"   \
        "lw      a0,112(sp)\n\t"   \
        "call    write_word\n\t"   \
        "lw      a0,116(sp)\n\t"   \
        "call    write_word\n\t"   \
        "lw      a0,120(sp)\n\t"   \
        "call    write_word\n\t"   \
                                   \
        "addi    sp,sp,124\n\t"    \
    );

#endif // __PULPINO_EXT_COMM__