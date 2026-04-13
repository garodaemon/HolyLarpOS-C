#include "holyc_compat.h"

extern U0 ata_read_sector(U32 lba, U8 *buf);
extern U0 ata_write_sector(U32 lba, U8 *buf);

__asm__(
".section .text.entry\n"
".global _ENTRY\n"
"_ENTRY:\n"
"    mov $0x10, %ax\n"
"    mov %ax, %ds\n"
"    mov %ax, %es\n"
"    mov %ax, %fs\n"
"    mov %ax, %gs\n"
"    mov %ax, %ss\n"
"    mov $0x90000, %esp\n"
"    call kernel_main\n"
"    jmp .\n"
".global _IRQ0_HANDLER\n"
"_IRQ0_HANDLER:\n"
"    pusha\n"
"    call timer_handler\n"
"    popa\n"
"    iret\n"
".global _IRQ1_HANDLER\n"
"_IRQ1_HANDLER:\n"
"    pusha\n"
"    call keyboard_handler\n"
"    popa\n"
"    iret\n"
".global _SYSCALL_HANDLER\n"
"_SYSCALL_HANDLER:\n"
"    pusha\n"
"    call syscall_handler_c\n"
"    popa\n"
"    iret\n"
);

U0 clear_screen();
U0 move_cursor(I64 x, I64 y);
I64 larp_strcmp(U8 *str1, U8 *str2);
extern U0 _IRQ0_HANDLER();
extern U0 _IRQ1_HANDLER();
extern U0 _SYSCALL_HANDLER();

U0 print_char(U8 c, I64 x, I64 y, U8 color) {
    U8 *video = (U8*)0xB8000;
    I64 offset = (y * 80 + x) * 2;
    video[offset] = c;
    video[offset + 1] = color;
}

U0 print_string(U8 *str, I64 x, I64 y, U8 color) {
    I64 i = 0;
    while (str[i] != '\0') {
        print_char(str[i], x + i, y, color);
        i++;
    }
}

U0 clear_screen() {
    I64 x, y;
    for (y = 0; y < 25; y++) {
        for (x = 0; x < 80; x++) {
            print_char(' ', x, y, 0x0E);
        }
    }
}

U8 inb(U16 port) { return InU8(port); }
U0 outb(U16 port, U8 data) { OutU8(port, data); }
U16 inw(U16 port) { return InU16(port); }
U0 outw(U16 port, U16 data) { OutU16(port, data); }

U0 move_cursor(I64 x, I64 y) {
    U16 pos = y * 80 + x;
    outb(0x3D4, 0x0F);
    outb(0x3D5, pos & 0xFF);
    outb(0x3D4, 0x0E);
    outb(0x3D5, (pos >> 8) & 0xFF);
}

I64 larp_strcmp(U8 *str1, U8 *str2) {
    I64 i = 0;
    while (str1[i] == str2[i]) {
        if (str1[i] == '\0') return 1;
        i++;
    }
    return 0;
}

typedef struct __attribute__((packed)) {
    U16 limit_low;
    U16 base_low;
    U8 base_middle;
    U8 access;
    U8 granularity;
    U8 base_high;
} gdt_entry;

typedef struct __attribute__((packed)) {
    U16 limit;
    U32 base;
} gdt_ptr;

gdt_entry gdt[5];
gdt_ptr gp;

U0 gdt_set_gate(I64 num, U64 base, U64 limit, U8 access, U8 gran) {
    gdt[num].base_low = base & 0xFFFF;
    gdt[num].base_middle = (base >> 16) & 0xFF;
    gdt[num].base_high = (base >> 24) & 0xFF;
    gdt[num].limit_low = limit & 0xFFFF;
    gdt[num].granularity = (limit >> 16) & 0x0F;
    gdt[num].granularity |= gran & 0xF0;
    gdt[num].access = access;
}

U0 gdt_install() {
    gp.limit = (sizeof(gdt_entry) * 5) - 1;
    gp.base = (U32)&gdt;
    gdt_set_gate(0, 0, 0, 0, 0);
    gdt_set_gate(1, 0, 0xFFFFFFFF, 0x9A, 0xCF);
    gdt_set_gate(2, 0, 0xFFFFFFFF, 0x92, 0xCF);
    gdt_set_gate(3, 0, 0xFFFFFFFF, 0xFA, 0xCF);
    gdt_set_gate(4, 0, 0xFFFFFFFF, 0xF2, 0xCF);
    SetGDT(&gp); 
}

