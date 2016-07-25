int makeRGB(int r, int g, int b) {
  return (r << 16) | (g << 8) | b;
}

int shade(int c, float shadeFactor) {
  int r = (c >> 16) & 0xFF;
  int g = (c >> 8) & 0xFF;
  int b = c & 0xFF;
  int rr = int(r * (1.0 - shadeFactor));
  int gg = int(g * (1.0 - shadeFactor));
  int bb = int(b * (1.0 - shadeFactor));
  return makeRGB(rr, gg, bb);
}

class Animation {
  String name;
  int speedPct;
  int logicalClock;
  int lastFrameCount;
  public Integer primaryColor;
  public Integer secondaryColor;
  VirtualPixel pixels[];
  Animation() {
    // each animation gets a deep copy of the KS pixel model
   this.pixels =  new VirtualPixel[ksVirtualPixels.length];
   this.speedPct = 50;
   for (int i = 0; i < ksVirtualPixels.length; i++) {
     VirtualPixel src = ksVirtualPixels[i];
     pixels[i] = new VirtualPixel(src.controllerId, src.stripId, src.pixelId,
                                  src.coord.x, src.coord.y, src.coord.z);
   }
  }
  void resetClock() {
    logicalClock = 0;
    lastFrameCount = frameCount;
  }
  void tick() {
    int frameDelta = frameCount-lastFrameCount;
    float framesPerTick = (float(globalFrameRate)/2.0) - (float(globalFrameRate) * (float(speedPct)/100.0));
    if (frameDelta < framesPerTick) return;
    lastFrameCount = frameCount;
    logicalClock++;
  }
  int getPixelColor(int controller, int strip, int index) {
    int i = controllerStripMap[controller][strip][index];
    return pixels[i].currentColor;
  }
}

class OffAnimation extends Animation {
  OffAnimation() {
    name = "off";
    speedPct = 50;
  }
}

// show the KS brand colors
class BrandAnimation extends Animation {

  BrandAnimation() {
    name = "brand";
    primaryColor = 0x009900;
    secondaryColor = 0x8B008B;
  }
  void tick() {
    super.tick();
    for (VirtualPixel vp : pixels) {
      // make this a diagonal
      if (vp.coord.x < divider(int(vp.coord.y))) {
        vp.currentColor = primaryColor;
      } else {
        vp.currentColor = secondaryColor;
      }
    }
  }
  int divider(int y) {
    return -y + 275;
  }
}

class ThumperAnimation extends Animation {
  final int thumperPurple = 0x660E6F;
  ThumperAnimation() {
    name = "thumper";
    speedPct = 50;
  }
  void tick() {
    super.tick();
    // rain effect
    int numBuckets = pixelsPerStrip;
    float yRange = maxY - minY;
    int activeBucket = logicalClock % numBuckets;
    float bucketHeight = yRange / float(numBuckets);
    float yActiveStart = minY + (activeBucket*bucketHeight);
    float yActiveEnd = yActiveStart + bucketHeight;
    for (VirtualPixel vp : pixels) {
      if (vp.coord.y >= yActiveStart && vp.coord.y < yActiveEnd) {
        vp.currentColor = thumperPurple;
      } else {
        vp.currentColor = 0x000000;
      }
    }
  }
}

class SolidAnimation extends Animation {
  SolidAnimation() {
    name = "solid";
    primaryColor = 0x009900;
  }
  void tick() {
    super.tick();
    for (VirtualPixel vp : pixels) {
      vp.currentColor = primaryColor;
    }
  }
}

class SolidGlowAnimation extends Animation {
  SolidGlowAnimation() {
    name = "solidglow";
    primaryColor = 0x009900;
  }
  void tick() {
    super.tick();
    int phase = logicalClock % 200;
    if (phase > 100) { phase = 100 - (phase-100); }
    int c = shade(primaryColor, 1.0 - (float(phase) / 100.0));
    for (VirtualPixel vp : pixels) {
      vp.currentColor = c;
    }
  }
}

class ScanAnimation extends Animation {
  ScanAnimation() {
    name = "scan";
    primaryColor = 0x009900;
    secondaryColor = 0x000000;
  }
  void tick() {
    super.tick();
    int numBuckets = 100;
    float xRange = maxX - minX;
    int activeBucket = logicalClock % numBuckets;
    float bucketHeight = xRange / float(numBuckets);
    float xActiveStart = minX + (activeBucket*bucketHeight);
    float xActiveEnd = xActiveStart + bucketHeight;
    for (VirtualPixel vp : pixels) {
      if (vp.coord.x >= xActiveStart && vp.coord.x < xActiveEnd) {
        vp.currentColor = primaryColor;
      } else {
        vp.currentColor = secondaryColor;
      }
    }
  }
}

