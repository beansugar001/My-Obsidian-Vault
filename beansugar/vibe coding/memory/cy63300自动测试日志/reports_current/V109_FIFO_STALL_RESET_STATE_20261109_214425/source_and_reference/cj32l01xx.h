/**
 ******************************************************************************
 * @file    cj32l01xx.h
 * @version V1.0.0
 * @date    2021-10-9
 * @brief   CMSIS Cortex-M0 Device Peripheral Access Layer Header File.
 *          This file contains all the peripheral register's definitions, bits
 *          definitions and memory mapping for cj32l01xx devices..
 */

/** @addtogroup CMSIS
 * @{
 */

/** @addtogroup cj32l01xx
 * @{
 */

#ifndef __CJ32L01XX_H
#define __CJ32L01XX_H

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */

/** @addtogroup Library_configuration_section
 * @{
 */

/* Uncomment the line below according to the target CJ32 device used in your
application
*/

#if !defined(USE_STDPERIPH_DRIVER)
/**
 * @brief Comment the line below if you will not use the peripherals
 drivers. In this case, these drivers will not be included and the
 application code will be based on direct access to peripherals registers
   */
#define USE_STDPERIPH_DRIVER
#endif /* USE_STDPERIPH_DRIVER */

/**
 * @brief CJ32L01xx Standard Peripherals Library version number V1.0.0
 */
#define __CJ32L01xx_STDPERIPH_VERSION_MAIN (0x01) /*!< [31:24] main version */
#define __CJ32L01xx_STDPERIPH_VERSION_SUB1 (0x00) /*!< [23:16] sub1 version */
#define __CJ32L01xx_STDPERIPH_VERSION_SUB2 (0x00) /*!< [15:8]  sub2 version */
#define __CJ32L01xx_STDPERIPH_VERSION_RC                                                                               \
    (0x00) /*!< [7:0]  release candidate                                       \
            */
#define __CJ32L01xx_STDPERIPH_VERSION                                                                                  \
    ((__CJ32L01xx_STDPERIPH_VERSION_MAIN << 24) | (__CJ32L01xx_STDPERIPH_VERSION_SUB1 << 16) |                         \
     (__CJ32L01xx_STDPERIPH_VERSION_SUB2 << 8) | (__CJ32L01xx_STDPERIPH_VERSION_RC))

/**
 * @}
 */

/** @addtogroup Configuration_section_for_CMSIS
 * @{
 */

/**
 * @brief Configuration of the Cortex-M0 Processor and Core Peripherals
 */
#define __CM0PLUS_REV 0x0000 /*!< Core revision                            		 */
#define __MPU_PRESENT 1      /*!< CJ32L01xx provides an MPU                     */
#define __NVIC_PRIO_BITS                                                                                               \
    2                            /*!< CJ32L01xx uses 2 Bits for the Priority Levels                       \
       */
#define __Vendor_SysTickConfig 0 /*!< Set to 1 if different SysTick Config is used  */
#define __FPU_PRESENT          0 /*!< FPU present                                   */

/**
 * @brief CJ32L01xx Interrupt Number Definition, according to the selected
 * device in @ref Library_configuration_section
 */
typedef enum IRQn
{
    /******  Cortex-M0 Processor Exceptions Numbers
     ***************************************************/
    NonMaskableInt_IRQn = -14, /*!< 2 Non Maskable Interrupt */
    HardFault_IRQn      = -13, /*!< 3 Cortex-M0 Hard Fault Interrupt */
    SVCall_IRQn         = -5,  /*!< 11 Cortex-M0 SV Call Interrupt  */
    PendSV_IRQn         = -2,  /*!< 14 Cortex-M0 Pend SV Interrupt  */
    SysTick_IRQn        = -1,  /*!< 15 Cortex-M0 System Tick Interrupt  */

    /******  CM0IKMCU Cortex-M0 specific Interrupt Numbers
     ********************************************/
    EXTI0_IRQn      = 0,
    EXTI1_IRQn      = 1,
    EXTI2_IRQn      = 2,
    EXTI3_IRQn      = 3,
    EXTI4_IRQn      = 4,
    EXTI5_IRQn      = 5,
    RTC_IRQn        = 6,
    WWDG_IRQn       = 7,
    I2C_IRQn        = 8,
    SPI0_IRQn       = 9,
    SPI1_IRQn       = 10,
    UART_IRQn       = 11,
    LPUART_IRQn     = 12,
    ONEWIRE_IRQn    = 13,
    FVT_IRQn        = 14,
    CLK_RANDOM_IRQn = 15,
    DMA_IRQn        = 16,
    TRNG_IRQn       = 17,
    HASH_IRQn       = 18,
    PKE_IRQn        = 19,
    SKE_IRQn        = 20,
    CJENC_IRQn      = 21,
    CJDEC_IRQn      = 22,
    IRQ23_IRQn      = 23,
    IRQ24_IRQn      = 24,
    IRQ25_IRQn      = 25,
    IRQ26_IRQn      = 26,
    IRQ27_IRQn      = 27,
    IRQ28_IRQn      = 28,
    IRQ29_IRQn      = 29,
    IRQ30_IRQn      = 30,
    IRQ31_IRQn      = 31
} IRQn_Type;

#include "core_cm0plus.h" /* Cortex-M0 processor and core peripherals */
#include "system_cj32l01xx.h"
#include <stdint.h>

#include "cj32l01xx_base.h"
#include "stdio.h"

/** @addtogroup Exported_types
 * @{
 */
/*!< cj32l01xx Standard Peripheral Library old types (maintained for legacy
 * purpose) */
typedef int32_t s32;
typedef int16_t s16;
typedef int8_t s8;

typedef const int32_t sc32; /*!< Read Only */
typedef const int16_t sc16; /*!< Read Only */
typedef const int8_t sc8;   /*!< Read Only */

typedef __IO int32_t vs32;
typedef __IO int16_t vs16;
typedef __IO int8_t vs8;

typedef __I int32_t vsc32; /*!< Read Only */
typedef __I int16_t vsc16; /*!< Read Only */
typedef __I int8_t vsc8;   /*!< Read Only */

typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t u8;

typedef const uint32_t uc32; /*!< Read Only */
typedef const uint16_t uc16; /*!< Read Only */
typedef const uint8_t uc8;   /*!< Read Only */

typedef __IO uint32_t vu32;
typedef __IO uint16_t vu16;
typedef __IO uint8_t vu8;

typedef __I uint32_t vuc32; /*!< Read Only */
typedef __I uint16_t vuc16; /*!< Read Only */
typedef __I uint8_t vuc8;   /*!< Read Only */

typedef enum
{
    RESET = 0,
    SET   = !RESET
} FlagStatus,
    ITStatus;

typedef enum
{
    DISABLE = 0,
    ENABLE  = !DISABLE
} FunctionalState;
#define IS_FUNCTIONAL_STATE(STATE) (((STATE) == DISABLE) || ((STATE) == ENABLE))

/** @addtogroup Peripheral_registers_structures
 * @{
 */

#if defined(__CC_ARM)
#pragma anon_unions
#endif

#define USE_BIT_MASK
typedef struct
{
    __IO uint32_t ODR;    // 0x00 offset
    __IO uint32_t DIR;    // 0x04
    uint8_t RESERVED0[0x24];
    __IO uint32_t ISYNC;    // 0x2C
    __IO uint32_t IER;      // 0x30
    __IO uint32_t IMASK;    // 0x34
    __IO uint32_t ITYPE;    // 0x38
    __IO uint32_t ITRIG;    // 0x3c
    __IO uint32_t ISR;      // 0x40
    __IO uint32_t RISR;     // 0x44
    uint8_t RESERVED1[0x4];
    __IO uint32_t ICR;       // 0x4c
    __IO uint32_t IDR;       // 0x50
    __IO uint32_t CS;        // 0x54
    __IO uint32_t OSOD;      // 0x58
    __IO uint32_t PUPD;      // 0x5c
    __IO uint32_t SPEED;     // 0x60
    __IO uint32_t DRIVE;     // 0x64
    __IO uint32_t AF_DG;     // 0x68
    __IO uint32_t AF_ANA;    // 0x6c
} M0_GPIO_TypeDef;

typedef struct
{
    __IO uint32_t SYSCTRL0;           // 0x00 offset
    __IO uint32_t SYSCTRL1;           // 0x04
    __IO uint32_t HSI_CTRL;           // 0x08
    __IO uint32_t PCLK_EN;            // 0x0C
    __IO uint32_t PERI_SOFT_RST;      // 0x10
    __IO uint32_t REMAP_EN;           // 0x14
    __IO uint32_t RTL_KEY_FLAG;       //0x18
    __IO uint32_t SELF_CHECK_FLAG;    //0x1C
    __IO uint32_t ENC_CTRL;           //0x20
    uint8_t RESERVED0[0x1C];
    __IO uint32_t JTAG_EN;    //0x40
} M0_SYSCTRL_Typedef;

typedef struct
{
    __IO uint32_t CCR;
    __IO uint32_t CNDTR;
    __IO uint32_t CPAR;
    __IO uint32_t CMAR;
    uint32_t RESERVED0;
} DMAChannel_Typedef;

typedef struct
{
    __IO uint32_t ISR;     //0x00
    __IO uint32_t IFCR;    //0x04
    DMAChannel_Typedef CHx[8];
} M0_DMA_Typedef;

typedef struct
{
    __IO uint32_t MD_CTR;    // 0x00
    uint8_t RESERVED0[4];
    __IO uint32_t FIFO;        // 0x08
    __IO uint32_t FIFO_SR;     // 0x0c
    __IO uint32_t CLK_DIV0;    // 0x10
    uint8_t RESERVED1[0x2c];
    __IO uint32_t MODE;        // 0x40
    __IO uint32_t CTR;         // 0x44
    __IO uint32_t SR;          // 0x48
    __IO uint32_t ICTR;        // 0x4c
    __IO uint32_t IE;          // 0x50
    __IO uint32_t ISR;         // 0x54
    __IO uint32_t RISR;        // 0x58
    __IO uint32_t IUNMASK;     // 0x5c
    __IO uint32_t ICR;         // 0x60
    __IO uint32_t DMA_CTRL;    //0x64
    __IO uint32_t DMA_TH;      //0x68
} M0_SPI_Typedef;

