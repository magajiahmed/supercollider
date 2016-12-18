// Pitch
~tuning = Tuning.et(5);
~degrees = (0..4);
~scale = Scale.new(~degrees, ~degrees.size, ~tuning);

// Time
~tempo = TempoClock(120/60);

//

(
SynthDef(\sine, { |amp = 0.1, freq = 440, gate = 1|
    var env             =   Env.asr(0.01, amp, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin             =   FSinOsc.ar(freq ! 2).round(0.25).round(0.125) * envgen;
    Out.ar(0, sin);
}).add;
);

(
~chords = ~degrees.powerset.reject({ |c| c.size != 3 });

Pdef(\chords,
    Pbind(
        \instrument, \sine,
        \amp, 0.03,
        \degree, Pshuf(~chords),
        \dur, 50,
        \legato, 0.5,
        \octave, 6,
        \scale, ~scale
));
);

/*
Pdef(\chords).play(~tempo, quant: 25);
Pdef(\chords).isPlaying;
Pdef(\chords).stop;
*/

//

(
SynthDef(\bass, { |amp = 0.1, curve = -4, fb = 0, freq = 440, releaseTime = 1, round = 0.1|
    var env             =   Env.perc(0.01, releaseTime, amp, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sin             =   SinOscFB.ar(freq ! 2, XLine.kr(fb + 0.00001, 0.00001, releaseTime)).round(round) * envgen;
    Out.ar(0, sin);
}).add;
);

(
Pdef(\bass,
    Pbind(
        \instrument, \bass,
        \curve, -4,
        \degree, Pseq([Pshuf((0..4), 9), Pseq([Rest], 30)], inf),
        \dur, Pshuf([
            Pseq([0.2], 5), Pseq([0.6, 0.4]), Pseq([0.4, 0.6]), Pseq([0.6, 0.2, 0.2]), Pseq([0.2, 0.2, 0.6])
        ], inf),
        \fb, Pshuf([0, 0.125, 0.25, 0.5, 1, 2], inf),
        \octave, [2, 3],
        \releaseTime, Pkey(\dur),
        \round, Pshuf(Array.interpolation(10, 0.005, 0.5), inf),
        \scale, ~scale
));
);

/*
Pdef(\bass).play(~tempo, quant: 25);
Pdef(\bass).isPlaying;
Pdef(\bass).stop;
*/

//

(
Pdef(\hat,
    Pbind(
        \instrument, \bass,
        \amp, 0.02,
        \curve, -64,
        \fb, 6,
        \octave, Pseq([
            10, 10, 10, 10, 10,
            10, 10, 10, 10, 10,
            Rest, Rest, Rest, Rest, Rest,
            10, 10, 10, 10, 10,
            Rest, Rest, Rest, Rest, Rest
        ], inf),
        \releaseTime, 0.03,
        \scale, ~scale
));
);

/*
Pdef(\hat).play(~tempo);
Pdef(\hat).isPlaying;
Pdef(\hat).stop;
*/

(
Pdef(\hat2,
    Pbindf(
        Pdef(\hat),
        \amp, 0.005,
        \dur, Pshuf([0.2, 0.4, 0.6, 0.8, 1], inf)
));
);

/*
Pdef(\hat2).play(~tempo);
Pdef(\hat2).isPlaying;
Pdef(\hat2).stop;
*/

//

(
SynthDef(\prc, { |amp = 0.1, curve = -4, fold2 = 0.5, freq = 1000, releaseTime = 1, round = 0.5|
    var env                 =   Env.perc(0.003, releaseTime, amp, curve);
    var envgen              =   EnvGen.kr(env, doneAction: 2);
    var bn                  =   LFBrownNoise2.ar(freq ! 2).round(round).round(round * 0.5).round(round * 0.25).fold2(fold2) * fold2.reciprocal * envgen;
    Out.ar(0, bn);

}).add;
);

(
~kikfreq = 500;
Pdef(\prc,
    Pbind(
        \instrument, \prc,
        \amp, 0.25,
        \curve, -16,
        \dur, Pshuf(Array.fill(10, { |d| d * 0.2 }), inf),
        //\dur, Pseq([2, 1, 1, 1], inf),
        /*\freq, Pseq([
            ~kikfreq, ~kikfreq, ~kikfreq, ~kikfreq,
            ~kikfreq, ~kikfreq, ~kikfreq, ~kikfreq,
            Rest, Rest, Rest, Rest, Rest,
            ~kikfreq, ~kikfreq, ~kikfreq, ~kikfreq,
            Rest, Rest, Rest, Rest, Rest
        ], inf)*/
        \freq, ~kikfreq,
        \round, Pshuf(Array.interpolation(10, 0.025, 0.25), inf)
));
);

/*
Pdef(\prc).play(~tempo, quant: 25);
Pdef(\prc).isPlaying;
Pdef(\prc).stop;
*/

(
~snrfreq = 20000;

Pdef(\snr,
    Pbind(
        \instrument, \prc,
        \amp, 0.25,
        \curve, -16,
        \dur, Pseq([
            1, 1, 1, 1, 1,
            1, 1, 1, 1, 1,
            1, 1, 1, 1, 1,
            1, 1, 1, 1, 0.6, 0.4,
            1, 1, 1, 1, 0.2, 0.2, 0.2, 0.2, 0.2
        ], inf),
        \fold2, 0.015,
        \freq, Pseq([
            Rest, ~snrfreq, Rest, Rest, Rest,
            Rest, ~snrfreq, Rest, ~snrfreq, Rest,
            Rest, ~snrfreq, Rest, ~snrfreq, ~snrfreq,
            Rest, ~snrfreq, Rest, Rest, ~snrfreq,
            Rest, ~snrfreq, Rest, Rest, ~snrfreq, ~snrfreq, ~snrfreq, ~snrfreq, ~snrfreq
        ], inf),
        \round, 0.5
));
);

/*
Pdef(\snr).play(~tempo, quant: 25);
Pdef(\snr).isPlaying;
Pdef(\snr).stop;
*/

Pdef(\snrecho, Pbind(\instrument, \prc, \amp, 0.05, \curve, -16, \dur, 3.8, \freq, ~snrfreq * 1.5));

/*
Pdef(\snrecho).play(~tempo, quant: 5);
Pdef(\snrecho).isPlaying;
Pdef(\snrecho).stop;
*/

Pdef(\prcpar, Ppar([Pdef(\hat), Pdef(\hat2), Pdef(\prc), Pdef(\snr), Pdef(\snrecho)]));

/*
Pdef(\prcpar).play(~tempo, quant: 25);
Pdef(\prcpar).isPlaying;
Pdef(\prcpar).stop;
*/