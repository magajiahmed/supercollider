Pdef.removeAll;

(
//midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
MIDIdef.cc(\midiccpostln, { |...args| args.postln });
~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("nanoKONTROL2")};
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~nanoktrl2.isNil) { ~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
);

s.meter;
~tempo = TempoClock(120/60);
~buffer = Buffer.alloc(s, s.sampleRate * (~tempo.tempo * 6), 1);

(
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 14/9, 7/4];
~tuning = Tuning.new(~ratios.ratiomidi);
~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
);

////////////////////////////////////////////////////////
// BASS ////////////////////////////////////////////////

// SynthDef

(
SynthDef(\bass, { | curve = 0, dur = 1, freq = 100, level = 0.05, width = 0.5 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var klfn0			=	LFNoise1.ar(18000, 0.999, 1);
	var klfn1			=	LFNoise1.kr(0.1, 0.0005, 1);
	var saw0			=	VarSaw.ar([freq, freq + 0.1], width: width, mul: envgen / 2);
	var saw1			=	VarSaw.ar([freq, freq + 0.1] * klfn0 * klfn1, width: width, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var lpf				=	BLowPass4.ar(sawmix, freq * 3);
	var rhpf			=	RHPF.ar(sawmix, 3000, 0.1, mul: 1);
	var sin				=	SinOsc.ar([freq, freq + 0.1], mul: envgen);
	Out.ar([0, 2], lpf + rhpf + sin);
	//Out.ar([0, 2], saw0 + saw1);
}).add;
);

// Pattern

(
~durations = [0.5, 0.75, 8, 12, 16, 24, 32, 48];
Pdef(\basspat,
	Pbind(
		\instrument, \bass,
		\curve, -4,
		\degree, Prand([-1, 0, 1, 2, 3], inf),
		\dur, Pwrand(~durations, ~durations.reverse.normalizeSum, inf),
		\level, 0.1,
		\octave, 3,
		\scale, ~scale,
		\width, Pwhite(0.1, 0.9, inf),
));
);

/*
Pdef(\basspat).play(~tempo, quant: 1);
Pdef(\basspat).isPlaying;
Pdef(\basspat).stop;
*/

// Midi Control

(
MIDIdef.cc(\bassplayktrl, {
    if(Pdef(\basspat).isPlaying.not) {
		Pdef(\basspat).play(~tempo, quant: 1);
		"bass play".postln;
	};
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\bassstopktrl, {
	if(Pdef(\basspat).isPlaying) {
		Pdef(\basspat).stop;
		"bass stop".postln;
	};
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0);
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
SynthDef(\bufrd, { | dur = 1, ffreq = 1000, gate = 1, pan = 0 |
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(~buffer.numChannels, ~buffer.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var rhpf			=	RHPF.ar(bufrd, ffreq, 0.1, envgen);
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
Pdef(\rbpdef).play(~tempo, quant: 3);
Pdef(\rbpdef).isPlaying;
Pdef(\rbpdef).stop;
~buffer.plot;
*/

(
Pdef(\pbpdef,
	Pbind(
		\instrument, \bufrd,
		\dur, Prand([0.75, 1.5, 3, 6], inf),
		\pan, Prand([-1, -0.5, 0, 0.5, 1], inf)
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

// Midi Control

(
MIDIdef.cc(\rbplayktrl, {
	if(Pdef(\rbpdef).isPlaying.not) {
		Pdef(\rbpdef).play(~tempo, quant: 3);
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

//

(
MIDIdef.cc(\pbplayktrl, {
	if(Pdef(\pbpar).isPlaying.not) {
		Pdef(\pbpar).play(~tempo, quant: 1);
		"playbuf play".postln;
	};
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pbstopktrl, {
	if(Pdef(\pbpar).isPlaying) {
		Pdef(\pbpar).stop;
		"playbuf stop".postln;
	};
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////
// PERC ////////////////////////////////////////////////

// SynthDef

(
SynthDef(\prc, { | curve = -64, dur = 1, freq = 1000, level = 0.08, pan = 0 |
	var env				= 	Env.perc(attackTime: 0.005, releaseTime: dur / 3, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var bn				=	LFBrownNoise0.ar(freq, mul: envgen);
	var n				=	24;
	var resonzmix		=	Mix.fill(n, {
		var kbn			=	LFBrownNoise1.kr(0.1, mul: 0.4, add: 1);
		Resonz.ar(bn, freq * kbn, 0.001, 150 / n);
	});
	var pan2			=	Pan2.ar(resonzmix, pan);
	Out.ar(0, pan2);
}).add;
);

// Pattern

(
Pdef(\prcpat0l,
	Pbind(
		\instrument, \prc,
		\curve, -16,
		\dur, Pshuf([Pseq([0.25/3], 3), Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].mirror2, inf),
		\freq, 15000,
		\pan, -0.5,
)));

(
Pdef(\prcpat0r,
	Pbindf(Pdef(\prcpat0l), \pan, 0.5));
);

Pdef(\prcpar0, Ppar([Pdef(\prcpat0l), Pdef(\prcpat0r)], inf));

/*
Pdef(\prcpar0).play(~tempo, quant: 1);
Pdef(\prcpar0).isPlaying;
Pdef(\prcpar0).stop;
*/

(
Pdef(\prcpat1l,
	Pbindf(
		Pdef(\prcpat0l),
		\curve, -64,
		\dur, Pshuf([
			1, 1, 1.5,
			1, 1, 1, 1.5,
			1, 1, 1, 1, 1.5
		] / 2, inf),
		\freq, 7500,
		\pan, -1,
)));

(
Pdef(\prcpat1r,
    Pbindf(Pdef(\prcpat1l), \pan, 1));
);

Pdef(\prcpar1, Ppar([Pdef(\prcpat1l), Pdef(\prcpat1r)], inf));

/*
Pdef(\prcpar)1.play(~tempo, quant: 1);
Pdef(\prcpar)1.isPlaying;
Pdef(\prcpar)1.stop;
*/

(
Pdef(\prcpulse,
	Pbind(
		\instrument, \prc,
		\dur, Pseq([
			1, 1, 1.5,
			1, 1, 1, 1.5,
			1, 1, 1, 1, 1.5
		], inf),
		\freq, 6000,
		\level, 0.05,
));
);

/*
Pdef(\prcpulse).play(~tempo, quant: 1);
Pdef(\prcpulse).isPlaying;
Pdef(\prcpulse).stop;
*/

// Midi Control

(
MIDIdef.cc(\prc0playktrl, {
	if(Pdef(\prcpar0).isPlaying.not) {
		Pdef(\prcpar0).play(~tempo, quant: 1);
		"prc0 play".postln;
	};
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc0stopktrl, {
	if(Pdef(\prcpar0).isPlaying) {
		Pdef(\prcpar0).stop;
		"prc0 stop".postln;
	};
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prc1playktrl, {
    if(Pdef(\prcpar1).isPlaying.not) {
        Pdef(\prcpar1).play(~tempo, quant: 1);
        "prc1 play".postln;
    };
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc1stopktrl, {
    if(Pdef(\prcpar1).isPlaying) {
        Pdef(\prcpar1).stop;
        "prc1 stop".postln;
    };
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prcpulseplayktrl, {
    if(Pdef(\prcpulse).isPlaying.not) {
        Pdef(\prcpulse).play(~tempo, quant: 1);
        "prcpulse play".postln;
    };
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prcpulsestopktrl, {
    if(Pdef(\prcpulse).isPlaying) {
        Pdef(\prcpulse).stop;
        "prcpulse stop".postln;
    };
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// SNR /////////////////////////////////////////////////////////

// SynthDef

(
SynthDef(\snr, { | a = 1, freq = 1000, curve = -64, level = 0.05, outbus = 0, pan = 0 |
	var env				=	Env.perc(0.003, 0.5, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(1000, a, mul: 1.5, add: 1);
	var sin				=	SinOsc.ar((freq * cusp).clip(50, SampleRate.ir / 3), mul: envgen);
	var pan2			=	Pan2.ar(sin, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Pattern

(
~snrfreq0 = 5000;
~snrfreq1 = 100;
~snrfreq2 = 15000;
~snrfreq3 = 3000;
~snrecholvl = 0.005;
Pdef(\snrpat0,
	Pbind(
		\instrument, \snr,
		\a, Pwhite(0.99, 1.01, inf),
		\curve, -24,
		\freq, ~snrfreq0,
		\dur, Pseq([
			1, 1, 1.5,
			1, 1, 1, 1.5,
			1, 1, 1, 1, 1.25, 0.25,], inf),
		\note, Pseq([Rest, 1, Rest], inf),
));

/*
Pdef(\snrpat0).play(~tempo, quant: 1);
Pdef(\snrpat0).isPlaying;
Pdef(\snrpat0).stop;
*/

Pdef(\snrpat1,
	Pbindf(
        Pdef(\snrpat0),
		\dur, Pseq([
			0.75, 0.75, 1.25,
			0.75, 0.75, 0.75, 1.25,
			0.75, 0.75, 0.75, 0.75, 1.25
		], inf),
		\level, ~snrecholvl,
		\note, Pseq([Rest, 1, Rest], inf),
		\pan, -1,
));

/*
Pdef(\snrpat1).play(~tempo, quant: 1);
Pdef(\snrpat1).isPlaying;
Pdef(\snrpat1).stop;
*/

Pdef(\snrpat2,
	Pbindf(
        Pdef(\snrpat0),
		\dur, Pseq([
			1.25, 1.25, 1.75,
			1.25, 1.25, 1.25, 1.25, 1.75,
			1.25, 1.25, 1.25, 1.25, 1.25, 1.75
		], inf),
		\level, ~snrecholvl,
		\note, Pseq([Rest, 1], inf),
		\pan, 1,
));

/*
Pdef(\snrpat2).play(~tempo, quant: 1);
Pdef(\snrpat2).isPlaying;
Pdef(\snrpat2).stop;
*/

////////////////

Pdef(\snrpat3,
	Pbindf(
        Pdef(\snrpat0),
		\curve, -8,
		\freq, ~snrfreq1,
		\dur, Prand([0.5, 0.75, 1], inf),
		\note, Pseq([Rest, 1], inf),
));

/*
Pdef(\snrpat3).play(~tempo, quant: 1);
Pdef(\snrpat3).isPlaying;
Pdef(\snrpat3).stop;
*/

Pdef(\snrpat4,
	Pbindf(
        Pdef(\snrpat3),
		\level, ~snrecholvl,
));

/*
Pdef(\snrpat4).play(~tempo, quant: 1);
Pdef(\snrpat4).isPlaying;
Pdef(\snrpat4).stop;
*/

Pdef(\snrpat5,
	Pbindf(
		Pdef(\snrpat3),
		\level, ~snrecholvl,
));

/*
Pdef(\snrpat5).play(~tempo, quant: 1);
Pdef(\snrpat5).isPlaying;
Pdef(\snrpat5).stop;
*/

////////////////

Pdef(\snrpat6,
	Pbindf(
		Pdef(\snrpat0),
		\dur, Prand([0.5, 0.75, 1], inf),
		\freq, ~snrfreq2,
));

/*
Pdef(\snrpat6).play(~tempo, quant: 1);
Pdef(\snrpat6).isPlaying;
Pdef(\snrpat6).stop;
*/

Pdef(\snrpat7,
	Pbindf(
		Pdef(\snrpat6),
		\level, ~snrecholvl,
));

/*
Pdef(\snrpat7).play(~tempo, quant: 1);
Pdef(\snrpat7).isPlaying;
Pdef(\snrpat7).stop;
*/

Pdef(\snrpat8,
	Pbindf(
		Pdef(\snrpat6),
		\level, ~snrecholvl,
));

/*
Pdef(\snrpat8).play(~tempo, quant: 1);
Pdef(\snrpat8).isPlaying;
Pdef(\snrpat8).stop;
*/

//////////////////////

Pdef(\snrpat9,
	Pbindf(
		Pdef(\snrpat0),
		\curve, -16,
		\dur, Prand([0.5, 0.75, 1], inf),
		\freq, ~snrfreq3,
		\note, Pseq([Rest, 1, Rest, Rest, 1, Rest, Rest, Rest, 1], inf),
));

/*
Pdef(\snrpat9).play(~tempo, quant: 1);
Pdef(\snrpat9).isPlaying;
Pdef(\snrpat9).stop;
*/

Pdef(\snrpat10,
	Pbindf(
		Pdef(\snrpat9),
		\level, ~snrecholvl,
));

Pdef(\snrpat11,
	Pbindf(
		Pdef(\snrpat9),
		\level, ~snrecholvl,
));
);

////////////////

Pdef(\snrpar0, Ppar([Pdef(\snrpat0), Pdef(\snrpat1), Pdef(\snrpat2), Pdef(\snrpat3), Pdef(\snrpat4), Pdef(\snrpat5),
    Pdef(\snrpat3), Pdef(\snrpat4), Pdef(\snrpat5)], inf));

/*
Pdef(\snrpar0).play(~tempo, quant: 1);
Pdef(\snrpar0).isPlaying;
Pdef(\snrpar0).stop;
*/

Pdef(\snrpar1, Ppar([Pdef(\snrpat3), Pdef(\snrpat4), Pdef(\snrpat5)].stutter(2)));

/*
Pdef(\snrpar1).play(~tempo, quant: 1);
Pdef(\snrpar1).isPlaying;
Pdef(\snrpar1).stop;
*/

Pdef(\snrpar2, Ppar([Pdef(\snrpat6), Pdef(\snrpat7), Pdef(\snrpat8)]));

/*
Pdef(\snrpar2).play(~tempo, quant: 1);
Pdef(\snrpar2).isPlaying;
Pdef(\snrpar2).stop;
*/

Pdef(\snrpar3, Ppar([Pdef(\snrpat9), Pdef(\snrpat10), Pdef(\snrpat11)].stutter(2)));

/*
Pdef(\snrpar3).play(~tempo, quant: 1);
Pdef(\snrpar3).isPlaying;
Pdef(\snrpar3).stop;
*/

// Midi Control

(
MIDIdef.cc(\snrpar0playktrl, {
    if(Pdef(\snrpar0).isPlaying.not) {
        Pdef(\snrpar0).play(~tempo, quant: 1);
        "snr0 play".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\snrpar0stopktrl, {
    if(Pdef(\snrpar0).isPlaying) {
        Pdef(\snrpar0).stop;
        "snr0 stop".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\snrpar2playktrl, {
    if(Pdef(\snrpar2).isPlaying.not) {
        Pdef(\snrpar2).play(~tempo, quant: 1);
        "snr2 play".postln;
    };
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\snrpar2stopktrl, {
    if(Pdef(\snrpar2).isPlaying) {
        Pdef(\snrpar2).stop;
        "snr2 stop".postln;
    };
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\snrpar3playktrl, {
    if(Pdef(\snrpar3).isPlaying.not) {
        Pdef(\snrpar3).play(~tempo, quant: 1);
        "snr3 play".postln;
    };
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\snrpar3stopktrl, {
    if(Pdef(\snrpar3).isPlaying) {
        Pdef(\snrpar3).stop;
        "snr3 stop".postln;
    };
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// HAT /////////////////////////////////////////////////////////

// SynthDef

(
SynthDef(\hat, { | freq = 1000, level = 0.1, outbus = 0, pan = 0 |
	var env				=	Env.perc(0.004, 0.4, level, -64);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var imp				=	Blip.ar(freq, 14, envgen);
	var rlpf			=	RLPF.ar(imp, 8000, 0.03);
	var pan2			=	Pan2.ar(rlpf, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Pattern

(
Pdef(\hatpatl,
	Pbind(
		\instrument, \hat,
		\dur, Pwrand([Pseq([0.25/3], 3), 0.5, 0.75], [1, 8, 8].normalizeSum, inf),
		\level, Prand([0.2, 1] * 0.08, inf),
        \degree, [0, 7],
        \octave, 8,
		\pan, -0.5,
        \scale, ~scale,
));
);

(
Pdef(\hatpatr,
	Pbindf(
        Pdef(\hatpatl),
		\pan, 0.5
));
);

Pdef(\hatpar, Ppar([Pdef(\hatpatl), Pdef(\hatpatr)], inf));

/*
Pdef(\hatpar).play(~tempo, quant: 1);
Pdef(\hatpar).isPlaying;
Pdef(\hatpar).stop;
*/

(
Pdef(\hatpulse,
	Pbind(
		\instrument, \hat,
		\dur, 0.25,
		\level, 0.03,
        \octave, 9,
		\pan, Prand([-1, -0.5, 0.5, 1], inf),
));
);

/*
Pdef(\hatpulse).play(~tempo, quant: 1);
Pdef(\hatpulse).isPlaying;
Pdef(\hatpulse).stop
*/

// Midi Control

(
MIDIdef.cc(\hatplayktrl, {
    if(Pdef(\hatpar).isPlaying.not) {
        Pdef(\hatpar).play(~tempo, quant: 1);
        "hat play".postln;
    }
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\hatstopktrl, {
    if(Pdef(\hatpar).isPlaying) {
        Pdef(\hatpar).stop;
        "hat stop".postln;
    }
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\hatpulseplayktrl, {
    if(Pdef(\hatpulse).isPlaying.not) {
        Pdef(\hatpulse).play(~tempo, quant: 1);
        "hatpulse play".postln;
    }
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\hatpulsestopktrl, {
    if(Pdef(\hatpulse).isPlaying) {
        Pdef(\hatpulse).stop;
        "hatpulse stop".postln;
    }
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// CRUMBLE /////////////////////////////////////////////////////

(
SynthDef(\crumble, { | a = 1, b = 1.9, bwr = 0.03, curve = -32, dur = 1, freq = 100, gate = 1, level = 1, outbus = 0, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var n				=	8;
	var mix				=	Mix.fill(n, {
		arg i;
		var clipnfreq		=	4;
		var clipn			=	LFClipNoise.kr(clipnfreq).range(0.5, 1);
		var cusp			=	CuspL.ar(a: a, b: b, mul: (envgen * clipn) / n);
		BPF.ar(cusp, (freq * (((3/2)) ** i)).clip(50, SampleRate.ir / 3), bwr, (100 / (i + 1).pow(2)));
	});
	var flt				=	RLPF.ar(mix, freq * 12, 0.1);
	var pan2			=	Pan2.ar(flt, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Patterns

(
Pdef(\crumblepdef0,
	Pbind(
		\instrument, \crumble,
		\a, Pbrown(0.8, 1, 0.05, inf),
		\b, Pbrown(1.6, 1.9, 0.05, inf),
		\bwr, Pbrown(0.0001, 0.01, 0.0001, inf),
		\curve, -32,
		\degree, 0,
		\dur, Prand([0.5, 0.75], inf),
		\level, Prand([0.2, 1] * 0.2, inf),
		\octave, 7,
		\pan, Prand([-0.5, 0, 0.5], inf),
		\scale, ~scale,
));
);

/*
Pdef(\crumblepdef0).play(~tempo, quant: 1);
Pdef(\crumblepdef0).isPlaying;
Pdef(\crumblepdef0).stop;
*/

(
Pdef(\crumblepdef1,
	Pbindf(
		Pdef(\crumblepdef0),
		\degree, -1,
));
);

/*
Pdef(\crumblepdef1).play(~tempo, quant: 1);
Pdef(\crumblepdef1).isPlaying;
Pdef(\crumblepdef1).stop;
*/

(
Pdef(\crumblepdef2,
	Pbindf(
		Pdef(\crumblepdef0),
		\degree, 7,
));
);

/*
Pdef(\crumblepdef2).play(~tempo, quant: 1);
Pdef(\crumblepdef2).isPlaying;
Pdef(\crumblepdef2).stop;
*/

////

Pdef(\crumblepar0, Ppar([Pdef(\crumblepdef0), Pdef(\crumblepdef1), Pdef(\crumblepdef2)], inf));

/*
Pdef(\crumblepar0).play(~tempo, quant: 1);
Pdef(\crumblepar0).isPlaying;
Pdef(\crumblepar0).stop;
*/

// Midi Control

(
MIDIdef.cc(\crumbleplayktrl, {
    if(Pdef(\crumblepar0).isPlaying.not) {
        Pdef(\crumblepar0).play(~tempo, quant: 1);
        "crumble play".postln;
    }
}, 36, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\crumblestopktrl, {
    if(Pdef(\crumblepar0).isPlaying) {
        Pdef(\crumblepar0).stop;
        "crumble stop".postln;
    }
}, 36, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PNO /////////////////////////////////////////////////////////

(
SynthDef(\pno, { | curve = -8, dur = 1, freq = 400, gate = 1, level = 0.002, pan = 0 |
	var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	Mix.fill(4, {
		|i|
		var lfn			=	LFNoise1.kr(0.1, mul: 0.01, add: 1);
		var sin			=	SinOsc.ar((freq) * (i + 1) * lfn, pi/4, mul: envgen / (i + 1));
		sin;
	});
	var lfn				=	LFNoise1.kr(0.1, mul: 0.02, add: 1);
	var cusp			=	CuspL.ar(1000, a: lfn, mul: 0.6, add: 1);
	var sinhi			=	SinOsc.ar((freq * 9 * cusp).clip(50, SampleRate.ir / 3), mul: envgen);
	var pan2			=	Pan2.ar(sin + sinhi, pan);
	Out.ar(0, pan2);
}).add;
);

(
Pdef(\pnopdef0,
	Pbind(
		\instrument, \pno,
        \degree, [0, 5],
		\dur, Prand([0.25, 0.5], inf),
		\level, 0.002,
		\octave, 8,
		\pan, Prand([-1, 0, 1], inf),
		\scale, ~scale,
));
);

/*
Pdef(\pnopdef0).play(~tempo, quant: 1);
Pdef(\pnopdef0).isPlaying;
Pdef(\pnopdef0).stop;
*/

Pdef(\pnopar0, Ppar(Array.fill(4, { Pdef(\pnopdef0) })));

/*
Pdef(\pnopar0).play(~tempo, quant: 1);
Pdef(\pnopar0).isPlaying;
Pdef(\pnopar0).stop;
*/

(
Pdef(\pnopdef1,
	Pbindf(
		Pdef(\pnopdef0),
		\degree, [-1, -3],
		\level, 0.0005,
));
);

Pdef(\pnopar1, Ppar(Array.fill(4, { Pdef(\pnopdef1) })));

/*
Pdef(\pnopar1).play(~tempo, quant: 1);
Pdef(\pnopar1).isPlaying;
Pdef(\pnopar1).stop;
*/

(
MIDIdef.cc(\pnopar0playktrl, {
    if(Pdef(\pnopar0).isPlaying.not) {
        Pdef(\pnopar0).play(~tempo, quant: 1);
        "pno0 play".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnopar0stopktrl, {
    if(Pdef(\pnopar0).isPlaying) {
        Pdef(\pnopar0).stop;
        "pno0 stop".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pnopar1playktrl, {
    if(Pdef(\pnopar1).isPlaying.not) {
        Pdef(\pnopar1).play(~tempo, quant: 1);
        "pno1 play".postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnopar1stopktrl, {
    if(Pdef(\pnopar1).isPlaying) {
        Pdef(\pnopar1).stop;
        "pno1 stop".postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0);
);


////////////////////////////////////////////////////////////////
// PNO2 ////////////////////////////////////////////////////////

(
SynthDef(\pno2, { | a = 1, b = 1.9, curve = -32, dur = 1, fb = 0, freq = 400, level = 0.003, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	SinOsc.ar(freq, mul: envgen);
	var n				=	5;
	var sinmix			=	Mix.fill(n, {
		|i|
        var freqmod         =   CuspN.ar(freq, [a, a - 0.01], [b, b - 0.01], mul: 0.02 * i, add: 1);
        SinOscFB.ar([freq, freq + 0.1] * freqmod, fb, mul: envgen / (i + 1))
	});
    var crackle         =   Crackle.ar(1.5!2, mul: envgen);
	Out.ar(0, sin + sinmix + crackle);
}).add;
);

// Pattern

(
Pdef(\pno2pat0,
	Pbind(
		\instrument, \pno2,
        \a, Pwhite(1.0, 1.99, inf).round(0.1),
        \b, Pwhite(1.8, 2.0, inf).round(0.1),
		\degree, 0,
		\dur, Pshuf([9, 10, 11].nthPrime, inf),
		\octave, 6,
		\scale, ~scale,
));
);

/*
Pdef(\pno2pat0).play(~tempo, quant: 1);
Pdef(\pno2pat0).isPlaying;
Pdef(\pno2pat0).stop;
*/

(
~pno2pat1degrees = [[-1, 0], [0, 1], [0, 2], [0, 3]].scramble.mirror1;
~pno2pat1durs1 = [0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24].scramble.mirror1;
Pdef(\pno2pat1,
	Pbind(
		\instrument, \pno2,
		\curve, 0,
		\degree, Pseq(~pno2pat1degrees, inf),
		\dur, Pseq(~pno2pat1durs1, inf),
        \fb, Pshuf((3..7) / 4, inf),
		\octave, 7,
		\pan, 1,
		\scale, ~scale,
));
);

/*
Pdef(\pno2pat1).play(~tempo, quant: 1);
Pdef(\pno2pat1).isPlaying;
Pdef(\pno2pat1).stop;
*/

(
~pno2pat2durs = [0.5, 0.75, 1, 1.5, 2, 3, 4, 6.25].scramble.mirror1;
Pdef(\pno2pat2, Pbindf(Pdef(\pno2pat1), \degree, [5, 7, 10], \dur, Pseq(~pno2pat2durs, inf), \octave, 6));
);

/*
Pdef(\pno2pat2).play(~tempo, quant: 1);
Pdef(\pno2pat2).isPlaying;
Pdef(\pno2pat2).stop;
*/

// Midi Control

(
MIDIdef.cc(\pno2playktrl, {
    if(Pdef(\pno2pat0).isPlaying.not) {
        Pdef(\pno2pat0).play(~tempo, quant: 1);
        "pno2pat0 play".postln;
    };
}, 37, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pno2stopktrl, {
    if(Pdef(\pno2pat0).isPlaying) {
        Pdef(\pno2pat0).stop;
        "pno2pat0 stop".postln;
    };
}, 37, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pno2pat1playktrl, {
    if(Pdef(\pno2pat1).isPlaying.not) {
        Pdef(\pno2pat1).play(~tempo, quant: 1);
        "pno2pat1 play".postln;
    };
}, 53, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pno2pat1stopktrl, {
    if(Pdef(\pno2pat1).isPlaying) {
        Pdef(\pno2pat1).stop;
        "pno2pat1 stop".postln;
    };
}, 53, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pno2pat2playktrl, {
    if(Pdef(\pno2pat2).isPlaying.not) {
        Pdef(\pno2pat2).play(~tempo, quant: 1);
        "pno2pat2 play".postln;
    };
}, 69, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pno2pat2stopktrl, {
    if(Pdef(\pno2pat2).isPlaying) {
        Pdef(\pno2pat2).stop;
        "pno2pat2 stop".postln;
    };
}, 69, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// DRONE ///////////////////////////////////////////////////////

(
SynthDef(\drone, { | curve = 0, dur = 1, freq = 400, gate = 1, level = 0.008 |
	var env				=	Env.asr(0.1, level, 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var kbn				=	LFBrownNoise0.kr(15!4, mul: 0.8, add: 1).round(0.2);
	var n				=	4;
	var mix				= 	Mix.fill(n, {
		|i|
		var freqmod			=	LFNoise0.kr(freq!2, 0.001, 1);
		SinOsc.ar((freq * (i + 1)) * freqmod, mul: envgen / (i + 1).pow(5));
	});
	var lor				=	Lorenz2DC.ar(s: [9.9, 10], mul: 0.8!2, add: 1);
	var sinhi			=	SinOsc.ar((4000 * lor).clip(50, SampleRate.ir / 3), mul: envgen / 6);
	var foldfactor		=	2;
	Out.ar(0, ((mix).fold2(level / foldfactor) * foldfactor * kbn[0,1]) + (sinhi * kbn[2,3]));
}).add;
);

(
Pdef(\dronepat0,
	Pbind(
		\instrument, \drone,
		\degree, [-1, 0],
		\dur, Pseq([13, 14, 15].nthPrime + 0.25, inf),
		\legato, 0.5,
		\octave, 6,
		\scale, ~scale
));
Pdef(\dronepat1, Pbindf(Pdef(\dronepat0), \degree, [0, 5], \dur, Pseq([14, 15, 16].nthPrime + 0.25, inf)));
Pdef(\dronepat2, Pbindf(Pdef(\dronepat0), \degree, [0, 7], \dur, Pseq([15, 16, 17].nthPrime + 0.25, inf)));
);

/*
Pdef(\dronepat0).play(~tempo, quant: 1);
Pdef(\dronepat0).isPlaying;
Pdef(\dronepat0).stop;
*/

/*
Pdef(\dronepat1).play(~tempo, quant: 1);
Pdef(\dronepat1).isPlaying;
Pdef(\dronepat1).stop;
*/

/*
Pdef(\dronepat2).play(~tempo, quant: 1);
Pdef(\dronepat2).isPlaying;
Pdef(\dronepat2).stop;
*/

// Midi Control

// (
// MIDIdef.cc(\drone0ktrl, {
//     if(Pdef(\dronepat0).isPlaying.not) {
//         Pdef(\dronepat0).play(~tempo, quant: 0.25);
//         "drone0 play".postln;
//     } {
//         Pdef(\dronepat0).stop;
//         "drone0 stop".postln;
//     };
// }, 38, srcID: ~nanoktrl2.uid);
// );

(
MIDIdef.cc(\dronepat0playktrl, {
    if(Pdef(\dronepat0).isPlaying.not) {
        Pdef(\dronepat0).play(~tempo, quant: 1);
        "drone0 play".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\dronepat0stopktrl, {
    if(Pdef(\dronepat0).isPlaying) {
        Pdef(\dronepat0).stop;
        "drone0 stop".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\dronepat1playktrl, {
    if(Pdef(\dronepat1).isPlaying.not) {
        Pdef(\dronepat1).play(~tempo, quant: 1);
        "drone1 play".postln;
    }
}, 54, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\dronepat1stopktrl, {
    if(Pdef(\dronepat1).isPlaying) {
        Pdef(\dronepat1).stop;
        "drone1 stop".postln;
    }
}, 54, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\dronepat2playktrl, {
    if(Pdef(\dronepat2).isPlaying.not) {
        Pdef(\dronepat2).play(~tempo, quant: 1);
        "drone2 play".postln;
    }
}, 70, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\dronepat2stopktrl, {
    if(Pdef(\dronepat2).isPlaying) {
        Pdef(\dronepat2).stop;
        "drone2 stop".postln;
    }
}, 70, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PAD /////////////////////////////////////////////////////////

// Synth

(
SynthDef(\pad, { | curve = 0, dur = 1, envtime = 8, freq = 400, gate = 1, level = 0.008 |
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
	Out.ar(0, striated);
}).add;
);

// Pattern


(
~padchords0 = Array.fill(~scale.size, { |i| [0, i, 7, i + 7] });
~paddurs0 = Array.fill(5, { |i| (i + 7).nthPrime });
Pdef(\padpat0,
	Pbind(
		\instrument, \pad,
        \curve, -4,
		\degree, Pshuf(~padchords0 ++ [Rest].stutter(6), inf),
		\dur, Prand(~paddurs0, inf),
        \envtime, 0.5,
		\octave, 5,
		\scale, ~scale,
));
);

/*
Pdef(\padpat0).play(~tempo, quant: 1);
Pdef(\padpat0).isPlaying;
Pdef(\padpat0).stop;
*/


(
Pdef(\paddrone,
	Pmono(
		\pad,
		\degree, [-1, 0, 5, 7],
		\octave, 4,
		\scale, ~scale,
));
);

/*
Pdef(\paddrone).play(~tempo, quant: 1);
Pdef(\paddrone).isPlaying;
Pdef(\paddrone).stop;
*/

Pdef(\padpar, Ppar([Pdef(\padpat0), Pdef(\paddrone)], inf));

/*
Pdef(\padpar).play(~tempo, quant: 1);
Pdef(\padpar).isPlaying;
Pdef(\padpar).stop;
*/

// Midi Control

(
MIDIdef.cc(\padpat0playktrl, {
    if(Pdef(\padpat0).isPlaying.not) {
        Pdef(\padpat0).play(~tempo, quant: 1);
        "padpat0 play".postln;
    }
}, 39, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\padpat0stopktrl, {
    if(Pdef(\padpat0).isPlaying) {
        Pdef(\padpat0).stop;
        "padpat0 stop".postln;
    }
}, 39, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

// (
// MIDIdef.cc(\paddronektrl, {
//     if(Pdef(\paddrone).isPlaying.not) {
//         Pdef(\paddrone).play(~tempo, quant: 1);
//         "paddrone play".postln;
//     } {
//         Pdef(\paddrone).stop;
//         "paddrone stop".postln;
//     };
// }, 55, srcID: ~nanoktrl2.uid);
// );

(
MIDIdef.cc(\paddroneplayktrl, {
    if(Pdef(\paddrone).isPlaying.not) {
        Pdef(\paddrone).play(~tempo, quant: 1);
        "paddrone play".postln;
    }
}, 55, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\paddronestopktrl, {
    if(Pdef(\paddrone).isPlaying) {
        Pdef(\paddrone).stop;
        "paddrone stop".postln;
    }
}, 55, srcID: ~nanoktrl2.uid, argTemplate: 0);
);