typedef struct
{
    __IO uint32_t MD_CTR;    // 0x00
    uint8_t RESERVED0[4];
    __IO uint32_t FIFO;        // 0x08
    __IO uint32_t FIFO_SR;     // 0x0c
    __IO uint32_t CLK_DIV0;    // 0x10
    __IO uint32_t CLK_DIV1;    // 0x14
    uint8_t RESERVED1[0x8];
    __IO uint32_t MODE;      // 0x20
    __IO uint32_t ADDR;      // 0x24
    __IO uint32_t MCTR;      // 0x28
    __IO uint32_t MCODE;     // 0x2c
    __IO uint32_t SCTR;      // 0x30
    __IO uint32_t FS_DIV;    // 0x34
    __IO uint32_t HOLD;      // 0x38
    __IO uint32_t SR;        // 0x3c
    uint8_t RESERVED2[0x0c];
    __IO uint32_t ICTR;       // 0x4c
    __IO uint32_t IE;         // 0x50
    __IO uint32_t ISR;        // 0x54
    __IO uint32_t RISR;       // 0x58
    __IO uint32_t IUNMASK;    // 0x5C
    __IO uint32_t ICR;        // 0x60
} M0_I2C_Typedef;

typedef struct
{
    __IO uint32_t DR;     // 0x00
    __IO uint32_t SR;     // 0x04
    __IO uint32_t CTR;    // 0x08
    __IO uint32_t ISR;    // 0x0C
    __IO uint32_t DIV;    // 0x10
} M0_UART_Typedef;

typedef struct
{
    __IO uint32_t KR;      // 0x00
    __IO uint32_t PR;      // 0x04
    __IO uint32_t RLR;     // 0x08
    __IO uint32_t SR;      // 0x0c
    __IO uint32_t WINR;    // 0x10
} M0_IWDG_Typedef;

typedef struct
{
    __IO uint32_t CR;     // 0x00
    __IO uint32_t CFR;    // 0x04
    __IO uint32_t SR;     // 0x08
} M0_WWDG_Typedef;

typedef struct
{
    union
    {
        __IO uint32_t u32DR;
        __IO uint16_t u16DR;
        __IO uint8_t u8DR;
    };                    // 0x00
    __IO uint32_t IDR;    // 0x04
    __IO uint32_t CR;     // 0x08
    uint32_t RESERVED;
    __IO uint32_t INIT;    // 0x10
    __IO uint32_t POL;     // 0x14
} M0_CRC_Typedef;

typedef struct
{
    __IO uint32_t DIV;         // 0x00
    __IO uint32_t CTR;         // 0x04
    __IO uint32_t IE;          // 0x08
    __IO uint32_t IMASK;       // 0x0c
    __IO uint32_t RISR;        // 0x10
    __IO uint32_t ICR;         // 0x14
    __IO uint32_t ADJ;         // 0x18
    __IO uint32_t SEC;         // 0x1c
    __IO uint32_t MIN;         // 0x20
    __IO uint32_t HOUR;        // 0x24
    __IO uint32_t DAY;         // 0x28
    __IO uint32_t MONTH;       // 0x2c
    __IO uint32_t YEAR;        // 0x30
    __IO uint32_t SER_ALM;     // 0x34
    __IO uint32_t MIN_ALM;     // 0x38
    __IO uint32_t HOUR_ALM;    // 0x3C
    __IO uint32_t DAY_ALM;     // 0x40
} M0_RTC_Typedef;

typedef struct
{
    __IO uint32_t CTR;         // 0x00
    __IO uint32_t READ_CYC;    // 0x04
    __IO uint32_t COMMON;      // 0x08
    __IO uint32_t WRITE1;
    __IO uint32_t WRITE2;
    __IO uint32_t WRITE3;
    __IO uint32_t ERASE1;
    __IO uint32_t ERASE2;
} M0_EFC_Typedef;

typedef struct
{
    __IO uint32_t JTAG_DISABLE;       // 0x00
    __IO uint32_t PUF_CPU_DISABLE;    // 0x04
    __IO uint32_t RAM_KEY_DISABLE;    // 0x08
    __IO uint32_t BUS_KEY_DISABLE;    // 0x0C
    __IO uint32_t FLS_KEY_DISABLE;    // 0x10
    __IO uint32_t TEST_CR;            // 0x14
    __IO uint32_t BL_TRIM;            // 0x18
    __IO uint32_t OSC_ADJ_CAP;        // 0x1C
    __IO uint32_t OSC_ADJ_TRIM;       // 0x20
    __IO uint32_t OSC_CR;             // 0x24
    __IO uint32_t FVT_TRIM;           // 0x28
    __IO uint32_t ENC_CR;             // 0x2C
    __O uint32_t RAM_KEY;             // 0x30
    __O uint32_t BUS_KEY;             // 0x34
    __O uint32_t FLS_KEY;             // 0x38
    __I uint32_t PROT_LEVEL;          // 0x3C
    __IO uint32_t FLAG1;              // 0x40
    __IO uint32_t FLAG2;              // 0x44
} M0_BOOT_TypeDef;

typedef struct
{
    __IO uint32_t START;
    __IO uint32_t TEST_NUM;
    __IO uint32_t BUSY;
    __IO uint32_t S[32];
    __IO uint32_t L[32];
    __IO uint8_t RESERVED[0x400 - 0x104 - 4];
    __IO uint32_t H_TH;    //0x400
} M0_PUF_TypeDef;

typedef struct
{
    __IO uint32_t CR;
    __IO uint32_t ISR;
    __IO uint32_t ICR;
    __IO uint32_t DIN;
    __IO uint32_t DOUT;
    __IO uint32_t KEY;
    __IO uint32_t SIGMA;
} M0_CJENCDEC_TypeDef;

typedef struct
{
    __IO uint32_t CTR;    // 0
    __IO uint32_t MDR;    // 4
    __IO uint32_t SR;     // 8
    __IO uint32_t DR;     // c
    __IO uint32_t VER;    // 0x10
    uint32_t RESERVED0[11];
    __IO uint32_t RESEED;    // 0x40
    uint32_t RESERVED1[7];
    __IO uint32_t HT_CTR;    // 0x60
    uint32_t RESERVED2[3];
    __IO uint32_t HT_SR;    // 0x70
    uint32_t RESERVED3[3];
    __IO uint32_t RO_SRC_EN1;    // 0x80
    __IO uint32_t RO_SRC_EN2;    // 0x84
    __IO uint32_t SCLK;          // 0x88
    uint32_t RESERVED4[9];
    __IO uint32_t TERO_CTR;      // 0xB0
    __IO uint32_t TERO_THOLD;    // 0xB4
    uint32_t RESERVED5[2];
    __IO uint32_t TERO_CNT[4];    // 0xC0~0xCC
    __IO uint32_t TERO_SR;        // 0xD0
    __IO uint32_t TERO_DR;        // 0xD4
    uint32_t RESERVED6[2];
    __IO uint32_t TERO_RCR[8];    // 0xE0
} M0_TRNG_TypeDef;

typedef struct
{
    __IO uint32_t CTR;
    __IO uint32_t CFG;
    __IO uint32_t SR1;
    __IO uint32_t SR2;
    __IO uint32_t RESERVED0[4];
    __IO uint32_t LEN[4];     // 0x20~0x2C
    __IO uint32_t HOR[16];    // 0x30~0x6C
    __IO uint32_t HIR[16];    // 0x70~0xAC
    __IO uint32_t VER;        // 0xB0
    __IO uint32_t RESERVED1[19];
    __IO uint32_t MIR[32];    // 0x100~0x17C
    __IO uint32_t DMA_SAR;    // 0x180
    __IO uint32_t DMA_DAR;    // 0x184
    //__IO uint32_t DMA_RLEN; //0x188
    //__IO uint32_t DMA_WLEN; //0x18C
} M0_HASH_TypeDef;

typedef struct
{
    __IO uint32_t CTR;
    __IO uint32_t CFG;
    __IO uint32_t MC_PTR;
    __IO uint32_t RISR;
    __IO uint32_t IER;
    __IO uint32_t MISR;    // 0x14
    uint32_t RESERVED0[3];
    __IO uint32_t RT_CODE;    // 0x24
    uint32_t RESERVED1[6];
    __IO uint32_t SEED;    // 0x40
    uint32_t RESERVED2[3];
    __IO uint32_t EXE_CFG;    // 0x50
    uint32_t RESERVED3[3];
    __IO uint32_t RC_EN;         // 0x60
    __IO uint32_t RC_KEY;        // 0x64
    __IO uint32_t RC_D_NONCE;    // 0x68
    __IO uint32_t RC_A_NONCE;    // 0x6C
    uint32_t RESERVED4[35];
    __IO uint32_t VER;    // 0xFC
    uint32_t RESERVED5[192];
    __IO uint32_t MEMA[645];    // 0x400~0xE10
    uint32_t RESERVED6[123];
    __IO uint32_t MEMB[645];    // 0x1000-0x1A10
} M0_PKE_TypeDef;

typedef struct
{
    __IO uint32_t CTR;
    __IO uint32_t CFG;
    __IO uint32_t SR1;
    __IO uint32_t SR2;
    uint8_t RESERVED0[0x50];
    __IO uint32_t AES_CFG;    // 0x60
    uint32_t RESERVED1[3];
    __IO uint32_t IV[4];     // 0x70~0x7C
    __IO uint32_t KEY[8];    // 0x80~0x9C
    uint32_t RESERVED2[24];
    __IO uint32_t RNG_SEED[9];    // 0x100~0x120
    uint32_t RESERVED3[3];
    __IO uint32_t RNG_CTR;    // 0x130
    uint32_t RESERVED4[3];
    __IO uint32_t VER;    // 0x140
    uint32_t RESERVED5[47];
    __IO uint32_t IDR[4];    // 0x200~0x20C
    __IO uint32_t ODR[4];
} M0_SKE_TypeDef;

typedef struct
{
    __IO uint32_t SEED;
    __IO uint32_t MODE;
    __IO uint32_t IRQ;
} M0_RANDOM_CLK_TypeDef;

typedef struct
{
    struct
    {
        __IO uint32_t EN;    // 0x00
        __IO uint32_t ALM;
        uint32_t RESERVED0;
        __IO uint32_t IE;
        __IO uint32_t RISR_H;    // 0x10
        __IO uint32_t RISR_L;
    } TEMP;
    struct
    {
        __IO uint32_t EN;    // 0x18
        __IO uint32_t ALM;
        uint32_t RESERVED0;    // 0x20
        __IO uint32_t IE;
        __IO uint32_t RISR_H;
        __IO uint32_t RISR_L;
    } VD;
    struct
    {
        __IO uint32_t EN;    // 0x30
        __IO uint32_t ALM;
        uint32_t RESERVED0;
        __IO uint32_t IE;
        __IO uint32_t RISR_H;    // 0x40
        __IO uint32_t RISR_L;
    } FREQ;
    __IO uint32_t ICLR;
    __IO uint32_t ISR;
    __IO uint32_t ICR;    // 0x50
    __IO uint32_t FREQ_H;
    __IO uint32_t FREQ_L;
    __IO uint32_t FREQ_CNT;
    struct
    {
        __IO uint32_t EN;    // 0x60
        __IO uint32_t ALM;
        __IO uint32_t IE;
        __IO uint32_t RISR;    // 0x6c
        __IO uint32_t H_CNT;
        __IO uint32_t L_CNT;
        __IO uint32_t CNT;
        __IO uint32_t LB_CNT;
    } VD_GLITCH;
} M0_FVT_TypeDef;

/******************************************************************************/
/*                         Peripheral memory map */
/******************************************************************************/
/* Peripheral and SRAM base address */
#define FLASH_BASE     ((uint32_t)0x00001000)
#define SRAM1_BASE     ((uint32_t)0x20000000)
#define PERIPH_BASE    ((uint32_t)0x40000000)
#define ROM_TABLE_BASE ((uint32_t)0xE00FF000)
#define SRAM_BASE      SRAM1_BASE

/* Peripheral memory map */
#define BOOT_BASE       (PERIPH_BASE + 0x21000)
#define GPIOA_BASE      (PERIPH_BASE)
#define GPIOB_BASE      (PERIPH_BASE + 0x0100)
#define GPIOC_BASE      (PERIPH_BASE + 0x0200)
#define CRC_BASE        (PERIPH_BASE + 0x22800)
#define I2C_BASE        (PERIPH_BASE + 0x02800)
#define SPI0_BASE       (PERIPH_BASE + 0x03000)
#define SPI1_BASE       (PERIPH_BASE + 0x03400)
#define UART0_BASE      (PERIPH_BASE + 0x03C00)
#define ONEWIRE_BASE    (PERIPH_BASE + 0x04800)
#define LPUART_BASE     (PERIPH_BASE + 0x04000)
#define RTC_BASE        (PERIPH_BASE + 0x00800)
#define IWDG_BASE       (PERIPH_BASE + 0x01000)
#define WWDG_BASE       (PERIPH_BASE + 0x01400)
#define SYSC_BASE       (PERIPH_BASE + 0x21800)
#define FVT_BASE        (PERIPH_BASE + 0x05000)
#define EFC_REG_BASE    (PERIPH_BASE + 0x22000)
#define DMA_BASE        (PERIPH_BASE + 0x20000)
#define TRNG_BASE       (PERIPH_BASE + 0x23000)
#define HASH_BASE       (PERIPH_BASE + 0x24000)
#define PKE_BASE        (PERIPH_BASE + 0x26000)
#define SKE_BASE        (PERIPH_BASE + 0x30000)
#define PUF_BASE        (PERIPH_BASE + 0x40000)
#define CJENC_BASE      (PERIPH_BASE + 0x50000)
#define CJDEC_BASE      (PERIPH_BASE + 0x60000)
#define RANDOM_CLK_BASE (PERIPH_BASE + 0x5800)

/******************************************************************************/
/*                         Peripheral declaration */
/******************************************************************************/
#define M0_BOOT       ((M0_BOOT_TypeDef*)BOOT_BASE)
#define M0_GPIOA      ((M0_GPIO_TypeDef*)GPIOA_BASE)
#define M0_GPIOB      ((M0_GPIO_TypeDef*)GPIOB_BASE)
#define M0_GPIOC      ((M0_GPIO_TypeDef*)GPIOC_BASE)
#define M0_SYSCTRL    ((M0_SYSCTRL_Typedef*)SYSC_BASE)
#define M0_SPI0       ((M0_SPI_Typedef*)SPI0_BASE)
#define M0_SPI1       ((M0_SPI_Typedef*)SPI1_BASE)
#define M0_I2C        ((M0_I2C_Typedef*)I2C_BASE)
#define M0_UART0      ((M0_UART_Typedef*)UART0_BASE)
#define M0_WWDG       ((M0_WWDG_Typedef*)WWDG_BASE)
#define M0_IWDG       ((M0_IWDG_Typedef*)IWDG_BASE)
#define M0_LPUART     ((M0_UART_Typedef*)LPUART_BASE)
#define M0_CRC        ((M0_CRC_Typedef*)CRC_BASE)
#define M0_RTC        ((M0_RTC_Typedef*)RTC_BASE)
#define M0_EFC        ((M0_EFC_Typedef*)EFC_REG_BASE)
#define M0_FVT        ((M0_FVT_TypeDef*)FVT_BASE)
#define M0_PUF        ((M0_PUF_TypeDef*)PUF_BASE)
#define M0_TRNG       ((M0_TRNG_TypeDef*)TRNG_BASE)
#define M0_HASH       ((M0_HASH_TypeDef*)HASH_BASE)
#define M0_PKE        ((M0_PKE_TypeDef*)PKE_BASE)
#define M0_SKE        ((M0_SKE_TypeDef*)SKE_BASE)
#define M0_CJENC      ((M0_CJENCDEC_TypeDef*)CJENC_BASE)
#define M0_CJDEC      ((M0_CJENCDEC_TypeDef*)CJDEC_BASE)
#define M0_DMA        ((M0_DMA_Typedef*)DMA_BASE)
#define M0_RANDOM_CLK ((M0_RANDOM_CLK_TypeDef*)RANDOM_CLK_BASE)

#ifdef USE_STDPERIPH_DRIVER
#include "cj32l01xx_conf.h"
#endif /* USE_STDPERIPH_DRIVER */

