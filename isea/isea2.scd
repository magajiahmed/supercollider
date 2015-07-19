///////////////////////////////////////////////////////////////
// SOURCE SOUNDS. You may need lots of RAM to load them all!

(
~arrayOfBuffers = "/run/media/phil/LMA Aug Sho/ISEA/*".pathMatch.sort.collect { |file| Buffer.read(s, file) };
);

////////////////////////////////////////////////////////////////
// MIDI

(
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.noteOn(\midipostln, { |...args| args.postln; });
~lp = MIDIClient.sources.detect{ |a| a.name.contains("Launchpad")};
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~lp.isNil) { ~lp = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
m = MIDIOut(0);
m.connect(~lp.uid);
);

////////////////////////////////////////////////////////////////
// INIT

s.scope;

// TIME

~tempo = TempoClock(80/60);

// BUS DEPOT

(
~ringzbus1 = Bus.audio(s, 2);
~ringzbus2 = Bus.audio(s, 2);
~ringzbus3 = Bus.audio(s, 2);
~rhpfbus = Bus.audio(s, 2);
~rezbus = Bus.audio(s, 2);
~verbus = Bus.audio(s, 2);
~dfmbus = Bus.audio(s, 2);
);

/////////////////////////////////////////////////////////////////
// RECORDING

s.prepareForRecord;
/*
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////////////
// LAUNCHPAD MINI COLOR CODES

(
~green   =  48; // for buttons which trigger patterns with environmental sounds
~orange  =  19; // for effects buses
~red     =  3;  // for buttons which trigger patterns of synthetic sounds
~yellow  =  51; // for alternate effects buses
);

////////////////////////////////////////////////////////////////
// RINGZ: SYNTH

(
SynthDef(\ringz, { |freq = 440, decaytime = 0.1, gate = 1, inbus = 0, level = 0.01, outbus = 0|
    var env             =   Env.asr(0.01, level, 1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var ringz           =   Ringz.ar(in, freq!2, decaytime, envgen);
    Out.ar(outbus, ringz);
}).add;
);

// RINGZ: PATTERNS

(
~ringzchords = [[-5, -2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]];
~ringzdurs = Array.fill(7, { |i| (i + 11).nthPrime });
Pdef(\ringz1,
    Pmono(
        \ringz,
        \dur, Pshuf(~ringzdurs, inf),
        \decaytime, 0.2,
        \inbus, ~ringzbus1,
        \note, Pshuf(~ringzchords, inf)
));
);

Pdef(\ringz1).play(~tempo, quant: 1);
m.noteOn(0, 64, ~orange);
/*
Pdef(\ringz1).isPlaying;
Pdef(\ringz1).stop;
*/

// RINGZ: MIDI CONTROL

