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
SynthDef(\pad, { |attack = 0.05, curve = -16, dur = 1, fb = 0, freq = 400, gate = 1, k = 1, level = 0.01, release = 1, round = 0.1, stan_freq = 100|
	var env				=	Env.asr(attack, level, release, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var freqmod			=	LFNoise2.kr(0.1!2, 0.0005, 1);
    var stan            =   StandardN.ar([stan_freq - 5, stan_freq + 5], [k, k - 0.01]).range(0.0, fb);
    var sinfb1			=	SinOscFB.ar(freq, stan);
    var sinfb2			=	SinOscFB.ar(freq * freqmod, 0);
    var sinfbmix        =   (sinfb1 + sinfb2).round(round) * envgen;
    var rhpf            =   RHPF.ar(sinfbmix, (freq * 4).clip(50, SampleRate.ir / 2.5));
    Out.ar(0, rhpf);
}).add;
);

(
//~paddurs1 = [41, 45, 49].scramble + 0.25;
//~paddurs2 = ~paddurs1 - 10;
Pdef(\pad1,
    Pbind(
        \instrument, \pad,
        \attack, 0.1,
        \curve, 0,
        \degree, Pseq([[0, 7], [7, 12]], inf),
        //\dur, Pseq(~paddurs1, inf),
        \dur, Pshuf([51, 53, 55], inf),
        \fb, Pshuf([0.5, 1.0, 1.5].stutter(5), inf),
        \k, Pwhite(0.9, 4.0, inf),
        \legato, 0.5,
        \octave, 5,
        \release, 0.1,
        \round, 0.5,
        \scale, ~scale,
        \stan_freq, 50
));

Pdef(\pads1, Ppar([Pdef(\pad1)].stutter(4), inf));

Pdef(\pads2, Pbindf(Pdef(\pads1), \degree, Pshuf([[-2, 2], [2, 10]], inf)));

Pdef(\padsgroup1, Ptpar([0, Pdef(\pads1), 3, Pdef(\pads2)], inf));

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

Pdef(\pads3, Pbindf(Pdef(\pads1), \octave, 6));

Pdef(\pads4, Pbindf(Pdef(\pads2), \octave, 6));

Pdef(\padsgroup2, Ptpar([0, Pdef(\pads3), 4, Pdef(\pads4)], inf));

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

(
Pdef(\pad5,
    //Pmono(
        //\pad,
    Pbind(
        \instrument, \pad,
        \attack, 0.1,
        \degree, [7, 10, 12],
        \dur, 53,
        \fb, 0.3,
        \k, Pwhite(0.9, 4.0, inf),
        \legato, 0.5,
        \octave, 4,
        \release, 0.1,
        \round, 0.5,
        \scale, ~scale
));

Pdef(\pads5, Ppar([Pdef(\pad5)].stutter(4), inf));
);

Pdef(\pads6, Pbindf(Pdef(\pads5), \degree, Pseq([[-2, 2], [2, 10]], inf)));

);

//

/*
Pdef(\pad5).play(t);
Pdef(\pad5).isPlaying;
Pdef(\pad5).stop;
*/

/*
Pdef(\pad6).play(t);
Pdef(\pad6).isPlaying;
Pdef(\pad6).stop;
*/

//

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

~midiktrl.value(\padsgroup1, 33);
~midiktrl.value(\padsgroup2, 34);
~midiktrl.value(\pads5, 35);
~midiktrl.value(\pads6, 51);

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
        \dur, 53,
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
        \degree, Pseq([Rest, 0, Rest, Rest, 0, Rest, Rest, Rest, 0], inf),
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
        \dur, Pshuf([0.25, 0.5, 0.75, Pseq([1/3], 3), 1, 1.5, 2, 3, 4], inf),
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

~midiktrl.value(\prcpar, 36);

/*
(
MIDIdef.cc(\prcparplay, {
	if(Pdef(\prcpar).isPlaying.not) {
		Pdef(\prcpar).play(t);
		"prc play".postln;
    };
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prcparstop, {
	if(Pdef(\prcpar).isPlaying) {
		Pdef(\prcpar).stop;
		"prc stop".postln;
    };
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);
*/

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
~murkylvl = 0.03;
~murkyecholvl = ~murkylvl / 5;
Pdef(\murky,
    Pbind(
        \instrument, \murky,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 1.75, 2, 3, 4, 6], inf),
        \ffreq, Pshuf([8, 16, 32] * 262, inf),
        \k, Pshuf((12..16) / 10, inf),
        \level, ~murkylvl,
        \degree, Pshuf([-2, 0, 1, 2, 3, 7], inf),
        \octave, Pshuf([4, 5, 6, 7], inf),
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

~midiktrl.value(\murkys, 52);

/*
(
MIDIdef.cc(\murkyplay, {
    if(Pdef(\murkys).isPlaying.not) {
        Pdef(\murkys).play(t, quant: 1);
        "murkys play".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\murkystop, {
    if(Pdef(\murkys).isPlaying) {
        Pdef(\murkys).stop;
        "murkys stop".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0)
);
*/

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
~scene2 = [\sinlo, \prcpar];
~scene2lights = [64, 36];
~scenetoggle.value(\scene2, 105, ~scene2, ~scene2lights);
);

(
~scene3 = [\padsgroup1];
~scene3lights = [33];
~scenetoggle.value(\scene3, 106, ~scene3, ~scene3lights);
);

(
~scene4 = [\padsgroup2];
~scene4lights = [34];
~scenetoggle.value(\scene4, 107, ~scene4, ~scene4lights);
);

(
~scene5 = [\pads5];
~scene5lights = [35];
~scene5stoppers = [\sinlo];
~scene5stopperlights = [64];
~scenetoggle.value(\scene5, 108, ~scene5, ~scene5lights, ~scene5stoppers, ~scene5stopperlights);
);

(
~scene6stoppers = [\sin, \murkys];
~scene6stopperlights = [48, 52];
~scenetoggle.value(\scene6, 109, patternstostop: ~scene6stoppers, stoplights: ~scene6stopperlights);
);

(
~scene7stoppers = [\sindrone, \padsgroup1, \padsgroup2, \pads5];
~scene7stopperlights = [32, 33, 34, 35];
~scenetoggle.value(\scene7, 110, patternstostop: ~scene7stoppers, stoplights: ~scene7stopperlights);
);