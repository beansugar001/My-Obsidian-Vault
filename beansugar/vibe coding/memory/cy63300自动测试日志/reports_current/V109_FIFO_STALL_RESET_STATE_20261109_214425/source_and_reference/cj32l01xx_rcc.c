#include "cj32l01xx_rcc.h"

void PeriCLK_Cmd(PCLK_t pclk, FunctionalState sw)
{
    WRITE_BIT(M0_SYSCTRL->PCLK_EN, pclk, sw);
}

RES_t CLK_Cmd(CLK_t clk, FunctionalState sw, u32 nms)
{
    return OK;
}

/**
 * @brief 时钟之间切换
 * @param clk: 参考CLK_t
 * @return 参考RES_t返回时钟动作结果
 */
RES_t CLK_SwitchTo(CLK_t clk)
{
	PeriCLK_Cmd(EFC_CLK, ENABLE);	
    if (CLK_Cmd(clk, ENABLE, STABLE_TIME))
    { /* 使能选择时钟 */
        return Error;
    }
    switch (clk)
    {
        case CLK_HSI16M:
			M0_EFC->READ_CYC = 2;
            M0_SYSCTRL->HSI_CTRL = CLK_HSI16M;
            M0_SYSCTRL->SYSCTRL0 &= ~(1 | 5);
            SystemCoreClock      = HSI_16MHZ;
            break;
        case CLK_HSI24M:
			M0_EFC->READ_CYC = 2;
            M0_SYSCTRL->HSI_CTRL = CLK_HSI24M;
            M0_SYSCTRL->SYSCTRL0 &= ~(1 | 5);
            SystemCoreClock      = HSI_24MHZ;
            break;
        case CLK_HSI32M:
			M0_EFC->READ_CYC = 2;
            M0_SYSCTRL->HSI_CTRL = CLK_HSI32M;
            M0_SYSCTRL->SYSCTRL0 &= ~(1 | 5);
            SystemCoreClock      = HSI_32MHZ;
            break;
        case CLK_HSI48M:
			M0_EFC->READ_CYC = 2;
            M0_SYSCTRL->HSI_CTRL = CLK_HSI48M;
            M0_SYSCTRL->SYSCTRL0 &= ~(1 | 5);
            SystemCoreClock      = HSI_48MHZ;
            break;
        case CLK_LSI:
            M0_SYSCTRL->SYSCTRL0 &= ~SYSCTRL_LCLK_SEL_Msk;
            M0_SYSCTRL->SYSCTRL0 |= 1 | 5;
            SystemCoreClock      = LSIVALUE;
            break;
        default:
            return ErrorInvalidParameter;
    }
    return OK;
}

/**
 * @brief AHB/APB时钟分频
 * @param clk: 参考HPCLK_t
 * @param div: 参考HPCLK_DIV_t
 * @return none
 */
void CLK_Div(HPCLK_t clk, HPCLK_DIV_t div)
{
    if (clk == AHB_CLK)
    {
        if (div <= HPCLK_DIV128)
        {
            M0_SYSCTRL->SYSCTRL0 = (M0_SYSCTRL->SYSCTRL0 & ~SYSCTRL_AHBCLK_DIV_Msk) | (div << SYSCTRL_AHBCLK_DIV_Pos);
        }
    }
    else if (clk == APB_CLK)
    {
        if (div > HPCLK_DIV8)
        {
            div = HPCLK_DIV8;
        }
        M0_SYSCTRL->SYSCTRL0 = (M0_SYSCTRL->SYSCTRL0 & ~SYSCTRL_APBCLK_DIV_Msk) | (div << SYSCTRL_APBCLK_DIV_Pos);
    }
}

/**
 * @brief 获取各个CLKs的频率值
 * @param none
 * @return none
 */
//void Get_CLKs_Freq(CLKs_Freq_t* const rcc_clks)
//{
//    switch (M0_SYSCTRL->SYSCTRL0 & (SYSCTRL_SYSCLK_SEL_Msk | SYSCTRL_HCLK_SEL_Msk | SYSCTRL_LCLK_SEL_Msk))
//    {
//        case 0: /* HSI */
//        case 4:
//            switch ((M0_SYSCTRL->HSI_CTRL & SYSCTRL_HSI_TRIM_Msk) >> SYSCTRL_HSI_TRIM_Pos)
//            {
//                case 0:
//                    rcc_clks->SYS_freq = HSI_16MHZ;
//                    break;
//                case 1:
//                    rcc_clks->SYS_freq = HSI_32MHZ;
//                    break;
//                case 2:
//                    rcc_clks->SYS_freq = HSI_48MHZ;
//                    break;
//                case 3:
//                    rcc_clks->SYS_freq = HSI_60MHZ;
//                    break;
//                default:
//                    break;
//            }
//            break;
//        case 1: /* LSI */
//        case 3:
//            rcc_clks->SYS_freq = LSIVALUE;
//            break;
//        default:
//            break;
//    }
//    SystemCoreClock    = rcc_clks->SYS_freq;
//    rcc_clks->AHB_Freq = SystemCoreClock >> ((M0_SYSCTRL->SYSCTRL0 & SYSCTRL_AHBCLK_DIV_Msk) >> SYSCTRL_AHBCLK_DIV_Pos);
//    rcc_clks->APB_Freq =
//        rcc_clks->AHB_Freq >> ((M0_SYSCTRL->SYSCTRL0 & SYSCTRL_APBCLK_DIV_Msk) >> SYSCTRL_APBCLK_DIV_Pos);
//}

void Get_CLKs_Freq(CLKs_Freq_t* const rcc_clks)
{
    rcc_clks->AHB_Freq = SystemCoreClock;
    rcc_clks->APB_Freq = SystemCoreClock;
    rcc_clks->SYS_freq = SystemCoreClock;
}

/**
 * @brief 外设复位
 * @param periph: 参考psft_rst_t选择外设类型
 * @return none
 */
void Peri_SoftReset(psft_rst_t periph)
{
    M0_SYSCTRL->PERI_SOFT_RST |= periph;
    M0_SYSCTRL->PERI_SOFT_RST &= ~periph;
}

/**
 * @brief 低功耗外设模块选择不同时钟
 * @param lpfunc: 低功耗外设模块选择
 * @param sel: 低功耗外设时钟选择
 * @return none
 */
void CLK_LpPeriClkSelect(lpfunc_t lpfunc, lpfunc_clk_sel_t sel)
{
    M0_SYSCTRL->SYSCTRL1 = (M0_SYSCTRL->SYSCTRL1 & (~(3UL << (2 * lpfunc + 1)))) | (sel << (2 * lpfunc + 1));
}
