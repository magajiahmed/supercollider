////////////////////////////////////////////////////////////////
// INIT

// clear all patterns

Pdef.removeAll;

( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { |...args| args.postln; });
~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("nanoKONTROL2")};
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~nanoktrl2.isNil) { ~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
~midiout =  MIDIOut(0);
~midiout.connect(~nanoktrl2.uid);
);

(
s.meter;
t = TempoClock(96/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);
);

(
~bassfxbus = Bus.audio(s, 2);
~prcfxbus = Bus.audio(s, 2);
~verbus = Bus.audio(s, 2);
~ratios = [1/1, 16/15, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 12/7, 7/4, 15/8];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
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
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.001, slopeAbove: 1/128); // compressor
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
// verb

(
SynthDef(\verb, { |gate = 1, inBus, level = 0.1|
    var env             =   Env.asr(0.01, level, 0.1, -64);
    var envgen          =   EnvGen.ar(env, gate, doneAction: 2);
    var in              =   In.ar(inBus, 2);
    var verb            =   JPverb.ar(in, t60: 5, size: 0.1, earlyDiff: 0.1, modDepth: 0.0, modFreq: 0.0).round(0.01) * envgen;
    //var comb            =   CombC.ar(verb, 1, LFNoise0.ar(100!2).range(0.999, 1));
    var grainin         =   GrainIn.ar(2, Dust.kr(30!2), 0.01, verb);
    //var balance         =   Balance2.ar(grainin[0], grainin[1], LFClipNoise.ar(1));
    Out.ar(0, grainin);
}).add;
);

(
Pdef(\verb,
    Pbind(
        \instrument, \verb,
        \dur, Pshuf([0.25, 0.5, 1, 2, 4, 8, 16, 32, 64], inf),
        \inBus, ~verbus,
        \legato, 1,
));

Pdef(\verbs, Ppar([Pdef(\verb)].stutter(2), inf));
);

/*
Pdef(\verbs).play(t);
Pdef(\verbs).isPlaying;
Pdef(\verbs).stop;
*/

////////////////////////////////////////////////////////////////
// dingle

(
SynthDef(\dingle, { | a = 0.02, curve = -16, freq = 10000, level = 0.2, pan = 0 |
	var env				=	Env.perc(releaseTime: 1, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq * 4, a, 3, add: 1);
	var sin				=	SinOsc.ar(freq * (cusp), mul: envgen);
	var rez				=	Resonz.ar(sin, 6000, 0.1);
	var pan2			=	Pan2.ar(rez, pan);
	Out.ar(~prcfxbus, pan2).fold(-0.5, 0.5);
}).add;
);

// Pattern

(
~dinglelvl = 0.1;
~dingleecholvl = ~dinglelvl / 5;
Pdef(\dinglepat1,
	Pbind(
		\instrument, \dingle,
		\a, 0.01,
		\curve, -4,
    	\dur, Pshuf([
            Pseq([1.25], 3),
            Pseq([1.5], 3),
            Pseq([1.75], 3),
            Pseq([2], 3),
            Pseq([2.25], 3),
		], inf),
		\level, ~dinglelvl,
		\octave, 5,
		\scale, ~scale,
));
Pdef(\dinglepat1a, Pbindf(Pdef(\dinglepat1), \level, ~dingleecholvl, \pan, -1));
Pdef(\dinglepat1b, Pbindf(Pdef(\dinglepat1a), \pan, 1));
Pdef(\dinglepat2, Pbindf(Pdef(\dinglepat1), \octave, 7));
Pdef(\dinglepat2a,
    Pbindf(
        Pdef(\dinglepat2),
        \level, ~dingleecholvl,
        \pan, -1
));
Pdef(\dinglepat2b, Pbindf(Pdef(\dinglepat2a), \pan, 1));
Pdef(\dinglepar2,
    Ppar([
        Pdef(\dinglepat1), Pdef(\dinglepat1a), Pdef(\dinglepat1b), Pdef(\dinglepat2a), Pdef(\dinglepat2a), Pdef(\dinglepat2b)
], inf));
);

/*
Pdef(\dinglepar2).play(t, quant: 0.5);
Pdef(\dinglepar2).isPlaying;
Pdef(\dinglepar2).stop;
*/

