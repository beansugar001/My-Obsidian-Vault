/**
 * @Description:CJW110芯片的GPIO库函数头文件
 *
 *
 ********************************************
 * 版本      日期      作者         变更内容
 * V1.0    2022-5-9    AE          首次发布
 *
 */
#ifndef __CJ32L01XX_GPIO_H
#define __CJ32L01XX_GPIO_H

#include "cj32l01xx.h"

#define GPIOA M0_GPIOA
#define GPIOB M0_GPIOB
#define GPIOC M0_GPIOC
#define GPIOD M0_GPIOD
#define IS_GPIO_PERIPH(PERIPH)                                                                                         \
    ((PERIPH == M0_GPIOA) || (PERIPH == M0_GPIOB) || (PERIPH == M0_GPIOC) || (PERIPH == M0_GPIOD))

#define GPIO_GROUPNUM 6
#define GPIO_Pin_0    0x01U
#define GPIO_Pin_1    0x02U
#define GPIO_Pin_2    0x04U
#define GPIO_Pin_3    0x08U
#define GPIO_Pin_4    0x10U
#define GPIO_Pin_5    0x20U
#define GPIO_Pin_All  0x3FU

#define IS_GPIO_PINs(PIN) ((PIN != 0) && (PIN <= GPIO_Pin_All))

#define IS_GPIO_PIN(PIN)                                                                                               \
    ((PIN == GPIO_Pin_0) || (PIN == GPIO_Pin_1) || (PIN == GPIO_Pin_2) || (PIN == GPIO_Pin_3) ||                       \
     (PIN == GPIO_Pin_4) || (PIN == GPIO_Pin_5))

#define GPIO_Mode_PU_Msk      (1UL << 4)
#define GPIO_Mode_PD_Msk      (1UL << 3)
#define GPIO_Mode_PUPD_Msk    (3UL << 3)
#define GPIO_Mode_OS_Msk      (1UL << 2)
#define GPIO_Mode_OD_Msk      (1UL << 1)
#define GPIO_Mode_OSOD_Msk    (3UL << 1)
#define GPIO_Mode_IO_Msk      (1U)
#define GPIO_Int_Polarity_Msk (1U)
#define GPIO_Int_Type_Msk     (2U)


typedef enum
{
    GPIO_Dir_IN,
    GPIO_Dir_OUT,
} GPIO_dir_t;

typedef enum
{
    GPIO_In_Floating,
    GPIO_In_PD,
    GPIO_In_PU,
} GPIO_pupd_t;

typedef enum
{
    GPIO_Dis_OSOD,
    GPIO_OD,
    GPIO_OS,
} GPIO_osod_t;

typedef enum
{
    GPIO_Dr_Low,
    GPIO_Dr_High,
} GPIO_dr_t;

typedef enum
{
    GPIO_Sr_Fast,
    GPIO_Sr_Slow,
} GPIO_sr_t;

typedef enum
{
    GPIO_Int_Level,
    GPIO_Int_Edge,
} GPIO_Int_LevelorEdge_t;

typedef enum
{
    GPIO_Int_Polarity_Low,
    GPIO_Int_Polarity_High,
} GPIO_Int_Polarity_t;

typedef enum
{
    GPIO_Int_Low,
    GPIO_Int_High,
    GPIO_Int_Falling,
    GPIO_Int_Rising,
} GPIO_Int_type_t;

typedef enum
{
    GPIO_Digital,
    GPIO_Analog,
} GPIO_AD_t;

typedef enum
{
    GPIO_Int_ASYNC,
    GPIO_Int_SYNC,
} GPIO_Int_sync_t;

typedef enum
{
    GPIO_Mode_Out_PP      = 0x1U,
    GPIO_Mode_Out_OD      = 0x3U,
    GPIO_Mode_Out_OS      = 0x5U,
    GPIO_Mode_IPU         = 0x10U,
    GPIO_Mode_IPD         = 0x8U,
    GPIO_Mode_IN_FLOATING = 0U,
} GPIO_Mode_t;    // bit 4 3,2 1,0 (PU PD , OS OD , Output)

typedef struct
{
    u8 GPIO_Pin;
    GPIO_Mode_t GPIO_Mode;
    GPIO_dr_t GPIO_Drive;
    GPIO_sr_t GPIO_Speed;
} GPIO_InitTypedef;

/*  */
void GPIO_Routine(void);

/*  */
void GPIO_Init_b(M0_GPIO_TypeDef* const GPIOx, u8 Pin, GPIO_dir_t dir);
void GPIO_DeInit(M0_GPIO_TypeDef* const GPIOx, u8 Pin);
void GPIO_Init(M0_GPIO_TypeDef* const GPIOx, const GPIO_InitTypedef* const GPIO_InitStruct);
void GPIO_WriteBits(M0_GPIO_TypeDef* const GPIOx, u8 Pin, u8 level);
void GPIO_SetBits(M0_GPIO_TypeDef* const GPIOx, u8 Pin);
void GPIO_ResetBits(M0_GPIO_TypeDef* GPIOx, u8 Pin);
void GPIO_ToggleBits(M0_GPIO_TypeDef* GPIOx, u8 Pin);
u8 GPIO_ReadBit(M0_GPIO_TypeDef* GPIOx, u8 Pin);
void GPIO_IntInit(M0_GPIO_TypeDef* const GPIOx, u8 Pin, GPIO_Int_type_t INT_type, u8 pri, FunctionalState sw);
u8 GPIO_GetIntStat(M0_GPIO_TypeDef* const GPIOx, u8 Pin);
u8 GPIO_GetRawIntStat(M0_GPIO_TypeDef* const GPIOx, u8 Pin);
void GPIO_AlternateFunction(M0_GPIO_TypeDef* const GPIOx, u8 Pin, u8 Func, GPIO_AD_t ADtype);
void GPIO_IntMask(M0_GPIO_TypeDef* const GPIOx, u8 Pin);
void GPIO_IntUnMask(M0_GPIO_TypeDef* const GPIOx, u8 Pin);
void GPIO_IntClr(M0_GPIO_TypeDef* const GPIOx, u8 Pin);
void GPIO_IntSync(M0_GPIO_TypeDef* const GPIOx, GPIO_Int_sync_t sync_mode);

#endif
