// INIT
//midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
//~nanoktrl2 = 1310720;
~nanoktrl2 = 1572864;


~root = 4;
~scale = Scale.new(#[0, 2, 4, 5, 7, 9, 10], 12, name: 'mixo');
~scale2 = Scale.new(#[1, 3, 5, 6, 8], 12, name: 'wat');
t = TempoClock(140/60);

////////////////////////////////////////////////////////////////

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\sinth, { | dur = 1, freq = 440, freq2 = 6000, im = 1, level = 0.03, pan = 0 |
	var env					=	Env.perc(0.003, releaseTime: dur, level: level, curve: -6);
	var envgen				=	EnvGen.kr(env, doneAction: 2);
	var lfn					=	LFNoise1.kr(0.5, 0.003, 1);
	var fbsin				=	FBSineC.ar((freq * 16) * lfn, im, mul: envgen);
	var rlpf				=	RLPF.ar(fbsin, freq * 2, 0.5);
	var rhpf				=	RHPF.ar(fbsin, (freq * 16).clip(50, SampleRate.ir / 3), 0.2);
	var pan2				=	Pan2.ar(rlpf + rhpf, pan);
	Out.ar(0, pan2);
}).add
);

(
~mbiradegrees1 = [-1, 0, 1, 4];
~mbiradurs1 = [2/5, 3/5, 2/5, 2/5, 3/5, 3/5, 2/5, 2/5, 3/5, 2/5, 3/5, 3/5];
~sinpat1 =
Pdef(\sinpat1,
	Pbind(
		\instrument, \sinth,
		\degree, Pseq([Pshuf(~mbiradegrees1.stutter(5), 5)], inf),
		\dur, Pseq(~mbiradurs1, inf),
		\im, Pshuf(((1..3) / 3).stutter(5), inf),
		\octave, 5,
		\pan, -1,
		\root, ~root,
		\scale, ~scale
))
);

~sinpat2 = Pdef(\sinpat2, Pbindf(~sinpat1, \pan, 1));
~sinpat2a = Pdef(\sinpat2a, Pbindf(~sinpat1, \degree, 0, \pan, 0));
~sinpar1 = Pdef(\sinpar, Ppar([~sinpat1, ~sinpat2, ~sinpat2a], inf));

/*
~sinpar1.play(t, quant: 4);
~sinpar1.isPlaying;
~sinpar1.pause;
*/

(
~sinpat1var =
Pdef(\sinpat1var,
	Pbindf(
		~sinpat1,
		//\degree, Pseq([Pshuf((~mbiradegrees1 - 2).stutter(5), 5)], inf),
		\degree, -3,
		\pan, 0
));
);

/*
~sinpat1var.play(t, quant: 4);
~sinpat1var.isPlaying;
~sinpat1var.pause;
*/

(
~sinpat3 =
Pdef(\sinpat3,
	Pbindf(
		~sinpat1,
		\degree, 3,
		\dur, Pseq(~mbiradurs1, inf),
		\octave, 4,
		\pan, 0
));
~sinpat4 = Pdef(\sinpat4, Pbindf(~sinpat3, \dur, 1));
~sinpar2 = Pdef(\sinpar2, Ppar([~sinpat3, ~sinpat4], inf));
);

/*
~sinpar2.play(t, quant: 4);
~sinpar2.isPlaying;
~sinpar2.pause;
*/

(
~sinpat5 =
Pdef(\sinpat5,
	Pbindf(
		~sinpat1,
		\degree, [4, 6],
		\dur, Pseq(~mbiradurs1, inf),
		\pan, 0
));
~sinpat6 = Pdef(\sinpat6, Pbindf(~sinpat5, \dur, 1));
~sinpar3 = Pdef(\sinpar3, Ppar([~sinpat5, ~sinpat6], inf));
);

/*
~sinpar3.play(t, quant: 4);
~sinpar3.isPlaying;
~sinpar3.pause;
*/

//

