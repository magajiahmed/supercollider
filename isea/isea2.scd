///////////////////////////////////////////////////////////////
// SOURCE SOUNDS. You may need lots of RAM to load them all!

(
~arrayOfBuffers = "/run/media/phil/LMA Aug Sho/ISEA/*".pathMatch.collect {
    |f| Buffer.read(s, f, action: { |b| [b.path, b.duration].postln })
};
);

////////////////////////////////////////////////////////////////
// MIDI

(
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
n.free;
c = MIDIdef.cc(\postcc, { |...args| args.postln; });
n = MIDIdef.noteOn(\postnoteon, { |...args| args.postln; });
~lp = MIDIClient.sources.detect{ |s| s.name.contains("Launchpad")};
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~lp.isNil) { ~lp = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
m = MIDIOut(0);
m.connect(~lp.uid);
);

////////////////////////////////////////////////////////////////
// PITCH LOGIC

(
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 128/81, 12/7, 7/4, 243/128];
//~ratios = [1/1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 16/9, 15/8];
~tuning = Tuning.new(~ratios.collect({ |i| i.ratiomidi }));
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
~chord = [-2, 0, 2, 7];
~chords = [[-5, -2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]];
);

// TIME

(
~tempo = TempoClock(80/60);
~durs = Array.fill(7, { |i| (i + 8).nthPrime });
~quickdurs = [Pseq([0.125], 37), 11, Pseq([0.125], 41), 13, Pseq([0.125], 43), 15];
);

// BUS DEPOT

