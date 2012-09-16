s.boot;
t = TempoClock(96/60);

(
 SynthDef.new("sinsyn", {arg out = 0, freq, amp = 0.2, dur = 1, gate = 1;
  var sin, env;
  
  env = EnvGen.kr(Env.adsr(0.001, 0.25, dur, 1, amp), gate, doneAction: 2);
  sin = SinOsc.ar(freq, mul: env);
  Out.ar(out, sin);
 }).store;
)

////////////////////////////////////////////////
~layers = List.new;

(
~layers.add(Pbind(
	 \midinote, Pshuf(#[60, 61, 65, 67], inf),
	 \dur, Pshuf(#[0.25, 0.5, 0.75, 3, 6], inf),
	 \instrument, \sinsyn
).play(clock: t, quant: 1));
)

~layers.do({ |player| player.stop}, ~layers = List.new);

////////////////////////////////////////////
(
~bass = (Pbind(
	 \midinote, Pshuf(#[46, 48, 51, 52], inf),
	 \dur, Pshuf(#[0.25, 0.5, 0.75, 1, 1.5], inf), 
	 \instrument, \example3
).play(clock: t, quant: 1));
)

~bass.stop;

//////////////////////////////////////////////

~hilayers = List.new;

(
~hilayers.add(Pbind(
	 \midinote, Pshuf(#[72, 73, 77, 79], inf),
	 \dur, Pshuf(#[0.25, 0.25, 0.5, 0.75, 1], inf), 
	 \instrument, \example3
).play(clock: t, quant: 1));
)

~hilayers.do({ |player| player.stop}, ~hilayers = List.new);

///////////////////////////////////////////////

~higherlayers = List.new;

(
~higherlayers.add(Pbind(
	 \midinote, Pshuf(#[79, 80, 84, 87], inf),
	 \dur, Pshuf(#[0.25, 0.5, 0.75], inf),
	 \instrument, \example3
).play(clock: t, quant: 1));
)

~higherlayers.do({ |player| player.stop}, ~higherlayers = List.new);