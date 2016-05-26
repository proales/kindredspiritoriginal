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

  for (VirtualPixel vp : ksVirtualPixels) {
    if (vp.coord.y > maxY) maxY = vp.coord.y;
    if (vp.coord.y < minY) minY = vp.coord.y;
    if (vp.coord.x > maxX) maxX = vp.coord.x;
    if (vp.coord.x < minX) minX = vp.coord.x;
  }
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
    println("*** fatal: maxPixelId("+maxPixelId+") > pixelsPerStrip("+pixelsPerStrip+")");
    exit(1);
  }
  if (maxControllerId == -1 || maxStripId == -1 || maxPixelId == -1) {
    println("*** fatal: maxControllerId("+maxControllerId+") or StripId("
            +maxStripId+") or PixelId("+maxPixelId+") is -1!");
    exit();
  }
}
