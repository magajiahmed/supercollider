t = TempoClock(108/60);
/////////////////////////////////////////////////////////////
// Adapted from http://www.dewdrop-world.net/sc3/tutorials/index.php?id=5
SynthDef(\kicksynth1, { |basefreq = 50, envratio = 3, freqdecay = 0.05, ampdecay = 0.0625|
        var fenv = EnvGen.kr(Env([envratio, 1], [freqdecay], \exp), 1) * basefreq,
        aenv = EnvGen.kr(Env.perc(0.01, ampdecay), 1, -1, doneAction:2);
        Out.ar([0, 1], SinOsc.ar(fenv, 0.5pi, aenv/4));
}).store;
///////////////////////////////////////////////////////////////
~kick = List.new;

(
~kick.add(Pbind(
//	 \dur, Pshuf(#[0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12], inf), 
	\dur, Pseq(#[0.25, 16, 0.5, 8, 0.75, 6, 1, 4, 1.5, 3, 2], inf),
	 \instrument, \kicksynth1
).play(clock: t, quant: 1));
)

~killkick = ~kick.do({ |player| player.stop}, ~kick = List.new);
/////////////////////////////////////////////////////////////////
(
SynthDef('snare2', { |outputchan = 0, rezfreq = 1000, length = 0.125|
	Out.ar(outputchan,               // output channel assignment, 0 (left) by default
//	Resonz.ar(WhiteNoise.ar(0.3),   // white noise into resonant filter
    Resonz.ar(Crackle.ar(1.9),
	rezfreq,                         // filter's resonant freq
//    WhiteNoise.kr(0.5),
	XLine.kr(0.5, 0.0625,                // start, end value (amp)
	length,                          // length of sound
	doneAction: 2)))
}).store;
)
/////////////////////////////////////////////////////////////////
~snr = List.new;

(
~snr.add(Pbind(
	 \dur, Prand(#[0.25, 0.5, 0.75, 1, 1.5, 2, 3], inf), 
	 \outputchan, Pshuf(#[0, 1], inf),
	 \rezfreq, Pshuf(#[250, 2000, 4000, 6000, 16000], inf),
	 \length, Pshuf(#[0.0625, 0.125, 0.25], inf),
	 \instrument, \snare2
).play(clock: t, quant: 1));
)

~snr.do({ |player| player.stop}, ~snr = List.new); 
////////////////////////////////////////////////////////////////
(
SynthDef('hat', { |outputchan = 0, rezfreq = 10000|
	Out.ar(outputchan, Resonz.ar(WhiteNoise.ar(0.5), rezfreq, XLine.kr(1, 0.001, 0.0025, doneAction: 2)))
}).store;
)
///////////////////////////////////////////////////////////////
~hat = List.new;

(
~hat.add(Pbind(
	 \dur, Prand(#[0.5, 0.75], inf), 
	 \outputchan, Pshuf(#[0, 1], inf),
	 \rezfreq, Pshuf(#[400, 800, 8000, 10000, 12000, 14000], inf),
	 \instrument, \hat
).play(clock: t, quant: 1));
)

~hat.do({ |player| player.stop}, ~hat = List.new);
