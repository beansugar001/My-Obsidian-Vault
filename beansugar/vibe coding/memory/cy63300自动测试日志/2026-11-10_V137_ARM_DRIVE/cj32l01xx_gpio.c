/**
 * @Description:CJW110芯片的GPIO库函数
 *
 *
 ********************************************
 * 版本      日期      作者         变更内容
 * V1.0    2022-5-9    AE          首次发布
 *
 */
#include "cj32l01xx_gpio.h"

/**
 * @brief GPIO例程
 * @param none
 * @return none
 */
void GPIO_Routine(void)
{
    GPIO_InitTypedef GPIO_InitStructure;

    PeriCLK_Cmd(GPIO_PCLK, ENABLE); /* 开GPIO时钟 */
    GPIO_InitStructure.GPIO_Pin   = GPIO_Pin_0;
    GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_Out_PP;
    GPIO_InitStructure.GPIO_Drive = GPIO_Dr_High;
    GPIO_InitStructure.GPIO_Speed = GPIO_Sr_Slow;
    GPIO_Init(GPIOA, &GPIO_InitStructure);
    GPIOA->ODR = 1;

    GPIO_InitStructure.GPIO_Pin  = GPIO_Pin_1;
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IPU;
    GPIO_Init(GPIOA, &GPIO_InitStructure);
    GPIO_IntInit(GPIOA, GPIO_Pin_1, GPIO_Int_Low, 3, ENABLE); /* 中断配置 */
    GPIOA->CS |= GPIO_Pin_1;
}

/**
 * @brief 外部中断1函数
 * @param none
 * @return none
 */
#ifndef _TEST_ALL_FUNCTIONS
//void EXTI1_IRQHandler(void)
//{
////    if (GPIO_GetIntStat(GPIOA, GPIO_Pin_1))
////    {
//#ifdef TESTPIN
////        TEST_PIN1();
////		printf("EXTI1 interrupt\n");
//#endif
//		GPIOA->ODR ^= 1;
//        GPIO_IntClr(GPIOA, GPIO_Pin_1);
//		GPIOA->IER = 0;
////    }
//	GPIO_IntClr(GPIOB, GPIO_Pin_1);
//}
#endif
/**
 * @brief 端口输入输出配置
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5或组合
 * @param dir: 参考GPIO_dir_t，选择端口方向
 * @return none
 */
void GPIO_Init_b(M0_GPIO_TypeDef* const GPIOx, u8 Pin, GPIO_dir_t dir)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    WRITE_BIT(GPIOx->DIR, Pin, dir);
}

/**
 * @brief GPIO重新复位对应端口
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5或组合
 * @return none
 */
void GPIO_DeInit(M0_GPIO_TypeDef* const GPIOx, u8 Pin)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    GPIOx->DRIVE &= ~Pin;
    GPIOx->DIR   &= ~Pin;
    GPIOx->PUPD  &= ~((Pin << GPIO_PU_TYPE_Pos) | Pin);
    GPIOx->OSOD  &= ~((Pin << GPIO_OS_TYPE_Pos) | Pin);
    GPIO_AlternateFunction(GPIOx, Pin, 0, GPIO_Digital);
}

/**
 * @brief GPIO初始化函数
 * @param *GPIOx: x表示从A..D
 * @param *GPIO_InitStruct: 参考结构体说明
 * @return none
 */
