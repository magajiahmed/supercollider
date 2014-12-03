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
//~nanoktrl2 = 1835008;
//~nanoktrl2 = 1572864;
);

(
s.meter;
t = TempoClock(96/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);
);

(
~ratios = [1/1, 15/14, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 14/9, 7/4];
~tuning = Tuning.new(~ratios.ratiomidi);
~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
);

~pulsedurarray = [Pseq([0.25], 53), Pseq([0.25], 31), Pseq([1/3], 3), Pseq([2/5], 5)];

////////////////////////////////////////////////////////
// RECORDING

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////
// COMPANDER

(
SynthDef(\dynamix, {
	var in	   		= 	In.ar(4, 2);
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.001, slopeAbove: 1/128); // compressor
	Out.ar(0, compressor);
}).add;
);

(
~startdynamix = {
	s.sync;
	~dynamix = Synth(\dynamix).register;
}.fork;
);

/*
~dynamix.isPlaying;
~dynamix.free;
*/

////////////////////////////////////////////////////////
// BASS ////////////////////////////////////////////////

// SynthDef

// (
// SynthDef(\bass, { | dur = 1, freq = 100, level = 0.02 |
// 	var env				=	Env.perc(releaseTime: dur, level: level, curve: -4);
// 	var envgen			=	EnvGen.kr(env, doneAction: 2);
// 	var sin				=	SinOsc.ar(freq, mul: envgen);
// 	var saw				=	LFSaw.ar(freq, mul: envgen);
// 	var sawflt			=	RLPF.ar(saw, freq * 3, 0.2);
// 	var dkfrqs			=	Array.fill(4, { arg i; (i + pi) * freq });
// 	var dkamps			=	Array.fill(4, { arg i; 0.2 });
// 	var dkrts			=	Array.fill(4, { 1 });
// 	var dynklank		=	DynKlank.ar(`[dkfrqs, dkamps, dkrts], saw);
// 	// var bn1				=	LFBrownNoise1.kr(1.dup).range(1, 50);
// 	// var bn2				=	LFBrownNoise0.kr(bn1).range(0.5, 2);
// 	// var shape			=	SineShaper.ar(sin + saw, 0.005 * bn2);
// 	// var bn				=	LFBrownNoise1.ar(freq.dup).range(0.75, 1.5);
// 	// var shapeflt		=	RLPF.ar(shape, 9000 * bn, 0.05, 0.25);
// 	Out.ar([0, 2], sin + dynklank).fold(-0.9, 0.9);
// }).add;
// );

(
SynthDef(\bass, { arg a = 1, dur = 1, freq = 100, level = 0.03;
 	var env				=	Env.perc(releaseTime: dur, level: level, curve: -4);
 	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var tri				=	LFTri.ar(freq, mul: envgen);
	var tri2			=	LFTri.ar(freq / 2, mul: envgen);
	var lat				=	Latoocarfian2DC.ar(a: [a, a - 0.01], mul: 0.5, add: 1);
	var sin1			=	SinOsc.ar(freq * lat, mul: 100, add: 1);
	var sin2			=	SinOsc.ar(freq, sin1, mul: envgen / 10);
	var rlpf 			=	RLPF.ar(sin2, freq * 2);
	var rhpf			=	RHPF.ar(sin2, 5000, 0.1);
	Out.ar([0, 2], tri + tri2 + rlpf + rhpf);
}).add;
);


// Pattern

