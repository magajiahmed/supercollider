//midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
//~nanoktrl2 = 1310720;
~nanoktrl2 = ~midisource = MIDIClient.sources.detect{ arg a; a.name.contains("nanoKONTROL2")};

s.meter;
s.scope(2);

//~patterndegrees1 = [-2, -1, 1, 2, 7];
~tuning = Tuning.just;
~scale = Scale.new(#[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], 12, ~tuning);
~root = 3;
~root2 = 10;

t = TempoClock(140/60);

////////////////////////////////////////////////////////////////

~lmamediadir = "/media/lma";

~filteredcrickets.free;
~filteredcrickets = Buffer.read(s, ~lmamediadir ++ "/samples/FilteredCrickets01.wav");
~filteredcrickets.bufnum;

~bees.free;
~bees = Buffer.read(s, ~lmamediadir ++ "/samples/1693.Dmitry_Urupin.Solovetsky_Islands.Bumblebees_and_bees.aif");
~bees.bufnum;

/////////////////////////////////////////////////////////////////

(
SynthDef(\sndfileplayer, { | bufnum, gate = 1, loop = 0, out = 0, rate = 1, startPos = 0, vol = 0 |
	var env			 	=	Env.asr(0.1, vol, 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var playbuf			=	PlayBuf.ar(
		2, bufnum, BufRateScale.kr(bufnum) * rate, startPos: startPos, loop: loop, doneAction: 2
	) * envgen;
	Out.ar(out, playbuf);
}).add
);

/*
~filteredcricketsplay = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 1, \vol, 0.1]).register;
~filteredcricketsplay.isPlaying;
~filteredcricketsplay.release;
*/

(
~crpat1 = Pdef(\crpat1,
	Pbind(
		\instrument, \sndfileplayer,
		\bufnum, ~filteredcrickets.bufnum,
		\dur, Pwhite(30.0, 90.0, inf),
		\legato, 1,
		\loop, 0,
		\note, Pseq([0, Rest], inf),
		\rate, Pwhite(0.1, 2, inf),
		\startPos, Pwhite(0, ~filteredcrickets.numFrames / 2),
		\vol, 0.1
));
);

/*
~crpat1.play;
~crpat1.isPlaying;
~crpat1.stop;
*/

~crpar = Pdef(\crpar, Ppar(Array.fill(3, { ~crpat1 })));

/*
~crpar.play;
~crpar.isPlaying;
~crpar.stop;
*/

(
~crparplayktrl =
MIDIdef.cc(\crparplayktrl, {
	if(~crpar.isPlaying.not) {
		~crpar.play(t, quant: 1);
		"crpar play".postln;
	}
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~crparstopktrl =
MIDIdef.cc(\crparstopktrl, {
	if(~crpar.isPlaying) {
		~crpar.pause;
		"crpar stop".postln;
	}
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
~drone =
SynthDef(\drone, { | a = 1.1, c = 0.5, fb = 0.1, freq = 440, gate = 1, im = 1, level = 0.02 |
	var env				=	Env.asr(0.01, level, 0.5, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var lfn1			=	LFNoise2.kr(0.1.dup, 0.008, 1);
	var lfn2			=	LFNoise1.kr(0.1.dup, 0.0003, 1);
	var fbsin			=	FBSineC.ar([freq, freq * 1.004] * 8 * lfn1, im, fb, a, c, mul: envgen).round(0.0003);
	var sinfb			=	SinOscFB.ar(freq.dup * lfn2, 0.2, mul: envgen);
	var sin				=	SinOsc.ar(freq, mul: envgen / 4);
	var kbn1			=	LFBrownNoise0.kr(15.dup).range(0, 1).round(1);
	var rhpf1			=	RHPF.ar(fbsin, freq * 16, 0.01, kbn1);
	var kbn2			=	LFBrownNoise0.kr(15.dup).range(0, 1).round(1);
	var rhpf2			=	RHPF.ar(fbsin, freq * 12, 0.01, kbn2);
	var rlpf			=	BLowPass4.ar(sinfb + sin, freq * 2, 0.5);
	//Out.ar(0, rlpf + (rhpf1 * 12) + rhpf2);
	Out.ar(0, rlpf + rhpf1 + rhpf2);
}).add
);

(
~dronepat1 =
Pdef(\dronepat1,
	Pmono(
		\drone,
		\degree, [0, 19, 24],
		\octave, 3,
		\root, ~root,
		\scale, ~scale
));
);

/*
~dronepat1.play(t, quant: 1);
~dronepat1.isPlaying;
~dronepat1.stop;
*/

(
~dronepat2 =
Pdef(\dronepat2,
	Pbind(
		\instrument, \drone,
		\degree, Pshuf([-2, 1, 2], inf),
		\dur, 30,
		\legato, 0.8,
		\octave, 5,
		\root, ~root,
		\scale, ~scale,
));
);

/*
~dronepat2.play(t, quant: 1);
~dronepat2.isPlaying;
~dronepat2.stop;
*/

//

(
~dronepat1playktrl =
MIDIdef.cc(\dronepat1playktrl, {
	if(~dronepat1.isPlaying.not) {
		~dronepat1.play(t, quant: 1);
		"dronepat1 play".postln;
	}
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~dronepat1stopktrl =
MIDIdef.cc(\dronepat1stopktrl, {
	if(~dronepat1.isPlaying) {
		~dronepat1.pause;
		"dronepat1 stop".postln;
	}
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~dronepat2playktrl =
MIDIdef.cc(\dronepat2playktrl, {
	if(~dronepat2.isPlaying.not) {
		~dronepat2.play(t, quant: 1);
		"dronepat2 play".postln;
	}
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~dronepat2stopktrl =
MIDIdef.cc(\dronepat2stopktrl, {
	if(~dronepat2.isPlaying) {
		~dronepat2.pause;
		"dronepat2 stop".postln;
	}
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////
// pno

(
SynthDef(\pno, { | dur = 1, freq = 400, level = 0.02 |
	var env				=	Env.perc(0.003, dur, level, -6);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfbnampmod		=	LFNoise0.kr(15.dup).range(0.5, 1).round(0.25);
	var sin				=	SinOscFB.ar(freq, 0.05, envgen);
	var lfbn1			=	LFBrownNoise2.ar(10000.dup, mul: envgen * lfbnampmod);
	var rhpf			=	RHPF.ar(lfbn1, 6000, 0.1);
	Out.ar(0, (sin + (rhpf)) * lfbnampmod);
}).add;
);

(
~pnopat1 =
Pdef(\pnopat1,
	Pbind(
		\instrument, \pno,
		\degree, Pshuf([[-5, -2], [-6, -5, 0], [-9, 1], [0, 3], [0, 5]].mirror2, inf),
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24], inf),
		\octave, 7,
		\root, ~root,
		\scale, ~scale));
);

/*
~pnopat1.play(t, quant: 1);
~pnopat1.isPlaying;
~pnopat1.stop;
*/

(
~pnopat1playktrl =
MIDIdef.cc(\pnopat1playktrl, {
	if(~pnopat1.isPlaying.not) {
		~pnopat1.play(t, quant: 1);
		"pnopat1 play".postln;
	}
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~pnopat1stopktrl =
MIDIdef.cc(\pnopat1stopktrl, {
	if(~pnopat1.isPlaying) {
		~pnopat1.pause;
		"pnopat1 stop".postln;
	}
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////////////
// clicks

(
SynthDef(\klk, { | minfreq = 18000, maxfreq = 20000, ffreq = 4000, bwr = 0.1, a = 1, b = 3, level = 0.1 |
	var env				=	Env.perc(0.003, 0.05, level, -64);
	var envgen			=	EnvGen.ar(env, doneAction: 2);
	var lat				=	Latoocarfian2DN.ar([minfreq, minfreq + 100], [maxfreq, maxfreq + 100], a, b, mul: envgen).wrap(-0.5, 0.5);
	var flt				=	Resonz.ar(lat, ffreq, bwr, 3);
	Out.ar(0, flt);
}).add;
);

~pstan = Pstandard.new.asStream;

/*
~pstan.next;
*/

(
~a = [0.1, 0.5, 0.8, 0.9, 1];
p = Prout({
	var x;
	loop({
		x = (~pstan.next[0] * ~a.size);
		x.yield;
	})
});
);

(
~durations = [0.25, 0.5, 0.75];
q = Prout({
	var x;
	loop({
		x = (~pstan.next[1] * ~durations.size);
		x.yield;
	})
});
);

(
~klkpat =
Pdef(\klkpat,
	Pbind(
		\instrument, \klk,
		\a, Pswitch1(~a, p),
		\dur, Pswitch1(~durations, q),
		\ffreq, 6000,
		\level, 0.5,
))
);

/*
~klkpat.play(t, quant: 1);
~klkpat.isPlaying;
~klkpat.stop;
*/

(
~klkpatplayktrl =
MIDIdef.cc(\klkpatplayktrl, {
	if(~klkpat.isPlaying.not) {
		~klkpat.play(t, quant: 1);
		"klkpat play".postln;
	}
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~klkpatstopktrl =
MIDIdef.cc(\klkpatstopktrl, {
	if(~klkpat.isPlaying) {
		~klkpat.pause;
		"klkpat stop".postln;
	}
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
SynthDef(\prc, { | a = 1, b = 1.9, cuspfreq = 22000, ffreq = 4000, level = 0.1 |
	var env				=	Env.perc(0.005, 0.1, level, -16);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspN.ar([cuspfreq, cuspfreq - 1], a, b, mul: envgen).fold(-0.2, 0.2);
	var rlpf			=	RLPF.ar(cusp, ffreq, 0.5);
	Out.ar(0, rlpf);
}).add;
);

(
~prcpat =
Pdef(\prcpat,
	Pbind(
		\instrument, \prc,
		\a, Pwhite(0.5, 2.0, inf),
		\b, Pwhite(1.0, 3.0, inf),
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].mirror2, inf),
		\level, Pxrand([0.5, 0.75, 1] * 0.3, inf),
))
);

/*
~prcpat.play(t, quant: 1);
~prcpat.isPlaying;
~prcpat.stop;
*/

(
~prc2pat =
Pdef(\prc2pat,
	Pbindf(
		~prcpat,
		\ffreq, 500,
))
);

/*
~prc2pat.play(t, quant: 1);
~prc2pat.isPlaying;
~prc2pat.stop;
*/

//

(
~prcpatplayktrl =
MIDIdef.cc(\prcpatplayktrl, {
	if(~prcpat.isPlaying.not) {
		~prcpat.play(t, quant: 1);
		"prcpat play".postln;
	}
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~prcpatstopktrl =
MIDIdef.cc(\prcpatstopktrl, {
	if(~prcpat.isPlaying) {
		~prcpat.pause;
		"prcpat stop".postln;
	}
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~prc2patplayktrl =
MIDIdef.cc(\prc2patplayktrl, {
	if(~prc2pat.isPlaying.not) {
		~prc2pat.play(t, quant: 1);
		"prc2pat play".postln;
	}
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~prc2patstopktrl =
MIDIdef.cc(\prc2patstopktrl, {
	if(~prc2pat.isPlaying) {
		~prc2pat.pause;
		"prc2pat stop".postln;
	}
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////
// bass

(
SynthDef(\bass, { | bwr = 1, dur = 1, fb = 0.4, ffreq = 2000, freq = 440, gate = 1, level = 0.1 |
	var env					=	Env.perc(0.01, dur, level, -8);
	var envgen				=	EnvGen.kr(env, doneAction: 2);
	var sinfb				=	SinOscFB.ar(freq.dup, fb, envgen);
	Out.ar([0, 2], sinfb);
}).add
);

(
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24], inf),
		\degree, Pshuf([0, 1, 2, 3, 7].stutter(5), inf),
		\fb, Pwhite(0.5, 0.8, inf),
		\octave, 3,
		\root, ~root,
		\scale, ~scale,
));
);

/*
~basspat.play(t, quant: 1);
~basspat.isPlaying;
~basspat.stop;
*/

~waitforverbtoload = Routine({
	(
		SynthDef(\verb, { | combfreq = 30, ffreq = 2000, invol = 0.1, modfreq = 15, outvol = 0.3, rq = 0.5, size = 0.1, t60 = 15 |
			var in					=	In.ar(2, 2);
			var verb				=	JPverbRaw.ar(in[0] * invol, in[1] * invol, earlydiff: 0.08, size: size, t60: t60);
			var lfbncombfreqmod		=	LFBrownNoise0.kr(modfreq.dup).range(0.25, 4);
			var comb				=	CombC.ar(verb, 0.2, combfreq.reciprocal * lfbncombfreqmod, 1);
			var lfbnampmod			=	LFBrownNoise0.kr(15).range(0.5, 1).round(0.5);
			var rhpf				=	RHPF.ar(comb, ffreq, rq, lfbnampmod * outvol);
			Out.ar(0, rhpf);
		}).add;
	);

	s.sync;

	~verb = Synth(\verb).register;


	/*
	~verb.isPlaying;
	~verb.free;
	//
	~verb.set(\combfreq, 30);
	~verb.set(\ffreq, 2000);
	~verb.set(\modfreq, 15);
	~verb.set(\outvol, 0.3);
	~verb.set(\rq, 0.5);
	~verb.set(\size, 0.05);
	~verb.set(\t60, 15);
	*/
});

(
~basspatplayktrl =
MIDIdef.cc(\basspatplayktrl, {
	if(~basspat.isPlaying.not) {
		~basspat.play(t, quant: 1);
		"basspat play".postln;
	}
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~basspatstopktrl =
MIDIdef.cc(\basspatstopktrl, {
	if(~basspat.isPlaying) {
		~basspat.pause;
		"basspat stop".postln;
	}
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// bees

/*
~beesplay1 = Synth(\sndfileplayer, [\bufnum, ~bees.bufnum, \loop, 1, \vol, 0.2]).register;
~beesplay1.isPlaying;
~beesplay1.release;
*/

/*
~beesplay2 = Synth(\sndfileplayer, [\bufnum, ~bees.bufnum, \loop, 1, \startPos, ~bees.numFrames / 2, \vol, 0.2]).register;
~beesplay2.isPlaying;
~beesplay2.release;
*/

(
~beepat1 =
Pdef(\beepat1,
	Pmono(
		\sndfileplayer,
		\bufnum, ~bees.bufnum,
		\loop, 1,
		\vol, 0.4
));
);

/*
~beepat1.play(t, quant: 1);
~beepat1.isPlaying;
~beepat1.stop;
*/

(
~beepat2 =
Pdef(\beepat2, Pbindf(~beepat1, \startPos, ~bees.numFrames / 2));
);

/*
~beepat2.play(t, quant: 1);
~beepat2.isPlaying;
~beepat2.stop;
*/

~beepar = Pdef(\beepar, Ppar([~beepat1, ~beepat2], inf));

/*
~beepar.play(t, quant: 1);
~beepar.isPlaying;
~beepar.stop;
*/

(
~beeparplayktrl =
MIDIdef.cc(\beeparplayktrl, {
	if(~beepar.isPlaying.not) {
		~beepar.play(t, quant: 1);
		"beepar play".postln;
	}
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~beeparstopktrl =
MIDIdef.cc(\beeparstopktrl, {
	if(~beepar.isPlaying) {
		~beepar.pause;
		"beepar stop".postln;
	}
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

//

(
SynthDef(\bee, { | freq = 400, gate = 1, level = 0.04, lfbnfbmodamp = 0.999 |
	var env				=	Env.asr(0.005, level, 0.8);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var lfnfreqmod		=	LFNoise2.kr(0.1.dup, 0.002, 1);
	var lfbnfbmod		=	LFBrownNoise1.kr(50.dup, mul: lfbnfbmodamp, add: 1);
	var sinfb			=	SinOscFB.ar(freq * lfnfreqmod, lfbnfbmod, envgen);
	var rlpf			=	RLPF.ar(sinfb, freq);
	var rhpf			=	RHPF.ar(sinfb, 8000, 0.1);
	Out.ar(0, sinfb + rlpf + rhpf);
}).add;
);

(
~beedronepat1 =
Pdef(\beedronepat1,
	Pmono(
		\bee,
		\degree, 0,
		\octave, 2,
		\root, ~root2,
		\scale, ~scale
));
);

/*
~beedronepat1.play(t, quant: 1);
~beedronepat1.isPlaying;
~beedronepat1.stop;
*/

(
~beedroneplayktrl =
MIDIdef.cc(\beedroneplayktrl, {
	if(~beedronepat1.isPlaying.not) {
		~beedronepat1.play(t, quant: 1);
		"beedronepat1 play".postln;
	}
}, 67, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~beedronestopktrl =
MIDIdef.cc(\beedronestopktrl, {
	if(~beedronepat1.isPlaying) {
		~beedronepat1.pause;
		"beedronepat1 stop".postln;
	}
}, 67, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

//

(
SynthDef(\pad, { | dur = 1, freq = 400, gate = 1, level = 0.03 |
	var env				=	Env.asr(0.01, level, 1, -16);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var lfnfreqmod		=	LFNoise1.kr(0.1.dup, 0.001, 1);
	var fbmodfreq		=	LFNoise0.kr(1).range(0.1, 100);
	var lfbnfbmod		=	LFBrownNoise0.kr(fbmodfreq.dup).range(0.0, 0.8).round(0.2);
	var lfnampmod		=	LFNoise0.kr(15.dup).range(0.5, 1).round(0.5);
	var sin				=	SinOscFB.ar(freq * lfnfreqmod, lfbnfbmod, mul: envgen * lfnampmod);
	//var rlpf			=	RLPF.ar(sin.round(0.01), freq * 32);
	var rhpf			=	RHPF.ar(sin.round(0.01), 4000, 0.1);
	Out.ar(0, sin.round(0.01) + (rhpf / 2));
}).add;
);

(
~beechordspat1 =
Pdef(\beechordspat1,
	Pbind(
		\instrument, \pad,
		\degree, Pshuf([[7, 10, 12], [7, 12, 13], [7, 12, 14], [7, 12, 15]], inf),
		\dur, 53,
		\legato, 1,
		\lfbnfbmodamp, 0.2,
		\octave, 3,
		\root, ~root2,
		\scale, ~scale
));
);

/*
~beechordspat1.play(t, quant: 1);
~beechordspat1.isPlaying;
~beechordspat1.stop;
*/

~beechordspat2 = Pdef(\beechordspat2, Pbindf(~beechordspat1, \degree, 6, \octave, 4));

/*
~beechordspat2.play(t, quant: 1);
~beechordspat2.isPlaying;
~beechordspat2.stop;
*/

~beechordspat3 = Pdef(\beechordspat3, Pbindf(~beechordspat1, \degree, [7, 10], \octave, 4));

/*
~beechordspat3.play(t, quant: 1);
~beechordspat3.isPlaying;
~beechordspat3.stop;
*/

(
~beechords1playktrl =
MIDIdef.cc(\beechords1playktrl, {
	if(~beechordspat1.isPlaying.not) {
		~beechordspat1.play(t, quant: 1);
		"beechordspat1 play".postln;
	}
}, 36, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~beechords1stopktrl =
MIDIdef.cc(\beechords1stopktrl, {
	if(~beechordspat1.isPlaying) {
		~beechordspat1.pause;
		"beechordspat1 stop".postln;
	}
}, 36, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~beechords2playktrl =
MIDIdef.cc(\beechords2playktrl, {
	if(~beechordspat2.isPlaying.not) {
		~beechordspat2.play(t, quant: 1);
		"beechordspat2 play".postln;
	}
}, 52, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~beechords2stopktrl =
MIDIdef.cc(\beechords2stopktrl, {
	if(~beechordspat2.isPlaying) {
		~beechordspat2.pause;
		"beechordspat2 stop".postln;
	}
}, 52, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~beechords3playktrl =
MIDIdef.cc(\beechords3playktrl, {
	if(~beechordspat3.isPlaying.not) {
		~beechordspat3.play(t, quant: 1);
		"beechordspat3 play".postln;
	}
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~beechords3stopktrl =
MIDIdef.cc(\beechords3stopktrl, {
	if(~beechordspat3.isPlaying) {
		~beechordspat3.pause;
		"beechordspat3 stop".postln;
	}
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0)
);