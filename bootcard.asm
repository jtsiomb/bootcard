; ---- boot me! ----
; nasm -f bin -o bootcard.img bootcard.asm
; cat bootcard.img >/dev/<usbstick>
; reboot

	org 7c00h
	bits 16

data_start	equ 7e00h
osc_freq	equ 1193182
PIT_DATA0	equ 40h
PIT_DATA2	equ 42h
PIT_CMD		equ 43h
PIT_CMD_CHAN0	equ 00h
PIT_CMD_CHAN1	equ 40h
PIT_CMD_CHAN2	equ 80h
PIT_CMD_HILO	equ 30h
PIT_CMD_SQWAVE	equ 06h
KB_CTRL		equ 61h

%define DIV_ROUND(a, b)	((a) / (b) + ((a) % (b)) / ((b) / 2))

%macro setcursor 2
	mov dl, %1
	mov dh, %2
	xor bx, bx
	mov ah, 2
	int 10h
%endmacro

%macro spkon 0
	in al, KB_CTRL
	or al, 3
	out KB_CTRL, al
%endmacro
%macro spkoff 0
	in al, KB_CTRL
	and al, 0fch
	out KB_CTRL, al
%endmacro

	xor ax, ax
	mov ds, ax
	mov ss, ax
	mov sp, 7c00h

	call init_spk

	mov ax, 13h
	int 10h
	mov ax, 0a000h
	mov es, ax

	mov ax, 0303h
	mov cx, 32000
	xor di, di
	rep stosw

	setcursor 10, 12
	mov si, str1
	call textout
	setcursor 12, 13
	mov si, str2
	call textout

infloop:
	hlt
	jmp infloop

init_spk:
	xor ax, ax
	mov [32], ax
	mov word [34], timer_intr

	mov al, PIT_CMD_CHAN2 | PIT_CMD_HILO | PIT_CMD_SQWAVE
	out PIT_CMD, al
	mov ax, DIV_ROUND(osc_freq, 440)
	out PIT_DATA2, al
	mov al, ah
	out PIT_DATA2, al

	spkon

	sti
	ret

textout:
	mov al, [si]
	and al, al
	jz .done
	mov ah, 0eh
	mov bx, 0fh
	int 10h
	inc si
	jmp textout
.done:	ret

timer_intr:
	spkoff
	mov al, 20h
	out 20h, al	; EOI
	iret

str1:	db 'message message blah',0
str2:	db 'Michael & Athina',0

	times 446-($-$$) db 0
	dd 00212080h
	dd 0820280ch
	dd 00000800h
	dd 0001f800h
	times 510-($-$$) db 0
	dw 0aa55h

; vi:ft=nasm ts=8 sts=8 sw=8:
