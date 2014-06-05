~root = 4;
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
	var fbsin				=	FBSineC.ar(([freq, freq * 1.002] * 16).dup, mul: envgen);
	var rlpf				=	RLPF.ar(fbsin, freq * 2);
	var rhpf				=	RHPF.ar(fbsin, (freq * 16).clip(50, SampleRate.ir / 3), 0.05);
	var pan2				=	Pan2.ar(rlpf + rhpf, pan);
	Out.ar(0, pan2);
}).add
);

(
~mbiradegrees1 = [-1, 0, 1, 4];
// ~mbiradegrees2 = [4, 6];
// ~mbiradegrees3 = [7, 8, 9];
~mbiradurs1 = [2/5, 3/5, 2/5, 2/5, 3/5, 3/5, 2/5, 2/5, 3/5, 2/5, 3/5, 3/5];
// ~mbiradurs2 = [2/5, 3/5];
// ~mbiradurs3 = ~mbiradurs2 + (1/5);
~sinpat1 =
Pdef(\sinpat1,
	Pbind(
		\instrument, \sinth,
		\degree, Pseq([Pshuf(~mbiradegrees1.stutter(5), 5)], inf),
		\dur, Pseq(~mbiradurs1, inf),
		\octave, 5,
		\pan, -1,
		\root, ~root,
		\scale, ~scale
))
);

~sinpat2 = Pdef(\sinpat2, Pbindf(~sinpat1, \pan, 1));
~sinpar = Pdef(\sinpar, Ppar([~sinpat1, ~sinpat2], inf));

/*
~sinpar.play(t, quant: 4);
~sinpar.isPlaying;
~sinpar.pause;
*/

(
~sinpat3 =
Pdef(\sinpat3,
	Pbindf(
		~sinpat1,
		\degree, -3,
		\dur, Pseq(~mbiradurs1, inf),
		\pan, 0
));
~sinpat4 = Pdef(\sinpat4, Pbindf(~sinpat3, \dur, 1));
~sinpar2 = Pdef(\sinpar2, Ppar([~sinpat3, ~sinpat4], inf));
);

/*
~sinpar2.play(t, quant: 1);
~sinpar2.isPlaying;
~sinpar2.pause;
*/

(
~sinpat5 =
Pdef(\sinpat5,
	Pbindf(
		~sinpat1,
		\degree, 6,
		\dur, Pseq(~mbiradurs1, inf),
		\pan, 0
));
~sinpat6 = Pdef(\sinpat6, Pbindf(~sinpat5, \dur, 1));
~sinpar3 = Pdef(\sinpar3, Ppar([~sinpat5, ~sinpat6], inf));
);

/*
~sinpar3.play(t, quant: 1);
~sinpar3.isPlaying;
~sinpar3.pause;
*/

/*
~sinpar.stop;
~sinpar2.stop;
~sinpar3.stop;
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
		//\dur, Pshuf([8/5, 7/5].stutter(5), inf),
		\dur, Pseq([2, 1.5, 1.5], inf),
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
	var sinfb			=	SinOscFB.ar([freq, freq * 1.001] * lfn, 0.3, envgen);
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
SynthDef(\klk, { | freq = 8000, level = 0.05, pan = 0 |
	var env				=	Env.perc(0.0005, 0.001, level, -64);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise1.ar(12000.dup, envgen);
	var rhpf			=	RHPF.ar(lfn, 8000, 0.5);
	var pan2			=	Pan2.ar(rhpf, pan);
	Out.ar(0, pan2);
}).add
);

(
~klkpat =
Pdef(\klkpat,
	Pbind(
		\instrument, \klk,
		\freq, Pwhite(6000, 6500, inf),
))
);

/*
~klkpat.play(t, quant: 1);
~klkpat.isPlaying;
~klkpat.pause;
*/

(
~klkechodurs = ([6, 6, 7, 6, 6, 6, 7, 6, 6, 6, 6, 7] - 2) / 5;
~klkpat2 =
Pdef(\klkpat2,
	Pbindf(
		~klkpat,
		\dur, Pseq(~klkechodurs, inf),
		\level, 0.013,
		\pan, -1
));

~klkpat3 =
Pdef(\klkpat3,
	Pbindf(
		~klkpat2,
		\dur, Pseq(~klkechodurs.reverse, inf)
))
);


/*
~klkpat2.play(t, quant: 1);
~klkpat2.isPlaying;
~klkpat2.pause;
*/

~klkpar = Pdef(\klkpar, Ppar([~klkpat, ~klkpat2, ~klkpat3], inf));

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
		\dur, Pseq([
			4/5, 4/5, 7/5,
			4/5, 4/5, 4/5, 7/5,
			4/5, 4/5, 4/5, 4/5, 7/5
		], inf),
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
		\dur, 2,
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
		\dur, Pseq([1/5, 1, 2, 3].mirror2, inf),
		\freq, 1000,
		//\note, Pseq([Rest, 0], inf)
))
);

/*
~kikpat.play(t, quant: 1);
~kikpat.isPlaying;
~kikpat.pause;
*/