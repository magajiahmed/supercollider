~tempo = TempoClock(90/60);

////////////////////////////////////////////////////////////////
// SOURCE SOUNDS. You may need lots of RAM to load them all!

(
~arrayOfBuffers = "/run/media/phil/LMA Aug Sho/ISEA/*".pathMatch.collect { |file| Buffer.read(s, file) };
);

////////////////////////////////////////////////////////////////
// BUS DEPOT

(
~ringzbus1 = Bus.audio(s, 2);
~ringzbus2 = Bus.audio(s, 2);
);

////////////////////////////////////////////////////////////////
// RECORDING

s.prepareForRecord;
/*
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////////////
// RESONATOR: SYNTH

(
SynthDef(\ringz, { |freq = 440, decaytime = 0.1, gate = 1, inbus = 0, level = 0.01, outbus = 0|
    var env             =   Env.asr(0.01, level, 1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var ringz           =   Ringz.ar(in, freq!2, decaytime, envgen);
    Out.ar(outbus, ringz);
}).add;
);

// RESONATOR: PATTERNS

(
~ringzchords = [[-5, -2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]];
~ringzdurs = Array.fill(7, { |i| (i + 11).nthPrime });
Pdef(\ringz1,
    Pmono(
        \ringz,
        \dur, Pshuf(~ringzdurs, inf),
        \decaytime, 0.5,
        \inbus, ~ringzbus1,
        \note, Pshuf(~ringzchords, inf)
));
);

/*
Pdef(\ringz1).play(~tempo, quant: 1);
Pdef(\ringz1).isPlaying;
Pdef(\ringz1).stop;
*/

(
Pdef(\ringz2,
    Pbind(
        \instrument, \ringz,
        \decaytime, 0.5,
        \dur, 30,
        \inbus, ~ringzbus2,
        \note, Pshuf(~ringzchords, inf),
        \octave, 7
));
);

/*
Pdef(\ringz2).play(~tempo, quant: 1);
Pdef(\ringz2).isPlaying;
Pdef(\ringz2).stop;
*/

////////////////////////////////////////////////////////////////
// SOUNDFILE PLAYER: SYNTH

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

// SOUNDFILE PLAYER: PATTERNS

(
Pdef(\sfplay1,
    Pbind(
        \instrument, \sfplay,
        \bufnum, Pshuf((0..(~arrayOfBuffers.size - 1)), inf),
        \dur, Pshuf([0.01, 0.1, 1, 10], inf),
        \legato, 1,
        \loop, 1,
        \outbus, Prand([~ringzbus1, ~ringzbus2, [0, ~ringzbus1], [0, ~ringzbus2]], inf),
        \startPos, Pwhite(0.0, 1000000.0, inf),
        \vol, 0.1,
));
Pdef(\sfplay2, Pbindf(Pdef(\sfplay1)));
Pdef(\sfplay3, Pbindf(Pdef(\sfplay1)));
);

/*
Pdef(\sfplay1).play(~tempo, quant: 1);
Pdef(\sfplay1).isPlaying;
Pdef(\sfplay1).stop;
*/

/*
Pdef(\sfplay2).play(~tempo, quant: 1);
Pdef(\sfplay2).isPlaying;
Pdef(\sfplay2).stop;
*/

/*
Pdef(\sfplay3).play(~tempo, quant: 1);
Pdef(\sfplay3).isPlaying;
Pdef(\sfplay3).stop;
*/

////////////////////////////////////////////////////////////////
// DRONE

(
SynthDef(\sin, { |fb = 0.1, freq = 440, gate = 1, im = 1, level = 0.1, outbus = 0|
    var env             =   Env.asr(0.1, level);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var freqmod         =   LFNoise2.kr(0.1!4, 0.001, 1);
    var sin1            =   FBSineC.ar((freq - 0.3) * freqmod[0, 1], [im, im - 0.01], fb, mul: envgen);
    var sin2            =   FBSineC.ar((freq + 0.3) * freqmod[2, 3], [im + 0.01, im - 0.02], fb, mul: envgen);
    var sin3            =   FBSineC.ar(freq!2, im, fb, mul: envgen);
    Out.ar(outbus, sin1 + sin2 + sin3);
}).add;
);

(
Pdef(\sin1,
    Pbind(
        \instrument, \sin,
        \dur, Pshuf(~ringzdurs, inf),
        \fb, Pshuf((1..11) / 10, inf),
        \im, Pshuf([1, 2], inf),
        \legato, 0.25,
        \level, 0.005,
        \note, Pshuf(~ringzchords, inf),
        \octave, [5, 6, 7],
));
Pdef(\sin2, Pbindf(Pdef(\sin1)));
Pdef(\sin3, Pbindf(Pdef(\sin1)));
);

/*
Pdef(\sin1).play(~tempo, quant: 1);
Pdef(\sin1).isPlaying;
Pdef(\sin1).stop;
*/

/*
Pdef(\sin2).play(~tempo, quant: 1);
Pdef(\sin2).isPlaying;
Pdef(\sin2).stop;
*/

/*
Pdef(\sin3).play(~tempo, quant: 1);
Pdef(\sin3).isPlaying;
Pdef(\sin3).stop;
*/