/*GPIO Bit Mask*/
#define GPIO_OS_TYPE_Pos   (6UL)
#define GPIO_PU_TYPE_Pos   (6UL)
#define GPIO_AFR1_TYPE_Msk (7UL)
#define GPIO_AFR2_TYPE_Msk (3UL)
/*SYSCTRL Bit Mask*/
#define SYSCTRL_SYSCLK_SEL_Msk              (1UL)
#define SYSCTRL_HCLK_SEL_Pos                (1UL)
#define SYSCTRL_HCLK_SEL_Msk                (1UL << SYSCTRL_HCLK_SEL_Pos)
#define SYSCTRL_LCLK_SEL_Pos                (2UL)
#define SYSCTRL_LCLK_SEL_Msk                (1UL << SYSCTRL_LCLK_SEL_Pos)
#define SYSCTRL_APBCLK_DIV_Pos              (3UL)
#define SYSCTRL_APBCLK_DIV_Msk              (3 << SYSCTRL_APBCLK_DIV_Pos)
#define SYSCTRL_AHBCLK_DIV_Pos              (5UL)
#define SYSCTRL_AHBCLK_DIV_Msk              (7 << SYSCTRL_AHBCLK_DIV_Pos)
#define SYSCTRL_WAIT_HSE_STABLE_Msk         (1UL)
#define SYSCTRL_LPPWM_CLK_SEL_Pos           (1UL)
#define SYSCTRL_LPPWM_CLK_SEL_Msk           (3 << SYSCTRL_LPPWM_CLK_SEL_Pos)
#define SYSCTRL_LPUART_CLK_SEL_Pos          (3UL)
#define SYSCTRL_LPUART_CLK_SEL_Msk          (3 << SYSCTRL_LPUART_CLK_SEL_Pos)
#define SYSCTRL_HSI_EN_Msk                  (1UL)
#define SYSCTRL_HSI_TRIM_Pos                (1UL)
#define SYSCTRL_HSI_TRIM_Msk                (3 << SYSCTRL_HSI_TRIM_Pos)
#define SYSCTRL_LSI_EN_Msk                  (1UL)
#define SYSCTRL_HSE_EN_Msk                  (1UL)
#define SYSCTRL_LSE_EN_Msk                  (1UL)
#define SYSCTRL_CLK_STABLE_CNT_Msk          (0x7FFFUL)
#define SYSCTRL_CLK_STABLE_Pos              (15UL)
#define SYSCTRL_CLK_STABLE_Msk              (1 << SYSCTRL_CLK_STABLE_Pos)
#define SYSCTRL_FLS_READY_TIME_Msk          (0x7FUL)
#define SYSCTRL_GPIO_PCLK_EN_Msk            (1UL)
#define SYSCTRL_CRC_HCLK_EN_Pos             (1UL)
#define SYSCTRL_CRC_HCLK_EN_Msk             (1 << SYSCTRL_CRC_HCLK_EN_Pos)
#define SYSCTRL_I2C_PCLK_EN_Pos             (2UL)
#define SYSCTRL_I2C_PCLK_EN_Msk             (1 << SYSCTRL_I2C_PCLK_EN_Pos)
#define SYSCTRL_AFEC_PCLK_EN_Pos            (3UL)
#define SYSCTRL_AFEC_PCLK_EN_Msk            (1 << SYSCTRL_AFEC_PCLK_EN_Pos)
#define SYSCTRL_ADC_PCLK_EN_Pos             (4UL)
#define SYSCTRL_ADC_PCLK_EN_Msk             (1 << SYSCTRL_ADC_PCLK_EN_Pos)
#define SYSCTRL_SINKC_PCLK_EN_Pos           (5UL)
#define SYSCTRL_SINKC_PCLK_EN_Msk           (1 << SYSCTRL_SINKC_PCLK_EN_Pos)
#define SYSCTRL_RTC_PCLK_EN_Pos             (6UL)
#define SYSCTRL_RTC_PCLK_EN_Msk             (1 << SYSCTRL_RTC_PCLK_EN_Pos)
#define SYSCTRL_CMPC0_PCLK_EN_Pos           (7UL)
#define SYSCTRL_CMPC0_PCLK_EN_Msk           (1 << SYSCTRL_CMPC0_PCLK_EN_Pos)
#define SYSCTRL_CMPC1_PCLK_EN_Pos           (8UL)
#define SYSCTRL_CMPC1_PCLK_EN_Msk           (1 << SYSCTRL_CMPC1_PCLK_EN_Pos)
#define SYSCTRL_WDT_PCLK_EN_Pos             (9UL)
#define SYSCTRL_WDT_PCLK_EN_Msk             (1 << SYSCTRL_WDT_PCLK_EN_Pos)
#define SYSCTRL_TIMA_PCLK_EN_Pos            (10UL)
#define SYSCTRL_TIMA_PCLK_EN_Msk            (1 << SYSCTRL_TIMA_PCLK_EN_Pos)
#define SYSCTRL_TIMB_PCLK_EN_Pos            (11UL)
#define SYSCTRL_TIMB_PCLK_EN_Msk            (1 << SYSCTRL_TIMB_PCLK_EN_Pos)
#define SYSCTRL_LPPWM_PCLK_EN_Pos           (12UL)
#define SYSCTRL_LPPWM_PCLK_EN_Msk           (1 << SYSCTRL_LPPWM_PCLK_EN_Pos)
#define SYSCTRL_UART0_PCLK_EN_Pos           (13UL)
#define SYSCTRL_UART0_PCLK_EN_Msk           (1 << SYSCTRL_UART0_PCLK_EN_Pos)
#define SYSCTRL_UART1_PCLK_EN_Pos           (14UL)
#define SYSCTRL_UART1_PCLK_EN_Msk           (1 << SYSCTRL_UART1_PCLK_EN_Pos)
#define SYSCTRL_LPUART_PCLK_EN_Pos          (15UL)
#define SYSCTRL_LPUART_PCLK_EN_Msk          (1 << SYSCTRL_LPUART_PCLK_EN_Pos)
#define SYSCTRL_SPI_PCLK_EN_Pos             (16UL)
#define SYSCTRL_SPI_PCLK_EN_Msk             (1 << SYSCTRL_SPI_PCLK_EN_Pos)
#define SYSCTRL_WDT_CLK_EN_Pos              (17UL)
#define SYSCTRL_WDT_CLK_EN_Msk              (1 << SYSCTRL_WDT_CLK_EN_Pos)
#define SYSCTRL_RTC_CLK_EN_Pos              (18UL)
#define SYSCTRL_RTC_CLK_EN_Msk              (1 << SYSCTRL_RTC_CLK_EN_Pos)
#define SYSCTRL_BOOT_CLK_EN_Pos             (19UL)
#define SYSCTRL_BOOT_CLK_EN_Msk             (1 << SYSCTRL_BOOT_CLK_EN_Pos)
#define SYSCTRL_EFC_REG_CLK_EN_Pos          (20UL)
#define SYSCTRL_EFC_REG_CLK_EN_Msk          (1 << SYSCTRL_EFC_REG_CLK_EN_Pos)
#define SYSCTRL_GPIO_SOFT_RST_Msk           (1UL)
#define SYSCTRL_CRC_SOFT_RST_Pos            (1UL)
#define SYSCTRL_CRC_SOFT_RST_Msk            (1 << SYSCTRL_CRC_SOFT_RST_Pos)
#define SYSCTRL_I2C_SOFT_RST_Pos            (2UL)
#define SYSCTRL_I2C_SOFT_RST_Msk            (1 << SYSCTRL_I2C_SOFT_RST_Pos)
#define SYSCTRL_AFEC_SOFT_RST_Pos           (3UL)
#define SYSCTRL_AFEC_SOFT_RST_Msk           (1 << SYSCTRL_AFEC_SOFT_RST_Pos)
#define SYSCTRL_ADC_SOFT_RST_Pos            (4UL)
#define SYSCTRL_ADC_SOFT_RST_Msk            (1 << SYSCTRL_ADC_SOFT_RST_Pos)
#define SYSCTRL_SINKC_SOFT_RST_Pos          (5UL)
#define SYSCTRL_SINKC_SOFT_RST_Msk          (1 << SYSCTRL_SINKC_SOFT_RST_Pos)
#define SYSCTRL_CMPC0_SOFT_RST_Pos          (7UL)
#define SYSCTRL_CMPC0_SOFT_RST_Msk          (1 << SYSCTRL_CMPC0_SOFT_RST_Pos)
#define SYSCTRL_CMPC1_SOFT_RST_Pos          (8UL)
#define SYSCTRL_CMPC1_SOFT_RST_Msk          (1 << SYSCTRL_CMPC1_SOFT_RST_Pos)
#define SYSCTRL_WDT_SOFT_RST_Pos            (9UL)
#define SYSCTRL_WDT_SOFT_RST_Msk            (1 << SYSCTRL_WDT_SOFT_RST_Pos)
#define SYSCTRL_TIM0_SOFT_RST_Pos           (10UL)
#define SYSCTRL_TIM0_SOFT_RST_Msk           (1 << SYSCTRL_TIM0_SOFT_RST_Pos)
#define SYSCTRL_TIM1_SOFT_RST_Pos           (11UL)
#define SYSCTRL_TIM1_SOFT_RST_Msk           (1 << SYSCTRL_TIM1_SOFT_RST_Pos)
#define SYSCTRL_LPPWM_SOFT_RST_Pos          (12UL)
#define SYSCTRL_LPPWM_SOFT_RST_Msk          (1 << SYSCTRL_LPPWM_SOFT_RST_Pos)
#define SYSCTRL_UART0_SOFT_RST_Pos          (13UL)
#define SYSCTRL_UART0_SOFT_RST_Msk          (1 << SYSCTRL_UART0_SOFT_RST_Pos)
#define SYSCTRL_UART1_SOFT_RST_Pos          (14UL)
#define SYSCTRL_UART1_SOFT_RST_Msk          (1 << SYSCTRL_UART1_SOFT_RST_Pos)
#define SYSCTRL_LPUART_SOFT_RST_Pos         (15UL)
#define SYSCTRL_LPUART_SOFT_RST_Msk         (1 << SYSCTRL_LPUART_SOFT_RST_Pos)
#define SYSCTRL_SPI_SOFT_RST_Pos            (16UL)
#define SYSCTRL_SPI_SOFT_RST_Msk            (1 << SYSCTRL_SPI_SOFT_RST_Pos)
#define SYSCTRL_REMAP_EN_Msk                (1UL)
#define SYSCTRL_PVDINTCTRL_INTEN_Msk        (1UL)
#define SYSCTRL_PVDINTCTRL_INTTYPE_Pos      (1U)
#define SYSCTRL_PVDINTCTRL_INTTYPE_Msk      (1UL << SYSCTRL_PVDINTCTRL_INTTYPE_Pos)
#define SYSCTRL_PVDINTCTRL_INTRAW_Pos       (2U)
#define SYSCTRL_PVDINTCTRL_INTRAW_Msk       (1UL << SYSCTRL_PVDINTCTRL_INTRAW_Pos)
#define SYSCTRL_ANALOGCTRL1_LPBGENb_Msk     (1UL)
#define SYSCTRL_ANALOGCTRL1_LPLDOENb_Pos    (1U)
#define SYSCTRL_ANALOGCTRL1_LPLDOENb_Msk    (1UL << SYSCTRL_ANALOGCTRL1_LPLDOENb_Pos)
#define SYSCTRL_ANALOGCTRL1_LPVCCPORTDE_Pos (2U)
#define SYSCTRL_ANALOGCTRL1_LPVCCPORTDE_Msk (1UL << SYSCTRL_ANALOGCTRL1_LPVCCPORTDE_Pos)
#define SYSCTRL_ANALOGCTRL1_LPVDDPORTDE_Pos (3U)
#define SYSCTRL_ANALOGCTRL1_LPVDDPORTDE_Msk (1UL << SYSCTRL_ANALOGCTRL1_LPVDDPORTDE_Pos)
#define SYSCTRL_ANALOGCTRL1_V1P2EN_Pos      (4U)
#define SYSCTRL_ANALOGCTRL1_V1P2EN_Msk      (1UL << SYSCTRL_ANALOGCTRL1_V1P2EN_Pos)
#define SYSCTRL_ANALOGCTRL1_V2P0EN_Pos      (5U)
#define SYSCTRL_ANALOGCTRL1_V2P0EN_Msk      (1UL << SYSCTRL_ANALOGCTRL1_V2P0EN_Pos)
#define SYSCTRL_ANALOGCTRL1_V2P5EN_Pos      (6U)
#define SYSCTRL_ANALOGCTRL1_V2P5EN_Msk      (1UL << SYSCTRL_ANALOGCTRL1_V2P5EN_Pos)
#define SYSCTRL_ANALOGCTRL1_PVDEN_Pos       (7U)
#define SYSCTRL_ANALOGCTRL1_PVDEN_Msk       (1UL << SYSCTRL_ANALOGCTRL1_PVDEN_Pos)
#define SYSCTRL_ANALOGCTRL1_IBIASEN_Pos     (8U)    // from strong vdd for afe cmp temp
#define SYSCTRL_ANALOGCTRL1_IBIASEN_Msk     (1UL << SYSCTRL_ANALOGCTRL1_IBIASEN_Pos)
#define SYSCTRL_ANALOGCTRL2_PVDLEVEL_Msk    (7UL)
#define SYSCTRL_ANALOGCTRL2_RESARRAY_Pos    (3U)
#define SYSCTRL_ANALOGCTRL2_RESARRAY_Msk    (0x3FUL << SYSCTRL_ANALOGCTRL2_RESARRAY_Pos)
#define SYSCTRL_ANALOGCTRL2_RESINPUT_Pos    (9U)
#define SYSCTRL_ANALOGCTRL2_RESINPUT_Msk    (7UL << SYSCTRL_ANALOGCTRL2_RESINPUT_Pos)
#define SYSCTRL_ANALOGCTRL2_TEMPTRTD_Pos    (12U)
#define SYSCTRL_ANALOGCTRL2_TEMPTRTD_Msk    (0x0FUL << SYSCTRL_ANALOGCTRL2_TEMPTRTD_Pos)
#define SYSCTRL_ANALOGCTRL3_MUX0_Msk        (7UL)
#define SYSCTRL_ANALOGCTRL3_MUX1_Pos        (3U)
#define SYSCTRL_ANALOGCTRL3_MUX1_Msk        (7UL << SYSCTRL_ANALOGCTRL3_MUX1_Pos)
#define SYSCTRL_ANALOGCTRL3_MUX2_Pos        (6U)
#define SYSCTRL_ANALOGCTRL3_MUX2_Msk        (7UL << SYSCTRL_ANALOGCTRL3_MUX2_Pos)
#define SYSCTRL_ANALOGCTRL3_MUX3_Pos        (9U)
#define SYSCTRL_ANALOGCTRL3_MUX3_Msk        (7UL << SYSCTRL_ANALOGCTRL3_MUX3_Pos)
#define SYSCTRL_ANALOGCTRL3_MUX4_Pos        (12U)
#define SYSCTRL_ANALOGCTRL3_MUX4_Msk        (7UL << SYSCTRL_ANALOGCTRL3_MUX4_Pos)
#define SYSCTRL_ANALOGCTRL3_MUX5_Pos        (15U)
#define SYSCTRL_ANALOGCTRL3_MUX5_Msk        (7UL << SYSCTRL_ANALOGCTRL3_MUX5_Pos)
/*SPI Bit Mask*/
#define SPI_EN_Msk               (1UL)
#define SPI_TX_FIFO_EN_Pos       (2UL)
#define SPI_TX_FIFO_EN_Msk       (1 << SPI_TX_FIFO_EN_Pos)
#define SPI_RX_FIFO_EN_Pos       (3UL)
#define SPI_RX_FIFO_EN_Msk       (1 << SPI_RX_FIFO_EN_Pos)
#define SPI_DATA_Msk             (0xFFFFUL)
#define SPI_FIFOSTA_TX_EMPTY_Msk (1UL)
#define SPI_FIFOSTA_TX_FULL_Pos  (1UL)
#define SPI_FIFOSTA_TX_FULL_Msk  (1 << SPI_FIFOSTA_TX_FULL_Pos)
#define SPI_FIFOSTA_RX_EMPTY_Pos (2UL)
#define SPI_FIFOSTA_RX_EMPTY_Msk (1 << SPI_FIFOSTA_RX_EMPTY_Pos)
#define SPI_FIFOSTA_RX_FULL_Pos  (3UL)
#define SPI_FIFOSTA_RX_FULL_Msk  (1 << SPI_FIFOSTA_RX_FULL_Pos)
#define SPI_FIFOSTA_TX_NUM_Pos   (8UL)
#define SPI_FIFOSTA_TX_NUM_Msk   (0xF << SPI_FIFOSTA_TX_NUM_Pos)
#define SPI_FIFOSTA_RX_NUM_Pos   (16UL)
#define SPI_FIFOSTA_RX_NUM_Msk   (0xF << SPI_FIFOSTA_RX_NUM_Pos)
#define SPI_DIV_Msk              (0xFFFFFFUL)
#define SPI_MS_MODE_Msk          (1UL)
#define SPI_DATA_SIZE_Msk        (0xFUL)
#define SPI_TMOD_Pos             (4UL)
#define SPI_TMOD_Msk             (3 << SPI_TMOD_Pos)
#define SPI_CPHA_Pos             (6UL)
#define SPI_CPHA_Msk             (1 << SPI_CPHA_Pos)
#define SPI_CPOL_Pos             (7UL)
#define SPI_CPOL_Msk             (1 << SPI_CPOL_Pos)
#define SPI_NSS_TOGGLE_Pos       (8UL)
#define SPI_NSS_TOGGLE_Msk       (1 << SPI_NSS_TOGGLE_Pos)
#define SPI_WORKING_Msk          (1UL)

