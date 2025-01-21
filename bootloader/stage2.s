[org 0x1000]
[bits 16]

STAGE2_SIZE           equ 0x1000 ; Maximum size for Stage 2
BOOT_DRIVE            equ 0x80
FIRST_PART_OFFSET     equ 0x01BE
FAT16_PART_ID         equ 0x0E
TEMP_BLOCK            equ 0x7c00

main_stage2:
    call check_cpu
    jc .no_long_mode

    mov bx, MSG_LOADING_KERNEL
    call bios_print
    call bios_print_nl

    ; Check if INT 13h extensions are supported
    mov dl, BOOT_DRIVE
    call check_int13_ext

    ; Get MBR
    mov dl, BOOT_DRIVE
    mov ecx, 0x00
    mov ax, 0x01
    mov ebx, TEMP_BLOCK
    call read_disk_lba

    ; Check if first partition is FAT16
    mov si, FIRST_PART_OFFSET
    cmp byte [TEMP_BLOCK + si + 4], FAT16_PART_ID ; Partition type is at byte 4 of the entry
    jne .invalid_boot_part

    ; Get LBA address of FAT16 partition start
    mov ecx, [TEMP_BLOCK + si + 8]
    mov [FAT16_START_SECTOR], ecx 

    ; Read the BPB
    mov dl, BOOT_DRIVE
    mov ecx, [FAT16_START_SECTOR]
    mov ax, 0x01
    mov ebx, TEMP_BLOCK
    call read_disk_lba

    ; Read first FAT
    mov dl, BOOT_DRIVE
    movzx ecx, word [TEMP_BLOCK + 0x0E] ; Reserved sectors, 2 bytes
    add ecx, [FAT16_START_SECTOR]
    mov ax, 0x01
    mov ebx, TEMP_BLOCK
    call read_disk_lba

    ; TEMP_BLOCK now contains the first sector of the first FAT

    ; Prepare for long mode and jump to kernel
    mov bx, MSG_LONG_MODE
    call bios_print
    call bios_print_nl

    mov edi, 0x9000
    call enter_long_mode
    
    jmp $                        ; Shouldn't get here

.invalid_boot_part:
    mov bx, MSG_INVALID_PART
    call bios_print
    call bios_print_nl
    jmp .die
.no_long_mode:
    mov bx, MSG_NO_LONG_MODE
    call bios_print
    call bios_print_nl
.die:
    hlt
    jmp $

%include "bootloader/bios_print.s"
%include "bootloader/disk.s"
%include "bootloader/long_mode.s"
%include "bootloader/vga_print.s"

[bits 64]
LONG_MODE:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    call vga_clear

    ; jmp KERNEL_OFFSET

    jmp $

; Variables
FAT16_START_SECTOR  dw 0x0000
; Messages
MSG_LOADING_KERNEL  db "Loading kernel from boot partition...", 0
MSG_INVALID_PART    db "Invalid boot partition 1...", 0
MSG_LONG_MODE       db "Entering long mode...", 0
MSG_NO_LONG_MODE    db "Long mode not supported", 0

; Pad stage 2
times STAGE2_SIZE - ($ - $$) db 0
