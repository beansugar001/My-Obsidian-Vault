#include <assert.h>
#include <stdio.h>
#include <string.h>
#define V160_OFFLINE
#include "main.c"

volatile uint32_t v160_mailbox[MB_LAST_COUNT + 1];
static uint32_t gpio[0x70 / 4], i2c[0x60 / 4], clocks;
static unsigned tx_count, stop_count, frame_byte;
enum fault { OK, LOW_SCL, BAD_ENABLE, NACK, STALL, NO_STOP, LATE_NACK, LATE_STALL, LATE_NO_STOP };
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


static unsigned expected_size(void)
{
    if (stop_count < 6) return frames[stop_count].size;
    assert(stop_count < 410);
    return (stop_count & 1) ? 25 : 4;
}

static unsigned expected_byte(void)
{
    if (stop_count < 6) return frames[stop_count].data[frame_byte];
    unsigned count = (stop_count - 6) / 4;
    unsigned half = ((stop_count - 6) % 4) / 2;
    if (!(stop_count & 1)) {
        const uint8_t command[] = {0, (uint8_t)(0xB2 + half), 0x10, 0};
        return command[frame_byte];
    }
    if (frame_byte == 0) return 0x40;
    char number[4];
    assert(snprintf(number, sizeof(number), "%03u", count) == 3);
    unsigned column = frame_byte - 1;
    return digit_glyphs[number[column / 8] - '0'][8 * half + column % 8];
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
        assert(frame_byte < expected_size());
        assert(value == expected_byte());
        ++frame_byte;
        ++tx_count;
        int stalled = fault == STALL || (fault == LATE_STALL && stop_count == 46);
        int nack = fault == NACK || (fault == LATE_NACK && stop_count == 46);
        i2c[(I2C_FIFO - I2C_MODULE) / 4] = stalled ? 0x104 : 5;
        i2c[(I2C_STA - I2C_MODULE) / 4] = stalled ? 1 : 3;
        i2c[(I2C_RAW - I2C_MODULE) / 4] = nack ? 0x2000 : 0;
    }
    if (addr == I2C_MCTR && value == 2) {
        assert(frame_byte == expected_size());
        ++stop_count;
        frame_byte = 0;
        if (fault != NO_STOP && !(fault == LATE_NO_STOP && stop_count == 47)) i2c[(I2C_STA - I2C_MODULE) / 4] = 0;
    }
}

static void check(enum fault mode, uint32_t expected, unsigned bytes, unsigned stops, uint32_t last_count, unsigned frames_done)
{
    memset(gpio, 0, sizeof(gpio));
    memset(i2c, 0, sizeof(i2c));
    clocks = tx_count = stop_count = frame_byte = 0;
    i2c[0] = 2;
    i2c[(I2C_FIFO - I2C_MODULE) / 4] = 5;
    fault = mode;
    assert(v160_main() == expected);
    assert(v160_mailbox[MB_MAGIC] == 0x4D423160 && v160_mailbox[MB_RESULT] == expected);
    assert(v160_mailbox[MB_DONE] == (expected ? 0x1600FA11u : 0x1600600Du));
    assert(tx_count == bytes && v160_mailbox[MB_TX_WRITES] == bytes);
    assert(stop_count == stops && v160_mailbox[MB_STOPS] == stops);
    assert(v160_mailbox[MB_LAST_COUNT] == last_count && v160_mailbox[MB_FRAMES_DONE] == frames_done);
    printf("PASS scenario=%d result=%u bytes=%u stop=%u frames_done=%u last=%u\n",
           mode, (unsigned)expected, bytes, stops, frames_done, (unsigned)last_count);
}

int main(void)
{
    check(OK, 0, 5975, 410, 100, 410);
    check(LOW_SCL, 4, 0, 0, UINT32_MAX, 0);
    check(BAD_ENABLE, 7, 0, 0, UINT32_MAX, 0);
    check(NACK, 10, 1, 0, UINT32_MAX, 0);
    check(STALL, 10, 1, 0, UINT32_MAX, 0);
    check(NO_STOP, 11, 25, 1, UINT32_MAX, 0);
    check(LATE_NACK, 10, 698, 46, 9, 46);
    check(LATE_STALL, 10, 698, 46, 9, 46);
    check(LATE_NO_STOP, 11, 701, 47, 9, 46);
    return 0;
}
