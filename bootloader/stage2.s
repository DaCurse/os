[org 0x1000]
BITS 16

KERNEL_OFFSET equ 0x2000                           ; Offset to load the kernel into memory
KERNEL_SIZE equ 0x1000                             ; Maximum size of kernel
KERNEL_START_SECTOR equ \
    ((KERNEL_OFFSET - KERNEL_SIZE) / 512) +  2     ; Sector # where the kernel starts at
KERNEL_SECTORS equ KERNEL_SIZE / 512               ; Number of sectors for kernel

main_stage2:
    mov bx, MSG_STAGE2
    call bios_print
    call bios_print_nl

    call check_cpu
    jc .no_long_mode

    ; Load kernel into memory at KERNEL_OFFSET (0x2000)
    mov bx, KERNEL_OFFSET
    mov dh, KERNEL_SECTORS       ; Number of sectors to read
    mov dl, [BOOT_DRIVE]         ; Use the boot drive
    mov cl, KERNEL_START_SECTOR  ; Starting sector
    call disk_load

    ; Prepare for long mode and jump to kernel
    mov edi, 0x9000
    call enter_long_mode
    
    jmp $                        ; Shouldn't get here

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

BOOT_DRIVE          db 0x80 ; HDD1
MSG_STAGE2          db "Entering long mode...", 0
MSG_NO_LONG_MODE    db "Long mode not supported", 0

; Pad the code to ensure the kernel appears right after the 2nd stage
times (KERNEL_OFFSET - KERNEL_SIZE) - ($ - $$) db 0
