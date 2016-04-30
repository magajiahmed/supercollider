////////////////////////////////////////////////////////////////
// INIT

// clear all patterns

Pdef.removeAll;


(
t = TempoClock(132/60);
b = Buffer.alloc(s, s.sampleRate * (t.tempo * 6), 1);
);

(
// Bus depot
~bassfxbus = Bus.audio(s, 2);
~delay = 0.05;
~delaybus = Bus.audio(s, 2);
~prcfxbus = Bus.audio(s, 2);
);

(
// Pitch logic
~ratios = [1/1, 16/15, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 5/3, 7/4, 15/8];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new(~scaledegrees, ~ratios.size, ~tuning);
~chord = [-2, 0, 2, 7];
~chords = [[-5, 2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]];
);

// midi
(
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
MIDIdef.cc(\midiccpostln, { |...args| args.postln });
MIDIdef.noteOn(\midinoteonpostln, { |...args| args.postln });
~lpm = MIDIClient.sources.detect{ |a| a.name.contains("Launchpad") };
if(~lpm.isNil) { ~lpm = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };
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

////////////////////////////////////////////////////////////////
// DELAY ///////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////
// LIMITER /////////////////////////////////////////////////////

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
Pdef(\limiter, Pmono(\limiter, \dur, ~delay / 2, \inBus, ~prcfxbus, \level, 0.3, \outbus, 0));
);

////////////////////////////////////////////////////////
// BASS ////////////////////////////////////////////////

// SynthDef

(
SynthDef(\bass, { |curve = -12, dur = 1, fb = 0, foldfactor = 1, freq = 100, level = 0.05, outbus, start = 1, end = 1|
    var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
 	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var fenv            =   XLine.kr(start, end, 0.25);
    var sinfb1          =   SinOscFB.ar(freq!2 * fenv, fb);
    var sinfb2     		=	SinOscFB.ar([freq - 0.03, freq + 0.03] * fenv, fb);
    var sinfb3          =   SinOscFB.ar(freq!2, fb * 0.1, envgen);
    var lowtri          =   LFTri.ar(freq!2 * 0.5, mul: envgen);
    Out.ar(outbus, ((sinfb1 + sinfb2).fold2(foldfactor) * (foldfactor.reciprocal + 0.001) * envgen) + sinfb3 + lowtri);
}).add;
);


// Pattern

(
~bassfoldseries = Array.fill(13, { |f| (f + 1) * 13.reciprocal });
Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
        \curve, -16,
        \degree, 0,
        \dur, Pshuf(Array.fill(17, { |d| (d + 1) * 0.25 })
            ++ Array.fill(3, { |d| Pseq([0.25], d + 1) }).stutter(2)
            , inf),
        \fb, Pshuf([0, 0.25, 0.5, 1, 2].stutter(7), inf),
		\foldfactor, Pshuf(~bassfoldseries.stutter(3), inf),
        \octave, 3,
        \outbus, [~delaybus, ~bassfxbus],
		\scale, ~scale,
        \start, Pshuf([7/8, 1/1, 16/15, 7/6, 2/1].stutter(5), inf),
        \end, Pshuf([7/8, 1/1, 16/15, 7/6].stutter(4), inf)
));

Pdef(\basspat2,
    Pbindf(
        Pdef(\basspat1),
        \start, 1,
        \end, 1,
));

Pdef(\basspar, Ppar([Pdef(\basspat1), Pdef(\basspat2)], inf));
);

/*
Pdef(\basspat1).play(t);
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

//

(
Pdef(\basstwo,
    Pbind(
        \instrument, \bass,
        \curve, -8,
        \dur, Pshuf([Pseq([0.125], 2), 0.25, Pseq([0.125], 4), Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, 1, 1.5, 6].stutter(5), inf),
        \foldfactor, Pshuf((11..23) * 0.01, inf),
        \level, 0.02,
        \octave, [4, 5, 6],
        \outbus, ~delaybus,
        \scale, ~scale,
        \start, Pshuf([7/8, 1/1, 16/15, 3/2], inf),
        \end, Pshuf([1/1, 16/15].stutter(3), inf)
));
);

/*
Pdef(\basstwo).play(t);
Pdef(\basstwo).isPlaying;
Pdef(\basstwo).stop;
*/

