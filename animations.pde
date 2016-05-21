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
   for (int i = 0; i < ksVirtualPixels.length; i++) {
     VirtualPixel src = ksVirtualPixels[i];
     pixels[i] = new VirtualPixel(src.controllerId, src.stripId, src.pixelId,
                                  src.x, src.y, src.z);
   }
  }
  void resetClock() {
    logicalClock = 0;
    lastFrameCount = frameCount;
  }
  void tick() {
    logicalClock++;
    /*
    int frameDelta = frameCount-lastFrameCount;
    float ticksPerSecond = float(globalFrameRate) * (float(speedPct)/100.0);
    float framesPerTick = float(globalFrameRate) / ticksPerSecond;
    lastFrameCount = frameCount;
    if (frameDelta < framesPerTick) return;
    logicalClock++;
    */
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
  int miny = 0;
  int maxy = 0;
  ThumperAnimation() {
    name = "thumper";
    primaryColor = null;
    for (VirtualPixel vp : pixels) {
      if (vp.y > maxy) maxy = vp.y;
      if (vp.y < miny) miny = vp.y;
    }
  }
  void tick() {
    super.tick();
    // rain effect
    int numBuckets = pixelsPerStrip;
    int yRange = maxy - miny;
    int activeBucket = logicalClock % numBuckets;
    float bucketHeight = float(yRange) / float(numBuckets);
    float yActiveStart = miny + (activeBucket*bucketHeight);
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
  int minX = 0;
  int maxX = 0;
  ScanAnimation() {
    name = "scan";
    primaryColor = 0x009900;
    for (VirtualPixel vp : pixels) {
      if (vp.x > maxX) maxX = vp.x;
      if (vp.x < minX) minX = vp.x;
    }
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
      if (vp.x >= xActiveStart && vp.x < xActiveEnd) {
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
    primaryColor = null;
  }
  void tick() {
    super.tick();
    for (VirtualPixel vp : pixels) {
      vp.currentColor = makeRGB(int(random(255)), int(random(255)), int(random(255)));
    }
  }
}

String animations[] = {
  "off",
  "solid",
  "solidglow",
  "scan",
  "noise",
  "thumper",
};

Animation createAnimation(int i) {
  switch (animations[i]) {
  case "off"    : return new OffAnimation();
  case "solid"  : return new SolidAnimation();
  case "solidglow" : return new SolidGlowAnimation();
  case "scan"   : return new ScanAnimation();
  case "noise"  : return new NoiseAnimation();
  case "thumper": return new ThumperAnimation();
  default:
    println("*** unknown animation: "+animations[i]);
    exit();
    return null;
  }
}