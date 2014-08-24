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

~jungle.free;
~jungle = Buffer.read(s, ~lmamediadir ++ "/samples/Jarra Schirris - Vang Vieng - Vang Vieng Jungle.aif");
~jungle.bufnum;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// A) CRICKETS

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

/*
Array.geom(7, 0.125, 1.5)
*/

(
~crpat1 = Pdef(\crpat1,
	Pbind(
		\instrument, \sndfileplayer,
		\bufnum, ~filteredcrickets.bufnum,
		\dur, Prand((30..90).round(5), inf),
		\legato, 1,
		\loop, 0,
		\note, Pshuf([0, Rest, Rest], inf),
		\out, [0, 4],
		\rate, Pshuf(Array.geom(7, 0.125, 1.5), inf),
		\startPos, Pwhite(0, ~filteredcrickets.numFrames / 2),
		\vol, 0.05
));
);

/*
~crpat1.play(t, quant: 1);
~crpat1.isPlaying;
~crpat1.stop;
*/

~crpar = Pdef(\crpar, Ppar(Array.fill(6, { ~crpat1 })));

/*
~crpar.play(t, quant: 1);
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
SynthDef(\cricketdelay,{ | decay = 0.1, freq = 100, gate = 1, level = 0.1 |
	var in				=	In.ar(4, 2);
	var env				=	Env.asr(0.1, level, 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var comb			=	CombC.ar(in, 1, [freq, freq * 1.005].reciprocal, decay, envgen);
	Out.ar(0, comb);
}).add;
);

(
~cdpat =
Pdef(\cdpat,
	Pmono(
		\cricketdelay,
		\decay, 3,
		\degree, [0, 7, 12],
		\level, 0.2,
		\octave, 1,
		\root, ~root,
		\scale, ~scale));
);

/*
~cdpat.play(t, quant: 1);
~cdpat.isPlaying;
~cdpat.stop;
*/

