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
~verbus = Bus.audio(s, 2);
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 128/81, 12/7, 7/4, 512/243];
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
            Pseq([1.25], 7),
            Pseq([1.5], 7),
            Pseq([1.75], 7)
		], inf),
		//\degree, Pwrand([0, Rest], [2, 1].normalizeSum, inf),
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
        Pdef(\dinglepat1), Pdef(\dinglepat1a), Pdef(\dinglepat1b), Pdef(\dinglepat2a), Pdef(\dinglepat2a), Pdef(\dinglepat2b)
], inf));
);

/*
Pdef(\dinglepar2).play(t, quant: 1);
Pdef(\dinglepar2).isPlaying;
Pdef(\dinglepar2).stop;
*/

(
Pdef(\single,
    Pbind(
        \instrument, \dingle,
        \a, Pwhite(0.01, 0.02, inf),
        \curve, -512,
        \degree, 7,
        \dur, Pshuf(Array.fill(5, { |d| (d + 1) * 0.25 }).stutter(5), inf),
        \level, Pshuf([0.25, 0.5, 1].stutter(3) * 0.2, inf),
        \octave, 7,
        \pan, Pshuf([-1, -0.5, 0, 0.5, 1], inf),
        \scale, ~scale
));
);

/*
Pdef(\single).play(t, quant: 1);
Pdef(\single).isPlaying;
Pdef(\single).stop;
*/

// Midi Control

(
MIDIdef.cc(\dingleparplayktrl, {
	if(Pdef(\dinglepar2).isPlaying.not) {
		Pdef(\dinglepar2).play(t, quant: 1);
		"dingle play".postln;
	};
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\dinglestopktrl, {
    if(Pdef(\dinglepar2).isPlaying) {
        Pdef(\dinglepar2).stop;
        "dingle stop".postln;
    }
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\singleplay, {
    if(Pdef(\single).isPlaying.not) {
        Pdef(\single).play(t, quant: 1);
        "single play".postln
    };
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\singlestop, {
    if(Pdef(\single).isPlaying) {
        Pdef(\single).stop;
        "single stop".postln;
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
		\degree, [2, 7],
		\dur, Pshuf([0.5, 0.75, 1, 1.5, 2, 3].stutter(7), inf),
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
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\snapstopktrl, {
	if(Pdef(\snappat).isPlaying) {
		Pdef(\snappat).stop;
		"snap stop".postln;
	};
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// clip noise percussion

(
SynthDef(\cnprc, { |bal = 0, curve = -16, freq = 500, level = 0.1, outbus = 0, releaseTime = 0.1|
    var env             =   Env.perc(0.003, releaseTime, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var blip            =   Blip.ar(0, mul: envgen);
    var clipnoiz        =   LFClipNoise.ar(freq!2, envgen);
    var rlpf            =   BLowPass4.ar(blip + clipnoiz, freq.clip(50, SampleRate.ir / 2.5), 0.1);
    var rhpf            =   RHPF.ar(blip + clipnoiz, (freq * 4).clip(50, SampleRate.ir / 2.5), 0.2);
    var balance         =   Balance2.ar((rlpf + rhpf)[0], (rlpf + rhpf)[1], bal);
    Out.ar(outbus, balance);
}).add;
);

(
~cnprclvl = 0.1;
~cnprcecholvl = ~cnprclvl / 4;
Pdef(\cnprc1,
    Pbind(
        \instrument, \cnprc,
        //\bal, Pshuf([-1, -0.5, 0, 0.5, 1], inf),
        \curve, Pshuf([-8, -4, -2], inf),
        \dur, Pshuf(Array.fill(23, { |d| (d + 1) * (0.25) }), inf),
        //\freq, Pshuf(Array.fill(3, { |i| pi.pow(i + 1) * 50 }), inf),
        \freq, Pseq([100, 1000, 100, 100, 1000, 100, 100, 100, 1000], inf),
        \level, ~cnprclvl,
        \offset, Pwhite(-0.01, 0.01, inf),
        \outbus, [~prcfxbus, ~verbus],
        \releaseTime, Pshuf([0.05, 0.075, 0.1, 0.15], inf)
));
Pdef(\cnprc2, Pbindf(Pdef(\cnprc1), \bal, -1, \level, ~cnprcecholvl));
Pdef(\cnprc3, Pbindf(Pdef(\cnprc2), \bal, 1));
Pdef(\cnprc4, Pbindf(Pdef(\cnprc1), \level, ~cnprcecholvl));
Pdef(\cnprcpar, Ppar([Pdef(\cnprc1), Pdef(\cnprc2), Pdef(\cnprc3)], inf));
//Pdef(\cnprcpar, Ppar([Pdef(\cnprc1), Pdef(\cnprc4)], inf));
);

/*
Pdef(\cnprc1).play(t, quant: 1);
Pdef(\cnprc1).isPlaying;
Pdef(\cnprc1).stop;
*/

/*
Pdef(\cnprc4).play(t, quant: 1);
Pdef(\cnprc4).isPlaying;
Pdef(\cnprc4).stop;
*/

/*
Pdef(\cnprcpar).play(t, quant: 1);
Pdef(\cnprcpar).isPlaying;
Pdef(\cnprcpar).stop;
*/

(
MIDIdef.cc(\cnplayktrl, {
	if(Pdef(\cnprcpar).isPlaying.not) {
		Pdef(\cnprcpar).play(t, quant: 1);
		"cnprc play".postln;
	};
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\cnstopktrl, {
	if(Pdef(\cnprcpar).isPlaying) {
		Pdef(\cnprcpar).stop;
		"cnprc stop".postln;
	};
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// VERB

(
SynthDef(\verb, { |gate = 1, inbus = 0, outbus = 0|
    var env             =   Env.asr(0.01, 0.3);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inbus, 2);
    //var tmod            =   LFNoise2.kr(1!2).range(5, 15);
    var dampmod         =   LFNoise2.kr(1!2, 1, 1);
    //var sizemod         =   LFNoise0.kr(0.1!2).range(0.1, 1);
    var lowmod          =   LFNoise0.kr(0.13!2, 1, 1);
    var midmod          =   LFNoise0.kr(0.23!2, 1, 1);
    var himod           =   LFNoise0.kr(0.17!2, 1, 1);
    var verb            =   JPverb.ar(in, 0.1, dampmod, 0.05, low: lowmod, mid: midmod, high: himod, lowcut: 1000, highcut: 4000) * envgen;
    Out.ar(outbus, verb);
}).add;
);

Pdef(\verb, Pmono(\verb, \inbus, ~verbus));

Pdef(\verb).play(t, quant: 1);
/*
Pdef(\verb).isPlaying;
Pdef(\verb).stop;
*/

(
MIDIdef.cc(\verbplay, {
    if(Pdef(\verb).isPlaying.not) {
        Pdef(\verb).play(t, quant: 1);
        "verb play".postln;
    };
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\verbstop, {
    if(Pdef(\verb).isPlaying) {
        Pdef(\verb).stop;
        "verb stop".postln;
    };
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PAD

(
SynthDef(\pad, { |curve = -4, dur = 1, fb = 0.1, freq = 400, gate = 1, im = 1, level = 0.005|
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var fbsin           =   FBSineC.ar(freq * 8, [im, im - 0.001], fb, mul: envgen);
    var delay           =   DelayC.ar(fbsin, 1, freq.reciprocal * XLine.kr(1, 1/2, 0.1));
    var submix1         =   fbsin + delay;
    var sin1            =   SinOsc.ar(freq!2, mul: envgen);
    var sin2            =   SinOsc.ar(freq!2 / 2, mul: envgen);
    Out.ar(0, fbsin + sin1 + sin2);
}).add;
);

(
Pdef(\pad1,
    Pbind(
        \instrument, \pad,
        \bal, Pshuf([-0.5, 0, 0.5].stutter(13), inf),
        \dur, Pshuf(Array.fill(7, { |i| (i + 7).nthPrime + 0.25 }), inf),
        \fb, Pshuf(Array.series(11, 0.1, 0.1), inf),
        \im, Pshuf(Array.series(17, 0.5, 0.2), inf),
        \legato, 0.5,
        \degree, Pseq([[-2, 0, 7], Rest], inf),
        \octave, 6,
        \scale, ~scale,
));
Pdef(\pad2, Pbindf(Pdef(\pad1), \degree, Pseq([Rest, [7, 10]], inf)));
Pdef(\pad3, Pbindf(Pdef(\pad1), \degree, Pseq([[7, 12], Rest], inf)));
Pdef(\pad4, Pbindf(Pdef(\pad1), \degree, Pseq([Rest, [7, 13]], inf)));
Pdef(\pads, Ppar([Pdef(\pad1), Pdef(\pad2), Pdef(\pad3), Pdef(\pad4)]));
);

/*
Pdef(\pads).play(t, quant: 1);
Pdef(\pads).isPlaying;
Pdef(\pads).stop;
*/

Pdef(\paddrone, Pmono(\pad, \degree, [0, 7], \scale, ~scale));

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
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\padsstopktrl, {
    if(Pdef(\pads).isPlaying) {
		Pdef(\pads).stop;
		"pads stop".postln;
	}
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\paddroneplayktrl, {
    if(Pdef(\paddrone).isPlaying.not) {
		Pdef(\paddrone).play(t, quant: 1);
		"pad drone play".postln;
	}
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\paddronestopktrl, {
    if(Pdef(\paddrone).isPlaying) {
		Pdef(\paddrone).stop;
		"pads stop".postln;
	}
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

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
        \dur, Pshuf(Array.fill(5, { |i| (i + 9).nthPrime }) + 0.25, inf),
        \fb, 0,
        \legato, 0.5,
        \level, 0.005,
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
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\larrynoplay, {
    if(Pdef(\larrys).isPlaying) {
        Pdef(\larrys).stop;
        "Bye Larry".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////
// BASS

// SynthDef

(
SynthDef(\abass, { |curve = -4, dur = 1, fb = 0, ffreq = 4000, freq = 440, level = 0.1|
    var env             =   Env.perc(0.001, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var xline           =   XLine.kr(1, 0.1, 1);
    var sinfb           =   SinOscFB.ar([freq, freq + 0.1], fb * xline, envgen);
    var rlpf            =   BLowPass4.ar(sinfb, (freq * XLine.kr(3, 2, 1)).clip(50, SampleRate.ir / 3), 0.5);
    var rhpf            =   BHiPass4.ar(sinfb, (ffreq).clip(50, SampleRate.ir / 3), 0.3);
    Out.ar([0, ~bassfxbus], rlpf + rhpf);
}).add;
);

// Pattern

(
~bassnotes = [-2, -1, 0, 1, 2, 3];
~bassdurations = [0.25, 0.5, Pseq([0.25], 3), 0.75, 1, 1.5, 2, Pseq([0.75], 3), 3, 4, 6, 8, 12, 16, 24];
Pdef(\bass,
	Pbind(
        \instrument, \abass,
        \degree, Pseq([Pshuf(~bassnotes, 2), Pseq([Rest], ~bassnotes.size)], inf),
		\dur, Pshuf(~bassdurations, inf),
        \fb, Pshuf((10..17) / 9, inf),
        \ffreq, 4000,
		\octave, 3,
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
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\basspause, {
    if(Pdef(\bass).isPlaying) {
        Pdef(\bass).pause;
        "bass pause".postln;
    };
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0);
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
		\dur, Prand([1, 1.5], inf),
		\ffreq, 4000,
        \level, 1,
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
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\rbstopktrl, {
	if(Pdef(\rbpdef).isPlaying) {
		Pdef(\rbpdef).stop;
		"recbuf stop".postln;
	};
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pbplayktrl, {
	if(Pdef(\pbpat).isPlaying.not) {
		Pdef(\pbpat).play(t, quant: 1);
		"playbuf play".postln;
	};
}, 67, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pbstopktrl, {
    if(Pdef(\pbpat).isPlaying) {
        Pdef(\pbpat).stop;
        "playbuf stop"
    }
}, 67, srcID: ~nanoktrl2.uid, argTemplate: 0);
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
		\degree, 0,
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
}, 36, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk1stopktrl, {
	if(Pdef(\plunkpat1).isPlaying) {
		Pdef(\plunkpat1).stop;
		"plunk1 stop".postln;
	};
}, 36, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\plunk2playktrl, {
	if(Pdef(\plunkpat2).isPlaying.not) {
		Pdef(\plunkpat2).play(t, quant: 1);
		"plunk2 play".postln;
	};
}, 52, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk2stopktrl, {
	if(Pdef(\plunkpat2).isPlaying) {
		Pdef(\plunkpat2).stop;
		"plunk2 stop".postln;
	};
}, 52, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\plunk3playktrl, {
	if(Pdef(\plunkpat3).isPlaying.not) {
		Pdef(\plunkpat3).play(t, quant: 1);
		"plunk3 play".postln;
	};
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\plunk3stopktrl, {
	if(Pdef(\plunkpat3).isPlaying) {
		Pdef(\plunkpat3).stop;
		"plunk3 stop".postln;
	};
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0);
);