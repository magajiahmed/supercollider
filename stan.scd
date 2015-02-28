t = TempoClock(108/60);

(
~chrom = Scale.chromatic;
~delay = 0.01;
~root = 3;
~scale = Scale.new([0, 1, 2, 3, 5, 7, 10]);
);

////////////////////////////////////////////////////////////////
// MIDI

MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl2 = ~midisource = MIDIClient.sources.detect{ arg a; a.name.contains("nanoKONTROL2")};


////////////////////////////////////////////////////////////////
// DELAY (to compensate for limiter delay)

(
SynthDef(\delay, {
	var in				= 	In.ar(2, 2);
	var delay			=	DelayC.ar(in, ~delay * 2, ~delay * 2);
	Out.ar(0, delay);
}).add;
);

~delay = Synth(\delay).register;

/*
~delay.free;
*/

////////////////////////////////////////////////////////////////
// LIMITER

(
SynthDef(\limiter, {
	var in				=	In.ar(4, 2);
	var limiter 		=	Limiter.ar(in, 0.999, ~delay);
	Out.ar(0, limiter);
}).add;
);

~limiter = Synth(\limiter).register;

/*
~limiter.free;
*/

////////////////////////////////////////////////////////////////
// SYNTH

(
SynthDef(\stansyn, { | curve = -4, dur = 1, fbamp = 1, freq = 262, level = 0.08 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var crackle			=	Crackle.kr.range(0.5, 2);
	var sinfb			=	SinOscFB.ar([freq, freq + 0.01], crackle * fbamp, envgen);
	var sin				=	SinOsc.ar(freq!2, mul: envgen);
	Out.ar(2, sinfb + sin);
}).add;
);

// Pattern

(
~stan = Pstandard(k: 1.5).asStream;

~stanpitches = Prout({
	var x;
	loop({
		x = ~stan.next[0] * ~chrom.degrees.size;
		x.yield;
	})
});

~durs = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24];
//~durs = [0.25, 0.5, 0.75, 1, 1.5];
~standurs = Prout({
	var x;
	loop({
		x = ~stan.next[1] * ~durs.size;
		x.yield;
	})
});

~stanpat1 =
Pdef(\stanpat1,
	Pbind(
		\instrument, \stansyn,
		\curve, -4,
		\degree, Pswitch1(~chrom.degrees, ~stanpitches),
		\dur, Pswitch1(~durs, ~standurs),
		\fbamp, 0.3,
		\root, ~root,
		\scale, ~chrom
));

~stanpar = Pdef(\stanpar, Ppar(~stanpat1!3, inf));
);

/*
~stanpat1.play(t, quant: 1);
~stanpat1.isPlaying;
~stanpat1.pause;
~stanpat1.stop;
*/

/*
~stanpar.play(t, quant: 1);
~stanpar.isPlaying;
~stanpar.pause;
~stanpar.stop;
*/

(
~stanplayktrl =
MIDIdef.cc(\stanplayktrl, {
	if(~stanpar.isPlaying.not) {
		~stanpar.play(t, quant: 1);
		"stan play".postln;
	}
}, 32, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~stanstopktrl =
MIDIdef.cc(\stanstopktrl, {
	if(~stanpar.isPlaying) {
		~stanpar.pause;
		"stan stop".postln;
	}
}, 32, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////
// BASS

(
~hen = Phenon.new(1.3095).asStream;

~henpitches = Prout({
	var x;
	loop({
		x = ~hen.next[0] * ~chrom.degrees.size;
		x.yield;
	})
});

~bassdurarr = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6];
~bassdurs = Prout({
	var x;
	loop({
		x = ~hen.next[1] * ~bassdurarr.size;
		x.yield;
	})
});

~basspat =
Pdef(\basspat,
	Pbind(
		\instrument, \stansyn,
		\degree, Pswitch1(~chrom.degrees, ~henpitches),
		\dur, Pswitch1(~bassdurarr, ~bassdurs),
		\octave, 2,
		\root, ~root,
		\scale, ~scale,
));
);

/*
~basspat.play(t, quant: 1);
~basspat.isPlaying;
~basspat.pause;
~basspat.stop;
*/

(
~bassplayktrl =
MIDIdef.cc(\bassplayktrl, {
	if(~basspat.isPlaying.not) {
		~basspat.play(t, quant: 1);
		"bass play".postln;
	}
}, 33, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~bassstopktrl =
MIDIdef.cc(\bassstopktrl, {
	if(~basspat.isPlaying) {
		~basspat.pause;
		"bass stop".postln;
	}
}, 33, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////
// PRC

(
SynthDef(\prc, { | a = 1, b = 1.9, curve = -64, dur = 1, foldfactor = 0.1, freq = 20000, level = 0.1, pan = 0 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	var cusp			=	CuspL.ar(freq, a: a, b: b);
	var cuspfold		=	cusp.fold2(foldfactor) * envgen * foldfactor.reciprocal * 2;
	var rhpf			=	RHPF.ar(cuspfold, (freq * 4).clip(50, SampleRate.ir / 3), 0.2);
	var pan2			=	Pan2.ar(cuspfold + rhpf, pan);
	Out.ar(4, pan2);
}).add;
);

~phenon = Phenon.new(1.3149494).asStream;

(
~a = Prout({
	var x;
	loop({
		x = (~phenon.next[0]) + 0.5;
		x.yield;
	})
});

~prcdurarr = [0.25, 0.5, 0.75];
~prcdurs = Prout({
	var x;
	loop({
		x = ~phenon.next[1] * ~prcdurarr.size;
		x.yield;
	})
});

~b = Prout({
	var x;
	loop({
		x = (~phenon.next[0]) + 1;
		x.yield;
	})
});

~prcpat1 =
Pdef(\prcpat1,
	Pbind(
		\instrument, \prc,
		\dur, Pswitch1(~prcdurarr, ~prcdurs),
		\a, ~a,
		\b, ~b,
		\foldfactor, Pshuf(Array.fill(7, { |i| 7.pow((i) * -1) }), inf),
		\freq, Prand([100, 150, 200, 1000, 1500, 2000, 10000, 15000, 20000], inf),
		\pan, Prand([-1, -0.5, -0.25, 0, 0.25, 0.5, 1], inf),
));
);

/*
~prcpat1.play(t, quant: 1);
~prcpat1.isPlaying;
~prcpat1.pause;
*/

~prcpat2 = Pdef(\prcpat2, Pbindf(~prcpat1, \dur, 0.25, \level, 0.04));

/*
~prcpat2.play(t, quant: 1);
~prcpat2.isPlaying;
~prcpat2.pause;
*/

(
~prc1playktrl =
MIDIdef.cc(\prc1playktrl, {
	if(~prcpat1.isPlaying.not) {
		~prcpat1.play(t, quant: 0.5);
		"prc1 play".postln;
	}
}, 34, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~prc1stopktrl =
MIDIdef.cc(\prc1stopktrl, {
	if(~prcpat1.isPlaying) {
		~prcpat1.pause;
		"prc1 stop".postln;
	}
}, 34, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

//

(
~prc2playktrl =
MIDIdef.cc(\prc2playktrl, {
	if(~prcpat2.isPlaying.not) {
		~prcpat2.play(t, quant: 0.5);
		"prc2 play".postln;
	}
}, 50, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~prc2stopktrl =
MIDIdef.cc(\prc2stopktrl, {
	if(~prcpat2.isPlaying) {
		~prcpat2.pause;
		"prc2 stop".postln;
	}
}, 50, srcID: ~nanoktrl2.uid, argTemplate: 0)
);

////////////////////////////////////////////////////////////////
// DRONE

(
SynthDef(\drone, { |fbmin = 2.0, freq = 440, gate = 1, level = 0.15|
	var env				=	Env.asr(0.1, level, 2).kr(gate: gate, doneAction: 2);
	var mix				=	Mix.fill(4, {
		var fbmod			=	LFBrownNoise2.kr(3).range(fbmin, fbmin + 1);
		var sinfb			=	SinOscFB.ar(freq!2, fbmod);
		var moogvcf			=	MoogVCF.ar(sinfb, ([freq, freq + 1]).clip(50, SampleRate.ir / 3), 0.1);
		moogvcf;
	});
	var ampmod			=	LFBrownNoise0.kr(30!2).range(0.5, 1.0).round(0.8);
	Out.ar(2, (mix * ampmod).fold2(0.05) * env * 5);
}).add;
);

(
~dronepat =
Pdef(\dronepat,
	Pbind(
		\instrument, \drone,
		\dur, Pshuf((23..27).collect({ |item, i| item.nthPrime }), inf),
		\legato, 0.5,
		\fbmin, 0.0,
		\note, Pshuf([0, 2, 5, 7], inf),
		\root, ~root,
		\octave, 6
));

~dronepar = Pdef(\dronepar, Ppar(~dronepat!4, inf));
);

/*
~dronepat.play(t, quant: 1);
~dronepat.isPlaying;
~dronepat.stop;
*/

/*
~dronepar.play(t, quant: 1);
~dronepar.isPlaying;
~dronepar.pause;
*/

(
~droneplayktrl =
MIDIdef.cc(\droneplayktrl, {
	if(~dronepar.isPlaying.not) {
		~dronepar.play(t, quant: 1);
		"drone play".postln;
	}
}, 35, srcID: ~nanoktrl2.uid, argTemplate: { arg x; x > 0 });

~dronestopktrl =
MIDIdef.cc(\dronestopktrl, {
	if(~dronepar.isPlaying) {
		~dronepar.pause;
		"drone stop".postln;
	}
}, 35, srcID: ~nanoktrl2.uid, argTemplate: 0)
);