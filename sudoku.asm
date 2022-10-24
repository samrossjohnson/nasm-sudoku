; ----------------------------------------------------------------------------------------
; To assemble and run:
;
;     nasm -felf64 sudoku.asm && ld sudoku.o && ./a.out
; ----------------------------------------------------------------------------------------
%define     key0      48
%define     key1      49
%define     key9      57
%define     keyQ      81

%define     sudokuLn  81
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
            call      drawGrid                        ; redraw the grid
.inputLoop:
            call      fillInput
            cmp       byte [input], escape
            jne       .inputChar                      ; not escape sequence so handle regular input
            cmp       byte [input + 1], '['
            jne       gameLoop                        ; we only care about '[' for arrow keys
            cmp       byte [input + 2], 'A'
            je        .upArr
            cmp       byte [input + 2], 'B'
            je        .downArr
            cmp       byte [input + 2], 'C'
            je        .rightArr
            cmp       byte [input + 2], 'D'
            je        .leftArr
            jmp       gameLoop                        ; something unexpected, ignore it
.leftArr:
            sub       byte [caret], 1
            jmp       gameLoop
.rightArr:
            add       byte [caret], 1
            jmp       gameLoop
.upArr:
            sub       byte [caret], 9
            jmp       gameLoop
.downArr:
            add       byte [caret], 9
            jmp       gameLoop
.inputChar:
            cmp       byte [input], keyQ
            je        exit
            mov       dil, byte [input]
            sub       dil, key1                       ; we are able to convert if (x>=0 && x<=b) into ...
            cmp       dil, 8                          ; ... if (x-a <= b-a) so we only need a single comparison ...
            jna       .inputCellValue                 ; ... by exploiting jna unsigned characteristic
            jmp       gameLoop
.inputCellValue:
            mov       dil, byte [input]
            sub       dil, key0                       ; conversion from ['0'...'9'] -> [0...9]
            call      writeToGrid
            jmp       gameLoop

; ==== EXIT FUNCTION ====
; function to exit the program
; input rdi: exit code
; modifies: rax
exit:
            push      rdi
            call      resetTerm
            pop       rdi
            mov       rax, sysExit                    ; system call for exit
            syscall                                   ; invoke operating system to exit
; ==== END EXIT FUNCTION ====

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

; ==== FILL INPUT FUNCTION ====
; function to fill the input buffer by reading from stdin.
fillInput:
            mov       rsi, input
            mov       rax, sysRead
            mov       rdi, fdStdin
            mov       rdx, 4
            syscall
            ret
; ==== END FILL INPUT FUNCTION ====

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
            jl        .drawLoop                       ; loop if not at limit
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
.cellsLoop:
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

            cmp       al, [caret]                     ; check if the cell to draw is the caret
            jne       .drawCellValue                  ; if not, draw as normal
            mov       byte [rdx], ' '                 ; draw the caret char
            jmp       .drawCellClose                  ; finish the cell (skipping the regular value)

.drawCellValue
            mov       r11, sudoku                     ; move address of sudoku buffer into r11
            add       r11, rax                        ; apply offset
            mov       dil, byte [r11]                 ; move current buffer byte into dil
            call      decToAscii                      ; convert decimal to ascii
            mov       byte [rdx], al                  ; the ascii grid value

.drawCellClose
            inc       rdx                             ; next byte
            mov       byte [rdx], ' '                 ; spacing
            inc       rdx                             ; next byte
            inc       r9                              ; row finished, increase counter
            cmp       r9, numCols                     ; compare for column limit
            jl        .cellsLoop                      ; loop if not at limit
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
; param dil: the row
; param sil: the column
; param dl: the number of columns
coordToIndex:
            mov       al, dil
            mul       dl
            add       al, sil
            ret
; ==== END COORDINATE TO INDEX FUNCTION ====

; ==== WRITE TO GRID FUNCTION ====
; function to write a number [1, 9] inclusive to the sudoku buffer.
; param dil: byte representing integer value [1, 9] inclusive
; ret 0: value successfully written to sudoku buffer
; ret 1: failed to write as value was not [1, 9] inclusive
; ret 2: failed to write as caret was outside of sudoku buffer bounds
writeToGrid:
            cmp       dil, 0                          ; check value is >= 0
            jl        .invalidValue
            cmp       dil, 9                          ; check value is <= 9
            jg        .invalidValue
            cmp       byte [caret], 0                 ; check sudoku buffer index is > 0
            jl        .outOfBounds
            cmp       byte [caret], sudokuLn          ; check sudoku buffer index is < sudokuLn - 1
            jge       .outOfBounds
            movzx     rsi, byte [caret]               ; the write location is the caret offset ...
            add       rsi, sudoku                     ; ... on top of the sudoku start address
            mov       byte [rsi], dil                 ; write the value to the sudoku grid
            mov       rax, 0                          ; return success code
            ret
.invalidValue
            mov       rax, 1
            ret
.outOfBounds
            mov       rax, 2
            ret
; ==== END WRITE TO GRID FUNCTION ====

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

; ==== PRINT FUNCTION ====
; function to write a buffer to the standard output
; input rsi: buffer to print
; input rdi: length of buffer to print
; modifies: rdx, rax, rdi
print:
            mov       rdx, rdi                        ; length of buffer
            mov       rax, sysWrite                   ; code for write syscall
            mov       rdi, fdStdout                   ; write to stdout (terminal)
            syscall                                   ; invoke OS to write
            ret
; ==== END PRINT FUNCTION ====

            section   .bss
input:      resb      4                               ; buffer used to read input
sudoku:     resb      sudokuLn                        ; sudoku values
write:      resb      38                              ; write buffer, there are 38 characters per grid row inc. decorations
caret:      resb      1                               ; players location in the sudoku grid
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