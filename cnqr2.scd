( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl2 = 1310720;
);

s.meter;
t = TempoClock(120/60);
t.tempo.postln;
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 1.5), 1);

(
~ratios = [1/1, 15/14, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 14/9, 7/4];
~tuning = Tuning.new(~ratios.ratiomidi);
~bassscale = Scale.new(#[0, 1, 2, 3, 5], ~ratios.size, ~tuning);
~scaledegrees = #[0, 1, 2, 3, 4, 7, 9, 16, 17, 18, 21, 22, 26];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
);

////////////////////////////////////////////////////////
// BASS ////////////////////////////////////////////////

// SynthDef

(
~bass = SynthDef(\bass, { | curve = 0, dur = 1, freq = 100, level = 0.05, width = 0.5 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var klfn0			=	LFNoise1.ar(18000, 0.999, 1);
	var klfn1			=	LFNoise1.kr(1, 0.02, 1);
	var saw0			=	VarSaw.ar([freq, freq + 0.1] * klfn0, width: width, mul: envgen / 2);
	var saw1			=	VarSaw.ar([freq, freq + 0.1] * klfn0 * klfn1, width: width, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var lpf				=	BLowPass4.ar(sawmix, freq);
	var rhpf			=	RHPF.ar(sawmix, 6000, 0.1, mul: 0.5);
	var sin				=	SinOsc.ar([freq, freq + 0.1], mul: envgen);
	Out.ar([0, 2], lpf + rhpf + sin);
	//Out.ar([0, 2], saw0 + saw1);
}).add;
);

// Pattern

(
~durations = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16];
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\curve, -4,
		\degree, Prand([0, 1, 2, 3], inf),
		\dur, Pwrand(~durations, ~durations.reverse.normalizeSum, inf),
		\level, 0.04,
		\root, (~scale.size - 1) * -2,
		\scale, ~bassscale,
		\width, Pwhite(0.1, 0.9, inf),
));
);

/*
~basspat.play(t, quant: 0.5);
~basspat.isPlaying;
~basspat.stop;
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
SynthDef(\bufrd, { | dur = 1, ffreq = 1000, gate = 1, pan = 0 |
	var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(b.numChannels, b.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var rhpf			=	RHPF.ar(bufrd, ffreq, 0.1, envgen * kbn1);
	var pan2			=	Pan2.ar(rhpf, pan);
	Out.ar(0, pan2);
}).add;
);

(
~rbpdef =
Pdef(\rbpdef,
	Pbind(
		\instrument, \recbuf,
		\dur, Pseq([3], inf),
));
);

/*
~rbpdef.play(t, quant: 3);
~rbpdef.isPlaying;
~rbpdef.pause;
b.plot;
*/

(
~pbpdef =
Pdef(\pbpdef,
	Pbind(
		\instrument, \bufrd,
		\dur, Prand([0.75, 1.5, 3], inf),
		\pan, Prand([-1, -0.5, 0, 0.5, 1], inf)
));
);

/*
~pbpdef.play(t, quant: 1);
~pbpdef.isPlaying;
~pbpdef.stop;
*/

(
~pbpar =Pdef(\pbpar, Ppar(Array.fill(3, { ~pbpdef })));
);

