/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/


~tempo = TempoClock(180/60);

(
~scale = Scale.minor;
~root = -4;
~degrees1 = [0, 2, 4, 6, 7];
~degrees2 = ~degrees1 + ~scale.size;
~degrees = ~degrees1 ++ ~degrees2;
);

//

(
SynthDef(\sin, { |freq = 440, fb = 0, gate = 1, level = 0.1|
    var env         =   Env.asr(0.005, level, 0.1, 0);
    var envgen      =   EnvGen.kr(env, gate, doneAction: 2);
    var sin1        =   SinOscFB.ar([freq, freq - 0.03], fb, envgen);
    var sin2        =   SinOsc.ar([freq, freq + 0.03] * 8, mul: envgen / 32);
    Out.ar(0, sin1 + sin2);
}).add;
);

//

~stan = Pstandard(1.01).asStream;

(
~degree = Prout({
    var d;
    loop({
        d = ~stan.next[0] * (~degrees1.size - 1);
        d.round(1).yield;
    });
});
);

(
x =
Pdef(\pat,
	//Pbind(
    Pmono(
        //\instrument, \sin,
        \sin,
        \degree, Pswitch1(~degrees1, ~degree),
        //\degree, Pwalk(~degrees1, Prand([-1, 1], inf), Pseq([-1, 1], inf)),
        \dur, 0.5,
        \fb, 0.3,
        \legato, 1,
        \octave, 6,
        \root, ~root,
        \scale, ~scale
));
);

x.play(~tempo, quant: 0.5);
x.stop;

//

(
y = Pdef(\pat2,
    Pbindf(
        x,
        \octave, 5
));
);

y.play(~tempo, quant: 0.5);
y.stop;

//

(
z =
Pdef(\bass,
    Pbindf(
        x,
        \fb, 0.8,
        \octave, [3, 4]
));
);

z.play(~tempo, quant: 0.5);
z.stop;

//

a = Pdef(\pats, Ptpar([0, x, 200, y, 400, z]));

a.play(~tempo, quant: 0.5);
a.isPlaying;
a.stop;