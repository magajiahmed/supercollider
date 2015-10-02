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

(
s.meter;
~tempo = TempoClock(120/60);
~buffer.free;
~buffer = Buffer.alloc(s, s.sampleRate * (~tempo.tempo * 6), 1);
~bassfxbus = Bus.audio(s, 2);
);


(
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 1024/729, 3/2, 14/9, 7/4];
~tuning = Tuning.new(~ratios.ratiomidi);
//~bassscale = Scale.new(#[0, 1, 2, 3], ~ratios.size, ~tuning);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
);

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////
// SINFBDRONE //////////////////////////////////////////

(
SynthDef(\sinfbdrone, { |freq = 440, gate = 1, level = 0.003|
    var env             =   Env.asr(0.1, level, 1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var freqmod         =   LFBrownNoise0.kr(0.1!2, mul: 0.001, add: 1);
    var sinfb           =   SinOscFB.ar(freq * freqmod, 0.3, envgen);
    var deci            =   Decimator.ar(sinfb, bits: 5);
    var rhpf            =   RHPF.ar(deci, 10000) * 0.2;
    Out.ar(0, sinfb + rhpf);
}).add;
);

Pdef(\sinfbdrone0, Pmono(\sinfbdrone, \degree, [7, 10], \octave, 4, \scale, ~scale));

(
Pdef(\sinfbdrone1,
    Pbind(
        \instrument, \sinfbdrone,
        \degree, Pseq([9, Rest], inf),
        \dur, Pshuf([15, 17, 19], inf),
        \legato, 1,
        \octave, 4,
        \scale, ~scale));
);

Pdef(\sinfbdronepar, Ppar([Pdef(\sinfbdrone0), Pdef(\sinfbdrone1)], inf));

Pdef(\sinfbdrone2, Pmono(\sinfbdrone, \degree, [0, 7, 10, 17], \octave, 4, \scale, ~scale));

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
Pdef(\sinfbdronepar).play(~tempo, quant: 1);
Pdef(\sinfbdronepar).isPlaying;
Pdef(\sinfbdronepar).stop;
*/

/*
Pdef(\sinfbdrone2).play(~tempo, quant: 1);
Pdef(\sinfbdrone2).isPlaying;
Pdef(\sinfbdrone2).stop;
*/

(
MIDIdef.cc(\sinfbdrone0playktrl, {
    if(Pdef(\sinfbdrone0).isPlaying.not) {
        Pdef(\sinfbdrone0).play(~tempo, quant: 1);
        "sinfbdrone0 play".postln;
    };
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\sinfbdrone0stopktrl, {
    if(Pdef(\sinfbdrone0).isPlaying) {
        Pdef(\sinfbdrone0).stop;
        "sinfbdrone0 stop".postln;
    };
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\sinfbdrone1playktrl, {
    if(Pdef(\sinfbdrone1).isPlaying.not) {
        Pdef(\sinfbdrone1).play(~tempo, quant: 1);
        "sinfbdrone1 play".postln;
    };
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\sinfbdrone1stopktrl, {
    if(Pdef(\sinfbdrone1).isPlaying) {
        Pdef(\sinfbdrone1).stop;
        "sinfbdrone1 stop".postln;
    };
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\sinfbdrone2playktrl, {
    if(Pdef(\sinfbdrone2).isPlaying.not) {
        Pdef(\sinfbdrone2).play(~tempo, quant: 1);
        "sinfbdrone2 play".postln;
    };
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\sinfbdrone2stopktrl, {
    if(Pdef(\sinfbdrone2).isPlaying) {
        Pdef(\sinfbdrone2).stop;
        "sinfbdrone2 stop".postln;
    };
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////
// BASS ////////////////////////////////////////////////

// SynthDef

(
SynthDef(\bass, { | curve = 0, dur = 1, freq = 100, fxBus = 4, level = 0.03, width = 0.5 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var klfn0			=	LFNoise1.ar(18000!2, 0.999, 1);
	var klfn1			=	LFNoise1.kr(0.1!2, 0.000, 1);
	var saw0			=	VarSaw.ar(freq, width: width, mul: envgen / 2);
	var saw1			=	VarSaw.ar(freq * klfn0 * klfn1, width: width, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var lpf				=	BLowPass4.ar(sawmix, (freq * 3).clip(50, SampleRate.ir / 2.5));
	var rhpf			=	RHPF.ar(sawmix, 3000, 0.1, mul: 1);
	var sin				=	SinOscFB.ar([freq, freq + 0.1], 0.3, mul: envgen);
	Out.ar([0, fxBus], lpf + rhpf + sin);
	//Out.ar([0, 2], saw0 + saw1);
}).add;
);

// Pattern

(
~bassdegrees = [-3, -1, 0, 1, 2, 3, 4].scramble;
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
		\fxBus, ~bassfxbus,
		\level, 0.03,
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

////////////////////////////////////////////////////////////////
// SNR /////////////////////////////////////////////////////////

// SynthDef

(
SynthDef(\snr, { | a = 1, freq = 1000, curve = -64, level = 0.08, outbus = 0, pan = 0 |
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
~snrlvl = 0.08;
~snrecholvl = ~snrlvl / 4;
Pdef(\snrpat0,
	Pbind(
		\instrument, \snr,
		\a, Pwhite(0.98, 1.02, inf),
		\curve, Pshuf([-32, -28, -24, -20, -16], inf),
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


// Midi Control

(
MIDIdef.cc(\snrsplay, {
    if(Pdef(\snrs).isPlaying.not) {
        Pdef(\snrs).play(~tempo, quant: 1);
        "snrs play".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\snrsstop, {
    if(Pdef(\snrs).isPlaying) {
        Pdef(\snrs).stop;
        "snrs stop".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

/*
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
*/

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
~hatlvl = 0.03;
~hatecholvl = ~hatlvl / 5;
Pdef(\hatpat0l,
	Pbind(
		\instrument, \hat,
        \dur, Pshuf([
			0.25, Pseq([1/6], 3), Pseq([0.25], 2), 0.5, Pseq([1/5], 5), 1, 1.5, 2, 3, 4, 6
		], inf),
		\level, Prand([0.2, 1] * ~hatlvl, inf),
        \degree, [0, 7],
        \octave, 7,
		\pan, -0.5,
        \scale, ~scale,
));

Pdef(\hatpat0r, Pbindf(Pdef(\hatpat0l), \pan, 0.5));
Pdef(\hatecho0l, Pbindf(Pdef(\hatpat0l), \level, ~hatecholvl));
Pdef(\hatecho0r, Pbindf(Pdef(\hatecho0l), \pan, 0.5));
Pdef(\hatpar0, Ppar([Pdef(\hatpat0l), Pdef(\hatpat0r), Pdef(\hatecho0l), Pdef(\hatecho0r)], inf));
);

/*
Pdef(\hatpar0).play(~tempo, quant: 1);
Pdef(\hatpar0).isPlaying;
Pdef(\hatpar0).stop;
*/

Pdef(\hatpar1, Pbindf(Pdef(\hatpar0), \octave, 8));

/*
Pdef(\hatpar1).play(~tempo, quant: 1);
Pdef(\hatpar1).isPlaying;
Pdef(\hatpar1).stop;
*/

(
Pdef(\hatpulse,
    Pbind(
        \instrument, \hat,
        \dur, 0.25,
        \level, 0.02,
        \octave, 9,
        \pan, Pshuf([-0.5, 0.5].stutter(31), inf),
));
);

/*
Pdef(\hatpulse).play(~tempo, quant: 1);
Pdef(\hatpulse).isPlaying;
Pdef(\hatpulse).stop
*/

// Midi Control

(
MIDIdef.cc(\hat0playktrl, {
    if(Pdef(\hatpar0).isPlaying.not) {
        Pdef(\hatpar0).play(~tempo, quant: 1);
        "hat0 play".postln;
    }
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\hat0stopktrl, {
    if(Pdef(\hatpar0).isPlaying) {
        Pdef(\hatpar0).stop;
        "hat0 stop".postln;
    }
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\hatpar1playktrl, {
    if(Pdef(\hatpar1).isPlaying.not) {
        Pdef(\hatpar1).play(~tempo, quant: 1);
        "hat1 play".postln;
    }
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\hatpar1stopktrl, {
    if(Pdef(\hatpar1).isPlaying) {
        Pdef(\hatpar1).stop;
        "hat1 stop".postln;
    }
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\hatpulseplayktrl, {
    if(Pdef(\hatpulse).isPlaying.not) {
        Pdef(\hatpulse).play(~tempo, quant: 1);
        "hatpulse play".postln;
    }
}, 67, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\hatpulsestopktrl, {
    if(Pdef(\hatpulse).isPlaying) {
        Pdef(\hatpulse).stop;
        "hatpulse stop".postln;
    }
}, 67, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// CRUMBLE /////////////////////////////////////////////////////

(
SynthDef(\crumble, { | a = 1, b = 1.9, bwr = 0.03, curve = -32, dur = 1, freq = 100, gate = 0.1, level = 1, outbus = 0, pan = 0 |
    var env             =   Env.asr(0.01, level, 0.1, curve);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
	var n				=	5;
	var mix				=	Mix.fill(n, {
		|i|
		var clipn			=	LFClipNoise.kr(50!2).range(0.5, 1);
		var cusp			=	CuspL.ar(a: a, b: b, mul: (envgen * clipn) / n);
		BPF.ar(cusp, (freq * (((3/2)) ** i)).clip(50, SampleRate.ir / 3), bwr, (100 / (i + 1)));
	});
    var flt				=	RLPF.ar(mix, freq * 12, 0.1) * LFBrownNoise0.kr(50!2).range(0.5, 1).round(0.5);
	Out.ar(outbus, flt);
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
        \level, 0.3,
		\octave, 6,
		\scale, ~scale,
));

Pdef(\crumble1, Pbindf(Pdef(\crumble0), \degree, Pseq([7, Rest], inf)));
Pdef(\crumble2, Pbindf(Pdef(\crumble0), \degree, Pshuf([9, Rest], inf)));
Pdef(\crumble3, Pbindf(Pdef(\crumble0), \degree, Pshuf([10, Rest], inf)));
Pdef(\crumblepar0, Ppar([Pdef(\crumble0), Pdef(\crumble1), Pdef(\crumble2), Pdef(\crumble3)], inf));

Pdef(\crumble4, Pbindf(Pdef(\crumble0), \degree, [0, 7]));
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

(
MIDIdef.cc(\crumble4playktrl, {
    if(Pdef(\crumble4).isPlaying.not) {
        Pdef(\crumble4).play(~tempo, quant: 1);
        "crumble4 play".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\crumble4stopktrl, {
    if(Pdef(\crumble4).isPlaying) {
        Pdef(\crumble4).stop;
        "crumble4 stop".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PNO /////////////////////////////////////////////////////////

(
SynthDef(\pno, { | curve = -4, dur = 1, freq = 400, gate = 1, level = 0.003, pan = 0 |
	var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	Mix.fill(4, {
		|i|
		var lfn			=	LFNoise2.kr(0.2, mul: 0.005, add: 1);
		var sin			=	SinOsc.ar((freq) * (i + 1) * lfn, pi/4, mul: envgen / (i + 1));
		sin;
	});
	var lfn				=	LFNoise1.kr(0.2, mul: 0.005, add: 1);
	var cusp			=	CuspL.ar(1000, a: lfn, mul: 0.6, add: 1);
	var sinhi			=	SinOsc.ar((freq * 9 * cusp), mul: envgen);
	var pan2			=	Pan2.ar(sin + sinhi, pan);
	Out.ar(0, pan2);
}).add;
);

(
Pdef(\pno0,
	Pbind(
		\instrument, \pno,
		\degree, [-1, 0, 5, 7],
        \dur, Pshuf([4, 5, 6] + 0.25, inf),
		\octave, 7,
		\pan, Pshuf([-0.5, -0.25, 0, 0.25, 0.5], inf),
		\scale, ~scale,
));
//Pdef(\pnos0, Ppar([Pdef(\pno0)].stutter(3), inf));
//Pdef(\pno1, Pbindf(Pdef(\pnos0), \octave, 8));
//Pdef(\pnos1, Ppar([Pdef(\pno1)].stutter(3), inf));
);

/*
Pdef(\pno0).play(~tempo, quant: 1);
Pdef(\pno0).isPlaying;
Pdef(\pno0).stop;
*/

/*
Pdef(\pnopar0).play(~tempo, quant: 1);
Pdef(\pnopar0).isPlaying;
Pdef(\pnopar0).stop;
*/

/*
Pdef(\pnopdef1).play(~tempo, quant: 1);
Pdef(\pnopdef1).isPlaying;
Pdef(\pnopdef1).stop;
*/

/*
Pdef(\pnopar1).play(~tempo, quant: 1);
Pdef(\pnopar1).isPlaying;
Pdef(\pnopar1).stop;
*/

(
MIDIdef.cc(\pno0playktrl, {
    if(Pdef(\pno0).isPlaying.not) {
        Pdef(\pno0).play(~tempo, quant: 1);
        "pno0 play".postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pno0stopktrl, {
    if(Pdef(\pno0).isPlaying) {
        Pdef(\pno0).stop;
        "pno0 stop".postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PNO2 ////////////////////////////////////////////////////////

(
SynthDef(\pno2, { | a = 1, b = 1.9, curve = -32, dur = 1, fb = 0, freq = 400, level = 0.005, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var sin				=	SinOsc.ar(freq, mul: envgen);
	var n				=	4;
	var sinmix			=	Mix.fill(n, {
		|i|
        var freqmod         =   CuspN.ar(freq, [a, a - 0.01], [b, b - 0.01], mul: 0.001 * (i + 1), add: 1);
        SinOscFB.ar([freq, freq + 0.1] * freqmod, fb, mul: envgen / n)
	});
    var lc              =   LinCongC.ar((freq!2 * 128), mul: envgen).fold2(level);
    Out.ar(0, sin + sinmix + lc);
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
		\dur, Pshuf([13, 14, 15].nthPrime, inf),
        \level, 0.008,
		\octave, 7,
		\scale, ~scale,
));
);

/*
Pdef(\pno2pat0).play(~tempo, quant: 1);
Pdef(\pno2pat0).isPlaying;
Pdef(\pno2pat0).stop;
*/

(
~pno2pat1degrees = [[-3, 0], [-1, 0], [0, 1], [0, 2], [0, 3], [0, 5]].scramble.mirror1;
~pno2pat1durs1 = [0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24].scramble.mirror1;
Pdef(\pno2pat1,
	Pbind(
		\instrument, \pno2,
        \curve, -8,
		\degree, Pseq(~pno2pat1degrees, inf),
		\dur, Pseq(~pno2pat1durs1, inf),
        \fb, 0.5,
		\octave, 6,
		\pan, 1,
		\scale, ~scale,
));
);

/*
Pdef(\pno2pat1).play(~tempo, quant: 1);
Pdef(\pno2pat1).isPlaying;
Pdef(\pno2pat1).stop;
*/

Pdef(\pno2pat2, Pbindf(Pdef(\pno2pat1), \degree, [5, 7, 10], \dur, Pshuf((5..7).nthPrime + 0.25, inf), \octave, 5));


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
// PAD /////////////////////////////////////////////////////////

// Synth

(
SynthDef(\pad, { | curve = 0, dur = 1, envtime = 8, freq = 400, gate = 1, level = 0.01 |
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
~paddurs0 = Array.fill(5, { |i| (i + 11).nthPrime });
Pdef(\padpat0,
	Pbind(
        \instrument, \pad,
        \curve, 0,
        \degree, [-1, 0, 5, 7],
		\dur, Prand(~paddurs0, inf),
        \envtime, 0.1,
		\octave, 5,
		\scale, ~scale,
));

Pdef(\paddrone, Pmono(\pad, \degree, [-1, 0, 5, 7], \octave, 4, \scale, ~scale));
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

(
MIDIdef.cc(\padpat0playktrl, {
    if(Pdef(\padpat0).isPlaying.not) {
        Pdef(\padpat0).play(~tempo, quant: 1);
        "padpat0 play".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\padpat0stopktrl, {
    if(Pdef(\padpat0).isPlaying) {
        Pdef(\padpat0).stop;
        "padpat0 stop".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\paddroneplayktrl, {
    if(Pdef(\paddrone).isPlaying.not) {
        Pdef(\paddrone).play(~tempo, quant: 1);
        "paddrone play".postln;
    }
}, 54, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\paddronestopktrl, {
    if(Pdef(\paddrone).isPlaying) {
        Pdef(\paddrone).stop;
        "paddrone stop".postln;
    }
}, 54, srcID: ~nanoktrl2.uid, argTemplate: 0);
);
