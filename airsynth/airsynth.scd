(
(
// balloon air sound
SynthDef(\airsynth, { |out = 0, gate = 1, lowpass_cutoff = 6000, highpass = 10, amp = 0,
	ampLag = 0, ampCurve= 0, attack = 0, release = 0|
	var source, env, lfpulse, bandFilt, trig, freqRand, freqDemand, slewFreq, reverb, lowpassFilt;
	//amp = ~balloonAmp;
	env = Linen.kr(gate, attack, 1, release, 0) * VarLag.kr(amp, ampLag, ampCurve);
	source = WhiteNoise.ar(mul: amp, add: 0.0);
	//set trigger, to control demand bandpass freq
	trig = Dust.kr(density: 2, mul: 1.0, add: 0.0);
	//random bandpass freq
	freqRand = Drand([150, 350, 2000, 5500, 600, 1200, 3200], inf);
	//demand bandpass freq, on trig
	freqDemand = Demand.kr(trig, 0, freqRand);
	//slew bandpass freq
	slewFreq = Lag.kr(in: freqDemand, lagTime: 5, mul: 1.0, add: 0.0);
	//pass sig thru bandpass filter
	bandFilt = BBandPass.ar(in: source, freq: slewFreq, bw: 1, mul: 1.0);
	highpass = HPF.ar(in: bandFilt, freq: 50, mul: 1.0, add: 0.0);
	reverb = FreeVerb.ar(highpass, mix: 0.5, room: 1, damp: 0.5, mul: 1.0, add: 0.0);
	//Out.ar(out, bandFilt * env);
	Out.ar(out, bandFilt);
	//Out.ar(out, reverb);
}
).add;
);
/*
(
f = Pmono(\airsynth, \amp, 0.02, \attack, 2, \release, 4, \out, 6,);
f.play;
);
*/
)
