Pdef.removeAll;

( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
//~nanoktrl2 = 1310720;
//~nanoktrl2 = 1835008;
~nanoktrl2 = 1572864;
);


s.scope;
//~scale = Scale.chromatic;
t = TempoClock(88/60);

//////////////////////////////////////////////////////////////////////////////////

(
SynthDef(\thump, { | dur = 1, freq = 400, level = 0.1, rezfreq = 12000 |
	var env				=	Env.perc(releaseTime: 1.5, level: level, curve: -24);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var saw				=	Saw.ar([freq, freq * 1.02]).round(0.08) * envgen;
	var rlpf			=	RLPF.ar(saw, freq * 3, 0.5);
	var lfn				=	LFNoise2.kr(1.dup).range(0.25, 1);
	var rez				=	Resonz.ar(saw, rezfreq * lfn, 0.05);
	var deci			=	Decimator.ar(rez, bits: 4, mul: envgen);
	Out.ar(0, rlpf + deci);
}).add
);

(
~thumpat =
Pdef(\thumpat,
	Pbind(
		\instrument, \thump,
		\note, Pshuf([-2, 0, 0, 0, 0].stutter(3), inf),
		\dur, Pseq([Pshuf([Pseq([0.25], 3), 0.75, Pseq([0.25, 0.75]), 1.5, 3].stutter(3)), 11], inf),
		\octave, 3,
		\rezfreq, Pshuf((1..7) * 2000, inf),
))
);

/*
~thumpat.play(t, quant: 0.5);
~thumpat.isPlaying;
~thumpat.pause;
*/

