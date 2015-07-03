~tempo = TempoClock(90/60);

////////////////////////////////////////////////////////////////

~sndfilepath = "/run/media/phil/LMA Aug Sho/ISEA"

~falls01.free;
~falls01 = Buffer.read(s, ~sndfilepath ++ "/falls01.wav");
~falls01.bufnum;

~metalduct.free;
~metalduct = Buffer.read(s, ~sndfilepath ++ "/metalDuctNearLake.wav");
~metalduct.bufnum;

~traffic.free;
~traffic = Buffer.read(s, ~sndfilepath ++ "/traffic01.wav");
~traffic.bufnum;

////////////////////////////////////////////////////////////////

~ringzbus = Bus.audio(s, 2);
~ringzbus2 = Bus.audio(s, 2);

////////////////////////////////////////////////////////////////

(
SynthDef(\ringz, { |freq = 440, decaytime = 0.1, gate = 1, inbus = 0, level = 0.05, outbus = 0|
    var env             =   Env.asr(0.01, level, 1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var ringz           =   Ringz.ar(in, freq!2, decaytime, envgen);
    Out.ar(outbus, ringz);
}).add;
)

/*
r = Synth(\ringz, [\inbus, ~ringzbus]).register;
r.isPlaying;
r.release;
*/

(
Pdef(\ringzpat,
    Pmono(
        \ringz,
        \decaytime, 1,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
        \note, Pshuf([[-5, -2, 0], [-2, 0, 7], [0, 7, 10], [7, 12, 14], [12, 14, 19]], inf),
        \inbus, ~ringzbus,
        \root, -2
));
);

/*
Pdef(\ringzpat).play(~tempo, quant: 1);
Pdef(\ringzpat).isPlaying;
Pdef(\ringzpat).stop;
*/

(
Pdef(\ringzhi,
    Pmono(
        \ringz,
        \decaytime, 2,
        \dur, Pshuf([31, 37, 41, 43, 47], inf),
        \inbus, ~ringzbus2,
        \note, Pshuf([-2, 0, 7], inf),
        \octave, 7,
        \root, -2
));
Pdef(\ringzhi2, Pbindf(Pdef(\ringzhi)));
Pdef(\ringzhipar, Ppar([Pdef(\ringzhi), Pdef(\ringzhi2)]));
);

/*
Pdef(\ringzhipar).play(~tempo, quant: 1);
Pdef(\ringzhipar).isPlaying;
Pdef(\ringzhipar).stop;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\sfplay, { |attack = 0.01, bufnum, curve = 0, gate = 1, loop = 0, outbus = 0, rate = 1, release = 0.01, startPos = 0, vol = 0|
	var env			 	=	Env.asr(attack, vol, release, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var playbuf			=	PlayBuf.ar(
		2, bufnum, BufRateScale.kr(bufnum) * rate, startPos: startPos, loop: loop, doneAction: 2
	) * envgen;
	Out.ar(outbus, playbuf);
}).add
);

/*
f = Synth(\sndfileplayer, [\bufnum, ~falls01.bufnum, \loop, 1, \outbus, [~ringzbus, \vol, 0.1]);
f.isPlaying;
f.release;
*/

Pdef(\falls01pat, Pmono(\sfplay, \bufnum, ~metalduct.bufnum, \loop, 1, \outbus, [0, ~ringzbus, ~ringzbus2], \vol, 0.02));

/*
Pdef(\falls01pat).play(~tempo, quant: 1);
Pdef(\falls01pat).isPlaying;
Pdef(\falls01pat).stop;
*/

(
Pdef(\falls01prc,
    Pbind(
        \instrument, \sfplay,
        \bufnum, ~traffic.bufnum,
        \curve, -16,
        \dur, Prand([0.25, 0.5, 0.75], inf),
        \legato, 0.01,
        \loop, 1,
        \outbus, [0, ~ringzbus],
        \rate, Prand([0.1, 1, 10, 20, 40], inf),
        \release, 0.5,
        \startPos, Pwhite(0.0, ~falls01.numFrames, inf),
        \vol, 0.2
));
Pdef(\falls01prcecho, Pbindf(Pdef(\falls01prc), \dur, 0.25, \vol, 0.03));
);

/*
Pdef(\falls01prc).play(~tempo, quant: 1);
Pdef(\falls01prc).isPlaying;
Pdef(\falls01prc).stop;
*/

/*
Pdef(\falls01prcecho).play(~tempo, quant: 1);
Pdef(\falls01prcecho).isPlaying;
Pdef(\falls01prcecho).stop;
*/