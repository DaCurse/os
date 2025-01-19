[org 0x7c00]
BITS 16

STAGE2_OFFSET equ 0x1000                    ; Address to load Stage 2 bootloader
STAGE2_SECTORS equ STAGE2_OFFSET / 512      ; Number of sectors for Stage 2

main:
    jmp 0x0000:.flush_cs
.flush_cs:
    xor ax, ax

    ; Set up segment registers.
    mov ss, ax
    ; Set up stack so that it starts below Main.
    mov sp, main
    
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    cld

    mov [BOOT_DRIVE], dl    ; Save boot drive from BIOS

    ; Load Stage 2 bootloader into memory at STAGE2_OFFSET (0x1000)
    mov ah, 0x02            ; BIOS read sectors function
    mov al, STAGE2_SECTORS  ; Number of sectors to read
    mov ch, 0               ; Cylinder 0
    mov cl, 2               ; Sector 2 (Stage 2 starts at sector 2)
    mov dh, 0               ; Head 0
    mov dl, [BOOT_DRIVE]    ; Use the boot drive
    mov bx, STAGE2_OFFSET   ; Load address
    int 0x13                ; BIOS interrupt to read disk

    jc .error                ; Jump if carry flag is set (disk error)

    ; Jump to Stage 2 bootloader
    jmp STAGE2_OFFSET

.error:
    hlt                     ; Halt the CPU on error

BOOT_DRIVE db 0

; Boot signature
times 510 - ($ - $$) db 0   ; Pad to 510 bytes
dw 0xAA55                   ; Boot signature
