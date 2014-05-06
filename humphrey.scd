s.scope;
~scale = Scale.chromatic;
t = TempoClock(88/60);

(
SynthDef(\thump, { | dur = 1, freq = 400, level = 0.2, rezfreq = 12000 |
	var env				=	Env.perc(releaseTime: 1.5, level: level, curve: -16);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var	sin1			=	SinOsc.ar([freq, freq * 1.01], mul: envgen);
	var sin2			=	SinOsc.ar([freq, freq * 1.01] * 2, mul: envgen/2);
	var saw				=	Saw.ar([freq, freq * 1.01], mul: envgen);
	var rlpf			=	RLPF.ar(saw, freq * 2, 0.5);
	var rez				=	Resonz.ar(saw, rezfreq, 0.01);
	Out.ar(0, rlpf + rez);
}).add
);

(
~thumpat =
Pdef(\thumpat,
	Pbind(
		\instrument, \thump,
		\degree, Pshuf([0, 3].stutter(5), inf),
		\dur, Pseq([Pshuf([Pseq([0.25], 3), 0.75, Pseq([0.25, 0.75]), 1.5, 3].stutter(5)), 17], inf),
		\octave, 3,
		\rezfreq, Pseq([6000, 12000], inf),
		\scale, ~scale
))
);

/*
~thumpat.play(t, quant: 0.5);
~thumpat.pause;
*/

////////////////////////////////////////////////////////////////////////////////////////////

(
SynthDef(\drone, { | freq = 400, gate = 1, glissamp = 1, level = 0.03 |
	var env				=	Env.asr(5, level, 5, -4);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var sin				=	SinOsc.ar(freq.dup, mul: envgen / 4);
	var n				= 	4;
	var sawmix 			=	Mix.fill(n, {
		var noiz1			=	LFNoise0.kr(1.dup).range(0, 0.003);
		var noiz2			=	LFNoise0.kr(0.1.dup, mul: noiz1 * glissamp, add: 1);
		var saw				=	Saw.ar(freq * noiz2, envgen / n);
		saw
	});
	var rlpf			=	BLowPass4.ar(sawmix, freq * 2);
	var deci			=	Decimator.ar(sawmix, bits: 5, mul: envgen);
	var rez				=	Resonz.ar(deci, freq * 16, 0.1, 16);
	var n2				= 	8;
	var rezmix			=	Mix.fill(n2, {
		arg i;
		//var lor				=	Lorenz2DC.kr(0.05, 0.5, [10 + (i / n2), 11 + (i / n2)]).range(3000, 6000);
		var lat				=	Latoocarfian2DC.kr(0.01, 1, [1, 1.001]).range(3000, 6000);
		var rez				=	Resonz.ar(sawmix, lat.clip(3000, 6000), 0.005, 16 / n2);
		rez
	});
	var leakdc				=	LeakDC.ar(sin + rlpf + rez + rezmix);
	Out.ar(0, leakdc).clip(-0.9, 0.9);
}).add
);

// (
// ~dronepat =
// Pdef(\dronepat,
// 	Pmono(
// 		\drone,
// 		\degree, [0, 7],
// 		\octave, 4,
// 		\scale, ~scale
// ))
// );

(
~dronepat1 =
Pdef(\dronepat1,
	Pbind(
		\instrument, \drone,
		\degree, [0, 7],
		\dur, 84,
		\legato, 0.5,
		\octave, 4,
		\scale, ~scale
))
);

/*
~dronepat1.play(t, quant: 1);
~dronepat1.pause;
*/

(
~dronepat2 =
Pdef(\dronepat2,
	Pbindf(
		~dronepat1,
		\degree, 2,
		\dur, 53,
		\octave, 5,
))
);

/*
(
~dronepat2 =
Pdef(\dronepat2,
	Pbind(
		\instrument, \drone,
		// \degree, Pseq([
		// 	2, 2, 3,
		// 	2, 2, 2, 3,
		// 	2, 2, 2, 2, 3
		// ], inf),
		\degree, 2,
		\dur, 53,
		//\glissamp, 0.1,
		\legato, 0.5,
		\scale, ~scale
))
);
*/


