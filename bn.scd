// INIT //////////////////////////////////////////////////////////

//midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl2 = 1310720;

//other stuff
s.scope(2);
t = TempoClock(135/60);

// SYNTHDEFS /////////////////////////////////////////////////////

~dynamix =
SynthDef(\dynamix, {
	var in	   		= 	In.ar(2, 2);
	var compressor	=	Compander.ar(in, in, thresh: 0.25, slopeAbove: 1/128, clampTime: 0.002);
	Out.ar(0, compressor);
}).add;

~startcompressor = {
	s.sync;
	~compressor = Synth(\dynamix).register;
}.fork;

~startcompressor;

/*
~compressor.free;
*/

//

~verb =
SynthDef(\verb, {
	var in			=	In.ar(4, 2);
	var kbn1		=	LFBrownNoise0.kr(add: 0.1);
	var kbn2		=	LFBrownNoise0.kr(add: 0.1);
	var verb		=	GVerb.ar(in, revtime: (15 * kbn2).clip(1, 30), damping: kbn1.clip(0, 1), mul: 0.05);
	Out.ar(2, verb);
}).add;

~startreverb = {
	s.sync;
	~reverb = Synth(\verb).register;
}.fork;

~startreverb;

/*
~reverb = Synth(\verb).register;
~reverb.isPlaying;
~reverb.free;

*/

//

