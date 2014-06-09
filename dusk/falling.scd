// INIT
//midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
//~nanoktrl2 = 1310720;
~nanoktrl2 = 1572864;

s.freeAll;

~root = 4;
~scale = Scale.new(#[0, 2, 4, 5, 7, 9, 10], 12, name: 'mixo');
~scale2 = Scale.new(#[0, 1, 3, 4, 5, 8], 12, name: 'wat');
t = TempoClock(140/60);

////////////////////////////////////////////////////////////////

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\sinth, { | dur = 1, freq = 440, freq2 = 6000, im = 1, level = 0.015, pan = 0 |
	var env					=	Env.perc(0.003, releaseTime: 0.75, level: level);
	var envgen				=	EnvGen.kr(env, doneAction: 2);
	var fbsin				=	FBSineC.ar(([freq, freq * 1.005] * 16).dup, im, mul: envgen);
	var rlpf				=	RLPF.ar(fbsin, freq * 2, 0.5);
	var rhpf				=	RHPF.ar(fbsin, (freq * 12).clip(50, SampleRate.ir / 3), 0.2);
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
		\im, Prand((1..3) / 3, inf),
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
~sinpar2.play(t, quant: 4);
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
~sinpar3.play(t, quant: 4);
~sinpar3.isPlaying;
~sinpar3.pause;
*/

/*
~sinpar.stop;
~sinpar2.stop;
~sinpar3.stop;
*/

(
~sinparplayktrl =
MIDIdef.cc(\sinparplayktrl, {
	if(~sinpar.isPlaying.not) {
		~sinpar.play(t, quant: 4);
		"sinpar1 play".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~sinparstopktrl =
MIDIdef.cc(\sinparstopktrl, {
	if(~sinpar.isPlaying) {
		~sinpar.pause;
		"sinpar stop".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~sinpar2playktrl =
MIDIdef.cc(\sinpar2playktrl, {
	if(~sinpar2.isPlaying.not) {
		~sinpar2.play(t, quant: 4);
		"sinpar2 play".postln;
	}
}, 48, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~sinpar2stopktrl =
MIDIdef.cc(\sinpar2stopktrl, {
	if(~sinpar2.isPlaying) {
		~sinpar2.pause;
		"sinpar2 stop".postln;
	}
}, 48, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~sinpar3playktrl =
MIDIdef.cc(\sinpar3playktrl, {
	if(~sinpar3.isPlaying.not) {
		~sinpar3.play(t, quant: 4);
		"sinpar3 play".postln;
	}
}, 64, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~sinpar3stopktrl =
MIDIdef.cc(\sinpar3stopktrl, {
	if(~sinpar3.isPlaying) {
		~sinpar3.pause;
		"sinpar3 stop".postln;
	}
}, 64, srcID: ~nanoktrl2, argTemplate: 0)
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
		\degree, [-1, 0, 1, 4],
		//\dur, Pshuf([8/5, 7/5].stutter(5), inf),
		\dur, Pseq([
			1.5, 2,
			1.5, 1.5, 2,
			1.5, 1.5, 1.5, 2,
		], inf),
		\octave, 5,
		\pan, Pseq([-0.5, 0.5], inf),
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
}, 33, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~tripatstopktrl =
MIDIdef.cc(\tripatstopktrl, {
	if(~tripat.isPlaying) {
		~tripat.pause;
		"tripat stop".postln;
	}
}, 33, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
SynthDef(\pad, { | fb = 0.5, freq = 440, gate = 1, level = 0.01 |
	var env				=	Env.asr(sustainLevel: level);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var lfn				=	LFNoise1.kr(0.4.dup, 0.003, 1);
	var sinfb			=	SinOscFB.ar([freq, freq * 1.001] * lfn, fb, envgen);
	var rlpf			=	RLPF.ar(sinfb, freq * 4);
	Out.ar(0, rlpf);
}
).add
);

(
~chordspat1 =
Pdef(\chordspat1,
	Pbind(
		\instrument,\pad,
		\degree, Pshuf((0..(~scale.size - 1)), inf),
		\fb, 0.99,
		\dur, 24,
		\octave, 6,
		\root, ~root,
		\scale, ~scale,
));
);

/*
~chordspat1.play(t, quant: 4);
~chordspat1.isPlaying;
~chordspat1.pause;
*/

(
~chordspat2 =
Pdef(\chordspat2,
	Pbindf(
		~chordspat1,
		\degree, [0, 4],
		\scale, ~scale
));
);

/*
~chordspat2.play(t, quant: 4);
~chordspat2.isPlaying;
~chordspat2.pause;
*/


(
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \pad,
		\degree, Pshuf((0..5), inf),
		\dur, 24,
		\fb, 0.9,
		\legato, 0.5,
		\level, 0.05,
		\octave, 2,
		\root, ~root,
		\scale, ~scale2
))
);

/*
~basspat.play(t, quant: 24);
~basspat.isPlaying;
~basspat.pause;
*/

//

(
~chordspat1playktrl =
MIDIdef.cc(\chordspat1playktrl, {
	if(~chordspat1.isPlaying.not) {
		~chordspat1.play(t, quant: 4);
		"chords1 play".postln;
	}
}, 36, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~chordspat1stopktrl =
MIDIdef.cc(\chordspat1stopktrl, {
	if(~chordspat1.isPlaying) {
		~chordspat1.pause;
		"chords1 stop".postln;
	}
}, 36, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~chordspat2playktrl =
MIDIdef.cc(\chordspat2playktrl, {
	if(~chordspat2.isPlaying.not) {
		~chordspat2.play(t, quant: 4);
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
		~basspat.play(t, quant: 24);
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
SynthDef(\snr, { | freq = 12000, ffreq = 1000, level = 0.3 |
	var env				=	Env.perc(releaseTime: 0.1, level: level, curve: -16);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise2.ar(freq.dup, envgen);
	var rlpf			=	RLPF.ar(lfn, ffreq, 0.2);
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
		\level, 0.03,
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
	Pbindf(
		~snrpat,
		\dur, 3,
		\freq, Pwhite(11000, 13000, inf),
		\ffreq, 1000,
		\level, 0.15,
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
		\dur, Prand([Pseq([2, 2, 1] / 5), Pseq([2, 1, 2] / 5), 1], inf),
		\freq, Pwhite(18900, 19100, inf),
		\ffreq, 500,
))
);

/*
~perc1pat.play(t, quant: 1);
~perc1pat.isPlaying;
~perc1pat.pause;
*/

(
~perc1patplayktrl =
MIDIdef.cc(\perc1patplayktrl, {
	if(~perc1pat.isPlaying.not) {
		~perc1pat.play(t, quant: 1);
		"perc1 play".postln;
	}
}, 51, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~perc1parstopktrl =
MIDIdef.cc(\perc1patstopktrl, {
	if(~perc1pat.isPlaying) {
		~perc1pat.pause;
		"perc1 stop".postln;
	}
}, 51, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
SynthDef(\perc2, { | curve = -64, freq = 15000, level = 0.1 |
	var env				=	Env.perc(releaseTime: 0.1, level: level, curve: curve);
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