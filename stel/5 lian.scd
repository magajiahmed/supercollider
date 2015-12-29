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
t = TempoClock(132/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);
);

(
// Bus depot
~bassfxbus = Bus.audio(s, 2);
~prcfxbus = Bus.audio(s, 2);
// Pitch logic
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 1024/729, 3/2, 14/9, 12/7, 7/4, 243/128];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
~chord = [-2, 0, 2, 7];
~chords = [[-5, 2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]];
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
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.001, slopeAbove: 1/2); // compressor
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
// BASS ////////////////////////////////////////////////

// SynthDef

(
SynthDef(\bass, { | curve = -4, dur = 1, fb = 0, foldfactor = 3, ffend = 1, ffnoizamt = 1, ffstart = 1, freq = 100, level = 0.01, start = 1 |
    var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
 	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var fenv            =   XLine.kr(start, 1, dur / 4);
    var sin             =   SinOscFB.ar((freq - 0.1) * fenv, 0.3, envgen * 6);
    var sinfb      		=	SinOscFB.ar([freq, freq + 0.1] * fenv, fb);
    var ffnoiz          =   LFNoise2.kr(freq!2).range(ffnoizamt.reciprocal, ffnoizamt);
    var ffmod           =   XLine.kr(ffstart, ffend, dur / 2);
    var sineshaper      =   SineShaper.ar(sinfb, foldfactor * ffmod * ffnoiz, envgen) * (foldfactor.abs + 0.01).reciprocal;
    Out.ar([0, ~bassfxbus], sin + (sinfb * envgen) + sineshaper);
}).add;
);


// Pattern

(
~bassfoldseries = Array.series(11, 0.01, 0.001);
Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
        \curve, -16,
        \dur, Pshuf(([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].stutter(3)), inf),
        \fb, Pshuf((0..2), inf),
        \ffnoizamt, Pshuf([1, 2, 3, 4], inf),
        \ffstart, Pshuf([0.1, 0.25, 0.5, 0.75], inf),
        \ffend, Pshuf([2, 3, 4, 5, 7], inf),
		//\foldfactor, Pshuf(~bassfoldseries.stutter(3), inf),
        \level, 0.015,
        \degree, Pshuf([-2, 0, 3], inf),
        \octave, [2, 3],
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
		Pdef(\basspar).play(t);
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
        \inBus, ~bassfxbus
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
// PNO

(
SynthDef(\pno, { |balance = 0, curve = 0, dur = 1, fb = 0, freq = 400, k = 1, level = 0.02, loffset = 0.1, pan = 0, s = 10|
    var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var freqmod         =   LorenzL.ar([22050, 22000], s).range(1 - loffset, 1 + loffset);
    var fbmod           =   StandardL.ar(200, [k, k - 0.01]).range(0, 1);
    var sinfb1			=	SinOscFB.ar(freq * freqmod, fb * fbmod).softclip * envgen;
    var sinfb2          =   SinOscFB.ar([freq - 0.1, freq + 0.1], fb, envgen);
    var bal             =   Balance2.ar((sinfb1 + sinfb2)[0], (sinfb1 + sinfb2)[1], balance);
	Out.ar(~prcfxbus, bal);
}).add;
);

(
Pdef(\pno1,
    Pbind(
        \instrument, \pno,
        \curve, -32,
        \degree, Pseq([Pseq([[7, 10, 12, 14]], 12), Pseq([Rest], 8)], inf),
        \dur, Pshuf([0.5, 0.75, 1, 1.5, 11, 13, 15, 17, 19], inf),
        \fb, Pwhite(0.0, 2.0, inf),
        \k, Pwhite(0.5, 4.0, inf),
        \loffset, Pshuf([0, 0.1, 0.2, 0.3, 0.4], inf),
        \octave, 5,
        \timingOffset, Pwhite(-0.03, 0.03, inf),
        \s, Pwhite(9.0, 11.0, inf),
        \scale, ~scale
));

Pdef(\pnos, Ppar([Pdef(\pno1)].stutter(5), inf));

Pdef(\pnopulse,
    Pbind(
        \instrument, \pno,
        \balance, Prand([-1, 1], inf),
        \curve, -4,
        //\degree, Pseq([Pseq([~chord], 151), Pseq([Rest], 53)], inf),
        \degree, Pshuf(Array.fill(~chords.size, { |n| Pseq([~chords[n]], (n + 19).nthPrime) }), inf),
        \dur, Prand([0.25, 0.5], inf),
        \fb, Pwhite(0.0, 1.5, inf),
        \k, Pwhite(0.5, 4, inf),
        //\level, Prand([0.2, 0.2, 1] * 0.005, inf),
        \level, 0.005,
        \loffset, Pwhite(0.0, 0.4, inf),
        \octave, [4, 5],
        \s, Pwhite(9.0, 11.0, inf),
        \scale, ~scale
));

Pdef(\pnopulses, Ppar([Pdef(\pnopulse)].stutter(3), inf));
Pdef(\pnopulses2, Pbindf(Pdef(\pnopulses), \octave, [5,6]));
);

/*
Pdef(\pno1).play(t);
Pdef(\pno1).isPlaying;
Pdef(\pno1).stop;
*/

/*
Pdef(\pnos).play(t);
Pdef(\pnos).isPlaying;
Pdef(\pnos).stop;
*/

/*
Pdef(\pnopulse).play(t);
Pdef(\pnopulse).isPlaying;
Pdef(\pnopulse).stop;
*/

/*
Pdef(\pnopulses).play(t);
Pdef(\pnopulses).isPlaying;
Pdef(\pnopulses).stop;
*/

/*
Pdef(\pnopulses2).play(t);
Pdef(\pnopulses2).isPlaying;
Pdef(\pnopulses2).stop;
*/

(
MIDIdef.cc(\pnosplay, {
    if(Pdef(\pnos).isPlaying.not) {
        Pdef(\pnos).play(t);
        "pnos play".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnosstop, {
    if(Pdef(\pnos).isPlaying) {
        Pdef(\pnos).stop;
        "pnos stop".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pnopulsesplay, {
    if(Pdef(\pnopulses).isPlaying.not) {
        Pdef(\pnopulses).play(t);
        "pnopulses play".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnopulsesstop, {
    if(Pdef(\pnopulses).isPlaying) {
        Pdef(\pnopulses).stop;
        "pnopulses stop".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pnopulses2play, {
    if(Pdef(\pnopulses2).isPlaying.not) {
        Pdef(\pnopulses2).play(t);
        "pnopulses2 play".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnopulses2stop, {
    if(Pdef(\pnopulses2).isPlaying) {
        Pdef(\pnopulses2).stop;
        "pnopulses2 stop".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// WUT

(
SynthDef(\wut, { |attack = 0.01, curve = 0, dur = 1, fb = 0, foldfactor = 1, freq = 440, gate = 1, k = 1.4, level = 0.01, release = 0.1|
    var env             =   Env.asr(attack, level, release, curve);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin             =   SinOscFB.ar(freq * LFNoise0.kr(15!2, 0.001, 1), fb * Standard2DC.kr(0.5, 500, [k, k + 0.1]).range(0, 1).fold(0, 1), envgen);
    Out.ar(0, sin.fold2(level));
}).add;
);

(
Pdef(\wut,
    Pbind(
        \instrument, \wut,
        \degree, Pshuf(~chords, inf),
        \dur, 43,
        \fb, 1.5,
        \k, Pwhite(1.0, 2.0, inf),
        \legato, 0.5,
        \octave, 5,
        \scale, ~scale
));
);

/*
Pdef(\wut).play(t, quant: 1);
Pdef(\wut).isPlaying;
Pdef(\wut).stop;
*/

Pdef(\wat, Pbind(\instrument, \wut, \degree, [7, 10, 12], \dur, 53, \fb, 0.8, \legato, 0.5, \octave, 4, \scale, ~scale));

/*
Pdef(\wat).play(t, quant: 1);
Pdef(\wat).isPlaying;
Pdef(\wat).stop;
*/

Pdef(\wet, Pmono(\wut, \degree, [-5, 0], \fb, 0.3, \scale, ~scale));

/*
Pdef(\wet).play(t, quant: 1);
Pdef(\wet).isPlaying;
Pdef(\wet).stop;
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
MIDIdef.cc(\watplay, {
    if(Pdef(\wat).isPlaying.not) {
        Pdef(\wat).play(t, quant: 1);
        "wat".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\watstop, {
    if(Pdef(\wat).isPlaying) {
        Pdef(\wat).stop;
        "no wat".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

//

(
MIDIdef.cc(\wetplay, {
    if(Pdef(\wet).isPlaying.not) {
        Pdef(\wet).play(t, quant: 1);
        "wet".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\wetstop, {
    if(Pdef(\wet).isPlaying) {
        Pdef(\wet).stop;
        "no wet".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PINGLE

(
SynthDef(\pingle, { | a = 0.02, curve = -16, freq = 10000, level = 0.05, pan = 0 |
	var env				=	Env.perc(releaseTime: 0.003, level: level, curve: curve);
	var envgen			=	EnvGen.ar(env, doneAction: 2);
	var pn              =   PinkNoise.ar(envgen!2);
    var rhpf            =   RHPF.ar(pn, 12000, 0.03);
    Out.ar(~prcfxbus, (rhpf).fold2(level));
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
	Out.ar(~prcfxbus, pan2);
}).add;
);

(
~clapdurs = [
    0.75, 1,
    0.75, 1, 1.25,
    0.75, 1, 1.25, 1.5
		];
//~clapchords = (0..~ratios.size).powerset.reject({ |i| i.size != 6 });
~claplvl = 0.1;
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
		Pdef(\clappar).play(t);
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
SynthDef(\prc1, { |curve = -16, dur = 1, ffreq = 4000, ffreqmodrate = 4, freq = 1000, level = 0.2, xaos = 1.5|
    var env             =   Env.perc(0.01, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var noiz            =   LFBrownNoise2.ar((freq!2 * XLine.kr(1, 0.1, dur))).tanh;
    var crackle         =   Crackle.ar(xaos!2, 1, 1);
    var ffreqmod        =   LFNoise0.kr((t.tempo * ffreqmodrate)).range(0.25, 1);
    var rhpf            =   RHPF.ar(noiz * crackle, (ffreq * ffreqmod).clip(50, SampleRate.ir / 2.5), 1, envgen);
    Out.ar(~prcfxbus, rhpf.fold2(level / 8) * 2);
}).add;
);

(
Pdef(\prc1,
    Pbind(
        \instrument, \prc1,
        \curve, -12,
        \dur, Pshuf([Pseq([0.25], 12), Pshuf([0.5, 0.75, 1, 1.25].stutter(11)), 3], inf),
        \ffreq, Pshuf((1..23) * 300, inf),
        //\ffreq, Pshuf([100, 1000, 200, 2000, 300, 3000, 4000], inf),
        \freq, Pshuf([500, 750, 1000, 5000, 7500, 10000], inf),
        \ffreqmodrate, Pshuf((4..8), inf),
        \xaos, Pshuf((13..19) / 10, inf)
));
);

/*
Pdef(\prc1).play(t);
Pdef(\prc1).isPlaying;
Pdef(\prc1).stop;
*/

(
Pdef(\prc1b,
    Pbind(
        \instrument, \prc1,
        \dur, Pshuf([0.5, 0.75, 1].stutter(11), inf),
        \ffreq, Pseq([100, 2000, 100, 2000, 100, 100, 2000, 2000], inf),
        \ffreqmodrate, 16,
        \xaos, 1.9
));
);

/*
Pdef(\prc1b).play(t);
Pdef(\prc1b).isPlaying;
Pdef(\prc1b).stop;
*/

(
MIDIdef.cc(\prc1play, {
    if(Pdef(\prc1).isPlaying.not) {
        Pdef(\prc1).play(t);
        "prc1 play".postln;
    };
}, 36, argTemplate: { |x| x > 0 }, srcID: ~nanoktrl2.uid);

MIDIdef.cc(\prc1stop, {
    if(Pdef(\prc1).isPlaying) {
        Pdef(\prc1).stop;
        "prc1 stop".postln;
    };
}, 36, argTemplate: 0, srcID: ~nanoktrl2.uid);
);

////////////////////////////////////////////////////////////////
// PRC2

(
SynthDef(\prc2, { |curve = -16, fb = 0, freq = 440, length = 0.1, level = 0.1, lfreq = 22050, s = 10|
    var env             =   Env.perc(0.005, length, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sinmod          =   LorenzL.ar([lfreq, lfreq - 10], [s, s - 0.1], add: 1);
    var sin             =   SinOscFB.ar(freq * sinmod * XLine.kr(1, 0.1, length), fb, envgen);
    Out.ar(~prcfxbus, sin.fold2(level));
}).add;
);

(
Pdef(\prc2a,
    Pbind(
        \instrument, \prc2,
        \curve, -64,
        \dur, Pshuf([0.25, 1].stutter(13), inf),
        \fb, Pshuf(Array.series(11, 2.5, 0.1), inf),
        \freq, Pseq([40, 800, 40, 40, 800, 40, 40, 40, 800], inf),
        \length, 0.2,
        \s, Pshuf([9, 12].stutter(5), inf)
));
);

/*
Pdef(\prc2a).play(t);
Pdef(\prc2a).isPlaying;
Pdef(\prc2a).stop;
*/

(
Pdef(\prc2b,
    Pbind(
        \instrument, \prc2,
        \curve, -16,
        //\dur, Pshuf([Pseq([0.125], 2), 0.25, 0.5, Pseq([1/6], 3), 0.75, 1, 1.5, 2, 3].stutter(7), inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5].stutter(7), inf),
        \fb, Pxrand((1..5), inf),
        //\freq, Pxrand(Array.fill(5, { |i| pi.pow(i + 4) * 2 }), inf),
        \freq, Pshuf([125, 250, 500, 1000, 2000, 4000, 8000].stutter(3), inf),
        \length, Pxrand([0.1, 0.2, 0.4, 0.8, 1.6], inf),
        \lfreq, Pshuf((3..15) * 1000, inf),
        \s, Pwhite(7.0, 12.0, inf).round(0.1)
));
);

/*
Pdef(\prc2b).play(t);
Pdef(\prc2b).isPlaying;
Pdef(\prc2b).stop;
*/

(
MIDIdef.cc(\prc2aplay, {
    if(Pdef(\prc2a).isPlaying.not) {
        Pdef(\prc2a).play(t);
        "prc2a play".postln;
    };
}, 67, argTemplate: { |x| x > 0 }, srcID: ~nanoktrl2.uid);

MIDIdef.cc(\prc2astop, {
    if(Pdef(\prc2a).isPlaying) {
        Pdef(\prc2a).stop;
        "prc2a stop".postln;
    };
}, 67, argTemplate: 0, srcID: ~nanoktrl2.uid);
);

(
MIDIdef.cc(\prc2bplay, {
    if(Pdef(\prc2b).isPlaying.not) {
        Pdef(\prc2b).play(t);
        "prc2b play".postln;
    };
}, 68, argTemplate: { |x| x > 0 }, srcID: ~nanoktrl2.uid);

MIDIdef.cc(\prc2bstop, {
    if(Pdef(\prc2b).isPlaying) {
        Pdef(\prc2b).stop;
        "prc2b stop".postln;
    };
}, 68, argTemplate: 0, srcID: ~nanoktrl2.uid);
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
	Out.ar(~prcfxbus, pan2);
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
        \dur, Pshuf([Pseq([0.25], 3), Pseq([0.25], 5), Pseq([0.25], 7), 2, 3, 4, 6, 8, 12, 16, 24], inf),
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
        \dur, Pshuf([0.5, 0.75, 1, 1.5, 2, 3].stutter(3), inf),
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

/*
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
*/

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
