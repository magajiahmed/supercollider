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

(
~ratios = [1/1, 15/14, 9/8, 7/6, 3/2, 7/4, 81/32, 8/3, 14/5, 28/9];
~tuning = Tuning.new(~ratios.ratiomidi);
~bassscale = Scale.new(#[0, 1, 2, 3, 5], ~ratios.size, ~tuning);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
);

////////////////////////////////////////////////////////
// BASS ////////////////////////////////////////////////

// SynthDef

(
~bass = SynthDef(\bass, { | curve = 0, dur = 1, freq = 100, klormul = 0.5, level = 0.1, s = 10, width = 0.5 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var kwn				=	Lag2.ar(WhiteNoise.ar(0.99, add: 1), 0.1);
	var saw0			=	VarSaw.ar([freq, freq + 0.1], width: width, mul: envgen / 2);
	var saw1			=	VarSaw.ar([freq, freq + 0.1] * kwn, width: width, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var lpf				=	BLowPass4.ar(sawmix, freq);
	var rhpf			=	RHPF.ar(sawmix, 4000, 0.1);
	var sin				=	SinOsc.ar([freq, freq + 0.1], mul: envgen);
	Out.ar(0, lpf + rhpf + sin);
}).add;
);

// Pattern

(
~klormularray = Array.fill(3, { arg i; 0.05 * (i + 1) });
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\curve, -4,
		\degree, Prand([-1, 0, 1, 2, 3], inf),
		\dur, Prand([0.25, 0.5, 0.75, 4, 6, 8, 12], inf),
		\klormul, Prand(~klormularray, inf),
		\root, -24,
		\s, Pwhite(9, 11, inf),
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
// PERC ////////////////////////////////////////////////

// SynthDef

(
~prc =
SynthDef(\prc, { | curve = -48, freq = 1000, level = 0.1, pan = 0 |
	var env				= 	Env.perc(releaseTime: 0.5, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var bn				=	LFBrownNoise0.ar(freq, mul: envgen);
	var resonz			=	Resonz.ar(bn, freq, 0.05, 12);
	var pan2			=	Pan2.ar(resonz, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
~freqarray = (11..14) * 1000;
~prcpatl =
Pdef(\prcpatl,
	Pbind(
		\instrument, \prc,
		\dur, Prand([0.25, Pseq([1/3], 3), 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
		\freq, Prand(~freqarray, inf),
		\level, Prand([0.25, 0.5, 0.75, 1] * 0.2, inf),
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
		\dur, Prand([0.5, 0.75], inf),
		\freq, Pwhite(9000, 10000, inf),
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
SynthDef(\snr, { | curve = -32, level = 0.02 |
	var env				=	Env.perc(releaseTime: 0.25, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var clip			=	LFClipNoise.ar([13000, 13000], mul: envgen);
	var blow			=	BLowPass4.ar(clip, 6000, 0.1);
	Out.ar(0, blow);
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
		\note, Pseq([Rest, 1, Rest], inf),
));
);

/*
~snrpat.play(t, quant: 0.5);
~snrpat.isPlaying;
~snrpat.pause;
*/

(
~snrktrl = MIDIdef.cc(\snrktrl, {
	if(~snrpat.isPlaying.not) {
		~snrpat.play(t, quant: 0.5);
		"snr play".postln;
	} {
		~snrpat.pause;
		"snr stop".postln;
	};
}, 34, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// HAT /////////////////////////////////////////////////////////

// SynthDef

(
~hat =
SynthDef(\hat, { | level = 0.1, pan = 0 |
	var env				=	Env.perc(0.003, 0.05, level, 0);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var imp 			=	Impulse.ar(0, mul: envgen);
	var rlpf			=	RLPF.ar(imp, 8000, 0.01);
	var pan2			=	Pan2.ar(rlpf, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
~hatpatl =
Pdef(\hatpatl,
	Pbind(
		\instrument, \hat,
		\dur, Prand([0.5, 0.75, 1, 1.5], inf),
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
		\level, 0.008,
		\pan, Prand([-1, 1], inf),
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
SynthDef(\crumble, { | gate = 1, level = 0.001 |
	var env				=	Env.asr(0.2, level, 1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var n				=	8;
	var mix				=	Mix.fill(n, {
		arg i;
		var clipnfreq		=	50;
		var clipn			=	LFClipNoise.kr([clipnfreq, clipnfreq]).range(0, 1);
		var cusp			=	CuspL.ar(mul: [envgen, envgen] * clipn);
		BPF.ar(cusp, ((i / 8) + 1) * 500, 0.03, 64);
	});
	var kbn				=	LFBrownNoise0.kr(10).range(0, 1);
	var mixmod			=	mix * kbn;
	Out.ar(0, mixmod);
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
		~crumbles = Synth(\crumble).register;
		"crumble play".postln;
	} {
		~crumbles.release;
		~crumbles = nil;
		"crumble stop".postln;
	}
}, 36, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PAD /////////////////////////////////////////////////////////

// Synth

(
~pad =
SynthDef(\pad, { | dur = 1, freq = 400, gate = 1, hpffreq = 10000, level = 0.05 |
	var env 			=	Env.sine(dur, level);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var n				=	18;
	var mix				=	Mix.fill(n, {
		arg i;
		var kwn			=	Lag2.ar(WhiteNoise.ar(0.2, add: 1), 0.5);
		LFSaw.ar([freq, freq] * kwn, mul: envgen / n);
	});
	var lpf				=	BLowPass4.ar(mix, freq * 1.5);
	var rhpf			=	RHPF.ar(mix, hpffreq, 0.3, mul: 0.3);
	Out.ar(0, lpf + rhpf)
}).add;
);

// Pattern

(
// Take all possible combinations of the array of scale degrees and find the arrays containing n members (i.e., all n-note chords).
~chords = ~scaledegrees.powerset.reject({ arg i; i.size != 4 });
~chords.size.postln;
~padpat =
Pdef(\padpat,
	Pbind(
		\instrument, \pad,
		\degree, Prand(~chords ++ [Rest].stutter(300), inf),
		//\degree, Prand(~chords, inf),
		\dur, Prand([8, 12, 16], inf),
		\legato, 1,
		\scale, ~scale,
));
);

/*
~padpat.play(t, quant: 1);
~padpat.isPlaying;
~padpat.stop;
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
}, 37, srcID: ~nanoktrl2);
);