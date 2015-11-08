////////////////////////////////////////////////////////////////
// INIT

// clear all patterns

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
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 14/9, 12/7, 7/4, 243/128];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
~chord = [-2, 0, 2, 7];
~wutchords = [[-5, 2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]];
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
SynthDef(\dynamix, {
	var in	   		= 	In.ar(4, 2);
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.001, slopeAbove: 1/2); // compressor
	Out.ar(0, compressor);
}).add;
);

(
~startdynamix = {
	s.sync;
	~dynamix = Synth(\dynamix).register;
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
SynthDef(\bass, { | curve = -4, dur = 1, fb = 0, foldfactor = 3, ffend = 1, ffnoizamt = 1, ffstart = 1, freq = 100, level = 0.05, start = 1 |
    var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
 	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var fenv            =   XLine.kr(start, 1, dur / 4);
    var sin             =   SinOscFB.ar((freq - 0.1) * fenv, 0.3, envgen * 6);
    var sinfb      		=	SinOscFB.ar([freq, freq + 0.1] * fenv, fb);
    var ffnoiz          =   LFNoise2.kr(freq!2).range(ffnoizamt.reciprocal, ffnoizamt);
    var ffmod           =   XLine.kr(ffstart, ffend, dur / 2);
    var sineshaper      =   SineShaper.ar(sinfb, foldfactor * ffmod * ffnoiz, envgen) * (foldfactor.abs + 0.01).reciprocal;
    Out.ar([0, 1, 2, 3], sin + (sinfb * envgen) + sineshaper);
}).add;
);


// Pattern

(
~bassfoldseries = Array.series(11, 0.01, 0.001);
Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
        \curve, -16,
        \dur, Pshuf(([Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, 1.5, 2, 3].stutter(3)), inf),
        \fb, Pshuf((1..13) / 3, inf),
        \ffnoizamt, Pshuf([1, 2, 3, 4], inf),
        \ffstart, Pshuf([0.1, 0.25, 0.5, 0.75], inf),
        \ffend, Pshuf([2, 3, 4, 5, 7], inf),
		\foldfactor, Pshuf(~bassfoldseries.stutter(3), inf),
        \level, 0.015,
        \degree, Pshuf([-2, 0, 3], inf),
        \octave, 3,
		\scale, ~scale
));
Pdef(\basspat2,
    Pbindf(
        Pdef(\basspat1),
        \start, Pshuf(~ratios ++ (~ratios / 2), inf)
));
Pdef(\basspar, Ppar([Pdef(\basspat1), Pdef(\basspat2)], inf));
);

/*
Pdef(\basspat1).play(t, quant: 1);
Pdef(\basspat1).isPlaying;
Pdef(\basspat1).stop;
*/

/*
Pdef(\basspat2).play(t, quant: 1);
Pdef(\basspat2).isPlaying;
Pdef(\basspat2).stop;
*/

/*
Pdef(\basspar).play(t, quant: 1);
Pdef(\basspar).isPlaying;
Pdef(\basspar).stop;
*/

// Midi Control

