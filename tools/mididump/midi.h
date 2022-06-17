#ifndef MIDI_H_
#define MIDI_H_

#include <stdio.h>

struct midi {
	int ppqn, fps, ticks_per_frame;

	int num_tracks;
	struct midi_track *tracks;
};


struct midi_track {
	char *name;
	struct midi_event *head, *tail;
	int num_ev;
};

struct midi_event {
	long dt;
	int type;
	int channel;
	int arg[2];

	struct midi_event *next;
};

#define MIDI_NOTE_OFF			8
#define MIDI_NOTE_ON			9
#define MIDI_NOTE_AFTERTOUCH	10
#define MIDI_CONTROLLER			11
#define MIDI_PROG_CHANGE		12
#define MIDI_CHAN_AFTERTOUCH	13
#define MIDI_PITCH_BEND			14

#define MIDI_NOTE_NUM(ev)	((ev)->arg[0])
#define MIDI_NOTE_VEL(ev)	((ev)->arg[1])

#ifdef __cplusplus
extern "C" {
#endif

struct midi *midi_load(const char *fname);
void midi_free(struct midi *midi);

int midi_num_tracks(struct midi *midi);
struct midi_track *midi_track(struct midi *midi, int idx);

#ifdef __cplusplus
}
#endif

#endif	/* MIDI_H_ */