#define SPI_TX_FIFO_TH_Msk (3UL)
#define SPI_RX_FIFO_TH_Pos (8UL)
#define SPI_RX_FIFO_TH_Msk (3 << SPI_RX_FIFO_TH_Pos)
#define SPI_TH_MODE_Pos    (16UL)
#define SPI_TH_MODE_Msk    (1 << SPI_TH_MODE_Pos)

#define SPI_TX_THOLD_EN_Msk (1UL)
#define SPI_TX_EMPTY_EN_Pos (1UL)
#define SPI_TX_EMPTY_EN_Msk (1 << SPI_TX_EMPTY_EN_Pos)
#define SPI_TX_FULL_EN_Pos  (2UL)
#define SPI_TX_FULL_EN_Msk  (1 << SPI_TX_FULL_EN_Pos)
#define SPI_TX_RERR_EN_Pos  (3UL)
#define SPI_TX_RERR_EN_Msk  (1 << SPI_TX_RERR_EN_Pos)
#define SPI_TX_WERR_EN_Pos  (4UL)
#define SPI_TX_WERR_EN_Msk  (1 << SPI_TX_WERR_EN_Pos)
#define SPI_RX_THOLD_EN_Pos (5UL)
#define SPI_RX_THOLD_EN_Msk (1 << SPI_RX_THOLD_EN_Pos)
#define SPI_RX_EMPTY_EN_Pos (6UL)
#define SPI_RX_EMPTY_EN_Msk (1 << SPI_RX_EMPTY_EN_Pos)
#define SPI_RX_FULL_EN_Pos  (7UL)
#define SPI_RX_FULL_EN_Msk  (1 << SPI_RX_FULL_EN_Pos)
#define SPI_RX_RERR_EN_Pos  (8UL)
#define SPI_RX_RERR_EN_Msk  (1 << SPI_RX_RERR_EN_Pos)
#define SPI_RX_WERR_EN_Pos  (9UL)
#define SPI_RX_WERR_EN_Msk  (1 << SPI_RX_WERR_EN_Pos)
#define SPI_STOP_EN_Pos     (18UL)
#define SPI_STOP_EN_Msk     (1 << SPI_STOP_EN_Pos)

#define SPI_INTR_TX_THOLD_Msk (1UL)
#define SPI_INTR_TX_EMPTY_Pos (1UL)
#define SPI_INTR_TX_EMPTY_Msk (1 << SPI_INTR_TX_EMPTY_Pos)
#define SPI_INTR_TX_FULL_Pos  (2UL)
#define SPI_INTR_TX_FULL_Msk  (1 << SPI_INTR_TX_FULL_Pos)
#define SPI_INTR_TX_RERR_Pos  (3UL)
#define SPI_INTR_TX_RERR_Msk  (1 << SPI_INTR_TX_RERR_Pos)
#define SPI_INTR_TX_WERR_Pos  (4UL)
#define SPI_INTR_TX_WERR_Msk  (1 << SPI_INTR_TX_WERR_Pos)
#define SPI_INTR_RX_THOLD_Pos (5UL)
#define SPI_INTR_RX_THOLD_Msk (1 << SPI_INTR_RX_THOLD_Pos)
#define SPI_INTR_RX_EMPTY_Pos (6UL)
#define SPI_INTR_RX_EMPTY_Msk (1 << SPI_INTR_RX_EMPTY_Pos)
#define SPI_INTR_RX_FULL_Pos  (7UL)
#define SPI_INTR_RX_FULL_Msk  (1 << SPI_INTR_RX_FULL_Pos)
#define SPI_INTR_RX_RERR_Pos  (8UL)
#define SPI_INTR_RX_RERR_Msk  (1 << SPI_INTR_RX_RERR_Pos)
#define SPI_INTR_RX_WERR_Pos  (9UL)
#define SPI_INTR_RX_WERR_Msk  (1 << SPI_INTR_RX_WERR_Pos)
#define SPI_INTR_STOP_EN_Pos  (18UL)
#define SPI_INTR_STOP_EN_Msk  (1 << SPI_INTR_STOP_EN_Pos)

#define SPI_RAW_TX_THOLD_Msk (1UL)
#define SPI_RAW_TX_EMPTY_Pos (1UL)
#define SPI_RAW_TX_EMPTY_Msk (1 << SPI_RAW_TX_EMPTY_Pos)
#define SPI_RAW_TX_FULL_Pos  (2UL)
#define SPI_RAW_TX_FULL_Msk  (1 << SPI_RAW_TX_FULL_Pos)
#define SPI_RAW_TX_RERR_Pos  (3UL)
#define SPI_RAW_TX_RERR_Msk  (1 << SPI_RAW_TX_RERR_Pos)
#define SPI_RAW_TX_WERR_Pos  (4UL)
#define SPI_RAW_TX_WERR_Msk  (1 << SPI_RAW_TX_WERR_Pos)
#define SPI_RAW_RX_THOLD_Pos (5UL)
#define SPI_RAW_RX_THOLD_Msk (1 << SPI_RAW_RX_THOLD_Pos)
#define SPI_RAW_RX_EMPTY_Pos (6UL)
#define SPI_RAW_RX_EMPTY_Msk (1 << SPI_RAW_RX_EMPTY_Pos)
#define SPI_RAW_RX_FULL_Pos  (7UL)
#define SPI_RAW_RX_FULL_Msk  (1 << SPI_RAW_RX_FULL_Pos)
#define SPI_RAW_RX_RERR_Pos  (8UL)
#define SPI_RAW_RX_RERR_Msk  (1 << SPI_RAW_RX_RERR_Pos)
#define SPI_RAW_RX_WERR_Pos  (9UL)
#define SPI_RAW_RX_WERR_Msk  (1 << SPI_RAW_RX_WERR_Pos)
#define SPI_RAW_STOP_EN_Pos  (18UL)
#define SPI_RAW_STOP_EN_Msk  (1 << SPI_RAW_STOP_EN_Pos)

#define SPI_INTRUNMSK_TX_THOLD_MASK_Msk (1UL)
#define SPI_INTRUNMSK_TX_EMPTY_MASK_Pos (1UL)
#define SPI_INTRUNMSK_TX_EMPTY_MASK_Msk (1 << SPI_INTRUNMSK_TX_EMPTY_MASK_Pos)
#define SPI_INTRUNMSK_TX_FULL_MASK_Pos  (2UL)
#define SPI_INTRUNMSK_TX_FULL_MASK_Msk  (1 << SPI_INTRUNMSK_TX_FULL_MASK_Pos)
#define SPI_INTRUNMSK_TX_RERR_MASK_Pos  (3UL)
#define SPI_INTRUNMSK_TX_RERR_MASK_Msk  (1 << SPI_INTRUNMSK_TX_RERR_MASK_Pos)
#define SPI_INTRUNMSK_TX_WERR_MASK_Pos  (4UL)
#define SPI_INTRUNMSK_TX_WERR_MASK_Msk  (1 << SPI_INTRUNMSK_TX_WERR_MASK_Pos)
#define SPI_INTRUNMSK_RX_THOLD_MASK_Pos (5UL)
#define SPI_INTRUNMSK_RX_THOLD_MASK_Msk (1 << SPI_INTRUNMSK_RX_THOLD_MASK_Pos)
#define SPI_INTRUNMSK_RX_EMPTY_MASK_Pos (6UL)
#define SPI_INTRUNMSK_RX_EMPTY_MASK_Msk (1 << SPI_INTRUNMSK_RX_EMPTY_MASK_Pos)
#define SPI_INTRUNMSK_RX_FULL_MASK_Pos  (7UL)
#define SPI_INTRUNMSK_RX_FULL_MASK_Msk  (1 << SPI_INTRUNMSK_RX_FULL_MASK_Pos)
#define SPI_INTRUNMSK_RX_RERR_MASK_Pos  (8UL)
#define SPI_INTRUNMSK_RX_RERR_MASK_Msk  (1 << SPI_INTRUNMSK_RX_RERR_MASK_Pos)
#define SPI_INTRUNMSK_RX_WERR_MASK_Pos  (9UL)
#define SPI_INTRUNMSK_RX_WERR_MASK_Msk  (1 << SPI_INTRUNMSK_RX_WERR_MASK_Pos)
#define SPI_INTRUNMSK_SPI_STOP_EN_Pos   (18UL)
#define SPI_INTRUNMSK_SPI_STOP_EN_Msk   (1 << 18UL)

#define SPI_INTRCLR_TX_THOLD_CLR_Msk (1UL)
#define SPI_INTRCLR_TX_EMPTY_CLR_Pos (1UL)
#define SPI_INTRCLR_TX_EMPTY_CLR_Msk (1 << SPI_INTRCLR_TX_EMPTY_CLR_Pos)
#define SPI_INTRCLR_TX_FULL_CLR_Pos  (2UL)
#define SPI_INTRCLR_TX_FULL_CLR_Msk  (1 << SPI_INTRCLR_TX_FULL_CLR_Pos)
#define SPI_INTRCLR_TX_RERR_CLR_Pos  (3UL)
#define SPI_INTRCLR_TX_RERR_CLR_Msk  (1 << SPI_INTRCLR_TX_RERR_CLR_Pos)
#define SPI_INTRCLR_TX_WERR_CLR_Pos  (4UL)
#define SPI_INTRCLR_TX_WERR_CLR_Msk  (1 << SPI_INTRCLR_TX_WERR_CLR_Pos)
#define SPI_INTRCLR_RX_THOLD_CLR_Pos (5UL)
#define SPI_INTRCLR_RX_THOLD_CLR_Msk (1 << SPI_INTRCLR_RX_THOLD_CLR_Pos)
#define SPI_INTRCLR_RX_EMPTY_CLR_Pos (6UL)
#define SPI_INTRCLR_RX_EMPTY_CLR_Msk (1 << SPI_INTRCLR_RX_EMPTY_CLR_Pos)
#define SPI_INTRCLR_RX_FULL_CLR_Pos  (7UL)
#define SPI_INTRCLR_RX_FULL_CLR_Msk  (1 << SPI_INTRCLR_RX_FULL_CLR_Pos)
#define SPI_INTRCLR_RX_RERR_CLR_Pos  (8UL)
#define SPI_INTRCLR_RX_RERR_CLR_Msk  (1 << SPI_INTRCLR_RX_RERR_CLR_Pos)
#define SPI_INTRCLR_RX_WERR_CLR_Pos  (9UL)
#define SPI_INTRCLR_RX_WERR_CLR_Msk  (1 << SPI_INTRCLR_RX_WERR_CLR_Pos)
#define SPI_INTRCLR_STOP_EN_Pos      (18UL)
#define SPI_INTRCLR_STOP_EN_Msk      (1 << 18UL)

/*I2C Bit Mask*/
#define I2C_EN_Msk         (1UL)
#define I2C_TX_FIFO_EN_Pos (2UL)
#define I2C_TX_FIFO_EN_Msk (1 << I2C_TX_FIFO_EN_Pos)
#define I2C_RX_FIFO_EN_Pos (3UL)
#define I2C_RX_FIFO_EN_Msk (1 << I2C_RX_FIFO_EN_Pos)

#define I2C_DATA_Msk_0   (0xFFUL)
#define I2C_RnW_CTRL_Pos (8UL)
#define I2C_RnW_CTRL_Msk (1 << I2C_RnW_CTRL_Pos)
#define I2C_RESTART_Pos  (9UL)
#define I2C_RESTART_Msk  (1 << I2C_RESTART_Pos)

#define I2C_FIFOSTA_TX_EMPTY_Msk (1UL)
#define I2C_FIFOSTA_TX_FULL_Pos  (1UL)
#define I2C_FIFOSTA_TX_FULL_Msk  (1 << I2C_FIFOSTA_TX_FULL_Pos)
#define I2C_FIFOSTA_RX_EMPTY_Pos (2UL)
#define I2C_FIFOSTA_RX_EMPTY_Msk (1 << I2C_FIFOSTA_RX_EMPTY_Pos)
#define I2C_FIFOSTA_RX_FULL_Pos  (3UL)
#define I2C_FIFOSTA_RX_FULL_Msk  (1 << I2C_FIFOSTA_RX_FULL_Pos)
#define I2C_FIFOSTA_TX_NUM_Pos   (8UL)
#define I2C_FIFOSTA_TX_NUM_Msk   (0xF << I2C_FIFOSTA_TX_NUM_Pos)
#define I2C_FIFOSTA_RX_NUM_Pos   (16UL)
#define I2C_FIFOSTA_RX_NUM_Msk   (0xF << I2C_FIFOSTA_RX_NUM_Pos)

#define I2C_CLK_DIV0_Msk    (0xFFFFFFUL)
#define I2C_CLK_DIV1_Msk    (0xFFFFFFUL)
#define I2C_MS_MODE_Msk     (1UL)
#define I2C_ADDR_Msk        (0x3FFUL)
#define I2C_ADDR_FUTURE_Msk (0xF0UL)
#define I2C_ADDR_MODE_Msk   (1UL)
#define I2C_STOP_Pos        (1UL)
#define I2C_STOP_Msk        (1 << I2C_STOP_Pos)
#define I2C_HS_MODE_Pos     (2UL)
#define I2C_HS_MODE_Msk     (1 << I2C_HS_MODE_Pos)
#define I2C_SBYTE_Pos       (3UL)
#define I2C_SBYTE_Msk       (1 << I2C_SBYTE_Pos)
#define I2C_GCALL_Pos       (4UL)
#define I2C_GCALL_Msk       (1 << I2C_GCALL_Pos)
#define I2C_MCODE_Msk_0     (1UL)
#define I2C_MCODE_Msk_1     (1 << 1UL)
#define I2C_MCODE_Msk_2     (1 << 2UL)
#define I2C_GCALL_MODE_Msk  (1UL)
#define I2C_FM_DIV_Msk      (0xFFUL)
#define I2C_HOLD_Msk        (0xFFUL)

#define I2C_I2CM_WORK_Msk (1UL)
#define I2C_I2CS_DATA_Pos (1UL)
#define I2C_I2CS_DATA_Msk (1 << I2C_I2CS_DATA_Pos)
#define I2C_I2CS_WORK_Pos (8UL)
#define I2C_I2CS_WORK_Msk (1 << I2C_I2CS_WORK_Pos)

#define I2C_TX_FIFO_TH_Msk (3UL)
#define I2C_RX_FIFO_TH_Pos (8UL)
#define I2C_RX_FIFO_TH_Msk (3 << I2C_RX_FIFO_TH_Pos)
#define I2C_TH_MODE_Pos    (16UL)
#define I2C_TH_MODE_Msk    (1 << 16UL)

#define I2C_TX_THOLD_EN_Msk (1UL)
#define I2C_TX_EMPTY_EN_Pos (1UL)
#define I2C_TX_EMPTY_EN_Msk (1 << I2C_TX_EMPTY_EN_Pos)
#define I2C_TX_FULL_EN_Pos  (2UL)
#define I2C_TX_FULL_EN_Msk  (1 << I2C_TX_FULL_EN_Pos)
#define I2C_TX_RERR_EN_Pos  (3UL)
#define I2C_TX_RERR_EN_Msk  (1 << I2C_TX_RERR_EN_Pos)
#define I2C_TX_WERR_EN_Pos  (4UL)
#define I2C_TX_WERR_EN_Msk  (1 << I2C_TX_WERR_EN_Pos)
#define I2C_RX_THOLD_EN_Pos (5UL)
#define I2C_RX_THOLD_EN_Msk (1 << I2C_RX_THOLD_EN_Pos)
#define I2C_RX_EMPTY_EN_Pos (6UL)
#define I2C_RX_EMPTY_EN_Msk (1 << I2C_RX_EMPTY_EN_Pos)
#define I2C_RX_FULL_EN_Pos  (7UL)
#define I2C_RX_FULL_EN_Msk  (1 << I2C_RX_FULL_EN_Pos)
#define I2C_RX_RERR_EN_Pos  (8UL)
#define I2C_RX_RERR_EN_Msk  (1 << I2C_RX_RERR_EN_Pos)
#define I2C_RX_WERR_EN_Pos  (9UL)
#define I2C_RX_WERR_EN_Msk  (1 << I2C_RX_WERR_EN_Pos)

#define I2C_INTREN_STOP_EN_Pos       (12UL)
#define I2C_INTREN_STOP_EN_Msk       (1 << I2C_INTREN_STOP_EN_Pos)
#define I2C_INTREN_NACK_EN_Pos       (13UL)
#define I2C_INTREN_NACK_EN_Msk       (1 << I2C_INTREN_NACK_EN_Pos)
#define I2C_INTREN_LOSE_ARBI_EN_Pos  (14UL)
#define I2C_INTREN_LOSE_ARBI_EN_Msk  (1 << I2C_INTREN_LOSE_ARBI_EN_Pos)
#define I2C_INTREN_I2CS_GCALL_EN_Pos (15UL)
#define I2C_INTREN_I2CS_GCALL_EN_Msk (1 << I2C_INTREN_I2CS_GCALL_EN_Pos)
#define I2C_INTREN_AERR_EN_Pos       (16UL)
#define I2C_INTREN_AERR_EN_Msk       (1 << I2C_INTREN_AERR_EN_Pos)

#define I2C_INTR_TX_THOLD_Msk       (1UL)
#define I2C_INTR_TX_EMPTY_Pos       (1UL)
#define I2C_INTR_TX_EMPTY_Msk       (1 << I2C_INTR_TX_EMPTY_Pos)
#define I2C_INTR_TX_FULL_Pos        (2UL)
#define I2C_INTR_TX_FULL_Msk        (1 << I2C_INTR_TX_FULL_Pos)
#define I2C_INTR_TX_RERR_Pos        (3UL)
#define I2C_INTR_TX_RERR_Msk        (1 << I2C_INTR_TX_RERR_Pos)
#define I2C_INTR_TX_WERR_Pos        (4UL)
#define I2C_INTR_TX_WERR_Msk        (1 << I2C_INTR_TX_WERR_Pos)
#define I2C_INTR_RX_THOLD_Pos       (5UL)
#define I2C_INTR_RX_THOLD_Msk       (1 << I2C_INTR_RX_THOLD_Pos)
#define I2C_INTR_RX_EMPTY_Pos       (6UL)
#define I2C_INTR_RX_EMPTY_Msk       (1 << I2C_INTR_RX_EMPTY_Pos)
#define I2C_INTR_RX_FULL_Pos        (7UL)
#define I2C_INTR_RX_FULL_Msk        (1 << I2C_INTR_RX_FULL_Pos)
#define I2C_INTR_RX_RERR_Pos        (8UL)
#define I2C_INTR_RX_RERR_Msk        (1 << I2C_INTR_RX_RERR_Pos)
#define I2C_INTR_RX_WERR_Pos        (9UL)
#define I2C_INTR_RX_WERR_Msk        (1 << I2C_INTR_RX_WERR_Pos)
#define I2C_INTR_I2C_STOP_Pos       (12UL)
#define I2C_INTR_I2C_STOP_Msk       (1 << I2C_INTR_I2C_STOP_Pos)
#define I2C_INTR_I2C_NACK_Pos       (13UL)
#define I2C_INTR_I2C_NACK_Msk       (1 << I2C_INTR_I2C_NACK_Pos)
#define I2C_INTR_I2CM_LOSE_ARBI_Pos (14UL)
#define I2C_INTR_I2CM_LOSE_ARBI_Msk (1 << I2C_INTR_I2CM_LOSE_ARBI_Pos)
#define I2C_INTR_I2CS_GCALL_Pos     (15UL)
#define I2C_INTR_I2CS_GCALL_Msk     (1 << I2C_INTR_I2CS_GCALL_Pos)
#define I2C_INTR_I2C_AERR_Pos       (16UL)
#define I2C_INTR_I2C_AERR_Msk       (1 << I2C_INTR_I2C_AERR_Pos)

