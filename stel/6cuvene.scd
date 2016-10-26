// Clear environment and patterns
currentEnvironment.clear;
Pdef.removeAll;

( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
MIDIdef.noteOn(\noteonpostln, { arg ...args; args.postln; });
~lpm = MIDIClient.sources.detect{ |a| a.name.contains("Launchpad") };
if(~lpm.isNil) { ~lpm = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
~midiout = MIDIOut(0);
~midiout.connect(~lpm.uid);
);

// Turn off any lights left on previously.
(0..127).do({ |i| ~midiout.noteOn(0, i, 0) });
(0..127).do({ |i| ~midiout.control(0, i, 0) });

(
t = TempoClock(120/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);
);

(
~midiktrl = { |pdef, note|
    MIDIdef.noteOn(pdef, {
        if(Pdef(pdef).isPlaying.not) {
            ~midiout.noteOn(0, note, 127);
            Pdef(pdef).play(t);
            pdef.post;
            " play".postln;
        } {
            ~midiout.noteOn(0, note, 0);
            Pdef(pdef).stop;
            pdef.post;
            " stop".postln;
        }
    }, note, srcID: ~lpm.uid);
}
);

(
// Pitch logic
~ratios = [1/1, 16/15, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 5/3, 7/4, 15/8];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
~chord = [0, 2, 7, 10, 12];
~chords = [[-5, 2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]];
~root = 3;
);

(
// Bus
~compressorbus = Bus.audio(s, 2);
);

////////////////////////////////////////////////////////////////
// RECORDING

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////////////
// COMPRESSOR

(
SynthDef(\dynamix, { |inbus, outbus|
    var in              =   In.ar(inbus, 2);
    var press           =   Compander.ar(in, in, 0.5, slopeAbove: 1/8, clampTime: 0.002, relaxTime: 0.002);
    Out.ar(outbus, press);
}).add;
);

Pdef(\dynamix, Pmono(\dynamix, \inbus, ~compressorbus, \outbus, 0));

/*
Pdef(\dynamix).play;
Pdef(\dynamix).isPlaying;
Pdef(\dynamix).stop;
*/

////////////////////////////////////////////////////////////////
// PAD

(
SynthDef(\pad, { |attack = 0.05, curve = -16, dur = 1, fb = 0, freq = 400, gate = 1, k = 1, level = 0.03, outbus, release = 0.2, round = 0.1, stan_freq = 100|
	var env				=	Env.asr(attack, level, release, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var stan            =   StandardL.ar([stan_freq - 0.05, stan_freq + 0.05], [k, k - 0.01]).range(0.0, fb);
    //var sinfb1			=	SinOscFB.ar(freq, stan);
    //var sinfb1			=	SinOscFB.ar(freq, fb * LFBrownNoise2.kr(0.2!2).range(0.5, 1));
    var sinfb2			=	SinOscFB.ar(freq!2, fb);
    var roundmod        =   LFBrownNoise2.kr(1!6, mul: 0.01, add: 1);
    //var sinfbmix        =   (sinfb1 + sinfb2).round(round) * envgen;
    //var rhpf            =   RHPF.ar(sinfbmix, (freq * 4).clip(50, SampleRate.ir / 2.5), 0.5);
    //var rhpf            =   RHPF.ar(sinfb1.round(round) * envgen, (freq * 4).clip(50, SampleRate.ir / 2.5), 0.3);
    Out.ar(outbus, sinfb2.round(round * 0.25 * [roundmod[0], roundmod[1]]).round(round * 0.5 * [roundmod[2], roundmod[3]]).round(round * [roundmod[4], roundmod[5]]) * envgen);
}).add;
);

//

(
Pdef(\pad1,
    Pbind(
        \instrument, \pad,
        \attack, 0.03,
        \curve, 0,
        //\degree, Pseq([[-2, 0, 7], [7, 10, 12]], inf),
        \degree, Pshuf(~chords, inf),
        \dur, Pshuf([31, 33, 35, 37, 39] + 0.25, inf),
        \fb, 0.3,
        \k, Pwhite(0.9, 4.0, inf),
        \legato, 1,
        \octave, 5,
        \outbus, ~compressorbus,
        \release, 0.1,
        \root, ~root,
        \round, 0.5,
        \scale, ~scale,
        //\stan_freq, 23
        \stan_freq, 0.2
));

Pdef(\pads1, Ppar([Pdef(\pad1)].stutter(2), inf));

//Pdef(\pads2, Pbindf(Pdef(\pads1)));

Pdef(\padsgroup1, Ppar([Pdef(\pads1)].stutter(2), inf));

/*
Pdef(\pad1).play(t);
Pdef(\pad1).isPlaying;
Pdef(\pad1).stop;
*/

/*
Pdef(\pads1).play(t);
Pdef(\pads1).isPlaying;
Pdef(\pads1).stop;
*/

/*
Pdef(\pads2).play(t, quant: 1);
Pdef(\pads2).isPlaying;
Pdef(\pads2).stop;
*/

/*
Pdef(\padsgroup1).play(t, quant: 1);
Pdef(\padsgroup1).isPlaying;
Pdef(\padsgroup1).stop;
*/

//

(
Pdef(\padlo,
    //Pmono(
        //\pad,
    Pbind(
        \instrument, \pad,
        \attack, 0.1,
        \curve, -4,
        \degree, [0, 7, 12],
        \dur, Pshuf([41, 43, 45, 47, 49] + 0.25, inf),
        \fb, 0.2,
        \k, Pwhite(0.9, 4.0, inf),
        \legato, 1,
        \octave, 4,
        \outbus, ~compressorbus,
        \release, 0.1,
        \root, ~root,
        \round, 0.5,
        \scale, ~scale
));

Pdef(\padslo, Ppar([Pdef(\padlo)].stutter(2), inf));
);
);

/*
Pdef(\padslo).play(t);
Pdef(\padslo).isPlaying;
Pdef(\padslo).stop;
*/

Pdef(\padhi, Pbindf(Pdef(\pad1), \degree, Pshuf(~chord.collect({ |d| [d].stutter(2) }), inf), \fb, 1.5, \legato, 0.5, \octave, 6));

Pdef(\padshi, Ppar([Pdef(\padhi)].stutter(3)));

/*
Pdef(\padshi).play(t);
Pdef(\padshi).isPlaying;
Pdef(\padshi).stop;
*/

//

~midiktrl.value(\padsgroup1, 34);
~midiktrl.value(\padslo, 35);
~midiktrl.value(\padshi, 36);

////////////////////////////////////////////////////////////////
// SIN

(
SynthDef(\sin, { |fb = 0, freq = 440, gate = 1, level = 0.05, outbus|
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin             =   SinOscFB.ar(freq!2, fb, envgen);
    var lor             =   SinOsc.ar(freq * 16 * LorenzL.ar(freq * 32, [10, 9.99], mul: 0.1, add: 1), mul: envgen * 0.1);
    Out.ar(outbus, sin + lor);
}).add;
);

(
Pdef(\sindrone,
    Pmono(
        \sin,
        \dur, 11,
        \degree, [-5, 0],
        \fb, 0.2,
        \octave, 5,
        \outbus, ~compressorbus,
        \release, 0.1,
        \root, ~root,
        \scale, ~scale
));
);

/*
Pdef(\sindrone).play(t);
Pdef(\sindrone).isPlaying;
Pdef(\sindrone).stop;
*/

(
Pdef(\sin,
    Pbind(
        \instrument, \sin,
        \degree, ~chord,
        \dur, 47,
        \fb, 0.2,
        \legato, 0.5,
        \octave, 5,
        \outbus, ~compressorbus,
        \root, ~root,
        \scale, ~scale
));
);

/*
Pdef(\sin).play(t);
Pdef(\sin).isPlaying;
Pdef(\sin).stop;
*/

(
Pdef(\sinlo,
    Pbind(
        \instrument, \sin,
        \dur, 53,
        \degree, 2,
        \fb, 0.5,
        \legato, 0.5,
        \octave, 3,
        \outbus, ~compressorbus,
        \root, ~root,
        \scale, ~scale
));
);

/*
Pdef(\sinlo).play(t);
Pdef(\sinlo).isPlaying;
Pdef(\sinlo).stop;
*/

~midiktrl.value(\sindrone, 32);
~midiktrl.value(\sin, 48);
~midiktrl.value(\sinlo, 64);

////////////////////////////////////////////////////////////////
// TONE

(
SynthDef(\tone, { |curve = -4, dur, fb = 0, freq = 440, level = 0.15, outbus|
    var env             =   Env.perc(0.01, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sin             =   SinOscFB.ar([freq - 0.2, freq + 0.2], fb, envgen);
    Out.ar(outbus, sin);
}).add
);

(
Pdef(\tone1,
    Pbind(
        \instrument, \tone,
        \curve, -4,
        \degree, [-2, 0],
        \dur, Pseq([Pxrand([3, 3.75, 4.25, 5], 15), 23.25], inf),
        \fb, 0.1,
        \octave, 5,
        \outbus, ~compressorbus,
        \root, ~root,
        \scale, ~scale
));

Pdef(\tone2, Pbindf(Pdef(\tone1), \degree, 7));

Pdef(\tones, Ppar([Pdef(\tone1), Pdef(\tone2)], inf));
);

/*
Pdef(\tone1).play(t);
Pdef(\tone1).isPlaying;
Pdef(\tone1).stop;
*/

/*
Pdef(\tone2).play(t);
Pdef(\tone2).isPlaying;
Pdef(\tone2).stop;
*/

/*
Pdef(\tones).play(t);
Pdef(\tones).stop;
*/

~midiktrl.value(\tone1, 33);
~midiktrl.value(\tone2, 49);


////////////////////////////////////////////////////////////////
// SCENES

(
~scenetoggle = { |scene, light, patterns, patternlights, patternstostop, stoplights|
    var scenestatus;
    MIDIdef.cc(scene, {
        if(scenestatus.isNil) {
            ~midiout.control(0, light, 127);
            patternlights.do({ |l| ~midiout.noteOn(0, l, 127) });
            patterns.do({ |s| Pdef(s).play(t) });
            patternstostop.do({ |p| Pdef(p).stop });
            stoplights.do({ |l| ~midiout.noteOff(0, l) });
            scenestatus = "playing";
        } {
            ~midiout.control(0, light, 0);
            patterns.do({ |s| Pdef(s).stop });
            patternlights.do({ |l| ~midiout.noteOff(0, l) });
            scenestatus = nil;
        }
    }, light, srcID: ~lpm.uid, argTemplate: { |a| a > 0 });
}
);

(
~scene1 = [\sindrone, \sin, \tone2];
~scene1lights = [32, 48, 49];
~scenetoggle.value(\scene1, 104, ~scene1, ~scene1lights);
);

(
~scene2 = [\sinlo];
~scene2lights = [64];
~scenetoggle.value(\scene2, 105, ~scene2, ~scene2lights);
);

(
~scene3 = [\tone1, \padsgroup1];
~scene3lights = [33, 34];
~scenetoggle.value(\scene3, 106, ~scene3, ~scene3lights);
);

(
~scene4 = [\padslo];
~scene4lights = [35];
~scenetoggle.value(\scene4, 107, ~scene4, ~scene4lights);
);

(
~scene5 = [\padshi];
~scene5lights = [36];
~scene5stoppers = [\tone1, \tone2];
~scene5stopperlights = [33, 49];
~scenetoggle.value(\scene5, 108, ~scene5, ~scene5lights, ~scene5stoppers, ~scene5stopperlights);
);

(
~scene6stoppers = [\sin, \sinlo];
~scene6stopperlights = [48, 64];
~scenetoggle.value(\scene6, 109, patternstostop: ~scene6stoppers, stoplights: ~scene6stopperlights);
);

(
~scene7stoppers = [\sindrone, \padsgroup1, \padslo, \padshi];
~scene7stopperlights = [32, 34, 35, 36];
~scenetoggle.value(\scene7, 110, patternstostop: ~scene7stoppers, stoplights: ~scene7stopperlights);
);

////////////////////////////////////////////////////////////////
// START EFFECTS

(
{
    s.sync;
    Pdef(\dynamix).play;
}.fork;
);