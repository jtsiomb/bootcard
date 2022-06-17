#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <inttypes.h>
#include "midi.h"

#define USE_MMAP

#define FMT_SINGLE		0
#define FMT_MULTI_TRACK	1
#define FMT_MULTI_SEQ	2

/* meta events */
#define META_SEQ		0
#define META_TEXT		1
#define META_COPYRIGHT	2
#define META_NAME		3
#define META_INSTR		4
#define META_LYRICS		5
#define META_MARKER		6
#define META_CUE		7
#define META_CHANPREFIX	32
#define META_END_TRACK	47
#define META_TEMPO		81
#define META_SMPTE_OFFS	84
#define META_TMSIG		88
#define META_KEYSIG		89
#define META_SPECIFIC	127

#define CHUNK_HDR_SIZE	8
struct chunk_hdr {
	char id[4];
	uint32_t size;
	unsigned char data[1];
};

struct midi_hdr {
	uint16_t fmt;	/* 0: single, 1: multi-track, 2: multiple independent */
	uint16_t num_tracks;
	uint16_t tm_div;

} __attribute__ ((packed));

static void destroy_track(struct midi_track *trk);
static int read_track(struct midi *midi, struct chunk_hdr *chunk);
static long read_vardata(unsigned char **pptr);
static int read_meta_event(struct midi *midi, struct midi_track *trk, unsigned char **pptr);
static int read_sysex_event(struct midi *midi, unsigned char **pptr);
static int ischunk(struct chunk_hdr *chunk, const char *name);
static struct chunk_hdr *mkchunk(void *ptr);
static struct chunk_hdr *skip_chunk(struct chunk_hdr *chunk);
static struct midi_hdr *mkmidi(void *ptr);
static void bigend(void *ptr, int sz);
static void *map_file(const char *fname, int *size);
static void unmap_file(void *mem, int size);

#define IS_VALID_EVTYPE(x) ((x) >= MIDI_NOTE_OFF && (x) <= MIDI_PITCH_BEND)

/* XXX the event arity table must match the MIDI_* defines in midi.h */
static int ev_arity[] = {
	0, 0, 0, 0, 0, 0, 0, 0,
	2, /* note off (note, velocity)*/
	2, /* note on (note, velocity)*/
	2, /* note aftertouch (note, aftertouch value) */
	2, /* controller (controller number, value) */
	1, /* prog change (prog number) */
	1, /* channel aftertouch (aftertouch value) */
	2  /* pitch bend (pitch LSB, pitch MSB) */
};


struct midi *midi_load(const char *fname)
{
	struct midi *midi;
	char *mem;
	int size;
	struct chunk_hdr *chunk;
	struct midi_hdr *hdr;

	if(!(mem = map_file(fname, &size))) {
		return 0;
	}
	chunk = mkchunk(mem);

	if(!ischunk(chunk, "MThd") || chunk->size != 6) {
		fprintf(stderr, "invalid or corrupted midi file: %s\n", fname);
		goto err;
	}
	hdr = mkmidi(chunk->data);

	if(!(midi = malloc(sizeof *midi))) {
		perror("failed to allocate memory");
		goto err;
	}

	if((hdr->tm_div & 0x8000) == 0) {
		/* division is in pulses / quarter note */
		midi->ppqn = hdr->tm_div;
		midi->fps = midi->ticks_per_frame = -1;
	} else {
		/* division in frames / sec */
		midi->fps = (hdr->tm_div & 0x7f00) >> 8;
		midi->ticks_per_frame = hdr->tm_div & 0xff;
		midi->ppqn = -1;
	}

	if(!(midi->tracks = malloc(hdr->num_tracks * sizeof *midi->tracks))) {
		perror("failed to allocate memory");
		goto err;
	}
	midi->num_tracks = 0;

	while((chunk = skip_chunk(chunk)) && ((char*)chunk < mem + size)) {
		if(ischunk(chunk, "MTrk")) {
			if(read_track(midi, chunk) == -1) {
				fprintf(stderr, "failed to read track\n");
			}
		}
	}

	unmap_file(mem, size);
	return midi;

err:
	unmap_file(mem, size);
	midi_free(midi);
	return 0;
}

void midi_free(struct midi *midi)
{
	int i;

	if(!midi) return;

	for(i=0; i<midi->num_tracks; i++) {
		destroy_track(midi->tracks + i);
	}

	free(midi->tracks);
	free(midi);
}

int midi_num_tracks(struct midi *midi)
{
	return midi->num_tracks;
}

struct midi_track *midi_track(struct midi *midi, int idx)
{
	if(idx < 0 || idx >= midi->num_tracks) {
		return 0;
	}
	return midi->tracks + idx;
}

static void destroy_track(struct midi_track *trk)
{
	free(trk->name);
	while(trk->head) {
		void *tmp = trk->head;
		trk->head = trk->head->next;
		free(tmp);
	}
}

