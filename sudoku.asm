; ----------------------------------------------------------------------------------------
; To assemble and run:
;
;     nasm -felf64 sudoku.asm && ld sudoku.o && ./a.out
; ----------------------------------------------------------------------------------------
%define     keycode_Q 81

%define     sys_read  0
%define     sys_write 1
%define     sys_ioctl 16
%define     sys_exit  60

%define     fd_stdin  0
%define     fd_stdout 1

%define     tcgets    0x5401
%define     tcsets    0x5402
%define     icanon    1<<1
%define     echo      1<<3

%define     row_chars 38                      ; number of characters in a row including decorations
%define     num_rows  9                       ; number of rows in the sudoku grid
%define     num_cols  9                       ; number of columns in the sudoku grid

            global    _start

            section   .text
_start:
            call      generate_sudoku
            call      init_term
game_loop:
            call      draw_grid

            mov       rdi, input              ; buffer address for get_key
            call      get_key
            cmp       rax, keycode_Q          ; compare entered key with quit symbol
            je        exit                    ; exit
            jmp       game_loop               ; continue loop

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

; ==== GET KEY FUNCTION ====
; function to read a single key from the standard input
; input rdi: address of single byte buffer in which to store the read character
; output rax: the charater that was read. '0' if no character was read
; modifies: rax, rdx, rsi, rdi
get_key:
            mov       rsi, rdi                ; address of read buffer
            mov       rax, sys_read           ; system call for read
            mov       rdi, fd_stdin           ; file handle 0 is stdin
            mov       rdx, 1                  ; number of bytes to read
            syscall                           ; invoke OS to do the read
            dec       rax                     ; dec read count, if was 1 then 0 flag gets set
            jz        .return
            mov       byte [rsi], '0'
.return:
            mov       al, [rsi]               ; move read character to output
            ret
; ==== END GET KEY FUNCTION ====

; ==== DRAW GRID FUNCTION ====
; function to draw the sudoku grid to stdout
draw_grid:
            mov       r8, 0                   ; number of rows draw so far
draw_loop:
            call      draw_row_split          ; draw decorative row split
            mov       rdi, r8
            call      draw_row_content        ; draw content for row
            inc       r8                      ; row finished, increase counter
            cmp       r8, num_rows            ; compare for row limit
            jl        draw_loop               ; loop if not at limit
            call      draw_row_split          ; closing decorative row split
            ret                               ; end function
; ==== END DRAW GRID FUNCTION ====

; ==== DRAW ROW SPLIT FUNCTION ====
; function to decorative line between rows for the sudoku grid
draw_row_split:
            mov       rax, sys_write          ; code for write syscall
            mov       rdi, fd_stdout          ; write to stdout (terminal)
            mov       rsi, row_split          ; buffer to write out
            mov       rdx, row_chars          ; number of bytes to write
            syscall                           ; invoke OS to write
            ret                               ; end function
; ==== END DRAW ROW CONTENT FUNCTION ====

; ==== DRAW ROW CONTENT FUNCTION ====
; param rdi: the row to draw
; function to draw all columns of a row in the sudoku grid.   
draw_row_content:
            mov       r9, 0                   ; number of columns drawn so far
            mov       r10, rdi                ; store the row in r10
            mov       rdx, write              ; put start of write buffer into rdx
content_loop:
            mov       byte [rdx], '|'         ; decorative character
            inc       rdx                     ; next byte
            mov       byte [rdx], ' '         ; spacing
            inc       rdx                     ; next byte

            push      rdx                     ; save rdx to the stack
            mov       rdi, r10                ; row param
            mov       rsi, r9                 ; column param
            mov       rdx, 9                  ; num columns param
            call      coord_to_index          ; get sudoku buffer offset for row column
            pop       rdx                     ; restore rdx from stack

            mov       r11, sudoku             ; move address of sudoku buffer into r11
            add       r11, rax                ; apply offset
            mov       dil, byte [r11]         ; move current buffer byte into dil
            call      dec_to_ascii            ; convert decimal to ascii

            mov       byte [rdx], al          ; the ascii grid value
            inc       rdx                     ; next byte
            mov       byte [rdx], ' '         ; spacing
            inc       rdx                     ; next byte
            inc       r9                      ; row finished, increase counter
            cmp       r9, num_cols            ; compare for column limit
            jl        content_loop            ; loop if not at limit
            mov       byte [rdx], '|'         ; closing decorative character
            inc       rdx                     ; next byte
            mov       byte [rdx], 10          ; new line
            mov       rax, sys_write          ; code for write syscall
            mov       rdi, fd_stdout          ; write to stdout (terminal)
            mov       rsi, write              ; buffer to write out
            mov       rdx, row_chars          ; write whole row
            syscall                           ; invoke OS to write
            ret                               ; end function
; ==== END DRAW ROW CONTENT FUNCTION ====

; ==== DECIMAL TO ASCII FUNCTION ====
; function to convert a decimal number to its ascii code.
; param dil: byte containing decimal number from 0-9 inclusive
; return al: ascii code for input value 
dec_to_ascii:
            ; TODO: range checking and errors.
            mov       al, dil                ; move the input into al
            add       al, 48                 ; add an offset of 48
            ret
; ==== END DECIMAL TO ASCII FUNCTION ====

; ==== COORDINATE TO INDEX FUNCTION ====
; param rdi: the row
; param rsi: the column
; param rdx: the number of columns
coord_to_index:
            mov rax, rdi
            imul rax, rdx
            add rax, rsi
            ret
; ==== END COORDINATE TO INDEX FUNCTION ====

; ==== GENERATE SUDOKU FUNCTION ====
; stub implementation for sudoku generation that sets each byte to its
; index
generate_sudoku:
            mov       r8, 0
            mov       r9, sudoku
            mov       r10b, 0
write_loop:
            mov       byte [r9], r10b
            inc       r10b
            inc       r9
            inc       r8
            cmp       r8, 81
            jl        write_loop
            ret
; ==== END GENERATE SUDOKU FUNCTION ====

            section   .bss
input:      resb      1                       ; buffer used to read input
sudoku:     resb      81
write:      resb      38
termios:
c_iflag     resd      1                       ; input mode flags
c_oflag     resd      1                       ; output mode flags
c_cflag     resd      1                       ; control mode flags
c_lflag     resd      1                       ; local mode flags
c_line      resb      1                       ; line discipline
c_cc        resb      19                      ; control characters

            section   .data
row_split:  db        "+---+---+---+---+---+---+---+---+---+", 10