~snr =
SynthDef(\snr, { | a = 1, curve = -4, freq = 500, level = 0.5, pan = 0 |
	var env 		=	Env.perc(attackTime: 0.005, releaseTime: 0.05, level: level, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var bn0			=	LFBrownNoise0.ar(freq, mul: envgen);
	var bn1			=	LFBrownNoise0.ar(freq, mul: envgen);
	var lat0		=	Latoocarfian2DC.ar(add: 1).clip(0.1, 1);
	var resl		=	RLPF.ar(bn0, freq * lat0, 0.05);
	var resr		=	RLPF.ar(bn1, freq * lat0, 0.05);
	var lat1		=	Latoocarfian2DC.ar(a: a, mul: 0.75, add: 1).clip(0.1, 1);
	var ap			=	AllpassL.ar([resl, resr], 0.05, (0.02 * lat1).clip(1 / (SampleRate.ir / 3), (SampleRate.ir / 3)), 0.05, mul: level/4);
	Out.ar([2, 4], [resl, resr] + ap).clip(-1, 1);
}).add;

//

~kik =
SynthDef(\kik, { | curve = -512, dur = 1, freq = 2000, level = 0.75, pan = 0 |
	var env 		=	Env.perc(attackTime: 0.003, level: level, releaseTime: dur, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var bnl			=	LFBrownNoise0.ar(freq, mul: envgen);
	var bnr			=	LFBrownNoise0.ar(freq, mul: envgen);
	var comp		= 	Compander.ar([bnl, bnr], [bnl, bnr], thresh: 0.3, slopeAbove: 1/8, clampTime: 0.002);
	var rlpf		=	RLPF.ar(comp, freq * 2, 0.5);
	Out.ar(2, rlpf).clip(-1, 1);
}).add;

//

~hat =
SynthDef(\hat, { | freq = 6400, level = 0.05, pan = 0 |
	var	env			=	Env.perc(attackTime: 0.003, releaseTime: 0.01, level: level, curve: -4);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var penv		=	Env.new([1, 0.5], [0.01]);
	var penvgen		=	EnvGen.kr(penv);
	var bn			=	LFBrownNoise0.ar(mul: 0.05, add: 1);
	var sin			=	SinOsc.ar((freq * penvgen * bn).clip(50, SampleRate.ir / 4), pi, mul: envgen);
	var pan2		=	Pan2.ar(sin, pan);
	Out.ar(2, pan2).clip(-1, 1);
}).add;

//

~prc =
SynthDef(\prc, { | freq = 500, level = 0.02, pan = 0 |
	var env			=	Env.perc(releaseTime: 0.2, level: level);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var bn			=	Crackle.ar(1.99, envgen);
	var pan2		=	Pan2.ar(bn, pan);
	Out.ar(0, pan2).clip(-0.5, 0.5);
}).add;

~prc2 =
SynthDef(\prc2, { | dur = 1, freq = 3200, im = 1, level = 0.03 |
	var env			=	Env.perc(releaseTime: dur, level: level, curve: -64);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var noiz		=	FBSineC.ar(freq, im: [im, (im + 0.1)], mul: envgen);
	var trig		=	Impulse.kr(4);
	var grain		=	GrainIn.ar(2, trig, in: noiz, mul: 1);
	Out.ar(0, noiz + grain).clip(-0.5, 0.5);
}).add;

//

~prc3 =
SynthDef(\prc3, { | a = 1, b = 1.9, curve = -512, dur = 1, freq = 22050, level = 0.1, pan = 0, xi = 0  |
	var env			=	Env.perc(attackTime: 0.01, releaseTime: dur, level: level, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var cusp		=	CuspL.ar(freq, a, b, xi, envgen);
	var pan2		=	Pan2.ar(cusp, pan);
	Out.ar(2, pan2);
}).add;

/*
~prctest = Synth(\prc);
*/

//

~bass =
SynthDef(\bass, { | a = 1, freq = 440, gate = 1, level = 0.05, ka = 0, ka1 = 1, ka2 = 1, klatmul = 0.01 |
	var env			=	Env.asr(attackTime: 0.003, sustainLevel: level, releaseTime: 0.1, curve: -64);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 2);
	var klat0 		=	Latoocarfian2DL.kr(0.1, 0.5, ka1, mul: klatmul, add: 1).clip(0.9, 1.1);
	var klat1 		=	Latoocarfian2DL.kr(0.1, 0.5, ka1, mul: klatmul, add: 1).clip(0.9, 1.1);
	var klat2 		=	Latoocarfian2DL.kr(0.1, 0.5, ka2, mul: klatmul, add: 1).clip(0.9, 1.1);
	var sin0		=	SinOsc.ar(freq, mul: envgen);
	var sin1		=	SinOsc.ar(freq * 2.02, mul: envgen);
	var sin2		=	SinOsc.ar(freq * 4.04, mul: envgen / 4);
	var saw			=	LFSaw.ar((freq * klat0).clip(freq - 1, freq * 2), mul: envgen);
	var sawl		=	LFSaw.ar(((freq - 0.01) * klat1).clip(freq - 2, freq * 2), mul: envgen);
	var sawr		=	LFSaw.ar(((freq + 0.01) * klat2).clip(freq - 2, freq * 2), mul: envgen);
	//var lat 		=	Latoocarfian2DC.ar(0.1, 1, a: a.clip(-3, 3), mul: 1, add: 1);
	var kbn0		= 	LFBrownNoise0.kr(mul: 0.6, add: 1).clip(0.1, 1.0);
	var rlpf		=	RLPF.ar([sawl, sawr] + [saw, saw], freq);
	var rhpf1		=	RHPF.ar([saw, saw], (freq * 256 * kbn0).clip(freq * 4, SampleRate.ir / 6), 0.05, mul: level * 3).clip(-0.1, 0.1);
	Out.ar(0, sin0 + sin1 + sin2 + rlpf + rhpf1).clip(-0.9, 0.9);
}).add;

//

~pno =
SynthDef(\pno, { | a = 1, dur = 1, freq = 440, latmul = 0.05, level = 0.25, pan = 0 |
	var env			=	Env.perc(releaseTime: dur, level: level);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var klat		=	Latoocarfian2DC.kr(a: a, mul: latmul, add: 1);
	var klat2		=	Latoocarfian2DC.kr(a: a + 0.01, mul: latmul, add: 1);
	var klat3		=	Latoocarfian2DC.ar(a: a - 0.01, mul: 1, add: 1);
	var sin1		=	SinOsc.ar(freq, mul: envgen);
	var sin1kl		=	SinOsc.ar(freq * klat, mul: envgen);
	var sin2		=	SinOsc.ar((freq * 2.01), mul: envgen / 64);
	var sin2kl		=	SinOsc.ar(freq * klat2, mul: envgen / 64);
	var sin20		=	SinOsc.ar((freq * 10.01 * klat3).clip(50, SampleRate.ir / 4), mul: envgen / 4);
	var sinmix		=	sin1 + sin1kl + sin20;
	var pan2 		=	Pan2.ar(sinmix, pan);
	Out.ar(0, pan2).clip(-1, 1);
}).add;

//

~sinpulse =
SynthDef(\sinpulse, { | a = 1, dur = 1, freq = 200, level = 0.05, pan = 0 |
	var env			=	Env.perc(attackTime: 0.005, releaseTime: dur, level: level, curve: -16);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var sin0		=	SinOsc.ar(freq, mul: envgen);
	var sin1		=	SinOsc.ar(freq * 2.08, mul: envgen / 8);
	var sin2		=	SinOsc.ar(freq * 4.16, mul: envgen / 16);
	var klat0		=	Latoocarfian2DC.kr(freq / 2, freq, a: a, mul: 0.9, add: 1).clip(0.1, 10);
	var klat1		=	Latoocarfian2DC.kr(freq / 2, freq, a: a, mul: 0.9, add: 1).clip(0.1, 10);
	var sin3		=	SinOsc.ar((freq * 11 * klat0).clip(50, SampleRate.ir / 4), mul: envgen / 16);
	var sin4		=	SinOsc.ar((freq * 13 * klat1).clip(50, SampleRate.ir / 4), mul: envgen / 16);
	var pan2		=	Pan2.ar(sin0 + sin1 + sin2 + sin3 + sin4, pan);
	Out.ar(0, pan2).clip(-0.9, 0.9);
}).add;

//

~grable =
SynthDef(\grable, { | a = 1, dur = 1, fb = 0, freq = 400, gate = 1, latmul = 0.5, level = 0.02 |
	var env			=	Env.asr(attackTime: 1, sustainLevel: level, releaseTime: 3);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 2);
	var kbnffrq		=	LFBrownNoise0.kr(mul: [0.2, 0.2], add: 1).clip(0.1, 1);
	var kbnrez		=	LFBrownNoise0.kr(mul: [0.25, 0.25], add: 1).clip(0.1, 1);
	var kbnfrq		=	LFBrownNoise0.ar(mul: [0.005, 0.005], add: 1).clip(0.1, 1);
	var kbnfb		=	LFBrownNoise0.ar(mul: [1, 1], add: 1).clip(0, 0.999);
	var kbnamp		=	LFBrownNoise0.ar(mul: 0.03, add: 1);
	var sin0		=	SinOscFB.ar([freq, freq + 0.3], (fb * kbnfb).clip(0, 0.999), mul: envgen).clip(-1, 1);
	var rlpf		=	RLPF.ar(sin0, freq * 2);
	var rhpf		=	RHPF.ar(sin0, (6000 * kbnffrq).clip(50, SampleRate.ir / 4), (0.75 * kbnrez).clip(0.01, 1));
	Out.ar(0, rlpf + rhpf).clip(-0.5, 0.5);
}).add;

//

~sinpad =
SynthDef(\sinpad, { | freq = 300, gate = 1, level = 0.003 |
	var env			=	Env.asr(attackTime: 5, sustainLevel: level, releaseTime: 5);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 2);
	var kbnf0		=	LFBrownNoise0.ar(freq * (7), mul: 0.02, add: 1);
	var kbna0 		=	LFBrownNoise0.kr(mul: 1, add: 1).round(1);
	var kbna1 		=	LFBrownNoise0.kr(mul: 0.2, add: 1);
	var sin0		=	SinOsc.ar(freq, mul: (envgen / 2) * kbna0);
	var sin1		=	SinOsc.ar(freq * (7) * kbnf0, mul: (envgen / 2) * kbna1);
	Out.ar([0, 1], sin0 + sin1);
}).add;