(
Pdef(\bassthree,
    Pbind(
        \instrument, \bass,
        \dur, Pseq([Pseq([0.125], 2), Pshuf(Array.fill(7, { |d| (d + 1) * 0.25 }).stutter(3))], inf),
        \foldfactor, Pshuf(((1..11).stutter(3) * 0.05), inf),
        \octave, 3,
        \outbus, [~delaybus, ~bassfxbus],
        \scale, ~scale,
        \start, 1/2,
        \end, 1/2
));
);

/*
Pdef(\bassthree).play(t);
Pdef(\bassthree).isPlaying;
Pdef(\bassthree).stop;
*/

// Midi Control

~midiktrl.value(\basspar, 32);
~midiktrl.value(\basstwo, 48);
~midiktrl.value(\bassthree, 64);

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
SynthDef(\bufrd, { |amp = 1, curve = -4, dur = 1, filt_freq = 8000, filt_rq = 1, freq = 440, gate = 1, outbus, pan = 0|
	var kbn1			=	LFBrownNoise1.kr(4).range(0.75, 1);
	var env				=	Env.asr(0.005, amp, 0.005, curve);
	var envgen			=	EnvGen.ar(env, gate, doneAction: 2);
	var bufrd			=	BufRd.ar(b.numChannels, b.bufnum, Phasor.ar(0, 1, s.sampleRate * dur, 0), loop: 1, interpolation: 2);
	var rhpf			=	RHPF.ar(bufrd, filt_freq, filt_rq, envgen * kbn1 * 2);
	var pan2			=	Pan2.ar(rhpf, pan);
	Out.ar(outbus, pan2);
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
        \filt_freq, Prand([4000, 8000], inf),
		\filt_rq, Pwhite(0.3, 0.5, inf),
		\freq, Pwhite(100, 10000, inf),
        \outbus, ~delaybus,
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

Pdef(\bassstutter, Ppar([Pdef(\pbpar), Pdef(\rbpdef)], inf));

// MIDI control: none, as this effect is started when this document is evaluated; see below.

////////////////////////////////////////////////////////////////
// PNO

(
SynthDef(\pno, { |balance = 0, curve = 0, dur = 1, fb = 0, freq = 400, k = 1, level = 0.04, loffset = 0.1, outbus, pan = 0, s = 10|
    var env				=	Env.perc(0.003, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var freqmod         =   LorenzL.ar([22050, 22000], s).range(1 - loffset, 1 + loffset);
    var fbmod           =   StandardL.ar(200, [k, k - 0.01]).range(0, 1);
    var sinfb1			=	SinOscFB.ar(freq * freqmod, fb * fbmod).softclip * envgen;
    var sinfb2          =   SinOscFB.ar([freq - 0.1, freq + 0.1], fb, envgen);
    var bal             =   Balance2.ar((sinfb1 + sinfb2)[0], (sinfb1 + sinfb2)[1], balance);
	Out.ar(outbus, bal);
}).add;
);

(
Pdef(\pno1,
    Pbind(
        \instrument, \pno,
        \curve, -16,
        \degree, Pseq([Pshuf(~chords, 3), Pseq([Rest], 8)], inf),
        \dur, Pshuf([0.5, 0.75, 1, 1.5, 11, 13, 15, 17, 19, 31, 33, 35, 37, 39], inf),
        \fb, Pshuf([0.0, 0.5, 1.0, 1.5].stutter(3), inf),
        \k, Pwhite(0.5, 4.0, inf),
        \loffset, Pshuf([0, 0.1, 0.2, 0.3, 0.4], inf),
        \octave, [4, 5, 6, 7],
        \outbus, ~delaybus,
        \timingOffset, Pwhite(-0.03, 0.03, inf),
        \s, Pwhite(9.0, 11.0, inf),
        \scale, ~scale
));

//Pdef(\pnos, Ppar([Pdef(\pno1)].stutter(2), inf));

Pdef(\pnopulse,
    Pbind(
        \instrument, \pno,
        \balance, Pshuf([-0.5, -0.25, 0, 0.25, 0.5].stutter(3), inf),
        \curve, Pshuf([-64, 0].stutter(13), inf),
        \degree, Pshuf(Array.fill(~chords.size, { |n| Pseq([~chords[n]], 23) }), inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].stutter(3), inf),
        \fb, Pshuf([0.0, 0.5, 1, 1.5].stutter(3), inf),
        \k, Pwhite(0.5, 4, inf),
        \loffset, Pwhite(0.0, 0.4, inf),
        \octave, 5,
        \outbus, ~delaybus,
        \s, Pwhite(9.0, 11.0, inf),
        \scale, ~scale
));

Pdef(\pnopulses, Ppar([Pdef(\pnopulse)].stutter(3), inf));
//Pdef(\pnopulse2, Pbindf(Pdef(\pnopulse), \octave, 6));
//Pdef(\pnopulses2, Ppar([Pdef(\pnopulse2)].stutter(3), inf));
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
Pdef(\pnopulse2).play(t);
Pdef(\pnopulse2).isPlaying;
Pdef(\pnopulse2).stop;
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

~midiktrl.value(\pno1, 33);
~midiktrl.value(\pnopulse, 49);
//~midiktrl.value(\pnopulse2, 65);

////////////////////////////////////////////////////////////////
// WUT

(
SynthDef(\wut, { |attack = 0.01, curve = 0, dur = 1, fb = 0, foldfactor = 1, freq = 440, gate = 1, k = 1.4, level = 0.02, outbus, release = 0.1|
    var env             =   Env.asr(attack, level, release, curve);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var freqmod         =   LFNoise0.kr(11!2, 0.0005, 1);
    var fbmod           =   Standard2DC.kr(0.5, 500, [k, k + 0.1]).range(0.5, 1).fold(0.5, 1);
    var sin1            =   SinOscFB.ar(freq * freqmod, fb * fbmod, envgen / 2);
    var sin2            =   SinOscFB.ar(freq!2, fb * fbmod, envgen / 2);
    Out.ar(0, (sin2 * 2).fold2(level));
}).add;
);

(
Pdef(\wut,
    Pbind(
        \instrument, \wut,
        \degree, Pshuf(~chords, inf),
        \dur, 43,
        \fb, 0.1,
        \k, Pwhite(1.0, 2.0, inf),
        \legato, 0.5,
        \octave, 6,
        \outbus, ~delaybus,
        \scale, ~scale
));
);

/*
Pdef(\wut).play(t);
Pdef(\wut).isPlaying;
Pdef(\wut).stop;
*/

(
Pdef(\wat,
    Pbind(
        \instrument, \wut,
        \degree, [7, 10, 12, 14],
        \dur, 53,
        \fb, 2,
        \legato, 0.5,
        \level, 0.01,
        \octave, 4,
        \outbus, ~delaybus,
        \scale, ~scale
));
);

/*
Pdef(\wat).play(t, quant: 1);
Pdef(\wat).isPlaying;
Pdef(\wat).stop;
*/

Pdef(\wet, Pmono(\wut, \degree, [-5, 0], \fb, 0.3, \outbus, ~delaybus, \scale, ~scale));

/*
Pdef(\wet).play(t, quant: 1);
Pdef(\wet).isPlaying;
Pdef(\wet).stop;
*/

~midiktrl.value(\wut, 34);
~midiktrl.value(\wat, 50);
~midiktrl.value(\wet, 66);

////////////////////////////////////////////////////////////////
// PINGLE

(
SynthDef(\pingle, { |a = 0.02, curve = -16, freq = 10000, level = 0.08, outbus, pan = 0, rq = 1|
	//var env				=	Env.perc(0.0005, 1, level: level, curve: curve);
	//var envgen			=	EnvGen.ar(env, doneAction: 2);
    var imp             =   Impulse.ar(0!2, mul: level);
    var rhpf            =   RHPF.ar(imp, freq.clip(50, SampleRate.ir / 2.5), rq.clip(0.0001, 1));
	var ds              =   DetectSilence.ar(rhpf, doneAction: 2);
    var pan2            =   Pan2.ar(rhpf, pan);
    Out.ar(outbus, pan2);
}).add;
);

// Pattern

(
~pinglelevel = 0.08;
Pdef(\pinglepat,
	Pbind(
		\instrument, \pingle,
		\curve, -64,
        \dur, Pshuf(
            [4, 8, 16].collect({ |d| Pseq([d.reciprocal], d) }) ++
            Array.fill(17, { |d| Pseq([(d + 1) * 0.25], 2) }) ++
            Array.fill(5, { |d| Pseq([0.25], d) }),
        inf),
        \level, Pshuf([0.25, 1].stutter(11) * ~pinglelevel, inf),
        \degree, 0,
        \pan, Pseq([-1, -0.5, 0, 0.5, 1].mirror1, inf),
        \octave, [9, 10],
        \outbus, ~prcfxbus,
        \rq, Pbrown(0.002, 0.02, 0.002, inf),
		\scale, ~scale
));

);

/*
Pdef(\pinglepat).play(t, quant: 1);
Pdef(\pinglepat).isPlaying;
Pdef(\pinglepat).stop;
*/

~midiktrl.value(\pinglepat, 35);

////////////////////////////////////////////////////////////////
// CLAP

(
SynthDef(\clap, { | combdelay = 0.02, combdelay_start = 1, combdelay_end = 1, curve = 4, dur = 1, delaytime = 0.01, fb = 0, freq = 1000, level = 0.3, offset = 0, outbus, pan = 0, xi = 1.2, yi = 2.1 |
	var env				=	Env.perc(0.005, 0.3, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var gbman           =   GbmanL.ar(freq, xi, yi, 2, 1);
    var sin             =   SinOscFB.ar(freq * gbman, fb, envgen);
    var delay           =   DelayC.ar(sin, 0.1, delaytime.clip(0.0001, 0.01));
    var comb            =   CombC.ar(sin, 1, combdelay * XLine.kr(combdelay_start, combdelay_end, 0.1), 0.3);
    var res             =   Resonz.ar(sin + delay + comb, freq.clip(50, SampleRate.ir / 2.5), 0.3);
    var pan2			= 	Pan2.ar(res, pan);
	Out.ar(outbus, pan2);
}).add;
);

(
~claplvl = 0.15;
~clapecholvl = ~claplvl / 3;
Pdef(\clappat1,
	Pbind(
		\instrument, \clap,
        \combdelay, Pwhite(0.02, 0.04, inf),
        \combdelay_start, Prand([0.5, 1, 2], inf),
        \combdelay_end, Prand([0.5, 1, 2], inf),
        \curve, -16,
        \delaytime, Pwhite(0.0001, 0.001, inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 2, 3, Pseq([0.75], 3), Pseq([1.25], 3), Pseq([1.75], 3), Pseq([2.25], 3)].stutter(3), inf),
        \fb, Pshuf([0, 0.5, 1, 1.5, 2], inf),
        \level, ~claplvl,
        \degree, Pshuf([[-5, -2, 0, 2], [-2, 0, 2, 7], [0, 2, 7, 10], [2, 7, 10, 12]], inf),
        \octave, Pshuf([1, 2, 3, 5, 7, 11, 13], inf),
        \outbus, ~prcfxbus,
        \pan, Pshuf([-0.25, 0, 0.25].stutter(7), inf),
        \scale, ~scale,
        \xi, Pshuf([1.1, 1.2, 1.3].stutter(5), inf),
        \yi, Pshuf([1.9, 2.0, 2.1, 2.2, 2.3].stutter(3), inf)
));
Pdef(\clappat2, Pbindf(Pdef(\clappat1), \level, ~clapecholvl, \pan, -1));
Pdef(\clappat3, Pbindf(Pdef(\clappat2), \pan, 1));
Pdef(\clappar, Ppar([Pdef(\clappat1), Pdef(\clappat2), Pdef(\clappat3)], inf));
);

/*
Pdef(\clappat1).play(t, quant: 0.5);
Pdef(\clappat1).isPlaying;
Pdef(\clappat1).stop;
*/

/*
Pdef(\clappar).play(t, quant: 0.5);
Pdef(\clappar).isPlaying;
Pdef(\clappar).stop;
*/

~midiktrl.value(\clappar, 51);

////////////////////////////////////////////////////////////////
// PRC1

(
SynthDef(\prc1, { |a = 1.1, c = 0.13, curve = -16, dur = 1, fb = 0, freq = 1000, length = 1, level = 0.15, outbus|
    var env             =   Env.perc(0.01, length, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sindrop         =   SinOscFB.ar(freq * LinCongC.ar(a: [a, a - 0.01], c: [c, c - 0.01], mul: 2, add: 1), fb, envgen);
    Out.ar(outbus, sindrop.fold2(level));
}).add;
);

(
Pdef(\prc1,
    Pbind(
        \instrument, \prc1,
        \a, Pshuf([1.0, 1.1, 1.2, 1.3].stutter(17), inf),
        \c, Pshuf([0.1, 0.12, 0.14, 0.16, 0.18, 0.2].stutter(3), inf),
        \curve, -32,
        \dur, Pshuf([Pseq([0.125, 0.125, 0.25]), 0.25, 0.5, 0.75, 1, 1.5, 2, Pseq([1.25], 2), Pseq([1], 2), 3].stutter(2), inf),
        \fb, Prand([0, 1], inf),
        \freq, Pshuf([100, 500, 1000].stutter(13), inf),
        \length, Pshuf([0.5, 1, 1.5].stutter(11), inf),
        \outbus, ~prcfxbus,
));
);

/*
Pdef(\prc1).play(t);
Pdef(\prc1).isPlaying;
Pdef(\prc1).stop;
*/

~midiktrl.value(\prc1, 36);

////////////////////////////////////////////////////////////////
// PRC2

(
SynthDef(\prc2, { |curve = -16, fb = 0, freq = 440, length = 0.1, level = 0.15, lfreq = 22050, multiplier = 1, outbus, s = 10|
    var env             =   Env.perc(0.005, length, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sinmod          =   LorenzL.ar([lfreq, lfreq - 10], [s, s - 0.1], mul: 5, add: 1);
    var sin             =   SinOscFB.ar(freq * sinmod * XLine.kr(1, 0.1, length), fb, envgen);
    var rlpf            =   RLPF.ar(sin, (freq * 16).clip(50, SampleRate.ir / 2.5));
    var rhpf            =   RHPF.ar(sin, 4000, 0.1);
    Out.ar(outbus, (rlpf + rhpf).fold2(level));
}).add;
);

(
Pdef(\prc2a,
    Pbind(
        \instrument, \prc2,
        \curve, -8,
        //\dur, Pshuf([Pseq([0.125], 2), 0.25, 0.5, 1, 2, Pseq([1.25], 2), 4].stutter(2), inf),
        \dur, Pshuf([Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, Pseq([0.75], 2), 1.5, 2, 3].stutter(3), inf),
        \fb, Pshuf([0.5, 1, 1.5, 2, 2.5, 3], inf),
        \freq, Prand([100, 1000, 10000], inf),
        \length, 0.2,
        \lfreq, Pxrand([2500, 5000, 10000, 20000], inf),
        \outbus, ~prcfxbus,
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
        \curve, -2,
        \dur, Pseq([Pshuf([0.25, 0.5, 0.75].stutter(11)), 3], inf),
        \fb, Pshuf([0.25, 0.5].stutter(23), inf),
        //\freq, Pshuf([Pwhite(190.0, 210.0, 1), Pwhite(1000.0, 2000.0, 1)].stutter(3), inf),
        \freq, Pxrand([250, 500, 1000, 2000, 4000], inf),
        \length, Pshuf([0.1, 0.4].stutter(17), inf),
        \level, Pshuf([0.2, 1, 1, 1].stutter(11) * 0.1, inf),
        \lfreq, Pshuf((1..19) * 1000, inf),
        \outbus, ~prcfxbus,
        \s, Pwhite(7.0, 12.0, inf).round(0.1)
));
);

/*
Pdef(\prc2b).play(t);
Pdef(\prc2b).isPlaying;
Pdef(\prc2b).stop;
*/

~midiktrl.value(\prc2a, 67);
~midiktrl.value(\prc2b, 68);

////////////////////////////////////////////////////////////////
// HEAVY PERC

(
SynthDef(\heavy, { |brightness = 1000, curve = -8, dur = 1, freq = 440, level = 0.03, multiplier = 1, outbus, pan = 0, releaseTime = 1, sinfb = 0|
	var env				=	Env.perc(0.005, releaseTime: releaseTime, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var kxline			=	XLine.kr(1, 0.125, dur / 5);
    var sin				=	SinOscFB.ar(freq * LFBrownNoise0.ar(freq!2, mul: Line.kr(1, 1, 0.1), add: 1) * kxline, sinfb).tan.round(0.1).round(0.2).round(0.3).round(0.4).round(0.5) * envgen;
	var filtfreqmod		=	LFNoise0.kr(50!2).range(1/5, 5);
	var filtrqmod		=	LFNoise0.kr(50!2).range(0.2, 0.9).round(0.1) + 0.05;
	var delay			=	DelayC.ar(sin, 0.5, freq.clip(50, SampleRate.ir / 3).reciprocal, 0.5);
	var rez				=	RLPF.ar(sin + delay, (brightness * kxline * filtfreqmod).clip(30, SampleRate.ir / 4), filtrqmod);
    var rlpf            =   RLPF.ar(rez, freq.clip(50, SampleRate.ir / 3), 0.3);
    var rhpf            =   RHPF.ar(rez, (freq * 4).clip(50, SampleRate.ir / 3), 0.1);
    var pan2			=	Pan2.ar(rez, pan);
    Out.ar(outbus, pan2.fold2(level));
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
        \curve, Pshuf([-16, -4, 0, 2, 4].stutter(2), inf),
        \degree, Pseq([Pseq([[0, 7, 10]], 29), Pseq([Rest], 17)], inf),
        \dur, Pshuf([Pseq([0.25], 3), Pseq([0.25], 5), Pseq([0.25], 7), 2, 3, 4, 6, 8, 12, 16, 24], inf),
        \level, ~heavypatlvl,
		\octave, 5,
        \outbus, ~delaybus,
		\pan, Prand([-0.5, 0, 0.5], inf),
        \scale, ~scale,
		\sinfb, Pshuf((1..3), inf)
));

Pdef(\heavypat2,
    Pbind(
        \instrument, \heavy,
        \brightness, Pshuf((1..7) * 2000 , inf),
        \curve, Pshuf([-64, -32, -16, -8, -4], inf),
        \degree, [-5, -2, 0],
        \dur, Pshuf([Pseq([0.125], 2), 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25].stutter(3), inf),
        \level, ~heavypatlvl,
        \octave, Pshuf((2..7).stutter(3), inf),
        \outbus, ~prcfxbus,
        \releaseTime, Prand([0.5, 1, 1.5], inf),
        \scale, ~scale,
        \sinfb, Pshuf((1..3) + 0.5, inf)
));

Pdef(\heavypat3,
    Pbindf(
        Pdef(\heavypat2),
        \level, ~heavypatecholvl,
        \pan, Prand([-1, 1], inf),
        \sinfb, Pshuf((1..3), inf)
));

Pdef(\heavypar, Ppar([Pdef(\heavypat1), Pdef(\heavypat2), Pdef(\heavypat3)], inf));
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

~midiktrl.value(\heavypar, 52);

////////////////////////////////////////////////////////////////
// MAKING A SCENE

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
        } {
            ~midiout.control(0, light, 0);
            starters.do({ |s| Pdef(s).stop });
            starterlights.do({ |l| ~midiout.noteOff(0, l) });
            scenestatus = nil;
        }
    }, light, srcID: ~lpm.uid, argTemplate: { |a| a > 0 });
}
);

(
~scene1 = [\basspar, \pno1, \pinglepat, \clappar, \prc2a];
~scene1lights = [32, 33, 35, 51, 67];
~scenetoggle.value(\scene1, 104, ~scene1, starterlights: ~scene1lights);
);

(
~scene2 = [\basstwo, \bassthree, \clappar, \wut, \prc1];
~scene2lights = [48, 64, 51, 34, 36];
~scene2stoppers = [\basspar, \pno1, \pinglepat, \prc2a];
~scene2stopperlights = [32, 33, 35, 67];
~scenetoggle.value(\scene2, 105, ~scene2, ~scene2stoppers, ~scene2lights, ~scene2stopperlights);
);

(
~scene3 = [\basspar, \pnopulse, \pinglepat, \clappar, \prc2a];
~scene3lights = [32, 49, 35, 51, 67];
~scene3stoppers = [\basstwo, \bassthree, \wut, \prc1];
~scene3stopperlights = [48, 64, 34, 36];
~scenetoggle.value(\scene3, 106, ~scene3, ~scene3stoppers, ~scene3lights, ~scene3stopperlights);
);

(
~scene4 = [\bassthree, \wat, \wet, \clappar, \prc1];
~scene4lights = [64, 50, 66, 51, 36];
~scene4stoppers = [\basspar, \pnopulse, \pinglepat, \prc2a];
~scene4stopperlights = [32, 49, 35, 67];
~scenetoggle.value(\scene4, 107, ~scene4, ~scene4stoppers, ~scene4lights, ~scene4stopperlights);
);

(
~scene5 = [\wet, \heavypar, \prc2b];
~scene5lights = [66, 52, 68];
~scene5stoppers = [\prc1, \bassthree, \wat, \clappar];
~scene5stopperlights = [36, 64, 50, 51];
~scenetoggle.value(\scene5, 108, ~scene5, ~scene5stoppers, ~scene5lights, ~scene5stopperlights);
);

(
~scene6 = [\basspar, \basstwo, \bassthree, \pno1, \pnopulse, \wut, \wet, \pinglepat, \clappar];
~scene6lights = [32, 48, 64, 33, 49, 34, 66, 35, 51];
~scene6stoppers = [\heavypar, \prc2b];
~scene6stopperlights = [52, 68];
~scenetoggle.value(\scene6, 109, ~scene6, ~scene6stoppers, ~scene6lights, ~scene6stopperlights);
);

(
~scene7 = [\basspar, \bassthree, \wut, \wat, \wet, \clappar, \prc2a, \prc1];
~scene7lights = [32, 64, 34, 50, 66, 51, 67, 36];
~scene7stoppers = [\basstwo, \pno1, \pnopulse, \pinglepat];
~scene7stopperlights = [48, 33, 49, 35];
~scenetoggle.value(\scene7, 110, ~scene7, ~scene7stoppers, ~scene7lights, ~scene7stopperlights);
);

(
~scene8 = [\basstwo, \bassthree, \wut, \wet];
~scene8lights = [48, 64, 34, 66];
~scene8stoppers = [\basspar, \wat, \pinglepat, \clappar, \prc2a, \prc1];
~scene8stopperlights = [32, 50, 35, 51, 67, 36];
~scenetoggle.value(\scene8, 111, ~scene8, ~scene8stoppers, ~scene8lights, ~scene8stopperlights);
);

////////////////////////////////////////////////////////////////
// START UP THE EFFECTS

(
{
    s.sync;
    Pdef(\bassstutter).play(t);
    Pdef(\limiter).play(t);
    Pdef(\delay).play(t);
}.fork;
);