#define I2C_RAW_TX_THOLD_Msk       (1UL)
#define I2C_RAW_TX_EMPTY_Pos       (1UL)
#define I2C_RAW_TX_EMPTY_Msk       (1 << I2C_RAW_TX_EMPTY_Pos)
#define I2C_RAW_TX_FULL_Pos        (2UL)
#define I2C_RAW_TX_FULL_Msk        (1 << I2C_RAW_TX_FULL_Pos)
#define I2C_RAW_TX_RERR_Pos        (3UL)
#define I2C_RAW_TX_RERR_Msk        (1 << I2C_RAW_TX_RERR_Pos)
#define I2C_RAW_TX_WERR_Pos        (4UL)
#define I2C_RAW_TX_WERR_Msk        (1 << I2C_RAW_TX_WERR_Pos)
#define I2C_RAW_RX_THOLD_Pos       (5UL)
#define I2C_RAW_RX_THOLD_Msk       (1 << I2C_RAW_RX_THOLD_Pos)
#define I2C_RAW_RX_EMPTY_Pos       (6UL)
#define I2C_RAW_RX_EMPTY_Msk       (1 << I2C_RAW_RX_EMPTY_Pos)
#define I2C_RAW_RX_FULL_Pos        (7UL)
#define I2C_RAW_RX_FULL_Msk        (1 << I2C_RAW_RX_FULL_Pos)
#define I2C_RAW_RX_RERR_Pos        (8UL)
#define I2C_RAW_RX_RERR_Msk        (1 << I2C_RAW_RX_RERR_Pos)
#define I2C_RAW_RX_WERR_Pos        (9UL)
#define I2C_RAW_RX_WERR_Msk        (1 << I2C_RAW_RX_WERR_Pos)
#define I2C_RAW_I2C_STOP_Pos       (12UL)
#define I2C_RAW_I2C_STOP_Msk       (1 << I2C_RAW_I2C_STOP_Pos)
#define I2C_RAW_I2C_NACK_Pos       (13UL)
#define I2C_RAW_I2C_NACK_Msk       (1 << I2C_RAW_I2C_NACK_Pos)
#define I2C_RAW_I2CM_LOSE_ARBI_Pos (14UL)
#define I2C_RAW_I2CM_LOSE_ARBI_Msk (1 << I2C_RAW_I2CM_LOSE_ARBI_Pos)
#define I2C_RAW_I2CS_GCALL_Pos     (15UL)
#define I2C_RAW_I2CS_GCALL_Msk     (1 << I2C_RAW_I2CS_GCALL_Pos)
#define I2C_RAW_I2C_AERR_Pos       (16UL)
#define I2C_RAW_I2C_AERR_Msk       (1 << I2C_RAW_I2C_AERR_Pos)

#define I2C_INTRUNMASK_TX_THOLD_MASK_Msk  (1UL)
#define I2C_INTRUNMASK_TX_EMPTY_MASK_Pos  (1UL)
#define I2C_INTRUNMASK_TX_EMPTY_MASK_Msk  (1 << I2C_INTRUNMASK_TX_EMPTY_MASK_Pos)
#define I2C_INTRUNMASK_TX_FULL_MASK_Pos   (2UL)
#define I2C_INTRUNMASK_TX_FULL_MASK_Msk   (1 << I2C_INTRUNMASK_TX_FULL_MASK_Pos)
#define I2C_INTRUNMASK_TX_RERR_MASK_Pos   (3UL)
#define I2C_INTRUNMASK_TX_RERR_MASK_Msk   (1 << I2C_INTRUNMASK_TX_RERR_MASK_Pos)
#define I2C_INTRUNMASK_TX_WERR_MASK_Pos   (4UL)
#define I2C_INTRUNMASK_TX_WERR_MASK_Msk   (1 << I2C_INTRUNMASK_TX_WERR_MASK_Pos)
#define I2C_INTRUNMASK_RX_THOLD_MASK_Pos  (5UL)
#define I2C_INTRUNMASK_RX_THOLD_MASK_Msk  (1 << I2C_INTRUNMASK_RX_THOLD_MASK_Pos)
#define I2C_INTRUNMASK_RX_EMPTY_MASK_Pos  (6UL)
#define I2C_INTRUNMASK_RX_EMPTY_MASK_Msk  (1 << I2C_INTRUNMASK_RX_EMPTY_MASK_Pos)
#define I2C_INTRUNMASK_RX_FULL_MASK_Pos   (7UL)
#define I2C_INTRUNMASK_RX_FULL_MASK_Msk   (1 << I2C_INTRUNMASK_RX_FULL_MASK_Pos)
#define I2C_INTRUNMASK_RX_RERR_MASK_Pos   (8UL)
#define I2C_INTRUNMASK_RX_RERR_MASK_Msk   (1 << I2C_INTRUNMASK_RX_RERR_MASK_Pos)
#define I2C_INTRUNMASK_RX_WERR_MASK_Pos   (9UL)
#define I2C_INTRUNMASK_RX_WERR_MASK_Msk   (1 << I2C_INTRUNMASK_RX_WERR_MASK_Pos)
#define I2C_INTRUNMASK_I2C_STOP_Pos       (12UL)
#define I2C_INTRUNMASK_I2C_STOP_Msk       (1 << I2C_INTRUNMASK_I2C_STOP_Pos)
#define I2C_INTRUNMASK_I2C_NACK_Pos       (13UL)
#define I2C_INTRUNMASK_I2C_NACK_Msk       (1 << I2C_INTRUNMASK_I2C_NACK_Pos)
#define I2C_INTRUNMASK_I2CM_LOSE_ARBI_Pos (14UL)
#define I2C_INTRUNMASK_I2CM_LOSE_ARBI_Msk (1 << I2C_INTRUNMASK_I2CM_LOSE_ARBI_Pos)
#define I2C_INTRUNMASK_I2CS_GCALL_Pos     (15UL)
#define I2C_INTRUNMASK_I2CS_GCALL_Msk     (1 << I2C_INTRUNMASK_I2CS_GCALL_Pos)
#define I2C_INTRUNMASK_I2C_AERR_Pos       (16UL)
#define I2C_INTRUNMASK_I2C_AERR_Msk       (1 << I2C_INTRUNMASK_I2C_AERR_Pos)

#define I2C_INTCLR_TX_THOLD_CLR_Msk   (1UL)
#define I2C_INTCLR_TX_EMPTY_CLR_Pos   (1UL)
#define I2C_INTCLR_TX_EMPTY_CLR_Msk   (1 << I2C_INTCLR_TX_EMPTY_CLR_Pos)
#define I2C_INTCLR_TX_FULL_CLR_Pos    (2UL)
#define I2C_INTCLR_TX_FULL_CLR_Msk    (1 << I2C_INTCLR_TX_FULL_CLR_Pos)
#define I2C_INTCLR_TX_RERR_CLR_Pos    (3UL)
#define I2C_INTCLR_TX_RERR_CLR_Msk    (1 << I2C_INTCLR_TX_RERR_CLR_Pos)
#define I2C_INTCLR_TX_WERR_CLR_Pos    (4UL)
#define I2C_INTCLR_TX_WERR_CLR_Msk    (1 << I2C_INTCLR_TX_WERR_CLR_Pos)
#define I2C_INTCLR_RX_THOLD_CLR_Pos   (5UL)
#define I2C_INTCLR_RX_THOLD_CLR_Msk   (1 << I2C_INTCLR_RX_THOLD_CLR_Pos)
#define I2C_INTCLR_RX_EMPTY_CLR_Pos   (6UL)
#define I2C_INTCLR_RX_EMPTY_CLR_Msk   (1 << I2C_INTCLR_RX_EMPTY_CLR_Pos)
#define I2C_INTCLR_RX_FULL_CLR_Pos    (7UL)
#define I2C_INTCLR_RX_FULL_CLR_Msk    (1 << I2C_INTCLR_RX_FULL_CLR_Pos)
#define I2C_INTCLR_RX_RERR_CLR_Pos    (8UL)
#define I2C_INTCLR_RX_RERR_CLR_Msk    (1 << I2C_INTCLR_RX_RERR_CLR_Pos)
#define I2C_INTCLR_RX_WERR_CLR_Pos    (9UL)
#define I2C_INTCLR_RX_WERR_CLR_Msk    (1 << I2C_INTCLR_RX_WERR_CLR_Pos)
#define I2C_INTCLR_I2C_STOP_Pos       (12UL)
#define I2C_INTCLR_I2C_STOP_Msk       (1 << I2C_INTCLR_I2C_STOP_Pos)
#define I2C_INTCLR_I2C_NACK_Pos       (13UL)
#define I2C_INTCLR_I2C_NACK_Msk       (1 << I2C_INTCLR_I2C_NACK_Pos)
#define I2C_INTCLR_I2CM_LOSE_ARBI_Pos (14UL)
#define I2C_INTCLR_I2CM_LOSE_ARBI_Msk (1 << I2C_INTCLR_I2CM_LOSE_ARBI_Pos)
#define I2C_INTCLR_I2CS_GCALL_Pos     (15UL)
#define I2C_INTCLR_I2CS_GCALL_Msk     (1 << I2C_INTCLR_I2CS_GCALL_Pos)
#define I2C_INTCLR_I2C_AERR_Pos       (16UL)
#define I2C_INTCLR_I2C_AERR_Msk       (1 << I2C_INTCLR_I2C_AERR_Pos)

/*UART Bit Mask*/
#define UART_BUF_Msk               (0xFFUL)
#define UART_TX_BUF_FULL_Msk       (1UL)
#define UART_RX_BUF_FULL_Pos       (1UL)
#define UART_RX_BUF_FULL_Msk       (1 << UART_RX_BUF_FULL_Pos)
#define UART_TX_BUF_OVERRUN_Pos    (2UL)
#define UART_TX_BUF_OVERRUN_Msk    (1 << UART_TX_BUF_OVERRUN_Pos)
#define UART_RX_BUF_OVERRUN_Pos    (3UL)
#define UART_RX_BUF_OVERRUN_Msk    (1 << UART_RX_BUF_OVERRUN_Pos)
#define UART_TX_EN_Msk             (1UL)
#define UART_RX_EN_Pos             (1UL)
#define UART_RX_EN_Msk             (1 << UART_RX_EN_Pos)
#define UART_TX_INT_EN_Pos         (2UL)
#define UART_TX_INT_EN_Msk         (1 << UART_TX_INT_EN_Pos)
#define UART_RX_INT_EN_Pos         (3UL)
#define UART_RX_INT_EN_Msk         (1 << UART_RX_INT_EN_Pos)
#define UART_TX_OVERRUN_INT_EN_Pos (4UL)
#define UART_TX_OVERRUN_INT_EN_Msk (1 << UART_TX_OVERRUN_INT_EN_Pos)
#define UART_RX_OVERRUN_INT_EN_Pos (5UL)
#define UART_RX_OVERRUN_INT_EN_Msk (1 << UART_RX_OVERRUN_INT_EN_Pos)
#define UART_TX_INT_Msk            (1UL)
#define UART_RX_INT_Pos            (1UL)
#define UART_RX_INT_Msk            (1 << UART_RX_INT_Pos)
#define UART_TX_OVERRUN_INT_Pos    (2UL)
#define UART_TX_OVERRUN_INT_Msk    (1 << UART_TX_OVERRUN_INT_Pos)
#define UART_RX_OVERRUN_INT_Pos    (3UL)
#define UART_RX_OVERRUN_INT_Msk    (1 << UART_RX_OVERRUN_INT_Pos)
/*WDT Bit Mask*/
#define WDT_EN_Msk      (1UL)
#define WDT_INT_EN_Pos  (1UL)
#define WDT_INT_EN_Msk  (1 << WDT_INT_EN_Pos)
#define WDT_RST_EN_Pos  (2UL)
#define WDT_RST_EN_Msk  (1 << WDT_RST_EN_Pos)
#define WDT_CLR_Msk     (1UL)
#define WDT_INT_RAW_Msk (1UL)
#define WDT_FEED_Msk    (1UL)
#define WDT_LOCK_Msk    (1UL)
/*CRC Bit Mask*/
#define CRC_INIT_Msk  (1UL)
#define CRC_DIN_Msk   (0xFFUL)
#define CRC_RES_Msk_0 (0xFFFFUL)
/*RTC Bit Mask*/
#define RTC_PRESCALE_Msk_0     (0xFFFFUL)
#define RTC_CLK_SEL_Msk        (1UL)
#define RTC_OUT_1Hz_Pos        (1UL)
#define RTC_OUT_1Hz_Msk        (1 << RTC_OUT_1Hz_Pos)
#define RTC_EN_Pos             (2UL)
#define RTC_EN_Msk             (1 << RTC_EN_Pos)
#define RTC_INTEN_Msk          (1UL)
#define RTC_MASK_Msk           (1UL)
#define RTC_RAW_Msk            (1UL)
#define RTC_CLR_Msk            (1UL)
#define RTC_ADJUST_Msk         (0x7FUL)
#define RTC_ADJUST_NEG_POS_Pos (7UL)
#define RTC_ADJUST_NEG_POS_Msk (1 << RTC_ADJUST_NEG_POS_Pos)
#define RTC_ADJUST_EN_Pos      (8UL)
#define RTC_ADJUST_EN_Msk      (1 << RTC_ADJUST_EN_Pos)

