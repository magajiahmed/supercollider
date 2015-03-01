(

//////////////////////////////////////////////////////////////////////////////////////////////////////
// 								TODO

// Improve comments and documentation

//////////////////////////////////////////////////////////////////////////////////////////////////////
// 								STARTUP STUFF

// Buffers
~hatbuf		=	Buffer.alloc(s, 44100, 1);
~blipbuf	=	Buffer.alloc(s, 88200, 1);

// connect MIDI
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
//~nanoktrl2 = 1400710921;
//~nanoktrl2 = 683998490;
~nanoktrl2 = 1310720;

// tempo
t = TempoClock(88/60);

// This is the 'key' that the piece is in.
~keyfrq = 48;

// Graphical Monitoring
s.meter;

//////////////////////////////////////////////////////////////////////////////////////////////////////
//								RECORDING

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

//////////////////////////////////////////////////////////////////////////////////////////////////////
// 								SYNTHDEFS

// bass synth

~bass =
SynthDef(\synbass, { |bwr = 1, curve = -6, cutoff = 1000, dur = 1, envgendiv = 2, freq = 440, pan = 0, peak = 1|
	var env 	   	= 		Env.perc(0.003, dur, peak, 0, curve: curve); // envelope: specify and
	var envgen 		= 		EnvGen.kr(env, doneAction: 2);               //           generate
	var snosc1 		= 		SinOsc.ar(freq, 			0.05, envgen / envgendiv);
	var snosc2 		= 		SinOsc.ar(freq * 2.005, 	0.05, envgen / (envgendiv * 4));
	var snosc3 		= 		SinOsc.ar(freq * 4.01, 		0.05, envgen / (envgendiv * 16));
	var pan2		=		Pan2.ar(snosc1 + snosc2 + snosc3, pan);
	Out.ar(0, pan2);                                    // get it all out
}).add;


// dynamix (compressor)

~dynamix =
SynthDef(\dynamix, {
	var in	   		= 	In.ar(2, 2);                          // stereo input bus
	var compressor	=	Compander.ar(in, in, thresh: 0.125, clampTime: 0.001, slopeAbove: 1/128); // compressor
	Out.ar(0, compressor);
}).play;

// blip (clicky perc based on chaotic map)

~blip =
SynthDef(\blip, { |
	a = 0.5, b = 0.5, dur = 0.5, frq = 22050, ffrq = 1500,
	len = 0.025, outputchannel = 0, peak = 1, rq = 0.5|
	var env			=		Env.new(levels: [0, peak, 0], times: [0.003, len]);
	var envgen		=		EnvGen.kr(env, doneAction: 2);
	var cusp		=		CuspN.ar(frq, a: a, b: b, mul: envgen);
	var cutoff		=		(ffrq).clip(100, SampleRate.ir / 3);
	var filt		=		RHPF.ar(cusp, cutoff, rq);
	Out.ar(outputchannel, filt);
}).add;

// hat2 (clicky perc based on chaotic map)

~hat2 =
SynthDef(\hat2, { |
	a = 0.5, b = 0.5, dur = 0.5, combfrq = 1536, frq = 22050,
	outputchannel = 2, peak = 1, rq = 0.5
	|
	var env			=		Env.new(levels: [0, peak, 0], times: [0.003, 0.02]);
	var envgen		=		EnvGen.kr(env, doneAction: 2);
	var cusp		=		CuspN.ar(frq, a: a, b: b, mul: envgen);
	var cutoff		=		(frq / 3).clip(100, SampleRate.ir / 3);
	var filt		=		RHPF.ar(cusp, cutoff, rq);
	var bufcomb		=		BufCombL.ar(~hatbuf.bufnum, filt, delaytime: 1 / combfrq, mul: peak / 1.5);
	Out.ar(outputchannel, filt + bufcomb);
}).add;


// prc (based on chaotic noiz function modulating a sine wave)

~oscprc =
SynthDef(\oscprc, { |curve = -16, dur = 1, freq = 100, pan = 0, peak = 0.5, xaosinit = 1.99|
	var ampenv	 	=	 	Env.perc(0.003, dur, peak, curve: curve);      // envelope: specify and
	var ampenvgen 	=	 	EnvGen.kr(ampenv, doneAction: 2);          //           generate
	var crackl 		=	 	Crackle.kr(xaosinit, mul: 1, add: 1);      // crackle (chaotic noise)
	var osc 		=	 	SinOsc.ar(freq, mul: crackl * ampenvgen / 8); // crackle mod's sinosc amp
	var pan2		=		Pan2.ar(osc, pan);
	Out.ar(2, pan2);
}).add;


// glissy

~glissin =
SynthDef(\glissin, { |
						curve = -4, dur = 1, freq = 440, pan = 0, peak = 0.5,
						start1 = 1, endratio = 1
					|
	var expgliss1	=		XLine.kr(start1, endratio, dur, doneAction: 2);
	var envprc		=		Env.perc(0.01, dur, level: peak, curve: curve);
	var envgen		=		EnvGen.kr(envprc, doneAction: 2);
	var kbnmul		=		0.02;
	var bnk1		=		LFBrownNoise0.kr(mul: kbnmul, add: 1);
	var bnk2		=		LFBrownNoise0.kr(mul: kbnmul, add: 1);
	var bnk3		=		LFBrownNoise0.kr(mul: kbnmul, add: 1);
	var bnk4		=		LFBrownNoise0.kr(mul: kbnmul, add: 1);
	var bnk5		=		LFBrownNoise0.kr(mul: kbnmul, add: 1);
	var freqgap		=		10;
	var iphase		=		0.01;
	var sin1		=		SinOsc.ar(freq * 				expgliss1, 				iphase, mul: envgen);
	var sin2		=		SinOsc.ar((freq + freqgap) * 	expgliss1 * 	bnk1, 	iphase, mul: envgen/4);
	var sin3		=		SinOsc.ar((freq - freqgap) * 	expgliss1 * 	bnk1, 	iphase, mul: envgen/4);
	var bellratio1	=		19/11;
	var sin4		=		SinOsc.ar(freq * 				bellratio1, 			iphase, mul: envgen/8);
	var sin5		=		SinOsc.ar((freq + freqgap) * 	bellratio1 *	bnk2, 	iphase, mul: envgen/16);
	var sin6		=		SinOsc.ar((freq - freqgap) * 	bellratio1 *	bnk2, 	iphase, mul: envgen/16);
	var bellratio2	=		23/11;
	var sin7		=		SinOsc.ar(freq * 				bellratio2, 			iphase, mul: envgen/16);
	var sin8		=		SinOsc.ar((freq + freqgap) * 	bellratio2 * 	bnk3, 	iphase, mul: envgen/32);
	var sin9		=		SinOsc.ar((freq - freqgap) * 	bellratio2 * 	bnk3, 	iphase, mul: envgen/32);
	var bellratio3	=		29/11;
	var sin10		=		SinOsc.ar(freq * 				bellratio3, 			iphase, mul: envgen/32);
	var sin11		=		SinOsc.ar((freq + freqgap) * 	bellratio3 * 	bnk4, 	iphase, mul: envgen/64);
	var sin12		=		SinOsc.ar((freq - freqgap) * 	bellratio3 * 	bnk4, 	iphase, mul: envgen/64);
	var highsine	=		SinOsc.ar(freq * 16 * 							bnk5, 	iphase, mul: envgen/48);
	var sinmix		=		(sin1 + sin2 + sin3 + sin4 + sin5 + sin6 + sin7 +
							sin8 + sin9 + sin10 + sin11 + sin12 + highsine) / 3;
	var pan2		=		Pan2.ar(sinmix, pan);
	Out.ar(0, pan2);
}).add;

// pad

~pad =
SynthDef(\sinpad, { |amp = 0.125, dur = 1, gate = 1, envgendiv = 32, freq = 384, freqgap = 0.25, freqratios = #[1, 1.16667, 1.5, 1.75], gdamp = 0.003|
	var gd1			=		Gendy1.kr(minfreq: 0.1, maxfreq: 10, mul: gdamp, add: 1);
	var gd2			=		Gendy1.kr(minfreq: 0.1, maxfreq: 10, mul: gdamp, add: 1);
	var gd3			=		Gendy1.kr(minfreq: 0.1, maxfreq: 10, mul: gdamp, add: 1);
	var gd4			=		Gendy1.kr(minfreq: 0.1, maxfreq: 10, mul: gdamp, add: 1);
	var gd5			=		Gendy1.kr(minfreq: 0.1, maxfreq: 10, mul: gdamp, add: 1);
	var env			=		Env.asr(5, amp, 15);
	var envgen		=		EnvGen.kr(env, gate, doneAction: 2);
	var sin1		=		SinOsc.ar(freq * 					freqratios * 	gd1, mul: envgen / envgendiv);
	var sin2		= 		SinOsc.ar((freq + freqgap) *		freqratios * 	gd2, mul: envgen / envgendiv);
	var sin3		=		SinOsc.ar((freq - freqgap) * 		freqratios * 	gd3, mul: envgen / envgendiv);
	var sin4		=		SinOsc.ar((freq + (freqgap * 2)) * 	freqratios * 	gd4, mul: envgen / envgendiv);
	var sin5		=		SinOsc.ar((freq - (freqgap * 2)) * 	freqratios * 	gd5, mul: envgen / envgendiv);
	var sinmix1		=		sin1 + sin2 + sin3;
	var sinmix2		=		sin1 + sin4 + sin5;
	Out.ar([0, 1], [sinmix1, sinmix2]);
}).add;

/*
~padtest = Synth(\sinpad);
~padtest.release;
*/

~sineping =
SynthDef(\sineping, { |curve = -4, freq = 384, pan = 0, peak = 1|
	var env			=		Env.perc(0.002, level: peak, curve: curve);
	var envgen		=		EnvGen.kr(env, doneAction: 2);
	var sin			=		SinOsc.ar(freq, mul: envgen / 2);
	var pan2		=		Pan2.ar(sin, pan);
	Out.ar(0, pan2);
}).add;


// percussive resonant clicks

~impulse =
SynthDef(\impulse, { |freq = 1000, outchan = 0, peak = 1, rq = 0.5|
	var env			=		Env.perc;
	var envgen		=		EnvGen.kr(env, doneAction: 2);
	var impulse		=		Impulse.ar(0, mul: peak);
	var filt		=		RLPF.ar(impulse, freq, rq);
	Out.ar(outchan, filt);
}).add;

// ping

~pingsynth =
SynthDef(\pingsynth, { |curve = -4, dur = 1, freq = 440, peak = 0.5|
	var env			=		Env.perc(releaseTime: dur, level: peak/16, curve: curve);
	var envgen		=		EnvGen.kr(env, doneAction: 2);
	var bnkmul		=		0.002;
	var bnk1		=		LFBrownNoise0.kr(mul: bnkmul, add: 1);
	var bnk2		=		LFBrownNoise0.kr(mul: bnkmul, add: 1);
	var sin1		=		SinOsc.ar(freq, 								mul: envgen/2);
	var sin2		=		SinOsc.ar((freq + 1) * bnk1, 					mul: envgen/2);
	var sin3		=		SinOsc.ar(freq * 2.005, 						mul: envgen/4);
	var sin4		=		SinOsc.ar((freq + 1) * 2.005 * bnk2,		 	mul: envgen/4);
	var sinmix1		=		sin1 + sin3;
	var sinmix2		=		sin2 + sin4;
	var dist		=		Decimator.ar(sinmix1 + sinmix2, 11025, 1.5, envgen / 12);
	Out.ar([0, 1], [sinmix1, sinmix2] + dist);
}).add;

//////////////////////////////////////////////////////////////////////////////////////////////////////
//								PATTERNS

//////////////////////////////////////////////////////////////////////////////////////////////////////
// bass1

~synbasspat1 =
Pdef(\synbasspat1,
	Pbind(
		\instrument, 	\synbass,
		\dur, 		Pseq([
			1, 1, 1.5,
			1, 1, 1, 1.5,
			1, 1, 1, 1, 1.5
		], inf),
		\freq,		Pseq([Pseq([~keyfrq], 12), ~keyfrq * (7/8)], inf),
		\peak, 		Pwhite(0.85, 1, inf)  / 3
));

//

/*

~synpat2 =
Pdef(\testing,
	Pbind(
		\instrument, \synbass,
		\dur, Pseq([
			0.75, 0.75, 1,
			0.75, 0.75, 0.75, 1,
			0.75, 0.75, 0.75, 0.75, 1
		], inf),
		\freq, Pseq([Pseq([~keyfrq * 2 * (3/2)], 12), ~keyfrq * 2 * (7/6)], inf),
		\peak, Pwhite(0.85, 1, inf) / 16
));
*/

// bass2

/*
~synbasspat2 =
Pdef(\synbasspat2,
	Pbindf(~synbasspat1,
		\curve, 	-12,
		\dur, 		Pseq([
						0.75, 0.75, 1,
						0.75, 0.75, 0.75, 1,
						0.75, 0.75, 0.75, 0.75, 1
					], inf),
\freq, 		~keyfrq * (7/4),
		\peak, 		Pwhite(0.85, 1, inf) / 8
));
*/

//////////////////////////////////////////////////////////////////////////////////////////////////////
// blips

~blippat =
Pdef(\blippat,
	Pbind(
		\instrument, 	\blip,
		\a, 			Pshuf([
							0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1
						], inf),
		\b, 			Pshuf([
							0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1,
							1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9
						], inf),
		\dur, 			Pseq([
							Pseq([0.125], 16), Pseq([0.75], 4), 12
						], inf),
		\frq, 			Pshuf([1, 1, 2, 3, 5, 8] * 2000, inf),
		\len, 			0.01,
		\outputchannel, Pseq([2, 3, [2, 3]], inf),
		\peak, 			0.15,
		\rq, 			1
));

//////////////////////////////////////////////////////////////////////////////////////////////////////
// blip2

~blippat2 =
Pdef(\blippat2,
	Pbind(
		\instrument, 	\blip,
		\dur, 			Pseq([
							Pseq([1, 1.5], 5), Pseq([0.75], 5),
							Pseq([1, 1.5], 7), Pseq([0.75], 7),
							Pseq([1, 1.5], 9), Pseq([0.75], 9)
						], inf),
		\ffrq, 			3000,
		\outputchan, Pseq([2, 3], inf),
		\peak,			0.5,
		\rq, 			0.1
));

//////////////////////////////////////////////////////////////////////////////////////////////////////
// hat1

~hatpat1 =
Pdef(\hatpat1,
	Pbind(
		\instrument, \hat2,
		\a, 1,
		\b, 0.9,
		\combfrq, ~keyfrq * 32,
		\dur, Pseq([
			0.5, 0.5, 0.625, 0.125,
			0.5, 0.5, 0.5, 0.625, 0.125,
			0.5, 0.5, 0.5, 0.5, 0.625, 0.125
		], inf),
		\frq, Pwhite(13000, 15000, inf),
		\outputchannel, [2, 3],
		\peak, Pseq([
			0.75, 0.75, 1, 0.25,
			0.75, 0.75, 0.75, 1, 0.25,
			0.75, 0.75, 0.75, 0.75, 1, 0.25
		] / 4, inf),
		\rq, 0.75
));

// hat2

~hatpat2 =
Pdef(\hatpat2,
	Pbindf(
		~hatpat1,
		\dur, Pseq([
			0.5, 0.625, 0.125,
			0.5, 0.5, 0.625, 0.125,
			0.5, 0.5, 0.5, 0.625, 0.125
		], inf),
		\frq, Pwhite(11000, 13000, inf),
		\peak, Pseq([
			0.75, 1, 0.25,
			0.75, 0.75, 1, 0.25,
			0.75, 0.75, 0.75, 1, 0.25
		] / 4, inf)
));

//////////////////////////////////////////////////////////////////////////////////////////////////////
// snr

~snrpat =
Pdef(\snrpat,
	Pbind(
		\instrument, 	\blip,
		\a, 			1,
		\b, 			1.9,
		\dur, 			Pseq([1, 1.5, 2, 1.5, 3, 1.5], inf),
		\note, 			Pseq([Rest, 1], inf),
		\outputchannel, [2, 3],
		\peak, 			0.1,
));

//////////////////////////////////////////////////////////////////////////////////////////////////////
// singliss1

~singliss1 =
Pdef(\singliss1,
	Pbind(
		\instrument, 	\glissin,
		\curve,	 		-4,
		\dur, 			Pshuf([0.25, 0.5, 0.75, 12].mirror, inf),
		\freq, 			~keyfrq * 16,
		\pan, 			Pwhite(-0.5, 0.5, inf),
		\peak, 			Pwhite(0.75, 1, inf) / 4,
		\start1, 		Pseq([
							7/8, 1/1, 1/1,
							7/8, 1/1, 9/8, 1/1,
							7/8, 1/1, 9/8, 1/1, 1/1
						], inf),
		\endratio,		1/1,
));

// singliss2

~singliss2 =
Pdef(\singliss2,
	Pbindf(~singliss1,
		\start1, 		Pseq([
							7/6, 1/1, 1/1,
							7/6, 1/1, 9/8, 1/1,
                            7/6, 1/1, 9/8, 1/1, 1/1
						], inf),
));

// singliss3

~singliss3 =
Pdef(\singliss3,
	Pbindf(~singliss1,
		\start1, 		Pseq([
							7/8, 3/4, 3/4,
							7/8, 3/4, 9/8, 3/4,
							7/8, 3/4, 9/8, 3/4, 3/4
						], inf),
		\endratio,		3/4
));

//////////////////////////////////////////////////////////////////////////////////////////////////////
// prcpat1

~prcpat1 =
Pdef(\prcpat1,
	Pbind(
		\instrument, 	\oscprc,
		\curve, 		-4,
		\dur, 			Pshuf([
							0.25, 0.5, 0.75, 6
						].mirror, inf),
		\freq,	 		Pseq([
							1/1, 1/1, 7/6,
							1/1, 1/1, 1/1, 7/6,
							1/1, 1/1, 1/1, 1/1, 7/6
						] * ~keyfrq * 16, inf),
		\pan,	 		Pwhite(-0.5, 0.5, inf),
		\peak, 			Pwhite(0.75, 1, inf) / 4,
		\xaosinit,	 	Prand([1.2, 1.4, 1.6, 1.8, 1.99], inf),
));

// prcpat2

~prcpat2 =
Pdef(\prcpat2,
	Pbindf(
		~prcpat1,
		\freq, 		Pseq([
						3/2, 3/2, 7/6,
						3/2, 3/2, 3/2, 7/6,
						3/2, 3/2, 3/2, 3/2, 7/6
					] * ~keyfrq * 16, inf),
));

~prcpat3 =
Pdef(\prcpat3,
	Pbindf(
		~prcpat1,
		\freq, 		Pseq([
						7/8, 7/8, 9/8,
						7/8, 7/8, 7/8, 9/8,
						7/8, 7/8, 7/8, 7/8, 9/8
					] * ~keyfrq * 16, inf),
));

//////////////////////////////////////////////////////////////////////////////////////////////////////
// imp

~imppat =
Pdef(\imp,
	Pbind(
		\instrument, 	\impulse,
		\amp, 			Pwhite(0.5, 1, inf),
		\dur, 			Pseq([
							Pseq([1, 1.5], 7), Pseq([0.75], 7),
							Pseq([1, 1.5], 9), Pseq([0.75], 9),
							Pseq([1, 1.5], 11), Pseq([0.75], 11)
						], inf),
		\freq, 			Pseq([
								Pseq([6000], 6),  7000,
								Pseq([6000], 12), 9000,
								Pseq([6000], 18), 5250,
						], inf),
		\outchan, 		Pshuf([2, 3], inf),
		\peak, 			0.3,
		\rq, 			0.1,
));

//////////////////////////////////////////////////////////////////////////////////////////////////////
// ping

~ping =
Pdef(\ping,
	Pbind(
		\instrument, \pingsynth,
		\curve, -8,
		\dur, 24,
		\freq, ~keyfrq * [8, 16],
		\peak, 0.25
));

// sineping

~sinepingpat =
Pdef(\sinepingpat,
	Pbind(
		\instrument, 	\sineping,
		\curve, 		-8,
		\dur, 			0.5,
		\freq, 			[1/1, 7/6, 3/2, 7/4] * ~keyfrq * 8,
		\pan, 			Pseq([
								-1, 1, -1, 1, -1, 1, 1,
								-1, 1, -1, 1, -1, 1, -1, 1, 1,
								-1, 1, -1, 1, -1, 1, -1, 1, -1, 1, 1
						] / 2, inf),
		\peak, 			0.05
));

// Pretty GUI to monitor all Pdefs

/*
PdefAllGui.new;
*/

//////////////////////////////////////////////////////////////////////////////////////////////////////
//								MIDI CONTROL

//////////////////////////////////////////////////////////////////////////////////////////////////////
// bass1

~sb1mdef = MIDIdef.cc(\sb1mdef, {
	if(~synbasspat1.isPlaying.not) {
		~synbasspat1.play(t, quant: 0.5);
		"synbass1 play".postln;
	} {
		~synbasspat1.stop;
		"synbass1 stop".postln;
	};
}, ccNum: 32, srcID: ~nanoktrl2);

//

/*
~s2mdef = MIDIdef.cc(\s2mdef, {
	if(~synpat2.isPlaying.not) {
		~synpat2.play(t, quant: 0.5);
		"syn2 play".postln;
	} {
		~synpat2.stop;
		"syn2 stop".postln;
	};
}, ccNum: 48, srcID: ~nanoktrl2);
*/

// bass2

/*
~sb2mdef = MIDIdef.cc(\sb2mdef, {
	if(~synbasspat2.isPlaying.not) {
		~synbasspat2.play(t, quant: 0.5);
		"synbass2 play".postln;
	} {
		~synbasspat2.stop;
		"synbass2 stop".postln;
	};
}, ccNum: 48, srcID: ~nanoktrl2);
*/

//////////////////////////////////////////////////////////////////////////////////////////////////////
// blips

~blipmdef = MIDIdef.cc(\blipmdef, {
	if(~blippat.isPlaying.not) {
		~blippat.play(t, quant: 1);
		"blips play".postln;
	} {
		~blippat.stop;
		"blips stop".postln;
	};
}, ccNum: 33, srcID: ~nanoktrl2);

// blip2

~blip2mdef =
MIDIdef.cc(\blip2mdef, {
	if(~blippat2.isPlaying.not) {
		~blippat2.play(t, quant: 1);
		"blip2 play".postln;
	} {
		~blippat2.stop;
		"blip2".stop;
	}
}, 49, srcID: ~nanoktrl2);

//////////////////////////////////////////////////////////////////////////////////////////////////////
// hat1

~hat1mdef = MIDIdef.cc(\hat1mdef, {
	if(~hatpat1.isPlaying.not) {
		~hatpat1.play(t, quant: 1);
		"hat1 play".postln;
	} {
		~hatpat1.stop;
		"hat1 stop".postln;
	};
}, 34, srcID: ~nanoktrl2);

// hat2

~hat2mdef = MIDIdef.cc(\hat2mdef, {
	if(~hatpat2.isPlaying.not) {
		~hatpat2.play(t, quant: 1);
		"hat2 play".postln;
	} {
		~hatpat2.stop;
		"hat2 stop".postln;
	};
}, 50, srcID: ~nanoktrl2);

//////////////////////////////////////////////////////////////////////////////////////////////////////
// snr

~snrmdef = MIDIdef.cc(\snrmdef, {
	if(~snrpat.isPlaying.not) {
		~snrpat.play(t, quant: 1);
		"snr play".postln;
	} {
		~snrpat.stop;
		"snr stop".postln;
	};
}, 66, srcID: ~nanoktrl2);

//////////////////////////////////////////////////////////////////////////////////////////////////////
// singliss1

~singliss1mdef = MIDIdef.cc(\singliss1mdef, {
	if(~singliss1.isPlaying.not) {
		~singliss1.play(t, quant: 1);
		"singliss1 play".postln;
	} {
		~singliss1.stop;
		"singliss1 stop".postln;
	};
}, 35, srcID: ~nanoktrl2);

~singliss2mdef = MIDIdef.cc(\singliss2mdef, {
	if(~singliss2.isPlaying.not) {
		~singliss2.play(t, quant: 1);
		"singliss2 play".postln;
	} {
		~singliss2.stop;
		"singliss2 stop".postln;
	};
}, 51, srcID: ~nanoktrl2);

~singliss3mdef = MIDIdef.cc(\singliss3mdef, {
	if(~singliss3.isPlaying.not) {
		~singliss3.play(t, quant: 1);
		"singliss3 play".postln;
	} {
		~singliss3.stop;
		"singliss3 stop".postln;
	};
}, 67, srcID: ~nanoktrl2);

//////////////////////////////////////////////////////////////////////////////////////////////////////
// prcpats

~prcpat1mdef = MIDIdef.cc(\prcpat1mdef, {
	if(~prcpat1.isPlaying.not) {
		~prcpat1.play(t, quant: 1);
		"prcpat1 play".postln;
	} {
		~prcpat1.stop;
		"prcpat1 stop".postln;
	};
}, 36, srcID: ~nanoktrl2);

~prcpat2mdef = MIDIdef.cc(\prcpat2mdef, {
	if(~prcpat2.isPlaying.not) {
		~prcpat2.play(t, quant: 1);
		"prcpat2 play".postln;
	} {
		~prcpat2.stop;
		"prcpat2 stop".postln;
	};
}, 52, srcID: ~nanoktrl2);

~prcpat3mdef = MIDIdef.cc(\prcpat3mdef, {
	if(~prcpat3.isPlaying.not) {
		~prcpat3.play(t, quant: 1);
		"prcpat3 play".postln;
	} {
		~prcpat3.stop;
		"prcpat3 stop".postln;
	};
}, 68, srcID: ~nanoktrl2);

//////////////////////////////////////////////////////////////////////////////////////////////////////
// pad

~padmdef =
MIDIdef.cc(\padmdef, {
	if (~sinpad.isPlaying.not) {
		~sinpad = Synth(\sinpad).register;
		"pad play".postln;
	} {
		~sinpad.release;
		"pad stop".postln;
	}
}, 37, srcID: ~nanoktrl2);

//////////////////////////////////////////////////////////////////////////////////////////////////////
// imp

~impmdef = MIDIdef.cc(\impmdef, {
	if(~imppat.isPlaying.not) {
		~imppat.play(t, quant: 0.5);
		"imp play".postln;
	} {
		~imppat.stop;
		"imp stop".postln;

	};
}, 38, srcID: ~nanoktrl2);

//////////////////////////////////////////////////////////////////////////////////////////////////////
// ping

~pingmdef = MIDIdef.cc(\pingmdef, {
	if(~ping.isPlaying.not) {
		~ping.play(t, quant: 0.5);
		"ping play".postln;
	} {
		~ping.stop;
		"ping stop".postln;

	};
}, 64, srcID: ~nanoktrl2);

// sineping

~sinepingmdef = MIDIdef.cc(\sinepingmdef, {
	if(~sinepingpat.isPlaying.not) {
		~sinepingpat.play(t, quant: 0.5);
		"sineping play".postln;
	} {
		~sinepingpat.stop;
		"sineping stop".postln;

	};
}, 53, srcID: ~nanoktrl2);


)