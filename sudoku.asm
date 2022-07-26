; ----------------------------------------------------------------------------------------
; To assemble and run:
;
;     nasm -felf64 sudoku.asm && ld sudoku.o && ./a.out
; ----------------------------------------------------------------------------------------

            global    _start

            section   .text
keycode_Q:  equ       81

_start:     mov       rax, 0                  ; system call for read
            mov       rdi, 0                  ; file handle 0 is stdin
            mov       rsi, buffer             ; address of buffer
            mov       rdx, 1                  ; number of bytes to read
            syscall                           ; invoke operating system to do the read
            movzx     rdi, byte [buffer]      ; the byte that was read
            cmp       rdi, keycode_Q          ; compare entered key with quit symbol
            je        exit                    ; exit
            jmp       _start                  ; continue loop

exit:       mov       rdi, 0                  ; store read exit code
            mov       rax, 60                 ; system call for exit
            syscall                           ; invoke operating system to exit

            section   .bss
buffer:     resb      1