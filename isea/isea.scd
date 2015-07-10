t = TempoClock(90/60);

////////////////////////////////////////////////////////////////

~sndfilepath = "/run/media/phil/LMA Aug Sho/ISEA";

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

~ringzbus1 = Bus.audio(s, 2);
~ringzbus2 = Bus.audio(s, 2);

////////////////////////////////////////////////////////////////

(
SynthDef(\ringz, { |freq = 440, decaytime = 0.1, gate = 1, inbus = 0, level = 0.01, outbus = 0|
    var env             =   Env.asr(0.01, level, 1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var ringz           =   Ringz.ar(in, freq!2, decaytime, envgen);
    Out.ar(outbus, ringz);
}).add;
);

(
Pdef(\ringzpat,
    Pmono(
        \ringz,
        \decaytime, 1,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24], inf),
        \note, Pshuf([[-5, -2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12], [7, 10, 12, 19]], inf),
        \inbus, ~ringzbus1,
        \root, -2
));
);

/*
Pdef(\ringzpat).play(t, quant: 1);
Pdef(\ringzpat).isPlaying;
Pdef(\ringzpat).stop;
*/

Pdef(\ringzlo, Pbindf(Pdef(\ringzpat), \decaytime, 1, \level, 0.005, \note, 0, \octave, 3));

/*
Pdef(\ringzlo).play(t, quant: 1);
Pdef(\ringzlo).isPlaying;
Pdef(\ringzlo).stop;
*/

(
Pdef(\ringzhi,
    Pmono(
        \ringz,
        \decaytime, 2,
        \dur, Pshuf([31, 37, 41, 43, 47], inf),
        \inbus, ~ringzbus2,
        \level, 0.01,
        \note, Pshuf([-2, 0, 2, 7], inf),
        \octave, 7,
        \root, -2
));
Pdef(\ringzhi2, Pbindf(Pdef(\ringzhi)));
Pdef(\ringzhi3, Pbindf(Pdef(\ringzhi)));
Pdef(\ringzhipar, Ppar([Pdef(\ringzhi), Pdef(\ringzhi2), Pdef(\ringzhi3)]));
);

/*
Pdef(\ringzhipar).play(t, quant: 1);
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

Pdef(\falls01pat, Pmono(\sfplay, \bufnum, ~metalduct.bufnum, \loop, 1, \outbus, [0, ~ringzbus2], \vol, 0.05));

/*
Pdef(\falls01pat).play(t, quant: 1);
Pdef(\falls01pat).isPlaying;
Pdef(\falls01pat).stop;
*/

//

(
Pdef(\trafficprc,
    Pbind(
        \instrument, \sfplay,
        \bufnum, ~traffic.bufnum,
        \curve, Pshuf([-64, -32, -16, -8, -4], inf),
        \dur, Pshuf([Pseq([0.125], 2), 0.25, Pseq([0.25], 2), 0.5, 0.75].stutter(3), inf),
        //\dur, 0.25,
        \legato, 0.05,
        \loop, 1,
        \outbus, [0, ~ringzbus1],
        \rate, Pshuf([0.25, 0.5, 1, 1, 1, 1.5, 2, 3, 4, 6, 8, 12, 16], inf),
        \release, 0.5,
        //\startPos, Pwhite(0.0, ~traffic.numFrames, inf),
        \startPos, Pshuf(((1..11) / 11) * ~traffic.numFrames, inf),
        \vol, 0.3
));
Pdef(\trafficprcecho, Pbindf(Pdef(\trafficprc), \dur, 0.25, \vol, 0.06));
);

/*
Pdef(\trafficprc).play(t, quant: 1);
Pdef(\trafficprc).isPlaying;
Pdef(\trafficprc).stop;
*/

/*
Pdef(\trafficprcecho).play(t, quant: 1);
Pdef(\trafficprcecho).isPlaying;
Pdef(\trafficprcecho).stop;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\sinprc, { |curve = -4, fb = 0.1, freq = 440, im = 1, level = 0.1, pan = 0|
    var env             =   Env.perc(0.005, 1, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var fbsin           =   FBSineC.ar(freq, im, fb, mul: envgen);
    var pan2            =   Pan2.ar(fbsin, pan);
    Out.ar(0, pan2);
}).add;
);

(
Pdef(\sinprc1,
    Pbind(
        \instrument, \sinprc,
        \curve, Prand([-64, -32, -16], inf),
        \dur, Prand([0.25, 0.5, 0.75, 1], inf),
        \fb, Pshuf((7..20) / 5, inf),
        \level, Prand([0.3, 1] * 0.1, inf),
        \octave, Prand((6..12), inf),
        \pan, Prand([-1, -0.5, 0, 0.5, 1], inf),
        \root, -2
));

Pdef(\sinprc2, Pbindf(Pdef(\sinprc1)));

Pdef(\sinprc3,
    Pbind(
        \instrument, \sinprc,
        \curve, Prand([-256, -128, -64, -32, -16, -8, -4], inf),
        \dur, 0.25,
        \fb, Pwhite(0.1, 4.0, inf),
        \level, 0.01,
        \octave, 12,
        \root, -2
));
);

/*
Pdef(\sinprc1).play(t, quant: 1);
Pdef(\sinprc1).isPlaying;
Pdef(\sinprc1).stop;
*/

/*
Pdef(\sinprc2).play(t, quant: 1);
Pdef(\sinprc2).isPlaying;
Pdef(\sinprc2).stop;
*/

/*
Pdef(\sinprc3).play(t, quant: 1);
Pdef(\sinprc3).isPlaying;
Pdef(\sinprc3).stop;
*/