bin = bootcard.img

QEMU_FLAGS = -soundhw pcspk

$(bin): bootcard.asm
	nasm -f bin -o $@ $<

.PHONY: clean
clean:
	rm -f $(bin)

.PHONY: run
run: $(bin)
	qemu-system-i386 -hda $< $(QEMU_FLAGS)

.PHONY: debug
debug: $(bin)
	qemu-system-i386 -S -s -hda $< $(QEMU_FLAGS)

.PHONY: disasm
disasm: $(bin)
	ndisasm -o 0x7c00 $< >dis

.PHONY: qr
qr: bootcard.asm
	qrencode -o qr.png -r bootcard.asm
