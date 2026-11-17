#include <stdint.h>
#include "frames.h"

enum {
    CLKEN = 0x4002180C, PERI_RST = 0x40021810,
    GPIOA_AFR1 = 0x40000068, GPIOB_AFR1 = 0x40000168,
    GPIOC_ODR = 0x40000200, GPIOC_DIR = 0x40000204, GPIOC_IDR = 0x40000250,
    GPIOC_OSOD = 0x40000258, GPIOC_PUPD = 0x4000025C, GPIOC_SPEED = 0x40000260,
    GPIOC_DRIVE = 0x40000264, GPIOC_AFR1 = 0x40000268, GPIOC_AFR2 = 0x4000026C,
    I2C_MODULE = 0x40002800, I2C_TX = 0x40002808, I2C_FIFO = 0x4000280C,
    I2C_DIV0 = 0x40002810, I2C_DIV1 = 0x40002814, I2C_MODE = 0x40002820,
    I2C_ADDR = 0x40002824, I2C_MCTR = 0x40002828, I2C_HOLD = 0x40002838,
    I2C_STA = 0x4000283C, I2C_RAW = 0x40002858,
    FIFO_IDLE = 5, TX_COUNT_MASK = 0xF00, WORK = 1, DATA = 2, RAW_STOP = 0x1000,
    POLL_LIMIT = 250000
};

enum {
    MB_MAGIC, MB_STAGE, MB_RESULT, MB_ADDR, MB_EXPECTED, MB_VALUE,
    MB_FIFO, MB_STATUS, MB_RAW, MB_FRAME, MB_BYTE, MB_TX_WRITES, MB_STOPS, MB_DONE
};

#ifdef V159_OFFLINE
extern volatile uint32_t v159_mailbox[];
extern uint32_t rd(uint32_t addr);
extern void wr(uint32_t addr, uint32_t value);
static void fence_io(void) {}
static void power_up_delay(void) {}
#else
#define v159_mailbox ((volatile uint32_t *)(uintptr_t)0x2000F000)
static void fence_io(void) { __asm__ volatile ("fence iorw, iorw" ::: "memory"); }
static uint32_t rd(uint32_t addr)
{
    uint32_t value = *(volatile uint32_t *)(uintptr_t)addr;
    fence_io();
    return value;
}
static void wr(uint32_t addr, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)addr = value;
    fence_io();
}
static void power_up_delay(void)
{
    for (uint32_t i = 0; i < 2000000; ++i) {
        __asm__ volatile ("nop");
    }
}
#endif

static int expect(uint32_t addr, uint32_t mask, uint32_t expected)
{
    uint32_t value = rd(addr);
    if ((value & mask) == expected) return 1;
    v159_mailbox[MB_ADDR] = addr;
    v159_mailbox[MB_EXPECTED] = expected;
    v159_mailbox[MB_VALUE] = value;
    return 0;
}

static int configure(uint32_t addr, uint32_t mask, uint32_t write, uint32_t readback)
{
    uint32_t preserved = (mask == UINT32_MAX) ? 0 : (rd(addr) & ~mask);
    wr(addr, preserved | write);
    return expect(addr, mask, readback);
}

static int idle(void)
{
    return expect(I2C_FIFO, UINT32_MAX, FIFO_IDLE)
        && expect(I2C_STA, UINT32_MAX, 0)
        && expect(I2C_RAW, UINT32_MAX, 0);
}

static int poll_bus(int ending)
{
    for (uint32_t i = 0; i < POLL_LIMIT; ++i) {
        uint32_t fifo = rd(I2C_FIFO);
        uint32_t status = rd(I2C_STA);
        uint32_t raw = rd(I2C_RAW);
        if ((raw & ~(ending ? RAW_STOP : 0u)) || (fifo & TX_COUNT_MASK) > 0x100u) {
            v159_mailbox[MB_FIFO] = fifo;
            v159_mailbox[MB_STATUS] = status;
            v159_mailbox[MB_RAW] = raw;
            return 0;
        }
        if (!(fifo & TX_COUNT_MASK)
            && (ending ? (status & WORK) == 0 && raw == 0 : (status & (WORK | DATA)) == (WORK | DATA))) {
            v159_mailbox[MB_FIFO] = fifo;
            v159_mailbox[MB_STATUS] = status;
            v159_mailbox[MB_RAW] = raw;
            return 1;
        }
    }
    v159_mailbox[MB_FIFO] = rd(I2C_FIFO);
    v159_mailbox[MB_STATUS] = rd(I2C_STA);
    v159_mailbox[MB_RAW] = rd(I2C_RAW);
    return 0;
}

