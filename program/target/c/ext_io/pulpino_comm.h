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

#endif // __PULPINO_EXT_COMM__