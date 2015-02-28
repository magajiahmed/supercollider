////////////////////////////////////////////////////////////////
// INIT

//midi
(
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
~nanoktrl2 = 1310720;
);

// var
s.meter;
t = TempoClock(120/60);

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

////////////////////////////////////////////////////////////////
// INSTRUMENTS

(
~stansin =
SynthDef(\stansin, { | curve = -8, dur = 1, freq = 400, k = 1.4, level = 0.1 |
	var env				=	Env.perc(releaseTime: dur, level: level, curve: curve);
	var envgen			=	EnvGen.kr(env, doneAction: 2);
	//var stan			=	Standard2DC.ar(mul: 0.03, add: 1);
	var stan 			= 	1;
	var sinmix			=	Mix.fill(2, { arg i ; SinOsc.ar(([freq + (i), freq + 0.05 + (i)] * stan * (i + 1)).clip(50, SampleRate.ir / 8), mul: envgen / (i + 1)) });
	//var stan2			=	Standard2DC.ar(k: k, mul: envgen / 12).clip(-0.25, 0.25);
	//var rhpf			=	RHPF.ar(stan2, 8000, 0.1);
	Out.ar(0, sinmix);
}).add
);

/*
~stansyn = Synth(\stansin);
*/

////////////////////////////////////////////////////////////////
// PATTERNS

(
~tuning = Tuning.new([1/1, 9/8, 7/6, 4/3, 3/2, 7/4, 2/1].ratiomidi);
~scale = Scale.new(#[0, 1, 2, 3, 4, 5, 6], 7, ~tuning);
~keynote = 300;
~root1 = (~keynote/60.midicps).ratiomidi;
~root1a = ((~keynote*1.5)/60.midicps).ratiomidi;
~root1b = ((~keynote*2)/60.midicps).ratiomidi;
~root2 = ((~keynote/2)/60.midicps).ratiomidi;
~root3 = ((~keynote/4)/60.midicps).ratiomidi;
);

~pstan = Pstandard.new.asStream;

(
~degrees = (-1..6);
~degree = Prout({
	var x;
	loop({
		x = (~pstan.next[0] * ~degrees.size);
		x.yield;
	})
});

~durations = [0.25, 0.5, 0.75];
~dur = Prout({
	var x;
	loop({
		x = (~pstan.next[1] * ~durations.size);
		x.yield;
	})
});

~pattern1 =
Pdef(\pattern1,
	Pbind(
		\degree, Pswitch1(~degrees, ~degree),
		\dur, Pswitch1(~durations, ~dur),
		//\instrument, \stansin,
		\legato, 0.1,
		\level, Pwhite(0.75, 1, inf) * 0.1,
		\root, ~root1,
		\scale, ~scale,
));
);

/*
~pattern1.play(t, quant: 1);
~pattern1.isPlaying;
~pattern1.stop;
*/

//

~pattern1a = Pdef(\pattern1a, Pbindf(~pattern1, \root, ~root1a));

/*
~pattern1a.play(t, quant: 1);
~pattern1a.isPlaying;
~pattern1a.stop;
*/

//

~pattern1b = Pdef(\pattern1b, Pbindf(~pattern1, \root, ~root1b));

/*
~pattern1b.play(t, quant: 1);
~pattern1b.isPlaying;
~pattern1b.stop;
*/

//

(
~degrees2 = [[-1, 2], [0, 4], [0, 4, 5]];
~degree2 = Prout({
	var x;
	loop({
		x = (~pstan.next[0] * ~degrees2.size);
		x.yield;
	})
});

~durations2 = [0.5, 0.75];
~dur2 = Prout({
	var x;
	loop({
		x = (~pstan.next[1] * ~durations2.size);
		x.yield;
	})
});

~pattern2 =
Pdef(\pattern2,
	Pbind(
		\dur, Pswitch1(~durations2, ~dur2),
		\degree, Pswitch1(~degrees2, ~degree2),
		//\instrument, \stansin,
		\root, ~root2,
		\scale, ~scale
))
);

~pattern2.play(t, quant: 1);
~pattern2.isPlaying;
~pattern2.stop;

//

(
~degrees2a = (0..6);
~degree2a = Prout({
	var x;
	loop({
		x = (~pstan.next[0] * ~degrees2a.size);
		x.yield;
	})
});

~pattern2a =
Pdef(\pattern2a,
	Pbind(
		\dur, 0.25,
		\degree, Pswitch1(~degrees2a, ~degree2a),
		//\instrument, \stansin,
		\legato, 1,
		\root, ~root2,
		\scale, ~scale
))
);

~pattern2a.play(t, quant: 1);
~pattern2a.isPlaying;
~pattern2a.stop;


//

(
~degrees3 = (-1..6);
~degree3 = Prout({
	var x;
	loop({
		x = (~pstan.next[0] * ~degrees3.size);
		x.yield;
	})
});

~durations3 = [0.5, 5, 7, 9, 11, 13];
~dur3 = Prout({
	var x;
	loop({
		x = (~pstan.next[1] * ~durations3.size);
		x.yield;
	})
});

~pattern3 =
Pdef(\pattern3,
	Pbind(
		\dur, Pswitch1(~durations3, ~dur3),
		\degree, Pswitch1(~degrees3, ~degree3),
		//\instrument, \stansin,
		\k, Pshuf(Array.fill(3, { arg i; 1 + ((i + 1) / 10) }), inf),
		\root, ~root3,
		\scale, ~scale
))
);

~pattern3.play(t, quant: 1);
~pattern3.isPlaying;
~pattern3.stop;

////////////////////////////////////////////////////////////////
// MIDI KONTROL

(
~pat1ktrl = MIDIdef.cc(\pat1ktrl, {
	if(~pattern1.isPlaying.not) {
		~pattern1.play(t, quant: 1);
		"pat1 play".postln;
	} {
		~pattern1.stop;
		"pat1 stop".postln;
	};
}, 32, srcID: ~nanoktrl2)
);

(
~pat1aktrl = MIDIdef.cc(\pat1aktrl, {
	if(~pattern1a.isPlaying.not) {
		~pattern1a.play(t, quant: 1);
		"pat1a play".postln;
	} {
		~pattern1a.stop;
		"pat1a stop".postln;
	};
}, 48, srcID: ~nanoktrl2)
);

(
~pat1bktrl = MIDIdef.cc(\pat1bktrl, {
	if(~pattern1b.isPlaying.not) {
		~pattern1b.play(t, quant: 1);
		"pat1b play".postln;
	} {
		~pattern1b.stop;
		"pat1b stop".postln;
	};
}, 64, srcID: ~nanoktrl2)
);

(
~pat2ktrl = MIDIdef.cc(\pat2ktrl, {
	if(~pattern2.isPlaying.not) {
		~pattern2.play(t, quant: 1);
		"pat2 play".postln;
	} {
		~pattern2.stop;
		"pat2 stop".postln;
	};
}, 33, srcID: ~nanoktrl2)
);

(
~pat2aktrl = MIDIdef.cc(\pat2aktrl, {
	if(~pattern2a.isPlaying.not) {
		~pattern2a.play(t, quant: 1);
		"pat2a play".postln;
	} {
		~pattern2a.stop;
		"pat2a stop".postln;
	};
}, 49, srcID: ~nanoktrl2)
);


(
~pat3ktrl = MIDIdef.cc(\pat3ktrl, {
	if(~pattern3.isPlaying.not) {
		~pattern3.play(t, quant: 1);
		"pat3 play".postln;
	} {
		~pattern3.stop;
		"pat3 stop".postln;
	};
}, 34, srcID: ~nanoktrl2)
);