(
~thumpon = MIDIdef.cc(\thumpon, {
	if(~thumpat.isPlaying.not) {
		~thumpat.play(t, quant: 0.5);
		"bass play".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~thumpoff = MIDIdef.cc(\thumpoff, {
	if(~thumpat.isPlaying) {
		~thumpat.pause;
		"bass stop".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: 0);
);

////////////////////////////////////////////////////////////////////////////////////////////

(
SynthDef(\drone, { | a = 1.1, dur = 1, freq = 400, gate = 1, gliss_start = 2000, gliss_end = 4000, level = 0.01  |
	var env				=	Env.asr(0.1, level, 5, -4);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var sin				=	SinOsc.ar([freq, freq * 1.001], mul: envgen / 2);
	var fbsin			=	FBSineC.ar([22050, 22000]).range(0.25, 0.75);
	var sinfb			=	SinOscFB.ar(freq, fbsin, envgen);
	var rez				=	Resonz.ar(sinfb, freq * 4, 0.1, 2);
	Out.ar(0, sin + sinfb + rez);
}).add
);

(
~dronepat1 =
Pdef(\dronepat1,
	Pbind(
		\instrument, \drone,
		\note, [0, 7],
		\dur, 84,
		\legato, 0.3,
		\octave, 4,
))
);

/*
~dronepat1.play(t, quant: 1);
~dronepat1.isPlaying;
~dronepat1.pause;
*/

(
~dronepat2 =
Pdef(\dronepat2,
	Pbindf(
		~dronepat1,
		\note, [-2, 2],
		\dur, 53,
		\octave, 5,
))
);

/*
~dronepat2.play(t, quant: 1);
~dronepat2.isPlaying;
~dronepat2.pause;
*/

(
~drone1on = MIDIdef.cc(\drone1on, {
	if(~dronepat1.isPlaying.not) {
		~dronepat1.play(t, quant: 0.5);
		"drone1 play".postln;
	};
}, 48, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~drone1off = MIDIdef.cc(\drone1off, {
	if(~dronepat1.isPlaying) {
		~dronepat1.pause;
		"drone1 stop".postln;
	};
}, 48, srcID: ~nanoktrl2, argTemplate: 0);
);

//

(
~drone2on = MIDIdef.cc(\drone2on, {
	if(~dronepat2.isPlaying.not) {
		~dronepat2.play(t, quant: 0.5);
		"drone2 play".postln;
	};
}, 64, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~drone2off = MIDIdef.cc(\drone2off, {
	if(~dronepat2.isPlaying) {
		~dronepat2.pause;
		"drone2 stop".postln;
	};
}, 48, srcID: ~nanoktrl2, argTemplate: 0);
);

//////////////////////////////////////////////////////////////////////////////////////////////////////////

(
SynthDef(\click, { | bwr = 0.4, freq = 262, ffreq = 3000 |
	var env				=	Env.perc(0.003, 0.1, 1, 0);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var imp				=	BlitB3.ar(0.dup, mul: envgen);
	var rlpf			=	Resonz.ar(imp, ffreq, bwr, 32);
	//var delay			=	BufAllpassC.ar(~clickbuf.bufnum, imp, 0.004 / 4, 4);
	var comb			=	CombL.ar(rlpf, 1, freq.reciprocal, 0.1, 0.25);
	Out.ar(0, rlpf + comb);
}).add
);

(
~clickpat1 =
Pdef(\clickpat1,
	Pbind(
		\instrument, \click,
		\ffreq, 12000,
		\note, Pseq([
			0, 0, 0, Rest, Rest,
			0, 0, 0, 0, Rest, Rest,
			0, 0, 0, 0, 0, Rest, Rest
		], inf),
		\octave, 7,
	)
)
);

/*
~clickpat1.play(t, quant: 1);
~clickpat1.isPlaying;
~clickpat1.pause;
*/

(
~clickpat2 =
Pdef(\clickpat2,
	Pbindf(
		~clickpat1,
		\dur, 1.25,
		\ffreq, 3000,
		\note, Pseq([
			Rest, 0,
			Rest, Rest, 0,
			Rest, Rest, Rest, 0,
		], inf),
))
);

/*
~clickpat2.play(t, quant: 1);
~clickpat2.isPlaying;
~clickpat2.pause;
*/

(
~click1on = MIDIdef.cc(\click1on, {
	if(~clickpat1.isPlaying.not) {
		~clickpat1.play(t, quant: 1);
		"click1 play".postln;
	};
}, 33, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~click1off = MIDIdef.cc(\click1off, {
	if(~clickpat1.isPlaying) {
		~clickpat1.pause;
		"click1 stop".postln;
	};
}, 33, srcID: ~nanoktrl2, argTemplate: 0);
);

//

(
~click2on = MIDIdef.cc(\click2on, {
	if(~clickpat2.isPlaying.not) {
		~clickpat2.play(t, quant: 1);
		"click2 play".postln;
	};
}, 49, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~click2off = MIDIdef.cc(\click2off, {
	if(~clickpat2.isPlaying) {
		~clickpat2.pause;
		"click2 stop".postln;
	};
}, 49, srcID: ~nanoktrl2, argTemplate: 0);
);

/////////////////////////////////////////////////////////////////////////////

(
SynthDef(\prc2, { | a = 1, dur = 1, freq = 22050, level = 0.1, pan = 0 |
	var env				=	Env.perc(0.005, dur, level: level, curve: -4);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var quad			=	QuadC.ar(freq, a,  mul: envgen);
	var deci			=	Decimator.ar(quad, 11025);
	var pan2			=	Pan2.ar((deci / 8) + quad, pan);
	var rhpf			=	RHPF.ar(pan2, freq * 2, 0.2);
	Out.ar(0, rhpf + (quad / 24));
}).add
);

(
~prc2pat1 =
Pdef(\prc2pat1,
	Pbind(
		\instrument, \prc2,
		\a, Pshuf((1..10) / 10, inf),
		\note, Pwrand([0, 1], [16, 1].normalizeSum, inf),
		\dur, Prand([0.25, 0.5], inf),
		\octave, 8,
		\pan2, Prand([-1, 0, 1], inf),
));
);

/*
~prc2pat1.play(t, quant: 1);
~prc2pat1.isPlaying;
~prc2pat1.pause;
*/

~prc2par = Pdef(\prc2par, Ppar(Array.fill(2, { ~prc2pat1 })));

/*
~prc2par.play(t, quant: 1);
~prc2par.isPlaying;
~prc2par.pause;
*/

(
~pulseon = MIDIdef.cc(\pulseon, {
	if(~prc2par.isPlaying.not) {
		~prc2par.play(t, quant: 0.5);
		"pulse play".postln;
	}
}, 65, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~pulseoff = MIDIdef.cc(\pulseoff, {
	if(~prc2par.isPlaying) {
		~prc2par.pause;
		"pulse stop".postln;
	}
}, 65, srcID: ~nanoktrl2, argTemplate: 0);
);

/////////////////////////////////////////////////////////////////////////////

(
SynthDef(\pno, { | a = 1, dur = 1, freq = 400, level = 0.01 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: -4);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lat 			=	Latoocarfian2DC.ar(a: a, mul: 0.2, add: 1).clip(0.5, 2);
	var sin1			=	SinOsc.ar([freq, freq * 1.001] * lat, mul: envgen);
	var sin2			=	SinOsc.ar([freq, freq * 1.001], mul: envgen);
	Out.ar(0, sin1 + sin2);
}).add
);

(
~pnopat1 =
Pdef(\pnopat1,
	Pbind(
		\instrument, \pno,
		\a, Prand((1..6) / 2, inf),
		\dur, Pseq([Pshuf([0, 0.25, 0.5]), 11, 13, 31] + 0.25, inf),
		\note, Pseq([Pshuf([0, 1, 2, 3, 7]), Rest], inf),
		\octave, 6,
))
);

/*
~pnopat1.play(t, quant: 1);
~pnopat1.isPlaying;
~pnopat1.pause;
*/

~pnopar1 = Pdef(\pnopar1, Ppar(Array.fill(4, { ~pnopat1 })));

/*
~pnopar1.play(t, quant: 0.5);
~pnopar1.isPlaying;
~pnopar1.pause;
*/

~pnopat2 = Pdef(\pnopat2, Pbindf(~pnopat1, \degree, Pseq([Pshuf([-2, 0, 1, 2, 3])], inf), \octave, 7));
~pnopar2 = Pdef(\pnopar2, Ppar(Array.fill(2, { ~pnopat2 })));

/*
~pnopar2.play(t, quant: 0.5);
~pnopar2.isPlaying;
~pnopar2.pause;
*/

(
~pnoon1 = MIDIdef.cc(\pnoon1, {
	if(~pnopar1.isPlaying.not) {
		~pnopar1.play(t, quant: 0.5);
		"pno1 play".postln;
	}
}, 35, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~pnooff1 = MIDIdef.cc(\pnooff1, {
	if(~pnopar1.isPlaying) {
		~pnopar1.pause;
		"pno1 stop".postln;
	}
}, 35, srcID: ~nanoktrl2, argTemplate: 0);
);

//

(
~pnoon2 = MIDIdef.cc(\pnoon2, {
	if(~pnopar2.isPlaying.not) {
		~pnopar2.play(t, quant: 0.5);
		"pno2 play".postln;
	}
}, 51, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~pnooff2 = MIDIdef.cc(\pnooff2, {
	if(~pnopar2.isPlaying) {
		~pnopar2.pause;
		"pno2 stop".postln;
	}
}, 51, srcID: ~nanoktrl2, argTemplate: 0);
);