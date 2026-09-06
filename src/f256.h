
#ifndef F256_H
#define F256_H

#include <stdbool.h>
#include <stdint.h>

#define TEMP_ADDR          ((uint8_t*)0xA000)
#define TEMP_SIZE          (0x2000)

#define TEXT_WIDTH         80
#define TEXT_HEIGHT        30

#define KEY_UP             0x10
#define KEY_DOWN           0x0E
#define KEY_LEFT           0x02
#define KEY_RIGHT          0x06
#define KEY_RETURN         0x0D
#define KEY_SPACE          0x20
#define KEY_BACKSPACE      0x08
#define KEY_ESCAPE         0x1B
#define KEY_RUN_STOP       0x03

#define FLASH_SECTOR_START 0x40
#define FLASH_SECTOR_END   0x78

#define MACHINE_F256_JR    0x02
#define MACHINE_F256_K     0x12

void     map(uint8_t sector);

void     home(void);
void     clear(void);
void     color(uint8_t c);
void     at(uint8_t x, uint8_t y);

void     putc(char ch);
void     puts(const char* str);
void     puti(uint16_t value);
void     puth8(uint8_t value);
void     puth16(uint16_t value);
void     puth32(uint32_t value);
void     newline(void);

uint8_t  get_machine_id(void);

char     getc(void);

void     decompress(uint8_t* source, uint8_t* dest);
uint8_t* decompress_get_end(void);

// Global zero-page variables we can use
extern uint8_t  index0;
extern uint16_t index1;
extern uint8_t* ptr0;

#pragma zpsym("index0");
#pragma zpsym("index1");
#pragma zpsym("ptr0");

#endif
