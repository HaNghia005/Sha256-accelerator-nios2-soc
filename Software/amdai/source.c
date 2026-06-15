#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "system.h"
#include "io.h"
#ifndef LCD_SCL_BASE
#define LCD_SCL_BASE 0x13090
#endif

#ifndef LCD_SDA_BASE
#define LCD_SDA_BASE 0x13080
#endif
// ============================================================================
// CẤU HÌNH LCD I2C BIT-BANG
// ============================================================================
#define I2C_LCD_ADDR 0x27

void delay_us(int us) { usleep(us); }

void I2C_SCL_Write(int s) { IOWR(LCD_SCL_BASE, 0, s); }

void I2C_SDA_Write(int s) {
    if (s)
        IOWR(LCD_SDA_BASE, 1, 0);
    else {
        IOWR(LCD_SDA_BASE, 1, 1);
        IOWR(LCD_SDA_BASE, 0, 0);
    }
}

void I2C_Start() {
    I2C_SDA_Write(1); I2C_SCL_Write(1); delay_us(4);
    I2C_SDA_Write(0); delay_us(4);
    I2C_SCL_Write(0);
}

void I2C_Stop() {
    I2C_SDA_Write(0); delay_us(4);
    I2C_SCL_Write(1); delay_us(4);
    I2C_SDA_Write(1);
}

void I2C_SendByte(unsigned char d) {
    int i;
    for (i = 0; i < 8; i++) {
        I2C_SDA_Write((d & 0x80) ? 1 : 0);
        delay_us(2); I2C_SCL_Write(1); delay_us(4);
        I2C_SCL_Write(0); delay_us(2);
        d <<= 1;
    }
    I2C_SDA_Write(1);
    delay_us(2); I2C_SCL_Write(1); delay_us(4); I2C_SCL_Write(0);
}

void LCD_Write_Nibble(unsigned char n, unsigned char rs) {
    unsigned char d = n | (rs ? 0x01 : 0x00) | 0x08;
    I2C_Start();
    I2C_SendByte(I2C_LCD_ADDR << 1);
    I2C_SendByte(d | 0x04); delay_us(1);
    I2C_SendByte(d & ~0x04); delay_us(50);
    I2C_Stop();
}

void LCD_Send(unsigned char v, unsigned char mode) {
    LCD_Write_Nibble(v & 0xF0, mode);
    LCD_Write_Nibble((v << 4) & 0xF0, mode);
}

void LCD_Command(unsigned char c) { LCD_Send(c, 0); }
void LCD_Char(unsigned char c)    { LCD_Send(c, 1); }

void LCD_Init() {
    delay_us(50000);
    LCD_Write_Nibble(0x30, 0); delay_us(5000);
    LCD_Write_Nibble(0x30, 0); delay_us(200);
    LCD_Write_Nibble(0x30, 0); delay_us(200);
    LCD_Write_Nibble(0x20, 0); delay_us(200);
    LCD_Command(0x28); LCD_Command(0x0C);
    LCD_Command(0x06); LCD_Command(0x01);
    delay_us(2000);
}

void LCD_SetCursor(unsigned char row, unsigned char col) {
    LCD_Command((row == 0 ? 0x80 : 0xC0) + col);
}

void LCD_String(char *s) { while (*s) LCD_Char(*s++); }

// ============================================================================
// SHA256 DRIVER
// ============================================================================
#define SHA256_BASE 0x11000u
#define SHA256_REG(offset) (*(volatile uint32_t *)(SHA256_BASE + ((offset) << 2)))

enum {
    SHA256_REG_BLOCK0 = 0,
    SHA256_REG_CTRL   = 16,
    SHA256_REG_DIGEST0 = 17
};

#define SHA256_CTRL_INIT       (1u << 0)
#define SHA256_CTRL_NEXT       (1u << 1)
#define SHA256_STATUS_DONE     (1u << 0)
#define SHA256_STATUS_READY    (1u << 1)
#define SHA256_STATUS_VALID    (1u << 2)

static inline uint32_t be_word(const uint8_t bytes[4])
{
    return ((uint32_t)bytes[0] << 24) |
           ((uint32_t)bytes[1] << 16) |
           ((uint32_t)bytes[2] << 8) |
           ((uint32_t)bytes[3]);
}

static inline void sha256_write_block(const uint8_t block[64])
{
    int i;
    for (i = 0; i < 16; i++) {
        SHA256_REG(SHA256_REG_BLOCK0 + i) = be_word(&block[i * 4]);
    }
}

static inline void sha256_start_init(void)
{
    SHA256_REG(SHA256_REG_CTRL) = SHA256_CTRL_INIT;
}

static inline void sha256_poll_done(void)
{
    while ((SHA256_REG(SHA256_REG_CTRL) & SHA256_STATUS_DONE) == 0u) {
        ;
    }
}

static inline void sha256_read_digest(uint8_t digest[32])
{
    int i;
    for (i = 0; i < 8; i++) {
        uint32_t w = SHA256_REG(SHA256_REG_DIGEST0 + i);
        digest[i * 4 + 0] = (uint8_t)(w >> 24);
        digest[i * 4 + 1] = (uint8_t)(w >> 16);
        digest[i * 4 + 2] = (uint8_t)(w >> 8);
        digest[i * 4 + 3] = (uint8_t)(w >> 0);
    }
}

void sha256_compute_single_block(const uint8_t block[64], uint8_t digest[32])
{
    sha256_write_block(block);
    sha256_start_init();
    sha256_poll_done();
    sha256_read_digest(digest);
}

static void store_be32(uint8_t *dst, uint32_t value)
{
    dst[0] = (uint8_t)(value >> 24);
    dst[1] = (uint8_t)(value >> 16);
    dst[2] = (uint8_t)(value >> 8);
    dst[3] = (uint8_t)value;
}

static int pad_sha256_single_block(const uint8_t *msg, uint32_t len, uint8_t block[64])
{
    if (len > 55u) {
        return -1;
    }

    memset(block, 0, 64);
    memcpy(block, msg, len);
    block[len] = 0x80;

    uint64_t bitlen = (uint64_t)len << 3;
    store_be32(&block[56], (uint32_t)(bitlen >> 32));
    store_be32(&block[60], (uint32_t)(bitlen & 0xffffffffu));
    return 0;
}

static void print_hash(const uint8_t digest[32])
{
    int i;
    for (i = 0; i < 32; i++) {
        printf("%02x", digest[i]);
    }
}

// ============================================================================
// MAIN ROUTINE
// ============================================================================
int main(void)
{
    static const char *tests[100] = {
        "abc",
        "hello",
        "123456",
        "The quick brown fox",
        "Test case one",
        "Test case two",
        "OpenAI",
        "SHA256",
        "hardware",
        "software",
        "embedded",
        "FPGA",
        "Nios II",
        "Avalon",
        "data stream",
        "message digest",
        "digital logic",
        "design verification",
        "unit test",
        "integration test",
        "system test",
        "random data",
        "patterns",
        "repeat me",
        "sample input",
        "longer sentence example",
        "small message",
        "medium size",
        "tiny",
        "zero",
        "one",
        "two",
        "three",
        "four",
        "five",
        "six",
        "seven",
        "eight",
        "nine",
        "ten",
        "eleven",
        "twelve",
        "thirteen",
        "fourteen",
        "fifteen",
        "sixteen",
        "seventeen",
        "eighteen",
        "nineteen",
        "twenty",
        "twenty one",
        "twenty two",
        "twenty three",
        "twenty four",
        "twenty five",
        "twenty six",
        "twenty seven",
        "twenty eight",
        "twenty nine",
        "thirty",
        "thirty one",
        "thirty two",
        "thirty three",
        "thirty four",
        "thirty five",
        "thirty six",
        "thirty seven",
        "thirty eight",
        "thirty nine",
        "forty",
        "forty one",
        "forty two",
        "forty three",
        "forty four",
        "forty five",
        "forty six",
        "forty seven",
        "forty eight",
        "forty nine",
        "fifty",
        "fifty one",
        "fifty two",
        "fifty three",
        "fifty four",
        "fifty five",
        "fifty six",
        "fifty seven",
        "fifty eight",
        "fifty nine",
        "sixty",
        "sixty one",
        "sixty two",
        "sixty three",
        "sixty four",
        "sixty five",
        "sixty six",
        "sixty seven",
        "sixty eight",
        "sixty nine",
        "seventy"
    };

    const int test_count = 100;
    uint8_t block[64];
    uint8_t digest[32];
    char lcd_buf[17]; // Buffer 16 ký tự cho LCD
    int idx;

    // Khởi tạo LCD
    printf("=== BOOTING NIOS II SHA256 & LCD ===\n");
    LCD_Init();
    LCD_SetCursor(0, 0);
    LCD_String("SHA256 Hardware");
    LCD_SetCursor(1, 0);
    LCD_String("Initializing... ");
    usleep(1500000); // Dừng 1.5s để nhìn thông báo khởi động

    for (idx = 0; idx < test_count; idx++) {
        const char *msg = tests[idx];
        uint32_t len = (uint32_t)strlen(msg);

        printf("Test %d: %s\n", idx + 1, msg);

        if (pad_sha256_single_block((const uint8_t *)msg, len, block) != 0) {
            printf("Result%d: message too long for single-block demo\n", idx + 1);

            // Cập nhật LCD cho chuỗi quá dài
            snprintf(lcd_buf, 17, "Msg Too Long!   ");
            LCD_SetCursor(0, 0); LCD_String(lcd_buf);
            LCD_SetCursor(1, 0); LCD_String("Skipped.        ");
            usleep(500000);
            continue;
        }

        sha256_compute_single_block(block, digest);

        printf("Result%d: ", idx + 1);
        print_hash(digest);
        printf("\n");

        {
            size_t msg_len = strlen(msg);
            size_t copy_len = msg_len < 16 ? msg_len : 16;
            memset(lcd_buf, ' ', sizeof(lcd_buf));
            memcpy(lcd_buf, msg, copy_len);
            lcd_buf[16] = '\0';
        }

        // Hiển thị 4 phần của hash, mỗi phần 8 byte (16 ký tự hex)
        int part;
                for (part = 0; part < 4; part++) {
                    // 1. Dòng trên: Hiển thị "Tên: 1/4"
                    char short_msg[11];
                    size_t msg_len = strlen(msg);

                    // Chỉ lấy tối đa 10 ký tự đầu của msg để không bị tràn màn hình
                    if (msg_len > 10) msg_len = 10;
                    memcpy(short_msg, msg, msg_len);
                    short_msg[msg_len] = '\0';

                    // Ghép số part vào (VD: "abc: 1/4")
                    char temp_msg[17];
                    snprintf(temp_msg, sizeof(temp_msg), "%s: %d/4", short_msg, part + 1);

                    // Bơm khoảng trắng (space) cho đủ 16 ký tự để LCD xóa được chữ cũ
                    memset(lcd_buf, ' ', 16);
                    size_t temp_len = strlen(temp_msg);
                    memcpy(lcd_buf, temp_msg, temp_len); // Ghi đè chữ lên nền khoảng trắng
                    lcd_buf[16] = '\0';

                    // In ra dòng 0
                    LCD_SetCursor(0, 0);
                    LCD_String(lcd_buf);

                    // 2. Dòng dưới: Hiển thị 8 byte tương ứng (16 ký tự hex)
                    int byte_offset = part * 8;
                    snprintf(lcd_buf, 17, "%02x%02x%02x%02x%02x%02x%02x%02x",
                             digest[byte_offset + 0], digest[byte_offset + 1],
                             digest[byte_offset + 2], digest[byte_offset + 3],
                             digest[byte_offset + 4], digest[byte_offset + 5],
                             digest[byte_offset + 6], digest[byte_offset + 7]);

                    // In ra dòng 1
                    LCD_SetCursor(1, 0);
                    LCD_String(lcd_buf);

                    // Tạm dừng 0.8s
                    usleep(800000);
                }
    }

    // Hoàn thành
    LCD_SetCursor(0, 0); LCD_String("Test Complete!  ");
    LCD_SetCursor(1, 0); LCD_String("Check Terminal  ");

    return 0;
}
