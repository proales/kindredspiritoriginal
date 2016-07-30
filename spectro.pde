import ddf.minim.*;
import ddf.minim.analysis.*; // FFT

Minim minim;
AudioInput source;

FFT fft;
int radius = 300; // e.g. 30 feet
float[] spectro;
int spectro_i;
float spectro_fade = 0.9;

void setupSpectro() {
  minim = new Minim(this);
  source = minim.getLineIn(Minim.STEREO, 1024); //2, 1024, 44100, 16);
  fft = new FFT(source.bufferSize(), source.sampleRate());
  spectro = new float[radius];
  spectro_i = 0;
  println("*** spectro: bufferSize: "+source.bufferSize()+", sampleRate: "
           +source.sampleRate());
}

void tickSpectro() {
  fft.forward(source.mix);
  int hz = 60; // the body rattling untz untz untz is around 60hz
  // this all flies apart if we can't meet the globalFrameRate...
  int shz = min(hz / globalFrameRate, 2);
  int band_sum = 0;
  for (int i = 0; i < shz; i++)
    band_sum += fft.getBand(i);
  spectro[spectro_i] = band_sum * 20;  // hax
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