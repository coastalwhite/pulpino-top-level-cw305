#include "pulpino_comm.h"
#include "pulpino_gpio.h"

static inline void pulpino_read_flicker() {
	(*GPIO_OUT) ^= 0x00000100;
}

static inline void pulpino_write_flicker() {
	(*GPIO_OUT) ^= 0x00000200;
}

static inline void pulpino_data(uint8_t data) {
	(*GPIO_OUT) = ((*GPIO_OUT) & 0xFFFFFF00) | ((uint32_t) data);
}

static inline uint8_t ext_read_flicker() {
	return (uint8_t) (((*GPIO_IN) >> 8) & 0x1);
}

static inline uint8_t ext_write_flicker() {
	return (uint8_t) (((*GPIO_IN) >> 9) & 0x1);
}

static inline uint8_t ext_data() {
	return (uint8_t) ((*GPIO_IN) & 0xFF);
}

// Blocking read from the external machine.
uint8_t read() {
	// Wait for the external to write something
    while (ext_write_flicker() == 0) ;

	uint8_t byte = ext_data();

	// Coordinate to back to the original state
	pulpino_read_flicker();
    while (ext_write_flicker() == 1) ;
	pulpino_read_flicker();

	return byte;
}

// Blocking write to the external machine.
void write(uint8_t byte) {
    while (ext_read_flicker() == 1) ;

	pulpino_data(byte);

	pulpino_write_flicker();
    while (ext_read_flicker() == 0) ;
	pulpino_write_flicker();
}

// Block read of a word from the external machine.
uint32_t read_word() {
    // Read the bytes in Big-Endian notation
    return (
        (((uint32_t) read()) << 24) |
        (((uint32_t) read()) << 16) |
        (((uint32_t) read()) <<  8) |
        (((uint32_t) read()) <<  0)
    );
}

// Block write of a word to the external machine.
void write_word(uint32_t word) {
    // Write the bytes in Big-Endian notation
    write((word >> 24) & 0xFF);
    write((word >> 16) & 0xFF);
    write((word >>  8) & 0xFF);
    write((word >>  0) & 0xFF);
}

void led(bool is_on) {
    (*GPIO_OUT) = ((*GPIO_OUT) & 0xFFFFFBFF) | (is_on ? 0x400 : 0);
}

void trigger(bool is_on) {
    (*GPIO_OUT) = ((*GPIO_OUT) & 0xFFFFF7FF) | (is_on ? 0x800 : 0);
}

void program() {
    uint32_t start = read_word();
    uint32_t end   = read_word();

    for (; start < end; start++) {
        uint8_t *addr = (uint8_t *) ((uintptr_t) start);
        *addr = read();
    }
}