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
b = Buffer.alloc(s, s.sampleRate * (~tempo.tempo * 6), 1);
);

(
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 14/9, 7/4, 243/128];
~tuning = Tuning.new(~ratios.ratiomidi);
~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
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
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.001, slopeAbove: 1/128); // compressor
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
SynthDef(\bass, { | dur = 1, foldfactor = 3, freq = 100, level = 0.05 |
 	var env				=	Env.perc(releaseTime: dur, level: level, curve: -2);
 	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin1			=	SinOsc.ar(freq);
	var sinmix			=	Mix.fill(3, {
		|i|
		var freqmod			=	LFNoise2.kr(3!2, 0.01, 1);
		var sin				=	SinOsc.ar(freq * (i + 1) * freqmod);
		sin / 2.pow(i);
	});
	var oscs			=	(sin1 + sinmix);
	var distoscs		=	oscs.fold2(level / foldfactor) * foldfactor * 2;
	Out.ar([0, 1, 2, 3], (oscs * envgen) + (distoscs * envgen));
}).add;
);


// Pattern

(
~bassfoldseries = Array.series(11, 0.1, 0.2);
Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
		\dur, Pshuf([
			Pseq([0.75, 0.75, 0.5, 0.5]),
			Pseq([0.5, 1]),
			Pseq([1, 1.5]),
			Pseq([1, 0.75, 0.75, 1])
		].stutter(3), inf),
		\foldfactor, Pshuf(~bassfoldseries.stutter(3), inf),
		\note, Pseq([Pseq([0], 53), Pseq([1], 31), Pseq([2], 31), Pseq([-2], 17), Pseq([-1], 17)], inf),
		\octave, 3,
		\scale, ~scale
));
);

/*
Pdef(\basspat1).play(t, quant: 1);
Pdef(\basspat1).isPlaying;
Pdef(\basspat1).stop;
*/

// Midi Control

(
MIDIdef.cc(\bassktrl, {
	if(Pdef(\basspat1).isPlaying.not) {
		Pdef(\basspat1).play(t, quant: 1);
		"bass play".postln;
	} {
		Pdef(\basspat1).stop;
		"bass stop".postln;
	};
}, 32, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////
// BUFFER-STUTTER

(
SynthDef(\recbuf, { | dur = 2, gate = 1, inBus = 2, isRecording = 1, trigger = 1 |
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var in				=	In.ar(inBus, ~buffer.numChannels);
	var recbuf 			=	RecordBuf.ar(in, ~buffer.bufnum, recLevel: envgen, run: isRecording, loop: 0, trigger: trigger, doneAction: 2);
}).add;
);

(
SynthDef(\bufrd, { | amp = 1, curve = -4, dur = 1, filt_freq = 3000, filt_rq = 1, freq = 440, gate = 1, pan = 0 |
	var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.005, amp, 0.005, curve);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(~buffer.numChannels, ~buffer.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var rhpf			=	RHPF.ar(bufrd, filt_freq, filt_rq, envgen * kbn1 * 2);
	var delay			=	DelayC.ar(rhpf, 0.2, (freq.reciprocal).clip(50, SampleRate.ir / 3));
	var pan2			=	Pan2.ar(rhpf + delay, pan);
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
		\amp, 1,
		\curve, -64,
		\dur, Prand([0.25, 0.5, 0.75], inf),
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
		Pdef(\pbpar).play(~tempo, quant: 1);
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
	var env				=	Env.new([0, level, 0], [0.01, dur]);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var xline			=	XLine.ar(0.999, 0.001, dur);
	var lfn				=	LFBrownNoise0.ar(freq).range(0.1, 10);
	var sinfb			=	SinOscFB.ar(freq, xline * lfn).softclip * envgen;
	var pan2			=	Pan2.ar(sinfb, pan);
	Out.ar(4, pan2);
}).add;
);

//

(
~pulsedurarray = [Pseq([0.25], 53), Pseq([0.25], 31), Pseq([1/3], 3), Pseq([0.75], 4), Pseq([2/5], 5)];
Pdef(\pulsepat1,
	Pbind(
		\instrument, \pulse,
		\bits, Pbrown(8, 16, 1, inf).round(1),
		\dur, Pshuf(~pulsedurarray, inf),
		//\level, Pshuf([1, 0.5].stutter(5) * 0.01, inf),
		\note, 0,
		\pan, Pshuf([-0.5, 0, 0.5].stutter(13), inf),
		\scale, ~scale
));
Pdef(\pulsepat2, Pbindf(Pdef(\pulsepat1), \note, 2));
Pdef(\pulsepat3, Pbindf(Pdef(\pulsepat1), \note, 3));
Pdef(\pulsepat4, Pbindf(Pdef(\pulsepat1), \note, 1));
Pdef(\pulsepat5, Pbindf(Pdef(\pulsepat1), \note, -2));
Pdef(\pulsepat6, Pbindf(Pdef(\pulsepat1), \note, 7));
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
Pdef(\pulsepat4).play(t, quant: 1);
Pdef(\pulsepat4).isPlaying;
Pdef(\pulsepat4).stop;
*/

/*
Pdef(\pulsepat5).play(t, quant: 1);
Pdef(\pulsepat5).isPlaying;
Pdef(\pulsepat5).stop;
*/

/*
Pdef(\pulsepat6).play(t, quant: 1);
Pdef(\pulsepat6).isPlaying;
Pdef(\pulsepat6).stop;
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

(
MIDIdef.cc(\pulsektrl4, {
	if(Pdef(\pulsepat4).isPlaying.not) {
		Pdef(\pulsepat4).play(t, quant: 1);
		"pulse4 play".postln;
	} {
		Pdef(\pulsepat4).stop;
		"pulse4 stop".postln;
	};
}, 34, srcID: ~nanoktrl2.uid);
);

(
MIDIdef.cc(\pulsektrl5, {
	if(Pdef(\pulsepat5).isPlaying.not) {
		Pdef(\pulsepat5).play(t, quant: 1);
		"pulse5 play".postln;
	} {
		Pdef(\pulsepat5).stop;
		"pulse5 stop".postln;
	};
}, 50, srcID: ~nanoktrl2.uid);
);

(
MIDIdef.cc(\pulsektrl6, {
	if(Pdef(\pulsepat6).isPlaying.not) {
		Pdef(\pulsepat6).play(t, quant: 1);
		"pulse6 play".postln;
	} {
		Pdef(\pulsepat6).pause;
		"pulse6 stop".postln;
	};
}, 66, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////////////
// PAD

(
SynthDef(\pad, { | bits = 24, curve = -128, dur = 1, freq = 400, gate = 1, level = 0.03 |
	var env				=	Env.asr(9, level, 0.01);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var freqmod			=	LFNoise2.kr(0.1!2, 0.0001, 1);
	var xline			=	XLine.ar(0.5, 0.1, dur / 2);
	var lfn				=	LFBrownNoise0.ar(freq!2).range(0.1, 10);
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
		\note, Pshuf([-2, 0, 1, 2, 3, 7], inf),
		\octave, 8,
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

Pdef(\padpatlo, Pbindf(Pdef(\padpat), \octave, 6));
Pdef(\padparlo, Ppar([Pdef(\padpatlo)].stutter(2)));

/*
Pdef(\padparlo).play(~tempo, quant: 1);
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
SynthDef(\pingle, { | a = 0.02, curve = -16, delaytime = 0.0005, foldfactor = 2, freq = 10000, level = 0.1, pan = 0 |
	var env				=	Env.perc(releaseTime: 1, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar([freq, freq - 10] * 4, a, 3, add: 1);
	var sin				=	SinOsc.ar(freq * cusp, mul: envgen);
	var delay			=	DelayC.ar(sin, 0.2, delaytime.clip(0.0001, 0.2));
	Out.ar(4, sin).softclip;
}).add;
);

// Pattern

(
~mainlevel = 0.01;
~echolevel = ~mainlevel / 6;
Pdef(\pinglepat,
	Pbind(
		\instrument, \pingle,
		\a, 0.01,
		\curve, -64,
		\delaytime, Pshuf((1..11) / 2000, inf),
		\dur, Pshuf([
			Pseq([1/12], 3),
			Pseq([1/8], 2),
			Pxrand([0.75, 1, 1.25], 31)
		], inf),
		\level, ~mainlevel,
		\pan, Pwhite(-1.0, 1.0, inf),
		\note, 0!2,
		\octave, 7,
		\scale, ~scale
));
Pdef(\pinglepatt, Pbindf(Pdef(\pinglepat), \dur, 0.25, \level, ~echolevel));
Pdef(\pingleparf, Ppar([Pdef(\pinglepat), Pdef(\pinglepat)], inf));
);

/*
Pdef(\pingleparf).play(~tempo, quant: 1);
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
SynthDef(\clap, { | curve = -16, ffreq = 2000, freq = 400, level = 0.2, mfreq = 1000, mode = 0, pan = 0 |
	var env				=	Env.perc(0.005, 0.02, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var clip			=	ClipNoise.ar(envgen);
    var rlpf            =   RLPF.ar(clip, ffreq.clip(50, SampleRate.ir / 3));
    var xline           =   XLine.kr(0.125, 1, 0.01);
    var comb            =   CombN.ar(rlpf, 1, freq.reciprocal * xline, 0.01);
    var moog            =   BMoog.ar(comb, mfreq, 0.3, mode);
    var pan2			= 	Pan2.ar(moog, pan);
	Out.ar(4, pan2);
}).add;
);

(
~clapdurs = [
    0.75, 0.75, 1,
    0.75, 0.75, 0.75, 1,
    0.75, 0.75, 0.75, 0.75, 1,
		];
~claplvl = 0.03;
~clapecholvl = ~claplvl;
~filterfreqs = [1, 2, 3, 4, 6, 8, 12];
Pdef(\clappat1,
	Pbind(
		\instrument, \clap,
		\curve, 4,
        \degree, 0,
		\dur, Pseq(~clapdurs, inf),
        \ffreq, Pshuf(~filterfreqs.stutter(7) * 1000, inf),
        \level, ~claplvl,
        \mfreq, Pshuf(~filterfreqs.stutter(5) * 1000, inf),
        \mode, Prand([0, 1], inf),
		\pan, 0,
        \scale, ~scale
));
Pdef(\clappat2, Pbindf(Pdef(\clappat1), \dur, Pshuf(~clapdurs.mirror2, inf), \level, ~clapecholvl, \pan, -1));
Pdef(\clappat3, Pbindf(Pdef(\clappat2), \pan, 1));
Pdef(\clappar, Ppar([Pdef(\clappat1), Pdef(\clappat2), Pdef(\clappat3)], inf));
);

/*
Pdef(\clappar).play(~tempo, quant: 0.5);
Pdef(\clappar).isPlaying;
Pdef(\clappar).stop;
*/

(
MIDIdef.cc(\clapparktrl, {
	if(Pdef(\clappar).isPlaying.not) {
		Pdef(\clappar).play(~tempo, quant: 0.5);
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
	var env				=	Env.perc(0.005, releaseTime: 0.2, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var kxline			=	XLine.kr(1, 0.125, dur / 5);
	var sin				=	SinOscFB.ar(freq * kxline, sinfb, envgen);
	var filtfreqmod		=	LFNoise0.kr(50!2).range(1/5, 5);
	var filtrqmod		=	LFNoise0.kr(50!2).range(0.2, 0.9).round(0.1) + 0.05;
	var bn				=	LFBrownNoise1.ar(brightness, mul: envgen);
	var delay			=	DelayC.ar(sin + bn, 0.5, freq.clip(50, SampleRate.ir / 3).reciprocal, 0.5);
	var rez				=	RLPF.ar(sin + bn + delay, (brightness * kxline * filtfreqmod).clip(30, SampleRate.ir / 4), filtrqmod);
	var pan2			=	Pan2.ar(rez, pan);
	Out.ar(4, pan2);
}).add;
);

// Pattern

(
~heavypatlvl = 0.03;
~heavypatecholvl = ~heavypatlvl / 3;
Pdef(\heavypat1,
	Pbind(
		\instrument, \heavy,
		\brightness, Pshuf([1000, 4000, 8000].stutter(7), inf),
		\curve, Pshuf([-16, -4, 0, 2, 4], inf),
        \dur, Pshuf([Pseq([1/3], 3), Pseq([0.75, 0.75, 0.5, 0.5]), Pseq([0.5, 1]), Pseq([1, 1.5]), Pseq([1, 0.75, 0.75, 1])], inf),
        \level, ~heavypatlvl,
		\note, [-2, 0, 7],
		\octave, 3,
		\pan, Prand([-0.5, 0, 0.5], inf),
		\sinfb, Pshuf((0..6), inf)
));
Pdef(\heavypat2, Pbindf(Pdef(\heavypat1), \dur, Pshuf([0.25, 0.5, 0.75].stutter(17), inf), \level, ~heavypatecholvl));
Pdef(\heavypar, Ppar([Pdef(\heavypat1), Pdef(\heavypat2)], inf));
);

/*
Pdef(\heavypar).play(t, quant: 1);
Pdef(\heavypar).isPlaying;
Pdef(\heavypar).stop;
*/

// Midi Control

(
MIDIdef.cc(\heavyktrl, {
	if(Pdef(\heavypar).isPlaying.not) {
		Pdef(\heavypar).play(~tempo, quant: 1);
		"heavy prc play".postln;
	} {
		Pdef(\heavypar).pause;
		"heavy prc stop".postln;
	};
}, 67, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////////////
// KIK

(
SynthDef(\kik, { |a = 1.1, c = 0.13, curve = 0, freq = 22050, level = 0.2, pan = 0, releaseTime = 0.01|
	var env				=	Env.perc(0.003, releaseTime, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lc				=	LinCongC.ar(freq, a, c) * envgen;
	var rhpf			=	RHPF.ar(lc, (freq * 4).clip(50, SampleRate.ir / 3), 0.1);
	var pan2			=	Pan2.ar(lc + rhpf, pan);
	Out.ar(4, pan2);
}).add;
);

(
~prcpatlevel1 = 0.3;
~prcpatlevel2 = ~prcpatlevel1 / 10;
Pdef(\prcpat1,
	Pbind(
		\instrument, \kik,
		\a, Pwhite(1.200, 1.201, inf),
		\c, Pwhite(0.110, 0.111, inf),
		\curve, -64,
        \dur, Pshuf([0.5, 1, Pseq([0.75], 2)].stutter(2), inf),
		\level, ~prcpatlevel1,
		\note, Pseq([Rest, 0, Rest, Rest, 0, Rest, Rest, Rest, 0], inf),
        \octave, [7, 12],
		\scale, ~scale,
		\releaseTime, 1
));

Pdef(\prcpat2,
	Pbind(
		\instrument, \kik,
		\a, Pwhite(0.9, 1.3, inf),
		\c, Pwhite(0.11, 0.15, inf),
		\curve, -16,
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5].stutter(3), inf),
		\note, 0!2,
		\octave, 6!2,
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
		Pdef(\prcpar).play(~tempo, quant: 1);
		"prc play".postln;
	} {
		Pdef(\prcpar).stop;
		"prc stop".postln;
	};
}, 36, srcID: ~nanoktrl2.uid);
);