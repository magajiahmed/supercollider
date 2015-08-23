// INIT //////////////////////////////////////////////////////////

//midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl2 = 1310720;

//other stuff
/*
s.meter;
~clock = ClockFace.new;
~clock.play;
~clock.stop;
*/

t = TempoClock(135/60);

//record
/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

// SYNTHDEFS /////////////////////////////////////////////////////

(
~dynamix =
SynthDef(\dynamix, {
	var in	   		= 	In.ar(2, 2);
	var compressor	=	Compander.ar(in, in, thresh: 0.25, slopeAbove: 1/128, clampTime: 0.002);
	Out.ar(0, compressor);
}).add;
);

(
~startcompressor = {
	s.sync;
	~compressor = Synth(\dynamix).register;
}.fork;
);

/*
~compressor.isPlaying;
~compressor.free;
*/

//

(
~verb =
SynthDef(\verb, { | kbn2frq = 20 |
	var in			=	In.ar(4, 2);
	var kbn1		=	LFBrownNoise0.kr(add: 0.1);
	var kbn2		=	LFBrownNoise0.kr(kbn2frq, add: 0.4);
	var verb		=	GVerb.ar(in, revtime: (80 * kbn2).clip(1, 200), damping: kbn1.clip(0, 1), mul: 0.03);
	Out.ar(2, verb);
}).add;
);

~startreverb = {
	s.sync;
	~reverb = Synth(\verb).register;
}.fork;

/*
~reverb = Synth(\verb).register;
~reverb.isPlaying;
~reverb.free;
*/

//

