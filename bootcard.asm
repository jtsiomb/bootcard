; ---- boot me! ----
; nasm -f bin -o bootcard.img bootcard.asm
; cat bootcard.img >/dev/<usbstick>

%define MIDI

	bits 16
%ifdef DOS
	org 100h
	jmp start
%else
	org 7c00h
%endif

barh	equ 4
nbars	equ 11
barstart equ 200 - (nbars+1) * barh

%ifdef DOS
nticks 	dd 0
tmoffs 	dd 0
musptr 	dd 0
frame 	dd 0
pnote	dd 0
fval 	dd 0
cmap 	dd 0

saved_tintr_offs dw 0
saved_tintr_seg dw 0
%else
nticks	equ 7e00h
tmoffs	equ 7e04h
musptr	equ 7e08h
frame	equ 7e0ch
pnote	equ 7e18h
fval	equ 7e10h
cmap	equ 7e14h
%endif

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

start:
%ifndef DOS
	xor ax, ax
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
%else
	; for DOS save the previous interrupt handler to restore at the end
	xor ax, ax
	mov es, ax
	mov ax, [es:32]
	mov [saved_tintr_offs], ax
	mov ax, [es:34]
	mov [saved_tintr_seg], ax

	cli
	mov ax, ds
	mov word [es:32], tintr
	mov [es:34], ax
%endif

	stimer 0, 5966
%ifdef MIDI
	call resetmidi
	mov ax, 0c0h	; change program on chan 0
	call sendmidi
	mov ax, 19	; church organ
	call sendmidi
%endif
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

%ifdef DOS
	in al, 60h
	dec al
	jnz mainloop

	mov ax, 3
	int 10h

	cli
	xor ax, ax
	mov es, ax
	mov ax, [saved_tintr_offs]
	mov word [es:32], ax
	mov ax, [saved_tintr_seg]
	mov [es:34], ax
	stimer 0, 0xffff
	sti
	ret
%else
	jmp mainloop
%endif

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

%ifdef MIDI
note_on:
	mov [pnote], ax
	mov ax, 90h	; note-on command for channel 0
	call sendmidi
	mov ax, [pnote]
	call sendmidi
	mov ax, 127
	call sendmidi
	ret

note_off:
	mov ax, 80h	; note-off command for channel 0
	call sendmidi
	mov ax, [pnote]
	call sendmidi
	mov ax, 64
	call sendmidi
	ret

all_notes_off:
	mov ax, 0b0h	; channel mode message for channel 0...
	call sendmidi
	mov ax, 7bh	; all notes off
	call sendmidi
	xor ax, ax
	call sendmidi
	ret

waitmidi:
	mov ax, 331h
.wait:	in al, dx	; read status port
	test al, 40h	; test output-ready bit (0: ready)
	jnz .wait
	ret

sendmidi:
	push dx
	push ax
	call waitmidi
	pop ax
	dec dx
	out dx, al
	pop dx
	ret

resetmidi:
	call waitmidi
	mov ax, 0ffh	; reset command
	out dx, al
	call waitmidi
	mov ax, 3fh	; enter UART mode
	out dx, al
	ret
%endif	; MIDI

tintr:
	pusha
	mov ax, [nticks]
	inc ax
	mov [nticks], ax

	mov bx, [musptr]
%ifdef MIDI
	cmp bx, 22*2
%else
	cmp bx, 22*3
%endif
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

%ifdef MIDI
	call note_off
	mov al, [music + 1 + bx]
	xor ah, ah
	add bx, 2
%else
	mov ax, [music + 1 + bx]
	add bx, 3
%endif
	mov [musptr], bx
	test ax, ax
	jz .off

	mov bx, ax
%ifdef MIDI
	sub bx, 43
%else
	shr bx, 9
	sub bx, 13
%endif
	imul bx, bx, 3
	mov byte [cmap + bx], 3fh
	mov word [cmap + bx + 1], 2f2fh

%ifdef MIDI
	call note_on
%else
	mov bx, ax
	stimer 2, bx
	spkon
%endif
	jmp .end

.off:
%ifdef MIDI
	call all_notes_off
%else
	spkoff
%endif

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

%ifdef MIDI
G2	equ 43
C3	equ 48
D3	equ 50
B2	equ 47
F3	equ 53
E3	equ 52
%else
G2      equ 12175
C3      equ 9121
D3      equ 8126
B2      equ 9664
F3      equ 6833
E3      equ 7239
%endif


%ifdef MIDI
%macro EV 2
	db %1 >> 4
	db %2
%endmacro
%else
%macro EV 2
	db %1 >> 4
	dw %2
%endmacro
%endif

music:	EV     0,  G2
	EV   160,  C3
	EV   272,  C3
	EV   320,  C3
	EV   560,  0
	EV   640,  G2
	EV   800,  D3
	EV   912,  B2
	EV   960,  C3
	EV  1200,  0
	EV  1280,  G2
	EV  1440,  C3
	EV  1552,  F3
	EV  1600,  F3
	EV  1760,  E3
	EV  1872,  D3
	EV  1920,  C3
	EV  2080,  B2
	EV  2192,  C3
	EV  2240,  D3
	EV  2560,  0
	EV  2720,  0

w5:	dw 5
w30:	dw 30

%ifndef DOS
%ifndef MIDI
	times 446-($-$$) db 0
	dd 00212080h
	dd 0820280ch
	dd 00000800h
	dd 0001f800h
%endif

	times 510-($-$$) db 0
	dw 0aa55h
%endif
; vi:ft=nasm ts=8 sts=8 sw=8:
