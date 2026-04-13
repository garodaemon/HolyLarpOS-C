#include "holyc_compat.h"

extern U8* malloc(I64 size);
extern I64 larp_strcmp(U8 *s1, U8 *s2);
extern U0 print_string(U8 *str, I64 x, I64 y, U8 color);

typedef struct {
    U8 name[32];
    U8* content;
    I64 size;
} larp_file;

larp_file fs_root[16];
I64 fs_file_count = 0;

U0 larpfs_add_file(U8 *filename, U8 *data) {
    if (fs_file_count >= 16) return;

    I64 i = 0;
    while (filename[i] != '\0' && i < 31) {
        fs_root[fs_file_count].name[i] = filename[i];
        i++;
    }
    fs_root[fs_file_count].name[i] = '\0';

    I64 len = 0;
    while (data[len] != '\0') {
        len++;
    }

    fs_root[fs_file_count].content = malloc(len + 1);

    I64 j = 0;
    while (j < len) {
        fs_root[fs_file_count].content[j] = data[j];
        j++;
    }
    fs_root[fs_file_count].content[j] = '\0';
    fs_root[fs_file_count].size = j;
    
    fs_file_count++;
}

U0 larpfs_init() {
    larpfs_add_file("notlar.txt", "Larplando 0.3 Dosya Sistemi Calisiyor.");
    larpfs_add_file("readme.md", "LarpOS C Edition - Larplando");
    larpfs_add_file("sifreler.txt", "admin:123456");
    larpfs_add_file("supporters", "Xyl, /home/kali_linx, Diavolo, turkdogru");
}

I64 larpfs_find(U8 *filename) {
    I64 i;
    for (i = 0; i < fs_file_count; i++) {
        if (larp_strcmp(fs_root[i].name, filename) == 1) {
            return i;
        }
    }
    return -1;
}

U8* larpfs_get_content(I64 index) {
    if (index >= 0 && index < fs_file_count) {
        return fs_root[index].content;
    }
    return 0;
}

U8* larpfs_get_name(I64 index) {
    if (index >= 0 && index < fs_file_count) {
        return fs_root[index].name;
    }
    return 0;
}

I64 larpfs_get_count() {
    return fs_file_count;
}