/*
~sinpadsyng = Synth(\sinpad, [\freq, 800]).register;
~sinpadsyng.isPlaying;
~sinpadsyng.release;
*/

~createsinpadGroup = { | freqs = #[1600, 2400] |
	~sinpadgroup = Group(s).register;
	freqs.do({|i|
		Synth.tail(~sinpadgroup, \sinpad, [\freq, i]);
	});
};

/*
~createsinpadGroup.value;
~sinpadgroup.isPlaying;
~sinpadgroup.release;
~sinpadgroup = nil;
*/

//

~pad = SynthDef(\pad, { | a = 1, fbnmul = 1, freq = 400, gate = 1, kbnmul = 0.4, latmul = 0.02, level = 0.07 |
	var env			= 	Env.asr(10, level, 30);
	var envgen 		= 	EnvGen.kr(env, gate, doneAction: 14);
        // use doneAction 14: free enclosing group.
	var lat 		= 	Latoocarfian2DC.kr(0.01, 10, a: [a, (a - 0.01)], mul: latmul, add: 1).clip(-3, 3);
	var kbn			=	LFBrownNoise0.kr(mul: kbnmul, add: 1);
	var frq 		= 	(freq * lat).clip(100, 3200);
	var saw 		= 	Saw.ar(frq + [-0.001, 0.001], mul: envgen);
	var deci		= 	Decimator.ar(saw, bits: (6 * kbn).clip(3, 24)).clip(-0.5, 0.5);
	var rhpf		= 	RHPF.ar(deci, (12000 * lat).clip(freq, SampleRate.ir/4), mul: 0.5).clip(-0.5, 0.5);
	var fbn			= 	LFBrownNoise0.kr(mul: fbnmul, add: 1).clip(0.1, 0.9);
	var rlpf 		= 	RLPF.ar(saw, (freq * 1.5 * [fbn, fbn]).clip(freq, freq * 4)).clip(-0.5, 0.5);
	var nodc		=	LeakDC.ar(rlpf + rhpf);
	Out.ar(0, nodc).clip(-0.5, 0.5);
}).add;

/*
~padtest1 = Synth(\pad).register;
~padtest1.isPlaying;
~padtest1.release;
*/

~createPadGroup0 = { | freqs = #[200,300] |
	~padgroup0 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup0, \pad, [\freq, i, \kbnmul, 0.1, \latmul, 0, \level, 0.05]);
	});
};

/*
~createPadGroup0.value;
~padgroup0.isPlaying;
~padgroup0.release(3);
~padgroup = nil;
*/

~createPadGroup1 = { | freqs = #[400,600,400,600] |
	~padgroup1 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup1, \pad, [\a, (6.0.rand - 3), \freq, i]);
	});
};

/*
~createPadGroup1.value;
~padgroup1.isPlaying;
~padgroup1.release(3);
*/

~createPadGroup2 = { | freqs = #[400,600,400,600] |
	~padgroup2 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup2, \pad, [\a, (6.0.rand - 3), \freq, i]);
	});
};

/*
~createPadGroup2.value;
~padgroup2.isPlaying;
~padgroup2.release(3);
*/

~createPadGroup3 = { | freqs = #[400,600,400,600] |
	~padgroup3 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup3, \pad, [\a, (6.0.rand - 3), \freq, i]);
	});
};

/*
~createPadGroup3.value;
~padgroup3.isPlaying;
~padgroup3.release(3);
*/

~createPadGroup4 = { | freqs = #[400,600,400,600] |
	~padgroup4 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup4, \pad, [\a, (6.0.rand - 3), \freq, i]);
	});
};

/*
~createPadGroup4.value;
~padgroup4.isPlaying;
~padgroup4.release(3);
*/

~createPadGroup5 = { | freqs = #[400,600] |
	~padgroup5 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup5, \pad, [\a, (6.0.rand - 3), \freq, i]);
	});
};

/*
~createPadGroup5.value;
~padgroup5.isPlaying;
~padgroup5.release(3);
*/

~createGossamer = { | freqs = #[800,1200,1800] |
	~gossamergroup = Group(s).register;
	freqs.do({|i|
		Synth.tail(~gossamergroup, \pad, [\a, (6.0.rand - 3), \freq, i, \kbnmul, 0.25, \latmul, 0, \level, 0.007]);
	});
};

/*
~createGossamer.value;
~gossamergroup.isPlaying;
~gossamergroup.release(3);
~gossamergroup.free;
~gossamergroup = nil;
*/

// PATTERNS ///////////////////////////////////////////////////

~snrpat =
Pdef(\snrpat,
	Pbind(
		\instrument, \snr,
		\a, Pwhite(0.5, 1.0, inf),
		\dur, Pshuf([
			1, 1, 0.75,
			1, 1, 1, 0.75,
			1, 1, 1, 1, 0.75
		], inf),
		\freq, Pwhite(1000, 1200, inf),
		\level, 0.2,
		\note, Pseq([
			Rest, 1,
			Rest, Rest, 1,
			Rest, Rest, Rest, 1
		], inf),
));

/*
~snrpat.play(t, quant: 1);
~snrpat.isPlaying;
~snrpat.stop;
*/

~snrpat2 =
Pdef(\snrpat2,
	Pbindf(
		~snrpat,
		\dur, Pshuf([
			0.75, 0.75, 1,
			0.75, 0.75, 0.75, 1,
			0.75, 0.75, 0.75, 0.75, 1
		], inf),
		\freq, Pwhite(6000, 6400, inf),
		\level, Prand([0.75, 1] * 0.1, inf),
		\note, 1
));

/*
~snrpat2.play(t, quant: 1);
~snrpat2.isPlaying;
~snrpat2.stop;
*/

~snrpar = Pdef(\snrpar, Ppar(Array.fill(2, { ~snrpat2 }), inf));

/*
~snrpar.play(t, quant: 1);
~snrpar.isPlaying;
~snrpar.stop;
*/

//

~kikpat =
Pdef(\kikpat,
	Pbind(
		\instrument, \kik,
		\curve, -512,
		//\dur, Prand([0.25, Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, 1, 2, 3, 4, 6].mirror2, inf),
		\dur, Pwhite(0.25, 6, inf).round(0.25),
		\freq, 200
));

/*
~kikpat.play(t, quant: 1);
~kikpat.isPlaying;
~kikpat.stop;
*/

