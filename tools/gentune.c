#include <stdio.h>
#include <stdint.h>

uint32_t music[] = {
	0x0a2f8f00, 0xa11123a1, 0x23a11423, 0x28000023, 0xbe322f8f, 0x25c0391f,
	0x4b23a13c, 0x8f500000, 0x23a15a2f, 0x641ab161, 0x476e1ab1, 0x1fbe751c,
	0x8223a178, 0xa18925c0, 0x1fbe8c23, 0xaa0000a0,	0
};

struct {
	unsigned int cnt;
	const char *name;
} notes[] = {
	{0, "0"},
	{6833, "F3"},
	{7239, "E3"},
	{8126, "D3"},
	{9121, "C3"},
	{9664, "B2"},
	{12175, "G2"},
	{0, 0}
};

const char *pre =
	"G2	equ 12175\n"
	"C3	equ 9121\n"
	"D3	equ 8126\n"
	"B2	equ 9664\n"
	"F3	equ 6833\n"
	"E3	equ 7239\n"
	"\n"
	"%macro EV 2\n"
	"	db %1 >> 4\n"
	"	dw %2\n"
	"%endmacro\n\n";


int main(void)
{
	int i, j;
	unsigned char *mptr = (unsigned char*)music;

	printf("%s", pre);

	printf("music:");
	for(i=0; i<22; i++) {
		const char *nn = "?";
		unsigned int tm = (unsigned int)*mptr++ << 4;
		unsigned int cnt = *(uint16_t*)mptr;
		mptr += 2;

		for(j=0; notes[j].name; j++) {
			if(notes[j].cnt == cnt) {
				nn = notes[j].name;
				break;
			}
		}

		printf("\tEV  %4u,  %s\n", tm, nn);
	}
	return 0;
}
