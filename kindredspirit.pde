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

class Animation {
  String name;
  int speedPct;
  int logicalClock;
  int lastFrameCount;
  Integer primaryColor;
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
  int primaryColor = 0x009900;
  SolidAnimation() {
    name = "solid";
  }
  int getPixelColor(int _controller, int _strip, int _index) {
    return primaryColor;
  }
}

Animation animations[] = {
  new OffAnimation (),
  new SolidAnimation (),
  new ThumperAnimation ()
};

final int OFF_INDEX = 0;

public class ColorPicker {
  int x, y, w, h, c;
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
      int c = color(red(c1)+(j-y)*(deltaR/h), green(c1)+(j-y)*(deltaG/h), blue(c1)+(j-y)*(deltaB/h));
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
    /*if (mousePressed &&
        mouseX >= x &&
        mouseX < x + w &&
        mouseY >= y &&
        mouseY < y + h) {
        c = get( mouseX, mouseY );
    }
    fill(c);
    rect(x, y+h+10, 20, 20);
    */
  }
  /*
  public void fillUp () {
    fill(c);
    rect(x, y+h+10, 20, 20);
  }
  */
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
final int mainAreaWidth = width-sidebarWidth;
final int paneWidth = width-sidebarWidth;
final int paneHeight = height-15;
final int leftPaneX = sidebarWidth;
final int rightPaneX = sidebarWidth + paneWidth;
final int colorPickerHeight = 300;

ColorPicker placeColorPicker(int x, int w) {
  ColorPicker cp = new ColorPicker(x, paneHeight-(colorPickerHeight+30), paneWidth, colorPickerHeight);
  return cp;
}

void setPreviewAnimation(Animation a) {
  preview = a;
  if (preview.primaryColor != null) {
    previewColorPicker = placeColorPicker(leftPaneX, paneWidth); 
  } else {
    previewColorPicker = null;
  }
}

void setup() {
  titleFont = createFont("Arial",16,true);
  subtitleFont = createFont("Arial", 14, true);
  sidebarFont = createFont("Arial", 12, true);
  size(800, 600);
  stroke(255);
  background(0, 0, 0);
  frameRate(globalFrameRate);
  live = animations[OFF_INDEX];
  preview = animations[OFF_INDEX];
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
    int x = 0;
    int y = sidebarTextHeight * i;
    if (isSidebarItemHovered(i)) {
      fill(0x00, 0x99, 0x00);
      rect(0, y+2, sidebarWidth-5, sidebarTextHeight+2);
      fill(0xFF, 0xFF, 0xFF);
    } else {
      fill(0x99, 0x99, 0x99);
    }
    text(animations[i].name, 0, y+sidebarTextHeight);
  }
}

void drawDemo(String which, Animation animation, int x, int y, int w, int h)
{
  textFont(subtitleFont);
  fill(255);
  text(which+": "+animation.name, x, y);
}

void sendState(Animation animation)
{
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
  
  drawDemo("preview", preview, leftPaneX, 30, paneWidth, paneHeight);
  if (previewColorPicker != null) {
    previewColorPicker.draw();
  }
  drawDemo("live", live, rightPaneX, 30, paneWidth, paneHeight);
  if (liveColorPicker != null) {
    liveColorPicker.draw();
  }
  sendState(live);
}

void mouseClicked() {
  /* was a sidebar animation clicked? */
  for (int i = 0; i < animations.length; i++) {
    if (isSidebarItemHovered(i)) {
      setPreviewAnimation(animations[i]);
      break;
    }
  }
  /* was the preview color picker clicked? */
  if (previewColorPicker != null) {
    if (mouseX >= previewColorPicker.x
      && mouseX < previewColorPicker.x+previewColorPicker.w
      && mouseY >= previewColorPicker.y
      && mouseY < previewColorPicker.y+previewColorPicker.h) {
      preview.primaryColor = get(mouseX, mouseY);
    }
  }
  /* was the live color picker clicked? */
  if (liveColorPicker != null) {
    if (mouseX >= liveColorPicker.x
      && mouseX < liveColorPicker.x+liveColorPicker.w
      && mouseY >= liveColorPicker.y
      && mouseY < liveColorPicker.y+liveColorPicker.h) {
      preview.primaryColor = get(mouseX, mouseY);
    }
  }

  println("screen: width="+width+", height="+height);
  println("mouse clicked: x="+mouseX+", y="+mouseY); 
}

void keyPressed() {
  println("keyPressed: "+key);
}