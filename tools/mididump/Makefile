obj = mididump.o midi.o
bin = mididump

CFLAGS = -pedantic -Wall -g

$(bin): $(obj)
	$(CC) -o $@ $(obj) $(LDFLAGS)

.PHONY: clean
clean:
	rm -f $(bin) $(obj)
