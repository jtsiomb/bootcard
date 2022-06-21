; ---- boot me! ----
; nasm -f bin -o bootcard.img bootcard.asm
; cat bootcard.img >/dev/<usbstick>
; reboot

	org 7c00h
	bits 16

nticks	equ 7e00h
tmoffs	equ 7e04h
muscur	equ 7e08h

%macro setcur 2
	mov dx, %1 | (%2 << 8)
	xor bx, bx
	mov ah, 2
	int 10h
%endmacro
%macro spkon 0
	in al, 61h
	or al, 3
	out 61h, al
%endmacro
%macro spkoff 0
	in al, 61h
	and al, 0fch
	out 61h, al
%endmacro
%macro stimer 2
	mov al, (%1 << 6) | 36h
	out 43h, al
	mov ax, %2
	out 40h + %1, al
	mov al, ah
	out 40h + %1, al
%endmacro

start:	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 7c00h

	mov di, nticks
	mov cx, 6
	rep stosw

	mov word [32], tintr
	mov [34], ax

	stimer 0, 5966

	mov ax, 13h
	int 10h
	push 1000h
	pop es

	sti

mainloop:
	call drawbg

	push ds
	push es
	push es
	pop ds
	push 0a000h
	pop es
	xor di, di
	xor si, si
	mov cx, 32000

	mov dx, 3dah
.invb:	in al, dx
	and al, 8
	jnz .invb
.novb:	in al, dx
	and al, 8
	jz .novb

	rep movsw
	pop es
	pop ds

	setcur 10, 0
	mov si, str1
	call textout
	setcur 12, 1
	mov si, str2
	call textout

	jmp mainloop

drawbg:
	mov bx, 200
	mov di, 5120
.fillgrad:
	mov ax, bx
	mov ah, al
	mov cx, 2400	; 15 lines
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
	fstp st0
	mov bx, [bp - 2]
	add bx, 100
	imul bx, bx, 320
	add bx, cx
.mntcol:
	mov byte [es:bx], 0
	add bx, 320
	cmp bx, 64000
	jb .mntcol

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

tintr:
	pusha
	push ds
	push word 0
	pop ds
	mov ax, [nticks]
	inc ax
	mov [nticks], ax

	sub ax, [tmoffs]
.pmus:	mov bx, [muscur]
	shl bx, 2
	mov cx, [music + bx]
	cmp cx, 0ffffh
	jz .loop
	cmp ax, cx
	jb .eoi

	inc word [muscur]
	mov ax, [music + 2 + bx]
	test ax, ax
	jz .off
	mov bx, ax
	stimer 2, bx
	spkon
	jmp .eoi

.off:	spkoff

.eoi:	mov al, 20h
	out 20h, al
	pop ds
	popa
	iret

.loop:	neg cx
	mov [muscur], cx
	mov ax, [nticks]
	mov [tmoffs], ax
	jmp .pmus
	

str1:	db 'message blah',0
str2:	db 'Michael & Athena',0

G2	equ 12175
C3	equ 9121
D3	equ 8126
B2	equ 9664
F3	equ 6833
E3	equ 7239

music:	dw 0,		0
	dw 40,		G2
	dw 200,		C3
	dw 320,		C3
	dw 360,		C3
	dw 600,		0
	dw 680,		G2
	dw 840,		D3
	dw 960,		B2
	dw 1000,	C3
	dw 1240,	0
	dw 1320,	G2
	dw 1480,	C3
	dw 1600,	F3
	dw 1640,	F3
	dw 1800,	E3
	dw 1920,	D3
	dw 1960,	C3
	dw 2120,	B2
	dw 2240,	C3
	dw 2280,	D3
	dw 2600,	0
	dw 2760,	0
	dw 0ffffh,	0

w5:	dw 5
w30:	dw 30

	times 446-($-$$) db 0
	dd 00212080h
	dd 0820280ch
	dd 00000800h
	dd 0001f800h

	times 510-($-$$) db 0
	dw 0aa55h

; vi:ft=nasm ts=8 sts=8 sw=8:
