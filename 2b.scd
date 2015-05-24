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
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 128/81, 12/7, 7/4, 512/243];
~tuning = Tuning.new(~ratios.ratiomidi);
~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
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
// BASS

// SynthDef

(
SynthDef(\bass, { |a = 1, curve = -8, dur = 1, fb = 0.75, ffreq = 10000, freq = 100, level = 0.04, phasemodamp = 1|
 	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
 	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var subbass         =   SinOscFB.ar(freq / 2, fb!2, envgen);
    var trifrqmod       =   LFBrownNoise2.kr(0.2!2, mul: 0.0001, add: 1);
	var tri				=	LFTri.ar(freq * trifrqmod, mul: envgen);
	var lat				=	Latoocarfian2DN.ar(freq, freq * 2, a: [a, a - 0.01], mul: 0.005, add: 1);
	var sin1			=	SinOsc.ar(freq * lat, mul: phasemodamp, add: 1);
	var sin2			=	SinOsc.ar(freq, sin1, mul: envgen);
    var line            =   Line.kr(0.5, 0, dur / 4);
    var deci            =   Decimator.ar(tri + sin2, SampleRate.ir, 5) * line;
    var ffrqmod         =   LFBrownNoise0.kr(30!2).range(1, 1.2).round(0.2);
    var rqmod           =   LFBrownNoise0.kr(freq!2).range(0.1, 0.3).round(0.2);
    var rhpf            =   RHPF.ar(deci, (ffreq).clip(50, SampleRate.ir / 3), rqmod);
    Out.ar([0, ~bassfxbus], subbass + tri + sin2 + rhpf);
}).add;
);

// Pattern

