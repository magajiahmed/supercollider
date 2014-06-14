s.meter;
s.scope;

//~patterndegrees1 = [-2, -1, 1, 2, 7];
~tuning = Tuning.just;
~scale = Scale.new(#[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], 12, ~tuning);
~root = -7;

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
	var envgen			=	EnvGen.kr(env, gate, doneAction: 14); // free enclosing group
	var playbuf			=	PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum) * rate, loop: loop, doneAction: 2) * envgen;
	Out.ar([0, 2], playbuf);
}).add
);

/*
~filteredcricketsplay = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 1, \vol, 0.1]).register;
~filteredcricketsplay.isPlaying;
~filteredcricketsplay.free;
*/

/*
~filteredcricketsplay_up5th = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 1.5, \vol, 0.1]).register;
~filteredcricketsplay_up5th.isPlaying;
~filteredcricketsplay_up5th.free;
*/

/*
~filteredcricketsplay_upoct = Synth(\sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, 2, \vol, 0.1]).register;
~filteredcricketsplay_upoct.isPlaying;
~filteredcricketsplay_upoct.free;
*/

(
~createCricketGroup = { | rates = #[1, 1.5, 2] |
	~cricketGroup = Group(s).register;
	rates.do({|i|
		Synth.tail(~cricketGroup, \sndfileplayer, [\bufnum, ~filteredcrickets.bufnum, \loop, 1, \rate, i, \vol, 0.1]);
	});
};
);

/*
~createCricketGroup.value;
~cricketGroup.isPlaying;
~cricketGroup.release;
~cricketGroup = nil;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\drone, { | a = 1.1, c = 0.5, fb = 0.1, freq = 440, gate = 1, im = 1, level = 0.02 |
	var env				=	Env.asr(0.01, level, 0.1, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	//var lfn1			=	LFNoise2.kr(0.05.dup, 0.03, 1);
	//var lfn2			=	LFNoise2.kr(0.1.dup, 0.003, 1);
	var fbsin			=	FBSineC.ar([freq, freq * 1.004] * 8, im, fb, a, c, mul: envgen).round(0.0005);
	var sinfb			=	SinOscFB.ar([freq, freq], 0.99, mul: envgen);
	var rhpf			=	RHPF.ar(fbsin, freq * 16, 0.03);
	var rlpf			=	BLowPass4.ar(sinfb, freq * 3, 0.3);
	Out.ar(0, rlpf + (rhpf * 12));
}).add
);

/*
~drone1 = Synth(\drone, [\freq, \440]).register;
~drone1.isPlaying;
~drone1.release;
*/

/*
~drone2 = Synth(\drone, [\freq, 660]).register;
~drone2.isPlaying;
~drone2.release;
*/

~dronepat1 = Pdef(\dronepat1, Pmono(\drone, \degree, [0, 19, 24], \octave, 3, \root, ~root, \scale, ~scale));

/*
~dronepat1.play;
~dronepat1.stop;
*/

(
~dronepat2 =
Pdef(\dronepat2,
	Pbind(
		\instrument, \drone,
		\degree, Pshuf([-2, -1, 1, 2, 7], inf),
		\dur, 30,
		\octave, 5,
		\root, ~root,
		\scale, ~scale,
));
);

/*
~dronepat2.play;
~dronepat2.stop;
*/

////////////////////////////////////////////////////////////////