(
MIDIdef.noteOn(\ringz1, {
    if(Pdef(\ringz1).isPlaying.not) {
        Pdef(\ringz1).play(~tempo, quant: 1);
        m.noteOn(0, 64, ~orange);
        "ringz1 play".postln;
    } {
        Pdef(\ringz1).stop;
        m.noteOn(0, 64, 0);
        "ringz1 stop".postln;
    };
}, 64, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// RESONANT HIGH-PASS FILTER: SYNTH

(
SynthDef(\rhpf, { |freq = 440, gate = 1, inbus = 0, level = 0.1, outbus = 0, rq = 1|
    var env             =   Env.asr(0.1, level);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var rhpf            =   RHPF.ar(in, (freq.clip(50, SampleRate.ir / 3))!2, rq);
    Out.ar(0, rhpf);
}).add;
);

// RHPF: PATTERN

(
Pdef(\rhpf,
    Pmono(
        \rhpf,
        \dur, Pshuf(~ringzdurs, inf),
        \inbus, ~rhpfbus,
        \level, 0.005,
        \note, Pshuf([0, 2, 7, 10].powerset.reject({ |i| i.isEmpty }), inf),
        \octave, 9,
        \rq, 0.2
));
);

Pdef(\rhpf).play(~tempo, quant: 1);
m.noteOn(0, 65, ~yellow);
/*
Pdef(\rhpf).isPlaying;
Pdef(\rhpf).stop;
*/

// RHPF: MIDI CONTROL

(
MIDIdef.noteOn(\rhpf, {
    if(Pdef(\rhpf).isPlaying.not) {
        Pdef(\rhpf).play(~tempo, quant: 1);
        m.noteOn(0, 65, ~yellow);
        "rhpf play".postln;
    } {
        Pdef(\rhpf).stop;
        m.noteOn(0, 65, 0);
        "rhpf stop".postln;
    }
}, 65, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// KARPLUS-STRONG WAVEGUIDE RESONATOR: SYNTH

(
SynthDef(\rez, { |decaytime = 0.1, freq = 440, gate = 1, inbus = 0, level = 0.1, outbus = 0, res = 0.9|
    var env             =   Env.asr(0.01, level);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var comb            =   CombC.ar(in, 1, freq.reciprocal, decaytime);
    var rlpf            =   BLowPass4.ar(comb, freq * 8, 0.3);
    Out.ar(outbus, rlpf);
}).add;
);

// RESONATOR: PATTERN

(
Pdef(\rez,
    Pmono(
        \rez,
        \decaytime, 0.08,
        \dur, Pshuf(~ringzdurs, inf),
        \inbus, ~rezbus,
        \level, 0.001,
        \note, Pshuf(~ringzchords, inf),
        //\octave, 4
));
);

Pdef(\rez).play(~tempo, quant: 1);
m.noteOn(0, 66, ~orange);
/*
Pdef(\rez).isPlaying;
Pdef(\rez).stop;
*/

// RESONATOR: MIDI CONTROL

(
MIDIdef.noteOn(\rez, {
    if(Pdef(\rez).isPlaying.not) {
        Pdef(\rez).play(~tempo, quant: 1);
        m.noteOn(0, 66, ~orange);
        "rez play".postln;
    } {
        Pdef(\rez).stop;
        m.noteOn(0, 66, 0);
        "rez stop".postln;
    }
}, 66, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// VERB: SYNTH

(
SynthDef(\verb, { |gate = 1, inbus = 0, level = 0.2, outbus = 0|
    var env             =   Env.asr(0.01, level, 5);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var dampmod         =   LFBrownNoise2.kr(5!2).range(0.0, 1.0).round(0.5);
    var ampmod          =   LFClipNoise.kr(15!2).range(0.1, 1);
    var verb            =   GVerb.ar(in, 7, 10, dampmod, drylevel: 0, mul: envgen * ampmod);
    Out.ar(outbus, verb);
}).add;
);

Pdef(\verb, Pmono(\verb, \inbus, ~verbus));

Pdef(\verb).play(~tempo, quant: 1);
m.noteOn(0, 67, ~yellow);
/*
Pdef(\verb).isPlaying;
Pdef(\verb).stop;
*/

(
MIDIdef.noteOn(\verb, {
    if(Pdef(\verb).isPlaying.not) {
        Pdef(\verb).play(~tempo, quant: 1);
        m.noteOn(0, 67, ~yellow);
        "verb play".postln;
    } {
        Pdef(\verb).stop;
        m.noteOn(0, 67, 0);
        "verb stop".postln;
    }
}, 67, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// DFM1

(
SynthDef(\dfm1, { |freq = 1000, gate = 1, inbus = 0, level = 0.1, outbus = 0, type = 0|
    var env             =   Env.asr(0.1, level, 5);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var dfm             =   DFM1.ar(in, freq.clip(100, 10000), 0.997, 1, type.clip(0, 1).round(1), 0, envgen);
    Out.ar(outbus, dfm).fold2(level);
}).add;
);

(
Pdef(\dfm1,
    PmonoArtic(
        \dfm1,
        \dur, Pshuf(~ringzdurs / 4, inf),
        \inbus, ~dfmbus,
        \legato, 0.999,
        \note, Pshuf(~ringzchords, inf),
        \octave, [4, 5],
        \type, Prand([0, 1], inf)
));
);

Pdef(\dfm1).play(~tempo, quant: 1);
m.noteOn(0, 68, ~orange);
/*
Pdef(\dfm1).isPlaying;
Pdef(\dfm1).stop;
*/

(
MIDIdef.noteOn(\dfm1, {
    if(Pdef(\dfm1).isPlaying.not) {
        Pdef(\dfm1).play(~tempo, quant: 1);
        m.noteOn(0, 68, ~orange);
        "dfm1 play".postln;
    } {
        Pdef(\dfm1).stop;
        m.noteOn(0, 68, 0);
        "dfm1 stop".postln;
    }
}, 68, srcID: ~lp.uid);
);

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
        \dur, Pshuf([0.5, 0.75, 16, 24, 32, 48, 64, 96], inf),
        \legato, 1,
        \loop, 1,
        \outbus, Prand([0, ~rhpfbus, [0, ~ringzbus1]], inf),
        \startPos, Pwhite(0, 1000000, inf),
        \vol, 0.1,
));
Pdef(\sfplay2, Pbindf(Pdef(\sfplay1)));
Pdef(\sfplay3, Pbindf(Pdef(\sfplay1)));
Pdef(\sfplay4, Pbindf(Pdef(\sfplay1)));
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

/*
Pdef(\sfplay4).play(~tempo, quant: 1);
Pdef(\sfplay4).isPlaying;
Pdef(\sfplay4).stop;
*/

// SOUNDFILE PLAYER: MIDI CONTROL

(
MIDIdef.noteOn(\sfplay1, {
    if(Pdef(\sfplay1).isPlaying.not) {
        Pdef(\sfplay1).play(~tempo, quant: 1);
        m.noteOn(0, 0, ~green);
        "sfplay1 play".postln;
    } {
        Pdef(\sfplay1).stop;
        m.noteOn(0, 0, 0);
        "sfplay1 stop".postln;
    }
}, 0, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sfplay2, {
    if(Pdef(\sfplay2).isPlaying.not) {
        Pdef(\sfplay2).play(~tempo, quant: 1);
        m.noteOn(0, 1, ~green);
        "sfplay2 play".postln;
    } {
        Pdef(\sfplay2).stop;
        m.noteOn(0, 1, 0);
        "sfplay2 stop".postln;
    }
}, 1, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sfplay3, {
    if(Pdef(\sfplay3).isPlaying.not) {
        Pdef(\sfplay3).play(~tempo, quant: 1);
        m.noteOn(0, 2, ~green);
        "sfplay3 play".postln;
    } {
        Pdef(\sfplay3).stop;
        m.noteOn(0, 2, 0);
        "sfplay3 stop".postln;
    }
}, 2, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sfplay4, {
    if(Pdef(\sfplay4).isPlaying.not) {
        Pdef(\sfplay4).play(~tempo, quant: 1);
        m.noteOn(0, 3, ~green);
        "sfplay4 play".postln;
    } {
        Pdef(\sfplay4).stop;
        m.noteOn(0, 3, 0);
        "sfplay4 stop".postln;
    }
}, 3, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// DRONE: SYNTH

(
SynthDef(\sin, { |fb = 0.1, freq = 440, gate = 1, im = 1, level = 0.01, outbus = 0|
    var env             =   Env.asr(0.1, level);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin1            =   FBSineC.ar(freq, [im, im - 0.01], fb, mul: envgen);
    var leakdc          =   LeakDC.ar(sin1);
    var rhpf            =   BHiPass4.ar(leakdc, (freq).clip(50, SampleRate.ir / 3), 0.03);
    var sin2            =   SinOscFB.ar(freq / 8, 0.2, envgen);
    Out.ar(outbus, rhpf + sin2);
}).add;
);

// DRONE: PATTERNS

(
Pdef(\sin1,
    Pbind(
        \instrument, \sin,
        \dur, Pshuf(~ringzdurs, inf),
        \fb, Pshuf((1..11) / 10, inf),
        \im, Pshuf((11..17) / 10, inf),
        \legato, 0.25,
        \note, Pshuf(~ringzchords, inf),
        \octave, Pshuf([6, 7, 8].powerset.reject({ |i| i.isEmpty }), inf),
));
Pdef(\sin2, Pbindf(Pdef(\sin1)));
Pdef(\sin3, Pbindf(Pdef(\sin1)));
Pdef(\sinbass, Pbindf(Pdef(\sin1), \level, 0.02, \note, Pshuf([-2, 0, 2, 7], inf), \octave, [4, 5, 6]));
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

/*
Pdef(\sinbass).play(~tempo, quant: 1);
Pdef(\sinbass).isPlaying;
Pdef(\sinbass).stop;
*/

(
MIDIdef.noteOn(\sin1, {
    if(Pdef(\sin1).isPlaying.not) {
        Pdef(\sin1).play(~tempo, quant: 1);
        m.noteOn(0, 16, ~red);
        "sin1 play".postln;
    } {
        Pdef(\sin1).stop;
        m.noteOn(0, 16, 0);
        "sin1 stop".postln;
    }
}, 16, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sin2, {
    if(Pdef(\sin2).isPlaying.not) {
        Pdef(\sin2).play(~tempo, quant: 1);
        m.noteOn(0, 17, ~red);
        "sin2 play".postln;
    } {
        Pdef(\sin2).stop;
        m.noteOn(0, 17, 0);
        "sin2 stop".postln;
    }
}, 17, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sin3, {
    if(Pdef(\sin3).isPlaying.not) {
        Pdef(\sin3).play(~tempo, quant: 1);
        m.noteOn(0, 18, ~red);
        "sin3 play".postln;
    } {
        Pdef(\sin3).stop;
        m.noteOn(0, 18, 0);
        "sin3 stop".postln;
    }
}, 18, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sinbass, {
    if(Pdef(\sinbass).isPlaying.not) {
        Pdef(\sinbass).play(~tempo, quant: 1);
        m.noteOn(0, 19, ~red);
        "sinbass play".postln;
    } {
        Pdef(\sinbass).stop;
        m.noteOn(0, 19, 0);
        "sinbass stop".postln;
    }
}, 19, srcID: ~lp.uid);
);
////////////////////////////////////////////////////////////////
// SINPRC: SYNTH

(
SynthDef(\sinprc, { |curve = -4, fb = 0.1, freq = 440, im = 1, level = 0.1, outbus = 0, pan = 0|
    var env             =   Env.perc(0.005, 1, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var fbsin           =   FBSineC.ar(freq, im, fb, mul: envgen);
    var pan2            =   Pan2.ar(fbsin, pan);
    Out.ar(outbus, pan2).fold2(level);
}).add;
);

// SINPRC: PATTERNS

(
Pdef(\sinprc1,
    Pbind(
        \instrument, \sinprc,
        \curve, -32,
        //\dur, Pshuf([0.25, Pseq([1/6], 3), Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, Pseq([0.25], 3), 1], inf),
        \dur, Pshuf([Pseq([1/6], 3), Pshuf([Pseq([0.125], 2), 0.5, 0.75, 1, 1.5].stutter(3))], inf),
        \fb, Pshuf((7..20) / 5, inf),
        \level, Prand([0.2, 1] * 0.1, inf),
        \note, [-2, 0, 2, 7],
        \octave, Pshuf([5, 6, 8, 9], inf),
        \outbus, Prand([0, [0, ~ringzbus3], [0, ~verbus]], inf),
        \pan, Pshuf([-1, 0, 1], inf),
));

Pdef(\sinprc2, Pbindf(Pdef(\sinprc1)));

Pdef(\sinprc3,
    Pbind(
        \instrument, \sinprc,
        \curve, Pshuf([-256, -128, -64].stutter(3), inf),
        \dur, Pshuf([Pshuf([0.25, 0.5, 0.75].stutter(11)), Pseq([1/6], 3), Pseq([9, 1, 1, 1] / 12)], inf),
        \fb, Pshuf([0.1, 0.2, 0.4, 0.8, 1.6, 3.2], inf),
        \level, 0.02,
        \note, Pshuf([2, 7, 10, 12].powerset.reject({ |i| i.isEmpty }), inf),
        \octave, 12,
        \outbus, Prand([0, [0, ~verbus]], inf)
));
);

/*
Pdef(\sinprc1).play(~tempo, quant: 1);
Pdef(\sinprc1).isPlaying;
Pdef(\sinprc1).stop;
*/

/*
Pdef(\sinprc2).play(~tempo, quant: 1);
Pdef(\sinprc2).isPlaying;
Pdef(\sinprc2).stop;
*/

/*
Pdef(\sinprc3).play(~tempo, quant: 1);
Pdef(\sinprc3).isPlaying;
Pdef(\sinprc3).stop;
*/

// SINPRC: MIDI CONTROL

(
MIDIdef.noteOn(\sinprc1, {
    if(Pdef(\sinprc1).isPlaying.not) {
        Pdef(\sinprc1).play(~tempo, quant: 1);
        m.noteOn(0, 32, ~red);
        "sinprc1 play".postln;
    } {
        Pdef(\sinprc1).stop;
        m.noteOn(0, 32, 0);
        "sinprc1 stop".postln;
    };
}, 32, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sinprc2, {
    if(Pdef(\sinprc2).isPlaying.not) {
        Pdef(\sinprc2).play(~tempo, quant: 1);
        m.noteOn(0, 33, ~red);
        "sinprc2 play".postln;
    } {
        Pdef(\sinprc2).stop;
        m.noteOn(0, 33, 0);
        "sinprc2 stop".postln;
    };
}, 33, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sinprc3, {
    if(Pdef(\sinprc3).isPlaying.not) {
        Pdef(\sinprc3).play(~tempo, quant: 1);
        m.noteOn(0, 34, ~red);
        "sinprc3 play".postln;
    } {
        Pdef(\sinprc3).stop;
        m.noteOn(0, 34, 0);
        "sinprc3 stop".postln;
    };
}, 34, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// LATPRC: SYNTH

(
SynthDef(\latprc, { |a = 1, curve = 0, envlength = 0.3, freq = 4000, level = 0.1, outbus|
    var env             =   Env.perc(0.01, envlength, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var lat             =   LatoocarfianC.ar(a: [a, a - 0.001], mul: envgen);
    //var rlpf            =   RLPF.ar(lat, freq.clip(50, SampleRate.ir / 2.5), 0.3);
    Out.ar(outbus, lat);
}).add;
);

// LATPRC: PATTERN

(
~latprcdurs = [0.75, 0.75, 1, 0.75, 0.75, 0.75, 1, 0.75, 0.75, 0.75, 0.75, 1, 6];
Pdef(\latprc1,
    Pbind(
        \instrument, \latprc,
        //\a, Pshuf(Array.series(13, -3, pi / 6.4), inf),
        \a, Pshuf((-3..2) + 0.5, inf),
        \curve, -32,
        \dur, Pseq(~latprcdurs, inf),
        \envlength, Pshuf([0.2, 0.4, 0.8], inf),
        //\octave, Pshuf([4, 11], inf)
        \outbus, Prand([0, ~dfmbus, [0, ~dfmbus]], inf)
));

Pdef(\latprc2, Pbindf(Pdef(\latprc1), \dur, Pshuf(~latprcdurs, inf), \level, 0.02));
Pdef(\latprcs, Ppar([Pdef(\latprc1), Pdef(\latprc2), Pdef(\latprc2)], inf));
);

/*
Pdef(\latprcs).play(~tempo, quant: 1);
Pdef(\latprcs).isPlaying;
Pdef(\latprcs).stop;
*/

// LATPRC: MIDI CONTROL

(
MIDIdef.noteOn(\latprc, {
    if(Pdef(\latprcs).isPlaying.not) {
        Pdef(\latprcs).play(~tempo, quant: 1);
        m.noteOn(0, 35, ~red);
        "latprc play".postln;
    } {
        Pdef(\latprcs).stop;
        m.noteOn(0, 35, 0);
        "latprc stop".postln;
    };
}, 35, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// SOUNDFILE STUTTER: PATTERN

(
Pdef(\sfstut,
    Pbind(
        \instrument, \sfplay,
        \attack, 0.003,
        \bufnum, Prand([1, 6, 7, 8], inf),
        \curve, 0,
        \decaytime, 1,
        \dur, Prand([0.25, 0.5, 0.75], inf),
        \legato, 0.4,
        \loop, 1,
        \note, Pseq([Pseq([0], 300), Pseq([Rest], 100)], inf),
        \outbus, [~rezbus],
        \release, 0.3,
        \startPos, Pwhite(0, 1000000, inf),
        \vol, 0.03
));
);

/*
Pdef(\sfstut).play(~tempo, quant: 1);
Pdef(\sfstut).isPlaying;
Pdef(\sfstut).stop;
*/

// SOUNDFILE STUTTER: MIDI CONTROL:

(
MIDIdef.noteOn(\sfstut, {
    if(Pdef(\sfstut).isPlaying.not) {
        Pdef(\sfstut).play(~tempo, quant: 1);
        m.noteOn(0, 4, ~green);
        "sfstuts play".postln;
    } {
        Pdef(\sfstut).stop;
        m.noteOn(0, 4, 0);
        "sfstuts stop".postln;
    }
}, 4, srcID: ~lp.uid);
);