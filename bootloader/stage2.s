[org 0x1000]
[bits 16]

; Constants
STAGE2_SIZE           equ 0x1000            ; Maximum size for Stage 2
FREE_SPACE            equ 0x9000            ; 
BOOT_DRIVE            equ 0x80              ; HDD1
FIRST_PART_OFFSET     equ 0x01BE            ; Offset for first partition in partition table
FAT16_PART_ID         equ 0x0E              ; ID for FAT16 partitions
MBR_ADDRESS           equ 0x7C00            ; Address of the MBR
TEMP_BLOCK            equ $$ + STAGE2_SIZE  ; Free memory right after Stage 2

main_stage2:
    call check_cpu
    jc .no_long_mode

    mov si, MSG_LOADING_KERNEL
    call bios_print
    call bios_print_nl

    ; Check if INT 13h extensions are supported
    mov dl, BOOT_DRIVE
    call check_int13_ext

    ; Check if first partition is FAT16
    mov si, FIRST_PART_OFFSET
    cmp byte [MBR_ADDRESS + si + 4], FAT16_PART_ID ; Partition type is at byte 4 of the entry
    jne .invalid_boot_part

    ; Get LBA address of FAT16 partition start
    mov ecx, [MBR_ADDRESS + si + 8]
    mov [FAT16_START_SECTOR], ecx 

    ; Read the BPB
    mov dl, BOOT_DRIVE
    mov ecx, [FAT16_START_SECTOR]
    mov ax, 0x01
    mov ebx, TEMP_BLOCK
    call read_disk_lba

    ; Get the fields we need from the BPB
    mov ax, [TEMP_BLOCK + 0x0B]
    mov [BPB.bytes_per_sector], ax
    mov al, [TEMP_BLOCK + 0x0D]
    mov [BPB.sectors_per_cluster], al
    mov ax, [TEMP_BLOCK + 0x0E]
    mov [BPB.reserved_sector_count], ax
    mov al, [TEMP_BLOCK + 0x10]
    mov [BPB.table_count], al
    mov ax, [TEMP_BLOCK + 0x11]
    mov [BPB.root_entry_count], ax
    mov ax, [TEMP_BLOCK + 0x16]
    mov [BPB.table_size_16], ax

    ; Calculate root dir sector
    ; https://wiki.osdev.org/FAT#Reading_Directories

    ; root_dir_sectors = ((fat_boot->root_entry_count * 32) + (fat_boot->bytes_per_sector - 1)) / fat_boot->bytes_per_sector;
    mov ax, [BPB.root_entry_count]
    mov bx, 32
    mul bx
    mov bx, [BPB.bytes_per_sector]
    dec bx
    add ax, bx
    mov bx, [BPB.bytes_per_sector]
    div bx
    mov [ROOT_DIR_SECTORS], ax

    ; first_data_sector = fat_boot->reserved_sector_count + (fat_boot->table_count * fat_size) + root_dir_sectors;
    mov ax, [BPB.table_count]
    mul word [BPB.table_size_16]
    add ax, word [BPB.reserved_sector_count]
    add ax, word [ROOT_DIR_SECTORS]
    mov [FIRST_DATA_SECTOR], ax

    ; first_root_dir_sector = first_data_sector - root_dir_sectors;
    sub ax, [ROOT_DIR_SECTORS]
    mov [FIRST_ROOT_DIR_SECTOR], ax

    ; Read first root directory sector
    ; For simplicity we will only look in the first sector, 
    ; which would search in 16 (standard) or 8 (long file name) entries
    mov dl, BOOT_DRIVE
    movzx ecx, word [FAT16_START_SECTOR]
    movzx ebx, word [FIRST_ROOT_DIR_SECTOR]
    add ecx, ebx
    mov ax, 0x01
    mov ebx, TEMP_BLOCK
    call read_disk_lba

    ; TEMP_BLOCK now contains the first sector of the root directory
    mov si, TEMP_BLOCK
.process_entry:
    ; Check if there are no more entries
    mov al, [si]
    cmp al, 0
    je  .no_more_entries
    ; Check for long file entry
    mov al, [si + 0x0B] 
    cmp al, 0x0F
    jne .standard_entry
    ; Skip long file entry
    add si, 0x20
.standard_entry:
    ; Store si for the current iteration
    push si
    ; si points to the 8.3 file name
    lea di, KERNEL_FILE_NAME
    mov cx, FILE_NAME_LENGTH
    ; Print filename for debugging
    call bios_print_n
    call bios_print_nl
    ; Comapre es:di with ds:si
    repe cmpsb
    jne .skip_entry
    jmp .kernel_found

.skip_entry:
    ; Restore si
    pop si
    ; Go to next entry
    add si, 0x20
    jmp .process_entry

.no_more_entries:
    ; Kernel wasn't found in the first sector
    mov si, MSG_NO_KERNEL
    call bios_print
    call bios_print_nl
    jmp .die

.kernel_found:
    ; Restore si
    pop si
    ; Kernel entry was found, si now points to it (skipping long name entry)

    ; Get the first cluster number of the file
    mov ax, [si + 0x1A]
    ; Calculate the first sector
    ; first_sector_of_cluster = ((cluster - 2) * fat_boot->sectors_per_cluster) + first_data_sector;
    sub ax, 2
    movzx bx, byte [BPB.sectors_per_cluster]
    mul bx
    add ax, [FIRST_DATA_SECTOR]

    ; Read 8 sectors for kernel
    ; TODO: Properly read kernel by implementing cluster chain following algorithm
    mov dl, BOOT_DRIVE
    movzx ecx, ax
    movzx ebx, word [FAT16_START_SECTOR]
    add ecx, ebx
    mov ax, 0x08
    mov ebx, TEMP_BLOCK
    call read_disk_lba

    ; Print first 2 bytes of kernel for debugging
    mov dx, [TEMP_BLOCK]
    call bios_print_hex
    call bios_print_nl

    ; Prepare for long mode and jump to kernel
    mov si, MSG_LONG_MODE
    call bios_print
    call bios_print_nl

    mov edi, FREE_SPACE
    call enter_long_mode
    
    ; Shouldn't get here
    jmp $

.invalid_boot_part:
    mov si, MSG_INVALID_PART
    call bios_print
    call bios_print_nl
    jmp .die
.no_long_mode:
    mov si, MSG_NO_LONG_MODE
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

    jmp TEMP_BLOCK

    jmp $

; Variables
; https://wiki.osdev.org/FAT#BPB_(BIOS_Parameter_Block)
BPB:
    .bytes_per_sector       dw  0x0000
    .sectors_per_cluster    db  0x00
    .reserved_sector_count  dw  0x0000
    .table_count            db  0x00
    .root_entry_count       dw  0x0000
    .table_size_16          dw  0x0000

; Intermediate variables to calculate FAT16 properties
FAT16_START_SECTOR      dw 0x0000
ROOT_DIR_SECTORS        dw 0x0000
FIRST_DATA_SECTOR       dw 0x0000
FIRST_ROOT_DIR_SECTOR   dw 0x0000

; 8.3 file name. The first 8 characters are the name and the last 3 are the extension.
KERNEL_FILE_NAME    db  "KERNEL  BIN"
FILE_NAME_LENGTH    equ $ - KERNEL_FILE_NAME

; Messages
MSG_LOADING_KERNEL  db "Loading kernel from boot partition...", 0
MSG_INVALID_PART    db "Invalid boot partition 1...", 0
MSG_NO_KERNEL       db "KERNEL.BIN not found", 0
MSG_LONG_MODE       db "Entering long mode...", 0
MSG_NO_LONG_MODE    db "Long mode not supported", 0

; Pad stage 2
times STAGE2_SIZE - ($ - $$) db 0
