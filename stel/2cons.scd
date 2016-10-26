// init
Pdef.removeAll;
currentEnvironment.clear;

(
~tempo = TempoClock(120/60);
~buffer.free;
~buffer = Buffer.alloc(s, s.sampleRate * (~tempo.tempo * 6), 1);
);

// midi
(
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
MIDIdef.cc(\midiccpostln, { |...args| args.postln });
MIDIdef.noteOn(\midinoteonpostln, { |...args| args.postln });
~lpm = MIDIClient.sources.detect{ |s| s.name.contains("Launchpad") };
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~lpm.isNil) { ~lpm = MIDIClient.sources.detect{ |s| s.name.contains("out0") } };
~midiout = MIDIOut(0);
~midiout.connect(~lpm.uid);
);

// Turn off any lights left on previously.
(0..127).do({ |i| ~midiout.noteOn(0, i, 0) });
(0..127).do({ |i| ~midiout.control(0, i, 0) });

(
~midiktrl = { |pdef, chan|
    MIDIdef.noteOn(pdef, {
        if(Pdef(pdef).isPlaying.not) {
            ~midiout.noteOn(0, chan, 127);
            Pdef(pdef).play(~tempo);
            pdef.post;
            " play".postln;
        } {
            ~midiout.noteOn(0, chan, 0);
            Pdef(pdef).stop;
            pdef.post;
            " stop".postln;
        }
    }, chan, srcID: ~lpm.uid);
}
);

// pitch logic
(
~ratios = [1/1, 16/15, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 5/3, 7/4, 15/8];
~tuning = Tuning.new(~ratios.ratiomidi);
//~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
~scaledegrees = (0..(~ratios.size - 1));
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
);

// bus depot
~bassfxbus = Bus.audio(s, 2);
~delay = 0.05;
~delaybus = Bus.audio(s, 2);
~limiterbus = Bus.audio(s, 2);

// record
/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////
// DELAY (to compensate for limiter delay //////////////

(
SynthDef(\delay, { |delay = 1, inBus = 0, outbus = 0|
    var in              =   In.ar(inBus, 2);
    var delayc          =   DelayC.ar(in, 2, delay);
    Out.ar(outbus, delayc);
}).add;
);

(
Pdef(\delay, Pmono(\delay, \delay, ~delay, \inBus, ~delaybus, \outbus, 0));
);

////////////////////////////////////////////////////////
// LIMITER /////////////////////////////////////////////

(
SynthDef(\limiter, { |dur = 1, gate = 1, inBus, level = 1, outbus = 0|
    var env             =   Env.asr(0.01, 1, 0.01, 0);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inBus, 2);
    var limiter         =   Limiter.ar(in, level, dur);
    Out.ar(outbus, limiter);
}).add;
);

(
Pdef(\limiter, Pmono(\limiter, \dur, ~delay / 2, \inBus, ~limiterbus, \level, 0.5, \outbus, 0));
);

////////////////////////////////////////////////////////
// SINFBDRONE //////////////////////////////////////////