static int read_track(struct midi *midi, struct chunk_hdr *chunk)
{
	unsigned char *ptr;
	struct midi_track trk = {0, 0, 0, 0};
	unsigned char prev_stat = 0;
	int type;
	struct midi_event *ev;

	if(!ischunk(chunk, "MTrk")) {
		return -1;
	}

	ptr = chunk->data;
	while(ptr < chunk->data + chunk->size) {
		long dt;
		unsigned char stat;

		dt = read_vardata(&ptr);
		stat = *ptr++;

		if(stat == 0xff) {
			read_meta_event(midi, &trk, &ptr);
		} else if(stat == 0xf0) {
			read_sysex_event(midi, &ptr);
		} else {
			if(!(stat & 0x80)) {
				/* not a status byte, assume running status */
				stat = prev_stat;
				ptr--;
			}
			type = (stat >> 4) & 0xf;

			if(!IS_VALID_EVTYPE(type) || !(ev = malloc(sizeof *ev))) {
				/* unkwown message, skip all data bytes */
				while(ptr < chunk->data + chunk->size && !(*ptr & 0x80)) {
					ptr++;
				}
				continue;
			}

			if(trk.head) {
				trk.tail->next = ev;
			} else {
				trk.head = ev;
			}
			trk.tail = ev;
			ev->next = 0;
			trk.num_ev++;

			ev->dt = dt;
			ev->type = type;
			ev->channel = stat & 0xf;

			ev->arg[0] = *ptr++;
			if(ev_arity[ev->type] > 1) {
				ev->arg[1] = *ptr++;
			}

			if(ev->type == MIDI_NOTE_ON && ev->arg[1] == 0) {
				ev->type = MIDI_NOTE_OFF;
			}

			prev_stat = stat;
		}
	}

	/* if we did actually add any events ... */
	if(trk.num_ev) {
		midi->tracks[midi->num_tracks++] = trk;
		/*printf("loaded track with %d events\n", trk.num_ev);*/
	}
	return 0;
}

static long read_vardata(unsigned char **pptr)
{
	int i;
	long res = 0;
	unsigned char *ptr = *pptr;

	for(i=0; i<4; i++) {
		res |= (long)(*ptr & 0x7f) << (i * 8);

		/* if first bit is not set we're done */
		if((*ptr++ & 0x80) == 0)
			break;
	}
	*pptr = ptr;
	return res;
}

static int read_meta_event(struct midi *midi, struct midi_track *trk, unsigned char **pptr)
{
	unsigned char *ptr = *pptr;
	unsigned char type;
	long size;

	type = *ptr++;
	size = read_vardata(&ptr);

	switch(type) {
	case META_NAME:
		free(trk->name);
		trk->name = malloc(size + 1);
		memcpy(trk->name, ptr, size);
		trk->name[size] = 0;
		break;

	case META_TEMPO:
		/* TODO add a tempo change event to the midi struct */
		break;

	default:
		break;
	}
	*pptr = ptr + size;
	return 0;
}

/* ignore sysex events */
static int read_sysex_event(struct midi *midi, unsigned char **pptr)
{
	long size = read_vardata(pptr);
	*pptr += size;
	return 0;
}

static int ischunk(struct chunk_hdr *chunk, const char *name)
{
	return memcmp(chunk->id, name, 4) == 0;
}

static struct chunk_hdr *mkchunk(void *ptr)
{
	struct chunk_hdr *chdr = ptr;
	bigend(&chdr->size, sizeof chdr->size);
	return chdr;
}

static struct chunk_hdr *skip_chunk(struct chunk_hdr *chunk)
{
	return mkchunk((char*)chunk + CHUNK_HDR_SIZE + chunk->size);
}

static struct midi_hdr *mkmidi(void *ptr)
{
	struct midi_hdr *midi = ptr;

	bigend(&midi->fmt, sizeof midi->fmt);
	bigend(&midi->num_tracks, sizeof midi->num_tracks);
	bigend(&midi->tm_div, sizeof midi->tm_div);
	return midi;
}

static void bigend(void *ptr, int sz)
{
	static unsigned char test[] = {0x12, 0x34};
	uint32_t val32;
	uint16_t val16;

	if(sz < 2 || *(uint16_t*)test == 0x1234) {
		return;
	}

	switch(sz) {
	case 4:
		val32 = *(uint32_t*)ptr;
		*(uint32_t*)ptr = (val32 << 24) | (val32 >> 24) | ((val32 & 0xff00) << 8) |
			((val32 & 0xff0000) >> 8);
		break;

	case 2:
		val16 = *(uint16_t*)ptr;
		*(uint16_t*)ptr = (val16 >> 8) | (val16 << 8);
		break;

	case 1:
	default:
		break;
	}
}

#if defined(__unix__) && defined(USE_MMAP)
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>

static void *map_file(const char *fname, int *size)
{
	int fd;
	struct stat st;
	void *mem;

	if((fd = open(fname, O_RDONLY)) == -1) {
		fprintf(stderr, "failed to open midi file: %s: %s\n", fname, strerror(errno));
		return 0;
	}
	fstat(fd, &st);

	if((mem = mmap(0, st.st_size, PROT_READ | PROT_WRITE, MAP_PRIVATE, fd, 0)) == (void*)-1) {
		fprintf(stderr, "failed to map midi file: %s: %s\n", fname, strerror(errno));
		close(fd);
		return 0;
	}
	close(fd);

	*size = st.st_size;
	return mem;
}

static void unmap_file(void *mem, int size)
{
	munmap(mem, size);
}
#else
static void *map_file(const char *fname, int *size)
{
	FILE *fp;
	long sz;
	void *buf;

	if(!(fp = fopen(fname, "rb"))) {
		fprintf(stderr, "failed to open midi file: %s: %s\n", fname, strerror(errno));
		return 0;
	}
	fseek(fp, 0, SEEK_END);
	sz = ftell(fp);
	rewind(fp);

	if(!(buf = malloc(sz))) {
		fprintf(stderr, "failed to allocate space for %s in memory (%ld bytes)\n", fname, sz);
		fclose(fp);
		return 0;
	}
	if(fread(buf, 1, sz, fp) != sz) {
		fprintf(stderr, "failed to load midi file: %s: %s\n", fname, strerror(errno));
		free(buf);
		fclose(fp);
		return 0;
	}
	fclose(fp);

	*size = sz;
	return buf;
}

static void unmap_file(void *mem, int size)
{
	free(mem);
}
#endif
