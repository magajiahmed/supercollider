~scale = Scale.chromatic;

(
SynthDef(\pew, { | curve = -2, dur = 1, freq = 400, level = 0.1, xaos = 1.2 |
	var env			=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen		=	EnvGen.kr(env, doneAction: 2);
	var crackle		=	Crackle.ar(xaos.dup).range(0, 0.999);
	var sinfb		=	SinOscFB.ar(freq, crackle, envgen);
	Out.ar(0, sinfb);
}).add;
);

(
~pdef1 =
Pdef(\pdef1,
	Pbind(
		\instrument, \pew,
		\dur, Prand([0.5, 0.75, 1], inf),
		\legato, 1,
		\scale, ~scale
));
);

/*
~pdef1.play;
~pdef1.pause;
*/

~pdef2 = Pdef(\pdef2, Pbindf(~pdef, \dur, 0.25, \level, 0.05));

/*
~pdef2.play;
*/