~prcpat0 =
Pdef(\prcpat0,
	Pbind(
		\instrument, \prc,
		\dur, Pshuf([0.75, 1, 1.5, 2, 3, 4, 6, 8, 12].mirror2, inf),
		\freq, Pwhite(400, 600, inf),
		\level, 0.2,
		\pan, Pshuf([-0.5, -0.25, 0, 0.25, 0.5], inf),
));

/*
~prcpat0.play(t, quant: 1);
~prcpat0.isPlaying;
~prcpat0.stop;
*/

~prcpat1 = Pdef(\prcpat1, Pbindf(~prcpat0, \level, 0.1));

~prcpar = Pdef(\prcpar, Ppar([~prcpat0, ~prcpat1, ~prcpat1, ~prcpat1], inf));

/*
~prcpar.play(t, quant: 1);
~prcpar.isPlaying;
~prcpar.stop;
*/

//

~prc2pat0 =
Pdef(\prc2pat0,
	Pbind(
		\instrument, \prc2,
		\dur, Pshuf([0.25, 0.5, 0.75, 2, 3, 4, 6, 8, 12].mirror2, inf),
		\freq, Pshuf([6/7, 5/9, 7/8, 14/15, 1/1, 15/14, 9/8, 7/6, 8/7, 4/3, 7/5, 3/2].mirror2 * 3200, inf),
		\im, Pwhite(0.001, 3.0, inf),
));

/*
~prc2pat0.play(t, quant: 1);
~prc2pat0.isPlaying;
~prc2pat0.stop;
*/

~prc2pat1 =
Pdef(\prc2pat1, Pbindf(~prc2pat0, \freq, 3200));

/*
~prc2pat1.play(t, quant: 1);
~prc2pat1.isPlaying;
~prc2pat1.stop;
*/

~prc2par =
//Pdef(\prc2par, Ppar([~prc2pat0, ~prc2pat1, ~prc2pat1], inf));
Pdef(\prc2par, Ppar([~prc2pat0, ~prc2pat0, ~prc2pat1], inf));

/*
~prc2par.play(t, quant: 1);
~prc2par.isPlaying;
~prc2par.stop;
*/

//

~prc3pat =
Pdef(\prc3pat,
	Pbind(
		\instrument, \prc3,
		\a, Pwhite(1, 2, inf),
		\b, Pwhite(0.1, 1.9, inf),
		\dur, Prand([0.25, 0.5, 0.75, 1, 1.25, 1.5], inf),
		\freq, Prand([128, 256, 512, 1024, 2048, 4096, 8192, 16384], inf),
		\pan, Prand([-1, -0.5, 0, 0.5, 1], inf),
		\xi, Pwhite(1, 2, inf),
));

/*
~prc3pat.play(t, quant: 1);
~prc3pat.isPlaying;
~prc3pat.stop:
~prcpat3.stop;
*/

//

~hatpat =
Pdef(\hatpat,
	Pbind(
		\instrument, \hat,
		\dur, Pshuf([
			Pseq([0.125], 2),
			Pseq([0.5], 17),
			Pseq([0.75], 17),
			Pseq([1], 17),
			Pseq([1.25], 17),
			Pseq([1.5], 17),
			Pseq([1.75], 17),
		].mirror2, inf),
		\freq, Pwhite(8000, 9000, inf),
		\level, Prand([0.75, 1] * 0.03, inf),
		\pan, Pshuf([-1, 1, -1, 1, -1, 1, -1, 1, -1, 1], inf),
));

/*
~hatpat.play(t, quant: 1.5);
~hatpat.isPlaying;
~hatpat.stop;
*/

~hatpat2 = Pdef(\hatpat2, Pbindf(~hatpat, \freq, Pwhite(12000, 14000, inf)));

/*
~hatpat2 =
Pdef(\hatpat2,
	Pbindf(~hatpat,
		\dur, Pseq([
			Pshuf([0.75, 0.75, 0.75].mirror2, 23),
			Pshuf([0.75, 1.25, 1.25].mirror2, 21),
		], inf),
		\level, Prand([0.75, 1] * 0.03, inf),
		\pan, Prand([-1, 1], inf)
));
*/

/*
~hatpat2.play(t, quant: 1.5);
~hatpat2.isPlaying;
~hatpat2.stop;
*/

~hatpar = Pdef(\hatpar, Ppar([~hatpat, ~hatpat2], inf));

/*
~hatpar.play(t, quant: 1.5);
~hatpar.isPlaying;
~hatpar.stop;
*/

