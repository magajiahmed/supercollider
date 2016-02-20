Pdef.removeAll;

( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
MIDIdef.noteOn(\noteonpostln, { arg ...args; args.postln; });
~lpm = MIDIClient.sources.detect{ |a| a.name.contains("Launchpad") };
//if(~lpm.isNil) { ~lpm = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
~midiout = MIDIOut(0);
~midiout.connect(~lpm.uid);
);

(
s.meter;
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
// Bus depot
~prcfxbus = Bus.audio(s, 2);
// Pitch logic
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 1024/729, 3/2, 14/9, 12/7, 7/4, 243/128];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
~chord = [0, 2, 7, 10, 12];
~chords = [[-5, 2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]];
);

////////////////////////////////////////////////////////
// RECORDING

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////
// COMPANDER

(
SynthDef(\dynamix, { |inBus|
	var in	   		= 	In.ar(inBus, 2);
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.001, slopeAbove: 1/2); // compressor
	Out.ar(0, compressor);
}).add;
);

(
~startdynamix = {
	s.sync;
    ~dynamix = Synth(\dynamix, [\inBus, ~prcfxbus]).register;
}.fork;
);

/*
~dynamix.isPlaying;
~dynamix.free;
*/

////////////////////////////////////////////////////////////////
// PAD

