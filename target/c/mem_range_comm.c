#include "pulpino_ext_comm.h"

void program_memory_range() {
    uint32_t start = pulpino_ext_read();
    uint32_t end   = pulpino_ext_read();

    // Ensure the `start` and `end` are word aligned.
    start &= 0xFFFFFFFC;
    end   &= 0xFFFFFFFC;

    for (; start < end; start += 4) {
        uint32_t *addr = (uint32_t *) ((uintptr_t) start);
        *addr = pulpino_ext_read();
    }
}

void echo_memory_range() {
    uint32_t start = pulpino_ext_read();
    uint32_t end   = pulpino_ext_read();

    // Ensure the `start` and `end` are word aligned.
    start &= 0xFFFFFFFC;
    end   &= 0xFFFFFFFC;

    for (; start < end; start += 4) {
        uint32_t *addr = (uint32_t *) ((uintptr_t) start);
        pulpino_ext_write(*addr);
    }
}