(
~bassdurations = [0.25, 0.5, Pseq([0.25], 3), 0.75, 1, 1.5, 2, Pseq([0.75], 4), 3, 4, 6, 8, 12, 16, 24];
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\a, Pwhite(0.9, 1.1, inf),
		\degree, Pshuf([-1, 0, 1, 2, 3].stutter(3), inf),
		\dur, Pshuf(~bassdurations, inf),
		\legato, 0.1,
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
		\ffreq, 3000,
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
// PRC2A

(
SynthDef(\prc2a, { | a = 1, curve = -8, dfrq = 2000, dur = 1, freq = 1000, level = 0.08, pan = 0 |
	var env				=	Env.perc(releaseTime: 0.15, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq, a, add: 1);
	var lfn				=	LFNoise0.ar(15).range(0, 1);
	var sin				=	SinOsc.ar(freq * cusp, mul: envgen);
	var sin2			=	sin.round(0.01) / 2;
	var rez				=	Resonz.ar(sin, freq, 0.05, 4);
	var pan2			=	Pan2.ar(sin2 + rez, pan);
	Out.ar(4, pan2);
}).add;
);

(
~prc2apatfrq1 = 50;
~prc2apatfrq2 = 5000;
~prc2apat1 =
Pdef(\prc2apat,
	Pbind(
		\instrument, \prc2a,
		\a, Pshuf([1, 2, 3, 1.1, 2.1, 3.1], inf),
		\dfrq, Pwhite(100, 8000, inf),
		\dur, Prand([Pseq([0.25], 3), Pseq([0.25], 5), Pseq([0.5, 0.75], 3)], inf),
		\freq, Pshuf([
			Pseq([~prc2apatfrq1, ~prc2apatfrq2, ~prc2apatfrq2]),
			Pseq([~prc2apatfrq2, ~prc2apatfrq1, ~prc2apatfrq2]),
			Pseq([~prc2apatfrq2, ~prc2apatfrq2, ~prc2apatfrq1]),
			Pseq([~prc2apatfrq2, ~prc2apatfrq2, ~prc2apatfrq2])
		].stutter(11), inf),
		// \freq, Prand([~prc2apatfrq1, ~prc2apatfrq2], inf),
		//\level, Pwhite(0.5, 1, inf) * 0.08,
		\level, 0.3,
		//\pan, Pshuf([Pseq([-0.25], 3), Pseq([0], 3), Pseq([0.25], 3)], inf),
));
);

/*
~prc2apat1.play(t, quant: 1);
~prc2apat1.isPlaying;
~prc2apat1.pause;
*/

(
~prc2apat1a = Pdef(\prc2pat1a, Pbindf(~prc2apat1, \level, 0.06, \pan, -1));
~prc2apat1b = Pdef(\prc2pat1b, Pbindf(~prc2apat1a, \pan, 1));
~prc2apar = Pdef(\prc2apar, Ppar([~prc2apat1, ~prc2apat1a, ~prc2apat1b], inf));
);

/*
~prc2apar.play(t, quant: 1);
~prc2apar.isPlaying;
~prc2apar.pause;
*/

(
~prc2aktrl = MIDIdef.cc(\prc2aktrl, {
	if(~prc2apar.isPlaying.not) {
		~prc2apar.play(t, quant: 1);
		"prc2a play".postln;
	} {
		~prc2apar.pause;
		"prc2a stop".postln;
	};
}, 34, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC3C

// Synth

(
SynthDef(\prc3c, { | curve = -512, dur = 1, freq = 400, im = 1, level = 0.1, rt = 0.1 |
	var env				=	Env.new([0, level, level / 40, 0], [0.005, 0.005, dur], curve: 'cubed');
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var fbs				=	FBSineC.ar(freq: freq, im: [im, im + 1], mul: envgen);
	var flt				=	RHPF.ar(fbs, 2000, 0.5);
	Out.ar(4, flt);
}).add;
);

// Pattern

(
~prc3cpat =
Pdef(\prc3cpat,
	Pbind(
		\instrument, \prc3c,
		\degree, [2, 7],
		\dur, Pshuf([0.5, 0.75].stutter(7), inf),
		\im, Pshuf((1..10), inf),
		\level, 0.05,
		\octave, 10,
		\scale, ~scale,
));
);

/*
~prc3cpat.play(t, quant: 1);
~prc3cpat.isPlaying;
~prc3cpat.pause;
*/

// Midi control

(
~prc3cktrl = MIDIdef.cc(\prc3cktrl, {
	if(~prc3cpat.isPlaying.not) {
		~prc3cpat.play(t, quant: 1);
		"prc3c play".postln;
	} {
		~prc3cpat.pause;
		"prc3c stop".postln;
	};
}, 67, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC4

(
SynthDef(\prc4, { | a = 0.02, curve = -16, freq = 10000, level = 0.2, pan = 0 |
	var env				=	Env.perc(releaseTime: 1, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq * 4, a, 3, add: 1);
	var sin				=	SinOsc.ar(freq * (cusp), mul: envgen);
	var rez				=	Resonz.ar(sin, 6000, 0.1);
	var pan2			=	Pan2.ar(rez, pan);
	Out.ar(4, pan2).fold(-0.5, 0.5);
}).add;
);

// Pattern

(
~prc4pat1 =
Pdef(\prc4pat1,
	Pbind(
		\instrument, \prc4,
		\a, 0.01,
		\curve, -8,
		\dur, Pshuf([
			Pseq([0.75], 7),
			Pseq([1], 7),
			Pseq([1.25], 7),
		], inf),
		\note, Pwrand([0, Rest], [4, 1].normalizeSum, inf),
		\level, Pwhite(0.5, 1, inf) * 0.4,
		\octave, 4,
		\scale, ~scale,
));
~prc4pat1a = Pdef(\prc4pat1a, Pbindf(~prc4pat1, \level, 0.08, \pan, -1));
~prc4pat1b = Pdef(\prc4pat1b, Pbindf(~prc4pat1a, \pan, 1));
~prc4pat2 = Pdef(\prc4pat2, Pbindf(~prc4pat1, \curve, -16, \octave, 7));
~prc4pat2a = Pdef(\prc4pat2a, Pbindf(~prc4pat2, \curve, -8, \dur, 0.25, \level, 0.08, \pan, -1));
~prc4pat2b = Pdef(\prc4pat2b, Pbindf(~prc4pat2a, \pan, 1));
(
~prc4par2 =
Pdef(\prc4par2,
	Ppar([
		~prc4pat1, ~prc4pat1, ~prc4pat1, ~prc4pat1a, ~prc4pat1b, ~prc4pat1a, ~prc4pat1b, ~prc4pat1a, ~prc4pat1b,
		~prc4pat2, ~prc4pat2a, ~prc4pat2b
], inf));
);
);

/*
~prc4par2.play(t, quant: 1);
~prc4par2.isPlaying;
~prc4par2.pause;
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
~prc4parktrl = MIDIdef.cc(\prc4parktrl, {
	if(~prc4par2.isPlaying.not) {
		~prc4par2.play(t, quant: 1);
		"prc4-2 play".postln;
	} {
		~prc4par2.pause;
		"prc4-2 stop".postln;
	};
}, 52, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PLUNK

(
SynthDef(\plunk, { | curve = -16, dur = 1, freq = 400, level = 0.08, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var fbenv			=	Env.new([0.999, 0.1], [0.05], 'sine');
	var fbenvgen		= 	EnvGen.kr(fbenv);
	var	kbn				=	(LFBrownNoise0.kr(30).range(0.2, 1)).round(0.2);
	var sinfb			=	SinOscFB.ar(freq, fbenvgen, envgen * kbn);
	var shape			=	SineShaper.ar(sinfb, 0.01);
	var rlpf			=	RLPF.ar(shape, freq * 4, 0.5);
	var rhpf			=	RHPF.ar(shape, 8000, 0.05);
	var flts			=	rlpf + rhpf;
	var pan2			=	Pan2.ar(flts, pan);
	Out.ar(0, pan2);
}).add;
);

(
~plunkdegrees = [-1, 0, 1, 2, 3];
~plunkpat1 =
Pdef(\plunkpat1,
	Pbind(
		\instrument, \plunk,
		\dur, Pshuf([
			0.25, 0.5, 0.75,
			4, 6, 8, 12, 16, 24
		], inf),
		\degree, Pseq([7, ~scale.size], inf),
		\octave, 4,
		\scale, ~scale,
));
);

/*
~plunkpat1.play(t, quant: 1);
~plunkpat1.isPlaying;
~plunkpat1.pause;
*/

(
~plunkpat2 =
Pdef(\plunkpat2,
	Pbindf(
		~plunkpat1,
		\degree, Pswitch1(~plunkdegrees, Pbrown(0, ~plunkdegrees.size - 1, 1), inf),
		\octave, 5
));
);

/*
~plunkpat2.play(t, quant: 1);
~plunkpat2.isPlaying;
~plunkpat2.pause;
*/

(
~plunkpat3 =
Pdef(\plunkpat3,
	Pbindf(
		~plunkpat2,
		\octave, 6,
));
);

/*
~plunkpat3.play(t, quant: 1);
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
SynthDef(\penguin, { | curve = 0, freq = 400, gate = 1, level = 0.2, shapermin = 0.0005, shapermax = 0.005 |
	var env				=	Env.asr(0.01, sustainLevel: level, releaseTime: 0.01, curve: curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var mix				=	Mix.fill(3, {
		var freqmod			=	LFNoise1.kr(0.3!2, 0.001, 1);
		var tri				=	LFTri.ar((freq * freqmod).clip(50, s.sampleRate / 3), mul: envgen);
		var kbn				=	LFBrownNoise1.kr(0.05!2).range(shapermin, shapermax);
		var shape			=	SineShaper.ar(tri, kbn);
		shape;
	});
	var hpf				=	HPF.ar(mix, (freq * 4).clip(50, SampleRate.ir / 3), 0.5);
	Out.ar(0, (hpf));
}).add;
);

(
~pgnpat1 =
Pdef(\pgnpat1,
	Pbind(
		\instrument, \penguin,
		\degree, Pswitch([[-3, -1], [-3, 0], [-1, 1], [-3, 2], [0, 3], [0, 7]], Pbrown(0, 6, 1), inf),
		\dur, Pshuf([8, 12, 16, 24, 32, 48], inf),
		\legato, 0.5,
		//\legato, 1,
		\octave, 6,
		\scale, ~scale,
		\shapermin, 0.0005,
		\shapermax, 0.01,
));
);

/*
~pgnpat1.play(t, quant: 1);
~pgnpat1.isPlaying;
~pgnpat1.pause;
*/

(
~pgnpat2 = Pdef(\pgnpat2, Pbindf(~pgnpat1, \degree, Pseq([0, 7], inf)));
~pgnpar = Pdef(\pgnpar, Ppar([~pgnpat1, ~pgnpat2, ~pgnpat2]));
);

/*
~pgnpar.play(t, quant: 1);
~pgnpar.isPlaying;
~pgnpar.pause;
*/

(
~pgnktrl =
MIDIdef.cc(\pgnktrl, {
	if(~pgnpar.isPlaying.not) {
		~pgnpar.play(t, quant: 1);
		"pgnpar play".postln;
	} {
		~pgnpar.pause;
		"pgnpar pause".postln;
	}
}, 54, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PAD2

// Synth

(
~pad2 =
SynthDef(\pad2, { | curve = -4, dur = 1, freq = 400, gate = 1, level = 0.005 |
	var env				=	Env.asr(3, level, 7, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	//var kbnenv1			=	(LFBrownNoise0.kr(15).range(0.25, 1).round(0.25));
	//var kbnenv2			=	(LFBrownNoise1.kr(15).range(0, 1)).round(0.5);
	var filtmulmods		=	LFBrownNoise0.kr(15!4).range(0.25, 1).round(0.25);
	var saw1freqmod		=	LFNoise1.kr(0.1.dup, 0.0001, 1);
	var saw0			=	LFSaw.ar(freq.dup, mul: envgen / 2);
	var saw1			=	LFSaw.ar(freq * saw1freqmod, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var bn				=	LFNoise2.ar(0.1!2, 0.1);
	var kbnshaper		=	LFBrownNoise1.kr(15.dup).range(0.5, 2);
	//var shape			=	SineShaper.ar(sawmix + bn, 0.002 * kbnshaper);
	var shape			=	(sawmix + bn).fold2(0.002 * kbnshaper) * 20;
	var lpf				=	BLowPass4.ar(sawmix + shape, freq, mul: filtmulmods[0, 1]);
	var rhpf			=	BHiPass4.ar(sawmix + shape, 6000, 0.05, filtmulmods[2, 3]);
	//var filtmix			=	lpf + rhpf;
	Out.ar(0, lpf + rhpf);
}).add;
);

// Pattern

(
~padchords2 = ~scaledegrees.powerset.reject({ arg i; i.size != 5 });
//~padchords2 = [[0, 7]];

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
}, 55, srcID: ~nanoktrl2);
);