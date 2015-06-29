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
t = TempoClock(120/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);
);

(
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 14/9, 7/4, 243/128];
~tuning = Tuning.new(~ratios.ratiomidi);
//~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
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
        \dur, Pshuf(([0.25, 0.5, 0.75, 0.75, 1.5, 2.25, 6].stutter(3)), inf),
        \fb, Pshuf((1..13) / 13, inf),
        \ffnoizamt, Pshuf([1, 2, 3, 4], inf),
        \ffstart, Pshuf([0.1, 0.25, 0.5, 0.75], inf),
        \ffend, Pshuf([2, 3, 4, 5, 7], inf),
		\foldfactor, Pshuf(~bassfoldseries.stutter(3), inf),
        \level, 0.015,
        \note, 0,
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
	var env				=	Env.new([0, level, 0], [0.001, dur]);
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
~pulsedurarray = [Pseq([0.25], 31), Pseq([0.5], 3), Pseq([0.75], 4), Pseq([1/3], 3), Pseq([2/5], 5), Pseq([2/7], 7)];
Pdef(\pulsepat1,
	Pbind(
		\instrument, \pulse,
		\bits, Pbrown(8, 16, 1, inf).round(1),
		\dur, Pshuf(~pulsedurarray, inf),
        \level, 0.02,
		\note, 0,
        \octave, 5,
		\pan, 0,
		\scale, ~scale
));
Pdef(\pulsepat2, Pbindf(Pdef(\pulsepat1), \pan, Prand([-1, 1], inf)));
Pdef(\pulsepat3, Pbindf(Pdef(\pulsepat2)));
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

//

(
MIDIdef.cc(\pulsektrl1, {
	if(Pdef(\pulsepat1).isPlaying.not) {
		Pdef(\pulsepat1).play(t, quant: 1);
		"pulse1 play".postln;
	} {
		Pdef(\pulsepat1).stop;
		"pulse1 stop".postln;
	};
}, 33, srcID: ~nanoktrl2.uid);
);

(
MIDIdef.cc(\pulsektrl2, {
    if(Pdef(\pulsepat2).isPlaying.not) {
		Pdef(\pulsepat2).play(t, quant: 1);
		"pulse2 play".postln;
	} {
		Pdef(\pulsepat2).stop;
		"pulse2 stop".postln;
	};
}, 49, srcID: ~nanoktrl2.uid);
);

(
MIDIdef.cc(\pulsektrl3, {
	if(Pdef(\pulsepat3).isPlaying.not) {
		Pdef(\pulsepat3).play(t, quant: 1);
		"pulse3 play".postln;
	} {
		Pdef(\pulsepat3).stop;
		"pulse3 stop".postln;
	};
}, 65, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////////////
// WUT

(
SynthDef(\wut, { |attack = 0.01, dur = 1, fb = 0, foldfactor = 1, freq = 440, gate = 1, level = 0.03, release = 0.1|
    var env             =   Env.asr(attack, level, release, 0);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin             =   SinOscFB.ar(freq!2, fb * Standard2DC.kr(1, 10, add: 1).fold(0, 1), envgen);
    var fold            =   sin.fold2(level * foldfactor) * foldfactor.reciprocal;
    Out.ar(0, fold);
}).add;
);

(
Pdef(\wut, Pbind(\instrument, \wut, \dur, 37, \fb, 0.1, \legato, 1, \octave, 5, \scale, ~scale));
Pdef(\wat, Pbindf(Pdef(\wut), \dur, 31, \legato, 0.5));
Pdef(\wot, Pbindf(Pdef(\wut), \dur, 29, \legato, 0.5, \note, Pseq([-2, Rest], inf)));
Pdef(\wuts, Ppar([Pdef(\wut), Pdef(\wat), Pdef(\wot)], inf));
);

/*
Pdef(\wuts).play(t, quant: 1);
Pdef(\wuts).isPlaying;
Pdef(\wuts).stop;
*/

(
//~wutchords1 = Array.fill(~ratios.size, { |i| [0, 7, i, i + 7] });
//~wutchords2 = Array.fill(~ratios.size, { |i| [0, 7, i - 2, i + 2] });
~wutdurs = [41, 43, 47, 53, 59] + 0.25;
Pdef(\hiwut1,
    Pbind(
        \instrument, \wut,
        \dur, Pshuf(~wutdurs, inf),
        \fb, 1.5,
        \foldfactor, 0.3,
        \legato, 0.5,
        \note, Pshuf([[-5, 2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10]], inf),
        \octave, 6,
        \scale, ~scale,
));
//Pdef(\hiwut2, Pbindf(Pdef(\hiwut1), \note, Pshuf(~wutchords2, inf)));
Pdef(\hiwut3, Pbindf(Pdef(\hiwut1), \note, [-2, 0, 2, 7]));
Pdef(\hiwuts, Ppar([Pdef(\hiwut1), Pdef(\hiwut3)]));
);

/*
Pdef(\hiwuts).play(t, quant: 1);
Pdef(\hiwuts).isPlaying;
Pdef(\hiwuts).stop;
*/

(
Pdef(\calmwuts,
    Pbind(
        \instrument, \wut,
        \attack, 0.1,
        \dur, Pshuf(~wutdurs, inf),
        \fb, 1,
        \foldfactor, 2,
        \legato, 0.25,
        \note, Pshuf([[-2, 0, 2, 7].stutter(2), Rest], inf),
        \release, 10,
        \scale, ~scale
));
);

/*
Pdef(\calmwuts).play(t, quant: 1);
Pdef(\calmwuts).isPlaying;
Pdef(\calmwuts).stop;
*/


(
MIDIdef.cc(\wutsplay, {
    if(Pdef(\wuts).isPlaying.not) {
        Pdef(\wuts).play(t, quant: 1);
        "wut".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\wutsstop, {
    if(Pdef(\wuts).isPlaying) {
        Pdef(\wuts).stop;
        "no wut".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

//

(
MIDIdef.cc(\hiwutsplay, {
    if(Pdef(\hiwuts).isPlaying.not) {
        Pdef(\hiwuts).play(t, quant: 1);
        "hiwut".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\hiwutsstop, {
    if(Pdef(\hiwuts).isPlaying) {
        Pdef(\hiwuts).stop;
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
SynthDef(\pad, { | bits = 24, curve = -128, dur = 1, freq = 400, gate = 1, level = 0.01 |
	var env				=	Env.asr(9, level, 0.01);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var freqmod			=	LFNoise0.kr(15!2, 0.0001, 1);
    var xline			=	XLine.ar(1, 0.25, dur / 2);
	var lfn				=	LFBrownNoise0.ar(freq!2).range(0.1, 5);
	var sinfb1			=	SinOscFB.ar(freq * freqmod, xline * lfn).softclip * (envgen / 2);
	var sinfb2			=	SinOscFB.ar(freq, xline * lfn).softclip * (envgen / 2);
	Out.ar(0, sinfb1 + sinfb2);
}).add;
);

(
Pdef(\padpat,
	Pbind(
		\instrument, \pad,
		\dur, Pshuf(Array.fill(5, { |i| (i + 9).nthPrime }), inf),
		\note, Pshuf([-2, 0, 2, 7], inf),
		\octave, 7,
		\scale, ~scale
));
Pdef(\padpar, Ppar([Pdef(\padpat)].stutter(5), inf));
);

/*
Pdef(\padpar).play(t, quant: 1);
Pdef(\padpar).isPlaying;
Pdef(\padpar).stop;
*/

Pdef(\paddrone, Pmono(\pad, \dur, 23, \note, [0, 7, 12], \octave, 4, \scale, ~scale));

/*
Pdef(\paddrone).play(t, quant: 1);
Pdef(\paddrone).isPlaying;
Pdef(\paddrone).stop;
*/

Pdef(\padpatlo, Pbindf(Pdef(\padpat), \note, Pshuf([7, 10, 12, 14], inf), \octave, 5));
Pdef(\padparlo, Ppar([Pdef(\padpatlo)].stutter(5)));

/*
Pdef(\padparlo).play(t, quant: 1);
Pdef(\padparlo).isPlaying;
Pdef(\padparlo).stop;
*/

(
MIDIdef.cc(\padparktrl, {
	if(Pdef(\padpar).isPlaying.not) {
		Pdef(\padpar).play(t, quant: 1);
		"padpar play".postln;
	} {
		Pdef(\padpar).pause;
		"padpar stop".postln;
	};
}, 37, srcID: ~nanoktrl2.uid);
);

//

(
MIDIdef.cc(\paddronektrl, {
	if(Pdef(\paddrone).isPlaying.not) {
		Pdef(\paddrone).play(t, quant: 1);
		"paddrone play".postln;
	} {
		Pdef(\paddrone).stop;
		"paddrone stop".postln;
	};
}, 53, srcID: ~nanoktrl2.uid);
);

//

(
MIDIdef.cc(\padparloktrl, {
	if(Pdef(\padparlo).isPlaying.not) {
		Pdef(\padparlo).play(t, quant: 1);
		"padparlo play".postln;
	} {
		Pdef(\padparlo).pause;
		"padparlo stop".postln;
	};
}, 69, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////////////
// PINGLE

(
SynthDef(\pingle, { | a = 0.02, curve = -16, delaytime = 0.0005, foldfactor = 2, freq = 10000, level = 0.05, pan = 0 |
	var env				=	Env.perc(releaseTime: 1, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	SinOsc.ar(freq!2, mul: envgen);
	var delay			=	DelayC.ar(sin, 0.2, delaytime.clip(0.0001, 0.2));
	Out.ar(4, sin + delay);
}).add;
);

// Pattern

(
~pinglelevel = 0.008;
~pingleecholevel = ~pinglelevel / 5;
Pdef(\pinglepat,
	Pbind(
		\instrument, \pingle,
		\curve, -32,
		\delaytime, Pshuf((1..11) / 2000, inf),
		\dur, Pshuf([
			Pseq([1/12], 3),
			Pseq([1/8], 2),
			Pxrand([0.75, 1, 1.25], 31)
		], inf),
		\level, ~pinglelevel,
		\pan, Pwhite(-1.0, 1.0, inf),
		\note, 0,
        \octave, 10,
		\scale, ~scale
));
Pdef(\pinglepatt, Pbindf(Pdef(\pinglepat), \dur, 0.25, \level, ~pingleecholevel));
Pdef(\pingleparf, Ppar([Pdef(\pinglepat), Pdef(\pinglepatt)], inf));
);

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
    var pan2			= 	Pan2.ar(gbman + delay, pan);
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
~claplvl = 0.02;
~clapecholvl = ~claplvl / 3;
Pdef(\clappat1,
	Pbind(
		\instrument, \clap,
        \curve, Prand([-64, -32, -16], inf),
        \delaytime, Pwhite(0.0001, 0.1, inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 2, 3, 4, 6, 8, 12, 16, 24], inf),
        \level, ~claplvl,
        \note, Pshuf([[-5, -2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]], inf),
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
        \dur, Pshuf([
            Pseq([1/3], 3), Pseq([2/5], 5), Pseq([2/7], 7),
            2, 3, 4, 6, 8, 12
        ], inf),
        \level, ~heavypatlvl,
        \note, Pseq([Pseq([[0, 7, 10]], 29), Pseq([Rest], 17)], inf),
		\octave, 5,
		\pan, Prand([-0.5, 0, 0.5], inf),
		\sinfb, Pshuf((4..6), inf)
));
Pdef(\heavypat2,
    Pbind(
        \instrument, \heavy,
        \brightness, Pshuf((1..7) * 2000 , inf),
        //\brightness, 15000,
        \curve, Pshuf([-64, -32, -16, -8], inf),
        \dur, Pshuf([0.25, 0.5, Pseq([1/6], 3), 0.75, 1, 1.25, 1.5, 1.75, 2].stutter(3), inf),
        \level, ~heavypatlvl,
        \note, [-5, -2, 0, 2],
        \octave, Pshuf((3..7), inf),
        \sinfb, Pshuf((1..3), inf)
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
MIDIdef.cc(\heavyktrl, {
	if(Pdef(\heavypar).isPlaying.not) {
		Pdef(\heavypar).play(t, quant: 1);
		"heavy prcs play".postln;
	} {
		Pdef(\heavypar).pause;
		"heavy prcs stop".postln;
	};
}, 67, srcID: ~nanoktrl2.uid);
);

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
		\note, Pseq([Rest, 0, Rest, Rest, 0, Rest, Rest, Rest, 0], inf),
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
		\note, 0!2,
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
}, 52, srcID: ~nanoktrl2.uid);
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
        \note, Pshuf([-2, 0, 1, 2, 3, 7], inf),
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
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\murkystop, {
    if(Pdef(\murkys).isPlaying) {
        Pdef(\murkys).stop;
        "murkys stop".postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////
// PNO

(
SynthDef(\pno, { |curve = -4, dur = 1, fb = 0, freq = 440, level = 0.01|
    var env             =   Env.perc(0.01, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var balmod          =   LFClipNoise.ar(80!2).lag2(0.001);
    var sin1            =   SinOscFB.ar(freq!2, fb, envgen);
    var sin2            =   SinOscFB.ar(freq!2, fb, envgen);
    var sin3            =   SinOscFB.ar(freq!2 * 17, fb, envgen / 17);
    var bal1            =   Balance2.ar(sin1[0], sin1[1], balmod[0]);
    var bal3            =   Balance2.ar(sin3[0], sin3[1], balmod[1]);
    Out.ar(0, bal1 + sin2 + bal3);
}).add;
);

(
Pdef(\pno,
    Pbind(
        \instrument, \pno,
        \curve, -32,
        \dur, 47,
        \fb, 0,
        \note, [0, 2],
        \octave, 6
));
);

/*
Pdef(\pno).play(t, quant: 1);
Pdef(\pno).isPlaying;
Pdef(\pno).stop;
*/

(
MIDIdef.cc(\pnoplay, {
    if(Pdef(\pno).isPlaying.not) {
        Pdef(\pno).play(t, quant: 1);
        "pno play".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnostop, {
    if(Pdef(\pno).isPlaying) {
        Pdef(\pno).stop;
        "pno stop".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: 0)
);
