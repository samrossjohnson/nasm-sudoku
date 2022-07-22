; ----------------------------------------------------------------------------------------
; To assemble and run:
;
;     nasm -felf64 text-editor.asm && ld text-editor.o && ./a.out
; ----------------------------------------------------------------------------------------

            global    _start

            section   .text

_start:     mov       rdi, 0                  ; store exit code
            mov       rax, 60                 ; system call for exit
            syscall                           ; invoke operating system to exit