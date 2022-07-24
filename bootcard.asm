; ---- boot me! ----
; nasm -f bin -o bootcard.img bootcard.asm
; cat bootcard.img >/dev/<usbstick>

	org 7c00h
	bits 16

barh	equ 4
nbars	equ 11
barstart equ 200 - (nbars+1) * barh

nticks	equ 7e00h
tmoffs	equ 7e04h
musptr	equ 7e08h
frame	equ 7e0ch
fval	equ 7e10h
cmap	equ 7e14h

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
	mov cx, 16
	rep stosw

	cli
	mov word [32], tintr
	mov [34], ax

	stimer 0, 5966

	mov ax, 13h
	int 10h
	push 0a000h
	pop es

	
	mov al, 16
	mov di, barstart * 320
	mov bx, nbars
.drawbars:
	mov cx, barh * 320
	rep stosb
	inc al
	dec bx
	jnz .drawbars

	setcur 12, 16
	mov si, str1
	call textout

	sti

mainloop:
	mov dx, 3dah
.invb:	in al, dx
	and al, 8
	jnz .invb
.novb:	in al, dx
	and al, 8
	jz .novb

drawbg:
	mov bx, 200
	xor di, di
.fillgrad:
	mov ax, bx
	mov ah, al
	mov cx, 2400 ; 15 lines
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
	add bx, 84
	imul bx, bx, 320
	add bx, cx
.mntcol:
	mov byte [es:bx], 0
	add bx, 320
	cmp bx, 128 * 320
	jb .mntcol

	dec cx
	jnz .mnt

	; upd colormap
	mov dx, 3c8h
	mov al, 16
	out dx, al
	inc dx
	mov si, cmap
	mov cx, 16 * 3
	rep outsb

	jmp mainloop

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
	mov ax, [nticks]
	inc ax
	mov [nticks], ax

	mov bx, [musptr]
	cmp bx, 22*3
	jnz .skiploop
	xor bx, bx
	mov [tmoffs], ax
.skiploop:
	xor cx, cx
	mov cl, [music + bx]
	shl cx, 4
	sub ax, [tmoffs]
	cmp ax, cx
	jb .end

	mov ax, [music + 1 + bx]
	add bx, 3
	mov [musptr], bx
	test ax, ax
	jz .off

	mov bx, ax
	shr bx, 9
	sub bx, 13
	imul bx, bx, 3
	mov byte [cmap + bx], 3fh
	mov word [cmap + bx + 1], 2f2fh

	mov bx, ax
	stimer 2, bx
	spkon
	jmp .end

.off:	spkoff

.end:	test word [nticks], 1
	jnz .eoi
	mov cx, 16 * 3
	mov si, cmap
.fadecol:
	lodsb
	test al, al
	jz .skipdec
	dec al
	mov [si-1], al
.skipdec:
	dec cx
	jnz .fadecol
	
.eoi:	mov al, 20h
	out 20h, al
	popa
	iret

str1:	db 'Michael ',3,' Athena',0

music:	dd 0a2f8f00h, 0a11123a1h, 23a11423h, 28000023h, 0be322f8fh, 25c0391fh
	dd 4b23a13ch, 8f500000h, 23a15a2fh, 641ab161h, 476e1ab1h, 1fbe751ch
	dd 8223a178h, 0a18925c0h, 1fbe8c23h, 0aa0000a0h
	dw 0

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
