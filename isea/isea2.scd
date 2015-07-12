~arrayOfBuffers = "/run/media/phil/LMA Aug Sho/ISEA/*".pathMatch.collect { |file| Buffer.read(s, file) };

(
SynthDef(\sfplay, { |attack = 0.01, bufnum, curve = 0, gate = 1, loop = 0, outbus = 0, rate = 1, release = 0.01, startPos = 0, vol = 0|
	var env			 	=	Env.asr(attack, vol, release, curve);
	var envgen			=	EnvGen.kr(env, gate, doneAction: 2);
	var playbuf			=	PlayBuf.ar(
		2, bufnum, BufRateScale.kr(bufnum) * rate, startPos: startPos, loop: loop, doneAction: 2
	) * envgen;
	Out.ar(outbus, playbuf);
}).add
);

x = Synth(\sfplay, [\bufnum, ~arrayOfBuffers.size.rand, \loop, 1, \vol, 0.1]).register;
y = Synth(\sfplay, [\bufnum, ~arrayOfBuffers.size.rand, \loop, 1, \vol, 0.1]).register;
z = Synth(\sfplay, [\bufnum, ~arrayOfBuffers.size.rand, \loop, 1, \vol, 0.1]).register;