(
~bassnotes = [-2, -1, 0, 1, 2, 3];
~bassdurations = [0.25, 0.5, Pseq([0.25], 3), 0.75, 1, 1.5, 2, Pseq([0.75], 3), 3, 4, 6, 8, 12, 16, 24];
Pdef(\bass,
	Pbind(
		\instrument, \bass,
		\a, Pwhite(0.9, 1.1, inf),
        \note, Pseq([Pshuf(~bassnotes.stutter(2), 2), Pseq([Rest], ~bassnotes.size)], inf),
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
Pdef(\bass).stop;
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
		\curve, -8,
		\dur, Pshuf([
			//Pseq([0.75], 7),
			//Pseq([1], 7),
			Pseq([1.25], 7),
            Pseq([1.5], 7),
            Pseq([1.75], 7)
		], inf),
		\note, Pwrand([0, Rest], [2, 1].normalizeSum, inf),
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
        \curve, -8,
        \level, ~dingleecholvl,
        \pan, -1
));
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
		\note, [2, 7],
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
Pdef(\snappat).stop;
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
// clip noise percussion

(
SynthDef(\cnprc, { |bal = 0, curve = -16, dur = 1, freq = 500, level = 0.1|
    var env             =   Env.perc(0.003, 0.5, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var blip            =   Blip.ar(0, mul: envgen);
    var clipnoiz        =   LFClipNoise.ar(freq!2, envgen);
    var rhpf            =   RHPF.ar(blip + clipnoiz, (freq * 4).clip(50, SampleRate.ir / 3), 0.3);
    var balance         =   Balance2.ar(rhpf[0], rhpf[1], bal);
    Out.ar(0, rhpf);
}).add;
);

(
~cnprclvl = 0.2;
~cnprcecholvl = ~cnprclvl / 4;
Pdef(\cnprc1,
    Pbind(
        \instrument, \cnprc,
        \curve, -32,
        \dur, Pshuf([0.75, 1, 1.5, 2, 3, 4].stutter(7), inf),
        \freq, Pseq([50, 400, 50, 100, 50, 50, 50, 50, 400], inf),
        \level, ~cnprclvl,
));
Pdef(\cnprc2, Pbindf(Pdef(\cnprc1), \bal, -1, \level, ~cnprcecholvl));
Pdef(\cnprc3, Pbindf(Pdef(\cnprc2), \bal, 1));
Pdef(\cnprc4,
    Pbind(
        \instrument, \cnprc,
        \curve, -64,
        \dur, Pseq([1, 1.5, 1, 1.5, 1, 1, 1.5], inf),
        \freq, 1600,
        \note, Pseq([Pseq([0], 14), Pseq([Rest], 21)], inf)
));
Pdef(\cnprcpar, Ppar([Pdef(\cnprc1), Pdef(\cnprc2), Pdef(\cnprc3), Pdef(\cnprc4)], inf));
);

/*
Pdef(\cnprcpar).play(t, quant: 1);
Pdef(\cnprcpar).isPlaying;
Pdef(\cnprcpar).stop;
*/

/*
Pdef(\cnprc4).play(t, quant: 1);
Pdef(\cnprc4).isPlaying;
Pdef(\cnprc4).stop;
*/

(
MIDIdef.cc(\cnplayktrl, {
	if(Pdef(\cnprcpar).isPlaying.not) {
		Pdef(\cnprcpar).play(t, quant: 1);
		"cnprc play".postln;
	};
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\cnstopktrl, {
	if(Pdef(\cnprcpar).isPlaying) {
		Pdef(\cnprcpar).stop;
		"cnprc stop".postln;
	};
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// prc

(
SynthDef(\prc, { | a = 1, curve = -8, dfrq = 2000, dur = 1, freq = 1000, level = 0.08, pan = 0 |
	var env				=	Env.perc(releaseTime: 0.1, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq, a, add: 1);
	var lfn				=	LFNoise0.ar(15).range(0, 1);
	var sin				=	SinOsc.ar(freq * cusp, pi / 2, envgen);
	var sin2			=	sin.round(0.01) / 2;
	var rez				=	Resonz.ar(sin, freq, 0.05, 4);
	var pan2			=	Pan2.ar(sin2 + rez, pan);
	Out.ar(~prcfxbus, pan2);
}).add;
);

(
~prcpatfrq1 = 90;
~prcpatfrq2 = ~prcpatfrq1 * 32;
~prcpatlvl = 0.2;
~prcpatecholvl = ~prcpatlvl / 5;
Pdef(\prcpat1,
	Pbind(
		\instrument, \prc,
		\a, Pshuf([1, 2, 3, 1.1, 2.1, 3.1, 1.2, 2.2, 3.2], inf),
        \curve, -4,
        \dfrq, Pshuf((1..19) * 400, inf),
        \dur, Pshuf([
            Pseq([1 / 12], 3), Pseq([0.125], 2),
            Pseq([0.25], 13), Pseq([0.5, 0.75], 11), Pseq([0.75, 1.25], 7), Pseq([1, 1.5], 5), Pseq([1.25, 1.75], 3),
            3, 5, 7, 11, 13
        ], inf),
		\freq, Pshuf([
			Pseq([~prcpatfrq1, ~prcpatfrq2, ~prcpatfrq2]),
			Pseq([~prcpatfrq2, ~prcpatfrq1, ~prcpatfrq2]),
			Pseq([~prcpatfrq2, ~prcpatfrq2, ~prcpatfrq1]),
			Pseq([~prcpatfrq2, ~prcpatfrq2, ~prcpatfrq2])
		], inf),
		\level, ~prcpatlvl,
));
Pdef(\prcpat1a, Pbindf(Pdef(\prcpat1), \level, ~prcpatecholvl, \pan, -1));
Pdef(\prcpat1b, Pbindf(Pdef(\prcpat1a), \pan, 1));
Pdef(\prcpar1, Ppar([Pdef(\prcpat1), Pdef(\prcpat1a), Pdef(\prcpat1b)], inf));
Pdef(\prcpar2, Pbindf(Pdef(\prcpar1), \a, Pwhite(2.8, 3.0, inf), \curve, -64, \freq, ~prcpatfrq2 * (4 / 3)));
Pdef(\prcpat3, Pbindf(Pdef(\prcpat1), \a, 3, \curve, -64, \dur, Pseq([1, 1.5, 1, 1.5, 1, 1, 1.5], inf), \freq, ~prcpatfrq2));
Pdef(\prcpar3, Ppar([Pdef(\prcpar2), Pdef(\prcpat3)], inf));
);

/*
Pdef(\prcpar1).play(t, quant: 1);
Pdef(\prcpar1).isPlaying;
Pdef(\prcpar1).stop;
*/

/*
Pdef(\prcpar2).play(t, quant: 1);
Pdef(\prcpar2).isPlaying;
Pdef(\prcpar2).stop;
*/

/*
Pdef(\prcpar3).play(t, quant: 1);
Pdef(\prcpar3).isPlaying;
Pdef(\prcpar3).stop;
*/

(
MIDIdef.cc(\prc1ktrl, {
	if(Pdef(\prcpar1).isPlaying.not) {
		Pdef(\prcpar1).play(t, quant: 1);
		"prc1 play".postln;
	};
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc1stopktrl, {
    if(Pdef(\prcpar1).isPlaying) {
        Pdef(\prcpar1).stop;
        "prc1 stop".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prc3ktrl, {
	if(Pdef(\prcpar3).isPlaying.not) {
		Pdef(\prcpar3).play(t, quant: 1);
		"prc2 play".postln;
	};
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc3stopktrl, {
    if(Pdef(\prcpar3).isPlaying) {
        Pdef(\prcpar3).stop;
        "prc2 stop".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PLUNK

(
SynthDef(\plunk, { | a = 1, curve = -16, dur = 1, fb = 0, freq = 400, level = 0.03, shapelimit = 1 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var kbn             =   1;
	var sinfb			=	SinOscFB.ar(freq, fb, envgen * kbn);
    var cusp            =   CuspL.ar(100, [a, a - 0.001], mul: 1, add: 1);
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
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 16, 24, 32, 48, 64, 96], inf),
		\note, 0,
        \fb, Pshuf(([0, 0.25, 0.5, 0.75, 1, 1.25, 1.5]), inf),
        \octave, 6,
		\scale, ~scale,
        \shapelimit, Pbrown(0.003, 0.008, 0.001, inf)
));


Pdef(\plunkpat2,
	Pbindf(
		Pdef(\plunkpat1),
));

Pdef(\plunkpat3,
	Pbindf(
		Pdef(\plunkpat1),
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
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk1stopktrl, {
	if(Pdef(\plunkpat1).isPlaying) {
		Pdef(\plunkpat1).stop;
		"plunk1 stop".postln;
	};
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\plunk2playktrl, {
	if(Pdef(\plunkpat2).isPlaying.not) {
		Pdef(\plunkpat2).play(t, quant: 1);
		"plunk2 play".postln;
	};
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk2stopktrl, {
	if(Pdef(\plunkpat2).isPlaying) {
		Pdef(\plunkpat2).stop;
		"plunk2 stop".postln;
	};
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\plunk3playktrl, {
	if(Pdef(\plunkpat3).isPlaying.not) {
		Pdef(\plunkpat3).play(t, quant: 1);
		"plunk3 play".postln;
	};
}, 67, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk3stopktrl, {
	if(Pdef(\plunkpat3).isPlaying) {
		Pdef(\plunkpat3).stop;
		"plunk3 stop".postln;
	};
}, 67, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PAD

(
SynthDef(\pad, { |bal = 0, curve = -4, dur = 1, fb = 0.1, freq = 400, gate = 1, im = 1, level = 0.005|
    //var env             =   Env.perc(releaseTime: dur, level: level, curve: curve);
    //var envgen          =   EnvGen.kr(env, doneAction: 2);
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var fbsin           =   FBSineC.ar(freq * 16, [im, im - 0.01], fb, mul: envgen);
    var delay           =   DelayC.ar(fbsin, 1, freq.reciprocal * XLine.kr(1, 1/2, 0.1));
    var submix1         =   fbsin + delay;
    var lop             =   BLowPass4.ar(submix1, freq.clip(50, SampleRate.ir / 3));
    var rhpf            =   RHPF.ar(submix1, (freq * 8).clip(50, SampleRate.ir / 3), 0.5);
    var sin             =   SinOsc.ar(freq!2, mul: envgen);
    var submix2         =   lop + rhpf + sin;
    var balance         =   Balance2.ar(submix2[0], submix2[1], bal);
    Out.ar(0, balance);
}).add;
);

(
Pdef(\pad1,
    Pbind(
        \instrument, \pad,
        \bal, 0,
        \dur, Pshuf(Array.fill(7, { |i| (i + 7).nthPrime + 0.25 }), inf),
        \fb, Pshuf(Array.series(11, 0.1, 0.1), inf),
        \im, Pshuf(Array.series(17, 0.5, 0.2), inf),
        \note, Pseq([[-2, 0, 7], Rest], inf),
        \octave, 5,
        \scale, ~scale,
));
Pdef(\pad2, Pbindf(Pdef(\pad1), \note, Pshuf([[7, 10], Rest], inf)));
Pdef(\pad3, Pbindf(Pdef(\pad1), \note, Pshuf([[7, 12], Rest], inf)));
Pdef(\pad4, Pbindf(Pdef(\pad1), \note, Pshuf([[7, 13], Rest], inf)));
Pdef(\pads, Ppar([Pdef(\pad1), Pdef(\pad2), Pdef(\pad3), Pdef(\pad4)]));
);

/*
Pdef(\pads).play(t, quant: 1);
Pdef(\pads).isPlaying;
Pdef(\pads).stop;
*/

Pdef(\paddrone, Pmono(\pad, \note, [0, 7]));

/*
Pdef(\paddrone).play(t, quant: 1);
Pdef(\paddrone).isPlaying;
Pdef(\paddrone).stop;
*/

(
MIDIdef.cc(\padsplayktrl, {
    if(Pdef(\pads).isPlaying.not) {
		Pdef(\pads).play(t, quant: 1);
		"pads play".postln;
	}
}, 36, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\padsstopktrl, {
    if(Pdef(\pads).isPlaying) {
		Pdef(\pads).stop;
		"pads stop".postln;
	}
}, 36, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\paddroneplayktrl, {
    if(Pdef(\paddrone).isPlaying.not) {
		Pdef(\paddrone).play(t, quant: 1);
		"pad drone play".postln;
	}
}, 52, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\paddronestopktrl, {
    if(Pdef(\paddrone).isPlaying) {
		Pdef(\paddrone).stop;
		"pads stop".postln;
	}
}, 52, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

/*
(
MIDIdef.cc(\pno2playktrl, {
    if(Pdef(\pnos2).isPlaying.not) {
		Pdef(\pnos2).play(t, quant: 1);
		"pnos2 play".postln;
	}
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pno2stopktrl, {
    if(Pdef(\pnos2).isPlaying) {
		Pdef(\pnos2).stop;
		"pnos2 stop".postln;
	}
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0);
);
*/

////////////////////////////////////////////////////////////////
// LARRY

(
SynthDef(\larry, { |curve = -4, dur = 1, fb = 0, freq = 440, gate = 1, level = 0.005, s = 10|
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
        \dur, Pshuf(Array.fill(5, { |i| (i + 11).nthPrime }) + 0.25, inf),
        \fb, 0,
        \legato, 0.5,
        \level, 0.005,
        \note, Pseq([[7, 12], Rest], inf),
        \octave, 5,
        \s, Pwhite(8.0, 12.0, inf),
        \scale, ~scale
));


Pdef(\larry2,
	Pbindf(
		Pdef(\larry1),
        \note, Pshuf([[7, 10, 12], Rest], inf),
));

Pdef(\larry3,
	Pbindf(
		Pdef(\larry1),
        \note, Pshuf([[7, 12, 13], Rest], inf)
));

Pdef(\larry4, Pbindf(Pdef(\larry1), \note, Pshuf([0, Rest], inf), \octave, 4));

Pdef(\larrys, Ppar([Pdef(\larry1), Pdef(\larry2), Pdef(\larry3), Pdef(\larry4)], inf));
);

/*
Pdef(\larry1).play(t, quant: 1);
Pdef(\larry1).isPlaying;
Pdef(\larry1).stop;
*/

/*
Pdef(\larry2).play(t, quant: 1);
Pdef(\larry2).isPlaying;
Pdef(\larry2).stop;
*/

/*
Pdef(\larry3).play(t, quant: 1);
Pdef(\larry3).isPlaying;
Pdef(\larry3).stop;
*/

/*
Pdef(\larry4).play(t, quant: 1);
Pdef(\larry4).isPlaying;
Pdef(\larry4).stop;
*/

/*
Pdef(\larrys).play(t, quant: 1);
Pdef(\larrys).isPlaying;
Pdef(\larrys).stop;
*/

(
MIDIdef.cc(\larryplay, {
    if(Pdef(\larrys).isPlaying.not) {
        Pdef(\larrys).play(t, quant: 1);
        "Hi Larry".postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\larrynoplay, {
    if(Pdef(\larrys).isPlaying) {
        Pdef(\larrys).stop;
        "Bye Larry".postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PNO

(
SynthDef(\pno, { | curve = -4, dur = 1, fb = 0, freq = 440, level = 0.1 |
    var env             =   Env.perc(0.01, 1, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sinfb           =   SinOscFB.ar(freq!2, fb, envgen);
    //var rhpf            =   RHPF.ar(sinfb, (freq * 4).clip(50, SampleRate.ir / 3), 0.2);
    var hpf             =   BHiPass4.ar(sinfb, (freq * 4).clip(50, SampleRate.ir / 3), 0.1);
    Out.ar(0, hpf);
}).add;
);

(
~pnolvl = 0.01;
~pnoecholvl = ~pnolvl / 5;
Pdef(\pno1,
    Pbind(
        \instrument, \pno,
        \curve, -8,
        \dur, Pshuf([0.5, 0.75].stutter(13), inf),
        \fb, Pshuf((0..22) / 7, inf),
        \level, ~pnolvl,
        \note, [2, 7],
        \octave, 7,
        \scale, ~scale
));
Pdef(\pno2, Pbindf(Pdef(\pno1), \level, ~pnoecholvl));
Pdef(\pnos, Ppar([Pdef(\pno1), Pdef(\pno2)], inf));
);

/*
Pdef(\pno1).play(t, quant: 1);
Pdef(\pno1).isPlaying;
Pdef(\pno1).stop;
*/

/*
Pdef(\pno2).play(t, quant: 1);
Pdef(\pno2).isPlaying;
Pdef(\pno2).stop;
*/

/*
Pdef(\pnos).play(t, quant: 1);
Pdef(\pnos).isPlaying;
Pdef(\pnos).stop;
*/


(
MIDIdef.cc(\pnoplay, {
    if(Pdef(\pnos).isPlaying.not) {
        Pdef(\pnos).play(t, quant: 1);
        "pno play".postln;
    }
}, 37, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnostop, {
    if(Pdef(\pnos).isPlaying) {
        Pdef(\pnos).stop;
        "pno stop".postln;
    }
}, 37, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PENGUIN

(
SynthDef(\penguin, { | curve = 0, freq = 400, gate = 1, level = 0.1, ess = 10, shapermin = 0.0005, shapermax = 0.005 |
	var env				=	Env.asr(0.01, sustainLevel: level, releaseTime: 0.01, curve: curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
    var ampmod          =   LFBrownNoise0.kr(13!2).range(0, 1).round(1);
    var n               =   4;
	var mix				=	Mix.fill(n, {
		var freqmod			=	LFNoise1.kr(0.3!2, 0.003, 1);
		var tri				=	LFTri.ar((freq * freqmod).clip(50, s.sampleRate / 3), mul: envgen);
        var lfrqmod         =   LFBrownNoise1.kr(0.2!2).range(0.05, 0.1);
        var limitmod		=	LFBrownNoise1.kr(lfrqmod).range(shapermin, shapermax);
        var shape			=	SineShaper.ar(tri, limitmod) * shapermax.reciprocal * ampmod;
		shape / n;
	});
	var hpf				=	HPF.ar(mix, (freq * 16).clip(50, SampleRate.ir / 3), 0.03);
    var sin             =   Decimator.ar(SinOsc.ar(freq!2), bits: Lorenz2DN.kr(3, 300, ess).range(1.0, 4.0)) * (envgen / 16);
	Out.ar(0, sin + hpf);
}).add;
);

(
Pdef(\pgnpat1,
	Pbind(
		\instrument, \penguin,
		\note, Pshuf([[-5, -2], [-5, 0], [0, 7]], inf),
		\dur, Pshuf([16, 24, 32, 48, 64] + 0.25, inf),
		\legato, 0.5,
		\octave, 6,
        \ess, Pwhite(9.0, 11.0, inf),
		\scale, ~scale,
		\shapermin, 0.003,
		\shapermax, 0.005
        //\shapermax, Pwhite(0.001, 0.003, inf)
));
Pdef(\pgnpat2, Pbindf(Pdef(\pgnpat1), \note, Pseq([0, 7], inf)));
Pdef(\pgnpar, Ppar([Pdef(\pgnpat1), Pdef(\pgnpat2)]));
);

/*
Pdef(\pgnpar).play(t, quant: 1);
Pdef(\pgnpar).isPlaying;
Pdef(\pgnpar).stop;
*/

Pdef(\pgndrone, Pmono(\penguin, \note, [-5, -2, 0], \octave, 7, \scale, ~scale));

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
~padchords2 = ~scaledegrees.collect({ |i| [0, i, i + 2, 7, 10, 12] });
~padchords2shuf = ~padchords2.scramble;

Pdef(\pad2pat,
	Pbind(
		\instrument, \pad2,
		\note, Pseq([
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

Pdef(\pad2pat2, Pmono(\pad2, \note, [-5, 0].stutter(2), \octave, 5, \scale, ~scale));
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