/*
~pbpar.play(t, quant: 1);
~pbpar.isPlaying;
~pbpar.stop;
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
	if(~pbpar.isPlaying.not) {
		~pbpar.play(t, quant: 0.5);
		"playbuf play".postln;
	} {
		~pbpar.stop;
		"playbuf stop".postln;
	};
}, 64, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////
// PERC ////////////////////////////////////////////////

// SynthDef

(
~prc =
SynthDef(\prc, { | curve = -512, dur = 1, freq = 1000, level = 0.05, pan = 0 |
	var env				= 	Env.perc(attackTime: 0.005, releaseTime: 0.25, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var bn				=	LFBrownNoise0.ar(freq, mul: envgen);
	var n				=	24;
	var resonzmix		=	Mix.fill(n, {
		var kbn			=	LFBrownNoise1.kr(0.1, mul: 0.4, add: 1);
		Resonz.ar(bn, freq * kbn, 0.001, 150 / n);
	});
	var pan2			=	Pan2.ar(resonzmix, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
~freqarray0 = [500, 1000, 2000, 10000, 11000, 12000, 13000];
~freqarray0.postln;
~freqarray0.mirror2.postln;
~prcpat0l =
Pdef(\prcpat0l,
	Pbind(
		\instrument, \prc,
		\dur, Pshuf([0.25, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].mirror2, inf),
		\freq, 5000,
		\pan, -1,
)));

(
~prcpat0r =
Pdef(\prcpat0r,
	Pbindf(~prcpat0l, \pan, 1));
);

~prcpar0 = Pdef(\prcpar0, Ppar([~prcpat0l, ~prcpat0r], inf));

/*
~prcpar0.play(t, quant: 0.5);
~prcpar0.isPlaying;
~prcpar0.pause;
*/

(
~prcpat1l =
Pdef(\prcpat1l,
	Pbindf(
		~prcpat0l,
		\dur, 0.25,
		\freq, 10000,
		\level, 0.02,
)));

(
~prcpat1r =
Pdef(\prcpat1r,
	Pbindf(~prcpat1l, \pan, 1));
);

~prcpar1 = Pdef(\prcpar1, Ppar([~prcpat1l, ~prcpat1r], inf));

/*
~prcpar1.play(t, quant: 0.5);
~prcpar1.isPlaying;
~prcpar1.pause;
*/

(
~prcpulse =
Pdef(\prcpulse,
	Pbind(
		\instrument, \prc,
		\dur, Pseq([
			1, 1, 1.5,
			1, 1, 1, 1.5,
			1, 1, 1, 1, 1.5
		], inf),
		\freq, 9000,
		\level, 0.05,
		\pan, Pwhite(-0.5, 0.5, inf),
));
);

// Midi Control

(
~prc0ktrl = MIDIdef.cc(\prc0ktrl, {
	if(~prcpar0.isPlaying.not) {
		~prcpar0.play(t, quant: 0.5);
		"prc0 play".postln;
	} {
		~prcpar0.pause;
		"prc0 stop".postln;
	};
}, 33, srcID: ~nanoktrl2);
);

(
~prc1ktrl = MIDIdef.cc(\prc1ktrl, {
	if(~prcpar1.isPlaying.not) {
		~prcpar1.play(t, quant: 0.5);
		"prc1 play".postln;
	} {
		~prcpar1.pause;
		"prc1 stop".postln;
	};
}, 49, srcID: ~nanoktrl2);
);

