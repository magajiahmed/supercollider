////////////////////////////////////////////////////////////////
// INIT

// clear all patterns

Pdef.removeAll;

// init

(
s.meter;
t = TempoClock(96/60);
);

(
~freezebus = Bus.audio(s, 2);
~prcfxbus = Bus.audio(s, 2);
~verbus = Bus.audio(s, 2);
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 1024/729, 3/2, 128/81, 12/7, 7/4, 512/243];
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
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~lpm.isNil) { ~lpm = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
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
// VERB

(
SynthDef(\verb, { |ffreq = 4000, freq = 1, gate = 1, inBus, level = 0.2, outBus, phase = 0, rq = 1, size = 1, t60 = 1|
    var env         =   Env.asr(0.01, level, 0.01);
    var envgen      =   EnvGen.kr(env, gate, doneAction: 2);
	var in			=	In.ar(inBus, 2);
	var verb		=	JPverb.ar(in, t60, size: size) * envgen;
    //var trigmod     =   SinOsc.ar(LFNoise2.kr(1).range(0.1, 1), phase).range(3, 120);
    var trig        =   Impulse.kr(freq * LFNoise2.kr(2!2).range(1.0, 8.0));
    var grain       =   GrainIn.ar(2, trig, 0.005, verb);
    var hipass		=	BHiPass4.ar(grain, ffreq.clip(50, SampleRate.ir / 2.5), rq.clip(0.0001, 1));
	Out.ar(outBus, hipass);
}).add;
);

(
Pdef(\verb,
    Pbind(
        \instrument, \verb,
        \dur, Prand([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
        \freq, Pwhite(1, 25, inf),
        \ffreq, Pwhite(2000, 8000, inf),
        \inBus, ~verbus,
        \outBus, ~prcfxbus,
        \phase, Pwhite(0, pi, inf),
        \rq, Pwhite(0.1, 1, inf),
        \size, 5,
        \t60, 5
));
);


/*
Pdef(\verb).play(t);
Pdef(\verb).isPlaying;
Pdef(\verb).stop;
*/

/*
(
~startverb = {
	s.sync;
	~verb = Synth(\verb, [\inBus, ~verbus, \outBus, ~prcfxbus, \size, 1, \t60, 20, \vol, 0.02]).register;
}.fork;
);
*/

/*
~verb.isPlaying;
~verb.free;
*/

////////////////////////////////////////////////////////
// FREEZE
/*
(
SynthDef(\freeze, { |gate = 1, inBus, level = 0.1|
	var env			=	Env.asr(0.005, level, 5, -16);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 2);
	//var in			=	In.ar(inBus, 2);
    var in          =   SinOsc.ar(LFNoise1.kr(5.2,250,400));
	var fft			=	FFT(LocalBuf(2048), in);
	var freeze		=	PV_MagFreeze(fft, LFNoise0.kr(0.1));
	Out.ar(0, envgen * IFFT(freeze)!2);
}).add;
);

(
Pdef(\freeze, Pbind(\instrument, \freeze, \inBus, ~freezebus));
Pdef(\freezetest, Pbind(\out, ~freezebus));
);
*/
/*
Pdef(\freeze).play(t);
Pdef(\freeze).isPlaying;
Pdef(\freeze).stop;
*/

/*
Pdef(\freezetest).play(t);
Pdef(\freezetest).isPlaying;
Pdef(\freezetest).stop;
*/

////////////////////////////////////////////////////////
// COMPANDER

(
SynthDef(\dynamix, { |inBus|
	var in	   		= 	In.ar(inBus, 2);
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.001, slopeAbove: 1/128);
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

////////////////////////////////////////////////////////////////
// PNO

(
SynthDef(\pno, { |curve = -4, dur = 1, fb = 0, fb2 = 0, fb2mul = 1, freq = 440, hffreq = 8000, level = 0.03, lffreq = 1000, rq1 = 1, rq2 = 1, sinhimul = 0|
    var env             =   Env.perc(0.001, dur + 1, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sinfb1          =   SinOscFB.ar(freq!2, fb, envgen / 4);
    var sinfb2          =   SinOscFB.ar(freq!2, fb2, envgen * fb2mul);
    //var octavelower     =   SinOsc.ar(freq!2 / 2, mul: envgen * octavelowermul);
    var sinhi           =   SinOsc.ar(freq * 11, mul: envgen * sinhimul);
    var rlpf            =   RLPF.ar(sinfb1, lffreq.clip(50, SampleRate.ir / 3), rq1);
    var rhpf            =   RHPF.ar(sinfb2, hffreq.clip(50, SampleRate.ir / 3), rq2);
    Out.ar(0, rlpf + rhpf + sinhi);
}).add;
);

(
~pnolvl = 0.03;

Pdef(\pnopulse1,
    Pbind(
        \instrument, \pno,
        \curve, -8,
        \dur, Pshuf([0.75, 1, 1.25, 1.5].stutter(2), inf),
		\fb, 0.0,
        \level, ~pnolvl,
        \degree, 0,
        \octave, 6,
        \rq1, 0.1,
        \scale, ~scale,
        \sinhimul, 0.0
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
        \fb2, Pshuf((1..5), inf),
        \fb2mul, 0.05,
        \hffreq, Pshuf((4..12) * 1000, inf),
        \level, 0.2,
        \lffreq, 5000,
        \degree, 0,
        \octave, 3,
        \octavelowermul, 1,
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

/*
(
MIDIdef.cc(\pnopulseplay, {
    if(Pdef(\pnopulse1).isPlaying.not) {
		Pdef(\pnopulse1).play(t, quant: 1);
		"pnopulse play".postln;
	}
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnopulsestop, {
    if(Pdef(\pnopulse1).isPlaying) {
		Pdef(\pnopulse1).stop;
		"pnopulse stop".postln;
	}
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pnopulse2play, {
    if(Pdef(\pnopulse2).isPlaying.not) {
		Pdef(\pnopulse2).play(t, quant: 1);
		"pnopulse2 play".postln;
	}
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnopulse2stop, {
    if(Pdef(\pnopulse2).isPlaying) {
		Pdef(\pnopulse2).stop;
		"pnopulse2 stop".postln;
	}
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pnobassplay, {
    if(Pdef(\pnobass1).isPlaying.not) {
		Pdef(\pnobass1).play(t, quant: 1);
		"pnobass play".postln;
	}
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnobassstop, {
    if(Pdef(\pnobass1).isPlaying) {
		Pdef(\pnobass1).stop;
		"pnobass stop".postln;
	}
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0);
);
*/

////////////////////////////////////////////////////////////////
// prc

(
SynthDef(\prc, { | a = 1, curve = -8, dur = 1, ffreq = 1000, freq = 1000, level = 0.2, outbus, pan = 0, releaseTime = 0.2 |
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
~prcpatlvl = 0.3;
~prcpatecholvl = ~prcpatlvl / 5;
Pdef(\prc1,
	Pbind(
		\instrument, \prc,
		\a, Pshuf([1, 2, 3, 1.1, 2.1, 3.1, 1.2, 2.2, 3.2], inf),
		//\curve, Pshuf([-2, -2, 2], inf),
		\curve, -4,
		\dur, Pshuf([0.75, 1.25, 1.75, 2, 2.25, 2.5], inf),
		\freq, Pshuf([~prcpatfrq1, ~prcpatfrq2], inf),
        \ffreq, Pkey(\freq),
		\level, ~prcpatlvl,
        \outbus, Pwrand([~prcfxbus, [~prcfxbus, ~verbus]], [4, 1].normalizeSum, inf),
		\pan, Pshuf([-0.5, -0.25, 0, 0.25, 0.5], inf),
        \releaseTime, 0.1
));

//

Pdef(\prc2,
    Pbindf(
        Pdef(\prc1),
        //\a, 3.5,
        \a, Pshuf([2.5, 3.5], inf),
		\curve, Pshuf([-16, -16, 16], inf),
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
        \dur, Pshuf([Pseq((~prc3durs * 2) - 0.25), Pseq(~prc3durs * 2), Pseq((~prc3durs * 2) + 0.25)], inf),
        //\dur, 0.25,
        \freq, ~prcpatfrq2,
        \ffreq, Pkey(\freq),
        \releaseTime, 1
));

//

Pdef(\prc4,
    Pbind(
        \instrument, \prc,
        \a, 3,
        \curve, -64,
		//\degree, Pseq([0].stutter(23) ++ [Rest].stutter(31), inf),
		\dur, Pshuf([Pseq([0.125], 2), 0.25, 0.25, 0.25, 0.5, 0.5, 0.5, 0.75, 0.75, 0.75, 1, 1, 1, 1.25, 1.25, 1.25], inf),
        \ffreq, Pshuf([10000, 20000], inf),
        //\freq, ~prcpatfrq2 * 2,
		\octave, 9,
        \outbus, Pwrand([~prcfxbus, [~prcfxbus, ~verbus]], [4, 1].normalizeSum, inf),
));

//

Pdef(\prc5,
    Pbind(
        \instrument, \prc,
        \a, Pwhite(1.8, 2.2, inf),
		\curve, -4,
		\dur, Prand([5, 5.25, 5.5], inf),
        \freq, Pseq([
            ~prcpatfrq1 * 8, ~prcpatfrq2 / 16,
            ~prcpatfrq1 * 8, ~prcpatfrq2 / 16, ~prcpatfrq2 / 16,
            ~prcpatfrq1 * 8, ~prcpatfrq2 / 16, ~prcpatfrq2 / 16, ~prcpatfrq2 / 16
        ], inf),
        \outbus, Pwrand([~prcfxbus, [~prcfxbus, ~verbus]], [4, 1].normalizeSum, inf),
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
		\dur, Prand([4.25, 4.5, 4.75, 5, 5.25, 5.5, 5.75], inf),
		\octave, 10,
        \outbus, Pwrand([~prcfxbus, [~prcfxbus, ~verbus]], [4, 1].normalizeSum, inf),
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

/*
(
MIDIdef.cc(\prc3play, {
	if(Pdef(\prc3).isPlaying.not) {
		Pdef(\prc3).play(t, quant: 1);
		"prc3 play".postln;
	};
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc3stop, {
    if(Pdef(\prc3).isPlaying) {
        Pdef(\prc3).stop;
        "prc3 stop".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prc2play, {
	if(Pdef(\prc2).isPlaying.not) {
		Pdef(\prc2).play(t, quant: 1);
		"prc2 play".postln;
	};
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc2stop, {
    if(Pdef(\prc2).isPlaying) {
        Pdef(\prc2).stop;
        "prc2 stop".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prc1play, {
	if(Pdef(\prc1).isPlaying.not) {
		Pdef(\prc1).play(t, quant: 1);
		"prc1 play".postln;
	};
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc1stop, {
    if(Pdef(\prc1).isPlaying) {
        Pdef(\prc1).stop;
        "prc1 stop".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prc4play, {
	if(Pdef(\prc4).isPlaying.not) {
		Pdef(\prc4).play(t, quant: 1);
		"prc4 play".postln;
	};
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc4stop, {
    if(Pdef(\prc4).isPlaying) {
        Pdef(\prc4).stop;
        "prc4 stop".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prc5play, {
	if(Pdef(\prc5s).isPlaying.not) {
		Pdef(\prc5s).play(t, quant: 1);
		"prc5s play".postln;
	};
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc5stop, {
    if(Pdef(\prc5s).isPlaying) {
        Pdef(\prc5s).stop;
        "prc5s stop".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prc8play, {
	if(Pdef(\prc8).isPlaying.not) {
		Pdef(\prc8).play(t, quant: 1);
		"prc8 play".postln;
	};
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc8stop, {
    if(Pdef(\prc8).isPlaying) {
        Pdef(\prc8).stop;
        "prc8 stop".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);
*/

////////////////////////////////////////////////////////////////
// PAD2

// Synth

(
SynthDef(\pad2, { | curve = -4, dur = 1, freq = 400, gate = 1, level = 0.008 |
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
	Out.ar(0, sinfb + lpf + rhpf);
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
		\level, 0.02,
        \octave, 5,
		\scale, ~scale,
));
);

/*
Pdef(\pad2pat).play(t, quant: 1);
Pdef(\pad2pat).isPlaying;
Pdef(\pad2pat).stop;
*/

Pdef(\pad2pat2, Pmono(\pad2, \degree, [-5, 0].stutter(2), \octave, 5, \scale, ~scale));
Pdef(\pad2pat3, Pmono(\pad2, \degree, [0, 12, 24, 31], \octave, 2, \scale, ~scale));

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

/*
(
MIDIdef.cc(\pad2playktrl, {
	if(Pdef(\pad2pat).isPlaying.not) {
		Pdef(\pad2pat).play(t, quant: 1);
		"pad2a play".postln;
	};
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad2stopktrl, {
    if(Pdef(\pad2pat).isPlaying) {
        Pdef(\pad2pat).stop;
        "pad2a stop".postln;
    }
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pad2bplayktrl, {
	if(Pdef(\pad2pat2).isPlaying.not) {
		Pdef(\pad2pat2).play(t, quant: 1);
		"pad2b play".postln;
	};
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad2bstopktrl, {
    if(Pdef(\pad2pat2).isPlaying) {
        Pdef(\pad2pat2).stop;
        "pad2b stop".postln;
    }
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pad2cplayktrl, {
	if(Pdef(\pad2pat3).isPlaying.not) {
		Pdef(\pad2pat3).play(t, quant: 1);
		"pad2c play".postln;
	};
}, 67, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad2cstopktrl, {
    if(Pdef(\pad2pat3).isPlaying) {
        Pdef(\pad2pat3).stop;
        "pad2c stop".postln;
    }
}, 67, srcID: ~nanoktrl2.uid, argTemplate: 0);
);
*/