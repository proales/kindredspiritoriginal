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

final int globalFrameRate = 30;
final int pixelsPerStrip = 96;
final int myScreenWidth = 800;
final int myScreenHeight = 600;

/* Represents a pixel in the KS model. Directly corresponds to a controller/strip/index. */
class VirtualPixel {
  final int controllerId;
  final int stripId;
  final int pixelId;
  final int x, y, z;
  int currentColor;
  VirtualPixel(int controllerId, int stripId, int pixelId, int x, int y, int z) {
    this.controllerId = controllerId;
    this.stripId = stripId;
    this.pixelId = pixelId;
    this.x = x;
    this.y = y;
    this.z = z;
    this.currentColor = 0;
  }
}

/* Represents a waypoint in the KS model. */
class VirtualWayPoint {
  final int x, y, z;
  VirtualWayPoint(int x, int y, int z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

/* Represents a strip of pixels in the KS model. */
class VirtualStrip {
  final int controllerId;
  final int stripId;
  VirtualWayPoint wayPoints[];
  VirtualStrip(int controllerId, int stripId, VirtualWayPoint wayPoints[]) {
    this.controllerId = controllerId;
    this.stripId = stripId;
    this.wayPoints = wayPoints;
  }
}

VirtualStrip ksVirtualStrips[];
VirtualPixel ksVirtualPixels[];
int controllerStripMap[][][];

void loadModel() {
  String lines[] = loadStrings("model.csv");
  List<VirtualStrip> virtualStrips = new ArrayList<VirtualStrip>();
  for (String line : lines) {
    line = trim(line);
    if (line.equals("") || line.charAt(0) == '#') continue;

    String[] parts = split(trim(line), "|");
    if (parts.length != 2) {
      println("*** line "+line+" split on | into too many parts: "+parts.length);
      exit();
    }
    String controllerAndStripId[] = split(trim(parts[0]), ":");
    int controllerId = int(controllerAndStripId[0]);
    int stripId = int(controllerAndStripId[1]);
    println("loadModel: controller:strip="+controllerId+":"+stripId);
    String points[] = split(trim(parts[1]), ';');
    List<VirtualWayPoint> virtualPoints = new ArrayList<VirtualWayPoint>();
    // the unit distance between waypoints is in feet in this sketch we
    // approximate 10 pixels per foot, so that's why we multiply by 10
    for (String point : points) {
      String pos[] = split(trim(point), ',');
      int x = int(pos[0]) * 10;
      int y = int(pos[1]) * 10;
      int z = int(pos[2]) * 10;
      virtualPoints.add(new VirtualWayPoint(x, y, z));
    }
    if (virtualPoints.size() < 2) {
      println("!!! too few waypoints: " + virtualPoints.size());
      // TODO: blowup
    }
    VirtualStrip vs = new VirtualStrip(controllerId, stripId,
        virtualPoints.toArray(new VirtualWayPoint[virtualPoints.size()]));
    virtualStrips.add(vs);
  }
  ksVirtualStrips = virtualStrips.toArray(new VirtualStrip[virtualStrips.size()]);
  println("loadModel: "+ksVirtualStrips.length+" strips loaded");
}

class Coordinate {
  final int x, y, z;
  Coordinate(int x, int y, int z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

int signum(float f) {
  if (f > 0) return 1;
  if (f < 0) return -1;
  return 0;
}

// the internet says this is "bresenham's". whatevs.
List<Coordinate> line3d(int startx, int starty, int startz, int endx, int endy, int endz) {
  int dx = endx - startx;
  int dy = endy - starty;
  int dz = endz - startz;
  int ax = abs(dx) << 1;
  int ay = abs(dy) << 1;
  int az = abs(dz) << 1;
  int signx = (int) signum(dx);
  int signy = (int) signum(dy);
  int signz = (int) signum(dz);
  int x = startx;
  int y = starty;
  int z = startz;
  int deltax, deltay, deltaz;
  List<Coordinate> results = new ArrayList<Coordinate>();
  if (ax >= max(ay, az)) /* x dominant */ {
    deltay = ay - (ax >> 1);
    deltaz = az - (ax >> 1);
    while (true) {
      results.add(new Coordinate(x, y, z));
      if (x == endx) return results;
      if (deltay >= 0) {
        y += signy;
        deltay -= ax;
      }
      if (deltaz >= 0) {
        z += signz;
        deltaz -= ax;
      }
      x += signx;
      deltay += ay;
      deltaz += az;
    }
  } else if (ay >= max(ax, az)) /* y dominant */ {
    deltax = ax - (ay >> 1);
    deltaz = az - (ay >> 1);
    while (true) {
      results.add(new Coordinate(x,y,z));
      if (y == endy) return results;
      if (deltax >= 0) {
        x += signx;
        deltax -= ay;
      }
      if (deltaz >= 0) {
        z += signz;
        deltaz -= ay;
      }
      y += signy;
      deltax += ax;
      deltaz += az;
    }
  } else if (az >= max(ax, ay)) /* z dominant */ {
    deltax = ax - (az >> 1);
    deltay = ay - (az >> 1);
    while (true) {
      results.add(new Coordinate(x,y,z));
      if (z == endz) return results;
      if (deltax >= 0) {
        x += signx;
        deltax -= az;
      }
      if (deltay >= 0) {
        y += signy;
        deltay -= az;
      }
      z += signz;
      deltax += ax;
      deltay += ay;
    }
  }
  return results;
}

void rasterizeModelToPixels() {
  List<VirtualPixel> virtualPixels = new ArrayList<VirtualPixel>();
  for (VirtualStrip strip : ksVirtualStrips) {
    VirtualWayPoint prev = null;
    int pixelId = 0;
    for (VirtualWayPoint wayPoint : strip.wayPoints) {
      if (prev != null) {
        VirtualWayPoint cur = wayPoint;
        for (Coordinate coord : line3d(prev.x, prev.y, prev.z, cur.x, cur.y, cur.z)) {
          virtualPixels.add(new VirtualPixel(strip.controllerId, strip.stripId,
                                             pixelId, coord.x, coord.y, coord.z));
          pixelId++;
        }
      }
      prev = wayPoint;
    }
  }
  ksVirtualPixels = virtualPixels.toArray(new VirtualPixel[virtualPixels.size()]);
  println("rasterizeModelToPixels: "+ksVirtualStrips.length+" strips to "+ksVirtualPixels.length+" pixels");
}

void initControllerStripMap() {
  int maxControllerId = -1;
  int maxStripId = -1;
  int maxPixelId = -1;
  for (VirtualPixel vp : ksVirtualPixels) {
    if (vp.controllerId > maxControllerId) maxControllerId = vp.controllerId;
    if (vp.stripId > maxStripId) maxStripId = vp.stripId;
    if (vp.pixelId > maxPixelId) maxPixelId = vp.pixelId;
  }
  controllerStripMap = new int[maxControllerId+1][maxStripId+1][maxPixelId+1];
  for (int i = 0; i < ksVirtualPixels.length; i++) {
    VirtualPixel vp = ksVirtualPixels[i];
    controllerStripMap[vp.controllerId][vp.stripId][vp.pixelId] = i;
  }
  if (maxPixelId >= pixelsPerStrip) {
    println("*** maxPixelId("+maxPixelId+") > pixelsPerStrip("+pixelsPerStrip+")");
  }
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
  ThumperAnimation() {
    name = "thumper";
    primaryColor = null;
  }
  void tick() {
    super.tick();
    for (VirtualPixel vp : pixels) {
      if ((logicalClock % pixelsPerStrip) == vp.pixelId) {
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
    live.primaryColor = preview.primaryColor;
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

void setup()  {
  loadModel();
  rasterizeModelToPixels();
  initControllerStripMap();
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
    stroke(0x99, 0x99, 0x99);
    line(leftSide, colorPickerY, leftSide+paneWidth, colorPickerY+colorPickerHeight);
    line(leftSide+paneWidth, colorPickerY, leftSide, colorPickerY+colorPickerHeight);
  }
}

void drawDemo(String which, Animation animation, ColorPicker colorPicker,
              int x, int y, int _w, int _h) {
  textFont(subtitleFont);
  fill(255);
  text(which+": "+animation.name, x, y);
  drawColorSelector(animation, colorPicker, x);
  int xoff = x;
  int yoff = y+30;
  strokeWeight(2);
  for (VirtualPixel vpixel : animation.pixels) {
    int c = vpixel.currentColor;
    if (c == 0) continue; // no need to render black
    int r = (c >> 16) & 0xFF;
    int g = (c >> 8) & 0xFF;
    int b = c & 0xFF;
    stroke(r, g, b);
    point(xoff+vpixel.x, yoff+vpixel.y);
  }
  strokeWeight(1);
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
  if (mousePressed) { // support dragging
    if (previewColorPicker != null) {
      Integer changeColor = previewColorPicker.getColorOverMouse();
      if (changeColor != null) {
        preview.primaryColor = changeColor;
        println("preview color change: "+changeColor);
      }
    }
    if (liveColorPicker != null) {
      Integer changeColor = liveColorPicker.getColorOverMouse();
      if (changeColor != null) {
        live.primaryColor = changeColor;
        println("live color change: "+changeColor);
      }
    }
  }
  background(0);
  drawTitle();
  drawSidebar();

  preview.tick();
  live.tick();

  drawDemo("preview", preview, previewColorPicker, leftPaneX, 30, paneWidth, paneHeight);
  drawDemo("live", live, liveColorPicker, rightPaneX, 30, paneWidth, paneHeight);
  sendState(live);
  //println("frameRate: "+frameRate);
}

void mouseClicked() {
  /* Was a sidebar list item clicked? */
  for (int i = 0; i < animations.length; i++) {
    if (isSidebarItemHovered(i)) {
      setPreviewAnimation(i);
      break;
    }
  }
}

void keyPressed() {
  if (key == '\n') {
    for (int i = 0; i < animations.length; i++) {
      if (preview.name == animations[i]) {
        setLiveAnimation(i);
        break;
      }
    }
  } else {
    println("unknown keyPressed: "+key);
  }
}