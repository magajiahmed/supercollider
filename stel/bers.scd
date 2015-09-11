////////////////////////////////////////////////////////////////
// INIT

// clear all patterns

Pdef.removeAll;

( //midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { |...args| args.postln; });
~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("nanoKONTROL2")};
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~nanoktrl2.isNil) { ~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
);

(
s.meter;
t = TempoClock(96/60);
);

(
~prcfxbus = Bus.audio(s, 2);
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 7/5, 3/2, 128/81, 12/7, 7/4, 512/243];
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

////////////////////////////////////////////////////////
// COMPANDER

(
SynthDef(\dynamix, { |inBus|
	var in	   		= 	In.ar(inBus, 2);
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.001, slopeAbove: 1/128); // compressor
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
SynthDef(\pno, { |curve = -4, dur = 1, fb = 0, fb2 = 0, fb2mul = 1, freq = 440, hffreq = 8000, level = 0.1, lffreq = 1000, rq1 = 1, rq2 = 1, sinhimul = 0|
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
~pnopulselvl = ~pnolvl / 4;
~pnodurs = [1, 1, 1.5, 1, 1, 1, 1.5, 1, 1, 1, 1, 1.5];

Pdef(\pnopulse1,
    Pbind(
        \instrument, \pno,
        \curve, -8,
        //\dur, Pshuf(~pnodurs, inf),
        \dur, Pshuf([0.75, 1, 1.25, 1.5].stutter(2), inf),
		\fb, 0,
        \level, ~pnopulselvl,
        \degree, 0,
        //\octave, 7,
        \octave, 6,
        \rq1, 0.1,
        \scale, ~scale,
        \sinhimul, 0.0
));

//Pdef(\pnopulse2, Pbindf(Pdef(\pnopulse1), \dur, Pseq(~pnodurs - 0.25, inf), \level, ~pnopulselvl / 3));
//Pdef(\pnopulses, Ppar([Pdef(\pnopulse1), Pdef(\pnopulse2)]));

//

/*
Pdef(\pno1,
    Pbind(
        \instrument, \pno,
        \curve, -4,
        \dur, Pseq(~pnodurs + 0.25, inf),
        \fb, 0.6,
        \fb2, 2.5,
        \fb2mul, 0.1,
        \hffreq, 8000,
        \level, ~pnolvl,
        \degree, Pseq([0].stutter(~pnodurs.size) ++ [Rest].stutter(~pnodurs.size * 2), inf),
        \octave, 7,
        \rq1, 0.3,
        \rq2, 0.3,
        \scale, ~scale,
        \sinhimul, 0.2
));

Pdef(\pno2,
    Pbindf(
        Pdef(\pno1),
        \degree, Pseq([-2].stutter(~pnodurs.size) ++ [Rest].stutter(~pnodurs.size * 3), inf)
));

Pdef(\pno3,
    Pbindf(
        Pdef(\pno1),
        \degree, Pseq([7].stutter(~pnodurs.size) ++ [Rest].stutter(~pnodurs.size * 4), inf)
));

Pdef(\pnos, Ppar([Pdef(\pno1), Pdef(\pno2), Pdef(\pno3)], inf));
*/
);


/*
Pdef(\pnopulses).play(t, quant: 1);
Pdef(\pnopulses).isPlaying;
Pdef(\pnopulses).stop;
*/

/*
Pdef(\pnos).play(t, quant: 1);
Pdef(\pnos).isPlaying;
Pdef(\pnos).stop;
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
        \level, 0.4,
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

/*
(
MIDIdef.cc(\pnoplay, {
    if(Pdef(\pnos).isPlaying.not) {
		Pdef(\pnos).play(t, quant: 1);
		"pnos play".postln;
	}
}, 127, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnostop, {
    if(Pdef(\pnos).isPlaying) {
		Pdef(\pnos).stop;
		"pnos stop".postln;
	}
}, 127, srcID: ~nanoktrl2.uid, argTemplate: 0);
);
*/

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

(
MIDIdef.cc(\pad2playktrl, {
	if(Pdef(\pad2pat).isPlaying.not) {
		Pdef(\pad2pat).play(t, quant: 1);
		"pad2a play".postln;
	};
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad2stopktrl, {
    if(Pdef(\pad2pat).isPlaying) {
        Pdef(\pad2pat).stop;
        "pad2a stop".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pad2bplayktrl, {
	if(Pdef(\pad2pat2).isPlaying.not) {
		Pdef(\pad2pat2).play(t, quant: 1);
		"pad2b play".postln;
	};
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad2bstopktrl, {
    if(Pdef(\pad2pat2).isPlaying) {
        Pdef(\pad2pat2).stop;
        "pad2b stop".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\pad2cplayktrl, {
	if(Pdef(\pad2pat3).isPlaying.not) {
		Pdef(\pad2pat3).play(t, quant: 1);
		"pad2c play".postln;
	};
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pad2cstopktrl, {
    if(Pdef(\pad2pat3).isPlaying) {
        Pdef(\pad2pat3).stop;
        "pad2c stop".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// prc

(
SynthDef(\prc, { | a = 1, curve = -8, dfrq = 2000, dur = 1, freq = 1000, level = 0.08, pan = 0, releaseTime = 0.2 |
	var env				=	Env.perc(releaseTime: releaseTime, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq, a, add: 1);
	var lfn				=	LFNoise0.ar(15).range(0, 1);
	var sin				=	SinOsc.ar(freq * cusp, pi / 2, envgen);
	var sin2			=	sin.round(0.01) / 2;
	var rez				=	Resonz.ar(sin, freq, 0.05, 4);
    var pan2			=	Pan2.ar(sin2 + rez, pan).fold2(1);
	Out.ar(~prcfxbus, pan2);
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
        //\a, Pshuf((1..3) + 0.2, inf),
        \curve, Pshuf([-64, -16, -4], inf),
        \dfrq, Pshuf((1..19) * 400, inf),
        /*
        \dur, Pshuf([
            Pseq([1 / 12], 3),
            Pseq([0.25], 13), Pseq([0.5, 0.75], 11), Pseq([0.75, 1.25], 7), Pseq([1, 1.5], 5), Pseq([1.25, 1.75], 3),
            3, 5, 7, 11, 13
        ], inf),
        */
        \dur, Pshuf([
            Pseq([0.125], 2), Pseq([0.25, 0.5]), Pseq([0.5, 0.75]), Pseq([0.75, 1]),
            Pseq([1, 1.25]), Pseq([1.25, 1.5]), Pseq([1.5, 1.75]), Pseq([1.75, 2]), Pseq([2, 2.25])
        ], inf),
		\freq, Pshuf([
			Pseq([~prcpatfrq1, ~prcpatfrq2, ~prcpatfrq2]),
			Pseq([~prcpatfrq2, ~prcpatfrq1, ~prcpatfrq2]),
			Pseq([~prcpatfrq2, ~prcpatfrq2, ~prcpatfrq1]),
			Pseq([~prcpatfrq2, ~prcpatfrq2, ~prcpatfrq2])
		], inf),
		\level, ~prcpatlvl,
        \releaseTime, 0.1
));
//Pdef(\prcpat1a, Pbindf(Pdef(\prcpat1), \level, ~prcpatecholvl, \pan, -1));
//Pdef(\prcpat1b, Pbindf(Pdef(\prcpat1a), \pan, 1));
//Pdef(\prcpar1, Ppar([Pdef(\prcpat1)], inf));
//, Pdef(\prcpat1a), Pdef(\prcpat1b)

//

Pdef(\prc2,
    Pbindf(
        Pdef(\prc1),
        //\a, 3.5,
        \a, Pshuf([2.5, 3.5], inf),
        \curve, -64,
        \freq, ~prcpatfrq2 * 2
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
        \releaseTime, 1
));

//

//Pdef(\prcpar3, Ppar([Pdef(\prcpar2), Pdef(\prcpat3)], inf));
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

(
MIDIdef.cc(\prc3play, {
	if(Pdef(\prc3).isPlaying.not) {
		Pdef(\prc3).play(t, quant: 1);
		"prc3 play".postln;
	};
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc3stop, {
    if(Pdef(\prc3).isPlaying) {
        Pdef(\prc3).stop;
        "prc3 stop".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prc2play, {
	if(Pdef(\prc2).isPlaying.not) {
		Pdef(\prc2).play(t, quant: 1);
		"prc2 play".postln;
	};
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc2stop, {
    if(Pdef(\prc2).isPlaying) {
        Pdef(\prc2).stop;
        "prc2 stop".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prc1play, {
	if(Pdef(\prc1).isPlaying.not) {
		Pdef(\prc1).play(t, quant: 1);
		"prc1 play".postln;
	};
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prc1stop, {
    if(Pdef(\prc1).isPlaying) {
        Pdef(\prc1).stop;
        "prc1 stop".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// SIN

(
SynthDef(\sin, { |a = 1.4, fb = 0, freq = 440, gate = 1, hfreq = 1, level = 0.005|
    var env             =   Env.asr(sustainLevel: level, releaseTime: 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    //var fbmod           =   LFBrownNoise0.ar([13, 14]).range(0.0, 0.5);
    var fbmod           =   HenonN.ar([13, 17], [a, a + 0.05]).range(0.0, 0.5);
    var sin1            =   SinOscFB.ar(freq!2, fbmod, envgen);
    //var sin2            =   SinOscFB.ar(freq!2, fb, envgen);
    Out.ar(0, (sin1).round(0.001));
}).add;
);

Pdef(\sin, Pmono(\sin, \fb, 0.2, \scale, ~scale));

/*
Pdef(\sin).play(t, quant: 1);
Pdef(\sin).isPlaying;
Pdef(\sin).stop;
*/

(
MIDIdef.cc(\sinplay, {
    if(Pdef(\sin).isPlaying.not) {
		Pdef(\sin).play(t, quant: 1);
		"sin play".postln;
	}
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\sinstop, {
    if(Pdef(\sin).isPlaying) {
		Pdef(\sin).stop;
		"sin stop".postln;
	}
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////
// PENGUIN

(
SynthDef(\penguin, { | a = 1, curve = 0, freq = 400, gate = 1, level = 0.01, shapermin = 0.0005, shapermax = 0.005 |
    var env             =	Env.asr(0.01, sustainLevel: level, releaseTime: 0.01, curve: curve);
    var envgen          =	EnvGen.kr(env, gate, doneAction: 2);
    var tri             =	LFTri.ar(freq * LFNoise2.kr(1, 0.0005, 1), mul: envgen);
    var limitmod        =   Latoocarfian2DN.kr(0.2, 50, [a, a - 0.001]).range(shapermin, shapermax).fold(0.00001, 1);
    var shape           =	SineShaper.ar(tri, limitmod).fold2(level);
    var rhpf            =	RHPF.ar(shape, (freq * 8).clip(50, SampleRate.ir / 3), 0.03, 8);
    var sin             =   SinOsc.ar(freq, mul: (envgen) * LFBrownNoise0.kr(15!2).range(0.5, 1).round(0.5));
	Out.ar(0, rhpf + sin);
}).add;
);


(
Pdef(\pgn1,
	Pbind(
		\instrument, \penguin,
        \a, Pshuf([0.8, 0.9, 1.0, 1.1, 1.2], inf),
        \degree, Pshuf([[0, 2, 7, 10], [2, 7, 10, 12], [7, 10, 12, 14], [10, 12, 14, 19]], inf),
		//\dur, Pshuf([24, 32, 48, 64, 96], inf),
        \dur, 47,
		\legato, 0.5,
		\octave, 5,
		\scale, ~scale,
        \shapermin, 0.001,
        \shapermax, 0.008,
));
//Pdef(\pgn2, Pbindf(Pdef(\pgn1)));
//Pdef(\pgn3, Pbindf(Pdef(\pgn2)));
//Pdef(\pgns, Ppar([Pdef(\pgn1), Pdef(\pgn2), Pdef(\pgn3)]));
);

/*
Pdef(\pgn1).play(t, quant: 1);
Pdef(\pgn1).isPlaying;
Pdef(\pgn1).stop;
*/

/*
Pdef(\pgn2).play(t, quant: 1);
Pdef(\pgn2).isPlaying;
Pdef(\pgn2).stop;
*/

/*
Pdef(\pgn3).play(t, quant: 1);
Pdef(\pgn3).isPlaying;
Pdef(\pgn3).stop;
*/

(
MIDIdef.cc(\pgn1play, {
    if(Pdef(\pgn1).isPlaying.not) {
        Pdef(\pgn1).play(t, quant: 1);
        "pgn1 play".postln;
    }
}, 35, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pgn1stop, {
    if(Pdef(\pgn1).isPlaying) {
        Pdef(\pgn1).stop;
        "pgn1 stop".postln;
    }
}, 35, argTemplate: 0);
);

(
MIDIdef.cc(\pgn2play, {
    if(Pdef(\pgn2).isPlaying.not) {
        Pdef(\pgn2).play(t, quant: 1);
        "pgn2 play".postln;
    }
}, 51, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pgn2stop, {
    if(Pdef(\pgn2).isPlaying) {
        Pdef(\pgn2).stop;
        "pgn2 stop".postln;
    }
}, 51, argTemplate: 0);
);

/*
(
MIDIdef.cc(\pgn3play, {
    if(Pdef(\pgn3).isPlaying.not) {
        Pdef(\pgn3).play(t, quant: 1);
        "pgn3 play".postln;
    }
}, 67, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pgn3stop, {
    if(Pdef(\pgn3).isPlaying) {
        Pdef(\pgn3).stop;
        "pgn3 stop".postln;
    }
}, 67, argTemplate: 0);
);
*/