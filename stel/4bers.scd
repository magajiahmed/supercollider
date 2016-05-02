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
c.free;
c = MIDIdef.cc(\ccpostln, { |...args| args.postln; });
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
SynthDef(\limiter, { |dur = 0.1, inBus, level = 0.4, outbus|
    var in          =   In.ar(inBus, 2);
    var limiter     =   Limiter.ar(in, level, dur);
    Out.ar(outbus, limiter);
}).add;
);

Pdef(\limiter, Pmono(\limiter, \dur, ~delay / 2, \inBus, ~prcfxbus, \level, 0.25, \outbus, 0));

////////////////////////////////////////////////////////
// VERB

(
SynthDef(\verb, { |dur = 1, filter_mode = 0, gate = 1, hipass_freq_min = 4000, hipass_freq_max = 8000, inBus, level = 0.5, outbus, rq = 1, size = 1, t60 = 1, trig_freq_min = 1, trig_freq_max = 100|
    //var env             =   Env.asr(0.01, level, 0.01);
    //var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var env             =   Env.perc(0.003, dur, level, 0);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
	var in		       	=	In.ar(inBus, 2);
	var verb		    =	JPverb.ar(in, t60, size: size) * envgen;
    //var trig_freq_mod   =   LFNoise2.kr(5!2).range(trig_freq_min, trig_freq_max);
    var trig_freq_mod   =   XLine.kr(trig_freq_max.clip(0.0001, SampleRate.ir), trig_freq_min.clip(0.0001, SampleRate.ir), dur);
    var trig            =   Impulse.kr(trig_freq_mod);
    var grain           =   GrainIn.ar(2, trig, 0.005, verb);
    //var filter_freq_mod =   (LFNoise2.kr(5!2).range(hipass_freq_start, hipass_freq_end)).clip(50, SampleRate.ir / 2.5);
    var filter_freq_mod =   XLine.kr(hipass_freq_min, hipass_freq_max, dur);
    //var filter		    =	BHiPass4.ar(grain, filter_freq_mod, rq.clip(0.0001, 1));
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
        //\trig_freq_min, Prand([5.0, 10.0], inf),
        //\trig_freq_max, Prand([50.0, 100.0], inf)
        \trig_freq_min, Prand([20, 80], inf),
        \trig_freq_max, Prand([20, 80], inf)
));
);

////////////////////////////////////////////////////////////////
// PNO

(
SynthDef(\pno, { |curve = -4, dur = 1, fb = 0, fb2 = 0, fb2mul = 1, freq = 440, hffreq = 8000, level = 0.1, lffreq = 1000, octavelowermul = 0, outbus, rq1 = 1, rq2 = 1, sinhimul = 0|
    var env             =   Env.perc(0.001, dur + 1, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sinfb1          =   SinOscFB.ar(freq!2, fb, envgen / 4);
    var sinfb2          =   SinOscFB.ar(freq!2, fb2, envgen * fb2mul);
    var octavelower     =   SinOsc.ar(freq!2 / 2, mul: envgen * octavelowermul);
    //var sinhi           =   SinOsc.ar(freq * 11, mul: envgen * sinhimul);
    var rlpf            =   RLPF.ar(sinfb1, lffreq.clip(50, SampleRate.ir / 3), rq1);
    var rhpf            =   RHPF.ar(sinfb2, hffreq.clip(50, SampleRate.ir / 3), rq2);
    Out.ar(outbus, octavelower + rlpf + rhpf);
}).add;
);

(
Pdef(\pnopulse1,
    Pbind(
        \instrument, \pno,
        \curve, -8,
        \dur, Pshuf([0.75, 1, 1.25, 1.5].stutter(5), inf),
		\fb, 0.0,
        \degree, 0,
        \octave, 6,
        \outbus, ~delaybus,
        \rq1, 0.1,
        \scale, ~scale,
        //\sinhimul, 0.0
));

Pdef(\pnopulse2, Pbindf(Pdef(\pnopulse1), \degree, [0, 7], \dur, Pshuf([1.75, 2, 2.25, 2.5, 2.75, 3, 3.25], inf), \fb, 0.1));
);

/*
Pdef(\pnopulse1).play(t, quant: 1);
Pdef(\pnopulse1).isPlaying;
Pdef(\pnopulse1).stop;
*/

/*
Pdef(\pnopulse2).play(t, quant: 1);
Pdef(\pnopulse2).isPlaying;
Pdef(\pnopulse2).stop;
*/

(
Pdef(\pnobass1,
    Pbind(
        \instrument, \pno,
        \curve, -8,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12].stutter(2), inf),
        \fb, 0.5,
        \fb2, Pshuf((0..2), inf),
        \fb2mul, 0.05,
        \hffreq, Pshuf((8..12) * 1000, inf),
        \level, 0.3,
        \lffreq, 5000,
        \degree, 0,
        \octave, 3,
        \octavelowermul, 0.5,
        \outbus, ~delaybus,
		\rq1, 1,
        \rq2, 0.3,
        \scale, ~scale
));
);

/*
Pdef(\pnobass1).play(t, quant: 1);
Pdef(\pnobass1).isPlaying;
Pdef(\pnobass1).stop;
*/

~midiktrl.value(\pnopulse1, 32);
~midiktrl.value(\pnopulse2, 48);
~midiktrl.value(\pnobass1, 64);

