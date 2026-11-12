#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"

/*===========================================================================
 * Minimal Freestanding C Library Helpers (memset / memcpy)
 *===========================================================================*/
void *memset(void *s, int c, size_t n)
{
    uint8_t *p = (uint8_t *)s;
    while (n--)
    {
        *p++ = (uint8_t)c;
    }
    return s;
}

void *memcpy(void *dest, const void *src, size_t n)
{
    uint8_t *d = (uint8_t *)dest;
    const uint8_t *s = (const uint8_t *)src;
    while (n--)
    {
        *d++ = *s++;
    }
    return dest;
}

/*===========================================================================
 * Memory-Mapped Peripheral Register Definitions (CPU_OS SoC)
 *===========================================================================*/
#define REG32(addr)             (*(volatile uint32_t *)(addr))

/* GPI (0x2000_0000) : Basys-3 Switches SW0 ~ SW7 */
#define GPI_BASE                0x20000000UL
#define GPI_CTR                 REG32(GPI_BASE + 0x00UL)
#define GPI_IDR                 REG32(GPI_BASE + 0x04UL)

/* GPO (0x2001_0000) : Basys-3 LEDs LED0 ~ LED7 */
#define GPO_BASE                0x20010000UL
#define GPO_CTR                 REG32(GPO_BASE + 0x00UL)
#define GPO_ODR                 REG32(GPO_BASE + 0x04UL)

/* GPIO (0x2002_0000) : Basys-3 LEDs LED8 ~ LED15 */
#define GPIO_BASE               0x20020000UL
#define GPIO_CTR                REG32(GPIO_BASE + 0x00UL)
#define GPIO_IDR                REG32(GPIO_BASE + 0x04UL)
#define GPIO_ODR                REG32(GPIO_BASE + 0x08UL)

/* APB UART (0x2003_0000) : 9600 Baud 8N1 with 16-Byte TX/RX FIFOs */
#define UART_BASE               0x20030000UL
#define UART_STATUS             REG32(UART_BASE + 0x00UL)
#define UART_TX                 REG32(UART_BASE + 0x04UL)
#define UART_RX                 REG32(UART_BASE + 0x08UL)

#define UART_ST_TX_FULL         (1UL << 3)
#define UART_ST_TX_EMPTY        (1UL << 2)
#define UART_ST_RX_FULL         (1UL << 1)
#define UART_ST_RX_EMPTY        (1UL << 0)

/*===========================================================================
 * UART Helper Functions
 *===========================================================================*/
static void uart_putc(char c)
{
    while (UART_STATUS & UART_ST_TX_FULL)
    {
        /* Wait until TX FIFO has space */
    }
    UART_TX = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *s)
{
    while (*s)
    {
        uart_putc(*s++);
    }
}

static char hex_digit(uint8_t v)
{
    v &= 0x0FU;
    return (v < 10U) ? (char)('0' + v) : (char)('A' + (v - 10U));
}

/*===========================================================================
 * Shared GPO State (LED0~3 owned by Task 1, LED4~7 owned by Task 2)
 *===========================================================================*/
static volatile uint8_t g_led_low_nibble  = 0x01U;
static volatile uint8_t g_led_high_nibble = 0x10U;

static void update_gpo_leds(void)
{
    GPO_ODR = (uint32_t)((g_led_high_nibble & 0xF0U) | (g_led_low_nibble & 0x0FU));
}

/*===========================================================================
 * Task 1: Binary Counter on LED0 ~ LED3 (500 ms period) + UART Status
 *===========================================================================*/
static void vTaskLed1(void *pvParameters)
{
    (void)pvParameters;
    uint8_t count = 1U;
    uint8_t first_run = 1U;

    for (;;)
    {
        taskENTER_CRITICAL();
        g_led_low_nibble = (count & 0x0FU);
        update_gpo_leds();
        taskEXIT_CRITICAL();

        uart_putc('T');
        uart_putc('1');
        uart_putc(':');
        uart_putc(hex_digit(count));
        uart_putc('\r');
        uart_putc('\n');

        count++;

        if (first_run)
        {
            first_run = 0U;
            vTaskDelay(1); /* Fast 1-tick delay on boot for quick sim verification */
        }
        else
        {
            vTaskDelay(pdMS_TO_TICKS(500));
        }
    }
}

/*===========================================================================
 * Task 2: Walking LED on LED4 ~ LED7 (250 ms period) + UART Status
 *===========================================================================*/
static void vTaskLed2(void *pvParameters)
{
    (void)pvParameters;
    uint8_t shift = 0U;
    uint8_t first_run = 1U;

    for (;;)
    {
        taskENTER_CRITICAL();
        g_led_high_nibble = (uint8_t)(0x10U << (shift & 0x03U));
        update_gpo_leds();
        taskEXIT_CRITICAL();

        uart_putc('T');
        uart_putc('2');
        uart_putc(':');
        uart_putc(hex_digit((uint8_t)(1U << (shift & 0x03U))));
        uart_putc('\r');
        uart_putc('\n');

        shift = (uint8_t)((shift + 1U) & 0x03U);

        if (first_run)
        {
            first_run = 0U;
            vTaskDelay(1); /* Fast 1-tick delay on boot for quick sim verification */
        }
        else
        {
            vTaskDelay(pdMS_TO_TICKS(250));
        }
    }
}

/*===========================================================================
 * Task 3: Switch Mirror (SW0~7 -> LED8~15) + UART RX Echo (10 ms period)
 *===========================================================================*/
static void vTaskIoMirror(void *pvParameters)
{
    (void)pvParameters;
    uint8_t first_run = 1U;

    for (;;)
    {
        /* Mirror SW0~SW7 (GPI) directly onto LED8~LED15 (GPIO) */
        uint32_t sw = GPI_IDR & 0xFFUL;
        GPIO_ODR = sw;

        /* If UART RX FIFO has data, echo it back */
        if ((UART_STATUS & UART_ST_RX_EMPTY) == 0UL)
        {
            char rx_ch = (char)(UART_RX & 0xFFUL);
            taskENTER_CRITICAL();
            uart_putc('[');
            uart_putc(rx_ch);
            uart_putc(']');
            uart_putc('\r');
            uart_putc('\n');
            taskEXIT_CRITICAL();
        }

        if (first_run)
        {
            first_run = 0U;
            vTaskDelay(1);
        }
        else
        {
            vTaskDelay(pdMS_TO_TICKS(10));
        }
    }
}

/*===========================================================================
 * Main Entry Point
 *===========================================================================*/
int main(void)
{
    /* Enable all 8 bits on GPI (SW0~7), GPO (LED0~7), and GPIO (LED8~15) */
    GPI_CTR  = 0xFFUL;
    GPO_CTR  = 0xFFUL;
    GPIO_CTR = 0xFFUL;

    /* Initial LED pattern on boot */
    GPO_ODR  = 0x11UL;
    GPIO_ODR = 0xAAUL;

    /* Send boot banner to UART TX FIFO */
    uart_puts("RTOS!\r\n");

    /* Create FreeRTOS Tasks */
    xTaskCreate(vTaskLed1,     "LED1", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    xTaskCreate(vTaskLed2,     "LED2", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    xTaskCreate(vTaskIoMirror, "IO",   configMINIMAL_STACK_SIZE, NULL, 1, NULL);

    /* Start the FreeRTOS Preemptive Scheduler */
    vTaskStartScheduler();

    /* Should never reach here */
    for (;;)
    {
    }
}
