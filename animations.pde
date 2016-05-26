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
    primaryColor = null;
  }
}

class ThumperAnimation extends Animation {
  final int thumperPurple = 0x660E6F;
  ThumperAnimation() {
    name = "thumper";
    primaryColor = null;
    speedPct = 50;
  }
  void tick() {
    super.tick();
    // rain effect
    int numBuckets = pixelsPerStrip;
    int yRange = maxY - minY;
    int activeBucket = logicalClock % numBuckets;
    float bucketHeight = float(yRange) / float(numBuckets);
    float yActiveStart = minY + (activeBucket*bucketHeight);
    float yActiveEnd = yActiveStart + bucketHeight;
    for (VirtualPixel vp : pixels) {
      if (vp.y >= yActiveStart && vp.y < yActiveEnd) {
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
  }
  void tick() {
    super.tick();
    int numBuckets = 100;
    int xRange = maxX - minX;
    int activeBucket = logicalClock % numBuckets;
    float bucketHeight = float(xRange) / float(numBuckets);
    float xActiveStart = minX + (activeBucket*bucketHeight);
    float xActiveEnd = xActiveStart + bucketHeight;
    for (VirtualPixel vp : pixels) {
      if (vp.coord.x >= xActiveStart && vp.coord.x < xActiveEnd) {
        vp.currentColor = primaryColor;
      } else {
        vp.currentColor = 0x000000;
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

String animations[] = {
  "off",
  "solid",
  "solidglow",
  "scan",
  "noise",
  "randomnoise",
  "thumper",
};

Animation createAnimation(int i) {
  switch (animations[i]) {
  case "off"    : return new OffAnimation();
  case "solid"  : return new SolidAnimation();
  case "solidglow" : return new SolidGlowAnimation();
  case "scan"   : return new ScanAnimation();
  case "noise"  : return new NoiseAnimation();
  case "randomnoise"  : return new RandomNoiseAnimation();
  case "thumper": return new ThumperAnimation();
  default:
    println("*** unknown animation: "+animations[i]);
    exit();
    return null;
  }
}
