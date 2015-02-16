// Environment
while ({ currentEnvironment === topEnvironment }.not, { Environment.pop });
~cnqr3Environment = Environment.make({});
~cnqr3Environment.push;

//midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
//~nanoktrl2 = 1310720;
~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("nanoKONTROL2")};
// Fallback if MIDI controller not actually attached, but still want to play stuff.
if(~nanoktrl2.isNil) { ~nanoktrl2 = MIDIClient.sources.detect{ |a| a.name.contains("Midi Through Port-0") } };

(
~root = 7;
~tuning = Tuning.new([1/1, 15/14, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 12/7, 7/4, 28/15]);
~scale = Scale.new((0..11), 12, ~tuning);
);

s.scope;

t = TempoClock(72/60);

////////////////////////////////////////////////////////////////

(
SynthDef(\bass, { |curve = -2, dur = 1, fb = 2.0, freq = 440, level = 0.02, rhpffrq = 2000|
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
~shortestdurs = ~durs.collect({ |i| Pseq([0.125], i) });
~shorterdurs = ~durs.collect({ |i| Pseq([0.5], i) });
~shortdurs = ~durs.collect({ |i| Pseq([0.75], i) });
~mediumdurs = ~durs.collect({ |i| 1 * i });
~longdurs = ~durs.collect({ |i| 1.5 * i });
~longerdurs = ~durs.collect({ |i| 4 * i });
~bassdurs = ~shortestdurs ++ ~shorterdurs ++ ~shortdurs ++ ~mediumdurs ++ ~longdurs ++ ~longerdurs;
~basspat1 =
Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
		//\dur, Pshuf([
		//	0.25, Pseq([0.25], 2), 0.5, Pseq([0.25], 3), 0.75, Pseq([0.25], 4), 1, Pseq([0.25], 6), 1.5, 2, 3, 4, 6, 8, 12
		//].stutter(3), inf),
		\dur, Pshuf(~bassdurs, inf),
		\fb, Pwhite(2.0, 3.0, inf),
		\note, Pshuf(((-2..6) ++ [Rest].stutter(3)).stutter(3), inf),
		\octave, 2,
		\rhpffrq, 8000,
		\root, ~root,
		\scale, ~scale
));
);

/*
~basspat1.play(t, quant: 0.5);
~basspat1.isPlaying;
~basspat1.stop;
*/

~basspat2 = Pdef(\basspat2, Pbindf(~basspat1, \curve, -8, \note, Prand([0, 7, 12], inf)));

/*
~basspat2.play(t, quant: 0.5);
~basspat2.isPlaying;
~basspat2.stop;
*/

~basspar = Pdef(\basspar, Ppar([~basspat1, ~basspat2], inf));

/*
~basspar.play(t, quant: 0.5);
~basspar.isPlaying;
~basspar.stop;
*/

