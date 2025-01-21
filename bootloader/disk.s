; https://wiki.osdev.org/Disk_access_using_the_BIOS_(INT_13h)#LBA_in_Extended_Mode
; Params:
;   dl => drive
; Returns:
;   halts if unsupported
check_int13_ext:
    mov ah, 0x41
    mov bx, 0x55AA
    int 0x13
    jc .ext_unsupported
    ret

.ext_unsupported:
    mov bx, MSG_EXT_UNSUPPORTED
    call bios_print
    call bios_print_nl
    jmp $

; https://wiki.osdev.org/Disk_access_using_the_BIOS_(INT_13h)#LBA_in_Extended_Mode
; Params:
;   dl => drive
;   ecx => starting sector
;   ax => sectors to read
;   ebx => address to write to
; Returns:
;   halts program if read failed 
read_disk_lba:
    mov [LBA_PACKET.block_count], ax
    mov [LBA_PACKET.lba_value], ecx
    mov [LBA_PACKET.transfer_buffer], ebx
    mov si, LBA_PACKET

    mov ah, 0x42
    int 0x13
    jc .read_error

    ret

.read_error:
    mov bx, MSG_READ_ERROR
    call bios_print
    call bios_print_nl
    jmp $

align 4
LBA_PACKET:
    .packet_size        db 0x10
    .reserved           db 0x00
    .block_count        dw 0x00
    .transfer_buffer    dd 0x00
    .lba_value          dq 0x00

MSG_EXT_UNSUPPORTED db "INT 13h extensions unsupported", 0
MSG_READ_ERROR      db "Failed to read from disk", 0