class NoiseAnimation extends Animation {
  NoiseAnimation() {
    name = "noise";
    primaryColor = 0x009900;
    speedPct = 10;
  }
  void tick() {
    super.tick();
    for (VirtualPixel vp : pixels) {
      if (random(100) < speedPct) {
        vp.currentColor = primaryColor;
      } else {
        vp.currentColor = 0;
      }
    }
  }
}

class RandomNoiseAnimation extends Animation {
  RandomNoiseAnimation() {
    name = "randomnoise";
    primaryColor = null;
    speedPct = 10;
  }
  void tick() {
    super.tick();
    for (VirtualPixel vp : pixels) {
      if (random(100) < speedPct) {
        vp.currentColor = makeRGB(int(random(255)), int(random(255)), int(random(255)));
      } else {
        vp.currentColor = 0;
      }
    }
  }
}

float dist(VirtualPixel vp, float x, float y, float z) {
  return sqrt(pow(x-vp.coord.x, 2) + pow(y-vp.coord.y, 2) + pow(z-vp.coord.z, 2));
}

class RadiateDJAnimation extends Animation {
  RadiateDJAnimation() {
    name = "radiate-dj";
    primaryColor = 0x990000;
    secondaryColor = 0x0;
    speedPct=75;
  }
  int djX = 210;
  int djY = 30;
  int djZ = 30;
  void tick() {
    super.tick();
    int i = logicalClock % 200;
    for (VirtualPixel vp : pixels) {
      float d = dist(vp, djX, djY, djZ);
      if (d >= i && d < i+40) {
        vp.currentColor = primaryColor;
      } else if (d >= (i+40) && d < (i+80)) {
        vp.currentColor = secondaryColor;
      } else {
        vp.currentColor = 0x0;
      }
    }
  }
}

class RadiateRandAnimation extends Animation {
  RadiateRandAnimation() {
    name = "radiate-rnd";
    primaryColor = 0x990000;
    secondaryColor = 0x0;
    speedPct = 75;
    randomSpot();
  }
  int djX, djY, djZ;
  void randomSpot() {
    djX = (int)random(minX, maxX);
    djY = (int)random(minY, maxY);
    djZ = (int)random(-40, 40);
  }
  void tick() {
    super.tick();
    if (logicalClock % 180 == 0) {
      randomSpot();
    }
    int i = logicalClock % 200;
    for (VirtualPixel vp : pixels) {
      float d = dist(vp, djX, djY, djZ);
      if (d >= i && d < i+40) {
        vp.currentColor = primaryColor;
      } else if (d >= (i+40) && d < (i+80)) {
        vp.currentColor = secondaryColor;
      } else {
        vp.currentColor = 0x0;
      }
    }
  }
}

class RadiateSubwoofers extends Animation {
  RadiateSubwoofers() {
    name = "radiate-bass";
    speedPct = 75;
    // TODO: actually use the speed setting, right now it radiates very slowly
    //   (default speed is about ~60 pixels/second, the frame rate)
  }
  int subX = 210;
  int subY = 110;
  int subZ = 30;
  void tick() {
    super.tick();
    for (VirtualPixel vp : pixels) {
      int d = int(dist(vp, subX, subY, subZ));
      int g = int(getSpectroAtDistance(d) * 1.5);
      vp.currentColor = makeRGB(0,g,0);
    }
  }
}

String animations[] = {
  "off",
  "solid",
  "solidglow",
  "brand",
  "scan",
  "noise",
  "randomnoise",
  "thumper",
  "radiate-dj",
  "radiate-rnd",
  "radiate-bass",
};

Animation createAnimation(int i) {
  switch (animations[i]) {
  case "off"    : return new OffAnimation();
  case "solid"  : return new SolidAnimation();
  case "solidglow" : return new SolidGlowAnimation();
  case "brand" : return new BrandAnimation();
  case "scan"   : return new ScanAnimation();
  case "noise"  : return new NoiseAnimation();
  case "randomnoise"  : return new RandomNoiseAnimation();
  case "thumper": return new ThumperAnimation();
  case "radiate-dj": return new RadiateDJAnimation();
  case "radiate-rnd":return new RadiateRandAnimation();
  case "radiate-bass":return new RadiateSubwoofers();
  default:
    println("*** unknown animation: "+animations[i]);
    exit();
    return null;
  }
}
