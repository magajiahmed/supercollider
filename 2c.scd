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
SynthDef(\bass, { arg a = 1, dur = 1, freq = 100, level = 0.05;
 	var env				=	Env.perc(releaseTime: dur, level: level, curve: -2);
 	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin1			=	SinOsc.ar(freq);
	var sinmix			=	Mix.fill(3, {
		|i|
		var freqmod			=	LFNoise1.kr(1!2, 0.002, 1);
		var sin				=	SinOsc.ar(freq * (i + 1) * freqmod);
		sin / 2.pow(i);
	});
	var oscs			=	(sin1 + sinmix);
	var foldfactor		=	3;
	var distoscs		=	oscs.fold2(level / foldfactor) * foldfactor * 2;
	//var lat				=	Latoocarfian2DC.ar(a: [a, a - 0.01], mul: 0.5, add: 1);
	//var sin2			=	SinOsc.ar(freq * lat, mul: 100, add: 1);
	//var sin3			=	SinOsc.ar(freq * freqmod[6, 7], sin2, mul: envgen);
	//var rlpf 			=	RLPF.ar(sin2, freq * 2);
	//var rhpf			=	RHPF.ar(distoscs * envgen, 2000, 0.2);
	Out.ar([0, 1, 2, 3], (oscs * envgen) + (distoscs * envgen));
}).add;
);


// Pattern

(
~bassdurations = [0.25, 0.5, 0.75];
~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\note, Pseq([-1, 0, 0, 0, 0, 0], inf),
		\dur, Pshuf([0.25, 0.5, 0.75].stutter(7), inf),
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
SynthDef(\bufrd, { | delaytime = 0.01, dur = 1, filt_freq = 3000, filt_rq = 1, gate = 1, pan = 0 |
	var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(b.numChannels, b.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var delay			=	DelayC.ar(bufrd, 0.2, delaytime.clip(0.00001, 0.2));
	var rhpf			=	RHPF.ar(bufrd + delaytime, filt_freq, filt_rq, envgen * kbn1 * 2);
	var pan2			=	Pan2.ar(rhpf, pan);
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
~pbpat =
Pdef(\pbpat,
	Pbind(
		\instrument, \bufrd,
		\delaytime, Pwhite(0.00001, 0.01, inf),
		\dur, Prand([0.25, 0.5, 0.75, 1, 1.5], inf),
		\filt_freq, Pwhite(2000, 4000, inf),
		\f_rq, Pwhite(0.1, 1, inf),
		\pan, Prand([-0.5, 0, 0.5], inf)
));
);

/*
~pbpat.play(t, quant: 1.5);
~pbpat.isPlaying;
~pbpat.pause;
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
	if(~pbpat.isPlaying.not) {
		~pbpat.play(t, quant: 1);
		"playbuf play".postln;
	} {
		~pbpat.pause;
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
// PRC2B

(
SynthDef(\prc2b, { | curve = -8, dur = 1, freq = 1000, level = 0.15, pan = 0 |
	var env				=	Env.perc(0.005, releaseTime: 0.5, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var kxline			=	XLine.kr(1, 0.1, dur / 5);
	var sin				=	SinOsc.ar([100, 110] * kxline, 0.2, envgen);
	var kbn				=	LFBrownNoise0.kr(20).range(0.2, 5);
	var bn				=	LFBrownNoise1.ar(freq, mul: envgen);
	var rez				=	RLPF.ar(bn, (freq * kxline * kbn).clip(30, SampleRate.ir / 4), 0.5);
	var delay			=	DelayC.ar(sin + rez, 0.1, 50.reciprocal, 0.5);
	var pan2			=	Pan2.ar(rez + delay, pan);
	Out.ar(4, pan2);
}).add;
);

// Pattern

(
~prc2bpatdurarr = Array.fill(4, { arg i; (i + 1) / 4 });
~prc2bpat1 =
Pdef(\prc2bpat1,
	Pbind(
		\instrument, \prc2b,
		\curve, -4,
		\dur, Pshuf([Pseq([0.75, 0.75, 0.5, 0.5]), Pseq([0.5, 1, 1]), Pseq([1], 3)], inf),
		\freq, Pshuf([1000, 4000, 6000, 8000].stutter(3), inf),
		\pan, Prand([-0.5, 0, 0.5], inf)
));
);

/*
~prc2bpat1.play(t, quant: 1);
~prc2bpat1.isPlaying;
~prc2bpat1.pause;
*/

// Midi Control

(
~prc2bktrl = MIDIdef.cc(\prc2bktrl, {
	if(~prc2bpat1.isPlaying.not) {
		~prc2bpat1.play(t, quant: 1);
		"prc2b play".postln;
	} {
		~prc2bpat1.pause;
		"prc2b stop".postln;
	};
}, 34, srcID: ~nanoktrl2);
);

////////////////////////////////////////////////////////////////
// PRC2C

(
SynthDef(\prc2c, { | curve = -16, freq = 400, level = 0.5, pan = 0 |
	var env				=	Env.perc(0.005, 1, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var clip			=	ClipNoise.ar(envgen);
	var xline			=	XLine.kr(1, 0.2, 0.2);
	var stan			=	Standard2DC.ar.clip(0.1, 1);
	var rez				=	Resonz.ar(clip, freq * xline, stan);
	var pan2			= 	Pan2.ar(rez, pan);
	Out.ar(4, pan2);
}).add;
);

(
~prc2cpatdurs = [
			0.75, 0.75, 1,
			0.75, 0.75, 0.75, 1,
			0.75, 0.75, 0.75, 0.75, 1
		];
~prc2cpat1 =
Pdef(\prc2cpat1,
	Pbind(
		\instrument, \prc2c,
		//\curve, Prand([-16, -24, -32, -48], inf),
		\curve, -8,
		//\dur, Prand([0.25, 0.5, 0.75], inf),
		\dur, Pseq(~prc2cpatdurs, inf),
		//\freq, Pxrand([100, 120, 130, 500, 520, 530, 1000, 1200, 1300], inf),
		// \freq, Pseq([
		// 	1000, 1500, 1000,
		// 	1000, 1500, 1000, 1500,
		// 	1000, 1500, 1000, 1500, 1000
		// ], inf),
		\freq, Pshuf([530, 1000, 1200, 1500], inf),
		\pan, 0,
));
~prc2cpat2 = Pdef(\prc2cpat2, Pbindf(~prc2cpat1, \dur, Pshuf(~prc2cpatdurs.mirror2, inf), \level, 0.25, \pan, -1));
~prc2cpat3 = Pdef(\prc2cpat3, Pbindf(~prc2cpat2, \pan, 1));
~prc2cpar = Pdef(\prc2cpar, Ppar([~prc2cpat1, ~prc2cpat2, ~prc2cpat3], inf));
);

/*
~prc2cpar.play(t, quant: 1);
~prc2cpar.isPlaying;
~prc2cpar.pause;
*/

(
~prc2cktrl = MIDIdef.cc(\prc2cktrl, {
	if(~prc2cpar.isPlaying.not) {
		~prc2cpar.play(t, quant: 1);
		"prc2c play".postln;
	} {
		~prc2cpar.pause;
		"prc2c stop".postln;
	};
}, 50, srcID: ~nanoktrl2);
);
