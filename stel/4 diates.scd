Pdef.removeAll;

// pitch logic
(
~root = 0;
~ratios = [1/1, 16/15, 9/8, 7/6, 5/4, 4/3, 7/5, 3/2, 8/5, 12/7, 7/4, 15/8];
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

// record
/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\bass, { |curve = -2, dur = 1, fb = 2.0, freq = 440, level = 0.1, rq = 1|
	var env				=	Env.perc(0.01, dur, level, curve).kr(2);
	var imp				=	Impulse.ar(0!2, mul: level);
    var comb			=	CombL.ar(imp, (freq).reciprocal, (freq).reciprocal, 2, 3);
    var leakdc          =   LeakDC.ar(comb);
    var rlpf1           =   RLPF.ar(leakdc, LFNoise2.kr((dur).reciprocal).range(1000, 12000).clip(50, SampleRate.ir / 2.5), rq);
    var sinfb			=	SinOscFB.ar(freq * LFNoise2.kr(17!2, 0.003, 1), fb, mul: env * 0.25);
    var rlpf2           =   RLPF.ar(sinfb, (freq * 128).clip(50, SampleRate.ir / 2.5), 0.3);
    var tri             =   LFTri.ar(freq * LFNoise2.kr(0.2!2, 0.001, 1) * 0.5).round(0.02) * env;
	//Out.ar(0, leakdc.fold2(level));
    Out.ar(0, tri + (rlpf1 + rlpf2).wrap2(level));
}).add;
);

(
/*
~durs = (1..3);
~shortestdurs = ~durs.collect({ |i| Pseq([0.25], i) });
~shorterdurs = ~durs.collect({ |i| Pseq([0.5], i) });
~shortdurs = ~durs.collect({ |i| Pseq([0.75], i) });
~mediumdurs = ~durs.collect({ |i| 1 * i });
~longdurs = ~durs.collect({ |i| 1.5 * i });
~longerdurs = ~durs.collect({ |i| 2 * i });
~longestdurs = ~durs.collect({ |i| 3 * i });
~bassdurs = ~shortestdurs ++ ~shorterdurs ++ ~shortdurs ++ ~mediumdurs ++ ~longdurs ++ ~longerdurs ++ ~longestdurs;
*/
Pdef(\basspat1,
	Pbind(
		\instrument, \bass,
        \curve, -4,
        //\dur, Pshuf([Pseq([1/3], 3)] ++ ((1..47).stutter(3) * 0.25), inf),
        \dur, Pshuf([Pseq([1/3], 3), 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf),
        \fb, Pshuf((1..13) / 10, inf),
        //\degree, Pseq([Pshuf([-2, -1, 1, 2, 3, 4, 5, 6, 7, 8, 9], 2), Pseq([Rest], 11)], inf),
        \degree, Pseq([Pshuf([1, 2, 3].stutter(7) ++ [7]), Pseq([Rest], 7)], inf),
        \octave, 3,
		\root, ~root,
        \rq, Pshuf([0.125, 0.25, 0.5, 1].stutter(5), inf),
		\scale, ~scale
));
);

/*
Pdef(\basspat1).play(~tempo);
Pdef(\basspat1).isPlaying;
Pdef(\basspat1).stop;
*/

(
Pdef(\basspat2,
    Pbindf(
        Pdef(\basspat1),
        //\degree, Pseq([Pshuf([0, 7].stutter(11)), Pseq([Rest], 11)], inf)
        //\degree, 0
));
);

//Pdef(\basspat2, Pbindf(Pdef(\basspat1)));

/*
Pdef(\basspat2).play(~tempo);
Pdef(\basspat2).isPlaying;
Pdef(\basspat2).stop;
*/

//Pdef(\basspar, Ppar([Pdef(\basspat1), Pdef(\basspat2)], inf));
//Pdef(\basspar, Ppar([Pdef(\basspat1), Pdef(\basspat2)], inf));
Pdef(\basspar, Ppar([Pdef(\basspat1)], inf));

/*
~basspar.play(~tempo);
~basspar.isPlaying;
~basspar.stop;
*/

~midiktrl.value(\basspar, 49);

/*
(
MIDIdef.cc(\bassplayktrl, {
    if(Pdef(\basspar).isPlaying.not) {
        Pdef(\basspar).play(~tempo, quant: 1);
        "bass play".postln;
    }
}, 49, srcID: ~nanoktrl2.uid, argTemplate: { |x| x > 0 });

MIDIdef.cc(\bassstopktrl, {
    if(Pdef(\basspar).isPlaying) {
        Pdef(\basspar).stop;
        "bass stop".postln;
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
*/

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
        \curve, -32,
        //\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].stutter(3), inf),
        \dur, Pshuf(Array.fill(17, { |i| (i + 1) * 0.25 }), inf),
		\fb, Pshuf(Array.series(10, 0.1, 0.1), inf),
		\level, 0.05,
		\degree, 0,
		\octave, 9,
		\root, ~root,
		\scale, ~scale
));