(
~ringzbus1 = Bus.audio(s, 2);
~ringzbus2 = Bus.audio(s, 2);
~ringzbus3 = Bus.audio(s, 2);
~ringzbus4 = Bus.audio(s, 2);
~rezbus1 = Bus.audio(s, 2);
~rezbus2 = Bus.audio(s, 2);
~rezbus3 = Bus.audio(s, 2);
~verbus1 = Bus.audio(s, 2);
~dfmbus1 = Bus.audio(s, 2);
~dfmbus2 = Bus.audio(s, 2);
~dfmbus3 = Bus.audio(s, 2);
~dfmbus4 = Bus.audio(s, 2);
~rhpfbus1 = Bus.audio(s, 2);
~rhpfbus2 = Bus.audio(s, 2);
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
SynthDef(\ringz, { |freq = 440, decaytime = 0.1, gate = 1, inbus = 0, level = 0.02, outbus = 0|
    var env             =   Env.asr(0.01, level, 1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var ringz           =   Ringz.ar(in, freq!2, decaytime, envgen);
    Out.ar(outbus, ringz);
}).add;
);

// RINGZ: PATTERNS

(
Pdef(\ringz1,
    Pmono(
        \ringz,
        \decaytime, 0.5,
        \degree, Pshuf(~chords, inf),
        \dur, Pshuf(~durs, inf),
        \inbus, ~ringzbus1,
        \octave, 5,
        \scale, ~scale
));

Pdef(\ringz2, Pbindf(Pdef(\ringz1), \inbus, ~ringzbus2, \octave, 6));

Pdef(\ringz3, Pbindf(Pdef(\ringz1), \inbus, ~ringzbus3, \octave, 7));

Pdef(\ringz4,
    Pbindf(
        Pdef(\ringz1),
        \inbus, ~ringzbus4,
        \octave, Pshuf([5, 6, 7].powerset.reject { |o| o.isEmpty }, inf)
));
);


Pdef(\ringz1).play(~tempo, quant: 0.5);
m.control(0, 104, ~orange);
/*
Pdef(\ringz1).isPlaying;
Pdef(\ringz1).stop;
*/

Pdef(\ringz2).play(~tempo, quant: 0.5);
m.control(0, 105, ~yellow);
/*
Pdef(\ringz2).isPlaying;
Pdef(\ringz2).stop;
*/

Pdef(\ringz3).play(~tempo, quant: 0.5);
m.control(0, 106, ~orange);
/*
Pdef(\ringz3).isPlaying;
Pdef(\ringz3).stop;
*/

Pdef(\ringz4).play(~tempo, quant: 0.5);
m.control(0, 107, ~yellow);
/*
Pdef(\ringz4).isPlaying;
Pdef(\ringz4).stop;
*/

// RINGZ: MIDI CONTROL

(
MIDIdef.cc(\ringz1, {
    if(Pdef(\ringz1).isPlaying.not) {
        Pdef(\ringz1).play(~tempo, quant: 0.5);
        m.control(0, 104, ~orange);
        "ringz1 play".postln;
    } {
        Pdef(\ringz1).stop;
        m.control(0, 104, 0);
        "ringz1 stop".postln;
    };
}, 104, srcID: ~lp.uid, argTemplate: { |a| a > 0 });
);

(
MIDIdef.cc(\ringz2, {
    if(Pdef(\ringz2).isPlaying.not) {
        Pdef(\ringz2).play(~tempo, quant: 0.5);
        m.control(0, 105, ~yellow);
        "ringz2 play".postln;
    } {
        Pdef(\ringz2).stop;
        m.control(0, 105, 0);
        "ringz2 stop".postln;
    };
}, 105, srcID: ~lp.uid, argTemplate: { |a| a > 0 });
);

(
MIDIdef.cc(\ringz3, {
    if(Pdef(\ringz3).isPlaying.not) {
        Pdef(\ringz3).play(~tempo, quant: 0.5);
        m.control(0, 106, ~orange);
        "ringz3 play".postln;
    } {
        Pdef(\ringz3).stop;
        m.control(0, 106, 0);
        "ringz3 stop".postln;
    };
}, 106, srcID: ~lp.uid, argTemplate: { |a| a > 0 });
);

(
MIDIdef.cc(\ringz4, {
    if(Pdef(\ringz4).isPlaying.not) {
        Pdef(\ringz4).play(~tempo, quant: 0.5);
        m.control(0, 107, ~orange);
        "ringz4 play".postln;
    } {
        Pdef(\ringz4).stop;
        m.control(0, 107, 0);
        "ringz4 stop".postln;
    };
}, 107, srcID: ~lp.uid, argTemplate: { |a| a > 0 });
);

////////////////////////////////////////////////////////////////
// COMB FILTER RESONATOR: SYNTH

(
SynthDef(\rez, { |decaytime = 0.1, freq = 440, gate = 1, inbus = 0, level = 0.1, outbus = 0, res = 0.9|
    var env             =   Env.asr(0.01, level);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var comb            =   CombC.ar(in, 1, freq.reciprocal, decaytime);
    Out.ar(outbus, comb.softclip);
}).add;
);

// RESONATOR: PATTERN

(
Pdef(\rez1,
    Pmono(
        \rez,
        \decaytime, 0.2,
        \dur, Pshuf(~durs, inf),
        \inbus, ~rezbus1,
        \degree, Pshuf(~chords, inf),
        \octave, 4,
        \scale, ~scale
));

Pdef(\rez2,
    Pmono(
        \rez,
        \decaytime, 0.2,
        \dur, Pshuf(~durs, inf),
        \inbus, ~rezbus2,
        \degree, Pshuf(~chords, inf),
        \octave, 5,
        \scale, ~scale
));

Pdef(\rez3,
    Pmono(
        \rez,
        \decaytime, 0.2,
        \dur, Pshuf(~durs, inf),
        \inbus, ~rezbus3,
        \degree, Pshuf(~chords, inf),
        \octave, [4, 5],
        \scale, ~scale
));

Pdef(\rez, Ppar([Pdef(\rez1), Pdef(\rez2), Pdef(\rez3)], inf));
);

Pdef(\rez).play(~tempo, quant: 0.5);
m.control(0, 108, ~orange);
/*
Pdef(\rez).isPlaying;
Pdef(\rez).stop;
*/

// RESONATOR: MIDI CONTROL

(
MIDIdef.cc(\rez, {
    if(Pdef(\rez).isPlaying.not) {
        Pdef(\rez).play(~tempo, quant: 0.5);
        m.control(0, 108, ~orange);
        "rez play".postln;
    } {
        Pdef(\rez).stop;
        m.control(0, 108, 0);
        "rez stop".postln;
    }
}, 108, srcID: ~lp.uid, argTemplate: { |a| a > 0 });
);

////////////////////////////////////////////////////////////////
// VERB: SYNTH

(
SynthDef(\verb, { |ampmodmin = 0.3, ampmodmax = 1, dampmodfreq = 7, gate = 1, inbus = 0, level = 0.2, outbus = 0|
    var env             =   Env.asr(0.01, level, 5);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var dampmod         =   LFBrownNoise2.kr(dampmodfreq!2).range(0.0, 1.0).round(0.25);
    var ampmod          =   LFClipNoise.kr(15!2).range(ampmodmin, ampmodmax);
    var verb            =   GVerb.ar(in, 7, 20, dampmod, drylevel: 0, mul: envgen * ampmod);
    Out.ar(outbus, verb);
}).add;
);

// VERB: PATTERN

Pdef(\verb1, Pmono(\verb, \inbus, ~verbus1));

Pdef(\verb1).play(~tempo, quant: 0.5);
m.control(0, 109, ~yellow);
/*
Pdef(\verb1).isPlaying;
Pdef(\verb1).stop;
*/

// VERB: MIDI CONTROL

(
MIDIdef.cc(\verb, {
    if(Pdef(\verb).isPlaying.not) {
        Pdef(\verb).play(~tempo, quant: 0.5);
        m.control(0, 109, ~yellow);
        "verb play".postln;
    } {
        Pdef(\verb).stop;
        m.control(0, 109, 0);
        "verb stop".postln;
    }
}, 109, srcID: ~lp.uid, argTemplate: { |a| a > 0 });
);

////////////////////////////////////////////////////////////////
// SELF-OSCILLATING RESONANT FILTER: SYNTH

(
SynthDef(\dfm, { |freq = 1000, gate = 1, inbus = 0, level = 0.1, outbus = 0, res = 0, type = 0|
    var env             =   Env.asr(0.1, level, 3);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var dfm             =   DFM1.ar(in, freq.clip(30, 12000), res, 1, type.clip(0, 1).round(1), 0, envgen);
    Out.ar(outbus, dfm).fold2(level);
}).add;
);

// SELF-OSCILLATING RESONANT FILTER: PATTERNS

(
Pdef(\dfm1,
    PmonoArtic(
        \dfm,
        \dur, Pshuf(~durs, inf),
        \inbus, ~dfmbus1,
        \legato, 0.999,
        \level, 0.1,
        \degree, Pshuf(~chords, inf),
        \octave, 7,
        \res, 0.999,
        \scale, ~scale
));

Pdef(\dfm2, Pbindf(Pdef(\dfm1), \inbus, ~dfmbus2));

/*
Pdef(\dfm3,
    Pbindf(
        Pdef(\dfm1),
        \inbus, ~dfmbus3,
        \level, 0.2,
        \octave, [3, 3, 4],
        \res, 0.997,
));
*/

Pdef(\dfms, Ppar([Pdef(\dfm1), Pdef(\dfm2)], inf));
);

/*
Pdef(\dfms).play(~tempo, quant: 0.5);
m.control(0, 110, ~yellow);
Pdef(\dfms).isPlaying;
Pdef(\dfms).stop;
*/

// SELF-OSCILLATING RESONANT FILTER: MIDI CONTROL

(
MIDIdef.cc(\dfms, {
    if(Pdef(\dfms).isPlaying.not) {
        Pdef(\dfms).play(~tempo, quant: 0.5);
        m.control(0, 110, ~orange);
        "dfm play".postln;
    } {
        Pdef(\dfms).stop;
        m.control(0, 110, 0);
        "dfm stop".postln;
    }
}, 110, srcID: ~lp.uid, argTemplate: { |a| a > 0 });
);

////////////////////////////////////////////////////////////////
// RESONANT HIGH-PASS FILTER: SYNTH

(
SynthDef(\rhpf, { |freq = 4000, gate = 1, inbus = 0, level = 0.5|
    var env             =   Env.asr(sustainLevel: level);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    var rhpf            =   RHPF.ar(in, freq, 0.01, envgen);
    Out.ar(0, rhpf);
}).add;
);

(
Pdef(\rhpf1, Pmono(\rhpf, \inbus, ~rhpfbus1, \octave, 9, \scale, ~scale));

Pdef(\rhpf2, Pmono(\rhpf, \inbus, ~rhpfbus2, \note, [0, 7], \octave, 9, \scale, ~scale));

Pdef(\rhpfs, Ppar([Pdef(\rhpf1), Pdef(\rhpf2)], inf));
);

Pdef(\rhpfs).play(~tempo, quant: 0.5);
m.control(0, 111, ~yellow);
/*
Pdef(\rhpfs).isPlaying;
Pdef(\rhpfs).stop;
*/

(
MIDIdef.cc(\rhpfs, {
    if(Pdef(\rhpfs).isPlaying.not) {
        Pdef(\rhpfs).play(~tempo, quant: 0.5);
        m.control(0, 111, ~yellow);
        "rhpfs play".postln;
    } {
        Pdef(\rhpfs).stop;
        m.control(0, 111, 0);
        "rhpfs stop".postln;
    }
}, 111, srcID: ~lp.uid, argTemplate: { |x| x > 0 });
);

////////////////////////////////////////////////////////////////
// SOUNDFILE PLAYER: SYNTH

(
SynthDef(\sfplay, { |
    attack = 0.01, bufnum, curve = 0, gate = 1, loop = 0, outbus = 0, rate = 1, release = 0.01, startPos = 0, vol = 0.1|
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
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 16, 24, 32], inf),
        \legato, 1,
        \loop, 1,
        \outbus, [0, ~ringzbus1],
        \startPos, Pwhite(0, 1000000, inf),
        //\startPos, Pwhite(0, ~arrayOfBuffers[Pkey(\bufnum)].numFrames, inf),
        \vol, 0.05,
));
Pdef(\sfplay2, Pbindf(Pdef(\sfplay1), \outbus, [0, ~ringzbus2]));

Pdef(\sfplay3, Pbindf(Pdef(\sfplay1), \outbus, [0, ~ringzbus3]));

Pdef(\sfplay4, Pbindf(Pdef(\sfplay1), \dur, Pshuf([64, 96], inf), \outbus, [0, ~ringzbus4]));
);

/*
Pdef(\sfplay1).play(~tempo, quant: 0.5);
Pdef(\sfplay1).isPlaying;
Pdef(\sfplay1).stop;
*/

/*
Pdef(\sfplay2).play(~tempo, quant: 0.5);
Pdef(\sfplay2).isPlaying;
Pdef(\sfplay2).stop;
*/

/*
Pdef(\sfplay3).play(~tempo, quant: 0.5);
Pdef(\sfplay3).isPlaying;
Pdef(\sfplay3).stop;
*/

/*
Pdef(\sfplay4).play(~tempo, quant: 0.5);
Pdef(\sfplay4).isPlaying;
Pdef(\sfplay4).stop;
*/

// SOUNDFILE PLAYER: MIDI CONTROL

(
MIDIdef.noteOn(\sfplay1, {
    if(Pdef(\sfplay1).isPlaying.not) {
        Pdef(\sfplay1).play(~tempo, quant: 0.5);
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
        Pdef(\sfplay2).play(~tempo, quant: 0.5);
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
        Pdef(\sfplay3).play(~tempo, quant: 0.5);
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
        Pdef(\sfplay4).play(~tempo, quant: 0.5);
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
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin1            =   FBSineC.ar(freq, [im, im - 0.01], fb, mul: envgen);
    var leakdc          =   LeakDC.ar(sin1);
    var rhpf            =   BHiPass4.ar(leakdc, (freq).clip(50, SampleRate.ir / 3), 0.01);
    var sin2            =   SinOscFB.ar(freq / 8, 0.3, envgen);
    Out.ar(outbus, rhpf + sin2);
}).add;
);

// DRONE: PATTERNS

(
Pdef(\sin1,
    Pbind(
        \instrument, \sin,
        \degree, Pshuf(~chords, inf),
        \dur, Pshuf(~durs, inf),
        \fb, Pshuf((1..11) / 10, inf),
        \im, Pshuf((11..17) / 10, inf),
        \legato, 0.5,
        \octave, 8,
        \scale, ~scale
));
Pdef(\sin2, Pbindf(Pdef(\sin1), \octave, 9));

Pdef(\sin3,
    Pmono(
        \sin,
        \degree, [7, 12],
        \dur, Pshuf(~durs, inf),
        \fb, Pshuf((1..11) / 10, inf),
        \im, Pshuf((11..17) / 10, inf),
        \octave, 7,
        \scale, ~scale
));

Pdef(\sinbass,
    Pbind(
        \instrument, \sin,
        \degree, Pshuf(~chord, inf),
        \dur, Pshuf(~durs, inf),
        \legato, 0.5,
        \level, 0.05,
        \octave, [5, 6],
        \scale, ~scale
));
);


/*
Pdef(\sin1).play(~tempo, quant: 0.5);
Pdef(\sin1).isPlaying;
Pdef(\sin1).stop;
*/

/*
Pdef(\sin2).play(~tempo, quant: 0.5);
Pdef(\sin2).isPlaying;
Pdef(\sin2).stop;
*/

/*
Pdef(\sin3).play(~tempo, quant: 0.5);
Pdef(\sin3).isPlaying;
Pdef(\sin3).stop;
*/

/*
Pdef(\sinbass).play(~tempo, quant: 0.5);
Pdef(\sinbass).isPlaying;
Pdef(\sinbass).stop;
*/

(
MIDIdef.noteOn(\sin1, {
    if(Pdef(\sin1).isPlaying.not) {
        Pdef(\sin1).play(~tempo, quant: 0.5);
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
        Pdef(\sin2).play(~tempo, quant: 0.5);
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
        Pdef(\sin3).play(~tempo, quant: 0.5);
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
        Pdef(\sinbass).play(~tempo, quant: 0.5);
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
// SHAPELY: SYNTH

(
SynthDef(\shapely, { |a = 1, dur = 1, fb = 0, freq = 440, gate = 1, level = 0.03, lfreq = 1, limitmodmin = 0.1, limitmodmax = 0.2, pan = 0|
    var env             =   Env.asr(0.01, level, 0.01);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin             =   SinOscFB.ar(freq, fb);
    var limitmod        =   LatoocarfianN.ar(lfreq, a).range(limitmodmin, limitmodmax);
    var shape           =   SineShaper.ar(sin, limitmod, envgen);
    var pan2            =   Pan2.ar(shape, pan);
    Out.ar(0, pan2).fold2(level);
}).add;
);

(
Pdef(\shapely1,
    Pbind(
        \instrument, \shapely,
        \a, Pwhite(0.8, 1.2, inf),
        \dur, Pshuf(~durs, inf),
        \fb, 1,
        \legato, 0.5,
        \lfreq, ~tempo.tempo * 4,
        \limitmodmin, 0.08,
        \limitmodmax, 0.16,
        \degree, Pshuf(~chords, inf),
        \octave, 7,
        \pan, -0.5,
        \scale, ~scale
));

Pdef(\shapely2, Pbindf(Pdef(\shapely1), \pan, 0.5));

//Pdef(\shapely3, Pbindf(Pdef(\shapely1), \lfreq, Pkey(\dur).reciprocal, \pan, 0));

Pdef(\shapes1, Ppar([Pdef(\shapely1), Pdef(\shapely2)], inf));
);

/*
Pdef(\shapes1).play(~tempo, quant: 0.5);
Pdef(\shapes1).isPlaying;
Pdef(\shapes1).stop;
*/

(
MIDIdef.noteOn(\shapes1, {
    if(Pdef(\shapes1).isPlaying.not) {
        Pdef(\shapes1).play(~tempo, quant: 0.5);
        m.noteOn(0, 20, ~red);
        "shapes1 play".postln;
    } {
        Pdef(\shapes1).stop;
        m.noteOn(0, 20, 0);
        "shapes1 stop".postln;
    }
}, 20, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// SWITCH: SYNTH

(
SynthDef(\switch, { |a = 1, curve = -4, dur = 1, fb = 0, freq = 440, gate = 1, level = 0.005|
    //var env             =   Env.perc(0.003, dur + 0.5, level, curve);
    //var envgen          =   EnvGen.kr(env, doneAction: 2);
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin             =   SinOscFB.ar(freq!2, fb, envgen);
    var lat             =   LatoocarfianC.ar(a: a, mul: envgen / 16);
    var rhpf            =   RHPF.ar(lat, (freq * 32).clip(50, SampleRate.ir / 2.5), 0.03, 0.3);
    Out.ar(0, sin + rhpf);
}).add;
);

/*
(
Pdef(\pulse1,
    Pbind(
        \instrument, \pulse,
        \a, Pshuf((-2..2).stutter(13), inf),
        \curve, -1,
        //\dur, Pseq([0.5, 0.5, 0.75, 0.5, 0.5, 0.5, 0.75, 0.5, 0.5, 0.5, 0.5, 0.75], inf),
        //\dur, Pseq([Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3].stutter(5)), 12], inf),
        //\dur, Pshuf(~durs, inf),
        //\dur, 0.125,
        \dur, Pseq(~quickdurs * 2, inf),
        \fb, 0.4,
        \level, 0.02,
        /*
        \degree, Pseq([
            Pseq([[7, 10]], 31),
            Pseq([[7, 10, 12]], 37),
            Pseq([[7, 10, 12, 14]], 41),
        ], inf),
        */
        //\degree, Pwalk(~chord, Prand([-1, 1], inf), Prand([-1, 1], inf)),
        \degree, Pshuf([Pshuf(~chord), Pshuf(~chord.mirror1)], inf),
        \octave, 5,
        \scale, ~scale
));

Pdef(\pulse2, Pbindf(Pdef(\pulse1)));
);

/*
Pdef(\pulse1).play(~tempo, quant: 0.5);
Pdef(\pulse1).isPlaying;
Pdef(\pulse1).stop;
*/

/*
Pdef(\pulse2).play(~tempo, quant: 0.5);
Pdef(\pulse2).isPlaying;
Pdef(\pulse2).stop;
*/

*/

(
Pdef(\switch1,
    Pbind(
        \instrument, \switch,
        \degree, Pshuf(~chords, inf),
        \dur, Pshuf(~durs, inf),
        \fb, 0.5,
        \legato, 0.5,
        \octave, 5,
        \scale, ~scale
));

Pdef(\switch2, Pbindf(Pdef(\switch1), \fb, 1));

Pdef(\switch3, Pbindf(Pdef(\switch1), \fb, 2));

Pdef(\switches1, Ppar([Pdef(\switch1), Pdef(\switch2), Pdef(\switch3)], inf));

Pdef(\switches2, Pbindf(Pdef(\switches1), \octave, 6));

Pdef(\switches3, Pbindf(Pdef(\switches1), \degree, Pshuf(~chord, inf), \octave, 4));
);

/*
Pdef(\switches1).play(~tempo, quant: 0.5);
Pdef(\switches1).isPlaying;
Pdef(\switches1).stop;
*/

/*
Pdef(\switches2).play(~tempo, quant: 0.5);
Pdef(\switches2).isPlaying;
Pdef(\switches2).stop;
*/

/*
Pdef(\switches3).play(~tempo, quant: 0.5);
Pdef(\switches3).isPlaying;
Pdef(\switches3).stop;
*/

/*
(
MIDIdef.noteOn(\pulse1, {
    if(Pdef(\pulse1).isPlaying.not) {
        Pdef(\pulse1).play(~tempo, quant: 0.5);
        m.noteOn(0, 21, ~red);
        "pulse1 play".postln;
    } {
        Pdef(\pulse1).stop;
        m.noteOn(0, 21, 0);
        "pulse1 stop".postln;
    }
}, 21, srcID: ~lp.uid);
);
*/

(
MIDIdef.noteOn(\switches1, {
    if(Pdef(\switches1).isPlaying.not) {
        Pdef(\switches1).play(~tempo, quant: 0.5);
        m.noteOn(0, 21, ~red);
        "switches1 play".postln;
    } {
        Pdef(\switches1).stop;
        m.noteOn(0, 21, 0);
        "switches1 stop".postln;
    }
}, 21, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\switches2, {
    if(Pdef(\switches2).isPlaying.not) {
        Pdef(\switches2).play(~tempo, quant: 0.5);
        m.noteOn(0, 22, ~red);
        "switches2 play".postln;
    } {
        Pdef(\switches2).stop;
        m.noteOn(0, 22, 0);
        "switches2 stop".postln;
    }
}, 22, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\switches3, {
    if(Pdef(\switches3).isPlaying.not) {
        Pdef(\switches3).play(~tempo, quant: 0.5);
        m.noteOn(0, 23, ~red);
        "switches3 play".postln;
    } {
        Pdef(\switches3).stop;
        m.noteOn(0, 23, 0);
        "switches3 stop".postln;
    }
}, 23, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// SINPRC: SYNTH

(
SynthDef(\sinprc, { |curve = -4, fb = 0.1, freq = 440, im = 1, level = 0.1, mode = 1, outbus = 0, pan = 0|
    var env             =   Env.perc(0.003, 0.5, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var fbsin           =   FBSineC.ar(freq, im, fb, mul: envgen);
    var rhpf            =   BMoog.ar(fbsin, freq.clip(50, SampleRate.ir / 2.5), 0.9, mode, 0);
    var sin             =   SinOsc.ar(freq!2, mul: envgen / 16);
    var pan2            =   Pan2.ar(rhpf + sin, pan).fold2(level);
    Out.ar(outbus, pan2);
}).add;
);

// SINPRC: PATTERNS

(
Pdef(\sinprc1,
    Pbind(
        \instrument, \sinprc,
        \curve, -4,
        \dur, Pshuf([Pseq([0.125], 2), Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].stutter(3))], inf),
        \level, 0.1,
        \mode, 1,
        \degree, Pshuf(~chords, inf),
        \octave, 8,
        \outbus, Pshuf([0, [0, ~verbus1]], inf),
        \pan, Pshuf([-0.5, 0, 0.5], inf),
        \scale, ~scale
));

Pdef(\sinprc2,
    Pbindf(
        Pdef(\sinprc1),
        \level, 0.02
));

Pdef(\sinprcs1and2, Ppar([Pdef(\sinprc1), Pdef(\sinprc2)], inf));

//~sinprcdegrees = [-5, -2, 0, 2].scramble.mirror1;
Pdef(\sinprc3,
    Pbindf(
        Pdef(\sinprc1),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
        \level, 0.2,
        \mode, 0,
        //\degree, Pseq(~sinprcdegrees, inf),
        \degree, 0,
        \octave, [5, 6],
        \outbus, 0,
        \pan, 0,
        \scale, ~scale
));

~sinprc4lvl = 0.03;
~sinprc5lvl = ~sinprc4lvl / 5;
Pdef(\sinprc4,
    Pbind(
        \instrument, \sinprc,
        \curve, Pshuf([-64, -32, -16].stutter(3), inf),
        \degree, Pshuf([2, 7, 10, 12].powerset.reject { |c| c.isEmpty }.stutter(11), inf),
        //\degree, Pshuf([7, 12].powerset.reject { |d| d.isEmpty }, inf),
        \dur, Pshuf([
            0.25, 0.5, 0.75, Pseq([0.75, 0.75, 0.5] / 2), 1, 1.5, 2, 3, 4, 6, 8
        ], inf),
        //\fb, Pshuf([0.1, 0.2, 0.4, 0.8, 1.6, 3.2], inf),
        \fb, Pshuf((0..10) / 10, inf),
        \level, Pshuf([0.5, 1] * ~sinprc4lvl, inf),
        \octave, 11,
        \outbus, Pshuf([0, [0, ~ringzbus2], [0, ~ringzbus3], [0, ~verbus1], ~verbus1], inf),
        \scale, ~scale
));

Pdef(\sinprc5,
    Pbindf(
        Pdef(\sinprc4),
        \level, ~sinprc5lvl
));

Pdef(\sinprcs4and5, Ppar([Pdef(\sinprc4), Pdef(\sinprc5)], inf));

Pdef(\sinprc6, Pbindf(Pdef(\sinprc4), \degree, 12));

Pdef(\sinprc7, Pbindf(Pdef(\sinprc6), \level, ~sinprc5lvl));

Pdef(\sinprcs6and7, Ppar([Pdef(\sinprc6), Pdef(\sinprc7)], inf));

Pdef(\sinprc8,
    Pbind(
        \instrument, \sinprc,
        \curve, -8,
        \degree, Pseq([Rest, [0, 7]], inf),
        \dur, Pshuf([0.75, 1, 1.25, 1.5, 1.75], inf),
        \im, Pwhite(0.9, 1.1, inf),
        \level, 0.1,
        \octave, 7,
        \scale, ~scale
));

Pdef(\sinprc9, Pbindf(Pdef(\sinprc8), \level, 0.02, \pan, -1));

Pdef(\sinprc10, Pbindf(Pdef(\sinprc9), \pan, 1));

Pdef(\sinprcs8and9and10, Ppar([Pdef(\sinprc8), Pdef(\sinprc9), Pdef(\sinprc10)], inf));
);

/*
Pdef(\sinprc1).play(~tempo, quant: 0.5);
Pdef(\sinprc1).isPlaying;
Pdef(\sinprc1).stop;
*/

/*
Pdef(\sinprc2).play(~tempo, quant: 0.5);
Pdef(\sinprc2).isPlaying;
Pdef(\sinprc2).stop;
*/

/*
Pdef(\sinprc3).play(~tempo, quant: 0.5);
Pdef(\sinprc3).isPlaying;
Pdef(\sinprc3).stop;
*/

/*
Pdef(\sinprcs4and5).play(~tempo, quant: 0.5);
Pdef(\sinprcs4and5).isPlaying;
Pdef(\sinprcs4and5).stop;
*/

/*
Pdef(\sinprcs6and7).play(~tempo, quant: 0.5);
Pdef(\sinprcs6and7).isPlaying;
Pdef(\sinprcs6and7).stop;
*/

/*
Pdef(\sinprc8).play(~tempo, quant: 0.5);
Pdef(\sinprc8).isPlaying;
Pdef(\sinprc8).stop;
*/

// SINPRC: MIDI CONTROL

(
MIDIdef.noteOn(\sinprcs1and2, {
    if(Pdef(\sinprcs1and2).isPlaying.not) {
        Pdef(\sinprcs1and2).play(~tempo, quant: 0.5);
        m.noteOn(0, 32, ~red);
        "sinprcs 1 and 2 play".postln;
    } {
        Pdef(\sinprcs1and2).stop;
        m.noteOn(0, 32, 0);
        "sinprcs 1 and 2 stop".postln;
    };
}, 32, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sinprc3, {
    if(Pdef(\sinprc3).isPlaying.not) {
        Pdef(\sinprc3).play(~tempo, quant: 0.5);
        m.noteOn(0, 33, ~red);
        "sinprc3 play".postln;
    } {
        Pdef(\sinprc3).stop;
        m.noteOn(0, 33, 0);
        "sinprc3 stop".postln;
    };
}, 33, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sinprcs4and5, {
    if(Pdef(\sinprcs4and5).isPlaying.not) {
        Pdef(\sinprcs4and5).play(~tempo, quant: 0.5);
        m.noteOn(0, 34, ~red);
        "sinprcs 4 and 5 play".postln;
    } {
        Pdef(\sinprcs4and5).stop;
        m.noteOn(0, 34, 0);
        "sinprcs 4 and 5 stop".postln;
    };
}, 34, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sinprcs6and7, {
    if(Pdef(\sinprcs6and7).isPlaying.not) {
        Pdef(\sinprcs6and7).play(~tempo, quant: 0.5);
        m.noteOn(0, 35, ~red);
        "sinprcs 6 and 7 play".postln;
    } {
        Pdef(\sinprcs6and7).stop;
        m.noteOn(0, 35, 0);
        "sinprcs 6 and 7 stop".postln;
    };
}, 35, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\sinprcs8and9and10, {
    if(Pdef(\sinprcs8and9and10).isPlaying.not) {
        Pdef(\sinprcs8and9and10).play(~tempo, quant: 0.5);
        m.noteOn(0, 48, ~red);
        "sinprcs 8, 9, and 10 play".postln;
    } {
        Pdef(\sinprcs8and9and10).stop;
        m.noteOn(0, 48, 0);
        "sinprcs 8, 9, and 10 stop".postln;
    };
}, 48, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// PINZ: SYNTH

(
SynthDef(\pinz, { |curve = -4, fb = 0, freq = 440, level = 0.05, pan = 0|
    var env         =   Env.perc(0.003, 1, level, curve);
    var envgen      =   EnvGen.kr(env, doneAction: 2);
    var sin         =   SinOscFB.ar(freq, fb, envgen);
    var rhpf        =   RHPF.ar(sin, (freq * 8).clip(50, SampleRate.ir / 2.5));
    var pan2        =   Pan2.ar(rhpf, pan);
    Out.ar(0, pan2);
}).add;
);

(
Pdef(\pinz1,
    Pbind(
        \instrument, \pinz,
        \dur, Pshuf([0.5, 0.75].stutter(7), inf),
        //\dur, 0.25,
        \fb, Pshuf((9..22) / 10, inf),
        /*
        \degree, Pseq([
            Pshuf(~chords[0].stutter(11)),
            Pshuf(~chords[1].stutter(11)),
            Pshuf(~chords[2].stutter(11)),
            Pshuf(~chords[3].stutter(11))
        ], inf),
        */
        \octave, 7,
        \pan, -1,
        \scale, ~scale
));

Pdef(\pinz2, Pbindf(Pdef(\pinz1), \pan, 1));

Pdef(\pinz3, Pbindf(Pdef(\pinz1), \degree, 0, \pan, 0));

Pdef(\pinz, Ppar([Pdef(\pinz1), Pdef(\pinz2), Pdef(\pinz3)], inf));
);

/*
Pdef(\pinz).play(~tempo, quant: 0.5);
Pdef(\pinz).isPlaying;
Pdef(\pinz).stop;
*/

(
MIDIdef.noteOn(\pinz, {
    if(Pdef(\pinz).isPlaying.not) {
        Pdef(\pinz).play(~tempo, quant: 0.5);
        m.noteOn(0, 51, ~red);
        "pinz play".postln;
    } {
        Pdef(\pinz).stop;
        m.noteOn(0, 51, 0);
        "pinz stop".postln;
    };
}, 51, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// LATPRC: SYNTH

(
SynthDef(\latprc, { |a = 1, bal = 0, curve = 0, envlength = 0.3, ffreq = 4000, freq = 2000, level = 0.1, outbus|
    var env             =   Env.perc(0.01, envlength, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var lat             =   LatoocarfianC.ar([freq, freq - 1], a: [a, a - 0.001], mul: envgen);
    var rlpf            =   RLPF.ar(lat, ffreq, 0.3);
    var bal2            =   Balance2.ar(rlpf[0], rlpf[1], bal);
    Out.ar(outbus, bal2);
}).add;
);

// LATPRC: PATTERNS

(
Pdef(\latprc1,
    Pbind(
        \instrument, \latprc,
        \a, Pshuf((-3..2) + 0.5, inf),
        \bal, Pshuf([-0.5, 0, 0.5].stutter(7), inf),
        \curve, -64,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6], inf),
        \envlength, 0.6,
        \ffreq, Pshuf((2..8) * 1000, inf),
        \freq, Pshuf([1/64, 1] * 22050, inf),
        \level, 0.1,
        \outbus, Pshuf([[0, ~dfmbus1], [0, ~dfmbus2]].stutter(5), inf),
        \scale, ~scale
));

Pdef(\latprc2,
    Pbindf(
        Pdef(\latprc1),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5], inf),
        \level, 0.02,
        \outbus, 0
));

Pdef(\latprcs, Ppar([Pdef(\latprc1), Pdef(\latprc2)], inf));

Pdef(\lathat1,
    Pbind(
        \instrument, \latprc,
        \a, Pseq((-2..2).mirror1 / 10, inf),
        \bal, Pshuf([-0.5, 0, 0.5].stutter(3), inf),
        \curve, -16,
        \dur, Prand([0.25, 0.5, 0.75, 1, 1.25], inf),
        \ffreq, 18000,
        \freq, 22050,
        \level, 0.3,
        \outbus, ~rhpfbus1
));

Pdef(\lathat2, Pbindf(Pdef(\lathat1), \level, 0.04));

Pdef(\lathats, Ppar([Pdef(\lathat1), Pdef(\lathat2)], inf));

Pdef(\latquick,
    Pbind(
        \instrument, \latprc,
        \a, Pshuf(((58..63) / 100).stutter(7), inf),
        \bal, Pshuf([-0.5, 0, 0.5].stutter(31), inf),
        \curve, -32,
        \dur, Pseq(~quickdurs, inf),
        \ffreq, 13000,
        \level, 0.3,
        \octave, 11,
        \outbus, ~rhpfbus2
));

Pdef(\latsnr,
    Pbind(
        \instrument, \latprc,
        \a, -1.5,
        \bal, Pshuf([-0.5, 0, 0.5], inf),
        \dur, Pseq([0.25, 11, 0.25, 12, 0.25, 13], inf),
        \curve, -8,
        \level, Pshuf([0.2, 1].stutter(5) * 0.05, inf),
        \octave, Pshuf([9, 11, 13].powerset.reject { |o| o.isEmpty }, inf),
));
);

/*
Pdef(\latprcs).play(~tempo, quant: 0.5);
Pdef(\latprcs).isPlaying;
Pdef(\latprcs).stop;
*/

/*
Pdef(\lathats).play(~tempo, quant: 0.5);
Pdef(\lathats).isPlaying;
Pdef(\lathats).stop;
*/

/*
Pdef(\latquick).play(~tempo, quant: 0.5);
Pdef(\latquick).isPlaying;
Pdef(\latquick).stop;
*/

/*
Pdef(\latsnr).play(~tempo, quant: 0.5);
Pdef(\latsnr).isPlaying;
Pdef(\latsnr).stop;
*/

// LATPRC: MIDI CONTROL

(
MIDIdef.noteOn(\latprcs, {
    if(Pdef(\latprcs).isPlaying.not) {
        Pdef(\dfms).play(~tempo, quant: 0.5);
        Pdef(\latprcs).play(~tempo, quant: 0.5);
        m.control(0, 110, ~orange);
        m.noteOn(0, 36, ~red);
        "latprcs play".postln;
    } {
        Pdef(\latprcs).stop;
        Pdef(\dfms).stop;
        m.noteOn(0, 36, 0);
        m.control(0, 110, 0);
        "latprcs stop".postln;
    };
}, 36, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\lathats, {
    if(Pdef(\lathats).isPlaying.not) {
        Pdef(\lathats).play(~tempo, quant: 0.5);
        m.noteOn(0, 37, ~red);
        "lathats play".postln;
    } {
        Pdef(\lathats).stop;
        m.noteOn(0, 37, 0);
        "lathats stop".postln;
    }
}, 37, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\latquick, {
    if(Pdef(\latquick).isPlaying.not) {
        Pdef(\latquick).play(~tempo, quant: 0.5);
        m.noteOn(0, 38, ~red);
        "latquick play".postln;
    } {
        Pdef(\latquick).stop;
        m.noteOn(0, 38, 0);
        "latquick stop".postln;
    }
}, 38, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\latsnr, {
    if(Pdef(\latsnr).isPlaying.not) {
        Pdef(\latsnr).play(~tempo, quant: 0.5);
        m.noteOn(0, 39, ~red);
        "latsnr play".postln;
    } {
        Pdef(\latsnr).stop;
        m.noteOn(0, 39, 0);
        "latsnr stop".postln;
    }
}, 39, srcID: ~lp.uid);
);

////////////////////////////////////////////////////////////////
// REZSOUND: SYNTH

(
~rezsound1buf = ~arrayOfBuffers.detect { |b| b.path.containsi("1794.schuettelgrat.Himara.Pebble_Beach_in_Himara") };
~rezsound2buf = ~arrayOfBuffers.detect { |b| b.path.containsi("1971.Caspar_StrAm.Baltic_Sea.Viking_Line_Taxfree") };
~rezsound3buf = ~arrayOfBuffers.detect { |b| b.path.containsi("0692.Pei.Taidong.east_coast_pebble_engulf01.aif") };

Pdef(\rezsound1,
    PmonoArtic(
        \sfplay,
        \bufnum, ~rezsound1buf.bufnum,
        \curve, -4,
        \dur, Pseq([(~rezsound1buf.duration / ~tempo.tempo).round(1) * 2]),
        \legato, 1,
        \loop, 1,
        \outbus, [0, ~rezbus1],
        \release, 5,
        \vol, 0.05
));

Pdef(\rezsound2,
    Pbindf(
        Pdef(\rezsound1),
        \attack, 5,
        \bufnum, ~rezsound2buf.bufnum,
        \dur, Pseq([(~rezsound2buf.duration / ~tempo.tempo).round(1) - 40]),
        \loop, 0,
        \outbus, ~rezbus2,
        \startPos, s.sampleRate * 40,
        \vol, 0.08
));

Pdef(\rezsound3,
    Pbindf(
        Pdef(\rezsound1),
        \bufnum, ~rezsound3buf.bufnum,
        \dur, Pseq([(~rezsound3buf.duration / ~tempo.tempo).round(1)]),
        \loop, 0,
        \outbus, [0, ~rezbus3],
        \vol, 0.08
));
);

/*
Pdef(\rezsound1).play(~tempo, quant: 0.5);
Pdef(\rezsound1).isPlaying;
Pdef(\rezsound1).stop;
*/

/*
Pdef(\rezsound2).play(~tempo, quant: 0.5);
Pdef(\rezsound2).isPlaying;
Pdef(\rezsound2).stop;
*/

/*
Pdef(\rezsound3).play(~tempo, quant: 0.5);
Pdef(\rezsound3).isPlaying;
Pdef(\rezsound3).stop;
*/

(
MIDIdef.noteOn(\rezsound1, {
    if(Pdef(\rezsound1).isPlaying.not) {
        Pdef(\rezsound1).play(~tempo, quant: 0.5);
        m.noteOn(0, 4, ~green);
        "rezsound1 play".postln;
    } {
        Pdef(\rezsound1).stop;
        m.noteOn(0, 4, 0);
        "rezsound1 stop".postln;
    }
}, 4, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\rezsound2, {
    if(Pdef(\rezsound2).isPlaying.not) {
        Pdef(\rezsound2).play(~tempo, quant: 0.5);
        m.noteOn(0, 5, ~green);
        "rezsound2 play".postln;
    } {
        Pdef(\rezsound2).stop;
        m.noteOn(0, 5, 0);
        "rezsound2 stop".postln;
    }
}, 5, srcID: ~lp.uid);
);

(
MIDIdef.noteOn(\rezsound3, {
    if(Pdef(\rezsound3).isPlaying.not) {
        Pdef(\rezsound3).play(~tempo, quant: 0.5);
        m.noteOn(0, 6, ~green);
        "rezsound3 play".postln;
    } {
        Pdef(\rezsound3).stop;
        m.noteOn(0, 6, 0);
        "rezsound3 stop".postln;
    }
}, 6, srcID: ~lp.uid);
);