(
Pdef(\single1,
    Pbind(
        \instrument, \dingle,
        \a, Pwhite(0.01, 0.02, inf),
        \curve, -64,
        \degree, 7,
        \dur, Pshuf(Array.fill(5, { |d| (d + 1) * 0.25 }).stutter(5), inf),
        \level, Pshuf([0.2, 1].stutter(5) * 0.2, inf),
        \octave, 7,
        \pan, Pshuf([-1, -0.5, 0, 0.5, 1], inf),
        \scale, ~scale
));

Pdef(\single2, Pbindf(Pdef(\single1), \dur, 0.25, \level, 0.04));
);

/*
Pdef(\single1).play(t, quant: 0.5);
Pdef(\single1).isPlaying;
Pdef(\single1).stop;
*/

/*
Pdef(\single2).play(t, quant: 0.5);
Pdef(\single2).isPlaying;
Pdef(\single2).stop;
*/

// Midi Control

(
MIDIdef.cc(\dingleparplayktrl, {
	if(Pdef(\dinglepar2).isPlaying.not) {
        ~midiout.control(0, 32, 127);
		Pdef(\dinglepar2).play(t, quant: 0.5);
		"dingle play".postln;
	};
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\dinglestopktrl, {
    if(Pdef(\dinglepar2).isPlaying) {
        ~midiout.control(0, 32, 0);
        Pdef(\dinglepar2).stop;
        "dingle stop".postln;
    }
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\single1play, {
    if(Pdef(\single1).isPlaying.not) {
        ~midiout.control(0, 33, 127);
        Pdef(\single1).play(t, quant: 0.5);
        "single1 play".postln
    };
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\single1stop, {
    if(Pdef(\single1).isPlaying) {
        ~midiout.control(0, 33, 0);
        Pdef(\single1).stop;
        "single1 stop".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\single2play, {
    if(Pdef(\single2).isPlaying.not) {
        ~midiout.control(0, 49, 127);
        Pdef(\single2).play(t, quant: 0.5);
        "single2 play".postln
    };
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\single2stop, {
    if(Pdef(\single2).isPlaying) {
        ~midiout.control(0, 49, 0);
        Pdef(\single2).stop;
        "single2 stop".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// snap

// Synth

(
SynthDef(\snap, { | curve = -512, dur = 1, freq = 400, im = 1, level = 0.1, rt = 0.1 |
	var env				=	Env.new([0, level, level / 40, 0], [0.005, 0.005, dur], curve: 'cubed');
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var fbs				=	FBSineC.ar(freq: freq, im: [im, im + 1], mul: envgen);
	var flt				=	RHPF.ar(fbs, 2000, 0.5);
	Out.ar(~prcfxbus, flt);
}).add;
);

// Pattern

(
Pdef(\snappat,
	Pbind(
		\instrument, \snap,
		\degree, [2, 7],
		\dur, Pshuf([0.5, 0.75, 1, 1.5, 2, 3].stutter(7), inf),
		\im, Pshuf((1..10), inf),
		\level, 0.05,
		\octave, 10,
		\scale, ~scale,
));
);

/*
Pdef(\snappat).play(t, quant: 0.5);
Pdef(\snappat).isPlaying;
Pdef(\snappat).stop;
*/

// Midi control

(
MIDIdef.cc(\snapplayktrl, {
	if(Pdef(\snappat).isPlaying.not) {
        ~midiout.control(0, 48, 127);
		Pdef(\snappat).play(t, quant: 0.5);
		"snap play".postln;
	};
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\snapstopktrl, {
	if(Pdef(\snappat).isPlaying) {
        ~midiout.control(0, 48, 0);
		Pdef(\snappat).stop;
		"snap stop".postln;
	};
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// xaos

(
SynthDef(\xaos, { |chaos = 1.5, curve = -16, dur = 1, freq = 440, level = 0.3, resonz_freq = 4000, rhpf_freq = 8000, rlpf_freq = 2000|
    var env             =   Env.perc(0.01, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var xaos            =   Crackle.ar(chaos!2).round(0.05) * envgen;
    var resonz          =   Resonz.ar(xaos, resonz_freq.clip(50, SampleRate.ir / 2.5), 0.3) * LFClipNoise.ar(80).range(0.5, 1);
    var rhpf            =   RHPF.ar(xaos, rhpf_freq.clip(50, SampleRate.ir / 2.5), 0.5) * LFClipNoise.ar(80).range(0.5, 1);
    Out.ar(~prcfxbus, (resonz + rhpf).fold2(level).tanh);
}).add;
);

(
Pdef(\xaos,
    Pbind(
        \instrument, \xaos,
        \curve, Prand([-64, -32, -16], inf),
        \dur, Pseq([Pseq([0.125], 2), Pshuf(Array.fill(7, { |i| (i) * 0.25 }).stutter(11))], inf),
        \resonz_freq, Pshuf(Array.fill(5, { |i| pi.pow(i + 4) }).stutter(5), inf),
        //\rlpf_freq, Pshuf([100, 10000].stutter(5), inf),
        \rhpf_freq, Pshuf([1000, 10000].stutter(3), inf),
        \chaos, Pshuf([1.0, 2.0].stutter(11), inf)
));
);

/*
Pdef(\xaos).play(t);
Pdef(\xaos).isPlaying;
Pdef(\xaos).stop;
*/

(
MIDIdef.cc(\xaosplay, {
    if(Pdef(\xaos).isPlaying.not) {
        ~midiout.control(0, 64, 127);
        Pdef(\xaos).play(t);
        "xaos".postln;
    }
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\xaosstop, {
    if(Pdef(\xaos).isPlaying) {
        ~midiout.control(0, 64, 0);
        Pdef(\xaos).stop;
        "xaos stop".postln;
    }
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// sinprc

(
SynthDef(\sinprc, { |curve = -16, fb = 2.5, ffreq = 4000, freq = 440, gfreq = 22050, level = 0.1, xi = 1.2, yi = 2.1|
    var env             =   Env.perc(0.01, 0.3, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var gbman           =   GbmanL.ar([gfreq, gfreq - 1], xi, yi, 0.25, 1);
    var sin             =   SinOscFB.ar(freq * gbman * XLine.kr(1, 0.1, 0.1), fb, envgen);
    var rhpf            =   RHPF.ar(sin, ffreq.clip(50, SampleRate.ir / 2.5), 0.5);
    Out.ar(~prcfxbus, rhpf.fold2(level));
}).add;
);

(
Pdef(\sinprc,
    Pbind(
        \instrument, \sinprc,
        \curve, Pshuf([-64, -32, -16].stutter(7), inf),
        \dur, Pshuf([Pseq([0.125], 2), 0.25, 0.5, Pseq([0.25], 3), 0.75, 1, Pseq([0.25], 6), 1.5, 2, 3].stutter(3), inf),
        \fb, Pshuf([1, 2, 3].stutter(17), inf),
        \ffreq, Pshuf([100, 10000].stutter(9), inf),
        \freq, Pshuf([100, 1000, 10000].stutter(13), inf),
        \xi, Pshuf([-0.5, 0, 0.5].stutter(5), inf),
        \yi, Pshuf([-2, 0, 2].stutter(7), inf)
));
);

/*
Pdef(\sinprc).play(t);
Pdef(\sinprc).isPlaying;
Pdef(\sinprc).stop;
*/

(
MIDIdef.cc(\sinprcplay, {
    if(Pdef(\sinprc).isPlaying.not) {
        ~midiout.control(0, 65, 127);
        Pdef(\sinprc).play(t);
        "sinprc play".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\sinprcstop, {
    if(Pdef(\sinprc).isPlaying) {
        ~midiout.control(0, 65, 0);
        Pdef(\sinprc).stop;
        "sinprc stop".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// clip noise percussion

(
SynthDef(\cnprc, { |bal = 0, curve = -16, freq = 500, level = 0.03, outbus = 0, releaseTime = 0.1, rhpf_cutoff_start = 1, rhpf_cutoff_end = 1|
    var env             =   Env.perc(0.003, releaseTime, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var blip            =   Blip.ar(0, mul: envgen);
    var clipnoiz        =   LFClipNoise.ar(freq!2, envgen);
    var rlpf            =   BLowPass4.ar(blip + clipnoiz, freq.clip(50, SampleRate.ir / 2.5), 0.1);
    //var rhpf            =   RHPF.ar(blip + clipnoiz, (freq * 4).clip(50, SampleRate.ir / 2.5), 0.2);
    var rhpf            =   RHPF.ar(blip + clipnoiz, (12000 * XLine.ar(rhpf_cutoff_start, rhpf_cutoff_end, releaseTime)).clip(50, SampleRate.ir / 2.5), 0.1);
    var balance         =   Balance2.ar((rlpf + rhpf)[0], (rlpf + rhpf)[1], bal);
    Out.ar(~prcfxbus, balance);
}).add;
);

(
//~cnprcfrqs = [100, 500, 1000, 100, 100, 500, 1000, 100, 100, 100, 500, 1000];
~cnprcfrqs = Array.fill(5, { |i| pi.pow(i) * 50});
~cnprclvl = 0.03;
~cnprcecholvl = ~cnprclvl / 4;
Pdef(\cnprc1,
    Pbind(
        \instrument, \cnprc,
        \bal, Pshuf([-1, -0.5, -0.25, 0, 0.25, 0.5, 1], inf),
        \curve, -2,
        \dur, Pshuf(Array.fill(11, { |d| (d + 1) * (0.25) }), inf),
        \freq, Pshuf(~cnprcfrqs.stutter(3), inf),
        \level, ~cnprclvl,
        \releaseTime, Pshuf([0.05, 0.07, 0.09, 0.11, 0.13, 0.15, 0.17, 0.19, 0.21, 0.23], inf),
        \rhpf_cutoff_start, Pshuf([0.2, 1.0].stutter(3), inf),
        \rhpf_cutoff_end, Pshuf([0.2, 1].stutter(5), inf)
));
Pdef(\cnprc2, Pbindf(Pdef(\cnprc1), \level, ~cnprcecholvl));
Pdef(\cnprcpar, Ppar([Pdef(\cnprc1), Pdef(\cnprc2)], inf));
);

(
Pdef(\cnprc3,
    Pbindf(
        Pdef(\cnprc1),
        \curve, -16,
        \dur, Pshuf([0.25, 0.5, 0.75, 1].stutter(11), inf),
        \freq, Prand(~cnprcfrqs * 4, inf)
));
);

/*
Pdef(\cnprcpar).play(t, quant: 0.5);
Pdef(\cnprcpar).isPlaying;
Pdef(\cnprcpar).stop;
*/

/*
Pdef(\cnprc3).play(t, quant: 0.5);
Pdef(\cnprc3).isPlaying;
Pdef(\cnprc3).stop;
*/

(
MIDIdef.cc(\cnplayktrl, {
	if(Pdef(\cnprcpar).isPlaying.not) {
        ~midiout.control(0, 34, 127);
		Pdef(\cnprcpar).play(t, quant: 0.5);
		"cnprc play".postln;
	};
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\cnstopktrl, {
	if(Pdef(\cnprcpar).isPlaying) {
        ~midiout.control(0, 34, 0);
		Pdef(\cnprcpar).stop;
		"cnprc stop".postln;
	};
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\cn3playktrl, {
	if(Pdef(\cnprc3).isPlaying.not) {
        ~midiout.control(0, 50, 127);
		Pdef(\cnprc3).play(t, quant: 0.5);
		"cnprc3 play".postln;
	};
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\cn3stopktrl, {
	if(Pdef(\cnprc3).isPlaying) {
        ~midiout.control(0, 50, 0);
		Pdef(\cnprc3).stop;
		"cnprc3 stop".postln;
	};
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// LORI

(
SynthDef(\lori, { |balance = 0, curve = -16, dur = 1, freq = 440, length = 1, level = 0.1, lfreq = 22050, lorimul = 1, r = 28, s = 10, start = 1, end = 1|
    var env             =   Env.perc(0.005, length, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var lori            =   LorenzL.ar(lfreq * XLine.ar(start, end, length), [s, s - 0.05], [r, r - 0.05], mul: lorimul, add: 1);
    var sin             =   SinOsc.ar(freq * lori, mul: envgen);
    var bal             =   Balance2.ar(sin[0], sin[1], balance);
    Out.ar(~prcfxbus, bal);
}).add;
);

(
Pdef(\lori,
    Pbind(
        \instrument, \lori,
        \balance, Pshuf([-0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75], inf),
        \curve, Pshuf([-64, -32, -16].stutter(7), inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5].stutter(9), inf),
        \freq, Pshuf([64, 8192].stutter(3), inf),
        \length, Pshuf([0.5, 0.75, 1].stutter(11), inf),
        \lorimul, Pshuf([0.5, 1, 2, 4].stutter(17), inf),
        \r, Pshuf((29..40), inf),
        \s, Pshuf((8..12), inf),
        \start, Pshuf([0.2, 0.4, 0.6, 0.8, 1.0], inf),
        \end, Pshuf([0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0], inf)
));
);

/*
Pdef(\lori).play(t);
Pdef(\lori).isPlaying;
Pdef(\lori).stop;
*/

(
MIDIdef.cc(\loriplay, {
    if(Pdef(\lori).isPlaying.not) {
        ~midiout.control(0, 66, 127);
        Pdef(\lori).play(t);
        "lori play".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\loristop, {
    if(Pdef(\lori).isPlaying) {
        ~midiout.control(0, 66, 0);
        Pdef(\lori).stop;
        "lori stop".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PAD

(
SynthDef(\pad, { |a = 1.1, curve = -4, dur = 1, fb = 0, freq = 400, freqmod_start = 1, gate = 1, level = 0.002|
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin1            =   SinOscFB.ar(freq!2 * XLine.ar(freqmod_start, 1, 0.05), fb, envgen);
    //var sin2            =   SinOscFB.ar(freq!2, 2.5).round(0.01) * envgen;
    //var sin3            =   SinOscFB.ar(freq!2, 2.5).round(0.1) * envgen;
    //var rhpf            =   RHPF.ar(sin3, (freq * 32).clip(50, SampleRate.ir / 2.5), 0.1) * LFClipNoise.kr(11!2).range(0, 1);
    Out.ar(0, sin1);
}).add;
);

(
Pdef(\pad1,
    Pbind(
        \instrument, \pad,
        \bal, Pshuf([-0.5, 0, 0.5].stutter(13), inf),
        \dur, Pshuf(Array.fill(7, { |i| (i + 25).nthPrime }), inf),
        \fb, 1.5,
        \freqmod_start, Pshuf([0.125, 0.25, 0.5, 2, 4], inf),
        \legato, 0.25,
        \degree, Pshuf([[0, 7, 10], [7, 10, 12], [10, 12, 19]], inf),
        \octave, Pshuf([5, 6, 7].powerset.reject ({ |i| i.isEmpty }), inf),
        \scale, ~scale,
));
//Pdef(\pad2, Pbindf(Pdef(\pad1)));
//Pdef(\pad3, Pbindf(Pdef(\pad1)));
//Pdef(\pad4, Pbindf(Pdef(\pad1)));
Pdef(\pads, Ptpar([0, Pdef(\pad1), 11.25, Pdef(\pad1), 13.25, Pdef(\pad1), 17.25, Pdef(\pad1)]));
);

/*
Pdef(\pads).play(t, quant: 0.5);
Pdef(\pads).isPlaying;
Pdef(\pads).stop;
*/

//Pdef(\paddrone, Pmono(\pad, \degree, [7, 12], \dur, 31, \octave, 4, \scale, ~scale));
Pdef(\paddrone, Pbind(\instrument, \pad, \degree, [7, 12], \dur, 101.25, \fb, 0.5, \legato, 0.25, \scale, ~scale));

/*
Pdef(\paddrone).play(t, quant: 0.5);
Pdef(\paddrone).isPlaying;
Pdef(\paddrone).stop;
*/

(
MIDIdef.cc(\padsplayktrl, {
    if(Pdef(\pads).isPlaying.not) {
        ~midiout.control(0, 35, 127);
		Pdef(\pads).play(t, quant: 0.5);
		"pads play".postln;
	}
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\padsstopktrl, {
    if(Pdef(\pads).isPlaying) {
        ~midiout.control(0, 35, 0);
		Pdef(\pads).stop;
		"pads stop".postln;
	}
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\paddroneplayktrl, {
    if(Pdef(\paddrone).isPlaying.not) {
        ~midiout.control(0, 51, 127);
		Pdef(\paddrone).play(t, quant: 0.5);
		"pad drone play".postln;
	}
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\paddronestopktrl, {
    if(Pdef(\paddrone).isPlaying) {
        ~midiout.control(0, 51, 0);
		Pdef(\paddrone).stop;
		"pads stop".postln;
	}
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// LARRY

(
SynthDef(\larry, { |curve = -4, dur = 1, fb = 0, freq = 440, gate = 1, level = 0.002, s = 10|
    var env             =   Env.asr(0.01, level, 0.01, curve);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var frqmod          =   Lorenz2DN.ar(15, 15000, s: [s, s - 0.001],  mul: 0.9, add: 1);
    var sinmod          =   SinOscFB.ar(freq * 8 * frqmod, fb, envgen / 8);
    var sin1            =   SinOscFB.ar(freq, fb, envgen);
    var sin2            =   SinOsc.ar(freq * LFNoise0.kr(15, 0.003, 1), mul: envgen);
    Out.ar(0, sinmod + sin1 + sin2);
}).add;
);

(
Pdef(\larry1,
	Pbind(
		\instrument, \larry,
        \curve, -32,
        \dur, Pshuf(Array.fill(5, { |i| (i + 9).nthPrime }) + 0.25, inf),
        \fb, 0,
        \legato, 0.5,
        \degree, Pseq([[7, 12], Rest], inf),
        \octave, 5,
        \s, Pwhite(8.0, 12.0, inf),
        \scale, ~scale
));


Pdef(\larry2,
	Pbindf(
		Pdef(\larry1),
        \degree, Pshuf([[7, 10, 12], Rest], inf),
));

Pdef(\larry3,
	Pbindf(
		Pdef(\larry1),
        \degree, Pshuf([[7, 12, 13], Rest], inf)
));

Pdef(\larry4, Pbindf(Pdef(\larry1), \degree, Pshuf([0, Rest], inf), \octave, 4));

Pdef(\larrys, Ppar([Pdef(\larry1), Pdef(\larry1), Pdef(\larry1), Pdef(\larry2), Pdef(\larry3), Pdef(\larry4)], inf));
);

/*
Pdef(\larry1).play(t, quant: 0.5);
Pdef(\larry1).isPlaying;
Pdef(\larry1).stop;
*/

/*
Pdef(\larry2).play(t, quant: 0.5);
Pdef(\larry2).isPlaying;
Pdef(\larry2).stop;
*/

/*
Pdef(\larry3).play(t, quant: 0.5);
Pdef(\larry3).isPlaying;
Pdef(\larry3).stop;
*/

/*
Pdef(\larry4).play(t, quant: 0.5);
Pdef(\larry4).isPlaying;
Pdef(\larry4).stop;
*/

/*
Pdef(\larrys).play(t, quant: 0.5);
Pdef(\larrys).isPlaying;
Pdef(\larrys).stop;
*/

(
MIDIdef.cc(\larryplay, {
    if(Pdef(\larrys).isPlaying.not) {
        ~midiout.control(0, 67, 127);
        Pdef(\larrys).play(t, quant: 0.5);
        "Hi Larry".postln;
    }
}, 67, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\larrynoplay, {
    if(Pdef(\larrys).isPlaying) {
        ~midiout.control(0, 67, 0);
        Pdef(\larrys).stop;
        "Bye Larry".postln;
    }
}, 67, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////
// BASS

// SynthDef

(
SynthDef(\abass, { |curve = -4, dur = 1, fb = 0, ffreq = 4000, freq = 440, level = 0.05|
    var env             =   Env.perc(0.001, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var xline           =   XLine.kr(1, 0.1, 1);
    var sinfb           =   SinOscFB.ar([freq, freq + 0.05], fb * xline).round(0.4) * envgen;
    //var rlpf_freq_mod   =   LFNoise2.kr(1!2).range(1, 8);
    var rlpf            =   BLowPass4.ar(sinfb, (freq * XLine.kr(pi.squared, pi.sqrt, 0.1)).clip(30, SampleRate.ir / 3), 0.5);
    var rhpf            =   BHiPass4.ar(sinfb, (ffreq).clip(50, SampleRate.ir / 3), 0.3);
    Out.ar([0, ~bassfxbus], rlpf + rhpf);
}).add;
);

// Pattern

(
//~bassnotes = [-5, -4, -3, -2, -1, 0, 1, 2, 3];
~bassnotes = [-5, -2, 1, 2, 3];
~bassdurations = [0.25, 0.5, Pseq([0.25], 3), 0.75, 1, 1.5, 2, Pseq([0.75], 3), 3, 4, 6, 8, 12, 16, 24];
Pdef(\bass,
	Pbind(
        \instrument, \abass,
        \degree, Pseq([Pshuf(~bassnotes.stutter(4)), Pseq([Rest], ~bassnotes.size * 3)], inf),
		\dur, Pshuf(~bassdurations, inf),
        \fb, Pshuf([0.25, 0.5, 1, 2].stutter(5), inf),
        \ffreq, 4000,
        \octave, 3,
		\scale, ~scale,
));

Pdef(\bass2,
    Pbind(
        \instrument, \abass,
        \degree, 0,
        \dur, Pshuf(~bassdurations, inf),
        \fb, Pshuf([0.25, 0.5, 1, 2].stutter(7), inf),
        \ffreq, 6000,
        \octave, [2, 3],
        \scale, ~scale
));
);

/*
Pdef(\bass).play(t, quant: 0.5);
Pdef(\bass).isPlaying;
Pdef(\bass).stop;
*/

/*
Pdef(\bass2).play(t, quant: 0.5);
Pdef(\bass2).isPlaying;
Pdef(\bass2).stop;
*/

// Midi Control

(
MIDIdef.cc(\bassplayktrl, {
    if(Pdef(\bass).isPlaying.not) {
        ~midiout.control(0, 36, 127);
        Pdef(\bass).play(t, quant: 0.5);
        "bass play".postln;
    };
}, 36, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\basspause, {
    if(Pdef(\bass).isPlaying) {
        ~midiout.control(0, 36, 0);
        Pdef(\bass).stop;
        "bass stop".postln;
    };
}, 36, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\bass2play, {
    if(Pdef(\bass2).isPlaying.not) {
        ~midiout.control(0, 68, 127);
        Pdef(\bass2).play(t, quant: 0.5);
        "bass2 play".postln;
    };
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\bass2stop, {
    if(Pdef(\bass2).isPlaying) {
        ~midiout.control(0, 68, 0);
        Pdef(\bass2).stop;
        "bass2 pause".postln;
    };
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////
// BUFFER-STUTTER

(
SynthDef(\recbuf, { | dur = 2, gate = 1, inBus = 2, isRecording = 1, trigger = 1 |
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var in				=	In.ar(inBus, b.numChannels);
	var recbuf 			=	RecordBuf.ar(in, b.bufnum, recLevel: envgen, run: isRecording, loop: 0, trigger: trigger, doneAction: 2);
}).add;
);

(
SynthDef(\bufrd, { | dur = 1, ffreq = 3000, gate = 1, level = 1, pan = 0 |
	//var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.003, level, 0.1);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(b.numChannels, b.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var rhpf			=	RHPF.ar(bufrd, ffreq, 0.3, envgen * 2);
	var pan2			=	Pan2.ar(rhpf, pan);
	Out.ar(0, pan2);
}).add;
);

(
Pdef(\rbpdef,
	Pbind(
		\instrument, \recbuf,
        \inBus, ~bassfxbus,
		\dur, 6,
));
);

/*
Pdef(\rbpdef).play(t, quant: 3);
Pdef(\rbpdef).isPlaying;
Pdef(\rbpdef).stop;
b.plot;
*/

(
Pdef(\pbpat,
	Pbind(
		\instrument, \bufrd,
		//\dur, Prand([1, 1.5], inf),
        \dur, 0.25,
		\ffreq, 4000,
        \level, 1,
		\pan, Prand([-0.5, 0, 0.5], inf)
));
);

/*
Pdef(\pbpat).play(t, quant: 0.5);
Pdef(\pbpat).isPlaying;
Pdef(\pbpat).pause;
*/

Pdef(\buffpat, Ppar([Pdef(\rbpdef), Pdef(\pbpat)], inf));

// Midi Control

(
MIDIdef.cc(\buffpatplay, {
    if(Pdef(\buffpat).isPlaying.not) {
        ~midiout.control(0, 52, 127);
        Pdef(\buffpat).play(t);
        "buffpat play".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\buffpatstop, {
    if(Pdef(\buffpat).isPlaying) {
        ~midiout.control(0, 52, 0);
        Pdef(\buffpat).stop;
        "buffpat stop".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PLUNK

(
SynthDef(\plunk, { | a = 1, curve = -16, dur = 1, fb = 0, freq = 400, level = 0.03, outBus, rq = 0.3, shapelimit = 1 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var sinfb			=	SinOscFB.ar(freq, fb);
    var cusp            =   CuspL.ar(100, [a, a - 0.001], add: 1);
    var shape			=	SineShaper.ar(sinfb, shapelimit * cusp, (shapelimit * 2).reciprocal);
    var rlpf			=	BLowPass4.ar(shape, (freq).clip(50, SampleRate.ir / 3));
    var rhpf			=	RHPF.ar(shape, (freq * 8).clip(50, SampleRate.ir / 3), rq);
    Out.ar(outBus, (rlpf + rhpf) * envgen);
}).add;
);

(
Pdef(\plunkpat1,
	Pbind(
		\instrument, \plunk,
        \a, Pshuf((5..10) / 5, inf),
        \curve, -16,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 16, 24, 32, 48, 64, 96], inf),
        \degree, 0,
        \fb, Pshuf(([0, 0.25, 0.5, 0.75, 1, 1.25, 1.5]), inf),
        \octave, 6,
        \outBus, [0, ~verbus],
		\scale, ~scale,
        \shapelimit, Pshuf([0.3, 0.4, 0.5, 0.6, 0.7, 0.8], inf)
));
);

Pdef(\plunkpat2,
	Pbindf(
		Pdef(\plunkpat1),
));

Pdef(\plunkpat3,
	Pbindf(
		Pdef(\plunkpat1),
));

/*
Pdef(\plunkpat4,
    Pbindf(
        Pdef(\plunkpat1),
        \curve, -8,
        //\degree, Pseq([5, Pseq([0], 12)], inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5].stutter(3), inf),
        \octave, [2, 3],
        \outBus, 0,
        \rq, Pshuf([0.125, 0.25, 0.5, 1].stutter(25), inf),
        //\shapelimit, Pshuf([0.3, 0.003, 0.0003, 0.00003].stutter(17), inf)
        \shapelimit, 0.1
));

Pdef(\plunkpat5, Pbindf(Pdef(\plunkpat4), \shapelimit, 0.005));

Pdef(\plunkpat6, Pbindf(Pdef(\plunkpat5)));
);
*/

/*
Pdef(\plunkpat1).play(t, quant: 0.5);
Pdef(\plunkpat1).isPlaying;
Pdef(\plunkpat1).stop;
*/

/*
Pdef(\plunkpat2).play(t, quant: 0.5);
Pdef(\plunkpat2).isPlaying;
Pdef(\plunkpat2).stop;
*/

/*
Pdef(\plunkpat3).play(t, quant: 0.5);
Pdef(\plunkpat3).isPlaying;
Pdef(\plunkpat3).stop;
*/

/*
Pdef(\plunkpat4).play(t, quant: 0.5);
Pdef(\plunkpat4).isPlaying;
Pdef(\plunkpat4).stop;
*/

/*
Pdef(\plunkpat5).play(t, quant: 0.5);
Pdef(\plunkpat5).isPlaying;
Pdef(\plunkpat5).stop;
*/

/*
Pdef(\plunkpat6).play(t, quant: 0.5);
Pdef(\plunkpat6).isPlaying;
Pdef(\plunkpat6).stop;
*/

// Midi Control

(
MIDIdef.cc(\plunk1playktrl, {
	if(Pdef(\plunkpat1).isPlaying.not) {
        ~midiout.control(0, 37, 127);
		Pdef(\plunkpat1).play(t, quant: 0.5);
		"plunk1 play".postln;
	};
}, 37, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk1stopktrl, {
	if(Pdef(\plunkpat1).isPlaying) {
        ~midiout.control(0, 37, 0);
		Pdef(\plunkpat1).stop;
		"plunk1 stop".postln;
	};
}, 37, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\plunk2playktrl, {
	if(Pdef(\plunkpat2).isPlaying.not) {
        ~midiout.control(0, 53, 127);
		Pdef(\plunkpat2).play(t, quant: 0.5);
		"plunk2 play".postln;
	};
}, 53, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk2stopktrl, {
	if(Pdef(\plunkpat2).isPlaying) {
        ~midiout.control(0, 53, 0);
		Pdef(\plunkpat2).stop;
		"plunk2 stop".postln;
	};
}, 53, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\plunk3playktrl, {
	if(Pdef(\plunkpat3).isPlaying.not) {
        ~midiout.control(0, 69, 127);
		Pdef(\plunkpat3).play(t, quant: 0.5);
		"plunk3 play".postln;
	};
}, 69, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk3stopktrl, {
	if(Pdef(\plunkpat3).isPlaying) {
        ~midiout.control(0, 69, 0);
		Pdef(\plunkpat3).stop;
		"plunk3 stop".postln;
	};
}, 69, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

// start up the reverb

{
    s.sync;
    Pdef(\verbs).play(t);
}.fork;