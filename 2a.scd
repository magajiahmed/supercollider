////////////////////////////////////////////////////////////////
// INIT 

// clear all patterns

Pdef.removeAll;

( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl2 = 1310720;
);

s.meter;
t = TempoClock(108/60);
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
	var bn2				=	LFBrownNoise0.kr(bn1).range(0.5, 2);
	var shape			=	SineShaper.ar(sin + saw, 0.0003 * bn2);
	Out.ar([0, 2], sin + sawflt + shape).fold(-0.9, 0.9);
}).add;
);

// Pattern

(
~durations = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 32];
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\degree, Pxrand([-1, 0, 1, 2, 3], inf),
		\dur, Prand(~durations, inf),
		\k, Pwhite(1.3, 1.5, inf),
		\octave, 3,
		\scale, ~scale,
));
);

/*
~basspat.play(t, quant: 1);
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
SynthDef(\prc1, { | bwr = 1, curve = -64, dur = 1, freq = 400, k = 1.4, level = 0.05, pan = 0 |
	var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var stan			=	Standard2DC.ar(3, 3000, k: k, mul: 1, add: 1);
	var fbfreqmod		=	LFNoise0.kr(0.5).range(1, 30);
	var fbmod			=	LFNoise1.kr(fbfreqmod).range(0, 0.999);
	var sinfb			=	SinOscFB.ar(freq * stan, 0.999, mul: envgen);
	var lfn				=	LFNoise1.kr(1 / (dur * 10), mul: 1, add: 1);
	var rez				=	Resonz.ar(sinfb, freq, bwr, 2);
	var pan2			=	Pan2.ar((sinfb / 3) + rez, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
~prc1frqarray1 = Array.fill(3, { arg i; (i.nthPrime).nthPrime * 100 }).postln;
~prc1apat =
Pdef(\prc1apdef,
	Pbind(
		\instrument, \prc1,
		\bwr, Prand([0.1, 0.5], inf),
		\dur, Prand([
			Pseq([0.125], 2), 0.25, 0.5, 0.75,
			Pseq([1/3], 3), 1, 1.5, Pseq([2/3], 3), 2, Pseq([0.75], 4), 3, 4, 6
		], inf),
		\freq, Prand(~prc1frqarray1, inf),
		\k, Pwhite(1.2, 1.6, inf),
		\note, Pwrand([Rest, 1], [1, 3].normalizeSum, inf),
		\pan, Prand([-0.5, 0, 0, 0.5], inf)
));
);

/*
~prc1apat.play(t, quant: 1);
~prc1apat.isPlaying;
~prc1apat.pause;
*/

(
~prc1frqarray2 = (~prc1frqarray1 * 4).postln;
~prc1bpat =
Pdef(\prc1bpdef,
	Pbindf(~prc1apat,
		\curve, -256,
		\freq, Prand(~prc1frqarray2, inf),
		\level, 0.1
));
);

/*
~prc1bpat.play(t, quant: 1);
~prc1bpat.isPlaying;
~prc1bpat.pause;
*/

(
~prc1frqarray3 = (~prc1frqarray1 / 8).postln;
~prc1cpat =
Pdef(\prc1cpdef,
	Pbindf(~prc1apat,
		\curve, -256,
		\freq, Prand(~prc1frqarray3, inf),
		\level, 0.1
));
);

/*
~prc1cpat.play(t, quant: 1);
~prc1cpat.isPlaying;
~prc1cpat.pause;
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

(
~prc1bktrl = MIDIdef.cc(\prc1bktrl, {
	if(~prc1bpat.isPlaying.not) {
		~prc1bpat.play(t, quant: 1);
		"prc1b play".postln;
	} {
		~prc1bpat.pause;
		"prc1b stop".postln;
	};
}, 49, srcID: ~nanoktrl2);
);

(
~prc1cktrl = MIDIdef.cc(\prc1cktrl, {
	if(~prc1cpat.isPlaying.not) {
		~prc1cpat.play(t, quant: 1);
		"prc1c play".postln;
	} {
		~prc1cpat.pause;
		"prc1c stop".postln;
	};
}, 65, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC2A

(
SynthDef(\prc2a, { | a = 1, cfreq = 1000, curve = -16, dur = 1, freq = 1000, level = 0.15, pan = 0 |
	var env				=	Env.perc(releaseTime: 0.5, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq, a, add: 1);
	var sin				=	SinOsc.ar(freq * cusp, mul: envgen);
	var pan2			=	Pan2.ar(sin, pan);
	Out.ar(0, pan2);
}).add;
);

(
~prc2apat =
Pdef(\prc2apat,
	Pbind(
		\instrument, \prc2a,
		\a, Pwhite(0.9, 1.1, inf),
		\dur, Pxrand([0.25, 0.5, 0.75, Pseq([1/3], 3), 1, 2, Pseq([0.75], 4), 3, Pseq([1], 6)], inf),
		\freq, Pwrand([200, 500, 1000, Pseq([Pwhite(1400, 1600, 1), Pwhite(900, 1100, 1)], 2)], [4, 2, 1].normalizeSum, inf),
		\note, Pwrand([Rest, 1], [1, 4].normalizeSum, inf)
));
);

/*
~prc2apat.play(t, quant: 1);
~prc2apat.isPlaying;
~prc2apat.pause;
*/

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
// PRC2B

