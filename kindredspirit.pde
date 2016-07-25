
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

final float globalShadeFactor = 0.0; //1.0; //0.85;
final int globalFrameRate = 60;
final int pixelsPerStrip = 96;
final int myScreenWidth = 800;
final int myScreenHeight = 700;

class Coordinate {
  final float x, y, z;
  Coordinate(float x, float y, float z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
  float distance(Coordinate b) {
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
  VirtualPixel(int controllerId, int stripId, int pixelId, float x, float y, float z) {
    this.controllerId = controllerId;
    this.stripId = stripId;
    this.pixelId = pixelId;
    this.coord = new Coordinate(x, y, z);
    this.currentColor = 0;
  }
}

/* Represents a waypoint in the KS model. */
class VirtualWayPoint {
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
    for (String point : points) {
      String pos[] = split(trim(point), ',');
      int x = int(pos[0]);
      int y = int(pos[1]);
      int z = int(pos[2]);
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

Animation live;
Animation preview;

DeviceRegistry registry;
PixelPusherObserver observer;
PFont titleFont;
PFont subtitleFont;
PFont sidebarFont;
ColorPicker previewPrimaryColorPicker, previewSecondaryColorPicker;
ColorPicker livePrimaryColorPicker, liveSecondaryColorPicker;

final int sidebarWidth = 100;
final int sidebarTextHeight = 18;
final int mainAreaWidth = myScreenWidth-sidebarWidth;
final int paneWidth = mainAreaWidth/2;
final int paneHeight = myScreenHeight-15;
final int leftPaneX = sidebarWidth;
final int rightPaneX = sidebarWidth + paneWidth;
final int colorPickerWidth = paneWidth/2;
final int colorPickerHeight = 100;
final int colorPickerY = paneHeight-(colorPickerHeight+30);

ColorPicker placeColorPicker(int x) {
  return new ColorPicker(x, colorPickerY, colorPickerWidth, colorPickerHeight);
}

void setLiveAnimation(int index) {
  Animation animation = createAnimation(index);
  live = animation;
  if (live.primaryColor != null) {
    livePrimaryColorPicker = placeColorPicker(rightPaneX);
    live.primaryColor = preview.primaryColor;
  } else {
    livePrimaryColorPicker = null;
  }
  if (live.secondaryColor != null) {
    liveSecondaryColorPicker = placeColorPicker(rightPaneX+colorPickerWidth);
    live.secondaryColor = preview.secondaryColor;
  } else {
    liveSecondaryColorPicker = null;
  }
}

void setPreviewAnimation(int index) {
  Animation animation = createAnimation(index);
  preview = animation;
  if (preview.primaryColor != null) {
    previewPrimaryColorPicker = placeColorPicker(leftPaneX);
  } else {
    previewPrimaryColorPicker = null;
  }
  if (preview.secondaryColor != null) {
    previewSecondaryColorPicker = placeColorPicker(leftPaneX+colorPickerWidth);
  } else {
    previewSecondaryColorPicker = null;
  }
}

void setup() {
  loadModel();
  rasterizeModelToPixels();
  initControllerStripMap();
  titleFont = createFont("Arial", 16, true);
  subtitleFont = createFont("Arial", 14, true);
  sidebarFont = createFont("Arial", 12, true);
  size(800, 700);
  stroke(255);
  background(0, 0, 0);
  frameRate(globalFrameRate);
  setLiveAnimation(0);
  setPreviewAnimation(0);
  registry = new DeviceRegistry();
  observer = new PixelPusherObserver();
  registry.addObserver(observer);
  setupSpectro();
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
    line(leftSide, colorPickerY, leftSide+colorPickerWidth, colorPickerY+colorPickerHeight);
    line(leftSide+colorPickerWidth, colorPickerY, leftSide, colorPickerY+colorPickerHeight);
  }
}

void drawLED(int x, int y, int c)
{
  // draw the point at x,y and also immediately
  // above and below and to either side
  // TODO: get fancy and render the neighboring ones a bit darker, maybe
  pixels[y*width + x] = c;
  pixels[(y-1)*width + x] = c;
  pixels[(y+1)*width + x] = c;
  pixels[y*width + (x-1)] = c;
  pixels[y*width + (x+1)] = c;
}

void drawDemoControls(String which, Animation animation, ColorPicker primaryColorPicker,
              ColorPicker secondaryColorPicker, int x, int y, int w, int h) {
  textFont(subtitleFont);
  fill(255);
  text(which+": "+animation.name, x, y);
  drawSlider(animation, x, w);
  drawColorSelector(animation, primaryColorPicker, x);
  drawColorSelector(animation, secondaryColorPicker, x+colorPickerWidth);
}

void drawDemoLEDs(Animation animation, int x, int y, int w) {
  int xoff = x;
  int yoff = y+30;

  for (VirtualPixel vpixel : animation.pixels) {
    int c = vpixel.currentColor;
    if (c == 0) continue; // no need to render black
    int r = (c >> 16) & 0xFF;
    int g = (c >> 8) & 0xFF;
    int b = c & 0xFF;
    color col = color(r,g,b);

    float flatten_x = 0;
    float flatten_y = 0;
    // "squash" the model into 2d space
    if (vpixel.coord.x >= 0) {
      if (vpixel.coord.z >= 0) {
        flatten_x = -vpixel.coord.y;
        flatten_y = vpixel.coord.x;
      } else {
        flatten_x = vpixel.coord.y;
        flatten_y = -vpixel.coord.x;
      }
      if (flatten_y < 0) {
        //point(xoff+(w/2)+flatten_x, yoff-flatten_y);
        drawLED(int(xoff+(w/2)+flatten_x), int((yoff+100)-flatten_y), col);
      } else {
        //point(xoff+(w/2)+flatten_x, yoff+flatten_y);
        drawLED(int(xoff+(w/2)+flatten_x), int((yoff+100)+flatten_y), col);
      }
    } else {
      flatten_x = -vpixel.coord.z;
      flatten_y = 140-vpixel.coord.y;
      drawLED(int(xoff+(w/2)+flatten_x), int(yoff+flatten_y), col);
    }
  }
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
    if (previewPrimaryColorPicker != null) {
      Integer changeColor = previewPrimaryColorPicker.getColorOverMouse();
      if (changeColor != null) {
        preview.primaryColor = changeColor;
        println("preview primary color change: "+changeColor);
      }
    }
    if (previewSecondaryColorPicker != null) {
      Integer changeColor = previewSecondaryColorPicker.getColorOverMouse();
      if (changeColor != null) {
        preview.secondaryColor = changeColor;
        println("preview secondary color change: "+changeColor);
      }
    }
    if (livePrimaryColorPicker != null) {
      Integer changeColor = livePrimaryColorPicker.getColorOverMouse();
      if (changeColor != null) {
        live.primaryColor = changeColor;
        println("live primary color change: "+changeColor);
      }
    }
    if (liveSecondaryColorPicker != null) {
      Integer changeColor = liveSecondaryColorPicker.getColorOverMouse();
      if (changeColor != null) {
        live.secondaryColor = changeColor;
        println("live secondary color change: "+changeColor);
      }
    }
  }
  background(0);
  drawTitle();
  drawSidebar();

  tickSpectro();
  preview.tick();
  live.tick();

  drawDemoControls("preview", preview, previewPrimaryColorPicker,
           previewSecondaryColorPicker, leftPaneX, 30,
           paneWidth, paneHeight);
  drawDemoControls("live", live, livePrimaryColorPicker,
           liveSecondaryColorPicker, rightPaneX, 30,
           paneWidth, paneHeight);
  // point() is ridiculously slow; do this {load,update}Pixels() thing so
  // we can access the pixels[] buffer directly
  loadPixels();
  drawDemoLEDs(preview, leftPaneX, 30, paneWidth);
  drawDemoLEDs(live, rightPaneX, 30, paneWidth);
  updatePixels();
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
  } else if (key == 'm') {
    String file = "/tmp/vertices.txt";
    dumpControllerStripMap(file);
    println("** dumped controller-strip-vertex map to "+file);
  } else {
    println("unknown keyPressed: "+key);
  }
}

void stop() {
  stopSpectro();
  super.stop();
}