////////////////////////////////////////////////////////////////
// PRC

(
SynthDef(\prc, { | a = 1, curve = -8, dur = 1, ffreq = 1000, freq = 1000, level = 0.4, outbus, pan = 0, releaseTime = 0.2 |
	var env				=	Env.perc(releaseTime: releaseTime, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq, a, add: 1);
	var lfn				=	LFNoise0.ar(15).range(0, 1);
	var sin				=	SinOsc.ar(freq * cusp, pi / 2, envgen);
	var sin2			=	sin.round(0.01) / 2;
    var rez				=	Resonz.ar(sin, ffreq.clip(50, SampleRate.ir / 2), 0.05, 4);
    var pan2			=	Pan2.ar(sin2 + rez, pan).fold2(1);
	Out.ar(outbus, pan2);
}).add;
);

(
~prcpatfrq1 = 90;
~prcpatfrq2 = ~prcpatfrq1 * 32;
~prcpatlvl = 0.4;
~prcpatecholvl = ~prcpatlvl / 5;
Pdef(\prc1,
	Pbind(
		\instrument, \prc,
		\a, Pshuf([1, 2, 3, 1.1, 2.1, 3.1, 1.2, 2.2, 3.2], inf),
		//\curve, Pshuf([-2, -2, 2], inf),
		\curve, -4,
        \dur, Pshuf([Pseq([0.125], 2), 0.75, 1.25, 1.75, 2, 2.25, 2.5], inf),
		\freq, Pshuf([~prcpatfrq1, ~prcpatfrq2], inf),
        \ffreq, Pkey(\freq),
		\level, ~prcpatlvl,
        //\outbus, Pwrand([~prcfxbus, [~prcfxbus, ~verbus]], [2, 1].normalizeSum, inf),
        \outbus, Pshuf([~prcfxbus, [~prcfxbus, ~verbus]].stutter(13), inf),
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

~prc3durs = [1, 1.5, 1, 1, 1.5, 1, 1, 1, 1.5];
Pdef(\prc3,
    Pbindf(
        Pdef(\prc1),
        \a, Pwhite(2.99, 3.01, inf),
        \curve, -16,
        \dur, Pseq([Pseq([1/12], 3), Pseq((~prc3durs * 2) - 0.25), Pseq(~prc3durs * 2), Pseq((~prc3durs * 2) + 0.25)], inf),
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
		\octave, 9,
        \outbus, Pshuf([~prcfxbus, [~prcfxbus, ~verbus]], inf),
));

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
        \outbus, Pshuf([~prcfxbus, [~prcfxbus, ~verbus]], inf),
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
        \outbus, Pshuf([~prcfxbus, [~prcfxbus, ~verbus]], inf),
));

//

Pdef(\prc7,
	Pbindf(
		Pdef(\prc6),
		\octave, 9
));

Pdef(\prc8, Ppar([Pdef(\prc6), Pdef(\prc7)], inf));
);

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
~midiktrl.value(\prc5, 50);
~midiktrl.value(\prc8, 66);

////////////////////////////////////////////////////////////////
// PAD2

// Synth

(
SynthDef(\pad2, { |curve = -4, dur = 1, freq = 400, gate = 1, level = 0.01, outbus|
	var env				=	Env.asr(3, level, 7, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var filtmulmods		=	LFBrownNoise0.kr(15!4).range(0.25, 1).round(0.25);
	var saw1freqmod		=	LFNoise1.kr(0.1!2, 0.001, 1);
	var saw0			=	LFSaw.ar(freq!2, mul: envgen / 2);
	var saw1			=	LFSaw.ar(freq * saw1freqmod, mul: envgen / 2);
	var sawmix			=	saw0 + saw1;
	var bn				=	LFNoise2.ar(0.1!2, 0.1);
	var kbnshaper		=	LFBrownNoise1.kr(15.dup).range(0.5, 2);
	var shape			=	(sawmix + bn).fold2(0.002 * kbnshaper) * 5;
    var sinfb           =   SinOscFB.ar(freq!2, 0.1, envgen);
	var lpf				=	BLowPass4.ar(sawmix + shape, freq * 1.125, mul: filtmulmods[0, 1]);
	var rhpf			=	BHiPass4.ar(sawmix + shape, 6000, 0.05, filtmulmods[2, 3]);
	Out.ar(outbus, sinfb + lpf + rhpf);
}).add;
);

// Pattern

(
~padchords2 = ~scaledegrees.collect({ |i| [2, 7, 10, 12, i, i + 2, i + 7, i + 10, i + 12] });
~padchords2shuf = ~padchords2.scramble;

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
        //\dur, Pshuf((23..28)),
        \dur, 23,
        \legato, 0.75,
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

Pdef(\pad2pat2, Pmono(\pad2, \degree, [7, 12].stutter(2), \octave, 4, \outbus, ~delaybus, \scale, ~scale));
Pdef(\pad2pat3, Pmono(\pad2, \degree, [0].stutter(5), \level, 0.0001, \octave, 8, \outbus, ~delaybus, \scale, ~scale));

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

~midiktrl.value(\pad2pat, 35);
~midiktrl.value(\pad2pat2, 51);
~midiktrl.value(\pad2pat3, 67);

// Start the effects
(
{
    s.sync;
    Pdef(\delay).play;
    Pdef(\limiter).play;
    Pdef(\verb).play;
}.fork;
);