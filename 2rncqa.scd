( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl2 = 1310720;
);

s.meter;
t = TempoClock(96/60);
t.tempo.postln;
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);

(
~ratios = [1/1, 15/14, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 14/9, 7/4];
~tuning = Tuning.new(~ratios.ratiomidi);
~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
);

////////////////////////////////////////////////////////
// BASS ////////////////////////////////////////////////

// SynthDef

(
SynthDef(\bass, { | dur = 1, freq = 100, k = 1.4, level = 0.03 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: -4);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	SinOsc.ar(freq, mul: envgen);
	var saw				=	LFSaw.ar(freq, mul: envgen);
	var sawflt			=	RLPF.ar(saw, freq * 2);
	var bn1				=	LFBrownNoise1.kr(1.dup).range(1, 50);
	var bn2				=	LFBrownNoise2.kr(bn1).range(0.5, 2);
	var shape			=	SineShaper.ar(sin + saw, 0.0003 * bn2);
	Out.ar([0, 2], sin + sawflt + shape).fold(-0.9, 0.9);
}).add;
);

// Pattern

(
~durations = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12];
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\degree, Pxrand([0, 1, 2, 3], inf),
		\dur, Prand(~durations, inf),
		\k, Pwhite(1.3, 1.5, inf),
		\octave, 3,
		\scale, ~scale,
));
);

/*
~basspat.play(t, quant: 0.5);
~basspat.isPlaying;
~basspat.pause;
*/

// Midi Control

