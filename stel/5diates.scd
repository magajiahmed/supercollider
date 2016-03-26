Pdef.removeAll;

// pitch logic
(
~root = 0;
~ratios = [1/1, 16/15, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 5/3, 7/4, 15/8];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new((0..11), 12, ~tuning);
);

// time
~tempo = TempoClock(100/60);

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
	var compressor	=	Compander.ar(in, in, thresh: 0.5, clampTime: 0.002, slopeAbove: 1/8);
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
Pdef(\limiter, Pmono(\limiter, \dur, ~delay / 2, \inBus, ~prcbus, \level, 0.3, \outbus, 0));
);

////////////////////////////////////////////////////////////////
// BASS

(
SynthDef(\bass, { |curve = -2, dur = 1, fb = 0, freq = 440, k = 1, level = 0.2, outbus, roundmod_freq = 1, sinfb_line_start = 1, sinfb_line_end = 1, sinfb_round = 0.1|
	var env				=	Env.perc(0.01, dur, level, curve).kr(2);
	var imp				=	Impulse.ar(0!2, mul: level);
    var comb			=	CombL.ar(imp, (freq).reciprocal, (freq).reciprocal, 15, env * 2);
    var leakdc          =   LeakDC.ar(comb);
    var roundmod        =   LFBrownNoise2.kr(roundmod_freq!2, mul: 1, add: 1);
    var sinfb			=	SinOscFB.ar(freq * LFNoise2.kr(17!2, 0.005, 1), fb * LFBrownNoise2.kr(0.2!2, mul: 1, add: 1)).round(sinfb_round * 0.25 * roundmod).round(sinfb_round * 0.5 * roundmod).round(sinfb_round * roundmod) * (env * 0.5);
    var tri             =   LFTri.ar(freq * 0.5 * LFNoise2.kr(0.2!2, 0.005, 1)).round(sinfb_round * 0.25 * LFBrownNoise2.kr(0.2!2, mul: 1, add: 1)) * (env * 0.5);
    Out.ar(outbus, leakdc + sinfb + tri);
}).add;
);

(
Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
        \curve, Prand([-8, -2], inf),
        \degree, Pseq([Pshuf([[0]!2].stutter(7) ++ [[-1]!2] ++ [[1]!2] ++ [[2]!2], 4), Pseq([Rest], 20)], inf),
        \dur, Pshuf([0.25, Pseq([0.25], 2), 0.5, 0.75, 1, 6].stutter(7), inf),
        //\dur, Pshuf([Pseq([2/3], 3), Pshuf(Array.fill(23, { |d| (d + 1) * 0.25 }))], inf),
        \fb, Prand([0, 0.5, 1], inf),
        \k, Pwhite(0.9, 1.1, inf),
        \octave, 3,
        \outbus, ~delaybus,
		\root, ~root,
		\scale, ~scale,
        \roundmod_freq, Prand([0.1, 0.5, 1], inf),
        \sinfb_line_start, Prand([0.0, 0.1, 0.5, 1.0], inf),
        \sinfb_line_end, Prand([0.0, 0.1, 0.25, 0.5, 1.0], inf),
        \sinfb_round, Pshuf([0.01, 0.05, 0.1, 0.5], inf),
));
);

/*
Pdef(\basspat1).play(~tempo);
Pdef(\basspat1).isPlaying;
Pdef(\basspat1).stop;
*/

(
Pdef(\basspat2,
    Pbind(
        \instrument, \bass,
        \degree, Pseq([[0, 7], Rest, [0, 7], Rest, Rest, [0, 7], Rest, Rest, Rest], inf),
        \dur, Pseq([1, 5, 1, 4, 3, 1, 4, 3, 2] + 0.25, inf),
        \level, 0.3,
        \octave, 3,
        \outbus, ~delaybus,
        \root, ~root,
        \scale, ~scale
));
);

/*
Pdef(\basspat2).play(~tempo);
Pdef(\basspat2).isPlaying;
Pdef(\basspat2).stop;
*/

