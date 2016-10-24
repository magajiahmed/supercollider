////////////////////////////////////////////////////////////////
// INIT

~clock      =    TempoClock(160/60);
~buffer     =    Buffer.alloc(s, s.sampleRate * ~clock.tempo * 4, 2);
~bus        =    Bus.audio(s, 2);

////////////////////////////////////////////////////////////////
// BUFFER RECORDER / PLAYER

(
SynthDef(\recbuf, { |dur = 2, gate = 1, inBus = 2, isRecording = 1, trigger = 1|
	var env                         =       Env.asr(0.003, 1, 0.003);
	var envgen                      =       EnvGen.kr(env, gate, doneAction: 2);
	var in                          =       In.ar(inBus, ~buffer.numChannels);
	var recbuf                      =       RecordBuf.ar(in, ~buffer.bufnum, recLevel: envgen, run: isRecording, loop: 0, trigger: trigger, doneAction: 2);
}).add;
);

(
SynthDef(\bufrd, { |dur = 1, ffreq = 3000, gate = 1, level = 1, outbus, pan = 0|
	var env                         =       Env.asr(0.003, level, 0.003);
	var envgen                      =       EnvGen.ar(env, gate, doneAction: 2);
	var bufrd                       =       BufRd.ar(~buffer.numChannels, ~buffer.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	Out.ar(outbus, bufrd);
}).add;
);

(
Pdef(\recbuf, Pbind(\instrument, \recbuf, \dur, 4, \inBus, ~bus));
);

/*
Pdef(\recbuf).play(~clock, quant: 4);
Pdef(\recbuf).isPlaying;
Pdef(\recbuf).stop;
*/

(
Pdef(\bufrd, Pbind(\instrument, \bufrd, \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3], inf)));
);

/*
Pdef(\bufrd).play(~clock);
Pdef(\bufrd).isPlaying;
Pdef(\bufrd).stop;
*/

////////////////////////////////////////////////////////////////
// PRC

(
SynthDef(\prc, { |amp = 0.2, curve = -16, freq = 1000, out|
	var env         =    Env.perc(0.003, 0.3, amp, curve);
	var envgen      =    EnvGen.kr(env, doneAction: 2);
	var bn          =    LFBrownNoise2.ar(freq ! 2, mul: envgen);
	Out.ar(out, bn);
}).add;
);

(
Pdef(\prc1,
	Pbind(
		\instrument, \prc,
		\amp, 0.2,
		\freq, 10000,
		\note, Pseq([Rest, 0], inf),
		\out, ~bus,
	));
);

/*
Pdef(\prc1).play(~clock, quant: 4);
Pdef(\prc1).isPlaying;
Pdef(\prc1).stop;
*/

(
Pdef(\prc2,
	Pbind(
		\instrument, \prc,
		\amp, 0.2,
		\curve, -8,
		\dur, Pseq([2.5, 1.5], inf),
		\freq, 1000,
		\out, ~bus,
	));
);

/*
Pdef(\prc2).play(~clock, quant: 4);
Pdef(\prc2).isPlaying;
Pdef(\prc2).stop;
*/
