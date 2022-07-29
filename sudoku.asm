; ----------------------------------------------------------------------------------------
; To assemble and run:
;
;     nasm -felf64 sudoku.asm && ld sudoku.o && ./a.out
; ----------------------------------------------------------------------------------------
%define     keycode_Q 81

%define     sys_read  0
%define     sys_ioctl 16
%define     sys_exit  60

%define     fd_stdin  0

%define     tcgets    0x5401
%define     tcsets    0x5402
%define     icanon    1<<1
%define     echo      1<<3

            global    _start

            section   .text
_start:
            call      init_term
            mov       rax, sys_read           ; system call for read
            mov       rdi, fd_stdin           ; file handle 0 is stdin
            mov       rsi, input              ; address of buffer
            mov       rdx, 1                  ; number of bytes to read
            syscall                           ; invoke OS to do the read
            movzx     rdi, byte [input]       ; the byte that was read
            cmp       rdi, keycode_Q          ; compare entered key with quit symbol
            je        exit                    ; exit
            jmp       _start                  ; continue loop

exit:
            call      reset_term
            mov       rdi, 0                  ; store read exit code
            mov       rax, sys_exit           ; system call for exit
            syscall                           ; invoke operating system to exit

init_term:
            mov       rax, sys_ioctl          ; system call for ioctl
            mov       rdi, fd_stdin           ; file descriptor
            mov       rsi, tcgets             ; request to get terminal attributes
            mov       rdx, termios            ; buffer to write into
            syscall                           ; invoke the OS to read termios

            and       byte [c_lflag], ~echo   ; disable echo
            and       byte [c_lflag], ~icanon ; disable canonical mode

            mov       rax, sys_ioctl          ; system call for ioctl
            mov       rdi, fd_stdin           ; file descriptor
            mov       rsi, tcsets             ; request number
            mov       rdx, termios            ; termios stucture to write
            syscall                           ; invoke the OS to write termios
            ret

reset_term:
            mov       rax, sys_ioctl          ; system call for ioctl
            mov       rdi, fd_stdin           ; file descriptor
            mov       rsi, tcgets             ; request to get terminal attributes
            mov       rdx, termios            ; buffer to write into
            syscall                           ; invoke the OS to read termios

            or        byte [c_lflag], echo    ; disable echo
            or        byte [c_lflag], icanon  ; disable canonical mode

            mov       rax, sys_ioctl          ; system call for ioctl
            mov       rdi, fd_stdin           ; file descriptor
            mov       rsi, tcsets             ; request number
            mov       rdx, termios            ; termios stucture to write
            syscall                           ; invoke the OS to write termios
            ret

            section   .bss
input:      resb      1                       ; buffer used to read input
termios:
c_iflag     resd      1                       ; input mode flags
c_oflag     resd      1                       ; output mode flags
c_cflag     resd      1                       ; control mode flags
c_lflag     resd      1                       ; local mode flags
c_line      resb      1                       ; line discipline
c_cc        resb      19                      ; control characters