~midiktrl.value(\basspat1, 49);
~midiktrl.value(\basspat2, 65);

////////////////////////////////////////////////////////////////

(
SynthDef(\hat, { |curve = -16, dur = 1, fb = 0, freq = 440, level = 0.03, outbus|
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise0.kr(50!2, 0.002, 1);
    var fbmod           =   LFBrownNoise0.ar(31!2, mul: 0.5, add: 1);
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
        //\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].stutter(3), inf),
        \dur, Pshuf(Array.fill(17, { |i| (i + 1) * 0.25 }), inf),
		\fb, Pshuf(Array.series(10, 0.1, 0.1), inf),
		\level, 0.05,
		\degree, 0,
		\octave, 9,
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
~pulselvl = 0.03;
~pulseecholvl = ~pulselvl / 4;
Pdef(\pulsepat1a,
	Pbind(
		\instrument, \hat,
        \curve, Prand([-64, -16, -4], inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 4, 6, 8, 12, 16, 24].stutter(11), inf),
		\fb, Pwhite(2.7, 3.2, inf),
		\level, ~pulselvl,
        \degree, Prand([[-6, -5, -1, 0]] ++ [[-5, 0]].stutter(7) ++ [[-5, -4, 0, 1]], inf),
		\octave, 4,
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
        \degree, Prand([[0, 7, 9, 11, 12, 13]] ++ [[0, 7, 10, 12, 14]].stutter(9) ++ [[0, 7, 11, 12, 13, 15]], inf)
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

(
Pdef(\hat2,
    Pbind(
        \instrument, \hat,
        \curve, -64,
        \degree, [0, 2, 7, 10, 12],
        //\dur, Pshuf(Array.fill(11, { |d| (d + 7) * 0.25 }), inf),
        \dur, Pshuf([0.25, 0.5, 0.75, Pseq([1/5], 5), Pseq([1/3], 3), 1, 1.25, 1.5, 1.75].stutter(2), inf),
        \level, Pshuf([0.2, 1].stutter(7) * 0.02, inf),
        \octave, [8, 9, 10],
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
Pdef(\pingpat,
    Pbind(
        \instrument, \hat,
        \curve, 0,
        \dur, Pshuf([1.25, 1.5, 1.75, 2.25], inf),
        \degree, Pseq([
            Rest, Rest, [2, 7, 10, 12], [2, 7, 10, 12], [2, 7, 10, 12],
            Rest, Rest, Rest, [2, 7, 10, 12], [2, 7, 10, 12], [2, 7, 10, 12],
            Rest, Rest, Rest, Rest, [2, 7, 10, 12], [2, 7, 10, 12], [2, 7, 10, 12]
        ], inf),
        \level, 0.01,
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
	|a = 1.1, curve = -4, dur = 1, foldfactor = 2, freq = 440, level = 0.2, outbus, releaseTime = 0.3, rez_freq = 1000, rez_rq = 1|
	var env				=	Env.perc(0.01, releaseTime, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
    var lc				=	LinCongC.ar([freq, freq + 1], a).fold2(1 / foldfactor) * foldfactor * envgen;
	//var delay			=	DelayC.ar(lc, 0.2, freq.reciprocal);
	var rez				=	Resonz.ar(lc, (rez_freq).clip(50, SampleRate.ir / 3), rez_rq) * rez_rq.reciprocal;
	Out.ar(outbus, lc + rez);
}).add;
);

(
//~degrees = [2, 7, 10, 12].powerset.reject({ |d| d.isEmpty });
Pdef(\prcpat1,
	Pbind(
		\instrument, \prc,
        \a, Pshuf([0.8, 0.9, 1.0, 1.1, 1.2], inf),
        \curve, -8,
        \degree, Pseq([Rest, 0], inf),
        \dur, Pshuf([0.75, 1, 1.25, 1.5, 3], inf),
        //\foldfactor, Pshuf([100, 200, 400, 800], inf),
        \foldfactor, Pwhite(200, 800, inf),
        \level, 0.2,
        \octave, 6,
        \outbus, ~prcbus,
        \rez_rq, 0.5,
		\root, ~root,
		\scale, ~scale,
		\rez_freq, 2000,
        //\rez_rq, Pshuf([0.25, 0.5].stutter(7), inf)
));

Pdef(\prcpat2, Pbindf(Pdef(\prcpat1), \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75], inf), \level, 0.04));

Pdef(\prcpar1, Ppar([Pdef(\prcpat1), Pdef(\prcpat2)]));
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

//

(
SynthDef(\kik, { |a = 1.4, c = 0.13, m = 1, dur = 1, fb = 0, ffreq = 1000, frq = 1, freq = 100, level = 0.2, outbus|
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
        \dur, Pshuf(Array.fill(17, { |d| (d + 1) * 0.25 }), inf),
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
~midiktrl.value(\prcpar2, 51);

////////////////////////////////////////////////////////////////

(
SynthDef(\prc2, { |a = 1.0, curve = -16, dur = 1, freq = 440, level = 0.3, outbus, releaseTime = 1|
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
        \dur, Pshuf([0.25, 0.5, 0.75, Pseq([0.375], 2), 1, 1.5, 2, 3, 4, 6], inf),
        \octave, Prand([3, 4, 7], inf),
        \outbus, ~prcbus,
        \releaseTime, Prand([1, 1.5], inf),
        \scale,  ~scale
));

Pdef(\prc2echo, Pbindf(Pdef(\prc2), \dur, Prand([0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2], inf), \level, 0.1));

Pdef(\prcpar2, Ppar([Pdef(\prc2), Pdef(\prc2echo)], inf));
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
        \dur, Pshuf(Array.fill(17, { |d| (d + 0.25) }), inf),
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
));

Pdef(\banjopar, Ppar([Pdef(\banjopat)].stutter(3), inf));

Pdef(\banjo2, Pbindf(Pdef(\banjopat), \dur, 101));
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
~midiktrl.value(\banjopat, 36);

////////////////////////////////////////////////////////////////

(
SynthDef(\pno, { |a = 1, b = 3, curve = -16, dur = 1, fb = 0, freq = 440, latfreq = 10000, level = 0.15, outbus, pan = 0|
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
        \dur, Pshuf([13, 17, 19], inf),
        \fb, 2,
        \level, 0.005,
        \degree, [2, 7, 10, 12],
        \octave, [4, 5, 7],
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
SynthDef(\string, { |delaytime = 0.01, dur = 1, fb1 = 0, fb2 = 0, freq = 440, gate = 1, level = 0.03, outbus, release = 0.1, xlinestart = 1|
    var env             =   Env.asr(0.01, level, release);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var xline           =   XLine.kr(xlinestart, 1, dur / 4);
    var fbmod           =   SinOscFB.ar(freq * xline, 0, 1, 1);
    var carrier         =   SinOscFB.ar(freq * LFNoise2.kr(0.2!2, 0.001, 1), fbmod).round(0.5) * envgen;
    var rhpf            =   RHPF.ar(carrier, (freq * 4).clip(50, SampleRate.ir / 2.5));
    var delay           =   DelayC.ar(carrier + rhpf, 1, delaytime.clip(0.00008, 0.1));
    Out.ar(outbus, carrier + rhpf + delay);
}).add;
);

(
SynthDef(\stringdelayktrl, {|delaytime = 0.01, dur = 1, outbus = 0|
	var setdelaytime	=	Line.kr(delaytime, delaytime, dur, doneAction: 2);
	Out.kr(outbus, setdelaytime);
}).add;
);

//

(
~setdelaytimedursshort = [2, 3].collect({ |d| Pseq([d.reciprocal], d) });
~setdelaytimedurslong = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13] + 0.25;
~setdelaytimedurs = ~setdelaytimedursshort ++ ~setdelaytimedurslong;

Pdef(\stringpat0setdelaytime,
	Pbind(
		\instrument,\stringdelayktrl,
		\delaytime, Pbrown(0.0001, 0.01, 0.001, inf),
        \dur, Pshuf(~setdelaytimedurs, inf),
		\legato, 1,
		\outbus, ~stringpat0delayktrlbus,
));

Pdef(\stringpat0,
    Pmono(
		\string,
		\delaytime, ~stringpat0delayktrlbus.asMap,
		\dur, 5,
		\degree, [-5, 0],
        \fb1, 1,
        \fb2, 1,
        \outbus, ~companderbus,
        \release, 0.1,
		\root, ~root,
		\scale, ~scale,
		\xlinestart, 1
));
);

/*
Pdef(\stringpat0setdelaytime).play(~tempo);
Pdef(\stringpat0setdelaytime).isPlaying;
Pdef(\stringpat0setdelaytime).stop;
*/

/*
Pdef(\stringpat0).play(~tempo);
Pdef(\stringpat0).isPlaying;
Pdef(\stringpat0).stop;
*/

(
Pdef(\stringpat1setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat1delayktrlbus,
));

/*
~chords = [
	[-5, -2, 0], [-5, 0, 0], [-5, 0, 1], [-5, 0, 2], [0, 3, 7], [0, 6, 7], [0, 7, 7]
];
*/
~chords = [[-5, -2, 0], [-5, 0, 0], [-5, 0, 2], [0, 3, 7], [0, 5, 7], [0, 6, 7], [0, 7, 7]];

Pdef(\stringpat1,
	Pbind(
		\instrument, \string,
		\degree, Pshuf(~chords, inf),
		\delaytime, ~stringpat1delayktrlbus.asMap,
		\dur, Pshuf(Array.fill(5, { |i| (i + 7).nthPrime }), inf),
        \fb1, 1,
        \fb2, 1,
		\legato, 1,
		\octave, 6,
        \outbus, ~companderbus,
		\root, ~root,
		\scale, ~scale,
        \xlinestart, Pshuf([1/2, 2/1].stutter(5), inf),
));
);

/*
Pdef(\stringpat1setdelaytime).play(~tempo, quant: 1);
Pdef(\stringpat1setdelaytime).isPlaying;
Pdef(\stringpat1setdelaytime).stop;
*/

/*
Pdef(\stringpat1).play(~tempo, quant: 1);
Pdef(\stringpat1).isPlaying;
Pdef(\stringpat1).stop;
*/

(
Pdef(\stringpat2setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat2delayktrlbus,
));

Pdef(\stringpat2,
	Pbindf(
		Pdef(\stringpat1),
		\delaytime, ~stringpat2delayktrlbus.asMap,
        \degree, Pshuf([[-5, 0], [0, 7]], inf),
        \octave, 6
));
);

/*
Pdef(\stringpat2setdelaytime).play(~tempo, quant: 1);
Pdef(\stringpat2setdelaytime).isPlaying;
Pdef(\stringpat2setdelaytime).stop;
*/

/*
Pdef(\stringpat2).play(~tempo, quant: 1);
Pdef(\stringpat2).isPlaying;
Pdef(\stringpat2).stop;
*/

(
Pdef(\stringpat3setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat3delayktrlbus,
));

Pdef(\stringpat3,
	Pbindf(
		Pdef(\stringpat2),
		\delaytime, ~stringpat3delayktrlbus.asMap,
        \degree, Pshuf([[-2, 2], [2, 10]], inf),
		\octave, 6
));
);

/*
Pdef(\stringpat3setdelaytime).play(~tempo, quant: 1);
Pdef(\stringpat3setdelaytime).isPlaying;
Pdef(\stringpat3setdelaytime).stop;
*/

/*
Pdef(\stringpat3).play(~tempo, quant: 1);
Pdef(\stringpat3).isPlaying;
Pdef(\stringpat3).stop;
*/

(
Pdef(\stringpat4setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat4delayktrlbus,
));

Pdef(\stringpat4,
	Pbindf(
		Pdef(\stringpat2),
		\delaytime, ~stringpat4delayktrlbus.asMap,
        \degree, Pshuf([[-5, 0], [0, 7]], inf),
		\octave, 4
));
);

/*
Pdef(\stringpat4setdelaytime).play(~tempo, quant: 1);
Pdef(\stringpat4setdelaytime).isPlaying;
Pdef(\stringpat4setdelaytime).stop;
*/

/*
Pdef(\stringpat4).play(~tempo, quant: 1);
Pdef(\stringpat4).isPlaying;
Pdef(\stringpat4).stop;
*/

(
Pdef(\stringpat5setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat5delayktrlbus,
));

Pdef(\stringpat5,
	Pbindf(Pdef(\stringpat2),
		\delaytime, ~stringpat5delayktrlbus.asMap,
        \degree, Pshuf([[-5, 0], [0, 7]], inf),
		\octave, 4,
));
);

/*
Pdef(\stringpat5setdelaytime).play(~tempo, quant: 1);
Pdef(\stringpat5setdelaytime).isPlaying;
Pdef(\stringpat5setdelaytime).stop;
*/

/*
Pdef(\stringpat5).play(~tempo, quant: 1);
Pdef(\stringpat5).isPlaying;
Pdef(\stringpat5).stop;
*/

(
Pdef(\stringpat6setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat6delayktrlbus,
));

Pdef(\stringpat6,
	Pbindf(Pdef(\stringpat2),
		\delaytime, ~stringpat6delayktrlbus.asMap,
        \degree, Pshuf([[-5, 0], [0, 7]], inf),
		\octave, 7,
));
);

/*
Pdef(\stringpat6setdelaytime).play(~tempo, quant: 1);
Pdef(\stringpat6setdelaytime).isPlaying;
Pdef(\stringpat6setdelaytime).stop;
*/

/*
Pdef(\stringpat6).play(~tempo, quant: 1);
Pdef(\stringpat6).isPlaying;
Pdef(\stringpat6).stop;
*/

(
Pdef(\stringpat7setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat7delayktrlbus,
));

Pdef(\stringpat7,
	Pbindf(Pdef(\stringpat2),
		\delaytime, ~stringpat7delayktrlbus.asMap,
        \degree, Pshuf([[-2, 2], [2, 10]], inf),
		\octave, 7
));
);

/*
Pdef(\stringpat7setdelaytime).play(~tempo, quant: 1);
Pdef(\stringpat7setdelaytime).isPlaying;
Pdef(\stringpat7setdelaytime).stop;
*/

/*
Pdef(\stringpat7).play(~tempo, quant: 1);
Pdef(\stringpat7).isPlaying;
Pdef(\stringpat7).stop;
*/

(
Pdef(\stringpat8setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat8delayktrlbus,
));

Pdef(\stringpat8,
	Pbindf(Pdef(\stringpat2),
		\delaytime, ~stringpat8delayktrlbus.asMap,
        \degree, [0, 12, 19],
        \octave, 2,
		\xlinestart, 1.01
));
);

/*
Pdef(\stringpat8setdelaytime).play(~tempo, quant: 1);
Pdef(\stringpat8setdelaytime).isPlaying;
Pdef(\stringpat8setdelaytime).stop;
*/

/*
Pdef(\stringpat8).play(~tempo, quant: 1);
Pdef(\stringpat8).isPlaying;
Pdef(\stringpat8).stop;
*/

(
Pdef(\stringpat9setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat9delayktrlbus,
));

Pdef(\stringpat9,
	Pbindf(Pdef(\stringpat2),
		\delaytime, ~stringpat9delayktrlbus.asMap,
        \degree, [0, 12, 19],
        \octave, 2,
		\xlinestart, 0.99
));
);

/*
Pdef(\stringpat9setdelaytime).play(~tempo, quant: 1);
Pdef(\stringpat9setdelaytime).isPlaying;
Pdef(\stringpat9setdelaytime).stop;
*/

/*
Pdef(\stringpat9).play(~tempo, quant: 1);
Pdef(\stringpat9).isPlaying;
Pdef(\stringpat9).stop;
*/


//

~midiktrl.value(\stringpat0, 52);
~midiktrl.value(\stringpat1, 68);
~midiktrl.value(\stringpat2, 37);
~midiktrl.value(\stringpat3, 53);
~midiktrl.value(\stringpat4, 69);
~midiktrl.value(\stringpat5, 38);
~midiktrl.value(\stringpat6, 54);
~midiktrl.value(\stringpat7, 70);
~midiktrl.value(\stringpat8, 39);
~midiktrl.value(\stringpat9, 55);

(
{
    s.sync;
    Pdef(\stringpat0setdelaytime).play(~tempo);
    Pdef(\stringpat1setdelaytime).play(~tempo);
    Pdef(\stringpat2setdelaytime).play(~tempo);
    Pdef(\stringpat3setdelaytime).play(~tempo);
    Pdef(\stringpat4setdelaytime).play(~tempo);
    Pdef(\stringpat5setdelaytime).play(~tempo);
    Pdef(\stringpat6setdelaytime).play(~tempo);
    Pdef(\stringpat7setdelaytime).play(~tempo);
    Pdef(\stringpat8setdelaytime).play(~tempo);
    Pdef(\stringpat9setdelaytime).play(~tempo);
}.fork;
);

