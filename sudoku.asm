; ----------------------------------------------------------------------------------------
; To assemble and run:
;
;     nasm -felf64 sudoku.asm && ld sudoku.o && ./a.out
; ----------------------------------------------------------------------------------------
%define     keyQ      81

%define     sysRead   0
%define     sysWrite  1
%define     sysIoctl  16
%define     sysExit   60

%define     fdStdin   0
%define     fdStdout  1

%define     tcgets    0x5401
%define     tcsets    0x5402
%define     icanon    1<<1
%define     echo      1<<3

%define     rowChars  38                              ; number of characters in a row including decorations
%define     numRows   9                               ; number of rows in the sudoku grid
%define     numCols   9                               ; number of columns in the sudoku grid

%define     escape    0x1b                            ; ascii escape character

            global    _start

            section   .text
_start:
            call      generateSudoku
            call      initTerm
gameLoop:
            call      clear                           ; clear the terminal
            call      drawGrid

            mov       rdi, input                      ; buffer address for getKey 
            call      getKey
            cmp       rax, keyQ                       ; compare entered key with quit symbol
            je        exit                            ; exit
            jmp       gameLoop                        ; continue loop

exit:
            call      resetTerm
            mov       rdi, 0                          ; store read exit code
            mov       rax, sysExit                    ; system call for exit
            syscall                                   ; invoke operating system to exit

initTerm:
            mov       rax, sysIoctl                   ; system call for ioctl
            mov       rdi, fdStdin                    ; file descriptor
            mov       rsi, tcgets                     ; request to get terminal attributes
            mov       rdx, termios                    ; buffer to write into
            syscall                                   ; invoke the OS to read termios

            and       byte [termios.lflag], ~echo     ; disable echo
            and       byte [termios.lflag], ~icanon   ; disable canonical mode

            mov       rax, sysIoctl                   ; system call for ioctl
            mov       rdi, fdStdin                    ; file descriptor
            mov       rsi, tcsets                     ; request number
            mov       rdx, termios                    ; termios stucture to write
            syscall                                   ; invoke the OS to write termios
            ret

resetTerm:
            mov       rax, sysIoctl                   ; system call for ioctl
            mov       rdi, fdStdin                    ; file descriptor
            mov       rsi, tcgets                     ; request to get terminal attributes
            mov       rdx, termios                    ; buffer to write into
            syscall                                   ; invoke the OS to read termios

            or        byte [termios.lflag], echo      ; disable echo
            or        byte [termios.lflag], icanon    ; disable canonical mode

            mov       rax, sysIoctl                   ; system call for ioctl
            mov       rdi, fdStdin                    ; file descriptor
            mov       rsi, tcsets                     ; request number
            mov       rdx, termios                    ; termios stucture to write
            syscall                                   ; invoke the OS to write termios
            ret

; ==== CLEAR FUNCTION ====
; function to clear the terminal by writing the cls buffer to the standard
; output
; modifies: rax, rdx, rsi, rdi
clear:
            mov       rax, sysWrite                   ; code for write syscall
            mov       rdi, fdStdout                   ; write to stdout (terminal)
            mov       rsi, cls                        ; write the cls buffer
            mov       rdx, clsLn                      ; buffer length
            syscall                                   ; invoke OS to write
            ret
; ==== END CLEAR FUNCTION ====

; ==== GET KEY FUNCTION ====
; function to read a single key from the standard input
; input rdi: address of single byte buffer in which to store the read character
; output rax: the charater that was read. '0' if no character was read
; modifies: rax, rdx, rsi, rdi
getKey:
            mov       rsi, rdi                        ; address of read buffer
            mov       rax, sysRead                    ; system call for read
            mov       rdi, fdStdin                    ; file handle 0 is stdin
            mov       rdx, 1                          ; number of bytes to read
            syscall                                   ; invoke OS to do the read
            dec       rax                             ; dec read count, if was 1 then 0 flag gets set
            jz        .return
            mov       byte [rsi], '0'
.return:
            mov       al, [rsi]                       ; move read character to output
            ret
; ==== END GET KEY FUNCTION ====

; ==== DRAW GRID FUNCTION ====
; function to draw the sudoku grid to stdout
drawGrid:
            mov       r8, 0                           ; number of rows draw so far
.drawLoop:
            call      drawRowSplit                    ; draw decorative row split
            mov       rdi, r8
            call      drawRowContent                  ; draw content for row
            inc       r8                              ; row finished, increase counter
            cmp       r8, numRows                     ; compare for row limit
            jl        .drawLoop                        ; loop if not at limit
            call      drawRowSplit                    ; closing decorative row split
            ret                                       ; end function