(
~cusp =
SynthDef(\cusp, { | a = 1, b = 1.9, curve = -64, dur = 1, freq = 22050, level = 0.05, pan = 0, xi = 0 |
	var env			=	Env.perc(releaseTime: 1, level: level, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var cusp		=	CuspN.ar(freq: freq, a: a, b: b, xi: xi, mul: envgen);
	var rlpf		=	RLPF.ar(cusp, 200, 0.2);
	var rhpf		=	RHPF.ar(cusp, 3200, 0.1);
	var pan2		=	Pan2.ar((cusp) + (rlpf) + (rhpf), pan);
	Out.ar([2, 4], pan2);
}).add;
);

//

~snr =
SynthDef(\snr, { | a = 1, curve = -4, freq = 500, level = 0.5, pan = 0 |
	var env 		=	Env.perc(attackTime: 0.008, releaseTime: 0.05, level: level, curve: curve);
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

(
~kik =
SynthDef(\kik, { | curve = 0, dur = 0.25, freq = 2000, level = 0.25, pan = 0 |
	var env 		=	Env.perc(attackTime: 0.008, level: level, releaseTime: 1, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var bnl			=	LFBrownNoise0.ar(freq, mul: envgen);
	var bnr			=	LFBrownNoise0.ar(freq, mul: envgen);
	var comp		= 	Compander.ar([bnl, bnr], [bnl, bnr], thresh: 0.3, slopeAbove: 1/8, clampTime: 0.005);
	var rlpf		=	RLPF.ar(comp, freq * 2, 0.05);
	//Out.ar(2, rlpf).clip(-1, 1);
	Out.ar(2, rlpf);
}).add;
);

//

(
~hat =
SynthDef(\hat, { | freq = 6400, level = 0.05, pan = 0 |
	var	env			=	Env.perc(attackTime: 0.008, releaseTime: 0.01, level: level, curve: -512);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	//var penv		=	Env.new([1, 0.5], [0.1]);
	//var penvgen		=	EnvGen.kr(penv);
	var penvgen		=	LFNoise0.ar(500, 1, 1);
	var bn			=	LFBrownNoise0.ar(mul: 0.05, add: 1);
	var sin			=	SinOsc.ar((freq * penvgen * bn).clip(50, SampleRate.ir / 4), pi, mul: envgen);
	var pan2		=	Pan2.ar(sin, pan);
	Out.ar(2, pan2).clip(-1, 1);
}).add;
);

//

(
~prc =
SynthDef(\prc, { | curve = -128, freq = 1600, bwr = 0.1, level = 0.1, pan = 0 |
	var env			=	Env.perc(releaseTime: 0.25, level: level, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var bn			=	Crackle.ar(1.995, envgen);
	var rlpf		=	RLPF.ar(bn, freq, bwr);
	var pan2		=	Pan2.ar(bn + rlpf, pan);
	Out.ar(2, pan2).clip(-0.5, 0.5);
}).add;
);

(
~prc2 =
SynthDef(\prc2, { | curve = -16, dur = 1, freq = 6400, im = 1, level = 0.03, pan = 0 |
	var env			=	Env.perc(attackTime: 0.008, releaseTime: dur, level: level, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var noiz1		=	FBSineC.ar(freq, im: im, mul: envgen);
	var noiz2		=	FBSineC.ar(freq * 31, im: im, mul: envgen / 7);
	var pan2		=	Pan2.ar(noiz1 + noiz2, pan);
	Out.ar(2, pan2).clip(-0.5, 0.5);
}).add;
);

//

(
~prc3 =
SynthDef(\prc3, { | a = 1, b = 1.9, curve = -64, dur = 1, freq = 22050, klnkfreq = 400, level = 0.1, pan = 0, xi = 0  |
	var env			=	Env.perc(attackTime: 0.02, releaseTime: dur, level: level, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var cusp		=	CuspL.ar(freq, a, b, xi, envgen);
	var klnklayers	=	31;
	var klnkfrqs	=	Array.fill(klnklayers, { arg i; ((i * (i / 100)) * klnkfreq) });
	var klnkamps	=	Array.fill(klnklayers, { 0.004 });
	var klnkrts		=	Array.fill(klnklayers, { 0.05 });
	var klank		=	Klank.ar(`[klnkfrqs, klnkamps, klnkrts], cusp);
	var pan2		=	Pan2.ar((cusp / 4) + klank, pan);
	Out.ar(2, pan2);
}).add;
);

/*
~prctest = Synth(\prc);
*/

//

(
~bass =
SynthDef(\bass, { | a = 1, freq = 440, gate = 1, level = 0.05, ka = 0, ka1 = 1, ka2 = 1, klatmul = 0.005 |
	var env			=	Env.asr(attackTime: 0.01, sustainLevel: level, releaseTime: 0.1, curve: -64);
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
);

//

(
~pno =
SynthDef(\pno, { | a = 1, curve = -8, dur = 1, freq = 440, latmul = 0.05, level = 0.25, pan = 0 |
	var env			=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var klat		=	Latoocarfian2DC.kr(a: a, mul: latmul, add: 1).clip(0.95, 1.05);
	var klat2		=	Latoocarfian2DC.kr(a: a + 0.01, mul: latmul, add: 1).clip(0.95, 1.05);
	var klat3		=	Latoocarfian2DC.ar(a: a - 0.01, mul: 1, add: 1).clip(0.95, 1.05);
	var sin1		=	SinOsc.ar(freq, mul: envgen);
	var sin1kl		=	SinOsc.ar(freq * klat, mul: envgen);
	var sin2		=	SinOsc.ar((freq * 2.01), mul: envgen / 64);
	var sin2kl		=	SinOsc.ar(freq * klat2 * 2.01, mul: envgen / 64);
	var sin20		=	SinOsc.ar((freq * 10.01 * klat3).clip(50, SampleRate.ir / 4), mul: envgen / 4);
	var sinmix		=	sin1 + sin1kl + sin2 + sin2kl + sin20;
	var pan2 		=	Pan2.ar(sinmix, pan);
	Out.ar(0, pan2).clip(-0.99, 0.99);
}).add;
);

//

(
~drone =
SynthDef(\drone, { | a = 1, dur = 1, freq = 200, gate = 1, level = 0.002, pan = 0 |
	//var env			=	Env.perc(attackTime: 0.005, releaseTime: dur, level: level, curve: 0);
	var env			=	Env.asr(attackTime: 5, sustainLevel: level, releaseTime: 10);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 14);
	var freqs		= 	[freq, freq - 1];
	var kbnfrq0		=	LFBrownNoise0.kr(freq).range(0.999, 1.001);
	var kbnfrq1		=	LFBrownNoise0.kr(freq).range(0.999, 1.001);
	var kbnfrq2		=	LFBrownNoise0.kr(freq).range(0.999, 1.001);
	var kbnfrq3		=	LFBrownNoise0.kr(freq).range(0.999, 1.001);
	var kbnmul		=	LFBrownNoise0.kr(40).range(0.25, 1).round(0.25);
	var sin0		=	SinOsc.ar(freqs * kbnfrq0, mul: envgen * kbnmul);
	var sin1		=	SinOsc.ar(freqs * kbnfrq1 * 2, mul: (envgen) * kbnmul);
	//var sin2		=	SinOsc.ar(freqs * kbnfrq2 * 4, mul: (envgen) * kbnmul);
	var sin3		=	SinOsc.ar(freqs * kbnfrq3 * 32, mul: (envgen / 8) * kbnmul);
	var klat0		=	Latoocarfian2DC.ar(freq / 2, freq, a: a).range(0.25, 4);
	var klat1		=	Latoocarfian2DC.ar(freq / 2, freq, a: a).range(0.25, 4);
	var sin4		=	SinOsc.ar((freqs * klat0 * 11).clip(50, SampleRate.ir / 4), mul: (envgen / 8) * kbnmul);
	var sin5		=	SinOsc.ar((freqs * klat1 * 13).clip(50, SampleRate.ir / 4), mul: (envgen / 8) * kbnmul);
	//var pan2		=	Pan2.ar(sin0 + sin1 + sin2 + sin3 + sin4 + sin5, pan);
	//var pan2		=	Pan2.ar(sin0 + sin1 + sin2, pan);
	Out.ar(0, sin0 + sin1 + sin3 + sin4 + sin5).clip(-0.9, 0.9);
}).add;
);

(
~createDroneGroup = { | freqs = #[200, 300] |
	~droneGroup = Group(s).register;
	freqs.do({|i|
		Synth.tail(~droneGroup, \drone, [\a, (6.0.rand - 2), \freq, i]);
	});
};
);

/*
~createDroneGroup.value;
~droneGroup.isPlaying;
~droneGroup.release;
~droneGroup1 = nil;
*/

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
	var env			=	Env.asr(attackTime: 5, sustainLevel: level, releaseTime: 15);
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

(
~pad = SynthDef(\pad, { | a = 1, fbnmul = 1, freq = 400, gate = 1, kbnmul = 0.4, latmul = 0.02, level = 0.05 |
	var env			= 	Env.asr(20, level, 20);
	var envgen 		= 	EnvGen.kr(env, gate, doneAction: 14);
        // use doneAction 14: free enclosing group.
	var lat 		= 	Latoocarfian2DC.kr(0.01, 5, a: [a, (a - 0.01)], mul: latmul, add: 1).clip(0.5, 16);
	var kbn1		=	LFBrownNoise0.kr.range(0.67, 1.5);
	var kbn2		=	LFBrownNoise0.kr.range(0.8, 1.25);
	var frq 		= 	(freq * lat).clip(100, 3200);
	var saw 		= 	Saw.ar(frq + [-0.001, 0.001], mul: envgen).clip(-0.5, 0.5);
	var deci		= 	Decimator.ar(saw, bits: (6 * kbn1)).clip(-0.5, 0.5);
	var rhpf		= 	RHPF.ar(deci, (11000 * kbn2).clip(50, SampleRate.ir / 3), 0.25, mul: 0.5).clip(-0.5, 0.5);
	var rlpf 		= 	RLPF.ar(saw, freq * 1.5);
	Out.ar(0, rlpf + rhpf).clip(-0.5, 0.5);
}).add;
);

(
~createPadGroup0 = { | freqs = #[200,300,200,300,200,300] |
	~padgroup0 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup0, \pad, [\a, 1, \bus, 2, \freq, i, \kbnmul, 0.05, \latmul, 0, \level, 0.02]);
	});
};
);

/*
~createPadGroup0.value;
~padgroup0.isPlaying;
~padgroup0.release(3);
~padgroup = nil;
*/

(
~createPadGroup1 = { | freqs = #[400,600,400,600,400,600] |
	~padgroup1 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup1, \pad, [\a, (4.0.rand - 2), \freq, i]);
	});
};
);

/*
~createPadGroup1.value;
~padgroup1.isPlaying;
~padgroup1.release(3);
~padgroup1 = nil;
*/

(
~createPadGroup2 = { | freqs = #[400,600,400,600,400,600] |
	~padgroup2 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup2, \pad, [\a, (4.0.rand - 2), \freq, i]);
	});
};
);

/*
~createPadGroup2.value;
~padgroup2.isPlaying;
~padgroup2.release(3);
~padgroup2 = nil;
*/

(
~createPadGroup3 = { | freqs = #[400,600,400,600,400,600] |
	~padgroup3 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup3, \pad, [\a, (4.0.rand - 2), \freq, i]);
	});
};
);

/*
~createPadGroup3.value;
~padgroup3.isPlaying;
~padgroup3.release(3);
~padgroup3 = nil;
*/

(
~createPadGroup4 = { | freqs = #[400,600,400,600,400,600] |
	~padgroup4 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup4, \pad, [\a, (4.0.rand - 2), \freq, i]);
	});
};
);

/*
~createPadGroup4.value;
~padgroup4.isPlaying;
~padgroup4.release(3);
~padgroup4 = nil;
*/

(
~createPadGroup5 = { | freqs = #[400,600,400,600] |
	~padgroup5 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup5, \pad, [\a, (4.0.rand - 2), \freq, i]);
	});
};
);

/*
~createPadGroup5.value;
~padgroup5.isPlaying;
~padgroup5.release(3);
*/

(
~createGossamer = { | freqs = #[800,1200,1800] |
	~gossamergroup = Group(s).register;
	freqs.do({|i|
		Synth.tail(~gossamergroup, \pad, [\freq, i, \kbnmul, 0.25, \latmul, 0, \level, 0.007]);
	});
};
);

/*
~createGossamer.value;
~gossamergroup.isPlaying;
~gossamergroup.release(3);
~gossamergroup.free;
~gossamergroup = nil;
*/

// PATTERNS ///////////////////////////////////////////////////

(
~cuspat =
Pdef(\cuspat,
	Pbind(
		\instrument, \cusp,
		\dur, Pshuf([
			Pseq([0.125], 2),
			0.25, 0.25, 0.25, 0.25, 0.25,
			0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5,
			0.75,
			Pseq([1/3], 3),
			1, 1, 1, 1, 1, 1, 1,
			1.5, 1.5, 1.5, 1.5,
			2,
			3,
			4,
			6,
			8,
			12,
			16,
			24
		].mirror2, inf),
		\a, Pwhite(0.2, 1, inf),
		\b, Pwhite(1.5, 1.9, inf),
		\freq, Pwhite(2800, 3200, inf),
		\level, 0.05,
		\pan, Prand([-0.5, 0, 0.5], inf),
));
);

/*
~cuspat.play(t, quant: 1);
~cuspat.stop;
*/

//

(
~cuspat2 =
Pdef(\cuspat2,
	Pbind(
		\instrument, \cusp,
		\a, 0.8,
		\b, 1.9,
		\curve, -64,
		\note, Pseq([Rest, 1, Rest, Rest, 1, Rest, Rest, Rest, 1], inf),
));
);

/*
~cuspat2.play(t, quant: 1);
~cuspat2.isPlaying;
~cuspat2.stop;
*/


//

/*
(
~snrpat =
Pdef(\snrpat,
	Pbind(
		\instrument, \snr,
		\a, Pwhite(0.5, 1.0, inf),
/*
		\dur, Pshuf([
			1, 1, 0.75,
			1, 1, 1, 0.75,
			1, 1, 1, 1, 0.75
		], inf),
*/
		\dur, 1,
		\freq, Pwhite(1500, 1700, inf),
		\level, 0.08,
		\note, Pseq([
			Rest, 1,
			Rest, Rest, 1,
			Rest, Rest, Rest, 1
		], inf),
));
);

/*
~snrpat.play(t, quant: 1);
~snrpat.isPlaying;
~snrpat.stop;
*/

(
~snrpat2 =
Pdef(\snrpat2,
	Pbindf(
		~snrpat,
		\curve, -64,
		\dur, Pshuf([
			0.75, 0.75, 1,
			0.75, 0.75, 0.75, 1,
			0.75, 0.75, 0.75, 0.75, 1
		], inf),
		\freq, Pwhite(14000, 15000, inf),
		\level, Prand([0.75, 1] * 0.05, inf),
));
);

/*
~snrpat2.play(t, quant: 1);
~snrpat2.isPlaying;
~snrpat2.stop;
*/

~snrpar = Pdef(\snrpar, Ppar(Array.fill(3, { ~snrpat2 }), inf));

/*
~snrpar.play(t, quant: 1);
~snrpar.isPlaying;
~snrpar.stop;
*/

*/

//

(
~kikpatdurarray = Array.fill(11, { arg i; (0.75 * (i + 1)) }).mirror2;
~kikpat =
Pdef(\kikpat,
	Pbind(
		\instrument, \kik,
		\curve, -32,
		\dur, Pshuf(~kikpatdurarray.mirror2, inf),
		\freq, Pseq([1/1, 1/1, 15/14, 1/1, 1/1, 1/1, 15/14, 1/1, 1/1, 1/1, 1/1, 15/14] * 50, inf),
		\level, 0.2,
));
);

/*
~kikpat.play(t, quant: 1);
~kikpat.isPlaying;
~kikpat.stop;
*/

(
~prcpat0 =
Pdef(\prcpat0,
	Pbind(
		\instrument, \prc,
		\dur, Pwrand([Pseq([0.125], 2), 0.25, 0.5, 0.75], [1, 8, 8, 8].normalizeSum, inf),
		\freq, Pseq([1/1, 1/1, 15/14, 1/1, 1/1, 1/1, 15/14, 1/1, 1/1, 1/1, 1/1, 15/14] * 3200, inf),
		\bwr, 0.02,
		\level, 0.003,
		\pan, Pshuf([-0.5, -0.25, 0, 0.25, 0.5], inf),
));
);

/*
~prcpat0.play(t, quant: 1);
~prcpat0.isPlaying;
~prcpat0.stop;
*/

~prcpat1 = Pdef(\prcpat1, Pbindf(~prcpat0, \level, 0.001));

~prcpar = Pdef(\prcpar, Ppar([~prcpat0, ~prcpat1, ~prcpat1, ~prcpat1], inf));

/*
~prcpar.play(t, quant: 1);
~prcpar.isPlaying;
~prcpar.stop;
*/

//

(
~prc2pat0 =
Pdef(\prc2pat0,
	Pbind(
		\instrument, \prc2,
		\curve, -2,
		\dur, 0.25,
		\freq, 1600,
		\im, Pshuf([
			1, 2, 3,
			1, 1, 2, 3,
			1, 1, 1, 2, 3,
			1, 1, 1, 1, 2, 3,
			1, 1, 1, 1, 1, 2, 3
		].mirror2, inf),
		\level, 0.005,
		\pan, Pshuf([-1, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 1].mirror2, inf),
));
);

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

(
~prc2par =
//Pdef(\prc2par, Ppar([~prc2pat0, ~prc2pat1, ~prc2pat1], inf));
//Pdef(\prc2par, Ppar([~prc2pat0, ~prc2pat0, ~prc2pat1], inf));
Pdef(\prc2par, Ppar(Array.fill(1, { ~prc2pat0 }), inf));
);

/*
~prc2par.play(t, quant: 1);
~prc2par.isPlaying;
~prc2par.stop;
*/

//

(
~prc3pat =
Pdef(\prc3pat,
	Pbind(
		\instrument, \prc3,
		\a, Pshuf(Array.fill(9, { arg i; ((2 * i) / 10) }), inf),
		\b, Pshuf(Array.fill(7, { arg i; (3 * i) / 9 }), inf),
		\dur, Prand([0.25, 0.5, 0.75, 1, 1.25, 1.5], inf),
		\freq, Prand(Array.fill(5, { arg i; (i + 1) * 3200 }), inf),
		\klnkfreq, Pseq([1/1, 1/1, 7/8, 1/1, 1/1, 1/1, 7/8, 1/1, 1/1, 1/1, 1/1, 7/8] * 400, inf),
		\level, 0.06,
		\pan, Prand([-1, -0.5, 0, 0.5, 1], inf),
		\xi, Pwhite(1, 2, inf),
));
);

/*
~prc3pat.play(t, quant: 1);
~prc3pat.isPlaying;
~prc3pat.stop:
~prcpat3.stop;
*/

//

(
~hatpat =
Pdef(\hatpat,
	Pbind(
		\instrument, \hat,
		\dur, Pshuf([
			Pseq([0.125], 2),
			Pseq([1.25], 17),
			Pseq([1.5], 17),
			Pseq([1.75], 17),
		].mirror2, inf),
		\freq, Pwhite(8000, 8000, inf),
		\level, Prand([0.75, 1] * 0.03, inf),
		\pan, Pshuf([-1, 1, -1, 1, -1, 1, -1, 1, -1, 1], inf),
));
);

/*
~hatpat.play(t, quant: 1.5);
~hatpat.isPlaying;
~hatpat.stop;
*/

(
~hatpat2 = Pdef(\hatpat2,
	Pbindf(~hatpat,
		\dur, Pseq([
			Pseq([0.125, 0.125, (1.25)], 1), Pseq([1.5], 3),
			Pseq([0.125, 0.125, (1.25)], 1), Pseq([1.5], 5),
			Pseq([0.125, 0.125, (1.25)], 1), Pseq([1.5], 7),
			Pseq([0.125, 0.125, (0.5)], 1), Pseq([0.75], 3),
			Pseq([0.125, 0.125, (0.5)], 1), Pseq([0.75], 5),
			Pseq([0.125, 0.125, (0.5)], 1), Pseq([0.75], 7),
		], inf),
		\freq, Pwhite(10000, 10000, inf),
		\pan, 0,
))
);

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

(
~hatpat3 =
Pdef(\hatpat3,
	Pbind(
		\instrument, \hat,
		\dur, Prand([1.25, 1.75, Pseq([1.25], 3), Pseq([1.75], 3)], inf),
		\freq, 12800 * 1.5,
		\level, 0.03,
		\pan, Pshuf([-1, -0.5, 0.5, 1], inf),
));
);

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

(
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
		\level, 0.02,
));
);

/*
~basspat.play(t, quant: 1);
~basspat.isPlaying;
~basspat.stop;
*/

(
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
);

/*
~pnopat1.play(t, quant: 1);
~pnopat1.isPlaying;
~pnopat1.stop;
*/

(
~pnopat2 =
Pdef(\pnopat2,
	Pbind(
		\instrument, \pno,
		\a, Pwhite(0.1, 1, inf),
		\dur, Pshuf([8, 12, 16, 24, 32, 48].mirror2, inf),
		\freq, Pshuf([1/1, 15/14, 9/8, 7/6] * 1600, inf),
		\latmul, 0.1,
		\level, 0.02,
		\pan, Prand([-0.5, 0, 0.5], inf),
));
);

/*
~pnopat2.play(t, quant: 1);
~pnopat2.isPlaying;
~pnopat2.stop;
*/

//

(
~pnopat3a =
Pdef(\pnopat3a,
	Pbind(
		\instrument, \pno,
		\a, Pwhite(-0.1, 0.1, inf),
		\curve, 4,
		\dur, Pseq([
			0.25, 0.5,
			0.25, 0.25, 0.5,
			0.25, 0.25, 0.25, 0.5
		], inf),
		\freq, Pseq([
			1/1, 3/2, 1/1, 3/2, 1/1, 3/2, 7/8, 1/1, 3/2,
			1/1, 3/2, 1/1, 3/2, 1/1, 3/2, 1/1, 3/2, 7/8, 1/1, 3/2,
			1/1, 3/2, 1/1, 3/2, 1/1, 3/2, 1/1, 3/2, 1/1, 3/2, 7/8, 1/1, 3/2
		] * 800, inf),
		\latmul, 0.05,
		\level, 0.006,
		\pan, -1,
));
);

/*
~pnopat3a.play(t, quant: 1);
~pnopat3a.isPlaying;
~pnopat3a.stop;
*/

(
~pnopat3b =
Pdef(\pnopat3b,
	Pbindf(~pnopat3a,
		\dur, Pseq([
			0.5, 0.25,
			0.5, 0.25, 0.25,
			0.5, 0.25, 0.25, 0.25, 0.25
		], inf),
		\pan, 1
));
);

/*
~pnopat3b.play(t, quant: 1);
~pnopat3b.stop;
*/

(
~pnopar3 =
Pdef(\pnopar3, Ppar([~pnopat3a, ~pnopat3b], inf));
);

/*
~pnopar3.play(t, quant: 1);
~pnopar3.stop;
*/

(
~pnopat4a =
Pdef(\pnopat4,
	Pbind(
		\instrument, \pno,
		\dur, Pshuf([0.75, 8, 12, 16, 24], inf),
		\freq, Pxrand([1/1, 15/14, 9/8, 7/6] * 400, inf),
		\level, 0.01,
		\pan, -1,
));
);

/*
~pnopat4a.play(t, quant: 1);
~pnopat4a.stop;
*/

(
~pnopat4b =
Pdef(\pnopat4b,
	Pbindf(
		~pnopat4a,
		\pan, 1
))
);

/*
~pnopat4b.play(t, quant: 1);
~pnopat4b.stop;
*/

~pnopar4 = Pdef(\pnopar4, Ppar([~pnopat4a, ~pnopat4b], inf));

/*
~pnopar4.play(t, quant: 1);
~pnopar4.isPlaying;
~pnopar4.stop;
*/

//

(
~spat =
Pdef(\spat,
	Pbind(
		\instrument, \sinpulse,
		\a, Pwhite(-3, 3, inf),
		\dur, 13,
		\freq, 400,
		\level, 0.015,
));
);

/*
~spat.play(t, quant: 1);
~spat.isPlaying;
~spat.stop;
*/

/*
~spat2 = Pdef(\spat2, Pbindf(~spat, \freq, Pshuf([1/1, 1/1, 1/1, 1/1, 1/1, 15/14, 9/8].mirror2 * 400, inf), \level, 0.015, \pan, Pshuf([-0.5, 0.5], inf)));
*/

/*
~spat2.play(t, quant: 1);
~spat2.isPlaying;
~spat2.stop;
*/

/*
~spar = Pdef(\spar, Ppar(Array.fill(1, { ~spat2 }, inf)));
*/

~spat2 = Pdef(\spat2, Pbindf(~spat, \freq, (3/2) * 400));

~spar = Pdef(\spar, Ppar(Array.fill(1, { ~spat2 }, inf)));

/*
~spar.play(t, quant: 1);
~spar.isPlaying;
~spar.stop;
*/

//

(
~gpatdurarray = ([32, 48, 64, 96]).mirror2.scramble;

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
			2/1
		] * 400, inf),
		\legato, 0.5,
		\level, 0.015,
));
);

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

(
~gpat2tuning = Tuning.new([1/1, 15/14, 9/8, 7/6, 4/3, 3/2, 7/4].ratiomidi);
~gpat2scale = Scale.new(#[0, 1, 2, 3, 4, 5, 6], 7, ~gpat2tuning);
~gpatchordletarray = [
	[-1, 1], [-1, 2], [-1, 3], [-1, 4],
	[1, 3], [1, 4], [1, 6],
	[2, 4], [2, 6],
	[3, 6],
	[4, 6],
];
~gpatchords = ~gpatchordletarray.deepCollect(1, { arg i; i ++ [0, 5] });

~gpat2 =
Pdef(\gpat2,
	Pbind(
		\instrument, \grable,
		\a, Pwhite(-3, 3, inf),
		\dur, Pshuf([32, 48, 64, 96], inf),
		\fb, 0.85,
		\legato, 0.5,
		\level, 0.015,
		\scale, ~gpat2scale,
		\degree, Pshuf(~gpatchords, inf),
		\dur, Pseq(~gpatdurarray, inf),
		\root, (400/60.midicps).ratiomidi;
));
);

/*
~gpat2.play(t, quant: 1);
~gpat2.isPlaying;
~gpat2.stop;
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

~cuspktrl = MIDIdef.cc(\cuspktrl, {
	if(~cuspat.isPlaying.not) {
		~cuspat.play(t, quant: 1);
		"cusp play".postln;
	} {
		~cuspat.stop;
		"cusp stop".postln;
	};
}, 48, srcID: ~nanoktrl2);

~cusp2ktrl = MIDIdef.cc(\snr2ktrl, {
	if(~cuspat2.isPlaying.not) {
		~cuspat2.play(t, quant: 1);
		"cusp2 play".postln;
	} {
		~cuspat2.stop;
		"cusp2 stop".postln;
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
	if(~prcpar.isPlaying.not) {
		~prcpar.play(t, quant: 1);
		"prc play".postln;
	} {
		~prcpar.stop;
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

(
~pno3ktrl = MIDIdef.cc(\pno3ktrl, {
	if(~pnopar3.isPlaying.not) {
		~pnopar3.play(t, quant: 1);
		"pno3 play".postln;
	} {
		~pnopar3.stop;
		"pno3 stop".postln;
	};
}, 68, srcID: ~nanoktrl2);
);

(
~pno4ktrl = MIDIdef.cc(\pno4ktrl, {
	if(~pnopar4.isPlaying.not) {
		~pnopar4.play(t, quant: 1);
		"pno4 play".postln;
	} {
		~pnopar4.stop;
		"pno4 stop".postln;
	};
}, 41, srcID: ~nanoktrl2);
);

(
~dronektrl = MIDIdef.cc(\sparktrl, {
	if(~droneGroup.isNil) {
		~createDroneGroup.value;
		"drone play".postln;
	} {
		~droneGroup.release;
		~droneGroup = nil;
		"drone stop".postln;
	};
}, 36, srcID: ~nanoktrl2);
);

(
~grablektrl = MIDIdef.cc(\grablektrl, {
	if(~gpar.isPlaying.not) {
		~gpar.play(t, quant: 1);
		"grable play".postln;
	} {
		~gpar.stop;
		"grable stop".postln;
	};
}, 52, srcID: ~nanoktrl2);
);

(
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
);

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