Pdef.removeAll;

( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
//~nanoktrl2 = 1310720;
//~nanoktrl2 = 1835008;
//~nanoktrl2 = 1572864;
~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("nanoKONTROL2")};
if(~nanoktrl2.isNil) { ~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
);

(
s.meter;
t = TempoClock(108/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);
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
SynthDef(\pad, { | curve = -128, dur = 1, freq = 400, gate = 1, k = 1, level = 0.01, release = 9 |
	var env				=	Env.asr(5, level, release, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var freqmod			=	LFNoise2.kr(0.1!2, 0.0005, 1);
    var xline			=	Line.ar(5, 0.1, dur / 4);
    //var lfn				=	LFNoise0.kr(freq!2).range(0.1, 1.0);
    var lfn             =   StandardN.ar([47,53], [k, k - 0.01]).range(0, 2);
    var sinfb1			=	SinOscFB.ar(freq * freqmod, xline * lfn, envgen / 2);
	var sinfb2			=	SinOscFB.ar(freq, xline, envgen / 2);
	Out.ar(0, sinfb1 + sinfb2);
}).add;
);

(
Pdef(\paddrone,
    Pmono(
        \pad,
        \dur, 53,
        \degree, ~chord,
        \k, Pwhite(0.9, 4.0, inf),
        \octave, [4,5],
        \release, 0.1,
        \scale, ~scale
));

Pdef(\pad1,
    Pbind(
        \instrument, \pad,
        \dur, Pshuf([43, 47, 53, 59, 61], inf),
        \degree, Pshuf(~chord, inf),
        \k, Pwhite(0.9, 4.0, inf),
        \legato, 0.75,
        \octave, 7,
        \release, 0.1,
        \scale, ~scale
));
Pdef(\pads1, Ppar([Pdef(\pad1)].stutter(4), inf));

Pdef(\pads2, Pbindf(Pdef(\pads1), \octave, 5));

Pdef(\pad3, Pbindf(Pdef(\pad1), \degree, [7, 10, 12], \octave, 4));
);

/*
Pdef(\paddrone).play(t, quant: 1);
Pdef(\paddrone).isPlaying;
Pdef(\paddrone).stop;
*/

/*
Pdef(\pads1).play(t, quant: 1);
Pdef(\pads1).isPlaying;
Pdef(\pads1).stop;
*/

/*
Pdef(\pads2).play(t, quant: 1);
Pdef(\pads2).isPlaying;
Pdef(\pads2).stop;
*/

/*
Pdef(\pad3).play(t, quant: 1);
Pdef(\pad3).isPlaying;
Pdef(\pad3).stop;
*/

(
MIDIdef.cc(\paddroneplay, {
	if(Pdef(\paddrone).isPlaying.not) {
		Pdef(\paddrone).play(t);
		"paddrone play".postln;
    }
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\paddronestop, {
	if(Pdef(\paddrone).isPlaying) {
		Pdef(\paddrone).stop;
		"paddrone stop".postln;
    }
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

//

(
MIDIdef.cc(\pads1play, {
    if(Pdef(\pads1).isPlaying.not) {
        Pdef(\pads1).play(t, quant: 0.5);
        "pads1 play".postln;
    };
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pads1stop, {
    if(Pdef(\pads1).isPlaying) {
        Pdef(\pads1).stop;
        "pads1 stop".postln;
    };
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

//

(
MIDIdef.cc(\pads2play, {
    if(Pdef(\pads2).isPlaying.not) {
        Pdef(\pads2).play(t, quant: 0.5);
        "pads2 play".postln;
    };
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pads2stop, {
    if(Pdef(\pads2).isPlaying) {
        Pdef(\pads2).stop;
        "pads2 stop".postln;
    };
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

//

(
MIDIdef.cc(\pad3play, {
    if(Pdef(\pad3).isPlaying.not) {
        Pdef(\pad3).play(t, quant: 0.5);
        "pad3 play".postln;
    };
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad3stop, {
    if(Pdef(\pad3).isPlaying) {
        Pdef(\pad3).stop;
        "pad3 stop".postln;
    };
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// SIN

(
SynthDef(\sin, { |fb = 0, freq = 440, gate = 1, level = 0.005|
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin1            =   SinOscFB.ar(freq * LFNoise2.kr(0.2!2, 0.0003, 1), fb, envgen);
    var sin2            =   SinOscFB.ar([freq - 0.01, freq + 0.01], fb, envgen);
    Out.ar(0, sin1 + sin2);
}).add;
);

(
Pdef(\sin,
    Pbind(
        \instrument, \sin,
        \degree, ~chord,
        \dur, 53,
        \fb, 0.05,
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
        \dur, 73,
        \degree, 2,
        \fb, 0.3,
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


(
MIDIdef.cc(\sinplay, {
    if(Pdef(\sin).isPlaying.not) {
        Pdef(\sin).play(t);
        "sin play".postln;
    }
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\sinstop, {
    if(Pdef(\sin).isPlaying) {
        Pdef(\sin).stop;
        "sin stop".postln;
    }
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\sinloplay, {
    if(Pdef(\sinlo).isPlaying.not) {
        Pdef(\sinlo).play(t);
        "sinlo play".postln;
    }
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\sinlostop, {
    if(Pdef(\sinlo).isPlaying) {
        Pdef(\sinlo).stop;
        "sinlo stop".postln;
    }
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// KIK

(
SynthDef(\kik, { |a = 1.1, c = 0.13, curve = 0, freq = 22050, level = 0.1, pan = 0, releaseTime = 0.01|
	var env				=	Env.perc(0.003, releaseTime, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lc				=	LinCongC.ar(freq, a, c) * envgen;
	var rhpf			=	RHPF.ar(lc, (freq * 4).clip(50, SampleRate.ir / 3), 0.1);
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
        \dur, Pshuf([0.75, 1, 1.25, 1.5, 1.75, 2, 2.25], inf),
		\level, ~prcpatlevel1,
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
        \dur, Pshuf([0.25, 0.5, 0.75, Pseq([1/3], 3), 1, 1.5, 2, 3, 4, 6].stutter(3), inf),
        \level, ~kiklevel,
		\degree, 0!2,
		\octave, 5,
		\releaseTime, 1
));
Pdef(\prcpat1a, Pbindf(Pdef(\prcpat1), \dur, Pshuf([0.25, 0.5].stutter(17), inf), \level, ~prcpatlevel2, \pan, -1));
Pdef(\prcpat1b, Pbindf(Pdef(\prcpat1a), \pan, 1));
Pdef(\prcpar, Ppar([Pdef(\prcpat1), Pdef(\prcpat1a), Pdef(\prcpat1b), Pdef(\prcpat2)], inf));
);

/*
Pdef(\prcpar).play(t, quant: 0.5);
Pdef(\prcpar).isPlaying;
Pdef(\prcpar).stop;
*/

(
MIDIdef.cc(\prcparplay, {
	if(Pdef(\prcpar).isPlaying.not) {
		Pdef(\prcpar).play(t);
		"prc play".postln;
    };
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prcparstop, {
	if(Pdef(\prcpar).isPlaying) {
		Pdef(\prcpar).stop;
		"prc stop".postln;
    };
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////

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
~murkylvl = 0.01;
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
Pdef(\littlemurky, Pbindf(Pdef(\murky), \dur, Pshuf([0.25, 0.5, 0.75].stutter(7), inf), \level, ~murkyecholvl));
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

(
MIDIdef.cc(\murkyplay, {
    if(Pdef(\murkys).isPlaying.not) {
        Pdef(\murkys).play(t, quant: 1);
        "murkys play".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\murkystop, {
    if(Pdef(\murkys).isPlaying) {
        Pdef(\murkys).stop;
        "murkys stop".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0)
);