void GPIO_Init(M0_GPIO_TypeDef* const GPIOx, const GPIO_InitTypedef* const GPIO_InitStruct)
{
    u32 GPIO_PUPDReg = 0;
    u32 GPIO_OSODReg = 0;

    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(GPIO_InitStruct->GPIO_Pin));

    if (GPIO_InitStruct->GPIO_Mode & GPIO_Mode_PD_Msk)
    {
        GPIO_PUPDReg = GPIO_InitStruct->GPIO_Pin;
    }
    else if (GPIO_InitStruct->GPIO_Mode & GPIO_Mode_PU_Msk)
    {
        GPIO_PUPDReg = (GPIO_InitStruct->GPIO_Pin) << GPIO_PU_TYPE_Pos;
    }
    if (GPIO_InitStruct->GPIO_Mode & GPIO_Mode_OD_Msk)
    {
        GPIO_OSODReg = GPIO_InitStruct->GPIO_Pin;
    }
    else if (GPIO_InitStruct->GPIO_Mode & GPIO_Mode_OS_Msk)
    {
        GPIO_OSODReg = (GPIO_InitStruct->GPIO_Pin) << GPIO_OS_TYPE_Pos;
    }

    MODIFY_REG(GPIOx->PUPD, (GPIO_InitStruct->GPIO_Pin) | (GPIO_InitStruct->GPIO_Pin << GPIO_PU_TYPE_Pos),
               GPIO_PUPDReg);
    MODIFY_REG(GPIOx->OSOD, (GPIO_InitStruct->GPIO_Pin) | (GPIO_InitStruct->GPIO_Pin << GPIO_OS_TYPE_Pos),
               GPIO_OSODReg);
    WRITE_BIT(GPIOx->DRIVE, GPIO_InitStruct->GPIO_Pin, GPIO_InitStruct->GPIO_Drive);
    WRITE_BIT(GPIOx->SPEED, GPIO_InitStruct->GPIO_Pin, GPIO_InitStruct->GPIO_Speed);
    WRITE_BIT(GPIOx->DIR, GPIO_InitStruct->GPIO_Pin, ((GPIO_InitStruct->GPIO_Mode) & GPIO_Mode_IO_Msk));
}

/**
 * @brief 控制IO端口输出状态
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5或组合
 * @param level: 0-低电平，1-高电平
 * @return none
 */
void GPIO_WriteBits(M0_GPIO_TypeDef* const GPIOx, u8 Pin, u8 level)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    WRITE_BIT(GPIOx->ODR, Pin, level);
}

/**
 * @brief 设置端口输出1
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5或组合
 * @return none
 */
void GPIO_SetBits(M0_GPIO_TypeDef* const GPIOx, u8 Pin)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    GPIOx->ODR |= Pin;
}

/**
 * @brief 设置端口输出0
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5或组合
 * @return none
 */
void GPIO_ResetBits(M0_GPIO_TypeDef* GPIOx, u8 Pin)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    GPIOx->ODR &= ~Pin;
}

void GPIO_ToggleBits(M0_GPIO_TypeDef* GPIOx, u8 Pin)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    GPIOx->ODR ^= Pin;
}

/**
 * @brief 读端口位输出状态
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5
 * @return 端口位状态
 */
u8 GPIO_ReadBit(M0_GPIO_TypeDef* GPIOx, u8 Pin)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PIN(Pin));

    return (!!(GPIOx->IDR & Pin));
}

/**
 * @brief 设置GPIO端口外部中断
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5
 * @param INT_type: 参考GPIO_Int_type_t选择不同中断类型
 * @param pri: 中断优先级0-3
 * @param sw: ENABLE/DISABLE
 * @return none
 */
void GPIO_IntInit(M0_GPIO_TypeDef* const GPIOx, u8 Pin, GPIO_Int_type_t INT_type, u8 pri, FunctionalState sw)
{
    IRQn_Type IRQn = EXTI0_IRQn;
    u8 i;
    u8 tmpPin = Pin;

    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));
    assert_param(IS_NVIC_PRI(pri));

    WRITE_BIT(GPIOx->IER, Pin, 0);    //防止切换过程进中断
    WRITE_BIT(GPIOx->ITRIG, Pin, INT_type & GPIO_Int_Polarity_Msk);
    WRITE_BIT(GPIOx->ITYPE, Pin, INT_type & GPIO_Int_Type_Msk);

    for (i = 0; tmpPin > 0 && i < GPIO_GROUPNUM; tmpPin >>= 1, IRQn++, i++)
    {
        if (tmpPin & 0x01)
        {
            if (sw)
            {
                GPIO_IntClr(GPIOx, tmpPin);    //防止开启中断后马上进中断
                NVIC_DisableIRQ(IRQn);         //防止开启中断后马上进中断
                NVIC_SetPriority(IRQn, pri);
                NVIC_ClearPendingIRQ(IRQn);
                NVIC_EnableIRQ(IRQn);
            }
            else
            {
                NVIC_DisableIRQ(IRQn);
            }
        }
    }
    if (sw)
    {
        WRITE_BIT(GPIOx->IER, Pin, 1);
    }
    else
    {
        WRITE_BIT(GPIOx->IER, Pin, 0);
    }
}

