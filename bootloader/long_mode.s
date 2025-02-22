; Checks whether CPU supports long mode or not.
; Returns with carry set if CPU doesn't support long mode.
check_cpu:
    ; Check whether CPUID is supported or not.
    pushfd ; Get flags in EAX register.
    
    pop eax
    mov ecx, eax  
    xor eax, 0x200000 
    push eax 
    popfd

    pushfd 
    pop eax
    xor eax, ecx
    shr eax, 21 
    and eax, 1 ; Check whether bit 21 is set or not. If EAX now contains 0, CPUID isn't supported.
    push ecx
    popfd 

    test eax, eax
    jz .no_long_mode
    
    mov eax, 0x80000000   
    cpuid                 
    
    cmp eax, 0x80000001 ; Check whether extended function 0x80000001 is available are not.
    jb .no_long_mode ; If not, long mode not supported.

    mov eax, 0x80000001  
    cpuid                 
    test edx, 1 << 29 ; Test if the LM-bit, is set or not.
    jz .no_long_mode ; If not Long mode not supported.

    ret

.no_long_mode:
    stc
    ret

%define PAGE_PRESENT    (1 << 0)
%define PAGE_WRITE      (1 << 1)

%define CODE_SEG     0x0008
%define DATA_SEG     0x0010

; Function to switch directly to long mode from real mode.
; Identity maps the first 2MiB.
; Params:
;   es:edi => Should point to a valid page-aligned 16KiB buffer, for the PML4, PDPT, PD and a PT.
;   ss:esp => Should point to memory that can be used as a small (1 uint32_t) stack
enter_long_mode:
    ; Zero out the 16KiB buffer.
    ; Since we are doing a rep stosd, count should be bytes/4.   
    push di                           ; REP STOSD alters DI.
    mov ecx, 0x1000
    xor eax, eax
    cld
    rep stosd
    pop di                            ; Get DI back.

    ; Build the Page Map Level 4.
    ; es:di points to the Page Map Level 4 table.
    lea eax, [es:di + 0x1000]         ; Put the address of the Page Directory Pointer Table in to EAX.
    or eax, PAGE_PRESENT | PAGE_WRITE ; Or EAX with the flags - present flag, writable flag.
    mov [es:di], eax                  ; Store the value of EAX as the first PML4E.

    ; Build the Page Directory Pointer Table.
    lea eax, [es:di + 0x2000]         ; Put the address of the Page Directory in to EAX.
    or eax, PAGE_PRESENT | PAGE_WRITE ; Or EAX with the flags - present flag, writable flag.
    mov [es:di + 0x1000], eax         ; Store the value of EAX as the first PDPTE.

    ; Build the Page Directory.
    lea eax, [es:di + 0x3000]         ; Put the address of the Page Table in to EAX.
    or eax, PAGE_PRESENT | PAGE_WRITE ; Or EAX with the flags - present flag, writeable flag.
    mov [es:di + 0x2000], eax         ; Store to value of EAX as the first PDE.
    
    push di                           ; Save DI for the time being.
    lea di, [di + 0x3000]             ; Point DI to the page table.
    mov eax, PAGE_PRESENT | PAGE_WRITE    ; Move the flags into EAX - and point it to 0x0000.


; Build the Page Table.
.loop_page_table:
    mov [es:di], eax
    add eax, 0x1000
    add di, 8
    cmp eax, 0x200000                 ; If we did all 2MiB, end.
    jb .loop_page_table

    pop di                            ; Restore DI.
    
    ; Disable IRQs
    mov al, 0xFF                      ; Out 0xFF to 0xA1 and 0x21 to disable all IRQs.
    out 0xA1, al
    out 0x21, al
    
    nop
    nop

    lidt [IDT]                        ; Load a zero length IDT so that any NMI causes a triple fault.

    ; Enter long mode.
    mov eax, 10100000b                ; Set the PAE and PGE bit.
    mov cr4, eax
      
    mov edx, edi                      ; Point CR3 at the PML4.
    mov cr3, edx
      
    mov ecx, 0xC0000080               ; Read from the EFER MSR. 
    rdmsr    

    or eax, 0x00000100                ; Set the LME bit.
    wrmsr
      
    mov ebx, cr0                      ; Activate long mode -
    or ebx,0x80000001                 ; - by enabling paging and protection simultaneously.
    mov cr0, ebx                    

    lgdt [GDT.pointer]                ; Load GDT.Pointer defined below.
      
    jmp CODE_SEG:LONG_MODE            ; Load CS with 64 bit segment and flush the instruction cache

ALIGN 4
IDT:
    .Length       dw 0
    .Base         dd 0

; Global Descriptor Table
GDT:
.null:
    dq 0x0000000000000000             ; Null Descriptor - should be present.

.code:
    dq 0x00209A0000000000             ; 64-bit code descriptor (exec/read).
    dq 0x0000920000000000             ; 64-bit data descriptor (read/write).
      
ALIGN 4
    dw 0                              ; Padding to make the "address of the GDT" field aligned on a 4-byte boundary

.pointer:
    dw $ - GDT - 1                    ; 16-bit Size (Limit) of GDT.
    dd GDT                            ; 32-bit Base Address of GDT. (CPU will zero extend to 64-bit)

