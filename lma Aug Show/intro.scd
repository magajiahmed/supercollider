s.meter;
s.scope;

//~patterndegrees1 = [-2, -1, 1, 2, 7];
~tuning = Tuning.just;
~scale = Scale.new(#[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], 12, ~tuning);
~root = 3;

////////////////////////////////////////////////////////////////

(
~filteredcrickets.free;
);

(
~filteredcrickets = Buffer.read(s, "/media/lma/samples/FilteredCrickets01.wav");
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
~dronepat1.play;
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
~dronepat2.play;
~dronepat2.isPlaying;
~dronepat2.stop;
*/