/**
 * @brief 读GPIO中断状态
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5
 * @return 中断状态
 */
u8 GPIO_GetIntStat(M0_GPIO_TypeDef* const GPIOx, u8 Pin)
{
    u8 int_status = 0;

    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PIN(Pin));

    int_status = (GPIOx->ISR) & Pin;
    return int_status;
}

/**
 * @brief 读中断原始标记信号
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5
 * @return 中断原始标记
 */
u8 GPIO_GetRawIntStat(M0_GPIO_TypeDef* const GPIOx, u8 Pin)
{
    u8 int_status = 0;

    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PIN(Pin));

    int_status = (GPIOx->RISR) & Pin;
    return int_status;
}

/**
 * @brief 设置GPIO中断屏蔽
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5
 * @return none
 */
void GPIO_IntMask(M0_GPIO_TypeDef* const GPIOx, u8 Pin)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    GPIOx->IMASK |= Pin;
}

/**
 * @brief 清楚GPIO中断屏蔽
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5
 * @return none
 */
void GPIO_IntUnMask(M0_GPIO_TypeDef* const GPIOx, u8 Pin)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    GPIOx->IMASK &= ~Pin;
}

/**
 * @brief 清楚中断标记
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5
 * @return none
 */
void GPIO_IntClr(M0_GPIO_TypeDef* const GPIOx, u8 Pin)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    GPIOx->ICR = Pin;
}

/**
 * @brief 设置GPIO数字/模拟复用功能
 * @param *GPIOx: x表示从A..D
 * @param Pin: GPIO_Pin_0..5或者组合
 * @param Func: @arg GPIO_Digital 0..7
 *              @arg GPIO_Analog  0
 * @param ADtype:
 * @return none
 */
void GPIO_AlternateFunction(M0_GPIO_TypeDef* const GPIOx, u8 Pin, u8 Func, GPIO_AD_t ADtype)
{
    u8 i;

    assert_param(IS_GPIO_PERIPH(GPIOx));
    assert_param(IS_GPIO_PINs(Pin));

    for (i = 0; i < GPIO_GROUPNUM; Pin >>= 1, i++)
    {
        if (Pin & 0x01)
        {
            if (ADtype == GPIO_Digital)
            {
                GPIOx->AF_DG = (GPIOx->AF_DG & ~(GPIO_AFR1_TYPE_Msk << (3 * i))) | Func << (3 * i);
            }
            else
            {
                GPIOx->AF_ANA = (GPIOx->AF_ANA & ~(GPIO_AFR2_TYPE_Msk << (2 * i))) | Func << (2 * i);
            }
        }
    }
}

/**
 * @brief GPIO中断同步
 * @param *GPIOx: x表示从A..D
 * @param sync_mode:同步/异步设置，参考GPIO_Int_sync_t[如果用于低功耗唤醒@系统时钟关闭，需要启用异步]
 * @return none
 */
void GPIO_IntSync(M0_GPIO_TypeDef* const GPIOx, GPIO_Int_sync_t sync_mode)
{
    assert_param(IS_GPIO_PERIPH(GPIOx));

    GPIOx->ISYNC = sync_mode;
}
