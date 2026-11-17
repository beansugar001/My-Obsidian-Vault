#include <stdint.h>

#define REG32(address) (*(volatile uint32_t *)(address))
#define RCC_CFGR       REG32(0x40021004u)
#define RCC_APB2ENR    REG32(0x40021018u)
#define GPIOB_CRH      REG32(0x40010C04u)
#define GPIOB_IDR      REG32(0x40010C08u)
#define GPIOB_BSRR     REG32(0x40010C10u)
#define DEMCR          REG32(0xE000EDFCu)
#define DWT_CTRL       REG32(0xE0001000u)
#define DWT_CYCCNT     REG32(0xE0001004u)

enum {
    SCL = 1u << 8,
    SDA = 1u << 9,
    BUS = SCL | SDA,
    HALF_PERIOD = 720u,
    CLOCK_TIMEOUT = 72000u,
    MAILBOX_MAGIC = 0x14203303u,
    ACK = 1,
    NACK = 2,
    BUS_NOT_IDLE = 3,
    SCL_TIMEOUT = 4,
    UNSTABLE = 5,
    STOP_NOT_IDLE = 6
};

typedef struct {
    uint32_t address;
    uint32_t idle_before;
    uint32_t ack_pins[3];
    uint32_t idle_after;
    uint32_t result;
    uint32_t cycles;
} address_sample;

typedef struct {
    uint32_t magic;
    uint32_t stage;
    uint32_t clock_config;
    uint32_t half_period;
    address_sample addresses[2];
} probe_result;

#define RESULT ((volatile probe_result *)0x20004200u)

static void delay_cycles(uint32_t cycles)
{
    const uint32_t start = DWT_CYCCNT;
    while (DWT_CYCCNT - start < cycles) {
        __asm volatile ("nop");
    }
}

static int release_clock(void)
{
    GPIOB_BSRR = SCL;
    const uint32_t start = DWT_CYCCNT;
    while (!(GPIOB_IDR & SCL)) {
        if (DWT_CYCCNT - start >= CLOCK_TIMEOUT) {
            return 0;
        }
    }
    return 1;
}

static void probe_address(volatile address_sample *sample, uint32_t address)
{
    sample->address = address;
    sample->idle_before = GPIOB_IDR & BUS;
    sample->ack_pins[0] = 0;
    sample->ack_pins[1] = 0;
    sample->ack_pins[2] = 0;
    sample->idle_after = 0;
    sample->result = BUS_NOT_IDLE;
    sample->cycles = 0;
    if (sample->idle_before != BUS) {
        return;
    }

    const uint32_t start = DWT_CYCCNT;
    const uint32_t byte = address << 1;
    GPIOB_BSRR = SDA << 16;
    delay_cycles(HALF_PERIOD);
    GPIOB_BSRR = SCL << 16;

    for (uint32_t mask = 0x80u; mask; mask >>= 1) {
        GPIOB_BSRR = (byte & mask) ? SDA : SDA << 16;
        delay_cycles(HALF_PERIOD);
        if (!release_clock()) {
            GPIOB_BSRR = BUS;
            sample->result = SCL_TIMEOUT;
            return;
        }
        delay_cycles(HALF_PERIOD);
        GPIOB_BSRR = SCL << 16;
    }

    GPIOB_BSRR = SDA;
    delay_cycles(HALF_PERIOD);
    if (!release_clock()) {
        GPIOB_BSRR = BUS;
        sample->result = SCL_TIMEOUT;
        return;
    }

    unsigned sda_high = 0;
    unsigned scl_high = 0;
    for (unsigned i = 0; i < 3; ++i) {
        delay_cycles(HALF_PERIOD / 3);
        uint32_t pins = GPIOB_IDR & BUS;
        sample->ack_pins[i] = pins;
        sda_high += (pins & SDA) != 0;
        scl_high += (pins & SCL) != 0;
    }
    sample->result = scl_high != 3 ? SCL_TIMEOUT :
        sda_high == 0 ? ACK : sda_high == 3 ? NACK : UNSTABLE;

    GPIOB_BSRR = SCL << 16;
    GPIOB_BSRR = SDA << 16;
    delay_cycles(HALF_PERIOD);
    if (!release_clock()) {
        GPIOB_BSRR = BUS;
        sample->result = SCL_TIMEOUT;
        return;
    }
    delay_cycles(HALF_PERIOD);
    GPIOB_BSRR = SDA;
    delay_cycles(HALF_PERIOD);
    sample->idle_after = GPIOB_IDR & BUS;
    sample->cycles = DWT_CYCCNT - start;
    if (sample->idle_after != BUS) {
        sample->result = STOP_NOT_IDLE;
    }
}

void probe_main(void)
{
    RESULT->magic = 0;
    RESULT->stage = 1;
    RESULT->clock_config = RCC_CFGR;
    RESULT->half_period = HALF_PERIOD;
    DEMCR |= 1u << 24;
    DWT_CYCCNT = 0;
    DWT_CTRL |= 1u;
    for (unsigned i = 0; i < 16; ++i) {
        __asm volatile ("nop");
    }
    if (DWT_CYCCNT != 0) {
        RCC_APB2ENR |= 1u << 3;
        (void)RCC_APB2ENR;
        GPIOB_BSRR = BUS;
        GPIOB_CRH = (GPIOB_CRH & ~0xFFu) | 0x77u;
        delay_cycles(4 * HALF_PERIOD);
        probe_address(&RESULT->addresses[0], 0x3Cu);
        if (RESULT->addresses[0].idle_after == BUS) {
            probe_address(&RESULT->addresses[1], 0x3Du);
            RESULT->stage = 3;
        } else {
            RESULT->stage = 2;
        }
    }
    __asm volatile ("dsb" ::: "memory");
    RESULT->magic = MAILBOX_MAGIC;
    __asm volatile ("dsb" ::: "memory");
    for (;;) {
        __asm volatile ("nop");
    }
}
