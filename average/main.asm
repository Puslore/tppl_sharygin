; average.asm
; nasm -felf64 average.asm -o average.o && ld average.o -o average

default rel
BUFSIZE equ 1048576

section .data
colon        db ": "
colon_len    equ $ - colon
corrupt_msg  db ": файл испорчен", 0xA
corrupt_len  equ $ - corrupt_msg
newline      db 0xA
zero_str     db "0"
minus_str    db "-"
usage_msg    db "Usage: ./average <file>", 0xA
usage_len    equ $ - usage_msg

section .bss
filename_ptr resq 1
fd           resq 1
bytes_read   resq 1
buffer_end   resq 1
line1_end    resq 1
second_start resq 1
second_end   resq 1
count_x      resq 1
count_y      resq 1
sum_x        resq 1
sum_y        resq 1
buffer       resb BUFSIZE
tmp          resb 1
numbuf       resb 32

section .text
global _start

_start:
    cmp qword [rsp], 1
    jle usage

    mov rdi, [rsp + 16]
    mov [filename_ptr], rdi

    ; open(filename, O_RDONLY)
    mov rax, 2
    mov rdi, [filename_ptr]
    xor esi, esi
    xor edx, edx
    syscall
    test rax, rax
    js corrupt
    mov [fd], rax

    ; read file into buffer (up to BUFSIZE)
    xor r15d, r15d
read_loop:
    lea rsi, [buffer]
    add rsi, r15
    mov rdx, BUFSIZE
    sub rdx, r15
    mov rax, 0
    mov rdi, [fd]
    syscall
    test rax, rax
    js corrupt

    add r15, rax
    cmp r15, BUFSIZE
    je read_full

    test rax, rax
    jnz read_loop

    mov [bytes_read], r15
    jmp close_file

read_full:
    ; Buffer is full. If there is more data, treat file as invalid/too large.
    mov rax, 0
    mov rdi, [fd]
    lea rsi, [tmp]
    mov rdx, 1
    syscall
    test rax, rax
    js corrupt
    cmp rax, 0
    jne corrupt

    mov [bytes_read], r15

close_file:
    mov rax, 3
    mov rdi, [fd]
    syscall

    cmp qword [bytes_read], 0
    je corrupt

    ; Find first '\n'
    lea rdi, [buffer]
    mov rcx, [bytes_read]
    lea rdx, [rdi + rcx]
    mov [buffer_end], rdx

find_first_line:
    cmp rdi, rdx
    jge corrupt
    cmp byte [rdi], 0xA
    je found_first_line
    inc rdi
    jmp find_first_line

found_first_line:
    mov [line1_end], rdi

    ; Parse first line: array x
    lea rdi, [buffer]
    mov rsi, [line1_end]
    lea rcx, [count_x]
    lea rdx, [sum_x]
    call parse_line
    test rax, rax
    jnz corrupt

    ; Second line starts after first '\n'
    mov rdi, [line1_end]
    inc rdi
    mov [second_start], rdi

    ; Restore buffer_end and find end of second line
    lea rdi, [buffer]
    mov rcx, [bytes_read]
    lea rdx, [rdi + rcx]
    mov [buffer_end], rdx

    mov rdi, [second_start]
find_second_line:
    cmp rdi, rdx
    jge second_end_eof
    cmp byte [rdi], 0xA
    je found_second_line
    inc rdi
    jmp find_second_line

found_second_line:
    mov [second_end], rdi
    jmp parse_second

second_end_eof:
    mov [second_end], rdx

parse_second:
    mov rdi, [second_start]
    mov rsi, [second_end]
    lea rcx, [count_y]
    lea rdx, [sum_y]
    call parse_line
    test rax, rax
    jnz corrupt

    ; After the second line only whitespace may remain.
    mov rdi, [second_end]
    mov rsi, [buffer_end]

check_tail:
    cmp rdi, rsi
    jge counts_ok
    movzx eax, byte [rdi]
    cmp al, 0x20
    je tail_skip
    cmp al, 0x09
    je tail_skip
    cmp al, 0x0A
    je tail_skip
    cmp al, 0x0D
    je tail_skip
    jmp corrupt

tail_skip:
    inc rdi
    jmp check_tail

counts_ok:
    mov rax, [count_x]
    cmp rax, [count_y]
    jne corrupt
    test rax, rax
    jz corrupt

    ; average = (sum_x - sum_y) / count
    mov rax, [sum_x]
    sub rax, [sum_y]
    mov rcx, [count_x]
    cqo
    idiv rcx

    mov r15, rax

    ; Print: filename + ": " + average + '\n'
    mov rdi, [filename_ptr]
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    mov rsi, [filename_ptr]
    syscall

    mov rax, 1
    mov rdi, 1
    lea rsi, [colon]
    mov rdx, colon_len
    syscall

    mov rax, r15
    call print_int

    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall

    mov rax, 60
    xor edi, edi
    syscall