(
SynthDef(\sinfbdrone, { |freq = 440, gate = 1, level = 0.05, outbus|
    var env             =   Env.asr(0.1, level, 1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var freqmod         =   LFBrownNoise0.kr(0.1!2, mul: 0.001, add: 1);
    var sinfb           =   SinOscFB.ar(freq * freqmod, 0.3, envgen);
    var deci            =   Decimator.ar(sinfb, bits: 5);
    var rhpf            =   RHPF.ar(deci, 10000) * 0.2;
    Out.ar(outbus, sinfb + rhpf);
}).add;
);

Pdef(\sinfbdrone0, Pmono(\sinfbdrone, \degree, [7, 12], \octave, 4, \outbus, ~delaybus, \scale, ~scale));

(
Pdef(\sinfbdrone1,
    Pbind(
        \instrument, \sinfbdrone,
        \degree, 10,
        \dur, Pshuf([35, 37, 39], inf),
        \legato, 0.5,
        \octave, 4,
        \outbus, ~delaybus,
        \scale, ~scale));
);

//Pdef(\sinfbdronepar, Ppar([Pdef(\sinfbdrone0), Pdef(\sinfbdrone1)], inf));

Pdef(\sinfbdrone2, Pmono(\sinfbdrone, \degree, [0, 7, 12, 19], \octave, 4, \outbus, ~delaybus, \scale, ~scale));

// midi

~midiktrl.value(\sinfbdrone0, 33);
~midiktrl.value(\sinfbdrone1, 49);
~midiktrl.value(\sinfbdrone2, 65);

/*
Pdef(\sinfbdrone0).play(~tempo, quant: 1);
Pdef(\sinfbdrone0).isPlaying;
Pdef(\sinfbdrone0).stop;
*/

/*
Pdef(\sinfbdrone1).play(~tempo, quant: 1);
Pdef(\sinfbdrone1).isPlaying;
Pdef(\sinfbdrone1).stop;
*/

/*
Pdef(\sinfbdrone2).play(~tempo, quant: 1);
Pdef(\sinfbdrone2).isPlaying;
Pdef(\sinfbdrone2).stop;
*/

////////////////////////////////////////////////////////
// BASS ////////////////////////////////////////////////

// SynthDef

(
SynthDef(\bass, { |curve = 0, dur = 1, freq = 100, level = 0.3, outbus, width = 0.5|
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var saw 			=	VarSaw.ar(freq + XLine.kr([-0.01, 0.01], [-1, 1], dur), width: width).round(0.03) * envgen;
    var sin				=	SinOsc.ar(freq!2).round(0.05) * envgen;
	Out.ar(outbus, saw + sin);
}).add;
);

// Pattern

(
~bassdegrees = [-5, -2, -1, 0, 1, 2, 3].scramble;
~bassdurations = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24];
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\curve, -4,
		\degree, Pshuf([
			Pseq([~bassdegrees[0], ~bassdegrees[1], Rest]),
			Pseq([~bassdegrees[2], ~bassdegrees[3], Rest]),
			Pseq([~bassdegrees[4], ~bassdegrees[5], ~bassdegrees[6], Rest])
		], inf),
        \dur, Pshuf(~bassdurations, inf),
        \octave, 3,
        \outbus, [~delaybus, ~bassfxbus],
		\scale, ~scale,
        \width, Pshuf([0.2, 0.4, 0.5, 0.6, 0.8], inf),
));
);

/*
Pdef(\basspat).play(~tempo);
Pdef(\basspat).isPlaying;
Pdef(\basspat).stop;
*/

// Midi Control
// see below

////////////////////////////////////////////////////////
// BUFFER-STUTTER

(
SynthDef(\recbuf, { |dur = 2, gate = 1, inBus = 2, isRecording = 1, trigger = 1|
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var in				=	In.ar(inBus, ~buffer.numChannels);
	var recbuf 			=	RecordBuf.ar(in, ~buffer.bufnum, recLevel: envgen, run: isRecording, loop: 0, trigger: trigger, doneAction: 2);
}).add;
);

