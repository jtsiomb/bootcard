; ---- boot me! ----
; nasm -f bin -o bootcard.img bootcard.asm
; cat bootcard.img >/dev/<usbstickdevice>
; reboot

	org 7c00h
	bits 16

	xor ax, ax
	mov ds, ax
	mov ss, ax

	mov ax, 13h
	int 10h

	mov ax, 0a000h
	mov es, ax
	mov ax, 0303h
	mov cx, 32000
	rep stosw

infloop:
	hlt
	jmp infloop

	times 446-($-$$) db 0
	db 80h		; active partition
	db 20h		; start head
	db 21h		; start cylinder
	db 0		; start sector
	db 0ch		; type
	db 28h		; last head
	db 20h		; last cylinder
	db 08h		; last sector
	dd 00000800h	; first lba
	dd 0001f800h	; number of sectors (lba)


	times 510-($-$$) db 0
	dw 0aa55h

; vi:ft=nasm ts=8 sts=8 sw=8:
