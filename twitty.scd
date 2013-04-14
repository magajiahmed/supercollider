////////////////////////////////////////////////////////////////////////////////
//
// TODO: Document/comment code
//
////////////////////////////////////////////////////////////////////////////////
//                          INIT
(

t = TempoClock(96/60);
~keyfrq = 64;

////////////////////////////////////////////////////////////////////////////////
// 							GRAPHICAL MONITORING

Stethoscope.new(s);

(
w = Window("Analyzer", Rect(0, 0, 511, 300));
f = FreqScopeView(w, w.view.bounds);
f.active_(true); // turn it on the first time;

w.onClose_({ f.kill }); // you must have this
w.front;
);

////////////////////////////////////////////////////////////////////////////////
//							RECORDING

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////////////////////////////
//							SYNTHDEFS

// compressor

~compressor =
SynthDef(\compressor, {
	var in	   		= 	In.ar(2, 2);                          // stereo input bus
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.002, relaxTime: 0.01,
							slopeAbove: 1/128); // compressor
	Out.ar(0, compressor);
}).play;

// bass

~sawbass =
SynthDef(\sawbass, { |dur = 1, freq = 440, peak = 0.5|
	var env			=	Env.new([0, peak, 0], [0.002, dur / 1.5]);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var envgendiv	=	6;
	var kbnfrq		=	10;
	var kbnmul		=	0.01;
	var kbn1		=	LFBrownNoise0.kr(kbnfrq, mul: kbnmul, add: 1);
	var kbn2		=	LFBrownNoise0.kr(kbnfrq, mul: kbnmul, add: 1);
	var saw1		=	SyncSaw.ar(freq, freq, mul: envgen / envgendiv);
	var saw2		=	SyncSaw.ar((freq) * kbn1, freq * kbn2, mul: envgen / envgendiv);
	var saw3		=	SyncSaw.ar((freq) * kbn2, freq * kbn1, mul: envgen / envgendiv);
	var tri			=	LFTri.ar(freq, mul: envgen / 4);
	var cutoff		=	(freq * 3).clip(60, SampleRate.ir / 3);
	var flt			=   RLPF.ar(saw1 + saw2 + saw3 + tri, cutoff, 0.75);
	Out.ar([0, 1], flt);
}).add;

// drone

~drone =
SynthDef(\drone, { |freq = 256, freqratio = #[1, 1.5], gate = 1, kbnammul = 0.85, kbnfmmul = 0.005, peak = 1|
	var kbnfmfreq	=	freq;
	var kbnamfreq	= 	20;
	var env			=	Env.asr(1, peak, 10, 0);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 2);
	var kbnfmod1	=	LFBrownNoise0.kr(kbnfmfreq, mul: kbnfmmul, add: 1);
	var kbnfmod2	=	LFBrownNoise0.kr(kbnfmfreq, mul: kbnfmmul, add: 1);
	var kbnfmod3	=	LFBrownNoise0.kr(kbnfmfreq, mul: kbnfmmul, add: 1);
	var kbnfmod4	=	LFBrownNoise0.kr(kbnfmfreq, mul: kbnfmmul, add: 1);
	var kbnamod1	=	LFBrownNoise0.kr(kbnamfreq, mul: kbnammul, add: 1);
	var kbnamod2	=	LFBrownNoise0.kr(kbnamfreq, mul: kbnammul, add: 1);
	var kbnamod3	=	LFBrownNoise0.kr(kbnamfreq, mul: kbnammul, add: 1);
	var kbnamod4	=	LFBrownNoise0.kr(kbnamfreq, mul: kbnammul, add: 1);
	var sin1a		=	SinOsc.ar(freq * freqratio * kbnfmod1, 			mul: envgen * kbnamod1);
	var sin1b		=	SinOsc.ar(freq * 1.003 * freqratio, 			mul: envgen * kbnamod1);
	var sin2a		=	SinOsc.ar(freq * 2 * freqratio * kbnfmod2, 		mul: (envgen / 4) * kbnamod2);
	var sin2b		=	SinOsc.ar(freq * 2.005 * freqratio, 			mul: (envgen / 4) * kbnamod2);
	var sin3a		=	SinOsc.ar(freq * 4 * freqratio * kbnfmod3, 		mul: (envgen / 16) * kbnamod3);
	var sin3b		=	SinOsc.ar(freq * 4.01 * freqratio, 				mul: (envgen / 16) * kbnamod3);
	Out.ar([0, 1], (sin1a + sin1b + sin2a + sin2b + sin3a + sin3b) / 256);
}).add;

// pad

~pad =
SynthDef(\pad, { |dur = 1, envgendivisor = 8, freq = 512, gate = 1, kbnmul = 0.005, peak = 1|
	var kbnfreq		=	freq;
	var env			=	Env.sine(dur, peak);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 2);
	var kbn1		=	LFBrownNoise0.kr(freq, mul: kbnmul, add: 1);
	var saw1		=	LFSaw.ar(freq * kbn1, mul: (envgen / envgendivisor));
	var kbn2		=	LFBrownNoise0.kr(freq, mul: kbnmul, add: 1);
	var saw2		=	LFSaw.ar((freq + 0.1) * kbn2, mul: (envgen / envgendivisor));
	var kbn3		=	LFBrownNoise0.kr(freq, mul: kbnmul, add: 1);
	var saw3		=	LFSaw.ar((freq - 0.1) * kbn3, mul: (envgen / envgendivisor));
	var rlpf		=	RLPF.ar(saw1 + saw2 + saw3, freq * 1.5, 0.5, mul: envgen / 2);
	var deci		=	Decimator.ar(saw1 + saw2 + saw3, rate: 16000, bits: 3, mul: envgen);
	var kbn4		=	LFBrownNoise0.kr(mul: 0.5, add: 1);
	var hpffrq		=	(freq * 6 * kbn4).clip(100, SampleRate.ir / 3);
	var kbn5		=	LFBrownNoise0.kr(mul: 0.75, add: 1).clip(0.1, 1);
	var rhpf		=	RHPF.ar(deci, hpffrq, kbn5, mul: envgen);
	Out.ar([0,1], rlpf + rhpf);
}).add;

/*
~padtest = Synth(\pad, [\dur, 20, \freq, 2500]).register;
~padtest.isPlaying;
~padtest.release;

d = DebugNodeWatcher(s);
d.start;
d.stop;
*/

// squirp

~squirp =
SynthDef(\squirp, { |amp = 1, dur = 8, freq = 512, squirpamp = 0.05|
	var env			=	Env.perc(0.002, releaseTime: dur, level: amp / 1.5, curve: 0);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var squirp1		=	LinCongC.ar(freq, mul: squirpamp, add: 1);
	var sin1		=	SinOsc.ar(freq * squirp1, mul: (envgen / 5));
	var squirp2		=	LinCongC.ar((freq + 0.1), mul: squirpamp, add: 1);
	var sin2		=	SinOsc.ar((freq + 0.1) * squirp2, mul: (envgen / 5));
	var squirp3		=	LinCongC.ar(freq * 8, mul: squirpamp * 8, add: 1);
	var sin3		=	SinOsc.ar(freq * 8 * squirp3, mul: (envgen / 72));
	Out.ar([0, 1], [sin1 + sin3, sin2 + sin3]);
}).add;

// pling

