(
~root = 7;
~tuning = Tuning.new([1/1, 15/14, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 12/7, 7/4, 28/15]);
~scale = Scale.new((0..11), 12, ~tuning);
);

s.scope;

t = TempoClock(90/60);

////////////////////////////////////////////////////////////////

(
SynthDef(\string, { |dur = 1, freq = 440, gate = 1, level = 0.05, xlinestart = 1|
	var env				=	Env.asr(5, level, 10, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var xline			=	XLine.kr(xlinestart, 1, dur / 2);
	var fbmod			=	SinOsc.ar([freq - 0.1, freq + 0.1] * xline, mul: 0.9, add: 1);
	var n				=	4;
	var mix 			=	Mix.fill(n, {
		var freqmod			=	LFNoise1.kr(0.2!2, 0.001, 1);
		var sinfb			=	SinOscFB.ar(freq * freqmod, fbmod, envgen / n).fold2(level / 2);
		sinfb;
	});
	var rhpf			=	RHPF.ar(mix, (freq * 8).clip(50, SampleRate.ir / 3), 0.1);
	var rez				=	RHPF.ar(mix, (freq * 2).clip(50, SampleRate.ir / 3), 0.1);
	var ampmod			=	LFNoise0.ar(30!2).range(0.25, 1).round(0.25);
	Out.ar(0, (mix + rhpf + rez) * ampmod);
}).add;
);

//

~stringpat0 = Pdef(\stringpat0, Pmono(\string, \note, [-5, 0], \root, ~root, \scale, ~scale, \xlinestart, 1));

/*
~stringpat0.play(t, quant: 0.5);
~stringpat0.isPlaying;
~stringpat0.stop;
*/

(
~chords = [
	//[-5, -2, 0], [-5, 0, 0], [-5, 0, 1], [-5, 0, 2], [-5, 0, 3], [0, 6, 7], [0, 7, 7]
	[-5, -2, 0], [-5, -1, 0], [-5, 0, 0], [-5, 0, 1], [-5, 0, 2], [0, 3, 7], [0, 4, 7], [0, 6, 7], [0, 7, 7]
];
~rests = Rest!(~chords.size / 2);
~chordsandrests = ~chords ++ ~rests;

~stringpat1 =
Pdef(\stringpat1,
	Pbind(
		\instrument, \string,
		\dur, Pshuf(Array.fill(4, { |i| (i + 5).nthPrime }), inf),
		\legato, 0.5,
		\note, Pshuf(~chordsandrests, inf),
		\octave, 5,
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
		\legato, 1,
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
		\note, [-2, 2],
		\octave, 6
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
		\note, [2, 7],
		\octave, 6
));
);

/*
~stringpat4.play(t, quant: 0.5);
~stringpat4.isPlaying;
~stringpat4.stop;
*/

(
~stringpat5 =
Pdef(\stringpat5,
	Pbindf(~stringpat2,
		\note, [0, 0, 7, 7, 12, 12],
		\octave, 3,
		\xlinestart, 4
));
);

/*
~stringpat5.play(t, quant: 0.5);
~stringpat5.isPlaying;
~stringpat5.stop;
*/

(
~stringpat6 =
Pdef(\stringpat6,
	Pbindf(~stringpat2,
		\note, [-2, 0, 2, 7],
		\octave, 7,
		\xlinestart, 0.5
));
);

/*
~stringpat6.play(t, quant: 0.5);
~stringpat6.isPlaying;
~stringpat6.stop;
*/

(
~stringpat7 =
Pdef(\stringpat7,
	Pbindf(~stringpat2,
		\note, [2, 7, 12],
		\octave, 7,
		\xlinestart, 0.5
));
);

/*
~stringpat7.play(t, quant: 0.5);
~stringpat7.isPlaying;
~stringpat7.stop;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\sin, {
	|amp = 0.1, curve = -8, dur = 1, fb = 0, foldfactor = 1, freq = 440, rlpf_freq = 880, rlpf_rq = 1, rhpf_freq = 8800, rhpf_rq = 1, sawfreq = 100|
	var env				=	Env.perc(0.005, dur, amp, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var noiz			=	LFNoise0.kr(30!2).range(0.999, 1);
	var sin				=	SinOscFB.ar([freq, freq * 1.0005], fb).round(amp / 2).fold2((amp * noiz) / foldfactor) * (foldfactor * noiz) * envgen;
	var rlpf			=	RLPF.ar(sin, rlpf_freq.clip(50, SampleRate.ir / 3), rlpf_rq).fold2(amp / foldfactor) * foldfactor;
	var rhpf 			=	RHPF.ar(sin, rhpf_freq.clip(50, SampleRate.ir / 3), rhpf_rq).fold2(amp / foldfactor) * foldfactor;
	Out.ar(0, rlpf + rhpf);
}).add;
);

(
~wat1 =
Pdef(\wat1,
	Pbind(
		\instrument, \sin,
		\amp, 0.03,
		\dur, Prand([Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, 1.5, 12], inf),
		\fb, Pwhite(0.0, 2.5, inf),
		\foldfactor, Pwhite(10.0, 100.0, inf),
		//\note, Prand((-2..6), inf),
		\note, Pshuf([-2, 0, 1, 2, 3, 7], inf),
		//\note, 0,
		//\octave, Pwhite(4, 7, inf),
		\octave, 5,
		\rlpf_freq, Pwhite(100.0, 10000.0, inf),
		\rlpf_rq, Pwhite(0.01, 1.0, inf),
		\rhpf_freq, Pwhite(1000.0, 15000.0, inf),
		\rhpf_rq, Pwhite(0.01, 1.0, inf),
		\root, ~root,
		\scale, ~scale,
));
//~wat2 = Pdef(\wat2, Pbindf(~wat1, \note, Prand([0, 7], inf)));
///
~watpar = Pdef(\watpar, Ppar(~wat1!4, inf));
);

/*
~wat1.play(t, quant: 0.5);
~wat1.isPlaying;
~wat1.stop;
*/

/*
~watpar.play(t, quant: 0.5);
~watpar.isPlaying;
~watpar.stop;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\bass, { |curve = -2, dur = 1, fb = 2.0, freq = 440, level = 0.02, rhpffrq = 2000|
	var env				=	Env.perc(0.01, dur, level, curve).kr(2);
	var imp				=	Impulse.ar(0);
	var sinfb			=	SinOscFB.ar([freq, freq * 1.005], fb, mul: env);
	var comb			=	CombL.ar(imp + sinfb, (freq).reciprocal, (freq).reciprocal).softclip;
	var lpf				=	MoogVCF.ar(comb, 1000, 0.1);
	var xline			=	XLine.kr(1, 0.5, dur);
	var rhpfrqmod		=	LFBrownNoise0.kr(freq!2).range(0.3, 1);
	var rhpf			=	RHPF.ar(comb, (rhpffrq * xline).clip(50, SampleRate.ir / 3), rhpfrqmod);
	var leakdc			=	LeakDC.ar(lpf + rhpf);
	Out.ar(0, leakdc);
}).add;
);

(
~durs = (1..3);
~shortestdurs = ~durs.collect({ |i| Pseq([0.25], i) });
~shorterdurs = ~durs.collect({ |i| Pseq([0.5], i) });
~shortdurs = ~durs.collect({ |i| Pseq([0.75], i) });
~mediumdurs = ~durs.collect({ |i| 1 * i });
~longdurs = ~durs.collect({ |i| 1.5 * i });
~bassdurs = ~shortestdurs ++ ~shorterdurs ++ ~shortdurs ++ ~mediumdurs ++ ~longdurs;
~basspat1 =
Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
		//\dur, Pshuf([
		//	0.25, Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, Pseq([0.25], 4), 1, Pseq([0.25], 6), 1.5, 2, 3, 4, 6, 8, 12
		//].stutter(3), inf),
		\dur, Pshuf(~bassdurs, inf),
		\fb, Pwhite(2.0, 3.0, inf),
		\note, Pshuf((-2..6).stutter(3), inf),
		\octave, 2,
		\rhpffrq, 8000,
		\root, ~root,
		\scale, ~scale
));
);

/*
~basspat1.play(t, quant: 0.5);
~basspat1.isPlaying;
~basspat1.stop;
*/

~basspat2 = Pdef(\basspat2, Pbindf(~basspat1, \curve, -8, \note, Prand([0, 7, 12], inf)));

/*
~basspat2.play(t, quant: 0.5);
~basspat2.isPlaying;
~basspat2.stop;
*/

~basspar = Pdef(\basspar, Ppar([~basspat1, ~basspat2], inf));

/*
~basspar.play(t, quant: 0.5);
~basspar.isPlaying;
~basspar.stop;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\prc, { |curve = -4, dur = 1, fb = 5.0, freq = 440, k = 1.4, level = 0.2, rhpffreq = 8000, x = 4.97897, y = 5.74734|
	var env				=	Env.perc(0.01, 0.3, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var stan			=	Standard2DN.ar(freq / 2, freq, k: k, x0: x, y0: y).range(fb, fb + 2);
	var sinfb			=	SinOscFB.ar([freq, freq * 1.005], stan, envgen);
	var rlpf			=	RLPF.ar(sinfb, (freq * 16).clip(50, SampleRate.ir / 3), 0.3);
	var rhpf			=	RHPF.ar(sinfb, (freq * 32).clip(50, SampleRate.ir / 3), 0.3);
	Out.ar(0, rlpf + rhpf);
}).add;
);

(
~karray = Array.series(11, 0.1, pi / 8);
~xarray = Array.series(13, 0.1, pi / 5);
~prcpat1a =
Pdef(\prcpat1a,
	Pbind(
		\instrument, \prc,
		\dur, Pshuf([Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12].stutter(3), inf),
		\fb, Pshuf((0..10) / 5, inf),
		\curve, Pshuf([-4, -16, -64], inf),
		\k, Pshuf(~karray, inf),
		\level, 0.1,
		\note, 0,
		\octave, 5,
		\root, ~root,
		\scale, ~scale,
		\x, Pshuf(~xarray, inf),
));
~prcpat1b = Pdef(\prcpat1b, Pbindf(~prcpat1a));
~prcpat1c = Pdef(\prcpat1c, Pbindf(~prcpat1a, \level, 0.05));
~prcpar1 = Pdef(\prcpar1, Ppar([~prcpat1a, ~prcpat1b, ~prcpat1c]));
);

/*
~prcpar1.play(t, quant: 0.5);
~prcpar1.isPlaying;
~prcpar1.stop;
*/

//

(
~prcpat2a = Pdef(\prcpat2a, Pbindf(~prcpat1a, \fb, 0, \octave, [0, 1, 2]));
~prcpat2b = Pdef(\prcpat2b, Pbindf(~prcpat2a, \dur, Prand([0.25, 0.5, 0.75, 1, 3], inf), \level, 0.05));
~prcpar2 = Pdef(\prcpar2, Ppar([~prcpat2a, ~prcpat2b]));
);

/*
~prcpar2.play(t, quant: 0.5);
~prcpar2.isPlaying;
~prcpar2.stop;
*/

////

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
		\note, 0,
		\octave, 8,
		\root, ~root,
		\scale, ~scale
));
~hatpat2 = Pdef(\hatpat2, Pbindf(~hatpat1, \dur, Prand([0.25, 0.5, 0.75], inf), \level, 0.02));
~hatpar = Pdef(\hatpar, Ppar([~hatpat1, ~hatpat2], inf));
);

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
		\dur, Pshuf([0.5, 0.75, 1.25].stutter(5), inf),
		\fb, Pwhite(2.7, 3.2, inf),
		\level, 0.01,
		\note, 0,
		\octave, 3,
		\root, ~root,
		\scale, ~scale
));

~pulsepat1b = Pdef(\pulsepat1b, Pbindf(~pulsepat1a, \level, 0.02));
~pulsepat1c = Pdef(\pulsepat1c, Pbindf(~pulsepat1b, \level, 0.02));
~pulsepar = Pdef(\pulsepar, Ppar([~pulsepat1a, ~pulsepat1b, ~pulsepat1c]));
);

/*
~pulsepar.play(t, quant: 0.5);
~pulsepar.isPlaying;
~pulsepar.stop;
*/