////////////////////////////////////////////////////////////////
// INIT

// clear environment

currentEnvironment.clear;

// clear all patterns

Pdef.removeAll;

// init

(
t = TempoClock(80/60);
);

(
~delay = 0.1;
~delaybus = Bus.audio(s, 2);
~nullbus = Bus.audio(s, 2);
~prcfxbus = Bus.audio(s, 2);
~verbus = Bus.audio(s, 2);
~ratios = [1/1, 16/15, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 5/3, 7/4, 15/8];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
);

// midi
(
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
MIDIdef.cc(\midiccpostln, { |...args| args.postln });
MIDIdef.noteOn(\midinoteonpostln, { |...args| args.postln });
~lpm = MIDIClient.sources.detect{ |a| a.name.contains("Launchpad") };
);

(
~midiout = MIDIOut(0);
~midiout.connect(~lpm.uid);
);

(
~midiktrl = { |pdef, note|
    MIDIdef.noteOn(pdef, {
        if(Pdef(pdef).isPlaying.not) {
            ~midiout.noteOn(0, note, 127);
            Pdef(pdef).play(t);
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


////////////////////////////////////////////////////////
// RECORDING

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////
// DELAY ///////////////////////////////////////////////
// (to compensate for limiter delay ////////////////////

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
// LIMITER

(
SynthDef(\limiter, { |dur = 0.1, inBus, level = 0.3, outbus|
    var in          =   In.ar(inBus, 2);
    var limiter     =   Limiter.ar(in, level, dur);
    Out.ar(outbus, limiter);
}).add;
);

Pdef(\limiter, Pmono(\limiter, \dur, ~delay / 2, \inBus, ~prcfxbus, \level, 0.3, \outbus, 0));

////////////////////////////////////////////////////////
// VERB

(
SynthDef(\verb, { |dur = 1, filter_mode = 0, gate = 1, hipass_freq_min = 4000, hipass_freq_max = 8000, inBus, level = 0.5, outbus, rq = 1, size = 1, t60 = 1, trig_freq_min = 1, trig_freq_max = 100|
    var env             =   Env.perc(0.003, dur, level, 0);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
	var in		       	=	In.ar(inBus, 2);
	var verb		    =	JPverb.ar(in, t60, size: size) * envgen;
    var trig_freq_mod   =   XLine.kr(trig_freq_max.clip(0.0001, SampleRate.ir), trig_freq_min.clip(0.0001, SampleRate.ir), dur);
    var trig            =   Impulse.kr(trig_freq_mod);
    var grain           =   GrainIn.ar(2, trig, 0.005, verb);
    var filter_freq_mod =   XLine.kr(hipass_freq_min, hipass_freq_max, dur);
    var filter          =   BMoog.ar(grain, filter_freq_mod.clip(50, SampleRate.ir / 2.5), 0.2, filter_mode);
	Out.ar(outbus, filter);
}).add;
);

(
Pdef(\verb,
    Pbind(
        \instrument, \verb,
        \addAction, 0,
        //\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24], inf),
        \dur, Pshuf([1, 2].stutter(7), inf),
        //\freq, Pwhite(10, 50, inf),
        //\ffreq, Pwhite(2000, 6000, inf),
        \filter_mode, Pshuf([0, 1, 2].stutter(7), inf),
        \hipass_freq_min, Prand([1000, 4000, 8000], inf),
        \hipass_freq_max, Prand([1000, 4000, 8000], inf),
        \inBus, ~verbus,
        \outbus, ~prcfxbus,
        \rq, Pwhite(0.1, 1, inf),
        \size, 5,
        \t60, 5,
        \trig_freq_min, Prand([20, 80], inf),
        \trig_freq_max, Prand([20, 80], inf)
));
);

////////////////////////////////////////////////////////////////
// PNO & SIN

/*
(
SynthDef(\pno, { |curve = -4, dur = 1, fb = 0, fb2 = 0, fb2mul = 1, freq = 440, hffreq = 8000, level = 0.1, lffreq = 1000, octavelowermul = 0, outbus, rq1 = 1, rq2 = 1|
    var env             =   Env.perc(0.001, dur + 1, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sinfb1          =   SinOscFB.ar(freq!2, fb, envgen / 4);
    var sinfb2          =   SinOscFB.ar(freq!2, fb2, envgen * fb2mul);
    var octavelower     =   SinOsc.ar(freq!2 / 2, mul: envgen * octavelowermul);
    var rlpf            =   RLPF.ar(sinfb1, lffreq.clip(50, SampleRate.ir / 3), rq1);
    var rhpf            =   RHPF.ar(sinfb2, hffreq.clip(50, SampleRate.ir / 3), rq2);
    Out.ar(outbus, octavelower + rlpf + rhpf);
}).add;
);
*/

(
SynthDef(\pno, { |balance = 0.25, curve = -4, dur = 1, fold = 1, freq = 440, freqmod_amp_start = 1, freqmod_amp_end = 0, freqmod_dur = 0.2, k = 1, level = 0.03, outbus|
	var env         =   Env.perc(0.005, dur, level, curve);
	var envgen      =   EnvGen.kr(env, doneAction: 2);
	var freqmod     =   StandardL.ar(2000, [k - 0.02, k + 0.02], mul: XLine.kr(freqmod_amp_start + 0.0000001, freqmod_amp_end + 0.0000001, freqmod_dur), add: 1);
	var sin1        =   SinOsc.ar(freq * freqmod).fold2(fold) * fold.reciprocal * envgen * balance;
	var rhpf        =   RHPF.ar(sin1, (freq * 8).clip(50, SampleRate.ir / 2.5));
	var sin2        =   SinOsc.ar(freq * LFNoise2.kr(0.5 ! 2, 0.001, 1)) * envgen * (1 - balance);
	Out.ar(outbus, (rhpf + sin2).fold2(level));
}).add;
);

/*
(
SynthDef(\sin, { |freq = 440, gate = 1, level = 0.0, outbus|
    var env             =   Env.asr(0.01, level, 0.1);
	var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
	var sin             =   SinOsc.ar(freq ! 2, mul: envgen);
	Out.ar(outbus, sin);
}).add;
);
*/

//

(
Pdef(\pno1,
    Pbind(
        \instrument, \pno,
		\balance, 1/3,
        \curve, -32,
        \degree, [12].stutter(4),
		\dur, 23,
		\fold, Pshuf(Array.interpolation(11, 0.01, 0.1), inf),
		\freqmod_amp_start, Pshuf([1, 2, 3, 4, 5, 6, 7], inf),
		\freqmod_amp_end, Pshuf([0.125, 0.25], inf),
		\freqmod_dur, Pshuf([0.005, 0.01, 0.02, 0.04], inf),
		\k, Pshuf(Array.interpolation(5, 0.9, 4.0), inf),
		//\level, 0.1,
		\octave, 5,
        \outbus, ~delaybus,
        \scale, ~scale,
	));

Pdef(\pno2, Pbindf(Pdef(\pno1), \degree, [10].stutter(4), \dur, 23.25));

Pdef(\pno3, Pbindf(Pdef(\pno1), \degree, [14].stutter(4), \dur, 23.5));

Pdef(\pno4, Pbindf(Pdef(\pno1), \degree, [7].stutter(4), \dur, 23.75));
);

(
Pdef(\pnoprepulse,
	Pbindf(
		Pdef(\pno1),
		\balance, 0.5,
		\curve, -2,
		\dur, Pshuf([0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
		\fold, Pshuf(Array.interpolation(7, 0.005, 0.05), inf),
		\freqmod_amp_end, 0.001,
		\level, 0.01,
		\octave, 4
	));

Pdef(\pnopulse, Pbindf(Pdef(\pnoprepulse), \dur, Pshuf([0.5, 0.75, 1, 1.5].stutter(13), inf)));
);

//

/*
(
Pdef(\sin1,
	Pbind(
		\instrument, \sin,
		\degree, 12,
		\dur, 46,
		\legato, 0.25,
		\octave, 4,
		\releaseTime, 0.1,
		\scale, ~scale
	));

Pdef(\sin2, Pbindf(Pdef(\sin1), \degree, 10));

Pdef(\sin3, Pbindf(Pdef(\sin1), \degree, 14));

Pdef(\sin4, Pbindf(Pdef(\sin1), \degree, 7));
);
*/

/*
Pdef(\pno1).play(t);
Pdef(\pno1).isPlaying;
Pdef(\pno1).stop;
*/

/*
Pdef(\pno2).play(t);
Pdef(\pno2).isPlaying;
Pdef(\pno2).stop;
*/

/*
Pdef(\pno3).play(t);
Pdef(\pno3).isPlaying;
Pdef(\pno3).stop;
*/

/*
Pdef(\pno4).play(t);
Pdef(\pno4).isPlaying;
Pdef(\pno4).stop;
*/

/*
Pdef(\pnoprepulse).play(t);
Pdef(\pnoprepulse).isPlaying;
Pdef(\pnoprepulse).stop;
*/

/*
Pdef(\pnopulse).play(t);
Pdef(\pnopulse).isPlaying;
Pdef(\pnopulse).stop;
*/

/*
Pdef(\sin1).play(t);
Pdef(\sin1).isPlaying;
Pdef(\sin1).stop;
*/

/*
Pdef(\sin2).play(t);
Pdef(\sin2).isPlaying;
Pdef(\sin2).stop;
*/

/*
Pdef(\sin3).play(t);
Pdef(\sin3).isPlaying;
Pdef(\sin3).stop;
*/

/*
Pdef(\sin4).play(t);
Pdef(\sin4).isPlaying;
Pdef(\sin4).stop;
*/

(
Pdef(\pnobass1,
    Pbind(
        \instrument, \pno,
		\balance, Pshuf([0, 0.125, 0.25, 0.5], inf),
        \curve, -8,
        \degree, [0].stutter(2),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12].stutter(2), inf),
		\fold, Pshuf([0.1, 0.2, 0.3, 0.4, 0.5], inf),
        \octave, [2, 3],
        \outbus, ~delaybus,
        \scale, ~scale,
		\freqmod_amp_start, Pshuf([1, 2, 3, 4, 5, 6, 7], inf),
		\freqmod_amp_end, Pshuf([0.125, 0.25], inf),
		\freqmod_dur, Pshuf([0.005, 0.01, 0.02, 0.04], inf),
		\k, Pshuf(Array.interpolation(5, 0.9, 4.0), inf),
));
);

/*
Pdef(\pnobass1).play(t, quant: 1);
Pdef(\pnobass1).isPlaying;
Pdef(\pnobass1).stop;
*/

~midiktrl.value(\pnoprepulse, 0);
~midiktrl.value(\pnopulse, 16);
~midiktrl.value(\pno1, 32);
~midiktrl.value(\pno2, 48);
~midiktrl.value(\pno3, 64);
~midiktrl.value(\pno4, 80);

//

/*
~midiktrl.value(\sin1, 112);
~midiktrl.value(\sin2, 113);
~midiktrl.value(\sin3, 114);
~midiktrl.value(\sin4, 115);
*/

//

~midiktrl.value(\pnobass1, 96);

////////////////////////////////////////////////////////////////
// PRC

(
SynthDef(\prc, { | a = 1, curve = -8, dur = 1, ffreq = 1000, freq = 1000, level = 0.25, outbus, pan = 0, releaseTime = 0.2, rq = 0.05 |
	var env				=	Env.perc(releaseTime: releaseTime, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq, a, add: 1);
	var lfn				=	LFNoise0.ar(15).range(0, 1);
	var sin				=	SinOsc.ar(freq * cusp, pi / 2, envgen);
	var sin2			=	sin.round(0.01) / 2;
    var rez				=	Resonz.ar(sin, ffreq.clip(50, SampleRate.ir / 2), rq, 4);
    var pan2			=	Pan2.ar(sin2 + rez, pan).fold2(1);
	Out.ar(outbus, pan2);
}).add;
);

(
~prcpatfrq1 = 90;
~prcpatfrq2 = ~prcpatfrq1 * 32;
~prcpatlvl = 0.35;
~prcpatecholvl = ~prcpatlvl / 5;
Pdef(\prc1,
	Pbind(
		\instrument, \prc,
		\a, Pshuf([1, 2, 3, 1.1, 2.1, 3.1, 1.2, 2.2, 3.2], inf),
		\curve, -4,
        \dur, Pshuf([Pseq([0.125], 2), 0.75, 1.25, 1.75, 2, 2.25, 2.5], inf),
		\freq, Pshuf([~prcpatfrq1, ~prcpatfrq2], inf),
        \ffreq, Pkey(\freq),
		\level, ~prcpatlvl,
        \outbus, Pshuf([~prcfxbus, ~prcfxbus, ~prcfxbus, [~prcfxbus, ~verbus]].stutter(13), inf),
		\pan, Pshuf([-0.5, -0.25, 0, 0.25, 0.5], inf),
        \releaseTime, 0.1
));

//

Pdef(\prc2,
    Pbindf(
        Pdef(\prc1),
        //\a, 3.5,
        \a, Pshuf([2.5, 3.5], inf),
		\curve, -16,
        \freq, ~prcpatfrq2 * 2,
        \ffreq, Pkey(\freq),
		\releaseTime, 0.05
));

//

~prc3durs = [2, 3, 2, 2, 3, 2, 2, 2, 3];
Pdef(\prc3,
    Pbindf(
        Pdef(\prc1),
        \a, Pshuf([2.95, 3.0, 3.05].stutter(3), inf),
        \curve, Pshuf([-64, -16, -4].stutter(5), inf),
        \dur, Pseq([Pseq([1/12], 3), Pseq((~prc3durs) - 0.25), Pseq(~prc3durs), Pseq((~prc3durs) + 0.25)], inf),
        \freq, ~prcpatfrq2,
        \ffreq, Pkey(\freq),
        \releaseTime, 1
));

//

Pdef(\prc4,
    Pbind(
        \instrument, \prc,
        \a, Pshuf([2.95, 3, 3.05].stutter(11), inf),
        \curve, Pshuf([-64, -16, -4].stutter(13), inf),
		\dur, Pshuf([Pseq([1/12], 3), 0.25, 0.25, 0.25, 0.5, 0.5, 0.5, 0.75, 0.75, 0.75, 1, 1, 1, 1.25, 1.25, 1.25], inf),
        \ffreq, Pshuf([10000, 20000], inf),
        \level, ~prcpatlvl * 0.5,
		\octave, 9,
        \outbus, Pshuf([~prcfxbus, ~prcfxbus, ~prcfxbus, [~prcfxbus, ~verbus]], inf),
	));

Pdef(\prc4a, Pbindf(Pdef(\prc4), \curve, Prand([-64, -16], inf), \dur, 0.125, \level, Prand([0.2, 1] * ~prcpatlvl * 0.5, inf));

//

Pdef(\prc5,
    Pbind(
        \instrument, \prc,
        \a, Pwhite(1.8, 2.2, inf),
		\curve, -4,
        \dur, Pshuf([Pseq([28, 1, 1] / 6), 5.25, 5.5, 5.75, 6], inf),
        \freq, Pseq([
            ~prcpatfrq1 * 8, ~prcpatfrq2 / 16,
            ~prcpatfrq1 * 8, ~prcpatfrq2 / 16, ~prcpatfrq2 / 16,
            ~prcpatfrq1 * 8, ~prcpatfrq2 / 16, ~prcpatfrq2 / 16, ~prcpatfrq2 / 16
        ], inf),
        \outbus, Pshuf([~prcfxbus, ~prcfxbus, ~prcfxbus, [~prcfxbus, ~verbus]], inf),
		\releaseTime, 0.05
));

Pdef(\prc5a, Pbindf(Pdef(\prc5), \dur, Prand([1.25, 1.5, 1.75], inf), \level, 0.03));

Pdef(\prc5s, Ppar([Pdef(\prc5), Pdef(\prc5a)]));

//

Pdef(\prc6,
	Pbind(
		\instrument, \prc,
		\a, Pwhite(0.99, 1.01, inf),
		\curve, -16,
        \dur, Prand([4.25, 4.5, 4.75, 5, 5.25, 5.5, 5.75, Pseq([94, 1, 1] / 16)], inf),
		\octave, 10,
        \outbus, Pshuf([~prcfxbus, ~prcfxbus, ~prcfxbus, [~prcfxbus, ~verbus]], inf),
));

//

Pdef(\prc7,
	Pbindf(
		Pdef(\prc6),
		\octave, 9
));

Pdef(\prc8, Ppar([Pdef(\prc6), Pdef(\prc7)], inf));

/*
Pdef(\prc1).play(t, quant: 1);
Pdef(\prc1).isPlaying;
Pdef(\prc1).stop;
*/

/*
Pdef(\prc2).play(t, quant: 1);
Pdef(\prc2).isPlaying;
Pdef(\prc2).stop;
*/

/*
Pdef(\prc3).play(t, quant: 1);
Pdef(\prc3).isPlaying;
Pdef(\prc3).stop;
*/

/*
Pdef(\prc4).play(t, quant: 1);
Pdef(\prc4).isPlaying;
Pdef(\prc4).stop;
*/

/*
Pdef(\prc4a).play(t, quant: 1);
Pdef(\prc4a).isPlaying;
Pdef(\prc4a).stop;
*/

/*
Pdef(\prc5).play(t, quant: 1);
Pdef(\prc5).isPlaying;
Pdef(\prc5).stop;
*/

/*
Pdef(\prc5a).play(t, quant: 1);
Pdef(\prc5a).isPlaying;
Pdef(\prc5a).stop;
*/

/*
Pdef(\prc5s).play(t, quant: 1);
Pdef(\prc5s).isPlaying;
Pdef(\prc5s).stop;
*/

/*
Pdef(\prc6).play(t, quant: 1);
Pdef(\prc6).isPlaying;
Pdef(\prc6).stop;
*/

/*
Pdef(\prc7).play(t, quant: 1);
Pdef(\prc7).isPlaying;
Pdef(\prc7).stop;
*/

/*
Pdef(\prc8).play(t, quant: 1);
Pdef(\prc8).isPlaying;
Pdef(\prc8).stop;
*/

~midiktrl.value(\prc3, 33);
~midiktrl.value(\prc2, 49);
~midiktrl.value(\prc1, 65);
~midiktrl.value(\prc4, 34);
~midiktrl.value(\prc4a, 18);
~midiktrl.value(\prc5, 50);
~midiktrl.value(\prc8, 66);

////////////////////////////////////////////////////////////////
// PRC2

(
SynthDef(\sinprc, { |curve = -4, ffreq = 1000, freq = 1000, level = 0.05, nfreq = 1000, nmul_start = 0.5, nmul_end = 0.05, outbus, releaseTime = 1, rq = 1|
	var env             =    Env.perc(0.005, releaseTime, level, curve);
	var envgen          =    EnvGen.kr(env, doneAction: 2);
	var noiz            =    LFClipNoise.ar(nfreq ! 2, XLine.kr(nmul_start, nmul_end, releaseTime * 0.5), 1);
	var sin             =    SinOsc.ar(freq * noiz).fold2(0.1) * 10 * envgen;
	var rhpf            =    RHPF.ar(sin, ffreq.clip(50, SampleRate.ir / 2.5), rq.clip(0.000001, 1));
	var ampmod          =    LFClipNoise.kr(50 ! 2).range(2/3, 1);
	Out.ar(outbus, rhpf * ampmod);
}).add;
);

(
Pdef(\sinprc,
	Pbind(
		\instrument, \sinprc,
		\curve, -4,
		\degree, Pseq([Rest, Pseq([[2, 7, 10, 12]], inf)]),
        \dur, Pshuf([0.125, 0.125, 0.25, 0.5, Pseq([5, 1, 1, 1] / 8), 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
		\ffreq, Pshuf(Array.interpolation(17, 200, 2000), inf),
		\nfreq, Pshuf(Array.interpolation(12, 50, 500), inf),
		\nmul_start, Pshuf(Array.interpolation(13, 0.002, 0.02), inf),
		\nmul_end, Pshuf(Array.interpolation(11, 0.002, 0.02), inf),
		\octave, 5,
		\outbus, ~prcfxbus,
		\releaseTime, Pkey(\dur),
		\rq, Pshuf(Array.interpolation(7, 0.3, 1.0), inf),
		\scale, ~scale
	));
);

/*
Pdef(\sinprc).play(t, quant: 1);
Pdef(\sinprc).isPlaying;
Pdef(\sinprc).stop;
*/

~midiktrl.value(\sinprc, 82);

////////////////////////////////////////////////////////////////
// PAD2

// Synth

(
SynthDef(\pad2, { |attack = 0.3, dur = 1, freq = 400, gate = 1, level = 0.05, outbus, release = 7|
	var env				=	Env.asr(attack, level, release, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var fm              =   SinOsc.ar(freq * SinOsc.ar(freq + [-0.1, 0.1], mul: 2, add: 1)).round(0.1).round(0.2).round(0.3).round(0.4).round(0.5) * envgen;
	var foldmod         =   SinOsc.ar(freq * LFNoise2.kr(0.2 ! 2, 0.002, 1)).range(0.05, 0.1);
	var shape			=	LeakDC.ar(fm.fold2(foldmod) * foldmod.reciprocal) * envgen;
	var lpf             =   MoogFF.ar(shape, (freq * 1.5).clip(50, SampleRate.ir / 2.5), 0.01);
	var rhpf			=	BHiPass4.ar(shape, (freq * 8).clip(50, SampleRate.ir / 2.5), 0.5);
	Out.ar(outbus, lpf + rhpf);
}).add;
);

// Pattern

(
~padchords2shuf = [6, 5, 7, 4, 8, 3, 9, 2, 10, 1, 11, 0].collect({ |c| [2, 7, 10, 12, c + 2, c + 7, c + 10, c + 12] });
//~padchords2shuf = [6, 5, 7, 4, 8, 3, 9, 2, 10, 1, 11, 0].collect({ |c| [-2, 0, 2, 7, c - 2, c + 0, c + 2, c + 7] });

Pdef(\pad2pat,
	Pbind(
		\instrument, \pad2,
		\degree, Pseq([
            ~padchords2shuf[0], Rest,
            ~padchords2shuf[1], ~padchords2shuf[2], Rest,
            ~padchords2shuf[3], ~padchords2shuf[4], ~padchords2shuf[5], Rest,
            ~padchords2shuf[6], ~padchords2shuf[7], ~padchords2shuf[8], Rest,
            ~padchords2shuf[9], ~padchords2shuf[10], Rest,
            ~padchords2shuf[11], Rest,
		]),
		\dur, 23,
		\fb, 1.5,
        \legato, 0.75,
		\level, 0.07,
        \octave, 5,
        \outbus, ~delaybus,
		\scale, ~scale,
));
);

/*
Pdef(\pad2pat).play(t, quant: 1);
Pdef(\pad2pat).isPlaying;
Pdef(\pad2pat).stop;
*/

(
Pdef(\pad2pat2,
	PmonoArtic(
		\pad2,
		\degree, [7, 12],
		\dur, 23,
		\legato, 1,
		\octave, 3,
		\outbus, ~delaybus,
		\scale, ~scale,
	));

Pdef(\pad2pat3,
	PmonoArtic(
		\pad2,
		\degree, 0,
		\dur, 23,
		\legato, 1,
		\octave, [2, 3],
		\outbus, ~delaybus,
		\scale, ~scale
	));

Pdef(\pad2hi, Pmono(\pad2, \degree, 0, \level, 0.02, \octave, 8, \outbus, ~delaybus, \scale, ~scale));
);

/*
Pdef(\pad2pat2).play(t, quant: 1);
Pdef(\pad2pat2).isPlaying;
Pdef(\pad2pat2).stop;
*/

/*
Pdef(\pad2pat3).play(t, quant: 1);
Pdef(\pad2pat3).isPlaying;
Pdef(\pad2pat3).stop;
*/

// Midi Control

~midiktrl.value(\pad2hi, 19);
~midiktrl.value(\pad2pat, 35);
~midiktrl.value(\pad2pat2, 51);
~midiktrl.value(\pad2pat3, 67);

// Making a scene

(
~scenetoggle = { |scene, light, starters, stoppers, starterlights, stopperlights|
    var scenestatus;
    MIDIdef.cc(scene, {
        if(scenestatus.isNil) {
            ~midiout.control(0, light, 127);
            starterlights.do({ |l| ~midiout.noteOn(0, l, 127) });
            starters.do({ |s| Pdef(s).play(t) });
            stopperlights.do({ |l| ~midiout.noteOff(0, l) });
            stoppers.do({ |s| Pdef(s).stop });
            scenestatus = "playing";
            scene.asString.post;
            " play".postln;
        } {
            ~midiout.control(0, light, 0);
            starters.do({ |s| Pdef(s).stop });
            starterlights.do({ |l| ~midiout.noteOff(0, l) });
            scenestatus = nil;
            scene.asString.post;
            " stop".postln;
        }
    }, light, srcID: ~lpm.uid, argTemplate: { |a| a > 0 });
}
);

(
~scenetoggle2 = { |scene, light, starters, stoppers, starterlights, stopperlights|
    var scenestatus;
    MIDIdef.noteOn(scene, {
        if(scenestatus.isNil) {
            ~midiout.noteOn(0, light, 127);
            starterlights.do({ |l| ~midiout.noteOn(0, l, 127) });
            starters.do({ |s| Pdef(s).play(t) });
            stopperlights.do({ |l| ~midiout.noteOff(0, l) });
            stoppers.do({ |s| Pdef(s).stop });
            scenestatus = "playing";
            scene.asString.post;
            " play".postln;
        } {
            ~midiout.noteOn(0, light, 0);
            starters.do({ |s| Pdef(s).stop });
            starterlights.do({ |l| ~midiout.noteOff(0, l) });
            scenestatus = nil;
            scene.asString.post;
            " stop".postln;
        }
    }, light, srcID: ~lpm.uid, argTemplate: { |a| a > 0 });
}
);

//

(
~scene2 = [\pnoprepulse, \pno1, \pad2pat2];
~scene2lights = [0, 32, 51];
~scenetoggle.value(\scene2, 105, ~scene2, starterlights: ~scene2lights);
);

(
~scene3 = [\prc3, \pad2pat];
~scene3lights = [33, 35];
~scenetoggle.value(\scene3, 106, ~scene3, starterlights: ~scene3lights);
);

(
~scene4 = [\prc2];
~scene4lights = [49];
~scene4stoppers = [];
~scene4stopperlights = [];
~scenetoggle.value(\scene4, 107, ~scene4, ~scene4stoppers, ~scene4lights, ~scene4stopperlights);
);

(
~scene5 = [\prc1];
~scene5lights = [65];
~scene5stoppers = [\pad2pat2];
~scene5stopperlights = [51];
~scenetoggle.value(\scene5, 108, ~scene5, ~scene5stoppers, ~scene5lights, ~scene5stopperlights);
);

(
~scene6 = [\pno2, \prc4, \pad2pat2];
~scene6lights = [48, 34, 51];
~scene6stoppers = [];
~scene6stopperlights = [];
~scenetoggle.value(\scene6, 109, ~scene6, ~scene6stoppers, ~scene6lights, ~scene6stopperlights);
);

(
~scene7 = [\prc5];
~scene7lights = [50];
~scene7stoppers = [\pad2pat2];
~scene7stopperlights = [51];
~scenetoggle.value(\scene7, 110, ~scene7, starterlights: ~scene7lights);
);

(
~scene8 = [\prc8];
~scene8lights = [66];
~scene8stoppers = [];
~scene8stopperlights = [];
~scenetoggle.value(\scene8, 111, ~scene8, ~scene8stoppers, ~scene8lights, ~scene8stopperlights);
);

(
~scene9 = [\pno3, \pnopulse, \pnobass1, \prc4a, \sinprc, \pad2pat3, \pad2hi];
~scene9lights = [64, 16, 96, 18, 82, 67, 19];
~scene9stoppers = [\prc3];
~scene9stopperlights = [33];
~scenetoggle2.value(\scene9, 8, ~scene9, ~scene9stoppers, ~scene9lights, ~scene9stopperlights);
);

(
~scene10stoppers = [\prc2];
~scene10stopperlights = [49];
~scenetoggle2.value(\scene10, 24, stoppers: ~scene10stoppers, stopperlights: ~scene10stopperlights)
);

(
~scene11 = [];
~scene11lights = [];
~scene11stoppers = [\prc1];
~scene11stopperlights = [65];
~scenetoggle2.value(\scene11, 40, ~scene11, ~scene11stoppers, ~scene11lights, ~scene11stopperlights);
);

(
~scene12 = [\pno4];
~scene12lights = [80];
~scene12stoppers = [\prc4, \prc4a];
~scene12stopperlights = [34, 18];
~scenetoggle2.value(\scene12, 56, ~scene12, ~scene12stoppers, ~scene12lights, ~scene12stopperlights);
);

(
~scene13 = [];
~scene13lights = [];
~scene13stoppers = [\prc5];
~scene13stopperlights = [50];
~scenetoggle2.value(\scene13, 72, ~scene11, ~scene13stoppers, ~scene13lights, ~scene13stopperlights);
);

(
~scene14stoppers = [\prc8];
~scene14stopperlights = [66];
~scenetoggle2.value(\scene14, 88, stoppers: ~scene14stoppers, stopperlights: ~scene14stopperlights);
);

(
~scene15stoppers = [\pno1, \pno2, \pno3, \pno4, \pnoprepulse, \pnopulse, \sinprc, \pad2pat, \pad2pat3];
~scene15stopperlights = [32, 48, 64, 80, 0, 16, 16, 82, 35, 67];
~scenetoggle2.value(\scene15, 104, stoppers: ~scene15stoppers, stopperlights: ~scene15stopperlights);
);

(
~scene16stoppers = [\pnobass1, \pad2hi];
~scene16stopperlights = [96, 19];
~scenetoggle2.value(\scene16, 120, stoppers: ~scene16stoppers, stopperlights: ~scene16stopperlights);
);

// Start the effects
(
{
    s.sync;
    Pdef(\delay).play;
    Pdef(\limiter).play;
    Pdef(\verb).play;
}.fork;
);