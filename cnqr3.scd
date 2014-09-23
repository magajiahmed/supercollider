~root = 7;

s.scope;

t = TempoClock(80/60);

(
SynthDef(\string, { |dur = 1, freq = 440, level = 0.05|
	var env				=	Env.sine(dur, level);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	SinOsc.ar(freq!2, mul: envgen);
	var fbmod			=	SinOsc.ar([freq - 0.1, freq + 0.1], mul: 0.9, add: 1);
	var sinfb			=	SinOscFB.ar(freq, fbmod, envgen).fold2(level / 2);
	var rlpf			=	RLPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3));
	var rhpf			=	RHPF.ar(sinfb, (freq * 16).clip(50, SampleRate.ir / 3), 0.1);
	var ampmod			=	LFNoise0.kr(15!2).range(0.7, 1).round(0.3);
	Out.ar(0, (sin + rlpf + rhpf) * ampmod);
}).add;
);

//

(
//~chords = [-2, 0, 1, 2, 3, 6, 7].collect({ |item, i| [item] ++ [0, 7] });
~chords = [[-5, -2, 0], [-5, 0, 0], [-5, 0, 1], [-5, 0, 2], [-5, 0, 3], [0, 6, 7], [0, 7, 7]];
//~rests = [Rest].stutter(~chords.size);
//~chordsandrests = ~chords ++ ~rests;

~stringpat =
Pdef(\stringpat,
	Pbind(
		\instrument, \string,
		\dur, Pshuf(Array.fill(5, { |i| (i + 5).nthPrime }), inf),
		\legato, 1,
		\note, Pshuf(~chords, inf).trace,
		\root, ~root,
));
);

~stringpat.play(t, quant: 0.5);
~stringpat.stop;

////////////////////////////////////////////////////////////////

(
SynthDef(\bass, { |dur = 1, freq = 440, level = 0.3|
	var env				=	Env.perc(0.01, dur, level, -2);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var n				=	8;
	var mix				=	Mix.fill(n, { |i|
		var bn				=	LFBrownNoise0.kr(freq, mul: 0.001, add: 1);
		var crackl			=	Crackle.kr(1.5!2, 0.9, 1);
		var sinfb			=	SinOscFB.ar(freq * bn, crackl, envgen / n).fold2(level);
		sinfb;
	});
	var rlpf			=	RLPF.ar(mix, freq * 2);
	var rhpf			=	RHPF.ar(mix, 3000, 0.2) / 2;
	Out.ar(0, rlpf + rhpf);
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
		\dur, Prand([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24], inf),
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

//

~prcpat2a = Pdef(\prcpat2a, Pbindf(~prcpat2, \level, 0.03));

~prcpat2a.play(t, quant: 0.5);
~prcpat2a.stop;

////////////////////////////////////////////////////////

(
SynthDef(\hat, { |curve = -16, dur = 1, fb = 5, freq = 440, level = 0.02|
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sinfb			=	SinOscFB.ar([freq, freq * 1.002], fb, envgen);
	var rlpf			=	RHPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.1);
	Out.ar(0, rlpf);
}).add;
);

(
~hatpat =
Pdef(\hatpat,
	Pbind(
		\instrument, \hat,
		\dur, Prand([0.5, 0.75, 1, 1.5], inf),
		\fb, Pshuf((1..6), inf),
		\octave, 8,
		\root, ~root
));
);

~hatpat.play(t, quant: 1);
~hatpat.stop;