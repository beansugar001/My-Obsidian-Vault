#include <assert.h>
#include <stdio.h>
#include <string.h>
#define V159_OFFLINE
#include "main.c"

volatile uint32_t v159_mailbox[MB_DONE + 1];
static uint32_t gpio[0x70 / 4], i2c[0x60 / 4], clocks;
static unsigned tx_count, stop_count, frame_byte;
enum fault { OK, LOW_SCL, BAD_ENABLE, NACK, STALL, NO_STOP };
static enum fault fault;

uint32_t rd(uint32_t addr)
{
    if (addr == CLKEN) return clocks;
    if (addr == PERI_RST || addr == GPIOA_AFR1 || addr == GPIOB_AFR1) return 0;
    if (addr == GPIOC_IDR) return fault == LOW_SCL ? 2 : 3;
    if (addr >= GPIOC_ODR && addr <= GPIOC_AFR2) return gpio[(addr - GPIOC_ODR) / 4];
    assert((clocks & 0x20) && addr >= I2C_MODULE && addr <= I2C_RAW);
    return i2c[(addr - I2C_MODULE) / 4];
}

void wr(uint32_t addr, uint32_t value)
{
    if (addr == CLKEN) {
        clocks = value;
        return;
    }
    if (addr >= GPIOC_ODR && addr <= GPIOC_AFR2) {
        gpio[(addr - GPIOC_ODR) / 4] = value;
        return;
    }
    assert((clocks & 0x20) && addr >= I2C_MODULE && addr <= I2C_RAW);
    if (addr == I2C_MODULE) {
        value |= 2;
        if (fault == BAD_ENABLE) value &= ~1u;
    }
    i2c[(addr - I2C_MODULE) / 4] = value;
    if (addr == I2C_TX) {
        assert(rd(GPIOC_AFR1) == 0x1B && rd(GPIOC_ODR) == 3 && rd(GPIOC_OSOD) == 3);
        assert(rd(I2C_MODULE) == 0xF && rd(I2C_MCTR) == 0);
        assert(stop_count < 6 && frame_byte < frames[stop_count].size);
        assert(value == frames[stop_count].data[frame_byte++]);
        ++tx_count;
        i2c[(I2C_FIFO - I2C_MODULE) / 4] = (fault == STALL) ? 0x104 : 5;
        i2c[(I2C_STA - I2C_MODULE) / 4] = (fault == STALL) ? 1 : 3;
        i2c[(I2C_RAW - I2C_MODULE) / 4] = (fault == NACK) ? 0x2000 : 0;
    }
    if (addr == I2C_MCTR && value == 2) {
        assert(stop_count < 6 && frame_byte == frames[stop_count].size);
        ++stop_count;
        frame_byte = 0;
        if (fault != NO_STOP) i2c[(I2C_STA - I2C_MODULE) / 4] = 0;
    }
}

static void check(enum fault mode, uint32_t expected, unsigned bytes, unsigned stops)
{
    memset(gpio, 0, sizeof(gpio));
    memset(i2c, 0, sizeof(i2c));
    clocks = tx_count = stop_count = frame_byte = 0;
    i2c[0] = 2;
    i2c[(I2C_FIFO - I2C_MODULE) / 4] = 5;
    fault = mode;
    assert(v159_main() == expected);
    assert(v159_mailbox[MB_MAGIC] == 0x4D423159 && v159_mailbox[MB_RESULT] == expected);
    assert(v159_mailbox[MB_DONE] == (expected ? 0x1590FA11u : 0x1590600Du));
    assert(tx_count == bytes && v159_mailbox[MB_TX_WRITES] == bytes);
    assert(stop_count == stops && v159_mailbox[MB_STOPS] == stops);
    printf("PASS scenario=%d result=%u bytes=%u stop=%u\n", mode, (unsigned)expected, bytes, stops);
}

int main(void)
{
    check(OK, 0, 117, 6);
    check(LOW_SCL, 4, 0, 0);
    check(BAD_ENABLE, 7, 0, 0);
    check(NACK, 10, 1, 0);
    check(STALL, 10, 1, 0);
    check(NO_STOP, 11, 25, 1);
    return 0;
}
