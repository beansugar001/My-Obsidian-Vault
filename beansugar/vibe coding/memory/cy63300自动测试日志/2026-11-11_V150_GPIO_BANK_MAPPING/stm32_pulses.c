#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))
#define GPIOB_CRH REG32(0x40010C04u)
#define GPIOB_IDR REG32(0x40010C08u)
#define GPIOB_BSRR REG32(0x40010C10u)
#define RCC_CFGR REG32(0x40021004u)
#define RCC_APB2ENR REG32(0x40021018u)
#define DEMCR REG32(0xE000EDFCu)
#define DWT_CTRL REG32(0xE0001000u)
#define DWT_CYCCNT REG32(0xE0001004u)

enum { SCL = 0x100u, SDA = 0x200u, BUS = SCL | SDA, HZ = 72000000u };

typedef struct {
    uint32_t phase;
    uint32_t start;
    uint32_t first_pins;
    uint32_t last_pins;
    uint32_t end;
} sample;

typedef struct {
    uint32_t magic, state, command, count, start, initial, current, clock;
    sample phases[5];
} result;

#define MAILBOX ((volatile result *)0x20003800u)

static void wait_cycles(uint32_t start, uint32_t cycles)
{
    while (DWT_CYCCNT - start < cycles) {
        __asm volatile ("nop");
    }
}

static void set_pins(uint32_t low, uint32_t upper_crh)
{
    GPIOB_CRH = upper_crh | 0x44u;
    GPIOB_BSRR = BUS;
    if (low != 0) {
        GPIOB_BSRR = low << 16;
        GPIOB_CRH = upper_crh | (low == SCL ? 0x47u : 0x74u);
    }
}

void pulse_main(void)
{
    const uint32_t upper_crh = GPIOB_CRH & ~0xFFu;
    MAILBOX->magic = 0;
    MAILBOX->clock = RCC_CFGR;
    MAILBOX->count = 0;
    MAILBOX->command = 0;
    RCC_APB2ENR |= 1u << 3;
    (void)RCC_APB2ENR;
    set_pins(0, upper_crh);
    DEMCR |= 1u << 24;
    DWT_CYCCNT = 0;
    DWT_CTRL |= 1u;
    MAILBOX->initial = GPIOB_IDR & BUS;
    MAILBOX->current = MAILBOX->initial;
    MAILBOX->state = DWT_CYCCNT != 0 && MAILBOX->clock == 0x001D040Au ? 1 : 4;
    __asm volatile ("dmb" ::: "memory");
    MAILBOX->magic = 0x143B0501u;
    while (MAILBOX->command != 1 || MAILBOX->state != 1) {
        MAILBOX->current = GPIOB_IDR & BUS;
    }
    uint32_t start = DWT_CYCCNT;
    MAILBOX->start = start;
    MAILBOX->state = 2;
    for (unsigned phase = 0; phase < 5; ++phase) {
        const uint32_t low = phase == 1 ? SCL : phase == 3 ? SDA : 0;
        const uint32_t duration = (phase == 0 ? 6u : phase == 1 || phase == 3 ? 10u : 4u) * HZ;
        set_pins(low, upper_crh);
        uint32_t phase_start = DWT_CYCCNT;
        volatile sample *entry = &MAILBOX->phases[phase];
        entry->phase = phase;
        entry->start = phase_start - start;
        wait_cycles(phase_start, HZ / 10000u);
        entry->first_pins = GPIOB_IDR & BUS;
        wait_cycles(phase_start, duration);
        entry->last_pins = GPIOB_IDR & BUS;
        entry->end = DWT_CYCCNT - start;
        __asm volatile ("dmb" ::: "memory");
        MAILBOX->count = phase + 1;
    }
    set_pins(0, upper_crh);
    MAILBOX->state = 3;
    for (;;) {
        MAILBOX->current = GPIOB_IDR & BUS;
    }
}
