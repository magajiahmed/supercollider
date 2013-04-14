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
s.scope;
*/
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
	var kbn2		=	LFBrownNoise0.kr(5, add: 0.1);
	var verb		=	GVerb.ar(in, revtime: (25 * kbn2).clip(10, 50), damping: kbn1.clip(0, 1), mul: 0.05);
	Out.ar(2, verb);
}).add;

~startreverb = {
	s.sync;
	~reverb = Synth(\verb).register;
}.fork;

~startreverb;

/*
~reverb.isPlaying;
~reverb.free;
*/

//

~snr =
SynthDef(\snr, { | a = 1, curve = -64, freq = 500, level = 0.5, pan = 0 |
	var env 		=	Env.perc(attackTime: 0.005, level: level, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var bn1			=	LFBrownNoise0.ar(freq, mul: envgen);
	var bn2			=	LFBrownNoise0.ar(freq, mul: envgen);
	var resl		=	RLPF.ar(bn1, freq, 0.05);
	var resr		=	RLPF.ar(bn2, freq, 0.05);
	var lat			=	Latoocarfian2DC.ar(a: a, mul: 0.75, add: 1).clip(0.1, 1);
	var ap			=	AllpassL.ar([resl, resr], 0.05, (0.02 * lat).clip(1 / (SampleRate.ir / 3), (SampleRate.ir / 3)), 0.05, mul: level/4);
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
SynthDef(\hat, { | a = 1, freq = 1000, level = 0.75, rq = 0.05 |
	var	env			=	Env.perc(level: level);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var imp			=	Impulse.ar(0, mul: envgen);
	var rhpf		=	RLPF.ar(imp, freq, rq);
	var lat			=	Latoocarfian2DC.ar(a: a, mul: 0.051, add: 1).clip(0.1, 1);
	var ap			=	AllpassL.ar(imp, 0.05, 0.02 * lat, 0.75, mul: level / 4);
	Out.ar([2, 3], rhpf + ap).clip(-1, 1);
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
SynthDef(\prc2, { | dur = 1, freq = 3200, im = 1, level = 0.1 |
	var env			=	Env.perc(releaseTime: dur, level: level, curve: -64);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var noiz		=	FBSineC.ar(freq, im: [im, (im + 0.1)], mul: envgen);
	Out.ar(0, noiz).clip(-0.5, 0.5);
}).add;

//

~bass =
SynthDef(\bass, { | a = 1, freq = 440, gate = 1, level = 0.05, ka = 0, ka1 = 1, ka2 = 1, klatmul = 0.01 |
	var env			=	Env.asr(attackTime: 0.003, sustainLevel: level, releaseTime: 0.1);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 2);
	var klat0 		=	Latoocarfian2DL.kr(0.1, 0.5, ka1, mul: klatmul, add: 1);
	var klat1 		=	Latoocarfian2DL.kr(0.1, 0.5, ka1, mul: klatmul, add: 1);
	var klat2 		=	Latoocarfian2DL.kr(0.1, 0.5, ka2, mul: klatmul, add: 1);
	var sin			=	SinOsc.ar(freq, mul: envgen);
	var saw			=	LFSaw.ar((freq * klat0).clip(freq - 1, freq * 2), mul: envgen);
	var sawl		=	LFSaw.ar(((freq - 0.01) * klat1).clip(freq - 2, freq * 2), mul: envgen);
	var sawr		=	LFSaw.ar(((freq + 0.01) * klat2).clip(freq - 2, freq * 2), mul: envgen);
	//var lat 		=	Latoocarfian2DC.ar(0.1, 1, a: a.clip(-3, 3), mul: 1, add: 1);
	var kbn0		= 	LFBrownNoise0.kr(add: 1).clip(0.1, 1.0);
	var rlpf		=	RLPF.ar([sawl, sawr] + [saw, saw], freq * 4);
	var rhpf1		=	RHPF.ar([saw, saw], (freq * 96 * kbn0).clip(freq * 4, SampleRate.ir / 6), 0.25, mul: 0.05).clip(-0.1, 0.1);
	Out.ar(0, sin + rlpf + rhpf1).clip(-1, 1);
	//Out.ar(0, sin + rlpf).clip(-1, 1);
}).add;

//

~pno =
SynthDef(\pno, { | a = 1, dur = 1, freq = 440, latmul = 0.05, level = 0.25, pan = 0 |
	var env			=	Env.perc(releaseTime: dur, level: level);
	//var env			=	Env.asr(sustainLevel: level);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var klat		=	Latoocarfian2DC.kr(a: a, mul: latmul, add: 1);
	var klat2		=	Latoocarfian2DC.kr(a: a + 0.01, mul: latmul, add: 1);
	var klat3		=	Latoocarfian2DC.ar(a: a - 0.01, mul: 1, add: 1);
	var sin1		=	SinOsc.ar(freq, mul: envgen);
	var sin1kl		=	SinOsc.ar(freq * klat, mul: envgen);
	var sin2		=	SinOsc.ar((freq * 2.01), mul: envgen / 64);
	var sin2kl		=	SinOsc.ar(freq * klat2, mul: envgen / 64);
	var sin20		=	SinOsc.ar((freq * 10.01 * klat3).clip(50, SampleRate.ir / 4), mul: envgen / 4);
	//var sinmix		=	sin1 + sin1kl + sin2 + sin2kl + sin20;
	var sinmix		=	sin1 + sin1kl + sin20;
	var pan2 		=	Pan2.ar(sinmix, pan);
	Out.ar(0, pan2).clip(-1, 1);
}).add;

//

~sinpulse =
SynthDef(\sinpulse, { | dur = 1, freq = 200, level = 0.05 |
	var env			=	Env.perc(attackTime: 0.005, releaseTime: dur, level: level, curve: -4);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var sin0		=	SinOsc.ar(freq, mul: envgen);
	var sin1		=	SinOsc.ar(freq * 2.02, mul: envgen / 16);
	var sin2		=	SinOsc.ar(freq * 23, mul: envgen / 64);
	Out.ar([0, 1], sin0 + sin1 + sin2);
}).add;

//

~grable =
SynthDef(\grable, { | a = 1, fb = 0, freq = 400, gate = 1, latmul = 0.5, level = 0.02 |
	var env			=	Env.asr(attackTime: 8, sustainLevel: level, releaseTime: 16, curve: -16);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 2);
	var kbn0		=	LFBrownNoise0.kr(mul: 0.3, add: 1).clip(0.1, 1);
	var kbn1		=	LFBrownNoise0.kr(mul: 0.3, add: 1).clip(0.1, 1);
	var sin0		=	SinOscFB.ar([freq, freq - 0.1], fb, mul: envgen).clip(-1, 1);
	var rlpf		=	RLPF.ar(sin0, freq);
	var rhpf		=	RHPF.ar(sin0, (6000 * [kbn0, kbn0]).clip(50, SampleRate.ir / 4), 0.3 * kbn1);
	//var rlpf1		=	RLPF.ar(rhpf, 6000);
	Out.ar(0, rlpf + rhpf).clip(-0.5, 0.5);
}).add;

//

~pad = SynthDef(\pad, { | a = 1, fbnmul = 1, freq = 400, gate = 1, latmul = 0.02, level = 0.05 |
	var env			= Env.asr(10, level, 20);
	var envgen 		= EnvGen.kr(env, gate, doneAction: 14);
        // use doneAction 14: free enclosing group.
	var lat 		= Latoocarfian2DC.kr(0.01, 10, a: [a, (a - 0.01)], mul: latmul, add: 1).clip(-3, 3);
	var frq 		= (freq * lat).clip(50, 1600);
	var saw 		= Saw.ar(frq + [-0.001, 0.001], mul: envgen);
	var deci		= Decimator.ar(saw, bits: 7).clip(-0.5, 0.5);
	var rhpf		= RHPF.ar(deci, (12000 * lat).clip(freq, SampleRate.ir/4), 0.25, 0.2).clip(-0.5, 0.5);
	var fbn			= LFBrownNoise0.kr(mul: fbnmul, add: 1).clip(0.1, 0.9);
	var rlpf 		= RLPF.ar(saw, (freq * 1.5 * [fbn, fbn]).clip(freq, freq * 4), 0.5).clip(-0.5, 0.5);
	var nodc		=	LeakDC.ar(rlpf + rhpf);
	Out.ar(0, nodc).clip(-0.5, 0.5);
	//Out.ar(0, saw).clip(-0.9, 0.9);
}).add;

/*
~padtest1 = Synth(\pad).register;
~padtest1.isPlaying;
~padtest1.release;
*/

~createPadGroup0 = { | freqs = #[200,300] |
	~padgroup0 = Group(s).register;
	freqs.do({|i|
		Synth.tail(~padgroup0, \pad, [\freq, i, \latmul, 0, \level, 0.05]);
	});
};

/*
~createPadGroup0.value;
~padgroup0.isPlaying;
~padgroup0.release(3);
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

~createPadGroup5 = { | freqs = #[400,600,400,600] |
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
		Synth.tail(~gossamergroup, \pad, [\a, (6.0.rand - 3), \freq, i, \latmul, 0.00005, \level, 0.005]);
	});
};

/*
~createGossamer.value;
~gossamergroup.isPlaying;
~gossamergroup.release(3);
~gossamergroup.free;
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

//

~kikpat =
Pdef(\kikpat,
	Pbind(
		\instrument, \kik,
		\curve, -512,
		\dur, Prand([0.25, Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, 1, 2, 3, 4, 6].mirror2, inf),
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
		\dur, Pshuf([0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24].mirror2, inf),
		\freq, Pwhite(400, 600, inf),
		\level, 0.1,
		\pan, Pshuf([-0.5, -0.25, 0, 0.25, 0.5], inf),
));

/*
~prcpat.play(t, quant: 1);
~prcpat.isPlaying;
~prcpat.stop;
*/

~prcpat1 = Pdef(\prcpat1, Pbindf(~prcpat0, \level, 0.03));

~prcpar = Pdef(\prcpar, Ppar([~prcpat0, ~prcpat1], inf));

/*
~prcpar.play(t, quant: 1);
~prcpar.isPlaying;
~prcpar.stop;
*/

~prc2pat =
Pdef(\prc2pat,
	Pbind(
		\instrument, \prc2,
		\dur, Prand([0.25, 0.5, 0.75, 2, 3, 4, 6, 8, 12, 16, 24], inf),
		\freq, Prand([1/1, 15/14, 9/8, 7/6, 9/7, 4/3, 7/5, 3/2, 12/7, 7/4, 28/15] * 3200, inf),
		\im, Pwhite(0.1, 5.0, inf),
));

/*
~prc2pat.play(t, quant: 1);
~prc2pat.stop;
*/

//

~hatpat =
Pdef(\hatpat,
	Pbind(
		\instrument, \hat,
		\a, Pwhite(0.1, 1.0, inf),
		\dur, Pseq([
			Pseq([0.75], 23), 5,
			Pseq([0.75], 25), 7,
			Pseq([0.75], 27), 9,
			Pseq([1.25], 21), 3,
			Pseq([1.25], 23), 5,
			Pseq([1.25], 25), 7,
		], inf),
));

/*
~hatpat.play(t, quant: 1.5);
~hatpat.isPlaying;
~hatpat.stop;
*/

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
		\level, 0.01,
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
		\level, 0.01,
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
		\dur, Pseq([
			Prand([1, 1.5], 5), 1,
			Prand([1, 1.5], 4), 2,
			Prand([1, 1.5], 3), 3,
			Prand([1, 1.5], 2), 4
		], inf),
		\freq, [200, 300],
		\level, 0.03,
));

/*
~spat.play(t, quant: 1);
~spat.stop;
*/

//

~gpat =
Pdef(\gpat,
	Pbind(
		\instrument, \grable,
		\dur, Prand([32, 48, 64, 96], inf),
		\a, Pwhite(-3, 3, inf),
		\fb, 0.6,
		\freq, Pshuf([7/8, 1/1, 15/14, 9/8, 7/6, 8/7, 4/3, 7/5, 3/2, 12/7, 7/4, 28/15, 2/1] * 400, inf),
		\legato, 0.4,
));

/*
~gpat.play(t, quant: 1);
~gpat.isPlaying;
~gpat.stop;
*/

~gpar = Pdef(\gpar, Ppar([~gpat, ~gpat, ~gpat], inf));

/*
~gpar.play(t, quant: 1);
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

~prcktrl = MIDIdef.cc(\prcktrl, {
	if(~prcpar.isPlaying.not) {
		~prcpar.play(t, quant: 1);
		"prc play".postln;
	} {
		~prcpar.stop;
		"prc stop".postln;
	};
}, 33, srcID: ~nanoktrl2);

~prc2ktrl = MIDIdef.cc(\prc2ktrl, {
	if(~prc2pat.isPlaying.not) {
		~prc2pat.play(t, quant: 1);
		"prc2 play".postln;
	} {
		~prc2pat.stop;
		"prc2 stop".postln;
	};
}, 49, srcID: ~nanoktrl2);

~bassktrl = MIDIdef.cc(\bassktrl, {
	if(~basspat.isPlaying.not) {
		~basspat.play(t, quant: 1);
		"bass play".postln;
	} {
		~basspat.stop;
		"bass stop".postln;
	};
}, 34, srcID: ~nanoktrl2);

~pno1ktrl = MIDIdef.cc(\pno1ktrl, {
	if(~pnopat1.isPlaying.not) {
		~pnopat1.play(t, quant: 1);
		"pno1 play".postln;
	} {
		~pnopat1.stop;
		"pno1 stop".postln;
	};
}, 50, srcID: ~nanoktrl2);

~pno2ktrl = MIDIdef.cc(\pno2ktrl, {
	if(~pnopat2.isPlaying.not) {
		~pnopat2.play(t, quant: 1);
		"pno2 play".postln;
	} {
		~pnopat2.stop;
		"pno2 stop".postln;
	};
}, 66, srcID: ~nanoktrl2);

~pulsektrl = MIDIdef.cc(\pulsektrl, {
	if(~spat.isPlaying.not) {
		~spat.play(t, quant: 1);
		"pulse play".postln;
	} {
		~spat.stop;
		"pulse stop".postln;
	};
}, 35, srcID: ~nanoktrl2);

~grablektrl = MIDIdef.cc(\grablektrl, {
	if(~gpar.isPlaying.not) {
		~gpar.play(t, quant: 1);
		"grable play".postln;
	} {
		~gpar.stop;
		"grable stop".postln;
	};
}, 51, srcID: ~nanoktrl2);

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

/*
~pad0mdef = MIDIdef.cc(\pad0mdef, {
        if (~padgroup0.isPlaying.not) {
			~createPadGroup0.value;
                "pad0 play".postln;
        } {
			~padgroup0.release(3);
			"pad0 stop".postln;
        }
}, 34, srcID: 1310720);
*/

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