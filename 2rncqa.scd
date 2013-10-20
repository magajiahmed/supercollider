( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl2 = 1310720;
);

s.meter;
t = TempoClock(88/60);
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

/*
(
SynthDef(\bass, { | curve = 0, dur = 1, freq = 100, level = 0.05, k = 1.4, width = 0.5 |
	var env				=	Env.perc(0.05, dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	SinOsc.ar([freq, freq + 0.1], mul: envgen);
	var klfn1			=	LFNoise1.kr(1, 0.001, 1);
	var saw1			=	LFSaw.ar([freq, freq + 0.2], mul: envgen / 2);
	var saw2			=	LFSaw.ar([freq, freq + 0.2] * klfn1, mul: envgen / 2);
	var sawmix			=	saw1 + saw2;
	var lpf				=	BLowPass4.ar(sawmix, freq * 8);
	var rhpf			=	RHPF.ar(sawmix, 8000, mul: 0.3);
	var n				=	1;
	var shapemix		=	Mix.fill(n, {
		var kbn2env		=	Env.new([0, 1, 1, 0], [0.01, dur, 0.1]);
		var kbn2envgen	=	EnvGen.kr(kbn2env, doneAction: 2);
		var kn1			=	LFNoise0.ar(0.1.dup).range(0.1, 10);
		var kn2			=	LFNoise0.ar(kn1, mul: envgen).range(0.01, 0.1);
		var kbn1		=	LFBrownNoise0.kr(1.dup).range(50, 100);
		var kbn2		=	LFBrownNoise1.kr(kbn1, mul: 0.1);
		var shape		=	SineShaper.ar(lpf + kbn2, kn2);
		shape / (n / 4);
	});
	Out.ar([0, 2], sin + shapemix);
}).add;
);
*/

(
SynthDef(\bass, { | dur = 1, freq = 100, k = 1.4, level = 0.03 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: -4);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	SinOsc.ar(freq, mul: envgen);
	var saw				=	LFSaw.ar(freq, mul: envgen);
	var sawflt			=	RLPF.ar(saw, freq * 2);
	var bn1				=	LFBrownNoise1.kr(0.3.dup).range(1, 15);
	var bn2				=	LFBrownNoise0.kr(bn1).range(0.5, 2);
	var shape			=	SineShaper.ar(sin + saw, 0.0005 * bn2);
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
		~basspat.play(t, quant: 0.5);
		"bass play".postln;
	} {
		~basspat.stop;
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
	var rhpf			=	RHPF.ar(bufrd, ffreq, 0.1, envgen * kbn1 * 2);
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
		~rbpdef.stop;
		"recbuf stop".postln;
	};
}, 48, srcID: ~nanoktrl2);
);

(
~pbktrl = MIDIdef.cc(\pbktrl, {
	if(~pbpat.isPlaying.not) {
		~pbpat.play(t, quant: 0.5);
		"playbuf play".postln;
	} {
		~pbpat.stop;
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
		\curve, Prand([-256, -64, -32], inf),
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
		~prc1apat.play(t, quant: 0.5);
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
			Pseq([0.25], 2),
			Pbrown(0.25, 2, 0.25, 8).round(0.25),
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
		~prc2apat.play(t, quant: 0.5);
		"prc2a play".postln;
	} {
		~prc2apat.stop;
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
		Array.fill(n, { arg i; (i + 23).nthPrime * 110 }) * lfn1, Array.fill(n, {0.2}), Array.fill(n, {0.01})
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
		\bits, Pwhite(10, 16, inf),
		\note, Pwrand([Rest, 1], [1, 2].normalizeSum, inf),
		\pan, Prand([-0.5, 0, 0.5], inf),
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
		~prc3pat.play(t, quant: 0.5);
		"prc3 play".postln;
	} {
		~prc3pat.pause;
		"prc3 stop".postln;
	};
}, 35, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// CRUMBLE

(
SynthDef(\crumble, { | gate = 1, level = 0.008 |
	var env				=	Env.asr(0.1, level, 0.1, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var klfn1			=	LFNoise0.kr(15.dup).range(0, 1);
	var klfn2			=	LFNoise0.kr(10.dup).range(0, 1);
	var bn				=	LFBrownNoise1.ar(5000.dup, mul: envgen * klfn1 * klfn2);
	var rez				=	RHPF.ar(bn, 1000 * LFNoise1.kr(15.dup, mul: 0.1, add: 1), 0.1);
	Out.ar(0, rez);
}).add;
);

// Pattern

(
~crumblepat =
Pdef(\crumblepat,
	Pmono(
		\crumble
));
);

/*
~crumblepat.play(t, quant: 1);
~crumblepat.isPlaying;
~crumblepat.pause;
*/

// Midi Control

(
~crumblektrl = MIDIdef.cc(\crumblektrl, {
	if(~crumblepat.isPlaying.not) {
		~crumblepat.play(t, quant: 0.5);
		"crumble play".postln;
	} {
		~crumblepat.stop;
		"crumble stop".postln;
	};
}, 36, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PLUNK

(
SynthDef(\plunk, { | dur = 1, freq = 400, level = 0.05, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: -8);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var fbenv			=	Env.new([0.999, 0.1], [0.05], 'sine');
	var fbenvgen		= 	EnvGen.kr(fbenv);
	var	kbn				=	LFBrownNoise0.kr(50).range(0.1, 1);
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

////////////////////////////////////////////////////////////////
// PAD /////////////////////////////////////////////////////////

// Synth

(
~pad =
SynthDef(\pad, { | curve = 0, dur = 1, freq = 400, gate = 1, level = 0.003 |
	var env				=	Env.asr(3, level, 3, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbnenv			=	LFBrownNoise0.kr(15).range(0.5, 1).round(0.1);
	var n				=	12;
	var mix				=	Mix.fill(n, {
		arg i;
		var klfn		=	LFNoise1.kr([0.1, 0.1], 0.001, 1);
		var freqgap		= 	3;
		var saw0		=	LFSaw.ar([freq, freq + (i / freqgap)] * klfn, mul: envgen / (i + 1));
		var saw1		=	LFSaw.ar([freq + ((i + 1) / freqgap), freq + ((i + 2) / freqgap)], mul: envgen / n);
		saw0 + saw1;
	});
	var lor				=	Lorenz2DC.ar(mul: 0.5, add: 1);
	var sin				=	SinOsc.ar(6000 * lor, mul: envgen / 6);
	var sinmix			=	mix + sin;
	var lpf				=	BLowPass4.ar(sinmix, freq * 8, 0.8);
	var rhpf			=	BHiPass4.ar(sinmix, 6000, 0.02, mul: 0.03);
	var filtmix			=	lpf + rhpf;
	var striated		=	filtmix * kbnenv;
	Out.ar(0, striated);
}).add;
);

// Pattern

(
~chords1 = (~scaledegrees ++ (~scaledegrees + ~scaledegrees.size)).powerset.reject({ arg i; i.size != 6 });
~chords1.size.postln;
~padpatdurarr = Array.fill(3, { arg i; (i + 3).nthPrime });
~padpat1 =
Pdef(\padpat1,
	Pbind(
		\instrument, \pad,
		\degree, Pseq([
			Prand(~chords1, 1), Rest,
			Prand(~chords1, 2), Rest,
			Prand(~chords1, 3), Rest
		], inf),
		\dur, Pshuf([7, 9, 11], inf),
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