~hatpat3 =
Pdef(\hatpat3,
	Pbind(
		\instrument, \hat,
		\dur, Prand([1.25, 1.75, Pseq([1.25], 3), Pseq([1.75], 3)], inf),
		\freq, 12800 * 1.5,
		\pan, Pshuf([-1, -0.5, 0.5, 1], inf),
));

/*
~hatpat3.play(t, quant: 1.25);
~hatpat3.isPlaying;
~hatpat3.stop;
*/

~hatpar3 =
Pdef(\hatpar3, Ppar([~hatpat3, ~hatpat3], inf));

/*
~hatpar3.play(t, quant: 1);
*/

//

//

~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\a, Pwhite(-3.0, 3.0, inf),
		\dur, Pseq([Pshuf([29, 27, 25, 23], 1), 13] * 2, inf),
		\freq, Pseq([Pshuf([7/6, 9/8, 15/14, 1/1], 1), 7/8] * 50, inf),
		\ka0, Pwhite(0.0, 1.0, inf),
		\ka1, Pwhite(0.0, 1.0, inf),
		\ka2, Pwhite(0.0, 1.0, inf),
		\legato, 0.5,
		\level, 0.03,
));

/*
~basspat.play(t, quant: 1);
~basspat.isPlaying;
~basspat.stop;
*/

~pnopat1 =
Pdef(\pnopat1,
	Pbind(
		\instrument, \pno,
		\a, Pwhite(0.1, 1, inf),
		\dur, Pshuf([8, 12, 16, 24, 32, 48].mirror2, inf),
		\freq, Pshuf([1/1, 15/14, 9/8, 7/6] * 800, inf),
		\latmul, 0.1,
		\level, 0.03,
		\pan, Prand([-0.5, 0, 0.5], inf),
));

/*
~pnopat1.play(t, quant: 1);
~pnopat1.isPlaying;
~pnopat1.stop;
*/

~pnopat2 =
Pdef(\pnopat2,
	Pbind(
		\instrument, \pno,
		\a, Pwhite(0.1, 1, inf),
		\dur, Pshuf([16, 24, 32, 48, 64, 96].mirror2, inf),
		\freq, Pshuf([1/1, 15/14, 9/8, 7/6] * 1600, inf),
		\latmul, 0.1,
		\level, 0.02,
		\pan, Prand([-0.5, 0, 0.5], inf),
));

/*
~pnopat2.play(t, quant: 1);
~pnopat2.isPlaying;
~pnopat2.stop;
*/

//

~spat =
Pdef(\spat,
	Pbind(
		\instrument, \sinpulse,
		\a, Pwhite(-3, 3, inf),
		\dur, Pshuf([0.75, Pseq([
			Pshuf([0.25, 0.25, 1.5, 1.75], 3), 1,
			Pshuf([0.25, 0.25, 1.5, 1.75], 3), 2,
			Pshuf([0.25, 0.25, 1.25, 1.5], 3), 3,
			Pshuf([0.25, 0.25, 1.25, 1.5], 3), 4,
		], 1)], inf),
		\freq, 400,
		\level, 0.02,
		\pan, 0
));

/*
~spat.play(t, quant: 1);
~spat.isPlaying;
~spat.stop;
*/

~spat2 = Pdef(\spat2, Pbindf(~spat, \freq, Pshuf([1/1, 1/1, 1/1, 1/1, 1/1, 15/14, 9/8].mirror2 * 400, inf), \level, 0.015, \pan, Pshuf([-0.5, 0.5], inf)));

/*
~spat2.play(t, quant: 1);
~spat2.isPlaying;
~spat2.stop;
*/

~spar = Pdef(\spar, Ppar(Array.fill(1, { ~spat2 }, inf)));

/*
~spar.play(t, quant: 1);
~spar.isPlaying;
~spar.stop;
*/

//

~gpatdurarray = [32, 48, 64, 96].mirror2.scramble;

~gpat =
Pdef(\gpat,
	Pbind(
		\instrument, \grable,
		\dur, Pseq(~gpatdurarray, inf),
		\a, Pwhite(-3, 3, inf),
		\fb, 0.75,
		\freq, Pshuf([
			7/8,
			1/1, 15/14, 9/8, 7/6, 4/3, 3/2, 7/4,
			2/1, 15/7, 9/4, 7/3
		] * 400, inf),
		\legato, 0.5,
		\level, 0.01,
));

/*
~gpat.play(t, quant: 1);
~gpat.isPlaying;
~gpat.stop;
*/

~gpar = Pdef(\gpar, Ppar(Array.fill(4, { ~gpat }), inf));

/*
~gpar.play(t, quant: 1);
~gpar.isPlaying;
~gpar.stop;
*/

