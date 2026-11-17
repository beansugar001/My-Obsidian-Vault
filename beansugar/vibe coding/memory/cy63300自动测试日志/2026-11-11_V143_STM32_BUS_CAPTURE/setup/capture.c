#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))
#define GPIOB_CRH REG32(0x40010C04u)
#define GPIOB_IDR REG32(0x40010C08u)
#define RCC_CFGR REG32(0x40021004u)
#define RCC_APB2ENR REG32(0x40021018u)
#define DEMCR REG32(0xE000EDFCu)
#define DWT_CTRL REG32(0xE0001000u)
#define DWT_CYCCNT REG32(0xE0001004u)

enum { BUS = 0x300, CAPACITY = 512, MAGIC = 0x143B0501 };
enum { READY = 1, CAPTURING, FULL, TIMER_FAILED };

typedef struct {
    uint32_t cycles;
    uint32_t pins;
} edge;

typedef struct {
    uint32_t magic;
    uint32_t state;
    uint32_t command;
    uint32_t count;
    uint32_t start_cycles;
    uint32_t initial;
    uint32_t current;
    uint32_t clock_config;
    edge edges[CAPACITY];
} capture_mailbox;

#define MAILBOX ((volatile capture_mailbox *)0x20003800u)

void capture_main(void)
{
    MAILBOX->magic = 0;
    MAILBOX->command = 0;
    MAILBOX->count = 0;
    MAILBOX->start_cycles = 0;
    MAILBOX->clock_config = RCC_CFGR;
    RCC_APB2ENR |= 1u << 3;
    (void)RCC_APB2ENR;
    /* CNF=01, MODE=00, floating input on PB8 and PB9. */
    GPIOB_CRH = (GPIOB_CRH & ~0xFFu) | 0x44u;
    DEMCR |= 1u << 24;
    DWT_CYCCNT = 0;
    DWT_CTRL |= 1u;
    MAILBOX->initial = GPIOB_IDR & BUS;
    MAILBOX->current = MAILBOX->initial;
    MAILBOX->state = DWT_CYCCNT ? READY : TIMER_FAILED;
    __asm volatile ("dmb" ::: "memory");
    MAILBOX->magic = MAGIC;
    while (MAILBOX->state == TIMER_FAILED || MAILBOX->command != 1) {
        MAILBOX->current = GPIOB_IDR & BUS;
    }

    uint32_t previous = GPIOB_IDR & BUS;
    const uint32_t start = DWT_CYCCNT;
    MAILBOX->initial = previous;
    MAILBOX->current = previous;
    MAILBOX->start_cycles = start;
    MAILBOX->state = CAPTURING;
    uint32_t count = 0;
    while (count < CAPACITY) {
        const uint32_t pins = GPIOB_IDR & BUS;
        if (pins != previous) {
            MAILBOX->edges[count].cycles = DWT_CYCCNT - start;
            MAILBOX->edges[count].pins = pins;
            __asm volatile ("dmb" ::: "memory");
            MAILBOX->count = ++count;
            MAILBOX->current = pins;
            previous = pins;
        }
    }
    MAILBOX->state = FULL;
    for (;;) {
        MAILBOX->current = GPIOB_IDR & BUS;
    }
}
