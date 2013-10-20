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
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);

(
~ratios = [1/1, 15/14, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 14/9, 7/4];
~tuning = Tuning.new(~ratios.ratiomidi);
~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
//~scaledegrees = #[0, 1, 2, 3, 4, 7, 9, 16, 17, 18, 21, 22, 26];
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
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
	var klfn1			=	LFNoise1.kr(0.1, 0.0005, 1);
	var saw0			=	VarSaw.ar([freq, freq + 0.1], width: width, mul: envgen / 2);
	var saw1			=	VarSaw.ar([freq, freq + 0.1] * klfn0 * klfn1, width: width, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var lpf				=	BLowPass4.ar(sawmix, freq * 2);
	var rhpf			=	RHPF.ar(sawmix, 5000, 0.1, mul: 0.5);
	var sin				=	SinOsc.ar([freq, freq + 0.1], mul: envgen);
	Out.ar([0, 2], lpf + rhpf + sin);
	//Out.ar([0, 2], saw0 + saw1);
}).add;
);

// Pattern

(
~durations = [0.5, 0.75, 8, 12, 16, 24];
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\curve, -4,
		\degree, Prand([-1, 0, 1, 2, 3], inf),
		\dur, Pwrand(~durations, ~durations.reverse.normalizeSum, inf),
		\level, 0.05,
		\octave, 3,
		\scale, ~scale,
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
~pbpdef =
Pdef(\pbpdef,
	Pbind(
		\instrument, \bufrd,
		\dur, Prand([0.75, 1.5, 3, 6], inf),
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
SynthDef(\prc, { | curve = -64, dur = 1, freq = 1000, level = 0.05, pan = 0 |
	var env				= 	Env.perc(attackTime: 0.005, releaseTime: dur / 3, level: level, curve: curve);
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
~prcpat0l =
Pdef(\prcpat0l,
	Pbind(
		\instrument, \prc,
		\curve, -16,
		\dur, Pshuf([Pseq([0.25/3], 3), Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].mirror2, inf),
		\freq, 15000,
		\pan, -0.5,
)));

(
~prcpat0r =
Pdef(\prcpat0r,
	Pbindf(~prcpat0l, \pan, 0.5));
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
		\curve, -64,
		\dur, Pshuf([
			1, 1, 1.5,
			1, 1, 1, 1.5,
			1, 1, 1, 1, 1.5
		] / 2, inf),
		\freq, 7500,
		\pan, -1,
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
		\freq, 12000,
		\level, 0.05,
));
);

/*
~prcpulse.play(t, quant: 1);
~prcpulse.isPlaying;
~prcpulse.pause;
*/

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
SynthDef(\snr, { | a = 1, freq = 1000, curve = -64, level = 0.05, outbus = 0, pan = 0 |
	var env				=	Env.perc(0.003, 0.5, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(1000, a, mul: 1.5, add: 1);
	var sin				=	SinOsc.ar((freq * cusp).clip(50, SampleRate.ir / 3), mul: envgen);
	var pan2			=	Pan2.ar(sin, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Pattern

(
~snrfreq0 = 5000;
~snrfreq1 = 100;
~snrfreq2 = 15000;
~snrfreq3 = 3000;
~snrecholvl = 0.005;
~snrpat0 =
Pdef(\snrpat0,
	Pbind(
		\instrument, \snr,
		\a, Pwhite(0.99, 1.01, inf),
		\curve, -24,
		\freq, ~snrfreq0,
		\dur, Pseq([
			1, 1, 1.5,
			1, 1, 1, 1.5,
			1, 1, 1, 1, 1.25, 0.25,], inf),
		\note, Pseq([Rest, 1, Rest], inf),
));

/*
~snrpat0.play(t, quant: 1);
~snrpat0.isPlaying;
~snrpat0.pause;
*/

~snrpat1 =
Pdef(\snrpat1,
	Pbindf(
		~snrpat0,
		\dur, Pseq([
			0.75, 0.75, 1.25,
			0.75, 0.75, 0.75, 1.25,
			0.75, 0.75, 0.75, 0.75, 1.25
		], inf),
		\level, ~snrecholvl,
		\note, Pseq([Rest, 1, Rest], inf),
		\pan, -1,
));

/*
~snrpat1.play(t, quant: 1);
~snrpat1.isPlaying;
~snrpat1.pause;
*/

~snrpat2 =
Pdef(\snrpat2,
	Pbindf(
		~snrpat0,
		\dur, Pseq([
			1.25, 1.25, 1.75,
			1.25, 1.25, 1.25, 1.25, 1.75,
			1.25, 1.25, 1.25, 1.25, 1.25, 1.75
		], inf),
		\level, ~snrecholvl,
		\note, Pseq([Rest, 1], inf),
		\pan, 1,
));

/*
~snrpat2.play(t, quant: 1);
~snrpat2.isPlaying;
~snrpat2.pause;
*/

////////////////

~snrpat3 =
Pdef(\snrpat3,
	Pbindf(
		~snrpat0,
		\curve, -8,
		\freq, ~snrfreq1,
		\dur, Prand([0.5, 0.75, 1], inf),
		\note, Pseq([Rest, 1], inf),
));

/*
~snrpat3.play(t, quant: 1);
~snrpat3.isPlaying;
~snrpat3.pause;
*/

~snrpat4 =
Pdef(\snrpat4,
	Pbindf(
		~snrpat3,
		\level, ~snrecholvl,
));

/*
~snrpat4.play(t, quant: 1);
~snrpat4.isPlaying;
~snrpat4.pause;
*/

~snrpat5 =
Pdef(\snrpat5,
	Pbindf(
		~snrpat3,
		\level, ~snrecholvl,
));

/*
~snrpat5.play(t, quant: 1);
~snrpat5.isPlaying;
~snrpat5.pause;
*/

////////////////

~snrpat6 =
Pdef(\snrpat6,
	Pbindf(
		~snrpat0,
		\dur, Prand([0.5, 0.75, 1], inf),
		\freq, ~snrfreq2,
));

/*
~snrpat6.play(t, quant: 1);
~snrpat6.isPlaying;
~snrpat6.pause;
*/

~snrpat7 =
Pdef(\snrpat7,
	Pbindf(
		~snrpat6,
		\level, ~snrecholvl,
));

/*
~snrpat7.play(t, quant: 1);
~snrpat7.isPlaying;
~snrpat7.pause;
*/

~snrpat8 =
Pdef(\snrpat8,
	Pbindf(
		~snrpat6,
		\level, ~snrecholvl,
));

/*
~snrpat8.play(t, quant: 1);
~snrpat8.isPlaying;
~snrpat8.pause;
*/

//////////////////////

~snrpat9 =
Pdef(\snrpat9,
	Pbindf(
		~snrpat0,
		\curve, -16,
		\dur, Prand([0.5, 0.75, 1], inf),
		\freq, ~snrfreq3,
		\note, Pseq([Rest, 1, Rest, Rest, 1, Rest, Rest, Rest, 1], inf),
));

/*
~snrpat9.play(t, quant: 1);
~snrpat9.isPlaying;
~snrpat9.pause;
*/

~snrpat10 =
Pdef(\snrpat10,
	Pbindf(
		~snrpat9,
		\level, ~snrecholvl,
));

/*
~snrpat10.play(t, quant: 1);
~snrpat10.isPlaying;
~snrpat10.pause;
*/

~snrpat11 =
Pdef(\snrpat11,
	Pbindf(
		~snrpat9,
		\level, ~snrecholvl,
));
);

/*
~snrpat11.play(t, quant: 1);
~snrpat11.isPlaying;
~snrpat11.pause;
*/

////////////////

~snrpar0 = Pdef(\snrpar0, Ppar([~snrpat0, ~snrpat1, ~snrpat2], inf));

/*
~snrpar0.play(t, quant: 1);
~snrpar0.isPlaying;
~snrpar0.pause;
*/

~snrpar1 = Pdef(\snrpar1, Ppar([~snrpat3, ~snrpat4, ~snrpat5].stutter(2)));

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

~snrpar3 = Pdef(\snrpar3, Ppar([~snrpat9, ~snrpat10, ~snrpat11].stutter(2)));

/*
~snrpar3.play(t, quant: 1);
~snrpar3.isPlaying;
~snrpar3.pause;
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

(
~snrpar3ktrl = MIDIdef.cc(\snrpar3ktrl, {
	if(~snrpar3.isPlaying.not) {
		~snrpar3.play(t, quant: 1);
		"snrpar3 play".postln;
	} {
		~snrpar3.pause;
		"snrpar3 stop".postln;
	};
}, 67, srcID: ~nanoktrl2);
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
		\pan, -0.5
));
);

(
~hatpatr =
Pdef(\hatpatr,
	Pbindf(
		~hatpatl,
		\pan, 0.5
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
		\pan, Prand([-1, -0.5, 0.5, 1], inf),
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
SynthDef(\crumble, { | a = 1, b = 1.9, bwr = 0.03, curve = -16, dur = 1, freq = 100, gate = 1, level = 1, outbus = 0, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var n				=	8;
	var mix				=	Mix.fill(n, {
		arg i;
		var clipnfreq		=	4;
		var clipn			=	LFClipNoise.kr(clipnfreq).range(0.5, 1);
		var cusp			=	CuspL.ar(a: a, b: b, mul: (envgen * clipn) / n);
		BPF.ar(cusp, (freq * (((4/3) + 0.03) ** i)).clip(50, SampleRate.ir / 3), bwr, (20 / (i + 1).pow(2)));
	});
	var lor				=	Lorenz2DC.ar(mul: 0.5, add: 1);
	var sin				=	SinOsc.ar((freq * lor).clip(50, SampleRate.ir / 3), mul: envgen / 96);
	var flt				=	RLPF.ar(mix + sin, freq * 12, 0.1);
	var pan2			=	Pan2.ar(flt, pan);
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
		\bwr, Pbrown(0.001, 0.01, 0.001, inf),
		\degree, 0,
		\dur, Pwrand([Pseq([0.125], 2), 0.5, 0.75, 1, 1.5], [1, 16, 16, 16, 16].normalizeSum, inf),
		\level, Pbrown(0.5, 1, 0.1, inf),
		\octave, 6,
		\pan, Prand([-0.5, 0, 0.5], inf),
		\scale, ~scale,
));
);

/*
~crumblepdef0.play(t, quant: 1);
~crumblepdef0.isPlaying;
~crumblepdef0.pause;
*/

(
~crumblepdef1 =
Pdef(\crumblepdef1,
	Pbindf(
		~crumblepdef0,
));
);

/*
~crumblepdef1.play(t, quant: 1);
~crumblepdef1.isPlaying;
~crumblepdef1.pause;
*/

//

(
~crumblepdef2 =
Pdef(\crumblepdef2,
	Pbindf(
		~crumblepdef0,
		\degree, 1,
));
);

/*
~crumblepdef2.play(t, quant: 1);
~crumblepdef2.isPlaying;
~crumblepdef2.pause;
*/

(
~crumblepdef3 =
Pdef(\crumblepdef3,
	Pbindf(
		~crumblepdef2,
));
);

/*
~crumblepdef3.play(t, quant: 1);
~crumblepdef3.isPlaying;
~crumblepdef3.pause;
*/

//

(
~crumblepdef4 =
Pdef(\crumblepdef4,
	Pbindf(
		~crumblepdef0,
		\degree, 7,
));
);

/*
~crumblepdef4.play(t, quant: 1);
~crumblepdef4.isPlaying;
~crumblepdef4.pause;
*/

(
~crumblepdef5 =
Pdef(\crumblepdef5,
	Pbindf(
		~crumblepdef4,
));
);

/*
~crumblepdef5.play(t, quant: 1);
~crumblepdef5.isPlaying;
~crumblepdef5.pause;
*/

////

~crumblepar0 = Pdef(\crumblepar0, Ppar([~crumblepdef0, ~crumblepdef1], inf));

/*
~crumblepar0.play(t, quant: 1);
~crumblepar0.isPlaying;
~crumblepar0.pause;
*/

~crumblepar1 = Pdef(\crumblepar1, Ppar([~crumblepdef2, ~crumblepdef3], inf));

/*
~crumblepar1.play(t, quant: 1);
~crumblepar1.isPlaying;
~crumblepar1.pause;
*/

~crumblepar2 = Pdef(\crumblepar2, Ppar([~crumblepdef4, ~crumblepdef5], inf));

/*
~crumblepar2.play(t, quant: 1);
~crumblepar2.isPlaying;
~crumblepar2.pause;
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

(
~crumble2ktrl =
MIDIdef.cc(\crumble2ktrl, {
	if(~crumblepar2.isPlaying.not) {
		~crumblepar2.play(t, quant: 1);
		"crumble2 play".postln;
	} {
		~crumblepar2.pause;
		"crumble2 stop".postln;
	};
}, 68, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PNO /////////////////////////////////////////////////////////

(
~pno =
SynthDef(\pno, { | curve = -8, dur = 1, freq = 400, gate = 1, level = 0.002, pan = 0 |
	var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	Mix.fill(2, {
		arg i;
		var lfn			=	LFNoise1.kr(0.1, mul: 0.005, add: 1);
		var sin			=	SinOsc.ar((freq) * (i + 1) * lfn, pi/4, mul: envgen / (i + 1));
		sin;
	});
	var lfn				=	LFNoise1.kr(0.1, mul: 0.02, add: 1);
	var cusp			=	CuspL.ar(1000, a: lfn, mul: 0.5, add: 1);
	var sinhi			=	SinOsc.ar((freq * 13 * cusp).clip(50, SampleRate.ir / 3), mul: envgen);
	var pan2			=	Pan2.ar(sin + sinhi, pan);
	Out.ar(0, pan2);
}).add;
);

(
~pnopdef0 =
Pdef(\pnopdef0,
	Pbind(
		\instrument, \pno,
		\dur, Prand([0.25, 0.5], inf),
		\level, 0.002,
		\octave, 8,
		\pan, Prand([-1, 0, 1], inf),
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

(
~pnopdef1 =
Pdef(\pnopdef1,
	Pbindf(
		~pnopdef0,
		\degree, [-1, -3],
		\level, 0.0005,
));
);

~pnopar1 = Pdef(\pnopar1, Ppar(Array.fill(4, { ~pnopdef1 })));

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
SynthDef(\pno2, { | curve = -32, dur = 1, freq = 400, level = 0.005 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	SinOsc.ar(freq, mul: envgen / n);
	var n				=	20;
	var sinmix			=	Mix.fill(n, {
		arg i;
		var lfn1modfrq		=	Array.fill(2, { 0.03 });
		var lfn1modmul		=	Array.fill(2, { 0.001 * i });
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
		\degree, 0,
		\dur, Pshuf([9, 10, 11].nthPrime.postln, inf),
		\octave, 6,
		\scale, ~scale,
));
);

/*
~pno2pat.play(t, quant: 0.5);
~pno2pat.isPlaying;
~pno2pat.pause;
*/

(
~pno2pat1 =
Pdef(\pno2pat1,
	Pbind(
		\instrument, \pno2,
		\curve, -8,
		\degree, Pshuf(~scaledegrees, inf),
		\dur, Pshuf([0.5, 0.75, 1, 1.5, 2, 3], inf),
		\octave, 6,
		\scale, ~scale,
));
);

/*
~pno2pat1.play(t, quant: 0.5);
~pno2pat1.isPlaying;
~pno2pat1.pause;
*/

~pno2par1 = Pdef(\pno2par1, Ppar(Array.fill(8, { ~pno2pat1 })));

/*
~pno2par1.play(t, quant: 0.5);
~pno2par1.isPlaying;
~pno2par1.pause;
*/

// Midi Control

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
	var env				=	Env.asr(0.005, level, 0.05);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbn				=	LFBrownNoise0.kr([15, 15], mul: 0.8, add: 1);
	var n				=	4;
	var mix				= 	Mix.fill(n, {
		arg i;
		//var lfn			=	LFNoise1.kr([0.1, 0.1], mul: 0.0005, add: 1);
		var lfn			=	1;
		SinOsc.ar((freq * (i + 1)), mul: envgen * kbn / (i + 1).pow(4));
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
		\degree, [-4, -1],
		\dur, Pseq([13, 14, 15].nthPrime.postln, inf),
		\legato, 0.5,
		\octave, 6,
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
		\dur, Pseq([14, 15, 16].nthPrime.postln, inf),
));
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
		~dronepat0,
		\degree, [0, 7],
		\dur, Pseq([15, 16, 17].nthPrime.postln, inf),
));
);

/*
~dronepat2.play(t, quant: 1);
~dronepat2.isPlaying;
~dronepat2.pause;
*/

// Midi Control

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

(
~drone2ktrl = MIDIdef.cc(\drone2ktrl, {
	if(~dronepat2.isPlaying.not) {
		~dronepat2.play(t, quant: 0.25);
		"drone2 play".postln;
	} {
		~dronepat2.pause;
		"drone2 stop".postln;
	};
}, 70, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PAD /////////////////////////////////////////////////////////

// Synth

(
~pad =
SynthDef(\pad, { | curve = 0, dur = 1, freq = 400, gate = 1, level = 0.008 |
	//var env 			=	Env.sine(dur / 1.5, level);
	var env				=	Env.asr(4, level, 4, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbnenv			=	LFBrownNoise0.kr(15).range(0.1, 1).round(0.1);
	var n				=	12;
	var mix				=	Mix.fill(n, {
		arg i;
		var klfn		=	LFNoise1.kr([0.1, 0.1], 0.003, 1);
		var freqgap		= 	3;
		var saw0		=	LFSaw.ar([freq, freq + (i / freqgap)] * klfn, mul: envgen / (i + 1));
		var saw1		=	LFSaw.ar([freq + ((i + 1) / freqgap), freq + ((i + 2) / freqgap)], mul: envgen / n);
		saw0 + saw1;
	});
	var lor				=	Lorenz2DC.ar(mul: 0.5, add: 1);
	var sin				=	SinOsc.ar(6000 * lor, mul: envgen / 6);
	var sinmix			=	mix + sin;
	var lpf				=	BLowPass4.ar(sinmix, freq * 1.5);
	var rhpf			=	BHiPass4.ar(sinmix, 8000, 0.02, mul: 0.1);
	var filtmix			=	lpf + rhpf;
	var striated		=	filtmix * kbnenv;
	Out.ar(0, striated);
}).add;
);

// Pattern

(
~scaledegrees.postln;
~chords0 = Array.fill(~scale.size, { arg i; [i, i + 2, i + 7, i + 9] });
~chords1 = ~chords0 + (~scale.size);
'chords0: '.postln;
~chords0.postln;
'chords1: '.postln;
~chords1.postln;
'size of each array: '.postln;
~chords0.size.postln;
);

(
~padpatdurarr = Array.fill(5, { arg i; (i + 4).nthPrime });
~padpatdurarr.postln;
~padpat0 =
Pdef(\padpat0,
	Pbind(
		\instrument, \pad,
		\degree, Prand(~chords0 ++ [Rest].stutter(6), inf),
		//\degree, Place(~chords0),
		\dur, Prand(~padpatdurarr, inf),
		\root, 0,
		//\root, (~scale.size - 1) * -1,
		\scale, ~scale,
));
);

/*
~padpat0.play(t, quant: 1);
~padpat0.isPlaying;
~padpat0.pause;
*/

// (
// ~padpat1 =
// Pdef(\padpat1,
// 	Pbindf(
// 		~padpat0,
// 		\degree, Prand(~chords1 ++ [Rest].stutter(3), inf)
// ));
// );

/*
~padpat1.play(t, quant: 1);
~padpat1.isPlaying;
~padpat1.pause;
*/

// (
// ~padhi =
// Pdef(\padhi,
// 	Pbind(
// 		\instrument, \pad,
// 		\degree, [0, 5],
// 		\dur, 31,
// 		\level, 0.002,
// 		\root, (~scale.size - 1) * 2,
// 		\scale, ~scale,
// ));
// );

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

// (
// ~pad1ktrl = MIDIdef.cc(\pad1ktrl, {
// 	if(~padpat1.isPlaying.not) {
// 		~padpat1.play(t, quant: 1);
// 		"pad1 play".postln;
// 	} {
// 		~padpat1.pause;
// 		"pad1 stop".postln;
// 	};
// }, 55, srcID: ~nanoktrl2);
// );
//
// (
// ~padhiktrl = MIDIdef.cc(\padhiktrl, {
// 	if(~padhi.isPlaying.not) {
// 		~padhi.play(t, quant: 1);
// 		"padhi play".postln;
// 	} {
// 		~padhi.pause;
// 		"padhi stop".postln;
// 	};
// }, 71, srcID: ~nanoktrl2);
// );