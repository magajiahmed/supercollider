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
~bass = SynthDef(\bass, { | curve = 0, dur = 1, freq = 100, level = 0.1, width = 0.5 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var klfn0			=	LFNoise1.ar(18000, 0.999, 1);
	var klfn1			=	LFNoise1.kr(1, 0.01, 1);
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
~durations = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6];
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\curve, -4,
		\degree, Prand([0, 1, 2, 3], inf),
		\dur, Pwrand(~durations, ~durations.reverse.normalizeSum, inf),
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
SynthDef(\prc, { | curve = -64, freq = 1000, level = 0.05, pan = 0 |
	var env				= 	Env.perc(releaseTime: 0.25, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var bn				=	LFBrownNoise0.ar(freq, mul: envgen);
	var kbn				=	LFBrownNoise1.kr(50).range(0.5, 2);
	var resonz			=	Resonz.ar(bn, freq * kbn, 0.1, 12);
	var pan2			=	Pan2.ar(resonz, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
//~freqarray = (11..14) * 1000;
~freqarray = [500, 1000, 2000, 10000, 11000, 12000, 13000];
~freqarray.postln;
~freqarray.mirror2.postln;
~prcpatl =
Pdef(\prcpatl,
	Pbind(
		\instrument, \prc,
		\dur, Pshuf([0.25, 0.25, 0.5, 0.75, 1, 1.5, 2, 3].mirror2, inf),
		\freq, Pshuf(~freqarray.mirror2, inf),
		\level, Prand([0.25, 0.5, 0.75, 1] * 0.08, inf),
		\pan, -1,
)));

(
~prcpatr =
Pdef(\prcpatr,
	Pbindf(~prcpatl, \pan, 1));
);

~prcpar = Pdef(\prcpar, Ppar([~prcpatl, ~prcpatr], inf));

/*
~prcpar.play(t, quant: 0.5);
~prcpar.isPlaying;
~prcpar.stop;
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
		\level, 0.008,
		\pan, Pwhite(-0.5, 0.5, inf),
));
);

// Midi Control

(
~prcktrl = MIDIdef.cc(\prcktrl, {
	if(~prcpar.isPlaying.not) {
		~prcpar.play(t, quant: 0.5);
		"prc play".postln;
	} {
		~prcpar.pause;
		"prc stop".postln;
	};
}, 33, srcID: ~nanoktrl2);
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
}, 49, srcID: ~nanoktrl2);
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
~snrpat =
Pdef(\snrpat,
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
~snrpat.play(t, quant: 1);
~snrpat.isPlaying;
~snrpat.pause;
*/

(
~snrpat2 =
Pdef(\snrpat2,
	Pbindf(
		~snrpat,
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
~snrpat2.play(t, quant: 1);
~snrpat2.isPlaying;
~snrpat2.pause;
*/

(
~snrpat3 =
Pdef(\snrpat3,
	Pbindf(
		~snrpat,
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
~snrpat3.play(t, quant: 1);
~snrpat3.isPlaying;
~snrpat3.pause;
*/

(
~snrpar = Pdef(\snrpar, Ppar([~snrpat2, ~snrpat3], inf));
);

/*
~snrpar.play(t, quant: 1);
~snrpar.isPlaying;
~snrpar.pause;
*/

// Midi Control

(
~snrktrl = MIDIdef.cc(\snrktrl, {
	if(~snrpat.isPlaying.not) {
		~snrpat.play(t, quant: 1);
		"snr play".postln;
	} {
		~snrpat.pause;
		"snr stop".postln;
	};
}, 34, srcID: ~nanoktrl2);
);

(
~snrparktrl = MIDIdef.cc(\snrparktrl, {
	if(~snrpar.isPlaying.not) {
		~snrpar.play(t, quant: 1);
		"snrpar play".postln;
	} {
		~snrpar.pause;
		"snrpar stop".postln;
	};
}, 50, srcID: ~nanoktrl2);
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
		\dur, Prand([0.5, 0.75, 1, 1.5], inf),
		\level, Prand([0.5, 1] * 0.08, inf),
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

(
~hatpar = Pdef(\hatpar, Ppar([~hatpatl, ~hatpatr], inf));
);

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
		\level, 0.01,
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
SynthDef(\crumble, { | gate = 1, level = 0.0015, outbus = 0 |
	var env				=	Env.asr(2, level, 1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var n				=	4;
	var mix				=	Mix.fill(n, {
		arg i;
		var clipnfreq		=	50;
		var clipn			=	LFClipNoise.kr([clipnfreq, clipnfreq]).range(0, 1);
		var cusp			=	CuspL.ar(mul: ([envgen, envgen] * clipn) / n);
		BPF.ar(cusp, ((i / 8) + 1) * 500, 0.03, 400);
	});
	var kbn				=	LFBrownNoise0.kr(10).range(0, 1);
	var mixmod			=	mix * kbn;
	Out.ar(outbus, mixmod);
}).add;
);

/*
~crumbles = Synth(\crumble).register;
~crumbles.isPlaying;
~crumbles.release;
*/

// Midi Control

(
~crumblektrl =
MIDIdef.cc(\crumblektrl, {
	if (~crumbles.isNil) {
		~crumbles = Synth(\crumble, [\outbus, [0, 2]]).register;
		"crumble play".postln;
	} {
		~crumbles.release;
		~crumbles = nil;
		"crumble stop".postln;
	}
}, 36, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PNO /////////////////////////////////////////////////////////

(
~pno =
SynthDef(\pno, { | curve = -2, dur = 1, freq = 400, level = 0.01, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var n				=	8;
	var mix				= 	Mix.fill(n, {
		arg i;
		var lfn			=	LFNoise1.kr(10, mul: (i / (n + 100)), add: 1);
		SinOsc.ar(freq * lfn * (i + 1) + (i / 10), mul: envgen / (i + 1).pow(6));
	});
	var sinhi			=	SinOsc.ar((freq * 13).clip(50, SampleRate.ir / 3), mul: envgen / 8);
	var pan2			=	Pan2.ar(mix + sinhi, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
~pnopatl =
Pdef(\pnopatl,
	Pbind(
		\instrument, \pno,
		\dur, 0.25,
		\degree, Prand([5, Pseq([-7, -8]), Pseq([-7, -8, 0]), Pseq([-7, -8, 0, 1])], inf),
		\legato, 1,
		\level, 0.005,
		\pan, -1,
		\root, (~scale.size - 1),
		\scale, ~scale,
		\spice, Pwhite(3, 3, inf),
));
);

/*
~pnopatl.play(t, quant: 1);
~pnopatl.isPlaying;
~pnopatl.stop;
*/

(
~pnopatr =
Pdef(\pnopatr,
	Pbindf(
		~pnopatl,
		\pan, 1
));
);

(
~pnopar = Pdef(\pnopar, Ppar([~pnopatl, ~pnopatr], inf));
);

/*
~pnopar.play(t, quant: 1);
~pnopar.isPlaying;
~pnopar.pause;
*/

(
~pnoktrl = MIDIdef.cc(\pnoktrl, {
	if(~pnopar.isPlaying.not) {
		~pnopar.play(t, quant: 1);
		"pno play".postln;
	} {
		~pnopar.pause;
		"pno stop".postln;
	};
}, 37, srcID: ~nanoktrl2);
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
		var lfn1modmul		=	Array.fill(2, { 0.02 * i });
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
		\dur, Pseq([5, 7, 11].nthPrime.postln, inf),
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
}, 53, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PAD /////////////////////////////////////////////////////////

// Synth

(
~pad =
SynthDef(\pad, { | dur = 1, freq = 400, gate = 1, hpffreq = 8000, level = 0.02 |
	var env 			=	Env.sine(dur, level);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbnenv			=	LFBrownNoise0.kr(10).range(0.5, 1);
	var n				=	18;
	var mix				=	Mix.fill(n, {
		arg i;
		var klfn		=	LFNoise1.kr(0.1, 0.001, 1);
		LFSaw.ar([freq, freq] * klfn, mul: (envgen * kbnenv) / n);
	});
	var lpf				=	BLowPass4.ar(mix, freq * 1.5);
	var rhpf			=	RHPF.ar(mix, hpffreq, 0.1, mul: 0.3);
	Out.ar(0, lpf + rhpf)
}).add;
);

// Pattern

(
// Take all possible combinations of the array of scale degrees and find the arrays containing n members (i.e., all n-note chords).
~scaledegrees.postln;
~chords = ~scaledegrees.powerset.reject({ arg i; i.size != 5 });
~chords.postln;
~chords.size.postln;
~padpat =
Pdef(\padpat,
	Pbind(
		\instrument, \pad,
		\degree, Prand(~chords ++ [Rest].stutter(300), inf),
		//\degree, Prand(~chords, inf),
		\dur, Prand([8, 12, 16], inf),
		\legato, 1,
		\root, 0,
		\scale, ~scale,
));
);

/*
~padpat.play(t, quant: 1);
~padpat.isPlaying;
~padpat.pause;
*/

(
~padhi =
Pdef(\padhi,
	Pbind(
		\instrument, \pad,
		\degree, [0, 5],
		\dur, 31,
		\level, 0.01,
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
~padktrl = MIDIdef.cc(\padktrl, {
	if(~padpat.isPlaying.not) {
		~padpat.play(t, quant: 1);
		"pad play".postln;
	} {
		~padpat.pause;
		"pad stop".postln;
	};
}, 38, srcID: ~nanoktrl2);
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
}, 54, srcID: ~nanoktrl2);
);