corrupt:
    mov rdi, [filename_ptr]
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    mov rsi, [filename_ptr]
    syscall

    mov rax, 1
    mov rdi, 1
    lea rsi, [corrupt_msg]
    mov rdx, corrupt_len
    syscall

    mov rax, 60
    mov rdi, 1
    syscall

usage:
    mov rax, 1
    mov rdi, 2
    lea rsi, [usage_msg]
    mov rdx, usage_len
    syscall

    mov rax, 60
    mov rdi, 1
    syscall

; ---------------------------------------------------------------
; parse_line(start, end, count_ptr, sum_ptr)
; rdi = start, rsi = end, rcx = count_ptr, rdx = sum_ptr
; returns rax = 0 if OK, rax = 1 if corrupted
; ---------------------------------------------------------------
parse_line:
    mov r8, rdi
    mov r9, rsi
    mov r10, rcx
    mov r11, rdx

    mov qword [r10], 0
    mov qword [r11], 0

.pl_next_number:
.pl_skip_spaces_before:
    cmp r8, r9
    jge .pl_error
    movzx eax, byte [r8]
    cmp al, 0x20
    je .pl_skip_spaces_before_inc
    cmp al, 0x09
    je .pl_skip_spaces_before_inc
    cmp al, 0x0D
    je .pl_skip_spaces_before_inc
    jmp .pl_parse_sign

.pl_skip_spaces_before_inc:
    inc r8
    jmp .pl_skip_spaces_before

.pl_parse_sign:
    xor r12d, r12d
    cmp al, '-'
    je .pl_negative_sign
    cmp al, '+'
    je .pl_positive_sign
    jmp .pl_number

.pl_negative_sign:
    mov r12d, 1
    inc r8
    jmp .pl_number

.pl_positive_sign:
    inc r8

.pl_number:
    xor ebx, ebx
    xor r13d, r13d

.pl_digit_loop:
    cmp r8, r9
    jge .pl_digits_done
    movzx eax, byte [r8]
    cmp al, '0'
    jb .pl_digits_done
    cmp al, '9'
    ja .pl_digits_done

    inc r13d

    imul rbx, rbx, 10
    sub al, '0'
    movzx eax, al
    add rbx, rax

    inc r8
    jmp .pl_digit_loop

.pl_digits_done:
    test r13d, r13d
    jz .pl_error

    test r12d, r12d
    jz .pl_add_number
    neg rbx

.pl_add_number:
    add [r11], rbx
    inc qword [r10]

.pl_skip_spaces_after:
    cmp r8, r9
    jge .pl_ok
    movzx eax, byte [r8]
    cmp al, 0x20
    je .pl_skip_spaces_after_inc
    cmp al, 0x09
    je .pl_skip_spaces_after_inc
    cmp al, 0x0D
    je .pl_skip_spaces_after_inc
    cmp al, ','
    je .pl_comma
    jmp .pl_error

.pl_skip_spaces_after_inc:
    inc r8
    jmp .pl_skip_spaces_after

.pl_comma:
    inc r8
    jmp .pl_next_number

.pl_ok:
    xor eax, eax
    ret

.pl_error:
    mov eax, 1
    ret

; ---------------------------------------------------------------
; strlen(str)
; rdi = string pointer
; returns rax = length
; ---------------------------------------------------------------
strlen:
    xor eax, eax
.strlen_loop:
    cmp byte [rdi + rax], 0
    je .strlen_done
    inc rax
    jmp .strlen_loop
.strlen_done:
    ret

; ---------------------------------------------------------------
; print_int(value)
; rax = signed 64-bit integer to print to stdout
; ---------------------------------------------------------------
print_int:
    mov r12, rax
    test r12, r12
    jz .print_zero
    js .print_negative

.print_positive:
    jmp .print_convert

.print_negative:
    mov rax, 1
    mov rdi, 1
    lea rsi, [minus_str]
    mov rdx, 1
    syscall

    neg r12

.print_convert:
    lea rdi, [numbuf + 32]
    mov r13, 10

.print_digit_loop:
    mov rax, r12
    xor edx, edx
    div r13
    mov r12, rax

    add dl, '0'
    dec rdi
    mov [rdi], dl

    test r12, r12
    jnz .print_digit_loop

    lea rdx, [numbuf + 32]
    sub rdx, rdi
    mov rsi, rdi
    mov rax, 1
    mov rdi, 1
    syscall
    ret

.print_zero:
    mov rax, 1
    mov rdi, 1
    lea rsi, [zero_str]
    mov rdx, 1
    syscall
    ret