; ----------------------------------------------------------------------------------------
; To assemble and run:
;
;     nasm -felf64 sudoku.asm && ld sudoku.o && ./a.out
; ----------------------------------------------------------------------------------------
%define     keycode_Q 81

%define     sys_read  0
%define     sys_exit  60

%define     fd_stdin  0

            global    _start

            section   .text
_start:
            mov       rax, sys_read           ; system call for read
            mov       rdi, fd_stdin           ; file handle 0 is stdin
            mov       rsi, buffer             ; address of buffer
            mov       rdx, 1                  ; number of bytes to read
            syscall                           ; invoke operating system to do the read
            movzx     rdi, byte [buffer]      ; the byte that was read
            cmp       rdi, keycode_Q          ; compare entered key with quit symbol
            je        exit                    ; exit
            jmp       _start                  ; continue loop

exit:
            mov       rdi, 0                  ; store read exit code
            mov       rax, sys_exit           ; system call for exit
            syscall                           ; invoke operating system to exit

            section   .bss
buffer:     resb      1