typedef struct __attribute__((packed)) {
    U16 base_low;
    U16 sel;
    U8 always0;
    U8 flags;
    U16 base_high;
} idt_entry;

typedef struct __attribute__((packed)) {
    U16 limit;
    U32 base;
} idt_ptr;

idt_entry idt[256];
idt_ptr idtp;

U0 idt_set_gate(U8 num, U64 base, U16 sel, U8 flags) {
    idt[num].base_low = base & 0xFFFF;
    idt[num].base_high = (base >> 16) & 0xFFFF;
    idt[num].sel = sel;
    idt[num].always0 = 0;
    idt[num].flags = flags;
}

U0 pic_remap() {
    outb(0x20, 0x11);
    outb(0xA0, 0x11);
    outb(0x21, 0x20);
    outb(0xA1, 0x28);
    outb(0x21, 0x04);
    outb(0xA1, 0x02);
    outb(0x21, 0x01);
    outb(0xA1, 0x01);
    outb(0x21, 0x00);
    outb(0xA1, 0x00);
}

U0 idt_install() {
    I64 i;
    idtp.limit = (sizeof(idt_entry) * 256) - 1;
    idtp.base = (U32)&idt;
    for (i = 0; i < 256; i++) {
        idt_set_gate(i, 0, 0, 0);
    }
    pic_remap();
    idt_set_gate(32, (U64)&_IRQ0_HANDLER, 0x08, 0x8E);
    idt_set_gate(33, (U64)&_IRQ1_HANDLER, 0x08, 0x8E);
    idt_set_gate(128, (U64)&_SYSCALL_HANDLER, 0x08, 0xEE);
    SetIDT(&idtp);
}

U32 timer_ticks = 0;
U0 timer_handler() {
    timer_ticks++;
    outb(0x20, 0x20);
}

U0 syscall_handler_c() {
    outb(0x20, 0x20);
}

U0 timer_install() {
    I64 divisor = 11931;
    outb(0x43, 0x36);
    outb(0x40, divisor & 0xFF);
    outb(0x40, divisor >> 8);
}

U8 scancode_to_ascii[128] = {
    0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
    0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,
    '*', 0, ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '7', '8', '9', '-',
    '4', '5', '6', '+', '1', '2', '3', '0', '.'
};

I64 cursor_x = 23;
I64 cursor_y = 9;
U8 input_buffer[64];
I64 buffer_index = 0;
U8 key_pressed = 0;
U8 last_scancode = 0;

U0 keyboard_handler() {
    last_scancode = inb(0x60);
    key_pressed = 1;
    outb(0x20, 0x20);
}

U32 heap_current = 0x100000;
U8* malloc(I64 size) {
    U8* ptr = (U8*)heap_current;
    heap_current += size;
    return ptr;
}
U0 free(U8* ptr) {}

U0 print_banner() {
    print_string("  _                  ____   ____  _____  _____ ", 2, 1, 0x0D);
    print_string(" | |    __ _ _ __ |  _ \\ / __ \\ / ____|  / ____|", 2, 2, 0x0D);
    print_string(" | |   / _` | '__|| |_) | |  | | (___   | |     ", 2, 3, 0x0D);
    print_string(" | |  / _` | |    |  __/| |  | |\\___ \\  | |     ", 2, 4, 0x0D);
    print_string(" | |__| (_| | |    | |   | |__| |____) | | |____ ", 2, 5, 0x0D);
    print_string(" |_____\\__,_|_|    |_|    \\____/|_____/  \\_____| 0.3", 2, 6, 0x0D);
    print_string("------------------- CODE NAME: HOLYLARP -----------------", 2, 7, 0x0E);
}

extern U0 larpfs_init();
extern I64 larpfs_find(U8 *filename);
extern U8* larpfs_get_content(I64 index);
extern U8* larpfs_get_name(I64 index);
extern I64 larpfs_get_count();
extern U0 larpfs_add_file(U8 *filename, U8 *data);
extern U0 larpfs_save_file(U8 *filename, U8 *data);