/*
~dronepat2.play(t, quant: 1);
~dronepat2.pause;
*/

//////////////////////////////////////////////////////////////////////////////////////////////////////////

(
SynthDef(\click, { | bwr = 0.1, ffreq = 4000 |
	var env				=	Env.perc(0.003, 0.1, 1, 0);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var imp				=	BlitB3.ar(0.dup, mul: envgen);
	var rlpf			=	Resonz.ar(imp, ffreq, bwr, 128);
	Out.ar(0, rlpf);
}).add
);

(
~clickpat =
Pdef(\clickpat,
	Pbind(
		\instrument, \click,
		\dur, 1.25,
		\note, Pseq([
			Rest, 1,
			Rest, Rest, 1,
			Rest, Rest, Rest, 1,
		], inf),
))
);

/*
~clickpat.play(t, quant: 1);
~clickpat.isPlaying;
~clickpat.pause;
*/

(
~clickpat2 =
Pdef(\clickpat2,
	Pbind(
		\instrument, \click,
		\ffreq, 12000,
		\note, Pseq([
			1, 1, Rest,
			1, 1, 1, Rest,
			1, 1, 1, 1, Rest
		], inf)
	)
)
);

/*
~clickpat2.play(t, quant: 1);
~clickpat2.isPlaying;
~clickpat2.pause;
*/

/////////////////////////////////////////////////////////////////////////

(
SynthDef(\kick, { | freq = 50, level = 0.15 |
	var env				=	Env.perc(releaseTime: 1, level: level, curve: -64);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin1			=	SinOsc.ar(freq.dup, mul: envgen);
	var sin2			=	SinOsc.ar((freq.dup) * 2, mul: envgen/4);
	Out.ar(0, sin1 + sin2);
}).add
);

(
~kickpat =
Pdef(\kickpat,
	Pbind(
		\instrument, \kick,
		\dur, 0.75,
		\degree, Pseq([
			0, Rest,
			0, Rest, Rest,
			0, Rest, Rest, Rest
		], inf),
		\octave, 3,
		\scale, ~scale,
	))
);

/*
~kickpat.play(t, quant: 1);
~kickpat.isPlaying;
~kickpat.pause;
*/

/////////////////////////////////////////////////////////////////////////////

(
SynthDef(\pno, { | a = 1, dur = 1, freq = 400, level = 0.01 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: -16);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lat 			=	Latoocarfian2DC.ar(a: a, mul: 0.2, add: 1).clip(0.5, 2);
	var sin1			=	SinOsc.ar([freq, freq * 1.001] * lat, mul: envgen);
	var sin2			=	SinOsc.ar([freq, freq * 1.001], mul: envgen);
	Out.ar(0, sin1 + sin2);
}).add
);

(
~pnopat1 =
Pdef(\pnopat1,
	Pbind(
		\instrument, \pno,
		\a, Prand((1..6) / 2, inf),
		\dur, Pshuf([7, 9, 11, 13, 15] + 0.25, inf),
		\degree, Pshuf(([0, 1, 2, 3, 7]).stutter(5), inf),
		\octave, 6,
		\scale, ~scale,
		\strum, Pwhite(-0.1, 0.1, inf),
))
);

/*
~pnopat1.play(t, quant: 1);
~pnopat1.isPlaying;
~pnopat1.pause;
*/

~pnopat2 = Pdef(\pnopat2, Pbindf(~pnopat1));

/*
~pnopat2.play(t, quant: 1);
~pnopat2.isPlaying;
~pnopat2.pause;
*/

~pnopar = Pdef(\pnopar, Ppar(Array.fill(8, { ~pnopat1 })));

/*
~pnopar.play(t, quant: 1);
~pnopar.pause;
*/