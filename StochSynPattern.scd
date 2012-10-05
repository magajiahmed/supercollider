///////////////////////
t = TempoClock(96/60);
///////////////////////
~syn = SynthDef(\stochsynth, { |
	ampdist = 1, 
	durdist = 1, 
	adparam = 1, 
	ddparam = 1, 
	minfreq = 440, 
	maxfreq = 660, 
	ampscale = 0.5, 
	durscale = 0.5, 
	initCPs = 12, 
	knum, 
	mul = 0.5, 
	add = 0,
	dur = 1
	|

	var env = Env.perc(0.0001, dur, 0.25, -32);
	var env_gen = EnvGen.kr(env, doneAction: 2);
	var gd = Gendy1.ar(
		ampdist, 
		durdist, 
		adparam, 
		ddparam, 
		minfreq, 
		maxfreq, 
		ampscale,
		durscale,
		initCPs, 
		knum,
		env_gen,
		add
		);
	var pan = Pan2.ar(gd, 0.0);
	Out.ar([0, 1], pan);
}).add;




//////////////////////////


~synpat = Pbind(
	\instrument, \stochsynth,
	\minfreq, Pshuf([250, 500, 750], inf),
	\maxfreq, Pshuf([1000, 2000, 3000, 4000], inf),
	\dur, Prand([Pseq([0.25 /4 ], 4), Pseq([0.25 / 3], 3), Pseq([0.25 / 2], 2), 0.25, 0.25, 0.25, 0.5, 0.5, 0.75, 1.5], inf),
).play(clock: t, quant: 1);


~synpat.stop;


///////////////////////////








/////////////////////////////////////////////////
SynthDef('hat', { |outputchan = 0, rezfreq = 10000|
	Out.ar(outputchan, Resonz.ar(WhiteNoise.ar(0.5), rezfreq, XLine.kr(1, 0.001, 0.0025, doneAction: 2)))
}).add;
/////////////////////////////////////////////////
~hatpat = Pbind(
	\instrument, \hat,
	\dur, 1,
	\outputchan, [0, 1],
).play(clock: t, quant: 1);
//////////////////////////////////////////////////
~hatpat.stop;
//////////////////////////////////////////////////