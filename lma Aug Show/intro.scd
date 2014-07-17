//midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
//~nanoktrl2 = 1310720;
~nanoktrl2 = 1572864;

s.meter;
s.scope;

//~patterndegrees1 = [-2, -1, 1, 2, 7];
~tuning = Tuning.just;
~scale = Scale.new(#[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], 12, ~tuning);
~root = 3;

t = TempoClock(140/60);

////////////////////////////////////////////////////////////////

~lmamediadir = "/media/lma";

(
~filteredcrickets.free;
~jungle.free;
);

(
~filteredcrickets = Buffer.read(s, ~lmamediadir ++ "/samples/FilteredCrickets01.wav");
~jungle = Buffer.read(s, ~lmamediadir ++ "/samples/Jarra Schirris - Vang Vieng - Vang Vieng Jungle.aif");
);

(
SynthDef(\sndfileplayer, { | bufnum, gate = 1, loop = 0, rate = 1, vol = 0 |
	var env			 	=	Env.asr(0.003, vol, 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2); // free enclosing group
	var playbuf			=	PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum) * rate, loop: loop, doneAction: 2) * envgen;
	Out.ar([0, 2], playbuf);
}).add
);

/*
~filteredcricketsplay = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 1, \vol, 0.1]).register;
~filteredcricketsplay.isPlaying;
~filteredcricketsplay.release;
*/

/*
~filteredcricketsplay_up5th = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 1.5, \vol, 0.1]).register;
~filteredcricketsplay_up5th.isPlaying;
~filteredcricketsplay_up5th.release;
*/

/*
~filteredcricketsplay_upoct = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 2, \vol, 0.1]).register;
~filteredcricketsplay_upoct.isPlaying;
~filteredcricketsplay_upoct.release;
*/

/*
~jungleplay = Synth(\sndfileplayer, [\bufnum, ~jungle.bufnum, \loop, 1, \vol, 0.2]).register;
~jungleplay.isPlaying;
~jungleplay.release;
*/


(
~crickets1playktrl =
MIDIdef.cc(\cricketc1playktrl, {
	if(~filteredcricketsplay.isPlaying.not) {
		~filteredcricketsplay = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \vol, 0.1]).register;
		"crickets play".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~cricketc1stopktrl =
MIDIdef.cc(\cricketc1stopktrl, {
	if(~filteredcricketsplay.isPlaying) {
		~filteredcricketsplay.release;
		"crickets stop".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~crickets2playktrl =
MIDIdef.cc(\cricketc2playktrl, {
	if(~filteredcricketsplay_up5th.isPlaying.not) {
		~filteredcricketsplay_up5th = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 1.5, \vol, 0.1]).register;
		"crickets up 5th play".postln;
	}
}, 48, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~cricketc2stopktrl =
MIDIdef.cc(\cricketc2stopktrl, {
	if(~filteredcricketsplay_up5th.isPlaying) {
		~filteredcricketsplay_up5th.release;
		"crickets up 5th stop".postln;
	}
}, 48, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~crickets3playktrl =
MIDIdef.cc(\cricketc3playktrl, {
	if(~filteredcricketsplay_upoct.isPlaying.not) {
		~filteredcricketsplay_upoct = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 2, \vol, 0.1]).register;
		"crickets up oct play".postln;
	}
}, 64, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~cricketc3stopktrl =
MIDIdef.cc(\cricketc3stopktrl, {
	if(~filteredcricketsplay_upoct.isPlaying) {
		~filteredcricketsplay_upoct.release;
		"crickets up oct stop".postln;
	}
}, 64, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////

(
SynthDef(\drone, { | a = 1.1, c = 0.5, fb = 0.1, freq = 440, gate = 1, im = 1, level = 0.02 |
	var env				=	Env.asr(0.01, level, 0.1, 0);
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

(
~dronepat1playktrl =
MIDIdef.cc(\dronepat1playktrl, {
	if(~dronepat1.isPlaying.not) {
		~dronepat1.play(t, quant: 1);
		"dronepat1 play".postln;
	}
}, 33, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~dronepat1stopktrl =
MIDIdef.cc(\dronepat1stopktrl, {
	if(~dronepat1.isPlaying) {
		~dronepat1.pause;
		"dronepat1 stop".postln;
	}
}, 33, srcID: ~nanoktrl2, argTemplate: 0)
);

(
~dronepat2playktrl =
MIDIdef.cc(\dronepat2playktrl, {
	if(~dronepat2.isPlaying.not) {
		~dronepat2.play(t, quant: 1);
		"dronepat2 play".postln;
	}
}, 49, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~dronepat2stopktrl =
MIDIdef.cc(\dronepat2stopktrl, {
	if(~dronepat2.isPlaying) {
		~dronepat2.pause;
		"dronepat2 stop".postln;
	}
}, 49, srcID: ~nanoktrl2, argTemplate: 0)
);

////////////////////////////////////////////////////////////////////////
// clicks

(
SynthDef(\klk, { | minfreq = 18000, maxfreq = 20000, ffreq = 4000, bwr = 0.1, a = 1, level = 0.1 |
	var env				=	Env.perc(0.003, 0.0001, level, -64);
	var envgen			=	EnvGen.ar(env, doneAction: 2);
	//var blit			=	BlitB3.ar(0.dup, envgen);
	var lat				=	Latoocarfian2DC.ar([minfreq, minfreq + 100], [maxfreq, maxfreq + 100], a, mul: envgen);
	var flt				=	Resonz.ar(lat, ffreq, bwr);
	Out.ar(0, flt);
}).add;
);

~pstan = Pstandard.new.asStream;

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
		\level, 0.5,
))
);

/*
~klkpat.play(t, quant: 1);
~klkpat.isPlaying;
~klkpat.stop;
*/

(
~kikpat =
Pdef(\kikpat,
	Pbind(
		\instrument, \klk,
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6], inf),
		\minfreq, 1000,
		\maxfreq, 10000,
		\ffreq, 200,
		\level, 0.8,
))
);

/*
~kikpat.play(t, quant: 1);
~kikpat.isPlaying;
~kikpat.stop;
*/

(
~prcpat =
Pdef(\prcpat,
	Pbind(
		\instrument, \klk,
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].mirror2, inf),
		\ffreq, 2000,
		\bwr, 0.3,
		\level, Pxrand([0.5, 0.75, 1] * 0.3, inf),
))
);

/*
~prcpat.play(t, quant: 1);
~prcpat.isPlaying;
~prcpat.stop;
*/