(
~sinpar1playktrl =
MIDIdef.cc(\sinpar1playktrl, {
	if(~sinpar1.isPlaying.not) {
		~sinpar1.play(t, quant: 4);
		"sinpar1 play".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~sinpar1stopktrl =
MIDIdef.cc(\sinpar1stopktrl, {
	if(~sinpar1.isPlaying) {
		~sinpar1.pause;
		"sinpar1 stop".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~sinpat1varplayktrl =
MIDIdef.cc(\sinpat1varplayktrl, {
	if(~sinpat1var.isPlaying.not) {
		~sinpat1var.play(t, quant: 4);
		"sinpar2 play".postln;
	}
}, 48, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~sinpat1varstopktrl =
MIDIdef.cc(\sinpat1varstopktrl, {
	if(~sinpat1var.isPlaying) {
		~sinpat1var.pause;
		"sinpat1var stop".postln;
	}
}, 48, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~sinpar2playktrl =
MIDIdef.cc(\sinpar2playktrl, {
	if(~sinpar2.isPlaying.not) {
		~sinpar2.play(t, quant: 4);
		"sinpar2 play".postln;
	}
}, 64, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~sinpar2stopktrl =
MIDIdef.cc(\sinpar2stopktrl, {
	if(~sinpar2.isPlaying) {
		~sinpar2.pause;
		"sinpar2 stop".postln;
	}
}, 64, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~sinpar3playktrl =
MIDIdef.cc(\sinpar3playktrl, {
	if(~sinpar3.isPlaying.not) {
		~sinpar3.play(t, quant: 4);
		"sinpar3 play".postln;
	}
}, 33, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~sinpar3stopktrl =
MIDIdef.cc(\sinpar3stopktrl, {
	if(~sinpar3.isPlaying) {
		~sinpar3.pause;
		"sinpar3 stop".postln;
	}
}, 33, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
SynthDef(\pulse, { | dur = 1, freq = 440, level = 0.01, pan = 0 |
	var env				=	Env.perc(0.003, dur, level);
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
		\degree, [0, 3, 4],
		//\dur, Pshuf([8/5, 7/5].stutter(5), inf),
		\dur, Pseq([
			1.5, 2,
			1.5, 1.5, 2,
			1.5, 1.5, 1.5, 2,
		], inf),
		\im, Pshuf(((1..3) / 3).stutter(5), inf),
		\octave, 4,
		\pan, Pshuf([-0.3, 0.3].stutter(5), inf),
		\root, ~root,
		\scale, ~scale,
))
);

/*
~tripat.play(t, quant: 4);
~tripat.isPlaying;
~tripat.pause;
*/

(
~tripatplayktrl =
MIDIdef.cc(\tripatplayktrl, {
	if(~tripat.isPlaying.not) {
		~tripat.play(t, quant: 4);
		"tripat play".postln;
	}
}, 65, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~tripatstopktrl =
MIDIdef.cc(\tripatstopktrl, {
	if(~tripat.isPlaying) {
		~tripat.pause;
		"tripat stop".postln;
	}
}, 65, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
SynthDef(\pad, { | fb = 0.5, freq = 440, gate = 1, level = 0.007 |
	var env				=	Env.asr(sustainLevel: level);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var n				=	8;
	var sfbmix			=	Mix.fill(n, {
		arg i;
		var lfn				=	LFNoise1.kr(0.4.dup, 0.002, 1);
		var sinfb			=	SinOscFB.ar(([freq, freq * 1.001] * (1 + (i / 10000))) * lfn, fb, envgen / (n / 2));
		sinfb
	});
	var rlpf			=	RLPF.ar(sfbmix, freq * 6, 0.3);
	Out.ar(0, rlpf);
}
).add
);

/*
(
var a;
a = List[1, 2, 3, 4];
a.removeAll(List[2, 3]);
a;
)

(0..(~scale.size / 2));
((~scale.size / 2)..(~scale.size -1)).round(1);
*/

(
~chordspatdegreesarray1 = [0, 1, 2, 3].scramble;
~chordspatdegreesarray2 = [4, 5, 6].scramble;
~chordspat1 =
Pdef(\chordspat1,
	Pbind(
		\instrument,\pad,
		\degree, Pshuf(~chordspatdegreesarray1, inf),
		\fb, 0.99,
		\dur, 36,
		\legato, 0.6,
		\octave, 6,
		\root, ~root,
		\scale, ~scale,
));

~chordspat1a = Pdef(\chordspat1a, Pbindf(~chordspat1, \degree, Pshuf(~chordspatdegreesarray2.reverse, inf)));

~chordspar1 = Pdef(\chordspar1, Ppar([~chordspat1, ~chordspat1a], inf));
);

/*
~chordspat1.play(t, quant: 4);
~chordspat1.isPlaying;
~chordspat1.pause;
*/

/*
~chordspar1.play(t, quant: 5);
~chordspar1.isPlaying;
~chordspar1.pause;
*/

(
~chordspat2 =
Pdef(\chordspat2,
	Pbindf(
		~chordspat1,
		\degree, [0, 4],
));
);

/*
~chordspat2.play(t, quant: 5);
~chordspat2.isPlaying;
~chordspat2.pause;
*/

(
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \pad,
		\degree, Pshuf((0..5), inf),
		\dur, 36,
		\fb, 0.8,
		\legato, 0.6,
		\level, 0.03,
		\octave, 2,
		\root, ~root,
		\scale, ~scale2
))
);

/*
~basspat.play(t, quant: 5);
~basspat.isPlaying;
~basspat.pause;
*/

//

(
~chordspar1playktrl =
MIDIdef.cc(\chordspar1playktrl, {
	if(~chordspar1.isPlaying.not) {
		~chordspar1.play(t, quant: 5);
		"chords1 play".postln;
	}
}, 36, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~chordspar1stopktrl =
MIDIdef.cc(\chordspar1stopktrl, {
	if(~chordspar1.isPlaying) {
		~chordspar1.pause;
		"chords1 stop".postln;
	}
}, 36, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~chordspat2playktrl =
MIDIdef.cc(\chordspat2playktrl, {
	if(~chordspat2.isPlaying.not) {
		~chordspat2.play(t, quant: 5);
		"chords2 play".postln;
	}
}, 52, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~chordspat2stopktrl =
MIDIdef.cc(\chordspat2stopktrl, {
	if(~chordspat2.isPlaying) {
		~chordspat2.pause;
		"chords2 stop".postln;
	}
}, 52, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~basspatplayktrl =
MIDIdef.cc(\basspatplayktrl, {
	if(~basspat.isPlaying.not) {
		~basspat.play(t, quant: 5);
		"bass play".postln;
	}
}, 68, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~basspatstopktrl =
MIDIdef.cc(\basspatstopktrl, {
	if(~basspat.isPlaying) {
		~basspat.pause;
		"bass stop".postln;
	}
}, 68, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
SynthDef(\klk, { | freq = 8000, level = 0.05, pan = 0 |
	var env				=	Env.perc(0.0005, 0.01, level, -64);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise1.ar(12000, envgen);
	var rhpf			=	RHPF.ar(lfn, 8000, 0.2);
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
		\pan, 0
))
);

/*
~klkpat.play(t, quant: 1);
~klkpat.isPlaying;
~klkpat.pause;
*/

(
~klkechodurs = ([6, 6, 7, 6, 6, 6, 7, 6, 6, 6, 6, 7]) / 5;
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
		\dur, Pseq(~klkechodurs.reverse, inf),
		\pan, 1
))
);

/*
~klkpat2.play(t, quant: 1);
~klkpat2.isPlaying;
~klkpat2.pause;
*/

/*
~klkpat3.play(t, quant: 1);
~klkpat3.isPlaying;
~klkpat3.pause;
*/

~klkpar = Pdef(\klkpar, Ppar([~klkpat, ~klkpat2, ~klkpat3], inf));

/*
~klkpar.play(t, quant: 1);
~klkpar.isPlaying;
~klkpar.pause;
*/

(
~klkparplayktrl =
MIDIdef.cc(\klkparplayktrl, {
	if(~klkpar.isPlaying.not) {
		~klkpar.play(t, quant: 1);
		"klk play".postln;
	}
}, 34, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~klkparstopktrl =
MIDIdef.cc(\klkparstopktrl, {
	if(~klkpar.isPlaying) {
		~klkpar.pause;
		"klk stop".postln;
	}
}, 34, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
SynthDef(\snr, { | curve = -16, freq = 12000, ffreq = 1000, klkffreq = 2000, klklevel = 0.1, level = 0.5, pan = 0, rq = 0.2 |
	var env				=	Env.perc(0.003, 0.1, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var klk				=	BlitB3.ar(0, klklevel);
	var klkflt			=	RLPF.ar(klk, klkffreq);
	var lfn				=	LFNoise2.ar(freq, envgen);
	var rlpf			=	RLPF.ar(lfn, ffreq, rq);
	var pan2			=	Pan2.ar(rlpf + klkflt, pan);
	Out.ar(0, pan2);
}).add
);

(
~snrpat1 =
Pdef(\snrpat1,
	Pbind(
		\instrument, \snr,
		// \dur, Pseq([
		// 	1, 1, 1, 2,
		// 	1, 1, 1, 1, 2,
		// 	1, 1, 1, 1, 1, 2
		// ], inf),
		\freq, Pwhite(11000, 13000, inf),
		\ffreq, 1200,
		\level, 0.4,
		//\note, Pseq([Rest, 0], inf),
		\note, Pseq([
			Rest, 0, Rest,
			Rest, 0, Rest, 0, Rest,
			Rest, 0, Rest, 0, Rest, 0, Rest
		], inf),
))
);

/*
~snrpat1.play(t, quant: 1);
~snrpat1.isPlaying;
~snrpat1.pause;
*/

(
~snrdursarray = [2, 3].stutter(5) / 5;
(
~snrpat2 =
Pdef(\snrpat2,
	Pbindf(
		~snrpat1,
		\dur, Pseq(~snrdursarray, inf),
		\level, 0.03,
		\note, 0,
		\pan, -1
))
);

(
~snrpat3 =
Pdef(\snrpat3,
	Pbindf(
		~snrpat2,
		\dur, Pseq(~snrdursarray.reverse, inf),
		\pan, 1
))
);
);

/*
~snrpat2.play(t, quant: 1);
~snrpat2.isPlaying;
~snrpat2.pause;
*/

/*
~snrpat3.play(t, quant: 1);
~snrpat3.isPlaying;
~snrpat3.pause;
*/

~snrpar = Pdef(\snrpar, Ppar([~snrpat1, ~snrpat2, ~snrpat3], inf));

/*
~snrpar.play(t, quant: 1);
~snrpar.isPlaying;
~snrpar.pause;
*/

(
~snrparplayktrl =
MIDIdef.cc(\snrparplayktrl, {
	if(~snrpar.isPlaying.not) {
		~snrpar.play(t, quant: 1);
		"snr play".postln;
	}
}, 50, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~snrparstopktrl =
MIDIdef.cc(\snrparstopktrl, {
	if(~snrpar.isPlaying) {
		~snrpar.pause;
		"snr stop".postln;
	}
}, 50, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
~kikpat =
Pdef(\kikpat,
	Pbind(
		\instrument, \snr,
		\curve, 0,
		\dur, Pseq([1/5, 1, 2, 3].mirror2, inf),
		\freq, 100,
		\ffreq, 200,
		\klkffreq, 3000,
))
);

/*
~kikpat.play(t, quant: 1);
~kikpat.isPlaying;
~kikpat.pause;
*/

(
~kikpatplayktrl =
MIDIdef.cc(\kikpatplayktrl, {
	if(~kikpat.isPlaying.not) {
		~kikpat.play(t, quant: 1);
		"kik play".postln;
	}
}, 66, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~kikparstopktrl =
MIDIdef.cc(\kikpatstopktrl, {
	if(~kikpat.isPlaying) {
		~kikpat.pause;
		"kik stop".postln;
	}
}, 66, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
~perc1pat =
Pdef(\perc1pat,
	Pbind(
		\instrument, \snr,
		\dur, Prand([Pseq([1, 4] / 5), Pseq([2, 3] / 5), Pseq([3, 2] / 5), Pseq([2, 2, 1] / 5), Pseq([2, 1, 2] / 5), 1], inf),
		\freq, 19000,
		\ffreq, Pshuf([250, 350, 450].stutter(5), inf),
		\klklevel, 0.03,
		\level, 0.15,
))
);

/*
~perc1pat.play(t, quant: 1);
~perc1pat.isPlaying;
~perc1pat.pause;
*/

~perc1par = Pdef(\perc1par, Ppar(Array.fill(4, { ~perc1pat })));

/*
~perc1par.play(t, quant: 1);
~perc1par.isPlaying;
~perc1par.pause;
*/

(
~perc1parplayktrl =
MIDIdef.cc(\perc1parplayktrl, {
	if(~perc1par.isPlaying.not) {
		~perc1par.play(t, quant: 1);
		"perc1 play".postln;
	}
}, 51, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~perc1parstopktrl =
MIDIdef.cc(\perc1parstopktrl, {
	if(~perc1par.isPlaying) {
		~perc1par.pause;
		"perc1 stop".postln;
	}
}, 51, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
SynthDef(\perc2, { | curve = -64, freq = 15000, level = 0.1 |
	var env				=	Env.perc(releaseTime: 1.5, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var fenv			=	Env.new([1, 3], [1], \sine);
	var fenvgen			=	EnvGen.kr(fenv);
	var bn				=	LFBrownNoise1.ar(freq.dup, mul: envgen);
	var rhpf			=	RHPF.ar(bn, 4000);
	var delay			=	AllpassC.ar(rhpf, delaytime: [0.005, 0.0075] * fenvgen, decaytime: 1);
	Out.ar(0, rhpf + delay);
}).add
);

(
~perc2pat =
Pdef(\perc2pat,
	Pbind(
		\instrument, \perc2,
		\freq, Pseq(((18..10) * 1000).mirror2, inf),
		\level, Pseq(((0..10) / 100).mirror2, inf),
));
);

/*
~perc2pat.play(t, quant: 1);
~perc2pat.isPlaying;
~perc2pat.pause;
*/

(
~perc2patplayktrl =
MIDIdef.cc(\perc2patplayktrl, {
	if(~perc2pat.isPlaying.not) {
		~perc2pat.play(t, quant: 1);
		"perc2 play".postln;
	}
}, 35, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~perc2parstopktrl =
MIDIdef.cc(\perc2patstopktrl, {
	if(~perc2pat.isPlaying) {
		~perc2pat.pause;
		"perc2 stop".postln;
	}
}, 35, srcID: ~nanoktrl2, argTemplate: 0)
);