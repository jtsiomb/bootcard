bin = bootcard.img

$(bin): bootcard.asm
	nasm -f bin -o $@ $<

.PHONY: clean
clean:
	rm -f $(bin)

.PHONY: run
run: $(bin)
	qemu-system-i386 -hda $<

.PHONY: debug
debug: $(bin)
	qemu-system-i386 -S -s -hda $<

.PHONY: disasm
disasm: $(bin)
	ndisasm -o 0x7c00 $< >dis
