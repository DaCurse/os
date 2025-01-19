[bits 64]
[extern _start] ; Define calling point. 
call _start ; Calls the C function. The linker will know where it is placed in memory
jmp $
