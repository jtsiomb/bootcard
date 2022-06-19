; ---- boot me! ----
; nasm -f bin -o bootcard.img bootcard.asm
; cat bootcard.img >/dev/<usbstick>
; reboot

	org 7c00h
	bits 16

data_start	equ 7e00h
nticks		equ data_start
tmoffs		equ nticks + 4
muscur		equ tmoffs + 4
data_end	equ muscur + 4

backbuf_seg	equ 1000h

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

start:	xor eax, eax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 7c00h

	mov di, data_start
	mov cx, (data_end - data_start) / 2
	rep stosw

	mov word [32], timer_intr
	mov [34], ax

	settimer 0, DIV_ROUND(OSC_FREQ, 200)

	mov ax, 13h
	int 10h
	push backbuf_seg
	pop es

	sti

mainloop:
	call drawbg

	mov dx, 3dah
.invb:	in al, dx
	and al, 8
	jnz mainloop
.novb:	in al, dx
	and al, 8
	jz .novb

	push ds
	push es
	push es
	pop ds
	push 0a000h
	pop es
	xor di, di
	xor si, si
	mov cx, 32000
	rep movsw
	pop es
	pop ds

	setcursor 10, 0
	mov si, str1
	call textout
	setcursor 12, 1
	mov si, str2
	call textout

	jmp mainloop

drawbg:
	mov bx, 200
	mov di, 5120
.fillgrad:
	mov ax, bx
	mov ah, al
	mov cx, 3680	; 20 lines
	rep stosw
	inc bx
	cmp bx, 208
	jnz .fillgrad

	; mountains
	mov cx, 320
	mov bp, sp
.mnt:	mov [bp - 2], cx
	fild word [bp - 2]
	fidiv word [w30]
	fsincos
	fiadd word [w5]
	fimul word [w5]
	fistp word [bp - 2]
	fistp word [bp - 4]
	mov bx, [bp - 2]
	add bx, 100
	imul bx, bx, 320
	add bx, cx
	mov byte [es:bx], 0
	dec cx
	jnz .mnt
	
	ret


textout:
	mov al, [si]
	and al, al
	jz .done
	mov ah, 0eh
	mov bx, 82
	int 10h
	inc si
	jmp textout
.done:	ret

timer_intr:
	pusha
	mov ax, [nticks]
	inc ax
	mov [nticks], ax

	sub ax, [tmoffs]
.pmus:	mov bx, [muscur]
	shl bx, 2
	mov cx, [music + bx]	; event time
	cmp cx, 0ffffh
	jz .loop
	cmp ax, cx
	jb .eoi

	inc dword [muscur]
	mov ax, [music + 2 + bx] ; event counter reload
	test ax, ax
	jz .off
	mov bx, ax
	settimer 2, bx
	spkon
	jmp .eoi

.off:	spkoff

.eoi:	mov al, 20h
	out 20h, al	; EOI
	popa
	iret

.loop:	neg cx
	mov [muscur], cx
	mov ax, [nticks]
	mov [tmoffs], ax
	jmp .pmus
	

str1:	db 'message message blah',0
str2:	db 'Michael & Athena',0

G2	equ 24351/2
C3	equ 18243/2
D3	equ 16252/2
B2	equ 19328/2
F3	equ 13666/2
E3	equ 14479/2

%define TM(x)	(40 + (x) * 4)

music:	dw 0, 0
	dw TM(0),	G2
	dw TM(40),	C3
	dw TM(70),	C3

	dw TM(80),	C3
	dw TM(140),	0

	dw TM(160),	G2
	dw TM(200),	D3
	dw TM(230),	B2

	dw TM(240),	C3
	dw TM(300),	0

	dw TM(320),	G2
	dw TM(360),	C3
	dw TM(390),	F3

	dw TM(400),	F3
	dw TM(440),	E3
	dw TM(470),	D3

	dw TM(480),	C3
	dw TM(520),	B2
	dw TM(550),	C3

	dw TM(560),	D3
	dw TM(640),	0

	dw TM(680),	0
	dw 0ffffh, 0

	times 446-($-$$) db 0
	dd 00212080h
	dd 0820280ch
	dd 00000800h
	dd 0001f800h

w5:	dw 5
w30:	dw 30
	times 510-($-$$) db 0
	dw 0aa55h

; vi:ft=nasm ts=8 sts=8 sw=8:
