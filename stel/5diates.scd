Pdef.removeAll;

// pitch logic
(
~root = 0;
~ratios = [1/1, 21/20, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 63/40, 27/16, 7/4, 15/8];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new((0..11), 12, ~tuning);
);

// time
~tempo = TempoClock(96/60);

//midi
(
MIDIClient.init;
MIDIIn.connectAll;
MIDIdef.freeAll;
MIDIdef.cc(\midiccpostln, { |...args| args.postln });
MIDIdef.noteOn(\midinoteonpostln, { |...args| args.postln });
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
            Pdef(pdef).play(~tempo);
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

// bus depot
(
~companderbus = Bus.audio(s, 2);
~delay = 0.05;
~delaybus = Bus.audio(s, 2);
~prcbus = Bus.audio(s, 2);
//
~stringchords1delayktrlbus = Bus.control(s);
~stringchords2delayktrlbus = Bus.control(s);
~stringchords3delayktrlbus = Bus.control(s);
~stringchords4delayktrlbus = Bus.control(s);
//~stringchords5delayktrlbus = Bus.control(s);
//~stringchorddronedelayktrlbus = Bus.control(s);
//~dronedelayktrlbus = Bus.control(s);
/*
~stringpat0delayktrlbus = Bus.control(s);
~stringpat1delayktrlbus = Bus.control(s);
~stringpat2delayktrlbus = Bus.control(s);
~stringpat3delayktrlbus = Bus.control(s);
~stringpat4delayktrlbus = Bus.control(s);
~stringpat5delayktrlbus = Bus.control(s);
~stringpat6delayktrlbus = Bus.control(s);
~stringpat7delayktrlbus = Bus.control(s);
~stringpat8delayktrlbus = Bus.control(s);
~stringpat9delayktrlbus = Bus.control(s);
*/
);

// record
/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////
// COMPANDER

(
SynthDef(\dynamix, { |inbus, outbus|
	var in	   		= 	In.ar(inbus, 2);
	var compressor	=	Compander.ar(in, in, thresh: 0.4, clampTime: 0.002, slopeAbove: 1/10);
	Out.ar(outbus, compressor);
}).add;
);

Pdef(\dynamix, Pmono(\dynamix, \inbus, ~companderbus, \outbus, ~delaybus));

/*
Pdef(\dynamix).play;
Pdef(\dynamix).isPlaying;
Pdef(\dynamix).stop;
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
// LIMITER /////////////////////////////////////////////

(
SynthDef(\limiter, { |dur = 1, gate = 1, inBus, level = 1, outbus|
    var env             =   Env.asr(0.01, 1, 0.01, 0);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(inBus, 2);
    var limiter         =   Limiter.ar(in, level, dur);
    Out.ar(outbus, limiter);
}).add;
);

(
Pdef(\limiter, Pmono(\limiter, \dur, ~delay / 2, \inBus, ~prcbus, \level, 0.25, \outbus, 0));
);

////////////////////////////////////////////////////////////////
// SIN

(
SynthDef(\sin, { |freq = 440, gate = 1, level = 0.01, outbus|
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var foldmod         =   LFBrownNoise0.kr(17 ! 2).range(0.1, 0.11);
    var saw             =   VarSaw.ar(freq ! 2, width: 0).fold2(foldmod) * envgen;
    var rhpf1           =   RHPF.ar(saw, 7000, 0.1);
    var sin             =   FSinOsc.ar(freq ! 2).round(0.05).round(0.1) * envgen * LFClipNoise.kr(LFNoise2.kr(1 ! 2).range(1, 15)).range(0.8, 1);
    var rhpf2           =   RHPF.ar(sin, (freq * 2).clip(100, SampleRate.ir / 2.5));
    Out.ar(outbus, rhpf1 + rhpf2);
}).add;
);

(
Pdef(\sin,
    Pmono(
        \sin,
        \degree, Pshuf([[7, 7, 10, 12], [7, 7, 12, 12], [7, 10, 12, 13]].collect({ |c| c.stutter(3) }), inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
        \octave, 5,
        \root, ~root,
        \scale, ~scale
));
);

/*
Pdef(\sin).play(~tempo);
Pdef(\sin).isPlaying;
Pdef(\sin).stop;
*/

~midiktrl.value(\sin, 17);

////////////////////////////////////////////////////////////////
// BASS

(
SynthDef(\bass, { |curve = -2, detune = 1, dur = 1, fb = 0, freq = 440, level = 0.05, outbus, round = 0|
	var env				=	Env.perc(0.01, dur, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var sinfb1          =   SinOscFB.ar(freq ! 2, [fb, fb * 0.99] * XLine.kr(1, 0.01, dur));
    var sinfb2          =   SinOscFB.ar(freq ! 2 * LFClipNoise.ar(100 ! 2, detune, 1), [fb, fb * 0.9] * XLine.kr(1, 0.01, dur));
    var mix             =   (sinfb1 + sinfb2).round(round / 8).round(round / 4).round(round / 2).round(round) * envgen;
    var sinfb           =   SinOscFB.ar(freq * 0.5 ! 2, XLine.kr(1, 0.1, dur), envgen);
    Out.ar(outbus, mix + sinfb);
}).add;
);

(
//~degrees = [0].stutter(8) ++ [-2] ++ [-2] ++ [-2] ++ [1] ++ [4] ++ [6];
~degrees = [-2, 0, 1, 0, 4, 0, 6, 0];

Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
        \curve, -4,
        //\degree, Pseq([Pshuf(~degrees.stutter(3)), Pseq([Rest], ~degrees.size)], inf),
        \degree, Pshuf(~degrees.stutter(3)),
        \detune, Pshuf([0.0025, 0.005, 0.01].stutter(5), inf),
        /*
        \dur, Pshuf([
            0.25, Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, Pseq([0.25], 4), Pseq([0.5], 2), 1,
            1.5, Pseq([4, 1, 1] / 3), 2, 3, 4, 6
        ].stutter(2), inf),
        */
        \dur, Pshuf([0.25, 6, 0.25, 0.25, 8, 0.25, 0.25, 0.25, 12].stutter(3), inf),
        \fb, Pshuf([0, 0.2, 0.4, 0.8, 1.6].stutter(2), inf),
        //\fold, Pshuf([0.5, 1].stutter(5), inf),
        \octave, 3,
        \outbus, ~delaybus,
		\root, ~root,
        \round, Pshuf([0, 0.1, 0.2, 0.4].stutter(2), inf),
        \scale, ~scale,
));
);

