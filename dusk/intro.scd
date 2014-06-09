//midi
MIDIdef.freeAll;
MIDIClient.init;
MIDIIn.connectAll;
c.free;
c = MIDIdef.cc(\ccpostln, { arg ...args; args.postln; });
//~nanoktrl2 = 1310720;
~nanoktrl2 = 1572864;

s.meter;

////////////////////////////////////////////////////////////////

/*
s.prepareForRecord;
s.record;
s.stopRecording;
*/

// load sound files

(
~cricketc0.free;
~cricketc1.free;
~cricketc2.free;
~cricketc3.free;
~cricketc4.free;
~cricketc5.free;
~insects0.free;
~insects1.free;
~insects2.free;
~insects3.free;
~insects4.free;
~nuthatch.free;
);

(
~cricketc0 = Buffer.read(s, "/media/sdb1/nature/C/FilteredCrickets01C.aif");
~cricketc1 = Buffer.read(s, "/media/sdb1/nature/C/FilteredCrickets01C-1oct.aif");
~cricketc2 = Buffer.read(s, "/media/sdb1/nature/C/FilteredCrickets01C-2oct.aif");
~cricketc3 = Buffer.read(s, "/media/sdb1/nature/C/FilteredCrickets01C-3oct.aif");
~cricketc4 = Buffer.read(s, "/media/sdb1/nature/C/FilteredCrickets01C-4oct.aif");
~cricketc5 = Buffer.read(s, "/media/sdb1/nature/C/FilteredCrickets01C-5oct.aif");
~insects0 = Buffer.read(s, "/media/sdb1/nature/insect_buzz_frogs_naturesounds-ca.aif");
~insects1 = Buffer.read(s, "/media/sdb1/nature/insect_buzz_frogs_naturesounds-ca-1oct.aif");
~insects2 = Buffer.read(s, "/media/sdb1/nature/insect_buzz_frogs_naturesounds-ca-2oct.aif");
~insects3 = Buffer.read(s, "/media/sdb1/nature/insect_buzz_frogs_naturesounds-ca-3oct.aif");
~insects4 = Buffer.read(s, "/media/sdb1/nature/insect_buzz_frogs_naturesounds-ca-4oct.aif");
~nuthatch = Buffer.read(s, "/media/sdb1/nature/nuthatch_chickadee_naturesounds-ca.aif");
);

// define sound file player
(
SynthDef(\sndfileplayer, { | bufnum, vol = 0 |
	var playbuf				=	PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), doneAction: 2) * vol;
	Out.ar([0, 2], playbuf);
}).add
);

// rez filter

(
SynthDef(\rezf, { | freq = 440, vol = 0 |
	var in					=	In.ar(2, 2);
	var mixfill				=	Mix.fill(16, {
		arg i;
		var rez 				=	Resonz.ar(in, freq * i.nthPrime, 0.005, vol / (i + 1).exp(4));
		var rez2				=	Resonz.ar(in, freq * i.nthPrime * 2, 0.005, vol / (16 * (i + 1).exp(4)));
		rez + rez2;
	});
	Out.ar(0, mixfill);
}).add
);


~rezfplay1 = Synth(\rezf, [\freq, 55]).register;
/*
~rezfplay1.isPlaying;
~rezfplay1.free;
*/

~rezfplay2 = Synth(\rezf, [\freq, 165]).register;
/*
~rezfplay2.isPlaying;
~rezfplay2.free;
*/


~rezfplay3 = Synth(\rezf, [\freq, 385]).register;
/*
~rezfplay3.isPlaying;
~rezfplay3.free;
*/

(
~rezf1volktrl =
MIDIdef.cc(\rezf1volktrl, { arg vol;
	if(~rezfplay1.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 750);
		~rezfplay1.set(\vol, vol);
		vol.postln;
	}
}, 5, srcID: ~nanoktrl2)
);