/*
~initpad =
(
~padsynthinit1 = Synth(\pad, [\freq, 200, \latmul, 0]).register;
~padsynthinit2 = Synth(\pad, [\freq, 300, \latmul, 0]).register;
)

(
~padsynthinit1.release;
~padsynthinit2.release;
)

(
~padsynth0 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 400]).register;
~padsynth1 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 600]).register;
~padsynth2 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 400]).register;
~padsynth3 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 600]).register;
)
(
~padsynth4 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 400]).register;
~padsynth5 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 600]).register;
~padsynth6 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 400]).register;
~padsynth7 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 600]).register;
)
(
~padsynth8 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 400]).register;
~padsynth9 = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 600]).register;
~padsyntha = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 400]).register;
~padsynthb = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 600]).register;
)
(
~padsynthc = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 400]).register;
~padsynthd = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 600]).register;
~padsynthe = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 400]).register;
~padsynthf = Synth(\pad, [\a, (0.5.rand + 0.5), \freq, 600]).register;
)

(
~padsynth0.release;
~padsynth1.release;
~padsynth2.release;
~padsynth3.release;
~padsynth4.release;
~padsynth5.release;
~padsynth6.release;
~padsynth7.release;
~padsynth8.release;
~padsynth9.release;
~padsyntha.release;
~padsynthb.release;
~padsynthc.release;
~padsynthd.release;
~padsynthe.release;
~padsynthf.release;
)
*/

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

// MIDI CONTROL ////////////////////////////////////////////////////

~snrktrl = MIDIdef.cc(\snrktrl, {
	if(~snrpat.isPlaying.not) {
		~snrpat.play(t, quant: 1);
		"snr play".postln;
	} {
		~snrpat.stop;
		"snr stop".postln;
	};
}, 48, srcID: ~nanoktrl2);

~snrparktrl = MIDIdef.cc(\snrparktrl, {
	if(~snrpar.isPlaying.not) {
		~snrpar.play(t, quant: 1);
		"snrpar play".postln;
	} {
		~snrpar.stop;
		"snrpar stop".postln;
	};
}, 66, srcID: ~nanoktrl2);

~kikktrl = MIDIdef.cc(\kikktrl, {
	if(~kikpat.isPlaying.not) {
		~kikpat.play(t, quant: 1);
		"kik play".postln;
	} {
		~kikpat.stop;
		"kik stop".postln;
	};
}, 32, srcID: ~nanoktrl2);

~hatktrl = MIDIdef.cc(\hatktrl, {
	if(~hatpat.isPlaying.not) {
		~hatpat.play(t, quant: 1);
		"hat play".postln;
	} {
		~hatpat.stop;
		"hat stop".postln;
	};
}, 64, srcID: ~nanoktrl2);

~hat2ktrl = MIDIdef.cc(\hat2ktrl, {
	if(~hatpat2.isPlaying.not) {
		~hatpat2.play(t, quant: 1);
		"hat2 play".postln;
	} {
		~hatpat2.stop;
		"hat2 stop".postln;
	};
}, 33, srcID: ~nanoktrl2);

~hat3ktrl = MIDIdef.cc(\hat3ktrl, {
	if(~hatpar3.isPlaying.not) {
		~hatpar3.play(t, quant: 1);
		"hatpar3 play".postln;
	} {
		~hatpar3.stop;
		"hatpar3 stop".postln;
	};
}, 49, srcID: ~nanoktrl2);

~prcktrl = MIDIdef.cc(\prcktrl, {
	if(~prcpat0.isPlaying.not) {
		~prcpat0.play(t, quant: 1);
		"prc play".postln;
	} {
		~prcpat0.stop;
		"prc stop".postln;
	};
}, 34, srcID: ~nanoktrl2);

~prc2ktrl = MIDIdef.cc(\prc2ktrl, {
	if(~prc2par.isPlaying.not) {
		~prc2par.play(t, quant: 1);
		"prc2par play".postln;
	} {
		~prc2par.stop;
		"prc2par stop".postln;
	};
}, 50, srcID: ~nanoktrl2);

~prc3ktrl = MIDIdef.cc(\prc3ktrl, {
	if(~prc3pat.isPlaying.not) {
		~prc3pat.play(t, quant: 1);
		"prc3 play".postln;
	} {
		~prc3pat.stop;
		"prc3 stop".postln;
	};
}, 65, srcID: ~nanoktrl2);

~bassktrl = MIDIdef.cc(\bassktrl, {
	if(~basspat.isPlaying.not) {
		~basspat.play(t, quant: 1);
		"bass play".postln;
	} {
		~basspat.stop;
		"bass stop".postln;
	};
}, 35, srcID: ~nanoktrl2);

