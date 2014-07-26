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

(
~filteredcrickets.free;
~jungle.free;
);

(
~filteredcrickets = Buffer.read(s, ~lmamediadir ++ "/samples/FilteredCrickets01.wav");
~bees = Buffer.read(s, ~lmamediadir ++ "/samples/1693.Dmitry_Urupin.Solovetsky_Islands.Bumblebees_and_bees.aif");
);

/*
~filteredcrickets.numFrames;
*/

(
SynthDef(\sndfileplayer, { | bufnum, gate = 1, loop = 0, rate = 1, startPos = 0, vol = 0 |
	var env			 	=	Env.asr(1, vol, 1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var playbuf			=	PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum) * rate, startPos: startPos, loop: loop, doneAction: 2) * envgen;
	Out.ar(0, playbuf);
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
		\dur, Pwhite(30.0, 40.0, inf),
		\legato, 1,
		\loop, 0,
		\note, Pwrand([0, Rest], [2, 1].normalizeSum, inf),
		\rate, Pshuf((1..7) / 5, inf),
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

/*
(
~crickets1playktrl =
MIDIdef.cc(\cricketc1playktrl, {
	if(~filteredcricketsplay.isPlaying.not) {
		~filteredcricketsplay = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \vol, 0.1]).register;
		"crickets play".postln;
	}
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~cricketc1stopktrl =
MIDIdef.cc(\cricketc1stopktrl, {
	if(~filteredcricketsplay.isPlaying) {
		~filteredcricketsplay.release;
		"crickets stop".postln;
	}
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~crickets2playktrl =
MIDIdef.cc(\cricketc2playktrl, {
	if(~filteredcricketsplay_up5th.isPlaying.not) {
		~filteredcricketsplay_up5th = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 1.5, \vol, 0.1]).register;
		"crickets up 5th play".postln;
	}
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~cricketc2stopktrl =
MIDIdef.cc(\cricketc2stopktrl, {
	if(~filteredcricketsplay_up5th.isPlaying) {
		~filteredcricketsplay_up5th.release;
		"crickets up 5th stop".postln;
	}
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~crickets3playktrl =
MIDIdef.cc(\cricketc3playktrl, {
	if(~filteredcricketsplay_upoct.isPlaying.not) {
		~filteredcricketsplay_upoct = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 2, \vol, 0.1]).register;
		"crickets up oct play".postln;
	}
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~cricketc3stopktrl =
MIDIdef.cc(\cricketc3stopktrl, {
	if(~filteredcricketsplay_upoct.isPlaying) {
		~filteredcricketsplay_upoct.release;
		"crickets up oct stop".postln;
	}
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0)
);
*/

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
	var lfbnampmod		=	LFNoise0.kr(15.dup).range(0.25, 1).round(0.25);
	var sin				=	SinOscFB.ar(freq, 0.4, envgen);
	var lfbn1			=	LFBrownNoise2.ar(8000.dup, mul: envgen);
	var rhpf			=	RHPF.ar(lfbn1, 7000, 0.01);
	Out.ar(0, (sin + (rhpf)) * lfbnampmod);
}).add;
);

(
~pnopat1 =
Pdef(\pnopat1,
	Pbind(
		\instrument, \pno,
		\degree, Pshuf([[-5, -2], [-9, 1], [0, 3], [0, 5]].mirror2, inf),
		\dur, Pwhite(3, 37, inf).round(0.25),
		\octave, 6,
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
SynthDef(\klk, { | minfreq = 18000, maxfreq = 20000, ffreq = 4000, bwr = 0.5, a = 1, b = 3, level = 0.1 |
	var env				=	Env.perc(0.003, 0.05, level, -64);
	var envgen			=	EnvGen.ar(env, doneAction: 2);
	var lat				=	Latoocarfian2DC.ar([minfreq, minfreq + 100], [maxfreq, maxfreq + 100], a, b, mul: envgen).fold(-0.5, 0.5);
	var flt				=	Resonz.ar(lat, ffreq, bwr);
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
		//\dur, Pxrand([0.25, 0.5, 0.75], inf),
		\dur, Pswitch1(~durations, q),
		\ffreq, Pwhite(5000, 6000, inf),
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

//

(
SynthDef(\bee, { | freq = 400, gate = 1, level = 0.03, lfbnfbmodamp = 0.99 |
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
	//var rhpf			=	RHPF.ar(sin.round(0.01), 4000, 0.05);
	Out.ar(0, sin.round(0.005));
}).add;
);

(
~beechordspat1 =
Pdef(\beechordspat1,
	Pbind(
		\instrument, \pad,
		\degree, Pshuf([[7, 10], [7, 12], [7, 13], [7, 14], [7, 15]], inf),
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

//

(
SynthDef(\beeano, {
	| a = 1, b = 3, c = 0.5, d = 0.5, dur = 1, startfreq = 0.5, freq = 400, level = 0.1 |
	var env				=	Env.perc(0.005, dur, level, -4);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var xline			=	Line.ar(startfreq, 1, 5);
	var sin				=	SinOscFB.ar([freq, freq * 1.001] * xline, 0.1, mul: envgen);
	var rhpf			=	RHPF.ar(sin.round(0.005), 4000, 0.1);
	Out.ar(0, rhpf);
}).add;
);

(
~glisses = [Rest, [1, 9/10], [1, 16/15], Rest, [1, 9/8], [1, 6/5]];
~beeanopat1 =
Pdef(\beeanopat1,
	Pbind(
		\instrument, \beeano,
		//\degree, Pshuf([0, 1, 2, 3, 7].mirror2, inf),
		\dur, Pshuf([
			7,
			9,
			11
		], inf),
		\octave, 6,
		\root, ~root,
		\scale, ~scale,
		\startfreq, Pshuf(~glisses, inf),
));
);

/*
~beeanopat1.play(t, quant: 1);
~beeanopat1.isPlaying;
~beeanopat1.stop;
*/