; ==== END DRAW GRID FUNCTION ====

; ==== DRAW ROW SPLIT FUNCTION ====
; function to decorative line between rows for the sudoku grid
drawRowSplit:
            mov       rax, sysWrite                   ; code for write syscall
            mov       rdi, fdStdout                   ; write to stdout (terminal)
            mov       rsi, rowSplit                   ; buffer to write out
            mov       rdx, rowSplitLn                 ; number of bytes to write
            syscall                                   ; invoke OS to write
            ret                                       ; end function
; ==== END DRAW ROW CONTENT FUNCTION ====

; ==== DRAW ROW CONTENT FUNCTION ====
; param rdi: the row to draw
; function to draw all columns of a row in the sudoku grid.   
drawRowContent:
            mov       r9, 0                           ; number of columns drawn so far
            mov       r10, rdi                        ; store the row in r10
            mov       rdx, write                      ; put start of write buffer into rdx
.contentLoop:
            mov       byte [rdx], '|'                 ; decorative character
            inc       rdx                             ; next byte
            mov       byte [rdx], ' '                 ; spacing
            inc       rdx                             ; next byte

            push      rdx                             ; save rdx to the stack
            mov       rdi, r10                        ; row param
            mov       rsi, r9                         ; column param
            mov       rdx, 9                          ; num columns param
            call      coordToIndex                    ; get sudoku buffer offset for row column
            pop       rdx                             ; restore rdx from stack

            mov       r11, sudoku                     ; move address of sudoku buffer into r11
            add       r11, rax                        ; apply offset
            mov       dil, byte [r11]                 ; move current buffer byte into dil
            call      decToAscii                      ; convert decimal to ascii

            mov       byte [rdx], al                  ; the ascii grid value
            inc       rdx                             ; next byte
            mov       byte [rdx], ' '                 ; spacing
            inc       rdx                             ; next byte
            inc       r9                              ; row finished, increase counter
            cmp       r9, numCols                     ; compare for column limit
            jl        .contentLoop                     ; loop if not at limit
            mov       byte [rdx], '|'                 ; closing decorative character
            inc       rdx                             ; next byte
            mov       byte [rdx], 10                  ; new line
            mov       rax, sysWrite                   ; code for write syscall
            mov       rdi, fdStdout                   ; write to stdout (terminal)
            mov       rsi, write                      ; buffer to write out
            mov       rdx, rowChars                   ; write whole row
            syscall                                   ; invoke OS to write
            ret                                       ; end function
; ==== END DRAW ROW CONTENT FUNCTION ====

; ==== DECIMAL TO ASCII FUNCTION ====
; function to convert a decimal number to its ascii code.
; param dil: byte containing decimal number from 0-9 inclusive
; return al: ascii code for input value 
decToAscii:
                    ; TODO: range checking and errors.
            mov       al, dil                         ; move the input into al
            add       al, 48                          ; add an offset of 48
            ret
; ==== END DECIMAL TO ASCII FUNCTION ====

; ==== COORDINATE TO INDEX FUNCTION ====
; param rdi: the row
; param rsi: the column
; param rdx: the number of columns
coordToIndex:
            mov       rax, rdi
            imul      rax, rdx
            add       rax, rsi
            ret
; ==== END COORDINATE TO INDEX FUNCTION ====

; ==== GENERATE SUDOKU FUNCTION ====
; stub implementation for sudoku generation that sets each byte to its
; index
generateSudoku:
            mov       r8, 0
            mov       r9, sudoku
            mov       r10b, 0
.writeLoop:
            mov       byte [r9], r10b
            inc       r10b
            inc       r9
            inc       r8
            cmp       r8, 81
            jl        .writeLoop
            ret
; ==== END GENERATE SUDOKU FUNCTION ====

            section   .bss
input:      resb      1                               ; buffer used to read input
sudoku:     resb      81
write:      resb      38
termios:
.iflag:     resd      1                               ; input mode flags
.oflag:     resd      1                               ; output mode flags
.cflag:     resd      1                               ; control mode flags
.lflag:     resd      1                               ; local mode flags    
.line:      resb      1                               ; line discipline
.cc:        resb      19                              ; control characters

            section   .data
rowSplit:   db        "+---+---+---+---+---+---+---+---+---+", 10
rowSplitLn: equ       $-rowSplit
cls:        db        escape, "[H", escape, "[2J"
clsLn:      equ       $-cls