/*
Pdef(\stringpat0setdelaytime).isPlaying;
*/

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
~scene1 = [\basspat1, \prcpar];
~scene1lights = [49, 50];
~scenetoggle.value(\scene1, 104, ~scene1, starterlights: ~scene1lights);
);

(
~scene2 = [\hat2];
~scene2lights = [33];
~scene2stoppers = [\pulsepat1a, \hatpar];
~scene2stopperlights = [32, 34];
~scenetoggle.value(\scsne2, 105, ~scene2, ~scene2stoppers, ~scene2lights, ~scene2stopperlights);
);

(
~scene3 = [\pulsepat1a, \pulsepat2a, \hatpar, \pnopat, \banjopar];
~scene3lights = [32, 48, 34, 35, 66];
~scene3stoppers = [\hat2];
~scene3stopperlights = [33];
~scenetoggle.value(\scene3, 106, ~scene3, ~scene3stoppers, ~scene3lights, ~scene3stopperlights);
);

(
~scene4 = [\hat2];
~scene4lights = [33];
~scene4stoppers = [\pulsepat1a, \pulsepat2a, \hatpar];
~scene4stopperlights = [32, 48, 34];
~scenetoggle.value(\scene4, 107, ~scene4, ~scene4stoppers, ~scene4lights, ~scene4stopperlights);
);

