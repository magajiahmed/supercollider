(
~root = 7;
~tuning = Tuning.new([1/1, 15/14, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 12/7, 7/4, 28/15]);
~scale = Scale.new((0..11), 12, ~tuning);
);

s.scope;

t = TempoClock(80/60);

////////////////////////////////////////////////////////////////

(
SynthDef(\string, { |dur = 1, freq = 440, gate = 1, level = 0.05, xlinestart = 1|
	//var env				=	Env.sine(dur, level);
	//var envgen			=	EnvGen.kr(env, doneAction: 2);
	var env				=	Env.asr(5, level, 15, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var xline			=	XLine.kr(xlinestart, 1, dur / 2);
	var fbmod			=	SinOsc.ar([freq - 0.1, freq + 0.1] * xline, mul: 0.9, add: 1);
	var n				=	4;
	var mix 			=	Mix.fill(n, {
		var freqmod			=	LFNoise1.kr(0.2!2, 0.001, 1);
		var sinfb			=	SinOscFB.ar(freq * freqmod, fbmod, envgen / n).fold2(level / 2);
		sinfb;
	});
	//var rlpf			=	RLPF.ar(mix, (freq * 4).clip(50, SampleRate.ir / 3), 0.3);
	var rhpf			=	RHPF.ar(mix, (freq * 8).clip(50, SampleRate.ir / 3), 0.1);
	var ampmod			=	LFNoise0.kr(30!2).range(0.5, 1).round(0.5);
	Out.ar(0, (mix + rhpf) * ampmod);
}).add;
);

//

(
~chords = [
	[-5, -2, 0], [-5, 0, 0], [-5, 0, 1], [-5, 0, 2], [-5, 0, 3], [0, 6, 7], [0, 7, 7]
];
~rests = Rest!(~chords.size / 2);
~chordsandrests = ~chords ++ ~rests;

~stringpat1 =
Pdef(\stringpat1,
	Pbind(
		\instrument, \string,
		\dur, Pshuf(Array.fill(4, { |i| (i + 5).nthPrime }), inf),
		\legato, 1,
		\note, Pshuf(~chordsandrests, inf),
		\root, ~root,
		\scale, ~scale,
		\xlinestart, Pshuf([0.25, 1/3, 0.5, 0.75, 1, 1.5, 2, 3, 4], inf),
));
);

/*
~stringpat1.play(t, quant: 0.5);
~stringpat1.isPlaying;
~stringpat1.stop;
*/

(
~stringpat2 =
Pdef(\stringpat2,
	Pbindf(
		~stringpat1,
		\legato, 0.5,
		\note, [7, 12],
		\xlinestart, 0.25,
));
);

/*
~stringpat2.play(t, quant: 0.5);
~stringpat2.isPlaying;
~stringpat2.stop;
*/

(
~stringpat3 =
Pdef(\stringpat3,
	Pbindf(
		~stringpat2,
		\note, [10, 14],
));
);

/*
~stringpat3.play(t, quant: 0.5);
~stringpat3.isPlaying;
~stringpat3.stop;
*/

(
~stringpat4 =
Pdef(\stringpat4,
	Pbindf(
		~stringpat2,
		\note, [14, 19],
));
);

/*
~stringpat4.play(t, quant: 0.5);
~stringpat4.isPlaying;
~stringpat4.stop;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\bass, { |dur = 1, fb = 2.0, freq = 440, level = 0.02, rhpffrq = 2000|
	var env				=	Env.perc(0.01, dur, level, -2).kr(2);
	var imp				=	Impulse.ar(0);
	var sinfb			=	SinOscFB.ar(freq!2, fb, mul: env);
	var comb			=	CombL.ar(imp + sinfb, (freq).reciprocal, (freq).reciprocal).softclip;
	var lpf				=	MoogVCF.ar(comb, 2000, 0.1);
	var xline			=	XLine.kr(1, 0.5, dur);
	var rhpfrqmod		=	LFBrownNoise0.kr(freq!2).range(0.3, 1);
	var rhpf			=	RHPF.ar(comb, (rhpffrq * xline).clip(50, SampleRate.ir / 3), rhpfrqmod);
	Out.ar(0, lpf + rhpf);
}).add;
);

(
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24].stutter(3), inf),
		\fb, Pwhite(2.0, 3.0, inf),
		\note, Pshuf([-2, 0, 1, 2, 3, 6, 7], inf),
		\octave, 2,
		\rhpffrq, Pwhite(3000, 6000, inf),
		\root, ~root,
		\scale, ~scale
));
);

/*
~basspat.play(t, quant: 0.5);
~basspat.isPlaying;
~basspat.stop;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\prc, { |curve = -4, dur = 1, freq = 440, freqstart = 2, k = 1.4, level = 0.2, x = 4.97897, y = 5.74734|
	var env				=	Env.perc(0.01, 0.3, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var stan			=	Standard2DC.ar(freq / 2, freq, k: k, x0: x, y0: y).range(5.0, 6.0);
	var sinfb			=	SinOscFB.ar(freq!2, stan, envgen).wrap2(level);
	var rlpf			= 	RLPF.ar(sinfb, (freq * 8).clip(50, SampleRate.ir / 3));
	var rez				=	Resonz.ar(sinfb, (XLine.kr(freq * 16, freq, 0.1)).clip(50, SampleRate.ir / 3));
	//var rhpf			=	RHPF.ar(sinfb, 12000, 0.1);
	Out.ar(0, rez);
}).add;
);

(
~prcpat1a =
Pdef(\prcpat1a,
	Pbind(
		\instrument, \prc,
		\curve, 0,
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].stutter(3), inf),
		\freqstart, Pshuf([7/8, 1, 7/6, 3/2, 2], inf),
		\k, Pwhite(0.1, 4.0, inf),
		\level, 0.2,
		\note, 0,
		\octave, 5,
		\root, ~root,
		\scale, ~scale,
		\x, Pwhite(0.1, 9.0, inf),
));
);

/*
~prcpat1a.play(t, quant: 0.5);
~prcpat1a.stop;
*/

//

~prcpat1b = Pdef(\prcpat1b, Pbindf(~prcpat1a, \level, 0.05));

/*
~prcpat1b.play(t, quant: 0.5);
~prcpat1b.stop;
*/

//

~prcpar1 = Pdef(\prcpar1, Ppar([~prcpat1a, ~prcpat1b]));

/*
~prcpar1.play(t, quant: 0.5);
~prcpar1.stop;
*/

//

~prcpat2a = Pdef(\prcpat2a, Pbindf(~prcpat1a, \curve, 0, \octave, [0, 1, 2]));

/*
~prcpat2a.play(t, quant: 0.5);
~prcpat2a.stop;
*/

//

~prcpat2b = Pdef(\prcpat2b, Pbindf(~prcpat2a, \dur, Prand([0.25, 0.5, 0.75, 3], inf), \level, 0.05));

/*
~prcpat2b.play(t, quant: 0.5);
~prcpat2b.stop;
*/

//

~prcpar2 = Pdef(\prcpar2, Ppar([~prcpat2a, ~prcpat2b]));

/*
~prcpar2.play(t, quant: 0.5);
~prcpar2.stop;
*/

//

~prcpar = Pdef(\prcpar, Ppar([~prcpar1, ~prcpar2]));

/*
~prcpar.play(t, quant: 0.5);
~prcpar.isPlaying;
~prcpar.stop;
*/

////////////////////////////////////////////////////////

(
SynthDef(\hat, { |curve = -16, dur = 1, fb = 0, freq = 440, level = 0.05|
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise0.kr(50!2, 0.0005, 1);
	var sinfb			=	SinOscFB.ar(freq!2 * lfn, fb).fold2(0.03) * envgen * 40;
	var rhpf			=	RHPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.1);
	Out.ar(0, rhpf);
}).add;
);

