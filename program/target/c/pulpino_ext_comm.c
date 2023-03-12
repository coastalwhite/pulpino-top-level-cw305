#include "pulpino_ext_comm.h"
#include "pulpino_gpio.h"

static inline void pulpino_usb_read_flicker() {
	(*GPIO_OUT) ^= 0x00000100;
}

static inline void pulpino_usb_write_flicker() {
	(*GPIO_OUT) ^= 0x00000200;
}

static inline void pulpino_usb_data(uint8_t data) {
	(*GPIO_OUT) = ((*GPIO_OUT) & 0xFFFFFF00) | ((uint32_t) data);
}

static inline void pulpino_ext_read_flicker() {
	(*GPIO_OUT) ^= 0x00000400;
}

static inline void pulpino_ext_write_flicker() {
	(*GPIO_OUT) ^= 0x00000800;
}

static inline uint8_t usb_pulpino_read_flicker() {
	return (uint8_t) (((*GPIO_IN) >> 8) & 0x1);
}

static inline uint8_t usb_pulpino_write_flicker() {
	return (uint8_t) (((*GPIO_IN) >> 9) & 0x1);
}

static inline uint8_t usb_pulpino_data() {
	return (uint8_t) ((*GPIO_IN) & 0xFF);
}

static inline uint8_t ext_pulpino_read_flicker() {
	return (uint8_t) (((*GPIO_IN) >> 10) & 0x1);
}

static inline uint8_t ext_pulpino_write_flicker() {
	return (uint8_t) (((*GPIO_IN) >> 11) & 0x1);
}


uint32_t pulpino_usb_read() {
    uint32_t word = 0;
    
    for (uint8_t i = 0; i < 4; i++) {
        while (usb_pulpino_write_flicker() == (i & 0x1)) ;

		word <<= 8;
		word |= usb_pulpino_data();

		pulpino_usb_read_flicker();
    }

    return word;
}

void pulpino_usb_write(uint32_t word) {
    for (uint8_t i = 0; i < 4; i++) {
		pulpino_usb_data((uint8_t) (word & 0xFF));
		word >>= 8;
		
		pulpino_usb_write_flicker();

        while (usb_pulpino_read_flicker() == (i & 0x1)) ;
    }

	pulpino_usb_data(0x00);
}

// Blocking read from the external machine.
uint32_t pulpino_ext_read() {
	// Wait for the external to write something
    while (ext_pulpino_write_flicker() == 0) ;

	uint32_t word = pulpino_usb_read();

	// Coordinate to back to the original state
	pulpino_ext_read_flicker();
    while (ext_pulpino_write_flicker() == 1) ;
	pulpino_ext_read_flicker();

	return word;
}

// Blocking write to the external machine.
void pulpino_ext_write(uint32_t word) {
	pulpino_usb_write(word);

	pulpino_ext_write_flicker();
    while (ext_pulpino_read_flicker() == 0) ;
	pulpino_ext_write_flicker();
}