#include <stdio.h>
#include <stdlib.h>
#include "midi.h"

unsigned int calc_reload(int note);

int main(int argc, char **argv)
{
	int i, chan = -1;
	struct midi *midi;
	struct midi_event *ev;
	long ticks;

	if(!argv[1]) {
		fprintf(stderr, "pass the path to a midi file\n");
		return 1;
	}
	if(argv[2]) {
		if((chan = atoi(argv[2])) < 0 || chan > 127) {
			fprintf(stderr, "invalid channel: %d\n", chan);
			return 1;
		}
	}

	if(!(midi = midi_load(argv[1]))) {
		fprintf(stderr, "failed to load midi file: %s\n", argv[1]);
		return 1;
	}

	if(chan < 0) {
		printf("midi file: %s\n", argv[1]);
		if(midi->ppqn > 0) {
			printf("  pulses per quarter-note: %d\n", midi->ppqn);
		}
		if(midi->fps > 0) {
			printf("  fps: %d (ticks per frame: %d)\n", midi->fps, midi->ticks_per_frame);
		}
		printf("  tracks: %d\n", midi->num_tracks);
		for(i=0; i<midi->num_tracks; i++) {
			if(midi->tracks[i].name) {
				printf("  %d - \"%s\":", i, midi->tracks[i].name);
			} else {
				printf("  %d:", i);
			}
			printf(" %d events\n", midi->tracks[i].num_ev);
		}
		midi_free(midi);
		return 0;
	}

	if(chan >= midi->num_tracks) {
		fprintf(stderr, "invalid track: %d (file has %d tracks)\n", chan, midi->num_tracks);
		midi_free(midi);
		return 1;
	}

	ticks = 0;
	ev = midi->tracks[chan].head;
	while(ev) {
		ticks += ev->dt;
		switch(ev->type) {
		case MIDI_NOTE_ON:
			/*printf("%ld: %d (%d)\n", ticks, MIDI_NOTE_NUM(ev), MIDI_NOTE_VEL(ev));*/
			if(ticks >= 0) {
				printf("\tdw %ld, %u\n", ticks, calc_reload(MIDI_NOTE_NUM(ev)));
			}
			break;

		case MIDI_NOTE_OFF:
			/*printf("%ld: off\n", ticks);*/
			if(ticks >= 0) {
				printf("\tdw %ld, 0\n", ticks);
			}
			break;

		default:
			break;
		}
		ev = ev->next;
	}

	midi_free(midi);
	return 0;
}


static float note_freq[] = {
	27.500, 29.135, 30.868, 32.703, 34.648, 36.708, 38.891, 41.203, 43.654, 46.249,
	48.999, 51.913, 55.000, 58.270, 61.735, 65.406, 69.296, 73.416, 77.782, 82.407,
	87.307, 92.499, 97.999, 103.83, 110.00, 116.54, 123.47, 130.81, 138.59, 146.83,
	155.56, 164.81, 174.61, 185.00, 196.00, 207.65, 220.00, 233.08, 246.94, 261.63,
	277.18, 293.67, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, 466.16,
	493.88, 523.25, 554.37, 587.33, 622.25, 659.26, 698.46, 739.99, 783.99, 830.61,
	880.00, 932.33, 987.77, 1046.5, 1108.7, 1174.7, 1244.5, 1318.5, 1396.9, 1480.0,
	1568.0, 1661.2, 1760.0, 1864.7, 1975.5, 2093.0, 2217.5, 2349.3, 2489.0, 2637.0,
	2793.0, 2960.0, 3136.0, 3322.4, 3520.0, 3729.3, 3951.1, 4186.0
};

#define OSC	1193182

unsigned int calc_reload(int note)
{
	if(note < 21 || note > 108) return 0;

	return (int)(OSC / note_freq[note - 21] + 0.5f);
}
