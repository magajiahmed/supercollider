////////////////////////////////////////////////////////////////
// INIT

// clear all patterns
Pdef.removeAll;

// Clock and buffer
(
t = TempoClock(84/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 3), 1);
);

// MIDI
(
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
MIDIdef.cc(\ccpostln, { |...args| args.postln; });
MIDIdef.noteOn(\noteonpostln, { |...args| args.postln; });
~lpm = MIDIClient.sources.detect{ |a| a.name.contains("Launchpad Mini") };
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~lpm.isNil) { ~lpm = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
~midiout =  MIDIOut(0);
~midiout.connect(~lpm.uid);
);

// MIDI Control
(
~midiktrl = { |pdef, note|
    MIDIdef.noteOn(pdef, {
        if(Pdef(pdef).isPlaying.not) {
            ~midiout.noteOn(0, note, 127);
            Pdef(pdef).play(t, quant: 0.25);
            pdef.post;
            " play".postln;
        } {
            ~midiout.noteOn(0, note, 0);
            Pdef(pdef).stop;
            pdef.post;
            " stop".postln;
        }
    }, note, srcID: ~lpm.uid);
}
);

// Bus depot
(
~bassfxbus = Bus.audio(s, 2);
~delay = 0.05;
~delaybus = Bus.audio(s, 2);
~prcfxbus = Bus.audio(s, 2);
~verbus = Bus.audio(s, 2);
);

// Pitch logic
(
~ratios = [1/1, 16/15, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 5/3, 7/4, 15/8];
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  _______  __
// |  ___\ \/ /
// | |_   \  /
// |  _|  /  \
// |_|   /_/\_\
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////
// LIMITER

(
SynthDef(\limiter, { |dur = 1, gate = 1, inBus = 0, level = 1, outbus = 0|
    var env             =   Env.asr(0.01, 1, 0.01, 0);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inBus, 2);
    var limiter         =   Limiter.ar(in, level, dur);
    Out.ar(outbus, limiter);
}).add;
);

(
Pdef(\limiter, Pmono(\limiter, \dur, ~delay * 0.5, \inBus, ~prcfxbus, \level, 0.25, \outbus, 0));
);

/*
Pdef(\limiter).play(t);
Pdef(\limiter).isPlaying;
Pdef(\limiter).stop;
*/

////////////////////////////////////////////////////////////////
// DELAY

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

/*
Pdef(\delay).play(t);
Pdef(\delay).isPlaying;
Pdef(\delay).stop;
*/

////////////////////////////////////////////////////////////////
// VERB

(
SynthDef(\verb, { |dur = 1, gate = 1, inBus, level = 0.1, outbus|
    var env             =   Env.asr(0.01, level, 0.1, -64);
    var envgen          =   EnvGen.ar(env, gate, doneAction: 2);
    var in              =   In.ar(inBus, 2);
    var verb            =   JPverb.ar(in, t60: 5, size: 0.1, earlyDiff: 0.1, modDepth: 0.0, modFreq: 0.0).round(0.01) * envgen;
    var grainin         =   GrainIn.ar(2, Dust2.kr(15!2), LFNoise0.kr(15!2).range(0.001, 0.1), verb);
    Out.ar(outbus, grainin);
}).add;
);

(
Pdef(\verb,
    Pbind(
        \instrument, \verb,
        \dur, Pshuf([0.25, 0.5, 1, 2, 4, 8, 16, 32, 64], inf),
        \inBus, ~verbus,
        \legato, 1,
        \level, 0.3,
        \outbus, ~delaybus
));

Pdef(\verbs, Ppar([Pdef(\verb)].stutter(2), inf));
);

/*
Pdef(\verbs).play(t);
Pdef(\verbs).isPlaying;
Pdef(\verbs).stop;
*/

//

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ___ _   _ ____ _____ ____  _   _ __  __ _____ _   _ _____ ____
// |_ _| \ | / ___|_   _|  _ \| | | |  \/  | ____| \ | |_   _/ ___|
//  | ||  \| \___ \ | | | |_) | | | | |\/| |  _| |  \| | | | \___ \
//  | || |\  |___) || | |  _ <| |_| | |  | | |___| |\  | | |  ___) |
// |___|_| \_|____/ |_| |_| \_\\___/|_|  |_|_____|_| \_| |_| |____/
//
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//