Pdef(\hatpat2,
    Pbindf(
        Pdef(\hatpat1),
        //\dur, Pshuf([Pseq([0.25], 4), Pseq([0.5], 2), 1, 2].stutter(11), inf),
        \level, 0.015
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
~pulselvl = 0.01;
~pulseecholvl = ~pulselvl / 4;
Pdef(\pulsepat1a,
	Pbind(
		\instrument, \hat,
        \curve, Prand([-16, -8, -4], inf),
        \dur, Pshuf([0.25, 0.5, 0.75, 4, 6, 8, 12, 16, 24].stutter(11), inf),
        //\dur, Pshuf((1..11).stutter(3) * 0.25, inf),
		\fb, Pwhite(2.7, 3.2, inf),
		\level, ~pulselvl,
        \degree, [-5, 0],
		\octave, 4,
		\root, ~root,
		\scale, ~scale
));
Pdef(\pulsepat1b, Pbindf(Pdef(\pulsepat1a), \level, ~pulseecholvl));
Pdef(\pulsepar1, Ppar([Pdef(\pulsepat1a), Pdef(\pulsepat1b), Pdef(\pulsepat1b)]));
);

/*
Pdef(\pulsepat1a).play(~tempo);
Pdef(\pulsepat1a).isPlaying;
Pdef(\pulsepat1a).stop;
*/

/*
Pdef(\pulsepar1).play(~tempo, quant: 1);
Pdef(\pulsepar1).isPlaying;
Pdef(\pulsepar1).stop;
*/

(
Pdef(\pulsepat2a, Pbindf(Pdef(\pulsepat1a), \degree, [0, 7, 10, 12, 14]));
Pdef(\pulsepat2b, Pbindf(Pdef(\pulsepat2a), \level, ~pulseecholvl));
Pdef(\pulsepar2, Ppar([Pdef(\pulsepat2a), Pdef(\pulsepat2b), Pdef(\pulsepat2b)]));
);

/*
Pdef(\pulsepat2a).play(~tempo);
Pdef(\pulsepat2a).stop;
*/

/*
Pdef(\pulsepar2).play(~tempo, quant: 1);
Pdef(\pulsepar2).isPlaying;
Pdef(\pulsepar2).stop;
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
Pdef(\pulsepat4,
    Pbindf(
        Pdef(\pulsepat1a),
        \curve, 4,
        \degree, 0,
        \dur, 0.25,
        \fb, Pshuf(Array.series(10, 0, 0.25), inf),
        \level, Prand([0.3, 1], inf) * 0.002,
        \degree, [7, 10, 12],
        \octave, [5, 6, 8]
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
        \curve, -4,
        \dur, Pshuf([1.25, 1.5, 1.75, 2.25], inf),
        \degree, Pseq([
            Rest, Rest, [2, 7, 10, 12], [2, 7, 10, 12], [2, 7, 10, 12],
            Rest, Rest, Rest, [2, 7, 10, 12], [2, 7, 10, 12], [2, 7, 10, 12],
            Rest, Rest, Rest, Rest, [2, 7, 10, 12], [2, 7, 10, 12], [2, 7, 10, 12]
        ], inf),
        \level, 0.003,
        \octave, [6, 7, 8],
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
~midiktrl.value(\pulsepar4, 33);
~midiktrl.value(\pingpat, 67);

/*
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
*/

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
~degrees = [2, 7, 10, 12].powerset.reject({ |d| d.isEmpty });
Pdef(\prcpat1a,
	Pbind(
		\instrument, \prc,
        //\a, Pshuf([1.0, 1.25, 1.5, 1.75].stutter(13), inf).trace,
        \curve, -4,
        //\dur, Pshuf([Pseq([0.125], 2), 0.25, 0.5, 1, 1.5, 2, 3, 4], inf),
        \dur, Pshuf([Pseq([0.125], 2), 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6].stutter(2), inf),
        //\foldfactor, Pshuf((11..23), inf),
        \foldfactor, Pshuf(Array.fill(7, { |f| (f + 10).nthPrime }), inf),
		\level, Pshuf([0.2, 1, 1] * 0.1, inf),
		\degree, Pshuf(~degrees, inf),
        \octave, 7,
		\root, ~root,
		\scale, ~scale,
		\rez_freq, 2000,
		\rez_rq, 0.5
));
Pdef(\prcpar1, Ppar([Pdef(\prcpat1a)].stutter(1)));
);

