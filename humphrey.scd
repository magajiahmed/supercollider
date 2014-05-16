Pdef.removeAll;

( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl2 = 1310720;
//~nanoktrl2 = 1835008;
//~nanoktrl2 = 1572864;
);


s.scope;
~scale = Scale.chromatic;
t = TempoClock(88/60);

(
SynthDef(\thump, { | dur = 1, freq = 400, level = 0.1, rezfreq = 12000 |
	var env				=	Env.perc(releaseTime: 1.5, level: level, curve: -24);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	//var	sin1			=	SinOsc.ar([freq, freq * 1.01], mul: envgen);
	//var sin2			=	SinOsc.ar([freq, freq * 1.01] * 2, mul: envgen/2);
	var saw				=	Saw.ar([freq, freq * 1.02], mul: envgen);
	var rlpf			=	RLPF.ar(saw, freq * 3, 0.5);
	//var deci			=	Decimator.ar(saw, 10000, bits: 5, mul: envgen * 2);
	var lfn				=	LFNoise2.kr(1.dup).range(0.25, 1);
	var rez				=	Resonz.ar(saw, rezfreq * lfn, 0.05);
	var deci			=	Decimator.ar(rez, bits: 5, mul: envgen);
	Out.ar(0, rlpf + deci);
}).add
);

(
~thumpat =
Pdef(\thumpat,
	Pbind(
		\instrument, \thump,
		\degree, Pshuf([-2, 0, 0, 0, 0].stutter(3), inf),
		\dur, Pseq([Pshuf([Pseq([0.25], 3), 0.75, Pseq([0.25, 0.75]), 1.5, 3].stutter(3)), 11], inf),
		\octave, 3,
		\rezfreq, Pshuf([12000, 14000].stutter(3), inf),
		\scale, ~scale
))
);

/*
~thumpat.play(t, quant: 0.5);
~thumpat.pause;
*/

(
~thumpon = MIDIdef.cc(\thumpon, {
	if(~thumpat.isPlaying.not) {
		~thumpat.play(t, quant: 0.5);
		"bass play".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~thumpoff = MIDIdef.cc(\thumpoff, {
	if(~thumpat.isPlaying) {
		~thumpat.pause;
		"bass stop".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: 0);
);

////////////////////////////////////////////////////////////////////////////////////////////

(
SynthDef(\drone, { | a = 1.1, dur = 1, freq = 400, gate = 1, gliss_start = 2000, gliss_end = 4000, level = 0.01  |
	var env				=	Env.asr(0.1, level, 5, -4);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var sin				=	SinOsc.ar([freq, freq * 1.001], mul: envgen / 2);
	var fbsin			=	FBSineC.ar([22050, 22000]).range(0.25, 0.75);
	var sinfb			=	SinOscFB.ar(freq, fbsin, envgen);
	var rez				=	Resonz.ar(sinfb, freq * 4, 0.1, 2);
	Out.ar(0, sin + sinfb + rez);
}).add
);

(
~dronepat1 =
Pdef(\dronepat1,
	Pbind(
		\instrument, \drone,
		\degree, [0, 7],
		\dur, 84,
		\legato, 0.3,
		\octave, 4,
		\scale, ~scale
))
);

/*
~dronepat1.play(t, quant: 1);
~dronepat1.isPlaying;
~dronepat1.pause;
*/

(
~dronepat2 =
Pdef(\dronepat2,
	Pbindf(
		~dronepat1,
		\degree, [-2, 2],
		\dur, 53,
		\octave, 5,
))
);

/*
~dronepat2.play(t, quant: 1);
~dronepat2.isPlaying;
~dronepat2.pause;
*/

(
~drone1on = MIDIdef.cc(\drone1on, {
	if(~dronepat1.isPlaying.not) {
		~dronepat1.play(t, quant: 0.5);
		"drone1 play".postln;
	};
}, 48, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~drone1off = MIDIdef.cc(\drone1off, {
	if(~dronepat1.isPlaying) {
		~dronepat1.pause;
		"drone1 stop".postln;
	};
}, 48, srcID: ~nanoktrl2, argTemplate: 0);
);

(
~drone2on = MIDIdef.cc(\drone2on, {
	if(~dronepat2.isPlaying.not) {
		~dronepat2.play(t, quant: 0.5);
		"drone2 play".postln;
	};
}, 64, srcID: ~nanoktrl2, argTemplate: { arg i; i > 0 });
);

(
~drone2off = MIDIdef.cc(\drone2off, {
	if(~dronepat2.isPlaying) {
		~dronepat2.pause;
		"drone2 stop".postln;
	};
}, 48, srcID: ~nanoktrl2, argTemplate: 0);
);

//////////////////////////////////////////////////////////////////////////////////////////////////////////

(
SynthDef(\click, { | bwr = 0.4, delaytime = 0.03, ffreq = 3000 |
	var env				=	Env.perc(0.003, 0.1, 1, 0);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var imp				=	BlitB3.ar(0.dup, mul: envgen);
	var delay			=	AllpassC.ar(imp, 1.5, delaytime, 1.5, 0.25);
	var rlpf			=	Resonz.ar(imp + delay, ffreq, bwr, 32);
	Out.ar(0, rlpf);
}).add
);

(
~clickpat1 =
Pdef(\clickpat1,
	Pbind(
		\instrument, \click,
		\ffreq, 12000,
		\note, Pseq([
			1, 1, 1, Rest, Rest,
			1, 1, 1, 1, Rest, Rest,
			1, 1, 1, 1, 1, Rest, Rest
		], inf)
	)
)
);

/*
~clickpat1.play(t, quant: 1);
~clickpat1.isPlaying;
~clickpat1.pause;
*/

(
~clickpat2 =
Pdef(\clickpat2,
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
~clickpat2.play(t, quant: 1);
~clickpat2.isPlaying;
~clickpat2.pause;
*/


/////////////////////////////////////////////////////////////////////////

// (
// SynthDef(\kick, { | freq = 50, level = 0.15 |
// 	var env				=	Env.perc(releaseTime: 2, level: level, curve: -64);
// 	var envgen			=	EnvGen.kr(env, doneAction: 2);
// 	var sin1			=	SinOsc.ar(freq.dup, mul: envgen);
// 	var sin2			=	SinOsc.ar((freq.dup) * 2, mul: envgen/4);
// 	Out.ar(0, sin1 + sin2);
// }).add
// );
//
// (
// ~kickpat =
// Pdef(\kickpat,
// 	Pbind(
// 		\instrument, \kick,
// 		\dur, 0.75,
// 		\degree, Pseq([
// 			0, Rest,
// 			0, Rest, Rest,
// 			0, Rest, Rest, Rest
// 		], inf),
// 		\octave, 3,
// 		\scale, ~scale,
// ))
// );

/*
~kickpat.play(t, quant: 1);
~kickpat.isPlaying;
~kickpat.pause;
*/

/////////////////////////////////////////////////////////////////////////////

(
SynthDef(\pno, { | a = 1, dur = 1, freq = 400, level = 0.01 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: -4);
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
		\dur, Pshuf([0.25, 0.5, 0.75, 31], inf),
		\degree, Pshuf(([0, 1, 2, 3, 7]).stutter(3), inf),
		\octave, 6,
		\scale, ~scale,
		//\strum, Pwhite(-0.2, 0.2, inf),
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

~pnopar = Pdef(\pnopar, Ppar(Array.fill(4, { ~pnopat1 })));

/*
~pnopar.play(t, quant: 1);
~pnopar.isPlaying;
~pnopar.pause;
*/