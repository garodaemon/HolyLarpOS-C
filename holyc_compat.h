#ifndef HOLYC_COMPAT_H
#define HOLYC_COMPAT_H

typedef long long I64;
typedef unsigned long long U64;
typedef unsigned int U32;
typedef signed char I8;
typedef unsigned short U16;
typedef unsigned char U8;
typedef void U0;

#define Sti __asm__ volatile ("sti")
#define Hlt __asm__ volatile ("hlt")
#define SetGDT(p) __asm__ volatile("lgdt %0" : : "m"(*(p)))
#define SetIDT(p) __asm__ volatile("lidt %0" : : "m"(*(p)))

static inline U8 InU8(U16 port) {
    U8 ret;
    __asm__ volatile ("inb %w1, %b0" : "=a"(ret) : "Nd"(port));
    return ret;
}

static inline U0 OutU8(U16 port, U8 val) {
    __asm__ volatile ("outb %b0, %w1" : : "a"(val), "Nd"(port));
}

static inline U16 InU16(U16 port) {
    U16 ret;
    __asm__ volatile ("inw %w1, %w0" : "=a"(ret) : "Nd"(port));
    return ret;
}

static inline U0 OutU16(U16 port, U16 val) {
    __asm__ volatile ("outw %w0, %w1" : : "a"(val), "Nd"(port));
}

#endif
