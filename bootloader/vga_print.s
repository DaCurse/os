[bits 64] ; Using Long Mode

VIDEO_MEMORY equ 0xb8000
WHITE_ON_BLACK equ 0x0f ; the color byte for each character

; Params:
;   rdi => address to the string
; Returns:
;   nothing
vga_print:
    push rsi                ; Save rsi
    push rdi                ; Save rdi (the address of the string)

    mov rsi, VIDEO_MEMORY   ; rsi now points to the starting address of video memory

.loop:
    mov al, [rdi]           ; rdi holds the address of the character string
    mov ah, WHITE_ON_BLACK  ; Set the attribute byte (foreground on black background)

    cmp al, 0               ; Check if end of string (null-terminated string)
    je .done                ; If yes, we jump to done

    mov [rsi], ax           ; Store character + attribute in video memory
    inc rdi                 ; Move to the next character in the string
    add rsi, 2              ; Move to the next video memory position (each character takes 2 bytes)

    jmp .loop               ; Loop again

.done:
    pop rdi                 ; Restore rdi
    pop rsi                 ; Restore rsi
    ret                     ; Return from the subroutine

; Params:
;   nothing
; Returns:
;   nothing
vga_clear:
    ; Set the base address for video memory
    mov edi, VIDEO_MEMORY       ; Video memory starting address
    mov rcx, 500                ; Screen has 80 * 25 = 2000 characters, each 2 bytes (character + attribute)
    
    ; Set the value to white foreground on black background
    mov rax, 0x0F20
    
    ; Fill the entire screen using rep stosq (store quadword)
    rep stosq                   ; Repeat store quadword for `rcx` iterations
    
    ret
