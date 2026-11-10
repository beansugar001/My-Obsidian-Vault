#include <stdint.h>

#define REG32(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define MB ((volatile uint32_t *)(uintptr_t)0x2000F000u)
#define CLKEN 0x4002180Cu
#define PERI_RST 0x40021810u
#define GPIOB_ODR 0x40000100u
#define GPIOB_DIR 0x40000104u
#define GPIOB_IDR 0x40000150u
#define GPIOB_OSOD 0x40000158u
#define GPIOB_PUPD 0x4000015Cu
#define GPIOB_AFR1 0x40000168u
#define I2C_MODULE 0x40002800u
#define I2C_TXFIFO 0x40002808u
#define I2C_FIFO 0x4000280Cu
#define I2C_DIV0 0x40002810u
#define I2C_DIV1 0x40002814u
#define I2C_MODE 0x40002820u
#define I2C_ADDR 0x40002824u
#define I2C_MCTR 0x40002828u
#define I2C_HOLD 0x40002838u
#define I2C_STA 0x4000283Cu
#define I2C_RAW 0x40002858u
#define I2C_INTR_CLR 0x40002860u

static inline void fence_io(void) { __asm__ volatile ("fence iorw, iorw" ::: "memory"); }
static inline uint32_t rd(uint32_t a) { uint32_t v = REG32(a); fence_io(); return v; }
static inline void wr(uint32_t a, uint32_t v) { REG32(a) = v; fence_io(); }

/* Snapshot layout: 0 magic, 1 stage, 2-5 clocks/reset/GPIO,
   6-11 init; byte 0x00: 12-20; byte 0xAE: 21-29;
   30 STOP issued, 31-33 final FIFO/STA/RAW. */
static void snap(volatile uint32_t *m, unsigned base, uint32_t *seen_work,
                 uint32_t *seen_data, uint32_t *empty, uint32_t *nack,
                 uint32_t *aerr, uint32_t *iterations, uint32_t *fifo,
                 uint32_t *sta, uint32_t *raw, uint32_t byte)
{
    uint32_t i;
    *seen_work = *seen_data = *empty = *nack = *aerr = 0;
    *fifo = *sta = *raw = 0;
    for (i = 0; i < 3000000u; ++i) {
        *fifo = rd(I2C_FIFO);
        *sta  = rd(I2C_STA);
        *raw  = rd(I2C_RAW);
        if (*sta & 1u) *seen_work = 1;
        if (*sta & 2u) *seen_data = 1;
        if (((*fifo >> 8) & 0xFu) == 0u) *empty = 1;
        if (*raw & 0x2000u) *nack = 1;
        if (*raw & 0x10000u) *aerr = 1;
        if (*nack || *aerr || (*seen_data && *empty)) break;
    }
    m[base + 0] = *seen_work;
    m[base + 1] = *seen_data;
    m[base + 2] = *empty;
    m[base + 3] = *nack;
    m[base + 4] = *aerr;
    m[base + 5] = i;
    (void)byte;
}

int main(void)
{
    volatile uint32_t *m = MB;
    uint32_t clk, seen_work, seen_data, empty, nack, aerr, iterations;
    uint32_t fifo, sta, raw;
    m[0] = 0; m[1] = 1; fence_io();

    clk = rd(CLKEN); m[2] = clk;
    wr(CLKEN, clk | 0x21u); m[3] = rd(CLKEN);
    m[4] = rd(PERI_RST);

    wr(GPIOB_ODR, rd(GPIOB_ODR) | 0xCu);
    wr(GPIOB_OSOD, rd(GPIOB_OSOD) | 0xCu);
    wr(GPIOB_DIR, rd(GPIOB_DIR) | 0xCu);
    wr(GPIOB_AFR1, (rd(GPIOB_AFR1) & ~0xFC0u) | 0x6C0u);
    wr(GPIOB_PUPD, rd(GPIOB_PUPD) | 0x300u);
    m[5] = rd(GPIOB_IDR);

    /* ARM MasterInit settings; no software reset in this stage. */
    wr(I2C_MODULE, 0x0u);
    wr(I2C_DIV0, 0x3E7u); wr(I2C_DIV1, 0x3E7u);
    wr(I2C_MCTR, 0u); wr(I2C_HOLD, 5u);
    wr(I2C_MODULE, 0x0Cu); wr(I2C_MODE, 1u);
    wr(I2C_INTR_CLR, 0x13000u);
    /* V115E address-enable ordering already observed to latch I2C_EN. */
    wr(I2C_ADDR, 0x50u); wr(I2C_MODULE, 0x0Du); wr(I2C_ADDR, 0x3Cu);
    m[6] = rd(I2C_MODULE); m[7] = rd(I2C_ADDR);
    m[8] = rd(I2C_FIFO); m[9] = rd(I2C_STA); m[10] = rd(I2C_RAW);
    m[11] = rd(PERI_RST); m[1] = 2;

    /* SSD1306 command frame, paced exactly one FIFO byte at a time.
       Do not enqueue the second byte until the first is observed drained. */
    wr(I2C_TXFIFO, 0x00u);
    snap(m, 12, &seen_work, &seen_data, &empty, &nack, &aerr,
         &iterations, &fifo, &sta, &raw, 0x00u);
    m[18] = fifo; m[19] = sta; m[20] = raw; m[1] = 3;
    if (!(seen_data && empty) || nack || aerr) goto done;

    wr(I2C_TXFIFO, 0xAEu);
    snap(m, 21, &seen_work, &seen_data, &empty, &nack, &aerr,
         &iterations, &fifo, &sta, &raw, 0xAEu);
    /* Keep the second byte's compact outcome in slots 21..27; final status
       is copied to 28..30 to avoid overlap with its per-byte result. */
    m[27] = fifo; m[28] = sta; m[29] = raw; m[1] = 4;
    if (seen_data && empty && !nack && !aerr) {
        wr(I2C_MCTR, 0x2u); m[30] = 1;
        for (iterations = 0; iterations < 3000000u; ++iterations) {
            sta = rd(I2C_STA); raw = rd(I2C_RAW); fifo = rd(I2C_FIFO);
            if (!(sta & 1u) || raw & (0x2000u | 0x10000u)) break;
        }
    }
done:
    m[31] = rd(I2C_FIFO); m[32] = rd(I2C_STA); m[33] = rd(I2C_RAW);
    m[1] = 0x600Du; fence_io(); m[0] = 0x4D424F58u; fence_io();
    for (;;) __asm__ volatile ("nop");
}