~pno1ktrl = MIDIdef.cc(\pno1ktrl, {
	if(~pnopat1.isPlaying.not) {
		~pnopat1.play(t, quant: 1);
		"pno1 play".postln;
	} {
		~pnopat1.stop;
		"pno1 stop".postln;
	};
}, 51, srcID: ~nanoktrl2);

~pno2ktrl = MIDIdef.cc(\pno2ktrl, {
	if(~pnopat2.isPlaying.not) {
		~pnopat2.play(t, quant: 1);
		"pno2 play".postln;
	} {
		~pnopat2.stop;
		"pno2 stop".postln;
	};
}, 67, srcID: ~nanoktrl2);

~pulsektrl = MIDIdef.cc(\pulsektrl, {
	if(~spat.isPlaying.not) {
		~spat.play(t, quant: 1);
		"pulse play".postln;
	} {
		~spat.stop;
		"pulse stop".postln;
	};
}, 36, srcID: ~nanoktrl2);

~pulseparktrl = MIDIdef.cc(\pulseparktrl, {
	if(~spat2.isPlaying.not) {
		~spat2.play(t, quant: 1);
		"pulse2 play".postln;
	} {
		~spat2.stop;
		"pulse2 stop".postln;
	};
}, 52, srcID: ~nanoktrl2);

~grablektrl = MIDIdef.cc(\grablektrl, {
	if(~gpar.isPlaying.not) {
		~gpar.play(t, quant: 1);
		"grable play".postln;
	} {
		~gpar.stop;
		"grable stop".postln;
	};
}, 68, srcID: ~nanoktrl2);

~sinpadmdef = MIDIdef.cc(\sinpadmdef, {
	if(~sinpadgroup.isNil) {
		~createsinpadGroup.value;
		"sinpad play".postln;
	} {
		~sinpadgroup.release;
		~sinpadgroup = nil;
		"sinpad stop".postln;
	}
}, 55, srcID: ~nanoktrl2);

~pad0mdef = MIDIdef.cc(\pad0mdef, {
	if(~padgroup0.isNil) {
		~createPadGroup0.value;
		"pad0 play".postln;
	} {
		~padgroup0.release;
		~padgroup0 = nil;
		"pad0 stop".postln;
	}
}, 37, srcID: ~nanoktrl2);

~pad1mdef = MIDIdef.cc(\pad1mdef, {
        if (~padgroup1.isNil) {
			~createPadGroup1.value;
                "pad1 play".postln;
        } {
			~padgroup1.release;
			~padgroup1 = nil;
			"pad1 stop".postln;
        }
}, 53, srcID: 1310720);

~pad2mdef = MIDIdef.cc(\pad2mdef, {
        if (~padgroup2.isNil) {
			~createPadGroup2.value;
                "pad2 play".postln;
        } {
			~padgroup2.release;
			~padgroup2 = nil;
			"pad2 stop".postln;
        }
}, 69, srcID: 1310720);

~pad3mdef = MIDIdef.cc(\pad3mdef, {
        if (~padgroup3.isNil) {
			~createPadGroup3.value;
            "pad3 play".postln;
        } {
			~padgroup3.release;
			~padgroup3 = nil;
			"pad3 stop".postln;
        }
}, 38, srcID: 1310720);

~pad4mdef = MIDIdef.cc(\pad4mdef, {
        if (~padgroup4.isNil) {
			~createPadGroup4.value;
            "pad4 play".postln;
        } {
			~padgroup4.release;
			~padgroup4 = nil;
			"pad4 stop".postln;
        }
}, 54, srcID: 1310720);

~pad5mdef = MIDIdef.cc(\pad5mdef, {
        if (~padgroup5.isNil) {
			~createPadGroup5.value;
            "pad5 play".postln;
        } {
			~padgroup5.release;
			~padgroup5 = nil;
			"pad5 stop".postln;
        }
}, 70, srcID: 1310720);

~gossmdef = MIDIdef.cc(\gossmdef, {
        if (~gossamergroup.isNil) {
			~createGossamer.value;
            "gossamer play".postln;
        } {
			~gossamergroup.free;
			~gossamergroup = nil;
			"gossamer stop".postln;
        }
}, 39, srcID: 1310720);

~verbmdef = MIDIdef.cc(\verbmdef, {
        if (~reverb.isPlaying.not) {
			~reverb = Synth(\verb).register;
       		"snr reverb on".postln;
        } {
			~reverb.free;
			"snr reverb off".postln;
        }
}, 71, srcID: 1310720);