static uint32_t run_display(void)
{
    v159_mailbox[MB_STAGE] = 0x15900001;
    power_up_delay();
    if (!expect(PERI_RST, 0x21, 0) || !expect(CLKEN, 0x20, 0)
        || !configure(CLKEN, 1, 1, 1)) return 1;

    v159_mailbox[MB_STAGE] = 0x15900002;
    if (!expect(GPIOA_AFR1, UINT32_MAX, 0) || !expect(GPIOB_AFR1, UINT32_MAX, 0)
        || !expect(GPIOC_AFR2, UINT32_MAX, 0) || !expect(GPIOC_DIR, 3, 0)
        || !expect(GPIOC_AFR1, 0x3F, 0)) return 2;

    /* Release both wires in GPIO input mode before assigning the I2C function. */
    if (!configure(GPIOC_ODR, 3, 3, 3) || !configure(GPIOC_OSOD, 3, 3, 3)
        || !configure(GPIOC_PUPD, 0xF, 0, 0) || !configure(GPIOC_SPEED, 3, 0, 0)
        || !configure(GPIOC_DRIVE, 3, 3, 3)) return 3;
    for (unsigned i = 0; i < 3; ++i) {
        if (!expect(GPIOC_IDR, 3, 3)) return 4;
    }
    if (!configure(GPIOC_DIR, 3, 3, 3) || !configure(GPIOC_AFR1, 0x3F, 0x1B, 0x1B)
        || !configure(CLKEN, 0x20, 0x20, 0x20)) return 5;

    v159_mailbox[MB_STAGE] = 0x15900003;
    if (!expect(PERI_RST, 0x21, 0) || !expect(I2C_MODULE, UINT32_MAX, 2) || !idle()) return 6;
    if (!configure(I2C_DIV0, UINT32_MAX, 0x3E7, 0x3E7)
        || !configure(I2C_DIV1, UINT32_MAX, 0x3E7, 0x3E7)
        || !configure(I2C_MCTR, UINT32_MAX, 0, 0)
        || !configure(I2C_HOLD, UINT32_MAX, 5, 5)
        || !configure(I2C_MODULE, UINT32_MAX, 0xC, 0xE)
        || !configure(I2C_MODE, UINT32_MAX, 1, 1)
        || !configure(I2C_ADDR, UINT32_MAX, 0x3C, 0x3C)
        || !configure(I2C_MODULE, UINT32_MAX, 0xD, 0xF)) return 7;

    v159_mailbox[MB_STAGE] = 0x15900004;
    for (unsigned f = 0; f < sizeof(frames) / sizeof(frames[0]); ++f) {
        v159_mailbox[MB_FRAME] = f;
        v159_mailbox[MB_BYTE] = UINT32_MAX;
        if (!idle()) return 8;
        uint32_t mctr = rd(I2C_MCTR);
        if (mctr != 0 && mctr != 2) {
            v159_mailbox[MB_ADDR] = I2C_MCTR;
            v159_mailbox[MB_VALUE] = mctr;
            return 9;
        }
        if (mctr == 2 && !configure(I2C_MCTR, UINT32_MAX, 0, 0)) return 9;
        for (unsigned b = 0; b < frames[f].size; ++b) {
            v159_mailbox[MB_BYTE] = b;
            wr(I2C_TX, frames[f].data[b]);
            ++v159_mailbox[MB_TX_WRITES];
            if (!poll_bus(0)) return 10;
        }
        wr(I2C_MCTR, 2);
        ++v159_mailbox[MB_STOPS];
        if (!poll_bus(1)) return 11;
    }
    return 0;
}

uint32_t v159_main(void)
{
    for (unsigned i = 0; i <= MB_DONE; ++i) v159_mailbox[i] = 0;
    fence_io();
    v159_mailbox[MB_MAGIC] = 0x4D423159;
    uint32_t result = run_display();
    v159_mailbox[MB_RESULT] = result;
    fence_io();
    v159_mailbox[MB_DONE] = result ? 0x1590FA11 : 0x1590600D;
    fence_io();
    return result;
}