/*
Pdef(\basspat1).play(~tempo);
Pdef(\basspat1).isPlaying;
Pdef(\basspat1).stop;
*/

/*
(
~bass2notes = [0, 12, 19];
Pdef(\basspat2,
    Pbind(
        \instrument, \bass,
        \curve, -4,
        \degree, Pseq([~bass2notes, Rest, ~bass2notes, Rest, Rest, ~bass2notes, Rest, Rest, Rest], inf),
        \dur, Pseq([1, 5, 1, 4, 3, 1, 4, 3, 2] + 0.25, inf),
        \fb, Pshuf([0.5, 1.5], inf),
        \octave, 2,
        \outbus, ~delaybus,
        \root, ~root,
        \scale, ~scale
));
);
*/

/*
Pdef(\basspat2).play(~tempo);
Pdef(\basspat2).isPlaying;
Pdef(\basspat2).stop;
*/


(
Pdef(\bass2,
    Pbind(
        \instrument, \bass,
        \degree, Pseq([-5, -2, 0, 1].scramble.mirror1, 17),
        \detune, Pwhite(0, 0.01, inf),
        \dur, Pshuf([0.25, Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, Pseq([1/3], 3), 1, 1.5, 2, 3], inf),
        \fb, Pwhite(0.0, 2.5, inf),
        \octave, 3,
        \outbus, ~delaybus,
        \round, Pwhite(0, 0.4, inf)
));
);

/*
Pdef(\bass2).play(~tempo);
Pdef(\bass2).isPlaying;
Pdef(\bass2).stop;
*/

(
Pdef(\basspat3,
    Pbind(
        \instrument, \bass,
        \curve, -4,
        \degree, Pseq([2] ++ [0].stutter(12), inf),
        \detune, Pshuf([0, 0.001, 0.002, 0.004], inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
        \fb, Pshuf([0, 1.5], inf),
        \octave, 3,
        \outbus, ~delaybus,
        \round, Pshuf([0, 0.25, 0.5], inf),
        \scale, ~scale
));
);

~midiktrl.value(\basspat1, 49);
~midiktrl.value(\bass2, 65);
~midiktrl.value(\basspat3, 81);

////////////////////////////////////////////////////////////////

(
SynthDef(\hat, { |curve = -16, dur = 1, fb = 0, fbmod_mul = 0.5, freq = 440, level = 0.02, outbus|
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise0.kr(50!2, 0.005, 1);
    var fbmod           =   LFBrownNoise0.ar(31!2, mul: fbmod_mul, add: 1);
	var sinfb			=	SinOscFB.ar(freq!2 * lfn, fb * fbmod).fold2(0.03) * envgen * 40;
	var rhpf			=	RHPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.1);
	Out.ar(outbus, rhpf);
}).add;
);

(
Pdef(\hatpat1,
	Pbind(
		\instrument, \hat,
        \curve, -32,
        \degree, [1, 4, 6, 7, 10, 12],
        \dur, Pshuf([
            Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, 1.5, 11
        ].stutter(3), inf),
        //\dur, Pshuf(Array.fill(11, { |i| (i + 1) * 0.25 }).stutter(3), inf),
		//\fb, Pshuf(Array.series(10, 0.1, 0.1), inf),
        \fb, Pshuf([0, 1].stutter(13), inf),
		\level, 0.05,
		\degree, 5,
        \octave, [9, 10],
        \outbus, ~prcbus,
		\root, ~root,
		\scale, ~scale
));

Pdef(\hatpat2,
    Pbindf(
        Pdef(\hatpat1),
        //\dur, Pshuf([Pseq([0.25], 4), Pseq([0.5], 2), 1, 2].stutter(11), inf),
        \level, 0.01
));

Pdef(\hatpar, Ppar([Pdef(\hatpat1), Pdef(\hatpat2)], inf));
);