////////////////////////////////////////////////////////////////
// DINGLE

(
SynthDef(\dingle, { |a = 0.02, curve = -16, freq = 10000, level = 0.2, outbus, pan = 0|
	var env				=	Env.perc(0.003, 1, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq * 4, a, 3, add: 1);
	var sin				=	SinOsc.ar(freq * (cusp), mul: envgen);
	var rez				=	Resonz.ar(sin, 6000, 0.1);
	var pan2			=	Pan2.ar(rez, pan);
	Out.ar(outbus, pan2);
}).add;
);

// Pattern

(
~dinglelvl = 0.4;
~dingleecholvl = ~dinglelvl / 4;

Pdef(\dinglepat1,
	Pbind(
		\instrument, \dingle,
		\a, 0.01,
		\curve, -4,
    	\dur, Pshuf([
            Pseq([1.25], 3),
            Pseq([1.5], 3),
            Pseq([1.75], 3),
            Pseq([2], 3),
            Pseq([2.25], 3),
		], inf),
		\level, ~dinglelvl,
		\octave, 5,
        \outbus, ~prcfxbus,
        \scale, ~scale,
));

Pdef(\dinglepat1a, Pbindf(Pdef(\dinglepat1), \level, ~dingleecholvl, \pan, -1));
Pdef(\dinglepat1b, Pbindf(Pdef(\dinglepat1a), \pan, 1));
Pdef(\dinglepat2, Pbindf(Pdef(\dinglepat1), \octave, 7));
Pdef(\dinglepat2a,
    Pbindf(
        Pdef(\dinglepat2),
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
Pdef(\dinglepar2).play(t, quant: 0.5);
Pdef(\dinglepar2).isPlaying;
Pdef(\dinglepar2).stop;
*/

(
Pdef(\single1,
    Pbind(
        \instrument, \dingle,
        \a, Pwhite(0.01, 0.02, inf),
        \curve, -64,
        \degree, 7,
        \dur, Pshuf(Array.fill(5, { |d| (d + 1) * 0.25 }).stutter(5), inf),
        \level, Pshuf([0.2, 1].stutter(17) * 0.4, inf),
        \octave, 7,
        \outbus, ~prcfxbus,
        \pan, Pshuf([-1, -0.5, 0, 0.5, 1], inf),
        \scale, ~scale
));

Pdef(\single2,
    Pbindf(
        Pdef(\single1),
        \dur, Pseq([
            Pseq([0.125], 4), Pseq([0.25], 31), (31 * 0.25),
            Pseq([0.125], 4), Pseq([0.25], 37), (37 * 0.25),
            Pseq([0.125], 4), Pseq([0.25], 41), (41 * 0.25)
], inf)));
);

/*
Pdef(\single1).play(t, quant: 0.5);
Pdef(\single1).isPlaying;
Pdef(\single1).stop;
*/

/*
Pdef(\single2).play(t, quant: 0.5);
Pdef(\single2).isPlaying;
Pdef(\single2).stop;
*/

// Midi Control

~midiktrl.value(\dinglepar2, 32);
~midiktrl.value(\single1, 33);
~midiktrl.value(\single2, 49);

////////////////////////////////////////////////////////////////
// SNAP

// Synth

(
SynthDef(\snap, { | curve = -512, dur = 1, freq = 400, im = 1, level = 0.2, outbus, rt = 0.1 |
	var env				=	Env.new([0, level, level / 40, 0], [0.005, 0.005, dur], curve: 'cubed');
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var fbs				=	FBSineC.ar(freq: freq, im: [im, im + 1], mul: envgen);
	var flt				=	RHPF.ar(fbs, 2000, 0.5);
	Out.ar(outbus, flt);
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
		\octave, 10,
        \outbus, ~prcfxbus,
		\scale, ~scale,
));
);

/*
Pdef(\snappat).play(t, quant: 0.5);
Pdef(\snappat).isPlaying;
Pdef(\snappat).stop;
*/

// Midi control

~midiktrl.value(\snappat, 48);

////////////////////////////////////////////////////////////////
// XAOS

(
SynthDef(\xaos, { |chaos = 1.5, curve = -16, dur = 1, level = 0.2, outbus, resonz_freq = 4000, rhpf_freq = 8000|
    var env             =   Env.perc(0.01, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var xaos            =   Crackle.ar([chaos, chaos - 0.01]).round(0.5) * envgen * 2;
    var resonz          =   Resonz.ar(xaos, resonz_freq.clip(50, SampleRate.ir / 2.5), 0.5) * 20;
    //var rhpf            =   RHPF.ar(xaos, rhpf_freq.clip(50, SampleRate.ir / 2.5), 0.5) * LFClipNoise.ar(80).range(0.5, 1).round(0.5);
    Out.ar(outbus, resonz.fold2(level));
}).add;
);

(
Pdef(\xaos,
    Pbind(
        \instrument, \xaos,
        \chaos, Pshuf([1.1, 1.25, 1.9, 2.0].stutter(11), inf),
        //\curve, Prand([-64, -32, -16], inf),
        \curve, -64,
        \degree, Pseq([Pseq([0], 53), Pseq([Rest], 31)], inf),
        \dur, Pseq([Pseq([0.125], 4), Pshuf(Array.fill(3, { |i| (i + 1) * 0.25 }).stutter(3))], inf),
        \outbus, ~prcfxbus,
        //\resonz_freq, Pshuf(Array.fill(3, { |i| pi.pow(i + 5) }).stutter(5), inf),
        \resonz_freq, Prand([100, 1000, 10000], inf),
        //\rhpf_freq, Pshuf([1000, 10000].stutter(3), inf),
));
);

/*
Pdef(\xaos).play(t);
Pdef(\xaos).isPlaying;
Pdef(\xaos).stop;
*/

~midiktrl.value(\xaos, 64);

////////////////////////////////////////////////////////////////
// SINPRC

(
SynthDef(\sinprc, { |curve = -16, fb = 2.5, ffreq = 4000, freq = 440, gfreq = 22050, level = 0.2, outbus, xi = 1.2, yi = 2.1|
    var env             =   Env.perc(0.01, 0.3, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var gbman           =   GbmanL.ar([gfreq, gfreq - 1], xi, yi, 0.25, 1);
    var sin             =   SinOscFB.ar(freq * gbman * XLine.kr(1, 0.1, 0.1), fb, envgen);
    var rhpf            =   RHPF.ar(sin, ffreq.clip(50, SampleRate.ir / 2.5), 0.5);
    Out.ar(outbus, rhpf.fold2(level));
}).add;
);

(
Pdef(\sinprc,
    Pbind(
        \instrument, \sinprc,
        \curve, Pshuf([-64, -32, -16].stutter(7), inf),
        \dur, Pshuf([Pseq([0.125], 4), 0.25, 0.5, Pseq([0.25], 3), 0.75, 1, Pseq([0.25], 6), 1.5, 2, 3].stutter(3), inf),
        \fb, Pshuf([1, 2, 3].stutter(17), inf),
        \ffreq, Pshuf([100, 10000].stutter(9), inf),
        \freq, Pshuf([100, 1000, 10000].stutter(13), inf),
        \outbus, ~prcfxbus,
        \xi, Pshuf([-0.5, 0, 0.5].stutter(5), inf),
        \yi, Pshuf([-2, 0, 2].stutter(7), inf)
));
);

/*
Pdef(\sinprc).play(t);
Pdef(\sinprc).isPlaying;
Pdef(\sinprc).stop;
*/

~midiktrl.value(\sinprc, 65);

////////////////////////////////////////////////////////////////
// clip noise percussion

(
SynthDef(\cnprc, { |bal = 0, curve = -16, freq = 500, level = 0.05, outbus, releaseTime = 0.1, rhpf_cutoff_start = 1, rhpf_cutoff_end = 1|
    var env             =   Env.perc(0.003, releaseTime, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var blip            =   Blip.ar(0, mul: envgen);
    var clipnoiz        =   LFClipNoise.ar(freq!2, envgen);
    var rlpf            =   BLowPass4.ar(blip + clipnoiz, freq.clip(50, SampleRate.ir / 2.5), 0.1);
    var rhpf            =   RHPF.ar(blip + clipnoiz, (12000 * XLine.ar(rhpf_cutoff_start, rhpf_cutoff_end, releaseTime)).clip(50, SampleRate.ir / 2.5), 0.5);
    var balance         =   Balance2.ar((rlpf + rhpf)[0], (rlpf + rhpf)[1], bal);
    Out.ar(outbus, balance);
}).add;
);

(
~cnprclvl = 0.05;
~cnprcecholvl = ~cnprclvl / 4;
Pdef(\cnprc1,
    Pbind(
        \instrument, \cnprc,
        \bal, Pshuf([-1, -0.5, -0.25, 0, 0.25, 0.5, 1], inf),
        \curve, -2,
        \dur, Pseq([Pseq([0.125], 4), Pshuf(Array.fill(11, { |d| (d + 1) * 0.25 }))], inf),
        \freq, Pseq([Pshuf([80, 800].stutter(17)), Pseq([Rest], 17)], inf),
        \level, ~cnprclvl,
        \outbus, ~prcfxbus,
        \releaseTime, Pshuf([0.05, 0.1, 0.2, 0.4].stutter(13), inf),
        \rhpf_cutoff_start, Pshuf([0.25, 0.5, 1], inf),
        \rhpf_cutoff_end, Pshuf([0.1, 1, 1, 1, 1], inf)
));
Pdef(\cnprc2, Pbindf(Pdef(\cnprc1), \level, ~cnprcecholvl));
Pdef(\cnprcpar, Ppar([Pdef(\cnprc1), Pdef(\cnprc2)], inf));
);

(
Pdef(\cnprc3,
    Pbindf(
        Pdef(\cnprc1),
        \curve, -16,
        \dur, Pshuf(Array.fill(7, { |d| (d + 1) * 0.25 }), inf),
        \freq, Pseq([Pshuf([100, 1000, 10000].stutter(7), 2), Pseq([Rest], 19)], inf),
        \releaseTime, Pshuf([Pseq([0.125], 4), 0.25, 0.5, 0.75, 1, 1.5], inf),
        \rhpf_cutoff_start, 1,
        \rhpf_cutoff_end, Pshuf([0.01, 0.1, 1], inf)
));
);

/*
Pdef(\cnprcpar).play(t, quant: 0.5);
Pdef(\cnprcpar).isPlaying;
Pdef(\cnprcpar).stop;
*/

/*
Pdef(\cnprc3).play(t, quant: 0.5);
Pdef(\cnprc3).isPlaying;
Pdef(\cnprc3).stop;
*/

~midiktrl.value(\cnprcpar, 34);
~midiktrl.value(\cnprc3, 50);

////////////////////////////////////////////////////////////////
// LORI

(
SynthDef(\lori, { |balance = 0, curve = -16, dur = 1, freq = 440, length = 1, level = 0.2, lfreq = 22050, lorimul = 1, outbus, r = 28, s = 10, start = 1, end = 1|
    var env             =   Env.perc(0.005, length, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var lori            =   LorenzL.ar(lfreq * XLine.ar(start, end, length), [s, s - 0.05], [r, r - 0.05], mul: lorimul, add: 1);
    var sin             =   SinOsc.ar(freq * lori, mul: envgen);
    var bal             =   Balance2.ar(sin[0], sin[1], balance);
    Out.ar(outbus, bal);
}).add;
);

(
Pdef(\lori,
    Pbind(
        \instrument, \lori,
        \balance, Pshuf([-0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75], inf),
        \curve, Pshuf([-64, -32, -16].stutter(7), inf),
        \dur, Pshuf([Pseq([0.125], 8), 0.25, 0.5, 0.75, 1, 1.5].stutter(11), inf),
        \freq, Pseq([Pshuf([64, 8192].stutter(3), 10), Pseq([Rest], 31)], inf),
        \length, Pshuf([0.5, 0.75, 1].stutter(11), inf),
        \lorimul, Pshuf([0.5, 1, 2, 4].stutter(17), inf),
        \outbus, ~prcfxbus,
        \r, Pshuf((29..40), inf),
        \s, Pshuf((8..12), inf),
        \start, Pshuf([0.2, 0.4, 0.6, 0.8, 1.0], inf),
        \end, Pshuf([0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0], inf)
));
);

/*
Pdef(\lori).play(t);
Pdef(\lori).isPlaying;
Pdef(\lori).stop;
*/

~midiktrl.value(\lori, 66);

////////////////////////////////////////////////////////////////
// PAD

(
SynthDef(\pad, { |a = 1.1, curve = -4, dur = 1, fb = 0, freq = 400, freqmod_length = 0.01, freqmod_start = 1, gate = 1, level = 0.01, outbus|
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var sin1            =   SinOscFB.ar(freq!2 * XLine.ar(freqmod_start, 1, freqmod_length), fb, envgen);
    Out.ar(outbus, sin1);
}).add;
);

(
Pdef(\pad1,
    Pbind(
        \instrument, \pad,
        \bal, Pshuf([-0.5, 0, 0.5].stutter(13), inf),
        \dur, Pshuf(Array.fill(7, { |i| (i + 25).nthPrime }), inf),
        \fb, 1.5,
        \freqmod_start, Pshuf([0.125, 0.25, 0.5, 2, 4], inf),
        \legato, 0.25,
        \degree, Pshuf([[0, 7, 10], [7, 10, 12], [10, 12, 19]], inf),
        \octave, Pshuf([4, 5, 6].powerset.reject ({ |i| i.isEmpty }), inf),
        \outbus, ~delaybus,
        \scale, ~scale,
));

Pdef(\pads, Ptpar([0, Pdef(\pad1), 11, Pdef(\pad1), 13, Pdef(\pad1), 17, Pdef(\pad1)]));
);

/*
Pdef(\pads).play(t, quant: 0.5);
Pdef(\pads).isPlaying;
Pdef(\pads).stop;
*/

(
Pdef(\paddrone1,
    PmonoArtic(
        \pad,
        \degree, [7, 12],
        \dur, Pshuf([0.5, 0.75, 1, 1.25, 1.5].stutter(3), inf),
        \fb, 0.3,
        \freqmod_length, 0.01,
        \freqmod_start, Pshuf([2, 4].stutter(7), inf),
        \legato, 0.999,
        \octave, 5,
        \outbus, ~delaybus,
        \scale, ~scale
));

(
Pdef(\paddrone2,
    Pbind(
        \instrument, \pad,
        \degree, [7, 12],
        \dur, Pshuf([97, 101, 103], inf),
        \fb, 1.5,
        \freqmod_length, 0.1,
        \freqmod_start, Prand([0.5, 2], inf),
        \legato, 0.25,
        \octave, 8,
        \scale, ~scale
));
);
);

/*
Pdef(\paddrone1).play(t, quant: 0.5);
Pdef(\paddrone1).isPlaying;
Pdef(\paddrone1).stop;
*/

/*
Pdef(\paddrone2).play(t, quant: 0.5);
Pdef(\paddrone2).isPlaying;
Pdef(\paddrone2).stop;
*/

/*
Pdef(\paddrones).play(t, quant: 0.5);
Pdef(\paddrones).isPlaying;
Pdef(\paddrones).stop;
*/

~midiktrl.value(\pads, 35);
~midiktrl.value(\paddrone1, 51);
~midiktrl.value(\paddrone2, 67);

////////////////////////////////////////////////////////////////
// LARRY

(
SynthDef(\larry, { |curve = -4, dur = 1, fb = 0, freq = 440, gate = 1, level = 0.003, outbus, s = 10|
    var env             =   Env.asr(0.01, level, 0.01, curve);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var frqmod          =   Lorenz2DN.ar(15, 15000, s: [s, s - 0.001],  mul: 0.9, add: 1);
    var sinmod          =   SinOscFB.ar(freq * 8 * frqmod, fb, envgen / 8);
    var sin1            =   SinOscFB.ar(freq, fb, envgen);
    var sin2            =   SinOsc.ar(freq * LFNoise0.kr(15, 0.003, 1), mul: envgen);
    Out.ar(outbus, sinmod + sin1 + sin2);
}).add;
);

(
Pdef(\larry1,
	Pbind(
		\instrument, \larry,
        \curve, -32,
        \dur, Pshuf(Array.fill(5, { |i| (i + 9).nthPrime }) + 0.25, inf),
        \fb, 0,
        \legato, 1,
        \degree, Pseq([[7, 10, 12, 13], Rest], inf),
        \octave, 5,
        \outbus, ~delaybus,
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

Pdef(\larry4, Pbindf(Pdef(\larry1), \degree, Pseq([0, Rest], inf), \legato, 1, \octave, [2, 3, 4]));

Pdef(\larrys, Ppar([Pdef(\larry1), Pdef(\larry1), Pdef(\larry1), Pdef(\larry1), Pdef(\larry1), Pdef(\larry4)], inf));
);

/*
Pdef(\larry1).play(t, quant: 0.5);
Pdef(\larry1).isPlaying;
Pdef(\larry1).stop;
*/

/*
Pdef(\larry2).play(t, quant: 0.5);
Pdef(\larry2).isPlaying;
Pdef(\larry2).stop;
*/

/*
Pdef(\larry3).play(t, quant: 0.5);
Pdef(\larry3).isPlaying;
Pdef(\larry3).stop;
*/

/*
Pdef(\larry4).play(t, quant: 0.5);
Pdef(\larry4).isPlaying;
Pdef(\larry4).stop;
*/

/*
Pdef(\larrys).play(t, quant: 0.5);
Pdef(\larrys).isPlaying;
Pdef(\larrys).stop;
*/

~midiktrl.value(\larrys, 68);

////////////////////////////////////////////////////////
// PNO

// SynthDef
(
SynthDef(\pno, { |curve = -8, dur = 1, fb = 0, freq = 440, level = 0.03, outbus|
    var env             =   Env.perc(0.001, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var xline           =   XLine.kr(0.5, 1, 0.01);
    var sin1            =   SinOscFB.ar(freq * xline * LFNoise2.kr(0.5!2, 0.001, 1) * LFNoise0.kr(17!2, 0.002, 1), fb);
    var sin3            =   SinOscFB.ar(freq!2 * xline, fb);
    Out.ar(outbus, ((sin1 + sin3).fold2(0.2) * 5 * envgen * 0.5) + ((sin1 + sin3) * envgen * 0.5));
}).add;
);

(
Pdef(\pno1,
    Pbind(
        \instrument, \pno,
        \degree, Pshuf([0, [-2, 0], [0, 1, 7]], inf),
        \dur, Prand([0.75, 1.25, 2.25, 3.25, 5, 11.25], inf),
        \fb, 0,
        \level, Prand([0.2, 1] * 0.02, inf),
        \octave, 6,
        \outbus, ~delaybus,
        \scale, ~scale
));

Pdef(\pno2, Pbindf(Pdef(\pno1), \fb, 0, \octave, 9));

Pdef(\pnos, Ppar([Pdef(\pno1), Pdef(\pno2)].stutter(2), inf));
);

/*
Pdef(\pnos).play(t);
Pdef(\pnos).isPlaying;
Pdef(\pnos).stop;
*/

(
Pdef(\pnochord,
    Pbind(
        \instrument, \pno,
        \degree, Pseq([[0, 1, 7], [1, 7, 12], [7, 10, 12, 13]], inf),
        \dur, Pshuf([13, 17, 19], inf),
        \fb, Pshuf([0, 0.125, 0.25, 0.5, 1], inf),
        \octave, 5,
        \outbus, ~delaybus,
        \scale, ~scale
));
);

/*
Pdef(\pnochord).play(t);
Pdef(\pnochord).isPlaying;
Pdef(\pnochord).stop;
*/

~midiktrl.value(\pnos, 36);
~midiktrl.value(\pnochord, 52);

////////////////////////////////////////////////////////
// BASS

// SynthDef

(
SynthDef(\abass, { |carrier_amp = 1, carrier_ratio = 1, curve = -4, dur = 1, fb = 0, freq = 440, level = 0.05, outbus|
    var env             =   Env.perc(0.001, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    //var fbmod           =   LFNoise2.kr(3!2, XLine.kr(1, 0.01, dur), 1) * LFNoise2.kr(11!2, XLine.kr(1, 0.01, dur), 1);
    var fbmod           =   1;
    var sinfb1freqmod   =   SinOscFB.ar(freq * carrier_ratio * XLine.kr(0.5, 1, 0.1), 0, carrier_amp * XLine.kr(1, 0.1, 0.1), 1);
    var sinfb1          =   SinOscFB.ar(freq!2 * sinfb1freqmod, fb * XLine.kr(1, 0.1, 0.2)) * envgen;
    var sinfb2          =   SinOscFB.ar(freq, fb * fbmod) * envgen;
    //var tri             =   LFTri.ar(freq!2, mul: envgen);
    var sinfb3          =   SinOscFB.ar(freq ! 2, 0.2, envgen);
    Out.ar(outbus, sinfb1 + sinfb2 + sinfb3);
}).add;
);

// Pattern

(
~bassnotes = (-5..3);
~bassdurations = [0.25, 0.5, 0.75, 1, 1.5, 8, 12];

Pdef(\bass,
	Pbind(
        \instrument, \abass,
        \carrier_amp, Pshuf((1..23), inf),
        \carrier_ratio, Pxrand([1, 2, 4], inf),
        \degree, Pseq([Pshuf(~bassnotes, 4), Pseq([Rest], ~bassnotes.size)], inf),
        \dur, Pshuf(~bassdurations.stutter(3), inf),
        \fb, Pshuf([0.25, 0.5, 0.75].stutter(5), inf),
        \octave, 3,
        \outbus, [~delaybus, ~bassfxbus],
		\scale, ~scale,
));

Pdef(\bass2,
    Pbind(
        \instrument, \abass,
        \carrier_amp, Pshuf([4, 8, 16, 32], inf),
        \carrier_ratio, 4,
        \degree, Pseq([Pseq([0], 3), 1, Pseq([0], 5), 1, Pseq([0], 7), 1], inf),
        \dur, Pshuf(~bassdurations, inf),
        \fb, Pshuf([0.25, 0.5, 1].stutter(7), inf),
        \octave, 3,
        \outbus, [~delaybus, ~bassfxbus],
        \scale, ~scale
));
);

/*
Pdef(\bass).play(t);
Pdef(\bass).isPlaying;
Pdef(\bass).stop;
*/

/*
Pdef(\bass2).play(t, quant: 0.5);
Pdef(\bass2).isPlaying;
Pdef(\bass2).stop;
*/

// Midi Control

~midiktrl.value(\bass, 37);
~midiktrl.value(\bass2, 69);

////////////////////////////////////////////////////////
// BUFFER-STUTTER

(
SynthDef(\recbuf, { |dur = 2, gate = 1, inBus = 2, isRecording = 1, trigger = 1|
	var env				=	Env.asr(0.003, 1, 0.1);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var in				=	In.ar(inBus, b.numChannels);
	var recbuf 			=	RecordBuf.ar(in, b.bufnum, recLevel: envgen, run: isRecording, loop: 0, trigger: trigger, doneAction: 2);
}).add;
);

(
SynthDef(\bufrd, { |dur = 1, ffreq = 3000, gate = 1, level = 1, outbus, pan = 0|
	//var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.003, level, 0.1);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(b.numChannels, b.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
    var rhpf			=	RHPF.ar(bufrd, ffreq.clip(50, SampleRate.ir / 2.5), 0.3, envgen);
	var pan2			=	Pan2.ar(rhpf, pan);
	Out.ar(outbus, pan2);
}).add;
);

(
Pdef(\rbpdef,
	Pbind(
		\instrument, \recbuf,
        \inBus, ~bassfxbus,
		\dur, 3,
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
        \dur, Prand([0.25, 0.5], inf),
		\ffreq, 4000,
        \level, 1,
        \outbus, ~delaybus,
		\pan, Prand([-0.5, 0, 0.5], inf)
));
);

/*
Pdef(\pbpat).play(t, quant: 0.5);
Pdef(\pbpat).isPlaying;
Pdef(\pbpat).pause;
*/

Pdef(\buffpat, Ppar([Pdef(\rbpdef), Pdef(\pbpat)], inf));

/*
Pdef(\buffpat).play(t);
Pdef(\buffpat).isPlaying;
Pdef(\buffpat).pause;
*/

// Midi Control

~midiktrl.value(\buffpat, 53);

////////////////////////////////////////////////////////////////
// PLUNK

(
SynthDef(\plunk, { |a = 1, curve = -16, dur = 1, fb = 0, freq = 400, level = 0.1, outbus, rq = 0.3, shapelimit = 1|
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var sinfb			=	SinOscFB.ar(freq, fb);
    var cusp            =   CuspL.ar(100, [a, a - 0.001], add: 1);
    var shape			=	SineShaper.ar(sinfb, shapelimit * cusp, (shapelimit * 2).reciprocal);
    var rlpf			=	BLowPass4.ar(shape, (freq).clip(50, SampleRate.ir / 3));
    var rhpf			=	RHPF.ar(shape, (freq * 8).clip(50, SampleRate.ir / 3), rq);
    Out.ar(outbus, (rlpf + rhpf) * envgen);
}).add;
);

(
Pdef(\plunkpat1,
	Pbind(
		\instrument, \plunk,
        \a, Pshuf((5..10) / 5, inf),
        \curve, -16,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 16, 24, 32, 48], inf),
        \degree, 0,
        \fb, Pshuf(([0, 0.25, 0.5, 0.75, 1, 1.25, 1.5]), inf),
        \octave, 6,
        \outbus, [~delaybus, ~verbus],
		\scale, ~scale,
        \shapelimit, Pshuf([0.3, 0.4, 0.5, 0.6, 0.7, 0.8], inf)
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
Pdef(\plunkpat1).play(t, quant: 0.5);
Pdef(\plunkpat1).isPlaying;
Pdef(\plunkpat1).stop;
*/

/*
Pdef(\plunkpat2).play(t, quant: 0.5);
Pdef(\plunkpat2).isPlaying;
Pdef(\plunkpat2).stop;
*/

/*
Pdef(\plunkpat3).play(t, quant: 0.5);
Pdef(\plunkpat3).isPlaying;
Pdef(\plunkpat3).stop;
*/

/*
Pdef(\plunkpat4).play(t, quant: 0.5);
Pdef(\plunkpat4).isPlaying;
Pdef(\plunkpat4).stop;
*/

/*
Pdef(\plunkpat5).play(t, quant: 0.5);
Pdef(\plunkpat5).isPlaying;
Pdef(\plunkpat5).stop;
*/

/*
Pdef(\plunkpat6).play(t, quant: 0.5);
Pdef(\plunkpat6).isPlaying;
Pdef(\plunkpat6).stop;
*/

// Midi Control

~midiktrl.value(\plunkpat1, 38);
~midiktrl.value(\plunkpat2, 54);
~midiktrl.value(\plunkpat3, 70);

////////////////////////////////////////////////////////////////
// START UP THE EFFECTS

(
{
    s.sync;
    Pdef(\limiter).play(t);
    Pdef(\delay).play(t);
    Pdef(\verbs).play(t);
}.fork;
);

////////////////////////////////////////////////////////////////
// SCENES

(
~scenetoggle = { |scene, light, patterns, patternlights|
    var scenestatus;
    MIDIdef.cc(scene, {
        if(scenestatus.isNil) {
            ~midiout.control(0, light, 127);
            patternlights.do({ |l| ~midiout.noteOn(0, l, 127) });
            patterns.do({ |s| Pdef(s).play(t, quant: 0.25) });
            scenestatus = "playing";
        } {
            ~midiout.control(0, light, 0);
            patterns.do({ |s| Pdef(s).stop });
            patternlights.do({ |l| ~midiout.noteOff(0, l) });
            scenestatus = nil;
        }
    }, light, srcID: ~lpm.uid, argTemplate: { |a| a > 0 });
}
);

(
~scene1 = [\dinglepar2, \snappat, \xaos, \pads, \paddrone1, \bass, \buffpat];
~scene1lights = [32, 48, 64, 35, 51, 37, 53];
~scenetoggle.value(\scene1, 104, ~scene1, ~scene1lights);
);

(
~scene2 = [\single1, \sinprc, \larrys, \pnos, \pnochord];
~scene2lights = [33, 65, 68, 36, 52];
~scenetoggle.value(\scene2, 105, ~scene2, ~scene2lights);
);

(
~scene3 = [\single2, \cnprcpar, \cnprc3, \pads, \paddrone1, \paddrone2, \bass, \buffpat];
~scene3lights = [49, 34, 50, 35, 51, 67, 37, 53];
~scenetoggle.value(\scene3, 106, ~scene3, ~scene3lights);
);

(
~scene4 = [\dinglepar2, \cnprc3, \lori, \larrys, \pnos, \pnochord, \buffpat, \bass2, \plunkpat1, \plunkpat2, \plunkpat3];
~scene4lights = [32, 50, 66, 68, 36, 52, 53, 69, 38, 54, 70];
~scenetoggle.value(\scene4, 107, ~scene4, ~scene4lights);
);