/*
Pdef(\prcpar1).play(~tempo, quant: 1);
Pdef(\prcpar1).isPlaying;
Pdef(\prcpar1).stop;
*/

/*
(
//~prc2durs = [0.25, 0.5, 0.75, Pseq([0.375], 2, 3)];
~prc2durs = [0.25, 0.5, 0.75, Pseq([0.375], 2), 1, 1.5, 2, 3, 4, 6];
Pdef(\prcpat2a,
    Pbindf(
        Pdef(\prcpat1a),
        //\a, Pshuf([1.4, 1.9], inf),
        \a, Pshuf([1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8], inf),
        \curve, -8,
        /*
        \dur, Pshuf([
            0.5, 0.75, 1.25,
            0.5, 0.5, 0.75, 1.25,
            0.5, 0.5, 0.5, 0.75, 1.25
        ], inf),
        */
        //\dur, Pshuf(~prc2durs.stutter(3), inf),
        \dur, Pshuf(~prc2durs, inf),
        \foldfactor, Pshuf(Array.fill(7, { |f| (f + 17).nthPrime }), inf),
        \level, Pshuf([0.2, 1], inf) * 0.1,
        \degree, [0, 7],
        \octave, Pshuf([4, 6].stutter(7), inf),
        \scale, ~scale
));
Pdef(\prcpat2b, Pbindf(Pdef(\prcpat2a), \dur, Pshuf(~prc2durs.stutter(5))));
Pdef(\prcpar2, Ppar([Pdef(\prcpat2a), Pdef(\prcpat2b)], inf));
);
*/

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
        \dur, Pshuf([Pseq([0.25], 2), 0.5, 0.75, 1, 1.5, 2, Pseq([0.75], 2), 3, 4, 6, 8].stutter(5), inf),
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

~midiktrl.value(\prcpar, 50);
/~midiktrl.value(\prcpar2, 51);