/*
Pdef(\hatpat1).play(~tempo, quant: 1);
Pdef(\hatpat1).stop;
*/

/*
Pdef(\hatpat2).play(~tempo, quant: 1);
Pdef(\hatpat2).stop;
*/

/*
Pdef(\hatpar).play(~tempo, quant: 1);
Pdef(\hatpar).isPlaying;
Pdef(\hatpar).stop;
*/

//

(
(
~pulselvl = 0.01;
~pulseecholvl = ~pulselvl / 4;
Pdef(\pulsepat1a,
	Pbind(
		\instrument, \hat,
        \curve, Prand([-16, -4], inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 4, 6, 8, 12, 16, 24].stutter(11), inf),
        \fb, Pshuf([2, 3, 4].stutter(5), inf),
        \fbmod_mul, Pshuf([0.25, 0.5, 1, 2, 4].stutter(3), inf),
		\level, ~pulselvl,
        \degree, Pshuf([[6, 7, 10, 12]] ++ [[7, 12].stutter(3)] ++ [[7, 10, 12].stutter(2)], inf),
		\octave, 3,
        \outbus, ~delaybus,
		\root, ~root,
		\scale, ~scale
));
);

/*
Pdef(\pulsepat1a).play(~tempo);
Pdef(\pulsepat1a).isPlaying;
Pdef(\pulsepat1a).stop;
*/

(
Pdef(\pulsepat2a,
    Pbindf(
        Pdef(\pulsepat1a),
        //\degree, Pshuf([[0, 7, 9, 11, 12, 13]] ++ [[0, 7, 10, 12, 14]].stutter(9) ++ [[0, 7, 11, 12, 13, 15]], inf)
        \octave, 4
));
);

/*
Pdef(\pulsepat2a).play(~tempo);
Pdef(\pulsepat2a).stop;
*/

(
Pdef(\pulsepat3a, Pbindf(Pdef(\pulsepat2a), \octave, 5));
Pdef(\pulsepat3b, Pbindf(Pdef(\pulsepat3a), \level, ~pulseecholvl));
Pdef(\pulsepar3, Ppar([Pdef(\pulsepat3a), Pdef(\pulsepat3b), Pdef(\pulsepat3b)]));
);

/*
Pdef(\pulsepat3a).play(~tempo);
Pdef(\pulsepat3a).stop;
*/

/*
Pdef(\pulsepar3).play(~tempo, quant: 1);
Pdef(\pulsepar3).isPlaying;
Pdef(\pulsepar3).stop;
*/
);

(
Pdef(\hat2,
    Pbind(
        \instrument, \hat,
        //\curve, Pshuf([-64, -16, -4].stutter(3), inf),
        \curve, -64,
        \degree, [0, 2, 7, 10, 12],
        //\dur, Pshuf(Array.fill(11, { |d| (d + 7) * 0.25 }), inf),
        //\dur, Pshuf([0.25, 0.5, 0.75, Pseq([1/5], 5), Pseq([1/3], 3), 1, 1.25, 1.5, 1.75].stutter(2), inf),
        //\dur, Pshuf(Array.fill(3, { |d| Pseq([0.75 + (d * 0.25)], 2) }), inf),
        /*
        \dur, Pshuf([
            0.25, Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, Pseq([0.25], 4)
        ].stutter(11), inf),
        */
        \dur, Prand([0.25, 0.5, 0.75], inf),
        \level, Pshuf([0.2, 1].stutter(11) * 0.02, inf),
        \fb, 0,
        \octave, (7..10),
        \outbus, ~prcbus,
        \root, ~root,
        \scale, ~scale
));
);

/*
Pdef(\hat2).play(~tempo);
Pdef(\hat2).isPlaying;
Pdef(\hat2).stop;
*/

(
~pingpatchord = [1, 4, 6, 7, 10, 12];

Pdef(\pingpat,
    Pbind(
        \instrument, \hat,
        \curve, 0,
        \dur, Pshuf([1.5, 1.75, 2.25, 2.5, 3], inf),
        \degree, Pseq([
            Rest, Rest, ~pingpatchord, ~pingpatchord, ~pingpatchord,
            Rest, Rest, Rest, ~pingpatchord, ~pingpatchord, ~pingpatchord,
            Rest, Rest, Rest, Rest, ~pingpatchord, ~pingpatchord, ~pingpatchord
        ], inf),
        \fb, 5,
        \level, 0.003,
        \octave, [6, 7, 8],
        \outbus, ~prcbus,
        \root, ~root,
        \scale, ~scale
));
);

/*
Pdef(\pingpat).play(~tempo, quant: 1);
Pdef(\pingpat).isPlaying;
Pdef(\pingpat).stop;
*/

//

~midiktrl.value(\hatpar, 34);
~midiktrl.value(\pulsepat1a, 32);
~midiktrl.value(\pulsepat2a, 48);
~midiktrl.value(\pulsepat3a, 64);
~midiktrl.value(\hat2, 33);
~midiktrl.value(\pingpat, 67);

////////////////////////////////////////////////////////////////

(
SynthDef(\prc, {
	|a = 1.1, c = 0.13, curve = -4, delaytime = 0.01, dur = 1, foldfactor = 2, freq = 440, level = 0.15, outbus, releaseTime = 0.3, rez_freq = 1000, rez_rq = 1|
	var env				=	Env.perc(0.01, releaseTime, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var lc				=	LinCongC.ar([freq, freq + 1], a).fold2(1 / foldfactor) * foldfactor * envgen * 0.5;
	//var delay			=	DelayC.ar(lc, delaytime, delaytime) * 0.5;
	var rez				=	Resonz.ar(lc, (rez_freq).clip(50, SampleRate.ir / 3), rez_rq) * rez_rq.reciprocal;
    Out.ar(outbus, (lc + rez));
}).add;
);

(
~prclvl = 0.2;
~prcecholvl = ~prclvl / 5;

Pdef(\prcpat1,
	Pbind(
		\instrument, \prc,
        //\a, Pshuf([0.8, 0.9, 1.2].stutter(11), inf),
        \a, 1.2,
        \curve, -8,
        //\delaytime, Pwhite(0.0001, 0.001, inf),
        \dur, Pshuf([0.75, 1, 1.5, 2, 3, 4, 6].stutter(7), inf),
        \foldfactor, Pshuf([4, 16, 64, 256].stutter(7), inf),
        \level, ~prclvl,
        \octave, 6,
        \outbus, ~prcbus,
        \rez_rq, 0.5,
		\root, ~root,
		\scale, ~scale,
		\rez_freq, 2000,
        //\rez_rq, Pshuf([0.25, 0.5].stutter(7), inf)
));

Pdef(\prcpat2, Pbindf(Pdef(\prcpat1), \a, 0.8));

Pdef(\prcpat3, Pbindf(Pdef(\prcpat1), \level, ~prcecholvl));

Pdef(\prcpar1, Ppar([Pdef(\prcpat1), Pdef(\prcpat2), Pdef(\prcpat3)]));

//

~prc3durs = [0.25, Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, Pseq([0.25], 4), Pseq([0.5], 2), 1, 1.5, 2, 3, 4, 6];
Pdef(\prc3,
    Pbind(
        \instrument, \prc,
        \a, Pshuf([1.4, 1.5, 1.6].stutter(4), inf),
        \c, Pshuf([0.01, 0.02, 0.04, 0.08, 0.16].stutter(6), inf),
        //\curve, Pshuf([-8, -2].stutter(7), inf),
        \delaytime, Pshuf([0.01, 0.02, 0.04].stutter(3), inf),
        \dur, Pshuf([0.75, 1, 1.5, 2], inf),
        \level, ~prclvl,
        \octave, Pseq([5, 9], inf),
        \outbus, ~prcbus
));

Pdef(\prc3a, Pbindf(Pdef(\prc3), \dur, Pxrand([0.75, 1, 1.5, 2], inf), \level, ~prcecholvl));

Pdef(\prcpar1b, Ppar([Pdef(\prc3), Pdef(\prc3a)]));
);

/*
Pdef(\prcpat1).play(~tempo);
Pdef(\prcpat1).isPlaying;
Pdef(\prcpat1).stop;
*/

/*
Pdef(\prcpar1).play(~tempo);
Pdef(\prcpar1).isPlaying;
Pdef(\prcpar1).stop;
*/

/*
Pdef(\prcpar1b).play(~tempo);
Pdef(\prcpar1b).isPlaying;
Pdef(\prcpar1b).stop;
*/

//

(
SynthDef(\kik, { |a = 1.4, c = 0.13, m = 1, dur = 1, fb = 0, ffreq = 1000, frq = 1, freq = 100, level = 0.1, outbus|
	var env				=	Env.perc(0.005, 1, level, -16);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lc				=	LinCongC.ar([freq, freq * 1.01], a, c, m, mul: envgen);
	var rhpf			=	RHPF.ar(lc, ffreq, frq, 2);
    var sin             =   SinOsc.ar(freq * XLine.kr(0.25, 0.125, dur) * (lc + 1), mul: envgen);
	Out.ar(outbus, lc + rhpf + sin);
}).add;
);

(
Pdef(\kikpat,
	Pbind(
		\instrument, \kik,
		\a, Pwhite(1.0, 2.0, inf).round(0.01),
        \dur, Pshuf(Array.fill(13, { |d| (d + 1) * 0.25 }) ++ [Pseq([7, 1, 1] /3)], inf),
		\ffreq, 1000,
		\frq, 0.1,
        \degree, [0, 7],
		\octave, 5,
        \outbus, ~prcbus,
		\root, ~root,
		\scale, ~scale
));
);

/*
Pdef(\kikpat).play(~tempo, quant: 1);
Pdef(\kikpat).isPlaying;
Pdef(\kikpat).stop;
*/

////

Pdef(\prcpar, Ppar([Pdef(\prcpar1), Pdef(\kikpat)]));

/*
Pdef(\prcpar).play(~tempo, quant: 1);
Pdef(\prcpar).isPlaying;
Pdef(\prcpar).stop;
*/

~midiktrl.value(\prcpar, 50);
~midiktrl.value(\prcpar1b, 82);

////////////////////////////////////////////////////////////////

(
SynthDef(\prc2, { |a = 1.0, curve = -16, dur = 1, freq = 440, level = 0.2, outbus, releaseTime = 1|
    var env             =   Env.perc(0.003, releaseTime, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var latoo           =   LatoocarfianC.ar([freq - 10, freq + 10], a, mul: XLine.kr(3, 0.1, 0.1), add: 1);
    var sin             =   SinOsc.ar(freq * latoo, mul: envgen);
    Out.ar(outbus, sin);
}).add;
);

(
Pdef(\prc2,
    Pbind(
        \instrument, \prc2,
        \a, Pxrand((1..3), inf),
        \curve, Prand([-32, -16], inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5].stutter(3) ++ [Pseq([1/3], 3)], inf),
        \octave, Prand([3, 4, 7], inf),
        \outbus, ~prcbus,
        \releaseTime, Prand([1, 1.5], inf),
        \scale,  ~scale
));

//Pdef(\prc2echo, Pbindf(Pdef(\prc2), \level, 0.01));

Pdef(\prcpar2, Ppar([Pdef(\prc2)], inf));
);

/*
Pdef(\prcpar2).play(~tempo);
Pdef(\prcpar2).isPlaying;
Pdef(\prcpar2).stop;
*/

~midiktrl.value(\prcpar2, 51);

////////////////////////////////////////////////////////////////

(
SynthDef(\banjo, {
	|curve = -8, dur = 1, fb = 0, foldfactor = 1, freq = 440, level = 0.05, outbus, rlpf_freq = 880, rlpf_rq = 1, rhpf_freq = 8800, rhpf_rq = 1, sawfreq = 100|
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var noiz			=	LFNoise0.kr(30!2).range(0.999, 1);
	var sin				=	SinOscFB.ar([freq, freq * 1.0005], fb).round(level / 2).fold2((level * noiz) / foldfactor) * (foldfactor * noiz) * envgen;
	var rlpf			=	RLPF.ar(sin, rlpf_freq.clip(50, SampleRate.ir / 3), rlpf_rq).fold2(level / foldfactor) * foldfactor;
	var rhpf 			=	RHPF.ar(sin, rhpf_freq.clip(50, SampleRate.ir / 3), rhpf_rq).fold2(level / foldfactor) * foldfactor;
	Out.ar(outbus, rlpf + rhpf);
}).add;
);

(
Pdef(\banjopat,
	Pbind(
		\instrument, \banjo,
		//\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 6], inf),
        \dur, Pshuf(Array.fill(17, { |d| (d + 0.25) }) ++ [Pseq([0.125], 4)], inf),
		\fb, Pwhite(0.0, 1.0, inf),
		\foldfactor, Pwhite(1, 20, inf),
        \degree, 0,
		\octave, Pwhite(4, 6, inf),
        \outbus, ~delaybus,
		\rlpf_freq, Pwhite(100.0, 10000.0, inf),
		\rlpf_rq, Pwhite(0.01, 1.0, inf),
		\rhpf_freq, Pwhite(1000.0, 15000.0, inf),
		\rhpf_rq, Pwhite(0.01, 1.0, inf),
		\root, ~root,
		\scale, ~scale,
        \timingOffset, Pwhite(-0.01, 0.01, inf)
));

Pdef(\banjopar, Ppar([Pdef(\banjopat)].stutter(4), inf));

Pdef(\banjo2, Pbindf(Pdef(\banjopat), \curve, -32, \degree, [0].stutter(2), \dur, 53));
);

/*
Pdef(\banjopat).play(~tempo);
Pdef(\banjopat).isPlaying;
Pdef(\banjopat).stop;
*/

/*
Pdef(\banjopar).play(~tempo, quant: 1);
Pdef(\banjopar).isPlaying;
Pdef(\banjopar).stop;
*/

/*
Pdef(\banjo2).play(~tempo);
Pdef(\banjo2).isPlaying;
Pdef(\banjo2).stop;
*/

~midiktrl.value(\banjopar, 66);
~midiktrl.value(\banjo2, 36);

////////////////////////////////////////////////////////////////

(
SynthDef(\pno, { |a = 1, b = 3, curve = -16, dur = 1, fb = 0, freq = 440, latfreq = 10000, level = 0.1, outbus, pan = 0|
    var env             =   Env.perc(0.003, dur, level: level, curve: curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var lat             =   Latoocarfian2DN.kr(a: [a, a - 0.002], b: [b, b - 0.002], mul: 1, add: 1).round(0.25);
	var sinfb           =   SinOscFB.ar(freq, fb, envgen * lat);
	var sin				=	SinOsc.ar(freq!2, pi /4, envgen);
    var rhpf            =   RHPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.05);
    Out.ar(outbus, rhpf + sin);
}).add;
);

(
Pdef(\pnopat,
    Pbind(
        \instrument, \pno,
        \a, Pwhite(-3.0, 3.0, inf),
        \b, Pwhite(-3.0, 3.0, inf),
        \curve, -16,
        \dur, Pshuf([23, 25, 27], inf),
        \fb, 2,
        \level, 0.005,
        \degree, [2, 7, 10, 12],
        \octave, 5,
        \outbus, ~prcbus,
        \root, ~root,
        \scale, ~scale,
));
);

/*
Pdef(\pnopat).play(~tempo, quant: 1);
Pdef(\pnopat).isPlaying;
Pdef(\pnopat).stop;
*/

~midiktrl.value(\pnopat, 35);

////////////////////////////////////////////////////////////////

(
SynthDef(\stringdelayktrl, {|delaytime = 0.01, dur = 1, outbus = 0|
	var setdelaytime	=	Line.kr(delaytime, delaytime, dur, doneAction: 2);
	Out.kr(outbus, setdelaytime);
}).add;
);

~setdelaytimedursshort = [2, 3].collect({ |d| Pseq([d.reciprocal], d) });
~setdelaytimedurslong = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13] + 0.25;
~setdelaytimedurs = ~setdelaytimedursshort ++ ~setdelaytimedurslong;

(
Pdef(\stringchords1setdelaytime,
	Pbind(
		\instrument,\stringdelayktrl,
		\delaytime, Pbrown(0.0001, 0.01, 0.001, inf),
        \dur, Pshuf(~setdelaytimedurs, inf),
		\legato, 1,
		\outbus, ~stringchords1delayktrlbus,
));

Pdef(\stringchords2setdelaytime, Pbindf(Pdef(\stringchords1setdelaytime), \outbus, ~stringchords2delayktrlbus));

Pdef(\stringchords3setdelaytime, Pbindf(Pdef(\stringchords1setdelaytime), \outbus, ~stringchords3delayktrlbus));

Pdef(\stringchords4setdelaytime, Pbindf(Pdef(\stringchords1setdelaytime), \outbus, ~stringchords4delayktrlbus));
);

/*
Pdef(\stringchords1setdelaytime).play(~tempo);
Pdef(\stringchords1setdelaytime).isPlaying;
Pdef(\stringchords1setdelaytime).stop;
*/

/*
Pdef(\stringchords2setdelaytime).play(~tempo);
Pdef(\stringchords2setdelaytime).isPlaying;
Pdef(\stringchords2setdelaytime).stop;
*/

/*
Pdef(\stringchords3setdelaytime).play(~tempo);
Pdef(\stringchords3setdelaytime).isPlaying;
Pdef(\stringchords3setdelaytime).stop;
*/

/*
Pdef(\stringchords4setdelaytime).play(~tempo);
Pdef(\stringchords4setdelaytime).isPlaying;
Pdef(\stringchords4setdelaytime).stop;
*/

////////////////////////////////////////////////////////////////
// STRING

(
SynthDef(\string, { |attack = 0.01, curve = -4, delaytime = 0.01, dur = 1, foldmod_freq_min = 0.1, foldmod_freq_max = 10, foldmod_min = 0.05, foldmod_max = 0.2, freq = 440, gate = 1, level = 0.01, outbus, release = 0.1, widthmod_freq_min = 0.1, widthmod_freq_max = 1, widthmod_min = 0, widthmod_max = 1|
    var env             =   Env.asr(attack, level, release, curve);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var widthmod        =   LFBrownNoise2.kr(dur.reciprocal).range(widthmod_min, widthmod_max);
    var foldmod         =   LFClipNoise.kr(LFNoise2.kr(0.1!2).range(foldmod_freq_min, foldmod_freq_max)).range(foldmod_min, foldmod_max);
    var osc             =   VarSaw.ar(freq, width: widthmod).fold2(foldmod) * foldmod.reciprocal * envgen;
    var delay           =   DelayC.ar(osc, 1, delaytime.clip(0.00008, 0.1));
    //var sin             =   SinOsc.ar(freq ! 2).round(0.02) * envgen * 0.03;
    Out.ar(outbus, (osc + delay).fold2(level));
}).add;
);

//

(
~stringchords = [[-5, -2, 0, 4, 6], [-2, 0, 4, 6, 7], [0, 4, 6, 7, 10], [4, 6, 7, 10, 12], [6, 7, 10, 12, 16]].collect({ |c| c.stutter(4) });

Pdef(\stringchords1,
    Pmono(
        \string,
        \curve, 0,
        \degree, Pshuf(~stringchords, inf),
        \delaytime, ~stringchords1delayktrlbus.asMap,
        //\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24], inf),
        \dur, Pshuf([31, 33, 35, 37, 39], inf),
        \foldmod_freq_min, 0.1,
        \foldmod_freq_max, 10,
        \foldmod_min, Pwhite(0.1, 0.25, inf),
        \foldmod_max, Pwhite(0.25, 0.5, inf),
        \octave, 5,
        \outbus, ~companderbus,
        \scale, ~scale,
        \widthmod_freq_min, 0.1,
        \widthmod_freq_min, 10,
        \widthmod_min, 0,
        \widthmod_max, 1
));

/*
Pdef(\stringchords2,
    Pbindf(
        Pdef(\stringchords1),
        \delaytime, ~stringchords2delayktrlbus.asMap,
        \dur, 53,
        \octave, 6,
        \widthmod_min, 1,
        \widthmod_max, Pkey(\widthmod_min)
));
*/

Pdef(\stringchords3,
    Pbindf(
        Pdef(\stringchords1),
        \degree, [0, 7, 12].stutter(5),
        \delaytime, ~stringchords3delayktrlbus.asMap,
        \dur, 53,
        \octave, 4,
        \widthmod_min, 1,
        \widthmod_max, Pkey(\widthmod_min)
));

Pdef(\stringchords4,
    Pbindf(
        Pdef(\stringchords1),
        \delaytime, ~stringchords4delayktrlbus.asMap,
        \degree, [0].stutter(10),
        \foldmod_min, 0.25,
        \foldmod_max, Pkey(\foldmod_min),
        \widthmod_min, 0.5,
        \widthmod_max, 0.6,
        \octave, [2, 3]
));
);

/*
Pdef(\stringchords1).play(~tempo);
Pdef(\stringchords1).isPlaying;
Pdef(\stringchords1).stop;
*/

/*
Pdef(\stringchords2).play(~tempo);
Pdef(\stringchords2).isPlaying;
Pdef(\stringchords2).stop;
*/

/*
Pdef(\stringchords3).play(~tempo);
Pdef(\stringchords3).isPlaying;
Pdef(\stringchords3).stop;
*/

/*
Pdef(\stringchords4).play(~tempo);
Pdef(\stringchords4).isPlaying;
Pdef(\stringchords4).stop;
*/

~midiktrl.value(\stringchords1, 52);
//~midiktrl.value(\stringchords2, 68);
~midiktrl.value(\stringchords3, 37);
~midiktrl.value(\stringchords4, 53);

////////////////////////////////////////////////////////////////
// SCENES

