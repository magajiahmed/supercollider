Pdef.removeAll;

//midi
//
MIDIClient.init;
MIDIIn.connectAll;
MIDIdef.freeAll;
MIDIdef.cc(\midiccpostln, { |...args| args.postln });
~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("nanoKONTROL2")};
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~nanoktrl2.isNil) { ~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("out0") } };

(
~root = 7;
~ratios = [1/1, 256/243, 9/8, 7/6, 81/64, 4/3, 1024/729, 3/2, 128/81, 12/7, 7/4, 512/243];
~tuning = Tuning.new(~ratios.ratiomidi);
~scaledegrees = #[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
~scale = Scale.new((0..11), 12, ~tuning);
);

~tempo = TempoClock(80/60);

////////////////////////////////////////////////////////////////

(
SynthDef(\bass, { |curve = -2, dur = 1, fb = 2.0, freq = 440, level = 0.015, rhpffrq = 2000|
	var env				=	Env.perc(0.01, dur, level, curve).kr(2);
	var imp				=	Impulse.ar(0);
	var sinfb			=	SinOscFB.ar([freq, freq * 1.005], fb, mul: env);
	var comb			=	CombL.ar(imp + sinfb, (freq).reciprocal, (freq).reciprocal).softclip;
	var lpf				=	MoogVCF.ar(comb, 1000, 0.1);
	var xline			=	XLine.kr(1, 0.5, dur);
	var rhpfrqmod		=	LFBrownNoise0.kr(freq!2).range(0.3, 1);
	var rhpf			=	RHPF.ar(comb, (rhpffrq * xline).clip(50, SampleRate.ir / 3), rhpfrqmod);
	var leakdc			=	LeakDC.ar(lpf + rhpf);
	Out.ar(0, leakdc);
}).add;
);

(
~durs = (1..3);
~shortestdurs = ~durs.collect({ |i| Pseq([0.25], i) });
~shorterdurs = ~durs.collect({ |i| Pseq([0.5], i) });
~shortdurs = ~durs.collect({ |i| Pseq([0.75], i) });
~mediumdurs = ~durs.collect({ |i| 1 * i });
~longdurs = ~durs.collect({ |i| 1.5 * i });
~longerdurs = ~durs.collect({ |i| 4 * i });
~bassdurs = ~shortestdurs ++ ~shorterdurs ++ ~shortdurs ++ ~mediumdurs ++ ~longdurs ++ ~longerdurs;
Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
		\dur, Pshuf(~bassdurs, inf),
		\fb, Pwhite(2.0, 3.0, inf),
		\degree, Pshuf(((-2..6) ++ [Rest].stutter(3)).stutter(3), inf),
		\octave, 2,
		\rhpffrq, 8000,
		\root, ~root,
		\scale, ~scale
));
);

/*
Pdef(\basspat1).play(~tempo, quant: 1);
Pdef(\basspat1).isPlaying;
Pdef(\basspat1).stop;
*/

Pdef(\basspat2, Pbindf(Pdef(\basspat1), \curve, -8, \degree, Prand([0, 7, 12], inf)));

/*
Pdef(\basspat2).play(~tempo, quant: 1);
Pdef(\basspat2).isPlaying;
Pdef(\basspat2).stop;
*/

~basspar = Pdef(\basspar, Ppar([Pdef(\basspat1), Pdef(\basspat2)], inf));

/*
~basspar.play(~tempo, quant: 1);
~basspar.isPlaying;
~basspar.stop;
*/

