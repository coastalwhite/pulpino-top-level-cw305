#ifndef __PULPINO_GPIO__
#define __PULPINO_GPIO__

#define GPIO_DIR ((volatile uint32_t*) 0x1A101000)
#define GPIO_IN  ((volatile uint32_t*) 0x1A101004)
#define GPIO_OUT ((volatile uint32_t*) 0x1A101008)

#endif // __PULPINO_GPIO__