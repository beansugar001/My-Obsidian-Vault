#include "cj32l01xx.h"
#include "cj32l01xx_gpio.h"
#include "cj32l01xx_rcc.h"
#include "cj32l01xx_i2c.h"


/*==========================================================
 * Slave Address
 *==========================================================*/
#define I2C_SLAVE_ADDR      0x50


/*
 * ??????????
 * ??????Debug,???????
 */
#define I2C_FRAME_DELAY     2000000UL


/*==========================================================
 * Watch??
 *==========================================================*/

/* ?????? */
volatile u32 g_i2c_tx_count = 0;

/* NACK?? */
volatile u32 g_i2c_nack_count = 0;

/* Timeout?? */
volatile u32 g_i2c_timeout_count = 0;

/* Arbitration / Address Error?? */
volatile u32 g_i2c_error_count = 0;


/* ????????? */
volatile u8 g_i2c_tx_data = 0;

/*
 * ????????:
 *
 *  0  = success
 * -1  = NACK
 * -2  = TX timeout
 * -3  = arbitration/address error
 * -4  = STOP timeout
 */
volatile int g_i2c_last_result = 0;


/*
 * ????????
 */
volatile u32 g_i2c_sr = 0;
volatile u32 g_i2c_fifo_sr = 0;
volatile u32 g_i2c_risr = 0;


/*
 * ??????:
 *
 * 0 = idle
 * 1 = byte??FIFO
 * 2 = TX FIFO?????
 * 3 = ?GenerateStop
 * 4 = ??????
 *
 * E1/E2/E3... = ????
 */
volatile u32 g_master_stage = 0;


/*
 * ????Master?????WORK / DATA
 */
volatile u32 g_master_seen_work = 0;
volatile u32 g_master_seen_data = 0;


/*==========================================================
 * Delay
 *==========================================================*/
static void Delay_Test(volatile u32 count)
{
    while(count--)
    {
        __NOP();
    }
}


/*==========================================================
 * ??I2C????
 *==========================================================*/
static void I2C_SaveStatus(void)
{
    g_i2c_sr =
        M0_I2C->SR;

    g_i2c_fifo_sr =
        M0_I2C->FIFO_SR;

    g_i2c_risr =
        M0_I2C->RISR;
}


/*==========================================================
 * Master GPIO
 *
 * PAD8 = GPIOB2 = I2C_SCL
 * PAD9 = GPIOB3 = I2C_SDA
 *
 * AF3
 *==========================================================*/
static void I2C_Master_GPIO_Init(void)
{
    GPIO_InitTypedef GPIO_InitStructure;


    /*
     * GPIO clock
     */
    PeriCLK_Cmd(GPIO_PCLK, ENABLE);


    /*------------------------------------------------------
     * PAD0/PAD1??I2C
     *
     * ARM??GPIO???AF5
     *------------------------------------------------------*/
    GPIO_AlternateFunction(GPIOA,
                           GPIO_Pin_0 | GPIO_Pin_1,
                           5,
                           GPIO_Digital);


    GPIO_InitStructure.GPIO_Pin =
        GPIO_Pin_0 | GPIO_Pin_1;

    GPIO_InitStructure.GPIO_Mode =
        GPIO_Mode_IN_FLOATING;

    GPIO_InitStructure.GPIO_Drive =
        GPIO_Dr_Low;

    GPIO_InitStructure.GPIO_Speed =
        GPIO_Sr_Slow;

    GPIO_Init(GPIOA,
              &GPIO_InitStructure);


    /*------------------------------------------------------
     * PAD8/PAD9
     *
     * Master I2C Open Drain
     *------------------------------------------------------*/
    GPIO_InitStructure.GPIO_Pin =
        GPIO_Pin_2 | GPIO_Pin_3;

    GPIO_InitStructure.GPIO_Mode =
        GPIO_Mode_Out_OD;

    GPIO_InitStructure.GPIO_Drive =
        GPIO_Dr_High;

    GPIO_InitStructure.GPIO_Speed =
        GPIO_Sr_Fast;

    GPIO_Init(GPIOB,
              &GPIO_InitStructure);


    /*
     * PAD8/PAD9 -> I2C AF3
     */
    GPIO_AlternateFunction(GPIOB,
                           GPIO_Pin_2 | GPIO_Pin_3,
                           3,
                           GPIO_Digital);


    /*
     * ???????????
     */
    GPIOB->PUPD &=
        ~(GPIO_Pin_2 | GPIO_Pin_3);

    GPIOB->PUPD |=
        ((GPIO_Pin_2 | GPIO_Pin_3)
         << GPIO_PU_TYPE_Pos);
}