(
~hatpat1 =
Pdef(\hatpat1,
	Pbind(
		\instrument, \hat,
		\curve, -16,
		\dur, Prand([Pseq([0.125], 2), 0.5, 0.75, 1, 1.5, 6], inf),
		\fb, Pshuf(Array.series(10, 0.1, 0.1), inf),
		\level, 0.08,
		//\note, Pwrand([0, 3], [2, 1].normalizeSum, inf),
		\note, 0,
		\octave, 8,
		\root, ~root,
		\scale, ~scale
));
);

/*
~hatpat1.play(t, quant: 1);
~hatpat1.isPlaying;
~hatpat1.stop;
*/

~hatpat2 = Pdef(\hatpat2, Pbindf(~hatpat1, \dur, Prand([0.25, 0.5, 0.75], inf), \level, 0.02));

/*
~hatpat2.play(t, quant: 1);
~hatpat2.isPlaying;
~hatpat2.stop;
*/

~hatpar = Pdef(\hatpar, Ppar([~hatpat1, ~hatpat2], inf));

/*
~hatpar.play(t, quant: 1);
~hatpar.isPlaying;
~hatpar.stop;
*/

//

(
~pulsepat1a =
Pdef(\pulsepat1a,
	Pbind(
		\instrument, \hat,
		\curve, -4,
		\dur, Pshuf([0.5, 0.75].stutter(5), inf),
		\fb, Pwhite(2.7, 3.2, inf),
		\note, 0,
		\octave, 3,
		\root, ~root,
		\scale, ~scale
));
);

/*
~pulsepat1a.play(t, quant: 0.5);
~pulsepat1a.stop;
*/

//

~pulsepat1b = Pdef(\pulsepat1b, Pbindf(~pulsepat1a, \level, 0.008));

/*
~pulsepat1b.play(t, quant: 0.5);
~pulsepat1b.stop;
*/

//

~pulsepat1c = Pdef(\pulsepat1c, Pbindf(~pulsepat1b, \level, 0.008));

/*
~pulsepat1c.play(t, quant: 0.5);
~pulsepat1c.stop;
*/

//

~pulsepar = Pdef(\pulsepar, Ppar([~pulsepat1a, ~pulsepat1b, ~pulsepat1c]));

/*
~pulsepar.play(t, quant: 0.5);
~pulsepar.isPlaying;
~pulsepar.stop;
*/