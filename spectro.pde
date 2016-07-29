import ddf.minim.*;
import ddf.minim.analysis.*; // FFT

Minim minim;
AudioSource source;
FFT fft;
int radius = 300; // e.g. 30 feet
int fft_spec_size; // hax
int hn = 35;
int bands_per_val;
float[] spectro;
int spectro_i;
float spectro_fade = 0.9;

void setupSpectro() {
  minim = new Minim(this);
  // this works on my Linux Thinkpad but not on my MacBook Pro 2011
  // still debugging
  source = minim.getLineIn(2, 1024);
  fft = new FFT(source.bufferSize(), source.sampleRate());
  fft_spec_size = fft.specSize() / 7; // hax
  spectro = new float[radius];
  bands_per_val = max(fft_spec_size / hn, 1);
  spectro_i = 0;
  println("*** sampleRate: "+source.sampleRate());
}

void tickSpectro() {
  // compute fft on source line
  fft.forward(source.mix);
  // save freq data for bottom-most band only (the "bassy" part)
  int iy = 0;
  int excl_bound = min(bands_per_val, fft_spec_size);
  float band_sum = 0;
  for (int i = 0; i < excl_bound; ++i)
    band_sum += fft.getBand(i);
  spectro[spectro_i] = band_sum / bands_per_val;
  spectro_i = (spectro_i + 1) % spectro.length;
}

float getSpectroAtDistance(int dist)
{
  if (dist > spectro.length) return 0; 
  int index = spectro_i-1;
  if (dist <= index)
    index = index-dist;
  else
    index = spectro.length-(dist-index); 
  float value = spectro[index];
  return value * pow(spectro_fade, dist/10);
  //return value;
}

void stopSpectro() {
  source.close();
  minim.stop();
}