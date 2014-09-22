~root = 7;

s.scope;

t = TempoClock(90/60);

(
SynthDef(\string, { |dur = 1, freq = 440, level = 0.05|
	var env				=	Env.sine(dur, level);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise1.kr(0.05, 0.5, 1);
	var sin				=	SinOsc.ar(freq!2 * lfn, mul: 0.5, add: 1);
	var sinfb			=	SinOscFB.ar(freq!2, sin, envgen).fold2(level / 2);
	var rlpf			=	RLPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.3);
	var rhpf			=	RHPF.ar(sinfb, (freq * 8).clip(50, SampleRate.ir / 3), 0.3);
	Out.ar(0, rlpf + rhpf);
}).add;
);

//

~chords = (0..11).collect({ |item, i| [7, 12] ++ [item] });
~rests = [Rest].stutter(~chords.size);
~chordsandrests = ~chords ++ ~rests;

(
~stringpat =
Pdef(\stringpat,
	Pbind(
		\instrument, \string,
		\dur, Pshuf(Array.fill(5, { |i| (i + 5).nthPrime }), inf),
		\note, Pshuf(~chordsandrests, inf),
		\octave, 4,
		\root, ~root,
));
);

~stringpat.play(t, quant: 0.5);
~stringpat.stop;

//

~stringpar = Pdef(\stringpar, Ppar(Array.fill(2, {~stringpat}), inf));

~stringpar.play(t, quant: 0.5);
~stringpar.isPlaying;
~stringpar.stop;

////////////////////////////////////////////////////////////////

(
SynthDef(\bass, { |dur = 1, freq = 440, level = 0.3|
	var env				=	Env.perc(0.01, dur, level, -2);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var n				=	8;
	var mix				=	Mix.fill(n, {
		|i|
		var bn				=	LFBrownNoise0.kr(freq, mul: 0.005, add: 1);
		var crackl			=	Crackle.kr(1.5!2, 0.9, 1);
		var sinfb			=	SinOscFB.ar(freq * bn, crackl, envgen / n).fold2(level);
		sinfb;
	});
	Out.ar(0, mix);
}).add;
);

(
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24].stutter(3), inf),
		\note, Pshuf([-2, 0, 1, 2, 3, 6, 7], inf),
		\octave, 2,
		\root, ~root
));
);

~basspat.play(t, quant: 0.5);
~basspat.stop;

////////////////////////////////////////////////////////////////

(
SynthDef(\prc, { |curve = -16, freq = 440, k = 1.4, level = 0.2, x = 4.97897, y = 5.74734|
	var env				=	Env.perc(0.01, 0.2, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var stan			=	Standard2DC.ar(k: k, x0: x, y0: y, add: 1);
	var sinfb			=	SinOscFB.ar(freq!2, stan + 5, envgen).wrap2(level);
	var rlpf			= 	RLPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.3);
	var rez				=	Resonz.ar(sinfb, (freq * 8).clip(50, SampleRate.ir / 3), 0.3) * 2;
	Out.ar(0, rlpf + rez);
}).add;
);

(
~prcpat1 =
Pdef(\prcpat1,
	Pbind(
		\instrument, \prc,
		\curve, -16,
		\dur, Prand([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6], inf),
		\k, Pwhite(0.1, 4.0, inf),
		\level, 0.2,
		\root, ~root,
		\x, Pwhite(0.1, 9.0, inf),
));
);

~prcpat1.play(t, quant: 0.5);
~prcpat1.stop;

//

~prcpat1a = Pdef(\prcpat1a, Pbindf(~prcpat1, \level, 0.05));

~prcpat1a.play(t, quant: 0.5);
~prcpat1a.stop;

//

~prcpat2 = Pdef(\prcpat2, Pbindf(~prcpat1, \curve, -4, \octave, [0, 1, 2]));

~prcpat2.play(t, quant: 0.5);
~prcpat2.stop;

////////////////////////////////////////////////////////

(
SynthDef(\hat, { |curve = -16, dur = 1, fb = 5, freq = 440, level = 0.02|
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sinfb			=	SinOscFB.ar([freq, freq * 1.002], fb, envgen);
	var rlpf			=	RHPF.ar(sinfb, (freq * 4).clip(50, SampleRate.ir / 3), 0.1);
	Out.ar(0, rlpf);
}).add;
);

(
~hatpat =
Pdef(\hatpat,
	Pbind(
		\instrument, \hat,
		\curve, Pwrand([-16, 0], [64, 1].normalizeSum, inf),
		\dur, 0.25,
		\fb, Pshuf((1..6), inf),
		\octave, 7,
		\root, 7
));
);

~hatpat.play(t, quant: 1);
~hatpat.stop;

//

~hatpar = Pdef(\hatpar, Ppar([~hatpat].stutter(4), inf));

~hatpar.play(t, quant: 1);
~hatpar.stop;

//

~pnopat1 = Pdef(\pnopat1, Pbind(\instrument, \hat, \dur, Prand([0.5, 0.75], inf), \fb, 0.1, \level, 0.8, \root, ~root));

~pnopat1.play(t, quant: 0.5);
~pnopat1.stop;

//

~pnopat2 = Pdef(\pnopat2, Pbindf(~pnopat1, \level, 0.3));

~pnopat2.play(t, quant: 0.5);
~pnopat2.stop;