(
~cdpatplayktrl =
MIDIdef.cc(\cdpatplayktrl, {
	if(~cdpat.isPlaying.not) {
		~cdpat.play(t, quant: 1);
		"cricket processing play".postln;
	}
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~cdpatstopktrl =
MIDIdef.cc(\cdpatstopktrl, {
	if(~cdpat.isPlaying) {
		~cdpat.pause;
		"cricket processing stop".postln;
	}
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
~drone =
SynthDef(\drone, { | a = 1.1, c = 0.5, fb = 0.1, freq = 440, gate = 1, im = 1, level = 0.02 |
	var env				=	Env.asr(0.01, level, 0.05, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var lfn1			=	LFNoise2.kr(0.1.dup, 0.01, 1);
	var lfn2			=	LFNoise1.kr(0.1.dup, 0.0005, 1);
	var fbsin			=	FBSineC.ar([freq, freq * 1.004] * 8 * lfn1, im, fb, a, c, mul: envgen).round(0.0003);
	var sinfb			=	SinOscFB.ar(freq.dup * lfn2, 0.2, mul: envgen);
	var sin				=	SinOsc.ar(freq, mul: envgen / 4);
	var kbn1			=	LFBrownNoise0.kr(15.dup).range(0, 1).round(1);
	var rhpf1			=	RHPF.ar(fbsin, (freq * 8).clip(50, SampleRate.ir / 3), 0.01, kbn1);
	var kbn2			=	LFBrownNoise0.kr(15.dup).range(0, 1).round(1);
	var rhpf2			=	RHPF.ar(fbsin, (freq * 16).clip(50, SampleRate.ir / 3), 0.01, kbn2);
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
		\degree, Pshuf([[-5, -2], [-5, 0, 1], [-5, 0, 2]], inf),
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
SynthDef(\pno, { | curve = -8, dur = 1, fb = 0, ffreqmult = 8, freq = 400, level = 0.02 |
	var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfbnampmod		=	LFNoise0.kr(15.dup).range(0.75, 1).round(0.25);
	var sin				=	SinOscFB.ar(freq, fb, envgen);
	var lfbn1			=	LFBrownNoise2.ar(10000.dup, mul: envgen * lfbnampmod);
	var rhpf			=	RHPF.ar(lfbn1, (freq * ffreqmult).clip(30, SampleRate.ir / 3), 0.05);
	Out.ar(0, (sin + (rhpf)) * lfbnampmod);
}).add;
);

(
~pnopat1 =
Pdef(\pnopat1,
	Pbind(
		\instrument, \pno,
		\degree, Pshuf([[-5, -2], [-5, 0], [-9, 1], [0, 3], [0, 5]].mirror2, inf),
		\dur, Pshuf([2, 3, 4, 6, 8, 12, 16, 24, 32, 48], inf),
		\fb, Pwhite(0, 0.5, inf),
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
SynthDef(\klk, { | minfreq = 18000, maxfreq = 20000, ffreq = 4000, freq = 1000, bwr = 0.1, a = 1, b = 3, level = 0.1 |
	var env				=	Env.perc(0.003, 0.1, level, -64);
	var envgen			=	EnvGen.ar(env, doneAction: 2);
	var lat				=	Latoocarfian2DN.ar([minfreq, minfreq + 100], [maxfreq, maxfreq + 100], a, b, mul: envgen).wrap2(0.8);
	var flt				=	Resonz.ar(lat, ffreq, 0.05, 4);
	Out.ar(0, flt);
}).add;
);

~pstan = Pstandard(0.9322, 4.95794, 5.487383).asStream;

/*
~pstan.next;
*/

(
~a = [0.2, 0.5, 0.8, 0.9, 1.0, 2.0];
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
		//\dur, 0.25,
		\ffreq, 6000,
		\level, Pshuf([0.25, 0.5, 1].stutter(17) * 0.5, inf),
		\octave, 8,
		\root, ~root,
		\scale, ~scale
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
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3].mirror2, inf),
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
// bass + verb

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

/*
~verb = Synth(\verb).register;
*/

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

(
~verbplayktrl =
MIDIdef.cc(\verbplayktrl, {
	if(~verb.isPlaying.not) {
		~verb = Synth(\verb).register;
		"verb play".postln;
	}
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~verbstopktrl =
MIDIdef.cc(\verbstopktrl, {
	if(~verb.isPlaying) {
		~verb.free;
		"verb stop".postln;
	}
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// B) PART BEE

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
		\dur, Pshuf([7, 9, 11], inf),
		\loop, 1,
		\rate, Pshuf([0.5, 1], inf),
		\vol, 0.2
));
);

/*
~beepat1.play(t, quant: 1);
~beepat1.isPlaying;
~beepat1.stop;
*/

(
~beepat2 =
Pdef(\beepat2, Pbindf(~beepat1, \startPos, ~bees.numFrames / 4));
);

/*
~beepat2.play(t, quant: 1);
~beepat2.isPlaying;
~beepat2.stop;
*/

(
~beepat3 =
Pdef(\beepat3, Pbindf(~beepat1, \startPos, ~bees.numFrames / 2));
);

/*
~beepat3.play(t, quant: 1);
~beepat3.isPlaying;
~beepat3.stop;
*/

(
~beepat4 =
Pdef(\beepat4, Pbindf(~beepat1, \startPos, (~bees.numFrames * 3) / 4));
);

/*
~beepat3.play(t, quant: 1);
~beepat3.isPlaying;
~beepat3.stop;
*/

~beepar = Pdef(\beepar, Ppar([~beepat1, ~beepat2, ~beepat3, ~beepat4], inf));

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
	var env				=	Env.asr(0.05, level, 0.05, 0);
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
		\level, 0.06,
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
SynthDef(\pad, { | a = 1, b = 3, c = 0.5, d = 0.5, dur = 1, freq = 400, freqmodamt = 0.3, gate = 1, level = 0.2 |
	var env				=	Env.asr(0.1, level, 0.1, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var fbmodfreq		=	LFNoise0.kr(1.dup).range(0.1, 15);
	var ampmodfreq		=	LFNoise0.kr(1.dup).range(0.1, 15);
	var lfbnfbmod		=	LFBrownNoise0.kr(fbmodfreq).range(0.2, 0.3).round(0.1);
	var lfnampmod		=	LFNoise0.kr(ampmodfreq).range(0.9, 1.0).round(0.1);
	var sin				=	SinOscFB.ar((freq.dup).clip(50, SampleRate.ir / 3), lfbnfbmod, envgen * lfnampmod).fold2(0.01) * 3;
	var rhpf			=	RHPF.ar(sin.fold2(0.01), (freq * 16).clip(50, SampleRate.ir / 3), 0.3, 0.5);
	Out.ar(0, sin + rhpf);
}).add;
);

(
~bpadmelos =
Pdef(\bpadmelos,
	PmonoArtic(
		\pad,
		\degree, Pshuf([-5, -2, 0, 2, 7].stutter(5), inf),
		\dur, Pshuf([0.25, 0.25, 0.5] ++ (5..9).nthPrime, inf),
		\legato, Prand([0.75, 1.0], inf),
		\octave, 4,
		\root, ~root2,
		\scale, ~scale
));
);

/*
~bpadmelos.play(t, quant: 1);
~bpadmelos.stop;
*/

~bpadcontrapunctus = Pdef(\bpadcontrapunctus, Ppar(Array.fill(2, { ~bpadmelos })));

/*
~bpadcontrapunctus.play(t, quant: 1);
~bpadcontrapunctus.isPlaying;
~bpadcontrapunctus.stop;
*/

~bpaddrone1 = Pdef(\bpaddrone1, Pmono(\pad, \degree, [-5, 0].stutter(2), \octave, 5, \root, ~root2, \scale, ~scale));

/*
~bpaddrone1.play(t, quant: 1);
~bpaddrone1.isPlaying;
~bpaddrone1.stop;
*/

~bpaddrone2 = Pdef(\bpaddrone2, Pmono(\pad, \degree, [0, 2].stutter(2), \octave, 5, \root, ~root2, \scale, ~scale));

/*
~bpaddrone2.play(t, quant: 1);
~bpaddrone2.isPlaying;
~bpaddrone2.stop;
*/

(
~bpadcontrapunctusplayktrl =
MIDIdef.cc(\bpadcontrapunctusplayktrl, {
	if(~bpadcontrapunctus.isPlaying.not) {
		~bpadcontrapunctus.play(t, quant: 1);
		"bpadcontrapunctus play".postln;
	}
}, 36, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~bpadcontrapunctusstopktrl =
MIDIdef.cc(\bpadcontrapunctusstopktrl, {
	if(~bpadcontrapunctus.isPlaying) {
		~bpadcontrapunctus.pause;
		"bpadcontrapunctus stop".postln;
	}
}, 36, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~bpaddrone1playktrl =
MIDIdef.cc(\bpaddrone1playktrl, {
	if(~bpaddrone1.isPlaying.not) {
		~bpaddrone1.play(t, quant: 1);
		"bpaddrone1 play".postln;
	}
}, 52, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~bpaddrone1stopktrl =
MIDIdef.cc(\bpaddrone1stopktrl, {
	if(~bpaddrone1.isPlaying) {
		~bpaddrone1.pause;
		"bpaddrone1 stop".postln;
	}
}, 52, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~bpaddrone2playktrl =
MIDIdef.cc(\bpaddrone2playktrl, {
	if(~bpaddrone2.isPlaying.not) {
		~bpaddrone2.play(t, quant: 1);
		"bpaddrone2 play".postln;
	}
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~bpaddrone2stopktrl =
MIDIdef.cc(\bpaddrone2stopktrl, {
	if(~bpaddrone2.isPlaying) {
		~bpaddrone2.pause;
		"bpaddrone2 stop".postln;
	}
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

/*
(
~padpat =
Pdef(\padpat,
	Pbind(
		\instrument, \pad,
		\a, Pwhite(0.1, 9.0, inf),
		\b, Pwhite(0.1, 11.0, inf),
		\c, Pwhite(0.1, 3.0),
		\d, Pwhite(0.1, 3.0),
		\dur, Pshuf((7..9).nthPrime, inf),
		\octave, 4,
		\root, ~root,
		\scale, ~scale))
);
*/

/*
~padpat.play(t, quant: 1);
~padpat.isPlaying;
~padpat.stop;
*/

//~padpar = Pdef(\padpar, Ppar(Array.fill(8, { ~padpat })));

/*
~padpar.play(t, quant: 1);
~parpar.isPlaying;
~padpar.stop;
*/

/*
~beepadgliss1 = Pdef(\beepadgliss1, Pmono(\pad, \a, 1.1, \octave, 4, \root, ~root2, \scale, ~scale));
~beepadgliss2 = Pdef(\beepadgliss2, Pmono(\pad, \a, 1.3, \octave, 4, \root, ~root2, \scale, ~scale));
~beepadgliss3 = Pdef(\beepadgliss3, Pmono(\pad, \a, 1.5, \octave, 4, \root, ~root2, \scale, ~scale));
~beepadgliss4 = Pdef(\beepadgliss4, Pmono(\pad, \a, 1.7, \octave, 4, \root, ~root2, \scale, ~scale));
~beepadglisspar = Pdef(\beepadglisspar, Ppar([~beepadgliss1, ~beepadgliss2, ~beepadgliss3, ~beepadgliss4], inf));
*/

/*
~beepadglisspar.play(t, quant: 1);
~beepadglisspar.stop;
*/

/*
(
~beechordspat1 =
Pdef(\beechordspat1,
	Pbind(
		\instrument, \pad,
		\degree, Pshuf([[0, 1, 7, 9, 10], [0, 1, 7, 10, 12], [-2, 2, 7, 12, 13], [0, 1, 7, 12, 14], [0, 1, 7, 12, 15]], inf),
		\dur, 53,
		\legato, 1,
		\lfbnfbmodamp, 0.2,
		\octave, 4,
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

*/

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// C) JUNGLE MUSIC

(
~junglepat =
Pdef(\junglepat,
	Pbind(
		\instrument, \sndfileplayer,
		\bufnum, ~jungle.bufnum,
		\dur, Prand((5..9).nthPrime, inf),
		\legato, 1,
		\loop, 1,
		\rate, Pshuf([0.25, 0.5, 1].stutter(7), inf),
		//\startPos, Pshuf(~jungle.numFrames / (2..7), inf),
		\startPos, Pwhite(0, ~jungle.numFrames / 1.1, inf),
		\vol, 0.2
));
);

/*
~junglepat.play(t, quant: 1);
~junglepat.isPlaying;
~junglepat.stop;
*/

~junglepar = Pdef(\junglepar, Ppar(Array.fill(2, { ~junglepat })));

/*
~junglepar.play(t, quant: 1);
~junglepar.isPlaying;
~junglepar.stop;
*/

(
~jungleparplayktrl =
MIDIdef.cc(\jungleparplayktrl, {
	if(~junglepar.isPlaying.not) {
		~junglepar.play(t, quant: 1);
		"junglepar play".postln;
	}
}, 37, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~jungleparstopktrl =
MIDIdef.cc(\jungleparstopktrl, {
	if(~junglepar.isPlaying) {
		~junglepar.pause;
		"junglepar stop".postln;
	}
}, 37, srcID: ~nanoktrl2.uid, argTemplate: 0)
);


//

(
SynthDef(\jungledrone, { | curve = 0, fb = 0.3, dur = 1, freq = 400, gate = 1, level = 0.05 |
	var env				=	Env.asr(0.003, level, 0.3);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var fenv			=	XLine.ar(4, 1, 0.0001);
	var freqmod			=	LFNoise2.kr(15.dup, 0.001, 1);
	//var fbmod			=	LFNoise0.kr(15.dup).range(0, fb);
	var ampmod			=	LFBrownNoise0.kr(11.dup).range(0.5, 1).round(0.5);
	var sin				=	SinOscFB.ar(freq * fenv * freqmod, fb).round(0.11) * (envgen * ampmod);
	var rlpf			=	RHPF.ar(sin, (freq * 8).clip(50, SampleRate.ir / 3), 0.1);
	var sin2			=	SinOscFB.ar(freq.dup, 0.2, envgen);
	Out.ar(0, rlpf + (sin2 / 2));
}).add;
);

(
~jdronepat =
Pdef(\jdronepat,
	Pmono(
		\jungledrone,
		\degree, [-5, 0],
		\fb, 0,
		\octave, 5,
		\root, ~root,
		\scale, ~scale
	));
);

/*
~jdronepat.play(t, quant: 1);
~jdronepat.isPlaying;
~jdronepat.stop;
*/

(
//~jfifthsdegrees = Array.fill(12, { |i| [i, i + 7] });
~jfifthsdegrees = [[0, 7], [0, 5], [2, 7]];
~jlongdurs = ((0..4) + 9).nthPrime;
~jfifthspat =
Pdef(\jfifths,
	Pbind(
		\instrument, \jungledrone,
		\degree, Pshuf(~jfifthsdegrees, inf),
		\dur, Pshuf(~jlongdurs, inf),
		\fb, 0.4,
		\octave, 4,
		\root, ~root,
		\scale, ~scale))
);

/*
~jfifthspat.play(t, quant: 1);
~jfifthspat.isPlaying;
~jfifthspat.stop;
*/

(
~jchords = [[-12, -11, -5, -2], [-5, 0, 1], [-5, 0, 1, 2], [-5, 0, 1, 6], [-5, 0, 1, 8], [-5, 0, 1, 9], [-5, 0, 1, 11]];
~jchordpat =
Pdef(\jchordpat,
	Pbind(
		\instrument, \jungledrone,
		\degree, Pshuf(~jchords, inf),
		\dur, Pshuf(~jlongdurs, inf),
		//\fb, Pseq([0.4, 0.5, 0.6], inf),
		\legato, 0.5,
		\octave, 5,
		\root, ~root,
		\scale, ~scale)
);
);

/*
~jchordpat.play(t, quant: 1);
~jchordpat.isPlaying;
~jchordpat.stop;
*/

(
~jdronepatplayktrl =
MIDIdef.cc(\jdronepatplayktrl, {
	if(~jdronepat.isPlaying.not) {
		~jdronepat.play(t, quant: 1);
		"jdronepat play".postln;
	}
}, 38, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~jdronepatstopktrl =
MIDIdef.cc(\jdronepatstopktrl, {
	if(~jdronepat.isPlaying) {
		~jdronepat.pause;
		"jdronepat stop".postln;
	}
}, 38, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~jfifthspatplayktrl =
MIDIdef.cc(\jfifthspatplayktrl, {
	if(~jfifthspat.isPlaying.not) {
		~jfifthspat.play(t, quant: 1);
		"jfifthspat play".postln;
	}
}, 54, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~jfifthspatstopktrl =
MIDIdef.cc(\jfifthspatstopktrl, {
	if(~jfifthspat.isPlaying) {
		~jfifthspat.pause;
		"jfifthspat stop".postln;
	}
}, 54, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~jchordpatplayktrl =
MIDIdef.cc(\jchordpatplayktrl, {
	if(~jchordpat.isPlaying.not) {
		~jchordpat.play(t, quant: 1);
		"jchordpat play".postln;
	}
}, 70, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~jchordpatstopktrl =
MIDIdef.cc(\jchordpatstopktrl, {
	if(~jchordpat.isPlaying) {
		~jchordpat.pause;
		"jchordpat stop".postln;
	}
}, 70, srcID: ~nanoktrl2.uid, argTemplate: 0)
);


//

(
~jpnopat1 =
Pdef(\jpnopat1,
	Pbind(
		\instrument, \pno,
		\degree, [0, 7],
		\dur, Pseq([0.5, Pshuf([1, 2, 5].stutter(3))], inf),
		\ffreqmult, 16,
		\level, 0.02,
		\root, ~root,
		\scale, ~scale
))
);

/*
~jpnopat1.play(t, quant: 1);
~jpnopat1.isPlaying;
~jpnopat1.stop;
*/

//~jpnopat2 = Pdef(\jpnopat2, Pbindf(~jpnopat1, \degree, 0));

~jpnopar = Pdef(\jpnopar, Ppar([~jpnopat1].stutter(2), inf));

/*
~jpnopar.play(t, quant: 1);
~jpnopar.isPlaying;
~jpnopar.stop;
*/

~jpnopat2 = Pdef(\jpnopat2, Pbindf(~jpnopat1, \degree, 5, \dur, Pshuf([3, 4].stutter(7), inf)));

/*
~jpnopat2.play(t, quant: 1);
~jpnopat2.isPlaying;
~jpnopat2.stop;
*/

(
~jpnoparplayktrl =
MIDIdef.cc(\jpnoparplayktrl, {
	if(~jpnopar.isPlaying.not) {
		~jpnopar.play(t, quant: 1);
		"jpnopar play".postln;
	}
}, 53, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~jpnoparstopktrl =
MIDIdef.cc(\jpnoparstopktrl, {
	if(~jpnopar.isPlaying) {
		~jpnopar.pause;
		"jpnopar stop".postln;
	}
}, 53, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~jpnopat2playktrl =
MIDIdef.cc(\jpnopat2playktrl, {
	if(~jpnopat2.isPlaying.not) {
		~jpnopat2.play(t, quant: 1);
		"jpnopat2 play".postln;
	}
}, 69, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~jpnopat2stopktrl =
MIDIdef.cc(\jpnopat2stopktrl, {
	if(~jpnopat2.isPlaying) {
		~jpnopat2.pause;
		"jpnopat2 stop".postln;
	}
}, 69, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

//

/*
(
SynthDef(\jklk, { | fb = 0, ffreq = 10000, freq = 8000, level = 0.3, pan = 0, rq = 1 |
	var env				=	Env.new([0, level, 0], [0.005, 0.001], \cub);
	var envgen			=	EnvGen.ar(env, doneAction: 2);
	//var fenv			=	XLine.ar(2, 1, 0.02);
	//var fenv			=	LFBrownNoise0.kr((SampleRate.ir / 2).dup, mul: 1, add: 1);
	//var sin				=	SinOscFB.ar(freq * fenv, fb, envgen);
	var bn				=	LFBrownNoise2.ar(freq.dup, mul: envgen);
	var rlpf			=	RLPF.ar(bn, ffreq, rq);
	var pan2			=	Pan2.ar(rlpf, pan);
	Out.ar(0, pan2);
}).add;
);
*/

(
SynthDef(\jklik, { |a = 1, b = 1.9, freq = 200, hpfreq = 1000, level = 0.2, lpfreq = 1000|
	var env				=	Env.perc(0.005, 0.3, level, -64);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq.dup, a, b, mul: envgen);
	var rhpf			=	RHPF.ar(cusp, hpfreq, 0.4);
	var imp				=	Impulse.ar(0.dup, mul: 0.5);
	var rlpf			=	RLPF.ar(imp, lpfreq, 0.4);
	Out.ar(0, rhpf + rlpf);
}).add;
);

(
~jklkpat1 =
Pdef(\jklkpat,
	Pbind(
		\instrument, \jklik,
		\a, Pshuf(1 + ((1..5) / 5), inf),
		\b, Pshuf(2 + ((1..7) / 7), inf),
		\dur, Pshuf([0.5, 1.5, 2, 3, 4].stutter(3), inf),
		\freq, 200,
		\hpfreq, 100,
		\level, Pshuf([0.1, 1].stutter(2) * 0.2, inf),
));
);

/*
~jklkpat1.play(t, quant: 1);
~jklkpat1.isPlaying;
~jklkpat1.stop;
*/

//~jklkpat2 = Pdef(\jklkpat2, Pbindf(~jklkpat1, \ffreq, 6000, \octave, 7, \rq, 0.1));

~jklkpat2 = Pdef(\jklkpat2, Pbindf(~jklkpat1, \freq, 8000, \hpfreq, 4000, \lpfreq, 4000));

/*
~jklkpat2.play(t, quant: 1);
~jklkpat2.isPlaying;
~jklkpat2.stop;
*/

~jklkpar = Pdef(\jklkpar, Ptpar([0, ~jklkpat1, 2, ~jklkpat2],  inf));

/*
~jklkpar.play(t, quant: 1);
~jklkpar.isPlaying;
~jklkpar.stop;
*/

//

(
SynthDef(\jhat, { |ffreq = 4000, level = 0.2, pan = 0|
	var env				=	Env.perc(0.003, 1, level, 0);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var imp				=	Blip.ar(0.01, 5000, mul: envgen);
	var rhpf			=	RHPF.ar(imp, ffreq.clip(50, SampleRate.ir / 3), 0.05);
	var pan2			=	Pan2.ar(rhpf, pan);
	Out.ar(0, pan2);
}).add;
);

(
~jhatpat1 =
Pdef(\jhatpat1,
	Pbind(
		\instrument, \jhat,
		// \dur, Pseq([
		// 	1, 1, 1.5,
		// 	1, 1, 1, 1.5,
		// 	1, 1, 1, 1, 1.5
		// ], inf),
		\dur, Pshuf([1, 1, 1, 1.5, 2].stutter(5), inf),
		\ffreq, Pshuf([4000, 4000, 8000].stutter(7), inf),
		\lag, Pwhite(-0.01, 0.01, inf),
		\level, Pshuf([0.1, 1, 1].stutter(5) * 0.2, inf),
		\pan, -1
));
);

/*
~jhatpat1.play(t, quant: 1);
~jhatpat1.isPlaying;
~jhatpat1.stop;
*/

(
~jhatpat2 =
Pdef(\jhatpat2,
	Pbindf(
		~jhatpat1,
		//\ffreq, 8000,
		\pan, 1
));
);

/*
~jhatpat2.play(t, quant: 1);
~jhatpat2.isPlaying;
~jhatpat2.stop;
*/

(
~jhatpat3 =
Pdef(\jhatpat3,
	Pbindf(
		~jhatpat1,
		//\degree, Pshuf([Rest, 0].stutter(17), inf),
		//\dur, Pshuf([0.25, 0.75].stutter(17), inf),
		\dur, 0.25,
		\ffreq, 12000,
		\lag, 0,
		\level, Pseq(((0..109) / 2000).mirror2, inf),
		\pan, Pseq(((((0..53) / 53) * 2) - 1).mirror2, inf)
));
);

/*
~jhatpat3.play(t, quant: 1);
~jhatpat3.isPlaying;
~jhatpat3.stop;
*/

~jhatpar = Pdef(\jhatpar, Ppar([~jhatpat1, ~jhatpat2], inf));

/*
~jhatpar.play(t, quant: 1);
~jhatpar.isPlaying;
~jhatpar.stop;
*/

(
~jklkparplayktrl =
MIDIdef.cc(\jklkparplayktrl, {
	if(~jklkpar.isPlaying.not) {
		~jklkpar.play(t, quant: 1);
		"jklkpar play".postln;
	}
}, 39, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~jklkparstopktrl =
MIDIdef.cc(\jklkparstopktrl, {
	if(~jklkpar.isPlaying) {
		~jklkpar.pause;
		"jpnopar stop".postln;
	}
}, 39, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~jhatparplayktrl =
MIDIdef.cc(\jhatparplayktrl, {
	if(~jhatpar.isPlaying.not) {
		~jhatpar.play(t, quant: 1);
		"jhatpar play".postln;
	}
}, 55, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~jhatparstopktrl =
MIDIdef.cc(\jhatparstopktrl, {
	if(~jhatpar.isPlaying) {
		~jhatpar.pause;
		"jhatpar stop".postln;
	}
}, 55, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

(
~jhatpat3playktrl =
MIDIdef.cc(\jhatpat3playktrl, {
	if(~jhatpat3.isPlaying.not) {
		~jhatpat3.play(t, quant: 1);
		"jhatpat3 play".postln;
	}
}, 45, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~jhatpat3stopktrl =
MIDIdef.cc(\jhatpat3stopktrl, {
	if(~jhatpat3.isPlaying) {
		~jhatpat3.pause;
		"jhatpat3 stop".postln;
	}
}, 45, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

//

(
SynthDef(\gbman, { |fb = 0, freq = 400, gbmaxf = 22050, gbminf = 11025, level = 0.2, x = 1.2, y = 2.1|
	var env				=	Env.perc(0.005, 1, level, -64);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var gbman			=	Gbman2DC.ar(gbminf, gbmaxf, x, y, 0.99, 1);
	var sin				=	FBSineC.ar(freq.dup * gbman * 8, fb: fb, mul: envgen);
	var rhpf			=	RHPF.ar(sin, freq * 4, 0.3);
	Out.ar(0, rhpf);
}).add;
);

(
~gbpat =
Pdef(\gbpat,
	Pbind(
		\instrument, \gbman,
		\fb, 0.9,
		\freq, 100,
		\gbminf, Pwhite(50.0, 100.0, inf),
		\gbmaxf, Pwhite(1000, 2000, inf),
		\x, Pwhite(1.0, 2.0, inf),
		\y, Pwhite(2.0, 3.0, inf)
));
);

/*
~gbpat.play(t, quant: 1);
~gbpat.stop;
*/

(
~bumppat =
Pdef(\bumppat,
	Pbind(
		\instrument, \bass,
		\degree, Pseq([[-2, 0], Rest], inf),
		\dur, Pseq([2, 5.5, 2, 7.5, 2, 9.5], inf),
		\octave, [2, 3],
		\root, ~root,
		\scale, ~scale));
);

/*
~bumppat.play(t, quant: 1);
~bumppat.isPlaying;
~bumppat.pause;
*/

(
~bumpplayktrl =
MIDIdef.cc(\bumpplayktrl, {
	if(~bumppat.isPlaying.not) {
		~bumppat.play(t, quant: 1);
		"bump play".postln;
	}
}, 71, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~bumpstopktrl =
MIDIdef.cc(\bumpstopktrl, {
	if(~bumppat.isPlaying) {
		~bumppat.pause;
		"bump stop".postln;
	}
}, 71, srcID: ~nanoktrl2.uid, argTemplate: 0)
);