(
SynthDef(\bufrd, { |dur = 1, ffreq = 8000, gate = 1, outbus, pan = 0|
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(~buffer.numChannels, ~buffer.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
    var rhpf			=	RHPF.ar(bufrd, ffreq.clip(50, SampleRate.ir / 2.5), 0.1, envgen);
	var pan2			=	Pan2.ar(rhpf, pan);
	Out.ar(outbus, pan2);
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
Pdef(\rbpdef).play(~tempo, quant: 3);
Pdef(\rbpdef).isPlaying;
Pdef(\rbpdef).stop;
~buffer.plot;
*/

(
Pdef(\pbpdef,
	Pbind(
		\instrument, \bufrd,
		\dur, Pshuf([0.75, 1.5, 3, 6], inf),
        \ffreq, Prand([4000, 8000], inf),
        \outbus, ~delaybus,
		\pan, Pshuf([-1, -0.5, 0, 0.5, 1], inf)
));
);

/*
Pdef(\pbpdef).play(~tempo, quant: 1);
Pdef(\pbpdef).isPlaying;
Pdef(\pbpdef).stop;
*/

(
Pdef(\pbpar, Ppar(Array.fill(3, { Pdef(\pbpdef) })));
);

/*
Pdef(\pbpar).play(~tempo, quant: 1);
Pdef(\pbpar).isPlaying;
Pdef(\pbpar).stop;
*/

Pdef(\basswithstutter, Ppar([Pdef(\basspat), Pdef(\rbpdef), Pdef(\pbpar)], inf));

// midi

~midiktrl.value(\basswithstutter, 32);

////////////////////////////////////////////////////////////////
// SNR /////////////////////////////////////////////////////////

// SynthDef

(
SynthDef(\snr, { |a = 1, freq = 1000, curve = -64, level = 0.9, outbus = 0, pan = 0|
	var env				=	Env.perc(0.003, 0.5, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(1000, a, mul: 1.5, add: 1);
	var sin				=	SinOsc.ar((freq * cusp).clip(50, SampleRate.ir / 3), mul: envgen);
	var pan2			=	Pan2.ar(sin, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Pattern

/*
(
~snrfreq0 = 5000;
~snrfreq1 = 100;
~snrfreq2 = 15000;
~snrlvl = 0.15;
~snrecholvl = ~snrlvl / 4;
Pdef(\snrpat0,
	Pbind(
		\instrument, \snr,
		\a, Pwhite(0.98, 1.02, inf),
		\curve, Prand([-32, -16], inf),
		\freq, ~snrfreq0,
		/*
		\dur, Pshuf([
			0.75, 0.75, 1.25,
			0.75, 0.75, 0.75, 1.25,
			0.75, 0.75, 0.75, 0.75, 1.25
        ], inf),
		*/
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3], inf),
		\note, Pshuf([
            Rest, Rest, Rest, Rest, Rest, Rest, Rest, 0,
            Rest, Rest, Rest, Rest, Rest, Rest, Rest, Rest, 0,
            Rest, Rest, Rest, Rest, Rest, Rest, Rest, Rest, Rest, 0
        ], inf),
        \level, ~snrlvl,
        \octave, 6,
        \outbus, ~limiterbus,
        \scale, ~scale
));

Pdef(\snrpat1, Pbindf(Pdef(\snrpat0), \level, ~snrecholvl, \pan, -1));

Pdef(\snrpat2, Pbindf(Pdef(\snrpat1), \pan, 1));

//

Pdef(\snrpat3, Pbindf(Pdef(\snrpat0), \curve, -8, \freq, ~snrfreq1));

Pdef(\snrpat4, Pbindf(Pdef(\snrpat3), \level, ~snrecholvl, \pan, -1));

Pdef(\snrpat5, Pbindf(Pdef(\snrpat4), \pan, 1));

//

Pdef(\snrpat6, Pbindf(Pdef(\snrpat0), \freq, ~snrfreq2));

Pdef(\snrpat7, Pbindf(Pdef(\snrpat6), \level, ~snrecholvl, \pan, -1));

Pdef(\snrpat8, Pbindf(Pdef(\snrpat7), \pan, 1));

//

Pdef(\snrpar0,
    Ppar([
        Pdef(\snrpat0), Pdef(\snrpat1), Pdef(\snrpat2),
        Pdef(\snrpat3), Pdef(\snrpat4), Pdef(\snrpat5),
        Pdef(\snrpat3), Pdef(\snrpat4), Pdef(\snrpat5)
], inf));

Pdef(\snrpar2, Ppar([Pdef(\snrpat6), Pdef(\snrpat7), Pdef(\snrpat8)]));

Pdef(\snrs, Ppar([Pdef(\snrpar0), Pdef(\snrpar2), Pdef(\snrpar2)]));
);
*/

//

(
~snrlvl = 0.8;
~snrecholvl = ~snrlvl / 4;

Pdef(\snr1,
    Pbind(
        \instrument, \snr,
        \a, Pwhite(0.98, 1.02, inf),
        \curve, Pshuf([-16, -8], inf),
        \dur, Pshuf([0.25, Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, 1, 1.5, 2, 3, 4, 6], inf),
        \freq, Pshuf([100, 500, 1000, 5000].stutter(3), inf),
        \level, ~snrlvl,
        \outbus, ~limiterbus
));

Pdef(\snr2, Pbindf(Pdef(\snr1), \level, ~snrecholvl));

Pdef(\snrs, Ppar([Pdef(\snr1), Pdef(\snr2)]));
);

/*
Pdef(\snr1).play(~tempo);
Pdef(\snr1).isPlaying;
Pdef(\snr1).stop;
*/

/*
Pdef(\snr2).play(~tempo);
Pdef(\snr2).isPlaying;
Pdef(\snr2).stop;
*/

// Midi Control

~midiktrl.value(\snrs, 34);

////////////////////////////////////////////////////////////////
// HAT /////////////////////////////////////////////////////////

// SynthDef

(
SynthDef(\hat, { |curve = -64, freq = 1000, level = 0.3, numharm = 14, outbus, pan = 0, releaseTime = 0.4|
	var env				=	Env.perc(0.004, releaseTime, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var imp				=	Blip.ar(freq, numharm, envgen);
	var rlpf			=	RLPF.ar(imp, 8000, 0.03);
	var pan2			=	Pan2.ar(rlpf, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Pattern

(
/*
~hat0shortdurs = (8..3).collect({ |d| Pseq([d.reciprocal], d) });
~hat0longdurs = [0.5, 1, 1.5, 2, 3, 4, 6];
//~hat0durs = ~hat0shortdurs ++ ~hat0longdurs;
~hat0durs = ~hat0shortdurs;
//~hatlvl = 0.002;
//~hatecholvl = ~hatlvl / 4;
*/

Pdef(\hatgrains,
	Pbind(
		\instrument, \hat,
        //\curve, Pshuf([-4, -16, -64].stutter(17), inf),
        \curve, Pbrown(-64, -8, -1, inf),
        \dur, 16.reciprocal,
        \degree, Pseq([Pseq([[7, 10, 12]], 601), Pseq([Rest], 601)], inf),
        \level, 0.1,
        \numharm, Pshuf([Pseq([1], 100.rand.round(1) + 100), Pseq([2], 100.rand.round(1) + 100), Pseq([3], 100.rand.round(1) + 100)].stutter(3), inf),
        \octave, 7,
        \outbus, ~limiterbus,
        \pan, Prand([-1, 0, 1], inf),
        \releaseTime, Pbrown(0.2, 1.0, 0.1, inf),
        \scale, ~scale,
));

Pdef(\hatgrainsdrone,
    Pbind(
        \instrument, \hat,
        \curve, -4,
        \degree, Pseq([Pseq([[7, 12]], 503), Pseq([Rest], 503)], inf),
        \dur, 16.reciprocal,
        \level, 0.03,
        \numharm, 0,
        \octave, 6,
        \outbus, ~limiterbus,
        \pan, Prand([-1, 0, 1], inf),
        \releaseTime, 0.2,
        \scale, ~scale
));

);

/*
Pdef(\hatgrains).play(~tempo);
Pdef(\hatgrains).isPlaying;
Pdef(\hatgrains).stop;
*/

/*
Pdef(\hatgrainsdrone).play(~tempo);
Pdef(\hatgrains).isPlaying;
Pdef(\hatgrains).stop;
*/

(
Pdef(\hatpat1,
    Pbind(
        \instrument, \hat,
        \degree, Pseq([Pseq([[7, 12]], 71), Pseq([Rest], 71)], inf),
        \dur, 0.25,
        \octave, 7,
        \outbus, ~limiterbus,
        \pan, Pshuf([-1, -0.5, 0.5, 1].stutter(29), inf),
        \scale, ~scale,
));
);
/*
Pdef(\hatpat1).play(~tempo);
Pdef(\hatpat1).isPlaying;
Pdef(\hatpat1).stop;
*/

(
Pdef(\hatpulse,
    Pbind(
        \instrument, \hat,
        \degree, Pseq([Pseq([0], 101), Pseq([Rest], 101)], inf),
        \dur, 0.25,
        \octave, 9,
        \outbus, ~limiterbus,
        \pan, Pshuf([-1, -0.5, 0.5, 1].stutter(31), inf),
));
);

/*
Pdef(\hatpulse).play(~tempo, quant: 1);
Pdef(\hatpulse).isPlaying;
Pdef(\hatpulse).stop
*/

// Midi Control

~midiktrl.value(\hatgrains, 50);
~midiktrl.value(\hatgrainsdrone, 66);
~midiktrl.value(\hatpat1, 51);
~midiktrl.value(\hatpulse, 67);

////////////////////////////////////////////////////////////////
// CRUMBLE /////////////////////////////////////////////////////

(
SynthDef(\crumble, { |a = 1, b = 1.9, bwr = 0.03, curve = -4, dur = 1, freq = 100, gate = 0.1, level = 0.5, outbus, pan = 0|
    var env             =   Env.asr(0.1, level, 0.1, curve);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
	var n				=	5;
	var mix				=	Mix.fill(n, {
		|i|
		var clipn			=	LFClipNoise.kr(50!2).range(0.5, 1);
		var cusp			=	CuspL.ar(a: a, b: b, mul: clipn / n);
		BPF.ar(cusp, (freq * (((3/2)) ** i)).clip(50, SampleRate.ir / 3), bwr, (100 / (i + 1)));
	});
    var flt				=	RLPF.ar(mix, (freq * 12).clip(50, SampleRate.ir / 2.5), 0.1, envgen) * LFBrownNoise0.kr(50!2).range(0.5, 1).round(0.5);
    Out.ar(outbus, flt.fold2(level));
}).add;
);

// Patterns

(
Pdef(\crumble0,
	Pbind(
		\instrument, \crumble,
		\a, Pshuf([0.8, 0.85, 0.9], inf),
		//\b, Pbrown(1.6, 1.9, 0.05, inf),
		\bwr, 0.01,
		\curve, 0,
        \degree, Pseq([5, Rest], inf),
        \dur, Pshuf([23, 29, 31], inf),
		\legato, 0.75,
        \level, 0.8,
		\octave, 6,
        \outbus, ~delaybus,
		\scale, ~scale,
));

Pdef(\crumble1, Pbindf(Pdef(\crumble0), \degree, Pseq([7, Rest], inf)));
Pdef(\crumble2, Pbindf(Pdef(\crumble0), \degree, Pshuf([10, Rest], inf)));
Pdef(\crumble3, Pbindf(Pdef(\crumble0), \degree, Pshuf([12, Rest], inf)));
Pdef(\crumblepar0, Ppar([Pdef(\crumble0), Pdef(\crumble1), Pdef(\crumble2), Pdef(\crumble3)], inf));

Pdef(\crumble4, Pbindf(Pdef(\crumble0), \degree, 0));
);

/*
Pdef(\crumble0).play(~tempo, quant: 1);
Pdef(\crumble0).isPlaying;
Pdef(\crumble0).stop;
*/

/*
Pdef(\crumble1).play(~tempo, quant: 1);
Pdef(\crumble1).isPlaying;
Pdef(\crumble1).stop;
*/

/*
Pdef(\crumble2).play(~tempo, quant: 1);
Pdef(\crumble2).isPlaying;
Pdef(\crumble2).stop;
*/

/*
Pdef(\crumble3).play(~tempo, quant: 1);
Pdef(\crumble3).isPlaying;
Pdef(\crumble3).stop;
*/

/*
Pdef(\crumblepar0).play(~tempo, quant: 1);
Pdef(\crumblepar0).isPlaying;
Pdef(\crumblepar0).stop;
*/

/*
Pdef(\crumble4).play(~tempo, quant: 1);
Pdef(\crumble4).isPlaying;
Pdef(\crumble4).stop;
*/

// Midi Control

~midiktrl.value(\crumblepar0, 52);
~midiktrl.value(\crumble4, 68);

////////////////////////////////////////////////////////////////
// PNO2 ////////////////////////////////////////////////////////

(
SynthDef(\pno2, { |a = 1, b = 1.9, curve = -32, dur = 1, fb = 0, fbmod_freq = 50, fbmod_mul = 0, freq = 400, level = 0.1, outbus, pan = 0|
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var fbmod           =   CuspN.ar(fbmod_freq, [a, a - 0.1], [b, b - 0.1]).range(1, fbmod_mul).round(fbmod_mul);
	var sin				=	SinOscFB.ar(freq!2, fb * fbmod, envgen);
	Out.ar(outbus, sin);
}).add;
);

// Pattern

(
Pdef(\pno2pat0,
	Pbind(
		\instrument, \pno2,
        \a, Pwhite(1.0, 1.99, inf).round(0.1),
        \b, Pwhite(1.8, 2.0, inf).round(0.1),
        \curve, -16,
        \degree, 0,
        \fb, 0,
        \fbmod_freq, 0,
        \fbmod_mul, 0,
		\dur, Pshuf([11, 12, 13].nthPrime, inf),
        \level, 0.1,
        \octave, 7,
        \outbus, ~delaybus,
		\scale, ~scale,
));
);

/*
Pdef(\pno2pat0).play(~tempo, quant: 1);
Pdef(\pno2pat0).isPlaying;
Pdef(\pno2pat0).stop;
*/

(
~pno2pat1durs1 = [0.5, 0.75, 1, 1.5, 2, 3, 32, 48].scramble.mirror1;
Pdef(\pno2pat1,
	Pbind(
		\instrument, \pno2,
        \a, Pwhite(1.0, 1.99, inf).round(0.1),
        \b, Pwhite(1.8, 2.0, inf).round(0.1),
        \curve, -16,
        \degree, [7, 10, 12],
		\dur, Pseq(~pno2pat1durs1, inf),
        \fb, 0.01,
        \fbmod_freq, 100,
        \fbmod_mul, 50,
		\octave, 6,
        \outbus, ~delaybus,
		\scale, ~scale,
));
);

/*
Pdef(\pno2pat1).play(~tempo, quant: 1);
Pdef(\pno2pat1).isPlaying;
Pdef(\pno2pat1).stop;
*/

// Midi Control

~midiktrl.value(\pno2pat0, 37);
~midiktrl.value(\pno2pat1, 53);

////////////////////////////////////////////////////////////////
// PAD /////////////////////////////////////////////////////////

// Synth

(
SynthDef(\pad, { |curve = 0, dur = 1, envtime = 8, freq = 400, gate = 1, level = 0.1, outbus|
	var env				=	Env.asr(envtime, level, envtime, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var n				=	2;
	var mix				=	Mix.fill(n, {
		arg i;
		var klfn		=	LFBrownNoise0.kr(1.dup, mul: 0.0005, add: 1);
		var freqgap		= 	200;
       	var kbnenv		=	LFBrownNoise0.kr(13!4).range(0.3, 1).round(0.7);
        var saw0		=	LFSaw.ar([freq, freq + (i / freqgap)] * klfn, mul: envgen / (i + 1)) * kbnenv[0, 1];
        var saw1		=	LFSaw.ar([freq, freq + (i / freqgap)], mul: envgen / n) * kbnenv[2, 3];
        (saw0 + saw1);
	});
	var lor				=	Lorenz2DC.ar(mul: 0.5, add: 1);
	var sin				=	SinOsc.ar(6000 * lor, mul: envgen / 6);
	var sinmix			=	mix + sin;
	var lpf				=	BLowPass4.ar(sinmix, freq * 1.5);
    var rhpf			=	BHiPass4.ar(sinmix, (freq * 32).clip(50, SampleRate.ir / 3), 0.5, 0.5);
	var filtmix			=	lpf + rhpf;
	var striated		=	filtmix;
	Out.ar(outbus, striated);
}).add;
);

// Pattern

(
~paddurs0 = Array.fill(5, { |i| (i + 11).nthPrime });
Pdef(\padpat0,
	Pbind(
        \instrument, \pad,
        \curve, 0,
        \degree, [-2, 0, 5, 7],
		\dur, Prand(~paddurs0, inf),
        \envtime, 0.1,
		\octave, 5,
        \outbus, ~delaybus,
		\scale, ~scale,
));

Pdef(\paddrone, Pmono(\pad, \degree, [-2, 0, 5, 7], \octave, 4, \outbus, ~delaybus, \scale, ~scale));
);

/*
Pdef(\padpat0).play(~tempo, quant: 1);
Pdef(\padpat0).isPlaying;
Pdef(\padpat0).stop;
*/

/*
Pdef(\paddrone).play(~tempo, quant: 1);
Pdef(\paddrone).isPlaying;
Pdef(\paddrone).stop;
*/

// Midi Control

~midiktrl.value(\padpat0, 38);
~midiktrl.value(\paddrone, 54);

////////////////////////////////
// "Scene" Control
// A set of patterns to be triggered together. Their being triggered causes certain other patterns to turn off.
(
~scene1 = [Pdef(\sinfbdrone1), Pdef(\hatgrains), Pdef(\hatgrainsdrone)];
~scene1lights = [49, 50, 66];
~scene2 = [Pdef(\sinfbdrone2), Pdef(\basswithstutter), Pdef(\hatpat1), Pdef(\hatpulse), Pdef(\snrs), Pdef(\crumblepar0), Pdef(\crumble4)];
~scene2lights = [65, 32, 51, 67, 34, 52, 68];

MIDIdef.cc(\scene1, {
    ~midiout.control(0, 105, 0);
    ~midiout.control(0, 104, 127);
    ~scene1lights.do({ |m| ~midiout.noteOn(0, m, 127) });
    ~scene1.do({ |p| p.play(~tempo) });
    ~scene2lights.do({ |m| ~midiout.noteOn(0, m, 0) });
    ~scene2.do({ |p| p.stop });
}, 104, srcID: ~lpm.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\scene2, {
    ~midiout.control(0, 104, 0);
    ~midiout.control(0, 105, 127);
    ~scene2lights.do({ |m| ~midiout.noteOn(0, m, 127) });
    ~scene2.do({ |p| p.play(~tempo) });
    ~scene1lights.do({ |m| ~midiout.noteOn(0, m, 0) });
    ~scene1.do({ |p| p.stop });
}, 105, srcID: ~lpm.uid, argTemplate: { |x| x > 0 });
);

////////////////////////////////
// start up the effects
{
    s.sync;
    Pdef(\limiter).play(t);
    Pdef(\delay).play(t);
}.fork;