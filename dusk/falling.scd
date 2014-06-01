~root = 2;
~scale = Scale.new(#[0, 2, 4, 6, 7, 9, 10], 12, name: 'mixo');
t = TempoClock(140/60);

////////////////////////////////////////////////////////////////

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\sinth, { | dur = 1, freq = 440, freq2 = 6000, level = 0.01, pan = 0 |
	var env					=	Env.perc(0.003, releaseTime: 0.75, level: level);
	var envgen				=	EnvGen.kr(env, doneAction: 2);
	var n					=	4;
	// var sinmix					=	Mix.fill(n, {
	// 	arg i;
	// 	var lfn					=	LFNoise1.kr(1, 0.001, 1);
	// 	var sin					=	SinOsc.ar((freq + i) * lfn, mul: envgen / n);
	// 	var hisin				=	SinOsc.ar(((freq * 8) + (i * 2)) * lfn, mul: envgen / (n * 24));
	// 	sin + hisin
	// });
	var fbsin				=	FBSineC.ar(([freq, freq * 1.002] * 16).dup, mul: envgen);
	var rlpf				=	RLPF.ar(fbsin, freq * 2);
	var rhpf				=	RHPF.ar(fbsin, freq * 32, 0.05);
	var pan2				=	Pan2.ar(rlpf + rhpf, pan);
	Out.ar(0, pan2);
}).add
);

(
~sinpat1 =
Pdef(\sinpat1,
	Pbind(
		\instrument, \sinth,
		\degree, Pseq([Pshuf([-1, 0, 1, 4].stutter(5), 5)], inf),
		\dur, Pseq([
			1/3, 0.5,
			1/3, 1/3, 0.5,
			1/3, 1/3, 1/3, 0.5
		], inf),
		\octave, 5,
		\pan, -1,
		\root, ~root,
		\scale, ~scale
))
);

~sinpat2 = Pdef(\sinpat2, Pbindf(~sinpat1, \pan, 1));

~sinpar = Pdef(\sinpar, Ppar([~sinpat1, ~sinpat2], inf));

/*
~sinpar.play(t, quant: 1);
~sinpar.isPlaying;
~sinpar.pause;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\pulse, { | dur = 1, freq = 440, level = 0.01, pan = 0 |
	var env				=	Env.perc(0.003, 1, level);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise1.kr(1, 0.003, 1);
	var tri				=	LFSaw.ar(freq * lfn, mul: envgen);
	var rlpf			=	BLowPass4.ar(tri, freq * 1.1, 0.3);
	var pan2			=	Pan2.ar(rlpf, pan);
	Out.ar(0, pan2);
}).add
);

(
~tripat =
Pdef(\tripat,
	Pbind(
		\instrument, \pulse,
		\degree, [-1, 0, 1, 4],
		\dur, Pshuf([8/5, 7/5].stutter(5), inf),
		\octave, 5,
		\pan, Pseq([-0.5, 0.5], inf),
		\root, ~root,
		\scale, ~scale,
))
);

/*
~tripat.play(t, quant: 1);
~tripat.isPlaying;
~tripat.pause;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\bass, { | freq = 440, gate = 1, level = 0.05 |
	var env				=	Env.asr(sustainLevel: level);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var lfn				=	LFNoise1.kr(0.1.dup, 0.003, 1);
	var sinfb			=	SinOscFB.ar([freq, freq * 1.001] * lfn, 0.75, envgen);
	Out.ar(0, sinfb);
}
).add
);

(
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\degree, Pshuf([-1, 0, 1, 3, 4], inf),
		\dur, 24,
		\octave, 3,
		\root, ~root,
		\scale, ~scale
))
);

/*
~basspat.play(t, quant: 1);
~basspat.isPlaying;
~basspat.pause;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\klk, { | freq = 8000, level = 0.05 |
	var env				=	Env.perc(0.0005, 0.001, level, -64);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	//var imp				=	BlitB3.ar(0, envgen);
	//var rlpf			=	RLPF.ar(imp, freq, 0.5);
	//var delay			=	AllpassC.ar(rlpf, 0.1, 0.01, 1);
	var lfn				=	LFNoise1.ar(12000.dup, envgen);
	var rhpf			=	RHPF.ar(lfn, 8000, 0.5);
	Out.ar([0, 1], rhpf);
}).add
);

(
~klkpat =
Pdef(\klkpat,
	Pbind(
		\instrument, \klk,
		\dur, 3/5,
		\freq, Pwhite(6000, 6500, inf),
))
);

/*
~klkpat.play(t, quant: 1);
~klkpat.isPlaying;
~klkpat.pause;
*/

(
~klkpat2 =
Pdef(\klkpat2,
	Pbindf(
		~klkpat,
		\dur, 1,
		\level, 0.02,
))
);


/*
~klkpat2.play(t, quant: 1);
~klkpat2.isPlaying;
~klkpat2.pause;
*/

~klkpar = Pdef(\klkpar, Ppar([~klkpat, ~klkpat2], inf));

/*
~klkpar.play(t, quant: 1);
~klkpar.isPlaying;
~klkpar.pause;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\snr, { | freq = 12000, ffreq = 1000, level = 0.15 |
	var env				=	Env.perc(releaseTime: 0.1, level: level, curve: -16);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise2.ar(freq.dup, envgen);
	var rlpf			=	RLPF.ar(lfn, ffreq, 0.1);
	Out.ar(0, rlpf);
}).add
);

(
~snrpat =
Pdef(\snrpat,
	Pbind(
		\instrument, \snr,
		\dur, 2,
		\freq, 12000,
		\ffreq, 1000,
		\note, Pseq([
			Rest, 0,
			Rest, 0, 0,
			Rest, 0, 0, 0
		], inf)
))
);

/*
~snrpat.play(t, quant: 1);
~snrpat.isPlaying;
~snrpat.pause;
*/

(
~snrpat2 =
Pdef(\snrpat2,
	Pbind(
		\instrument, \snr,
		\dur, Pseq([11/5], inf),
		\freq, Pwhite(11000, 13000, inf),
		\ffreq, 1000,
		\level, 0.015,
		\note, 0
))
);

/*
~snrpat2.play(t, quant: 1);
~snrpat2.isPlaying;
~snrpat2.pause;
*/

~snrpar = Pdef(\snrpar, Ppar([~snrpat, ~snrpat2], inf));

/*
~snrpar.play(t, quant: 1);
~snrpar.isPlaying;
~snrpar.pause;
*/

////////////////////////////////////////////////////////////////

(
~kikpat =
Pdef(\kikpat,
	Pbind(
		\instrument, \snr,
		\dur, Pseq([1/5, 4/5, 1], inf),
		\freq, 1000,
		\note, Pseq([Rest, 0], inf)
))
);

/*
~kikpat.play(t, quant: 1);
~kikpat.isPlaying;
~kikpat.pause;
*/