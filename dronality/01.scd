// time and pitch logic

t = TempoClock(1);

~key = 40;

// synth

(
SynthDef(\sinfb, { |fb = 0, freq = 440, gate = 1, level = 0.05|
    var env             =   Env.asr(1, level, 1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sinfb           =   SinOscFB.ar(freq * LFNoise2.kr(0.05 ! 2, 0.003, 1), fb, envgen);
    Out.ar(0, sinfb);
}).add;
);

// Patterns

(
Pdef(\drone, Pmono(\sinfb, \freq, [ 1, 2, 3, 4 ].stutter(2) * ~key));
);

/*
Pdef(\drone).play(t);
Pdef(\drone).isPlaying;
Pdef(\drone).stop;
*/

/*
(
Pdef(\tones1, Pbind(\instrument, \sinfb, \dur, 120, \freq, Pseq([ 6, 7, 8 ] * ~key, inf), \legato, 0.5));
);

/*
Pdef(\tones1).play(t);
Pdef(\tones1).isPlaying;
Pdef(\tones1).stop;
*/

Pdef(\tones2, Pbindf(Pdef(\tones1), \freq, Pxrand([ 6, 7, 8 ] * ~key, inf)));

/*
Pdef(\tones2).play(t);
Pdef(\tones2).isPlaying;
Pdef(\tones2).stop;
*/
*/

(
Pdef(\chords1,
    Pbind(
        \instrument, \sinfb,
        \dur, 60,
        \fb, 0.3,
        \freq, Pseq([[ 6, 7, 8 ].powerset.reject({ |c| c.size != 2 }) * ~key], inf),
        \legato, 1
))
);

/*
Pdef(\chords1).play(t, quant: 60);
Pdef(\chords1).isPlaying;
Pdef(\chords1).stop;
*/

(
Pdef(\chords2,
    Pbind(
        \instrument, \sinfb,
        \dur, 60,
        \fb, 0.5,
        \freq, Pseq([[ 8, 9, 11, 12, 13, 14, 16 ].powerset.reject({ |c| c.size != 4 }) * ~key], inf),
        \legato, 1
));
);

/*
Pdef(\chords2).play(t, quant: 60);
Pdef(\chords2).isPlaying;
Pdef(\chords2).stop;
*/