/*==========================================================
 * I2C Master???
 *==========================================================*/
static void I2C_Master_Init(void)
{
    I2CM_InitTypedef I2CM_InitStructure;


    I2C_Master_GPIO_Init();


    /*
     * ???????I2C???
     *
     * ?????????,
     * ?????????
     */
    I2CM_InitStructure.CLK_Div_H =
        1000;

    I2CM_InitStructure.CLK_Div_L =
        1000;


    I2CM_InitStructure.HOLD =
        5;


    I2CM_InitStructure.GCALL =
        GCALL_DIS;


    I2CM_InitStructure.SBYTE =
        SBYTE_DIS;


    I2CM_InitStructure.HS_MODE =
        HSMODE_DIS;


    /*
     * ???:
     *
     * TX FIFO????SCL Low?
     * ????GenerateStop?
     */
    I2CM_InitStructure.STOP_MODE =
        SCL_L;


    I2CM_InitStructure.ADDR_MODE =
        ADDR_7bits;


    if(I2C_MasterInit(&I2CM_InitStructure) != OK)
    {
        while(1)
        {
        }
    }


    /*
     * Slave??
     */
    if(I2C_SetAddr(I2C_SLAVE_ADDR) != OK)
    {
        while(1)
        {
        }
    }


    /*
     * Enable I2C
     */
    I2C_Cmd(ENABLE);


    /*
     * ????
     */
    I2C_IntClr(
        (I2C_INT_t)(
            I2C_INT_Stop        |
            I2C_INT_NACK        |
            I2C_INT_M_Lose_ARBI |
            I2C_INT_A_Err
        )
    );


    I2C_SaveStatus();
}


/*==========================================================
 * Master??1 Byte
 *
 * ???????????
 *==========================================================*/