(
~rezf2volktrl =
MIDIdef.cc(\rezf2volktrl, { arg vol;
	if(~rezfplay2.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 150);
		~rezfplay2.set(\vol, vol);
		vol.postln;
	}
}, 6, srcID: ~nanoktrl2)
);

(
~rezf3volktrl =
MIDIdef.cc(\rezf3volktrl, { arg vol;
	if(~rezfplay3.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 30);
		~rezfplay3.set(\vol, vol);
		vol.postln;
	}
}, 7, srcID: ~nanoktrl2)
);


// CRICKETS CONVOLVED

/*
~cricketc0play = Synth(\sndfileplayer, [\bufnum, ~cricketc0.bufnum]).register;
~cricketc0play.isPlaying;
~cricketc0play.free;
*/

(
~cricketc0volktrl =
MIDIdef.cc(\cricketc0volktrl, { arg vol;
	if(~cricketc0play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~cricketc0play.set(\vol, vol);
		vol.postln;
	}
}, 16, srcID: ~nanoktrl2)
);

(
~cricketc0playktrl =
MIDIdef.cc(\cricketc0playktrl, {
	if(~cricketc0play.isPlaying.not) {
		~cricketc0play = Synth(\sndfileplayer, [\bufnum, ~cricketc0.bufnum]).register;
		"cricketc0 play".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~cricketc0stopktrl =
MIDIdef.cc(\cricketc0stopktrl, {
	if(~cricketc0play.isPlaying) {
		~cricketc0play.free;
		"cricketc0 stop".postln;
	}
}, 32, srcID: ~nanoktrl2, argTemplate: 0)
);


// CRICKETS CONVOLVED -1 OCT

/*
~cricketc1play = Synth(\sndfileplayer, [\bufnum, ~cricketc1.bufnum]).register;
~cricketc1play.isPlaying;
~cricketc1play.free;
*/

(
~cricketc1volktrl =
MIDIdef.cc(\cricketc1volktrl, { arg vol;
	if(~cricketc1play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~cricketc1play.set(\vol, vol);
		vol.postln;
	}
}, 17, srcID: ~nanoktrl2)
);

(
~cricketc1playktrl =
MIDIdef.cc(\cricketc1playktrl, {
	if(~cricketc1play.isPlaying.not) {
		~cricketc1play = Synth(\sndfileplayer, [\bufnum, ~cricketc1.bufnum]).register;
		"cricketc1 play".postln;
	}
}, 33, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~cricketc1stopktrl =
MIDIdef.cc(\cricketc1stopktrl, {
	if(~cricketc1play.isPlaying) {
		~cricketc1play.free;
		"cricketc1 stop".postln;
	}
}, 33, srcID: ~nanoktrl2, argTemplate: 0)
);

// CRICKETS CONVOLVED -2 OCT

/*
~cricketc2play = Synth(\sndfileplayer, [\bufnum, ~cricketc2.bufnum]).register;
~cricketc2play.isPlaying;
~cricketc2play.free;
*/

(
~cricketc2volktrl =
MIDIdef.cc(\cricketc2volktrl, { arg vol;
	if(~cricketc2play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~cricketc2play.set(\vol, vol);
		vol.postln;
	}
}, 18, srcID: ~nanoktrl2)
);

(
~cricketc2playktrl =
MIDIdef.cc(\cricketc2playktrl, {
	if(~cricketc2play.isPlaying.not) {
		~cricketc2play = Synth(\sndfileplayer, [\bufnum, ~cricketc2.bufnum]).register;
		"cricketc2 play".postln;
	}
}, 34, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~cricketc2stopktrl =
MIDIdef.cc(\cricketc2stopktrl, {
	if(~cricketc2play.isPlaying) {
		~cricketc2play.free;
		"cricketc2 stop".postln;
	}
}, 34, srcID: ~nanoktrl2, argTemplate: 0)
);

// CRICKETS CONVOLVED -3 OCT

/*
~cricketc3play = Synth(\sndfileplayer, [\bufnum, ~cricketc3.bufnum]).register;
~cricketc3play.isPlaying;
~cricketc3play.free;
*/

(
~cricketc3volktrl =
MIDIdef.cc(\cricketc3volktrl, { arg vol;
	if(~cricketc3play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~cricketc3play.set(\vol, vol);
		vol.postln;
	}
}, 19, srcID: ~nanoktrl2)
);

(
~cricketc3playktrl =
MIDIdef.cc(\cricketc3playktrl, {
	if(~cricketc3play.isPlaying.not) {
		~cricketc3play = Synth(\sndfileplayer, [\bufnum, ~cricketc3.bufnum]).register;
		"cricketc3 play".postln;
	}
}, 35, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~cricketc3stopktrl =
MIDIdef.cc(\cricketc3stopktrl, {
	if(~cricketc3play.isPlaying) {
		~cricketc3play.free;
		"cricketc3 stop".postln;
	}
}, 35, srcID: ~nanoktrl2, argTemplate: 0)
);

// CRICKETS CONVOLVED -4 OCT

/*
~cricketc4play = Synth(\sndfileplayer, [\bufnum, ~cricketc4.bufnum]).register;
~cricketc4play.isPlaying;
~cricketc4play.free;
*/

(
~cricketc4volktrl =
MIDIdef.cc(\cricketc4volktrl, { arg vol;
	if(~cricketc4play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~cricketc4play.set(\vol, vol);
		vol.postln;
	}
}, 20, srcID: ~nanoktrl2)
);


// CRICKETS CONVOLVED -5 OCT

/*
~cricketc5play = Synth(\sndfileplayer, [\bufnum, ~cricketc5.bufnum]).register;
~cricketc5play.isPlaying;
~cricketc5play.free;
*/

(
~cricketc5volktrl =
MIDIdef.cc(\cricketc5volktrl, { arg vol;
	if(~cricketc5play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~cricketc5play.set(\vol, vol);
		vol.postln;
	}
}, 20, srcID: ~nanoktrl2)
);

(
~cricketc5playktrl =
MIDIdef.cc(\cricketc5playktrl, {
	if(~cricketc5play.isPlaying.not) {
		~cricketc5play = Synth(\sndfileplayer, [\bufnum, ~cricketc5.bufnum]).register;
		"cricketc5 play".postln;
	}
}, 36, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~cricketc5stopktrl =
MIDIdef.cc(\cricketc5stopktrl, {
	if(~cricketc5play.isPlaying) {
		~cricketc5play.free;
		"cricketc5 stop".postln;
	}
}, 36, srcID: ~nanoktrl2, argTemplate: 0)
);

// insects

/*
~insects0play = Synth(\sndfileplayer, [\bufnum, ~insects0.bufnum]).register;
~insects0play.isPlaying;
~insects0play.free;
*/

(
~insects0volktrl =
MIDIdef.cc(\insects0volktrl, { arg vol;
	if(~insects0play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~insects0play.set(\vol, vol);
		vol.postln;
	}
}, 0, srcID: ~nanoktrl2)
);

(
~insects0playktrl =
MIDIdef.cc(\insects0playktrl, {
	if(~insects0play.isPlaying.not) {
		~insects0play = Synth(\sndfileplayer, [\bufnum, ~insects0.bufnum]).register;
		"insects0 play".postln;
	}
}, 48, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~insects0stopktrl =
MIDIdef.cc(\insects0stopktrl, {
	if(~insects0play.isPlaying) {
		~insects0play.free;
		"insects0 stop".postln;
	}
}, 48, srcID: ~nanoktrl2, argTemplate: 0)
);

// insects -1 oct

/*
~insects1play = Synth(\sndfileplayer, [\bufnum, ~insects1.bufnum]).register;
~insects1play.isPlaying;
~insects1play.free;
*/

(
~insects1volktrl =
MIDIdef.cc(\insects1volktrl, { arg vol;
	if(~insects1play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~insects1play.set(\vol, vol);
		vol.postln;
	}
}, 1, srcID: ~nanoktrl2)
);

(
~insects1playktrl =
MIDIdef.cc(\insects1playktrl, {
	if(~insects1play.isPlaying.not) {
		~insects1play = Synth(\sndfileplayer, [\bufnum, ~insects1.bufnum]).register;
		"insects1 play".postln;
	}
}, 49, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~insects1stopktrl =
MIDIdef.cc(\insects1stopktrl, {
	if(~insects1play.isPlaying) {
		~insects1play.free;
		"insects1 stop".postln;
	}
}, 49, srcID: ~nanoktrl2, argTemplate: 0)
);

// insects -2 oct

/*
~insects2play = Synth(\sndfileplayer, [\bufnum, ~insects2.bufnum]).register;
~insects2play.isPlaying;
~insects2play.free;
*/

(
~insects2volktrl =
MIDIdef.cc(\insects2volktrl, { arg vol;
	if(~insects2play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~insects2play.set(\vol, vol);
		vol.postln;
	}
}, 2, srcID: ~nanoktrl2)
);

(
~insects2playktrl =
MIDIdef.cc(\insects2playktrl, {
	if(~insects2play.isPlaying.not) {
		~insects2play = Synth(\sndfileplayer, [\bufnum, ~insects2.bufnum]).register;
		"insects2 play".postln;
	}
}, 50, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~insects2stopktrl =
MIDIdef.cc(\insects2stopktrl, {
	if(~insects2play.isPlaying) {
		~insects2play.free;
		"insects2 stop".postln;
	}
}, 50, srcID: ~nanoktrl2, argTemplate: 0)
);

// insects -3 oct

/*
~insects2play = Synth(\sndfileplayer, [\bufnum, ~insects2.bufnum]).register;
~insects2play.isPlaying;
~insects2play.free;
*/

(
~insects3volktrl =
MIDIdef.cc(\insects3volktrl, { arg vol;
	if(~insects3play.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~insects3play.set(\vol, vol);
		vol.postln;
	}
}, 3, srcID: ~nanoktrl2)
);

(
~insects3playktrl =
MIDIdef.cc(\insects3playktrl, {
	if(~insects3play.isPlaying.not) {
		~insects3play = Synth(\sndfileplayer, [\bufnum, ~insects3.bufnum]).register;
		"insects3 play".postln;
	}
}, 51, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~insects3stopktrl =
MIDIdef.cc(\insects3stopktrl, {
	if(~insects3play.isPlaying) {
		~insects3play.free;
		"insects3 stop".postln;
	}
}, 51, srcID: ~nanoktrl2, argTemplate: 0)
);

// nuthatches, chickadees, etc.

/*
~nuthatchplay = Synth(\sndfileplayer, [\bufnum, ~nuthatch.bufnum]).register;
~nuthatchplay.isPlaying;
~nuthatchplay.free;
*/

(
~nuthatchvolktrl =
MIDIdef.cc(\nuthatchvolktrl, { arg vol;
	if(~nuthatchplay.isPlaying) {
		vol = vol.linexp(0, 127, 0.0001, 1);
		~nuthatchplay.set(\vol, vol);
		vol.postln;
	}
}, 21, srcID: ~nanoktrl2)
);

(
~nuthatchplayktrl =
MIDIdef.cc(\nuthatchplayktrl, {
	if(~nuthatchplay.isPlaying.not) {
		~nuthatchplay = Synth(\sndfileplayer, [\bufnum, ~nuthatch.bufnum]).register;
		"nuthatch play".postln;
	}
}, 37, srcID: ~nanoktrl2, argTemplate: { arg x; x > 0 });

~nuthatchstopktrl =
MIDIdef.cc(\nuthatchstopktrl, {
	if(~nuthatchplay.isPlaying) {
		~nuthatchplay.free;
		"nuthatch stop".postln;
	}
}, 37, srcID: ~nanoktrl2, argTemplate: 0)
);