(
MIDIdef.cc(\bassplay, {
	if(Pdef(\basspar).isPlaying.not) {
		Pdef(\basspar).play(t, quant: 1);
		"bass play".postln;
	}
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\bassstop, {
    if(Pdef(\basspar).isPlaying) {
        Pdef(\basspar).stop;
        "bass stop".postln;
    }
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
SynthDef(\bufrd, { | amp = 1, curve = -4, dur = 1, filt_freq = 8000, filt_rq = 1, freq = 440, gate = 1, pan = 0 |
	var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.005, amp, 0.005, curve);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(b.numChannels, b.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var rhpf			=	RHPF.ar(bufrd, filt_freq, filt_rq, envgen * kbn1 * 2);
	//var delay			=	DelayC.ar(rhpf, 0.2, (freq.reciprocal).clip(50, SampleRate.ir / 3));
	var pan2			=	Pan2.ar(rhpf, pan);
	Out.ar(0, pan2);
}).add;
);

(
Pdef(\rbpdef,
	Pbind(
		\instrument, \recbuf,
		\dur, 6,
));
);

/*
Pdef(\rbpdef).play(t, quant: 3);
Pdef(\rbpdef).isPlaying;
Pdef(\rbpdef).stop;
*/

(
Pdef(\pbpat1,
	Pbind(
		\instrument, \bufrd,
		\amp, 0.5,
		\curve, -64,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 1.75, 2, 3, 4, 6].stutter(2), inf),
		\filt_freq, Pwhite(4000, 8000, inf),
		\filt_rq, Pwhite(0.3, 0.5, inf),
		\freq, Pwhite(100, 10000, inf),
		\pan, 0,
));
Pdef(\pbpat2, Pbindf(Pdef(\pbpat1), \amp, 0.2, \pan, -1));
Pdef(\pbpat3, Pbindf(Pdef(\pbpat2), \pan, 1));
Pdef(\pbpar, Ppar([Pdef(\pbpat1), Pdef(\pbpat2), Pdef(\pbpat2)], inf));
);

/*
Pdef(\pbpar).play(t, quant: 1.5);
Pdef(\pbpar).isPlaying;
Pdef(\pbpar).stop;
*/

// Midi Control

(
MIDIdef.cc(\rbktrl, {
	if(Pdef(\rbpdef).isPlaying.not) {
		Pdef(\rbpdef).play(t, quant: 3);
		"recbuf play".postln;
	} {
		Pdef(\rbpdef).stop;
		"recbuf stop".postln;
	};
}, 48, srcID: ~nanoktrl2.uid);
);

(
MIDIdef.cc(\pbktrl, {
	if(Pdef(\pbpar).isPlaying.not) {
		Pdef(\pbpar).play(t, quant: 1);
		"playbuf play".postln;
	} {
		Pdef(\pbpar).stop;
		"playbuf stop".postln;
	};
}, 64, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////////////
// PULSE

(
SynthDef(\pulse, { | bits = 24, curve = -128, dur = 1, freq = 400, level = 0.05, pan = 0 |
	var env				=	Env.new([0, level, 0], [0.0005, dur]);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var xline			=	XLine.ar(1, 0.1, dur);
	var lfn				=	LFBrownNoise0.ar(freq).range(1/3, 3);
	var sinfb			=	SinOscFB.ar(freq, xline * lfn).softclip * envgen;
	var pan2			=	Pan2.ar(sinfb, pan);
	Out.ar(4, pan2);
}).add;
);

//

(
Pdef(\pulsepat1,
	Pbind(
		\instrument, \pulse,
		\bits, Pbrown(8, 16, 1, inf).round(1),
        \degree, 0!3,
        \dur, 0.25,
        \level, 0.02,
        \octave, 5,
        \pan, Prand([-0.25, 0.25], inf),
		\scale, ~scale
));


Pdef(\pulsepat2,
    Pbindf(
        Pdef(\pulsepat1),
        \degree, Pseq([Rest].stutter(37) ++ [[-2, 0, 2]].stutter(97), inf),
        \dur, Pwrand([0.25, Pseq([0.375], 2)], [31, 1].normalizeSum, inf),
        \pan, Prand([-1, 1], inf)
));

Pdef(\pulsepat3, Pbindf(Pdef(\pulsepat2), \degree, Pseq([Rest].stutter(41) ++ [[0, 7]].stutter(101), inf)));

Pdef(\pulses, Ppar([Pdef(\pulsepat1), Pdef(\pulsepat2), Pdef(\pulsepat3)], inf));

Pdef(\pulsepat4, Pbindf(Pdef(\pulsepat1), \degree, ~chord, \octave, 6));
);

/*
Pdef(\pulsepat1).play(t, quant: 1);
Pdef(\pulsepat1).isPlaying;
Pdef(\pulsepat1).stop;
*/

/*
Pdef(\pulsepat2).play(t, quant: 1);
Pdef(\pulsepat2).isPlaying;
Pdef(\pulsepat2).stop;
*/

/*
Pdef(\pulsepat3).play(t, quant: 1);
Pdef(\pulsepat3).isPlaying;
Pdef(\pulsepat3).stop;
*/

/*
Pdef(\pulses).play(t, quant: 1);
Pdef(\pulses).isPlaying;
Pdef(\pulses).stop;
*/

/*
Pdef(\pulsepat4).play(t, quant: 1);
Pdef(\pulsepat4).isPlaying;
Pdef(\pulsepat4).stop;
*/

//

(
MIDIdef.cc(\pulsesplay, {
    if(Pdef(\pulses).isPlaying.not) {
        Pdef(\pulses).play(t, quant: 0.5);
        "pulses play".postln
    };
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pulsesstop, {
    if(Pdef(\pulses).isPlaying) {
        Pdef(\pulses).stop;
        "pulses stop".postln;
    };
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pulse4play, {
    if(Pdef(\pulsepat4).isPlaying.not) {
        Pdef(\pulsepat4).play(t, quant: 0.5);
        "pulse4 play".postln
    };
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pulse4stop, {
    if(Pdef(\pulsepat4).isPlaying) {
        Pdef(\pulsepat4).stop;
        "pulse4 stop".postln;
    };
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);


////////////////////////////////////////////////////////////////
// WUT

(
SynthDef(\wut, { |attack = 0.01, curve = 0, dur = 1, fb = 0, foldfactor = 1, freq = 440, gate = 1, k = 1.4, level = 0.01, release = 0.1|
    var env             =   Env.asr(attack, level, release, curve);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin             =   SinOscFB.ar(freq * LFNoise0.kr(15!2, 0.001, 1), fb * Standard2DC.kr(0.5, 500, [k, k + 0.1]).range(0, 1).fold(0, 1), envgen);
    var fold            =   sin.fold2(level * foldfactor) * foldfactor.reciprocal;
    Out.ar(0, fold);
}).add;
);

(
Pdef(\wut,
    Pbind(
        \instrument, \wut,
        \degree, [2, 7, 10, 12],
        \dur, 37,
        \fb, 1.1,
        \k, Pwhite(1.0, 2.0, inf),
        \legato, 0.75,
        \octave, 5,
        \release, 0.3,
        \scale, ~scale
));

/*
Pdef(\wat, Pbindf(Pdef(\wut), \degree, 10!2, \dur, 31, \legato, 0.25));

Pdef(\wot, Pbindf(Pdef(\wat), \degree, 14!2, \dur, 29));

Pdef(\wet, Pbindf(Pdef(\wat), \degree, 7!2, \dur, 23));

Pdef(\wuts, Ppar([Pdef(\wut), Pdef(\wat), Pdef(\wot), Pdef(\wet)], inf));
*/
);

/*
Pdef(\wut).play(t, quant: 1);
Pdef(\wut).isPlaying;
Pdef(\wut).stop;
*/

(
~wutdurs = [29, 31, 37, 41, 43];
Pdef(\hiwut1,
    Pbind(
        \instrument, \wut,
        \curve, -16,
        \degree, Pshuf(~wutchords, inf),
        \dur, Pshuf(~wutdurs, inf),
        \fb, 2.1,
        \foldfactor, 0.3,
        \k, Pwhite(1.0, 2.0, inf),
        \legato, 0.5,
        \octave, 6,
        \release, 2,
        \scale, ~scale,
));

//Pdef(\hiwuts, Ppar([Pdef(\hiwut1)].stutter(3)));
);

/*
Pdef(\hiwut1).play(t, quant: 1);
Pdef(\hiwut1).isPlaying;
Pdef(\hiwut1).stop;
*/

(
Pdef(\calmwuts,
    Pbind(
        \instrument, \wut,
        \attack, 0.1,
        \degree, Pshuf(~wutchords, inf),
        \dur, Pshuf(~wutdurs, inf),
        \fb, 1,
        \foldfactor, 2,
        \legato, 0.5,
        \octave, 6,
        \release, 0.1,
        \scale, ~scale
));
);

/*
Pdef(\calmwuts).play(t, quant: 1);
Pdef(\calmwuts).isPlaying;
Pdef(\calmwuts).stop;
*/

(
MIDIdef.cc(\wutplay, {
    if(Pdef(\wut).isPlaying.not) {
        Pdef(\wut).play(t, quant: 1);
        "wut".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\wutstop, {
    if(Pdef(\wut).isPlaying) {
        Pdef(\wut).stop;
        "no wut".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

//

(
MIDIdef.cc(\hiwutplay, {
    if(Pdef(\hiwut1).isPlaying.not) {
        Pdef(\hiwut1).play(t, quant: 1);
        "hiwut".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\hiwutstop, {
    if(Pdef(\hiwut1).isPlaying) {
        Pdef(\hiwut1).stop;
        "no hiwut".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

//

(
MIDIdef.cc(\calmwutsplay, {
    if(Pdef(\calmwuts).isPlaying.not) {
        Pdef(\calmwuts).play(t, quant: 1);
        "calmwut".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\calmwutsstop, {
    if(Pdef(\calmwuts).isPlaying) {
        Pdef(\calmwuts).stop;
        "no calmwut".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PAD

(
SynthDef(\pad, { | bits = 24, curve = -128, dur = 1, freq = 400, gate = 1, level = 0.01, release = 9 |
	var env				=	Env.asr(9, level, release, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var freqmod			=	LFNoise0.kr(15!2, 0.0001, 1);
    var xline			=	XLine.ar(1, 0.1, dur / 3);
	var lfn				=	LFBrownNoise0.ar(freq!2).range(0.1, 6);
	var sinfb1			=	SinOscFB.ar(freq * freqmod, xline * lfn).softclip * (envgen / 2);
	var sinfb2			=	SinOscFB.ar(freq, xline * lfn).softclip * (envgen / 2);
	Out.ar(0, sinfb1 + sinfb2);
}).add;
);

(
Pdef(\paddrone,
    Pmono(
        \pad,
        \dur, 53,
        \degree, [0, 2, 7, 10, 12],
        \octave, 5,
        \release, 0.1,
        \scale, ~scale
));

Pdef(\pad1,
    Pbind(
        \instrument, \pad,
        \dur, Pshuf([43, 47, 53, 59, 61], inf),
        \degree, Pshuf(~chord, inf),
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
MIDIdef.cc(\paddronektrl, {
	if(Pdef(\paddrone).isPlaying.not) {
		Pdef(\paddrone).play(t, quant: 1);
		"paddrone play".postln;
	} {
		Pdef(\paddrone).stop;
		"paddrone stop".postln;
	};
}, 69, srcID: ~nanoktrl2.uid);
);

(
MIDIdef.cc(\pads1play, {
    if(Pdef(\pads1).isPlaying.not) {
        Pdef(\pads1).play(t, quant: 0.5);
        "pads1 play".postln;
    };
}, 38, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pads1stop, {
    if(Pdef(\pads1).isPlaying) {
        Pdef(\pads1).stop;
        "pads1 stop".postln;
    };
}, 38, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

//

(
MIDIdef.cc(\pads2play, {
    if(Pdef(\pads2).isPlaying.not) {
        Pdef(\pads2).play(t, quant: 0.5);
        "pads2 play".postln;
    };
}, 54, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pads2stop, {
    if(Pdef(\pads2).isPlaying) {
        Pdef(\pads2).stop;
        "pads2 stop".postln;
    };
}, 54, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

//

(
MIDIdef.cc(\pad3play, {
    if(Pdef(\pad3).isPlaying.not) {
        Pdef(\pad3).play(t, quant: 0.5);
        "pad3 play".postln;
    };
}, 70, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad3stop, {
    if(Pdef(\pad3).isPlaying) {
        Pdef(\pad3).stop;
        "pad3 stop".postln;
    };
}, 70, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PINGLE

(
SynthDef(\pingle, { | a = 0.02, curve = -16, freq = 10000, level = 0.05, pan = 0 |
	var env				=	Env.perc(releaseTime: 0.003, level: level, curve: curve);
	var envgen			=	EnvGen.ar(env, doneAction: 2);
	var pn              =   PinkNoise.ar(envgen!2);
    var rhpf            =   RHPF.ar(pn, 12000, 0.03);
    Out.ar(4, (rhpf).fold2(level));
}).add;
);

// Pattern

(
~pinglelevel = 0.08;
~pingleecholevel = ~pinglelevel / 5;
Pdef(\pinglepat,
	Pbind(
		\instrument, \pingle,
		\curve, -64,
		\dur, Pshuf([
			Pseq([1/12], 3),
			Pseq([1/8], 2),
			Pxrand([0.75, 1, 1.25], 31)
		], inf),
		\level, ~pinglelevel,
		\pan, Pwhite(-1.0, 1.0, inf),
		\degree, 0,
        \octave, 10,
		\scale, ~scale
));
Pdef(\pinglepatt, Pbindf(Pdef(\pinglepat), \dur, 0.25, \level, ~pingleecholevel));
Pdef(\pingleparf, Ppar([Pdef(\pinglepat), Pdef(\pinglepatt)], inf));
);

/*
Pdef(\pinglepat).play(t, quant: 1);
Pdef(\pinglepat).isPlaying;
Pdef(\pinglepat).stop;
*/

/*
Pdef(\pingleparf).play(t, quant: 1);
Pdef(\pingleparf).isPlaying;
Pdef(\pingleparf).stop;
*/

(
MIDIdef.cc(\pinglektrl, {
	if(Pdef(\pingleparf).isPlaying.not) {
		Pdef(\pingleparf).play(t, quant: 1);
		"pingle play".postln;
	} {
		Pdef(\pingleparf).stop;
		"pingle stop".postln;
	};
}, 35, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////////////
// CLAP

(
SynthDef(\clap, { | curve = 4, dur = 1, delaytime = 0.01, freq = 1000, level = 0.2, offset = 0, pan = 0 |
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var gbman           =   GbmanL.ar(freq / 2, freq, mul: envgen).fold2(level);
    var delay           =   DelayC.ar(gbman, 0.01, delaytime.clip(0.0001, 0.01));
    var res             =   Resonz.ar(gbman + delay, freq.clip(50, SampleRate.ir / 2.5), 0.1);
    var pan2			= 	Pan2.ar(res, pan);
	Out.ar(4, pan2);
}).add;
);

(
~clapdurs = [
    0.75, 1,
    0.75, 1, 1.25,
    0.75, 1, 1.25, 1.5
		];
//~clapchords = (0..~ratios.size).powerset.reject({ |i| i.size != 6 });
~claplvl = 0.05;
~clapecholvl = ~claplvl / 3;
Pdef(\clappat1,
	Pbind(
		\instrument, \clap,
        \curve, Prand([-64, -32, -16], inf),
        \delaytime, Pwhite(0.0001, 0.1, inf),
        \dur, Pshuf([
            Pseq([0.125], 2), 0.25, Pseq([0.125], 4), 0.5, Pseq([0.125], 6), 0.75, Pseq([0.125], 8), 1, 2, 3, 4, 6
        ], inf),
        \level, ~claplvl,
        \degree, Pshuf([[-5, -2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]], inf),
        \octave, Pshuf((1..13), inf),
		\pan, 0,
        \scale, ~scale
));
Pdef(\clappat2, Pbindf(Pdef(\clappat1), \dur, Pshuf(~clapdurs.stutter(3), inf), \level, ~clapecholvl, \pan, -1));
Pdef(\clappat3, Pbindf(Pdef(\clappat2), \pan, 1));
Pdef(\clappar, Ppar([Pdef(\clappat1), Pdef(\clappat2), Pdef(\clappat3)], inf));
);

/*
Pdef(\clappar).play(t, quant: 0.5);
Pdef(\clappar).isPlaying;
Pdef(\clappar).stop;
*/

(
MIDIdef.cc(\clapparktrl, {
	if(Pdef(\clappar).isPlaying.not) {
		Pdef(\clappar).play(t, quant: 0.5);
		"clap play".postln;
	} {
		Pdef(\clappar).stop;
		"clap stop".postln;
	};
}, 51, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////////////
// PRC1

(
SynthDef(\prc1, { |curve = -16, dur = 1, ffreq = 4000, freq = 1000, level = 0.2, xaos = 1.5|
    var env             =   Env.perc(0.01, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var noiz            =   LFBrownNoise2.ar((freq!2 * XLine.kr(1, 0.1, dur))).tanh;
    var crackle         =   Crackle.ar(xaos!2, 1, 1);
    var ffreqmod        =   LFNoise0.kr((t.tempo * 6)!2).range(0.25, 1);
    var rhpf            =   RHPF.ar(noiz * crackle, (ffreq * ffreqmod).clip(50, SampleRate.ir / 2.5), 1, envgen);
    Out.ar(4, rhpf.fold2(level / 8) * 2);
}).add;
);

(
Pdef(\prc1,
    Pbind(
        \instrument, \prc1,
        \dur, Pshuf([0.75, 1, 1.5].stutter(5), inf),
        \ffreq, Pshuf((1..23) * 100, inf),
        \freq, Pseq([500, 7500, 15000], inf),
        \xaos, Pshuf((12..19) / 10, inf)
));
);

/*
Pdef(\prc1).play(t);
Pdef(\prc1).stop;
*/

(
MIDIdef.cc(\prc1play, {
    if(Pdef(\prc1).isPlaying.not) {
        Pdef(\prc1).play(t, quant: 0.5);
        "prc1 play".postln;
    };
}, 67, argTemplate: { |x| x > 0 }, srcID: ~nanoktrl2.uid);

MIDIdef.cc(\prc1stop, {
    if(Pdef(\prc1).isPlaying) {
        Pdef(\prc1).stop;
        "prc1 stop".postln;
    };
}, 67, argTemplate: 0, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////////////
// HEAVY PERC

(
SynthDef(\heavy, { | brightness = 1000, curve = -8, dur = 1, freq = 440, level = 0.03, pan = 0, sinfb = 0 |
	var env				=	Env.perc(0.005, releaseTime: 1, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var kxline			=	XLine.kr(1, 0.125, dur / 5);
	var sin				=	SinOscFB.ar(freq * kxline, sinfb, envgen);
	var filtfreqmod		=	LFNoise0.kr(50!2).range(1/5, 5);
	var filtrqmod		=	LFNoise0.kr(50!2).range(0.2, 0.9).round(0.1) + 0.05;
	var delay			=	DelayC.ar(sin, 0.5, freq.clip(50, SampleRate.ir / 3).reciprocal, 0.5);
	var rez				=	RLPF.ar(sin + delay, (brightness * kxline * filtfreqmod).clip(30, SampleRate.ir / 4), filtrqmod);
    var rlpf            =   RLPF.ar(rez, freq.clip(50, SampleRate.ir / 3));
    var rhpf            =   RHPF.ar(rez, (freq * 4).clip(50, SampleRate.ir / 3), 0.3);
    var pan2			=	Pan2.ar(rez, pan);
	Out.ar(4, pan2);
}).add;
);

// Pattern

(
~heavypatlvl = 0.03;
~heavypatecholvl = ~heavypatlvl / 4;
Pdef(\heavypat1,
	Pbind(
		\instrument, \heavy,
		\brightness, Pshuf([1000, 4000, 8000].stutter(7), inf),
		\curve, Pshuf([-16, -4, 0, 2, 4], inf),
        \degree, Pseq([Pseq([[0, 7, 10]], 29), Pseq([Rest], 17)], inf),
        \dur, Pshuf([
            Pseq([1/3], 3), Pseq([2/5], 5), Pseq([2/7], 7),
            2, 3, 4, 6, 8, 12
        ], inf),
        \level, ~heavypatlvl,
		\octave, 5,
		\pan, Prand([-0.5, 0, 0.5], inf),
        \scale, ~scale,
		\sinfb, Pshuf((4..6), inf)
));

Pdef(\heavypat2,
    Pbind(
        \instrument, \heavy,
        \brightness, Pshuf((1..7) * 2000 , inf),
        //\brightness, 15000,
        \curve, Pshuf([-64, -32, -16, -8], inf),
        \degree, [-5, -2, 0],
        \dur, Pshuf([
            Pseq([0.125], 2), 0.25, Pseq([0.125], 4), 0.5, Pseq([1/6], 3), 0.75, 1, 1.5, 2, 3
        ].stutter(3), inf),
        \level, ~heavypatlvl,
        \octave, Pshuf((2..7), inf),
        \scale, ~scale,
        \sinfb, Pshuf((2..5) + 0.5, inf)
));

Pdef(\heavypat3,
    Pbindf(
        Pdef(\heavypat2),
        \level, ~heavypatecholvl,
        \pan, Prand([-1, 1], inf),
        \sinfb, Pshuf((4..6), inf)
));

Pdef(\heavypar, Ppar([Pdef(\heavypat2), Pdef(\heavypat3)], inf));
);

/*
Pdef(\heavypat1).play(t, quant: 1);
Pdef(\heavypat1).isPlaying;
Pdef(\heavypat1).stop;
*/

/*
Pdef(\heavypat2).play(t, quant: 1);
Pdef(\heavypat2).isPlaying;
Pdef(\heavypat2).stop;
*/

/*
Pdef(\heavypat3).play(t, quant: 1);
Pdef(\heavypat3).isPlaying;
Pdef(\heavypat3).stop;
*/

/*
Pdef(\heavypar).play(t, quant: 1);
Pdef(\heavypar).isPlaying;
Pdef(\heavypar).stop;
*/

// Midi Control

(
MIDIdef.cc(\heavy1ktrl, {
	if(Pdef(\heavypat1).isPlaying.not) {
		Pdef(\heavypat1).play(t, quant: 1);
		"heavy solo play".postln;
	} {
		Pdef(\heavypat1).pause;
		"heavy solo stop".postln;
	};
}, 36, srcID: ~nanoktrl2.uid);
);

(
MIDIdef.cc(\heavyktrl, {
	if(Pdef(\heavypar).isPlaying.not) {
		Pdef(\heavypar).play(t, quant: 1);
		"heavy prcs play".postln;
	} {
		Pdef(\heavypar).pause;
		"heavy prcs stop".postln;
	};
}, 52, srcID: ~nanoktrl2.uid);
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
    Out.ar(4, pan2).fold2(level);
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
MIDIdef.cc(\prcparktrl, {
	if(Pdef(\prcpar).isPlaying.not) {
		Pdef(\prcpar).play(t, quant: 1);
		"prc play".postln;
	} {
		Pdef(\prcpar).stop;
		"prc stop".postln;
	};
}, 37, srcID: ~nanoktrl2.uid);
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
	Out.ar(4, pan2);
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
}, 53, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\murkystop, {
    if(Pdef(\murkys).isPlaying) {
        Pdef(\murkys).stop;
        "murkys stop".postln;
    }
}, 53, srcID: ~nanoktrl2.uid, argTemplate: 0)
);