(
~bassktrl = MIDIdef.cc(\bassktrl, {
	if(~basspat.isPlaying.not) {
		~basspat.play(t, quant: 1);
		"bass play".postln;
	} {
		~basspat.pause;
		"bass stop".postln;
	};
}, 32, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////
// BUFFER-STUTTER

(
SynthDef(\recbuf, { | dur = 2, gate = 1, inBus = 2, isRecording = 1, trigger = 1 |
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var in				=	In.ar(inBus, b.numChannels);
	var recbuf 			=	RecordBuf.ar(in, b.bufnum, recLevel: envgen, run: isRecording, loop: 0, trigger: trigger, doneAction: 2);
}).add;
);

(
SynthDef(\bufrd, { | dur = 1, ffreq = 3000, gate = 1, pan = 0 |
	var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(b.numChannels, b.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var rhpf			=	RHPF.ar(bufrd, ffreq, 0.5, envgen * kbn1 * 2);
	var pan2			=	Pan2.ar(rhpf, pan);
	Out.ar(0, pan2);
}).add;
);

(
~rbpdef =
Pdef(\rbpdef,
	Pbind(
		\instrument, \recbuf,
		\dur, 6,
));
);

/*
~rbpdef.play(t, quant: 3);
~rbpdef.isPlaying;
~rbpdef.pause;
b.plot;
*/

(
~pbpat =
Pdef(\pbpat,
	Pbind(
		\instrument, \bufrd,
		\dur, Prand([1, 1.5], inf),
		\pan, Prand([-0.5, 0, 0.5], inf)
));
);

/*
~pbpat.play(t, quant: 1.5);
~pbpat.isPlaying;
~pbpat.pause;
*/

// Midi Control

(
~rbktrl = MIDIdef.cc(\rbktrl, {
	if(~rbpdef.isPlaying.not) {
		~rbpdef.play(t, quant: 3);
		"recbuf play".postln;
	} {
		~rbpdef.pause;
		"recbuf stop".postln;
	};
}, 48, srcID: ~nanoktrl2);
);

(
~pbktrl = MIDIdef.cc(\pbktrl, {
	if(~pbpat.isPlaying.not) {
		~pbpat.play(t, quant: 1);
		"playbuf play".postln;
	} {
		~pbpat.pause;
		"playbuf stop".postln;
	};
}, 64, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC1

(
SynthDef(\prc1, { | bwr = 1, curve = -32, dur = 1, freq = 400, k = 1.4, level = 0.1, pan = 0 |
	var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var stan			=	Standard2DC.ar(k: k, mul: 1, add: 1);
	var sin				=	SinOsc.ar(freq * stan, mul: envgen);
	var lfn				=	LFNoise1.kr(1/(dur * 10), mul: 1, add: 1);
	var rez				=	Resonz.ar(sin, freq * lfn, bwr, 2);
	var pan2			=	Pan2.ar((sin / 3) + rez, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
~prcfrqarray = Array.fill(3, { arg i; (i.nthPrime).nthPrime * 400 });
~prc1apat =
Pdef(\prc1apdef,
	Pbind(
		\instrument, \prc1,
		\bwr, Prand([0.1, 0.5], inf),
		\curve, Prand([-256, -64], inf),
		\dur, Prand([Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, 1.5, 2, 3], inf),
		\freq, Prand(~prcfrqarray, inf),
		\k, Pwhite(1.2, 1.6, inf),
		\pan, Prand([-0.5, 0, 0, 0.5], inf)
));
);

/*
~prc1apat.play(t, quant: 0.5);
~prc1apat.isPlaying;
~prc1apat.pause;
*/


// Midi Control

(
~prc1aktrl = MIDIdef.cc(\prc1aktrl, {
	if(~prc1apat.isPlaying.not) {
		~prc1apat.play(t, quant: 1);
		"prc1a play".postln;
	} {
		~prc1apat.pause;
		"prc1a stop".postln;
	};
}, 33, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC2

(
SynthDef(\prc2, { | curve = -64, dur = 1, freq = 1000, level = 0.3, pan = 0 |
	var env				=	Env.perc(releaseTime: 0.5, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var bn				=	LFBrownNoise1.ar(freq, mul: envgen);
	var rez				=	RLPF.ar(bn, freq, 0.5);
	var pan2			=	Pan2.ar(rez, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
~prc2apat =
Pdef(\prc2apat,
	Pbind(
		\instrument, \prc2,
		\dur, Pxrand([
			Pseq([Pseq([0.125], 2), 0.75]),
			Pseq([Pseq([0.25], 2), 0.5]),
			Pbrown(0.25, 3, 0.25, 8).round(0.25),
			Pseq([Pseq([1/3], 3)])
		], inf),
		\freq, Pxrand([500, 1000, 5000], inf),
		\pan, Prand([-0.5, 0, 0.5], inf)
));
);

/*
~prc2apat.play(t, quant: 0.5);
~prc2apat.isPlaying;
~prc2apat.pause;
*/

// Midi Control

(
~prc2aktrl = MIDIdef.cc(\prc2aktrl, {
	if(~prc2apat.isPlaying.not) {
		~prc2apat.play(t, quant: 1);
		"prc2a play".postln;
	} {
		~prc2apat.pause;
		"prc2a stop".postln;
	};
}, 34, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC3

(
SynthDef(\prc3, { | bits = 24, curve = -64, dur = 1, freq = 4000, level = 0.3, pan = 0, rate = 44100 |
	var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var imp				=	Impulse.ar(0, envgen);
	var n				=	3;
	var lfn1			=	LFNoise1.ar(15).range(0.5, 2);
	var klank			=	DynKlank.ar(`[
		Array.fill(n, { arg i; (i + 23).nthPrime * 110 }) * lfn1,
		Array.fill(n, {0.2}),
		Array.fill(n, {0.01})
	], imp);
	var deci			=	Decimator.ar(klank, rate, bits);
	var pan2			=	Pan2.ar(deci, pan);
	Out.ar(0, pan2);
}).add;
);

Array.fill(3, { arg i; (i + 23).nthPrime * 100 });

//

(
~prc3pat =
Pdef(\prc3pat,
	Pbind(
		\instrument, \prc3,
		\dur, 1,
		\bits, Pwhite(8, 16, inf),
		\note, Pwrand([Rest, 1], [1, 2].normalizeSum, inf),
		\pan, Prand([-0.5, 0, 0.5], inf),
		\rate, Pwhite(0.75, 1, inf) * 44100,
));
);

/*
~prc3pat.play(t, quant: 1);
~prc3pat.isPlaying;
~prc3pat.pause;
*/

(
~prc3ktrl = MIDIdef.cc(\prc3ktrl, {
	if(~prc3pat.isPlaying.not) {
		~prc3pat.play(t, quant: 1);
		"prc3 play".postln;
	} {
		~prc3pat.pause;
		"prc3 stop".postln;
	};
}, 35, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC4

(
SynthDef(\prc4, { | bwr = 0.1, curve = -64, dur = 1, ffreq = 1000, freq = 5000, gate = 1, level = 0.02 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var bn				=	LFBrownNoise1.ar(freq.dup, mul: envgen);
	var rez				=	RHPF.ar(bn, ffreq * LFNoise1.kr(5.dup, mul: 0.3, add: 1), bwr);
	Out.ar(0, rez);
}).add;
);

// Pattern

(
~prc4pat1 =
Pdef(\prc4pat1,
	Pbind(
		\instrument, \prc4,
		\bwr, 0.05,
		\curve, -128,
		\dur, 1,
		\ffreq, 5000,
		\freq, 6000,
		\level, 0.05,
		\note, Prand([1, Rest], inf),
));
);

/*
~prc4pat1.play(t, quant: 1);
~prc4pat1.isPlaying;
~prc4pat1.pause;
*/


(
~prc4pat2 =
Pdef(\prc4pat2,
	Pbindf(
		~prc4pat1,
		// \bwr, 0.1,
		\curve, -64,
		\dur, Prand([Pseq([1/3], 3), Pseq([1/4], 4), Pseq([1/6], 6), 1, 2], inf),
		\ffreq, 3000,
		\freq, Pwhite(4000, 5000, inf),
		\level, Pwrand([0.25, 1] * 0.05, [6, 1].normalizeSum, inf),
		\note, Pwrand([1, Rest], [12, 8].normalizeSum, inf)
));
);

/*
~prc4pat2.play(t, quant: 1);
~prc4pat2.isPlaying;
~prc4pat2.pause;
*/

// Midi Control

(
~prc4pat1ktrl = MIDIdef.cc(\prc4pat1ktrl, {
	if(~prc4pat1.isPlaying.not) {
		~prc4pat1.play(t, quant: 1);
		"prc4-1 play".postln;
	} {
		~prc4pat1.pause;
		"prc4-1 stop".postln;
	};
}, 36, srcID: ~nanoktrl2);
);

(
~prc4pat2ktrl = MIDIdef.cc(\prc4pat2ktrl, {
	if(~prc4pat2.isPlaying.not) {
		~prc4pat2.play(t, quant: 1);
		"prc4-2 play".postln;
	} {
		~prc4pat2.pause;
		"prc4-2 stop".postln;
	};
}, 52, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PLUNK

(
SynthDef(\plunk, { | dur = 1, freq = 400, level = 0.05, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: -8);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var fbenv			=	Env.new([0.999, 0.1], [0.05], 'sine');
	var fbenvgen		= 	EnvGen.kr(fbenv);
	var	kbn				=	(LFBrownNoise0.kr(30).range(0, 1)).round(0.5);
	var sinfb			=	SinOscFB.ar(freq, fbenvgen, envgen * kbn);
	var pan2			=	Pan2.ar(sinfb, pan);
	Out.ar(0, pan2);
}).add;
);

/*
~plunk = Synth(\plunk);
*/

(
~plunkpat1 =
Pdef(\plunkpat1,
	Pbind(
		\instrument, \plunk,
		\dur, Prand([Pseq([0.125], 2), 0.25, Pseq([0.125], 4), 0.5, Pseq([0.125], 6), 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
		\degree, Prand([-3, -1, 0], inf),
		\octave, 5,
		\scale, ~scale,
));
);

/*
~plunkpat1.play(t, quant: 0.5);
~plunkpat1.isPlaying;
~plunkpat1.pause;
*/

(
~plunkpat2 =
Pdef(\plunkpat2,
	Pbindf(
		~plunkpat1,
		\degree, Prand([0, 1, 3, 5, Rest], inf),
));
);

/*
~plunkpat2.play(t, quant: 0.5);
~plunkpat2.isPlaying;
~plunkpat2.pause;
*/

(
~plunkpat3 =
Pdef(\plunkpat3,
	Pbindf(
		~plunkpat1,
		\degree, Prand([-3, -1, 0, 1, 2, 3, 5, Rest], inf),
		\octave, 6,
));
);

/*
~plunkpat3.play(t, quant: 0.5);
~plunkpat3.isPlaying;
~plunkpat3.pause;
*/

// Midi Control

(
~plunk1ktrl = MIDIdef.cc(\plunk1ktrl, {
	if(~plunkpat1.isPlaying.not) {
		~plunkpat1.play(t, quant: 0.5);
		"plunk1 play".postln;
	} {
		~plunkpat1.pause;
		"plunk1 stop".postln;
	};
}, 37, srcID: ~nanoktrl2);
);

(
~plunk2ktrl = MIDIdef.cc(\plunk2ktrl, {
	if(~plunkpat2.isPlaying.not) {
		~plunkpat2.play(t, quant: 1);
		"plunk2 play".postln;
	} {
		~plunkpat2.pause;
		"plunk2 stop".postln;
	};
}, 53, srcID: ~nanoktrl2);
);

(
~plunk3ktrl = MIDIdef.cc(\plunk3ktrl, {
	if(~plunkpat3.isPlaying.not) {
		~plunkpat3.play(t, quant: 1);
		"plunk3 play".postln;
	} {
		~plunkpat3.pause;
		"plunk3 stop".postln;
	};
}, 69, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// SINTH

(
SynthDef(\sinth, { | fb = 0, freq = 400, gate = 1, level = 0.1 |
	var env				=	Env.asr(sustainLevel: level, releaseTime: 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbn1a			=	LFBrownNoise0.kr(0.5.dup).range(0.5, 15);
	var kbn1b			=	LFBrownNoise0.kr(kbn1a, mul: 0.003, add: 1);
	var sin				=	SinOsc.ar(freq * kbn1b, mul: envgen);
	var kbn2			=	LFBrownNoise0.kr(13.dup).range(0, 0.999);
	var sinfb			=	SinOscFB.ar([freq, freq + 0.2], kbn2, envgen);
	var shape			=	SineShaper.ar(sin + sinfb, 0.005);
	Out.ar(0, shape);
}).add;
);

//

(
~sinpat =
Pdef(\sinpat,
	Pmono(
		\sinth,
		\degree, Prand(~scaledegrees, 31),
		\dur, Prand([
			Pseq([0.125], 2), 0.25,
			Pseq([0.125, 0.25, 0.125]), 0.5,
			Pseq([0.125, 0.25, 0.25, 0.125]), 0.75,
			Pseq([0.125, 0.25, 0.25, 0.25, 0.125]), 1,
			1.5, 2, 3, 4, 6, 8, 12
		], inf),
		\octave, Prand([5, 6], inf),
		\scale, ~scale,
));
);

/*
~sinpat.playOnce(t, quant: 1);
~sinpat.isPlaying;
~sinpat.pause;
*/

//

(
~sinthktrl =
MIDIdef.cc(\sinthktrl, {
	if(~sinpat.isPlaying) {
		~sinpat.pause;
		"sinpat stop"
	} {
		~sinpat.play(t, quant: 1);
		"sinpat play"
	}
}, 38, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PAD /////////////////////////////////////////////////////////

// Synth

(
~pad =
SynthDef(\pad, { | curve = 0, dur = 1, freq = 400, gate = 1, level = 0.005 |
	var env				=	Env.asr(5, level, 5, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbnenv1			=	(LFBrownNoise0.kr(15).range(0, 1)).round(0.25);
	var kbnenv2			=	(LFBrownNoise1.kr(15).range(0, 1)).round(1);
	var klfn			=	LFNoise1.kr(0.1.dup, 0.005, 1);
	var saw0			=	LFSaw.ar(freq.dup, mul: envgen / 2);
	var saw1			=	LFSaw.ar(freq.dup * klfn, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var bn				=	LFBrownNoise1.kr(7).range(0.5, 2);
	var shape			=	SineShaper.ar(sawmix, 0.005 * bn);
	var lpf				=	BLowPass4.ar(shape, freq * 4, 1, kbnenv1);
	var rhpf			=	BHiPass4.ar(shape, 6000, 0.1, mul: kbnenv2 / 4);
	var filtmix			=	lpf + rhpf;
	Out.ar(0, filtmix);
}).add;
);

// Pattern

(
~chords1 = (~scaledegrees ++ (~scaledegrees + ~scaledegrees.size)).powerset.reject({ arg i; i.size != 5 });
~chords1.size.postln;
);

(
~padpat1 =
Pdef(\padpat1,
	Pbind(
		\instrument, \pad,
		\degree, Pseq([
			Prand(~chords1, 1), Rest,
			Prand(~chords1, 2), Rest,
			Prand(~chords1, 3), Rest
		], inf),
		\dur, Pshuf([11, 13, 15], inf),
		\level, 0.02,
		\octave, 5,
		\scale, ~scale,
));
);

/*
~padpat1.play(t, quant: 1);
~padpat1.isPlaying;
~padpat1.pause;
*/

// Midi Control

(
~pad1ktrl = MIDIdef.cc(\pad1ktrl, {
	if(~padpat1.isPlaying.not) {
		~padpat1.play(t, quant: 1);
		"pad1 play".postln;
	} {
		~padpat1.pause;
		"pad1 stop".postln;
	};
}, 39, srcID: ~nanoktrl2);
);