(
~bass1playktrl =
MIDIdef.cc(\bass1playktrl, {
    if(~basspat1.isPlaying.not) {
        ~basspat1.play(t, quant: 0.5);
        "bass1 play".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~bass1stopktrl =
MIDIdef.cc(\bass1stopktrl, {
    if(~basspat1.isPlaying) {
        ~basspat1.stop;
        "bass1 stop".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
~bass2playktrl =
MIDIdef.cc(\bass2playktrl, {
    if(~basspat2.isPlaying.not) {
        ~basspat2.play(t, quant: 0.5);
        "bass2 play".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~bass2stopktrl =
MIDIdef.cc(\bass2stopktrl, {
    if(~basspat2.isPlaying) {
        ~basspat2.stop;
        "bass2 stop".postln;
    }
}, 65, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////

(
SynthDef(\hat, { |curve = -16, dur = 1, fb = 0, freq = 440, level = 0.05|
	var env				=	Env.perc(0.005, dur, level, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var lfn				=	LFNoise0.kr(50!2, 0.0005, 1);
    var fbmod           =   LFBrownNoise0.ar(30!2, mul: 0.5, add: 1);
	var sinfb			=	SinOscFB.ar(freq!2 * lfn, fb * fbmod).fold2(0.03) * envgen * 40;
	var rhpf			=	RHPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.1);
	Out.ar(0, rhpf);
}).add;
);

(
~hatpat1 =
Pdef(\hatpat1,
	Pbind(
		\instrument, \hat,
        \dur, Pshuf([Pseq([0.25 / 3], 3), Pseq([0.125], 2), 0.5, 0.75, 1, 1.5, 6], inf),
		\fb, Pshuf(Array.series(10, 0.1, 0.1), inf),
		\level, 0.08,
		\note, 0,
		\octave, 8,
		\root, ~root,
		\scale, ~scale
));
~hatpat2 = Pdef(\hatpat2, Pbindf(~hatpat1, \dur, Prand([0.25, 0.5, 0.75], inf), \level, 0.02));
~hatpar = Pdef(\hatpar, Ppar([~hatpat1, ~hatpat2], inf));
);

/*
~hatpat1.play(t, quant: 1);
~hatpat1.stop;
*/

/*
~hatpat2.play(t, quant: 1);
~hatpat2.stop;
*/

/*
~hatpar.play(t, quant: 1);
~hatpar.isPlaying;
~hatpar.stop;
*/

//

(
~pulsepat1a =
Pdef(\pulsepat1a,
	Pbind(
		\instrument, \hat,
		\curve, -4,
        \dur, Pshuf([0.5, 0.75, 1.25, 0.5, 0.5, 0.75, Pseq([1, 0.125, 0.125])].stutter(5), inf),
		\fb, Pwhite(2.7, 3.2, inf),
		\level, 0.02,
		\note, 0,
		\octave, 3,
		\root, ~root,
		\scale, ~scale
));

~pulsepat1b = Pdef(\pulsepat1b, Pbindf(~pulsepat1a, \level, 0.005));
~pulsepar1 = Pdef(\pulsepar1, Ppar([~pulsepat1a, ~pulsepat1b, ~pulsepat1b]));
);

/*
~pulsepar1.play(t, quant: 0.5);
~pulsepar1.isPlaying;
~pulsepar1.stop;
*/

~pulsepat2a = Pdef(\pulsepat2a, Pbindf(~pulsepat1a, \note, [-2, 7]));
~pulsepat2b = Pdef(\pulsepat2b, Pbindf(~pulsepat1a, \note, [7, 12, 14]));

/*
~pulsepat2a.play(t, quant: 1);
~pulsepat2a.stop;
*/

/*
~pulsepat2b.play(t, quant: 1);
~pulsepat2b.stop;
*/

(
~pulsepat3 =
Pdef(\pulsepat3,
    Pbindf(
        ~pulsepat1a,
        \curve, 4,
        \dur, Pwrand([0.25, Pseq([0.125], 2)], [17, 1].normalizeSum, inf),
        \fb, Pwhite(0.0, 1.0, inf).round(0.2),
        //\lag, Pwhite(-0.005, 0.005, inf),
        \level, Prand([0.3, 1], inf) * 0.003,
        \note, [7, 10, 12],
        \octave, [5, 8]
));
~pulsepar3 = Pdef(\pulsepar3, Ppar([~pulsepat3].stutter(4), inf));
);

/*
~pulsepar3.play(t, quant: 0.5);
~pulsepar3.isPlaying;
~pulsepar3.stop;
*/

//

(
~hatplayktrl =
MIDIdef.cc(\hatplayktrl, {
    if(~hatpar.isPlaying.not) {
        ~hatpar.play(t, quant: 1);
        "hat play".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~hatstopktrl =
MIDIdef.cc(\hatstopktrl, {
    if(~hatpar.isPlaying) {
        ~hatpar.stop;
        "hat stop".postln;
    }
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~pulse1playktrl =
MIDIdef.cc(\pulse1playktrl, {
    if(~pulsepar1.isPlaying.not) {
        ~pulsepar1.play(t, quant: 1);
        "pulse1 play".postln;
    }
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~pulse1stopktrl =
MIDIdef.cc(\pulse1stopktrl, {
    if(~pulsepar1.isPlaying) {
        ~pulsepar1.stop;
        "pulse1 stop".postln;
    }
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~pulse2aplayktrl =
MIDIdef.cc(\pulse2aplayktrl, {
    if(~pulsepat2a.isPlaying.not) {
        ~pulsepat2a.play(t, quant: 1);
        "pulse2a play".postln;
    }
}, 48, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~pulse2astopktrl =
MIDIdef.cc(\pulse2astopktrl, {
    if(~pulsepat2a.isPlaying) {
        ~pulsepat2a.stop;
        "pulse2a stop".postln;
    }
}, 48, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~pulse2bplayktrl =
MIDIdef.cc(\pulse2bplayktrl, {
    if(~pulsepat2b.isPlaying.not) {
        ~pulsepat2b.play(t, quant: 1);
        "pulse2b play".postln;
    }
}, 64, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~pulse2bstopktrl =
MIDIdef.cc(\pulse2bstopktrl, {
    if(~pulsepat2b.isPlaying) {
        ~pulsepat2b.stop;
        "pulse2b stop".postln;
    }
}, 64, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~pulse3playktrl =
MIDIdef.cc(\pulse3playktrl, {
    if(~pulsepar3.isPlaying.not) {
        ~pulsepar3.play(t, quant: 1);
        "pulse3 play".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~pulse3stopktrl =
MIDIdef.cc(\pulse3stopktrl, {
    if(~pulsepar3.isPlaying) {
        ~pulsepar3.stop;
        "pulse3 stop".postln;
    }
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0);
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
~prcpat1a =
Pdef(\prcpat1a,
	Pbind(
		\instrument, \prc,
		\a, Pwhite(1.0, 2.0, inf).round(0.1),
		\curve, -8,
        \dur, Pshuf([Pseq([0.125], 4), 0.25, 0.5, Pseq([0.375], 2), 1, 1.5, 2, 3, 4, 6], inf),
		\foldfactor, Pwhite(1, 10, inf),
		\level, Pshuf([0.2, 1, 1] * 0.2, inf),
		\note, Pshuf([Rest, 0, 0, 0], inf),
		\octave, 7,
		\root, ~root,
		\scale, ~scale,
		\rez_freq, 2000,
		\rez_rq, 0.5
));
~prcpar1 = Pdef(\prcpar1, Ppar([~prcpat1a].stutter(2)));
);

/*
~prcpar1.play(t, quant: 0.5);
~prcpar1.isPlaying;
~prcpar1.stop;
*/

(
~prcpat2a =
Pdef(\prcpat2a,
    Pbindf(
        ~prcpat1a,
        \curve, -16,
        \dur, Pshuf([Pseq([0.125], 4), 0.5, 0.75, Pseq([0.125], 4), 0.5, 0.5, 0.75, Pseq([0.125], 4), 0.5, 0.5, 0.5, 0.75], inf),
        \level, 0.2,
        \note, 7,
        \octave, 8
));
~prcpat2b = Pdef(\prcpat2b, Pbindf(~prcpat2a, \level, 0.04));
~prcpar2 = Pdef(\prcpar2, Ppar([~prcpat2a, ~prcpat2b]));
);

/*
~prcpar2.play(t, quant: 0.5);
~prcpar2.isPlaying;
~prcpar2.stop;
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
~kikpat =
Pdef(\kikpat,
	Pbind(
		\instrument, \kik,
		\a, Pwhite(1.0, 2.0, inf).round(0.01),
        \dur, Pshuf([Pseq([0.25], 2), 0.5, 0.75, 1, 1.5, 2, Pseq([0.75], 3), 3, 4, 6].stutter(5), inf),
		\ffreq, 1000,
		\frq, 0.1,
		\level, Prand([0.2, 1], inf) * 0.3,
		\note, [0, 7],
		\octave, 5,
		\root, ~root,
		\scale, ~scale
));
);

/*
~kikpat.play(t, quant: 0.5);
~kikpat.isPlaying;
~kikpat.stop;
*/

////

~prcpar = Pdef(\prcpar, Ppar([~prcpar1, ~kikpat]));

/*
~prcpar.play(t, quant: 0.5);
~prcpar.isPlaying;
~prcpar.stop;
*/

(
~prcplayktrl =
MIDIdef.cc(\prcplayktrl, {
    if(~prcpar.isPlaying.not) {
        ~prcpar.play(t, quant: 1);
        "prc play".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~prcstopktrl =
MIDIdef.cc(\prcstopktrl, {
    if(~prcpar.isPlaying) {
        ~prcpar.stop;
        "prc stop".postln;
    }
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

(
~prcpar2playktrl =
MIDIdef.cc(\prcpar2playktrl, {
    if(~prcpar2.isPlaying.not) {
        ~prcpar2.play(t, quant: 1);
        "prcpar2 play".postln;
    }
}, 51, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~prcpar2stopktrl =
MIDIdef.cc(\prcpar2stopktrl, {
    if(~prcpar2.isPlaying) {
        ~prcpar2.stop;
        "prcpar2 stop".postln;
    }
}, 51, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////

(
SynthDef(\banjo, {
	|amp = 0.1, curve = -8, dur = 1, fb = 0, foldfactor = 1, freq = 440, rlpf_freq = 880, rlpf_rq = 1, rhpf_freq = 8800, rhpf_rq = 1, sawfreq = 100|
	var env				=	Env.perc(0.005, dur, amp, curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var noiz			=	LFNoise0.kr(30!2).range(0.999, 1);
	var sin				=	SinOscFB.ar([freq, freq * 1.0005], fb).round(amp / 2).fold2((amp * noiz) / foldfactor) * (foldfactor * noiz) * envgen;
	var rlpf			=	RLPF.ar(sin, rlpf_freq.clip(50, SampleRate.ir / 3), rlpf_rq).fold2(amp / foldfactor) * foldfactor;
	var rhpf 			=	RHPF.ar(sin, rhpf_freq.clip(50, SampleRate.ir / 3), rhpf_rq).fold2(amp / foldfactor) * foldfactor;
	Out.ar(0, rlpf + rhpf);
}).add;
);

(
~banjopat =
Pdef(\banjopat,
	Pbind(
		\instrument, \banjo,
		\amp, 0.08,
		\dur, Pshuf([Pseq([0.25 / 3], 3), Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, 1.5, 6], inf),
		\fb, Pwhite(0.0, 1.0, inf),
		\foldfactor, Pwhite(1, 20, inf),
		\note, Pshuf([-2, 0, 1, 2, 3, 7], inf),
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
~banjopar = Pdef(\banjopar, Ppar([~banjopat].stutter(4), inf));
);

/*
~banjopat.play(t, quant: 0.5);
~banjopat.isPlaying;
~banjopat.stop;
*/

/*
~banjopar.play(t, quant: 0.5);
~banjopar.isPlaying;
~banjopar.stop;
*/

(
~banjoplayktrl =
MIDIdef.cc(\banjoplayktrl, {
    if(~banjopar.isPlaying.not) {
        ~banjopar.play(t, quant: 1);
        "banjo play".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~banjostopktrl =
MIDIdef.cc(\banjostopktrl, {
    if(~banjopar.isPlaying) {
        ~banjopar.stop;
        "banjo stop".postln;
    }
}, 66, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////

(
SynthDef(\prc2, { |a = 1, b = 3, curve = -16, dur = 1, fb = 0, freq = 440, latfreq = 10000, level = 0.1, pan = 0, x0 = 4.9789799812499, y0 = 5.7473416156381|
    var env             =   Env.perc(releaseTime: dur, level: level, curve: curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var lat             =   Latoocarfian2DC.ar(latfreq / 2, latfreq, [a, a - 0.001], [b, b - 0.001], mul: 0.999, add: 1).clip(0, 1);
    var ampmod          =   LFBrownNoise2.kr(15.dup, add: 1).clip(0.25, 1).round(0.75);
    var sinfb           =   SinOscFB.ar(freq * lat, fb, envgen * ampmod);
    var rhpf            =   RHPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.05);
    Out.ar(0, rhpf);
}).add;
);

(
~prc2pata =
Pdef(\prc2pata,
    Pbind(
        \instrument, \prc2,
        \a, Pwhite(-3.0, 3.0, inf),
        \b, Pwhite(-3.0, 3.0, inf),
        \dur, Pshuf([17, 19, 23], inf),
        \fb, 2,
        \level, 0.01,
        \note, [-5, -2, 0, 2],
        \octave, [5, 8],
        \root, ~root,
        \scale, ~scale,
));
~prc2par = Pdef(\prc2par, Ppar([~prc2pata], inf));
);

/*
~prc2par.play(t, quant: 1);
~prc2par.isPlaying;
~prc2par.stop;
*/

(
~prc2playktrl =
MIDIdef.cc(\prc2playktrl, {
    if(~prc2par.isPlaying.not) {
        ~prc2par.play(t, quant: 1);
        "prc2 play".postln;
    }
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~prc2stopktrl =
MIDIdef.cc(\prc2stopktrl, {
    if(~prc2par.isPlaying) {
        ~prc2par.stop;
        "prc2 stop".postln;
    }
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0);
);

////////////////////////////////////////////////////////////////

(
SynthDef(\string, { |delaytime = 0.03, dur = 1, freq = 440, gate = 1, level = 0.025, xlinestart = 1|
	var env				=	Env.asr(5, level, 10, 0);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var xline			=	XLine.kr(xlinestart, 1, dur / 2);
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
    var hpfampmod       =   LFBrownNoise0.kr(15.dup).range(0.4, 1).round(0.6);
	var rhpf			=	RHPF.ar(mix + delay, (freq * 11).clip(50, SampleRate.ir / 3), 0.05) * hpfampmod;
	var leakdc			=	LeakDC.ar(lopass + rhpf);
	Out.ar(0, leakdc);
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

~stringpat0setdelaytime =
Pdef(\stringpat0setdelaytime,
	Pbind(
		\instrument,\stringdelayktrl,
		\delaytime, Pbrown(0.0001, 0.01, 0.001, inf),
		//\delaytime, Pshuf([0.001, 0.0015, 0.002], inf),
		\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48], inf),
		\legato, 1,
		\outbus, ~stringpat0delayktrlbus,
));

~stringpat0 =
Pdef(\stringpat0,
	Pmono(
		\string,
		\delaytime, ~stringpat0delayktrlbus.asMap,
		\dur, Pwhite(3, 5, inf),
		\note, [-5, 0],
		\root, ~root,
		\scale, ~scale,
		\xlinestart, 1
));
);

~stringpat0setdelaytime.play(t, quant: 0.5);
/*
~stringpat0setdelaytime.isPlaying;
~stringpat0setdelaytime.stop;
*/

/*
~stringpat0.play(t, quant: 0.5);
~stringpat0.isPlaying;
~stringpat0.stop;
*/

(
~stringpat1delayktrlbus = Bus.control(s);

~stringpat1setdelaytime =
Pdef(\stringpat1setdelaytime,
	Pbindf(
		~stringpat0setdelaytime,
		\outbus, ~stringpat1delayktrlbus,
));

~chords = [
	//[-5, -2, 0], [-5, 0, 0], [-5, 0, 1], [-5, 0, 2], [-5, 0, 3], [0, 6, 7], [0, 7, 7]
	[-5, -2, 0], [-5, -1, 0], [-5, 0, 0], [-5, 0, 1], [-5, 0, 2], [0, 3, 7], [0, 4, 7], [0, 6, 7], [0, 7, 7]
];
~rests = Rest!(~chords.size / 2);
~chordsandrests = ~chords ++ ~rests;

~stringpat1 =
Pdef(\stringpat1,
	Pbind(
		\instrument, \string,
		\delaytime, ~stringpat1delayktrlbus.asMap,
		\dur, Pshuf(Array.fill(4, { |i| (i + 7).nthPrime }), inf),
		\legato, 1,
		\note, Pshuf(~chordsandrests, inf),
		\octave, 5,
		\root, ~root,
		\scale, ~scale,
		//\xlinestart, Pshuf([0.25, 1/3, 0.5, 0.75, 1, 1.5, 2, 3, 4], inf),
        \xlinestart, Pshuf([0.5, 1, 2], inf),
));
);

~stringpat1setdelaytime.play(t, quant: 0.5);
/*
~stringpat1setdelaytime.isPlaying;
~stringpat1setdelaytime.stop;
*/

/*
~stringpat1.play(t, quant: 0.5);
~stringpat1.isPlaying;
~stringpat1.stop;
*/

(
~stringpat2delayktrlbus = Bus.control(s);

~stringpat2setdelaytime =
Pdef(\stringpat2setdelaytime,
	Pbindf(
		~stringpat0setdelaytime,
		\outbus, ~stringpat2delayktrlbus,
));

~stringpat2 =
Pdef(\stringpat2,
	Pbindf(
		~stringpat1,
		\delaytime, ~stringpat2delayktrlbus.asMap,
		\note, [-5, 0],
        \octave, 6
));
);

~stringpat2setdelaytime.play(t, quant: 0.5);
/*
~stringpat2setdelaytime.isPlaying;
~stringpat2setdelaytime.stop;
*/

/*
~stringpat2.play(t, quant: 0.5);
~stringpat2.isPlaying;
~stringpat2.stop;
*/

(
~stringpat3delayktrlbus = Bus.control(s);

~stringpat3setdelaytime =
Pdef(\stringpat3setdelaytime,
	Pbindf(
		~stringpat0setdelaytime,
		\outbus, ~stringpat3delayktrlbus,
));

~stringpat3 =
Pdef(\stringpat3,
	Pbindf(
		~stringpat2,
		\delaytime, ~stringpat3delayktrlbus.asMap,
		\note, [-2, 2],
		\octave, 6
));
);

~stringpat3setdelaytime.play(t, quant: 0.5);
/*
~stringpat3setdelaytime.isPlaying;
~stringpat3setdelaytime.stop;
*/

/*
~stringpat3.play(t, quant: 0.5);
~stringpat3.isPlaying;
~stringpat3.stop;
*/

(
~stringpat4delayktrlbus = Bus.control(s);

~stringpat4setdelaytime =
Pdef(\stringpat4setdelaytime,
	Pbindf(
		~stringpat0setdelaytime,
		\outbus, ~stringpat4delayktrlbus,
));

~stringpat4 =
Pdef(\stringpat4,
	Pbindf(
		~stringpat2,
		\delaytime, ~stringpat4delayktrlbus.asMap,
        \note, [-5, 0],
		\octave, 4
));
);

~stringpat4setdelaytime.play(t, quant: 0.5);
/*
~stringpat4setdelaytime.isPlaying;
~stringpat4setdelaytime.stop;
*/

/*
~stringpat4.play(t, quant: 0.5);
~stringpat4.isPlaying;
~stringpat4.stop;
*/

(
~stringpat5delayktrlbus = Bus.control(s);

~stringpat5setdelaytime =
Pdef(\stringpat5setdelaytime,
	Pbindf(
		~stringpat0setdelaytime,
		\outbus, ~stringpat5delayktrlbus,
));

~stringpat5 =
Pdef(\stringpat5,
	Pbindf(~stringpat2,
		\delaytime, ~stringpat5delayktrlbus.asMap,
		\note, [-2, 2],
		\octave, 4,
));
);

~stringpat5setdelaytime.play(t, quant: 0.5);
/*
~stringpat5setdelaytime.isPlaying;
~stringpat5setdelaytime.stop;
*/

/*
~stringpat5.play(t, quant: 0.5);
~stringpat5.isPlaying;
~stringpat5.stop;
*/

(
~stringpat6delayktrlbus = Bus.control(s);

~stringpat6setdelaytime =
Pdef(\stringpat6setdelaytime,
	Pbindf(
		~stringpat0setdelaytime,
		\outbus, ~stringpat6delayktrlbus,
));

~stringpat6 =
Pdef(\stringpat6,
	Pbindf(~stringpat2,
		\delaytime, ~stringpat6delayktrlbus.asMap,
		\note, [-5, 0],
		\octave, 7,
));
);

~stringpat6setdelaytime.play(t, quant: 0.5);
/*
~stringpat6setdelaytime.isPlaying;
~stringpat6setdelaytime.stop;
*/

/*
~stringpat6.play(t, quant: 0.5);
~stringpat6.isPlaying;
~stringpat6.stop;
*/

(
~stringpat7delayktrlbus = Bus.control(s);

~stringpat7setdelaytime =
Pdef(\stringpat7setdelaytime,
	Pbindf(
		~stringpat0setdelaytime,
		\outbus, ~stringpat7delayktrlbus,
));

~stringpat7 =
Pdef(\stringpat7,
	Pbindf(~stringpat2,
		\delaytime, ~stringpat7delayktrlbus.asMap,
		\note, [-2, 2],
		\octave, 7
));
);

~stringpat7setdelaytime.play(t, quant: 0.5);
/*
~stringpat7setdelaytime.isPlaying;
~stringpat7setdelaytime.stop;
*/

/*
~stringpat7.play(t, quant: 0.5);
~stringpat7.isPlaying;
~stringpat7.stop;
*/

(
~stringpat8delayktrlbus = Bus.control(s);

~stringpat8setdelaytime =
Pdef(\stringpat8setdelaytime,
	Pbindf(
		~stringpat0setdelaytime,
		\outbus, ~stringpat8delayktrlbus,
));

~stringpat8 =
Pdef(\stringpat8,
	Pbindf(~stringpat2,
		\delaytime, ~stringpat8delayktrlbus.asMap,
        \note, [0, 12, 19].stutter(2),
        \octave, 2,
		\xlinestart, 1.01
));
);

~stringpat8setdelaytime.play(t, quant: 0.5);
/*
~stringpat8setdelaytime.isPlaying;
~stringpat8setdelaytime.stop;
*/

/*
~stringpat8.play(t, quant: 0.5);
~stringpat8.isPlaying;
~stringpat8.stop;
*/

//

(
~string0playktrl =
MIDIdef.cc(\string0playktrl, {
    if(~stringpat0.isPlaying.not) {
        ~stringpat0.play(t, quant: 0.5);
        "string0 ([-5, 0], octave 5) play".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~string0stopktrl =
MIDIdef.cc(\string0stopktrl, {
    if(~stringpat0.isPlaying) {
        ~stringpat0.stop;
        "string0 ([-5, 0], octave 5) stop".postln;
    }
}, 52, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~string1playktrl =
MIDIdef.cc(\string1playktrl, {
    if(~stringpat1.isPlaying.not) {
        ~stringpat1.play(t, quant: 0.5);
        "string1 (chords and rests, octave 5) play".postln;
        ~chords.postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~string1stopktrl =
MIDIdef.cc(\string1stopktrl, {
    if(~stringpat1.isPlaying) {
        ~stringpat1.stop;
        "string1 (chords and rests, octave 5) stop".postln;
    }
}, 68, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~string2playktrl =
MIDIdef.cc(\string2playktrl, {
    if(~stringpat2.isPlaying.not) {
        ~stringpat2.play(t, quant: 0.5);
        "string2 ([-5, 0], octave 6) play".postln;
    }
}, 37, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~string2stopktrl =
MIDIdef.cc(\string2stopktrl, {
    if(~stringpat2.isPlaying) {
        ~stringpat2.stop;
        "string2 ([-5, 0], octave 6) stop".postln;
    }
}, 37, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~string3playktrl =
MIDIdef.cc(\string3playktrl, {
    if(~stringpat3.isPlaying.not) {
        ~stringpat3.play(t, quant: 0.5);
        "string3 ([-2, 2], octave 6) play".postln;
    }
}, 53, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~string3stopktrl =
MIDIdef.cc(\string3stopktrl, {
    if(~stringpat3.isPlaying) {
        ~stringpat3.stop;
        "string3 ([-2, 2], octave 6) stop".postln;
    }
}, 53, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~string4playktrl =
MIDIdef.cc(\string4playktrl, {
    if(~stringpat4.isPlaying.not) {
        ~stringpat4.play(t, quant: 0.5);
        "string4 ([-5, 0], octave 4) play".postln;
    }
}, 69, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~string4stopktrl =
MIDIdef.cc(\string4stopktrl, {
    if(~stringpat4.isPlaying) {
        ~stringpat4.stop;
        "string4 ([-5, 0], octave 4) stop".postln;
    }
}, 69, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~string5playktrl =
MIDIdef.cc(\string5playktrl, {
    if(~stringpat5.isPlaying.not) {
        ~stringpat5.play(t, quant: 0.5);
        "string5 ([-2, 2], octave 4) play".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~string5stopktrl =
MIDIdef.cc(\string5stopktrl, {
    if(~stringpat5.isPlaying) {
        ~stringpat5.stop;
        "string5 ([-2, 2], octave 4) stop".postln;
    }
}, 38, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~string6playktrl =
MIDIdef.cc(\string6playktrl, {
    if(~stringpat6.isPlaying.not) {
        ~stringpat6.play(t, quant: 0.5);
        "string6 play".postln;
    }
}, 54, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~string6stopktrl =
MIDIdef.cc(\string6stopktrl, {
    if(~stringpat6.isPlaying) {
        ~stringpat6.stop;
        "string6 stop".postln;
    }
}, 54, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~string7playktrl =
MIDIdef.cc(\string7playktrl, {
    if(~stringpat7.isPlaying.not) {
        ~stringpat7.play(t, quant: 0.5);
        "string7 ([-5, 0], octave 7) play".postln;
    }
}, 70, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~string7stopktrl =
MIDIdef.cc(\string7stopktrl, {
    if(~stringpat7.isPlaying) {
        ~stringpat7.stop;
        "string7 ([-5, 0], octave 7) stop".postln;
    }
}, 70, srcID: ~nanoktrl2.uid, argTemplate: 0);
);



(
~string8playktrl =
MIDIdef.cc(\string8playktrl, {
    if(~stringpat8.isPlaying.not) {
        ~stringpat8.play(t, quant: 0.5);
        "string8 ([0, 12, 19], octave 2) play".postln;
    }
}, 39, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

~string8stopktrl =
MIDIdef.cc(\string8stopktrl, {
    if(~stringpat8.isPlaying) {
        ~stringpat8.stop;
        "string8 ([0, 12, 19], octave 2) stop".postln;
    }
}, 39, srcID: ~nanoktrl2.uid, argTemplate: 0);
);