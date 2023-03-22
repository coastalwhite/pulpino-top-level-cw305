#include "../ext_io/pulpino_comm.h"

#define SLEEP_TIME 5000000

void sleep(int ticks) {
    for (int i = 0; i < ticks; i++)
        asm("NOP");
}

int main() {
    while (true) {
        led(false);
        sleep(SLEEP_TIME);
        led(true);
        sleep(SLEEP_TIME);
    }
}