(
SynthDef(\pad, { |attack = 0.05, curve = -16, dur = 1, fb = 0, freq = 400, gate = 1, k = 1, level = 0.04, release = 1, round = 0.1, stan_freq = 100|
	var env				=	Env.asr(attack, level, release, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var freqmod			=	LFNoise2.kr(0.1!2, 0.0003, 1);
    var stan            =   StandardN.ar([stan_freq - 5, stan_freq + 5], [k, k - 0.01]).range(0.0, fb);
    var sinfb1			=	SinOscFB.ar(freq, stan);
    var sinfb2			=	SinOscFB.ar(freq * freqmod, fb * 0.3);
    var sinfbmix        =   (sinfb1 + sinfb2).round(round) * envgen;
    var rhpf            =   RHPF.ar(sinfbmix, (freq * 4).clip(50, SampleRate.ir / 2.5));
    Out.ar(0, rhpf);
}).add;
);

(
Pdef(\pad1,
    Pbind(
        \instrument, \pad,
        \attack, 10,
        \curve, -4,
        \degree, Pshuf([Rest, [0, 7], [7, 12]], inf),
        //\dur, Pseq(~paddurs1, inf),
        \dur, Pshuf([51, 53, 55, 57, 59] + 0.25, inf),
        \fb, Pshuf([0.5, 1.0, 1.5].stutter(5), inf),
        \k, Pwhite(0.9, 4.0, inf),
        \legato, 1,
        \octave, 5,
        \release, 0.1,
        \round, 0.5,
        \scale, ~scale,
        \stan_freq, 50
));

Pdef(\pads1, Ppar([Pdef(\pad1)].stutter(3), inf));

Pdef(\pads2, Pbindf(Pdef(\pads1), \degree, Pshuf([Rest, [-2, 2], [2, 10]], inf)));

Pdef(\padsgroup1, Ppar([Pdef(\pads1), Pdef(\pads2)], inf));

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

Pdef(\pads3, Pbindf(Pdef(\pads1), \dur, Pshuf([31, 33, 35, 37, 39] + 0.25, inf), \octave, 6));

Pdef(\pads4, Pbindf(Pdef(\pads2), \dur, Pshuf([31, 33, 35, 37, 39] + 0.25, inf), \octave, 6));

Pdef(\padsgroup2, Ppar([Pdef(\pads3), Pdef(\pads4)], inf));

/*
Pdef(\pads3).play(t);
Pdef(\pads3).isPlaying;
Pdef(\pads3).stop;
*/

/*
Pdef(\pads4).play(t);
Pdef(\pads4).isPlaying;
Pdef(\pads4).stop;
*/

/*
Pdef(\padsgroup2).play(t);
Pdef(\padsgroup2).isPlaying;
Pdef(\padsgroup2).stop;
*/

//

Pdef(\pads5, Pbindf(Pdef(\pads1), \dur, Pshuf([21, 23, 25, 27, 29] + 0.25, inf), \octave, 7));

Pdef(\pads6, Pbindf(Pdef(\pads2), \dur, Pshuf([21, 23, 25, 27, 29] + 0.25, inf), \octave, 7));

Pdef(\padsgroup3, Ppar([Pdef(\pads5), Pdef(\pads6)], inf));

/*
Pdef(\pads5).play(t);
Pdef(\pads5).isPlaying;
Pdef(\pads5).stop;
*/

/*
Pdef(\pads6).play(t);
Pdef(\pads6).isPlaying;
Pdef(\pads6).stop;
*/

//

(
Pdef(\pad7,
    //Pmono(
        //\pad,
    Pbind(
        \instrument, \pad,
        \attack, 10,
        \curve, -4,
        \degree, Pshuf([Rest, [7, 12]], inf),
        \dur, Pshuf([71, 73, 75, 77, 79] + 0.25, inf),
        \fb, 0.3,
        \k, Pwhite(0.9, 4.0, inf),
        \legato, 0.5,
        \octave, 4,
        \release, 0.1,
        \round, 0.5,
        \scale, ~scale
));

Pdef(\pads7, Ppar([Pdef(\pad7)].stutter(3), inf));
);

Pdef(\pads8, Pbindf(Pdef(\pads7), \degree, Pshuf([Rest, [2, 10]], inf)));

Pdef(\padsgroup4, Ppar([Pdef(\pads7), Pdef(\pads8)], inf));

);

/*
Pdef(\padsgroup4).play(t);
*/
//

~midiktrl.value(\padsgroup1, 34);
~midiktrl.value(\padsgroup2, 35);
~midiktrl.value(\padsgroup3, 36);
~midiktrl.value(\padsgroup4, 37);

////////////////////////////////////////////////////////////////
// SIN

(
SynthDef(\sin, { |fb = 0, freq = 440, gate = 1, level = 0.005|
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin             =   SinOscFB.ar(freq!2, fb, envgen);
    var lor             =   SinOsc.ar(freq * 16 * LorenzL.ar(freq * 32, [10, 9.99], mul: 0.1, add: 1), mul: envgen * 0.1);
    Out.ar(0, sin + lor);
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
        \release, 0.1,
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
        \octave, [3, 4],
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
SynthDef(\tone, { |curve = -4, dur, freq = 440, level = 0.02|
    var env             =   Env.perc(0.01, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    //var sin             =   FBSineC.ar(freq!2, mul: envgen);
    var sin             =   SinOscFB.ar(freq!2, 0.25 * XLine.kr(1, 0.1, dur), envgen);
    Out.ar(0, sin);
}).add
);

(
Pdef(\tone1,
    Pbind(
        \instrument, \tone,
        \curve, -2,
        \degree, 0,
        \dur, Pseq([Pshuf([3, 3.25, 3.5, 3.75, 4].stutter(3)), 23.25], inf),
        \octave, 5,
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
// KIK

(
SynthDef(\kik, { |a = 1.1, c = 0.13, curve = 0, freq = 22050, level = 0.1, pan = 0, releaseTime = 0.01|
	var env				=	Env.perc(0.003, releaseTime, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var lc				=	LinCongC.ar(freq * SinOsc.ar(freq, 0, 0.2, 1), a, c) * envgen;
	var rhpf			=	RHPF.ar(lc, (freq * 4).clip(50, SampleRate.ir / 2.5), 0.1);
	var pan2			=	Pan2.ar(lc + rhpf, pan);
    Out.ar(~prcfxbus, pan2).fold2(level);
}).add;
);

(
~kiklevel = 0.25;
~prcpatlevel1 = 0.15;
~prcpatlevel2 = ~prcpatlevel1 / 5;
Pdef(\prcpat1,
	Pbind(
		\instrument, \kik,
        \a, Pshuf([1.15, 1.2, 1.25], inf),
        \c, Pshuf([0.05, 0.07, 0.09, 0.11, 0.13, 0.15], inf),
		\curve, -64,
        //\dur, Pshuf([0.5, 1, Pseq([0.75], 2)].stutter(3), inf),
        \dur, Pshuf([0.75, 1, 1.25, 1.5, 1.75], inf),
		\level, ~prcpatlevel1,
        //\degree, Pseq([Pseq([Rest, 0, Rest, Rest, 0, Rest, Rest, Rest, 0], 5), Pseq([Rest], 45)], inf),
        \degree, Pseq([Rest, Rest, Rest, 0, Rest, Rest, Rest, Rest, 0, Rest, Rest, Rest, Rest, Rest, 0], inf),
        \octave, Pshuf([[7, 12], [7, 13], [7, 14], [9, 12], [9, 13], [9, 14]], inf),
		\scale, ~scale,
		\releaseTime, 0.5
));

Pdef(\prcpat2,
	Pbind(
		\instrument, \kik,
        \a, Pshuf([0.9, 1.0, 1.1, 1.2, 1.3], inf),
        //\c, Pwhite([0.07, 0.11, 0.15], inf),
        \c, 0.15,
		\curve, -16,
        \dur, Pshuf([0.25, 0.25, Pseq([0.25], 2), 0.5, 0.75, Pseq([1/3], 3), 1, 1.5, 2, 3, 4], inf),
        \level, ~kiklevel,
        \degree, Pseq([Pseq(0!2, 11), Pseq([Rest], 22)], inf),
		\octave, 5,
		\releaseTime, 1
));
Pdef(\prcpat1a, Pbindf(Pdef(\prcpat1), \dur, Pshuf([0.25, 0.5, 0.75].stutter(17), inf), \level, ~prcpatlevel2, \pan, -1));
Pdef(\prcpat1b, Pbindf(Pdef(\prcpat1a), \pan, 1));
Pdef(\prcpat1c, Pbindf(Pdef(\prcpat1), \dur, 1));
Pdef(\prcpar, Ppar([Pdef(\prcpat1), Pdef(\prcpat1a), Pdef(\prcpat1b), Pdef(\prcpat1c), Pdef(\prcpat2)], inf));
);

/*
Pdef(\prcpar).play(t, quant: 0.5);
Pdef(\prcpar).isPlaying;
Pdef(\prcpar).stop;
*/

//~midiktrl.value(\prcpar, 36);

////////////////////////////////////
// MURKY

(
SynthDef(\murky, { | bwr = 1, curve = -64, dur = 1, ffreq = 4000, freq = 400, k = 1.4, level = 0.1, pan = 0 |
	var env				=	Env.new([0, level, level / 10, 0], [0.005, 0.05, dur / 2]);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var stan			=	Standard2DN.ar(300, 3000, k: k, mul: 1, add: 1);
	var fbfreqmod		=	LFNoise0.kr(0.5).range(1, 30);
	var fbmod			=	LFNoise1.kr(fbfreqmod).range(0, 0.999);
	var sinfb			=	SinOscFB.ar(freq * stan, 0.999, mul: envgen);
	var lfn				=	LFNoise1.kr(1 / (dur * 10), mul: 1, add: 1);
    var rlpf			=	RLPF.ar(sinfb, ffreq.clip(50, SampleRate.ir / 3), 0.05);
	var lfndelaymod		=	LFNoise0.kr(5).range(0.005, 0.05);
	var delay			=	DelayC.ar(rlpf, 0.2, freq.reciprocal);
	var pan2			=	Pan2.ar(rlpf + delay, pan);
	Out.ar(~prcfxbus, pan2);
}).add;
);

(
~murkylvl = 0.025;
~murkyecholvl = ~murkylvl / 5;
Pdef(\murky,
    Pbind(
        \instrument, \murky,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 1.75, 2, 3, 4, 6], inf),
        \ffreq, Pshuf([8, 16, 32] * 262, inf),
        \k, Pshuf((12..16) / 10, inf),
        \level, ~murkylvl,
        \degree, Pshuf([-2, 0, 1, 2, 3, 7], inf),
        \octave, Pshuf([3, 5, 7], inf),
        \scale, ~scale
));
Pdef(\littlemurky, Pbindf(Pdef(\murky), \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5].stutter(7), inf), \level, ~murkyecholvl));
Pdef(\murkys, Ppar([Pdef(\murky), Pdef(\littlemurky)], inf));
);

/*
Pdef(\murky).play(t, quant: 1);
Pdef(\murky).isPlaying;
Pdef(\murky).stop;
*/

/*
Pdef(\littlemurky).play(t, quant: 1);
Pdef(\littlemurky).isPlaying;
Pdef(\littlemurky).stop;
*/

/*
Pdef(\murkys).play(t, quant: 1);
Pdef(\murkys).isPlaying;
Pdef(\murkys).stop;
*/

//~midiktrl.value(\murkys, 52);

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
~scene1 = [\sindrone, \sin];
~scene1lights = [32, 48];
~scenetoggle.value(\scene1, 104, ~scene1, ~scene1lights);
);

(
~scene2 = [\sinlo];
~scene2lights = [64];
~scenetoggle.value(\scene2, 105, ~scene2, ~scene2lights);
);

(
~scene3 = [\padsgroup1, \tone2];
~scene3lights = [34, 49];
~scenetoggle.value(\scene3, 106, ~scene3, ~scene3lights);
);

(
~scene4 = [\padsgroup2];
~scene4lights = [35];
~scenetoggle.value(\scene4, 107, ~scene4, ~scene4lights);
);

(
~scene5 = [\tone1, \padsgroup3];
~scene5lights = [33, 36];
~scenetoggle.value(\scene5, 108, ~scene5, ~scene5lights);
);

(
~scene6 = [\padsgroup4];
~scene6lights = [37];
~scenetoggle.value(\scene6, 109, ~scene6, ~scene6lights);
);

(
~scene7stoppers = [\sindrone, \sin, \sinlo, \tone1, \tone2];
~scene7stopperlights = [32, 48, 64];
~scenetoggle.value(\scene7, 110, patternstostop: ~scene7stoppers, stoplights: ~scene7stopperlights);
);

(
~scene8stoppers = [\padsgroup1, \padsgroup2, \padsgroup3, \padsgroup4];
~scene8stopperlights = [34, 35, 36, 37];
~scenetoggle.value(\scene8, 111, patternstostop: ~scene8stoppers, stoplights: ~scene8stopperlights);
);