/*
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
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\prc2, { |a = 1.0, curve = -16, dur = 1, freq = 440, level = 0.1, releaseTime = 1|
    var env             =   Env.perc(0.003, releaseTime, level, curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var latoo           =   LatoocarfianC.ar([freq - 10, freq + 10], a, mul: XLine.kr(3, 0.1, 0.1), add: 1);
    var sin             =   SinOsc.ar(freq * latoo, mul: envgen);
    Out.ar(0, sin);
}).add;
);

(
Pdef(\prc2,
    Pbind(
        \instrument, \prc2,
        \a, Pxrand((1..3), inf),
        \curve, Prand([-32, -16], inf),
        \dur, Pshuf([0.25, 0.5, 0.75, Pseq([0.375], 2), 1, 1.5, 2, 3, 4, 6], inf),
        \level, 0.1,
        \octave, Prand([3, 4, 7], inf),
        \releaseTime, Prand([1, 1.5], inf),
        \scale,  ~scale
));

Pdef(\prc2echo, Pbindf(Pdef(\prc2), \dur, Prand([0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2], inf), \level, 0.02));

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
		//\dur, Pshuf([0.25, 0.5, 0.75, 1, 1.5, 6], inf),
        \dur, Pshuf(Array.fill(17, { |d| (d + 0.25) }), inf),
		\fb, Pwhite(0.0, 1.0, inf),
		\foldfactor, Pwhite(1, 20, inf),
        \level, 0.05,
		//\degree, Pshuf([-2, 0, 1, 2, 3, 7], inf),
        \degree, 0,
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

~midiktrl.value(\banjopar, 66);

/*
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
*/

////////////////////////////////////////////////////////////////