(
~scenetoggle = { |scene, light, starters, stoppers, starterlights, stopperlights|
    var scenestatus;
    MIDIdef.cc(scene, {
        if(scenestatus.isNil) {
            ~midiout.control(0, light, 127);
            starterlights.do({ |l| ~midiout.noteOn(0, l, 127) });
            starters.do({ |s| Pdef(s).play(~tempo) });
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
~scenetoggle2 = { |scene, light, starters, stoppers, starterlights, stopperlights|
    var scenestatus;
    MIDIdef.noteOn(scene, {
        if(scenestatus.isNil) {
            ~midiout.noteOn(0, light, 127);
            starterlights.do({ |l| ~midiout.noteOn(0, l, 127) });
            starters.do({ |s| Pdef(s).play(~tempo) });
            stopperlights.do({ |l| ~midiout.noteOff(0, l) });
            stoppers.do({ |s| Pdef(s).stop });
            scenestatus = "playing";
        } {
            ~midiout.noteOn(0, light, 0);
            starters.do({ |s| Pdef(s).stop });
            starterlights.do({ |l| ~midiout.noteOff(0, l) });
            scenestatus = nil;
        }
    }, light, srcID: ~lpm.uid, argTemplate: { |a| a > 0 });
}
);

(
~scene1 = [\basspat1, \prcpar];
~scene1lights = [49, 50];
~scenetoggle.value(\scene1, 104, ~scene1, starterlights: ~scene1lights);
);

(
~scene2 = [\sin, \hat2, \bass2, \prcpar1b];
~scene2lights = [17,33, 65, 82];
~scene2stoppers = [\pulsepat1a, \basspat1, \hatpar, \prcpar];
~scene2stopperlights = [32, 49, 34, 50];
~scenetoggle.value(\scsne2, 105, ~scene2, ~scene2stoppers, ~scene2lights, ~scene2stopperlights);
);

(
~scene3 = [\pulsepat1a, \pulsepat2a, \basspat1, \hatpar, \pnopat, \prcpar, \banjopar];
~scene3lights = [32, 48, 49, 34, 35, 50, 66];
~scene3stoppers = [\sin, \hat2, \bass2, \prcpar1b];
~scene3stopperlights = [17, 33, 65, 82];
~scenetoggle.value(\scene3, 106, ~scene3, ~scene3stoppers, ~scene3lights, ~scene3stopperlights);
);

(
~scene4 = [\sin, \hat2, \bass2, \prcpar1b];
~scene4lights = [17, 33, 65, 82];
~scene4stoppers = [\pulsepat1a, \pulsepat2a, \basspat1, \hatpar, \prcpar];
~scene4stopperlights = [32, 48, 49, 34, 50];
~scenetoggle.value(\scene4, 107, ~scene4, ~scene4stoppers, ~scene4lights, ~scene4stopperlights);
);

(
~scene5 = [\pulsepat1a, \pulsepat2a, \pulsepat3a, \basspat1, \hatpar, \prcpar];
~scene5lights = [32, 48, 64, 49, 34, 50];
~scene5stoppers = [\sin, \hat2, \bass2, \prcpar1b];
~scene5stopperlights = [17, 33, 65, 82];
~scenetoggle.value(\scene5, 108, ~scene5, ~scene5stoppers, ~scene5lights, ~scene5stopperlights);
);

(
~scene6 = [\sin, \hat2, \bass2, \prcpar1b];
~scene6lights = [17, 33, 65, 82];
~scene6stoppers = [\pulsepat1a, \pulsepat2a, \pulsepat3a, \basspat1, \hatpar, \prcpar];
~scene6stopperlights = [32, 48, 64, 49, 34, 50];
~scenetoggle.value(\scene6, 109, ~scene6, ~scene6stoppers, ~scene6lights, ~scene6stopperlights);
);

(
~scene7 = [\basspat3, \prcpar2, \pingpat, \banjo2, \stringchords1];
~scene7lights = [81, 51, 67, 36, 52];
~scene7stoppers = [\sin, \basspat1, \pulsepat1a, \hat2, \bass2, \hatpar, \prcpar1b, \banjopar];
~scene7stopperlights = [17, 49, 32, 33, 65, 34, 82, 66];
~scenetoggle.value(\scene7, 110, ~scene7, ~scene7stoppers, ~scene7lights, ~scene7stopperlights);
);

/*
(
~scene8 = [\stringchords2];
~scene8lights = [68];
~scene8stoppers = nil;
~scene8stopperlights = nil;
~scenetoggle.value(\scene8, 111, ~scene8, ~scene8stoppers, ~scene8lights, ~scene8stopperlights);
);
*/

(
~scene9 = [\stringchords3];
~scene9lights = [37];
~scene9stoppers = nil;
~scene9stopperlights = nil;
~scenetoggle2.value(\scene9, 8, ~scene9, ~scene9stoppers, ~scene9lights, ~scene9stopperlights);
);

(
~scene10 = [\pulsepat1a, \stringchords4];
~scene10lights = [32, 53];
~scene10stoppers = [\basspat3, \hatpar];
~scene10stopperlights = [81, 34];
~scenetoggle2.value(\scene10, 24, ~scene10, ~scene10stoppers, ~scene10lights, ~scene10stopperlights);
);

(
~scene11stoppers = [\pulsepat1a, \prcpar2, \pnopat, \pingpat, \stringchords3];
~scene11stopperlights = [32, 51, 35, 67, 37];
~scenetoggle2.value(\scene11, 40, stoppers: ~scene11stoppers, stopperlights: ~scene11stopperlights);
);

(
~scene12stopper = [\stringchords4];
~scene12stopperlight = [53];
~scenetoggle2.value(\scene12, 56, stoppers: ~scene12stopper, stopperlights: ~scene12stopperlight);
);

(
//~endstoppers = [\sin, \banjo2, \stringchords2, \stringchords3];
~endstoppers = [\sin, \banjo2, \stringchords1];
//~endstopperlights = [17, 36, 68, 37];
~endstopperlights = [17, 36, 52];
~scenetoggle2.value(\end, 72, stoppers: ~endstoppers, stopperlights: ~endstopperlights);
);

////////////////////////////////
// start up the effects
(
{
    s.sync;
    Pdef(\delay).play(t);
    Pdef(\dynamix).play(t);
    Pdef(\limiter).play(t);
}.fork;
);

(
{
    s.sync;
    Pdef(\stringchords1setdelaytime).play(~tempo);
    Pdef(\stringchords2setdelaytime).play(~tempo);
    Pdef(\stringchords3setdelaytime).play(~tempo);
    Pdef(\stringchords4setdelaytime).play(~tempo);
    //Pdef(\stringchords5setdelaytime).play(~tempo);
}.fork;
);

/*
Pdef(\stringchords1setdelaytime).isPlaying;
Pdef(\stringchords2setdelaytime).isPlaying;
Pdef(\stringchords3setdelaytime).isPlaying;
Pdef(\stringchords4setdelaytime).isPlaying;
Pdef(\stringchords5setdelaytime).isPlaying;
*/
