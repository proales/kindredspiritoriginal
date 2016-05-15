import com.heroicrobot.dropbit.registry.*;
import com.heroicrobot.dropbit.devices.pixelpusher.Pixel;
import com.heroicrobot.dropbit.devices.pixelpusher.Strip;

import java.util.*;

class PixelPusherObserver implements Observer {
  public boolean hasStrips = false;
  public void update(Observable registry, Object updatedDevice) {
    println("=== registry changed");
    if (updatedDevice != null) {
      println("device change: " + updatedDevice);
    }
    this.hasStrips = true;
  }
}

final int globalFrameRate = 60;
final int pixelsPerStrip = 96;
final int myScreenWidth = 800;
final int myScreenHeight = 600;

/* Represents a pixel in the KS model. */
class VirtualPoint {
  int x, y, z;
  int currentColor;
  VirtualPoint(int x, int y, int z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

/* Represents a strip of pixels in the KS model. */
class VirtualStrip {
  VirtualPoint wayPoints[];
  VirtualStrip(VirtualPoint wayPoints[]) {
    this.wayPoints = wayPoints;
  }
}

VirtualStrip ksVirtualStrips[];

void loadModel() {
  String lines[] = loadStrings("model.csv");
  List<VirtualStrip> virtualStrips = new ArrayList<VirtualStrip>();
  for (String line : lines) {
    String points[] = split(trim(line), ';');
    List<VirtualPoint> virtualPoints = new ArrayList<VirtualPoint>();
    for (String point : points) {
      String pos[] = split(trim(point), ',');
      int x = int(pos[0]);      
      int y = int(pos[1]);
      int z = int(pos[2]);
      virtualPoints.add(new VirtualPoint(x, y, z));
    }
    virtualStrips.add(new VirtualStrip(virtualPoints.toArray(new VirtualPoint[virtualPoints.size()])));
  }
  ksVirtualStrips = virtualStrips.toArray(new VirtualStrip[virtualStrips.size()]);
  println("loadModel: "+ksVirtualStrips.length+" strips loaded");
}

class Animation {
  String name;
  int speedPct;
  int logicalClock;
  int lastFrameCount;
  public Integer primaryColor;

  void resetClock() {
    logicalClock = 0;
    lastFrameCount = frameCount;
  }
  void tick() {
    int frameDelta = frameCount-lastFrameCount;
    float ticksPerSecond = float(globalFrameRate) * (float(speedPct)/100.0);
    float framesPerTick = float(globalFrameRate) / ticksPerSecond;
    lastFrameCount = frameCount;
    if (frameDelta < framesPerTick) return;
    logicalClock++;
  }
  int getPixelColor(int controller, int strip, int index) {
    println("base.getPixelColor: "+controller+", "+strip+", "+index);
    return 0;
  }
}

class OffAnimation extends Animation {
  OffAnimation() {
    name = "off";
    speedPct = 50;
    primaryColor = null;
  }
  int getPixelColor(int _controller, int _strip, int _index) {
    return 0x000000;
  }
}

class ThumperAnimation extends Animation {
  final int thumperPurple = 0x660E6F;
  ThumperAnimation() {
    name = "thumper";
    primaryColor = null;
  }
  int getPixelColor(int _controller, int _strip, int index) {
     if ((logicalClock % pixelsPerStrip) == index) {
       return thumperPurple;
     } else {
       return 0x000000;
     }
  }
}

class SolidAnimation extends Animation {
  SolidAnimation() {
    name = "solid";
    primaryColor = 0x009900;
  }
  int getPixelColor(int _controller, int _strip, int _index) {
    return primaryColor;
  }
}

// TODO: color picker should only show actual colors supported
// TODO: should show a box around the color that's currently selected
public class ColorPicker {
  int x, y, w, h;
  PImage cpImage;
  public ColorPicker(int x, int y, int w, int h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    cpImage = new PImage(w, h);
    init();
  }
  private void init () {
    int cw = w - 60;
    for (int i = 0; i < cw; i++) {
      float nColorPercent = i / (float)cw;
      float rad = (-360 * nColorPercent) * (PI / 180);
      int nR = (int)(cos(rad) * 127 + 128) << 16;
      int nG = (int)(cos(rad + 2 * PI / 3) * 127 + 128) << 8;
      int nB = (int)(Math.cos(rad + 4 * PI / 3) * 127 + 128);
      int nColor = nR | nG | nB;
      setGradient(i, 0, 1, h/2, 0xFFFFFF, nColor);
      setGradient(i, (h/2), 1, h/2, nColor, 0x000000);
    }
    drawRect(cw, 0,   30, h/2, 0xFFFFFF);
    drawRect(cw, h/2, 30, h/2, 0);
    for (int j = 0; j < h; j++) {
      int g = 255 - (int)(j/(float)(h-1) * 255 );
      drawRect(w-30, j, 30, 1, color( g, g, g ));
    }
  }
  private void setGradient(int x, int y, float w, float h, int c1, int c2 ) {
    float deltaR = red(c2) - red(c1);
    float deltaG = green(c2) - green(c1);
    float deltaB = blue(c2) - blue(c1);
    for (int j = y; j < (y+h); j++) {
      int c = color(red(c1)+(j-y)*(deltaR/h),
                    green(c1)+(j-y)*(deltaG/h),
                    blue(c1)+(j-y)*(deltaB/h));
      cpImage.set(x, j, c);
    }
  }
  private void drawRect(int rx, int ry, int rw, int rh, int rc) {
    for(int i = rx; i < rx+rw; i++) {
      for(int j = ry; j < ry+rh; j++) {
        cpImage.set(i, j, rc);
      }
    }
  }
  public void draw() {
    image(cpImage, x, y);
  }
  public Integer getColorOverMouse() {
    if (mouseX >= x && mouseX < x + w && mouseY >= y && mouseY < y+h) {
      return new Integer(get(mouseX, mouseY));
    } else {
      //  mouse isn't over this color picker
      return null;
    }
  }
}

String animations[] = {
  "off",
  "solid",
  "thumper"
};

Animation createAnimation(int i) {
  switch (animations[i]) {
  case "off"    : return new OffAnimation();
  case "solid"  : return new SolidAnimation();
  case "thumper": return new ThumperAnimation();
  default:
    println("*** unknown animation: "+animations[i]);
    return null;
  }
}

Animation live;
Animation preview;

DeviceRegistry registry;
PixelPusherObserver observer;
PFont titleFont;
PFont subtitleFont;
PFont sidebarFont;
ColorPicker previewColorPicker;
ColorPicker liveColorPicker;

final int sidebarWidth = 100;
final int sidebarTextHeight = 18;
final int mainAreaWidth = myScreenWidth-sidebarWidth;
final int paneWidth = mainAreaWidth/2;
final int paneHeight = myScreenHeight-15;
final int leftPaneX = sidebarWidth;
final int rightPaneX = sidebarWidth + paneWidth;
final int colorPickerHeight = 100;
final int colorPickerY = paneHeight-(colorPickerHeight+30);

ColorPicker placeColorPicker(int x) {
  return new ColorPicker(x, colorPickerY, paneWidth, colorPickerHeight);
}

void setLiveAnimation(int index) {
  Animation animation = createAnimation(index);
  live = animation;
  if (live.primaryColor != null) {
    liveColorPicker = placeColorPicker(rightPaneX);
  } else {
    liveColorPicker = null;
  }
}

void setPreviewAnimation(int index) {
  Animation animation = createAnimation(index);
  preview = animation;
  if (preview.primaryColor != null) {
    previewColorPicker = placeColorPicker(leftPaneX);
  } else {
    previewColorPicker = null;
  }
}

void setup() {
  loadModel();
  titleFont = createFont("Arial", 16, true);
  subtitleFont = createFont("Arial", 14, true);
  sidebarFont = createFont("Arial", 12, true);
  size(800, 600);
  stroke(255);
  background(0, 0, 0);
  frameRate(globalFrameRate);
  setLiveAnimation(0);
  setPreviewAnimation(0);
  registry = new DeviceRegistry();
  observer = new PixelPusherObserver();
  registry.addObserver(observer);
}

void drawTitle() {
  textFont(titleFont);
  fill(255);
  text("Kindred Spirit Lighting Console", sidebarWidth, 15);
}

boolean isSidebarItemHovered(int i) {
  int x = 0;
  int y = sidebarTextHeight * i;
  if (mouseX >= x && mouseX < x+sidebarWidth
   && mouseY >= y && mouseY < y+sidebarTextHeight) {
    return true;
  }
  return false;
}

void drawSidebar() {
  textFont(sidebarFont);
  for (int i = 0; i < animations.length; i++) {
    int y = sidebarTextHeight * i;
    if (isSidebarItemHovered(i)) {
      fill(0x00, 0x99, 0x00);
      rect(0, y+2, sidebarWidth-5, sidebarTextHeight+2);
      fill(0xFF, 0xFF, 0xFF);
    } else {
      fill(0x99, 0x99, 0x99);
    }
    text(animations[i], 0, y+sidebarTextHeight);
  }
}

void drawColorSelector(Animation a, ColorPicker colorPicker, int leftSide) {
  if (colorPicker != null) {
    colorPicker.draw();
  } else {
    fill(0x99, 0x99, 0x99);
    line(leftSide, colorPickerY, leftSide+paneWidth, colorPickerY+colorPickerHeight);
    line(leftSide+paneWidth, colorPickerY, leftSide, colorPickerY+colorPickerHeight);
  }
}

void drawDemo(String which, Animation animation, ColorPicker colorPicker,
              int x, int y, int w, int h) {
  textFont(subtitleFont);
  fill(255);
  text(which+": "+animation.name, x, y);
  drawColorSelector(animation, colorPicker, x);
}

void sendState(Animation animation) {
  if (!observer.hasStrips) {
    //println("observer.hasStrips is false; no strips available?");
    return;
  }
  registry.startPushing();
  registry.setAutoThrottle(true);
  for (Strip strip : registry.getStrips()) {
    for (int i = 0; i < strip.getLength(); i++) {
      int c = animation.getPixelColor(0, 0, i);
      strip.setPixel(c, i);
    }
  }
}


void draw() {
  background(0);
  drawTitle();
  drawSidebar();

  preview.tick();
  live.tick();

  drawDemo("preview", preview, previewColorPicker, leftPaneX, 30, paneWidth, paneHeight);
  drawDemo("live", live, liveColorPicker, rightPaneX, 30, paneWidth, paneHeight);
  sendState(live);
}

void mouseClicked() {
  /* Was a sidebar list item clicked? */
  for (int i = 0; i < animations.length; i++) {
    if (isSidebarItemHovered(i)) {
      setPreviewAnimation(i);
      break;
    }
  }
  if (previewColorPicker != null) {
    Integer changeColor = previewColorPicker.getColorOverMouse();
    if (changeColor == null) {
      preview.primaryColor = changeColor;
      println("preview color change: "+changeColor);
    }
  } else if (liveColorPicker != null) {
    Integer changeColor = liveColorPicker.getColorOverMouse();
    if (changeColor == null) {
      live.primaryColor = changeColor;
      println("live color change: "+changeColor);
    }
  }
}

void keyPressed() {
  println("keyPressed: "+key);
}