(
~scene5 = [\pulsepat1a, \pulsepat2a, \pulsepat3a, \hatpar, \prcpar2];
~scene5lights = [32, 48, 64, 34, 51];
~scene5stoppers = [\hat2];
~scene5stopperlights = [33];
~scenetoggle.value(\scene5, 108, ~scene5, ~scene5stoppers, ~scene5lights, ~scene5stopperlights);
);

(
~scene6 = [\basspat2];
~scene6lights = [65];
~scene6stoppers = [\pulsepat2a, \pulsepat3a, \hatpar, \prcpar];
~scene6stopperlights = [48, 64, 34, 50];
~scenetoggle.value(\scene6, 109, ~scene6, ~scene6stoppers, ~scene6lights, ~scene6stopperlights);
);

(
~scene7 = [\pingpat, \banjopat, \stringpat0];
~scene7lights = [67, 36, 52];
~scene7stoppers = [\pulsepat1a, \hatpar, \prcpar, \banjopar];
~scene7stopperlights = [32, 34, 50, 66];
~scenetoggle.value(\scene7, 110, ~scene7, ~scene7stoppers, ~scene7lights, ~scene7stopperlights);
);

(
~scene8 = [\stringpat1];
~scene8lights = [68];
~scene8stoppers = [\basspat1];
~scene8stopperlights = [49];
~scenetoggle.value(\scene8, 111, ~scene8, ~scene8stoppers, ~scene8lights, ~scene8stopperlights);
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