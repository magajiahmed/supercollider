b.free;
b = Buffer.read(s, "/run/media/phil/LMA Aug Sho/ISEA/stream01.wav");
b.plot;

c.free;
c = Buffer.read(s, "/run/media/phil/LMA Aug Sho/ISEA/traffic01.wav");
c.plot;

////////////////////////////////////////////////////////////////
// Straight-up soundfile player

(
SynthDef(\playBuf, {|bufnum = 0, loop = 1, mul = 1, out = 0, rate = 1|
    var scaledRate, player;
    scaledRate = BufRateScale.kr(bufnum);
    player = PlayBuf.ar(2, bufnum, scaledRate * rate, loop: loop, doneAction:2) * mul;
    Out.ar(out, player);
}).add;
)

/*
~pb = Synth(\playBuf, [\bufnum, b.bufnum]);
~pb.free;
*/

////////////////////////////////////////////////////////////////
// Using a sine wave to modulate an input signal (frequency modulation with environmental sound)

(
SynthDef(\watersinmod, { |bufnum = 0, fb = 0, freq = 440, gate = 1, index = 1, level = 0.1, rate = 1|
    var env             =   Env.asr(0.01, level, 0.05);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var mod             =   SinOscFB.ar(freq!2, fb, index, 1);
    //var mod             =   LFBrownNoise0.kr(freq, mul: 1, add: 1);
    var buf             =   PlayBuf.ar(2, bufnum, rate * mod, loop: 1) * envgen;
    Out.ar(0, buf);
}).add;
);

~wsm = Synth(\watersinmod, [\bufnum, b.bufnum, \fb, 5, \freq, 0.1, \level, 0.5]);

~wsm.set(\fb, 0);
~wsm.set(\freq, 64);
~wsm.set(\index, 20);
~wsm.set(\rate, 0.01);

~wsm.release;

////////////////////////////////////////////////////////////////
// Using Ringz to resonate an input signal

~ringbus = Bus.audio(s, 2);

(
SynthDef(\ringz, { |freq = 440, input = 0, out = 0|
    var in              =   In.ar(input, 2);
    var ringz           =   Ringz.ar(in, freq!2, 2, 0.04);
    Out.ar(out, in + ringz);
}).add;
);

~r1 = Synth(\ringz, [\freq, 256, \input, ~ringbus]).register;
~r2 = Synth(\ringz, [\freq, 256 * 1.5, \input, ~ringbus]).register;
~r3 = Synth(\ringz, [\freq, 256 * 1.75, \input, ~ringbus]).register;


/*
~r1.isPlaying;
~r2.isPlaying;
~r3.isPlaying;
~r1.free;
~r2.free;
~r3.free;
*/

~w1 = Synth(\playBuf, [\bufnum, b.bufnum, \mul, 0.3, \out, ~ringbus]);
~w1.free;

////////////////////////////////////////////////////////////////
// Use input signal to modulate a sine wave's frequency, but quantized and lagged to give a 'harmonic tune'

~htbus = Bus.audio(s, 2);

(
SynthDef(\harmonictune, { |fb = 0, freq = 440, gate = 1, input = 0, level = 0.1, out = 0|
    var env             =   Env.asr(0.1, level, 1);
    var envgen          =   EnvGen.kr(env, gate, doneAction: 2);
    var in              =   In.ar(input, 2);
    var lag             =   VarLag.ar(in, 0.01, -64, add: 1).clip(1, 64);
    var lfo             =   SinOsc.kr([0.1, 0.11], 0, 0.0005, 1);
    var sin1            =   SinOscFB.ar((freq!2 * (lag)).round(freq) * lfo, fb, envgen);
    var sin2            =   SinOscFB.ar((freq!2 * (lag)).round(freq), fb, envgen);
    Out.ar(out, sin1 + sin2);
}).add;
);

~ht = Synth(\harmonictune, [\fb, 0.4, \freq, 128, \input, ~htbus]).register;

/*
~ht.isPlaying;
~ht.release;
*/

~w2 = Synth(\playBuf, [\bufnum, b.bufnum, \loop, 1, \mul, 100, \out, ~htbus, \rate, 1]).register;

~w2.set(\mul, 150);
~w2.set(\rate, 1000.reciprocal);

/*
~w2.isPlaying;
~w2.free;
*/