#define RTC_SECOND_ONE_Msk (0xFUL)
#define RTC_SECOND_TEN_Pos (4UL)
#define RTC_SECOND_TEN_Msk (7 << RTC_SECOND_TEN_Pos)
#define RTC_MINUTE_ONE_Msk (0xFUL)
#define RTC_MINUTE_TEN_Pos (4UL)
#define RTC_MINUTE_TEN_Msk (7 << RTC_MINUTE_TEN_Pos)
#define RTC_HOUR_ONE_Msk   (0xFUL)
#define RTC_HOUR_TEN_Pos   (4UL)
#define RTC_HOUR_TEN_Msk   (3 << RTC_HOUR_TEN_Pos)
#define RTC_DAY_ONE_Msk    (0xFUL)
#define RTC_DAY_TEN_Pos    (4UL)
#define RTC_DAY_TEN_Msk    (3 << RTC_DAY_TEN_Pos)
#define RTC_MONTH_ONE_Msk  (0xFUL)
#define RTC_MONTH_TEN_Pos  (4UL)
#define RTC_MONTH_TEN_Msk  (1 << RTC_MONTH_TEN_Pos)
#define RTC_YEAR_ONE_Msk   (0xFUL)
#define RTC_YEAR_TEN_Pos   (4UL)
#define RTC_YEAR_TEN_Msk   (0xF << RTC_YEAR_TEN_Pos)

#define RTC_SECOND_ONE_ALM_Msk (0xFUL)
#define RTC_SECOND_TEN_Pos     (4UL)
#define RTC_SECOND_TEN_ALM_Msk (7 << RTC_SECOND_TEN_Pos)
#define RTC_SECOND_ALM_Pos     (7U)
#define RTC_SECOND_ALM_Msk     (1UL << RTC_SECOND_ALM_Pos)
#define RTC_MINUTE_ONE_ALM_Msk (0xFUL)
#define RTC_MINUTE_TEN_Pos     (4UL)
#define RTC_MINUTE_TEN_ALM_Msk (7 << RTC_MINUTE_TEN_Pos)
#define RTC_MINUTE_ALM_Pos     (7UL)
#define RTC_MINUTE_ALM_Msk     (1UL << RTC_MINUTE_ALM_Pos)
#define RTC_HOUR_ONE_ALM_Msk   (0xFUL)
#define RTC_HOUR_TEN_Pos       (4UL)
#define RTC_HOUR_TEN_ALM_Msk   (3 << RTC_HOUR_TEN_Pos)
#define RTC_HOUR_ALM_Pos       (6UL)
#define RTC_HOUR_ALM_Msk       (1UL << RTC_HOUR_ALM_Pos)
#define RTC_DAY_ONE_ALM_Msk    (0xFUL)
#define RTC_DAY_TEN_Pos        (4UL)
#define RTC_DAY_TEN_ALM_Msk    (3 << RTC_DAY_TEN_Pos)
#define RTC_DAY_ALM_Pos        (6UL)
#define RTC_DAY_ALM_Msk        (1 << RTC_DAY_ALM_Pos)
/*EFC Bit Mask*/
#define EFC_PROG_EN_Msk    (1UL)
#define EFC_ERASE_EN_Msk   (~1UL)
#define EFC_FLS_BUSY_Pos   (2UL)
#define EFC_FLS_BUSY_Msk   (1 << EFC_FLS_BUSY_Pos)
#define EFC_RD_CYCLE_Msk   (3UL)
#define EFC_TPGS_CNT_Msk   (0xFFUL)
#define EFC_TPROG_CNT_Msk  (0xFFUL)
#define EFC_TERASE_CNT_Msk (0x3FFFFUL)
/*CMP and TEMP Bit Mask*/
#define TEMP_PWR_D_Msk     (1UL)
#define TEMP_LOWER_N40_Msk (1UL)
#define TEMP_UPPER_P95_Pos (1UL)
#define TEMP_UPPER_P95_Msk (1 << TEMP_UPPER_P95_Pos)
/*BOOT Bit Mask*/
#define BIST_EN_Msk        (1UL)
#define MCO_SEL_Pos        (1U)
#define MCO_SEL_Msk        (1UL << MCO_SEL_Pos)
#define MCO_DIV_Pos        (2U)
#define MCO_DIV_Msk        (3UL << MCO_DIV_Pos)
#define ANA0_TEST_Pos      (4U)
#define ANA0_TEST_Msk      (7UL << ANA0_TEST_Pos)
#define ANA1_TEST_Pos      (7U)
#define ANA1_TEST_Msk      (7UL << ANA1_TEST_Pos)
#define LPBG_TRIM_Msk      7UL
#define LPLDO_TRIM_Pos     (3U)
#define LPLDO_TRIM_Msk     (7UL << LPLDO_TRIM_Pos)
#define OSC32_TRIM_Pos     (6U)
#define OSC32_TRIM_Msk     (0x1FUL << OSC32_TRIM_Pos)
#define BG_TRIM_Pos        (11U)
#define BG_TRIM_Msk        (0xFUL << BG_TRIM_Pos)
#define LDO_TRIM_Pos       (15U)
#define LDO_TRIM_Msk       (0xFUL << LDO_TRIM_Pos)
#define OSC4M_CAPTRIM_Msk  (0xFUL)
#define OSC8M_CAPTRIM_Pos  (4U)
#define OSC8M_CAPTRIM_Msk  (0xFUL << OSC8M_CAPTRIM_Pos)
#define OSC16M_CAPTRIM_Pos (8U)
#define OSC16M_CAPTRIM_Msk (0xFUL << OSC16M_CAPTRIM_Pos)
#define OSC24M_CAPTRIM_Pos (12U)
#define OSC24M_CAPTRIM_Msk (0xFUL << OSC24M_CAPTRIM_Pos)
#define OSC4M_TRIM_Msk     (0x3FUL)
#define OSC8M_TRIM_Pos     (6U)
#define OSC8M_TRIM_Msk     (0x3FUL << OSC8M_TRIM_Pos)
#define OSC16M_TRIM_Pos    (12U)
#define OSC16M_TRIM_Msk    (0x3FUL << OSC16M_TRIM_Pos)
#define OSC24M_TRIM_Pos    (18U)
#define OSC24M_TRIM_Msk    (0x3FUL << OSC24M_TRIM_Pos)
#define V1P2_TRIM_Msk      (0xFUL)
#define V2P0_TRIM_Pos      (4U)
#define V2P0_TRIM_Msk      (0x1FUL << V2P0_TRIM_Pos)
#define V2P5_TRIM_Pos      (9U)
#define V2P5_TRIM_Msk      (0x1FUL << V2P5_TRIM_Pos)
#define BOR_EN_Pos         (14U)
#define BOR_EN_Msk         (0x1UL << BOR_EN_Pos)
#define BOR_LEVEL_Pos      (15U)
#define BOR_LEVEL_Msk      (7UL << BOR_LEVEL_Pos)
/*TRNG bit mask*/
#define TRNG_EN_Msk     (1UL)
#define TRNG_ROS0EN_Pos (4UL)
#define TRNG_ROS0EN_Msk (1UL << TRNG_ROSEN_Pos)
#define TRNG_ROS1EN_Pos (5UL)
#define TRNG_ROS1EN_Msk (1UL << TRNG_ROSEN_Pos)
#define TRNG_ROS2EN_Pos (6UL)
#define TRNG_ROS2EN_Msk (1UL << TRNG_ROSEN_Pos)
#define TRNG_ROS3EN_Pos (7UL)
#define TRNG_ROS3EN_Msk (1UL << TRNG_ROSEN_Pos)
#define TRNG_IRQEN_Pos  (24UL)
#define TRNG_IRQEN_Msk  (1UL << TRNG_IRQEN_Pos)
/*SKE bit mask*/
#define SKE_IRQ_Msk   (1u << 16)
#define SKE_ALARM_Msk (1u)

/** @addtogroup Exported_macro
 * @{
 */
#define SET_BIT(REG, BIT) ((REG) |= (BIT))

#define CLEAR_BIT(REG, BIT) ((REG) &= ~(BIT))

#define READ_BIT(REG, BIT) ((REG) & (BIT))

#define CLEAR_REG(REG) ((REG) = (0x0))

#define WRITE_REG(REG, VAL) ((REG) = (VAL))

#define READ_REG(REG) ((REG))

#define MODIFY_REG(REG, CLEARMASK, SETMASK) WRITE_REG((REG), (((READ_REG(REG)) & (~(CLEARMASK))) | (SETMASK)))

#define WRITE_BIT(reg, bitmask, flag)                                                                                  \
    {                                                                                                                  \
        if ((flag) == 0)                                                                                               \
            (reg) &= (~(bitmask));                                                                                     \
        else                                                                                                           \
            (reg) |= (bitmask);                                                                                        \
    }

/**
 * @}
 */

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* !__CJ32L01XX_H */

/**
 * @}
 */

/**
 * @}
 */

/************************ (C) COPYRIGHT *****END OF FILE****/