static int I2C_Master_SendByte(u8 data)
{
    u32 timeout;
    u32 sr;
    u32 risr;
    u32 fifo_sr;
    u32 tx_num;


    /*------------------------------------------------------
     * ???GenerateStop??STOP bit=1?
     *
     * ??????????:
     *
     * STOP = 0
     * STOP_MODE = SCL_L
     *------------------------------------------------------*/
    M0_I2C->MCTR &=
        ~I2C_STOP_Msk;


    /*
     * ?????????
     */
    I2C_IntClr(
        (I2C_INT_t)(
            I2C_INT_Stop        |
            I2C_INT_NACK        |
            I2C_INT_M_Lose_ARBI |
            I2C_INT_A_Err
        )
    );


    g_master_stage =
        0;

    g_master_seen_work =
        0;

    g_master_seen_data =
        0;


    g_i2c_tx_data =
        data;


    /*======================================================
     * Stage 1
     *
     * ?TX FIFO
     *======================================================*/
    I2C_WrByte(data);


    g_master_stage =
        1;


    /*======================================================
     * ??TX FIFO?????
     *======================================================*/
    timeout =
        3000000UL;


    while(timeout > 0)
    {
        timeout--;


        sr =
            M0_I2C->SR;

        risr =
            M0_I2C->RISR;

        fifo_sr =
            M0_I2C->FIFO_SR;


        /*
         * TX_NUM = FIFO_SR[11:8]
         */
        tx_num =
            (fifo_sr >> 8) & 0x0F;


        /*
         * ??Master?????????
         */
        if(sr & I2CM_Work)
        {
            g_master_seen_work =
                1;
        }


        if(sr & I2CM_Data)
        {
            g_master_seen_data =
                1;
        }


        /*--------------------------------------------------
         * Arbitration / Address Error
         *--------------------------------------------------*/
        if(risr &
           (I2C_INT_M_Lose_ARBI |
            I2C_INT_A_Err))
        {
            g_master_stage =
                0xE1;

            g_i2c_error_count++;


            /*
             * ??????
             */
            I2C_GenerateStop();


            I2C_SaveStatus();


            return -3;
        }


        /*--------------------------------------------------
         * NACK
         *--------------------------------------------------*/
        if(risr & I2C_INT_NACK)
        {
            g_master_stage =
                0xE2;

            g_i2c_nack_count++;


            I2C_GenerateStop();


            I2C_SaveStatus();


            return -1;
        }


        /*--------------------------------------------------
         * ????????:
         *
         * Master???DATA
         * &&
         * TX_NUM == 0
         *
         * ???????GenerateStop?
         *--------------------------------------------------*/
        if((g_master_seen_data != 0) &&
           (tx_num == 0))
        {
            break;
        }
    }


    /*
     * TX????
     */
    if(timeout == 0)
    {
        g_master_stage =
            0xE3;

        g_i2c_timeout_count++;


        /*
         * ????SCL
         */
        I2C_GenerateStop();


        I2C_SaveStatus();


        return -2;
    }


    /*======================================================
     * Stage 2
     *
     * ?????I2C????
     *======================================================*/
    g_master_stage =
        2;


    /*======================================================
     * ????STOP
     *
     * ???????????SCL Low???
     *======================================================*/
    I2C_GenerateStop();


    g_master_stage =
        3;


    /*======================================================
     * ??Master??IDLE
     *======================================================*/
    timeout =
        3000000UL;


    while(timeout > 0)
    {
        timeout--;


        sr =
            M0_I2C->SR;

        risr =
            M0_I2C->RISR;


        /*
         * ???STOP?????????
         */
        if(risr & I2C_INT_NACK)
        {
            g_master_stage =
                0xE4;

            g_i2c_nack_count++;


            I2C_SaveStatus();


            return -1;
        }


        if(risr &
           (I2C_INT_M_Lose_ARBI |
            I2C_INT_A_Err))
        {
            g_master_stage =
                0xE5;

            g_i2c_error_count++;


            I2C_SaveStatus();


            return -3;
        }


        /*
         * I2CM_WORK == 0
         *
         * ?????????
         */
        if((sr & I2CM_Work) == 0)
        {
            g_master_stage =
                4;


            g_i2c_tx_count++;


            /*
             * ??STOP???????,
             * ???????????
             */
            if(M0_I2C->RISR &
               I2C_INT_Stop)
            {
                I2C_IntClr(
                    I2C_INT_Stop);
            }


            I2C_SaveStatus();


            return 0;
        }
    }


    /*
     * STOP??Timeout
     */
    g_master_stage =
        0xE6;

    g_i2c_timeout_count++;


    I2C_SaveStatus();


    return -4;
}


/*==========================================================
 * main
 *
 * ??????:
 *
 * A5 -> STOP -> delay
 * 5A -> STOP -> delay
 * A5 -> ...
 *==========================================================*/
int main(void)
{
    int result;


    /*
     * ???I2C Master
     */
    I2C_Master_Init();


    /*
     * ?Slave????
     */
    Delay_Test(I2C_FRAME_DELAY);


    while(1)
    {
        /*==================================================
         * Frame 1
         *
         * ?? A5
         *==================================================*/
        result =
            I2C_Master_SendByte(0xA5);


        g_i2c_last_result =
            result;


        /*
         * ?????????????
         *
         * ????????????
         */
        Delay_Test(I2C_FRAME_DELAY);



        /*==================================================
         * Frame 2
         *
         * ?? 5A
         *==================================================*/
        result =
            I2C_Master_SendByte(0x5A);


        g_i2c_last_result =
            result;


        Delay_Test(I2C_FRAME_DELAY);
    }
}