(
SynthDef(\prc2b, { | curve = -8, dur = 1, freq = 1000, level = 0.3, pan = 0 |
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
~prc2bpat =
Pdef(\prc2bpat,
	Pbind(
		\instrument, \prc2b,
		\dur, Pxrand([
			Pseq([Pseq([0.125], 2), 0.75]),
			Pseq([Pseq([0.25], 2), 0.5]),
			Pbrown(0.25, 2, 0.25, 8).round(0.25),
			Pseq([Pseq([1/3], 3)])
		], inf),
		\freq, Pxrand([500, 1000, 5000], inf),
		\pan, Prand([-0.5, 0, 0.5], inf)
));
);

/*
~prc2bpat.play(t, quant: 1);
~prc2bpat.isPlaying;
~prc2bpat.pause;
*/

// Midi Control

(
~prc2bktrl = MIDIdef.cc(\prc2bktrl, {
	if(~prc2bpat.isPlaying.not) {
		~prc2bpat.play(t, quant: 1);
		"prc2b play".postln;
	} {
		~prc2bpat.pause;
		"prc2b stop".postln;
	};
}, 50, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC2C

(
SynthDef(\prc2c, { | curve = -16, freq = 400, level = 0.8, pan = 0 |
	var env				=	Env.perc(0.005, 1, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var clip			=	ClipNoise.ar(envgen);
	var xline			=	XLine.kr(1, 0.3, 0.05);
	var stan			=	Standard2DC.ar.clip(0.05, 0.5);
	var rez				=	Resonz.ar(clip, freq * xline, stan);
	var pan2			= 	Pan2.ar(rez, pan);
	Out.ar(0, pan2);
}).add;
);

(
~prc2cpat =
Pdef(\prc2cpat,
	Pbind(
		\instrument, \prc2c,
		\curve, Prand([-64, -32, -16], inf),
		\dur, Prand([0.25, 0.5, 0.75, Pseq([1/3], 3), Pseq([0.75], 4)], inf),
		\freq, Pxrand([100, 120, 130, 500, 520, 530, 1000, 1200, 1300], inf),
		\pan, Prand([-0.5, 0, 0.5], inf),
));
);

/*
~prc2cpat.play(t, quant: 1);
~prc2cpat.isPlaying;
~prc2cpat.pause;
*/

(
~prc2cktrl = MIDIdef.cc(\prc2cktrl, {
	if(~prc2cpat.isPlaying.not) {
		~prc2cpat.play(t, quant: 1);
		"prc2c play".postln;
	} {
		~prc2cpat.pause;
		"prc2c stop".postln;
	};
}, 66, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC3A

(
SynthDef(\prc3a, { | bits = 24, curve = -64, dur = 1, freq = 4000, level = 0.3, pan = 0, rate = 44100 |
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
	var rez				=	Resonz.ar(deci, 4000, 0.1);
	var pan2			=	Pan2.ar(rez, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
~prc3apat =
Pdef(\prc3apat,
	Pbind(
		\instrument, \prc3a,
		\dur, 1,
		\bits, Pwhite(8, 16, inf),
		//\note, Pwrand([Rest, 1], [3, 2].normalizeSum, inf),
		\pan, Prand([-0.5, 0, 0.5], inf),
		\rate, Pwhite(0.75, 1, inf) * 44100,
));
);

/*
~prc3apat.play(t, quant: 1);
~prc3apat.isPlaying;
~prc3apat.pause;
*/

(
~prc3aktrl = MIDIdef.cc(\prc3aktrl, {
	if(~prc3apat.isPlaying.not) {
		~prc3apat.play(t, quant: 1);
		"prc3a play".postln;
	} {
		~prc3apat.pause;
		"prc3a stop".postln;
	};
}, 35, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC3B

(
SynthDef(\prc3b, { | curve = -16, dur = 1, freq = 1000, level = 0.1 |
	//var env				=	Env.perc(releaseTime: 0.1, level: level, curve: curve);
	var env				=	Env.new([0, level, level / 32, 0], [0.003, 0.01, dur / 4], 'sin');
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var n				=	3;
	var mixfill			=	Mix.fill(n, {
		var kbn1		=	LFBrownNoise2.kr(0.5).range(5, 50);
		var kbn2		=	LFBrownNoise1.kr(kbn1.dup).range(0.5, 1);
		var sin			=	FSinOsc.ar(freq * kbn2, mul: envgen / n);
		sin;
	});
	Out.ar(0, mixfill);
}).add;
);

(
~prc3bfrqarray = Array.fill(5, { arg i; 4000 + (i * 2000) });
~prc3bpat =
Pdef(\prc3bpat,
	Pbind(
		\instrument, \prc3b,
		\dur, Prand([Pseq([0.125], 2), 0.5, 0.75, Pseq([1/3], 3), 4, 6, 8, 12], inf),
		\freq, Pseq([Pxrand(~prc3bfrqarray).repeat(3)], inf),
		\level, 0.1
));
);

/*
~prc3bpat.play(t, quant: 1);
~prc3bpat.isPlaying;
~prc3bpat.pause;
*/

(
~prc3bktrl = MIDIdef.cc(\prc3bktrl, {
	if(~prc3bpat.isPlaying.not) {
		~prc3bpat.play(t, quant: 1);
		"prc3b play".postln;
	} {
		~prc3bpat.pause;
		"prc3b stop".postln;
	};
}, 51, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC4

(
SynthDef(\prc4, { | a = 0.1, b = 3, curve = -16, dur = 1, freq = 10000, level = 0.5, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq, a, b, add: 1);
	var sin				=	SinOsc.ar(freq * (cusp), mul: envgen);
	var rez				=	Resonz.ar(sin, 6000, 0.1);
	var pan2			=	Pan2.ar(rez, pan);
	Out.ar(0, pan2).fold(-0.5, 0.5);
}).add;
);

// Pattern

(
~prc4pat1 =
Pdef(\prc4pat1,
	Pbind(
		\instrument, \prc4,
		\curve, -256,
		\dur, Prand([
			Pseq([0.75], 17),
			Pseq([1.25], 17),
			Pseq([1.75], 17)
		], inf),
		\freq, 8000,
		\note, Pwrand([1, Rest], [4, 1].normalizeSum, inf),
		\xaos, 1
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
	Pbind(
		\instrument, \prc4,
		\a, Pwhite(0, 1, inf),
		\b, Pwhite(0, 1.9, inf),
		\curve, -16,
		\dur, Prand([Pseq([1/6], 6), Pseq([1/4], 4), Pseq([1/3], 3), Pseq([0.5], 2), 1, Pseq([2/3], 3), 2], inf),
		\freq, 6000,
		\level, Pwrand([0.5, 1] * 0.1, [6, 1].normalizeSum, inf),
		\note, Prand([1, Rest], inf),
		\xaos, Pwhite(1.5, 1.999, inf)
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
SynthDef(\plunk, { | dur = 1, freq = 400, level = 0.1, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: -8);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var fbenv			=	Env.new([0.999, 0.1], [0.05], 'sine');
	var fbenvgen		= 	EnvGen.kr(fbenv);
	var	kbn				=	(LFBrownNoise0.kr(30).range(0, 1)).round(0.5);
	var sinfb			=	SinOscFB.ar(freq, fbenvgen, envgen * kbn);
	var shape			=	SineShaper.ar(sinfb, 0.01);
	var rlpf			=	RLPF.ar(shape, freq * 2, 0.5);
	var rhpf			=	RHPF.ar(shape, 8000, 0.05);
	var flts			=	rlpf + rhpf;
	var pan2			=	Pan2.ar(flts, pan);
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
		\dur, Prand([
			Pseq([1/6], 3), 0.5, 1,
			1.5, 2, 3, 4, 6, 8, 12, 16, 24
		], inf),
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
// PENGUIN

(
SynthDef(\penguin, { | freq = 400, gate = 1, level = 0.1 |
	var env				=	Env.asr(sustainLevel: level, releaseTime: 3);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var tri				=	LFTri.ar(freq, mul: envgen);
	var kbnfm			=	LFNoise0.kr(1).range(1, 10);
	var kbn				=	LFBrownNoise2.kr(kbnfm.dup).range(0.003, 0.005);
	var shape			=	SineShaper.ar(tri, kbn);
	var lpf				=	BLowPass4.ar(shape, freq * 2);
	var hpf				=	HPF.ar(shape, 4000);
	Out.ar(0, lpf + hpf);
}).add;
);

(
~pgndegrees = [0, 1, 2, 3];
~pgnpat =
Pdef(\pgnpat,
	Pmono(
		\penguin,
		\degree, Prand(~pgndegrees, inf),
		// \dur, Prand([
		// 	Pseq([0.25], 2),
		// 	Pseq([0.25, 0.5, 0.25]),
		// 	Pseq([0.25, 0.5, 0.5, 0.25]),
		// 	8, 12, 16, 24, 32, 48
		// ], inf),
		\dur, Pseq([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24], inf),
		\octave, Pxrand([5, 6], inf),
		\scale, ~scale,
));
);

/*
~pgnpat.play(t, quant: 1);
~pgnpat.isPlaying;
~pgnpat.pause;
*/

(
~pgnktrl =
MIDIdef.cc(\pgnktrl, {
	if(~pgnpat.isPlaying.not) {
		~pgnpat.play(t, quant: 1);
		"pgnpat play".postln;
	} {
		~pgnpat.pause;
		"pgnpat pause".postln;
	}
}, 38, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// SINTH

~shaperbuf = Buffer.alloc(s, 512, 1, { |buf| buf.chebyMsg([1,0,1,1,0,1])});

(
SynthDef(\sinth, { | fb = 0, freq = 400, gate = 1, level = 0.05 |
	var env				=	Env.asr(sustainLevel: level, releaseTime: 2);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbn1a			=	LFBrownNoise0.kr(0.5.dup).range(0.5, 2);
	var kbn1b			=	LFBrownNoise2.kr(kbn1a, mul: 0.003, add: 1);
	var sin				=	SinOsc.ar(freq * kbn1b, mul: envgen);
	var kbn2			=	LFBrownNoise2.kr(1.3.dup).range(0, 0.999);
	var sinfb			=	SinOscFB.ar([freq, freq + 0.2], kbn2, envgen);
	var shape			=	SineShaper.ar(sin + sinfb, 0.003);
	var lpf				=	RLPF.ar(shape, freq * 2);
	var rhpf			=	RHPF.ar(shape, (freq * 16).clip(50, SampleRate.ir / 3), 0.03);
	Out.ar(0, lpf + rhpf);
}).add;
);

//

(
~sinpat =
Pdef(\sinpat,
	Pmono(
		\sinth,
		\degree, Prand(~scaledegrees, inf),
		\dur, Prand([
			Pseq([0.25], 2), 0.5,
			Pseq([0.25, 0.5, 0.25]), 1,
			Pseq([0.25, 0.5, 0.5, 0.25]), 1.5,
			Pseq([0.25, 0.5, 0.5, 0.5, 0.25]), 2,
			3, 4, 6, 8, 12, 16, 24
		], inf),
		\octave, 6,
		\scale, ~scale,
));
);

/*
~sinpat.play(t, quant: 1);
~sinpat.isPlaying;
~sinpat.pause;
*/

//

(
~sinthktrl =
MIDIdef.cc(\sinthktrl, {
	if(~sinpat.isPlaying.not) {
		~sinpat.play(t, quant: 1);
		"sinpat play".postln;
	} {
		~sinpat.pause;
		"sinpat pause".postln;
	}
}, 70, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PAD1

/*
(
SynthDef(\pad1, { | freq = 400, gate = 1, level = 0.01 |
	// var env				=	Env.asr(0.05, level, 2, 0);
	// var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var env				=	Env.perc(releaseTime: 4, level: level, curve: -64);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var n 				=	8;
	var mixfill			=	Mix.fill(n, {
		var lfn			=	LFBrownNoise2.kr(1.5.dup, mul: 0.00001, add: 1);
		var sinfb		=	SinOscFB.ar(freq.dup, 0.99, envgen / n);
		sinfb;
	});
	var deci 			=	Decimator.ar(mixfill * 32, 5000, bits: 3, mul: envgen);
	var lpf				=	BLowPass4.ar(mixfill, freq * 8);
	var rhpf			=	RHPF.ar(deci, 4000, 0.05);
	var kbnenv			=	LFBrownNoise0.kr(25.dup).range(0.25, 1).round(0.25);
	Out.ar(0, (lpf + rhpf));
}).add;
);
*/

(
SynthDef(\pad1, { | freq = 400, gate = 1, level = 0.05 |
	var env				=	Env.new([0, level, level / 96, 0], [0.01, 0.1, 3]);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var mixfill			=	Mix.fill(4, {
		var noiz		=	LFNoise0.ar(freq.dup, mul: 0.02, add: 1);
		var sin 		=	LFTri.ar([freq, freq + 1] * noiz, mul: envgen / 4);
		sin;
	});
	var shape			=	SineShaper.ar(mixfill, 0.008);
	var lpf				=	BLowPass4.ar(shape, freq);
	var rhpf			=	RHPF.ar(shape, 8000, 0.05);
	var kbnenv			=	LFBrownNoise0.kr(13.dup).range(0.3, 1);
	Out.ar(0, (lpf + rhpf) * kbnenv);
}).add;
);

(
~padchords1 = ~scaledegrees.powerset.reject({ arg i; i.size != 6 });
//~padchords1 = Array.fill(7, { arg i; [i, i + 7] });
~paddegrees = [0, 1, 2, 3, 7];
~pad1pat =
Pdef(\pad1pat,
	Pbind(
		\instrument, \pad1,
		// \degree, Pseq([
		// 	Pbrown(0, 3, 1, 1), Rest,
		// 	Pbrown(0, 3, 1, 2), Rest,
		// 	Pbrown(0, 3, 1, 3), Rest,
		// ],  inf),
		// \degree, Pseq([
		// 	Pswitch1(~padchords1, Pbrown(0, ~padchords1.size, 2, 1)), Rest,
		// 	Pswitch1(~padchords1, Pbrown(0, ~padchords1.size, 2, 2)), Rest,
		// 	Pswitch1(~padchords1, Pbrown(0, ~padchords1.size, 2, 3)), Rest,
		// ], inf),
		\degree, Pseq([Pswitch1(~padchords1, Pbrown(0, ~padchords1.size, 2, 1)), Rest], inf),
		\dur, Pseq([0.25, 3, 0.25, 5, 0.25, 7, 0.25, 9, 0.25, 11], inf),
		\octave, 8,
		\scale, ~scale,
));
);

/*
~pad1pat.play(t, quant: 1);
~pad1pat.isPlaying;
~pad1pat.pause;
*/

(
~pad1ktrl = MIDIdef.cc(\pad1ktrl, {
	if(~pad1pat.isPlaying.not) {
		~pad1pat.play(t, quant: 1);
		"pad1 play".postln;
	} {
		~pad1pat.pause;
		"pad1 stop".postln;
	};
}, 39, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PAD2 ////////////////////////////////////////////////////////

// Synth

(
~pad2 =
SynthDef(\pad2, { | curve = -4, dur = 1, freq = 400, gate = 1, level = 0.005 |
	var env				=	Env.asr(3, level, 7, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbnenv1			=	(LFBrownNoise0.kr(15).range(0.25, 1).round(0.25));
	var kbnenv2			=	(LFBrownNoise1.kr(15).range(0, 1)).round(0.5);
	var klfn			=	LFNoise1.kr(0.1.dup, 0.001, 1);
	var saw0			=	LFSaw.ar(freq.dup, mul: envgen / 2);
	var saw1			=	LFSaw.ar(freq.dup * klfn, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var bn				=	LFNoise0.ar(1, 0.1);
	var mixfill			=	Mix.fill(4, {
		var kbnshaper		=	LFBrownNoise1.kr(15.dup).range(0.5, 2);
		var shape			=	SineShaper.ar(sawmix + bn, 0.002 * kbnshaper);
		shape;
	});
	var lpf				=	BLowPass4.ar((sawmix / 4) + mixfill, freq, 1, kbnenv1);
	var rhpf			=	BHiPass4.ar((sawmix / 4) + mixfill, 6000, 0.05, mul: kbnenv2);
	var filtmix			=	lpf + rhpf;
	Out.ar(0, filtmix);
}).add;
);

// Pattern

(
~padchords2 = ~scaledegrees.powerset.reject({ arg i; i.size != 4 });
~padchords2.size.postln;
);

(
~pad2pat =
Pdef(\pad2pat,
	Pbind(
		\instrument, \pad2,
		\degree, Pseq([
		 	Prand(~padchords2, 1), Rest,
		 	Prand(~padchords2, 2), Rest,
		 	Prand(~padchords2, 3), Rest
		 ], inf),
		\dur, Pshuf([11, 13, 15], inf),
		\level, 0.01,
		\octave, 5,
		\scale, ~scale,
));
);

/*
~pad2pat.play(t, quant: 1);
~pad2pat.isPlaying;
~pad2pat.pause;
*/

// Midi Control

(
~pad2ktrl = MIDIdef.cc(\pad2ktrl, {
	if(~pad2pat.isPlaying.not) {
		~pad2pat.play(t, quant: 1);
		"pad2 play".postln;
	} {
		~pad2pat.pause;
		"pad2 stop".postln;
	};
}, 71, srcID: ~nanoktrl2);
);
