//gransyn by Peter van Haaften & Martin Marier
// originally inspired by Supercollidr help instrument:
// Ex.1e: Buffer granulation Synth with per-grain effect processing (TGrains) @
// https://pustota.basislager.org/_/sc-help/Help/Tutorials/Buffer_Granulation.html
(
~maxOverlaps = 20;


SynthDef(\gransyn9_horn, { |out = 0, soundBuf, posLo = 0.1, posHi = 0.9, posRate= 1, posRateLag = 0, posRateCurve = 0, rate= 1, rateLag = 0, rateCurve = 0, amp = 1, overlap = 2, overlapLag = 0, overlapCurve = 0, trigRate = 1, trigRateLag = 0, trigRateCurve = 0, interp = 2, lpFreqMin = 20000, lpFreqMax = 20000, lpLag = 0, lpCurve = 0, hpFreqMin = 20, hpFreqMax = 20, hpLag = 0, hpCurve = 0, rateRandomness = 0, rateRandomnessLag = 0, rateRandomnessCurve = 0, overlapRandomness = 0, overlapRandomnessLag = 0, overlapRandomnessCurve = 0, verbMix = 0, verbMixLag = 0, verbMixCurve = 0, verbRoom = 0, verbDamp =0, freezeOsc = 0, freezeVal = 0, freezeDelay = 0, freezeAmp = 0, freezeAmpLag = 0, freezeAmpCurve = 0, cleanAmp = 0, binScrambleWipe = 0, binScrambleWidth = 0, binScrambleTrigger = 0, binScrambleAmp = 0, binScrambleAmpLag = 0, binScrambleAmpCurve = 0, cleanAmpLag = 0, cleanAmpCurve = 0, binShiftStretch = 1.0, binShiftStretchLag = 0, binShiftStretchCurve = 0|

	var sig, chain, fftOut, freezeSig, binScrambleSig, sigMix, sigOut, sigLimiter, sigCompressor, env, chan, trig, trigs, bufDur, pos, lpfSig, rateNoiseSig, overlapNoiseSig, verbSig, highpassSig, lowpassSig;

	//trigger for grains
	trigRate = VarLag.kr(trigRate, trigRateLag, trigRateCurve);
	// we need a multichannel trigger that steps through all consecutive channels
	trigs = Impulse.ar( ((trigRate / ~maxOverlaps) ! ~maxOverlaps), ((0..(~maxOverlaps-1)) / ~maxOverlaps));
	//randomness for rate
	rateNoiseSig = PinkNoise.kr(mul: VarLag.kr(rateRandomness, rateRandomnessLag, rateRandomnessCurve), add: 0);
	//randomness for overlap
	overlapNoiseSig = PinkNoise.kr(mul: VarLag.kr(overlapRandomness, overlapRandomnessLag, overlapRandomnessCurve), add: 0);

	//define all of your VarLag controlled values here
	lpFreqMin = VarLag.kr(lpFreqMin, lpLag, lpCurve);
	lpFreqMax = VarLag.kr(lpFreqMax, lpLag, lpCurve);
	hpFreqMin = VarLag.kr(hpFreqMin, hpLag, hpCurve);
	hpFreqMax = VarLag.kr(hpFreqMax, hpLag, hpCurve);
	rate = VarLag.kr(rate + rateNoiseSig, rateLag, rateCurve);
	overlap = VarLag.kr(overlap + overlapNoiseSig, overlapLag, overlapCurve);
	posRate = VarLag.kr(posRate, posRateLag, posRateCurve);
	verbMix = VarLag.kr(verbMix, verbMixLag, verbMixCurve);

    bufDur = BufDur.kr(soundBuf);
	pos = Phasor.ar(0, BufRateScale.kr(soundBuf) * posRate * SampleDur.ir / bufDur, posLo, posHi);
	sig = GrainBuf.ar(
		numChannels: 1,
		trigger: trigs, //trigs has ~maxOverlap channels, so sig expands to ~maxOverlap channels too.
		dur: overlap / trigRate,
		sndbuf: soundBuf,
		rate: rate,
		pos: pos,
		interp: interp,
		pan: 0,
		envbufnum: -1,
		maxGrains: 2, // grains overlap using multichannel expansion
		mul: 1.0
	);

	sig = LPF.ar(in: sig, freq: TExpRand.ar(lpFreqMin, lpFreqMax, trigs), mul: 1, add: 0);
	sig = HPF.ar(in: sig, freq: TExpRand.ar(hpFreqMin, hpFreqMax, trigs), mul: 1, add: 0);

    // routing to one channel
    sigMix = Mix(sig);

	//fft chain
	chain = FFT(LocalBuf(2048), sigMix);

	//freeze effect
	freezeSig = PV_Freeze(chain, freeze: DelayN.kr(in: freezeVal, maxdelaytime: 5, delaytime: freezeDelay));
	binShiftStretch = VarLag.kr(binShiftStretch, binShiftStretchLag, binShiftStretchCurve);
	freezeSig = PV_BinShift(freezeSig, stretch: binShiftStretch);

	//bin scramble
	binScrambleSig = PV_BinScramble(chain, wipe: binScrambleWipe, width: binScrambleWidth, trig: binScrambleTrigger);

	//freeze2sig
	freezeSig = IFFT((freezeSig)).dup;
	freezeAmp = VarLag.kr(freezeAmp, freezeAmpLag, freezeAmpCurve);
	//need to delay freezeSig input to same val as delay in PV_Freeze above
	freezeSig = DelayN.ar(in: freezeSig * freezeAmp, maxdelaytime: 5, delaytime: freezeDelay);

	//binScramble2sig
	binScrambleSig = IFFT((binScrambleSig)).dup;
	binScrambleAmp = VarLag.kr(binScrambleAmp, binScrambleAmpLag, binScrambleAmpCurve);
	binScrambleSig = binScrambleSig * binScrambleAmp;

	//fftOut mix global
	fftOut = (freezeSig + binScrambleSig) / 2;

	// clean amp
	cleanAmp = VarLag.kr(cleanAmp, cleanAmpLag, cleanAmpCurve);
	sigMix = sigMix * cleanAmp;

	//mix clean with fftchain
	sigMix = (sigMix + fftOut) / 2;


	/// compression
	sigCompressor = Compander.ar(sigMix, sigMix,
        thresh: 0.75,
        slopeBelow: 1,
        slopeAbove: 0.1,
        clampTime:  0.002,
        relaxTime:  0.1,
		mul: 1,
		add: 0,
    );

	sigLimiter = Limiter.ar(in: sigCompressor, level: 1, dur: 0.5);
	lowpassSig = LPF.ar(in: sigLimiter, freq: 6000, mul: 1.0, add: 0.0);
	highpassSig = HPF.ar(in: lowpassSig, freq: 500.0, mul: 1.0, add: 0.0);
	verbSig = FreeVerb.ar(highpassSig, mix: verbMix, room: verbRoom, damp: verbDamp);
	Out.ar(out, verbSig[0]);
}).store;
)