~burn =
SynthDef(\sin, { |amp = 1, curve = -4, dur = 1, envgendiv = 32, freq = 440, mulkbn = 0.9, mulcrckl = 0.01, xaos = 1.99|
	////////////////////////////////////////////////////////////////////////////////
	var env			=	Env.perc(0.005, releaseTime: dur, level: amp, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	///////////////////////////////////////////////////////////////////////////
	var crckl1		= 	Crackle.kr(chaosParam: xaos, mul: mulcrckl, add: 1);
	var sin1		=	SinOsc.ar(freq * crckl1, mul: envgen / 3);
	var kbn1		=	LFBrownNoise0.kr(freq, mul: mulkbn, add: 1);
	var sin1a		=	SinOsc.ar(freq * crckl1 * kbn1 * 8, mul: (envgen / envgendiv));
	////////////////////////////////////////////////////////////////////////////
	var crckl2		= 	Crackle.kr(chaosParam: xaos, mul: mulcrckl, add: 1);
	var sin2		=	SinOsc.ar(freq * crckl2, mul: envgen / 3);
	var kbn2		=	LFBrownNoise0.kr(freq, mul: mulkbn, add: 1);
	var sin2a		=	SinOsc.ar(freq * crckl2 * kbn2 * 8, mul: (envgen / envgendiv));
	////////////////////////////////////////////////////////////////////////////
	var sin3		=	SinOsc.ar(freq, mul: envgen / 3);
	var kbn3		=	LFBrownNoise0.kr(freq, mul: mulkbn, add: 1);
	var sin3a		=	SinOsc.ar(freq * kbn3 * 8, mul: (envgen / envgendiv));
	///////////////////////////////////////////////////////////////////
	Out.ar([0, 1], sin1 + sin1a + sin2 + sin2a + sin3 + sin3a);
}).add;

// ox

~ox =
SynthDef(\ox, { |dur = 1, end = 0.5, freq= 440, length = 0.25, peak = 1|
	var env			=	Env.perc(0.002, releaseTime: dur / 2, level: peak / 8, curve: -64);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var penv		=	XLine.kr(end: end, dur: dur / 32, add: 1);
	var kbn1		=	LFBrownNoise0.kr(freq, add: 1);
	var kbn2		=	LFBrownNoise0.kr(freq, add: 1);
	var kimp		=	Impulse.kr(freq * penv, mul: kbn1, add: 1);
	var sin			=	SinOsc.ar(freq * kimp * penv, mul: envgen * kbn2);
	Out.ar([2, 3], sin);
}).add;

// pad2

~pad2 =
SynthDef(\pad2, { |freq = 256, gate = 1, kbnmul = 0.0075, peak = 1, width = 0.5|
	var env			=	Env.adsr(5, 1, peak, 10, peak, curve: -4);
	var envgen		=	EnvGen.kr(env, gate, doneAction: 2);
	var kbn1		=	LFBrownNoise0.kr(freq / 8, mul: kbnmul, add: 1);
	var saw1		=	VarSaw.ar(freq * kbn1, width: width, mul: envgen / 128);
	var kbn2		=	LFBrownNoise0.kr(freq / 8, mul: kbnmul, add: 1);
	var saw2		=	VarSaw.ar((freq + 0.1) * kbn2, width: width, mul: envgen / 128);
	var kbn3		=	LFBrownNoise0.kr(freq / 4, mul: 0.1, add: 1);
	var cutoff		=	(freq * 2 * kbn3).clip(50, SampleRate.ir / 3);
	var rlpf		=	RLPF.ar(saw1 + saw2, cutoff, 0.1);
	Out.ar([0, 1], rlpf);
}).add;

// prc based on xaotic fn

~foibles =
SynthDef(\latte, { |a = 1, b = 3, curve = -8, length = 0.2, pan = 0, peak = 1|
	var env			=	Env.perc(releaseTime: length, level: peak, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var lat			=	Latoocarfian2DN.ar(a: a, b: b, mul: envgen);
	var pan2		= 	Pan2.ar(lat, pan);
	Out.ar(2, pan2);
}).add;

// clicky prc

~germ =
SynthDef(\imp, { |frq = 2000, pan = 0, peak = 1, rq = 1|
	var env			=	Env.perc(0.005, level: peak);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var imp			=	Impulse.ar(0, mul: envgen);
	var flt			=	RLPF.ar(imp, frq, rq);
	var pan2		=	Pan2.ar(flt, pan);
	Out.ar(2, pan2);
}).add;

////////////////////////////////////////////////////////////////////////////////////
//							PATTERNS

// bass
~morse =
Pdef(\mutter,
	Pbind(
		\instrument, 	\sawbass,
		\dur, 			Pshuf([0.25, 0.5, 0.75, 1, 1.5, 8, 12, 16, 24].mirror, inf),
		\freq, 			Pseq([
							1/1, 16/15,
							1/1, 1/1, 9/8,
							1/1, 1/1, 1/1, 6/5, 16/15
						] * ~keyfrq, inf),
		\peak, 			0.1
));

/*
~morse.play(t, quant: 1);
~morse.stop;
*/

~squirpy1 =
Pdef(\squirpy,
Pbind(
	\instrument, 		\squirp,
	\dur, 				Prand([0.25, 4, 6, 8, 12, 16, 24], inf),
	\freq, 				Pshuf([9/10, 1/1, 16/15, 9/8, 6/5, 3/2, 9/5, 32/15, 9/4, 13/5] * ~keyfrq * 8, inf),
));

/*
~squirpy1.play(t, quant: 1);
~squirpy1.stop;
*/

~squirpy2 = Pdef(\squirpy2, Pbindf(~squirpy1));

/*
~squirpy2.play(t, quant: 1);
~squirpy2.stop;
*/

// pad ///////////////////////////////////////////////

~padpat =
Pdef(\padpat,
	Pbind(
		\instrument, 	\pad,
		\dur, 			Pshuf([21, 23, 25, 27, 29], inf),
		\freq, 			Pshuf([1/1, 16/15, 9/8, 8/7, 6/5, 9/7, 11/8, 7/5, 10/7, 3/2, 11/7, 8/5, 13/8, 12/7, 9/5, 13/7, 11/5, 13/5, 13/3] * ~keyfrq * 4, inf),
		\peak, 			0.2,
));

/*
~padpat.play(t, quant: 1);
~padpat.stop;
*/

~padchords =
Pdef(\padchords,
Ppar([~padpat, ~padpat, ~padpat], inf
));

/*
~padchords.play(t, quant: 1);
~padchords.stop;
*/

// prc1a /////////////////////////////////////////////

~gazelle =
Pdef(\moisture,
	Pbind(
		\instrument, 	\latte,
		\a, 			Pwhite(0.1, 1, inf),
		\b, 			Pwhite(1, 3, inf),
		\dur, 			Pwrand([Pseq([0.25 / 2], 4), 0.5, 0.75, 6, 9], [1, 16, 16, 4, 4].normalizeSum, inf),
		\pan, 			Pshuf([-1, -0.5, 0, 0.5, 1], inf),
		\peak, 			Pwhite(0.75, 1, inf) / 4,
));

/*
~gazelle.play(t, quant: 1);
~gazelle.stop;
*/

// prc1b

~gauze =
Pdef(\gumboots,
	Ppar(
		[~gazelle, ~gazelle], inf
));

/*
~gauze.play(t, quant: 1);
~gauze.stop;
*/

// prc1c

~bandage =
Pdef(\gobble,
	Ppar(
		[~gauze, ~gauze], inf
));

/*
~bandage.play(t, quant: 1);
~bandage.stop;
*/

// imp (clicky) //////////////////////////

~godliness =
Pdef(\huddled,
	Pbind(
		\instrument, 	\imp,
		\dur, 			Pxrand([0.5, 0.75, 1.5], inf),
		\frq, 			Prand([4000, 8000, 16000], inf),
		\pan, 			Prand([-1, 0, 1], inf),
		\peak, 			Pwhite(0.75, 1, inf) / 4,
		\rq, 0.1
));

/*
~godliness.play(t, quant: 1);
~godliness.stop;
*/

// clicky echo ///////////////////////////

~gumption =
Pdef(\homesick,
	Pbindf(~godliness,
		\dur, 			Pwrand([Pseq([0.125], 2), Pseq([0.125], 4), 0.5, 0.75, 1.5], [1, 1, 16, 16, 16].normalizeSum, inf),
		\peak, 			Pwhite(0.75, 1, inf) / 12,
		\rq, 			0.05
));

~desert =
Pdef(\fluster,
	Ppar([~gumption, ~gumption], inf));

/*
~desert.play(t, quant: 1);
~desert.stop;
*/

// imp for 2nd section

~klikk2 =
Pdef(\klikk,
	Pbind(
		\instrument, \imp,
		\dur, Pshuf([0.75, 1, 1.5, 2].mirror2, inf),
		\peak, Pwhite(0.75, 1, inf),
));

/*
~klikk2.play(t, quant: 1);
~klikk2.stop;
*/
// kik ///////////////////

~bonk =
Pdef(\borne,
	Pbind(
		\instrument, 	\latte,
		\a, 			3,
		\b, 			Pwhite(0.11, 0.114, inf),
		\curve, 		-4,
		\dur, 			Pxrand([0.25, 0.5, 0.75, 1, 1.5, 4, 6, 16, 24], inf),
		\length, 		0.25,
		\pan, 			Pwhite(-0.5, 0.5, inf),
		\peak, 			Pwhite(0.75, 1, inf),
));

/*
~bonk.play(t, quant: 1);
~bonk.stop;
*/

// snr ////////////////////

~guzzle =
Pdef(\horned,
	Pbind(
		\instrument, 	\latte,
		\a, 			Pwhite(0.925, 0.926, inf),
		\curve, 		-16,
		\dur, 			Pxrand([0.75, 1, 1.5, 2, 4, 6, 16, 24], inf),
		\length, 		0.1,
		\note, 			Pseq([Rest, 1], inf),
		\peak, 			0.3,
));

/*
~guzzle.play(t, quant: 1);
~guzzle.stop;
*/

// pling /////////////////////////////////////////////////////////////

~forked =
Pdef(\fillery,
	Pbind(
		\instrument, 	\sin,
		\amp, 			0.02,
		\dur, 			Pshuf([0.25, 4, 6, 8, 12, 16, 24, 32, 48], inf),
		\freq, 			Pseq([9/10, 1/1, 16/15, 9/8, 6/5, 3/2, 9/5, 13/5] * ~keyfrq * 8, inf),
));

/*
~forked.play(t, quant: 1);
~forked.stop;
*/

~formula =
Pdef(\borked,
	Ppar(
		[~forked, ~forked], inf
));

/*
~formula.play(t, quant: 1);
~formula.stop;
*/

~familyman =
Pdef(\vooom,
	Pbindf(
		~forked,
		\freq, Pshuf([9/10, 1/1, 16/15, 9/8, 6/5, 3/2, 9/5, 13/5] * ~keyfrq * 8 * (3/2), inf),
));

/*
~familyman.play(t, quant: 1);
~familyman.stop;
*/

~families =
Pdef(\goam,
Ppar(
		[~familyman, ~familyman], inf
));

/*
~families.play(t, quant: 1);
~families.stop;
*/

// pad2

~pad2pat =
Pdef(\pad2pat,
Pbind(
		\instrument, 	\pad2,
		\dur, 			Pshuf([7, 9, 11, 13, 15, 17, 19], inf),
		\freq, 			Pshuf([1/1, 3/2] * 256 * (9/8), inf),
		\peak, 			1,
		\width, 		Pwhite(0.2, 0.8, inf),
));

/*
~pad2pat.play(t, quant: 1);
~pad2pat.stop;
*/

~pad2chords =
Pdef(\pad2chords,
Ppar(
		[~pad2pat, ~pad2pat], inf
));

/*
~pad2chords.play(t, quant: 1);
~pad2chords.stop;
*/

// ox

~oxpastpat =
Pdef(\oxtestpat,
Pbind(
		\instrument, 	\ox,
		\dur, 			Pxrand([0.25, 0.5, 0.75, 1, 1.5, 2, 3], inf),
		\end, 			Pxrand([0.25, 0.5], inf),
		\freq, 			Pxrand([1/1, 3/2, 2/1, 3/1] * 256, inf),
		\peak, 			Pbrown(0.5, 1, 0.5, inf) / 1.5
));

/*
PdefAllGui.new;
*/

);

(
/////////////////////////////////////////////////////////////////////////////////
// 							MIDI KONTROL

// connect MIDI
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl = 1310720;
//~nanoktrl = 1400710921;
//~nanoktrl = 683998490;

// bass

~flub =
MIDIdef.cc(\flub, {
	if (~morse.isPlaying.not) {
		~morse.play(t, quant: 0.5);
		"bass play".postln;
	} {
		~morse.stop;
		"bass stop".postln;
	};
}, 32, srcID: ~nanoktrl);

// drone

~dronectl =
MIDIdef.cc(\dronectl, {
	if (~dronenode.isPlaying.not) {
		~dronenode = Synth(\drone).register;
		"drone play".postln;
	} {
		~dronenode.release;
		"drone stop".postln;
	};
}, 48, srcID: ~nanoktrl);

// pad

~padctrl =
MIDIdef.cc(\padctrl, {
	if (~padchords.isPlaying.not) {
		~padchords.play(t, quant: 1);
		"pad play".postln;
	} {
		~padchords.stop;
		"pad stop".postln;
	}
}, 64, srcID: ~nanoktrl);

// prc1a-c

~gassy1 =
MIDIdef.cc(\morp, {
	if (~gazelle.isPlaying.not) {
		~gazelle.play(t, quant: 0.5);
		"prc1 play".postln;
	} {
		~gazelle.stop;
		"prc1 stop".postln;
	};
}, 33, srcID: ~nanoktrl);

~gassy2 =
MIDIdef.cc(\morp2, {
	if (~gauze.isPlaying.not) {
		~gauze.play(t, quant: 0.5);
		"prc2 play".postln;
	} {
		~gauze.stop;
		"prc2 stop".postln;
	};
}, 49, srcID: ~nanoktrl);

~gassy3 =
MIDIdef.cc(\morp3, {
	if (~bandage.isPlaying.not) {
		~bandage.play(t, quant: 0.5);
		"prc3 play".postln;
	} {
		~bandage.stop;
		"prc3 stop".postln;
	};
}, 65, srcID: ~nanoktrl);

// squirp

~squirpplayer1 =
MIDIdef.cc(\squipplayer1, {
	if (~squirpy1.isPlaying.not) {
		~squirpy1.play(t, quant: 0.5);
		"squirpy1 play".postln;
	} {
		~squirpy1.stop;
		"squirpy1 stop".postln;
	}
}, 34, srcID: ~nanoktrl);

~squirpplayer2 =
MIDIdef.cc(\squipplayer2, {
	if (~squirpy2.isPlaying.not) {
		~squirpy2.play(t, quant: 0.5);
		"squirpy2 play".postln;
	} {
		~squirpy2.stop;
		"squirpy2 stop".postln;
	}
}, 50, srcID: ~nanoktrl);

// clicky 'hat'

~elastics =
MIDIdef.cc(\kaiser, {
	if (~godliness.isPlaying.not) {
		~godliness.play(t, quant: 0.5);
		"hat play".postln;
	} {
		~godliness.stop;
		"hat stop".postln;
	}
}, 35, srcID: ~nanoktrl);

// clicky 'hat' echo

~thumble =
MIDIdef.cc(\geyser, {
	if (~desert.isPlaying.not) {
		~desert.play(t, quant: 0.5);
		"hat echo play".postln;
	} {
		~desert.stop;
		"hat echo stop".postln;
	}
}, 51, srcID: ~nanoktrl);

// klikk2

~klikk2player =
MIDIdef.cc(\klikk2player, {
	if (~klikk2.isPlaying.not) {
		~klikk2.play(t, quant: 0.5);
		"klikk2 play".postln;
	} {
		~klikk2.stop;
		"klikk2 stop".postln;
	}
}, 67, srcID: ~nanoktrl);

// kik

~grassrooties =
MIDIdef.cc(\formals, {
	if (~bonk.isPlaying.not) {
		~bonk.play(t, quant: 0.5);
		"kik play".postln;
	} {
		~bonk.stop;
		"kik stop".postln;
	}
}, 36, srcID: ~nanoktrl);

// 'snr'

~corndogs =
MIDIdef.cc(\armedstruggle, {
	if (~guzzle.isPlaying.not) {
		~guzzle.play(t, quant: 0.5);
		"snr play".postln;
	} {
		~guzzle.stop;
		"snr stop".postln;
	}
}, 52, srcID: ~nanoktrl);

// pling

~boring =
MIDIdef.cc(\cookies, {
	if (~formula.isPlaying.not) {
		~formula.play(t, quant: 0.5);
		"pling1 play".postln;
	} {
		~formula.stop;
		"pling1 stop".postln;
	}
}, 37, srcID: ~nanoktrl);

~coring =
MIDIdef.cc(\morecookies, {
	if (~families.isPlaying.not) {
		~families.play(t, quant: 0.5);
		"pling2 play".postln;
	} {
		~families.stop;
		"pling2 stop".postln;
	}
}, 53, srcID: ~nanoktrl);

// ox

~oxpat =
MIDIdef.cc(\oxpat, {
	if (~oxpastpat.isPlaying.not) {
		~oxpastpat.play(t, quant: 0.5);
		"ox play".postln;
	} {
		~oxpastpat.stop;
		"ox stop".postln;
	}
}, 68, srcID: ~nanoktrl);

// pad2

~pad2pctl =
MIDIdef.cc(\pad2ctl, {
	if (~pad2chords.isPlaying.not) {
		~pad2chords.play(t, quant: 0.5);
		"pad2 play".postln;
	} {
		~pad2chords.stop;
		"pad2 stop".postln;
	}
}, 38, srcID: ~nanoktrl);

);