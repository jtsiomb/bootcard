; ---- boot me! ----
; nasm -f bin -o bootcard.img bootcard.asm
; cat bootcard.img >/dev/<usbstick>
; reboot

	org 7c00h
	bits 16

data_start	equ 7e00h
nticks		equ data_start
muscur		equ nticks + 4
spkstat		equ muscur + 4
vol		equ spkstat + 4

OSC_FREQ	equ 1193182
PIT_DATA0	equ 40h
PIT_CMD		equ 43h
PIT_CMD_CHAN0	equ 00h
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
%macro settimer 2
	mov al, (PIT_CMD_CHAN0 + (%1 << 6)) | PIT_CMD_HILO | PIT_CMD_SQWAVE
	out PIT_CMD, al
	mov ax, %2
	out PIT_DATA0 + %1, al
	mov al, ah
	out PIT_DATA0 + %1, al
%endmacro

	xor eax, eax
	mov ds, ax
	mov ss, ax
	mov sp, 7c00h

	mov [nticks], eax
	mov [muscur], eax
	;mov [spkstat], eax
	;mov word [vol], 04h
	mov word [32], timer_intr
	mov word [34], 0

	settimer 0, DIV_ROUND(OSC_FREQ, 100)

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

	sti

infloop:
	hlt
	jmp infloop

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
	pusha
	mov ax, [nticks]
	inc ax
	mov [nticks], ax

.pmus:	mov bx, [muscur]
	shl bx, 2
	mov cx, [music + bx]	; event time
	cmp cx, 0ffffh
	jz .loop
	cmp ax, cx
	jb .dopwm

	inc dword [muscur]
	mov ax, [music + 2 + bx] ; event counter reload
	test ax, ax
	jz .off
	mov bx, ax
	settimer 2, bx
	spkon
	mov word [spkstat], 1
	jmp .dopwm

.off:	spkoff
	mov word [spkstat], 0
	jmp .eoi

	; PWM for volume control
.dopwm:	jmp .eoi
	spkoff
	mov ax, [spkstat]
	test ax, ax
	jz .eoi
	mov ax, [nticks]
	and ax, 0fh
	cmp ax, [vol]
	jae .pwmoff
	spkon
	jmp .eoi
.pwmoff:
	spkoff

.eoi:	mov al, 20h
	out 20h, al	; EOI
	popa
	iret

.loop:	neg cx
	mov [muscur], cx
	jmp .pmus
	

str1:	db 'message message blah',0
str2:	db 'Michael & Athina',0

music:
	dw 0, 2000
	dw 10, 1900
	dw 20, 1800
	dw 30, 1700
	dw 40, 1600
	dw 50, 1500
	dw 60, 1400
	dw 70, 1300
	dw 80, 1200
	dw 90, 1100
	dw 100, 1000
	dw 110, 1100
	dw 120, 1200
	dw 130, 1300
	dw 140, 1400
	dw 150, 1500
	dw 160, 1600
	dw 170, 1700
	dw 180, 1800
	dw 190, 1900
	dw 200, 2000
	dw 210, 0
	dw 0ffffh, 0

	times 446-($-$$) db 0
	dd 00212080h
	dd 0820280ch
	dd 00000800h
	dd 0001f800h
	times 510-($-$$) db 0
	dw 0aa55h

; vi:ft=nasm ts=8 sts=8 sw=8:
