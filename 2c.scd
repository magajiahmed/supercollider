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
~nanoktrl2 = 1310720;
//~nanoktrl2 = 1835008;
//~nanoktrl2 = 1572864;
);

(
s.meter;
t = TempoClock(108/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);
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
~bassdurations = [0.25, 0.5, 0.75];
//~bassrepeats = 17;
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\foldfactor, Pshuf(Array.series(11, 1.0, 0.2), inf),
		\note, Pseq([
			Prand([-2, 0, 0, 0], 23), Pxrand([-1, 1], 9)
		], inf),
		\dur, Pshuf(~bassdurations.stutter(7), inf),
		\octave, 3,
		\scale, ~scale,
));
);

/*
~basspat.play(t, quant: 1);
~basspat.isPlaying;
~basspat.pause;
*/

// Midi Control

(
~bassktrl = MIDIdef.cc(\bassktrl, {
	if(~basspat.isPlaying.not) {
		~basspat.play(t, quant: 1);
		"bass play".postln;
	} {
		~basspat.pause;
		"bass stop".postln;
	};
}, 32, srcID: ~nanoktrl2);
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
SynthDef(\bufrd, { | amp = 1, curve = -4, dur = 1, filt_freq = 3000, filt_rq = 1, freq = 440, gate = 1, pan = 0 |
	var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.005, amp, 0.005, curve);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(b.numChannels, b.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var rhpf			=	RHPF.ar(bufrd, filt_freq, filt_rq, envgen * kbn1 * 2);
	var delay			=	DelayC.ar(rhpf, 0.2, (freq.reciprocal).clip(50, SampleRate.ir / 3));
	var pan2			=	Pan2.ar(rhpf + delay, pan);
	Out.ar(0, pan2);
}).add;
);

(
~rbpdef =
Pdef(\rbpdef,
	Pbind(
		\instrument, \recbuf,
		\dur, 6,
));
);

/*
~rbpdef.play(t, quant: 3);
~rbpdef.isPlaying;
~rbpdef.pause;
b.plot;
*/

(
~pbpat1 =
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
~pbpat2 = Pdef(\pbpat2, Pbindf(~pbpat1, \amp, 0.2, \pan, -1));
~pbpat3 = Pdef(\pbpat3, Pbindf(~pbpat2, \pan, 1));
~pbpar = Pdef(\pbpar, Ppar([~pbpat1, ~pbpat2, ~pbpat3], inf));
);

/*
~pbpar.play(t, quant: 1.5);
~pbpar.isPlaying;
~pbpar.pause;
*/

// Midi Control

(
~rbktrl = MIDIdef.cc(\rbktrl, {
	if(~rbpdef.isPlaying.not) {
		~rbpdef.play(t, quant: 3);
		"recbuf play".postln;
	} {
		~rbpdef.pause;
		"recbuf stop".postln;
	};
}, 48, srcID: ~nanoktrl2);
);

(
~pbktrl = MIDIdef.cc(\pbktrl, {
	if(~pbpar.isPlaying.not) {
		~pbpar.play(t, quant: 1);
		"playbuf play".postln;
	} {
		~pbpar.pause;
		"playbuf stop".postln;
	};
}, 64, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PULSE

(
SynthDef(\pulse, { | bits = 24, curve = -128, dur = 1, freq = 400, level = 0.05, pan = 0 |
	var env				=	Env.new([0, level, 0], [0.01, dur]);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var xline			=	XLine.ar(0.999, 0.001, dur);
	var lfn				=	LFBrownNoise0.ar(freq).range(0.2, 5);
	var sinfb			=	SinOscFB.ar(freq, xline * lfn, envgen);
	var pan2			=	Pan2.ar(sinfb, pan);
	Out.ar(4, pan2);
}).add;
);

//

(
~pulsedurarray = [Pseq([0.25], 53), Pseq([0.25], 31), Pseq([1/3], 3), Pseq([0.75], 4), Pseq([2/5], 5)];
~pulsepat1 =
Pdef(\pulsepat1,
	Pbind(
		\instrument, \pulse,
		\bits, Pbrown(8, 16, 1, inf).round(1),
		\dur, Pshuf(~pulsedurarray, inf),
		//\level, Pshuf([1, 0.5].stutter(5) * 0.01, inf),
		\note, 0,
		\pan, Pshuf([-0.5, 0, 0.5].stutter(3), inf),
		\scale, ~scale
));
~pulsepat2 = Pdef(\pulsepat2, Pbindf(~pulsepat1, \note, 2));
~pulsepat3 = Pdef(\pulsepat3, Pbindf(~pulsepat1, \note, 3));
);

/*
~pulsepat1.play(t, quant: 1);
~pulsepat1.isPlaying;
~pulsepat1.pause;
*/

/*
~pulsepat2.play(t, quant: 1);
~pulsepat2.isPlaying;
~pulsepat2.pause;
*/

/*
~pulsepat3.play(t, quant: 1);
~pulsepat3.isPlaying;
~pulsepat3.pause;
*/

//

(
~pulsektrl1 = MIDIdef.cc(\pulsektrl1, {
	if(~pulsepat1.isPlaying.not) {
		~pulsepat1.play(t, quant: 1);
		"pulse1 play".postln;
	} {
		~pulsepat1.pause;
		"pulse1 stop".postln;
	};
}, 33, srcID: ~nanoktrl2);
);

(
~pulsektrl2 = MIDIdef.cc(\pulsektrl2, {
	if(~pulsepat2.isPlaying.not) {
		~pulsepat2.play(t, quant: 1);
		"pulse2 play".postln;
	} {
		~pulsepat2.pause;
		"pulse2 stop".postln;
	};
}, 49, srcID: ~nanoktrl2);
);

(
~pulsektrl3 = MIDIdef.cc(\pulsektrl3, {
	if(~pulsepat3.isPlaying.not) {
		~pulsepat3.play(t, quant: 1);
		"pulse3 play".postln;
	} {
		~pulsepat3.pause;
		"pulse3 stop".postln;
	};
}, 65, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PINGLE

(
SynthDef(\pingle, { | a = 0.02, curve = -16, foldfactor = 2, freq = 10000, level = 0.3, pan = 0 |
	var env				=	Env.perc(releaseTime: 1, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq * 4, a, 3, add: 1);
	var sin				=	SinOsc.ar(freq * (cusp));
	var sinwrap			=	sin.fold2(foldfactor.reciprocal).softclip * foldfactor * envgen;
	var rez				=	Resonz.ar(sinwrap, 6000, 0.1);
	var pan2			=	Pan2.ar(rez, pan);
	Out.ar(4, pan2).softclip;
}).add;
);

// Pattern

(
~mainlevel = 0.3;
~echolevel = ~mainlevel / 5;
~foldseries = Array.series(13, 5, 5);

~pinglepat1 =
Pdef(\pinglepat1,
	Pbind(
		\instrument, \pingle,
		\a, 0.01,
		\curve, -16,
		\dur, Pshuf([
			Pseq([0.75], 7),
			Pseq([1], 7),
			Pseq([1.25], 7),
		], inf),
		\foldfactor, Pshuf(~foldseries, inf),
		\note, Pwrand([0, Rest], [4, 1].normalizeSum, inf),
		//\note, 0,
		\level, ~mainlevel,
		\octave, 7,
		\scale, ~scale,
));
~pinglepat1a = Pdef(\pinglepat1a, Pbindf(~pinglepat1, \dur, Pshuf([0.25, 0.5].stutter(7), inf), \level, ~echolevel, \pan, -1));
~pinglepat1b = Pdef(\pinglepat1b, Pbindf(~pinglepat1a, \pan, 1));
~pinglepat2 = Pdef(\pinglepat2, Pbindf(~pinglepat1, \note, 0, \octave, 8));
~pinglepat2a = Pdef(\pinglepat2a, Pbindf(~pinglepat2, \dur, Pshuf([0.25, 0.5].stutter(7), inf), \level, ~echolevel, \pan, -1));
~pinglepat2b = Pdef(\pinglepat2b, Pbindf(~pinglepat2a, \pan, 1));
(
~pinglepar =
Pdef(\pinglepar,
	Ppar(
		[~pinglepat1, ~pinglepat1a, ~pinglepat1b]
		 ++
		[~pinglepat2, ~pinglepat2a, ~pinglepat2b]
		, inf));
);
);

/*
~pinglepar.play(t, quant: 1);
~pinglepar.isPlaying;
~pinglepar.pause;
*/

(
~pinglepat =
Pdef(\pinglepat,
	Pbind(
		\instrument, \pingle,
		\dur, Prand([0.25, 0.5, 0.75], inf),
		\foldfactor, Pwhite(1.0, 10.0, inf),
		//\level, Pwrand([0.2, 1] * 0.5, [4, 1].normalizeSum, inf),
		\pan, Prand([-1, 0, 1], inf),
		\note, 0,
		\octave, 7,
		\scale, ~scale
));
~pingleparf = Pdef(\pingleparf, Ppar(~pinglepat!3, inf));
);

/*
~pingleparf.play(t, quant: 1);
~pinglepat.isPlaying;
~pingleparf.pause;
*/

////////////////////////////////////////////////////////////////
// CLAP

(
SynthDef(\clap, { | curve = -16, freq = 400, level = 0.2, pan = 0, xlinestart = 1, xlineend = 0.2 |
	var env				=	Env.perc(0.005, 1, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var clip			=	ClipNoise.ar(envgen);
	var xline			=	XLine.kr(xlinestart, xlineend, 0.2);
	var stan			=	Standard2DC.ar.clip(0.1, 1);
	var rez				=	Resonz.ar(clip, (freq * xline).clip(50, SampleRate.ir / 3), stan);
	var pan2			= 	Pan2.ar(rez, pan);
	Out.ar(4, pan2);
}).add;
);

(
~clapdurs = [
			0.75, 0.75, 1,
			0.75, 0.75, 0.75, 1,
			0.75, 0.75, 0.75, 0.75, 1
		];
~clappat1 =
Pdef(\clappat1,
	Pbind(
		\instrument, \clap,
		\curve, -8,
		\dur, Pseq(~clapdurs, inf),
		\freq, Pshuf([530, 1000, 1200, 1500], inf),
		\pan, 0,
		\xlinestart, Pshuf([7/8, 1, 256/243, 9/8, 7/6], inf),
		\xlineend, Pwhite(0.05, 0.5, inf)
));
~clappat2 = Pdef(\clappat2, Pbindf(~clappat1, \dur, Pshuf(~clapdurs.mirror2, inf), \level, 0.25, \pan, -1));
~clappat3 = Pdef(\clappat3, Pbindf(~clappat2, \pan, 1));
~clappar = Pdef(\clappar, Ppar([~clappat1, ~clappat2, ~clappat3], inf));
);

/*
~clappar.play(t, quant: 0.5);
~clappar.isPlaying;
~clappar.pause;
*/

(
~clapparktrl = MIDIdef.cc(\clapparktrl, {
	if(~clappar.isPlaying.not) {
		~clappar.play(t, quant: 0.5);
		"clap play".postln;
	} {
		~clappar.pause;
		"clap stop".postln;
	};
}, 50, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// HEAVY PERC

(
SynthDef(\heavy, { | brightness = 1000, curve = -8, dur = 1, freq = 440, level = 0.03, pan = 0, sinfb = 0 |
	var env				=	Env.perc(0.005, releaseTime: 0.5, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var kxline			=	XLine.kr(1, 0.125, dur / 5);
	var sin				=	SinOscFB.ar(freq * kxline, sinfb, envgen);
	var filtfreqmod		=	LFNoise0.kr(30!2).range(1/5, 5);
	var filtrqmod		=	LFNoise0.kr(30!2).range(0.2, 1.0);
	var bn				=	LFBrownNoise1.ar(brightness, mul: envgen);
	var delay			=	DelayC.ar(sin + bn, 0.5, freq.clip(50, SampleRate.ir / 3).reciprocal, 0.5);
	var rez				=	RLPF.ar(sin + bn + delay, (brightness * kxline * filtfreqmod).clip(30, SampleRate.ir / 4), filtrqmod);
	var pan2			=	Pan2.ar(rez, pan);
	Out.ar(4, pan2);
}).add;
);

// Pattern

(
~heavypat1 =
Pdef(\heavypat1,
	Pbind(
		\instrument, \heavy,
		\brightness, Pshuf([1000, 4000, 8000].stutter(7), inf),
		\curve, -4,
		\dur, Pshuf([Pseq([0.75, 0.75, 0.5, 0.5]), Pseq([0.5, 1]), Pseq([1, 1.5]), Pseq([1, 0.75, 0.75, 1])].stutter(3), inf),
		\note, [-2, 0, 7],
		\octave, 3,
		\pan, Prand([-0.5, 0, 0.5], inf),
		\sinfb, Pshuf((0..6), inf)
));
);

/*
~heavypat1.play(t, quant: 1);
~heavypat1.isPlaying;
~heavypat1.pause;
*/

// Midi Control

(
~heavypat1ktrl = MIDIdef.cc(\heavypat1ktrl, {
	if(~heavypat1.isPlaying.not) {
		~heavypat1.play(t, quant: 1);
		"heavy prc play".postln;
	} {
		~heavypat1.pause;
		"heavy prc stop".postln;
	};
}, 66, srcID: ~nanoktrl2);
);