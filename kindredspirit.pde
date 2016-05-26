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

final float globalShadeFactor = 0.85;
final int globalFrameRate = 30;
final int pixelsPerStrip = 96;
final int myScreenWidth = 800;
final int myScreenHeight = 600;

class Coordinate {
  final float x, y, z;
  Coordinate(float x, float y, float z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
  float distance(Coordindate b) {
    Coordinate a = this;
    float dx = b.x - a.x;
    float dy = b.y - a.y;
    float dz = b.z - a.z;
    return sqrt(pow(dx,2) + pow(dy,2) + pow(dz,2));
  }
}


/* Represents a pixel in the KS model. Directly corresponds to a controller/strip/index. */
class VirtualPixel {
  final int controllerId;
  final int stripId;
  final int pixelId;
  final Coordinate coord;
  int currentColor;
  VirtualPixel(int controllerId, int stripId, int pixelId, int x, int y, int z) {
    this.controllerId = controllerId;
    this.stripId = stripId;
    this.pixelId = pixelId;
    this.coord = new Coordinate(x, y, z);
    this.currentColor = 0;
  }
}

/* Represents a waypoint in the KS model. */
class VirtualWayPoint {
  final int x, y, z;
  final Coordinate coord;
  VirtualWayPoint(int x, int y, int z) {
    this.coord = new Coordinate(x, y, z);
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
float minX, maxX;
float minY, maxY;

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
    // The unit distance between waypoints is in feet.  In this sketch we
    // approximate 10 pixels per foot, so that's why we multiply by 10.
    for (String point : points) {
      String pos[] = split(trim(point), ',');
      int x = int(pos[0]) * 10;
      int y = int(pos[1]) * 10;
      int z = int(pos[2]) * 10;
      virtualPoints.add(new VirtualWayPoint(x, y, z));
    }
    if (virtualPoints.size() < 2) {
      println("!!! too few waypoints: " + virtualPoints.size());
      exit();
    }
    VirtualStrip vs = new VirtualStrip(controllerId, stripId,
        virtualPoints.toArray(new VirtualWayPoint[virtualPoints.size()]));
    virtualStrips.add(vs);
  }
  ksVirtualStrips = virtualStrips.toArray(new VirtualStrip[virtualStrips.size()]);
  println("loadModel: "+ksVirtualStrips.length+" strips loaded");
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
  textFont(sidebarFont);
  text("fps: "+int(frameRate), width-50, 15);
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
      stroke(0xFF, 0xFF, 0xFF);
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
              int x, int y, int w, int _h) {
  textFont(subtitleFont);
  fill(255);
  text(which+": "+animation.name, x, y);
  drawSlider(animation, x, w);
  drawColorSelector(animation, colorPicker, x);
  int xoff = x;
  int yoff = y+30;
  strokeWeight(4);
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
    int controllerId = strip.getPusher().getControllerOrdinal();
    int stripId = strip.getStripNumber();
    for (int i = 0; i < strip.getLength(); i++) {
      int c = animation.getPixelColor(controllerId, stripId, i);
      strip.setPixel(shade(c, globalShadeFactor), i);
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
  if (keyCode == ENTER || keyCode == RETURN) {
    for (int i = 0; i < animations.length; i++) {
      if (preview.name == animations[i]) {
        setLiveAnimation(i);
        live.speedPct = preview.speedPct;
        break;
      }
    }
  } else {
    println("unknown keyPressed: "+key);
  }
}