(
MIDIdef.cc(\bass1playktrl, {
    if(Pdef(\basspat1).isPlaying.not) {
        Pdef(\basspat1).play(~tempo, quant: 1);
        "bass1 play".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\bass1stopktrl, {
    if(Pdef(\basspat1).isPlaying) {
        Pdef(\basspat1).stop;
        "bass1 stop".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\bass2playktrl, {
    if(Pdef(\basspat2).isPlaying.not) {
        Pdef(\basspat2).play(~tempo, quant: 1);
        "bass2 play".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\bass2stopktrl, {
    if(Pdef(\basspat2).isPlaying) {
        Pdef(\basspat2).stop;
        "bass2 stop".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////

(
SynthDef(\hat, { |curve = -16, dur = 1, fb = 0, freq = 440, level = 0.03|
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise0.kr(50!2, 0.002, 1);
    var fbmod           =   LFBrownNoise0.ar(31!2, mul: 0.5, add: 1);
	var sinfb			=	SinOscFB.ar(freq!2 * lfn, fb * fbmod).fold2(0.03) * envgen * 40;
	var rhpf			=	RHPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.1);
	Out.ar(0, rhpf);
}).add;
);

(
Pdef(\hatpat1,
	Pbind(
		\instrument, \hat,
        \dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 6].stutter(3), inf),
		\fb, Pshuf(Array.series(10, 0.1, 0.1), inf),
		\level, 0.05,
		\degree, 0,
		\octave, 8,
		\root, ~root,
		\scale, ~scale
));
Pdef(\hatpat2, Pbindf(Pdef(\hatpat1), \dur, Prand([0.25, 0.5, 0.75], inf), \level, 0.015));
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
~pulselvl = 0.01;
~pulseecholvl = ~pulselvl / 4;
Pdef(\pulsepat1a,
	Pbind(
		\instrument, \hat,
		\curve, -4,
        \dur, Pshuf([0.5, 0.75, 1.25, 0.5, 0.5, 0.75, 1.5].stutter(5), inf),
		\fb, Pwhite(2.7, 3.2, inf),
		\level, ~pulselvl,
		\degree, 0,
		\octave, 3,
		\root, ~root,
		\scale, ~scale
));
Pdef(\pulsepat1b, Pbindf(Pdef(\pulsepat1a), \level, ~pulseecholvl));
Pdef(\pulsepar1, Ppar([Pdef(\pulsepat1a), Pdef(\pulsepat1b), Pdef(\pulsepat1b)]));
);

/*
Pdef(\pulsepar1).play(~tempo, quant: 1);
Pdef(\pulsepar1).isPlaying;
Pdef(\pulsepar1).stop;
*/

(
Pdef(\pulsepat2a, Pbindf(Pdef(\pulsepat1a), \degree, [-2, 7]));
Pdef(\pulsepat2b, Pbindf(Pdef(\pulsepat2a), \level, ~pulseecholvl));
Pdef(\pulsepar2, Ppar([Pdef(\pulsepat2a), Pdef(\pulsepat2b), Pdef(\pulsepat2b)]));
);

/*
Pdef(\pulsepar2).play(~tempo, quant: 1);
Pdef(\pulsepar2).isPlaying;
Pdef(\pulsepar2).stop;
*/

(
Pdef(\pulsepat3a, Pbindf(Pdef(\pulsepat1a), \degree, [7, 12, 14]));
Pdef(\pulsepat3b, Pbindf(Pdef(\pulsepat3a), \level, ~pulseecholvl));
Pdef(\pulsepar3, Ppar([Pdef(\pulsepat3a), Pdef(\pulsepat3b), Pdef(\pulsepat3b)]));
);

/*
Pdef(\pulsepar3).play(~tempo, quant: 1);
Pdef(\pulsepar3).isPlaying;
Pdef(\pulsepar3).stop;
*/

(
Pdef(\pulsepat4,
    Pbindf(
        Pdef(\pulsepat1a),
        \curve, 4,
        \dur, 0.25,
        \fb, Pshuf(Array.series(10, 0, 0.25), inf),
        \level, Prand([0.3, 1], inf) * 0.002,
        \degree, [7, 10, 12],
        \octave, [5, 8]
));
Pdef(\pulsepar4, Ppar([Pdef(\pulsepat4)].stutter(4), inf));
);

/*
Pdef(\pulsepar4).play(~tempo, quant: 1);
Pdef(\pulsepar4).isPlaying;
Pdef(\pulsepar4).stop;
*/

(
Pdef(\pingpat,
    Pbind(
        \instrument, \hat,
        \curve, 0,
        \dur, Pshuf([1, 1.25, 1.5], inf),
        \degree, Pseq([
            Rest, Rest, 0, 0,
            Rest, Rest, Rest, 0, 0,
            Rest, Rest, Rest, Rest, 0, 0,
        ], inf),
        \level, 0.015,
        \octave, 8,
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

(
MIDIdef.cc(\hatplayktrl, {
    if(Pdef(\hatpar).isPlaying.not) {
        Pdef(\hatpar).play(~tempo, quant: 1);
        "hat play".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\hatstopktrl, {
    if(Pdef(\hatpar).isPlaying) {
        Pdef(\hatpar).stop;
        "hat stop".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\pulse1playktrl, {
    if(Pdef(\pulsepar1).isPlaying.not) {
        Pdef(\pulsepar1).play(~tempo, quant: 1);
        "pulse1 play".postln;
    }
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pulse1stopktrl, {
    if(Pdef(\pulsepar1).isPlaying) {
        Pdef(\pulsepar1).stop;
        "pulse1 stop".postln;
    }
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\pulse2playktrl, {
    if(Pdef(\pulsepar2).isPlaying.not) {
        Pdef(\pulsepar2).play(~tempo, quant: 1);
        "pulse2 play".postln;
    }
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pulse2stopktrl, {
    if(Pdef(\pulsepar2).isPlaying) {
        Pdef(\pulsepar2).stop;
        "pulse2a stop".postln;
    }
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\pulse3playktrl, {
    if(Pdef(\pulsepar3).isPlaying.not) {
        Pdef(\pulsepar3).play(~tempo, quant: 1);
        "pulse3 play".postln;
    }
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pulse3stopktrl, {
    if(Pdef(\pulsepar3).isPlaying) {
        Pdef(\pulsepar3).stop;
        "pulse3 stop".postln;
    }
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\pulse4playktrl, {
    if(Pdef(\pulsepar4).isPlaying.not) {
        Pdef(\pulsepar4).play(~tempo, quant: 1);
        "pulse4 play".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pulse4stopktrl, {
    if(Pdef(\pulsepar4).isPlaying) {
        Pdef(\pulsepar4).stop;
        "pulse4 stop".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\pingplayktrl, {
    if(Pdef(\pingpat).isPlaying.not) {
        Pdef(\pingpat).play(~tempo, quant: 1);
        "ping play".postln;
    }
}, 67, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pingstopktrl, {
    if(Pdef(\pingpat).isPlaying) {
        Pdef(\pingpat).stop;
        "ping stop".postln;
    }
}, 67, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////

(
SynthDef(\prc, {
	|a = 1.1, curve = -4, dur = 1, foldfactor = 2, freq = 440, level = 0.3, rez_freq = 1000, rez_rq = 1|
	var env				=	Env.perc(0.01, 0.3, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lc				=	LinCongC.ar([freq, freq + 1], a).fold2(1 / foldfactor) * foldfactor * envgen;
	var delay			=	DelayC.ar(lc, 0.2, freq.reciprocal);
	var rez				=	Resonz.ar(lc + delay, (rez_freq).clip(50, SampleRate.ir / 3), rez_rq) * rez_rq.reciprocal;
	Out.ar(0, rez);
}).add;
);

(
Pdef(\prcpat1a,
	Pbind(
		\instrument, \prc,
		\a, Pwhite(1.0, 2.0, inf).round(0.1),
		\curve, -8,
        \dur, Pshuf([0.25, 0.5, Pseq([0.375], 2), 1, 1.5, 2, 3, 4, 6], inf),
		\foldfactor, Pwhite(1, 10, inf),
		\level, Pshuf([0.2, 1, 1] * 0.1, inf),
		\degree, Pshuf([Rest, 0, 0, 0], inf),
		\octave, 7,
		\root, ~root,
		\scale, ~scale,
		\rez_freq, 2000,
		\rez_rq, 0.5
));
Pdef(\prcpar1, Ppar([Pdef(\prcpat1a)].stutter(2)));
);

/*
Pdef(\prcpar1).play(~tempo, quant: 1);
Pdef(\prcpar1).isPlaying;
Pdef(\prcpar1).stop;
*/

(
Pdef(\prcpat2a,
    Pbindf(
        Pdef(\prcpat1a),
        \curve, -16,
        \dur, Pshuf([
            0.5, 0.75, 1.25,
            0.5, 0.5, 0.75, 1.25,
            0.5, 0.5, 0.5, 0.75, 1.25
        ], inf),
        \level, 0.1,
        \degree, 7,
        \octave, 8
));
Pdef(\prcpat2b, Pbindf(Pdef(\prcpat2a), \level, 0.04));
Pdef(\prcpar2, Ppar([Pdef(\prcpat2a), Pdef(\prcpat2b)]));
);

/*
Pdef(\prcpar2).play(~tempo, quant: 1);
Pdef(\prcpar2).isPlaying;
Pdef(\prcpar2).stop;
*/

//

(
SynthDef(\kik, { |a = 1.4, c = 0.13, m = 1, dur = 1, fb = 0, ffreq = 1000, frq = 1, freq = 100, level = 0.2|
	var env				=	Env.perc(0.005, 1, level, -16);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lc				=	LinCongC.ar([freq, freq * 1.01], a, c, m, mul: envgen);
	var rhpf			=	RHPF.ar(lc, ffreq, frq, 2);
	Out.ar(0, lc + rhpf);
}).add;
);

(
Pdef(\kikpat,
	Pbind(
		\instrument, \kik,
		\a, Pwhite(1.0, 2.0, inf).round(0.01),
        \dur, Pshuf([Pseq([0.25], 2), 0.5, 0.75, 1, 1.5, 2, Pseq([0.75], 3), 3, 4, 6].stutter(5), inf),
		\ffreq, 1000,
		\frq, 0.1,
		\level, Prand([0.2, 1], inf) * 0.1,
		\degree, [0, 7],
		\octave, 5,
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

(
MIDIdef.cc(\prcplayktrl, {
    if(Pdef(\prcpar).isPlaying.not) {
        Pdef(\prcpar).play(~tempo, quant: 1);
        "prc play".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prcstopktrl, {
    if(Pdef(\prcpar).isPlaying) {
        Pdef(\prcpar).stop;
        "prc stop".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
MIDIdef.cc(\prcpar2playktrl, {
    if(Pdef(\prcpar2).isPlaying.not) {
        Pdef(\prcpar2).play(~tempo, quant: 1);
        "prcpar2 play".postln;
    }
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\prcpar2stopktrl, {
    if(Pdef(\prcpar2).isPlaying) {
        Pdef(\prcpar2).stop;
        "prcpar2 stop".postln;
    }
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////

(
SynthDef(\banjo, {
	|curve = -8, dur = 1, fb = 0, foldfactor = 1, freq = 440, level = 0.1, rlpf_freq = 880, rlpf_rq = 1, rhpf_freq = 8800, rhpf_rq = 1, sawfreq = 100|
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var noiz			=	LFNoise0.kr(30!2).range(0.999, 1);
	var sin				=	SinOscFB.ar([freq, freq * 1.0005], fb).round(level / 2).fold2((level * noiz) / foldfactor) * (foldfactor * noiz) * envgen;
	var rlpf			=	RLPF.ar(sin, rlpf_freq.clip(50, SampleRate.ir / 3), rlpf_rq).fold2(level / foldfactor) * foldfactor;
	var rhpf 			=	RHPF.ar(sin, rhpf_freq.clip(50, SampleRate.ir / 3), rhpf_rq).fold2(level / foldfactor) * foldfactor;
	Out.ar(0, rlpf + rhpf);
}).add;
);

(
Pdef(\banjopat,
	Pbind(
		\instrument, \banjo,
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 6], inf),
		\fb, Pwhite(0.0, 1.0, inf),
		\foldfactor, Pwhite(1, 20, inf),
        \level, 0.05,
		\degree, Pshuf([-2, 0, 1, 2, 3, 7], inf),
		\octave, Pwhite(4, 6, inf),
		//\octave, 4,
		\rlpf_freq, Pwhite(100.0, 10000.0, inf),
		\rlpf_rq, Pwhite(0.01, 1.0, inf),
		\rhpf_freq, Pwhite(1000.0, 15000.0, inf),
		\rhpf_rq, Pwhite(0.01, 1.0, inf),
		\root, ~root,
		\scale, ~scale,
));
//
Pdef(\banjopar, Ppar([Pdef(\banjopat)].stutter(4), inf));
);

/*
Pdef(\banjopat).play(~tempo, quant: 1);
Pdef(\banjopat).isPlaying;
Pdef(\banjopat).stop;
*/

/*
Pdef(\banjopar).play(~tempo, quant: 1);
Pdef(\banjopar).isPlaying;
Pdef(\banjopar).stop;
*/

(
MIDIdef.cc(\banjoplayktrl, {
    if(Pdef(\banjopar).isPlaying.not) {
        Pdef(\banjopar).play(~tempo, quant: 1);
        "banjo play".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\banjostopktrl, {
    if(Pdef(\banjopar).isPlaying) {
        Pdef(\banjopar).stop;
        "banjo stop".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////

(
SynthDef(\pno, { |a = 1, b = 3, curve = -8, dur = 1, fb = 0, freq = 440, latfreq = 10000, level = 0.1, pan = 0|
    var env             =   Env.perc(releaseTime: dur, level: level, curve: curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var lat             =   Latoocarfian2DC.kr(a: [a, a - 0.001], b: [b, b - 0.001], mul: 0.999, add: 1).clip(0, 1);
    var ampmod          =   LFBrownNoise2.kr(15.dup, add: 1).clip(0.25, 1).round(0.75);
    var sinfb           =   SinOscFB.ar(freq * lat, fb, envgen * ampmod);
    var rhpf            =   RHPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.05);
    Out.ar(0, rhpf);
}).add;
);

(
Pdef(\pnopat,
    Pbind(
        \instrument, \pno,
        \a, Pwhite(-3.0, 3.0, inf),
        \b, Pwhite(-3.0, 3.0, inf),
        \dur, Pshuf([13, 17, 19] + 0.25, inf),
        \fb, 2,
        \level, 0.005,
        \degree, [-5, -2, 0, 2],
        \octave, [5, 8],
        \root, ~root,
        \scale, ~scale,
));
);

/*
Pdef(\pnopat).play(~tempo, quant: 1);
Pdef(\pnopat).isPlaying;
Pdef(\pnopat).stop;
*/

(
MIDIdef.cc(\pnoplayktrl, {
    if(Pdef(\pnopat).isPlaying.not) {
        Pdef(\pnopat).play(~tempo, quant: 1);
        "pno play".postln;
    }
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\pnostopktrl, {
    if(Pdef(\pnopat).isPlaying) {
        Pdef(\pnopat).stop;
        "pno stop".postln;
    }
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////

(
SynthDef(\string, { |delaytime = 0.03, dur = 1, freq = 440, gate = 1, level = 0.01, xlinestart = 1|
	var env				=	Env.asr(0.3, level, 8, -4);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
    var xlinemod        =   LFBrownNoise0.kr(13!2, mul: 0.03, add: 1);
	var xline			=	XLine.kr(xlinestart, 1, dur / 2) * xlinemod;
	var fbmod			=	SinOsc.ar(freq * xline, mul: 0.99, add: 1);
	var n				=	2;
	var mix 			=	Mix.fill(n, {
		var freqmodmod		=	LFNoise1.kr(1!2).range(1, 10);
		var freqmod			=	LFNoise1.kr(freqmodmod, 0.0003, 1);
		var sinfb			=	(SinOscFB.ar(freq * freqmod, fbmod).round(0.9) * (envgen / n)).fold2(level / 2);
		sinfb;
	});
	var delay			=	DelayC.ar(mix, 0.2, delaytime.clip(0.00008, 0.1));
	var lopass			=	RLPF.ar(mix + delay, freq * 1.5);
    var hpfampmod       =   LFBrownNoise0.kr(15!2).range(0.3, 1).round(0.7);
	var rhpf			=	RHPF.ar(mix + delay, (freq * 12).clip(50, SampleRate.ir / 3), 0.05) * hpfampmod;
	Out.ar(0, lopass + rhpf);
}).add;
);

(
SynthDef(\stringdelayktrl, {|delaytime = 0.01, dur = 1, outbus = 0|
	// var env				=	Env.new([0.01, delaytime, delaytime, 0.01], [0.05, dur, 0.05]);
	// var envgen			=	EnvGen.kr(env, doneAction: 2);
	var setdelaytime	=	Line.kr(delaytime, delaytime, dur, doneAction: 2);
	Out.kr(outbus, setdelaytime);
}).add;
);

//

/*
~chordlets = [[-5, 0], [-2, 2]];
string0 = [-5, 0]; // octave 5
string1 = chords (maybe no rests?) // octave 5
string2 = [-5, 0]; // octave 6
string3 = [-2, 2]; // octave 6
string4 = [-5, 0]; // octave 4
string5 = [-2, 2]; // octave 4
string6 = [-5, 0]; // octave 7
string7 = [-2, 2]; // octave 7
string8 = [0, 12]; // octave 2
*/

(
~stringpat0delayktrlbus = Bus.control(s);

Pdef(\stringpat0setdelaytime,
	Pbind(
		\instrument,\stringdelayktrl,
		\delaytime, Pbrown(0.0001, 0.01, 0.001, inf),
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48], inf),
		\legato, 1,
		\outbus, ~stringpat0delayktrlbus,
));

Pdef(\stringpat0,
	Pmono(
		\string,
		\delaytime, ~stringpat0delayktrlbus.asMap,
		\dur, Pwhite(3, 5, inf),
		\degree, [-5, 0],
		\root, ~root,
		\scale, ~scale,
		\xlinestart, 1
));
);

Pdef(\stringpat0setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat0setdelaytime).isPlaying;
Pdef(\stringpat0setdelaytime).stop;
*/

/*
Pdef(\stringpat0).play(~tempo, quant: 1);
Pdef(\stringpat0).isPlaying;
Pdef(\stringpat0).stop;
*/

(
~stringpat1delayktrlbus = Bus.control(s);

Pdef(\stringpat1setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat1delayktrlbus,
));

~chords = [
	[-5, -2, 0], [-5, -1, 0], [-5, 0, 0], [-5, 0, 1], [-5, 0, 2], [0, 3, 7], [0, 4, 7], [0, 6, 7], [0, 7, 7]
];
~rests = Rest!(~chords.size / 2);
~chordsandrests = ~chords ++ ~rests;

Pdef(\stringpat1,
	Pbind(
		\instrument, \string,
		\delaytime, ~stringpat1delayktrlbus.asMap,
		\dur, Pshuf(Array.fill(4, { |i| (i + 7).nthPrime }), inf),
		\legato, 1,
		\degree, Pshuf(~chordsandrests, inf),
		\octave, 5,
		\root, ~root,
		\scale, ~scale,
        \xlinestart, Pshuf([0.5, 1, 2], inf),
));
);

Pdef(\stringpat1setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat1setdelaytime).isPlaying;
Pdef(\stringpat1setdelaytime).stop;
*/

/*
Pdef(\stringpat1).play(~tempo, quant: 1);
Pdef(\stringpat1).isPlaying;
Pdef(\stringpat1).stop;
*/

(
~stringpat2delayktrlbus = Bus.control(s);

Pdef(\stringpat2setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat2delayktrlbus,
));

Pdef(\stringpat2,
	Pbindf(
		Pdef(\stringpat1),
		\delaytime, ~stringpat2delayktrlbus.asMap,
		\degree, [-5, 0],
        \octave, 6
));
);

Pdef(\stringpat2setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat2setdelaytime).isPlaying;
Pdef(\stringpat2setdelaytime).stop;
*/

/*
Pdef(\stringpat2).play(~tempo, quant: 1);
Pdef(\stringpat2).isPlaying;
Pdef(\stringpat2).stop;
*/

(
~stringpat3delayktrlbus = Bus.control(s);

Pdef(\stringpat3setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat3delayktrlbus,
));

Pdef(\stringpat3,
	Pbindf(
		Pdef(\stringpat2),
		\delaytime, ~stringpat3delayktrlbus,
		\degree, [-2, 2],
		\octave, 6
));
);

Pdef(\stringpat3setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat3setdelaytime).isPlaying;
Pdef(\stringpat3setdelaytime).stop;
*/

/*
Pdef(\stringpat3).play(~tempo, quant: 1);
Pdef(\stringpat3).isPlaying;
Pdef(\stringpat3).stop;
*/

(
~stringpat4delayktrlbus = Bus.control(s);

Pdef(\stringpat4setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat4delayktrlbus,
));

Pdef(\stringpat4,
	Pbindf(
		Pdef(\stringpat2),
		\delaytime, ~stringpat4delayktrlbus.asMap,
        \degree, [-5, 0],
		\octave, 4
));
);

Pdef(\stringpat4setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat4setdelaytime).isPlaying;
Pdef(\stringpat4setdelaytime).stop;
*/

/*
Pdef(\stringpat4).play(~tempo, quant: 1);
Pdef(\stringpat4).isPlaying;
Pdef(\stringpat4).stop;
*/

(
~stringpat5delayktrlbus = Bus.control(s);

Pdef(\stringpat5setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat5delayktrlbus,
));

Pdef(\stringpat5,
	Pbindf(Pdef(\stringpat2),
		\delaytime, ~stringpat5delayktrlbus.asMap,
		\degree, [-2, 2],
		\octave, 4,
));
);

Pdef(\stringpat5setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat5setdelaytime).isPlaying;
Pdef(\stringpat5setdelaytime).stop;
*/

/*
Pdef(\stringpat5).play(~tempo, quant: 1);
Pdef(\stringpat5).isPlaying;
Pdef(\stringpat5).stop;
*/

(
~stringpat6delayktrlbus = Bus.control(s);

Pdef(\stringpat6setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat6delayktrlbus,
));

Pdef(\stringpat6,
	Pbindf(Pdef(\stringpat2),
		\delaytime, ~stringpat6delayktrlbus.asMap,
		\degree, [-5, 0],
		\octave, 7,
));
);

Pdef(\stringpat6setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat6setdelaytime).isPlaying;
Pdef(\stringpat6setdelaytime).stop;
*/

/*
Pdef(\stringpat6).play(~tempo, quant: 1);
Pdef(\stringpat6).isPlaying;
Pdef(\stringpat6).stop;
*/

(
~stringpat7delayktrlbus = Bus.control(s);

Pdef(\stringpat7setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat7delayktrlbus,
));

Pdef(\stringpat7,
	Pbindf(Pdef(\stringpat2),
		\delaytime, ~stringpat7delayktrlbus.asMap,
		\degree, [-2, 2],
		\octave, 7
));
);

Pdef(\stringpat7setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat7setdelaytime).isPlaying;
Pdef(\stringpat7setdelaytime).stop;
*/

/*
Pdef(\stringpat7).play(~tempo, quant: 1);
Pdef(\stringpat7).isPlaying;
Pdef(\stringpat7).stop;
*/

(
~stringpat8delayktrlbus = Bus.control(s);

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

Pdef(\stringpat8setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat8setdelaytime).isPlaying;
Pdef(\stringpat8setdelaytime).stop;
*/

/*
Pdef(\stringpat8).play(~tempo, quant: 1);
Pdef(\stringpat8).isPlaying;
Pdef(\stringpat8).stop;
*/

(
~stringpat9delayktrlbus = Bus.control(s);

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

Pdef(\stringpat9setdelaytime).play(~tempo, quant: 1);
/*
Pdef(\stringpat9setdelaytime).isPlaying;
Pdef(\stringpat9setdelaytime).stop;
*/

/*
Pdef(\stringpat9).play(~tempo, quant: 1);
Pdef(\stringpat9).isPlaying;
Pdef(\stringpat9).stop;
*/


//

(
MIDIdef.cc(\string0playktrl, {
    if(Pdef(\stringpat0).isPlaying.not) {
        Pdef(\stringpat0).play(~tempo, quant: 1);
        "string0 ([-5, 0], octave 5) play".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string0stopktrl, {
    if(Pdef(\stringpat0).isPlaying) {
        Pdef(\stringpat0).stop;
        "string0 ([-5, 0], octave 5) stop".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\string1playktrl, {
    if(Pdef(\stringpat1).isPlaying.not) {
        Pdef(\stringpat1).play(~tempo, quant: 1);
        "string1 (chords and rests, octave 5) play".postln;
        ~chords.postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string1stopktrl, {
    if(Pdef(\stringpat1).isPlaying) {
        Pdef(\stringpat1).stop;
        "string1 (chords and rests, octave 5) stop".postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\string2playktrl, {
    if(Pdef(\stringpat2).isPlaying.not) {
        Pdef(\stringpat2).play(~tempo, quant: 1);
        "string2 ([-5, 0], octave 6) play".postln;
    }
}, 37, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string2stopktrl, {
    if(Pdef(\stringpat2).isPlaying) {
        Pdef(\stringpat2).stop;
        "string2 ([-5, 0], octave 6) stop".postln;
    }
}, 37, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\string3playktrl, {
    if(Pdef(\stringpat3).isPlaying.not) {
        Pdef(\stringpat3).play(~tempo, quant: 1);
        "string3 ([-2, 2], octave 6) play".postln;
    }
}, 53, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string3stopktrl, {
    if(Pdef(\stringpat3).isPlaying) {
        Pdef(\stringpat3).stop;
        "string3 ([-2, 2], octave 6) stop".postln;
    }
}, 53, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\string4playktrl, {
    if(Pdef(\stringpat4).isPlaying.not) {
        Pdef(\stringpat4).play(~tempo, quant: 1);
        "string4 ([-5, 0], octave 4) play".postln;
    }
}, 69, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string4stopktrl, {
    if(Pdef(\stringpat4).isPlaying) {
        Pdef(\stringpat4).stop;
        "string4 ([-5, 0], octave 4) stop".postln;
    }
}, 69, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\string5playktrl, {
    if(Pdef(\stringpat5).isPlaying.not) {
        Pdef(\stringpat5).play(~tempo, quant: 1);
        "string5 ([-2, 2], octave 4) play".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string5stopktrl, {
    if(Pdef(\stringpat5).isPlaying) {
        Pdef(\stringpat5).stop;
        "string5 ([-2, 2], octave 4) stop".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\string6playktrl, {
    if(Pdef(\stringpat6).isPlaying.not) {
        Pdef(\stringpat6).play(~tempo, quant: 1);
        "string6 ([-5, 0], octave, 7) play".postln;
    }
}, 54, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string6stopktrl, {
    if(Pdef(\stringpat6).isPlaying) {
        Pdef(\stringpat6).stop;
        "string6 ([-5, 0], octave, 7) stop".postln;
    }
}, 54, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\string7playktrl, {
    if(Pdef(\stringpat7).isPlaying.not) {
        Pdef(\stringpat7).play(~tempo, quant: 1);
        "string7 ([-5, 0], octave 7) play".postln;
    }
}, 70, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string7stopktrl, {
    if(Pdef(\stringpat7).isPlaying) {
        Pdef(\stringpat7).stop;
        "string7 ([-5, 0], octave 7) stop".postln;
    }
}, 70, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\string8playktrl, {
    if(Pdef(\stringpat8).isPlaying.not) {
        Pdef(\stringpat8).play(~tempo, quant: 1);
        "string8 ([0, 12, 19], octave 2) play".postln;
    }
}, 39, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string8stopktrl, {
    if(Pdef(\stringpat8).isPlaying) {
        Pdef(\stringpat8).stop;
        "string8 ([0, 12, 19], octave 2) stop".postln;
    }
}, 39, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
MIDIdef.cc(\string9playktrl, {
    if(Pdef(\stringpat9).isPlaying.not) {
        Pdef(\stringpat9).play(~tempo, quant: 1);
        "string9 ([0, 12, 19], octave 2) play".postln;
    }
}, 55, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\string9stopktrl, {
    if(Pdef(\stringpat9).isPlaying) {
        Pdef(\stringpat9).stop;
        "string9 ([0, 12, 19], octave 2) stop".postln;
    }
}, 55, srcID: ~nanoktrl2.uid, argTemplate: 0);
);