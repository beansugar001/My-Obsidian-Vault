/**
 * @Description:CJW110时钟相关配置头文件
 *
 *
 *
 ********************************************
 * 版本      日期      作者         变更内容
 * V1.0    2022-5-9    AE          首次发布
 *
 */
#ifndef __CJ32L01xx_RCC_H
#define __CJ32L01xx_RCC_H

#include "cj32l01xx.h"

#define SYSCTRL M0_SYSCTRL

#define LSIVALUE 32768

#define HSI_16MHZ   16000000
#define HSI_24MHZ   24000000
#define HSI_32MHZ   32000000
#define HSI_48MHZ   48000000
#define HSI_60MHZ   60000000
#define STABLE_TIME 50 /* 50MS */

typedef enum
{
    GPIO_PCLK        = 1, /* Enumeration of peripheral clock enable */
    RTC_HCLK         = 1 << 1,
    IWDG_PCLK        = 1 << 2,
    WWDG_PCLK        = 1 << 3,
    I2C_PCLK         = 1 << 5,
    SPI0_PCLK        = 1 << 6,
    SPI1_PCLK        = 1 << 7,
    UART_PCLK        = 1 << 8,
    LPUART_PCLK      = 1 << 9,
    ONEWIRE_PCLK     = 1 << 10,
    FVT_PCLK         = 1 << 11,
    CLK_RANDOM_PCLK  = 1 << 12,
    RTC_OSC32K_PCLK  = 1 << 13,
    IWDG_OSC32K_PCLK = 1 << 14,
    DMA_HCLK         = 1 << 16,
    BOOT_CLK         = 1 << 18,
    EFC_CLK          = 1 << 19,
    CRC_CLK          = 1 << 20,
    TRNG_CLK         = 1 << 21,
    HASH_CLK         = 1 << 22,
    PKE_CLK          = 1 << 23,
    SKE_CLK          = 1 << 24,
    PUF_CLK          = 1 << 25,
    CJENC_PCLK       = 1 << 26,
    CJDEC_PCLK       = 1 << 27,
} PCLK_t;

typedef enum
{
    CLK_HSI16M, /* High Speed Internal clock */
    CLK_HSI24M,
    CLK_HSI32M,
    CLK_HSI48M,
    CLK_HSI60M,
    CLK_LSI, /* Low Speed Internal clock */
} CLK_t;

typedef enum
{
    HS_CLK, /* The system clock is a high speed clock */
    LS_CLK, /* The system clock is a low speed clock */
} HLCLK_t;

typedef enum
{
    INTER_CLK, /* The system clock is an internal clock */
    EXTER_CLK,
    /* The system clock is an external clock */
} IE_CLKSEL_t;

typedef enum
{
    AHB_CLK,
    APB_CLK,
} HPCLK_t;

typedef enum
{
    HPCLK_DIV1, /* Frequency division of AHB or APB clock */
    HPCLK_DIV2,
    HPCLK_DIV4,
    HPCLK_DIV8, /* APB最大分频系数 */
    HPCLK_DIV16,
    HPCLK_DIV32,
    HPCLK_DIV64,
    HPCLK_DIV128, /* AHB最大分频系数 */
} HPCLK_DIV_t;

typedef enum
{
    GPIO_Soft_Rst    = 1, /* peripheral soft reset bits */
    CRC_Soft_Rst     = 1 << 1,
    I2C_Soft_Rst     = 1 << 2,
    TRNG_Soft_Rst    = 1 << 3,
    HASH_Soft_Rst    = 1 << 4,
    PKE_Soft_Rst     = 1 << 5,
    SKE_Soft_Rst     = 1 << 6,
    FVT_Soft_Rst     = 1 << 7,
    WDT_Soft_Rst     = 1 << 9,
    PUF_Soft_Rst     = 1 << 10,
    SPI1_Soft_Rst    = 1 << 11,
    UART0_Soft_Rst   = 1 << 13,
    ONEWIRE_Soft_Rst = 1 << 14,
    LPUART_Soft_Rst  = 1 << 15,
    SPI_Soft_Rst     = 1 << 16,
} psft_rst_t;

typedef enum
{
    LPPWM_clk,  /* Choose LSE clock, pclk or LSI clock for lppwm */
    LPUART_clk, /* Choose LSE clock, pclk or LSI clock for lpuart */
} lpfunc_t;

typedef enum
{
    LPFunc_clk_LSI, /* This enumeration is only for lppwm and lpuart */
    LPFunc_clk_LSE,
    LPFunc_clk_PCLK,
} lpfunc_clk_sel_t;

/* 所有的系统时钟 */
typedef struct
{
    u32 SYS_freq;
    u32 AHB_Freq;
    u32 APB_Freq;
} CLKs_Freq_t;

void PeriCLK_Cmd(PCLK_t pclk, FunctionalState sw);
RES_t CLK_Cmd(CLK_t clk, FunctionalState sw, u32 nms);
RES_t CLK_SwitchTo(CLK_t clk);
void CLK_Div(HPCLK_t clk, HPCLK_DIV_t div);
void Peri_SoftReset(psft_rst_t periph);
void CLK_LpPeriClkSelect(lpfunc_t lpfunc, lpfunc_clk_sel_t sel);
void Get_CLKs_Freq(CLKs_Freq_t* const rcc_clks);
#endif
