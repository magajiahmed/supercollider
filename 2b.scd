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
);

(
s.meter;
t = TempoClock(96/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);
);

(
~bassfxbus = Bus.audio(s, 2);
~prcfxbus = Bus.audio(s, 2);
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 14/9, 7/4];
~tuning = Tuning.new(~ratios.ratiomidi);
~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
);

//~pulsedurarray = [Pseq([0.25], 53), Pseq([0.25], 31), Pseq([1/3], 3), Pseq([2/5], 5)];

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

////////////////////////////////////////////////////////
// BASS ////////////////////////////////////////////////

// SynthDef

(
SynthDef(\bass, { |a = 1, curve = -8, dur = 1, ffreq = 10000, freq = 100, level = 0.04, phasemodamp = 1|
 	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
 	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var trifrqmod       =   LFBrownNoise2.kr(0.2!2, mul: 0.001, add: 1);
	var tri				=	LFTri.ar(freq * trifrqmod, mul: envgen);
	var lat				=	Latoocarfian2DN.ar(freq, freq * 2, a: [a, a - 0.01], mul: 0.005, add: 1);
	var sin1			=	SinOsc.ar(freq * lat, mul: phasemodamp, add: 1);
	var sin2			=	SinOsc.ar(freq, sin1, mul: envgen);
    var line            =   Line.kr(1, 0, dur / 2);
    var deci            =   Decimator.ar(tri + sin2, SampleRate.ir, 5) * line;
    var ffrqmod         =   LFBrownNoise0.kr(30!2).range(1, 1.2).round(0.2);
    var rqmod           =   LFBrownNoise0.kr(freq!2).range(0.1, 0.3).round(0.2);
    var rhpf            =   RHPF.ar(deci, (ffreq).clip(50, SampleRate.ir / 3), rqmod);
    Out.ar([0, ~bassfxbus], tri + sin2 + rhpf);
}).add;
);

// Pattern

(
~bassdurations = [0.25, 0.5, Pseq([0.25], 3), 0.75, 1, 1.5, 2, Pseq([0.75], 3), 3, 4, 6, 8, 12, 16, 24];
Pdef(\bass,
	Pbind(
		\instrument, \bass,
		\a, Pwhite(0.9, 1.1, inf),
		\degree, Pshuf([-3, -1, 0, 1, 2, 3].stutter(3), inf),
		\dur, Pshuf(~bassdurations, inf),
        \ffreq, Pwhite(8000, 10000, inf),
		\octave, 3,
        \phasemodamp, Pshuf((0..11) / 2, inf),
		\scale, ~scale,
));
);

/*
Pdef(\bass).play(t, quant: 1);
Pdef(\bass).isPlaying;
Pdef(\bass).pause;
*/

// Midi Control

(
MIDIdef.cc(\bassplayktrl, {
    if(Pdef(\bass).isPaused) {
        Pdef(\bass).resume(t, quant: 0.5);
        // if pattern still paused, then it probably can't be resumed, so play it
        if(Pdef(\bass).isPaused) {
            Pdef(\bass).play(t, quant: 0.5);
        };
        "bass play".postln;
    };
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\basspause, {
    if(Pdef(\bass).isPlaying) {
        Pdef(\bass).pause;
        "bass pause".postln;
    };
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0);
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
SynthDef(\bufrd, { | dur = 1, ffreq = 3000, gate = 1, pan = 0 |
	var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(b.numChannels, b.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var rhpf			=	RHPF.ar(bufrd, ffreq, 0.3, envgen * kbn1 * 2);
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
		\dur, Prand([1, 1.5], inf),
		\ffreq, 3000,
		\pan, Prand([-0.5, 0, 0.5], inf)
));
);

/*
Pdef(\pbpat).play(t, quant: 1.5);
Pdef(\pbpat).isPlaying;
Pdef(\pbpat).pause;
*/

// Midi Control

(
MIDIdef.cc(\rbplayktrl, {
	if(Pdef(\rbpdef).isPlaying.not) {
		Pdef(\rbpdef).play(t, quant: 3);
		"recbuf play".postln;
	};
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\rbstopktrl, {
	if(Pdef(\rbpdef).isPlaying) {
		Pdef(\rbpdef).stop;
		"recbuf stop".postln;
	};
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pbplayktrl, {
	if(Pdef(\pbpat).isPlaying.not) {
		Pdef(\pbpat).play(t, quant: 1);
		"playbuf play".postln;
	};
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pbstopktrl, {
    if(Pdef(\pbpat).isPlaying) {
        Pdef(\pbpat).stop;
        "playbuf stop"
    }
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// prc

(
SynthDef(\prc, { | a = 1, curve = -8, dfrq = 2000, dur = 1, freq = 1000, level = 0.08, pan = 0 |
	var env				=	Env.perc(releaseTime: 0.15, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq, a, add: 1);
	var lfn				=	LFNoise0.ar(15).range(0, 1);
	var sin				=	SinOsc.ar(freq * cusp, mul: envgen);
	var sin2			=	sin.round(0.01) / 2;
	var rez				=	Resonz.ar(sin, freq, 0.05, 4);
	var pan2			=	Pan2.ar(sin2 + rez, pan);
	Out.ar(~prcfxbus, pan2);
}).add;
);

(
~prcpatfrq1 = 80;
~prcpatfrq2 = 8000;
Pdef(\prcpat,
	Pbind(
		\instrument, \prc,
		\a, Pshuf([1, 2, 3, 1.1, 2.1, 3.1], inf),
		\dfrq, Pwhite(100, 8000, inf),
		\dur, Prand([Pseq([0.25], 3), Pseq([0.25], 5), Pseq([0.5, 0.75], 3)], inf),
		\freq, Pshuf([
			Pseq([~prcpatfrq1, ~prcpatfrq2, ~prcpatfrq2]),
			Pseq([~prcpatfrq2, ~prcpatfrq1, ~prcpatfrq2]),
			Pseq([~prcpatfrq2, ~prcpatfrq2, ~prcpatfrq1]),
			Pseq([~prcpatfrq2, ~prcpatfrq2, ~prcpatfrq2])
		], inf),
		\level, 0.3,
));
);

/*
Pdef(\prcpat).play(t, quant: 1);
Pdef(\prcpat).isPlaying;
Pdef(\prcpat).stop;
*/

(
Pdef(\prc2pat1a, Pbindf(Pdef(\prcpat), \level, 0.03, \pan, -1));
Pdef(\prc2pat1b, Pbindf(Pdef(\prc2pat1a), \pan, 1));
Pdef(\prcpar, Ppar([Pdef(\prcpat), Pdef(\prc2pat1a), Pdef(\prc2pat1b)], inf));
);

/*
Pdef(\prcpar).play(t, quant: 1);
Pdef(\prcpar).isPlaying;
Pdef(\prcpar).pause;
*/

(
MIDIdef.cc(\prcktrl, {
	if(Pdef(\prcpar).isPlaying.not) {
		Pdef(\prcpar).play(t, quant: 1);
		"prc play".postln;
	};
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prcstopktrl, {
    if(Pdef(\prcpar).isPlaying) {
        Pdef(\prcpar).stop;
        "prc stop".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
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
		\dur, Pshuf([0.5, 0.75].stutter(7), inf),
		\im, Pshuf((1..10), inf),
		\level, 0.05,
		\octave, 10,
		\scale, ~scale,
));
);

/*
Pdef(\snappat).play(t, quant: 1);
Pdef(\snappat).isPlaying;
Pdef(\snappat).pause;
*/

// Midi control

(
MIDIdef.cc(\snapplayktrl, {
	if(Pdef(\snappat).isPlaying.not) {
		Pdef(\snappat).play(t, quant: 1);
		"snap play".postln;
	};
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\snapstopktrl, {
	if(Pdef(\snappat).isPlaying) {
		Pdef(\snappat).stop;
		"snap stop".postln;
	};
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

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
Pdef(\dinglepat1,
	Pbind(
		\instrument, \dingle,
		\a, 0.01,
		\curve, -8,
		\dur, Pshuf([
			Pseq([0.75], 7),
			Pseq([1], 7),
			Pseq([1.25], 7),
		], inf),
		\note, Pwrand([0, Rest], [4, 1].normalizeSum, inf),
		\level, Pwhite(0.5, 1, inf) * 0.4,
		\octave, 4,
		\scale, ~scale,
));
Pdef(\dinglepat1a, Pbindf(Pdef(\dinglepat1), \level, 0.08, \pan, -1));
Pdef(\dinglepat1b, Pbindf(Pdef(\dinglepat1a), \pan, 1));
Pdef(\dinglepat2, Pbindf(Pdef(\dinglepat1), \curve, -64, \octave, 6));
Pdef(\dinglepat2a, Pbindf(Pdef(\dinglepat2), \curve, -8, \dur, 0.25, \level, 0.08, \pan, -1));
Pdef(\dinglepat2b, Pbindf(Pdef(\dinglepat2a), \pan, 1));
Pdef(\dinglepar2,
    Ppar([
        Pdef(\dinglepat1), Pdef(\dinglepat1a), Pdef(\dinglepat1b)].stutter(3) ++ [Pdef(\dinglepat2a), Pdef(\dinglepat2a), Pdef(\dinglepat2b)
], inf));
);

/*
Pdef(\dinglepar2).play(t, quant: 1);
Pdef(\dinglepar2).isPlaying;
Pdef(\dinglepar2).stop;
*/

// Midi Control

(
MIDIdef.cc(\dingleparplayktrl, {
	if(Pdef(\dinglepar2).isPlaying.not) {
		Pdef(\dinglepar2).play(t, quant: 1);
		"dingle play".postln;
	};
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\dinglestopktrl, {
    if(Pdef(\dinglepar2).isPlaying) {
        Pdef(\dinglepar2).stop;
        "dingle stop".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PLUNK

(
SynthDef(\plunk, { | a = 1, curve = -16, dur = 1, fb = 0, freq = 400, level = 0.03, shapelimit = 1 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var kbn             =   1;
	var sinfb			=	SinOscFB.ar(freq, fb, envgen * kbn);
    var cusp            =   CuspL.ar(100, [a, a-0.001], mul: 1, add: 1);
    var shape			=	SineShaper.ar(sinfb, shapelimit * cusp, (shapelimit * 50).reciprocal);
    var rlpf			=	BLowPass4.ar(shape, (freq).clip(50, SampleRate.ir / 3));
    var rhpf			=	RHPF.ar(shape, (freq * 8).clip(50, SampleRate.ir / 3), 0.3);
	Out.ar(0, rlpf + rhpf);
}).add;
);

(
Pdef(\plunkpat1,
	Pbind(
		\instrument, \plunk,
        \a, Pshuf((5..10) / 5, inf),
        \curve, -16,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 16, 24], inf),
		\degree, Pshuf([-1, 0], inf),
        \fb, 0,
        \octave, 6,
		\scale, ~scale,
        \shapelimit, Pbrown(0.003, 0.008, 0.001, inf)
));


Pdef(\plunkpat2,
	Pbindf(
		Pdef(\plunkpat1),
        \degree, Pshuf([[0, 1], [0, 2], [0, 3]], inf),
));

Pdef(\plunkpat3,
	Pbindf(
		Pdef(\plunkpat1),
		\degree, 7
));
);

/*
Pdef(\plunkpat1).play(t, quant: 1);
Pdef(\plunkpat1).isPlaying;
Pdef(\plunkpat1).stop;
*/

/*
Pdef(\plunkpat2).play(t, quant: 1);
Pdef(\plunkpat2).isPlaying;
Pdef(\plunkpat2).stop;
*/

/*
Pdef(\plunkpat3).play(t, quant: 1);
Pdef(\plunkpat3).isPlaying;
Pdef(\plunkpat3).stop;
*/

// Midi Control

(
MIDIdef.cc(\plunk1playktrl, {
	if(Pdef(\plunkpat1).isPlaying.not) {
		Pdef(\plunkpat1).play(t, quant: 0.5);
		"plunk1 play".postln;
	};
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk1stopktrl, {
	if(Pdef(\plunkpat1).isPlaying) {
		Pdef(\plunkpat1).stop;
		"plunk1 stop".postln;
	};
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\plunk2playktrl, {
	if(Pdef(\plunkpat2).isPlaying.not) {
		Pdef(\plunkpat2).play(t, quant: 1);
		"plunk2 play".postln;
	};
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk2stopktrl, {
	if(Pdef(\plunkpat2).isPlaying) {
		Pdef(\plunkpat2).stop;
		"plunk2 stop".postln;
	};
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\plunk3playktrl, {
	if(Pdef(\plunkpat3).isPlaying.not) {
		Pdef(\plunkpat3).play(t, quant: 1);
		"plunk3 play".postln;
	};
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk3stopktrl, {
	if(Pdef(\plunkpat3).isPlaying) {
		Pdef(\plunkpat3).stop;
		"plunk3 stop".postln;
	};
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PENGUIN

(
SynthDef(\penguin, { | curve = 0, freq = 400, gate = 1, level = 0.1, shapermin = 0.0005, shapermax = 0.005 |
	var env				=	Env.asr(0.01, sustainLevel: level, releaseTime: 0.1, curve: curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
    var n               =   4;
	var mix				=	Mix.fill(n, {
		var freqmod			=	LFNoise1.kr(0.3!2, 0.002, 1);
		var tri				=	LFTri.ar((freq * freqmod).clip(50, s.sampleRate / 3), mul: envgen);
        var kbn				=	LFBrownNoise2.kr(0.1!2).range(shapermin, shapermax);
		var shape			=	SineShaper.ar(tri, kbn) * shapermax.reciprocal;
		shape / n;
	});
	var hpf				=	HPF.ar(mix, (freq * 4).clip(50, SampleRate.ir / 3), 0.1);
    var sin             =   SinOscFB.ar(freq!2, 0.3, mul: envgen / 32);
	Out.ar(0, sin + hpf);
}).add;
);

(
Pdef(\pgnpat1,
	Pbind(
		\instrument, \penguin,
		\degree, Pswitch([[-3, -1], [-3, 0], [-1, 1], [-3, 2], [0, 3], [0, 7]], Pbrown(0, 6, 1), inf),
		\dur, Pshuf([16, 24, 32, 48, 64] + 0.25, inf),
		\legato, 0.5,
		\octave, 6,
		\scale, ~scale,
		\shapermin, 0.001,
		\shapermax, 0.003,
));
Pdef(\pgnpat2, Pbindf(Pdef(\pgnpat1), \degree, Pseq([0, 7], inf)));
Pdef(\pgnpar, Ppar([Pdef(\pgnpat1), Pdef(\pgnpat2)]));
);

/*
Pdef(\pgnpar).play(t, quant: 1);
Pdef(\pgnpar).isPlaying;
Pdef(\pgnpar).stop;
*/

Pdef(\pgndrone, Pmono(\penguin, \degree, [-3, -1, 0], \octave, 7, \scale, ~scale));

/*
Pdef(\pgndrone).play(t, quant: 1);
Pdef(\pgndrone).isPlaying;
Pdef(\pgndrone).stop;
*/

(
MIDIdef.cc(\pgnplayktrl, {
    if(Pdef(\pgnpar).isPlaying.not) {
		Pdef(\pgnpar).play(t, quant: 1);
		"pgnpar play".postln;
	}
}, 54, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pgnstopktrl, {
    if(Pdef(\pgnpar).isPlaying) {
		Pdef(\pgnpar).stop;
		"pgnpar stop".postln;
	}
}, 54, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PAD2

// Synth

(
SynthDef(\pad2, { | curve = -4, dur = 1, freq = 400, gate = 1, level = 0.005 |
	var env				=	Env.asr(3, level, 7, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var filtmulmods		=	LFBrownNoise0.kr(15!4).range(0.25, 1).round(0.25);
	var saw1freqmod		=	LFNoise1.kr(0.1!2, 0.001, 1);
	var saw0			=	LFSaw.ar(freq!2, mul: envgen / 2);
	var saw1			=	LFSaw.ar(freq * saw1freqmod, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var bn				=	LFNoise2.ar(0.1!2, 0.1);
	var kbnshaper		=	LFBrownNoise1.kr(15.dup).range(0.5, 2);
	var shape			=	(sawmix + bn).fold2(0.002 * kbnshaper) * 5;
    var sinfb           =   SinOscFB.ar(freq!2, 0.1, envgen);
	var lpf				=	BLowPass4.ar(sawmix + shape, freq * 1.125, mul: filtmulmods[0, 1]);
	var rhpf			=	BHiPass4.ar(sawmix + shape, 6000, 0.05, filtmulmods[2, 3]);
	Out.ar(0, sinfb + lpf + rhpf);
}).add;
);

// Pattern

(
~padchords2 = ~scaledegrees.collect({ |i| [0, i, i + 2, 7, 9] });
~padchords2shuf = ~padchords2.scramble;

Pdef(\pad2pat,
	Pbind(
		\instrument, \pad2,
		\degree, Pseq([
            ~padchords2shuf[0], Rest,
            ~padchords2shuf[1], ~padchords2shuf[2], Rest,
            ~padchords2shuf[3], ~padchords2shuf[4], ~padchords2shuf[5], Rest,
            ~padchords2shuf[6], ~padchords2shuf[7], ~padchords2shuf[8], ~padchords2shuf[9], Rest,
		 ], inf),
		\dur, Pshuf([11, 13, 15], inf),
		\level, 0.01,
		\octave, 5,
		\scale, ~scale,
));
);

/*
Pdef(\pad2pat).play(t, quant: 1);
Pdef(\pad2pat).isPlaying;
Pdef(\pad2pat).stop;
*/

Pdef(\pad2pat2, Pmono(\pad2, \degree, [-3, 0].stutter(2), \octave, 5, \scale, ~scale));

Pdef(\pad2pat3, Pmono(\pad2, \octave, [2, 3, 4], \scale, ~scale));

/*
Pdef(\pad2pat2).play(t, quant: 1);
Pdef(\pad2pat2).isPlaying;
Pdef(\pad2pat2).stop;
*/

/*
Pdef(\pad2pat3).play(t, quant: 1);
Pdef(\pad2pat3).isPlaying;
Pdef(\pad2pat3).stop;
*/

// Midi Control

(
MIDIdef.cc(\pad2playktrl, {
	if(Pdef(\pad2pat).isPlaying.not) {
		Pdef(\pad2pat).play(t, quant: 1);
		"pad2a play".postln;
	};
}, 39, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad2stopktrl, {
    if(Pdef(\pad2pat).isPlaying) {
        Pdef(\pad2pat).stop;
        "pad2a stop".postln;
    }
}, 39, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pad2bplayktrl, {
	if(Pdef(\pad2pat2).isPlaying.not) {
		Pdef(\pad2pat2).play(t, quant: 1);
		"pad2b play".postln;
	};
}, 55, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad2bstopktrl, {
    if(Pdef(\pad2pat2).isPlaying) {
        Pdef(\pad2pat2).stop;
        "pad2b stop".postln;
    }
}, 55, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pad2cplayktrl, {
	if(Pdef(\pad2pat3).isPlaying.not) {
		Pdef(\pad2pat3).play(t, quant: 1);
		"pad2c play".postln;
	};
}, 71, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad2cstopktrl, {
    if(Pdef(\pad2pat3).isPlaying) {
        Pdef(\pad2pat3).stop;
        "pad2c stop".postln;
    }
}, 71, srcID: ~nanoktrl2.uid, argTemplate: 0);
);