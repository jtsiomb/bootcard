bin = bootcard.img
com = bootcard.com

QEMU_FLAGS = -soundhw pcspk -device sb16

$(bin): bootcard.asm
	nasm -f bin -o $@ $<

$(com): bootcard.asm
	nasm -f bin -o $@ $< -DDOS

.PHONY: clean
clean:
	rm -f $(bin) $(com)

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

.PHONY: install
install: $(bin)
	dd if=$(bin) of=/dev/sdd bs=512

.PHONY: com
com: $(com)

.PHONY: rundos
rundos: $(com)
	dosbox-x $(com)

tools/gentune: tools/gentune.c
	$(CC) -o $@ $< $(LDFLAGS)