U0 execute_command() {
    input_buffer[buffer_index] = '\0';
    if (buffer_index > 0) {
        if (larp_strcmp(input_buffer, "clear") == 1) {
            clear_screen();
            cursor_y = -1;
        } else if (larp_strcmp(input_buffer, "help") == 1) {
            cursor_y++;
            print_string("cmds: help clear uname pwd ls cat mkdir lsblk reboot", 0, cursor_y, 0x0E);
        } else if (larp_strcmp(input_buffer, "uname") == 1) {
            cursor_y++;
            print_string("LarpOS C 0.3 (holylarp)", 0, cursor_y, 0x0E);
        } else if (larp_strcmp(input_buffer, "pwd") == 1) {
            cursor_y++;
            print_string("/home/garodaemon", 0, cursor_y, 0x0E);
        } else if (larp_strcmp(input_buffer, "lsblk") == 1) {
            cursor_y++;
            print_string("NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT", 0, cursor_y, 0x0E);
            cursor_y++;
            print_string("ld0       1:0    0   128M  0 disk ", 0, cursor_y, 0x0E);
            cursor_y++;
            print_string("`-ld0p1   1:1    0   128M  0 part /", 0, cursor_y, 0x0E);
        } else if (larp_strcmp(input_buffer, "ls") == 1) {
            cursor_y++;
            I64 count = larpfs_get_count();
            I64 current_x = 0;
            I64 i;
            for(i = 0; i < count; i++) {
                U8* fname = larpfs_get_name(i);
                print_string(fname, current_x, cursor_y, 0x0E);
                I64 len = 0;
                while(fname[len] != '\0') len++;
                current_x += len + 2;
                if(current_x > 60) {
                    current_x = 0;
                    cursor_y++;
                }
            }
        } else if (input_buffer[0] == 'c' && input_buffer[1] == 'a' && input_buffer[2] == 't' && input_buffer[3] == ' ') {
            U8 *fname = &input_buffer[4];
            I64 idx = larpfs_find(fname);
            cursor_y++;
            if (idx != -1) {
                print_string(larpfs_get_content(idx), 0, cursor_y, 0x0E);
            } else {
                print_string("Dosya bulunamadi.", 0, cursor_y, 0x0E);
            }
        } else if (input_buffer[0] == 'm' && input_buffer[1] == 'k' && input_buffer[2] == 'd' && input_buffer[3] == 'i' && input_buffer[4] == 'r' && input_buffer[5] == ' ') {
            U8 *dname = &input_buffer[6];
            larpfs_add_file(dname, "</home/tsukasa is larp and fraud>");
            cursor_y++;
            print_string("Klasor olusturuldu.", 0, cursor_y, 0x0E);
        } else if (larp_strcmp(input_buffer, "reboot") == 1) {
            outb(0x64, 0xFE);
        } else {
            cursor_y++;
            print_string("Command not found.", 0, cursor_y, 0x0E);
        }
    }
    buffer_index = 0;
}

U0 run_terminal() {
    if (!key_pressed) {
        Hlt;
        return;
    }
    key_pressed = 0;
    U8 scancode = last_scancode;
    if (scancode & 0x80) return;
    
    if (scancode < 128) {
        U8 c = scancode_to_ascii[scancode];
        if (c == '\n') {
            execute_command();
            cursor_y++;
            if (cursor_y >= 25) {
                clear_screen();
                cursor_y = 0;
            }
            cursor_x = 0;
            print_string("garodaemon@holylarp:~$ ", cursor_x, cursor_y, 0x0E);
            cursor_x = 23;
        } else if (c == '\b') {
            if (cursor_x > 23 && buffer_index > 0) {
                cursor_x--;
                buffer_index--;
                print_char(' ', cursor_x, cursor_y, 0x0E);
            }
        } else if (c != 0 && buffer_index < 63) {
            input_buffer[buffer_index] = c;
            buffer_index++;
            print_char(c, cursor_x, cursor_y, 0x0E);
            cursor_x++;
            if (cursor_x >= 80) {
                cursor_x = 0;
                cursor_y++;
            }
        }
        move_cursor(cursor_x, cursor_y);
    }
}

U0 kernel_main() {
    clear_screen();
    print_banner();
    gdt_install();
    idt_install();
    timer_install();
    larpfs_init();
    Sti;
    print_string("garodaemon@holylarp:~$ ", 0, 9, 0x0E);
    move_cursor(23, 9);
    while (1) {
        run_terminal();
    }
}