(
SynthDef(\pno, { |a = 1, b = 3, curve = -16, dur = 1, fb = 0, freq = 440, latfreq = 10000, level = 0.1, pan = 0|
    var env             =   Env.perc(0.003, dur, level: level, curve: curve);
    var envgen          =   EnvGen.kr(env, doneAction: 2);
    var lat             =   Latoocarfian2DN.kr(a: [a, a - 0.002], b: [b, b - 0.002], mul: 1, add: 1).round(0.25);
    //var ampmod          =   LFBrownNoise0.kr(15!2, add: 1).round(0.5);
	var sinfb           =   SinOscFB.ar(freq, fb, envgen * lat);
	var sin				=	SinOsc.ar(freq!2, pi /4, envgen);
    var rhpf            =   RHPF.ar(sinfb, (freq * 2).clip(50, SampleRate.ir / 3), 0.05);
    Out.ar(0, rhpf + sin);
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
        \level, 0.003,
        \degree, [2, 7, 10, 12],
        \octave, [4, 5, 7],
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

/*
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
*/

////////////////////////////////////////////////////////////////

/*
(
SynthDef(\string, { |delaytime = 0.03, dur = 1, fb = 0, freq = 440, gate = 1, level = 0.01, xlinestart = 1|
	var env				=	Env.asr(0.1, level, 0.1, -4);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
    //var xlinemod        =   LFBrownNoise0.kr(13!2, mul: 0.03, add: 1);
	var xline			=	XLine.kr(xlinestart, 1, dur / 2);
	var fbmod			=	SinOsc.ar(freq * xline, mul: 1, add: 1);
	//var n				=	3;
	//var mix 			=	Mix.fill(n, {
		//var freqmodmod		=	LFNoise1.kr(1!2).range(1, 10);
		//var freqmod			=	LFNoise1.kr(freqmodmod, 0.0, 1);
		//var sinfb			=	(SinOscFB.ar(freq, fbmod).round(0.9) * (envgen / n)).fold2(level / 2);
		//sinfb;
	//});
    var mix             =	SinOscFB.ar(freq, fbmod * fb).round(0.9).fold2(0.5) * 3 * envgen;
	var delay			=	DelayC.ar(mix, 0.2, delaytime.clip(0.00008, 0.1));
    //var lopass			=	RLPF.ar(mix + delay, (freq * 4).clip(50, SampleRate.ir / 2.5), 0.5);
    var hpfampmod       =   LFBrownNoise0.kr(15!2).range(0.3, 1).round(0.7);
	var rhpf			=	RHPF.ar(mix + delay, (freq * 8).clip(50, SampleRate.ir / 3), 0.1) * hpfampmod;
    var sin             =   SinOscFB.ar(freq!2, 1.5, envgen * 0.25) ;
	//Out.ar(0, mix + rhpf + sin);
    Out.ar(0, mix + delay + rhpf + sin);
}).add;
);
*/

(
SynthDef(\string, { |delaytime = 0.01, dur = 1, fb1 = 0, fb2 = 0, freq = 440, gate = 1, level = 0.015, xlinestart = 1|
    var env             =   Env.asr(0.01, level, 0.1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var xline           =   XLine.kr(xlinestart, 0.9999, dur / 2);
    var fbmod           =   SinOscFB.ar([freq - 0.03, freq + 0.03] * xline * LFNoise2.kr(0.2!2, 0.05, 1), fb1, 1, 1);
    var carrier         =   SinOscFB.ar(freq, fb2 * fbmod, envgen);
    var delay           =   DelayC.ar(carrier, 1, delaytime.clip(0.00008, 0.1));
    Out.ar(0, carrier + delay);
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
		\dur, 5,
		\degree, [-5, 0],
        \fb1, 1,
        \fb2, 1,
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
	[-5, -2, 0], [-5, 0, 0], [-5, 0, 1], [-5, 0, 2], [0, 3, 7], [0, 6, 7], [0, 7, 7]
];
~rests = Rest!(~chords.size / 2);
~chordsandrests = ~chords ++ ~rests;

Pdef(\stringpat1,
	Pbind(
		\instrument, \string,
		\delaytime, ~stringpat1delayktrlbus.asMap,
		\dur, Pshuf(Array.fill(5, { |i| (i + 7).nthPrime }), inf),
        //\fb1, Pshuf([0.25, 0.5, 1].stutter(7), inf),
        //\fb2, Pshuf([0.5, 1].stutter(3), inf),
        \fb1, 1,
        \fb2, 1,
		\legato, 1,
		\degree, Pshuf(~chords, inf),
		\octave, 5,
		\root, ~root,
		\scale, ~scale,
        \xlinestart, Pshuf([1/2, 2/3, 7/8, 1/1, 3/2, 7/4, 2/1].stutter(5), inf),
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
~stringpat5delayktrlbus = Bus.control(s);

Pdef(\stringpat5setdelaytime,
	Pbindf(
		Pdef(\stringpat0setdelaytime),
		\outbus, ~stringpat5delayktrlbus,
));

Pdef(\stringpat5,
	Pbindf(Pdef(\stringpat2),
		\delaytime, ~stringpat5delayktrlbus.asMap,
        \degree, [-5, 0],
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

//{
    //s.sync;
(
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
);
//};

/*
Pdef(\stringpat0setdelaytime).isPlaying;
*/


/*
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
*/

//

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
~scene1 = [\basspar, \prcpar];
~scene1lights = [49, 50];
~scenetoggle.value(\scene1, 104, ~scene1, starterlights: ~scene1lights);
);

(
~scene2stoppers = [\pulsepat1a, \hatpar];
~scene2stopperlights = [32, 34];
~scenetoggle.value(\scsne2, 105, stoppers: ~scene2stoppers, stopperlights: ~scene2stopperlights);
);

(
~scene3 = [\pulsepat1a, \pulsepat2a, \hatpar, \pnopat, \banjopar];
~scene3lights = [32, 48, 34, 35, 66];
~scenetoggle.value(\scene3, 106, ~scene3, starterlights: ~scene3lights);
);

(
~scene4stoppers = [\pulsepat1a, \pulsepat2a, \hatpar];
~scene4stopperlights = [32, 48, 34];
~scenetoggle.value(\scene4, 107, stoppers: ~scene4stoppers, stopperlights: ~scene4stopperlights);
);

(
~scene5 = [\pulsepat1a, \pulsepat2a, \pulsepat3a, \hatpar, \prcpar2];
~scene5lights = [32, 48, 64, 34, 51];
~scenetoggle.value(\scene5, 108, ~scene5, starterlights: ~scene5lights);
);

(
~scene6 = [\pingpat, \stringpat0];
~scene6lights = [67, 52];
~scene6stoppers = [\pulsepat1a, \pulsepat2a, \pulsepat3a, \basspar, \hatpar, \banjopar];
~scene6stopperlights = [32, 48, 64, 49, 34, 66];
~scenetoggle.value(\scene6, 109, ~scene6, ~scene6stoppers, ~scene6lights, ~scene6stopperlights);
);

/*
(
~scene7stoppers = [\prcpar];
);
*/