(
~prcpulsektrl = MIDIdef.cc(\prcpulsektrl, {
	if(~prcpulse.isPlaying.not) {
		~prcpulse.play(t, quant: 0.5);
		"prcpulse play".postln;
	} {
		~prcpulse.pause;
		"prcpulse stop".postln;
	};
}, 65, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// SNR /////////////////////////////////////////////////////////

// SynthDef

(
~snr =
SynthDef(\snr, { | blowfreq = 3000, curve = -32, level = 0.02, outbus = 0, pan = 0 |
	var env				=	Env.perc(releaseTime: 0.25, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var clip			=	LFClipNoise.ar(13000, mul: envgen);
	var blow			=	BLowPass4.ar(clip, blowfreq, 0.1);
	var pan2			=	Pan2.ar(blow, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Pattern

(
~snrpat0 =
Pdef(\snrpat0,
	Pbind(
		\instrument, \snr,
		\dur, Pseq([
			1, 1, 1.5,
			1, 1, 1, 1.5,
			1, 1, 1, 1, 1.25, 0.25,], inf),
		\level, 0.015,
		\note, Pseq([Rest, 1, Rest], inf),
));
);

/*
~snrpat0.play(t, quant: 1);
~snrpat0.isPlaying;
~snrpat0.pause;
*/

(
~snrpat1 =
Pdef(\snrpat1,
	Pbindf(
		~snrpat0,
		\dur, Pseq([
			0.75, 0.75, 1.25,
			0.75, 0.75, 0.75, 1.25,
			0.75, 0.75, 0.75, 0.75, 1.25
		], inf),
		\level, 0.002,
		\note, Pseq([Rest, 1, Rest], inf),
		\pan, -1,
));
);

/*
~snrpat1.play(t, quant: 1);
~snrpat1.isPlaying;
~snrpat1.pause;
*/

(
~snrpat2 =
Pdef(\snrpat2,
	Pbindf(
		~snrpat0,
		\dur, Pseq([
			1.25, 1.25, 1.75,
			1.25, 1.25, 1.25, 1.25, 1.75,
			1.25, 1.25, 1.25, 1.25, 1.25, 1.75
		], inf),
		\level, 0.002,
		\note, Pseq([Rest, 1], inf),
		\pan, 1,
));
);

/*
~snrpat2.play(t, quant: 1);
~snrpat2.isPlaying;
~snrpat2.pause;
*/

////////////////

(
~snrpat3 =
Pdef(\snrpat3,
	Pbindf(
		~snrpat0,
		\blowfreq, 4000,
		\dur, Prand([0.5, 0.75, 1], inf),
		\note, Pseq([Rest, 1], inf),
));
);

/*
~snrpat3.play(t, quant: 1);
~snrpat3.isPlaying;
~snrpat3.pause;
*/

(
~snrpat4 =
Pdef(\snrpat4,
	Pbindf(
		~snrpat1,
		\blowfreq, 4000,
		\dur, Prand([0.5, 0.75, 1], inf),
		\note, Pseq([Rest, 1], inf),
));
);

/*
~snrpat4.play(t, quant: 1);
~snrpat4.isPlaying;
~snrpat4.pause;
*/

(
~snrpat5 =
Pdef(\snrpat5,
	Pbindf(
		~snrpat2,
		\blowfreq, 4000,
		\dur, Prand([0.5, 0.75, 1], inf),
		\note, Pseq([Rest, 1], inf),
));
);

/*
~snrpat5.play(t, quant: 1);
~snrpat5.isPlaying;
~snrpat5.pause;
*/

////////////////

(
~snrpat6 =
Pdef(\snrpat6,
	Pbindf(
		~snrpat3,
		\blowfreq, 2500,
));
);

/*
~snrpat6.play(t, quant: 1);
~snrpat6.isPlaying;
~snrpat6.pause;
*/

(
~snrpat7 =
Pdef(\snrpat7,
	Pbindf(
		~snrpat4,
		\blowfreq, 4000,
));
);

/*
~snrpat7.play(t, quant: 1);
~snrpat7.isPlaying;
~snrpat7.pause;
*/

(
~snrpat8 =
Pdef(\snrpat8,
	Pbindf(
		~snrpat5,
		\blowfreq, 4000,
));
);

/*
~snrpat8.play(t, quant: 1);
~snrpat8.isPlaying;
~snrpat8.pause;
*/

////////////////

~snrpar0 = Pdef(\snrpar0, Ppar([~snrpat0, ~snrpat1, ~snrpat2], inf));

/*
~snrpar0.play(t, quant: 1);
~snrpar0.isPlaying;
~snrpar0.pause;
*/

~snrpar1 = Pdef(\snrpar1, Ppar([~snrpat4, ~snrpat4, ~snrpat5]));

/*
~snrpar1.play(t, quant: 1);
~snrpar1.isPlaying;
~snrpar1.pause;
*/

~snrpar2 = Pdef(\snrpar2, Ppar([~snrpat6, ~snrpat7, ~snrpat8]));

/*
~snrpar2.play(t, quant: 1);
~snrpar2.isPlaying;
~snrpar2.pause;
*/

// Midi Control

(
~snrpar0ktrl = MIDIdef.cc(\snrpar0ktrl, {
	if(~snrpar0.isPlaying.not) {
		~snrpar0.play(t, quant: 1);
		"snrpar0 play".postln;
	} {
		~snrpar0.pause;
		"snrpar0 stop".postln;
	};
}, 34, srcID: ~nanoktrl2);
);

(
~snrpar1ktrl = MIDIdef.cc(\snrpar1ktrl, {
	if(~snrpar1.isPlaying.not) {
		~snrpar1.play(t, quant: 1);
		"snrpar1 play".postln;
	} {
		~snrpar1.pause;
		"snrpar stop".postln;
	};
}, 50, srcID: ~nanoktrl2);
);

(
~snrpar2ktrl = MIDIdef.cc(\snrpar2ktrl, {
	if(~snrpar2.isPlaying.not) {
		~snrpar2.play(t, quant: 1);
		"snrpar2 play".postln;
	} {
		~snrpar2.pause;
		"snrpar2 stop".postln;
	};
}, 66, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// HAT /////////////////////////////////////////////////////////

// SynthDef

(
~hat =
SynthDef(\hat, { | level = 0.1, outbus = 0, pan = 0 |
	var env				=	Env.perc(0.003, 0.05, level, 0);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var imp 			=	Impulse.ar(0, mul: envgen);
	var rlpf			=	RLPF.ar(imp, 8000, 0.01);
	var pan2			=	Pan2.ar(rlpf, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Pattern

(
~hatpatl =
Pdef(\hatpatl,
	Pbind(
		\instrument, \hat,
		\dur, Pwrand([Pseq([0.25/3], 3), 0.5, 0.75], [1, 8, 8].normalizeSum, inf),
		\level, Prand([0.5, 1] * 0.1, inf),
		\pan, -1
));
);

(
~hatpatr =
Pdef(\hatpatr,
	Pbindf(
		~hatpatl,
		\pan, 1
));
);

~hatpar = Pdef(\hatpar, Ppar([~hatpatl, ~hatpatr], inf));

/*
~hatpar.play(t, quant: 0.5);
~hatpar.isPlaying;
~hatpar.stop;
*/

(
~hatpulse =
Pdef(\hatpulse,
	Pbind(
		\instrument, \hat,
		\dur, 0.25,
		\level, 0.04,
		\pan, Prand([-0.5, 0.5], inf),
));
);

/*
~hatpulse.play(t, quant: 0.5);
~hatpulse.isPlaying;
~hatpulse.pause
*/

// Midi Control

(
~hatktrl = MIDIdef.cc(\hatktrl, {
	if(~hatpar.isPlaying.not) {
		~hatpar.play(t, quant: 0.5);
		"hat play".postln;
	} {
		~hatpar.pause;
		"hat stop".postln;
	};
}, 35, srcID: ~nanoktrl2);
);

(
~hatpulsektrl = MIDIdef.cc(\hatpulsektrl, {
	if(~hatpulse.isPlaying.not) {
		~hatpulse.play(t, quant: 0.5);
		"hatpulse play".postln;
	} {
		~hatpulse.pause;
		"hatpulse stop".postln;
	};
}, 51, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// CRUMBLE /////////////////////////////////////////////////////

(
~crumble =
SynthDef(\crumble, { | a = 1, b = 1.9, bwr = 0.03, curve = -8, dur = 1, freq = 1000, gate = 1, level = 0.001, outbus = 0, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var n				=	16;
	var mix				=	Mix.fill(n, {
		arg i;
		var clipnfreq		=	1;
		var clipn			=	LFClipNoise.kr(clipnfreq).range(0.5, 1);
		var cusp			=	CuspL.ar(a: a, b: b, mul: (envgen * clipn) / n);
		BPF.ar(cusp, (((i / n) + n) * freq).clip(50, SampleRate.ir / 3), bwr, 600);
	});
	//var kbn				=	LFBrownNoise0.kr(10).range(1, 1);
	var mixmod			=	mix;
	var pan2			=	Pan2.ar(mixmod, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Patterns

(
~crumblepdef0 =
Pdef(\crumblepdef0,
	Pbind(
		\instrument, \crumble,
		\a, Pbrown(0.8, 1, 0.05, inf),
		\b, Pbrown(1.6, 1.9, 0.05, inf),
		\bwr, Pbrown(0.002, 0.02, 0.005, inf),
		\degree, (~scale.size - 1),
		\dur, Prand([0.25, 0.5, 0.75], inf),
		\level, Pbrown(0, 0.003, 0.0003, inf),
		\pan, Prand([-0.5, -0.25, 0, 0.25, 0.5], inf)
));
);

/*
~crumblepdef0.play(t, quant: 1);
~crumblepdef0.isPlaying;
~crumblepdef0.stop;
*/

(
~crumblepdef1 =
Pdef(\crumblepdef1,
	Pbindf(
		~crumblepdef0
));
);

/*
~crumblepdef1.play(t, quant: 1);
~crumblepdef1.isPlaying;
~crumblepdef1.stop;
*/

~crumblepar0 = Pdef(\crumblepar0, Ppar([~crumblepdef0, ~crumblepdef1], inf));

/*
~crumblepar0.play(t, quant: 1);
~crumblepar0.isPlaying;
~crumblepar0.stop;
*/

~crumblepar1 = Pdef(\crumblepar1, Ppar([~crumblepdef0, ~crumblepdef1], inf));

/*
~crumblepar1.play(t, quant: 1);
~crumblepar1.isPlaying;
~crumblepar1.stop;
*/

// Midi Control

(
~crumble0ktrl =
MIDIdef.cc(\crumble0ktrl, {
	if(~crumblepar0.isPlaying.not) {
		~crumblepar0.play(t, quant: 1);
		"crumble0 play".postln;
	} {
		~crumblepar0.pause;
		"crumble0 stop".postln;
	};
}, 36, srcID: ~nanoktrl2);
);

(
~crumble1ktrl =
MIDIdef.cc(\crumble1ktrl, {
	if(~crumblepar1.isPlaying.not) {
		~crumblepar1.play(t, quant: 1);
		"crumble1 play".postln;
	} {
		~crumblepar1.pause;
		"crumble1 stop".postln;
	};
}, 52, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PNO /////////////////////////////////////////////////////////

(
~pno =
SynthDef(\pno, { | curve = -2, dur = 1, freq = 400, gate = 1, level = 0.002, pan = 0 |
	var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	Mix.fill(2, {
		arg i;
		var lfn			=	LFNoise1.kr(0.1, mul: 0.005, add: 1);
		var sin			=	SinOsc.ar((freq) * (i + 1) * lfn, 0.1, mul: envgen / (i + 1));
		sin;
	});
	var lfn				=	LFNoise1.kr(0.1, mul: 0.01, add: 1);
	var cusp			=	CuspL.ar(a: lfn, mul: 0.3, add: 1);
	var sinhi			=	SinOsc.ar((freq * 23 * cusp).clip(50, SampleRate.ir / 3), mul: envgen);
	var pan2			=	Pan2.ar(sin + sinhi, pan);
	Out.ar(0, pan2);
}).add;
);

(
~pnopdef0 =
Pdef(\pnopdef0,
	Pbind(
		\instrument, \pno,
		\degree, 0,
		\dur, Prand([0.25, 0.5], inf),
		\level, 0.0004,
		\pan, Prand([-1, -0.5, 0, 0.5, 1], inf),
		\root, ~scale.size - 1,
		\scale, ~scale,
));
);

/*
~pnopdef0.play(t, quant: 1);
~pnopdef0.isPlaying;
~pnopdef0.pause;
*/

~pnopar0 = Pdef(\pnopar0, Ppar(Array.fill(4, { ~pnopdef0 })));

/*
~pnopar0.play(t, quant: 1);
~pnopar0.isPlaying;
~pnopar0.pause;
*/

~pnopar1 = Pdef(\pnopar1, Ppar(Array.fill(4, { ~pnopdef0 })));

/*
~pnopar1.play(t, quant: 1);
~pnopar1.isPlaying;
~pnopar1.pause;
*/

(
~pnopar0ktrl = MIDIdef.cc(\pnopar0ktrl, {
	if(~pnopar0.isPlaying.not) {
		~pnopar0.play(t, quant: 0.25);
		"pno0 play".postln;
	} {
		~pnopar0.pause;
		"pno0 stop".postln;
	};
}, 37, srcID: ~nanoktrl2);
);

(
~pnopar11ktrl = MIDIdef.cc(\pnopar1ktrl, {
	if(~pnopar1.isPlaying.not) {
		~pnopar1.play(t, quant: 0.25);
		"pno1 play".postln;
	} {
		~pnopar1.pause;
		"pno1 stop".postln;
	};
}, 53, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PNO2 ////////////////////////////////////////////////////////

(
~pno2 =
SynthDef(\pno2, { | curve = -16, dur = 1, freq = 400, level = 0.005 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	SinOsc.ar(freq, mul: envgen / n);
	var n				=	20;
	var sinmix			=	Mix.fill(n, {
		arg i;
		var lfn1modfrq		=	Array.fill(2, { 0.03 });
		var lfn1modmul		=	Array.fill(2, { 0.005 * i });
		var lfn1mod			=	LFNoise1.kr(lfn1modfrq, mul: lfn1modmul, add: [1, 1]);
		SinOsc.ar([freq, freq + 0.1] * lfn1mod, mul: envgen / (i + 1))
	});
	Out.ar(0, sin + sinmix);
}).add;
);

// Pattern

(
~pno2pat =
Pdef(\pno2pat,
	Pbind(
		\instrument, \pno2,
		\curve, -8,
		\degree, 0,
		\dur, Pseq([9, 10, 11].nthPrime.postln, inf),
		\root, ~scale.size - 1,
		\scale, ~scale,
));
);

/*
~pno2pat.play(t, quant: 0.5);
~pno2pat.isPlaying;
~pno2pat.pause;
*/

(
~pno2ktrl = MIDIdef.cc(\pno2ktrl, {
	if(~pno2pat.isPlaying.not) {
		~pno2pat.play(t, quant: 1);
		"pno2 play".postln;
	} {
		~pno2pat.pause;
		"pno2 stop".postln;
	};
}, 69, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// DRONE ///////////////////////////////////////////////////////

(
~drone =
SynthDef(\drone, { | curve = 0, dur = 1, freq = 400, gate = 1, level = 0.002, pan = 0 |
	var env				=	Env.asr(0.005, level, 1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbn				=	LFBrownNoise0.kr([15, 15], mul: 0.8, add: 1);
	var n				=	4;
	var mix				= 	Mix.fill(n, {
		arg i;
		var lfn			=	LFNoise1.kr([0.1, 0.1], mul: 0.002, add: 1);
		SinOsc.ar((freq * lfn * (i + 1)), 0.1, mul: envgen * kbn / (i + 1).pow(4));
	});
	var sin				=	SinOsc.ar((freq), 0.1, mul: envgen);
	var lor				=	Lorenz2DC.ar(s: [9.9, 10], mul: [0.8, 0.8], add: 1);
	var sinhi			=	SinOsc.ar((freq * 21 * lor).clip(50, SampleRate.ir / 3), mul: envgen / 4);
	Out.ar(0, (mix + sin + sinhi) * kbn);
}).add;
);

(
~dronepat0 =
Pdef(\dronepat0,
	Pbind(
		\instrument, \drone,
		\degree, [-7, -8],
		\dur, Pseq([13, 14, 15].nthPrime.postln, inf),
		\legato, 0.5,
		\root, ~scale.size - 1,
		\scale, ~scale
));
);

/*
~dronepat0.play(t, quant: 1);
~dronepat0.isPlaying;
~dronepat0.pause;
*/

(
~dronepat1 =
Pdef(\dronepat1,
	Pbindf(
		~dronepat0,
		\degree, [0, 2],
		//\root, (~scale.size - 1) * 2,
));
);

/*
~dronepat1.play(t, quant: 1);
~dronepat1.isPlaying;
~dronepat1.pause;
*/

(
~drone0ktrl = MIDIdef.cc(\drone0ktrl, {
	if(~dronepat0.isPlaying.not) {
		~dronepat0.play(t, quant: 0.25);
		"drone0 play".postln;
	} {
		~dronepat0.pause;
		"drone0 stop".postln;
	};
}, 38, srcID: ~nanoktrl2);
);

(
~drone1ktrl = MIDIdef.cc(\drone1ktrl, {
	if(~dronepat1.isPlaying.not) {
		~dronepat1.play(t, quant: 0.25);
		"drone1 play".postln;
	} {
		~dronepat1.pause;
		"drone1 stop".postln;
	};
}, 54, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PAD /////////////////////////////////////////////////////////

// Synth

(
~pad =
SynthDef(\pad, { | dur = 1, freq = 400, gate = 1, level = 0.008 |
	var env 			=	Env.sine(dur / 1.5, level);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbnenv			=	LFBrownNoise0.kr(15).range(0.3, 1).round(0.1);
	var n				=	12;
	var mix				=	Mix.fill(n, {
		arg i;
		var klfn		=	LFNoise1.kr(0.1, 0.01, 1);
		var pulse0		=	LFPulse.ar(([freq, freq + 0.1] * klfn), mul: (envgen) / (i + 1));
		var pulse1		=	LFPulse.ar([freq, freq + 0.1], mul: (envgen) / n);
		pulse0 + pulse1;
	});
	var lpf				=	BLowPass4.ar(mix, freq * 1.5);
	var rhpf			=	BHiPass4.ar(mix, 8000, 0.02, mul: 0.2);
	var filtmix			=	lpf + rhpf;
	var striated		=	filtmix * kbnenv;
	Out.ar(0, striated);
}).add;
);

// Pattern

(
~scaledegrees.postln;
~chords0 = Array.fill(~scale.size - 1, { arg i; [0, i, 5, i + 5] });
~chords1 = ~chords0 + (~scale.size - 1);
'chords0: '.postln;
~chords0.postln;
'chords1: '.postln;
~chords1.postln;
'size of each array: '.postln;
~chords0.size.postln;
);

(
~padpatdurarr = Array.fill(5, { arg i; (i + 6).nthPrime });
~padpatdurarr.postln;
~padpat0 =
Pdef(\padpat0,
	Pbind(
		\instrument, \pad,
		//\degree, Prand(~chords0 ++ [Rest].stutter(12), inf),
		\degree, Prand(~chords0, inf),
		\dur, Prand(~padpatdurarr, inf),
		\legato, 1,
		\root, 0,
		\scale, ~scale,
));
);

/*
~padpat0.play(t, quant: 1);
~padpat0.isPlaying;
~padpat0.pause;
*/

(
~padpat1 =
Pdef(\padpat1,
	Pbindf(
		~padpat0,
		\degree, Prand(~chords1 ++ [Rest].stutter(12), inf)
));
);

/*
~padpat1.play(t, quant: 1);
~padpat1.isPlaying;
~padpat1.pause;
*/

(
~padhi =
Pdef(\padhi,
	Pbind(
		\instrument, \pad,
		\degree, [0, 5],
		\dur, 31,
		\level, 0.002,
		\root, (~scale.size - 1) * 2,
		\scale, ~scale,
));
);

/*
~padhi.play(t, quant: 1);
~padhi.isPlaying;
~padhi.pause;
*/

// Midi Control

(
~pad0ktrl = MIDIdef.cc(\pad0ktrl, {
	if(~padpat0.isPlaying.not) {
		~padpat0.play(t, quant: 1);
		"pad0 play".postln;
	} {
		~padpat0.pause;
		"pad0 stop".postln;
	};
}, 39, srcID: ~nanoktrl2);
);

(
~pad1ktrl = MIDIdef.cc(\pad1ktrl, {
	if(~padpat1.isPlaying.not) {
		~padpat1.play(t, quant: 1);
		"pad1 play".postln;
	} {
		~padpat1.pause;
		"pad1 stop".postln;
	};
}, 55, srcID: ~nanoktrl2);
);

(
~padhiktrl = MIDIdef.cc(\padhiktrl, {
	if(~padhi.isPlaying.not) {
		~padhi.play(t, quant: 1);
		"padhi play".postln;
	} {
		~padhi.pause;
		"padhi stop".postln;
	};
}, 71, srcID: ~nanoktrl2);
);